extends SceneTree
## Loads every script of the game and prints the ones that do not compile.  godot --headless --path game --script res://tools/load_all.gd [-- sim ui]
func _initialize() -> void:
	var roots: Array = ["res://sim", "res://ui"]
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		roots = []
		for a in args:
			roots.append("res://" + a)
	var bad := 0
	var n := 0
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				n += 1
				var s = ResourceLoader.load(d.path_join(f), "", ResourceLoader.CACHE_MODE_IGNORE)
				if s == null or not (s as GDScript).can_instantiate():
					bad += 1
					print("BAD ", d.path_join(f))
	print("scripts: ", n, "  bad: ", bad)
	quit()
