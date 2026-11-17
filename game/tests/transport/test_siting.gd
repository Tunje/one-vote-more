extends TestCase
## Terra (Wilma's queued job 2026-11-15): site choice groundwork (sim/transport/siting.gd, flag SITING): land
## reserved by use, site options, a chosen site used instead of the nearest free tile. Unit tests only (no long runs).


func _game(seed_v: int = 1, months: int = 2, on: bool = true, extra: Array = []) -> Simulation:
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(Siting.FLAG)
	for f in extra:
		(sim.world.meta["on"] as Array).append(f)
	for _m in months:
		sim.step()
	return sim


func _org(w: WorldState) -> String:
	return String(CoreUtil.sorted_keys(w.peek("org"))[0])


func _k(t: Vector2i) -> String:
	return Terrain.key(t.x, t.y)


func test_flag_off_changes_nothing() -> void:
	var w := _game(1, 2, false).world
	var key0 := ColonyLayout.key(w)
	var ft0 := ColonyLayout.facility_tiles(w)
	var h := w.state_hash()
	var t0: Vector2i = ColonyLayout.econ_anchors(w)["d:1"]
	check(ColonyLayout.set_use(w, [t0], "NATURE") != "", "no reservations")
	check(ColonyLayout.site_options(w, "HOUSING", "d:1").is_empty(), "no options")
	check(ColonyLayout.place_at(w, String(CoreUtil.sorted_keys(ft0)[0]), t0) != "", "no chosen sites")
	check_eq(ColonyLayout.use_at(w, t0), "", "no use")
	check_eq(w.state_hash(), h, "nothing written")
	check_eq(ColonyLayout.key(w), key0, "the layout key is as before")
	check(w.peek("siting").is_empty(), "no table")


func test_reserved_land_is_refused_and_what_stands_stays() -> void:
	var w := _game().world
	var ft0 := ColonyLayout.facility_tiles(w).duplicate()
	var opts := ColonyLayout.site_options(w, "HOUSING", "d:1", 1)
	check_eq(opts.size(), 1, "a default site")
	var dt := ColonyLayout.as_tile(opts[0]["tile"])
	# reserve the land around the default site, and around a standing facility, as nature
	var fid0 := String(CoreUtil.sorted_keys(ft0)[0])
	var land := Siting.tiles_around(w, dt, 2)
	for t in Siting.tiles_around(w, ft0[fid0], 1):
		if not t in land:
			land.append(t)
	check_eq(ColonyLayout.set_use(w, land, "NATURE"), "", "reserved")
	check_eq(ColonyLayout.use_at(w, dt), "NATURE", "the use is on the tile")
	check(ColonyLayout.set_use(w, [dt], "PARK") != "", "only the listed uses")
	var f := w.facts.query("LAND_USE_SET", 0, 1 << 30)
	check(f.size() == 1 and String(f[0]["data"]["use"]) == "NATURE" and int(f[0]["data"]["tiles"]) == land.size()
		and f[0]["visibility"] == "PUBLIC" and (f[0]["data"]["kept"] as Array).has(fid0), "a public fact %s" % str(f))
	var ft1 := ColonyLayout.facility_tiles(w)
	for fid in ft0:
		check_eq(ft1[fid], ft0[fid], "%s keeps its tile" % fid)
	# a new building does not go onto the reserved land
	var nid := EconSetup.add_facility(w, "HOUSING", _org(w), "d:1", false)
	var nt: Vector2i = ColonyLayout.facility_tiles(w)[nid]
	check_eq(Siting.use_at(w, nt), "", "the new housing is off the reserved land (%s)" % str(nt))
	check(nt != dt, "not at the old default")
	# farmland: farms only
	var ot := ColonyLayout.site_options(w, "HOUSING", "d:2", 1)
	var ft := ColonyLayout.as_tile(ot[0]["tile"])
	check_eq(ColonyLayout.set_use(w, [ft], "FARMLAND"), "", "farmland")
	check(not Siting.fits("FARMLAND", "HOUSING") and Siting.fits("FARMLAND", "FARM") and Siting.fits("HOUSING", "CLINIC")
		and Siting.fits("INDUSTRY", "RETAIL") and not Siting.fits("HOUSING", "MINE") and not Siting.fits("NATURE", "FARM")
		and Siting.fits("OPEN", "MINE"), "the rules")
	check(ColonyLayout.site_options(w, "HOUSING", "d:2", 1)[0]["tile"] != _k(ft), "the housing default moves off farmland")
	check_eq(ColonyLayout.set_use(w, [ft], ""), "", "lifted")
	check_eq(ColonyLayout.site_options(w, "HOUSING", "d:2", 1)[0]["tile"], _k(ft), "and it is back")


func test_site_options_say_what_stands_near() -> void:
	var w := _game(1, 2, true, [RoadSafety.FLAG]).world
	var h := w.state_hash()
	var key0 := ColonyLayout.key(w)
	var opts := ColonyLayout.site_options(w, "CLINIC", "d:1", 5)
	check_eq(w.state_hash(), h, "pure")
	check_eq(ColonyLayout.key(w), key0, "the layout is unchanged")
	check(opts.size() >= 3, "several options (%d)" % opts.size())
	check(bool(opts[0]["default"]) and not opts.slice(1).any(func(o): return bool(o["default"])), "the first is today's default")
	var seen := {}
	var setl := ColonyLayout.settlements(w)
	var taken := Siting._taken(w)
	var any_road := false
	for o in opts:
		for k in ["tile", "terrain", "use", "town_km", "road_km", "homes", "near", "mine_km", "depot_km", "farmland_lost", "road"]:
			check(o.has(k), "field %s" % k)
		var t := ColonyLayout.as_tile(o["tile"])
		check(not seen.has(o["tile"]), "distinct tiles")
		seen[o["tile"]] = true
		check(not taken.has(String(o["tile"])), "free")
		check(Terrain.at(w, t.x, t.y) in ColonyLayout.BUILD_TERRAIN, "buildable")
		if not bool(o["default"]):
			check_eq(Transport._district_near(setl, t), "d:1", "in the district")
		if not (o["road"] as Dictionary).is_empty():
			any_road = true
			check(int(o["road"]["kmh"]) > 0 and o["road"].has("risk_pm") and int(o["road"]["added_pm"]) >= 0, "a road %s" % str(o["road"]))
	check(int(opts[0]["town_km"]) <= int(opts[opts.size() - 1]["town_km"]) + 3 * Siting.REACH, "near the settlement")
	check(any_road or opts.all(func(o): return int(o["road_km"]) != 0), "roads seen where they are")
	check_eq(ColonyLayout.site_options(w, "CLINIC", "d:1", 5), opts, "the same answer twice")


func test_a_chosen_site_is_used() -> void:
	var w := _game().world
	var opts := ColonyLayout.site_options(w, "RETAIL", "d:1", 4)
	check(opts.size() >= 3, "options")
	var pick := ColonyLayout.as_tile(opts[2]["tile"])
	var nid := EconSetup.add_facility(w, "RETAIL", _org(w), "d:1", false)
	var before: Vector2i = ColonyLayout.facility_tiles(w)[nid]
	check(before != pick, "the layout would put it elsewhere")
	check_eq(ColonyLayout.place_at(w, nid, pick), "", "placed")
	check_eq(ColonyLayout.facility_tiles(w)[nid], pick, "it stands at the chosen site")
	# refusals
	var old := String(CoreUtil.sorted_keys(w.peek("facility"))[0])
	check(ColonyLayout.place_at(w, old, ColonyLayout.as_tile(opts[1]["tile"])) != "", "a standing building is not moved")
	var nid2 := EconSetup.add_facility(w, "RETAIL", _org(w), "d:1", false)
	check(ColonyLayout.place_at(w, nid2, pick).contains("taken"), "not where another stands")
	var sea := Vector2i(-1, -1)
	for y in Terrain.H:
		for x in Terrain.W:
			if sea.x < 0 and Terrain.at(w, x, y) == Terrain.SEA:
				sea = Vector2i(x, y)
	if sea.x >= 0:
		check(ColonyLayout.place_at(w, nid2, sea) != "", "not on the sea")
	var far := ColonyLayout.as_tile(ColonyLayout.site_options(w, "RETAIL", "d:3", 2)[1]["tile"])
	check(ColonyLayout.place_at(w, nid2, far).contains("not in"), "not in another district")
	var p1 := ColonyLayout.as_tile(opts[1]["tile"])
	ColonyLayout.set_use(w, [p1], "FARMLAND")
	check(ColonyLayout.place_at(w, nid2, p1).contains("reserved"), "not on land reserved for farms")
	w.month += 1
	check(ColonyLayout.place_at(w, nid2, ColonyLayout.as_tile(opts[3]["tile"])) != "", "only in the month it opens")


func test_a_project_site_goes_to_its_building() -> void:
	var w := _game().world
	var opts := ColonyLayout.site_options(w, "CLINIC", "d:2", 3)
	var pick := ColonyLayout.as_tile(opts[2]["tile"])
	w.table("project")["proj:t1"] = {"id": "proj:t1", "type": "CLINIC", "status": "TENDER", "district": "d:2"}
	w.table("project")["proj:t2"] = {"id": "proj:t2", "type": "ROAD", "status": "TENDER", "district": "d:2"}
	check(ColonyLayout.place_at(w, "proj:t2", pick) != "", "a road project has no site")
	check_eq(ColonyLayout.place_at(w, "proj:t1", pick), "", "a site for the clinic to be built")
	check(not ColonyLayout.site_options(w, "CLINIC", "d:2", 5).any(func(o): return o["tile"] == _k(pick)), "the site is spoken for")
	var nid := EconSetup.add_facility(w, "RETAIL", _org(w), "d:2", false)
	check(ColonyLayout.place_at(w, nid, pick).contains("taken"), "taken by the project")
	check(ColonyLayout.facility_tiles(w)[nid] != pick, "the layout keeps it free")
	# the clinic is built: it stands at the chosen site from the month it opens
	var p: Dictionary = w.table("project")["proj:t1"]
	p["status"] = "DONE"
	p["done_month"] = w.month
	var fid := EconSetup.add_facility(w, "CLINIC", _org(w), "d:2", false)
	w.add_fact({"type": "ECON_PROJECT_COMPLETED", "owner": "economy", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 30, "visibility": "PUBLIC", "data": {"project": "proj:t1", "facility": fid, "type": "CLINIC"}})
	check_eq(ColonyLayout.facility_tiles(w)[fid], pick, "the clinic stands at its site")
	Siting.step_month(w)
	var pl: Dictionary = w.peek("siting")["placed"]
	check(pl.has(fid) and not pl.has("proj:t1"), "the site moves to the building")
	check_eq(ColonyLayout.facility_tiles(w)[fid], pick, "and stays")
	# a cancelled project frees its site
	w.table("project")["proj:t3"] = {"id": "proj:t3", "type": "SCHOOL", "status": "TENDER", "district": "d:2"}
	check_eq(ColonyLayout.place_at(w, "proj:t3", ColonyLayout.as_tile(opts[1]["tile"])), "", "a school site")
	w.table("project")["proj:t3"]["status"] = "CANCELLED"
	Siting.step_month(w)
	check(not w.peek("siting")["placed"].has("proj:t3"), "dropped when cancelled")


func test_in_the_game_deterministic_and_save_load() -> void:
	var a := _game(2, 2)
	var b := _game(2, 2)
	for s in [a, b]:
		var w: WorldState = s.world
		var o := ColonyLayout.site_options(w, "HOUSING", "d:1", 3)
		ColonyLayout.set_use(w, Siting.tiles_around(w, o[1]["tile"], 1), "INDUSTRY")
		var nid := EconSetup.add_facility(w, "RETAIL", _org(w), "d:1", false)
		ColonyLayout.place_at(w, nid, o[2]["tile"])
		s.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "deterministic")
	var path := "user://test_siting.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := EconSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	check_eq(ColonyLayout.facility_tiles(c.world), ColonyLayout.facility_tiles(a.world), "the same layout after loading")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
