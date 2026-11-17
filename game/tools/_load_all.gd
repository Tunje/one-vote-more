extends SceneTree
## Loads every script and prints the ones that do not compile.
func _initialize() -> void:
	var bad := 0
	var stack: Array = ["res://sim", "res://ui", "res://tests", "res://tools"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and f != "_load_all.gd":
				var s = ResourceLoader.load(d.path_join(f), "", ResourceLoader.CACHE_MODE_IGNORE)
				if s == null or not (s as GDScript).can_instantiate():
					bad += 1
					print("BAD ", d.path_join(f))
	print("bad scripts: ", bad)
	quit()
