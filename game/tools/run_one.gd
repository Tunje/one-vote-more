extends SceneTree
## Runs the test_* methods of the test files given after "--" (fast iteration; the full suite is tools/test.sh).
##   godot --headless --path game --script res://tools/run_one.gd -- res://tests/population/test_pop_store.gd


func _initialize() -> void:
	var failed := 0
	for path in OS.get_cmdline_user_args():
		var script = load(path)
		if script == null or not script.can_instantiate():
			print("  FAIL  %s :: <script failed to load/parse>" % path)
			failed += 1
			continue
		for m in script.new().get_method_list():
			var n: String = m["name"]
			if not n.begins_with("test_"):
				continue
			var t = script.new()
			t.call(n)
			print("  %s  %s" % ["PASS" if t.failures.is_empty() else "FAIL", n])
			for f in t.failures:
				print("        - " + str(f))
			if not t.failures.is_empty():
				failed += 1
	print("failed: %d" % failed)
	quit(1 if failed > 0 else 0)
