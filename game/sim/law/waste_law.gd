extends RefCounted
## Waste, sewage and burial law (planning/spec-waste-v1.md W6). Owner: Anni (law). Pure lever reads for Bob's
## W1–W5 economy and Wilma's W7 politics; preload it (no class_name). Siting is Wilma's (with Terra's WasteMap).
##
## Levers (NUMBER, AI governments draft them):
##   LAW_WASTE_STANDARD     0 anything goes … 100 strict (30 default): inspection rate and dumping fines (justice_ops),
##                          disposal cost and pollution (Bob)
##   LAW_RECYCLING_TARGET   0–80 % of municipal waste recycled
##   LAW_LANDFILL_TAX       0–20 milli-W_ref per tonne landfilled
##   LAW_SEWAGE_STANDARD    0–100 % of sewage pollution removed before discharge (30 default)
##   LAW_BURIAL_RULES       −100 cremation required … 0 free choice … +100 burial only
##   LAW_SANITATION_FEE     0–100 % of household collection cost paid as a fee (0 = budget line)
##
## All factors are 1.0 at the defaults, so a colony that never touches these laws plays as before.

const STANDARD_DEFAULT := 30
## At standard 100 disposal costs COST_AT_STRICT × and pollutes POLLUTION_AT_STRICT × the default; at 0 it costs
## COST_AT_LAX × and pollutes POLLUTION_AT_LAX ×.
const COST_AT_STRICT := 1.6
const COST_AT_LAX := 0.8
const POLLUTION_AT_STRICT := 0.4
const POLLUTION_AT_LAX := 1.5
const SEWAGE_DEFAULT := 30


static func _lv(world: WorldState, id: String, dflt: int, lo: int, hi: int) -> int:
	return clampi(int(world.levers.get(id, dflt)), lo, hi)


static func waste_standard(world: WorldState) -> int:
	return _lv(world, "LAW_WASTE_STANDARD", STANDARD_DEFAULT, 0, 100)


## Environmental inspections scale with the standard: ×0.5 at 0, ×1 at the default, ≈ ×2.2 at 100.
static func inspection_factor(world: WorldState) -> float:
	return 0.5 + 0.5 * float(waste_standard(world)) / float(STANDARD_DEFAULT)


## Dumping (DISCHARGE_WASTE) fines scale the same way: the stricter the law, the dearer the conviction.
static func dumping_fine_factor(world: WorldState) -> float:
	return inspection_factor(world)


## Piecewise: 1.0 at the default standard, `at_lax` at 0, `at_strict` at 100.
static func _by_standard(s: int, at_lax: float, at_strict: float) -> float:
	if s >= STANDARD_DEFAULT:
		return 1.0 + (at_strict - 1.0) * float(s - STANDARD_DEFAULT) / float(100 - STANDARD_DEFAULT)
	return 1.0 + (at_lax - 1.0) * float(STANDARD_DEFAULT - s) / float(STANDARD_DEFAULT)


## Bob: legal disposal cost per tonne × this.
static func disposal_cost_factor(world: WorldState) -> float:
	return _by_standard(waste_standard(world), COST_AT_LAX, COST_AT_STRICT)


## Bob: pollution (ground, river leachate, incinerator air) per tonne disposed × this.
static func disposal_pollution_factor(world: WorldState) -> float:
	return _by_standard(waste_standard(world), POLLUTION_AT_LAX, POLLUTION_AT_STRICT)


## Share of municipal waste (‰) that must go to recycling works (while they have capacity).
static func recycling_target_pm(world: WorldState) -> int:
	return _lv(world, "LAW_RECYCLING_TARGET", 0, 0, 80) * 10


## Landfill tax in mcr per tonne (milli-W_ref × W_ref / 1000). Bob: tax × tonnes to the treasury.
static func landfill_tax_per_tonne(world: WorldState) -> int:
	var wref := maxi(1, int(world.values.get("ECON_W_REF", 1200000)))
	return _lv(world, "LAW_LANDFILL_TAX", 0, 0, 20) * wref / 1000


## Share (‰) of sewage pollution a treatment plant must remove. A private operator discharging below it is
## dumping (Bob: LawOps.record_greed kind DUMPING); treatment cost × sewage_cost_factor.
static func sewage_removal_pm(world: WorldState) -> int:
	return _lv(world, "LAW_SEWAGE_STANDARD", SEWAGE_DEFAULT, 0, 100) * 10


static func sewage_cost_factor(world: WorldState) -> float:
	return 1.0 + 0.8 * float(_lv(world, "LAW_SEWAGE_STANDARD", SEWAGE_DEFAULT, 0, 100) - SEWAGE_DEFAULT) / 100.0


## Burial law -> {cremation_min_pm, burial_min_pm, strictness 0..100}. Wilma: strictness offends the other side.
static func burial(world: WorldState) -> Dictionary:
	var v := _lv(world, "LAW_BURIAL_RULES", 0, -100, 100)
	return {"cremation_min_pm": maxi(0, -v) * 10, "burial_min_pm": maxi(0, v) * 10, "strictness": absi(v)}


## Bob: cremated share (‰) of deaths, given the families' wish (‰), with the law's floor and ceiling applied.
static func cremation_share_pm(world: WorldState, wished_pm: int) -> int:
	var b := burial(world)
	return clampi(maxi(wished_pm, int(b["cremation_min_pm"])), 0, 1000 - int(b["burial_min_pm"]))


## Share (‰) of household collection cost charged to households as a fee; the rest is the budget line.
static func sanitation_fee_pm(world: WorldState) -> int:
	return _lv(world, "LAW_SANITATION_FEE", 0, 0, 100) * 10
