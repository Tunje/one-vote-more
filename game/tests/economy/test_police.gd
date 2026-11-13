extends TestCase
## P1b (EconPolice, opt-in "POLICE"): the police institution staffs its stations from LAW_POLICE_BUDGET, pays them from
## the treasury, gives Anni's crime model its hours, and a budget cut bites (no labour hoarding).


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	check(EconQuery.police(sim.world)["stations"].is_empty(), "no stations unless POLICE is on")
	check_eq(EconPolice.hours(sim.world, "d:1"), 0, "no hours when off")


func test_stations_staffed_and_cuts_bite() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["POLICE", "WORKLOAD"]
	w.levers["LAW_POLICE_BUDGET"] = 2000
	sim.run(12)
	var st: Array = EconQuery.police(w)["stations"]
	check(not st.is_empty(), "the HQ station is open")
	check(String(st[0]["id"]).begins_with("fac:") and st[0]["district"] == "d:1", "rows carry a stable id: %s" % [st[0]])
	var before := int(st[0]["staff"])
	check(before > 0 and EconPolice.hours(w, "d:1") > 0, "officers on duty: %s" % [st[0]])
	check(int(EconUtil.st(w)["spent_ytd"].get("LAW_POLICE_BUDGET", 0)) > 0, "paid from the police line")
	w.levers["LAW_POLICE_BUDGET"] = 300
	sim.run(6)
	var after := int(EconQuery.police(w)["stations"][0]["staff"])
	check(after * 100 <= before * 40, "a cut to 300‰ leaves about 30%% (%d → %d)" % [before, after])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])


func test_crime_drivers_shape() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(14)
	var dr := EconQuery.crime_drivers(sim.world)
	check(not dr.is_empty(), "drivers per district")
	for d in dr:
		for k in ["pop", "unemployed_pm", "hunger_pm", "homeless_pm", "youth_pm", "ineq_x1000", "stock_wref", "firms"]:
			check(dr[d].has(k) and typeof(dr[d][k]) == TYPE_INT, "%s has integer %s" % [d, k])
