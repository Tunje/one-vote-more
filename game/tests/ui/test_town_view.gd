extends TestCase
## Terra (the user via Wilma 2026-11-15): the town view (ui/town_view.gd, flag TOWN_GRID): what it draws from the
## town grid, the model slots with placeholders, a dropped-in model used, the cell panel; it never writes the world.


func _game(months: int = 2, on: bool = true) -> Simulation:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(TownGrid.FLAG)
	for _m in months:
		sim.step()
	return sim


func test_no_grid_no_view() -> void:
	var w := _game(2, false).world
	check(TownView.layout(w, "d:1").is_empty(), "nothing without the flag")
	var w2 := _game().world
	var none := ""
	for s in ColonyLayout.settlements(w2):
		if not TownGrid.has_grid(w2, String(s["id"])):
			none = String(s["id"])
	if none != "":
		check(TownView.layout(w2, none).is_empty(), "nothing for a settlement without a grid")


func test_every_cell_has_its_buildings() -> void:
	var w := _game().world
	var h := w.state_hash()
	var lay := TownView.layout(w, "d:1")
	check_eq(w.state_hash(), h, "pure")
	check_eq(TownView.layout(w, "d:1"), lay, "deterministic")
	var cells: Dictionary = w.peek("town")["towns"]["d:1"]["cells"]
	var by_cell := {}
	for it in lay["items"]:
		if String(it["cell"]) != "":
			by_cell[it["cell"]] = int(by_cell.get(it["cell"], 0)) + 1
			var c := ColonyLayout.as_tile(it["cell"])
			var c0 := Vector2i(int(lay["centre"][0]), int(lay["centre"][1]))
			var p: Vector3 = it["pos"]
			check(p.x >= float(c.x - c0.x) * 100.0 and p.x <= float(c.x - c0.x + 1) * 100.0
				and p.z >= float(c.y - c0.y) * 100.0 and p.z <= float(c.y - c0.y + 1) * 100.0, "inside its cell")
	for ck in cells:
		var row: Array = cells[ck]
		var want := 1
		if String(row[1]) == "HOUSE":
			want = clampi(int(row[2]), 1, 10)
		check_eq(int(by_cell.get(ck, 0)), want, "cell %s %s" % [ck, str(row)])
	check_eq(int(lay["homes"]), int(TownGrid.grid_due(w, "d:1")["homes"]), "all the homes")
	check(not (lay["streets"] as Array).is_empty(), "streets")
	check(lay["items"].any(func(it): return String(it["slot"]) == "TREE"), "trees in the country")
	check_eq(TownView.slot_of("HOUSING", "TOWER"), "TOWER", "a tower")
	check_eq(TownView.slot_of("FAMBAKERY"), "BAKERY", "a bakery")
	check_eq(TownView.slot_of("POWER"), "WORKS", "works")
	check_eq(TownView.slot_of("HOUSING"), "HOUSE", "houses by default")


func test_the_cell_panel_says_why_a_spot_is_dear() -> void:
	var w := _game().world
	var cs: Dictionary = w.peek("town")["towns"]["d:1"]["cells"]
	var ck := String(EconUtil.sorted_keys(cs)[0])
	var h := w.state_hash()
	var t := TownView.cell_text(w, "d:1", ColonyLayout.as_tile(ck))
	check_eq(w.state_hash(), h, "pure")
	check(t.contains("Location value") and t.contains("jobs near"), "the value and its parts: %s" % t)
	check(t.contains("home") or t.contains("("), "what stands there")
	var far := TownView.cell_text(w, "d:1", ColonyLayout.as_tile(ck) + Vector2i(200, 0))
	check(far.contains("Empty"), "an empty cell says so")


func test_the_view_builds_with_placeholders_and_with_a_model() -> void:
	var w := _game().world
	var h := w.state_hash()
	TownView.model_dir = "user://test_town_models"
	var v := TownView.new()
	v.world_override = w
	v._ready()
	v.open_town("d:1")
	check(v._content.get_child_count() >= 3, "ground, flats and buildings")
	check(TownView.variants("HOUSE").is_empty(), "no models: placeholders")
	# drop a model into the HOUSE slot: a small box exported to glTF
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_town_models/HOUSE"))
	var scene := Node3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(9, 7, 8)
	mi.mesh = bm
	scene.add_child(mi)
	mi.owner = scene
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	check_eq(doc.append_from_scene(scene, st), OK, "exported")
	var path := "user://test_town_models/HOUSE/box.glb"
	check_eq(doc.write_to_filesystem(st, ProjectSettings.globalize_path(path)), OK, "written")
	scene.free()
	v.open_town("d:1")
	check_eq(TownView.variants("HOUSE").size(), 1, "the model is found")
	var models := 0
	for c in v._content.get_children():
		if not c is MeshInstance3D:
			models += 1
	check(models > 0, "houses are the model (%d)" % models)
	check_eq(w.state_hash(), h, "the view never writes the world")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_town_models/HOUSE"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_town_models"))
	TownView.model_dir = TownView.MODEL_DIR
	TownView._templates.clear()
	v.free()
