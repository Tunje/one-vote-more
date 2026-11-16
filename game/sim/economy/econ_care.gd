class_name EconCare
extends RefCounted
## Support economy part E, step 4 (planning/plan-support-economy.md §2 E; Wilma: "public services with real staffing
## ratios, workload/stress tags, budget lines with symmetric hints, and childcare raising labour supply"):
##   ELDER CARE (org "ELDC", ELDERCARE sites) for the retired: NORMAL 9 clients per worker at full coverage.
##   CHILDCARE (org "CHC", CHILDCARE sites) for children aged 1–5: NORMAL 5.5 per worker.
##   Each is a public institution on the PES pattern with its own budget line (ECON_BUDGET_ELDER_CARE /
##   ECON_BUDGET_CHILDCARE): the line buys posts (4 G + 1 S each), shared over the districts by need, never above full
##   cover. Wages are topped up monthly from the treasury and booked to the line.
##   ENROLMENT lags the posts: places open over ~3 months and close over ~6 (a cut leaves the clients with fewer staff
##   first — workload, stress, Anni's ratio checks — before the waiting lists grow).
##   COVERAGE (‰ per district) = the clients actually cared for (enrolled, but at most 1.3 × what the staff present can
##   handle) ÷ clients, × the WORKLOAD quality factor.
##   EFFECTS (symmetric around the default coverage, so a colony at the default is unchanged from today):
##     elder care — mortality of the retired × (1 + ELDER_MORT × (ELDER_DEF − coverage));
##     childcare — parents' re-entry into the labour force × (1 + CHILD_REENTRY × (coverage − CHILD_DEF)).
##   INDICATORS ECON_ELDER_CARE_ACCESS / ECON_CHILDCARE_ACCESS (%, district; exception-only).
## OPT-IN until its A/B (world.meta["on"] has "CARE").

const EconInst := preload("res://sim/economy/econ_institutions.gd")
const S := EconUtil.S
const POSTS_PER_UNIT := 5
const SERVICES := {
	"ELDER": {"key": "ELDC", "name": "Elder Care Service", "type": "ELDERCARE", "line": "ECON_BUDGET_ELDER_CARE", "normal": 9.0},
	"CHILD": {"key": "CHC", "name": "Childcare Service", "type": "CHILDCARE", "line": "ECON_BUDGET_CHILDCARE", "normal": 5.5},
}
const ELDER_DEF := 600
const CHILD_DEF := 500
const ELDER_MORT := 0.4
const CHILD_REENTRY := 1.0
const OPEN_M := 3
const CLOSE_M := 6
const STRETCH := 1.3


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("CARE") and not EconUtil.off(world, "CARE")


static func org(world: WorldState, svc: String) -> String:
	return EconFinance.org_by_key(world, SERVICES[svc]["key"])


static func _found(world: WorldState, svc: String) -> String:
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": SERVICES[svc]["key"], "name": SERVICES[svc]["name"], "type": "PUBLIC_INSTITUTION",
		"hq": "d:1", "status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 10, "age_m": 45 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	return oid


static func _site(world: WorldState, oid: String, ftype: String, d: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == ftype and f["district"] == d:
			return f
	var nid := EconSetup.add_facility(world, ftype, oid, d, false)
	var g: Dictionary = world.table("facility")[nid]
	g["scale"] = 0
	g["book"] = 0
	g["enrolled"] = 0
	return g


## Clients per district (persons): the retired, or children aged 1–5.
static func clients(world: WorldState, svc: String) -> Dictionary:
	var out := {}
	if svc == "ELDER":
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var g: Dictionary = world.table("hh")[gid]
			out[g["district"]] = int(out.get(g["district"], 0)) + int(g["retired"]) / S
		return out
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		var h := EconCohorts.histogram(world, d)
		if h.is_empty():
			continue
		var n := 0
		for a in range(1, 6):
			n += int(h[a])
		out[d] = n
	return out


static func _post_cost(world: WorldState, oid: String, ftype: String) -> int:
	var r: Dictionary = EconData.RECIPES[ftype]
	var c := 0
	for t in r["labor"]:
		c += int(r["labor"][t]) * EconFinance.wage_for(world, oid, t)
	return c / POSTS_PER_UNIT


## COMPANY_AI, before FirmAI.run: size each service's posts from its line, enrol, fund next month's wages.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var cov_all: Dictionary = s.get("care_cov", {})
	s["care_cov"] = cov_all
	for svc in ["ELDER", "CHILD"]:
		var sd: Dictionary = SERVICES[svc]
		var oid := org(world, svc)
		if oid == "":
			oid = _found(world, svc)
		var normal: float = sd["normal"]
		var cl := clients(world, svc)
		var ds := EconUtil.sorted_keys(cl)
		var need: Array = []
		var need_total := 0
		for d in ds:
			var n := int(ceil(float(int(cl[d])) / normal))
			need.append(float(n))
			need_total += n
		var cost := maxi(1, _post_cost(world, oid, sd["type"]))
		var budget_posts := (int(EconUtil.lever(world, sd["line"], 0)) * 1000 * S / 12 + EconInst.earmarked(world, svc)) / cost   # + its bracket (R8_INSTITUTIONS)
		# whole units of POSTS_PER_UNIT per district (a site keeps 70% of a unit's crew however small it is — E49 labour
		# hoarding — so part-units would overstaff); a district below one unit has no site of its own this month
		var units := mini(budget_posts, need_total + POSTS_PER_UNIT - 1) / POSTS_PER_UNIT
		var split: Array = EconUtil.split_lr(units, need) if need_total > 0 else []
		var cov: Dictionary = {}
		var bill := 0
		for i in ds.size():
			var d: String = ds[i]
			var f := _site(world, oid, sd["type"], d)
			var p := (int(split[i]) if i < split.size() else 0) * POSTS_PER_UNIT
			f["scale"] = p * 1000 / POSTS_PER_UNIT
			f["T"] = 1000
			f["mothball"] = p <= 0
			var c := int(cl[d])
			f["clients"] = c
			# enrolment follows the places: opens over OPEN_M months, closes over CLOSE_M
			var target := mini(c, int(float(p) * normal))
			var e := int(f.get("enrolled", 0))
			if target > e:
				e += maxi(1, (target - e) / OPEN_M)
			elif target < e:
				e -= maxi(1, (e - target) / CLOSE_M)
			e = clampi(e, 0, c)
			f["enrolled"] = e
			var present := float(EconLabor.staff_total(f["staff"])) / float(S)
			var cared := mini(e, int(present * normal * STRETCH))
			var q := EconWorkload.quality_mult(f) if EconWorkload.active(world) else 1.0
			cov[d] = 1000 if c <= 0 else clampi(int(1000.0 * float(cared) / float(c) * q), 0, 1000)
			var req := EconLabor.required(f)
			for t in req:
				bill += int(req[t]) / S * EconFinance.wage_for(world, oid, t)
		cov = EconInst.care_private(world, svc, cl, cov)   # R8_INSTITUTIONS (Maja): private care homes' clients count too
		cov_all[svc] = cov
		# fund next month's wage bill from the line
		var due := bill - world.ledger.balance(EconUtil.acct(oid))
		if due > 0:
			var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), due, "CARE_BUDGET")
			EconFinance._spend_line(world, sd["line"], paid)
			EconFinance.pl_add(world, oid, "subsidy", paid)


## Coverage ‰ of a service in a district (the default when off or unknown).
static func coverage(world: WorldState, svc: String, d: String) -> int:
	var def := ELDER_DEF if svc == "ELDER" else CHILD_DEF
	if not active(world):
		return def
	return int(EconUtil.peek_st(world).get("care_cov", {}).get(svc, {}).get(d, def))


## Mortality multiplier for the retired in a district (1.0 when off or at the default coverage).
static func elder_mort_mult(world: WorldState, d: String) -> float:
	if not active(world):
		return 1.0
	return maxf(0.5, 1.0 + ELDER_MORT * float(ELDER_DEF - coverage(world, "ELDER", d)) / 1000.0)


## Re-entry multiplier for non-participating adults in a district (1.0 when off or at the default coverage).
static func reentry_mult(world: WorldState, d: String) -> float:
	if not active(world):
		return 1.0
	return maxf(0.0, 1.0 + CHILD_REENTRY * float(coverage(world, "CHILD", d) - CHILD_DEF) / 1000.0)


## Clients a care site serves (for workload and Anni's ratio checks): the enrolled.
static func site_clients(f: Dictionary) -> int:
	return int(f.get("enrolled", 0))


static func normal_for(ftype: String) -> float:
	for svc in SERVICES:
		if SERVICES[svc]["type"] == ftype:
			return float(SERVICES[svc]["normal"])
	return 1.0


## {ELDER/CHILD: {posts, staff, clients, enrolled, coverage ‰ (colony)}} for probes and the panel.
static func summary(world: WorldState) -> Dictionary:
	var out := {}
	for svc in ["ELDER", "CHILD"]:
		var oid := org(world, svc)
		var r := {"posts": 0, "staff": 0, "clients": 0, "enrolled": 0, "coverage": 0}
		var covered := 0
		for fid in EconUtil.sorted_keys(world.peek("facility")):
			var f: Dictionary = world.peek("facility")[fid]
			if f["org"] != oid or oid == "":
				continue
			r["posts"] += int(f["scale"]) * POSTS_PER_UNIT / 1000
			r["staff"] += EconLabor.staff_total(f["staff"]) / S
			r["clients"] += int(f.get("clients", 0))
			r["enrolled"] += int(f.get("enrolled", 0))
			covered += coverage(world, svc, f["district"]) * int(f.get("clients", 0))
		r["coverage"] = covered / maxi(1, int(r["clients"]))
		out[svc] = r
	return out
