extends TestCase
## Terra (A47 §X2): the expedition's candidate worlds (sim/planet/expedition_worlds.gd).


func _game_on(seed_v: int, k: int) -> Simulation:   # what Wilma's expedition flow does: choose, then set up the game
	var sim := Simulation.new(seed_v)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["voters"] = "LEAVES"
	ExpeditionWorlds.choose(sim.world, k)
	EconSim._register(sim)
	sim.new_game()
	return sim


func test_candidates_are_several_distinct_and_deterministic() -> void:
	for seed_v in [1, 2, 7]:
		var cs := ExpeditionWorlds.candidates(seed_v)
		check(cs.size() >= 3 and cs.size() <= 5, "3–5 worlds (%d)" % cs.size())
		var lands := {}
		var arch := {}
		for c in cs:
			var w := ExpeditionWorlds.world(seed_v, int(c["index"]))
			lands[str(c["landing"]["lat"]) + String(c["landing"]["biome"])] = true
			arch[String(w.peek("planet")["arch"])] = true
			check(int(c["ship_months"][0]) < int(c["ship_months"][1]), "a ship-interval range")
			check(int(c["cost_index"]) > 0 and int(c["harshness"]) >= 0 and int(c["harshness"]) <= 100, "cost and harshness")
			check(c["summary"].size() >= 4, "a summary card")
			for f in c["survey"]:
				var fact: Dictionary = c["survey"][f]
				check(int(fact["lo"]) <= int(fact["value"]) and int(fact["value"]) <= int(fact["hi"]), "%s: the truth lies in the estimate (%s)" % [f, str(fact)])
				if fact["certainty"] == "SURVEYED":
					check(int(fact["lo"]) == int(fact["hi"]), "%s: surveyed facts are exact" % f)
		check_eq(arch.size(), cs.size(), "seed %d: every world has its own climate" % seed_v)
		check_eq(lands.size(), cs.size(), "seed %d: different landing sites" % seed_v)
		check_eq(var_to_str(ExpeditionWorlds.card(seed_v, 0)), var_to_str(cs[0]), "the card is deterministic")


func test_the_chosen_world_is_the_game_world() -> void:
	var seed_v := 2
	var k := 1
	var preview := ExpeditionWorlds.world(seed_v, k)
	var sim := _game_on(seed_v, k)
	var w := sim.world
	check_eq(Planet.seed_of(w), Planet.seed_of(preview), "the planet seed of the choice")
	check_eq(Planet.landing(w), Planet.landing(preview), "the same landing hex")
	check_eq(var_to_str(w.peek("map")["grid"]["rows"]), var_to_str(preview.peek("map")["grid"]["rows"]), "the same colony grid")
	check(Planet.seed_of(w) != Planet.seed_of(EconSim.make(seed_v, "BALANCED", {}, true).world), "a different world than the default game")
	for _m in 3:
		sim.step()
	var path := "user://test_expedition.sav"
	check_eq(SaveIO.save(sim, path), OK, "saved")
	var b := EconSim.for_load()
	check_eq(SaveIO.load_into(b, path), OK, "loaded")
	check_eq(Planet.landing(b.world), Planet.landing(w), "the chosen world survives save/load")
	sim.step()
	b.step()
	check_eq(b.world.state_hash(), sim.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_default_game_keeps_its_planet() -> void:
	var w := EconSim.make(5, "BALANCED", {}, true).world
	check(not w.peek("planet").has("seed") and not w.peek("planet").has("arch"), "no expedition: the planet table is unchanged")
	check_eq(Planet.seed_of(w), w.rng.derive_seed("planet.terrain"), "the old planet seed")


func test_the_picker_shows_cards_and_chooses() -> void:
	var p := ExpeditionPicker.new()
	p.setup(2)
	check_eq(p._list.get_child_count(), ExpeditionWorlds.candidates(2).size(), "one button per world")
	var t := ExpeditionPicker.card_text(ExpeditionWorlds.candidates(2)[1])
	check(t.contains("Landing") and t.contains("est."), "the card shows the landing and the estimates")
	var got := [-1]
	p.chosen.connect(func(k: int): got[0] = k)
	p.select(2)
	p.chosen.emit(p.selected)
	check_eq(got[0], 2, "choosing reports the world")
	p.free()
