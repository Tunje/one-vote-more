class_name EconConsumer
extends RefCounted
## D2 (user decision A42, planning/spec-demand-v1.md §D2): consumer industries — durables that wear out, quality,
## reputation and a confidence cycle. Goods CLOTHING (TEXTILE), FURNISHINGS (FURNITURE), FINE_FOOD (BAKERY).
##
## Households: each pool holds a stock of clothing and furnishings (hh.dur {good: mu}, hh.dur_q {good: 0..100}) that
## wears out (clothing ~24 months, furnishings ~10 years, × (0.5 + quality/100): "buy cheap, buy twice"). They buy to
## replace wear and to close the gap to a target stock that grows with income band (no hard cap); fine food is eaten.
## Purchases come out of the discretionary goods budget left after the capped CONSUMER spending (money that used to sit
## idle), and the catch-up part follows CONFIDENCE (durables are postponable: booms and slumps).
## Workshops: each has a quality score (f.quality 0..100) from skilled staffing, condition, management, a corner-cutting
## (high-risk) CEO and experience; a company's reputation per good (org.rep {good}) follows its delivered quality with a
## lag. Sellers of better goods ask more; households choose by price × reputation; goods from a seller with quality ≥
## FINE_Q are the FINE tier (luxury tax, Anni's trade_law). Imports arrive at IMPORT_Q. Exports pay by reputation.
## A workshop below SCANDAL_Q may cause a quality scandal (fact, reputation −20).

const S := EconUtil.S
const TL := preload("res://sim/law/trade_law.gd")
const GOODS := ["CLOTHING", "FURNISHINGS", "FINE_FOOD"]
const WORKSHOPS := {"TEXTILE": "CLOTHING", "FURNITURE": "FURNISHINGS", "BAKERY": "FINE_FOOD"}
const DURABLE := {"CLOTHING": {"life": 24, "target_pc": 6}, "FURNISHINGS": {"life": 120, "target_pc": 10}}
const BAND_MULT := {"I1": 0.5, "I2": 0.75, "I3": 1.0, "I4": 1.5, "I5": 2.2}
const FINE_FOOD_PC := {"I1": 0.03, "I2": 0.08, "I3": 0.18, "I4": 0.35, "I5": 0.6}  # units per person-month
const CATCH_UP_M := 6
const DUR_SAVINGS_SHARE := 0.04  # of savings above the comfort level, per month, for durables (× confidence)
const FINE_Q := 70
const IMPORT_Q := 80
const SCANDAL_Q := 25
const SCANDAL_P := 0.01


# ------------------------------------------------------------------ setup / migration

## TRADE, first: prices for the D2 goods in worlds started before D2.
static func ensure(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for g in GOODS:
		if not s["prices"].has(g):
			s["prices"][g] = EconData.BASE_PRICE[g] * S
			s["base"][g] = EconData.BASE_PRICE[g] * S


# ------------------------------------------------------------------ quality & reputation (COMPANY_AI)

static func quality_monthly(world: WorldState) -> void:
	if EconUtil.off(world, "D2"):
		return
	var delivered := {}  # org|good -> [Σ q × out, Σ out]
	var r := world.rng.stream("econ.consumer")
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if not WORKSHOPS.has(f["type"]):
			continue
		var o: Dictionary = world.table("org")[f["org"]]
		var req := EconLabor.required(f)
		var need_sk := int(req.get("S", 0)) + int(req.get("Sp", 0))
		var have_sk := EconLabor.tier_total(f["staff"], "S") + EconLabor.tier_total(f["staff"], "Sp")
		var skill := 1.0 if need_sk <= 0 else clampf(float(have_sk) / float(need_sk), 0.0, 1.0)
		if not f["mothball"]:
			f["run_m"] = int(f.get("run_m", 0)) + 1
		var target := 25.0 + 25.0 * skill + 15.0 * float(f["condition"]) / float(100 * S) + 15.0 * float(o["ceo"].get("mgmt", 50)) / 100.0 \
			+ minf(15.0, float(f.get("run_m", 0)) / 24.0) + 5.0 * float(int(f.get("tier", 2)) - 2)
		if int(o["ceo"].get("risk", 50)) >= 70:
			target -= 12.0  # cutting corners: margin up, quality down
		var q := int(f.get("quality", 40))
		q += int(round((clampf(target, 0.0, 100.0) - float(q)) / 12.0))
		f["quality"] = clampi(q, 0, 100)
		var k := "%s|%s" % [f["org"], WORKSHOPS[f["type"]]]
		var row: Array = delivered.get(k, [0, 0])
		row[0] += int(f["quality"]) * int(f.get("out_last", 0)) / S
		row[1] += int(f.get("out_last", 0)) / S
		delivered[k] = row
		# a shoddy workshop risks a scandal (defective goods, a fire from cheap furnishings)
		if int(f["quality"]) < SCANDAL_Q and int(f.get("out_last", 0)) > 0 and r.randf() < SCANDAL_P:
			var rep: Dictionary = o.get("rep", {})
			rep[WORKSHOPS[f["type"]]] = maxi(0, int(rep.get(WORKSHOPS[f["type"]], 50)) - 20)
			o["rep"] = rep
			EconFacts.emit(world, "ECON_QUALITY_SCANDAL", f["district"], [["COMPANY", f["org"]]], EconFacts.company_blame(world, f["org"], 0.8),
				{"COST_OF_LIVING": -10, "SAFETY": -5 if f["type"] == "FURNITURE" else 0}, 40, "PUBLIC",
				{"org": f["org"], "facility": fid, "good": WORKSHOPS[f["type"]], "quality": f["quality"]}, {"districts": [f["district"]]})
	for k in EconUtil.sorted_keys(delivered):
		var parts: PackedStringArray = str(k).split("|")
		var o2: Dictionary = world.table("org")[parts[0]]
		var rep2: Dictionary = o2.get("rep", {})
		var row2: Array = delivered[k]
		if int(row2[1]) <= 0:
			continue
		var dq := int(row2[0]) / int(row2[1])
		var cur := int(rep2.get(parts[1], 50))
		rep2[parts[1]] = clampi(cur + int(round(float(dq - cur) / 12.0)), 0, 100)  # buyers remember: a lagged follow
		o2["rep"] = rep2


## A company's current delivered quality for a good (output-weighted over its workshops), or -1.
static func org_quality(world: WorldState, oid: String, good: String) -> int:
	var sq := 0
	var n := 0
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] == oid and WORKSHOPS.get(f["type"], "") == good:
			sq += int(f.get("quality", 40)) * maxi(1, int(f.get("out_last", 0)) / S)
			n += maxi(1, int(f.get("out_last", 0)) / S)
	return -1 if n == 0 else sq / n


static func rep_of(world: WorldState, oid: String, good: String) -> int:
	if oid == EconTrade.IMPORTER:
		return IMPORT_Q
	return int(world.peek("org").get(oid, {}).get("rep", {}).get(good, 50))


## After the firms posted their offers (COMPANY_AI): D2 offers carry quality and reputation; better goods ask more.
static func decorate_offers(world: WorldState) -> void:
	if EconUtil.off(world, "D2"):
		return
	for o in EconUtil.st(world)["offers"]:
		if not o["good"] in GOODS:
			continue
		var q := IMPORT_Q if o["seller"] == EconTrade.IMPORTER else org_quality(world, o["seller"], o["good"])
		if q < 0:
			q = 40
		o["q"] = q
		o["rep"] = rep_of(world, o["seller"], o["good"])
		if o["seller"] != EconTrade.IMPORTER:
			o["ask"] = int(float(o["ask"]) * (0.85 + 0.003 * float(q)))


## Market sort key multiplier (‰) for a household choosing between offers: price × (1.5 − reputation).
static func choice_factor(o: Dictionary) -> int:
	if not o.has("rep"):
		return 1000
	return 1500 - 10 * int(o["rep"])


## Market hook (household bought take units from offer o): record quality, collect the luxury tax on the FINE tier.
static func on_hh_purchase(world: WorldState, g: Dictionary, acct: String, o: Dictionary, take: int, goods_cost: int) -> void:
	if not o.has("q"):
		return
	var bq: Dictionary = g.get("bought_q", {})
	bq[o["good"]] = int(bq.get(o["good"], 0)) + int(o["q"]) * take / S
	g["bought_q"] = bq
	if int(o["q"]) >= FINE_Q:
		var fine: Dictionary = g.get("bought_fine", {})
		fine[o["good"]] = int(fine.get(o["good"], 0)) + take
		g["bought_fine"] = fine
		var tax := int(float(goods_cost) * float(TL.luxury_tax_pct(world)) / 100.0)
		if tax > 0:
			var paid := EconUtil.pay_upto(world, acct, EconUtil.TREASURY, tax, "LUXURY_TAX")
			EconFinance._gov_rev(world, paid)


# ------------------------------------------------------------------ households

## Confidence 0..1000 (SOCIAL): falling unemployment and rising real wages lift it; strikes and famine sink it.
static func confidence(world: WorldState) -> int:
	return int(EconUtil.peek_st(world).get("confidence", 600))


static func update_confidence(world: WorldState) -> void:
	if EconUtil.off(world, "D2"):
		return
	var s := EconUtil.st(world)
	var u := FirmAI.colony_unemployment(world)
	var hist: Array = s.get("u_hist", [])
	hist.append(int(u * 1000.0))
	while hist.size() > 13:
		hist.pop_front()
	s["u_hist"] = hist
	var du := float(int(hist[hist.size() - 1]) - int(hist[0])) / 1000.0  # change in the unemployment rate over a year
	var target := 600.0 - 2500.0 * du + 12.0 * EconUnions.real_wage_growth(world) - 150.0 * maxf(0.0, u - 0.15) * 10.0
	if not world.facts.query("UNION_STRIKE_CALLED", world.month - 3, world.month).is_empty():
		target -= 80.0
	if bool(s.get("famine", false)):
		target -= 250.0
	var c := int(s.get("confidence", 600))
	s["confidence"] = clampi(c + int(round((clampf(target, 100.0, 1000.0) - float(c)) / 4.0)), 100, 1000)


## Household orders for D2 goods (end of SOCIAL, after the capped CONSUMER order), within `budget` (milli).
static func post_orders(world: WorldState, gid: String, g: Dictionary, budget: int) -> void:
	budget = maxi(0, budget)
	if EconUtil.off(world, "D2"):
		return
	var s := EconUtil.st(world)
	var p := EconHouseholds.persons(g)
	if p <= 0:
		return
	var band: String = g.get("band", "I3")
	var bm := float(BAND_MULT.get(band, 1.0))
	var conf := 0.3 + float(confidence(world)) / 1000.0
	# durables are what savings are for: a share of the savings above the household's comfort level, more when confident
	var savings := world.ledger.balance(EconUtil.hh_acct(gid))
	var excess := maxi(0, savings - int(EconData.SAVINGS_TARGET_MONTHS * float(EconHouseholds.essentials_cost(world, g))))
	budget += int(float(excess) * DUR_SAVINGS_SHARE * conf)
	var dur: Dictionary = g.get("dur", {})
	var worn: Dictionary = g.get("dur_worn", {})
	var want := {}
	for good in DURABLE:
		var target := int(float(p) * float(DURABLE[good]["target_pc"]) * bm)
		var gap := maxi(0, target - int(dur.get(good, 0)))
		want[good] = int(worn.get(good, 0)) + int(float(gap) / float(CATCH_UP_M) * conf)
	want["FINE_FOOD"] = int(float(p) * float(FINE_FOOD_PC.get(band, 0.1)) * (0.6 + 0.4 * conf))
	var cost := 0
	var price := {}
	for good in want:
		price[good] = int(float(s["prices"].get(good, EconData.BASE_PRICE[good] * S)) * 1.1)
		cost += EconUtil.val(int(want[good]), price[good])
	if cost <= 0:
		return
	var f := minf(1.0, float(budget) / float(cost))
	var tariff := 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
	for good in EconUtil.sorted_keys(want):
		var q := int(float(want[good]) * f)
		if q <= 0:
			continue
		s["orders"].append({"buyer": gid + "~" + good, "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": good, "qty": q,
			"limit": int(price[good]) * 13 / 10 + tariff, "class": EconMarket.C_HH_DISC, "kind": "hh", "group": gid})


## SOCIAL (_consume): bought durables join the household stock (quality-weighted), fine food is eaten; stock wears.
static func absorb(world: WorldState, g: Dictionary) -> void:
	if EconUtil.off(world, "D2"):
		return
	var dur: Dictionary = g.get("dur", {})
	var dq: Dictionary = g.get("dur_q", {})
	var bq: Dictionary = g.get("bought_q", {})
	var worn := {}
	for good in GOODS:
		var b: int = int(g["bought"].get(good, 0))
		if b > 0:
			EconUtil.qflow(world, good, "burned", b)  # into the home (durables) or eaten (fine food)
		if not DURABLE.has(good):
			continue
		var stock := int(dur.get(good, 0))
		if b > 0:
			var q_new := int(bq.get(good, 0)) * S / b
			dq[good] = (int(dq.get(good, 50)) * stock / S + q_new * b / S) / maxi(1, (stock + b) / S)
			stock += b
		var life := maxf(1.0, float(DURABLE[good]["life"]) * (0.5 + float(dq.get(good, 50)) / 100.0))
		var w := int(float(stock) / life)
		stock -= w
		dur[good] = stock
		worn[good] = w
	g["dur"] = dur
	g["dur_q"] = dq
	g["dur_worn"] = worn
	g["bought_q"] = {}
	g["bought_fine"] = {}


# ------------------------------------------------------------------ queries

## {good: {producers, quality (avg delivered), stock_pc (units per person, durables), fine_share_pct}, confidence}
static func summary(world: WorldState) -> Dictionary:
	var out := {"confidence": confidence(world)}
	var pop := maxi(1, PopStore.total(world))
	for good in GOODS:
		var prod := 0
		var sq := 0
		for fid in world.peek("facility"):
			var f: Dictionary = world.peek("facility")[fid]
			if WORKSHOPS.get(f["type"], "") == good and not f["mothball"]:
				prod += 1
				sq += int(f.get("quality", 40))
		var stock := 0
		for gid in world.peek("hh"):
			stock += int(world.peek("hh")[gid].get("dur", {}).get(good, 0))
		out[good] = {"producers": prod, "quality": 0 if prod == 0 else sq / prod, "stock_pc": float(stock) / S / float(pop)}
	return out
