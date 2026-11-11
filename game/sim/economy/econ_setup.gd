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

	# households
	_init_households(world, org_by_key)

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
		if g["tier"] != "Sp":
			g["self_emp"] = int(float(g["lf"]) * EconData.SELF_EMP_FOUNDING)
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


static func _init_households(world: WorldState, org_by_key: Dictionary) -> void:
	var dists: Array = []
	var dweights: Array = []
	for d in EconData.DISTRICTS:
		if EconData.DISTRICTS[d]["pop"] > 0:
			dists.append(d)
			dweights.append(float(EconData.DISTRICTS[d]["pop"]))
	var lf_total := 0
	for t in EconData.LABOR_FORCE:
		lf_total += EconData.LABOR_FORCE[t]
	var nonpart_total: int = EconData.WORKING_AGE - lf_total
	var groups := {}  # "d|t" -> id
	for t in ["G", "S", "Sp"]:
		var tshare := float(EconData.LABOR_FORCE[t]) / float(lf_total)
		var lf := EconUtil.split_lr(EconData.LABOR_FORCE[t], dweights)
		var np := EconUtil.split_lr(int(round(nonpart_total * tshare)), dweights)
		var ret := EconUtil.split_lr(int(round(EconData.RETIRED * tshare)), dweights)
		var ch := EconUtil.split_lr(int(round(EconData.CHILDREN * tshare)), dweights)
		for i in dists.size():
			var gid := world.new_id("hh")
			groups["%s|%s" % [dists[i], t]] = gid
			var g := {"id": gid, "district": dists[i], "tier": t, "lf": lf[i] * S, "nonpart": np[i] * S, "retired": ret[i] * S,
				"children": ch[i] * S, "owners": 0, "unemp_long": 0, "unemp_months": 0, "bought": {}, "unmet": {},
				"income": {}, "income_last": {}, "disposable": 0, "ess_cost": 0, "rent_due": 0, "util_due": 0,
				"emp": {}, "base_income_pa": 0}
			world.table("hh")[gid] = g
			world.ledger.open_account(EconUtil.hh_acct(gid))
			var persons: float = float(lf[i] + np[i] + ret[i] + ch[i])
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), int(persons * EconData.SAVINGS_PC[t]) * S, "GRANT", world.month)
	# business owners: one per PRIVATE org, a Specialist adult (from non-participants) in the HQ district
	for oid in world.table("org"):
		var o: Dictionary = world.table("org")[oid]
		if o["type"] != "PRIVATE":
			continue
		var gid: String = groups.get("%s|Sp" % o["hq"], "")
		if gid == "":
			continue
		var g: Dictionary = world.table("hh")[gid]
		g["owners"] += S
		g["nonpart"] = maxi(0, g["nonpart"] - S)
		o["owner_group"] = gid
		world.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), EconData.OWNER_SAVINGS * S, "GRANT", world.month)
