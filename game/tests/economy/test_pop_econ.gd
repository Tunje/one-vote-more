extends TestCase
## M10 S2: the economy on population leaves (spec-population-v1 §3, §13; PD §26 tests 4 and 5).


func _employed(w: WorldState) -> int:
	return PopStore.count(w, {"status": "EMPLOYED"})


func test_jobs_equal_people_and_conservation() -> void:
	var sim := EconSim.make_econ_only(3)
	for m in 14:
		sim.run(1)
		var w := sim.world
		check(PopStore.reconcile(w).is_empty(), "m%d reconcile: %s" % [w.month, PopStore.reconcile(w)])
		check(EconPop.check(w).is_empty(), "m%d jobs = employed people: %s" % [w.month, EconPop.check(w)])
		check_eq(w.ledger.total(), 0, "m%d ledger" % w.month)
	check(EconUtil.st(sim.world).get("pop_mismatch", []).is_empty(), "no mismatches: %s" % [EconUtil.st(sim.world).get("pop_mismatch", [])])
	# pools are derived from the leaves
	var w := sim.world
	var pool_persons := 0
	for gid in w.table("hh"):
		pool_persons += EconHouseholds.persons(w.table("hh")[gid])
	check_eq(pool_persons, PopStore.total(w) * EconUtil.S, "pool head counts = leaves")


## PD test 4: close a factory — its allocations end, its workers become unemployed (keeping occupation and skill),
## and household income falls.
func test_pd4_company_closure() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var w := sim.world
	var fac := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "CONSUMERF" and EconLabor.staff_total(f["staff"]) >= 20 * EconUtil.S:
			fac = fid
	check(fac != "", "a consumer-goods factory with 20+ staff")
	if fac == "":
		return
	var f: Dictionary = w.table("facility")[fac]
	var staff := EconLabor.staff_total(f["staff"]) / EconUtil.S
	var occ := EconPop.person_occ(w, f["org"], f["type"], "G")
	var emp0 := _employed(w)
	var unemp_occ0 := PopStore.count(w, {"occ": occ, "status": "UNEMPLOYED"})
	f["mothball"] = true
	EconLabor.post_vacancies(w)
	check_eq(EconLabor.staff_total(f["staff"]), 0, "allocations ended")
	check(_employed(w) <= emp0 - staff, "employed people fell by at least the staff (%d): %d -> %d" % [staff, emp0, _employed(w)])
	check(PopStore.count(w, {"occ": occ, "status": "UNEMPLOYED"}) > unemp_occ0, "laid-off workers keep their occupation (%s)" % occ)
	check(EconPop.check(w).is_empty(), "jobs = people after closure: %s" % [EconPop.check(w)])
	# household wages: compare the next settlement with an identical run without the closure
	var ref := EconSim.make_econ_only(3)
	ref.run(3)
	sim.run(1)
	ref.run(1)
	var wages := 0
	var wages_ref := 0
	for gid in w.table("hh"):
		wages += int(w.table("hh")[gid]["income"].get("wages", 0))
	for gid in ref.world.table("hh"):
		wages_ref += int(ref.world.table("hh")[gid]["income"].get("wages", 0))
	check(wages < wages_ref, "household wage income falls (%d vs %d)" % [wages, wages_ref])


## PD test 5: raise the wages of a group — some of them move into higher income bands (at the January
## reclassification, E92), compared with an identical colony without the raise.
func test_pd5_income_mobility() -> void:
	var a := EconSim.make_econ_only(5)
	var b := EconSim.make_econ_only(5)
	a.run(2)
	b.run(2)
	for i in 11:  # through the next January
		# a 50% raise: a tripled wage bankrupts employers (partial payroll, layoffs), so actual incomes barely rose
		EconUtil.st(a.world)["wage"]["G"] = EconUtil.st(b.world)["wage"]["G"] * 3 / 2
		a.run(1)
		b.run(1)
	var hi_a := PopStore.count(a.world, {"status": "EMPLOYED", "inc": ["I4", "I5"]}, "skill:G")
	var hi_b := PopStore.count(b.world, {"status": "EMPLOYED", "inc": ["I4", "I5"]}, "skill:G")
	# mobility is the share of employed G workers in the high bands; a tripled wage also causes layoffs, so raw counts
	# mix the two effects (E116 changed which one wins)
	var emp_a := maxi(1, PopStore.count(a.world, {"status": "EMPLOYED"}, "skill:G"))
	var emp_b := maxi(1, PopStore.count(b.world, {"status": "EMPLOYED"}, "skill:G"))
	check(float(hi_a) / emp_a > float(hi_b) / emp_b, "share of employed General-skill workers in high bands: %d/%d with the raise vs %d/%d without" % [hi_a, emp_a, hi_b, emp_b])
	check(PopStore.reconcile(a.world).is_empty(), "conservation holds through band moves")
	check_eq(a.world.ledger.total(), 0, "money moved with people, ledger balanced")
