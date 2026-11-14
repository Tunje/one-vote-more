extends TestCase
## The v10 parts not covered elsewhere (all OPT-IN): E156 priced-out bread, PAYOUT12 a year's buffer before payout,
## E157 planners read effective (served, staffed) capacity, E161 farms work by hand without power.


func _firm(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and String(o.get("owner_group", "")) != "":
			return oid
	return ""


func test_e161_hand_share() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	check_eq(EconProduction.energy_factor(w, "FARM", 0.0), 0.0, "off: no power, no output")
	w.meta["on"] = ["E161"]
	check(absf(EconProduction.energy_factor(w, "FARM", 0.0) - EconProduction.HAND_SHARE) < 0.0001, "a farm works by hand without power")
	check(absf(EconProduction.energy_factor(w, "FARM", 0.5) - 0.8) < 0.0001, "half the power: linear to full")
	check(absf(EconProduction.energy_factor(w, "FARM", 1.0) - 1.0) < 0.0001, "full power: full output")
	check_eq(EconProduction.energy_factor(w, "FACTORY", 0.0), 0.0, "other plants still need power")


func test_e157_effective_capacity() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(3)
	var full := float(EconEssentials.measure(w)["FOOD"]["capacity"])
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "FARM":
			f["e_served"] = 0
	var off: Dictionary = EconEssentials.measure(w)["FOOD"]
	check(absf(float(off["capacity"]) - full) < 0.01, "off: planners read nameplate, power or not")
	w.meta["on"] = ["E157"]
	var on: Dictionary = EconEssentials.measure(w)["FOOD"]
	check(float(on["capacity"]) < 0.01 * float(on["nameplate"]), "on: a farm without power delivers nothing")
	check(absf(float(on["nameplate"]) - full) < 0.01, "nameplate still reported")
	w.meta["on"] = ["E157", "E161"]
	var hand := float(EconEssentials.measure(w)["FOOD"]["capacity"])
	check(hand > 0.5 * EconProduction.HAND_SHARE * full, "with E161 the plan counts hand farming (%.0f of %.0f)" % [hand, full])


func test_payout12_keeps_a_year() -> void:
	for on in [false, true]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["PAYOUT", "PAYOUT12"] if on else ["PAYOUT"]
		sim.run(2)
		var oid := _firm(w)
		var o: Dictionary = w.table("org")[oid]
		var costs := 1000 * EconUtil.S
		var acc := EconUtil.acct(oid)
		w.ledger.transfer(Ledger.EXTERNAL, acc, 30 * costs, "TEST", w.month)
		EconFinance._payout_surplus(w, oid, o, costs)
		var bal := w.ledger.balance(acc)
		if on:
			check(bal >= 12 * costs, "PAYOUT12: a year of costs stays in the firm")
		else:
			check(bal < 12 * costs and bal >= 2 * costs, "PAYOUT: two months stay")


func test_e156_demand_and_gate() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E146"]
	check(not EconStaple.dissatisfaction(w), "off without E156")
	check_eq(EconStaple.bread_cut(w, 100.0 * EconUtil.S, 0.0, 0, 50.0 * EconUtil.S), -1.0, "no cut when off")
	var s := EconUtil.st(w)
	# one pool: wants 10 units, price cap 300, no spare budget limit; one with a budget for part of it above food price
	s["bread_gates"] = [[10 * EconUtil.S, 300 * EconUtil.S, -1, 100 * EconUtil.S], [10 * EconUtil.S, 400 * EconUtil.S, 1000 * EconUtil.S, 100 * EconUtil.S]]
	var hi := EconStaple.demand_at(w, 350 * EconUtil.S)
	var lo := EconStaple.demand_at(w, 250 * EconUtil.S)
	check(lo > hi, "a lower price brings priced-out households back (%d > %d)" % [lo, hi])
	check(EconStaple.demand_at(w, 50 * EconUtil.S) == 20 * EconUtil.S, "below the food price everyone buys")


func test_v10_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E146", "E147", "E148", "E149", "E150", "E156", "PAYOUT", "PAYOUT12", "E157", "E161"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
