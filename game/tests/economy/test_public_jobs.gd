extends TestCase
## E117: (a) a new builder enters when tenders sit unbid while a private builder is alive; (b) the public employment
## scheme hires the unemployed at 80% of the General wage from ECON_BUDGET_PUBLIC_EMPLOYMENT, as real EMPLOYED posts.


func _unemployed(w: WorldState) -> int:
	return PopStore.count(w, {"status": "UNEMPLOYED"})


func test_scheme_off_by_default_and_hires_when_funded() -> void:
	var base := EconSim.make_econ_only(4)
	base.run(6)
	check_eq(EconPublicJobs.pes(base.world), "", "no budget: the scheme never exists")
	var sim := EconSim.make_econ_only(4)
	sim.run(3)
	var w := sim.world
	w.levers["ECON_BUDGET_PUBLIC_EMPLOYMENT"] = 3000
	sim.run(3)
	var oid := EconPublicJobs.pes(w)
	check(oid != "", "funding founds the Public Employment Service")
	var n := EconPublicJobs.posts(w)
	check(n > 0, "the scheme employs people (%d)" % n)
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	var pes_w := EconLabor.offer(w, oid, "S")
	check_eq(pes_w, int(float(EconUtil.st(w)["wage"]["G"]) * EconPublicJobs.PES_PAY), "every post pays 80% of the General wage")
	check(int(EconUtil.st(w).get("spent_ytd", {}).get("ECON_BUDGET_PUBLIC_EMPLOYMENT", 0)) > 0, "booked on its budget line")
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(not w.facts.query("ECON_PUBLIC_JOBS_HIRED").is_empty(), "a bulk hiring makes news")


func test_cutting_the_budget_lays_off() -> void:
	var sim := EconSim.make_econ_only(4)
	sim.run(2)
	var w := sim.world
	w.levers["ECON_BUDGET_PUBLIC_EMPLOYMENT"] = 3000
	sim.run(4)
	var n1 := EconPublicJobs.posts(w)
	w.levers["ECON_BUDGET_PUBLIC_EMPLOYMENT"] = 0
	sim.run(3)
	check(EconPublicJobs.posts(w) < n1, "posts fall when parliament cuts the line (%d → %d)" % [n1, EconPublicJobs.posts(w)])
	check(EconPop.check(w).is_empty(), "jobs still equal people after layoffs")


func test_switch_off() -> void:
	var sim := EconSim.make_econ_only(4)
	sim.world.meta["off"] = ["E117"]
	sim.world.levers["ECON_BUDGET_PUBLIC_EMPLOYMENT"] = 3000
	sim.run(4)
	check_eq(EconPublicJobs.pes(sim.world), "", "E117 off: no scheme")
