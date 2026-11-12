extends RefCounted
## Transport law (planning/spec-transport-v1.md T5). Owner: Anni (law). Pure lever reads for Bob's T2–T4 and
## Terra's network; preload it (no class_name).
##
## Levers (NUMBER, AI governments draft them; defaults change nothing until read):
##   LAW_FARE_CAP            0–150 % of a public route's cost (100 default; below 100 the treasury pays the gap)
##   LAW_TRANSPORT_SAFETY    0 lax … 100 strict vehicle inspection (40 default)
##   LAW_TOUR_LICENSING      0 lax … 100 strict rover/airship operator licences (40 default)
##   LAW_ROAD_TOLL           0–20 milli-W_ref per vehicle trip on PAVED roads (0 default)
##   LAW_TRANSPORT_OPERATION 0 PUBLIC / 1 FRANCHISE / 2 OPEN (0 default)

const OPERATION := ["PUBLIC", "FRANCHISE", "OPEN"]
## Inspection: at 100 accidents fall to this share of the lax rate, running costs rise by this share.
const SAFETY_ACCIDENTS_STRICT := 0.35
const SAFETY_COST_STRICT := 0.15
## Tour licences: at 100 a new operator is licensed with this probability; licensed operators' accident rate.
const TOUR_APPROVAL_STRICT := 0.25
const TOUR_ACCIDENTS_STRICT := 0.4


static func _lv(world: WorldState, id: String, dflt: int, lo: int, hi: int) -> int:
	return clampi(int(world.levers.get(id, dflt)), lo, hi)


## Highest public fare as a share of the route's cost (0.0 = free, 1.0 = cost recovery, 1.5 = 50% margin).
static func fare_cap(world: WorldState) -> float:
	return float(_lv(world, "LAW_FARE_CAP", 100, 0, 150)) / 100.0


## The fare a capped public route charges and the treasury's top-up, both mcr: {fare, subsidy}.
static func capped_fare(world: WorldState, cost: int, wanted_fare: int) -> Dictionary:
	var cap := int(round(float(cost) * fare_cap(world)))
	var fare := mini(wanted_fare, cap)
	return {"fare": fare, "subsidy": maxi(0, cost - fare)}


static func safety_strictness(world: WorldState) -> float:
	return float(_lv(world, "LAW_TRANSPORT_SAFETY", 40, 0, 100)) / 100.0


## Multiplier on vehicle accident rates (all modes) and on operators' running costs.
static func accident_factor(world: WorldState) -> float:
	return lerpf(1.0, SAFETY_ACCIDENTS_STRICT, safety_strictness(world))


static func safety_cost_factor(world: WorldState) -> float:
	return 1.0 + SAFETY_COST_STRICT * safety_strictness(world)


static func tour_strictness(world: WorldState) -> float:
	return float(_lv(world, "LAW_TOUR_LICENSING", 40, 0, 100)) / 100.0


## Probability a new rover/airship tour operator gets its licence this month.
static func tour_approval_p(world: WorldState) -> float:
	return lerpf(1.0, TOUR_APPROVAL_STRICT, tour_strictness(world))


## Extra multiplier on tour accidents (on top of accident_factor).
static func tour_accident_factor(world: WorldState) -> float:
	return lerpf(1.0, TOUR_ACCIDENTS_STRICT, tour_strictness(world))


## Toll per vehicle trip on a PAVED link, mcr.
static func road_toll(world: WorldState) -> int:
	var wref := maxi(1, int(world.values.get("ECON_W_REF", 1200000)))
	return int(round(float(_lv(world, "LAW_ROAD_TOLL", 0, 0, 20)) * float(wref) / 1000.0))


## PUBLIC | FRANCHISE | OPEN.
static func operation(world: WorldState) -> String:
	return OPERATION[_lv(world, "LAW_TRANSPORT_OPERATION", 0, 0, 2)]


## Does the fare cap bind this operator? Always for the CTA and franchisees; not for open-market private operators.
static func fare_cap_binds(world: WorldState, public_operator: bool) -> bool:
	return public_operator or operation(world) != "OPEN"
