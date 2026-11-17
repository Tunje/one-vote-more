class_name PlanetProvider
extends PicProvider
## Terra: the planet's monthly CONDITIONS (spec-planet-v1, A40, T2). Runs in TickPhase.NATURE, before trade and
## production: draws this month's storms and alien phenomena, drifts air pollution and updates the greenhouse stock
## (PlanetClimate.step_month), publishes indicators and reports weather that hits a settled hex as facts.
## It never applies damage: Bob's hazard engine reads PlanetClimate's queries.

const OWNER := "planet"


func owner_id() -> String:
	return OWNER


func phases() -> Array:
	return [TickPhase.NATURE]



## Wilma (politics): which concerns the ecology's measures feed, and how strongly (like LawData.INDICATOR_TUNING).
## They are only written with ECO on, so a base game is unaffected.
const ECO_CONCERNS := {
	"PLANET_ECO_HARM": {"ENVIRONMENT_QUALITY": 0.6},
	"PLANET_WILDLIFE_ATTACKS": {"SAFETY": 0.5},
	"PLANET_WEB_HEALTH": {"ENVIRONMENT_QUALITY": 0.4},
	"PLANET_BIRDS": {"ENVIRONMENT_QUALITY": 0.3},
}

func indicator_defs() -> Array:
	var out: Array = []
	for row in [
		["PLANET_RAIN_PCT", "% of normal rain (milli)", [0, 400000], 1, {"good": 100000, "bad": 40000}],
		["PLANET_TEMP_ANOM", "°C vs normal (milli)", [-15000, 15000], 0, {"good": 0, "bad": 6000}],
		["PLANET_DROUGHT_MONTHS", "months (milli)", [0, 24000], -1, {"good": 0, "bad": 6000}],
		["PLANET_AIR_POLLUTION", "index (milli)", [0, 100000], -1, {"good": 0, "bad": 60000}],
		["PLANET_WARMING", "°C (milli)", [0, 10000], -1, {"good": 0, "bad": 2000}],
		["PLANET_ECO_HARM", "‰ (milli)", [0, 1000000], -1, {"good": 0, "bad": 600000}],   # ECO only
		["PLANET_WILDLIFE_ATTACKS", "attacks in 12 months (milli)", [0, 100000], -1, {"good": 0, "bad": 6000}],   # ECO only
		["PLANET_WEB_HEALTH", "weakest level ‰ (milli)", [0, 1000000], 1, {"good": 1000000, "bad": 300000}],   # ECO only
		["PLANET_BIRDS", "flocks' size ‰ of natural (milli)", [0, 2000000], 1, {"good": 1000000, "bad": 400000}],   # ECO only (stage 3)
		["TRANSPORT_FREIGHT_JAM", "‰ of freight held back by the roads (milli)", [0, 1000000], -1, {"good": 0, "bad": 300000}],   # FREIGHT_ROADS only
	]:
		# how much people care is politics' call (Wilma): the ecology's three measures reach voters; the weather ones don't yet
		out.append({"id": row[0], "owner": OWNER, "unit": row[1], "range": row[2], "granularity": "COLONY",
			"polarity": row[3], "concerns": ECO_CONCERNS.get(row[0], {}), "normalize": row[4], "phase": TickPhase.NATURE,
			"visibility": "PUBLIC", "perceptionLag": 0})
	return out


## ECO stage 2: how the colony treats wildlife (PlanetWildlife). Only on the table when ECO is on.
func lever_defs() -> Array:
	return [{"id": PlanetWildlife.POLICY_LEVER, "owner": OWNER, "type": "ENUM", "values": PlanetWildlife.POLICIES, "default": "MANAGE",
		"legalLevel": "REGULATION", "foundingEra": "COMMANDER", "ideology": {"ENVIRONMENT": -6.0}, "concerns": {"SAFETY": 20, "ENVIRONMENT_QUALITY": -20},
		"implementation": "STAFF_T_IMPL_REGULATORY", "lag": 1, "scope": "COLONY", "fiscal": null, "domain": "ENV"}]


func init_world(world: WorldState) -> void:
	Planet.generate(world)   # idempotent


func run_phase(phase: int, world: WorldState) -> void:
	if phase != TickPhase.NATURE:
		return
	Planet.generate(world)   # worlds set up before the planet existed
	PlanetClimate.step_month(world)
	var crossed: Array = []
	var wild := {}
	var birds: Array = []
	if PlanetEcology.on(world):   # ECO: pollution released, spread and absorbed; harmed land raises dust (own stream)
		var pt := world.table("planet")
		crossed = PlanetEcology.step_month(world, pt["storms"], pt["phenomena"])
		wild = PlanetWildlife.step_month(world)
		birds = PlanetBirds.step_month(world)   # stage 3: the flocks' year and their arrivals at the colony
	Transport.step_month(world)
	if FreightRoads.on(world):
		world.set_indicator(OWNER, "TRANSPORT_FREIGHT_JAM", "COLONY", FreightRoads.jam_share_pm(world) * 1000)
	WasteMap.step_month(world)    # A45 W5: last month's sewage and leachate flow down the river   # A43 T1: the network wears, storms and mud close tracks (after this month's weather)
	var home := Planet.landing(world)
	var wx := PlanetClimate.weather(world, home)
	world.set_indicator(OWNER, "PLANET_RAIN_PCT", "COLONY", int(wx["rain_pct"]) * 1000)
	world.set_indicator(OWNER, "PLANET_TEMP_ANOM", "COLONY", roundi(float(wx["temp_anom_c"]) * 1000.0))
	world.set_indicator(OWNER, "PLANET_DROUGHT_MONTHS", "COLONY", int(wx["drought_months"]) * 1000)
	world.set_indicator(OWNER, "PLANET_AIR_POLLUTION", "COLONY", roundi(PlanetClimate.air_pollution(world, home) * 1000.0))
	world.set_indicator(OWNER, "PLANET_WARMING", "COLONY", roundi(PlanetClimate.warming_c(world) * 1000.0))
	if PlanetEcology.on(world):
		world.set_indicator(OWNER, "PLANET_ECO_HARM", "COLONY", PlanetEcology.harm(world, home) * 1000)
		_report_eco(world, crossed)
		world.set_indicator(OWNER, "PLANET_WILDLIFE_ATTACKS", "COLONY", PlanetWildlife.attacks_last_year(world) * 1000)
		world.set_indicator(OWNER, "PLANET_WEB_HEALTH", "COLONY", PlanetWildlife.web_health(world, home) * 1000)
		_report_wild(world, wild)
		world.set_indicator(OWNER, "PLANET_BIRDS", "COLONY", PlanetBirds.colony_index(world) * 1000)
		_report_birds(world, birds)
		var ex := PlanetSeasons.extreme(world, home, world.month)
		if not ex.is_empty() and String(PlanetSeasons.extreme(world, home, world.month - 1).get("kind", "")) != String(ex["kind"]):   # once per spell
			world.add_fact({"type": "PLANET_" + String(ex["kind"]), "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
				"magnitude": 35, "visibility": "PUBLIC", "data": {"hex": home, "temp_c": float(ex["temp_c"]), "anom_c": float(ex["anom_c"])}})
	if PlanetSeasons.on(world) and posmod(world.month, 12) == PlanetSeasons.harvest_month(world, home) and world.month >= 6:
		var hv := PlanetSeasons.harvest(world, home, world.month)
		world.add_fact({"type": "PLANET_HARVEST", "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
			"magnitude": clampi(20 + absi(100 - int(hv["pct"])), 0, 100), "visibility": "PUBLIC",
			"data": {"hex": home, "pct": int(hv["pct"]), "months": int(hv["months"]), "worst_drought": int(hv["worst_drought"])}})
	for cell in Planet.settled(world):
		for h in PlanetClimate.storms_at(world, cell) + PlanetClimate.phenomena_at(world, cell):
			_report(world, cell, h)
		if int(PlanetClimate.weather(world, cell)["drought_months"]) in [3, 6, 12]:
			_report(world, cell, {"kind": "DROUGHT", "strength": int(PlanetClimate.weather(world, cell)["drought_months"]) / 3})


## A weather fact for a settled hex: nature is responsible (no actor), the hazard engine decides the damage.
func _report(world: WorldState, cell: int, h: Dictionary) -> void:
	var kind := String(h["kind"])
	var st := int(h["strength"])
	world.add_fact({"type": "PLANET_" + kind, "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
		"magnitude": clampi(10 + st * 15, 0, 100), "visibility": "PUBLIC",
		"data": {"hex": cell, "kind": kind, "strength": st, "name": String(PlanetClimate.NAMES.get(kind, kind.to_lower().replace("_", " ")))}})


## ECO: land near the colony (a settled hex or a neighbour) crossing a harm level. Rising: PLANET_ECO_DAMAGE with the
## level; falling back under the first level: PLANET_ECO_RECOVERY. Pollution has many authors, so no one is named
## responsible here; politics decides the blame.
func _report_eco(world: WorldState, crossed: Array) -> void:
	if crossed.is_empty():
		return
	var near := {}
	for c in Planet.settled(world):
		near[int(c)] = true
		for j in Planet.neighbors(world, int(c)):
			near[int(j)] = true
	for x in crossed:
		var c := int(x["cell"])
		if not near.has(c):
			continue
		var rising: bool = int(x["new"]) > int(x["old"])
		if not rising and int(x["level"]) != PlanetEcology.LEVELS[0]:
			continue
		var lv := int(x["level"])
		world.add_fact({"type": "PLANET_ECO_DAMAGE" if rising else "PLANET_ECO_RECOVERY", "owner": OWNER, "subjects": [], "responsible": [],
			"impact": {}, "magnitude": clampi(20 + lv / 20, 0, 100) if rising else 30, "visibility": "PUBLIC",
			"data": {"hex": c, "harm": int(x["new"]), "level": lv, "colony": c == Planet.landing(world)}})


## ECO stage 2: attacks on people, and food-web collapses, booms and recoveries near the colony. PUBLIC; no one
## responsible (nature); the place and what stood there go in data so politics can attach blame and worry.
func _report_wild(world: WorldState, wild: Dictionary) -> void:
	var ch := PlanetWildlife.character(world)
	var orgs: Dictionary = world.peek("org")
	for a in wild.get("attacks", []):
		var s: Dictionary = a["site"]
		var org: Dictionary = orgs.get(String(s.get("org", "")), {})
		var fac: Dictionary = world.peek("facility").get(String(s.get("fid", "")), {})
		var tl: Vector2i = s["tile"]
		var killed := int(a["killed"])
		if killed > 0 and String(s.get("district", "")) != "":   # Bob's hook: the dead leave the population (plant's workers first)
			killed = EconFace.pop_casualties(world, String(s["district"]), killed, "OUTDOOR", String(s.get("fid", "")))
		world.add_fact({"type": "PLANET_WILDLIFE_ATTACK", "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
			"magnitude": clampi(25 + 30 * killed + 5 * int(a["injured"]), 0, 100), "visibility": "PUBLIC",
			"data": {"hex": int(s["hex"]), "tile": [tl.x, tl.y], "creature": PlanetWildlife.creature(world, "pred"), "danger": int(ch["danger"]),
				"killed": killed, "injured": int(a["injured"]), "site": String(s["kind"]), "fid": String(s.get("fid", "")),
				"org": String(s.get("org", "")), "district": String(s.get("district", "")), "place": String(s.get("name", "")),
				"opened": int(fac.get("opened", -1)), "family_farm": bool(org.get("family", false)),
				"grant_funded": int(org.get("grant_paid", 0)) > 0, "grant_month": int(org.get("grant_month", -1)),
				"policy": PlanetWildlife.policy(world)}})
	for x in wild.get("crossed", []):
		var lv := String(x["level"])
		world.add_fact({"type": "PLANET_WILDLIFE_" + String(x["kind"]), "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
			"magnitude": 40 if x["kind"] == "COLLAPSE" else 30, "visibility": "PUBLIC",
			"data": {"hex": int(x["cell"]), "level": lv, "group": PlanetWildlife.LEVEL_NAMES[lv], "creature": PlanetWildlife.creature(world, lv),
				"value": int(x["value"]), "colony": int(x["cell"]) == Planet.landing(world), "policy": PlanetWildlife.policy(world)}})
	if wild.get("swarm", false):
		world.add_fact({"type": "PLANET_WILDLIFE_SWARM", "owner": OWNER, "subjects": [], "responsible": [], "impact": {}, "magnitude": 35,
			"visibility": "PUBLIC", "data": {"hex": Planet.landing(world), "creature": PlanetWildlife.creature(world, "pest")}})


## ECO stage 3: the flocks at the colony. ARRIVED (great when big or up 30%), FAILED ("the birds didn't come": with the
## most harmed hex they use, so blame can reach along the route), GONE (a flock collapsed). PUBLIC, no one responsible.
func _report_birds(world: WorldState, events: Array) -> void:
	for e in events:
		var f: Dictionary = e["flock"]
		var d := {"flock": String(f["id"]), "name": String(f["name"]), "role": String(f["role"]), "size": int(e["size"]),
			"hex": Planet.landing(world)}   # the flocks arrive at (or fail to reach) the colony's hex
		var mag := 25
		match String(e["kind"]):
			"ARRIVED":
				d["last_year"] = int(e["last"])
				d["phase"] = String(e["phase"])
				d["great"] = bool(e["great"])
				mag = 30 if e["great"] else 15
			"FAILED":
				d["last_year"] = int(e["last"])
				d["phase"] = String(e["phase"])
				var wh := PlanetBirds.worst_hex(world, f)
				d["worst_hex"] = int(wh["cell"])
				d["worst_harm"] = int(wh["harm"])
				d["worst_is_colony"] = int(wh["cell"]) == Planet.landing(world)
				mag = 40
			"GONE":
				mag = 50
		world.add_fact({"type": "PLANET_BIRDS_" + String(e["kind"]), "owner": OWNER, "subjects": [], "responsible": [], "impact": {},
			"magnitude": mag, "visibility": "PUBLIC", "data": d})
