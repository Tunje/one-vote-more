class_name PlanetClimate
extends RefCounted
## Terra (spec-planet-v1 "Climate, weather and pollution", A40, T2): the planet's CONDITIONS. Seasons, rain and
## temperature for any hex; storms that travel hex by hex with the prevailing winds; alien phenomena; downwind
## air pollution; a greenhouse stock. It never applies damage: Bob's hazard engine reads these queries.
##
## Pure functions of (seed, month, hex): climate(), weather(). Drawn monthly in TickPhase.NATURE (PlanetProvider)
## and saved in world table "planet": "storms" (this month's tracks), "phenomena", "air" (hex -> milli index),
## "ghg" (greenhouse stock, milli).

## Axial tilt (degrees): seasons, opposite in the two hemispheres. Northern summer peaks in month 7.
const TILT_DEG := 26.0
## THE warming knob (A40: barely noticeable for now; a future tech/industry system may scale it).
## °C per unit of greenhouse stock. Calibrated so 100 years of founding-era industry stay below ~0.3 °C.
const WARMING_PER_STOCK := 0.00002
const GHG_DECAY := 0.002            # share of the stock the planet absorbs per month
const LAPSE_C_PER_STEP := 0.52      # 6.5 °C/km at 80 m per height step
const DRY_PCT := 70                 # a month below this share of normal rain counts toward a drought

## Storm kinds (weather) and alien phenomena. Strength 1..5 (storms), 1..5 / 1..3 (phenomena).
const STORMS := ["CYCLONE", "DUST", "BLIZZARD", "RAIN_FRONT"]
const PHENOMENA := ["SOLAR_FLARE", "SPORE_BLOOM", "MOON_SURGE"]
const NAMES := {"CYCLONE": "cyclone", "DUST": "dust storm", "BLIZZARD": "blizzard", "RAIN_FRONT": "rain front",
	"SOLAR_FLARE": "solar flare", "SPORE_BLOOM": "spore bloom", "MOON_SURGE": "twin-moon surge"}

static var _field := {}   # weather-noise seed -> [FastNoiseLite, FastNoiseLite]


# ================================================================== climate (pure)

## Seasonal phase for a latitude: +1 at the height of local summer, -1 at the depth of winter.
static func season_phase(lat_deg: float, month: int) -> float:
	var s := sin(TAU * float(posmod(month, 12) + 1 - 4) / 12.0)   # month index 0 = January
	return s if lat_deg >= 0.0 else -s


static func season_name(lat_deg: float, month: int) -> String:
	var mo := posmod(month, 12)
	var north := ["WINTER", "WINTER", "SPRING", "SPRING", "SPRING", "SUMMER", "SUMMER", "SUMMER", "AUTUMN", "AUTUMN", "AUTUMN", "WINTER"]
	var south := {"WINTER": "SUMMER", "SUMMER": "WINTER", "SPRING": "AUTUMN", "AUTUMN": "SPRING"}
	var s: String = north[mo]
	return s if lat_deg >= 0.0 else String(south[s])


## Baseline climate of a hex in a month (no weather noise): {temp_c, rain_mm, season, growing}.
## growing: 0..1, how good the month is for crops by temperature (rain is in weather()).
## with_warming false: the planet's own climate (no greenhouse offset), a pure function of the seed.
static func climate(world: WorldState, cell: int, month: int, with_warming: bool = true) -> Dictionary:
	var ll := Planet.lat_lon(cell, Planet.freq(world))
	var lat := ll.x
	var sl := sin(deg_to_rad(absf(lat)))
	var h := Planet.height(world, cell)
	var coast := Planet.is_coast(world, cell) or h < 0
	var tmean := 28.0 - 32.0 * sl * sl - 18.0 * sl * sl * sl * sl - LAPSE_C_PER_STEP * float(maxi(h, 0)) + (warming_c(world) if with_warming else 0.0)
	var amp := (1.5 + 17.0 * sl) * (0.55 if coast else 1.0) * (TILT_DEG / 26.0)
	var sp := season_phase(lat, month)
	var temp := tmean + amp * sp
	var moist := Planet.moisture(world, cell)
	var rain := 8.0 + 170.0 * moist * moist
	if absf(lat) < 35.0:
		rain *= 1.0 + 0.5 * sp        # monsoon: tropical rain peaks in summer
	else:
		rain *= 1.0 - 0.15 * sp       # mid-latitudes: a little wetter in winter
	var growing := clampf((temp - 4.0) / 12.0, 0.0, 1.0) * (0.0 if temp > 40.0 else 1.0)
	return {"temp_c": snappedf(temp, 0.1), "rain_mm": roundi(rain), "season": season_name(lat, month), "growing": snappedf(growing, 0.01)}


# ================================================================== weather (pure)

static func _noises(world: WorldState) -> Array:
	var sd := world.rng.derive_seed("planet.weather.field")
	if not _field.has(sd):
		var a := FastNoiseLite.new()
		a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		a.seed = sd & 0x7fffffff
		a.frequency = 1.4
		a.fractal_octaves = 3
		var b := FastNoiseLite.new()
		b.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		b.seed = (sd >> 7) & 0x7fffffff
		b.frequency = 1.1
		b.fractal_octaves = 2
		_field[sd] = [a, b]
	return _field[sd]


## Raw anomaly field in -1..1 at a hex and month: two noise patterns drifting at different speeds, so dry and wet
## spells cover regions and last for months.
static func _anom(world: WorldState, cell: int, month: int, which: int) -> float:
	var nz: Array = _noises(world)
	var c: Vector3 = Planet.geometry(Planet.freq(world))["centers"][cell]
	var t := float(month)
	var p1 := c.rotated(Vector3.UP, t * 0.045) * 1.5
	var p2 := c.rotated(Vector3(0.3, 1.0, 0.1).normalized(), -t * 0.027) * 1.5
	var a: FastNoiseLite = nz[0]
	var b: FastNoiseLite = nz[1]
	var off := 7.3 * float(which)
	return clampf(a.get_noise_3d(p1.x + off, p1.y, p1.z) * 0.9 + b.get_noise_3d(p2.x, p2.y + off, p2.z) * 0.7, -1.0, 1.0)


static func _rain_pct(world: WorldState, cell: int, month: int) -> int:
	return roundi(100.0 * exp(0.8 * _anom(world, cell, month, 0)))


## Weather of any hex in a month: {rain_pct (100 = normal), rain_mm, temp_c, temp_anom_c, drought_months}.
## drought_months counts consecutive months (this one included, at most 24) below DRY_PCT of normal rain.
static func weather(world: WorldState, cell: int, month: int = -1) -> Dictionary:
	var m := world.month if month < 0 else month
	var cl := climate(world, cell, m)
	var rp := _rain_pct(world, cell, m)
	var ta := snappedf(3.0 * _anom(world, cell, m, 1), 0.1)
	var dm := 0
	while dm < 24 and m - dm >= 0 and _rain_pct(world, cell, m - dm) < DRY_PCT:
		dm += 1
	return {"rain_pct": rp, "rain_mm": roundi(float(cl["rain_mm"]) * rp / 100.0), "temp_c": snappedf(float(cl["temp_c"]) + ta, 0.1),
		"temp_anom_c": ta, "drought_months": dm, "season": cl["season"], "growing": cl["growing"]}


# ================================================================== drawn monthly (NATURE)

## Storms and phenomena that crossed a hex this month: [{kind, strength}] (strongest first).
static func storms_at(world: WorldState, cell: int) -> Array:
	return _hits(world.peek("planet").get("storms", []), cell)


## Alien phenomena affecting a hex this month: [{kind, strength}]. A solar flare hits every hex.
static func phenomena_at(world: WorldState, cell: int) -> Array:
	return _hits(world.peek("planet").get("phenomena", []), cell)


static func _hits(list: Array, cell: int) -> Array:
	var out: Array = []
	for s in list:
		var cells: Array = s["cells"]
		if s.get("global", false) or cell in cells:
			out.append({"kind": s["kind"], "strength": int(s["strength"])})
	out.sort_custom(func(a, b): return int(a["strength"]) > int(b["strength"]))
	return out


## Air pollution index of a hex (0..100): the settlements' own emissions plus what the wind brings.
static func air_pollution(world: WorldState, cell: int) -> float:
	return float(world.peek("planet").get("air", {}).get(str(cell), 0)) / 1000.0


## Global warming offset in °C from the greenhouse stock.
static func warming_c(world: WorldState) -> float:
	return float(world.peek("planet").get("ghg", 0)) / 1000.0 * WARMING_PER_STOCK


## Prevailing wind at a hex as a unit tangent vector: trade winds (to the west) below 30°, westerlies to 60°,
## polar easterlies beyond. Slight poleward drift in the trades, equatorward beyond 60°.
static func wind(c: Vector3) -> Vector3:
	var east := Vector3.UP.cross(c)
	if east.length() < 0.001:
		return Vector3.RIGHT
	east = east.normalized()
	var north := c.cross(east).normalized()
	var lat := rad_to_deg(asin(clampf(c.y, -1.0, 1.0)))
	var pole := north * signf(lat) if lat != 0.0 else north
	if absf(lat) < 30.0:
		return (-east + pole * 0.35).normalized()
	if absf(lat) < 60.0:
		return (east + pole * 0.2).normalized()
	return (-east - pole * 0.2).normalized()


## The neighbour of `cell` lying most along direction `dir` (jittered by r).
static func _step(cs: PackedVector3Array, nb: Array, cell: int, dir: Vector3, r: RandomNumberGenerator, jitter: float) -> int:
	var best := cell
	var bd := -INF
	for j in nb[cell]:
		var d := (cs[j] - cs[cell]).normalized().dot(dir) + r.randf_range(-jitter, jitter)
		if d > bd:
			bd = d
			best = j
	return best


## One month of storms, phenomena, pollution drift and greenhouse stock. Called by PlanetProvider in NATURE.
static func step_month(world: WorldState) -> void:
	var r := world.rng.stream("planet.weather")
	var t := world.table("planet")
	var geo := Planet.geometry(Planet.freq(world))
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var n := cs.size()
	var m := world.month
	var warm := warming_c(world)
	var storms: Array = []
	# --- cyclones: warm seas between 5° and 25°, late summer to autumn in each hemisphere
	for hemi in [1.0, -1.0]:
		var season := maxf(0.0, season_phase(10.0 * hemi, m - 1))   # lags the sun by a month
		var lam := 2.2 * season * (1.0 + 0.15 * warm)
		for _k in _poisson(r, lam):
			var g := _pick(world, r, cs, func(i): return Planet.height(world, i) < 0 and absf(Planet.lat_lon(i).x) > 5.0 and absf(Planet.lat_lon(i).x) < 25.0 and signf(Planet.lat_lon(i).x) == hemi)
			if g >= 0:
				storms.append(_track(world, cs, nb, r, g, "CYCLONE", r.randi_range(1, 3), r.randi_range(12, 26)))
	# --- dust storms: deserts in their dry, hot season
	for _k in _poisson(r, 2.0):
		var g2 := _pick(world, r, cs, func(i): return Planet.biome(world, i) in ["d", "s"])
		if g2 >= 0 and season_phase(Planet.lat_lon(g2).x, m) > -0.3:
			storms.append(_track(world, cs, nb, r, g2, "DUST", r.randi_range(1, 3), r.randi_range(3, 9)))
	# --- blizzards: high latitudes in winter
	for hemi2 in [1.0, -1.0]:
		var winter := maxf(0.0, -season_phase(50.0 * hemi2, m))
		for _k in _poisson(r, 2.5 * winter):
			var g3 := _pick(world, r, cs, func(i): return absf(Planet.lat_lon(i).x) > 45.0 and signf(Planet.lat_lon(i).x) == hemi2)
			if g3 >= 0:
				storms.append(_track(world, cs, nb, r, g3, "BLIZZARD", r.randi_range(1, 4), r.randi_range(5, 12)))
	# --- rain fronts: the westerlies, all year, more in winter
	for _k in _poisson(r, 5.0):
		var g4 := _pick(world, r, cs, func(i): return absf(Planet.lat_lon(i).x) > 30.0 and absf(Planet.lat_lon(i).x) < 62.0)
		if g4 >= 0:
			storms.append(_track(world, cs, nb, r, g4, "RAIN_FRONT", r.randi_range(1, 3), r.randi_range(6, 14)))
	for k in storms.size():
		storms[k]["id"] = "storm:%d:%d" % [m, k]
	t["storms"] = storms
	# --- alien phenomena
	var ph: Array = []
	var activity := 0.5 + 0.5 * sin(TAU * float(m) / 132.0)   # the star's 11-year cycle
	if r.randf() < 0.015 + 0.05 * activity:
		ph.append({"kind": "SOLAR_FLARE", "strength": _powerlaw(r, 5), "cells": [], "global": true})
	for _k in _poisson(r, 3.0):
		var g5 := _pick(world, r, cs, func(i): return Planet.biome(world, i) in ["j", "w", "F"])
		if g5 >= 0 and season_phase(Planet.lat_lon(g5).x, m) > 0.0 and int(weather(world, g5, m)["rain_pct"]) > 100:
			var tr := _track(world, cs, nb, r, g5, "SPORE_BLOOM", r.randi_range(1, 3), r.randi_range(3, 8))
			ph.append(tr)
	var align := cos(TAU * float(m) / 7.0) + cos(TAU * float(m) / 11.0)   # two moons: predictable surges
	if align > 1.75:
		var coast_cells: Array = []
		for i in Planet.settled(world):
			if Planet.is_coast(world, i):
				coast_cells.append(i)
		ph.append({"kind": "MOON_SURGE", "strength": 3 if align > 1.95 else (2 if align > 1.85 else 1), "cells": coast_cells,
			"global": false, "all_coasts": true})
	t["phenomena"] = ph
	# --- air pollution drift and greenhouse stock (stopgap read agreed with Bob until EconGeo.emissions lands)
	var em: Dictionary = EconUtil.peek_st(world).get("emissions", {})
	var total := 0.0
	for d in em:
		total += float(em[d]) / 1000.0
	var air: Dictionary = t.get("air", {})
	var src := Planet.landing(world)
	var fresh := {str(src): total}
	var cur := src
	var share := 0.5
	for _s in 4:   # the plume: half, a quarter, ... of the source's load reaches the next hexes downwind
		cur = _step(cs, nb, cur, wind(cs[cur]), r, 0.0)
		fresh[str(cur)] = float(fresh.get(str(cur), 0.0)) + total * share
		share *= 0.5
	var keys: Array = air.keys()
	for k in fresh:
		if not k in keys:
			keys.append(k)
	keys.sort()
	var next_air := {}
	for k in keys:
		var v := 0.7 * float(air.get(k, 0)) / 1000.0 + 0.3 * float(fresh.get(k, 0.0))
		if v >= 0.05:
			next_air[k] = int(clampf(v, 0.0, 100.0) * 1000.0)
	t["air"] = next_air
	t["ghg"] = int(float(t.get("ghg", 0)) * (1.0 - GHG_DECAY) + total * 1000.0)


static func _poisson(r: RandomNumberGenerator, lam: float) -> int:
	if lam <= 0.0:
		return 0
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= r.randf()
		if p <= l:
			return k
		k += 1
		if k > 50:
			return k
	return k


static func _powerlaw(r: RandomNumberGenerator, top: int) -> int:
	var s := 1
	while s < top and r.randf() < 0.4:
		s += 1
	return s


## A random hex meeting `ok` (up to 400 tries), or -1.
static func _pick(world: WorldState, r: RandomNumberGenerator, cs: PackedVector3Array, ok: Callable) -> int:
	for _try in 400:
		var i := r.randi_range(0, cs.size() - 1)
		if ok.call(i):
			return i
	return -1


## A storm's track: it moves with the wind one hex per step, strengthening over warm sea (cyclones) and
## weakening over land or cold water. Ends when it dies out or after `steps` hexes.
static func _track(world: WorldState, cs: PackedVector3Array, nb: Array, r: RandomNumberGenerator, start: int, kind: String, strength: int, steps: int) -> Dictionary:
	var cells: Array = [start]
	var s := float(strength)
	var peak := strength
	var cur := start
	for _k in steps:
		cur = _step(cs, nb, cur, wind(cs[cur]), r, 0.35)
		if cur in cells:
			break
		var sea := Planet.height(world, cur) < 0
		var lat := absf(Planet.lat_lon(cur).x)
		match kind:
			"CYCLONE":
				s += 0.45 if sea and lat < 28.0 else (-0.9 if not sea else -0.4)
			"DUST":
				s += -0.4 if sea else -0.1
			"BLIZZARD", "RAIN_FRONT":
				s -= 0.15
			_:
				s -= 0.3
		if s < 0.6:
			break
		s = minf(s, 5.0)
		peak = maxi(peak, roundi(s))
		cells.append(cur)
	return {"kind": kind, "strength": clampi(peak, 1, 5), "cells": cells, "global": false}
