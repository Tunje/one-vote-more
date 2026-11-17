extends SceneTree
## Wilma: which part of the state differs after save/load/continue? args: seed months
func _diff(pa: String, x, y, out: Array) -> void:
	if out.size() > 25:
		return
	if typeof(x) == TYPE_DICTIONARY and typeof(y) == TYPE_DICTIONARY:
		for k in x:
			if not y.has(k):
				out.append("%s.%s only in A" % [pa, str(k)])
			else:
				_diff("%s.%s" % [pa, str(k)], x[k], y[k], out)
		for k in y:
			if not x.has(k):
				out.append("%s.%s only in B" % [pa, str(k)])
	elif typeof(x) == TYPE_ARRAY and typeof(y) == TYPE_ARRAY:
		if x.size() != y.size():
			out.append("%s size %d vs %d" % [pa, x.size(), y.size()])
		for i in mini(x.size(), y.size()):
			_diff("%s[%d]" % [pa, i], x[i], y[i], out)
	elif var_to_str(x) != var_to_str(y):
		out.append("%s: %s vs %s" % [pa, var_to_str(x).left(120), var_to_str(y).left(120)])


func _initialize() -> void:
	var a: Simulation = EconSim.make(4, "BALANCED", {}, true)
	for _m in 30:
		a.step()
	SaveIO.save(a, "user://dbg.sav")
	var b := EconSim.for_load()
	SaveIO.load_into(b, "user://dbg.sav")
	a.step()
	b.step()
	var out: Array = []
	_diff("", a.world.to_dict(), b.world.to_dict(), out)
	for l in out:
		print(l)
	quit(0)
