extends TestCase
## Support economy E, step 1: the Sanitation Department scales with the population (opt-in "SUPPORT_E") and housing
## owners employ caretakers (building upkeep) through their office. Jobs = people, ledger closed.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check_eq(EconSanitation.dept(sim.world), "", "no Sanitation Department unless SUPPORT_E is on")


func test_department_scales_and_is_paid() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_E"]
	sim.run(6)
	var w := sim.world
	check(EconSanitation.dept(w) != "", "the department is founded")
	var sm := EconSanitation.summary(w)
	check(int(sm["need"]) > 0, "the colony needs sanitation workers (%s)" % [sm])
	check(int(sm["posts"]) > 0, "posts are filled (%s)" % [sm])
	check(int(sm["posts"]) <= int(sm["need"]) + EconSanitation.POSTS_PER_UNIT, "no more than the need (%s)" % [sm])
	check(int(EconUtil.st(w).get("spent_ytd", {}).get(EconSanitation.LINE, 0)) > 0, "paid and booked to public administration")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_housing_owners_employ_caretakers() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_E"]
	sim.run(4)
	var w := sim.world
	var owner := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "HOUSING" and not f["mothball"]:
			owner = f["org"]
			break
	check(owner != "", "someone owns housing")
	if owner == "":
		return
	check(EconOffice.target_posts(w, owner) > 0, "the housing owner needs caretakers (%d)" % EconOffice.target_posts(w, owner))
	check(EconOffice.office_of(w, owner) != "", "the caretakers work from the owner's office")
	check_eq(EconOffice.cost_factor(w, "FARM"), 1.0, "upkeep alone adds no office overhead to production costs")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
