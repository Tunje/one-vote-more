extends TestCase
## Terra: climate, weather, storms, phenomena, pollution drift and greenhouse (sim/planet/planet_climate.gd, A40, T2).


func _world(seed_v: int = 4) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	return w


## A land cell near the given latitude (degrees).
func _cell_near(w: WorldState, lat: float, land: bool = true) -> int:
	var best := -1
	var bd := INF
	for i in Planet.cell_count(w):
		if (Planet.height(w, i) >= 0) != land:
			continue
		var d := absf(Planet.lat_lon(i).x - lat)
		if d < bd:
			bd = d
			best = i
	return best


func test_seasons_latitude_and_height() -> void:
	var w := _world()
	var n := _cell_near(w, 45.0)
	var s := _cell_near(w, -45.0)
	check(float(PlanetClimate.climate(w, n, 6)["temp_c"]) > float(PlanetClimate.climate(w, n, 0)["temp_c"]) + 5.0, "northern July warmer than January")
	check(float(PlanetClimate.climate(w, s, 0)["temp_c"]) > float(PlanetClimate.climate(w, s, 6)["temp_c"]) + 5.0, "southern seasons are reversed")
	check_eq(PlanetClimate.climate(w, n, 6)["season"], "SUMMER", "July is northern summer")
	check_eq(PlanetClimate.climate(w, s, 6)["season"], "WINTER", "July is southern winter")
	var eq := _cell_near(w, 0.0)
	var pole := _cell_near(w, 85.0)
	check(float(PlanetClimate.climate(w, eq, 3)["temp_c"]) > float(PlanetClimate.climate(w, pole, 3)["temp_c"]) + 20.0, "equator warmer than pole")
	var g: float = PlanetClimate.climate(w, n, 6)["growing"]
	check(g >= 0.0 and g <= 1.0, "growing in 0..1")
	check(float(PlanetClimate.climate(w, n, 6)["growing"]) >= float(PlanetClimate.climate(w, n, 0)["growing"]), "summer grows better than winter")
	# height: the highest land is colder than lowland at the same latitude band
	var hi := 0
	for i in Planet.cell_count(w):
		if Planet.height(w, i) > Planet.height(w, hi):
			hi = i
	var lat_hi := Planet.lat_lon(hi).x
	var lo := _cell_near(w, lat_hi)
	if Planet.height(w, lo) < Planet.height(w, hi) - 20:
		check(float(PlanetClimate.climate(w, hi, 6)["temp_c"]) < float(PlanetClimate.climate(w, lo, 6)["temp_c"]), "mountains are colder")


func test_weather_is_pure_covers_any_hex_and_counts_droughts() -> void:
	var a := _world(9)
	var b := _world(9)
	for cell in [0, 1234, 5000, 10241, Planet.landing(a)]:
		for m in [0, 17, 240]:
			check_eq(PlanetClimate.weather(a, cell, m), PlanetClimate.weather(b, cell, m), "same seed, hex %d month %d" % [cell, m])
	var l := Planet.landing(a)
	var lo := 999
	var hi := 0
	var spell := 0
	for m in 600:
		var wx := PlanetClimate.weather(a, l, m)
		lo = mini(lo, int(wx["rain_pct"]))
		hi = maxi(hi, int(wx["rain_pct"]))
		var dry: bool = int(wx["rain_pct"]) < PlanetClimate.DRY_PCT
		spell = spell + 1 if dry else 0
		check_eq(int(wx["drought_months"]), mini(spell, 24), "drought_months counts the dry spell (month %d)" % m)
	check(lo < 75 and hi > 130, "rain varies (%d..%d)" % [lo, hi])


func test_storms_are_deterministic_contiguous_and_plausible() -> void:
	var a := _world(5)
	var b := _world(5)
	var nb: Array = Planet.geometry(Planet.freq(a))["nbrs"]
	var kinds := {}
	for m in 240:
		a.month = m
		b.month = m
		PlanetClimate.step_month(a)
		PlanetClimate.step_month(b)
		check_eq(var_to_str(a.peek("planet")["storms"]), var_to_str(b.peek("planet")["storms"]), "same storms, month %d" % m)
		for s in a.peek("planet")["storms"] + a.peek("planet")["phenomena"]:
			kinds[s["kind"]] = true
			check(int(s["strength"]) >= 1 and int(s["strength"]) <= 5, "strength 1..5")
			var cells: Array = s["cells"]
			for k in range(1, cells.size()):
				check(int(cells[k]) in Array(nb[int(cells[k - 1])]), "%s moves hex by hex" % s["kind"])
	for k in ["CYCLONE", "DUST", "BLIZZARD", "RAIN_FRONT", "SOLAR_FLARE", "MOON_SURGE"]:
		check(kinds.has(k), "%s happens within 20 years" % k)
	check(a.rng.to_dict()["states"].has("planet.weather"), "storms draw on their own stream")


func test_storms_at_and_phenomena_at() -> void:
	var w := _world()
	var t := w.table("planet")
	t["storms"] = [{"kind": "CYCLONE", "strength": 2, "cells": [5, 6], "global": false},
		{"kind": "RAIN_FRONT", "strength": 4, "cells": [6], "global": false}]
	t["phenomena"] = [{"kind": "SOLAR_FLARE", "strength": 1, "cells": [], "global": true}]
	check_eq(PlanetClimate.storms_at(w, 6), [{"kind": "RAIN_FRONT", "strength": 4}, {"kind": "CYCLONE", "strength": 2}], "strongest first")
	check_eq(PlanetClimate.storms_at(w, 7), [], "untouched hex")
	check_eq(PlanetClimate.phenomena_at(w, 9999), [{"kind": "SOLAR_FLARE", "strength": 1}], "a flare hits every hex")


func test_pollution_drifts_downwind_and_warming_stays_small() -> void:
	var w := _world()
	w.table("econ")["s"] = {"emissions": {"d:1": 20000, "d:2": 10000}}   # 30 units a month, founding-era scale
	for m in 1200:
		w.month = m
		PlanetClimate.step_month(w)
	var l := Planet.landing(w)
	var at_home := PlanetClimate.air_pollution(w, l)
	check(at_home > 20.0, "the colony breathes its own smoke (%.1f)" % at_home)
	var downwind := 0
	for k in w.peek("planet")["air"]:
		if int(k) != l and int(w.peek("planet")["air"][k]) > 0:
			downwind += 1
	check(downwind >= 2, "smoke reaches hexes downwind (%d)" % downwind)
	var warm := PlanetClimate.warming_c(w)
	check(warm > 0.05 and warm < 0.3, "a century of founding-era industry: barely noticeable warming (%.3f °C)" % warm)
	var before := float(PlanetClimate.climate(_world(), l, 6)["temp_c"])
	check(float(PlanetClimate.climate(w, l, 6)["temp_c"]) > before, "warming raises the climate baseline")


func test_provider_runs_in_nature_and_reports_weather_facts() -> void:
	var sim := Simulation.new(3)
	sim.register(PlanetProvider.new())
	sim.new_game()
	check(Planet.ready(sim.world), "the provider makes the planet")
	for _m in 36:
		sim.step()
	check(sim.world.indicators.read("PLANET_RAIN_PCT") > 0, "rain indicator published")
	check(sim.world.indicators.defs.has("PLANET_WARMING"), "warming indicator defined")
	for f in sim.world.facts.query("PLANET_"):
		check(f["responsible"].is_empty() and f["data"].has("hex"), "weather facts blame no one and name the hex")
	var a := Simulation.new(3)
	a.register(PlanetProvider.new())
	a.new_game()
	for _m in 36:
		a.step()
	check_eq(a.world.state_hash(), sim.world.state_hash(), "deterministic")
