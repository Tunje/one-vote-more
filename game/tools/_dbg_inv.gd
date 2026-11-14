extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	for y in [5, 10, 20]:
		sim.run(y * 12 - w.month)
		var by := {}
		for k in w.table("inv"):
			var parts: PackedStringArray = k.split("|")
			var holder := parts[0]
			var o: Dictionary = w.table("org").get(holder, {})
			var kind: String = o.get("type", holder.split(":")[0]) if not o.is_empty() else holder.split(":")[0]
			var kk := "%s %s" % [kind, parts[1]]
			by[kk] = int(by.get(kk, 0)) + int(w.table("inv")[k]["q"]) / 1000
		var keys := by.keys()
		keys.sort_custom(func(a, b): return int(by[a]) > int(by[b]))
		var line := "Y%d:" % y
		for k in keys.slice(0, 14):
			line += " %s=%d" % [k, by[k]]
		print(line)
	quit()
