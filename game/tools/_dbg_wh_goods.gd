extends SceneTree
func _init() -> void:
	for on in [[], ["WAREHOUSE"]]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = on
		for m in 16:
			sim.run(1)
			var e := EconReport.goods_errors(w)
			if not e.is_empty():
				print("%s m%d %s" % [on, m, e])
				break
		print("%s done" % [on])
	quit()
