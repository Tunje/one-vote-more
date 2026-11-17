class_name ColonyLayout
extends RefCounted
## Terra: where things stand on the colony map (Terrain.W × Terrain.H), a pure read of the world.
## - Settlements: the areas (AreaStore). Before the first area is founded, the landfall place alone (LANDING): the
##   colony starts as one place, and districts are drawn from areas as it spreads (rebuild-company.md 9.12, 12.1).
## - Plants: where they stand is recorded once, on the map (Site: a town plant's cells, a country plant's tile); a plan
##   holding its site counts too. There is no guessed placement any more.
## Used by the transport network (sim) and the colony map (UI). Deterministic in the terrain and the recorded places.

const Site := preload("res://sim/transport/site.gd")
## Where a building may stand (build validity on the map).
const FAC_TERRAIN := {"MINE": ["o", "x", "k", "h"], "FARM": ["f", "n", "."], "LANDLORD": [".", "f", "L", "n"]}
const BUILD_TERRAIN := [".", "f", "L", "n", "h"]
## The landfall place before its first area is founded (the colony starts as one place where it landed).
const LANDING := "landing"
static var _cache := {}


## Changes whenever the layout may change: the terrain, the areas (status, district, name, size), the map uses and the
## recorded places (Site.sig and the town table's revision). Not the month (Bob/Wilma 2026-11-13: the commuting step
## asks every month, and rebuilding the layout cost seconds a month).
static func key(w: WorldState) -> String:
	return "%s%s|t%d" % [_land_key(w), Site.sig(w), int(w.peek("town").get("rev", 0))]


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


## Where each plant (and each plan holding a site) stands: id -> Vector2i, its 3 km tile (a town plant: the tile of its
## first cell). `_given_anchors` is ignored (kept for old callers).
static func facility_tiles(w: WorldState, _given_anchors: Dictionary = {}) -> Dictionary:
	return _cached(w, "fac", func(): return _facility_tiles(w))


static func _facility_tiles(w: WorldState, _anchors: Dictionary = {}) -> Dictionary:
	var out := {}
	for id in Site.ids(w):
		var s := Site.of(w, String(id))
		if not s.is_empty():
			out[String(id)] = as_tile(String(s["tile"]))
	return out


## Every plant and held plan site with what it is: id -> {type, sixths, plan, closed, company, tile (Vector2i), area,
## district}. The area is the one it stands in (a town plant: the neighbourhood owning the block of its first cell; a
## country plant: the area of its tile, else the nearest), the district that area's. Read fresh (not cached): a plant closing changes it.
static func plants(w: WorldState) -> Dictionary:
	var out := {}
	var ft := facility_tiles(w)
	for id in CoreUtil.sorted_keys(ft):
		var wt := Site.what(w, String(id))
		if wt.is_empty():
			continue
		var t: Vector2i = ft[id]
		wt["tile"] = t
		var cs := TownGrid.cells_of(w, String(id))
		var area := AreaStore.area_of_block(w, TownGrid.block_of(cs[0])) if not cs.is_empty() else ""
		if area == "":
			area = AreaStore.area_of(w, t)
		if area == "":
			area = AreaStore.nearest_area(w, t)
		wt["area"] = area
		wt["district"] = String(AreaStore.get_area(w, area).get("district", ""))
		out[String(id)] = wt
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
