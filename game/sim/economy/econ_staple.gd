class_name EconStaple
extends RefCounted
## E146 bakery staples (user order via Wilma 2026-11-14: "people prefer bakery things over direct from farms").
## OPT-IN: world.meta["on"] has "E146", until its A/B.
##   ORDERS (SOCIAL, EconHouseholds._post_orders): a group meets a band-dependent share of its FOOD need with FINE_FOOD
##     (1 unit covers 1 unit of need), ordered in the essentials class; the rest as FOOD. Not when bakery goods cost more
##     than PRICE_CAP × the effective food price for that band (then all FOOD).
##   FALLBACK (TRADE): FINE_FOOD clears before FOOD; whatever staple fine food a group did not get (sold out, too dear,
##     no cash) is ordered as raw FOOD in the same month, so the switch alone cannot cause hunger.
##   HUNGER: the staple fine food a group got counts toward its food need (EconHouseholds._consume); the luxury extra
##     (EconConsumer FINE_FOOD_PC) stays on top and is eaten as before.
##   BAKERIES: their FOOD bids join the households' essentials class (pro-rata, equal terms) and the D2 bid cap at the
##     fine-food value is dropped — the demand is now large and real.

const S := EconUtil.S
const SHARE_PM := {"I1": 400, "I2": 500, "I3": 600, "I4": 700, "I5": 800}
## fine food (incl. its shop margin) at most this many times the effective food price, else the band buys raw FOOD
## (base prices: fine food 260 + 20% margin against food 115 = 2.7×)
const PRICE_CAP := {"I1": 2.0, "I2": 2.3, "I3": 2.7, "I4": 3.2, "I5": 4.0}


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("E146") and not EconUtil.off(world, "E146")


static func fine_price_eff(world: WorldState) -> int:
	var tax_m := 1.0 + float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0
	var p := int(EconUtil.st(world)["prices"].get("FINE_FOOD", EconData.BASE_PRICE["FINE_FOOD"] * S))
	return int(float(p) * 1.1 * tax_m * (1.0 + float(EconRetail.margin_pm(world, "FINE_FOOD")) / 1000.0))


## Staple fine food a group orders out of its food quantity `food_q` (milli-units).
static func staple_q(world: WorldState, g: Dictionary, food_q: int, pf_eff: int, spare: int = -1) -> int:
	var band: String = g.get("band", "I3")
	var share_q := food_q * int(SHARE_PM.get(band, 600)) / 1000
	# (d) the taste for bakery goods grows with exposure: the unhappiness yardstick is the share × taste, so a colony that
	# never had bakeries does not miss them, while one whose bakeries collapse does (taste fades over years)
	g["ff_pref"] = share_q * int(g.get("ff_taste", 0)) / 1000
	var pff := fine_price_eff(world)
	var cap_eff := int(float(PRICE_CAP.get(band, 2.7)) * float(pf_eff))
	var want := share_q
	if float(pff) > float(cap_eff):
		share_q = 0
	elif spare >= 0 and pff > pf_eff:
		# never at the expense of calories: the bakery premium comes out of money left after a full raw-food diet,
		# utilities and rent (5 seeds: without this cap the dearer staples left families short for the fallback)
		share_q = mini(share_q, int(float(spare) * S / float(pff - pf_eff)))
	if dissatisfaction(world):
		_record_gate(world, want, cap_eff, spare, pf_eff, maxi(0, share_q))
	return maxi(0, share_q)  # households still try to buy their share — that is how they get to know bakery goods


# ------------------------------------------------------------------ E156 priced-out demand (bread only)

## E156 (user, opt-in with E146): "if they want to but can't buy, bread goes too high — the company can win by lowering
## instead: 1000 orders at 250 beats 500 orders at 350". Priced-out bread was invisible to bakeries (no order, so no
## shortage, so the price never fell, bakeries idle at 18–68% beside people eating raw). Each month every household
## pool's own gate is recorded — its bread share, its price cap (band × food price) and its spare budget — so the bakers
## can see exactly how much more would sell at a lower price. EconMarket then lowers the bread price by up to
## CUT_STEP a month when that raises revenue (never below CUT_FLOOR × the cheapest bakery's cost, only with idle
## capacity, not in a shortage). Bread only, by the user's choice (one clean control case).
const CUT_STEP := 0.05
const CUT_STEP_IDLE := 0.15  # Wilma: the same as the normal ALPHA, while (almost) nothing sells
const CUT_FLOOR := 1.1
const PRICED_OUT_MIN := 0.20
const IDLE_UTIL := 0.85


static func dissatisfaction(world: WorldState) -> bool:
	return active(world) and (world.meta["on"] as Array).has("E156")


static func _record_gate(world: WorldState, want: int, cap_eff: int, spare: int, pf_eff: int, ordered: int) -> void:
	var s := EconUtil.st(world)
	if int(s.get("bread_gates_m", -1)) != world.month:
		s["bread_gates"] = []
		s["bread_gates_m"] = world.month
		s["priced_out"] = {"FINE_FOOD": 0, "wanted": 0}
	(s["bread_gates"] as Array).append([want, cap_eff, spare, pf_eff])
	var po: Dictionary = s["priced_out"]
	po["FINE_FOOD"] = int(po["FINE_FOOD"]) + maxi(0, want - ordered)
	po["wanted"] = int(po["wanted"]) + want


## Staple bread the recorded households would order at an effective (shop) price x (milli-units).
static func demand_at(world: WorldState, x_eff: int) -> int:
	var t := 0
	for e in EconUtil.st(world).get("bread_gates", []):
		var want := int(e[0])
		if x_eff > int(e[1]):
			continue
		if x_eff <= int(e[3]) or int(e[2]) < 0:
			t += want
		else:
			t += mini(want, int(float(int(e[2])) * S / float(x_eff - int(e[3]))))
	return t


## The shop price households see for a market bread price p.
static func eff_of(world: WorldState, p: float) -> int:
	var tax_m := 1.0 + float(EconUtil.lever(world, "ECON_SALES_TAX", 0)) / 100.0
	return int(p * 1.1 * tax_m * (1.0 + float(EconRetail.margin_pm(world, "FINE_FOOD")) / 1000.0))


## TRADE (_update_prices): the bakers' price cut, or -1.0 for no change. `sold` = bread sold this month (milli).
static func bread_cut(world: WorldState, p: float, shortage: float, sold: int, cheapest: float) -> float:
	if not dissatisfaction(world) or cheapest <= 0.0:
		return -1.0
	var s := EconUtil.st(world)
	# Wilma: the shortage that blocks a cut is on the STAPLE orders only (a few unfilled luxury orders must not stop it)
	var sm: Dictionary = s.get("staple_m", {})
	var st_short := 0.0
	if int(sm.get("want", 0)) > 0:
		st_short = 1.0 - float(int(sm.get("got", 0))) / float(int(sm["want"]))
	if st_short > 0.05:
		return -1.0
	var po: Dictionary = s.get("priced_out", {})
	if int(po.get("wanted", 0)) <= 0 or float(int(po.get("FINE_FOOD", 0))) < PRICED_OUT_MIN * float(int(po["wanted"])):
		return -1.0
	var cap := 0
	var made := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "BAKERY" and not f["mothball"]:
			cap += int(float(EconData.RECIPES["BAKERY"]["out"][1]) * S * EconUtil.fscale(f))
			made += int(f.get("out_last", 0))
	if cap <= 0 or float(made) >= IDLE_UTIL * float(cap):
		return -1.0
	var floor_p := CUT_FLOOR * cheapest
	if p <= floor_p:
		return -1.0
	# the bakers look down the whole price range (to the floor) for the price that earns most, using the households'
	# own gates and budgets — a single 5% step from far above every gate would show no gain and never start
	var base_d := demand_at(world, eff_of(world, p))
	var best_p := p
	var best_rev := p * float(sold)
	var x := p
	while x > floor_p:
		x = maxf(floor_p, x * (1.0 - CUT_STEP))
		var gained := mini(maxi(0, demand_at(world, eff_of(world, x)) - base_d), cap - made)  # idle ovens only
		var rev := x * float(sold + gained)
		if rev > best_rev:
			best_rev = rev
			best_p = x
	if best_p >= p:
		return -1.0  # no lower price pays: keep it
	s["bread_cut_m"] = int(s.get("bread_cut_m", 0)) + 1
	# a seller with (almost) no sales loses nothing by cutting: up to CUT_STEP_IDLE a month then, CUT_STEP once it sells
	var step := CUT_STEP_IDLE if float(sold) < 0.05 * float(maxi(1, made)) or sold < S else CUT_STEP
	return maxf(best_p, p * (1.0 - step))


## (d) taste (‰ of the band share) after this month's staples: rises toward 1000 by the share of the staple order that
## was filled (TASTE_GROW_M months to get used to it), fades slowly when there are none (TASTE_FADE_M).
const TASTE_GROW_M := 12
const TASTE_FADE_M := 60


static func update_taste(g: Dictionary) -> void:
	var t := int(g.get("ff_taste", 0))
	var ordered := int(g.get("ff_ord", 0))
	var got := int(g.get("ff_got", 0))
	var exposure := 0 if ordered <= 0 else mini(1000, 1000 * got / ordered)
	t += (1000 - t) * exposure / 1000 / TASTE_GROW_M
	if exposure == 0:
		t -= t / TASTE_FADE_M
	g["ff_taste"] = clampi(t, 0, 1000)


## SOCIAL (_consume): the share of the preferred bakery portion that had to be covered with raw food, by district and
## colony (‰, weighted by quantity ≈ population); ECON_RAW_FOOD quarterly while the colony share is ≥ RAW_FACT_PM.
## User (via Wilma): "living on raw should produce unhappiness" — indicator ECON_RAW_FOOD_SHARE.
const RAW_FACT_PM := 250


static func record_raw(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var pref_d := {}
	var got_d := {}
	var pt := 0
	var gt := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var pref := int(g.get("ff_pref", 0))
		update_taste(g)
		if pref <= 0:
			continue
		var got := mini(pref, int(g.get("ff_got", 0)))
		var d: String = g["district"]
		pref_d[d] = int(pref_d.get(d, 0)) + pref
		got_d[d] = int(got_d.get(d, 0)) + got
		pt += pref
		gt += got
	var out := {}
	for d in pref_d:
		out[d] = 1000 - int(1000.0 * float(got_d[d]) / maxf(1.0, float(pref_d[d])))
	s["raw_food_d"] = out
	s["raw_food"] = 1000 - int(1000.0 * float(gt) / maxf(1.0, float(pt))) if pt > 0 else 0
	if world.month_of_year() % 3 == 0 and int(s["raw_food"]) >= RAW_FACT_PM:
		var worst := ""
		var wv := -1
		for d in EconUtil.sorted_keys(out):
			if int(out[d]) > wv:
				wv = int(out[d])
				worst = d
		EconFacts.emit(world, "ECON_RAW_FOOD", worst, [], [["GOVERNMENT", "government", 0.5], ["NATURE", "market", 0.5]],
			{"COST_OF_LIVING": -int(0.04 * float(s["raw_food"])), "FAIRNESS": -int(0.02 * float(s["raw_food"]))}, 10 + int(s["raw_food"]) / 40, "PUBLIC",
			{"raw_permille": int(s["raw_food"])}, {"districts": [worst]})


static func raw_pct(world: WorldState, d: String) -> float:
	return float(int(EconUtil.st(world).get("raw_food_d", {}).get(d, 0))) / 10.0


## TRADE, after FINE_FOOD cleared: unfilled staple fine food becomes a raw FOOD order (essentials class).
static func fallback(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var pf: int = s["prices"]["FOOD"]
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var want := int(g.get("ff_ord", 0))
		if want <= 0:
			g["ff_got"] = 0
			continue
		var got := mini(want, int(g["bought"].get("FINE_FOOD", 0)))  # the essentials class cleared before the luxury extra
		g["ff_got"] = got
		var gap := want - got
		if gap > 0:
			s["orders"].append({"buyer": gid + "~fb", "acct": EconUtil.hh_acct(gid), "district": g["district"], "good": "FOOD", "qty": gap,
				"limit": pf * 3, "class": EconMarket.C_HH_ESS, "kind": "hh", "group": gid})
		var st: Dictionary = s.get("staple_m", {"want": 0, "got": 0})
		st["want"] = int(st["want"]) + want
		st["got"] = int(st["got"]) + got
		s["staple_m"] = st


## E147 (opt-in "E147", A/B with E146): when a new firm's plant opens, the founder pays in working capital — WC_MONTHS of
## the plant's running cost (recipe crew at the firm's wage offer, inputs at market prices), at most half the founder's
## cash. Founders put 40% of the build cost in and borrowed the rest, all of it spent on construction, so a new bakery
## opened with 0–10k, could not buy food or hire, and was in distress by its second month (v9 probe, seed 1).
const WC_MONTHS := 3


static func startup_capital(world: WorldState, oid: String, fid: String) -> void:
	if not (world.meta.has("on") and (world.meta["on"] as Array).has("E147")):
		return
	var o: Dictionary = world.table("org")[oid]
	var founder: String = o.get("owner_group", "")
	if founder == "" or not world.table("hh").has(founder) or o.get("wc_paid", false):
		return
	o["wc_paid"] = true
	var f: Dictionary = world.table("facility")[fid]
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var s := EconUtil.st(world)
	var cost := 0
	for t in r["labor"]:
		cost += int(float(r["labor"][t]) * EconUtil.fscale(f)) * EconLabor.offer(world, oid, t)
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			cost += EconUtil.val(int(float(r["in"][g]) * S * EconUtil.fscale(f)), int(s["prices"][g]))
	var amt := mini(cost * WC_MONTHS, world.ledger.balance(EconUtil.hh_acct(founder)) / 2)
	if amt > 0:
		world.ledger.transfer(EconUtil.hh_acct(founder), EconUtil.acct(oid), amt, "EQUITY", world.month)
		s["startup_wc_m"] = int(s.get("startup_wc_m", 0)) + amt
