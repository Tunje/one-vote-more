extends TestCase
## §8c (EconFleet): CTA's buses age, wear, break down and are repaired from parts; too few seats leave commuters unable
## to reach work, which cuts the work district's crews and makes news naming the employers and the causes.
## Opt-in "FLEET" (with "SUPPORT_T" for the riders).


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_T"]
	sim.run(3)
	check(sim.world.peek("bus").is_empty(), "no fleet unless FLEET is on")
	check_eq(EconFleet.absent_pm(sim.world, "d:1"), 0, "nobody misses work when off")


func test_breakdowns_leave_commuters_stranded() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_T", "FLEET"]
	sim.run(10)
	var w := sim.world
	# whatever was assembled, break every bus: nobody gets to work in other districts this month
	for bid in w.table("bus"):
		w.table("bus")[bid]["repair_m"] = 3
	sim.run(1)
	var worst := 0
	var worst_d := ""
	for d in EconUtil.sorted_keys(w.table("district")):
		var a := EconFleet.absent_pm(w, d)
		if a > worst:
			worst = a
			worst_d = d
	check(worst > 0, "commuters could not reach work (worst %d‰ in %s)" % [worst, worst_d])
	var news := w.facts.query("ECON_COMMUTE_DISRUPTION")
	check(not news.is_empty(), "the disruption makes news")
	if not news.is_empty():
		var d: Dictionary = news[news.size() - 1]["data"]
		check(not (d.get("employers", []) as Array).is_empty(), "the employers hit are named")
		check(d.get("cause", {}).has("fleet_condition") and d.get("cause", {}).has("depot_starved_m"), "the causes are on the fact: %s" % [d.get("cause", {})])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])
