extends SceneTree
## Headless test runner.
##   godot --headless --path game --script res://tests/run_tests.gd
## Runs every tests/**/test_*.gd file's test_* methods. Exit code 0 = all passed.


func _initialize() -> void:
	var files: Array = []
	_collect("res://tests", files)
	files.sort()
	var passed := 0
	var failed := 0
	for path in files:
		var script = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL  %s :: <script failed to load/parse>" % path.get_file())
			continue
		var probe = script.new()
		var names: Array = []
		for m in probe.get_method_list():
			if String(m["name"]).begins_with("test_"):
				names.append(m["name"])
		names.sort()
		for n in names:
			var t = script.new()
			t.call(n)
			if t.failures.is_empty():
				passed += 1
				print("  PASS  %s :: %s" % [path.get_file(), n])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [path.get_file(), n])
				for f in t.failures:
					print("        - " + str(f))
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append(dir_path.path_join(f))
