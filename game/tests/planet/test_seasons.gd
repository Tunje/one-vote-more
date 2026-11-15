extends TestCase
## Terra: ecology stage 3 — the farm year, heating and droughts (PlanetSeasons, flag SEASONS) and migrating birds
## (PlanetBirds, under ECO).


func _world(seed_v: int = 4, flags: Array = ["ECO"]) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	w.meta["on"] = flags.duplicate()
	w.table("econ")["s"] = {"emissions": {}}
	var l := Planet.landing(w)
	w.table("planet")["uses"] = {str(l): {"kind": "COLONY"}}
	return w


func _cell_near(w: WorldState, lat: float) -> int:
	var best := -1
	var bd := INF
	for i in Planet.cell_count(w):
		if Planet.is_water(w, i):
			continue
		var d := absf(Planet.lat_lon(i).x - lat)
		if d < bd:
			bd = d
			best = i
	return best


func test_the_farm_year_averages_to_normal_and_follows_the_hemisphere() -> void:
	var w := _world()
	var north := _cell_near(w, 45.0)
	var south := _cell_near(w, -45.0)
	for c in [north, south, Planet.landing(w), _cell_near(w, 5.0)]:
		var s := 0
		var h := 0
		for m in 12:
			s += PlanetSeasons.season_pct(w, c, m)
			h += PlanetSeasons.heating_pct(w, c, m)
		check(absi(s - 1200) <= 12, "the farm year averages 100 at hex %d (%d)" % [c, s])
		check(absi(h - 1200) <= 12, "heating averages 100 at hex %d (%d)" % [c, h])
	check(PlanetSeasons.season_pct(w, north, 6) > PlanetSeasons.season_pct(w, north, 0) * 2, "north: July grows, January rests")
	check(PlanetSeasons.season_pct(w, south, 0) > PlanetSeasons.season_pct(w, south, 6), "south: the other way round")
	check(PlanetSeasons.heating_pct(w, north, 0) > PlanetSeasons.heating_pct(w, north, 6), "heating is a winter need")
	check(PlanetSeasons.season_pct(w, north, 1) > 0, "a little all year (stores, winter crops)")
	var hm := PlanetSeasons.harvest_month(w, north)
	check(hm >= 8 and hm <= 11, "the northern harvest is reckoned in autumn (%d)" % hm)


func test_drought_costs_the_harvest() -> void:
	var w := _world()
	var l := Planet.landing(w)
	var seen := false
	for m in 600:
		var dm := int(PlanetClimate.weather(w, l, m)["drought_months"])
		var loss := PlanetSeasons.drought_loss(w, l, m)
		if dm < PlanetSeasons.DROUGHT_FROM:
			check_eq(loss, 0, "no loss before %d dry months" % PlanetSeasons.DROUGHT_FROM)
		else:
			seen = true
			check_eq(loss, mini(PlanetSeasons.DROUGHT_MAX, (dm - PlanetSeasons.DROUGHT_FROM + 1) * PlanetSeasons.DROUGHT_PER_MONTH), "loss grows with the drought")
			check(PlanetSeasons.farm_pct(w, l, m) < PlanetSeasons.season_pct(w, l, m) or PlanetSeasons.season_pct(w, l, m) == 0, "the drought cuts the farm month")
	check(seen, "fifty years bring a drought")


func test_flocks_are_pure_and_the_colony_has_birds() -> void:
	for sd in [1, 2, 3, 4, 5, 6]:
		var w := _world(sd)
		var fl := PlanetBirds.flocks(w)
		check_eq(var_to_str(fl), var_to_str(PlanetBirds.flocks(_world(sd))), "seed %d: pure in the seed" % sd)
		check(fl.size() >= 2 and fl.size() <= 3, "two or three flocks")
		var l := Planet.landing(w)
		check(l in fl[0]["breed"], "the first flock breeds at the colony")
		check(l in fl[1]["route"], "the second passes over it")
		var nb: Array = Planet.geometry(Planet.freq(w))["nbrs"]
		for f in fl:
			var route: Array = f["route"]
			for i in range(1, route.size()):
				check(int(route[i]) in Array(nb[int(route[i - 1])]), "the route is a chain of neighbours")
			var phases := {}
			for m in 12:
				phases[String(PlanetBirds.where(w, f, m)["phase"])] = true
			check(phases.has("BREEDING") and phases.has("WINTER"), "a year of breeding and wintering (%s)" % str(phases.keys()))
			check(phases.has("SOUTH") and phases.has("NORTH"), "and travelling both ways")


func test_birds_hold_down_pests_and_when_they_fail_pests_rise() -> void:
	var w := _world(4)
	var l := Planet.landing(w)
	w.levers[PlanetWildlife.POLICY_LEVER] = "PROTECT"
	for _m in 120:
		w.month += 1
		PlanetWildlife.step_month(w)
	var with_birds := int(PlanetWildlife.levels(w, l)["pest"])
	var w2 := _world(4)
	w2.levers[PlanetWildlife.POLICY_LEVER] = "PROTECT"
	var gone := {}
	for f in PlanetBirds.flocks(w2):
		gone[String(f["id"])] = [0, 0, 1]
	for _m in 120:
		w2.month += 1
		w2.table("planet")["birds"] = gone.duplicate(true)
		PlanetWildlife.step_month(w2)
	var without := int(PlanetWildlife.levels(w2, l)["pest"])
	check(absi(with_birds - 1000) <= 20, "with its birds the colony's land is in balance (%d‰)" % with_birds)
	check(without > 1150, "without them the pests rise (%d‰)" % without)
	check(PlanetWildlife.yield_loss(w2, l) > PlanetWildlife.yield_loss(w, l), "and farms lose more")
	# through the year: insects dormant in winter, thinner while the birds stay
	var lat := Planet.lat_lon(l).x
	var summer := 6 if lat >= 0.0 else 0
	var winter := 0 if lat >= 0.0 else 6
	check(int(PlanetWildlife.levels_now(w, l, summer)["pol"]) > int(PlanetWildlife.levels_now(w, l, winter)["pol"]), "pollinators fly in summer, rest in winter")


func test_harm_along_the_route_brings_fewer_birds_and_the_news_says_so() -> void:
	var w := _world(4)
	var f: Dictionary = PlanetBirds.flocks(w)[1]   # the flock that passes over the colony
	var eco := {}
	var route: Array = f["route"]
	for c in route.slice(route.size() / 2, route.size()) + f["winter"]:
		if not Planet.is_water(w, int(c)):
			eco[str(int(c))] = [0, 900]
	var events: Array = []
	for _m in 60:
		w.month += 1
		w.table("planet")["eco"] = eco.duplicate(true)
		events += PlanetBirds.step_month(w)
	var sz := PlanetBirds.size(w, String(f["id"]))
	check(sz < 600, "a poisoned route: fewer birds come back (%d‰)" % sz)
	var failed := false
	for e in events:
		if String(e["kind"]) == "FAILED" and String(e["flock"]["id"]) == String(f["id"]):
			failed = true
	check(failed, "\"the birds didn't come\"")
	var wh := PlanetBirds.worst_hex(w, f)
	check(int(wh["harm"]) == 900 and eco.has(str(int(wh["cell"]))), "the worst hex on the route is named")
	# a healthy world's flocks arrive and stay near natural
	var w2 := _world(4)
	var arrived := 0
	for _m in 60:
		w2.month += 1
		for e in PlanetBirds.step_month(w2):
			arrived += 1 if String(e["kind"]) == "ARRIVED" else 0
	check(arrived >= 5, "the colony's flocks arrive every year (%d)" % arrived)
	for fl in PlanetBirds.flocks(w2):
		check(absi(PlanetBirds.size(w2, String(fl["id"])) - 1000) < 250, "a healthy flock stays near natural")


func test_in_the_game_seasons_deterministic_and_save_load() -> void:
	var a := EconSim.make(3, "BALANCED", {}, true)
	var b := EconSim.make(3, "BALANCED", {}, true)
	for s in [a, b]:
		(s.world.meta["on"] as Array).append_array(["ECO", "SEASONS"])
	for _m in 16:
		a.step()
		b.step()
	check_eq(var_to_str(a.world.peek("planet").get("birds", {})), var_to_str(b.world.peek("planet").get("birds", {})), "deterministic")
	check(not a.world.facts.query("PLANET_BIRDS_", 0, 1 << 30).is_empty(), "the birds make the news")
	check(not a.world.facts.query("PLANET_HARVEST", 0, 1 << 30).is_empty(), "a harvest is reckoned")
	var path := "user://test_seasons.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := EconSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var plain := EconSim.make(3, "BALANCED", {}, true)
	for _m in 3:
		plain.step()
	check(not plain.world.peek("planet").has("birds"), "ECO off: no birds stored")
