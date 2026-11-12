class_name Transport
extends RefCounted
## Terra (A43, spec-transport-v1 §T1): the transport network. NOTHING IS REACHABLE FOR FREE: off the built network
## the land is off-road. A place (settlement, the port, a plant, a tourist site) is reached by a built link, or by
## specialised vehicles: rovers (ground, need a ROVER_BASE, range in hexes) and airships (need a MAST, grounded by
## storms).
##
## State (world table "transport", integers and strings only):
##   {"links": {lid: link}, "bases": {bid: {id, kind: ROVER_BASE|MAST, tile, owner}}, "seq": int}
##   colony link: {id, kind: TRACK|ROAD|PAVED, path: [tile ints, y*64+x], bridges, cond 0..1000, traffic, built, globe: 0}
##   globe link:  {id, kind, cells: [hex ints from the landing hex], site, cond, traffic, built, globe: 1}
## Until the first NATURE tick writes the table, every query sees the founding network (tracks joining the first
## settlements, and spurs to the founding plants that stand outside a town), so queries stay pure.
##
## Queries (pure): network, route, reachable_sites, closures, plan_link / validate_link (cost of a link).
## Writes: step_month (NATURE: wear, weather), complete_road (Bob's ROAD projects), add_traffic, add_base.

const KINDS := ["TRACK", "ROAD", "PAVED"]
const KIND_NAMES := {"TRACK": "dirt track", "ROAD": "road", "PAVED": "paved road"}
const KM_PER_TILE := 3            # the landing hex (~210 km) holds the 64-tile-wide colony map
const KM_PER_HEX := 210
## Speeds (km a day, loading and stops included) and cost (cost_index per 100 km; 100 = 100 km on a sound road).
const SPEED := {"TRACK": 80, "ROAD": 200, "PAVED": 400, "STREET": 120, "ROVER": 60, "AIRSHIP": 900}
const COST := {"TRACK": 160, "ROAD": 100, "PAVED": 80, "STREET": 100, "ROVER": 450, "AIRSHIP": 1200}
const CAPACITY := {"TRACK": 300, "ROAD": 1500, "PAVED": 6000}    # vehicle trips a month before congestion
const WEAR := {"TRACK": 10, "ROAD": 5, "PAVED": 3}               # condition lost a month (of 1000) with no traffic
const STORM_WEAR := {"TRACK": 30, "ROAD": 15, "PAVED": 8}        # per storm strength over the colony
const WORN := 150                  # below this condition a road or paved road is only as good as a track
const ROVER_RANGE_HEX := 5         # rovers reach land hexes this many steps from the colony (no sea crossing)
const AIRSHIP_RANGE_HEX := 80      # the whole hemisphere and more
## Path planning: cost of entering a tile (10 = open plain); a river tile needs a bridge.
const TERRAIN_COST := {".": 10, "f": 10, "n": 10, "L": 10, "h": 20, "k": 35, "o": 25, "x": 25, "r": 60}
## Bridges: a road crosses the river straight (no diagonal step touches water), and every further water tile of the
## same span costs RIVER_RUN, so the planner takes the shortest span and never runs along the river.
const RIVER_RUN := 160
const SPAN_EXTRA := 50             # each tile beyond the first of a span costs this % more to build (longer, higher bridge)
const PLANNER := 2                 # bump when crossings are planned differently: old links are re-planned once
## Work bill per tile (wu, materials, components), like an EconData.BUILD row; bridges per river tile;
## globe links per hex (a long road through the wild).
const BILL_TILE := {"TRACK": [6, 2, 0], "ROAD": [20, 18, 1], "PAVED": [32, 36, 2]}
const BILL_BRIDGE := {"TRACK": [20, 15, 0], "ROAD": [60, 70, 4], "PAVED": [80, 100, 6]}
const BILL_HEX := {"TRACK": [180, 60, 0], "ROAD": [600, 520, 15], "PAVED": [1000, 1000, 30]}
const TERRAIN_WU := {"h": 15, "k": 20, "o": 18, "x": 18}         # ×10: hills cost 1.5× the work
## T7 traffic engineering. Capacity of a link = CAPACITY[kind] × lanes; its river crossings carry CAPACITY[kind] ×
## bridge_lanes (a second bridge doubles them). Junctions (tiles where three or more road branches meet) have a type.
const JUNCTION_TYPES := ["CROSSING", "PRIORITY", "ROUNDABOUT", "SIGNALS"]
const JUNCTION_NAMES := {"CROSSING": "plain crossing", "PRIORITY": "priority junction", "ROUNDABOUT": "roundabout",
	"SIGNALS": "signal-controlled junction"}
const JUNCTION_CAPACITY := {"CROSSING": 400, "PRIORITY": 900, "ROUNDABOUT": 2000, "SIGNALS": 3000}   # trips a month
## Relative risk of a serious accident per trip (100 = a plain crossing); Bob turns counts into accidents.
const JUNCTION_RISK := {"CROSSING": 100, "PRIORITY": 70, "ROUNDABOUT": 25, "SIGNALS": 45}
const BILL_JUNCTION := {"PRIORITY": [15, 8, 0], "ROUNDABOUT": [110, 140, 2], "SIGNALS": [50, 40, 14]}
const LANE_SHARE := 70             # a second lane costs this % of the link's bill (bridges excluded)
const PLANT_FREE_TYPES := ["HOUSING", "CLINIC", "SCHOOL", "ADMIN", "SERVICEHUB"]   # in-town services, not plants

static var _init_cache := {}
static var _memo := {}


## Memoised pure reads: valid while the month, the network revision and the colony layout stay the same.
static func _memoised(world: WorldState, what: String, fn: Callable) -> Variant:
	var k := "%s|%d|%d|%d|%s|%d" % [what, world.rng.derive_seed("map.terrain"), world.month, int(world.peek("transport").get("rev", 0)),
		ColonyLayout.key(world), hash(world.peek("planet").get("storms", []))]
	if not _memo.has(k):
		if _memo.size() >= 32:
			_memo.clear()
		_memo[k] = fn.call()
	return _memo[k]


static func _bump(world: WorldState) -> void:
	var t := world.table("transport")
	t["rev"] = int(t.get("rev", 0)) + 1


# ================================================================== state

static func _links(world: WorldState) -> Dictionary:
	var t := world.peek("transport")
	if t.has("links"):
		return t["links"]
	return _founding(world)


static func _bases(world: WorldState) -> Dictionary:
	return world.peek("transport").get("bases", {})


## Write the founding network into the world (idempotent). Called by the NATURE tick and by every write.
static func ensure(world: WorldState) -> void:
	if world.peek("transport").has("links") or not Terrain.ready(world):
		return
	var t := world.table("transport")
	t["links"] = _founding(world).duplicate(true)
	t["bases"] = {}
	t["seq"] = t["links"].size()
	t["junctions"] = _derive_junctions(t["links"], {})
	t["planner"] = PLANNER
	t["rev"] = 1


static func _new_id(world: WorldState) -> String:
	var t := world.table("transport")
	t["seq"] = int(t.get("seq", 0)) + 1
	return "link:%d" % int(t["seq"])


## The founding network: tracks joining the first settlements (nearest first, from the landing), plus spur tracks to
## founding plants outside every town. Pure, cached per terrain and layout.
static func _founding(world: WorldState) -> Dictionary:
	if not Terrain.ready(world):
		return {}
	var key := ColonyLayout.key(world)
	if _init_cache.has(key):
		return _init_cache[key]
	var links := {}
	var setl := ColonyLayout.settlements(world)
	var land := Terrain.landing(world)
	var joined: Array = []
	var left: Array = setl.duplicate()
	left.sort_custom(func(a, b): return Vector2(a["tile"]).distance_to(Vector2(land)) < Vector2(b["tile"]).distance_to(Vector2(land)) or (Vector2(a["tile"]).distance_to(Vector2(land)) == Vector2(b["tile"]).distance_to(Vector2(land)) and String(a["id"]) < String(b["id"])))
	if not left.is_empty():
		joined.append(left.pop_front())
	var n := 0
	var used := {}
	while not left.is_empty():
		var bi := 0
		var bj := 0
		var bd := INF
		for i in left.size():
			for j in joined.size():
				var d := Vector2(left[i]["tile"]).distance_to(Vector2(joined[j]["tile"]))
				if d < bd:
					bd = d
					bi = i
					bj = j
		var s: Dictionary = left.pop_at(bi)
		var p := plan_path(world, joined[bj]["tile"], s["tile"], used)
		if not p.is_empty():
			n += 1
			links["link:%d" % n] = _colony_link("link:%d" % n, "TRACK", p, world, 0)
			for ti in p:
				used[ti] = true
		joined.append(s)
	# spur tracks to founding plants that stand outside every town
	var ft := ColonyLayout.facility_tiles(world)
	var fac: Dictionary = world.peek("facility")
	for fid in EconUtil.sorted_keys(ft):
		if String(fac.get(fid, {}).get("type", "")) in PLANT_FREE_TYPES:
			continue
		var t: Vector2i = ft[fid]
		if _town_of(setl, t) != "":
			continue
		var best: Vector2i = setl[0]["tile"] if not setl.is_empty() else land
		for s2 in setl:
			if Vector2(s2["tile"]).distance_to(Vector2(t)) < Vector2(best).distance_to(Vector2(t)):
				best = s2["tile"]
		var p2 := plan_path(world, best, t, used)
		if not p2.is_empty():
			n += 1
			links["link:%d" % n] = _colony_link("link:%d" % n, "TRACK", p2, world, 0)
			for ti in p2:
				used[ti] = true
	if _init_cache.size() >= 6:
		_init_cache.clear()
	_init_cache[key] = links
	return links


static func _colony_link(id: String, kind: String, path: Array, world: WorldState, month: int) -> Dictionary:
	var sp := spans(world, path)
	var br := 0
	for x in sp:
		br += int(x[1])
	return {"id": id, "kind": kind, "path": path.duplicate(), "lanes": 1, "bridges": br, "spans": sp, "bridge_lanes": 1,
		"cond": 1000, "traffic": 0, "acc": 0, "built": month, "globe": 0}


## River crossings of a tile path: [[index of the first water tile, tiles of water in a row], ...].
static func spans(world: WorldState, path: Array) -> Array:
	var out: Array = []
	var i := 0
	while i < path.size():
		if _water(world, int(path[i])):
			var n := 0
			while i + n < path.size() and _water(world, int(path[i + n])):
				n += 1
			out.append([i, n])
			i += n
		else:
			i += 1
	return out


static func _water(world: WorldState, ti: int) -> bool:
	return Terrain.at(world, ti % Terrain.W, ti / Terrain.W) == "r"


## Junctions: tiles where three or more road branches meet. Keeps the type, traffic and accidents of junctions
## that still exist (`old`); new ones start as plain crossings.
static func _derive_junctions(links: Dictionary, old: Dictionary) -> Dictionary:
	var nb := {}
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var p: Array = l["path"]
		for i in range(1, p.size()):
			var u := int(p[i - 1])
			var v := int(p[i])
			if not nb.has(u):
				nb[u] = {}
			if not nb.has(v):
				nb[v] = {}
			nb[u][v] = true
			nb[v][u] = true
	var out := {}
	for t in nb:
		if nb[t].size() >= 3:
			var jid := "junc:%d" % int(t)
			var o: Dictionary = old.get(jid, {})
			out[jid] = {"id": jid, "tile": int(t), "type": String(o.get("type", "CROSSING")), "branches": nb[t].size(),
				"traffic": int(o.get("traffic", 0)), "acc": int(o.get("acc", 0))}
	return out


## Junctions: {jid: {id, tile, type, branches, traffic, acc}}.
static func junctions(world: WorldState) -> Dictionary:
	var t := world.peek("transport")
	if t.has("junctions"):
		return t["junctions"]
	return _memoised(world, "junctions", func(): return _derive_junctions(_links(world), {}))


## Trips a month a link carries before congestion: kind × lanes, and its river crossings kind × bridges.
static func link_capacity(l: Dictionary) -> int:
	var base := int(CAPACITY[effective_kind(l)])
	var cap := base * int(l.get("lanes", 1))
	if int(l.get("bridges", 0)) > 0:
		cap = mini(cap, base * int(l.get("bridge_lanes", 1)))
	return cap


## Trips a month a junction handles: its type × the most lanes of the links meeting there.
static func junction_capacity(world: WorldState, j: Dictionary) -> int:
	var lanes := 1
	var links := _links(world)
	for lid in links:
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 0 and int(j["tile"]) in l["path"]:
			lanes = maxi(lanes, int(l.get("lanes", 1)))
	return int(JUNCTION_CAPACITY[String(j["type"])]) * lanes


static func _town_of(setl: Array, t: Vector2i) -> String:
	for s in setl:
		if t in s["tiles"]:
			return String(s["id"])
	return ""


static func tile_int(t: Vector2i) -> int:
	return t.y * Terrain.W + t.x


static func int_tile(i: int) -> Vector2i:
	return Vector2i(i % Terrain.W, i / Terrain.W)


# ================================================================== path planning (pure)

## Cheapest tile path from a to b over the terrain ([tile ints], a and b included; [] if none). Existing link tiles
## in `reuse` are cheap, so new roads follow old ones.
static func plan_path(world: WorldState, a: Vector2i, b: Vector2i, reuse: Dictionary = {}, avoid: Dictionary = {}) -> Array:
	var W := Terrain.W
	var n := W * Terrain.H
	var src := tile_int(a)
	var dst := tile_int(b)
	if Terrain.at(world, a.x, a.y) == "" or Terrain.at(world, b.x, b.y) == "":
		return []
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(0x3fffffff)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var rows: Array = world.peek("map")["grid"]["rows"]
	dist[src] = 0
	var heap: Array = [src]   # keys: cost << 12 | tile
	while not heap.is_empty():
		var top: int = _hpop(heap)
		var c := top & 4095
		var dc := top >> 12
		if dc > dist[c]:
			continue
		if c == dst:
			break
		var cx := c % W
		var cy := c / W
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nx: int = cx + dx
				var ny: int = cy + dy
				if nx < 0 or ny < 0 or nx >= W or ny >= Terrain.H:
					continue
				var ni: int = ny * W + nx
				var code := String(rows[ny]).substr(nx, 1)
				var from_water := String(rows[cy]).substr(cx, 1) == "r"
				if dx != 0 and dy != 0 and (code == "r" or from_water or String(rows[cy]).substr(nx, 1) == "r" or String(rows[ny]).substr(cx, 1) == "r"):
					continue   # bridges go straight across: no diagonal step over, into, out of or past a water corner
				var step: int = 4 if reuse.has(ni) else int(TERRAIN_COST.get(code, 10))
				if code == "r" and from_water:
					step = RIVER_RUN   # one more tile of the same span (even on an old link: a long span is a bad bridge)
				if avoid.has(ni):
					step *= 8
				if dx != 0 and dy != 0:
					step = step * 14 / 10
				var nd := dc + step
				if nd < dist[ni]:
					dist[ni] = nd
					prev[ni] = c
					_hpush(heap, (nd << 12) | ni)
	if prev[dst] < 0 and src != dst:
		return []
	var path: Array = [dst]
	var cur := dst
	while cur != src:
		cur = prev[cur]
		path.append(cur)
	path.reverse()
	return path


static func _hpush(h: Array, v: int) -> void:
	h.append(v)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p] <= v:
			break
		h[i] = h[p]
		i = p
	h[i] = v


static func _hpop(h: Array) -> int:
	var top: int = h[0]
	var last: int = h.pop_back()
	if h.is_empty():
		return top
	var i := 0
	var n := h.size()
	while true:
		var l := 2 * i + 1
		if l >= n:
			break
		var r := l + 1
		var m := l if r >= n or h[l] <= h[r] else r
		if h[m] >= last:
			break
		h[i] = h[m]
		i = m
	h[i] = last
	return top


static func _path_km(path: Array) -> int:
	var km := 0.0
	for k in range(1, path.size()):
		var a := int_tile(int(path[k - 1]))
		var b := int_tile(int(path[k]))
		km += (1.4 if a.x != b.x and a.y != b.y else 1.0) * KM_PER_TILE
	return roundi(km)


# ================================================================== weather (pure, this month)

## Strongest storm over a hex this month (0 = none).
static func _storm(world: WorldState, cell: int) -> int:
	var s := 0
	for h in PlanetClimate.storms_at(world, cell):
		s = maxi(s, int(h["strength"]))
	return s


## Kind a link works as: a worn-out road or paved road is only as good as a track.
static func effective_kind(l: Dictionary) -> String:
	return "TRACK" if int(l["cond"]) < WORN else String(l["kind"])


## Why a link is closed this month ("" = open): tracks close in storms (2+) and heavy rain (160% of normal),
## roads in strong storms (4+); paved roads stay open.
static func closed_reason(world: WorldState, l: Dictionary) -> String:
	var k := effective_kind(l)
	if k == "PAVED":
		return ""
	var s := 0
	var rain := 100
	if int(l.get("globe", 0)) == 1:
		for c in l["cells"]:
			s = maxi(s, _storm(world, int(c)))
	else:
		var home := Planet.landing(world)
		s = _storm(world, home)
		rain = int(PlanetClimate.weather(world, home)["rain_pct"])
	if k == "TRACK":
		if s >= 2:
			return "STORM"
		if rain >= 160:
			return "MUD"
	elif s >= 4:
		return "STORM"
	return ""


## Links closed this month: {lid: reason}.
static func closures(world: WorldState) -> Dictionary:
	var out := {}
	var links := _links(world)
	for lid in EconUtil.sorted_keys(links):
		var r := closed_reason(world, links[lid])
		if r != "":
			out[lid] = r
	return out


# ================================================================== nodes

## Every node: [{id, kind: SETTLEMENT|PORT|PLANT|SITE|BASE, name, tile (int, -1 off the colony map), cell, town}].
## town = the settlement whose streets reach it ("" = none).
static func nodes(world: WorldState) -> Array:
	return _memoised(world, "nodes", func(): return _nodes(world))


static func node(world: WorldState, id: String) -> Dictionary:
	return _memoised(world, "node_index", func():
		var ix := {}
		for n in nodes(world):
			ix[n["id"]] = n
		return ix).get(id, {})


static func _nodes(world: WorldState) -> Array:
	var out: Array = []
	if not Terrain.ready(world):
		return out
	var setl := ColonyLayout.settlements(world)
	var home := Planet.landing(world)
	for s in setl:
		out.append({"id": s["id"], "kind": "SETTLEMENT", "name": s["name"], "tile": tile_int(s["tile"]), "cell": home, "town": s["id"]})
	var land := Terrain.landing(world)
	out.append({"id": "port", "kind": "PORT", "name": "the landing port", "tile": tile_int(land), "cell": home, "town": _town_of(setl, land)})
	var ft := ColonyLayout.facility_tiles(world)
	var fac: Dictionary = world.peek("facility")
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty() or String(f["type"]) in PLANT_FREE_TYPES:
			continue
		out.append({"id": fid, "kind": "PLANT", "name": "%s %s" % [String(f["type"]).to_lower(), fid], "tile": tile_int(ft[fid]),
			"cell": home, "town": _town_of(setl, ft[fid])})
	for st in PlanetSites.sites(world):
		var colony: bool = st["where"] == "COLONY"
		out.append({"id": st["id"], "kind": "SITE", "name": st["name"], "tile": tile_int(st["tile"]) if colony else -1,
			"cell": int(st["cell"]), "town": _town_of(setl, st["tile"]) if colony else ""})
	var bases := _bases(world)
	for bid in EconUtil.sorted_keys(bases):
		var b: Dictionary = bases[bid]
		out.append({"id": bid, "kind": "BASE", "name": "%s %s" % [String(b["kind"]).to_lower().replace("_", " "), bid],
			"tile": int(b["tile"]), "cell": home, "town": _town_of(setl, int_tile(int(b["tile"])))})
	return out


# ================================================================== queries

## The network: {nodes: (see nodes()), links: [{id, kind, effective, globe, path | cells, site, km, bridges, cond,
## capacity, traffic, closed}]}.
static func network(world: WorldState) -> Dictionary:
	var ls: Array = []
	var links := _links(world)
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		var d := l.duplicate(true)
		d["effective"] = effective_kind(l)
		d["km"] = link_km(l)
		d["capacity"] = link_capacity(l)
		d["closed"] = closed_reason(world, l)
		ls.append(d)
	var js: Array = []
	var jt := junctions(world)
	for jid in EconUtil.sorted_keys(jt):
		var j: Dictionary = jt[jid].duplicate()
		j["capacity"] = junction_capacity(world, jt[jid])
		j["risk"] = int(JUNCTION_RISK[String(j["type"])])
		js.append(j)
	return {"nodes": nodes(world), "links": ls, "junctions": js}


static func link_km(l: Dictionary) -> int:
	if int(l.get("globe", 0)) == 1:
		return maxi(0, l["cells"].size() - 1) * KM_PER_HEX
	return _path_km(l["path"])


## Route between two nodes by a mode: "ROAD" (the built network), "ROVER", "AIRSHIP" or "BEST" (road, else rover,
## else airship). → {ok, mode, time_days, time_h, km, cost_index, links: [lid], reason}. ignore_weather: the usual
## route (closures and groundings left out).
static func route(world: WorldState, from_id: String, to_id: String, mode: String = "BEST", ignore_weather: bool = false) -> Dictionary:
	if mode == "BEST":   # the cheapest kind of trip that works; on failure, why the road does not
		var first := {}
		for m in ["ROAD", "ROVER", "AIRSHIP"]:
			var r := route(world, from_id, to_id, m, ignore_weather)
			if r["ok"]:
				return r
			if first.is_empty():
				first = r
		return first
	var a := node(world, from_id)
	var b := node(world, to_id)
	if a.is_empty() or b.is_empty():
		return _fail(mode, "UNKNOWN_NODE")
	match mode:
		"ROAD":
			return _road_route(world, a, b, ignore_weather)
		"ROVER":
			return _rover_route(world, a, b, ignore_weather)
		"AIRSHIP":
			return _air_route(world, a, b, ignore_weather)
	return _fail(mode, "UNKNOWN_MODE")


static func _fail(mode: String, why: String) -> Dictionary:
	return {"ok": false, "mode": mode, "time_days": 0, "time_h": 0, "km": 0, "cost_index": 0, "links": [], "reason": why}


static func _ok(mode: String, km_x10: int, hours: int, cost: int, links: Array) -> Dictionary:
	return {"ok": true, "mode": mode, "time_days": maxi(1, ceili(float(hours) / 24.0)) if hours > 0 else 0, "time_h": hours,
		"km": km_x10 / 10, "cost_index": cost, "links": links, "reason": ""}


## Over the built network: colony links (tile graph) and, to a globe site, the globe road from the port.
static func _road_route(world: WorldState, a: Dictionary, b: Dictionary, ignore_weather: bool) -> Dictionary:
	if int(b["tile"]) < 0:   # a globe site: to the port, then the globe road
		var gl := {}
		var links := _links(world)
		for lid in EconUtil.sorted_keys(links):
			var l: Dictionary = links[lid]
			if int(l.get("globe", 0)) == 1 and String(l.get("site", "")) == String(b["id"]):
				gl = l
				break
		if gl.is_empty():
			return _fail("ROAD", "NO_LINK")
		if not ignore_weather and closed_reason(world, gl) != "":
			return _fail("ROAD", "CLOSED")
		var first := _road_route(world, a, node(world, "port"), ignore_weather) if a["id"] != "port" else _ok("ROAD", 0, 0, 0, [])
		if not first["ok"]:
			return first
		var k := effective_kind(gl)
		var km := link_km(gl)
		var hrs: int = int(first["time_h"]) + roundi(24.0 * km / _speed(k, int(gl["cond"])))
		return _ok("ROAD", int(first["km"]) * 10 + km * 10, hrs, int(first["cost_index"]) + _cost(k, int(gl["cond"]), km * 10),
			first["links"] + [gl["id"]])
	if int(a["tile"]) < 0:
		return _road_route(world, b, a, ignore_weather)   # symmetric
	return _tile_route(world, a, b, ignore_weather)


static func _speed(kind: String, cond: int) -> float:
	return float(SPEED[kind]) * (0.5 + 0.5 * clampf(float(cond) / 1000.0, 0.0, 1.0))


## cost_index for km_x10 tenths of a km on a link kind in a condition.
static func _cost(kind: String, cond: int, km_x10: int) -> int:
	return roundi(float(COST[kind]) * float(km_x10) / 1000.0 * (1.5 - 0.5 * clampf(float(cond) / 1000.0, 0.0, 1.0)))


## Dijkstra over the colony graph. Vertices: link tiles (ints) and nodes (negative ids). Edges: consecutive tiles of
## open links; a settlement's streets to the link tiles and nodes inside its town; any other node to link tiles
## next to it (an access lane).
static func _tile_route(world: WorldState, a: Dictionary, b: Dictionary, ignore_weather: bool) -> Dictionary:
	if a["id"] == b["id"] or (String(a["town"]) != "" and a["town"] == b["town"]):
		var km_x10 := roundi(Vector2(int_tile(int(a["tile"]))).distance_to(Vector2(int_tile(int(b["tile"])))) * KM_PER_TILE * 10.0)
		return _ok("ROAD", km_x10, roundi(24.0 * km_x10 / 10.0 / SPEED["STREET"]), _cost("STREET", 1000, km_x10), [])
	var g := _graph(world, ignore_weather)
	var adj: Dictionary = g["adj"]
	var setl := ColonyLayout.settlements(world)
	var towns := {}
	for s in setl:
		towns[s["id"]] = s["tiles"]
	# attach the two end nodes: to link tiles in their town (streets) or right next to them (access lane)
	var starts := _attach(a, adj, towns)
	var goals := _attach(b, adj, towns)
	if starts.is_empty() or goals.is_empty():
		if not ignore_weather and _tile_route(world, a, b, true)["ok"]:
			return _fail("ROAD", "CLOSED")
		return _fail("ROAD", "OFF_NETWORK_FROM" if starts.is_empty() else "OFF_NETWORK_TO")
	var best := {}   # vertex -> [hours_x100, prev, edge lid, km_x10, cost]
	var heap: Array = []
	var keymap: Array = []   # heap holds ints: hours_x100 << 20 | index into keymap
	for v in starts:
		var e: Array = starts[v]
		best[v] = [e[0], null, "", e[1], e[2]]
		keymap.append(v)
		_hpush(heap, (int(e[0]) << 20) | (keymap.size() - 1))
	var done := {}
	var reached = null
	var reached_t := 0x7fffffff
	while not heap.is_empty():
		var top: int = _hpop(heap)
		var v = keymap[top & 0xfffff]
		var t: int = top >> 20
		if done.has(v) or t > int(best[v][0]):
			continue
		done[v] = true
		if goals.has(v):
			var total: int = t + int(goals[v][0])
			if total < reached_t:
				reached_t = total
				reached = v
		if t > reached_t:
			break
		for e in adj.get(v, []):   # e = [to, hours_x100, lid, km_x10, cost]
			var nt: int = t + int(e[1])
			if not best.has(e[0]) or nt < int(best[e[0]][0]):
				best[e[0]] = [nt, v, e[2], e[3], e[4]]
				keymap.append(e[0])
				_hpush(heap, (nt << 20) | (keymap.size() - 1))
	if reached == null:
		return _fail("ROAD", "CLOSED" if not ignore_weather and _tile_route(world, a, b, true)["ok"] else "NO_ROUTE")
	var lids: Array = []
	var km := int(goals[reached][1])
	var cost := int(goals[reached][2])
	var cur = reached
	while cur != null:
		var rec: Array = best[cur]
		if String(rec[2]) != "" and not (rec[2] in lids):
			lids.append(rec[2])
		km += int(rec[3])
		cost += int(rec[4])
		cur = rec[1]
	lids.reverse()
	return _ok("ROAD", km, roundi(float(reached_t) / 100.0), cost, lids)


## Start or goal edges for a node: {vertex: [hours_x100, km_x10, cost]}.
static func _attach(n: Dictionary, adj: Dictionary, towns: Dictionary) -> Dictionary:
	var out := {}
	var t := int_tile(int(n["tile"]))
	var town: Array = towns.get(String(n["town"]), [])
	for v in adj:
		var vt := int_tile(int(v))
		var d := Vector2(vt).distance_to(Vector2(t))
		var ok := d <= 1.5 or vt in town
		if ok:
			var km_x10 := roundi(d * KM_PER_TILE * 10.0)
			out[v] = [roundi(2400.0 * km_x10 / 10.0 / SPEED["STREET"]), km_x10, _cost("STREET", 1000, km_x10)]
	return out


## The colony tile graph of open links: {adj: {tile: [[to, hours_x100, lid, km_x10, cost], ...]}}.
static func _graph(world: WorldState, ignore_weather: bool) -> Dictionary:
	return _memoised(world, "graph%d" % int(ignore_weather), func(): return _build_graph(world, ignore_weather))


static func _build_graph(world: WorldState, ignore_weather: bool) -> Dictionary:
	var adj := {}
	var links := _links(world)
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		if not ignore_weather and closed_reason(world, l) != "":
			continue
		var k := effective_kind(l)
		var sp := _speed(k, int(l["cond"]))
		var p: Array = l["path"]
		for i in range(1, p.size()):
			var u := int(p[i - 1])
			var v := int(p[i])
			var diag := int_tile(u).x != int_tile(v).x and int_tile(u).y != int_tile(v).y
			var km_x10 := (42 if diag else 30)
			var e_h := roundi(2400.0 * km_x10 / 10.0 / sp)
			var c := _cost(k, int(l["cond"]), km_x10)
			if not adj.has(u):
				adj[u] = []
			if not adj.has(v):
				adj[v] = []
			adj[u].append([v, e_h, lid, km_x10, c])
			adj[v].append([u, e_h, lid, km_x10, c])
	return {"adj": adj}


## Rovers: by road to a rover base (or from one), then off-road: anywhere on the colony map, or a land hex within
## ROVER_RANGE_HEX of the colony (no sea crossing). Storms of 3+ stop them.
static func _rover_route(world: WorldState, a: Dictionary, b: Dictionary, ignore_weather: bool) -> Dictionary:
	var base := _base_for(world, a, "ROVER_BASE", ignore_weather)
	if base.is_empty():
		return _fail("ROVER", "NO_BASE")
	if not ignore_weather and _storm(world, Planet.landing(world)) >= 3:
		return _fail("ROVER", "STORM")
	var leg: Dictionary = base["leg"]
	var km := 0
	if int(b["tile"]) >= 0:
		km = roundi(Vector2(int_tile(int(base["tile"]))).distance_to(Vector2(int_tile(int(b["tile"])))) * KM_PER_TILE * 1.3)
	else:
		var steps := _land_steps(world, Planet.landing(world), int(b["cell"]), ROVER_RANGE_HEX)
		if steps < 0:
			return _fail("ROVER", "OUT_OF_RANGE")
		if not ignore_weather and _storm(world, int(b["cell"])) >= 3:
			return _fail("ROVER", "STORM")
		km = steps * KM_PER_HEX
	var hrs: int = int(leg["time_h"]) + roundi(24.0 * km / SPEED["ROVER"])
	return _ok("ROVER", int(leg["km"]) * 10 + km * 10, hrs, int(leg["cost_index"]) + _cost("ROVER", 1000, km * 10), leg["links"])


## Airships: by road to a mast, then straight to any site or node within AIRSHIP_RANGE_HEX. Grounded by storms of
## 2+ at the mast's hex or the destination.
static func _air_route(world: WorldState, a: Dictionary, b: Dictionary, ignore_weather: bool) -> Dictionary:
	var base := _base_for(world, a, "MAST", ignore_weather)
	if base.is_empty():
		return _fail("AIRSHIP", "NO_BASE")
	var home := Planet.landing(world)
	if not ignore_weather and (_storm(world, home) >= 2 or _storm(world, int(b["cell"])) >= 2):
		return _fail("AIRSHIP", "GROUNDED")
	var km := 0
	if int(b["tile"]) >= 0:
		km = roundi(Vector2(int_tile(int(base["tile"]))).distance_to(Vector2(int_tile(int(b["tile"])))) * KM_PER_TILE)
	else:
		var cs: PackedVector3Array = Planet.geometry(Planet.freq(world))["centers"]
		var ang := cs[home].angle_to(cs[int(b["cell"])])
		km = roundi(ang * PlanetSites.RADIUS_KM)
		if km > AIRSHIP_RANGE_HEX * KM_PER_HEX:
			return _fail("AIRSHIP", "OUT_OF_RANGE")
	var leg: Dictionary = base["leg"]
	var hrs: int = int(leg["time_h"]) + roundi(24.0 * km / SPEED["AIRSHIP"])
	return _ok("AIRSHIP", int(leg["km"]) * 10 + km * 10, hrs, int(leg["cost_index"]) + _cost("AIRSHIP", 1000, km * 10), leg["links"])


## The nearest base of a kind that `a` can reach by road: {tile, leg (the road route to it)}; {} if none.
static func _base_for(world: WorldState, a: Dictionary, kind: String, ignore_weather: bool) -> Dictionary:
	var best := {}
	var bases := _bases(world)
	for bid in EconUtil.sorted_keys(bases):
		if bases[bid]["kind"] != kind:
			continue
		var leg := _ok("ROAD", 0, 0, 0, []) if a["id"] == bid else _road_route(world, a, node(world, bid), ignore_weather)
		if leg["ok"] and (best.is_empty() or int(leg["time_h"]) < int(best["leg"]["time_h"])):
			best = {"tile": int(bases[bid]["tile"]), "leg": leg}
	return best


## Land steps between two hexes (BFS over land, at most `limit`); -1 if farther or across the sea.
static func _land_steps(world: WorldState, from: int, to: int, limit: int) -> int:
	if from == to:
		return 0
	var seen := {from: true}
	var frontier: Array = [from]
	for step in range(1, limit + 1):
		var nxt: Array = []
		for c in frontier:
			for j in Planet.neighbors(world, c):
				if seen.has(j) or Planet.is_water(world, j):
					continue
				if j == to:
					return step
				seen[j] = true
				nxt.append(j)
		frontier = nxt
	return -1


## Tourist sites and how tourists get there from the port this month:
## [{id, name, where, mode: ROAD|ROVER|AIRSHIP|UNREACHABLE, usual (the mode in fair weather), time_days, km,
##   cost_index, reason}].
static func reachable_sites(world: WorldState) -> Array:
	var out: Array = []
	for st in PlanetSites.sites(world):
		var r := route(world, "port", st["id"], "BEST")
		var u := r if r["ok"] else route(world, "port", st["id"], "BEST", true)
		out.append({"id": st["id"], "name": st["name"], "where": st["where"], "mode": r["mode"] if r["ok"] else "UNREACHABLE",
			"usual": u["mode"] if u["ok"] else "UNREACHABLE", "time_days": int(r["time_days"]), "km": int(r["km"]),
			"cost_index": int(r["cost_index"]), "reason": String(r["reason"])})
	return out


# ================================================================== building (plan pure, complete writes)

## What a link job would take: spec {"a": tile, "b": tile, "kind"} (new), {"upgrade": lid}, {"repair": lid} or
## {"site": site_id, "kind"} (a globe road from the colony to a REGION tourist site).
## → {ok, error, job: NEW|UPGRADE|REPAIR|GLOBE, kind, path | cells, km, bridges, wu, mat, comp, months, cost}.
## wu/mat/comp are EconData.BUILD units (Bob multiplies by S); cost is in EconConstruction.estimate units.
static func plan_link(world: WorldState, spec: Dictionary) -> Dictionary:
	var links := _links(world)
	var out := {"ok": false, "error": "", "job": "", "kind": "", "path": [], "cells": [], "km": 0, "bridges": 0,
		"wu": 0, "mat": 0, "comp": 0, "months": 0, "cost": 0}
	var bill := [0, 0, 0]
	if spec.has("upgrade") or spec.has("repair"):
		var lid := String(spec.get("upgrade", spec.get("repair", "")))
		if not links.has(lid):
			out["error"] = "Unknown link '%s'" % lid
			return out
		var l: Dictionary = links[lid]
		var globe := int(l.get("globe", 0)) == 1
		var kind := String(l["kind"])
		if spec.has("upgrade"):
			var i := KINDS.find(kind)
			if i >= KINDS.size() - 1:
				out["error"] = "Already a paved road: it can only be repaired"
				return out
			kind = KINDS[i + 1]
			out["job"] = "UPGRADE"
		else:
			if int(l["cond"]) >= 950:
				out["error"] = "The %s is in good repair (%d%%)" % [KIND_NAMES[kind], int(l["cond"]) / 10]
				return out
			out["job"] = "REPAIR"
		bill = _globe_bill(kind, l["cells"].size() - 1) if globe else _tile_bill(world, kind, l["path"])
		if out["job"] == "UPGRADE":
			var was := _globe_bill(String(l["kind"]), l["cells"].size() - 1) if globe else _tile_bill(world, String(l["kind"]), l["path"])
			bill = [maxi(bill[0] - was[0] / 2, 1), maxi(bill[1] - was[1] / 2, 0), maxi(bill[2] - was[2] / 2, 0)]
		else:
			var worn := 1000 - int(l["cond"])
			bill = [maxi(1, bill[0] * worn / 3000), bill[1] * worn / 3000, bill[2] * worn / 3000]
		out["kind"] = kind
		out["km"] = link_km(l)
		if globe:
			out["cells"] = l["cells"].duplicate()
		else:
			out["path"] = l["path"].duplicate()
			out["bridges"] = int(l["bridges"])
	elif spec.has("lanes") or spec.has("bridge"):
		var lid2 := String(spec.get("lanes", spec.get("bridge", "")))
		if not links.has(lid2) or int(links[lid2].get("globe", 0)) == 1:
			out["error"] = "Unknown link '%s' (lanes and bridges are for links on the colony map)" % lid2
			return out
		var l2: Dictionary = links[lid2]
		var k2 := String(l2["kind"])
		if spec.has("lanes"):
			if int(l2.get("lanes", 1)) >= 2:
				out["error"] = "The %s already has two lanes" % KIND_NAMES[k2]
				return out
			if k2 == "TRACK":
				out["error"] = "A dirt track gets no second lane: make it a road first"
				return out
			var full := _tile_bill(world, k2, l2["path"].filter(func(ti): return Terrain.at(world, int(ti) % Terrain.W, int(ti) / Terrain.W) != "r"))
			bill = [maxi(1, full[0] * LANE_SHARE / 100), full[1] * LANE_SHARE / 100, full[2] * LANE_SHARE / 100]
			out["job"] = "LANES"
		else:
			if int(l2["bridges"]) <= 0:
				out["error"] = "This %s crosses no river" % KIND_NAMES[k2]
				return out
			if int(l2.get("bridge_lanes", 1)) >= 2:
				out["error"] = "This crossing already has a second bridge"
				return out
			bill = _bridge_bill(k2, l2.get("spans", spans(world, l2["path"])))
			out["job"] = "BRIDGE"
		out["kind"] = k2
		out["km"] = link_km(l2)
		out["path"] = l2["path"].duplicate()
		out["bridges"] = int(l2["bridges"])
	elif spec.has("junction"):
		var js := junctions(world)
		var jid := String(spec["junction"])
		var to := String(spec.get("type", ""))
		if not js.has(jid):
			out["error"] = "Unknown junction '%s'" % jid
			return out
		if not to in BILL_JUNCTION:
			out["error"] = "A junction can become PRIORITY, ROUNDABOUT or SIGNALS"
			return out
		if String(js[jid]["type"]) == to:
			out["error"] = "It already is a %s" % JUNCTION_NAMES[to]
			return out
		bill = BILL_JUNCTION[to].duplicate()
		out["job"] = "JUNCTION"
		out["kind"] = to
		out["path"] = [int(js[jid]["tile"])]
		out["needs_power"] = to == "SIGNALS"
	elif spec.has("site"):
		var st := PlanetSites.site(world, String(spec["site"]))
		var kind2 := String(spec.get("kind", "TRACK"))
		if not kind2 in KINDS:
			out["error"] = "Unknown road kind '%s' (TRACK, ROAD or PAVED)" % kind2
			return out
		if st.is_empty():
			out["error"] = "Unknown site '%s'" % str(spec["site"])
			return out
		if st["where"] == "COLONY":
			out["error"] = "%s is on the colony map: build a link to its tile" % st["name"]
			return out
		if st["where"] != "REGION":
			out["error"] = "%s is %d km away, too far for a road: rovers or airships only" % [st["name"], int(st["km"])]
			return out
		for lid in links:
			if String(links[lid].get("site", "")) == String(st["id"]):
				out["error"] = "%s already has a road: upgrade it instead" % st["name"]
				return out
		var cells := land_path(world, Planet.landing(world), int(st["cell"]))
		if cells.is_empty():
			out["error"] = "No land route to %s: the sea is in the way (airships only)" % st["name"]
			return out
		out["job"] = "GLOBE"
		out["kind"] = kind2
		out["cells"] = cells
		out["km"] = (cells.size() - 1) * KM_PER_HEX
		bill = _globe_bill(kind2, cells.size() - 1)
	else:
		var kind3 := String(spec.get("kind", "TRACK"))
		if not kind3 in KINDS:
			out["error"] = "Unknown road kind '%s' (TRACK, ROAD or PAVED)" % kind3
			return out
		if not (spec.has("a") and spec.has("b")):
			out["error"] = "A new link needs two ends (a, b)"
			return out
		var a := int_tile(int(spec["a"]))
		var b := int_tile(int(spec["b"]))
		if Terrain.at(world, a.x, a.y) == "" or Terrain.at(world, b.x, b.y) == "":
			out["error"] = "An end lies off the colony map"
			return out
		if a == b or Vector2(a).distance_to(Vector2(b)) < 1.5:
			out["error"] = "The two ends are too close: a link needs at least two tiles"
			return out
		var avoid := {}
		if spec.has("avoid"):   # a bypass: keep clear of the old link's inner tiles
			var old: Dictionary = links.get(String(spec["avoid"]), {})
			if old.is_empty() or int(old.get("globe", 0)) == 1:
				out["error"] = "Unknown link to bypass '%s'" % str(spec["avoid"])
				return out
			for ti in old["path"].slice(1, old["path"].size() - 1):
				avoid[int(ti)] = true
		var path := plan_path(world, a, b, {}, avoid)
		if path.is_empty():
			out["error"] = "No path between the two ends"
			return out
		if not avoid.is_empty():
			var shared := path.filter(func(ti): return avoid.has(int(ti))).size()
			if shared * 2 > avoid.size():
				out["error"] = "No way around: the land leaves no room for a bypass"
				return out
		out["job"] = "NEW"
		out["kind"] = kind3
		out["path"] = path
		out["km"] = _path_km(path)
		out["bridges"] = _colony_link("", kind3, path, world, 0)["bridges"]
		bill = _tile_bill(world, kind3, path)
	out["ok"] = true
	out["wu"] = int(bill[0])
	out["mat"] = int(bill[1])
	out["comp"] = int(bill[2])
	out["months"] = clampi(int(bill[0]) / 100 + 1, 2, 36)
	out["cost"] = int((float(bill[0]) * EconData.WU_COST_EST + float(bill[1]) * EconData.BASE_PRICE["MATERIAL"]
		+ float(bill[2]) * EconData.BASE_PRICE["COMPONENT"]) * 1.15) * EconUtil.S
	return out


static func _tile_bill(world: WorldState, kind: String, path: Array) -> Array:
	var b := [0, 0, 0]
	for ti in path:
		var code := Terrain.at(world, int(ti) % Terrain.W, int(ti) / Terrain.W)
		if code == "r":
			continue
		var row: Array = BILL_TILE[kind]
		b[0] += int(row[0]) * int(TERRAIN_WU.get(code, 10)) / 10
		b[1] += int(row[1])
		b[2] += int(row[2])
	var br := _bridge_bill(kind, spans(world, path))
	return [b[0] + br[0], b[1] + br[1], b[2] + br[2]]


## Bridges priced by span: a span of n water tiles costs n tiles × (1 + SPAN_EXTRA% × (n - 1)).
static func _bridge_bill(kind: String, sp: Array) -> Array:
	var row: Array = BILL_BRIDGE[kind]
	var b := [0, 0, 0]
	for x in sp:
		var n := int(x[1])
		var f := 100 + SPAN_EXTRA * (n - 1)
		for k in 3:
			b[k] += int(row[k]) * n * f / 100
	return b


static func _globe_bill(kind: String, hexes: int) -> Array:
	var row: Array = BILL_HEX[kind]
	return [int(row[0]) * hexes, int(row[1]) * hexes, int(row[2]) * hexes]


## Readable reason a link job cannot be commissioned ("" = fine). Pure.
static func validate_link(world: WorldState, spec: Dictionary) -> String:
	return String(plan_link(world, spec)["error"])


## Shortest land hex path from one hex to another ([cells], both included; [] if none within 12 steps).
static func land_path(world: WorldState, from: int, to: int) -> Array:
	var prev := {from: -1}
	var frontier: Array = [from]
	for _s in 12:
		var nxt: Array = []
		for c in frontier:
			for j in Planet.neighbors(world, c):
				if prev.has(j) or (Planet.is_water(world, j) and j != to):
					continue
				prev[j] = c
				if j == to:
					var path: Array = [to]
					var cur: int = c
					while cur != -1:
						path.append(cur)
						cur = int(prev[cur])
					path.reverse()
					return path
				nxt.append(j)
		frontier = nxt
	return []


## A ROAD project is done (Bob's EconConstruction._complete): build, upgrade or repair, and return the link id ("" if
## nothing could be done). Without p["link"], the most useful job in the project's district (auto_job).
static func complete_road(world: WorldState, p: Dictionary) -> String:
	ensure(world)
	var spec: Dictionary = p.get("link", {})
	if spec.is_empty():
		spec = auto_job(world, String(p.get("district", "")))
		if spec.is_empty():
			return ""
	var plan := plan_link(world, spec)
	if not plan["ok"]:
		return ""
	var links: Dictionary = world.table("transport")["links"]
	var lid := ""
	match String(plan["job"]):
		"NEW":
			lid = _new_id(world)
			links[lid] = _colony_link(lid, String(plan["kind"]), plan["path"], world, world.month)
		"GLOBE":
			lid = _new_id(world)
			links[lid] = {"id": lid, "kind": String(plan["kind"]), "cells": plan["cells"].duplicate(), "site": String(spec["site"]),
				"cond": 1000, "traffic": 0, "built": world.month, "globe": 1}
		"UPGRADE":
			lid = String(spec["upgrade"])
			links[lid]["kind"] = String(plan["kind"])
			links[lid]["cond"] = 1000
		"REPAIR":
			lid = String(spec["repair"])
			links[lid]["cond"] = 1000
		"LANES":
			lid = String(spec["lanes"])
			links[lid]["lanes"] = 2
		"BRIDGE":
			lid = String(spec["bridge"])
			links[lid]["bridge_lanes"] = 2
		"JUNCTION":
			var jid := String(spec["junction"])
			world.table("transport")["junctions"][jid]["type"] = String(plan["kind"])
			_bump(world)
			world.add_fact({"type": "TRANSPORT_JUNCTION_REBUILT", "owner": "transport", "subjects": [],
				"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}] if p.get("owner", "gov") == "gov" else [],
				"impact": {"INFRASTRUCTURE": 3}, "magnitude": 20, "visibility": "PUBLIC",
				"data": {"junction": jid, "type": String(plan["kind"]), "district": String(p.get("district", "")), "project": String(p.get("id", ""))}})
			return jid
	var tt := world.table("transport")
	tt["junctions"] = _derive_junctions(links, tt.get("junctions", {}))
	_bump(world)
	var l: Dictionary = links[lid]
	var ftype := "TRANSPORT_LINK_OPENED" if plan["job"] in ["NEW", "GLOBE"] else ("TRANSPORT_LINK_REPAIRED" if plan["job"] == "REPAIR" else "TRANSPORT_LINK_UPGRADED")
	world.add_fact({"type": ftype, "owner": "transport", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}] if p.get("owner", "gov") == "gov" else [],
		"impact": {"INFRASTRUCTURE": 4 if plan["job"] != "REPAIR" else 2}, "magnitude": 25 if plan["job"] != "REPAIR" else 10,
		"visibility": "PUBLIC", "data": {"link": lid, "job": String(plan["job"]), "kind": String(l["kind"]), "lanes": int(l.get("lanes", 1)), "km": link_km(l), "site": String(l.get("site", "")),
			"district": String(p.get("district", "")), "project": String(p.get("id", "")), "serves": _serves(world, l)}})
	return lid


## Names of the nodes a link brings onto the network (news lines).
static func _serves(world: WorldState, l: Dictionary) -> Array:
	var out: Array = []
	if int(l.get("globe", 0)) == 1:
		var st := PlanetSites.site(world, String(l["site"]))
		return [String(st.get("name", l["site"]))]
	var ends: Array = [int_tile(int(l["path"][0])), int_tile(int(l["path"][-1]))]
	var setl := ColonyLayout.settlements(world)
	for n in nodes(world):
		if int(n["tile"]) < 0:
			continue
		var t := int_tile(int(n["tile"]))
		for e in ends:
			if Vector2(t).distance_to(Vector2(e)) <= 1.5 or (String(n["town"]) != "" and e in _town_tiles(setl, String(n["town"]))):
				if not String(n["name"]) in out and n["kind"] in ["SETTLEMENT", "SITE", "PLANT"]:
					out.append(String(n["name"]))
	return out.slice(0, 4)


static func _town_tiles(setl: Array, id: String) -> Array:
	for s in setl:
		if s["id"] == id:
			return s["tiles"]
	return []


## The most useful road job in a district (GovBuilder's district roads): a link for a plant off the network, else
## repair the worst link below 60%, else upgrade the busiest track, else repair the worst link. {} = nothing to do.
## Tourist sites are never linked automatically (opening nature to tourism is a political choice: T6).
static func auto_job(world: WorldState, district: String) -> Dictionary:
	var links := _links(world)
	var setl := ColonyLayout.settlements(world)
	var mine := func(t: Vector2i) -> bool:
		if district == "":
			return true
		var best := ""
		var bd := INF
		for s in setl:
			var d := Vector2(s["tile"]).distance_to(Vector2(t))
			if d < bd:
				bd = d
				best = String(s["district"])
		return best == district
	for n in nodes(world):
		if n["kind"] != "PLANT" or not mine.call(int_tile(int(n["tile"]))):
			continue
		if _road_route(world, n, node(world, "port"), true)["ok"]:
			continue
		var t := int_tile(int(n["tile"]))
		var near := _nearest_link_tile(world, links, t)
		if near.x >= 0:
			return {"a": tile_int(near), "b": int(n["tile"]), "kind": "TRACK"}
	var worst := ""
	var busiest := ""
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1 or not mine.call(int_tile(int(l["path"][l["path"].size() / 2]))):
			continue
		if worst == "" or int(l["cond"]) < int(links[worst]["cond"]):
			worst = lid
		if l["kind"] == "TRACK" and (busiest == "" or int(l["traffic"]) > int(links[busiest]["traffic"])):
			busiest = lid
	if worst != "" and int(links[worst]["cond"]) < 600:
		return {"repair": worst}
	# T7: the busiest bottleneck first (above 80% of capacity): a junction, a bridge, a second lane
	var jt := junctions(world)
	for jid in EconUtil.sorted_keys(jt):
		var j: Dictionary = jt[jid]
		var ji: int = JUNCTION_TYPES.find(String(j["type"]))
		if mine.call(int_tile(int(j["tile"]))) and ji < 2 and int(j["traffic"]) * 10 > junction_capacity(world, j) * 8:
			return {"junction": jid, "type": "ROUNDABOUT" if ji == 1 or int(j["branches"]) >= 4 else "PRIORITY"}
	for lid3 in EconUtil.sorted_keys(links):
		var l3: Dictionary = links[lid3]
		if int(l3.get("globe", 0)) == 1 or not mine.call(int_tile(int(l3["path"][l3["path"].size() / 2]))):
			continue
		if int(l3["traffic"]) * 10 > link_capacity(l3) * 8:
			if int(l3["bridges"]) > 0 and int(l3.get("bridge_lanes", 1)) < 2 and int(l3.get("lanes", 1)) == 2:
				return {"bridge": lid3}
			if l3["kind"] != "TRACK" and int(l3.get("lanes", 1)) == 1:
				return {"lanes": lid3}
	if busiest != "":
		return {"upgrade": busiest}
	if worst != "" and int(links[worst]["cond"]) < 950:
		return {"repair": worst}
	for lid2 in EconUtil.sorted_keys(links):   # all good: upgrade the district's first road that can still go up
		var l2: Dictionary = links[lid2]
		if int(l2.get("globe", 0)) == 0 and l2["kind"] != "PAVED" and mine.call(int_tile(int(l2["path"][l2["path"].size() / 2]))):
			return {"upgrade": lid2}
	return {}


static func _nearest_link_tile(world: WorldState, links: Dictionary, t: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		for ti in l["path"]:
			var v := int_tile(int(ti))
			var d := Vector2(v).distance_to(Vector2(t))
			if d < bd:
				bd = d
				best = v
	return best


# ================================================================== monthly (NATURE) and other writes

## Wear: every link loses condition with age, traffic above capacity and storms over it. Traffic resets each month.
## Closed links are reported (one fact a month). Called from PlanetProvider in TickPhase.NATURE.
static func step_month(world: WorldState) -> void:
	if not Terrain.ready(world):
		return
	ensure(world)
	_replan_crossings(world)
	var links: Dictionary = world.table("transport")["links"]
	var home := Planet.landing(world)
	var s_home := _storm(world, home)
	var closed := 0
	var reasons := {}
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		var k := String(l["kind"])
		var s := s_home
		if int(l.get("globe", 0)) == 1:
			s = 0
			for c in l["cells"]:
				s = maxi(s, _storm(world, int(c)))
		var cap := link_capacity(l)
		var over := maxi(0, int(l["traffic"]) - cap) * 10 / maxi(1, cap)
		l["cond"] = clampi(int(l["cond"]) - int(WEAR[k]) - over - int(STORM_WEAR[k]) * s, 0, 1000)
		l["traffic"] = 0
		var why := closed_reason(world, l)
		if why != "":
			closed += 1
			reasons[why] = true
	var jt: Dictionary = world.table("transport").get("junctions", {})
	for jid in jt:
		jt[jid]["traffic"] = 0
	if posmod(world.month, 12) == 0:   # accident counts are "recent": they halve every year
		for lid2 in links:
			links[lid2]["acc"] = int(links[lid2].get("acc", 0)) / 2
		for jid2 in jt:
			jt[jid2]["acc"] = int(jt[jid2].get("acc", 0)) / 2
	_bump(world)
	if closed > 0:
		world.add_fact({"type": "TRANSPORT_LINKS_CLOSED", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
			"magnitude": clampi(10 + closed * 5, 0, 60), "visibility": "PUBLIC",
			"data": {"links": closed, "reasons": EconUtil.sorted_keys(reasons)}})


## Freight or passengers used a link or a junction this month (T2/T3/T7: the route's links, and the junctions on
## them: route_junctions). Wear grows above capacity. Counts reset in the next NATURE tick.
static func add_traffic(world: WorldState, id: String, units: int) -> void:
	ensure(world)
	var t := world.table("transport")
	if t["links"].has(id):
		t["links"][id]["traffic"] = int(t["links"][id]["traffic"]) + maxi(0, units)
	elif t.get("junctions", {}).has(id):
		t["junctions"][id]["traffic"] = int(t["junctions"][id]["traffic"]) + maxi(0, units)


## An accident on a link or at a junction (Bob, T7). "acc" counts recent accidents (halved every year).
static func add_accident(world: WorldState, id: String, n: int = 1) -> void:
	ensure(world)
	var t := world.table("transport")
	if t["links"].has(id):
		t["links"][id]["acc"] = int(t["links"][id].get("acc", 0)) + n
	elif t.get("junctions", {}).has(id):
		t["junctions"][id]["acc"] = int(t["junctions"][id].get("acc", 0)) + n


## Junctions a route passes (for counting traffic there): ids, in no particular order.
static func route_junctions(world: WorldState, r: Dictionary) -> Array:
	var out: Array = []
	var links := _links(world)
	var jt := junctions(world)
	var on := {}
	for lid in r.get("links", []):
		if links.has(lid) and int(links[lid].get("globe", 0)) == 0:
			for ti in links[lid]["path"]:
				on[int(ti)] = true
	for jid in EconUtil.sorted_keys(jt):
		if on.has(int(jt[jid]["tile"])):
			out.append(jid)
	return out


## A rover base or airship mast at a tile (T4: operators). Returns its id.
static func add_base(world: WorldState, kind: String, tile: int, owner: String) -> String:
	assert(kind in ["ROVER_BASE", "MAST"], "base kind ROVER_BASE or MAST")
	ensure(world)
	var t := world.table("transport")
	t["seq"] = int(t.get("seq", 0)) + 1
	var bid := "base:%d" % int(t["seq"])
	t["bases"][bid] = {"id": bid, "kind": kind, "tile": tile, "owner": owner}
	_bump(world)
	return bid


static func remove_base(world: WorldState, bid: String) -> void:
	world.table("transport").get("bases", {}).erase(bid)
	_bump(world)


# ================================================================== T7: fixes on offer (Anni's engineers)

## Every fix the network offers, keyed like Bob's traffic counts: "LINK:<lid>" and "NODE:<jid>".
## {key: {options: [{fix, cost, months, cap_pm, acc_pm, spec}]}}. Pure, current with the network.
##   fix: ROAD (track → road), PAVE (road → paved), LANES_2, BRIDGE_2 (a second bridge), BYPASS (a new road around
##        the link), PRIORITY, ROUNDABOUT, SIGNALS (junctions)
##   cost: Bob's money units (credits × S, as EconConstruction.estimate); months: build time
##   cap_pm: capacity after / before, ‰; acc_pm: accident risk per trip after / before, ‰
##   spec: the ROAD project's "link" params that order this fix (ECON_COMMISSION_PROJECT {type: "ROAD", link: spec})
static func traffic_fixes(world: WorldState) -> Dictionary:
	return _memoised(world, "fixes", func(): return _traffic_fixes(world))


## The project params for one fix ({} if that fix is not on offer).
static func fix_spec(world: WorldState, key: String, fix: String) -> Dictionary:
	for o in traffic_fixes(world).get(key, {}).get("options", []):
		if o["fix"] == fix:
			return o["spec"]
	return {}


static func _traffic_fixes(world: WorldState) -> Dictionary:
	var out := {}
	var links := _links(world)
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		var opts: Array = []
		var k := String(l["kind"])
		var globe := int(l.get("globe", 0)) == 1
		if k != "PAVED":
			opts.append(_fix_option(world, "ROAD" if k == "TRACK" else "PAVE", {"upgrade": lid}, l,
				func(x): x["kind"] = KINDS[KINDS.find(k) + 1]; x["cond"] = 1000, 700 if k == "TRACK" else 800))
		if not globe and k != "TRACK" and int(l.get("lanes", 1)) == 1:
			opts.append(_fix_option(world, "LANES_2", {"lanes": lid}, l, func(x): x["lanes"] = 2, 850))
		if not globe and int(l["bridges"]) > 0 and int(l.get("bridge_lanes", 1)) == 1 and int(l.get("lanes", 1)) == 2:
			opts.append(_fix_option(world, "BRIDGE_2", {"bridge": lid}, l, func(x): x["bridge_lanes"] = 2, 900))
		if not globe and k != "TRACK" and l["path"].size() >= 6:
			var spec := {"a": int(l["path"][0]), "b": int(l["path"][-1]), "kind": "ROAD", "avoid": lid}
			var plan := plan_link(world, spec)
			if plan["ok"]:
				var cap0 := link_capacity(l)
				opts.append({"fix": "BYPASS", "cost": int(plan["cost"]), "months": int(plan["months"]),
					"cap_pm": (cap0 + int(CAPACITY["ROAD"])) * 1000 / maxi(1, cap0), "acc_pm": 600, "spec": spec})
		opts = opts.filter(func(o): return not o.is_empty())
		if not opts.is_empty():
			out["LINK:" + lid] = {"options": opts}
	var jt := junctions(world)
	for jid in EconUtil.sorted_keys(jt):
		var j: Dictionary = jt[jid]
		var cur := String(j["type"])
		var opts2: Array = []
		for to in ["PRIORITY", "ROUNDABOUT", "SIGNALS"]:
			if JUNCTION_TYPES.find(to) <= JUNCTION_TYPES.find(cur) or (to == "PRIORITY" and cur != "CROSSING"):
				continue
			var spec2 := {"junction": jid, "type": to}
			var plan2 := plan_link(world, spec2)
			if plan2["ok"]:
				opts2.append({"fix": to, "cost": int(plan2["cost"]), "months": int(plan2["months"]),
					"cap_pm": int(JUNCTION_CAPACITY[to]) * 1000 / int(JUNCTION_CAPACITY[cur]),
					"acc_pm": int(JUNCTION_RISK[to]) * 1000 / int(JUNCTION_RISK[cur]), "spec": spec2})
		if not opts2.is_empty():
			out["NODE:" + jid] = {"options": opts2}
	return out


static func _fix_option(world: WorldState, fix: String, spec: Dictionary, l: Dictionary, change: Callable, acc_pm: int) -> Dictionary:
	var plan := plan_link(world, spec)
	if not plan["ok"]:
		return {}
	var after := l.duplicate(true)
	change.call(after)
	return {"fix": fix, "cost": int(plan["cost"]), "months": int(plan["months"]),
		"cap_pm": link_capacity(after) * 1000 / maxi(1, link_capacity(l)), "acc_pm": acc_pm, "spec": spec}



## Links planned before straight bridges (PLANNER 2) that cross the river diagonally or run along it get their route
## re-planned once between the same ends (kind, lanes, condition kept). Deterministic; runs in the NATURE tick.
static func _replan_crossings(world: WorldState) -> void:
	var t := world.table("transport")
	if int(t.get("planner", 1)) >= PLANNER:
		return
	t["planner"] = PLANNER
	var links: Dictionary = t["links"]
	var changed := false
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1 or not bad_crossing(world, l["path"]):
			continue
		var p := plan_path(world, int_tile(int(l["path"][0])), int_tile(int(l["path"][-1])))
		if p.is_empty():
			continue
		var fresh := _colony_link(lid, String(l["kind"]), p, world, int(l["built"]))
		for k in ["lanes", "bridge_lanes", "cond", "traffic", "acc", "built"]:
			fresh[k] = l.get(k, fresh[k])
		links[lid] = fresh
		changed = true
	for lid2 in links:   # every colony link records its spans
		if int(links[lid2].get("globe", 0)) == 0 and not links[lid2].has("spans"):
			links[lid2]["spans"] = spans(world, links[lid2]["path"])
	if changed:
		t["junctions"] = _derive_junctions(links, t.get("junctions", {}))
	_bump(world)


## A path crosses water badly: a diagonal step touching a river tile, or a span longer than the river is wide there
## (it runs along the river).
static func bad_crossing(world: WorldState, path: Array) -> bool:
	for i in range(1, path.size()):
		var a := int_tile(int(path[i - 1]))
		var b := int_tile(int(path[i]))
		if a.x != b.x and a.y != b.y and (_water(world, int(path[i - 1])) or _water(world, int(path[i]))
				or _water(world, tile_int(Vector2i(b.x, a.y))) or _water(world, tile_int(Vector2i(a.x, b.y)))):
			return true   # a diagonal step over water, or slipping between two water tiles without a bridge
	for x in spans(world, path):
		if int(x[1]) >= 3:
			return true
	return false
