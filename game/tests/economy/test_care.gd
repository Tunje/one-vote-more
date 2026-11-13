extends TestCase
## Part E (EconCare, opt-in "CARE"): elder care and childcare buy posts from their budget lines; coverage moves the
## retired's mortality and parents' re-entry; a cut overloads the staff before the waiting lists grow.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check_eq(EconCare.org(sim.world, "ELDER"), "", "no elder care service unless CARE is on")
	check_eq(EconCare.elder_mort_mult(sim.world, "d:1"), 1.0, "mortality unchanged when off")
	check_eq(EconCare.reentry_mult(sim.world, "d:1"), 1.0, "re-entry unchanged when off")


func test_services_staffed_and_budgeted() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["CARE"]
	sim.run(12)
	var sm := EconCare.summary(w)
	for svc in ["ELDER", "CHILD"]:
		check(int(sm[svc]["posts"]) > 0 and int(sm[svc]["staff"]) > 0, "%s staffed: %s" % [svc, sm[svc]])
		check(int(sm[svc]["staff"]) <= int(sm[svc]["posts"]) * 11 / 10 + 1, "%s not overstaffed: %s" % [svc, sm[svc]])
		check(int(sm[svc]["coverage"]) > 0, "%s covers someone" % svc)
	check(int(EconUtil.st(w)["spent_ytd"].get("ECON_BUDGET_CHILDCARE", 0)) > 0, "childcare paid from its line")
	check(w.indicators.read("ECON_CHILDCARE_ACCESS", "d:1", -1) > 0, "the childcare access indicator is written")
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])


func test_cut_overloads_then_coverage_falls() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["CARE", "WORKLOAD"]
	sim.run(12)
	var d := "d:1"
	var cov0 := EconCare.coverage(w, "CHILD", d)
	w.levers["ECON_BUDGET_CHILDCARE"] = 200
	sim.run(2)
	var hot := 0
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "CHILDCARE" and not f["mothball"]:
			hot = maxi(hot, int(f.get("workload_pm", 0)))
	check(hot > 1100, "the staff left behind are overloaded first: %d‰" % hot)
	sim.run(12)
	var cov1 := EconCare.coverage(w, "CHILD", d)
	check(cov1 < cov0, "then coverage falls (%d → %d‰)" % [cov0, cov1])
	check(EconCare.reentry_mult(w, d) < 1.0, "fewer parents return to work: %.2f" % EconCare.reentry_mult(w, d))
	w.levers["ECON_BUDGET_ELDER_CARE"] = 0
	sim.run(8)
	check(EconCare.elder_mort_mult(w, d) > 1.0, "the old die sooner without care: %.2f" % EconCare.elder_mort_mult(w, d))
	check_eq(w.ledger.total(), 0, "ledger closed")
