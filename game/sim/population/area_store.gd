class_name AreaStore
extends RefCounted
## M13 (planning/spec-areas-v1.md §2–§4): areas = housing blocks (population.md §3) built on the terrain map.
## An area is a set of residential tiles. Building housing next to an area extends it; building it apart founds
## a new one. Areas split (too big, or an enclave diverging inside) and merge, with parent ids kept for history.
## People live in PopStore leaves keyed by the area id (key part "hb"); splits move them with PopStore transfers,
## so population is conserved and beliefs travel.
##
## Table "area": id -> {id, name, kind, tiles: ["x,y"], town, district, founded, parents, children, status}
## town: the id of the town (TownGrid's town id = the area that founded it) the area is a neighbourhood of. An area
## founded on its own is its own town; an area split off by blocks stays in its parent's town (Terra's review).
## Table "area_block": block -> area id. The one record of which town-grid street blocks (400 m, "b:bx,by", Terra's
## TownGrid.block_of) an area is made of, besides its country tiles (3 km). A block belongs to exactly one area: the
## first area to build in it owns it (Maja and Terra, 2026-11-17). Written by claim_block, split and merge.
## Tile uses (Terrain "uses"): {"area": id, "units": int, "by": GOV|COMPANY|PRIVATE, "band": "" | "I4"…}
##
## Hooks (static, set by other systems at startup; not saved):
##   change_listeners: Callables (world, moves: [{from, to, band, persons}]) called after people move between areas
##                     (Bob: pool savings follow people)
##   district_resolver: Callable (world, area_id) -> district id for a newly founded area (Anni: law decides)

const KINDS := ["SETTLEMENT", "CAMP", "VILLAGE", "ENCLAVE", "SHELTER"]
## An area splits where its homes reach farther than a school's catchment (TownGrid.CATCH_KM["SCHOOL"], Terra's one
## number): "a neighbourhood is what's within walking distance of its school" (Maja and Terra, 2026-11-17). No headcount.
const ENCLAVE_MIN_TILES := 2      # contiguous private tiles that can break away as an enclave
const NAME_PARTS := ["Heights", "Bend", "Rise", "Flats", "Hollow", "Gate", "Field", "Row", "Park", "Crossing", "Ridge", "Green"]

static var change_listeners: Array = []
static var district_resolver: Callable = Callable()


# ======================================================================= reads

static func areas(world: WorldState, active_only: bool = true) -> Array:
	var out: Array = []
	var ids: Array = world.peek("area").keys()
	ids.sort_custom(func(a, b): return int(String(a).get_slice(":", 1)) < int(String(b).get_slice(":", 1)))
	for id in ids:
		var a: Dictionary = world.peek("area")[id]
		if not active_only or a["status"] == "ACTIVE":
			out.append(a)
	return out


static func get_area(world: WorldState, id: String) -> Dictionary:
	return world.peek("area").get(id, {})


static func tiles_of(world: WorldState, id: String) -> Array:
	return get_area(world, id).get("tiles", []).map(func(k): return _vec(k))


## In tile units. An area with homes on the town grid: the homes-weighted middle of its blocks; else its tiles' middle.
static func centroid(world: WorldState, id: String) -> Vector2:
	var hc := _homes_centre_km(world, id)
	if hc.x >= 0.0:
		return hc / (TownGrid.CELL_KM * float(TownGrid.PER_TILE))
	var ts := tiles_of(world, id)
	var c := Vector2.ZERO
	for t in ts:
		c += Vector2(t)
	return c / maxf(1.0, float(ts.size()))


static func area_of(world: WorldState, tile: Vector2i) -> String:
	return String(Terrain.use_at(world, tile.x, tile.y).get("area", ""))


## Homes in the area: those in its town-grid blocks (Terra's cells, the one record of a home), plus homes recorded on
## its country tiles. Tile "units" are ONLY homes that stand on no town grid (place_housing; no game code writes them
## since the town grid is on, tests and tools still do). A home laid in a cell is never also written as tile units.
static func capacity(world: WorldState, id: String) -> int:
	var c := 0
	for b in blocks_of(world, id):
		c += TownGrid.block_homes(world, b)
	for t in tiles_of(world, id):
		c += int(Terrain.use_at(world, t.x, t.y).get("units", 0))
	return c


## The middle of a street block in km (global fine coordinates x CELL_KM).
static func _block_mid_km(block: String) -> Vector2:
	var p := block.trim_prefix("b:").split(",")
	var m := float(TownGrid.BLOCK_CELLS) * 0.5
	return Vector2((float(p[0]) * TownGrid.BLOCK_CELLS + m) * TownGrid.CELL_KM, (float(p[1]) * TownGrid.BLOCK_CELLS + m) * TownGrid.CELL_KM)


## Homes-weighted middle (km) of an area's blocks with homes; (-1, -1) when it has none.
static func _homes_centre_km(world: WorldState, id: String) -> Vector2:
	var c := Vector2.ZERO
	var n := 0
	for b in blocks_of(world, id):
		var h := TownGrid.block_homes(world, b)
		if h > 0:
			c += _block_mid_km(b) * float(h)
			n += h
	return c / float(n) if n > 0 else Vector2(-1.0, -1.0)


static func residents(world: WorldState, id: String) -> int:
	return PopStore.count(world, {"hb": id})


## Area (other than `exclude`) sharing an edge with this tile, or "".
static func adjacent_area(world: WorldState, tile: Vector2i, exclude: String = "") -> String:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var a := area_of(world, tile + d)
		if a != "" and a != exclude and get_area(world, a).get("status", "") == "ACTIVE":
			return a
	return ""


## Nearest active area to a tile by centroid distance (tiles), or "".
static func nearest_area(world: WorldState, tile: Vector2i, exclude: String = "") -> String:
	var best := ""
	var bd := INF
	for a in areas(world):
		if a["id"] == exclude:
			continue
		var d := centroid(world, a["id"]).distance_to(Vector2(tile))
		if d < bd:
			bd = d
			best = a["id"]
	return best


# ======================================================================= writes

## Housing built on a tile: extends the adjacent area or founds a new one. Returns the area id ("" if the tile
## is taken or not buildable). built_by: GOV | COMPANY | PRIVATE; band: the private builder's income band.
## A tile an area has claimed with nothing on it yet (the Landing's tile at a new game) takes homes for that area.
static func place_housing(world: WorldState, tile: Vector2i, units: int, built_by: String = "GOV", band: String = "", name: String = "") -> String:
	var u0 := Terrain.use_at(world, tile.x, tile.y)
	var claimed := String(u0.get("area", "")) if u0.size() == 1 else ""
	if (not u0.is_empty() and claimed == "") or not (Terrain.at(world, tile.x, tile.y) in Terrain.BUILDABLE_HOUSING):
		return ""
	var id := claimed
	if id == "":
		id = adjacent_area(world, tile)
		if id == "":
			var kind: String = {"GOV": "SETTLEMENT", "COMPANY": "CAMP", "PRIVATE": "ENCLAVE"}.get(built_by, "SETTLEMENT")
			id = found(world, [tile], kind, name)
		else:
			world.table("area")[id]["tiles"].append(Terrain.key(tile.x, tile.y))
	Terrain.set_use(world, tile.x, tile.y, {"area": id, "units": units, "by": built_by, "band": band})
	return id


## A new area on the given tiles (tiles claimed with 0 units; housing sets units).
static func found(world: WorldState, tiles: Array, kind: String, name: String = "", parents: Array = []) -> String:
	var id := world.new_id("hb")
	var keys: Array = tiles.map(func(t): return Terrain.key(t.x, t.y))
	var a := {"id": id, "name": name if name != "" else _name(world, tiles[0], kind), "kind": kind, "tiles": keys, "town": id,
		"district": "", "founded": world.month, "parents": parents.duplicate(), "children": [], "status": "ACTIVE"}
	world.table("area")[id] = a
	for t in tiles:
		var u := Terrain.use_at(world, t.x, t.y).duplicate()
		u["area"] = id
		Terrain.set_use(world, t.x, t.y, u)
	if not parents.is_empty():
		a["district"] = String(get_area(world, parents[0]).get("district", ""))
	elif district_resolver.is_valid():
		a["district"] = String(district_resolver.call(world, id))
	else:
		var near := nearest_area(world, tiles[0], id)
		a["district"] = String(get_area(world, near).get("district", "")) if near != "" else ""
	world.add_fact({"type": "POP_AREA_FOUNDED", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 30,
		"visibility": "PUBLIC", "data": {"area": id, "name": a["name"], "kind": kind, "parents": parents}})
	return id


## A new game: ONE area, the Landing, on the landfall tile (the user, 9.12: "no sectors beyond landfallpoint").
## Nothing is built on it yet (homes come with build step 2). Returns the id of the area on the landfall tile; founds
## it only when no area exists at all.
static func found_landing(world: WorldState) -> String:
	if not world.peek("area").is_empty():
		return area_of(world, Terrain.landing(world))
	return found(world, [Terrain.landing(world)], "SETTLEMENT", "Landing")


## The town an area belongs to (its own id for an area that is its own town).
static func town_of(world: WorldState, id: String) -> String:
	return String(get_area(world, id).get("town", id)) if not get_area(world, id).is_empty() else ""


## The active areas (neighbourhoods) of a town, sorted.
static func areas_of_town(world: WorldState, town: String) -> Array:
	var out: Array = []
	for a in areas(world):
		if town_of(world, String(a["id"])) == town:
			out.append(String(a["id"]))
	return out


## Which neighbourhood a new block of `town` joins: the area owning the nearest block of that town already claimed
## (by block middle; ties by area id), else the town's founding area if active, else its first active area, else "".
## Terra's TownGrid.lay calls it before claim_block.
static func area_for_new_block(world: WorldState, town: String, block: String) -> String:
	var mine := areas_of_town(world, town)
	if mine.is_empty():
		return ""
	var at := _block_mid_km(block)
	var best := ""
	var bd := INF
	for a in mine:
		for b in blocks_of(world, a):
			var d := _block_mid_km(String(b)).distance_to(at)
			if d < bd - 0.0001 or (absf(d - bd) <= 0.0001 and a < best):
				bd = d
				best = a
	if best != "":
		return best
	return town if town in mine else String(mine[0])


## The area owning town-grid block `block` ("b:bx,by"), or "".
static func area_of_block(world: WorldState, block: String) -> String:
	return String(world.peek("area_block").get(block, ""))


## The blocks of area `id`, sorted.
static func blocks_of(world: WorldState, id: String) -> Array:
	var out: Array = []
	var ab: Dictionary = world.peek("area_block")
	for b in ab:
		if String(ab[b]) == id:
			out.append(b)
	out.sort()
	return out


## Area `id` builds in `block`: the block becomes its own unless another area already owns it (the first to build
## there keeps it). Returns the owning area's id ("" if `id` is not an active area).
static func claim_block(world: WorldState, id: String, block: String) -> String:
	var owner := area_of_block(world, block)
	if owner != "":
		return owner
	if String(world.peek("area").get(id, {}).get("status", "")) != "ACTIVE":
		return ""
	world.table("area_block")[block] = id
	return id


## A block with nothing left in it goes back to free (Terra's TownGrid.free_cells calls it when the last cell of a
## block is freed, e.g. a plan given up before anything was built). Returns the area that owned it ("" if none).
static func release_block(world: WorldState, block: String) -> String:
	var owner := area_of_block(world, block)
	if owner != "":
		world.table("area_block").erase(block)
		Logbook.note(world, "AREA", owner, "block released", {"block": block}, {"blocks": [1, 0]})
	return owner


## Law is the single writer of district membership (Anni: districting acts).
static func set_district(world: WorldState, id: String, district: String) -> void:
	if world.peek("area").has(id):
		world.table("area")[id]["district"] = district


## Split `tiles_b` (keys or Vector2i) out of area `id` into a new area. Residents follow the housing units, or,
## for an enclave, the given income bands move first (up to the new area's capacity). Returns the new id.
static func split(world: WorldState, id: String, tiles_b: Array, kind_b: String, reason: String, bands_first: Array = []) -> String:
	var a: Dictionary = world.table("area")[id]
	var keys_b: Array = tiles_b.map(func(t): return t if typeof(t) == TYPE_STRING else Terrain.key(t.x, t.y))
	var cap_all := capacity(world, id)
	var vecs: Array = keys_b.map(func(k): return _vec(k))
	var new_id := found(world, vecs, kind_b, "", [id])
	for k in keys_b:
		a["tiles"].erase(k)
	for bk in blocks_of(world, id):   # the street blocks on the child's tiles go with them
		var t := TownGrid.tile_of(TownGrid.block_cells(bk)[0])
		if Terrain.key(t.x, t.y) in keys_b:
			world.table("area_block")[bk] = new_id
	a["children"].append(new_id)
	var moves := _move_share(world, id, new_id, cap_all, bands_first)
	world.add_fact({"type": "POP_AREA_SPLIT", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"area": id, "new": new_id, "reason": reason, "moved": _moved(moves)}})
	Logbook.note(world, "AREA", new_id, "split from %s (%s)" % [id, reason], {"homes_before": cap_all},
		{"tiles": [0, keys_b.size()], "homes": [0, capacity(world, new_id)], "persons": [0, _moved(moves)]}, id)
	return new_id


## TENANCY (step 7, agreed with Otto 2026-11-17): who lives in whose homes will be held once, in the landlord's company
## record (slots {plant: {pool id: households}}), written only by the household side. A split changes the movers' pool
## ids (the area changes), so it must move their tenancies to the new pool ids in the same step.
## People of `id` follow the homes into `new_id`: its share of the homes (cap_all = the homes before the split), by
## income band so every band keeps its share in both parts; or, for an enclave, the given bands first, up to its homes.
static func _move_share(world: WorldState, id: String, new_id: String, cap_all: int, bands_first: Array = []) -> Array:
	var cap_b := capacity(world, new_id)
	var total := residents(world, id)
	var want := int(round(float(total) * float(cap_b) / maxf(1.0, float(cap_all))))
	var moves: Array = []
	if not bands_first.is_empty():
		for b in bands_first:
			var have := _movable(world, id, b)
			var k := mini(have, cap_b - _moved(moves))
			if k > 0:
				k = _move_movable(world, id, b, k, new_id)
				moves.append({"from": id, "to": new_id, "band": b, "persons": k})
	else:
		# proportional by band, largest remainder, so every band keeps its share in both parts
		var bands: Array = PopStore.INCOME_BANDS
		var w: Array = bands.map(func(b): return _movable(world, id, b))
		var parts := CoreUtil.split_lr(want, w)
		for i in bands.size():
			var k2 := mini(int(parts[i]), int(w[i]))
			if k2 > 0:
				k2 = _move_movable(world, id, bands[i], k2, new_id)
				moves.append({"from": id, "to": new_id, "band": bands[i], "persons": k2})
	_notify(world, moves)
	return moves


## People of a band in an area who move with a split: everyone but owners' households (occupation BUSINESS_OWNER: a
## founder and their family stay where their record keeps them; Terra's review).
static func _movable(world: WorldState, id: String, band: String) -> int:
	return PopStore.count(world, {"hb": id, "inc": band}) - PopStore.count(world, {"hb": id, "inc": band, "occ": "BUSINESS_OWNER"})


## Moves k of them, shared over the occupations in proportion (largest remainder). Returns persons moved.
static func _move_movable(world: WorldState, id: String, band: String, k: int, new_id: String) -> int:
	var occs: Array = PopStore.OCCUPATIONS.filter(func(o): return o != "BUSINESS_OWNER")
	var w: Array = occs.map(func(o): return PopStore.count(world, {"hb": id, "inc": band, "occ": o}))
	var parts := CoreUtil.split_lr(k, w)
	var moved := 0
	for i in occs.size():
		if int(parts[i]) > 0:
			moved += PopStore.move_group(world, {"hb": id, "inc": band, "occ": occs[i]}, int(parts[i]), {"hb": new_id}, "AREA_SPLIT")
	return moved


## Split the town-grid blocks `blocks_b` out of area `id` into a new area (a neighbourhood of the same town). Its
## country tile is the tile its first block lies in, shared with the parent (the tile stays the parent's on the map).
## People follow the homes. Returns the new id.
static func split_blocks(world: WorldState, id: String, blocks_b: Array, reason: String, why: Dictionary = {}) -> String:
	var a: Dictionary = world.table("area")[id]
	var cap_all := capacity(world, id)
	var bs: Array = blocks_b.duplicate()
	bs.sort()
	var t := TownGrid.tile_of(TownGrid.block_cells(String(bs[0]))[0])
	var new_id := world.new_id("hb")
	world.table("area")[new_id] = {"id": new_id, "name": _name(world, t, "SETTLEMENT"), "kind": "SETTLEMENT",
		"tiles": [Terrain.key(t.x, t.y)], "town": town_of(world, id), "district": String(a.get("district", "")), "founded": world.month,
		"parents": [id], "children": [], "status": "ACTIVE"}
	for b in bs:
		world.table("area_block")[String(b)] = new_id
	a["children"].append(new_id)
	var moves := _move_share(world, id, new_id, cap_all)
	world.add_fact({"type": "POP_AREA_SPLIT", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"area": id, "new": new_id, "reason": reason, "moved": _moved(moves)}})
	var w := why.duplicate()
	w["homes_before"] = cap_all
	Logbook.note(world, "AREA", new_id, "split from %s (%s)" % [id, reason], w,
		{"blocks": [0, bs.size()], "homes": [0, capacity(world, new_id)], "persons": [0, _moved(moves)]}, id)
	return new_id


## Where area `id` should split by reach, or {}: when a block with homes lies farther than a school's reach from the
## homes-weighted centre. The cut is one of TownGrid.boundaries that leaves homes on both sides: the strongest kind of
## boundary (river, fast road, main street, street), and within a kind the one that leaves both parts most compact
## (the smallest distance from a part's homes centre to its farthest block with homes), then Terra's order. The side
## fewer homes leaves. {"blocks": [...], "cut": {...}, "far_km": float}; {} within reach; "blocks" empty when the
## homes reach too far but no cut line leaves homes on both sides.
static func reach_split(world: WorldState, id: String) -> Dictionary:
	var mine := blocks_of(world, id)
	var far := _spread_km(world, mine)
	if far <= float(TownGrid.CATCH_KM["SCHOOL"]):
		return {}
	var best := {}
	var best_key := [INF, INF]
	for cut in TownGrid.boundaries(world, mine):
		if int(cut["homes_a"]) <= 0 or int(cut["homes_b"]) <= 0:
			continue
		var key := [float(TownGrid.BOUNDARY_RANK[String(cut["kind"])]), maxf(_spread_km(world, cut["a"]), _spread_km(world, cut["b"]))]
		if key[0] < best_key[0] or (key[0] == best_key[0] and key[1] < best_key[1] - 0.0001):
			best_key = key
			best = cut
	if best.is_empty():
		return {"blocks": [], "cut": {}, "far_km": far}   # too far, but no line leaves homes on both sides
	var side: Array = best["a"] if int(best["homes_a"]) < int(best["homes_b"]) else best["b"]
	return {"blocks": side, "cut": best, "far_km": far}


## How far (km) the farthest block with homes lies from the homes-weighted middle of `blocks`; 0 without homes.
static func _spread_km(world: WorldState, blocks: Array) -> float:
	var c := Vector2.ZERO
	var n := 0
	for b in blocks:
		var h := TownGrid.block_homes(world, String(b))
		if h > 0:
			c += _block_mid_km(String(b)) * float(h)
			n += h
	if n <= 0:
		return 0.0
	c /= float(n)
	var far := 0.0
	for b in blocks:
		if TownGrid.block_homes(world, String(b)) > 0:
			far = maxf(far, _block_mid_km(String(b)).distance_to(c))
	return far


## Merge area `b` into area `a` (people, tiles); b becomes MERGED with a recorded as its successor.
static func merge(world: WorldState, a_id: String, b_id: String) -> void:
	var a: Dictionary = world.table("area")[a_id]
	var b: Dictionary = world.table("area")[b_id]
	var moves: Array = []
	for band in PopStore.INCOME_BANDS:
		var k := PopStore.count(world, {"hb": b_id, "inc": band})
		if k > 0:
			PopStore.move_group(world, {"hb": b_id, "inc": band}, k, {"hb": a_id}, "AREA_MERGE")
			moves.append({"from": b_id, "to": a_id, "band": band, "persons": k})
	for k2 in b["tiles"]:
		a["tiles"].append(k2)
		var t := _vec(k2)
		var u := Terrain.use_at(world, t.x, t.y).duplicate()
		u["area"] = a_id
		Terrain.set_use(world, t.x, t.y, u)
	b["tiles"] = []
	for bk in blocks_of(world, b_id):
		world.table("area_block")[bk] = a_id
	b["status"] = "MERGED"
	b["merged_into"] = a_id
	if not (b_id in a["parents"]):
		a["parents"].append(b_id)
	_notify(world, moves)
	world.add_fact({"type": "POP_AREAS_MERGED", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 35,
		"visibility": "PUBLIC", "data": {"into": a_id, "absorbed": b_id}})


## Yearly (January): private enclaves inside an area break away; an area whose homes reach farther than a school's
## catchment splits along its strongest boundary (reach_split).
static func yearly(world: WorldState) -> void:
	if world.month_of_year() != 1:
		return
	for a in areas(world):
		var id: String = a["id"]
		# enclave: a contiguous cluster of PRIVATE tiles in an area that is mostly not private
		var priv: Array = a["tiles"].filter(func(k): return Terrain.use_at(world, _vec(k).x, _vec(k).y).get("by", "") == "PRIVATE")
		if priv.size() >= ENCLAVE_MIN_TILES and priv.size() < a["tiles"].size() and a["kind"] != "ENCLAVE":
			var cl := _cluster(priv, priv[0])
			if cl.size() >= ENCLAVE_MIN_TILES:
				split(world, id, cl, "ENCLAVE", "ENCLAVE", ["I5", "I4"])
				continue
		# reach: homes farther than a school's walk from the rest split off as their own neighbourhood
		var rs := reach_split(world, id)
		if not rs.is_empty() and (rs["blocks"] as Array).is_empty():
			Logbook.note(world, "AREA", id, "no cut", {"far_km": snappedf(float(rs["far_km"]), 0.01),
				"reach_km": float(TownGrid.CATCH_KM["SCHOOL"])})
		elif not rs.is_empty():
			var cut: Dictionary = rs["cut"]
			split_blocks(world, id, rs["blocks"], "REACH", {"far_km": snappedf(float(rs["far_km"]), 0.01),
				"reach_km": float(TownGrid.CATCH_KM["SCHOOL"]), "cut": String(cut["kind"]), "axis": String(cut["axis"]), "at": int(cut["at"])})


# ======================================================================= helpers

static func _notify(world: WorldState, moves: Array) -> void:
	if moves.is_empty():
		return
	for cb in change_listeners:
		if cb is Callable and cb.is_valid():
			cb.call(world, moves)


static func _moved(moves: Array) -> int:
	var n := 0
	for m in moves:
		n += int(m["persons"])
	return n


static func _vec(k: String) -> Vector2i:
	return Vector2i(int(k.get_slice(",", 0)), int(k.get_slice(",", 1)))


## Tiles of `keys` connected (4-neighbour) to `start`.
static func _cluster(keys: Array, start: String) -> Array:
	var inset := {}
	for k in keys:
		inset[k] = true
	var out: Array = []
	var stack: Array = [start]
	var seen := {start: true}
	while not stack.is_empty():
		var k: String = stack.pop_back()
		out.append(k)
		var t := _vec(k)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nk := Terrain.key(t.x + d.x, t.y + d.y)
			if inset.has(nk) and not seen.has(nk):
				seen[nk] = true
				stack.append(nk)
	out.sort()
	return out


static func _name(world: WorldState, tile: Vector2i, kind: String) -> String:
	if world.peek("area").is_empty():
		return "Landing"
	var terr := Terrain.at(world, tile.x, tile.y)
	var r := world.rng.stream("map.names")
	# compass direction from the landing site gives every place its own name
	var l := Terrain.landing(world)
	var d := Vector2(tile - l)
	var dir := ""
	if d.length() >= 4.0:
		dir = ["East", "Southeast", "South", "Southwest", "West", "Northwest", "North", "Northeast"][int(round(fposmod(atan2(d.y, d.x), TAU) / (TAU / 8.0))) % 8]
	var feature := "River" if terr in ["f", "r"] else ("Ridge" if terr in ["h", "k"] else ("Ore" if terr in ["o", "x"] else ""))
	var base := ""
	match kind:
		"CAMP": base = "%s Camp" % (feature if feature != "" else (dir if dir != "" else "Landing"))
		"VILLAGE": base = "%s Village" % (feature if feature != "" else (dir if dir != "" else "Landing"))
		"ENCLAVE": base = "%s %s" % [dir if dir != "" else "Landing", ["Heights", "Park", "Gardens"][r.randi_range(0, 2)]]
		_: base = "%s %s" % [dir if dir != "" else "Landing", NAME_PARTS[r.randi_range(0, NAME_PARTS.size() - 1)]]
	var taken := {}
	for a in world.peek("area").values():
		taken[String(a["name"])] = true
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s %s" % [base, _roman(n)]):
		n += 1
	return "%s %s" % [base, _roman(n)]


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][n] if n <= 10 else str(n)
