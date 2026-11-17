class_name PlanetEcology
extends RefCounted
## Terra (user order via Wilma, 2026-11-15; opt-in flag "ECO"): a simple ecology for the planet.
##
## Pollution is released in the hex where it is made (v1: each economic district's emissions at the district's centre
## tile; to-do for Bob: per-facility emissions at the facility's own tile). Every month a share drifts downwind,
## a little spreads to all neighbours, some runs down the river, and some breaks down. Land that takes more than it
## can absorb is harmed; harm heals slowly once the load falls.
##
## Every world differs (pure functions of the seed, nothing saved): how rich each hex's living layer is (biome x
## noise), how fast the planet recovers, how sensitive it is, and one trait (SCRUBBER, FRAGILE, SPORE_PRONE, HARDY).
##
## Effects (only with ECO on): rain anomalies swing wider over harmed land (deeper droughts and floods) and dust storms
## rise from badly harmed land (PlanetClimate); farm yields follow yield_pct (EconProduction); indicator PLANET_ECO_HARM
## and facts PLANET_ECO_DAMAGE / PLANET_ECO_RECOVERY (PlanetProvider); the globe tints harmed land.
##
## Saved: world table "planet", key "eco": {"<cell>": [poll_milli, harm_permille]} for touched hexes only. A hex drops
## out once its load is below DROP_MILLI and its harm is 0.

const FLAG := "ECO"
const TRAITS := ["SCRUBBER", "FRAGILE", "SPORE_PRONE", "HARDY"]
const TRAIT_NAMES := {"SCRUBBER": "scrubber moss (pollution breaks down twice as fast)",
	"FRAGILE": "fragile soils (harm costs twice the harvest)", "SPORE_PRONE": "spore-prone life (harmed land releases spores)",
	"HARDY": "hardy life"}

## Monthly movement of a hex's load (‰). The rest stays (STAY = 1000 - the others).
const WIND_PM := 120        # downwind neighbour
const DIFFUSE_PM := 60      # shared among all neighbours
const RIVER_PM := 50        # downstream (land hexes)
const DECAY_PM := 30        # breaks down (x2 SCRUBBER, x resilience)
const DROP_MILLI := 500     # a load below this (0.5 units) is dropped when the hex is unharmed
## What a hex absorbs without harm (units): (CAP_BASE + vitality/CAP_DIV) / sensitivity, 100..350 on an average world.
## Calibrated on seed 1 (a founding colony emits ~90 units a month by year 20; its own hex then holds ~350-400).
const CAP_BASE := 100
const CAP_DIV := 4
## Harm moves toward its target 1000·(1 - cap/load): up by HARM_UP_PM of the gap per month (x sensitivity, ~5 years),
## down by HEAL_PM (x resilience, ~20 years).
const HARM_UP_PM := 15
const HEAL_PM := 4
## THE rough-weather knob: rain anomalies over a fully harmed hex swing (1 + ROUGH) times as wide.
const ROUGH := 0.6
## Dust storms per month from a fully harmed land hex (scaled by harm above DUST_FROM); spores the same (SPORE_PRONE).
const DUST_FROM := 400
const DUST_PER_MONTH := 0.08
const SPORE_FROM := 300
const SPORE_PER_MONTH := 0.10
## Farm yield lost at full harm (%); FRAGILE doubles it.
const YIELD_LOSS := 30
## Harm thresholds (‰) for facts.
const LEVELS := [300, 600, 900]
## Living-layer richness by biome (‰ before noise).
const VITALITY := {"j": 950, "w": 900, "F": 850, "f": 800, "g": 650, "h": 550, "s": 450, "H": 400, "T": 300, "M": 250,
	"d": 200, "P": 100, "I": 50, "S": 0, "D": 0}

static var _cache := {}


## Always on: part of the rebuild ("nothing behind an off switch", rebuild-company.md 12.4, 33).
static func on(_world: WorldState = null) -> bool:
	return true


# ================================================================== the planet's character (pure in the seed)

## {resilience, sensitivity, trait}. Drawn from the seed alone (no stream state), so nothing is saved.
static func character(world: WorldState) -> Dictionary:
	var sd := world.rng.derive_seed("planet.eco.character")
	var key := "char|%d" % sd
	if not _cache.has(key):
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var res := pow(2.0, r.randf_range(-1.0, 1.0))    # 0.5 .. 2.0, as likely halved as doubled
		var sen := pow(2.0, r.randf_range(-1.0, 1.0))
		_cache[key] = {"resilience": snappedf(res, 0.01), "sensitivity": snappedf(sen, 0.01), "trait": TRAITS[r.randi_range(0, TRAITS.size() - 1)]}
	return _cache[key]


## Richness of a hex's living layer, 0..1000 (0 at sea): biome x seeded noise (0.75..1.25).
static func vitality(world: WorldState, cell: int) -> int:
	if Planet.is_water(world, cell):
		return 0
	var sd := world.rng.derive_seed("planet.eco.vitality")
	var key := "vit|%d|%d" % [sd, Planet.freq(world)]
	if not _cache.has(key):
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.seed = sd & 0x7fffffff
		nz.frequency = 2.2
		nz.fractal_octaves = 2
		var cs: PackedVector3Array = Planet.geometry(Planet.freq(world))["centers"]
		var out := PackedInt32Array()
		out.resize(cs.size())
		for i in cs.size():
			var base := int(VITALITY.get(Planet.biome(world, i), 500))
			out[i] = clampi(roundi(float(base) * (1.0 + 0.25 * nz.get_noise_3dv(cs[i]))), 0, 1000)
		_cache[key] = out
	return (_cache[key] as PackedInt32Array)[cell]


## Load a hex absorbs without harm (units); a sensitive world absorbs less.
static func capacity(world: WorldState, cell: int) -> int:
	return roundi(float(CAP_BASE + vitality(world, cell) / CAP_DIV) / float(character(world)["sensitivity"]))


# ================================================================== queries (state)

static func pollution(world: WorldState, cell: int) -> float:
	return float(_row(world, cell)[0]) / 1000.0


## Harm to a hex's living layer, 0..1000‰ (0 when ECO is off).
static func harm(world: WorldState, cell: int) -> int:
	return int(_row(world, cell)[1])


static func _row(world: WorldState, cell: int) -> Array:
	return world.peek("planet").get("eco", {}).get(str(cell), [0, 0])


## Farm yield of a hex in percent: 100 untouched, 100 - YIELD_LOSS at full harm (FRAGILE: twice the loss), less what
## the food web takes (PlanetWildlife.yield_loss: pollinators missing, pests and grazers booming).
static func yield_pct(world: WorldState, cell: int) -> int:
	if not on(world) or cell < 0:
		return 100
	var loss := YIELD_LOSS * (2 if String(character(world)["trait"]) == "FRAGILE" else 1)
	return maxi(20, 100 - loss * harm(world, cell) / 1000 - PlanetWildlife.yield_loss(world, cell))   # stage 2: the food web


## How much wider rain anomalies swing over a hex (1.0 when unharmed or ECO off).
static func rough(world: WorldState, cell: int) -> float:
	if not on(world):
		return 1.0
	return 1.0 + ROUGH * float(harm(world, cell)) / 1000.0


## The hex holding an economic district's centre (display anchor), or the landing hex.
static func district_hex(world: WorldState, d: String) -> int:
	var li := Planet.landing(world)
	if not Terrain.ready(world):
		return li
	var anchors: Dictionary = ColonyLayout.anchors(world)
	if not anchors.has(d):
		return li
	var h := Planet.hex_of_tile(world, ColonyLayout.as_tile(anchors[d]))
	return h if h >= 0 else li


# ================================================================== the month (PlanetClimate.step_month, NATURE)

## Release last month's emissions, spread and break down the load, move harm, roll dust storms and spores.
## Returns [{cell, old, new}] for hexes whose harm crossed a LEVELS threshold (PlanetProvider reports them).
static func step_month(world: WorldState, storms: Array, phenomena: Array) -> Array:
	var t := world.table("planet")
	var eco: Dictionary = t.get("eco", {})
	var ch := character(world)
	var geo := Planet.geometry(Planet.freq(world))
	var cs: PackedVector3Array = geo["centers"]
	var nb: Array = geo["nbrs"]
	var load := {}   # cell -> milli
	for k in eco:
		load[int(k)] = int(eco[k][0])
	# --- release: each district's emissions at its centre hex (v1 fallback, see the header)
	var em: Dictionary = CoreUtil.peek_st(world).get("emissions", {})
	var ds: Array = em.keys()
	ds.sort()
	for d in ds:
		var h := district_hex(world, String(d))
		if h >= 0:
			load[h] = int(load.get(h, 0)) + int(em[d])
	# --- spread and break down (integer milli; cells in order so the rounding is deterministic)
	var decay_pm := clampi(roundi(float(DECAY_PM) * float(ch["resilience"]) * (2.0 if String(ch["trait"]) == "SCRUBBER" else 1.0)), 1, 400)
	var cells: Array = load.keys()
	cells.sort()
	var next := {}
	for c in cells:
		var v := int(load[c])
		if v <= 0:
			continue
		var wind_to := _downwind(cs, nb, c)
		var down := Planet.downstream(world, c) if not Planet.is_water(world, c) else -1
		var to_wind := v * WIND_PM / 1000
		var each := v * DIFFUSE_PM / 1000 / (nb[c] as PackedInt32Array).size()
		var to_river := v * RIVER_PM / 1000 if down >= 0 else 0
		var gone := v * decay_pm / 1000
		var stay := v - to_wind - each * (nb[c] as PackedInt32Array).size() - to_river - gone
		next[c] = int(next.get(c, 0)) + stay
		next[wind_to] = int(next.get(wind_to, 0)) + to_wind
		for j in nb[c]:
			next[j] = int(next.get(j, 0)) + each
		if down >= 0:
			next[down] = int(next.get(down, 0)) + to_river
	# --- harm moves toward its target; heals when the load falls
	var crossed: Array = []
	var keys: Array = next.keys()
	for k in eco:
		if not int(k) in next:
			keys.append(int(k))
	keys.sort()
	var out := {}
	for c in keys:
		var v := int(next.get(c, 0))
		var old := int(eco.get(str(c), [0, 0])[1])
		var hm := old
		if not Planet.is_water(world, c):
			var cap_m := capacity(world, c) * 1000
			var target := 0 if v <= cap_m else 1000 - 1000 * cap_m / v
			if target > hm:
				hm += maxi(1, roundi(float((target - hm) * HARM_UP_PM) / 1000.0 * float(ch["sensitivity"])))
				hm = mini(hm, target)
			elif target < hm:
				hm -= maxi(1, roundi(float((hm - target) * HEAL_PM) / 1000.0 * float(ch["resilience"])))
				hm = maxi(hm, target)
		for lv in LEVELS:
			if (old < lv) != (hm < lv):
				crossed.append({"cell": c, "old": old, "new": hm, "level": lv})
				break
		if v >= DROP_MILLI or hm > 0:
			out[str(c)] = [v, hm]
	t["eco"] = out
	# --- harmed land raises dust; spore-prone life releases spores (own stream: ECO off leaves the weather alone)
	var r := world.rng.stream("planet.eco")
	for k in CoreUtil.sorted_keys(out):
		var c := int(k)
		var hm := int(out[k][1])
		if Planet.is_water(world, c):
			continue
		if hm > DUST_FROM and r.randf() < DUST_PER_MONTH * float(hm - DUST_FROM) / float(1000 - DUST_FROM):
			var tr := PlanetClimate.track(world, cs, nb, r, c, "DUST", r.randi_range(1, 2), r.randi_range(2, 5))
			tr["eco"] = true
			tr["id"] = "storm:%d:%d" % [world.month, storms.size()]
			storms.append(tr)
		if String(ch["trait"]) == "SPORE_PRONE" and hm > SPORE_FROM and r.randf() < SPORE_PER_MONTH * float(hm - SPORE_FROM) / float(1000 - SPORE_FROM):
			var sp := PlanetClimate.track(world, cs, nb, r, c, "SPORE_BLOOM", r.randi_range(1, 2), r.randi_range(2, 5))
			sp["eco"] = true
			phenomena.append(sp)
	return crossed


static func _downwind(cs: PackedVector3Array, nb: Array, cell: int) -> int:
	var dir := PlanetClimate.wind(cs[cell])
	var best := cell
	var bd := -INF
	for j in nb[cell]:
		var d := (cs[j] - cs[cell]).normalized().dot(dir)
		if d > bd:
			bd = d
			best = j
	return best


## Worst harm among the hexes the colony stands on and their neighbours (indicator PLANET_ECO_HARM uses the landing hex).
static func summary(world: WorldState) -> Dictionary:
	var eco: Dictionary = world.peek("planet").get("eco", {})
	var worst := 0
	var harmed := 0
	for k in eco:
		var hm := int(eco[k][1])
		worst = maxi(worst, hm)
		if hm >= LEVELS[0]:
			harmed += 1
	return {"hexes": eco.size(), "harmed": harmed, "worst": worst, "trait": character(world)["trait"]}
