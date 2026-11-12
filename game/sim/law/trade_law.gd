extends RefCounted
## Trade, luxury, tourism and leisure law (planning/spec-demand-v1.md D5). Owner: Anni (law). Pure lever reads for
## Bob's D1–D4 economy; preload it (no class_name). Export terms (charter levy, reserved goods, refusal) come from
## CharterOps.export_terms(world, good).
##
## Levers (NUMBER, AI governments draft them):
##   LAW_EXPORT_TAX          0–50 % of export revenue (not on reserved goods: the charter forbids it)
##   LAW_LUXURY_TAX          0–50 % on LUXURY sales to households
##   LAW_TOURIST_TAX         0–30 % on tourists' spending (hotels, guides, leisure)
##   LAW_TOURIST_VISA        0 closed … 100 open (50 default)
##   LAW_IMMIGRATION         0 closed … 100 open (70 default): settlers let in (E120, Bob's arrivals)
##   LAW_LEISURE_LICENSING   0 lax … 100 strict (40 default): venue licences, opening hours, alcohol
##   LAW_CHARTER_EXPORT_LEVY 0–50 % of export revenue to the home world (charter level: home world only)

## Leisure: at 100 strictness a new private venue is licensed with this probability (1.0 at 0); venues that do open
## sell less (early closing, no alcohol) and the streets are calmer.
const VENUE_APPROVAL_STRICT := 0.3
const VENUE_SALES_STRICT := 0.7
const LEISURE_SAFETY_STRICT := 0.5


static func _lv(world: WorldState, id: String, dflt: int, lo: int, hi: int) -> int:
	return clampi(int(world.levers.get(id, dflt)), lo, hi)


static func export_tax_pct(world: WorldState) -> int:
	return _lv(world, "LAW_EXPORT_TAX", 0, 0, 50)


static func luxury_tax_pct(world: WorldState) -> int:
	return _lv(world, "LAW_LUXURY_TAX", 0, 0, 50)


static func tourist_tax_pct(world: WorldState) -> int:
	return _lv(world, "LAW_TOURIST_TAX", 0, 0, 30)


## Share of would-be visitors let in (0 = closed borders .. 1 = fully open); default 0.5.
static func visa_openness(world: WorldState) -> float:
	return float(_lv(world, "LAW_TOURIST_VISA", 50, 0, 100)) / 100.0


## Share of would-be settlers let in (0 = closed .. 1 = open); default 0.7. Bob: arrivals × this.
static func immigration_openness(world: WorldState) -> float:
	return float(_lv(world, "LAW_IMMIGRATION", 70, 0, 100)) / 100.0


static func leisure_strictness(world: WorldState) -> float:
	return float(_lv(world, "LAW_LEISURE_LICENSING", 40, 0, 100)) / 100.0


## Probability a new private venue (tavern, restaurant) gets its licence this month.
static func venue_approval_p(world: WorldState) -> float:
	return lerpf(1.0, VENUE_APPROVAL_STRICT, leisure_strictness(world))


## Multiplier on a private venue's sales (opening hours, alcohol rules).
static func venue_sales_factor(world: WorldState) -> float:
	return lerpf(1.0, VENUE_SALES_STRICT, leisure_strictness(world))


## Multiplier on venue-related disorder (fights, drunkenness) for the SAFETY side.
static func leisure_disorder_factor(world: WorldState) -> float:
	return lerpf(1.0, LEISURE_SAFETY_STRICT, leisure_strictness(world))
