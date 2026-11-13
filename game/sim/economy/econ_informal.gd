class_name EconInformal
extends RefCounted
## S7 (user, after v6; spec-settlements-v1 §S7): when formal housing fails. In v6 everyone born after the homes filled
## squeezed into full blocks at 140–175% occupancy with nothing visible happening. Now:
##   - Doubling up has a ceiling: above OCC_CAP (130%) households per formal home, new households stop squeezing in.
##   - Households beyond the ceiling build SHACKS on free land near the jobs (district "shacks", households ×S): no water,
##     sewage or roads — higher mortality and fertility loss (EconCohorts), fire risk (a fact), concern indicators.
##     Land is limited (SHACK_LAND: shacks per formal home in the district) and shacks need scrap material (none
##     while MATERIAL costs ≥ MAT_SCARCE × its base price).
##   - Households that find neither a home nor room for a shack are HOMELESS (district "homeless", households ×S):
##     counted, the worst health, and working families among them leave on the next ship (EconCohorts).
##   - Crowded young adults delay families (lower fertility, EconCohorts.tfr).
##   - When formal homes are built again, shack households move in and the shacks are abandoned (SHACK_DECAY a month).
## The political answer — clear, legalise and upgrade, or build — belongs to the government (Wilma); the informal AREA
## kind and the shacks on the map come with S1 areas (Terra). Integer state only.

const S := EconUtil.S
const OCC_CAP := 1300  # ‰ households per formal home beyond which nobody else squeezes in
const SHACK_RATE_PM := 250  # ‰ of the unsheltered households who put up a shack each month
const SHACK_LAND_PM := 600  # ‰ shacks per formal home the district's free land can take
const SHACK_DECAY_PM := 50  # ‰ of surplus shacks abandoned a month once homes are free again
const MAT_SCARCE := 3  # MATERIAL price ≥ this × base: no scrap for shacks
const FIRE_PM_PER_100 := 4  # ‰ chance a month of a shack fire per 100 shack households
const FIRE_LOSS := [200, 500]  # ‰ of a district's shacks a fire destroys
const HOMELESS_FACT_PM := 20  # ‰ of a district's households homeless before the papers notice


static func shacks(world: WorldState, d: String) -> int:
	return int(world.peek("district").get(d, {}).get("shacks", 0))


static func homeless(world: WorldState, d: String) -> int:
	return int(world.peek("district").get(d, {}).get("homeless", 0))


## Share (0..1) of the district's households living in shacks / homeless.
static func shack_share(world: WorldState, d: String) -> float:
	var hh := int(world.peek("district").get(d, {}).get("households", 0))
	return 0.0 if hh <= 0 else clampf(float(shacks(world, d)) / float(hh), 0.0, 1.0)


static func homeless_share(world: WorldState, d: String) -> float:
	var hh := int(world.peek("district").get(d, {}).get("households", 0))
	return 0.0 if hh <= 0 else clampf(float(homeless(world, d)) / float(hh), 0.0, 1.0)


static func _materials_ok(world: WorldState) -> bool:
	var s := EconUtil.st(world)
	var base := int(s.get("base", {}).get("MATERIAL", 0))
	return base <= 0 or int(s["prices"].get("MATERIAL", 0)) < MAT_SCARCE * base


## S7 is OPT-IN for now (Wilma, 2026-11-13): seed 1 with S7 on stalled at ~5.5k by Y50 (farm building froze at 20
## for 30 years) against 10.8k with it off — under investigation. Tools and tests turn it on with
## world.meta["on"] = ["S7"]; meta["off"] still wins.
static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("S7") and not EconUtil.off(world, "S7")


## SOCIAL, after the district housing update (EconHouseholds._housing).
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var mat_ok := _materials_ok(world)
	var rng := world.rng.stream("econ.informal")
	for d in EconUtil.sorted_keys(world.table("district")):
		var dr: Dictionary = world.table("district")[d]
		var hh := int(dr.get("households", 0))
		var units := int(dr.get("units", 0))
		var sh := int(dr.get("shacks", 0))
		var excess := maxi(0, hh - units * OCC_CAP / 1000)
		if hh <= 0:
			dr["shacks"] = 0
			dr["homeless"] = 0
			continue
		var land := units * SHACK_LAND_PM / 1000 if units > 0 else hh  # an unbuilt district: open land
		var want := mini(excess, land)
		var before := sh
		if sh < want:
			if mat_ok:
				sh += maxi(S, (want - sh) * SHACK_RATE_PM / 1000) if want - sh >= S else want - sh
				sh = mini(sh, want)
		elif sh > excess:
			sh -= maxi(S, (sh - excess) * SHACK_DECAY_PM / 1000) if sh - excess >= S else sh - excess
			sh = maxi(sh, excess)
		# fire: crowded wooden shacks without water
		if sh >= 10 * S and rng.randi_range(0, 999) < mini(200, FIRE_PM_PER_100 * sh / (100 * S)):
			var loss := sh * rng.randi_range(FIRE_LOSS[0], FIRE_LOSS[1]) / 1000
			sh -= loss
			EconFacts.emit(world, "ECON_SHACK_FIRE", d, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 0.6], ["NATURE", "fire", 0.4]],
				{"HOUSING": -20, "SAFETY": -30, "PUBLIC_SERVICES": -10}, 50, "PUBLIC",
				{"district": d, "households": loss / S, "shacks_left": sh / S}, {"districts": [d]})
		var hl := maxi(0, excess - sh)
		if before < S and sh >= 10 * S:
			EconFacts.emit(world, "ECON_SHANTYTOWN", d, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 0.8], ["NATURE", "market", 0.2]],
				{"HOUSING": -30, "FAIRNESS": -15, "SAFETY": -10}, 45, "PUBLIC",
				{"district": d, "households": sh / S, "occupancy_pct": int(100 * hh / maxi(1, units))}, {"districts": [d]})
		var was_hl := int(dr.get("homeless", 0))
		if hl * 1000 >= HOMELESS_FACT_PM * hh and was_hl * 1000 < HOMELESS_FACT_PM * hh:
			EconFacts.emit(world, "ECON_HOMELESSNESS", d, [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 0.8], ["NATURE", "market", 0.2]],
				{"HOUSING": -40, "FAIRNESS": -25, "SAFETY": -15}, 55, "PUBLIC",
				{"district": d, "households": hl / S, "persons": int(float(hl) / S * EconData.HOUSEHOLD_SIZE), "no_materials": not mat_ok}, {"districts": [d]})
		dr["shacks"] = sh
		dr["homeless"] = hl


## For EconQuery / the office: per district shacks and homeless households.
static func summary(world: WorldState) -> Dictionary:
	var out := {}
	for d in EconUtil.sorted_keys(world.peek("district")):
		var sh := shacks(world, d)
		var hl := homeless(world, d)
		if sh > 0 or hl > 0:
			out[d] = {"shack_households": sh / S, "homeless_households": hl / S}
	return out
