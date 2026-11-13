extends TestCase
## §8b step 2 (EconCommute): commuters pay bus fares to CTA by distance, CTA staffs its buses from the fares, the
## pair rows reach Terra (EconQuery.commuting). Opt-in "SUPPORT_T"; jobs = people, ledger closed.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check(EconQuery.commuting(sim.world).is_empty(), "no commuting rows unless SUPPORT_T is on")
	check_eq(EconCommute.fare_per_worker(sim.world, "d:1"), 0, "no fares when off")


func test_fares_pay_for_buses() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_T"]
	sim.run(8)
	var w := sim.world
	var rows := EconQuery.commuting(w)
	check(not rows.is_empty(), "commuting rows for Terra (%d pairs)" % rows.size())
	var riders := 0
	for r in rows:
		riders += int(r["bus_commuters"])
		check(int(r["load_pm"]) <= 1300, "buses sized to the riders, under the §8c overcrowding line (%s)" % [r])
	check(riders > 0, "people ride the bus (%d)" % riders)
	var paid := false
	for d in w.table("district"):
		if EconCommute.fare_per_worker(w, d) > 0:
			paid = true
	check(paid, "workers pay fares")
	var cta := EconFinance.org_by_key(w, "CTA")
	var staff := 0
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "TRANSIT" and f["org"] == cta:
			staff += EconLabor.staff_total(f["staff"])
	check(staff > 0, "the buses employ drivers and depot staff (%d)" % [staff / 1000])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
