class_name Planet
extends RefCounted
## The colony's planet (Terra): a globe of big hex regions (a Goldberg sphere: 12 pentagons, the rest hexagons),
## each with an elevation level and a biome. The 64×40 colony grid (Terrain) lives INSIDE one region, the landing
## region. Generated per seed from its own RNG seed ("planet.terrain"), so it never moves other streams.
##
## World table "planet": {"freq": int, "elev": String, "biome": String, "landing": int, "uses": {"<cell>": {...}}}
##   elev:  one char per cell, '0'..'7' = level -2..5  (-2 deep ocean, -1 shallow sea, 0 lowland … 5 peaks)
##   biome: one char per cell, see NAMES
## Geometry (centres, corner polygons, neighbours) is pure maths of `freq` and is cached, not stored.

const FREQ := 7                 # 10·f²+2 cells: 7 → 492 regions (big hexes)
const SEA_FRACTION := 0.56
const NAMES := {
	"D": "deep ocean", "S": "shallow sea", "I": "ice", "T": "tundra", "d": "desert", "s": "steppe",
	"g": "grassland", "f": "fertile lowland", "F": "forest", "j": "jungle", "w": "wetland",
	"h": "hills", "H": "highlands", "M": "mountains", "P": "peaks",
}
const WATER := ["D", "S"]
const MIN_LEVEL := -2
const MAX_LEVEL := 5

static var _geo := {}           # freq -> {"centers", "corners", "nbrs", "edge_nbr"}


# ================================================================== geometry

## Geometry of a Goldberg sphere of frequency `freq` (unit radius). Cached.
##   centers: PackedVector3Array (cell centre directions)
##   corners: Array of PackedVector3Array (polygon corners, counter-clockwise seen from outside)
##   edge_nbr: Array of PackedInt32Array (edge_nbr[i][k] = neighbour across edge corners[k] → corners[k+1])
##   nbrs: same set as edge_nbr, as the plain neighbour list
static func geometry(freq: int = FREQ) -> Dictionary:
	if _geo.has(freq):
		return _geo[freq]
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var iv: Array[Vector3] = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11],
		[6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var centers := PackedVector3Array()
	var index := {}             # snapped position -> vertex id
	var tris: Array = []        # [a, b, c]
	for f in faces:
		var a: Vector3 = iv[f[0]]
		var b: Vector3 = iv[f[1]]
		var c: Vector3 = iv[f[2]]
		var ids := {}           # Vector2i(i, j) -> vertex id
		for i in freq + 1:
			for j in freq + 1 - i:
				var p: Vector3 = (a * float(freq - i - j) + b * float(i) + c * float(j)) / float(freq)
				p = p.normalized()
				var k := Vector3i(roundi(p.x * 10000.0), roundi(p.y * 10000.0), roundi(p.z * 10000.0))
				if not index.has(k):
					index[k] = centers.size()
					centers.append(p)
				ids[Vector2i(i, j)] = index[k]
		for i in freq:
			for j in freq - i:
				tris.append([ids[Vector2i(i, j)], ids[Vector2i(i + 1, j)], ids[Vector2i(i, j + 1)]])
				if i + j < freq - 1:
					tris.append([ids[Vector2i(i + 1, j)], ids[Vector2i(i + 1, j + 1)], ids[Vector2i(i, j + 1)]])
	var n := centers.size()
	var inc: Array = []         # vertex -> triangle ids
	for _i in n:
		inc.append([])
	var tri_c := PackedVector3Array()
	for t in tris.size():
		var tr: Array = tris[t]
		tri_c.append((centers[tr[0]] + centers[tr[1]] + centers[tr[2]]).normalized())
		for v in tr:
			inc[v].append(t)
	var corners: Array = []
	var edge_nbr: Array = []
	var nbrs: Array = []
	for v in n:
		var cv: Vector3 = centers[v]
		var t1: Vector3 = cv.cross(Vector3.UP if absf(cv.y) < 0.9 else Vector3.RIGHT).normalized()
		var t2: Vector3 = cv.cross(t1)
		var ts: Array = inc[v].duplicate()
		ts.sort_custom(func(x, y): return _ang(tri_c[x], t1, t2) < _ang(tri_c[y], t1, t2))
		var poly := PackedVector3Array()
		for t in ts:
			poly.append(tri_c[t])
		# counter-clockwise seen from outside: (p1-p0)×(p2-p0) points outward
		if (poly[1] - poly[0]).cross(poly[2] - poly[0]).dot(cv) < 0.0:
			poly.reverse()
			ts.reverse()
		corners.append(poly)
		# the neighbour across edge k shares both triangles ts[k] and ts[k+1]
		var en := PackedInt32Array()
		for k in ts.size():
			var ta: Array = tris[ts[k]]
			var tb: Array = tris[ts[(k + 1) % ts.size()]]
			var other := -1
			for u in ta:
				if u != v and u in tb:
					other = u
			en.append(other)
		edge_nbr.append(en)
		nbrs.append(en.duplicate())
	_geo[freq] = {"centers": centers, "corners": corners, "edge_nbr": edge_nbr, "nbrs": nbrs}
	return _geo[freq]


static func _ang(p: Vector3, t1: Vector3, t2: Vector3) -> float:
	return atan2(p.dot(t2), p.dot(t1))


static func cell_count_for(freq: int) -> int:
	return 10 * freq * freq + 2


## Cell whose centre is nearest to direction `dir` (any length).
static func cell_at(dir: Vector3, freq: int = FREQ) -> int:
	var d := dir.normalized()
	var cs: PackedVector3Array = geometry(freq)["centers"]
	var best := 0
	var bd := -2.0
	for i in cs.size():
		var dd := cs[i].dot(d)
		if dd > bd:
			bd = dd
			best = i
	return best


## Latitude and longitude of a cell centre, in degrees (y is the rotation axis).
static func lat_lon(i: int, freq: int = FREQ) -> Vector2:
	var c: Vector3 = geometry(freq)["centers"][i]
	return Vector2(rad_to_deg(asin(clampf(c.y, -1.0, 1.0))), rad_to_deg(atan2(c.x, c.z)))


# ================================================================== generation

## Idempotent: does nothing if the world already has a planet (several setups call it).
static func generate(world: WorldState, freq: int = FREQ) -> void:
	if ready(world):
		return
	var r := RandomNumberGenerator.new()
	r.seed = world.rng.derive_seed("planet.terrain")   # own generator: never advances shared streams
	var geo := geometry(freq)
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var n := cs.size()
	var base := FastNoiseLite.new()
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.seed = r.randi() & 0x7fffffff
	base.frequency = 0.9
	base.fractal_type = FastNoiseLite.FRACTAL_FBM
	base.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.seed = r.randi() & 0x7fffffff
	ridge.frequency = 1.3
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	var wet := FastNoiseLite.new()
	wet.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wet.seed = r.randi() & 0x7fffffff
	wet.frequency = 1.1
	# a few continental shields so land comes in continents, not speckle
	var shields: Array = []
	for _k in r.randi_range(3, 5):
		var d := Vector3(r.randf_range(-1, 1), r.randf_range(-0.8, 0.8), r.randf_range(-1, 1)).normalized()
		shields.append([d, r.randf_range(0.55, 1.0), r.randf_range(0.5, 0.85)])   # dir, radius (rad), strength
	var e := PackedFloat32Array()
	e.resize(n)
	for i in n:
		var p: Vector3 = cs[i] * 1.2
		var v := base.get_noise_3d(p.x, p.y, p.z)
		for s in shields:
			var ang := acos(clampf(cs[i].dot(s[0]), -1.0, 1.0))
			v += float(s[2]) * maxf(0.0, 1.0 - ang / float(s[1]))
		e[i] = v
	# rank-normalise: a fixed share of ocean, then land levels by quantile
	var order: Array = range(n)
	order.sort_custom(func(a, b): return e[a] < e[b] or (e[a] == e[b] and a < b))
	var lvl := PackedInt32Array()
	lvl.resize(n)
	var n_sea := int(round(n * SEA_FRACTION))
	for rank in n:
		var i: int = order[rank]
		if rank < int(n_sea * 0.55):
			lvl[i] = -2
		elif rank < n_sea:
			lvl[i] = -1
		else:
			lvl[i] = 0
	# tidy coastlines: lone islets sink, enclosed puddles fill (two passes, in index order)
	for _pass in 2:
		for i in n:
			var land_n := 0
			for j in nb[i]:
				if lvl[j] >= 0:
					land_n += 1
			if lvl[i] >= 0 and land_n == 0 and r.randf() < 0.75:
				lvl[i] = -1
			elif lvl[i] < 0 and land_n >= nb[i].size() - 1:
				lvl[i] = 0
	# land relief: lowland base plus ridged mountain belts, again by quantile among land
	var land: Array = []
	var relief := {}
	for i in n:
		if lvl[i] >= 0:
			var p2: Vector3 = cs[i] * 2.0
			var rg := ridge.get_noise_3d(p2.x, p2.y, p2.z)
			relief[i] = (e[i] - e[order[n_sea]]) * 1.2 + rg * 0.8 + r.randf() * 0.05
			land.append(i)
	land.sort_custom(func(a, b): return relief[a] < relief[b] or (relief[a] == relief[b] and a < b))
	var cuts := [0.38, 0.66, 0.82, 0.92, 0.975]   # → 0 lowland, 1 upland, 2 hills, 3 highlands, 4 mountains, 5 peaks
	for rank in land.size():
		var q := float(rank) / float(maxi(1, land.size()))
		var L := 0
		for c in cuts:
			if q >= c:
				L += 1
		lvl[land[rank]] = L
	# coast: land touching the sea is never above highlands
	for i in n:
		if lvl[i] > 3:
			for j in nb[i]:
				if lvl[j] < 0:
					lvl[i] = 3
					break
	# climate → biome
	var bio := PackedStringArray()
	bio.resize(n)
	for i in n:
		var c: Vector3 = cs[i]
		var lat_f := absf(rad_to_deg(asin(clampf(c.y, -1.0, 1.0)))) / 90.0
		var temp := 1.0 - pow(lat_f, 1.5) - maxf(0, lvl[i]) * 0.06
		var near_sea := false
		for j in nb[i]:
			if lvl[j] < 0:
				near_sea = true
		var p3: Vector3 = c * 2.0
		var moist := 0.5 + wet.get_noise_3d(p3.x, p3.y, p3.z) * 0.7 + (0.18 if near_sea else 0.0)
		# dry belts around ±25° (subtropical highs), wet equator
		# wet equator, dry belts around 25° (subtropical highs)
		moist += 0.15 * maxf(0.0, 1.0 - lat_f / 0.12) - 0.3 * maxf(0.0, 1.0 - absf(lat_f - 0.3) / 0.12)
		bio[i] = _biome(lvl[i], temp, moist)
	var landing := _choose_landing(cs, nb, lvl, bio, r)
	var elev := ""
	for i in n:
		elev += String.chr(48 + lvl[i] - MIN_LEVEL)
	var t := world.table("planet")
	t["freq"] = freq
	t["elev"] = elev
	t["biome"] = "".join(bio)
	t["landing"] = landing
	t["uses"] = {str(landing): {"colony": true}}


static func _biome(level: int, temp: float, moist: float) -> String:
	if level < 0:
		return "I" if temp < 0.05 else ("D" if level == -2 else "S")
	if temp < 0.12:
		return "I"
	match level:
		5: return "P"
		4: return "M"
		3: return "H"
		2: return "h"
	if temp < 0.3:
		return "T"
	if moist < 0.36:
		return "d" if temp > 0.6 else "s"
	if moist > 0.78 and temp > 0.68:
		return "j"
	if moist > 0.82 and level == 0:
		return "w"
	if level == 0 and moist > 0.45 and temp > 0.4:
		return "f"
	if moist > 0.6:
		return "F"
	return "g"


## Landing: temperate lowland or upland near the sea, preferring fertile ground with hills in sight
## (the colony grid inside it has a river, hills and deposits).
static func _choose_landing(cs: PackedVector3Array, nb: Array, lvl: PackedInt32Array, bio: PackedStringArray, r: RandomNumberGenerator) -> int:
	var best := -1
	var best_s := INF
	for i in cs.size():
		if not (bio[i] in ["g", "f", "F"]) or lvl[i] > 1:
			continue
		var sea := false
		var hills := false
		for j in nb[i]:
			sea = sea or lvl[j] < 0
			hills = hills or lvl[j] >= 2
		var s := absf(absf(cs[i].y) - 0.6) * 2.0 + r.randf() * 0.3
		s += 0.0 if sea else 0.6
		s -= 0.25 if hills else 0.0
		s -= 0.2 if bio[i] == "f" else 0.0
		if s < best_s:
			best_s = s
			best = i
	if best < 0:   # no temperate lowland at all: the lowest land cell
		for i in cs.size():
			if lvl[i] >= 0 and (best < 0 or lvl[i] < lvl[best]):
				best = i
	return best


# ================================================================== reads

static func ready(world: WorldState) -> bool:
	return world.peek("planet").has("elev")


static func freq(world: WorldState) -> int:
	return int(world.peek("planet").get("freq", FREQ))


static func cell_count(world: WorldState) -> int:
	return String(world.peek("planet").get("elev", "")).length()


static func level(world: WorldState, i: int) -> int:
	return String(world.peek("planet")["elev"]).unicode_at(i) - 48 + MIN_LEVEL


static func biome(world: WorldState, i: int) -> String:
	return String(world.peek("planet")["biome"]).substr(i, 1)


static func is_water(world: WorldState, i: int) -> bool:
	return level(world, i) < 0


static func landing(world: WorldState) -> int:
	return int(world.peek("planet").get("landing", -1))


static func neighbors(world: WorldState, i: int) -> PackedInt32Array:
	return geometry(freq(world))["nbrs"][i]


static func use_at(world: WorldState, i: int) -> Dictionary:
	return world.peek("planet").get("uses", {}).get(str(i), {})


## One-line description of a cell for tooltips and news.
static func describe(world: WorldState, i: int) -> String:
	var ll := lat_lon(i, freq(world))
	return "%s · elevation %d · %d°%s %d°%s" % [String(NAMES.get(biome(world, i), "?")).capitalize(), level(world, i),
		absi(roundi(ll.x)), "N" if ll.x >= 0 else "S", absi(roundi(ll.y)), "E" if ll.y >= 0 else "W"]
