extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	var a := String(Commuting.district_node(w, "d:1")["id"])
	var b := String(Commuting.district_node(w, "d:4")["id"])
	for i in 3:
		var t := Time.get_ticks_usec()
		Transport.node(w, a)
		var t1 := Time.get_ticks_usec()
		Transport.route(w, a, b, "ROAD", true)
		var t2 := Time.get_ticks_usec()
		print("node %d ms, route %d ms, memo %d" % [(t1 - t) / 1000, (t2 - t1) / 1000, Transport._memo.size()])
	quit()
