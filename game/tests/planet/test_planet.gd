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
	check(Planet.heights(_world(8)) != Planet.heights(a), "another seed, another planet")
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


## The colony on its hex: the colony map (terrain, areas, facilities) laid on the landing region, inside it, following
## the terrain; weather over the colony flagged.
func test_colony_lies_on_its_hex() -> void:
	var s := GameSession.new()
	s.new_game(3, true)
	var w := s.world()
	var v := PlanetView.new()
	v.session = s
	v._ready()
	check(v._colony_mesh.mesh != null, "the colony map is laid on the landing hex")
	var img := PlanetView.colony_image(w)
	check_eq(img.get_size(), Vector2i(Terrain.W, Terrain.H) * PlanetView.COLONY_PX, "one block of pixels per colony tile")
	check_eq(img.get_data(), PlanetView.colony_image(w).get_data(), "deterministic")
	var li := Planet.landing(w)
	for g in [Vector2(0, 0), Vector2(Terrain.W, 0), Vector2(0, Terrain.H), Vector2(Terrain.W, Terrain.H), Vector2(Terrain.landing(w))]:
		var p := v.colony_point(w, g)
		check_eq(Planet.cell_at(p.normalized(), Planet.freq(w), li), li, "colony map point %s stays inside the landing hex" % g)
		check(p.length() > 1.0 and p.length() < 1.0 + PlanetView.RELIEF * 100.0, "on the surface")
	check_eq(PlanetView.colony_hits(w), [], "calm weather: no hits")
	check(not v._alert_mesh.visible, "no warning rim")
	w.table("planet")["storms"] = [{"kind": "CYCLONE", "strength": 3, "cells": [li], "global": false}]
	v.refresh()
	check_eq(PlanetView.colony_hits(w), [{"kind": "CYCLONE", "strength": 3}], "a cyclone over the colony")
	check(v._alert_mesh.visible and v._marker_lbl.text.contains("Cyclone"), "warning rim and label")
	v.free()
