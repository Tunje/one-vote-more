extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	sim.run(12)
	var w := sim.world
	var t := Time.get_ticks_usec()
	var rows: Array = Transport.commutes(w)
	print("commutes rows %d in %d ms" % [rows.size(), (Time.get_ticks_usec() - t) / 1000])
	var pairs := {}
	for r in rows:
		pairs["%s>%s" % [r["from_d"], r["to_d"]]] = [r["from_d"], r["to_d"]]
	print("pairs %d districts %d" % [pairs.size(), w.table("district").size()])
	t = Time.get_ticks_usec()
	for k in pairs:
		Transport.commute_d(w, pairs[k][0], pairs[k][1])
	print("first pass %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	for k in pairs:
		Transport.commute_d(w, pairs[k][0], pairs[k][1])
	print("second pass %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	for i in 100:
		ColonyLayout.key(w)
	print("100× ColonyLayout.key %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	t = Time.get_ticks_usec()
	for i in 100:
		Commuting.district_node(w, "d:2")
	print("100× district_node %d ms" % [(Time.get_ticks_usec() - t) / 1000])
	quit()
