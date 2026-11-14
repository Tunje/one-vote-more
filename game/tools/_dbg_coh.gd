extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 720
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = Array(a[2].split(",")) if a.size() > 2 and a[2] != "-" else []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	var last := {"b": 0, "d": 0, "a": 0, "x": 0}
	for m in months:
		sim.step()
		if (m + 1) % 60 != 0:
			continue
		var b := int(w.values.get("pop_births", 0)) - int(last["b"])
		var dth := int(w.values.get("pop_deaths", 0)) - int(last["d"])
		var arr := int(w.values.get("pop_arrivals", 0)) - int(last["a"])
		var dep := int(w.values.get("pop_departures", 0)) - int(last["x"])
		last = {"b": int(w.values.get("pop_births", 0)), "d": int(w.values.get("pop_deaths", 0)), "a": int(w.values.get("pop_arrivals", 0)), "x": int(w.values.get("pop_departures", 0))}
		var fc := EconQuery.demography(w)
		var pop := PopStore.total(w)
		var st := {}
		for s2 in ["CHILD", "EMPLOYED", "UNEMPLOYED", "NOT_IN_LF", "RETIRED"]:
			st[s2] = PopStore.count(w, {"status": s2})
		var tf := []
		for d in ["d:1", "d:2", "d:3"]:
			tf.append("%.1f" % EconCohorts.tfr(w, d, float(EconUtil.st(w).get("edu_access", {}).get(d, 1000)) / 1000.0))
		var pyr := EconCohorts.pyramid(w)
		var reno := w.facts.query("ECON_HOUSING_RENOVATED").size()
		var rund := w.facts.query("ECON_HOUSING_RUNDOWN").size()
		print("   renovations so far %d, run-down events %d, LAW_IMMIGRATION %s | S7 %s | fires %d shantytowns %d homeless-news %d" % [reno, rund, str(w.levers.get("LAW_IMMIGRATION", "-")), str(EconInformal.summary(w)), w.facts.query("ECON_SHACK_FIRE").size(), w.facts.query("ECON_SHANTYTOWN").size(), w.facts.query("ECON_HOMELESSNESS").size()])
		print("Y%d pop %d births/5y %d deaths/5y %d arr %d dep %d tfr %s u %.1f%% homes %d occ %d%% slums %s attract %d%% | %s | check %d" % [(m + 1) / 12, pop, b, dth, arr, dep, tf, 100.0 * FirmAI.colony_unemployment(w), int(fc["housing_units"]), int(fc["occupancy_pct"]), fc["slums"], int(fc["attractiveness_pct"]), st, EconPop.check(w).size()])

	print("ledger ", w.ledger.total(), " goods ", EconReport.goods_errors(w))
	quit()
