class_name FirmAI
extends RefCounted
## COMPANY_AI phase (spec §9): rule-based firm decisions for next month.
## Producers: targets, mothballing, input orders, sale asks. Utilities/institutions: demand/budget targets.
## Contractors: crews, materials, bids. Quarterly: investment, entry. CEO turnover. Wage index.

const S := EconUtil.S


static func run(world: WorldState) -> void:
	var s := EconUtil.st(world)
	_update_sales_ema(world)
	_ceo_turnover(world)
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		_set_target(world, f)
	_post_inputs_and_offers(world)
	EconConstruction.contractor_plans(world)
	EconLabor.post_vacancies(world)
	EconConstruction.bid_round(world)
	_auto_award(world)
	EconInsolvency.liquidation_round(world)
	EconInsolvency.forced_sale_round(world)
	if world.month % 6 == 0:
		EconInsolvency.reprivatize(world)
	if not EconUtil.off(world, "E110"):
		EconEssentials.record(world)
	if world.month_of_year() % 3 == 0:
		_investment(world)
		_entry(world)
		_builder_entry(world)
		_new_plants(world)
		_essentials_planner(world)
		_developers(world)  # E120: private housing where the colony is crowded
	_expansion(world)
	_small_business(world)
	_media_owners(world)
	EconLabor.update_wage_index(world)


static func _update_sales_ema(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		var sold: Dictionary = o.get("sold", {})
		for good in EconUtil.sorted_keys(_org_outputs(world, oid)):
			var prev: int = o["sales_ema"].get(good, _org_outputs(world, oid)[good])
			var cur: int = sold.get(good, 0)
			o["sales_ema"][good] = int(0.67 * prev + 0.33 * cur)


## Output goods (market goods only) an org produces -> total full capacity (mu).
static func _org_outputs(world: WorldState, oid: String) -> Dictionary:
	var out := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid:
			continue
		var r: Dictionary = EconData.RECIPES[f["type"]]
		if r["out"][0] in EconData.MARKET_GOODS:
			out[r["out"][0]] = out.get(r["out"][0], 0) + int(float(r["out"][1]) * S * EconUtil.fscale(f))
	return out


static func _org_stock(world: WorldState, oid: String, good: String) -> int:
	var t := 0
	for d in EconData.DISTRICTS:
		t += EconUtil.inv_get(world, oid, good, d)
	return t


static func _set_target(world: WorldState, f: Dictionary) -> void:
	var s := EconUtil.st(world)
	var o: Dictionary = world.table("org")[f["org"]]
	if o["status"] in ["LIQUIDATION", "DISSOLVED"]:
		f["mothball"] = true
		return
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var good: String = r["out"][0]
	var t := 1.0
	match f["type"]:
		"POWER", "WATERWORKS":
			var key := "E" if f["type"] == "POWER" else "W"
			var cap := 0.0
			for fid2 in world.table("facility"):
				var f2: Dictionary = world.table("facility")[fid2]
				if f2["type"] == f["type"] and not f2["mothball"]:
					# E66: effective capacity (condition × management), not nameplate — decayed plants must run harder
					cap += float(EconData.RECIPES[f2["type"]]["out"][1]) * S * EconUtil.fscale(f2) * EconProduction._eff(world, f2)
			t = clampf(1.08 * float(s.get("util_demand", {}).get(key, cap)) / maxf(1.0, cap), 0.3, 1.0)
		"CLINIC", "SCHOOL", "ADMIN":
			t = _budget_ratio(world, f)
		"HOUSING", "DEPOT":
			t = 1.0
		"SERVICEHUB":
			var cap2 := float(r["out"][1]) * S * EconUtil.fscale(f)
			var sold := float(f.get("svc_sold", cap2))  # services sold last month
			t = clampf(1.1 * sold / cap2 + 0.05, 0.3, 1.0)
		_:
			if good in EconData.MARKET_GOODS:
				t = _producer_target(world, f, o, good)
	if good in EconData.MARKET_GOODS:
		var old := float(f["T"]) / 1000.0
		t = old + clampf(t - old, -0.20, 0.30)  # smoothed production planning (E45)
	f["T"] = int(t * 1000)
	f["steady_m"] = f.get("steady_m", 0) + 1 if f["T"] >= 850 else 0
	if f["T"] >= 900:
		f["high_util_m"] += 1
	else:
		f["high_util_m"] = 0
	# mothballing (spec §9.1 step 4)
	if good in EconData.MARKET_GOODS:
		if f["T"] < 250:
			f["low_util_m"] += 1
		else:
			f["low_util_m"] = 0
		if not f["mothball"] and f["low_util_m"] >= 12 and not _keeps_idle_plant(world, o):
			var jobs := 0  # E115b: posts lost, for the papers
			var req := EconLabor.required(f)
			for t2 in req:
				jobs += int(req[t2])
			f["mothball"] = true
			EconFacts.emit(world, "ECON_FACILITY_MOTHBALLED", f["district"], [["COMPANY", f["org"]]],
				EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": -10}, 35, "PUBLIC", {"facility": f["id"],
				"type": f["type"], "jobs": jobs / S}, {"districts": [f["district"]]})
		elif f["mothball"] and f["T"] >= 500 and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"] 				and not f.get("closed_unsafe", false) and not f.get("law_closed", false) and not f.get("abandoned", false):  # E104: only repair/relicensing reopens those; E118: never a scrapped plant
			f["mothball"] = false
			f["low_util_m"] = 0


## Media M4 (company side; Anni runs outlet finances in JUSTICE, after this): each month a company that owns a paper
## decides whether to cover next month's shortfall (running cost − account balance). It covers while it is ACTIVE,
## keeps MEDIA_RESERVE_MONTHS of its costs in cash, and the top-up stays under its willingness to pay: the more bad
## press it had in 12 months, the more a mouthpiece is worth (MEDIA_COVER_BASE + MEDIA_COVER_PER_STORY W_ref per
## story, up to 4 stories) plus MEDIA_COVER_PROFIT_SHARE of last month's profit. Covering is an investment from
## retained cash ("MEDIA_COVER", no P&L line, like the founding). An owner that will not or cannot cover, or one in
## liquidation, tries to sell to the richest willing company (one with bad press of its own and no paper, enough
## cash); with no buyer the paper runs on until Anni's deficit rule closes it.
const MEDIA_COVER_BASE := 2.0  # W_ref a month; a firm's costs run 20–400 W_ref, a company paper costs about 1.6–3
const MEDIA_COVER_PER_STORY := 1.0
const MEDIA_COVER_PROFIT_SHARE := 0.05
const MEDIA_RESERVE_MONTHS := 1  # a firm keeps one month of its own costs (most firms never hold three)
const MEDIA_BUYER_CASH := 100  # W_ref
const MEDIA_SELL_AFTER := 3  # deficit months before an unwilling owner looks for a buyer


static func _media_owners(world: WorldState) -> void:
	if EconUtil.off(world, "MEDIA_M4") or world.peek("outlet").is_empty():
		return
	var wref := maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))
	for out_id in Media.outlets(world):
		var out: Dictionary = world.table("outlet")[out_id]
		if String(out["owner"].get("kind", "")) != "COMPANY":
			continue
		var oid := String(out["owner"]["id"])
		var o: Dictionary = world.table("org").get(oid, {})
		var acc := String(out["account"])
		# + 10%: the cost is re-read in JUSTICE after circulation updates; an exact top-up can miss by a few credits
		var short := Media.running_cost(world, out) * 11 / 10 - world.ledger.balance(acc)
		if o.is_empty() or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			_sell_paper(world, out_id, oid, wref)  # an asset of the estate
			continue
		if short <= 0:
			continue
		var willing := (MEDIA_COVER_BASE + MEDIA_COVER_PER_STORY * float(mini(4, Media.bad_press_12m(world, oid)))) * float(wref)
		var profit := EconFinance.profit(o["pl_last"]) if not o.get("pl_last", {}).is_empty() else 0
		willing += MEDIA_COVER_PROFIT_SHARE * float(maxi(0, profit))
		var spare := world.ledger.balance(EconUtil.acct(oid)) - MEDIA_RESERVE_MONTHS * maxi(1, EconFinance._monthly_costs(o))
		# the owner's reasoning, kept on the outlet for the papers' finance view and probes (W_ref)
		out["owner_decision"] = {"month": world.month, "short_mw": int(round(1000.0 * float(short) / wref)), "willing_mw": int(round(1000.0 * willing / wref)),
			"spare_mw": int(round(1000.0 * float(spare) / wref)), "status": o["status"]}  # milli-W_ref (integer state)
		if o["status"] == "ACTIVE" and float(short) <= willing and spare >= short:
			world.ledger.transfer(EconUtil.acct(oid), acc, short, "MEDIA_COVER", world.month)
			o["media_cover_12m"] = int(o.get("media_cover_12m", 0)) + short
		elif Media.deficit_months(world, out_id) >= MEDIA_SELL_AFTER:
			_sell_paper(world, out_id, oid, wref)
	if world.month_of_year() == 1:
		for oid2 in world.table("org"):
			world.table("org")[oid2].erase("media_cover_12m")


## Sells a company paper to the richest willing company; the price is the buyer's cash share it is ready to commit
## (one month of running cost — papers in deficit sell cheaply), paid to the seller (or its estate). False: no buyer.
static func _sell_paper(world: WorldState, out_id: String, seller: String, wref: int) -> bool:
	var out: Dictionary = world.table("outlet")[out_id]
	var best := ""
	var best_cash := MEDIA_BUYER_CASH * wref
	for oid in EconUtil.sorted_keys(world.table("org")):
		if oid == seller:
			continue
		var o: Dictionary = world.table("org")[oid]
		if o["status"] != "ACTIVE" or o["is_contractor"] or not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
			continue
		if not Media.owned_by(world, {"kind": "COMPANY", "id": oid}).is_empty() or Media.bad_press_12m(world, oid) <= 0:
			continue
		var c := world.ledger.balance(EconUtil.acct(oid))
		if c > best_cash:
			best_cash = c
			best = oid
	if best == "":
		return false
	var price := mini(Media.running_cost(world, out), world.ledger.balance(EconUtil.acct(best)))
	var r: Dictionary = Media.transfer_outlet(world, out_id, {"kind": "COMPANY", "id": best}, price)
	if not bool(r.get("ok", false)):
		return false
	if price > 0 and world.ledger.has_account(EconUtil.acct(seller)):
		world.ledger.transfer(EconUtil.acct(best), EconUtil.acct(seller), price, "MEDIA_SALE", world.month)
	if world.table("org").has(seller):
		world.table("org")[seller].erase("media_out")
	world.table("org")[best]["media_out"] = out_id
	return true


## E115b (Wilma): the owner decides on mothballing. A public enterprise keeps an idle plant running while colony
## unemployment is high (keeping jobs is a political choice it may make; it pays for it).
static func _keeps_idle_plant(world: WorldState, o: Dictionary) -> bool:
	if EconUtil.off(world, "E115") or o["type"] != "PUBLIC_ENTERPRISE" or o["status"] != "ACTIVE":
		return false
	return colony_unemployment(world) >= PE_KEEP_IDLE_U


const PE_KEEP_IDLE_U := 0.12


## E112: monthly input requirement of `good` by the org's own running plants at their current targets.
static func _own_input_need(world: WorldState, oid: String, good: String) -> float:
	var need := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f2: Dictionary = world.table("facility")[fid]
		if f2["org"] != oid or f2["mothball"]:
			continue
		var r2: Dictionary = EconData.RECIPES.get(f2["type"], {})
		if r2.is_empty() or not r2["in"].has(good):
			continue
		need += float(r2["in"][good]) * S * float(f2["T"]) / 1000.0 * EconUtil.fscale(f2) * EconUtil.tier_in(f2)
	return need


static func _producer_target(world: WorldState, f: Dictionary, o: Dictionary, good: String) -> float:
	var caps := _org_outputs(world, f["org"])
	var cap: float = float(caps.get(good, 1))
	var ema := float(o["sales_ema"].get(good, cap))
	# demand signal: the firm's capacity share of everything buyers wanted last month (sees unfilled demand)
	var ms: Dictionary = EconUtil.st(world).get("market_stats", {}).get(good, {})
	var all_cap := 0.0
	for oid2 in EconUtil.sorted_keys(world.table("org")):
		all_cap += float(_org_outputs(world, oid2).get(good, 0))
	var wanted_share := float(ms.get("wanted", 0)) * cap / maxf(1.0, all_cap)
	ema = maxf(ema, 0.5 * (ema + wanted_share))
	# E112: inputs the firm's own downstream plants draw internally (E93 pooling) are not market sales — without
	# this, CPW's mines saw no demand while its own smelters starved (mines at the 20% floor, materials at 10×).
	if not EconUtil.off(world, "E112"):
		ema += _own_input_need(world, f["org"], good)
	var sigma := 0.20 * (1.0 - float(o["ceo"]["mgmt"]) / 100.0)
	var expected := ema * (1.0 + EconUtil.normal(world, "comp.forecast", sigma))
	# if everything offered was sold, demand was rationed: aim for capacity
	var stock := float(_org_stock(world, f["org"], good))
	if stock < 0.05 * cap:
		expected = maxf(expected, cap)
	# stock now (incl. this month's output) is sold next month; next month's output is sold the month after:
	# Q = expected (next) + buffer − (stock − expected)
	var target_inv := expected * (0.5 if good == "FOOD" else 1.0)
	var q := 2.0 * expected + target_inv - stock
	var t := clampf(q / cap, 0.2, 1.0)
	# E108: profit-seeking supply. When the price is well above unit cost and stock is not piling up, produce more —
	# buyers' orders shrink at high prices, so following sales alone trapped the colony at high price / low volume
	# (io_feasibility: the plants exist, they ran at 20–30% while prices sat at the cap).
	if not EconUtil.off(world, "E108") and stock < 2.0 * cap:
		var price := float(EconUtil.st(world)["prices"].get(good, 0))
		var margin := price / maxf(1.0, unit_cost(world, f["type"]))
		if margin >= 1.25:
			t = maxf(t, clampf(0.5 + 0.5 * (margin - 1.25) / 0.75, 0.5, 1.0))
	return t  # producers keep a 20% floor (core crew), spec §9.1 mothball rule handles real collapse


static func _budget_ratio(world: WorldState, f: Dictionary) -> float:
	var s := EconUtil.st(world)
	var o: Dictionary = world.table("org")[f["org"]]
	var lever_id: String = EconData.INSTITUTION_BUDGET.get(o["key"], "")
	if lever_id == "":
		return 1.0
	var budget := float(EconUtil.lever(world, lever_id, 0)) * 1000.0 * S / 12.0
	var r: Dictionary = EconData.RECIPES[f["type"]]
	var cost := 0.0
	for t in r["labor"]:
		cost += float(r["labor"][t]) * float(EconFinance.wage_for(world, f["org"], t))
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			cost += float(r["in"][g]) * float(s["prices"][g])
		elif g == "ENERGY":
			cost += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			cost += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	# count every facility this institution runs
	var n := 0
	for fid in world.table("facility"):
		if world.table("facility")[fid]["org"] == f["org"]:
			n += 1
	return clampf(budget / maxf(1.0, cost * n), 0.0, 1.0)


static func _post_inputs_and_offers(world: WorldState) -> void:
	var s := EconUtil.st(world)
	# input orders per org per (good, district)
	var needs := {}  # "org|good|district" -> qty
	var upkeep_val := {}  # org -> value of its running plants' monthly upkeep (E116)
	var upkeep_qty := {}  # "org|good|district" -> upkeep part of the need (E116)
	var bakery_orgs := {}  # D2: orgs that turn food into fine food
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
		if f["type"] == "BAKERY":
			bakery_orgs[f["org"]] = true
		if f["mothball"]:
			if f.get("closed_unsafe", false):  # E84: overhaul of a plant closed as unsafe needs its full upkeep
				if r["upkeep"] > 0:
					var ko := "%s|MATERIAL|%s" % [f["org"], f["district"]]
					needs[ko] = needs.get(ko, 0) + int(float(r["upkeep"]) * S * EconUtil.fscale(f))
				var uco: int = EconData.UPKEEP_COMPONENT.get(f["type"], 0)
				if uco > 0:
					var kc := "%s|COMPONENT|%s" % [f["org"], f["district"]]
					needs[kc] = needs.get(kc, 0) + int(float(uco) * S * EconUtil.fscale(f))
			continue
		var t := float(f["T"]) / 1000.0
		for g in r["in"]:
			if g in EconData.MARKET_GOODS:
				var k := "%s|%s|%s" % [f["org"], g, f["district"]]
				needs[k] = needs.get(k, 0) + int(float(r["in"][g]) * S * t * EconUtil.fscale(f) * EconUtil.tier_in(f))
		if r["upkeep"] > 0:
			var k2 := "%s|MATERIAL|%s" % [f["org"], f["district"]]
			var q2 := int(float(r["upkeep"]) * S * EconUtil.fscale(f))
			needs[k2] = needs.get(k2, 0) + q2
			upkeep_val[f["org"]] = int(upkeep_val.get(f["org"], 0)) + EconUtil.val(q2, s["prices"]["MATERIAL"] * 2)
			upkeep_qty[k2] = int(upkeep_qty.get(k2, 0)) + q2
		var uc: int = EconData.UPKEEP_COMPONENT.get(f["type"], 0)
		if uc > 0:
			var k3 := "%s|COMPONENT|%s" % [f["org"], f["district"]]
			var q3 := int(float(uc) * S * EconUtil.fscale(f))
			needs[k3] = needs.get(k3, 0) + q3
			upkeep_val[f["org"]] = int(upkeep_val.get(f["org"], 0)) + EconUtil.val(q3, s["prices"]["COMPONENT"] * 2)
			upkeep_qty[k3] = int(upkeep_qty.get(k3, 0)) + q3
	var budgets := {}
	var e116 := not EconUtil.off(world, "E116")
	for k in EconUtil.sorted_keys(needs):
		var parts: PackedStringArray = k.split("|")
		var oid := parts[0]
		var good := parts[1]
		var d := parts[2]
		var o: Dictionary = world.table("org")[oid]
		if not budgets.has(oid):
			var reserve: int = 0 if o["type"] == "PUBLIC_INSTITUTION" else o["pl_last"].get("wages", 0)
			var bal := world.ledger.balance(EconUtil.acct(oid))
			budgets[oid] = bal - reserve
			if e116:
				# E116 maintenance first: upkeep (about 2% of a farm firm's wage bill) is funded before the wage
				# reserve. Firms living month to month on one wage bill of cash otherwise let their plants rot.
				budgets[oid] = maxi(0, bal - reserve) + mini(maxi(0, bal), int(upkeep_val.get(oid, 0)))
			if o["status"] == "ADMINISTRATION" and not EconUtil.off(world, "E119"):
				# E119 (Wilma): the administrator runs the business — inputs are bought out of revenue (last month's sales),
				# not out of cash above the wage bill, which starved every plant of a big employer in administration
				var rev := int(o["pl_last"].get("rev", 0)) if not o.get("pl_last", {}).is_empty() else 0
				# (when the plants already stand idle there is no revenue: restart from up to a quarter of the cash)
				budgets[oid] = maxi(int(budgets[oid]), mini(maxi(0, bal), maxi(int(float(rev) * ADMIN_INPUT_SHARE), maxi(0, bal) / 4)))
		var want: int = needs[k] - EconUtil.inv_get(world, oid, good, d)
		var distressed: bool = o["status"] != "ACTIVE"
		var freight_allow := 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
		# a distressed firm bids tight (1.1×) for production inputs, but E116: not for upkeep parts. Sellers' asks
		# sit at their unit-cost floor above 1.1× price, so a tight bid never fills and the plants rot.
		var tight := distressed and not (e116 and good in ["MATERIAL", "COMPONENT"])
		if o["status"] == "ADMINISTRATION" and not EconUtil.off(world, "E119"):
			tight = false  # E119: an administrator buys at normal terms (a tight bid never fills)
		var lim := int(s["prices"][good] * (1.1 if tight else EconData.INPUT_LIMIT_MULT)) + freight_allow
		if o["type"] in EconData.PUBLIC_TYPES:
			lim = s["prices"][good] * 2 + freight_allow  # public services and utilities outbid industry for inputs
		if good == "FOOD" and bakery_orgs.has(oid) and not EconUtil.off(world, "D2"):
			# D2 (Wilma): a bakery pays for food only what its fine food earns (1.2 per unit of food, at BAKERY_FOOD_SHARE of
			# the value; a corner-cutting CEO pays more). In a shortage food outprices cakes and bakeries cut back by
			# themselves; strong fine-food demand from the rich, or a greedy owner, can still keep them buying.
			var share := BAKERY_FOOD_SHARE_GREEDY if int(o["ceo"].get("risk", 50)) >= 70 else BAKERY_FOOD_SHARE
			lim = mini(lim, int(float(s["prices"].get("FINE_FOOD", 0)) * BAKERY_YIELD * share))
		var cost_needed := EconUtil.val(maxi(want, 0), lim)
		if cost_needed > budgets[oid] and o["type"] in ["PRIVATE", "COOPERATIVE"]:
			budgets[oid] += _working_capital(world, oid, cost_needed - budgets[oid])
		var up_want := mini(maxi(0, want), int(upkeep_qty.get(k, 0)))
		want = mini(want, int(float(maxi(0, budgets[oid])) * S / float(maxi(1, lim))))
		if e116 and up_want > 0:
			# E116: the upkeep part is its own order, always posted at the normal input limit (not the distressed 1.1×; a 2×
			# bid was tried and drove material prices up for everyone). Wages leave a
			# month-to-month firm with no cash at order time, but its sales come in at TRADE before materials clear (FOOD
			# first) and the fill takes only what it can pay.
			var up_lim: int = maxi(lim, int(float(s["prices"][good]) * EconData.INPUT_LIMIT_MULT) + freight_allow)
			s["orders"].append({"buyer": oid, "acct": EconUtil.acct(oid), "district": d, "good": good, "qty": up_want, "limit": up_lim,
				"class": EconMarket.C_INSTITUTION if o["type"] == "PUBLIC_INSTITUTION" else EconMarket.C_FIRM, "kind": "org"})
			budgets[oid] -= EconUtil.val(up_want, up_lim)
			want = mini(want, int(float(maxi(0, budgets[oid])) * S / float(maxi(1, lim))))
			want = mini(want, needs[k] - EconUtil.inv_get(world, oid, good, d) - up_want)
		if want <= 0:
			continue
		budgets[oid] -= EconUtil.val(want, lim)
		s["orders"].append({"buyer": oid, "acct": EconUtil.acct(oid), "district": d, "good": good, "qty": want, "limit": lim,
			"class": EconMarket.C_INSTITUTION if o["type"] == "PUBLIC_INSTITUTION" else EconMarket.C_FIRM, "kind": "org"})
	# sale offers: each org offers its output goods' stock, priced by inventory cover
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		var outs := _org_outputs(world, oid)
		for good in EconUtil.sorted_keys(outs):
			var ema := float(o["sales_ema"].get(good, outs[good]))
			for d in EconUtil.sorted_keys(EconData.DISTRICTS):
				var q := EconUtil.inv_get(world, oid, good, d)
				if q <= 0:
					continue
				var cover := float(_org_stock(world, oid, good)) / maxf(1.0, ema)
				var m := 1.05 if cover < 0.5 else (1.0 if cover <= 2.0 else (0.95 if cover <= 4.0 else 0.90))
				var ask := int(float(s["prices"][good]) * m)
				# floor: full unit cost (labor included), 90% when active, 70% when distressed; never below material cost
				var ftype := _type_of_output(world, oid, good)
				var full := unit_cost(world, ftype) if ftype != "" else 0.0
				var floor_c := maxi(EconUtil.inv_wac(world, oid, good, d), int(full * (0.9 if o["status"] == "ACTIVE" else 0.7)))
				ask = maxi(ask, floor_c)
				s["offers"].append({"seller": oid, "acct": EconUtil.acct(oid), "district": d, "good": good, "qty": q, "ask": ask})


## Delegated award: tenders open for >= 1 month with bids are awarded to the top score
## unless world.meta["manual_award"] is set (player chooses via ECON_AWARD_CONTRACT).
static func _auto_award(world: WorldState) -> void:
	for pid in EconUtil.sorted_keys(world.table("project")):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] != "TENDER" or p["bids"].is_empty():
			continue
		if p["owner"] == "gov" and world.meta.get("manual_award", false) and world.month - p["tender_month"] < 3:
			continue
		var ranked := EconConstruction.ranked_bids(world, p)
		EconConstruction.award(world, pid, ranked[0]["org"])


static func _ceo_turnover(world: WorldState) -> void:
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		var ceo: Dictionary = o["ceo"]
		ceo["age_m"] += 1
		var reason := ""
		if ceo["age_m"] >= 65 * 12:
			reason = "RETIREMENT"
		elif o["distress_months"] >= 6 and o["type"] in ["PRIVATE", "COOPERATIVE"]:
			reason = "DISTRESS"
		if reason == "":
			continue
		var m := int(clampf(50.0 + EconUtil.normal(world, "comp.ceo", 15.0), 10.0, 95.0))
		var old: int = ceo["mgmt"]
		o["ceo"] = {"mgmt": m, "risk": ceo["risk"], "age_m": 45 * 12}
		if reason == "DISTRESS":
			o["distress_months"] = 0
		EconFacts.emit(world, "COMP_CEO_REPLACED", world.table("org")[oid]["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {},
			25 if reason == "DISTRESS" else 10, "PUBLIC", {"reason": reason, "old_mgmt": old, "new_mgmt": m})


## Bank working-capital line (E48): 12-month loan for inputs, capped at 2× last month's revenue and 60% leverage.
static func _working_capital(world: WorldState, oid: String, amount: int) -> int:
	var o: Dictionary = world.table("org")[oid]
	if not (o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]):  # administrators get debtor-in-possession credit
		return 0
	for lid in world.table("loan"):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and l["missed"] > 0:
			return 0
	var rev: int = o["pl_last"].get("rev", 0)
	var assets := world.ledger.balance(EconUtil.acct(oid))
	for fid in world.table("facility"):
		if world.table("facility")[fid]["org"] == oid:
			assets += world.table("facility")[fid]["book"]
	var debt := EconFinance.debt_of(world, oid)
	var amt := mini(amount, maxi(0, 2 * rev))
	amt = mini(amt, maxi(0, int(0.6 * float(assets)) - debt))
	if amt < 1000 * S:
		return 0
	if not EconFinance.new_loan(world, oid, amt, 0, true):
		return 0
	var lid_last := ""
	for lid in EconUtil.sorted_keys(world.table("loan")):
		if world.table("loan")[lid]["borrower"] == oid:
			lid_last = lid
	world.table("loan")[lid_last]["term_left"] = 12
	return amt


static func _type_of_output(world: WorldState, oid: String, good: String) -> String:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and EconData.RECIPES[f["type"]]["out"][0] == good:
			return f["type"]
	return ""


## Unit full cost (mcr/unit) of a facility type at current prices.
static func unit_cost(world: WorldState, ftype: String) -> float:
	var s := EconUtil.st(world)
	var r: Dictionary = EconData.RECIPES[ftype]
	var c := 0.0
	for t in r["labor"]:
		c += float(r["labor"][t]) * float(s["wage"][t])
	for g in r["in"]:
		if g in EconData.MARKET_GOODS:
			c += float(r["in"][g]) * float(s["prices"][g])
		elif g == "ENERGY":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_ENERGY", 40)) * S
		elif g == "WATER":
			c += float(r["in"][g]) * float(EconUtil.lever(world, "ECON_UTILITY_TARIFF_WATER", 20)) * S
	c += float(r["upkeep"]) * float(s["prices"]["MATERIAL"])
	if EconData.BUILD.has(ftype):
		c += float(EconConstruction.estimate(ftype)) / EconData.DEPRECIATION_MONTHS
	return c / float(r["out"][1])


static func _investment(world: WorldState) -> void:
	var s := EconUtil.st(world)
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not (o["type"] in ["PRIVATE", "COOPERATIVE"]) or o["status"] != "ACTIVE" or o["is_contractor"]:
			continue
		if world.month - o.get("last_invest", -24) < 12:
			continue
		var by_type := {}
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["org"] == oid and EconData.RECIPES[f["type"]]["out"][0] in EconData.MARKET_GOODS:
				if not by_type.has(f["type"]):
					by_type[f["type"]] = []
				by_type[f["type"]].append(f)
		for ftype in EconUtil.sorted_keys(by_type):
			var all_high := true
			for f in by_type[ftype]:
				if f["high_util_m"] < 6:
					all_high = false
			var good: String = EconData.RECIPES[ftype]["out"][0]
			if not all_high or float(s["prices"][good]) < 1.10 * unit_cost(world, ftype):
				continue
			if EconEssentials.overbuilt(world, good):
				continue  # E115b: the colony already has far more of this than it uses
			if not EconUtil.off(world, "E113") and EconConstruction.has_open_project(world, oid, ftype):
				continue  # E113: one open project per owner and plant type
			var est := EconConstruction.estimate(ftype)
			var cash := world.ledger.balance(EconUtil.acct(oid))
			if cash < est * 3 / 10:
				continue
			var lev_cap := 0.3 + 0.4 * float(o["ceo"]["risk"]) / 100.0
			var assets := cash
			for f in by_type[ftype]:
				assets += f["book"]
			if float(EconFinance.debt_of(world, oid) + est * 7 / 10) / float(maxi(1, assets + est)) > lev_cap:
				continue
			if not LawBridge.allowed(world, oid, "BUILD_FACILITY", {"facility_type": ftype, "district": by_type[ftype][0]["district"],
					"owner_kind": "COMPANY", "value_wref": est / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
				continue
			if not EconFinance.new_loan(world, oid, est * 7 / 10, 0, true):
				continue
			EconConstruction.create(world, ftype, by_type[ftype][0]["district"], oid, oid, "")
			o["last_invest"] = world.month
			break


static func colony_unemployment(world: WorldState) -> float:
	var lf := 0
	var emp := 0
	for gid in world.table("hh"):
		lf += world.table("hh")[gid]["lf"]
		emp += EconLabor.employed(world.table("hh")[gid])
	return 0.0 if lf == 0 else float(lf - emp) / float(lf)


## E54 growth engine (a): idle labour + 3 steady months at ≥ 85% → +25% capacity step via a small project.
static func _expansion(world: WorldState) -> void:
	var idle := colony_unemployment(world) >= 0.06
	var s := EconUtil.st(world)
	var pending := {}
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "EXPAND" and p["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
			pending[p["target"]] = true
	var started := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		if started >= 2:
			break
		var f: Dictionary = world.table("facility")[fid]
		var o: Dictionary = world.table("org").get(f["org"], {})
		var pe_ok: bool = o.get("type", "") == "PUBLIC_ENTERPRISE" and int(EconUtil.lever(world, "ECON_PE_EXPANSION", 1)) > 0 \
			and f["type"] in EconData.STRATEGIC and not (f["type"] in ["POWER", "WATERWORKS"])
		if o.is_empty() or not (o["type"] in ["PRIVATE", "COOPERATIVE"] or pe_ok) or o["status"] != "ACTIVE" or pending.has(fid):
			continue
		if f["mothball"] or f.get("steady_m", 0) < 3 or f.get("scale", 1000) >= 3000 or not EconData.BUILD.has(f["type"]):
			continue
		if world.month - o.get("last_expand", -6) < 6:
			continue
		var good: String = EconData.RECIPES[f["type"]]["out"][0]
		var price := float(s["svc_price"].get(f["district"], 0)) if good == "SERVICES" else float(s["prices"].get(good, 0))
		if not (good in EconData.MARKET_GOODS or good == "SERVICES") or price < unit_cost(world, f["type"]):
			continue
		if EconEssentials.overbuilt(world, good):
			continue  # E115b
		if not idle and price < 1.2 * unit_cost(world, f["type"]):
			continue  # without idle labour, only a strong price signal justifies expansion
		if pe_ok and price < 1.3 * unit_cost(world, f["type"]):
			continue  # E68: public enterprises expand strategic plants only on a clear shortage price
		var cost := EconConstruction.estimate(f["type"]) / 4
		var acc := EconUtil.acct(f["org"])
		if world.ledger.balance(acc) < cost * 3 / 10:
			continue
		if world.ledger.balance(acc) < cost:
			if not EconFinance.new_loan(world, f["org"], cost * 7 / 10, 0, true):
				continue
		EconConstruction.create_expansion(world, fid, f["org"])
		o["last_expand"] = world.month
		started += 1


## E54 growth engine (b): small-business formation. Unemployed + household savings → a micro service co-op (¼ hub).
static func _small_business(world: WorldState) -> void:
	if colony_unemployment(world) < 0.08 or world.month % 3 != 0:
		return
	var s := EconUtil.st(world)
	# E77: no churn — a district gets a new micro co-op at most every 18 months, and only while the existing ones
	# are healthy (a dying micro co-op means local services demand is not there)
	for oid in world.table("org"):
		var om: Dictionary = world.table("org")[oid]
		if om["key"].begins_with("MICRO") and om["status"] in ["DISTRESSED", "ADMINISTRATION", "LIQUIDATION"]:
			return
	var best := ""
	var best_u := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["band"] in ["I4", "I5"]:
			continue
		var u := maxi(0, g["lf"] - EconLabor.employed(g))
		if u > best_u and world.ledger.balance(EconUtil.hh_acct(gid)) >= 20000 * S:
			best_u = u
			best = gid
	if best == "" or best_u < 10 * S:
		return
	var g: Dictionary = world.table("hh")[best]
	var d: String = g["district"]
	if world.month - int(s.get("micro_last", {}).get(d, -100)) < 18:
		return
	if float(s["svc_price"].get(d, 0)) < 1.0 * EconData.BASE_SERVICES_PRICE * S:
		return  # local services already saturated
	var n_micro := 0
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if o["key"].begins_with("MICRO") and o["hq"] == d and o["status"] in ["ACTIVE", "DISTRESSED"]:
			n_micro += 1
	if n_micro >= 2:
		return
	var id := world.new_id("org")
	world.table("org")[id] = {"id": id, "key": "MICRO_" + id, "name": EconUtil.firm_name(world, d, "TRADERS", "Co-op"),
		"type": "COOPERATIVE", "hq": d, "status": "ACTIVE", "ceo": {"mgmt": 45, "risk": 30, "age_m": 35 * 12}, "reliability": 0,
		"is_contractor": false, "crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": best, "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(id))
	world.ledger.transfer(EconUtil.hh_acct(best), EconUtil.acct(id), 20000 * S, "EQUITY", world.month)
	var fid := EconSetup.add_facility(world, "SERVICEHUB", id, d, false)
	world.table("facility")[fid]["scale"] = 250
	world.table("facility")[fid]["book"] = 20000 * S
	world.table("facility")[fid]["svc_sold"] = 300 * S
	var ml: Dictionary = s.get("micro_last", {})
	ml[d] = world.month
	s["micro_last"] = ml
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", d, [["COMPANY", id]], [["COMPANY", id, 0.8], ["GOVERNMENT", "government", 0.2]],
		{"JOBS": 2}, 10, "PUBLIC", {"type": "SERVICEHUB", "micro": true}, {"districts": [d]})


## E102 (user, 2026-11-11): firms decide their own investment in NEW plants — "a power company might want to build
## another station". Each quarter a scarcity signal per product: market goods when the price is ≥ 1.3× unit cost and
## buyers got < 90% of what they wanted, or < 75% at any price; power/water when demand exceeds 85% of supply. After
## NEW_PLANT_QUARTERS quarters of scarcity the richest active owner of that plant type (public enterprises included)
## commissions a new plant, financed from cash, a bank loan (70%), or for a public enterprise a treasury request.
## At most one new plant per type every NEW_PLANT_GAP months.
const PLANT_FOR := {"FOOD": "FARM", "MINERAL": "MINE", "MATERIAL": "PROCESSING", "COMPONENT": "COMPONENTS", "CONSUMER": "CONSUMERF",
	"MEDICAL": "MEDWORKS", "ENERGY": "POWER", "WATER": "WATERWORKS", "CLOTHING": "TEXTILE", "FURNISHINGS": "FURNITURE", "FINE_FOOD": "BAKERY"}


static func _new_plants(world: WorldState) -> void:
	if EconUtil.off(world, "E102"):
		return
	var s := EconUtil.st(world)
	var sig: Dictionary = s.get("scarce_q", {})
	s["scarce_q"] = sig
	var last: Dictionary = s.get("new_plant_last", {})
	s["new_plant_last"] = last
	for good in EconUtil.sorted_keys(PLANT_FOR):
		var ftype: String = PLANT_FOR[good]
		var scarce := false
		if good in ["ENERGY", "WATER"]:
			var k := "E" if good == "ENERGY" else "W"
			scarce = float(s.get("util_demand", {}).get(k, 0)) > 0.85 * float(maxi(1, s.get("util_supply", {}).get(k, 1)))
		else:
			var fill := int(s.get("fill_last", {}).get(good, 1000))
			# E110: an open incentive offer is co-financing — a lower price threshold and fill bar
			var e110 := not EconUtil.off(world, "E110")
			var incent: bool = e110 and EconEssentials.offer_open(world, ftype)
			var pmult := 1.1 if incent else 1.3
			scarce = fill < 750 or (fill < (1000 if incent else 900) and float(s["prices"].get(good, 0)) >= pmult * unit_cost(world, ftype))
			if e110 and good == "FOOD" and int(s.get("food_shortfall", 0)) >= 50:
				scarce = true  # households ration food at high prices, so market fill hides the gap
		if scarce and EconEssentials.overbuilt(world, good):
			scarce = false  # E115b: a price spike over idle capacity is a supply hiccup, not a reason for a new plant
		sig[good] = int(sig.get(good, 0)) + 1 if scarce else 0
		var quarters := 1 if not EconUtil.off(world, "E110") and EconEssentials.offer_open(world, ftype) else EconData.NEW_PLANT_QUARTERS
		if int(sig[good]) < quarters or world.month - int(last.get(ftype, -999)) < EconData.NEW_PLANT_GAP:
			continue
		if not EconUtil.off(world, "E110") and EconEssentials.labour_fill(world, ftype) < EconEssentials.MIN_LABOUR_FILL:
			continue  # E110: no plant that cannot be staffed
		var pending := false
		for pid in world.table("project"):
			var p: Dictionary = world.table("project")[pid]
			if p["type"] == ftype and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
				pending = true
		if pending:
			continue
		# investor: the richest active owner of this plant type
		var best := ""
		var best_cash := -1
		var district := ""
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["type"] != ftype:
				continue
			var o: Dictionary = world.table("org").get(f["org"], {})
			if o.is_empty() or o["status"] != "ACTIVE" or o["type"] == "PUBLIC_INSTITUTION":
				continue
			var c := world.ledger.balance(EconUtil.acct(f["org"]))
			if c > best_cash:
				best_cash = c
				best = f["org"]
				district = f["district"]
		if best == "" and not EconUtil.off(world, "E110") and EconEssentials.offer_open(world, ftype):
			# E110: with a grant on offer, the richest private firm or co-op diversifies
			for oid3 in EconUtil.sorted_keys(world.table("org")):
				var o3: Dictionary = world.table("org")[oid3]
				if o3["status"] != "ACTIVE" or o3["is_contractor"] or not (o3["type"] in ["PRIVATE", "COOPERATIVE"]):
					continue
				var c3 := world.ledger.balance(EconUtil.acct(oid3))
				if c3 > best_cash:
					best_cash = c3
					best = oid3
					district = o3["hq"]
		if best == "":
			continue  # nobody runs this kind of plant: firm entry (_entry) covers new owners
		var est := EconConstruction.estimate(ftype)
		if not LawBridge.allowed(world, best, "BUILD_FACILITY", {"facility_type": ftype, "district": district, "owner_kind": "COMPANY",
				"value_wref": est / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
			continue
		var o2: Dictionary = world.table("org")[best]
		var need := maxi(0, est - world.ledger.balance(EconUtil.acct(best)))
		if need > 0:
			var loan := mini(need, est * 7 / 10)
			if not EconFinance.new_loan(world, best, loan, 0, true):
				if o2["type"] == "PUBLIC_ENTERPRISE" and not (not EconUtil.off(world, "E110") and EconEssentials.human_governs(world)):
					var paid := EconFinance.gov_pay(world, EconUtil.acct(best), need, "PE_INVESTMENT")
					EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
					if paid < need / 2:
						continue
				else:
					continue
		var pid2 := EconConstruction.create(world, ftype, district, best, best, "")
		last[ftype] = world.month
		sig[good] = 0
		EconFacts.emit(world, "COMP_INVESTMENT", district, [["COMPANY", best]], [["COMPANY", best, 1.0]], {"JOBS": 3}, 20, "PUBLIC",
			{"type": ftype, "project": pid2, "reason": "scarcity", "good": good})


## E105 (Wilma-approved): the public utility (CPW) is planner of last resort for the essentials chain. Each quarter it
## compares capacity with demand for power, water, materials and components; if spare capacity is below
## ESSENTIAL_SPARE it commissions a new plant AHEAD of the price signal, financed from its cash, a bank loan or the
## treasury (public utility). One plant per type per ESSENTIAL_GAP months; nothing if one is already being built.
static func _essentials_planner(world: WorldState) -> void:
	if EconUtil.off(world, "E105"):
		return
	var s := EconUtil.st(world)
	var cpw := EconFinance.org_by_key(world, "CPW")
	if cpw == "" or world.table("org")[cpw]["status"] in ["LIQUIDATION", "DISSOLVED"]:
		return
	var last: Dictionary = s.get("essential_last", {})
	s["essential_last"] = last
	var e110 := not EconUtil.off(world, "E110")
	# E110 (Wilma, user rules): food is a political decision — farms are built only when a government commissions
	# them or a firm invests, never by this automatic floor (famine must stay possible).
	var types: Array = ["POWER", "WATERWORKS", "PROCESSING", "COMPONENTS"]
	var ess: Dictionary = EconEssentials.measure(world) if e110 else {}
	for ftype in types:
		if world.month - int(last.get(ftype, -999)) < EconData.ESSENTIAL_GAP:
			continue
		var r: Dictionary = EconData.RECIPES[ftype]
		var good: String = r["out"][0]
		var cap := 0.0
		var demand := 0.0
		var district := ""
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["type"] == ftype:
				district = f["district"]
				break
		if e110:
			cap = float(ess[good]["capacity"])
			demand = float(ess[good]["demand"])
		else:
			for fid in EconUtil.sorted_keys(world.table("facility")):
				var f: Dictionary = world.table("facility")[fid]
				if f["type"] == ftype and not f["mothball"]:
					cap += float(r["out"][1]) * S * EconUtil.fscale(f) * EconProduction._eff(world, f)
			match ftype:
				"POWER": demand = float(s.get("util_demand", {}).get("E", 0))
				"WATERWORKS": demand = float(s.get("util_demand", {}).get("W", 0))
				_: demand = float(s.get("wanted_ema", {}).get(good, 0))
		if demand <= 0.0 or cap >= demand * (1.0 + EconData.ESSENTIAL_SPARE):
			continue
		# E110: no plant that cannot be staffed — unless a survival good is in outright deficit
		if e110 and EconEssentials.labour_fill(world, ftype) < EconEssentials.MIN_LABOUR_FILL 				and not (good in ["FOOD", "ENERGY", "WATER"] and cap < demand):
			continue
		var pending := false
		for pid in world.table("project"):
			var p: Dictionary = world.table("project")[pid]
			if (p["type"] == ftype or (p["type"] == "UPGRADE" and world.table("facility").has(p.get("target", "")) 					and world.table("facility")[p["target"]]["type"] == ftype)) and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
				pending = true
		if pending:
			continue
		var owner: String = EconEssentials.ag_board(world) if ftype == "FARM" else cpw
		# E106: for fabrication kits, upgrading CPW's lowest-tier kit comes before building a new one
		var up_fid := ""
		if ftype in EconData.KIT_TYPES and not EconUtil.off(world, "E106"):
			var low := 3
			for fid in EconUtil.sorted_keys(world.table("facility")):
				var kf: Dictionary = world.table("facility")[fid]
				if kf["type"] == ftype and kf["org"] == cpw and not kf["mothball"] and int(kf.get("tier", 2)) < low 						and not EconConstruction.upgrade_pending(world, fid):
					low = int(kf.get("tier", 2))
					up_fid = fid
		var est := EconConstruction.upgrade_estimate(int(world.table("facility")[up_fid].get("tier", 2)) + 1) if up_fid != "" else EconConstruction.estimate(ftype)
		var need := maxi(0, est - world.ledger.balance(EconUtil.acct(owner)))
		if need > 0 and not EconFinance.new_loan(world, owner, mini(need, est * 7 / 10), 0, true):
			if e110 and EconEssentials.human_governs(world):
				continue  # E110: no treasury money behind a human government's back
			var paid := EconFinance.gov_pay(world, EconUtil.acct(owner), need, "PE_INVESTMENT")
			EconFinance._spend_line(world, "ECON_BUDGET_INFRASTRUCTURE", paid)
		var home := district if district != "" else ("d:2" if ftype == "FARM" else "d:4")
		var pid2 := EconConstruction.create_upgrade(world, up_fid, owner, "") if up_fid != "" else EconConstruction.create(world, ftype, home, owner, owner, "")
		last[ftype] = world.month
		EconFacts.emit(world, "COMP_INVESTMENT", home, [["COMPANY", owner]], [["COMPANY", owner, 0.5], ["GOVERNMENT", "government", 0.5]],
			{"JOBS": 3, "INFRASTRUCTURE": 5}, 25, "PUBLIC", {"type": ftype, "project": pid2, "reason": "spare_capacity", "good": good,
			"capacity_pct": int(100.0 * cap / maxf(0.001, demand))})


## E87 (O-1): construction firm entry. When projects queue without bids and no private builder is alive, a new
## builder is founded with capital from the richest household pool (the construction sector otherwise died for good
## after the founding boom and every expansion stalled).
const STALE_TENDER_M := 3  # E117a: months a tender sits without a bid before it counts as unmet construction demand
const MAX_FORMING := 3  # D2: new companies being set up at once (was 1; the consumer industries waited years in line)
const ADMIN_INPUT_SHARE := 0.6  # E119: share of last month's revenue an administrator spends on inputs
const BAKERY_YIELD := 1.2  # D2: fine food made per unit of food (BAKERY recipe 300 out / 250 in)
const BAKERY_FOOD_SHARE := 0.6  # of the fine-food value a bakery will pay for its food
const BAKERY_FOOD_SHARE_GREEDY := 0.8  # a corner-cutting CEO (risk ≥ 70) keeps buying longer
const D2_ENTRY_UNEMP := 0.06
const D2_ENTRY_MONTH := 24  # the founding years build essentials first


static func _builder_entry(world: WorldState) -> void:
	if EconUtil.off(world, "E87"):
		return
	var s := EconUtil.st(world)
	if world.month - int(s.get("builder_entry_last", -100)) < 12:
		return
	var waiting := 0
	var stale := 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] == "TENDERABLE" or (p["status"] == "TENDER" and p["bids"].is_empty()):
			waiting += 1
		if p["status"] == "TENDER" and p["bids"].is_empty() and world.month - int(p.get("tender_month", world.month)) >= STALE_TENDER_M:
			stale += 1
	if EconConstruction._private_builder_alive(world):
		# E117a (Wilma): the existing builders are at their crew ceiling and tenders sit unbid — a new builder enters
		# (same founding as E87: equity from the richest household pool, at most one per 12 months)
		if EconUtil.off(world, "E117") or stale < EconData.BUILDER_ENTRY_BACKLOG:
			return
	elif waiting < EconData.BUILDER_ENTRY_BACKLOG:
		return
	var best := ""
	var best_cash := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		var c := world.ledger.balance(EconUtil.hh_acct(gid))
		if g["nonpart"] >= S and c > best_cash:
			best_cash = c
			best = gid
	var equity := EconData.BUILDER_EQUITY * S
	if best == "" or best_cash < equity * 2:
		return
	var g: Dictionary = world.table("hh")[best]
	var d: String = g["district"]
	var id := world.new_id("org")
	var mgmt := int(clampf(50.0 + EconUtil.normal(world, "comp.entry", 15.0), 10.0, 95.0))
	var risk := world.rng.stream("comp.entry").randi_range(20, 70)
	world.table("org")[id] = {"id": id, "key": "BUILD_" + id, "name": EconUtil.firm_name(world, d, "CONTRACTOR", "Ltd"),
		"type": "PRIVATE", "hq": d, "status": "ACTIVE", "ceo": {"mgmt": mgmt, "risk": risk, "age_m": 40 * 12}, "reliability": 50,
		"is_contractor": true, "crew": {"G": {}, "S": {}, "Sp": {}}, "crew_target": EconData.BUILDER_CREW.duplicate(),
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": best, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(id))
	world.ledger.transfer(EconUtil.hh_acct(best), EconUtil.acct(id), equity, "EQUITY", world.month)
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	s["builder_entry_last"] = world.month
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", d, [["COMPANY", id]], [["COMPANY", id, 0.8], ["GOVERNMENT", "government", 0.2]],
		{"JOBS": 3, "INFRASTRUCTURE": 2}, 20, "PUBLIC", {"type": "CONTRACTOR", "waiting_projects": waiting}, {"districts": [d]})


## Firm entry (spec §9.4): at most one per quarter, when a good is scarce and pricey.
static func _entry(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var hist: Dictionary = s.get("entry_signal", {})
	var hot_list: Array = []  # [ftype, price / unit cost]
	var svc_district := "d:1"
	for ftype in ["FARM", "CONSUMERF", "SERVICEHUB", "PROCESSING", "MINE", "TEXTILE", "FURNITURE", "BAKERY"]:  # D2: consumer workshops
		var good: String = EconData.RECIPES[ftype]["out"][0]
		var price := float(s["prices"].get(good, 0))
		if good == "SERVICES":
			# the dearest district (a new hub is built there; the old code read d:1 and built in the founder's district,
			# so hubs piled up where they were not needed while d:1 stayed "hot")
			price = 0.0
			for dd in EconUtil.sorted_keys(s["svc_price"]):
				if float(s["svc_price"][dd]) > price:
					price = float(s["svc_price"][dd])
					svc_district = dd
		var uc := unit_cost(world, ftype)
		var hot := price >= 1.25 * uc
		hist[ftype] = hist.get(ftype, 0) + 1 if hot else 0
		if hist[ftype] >= 2:
			hot_list.append([ftype, price / maxf(1.0, uc)])
	s["entry_signal"] = hist
	if hot_list.is_empty():
		return
	var forming := 0
	var forming_types := {}  # sectors with an entrant already being set up
	for oid in world.table("org"):
		if world.table("org")[oid]["status"] == "FORMING":
			for pid in world.table("project"):
				if world.table("project")[pid]["owner"] == oid:
					forming_types[world.table("project")[pid]["type"]] = true
			forming += 1
	var u_now := colony_unemployment(world)
	var max_forming := mini(MAX_FORMING, 1 + (1 if u_now >= 0.08 else 0) + (1 if u_now >= 0.12 else 0))  # more entrants only with idle hands
	if forming >= max_forming:
		return  # E77: a few entrants at a time (each needs a builder and a market); D2: was one
	# founder capital from the richest high-income household pool with an adult outside the labour force
	var best := ""
	var best_cash := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g0: Dictionary = world.table("hh")[gid]
		if g0["band"] in ["I4", "I5"] and g0["nonpart"] >= S:
			var c := world.ledger.balance(EconUtil.hh_acct(gid))
			if c > best_cash:
				best_cash = c
				best = gid
	if best == "":
		return
	var g: Dictionary = world.table("hh")[best]
	# D2: try every hot sector, the most profitable first (a blocked one no longer stops the others)
	hot_list.sort_custom(func(a, b): return float(a[1]) > float(b[1]) or (float(a[1]) == float(b[1]) and str(a[0]) < str(b[0])))
	var candidate := ""
	var district := ""
	var est := 0
	for row in hot_list:
		var ft: String = row[0]
		if ft in ["TEXTILE", "FURNITURE", "BAKERY"] and (world.month < D2_ENTRY_MONTH or colony_unemployment(world) < D2_ENTRY_UNEMP):
			continue  # D2: consumer workshops start once there are idle hands (not while the farms still need every worker)
		if forming_types.has(ft):
			continue
		var e := EconConstruction.estimate(ft)
		var d: String = "d:3" if ft == "MINE" else (svc_district if ft == "SERVICEHUB" else g["district"])
		if best_cash < e * 4 / 10:
			continue
		if not LawBridge.allowed(world, "new", "BUILD_FACILITY", {"facility_type": ft, "district": d, "owner_kind": "COMPANY", "value_wref": 0}):
			continue
		candidate = ft
		district = d
		est = e
		break
	if candidate == "":
		return
	var id := world.new_id("org")
	var mgmt := int(clampf(50.0 + EconUtil.normal(world, "comp.entry", 15.0), 10.0, 95.0))
	var risk := world.rng.stream("comp.entry").randi_range(20, 80)
	world.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": EconUtil.firm_name(world, district, candidate, "Ltd"), "type": "PRIVATE",
		"hq": district, "status": "FORMING", "ceo": {"mgmt": mgmt, "risk": risk, "age_m": 40 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(),
		"pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": best, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(id))
	world.ledger.transfer(EconUtil.hh_acct(best), EconUtil.acct(id), est * 4 / 10, "EQUITY", world.month)
	EconPop.make_owner(world, g["hb"], g["band"])
	EconPop.sync(world)
	if not EconFinance.new_loan(world, id, est * 6 / 10, 0, true):
		pass  # builds with equity only; may stall on payments
	EconConstruction.create(world, candidate, district, id, id, "")
	EconFacts.emit(world, "COMP_COMPANY_FOUNDED", district, [["COMPANY", id]], [["COMPANY", id, 0.8], ["GOVERNMENT", "government", 0.2]],
		{"JOBS": 3}, 15, "PUBLIC", {"type": candidate}, {"districts": [district]})
	hist[candidate] = 0


## E120: private housing developers. Each quarter the most crowded district (occupancy ≥ DEV_OCC) gets a housing
## project from the richest company that can finance it (30% cash, 70% bank loan), at most one per district every
## DEV_GAP months and none while one is being built there. The homes are let at the private rent (EconFinance).
const DEV_OCC := 1050
const DEV_GAP := 12


static func _developers(world: WorldState) -> void:
	if EconUtil.off(world, "E120"):
		return
	var s := EconUtil.st(world)
	var last: Dictionary = s.get("dev_last", {})
	s["dev_last"] = last
	var best_d := ""
	var best_occ := DEV_OCC - 1
	for d in EconUtil.sorted_keys(world.table("district")):
		var occ := int(world.table("district")[d].get("occupancy", 0))
		if occ > best_occ and world.month - int(last.get(d, -999)) >= DEV_GAP:
			best_occ = occ
			best_d = d
	if best_d == "":
		return
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["type"] == "HOUSING" and p["district"] == best_d and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			return
	var est := EconConstruction.estimate("HOUSING")
	var owner := ""
	var cash := 0
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["status"] != "ACTIVE" or o["is_contractor"] or not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
			continue
		var c := world.ledger.balance(EconUtil.acct(oid))
		if c >= est * 3 / 10 and c > cash:
			cash = c
			owner = oid
	if owner == "":
		return
	if not LawBridge.allowed(world, owner, "BUILD_FACILITY", {"facility_type": "HOUSING", "district": best_d, "owner_kind": "COMPANY",
			"value_wref": est / maxi(1, int(world.values.get("ECON_W_REF", 1200 * S)))}):
		return
	if not EconFinance.new_loan(world, owner, est * 7 / 10, 0, true):
		return
	var pid2 := EconConstruction.create(world, "HOUSING", best_d, owner, owner, "")
	last[best_d] = world.month
	EconFacts.emit(world, "COMP_INVESTMENT", best_d, [["COMPANY", owner]], [["COMPANY", owner, 1.0]], {"HOUSING": 5, "JOBS": 3}, 25, "PUBLIC",
		{"type": "HOUSING", "project": pid2, "reason": "crowding", "occupancy_pct": best_occ / 10})
