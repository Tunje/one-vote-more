class_name ColonyLayout
extends RefCounted
## Terra: where things stand on the colony map (Terrain.W × Terrain.H), a pure read of the world.
## - Settlements: the areas (AreaStore). Before the first area is founded, the landfall place alone (LANDING): the
##   colony starts as one place, and districts are drawn from areas as it spreads (rebuild-company.md 9.12, 12.1).
## - Facilities: their own tile (f["tile"]) or the site siting chose; else a free tile of suitable terrain nearest
##   their area, their district's anchor, or the landing.
## Used by the transport network (sim) and the colony map (UI). Deterministic in the terrain and the facility ids.

## Where facilities may stand (placement before A2, and build validity).
const FAC_TERRAIN := {"MINE": ["o", "x", "k", "h"], "FARM": ["f", "n", "."], "HOUSING": [".", "f", "L", "n"]}
const BUILD_TERRAIN := [".", "f", "L", "n", "h"]
## The landfall place before its first area is founded (the colony starts as one place where it landed).
const LANDING := "landing"
static var _cache := {}


## Changes whenever the layout may change: the terrain, the facilities (which ones), the areas (status, district,
## name, size) and the map uses. Not the month (Bob/Wilma 2026-11-13: the commuting step asks every month, and
## rebuilding the layout cost seconds a month).
static func key(w: WorldState) -> String:
	var fac: Dictionary = w.peek("facility")
	return "%s|%d|%d%s" % [_land_key(w), fac.size(), hash(fac.keys()), Siting.sig(w)]


## The part without the facilities: what the settlements depend on (terrain, areas, map uses).
static func _land_key(w: WorldState) -> String:
	var asig := 0
	var areas: Dictionary = w.peek("area")
	for id in areas:
		var a: Dictionary = areas[id]
		asig = hash([asig, String(id), String(a.get("status", "")), String(a.get("district", "")), String(a.get("name", "")),
			(a.get("tiles", []) as Array).size()])
	return "%d|%d|%d|%d|%d|%d" % [w.get_instance_id(), w.rng.derive_seed("map.terrain"), hash(w.peek("map").get("grid", {}).get("rows", [])),
		areas.size(), asig, hash(w.peek("map").get("uses", {}).keys())]


static func _cached(w: WorldState, what: String, fn: Callable, land_only: bool = false) -> Variant:
	var k := what + "|" + (_land_key(w) if land_only else key(w))
	if not _cache.has(k):
		if _cache.size() >= 16:
			_cache.clear()
		_cache[k] = fn.call()
	return _cache[k]


## Each district's anchor: the tile of its first settlement (by id). No districts are laid out in advance (the user:
## "no sectors beyond landfallpoint that's up to where things are built"), so this is {} until areas exist; readers
## fall back to the landing tile. Pure in the areas.
static func anchors(w: WorldState) -> Dictionary:
	return _cached(w, "anchors", func(): return _anchors(w), true)


static func _anchors(w: WorldState) -> Dictionary:
	var out := {}
	for s in settlements(w):
		var d := String(s["district"])
		if d != "" and not out.has(d):
			out[d] = s["tile"]
	return out


static func count_near(w: WorldState, t: Vector2i, codes: Array, r: int) -> int:
	var n := 0
	for yy in range(t.y - r, t.y + r + 1):
		for xx in range(t.x - r, t.x + r + 1):
			n += 1 if Terrain.at(w, xx, yy) in codes else 0
	return n


static func near_code(w: WorldState, t: Vector2i, code: String, r: int) -> bool:
	for yy in range(t.y - r, t.y + r + 1):
		for xx in range(t.x - r, t.x + r + 1):
			if Terrain.at(w, xx, yy) == code:
				return true
	return false


## Settlements: [{id, name, tile (Vector2i), tiles ([Vector2i] the town covers), district}], sorted by id.
## Areas once they exist (every kind: settlements, camps, villages, enclaves...), else the display settlements.
static func settlements(w: WorldState) -> Array:
	return _cached(w, "settlements", func(): return _settlements(w), true)


static func _settlements(w: WorldState) -> Array:
	var out: Array = []
	var areas := AreaStore.areas(w)
	if not areas.is_empty():
		for a in areas:
			var tiles: Array = AreaStore.tiles_of(w, a["id"]).map(func(t): return as_tile(t))
			if tiles.is_empty():
				continue
			var c := AreaStore.centroid(w, a["id"])
			var best: Vector2i = tiles[0]
			for t in tiles:   # the area tile nearest its centroid (an area may be L-shaped)
				if Vector2(t).distance_to(c) < Vector2(best).distance_to(c):
					best = t
			out.append({"id": String(a["id"]), "name": String(a.get("name", a["id"])), "tile": best, "tiles": tiles,
				"district": String(a.get("district", ""))})
	elif Terrain.ready(w):   # before the first area: the landfall place alone
		var l := Terrain.landing(w)
		out.append({"id": LANDING, "name": "Landing", "tile": l, "tiles": [l], "district": ""})
	out.sort_custom(func(a, b): return String(a["id"]) < String(b["id"]))
	return out


## Where each facility stands: fid -> Vector2i (see the header).
static func facility_tiles(w: WorldState, given_anchors: Dictionary = {}) -> Dictionary:
	if given_anchors.is_empty():
		return _cached(w, "fac", func(): return _facility_tiles(w, anchors(w)))
	return _facility_tiles(w, given_anchors)


static func _facility_tiles(w: WorldState, anchors: Dictionary) -> Dictionary:
	var out := {}
	var taken := {}
	for k in w.peek("map").get("uses", {}):
		taken[k] = true
	var fac: Dictionary = w.peek("facility")
	var ids: Array = CoreUtil.sorted_keys(fac)
	var pins := Siting.pins(w)   # SITING: chosen and kept sites ({} without the flag)
	for fid in ids:   # facilities that already stand on a tile
		var tv = fac[fid].get("tile", null)
		if tv == null and pins["fac"].has(fid):
			tv = pins["fac"][fid]
		if tv != null:
			var t := as_tile(tv)
			out[fid] = t
			taken[Terrain.key(t.x, t.y)] = true
	for k in pins["pending"]:   # SITING: a site chosen for a building still to be built
		taken[k] = true
	var blocked := {}   # SITING: kind -> tiles reserved for another use
	for k in anchors:
		taken[Terrain.key(anchors[k].x, anchors[k].y)] = true
	for fid in ids:
		if out.has(fid):
			continue
		var f: Dictionary = fac[fid]
		var a: Vector2i = anchors.get(String(f.get("district", "")), Terrain.landing(w))
		if f.has("area") and not AreaStore.get_area(w, String(f["area"])).is_empty():
			var c := AreaStore.centroid(w, String(f["area"]))
			a = Vector2i(roundi(c.x), roundi(c.y))
		var codes: Array = FAC_TERRAIN.get(String(f["type"]), BUILD_TERRAIN)
		var bl := {}
		if Siting.on(w):
			var kd := Siting.kind_of(String(f["type"]))
			if not blocked.has(kd):
				blocked[kd] = Siting.blocked(w, String(f["type"]))
			bl = blocked[kd]
		var t := nearest_untaken(w, a, codes, taken, 40, bl)
		if t.x < 0:
			t = nearest_untaken(w, a, BUILD_TERRAIN + ["k", "o", "x"], taken, 40, bl)
		if t.x >= 0:
			out[fid] = t
			taken[Terrain.key(t.x, t.y)] = true
	return out


static func as_tile(v) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Vector2:
		return Vector2i(roundi(v.x), roundi(v.y))
	if v is String:
		return Vector2i(int(String(v).get_slice(",", 0)), int(String(v).get_slice(",", 1)))
	if v is Array:
		return Vector2i(int(v[0]), int(v[1]))
	if v is int:
		return Vector2i(int(v) % Terrain.W, int(v) / Terrain.W)
	return Vector2i(-1, -1)


## Nearest tile to `a` of one of `codes` that is not taken (nor `blocked`: SITING, land reserved for another use);
## ties go to the first in rows-then-columns order.
## Deterministic. Searched ring by ring and stopped once no nearer tile can come (the same answer as a full scan).
static func nearest_untaken(w: WorldState, a: Vector2i, codes: Array, taken: Dictionary, reach: int, blocked: Dictionary = {}) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for r in reach + 1:
		if float(r) > bd:   # every tile of this ring and beyond is at least r away
			break
		for yy in range(a.y - r, a.y + r + 1):
			if yy < 0 or yy >= Terrain.H:
				continue
			var step := 1 if absi(yy - a.y) == r else 2 * r
			var xx := a.x - r
			while xx <= a.x + r:
				if xx >= 0 and xx < Terrain.W and not taken.has(Terrain.key(xx, yy)) and Terrain.at(w, xx, yy) in codes 						and (blocked.is_empty() or not blocked.has(Terrain.key(xx, yy))):
					var d := Vector2(xx - a.x, yy - a.y).length()
					if d < bd or (d == bd and (yy < best.y or (yy == best.y and xx < best.x))):
						bd = d
						best = Vector2i(xx, yy)
				xx += maxi(1, step)
	return best


# ================================================================== site choice (Siting, flag SITING)

## Candidate tiles for a building of this type in a district, with what stands near each (Siting.site_options). Pure.
static func site_options(w: WorldState, ftype: String, district: String, n: int = 5) -> Array:
	return Siting.site_options(w, ftype, district, n)


## Use this tile for a facility opened this month or a building project still to be built. → "" or why not.
static func place_at(w: WorldState, fid_or_project: String, tile) -> String:
	return Siting.place_at(w, fid_or_project, tile)


## Reserve tiles for a use (FARMLAND / HOUSING / INDUSTRY / NATURE / OPEN; "" lifts it). → "" or why not.
static func set_use(w: WorldState, tiles: Array, use: String, by: String = "gov") -> String:
	return Siting.set_use(w, tiles, use, by)


## The use a tile is reserved for ("" = none).
static func use_at(w: WorldState, tile) -> String:
	return Siting.use_at(w, tile)
