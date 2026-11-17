extends TestCase

const Company := preload("res://sim/economy/company.gd")
## M13 A1: terrain map and areas (planning/spec-areas-v1.md §1–§4; population.md §3, §26 tests 1 and 3).


func _world(seed_v: int = 11) -> WorldState:
	var w := WorldState.new(seed_v)
	Terrain.generate(w)
	AreaStore.change_listeners = []
	AreaStore.district_resolver = Callable()
	return w


## Make tiles plain ground (tests control their own terrain).
func _flatten(w: WorldState, tiles: Array) -> void:
	var rows: Array = w.table("map")["grid"]["rows"]
	for t in tiles:
		var row: String = rows[t.y]
		rows[t.y] = row.substr(0, t.x) + "." + row.substr(t.x + 1)


func _leaf(w: WorldState, hb: String, inc: String, n: int) -> void:
	PopStore.seed_leaf(w, {"hb": hb, "inc": inc, "occ": "SERVICES", "status": "EMPLOYED", "arch": "PRAG"}, n)


func test_terrain_is_deterministic_and_has_a_landing_site() -> void:
	var a := _world(5)
	var b := _world(5)
	check_eq(a.state_hash(), b.state_hash(), "same seed, same map")
	var l := Terrain.landing(a)
	check_eq(Terrain.at(a, l.x, l.y), "L", "landing site marked")
	var counts := {}
	for row in a.peek("map")["grid"]["rows"]:
		for c in String(row):
			counts[c] = int(counts.get(c, 0)) + 1
	check(counts.get("r", 0) > 20, "a river")
	check(counts.get("o", 0) >= 3, "ore deposits")
	check(counts.get("x", 0) >= 1, "rare-mineral deposit")
	check(counts.get("n", 0) >= 3, "native-crop land")


func test_housing_extends_or_founds_areas() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 50, "GOV")
	check(a != "", "first housing founds an area")
	check_eq(String(AreaStore.get_area(w, a)["name"]), "Landing", "the first area is Landing")
	var t2 := Terrain.nearest_free(w, l.x + 1, l.y, Terrain.BUILDABLE_HOUSING, 1)
	if AreaStore.adjacent_area(w, t2) == a:
		check_eq(AreaStore.place_housing(w, t2, 50, "GOV"), a, "next door extends the same area")
	var far := Terrain.nearest_free(w, (l.x + 30) % Terrain.W, l.y, Terrain.BUILDABLE_HOUSING, 10)
	var b := AreaStore.place_housing(w, far, 20, "COMPANY")
	check(b != "" and b != a, "apart founds a new area")
	check_eq(String(AreaStore.get_area(w, b)["kind"]), "CAMP", "company housing founds a camp")
	check_eq(AreaStore.place_housing(w, far, 10, "GOV"), "", "a taken tile cannot be built on")


func test_a_tile_split_conserves_people_and_records_history() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	_flatten(w, [l + Vector2i(1, 0)])
	AreaStore.place_housing(w, l + Vector2i(1, 0), 300, "GOV")
	if AreaStore.get_area(w, a)["tiles"].size() < 2:
		return  # map edge case
	_leaf(w, a, "I2", 600)
	_leaf(w, a, "I4", 300)
	var moved_seen := []
	AreaStore.change_listeners = [func(_w, moves): moved_seen.append_array(moves)]
	var b := AreaStore.split(w, a, [l + Vector2i(1, 0)], "SETTLEMENT", "TEST")
	check_eq(AreaStore.residents(w, a) + AreaStore.residents(w, b), 900, "nobody lost or duplicated")
	check_eq(AreaStore.residents(w, b), 450, "people follow the homes (half of them)")
	check_eq(String(AreaStore.get_area(w, b)["parents"][0]), a, "new area remembers its parent")
	check(not moved_seen.is_empty(), "listeners told where people went (savings follow them)")
	check(PopStore.reconcile(w).is_empty(), "population reconciles")


func test_no_split_by_headcount_any_more() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	_flatten(w, [l + Vector2i(1, 0)])
	AreaStore.place_housing(w, l + Vector2i(1, 0), 300, "GOV")
	_leaf(w, a, "I2", 5000)
	w.month = 12
	AreaStore.yearly(w)
	check_eq(AreaStore.get_area(w, a)["children"].size(), 0, "5,000 people within reach of one school stay one area")


func test_private_enclave_breaks_away_with_the_rich() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 200, "GOV")
	# one more public block east of the landing site, then two private homes in a row
	var row: Array = [l + Vector2i(1, 0), l + Vector2i(2, 0), l + Vector2i(3, 0)]
	_flatten(w, row)
	check_eq(AreaStore.place_housing(w, row[0], 100, "GOV"), a, "public block extends Landing")
	check_eq(AreaStore.place_housing(w, row[1], 5, "PRIVATE", "I5"), a, "private home extends Landing")
	check_eq(AreaStore.place_housing(w, row[2], 5, "PRIVATE", "I5"), a, "second private home")
	_leaf(w, a, "I2", 300)
	_leaf(w, a, "I5", 15)
	w.month = 12
	AreaStore.yearly(w)
	var kids: Array = AreaStore.get_area(w, a)["children"]
	check_eq(kids.size(), 1, "the private enclave split off")
	if kids.is_empty():
		return
	var e: String = kids[0]
	check_eq(String(AreaStore.get_area(w, e)["kind"]), "ENCLAVE", "it is an enclave")
	check_eq(PopStore.count(w, {"hb": e, "inc": "I5"}), 10, "the rich moved in (up to its 10 homes)")
	check_eq(PopStore.count(w, {"hb": e, "inc": "I2"}), 0, "ordinary households stayed")
	check(PopStore.reconcile(w).is_empty(), "population reconciles")


func test_merge_and_district_inheritance() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 100, "GOV")
	AreaStore.set_district(w, a, "dist:1")
	var far := Terrain.nearest_free(w, (l.x + 20) % Terrain.W, l.y, Terrain.BUILDABLE_HOUSING, 10)
	var b := AreaStore.place_housing(w, far, 30, "COMPANY")
	check_eq(String(AreaStore.get_area(w, b)["district"]), "dist:1", "a new area joins the nearest area's district")
	AreaStore.district_resolver = func(_w, _id): return "dist:law"
	var far2 := Terrain.nearest_free(w, l.x, (l.y + 15) % Terrain.H, Terrain.BUILDABLE_HOUSING, 10)
	var c := AreaStore.place_housing(w, far2, 30, "COMPANY")
	if c != "" and c != a and c != b:
		check_eq(String(AreaStore.get_area(w, c)["district"]), "dist:law", "law's resolver decides when set")
	_leaf(w, b, "I3", 40)
	AreaStore.merge(w, a, b)
	check_eq(AreaStore.residents(w, a), 40, "merged residents")
	check_eq(String(AreaStore.get_area(w, b)["status"]), "MERGED", "absorbed area kept for history")
	check(PopStore.reconcile(w).is_empty(), "population reconciles")


func test_a_new_game_has_one_area_the_landing() -> void:
	var sim := GameSim.make(3)
	var w := sim.world
	var all := AreaStore.areas(w)
	check_eq(all.size(), 1, "one area at the start: no sectors beyond the landfall point")
	var a: Dictionary = all[0]
	check_eq(String(a["name"]), "Landing", "it is the Landing")
	check_eq(a["tiles"], [Terrain.key(Terrain.landing(w).x, Terrain.landing(w).y)], "on the landfall tile")
	check_eq(AreaStore.capacity(w, String(a["id"])), 400, "only the landing shelters stand on it: a home per founding household")
	sim.run(1)
	var ds := preload("res://sim/law/law_query.gd").districts(w)
	check_eq(ds.size(), 1, "law's charter gives one district")
	check_eq(String(ds[0]["name"]), "The Colony", "named The Colony")
	check_eq(ds[0]["areas"], [String(a["id"])], "holding the Landing")
	check_eq(AreaStore.found_landing(w), String(a["id"]), "founding again changes nothing")
	check_eq(AreaStore.areas(w).size(), 1, "still one area")


func test_the_first_homes_on_the_landing_tile_are_the_landings() -> void:
	var w := _world()
	var id := AreaStore.found_landing(w)
	var l := Terrain.landing(w)
	check_eq(AreaStore.place_housing(w, l, 40, "GOV"), id, "homes on the claimed landfall tile go to the Landing")
	check_eq(AreaStore.capacity(w, id), 40, "its homes are counted")
	check_eq(AreaStore.get_area(w, id)["tiles"].size(), 1, "the tile is not added twice")
	check_eq(AreaStore.place_housing(w, l, 10, "GOV"), "", "a built tile cannot be built on again")


func test_a_block_belongs_to_the_first_area_that_builds_there() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var far := Terrain.nearest_free(w, (Terrain.landing(w).x + 30) % Terrain.W, Terrain.landing(w).y, Terrain.BUILDABLE_HOUSING, 10)
	var b := AreaStore.place_housing(w, far, 20, "COMPANY")
	check_eq(AreaStore.claim_block(w, a, "b:10,10"), a, "the Landing takes a free block")
	check_eq(AreaStore.claim_block(w, b, "b:10,10"), a, "a second area building there finds it taken")
	check_eq(AreaStore.area_of_block(w, "b:10,10"), a, "the block is the Landing's")
	check_eq(AreaStore.claim_block(w, b, "b:11,10"), b, "the other area takes its own block")
	AreaStore.merge(w, a, b)
	check_eq(AreaStore.area_of_block(w, "b:11,10"), a, "a merge carries the blocks")
	check_eq(AreaStore.blocks_of(w, b), [], "the absorbed area keeps none")
	check_eq(AreaStore.blocks_of(w, a), ["b:10,10", "b:11,10"], "the Landing has both")


func test_a_split_takes_the_blocks_on_its_tiles() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	var t2 := l + Vector2i(1, 0)
	_flatten(w, [t2])
	check_eq(AreaStore.place_housing(w, t2, 300, "GOV"), a, "next tile extends the Landing")
	var b_home := TownGrid.block_of(TownGrid.centre_cell(l))
	var b_east := TownGrid.block_of(TownGrid.centre_cell(t2))
	AreaStore.claim_block(w, a, b_home)
	AreaStore.claim_block(w, a, b_east)
	var c := AreaStore.split(w, a, [t2], "SETTLEMENT", "TEST")
	check_eq(AreaStore.area_of_block(w, b_east), c, "the block on the child's tile went with it")
	check_eq(AreaStore.area_of_block(w, b_home), a, "the block on the parent's tile stayed")


func test_found_landing_finds_the_area_on_the_landfall_tile() -> void:
	var w := _world()
	var far := Terrain.nearest_free(w, (Terrain.landing(w).x + 30) % Terrain.W, Terrain.landing(w).y, Terrain.BUILDABLE_HOUSING, 10)
	AreaStore.place_housing(w, far, 20, "COMPANY")
	check_eq(AreaStore.found_landing(w), "", "an area elsewhere is not the Landing, and none is founded beside it")


## Homes laid straight into the town grid's table (the shape TownGrid reads), in cells (fine coordinates), and their
## blocks claimed for the area.
func _homes(w: WorldState, area: String, cells: Array, per_cell: int) -> void:
	# real plants laid through Terra's TownGrid.lay (it claims the blocks): a family-size landlord of `per_cell` homes
	# on each cell, or a shop (no homes) when per_cell is 0
	var type := "LANDLORD" if per_cell > 0 else "SHOP"
	var cid := Company.create(w, type, "FAMILY", {"kind": "STATE", "holders": {"gov": 1000}}, "test " + type.to_lower(), {"area": area})
	for c in cells:
		var pid := Company.add_plant(w, cid, "FAMILY")
		var why := TownGrid.lay(w, area, pid, type, "%d,%d" % [c.x, c.y], per_cell)
		check_eq(why, "", "laid a %s on cell %s" % [type.to_lower(), str(c)])


func test_homes_within_a_schools_reach_stay_one_area() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var c0 := TownGrid.centre_cell(Terrain.landing(w))
	_homes(w, a, [c0, c0 + Vector2i(4, 0), c0 + Vector2i(8, 0)], 8)
	check_eq(AreaStore.capacity(w, a), 24, "the area's homes are the homes in its blocks")
	check(AreaStore.reach_split(w, a).is_empty(), "800 m across: no split")


func test_homes_beyond_a_schools_reach_split_off_with_their_people() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var c0 := TownGrid.centre_cell(Terrain.landing(w))
	var near: Array = []
	for i in 6:
		near.append(c0 + Vector2i(i % 3, i / 3))   # 48 homes in the middle
	var far: Array = [c0 + Vector2i(40, 0), c0 + Vector2i(41, 0)]   # 16 homes 4 km east
	_homes(w, a, near, 8)
	_homes(w, a, far, 8)
	_leaf(w, a, "I2", 400)
	_leaf(w, a, "I4", 240)
	var rs := AreaStore.reach_split(w, a)
	check(not rs.is_empty(), "a block farther than %.1f km from the homes' centre" % TownGrid.CATCH_KM["SCHOOL"])
	w.month = 12
	AreaStore.yearly(w)
	var kids: Array = AreaStore.get_area(w, a)["children"]
	check_eq(kids.size(), 1, "the far homes split off")
	if kids.is_empty():
		return
	var b: String = kids[0]
	check_eq(AreaStore.area_of_block(w, TownGrid.block_of(far[0])), b, "the far block is the new area's")
	check_eq(AreaStore.area_of_block(w, TownGrid.block_of(near[0])), a, "the middle stays")
	check_eq(AreaStore.capacity(w, b), 16, "its homes")
	check_eq(AreaStore.residents(w, b), 160, "people follow the homes: 16 of 64 homes, a quarter of 640")
	check_eq(PopStore.count(w, {"hb": b, "inc": "I4"}), 60, "every band keeps its share")
	check(PopStore.reconcile(w).is_empty(), "population reconciles")
	check_eq(Logbook.rows(w, {"kind": "AREA"}).size(), 1, "the split is a log row")
	check(AreaStore.reach_split(w, a).is_empty() and AreaStore.reach_split(w, b).is_empty(), "both parts are within reach now")


func test_shelters_laid_in_cells_on_the_landing_tile_are_counted_once() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var c0 := TownGrid.centre_cell(Terrain.landing(w))
	var cells: Array = []
	for i in 50:
		cells.append(c0 + Vector2i(i % 10, i / 10))   # 50 HOUSE cells of 8: the 400 landing shelters
	_homes(w, a, cells, 8)
	check_eq(AreaStore.capacity(w, a), 400, "400 shelters, counted from the cells only (not also as tile units)")


func test_a_neighbourhood_split_off_stays_in_its_town() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	check_eq(AreaStore.town_of(w, a), a, "the Landing is its own town")
	var c0 := TownGrid.centre_cell(Terrain.landing(w))
	var near: Array = []
	for i in 6:
		near.append(c0 + Vector2i(i % 3, i / 3))
	var far: Array = [c0 + Vector2i(40, 0), c0 + Vector2i(41, 0)]
	_homes(w, a, near, 8)
	_homes(w, a, far, 8)
	w.month = 12
	AreaStore.yearly(w)
	var b: String = AreaStore.get_area(w, a)["children"][0]
	check_eq(AreaStore.town_of(w, b), a, "the new neighbourhood is in the Landing's town")
	check_eq(AreaStore.areas_of_town(w, a), [a, b], "the town has two neighbourhoods")
	check_eq(AreaStore.area_for_new_block(w, a, TownGrid.block_of(c0 + Vector2i(44, 0))), b, "a block by the far homes joins them")
	check_eq(AreaStore.area_for_new_block(w, a, TownGrid.block_of(c0 + Vector2i(0, 4))), a, "a block in the middle joins the Landing")
	var far2 := Terrain.nearest_free(w, (Terrain.landing(w).x + 30) % Terrain.W, Terrain.landing(w).y, Terrain.BUILDABLE_HOUSING, 10)
	var e := AreaStore.place_housing(w, far2, 20, "COMPANY")
	check_eq(AreaStore.town_of(w, e), e, "an area founded apart is its own town")


func test_too_far_but_no_cut_is_a_log_row() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var c0 := TownGrid.centre_cell(Terrain.landing(w))
	_homes(w, a, [c0 + Vector2i(1, 1), c0 + Vector2i(2, 2)], 8)   # one block with homes
	_homes(w, a, [c0 + Vector2i(40, 1)], 0)                        # a far block with no homes
	w.month = 12
	AreaStore.yearly(w)
	check_eq(AreaStore.get_area(w, a)["children"].size(), 0, "nothing splits")
	check_eq(Logbook.rows(w, {"kind": "AREA", "what": "no cut"}).size(), 0, "a block without homes does not count as far")


func test_a_released_block_is_free_again() -> void:
	var w := _world()
	var a := AreaStore.found_landing(w)
	var far := Terrain.nearest_free(w, (Terrain.landing(w).x + 30) % Terrain.W, Terrain.landing(w).y, Terrain.BUILDABLE_HOUSING, 10)
	var b := AreaStore.place_housing(w, far, 20, "COMPANY")
	AreaStore.claim_block(w, a, "b:10,10")
	check_eq(AreaStore.release_block(w, "b:10,10"), a, "the Landing gives it up")
	check_eq(AreaStore.area_of_block(w, "b:10,10"), "", "nobody owns it")
	check_eq(AreaStore.claim_block(w, b, "b:10,10"), b, "another area may take it now")
	check_eq(AreaStore.release_block(w, "b:99,99"), "", "releasing a free block does nothing")
