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


## Step 2 (Wilma's union side): a staffing strike in `sector` (an occupation, as EconQuery.workload and the unions use) is
## lawful when ratios are BINDING and a workplace in that sector is short of them: an active UNDERSTAFFING record
## (Bob reports one every month a private clinic is short; the union knows its own rota, revealed or not), or, for
## PUBLIC_SECTOR, a public workplace short of them (report_public_staffing).
static func strike_lawful_staffing(world: WorldState, sector: String) -> bool:
	if ratio_mode(world) != "BINDING":
		return false
	if sector == "PUBLIC_SECTOR" and not public_shortfalls(world).is_empty():
		return true
	var fac := world.peek("facility")
	var orgs := world.peek("org")
	var vt := world.peek("violation_track")
	for vid in vt:
		var v: Dictionary = vt[vid]
		if String(v.get("kind", "")) != "UNDERSTAFFING" or not bool(v.get("active", false)) or not bool(v.get("unlawful", false)):
			continue
		var f: Dictionary = fac.get(String(v.get("facility", "")), {})
		var org := String(f.get("org", ""))
		if f.is_empty() or not orgs.has(org):
			continue
		if EconLabor.occupation_of(world, org, String(f["type"])) == sector:
			return true
	return false



# =====================================================================================  public workplaces

## Bob calls this every month for each PUBLIC workplace with a ratio service (HEALTH, CARE, CHILDCARE). Returns
## staffing_check + {fact}. Under BINDING ratios a shortfall is the government breaking its own law: one SECRET
## LAW_UNLAWFUL_GOV_ACTION (action UNDERSTAFF_SERVICE, responsible GOVERNMENT = the Cabinet) per continuous shortfall,
## found through the usual leaks and complaints by the district's patients (VICTIMS), then an UNLAWFUL_GOV case. The
## episode ends when the workplace is no longer short, the law stops binding, or Bob stops reporting it.
static func report_public_staffing(world: WorldState, facility: String, district: String, service: String, clients: int,
		staff: int) -> Dictionary:
	var chk := staffing_check(world, service, clients, staff)
	var ps := _public_state(world)
	var row: Dictionary = ps.get(facility, {})
	var open := not row.is_empty() and int(row["last"]) >= world.month - 1
	if not bool(chk["unlawful"]):
		ps.erase(facility)
		chk["fact"] = ""
		return chk
	if not open:
		var LawOps = load("res://sim/law/law_ops.gd")
		var res: Dictionary = LawOps.proceed_unlawfully(world, {"kind": "GOVERNMENT", "id": "government"}, "UNDERSTAFF_SERVICE",
			{"facility": facility, "district": district, "service": service, "required": int(chk["required"]),
			"staff": staff, "short": int(chk["short"])}, "",
			{"kind": "VICTIMS", "id": "patients:" + district, "scope": {"districts": [district]}}, "SERIOUS")
		if not bool(res.get("ok", false)):
			chk["fact"] = ""
			return chk
		row = {"fact": String(res["fact"]), "since": world.month, "district": district, "service": service, "max_short": 0}
		ps[facility] = row
	row["last"] = world.month
	row["short"] = int(chk["short"])
	row["max_short"] = maxi(int(row["max_short"]), int(chk["short"]))
	chk["fact"] = String(row["fact"])
	return chk


## Open public shortfalls this month or last: {facility: {fact, since, last, district, service, short, max_short}}.
static func public_shortfalls(world: WorldState) -> Dictionary:
	var out := {}
	var ps: Dictionary = world.peek("law_state").get("s", {}).get("public_staffing", {})
	for fid in ps:
		if int(ps[fid].get("last", -99)) >= world.month - 1:
			out[fid] = ps[fid]
	return out


static func _public_state(world: WorldState) -> Dictionary:
	var s: Dictionary = load("res://sim/law/law_ops.gd").state(world)
	if not s.has("public_staffing"):
		s["public_staffing"] = {}
	return s["public_staffing"]
