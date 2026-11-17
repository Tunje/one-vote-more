extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	var t := Time.get_ticks_usec()
	Transport._graph(w, true)
	print("graph build %d ms memo size %d" % [(Time.get_ticks_usec() - t) / 1000, Transport._memo.size()])
	t = Time.get_ticks_usec()
	Transport._graph(w, true)
	print("graph hit %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	var r := Transport.route(w, String(Commuting.district_node(w, "d:1")["id"]), String(Commuting.district_node(w, "d:4")["id"]), "ROAD", true)
	print("one route %d ms ok %s memo size %d" % [(Time.get_ticks_usec() - t) / 1000, r["ok"], Transport._memo.size()])
	quit()
