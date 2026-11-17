class_name TownGrid
extends RefCounted
## Terra (planning/design-town-grid.md; the rebuild, planning/rebuild-company.md 9.8 and 12.1): towns on a fine grid.
## Part of the rebuild and always on ("nothing behind an off switch").
## - Each settlement gets a grid of 100 m cells (30 × 30 to a 3 km tile) in global fine coordinates: cell (fx, fy) lies
##   in tile (fx ÷ 30, fy ÷ 30), so two towns cannot overlap.
## - Streets run on one global lattice (every BLOCK_CELLS cells), so a street block (400 m, 16 cells) is fixed by
##   geography: block_of(cell). A street block is the town's "square" (rebuild 5) and the piece areas are made of
##   (Maja's AreaStore holds which blocks form an area; this file holds the cells).
## - A plant is laid explicitly (Site.place / Site.hold, which call lay()): a plant with homes (a LANDLORD) takes cells
##   in a form (HOUSE / APARTMENT / TOWER) for its homes; a town building (shop, clinic, school, care, offices...) takes
##   one cell. The cells are the one record of where a town plant stands and of its homes (homes_of). Only occupied
##   cells are stored; streets are derived.
## - Where a town grows is scored per cell, by what draws people (jobs, school, clinic, shops, laid utilities, water,
##   a road, the centre) less what keeps them away (a fast road, industry next door), with a little randomness per seed
##   (the user: "not perfect circular towns"). The parts stay visible for a site case.
## - The allowed forms are a policy (the commander's, later the government's or a municipality's): per town or "*".
## - A grid from the first house (the user, 2026-11-17: "Below 250 start a gridd anyway and only use what you need"):
##   a town (an area's id) gets its grid with the first building laid in it (ensure_town). No high-rise exists in a
##   town until it has apartments.
## Table "town": {"towns": {tid: {"c": [fx, fy], "cells": {"fx,fy": [plant or plan id, form, homes]}}},
##   "policy": {tid | "*": [form, ...]}, "rev": int}.

const PER_TILE := 30          # cells along a 3 km tile
const CELL_KM := 0.1
## homes: per cell; storeys; conn_m: street, pipe and cable per home inside the cell's street block.
const FORMS := {
	"HOUSE": {"homes": 8, "storeys": 2, "conn_m": 15},   # 8 plots to a cell (the user's house plots, 2026-11-16)
	"APARTMENT": {"homes": 60, "storeys": 4, "conn_m": 3},
	"TOWER": {"homes": 200, "storeys": 15, "conn_m": 1},
}
const DEFAULT_FORMS := ["HOUSE"]
const TRUNK_HOMES := 100      # a metre of trunk (centre → cell) is shared by about this many homes (a guess)
## Score weights (draws positive, penalties negative) and reach (km). "view": the sea or a river in sight (close);
## "water": the shore within walking distance.
const W := {"jobs": 3.0, "school": 2.0, "clinic": 1.0, "shops": 2.0, "utilities": 3.0, "view": 2.0, "water": 1.5,
	"road": 1.5, "centre": 1.0, "fast_road": -3.0, "industry": -2.0, "noise": 1.5}
const REACH_KM := {"jobs": 4.0, "school": 1.5, "clinic": 2.0, "shops": 1.5, "utilities": 1.0, "view": 0.3, "water": 1.0,
	"road": 1.0, "centre": 3.0, "fast_road": 0.3, "industry": 1.0}
## The parts of a cell's location value (what a home there is worth); the growth score adds "centre" and "noise".
const VALUE_PARTS := ["jobs", "school", "clinic", "shops", "utilities", "view", "water", "road", "fast_road", "industry"]
const VALUE_PER_POINT := 100  # ‰ of an ordinary cell's value per point of the value score
const VALUE_MIN_PM := 300
## Catchments: how far people walk or travel to a place (km), and when it counts as full (free cells for houses left).
const CATCH_KM := {"SCHOOL": 1.5, "CLINIC": 2.0, "": 3.0}   # "" = a workplace
const FULL_FREE := 5          # fewer free cells than one 50-home block of houses takes
const SHOP_TYPES := ["SHOP", "BAKERY", "CAFE"]
const SEED_KM := 12.0         # a new neighbourhood may start at a workplace this close to the centre
const SEED_CELLS := 6         # ... at cells this far from it (a 3 × 3 sample, every SEED_CELLS cells)
const KEEP_CLEAR := 2         # cells around a country building's site (its tile's middle) that homes do not take
const START_R := 5            # an empty town's candidates: cells this close to its centre
const BLOCK_CELLS := 4        # a street every 4 cells: a street block is 400 m, 16 cells

const Site := preload("res://sim/transport/site.gd")

static var _cache := {}


## Always on (rebuild 12.4, 33). Kept as a function because its readers ask.
static func on(_world: WorldState = null) -> bool:
	return true


static func _ck(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _cell(v) -> Vector2i:
	return ColonyLayout.as_tile(v)


static func tile_of(cell) -> Vector2i:
	var c := _cell(cell)
	return Vector2i(floori(float(c.x) / PER_TILE), floori(float(c.y) / PER_TILE))


static func centre_cell(tile) -> Vector2i:
	var t := ColonyLayout.as_tile(tile)
	return Vector2i(t.x * PER_TILE + PER_TILE / 2, t.y * PER_TILE + PER_TILE / 2)


## A cell's middle in km (fine coordinates × 0.1).
static func _km(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * CELL_KM, (float(c.y) + 0.5) * CELL_KM)


static func _tile_km(t: Vector2i) -> Vector2:
	return Vector2((float(t.x) + 0.5) * 3.0, (float(t.y) + 0.5) * 3.0)


static func _bump(tb: Dictionary) -> void:
	tb["rev"] = int(tb.get("rev", 0)) + 1


# ================================================================== reads

## {cell key: [fid, form, homes, tid]} and {fid: [cell keys]} over all towns; cached on the table's revision.
static func _index(world: WorldState) -> Dictionary:
	var tb: Dictionary = world.peek("town")
	var key := "%d|%d" % [world.get_instance_id(), int(tb.get("rev", -1))]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= 8:
		_cache.clear()
	var cells := {}
	var of := {}
	var towns: Dictionary = tb.get("towns", {})
	for tid in CoreUtil.sorted_keys(towns):
		var cs: Dictionary = towns[tid]["cells"]
		for ck in CoreUtil.sorted_keys(cs):
			var row: Array = cs[ck]
			cells[ck] = [String(row[0]), String(row[1]), int(row[2]), String(tid)]
			if not of.has(row[0]):
				of[row[0]] = []
			of[row[0]].append(String(ck))
	var out := {"cells": cells, "of": of}
	_cache[key] = out
	return out


## The cells a building stands on ("fx,fy"), [] if none.
static func cells_of(world: WorldState, fid: String) -> Array:
	return (_index(world)["of"] as Dictionary).get(fid, []).duplicate()


## The town a building stands in ("" if none).
static func town_of(world: WorldState, fid: String) -> String:
	var cs := cells_of(world, fid)
	return "" if cs.is_empty() else String(_index(world)["cells"][cs[0]][3])


## A plant's form (HOUSE, APARTMENT, TOWER for homes; "" for a town building or a plant without cells).
static func form_of(world: WorldState, fid: String) -> String:
	var cs := cells_of(world, fid)
	return String(_index(world)["cells"][cs[0]][1]) if not cs.is_empty() else ""


## The homes of a plant: the homes in its cells (the one record of homes; a landlord's client places).
static func homes_of(world: WorldState, fid: String) -> int:
	var n := 0
	var cells: Dictionary = _index(world)["cells"]
	for ck in cells_of(world, fid):
		n += int(cells[ck][2])
	return n


## The homes on one cell (Vector2i or "fx,fy"); 0 for an empty cell or a town building. Land law reads it (evictions).
static func homes_on_cell(world: WorldState, cell) -> int:
	var row: Array = (_index(world)["cells"] as Dictionary).get(_ck(_cell(cell)), [])
	return int(row[2]) if not row.is_empty() else 0


## Every id that holds cells, sorted.
static func ids(world: WorldState) -> Array:
	return CoreUtil.sorted_keys(_index(world)["of"])


## The 3 km tiles that hold town cells: {"x,y": true}.
static func town_tiles(world: WorldState) -> Dictionary:
	var out := {}
	for ck in _index(world)["cells"]:
		var t := tile_of(ck)
		out[Terrain.key(t.x, t.y)] = true
	return out


## Does the town have its fine grid yet?
static func has_grid(world: WorldState, tid: String) -> bool:
	return world.peek("town").get("towns", {}).has(tid)


static func _centre_of(world: WorldState, tid: String) -> Vector2i:
	var t: Dictionary = world.peek("town").get("towns", {}).get(tid, {})
	if not t.is_empty():
		return Vector2i(int(t["c"][0]), int(t["c"][1]))
	for s in ColonyLayout.settlements(world):
		if String(s["id"]) == tid:
			return centre_cell(s["tile"])
	return Vector2i(-1, -1)


## The forms allowed in a town (the first is what a new block is built as): the town's policy, else the colony's
## ("*"), else DEFAULT_FORMS.
## No high-rise before the town has apartments: TOWER is left out until then (HOUSE stands in if nothing is left).
static func forms_allowed(world: WorldState, tid: String) -> Array:
	var pol: Dictionary = world.peek("town").get("policy", {})
	var out: Array = (pol.get(tid, pol.get("*", DEFAULT_FORMS)) as Array).duplicate()
	if out.has("TOWER") and not _has_form(world, tid, "APARTMENT"):
		out.erase("TOWER")
	if out.is_empty():
		out = DEFAULT_FORMS.duplicate()
	return out


static func _has_form(world: WorldState, tid: String, form: String) -> bool:
	var cs: Dictionary = world.peek("town").get("towns", {}).get(tid, {}).get("cells", {})
	for ck in cs:
		if String(cs[ck][1]) == form:
			return true
	return false


## Street, pipe and cable per home of a block, m: its form's own, plus its share of the trunk from the town centre
## (the street-lattice distance ÷ TRUNK_HOMES). A block in a settlement without a grid: houses at the centre (the
## HOUSE figure). -1 if not housing.
static func connection_m(world: WorldState, fid: String) -> int:
	var cs := cells_of(world, fid)
	if cs.is_empty():
		return int(FORMS["HOUSE"]["conn_m"]) if form_of(world, fid) == "HOUSE" else -1
	var tid := town_of(world, fid)
	var c0 := _centre_of(world, tid)
	var m := 0.0
	for ck in cs:
		var c := _cell(ck)
		m += float(absi(c.x - c0.x) + absi(c.y - c0.y)) * CELL_KM * 1000.0
	m /= float(cs.size())
	return int(FORMS.get(form_of(world, fid), FORMS["HOUSE"])["conn_m"]) + roundi(m / TRUNK_HOMES)


## A town building's mean distance to its town centre, km (straight). -1.0 for a plant without cells.
static func centre_km(world: WorldState, fid: String) -> float:
	var cs := cells_of(world, fid)
	if cs.is_empty():
		return -1.0
	var c0 := _km(_centre_of(world, town_of(world, fid)))
	var s := 0.0
	for ck in cs:
		s += _km(_cell(ck)).distance_to(c0)
	return s / float(cs.size())


## Street distance between two buildings, km (along the lattice: |dx| + |dy| between their first cells; a building
## without a cell counts at the middle of its 3 km tile). -1.0 if either is unknown.
static func in_town_km(world: WorldState, fid_a: String, fid_b: String) -> float:
	var pa := _pos_km(world, fid_a)
	var pb := _pos_km(world, fid_b)
	if pa.x < 0.0 or pb.x < 0.0:
		return -1.0
	return absf(pa.x - pb.x) + absf(pa.y - pb.y)


static func _pos_km(world: WorldState, fid: String) -> Vector2:
	var cs := cells_of(world, fid)
	if not cs.is_empty():
		return _km(_cell(cs[0]))
	var ft := ColonyLayout.facility_tiles(world)
	if ft.has(fid):
		return _tile_km(ColonyLayout.as_tile(ft[fid]))
	return Vector2(-1, -1)


## Free cells next to a town's cells (room to grow), sorted.
static func edge_cells(world: WorldState, tid: String) -> Array:
	var idx: Dictionary = _index(world)["cells"]
	var out := {}
	for ck in world.peek("town").get("towns", {}).get(tid, {}).get("cells", {}):
		var c := _cell(ck)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var k := _ck(c + d)
			if not idx.has(k):
				out[k] = true
	return CoreUtil.sorted_keys(out)


# ================================================================== street blocks (the pieces areas are made of)

## The street block a cell lies in: "b:bx,by", bx = fx ÷ BLOCK_CELLS (floored). Fixed by geography; pure.
static func block_of(cell) -> String:
	var c := _cell(cell)
	return "b:%d,%d" % [floori(float(c.x) / BLOCK_CELLS), floori(float(c.y) / BLOCK_CELLS)]


static func _block_xy(block: String) -> Vector2i:
	var p := block.trim_prefix("b:").split(",")
	return Vector2i(int(p[0]), int(p[1]))


## A block's cells ("fx,fy"), row by row.
static func block_cells(block: String) -> Array:
	var b := _block_xy(block)
	var out: Array = []
	for dy in BLOCK_CELLS:
		for dx in BLOCK_CELLS:
			out.append(_ck(Vector2i(b.x * BLOCK_CELLS + dx, b.y * BLOCK_CELLS + dy)))
	return out


## The blocks a town has anything built in, sorted ("" = every town).
static func blocks(world: WorldState, tid: String = "") -> Array:
	var cells: Dictionary = _index(world)["cells"]
	var out := {}
	for ck in cells:
		if tid == "" or String(cells[ck][3]) == tid:
			out[block_of(ck)] = true
	return CoreUtil.sorted_keys(out)


## Homes in a block.
static func block_homes(world: WorldState, block: String) -> int:
	var cells: Dictionary = _index(world)["cells"]
	var n := 0
	for ck in block_cells(block):
		if cells.has(ck):
			n += int(cells[ck][2])
	return n


## Where a set of blocks (an area) could be cut in two: every street-lattice line that leaves blocks on both sides,
## strongest boundary first. Kinds, strongest first (agreed with Maja, 2026-11-17): RIVER (a river runs along the line),
## FAST_ROAD (a road at 70 km/h or more runs along it), MAIN_STREET (any colony road runs along it), STREET (the plain
## lattice). Within a kind, the cut that leaves both parts most compact first (the smaller of the two parts'
## spread_km, agreed with Maja), then the most even split of the homes, then by position.
## [{axis: "x" | "y" (the line is x = at or y = at, in fine cells), at, kind, a: [blocks on the smaller-coordinate side (west
## for "x", north for "y")], b: [the larger side], homes_a, homes_b}]. Pure in the town table, the roads and the terrain. Roads and rivers are drawn as straight
## runs between 3 km tile middles (as the town view draws them); "along" means a run that is more along the line than
## across it, passes within half a block of it (nearer it than the next street), and overlaps the blocks' extent.
static func boundaries(world: WorldState, blocks_in: Array) -> Array:
	var bs: Array = []
	for b in blocks_in:
		bs.append(_block_xy(String(b)))
	if bs.size() < 2:
		return []
	var runs := _boundary_runs(world)
	var out: Array = []
	for axis in ["x", "y"]:
		var lo := 1 << 30
		var hi := -(1 << 30)
		for b in bs:
			var v: int = b.x if axis == "x" else b.y
			lo = mini(lo, v)
			hi = maxi(hi, v)
		for line in range(lo + 1, hi + 1):   # the street between block line - 1 and block line
			var a: Array = []
			var b2: Array = []
			var ha := 0
			var hb := 0
			var span_lo := 1 << 30
			var span_hi := -(1 << 30)
			for i in bs.size():
				var bv: Vector2i = bs[i]
				var key := "b:%d,%d" % [bv.x, bv.y]
				var h := block_homes(world, key)
				if (bv.x if axis == "x" else bv.y) < line:
					a.append(key)
					ha += h
				else:
					b2.append(key)
					hb += h
				var other: int = bv.y if axis == "x" else bv.x
				span_lo = mini(span_lo, other * BLOCK_CELLS)
				span_hi = maxi(span_hi, (other + 1) * BLOCK_CELLS)
			if a.is_empty() or b2.is_empty():
				continue
			var at := line * BLOCK_CELLS
			var kind := "STREET"
			for r in runs:
				if _runs_along(r, axis, at, span_lo, span_hi) and BOUNDARY_RANK[String(r["kind"])] < BOUNDARY_RANK[kind]:
					kind = String(r["kind"])
			a.sort()
			b2.sort()
			out.append({"axis": axis, "at": at, "kind": kind, "a": a, "b": b2, "homes_a": ha, "homes_b": hb,
				"spread_km": snappedf(maxf(spread_km(world, a), spread_km(world, b2)), 0.001)})
	out.sort_custom(func(p, q):
		if BOUNDARY_RANK[p["kind"]] != BOUNDARY_RANK[q["kind"]]:
			return BOUNDARY_RANK[p["kind"]] < BOUNDARY_RANK[q["kind"]]
		if float(p["spread_km"]) != float(q["spread_km"]):
			return float(p["spread_km"]) < float(q["spread_km"])
		var dp := absi(int(p["homes_a"]) - int(p["homes_b"]))
		var dq := absi(int(q["homes_a"]) - int(q["homes_b"]))
		if dp != dq:
			return dp < dq
		if p["axis"] != q["axis"]:
			return String(p["axis"]) < String(q["axis"])
		return int(p["at"]) < int(q["at"]))
	return out


const BOUNDARY_RANK := {"RIVER": 0, "FAST_ROAD": 1, "MAIN_STREET": 2, "STREET": 3}


## The middle of a street block, km.
static func block_mid_km(block: String) -> Vector2:
	var b := _block_xy(block)
	var m := float(BLOCK_CELLS) * 0.5
	return Vector2((float(b.x * BLOCK_CELLS) + m) * CELL_KM, (float(b.y * BLOCK_CELLS) + m) * CELL_KM)


## How far (km) the farthest block with homes lies from the homes-weighted middle of `blocks`; 0 without homes.
## The compactness of a neighbourhood (Maja's reach split reads it; one rule for both of us).
static func spread_km(world: WorldState, blocks: Array) -> float:
	var c := Vector2.ZERO
	var n := 0
	for b in blocks:
		var h := block_homes(world, String(b))
		if h > 0:
			c += block_mid_km(String(b)) * float(h)
			n += h
	if n <= 0:
		return 0.0
	c /= float(n)
	var far := 0.0
	for b in blocks:
		if block_homes(world, String(b)) > 0:
			far = maxf(far, block_mid_km(String(b)).distance_to(c))
	return far
const FAST_KMH := 70


## Rivers and roads as straight runs between 3 km tile middles, in fine cells: [{kind, p, q}].
static func _boundary_runs(world: WorldState) -> Array:
	var out: Array = []
	var mid := func(t: Vector2i) -> Vector2:
		return Vector2(float(t.x * PER_TILE) + PER_TILE * 0.5, float(t.y * PER_TILE) + PER_TILE * 0.5)
	if Terrain.ready(world):
		for y in Terrain.H:
			for x in Terrain.W:
				if Terrain.at(world, x, y) != "r":
					continue
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
					if Terrain.at(world, x + d.x, y + d.y) == "r":
						out.append({"kind": "RIVER", "p": mid.call(Vector2i(x, y)), "q": mid.call(Vector2i(x, y) + d)})
	var links := Transport._links(world)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var kind := "FAST_ROAD" if RoadSafety.kmh(world, l) >= FAST_KMH else "MAIN_STREET"
		var path: Array = l.get("path", [])
		for i in range(1, path.size()):
			out.append({"kind": kind, "p": mid.call(Transport.int_tile(int(path[i - 1]))), "q": mid.call(Transport.int_tile(int(path[i])))})
	return out


static func _runs_along(r: Dictionary, axis: String, at: int, span_lo: int, span_hi: int) -> bool:
	var p: Vector2 = r["p"]
	var q: Vector2 = r["q"]
	var d := q - p
	var along := absf(d.y) if axis == "x" else absf(d.x)
	var across := absf(d.x) if axis == "x" else absf(d.y)
	if along <= across:
		return false
	var m := (p + q) * 0.5
	var off := absf((m.x if axis == "x" else m.y) - float(at))
	if off > float(BLOCK_CELLS) * 0.5:   # nearer this street than the next one
		return false
	var r_lo := minf(p.y, q.y) if axis == "x" else minf(p.x, q.x)
	var r_hi := maxf(p.y, q.y) if axis == "x" else maxf(p.x, q.x)
	return r_hi > float(span_lo) and r_lo < float(span_hi)


## The 3 km tiles a town covers: {"x,y": homes}. {} before it has a grid.
static func footprint(world: WorldState, tid: String) -> Dictionary:
	var out := {}
	var cs: Dictionary = world.peek("town").get("towns", {}).get(tid, {}).get("cells", {})
	for ck in CoreUtil.sorted_keys(cs):
		var t := tile_of(ck)
		var k := Terrain.key(t.x, t.y)
		out[k] = int(out.get(k, 0)) + int(cs[ck][2])
	return out


## Homes in a 3 km tile (every home stands on a town cell).
static func homes_in_tile(world: WorldState, tile) -> int:
	var t := ColonyLayout.as_tile(tile)
	var n := 0
	var idx: Dictionary = _index(world)
	for ck in idx["cells"]:
		if tile_of(ck) == t:
			n += int(idx["cells"][ck][2])
	return n


# ================================================================== scoring

## What the scoring reads once per call: the places that draw people or keep them away, in km, and the roads.
static func _context(world: WorldState, tid: String = "") -> Dictionary:
	var ft := ColonyLayout.facility_tiles(world)
	var idx: Dictionary = _index(world)
	var pts := {"jobs": [], "school": [], "clinic": [], "shops": [], "industry": [], "clear": []}
	for fid in CoreUtil.sorted_keys(ft):
		var wt := Site.what(world, String(fid))
		if wt.is_empty():
			continue
		var ty := String(wt["type"])
		var cs: Array = (idx["of"] as Dictionary).get(fid, [])
		var p := _km(_cell(cs[0])) if not cs.is_empty() else _tile_km(ColonyLayout.as_tile(ft[fid]))
		if ty != "LANDLORD":
			pts["jobs"].append(p)
		match ty:
			"SCHOOL":
				pts["school"].append(p)
			"CLINIC":
				pts["clinic"].append(p)
		if ty in SHOP_TYPES:
			pts["shops"].append(p)
		if _industry(ty):
			pts["industry"].append(p)
		if Site.setting(ty) == "COUNTRY" and cs.is_empty():
			pts["clear"].append(centre_cell(ft[fid]))
	pts["jobs"].append(_tile_km(Terrain.landing(world)))   # the port
	var segs: Array = []   # [a km, b km, kmh]
	var links := Transport._links(world)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var path: Array = l.get("path", [])
		var v := RoadSafety.kmh(world, l)
		for i in range(1, path.size()):
			segs.append([_tile_km(Transport.int_tile(int(path[i - 1]))), _tile_km(Transport.int_tile(int(path[i]))), v])
	return {"pts": pts, "segs": segs, "cells": idx["cells"], "salt": world.rng.derive_seed("town.grid"), "tid": tid}


## Industry keeps homes away and lowers their value: every country type but a farm.
static func _industry(type: String) -> bool:
	return type != "FARM" and type != "" and Site.setting(type) == "COUNTRY"


static func _nearest(p: Vector2, arr: Array) -> float:
	var d := INF
	for q in arr:
		d = minf(d, p.distance_to(q))
	return d


static func _draw(d: float, reach: float) -> float:
	return maxf(0.0, 1.0 - d / reach)


static func _seg_d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 <= 0.0:
		return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / l2, 0.0, 1.0))


## Distance (km) from a point to the nearest sea or river tile's edge, looking within two tiles.
static func _water_km(world: WorldState, c: Vector2i) -> float:
	var t := tile_of(c)
	var p := _km(c)
	var d := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var tt := t + Vector2i(dx, dy)
			if Terrain.at(world, tt.x, tt.y) in [Terrain.SEA, "r"]:
				var lo := Vector2(tt.x * 3.0, tt.y * 3.0)
				var q := Vector2(clampf(p.x, lo.x, lo.x + 3.0), clampf(p.y, lo.y, lo.y + 3.0))
				d = minf(d, p.distance_to(q))
	return d


## Why a cell cannot take a building of this type ("" = it can): off the map, unbuildable terrain, taken, next to a
## country building's site, a zone that does not allow it (land law), or a street block that belongs to another town
## (a block belongs to the first area that builds in it, and an area to its town; Maja's AreaStore).
static func blocked(world: WorldState, c: Vector2i, ftype: String, ctx: Dictionary) -> String:
	var t := tile_of(c)
	if t.x < 0 or t.y < 0 or t.x >= Terrain.W or t.y >= Terrain.H:
		return "off the map"
	if (ctx["cells"] as Dictionary).has(_ck(c)):
		return "taken"
	if not Terrain.at(world, t.x, t.y) in ColonyLayout.BUILD_TERRAIN:
		return "cannot build on %s" % String(Terrain.NAMES.get(Terrain.at(world, t.x, t.y), "this"))
	for s in ctx["pts"]["clear"]:
		var sc: Vector2i = s
		if absi(sc.x - c.x) <= KEEP_CLEAR and absi(sc.y - c.y) <= KEEP_CLEAR:
			return "a country building's site"
	if ftype != "" and not Site.zone_allows(world, Site.cell_key(c), ftype):   # the cell's own zone (Anni)
		return "the zone does not allow it"
	var own := AreaStore.area_of_block(world, block_of(c))
	if own != "" and String(ctx.get("tid", "")) != "" and AreaStore.town_of(world, own) != String(ctx["tid"]):
		return "a block of another town"
	return ""


## How much a cell draws a building of this type to a town: {score, parts {the location value's parts (VALUE_PARTS),
## centre, noise}, blocked ("" or why not)}. Draws are weight × (1 − km ÷ reach); penalties likewise, negative; noise
## is fixed per seed and cell. Pure.
static func cell_score(world: WorldState, tid: String, cell, ftype: String = "LANDLORD", ctx: Dictionary = {}) -> Dictionary:
	if ctx.is_empty():
		ctx = _context(world, tid)
	var c := _cell(cell)
	var p := _km(c)
	var own: Dictionary = world.peek("town").get("towns", {}).get(tid, {}).get("cells", {})
	var parts := _value_parts(world, c, ctx, own, _centre_of(world, tid) if own.is_empty() else Vector2i(-1, -1), ftype)
	parts["centre"] = float(W["centre"]) * _draw(p.distance_to(_km(_centre_of(world, tid))), float(REACH_KM["centre"]))
	var u := float(Planet._mix(Planet._mix(int(ctx["salt"]) & 0x7fffffff, c.x + 7919), c.y + 104729) % 10000) / 10000.0
	parts["noise"] = float(W["noise"]) * (u - 0.5)
	var s := 0.0
	for k in parts:
		parts[k] = snappedf(float(parts[k]), 0.001)
		s += float(parts[k])
	return {"cell": _ck(c), "score": snappedf(s, 0.001), "parts": parts, "blocked": blocked(world, c, ftype, ctx)}


## A cell's location value: what a home there is worth against an ordinary cell (the user: "the closer to the coast
## you get the more expensive they get; it can even shift from road to road"). {cell, value_pm (1000 = an ordinary
## cell; VALUE_PER_POINT ‰ a point, at least VALUE_MIN_PM), score, parts (VALUE_PARTS: view of the sea or a river,
## the shore, jobs, school, clinic, shops and bakeries, a road, laid utilities (any built cell); a fast road beside it
## and industry next door count against)}. Per cell; it changes only when something near it changes (no noise).
## Pure. Otto's housing reads it for rents and prices; this only publishes it.
static func value(world: WorldState, cell, ctx: Dictionary = {}) -> Dictionary:
	if ctx.is_empty():
		ctx = _context(world)
	var c := _cell(cell)
	var parts := _value_parts(world, c, ctx, ctx["cells"], Vector2i(-1, -1), "LANDLORD")
	var s := 0.0
	for k in parts:
		parts[k] = snappedf(float(parts[k]), 0.001)
		s += float(parts[k])
	return {"cell": _ck(c), "value_pm": maxi(VALUE_MIN_PM, 1000 + roundi(float(VALUE_PER_POINT) * s)),
		"score": snappedf(s, 0.001), "parts": parts}


## The location parts of a cell. `built`: cells whose utilities are laid ({"fx,fy": ...}); `start`: where they would
## come from when there are none yet (a town's centre), else (-1, -1).
static func _value_parts(world: WorldState, c: Vector2i, ctx: Dictionary, built: Dictionary, start: Vector2i, ftype: String) -> Dictionary:
	var p := _km(c)
	var pts: Dictionary = ctx["pts"]
	var parts := {}
	for k in ["jobs", "school", "clinic", "shops"]:
		parts[k] = float(W[k]) * _draw(_nearest(p, pts[k]), float(REACH_KM[k]))
	# utilities: laid where building already stands (near built cells, else the town's centre)
	var ud := INF
	var own := built
	if start.x >= 0:
		ud = p.distance_to(_km(start))
	else:   # ring by ring outward to the nearest built cell (within the reach)
		var reach := ceili(float(REACH_KM["utilities"]) / CELL_KM)
		for r in reach + 1:
			if float(r) * CELL_KM > ud:
				break
			for dy in range(-r, r + 1):
				var step := 1 if absi(dy) == r else 2 * r
				var dx := -r
				while dx <= r:
					var q := c + Vector2i(dx, dy)
					if own.has(_ck(q)):
						ud = minf(ud, p.distance_to(_km(q)))
					dx += maxi(1, step)
	parts["utilities"] = float(W["utilities"]) * _draw(ud, float(REACH_KM["utilities"]))
	var wk := _water_km(world, c)
	parts["view"] = float(W["view"]) * _draw(wk, float(REACH_KM["view"]))
	parts["water"] = float(W["water"]) * _draw(wk, float(REACH_KM["water"]))
	var rd := INF
	var fast := 0.0
	for sg in ctx["segs"]:
		var d := _seg_d(p, sg[0], sg[1])
		rd = minf(rd, d)
		if d < float(REACH_KM["fast_road"]):
			fast = maxf(fast, _draw(d, float(REACH_KM["fast_road"])) * clampf((float(sg[2]) - 50.0) / 60.0, 0.0, 1.0))
	parts["road"] = float(W["road"]) * _draw(rd, float(REACH_KM["road"]))
	parts["fast_road"] = float(W["fast_road"]) * fast
	parts["industry"] = float(W["industry"]) * _draw(_nearest(p, pts["industry"]), float(REACH_KM["industry"])) \
		if not _industry(ftype) else 0.0
	return parts


# ================================================================== what the motives to build up read

## Homes, land and connection per form: {form: {homes (per cell), storeys, land_m2 (per home), conn_m (per home)}}.
static func form_table() -> Dictionary:
	var out := {}
	for fm in FORMS:
		var f: Dictionary = FORMS[fm]
		out[fm] = {"homes": int(f["homes"]), "storeys": int(f["storeys"]),
			"land_m2": roundi(CELL_KM * CELL_KM * 1e6 / float(f["homes"])), "conn_m": int(f["conn_m"])}
	return out


## A school's, clinic's or workplace's reach: is there room left for homes near it? {fid, type, reach_km, cells
## (buildable cells within reach), free (of them, free for housing), homes (in reach), full (free < FULL_FREE)}.
## "No room left where people want to be" is a motive to build upward there. {} if the building has no place. Pure.
static func catchment(world: WorldState, fid: String, reach_km: float = -1.0) -> Dictionary:
	var wt := Site.what(world, fid)
	if wt.is_empty():
		return {}
	var p := _pos_km(world, fid)
	if p.x < 0.0:
		return {}
	var ty := String(wt["type"])
	var rk := reach_km if reach_km > 0.0 else float(CATCH_KM.get(ty, CATCH_KM[""]))
	var ctx := _context(world)
	var idx: Dictionary = ctx["cells"]
	var c0 := Vector2i(floori(p.x / CELL_KM), floori(p.y / CELL_KM))
	var r := ceili(rk / CELL_KM)
	var n := 0
	var free := 0
	var homes := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := c0 + Vector2i(dx, dy)
			if _km(c).distance_to(p) > rk:
				continue
			var k := _ck(c)
			if idx.has(k):
				n += 1
				homes += int(idx[k][2])
				continue
			var why := blocked(world, c, "LANDLORD", ctx)
			if why == "":
				n += 1
				free += 1
	return {"fid": fid, "type": ty, "reach_km": rk, "cells": n, "free": free, "homes": homes, "full": free < FULL_FREE}


## Where a building of this type would best go in a town: up to n cells, best first, each a cell_score row with its
## tile. The candidates: the free cells next to the town; around its centre while it is empty; and cells near
## workplaces within SEED_KM of the centre (a new neighbourhood at a plant, as Rydebäck). Pure.
static func site_scores(world: WorldState, tid: String, ftype: String = "LANDLORD", n: int = 5) -> Array:
	var ctx := _context(world, tid)
	var rows: Array = []
	for ck in _candidates(world, tid, ctx):
		var r := cell_score(world, tid, ck, ftype, ctx)
		if String(r["blocked"]) == "":
			var t := tile_of(ck)
			r["tile"] = Terrain.key(t.x, t.y)
			rows.append(r)
	rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and String(a["cell"]) < String(b["cell"])))
	return rows.slice(0, n)


static func _candidates(world: WorldState, tid: String, ctx: Dictionary) -> Array:
	var out := {}
	var c0 := _centre_of(world, tid)
	if c0.x < 0:
		return []
	for k in edge_cells(world, tid):
		out[k] = true
	if (world.peek("town").get("towns", {}).get(tid, {}).get("cells", {}) as Dictionary).is_empty():
		for dy in range(-START_R, START_R + 1):
			for dx in range(-START_R, START_R + 1):
				out[_ck(c0 + Vector2i(dx, dy))] = true
	var p0 := _km(c0)
	for q in ctx["pts"]["jobs"]:   # a neighbourhood may start at a workplace
		var qp: Vector2 = q
		if qp.distance_to(p0) > SEED_KM or qp.distance_to(p0) < 1.0:
			continue
		var qc := Vector2i(floori(qp.x / CELL_KM), floori(qp.y / CELL_KM))
		for dy in range(-SEED_CELLS, SEED_CELLS + 1, SEED_CELLS):
			for dx in range(-SEED_CELLS, SEED_CELLS + 1, SEED_CELLS):
				out[_ck(qc + Vector2i(dx, dy))] = true
	return CoreUtil.sorted_keys(out)


# ================================================================== writes

## Allow these forms in a town (or "*", the colony); the first is what a new block is built as. The commander's,
## later the government's or a municipality's decision. Public fact TOWN_FORMS_SET. → "" or why not.
static func set_forms(world: WorldState, tid: String, forms: Array, by: String = "gov") -> String:
	if forms.is_empty():
		return "At least one form"
	for fm in forms:
		if not FORMS.has(String(fm)):
			return "A form is one of %s" % str(FORMS.keys())
	if tid != "*" and _centre_of(world, tid).x < 0:
		return "Unknown town '%s'" % tid
	var tb := _table(world)
	var was := forms_allowed(world, tid)
	tb["policy"][tid] = forms.map(func(x): return String(x))
	_bump(tb)
	world.add_fact({"type": "TOWN_FORMS_SET", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 15, "visibility": "PUBLIC", "data": {"town": tid, "forms": tb["policy"][tid].duplicate(), "was": was, "by": by}})
	Logbook.note(world, "TOWN", tid, "forms set", {"by": by}, {"forms": [was, tb["policy"][tid].duplicate()]})
	return ""


## Rebuild a block in another allowed form (on renovation or replacement): it keeps its best cells and frees or adds
## the rest. → "" or why not.
static func set_form(world: WorldState, fid: String, form: String) -> String:
	var cs := cells_of(world, fid)
	if cs.is_empty():
		return "%s has no cells" % fid
	var tid := town_of(world, fid)
	if not form in forms_allowed(world, tid):
		return "%s is not allowed in %s" % [form, tid]
	var homes := homes_of(world, fid)
	var ftype := String(Site.what(world, fid).get("type", "LANDLORD"))
	var tb := _table(world)
	var cells: Dictionary = tb["towns"][tid]["cells"]
	var c0 := _centre_of(world, tid)
	cs.sort_custom(func(a, b): return _cd(_cell(a), c0) < _cd(_cell(b), c0) or (_cd(_cell(a), c0) == _cd(_cell(b), c0) and String(a) < String(b)))
	var need := _cells_needed(homes, form)
	for i in range(need, cs.size()):
		cells.erase(cs[i])
	var kept: Array = cs.slice(0, need)
	_bump(tb)
	_lay(world, tid, fid, ftype, form, homes, kept, need - kept.size())
	return ""


static func _cd(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _table(world: WorldState) -> Dictionary:
	var tb := world.table("town")
	if not tb.has("towns"):
		tb["towns"] = {}
		tb["policy"] = {}
		tb["rev"] = 0
	return tb


static func _cells_needed(homes: int, form: String) -> int:
	return maxi(1, ceili(float(homes) / float(FORMS[form]["homes"])))


## Put a block's homes into its kept cells and `more` new ones, grown from the best free cells next to them (or the
## best site in the town when it has none yet).
static func _lay(world: WorldState, tid: String, fid: String, ftype: String, form: String, homes: int, kept: Array, more: int) -> void:
	var tb := _table(world)
	var town: Dictionary = tb["towns"][tid]
	var cells: Dictionary = town["cells"]
	var mine: Array = kept.duplicate()
	for ck0 in mine:
		cells[ck0] = [fid, form, 0]
	_bump(tb)
	for _i in more:
		var ctx := _context(world, tid)
		var best := ""
		var bs := -INF
		var cand: Array = []
		if mine.is_empty():
			for r in site_scores(world, tid, ftype, 1):
				cand.append(String(r["cell"]))
		else:
			var nb := {}
			for ck in mine:
				var c := _cell(ck)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					nb[_ck(c + d)] = true
			cand = CoreUtil.sorted_keys(nb)
		for ck in cand:
			var r := cell_score(world, tid, ck, ftype, ctx)
			if String(r["blocked"]) == "" and float(r["score"]) > bs:
				bs = float(r["score"])
				best = String(ck)
		if best == "":
			break
		mine.append(best)
		cells[best] = [fid, form, 0]
		_bump(tb)
	# share the homes over the cells, the fuller cells first
	var cap := int(FORMS[form]["homes"]) if FORMS.has(form) else 0
	var left := homes
	for ck in mine:
		var h := mini(cap, left)
		left -= h
		cells[ck] = [fid, form, h]
	_bump(tb)


## A town gets its grid with its first building ("Below 250 start a gridd anyway"): public fact TOWN_GRID_LAID and a
## Logbook row. → "" or why not.
static func ensure_town(world: WorldState, tid: String) -> String:
	if has_grid(world, tid):
		return ""
	var c0 := _centre_of(world, tid)
	if c0.x < 0:
		return "Unknown town '%s'" % tid
	var tb := _table(world)
	tb["towns"][tid] = {"c": [c0.x, c0.y], "cells": {}}
	_bump(tb)
	world.add_fact({"type": "TOWN_GRID_LAID", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 10, "visibility": "PUBLIC", "data": {"town": tid, "centre": [c0.x, c0.y]}})
	Logbook.note(world, "TOWN", tid, "grid laid", {"centre": [c0.x, c0.y]}, {})
	return ""


## Lay a building on the grid from `first` (a free cell): a town building takes one cell; a plant with homes takes as
## many cells as its homes need in the town's first allowed form, grown from the first by the same scoring. Each block
## it touches that nobody owns yet joins the neighbourhood Maja's AreaStore picks (area_for_new_block, claim_block).
## A town's id is its founding area's id (AreaStore.town_of). → "" or why not.
static func lay(world: WorldState, tid: String, id: String, ftype: String, first: String, homes: int = 0) -> String:
	var why := ensure_town(world, tid)
	if why != "":
		return why
	var c := _cell(first)
	var bl := blocked(world, c, ftype, _context(world, tid))
	if bl != "":
		return "Cell %s: %s" % [first, bl]
	var form := ""
	var need := 1
	if homes > 0:
		form = String(forms_allowed(world, tid)[0])
		need = _cells_needed(homes, form)
	_lay(world, tid, id, ftype, form, homes, [_ck(c)], need - 1)
	for ck in cells_of(world, id):
		var blk := block_of(ck)
		if AreaStore.area_of_block(world, blk) == "":
			AreaStore.claim_block(world, AreaStore.area_for_new_block(world, tid, blk), blk)
	return ""


## A plan's cells become its plant's (Site.open).
static func rekey(world: WorldState, from_id: String, to_id: String) -> void:
	var tb := _table(world)
	for tid in tb["towns"]:
		var cells: Dictionary = tb["towns"][tid]["cells"]
		for ck in cells:
			if String(cells[ck][0]) == from_id:
				cells[ck][0] = to_id
	_bump(tb)


## Free a building's cells (Site.release). A block left with no cells goes back to free (AreaStore.release_block): a
## plan given up has built nothing there.
static func free_cells(world: WorldState, id: String) -> void:
	var tb := _table(world)
	var touched := {}
	for tid in tb["towns"]:
		var cells: Dictionary = tb["towns"][tid]["cells"]
		for ck in CoreUtil.sorted_keys(cells):
			if String(cells[ck][0]) == id:
				cells.erase(ck)
				touched[block_of(ck)] = true
	_bump(tb)
	for blk in CoreUtil.sorted_keys(touched):
		var empty := true
		for ck in block_cells(blk):
			if (_index(world)["cells"] as Dictionary).has(ck):
				empty = false
				break
		if empty:
			AreaStore.release_block(world, blk)
