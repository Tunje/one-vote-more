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


func indicator_defs() -> Array:
	var out: Array = []
	for row in [
		["PLANET_RAIN_PCT", "% of normal rain (milli)", [0, 400000], 1, {"good": 100000, "bad": 40000}],
		["PLANET_TEMP_ANOM", "°C vs normal (milli)", [-15000, 15000], 0, {"good": 0, "bad": 6000}],
		["PLANET_DROUGHT_MONTHS", "months (milli)", [0, 24000], -1, {"good": 0, "bad": 6000}],
		["PLANET_AIR_POLLUTION", "index (milli)", [0, 100000], -1, {"good": 0, "bad": 60000}],
		["PLANET_WARMING", "°C (milli)", [0, 10000], -1, {"good": 0, "bad": 2000}],
	]:
		# concerns stay empty for now: politics decides how much people care (Wilma)
		out.append({"id": row[0], "owner": OWNER, "unit": row[1], "range": row[2], "granularity": "COLONY",
			"polarity": row[3], "concerns": {}, "normalize": row[4], "phase": TickPhase.NATURE,
			"visibility": "PUBLIC", "perceptionLag": 0})
	return out


func init_world(world: WorldState) -> void:
	Planet.generate(world)   # idempotent


func run_phase(phase: int, world: WorldState) -> void:
	if phase != TickPhase.NATURE:
		return
	Planet.generate(world)   # worlds set up before the planet existed
	PlanetClimate.step_month(world)
	var home := Planet.landing(world)
	var wx := PlanetClimate.weather(world, home)
	world.set_indicator(OWNER, "PLANET_RAIN_PCT", "COLONY", int(wx["rain_pct"]) * 1000)
	world.set_indicator(OWNER, "PLANET_TEMP_ANOM", "COLONY", roundi(float(wx["temp_anom_c"]) * 1000.0))
	world.set_indicator(OWNER, "PLANET_DROUGHT_MONTHS", "COLONY", int(wx["drought_months"]) * 1000)
	world.set_indicator(OWNER, "PLANET_AIR_POLLUTION", "COLONY", roundi(PlanetClimate.air_pollution(world, home) * 1000.0))
	world.set_indicator(OWNER, "PLANET_WARMING", "COLONY", roundi(PlanetClimate.warming_c(world) * 1000.0))
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
