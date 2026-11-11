extends SceneTree
func _initialize() -> void:
	var sim := EconSim.make(4, "BALANCED", {}, true)
	for m in 30:
		sim.step()
		if m % 3 == 2:
			var parts: Array = []
			for o in EconQuery.commission_options(sim.world):
				parts.append("%s %s/%s" % [o["type"], EconQuery_money(o["headroom"]), EconQuery_money(o["estimate"])])
			print("m%d " % sim.world.month, ", ".join(parts))
	quit(0)

func EconQuery_money(v: float) -> String:
	return "%.0fk" % (v / 1000.0)
