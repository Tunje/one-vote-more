extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	(w.meta["on"] as Array).append("POLICE")
	for m in 168:
		if m == 120:
			w.levers["LAW_POLICE_BUDGET"] = 300
		sim.run(1)
		if m % 12 != 11 and not (m >= 120 and m % 3 == 2):
			continue
		var line := "m%d lever %d spent %dk |" % [m + 1, int(w.levers.get("LAW_POLICE_BUDGET", 0)), int(EconUtil.st(w)["spent_ytd"].get("LAW_POLICE_BUDGET", 0)) / 1000000]
		for st in EconQuery.police(w)["stations"]:
			line += " %s %s cov%s pop %d tgt %d staff %d wl %d stress %d" % [st["id"], st["district"], st["covers"], st["covered_pop"], st["officers_target"], st["staff"], st["workload_pm"], st["stress_pm"]]
		line += " | hours d:1 %d" % EconPolice.hours(w, "d:1")
		print(line)
	print("ledger %d jobs %s" % [w.ledger.total(), EconPop.check(w)])
	quit()
