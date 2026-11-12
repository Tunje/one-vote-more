class_name EconUnions
extends RefCounted
## Interest groups, economy side (planning/spec-politics-v2.md §5, M9).
##   - union density per occupation (indicator ECON_UNION_DENSITY, SOCIAL)
##   - industrial action: ECON_STRIKE / ECON_LOCKOUT / ECON_LAYOFFS_MASS facts (COMPANY_AI)
##   - company donation offers: table "donation_offer" (SETTLEMENT); politics matches and books them.
## State lives in econ.s["union"]. Stoppages live on facilities as f["stop_until"] / f["stop_kind"] and cut
## labor productivity in EconProduction._plan. A won strike adds o["union_pm"] (wage premium ‰, decays).

const S := EconUtil.S

## Unionised occupations and their base density (% of employed) at union rights 50.
const BASE_DENSITY := {"MANUFACTURING": 34.0, "CONSTRUCTION": 30.0, "LOGISTICS": 30.0, "MINING": 45.0, "AGRICULTURE": 14.0,
	"SERVICES": 12.0, "PROFESSIONAL": 10.0, "PUBLIC_SECTOR": 48.0}
const DENSITY_ADJUST := 1.0 / 12.0       # monthly move toward the target density
const STRIKE_RATE := 0.035               # P(strike) per org-month = density × grievance × this
const MAX_NEW_STOPPAGES := 2             # per month, colony-wide
const STRIKE_WORK := 0.5                 # labor effectiveness while on strike (partial strike / work-to-rule)
const LOCKOUT_WORK := 0.2                # labor effectiveness during a lockout (skeleton crews)
const STRIKE_WIN_PM := 40                # wage premium won by a strike (‰), decays
const ESSENTIAL_TYPES := ["POWER", "WATERWORKS", "CLINIC"]  # LAW_ESSENTIAL_SERVICES applies to these
const MIN_SERVICE_SHARE := 0.6           # MIN_SERVICE: a struck essential service keeps 60% of its labour
const ARBITRATION_PM := 20               # NO_STRIKE: binding arbitration awards half a strike's gain
const UNION_PM_MAX := 120
const UNION_PM_DECAY := 4                # ‰ per month
const MASS_LAYOFF_MIN := 15              # persons laid off in one month by one org …
const MASS_LAYOFF_SHARE := 0.20          # … and at least this share of its workforce (max one fact per org per 6 months)
## Labor levers watched for "labor law moves against workers": id -> occupation scope ("" = all).
const LABOR_LEVERS := {"ECON_UNION_RIGHTS": "", "ECON_MIN_WAGE": "", "LAW_SAFETY_STANDARD": "",
	"ECON_UNEMPLOYMENT_BENEFIT_RATE": "", "ECON_PUBLIC_PAY_INDEX": "PUBLIC_SECTOR"}
const SAFETY_ORDER := ["BASIC", "STANDARD", "STRICT"]
const CLOSED_SHOP_LAW := preload("res://sim/law/union_law.gd")
const CLOSED_SHOP_MULT := 1.2
const CLOSED_SHOP_M := 48
## Donations (SETTLEMENT).
const DONATION_SHARE := 0.06             # of last month's profit, times exposure (0..1.5)
const DONATION_MIN := 2000 * S           # mcr; smaller offers are not made
const DONATION_CASH_COVER := 4           # keep at least this many months of costs in cash


static func _u(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if not s.has("union"):
		s["union"] = {"density": {}, "levers": {}, "law_hits": [], "last_strike": {}, "last_layoff": {}}
		for occ in BASE_DENSITY:
			s["union"]["density"][occ] = int(BASE_DENSITY[occ] * 1000.0)
	return s["union"]


# ------------------------------------------------------------------ density (SOCIAL)

## Employed persons (mu) per occupation, from the recount on each group.
static func employed_by_occ(world: WorldState) -> Dictionary:
	var out := {}
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var e: Dictionary = world.table("hh")[gid].get("emp", {})
		for occ in e:
			out[occ] = out.get(occ, 0) + e[occ]
	return out


## Target density (‰ of 100%, i.e. 0..100000) for an occupation.
static func target_density(world: WorldState, occ: String, emp: Dictionary, total: int) -> int:
	var rights := float(EconUtil.lever(world, "ECON_UNION_RIGHTS", 50)) / 100.0
	var law := 0.4 + 1.2 * rights                                    # 0.4 .. 1.6, 1.0 at 50
	var safety: String = str(EconUtil.lever(world, "LAW_SAFETY_STANDARD", "BASIC"))
	law *= 1.0 + 0.04 * float(SAFETY_ORDER.find(safety))             # inspected workplaces organise a little more
	var share := float(emp.get(occ, 0)) / maxf(1.0, float(total))
	var size := clampf(0.6 + 0.4 * sqrt(share / 0.15), 0.6, 1.4)     # big sectors organise more easily
	var grievance := 1.0 + 0.15 * minf(2.0, wage_grievance(world, occ) + law_grievance(world, occ))
	var u := _unemp(world)
	var fear := clampf(1.0 - 0.8 * maxf(0.0, u - 0.10), 0.6, 1.0)  # high unemployment weakens organising
	# U4 closed shop (Anni's LAW_CLOSED_SHOP): where the sector's union holds an agreement (a settlement in the last
	# CLOSED_SHOP_M months) membership becomes a condition of the job
	if not EconUtil.off(world, "UNIONS_U2") and CLOSED_SHOP_LAW.closed_shop(world):
		var su := Unions.of_occ(world, occ)
		if not su.is_empty() and world.month - int(su.get("relief_m", -9999)) < CLOSED_SHOP_M:
			law *= CLOSED_SHOP_MULT
	return int(clampf(BASE_DENSITY[occ] * law * size * grievance * fear, 0.0, 95.0) * 1000.0)


static func publish_density(world: WorldState) -> void:
	var un := _u(world)
	var emp := employed_by_occ(world)
	var total := 0
	for occ in BASE_DENSITY:
		total += emp.get(occ, 0)
	for occ in EconUtil.sorted_keys(BASE_DENSITY):
		var cur: int = un["density"].get(occ, int(BASE_DENSITY[occ] * 1000.0))
		var tgt := target_density(world, occ, emp, total)
		cur += int(round(float(tgt - cur) * DENSITY_ADJUST))
		un["density"][occ] = clampi(cur, 0, 100000)
		world.set_indicator("econ", "ECON_UNION_DENSITY", occ, un["density"][occ])


static func density(world: WorldState, occ: String) -> int:
	return int(EconUtil.peek_st(world).get("union", {}).get("density", {}).get(occ, 0))


# ------------------------------------------------------------------ grievances

static func _unemp(world: WorldState) -> float:
	var lf := 0
	var emp := 0
	for gid in world.table("hh"):
		var g: Dictionary = world.table("hh")[gid]
		lf += g["lf"]
		emp += EconLabor.employed(g)
	return 0.0 if lf <= 0 else float(lf - emp) / float(lf)


## 12-month real wage growth (%) of the General tier (the bulk of union members); 0 before a year of history.
static func real_wage_growth(world: WorldState) -> float:
	var s := EconUtil.peek_st(world)
	var wh: Array = s.get("wage_hist", [])
	var ch: Array = s.get("cpi_hist", [])
	if wh.size() < 13 or ch.size() < 13:
		return 0.0
	var wr := (float(wh[-1]["G"]) + float(wh[-1]["S"])) / maxf(1.0, float(wh[0]["G"]) + float(wh[0]["S"]))
	return 100.0 * (wr / (float(ch[-1]) / maxf(1.0, float(ch[0]))) - 1.0)


## 0..2: real wages falling more than 2% a year (public sector: also pay index cuts are counted as law hits).
static func wage_grievance(world: WorldState, _occ: String) -> float:
	return clampf((-real_wage_growth(world) - 2.0) / 5.0, 0.0, 2.0)


## 0..2: adverse labor-law changes in the last 12 months, fading linearly.
static func law_grievance(world: WorldState, occ: String) -> float:
	var un: Dictionary = EconUtil.peek_st(world).get("union", {})
	var g := 0.0
	for h in un.get("law_hits", []):
		if h["scope"] != "" and h["scope"] != occ:
			continue
		var age := world.month - int(h["m"])
		if age < 12:
			g += float(h["size_pm"]) / 1000.0 * (1.0 - float(age) / 12.0)
	return clampf(g, 0.0, 2.0)


## Detect enacted labor-lever changes that move against workers (any change of an effective lever value).
static func _track_levers(world: WorldState) -> void:
	var un := _u(world)
	var prev: Dictionary = un["levers"]
	for id in EconUtil.sorted_keys(LABOR_LEVERS):
		if not world.lever_defs.has(id):
			continue
		var v = world.levers.get(id, world.lever_defs[id]["default"])
		if prev.has(id) and prev[id] != v:
			var size := _adverse_size(world, id, prev[id], v)
			if size > 0.0:
				un["law_hits"].append({"m": world.month, "lever": id, "scope": LABOR_LEVERS[id], "size_pm": int(round(size * 1000.0)),
					"from": prev[id], "to": v})
		prev[id] = v
	var keep: Array = []
	for h in un["law_hits"]:
		if world.month - int(h["m"]) < 12:
			keep.append(h)
	un["law_hits"] = keep


## 0 if the change is neutral or pro-worker; otherwise the size of the cut (0.5 .. 2).
static func _adverse_size(world: WorldState, id: String, from_v, to_v) -> float:
	if id == "LAW_SAFETY_STANDARD":
		var d := SAFETY_ORDER.find(str(from_v)) - SAFETY_ORDER.find(str(to_v))
		return 0.0 if d <= 0 else 0.75 * float(d)
	var r: Array = world.lever_defs[id].get("range", [0, 100])
	var cut := float(from_v) - float(to_v)
	if cut <= 0.0:
		return 0.0
	return clampf(0.5 + 6.0 * cut / maxf(1.0, float(r[1] - r[0])), 0.5, 2.0)


# ------------------------------------------------------------------ industrial action (COMPANY_AI)

## Workforce (mu) of an org by occupation, and its facilities.
static func _org_workforce(world: WorldState, oid: String) -> Dictionary:
	var occ_n := {}
	var facs: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid:
			continue
		facs.append(fid)
		var occ := EconLabor.occupation_of(world, oid, f["type"])
		occ_n[occ] = occ_n.get(occ, 0) + EconLabor.staff_total(f["staff"])
	var o: Dictionary = world.table("org")[oid]
	if o["is_contractor"]:
		var occ := EconLabor.occupation_of(world, oid, "CREW")
		occ_n[occ] = occ_n.get(occ, 0) + EconLabor.staff_total(o["crew"])
	return {"occ": occ_n, "facs": facs}


## Main COMPANY_AI step (after FirmAI.run, so this month's layoffs are known).
static func industrial_action(world: WorldState) -> void:
	_track_levers(world)
	var un := _u(world)
	var s := EconUtil.st(world)
	var rng := world.rng.stream("econ.unions")
	var layoffs: Dictionary = s.get("layoffs_m", {})
	var laid := {}
	for k in EconUtil.sorted_keys(layoffs):
		var oid: String = k.split("|")[0]
		laid[oid] = laid.get(oid, 0) + int(layoffs[k])
	var started := 0
	var u2 := not EconUtil.off(world, "UNIONS_U2") and not EconUtil.off(world, "UNIONS_U1")
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		o["union_pm"] = maxi(0, int(o.get("union_pm", 0)) - UNION_PM_DECAY)
		var wf := _org_workforce(world, oid)
		var occ_n: Dictionary = wf["occ"]
		var staff := 0
		for occ in occ_n:
			staff += occ_n[occ]
		# ---- mass layoffs ----
		var cut: int = laid.get(oid, 0)
		if cut >= MASS_LAYOFF_MIN * S and float(cut) >= MASS_LAYOFF_SHARE * float(staff + cut) and world.month - int(un["last_layoff"].get(oid, -99)) >= 6:
			un["last_layoff"][oid] = world.month
			var closing: bool = o["status"] in ["LIQUIDATION", "DISSOLVED"]
			EconFacts.emit(world, "ECON_LAYOFFS_MASS", o["hq"], [["COMPANY", oid]], EconFacts.company_blame(world, oid, 0.7),
				{"JOBS": -int(clampf(float(cut) / S * 4.0, 40.0, 300.0)), "FAIRNESS": -20}, clampi(25 + cut / S / 2, 30, 80), "PUBLIC",
				{"org": oid, "persons": cut / S, "share_pct": int(100.0 * float(cut) / float(staff + cut)), "closing": closing})
		if o["status"] != "ACTIVE" or staff < 5 * S or started >= MAX_NEW_STOPPAGES:
			continue
		if _stopped(world, wf["facs"]):
			continue
		if world.month - int(un["last_strike"].get(oid, -99)) < 12:
			continue  # a workforce does not strike twice within a year
		if u2:
			continue  # U2 (A41): strikes follow from failed talks (UnionDisputes), not a random roll
		# ---- strike decision: the org's dominant occupation sets density and grievances ----
		var occ := _dominant(occ_n)
		if not BASE_DENSITY.has(occ):
			continue
		var dens := float(un["density"].get(occ, 0)) / 100000.0
		var g_wage := wage_grievance(world, occ)
		var g_law := law_grievance(world, occ)
		var g_lay := 1.0 if cut >= 3 * S and float(cut) >= 0.10 * float(staff + cut) and o["status"] == "ACTIVE" else 0.0
		var g := g_wage + g_law + g_lay
		if g <= 0.0:
			continue
		var p := dens * g * STRIKE_RATE
		if rng.randf() >= p:
			continue
		started += 1
		un["last_strike"][oid] = world.month
		var cause := "REAL_WAGES"
		if g_law >= g_wage and g_law >= g_lay:
			cause = "LABOR_LAW"
		elif g_lay >= g_wage:
			cause = "LAYOFFS"
		_strike(world, oid, wf, occ, staff, cause, rng)
	UnionDisputes.monthly(world)  # U2: demands, talks, strikes (replaces the random roll above)


static func _dominant(occ_n: Dictionary) -> String:
	var best := ""
	for occ in EconUtil.sorted_keys(occ_n):
		if best == "" or occ_n[occ] > occ_n[best]:
			best = occ
	return best


static func _stopped(world: WorldState, facs: Array) -> bool:
	for fid in facs:
		if int(world.table("facility")[fid].get("stop_until", -1)) >= world.month:
			return true
	return false


static func _strike(world: WorldState, oid: String, wf: Dictionary, occ: String, staff: int, cause: String, rng: RandomNumberGenerator) -> void:
	var o: Dictionary = world.table("org")[oid]
	var public: bool = o["type"] in EconData.PUBLIC_TYPES
	# who is blamed: government for real-wage erosion and anti-worker law (spec §5), the employer for layoffs
	var resp: Array
	match cause:
		"LABOR_LAW": resp = [["GOVERNMENT", "government", 1.0]]
		"REAL_WAGES": resp = [["GOVERNMENT", "government", 1.0]] if public else [["GOVERNMENT", "government", 0.7], ["COMPANY", oid, 0.3]]
		_: resp = EconFacts.company_blame(world, oid, 0.8)
	# a hard-line private employer answers with a lockout instead of bargaining
	var lockout := false
	if o["type"] == "PRIVATE":
		var rights := float(EconUtil.lever(world, "ECON_UNION_RIGHTS", 50))
		lockout = rng.randf() < float(o["ceo"]["risk"]) / 100.0 * (0.25 + 0.5 * (1.0 - rights / 100.0))
	var months := 1 + (1 if rng.randf() < 0.4 else 0)
	var persons := staff / S
	var mag := clampi(30 + persons / 3, 30, 75)
	var services := false
	# LAW_ESSENTIAL_SERVICES (Anni's law, Bob's hook): power, water and clinics keep a minimum service, or may not
	# stop at all (binding arbitration: a smaller rise, no outage)
	var ess_law := str(world.levers.get("LAW_ESSENTIAL_SERVICES", "NONE"))
	var stopped := 0
	var arbitrated := 0
	for fid in wf["facs"]:
		var f: Dictionary = world.table("facility")[fid]
		var essential: bool = f["type"] in ESSENTIAL_TYPES
		if essential and ess_law == "NO_STRIKE" and not lockout:
			arbitrated += 1
			continue
		f["stop_until"] = world.month + months
		f["stop_kind"] = "LOCKOUT" if lockout else "STRIKE"
		f["stop_min"] = essential and ess_law == "MIN_SERVICE" and not lockout
		stopped += 1
		if f["type"] in ["CLINIC", "SCHOOL", "DEPOT", "POWER", "WATERWORKS"] and not f["stop_min"]:
			services = true
	if stopped == 0 and arbitrated > 0:
		# every struck workplace is an essential service under NO_STRIKE: the dispute goes to arbitration
		o["union_pm"] = mini(UNION_PM_MAX, int(o.get("union_pm", 0)) + ARBITRATION_PM)
		EconFacts.emit(world, "ECON_ARBITRATION", o["hq"], [["COMPANY", oid], ["OCCUPATION", occ]], resp,
			{"FAIRNESS": -5, "INFRASTRUCTURE": 5}, clampi(20 + persons / 5, 20, 50), "PUBLIC",
			{"org": oid, "occupation": occ, "persons": persons, "cause": cause, "award_pm": ARBITRATION_PM})
		return
	var impact := {"JOBS": -40, "FAIRNESS": -15, "COST_OF_LIVING": -20}
	if services:
		impact["PUBLIC_SERVICES"] = -60
		mag = mini(85, mag + 10)
	var data := {"org": oid, "occupation": occ, "persons": persons, "months": months, "cause": cause,
		"union_density_pct": int(density(world, occ) / 1000), "real_wage_growth_x10": int(round(real_wage_growth(world) * 10.0))}  # tenths of a %
	var fid0 := EconFacts.emit(world, "ECON_STRIKE", o["hq"], [["COMPANY", oid], ["OCCUPATION", occ]], resp, impact, mag, "PUBLIC", data)
	if lockout:
		EconFacts.emit(world, "ECON_LOCKOUT", o["hq"], [["COMPANY", oid], ["OCCUPATION", occ]], EconFacts.company_blame(world, oid, 0.8),
			{"JOBS": -50, "FAIRNESS": -30}, mini(90, mag + 5), "PUBLIC", {"org": oid, "persons": persons, "months": months}, "ALL", [fid0])
	else:
		o["union_pm"] = mini(UNION_PM_MAX, int(o.get("union_pm", 0)) + STRIKE_WIN_PM)


## Labor effectiveness multiplier for a facility this month (1.0 = no stoppage). Read by EconProduction._plan.
static func work_factor(world: WorldState, f: Dictionary) -> float:
	if int(f.get("stop_until", -1)) < world.month:
		return 1.0
	if f.get("stop_min", false):
		return maxf(STRIKE_WORK, MIN_SERVICE_SHARE)  # LAW_ESSENTIAL_SERVICES = MIN_SERVICE
	if f.get("stop_kind", "") == "GENERAL":
		return UnionDisputes.GENERAL_WORK  # U2: a one-month general strike, all sectors partial
	return LOCKOUT_WORK if f.get("stop_kind", "") == "LOCKOUT" else STRIKE_WORK


# ------------------------------------------------------------------ donation offers (SETTLEMENT)

## Exposure of a company's profits to political levers, as {axis: [sign, weight]} (weights 0..1).
static func exposure(world: WorldState, oid: String) -> Dictionary:
	var o: Dictionary = world.table("org")[oid]
	var pl: Dictionary = o["pl"]
	var rev := maxf(1.0, float(pl.get("rev", 0)) + float(pl.get("subsidy", 0)))
	var out := {}
	if o["type"] == "COOPERATIVE":
		out["LABOR"] = [1, 0.6]  # worker-owned firms back pro-labor parties
		out["REDISTRIBUTION"] = [1, 0.3]
		return out
	# profit tax: the higher the rate, the more a profitable firm stands to gain from a cut
	var ptax := float(EconUtil.lever(world, "ECON_PROFIT_TAX_RATE", 20)) / 100.0
	out["REDISTRIBUTION"] = [-1, clampf(ptax * 2.5, 0.0, 1.0)]
	# labor cost: wage bill share × (union density + minimum wage bite)
	var wage_share := float(pl.get("wages", 0)) / rev
	var wf := _org_workforce(world, oid)
	var dens := float(density(world, _dominant(wf["occ"]))) / 100000.0
	var mw_bite := clampf((float(EconUtil.lever(world, "ECON_MIN_WAGE", 40)) - 40.0) / 60.0, 0.0, 1.0)
	var lab := clampf(wage_share * (0.8 + 1.5 * dens + mw_bite) + 0.3 * float(int(o.get("union_pm", 0))) / 100.0, 0.0, 1.0)
	if lab > 0.15:
		out["LABOR"] = [-1, lab]
	# pollution regulation
	var poll := 0.0
	for fid in wf["facs"]:
		poll += float(EconData.RECIPES[world.table("facility")[fid]["type"]]["poll"])
	if poll >= 4.0:
		out["ENVIRONMENT"] = [-1, clampf(poll / 12.0, 0.0, 1.0)]
	# state as customer: contractors and subsidy recipients want an active state
	var gov_share := float(pl.get("subsidy", 0)) / rev
	if o["is_contractor"]:
		var gov_contracts := 0
		for pid in o.get("contracts", []):
			if world.table("project").has(pid) and world.table("project")[pid]["owner"] == "gov":
				gov_contracts += 1
		gov_share += 0.25 * float(gov_contracts)
	if gov_share > 0.1:
		out["ECON_ROLE"] = [1, clampf(gov_share, 0.0, 1.0)]
	return out


## Write this month's offers (end of SETTLEMENT). Politics matches each to a party in POLITICS and books
## ledger.transfer(EconUtil.acct(from) → "party:<id>", amount_milli); a failed transfer means the offer lapsed.
static func donation_offers(world: WorldState) -> void:
	var tbl := world.table("donation_offer")
	tbl.clear()
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not (o["type"] in ["PRIVATE", "COOPERATIVE"]) or o["status"] != "ACTIVE":
			continue
		var pl_m: Dictionary = o["pl_last"] if not o.get("pl_last", {}).is_empty() else o["pl"]  # last closed month (the current one is still being booked)
		var profit := EconFinance.profit(pl_m)
		if profit <= 0:
			continue
		var exp := exposure(world, oid)
		var axes: Array = EconUtil.sorted_keys(exp)
		axes.sort_custom(func(a, b): return exp[a][1] > exp[b][1] or (exp[a][1] == exp[b][1] and a < b))
		var weight := 0.0
		var prefers := {}
		for ax in axes.slice(0, 2):
			if exp[ax][1] < 0.2:
				continue
			prefers[ax] = exp[ax][0]
			weight += exp[ax][1]
		if prefers.is_empty():
			continue
		var cash := world.ledger.balance(EconUtil.acct(oid))
		var spare := cash - DONATION_CASH_COVER * maxi(1, EconFinance._monthly_costs(o))
		var amount := mini(int(float(profit) * DONATION_SHARE * minf(weight, 1.5)), spare)
		if amount < DONATION_MIN:
			continue
		tbl[oid] = {"from": oid, "amount_milli": amount, "prefers": prefers, "month": world.month}
