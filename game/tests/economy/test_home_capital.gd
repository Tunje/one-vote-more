extends TestCase
## E155 (EconMoney.found_capital, opt-in "E155"): the colony's sponsoring firms arrive with 5 years of running costs in
## cash from the home world and 5 years of upkeep parts, without start-up loans; later builders bring the same.


func _founders(w: WorldState) -> Array:
	var out := []
	for key in EconData.ORGS:
		if EconData.ORGS[key][1] in EconMoney.FOUND_KINDS:
			out.append(EconFinance.org_by_key(w, key))
	return out


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(1)
	check(not bool(EconUtil.st(sim.world).get("e155_done", false)), "nothing happens when off")
	var loans := 0
	for oid in _founders(sim.world):
		loans += EconFinance.debt_of(sim.world, oid)
	check(loans > 0, "the old start-up loans are there when off")


func test_founders_capitalised() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E155"]
	var cash0 := {}
	for oid in _founders(w):
		cash0[oid] = w.ledger.balance(EconUtil.acct(oid))
	sim.run(1)
	check(bool(EconUtil.st(w).get("e155_done", false)), "applied in the first month")
	for oid in _founders(w):
		check_eq(EconFinance.debt_of(w, oid), 0, "%s: no start-up loan" % w.table("org")[oid]["key"])
		var cost := EconMoney.founding_cost(w, oid)
		check(w.ledger.balance(EconUtil.acct(oid)) >= cost * (EconMoney.FOUND_M - 3), "%s: about 5 years of costs in cash" % w.table("org")[oid]["key"])
	check(int(EconUtil.st(w).get("e155_founding_capital", 0)) > 0, "money came from outside")
	check_eq(w.ledger.total(), 0, "ledger closed")
	var cpw := EconFinance.org_by_key(w, "CPW")
	check(EconFinance.debt_of(w, cpw) >= 0, "public enterprises untouched")
	# applied once only
	var c := int(EconUtil.st(w)["e155_founding_capital"])
	EconMoney.found_capital(w)
	check_eq(int(EconUtil.st(w)["e155_founding_capital"]), c, "once")


func test_parts_in_stock() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E155"]
	sim.run(1)
	var farm_org := EconFinance.org_by_key(w, "GREENFOLD")
	var mat := 0
	for d in EconData.DISTRICTS:
		mat += EconUtil.inv_get(w, farm_org, "MATERIAL", d)
	check(mat > 0, "upkeep parts in stock")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved (parts counted as imported)")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E155"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
