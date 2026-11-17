class_name PlanetSeasons
extends RefCounted
## Terra (ecology stage 3, user via Wilma 2026-11-15: "Don't forget birds, preferably that migrate, and seasons.
## Terra's gotta make the planet feel real."). The seasons as the economy and the land feel them.
##
## Flag SEASONS (opt-in; Bob A/Bs it before anyone switches it on): farms follow the farm year. Output is multiplied by
## farm_pct = season_pct x (100 - drought loss). season_pct averages 100 over the year at every hex, so a year's food
## stays as calibrated, but the harvest comes in the growing months and winter runs on stores. heating_pct is a query
## only (yearly average 100) for Bob's household energy, if he wants it.
## Flag ECO: wild land's activity through the year (insects dormant in the cold; PlanetWildlife.levels_now), and facts
## PLANET_HARD_WINTER / PLANET_HEATWAVE at the colony. PLANET_HARVEST (once a year after the growing season) needs SEASONS.
## Pure functions of (seed, hex, month) from PlanetClimate's baseline (no greenhouse offset, so caches stay pure).

const FLAG := "SEASONS"
## Share of a farm's output that does not depend on the season (stores, cold frames, winter crops).
const BASE_SHARE := 0.1
## Drought: from DROUGHT_FROM dry months in a row, DROUGHT_PER_MONTH % a month, up to DROUGHT_MAX %.
const DROUGHT_FROM := 3
const DROUGHT_PER_MONTH := 5
const DROUGHT_MAX := 30
## Heating: degree-months below this temperature.
const HEAT_BASE_C := 15.0
## Hard winter / heatwave at the colony: a month this many °C off normal.
const EXTREME_C := 3.0
## A month counts toward the harvest season when its growing value is at least this.
const GROWING_FROM := 0.3

static var _cache := {}


## Always on: part of the rebuild ("nothing behind an off switch", rebuild-company.md 12.4, 33).
static func on(_world: WorldState = null) -> bool:
	return true


## 12 growing values (0..1) for a hex, months 0..11 (January first), from the planet's own climate.
static func _growing_year(world: WorldState, cell: int) -> PackedFloat32Array:
	var key := "g|%d|%d|%d" % [Planet.seed_of(world), Planet.freq(world), cell]
	if not _cache.has(key):
		var out := PackedFloat32Array()
		out.resize(12)
		for m in 12:
			out[m] = float(PlanetClimate.climate(world, cell, m, false)["growing"])
		_cache[key] = out
	return _cache[key]


## How much of the year's farm output falls in this month, % (yearly average 100).
static func season_pct(world: WorldState, cell: int, month: int) -> int:
	var g := _growing_year(world, cell)
	var mean := 0.0
	for v in g:
		mean += BASE_SHARE + (1.0 - BASE_SHARE) * v
	mean /= 12.0
	if mean <= 0.0:
		return 100
	return roundi(100.0 * (BASE_SHARE + (1.0 - BASE_SHARE) * g[posmod(month, 12)]) / mean)


## Yield lost to drought this month, %: DROUGHT_PER_MONTH for each dry month from DROUGHT_FROM, capped.
static func drought_loss(world: WorldState, cell: int, month: int) -> int:
	var dm := int(PlanetClimate.weather(world, cell, month)["drought_months"])
	if dm < DROUGHT_FROM:
		return 0
	return mini(DROUGHT_MAX, (dm - DROUGHT_FROM + 1) * DROUGHT_PER_MONTH)


## Farm output this month in % of the flat calibrated rate (SEASONS): the season's share less the drought.
static func farm_pct(world: WorldState, cell: int, month: int) -> int:
	return season_pct(world, cell, month) * (100 - drought_loss(world, cell, month)) / 100


## Heating need this month, % of the yearly average (100); 100 flat where it is never cold. Query only.
static func heating_pct(world: WorldState, cell: int, month: int) -> int:
	var key := "h|%d|%d|%d" % [Planet.seed_of(world), Planet.freq(world), cell]
	if not _cache.has(key):
		var hd := PackedFloat32Array()
		hd.resize(12)
		for m in 12:
			hd[m] = maxf(0.0, HEAT_BASE_C - float(PlanetClimate.climate(world, cell, m, false)["temp_c"]))
		_cache[key] = hd
	var h: PackedFloat32Array = _cache[key]
	var mean := 0.0
	for v in h:
		mean += v
	mean /= 12.0
	if mean <= 0.0:
		return 100
	return roundi(100.0 * h[posmod(month, 12)] / mean)


## Wild land's activity this month (0.25 dormant .. 1.0 full), and its yearly mean: insects and grazers follow it.
static func activity(world: WorldState, cell: int, month: int) -> float:
	return 0.25 + 0.75 * _growing_year(world, cell)[posmod(month, 12)]


static func mean_activity(world: WorldState, cell: int) -> float:
	var s := 0.0
	for v in _growing_year(world, cell):
		s += 0.25 + 0.75 * v
	return s / 12.0


## The months (0..11) of a hex's growing season, and the month after it ends (when the harvest is reckoned), or -1.
static func harvest_month(world: WorldState, cell: int) -> int:
	var g := _growing_year(world, cell)
	for m in 12:
		if g[m] >= GROWING_FROM and g[(m + 1) % 12] < GROWING_FROM:
			return (m + 1) % 12
	return -1


## The season just ended at a hex: {pct, months, worst_drought} — farm output over the growing months in % of a normal
## season (drought and, with ECO, the land's harm and the food web).
static func harvest(world: WorldState, cell: int, end_month: int) -> Dictionary:
	var g := _growing_year(world, cell)
	var sum := 0.0
	var n := 0
	var worst := 0
	var m := end_month - 1
	while n < 12 and g[posmod(m, 12)] >= GROWING_FROM:
		var eco := float(PlanetEcology.yield_pct(world, cell)) / 100.0
		sum += float(100 - drought_loss(world, cell, m)) * eco
		worst = maxi(worst, int(PlanetClimate.weather(world, cell, m)["drought_months"]))
		n += 1
		m -= 1
	return {"pct": roundi(sum / float(maxi(1, n))), "months": n, "worst_drought": worst}


## This month at a hex if it is extreme: {kind HARD_WINTER|HEATWAVE, temp_c, anom_c} or {}.
static func extreme(world: WorldState, cell: int, month: int) -> Dictionary:
	var wx := PlanetClimate.weather(world, cell, month)
	var a := float(wx["temp_anom_c"])
	if String(wx["season"]) == "WINTER" and a <= -EXTREME_C and float(wx["temp_c"]) < 0.0:
		return {"kind": "HARD_WINTER", "temp_c": float(wx["temp_c"]), "anom_c": a}
	if String(wx["season"]) == "SUMMER" and a >= EXTREME_C:
		return {"kind": "HEATWAVE", "temp_c": float(wx["temp_c"]), "anom_c": a}
	return {}
