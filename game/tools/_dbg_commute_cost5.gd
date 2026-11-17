extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	for i in 2:
		var t := Time.get_ticks_usec()
		ColonyLayout.settlements(w)
		var t1 := Time.get_ticks_usec()
		ColonyLayout.facility_tiles(w)
		var t2 := Time.get_ticks_usec()
		PlanetSites.sites(w)
		var t3 := Time.get_ticks_usec()
		Transport.nodes(w)
		var t4 := Time.get_ticks_usec()
		print("settlements %d ms, facility_tiles %d ms, sites %d ms, nodes %d ms" % [(t1 - t) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, (t4 - t3) / 1000])
		w.month += 1
	quit()
