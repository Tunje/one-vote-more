extends TestCase
## R8 step 1 (EconRules, opt-in "R8"): the shared signals are measured and published, and nothing else changes.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(6)
	check(not EconUtil.st(sim.world).has("r8"), "no signals unless R8 is on")


func test_measuring_changes_nothing() -> void:
	var a := EconSim.make_econ_only(3)
	var b := EconSim.make_econ_only(3)
	b.world.meta["on"] = ["R8"]
	a.run(18)
	b.run(18)
	var sa := EconUtil.st(a.world)
	var sb := EconUtil.st(b.world)
	for g in EconUtil.sorted_keys(sa["prices"]):
		check_eq(int(sb["prices"][g]), int(sa["prices"][g]), "same price for %s" % g)
	for acct in [EconUtil.TREASURY, EconUtil.BANK]:
		check_eq(b.world.ledger.balance(acct), a.world.ledger.balance(acct), "same balance for %s" % acct)
	check_eq(PopStore.total(b.world), PopStore.total(a.world), "same population")
	check(sb.has("r8") and not sa.has("r8"), "only the signals differ")


func test_signals_are_sane() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["R8"]
	sim.run(12)
	var r8: Dictionary = EconUtil.st(w)["r8"]
	check(not (r8["goods"] as Dictionary).is_empty(), "goods by district")
	for g in r8["goods"]:
		for d in r8["goods"][g]:
			var row: Dictionary = r8["goods"][g][d]
			check(int(row["f"]) <= int(row["w"]) and int(row["u"]) == int(row["w"]) - int(row["f"]), "%s %s: filled <= wanted" % [g, d])
	check(not (r8["plants"] as Dictionary).is_empty(), "plants measured")
	for fid in r8["plants"]:
		var p: Dictionary = r8["plants"][fid]
		check(int(p["util"]) >= 0 and int(p["cost_var"]) >= 0 and int(p["reach"]) >= 0, "plant %s readings" % fid)
	for k in r8["deliver"]:
		check(int(r8["deliver"][k]) >= 0 and int(r8["deliver"][k]) <= 1000, "route %s in ‰" % k)
	check(EconRules.reachable_unfilled(w, "FOOD", "d:1") >= 0, "reachable unfilled orders readable")
	var inst := EconRules.institution_needs(w)
	check(not inst.is_empty() and inst[0].has("budget_to_serve"), "institutions' budget request rows")


func test_freight_held_is_measured() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["R8"]
	sim.run(6)
	# squeeze the trucks: almost no freight capacity, so cross-district orders are held
	for i in 3:
		EconUtil.st(w)["freight_cap"] = 10
		EconMarket.trade(w)
	var held := 0
	for g in EconUtil.st(w)["r8"]["goods"]:
		for d in EconUtil.st(w)["r8"]["goods"][g]:
			held += int(EconUtil.st(w)["r8"]["goods"][g][d]["hf"])
	check(held > 0, "orders held for want of freight are counted (%d)" % held)
