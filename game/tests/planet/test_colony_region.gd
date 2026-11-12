extends TestCase
## Terra (2026-11-12, Wilma: "make the flat colony map fit the globe"): the 64×40 colony map is the landing region of
## the globe (Terrain.derive), with globe rivers and deposits (Planet.downstream / river_flow / deposit).


func _world(seed_v: int) -> WorldState:
	var w := WorldState.new(seed_v)
	Planet.generate(w)
	Terrain.generate(w)
	return w


func _worlds() -> Array:
	var out: Array = []
	for s in [1, 2, 7]:
		out.append(_world(s))
	for k in 3:
		out.append(ExpeditionWorlds.world(2, k))
	return out


## Map tiles on the side of a neighbour: the outer quarter of the map in that direction.
func _side_tiles(w: WorldState, j: int) -> Array:
	var fr := Planet.colony_frame(w)
	var cj: Vector3 = Planet.geometry(Planet.freq(w))["centers"][j]
	var d := Vector2(cj.dot(fr["east"]), cj.dot(fr["north"])).normalized()
	var reach := minf(float(fr["hw"]) / maxf(absf(d.x), 1e-6), float(fr["hh"]) / maxf(absf(d.y), 1e-6))
	var out: Array = []
	for y in Terrain.H:
		for x in Terrain.W:
			var q := Vector2(((x + 0.5) / Terrain.W - 0.5) * 2.0 * float(fr["hw"]), (0.5 - (y + 0.5) / Terrain.H) * 2.0 * float(fr["hh"]))
			if q.dot(d) / reach >= 0.75:
				out.append(Vector2i(x, y))
	return out


func test_water_runs_to_the_sea_and_rivers_are_pure() -> void:
	var w := _world(1)
	var h := w.state_hash()
	var rivers := 0
	for i in Planet.cell_count(w):
		if Planet.is_water(w, i):
			check_eq(Planet.downstream(w, i), -1, "sea cells drain nowhere")
			continue
		var c := i
		var steps := 0
		while c >= 0 and not Planet.is_water(w, c) and steps < 5000:
			c = Planet.downstream(w, c)
			steps += 1
		if c < 0 or not Planet.is_water(w, c):
			check(false, "cell %d never reaches the sea" % i)
			return
		rivers += 1 if Planet.is_river(w, i) else 0
		var dep := Planet.deposit(w, i)
		check(dep == "" or Planet.level(w, i) >= 2, "deposits lie in hills and mountains")
	check(rivers > 100 and rivers < Planet.cell_count(w) / 5, "rivers, not everywhere (%d)" % rivers)
	for j in Planet.neighbors(w, 100):
		check(Planet.downstream(w, j) != 100 or Planet.inflows(w, 100).any(func(p): return int(p[0]) == j), "inflows list who runs in")
	check_eq(w.state_hash(), h, "the planet's rivers and deposits are pure (no stream advanced, nothing stored)")
	check_eq(Planet.deposit(w, 500), Planet.deposit(_world(1), 500), "deposits are the same every time")


func test_the_map_is_the_landing_region() -> void:
	for w in _worlds():
		var li := Planet.landing(w)
		var sea_n := 0
		var label := "seed %d" % Planet.seed_of(w)
		for j in Planet.neighbors(w, li):
			var side := _side_tiles(w, j)
			var sea := side.filter(func(t): return Terrain.at(w, t.x, t.y) == Terrain.SEA).size()
			if Planet.is_water(w, j):
				sea_n += 1
				check(sea * 4 >= side.size(), "%s: a sea neighbour puts a coast on its side (%d of %d)" % [label, sea, side.size()])
			else:
				check(sea * 4 < side.size(), "%s: land on a land neighbour's side (%d of %d sea)" % [label, sea, side.size()])
			if Planet.height(w, j) >= Planet.height(w, li) + 20 and not Planet.is_water(w, j):
				var high := side.filter(func(t): return Terrain.at(w, t.x, t.y) in ["h", "k", "o", "x"]).size()
				check(high * 5 >= side.size(), "%s: a mountain neighbour raises its side (%d of %d)" % [label, high, side.size()])
		var all_sea := 0
		for y in Terrain.H:
			all_sea += String(w.peek("map")["grid"]["rows"][y]).count(Terrain.SEA)
		if sea_n == 0:
			check_eq(all_sea, 0, "%s: no sea neighbour, no sea" % label)
		# the river leaves where the globe's water goes: into the sea when that is the sea
		var mo: Array = w.peek("map")["grid"]["mouth"]
		var mouth := Vector2i(int(mo[0]), int(mo[1]))
		check_eq(Terrain.at(w, mouth.x, mouth.y), "r", "%s: the mouth is river" % label)
		if Planet.is_water(w, Planet.downstream(w, li)):
			var by_sea := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				by_sea = by_sea or Terrain.at(w, mouth.x + d.x, mouth.y + d.y) == Terrain.SEA
			check(by_sea, "%s: the river runs into the sea" % label)
		# the colony stands on land, and nothing is placed in the sea
		var l := Terrain.landing(w)
		check_eq(Terrain.at(w, l.x, l.y), "L", "%s: a landing site" % label)
		for s in ColonyLayout.settlements(w):
			for t in s["tiles"]:
				check(Terrain.at(w, t.x, t.y) != Terrain.SEA, "%s: %s does not spread into the sea" % [label, s["id"]])
		var counts := {}
		for row in w.peek("map")["grid"]["rows"]:
			for ch in String(row):
				counts[ch] = int(counts.get(ch, 0)) + 1
		check(int(counts.get("o", 0)) >= 4 and int(counts.get("x", 0)) >= 1, "%s: deposits to mine (%s)" % [label, str(counts)])
		check(int(counts.get("r", 0)) >= 40, "%s: a river crosses the map" % label)
		check(int(counts.get(".", 0)) + int(counts.get("f", 0)) >= 800, "%s: room to build" % label)


func test_derive_is_pure_and_deterministic() -> void:
	var w := _world(7)
	var h := w.state_hash()
	var a := Terrain.derive(w)
	check_eq(var_to_str(a), var_to_str(Terrain.derive(w)), "the same map every time")
	check_eq(var_to_str(a["rows"]), var_to_str(w.peek("map")["grid"]["rows"]), "the stored map is the derived one")
	check_eq(w.state_hash(), h, "deriving reads only the planet")


func test_sea_blocks_roads_and_old_maps_still_flow() -> void:
	var w := _world(1)
	var sea := Vector2i(-1, -1)
	for y in Terrain.H:
		for x in Terrain.W:
			if sea.x < 0 and Terrain.at(w, x, y) == Terrain.SEA:
				sea = Vector2i(x, y)
	check(sea.x >= 0, "seed 1 lands on the coast")
	var l := Terrain.landing(w)
	check(Transport.plan_path(w, l, sea).is_empty(), "no road into the sea")
	check(Transport.validate_link(w, {"a": Transport.tile_int(l), "b": Transport.tile_int(sea), "kind": "TRACK"}) != "", "a readable refusal")
	var p := Transport.plan_path(w, Vector2i(0, 0), Vector2i(Terrain.W - 1, Terrain.H - 1))
	check(p.filter(func(ti): return Terrain.at(w, int(ti) % Terrain.W, int(ti) / Terrain.W) == Terrain.SEA).is_empty(), "paths go round the sea")
	# an old save's map (no stored mouth): the river still flows to one mouth
	var old := _world(2)
	old.table("map")["grid"].erase("mouth")
	var f := WasteMap.flow(old)
	var n := 0
	for row in old.peek("map")["grid"]["rows"]:
		n += String(row).count("r")
	check_eq(f["order"].size(), n, "every river tile of an old map flows")
