extends SceneTree
## Wilma: largest party's vote share and effective number of parties at every election.
##   godot --headless --path game --script res://tools/measure_landslides.gd -- years seed...
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0])
	for i in range(1, args.size()):
		var sim: Simulation = EconSim.make(int(args[i]), "BALANCED", {}, true)
		var line := "seed %s:" % args[i]
		var worst := 0.0
		for _m in years * 12:
			sim.step()
			var w := sim.world
			for f in w.facts.query("POL_ELECTION_HELD", w.month - 1, w.month - 1):
				var e: Dictionary = w.table("election")[f["data"]["election"]]
				var top := 0.0
				var hh := 0.0
				for pid in e["votes"]:
					var sh := float(e["votes"][pid]) / maxf(1.0, e["total"])
					top = maxf(top, sh)
					hh += sh * sh
				worst = maxf(worst, top)
				line += " Y%d:%.0f%%/%.1f" % [w.month / 12 + 1, top * 100.0, 1.0 / maxf(0.0001, hh)]
		print(line, "   max %.0f%%" % (worst * 100.0))
	quit()
