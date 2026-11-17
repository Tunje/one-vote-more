class_name TownGrid
extends RefCounted
## Terra (planning/design-town-grid.md; the user's go via Wilma 2026-11-15), flag TOWN_GRID: the groundwork for towns
## on a fine grid. Opt-in; nothing reads it yet (the layout, the economy and the map keep the 3 km tile).
## - Each settlement gets a grid of 100 m cells (30 × 30 to a 3 km tile) in global fine coordinates: cell (fx, fy) lies
##   in tile (fx ÷ 30, fy ÷ 30), so two towns cannot overlap.
## - Housing blocks take cells in a form (HOUSE / APARTMENT / TOWER); town buildings (shops, clinic, school, care,
##   offices...) take one cell. Only occupied cells are stored; streets are derived.
## - Where a town grows is scored per cell, by what draws people (jobs, school, clinic, shops, laid utilities, water,
##   a road, the centre) less what keeps them away (a fast road, industry next door), with a little randomness per seed
##   (the user: "not perfect circular towns"). The parts stay visible for a site case.
## - The allowed forms are a policy (the commander's, later the government's or a municipality's): per town or "*".
## - The next level only when needed (the user: "like the main map, maps should not become the next level until
##   necessary"): a settlement has no grid until it is due (grid_due: enough homes, or homes and several town buildings
##   competing for land; or designated, step_up). Until then it is homes on its country tile, nothing stored, and the
##   queries give the tile-level answer. Likewise no high-rise exists in a town until it has apartments.
## Table "town" (only with the flag): {"towns": {tid: {"c": [fx, fy], "cells": {"fx,fy": [fid, form, homes]}}},
##   "policy": {tid | "*": [form, ...]}, "rev": int}.

const FLAG := "TOWN_GRID"
const PER_TILE := 30          # cells along a 3 km tile
const CELL_KM := 0.1
## homes: per cell; storeys; conn_m: street, pipe and cable per home inside the cell's street block.
const FORMS := {
	"HOUSE": {"homes": 10, "storeys": 2, "conn_m": 15},
	"APARTMENT": {"homes": 60, "storeys": 4, "conn_m": 3},
	"TOWER": {"homes": 200, "storeys": 15, "conn_m": 1},
}
const DEFAULT_FORMS := ["HOUSE"]
const BLOCK_HOMES := 50       # EconRulesHousing.BLOCK_UNITS (× the block's scale)
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
const SHOP_TYPES := ["RETAIL", "BAKERY", "FAMBAKERY", "COMFORT"]
const SEED_KM := 12.0         # a new neighbourhood may start at a workplace this close to the centre
const SEED_CELLS := 6         # ... at cells this far from it (a 3 × 3 sample, every SEED_CELLS cells)
const KEEP_CLEAR := 2         # cells around a country building's site (its tile's middle) that homes do not take
const START_R := 5            # an empty town's candidates: cells this close to its centre
## When a settlement gets its grid: GRID_HOMES homes (about 500 adults), or GRID_SOME_HOMES homes with GRID_BUILDINGS
## town buildings of at least two kinds (several uses competing for the same land), or step_up (designated a
## municipality; the user's floor for that is about 1,000 adults).
const GRID_HOMES := 250
const GRID_SOME_HOMES := 100
const GRID_BUILDINGS := 3

static var _cache := {}


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has(FLAG) and not (world.meta.get("off", []) as Array).has(FLAG)


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
	for tid in EconUtil.sorted_keys(towns):
		var cs: Dictionary = towns[tid]["cells"]
		for ck in EconUtil.sorted_keys(cs):
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


## A block's form; a block in a settlement without a grid is houses on its tile ("HOUSE"). "" if not housing.
static func form_of(world: WorldState, fid: String) -> String:
	var cs := cells_of(world, fid)
	if not cs.is_empty():
		return String(_index(world)["cells"][cs[0]][1])
	return "HOUSE" if String(world.peek("facility").get(fid, {}).get("type", "")) == "HOUSING" else ""


## Does the town have its fine grid yet?
static func has_grid(world: WorldState, tid: String) -> bool:
	return world.peek("town").get("towns", {}).has(tid)


## Is a settlement due its grid? {due, why ("homes" | "buildings" | ""), homes, buildings, kinds}. Pure.
static func grid_due(world: WorldState, tid: String) -> Dictionary:
	var homes := 0
	var kinds := {}
	var nb := 0
	var fac: Dictionary = world.peek("facility")
	for fid in EconUtil.sorted_keys(fac):
		var f: Dictionary = fac[fid]
		var ty := String(f.get("type", ""))
		if ty != "HOUSING" and Siting.kind_of(ty) != "TOWN":
			continue
		if town_for(world, f) != tid:
			continue
		if ty == "HOUSING":
			homes += _homes(f)
		else:
			nb += 1
			kinds[ty] = true
	var why := ""
	if homes >= GRID_HOMES:
		why = "homes"
	elif homes >= GRID_SOME_HOMES and nb >= GRID_BUILDINGS and kinds.size() >= 2:
		why = "buildings"
	return {"due": why != "", "why": why, "homes": homes, "buildings": nb, "kinds": kinds.size()}


## Which town a building of this district or area belongs to: the area's settlement, else the district's first. "".
static func town_for(world: WorldState, f: Dictionary) -> String:
	var setl := ColonyLayout.settlements(world)
	if f.has("area"):
		for s in setl:
			if String(s["id"]) == String(f["area"]):
				return String(s["id"])
	for s in setl:
		if String(s["district"]) == String(f.get("district", "")):
			return String(s["id"])
	return ""


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


## A building's mean distance to its town centre, km (straight). Without a grid, the tile-level answer: from its
## country tile to its settlement's tile. -1.0 if unknown.
static func centre_km(world: WorldState, fid: String) -> float:
	var cs := cells_of(world, fid)
	if cs.is_empty():
		var f: Dictionary = world.peek("facility").get(fid, {})
		var tid0 := town_for(world, f) if not f.is_empty() else ""
		var p := _pos_km(world, fid)
		if tid0 == "" or p.x < 0.0:
			return -1.0
		return p.distance_to(_km(_centre_of(world, tid0)))
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
	return EconUtil.sorted_keys(out)


## The 3 km tiles a town covers: {"x,y": homes}. Without a grid: its homes on its settlement tile.
static func footprint(world: WorldState, tid: String) -> Dictionary:
	var out := {}
	if not has_grid(world, tid):
		var c0 := _centre_of(world, tid)
		if c0.x < 0:
			return out
		var t0 := tile_of(c0)
		out[Terrain.key(t0.x, t0.y)] = int(grid_due(world, tid)["homes"])
		return out
	var cs: Dictionary = world.peek("town").get("towns", {}).get(tid, {}).get("cells", {})
	for ck in EconUtil.sorted_keys(cs):
		var t := tile_of(ck)
		var k := Terrain.key(t.x, t.y)
		out[k] = int(out.get(k, 0)) + int(cs[ck][2])
	return out


## Homes in a 3 km tile: the cells of towns with a grid, and the blocks without cells on their own country tile.
static func homes_in_tile(world: WorldState, tile) -> int:
	var t := ColonyLayout.as_tile(tile)
	var n := 0
	var idx: Dictionary = _index(world)
	for ck in idx["cells"]:
		if tile_of(ck) == t:
			n += int(idx["cells"][ck][2])
	var fac: Dictionary = world.peek("facility")
	var ft := ColonyLayout.facility_tiles(world)
	for fid in ft:
		if String(fac.get(fid, {}).get("type", "")) == "HOUSING" and not (idx["of"] as Dictionary).has(fid) \
				and ColonyLayout.as_tile(ft[fid]) == t:
			n += _homes(fac[fid])
	return n


# ================================================================== scoring

## What the scoring reads once per call: the places that draw people or keep them away, in km, and the roads.
static func _context(world: WorldState) -> Dictionary:
	var fac: Dictionary = world.peek("facility")
	var ft := ColonyLayout.facility_tiles(world)
	var idx: Dictionary = _index(world)
	var pts := {"jobs": [], "school": [], "clinic": [], "shops": [], "industry": [], "clear": []}
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty():
			continue
		var ty := String(f.get("type", ""))
		var cs: Array = (idx["of"] as Dictionary).get(fid, [])
		var p := _km(_cell(cs[0])) if not cs.is_empty() else _tile_km(ColonyLayout.as_tile(ft[fid]))
		if ty != "HOUSING":
			pts["jobs"].append(p)
		match ty:
			"SCHOOL":
				pts["school"].append(p)
			"CLINIC":
				pts["clinic"].append(p)
		if ty in SHOP_TYPES:
			pts["shops"].append(p)
		var kd := Siting.kind_of(ty)
		if kd == "INDUSTRY":
			pts["industry"].append(p)
		if kd in ["INDUSTRY", "FARMLAND"] and cs.is_empty():
			pts["clear"].append(centre_cell(ft[fid]))
	pts["jobs"].append(_tile_km(Terrain.landing(world)))   # the port
	var segs: Array = []   # [a km, b km, kmh]
	var links := Transport._links(world)
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var path: Array = l.get("path", [])
		var v := RoadSafety.kmh(world, l)
		for i in range(1, path.size()):
			segs.append([_tile_km(Transport.int_tile(int(path[i - 1]))), _tile_km(Transport.int_tile(int(path[i]))), v])
	return {"pts": pts, "segs": segs, "cells": idx["cells"], "salt": world.rng.derive_seed("town.grid")}


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
## country building's site, or land SITING reserves for another use.
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
	if Siting.on(world) and not Siting.fits(Siting.use_at(world, t), ftype):
		return "land reserved for %s" % Siting.use_at(world, t).to_lower()
	return ""


## How much a cell draws a building of this type to a town: {score, parts {the location value's parts (VALUE_PARTS),
## centre, noise}, blocked ("" or why not)}. Draws are weight × (1 − km ÷ reach); penalties likewise, negative; noise
## is fixed per seed and cell. Pure.
static func cell_score(world: WorldState, tid: String, cell, ftype: String = "HOUSING", ctx: Dictionary = {}) -> Dictionary:
	if ctx.is_empty():
		ctx = _context(world)
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
	var parts := _value_parts(world, c, ctx, ctx["cells"], Vector2i(-1, -1), "HOUSING")
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
		if Siting.kind_of(ftype) != "INDUSTRY" else 0.0
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
	var f: Dictionary = world.peek("facility").get(fid, {})
	if f.is_empty():
		return {}
	var p := _pos_km(world, fid)
	if p.x < 0.0:
		return {}
	var ty := String(f.get("type", ""))
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
			var why := blocked(world, c, "HOUSING", ctx)
			if why == "":
				n += 1
				free += 1
	return {"fid": fid, "type": ty, "reach_km": rk, "cells": n, "free": free, "homes": homes, "full": free < FULL_FREE}


## Where a building of this type would best go in a town: up to n cells, best first, each a cell_score row with its
## tile. The candidates: the free cells next to the town; around its centre while it is empty; and cells near
## workplaces within SEED_KM of the centre (a new neighbourhood at a plant, as Rydebäck). Pure.
static func site_scores(world: WorldState, tid: String, ftype: String = "HOUSING", n: int = 5) -> Array:
	var ctx := _context(world)
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
	return EconUtil.sorted_keys(out)


# ================================================================== writes

## Allow these forms in a town (or "*", the colony); the first is what a new block is built as. The commander's,
## later the government's or a municipality's decision. Public fact TOWN_FORMS_SET. → "" or why not.
static func set_forms(world: WorldState, tid: String, forms: Array, by: String = "gov") -> String:
	if not on(world):
		return "Town grids are not in this game"
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
	return ""


## Rebuild a block in another allowed form (on renovation or replacement): it keeps its best cells and frees or adds
## the rest. → "" or why not.
static func set_form(world: WorldState, fid: String, form: String) -> String:
	if not on(world):
		return "Town grids are not in this game"
	var cs := cells_of(world, fid)
	if cs.is_empty():
		return "%s has no cells" % fid
	var tid := town_of(world, fid)
	if not form in forms_allowed(world, tid):
		return "%s is not allowed in %s" % [form, tid]
	var f: Dictionary = world.peek("facility").get(fid, {})
	var homes := _homes(f)
	var tb := _table(world)
	var cells: Dictionary = tb["towns"][tid]["cells"]
	var c0 := _centre_of(world, tid)
	cs.sort_custom(func(a, b): return _cd(_cell(a), c0) < _cd(_cell(b), c0) or (_cd(_cell(a), c0) == _cd(_cell(b), c0) and String(a) < String(b)))
	var need := _cells_needed(homes, form)
	for i in range(need, cs.size()):
		cells.erase(cs[i])
	var kept: Array = cs.slice(0, need)
	_bump(tb)
	_lay(world, tid, fid, form, homes, kept, need - kept.size())
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


static func _homes(f: Dictionary) -> int:
	return maxi(1, roundi(float(BLOCK_HOMES) * EconUtil.fscale(f)))


static func _cells_needed(homes: int, form: String) -> int:
	return maxi(1, ceili(float(homes) / float(FORMS[form]["homes"])))


## Put a block's homes into its kept cells and `more` new ones, grown from the best free cells next to them (or the
## best site in the town when it has none yet).
static func _lay(world: WorldState, tid: String, fid: String, form: String, homes: int, kept: Array, more: int) -> void:
	var tb := _table(world)
	var town: Dictionary = tb["towns"][tid]
	var cells: Dictionary = town["cells"]
	var mine: Array = kept.duplicate()
	var ftype := String(world.peek("facility").get(fid, {}).get("type", "HOUSING"))
	for _i in more:
		var ctx := _context(world)
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
			cand = EconUtil.sorted_keys(nb)
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


## Give a settlement its grid now (it is due, or it was designated a municipality): the homes and town buildings
## already there are laid out on it at once, in the order they were built, by the same scoring. Public fact
## TOWN_GRID_LAID. → "" or why not.
static func step_up(world: WorldState, tid: String, why: String = "designated") -> String:
	if not on(world):
		return "Town grids are not in this game"
	if has_grid(world, tid):
		return "%s has its grid" % tid
	var c0 := _centre_of(world, tid)
	if c0.x < 0:
		return "Unknown town '%s'" % tid
	var tb := _table(world)
	tb["towns"][tid] = {"c": [c0.x, c0.y], "cells": {}}
	_bump(tb)
	_place_new(world, tid)
	var due := grid_due(world, tid)
	world.add_fact({"type": "TOWN_GRID_LAID", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 10, "visibility": "PUBLIC", "data": {"town": tid, "why": why, "homes": int(due["homes"]),
			"buildings": int(due["buildings"]), "cells": (tb["towns"][tid]["cells"] as Dictionary).size()}})
	return ""


## Monthly (NATURE tick): blocks and town buildings that are gone free their cells; a settlement that is due gets its
## grid; in towns with a grid, new housing blocks take cells in their form (the block's "form" if allowed there, else
## the first allowed) and new town buildings take one cell.
static func step_month(world: WorldState) -> void:
	if not on(world):
		return
	var tb := _table(world)
	var fac: Dictionary = world.peek("facility")
	for tid in EconUtil.sorted_keys(tb["towns"]):
		var cells: Dictionary = tb["towns"][tid]["cells"]
		for ck in EconUtil.sorted_keys(cells):
			if not fac.has(String(cells[ck][0])):
				cells.erase(ck)
				_bump(tb)
	for s in ColonyLayout.settlements(world):
		var sid := String(s["id"])
		if has_grid(world, sid):
			_place_new(world, sid)
		else:
			var due := grid_due(world, sid)
			if bool(due["due"]):
				step_up(world, sid, String(due["why"]))


## Lay out the town's housing blocks and town buildings that have no cells yet, in the order they were built.
static func _place_new(world: WorldState, tid: String) -> void:
	var fac: Dictionary = world.peek("facility")
	var have: Dictionary = _index(world)["of"]
	for fid in _ordered(fac):
		if have.has(fid):
			continue
		var f: Dictionary = fac[fid]
		var ty := String(f.get("type", ""))
		if ty != "HOUSING" and Siting.kind_of(ty) != "TOWN":
			continue
		if town_for(world, f) != tid:
			continue
		if ty == "HOUSING":
			var allowed := forms_allowed(world, tid)
			var form := String(f.get("form", ""))
			if not form in allowed:
				form = String(allowed[0])
			var homes := _homes(f)
			_lay(world, tid, String(fid), form, homes, [], _cells_needed(homes, form))
		else:
			_lay(world, tid, String(fid), "", 0, [], 1)


## Facilities in the order they were made (id number), so a town grows in the order its buildings came.
static func _ordered(fac: Dictionary) -> Array:
	var ids: Array = fac.keys()
	ids.sort_custom(_id_less)
	return ids


static func _id_less(a, b) -> bool:
	var pa := String(a).get_slice(":", 0)
	var pb := String(b).get_slice(":", 0)
	if pa != pb:
		return pa < pb
	return int(String(a).get_slice(":", 1)) < int(String(b).get_slice(":", 1))
