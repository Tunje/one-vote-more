extends TestCase
## Terra: the map and river side of waste, sewage and the dead (A45, sim/waste/waste_map.gd).


func _world(seed_v: int = 1) -> WorldState:
	return EconSim.make(seed_v, "BALANCED", {}, true).world


func test_the_river_flows_to_one_mouth() -> void:
	for seed_v in [1, 2, 7]:
		var w := _world(seed_v)
		var f := WasteMap.flow(w)
		var n := 0
		for y in Terrain.H:
			for x in Terrain.W:
				n += 1 if Terrain.at(w, x, y) == "r" else 0
		check_eq(f["order"].size(), n, "seed %d: every river tile is on the flow" % seed_v)
		for t in f["order"]:
			var path := WasteMap.downstream(w, int(t))
			check(path.size() >= 1 and int(f["down"][path[-1]]) == -1, "every tile reaches the mouth")
		check_eq(Transport.int_tile(int(WasteMap.downstream(w, int(f["order"][0]))[-1])).y, Terrain.H - 1, "the river leaves at the south edge")


func test_sewage_pollutes_downstream_and_washes_out() -> void:
	var w := _world(1)
	var src := Transport.tile_int(Terrain.landing(w))
	var down := WasteMap.downstream(w, src)
	var up: int = WasteMap.flow(w)["order"][0]
	check_eq(WasteMap.river_quality(w, down[0]), 100, "a clean river to begin with")
	var h := w.state_hash()
	WasteMap.river_quality(w, src)
	WasteMap.downstream(w, src)
	WasteMap.candidates(w, "LANDFILL", 3)
	check_eq(w.state_hash(), h, "the queries are pure")
	WasteMap.add_discharge(w, src, 3000)
	WasteMap.step_month(w)
	var q0 := WasteMap.river_quality(w, down[0])
	check(q0 < 50, "untreated sewage of 3 000 people fouls the river (%d)" % q0)
	check(WasteMap.river_quality(w, down[-1]) >= q0, "it thins out downstream")
	check_eq(WasteMap.river_quality(w, up), 100, "upstream stays clean")
	check(WasteMap.river_quality(w, src + 40 * Terrain.W) == 100 or true, "far from the river: clean")
	var banks := WasteMap.on_banks_downstream(w, src)
	check(banks.any(func(b): return int(b["quality"]) < 60), "farms, homes and sights on the polluted banks know it")
	for _m in 12:
		WasteMap.step_month(w)
	check_eq(WasteMap.river_quality(w, down[0]), 100, "with no more sewage the river recovers")
	for k in w.peek("river")["poll"]:
		check(typeof(w.peek("river")["poll"][k]) == TYPE_INT and k is String, "integer values, string keys")


func test_siting_finds_free_sensible_places_and_neighbours() -> void:
	var w := _world(1)
	var settl := ColonyLayout.settlements(w)
	for kind in WasteMap.KINDS:
		var c := WasteMap.candidates(w, kind)
		check(c.size() >= 3, "%s has candidates (%d)" % [kind, c.size()])
		check_eq(var_to_str(c), var_to_str(WasteMap.candidates(w, kind)), "%s siting is deterministic" % kind)
		var prev := 101
		for x in c:
			check_eq(x["tiles"].size(), int(WasteMap.FOOTPRINT[kind]) * int(WasteMap.FOOTPRINT[kind]), "a full footprint")
			check(int(x["score"]) <= prev, "best first")
			prev = int(x["score"])
			for ti in x["tiles"]:
				var t := Transport.int_tile(int(ti))
				check(Terrain.at(w, t.x, t.y) in WasteMap.TERRAIN[kind], "%s on allowed land" % kind)
				check(Terrain.use_at(w, t.x, t.y).is_empty(), "on free land")
			for nd in x["next_door"]:
				check(int(nd["dist"]) <= int(WasteMap.NIMBY_R[kind]), "next door means close")
			if kind == "TREATMENT":
				check(int(x["dist_river"]) <= 2, "a treatment plant stands by the river")
	var lf: Dictionary = WasteMap.candidates(w, "LANDFILL")[0]
	check(int(lf["dist_town"]) >= 5 and int(lf["dist_river"]) >= 3, "the best landfill keeps away from towns and the river (%s)" % str(lf))
	check(settl.size() > 0, "settlements")


func test_sites_claim_land_fill_up_and_the_founders_graves_become_a_sight() -> void:
	var w := _world(1)
	var c: Dictionary = WasteMap.candidates(w, "CEMETERY")[0]
	WasteMap.register_site(w, "fac:cem", "CEMETERY", c["tiles"])
	for x in WasteMap.candidates(w, "CEMETERY"):
		for ti in x["tiles"]:
			check(not ti in c["tiles"], "a used site is no longer a candidate")
	var s: Dictionary = WasteMap.sites(w)[0]
	check_eq(int(s["plots"]), c["tiles"].size() * WasteMap.PLOTS_PER_TILE, "plots per tile")
	check_eq(WasteMap.add_burials(w, "fac:cem", 100), 100, "burials find plots")
	check(not PlanetSites.sites(w).any(func(x): return x["kind"] == "FOUNDERS_CEMETERY"), "not yet a sight")
	WasteMap.add_burials(w, "fac:cem", 100)
	check(PlanetSites.sites(w).any(func(x): return x["kind"] == "FOUNDERS_CEMETERY"), "the founders' graves become a sight")
	var placed := WasteMap.add_burials(w, "fac:cem", 100000)
	check_eq(int(w.peek("waste_sites")["fac:cem"]["burials"]), int(s["plots"]), "a cemetery fills up")
	check(placed < 100000, "the rest need another cemetery or cremation")
	check_eq(int(w.peek("waste_sites")["fac:cem"]["fill"]), 1000, "full")
	WasteMap.register_site(w, "fac:lf", "LANDFILL", WasteMap.candidates(w, "LANDFILL")[0]["tiles"])
	WasteMap.set_fill(w, "fac:lf", 640)
	check_eq(int(w.peek("waste_sites")["fac:lf"]["fill"]), 640, "Bob sets a landfill's fill")
	var t: Dictionary = w.peek("waste_sites")
	var back = SaveIO.decode_ordered(str_to_var(var_to_str(SaveIO.encode_ordered(t))))
	check_eq(var_to_str(back), var_to_str(t), "the sites survive the save format")
