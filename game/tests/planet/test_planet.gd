extends TestCase
## Terra: the hex planet (sim/planet/planet.gd).


func _world(seed_v: int) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	return w


func test_geometry_is_a_goldberg_sphere() -> void:
	var geo := Planet.geometry(Planet.FREQ)
	var n: int = geo["centers"].size()
	check_eq(n, Planet.cell_count_for(Planet.FREQ), "10f²+2 cells")
	var pent := 0
	for i in n:
		var poly: PackedVector3Array = geo["corners"][i]
		var en: PackedInt32Array = geo["edge_nbr"][i]
		check(poly.size() == 5 or poly.size() == 6, "cell %d has 5 or 6 corners" % i)
		check_eq(en.size(), poly.size(), "one neighbour per edge")
		if poly.size() == 5:
			pent += 1
		for j in en:
			check(j >= 0 and i in Array(geo["edge_nbr"][j]), "neighbour %d of %d is mutual" % [j, i])
	check_eq(pent, 12, "exactly 12 pentagons")
	check_eq(Planet.cell_at(geo["centers"][37]), 37, "cell_at finds a centre")


func test_generation_is_deterministic_idempotent_and_saves() -> void:
	var a := _world(7)
	var b := _world(7)
	check_eq(a.state_hash(), b.state_hash(), "same seed, same planet")
	var h := a.state_hash()
	Planet.generate(a)
	check_eq(a.state_hash(), h, "generating twice changes nothing")
	check(_world(8).peek("planet")["elev"] != a.peek("planet")["elev"], "another seed, another planet")
	var t: Dictionary = a.peek("planet")
	var back = SaveIO.decode_ordered(str_to_var(var_to_str(SaveIO.encode_ordered(t))))
	check_eq(var_to_str(back), var_to_str(t), "the planet table survives the save format")


func test_planet_has_seas_land_relief_and_a_sensible_landing() -> void:
	for s in [1, 2, 3, 4, 5]:
		var w := _world(s)
		var n := Planet.cell_count(w)
		var water := 0
		var high := 0
		for i in n:
			water += 1 if Planet.is_water(w, i) else 0
			high += 1 if Planet.level(w, i) >= 4 else 0
		check(water > n * 0.4 and water < n * 0.7, "seed %d: a sea share (%d/%d)" % [s, water, n])
		check(high >= 3, "seed %d: mountains (%d)" % [s, high])
		var l := Planet.landing(w)
		check(l >= 0 and not Planet.is_water(w, l), "seed %d: landing on land" % s)
		check(Planet.biome(w, l) in ["g", "f", "F"], "seed %d: landing on temperate ground (%s)" % [s, Planet.biome(w, l)])
		check(Planet.use_at(w, l).get("colony", false), "seed %d: landing holds the colony" % s)
		# the planet uses its own RNG seed: shared streams are untouched
		check(not w.rng.to_dict()["states"].has("planet.terrain"), "seed %d: no shared stream consumed" % s)


func test_view_builds_headless() -> void:
	var s := GameSession.new()
	s.new_game(3, true)
	check(Planet.ready(s.world()), "a new game has a planet")
	var v := PlanetView.new()
	v.session = s
	v._ready()
	check(v._globe.mesh != null and v._globe.mesh.get_surface_count() == 2, "land and water surfaces")
	v.free()
