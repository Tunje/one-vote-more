extends TestCase
## E110 (user decision A39): governments secure the essentials — EconQuery.essentials, the Colony Agricultural
## Board (state farms), and ECON_OFFER_INCENTIVE grants paid on completion.


func test_essentials_query_shape() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var e := EconQuery.essentials(sim.world)
	for g in ["FOOD", "ENERGY", "WATER", "MATERIAL", "COMPONENT"]:
		check(e.has(g), "essentials has %s" % g)
		var r: Dictionary = e[g]
		for k in ["capacity", "demand", "margin_pct", "trend", "labour_fill", "incentive"]:
			check(r.has(k), "%s.%s present" % [g, k])
	check(e["FOOD"]["demand"] > 1000.0, "food demand is household need: %s" % e["FOOD"])
	check(e["FOOD"]["capacity"] > 0.0, "farms give food capacity")
	check(e["HOUSING"]["units"] > 0.0 and e["HOUSING"]["occupancy_pct"] > 0, "housing occupancy: %s" % e["HOUSING"])


func test_commission_farm_founds_agricultural_board() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	check_eq(EconFinance.org_by_key(w, "CAB"), "", "no Board before it is needed")
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 20000
	var r := EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", {"type": "FARM", "district": "d:2"})
	check(r["ok"], "farm can be commissioned: %s" % r["error"])
	sim.run(1)
	var cab := EconFinance.org_by_key(w, "CAB")
	check(cab != "", "the Colony Agricultural Board was founded")
	if cab != "":
		check_eq(w.table("org")[cab]["type"], "PUBLIC_ENTERPRISE", "the Board is a public enterprise")
		var found := false
		for pid in w.table("project"):
			var p: Dictionary = w.table("project")[pid]
			if p["type"] == "FARM" and p["operator"] == cab and p["owner"] == "gov":
				found = true
		check(found, "the farm project is operated by the Board")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_incentive_offer_and_claim() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	check(not EconActions.check(w, "ECON_OFFER_INCENTIVE", {"type": "FARM", "grant_pct": 80, "months": 24, "cap": 50000})["ok"], "grant above 50% refused")
	check(not EconActions.check(w, "ECON_OFFER_INCENTIVE", {"type": "CLINIC", "grant_pct": 20, "months": 24, "cap": 50000})["ok"], "type outside the list refused")
	var r := EconActions.enqueue(w, "ECON_OFFER_INCENTIVE", {"type": "FARM", "grant_pct": 30, "months": 24, "cap": 50000})
	check(r["ok"], "offer accepted: %s" % r["error"])
	sim.run(1)
	check(EconEssentials.offer_open(w, "FARM"), "offer is open")
	check_eq(EconQuery.essentials(w)["FOOD"]["incentive"].get("grant_pct", 0), 30, "essentials shows the offer")
	# a private farm project completes: the owner is paid 30% of the price
	var owner := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[oid]["key"] == "GREENFOLD":
			owner = oid
	var con := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[oid]["is_contractor"]:
			con = oid
			break
	var pid := EconConstruction.create(w, "FARM", "d:5", owner, owner, "")
	var p: Dictionary = w.table("project")[pid]
	p["status"] = "ACTIVE"
	p["contractor"] = con
	p["price"] = 100000 * EconUtil.S
	p["start_month"] = w.month
	w.table("org")[con]["contracts"].append(pid)
	w.levers["ECON_BUDGET_SUBSIDIES"] = 100000
	var before := w.ledger.balance(EconUtil.acct(owner))
	EconConstruction._complete(w, p)
	var gain := w.ledger.balance(EconUtil.acct(owner)) - before
	check(gain > 0 and gain <= 30000 * EconUtil.S, "grant paid, at most 30%% of price: %d" % gain)
	check_eq(w.ledger.total(), 0, "ledger closed")
