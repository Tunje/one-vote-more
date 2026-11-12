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
	# force a real mismatch (training only runs then): every unemployed S worker becomes G
	for key in PopStore.select(w, {"status": "UNEMPLOYED"}):
		var n := int(w.peek("pop")[key]["skill"].get("S", 0))
		if n > 0:
			EconPop.recompose(w, key, "skill", "S", "G", n)
	var vac := EconTraining.vacancies(w)
	var free_g := PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:G")
	EconTraining.monthly(w)
	var last: Dictionary = EconUtil.st(w).get("train_last", {})
	if vac["S"] > 0 and free_g > vac["G"]:
		check(int(last.get("S", 0)) > 0, "S vacancies %s with %d free G led to training: %s" % [vac, free_g, last])
	else:
		check(false, "test setup: expected S vacancies and spare G (vac %s, free G %d)" % [vac, free_g])
	sim.run(12)
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
