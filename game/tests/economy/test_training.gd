extends TestCase
## E114: on-the-job training — firms with skilled vacancies sponsor unemployed workers one tier below, paying a
## stipend (one month of the wage gap); the training subsidy pays a share from ECON_BUDGET_TRAINING and speeds it up.


func _skill(w: WorldState, t: String) -> int:
	return PopStore.count(w, {}, "skill:" + t)


func test_training_promotes_into_vacancies_and_costs_money() -> void:
	var sim := EconSim.make_econ_only(6)
	sim.run(6)
	var w := sim.world
	var s0 := _skill(w, "S")
	var vac := EconTraining.vacancies(w)
	sim.run(12)
	var trained := 0
	for h in EconUtil.st(w).get("train_hist", []):
		trained += int(h[0]) + int(h[1])
	if vac["S"] + vac["Sp"] > 0:
		check(trained > 0, "skilled vacancies %s led to training (%d)" % [vac, trained])
	check_eq(w.ledger.total(), 0, "ledger closed (stipends are transfers)")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	var sk: Dictionary = EconQuery.essentials(w)["SKILLS"]
	for k in ["vacancies_S", "vacancies_Sp", "unemployed_G", "trained_12m_S", "trained_12m_Sp", "subsidy_pct"]:
		check(sk.has(k), "SKILLS.%s present" % k)
	check(_skill(w, "S") > 0 and s0 > 0, "skilled workers exist")


func test_subsidy_speeds_training() -> void:
	var base := EconSim.make_econ_only(6)
	var sub := EconSim.make_econ_only(6)
	sub.world.levers["ECON_TRAINING_SUBSIDY"] = 100
	sub.world.levers["ECON_BUDGET_TRAINING"] = 2000
	base.run(18)
	sub.run(18)
	var tb := 0
	var ts := 0
	for h in EconUtil.st(base.world).get("train_hist", []):
		tb += int(h[0]) + int(h[1])
	for h in EconUtil.st(sub.world).get("train_hist", []):
		ts += int(h[0]) + int(h[1])
	check(ts >= tb, "full subsidy trains at least as many in the last year (%d vs %d)" % [ts, tb])
	check_eq(sub.world.ledger.total(), 0, "ledger closed with subsidy")
