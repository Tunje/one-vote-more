class_name AreaStore
extends RefCounted
## M13 (planning/spec-areas-v1.md §2–§4): areas = housing blocks (population.md §3) built on the terrain map.
## An area is a set of residential tiles. Building housing next to an area extends it; building it apart founds
## a new one. Areas split (too big, or an enclave diverging inside) and merge, with parent ids kept for history.
## People live in PopStore leaves keyed by the area id (key part "hb"); splits move them with PopStore transfers,
## so population is conserved and beliefs travel.
##
## Table "area": id -> {id, name, kind, tiles: ["x,y"], district, founded, parents, children, status}
## Tile uses (Terrain "uses"): {"area": id, "units": int, "by": GOV|COMPANY|PRIVATE, "band": "" | "I4"…}
##
## Hooks (static, set by other systems at startup; not saved):
##   change_listeners: Callables (world, moves: [{from, to, band, persons}]) called after people move between areas
##                     (Bob: pool savings follow people)
##   district_resolver: Callable (world, area_id) -> district id for a newly founded area (Anni: law decides)

const KINDS := ["SETTLEMENT", "CAMP", "VILLAGE", "ENCLAVE", "SHELTER"]
const SPLIT_SIZE := 800           # residents above which an area splits in two
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


static func centroid(world: WorldState, id: String) -> Vector2:
	var ts := tiles_of(world, id)
	var c := Vector2.ZERO
	for t in ts:
		c += Vector2(t)
	return c / maxf(1.0, float(ts.size()))


static func area_of(world: WorldState, tile: Vector2i) -> String:
	return String(Terrain.use_at(world, tile.x, tile.y).get("area", ""))


static func capacity(world: WorldState, id: String) -> int:
	var c := 0
	for t in tiles_of(world, id):
		c += int(Terrain.use_at(world, t.x, t.y).get("units", 0))
	return c


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
static func place_housing(world: WorldState, tile: Vector2i, units: int, built_by: String = "GOV", band: String = "", name: String = "") -> String:
	if not Terrain.use_at(world, tile.x, tile.y).is_empty() or not (Terrain.at(world, tile.x, tile.y) in Terrain.BUILDABLE_HOUSING):
		return ""
	var id := adjacent_area(world, tile)
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
	var a := {"id": id, "name": name if name != "" else _name(world, tiles[0], kind), "kind": kind, "tiles": keys,
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
	a["children"].append(new_id)
	var cap_b := capacity(world, new_id)
	var total := residents(world, id)
	var want := int(round(float(total) * float(cap_b) / maxf(1.0, float(cap_all))))
	var moves: Array = []
	if not bands_first.is_empty():
		for b in bands_first:
			var have := PopStore.count(world, {"hb": id, "inc": b})
			var k := mini(have, cap_b - _moved(moves))
			if k > 0:
				PopStore.move_group(world, {"hb": id, "inc": b}, k, {"hb": new_id}, "AREA_SPLIT")
				moves.append({"from": id, "to": new_id, "band": b, "persons": k})
	else:
		# proportional by band, largest remainder, so every band keeps its share in both parts
		var bands: Array = PopStore.INCOME_BANDS
		var w: Array = bands.map(func(b): return PopStore.count(world, {"hb": id, "inc": b}))
		var parts := EconUtil.split_lr(want, w)
		for i in bands.size():
			var k2 := mini(int(parts[i]), int(w[i]))
			if k2 > 0:
				PopStore.move_group(world, {"hb": id, "inc": bands[i]}, k2, {"hb": new_id}, "AREA_SPLIT")
				moves.append({"from": id, "to": new_id, "band": bands[i], "persons": k2})
	_notify(world, moves)
	world.add_fact({"type": "POP_AREA_SPLIT", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"area": id, "new": new_id, "reason": reason, "moved": _moved(moves)}})
	return new_id


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
	b["status"] = "MERGED"
	b["merged_into"] = a_id
	if not (b_id in a["parents"]):
		a["parents"].append(b_id)
	_notify(world, moves)
	world.add_fact({"type": "POP_AREAS_MERGED", "owner": "pop", "subjects": [], "responsible": [], "impact": {}, "magnitude": 35,
		"visibility": "PUBLIC", "data": {"into": a_id, "absorbed": b_id}})


## Yearly (January): oversized areas split in two; private enclaves inside an area break away.
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
		# size: split along the longest axis at the median
		if residents(world, id) > SPLIT_SIZE and a["tiles"].size() >= 2:
			var ts: Array = a["tiles"].map(func(k): return _vec(k))
			var xs: Array = ts.map(func(t): return t.x)
			var ys: Array = ts.map(func(t): return t.y)
			var along_x: bool = (xs.max() - xs.min()) >= (ys.max() - ys.min())
			ts.sort_custom(func(p, q): return (p.x < q.x or (p.x == q.x and p.y < q.y)) if along_x else (p.y < q.y or (p.y == q.y and p.x < q.x)))
			split(world, id, ts.slice(ts.size() / 2), "SETTLEMENT", "SIZE")


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
	var base := "Landing"
	var near := nearest_area(world, tile)
	if near != "":
		base = String(get_area(world, near)["name"]).get_slice(" ", 0)
	var terr := Terrain.at(world, tile.x, tile.y)
	var r := world.rng.stream("map.names")
	match kind:
		"CAMP": return "%s Camp" % ("Ore" if terr in ["h", "k", "o"] else base)
		"VILLAGE": return "%s Village" % ("River" if terr in ["f", "r"] else base)
		"ENCLAVE": return "%s %s" % [base, ["Heights", "Park", "Ridge"][r.randi_range(0, 2)]]
	if world.peek("area").is_empty():
		return "Landing"
	return "%s %s" % [base, NAME_PARTS[r.randi_range(0, NAME_PARTS.size() - 1)]]
