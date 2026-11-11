extends SceneTree
## Crisis frequency on the real economy (integrated), N seeds x 120 months.
const EconSim := preload("res://sim/economy/econ_sim.gd")
func _initialize() -> void:
	var tot := {}
	for seed_v in [1, 2, 3, 4]:
		var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
		sim.run(120)
		var line := "seed %d:" % seed_v
		for t in ["POL_NO_CONFIDENCE_PASSED", "POL_NO_CONFIDENCE_FAILED", "POL_PARTNER_LEFT", "POL_PM_VOTE_FAILED", "POL_FORMATION_FAILED", "POL_GOVERNMENT_FORMED"]:
			var n := sim.world.facts.query(t).size()
			tot[t] = tot.get(t, 0) + n
			line += " %s=%d" % [t.trim_prefix("POL_"), n]
		var g: Dictionary = sim.world.peek("pol")["state"]["government"]
		line += " | final gov members %d" % g.get("members", []).size()
		print(line)
	print("TOTAL ", tot)
	quit(0)
