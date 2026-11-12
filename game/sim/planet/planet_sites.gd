class_name PlanetSites
extends RefCounted
## Terra (A42, spec-demand-v1 §D4): tourist SITES. They are places worth a trip, read from the planet's terrain,
## climate and alien phenomena. Pure: a function of the seed (globe), the colony grid (sites on the colony map)
## and the month (season). Nothing is saved. Bob's tourism economy reads `sites()` and `season_pct()`.
##
## Site = {id, name, kind, attraction 0..100, season_mult [12 ints, % by calendar month, 100 = an average month],
##         cell, dist (hex steps from the colony), km, travel_days, where ("COLONY" | "REGION" | "GLOBE"),
##         tile (Vector2i on the colony map for COLONY sites, else (-1, -1))}
## Every number is an int. Sort order: colony sites first, then by distance, then by id.

const KINDS := ["FOUNDERS_CEMETERY", "FIRST_LANDING", "RIVER_FALLS", "GLOW_MEADOW", "CRYSTAL_CRAGS",
	"WATERFALL", "CANYON", "GLOWING_FIELD", "AURORA_PLAIN", "TIDAL_BORE", "SUMMIT"]
const KIND_NAMES := {
	"FIRST_LANDING": "first landing site", "FOUNDERS_CEMETERY": "the founders' cemetery", "RIVER_FALLS": "river falls", "GLOW_MEADOW": "glowing meadow",
	"CRYSTAL_CRAGS": "crystal crags", "WATERFALL": "waterfall", "CANYON": "canyon",
	"GLOWING_FIELD": "glowing field (alien)", "AURORA_PLAIN": "aurora plain", "TIDAL_BORE": "twin-moon tidal bore",
	"SUMMIT": "summit"}
## Planet radius (km): one hex step at frequency 32 is ~210 km. The colony map (64×40) lies inside one hex.
const RADIUS_KM := 6100
const KM_PER_TRAVEL_DAY := 400      # overland/air trip, for the travel cost (Bob prices it)
const REGION_STEPS := 8             # within this many hex steps a site is "REGION", beyond it "GLOBE"
const SPACING := 4                  # two sites of a kind keep at least this many hex steps apart

const _STEMS := {
	"WATERFALL": ["Veil", "Thunder", "Silver", "Mist", "Bridal", "Echo", "Stair", "Cloud"],
	"CANYON": ["Red", "Sunset", "Whisper", "Ochre", "Hollow", "Serpent", "Copper", "Long"],
	"GLOWING_FIELD": ["Lantern", "Ember", "Lumen", "Starfall", "Halo", "Firefly", "Pale", "Ghost"],
	"AURORA_PLAIN": ["Curtain", "Northlight", "Veil", "Frost", "Shimmer", "Polar", "Banner", "Crown"],
	"TIDAL_BORE": ["Twin-Moon", "Roaring", "Racing", "Moonrise", "Tidewall", "Long Wave", "Surge", "Pilgrim"],
	"SUMMIT": ["Mount Harrow", "Mount Vigil", "The Spire", "Mount Solace", "High Crown", "Mount Corran", "The Anvil", "Mount Ash"],
}
const _SUFFIX := {"WATERFALL": " Falls", "CANYON": " Canyon", "GLOWING_FIELD": " Fields", "AURORA_PLAIN": " Plain",
	"TIDAL_BORE": " Bore", "SUMMIT": ""}

static var _cache := {}


## All tourist sites of the world (pure; cached per seed and colony grid).
static func sites(world: WorldState) -> Array:
	if not Planet.ready(world):
		return []
	var rows: Array = world.peek("map").get("grid", {}).get("rows", [])
	var key := "%d|%d|%d|%d|%s" % [world.rng.derive_seed("planet.terrain"), Planet.freq(world),
		int(world.peek("planet").get("gen", Planet.GEN_VERSION)), hash("".join(rows)), str(WasteMap.founders_sight_tile(world))]
	if not _cache.has(key):
		if _cache.size() >= 6:
			_cache.clear()
		_cache[key] = _compute(world)
	return _cache[key]


static func site(world: WorldState, id: String) -> Dictionary:
	for s in sites(world):
		if s["id"] == id:
			return s
	return {}


## Sites in one hex (the globe's hover line; the colony map uses `where == "COLONY"`).
static func at_cell(world: WorldState, cell: int) -> Array:
	return sites(world).filter(func(s): return int(s["cell"]) == cell)


## How much a site draws this month, in % (100 = an average month): the calendar season, plus what the sky does
## that month: a twin-moon surge for a tidal bore (predictable), a solar flare for the auroras, a spore bloom for
## the glowing fields. Storms over the site keep visitors away. Storms and phenomena are known for the current
## month only; other months get the season and the (predictable) moons.
static func season_pct(world: WorldState, site_d: Dictionary, month: int = -1) -> int:
	var m := world.month if month < 0 else month
	var pct := int(site_d["season_mult"][posmod(m, 12)])
	var kind: String = site_d["kind"]
	if kind == "TIDAL_BORE":
		pct = pct * moon_surge_pct(m) / 100
	if m != world.month:
		return pct
	var cell := int(site_d["cell"])
	for p in PlanetClimate.phenomena_at(world, cell):
		if p["kind"] == "SOLAR_FLARE" and kind == "AURORA_PLAIN":
			pct = pct * (100 + 60 * int(p["strength"])) / 100
		elif p["kind"] == "SPORE_BLOOM" and kind in ["GLOWING_FIELD", "GLOW_MEADOW"]:
			pct = pct * (100 + 40 * int(p["strength"])) / 100
	var worst := 0
	for s in PlanetClimate.storms_at(world, cell):
		worst = maxi(worst, int(s["strength"]))
	if worst > 0:
		pct = pct * maxi(20, 100 - 20 * worst) / 100
	return pct


## The twin moons (7- and 11-month cycles, as in PlanetClimate) make the tidal bores: 300% in a surge month, 60%
## otherwise. Predictable, so tour operators can sell surge trips years ahead.
static func moon_surge_pct(month: int) -> int:
	var align := cos(TAU * float(month) / 7.0) + cos(TAU * float(month) / 11.0)
	if align > 1.95:
		return 400
	if align > 1.75:
		return 300
	return 60


## Next month (>= from) with a twin-moon surge.
static func next_surge(from_month: int) -> int:
	var m := from_month
	while moon_surge_pct(m) < 300 and m < from_month + 200:
		m += 1
	return m


# ================================================================== generation

static func _compute(world: WorldState) -> Array:
	var fq := Planet.freq(world)
	var geo := Planet.geometry(fq)
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var n := cs.size()
	var home := Planet.landing(world)
	var dist := _bfs(nb, home, n)
	var sd := world.rng.derive_seed("planet.sites")
	var cand := {}   # kind -> [[score, cell]]
	for k in ["WATERFALL", "CANYON", "GLOWING_FIELD", "AURORA_PLAIN", "TIDAL_BORE", "SUMMIT"]:
		cand[k] = []
	for i in n:
		if i == home:
			continue
		var h := Planet.height(world, i)
		if h < 0:
			continue
		var b := Planet.biome(world, i)
		var moist := Planet.moisture(world, i)
		var lat := absf(Planet.lat_lon(i, fq).x)
		var lo := h
		var hi := h
		var sea_n := 0
		for j in nb[i]:
			var hj := Planet.height(world, j)
			lo = mini(lo, hj)
			hi = maxi(hi, hj)
			sea_n += 1 if hj < 0 else 0
		var jit := _mix(sd, i) % 10
		if moist >= 0.5 and h - maxi(lo, 0) >= 10 and lat < 65.0:              # water falls off a scarp
			cand["WATERFALL"].append([(h - maxi(lo, 0)) * 3 + int(moist * 20.0) + jit, i])
		if b in ["d", "s", "h", "H"] and moist < 0.55 and hi - lo >= 14:      # dry land cut deep
			cand["CANYON"].append([(hi - lo) * 3 + int((0.55 - moist) * 30.0) + jit, i])
		if b in ["j", "w", "F"] and moist >= 0.6 and _mix(sd + 1, i) % 5 == 0:  # alien glowing flora (not everywhere)
			cand["GLOWING_FIELD"].append([int(moist * 50.0) + (15 if b == "w" else 0) + jit * 2, i])
		if lat >= 56.0 and lat < 75.0:                                          # under the auroral oval
			cand["AURORA_PLAIN"].append([int((lat - 50.0) * 2.0) + (10 if b in ["T", "I"] else 0) + jit, i])
		if sea_n >= 3 and sea_n < nb[i].size():                                 # a narrow bay funnels the surge
			cand["TIDAL_BORE"].append([sea_n * 12 + jit * 2, i])
		if h >= 60 and h >= hi:                                                 # a local top
			cand["SUMMIT"].append([h + jit, i])
	var out: Array = []
	var used := {}
	var names := {}
	for kind in cand:
		var list: Array = cand[kind]
		list.sort_custom(func(a, c): return a[0] > c[0] or (a[0] == c[0] and a[1] < c[1]))
		var top := float(list[0][0]) if not list.is_empty() else 1.0
		var picked: Array = []
		# the best within the region (worth a day trip), then the best on the globe, then a second far one
		for pass_i in 3:
			for e in list:
				var c: int = e[1]
				if dist[c] < 0 or used.has(c):
					continue
				if pass_i == 0 and dist[c] > REGION_STEPS:
					continue
				var close := false
				for p in picked:
					close = close or _hex_steps(nb, p, c, SPACING) >= 0
				if close:
					continue
				picked.append(c)
				used[c] = true
				var att := _attraction(kind, float(e[0]) / maxf(top, 1.0))
				out.append(_site(world, kind, c, att, dist[c], names, Vector2i(-1, -1), sd))
				break
	out.append_array(_colony_sites(world, home, sd, names))
	out.sort_custom(func(a, c):
		var wa := 0 if a["where"] == "COLONY" else 1
		var wc := 0 if c["where"] == "COLONY" else 1
		if wa != wc:
			return wa < wc
		if a["dist"] != c["dist"]:
			return a["dist"] < c["dist"]
		return String(a["id"]) < String(c["id"]))
	return out


## Base attraction by kind (alien wonders draw most), scaled by how good this example is (q 0..1).
static func _attraction(kind: String, q: float) -> int:
	var lo_hi := {"WATERFALL": [45, 80], "CANYON": [40, 75], "GLOWING_FIELD": [60, 95], "AURORA_PLAIN": [50, 85],
		"TIDAL_BORE": [45, 80], "SUMMIT": [35, 70]}
	var r: Array = lo_hi[kind]
	return clampi(roundi(lerpf(float(r[0]), float(r[1]), clampf(q, 0.0, 1.0))), 0, 100)


static func _site(world: WorldState, kind: String, cell: int, att: int, steps: int, names: Dictionary, tile: Vector2i, sd: int) -> Dictionary:
	var km := _km(world, Planet.landing(world), cell)
	var where := "COLONY" if tile.x >= 0 else ("REGION" if steps <= REGION_STEPS else "GLOBE")
	var nm := _name(kind, cell, names, sd)
	return {"id": "site:%s:%d" % [kind.to_lower(), cell if tile.x < 0 else tile.y * Terrain.W + tile.x],
		"name": nm, "kind": kind, "attraction": att, "season_mult": _seasons(world, kind, cell),
		"cell": cell, "dist": steps, "km": km, "travel_days": 0 if where == "COLONY" else maxi(1, ceili(float(km) / KM_PER_TRAVEL_DAY)),
		"where": where, "tile": tile}


## A name from the kind's stems, never one already used on this planet.
static func _name(kind: String, cell: int, names: Dictionary, sd: int) -> String:
	var nm := String(KIND_NAMES[kind]).capitalize()
	if _STEMS.has(kind):
		var stems: Array = _STEMS[kind]
		var k0 := _mix(sd + 7, cell)
		for k in stems.size():
			nm = String(stems[(k0 + k) % stems.size()]) + String(_SUFFIX[kind])
			if not names.has(nm):
				break
	names[nm] = true
	return nm


## Calendar seasonality, % per month (January = 0), normalised to an average of ~100.
static func _seasons(world: WorldState, kind: String, cell: int) -> Array:
	var raw: Array = []
	var lat := Planet.lat_lon(cell, Planet.freq(world)).x
	for mo in 12:
		var cl := PlanetClimate.climate(world, cell, mo, false)   # the planet's own seasons (cached per seed), no warming
		var t := float(cl["temp_c"])
		var comfort := clampf(1.0 - absf(t - 20.0) / 22.0, 0.15, 1.0)   # a pleasant month to travel
		var sp := PlanetClimate.season_phase(lat, mo)
		var v := comfort
		match kind:
			"WATERFALL", "RIVER_FALLS":   # in spate in the wet months; frozen falls are a sight of their own, smaller
				v = comfort * (0.5 + float(cl["rain_mm"]) / 120.0) * (0.6 if t < 0.0 else 1.0)
			"GLOWING_FIELD", "GLOW_MEADOW":   # the flora glows in the warm, wet season (the spore season)
				v = 0.25 + maxf(0.0, sp) * 1.2
			"AURORA_PLAIN":   # long dark nights, cold but clear
				v = 0.2 + maxf(0.0, -sp) * 1.3
			"SUMMIT":   # climbing season only
				v = 0.1 + maxf(0.0, sp) * 1.0
			"TIDAL_BORE":   # the moons decide, not the calendar (season_pct)
				v = 0.6 + comfort * 0.4
		raw.append(maxf(v, 0.05))
	var mean := 0.0
	for v2 in raw:
		mean += v2
	mean /= 12.0
	var out: Array = []
	for v3 in raw:
		out.append(clampi(roundi(100.0 * v3 / mean), 10, 300))
	return out


## Sites on the colony map (the landing hex): the landing site itself, falls where the river leaves the hills,
## the glowing native meadows, the crystal crags of the rare-mineral rock.
static func _colony_sites(world: WorldState, home: int, sd: int, names: Dictionary) -> Array:
	var out: Array = []
	if not Terrain.ready(world):
		return out
	var land := Terrain.landing(world)
	out.append(_site(world, "FIRST_LANDING", home, 30, 0, names, land, sd))
	var best := Vector2i(-1, -1)
	var best_s := 0
	var meadow := Vector2i(-1, -1)
	var meadow_s := 0
	var crag := Vector2i(-1, -1)
	for y in Terrain.H:
		for x in Terrain.W:
			var c := Terrain.at(world, x, y)
			if c == "r":
				var s := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						if Terrain.at(world, x + dx, y + dy) in ["h", "k"]:
							s += 2 if Terrain.at(world, x + dx, y + dy) == "k" else 1
				if s > best_s:
					best_s = s
					best = Vector2i(x, y)
			elif c == "n":
				var s2 := 0
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						s2 += 1 if Terrain.at(world, x + dx, y + dy) == "n" else 0
				if s2 > meadow_s:
					meadow_s = s2
					meadow = Vector2i(x, y)
			elif c == "x" and crag.x < 0:
				crag = Vector2i(x, y)
	if best.x >= 0 and best_s >= 3:
		out.append(_site(world, "RIVER_FALLS", home, clampi(25 + best_s * 2, 25, 55), 0, names, best, sd))
	if meadow.x >= 0:
		out.append(_site(world, "GLOW_MEADOW", home, clampi(30 + meadow_s, 30, 60), 0, names, meadow, sd))
	if crag.x >= 0:
		out.append(_site(world, "CRYSTAL_CRAGS", home, 35, 0, names, crag, sd))
	var graves := WasteMap.founders_sight_tile(world)   # A45 W4: the founders' graves, once enough lie there
	if graves.x >= 0:
		out.append(_site(world, "FOUNDERS_CEMETERY", home, 40, 0, names, graves, sd))
	return out


# ================================================================== helpers

static func _bfs(nb: Array, start: int, n: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(-1)
	d[start] = 0
	var q: Array = [start]
	var qi := 0
	while qi < q.size():
		var c: int = q[qi]
		qi += 1
		for j in nb[c]:
			if d[j] < 0:
				d[j] = d[c] + 1
				q.append(j)
	return d


## Hex steps from a to b if within `limit`, else -1.
static func _hex_steps(nb: Array, a: int, b: int, limit: int) -> int:
	var seen := {a: 0}
	var frontier: Array = [a]
	for step in limit + 1:
		var nxt: Array = []
		for c in frontier:
			if c == b:
				return step
			for j in nb[c]:
				if not seen.has(j):
					seen[j] = true
					nxt.append(j)
		frontier = nxt
	return -1


static func _km(world: WorldState, a: int, b: int) -> int:
	var cs: PackedVector3Array = Planet.geometry(Planet.freq(world))["centers"]
	return roundi(cs[a].angle_to(cs[b]) * RADIUS_KM)


## Deterministic integer hash (no engine hash quirks), 0..2^30.
static func _mix(a: int, b: int) -> int:
	var x := (a * 73856093) ^ (b * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return x & 0x3fffffff
