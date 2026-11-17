extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	var g := Transport._graph(w, true)
	var adj: Dictionary = g["adj"]
	var towns := {}
	var maxt := 0
	for s in ColonyLayout.settlements(w):
		towns[s["id"]] = s["tiles"]
		maxt = maxi(maxt, (s["tiles"] as Array).size())
	print("adj vertices %d settlements %d biggest town %d tiles" % [adj.size(), towns.size(), maxt])
	var a := Commuting.district_node(w, "d:1")
	var t := Time.get_ticks_usec()
	var st := Transport._attach(a, adj, towns)
	print("_attach %d ms (%d starts)" % [(Time.get_ticks_usec() - t) / 1000, st.size()])
	t = Time.get_ticks_usec()
	for i in 1000:
		Transport.int_tile(i)
	print("1000× int_tile %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	quit()
