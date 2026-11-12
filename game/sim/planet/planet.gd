class_name Planet
extends RefCounted
## The colony's planet (Terra): a globe of big hex regions (a Goldberg sphere: 12 pentagons, the rest hexagons),
## each with an elevation level and a biome. The 64×40 colony grid (Terrain) lives INSIDE one region, the landing
## region. Generated per seed from its own RNG seed ("planet.terrain"), so it never moves other streams.
##
## World table "planet" is small: {"freq": int, "gen": int, "landing": int, "uses": {"<cell>": {...}}}.
## Heights and biomes are a pure function of (master seed, freq, gen), regenerated into a cache on first use
## (also after a load) and never saved (Wilma: keep state_hash and saves small).
##   height: per cell, in steps; sea level 0, land 0..~95, sea floor down to -40. Terrain is smooth: a cell's height
##           is its centre; each corner is the mean of the 3 cells meeting there.
## Geometry (centres, corner polygons, neighbours) is pure maths of `freq` and is cached too.

const FREQ := 32                # 10·f²+2 cells: 32 → 10 242 regions (user: "the 10 000 range")
const METERS_PER_STEP := 80     # one height step in metres (tooltips)
const SEA_FRACTION := 0.56
const NAMES := {
	"D": "deep ocean", "S": "shallow sea", "I": "ice", "T": "tundra", "d": "desert", "s": "steppe",
	"g": "grassland", "f": "fertile lowland", "F": "forest", "j": "jungle", "w": "wetland",
	"h": "hills", "H": "highlands", "M": "mountains", "P": "peaks",
}
const WATER := ["D", "S"]
const GEN_VERSION := 1          # bump when the generator changes (old saves keep their own planet version)
## Coarse levels from height (for rules and text): -2 deep sea, -1 shallow, 0 lowland, 1 upland, 2 hills,
## 3 highlands, 4 mountains, 5 peaks.
const LEVEL_CUTS := [10, 20, 35, 50, 70]

static var _geo := {}           # freq -> {"centers", "corners", "corner_tri", "tris", "nbrs", "edge_nbr"}
static var _cache := {}         # "seed|freq|gen" -> {"h", "bio", "landing"}


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
	var corner_tri: Array = []  # cell -> PackedInt32Array of triangle ids, matching corners
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
		corner_tri.append(PackedInt32Array(ts))
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
	var flat := PackedInt32Array()
	for tr in tris:
		flat.append_array(PackedInt32Array(tr))
	_geo[freq] = {"centers": centers, "corners": corners, "corner_tri": corner_tri, "tris": flat,
		"edge_nbr": edge_nbr, "nbrs": nbrs}
	return _geo[freq]


static func _ang(p: Vector3, t1: Vector3, t2: Vector3) -> float:
	return atan2(p.dot(t2), p.dot(t1))


static func cell_count_for(freq: int) -> int:
	return 10 * freq * freq + 2


## Cell whose centre is nearest to direction `dir` (any length). Greedy walk over neighbours from `start`
## (exact on a sphere's Voronoi cells; fast when `start` is close, e.g. the last hovered cell).
static func cell_at(dir: Vector3, freq: int = FREQ, start: int = 0) -> int:
	var d := dir.normalized()
	var geo := geometry(freq)
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var cur := clampi(start, 0, cs.size() - 1)
	var cd := cs[cur].dot(d)
	while true:
		var best := cur
		for j in nb[cur]:
			var dd := cs[j].dot(d)
			if dd > cd:
				cd = dd
				best = j
		if best == cur:
			return cur
		cur = best
	return cur


## Latitude and longitude of a cell centre, in degrees (y is the rotation axis).
static func lat_lon(i: int, freq: int = FREQ) -> Vector2:
	var c: Vector3 = geometry(freq)["centers"][i]
	return Vector2(rad_to_deg(asin(clampf(c.y, -1.0, 1.0))), rad_to_deg(atan2(c.x, c.z)))


# ================================================================== generation

## Idempotent: does nothing if the world already has a planet (several setups call it).
## Stores only the small "planet" table; heights and biomes are regenerated from the seed into a cache.
static func generate(world: WorldState, freq: int = FREQ) -> void:
	if ready(world):
		return
	var tb := world.table("planet")
	tb["freq"] = freq
	tb["gen"] = GEN_VERSION
	var d := _data(world)
	tb["landing"] = d["landing"]
	tb["uses"] = {str(d["landing"]): {"colony": true}}


## Generated planet for this world: {"h": PackedInt32Array, "bio": String, "landing": int,
## "moist": PackedFloat32Array (0..1.2), "coast": PackedByteArray (1 = touches the other of land/sea)}. A pure function of
## the master seed, frequency and generator version, so it is cached (bounded) and never saved.
static func _data(world: WorldState) -> Dictionary:
	var fq := freq(world)
	var sd := world.rng.derive_seed("planet.terrain")   # own generator: never advances shared streams
	var key := "%d|%d|%d" % [sd, fq, int(world.peek("planet").get("gen", GEN_VERSION))]
	if not _cache.has(key):
		if _cache.size() >= 6:
			_cache.clear()
		_cache[key] = _compute(sd, fq)
	return _cache[key]


static func _compute(sd: int, freq: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var geo := geometry(freq)
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var n := cs.size()
	var base := _noise(r.randi(), 0.9, FastNoiseLite.FRACTAL_FBM, 6)
	var ridge := _noise(r.randi(), 1.1, FastNoiseLite.FRACTAL_RIDGED, 5)
	var wet := _noise(r.randi(), 1.1, FastNoiseLite.FRACTAL_FBM, 4)
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
	var order: Array = range(n)
	order.sort_custom(func(a, b): return e[a] < e[b] or (e[a] == e[b] and a < b))
	var n_sea := int(round(n * SEA_FRACTION))
	var sea_e: float = e[order[n_sea]]
	var land := PackedByteArray()
	land.resize(n)
	for rank in n:
		land[order[rank]] = 0 if rank < n_sea else 1
	# tidy coastlines: lone islets sink, enclosed puddles fill
	for _pass in 2:
		for i in n:
			var land_n := 0
			for j in nb[i]:
				land_n += land[j]
			if land[i] == 1 and land_n == 0 and r.randf() < 0.75:
				land[i] = 0
			elif land[i] == 0 and land_n >= nb[i].size() - 1:
				land[i] = 1
	var coast := PackedByteArray()
	coast.resize(n)
	for i in n:
		for j in nb[i]:
			if land[j] != land[i]:
				coast[i] = 1
	# heights by quantile: land relief = continental height + ridged mountain belts; sea floor by depth rank
	var land_ids: Array = []
	var sea_ids: Array = []
	var relief := PackedFloat32Array()
	relief.resize(n)
	for i in n:
		if land[i] == 1:
			var p2: Vector3 = cs[i] * 1.6
			var rg := ridge.get_noise_3d(p2.x, p2.y, p2.z)
			relief[i] = (e[i] - sea_e) * 1.1 + maxf(0.0, rg) * 0.9 + r.randf() * 0.01
			land_ids.append(i)
		else:
			relief[i] = e[i]
			sea_ids.append(i)
	land_ids.sort_custom(func(a, b): return relief[a] < relief[b] or (relief[a] == relief[b] and a < b))
	sea_ids.sort_custom(func(a, b): return relief[a] < relief[b] or (relief[a] == relief[b] and a < b))
	var h := PackedInt32Array()
	h.resize(n)
	var qs := [0.0, 0.38, 0.66, 0.82, 0.92, 0.975, 1.0]
	var hs := [0.0, 10.0, 20.0, 35.0, 50.0, 70.0, 95.0]
	for rank in land_ids.size():
		var q := float(rank) / float(maxi(1, land_ids.size() - 1))
		var k := 1
		while k < qs.size() - 1 and q > qs[k]:
			k += 1
		var t: float = (q - qs[k - 1]) / (qs[k] - qs[k - 1])
		h[land_ids[rank]] = roundi(lerpf(hs[k - 1], hs[k], t))
	for rank in sea_ids.size():
		var q2 := float(rank) / float(maxi(1, sea_ids.size() - 1))
		h[sea_ids[rank]] = -1 - roundi(39.0 * pow(1.0 - q2, 1.6))
	for i in n:
		if coast[i] == 1:
			h[i] = mini(h[i], 30) if land[i] == 1 else maxi(h[i], -4)
	# climate → biome
	var bio := PackedStringArray()
	bio.resize(n)
	var moist_a := PackedFloat32Array()
	moist_a.resize(n)
	for i in n:
		var c: Vector3 = cs[i]
		var lat_f := absf(rad_to_deg(asin(clampf(c.y, -1.0, 1.0)))) / 90.0
		var temp := 1.0 - pow(lat_f, 1.5) - maxf(0, h[i]) * 0.0065
		var p3: Vector3 = c * 2.0
		var moist := 0.5 + wet.get_noise_3d(p3.x, p3.y, p3.z) * 0.7 + (0.18 if coast[i] == 1 else 0.0)
		# wet equator, dry belts around 25° (subtropical highs)
		moist += 0.15 * maxf(0.0, 1.0 - lat_f / 0.12) - 0.3 * maxf(0.0, 1.0 - absf(lat_f - 0.3) / 0.12)
		bio[i] = _biome(h[i], temp, moist)
		moist_a[i] = clampf(moist, 0.0, 1.2)
	var landing := _choose_landing(cs, nb, h, bio, r)
	return {"h": h, "bio": "".join(bio), "landing": landing, "moist": moist_a, "coast": coast}


static func _noise(sd: int, fq: float, fractal: int, octaves: int) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.seed = sd & 0x7fffffff
	nz.frequency = fq
	nz.fractal_type = fractal
	nz.fractal_octaves = octaves
	return nz


static func level_of(height_v: int) -> int:
	if height_v < 0:
		return -2 if height_v < -8 else -1
	var lv := 0
	for c in LEVEL_CUTS:
		if height_v >= c:
			lv += 1
	return lv


static func _biome(height_v: int, temp: float, moist: float) -> String:
	if height_v < 0:
		return "I" if temp < 0.05 else ("D" if height_v < -8 else "S")
	if temp < 0.12:
		return "I"
	match level_of(height_v):
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
	if moist > 0.82 and height_v < 6:
		return "w"
	if height_v < 10 and moist > 0.45 and temp > 0.4:
		return "f"
	if moist > 0.6:
		return "F"
	return "g"


## Landing: temperate lowland or upland near the sea, preferring fertile ground with hills nearby
## (the colony grid inside it has a river, hills and deposits).
static func _choose_landing(cs: PackedVector3Array, nb: Array, h: PackedInt32Array, bio: PackedStringArray, r: RandomNumberGenerator) -> int:
	var best := -1
	var best_s := INF
	for i in cs.size():
		if not (bio[i] in ["g", "f", "F"]) or h[i] >= 20:
			continue
		var sea := false
		var hills := false
		for j in nb[i]:
			sea = sea or h[j] < 0
			for k in nb[j]:
				hills = hills or h[k] >= 20
		var s := absf(absf(cs[i].y) - 0.6) * 2.0 + r.randf() * 0.3
		s += 0.0 if sea else 0.6
		s -= 0.25 if hills else 0.0
		s -= 0.2 if bio[i] == "f" else 0.0
		if s < best_s:
			best_s = s
			best = i
	if best < 0:   # no temperate lowland at all: the lowest land cell
		for i in cs.size():
			if h[i] >= 0 and (best < 0 or h[i] < h[best]):
				best = i
	return best


# ================================================================== reads

static func ready(world: WorldState) -> bool:
	return world.peek("planet").has("landing")


static func freq(world: WorldState) -> int:
	return int(world.peek("planet").get("freq", FREQ))


static func cell_count(world: WorldState) -> int:
	return cell_count_for(freq(world))


## Height of a cell centre in steps (sea level 0; one step = METERS_PER_STEP m).
static func height(world: WorldState, i: int) -> int:
	return _data(world)["h"][i]


## All heights at once (rendering). Shared, do not modify.
static func heights(world: WorldState) -> PackedInt32Array:
	return _data(world)["h"]


## All biome codes, one char per cell.
static func biomes(world: WorldState) -> String:
	return _data(world)["bio"]


static func level(world: WorldState, i: int) -> int:
	return level_of(height(world, i))


static func biome(world: WorldState, i: int) -> String:
	return String(_data(world)["bio"]).substr(i, 1)


static func is_water(world: WorldState, i: int) -> bool:
	return height(world, i) < 0


static func landing(world: WorldState) -> int:
	return int(world.peek("planet").get("landing", -1))


static func neighbors(world: WorldState, i: int) -> PackedInt32Array:
	return geometry(freq(world))["nbrs"][i]


## Moisture index of a cell (0 dry .. ~1.2 very wet); climate uses it for rainfall.
static func moisture(world: WorldState, i: int) -> float:
	return _data(world)["moist"][i]


static func is_coast(world: WorldState, i: int) -> bool:
	return _data(world)["coast"][i] == 1


## Hex that holds a tile of the 64×40 colony grid (Terrain). The whole grid lies inside the landing hex today;
## when settlements spread to other hexes, each gets its own grid and this maps grid → hex (agreed with Bob).
static func hex_of_tile(world: WorldState, _tile: Vector2i) -> int:
	return landing(world)


## Hexes with something on them (the colony, later outposts): weather facts are reported for these.
static func settled(world: WorldState) -> Array:
	var out: Array = []
	for k in world.peek("planet").get("uses", {}):
		out.append(int(k))
	out.sort()
	return out


static func use_at(world: WorldState, i: int) -> Dictionary:
	return world.peek("planet").get("uses", {}).get(str(i), {})


## One-line description of a cell for tooltips and news.
static func describe(world: WorldState, i: int) -> String:
	var ll := lat_lon(i, freq(world))
	var hh := height(world, i)
	var alt := ("%d m" % (hh * METERS_PER_STEP)) if hh >= 0 else ("%d m deep" % (-hh * METERS_PER_STEP))
	return "%s · %s · %d°%s %d°%s" % [String(NAMES.get(biome(world, i), "?")).capitalize(), alt,
		absi(roundi(ll.x)), "N" if ll.x >= 0 else "S", absi(roundi(ll.y)), "E" if ll.y >= 0 else "W"]


## Tourist sites (A42, spec-demand-v1 §D4): see PlanetSites. Pure: [{id, name, kind, attraction 0..100,
## season_mult [12 × %], cell, dist, km, travel_days, where, tile}]. This month's draw: PlanetSites.season_pct.
static func sites(world: WorldState) -> Array:
	return PlanetSites.sites(world)
