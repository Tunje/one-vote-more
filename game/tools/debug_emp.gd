extends SceneTree
func _initialize() -> void:
	for mode in ["econ_only", "integrated"]:
		var sim := EconSim.make_econ_only(1) if mode == "econ_only" else EconSim.make(1, "BALANCED", {}, true)
		var line: String = str(mode) + ":"
		for m in 6:
			sim.step()
			var lf := 0
			var emp := 0
			for gid in sim.world.table("hh"):
				lf += sim.world.table("hh")[gid]["lf"]
				emp += EconLabor.employed(sim.world.table("hh")[gid])
			line += " m%d %d/%d" % [m, emp / 1000, lf / 1000]
		print(line)
	quit(0)
