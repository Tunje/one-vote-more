extends TestCase
## Terra: the planet's ecology (sim/planet/planet_ecology.gd, opt-in ECO): pollution released, spread and absorbed,
## harm and recovery, a character per seed, rougher weather and yields over harmed land.


func _world(seed_v: int = 4, eco: bool = true) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	w.meta["on"] = ["ECO"] if eco else []
	w.table("econ")["s"] = {"emissions": {}}
	return w


func _emit(w: WorldState, units: int) -> void:
	CoreUtil.st(w)["emissions"] = {"d:1": units * 1000}


func _months(w: WorldState, n: int) -> void:
	for _m in n:
		w.month += 1
		PlanetEcology.step_month(w, [], [])


## A land hex with land neighbours all round and a river leaving it, near the landing site if possible.
func _inland(w: WorldState) -> int:
	var li := Planet.landing(w)
	var best := -1
	var bd := INF
	var cs: PackedVector3Array = Planet.geometry(Planet.freq(w))["centers"]
	for i in Planet.cell_count(w):
		if Planet.is_water(w, i) or Planet.downstream(w, i) < 0:
			continue
		var dry := true
		for j in Planet.neighbors(w, i):
			dry = dry and not Planet.is_water(w, j)
		if dry and cs[i].distance_to(cs[li]) < bd:
			bd = cs[i].distance_to(cs[li])
			best = i
	return best


func test_every_seed_has_its_own_character() -> void:
	var seen := {}
	var vit_differs := false
	for sd in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		var a := _world(sd)
		var b := _world(sd)
		var ch := PlanetEcology.character(a)
		check_eq(ch, PlanetEcology.character(b), "seed %d: the character is pure in the seed" % sd)
		check(float(ch["resilience"]) >= 0.5 and float(ch["resilience"]) <= 2.0, "resilience in 0.5..2")
		check(float(ch["sensitivity"]) >= 0.5 and float(ch["sensitivity"]) <= 2.0, "sensitivity in 0.5..2")
		seen[ch["trait"]] = true
		var l := Planet.landing(a)
		check(PlanetEcology.vitality(a, l) > 0, "seed %d: the landing hex has life" % sd)
		vit_differs = vit_differs or PlanetEcology.vitality(a, l) != PlanetEcology.vitality(_world(sd % 12 + 1), Planet.landing(_world(sd % 12 + 1)))
	check(seen.size() >= 3, "twelve seeds show several traits (%s)" % str(seen.keys()))
	check(vit_differs, "the land's richness differs between worlds")
	var w := _world(1)
	for i in [0, 500, 4000, 9000]:
		if Planet.is_water(w, i):
			check_eq(PlanetEcology.vitality(w, i), 0, "no living layer at sea")


func test_pollution_is_released_spreads_downwind_and_down_the_river() -> void:
	var w := _world(4)
	var c := _inland(w)
	check(c >= 0, "an inland hex with a river")
	w.table("planet")["eco"] = {str(c): [400000, 0]}
	_months(w, 1)
	var cs: PackedVector3Array = Planet.geometry(Planet.freq(w))["centers"]
	var wind := PlanetClimate.wind(cs[c])
	var down_wind := -1
	var up_wind := -1
	var bd := -INF
	var bu := INF
	for j in Planet.neighbors(w, c):
		var d := (cs[j] - cs[c]).normalized().dot(wind)
		if d > bd:
			bd = d
			down_wind = j
		if d < bu:
			bu = d
			up_wind = j
	check(PlanetEcology.pollution(w, c) < 400.0 and PlanetEcology.pollution(w, c) > 250.0, "most of the load stays (%.1f)" % PlanetEcology.pollution(w, c))
	check(PlanetEcology.pollution(w, down_wind) > PlanetEcology.pollution(w, up_wind) * 2.0, "downwind gets more than upwind")
	check(PlanetEcology.pollution(w, up_wind) > 0.0, "a little spreads to every neighbour")
	var down := Planet.downstream(w, c)
	if down != down_wind:
		check(PlanetEcology.pollution(w, down) > PlanetEcology.pollution(w, up_wind), "the river carries some downstream")
	# released at the district's hex: with no terrain, the landing hex
	var w2 := _world(4)
	_emit(w2, 30)
	_months(w2, 1)
	check(PlanetEcology.pollution(w2, Planet.landing(w2)) > 20.0, "emissions enter at the landing hex")
	# conservation: nothing appears from nowhere; total falls by about the decay share
	var total := 0
	for k in w.peek("planet")["eco"]:
		total += int(w.peek("planet")["eco"][k][0])
	check(total <= 400000 and total > 400000 * 9 / 10, "the load is moved, only a little breaks down (%d)" % total)
	for k in w.peek("planet")["eco"]:
		for v in w.peek("planet")["eco"][k]:
			check_eq(typeof(v), TYPE_INT, "integer state")


func test_heavy_pollution_harms_the_land_and_it_heals_slowly() -> void:
	var w := _world(4)
	var l := Planet.landing(w)
	_emit(w, 400)
	var at5 := 0
	for m in 240:
		_months(w, 1)
		if m == 59:
			at5 = PlanetEcology.harm(w, l)
	var at20 := PlanetEcology.harm(w, l)
	check(at5 > 100, "five years of heavy industry harm the land (%d‰)" % at5)
	check(at20 >= at5 and at20 < 1000, "harm keeps toward its level, below total (%d‰)" % at20)
	check(PlanetEcology.yield_pct(w, l) < 100 and PlanetEcology.yield_pct(w, l) >= 100 - 2 * PlanetEcology.YIELD_LOSS, "yields fall (%d%%)" % PlanetEcology.yield_pct(w, l))
	check(PlanetEcology.rough(w, l) > 1.0, "weather swings wider over harmed land")
	_emit(w, 0)
	_months(w, 60)
	var after5 := PlanetEcology.harm(w, l)
	check(after5 < at20, "harm falls once the factories stop (%d -> %d)" % [at20, after5])
	check(after5 > at20 / 5, "but healing is slow (%d‰ after 5 years)" % after5)
	_months(w, 600)
	check(not w.peek("planet")["eco"].has(str(l)) or PlanetEcology.harm(w, l) < 50, "after decades the land has healed (%d‰)" % PlanetEcology.harm(w, l))
	# a light colony stays under what the land absorbs
	var w2 := _world(4)
	_emit(w2, 20)
	_months(w2, 240)
	check_eq(PlanetEcology.harm(w2, Planet.landing(w2)), 0, "a light colony does no harm")


func test_harmed_land_has_rougher_weather_and_raises_dust() -> void:
	var w := _world(4)
	var l := Planet.landing(w)
	var calm: Array = []
	for m in 120:
		calm.append(int(PlanetClimate.weather(w, l, m)["rain_pct"]))
	w.table("planet")["eco"] = {str(l): [900000, 900]}
	var wider := 0
	for m in 120:
		var rp := int(PlanetClimate.weather(w, l, m)["rain_pct"])
		if absi(rp - 100) > absi(int(calm[m]) - 100):
			wider += 1
		check((rp - 100) * (int(calm[m]) - 100) >= 0, "same direction, only wider (month %d)" % m)
	check(wider > 60, "most months swing further from normal (%d/120)" % wider)
	var dust := 0
	for m in 120:
		w.month = m
		w.table("planet")["eco"] = {str(l): [900000, 900]}
		var storms: Array = []
		PlanetEcology.step_month(w, storms, [])
		for s in storms:
			if s["kind"] == "DUST" and s.get("eco", false):
				dust += 1
				check(int(s["cells"][0]) == l, "the dust rises from the harmed hex")
	check(dust >= 3, "harmed land raises dust storms (%d in 10 years)" % dust)
	# ECO off: weather and yields as before, nothing stored
	var off := _world(4, false)
	off.table("planet")["eco"] = {str(l): [900000, 900]}
	for m in 24:
		check_eq(int(PlanetClimate.weather(off, l, m)["rain_pct"]), int(calm[m]), "ECO off: the weather is untouched")
	check_eq(PlanetEcology.yield_pct(off, l), 100, "ECO off: full yields")


func test_in_the_game_off_by_default_deterministic_and_save_load() -> void:
	var plain := EconFace.sim_make(2, "BALANCED", {}, true)
	for _m in 3:
		plain.step()
	check(not plain.world.peek("planet").has("eco"), "ECO is off by default: nothing stored")
	var a := EconFace.sim_make(2, "BALANCED", {}, true)
	var b := EconFace.sim_make(2, "BALANCED", {}, true)
	for s in [a, b]:
		(s.world.meta["on"] as Array).append("ECO")
	for _m in 14:
		a.step()
		b.step()
	check_eq(var_to_str(a.world.peek("planet").get("eco", {})), var_to_str(b.world.peek("planet").get("eco", {})), "deterministic")
	check(not a.world.peek("planet").get("eco", {}).is_empty(), "the colony's emissions reach the planet")
	check(a.world.indicators.written_this_month("PLANET_ECO_HARM") or a.world.indicators.read("PLANET_ECO_HARM") >= 0, "the harm indicator is defined")
	var path := "user://test_ecology.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := EconFace.sim_for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	check_eq(var_to_str(c.world.peek("planet").get("eco", {})), var_to_str(a.world.peek("planet")["eco"]), "the ecology survives save/load")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_damage_facts_near_the_colony() -> void:
	var w := _world(4)
	var l := Planet.landing(w)
	w.table("planet")["uses"] = {str(l): {"kind": "COLONY"}}
	var p := PlanetProvider.new()
	p._report_eco(w, [{"cell": l, "old": 250, "new": 320, "level": 300}])
	p._report_eco(w, [{"cell": l, "old": 320, "new": 280, "level": 300}])
	var far := -1
	for i in Planet.cell_count(w):
		if Planet.lat_lon(i).distance_to(Planet.lat_lon(l)) > 60.0:
			far = i
			break
	p._report_eco(w, [{"cell": far, "old": 250, "new": 320, "level": 300}])
	var dmg: Array = w.facts.query("PLANET_ECO_DAMAGE", 0, 10)
	var rec: Array = w.facts.query("PLANET_ECO_RECOVERY", 0, 10)
	check_eq(dmg.size(), 1, "one damage fact (the far hex is not reported)")
	check_eq(rec.size(), 1, "one recovery fact")
	if dmg.size() == 1:
		check_eq(int(dmg[0]["data"]["level"]), 300, "the level crossed")
		check(bool(dmg[0]["data"]["colony"]), "it is the colony's own hex")
