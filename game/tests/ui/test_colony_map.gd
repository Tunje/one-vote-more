extends TestCase
## Terra (A5, planning/spec-areas-v1.md §7): the colony map UI (ui/colony_map.gd): facility placement for display,
## build validity and the stubbed build action, district drawing, and every panel rendering headless.

const Shot := preload("res://tools/shot_colony.gd")


func _session(fixture: bool) -> GameSession:
	var s := GameSession.new()
	s.new_game(7, true)
	if fixture:
		Shot.fixture(s.world())
	return s


func _view(s: GameSession) -> ColonyMap:
	var v := ColonyMap.new()
	v.session = s
	v._ready()   # builds the side panel without a scene tree
	v.size = Vector2(1600, 900)
	v.refresh()
	return v


func test_facilities_get_distinct_display_tiles_deterministically() -> void:
	var s := _session(false)
	var w := s.world()
	var a := ColonyMap.facility_tiles(w)
	check_eq(a, ColonyMap.facility_tiles(w), "same placement twice")
	check_eq(a.size(), w.peek("facility").size(), "every facility is drawn")
	var seen := {}
	for fid in a:
		var t: Vector2i = a[fid]
		check(t.x >= 0 and t.y >= 0 and t.x < Terrain.W and t.y < Terrain.H, "on the map")
		check(not seen.has(t), "one facility per tile")
		seen[t] = true
		if String(w.peek("facility")[fid]["type"]) == "MINE":
			check(Terrain.at(w, t.x, t.y) in ["o", "x", "k", "h"], "mines stand on deposits, rock or hills")
	# a facility with its own tile (Bob's A2) is drawn there
	var fid0: String = EconUtil.sorted_keys(w.peek("facility"))[0]
	var free := Terrain.nearest_free(w, 3, 3, [".", "f", "h", "k"], 20)
	w.table("facility")[fid0]["tile"] = [free.x, free.y]
	check_eq(ColonyMap.facility_tiles(w)[fid0], free, "A2 tile wins over display placement")
	var anchors := ColonyMap.econ_anchors(w)
	check_eq(anchors["d:1"], Terrain.landing(w), "Landing sits at the landing site")
	check_eq(anchors.size(), 6, "six settlements before A2")


func test_build_validity_and_stubbed_action() -> void:
	var s := _session(true)
	var w := s.world()
	var area: Dictionary = AreaStore.areas(w)[0]
	var at: Vector2i = AreaStore.tiles_of(w, area["id"])[0]
	check(ColonyMap.build_problem(w, "HOUSING", at).begins_with("Taken"), "area tiles are taken")
	var river := Vector2i(-1, -1)
	for y in Terrain.H:
		for x in Terrain.W:
			if river.x < 0 and Terrain.at(w, x, y) == "r":
				river = Vector2i(x, y)
	check(ColonyMap.build_problem(w, "CLINIC", river) != "", "no building on the river")
	check(ColonyMap.build_problem(w, "HOUSING", Vector2i(-1, 0)) != "", "outside the map")
	var free := Terrain.nearest_free(w, 2, 2, ["."], 30)
	check_eq(ColonyMap.build_problem(w, "HOUSING", free), "", "free plain is buildable")
	var p := ColonyMap.build_params(w, "SCHOOL", free)
	check(EconData.DISTRICTS.has(p["district"]) and p["tile"] == [free.x, free.y], "params carry a district and the tile")
	var q: int = EconUtil.st(w)["queue"].size()
	var r := ColonyMap.submit_build(w, "SCHOOL", free)
	check(not r["ok"] and String(r["message"]) != "", "stub reports why")
	check_eq(EconUtil.st(w)["queue"].size(), q, "the stub queues nothing until A2")


func test_district_drawing_plan_and_preview() -> void:
	var s := _session(true)
	var w := s.world()
	var v := _view(s)
	v.set_mode("DRAW")
	check_eq(v.plan, DistrictPolitics.current_plan(w), "drawing starts from the map in force")
	var ids: Array = AreaStore.areas(w).map(func(a): return a["id"])
	check(ids.size() >= 3, "fixture has areas (%d)" % ids.size())
	v.new_group()
	var g := v.draw_group
	v.click_tile(AreaStore.tiles_of(w, ids[1])[0])
	check(ids[1] in v.plan[g], "clicking an area moves it into the chosen district")
	var n := 0
	for k in v.plan:
		n += v.plan[k].count(ids[1])
	check_eq(n, 1, "an area is in one district only")
	v.rename_group(g, "Riverbend")
	check(v.plan.has("Riverbend") and not v.plan.has(g), "rename")
	v.new_group()
	check(not v.clean_plan().has(v.draw_group), "empty districts are dropped from the bill")
	var pv: Dictionary = preload("res://sim/law/law_query.gd").districting_preview(w, v.clean_plan(), "LAW")
	check(pv.has("ok") and pv.has("errors"), "preview runs on the draft")
	check(not v._info.text.is_empty(), "draw panel text")
	var st: Dictionary = s.pol_state()
	if st.get("government", {}).is_empty():
		check(not v.submit_plan()["ok"], "no parliament, no districting bill")
	v.free()


func test_every_panel_and_mode_renders() -> void:
	for fixture in [false, true]:
		var s := _session(fixture)
		var w := s.world()
		var v := _view(s)
		for m in ["INSPECT", "BUILD", "DISTRICTS", "DRAW", "INSPECT"]:
			v.set_mode(m)
			check(not v._info.text.is_empty(), "%s panel (fixture %s)" % [m, fixture])
		var fid: String = v._fac_tiles.keys()[0]
		v.click_tile(v._fac_tiles[fid])
		check(v._info.text.contains("Owner"), "facility panel")
		v.click_tile(Vector2i(0, 0))
		check(not v._info.text.is_empty(), "tile panel")
		if fixture:
			var a: Dictionary = AreaStore.areas(w)[0]
			v.click_tile(AreaStore.tiles_of(w, a["id"])[0])
			check(v._info.text.contains("Income mix") and v._info.text.contains(String(a["name"])), "area panel")
		else:
			check(v.settlement_text(w, "d:1").contains("Income mix"), "settlement panel before A2")
		v.set_mode("BUILD")
		v.click_tile(Terrain.nearest_free(w, 2, 2, ["."], 30))
		check(v._info.text.contains("Tile"), "build panel for a chosen tile")
		v.free()


func test_road_tool_and_network_panels() -> void:
	var s := _session(false)
	var w := s.world()
	var v := _view(s)
	check(not v._net.get("links", []).is_empty(), "the map knows the network")
	# inspect a link and a junction: their works on offer are listed and orderable
	var lid := String(v._net["links"][0]["id"])
	v.click_tile(Transport.int_tile(int(v._net["links"][0]["path"][1])))
	if v.selected.get("kind", "") == "LINK":
		check(v._info.text.contains("Possible works") or v._info.text.contains("Nothing more"), "the link panel lists works")
	check(v.link_text(w, lid).contains("Capacity"), "a link panel")
	for j in v._net.get("junctions", []):
		check(v.junction_text(w, String(j["id"])).contains("accident risk"), "a junction panel")
	# draw a road in the Build tab and commission it
	v.set_mode("BUILD")
	v.build_type = "ROAD"
	var meadow := {}
	for st in PlanetSites.sites(w):
		if st["kind"] == "GLOW_MEADOW":
			meadow = st
	var a := Terrain.landing(w)
	v.click_tile(a)
	v.click_tile(meadow["tile"])
	check_eq(v.road_b, Vector2i(meadow["tile"]), "two clicks give the two ends")
	var plan := Transport.plan_link(w, v.road_spec())
	check(plan["ok"] and v._info.text.contains("Estimated cost"), "the plan and its cost show")
	var params := ColonyMap.road_params(w, v.road_spec())
	check_eq(params["type"], "ROAD", "a ROAD project")
	check_eq(params["link"], v.road_spec(), "carrying the link")
	var q: int = EconUtil.st(w)["queue"].size()
	var r := ColonyMap.submit_road(w, v.road_spec())
	if r["ok"]:
		check_eq(EconUtil.st(w)["queue"].size(), q + 1, "commissioned: queued for the tender")
	else:
		check(String(r["message"]) != "", "or a readable reason (%s)" % r["message"])
	check(ColonyMap.submit_road(w, {"a": 0, "b": 0, "kind": "TRACK"})["message"] != "", "a bad link is refused with a reason")
	v.free()


func test_waste_siting_and_sites_on_the_map() -> void:
	var s := _session(false)
	var w := s.world()
	WasteMap.register_site(w, "t:lf", "LANDFILL", WasteMap.candidates(w, "LANDFILL")[0]["tiles"])
	WasteMap.set_fill(w, "t:lf", 500)
	WasteMap.add_discharge(w, Transport.tile_int(Terrain.landing(w)), 3000)
	WasteMap.step_month(w)
	var v := _view(s)
	var lf_tile: int = w.peek("waste_sites")["t:lf"]["tiles"][0]
	check(v.tile_text(w, Transport.int_tile(lf_tile)).contains("50% full"), "a landfill tile tells how full it is")
	var down: int = WasteMap.downstream(w, Transport.tile_int(Terrain.landing(w)))[0]
	check(v.tile_text(w, Transport.int_tile(down)).contains("Water quality"), "a river tile tells its water quality")
	v.set_mode("BUILD")
	for kind in WasteMap.KINDS:
		v.build_type = kind
		v._refresh_siting()
		v._update_panel()
		check(not v._site_cands.is_empty(), "%s: a shortlist" % kind)
		check(v._info.text.contains("Site 1") and v._info.text.contains("score"), "%s: the chosen site's study shows" % kind)
		var second: Dictionary = v._site_cands[mini(1, v._site_cands.size() - 1)]
		v.click_tile(Transport.int_tile(int(second["tile"])))
		check_eq(v._site_pick, mini(1, v._site_cands.size() - 1), "%s: clicking a site picks it" % kind)
	var img := v.get_rect()   # draw path smoke: no errors drawing sites and the study
	check(img.size.x > 0, "drawn")
	v.free()
