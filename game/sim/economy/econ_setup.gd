class_name EconSetup
extends RefCounted
## Builds the month-1 colony (planning/spec-economy-v1.md §3): districts, orgs, facilities, households,
## accounts, loans, inventories, and initial staffing. Called from EconProvider.init_world (new game only).

const S := EconUtil.S


static func init_world(world: WorldState) -> void:
	var s := {
		"prices": {}, "base": {}, "svc_price": {}, "wage": {}, "qflow": {}, "orders": [], "offers": [],
		"queue": [], "import_orders": [], "pollution": {}, "spent_ytd": {}, "gov_rev_hist": [], "gov_missed_debt": 0,
		"gov_missed_wages": 0, "food_short_streak": 0, "freight_cap": 0, "cpi": 100 * S, "cpi_hist": [],
		"wage_hist": [], "basket": {}, "vac_unfilled": {"G": 0, "S": 0, "Sp": 0}, "unemp_rate": {"G": 0, "S": 0, "Sp": 0},
		"sovereign_default": false, "famine": false, "last": {}, "output_hist": [], "bank_profit_ytd": 0,
		"mineral_sales": 0, "household_util": {}, "bands": [], "debt_threshold_pp": 0, "entries_this_quarter": 0,
	}
	world.table("econ")["s"] = s
	for g in EconData.BASE_PRICE:
		s["base"][g] = EconData.BASE_PRICE[g] * S
		s["prices"][g] = EconData.BASE_PRICE[g] * S
	for t in EconData.WAGE:
		s["wage"][t] = EconData.WAGE[t] * S
	for d in EconData.DISTRICTS:
		s["svc_price"][d] = EconData.BASE_SERVICES_PRICE * S
		s["pollution"][d] = 0
	world.values["ECON_W_REF"] = EconData.WAGE["S"] * S

	# accounts
	world.ledger.open_account(EconUtil.TREASURY)
	world.ledger.open_account(EconUtil.FINES)
	world.ledger.open_account(EconUtil.BANK)
	world.ledger.transfer(Ledger.EXTERNAL, EconUtil.TREASURY, EconData.TREASURY * S, "GRANT", world.month)
	world.ledger.transfer(Ledger.EXTERNAL, EconUtil.BANK, EconData.BANK_CASH * S, "GRANT", world.month)

	# districts
	for d in EconData.DISTRICTS:
		world.table("district")[d] = {"id": d, "name": EconData.DISTRICTS[d]["name"], "households": EconData.DISTRICTS[d]["hh"] * S,
			"rent_private": EconData.PRIVATE_RENT * S, "rent_hist": [], "occupancy": 0}

	# organizations
	var org_by_key := {}
	for key in EconData.ORGS:
		var o: Array = EconData.ORGS[key]
		var id := world.new_id("org")
		org_by_key[key] = id
		var rec := {"id": id, "key": key, "name": o[0], "type": o[1], "hq": o[10], "status": "ACTIVE",
			"ceo": {"mgmt": o[4], "risk": o[5], "age_m": o[6] * 12}, "reliability": o[7],
			"is_contractor": not (o[8] as Dictionary).is_empty(), "crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0},
			"tax_loss_cf": 0, "profit_q": 0, "pl": {}, "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0,
			"distress_months": 0, "admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "",
			"sales_ema": {}, "contracts": [], "dividends_ytd": 0}
		world.table("org")[id] = rec
		world.ledger.open_account(EconUtil.acct(id))
		if o[2] > 0:
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(id), o[2] * S, "GRANT", world.month)
		if o[3] > 0:
			EconFinance.new_loan(world, id, o[3] * S, 0)
		for good in o[9]:
			EconUtil.inv_add(world, id, good, o[10], o[9][good] * S, EconData.BASE_PRICE[good] * S)
		for t in o[8]:
			rec["crew_target"][t] = o[8][t]
			rec["crew"][t] = {}

	# facilities
	for spec in EconData.FACILITIES:
		for _i in spec[3]:
			EconSetup.add_facility(world, spec[0], org_by_key[spec[1]], spec[2], true)

	# households: population leaves + household pools (M10)
	EconPop.seed_founding(world)

	# starting stocks: 1 month of output + 1 month of market inputs for each producer
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
		var out_good: String = r["out"][0]
		if out_good in EconData.MARKET_GOODS:
			EconUtil.inv_add(world, f["org"], out_good, f["district"], int(r["out"][1]) * S / 2, int(s["prices"][out_good] * 0.85))
		for g in r["in"]:
			if g in EconData.MARKET_GOODS:
				EconUtil.inv_add(world, f["org"], g, f["district"], int(r["in"][g]) * S / 2, s["prices"][g])
		if r["upkeep"] > 0:
			EconUtil.inv_add(world, f["org"], "MATERIAL", f["district"], int(r["upkeep"]) * S, s["prices"]["MATERIAL"])
		if EconData.UPKEEP_COMPONENT.get(f["type"], 0) > 0:
			EconUtil.inv_add(world, f["org"], "COMPONENT", f["district"], EconData.UPKEEP_COMPONENT[f["type"]] * S, s["prices"]["COMPONENT"])
	for g in EconData.GOV_RESERVE:
		EconUtil.inv_add(world, "gov", g, "d:1", EconData.GOV_RESERVE[g] * S, s["prices"][g])
	for g in EconData.MARKET_GOODS:
		EconUtil.qflow(world, g, "initial", EconUtil.inv_sum(world, g))

	# founding construction programme (charter-funded, already awarded): keeps contractors busy at landing
	for fc in EconData.FOUNDING_PROJECTS:
		var op := EconFinance.org_by_key(world, EconActions.OPERATOR[fc[0]])
		var pid := EconConstruction.create(world, fc[0], fc[1], "gov", op, "FOUNDING")
		var p: Dictionary = world.table("project")[pid]
		var con: String = org_by_key[fc[2]]
		var crew := 0
		for t in EconData.ORGS[fc[2]][8]:
			crew += EconData.ORGS[fc[2]][8][t]
		p["bids"] = [{"org": con, "price": p["est_cost"], "duration": maxi(p["min_months"], int(ceil(float(EconData.BUILD[fc[0]][0]) / (0.9 * crew)))), "reliability": world.table("org")[con]["reliability"]}]
		p["status"] = "TENDER"
	# founding sole proprietors (small traders, craftspeople): scenario data; afterwards entry/exit is emergent (E67)
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		for t in ["G", "S"]:
			var n := int(float(g["skill"].get(t, 0)) * EconData.SELF_EMP_FOUNDING) / S
			PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "UNEMPLOYED"}, n,
				{"occ": "BUSINESS_OWNER", "status": "EMPLOYED"}, "SELF_EMP_ENTRY", "skill:" + t)
	EconPop.sync(world)
	# initial staffing: fill all slots without hiring limits
	EconLabor.post_vacancies(world)
	EconLabor.match(world, true)
	for oid in EconUtil.sorted_keys(world.table("org")):
		var org: Dictionary = world.table("org")[oid]
		org["pl"] = EconFinance.empty_pl()
		org["sold"] = {}
		var outs := FirmAI._org_outputs(world, oid)
		for good in outs:
			org["sales_ema"][good] = outs[good]
	# month-1 market: producers offer and buy inputs, households order essentials (spec §5: TRADE uses last month's orders)
	for fid in world.table("facility"):
		world.table("facility")[fid]["svc_sold"] = int(EconData.RECIPES[world.table("facility")[fid]["type"]]["out"][1]) * S
	s["freight_cap"] = EconData.FREIGHT_FLEET_CAP * S
	for pid in EconUtil.sorted_keys(world.table("project")):
		EconConstruction.award(world, pid, world.table("project")[pid]["bids"][0]["org"])
	FirmAI._post_inputs_and_offers(world)
	EconHouseholds._post_orders(world)


static func add_facility(world: WorldState, ftype: String, org_id: String, district: String, initial: bool) -> String:
	var id := world.new_id("fac")
	var b: Array = EconData.BUILD.get(ftype, [0, 0, 0, 1])
	var book := int((b[0] * EconData.WU_COST_EST + b[1] * EconData.BASE_PRICE["MATERIAL"] + b[2] * EconData.BASE_PRICE["COMPONENT"]) * 1.15) * S
	world.table("facility")[id] = {"id": id, "type": ftype, "org": org_id, "district": district, "condition": 90 * S if initial else 100 * S,
		"T": 1000, "staff": {"G": {}, "S": {}, "Sp": {}}, "vac": {}, "mothball": false, "low_util_m": 0, "high_util_m": 0,
		"book": book, "licensed": true, "unsafe_m": 0, "util": 1000, "svc_cap": 0, "out_last": 0, "opened": world.month}
	return id

