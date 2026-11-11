extends TestCase
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


func test_size_split_conserves_people_and_records_history() -> void:
	var w := _world()
	var l := Terrain.landing(w)
	var a := AreaStore.place_housing(w, l, 300, "GOV")
	_flatten(w, [l + Vector2i(1, 0), l + Vector2i(2, 0), l + Vector2i(3, 0)])
	for d in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]:
		var t: Vector2i = l + d
		if Terrain.at(w, t.x, t.y) in Terrain.BUILDABLE_HOUSING:
			AreaStore.place_housing(w, t, 300, "GOV")
	if AreaStore.get_area(w, a)["tiles"].size() < 2:
		return  # map edge case: not enough room next to the landing site in this seed
	_leaf(w, a, "I2", 600)
	_leaf(w, a, "I4", 300)
	var moved_seen := []
	AreaStore.change_listeners = [func(_w, moves): moved_seen.append_array(moves)]
	w.month = 12  # January
	AreaStore.yearly(w)
	var kids: Array = AreaStore.get_area(w, a)["children"]
	check_eq(kids.size(), 1, "oversized area split once")
	var b: String = kids[0]
	check_eq(AreaStore.residents(w, a) + AreaStore.residents(w, b), 900, "nobody lost or duplicated")
	check(AreaStore.residents(w, b) > 0, "people moved to the new area")
	check_eq(String(AreaStore.get_area(w, b)["parents"][0]), a, "new area remembers its parent")
	check(not moved_seen.is_empty(), "listeners told where people went (savings follow them)")
	check(PopStore.reconcile(w).is_empty(), "population reconciles")


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
