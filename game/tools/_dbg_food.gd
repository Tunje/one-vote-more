extends SceneTree
## temp (Bob): food chain per year. args: seed years
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	for y in int(a[1]):
		sim.run(12)
		var e := EconEssentials.measure(w)
		var farms := 0
		var live := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "FARM":
				farms += 1
				if not f["mothball"]:
					live += 1
		var s := EconUtil.st(w)
		print("Y%d food cap %d dem %d margin %d%% | brake %.2f | farms %d/%d | price %d base %d | shortage facts %d famine %d | pop %d u %.1f%% | attract %.0f%% | LAW_IMMIGRATION %s" % [y + 1,
			int(e["FOOD"]["capacity"]) / 1000, int(e["FOOD"]["demand"]) / 1000, int(e["FOOD"]["margin_pct"]), EconHouseholds.food_brake(w), live, farms,
			int(s["prices"]["FOOD"]) / 1000, int(s["base"]["FOOD"]) / 1000, w.facts.query("ECON_SHORTAGE").size(), w.facts.query("ECON_FAMINE").size(),
			PopStore.total(w), 100.0 * FirmAI.colony_unemployment(w), 100.0 * EconCohorts.attractiveness(w), str(w.levers.get("LAW_IMMIGRATION", "-"))])
	quit()
