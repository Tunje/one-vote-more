extends TestCase
## Terra (planning/design-town-grid.md; the user's go via Wilma 2026-11-15): towns on a fine grid (sim/transport/
## town_grid.gd, flag TOWN_GRID): a grid only when a settlement needs one, housing forms as a policy, growth scored by
## what draws people. Unit tests only (no long runs).


func _game(seed_v: int = 1, months: int = 2, on: bool = true, extra: Array = []) -> Simulation:
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(TownGrid.FLAG)
	for f in extra:
		(sim.world.meta["on"] as Array).append(f)
	for _m in months:
		sim.step()
	return sim


func _org(w: WorldState) -> String:
	return String(EconUtil.sorted_keys(w.peek("org"))[0])


func _housing_of(w: WorldState, tid: String) -> Array:
	var out: Array = []
	var fac: Dictionary = w.peek("facility")
	for fid in EconUtil.sorted_keys(fac):
		if String(fac[fid]["type"]) == "HOUSING" and TownGrid.town_for(w, fac[fid]) == tid:
			out.append(String(fid))
	return out


func _tick(w: WorldState) -> void:
	w.month += 1
	TownGrid.step_month(w)


func test_flag_off_changes_nothing() -> void:
	var w := _game(1, 2, false).world
	check(w.peek("town").is_empty(), "no table")
	var h := w.state_hash()
	TownGrid.step_month(w)
	check(TownGrid.set_forms(w, "*", ["APARTMENT"]) != "" and TownGrid.step_up(w, "d:1") != "", "no writes")
	check_eq(w.state_hash(), h, "nothing written")
	var hs := _housing_of(w, "d:1")
	check(not TownGrid.has_grid(w, "d:1"), "no grid")
	check_eq(TownGrid.form_of(w, hs[0]), "HOUSE", "the tile-level answer: houses")
	check_eq(TownGrid.connection_m(w, hs[0]), 15, "a house's connection")
	check(TownGrid.cells_of(w, hs[0]).is_empty(), "no cells")


func test_a_grid_only_when_needed() -> void:
	var w := _game().world
	var with_grid := 0
	var without := ""
	for s in ColonyLayout.settlements(w):
		var tid := String(s["id"])
		var due := TownGrid.grid_due(w, tid)
		check_eq(TownGrid.has_grid(w, tid), bool(due["due"]), "%s: a grid exactly when due %s" % [tid, str(due)])
		if TownGrid.has_grid(w, tid):
			with_grid += 1
			var homes := 0
			for fid in _housing_of(w, tid):
				var cs := TownGrid.cells_of(w, fid)
				check_eq(cs.size(), ceili(float(TownGrid._homes(w.peek("facility")[fid])) / 10.0), "%s laid as houses" % fid)
				check_eq(TownGrid.form_of(w, fid), "HOUSE", "houses by default")
				check(TownGrid.connection_m(w, fid) >= 15, "connection")
				check(TownGrid.centre_km(w, fid) >= 0.0, "distance to the centre")
			var foot := TownGrid.footprint(w, tid)
			for k in foot:
				homes += int(foot[k])
			check_eq(homes, int(due["homes"]), "every home is on a cell")
		elif without == "":
			without = tid
	check(with_grid >= 1, "the main town has its grid")
	check(not w.facts.query("TOWN_GRID_LAID", 0, 1 << 30).is_empty(), "news")
	if without == "":
		return
	# a settlement without a grid answers at tile level, and gets one when designated
	var foot0 := TownGrid.footprint(w, without)
	check_eq(foot0.size(), 1, "its homes on its own tile")
	check(not w.peek("town")["towns"].has(without), "nothing stored for it")
	check_eq(TownGrid.step_up(w, without, "designated"), "", "designated a municipality")
	check(TownGrid.has_grid(w, without), "now it has a grid")
	check(TownGrid.step_up(w, without) != "", "only once")


func test_growth_is_scored_and_pure() -> void:
	var w := _game(1, 2, true, [Siting.FLAG]).world
	var h := w.state_hash()
	var rows := TownGrid.site_scores(w, "d:1", "HOUSING", 6)
	check_eq(w.state_hash(), h, "pure")
	check(rows.size() == 6, "options")
	for i in rows.size():
		var r: Dictionary = rows[i]
		check_eq(String(r["blocked"]), "", "free")
		for k in ["jobs", "school", "clinic", "shops", "utilities", "water", "road", "centre", "fast_road", "industry", "noise"]:
			check(r["parts"].has(k), "part %s" % k)
		if i > 0:
			check(float(rows[i - 1]["score"]) >= float(r["score"]), "best first")
	check_eq(TownGrid.site_scores(w, "d:1", "HOUSING", 6), rows, "the same answer twice")
	# a fast road beside a cell keeps homes away
	var links := Transport._links(w)
	var lid := ""
	for k in EconUtil.sorted_keys(links):
		if lid == "" and int(links[k].get("globe", 0)) == 0 and (links[k]["path"] as Array).size() >= 3:
			lid = String(k)
	var l: Dictionary = w.table("transport")["links"][lid]
	l["kind"] = "PAVED"
	l["cond"] = 1000
	Transport._bump(w)
	var on_road := TownGrid.centre_cell(Transport.int_tile(int(l["path"][1])))
	check(float(TownGrid.cell_score(w, "d:1", on_road)["parts"]["fast_road"]) < 0.0, "a fast road is a penalty")
	check(float(TownGrid.cell_score(w, "d:1", on_road)["parts"]["road"]) > 0.0, "a road is a draw")
	# the shore or a river draws
	var wet := Vector2i(-1, -1)
	for y in range(1, Terrain.H - 1):
		for x in range(1, Terrain.W - 1):
			if wet.x < 0 and Terrain.at(w, x, y) == "r" and Terrain.at(w, x + 1, y) in ColonyLayout.BUILD_TERRAIN:
				wet = Vector2i(x + 1, y)
	if wet.x >= 0:
		var c := Vector2i(wet.x * TownGrid.PER_TILE, wet.y * TownGrid.PER_TILE + 15)
		check(float(TownGrid.cell_score(w, "d:1", c)["parts"]["water"]) > 1.0, "by the river")
		check(float(TownGrid.cell_score(w, "d:1", c + Vector2i(20, 0))["parts"]["water"]) < float(TownGrid.cell_score(w, "d:1", c)["parts"]["water"]), "less far from it")
	# land reserved for another use is refused, and says why
	var t := TownGrid.tile_of(rows[0]["cell"])
	check_eq(Siting.set_use(w, [t], "NATURE"), "", "reserved")
	check(String(TownGrid.cell_score(w, "d:1", rows[0]["cell"])["blocked"]).contains("reserved"), "refused: reserved")
	check(not TownGrid.site_scores(w, "d:1", "HOUSING", 6).any(func(r): return TownGrid.tile_of(r["cell"]) == t), "not offered")
	# two seeds, two towns
	var w2 := _game(2, 2).world
	check(w2.peek("town")["towns"].get("d:1", {}).get("cells", {}).keys() != w.peek("town")["towns"]["d:1"]["cells"].keys(), "towns differ by seed")


func test_forms_are_a_policy_and_towers_wait_for_apartments() -> void:
	var w := _game().world
	check(TownGrid.set_forms(w, "*", ["PALACE"]) != "", "only the known forms")
	check_eq(TownGrid.set_forms(w, "*", ["APARTMENT", "HOUSE"]), "", "the commander allows apartments")
	check_eq(w.facts.query("TOWN_FORMS_SET", 0, 1 << 30).size(), 1, "news")
	var nid := EconSetup.add_facility(w, "HOUSING", _org(w), "d:1", false)
	_tick(w)
	check_eq(TownGrid.form_of(w, nid), "APARTMENT", "a new block is built as the first allowed form")
	check_eq(TownGrid.cells_of(w, nid).size(), 1, "on one cell")
	var old: String = _housing_of(w, "d:1")[0]
	check(TownGrid.connection_m(w, nid) < TownGrid.connection_m(w, old) + 15, "less street per home")
	# towers only once the town has apartments
	var other := ""
	for s in ColonyLayout.settlements(w):
		if TownGrid.has_grid(w, String(s["id"])) and String(s["id"]) != "d:1":
			other = String(s["id"])
			break
	if other != "":
		check_eq(TownGrid.set_forms(w, other, ["TOWER", "HOUSE"]), "", "towers allowed by policy")
		check_eq(TownGrid.forms_allowed(w, other), ["HOUSE"], "but not before apartments: %s" % str(TownGrid.forms_allowed(w, other)))
	check_eq(TownGrid.set_forms(w, "d:1", ["TOWER", "APARTMENT", "HOUSE"]), "", "d:1 may build towers")
	check(TownGrid.forms_allowed(w, "d:1").has("TOWER"), "it has apartments")
	# rebuilding upward
	var n_old := TownGrid.cells_of(w, old).size()
	check_eq(TownGrid.set_form(w, old, "APARTMENT"), "", "rebuilt as apartments")
	check(TownGrid.cells_of(w, old).size() < n_old, "fewer cells")
	check_eq(TownGrid.form_of(w, old), "APARTMENT", "the new form")
	var homes := 0
	for ck in TownGrid.cells_of(w, old):
		homes += int(TownGrid._index(w)["cells"][ck][2])
	check_eq(homes, TownGrid._homes(w.peek("facility")[old]), "the same homes")
	check(TownGrid.set_form(w, old, "CASTLE") != "", "not an unknown form")
	check(TownGrid.in_town_km(w, old, nid) >= 0.0, "a distance in town")


func test_gone_buildings_free_their_cells() -> void:
	var w := _game().world
	var fid: String = _housing_of(w, "d:1")[0]
	var cs := TownGrid.cells_of(w, fid)
	check(not cs.is_empty(), "it has cells")
	w.table("facility").erase(fid)
	_tick(w)
	check(TownGrid.cells_of(w, fid).is_empty(), "freed")
	check(String((w.peek("town")["towns"]["d:1"]["cells"] as Dictionary).get(cs[0], [""])[0]) != fid, "the cell is no longer its")


func test_in_the_game_deterministic_and_save_load() -> void:
	var a := _game(2, 3)
	var b := _game(2, 3)
	for s in [a, b]:
		TownGrid.set_forms(s.world, "*", ["APARTMENT", "HOUSE"])
		EconSetup.add_facility(s.world, "HOUSING", _org(s.world), "d:1", false)
		s.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "deterministic")
	var path := "user://test_town_grid.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := EconSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_location_value_and_what_building_up_reads() -> void:
	var w := _game(1, 2, true, [Siting.FLAG]).world
	var h := w.state_hash()
	# by the water a home is worth more, and it changes from one street to the next
	var wet := Vector2i(-1, -1)
	for y in range(1, Terrain.H - 1):
		for x in range(1, Terrain.W - 2):
			if wet.x < 0 and Terrain.at(w, x, y) in ["r", Terrain.SEA] and Terrain.at(w, x + 1, y) in ColonyLayout.BUILD_TERRAIN \
					and Terrain.at(w, x + 2, y) in ColonyLayout.BUILD_TERRAIN:
				wet = Vector2i(x + 1, y)
	check(wet.x >= 0, "a shore on the map")
	if wet.x >= 0:
		var c := Vector2i(wet.x * TownGrid.PER_TILE, wet.y * TownGrid.PER_TILE + 15)
		var v0 := TownGrid.value(w, c)
		var v1 := TownGrid.value(w, c + Vector2i(1, 0))
		var vfar := TownGrid.value(w, c + Vector2i(12, 0))
		check(float(v0["parts"]["view"]) > 0.0 and float(vfar["parts"]["view"]) == 0.0, "a view by the water only")
		check(int(v0["value_pm"]) > int(v1["value_pm"]) and int(v1["value_pm"]) > int(vfar["value_pm"]) - 200,
			"dearer the closer to the water (%d, %d, %d)" % [int(v0["value_pm"]), int(v1["value_pm"]), int(vfar["value_pm"])])
		for k in TownGrid.VALUE_PARTS:
			check(v0["parts"].has(k), "part %s" % k)
		check(not v0["parts"].has("noise") and not v0["parts"].has("centre"), "no randomness in the value")
		check_eq(w.state_hash(), h, "the value is pure")
		TownGrid.step_month(w)   # nothing new near it: the value stays
		check_eq(TownGrid.value(w, c), v0, "stable month to month")
	# form figures
	var ft := TownGrid.form_table()
	check(int(ft["HOUSE"]["land_m2"]) == 1000 and int(ft["APARTMENT"]["land_m2"]) < 200 and int(ft["TOWER"]["land_m2"]) == 50, "land per home %s" % str(ft))
	check(int(ft["TOWER"]["conn_m"]) < int(ft["APARTMENT"]["conn_m"]) and int(ft["APARTMENT"]["conn_m"]) < int(ft["HOUSE"]["conn_m"]), "connection per home")
	# a school's catchment, and when it is full
	var school := ""
	var fac: Dictionary = w.peek("facility")
	for fid in EconUtil.sorted_keys(fac):
		if school == "" and String(fac[fid]["type"]) == "SCHOOL":
			school = String(fid)
	check(school != "", "a school")
	if school == "":
		return
	var h2 := w.state_hash()
	var cm := TownGrid.catchment(w, school)
	check_eq(w.state_hash(), h2, "pure")
	check(int(cm["cells"]) > 0 and int(cm["free"]) <= int(cm["cells"]) and float(cm["reach_km"]) == 1.5 and not bool(cm["full"]), "room near the school %s" % str(cm))
	var sp := TownGrid._pos_km(w, school)
	var st := Vector2i(floori(sp.x / 3.0), floori(sp.y / 3.0))
	Siting.set_use(w, Siting.tiles_around(w, st, 2), "INDUSTRY")
	var cm2 := TownGrid.catchment(w, school)
	check(bool(cm2["full"]) and int(cm2["free"]) == 0, "no room left near the school %s" % str(cm2))
