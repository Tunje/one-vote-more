extends SceneTree
func _initialize() -> void:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	sim.run(2)
	var w := sim.world
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		var e := {}
		for k in g["emp"]:
			e[k] = g["emp"][k] / 1000
		print("%s %s %s lf %d np %d ret %d own %d self %d emp %s" % [gid, g["district"], g["tier"], g["lf"] / 1000, g["nonpart"] / 1000, g["retired"] / 1000, g["owners"] / 1000, g.get("self_emp", 0) / 1000, e])
	var occ := {}
	for k in w.table("census"):
		var o: String = k.split("|")[1]
		occ[o] = occ.get(o, 0) + w.table("census")[k]
	print(occ)
	quit(0)
