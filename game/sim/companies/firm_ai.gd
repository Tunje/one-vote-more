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
	if world.month_of_year() % 3 == 0:
		_investment(world)
		_entry(world)
		_builder_entry(world)
	_expansion(world)
	_small_business(world)
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
		if not f["mothball"] and f["low_util_m"] >= 12:
			f["mothball"] = true
			EconFacts.emit(world, "ECON_FACILITY_MOTHBALLED", f["district"], [["COMPANY", f["org"]]],
				EconFacts.company_blame(world, f["org"], 0.7), {"JOBS": -10}, 35, "PUBLIC", {"facility": f["id"]},
				{"districts": [f["district"]]})
		elif f["mothball"] and f["T"] >= 500 and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]:
			f["mothball"] = false
			f["low_util_m"] = 0


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
	return clampf(q / cap, 0.2, 1.0)  # producers keep a 20% floor (core crew), spec §9.1 mothball rule handles real collapse


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
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
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
				needs[k] = needs.get(k, 0) + int(float(r["in"][g]) * S * t * EconUtil.fscale(f))
		if r["upkeep"] > 0:
			var k2 := "%s|MATERIAL|%s" % [f["org"], f["district"]]
			needs[k2] = needs.get(k2, 0) + int(float(r["upkeep"]) * S * EconUtil.fscale(f))
		var uc: int = EconData.UPKEEP_COMPONENT.get(f["type"], 0)
		if uc > 0:
			var k3 := "%s|COMPONENT|%s" % [f["org"], f["district"]]
			needs[k3] = needs.get(k3, 0) + int(float(uc) * S * EconUtil.fscale(f))
	var budgets := {}
	for k in EconUtil.sorted_keys(needs):
		var parts: PackedStringArray = k.split("|")
		var oid := parts[0]
		var good := parts[1]
		var d := parts[2]
		var o: Dictionary = world.table("org")[oid]
		if not budgets.has(oid):
			var reserve: int = 0 if o["type"] == "PUBLIC_INSTITUTION" else o["pl_last"].get("wages", 0)
			budgets[oid] = world.ledger.balance(EconUtil.acct(oid)) - reserve
		var want: int = needs[k] - EconUtil.inv_get(world, oid, good, d)
		var distressed: bool = o["status"] != "ACTIVE"
		var freight_allow := 3 * int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
		var lim := int(s["prices"][good] * (1.1 if distressed else EconData.INPUT_LIMIT_MULT)) + freight_allow
		if o["type"] in EconData.PUBLIC_TYPES:
			lim = s["prices"][good] * 2 + freight_allow  # public services and utilities outbid industry for inputs
		var cost_needed := EconUtil.val(maxi(want, 0), lim)
		if cost_needed > budgets[oid] and o["type"] in ["PRIVATE", "COOPERATIVE"]:
			budgets[oid] += _working_capital(world, oid, cost_needed - budgets[oid])
		want = mini(want, int(float(maxi(0, budgets[oid])) * S / float(maxi(1, lim))))
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


## E87 (O-1): construction firm entry. When projects queue without bids and no private builder is alive, a new
## builder is founded with capital from the richest household pool (the construction sector otherwise died for good
## after the founding boom and every expansion stalled).
static func _builder_entry(world: WorldState) -> void:
	if EconUtil.off(world, "E87"):
		return
	var s := EconUtil.st(world)
	if world.month - int(s.get("builder_entry_last", -100)) < 12 or EconConstruction._private_builder_alive(world):
		return
	var waiting := 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["status"] == "TENDERABLE" or (p["status"] == "TENDER" and p["bids"].is_empty()):
			waiting += 1
	if waiting < EconData.BUILDER_ENTRY_BACKLOG:
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
	var candidate := ""
	for ftype in ["FARM", "CONSUMERF", "SERVICEHUB", "PROCESSING", "MINE"]:
		var good: String = EconData.RECIPES[ftype]["out"][0]
		var price := float(s["svc_price"]["d:1"]) if good == "SERVICES" else float(s["prices"].get(good, 0))
		var hot := price >= 1.25 * unit_cost(world, ftype)
		hist[ftype] = hist.get(ftype, 0) + 1 if hot else 0
		if hist[ftype] >= 2 and candidate == "":
			candidate = ftype
	s["entry_signal"] = hist
	if candidate == "":
		return
	for oid in world.table("org"):
		if world.table("org")[oid]["status"] == "FORMING":
			return  # E77: one entrant at a time (each needs a builder and a market)
	var est := EconConstruction.estimate(candidate)
	# founder capital from the richest high-income household pool with an adult outside the labour force
	var best := ""
	var best_cash := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["band"] in ["I4", "I5"] and g["nonpart"] >= S:
			var c := world.ledger.balance(EconUtil.hh_acct(gid))
			if c > best_cash:
				best_cash = c
				best = gid
	if best == "" or best_cash < est * 4 / 10:
		return
	var g: Dictionary = world.table("hh")[best]
	var district: String = g["district"]
	if candidate == "MINE":
		district = "d:3"
	if not LawBridge.allowed(world, "new", "BUILD_FACILITY", {"facility_type": candidate, "district": district, "owner_kind": "COMPANY", "value_wref": 0}):
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
