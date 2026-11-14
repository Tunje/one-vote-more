extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.world.meta["on"] = ["SUPPORT_T", "FLEET"]
	var t := Time.get_ticks_usec()
	sim.run(36)
	var w := sim.world
	print("3y in %d ms/month; buses %d" % [(Time.get_ticks_usec() - t) / 36000, w.table("bus").size()])
	for k in ["BUS_BREAKDOWN", "BUS_CRASH", "ECON_COMMUTE_DISRUPTION"]:
		var fs := w.facts.query(k)
		var tiled := 0
		for f in fs:
			if int(f["data"].get("tile", -1)) >= 0:
				tiled += 1
		print("%s %d (with tile %d)" % [k, fs.size(), tiled])
	print("ledger %d" % w.ledger.total())
	quit()
