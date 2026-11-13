extends RefCounted
## Workload and stress law (user ruling: lean staffing pays, stress costs). Owner: Anni (law). Pure lever reads;
## preload it (no class_name). Step 1: levers and readers only. Nothing reads them until Bob's support-economy pass
## reports workload per facility; then OVERWORK / UNDERSTAFFING become M11 conduct kinds (channel WORK).
##
## Levers (NUMBER, legislative):
##   LAW_MAX_WORKING_HOURS        40–70 h/week (60 default: a frontier colony); above it = overwork
##   LAW_STAFFING_RATIOS          0 none / 1 guidance (public, lawful) / 2 binding (understaffing unlawful)
##   LAW_WORK_INSPECTORATE_BUDGET 0–20000 milli-W_ref/month (3000 default): the work-environment authority

## Clients per worker at the legal ratio, by service tag (Bob's facility tag).
const RATIOS := {"HEALTH": 300, "CARE": 10, "CHILDCARE": 8}
const RATIO_MODES := ["NONE", "GUIDANCE", "BINDING"]
const WORK_INSPECTION_COST := 1500      # milli-W_ref per workplace inspection (as the environmental inspectorate)
const STRESS_ACCIDENT_FROM := 1300      # workload ‰ at or above which an accident is a stress accident (TORT)


static func max_hours(world: WorldState) -> int:
	return clampi(int(world.levers.get("LAW_MAX_WORKING_HOURS", 60)), 40, 70)


## Weekly hours over the legal maximum (0 if within it).
static func overtime(world: WorldState, hours_per_week: int) -> int:
	return maxi(0, hours_per_week - max_hours(world))


static func ratio_mode(world: WorldState) -> String:
	return RATIO_MODES[clampi(int(world.levers.get("LAW_STAFFING_RATIOS", 0)), 0, 2)]


## Workers a service needs for `clients` at the legal ratio (0 for untagged services or no ratio law).
static func required_staff(world: WorldState, service: String, clients: int) -> int:
	if ratio_mode(world) == "NONE" or not RATIOS.has(service) or clients <= 0:
		return 0
	return int(ceil(float(clients) / float(RATIOS[service])))


## {mode, required, short, unlawful}: how a facility stands against the ratio law.
static func staffing_check(world: WorldState, service: String, clients: int, staff: int) -> Dictionary:
	var need := required_staff(world, service, clients)
	var short := maxi(0, need - staff)
	var mode := ratio_mode(world)
	return {"mode": mode, "required": need, "short": short, "unlawful": mode == "BINDING" and short > 0}


## Workplace inspections a month the work-environment authority can make.
static func inspections(world: WorldState) -> float:
	return float(clampi(int(world.levers.get("LAW_WORK_INSPECTORATE_BUDGET", 3000)), 0, 20000)) / float(WORK_INSPECTION_COST)


static func stress_accident(workload_pm: int) -> bool:
	return workload_pm >= STRESS_ACCIDENT_FROM
