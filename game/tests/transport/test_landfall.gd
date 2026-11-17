extends TestCase
## Terra, rebuild step 1 (planning/rebuild-company.md 9.12, 12.1, 12.2, 12.4): the colony starts as ONE place where it
## landed ("no sectors beyond landfallpoint that's up to where things are built"), with no roads beyond it; the town
## grid is on and a place gets its grid from its first home ("Below 250 start a gridd anyway"); street blocks are the
## pieces areas are made of; the road and planet systems are on.

const RoadSafetyLaw := preload("res://sim/law/road_safety_law.gd")


func _game(seed_v: int = 1, months: int = 0) -> Simulation:
	var sim := GameSim.make(seed_v, "BALANCED", {}, true)
	for _m in months:
		sim.step()
	return sim


func test_one_place_at_the_landfall_and_no_roads() -> void:
	for seed_v in [1, 2]:
		var w := _game(seed_v, 2).world
		var setl := ColonyLayout.settlements(w)
		check(setl.size() >= 1, "seed %d: the landfall place exists" % seed_v)
		if AreaStore.areas(w).is_empty():
			check_eq(setl.size(), 1, "seed %d: one place before the first area" % seed_v)
			check_eq(String(setl[0]["id"]), ColonyLayout.LANDING, "it is the landfall place")
		check_eq(setl[0]["tile"], Terrain.landing(w), "seed %d: it stands where the colony landed" % seed_v)
		check(ColonyLayout.anchors(w).size() <= AreaStore.areas(w).size(), "no district laid out in advance")
		check(Transport.network(w)["links"].is_empty(), "seed %d: no roads beyond the landfall place" % seed_v)
		var r := Transport.route(w, "port", String(setl[0]["id"]), "ROAD")
		check(r["ok"], "seed %d: the port is at the landfall place (%s)" % [seed_v, r.get("reason", "")])


func test_the_road_and_planet_systems_are_on() -> void:
	var w := _game(1).world
	check(TownGrid.on(w) and PlanetSeasons.on(w) and PlanetEcology.on(w) and FreightRoads.on(w)
		and RoadSafety.on(w) and GovBuilder.road_works_on(w) and RoadSafetyLaw.on(w) and GovWildlife.on(w),
		"town grid, seasons, ecology, freight on roads, road works and road safety are part of the game")
	check(not PrivateRoads.on(w), "private roads and tolls are left out for now (12.12)")
	check(w.lever_defs.has("LAW_SPEED_NEAR_HOMES") and Legislature.lever_available(w, w.lever_defs["LAW_SPEED_NEAR_HOMES"]),
		"the road safety law is on the table")


func test_street_blocks_are_fixed_by_geography() -> void:
	check_eq(TownGrid.block_of("0,0"), "b:0,0", "the first block")
	check_eq(TownGrid.block_of("3,3"), "b:0,0", "four cells to a block")
	check_eq(TownGrid.block_of("4,7"), "b:1,1", "the next block")
	check_eq(TownGrid.block_of(Vector2i(-1, -4)), "b:-1,-1", "negative cells floor")
	var cs := TownGrid.block_cells("b:2,5")
	check_eq(cs.size(), 16, "16 cells to a block")
	for ck in cs:
		check_eq(TownGrid.block_of(ck), "b:2,5", "%s lies in its block" % ck)
	check_eq(int(TownGrid.FORMS["HOUSE"]["homes"]), 8, "8 house plots to a cell")


## A grid from the first home: tests/transport/test_site.gd (the landing shelters get the Landing its grid).


func test_where_an_area_could_be_cut() -> void:
	var w := _game(1).world
	# a river running north-south: two vertically joined river tiles
	var rt := Vector2i(-1, -1)
	for y in Terrain.H - 1:
		for x in Terrain.W:
			if rt.x < 0 and Terrain.at(w, x, y) == "r" and Terrain.at(w, x, y + 1) == "r":
				rt = Vector2i(x, y)
	check(rt.x >= 0, "seed 1 has a river")
	var rx := rt.x * TownGrid.PER_TILE + TownGrid.PER_TILE / 2   # the river's fine x
	var line := roundi(float(rx) / TownGrid.BLOCK_CELLS)
	var by := (rt.y * TownGrid.PER_TILE + TownGrid.PER_TILE) / TownGrid.BLOCK_CELLS   # where the two river tiles meet
	var blocks := ["b:%d,%d" % [line - 1, by], "b:%d,%d" % [line, by], "b:%d,%d" % [line + 1, by]]
	var cuts := TownGrid.boundaries(w, blocks)
	check_eq(cuts.size(), 2, "two streets leave blocks on both sides")
	check_eq(String(cuts[0]["kind"]), "RIVER", "the river is the strongest cut: %s" % str(cuts[0]))
	check_eq(int(cuts[0]["at"]), line * TownGrid.BLOCK_CELLS, "on the line by the river")
	check_eq(String(cuts[1]["kind"]), "STREET", "the other is a plain street")
	check_eq(cuts[0]["a"], ["b:%d,%d" % [line - 1, by]], "one block west of the river")
	check(TownGrid.boundaries(w, [blocks[0]]).is_empty(), "one block cannot be cut")
	check_eq(var_to_str(TownGrid.boundaries(w, blocks)), var_to_str(cuts), "pure")
