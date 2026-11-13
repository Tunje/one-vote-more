extends RefCounted
## P1a crime model (planning/design-p1-crime-police.md §1; plan-public-safety A60). Owner: Anni (law).
## Aggregate offence counts per district and month: THEFT, VIOLENCE, FRAUD. OPT-IN: world.meta["on"] has "CRIME"
## (meta["off"] wins). Integer state in law_state.s.crime; stream law.crime. Preload it (no class_name).
##
## expected = base × pop/10k/12 × drivers × deterrence × presence × cooperation
##   drivers     Bob's EconQuery.crime_drivers when it exists, else a fallback from households (unemployment,
##               colony food shortfall, homelessness, income ratio)
##   deterrence  last year's clearance against the base clearance (a force that solves crimes prevents them)
##   presence    patrol hours delivered against the need (P1a: police strength from LAW_POLICE_BUDGET only)
##   cooperation 1.0 until trust in the police exists (P1c)
## Only reported offences enter the police workload and the published rate (crime_rate).

const KINDS := ["THEFT", "VIOLENCE", "FRAUD"]
const BASE_10K_Y := {"THEFT": 600, "VIOLENCE": 100, "FRAUD": 200}      # Swedish-level, full employment
const BASE_CLEAR_PM := {"THEFT": 60, "VIOLENCE": 250, "FRAUD": 100}     # share of reported offences solved
const REPORT_PM := {"THEFT": 700, "VIOLENCE": 600, "FRAUD": 400}        # share of offences reported
const HOURS_PER_CASE := {"THEFT": 6, "VIOLENCE": 30, "FRAUD": 40}

# drivers (multipliers around 1.0 at the reference)
const U_REF := 40                       # unemployment ‰ at "full employment"
const U_SLOPE := {"THEFT": 0.0055, "VIOLENCE": 0.0027, "FRAUD": 0.001}           # per ‰ above U_REF (4%→15%: ×1.6 theft)
const HUNGER_SLOPE := {"THEFT": 0.004, "VIOLENCE": 0.0015, "FRAUD": 0.0}         # per ‰ food shortfall (250‰: ×2 theft)
const HOMELESS_SLOPE := {"THEFT": 0.002, "VIOLENCE": 0.002, "FRAUD": 0.0}        # per ‰ of households without a home
const INEQ_REF := 4000                  # income per head, top band / bottom band, ×1000 (fallback; the colony's first
                                        # measured ratio becomes state.ineq_ref)
const INEQ_EXP := {"THEFT": 0.3, "VIOLENCE": 0.3, "FRAUD": 0.1}
const DRIVER_MIN := 0.5
const DRIVER_MAX := 4.0

# police strength (P1a: from the budget lever only; P1b replaces it with stations and staff)
const OFFICERS_PER_10K := 20
const OFFICER_HOURS := 130              # per officer-month on duty
const COOP_BASE := 0.7                   # P1c: reporting and clearance × (0.7 + 0.3 × trust / start trust)
const COOP_MIN := 0.6
const COOP_MAX := 1.15
const PATROL_HOURS_PER_10K := 1100      # patrol need per 10k residents per month (≈ 42% of reference hours). Tuned on
                                        # Bob's stations: base crime ≈ 650‰ workload, slumps ≈ 1000‰, cuts to the cap
const REF_COST_PER_10K := 26000         # milli-W_ref/month at full strength: 20 officers + support staff (Bob's budget line)
const DEFAULT_BUDGET := 1000            # LAW_POLICE_BUDGET: ‰ of the reference strength per resident
const PRESENCE_EXP := -0.3
const PRESENCE_MIN := 0.8
const PRESENCE_MAX := 1.5
const DETER := 0.3                      # relative clearance gain → relative crime fall
const DETER_MIN := 0.7
const DETER_MAX := 1.5
const CLEAR_EMA := 0.1                  # monthly weight of this month's clearance in clear_ema

# facts
const WAVE_FACTOR := 1.5                # 3-month rate ≥ this × the district's 24-month mean …
const WAVE_ABOVE_BASE := 1.3            # … and ≥ this × the reported base rate
const WAVE_GAP := 12                    # months between waves in one district
const HIGH_CRIME_X := 2.0               # v8: a district whose 12-month index (theft + 3 × violence) is ≥ this × the
const HIGH_CRIME_GAP := 12              # reported base is news once a year (a wave is measured against the district's
                                        # own past, so lasting high crime stopped being news)
const P_VIOLENT_STORY := 0.2            # chance a month with violent crime gives one LAW_VIOLENT_CRIME story
const WAVE_SIGMA := 3.0                 # … and ≥ this many Poisson deviations above what the mean rate predicts
const P_RING := 0.08                    # chance a solved fraud is a ring (LAW_FRAUD_RING_BUSTED)
const UNPATROLLED_BELOW := 500          # coverage ‰ …
const UNPATROLLED_MONTHS := 3           # … for this long
const HIST := 24


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("CRIME") \
		and not (world.meta.has("off") and (world.meta["off"] as Array).has("CRIME"))


static func state(world: WorldState) -> Dictionary:
	var s: Dictionary = world.table("law_state").get_or_add("s", {})
	if not s.has("crime"):
		s["crime"] = {"d": {}, "low_cov_months": 0, "last_unpatrolled": -999, "budget_hist": []}
	return s["crime"]


static func _peek_state(world: WorldState) -> Dictionary:
	return world.peek("law_state").get("s", {}).get("crime", {})


# =================================================================================== drivers

## {district: {pop, unemployed_pm, hunger_pm, homeless_pm, ineq_x1000, youth_pm, stock_wref, firms}} — Bob's reader
## when it exists, else the household fallback. Integers.
static func drivers(world: WorldState) -> Dictionary:
	var eq = load("res://sim/economy/econ_query.gd")
	for m in eq.get_script_method_list():
		if String(m["name"]) == "crime_drivers":
			return eq.call("crime_drivers", world)
	return _fallback_drivers(world)


## Bob's EconPolice.hours(world, district) (officers on duty × OFFICER_HOURS, sick share removed) while the police
## stations run (meta["on"] "POLICE"); null otherwise, and police_hours models strength from the lever.
static func _station_hours():
	if not ResourceLoader.exists("res://sim/economy/econ_police.gd"):
		return null
	var ep = load("res://sim/economy/econ_police.gd")
	var has_on := false
	var has_hours := false
	for m in ep.get_script_method_list():
		has_on = has_on or String(m["name"]) == "active"
		has_hours = has_hours or String(m["name"]) == "hours"
	if not has_hours:
		return null
	return func(w: WorldState, d: String) -> int:
		if has_on and not bool(ep.call("active", w)):
			return police_hours(int(state(w)["d"].get(d, {}).get("pop", 0)), coverage_pm(w))
		return int(ep.call("hours", w, d))


static func _fallback_drivers(world: WorldState) -> Dictionary:
	var out := {}
	var hh := world.peek("hh")
	var inc := {}       # district -> band -> [income, persons]
	for gid in EconUtil.sorted_keys(hh):
		var g: Dictionary = hh[gid]
		var d := String(g["district"])
		var e: Dictionary = out.get(d, {"pop": 0, "lf": 0, "emp": 0})
		e["pop"] = int(e["pop"]) + EconHouseholds.persons(g) / 1000
		e["lf"] = int(e["lf"]) + int(g["lf"])
		e["emp"] = int(e["emp"]) + EconLabor.employed(g)
		out[d] = e
		var bd: Dictionary = inc.get(d, {})
		var b: Array = bd.get(String(g.get("band", "MID")), [0, 0])
		b[0] = int(b[0]) + EconHouseholds.disposable(g)
		b[1] = int(b[1]) + EconHouseholds.persons(g)
		bd[String(g.get("band", "MID"))] = b
		inc[d] = bd
	var hunger := int(EconUtil.peek_st(world).get("food_shortfall", 0))
	var dt := world.peek("district")
	for d in out:
		var e: Dictionary = out[d]
		var lf := int(e["lf"])
		e["unemployed_pm"] = 0 if lf <= 0 else maxi(0, lf - int(e["emp"])) * 1000 / lf
		e["hunger_pm"] = hunger
		var dr: Dictionary = dt.get(d, {})
		var hhs := int(dr.get("households", 0))
		e["homeless_pm"] = 0 if hhs <= 0 else maxi(0, hhs - int(dr.get("units", hhs))) * 1000 / hhs
		var lo := -1.0
		var hi := -1.0
		var bands := 0
		for band in inc[d]:
			var b: Array = inc[d][band]
			if int(b[1]) <= 0:
				continue
			bands += 1
			var pc := float(b[0]) / float(b[1])
			lo = pc if lo < 0.0 else minf(lo, pc)
			hi = maxf(hi, pc)
		e["ineq_x1000"] = INEQ_REF if lo <= 0.0 or bands < 2 else int(round(1000.0 * hi / lo))   # one band: no measure
		e["youth_pm"] = -1
		e["stock_wref"] = -1
		e["firms"] = -1
		e.erase("lf")
		e.erase("emp")
	return out


## Product of the driver multipliers for one kind, clamped.
static func driver_mult(dr: Dictionary, kind: String, ineq_ref: int = INEQ_REF) -> float:
	var m := 1.0 + float(U_SLOPE[kind]) * float(int(dr.get("unemployed_pm", U_REF)) - U_REF)
	m *= 1.0 + float(HUNGER_SLOPE[kind]) * float(maxi(0, int(dr.get("hunger_pm", 0))))
	m *= 1.0 + float(HOMELESS_SLOPE[kind]) * float(maxi(0, int(dr.get("homeless_pm", 0))))
	m *= pow(maxf(0.25, float(int(dr.get("ineq_x1000", ineq_ref))) / float(maxi(1000, ineq_ref))), float(INEQ_EXP[kind]))
	return clampf(m, DRIVER_MIN, DRIVER_MAX)


# =================================================================================== police strength (P1a)

## Police strength ‰ of the reference per resident (LAW_POLICE_BUDGET). pop_total is kept for P1b (stations).
static func coverage_pm(world: WorldState, _pop_total: int = 0) -> int:
	return clampi(int(world.levers.get("LAW_POLICE_BUDGET", DEFAULT_BUDGET)), 0, 2000)


## Monthly cost of the police at the lever's strength (milli-W_ref) for Bob's budget line: value × REF_COST × pop.
static func police_cost(world: WorldState, pop_total: int) -> int:
	return int(round(float(REF_COST_PER_10K) * float(pop_total) / 10000.0 * float(coverage_pm(world)) / 1000.0))


## Monthly police hours in a district (allocated by population).
static func police_hours(pop: int, cov_pm: int) -> int:
	return int(round(float(OFFICERS_PER_10K * OFFICER_HOURS) * float(pop) / 10000.0 * float(cov_pm) / 1000.0))


# =================================================================================== monthly

## LawProvider EVENTS (after the economy): draw this month's offences per district, solve some, update the rolling
## state, emit the notable facts.
static func monthly(world: WorldState) -> void:
	if not on(world):
		return
	var drv := drivers(world)
	if drv.is_empty():
		return
	var cs := state(world)
	var rng := world.rng.stream("law.crime")
	var pop_total := 0
	for d in drv:
		pop_total += int(drv[d].get("pop", 0))
	var cov := coverage_pm(world, pop_total)
	var station_hours = _station_hours()
	var Police = load("res://sim/law/police.gd")
	var powers_clear := float(Police.powers_clearance(world))       # P1c LAW_POLICE_POWERS
	var police_on := bool(Police.on(world))
	var Crim = load("res://sim/law/criminal.gd")
	var crim_on := bool(Crim.on(world))
	if not cs.has("ineq_ref"):       # inequality counts as it changes from the colony's first measured month
		var sw := 0.0
		for d in drv:
			sw += float(int(drv[d].get("ineq_x1000", INEQ_REF))) * float(int(drv[d].get("pop", 0)))
		cs["ineq_ref"] = INEQ_REF if pop_total <= 0 else maxi(1000, int(round(sw / float(pop_total))))
	var violent_total := 0
	var violent_by: Array = []
	for d in EconUtil.sorted_keys(drv):
		var dr: Dictionary = drv[d]
		var pop := int(dr.get("pop", 0))
		if pop <= 0:
			continue
		var row: Dictionary = cs["d"].get(d, {})
		if row.is_empty():
			row = {"hist": {}, "solved_hist": {}, "clear_ema": {}, "last_wave": -999, "m": {}, "pop_hist": []}
			for k in KINDS:
				row["hist"][k] = []
				row["solved_hist"][k] = []
				row["clear_ema"][k] = int(BASE_CLEAR_PM[k])
			cs["d"][d] = row
		row["pop"] = pop
		_push(row["pop_hist"], pop)
		# police hours: cases first, the rest patrols. With Bob's stations (opt-in POLICE) the officers on duty there.
		var hours := police_hours(pop, cov) if station_hours == null else int(station_hours.call(world, d))
		var patrol_need := int(round(float(PATROL_HOURS_PER_10K) * float(pop) / 10000.0))
		# P1c cooperation: trust in the police moves reporting and witnesses (not the true crime rate)
		var coop := 1.0 if not police_on else clampf(COOP_BASE + (1.0 - COOP_BASE) * float(Police.trust_pm(world, d)) 			/ float(Police.TRUST_START), COOP_MIN, COOP_MAX)
		var m := {}
		var reported := {}
		var case_hours := 0
		for k in KINDS:
			var deter := clampf(1.0 - DETER * (float(row["clear_ema"][k]) - float(BASE_CLEAR_PM[k])) / float(BASE_CLEAR_PM[k]),
				DETER_MIN, DETER_MAX)
			var last_patrol := float(row.get("patrol_pm", 1000)) / 1000.0
			var presence := clampf(pow(maxf(0.05, last_patrol), PRESENCE_EXP), PRESENCE_MIN, PRESENCE_MAX) if k != "FRAUD" else 1.0
			var exp_m := float(BASE_10K_Y[k]) * float(pop) / 10000.0 / 12.0 * 1000.0 * driver_mult(dr, k, int(cs["ineq_ref"])) * deter * presence
			if crim_on:
				exp_m += float(Crim.reoffending_milli(world, d, k))     # P2a recent offenders who reoffend
			var n := _draw(rng, exp_m)
			var rep := _draw(rng, float(n) * minf(1000.0, float(REPORT_PM[k]) * coop))
			m[k] = [n, rep, 0]
			reported[k] = rep
			case_hours += rep * int(HOURS_PER_CASE[k])
		var need := case_hours + patrol_need
		var work_pm := 1000 if need <= 0 else int(round(1000.0 * float(need) / maxf(1.0, float(hours))))
		var cap_ratio := 1.0 if need <= 0 else minf(1.0, float(hours) / float(need))
		row["workload_pm"] = work_pm
		row["need_h"] = need          # Bob's station workload ‰ = Σ need_h of its districts ÷ (staff × OFFICER_HOURS)
		row["hours"] = hours
		row["patrol_pm"] = 1000 if patrol_need <= 0 else clampi(int(round(1000.0 * float(maxi(0, hours - case_hours)) / float(patrol_need))), 0, 3000)
		for k in KINDS:
			var clear := minf(1000.0, float(BASE_CLEAR_PM[k]) * sqrt(cap_ratio) * sqrt(coop) * powers_clear)
			var solved := _draw(rng, float(int(reported[k])) * clear)
			m[k][2] = solved
			var rep_k := int(reported[k])
			if rep_k > 0:
				var c_now := 1000.0 * float(solved) / float(rep_k)
				row["clear_ema"][k] = int(round(float(row["clear_ema"][k]) + (c_now - float(row["clear_ema"][k])) * CLEAR_EMA))
			_push(row["hist"][k], rep_k)
			_push(row["solved_hist"][k], solved)
		row["m"] = m
		row["month"] = world.month
		_wave(world, d, row)
		_high_crime(world, d, row)
		var rings := 0
		for i in int(m["FRAUD"][2]):
			if rng.randf() < P_RING:
				rings += 1
		if rings > 0:
			world.add_fact({"type": "LAW_FRAUD_RING_BUSTED", "owner": "law", "subjects": [{"kind": "DISTRICT", "id": d}],
				"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
				"impact": {"FAIRNESS": 2, "GOVERNANCE": 1}, "magnitude": 30, "visibility": "PUBLIC",
				"data": {"district": d, "solved": int(m["FRAUD"][2]), "rings": rings}})
		if int(m["VIOLENCE"][0]) > 0:
			violent_total += int(m["VIOLENCE"][0])
			violent_by.append([d, int(m["VIOLENCE"][0]), int(m["VIOLENCE"][2])])
	cs["coverage_pm"] = cov
	_unpatrolled(world, cs, cov)
	if violent_total > 0 and rng.randf() < P_VIOLENT_STORY:
		var x := rng.randi_range(1, violent_total)
		for v in violent_by:
			x -= int(v[1])
			if x <= 0:
				world.add_fact({"type": "LAW_VIOLENT_CRIME", "owner": "law", "subjects": [{"kind": "DISTRICT", "id": v[0]}],
					"responsible": [], "impact": {"SAFETY": -2}, "magnitude": 30, "visibility": "PUBLIC",
					"data": {"district": v[0], "solved": int(v[2]) > 0}})
				break


## Integer draw with mean exp_milli / 1000: the whole part for certain, the remainder by chance.
static func _draw(rng: RandomNumberGenerator, exp_milli: float) -> int:
	var e := int(maxf(0.0, exp_milli))
	return e / 1000 + (1 if rng.randi_range(0, 999) < e % 1000 else 0)


static func _push(a: Array, v: int) -> void:
	a.append(v)
	while a.size() > HIST:
		a.pop_front()


static func _sum_last(a: Array, n: int) -> int:
	var s := 0
	for i in range(maxi(0, a.size() - n), a.size()):
		s += int(a[i])
	return s


## A crime wave: the district's 3-month reported rate per resident (theft + violence) ≥ WAVE_FACTOR × its 24-month
## mean rate, significantly so (WAVE_SIGMA Poisson deviations: small districts are noisy), and ≥ WAVE_ABOVE_BASE × the
## reported base. Rates, not counts: a district that grows is not a wave. Blame on the government by police underfunding.
static func _wave(world: WorldState, d: String, row: Dictionary) -> void:
	if world.month - int(row["last_wave"]) < WAVE_GAP:
		return
	var h_t: Array = row["hist"]["THEFT"]
	var ph: Array = row.get("pop_hist", [])
	if h_t.size() < HIST or ph.size() < HIST:
		return
	var recent_n := 0.0
	var mean_n := 0.0
	var base_rate_pp := 0.0      # reported per resident-month at the base
	for k in ["THEFT", "VIOLENCE"]:
		recent_n += float(_sum_last(row["hist"][k], 3))
		mean_n += float(_sum_last(row["hist"][k], HIST))
		base_rate_pp += float(BASE_10K_Y[k]) * float(REPORT_PM[k]) / 1000.0 / 10000.0 / 12.0
	var pop3 := float(_sum_last(ph, 3))
	var pop24 := float(_sum_last(ph, HIST))
	if pop3 <= 0.0 or pop24 <= 0.0:
		return
	var expected := mean_n / pop24 * pop3          # what the 24-month rate predicts for the last 3 months
	var recent := recent_n / 3.0
	var mean := mean_n / float(HIST)
	if recent_n < WAVE_FACTOR * expected or recent_n < expected + WAVE_SIGMA * sqrt(maxf(1.0, expected)) \
			or recent_n / pop3 < WAVE_ABOVE_BASE * base_rate_pp:
		return
	row["last_wave"] = world.month
	var cov := int(_peek_state(world).get("coverage_pm", 1000))
	var gov_share := clampf(1.0 - float(cov) / 1000.0, 0.0, 1.0)
	var resp: Array = []
	if gov_share > 0.0:
		# shares must sum to 1 (FactStore): the rest of the blame falls on the offenders, whom politics ignores
		resp.append({"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": gov_share})
		if gov_share < 1.0:
			resp.append({"actor": {"kind": "OFFENDERS", "id": "offenders"}, "share": 1.0 - gov_share})
	world.add_fact({"type": "LAW_CRIME_WAVE", "owner": "law", "subjects": [{"kind": "DISTRICT", "id": d}],
		"responsible": resp, "impact": {"SAFETY": -5}, "magnitude": 45, "visibility": "PUBLIC",
		"data": {"district": d, "monthly": int(round(recent)), "mean": int(round(mean)), "coverage_pm": cov}})


## LAW_DISTRICT_UNPATROLLED: police coverage below UNPATROLLED_BELOW ‰ for UNPATROLLED_MONTHS months (once a year).
## data.budget_cut when LAW_POLICE_BUDGET fell within the last 24 months.
static func _unpatrolled(world: WorldState, cs: Dictionary, cov: int) -> void:
	var bh: Array = cs["budget_hist"]
	_push(bh, int(world.levers.get("LAW_POLICE_BUDGET", DEFAULT_BUDGET)))
	cs["low_cov_months"] = int(cs["low_cov_months"]) + 1 if cov < UNPATROLLED_BELOW else 0
	if int(cs["low_cov_months"]) < UNPATROLLED_MONTHS or world.month - int(cs["last_unpatrolled"]) < 12:
		return
	cs["last_unpatrolled"] = world.month
	var cut := false
	for v in bh:
		if int(v) > int(bh[bh.size() - 1]):
			cut = true
	var worst := ""
	var worst_rate := -1
	for d in EconUtil.sorted_keys(cs["d"]):
		var r := rate_10k_y(cs["d"][d], "VIOLENCE") + rate_10k_y(cs["d"][d], "THEFT")
		if r > worst_rate:
			worst_rate = r
			worst = String(d)
	world.add_fact({"type": "LAW_DISTRICT_UNPATROLLED", "owner": "law", "subjects": [{"kind": "DISTRICT", "id": worst}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {"SAFETY": -4, "GOVERNANCE": -2},
		"magnitude": 45, "visibility": "PUBLIC", "data": {"district": worst, "coverage_pm": cov, "budget_cut": cut}})


# =================================================================================== readers

## Reported offences per 10k residents per year over the last 12 months (fewer months early on, annualised).
## v8: lasting high crime stays visible. LAW_HIGH_CRIME (PUBLIC) at most once a year per district while its 12-month
## reported index is ≥ HIGH_CRIME_X × the base index; blame on the government by police underfunding (as a wave).
static func _high_crime(world: WorldState, d: String, row: Dictionary) -> void:
	if (row["hist"]["THEFT"] as Array).size() < 12 or world.month - int(row.get("last_high", -999)) < HIGH_CRIME_GAP:
		return
	var idx := float(rate_10k_y(row, "THEFT") + 3 * rate_10k_y(row, "VIOLENCE"))
	var base := float(BASE_10K_Y["THEFT"]) * float(REPORT_PM["THEFT"]) / 1000.0 		+ 3.0 * float(BASE_10K_Y["VIOLENCE"]) * float(REPORT_PM["VIOLENCE"]) / 1000.0
	if idx < HIGH_CRIME_X * base:
		return
	row["last_high"] = world.month
	var cov := int(_peek_state(world).get("coverage_pm", 1000))
	var gov_share := clampf(1.0 - float(cov) / 1000.0, 0.0, 1.0)
	var resp: Array = []
	if gov_share > 0.0:
		resp.append({"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": gov_share})
		if gov_share < 1.0:
			resp.append({"actor": {"kind": "OFFENDERS", "id": "offenders"}, "share": 1.0 - gov_share})
	world.add_fact({"type": "LAW_HIGH_CRIME", "owner": "law", "subjects": [{"kind": "DISTRICT", "id": d}],
		"responsible": resp, "impact": {"SAFETY": -4}, "magnitude": 40, "visibility": "PUBLIC",
		"data": {"district": d, "theft": rate_10k_y(row, "THEFT"), "violence": rate_10k_y(row, "VIOLENCE"),
			"times_base": snappedf(idx / base, 0.1), "coverage_pm": cov}})


static func rate_10k_y(row: Dictionary, kind: String) -> int:
	var h: Array = row.get("hist", {}).get(kind, [])
	var pop := int(row.get("pop", 0))
	if h.is_empty() or pop <= 0:
		return 0
	var n := mini(12, h.size())
	return int(round(float(_sum_last(h, n)) * 12.0 / float(n) * 10000.0 / float(pop)))


## {THEFT, VIOLENCE, FRAUD: reported per 10k per year} for a district ("" = colony, population-weighted). Pure read;
## {} while the crime model is off or has not run; zeros for a district without residents.
static func crime_rate(world: WorldState, district: String = "") -> Dictionary:
	var cs := _peek_state(world)
	var rows: Dictionary = cs.get("d", {})
	if rows.is_empty():
		return {}
	var out := {}
	if district != "":
		if not rows.has(district):
			for k in KINDS:      # a district nobody lives in (yet): no crime, not "no data" (Terra's map)
				out[k] = 0
			return out
		for k in KINDS:
			out[k] = rate_10k_y(rows[district], k)
		return out
	var pop := 0
	for d in rows:
		pop += int(rows[d].get("pop", 0))
	for k in KINDS:
		var s := 0.0
		for d in rows:
			s += float(rate_10k_y(rows[d], k)) * float(int(rows[d].get("pop", 0)))
		out[k] = 0 if pop <= 0 else int(round(s / float(pop)))
	return out


## The reported base rate per 10k per year (what crime_rate reads at full employment with reference police).
static func base_rate(kind: String) -> int:
	return int(BASE_10K_Y[kind]) * int(REPORT_PM[kind]) / 1000


## UI / probes: per district {pop, workload_pm, patrol_pm, need_h, hours, clearance_pm {kind}, month {kind: [offences, reported, solved]}}.
static func stats(world: WorldState) -> Dictionary:
	var out := {}
	var rows: Dictionary = _peek_state(world).get("d", {})
	for d in rows:
		var r: Dictionary = rows[d]
		out[d] = {"pop": int(r.get("pop", 0)), "workload_pm": int(r.get("workload_pm", 0)), "patrol_pm": int(r.get("patrol_pm", 0)),
			"need_h": int(r.get("need_h", 0)), "hours": int(r.get("hours", 0)),
			"clearance_pm": r.get("clear_ema", {}).duplicate(), "month": r.get("m", {}).duplicate(true)}
	return out
