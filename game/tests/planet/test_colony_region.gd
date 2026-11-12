extends TestCase
## Terra (2026-11-12, Wilma: "make the flat colony map fit the globe", then "the tall map"): the colony map holds the
## whole landing hex and shows the neighbours in its corners (Terrain.derive), with globe rivers and deposits (Planet.downstream / river_flow / deposit).


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
		var label := "seed %d" % Planet.seed_of(w)
		var hexes := Planet.tile_hexes(w)
		var rows: Array = w.peek("map")["grid"]["rows"]
		var agree := 0
		var in_hex := 0
		var high := {}
		var tiles := {}
		for y in Terrain.H:
			for x in Terrain.W:
				var c: int = hexes[y * Terrain.W + x]
				var code := String(rows[y]).substr(x, 1)
				agree += 1 if (code == Terrain.SEA) == Planet.is_water(w, c) else 0
				in_hex += 1 if c == li else 0
				tiles[c] = int(tiles.get(c, 0)) + 1
				high[c] = int(high.get(c, 0)) + (1 if code in ["h", "k", "o", "x"] else 0)
		check(agree * 100 >= Terrain.W * Terrain.H * 93, "%s: the map's sea is the globe's sea (%d of %d agree)" % [label, agree, Terrain.W * Terrain.H])
		check(in_hex * 100 >= Terrain.W * Terrain.H * 45, "%s: the landing hex fills the middle of the map (%d)" % [label, in_hex])
		for j in Planet.neighbors(w, li):
			check(tiles.has(j), "%s: every neighbour shows in a corner of the map" % label)
			if Planet.height(w, j) >= Planet.height(w, li) + 20 and int(tiles.get(j, 0)) >= 100:
				check(int(high[j]) * 100 / int(tiles[j]) > int(high.get(li, 0)) * 100 / in_hex, "%s: a higher neighbour is hillier" % label)
		# the river leaves where the globe's water goes, once: one mouth, no forks
		var mo: Array = w.peek("map")["grid"]["mouth"]
		var mouth := Vector2i(int(mo[0]), int(mo[1]))
		check_eq(Terrain.at(w, mouth.x, mouth.y), "r", "%s: the mouth is river" % label)
		var f := WasteMap.flow(w)
		check_eq(f["down"].values().filter(func(v): return int(v) == -1).size(), 1, "%s: one mouth" % label)
		if Planet.is_water(w, Planet.downstream(w, li)):
			var by_sea := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				by_sea = by_sea or Terrain.at(w, mouth.x + d.x, mouth.y + d.y) == Terrain.SEA
			check(by_sea, "%s: the river runs into the sea" % label)
		var edge_r := 0
		for x in Terrain.W:
			for y in [0, Terrain.H - 1]:
				edge_r += 1 if Terrain.at(w, x, y) == "r" and Vector2i(x, y) != mouth else 0
		for y in Terrain.H:
			for x in [0, Terrain.W - 1]:
				edge_r += 1 if Terrain.at(w, x, y) == "r" and Vector2i(x, y) != mouth else 0
		check(edge_r <= 2 * mini(2, Planet.inflows(w, li).size()) + 1, "%s: rivers come in over the edge only from a globe inflow (%d)" % [label, edge_r])
		# the colony stands on land in its own hex, and nothing is placed in the sea
		var l := Terrain.landing(w)
		check_eq(Terrain.at(w, l.x, l.y), "L", "%s: a landing site" % label)
		check_eq(Planet.hex_of_tile(w, l), li, "%s: the landing site lies in the landing hex" % label)
		for s in ColonyLayout.settlements(w):
			for t in s["tiles"]:
				check(Terrain.at(w, t.x, t.y) != Terrain.SEA, "%s: %s does not spread into the sea" % [label, s["id"]])
		var counts := {}
		for row in rows:
			for ch in String(row):
				counts[ch] = int(counts.get(ch, 0)) + 1
		check(int(counts.get("o", 0)) >= 5 and int(counts.get("x", 0)) >= 2, "%s: deposits to mine (%s)" % [label, str(counts)])
		check(int(counts.get("r", 0)) >= 40, "%s: a river crosses the map" % label)
		check(int(counts.get(".", 0)) + int(counts.get("f", 0)) >= 2500, "%s: room to build" % label)


func test_derive_is_pure_and_deterministic() -> void:
	var w := _world(7)
	var h := w.state_hash()
	var a := Terrain.derive(w)
	check_eq(var_to_str(a), var_to_str(Terrain.derive(w)), "the same map every time")
	check_eq(var_to_str(a["rows"]), var_to_str(w.peek("map")["grid"]["rows"]), "the stored map is the derived one")
	check_eq(w.state_hash(), h, "deriving reads only the planet")


func test_sea_blocks_roads() -> void:
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
