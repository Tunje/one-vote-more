class_name PlanetWildlife
extends RefCounted
## Terra (ecology stage 2, user order via Wilma 2026-11-15; under flag ECO): a small food pyramid per hex.
## User: "an animal pyramid too: insects at the bottom, and if something gets wiped the others are affected; at the
## top, things that can hurt humans ... insects that can both help or hinder, animals that depend on them; real fodder
## for planet-first parties."
##
## Five levels, each in ‰ of the hex's natural balance (1000 = untouched): pollinators (help farms), pests (hurt
## farms; farmland feeds them), foragers (eat insects, mostly pests), grazers (raid crops), predators (eat foragers and
## grazers; can hurt people). Each level moves toward what its habitat and food allow and what the level above leaves
## it, so wiping one out cascades. Habitat shrinks with harm (stage 1) and land clearing (farmed and built map tiles);
## pollution poisons insects. Lever ECO_WILDLIFE_POLICY: PROTECT (no hunting), MANAGE (some hunting at the colony),
## CULL (predators near the colony are culled hard: fewer attacks, but grazers and foragers boom and eat the insects).
##
## Random per world (pure in the seed, nothing saved): creature names, predator danger (1..5) and boldness, insect
## fragility to pollution, how much the crops need pollinators, how often pest swarms come.
## Random per month (stream planet.eco): pest swarm years, attacks on people.
##
## Saved: planet table "web": {"<cell>": [pol, pest, forg, graz, pred]} only for hexes off their natural balance;
## "web_att": [month of each attack in the last 12 months].

const LEVELS := ["pol", "pest", "forg", "graz", "pred"]
const LEVEL_NAMES := {"pol": "pollinators", "pest": "crop pests", "forg": "insect-eaters", "graz": "grazers", "pred": "predators"}
## Months to close the gap to a level's target (‰ of the gap per month): insects fast, predators slow.
const RATE_PM := [150, 200, 60, 50, 25]
const MAX_LEVEL := 3000
const KEEP_OFF := 15          # a hex is saved while any level or its target is more than this ‰ off natural
const COLLAPSE := 150         # a level near the colony under this: PLANET_WILDLIFE_COLLAPSE
const RECOVER := 500          # back above this: PLANET_WILDLIFE_RECOVERY
const BOOM := 1600            # pests or grazers above this: PLANET_WILDLIFE_BOOM
const SWARM_PER_MONTH := 0.006    # x the world's swarm factor: a pest swarm year every ~14 years
const SWARM_ADD := 1500
## Yield losses (%): pollinators gone (x the crops' dependence), pests and grazers booming.
const POL_LOSS := 15
const PEST_LOSS_PER_K := 10
const PEST_LOSS_MAX := 20
const GRAZ_LOSS_PER_K := 6
const GRAZ_LOSS_MAX := 10
## Attacks: expected per month = ATTACK_BASE x danger x boldness x sum over sites of (predators ‰ / 1000 x exposure).
const ATTACK_BASE := 0.012   # an average world (danger 3, boldness 1): ~1 attack a year, a death every few years
const KILL_PER_DANGER := 0.07     # chance an attack kills, per danger point
const OUTDOOR_SITES := ["FARM", "FAMFARM", "MINE"]
const POLICY_LEVER := "ECO_WILDLIFE_POLICY"
const POLICIES := ["PROTECT", "MANAGE", "CULL"]

const NAME_POOLS := {
	"pol": ["glassbees", "lantern moths", "drift wasps", "silkwings", "chime flies", "sunmites"],
	"pest": ["rootmites", "husk beetles", "leaf borers", "rust aphids", "stalk weevils", "blight crickets"],
	"forg": ["skitterlings", "frill lizards", "reed hoppers", "burrow voles", "thorn finches", "glide newts"],
	"graz": ["ridgebacks", "moss deer", "trundlers", "plains hares", "longnecks", "shell boars"],
	"pred": ["dusk stalkers", "ridge cats", "pack wolvens", "night shrikes", "thorn bears", "marsh drakes"],
}

static var _cache := {}


static func policy(world: WorldState) -> String:
	var v := String(world.levers.get(POLICY_LEVER, "MANAGE"))
	return v if v in POLICIES else "MANAGE"


# ================================================================== the world's creatures (pure in the seed)

## {names: {level: name}, danger 1..5, boldness, fragility (pollinators to pollution), dependence (crops on
## pollinators, 0.3..1), swarm (factor on swarm years)}.
static func character(world: WorldState) -> Dictionary:
	var sd := world.rng.derive_seed("planet.eco.web")
	var key := "web|%d" % sd
	if not _cache.has(key):
		var r := RandomNumberGenerator.new()
		r.seed = sd
		var names := {}
		for lv in LEVELS:
			var pool: Array = NAME_POOLS[lv]
			names[lv] = pool[r.randi_range(0, pool.size() - 1)]
		var roll := r.randf()
		var danger := 1 if roll < 0.15 else (2 if roll < 0.40 else (3 if roll < 0.70 else (4 if roll < 0.90 else 5)))
		_cache[key] = {"names": names, "danger": danger, "boldness": snappedf(pow(2.0, r.randf_range(-1.0, 1.0)), 0.01),
			"fragility": snappedf(pow(2.0, r.randf_range(-1.0, 1.0)), 0.01), "dependence": snappedf(r.randf_range(0.3, 1.0), 0.01),
			"swarm": snappedf(pow(2.0, r.randf_range(-1.0, 1.0)), 0.01)}
	return _cache[key]


static func creature(world: WorldState, lv: String) -> String:
	return String(character(world)["names"][lv])


# ================================================================== queries (state)

## The five levels of a hex (‰ of natural): {pol, pest, forg, graz, pred}. 1000 each when untouched.
static func levels(world: WorldState, cell: int) -> Dictionary:
	var row: Array = world.peek("planet").get("web", {}).get(str(cell), [1000, 1000, 1000, 1000, 1000])
	var out := {}
	for i in LEVELS.size():
		out[LEVELS[i]] = int(row[i])
	return out


## Farm yield lost to the food web in a hex (%, 0 when ECO is off): pollinators missing, pests and grazers booming.
static func yield_loss(world: WorldState, cell: int) -> int:
	if not PlanetEcology.on(world) or cell < 0:
		return 0
	var l := levels(world, cell)
	var dep := float(character(world)["dependence"])
	var loss := roundi(dep * float(POL_LOSS * maxi(0, 1000 - l["pol"])) / 1000.0)
	loss += mini(PEST_LOSS_MAX, maxi(0, l["pest"] - 1000) * PEST_LOSS_PER_K / 1000)
	loss += mini(GRAZ_LOSS_MAX, maxi(0, l["graz"] - 1000) * GRAZ_LOSS_PER_K / 1000)
	return loss


## The weakest level at a hex (‰, at most 1000): PLANET_WEB_HEALTH.
static func web_health(world: WorldState, cell: int) -> int:
	var l := levels(world, cell)
	var m := 1000
	for lv in LEVELS:
		m = mini(m, int(l[lv]))
	return m


static func attacks_last_year(world: WorldState) -> int:
	return (world.peek("planet").get("web_att", []) as Array).size()


## Attacks of the last 12 months for the colony map: [{tile: Vector2i, killed, injured, month, site, place}] (facts).
static func attack_marks(world: WorldState) -> Array:
	var out: Array = []
	if not PlanetEcology.on(world):
		return out
	for f in world.facts.query("PLANET_WILDLIFE_ATTACK", world.month - 11, world.month):
		var d: Dictionary = f["data"]
		var tl: Array = d.get("tile", [])
		if tl.size() == 2:
			out.append({"tile": Vector2i(int(tl[0]), int(tl[1])), "killed": int(d["killed"]), "injured": int(d["injured"]),
				"month": int(f["month"]), "site": String(d["site"]), "place": String(d.get("place", ""))})
	return out


# ================================================================== land use on the colony map (per hex)

## Map tiles of each hex (pure in seed, landing, freq).
static func _tiles_per_hex(world: WorldState) -> Dictionary:
	var key := "tph|%d|%d|%d" % [Planet.seed_of(world), Planet.landing(world), Planet.freq(world)]
	if not _cache.has(key):
		var out := {}
		for h in Planet.tile_hexes(world):
			out[h] = int(out.get(h, 0)) + 1
		_cache[key] = out
	return _cache[key]


## {hex: [cleared ‰, farmland ‰]} from the facilities (a farm works a 3x3 patch, a family farm 2 tiles) and the
## map's uses. Recomputed each month (cheap; no memo).
static func land_use(world: WorldState) -> Dictionary:
	var out := {}
	if not Terrain.ready(world):
		return out
	var tph := _tiles_per_hex(world)
	var cleared := {}
	var farmed := {}
	var fac: Dictionary = world.peek("facility")
	var ft: Dictionary = ColonyLayout.facility_tiles(world)
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty():
			continue
		var h := Planet.hex_of_tile(world, ColonyLayout.as_tile(ft[fid]))
		if h < 0:
			continue
		var ty := String(f.get("type", ""))
		var n := 9 if ty == "FARM" else (2 if ty == "FAMFARM" else 1)
		cleared[h] = int(cleared.get(h, 0)) + n
		if ty in ["FARM", "FAMFARM"]:
			farmed[h] = int(farmed.get(h, 0)) + n
	for k in world.peek("map").get("uses", {}):
		var h2 := Planet.hex_of_tile(world, ColonyLayout.as_tile(k))
		if h2 >= 0:
			cleared[h2] = int(cleared.get(h2, 0)) + 1
	for h in cleared:
		var tiles := maxi(1, int(tph.get(h, 1)))
		out[h] = [mini(1000, int(cleared[h]) * 1000 / tiles), mini(1000, int(farmed.get(h, 0)) * 1000 / tiles)]
	return out


# ================================================================== the month (after PlanetEcology.step_month)

## Move every tracked hex's levels, roll a swarm and the attacks. Returns {"crossed": [...], "attacks": [...]} for
## PlanetProvider's facts.
static func step_month(world: WorldState) -> Dictionary:
	var t := world.table("planet")
	var web: Dictionary = t.get("web", {})
	var eco: Dictionary = t.get("eco", {})
	var ch := character(world)
	var lu := land_use(world)
	var pol_name := policy(world)
	var r := world.rng.stream("planet.eco")
	# tracked: settled hexes, their neighbours, polluted or harmed hexes, hexes already off balance, cleared hexes
	var near := {}
	var settled := {}
	for c in Planet.settled(world):
		settled[int(c)] = true
		near[int(c)] = true
		for j in Planet.neighbors(world, int(c)):
			near[int(j)] = true
	var track := {}
	for c in near:
		track[c] = true
	for k in eco:
		track[int(k)] = true
	for k in web:
		track[int(k)] = true
	for h in lu:
		track[int(h)] = true
	var cells: Array = track.keys()
	cells.sort()
	# a pest swarm year: the landing hex and its neighbours
	var swarm := {}
	if r.randf() < SWARM_PER_MONTH * float(ch["swarm"]):
		var li := Planet.landing(world)
		swarm[li] = true
		for j in Planet.neighbors(world, li):
			swarm[int(j)] = true
	var out := {}
	var crossed: Array = []
	for c in cells:
		if Planet.is_water(world, c):
			continue
		var old: Array = web.get(str(c), [1000, 1000, 1000, 1000, 1000])
		var x: Array = old.duplicate()
		var row: Array = eco.get(str(c), [0, 0])
		var hm := int(row[1])
		var use: Array = lu.get(c, [0, 0])
		var hab := (1000 - hm) * (1000 - mini(900, 2 * int(use[0]))) / 1000
		var tox := mini(1000, int(row[0]) / maxi(1, PlanetEcology.capacity(world, c)))   # milli-load / units = ‰ of capacity
		var farm := int(use[1])
		var k_pol := hab * (1000 - mini(950, roundi(float(tox) * 0.45 * float(ch["fragility"])))) / 1000
		var k_pest := (hab + 3 * farm) * (1000 - tox / 5) / 1000
		var pol_t := k_pol * 1000 / (700 + 3 * int(x[2]) / 10)
		var pest_t := k_pest * 1000 / (400 + 6 * int(x[2]) / 10)
		var food := (3 * int(x[0]) + 7 * int(x[1])) / 10
		var forg_t := hab * food / 1000 * 1000 / (500 + int(x[4]) / 2)
		var graz_t := (hab + 2 * farm) * 1000 / (400 + 6 * int(x[4]) / 10)
		var pred_t := hab * ((int(x[2]) + int(x[3])) / 2) / 1000
		if pol_name == "CULL" and near.has(c):
			pred_t = pred_t * (150 if settled.has(c) else 400) / 1000
		elif pol_name == "MANAGE" and settled.has(c):
			pred_t = pred_t * 800 / 1000
		var tg := [pol_t, pest_t, forg_t, graz_t, pred_t]
		for i in 5:
			var v := int(x[i])
			var gap := clampi(int(tg[i]), 0, MAX_LEVEL) - v
			if gap != 0:
				var step: int = gap * int(RATE_PM[i]) / 1000
				if step == 0:
					step = signi(gap)
				v += step
			x[i] = clampi(v, 0, MAX_LEVEL)
		if swarm.has(c):
			x[1] = mini(MAX_LEVEL, int(x[1]) + SWARM_ADD)
		if near.has(c):
			for i in 5:
				var a := int(old[i])
				var b := int(x[i])
				if a >= COLLAPSE and b < COLLAPSE and not _was_collapsed(world, c, LEVELS[i]):
					crossed.append({"cell": c, "level": LEVELS[i], "kind": "COLLAPSE", "value": b})
				elif a < RECOVER and b >= RECOVER and _was_collapsed(world, c, LEVELS[i]):
					crossed.append({"cell": c, "level": LEVELS[i], "kind": "RECOVERY", "value": b})
				elif i in [1, 3] and a <= BOOM and b > BOOM and not (i == 1 and swarm.has(c)):   # a swarm is its own fact
					crossed.append({"cell": c, "level": LEVELS[i], "kind": "BOOM", "value": b})
		var off := false   # kept while a level, or where it is heading, is off natural (small drifts must add up)
		for i in 5:
			off = off or absi(int(x[i]) - 1000) > KEEP_OFF or absi(clampi(int(tg[i]), 0, MAX_LEVEL) - 1000) > KEEP_OFF
		if off:
			out[str(c)] = x
	t["web"] = out
	# collapses remembered until recovered (so a recovery fact follows only a collapse)
	var col: Dictionary = t.get("web_col", {})
	for x2 in crossed:
		var ck := "%d|%s" % [int(x2["cell"]), x2["level"]]
		if x2["kind"] == "COLLAPSE":
			col[ck] = world.month
		elif x2["kind"] == "RECOVERY":
			col.erase(ck)
	t["web_col"] = col
	var attacks := _attacks(world, r, ch)
	var hist: Array = t.get("web_att", [])
	var kept: Array = []
	for m in hist:
		if int(m) > world.month - 12:
			kept.append(int(m))
	for _a in attacks:
		kept.append(world.month)
	t["web_att"] = kept
	return {"crossed": crossed, "attacks": attacks, "swarm": not swarm.is_empty()}


static func _was_collapsed(world: WorldState, cell: int, lv: String) -> bool:
	return world.peek("planet").get("web_col", {}).has("%d|%s" % [cell, lv])


## Places where people meet the wild: farms, family farms and mines, and the settlements. Exposure grows with the
## land's richness (vitality), distance from the landing site (the colony's edge) and empty land around the site.
## [{kind, fid, tile, hex, exposure}] sorted by fid/name.
static func sites(world: WorldState) -> Array:
	var out: Array = []
	if not Terrain.ready(world):
		return out
	var land := Terrain.landing(world)
	var fac: Dictionary = world.peek("facility")
	var ft: Dictionary = ColonyLayout.facility_tiles(world)
	var busy := {}
	for fid in ft:
		busy[ColonyLayout.as_tile(ft[fid])] = true
	for k in world.peek("map").get("uses", {}):
		busy[ColonyLayout.as_tile(k)] = true
	var cand: Array = []
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty() or not String(f.get("type", "")) in OUTDOOR_SITES or bool(f.get("mothball", false)):
			continue
		cand.append({"kind": String(f["type"]), "fid": fid, "tile": ColonyLayout.as_tile(ft[fid]), "district": String(f.get("district", "")), "org": String(f.get("org", ""))})
	for s in ColonyLayout.settlements(world):
		cand.append({"kind": "SETTLEMENT", "fid": "", "tile": ColonyLayout.as_tile(s["tile"]), "district": String(s.get("district", "")), "org": "", "name": String(s.get("name", ""))})
	for c in cand:
		var tl: Vector2i = c["tile"]
		var h := Planet.hex_of_tile(world, tl)
		if h < 0:
			continue
		var crowd := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if busy.has(tl + Vector2i(dx, dy)):
					crowd += 1
		var edge := clampf((Vector2(tl - land).length() - 6.0) / 20.0, 0.1, 1.0)
		var e := float(PlanetEcology.vitality(world, h)) / 1000.0 * edge * (1.0 - float(mini(crowd, 40)) / 49.0)
		if c["kind"] == "SETTLEMENT":
			e *= 0.5
		c["hex"] = h
		c["exposure"] = snappedf(e, 0.001)
		out.append(c)
	return out


static func _attacks(world: WorldState, r: RandomNumberGenerator, ch: Dictionary) -> Array:
	var ss := sites(world)
	if ss.is_empty():
		return []
	var w: Array = []
	var total := 0.0
	for s in ss:
		var x := float(levels(world, int(s["hex"]))["pred"]) / 1000.0 * float(s["exposure"])
		w.append(x)
		total += x
	var lam := ATTACK_BASE * float(ch["danger"]) * float(ch["boldness"]) * total
	var n := PlanetClimate._poisson(r, lam)
	var out: Array = []
	for _k in mini(n, 5):
		var pick := r.randf() * total
		var idx := 0
		while idx < w.size() - 1 and pick > float(w[idx]):
			pick -= float(w[idx])
			idx += 1
		var s: Dictionary = ss[idx]
		var killed := 1 if r.randf() < KILL_PER_DANGER * float(ch["danger"]) else 0
		var injured := 0 if killed > 0 and r.randf() < 0.5 else 1 + (1 if r.randf() < 0.3 else 0)
		out.append({"site": s, "killed": killed, "injured": injured})
	return out
