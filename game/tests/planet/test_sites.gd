extends TestCase
## Terra: tourist sites (A42, sim/planet/planet_sites.gd).


func _world(seed_v: int) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	Terrain.generate(w)
	return w


func _ints_only(v: Variant) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return false
		TYPE_ARRAY:
			for e in v:
				if not _ints_only(e):
					return false
		TYPE_DICTIONARY:
			for k in v:
				if not _ints_only(v[k]):
					return false
	return true


func test_sites_are_pure_varied_and_integer() -> void:
	for seed_v in [1, 2, 7]:
		var w := _world(seed_v)
		var h := w.state_hash()
		var s := Planet.sites(w)
		check_eq(w.state_hash(), h, "reading sites changes no state (seed %d)" % seed_v)
		check(s.size() >= 8, "seed %d has a good number of sites (%d)" % [seed_v, s.size()])
		check_eq(var_to_str(s), var_to_str(PlanetSites._compute(_world(seed_v))), "same seed, same sites")
		var kinds := {}
		var wheres := {}
		var ids := {}
		for x in s:
			check(_ints_only(x), "only ints: %s" % x["id"])
			check(int(x["attraction"]) >= 0 and int(x["attraction"]) <= 100, "attraction 0..100")
			check_eq(x["season_mult"].size(), 12, "a value per calendar month")
			check(not ids.has(x["id"]), "unique id %s" % x["id"])
			ids[x["id"]] = true
			check(not ids.has("name:" + x["name"]), "unique name %s" % x["name"])
			ids["name:" + x["name"]] = true
			kinds[x["kind"]] = true
			wheres[x["where"]] = true
			if x["where"] == "COLONY":
				check_eq(int(x["cell"]), Planet.landing(w), "colony sites lie in the landing hex")
				check(x["tile"].x >= 0, "colony sites have a tile on the colony map")
				check_eq(int(x["travel_days"]), 0, "no trip needed")
			else:
				check(not Planet.is_water(w, int(x["cell"])), "globe sites stand on land")
				check(int(x["dist"]) > 0 and int(x["km"]) > 0 and int(x["travel_days"]) > 0, "a trip away")
		check(kinds.has("FIRST_LANDING"), "the landing site is a site")
		check(kinds.size() >= 5, "several kinds (%s)" % str(kinds.keys()))
		check(wheres.has("COLONY") and wheres.has("GLOBE"), "near and far sites")


func test_seasons_and_sky() -> void:
	var w := _world(1)
	for x in Planet.sites(w):
		var lo := 1000
		var hi := 0
		for v in x["season_mult"]:
			lo = mini(lo, int(v))
			hi = maxi(hi, int(v))
		if x["kind"] in ["AURORA_PLAIN", "GLOWING_FIELD", "SUMMIT", "GLOW_MEADOW"]:
			check(hi >= lo * 2, "%s is strongly seasonal (%d..%d)" % [x["id"], lo, hi])
	# the twin moons: predictable surges every couple of years
	var surges := 0
	for m in 240:
		if PlanetSites.moon_surge_pct(m) >= 300:
			surges += 1
	check(surges >= 4 and surges <= 30, "tidal bore surges in 20 years: %d" % surges)
	var nxt := PlanetSites.next_surge(5)
	check(nxt >= 5 and PlanetSites.moon_surge_pct(nxt) >= 300, "next surge is a surge")
	# a solar flare this month lights the auroras
	for x in Planet.sites(w):
		if x["kind"] == "AURORA_PLAIN":
			var calm := PlanetSites.season_pct(w, x)
			w.table("planet")["phenomena"] = [{"kind": "SOLAR_FLARE", "strength": 3, "cells": [], "global": true}]
			check(PlanetSites.season_pct(w, x) > calm, "a flare lights the aurora")
			w.table("planet")["phenomena"] = []
			break
