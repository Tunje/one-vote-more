class_name WasteMap
extends RefCounted
## Terra (A45, planning/spec-waste-v1.md): the map and river side of waste, sewage and the dead.
## - Siting (pure): candidate footprints for LANDFILL, INCINERATOR, RECYCLING, TREATMENT, CEMETERY, CREMATORIUM by
##   terrain, distance to settlements and the river, road access, land cost and competing use, with the areas
##   "next door" (NIMBY politics).
## - Sites (state): footprints claimed on the map when Bob builds them, fill (landfills: Bob sets it; cemeteries:
##   plots per tile, filled by burials). The founders' cemetery becomes a sight once it holds enough graves.
## - The river (state): untreated sewage and leachate enter at a tile (Bob: add_discharge), are carried downstream
##   along the river and decay with distance and time. Queries: river_quality, downstream.
##
## World tables (integers and strings only):
##   "waste_sites": {fid: {id, kind, tiles: [tile ints], built, fill (‰, landfill), burials (cemetery)}}
##   "river": {"load": {"<tile>": load this month (units)}, "poll": {"<tile>": pollution (units)}}
## Units: 1 000 load units ≈ the untreated sewage of 1 000 people for a month. Tile = y*64+x (Transport.tile_int).

const LQ := preload("res://sim/law/law_query.gd")
const KINDS := ["LANDFILL", "INCINERATOR", "RECYCLING", "TREATMENT", "CEMETERY", "CREMATORIUM"]
const KIND_NAMES := {"LANDFILL": "landfill", "INCINERATOR": "incinerator", "RECYCLING": "recycling works",
	"TREATMENT": "sewage treatment plant", "CEMETERY": "cemetery", "CREMATORIUM": "crematorium"}
const FOOTPRINT := {"LANDFILL": 3, "INCINERATOR": 1, "RECYCLING": 1, "TREATMENT": 1, "CEMETERY": 2, "CREMATORIUM": 1}
const TERRAIN := {"LANDFILL": [".", "h", "k"], "INCINERATOR": [".", "h"], "RECYCLING": [".", "h"], "TREATMENT": [".", "f", "h"],
	"CEMETERY": [".", "f", "n", "h"], "CREMATORIUM": [".", "h"]}
## Tiles around a site where people object (NIMBY): their areas are "next door".
const NIMBY_R := {"LANDFILL": 6, "INCINERATOR": 6, "RECYCLING": 3, "TREATMENT": 4, "CEMETERY": 3, "CREMATORIUM": 4}
const PLOTS_PER_TILE := 400        # graves a cemetery tile holds
const FOUNDERS_SIGHT_BURIALS := 150   # the colony's first cemetery becomes a sight once this many lie there
const LAND_COST := {".": 100, "h": 70, "k": 60, "f": 250, "n": 250, "L": 400}
## River: share of the load a tile passes on downstream (‰), share of last month's pollution that lingers (‰), and the
## pollution at which water quality is down to 50.
const KEEP_PER_TILE := 970
const LINGER := 300
const QUALITY_HALF := 1500
const CANDIDATES := 10

static var _flow_cache := {}


# ================================================================== the river (flow is pure)

## River flow of the colony map: {"down": {tile: next tile downstream (-1 at the mouth)}, "order": [tiles, upstream
## first], "dist": {tile: steps to the mouth}}. The river runs north to south and leaves the map at the south edge;
## the tributary flows into it. Cached per terrain.
static func flow(world: WorldState) -> Dictionary:
	if not Terrain.ready(world):
		return {"down": {}, "order": [], "dist": {}}
	var key := "%d|%d" % [world.rng.derive_seed("map.terrain"), hash(world.peek("map")["grid"]["rows"])]
	if _flow_cache.has(key):
		return _flow_cache[key]
	var W := Terrain.W
	var H := Terrain.H
	var dist := {}
	var q: Array = []
	for x in W:   # the mouth: river tiles on the south edge (else the southernmost ones)
		if Terrain.at(world, x, H - 1) == "r":
			dist[(H - 1) * W + x] = 0
			q.append((H - 1) * W + x)
	if q.is_empty():
		for y in range(H - 1, -1, -1):
			for x2 in W:
				if Terrain.at(world, x2, y) == "r":
					dist[y * W + x2] = 0
					q.append(y * W + x2)
			if not q.is_empty():
				break
	var down := {}
	for t in q:
		down[t] = -1
	var all_river: Array = []
	for y2 in H:
		for x3 in W:
			if Terrain.at(world, x3, y2) == "r":
				all_river.append(y2 * W + x3)
	var qi := 0
	while true:
		while qi < q.size():
			var c: int = q[qi]
			qi += 1
			var cx := c % W
			var cy := c / W
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx: int = cx + dx
					var ny: int = cy + dy
					var ni: int = ny * W + nx
					if nx < 0 or ny < 0 or nx >= W or ny >= H or dist.has(ni) or Terrain.at(world, nx, ny) != "r":
						continue
					dist[ni] = int(dist[c]) + 1
					down[ni] = c
					q.append(ni)
		# a stretch cut off by hills (the stream runs under them): join its tile nearest the flowing river to it
		var best_u := -1
		var best_v := -1
		var bd := 0x7fffffff
		for u in all_river:
			if dist.has(u):
				continue
			for v in q:
				var d := maxi(absi(int(u) % W - int(v) % W), absi(int(u) / W - int(v) / W))
				if d < bd:
					bd = d
					best_u = int(u)
					best_v = int(v)
		if best_u < 0:
			break
		dist[best_u] = int(dist[best_v]) + bd
		down[best_u] = best_v
		q.append(best_u)
	var order: Array = dist.keys()
	order.sort_custom(func(a, b): return int(dist[a]) > int(dist[b]) or (int(dist[a]) == int(dist[b]) and int(a) < int(b)))
	var out := {"down": down, "order": order, "dist": dist}
	if _flow_cache.size() >= 6:
		_flow_cache.clear()
	_flow_cache[key] = out
	return out


## The river tile nearest a tile (itself if it is one); -1 if the map has no river.
static func nearest_river(world: WorldState, tile: int) -> int:
	var f := flow(world)
	if f["dist"].has(tile):
		return tile
	var t := Transport.int_tile(tile)
	var best := -1
	var bd := 0x7fffffff
	for r in f["order"]:
		var v := Transport.int_tile(int(r))
		var d := maxi(absi(v.x - t.x), absi(v.y - t.y)) * 1000 + int(r) % 1000
		if d < bd:
			bd = d
			best = int(r)
	return best


## River tiles downstream of a tile (from its nearest river tile to the mouth, that tile first).
static func downstream(world: WorldState, tile: int) -> Array:
	var f := flow(world)
	var out: Array = []
	var c := nearest_river(world, tile)
	while c >= 0 and out.size() < 400:
		out.append(c)
		c = int(f["down"].get(c, -1))
	return out


## Pollution of the river at (or nearest to) a tile, in load units.
static func river_pollution(world: WorldState, tile: int) -> int:
	var r := nearest_river(world, tile)
	return int(world.peek("river").get("poll", {}).get(str(r), 0)) if r >= 0 else 0


## Water quality 0..100 (100 = clean) of the river at a tile, or of the nearest river tile within `reach` tiles
## (farms and waterworks on the banks); 100 if the river is farther.
static func river_quality(world: WorldState, tile: int, reach: int = 3) -> int:
	var r := nearest_river(world, tile)
	if r < 0:
		return 100
	var a := Transport.int_tile(tile)
	var b := Transport.int_tile(r)
	if maxi(absi(a.x - b.x), absi(a.y - b.y)) > reach:
		return 100
	var p := float(world.peek("river").get("poll", {}).get(str(r), 0))
	return clampi(roundi(100.0 * QUALITY_HALF / (QUALITY_HALF + p)), 0, 100)


## Bob (W5): untreated sewage or landfill leachate entering the river this month at (or near) a source tile.
static func add_discharge(world: WorldState, tile: int, units: int) -> void:
	var r := nearest_river(world, tile)
	if r < 0 or units <= 0:
		return
	var rv := world.table("river")
	if not rv.has("load"):
		rv["load"] = {}
	rv["load"][str(r)] = int(rv["load"].get(str(r), 0)) + units


## Monthly (NATURE): last month's discharges flow downstream (each tile passes on KEEP_PER_TILE ‰), on top of what
## lingers from before (LINGER ‰). Tiles below 1 unit are dropped, so the table stays small.
static func step_month(world: WorldState) -> void:
	if not Terrain.ready(world) or not world.peek("river").has("load") and not world.peek("river").has("poll"):
		return
	var f := flow(world)
	var rv := world.table("river")
	var load: Dictionary = rv.get("load", {})
	var old: Dictionary = rv.get("poll", {})
	var carry := {}
	var poll := {}
	for t in f["order"]:   # upstream first
		var here := int(load.get(str(t), 0)) + int(carry.get(t, 0))
		var v := int(old.get(str(t), 0)) * LINGER / 1000 + here
		if v >= 1:
			poll[str(t)] = v
		var d := int(f["down"].get(t, -1))
		if d >= 0 and here > 0:
			carry[d] = int(carry.get(d, 0)) + here * KEEP_PER_TILE / 1000
	rv["poll"] = poll
	rv["load"] = {}


## What sits on the banks downstream of a tile: [{kind: FACILITY|SITE|AREA, id, name, tile, quality}] (news, Bob's
## farms and waterworks, tourism).
static func on_banks_downstream(world: WorldState, tile: int, reach: int = 2) -> Array:
	var river := {}
	for r in downstream(world, tile):
		river[int(r)] = true
	var near := func(t: Vector2i) -> bool:
		for yy in range(t.y - reach, t.y + reach + 1):
			for xx in range(t.x - reach, t.x + reach + 1):
				if river.has(yy * Terrain.W + xx) and xx >= 0 and xx < Terrain.W:
					return true
		return false
	var out: Array = []
	var ft := ColonyLayout.facility_tiles(world)
	for fid in EconUtil.sorted_keys(ft):
		if near.call(ft[fid]):
			out.append({"kind": "FACILITY", "id": fid, "name": String(world.peek("facility")[fid]["type"]).to_lower(), "tile": Transport.tile_int(ft[fid]),
				"quality": river_quality(world, Transport.tile_int(ft[fid]))})
	for s in PlanetSites.sites(world):
		if s["where"] == "COLONY" and near.call(s["tile"]):
			out.append({"kind": "SITE", "id": s["id"], "name": s["name"], "tile": Transport.tile_int(s["tile"]),
				"quality": river_quality(world, Transport.tile_int(s["tile"]))})
	for st in ColonyLayout.settlements(world):
		if near.call(st["tile"]):
			out.append({"kind": "AREA", "id": st["id"], "name": st["name"], "tile": Transport.tile_int(st["tile"]),
				"quality": river_quality(world, Transport.tile_int(st["tile"]))})
	return out


# ================================================================== siting (pure)

## Candidate sites for a kind, best first: [{tiles: [footprint tile ints], tile (the anchor), score 0..100, terrain,
## dist_town (tiles to the nearest settlement), dist_river, road (tiles to the nearest road; -1 = no road at all),
## land_cost (per tile, summed), competing ("farmland" | "housing land" | ""), private (tiles on private land),
## next_door: [{id, name, district, dist}] (settlements within NIMBY_R), downstream_of_towns (TREATMENT)}].
static func candidates(world: WorldState, kind: String, n: int = CANDIDATES) -> Array:
	if not Terrain.ready(world) or not kind in KINDS:
		return []
	var fields := _fields(world)
	var town: PackedInt32Array = fields["town"]
	var river: PackedInt32Array = fields["river"]
	var road: PackedInt32Array = fields["road"]
	var taken: Dictionary = fields["taken"]
	var fp: int = FOOTPRINT[kind]
	var ok_codes: Array = TERRAIN[kind]
	var W := Terrain.W
	var town_d := _town_river_dist(world)
	var all: Array = []
	for y in range(0, Terrain.H - fp + 1):
		for x in range(0, W - fp + 1):
			var tiles: Array = []
			var good := true
			for dy in fp:
				for dx in fp:
					var ti := (y + dy) * W + x + dx
					if taken.has(ti) or not Terrain.at(world, x + dx, y + dy) in ok_codes:
						good = false
						break
					tiles.append(ti)
				if not good:
					break
			if not good:
				continue
			var dt := 0x7fff
			var dr := 0x7fff
			var dd := 0x7fff
			var cost := 0
			var farm := 0
			var house := 0
			var priv := 0
			for ti2 in tiles:
				dt = mini(dt, town[ti2])
				dr = mini(dr, river[ti2])
				dd = mini(dd, road[ti2] if road[ti2] >= 0 else 0x7fff)
				var code := Terrain.at(world, ti2 % W, ti2 / W)
				var c := int(LAND_COST.get(code, 100))
				if code in ["f", "n"]:
					farm += 1
				if town[ti2] <= 3 and code in Terrain.BUILDABLE_HOUSING:
					house += 1
					c += 100
				var title: Dictionary = LQ.land_title(world, Transport.int_tile(ti2))
				if not title.is_empty() and String(title.get("owner", "gov")) != "gov":
					priv += 1
					c *= 2
				cost += c
			var below := -1
			if kind == "TREATMENT":
				if dr > 2:
					continue
				var rt := WasteMap.nearest_river(world, tiles[0])
				below = 1 if rt >= 0 and int(flow(world)["dist"].get(rt, 0)) <= town_d else 0
			var s := _score(kind, dt, dr, dd, cost / tiles.size(), below)
			all.append({"tiles": tiles, "tile": tiles[0], "score": s, "terrain": Terrain.at(world, x, y), "dist_town": dt,
				"dist_river": dr, "road": dd if dd < 0x7fff else -1, "land_cost": cost,
				"competing": "farmland" if farm > 0 else ("housing land" if house > 0 else ""), "private": priv,
				"downstream_of_towns": below})
	all.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]) or (int(a["score"]) == int(b["score"]) and int(a["tile"]) < int(b["tile"])))
	var out: Array = []
	for c2 in all:   # spread the shortlist: candidates at least 3 tiles apart
		var close := false
		var a := Transport.int_tile(int(c2["tile"]))
		for o in out:
			var b := Transport.int_tile(int(o["tile"]))
			close = close or maxi(absi(a.x - b.x), absi(a.y - b.y)) < 3
		if close:
			continue
		c2["next_door"] = next_door(world, kind, c2["tiles"])
		out.append(c2)
		if out.size() >= n:
			break
	return out


## How good a site is, 0..100: kind-specific distance wishes, road access, land cost.
static func _score(kind: String, dt: int, dr: int, dd: int, cost: int, below: int) -> int:
	var s := 100.0
	match kind:
		"LANDFILL":
			s -= 15.0 * maxi(0, 6 - dt) + 12.0 * maxi(0, 4 - dr) + 1.0 * maxi(0, dt - 14)
		"INCINERATOR":
			s -= 15.0 * maxi(0, 4 - dt) + 1.0 * maxi(0, dt - 10)
		"RECYCLING":
			s -= 10.0 * maxi(0, 2 - dt) + 4.0 * maxi(0, dt - 6)
		"TREATMENT":
			s -= 12.0 * maxi(0, 3 - dt) + 3.0 * maxi(0, dt - 8) + (0.0 if below == 1 else 25.0)
		"CEMETERY":
			s -= 12.0 * maxi(0, 2 - dt) + 4.0 * maxi(0, dt - 6) + 10.0 * maxi(0, 2 - dr)
		"CREMATORIUM":
			s -= 12.0 * maxi(0, 2 - dt) + 3.0 * maxi(0, dt - 8)
	s -= 2.0 * float(mini(dd, 20))   # a site off the network needs a road first (Transport)
	s -= float(cost) / 25.0
	return clampi(roundi(s), 0, 100)


## Settlements (areas once they exist) within NIMBY_R of a footprint: [{id, name, district, dist}], nearest first.
static func next_door(world: WorldState, kind: String, tiles: Array) -> Array:
	var r: int = NIMBY_R.get(kind, 4)
	var out: Array = []
	for s in ColonyLayout.settlements(world):
		var best := 0x7fff
		for tt in s["tiles"]:
			for ti in tiles:
				var a := Transport.int_tile(int(ti))
				best = mini(best, maxi(absi(a.x - tt.x), absi(a.y - tt.y)))
		if best <= r:
			out.append({"id": s["id"], "name": s["name"], "district": s["district"], "dist": best})
	out.sort_custom(func(a, b): return int(a["dist"]) < int(b["dist"]) or (int(a["dist"]) == int(b["dist"]) and String(a["id"]) < String(b["id"])))
	return out


## Distance fields over the map (Chebyshev tiles): to the nearest settlement tile, river tile and road tile; and the
## tiles already taken (map uses, facilities, roads, waste sites).
static func _fields(world: WorldState) -> Dictionary:
	var W := Terrain.W
	var n := W * Terrain.H
	var towns: Array = []
	for s in ColonyLayout.settlements(world):
		for t in s["tiles"]:
			towns.append(Transport.tile_int(t))
	var rivers: Array = flow(world)["order"]
	var roads: Array = []
	var taken := {}
	for l in Transport.network(world)["links"]:
		if int(l.get("globe", 0)) == 0:
			for ti in l["path"]:
				roads.append(int(ti))
				taken[int(ti)] = true
	for k in world.peek("map").get("uses", {}):
		taken[Transport.tile_int(ColonyLayout.as_tile(k))] = true
	var ft := ColonyLayout.facility_tiles(world)
	for fid in ft:
		taken[Transport.tile_int(ft[fid])] = true
	for sid in world.peek("waste_sites"):
		for ti2 in world.peek("waste_sites")[sid]["tiles"]:
			taken[int(ti2)] = true
	for s2 in ColonyLayout.settlements(world):   # pre-A2 towns are drawn, not claimed: keep their centres free
		taken[Transport.tile_int(s2["tile"])] = true
	return {"town": _bfs(towns, n, W), "river": _bfs(rivers, n, W), "road": _bfs(roads, n, W), "taken": taken}


static func _bfs(src: Array, n: int, W: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(-1)
	var q: Array = []
	for s in src:
		if d[int(s)] < 0:
			d[int(s)] = 0
			q.append(int(s))
	var qi := 0
	while qi < q.size():
		var c: int = q[qi]
		qi += 1
		var cx := c % W
		var cy := c / W
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var nx: int = cx + dx
				var ny: int = cy + dy
				if nx < 0 or ny < 0 or nx >= W or ny * W + nx >= n:
					continue
				var ni: int = ny * W + nx
				if d[ni] < 0:
					d[ni] = d[c] + 1
					q.append(ni)
	if src.is_empty():
		d.fill(0x7fff)
	return d


## The river distance (to the mouth) of the most downstream river tile next to a settlement: a treatment plant below
## this point is downstream of every town.
static func _town_river_dist(world: WorldState) -> int:
	var f := flow(world)
	var best := 0x7fff
	for s in ColonyLayout.settlements(world):
		var r := nearest_river(world, Transport.tile_int(s["tile"]))
		if r >= 0:
			best = mini(best, int(f["dist"].get(r, 0x7fff)))
	return best


# ================================================================== sites (state)

## Bob: a waste facility or cemetery was built on a footprint (tile ints from a candidate). Claims the tiles.
static func register_site(world: WorldState, fid: String, kind: String, tiles: Array) -> void:
	assert(kind in KINDS, "waste site kind")
	world.table("waste_sites")[fid] = {"id": fid, "kind": kind, "tiles": tiles.map(func(t): return int(t)), "built": world.month,
		"fill": 0, "burials": 0}


static func remove_site(world: WorldState, fid: String) -> void:
	world.table("waste_sites").erase(fid)


## A cemetery or landfill grows onto more tiles (an extension project).
static func extend_site(world: WorldState, fid: String, tiles: Array) -> void:
	var s: Dictionary = world.table("waste_sites")[fid]
	for t in tiles:
		if not int(t) in s["tiles"]:
			s["tiles"].append(int(t))


## Bob: how full a landfill (or any site) is, ‰.
static func set_fill(world: WorldState, fid: String, permille: int) -> void:
	world.table("waste_sites")[fid]["fill"] = clampi(permille, 0, 1000)


## Bob: burials in a cemetery this month. Returns how many found a plot (the rest need another cemetery or cremation).
static func add_burials(world: WorldState, fid: String, n: int) -> int:
	var s: Dictionary = world.table("waste_sites")[fid]
	var free := plots(s) - int(s["burials"])
	var placed := clampi(n, 0, maxi(0, free))
	s["burials"] = int(s["burials"]) + placed
	s["fill"] = int(s["burials"]) * 1000 / maxi(1, plots(s))
	return placed


static func plots(site: Dictionary) -> int:
	return site["tiles"].size() * PLOTS_PER_TILE


## All sites: [{id, kind, tiles, built, fill, burials, plots}] (cemeteries carry plots).
static func sites(world: WorldState) -> Array:
	var out: Array = []
	var t := world.peek("waste_sites")
	for fid in EconUtil.sorted_keys(t):
		var s: Dictionary = t[fid].duplicate(true)
		if s["kind"] == "CEMETERY":
			s["plots"] = plots(t[fid])
		out.append(s)
	return out


## The colony's first cemetery (earliest built, then lowest id); {} if none yet.
static func founders_cemetery(world: WorldState) -> Dictionary:
	var best := {}
	var t := world.peek("waste_sites")
	for fid in EconUtil.sorted_keys(t):
		var s: Dictionary = t[fid]
		if s["kind"] == "CEMETERY" and (best.is_empty() or int(s["built"]) < int(best["built"])):
			best = s
	return best


## The founders' cemetery as a sight (PlanetSites reads it): its tile once FOUNDERS_SIGHT_BURIALS lie there, else (-1, -1).
static func founders_sight_tile(world: WorldState) -> Vector2i:
	var f := founders_cemetery(world)
	if f.is_empty() or int(f["burials"]) < FOUNDERS_SIGHT_BURIALS:
		return Vector2i(-1, -1)
	return Transport.int_tile(int(f["tiles"][0]))
