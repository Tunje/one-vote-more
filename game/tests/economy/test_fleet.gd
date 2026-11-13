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


func test_budget_line_funds_parts_and_cut_is_blamed() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_T", "FLEET"]
	w.levers["ECON_BUDGET_PUBLIC_TRANSPORT"] = 600
	sim.run(14)
	check(int(EconUtil.st(w)["spent_ytd"].get("ECON_BUDGET_PUBLIC_TRANSPORT", 0)) + int(EconUtil.st(w).get("fleet_fare_part", 0)) > 0, "the fleet was funded")
	w.levers["ECON_BUDGET_PUBLIC_TRANSPORT"] = 0
	sim.run(3)
	var c := EconFleet.budget_cause(w)
	check_eq(int(c["transport_budget_peak"]), 600, "the peak is remembered")
	check_eq(int(c["budget_cut_pm"]), 1000, "the full cut shows")
	check(int(c["budget_cut_months_ago"]) >= 3 and bool(c["fares_only"]), "when and how far: %s" % [c])
	for bid in w.table("bus"):
		w.table("bus")[bid]["repair_m"] = 3
	sim.run(1)
	var news := w.facts.query("ECON_COMMUTE_DISRUPTION")
	if not news.is_empty():
		var cause: Dictionary = news[news.size() - 1]["data"]["cause"]
		check(cause.has("transport_budget_peak") and int(cause["budget_cut_pm"]) == 1000, "the disruption names the cut: %s" % [cause])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_dead_fleet_recovers_and_absence_fades() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_T", "FLEET"]
	sim.run(6)
	w.table("bus").clear()  # every bus scrapped, no components anywhere
	var cta := EconFinance.org_by_key(w, "CTA")
	EconUtil.inv_take(w, cta, "COMPONENT", "d:1", EconUtil.inv_get(w, cta, "COMPONENT", "d:1"))
	w.ledger.transfer(EconUtil.TREASURY, EconUtil.acct(cta), 2000000000, "TEST", w.month)  # the money returns
	EconUtil.st(w)["fleet_fund"] = 2000000000  # … and was saved for buses
	sim.run(1)
	check(not w.table("bus").is_empty(), "buses imported when no parts exist")
	# a district without buses: absence fades as people adapt
	var s := EconUtil.st(w)
	w.table("bus").clear()
	w.ledger.transfer(EconUtil.acct(cta), EconUtil.TREASURY, w.ledger.balance(EconUtil.acct(cta)), "TEST", w.month)
	var first := 0
	var last := 0
	for m in 8:
		sim.run(1)
		var worst := 0
		for d in s.get("commute_absent_pm", {}):
			worst = maxi(worst, int(s["commute_absent_pm"][d]))
		if m == 0:
			first = worst
		last = worst
	check(first <= EconFleet.ABSENT_CAP, "absence capped: %d" % first)
	check(last < first or first == 0, "absence fades as commuters adapt (%d → %d)" % [first, last])
	check_eq(w.ledger.total(), 0, "ledger closed")
