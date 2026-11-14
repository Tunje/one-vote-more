extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(60)
	var d := EconQuery.crime_drivers(sim.world)
	for k in EconUtil.sorted_keys(d):
		print(k, " ", d[k])
	quit()
