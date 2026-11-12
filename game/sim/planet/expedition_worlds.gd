class_name ExpeditionWorlds
extends RefCounted
## Terra (A47, planning/spec-expedition-v1.md §X2): the candidate worlds of a new game. 3–5 per game seed, each a full
## Planet + Terrain (its own planet seed: Planet.candidate_seed). A survey card per world: climate at the landing
## site, land and deposits, phenomena and sights, hazards, distance (ship interval and cost), with honest uncertainty:
## some facts are SURVEYED (exact), others only ESTIMATED (a range that holds the true value).
## Choosing: world.meta["expedition"]["planet"] = k before the game is set up; Planet.generate then builds that world
## (planet and colony grid) and everything downstream follows. Pure; cached per seed.

const MIN_WORLDS := 3
const MAX_WORLDS := 5
const STAR_NAMES := ["Tau Ceti", "Gliese 667", "Wolf 1061", "Ross 128", "Luyten", "Kapteyn", "Teegarden", "HD 40307",
	"Lacaille 9352", "Groombridge 34", "Van Maanen", "Struve 2398"]
const WORLD_NAMES := ["Verdance", "Hollowmere", "Kestrel", "New Albion", "Cinder", "Serein", "Amberlea", "Thule",
	"Halcyon", "Brightwater", "Galene", "Orison", "Marrow", "Tamsin", "Elysia", "Corvid"]
## Storm strikes per hex per year by latitude band (spec-planet-v1, seed 1, 100 years), in thousandths.
const STORM_RATE := {"CYCLONE": [20, 60, 10, 0, 0], "DUST": [10, 20, 10, 0, 0], "RAIN_FRONT": [0, 0, 100, 120, 10], "BLIZZARD": [0, 0, 0, 50, 40]}

static var _cache := {}


## How many candidate worlds this game seed offers (3–5).
static func count(seed_v: int) -> int:
	var w := WorldState.new(seed_v)
	return MIN_WORLDS + w.rng.derive_seed("expedition.count") % (MAX_WORLDS - MIN_WORLDS + 1)


## A candidate world, generated (planet + colony grid) on a scratch world of the same game seed. Cached; do not modify.
static func world(seed_v: int, k: int) -> WorldState:
	var key := "w|%d|%d" % [seed_v, k]
	if not _cache.has(key):
		if _cache.size() >= 24:
			_cache.clear()
		var w := WorldState.new(seed_v)
		w.meta["expedition"] = {"planet": k}
		Planet.generate(w)
		_cache[key] = w
	return _cache[key]


## All candidates' survey cards for a game seed (see card()).
static func candidates(seed_v: int) -> Array:
	var key := "c|%d" % seed_v
	if not _cache.has(key):
		var out: Array = []
		for k in count(seed_v):
			out.append(card(seed_v, k))
		_cache[key] = out
	return _cache[key]


## Make a game world the chosen candidate. Call before the game is set up (EconSim.make / new_game init_world).
static func choose(world_v: WorldState, k: int) -> void:
	var ex: Dictionary = world_v.meta.get("expedition", {})
	ex["planet"] = k
	world_v.meta["expedition"] = ex


## The survey card of candidate k:
## {index, name, star, distance_ly, ship_months: [lo, hi], cost_index (100 = an average reach), harshness 0..100,
##  landing: {lat, lon, biome, height_m, coast}, climate: {warm_c, cold_c, rain_mm, swing_c},
##  land: {fertile_pct, river, ore, rare, native, buildable_pct}, phenomena: [{kind, certainty}],
##  sights: {count, best, best_attraction}, hazards: {storms_per_decade, drought_years_per_century, kinds},
##  survey: {fact: {value, lo, hi, certainty: SURVEYED|ESTIMATED}}, summary: [lines]}
## Every number is an int (degrees and mm rounded); "°C" values are whole degrees.
static func card(seed_v: int, k: int) -> Dictionary:
	var w := world(seed_v, k)
	var r := RandomNumberGenerator.new()
	r.seed = Planet.seed_of(w) ^ 0x5eed
	var home := Planet.landing(w)
	var ll := Planet.lat_lon(home, Planet.freq(w))
	var lat := absi(roundi(ll.x))
	# climate at the landing site over a year
	var warm := -999.0
	var cold := 999.0
	var rain := 0
	var frost := 0
	for mo in 12:
		var cl := PlanetClimate.climate(w, home, mo, false)
		warm = maxf(warm, float(cl["temp_c"]))
		cold = minf(cold, float(cl["temp_c"]))
		rain += int(cl["rain_mm"])
		frost += 1 if float(cl["temp_c"]) < 0.0 else 0
	# land on the colony grid
	var n := {"f": 0, "n": 0, "o": 0, "x": 0, "r": 0, "build": 0}
	for y in Terrain.H:
		for x in Terrain.W:
			var c := Terrain.at(w, x, y)
			if n.has(c):
				n[c] += 1
			if c in Terrain.BUILDABLE_HOUSING:
				n["build"] += 1
	var tiles := Terrain.W * Terrain.H
	var fertile_pct := (int(n["f"]) + int(n["n"])) * 100 / tiles
	# phenomena: what the land and the sky make likely here
	var ph: Array = [{"kind": "SOLAR_FLARE", "certainty": "SURVEYED"}]
	var wild := 0
	for j in Planet.neighbors(w, home):
		wild += 1 if Planet.biome(w, j) in ["j", "w", "F"] else 0
	if wild >= 2 or Planet.biome(w, home) in ["j", "w", "F"]:
		ph.append({"kind": "SPORE_BLOOM", "certainty": "ESTIMATED"})
	if Planet.is_coast(w, home):
		ph.append({"kind": "MOON_SURGE", "certainty": "SURVEYED"})
	var sites := PlanetSites.sites(w)
	var best := {}
	for s in sites:
		if best.is_empty() or int(s["attraction"]) > int(best["attraction"]):
			best = s
	# hazards: storm strikes by latitude band (cyclones only reach coasts), droughts over a simulated century
	var band := 0 if lat < 15 else (1 if lat < 30 else (2 if lat < 45 else (3 if lat < 60 else 4)))
	var storms := 0
	var kinds: Array = []
	for kind in STORM_RATE:
		var rate: int = STORM_RATE[kind][band]
		if kind == "CYCLONE" and not Planet.is_coast(w, home):
			rate /= 4
		storms += rate
		if rate >= 10:
			kinds.append(kind)
	var droughts := 0
	var dry := 0
	for m in 1200:
		if PlanetClimate._rain_pct(w, home, m) < PlanetClimate.DRY_PCT:
			dry += 1
			if dry == 3:
				droughts += 1
		else:
			dry = 0
	# distance and reach: closer worlds get ships more often and cost less to reach
	var ly := 6 + r.randi_range(0, 18)
	var lo := 12 + ly * 6 / 10
	# harshness: growing food first (fertile share, rain, frost months), then heat, cold, storms, droughts, spores
	var food := clampf((15.0 - float(fertile_pct)) * 3.0, 0.0, 45.0) + clampf((600.0 - float(rain)) / 12.0, 0.0, 30.0) + float(frost) * 3.0
	var rest := maxf(0.0, warm - 28.0) * 2.0 + maxf(0.0, -5.0 - cold) + float(storms) / 10.0 + float(droughts) * 0.8
	for p in ph:
		rest += 5.0 if p["kind"] == "SPORE_BLOOM" else 0.0
	var harsh := clampi(roundi(food + rest * 0.6), 0, 100)
	var out := {
		"index": k, "name": WORLD_NAMES[(Planet.seed_of(w) & 0x7fff) % WORLD_NAMES.size()],
		"star": STAR_NAMES[((Planet.seed_of(w) >> 15) & 0x7fff) % STAR_NAMES.size()],
		"distance_ly": ly, "ship_months": [lo, lo + 8 + ly / 4], "cost_index": 60 + ly * 3 + harsh / 4, "harshness": harsh,
		"landing": {"lat": roundi(ll.x), "lon": roundi(ll.y), "biome": String(Planet.NAMES.get(Planet.biome(w, home), "?")),
			"height_m": Planet.height(w, home) * Planet.METERS_PER_STEP, "coast": Planet.is_coast(w, home)},
		"climate": {"warm_c": roundi(warm), "cold_c": roundi(cold), "rain_mm": rain, "swing_c": roundi(warm - cold), "frost_months": frost},
		"land": {"fertile_pct": fertile_pct, "river": int(n["r"]) > 0, "ore": int(n["o"]), "rare": int(n["x"]), "native": int(n["n"]),
			"buildable_pct": int(n["build"]) * 100 / tiles},
		"phenomena": ph,
		"sights": {"count": sites.size(), "best": String(best.get("name", "")), "best_attraction": int(best.get("attraction", 0))},
		"hazards": {"storms_per_decade": storms / 100, "storm_rate_milli": storms, "drought_years_per_century": droughts, "kinds": kinds},
	}
	# the survey: orbital surveys measure climate and land; deposits, native crops and hazards are estimates
	var sv := {}
	sv["fertile_pct"] = _fact(fertile_pct, "SURVEYED", r)
	sv["warm_c"] = _fact(roundi(warm), "SURVEYED", r)
	sv["cold_c"] = _fact(roundi(cold), "SURVEYED", r)
	sv["ore"] = _fact(int(n["o"]), "ESTIMATED", r)
	sv["rare"] = _fact(int(n["x"]), "ESTIMATED", r)
	sv["native"] = _fact(int(n["n"]), "ESTIMATED", r)
	sv["storms_per_decade"] = _fact(storms / 100, "ESTIMATED", r)
	sv["droughts"] = _fact(droughts, "ESTIMATED", r)
	sv["sights"] = _fact(sites.size(), "ESTIMATED", r)
	out["survey"] = sv
	out["summary"] = _summary(out)
	return out


## A survey fact: exact when SURVEYED; when ESTIMATED a range around the truth (the truth always inside, not centred).
static func _fact(v: int, certainty: String, r: RandomNumberGenerator) -> Dictionary:
	if certainty == "SURVEYED":
		return {"value": v, "lo": v, "hi": v, "certainty": certainty}
	var spread := maxi(1, absi(v) * r.randi_range(25, 60) / 100)
	var lo := v - r.randi_range(0, spread)
	return {"value": v, "lo": maxi(0, lo), "hi": lo + spread + r.randi_range(0, spread / 2) + (1 if lo + spread <= v else 0) + maxi(0, v - (lo + spread)), "certainty": certainty}


static func _summary(c: Dictionary) -> Array:
	var cl: Dictionary = c["climate"]
	var ld: Dictionary = c["land"]
	var lines: Array = []
	lines.append("%s around %s, %d light-years: a ship every %d–%d months" % [c["name"], c["star"], int(c["distance_ly"]),
		int(c["ship_months"][0]), int(c["ship_months"][1])])
	lines.append("Landing on %s at %d°%s, %d m%s" % [String(c["landing"]["biome"]), absi(int(c["landing"]["lat"])),
		"N" if int(c["landing"]["lat"]) >= 0 else "S", int(c["landing"]["height_m"]), ", on the coast" if c["landing"]["coast"] else ""])
	lines.append("Climate: %d to %d °C over the year, %d mm of rain" % [int(cl["cold_c"]), int(cl["warm_c"]), int(cl["rain_mm"])])
	lines.append("Land: %d%% fertile%s" % [int(ld["fertile_pct"]), ", a river" if ld["river"] else ", no river"])
	return lines
