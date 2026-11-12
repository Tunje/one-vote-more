extends SceneTree
## Wilma: list non-integer floats in the saved state (integer-state rule) and the first diverging table after
## save/load/continue.  args: months seed
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 50
	var sim: Simulation = EconSim.make(int(args[1]) if args.size() > 1 else 5, "BALANCED", {}, true)
	sim.run(months)
	var path := "user://ff.sav"
	SaveIO.save(sim, path)
	var found := []
	_walk(sim.world.entities, "entities", found)
	_walk(sim.world.levers, "levers", found)
	_walk(sim.world.values, "values", found)
	_walk(sim.world.meta, "meta", found)
	print("non-integer floats: %d" % found.size())
	var by := {}
	for f in found:
		var parts: PackedStringArray = String(f).split(".")
		var k := parts[0] + "." + parts[1] if parts.size() > 1 else parts[0]
		by[k] = int(by.get(k, 0)) + 1
	print("  by table: ", by)
	for f in found:
		if not String(f).begins_with("entities.outlet"):
			print("  ", f)
	var loaded: Simulation = EconSim.for_load()
	SaveIO.load_into(loaded, path)
	sim.run(3)
	loaded.run(3)
	for t in sim.world.entities:
		if var_to_str(sim.world.entities[t]) != var_to_str(loaded.world.entities.get(t, null)):
			print("DIVERGES after 3 months: table ", t)
	quit()


func _walk(v, path: String, out: Array) -> void:
	if out.size() > 5000:
		return
	match typeof(v):
		TYPE_FLOAT:
			if v != floor(v):
				out.append("%s = %s" % [path, str(v)])
		TYPE_DICTIONARY:
			for k in v:
				_walk(v[k], path + "." + str(k), out)
		TYPE_ARRAY:
			for i in v.size():
				_walk(v[i], "%s[%d]" % [path, i], out)
