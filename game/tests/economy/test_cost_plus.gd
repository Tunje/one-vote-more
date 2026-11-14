extends TestCase
## E149 cost-plus prices (EconMarket._cost_plus, opt-in "E149"): at most COST_PLUS_STEP a month; towards the sector
## markup over the cheapest producer's full cost.


func test_step_is_capped() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E149"]
	sim.run(2)
	var p := 1000000.0
	check(EconMarket._cost_plus(w, "FOOD", p, 0.8, 0.0) <= p * (1.0 + EconMarket.COST_PLUS_STEP) + 1.0, "a big shortage: +3% at most")
	check(EconMarket._cost_plus(w, "FOOD", p, 0.0, 1.0) >= p * (1.0 - EconMarket.COST_PLUS_STEP) - 1.0, "a glut: −3% at most")


func test_drifts_to_markup() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E149"]
	sim.run(2)
	var uc := EconMarket._cheapest_cost(w, "FOOD")
	check(uc > 0.0, "a farm's full cost")
	var target := EconMarket.MARKUP["FOOD"] * uc
	var p := target * 2.0
	for i in 60:
		p = EconMarket._cost_plus(w, "FOOD", p, 0.0, 0.0)
	check(absf(p - target) < target * 0.01, "high price drifts down to the markup (%d vs %d)" % [int(p), int(target)])
	p = target * 0.5
	for i in 60:
		p = EconMarket._cost_plus(w, "FOOD", p, 0.0, 0.0)
	check(absf(p - target) < target * 0.01, "low price drifts up to the markup")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E149"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
