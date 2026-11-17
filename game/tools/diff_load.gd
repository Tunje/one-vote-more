extends SceneTree
## Finds what a saved and loaded game does differently: runs a game N months, saves, loads into a second, steps both M
## more months and prints the first tables and keys that differ.
## usage: godot --headless --path game --script res://tools/diff_load.gd -- [months before save=14] [months after=1] [seed=3] [file]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var before := int(args[0]) if args.size() > 0 else 14
	var after := int(args[1]) if args.size() > 1 else 1
	var seed_v := int(args[2]) if args.size() > 2 else 3
	var a := GameSim.make(seed_v)
	for i in before:
		a.step()
	var b := GameSim.for_load()
	if args.size() > 3 and args[3] == "file":   # through the save file, as the game saves (JSON changes some types)
		SaveIO.save(a, "user://diff_load.sav")
		SaveIO.load_into(b, "user://diff_load.sav")
	else:
		b.load_dict(a.to_dict())
	print("right after load: ", "same" if a.world.state_hash() == b.world.state_hash() else "DIFFERENT")
	_diff("", a.to_dict(), b.to_dict(), 0)
	for i in after:
		a.step()
		b.step()
	print("after %d more month(s): " % after, "same" if a.world.state_hash() == b.world.state_hash() else "DIFFERENT")
	_shown = 0
	_diff("", a.to_dict(), b.to_dict(), 0)
	quit()


var _shown := 0


func _diff(path: String, x, y, depth: int) -> void:
	if _shown >= 25:
		return
	if typeof(x) == TYPE_DICTIONARY and typeof(y) == TYPE_DICTIONARY:
		var keys := {}
		for k in x:
			keys[k] = true
		for k in y:
			keys[k] = true
		if var_to_str(x) != var_to_str(y) and str(x.keys()) != str(y.keys()) and x.size() == y.size() and depth > 0:
			var same_set := true
			for k in x:
				same_set = same_set and y.has(k)
			if same_set:
				_shown += 1
				print("  %s: same keys in another ORDER: %s vs %s" % [path, str(x.keys()).left(60), str(y.keys()).left(60)])
		for k in keys:
			if not x.has(k) or not y.has(k):
				_shown += 1
				print("  %s/%s only in %s" % [path, str(k), "the saved game" if x.has(k) else "the loaded game"])
			else:
				_diff(path + "/" + str(k), x[k], y[k], depth + 1)
	elif typeof(x) == TYPE_ARRAY and typeof(y) == TYPE_ARRAY:
		if var_to_str(x).left(12) != var_to_str(y).left(12):
			_shown += 1
			print("  %s: array written differently: %s vs %s" % [path, var_to_str(x).left(30), var_to_str(y).left(30)])
		if x.size() != y.size():
			_shown += 1
			print("  %s sizes %d vs %d" % [path, x.size(), y.size()])
			return
		for i in x.size():
			_diff(path + "[%d]" % i, x[i], y[i], depth + 1)
	elif typeof(x) != typeof(y) or str(x) != str(y) or var_to_str(x) != var_to_str(y):
		_shown += 1
		print("  %s: %s vs %s" % [path, str(x).left(80), str(y).left(80)])
