extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(int(OS.get_cmdline_user_args()[0]))
	var w := sim.world
	w.meta["on"] = ["SUPPORT_T", "FLEET"]
	for y in 3:
		sim.run(60)
		var s := EconUtil.st(w)
		var riders := 0
		for r in s.get("commute_rows", []):
			riders += int(r["bus_commuters"])
		print("Y%d buses %d riders %d COMPONENT price %d fare_ema %d starved %d" % [(y + 1) * 5, w.table("bus").size(), riders,
			int(s["prices"]["COMPONENT"]), int(s.get("fare_rev_ema", 0)), int(s.get("depot_starved_m", 0))])
	quit()
