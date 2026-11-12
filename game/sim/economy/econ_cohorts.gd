class_name EconCohorts
extends RefCounted
## E120 (user, Wilma-approved): age-structured demography. "Population booms … wouldn't everyone retire at the same
## time?" Each district keeps an age histogram (econ.s.cohorts[district] = 100 ints, persons aged 0..99+; no new
## PopStore key). The histogram is the authority on age; it drives the existing PopStore status moves:
##   - births: women 18–42 (half of each age) × an age-specific fertility schedule; total fertility starts near
##     TFR_BASE and falls with income, school access, density and crowding (the demographic transition), × food brake;
##   - deaths by age (infant, adult, old), worse with poor health access and famine;
##   - every January everyone ages a year; the cohort turning 18 grows up and the cohort reaching the retirement age
##     (LAW_RETIREMENT_AGE) retires over the following 12 months — employed people too (their jobs fall vacant).
##     Founders (mostly 20–40) therefore retire as a wave around Y25–40, and the first baby boom echoes 25–30 years on;
##   - adults outside the labour force re-enter it, faster when there are vacancies.
## Once a year the histogram is rescaled to PopStore's counts per life stage (absorbs migrants and moves).

const S := EconUtil.S
const AGES := 100
const ADULT := 18
const FERT_LO := 18
const FERT_HI := 42
const TFR_BASE := 6.0
const TFR_MIN := 1.3
const TFR_MAX := 4.2
const REENTRY_BASE := 0.01  # share of non-participating adults re-entering the labour force per month
const REENTRY_VAC := 0.05  # extra per month × the vacancy rate


# ------------------------------------------------------------------ age schedules

## Annual death probability at an age (h = health access 0..1).
static func mortality(a: int, h: float) -> float:
	var poor := 2.0 - h
	if a == 0:
		return 0.015 * poor
	if a < 5:
		return 0.002 * poor
	if a < 18:
		return 0.0005
	if a < 40:
		return 0.001 * poor
	if a < 55:
		return 0.003 * poor
	if a < 65:
		return 0.009 * poor
	if a < 75:
		return 0.022 * poor
	if a < 85:
		return 0.06 * poor
	if a < 95:
		return 0.16
	return 0.35


## Share of a lifetime's births at age a (sums to 1 over 18..42; peak in the mid-twenties).
static func fert_shape(a: int) -> float:
	if a < FERT_LO or a > FERT_HI:
		return 0.0
	var w := 1.0 - absf(float(a) - 26.0) / 17.0
	return maxf(0.05, w) / 15.8


# ------------------------------------------------------------------ state

static func _st(world: WorldState) -> Dictionary:
	var s := EconUtil.st(world)
	if not s.has("cohorts"):
		s["cohorts"] = {}
		s["cohort_rem"] = {}
		s["cohort_pending"] = {}
	return s


## Builds a district's histogram from PopStore life stages: children 0–17, founders' adults mostly 20–40, retirees.
static func _init_district(world: WorldState, d: String) -> Array:
	var hb := EconPop.hb_of(d)
	var ch := PopStore.count(world, {"hb": hb, "status": "CHILD"})
	var ret := PopStore.count(world, {"hb": hb, "status": "RETIRED"})
	var all := PopStore.count(world, {"hb": hb})
	var adults := maxi(0, all - ch - ret)
	var ra := EconHouseholds.retirement_age(world)
	var h: Array = []
	h.resize(AGES)
	h.fill(0)
	_spread(h, ch, 0, ADULT - 1, func(a): return 1.2 - float(a) / 30.0)
	_spread(h, adults, ADULT, ra - 1, func(a): return exp(-pow((float(a) - 30.0) / 8.0, 2.0) / 2.0) + 0.02)
	_spread(h, ret, ra, 90, func(a): return exp(-float(a - ra) / 8.0))
	return h


static func _spread(h: Array, n: int, lo: int, hi: int, weight: Callable) -> void:
	if n <= 0 or hi < lo:
		return
	var w: Array = []
	for a in range(lo, hi + 1):
		w.append(maxf(0.0, float(weight.call(a))))
	var parts := EconUtil.split_lr(n, w)
	for i in parts.size():
		h[lo + i] = int(h[lo + i]) + int(parts[i])


static func histogram(world: WorldState, d: String) -> Array:
	var s := _st(world)
	if not s["cohorts"].has(d):
		s["cohorts"][d] = _init_district(world, d)
	return s["cohorts"][d]


static func _whole(rem: Dictionary, key: String, x: float) -> int:
	var v := float(rem.get(key, 0)) / 1000.0 + x
	var n := int(floor(v))
	rem[key] = int(round((v - float(n)) * 1000.0))
	return n


# ------------------------------------------------------------------ monthly

static func monthly(world: WorldState) -> void:
	var s := _st(world)
	var health: Dictionary = s.get("health_access", {})
	var edu: Dictionary = s.get("edu_access", {})
	var famine := float(s.get("food_shortfall", 0)) / 1000.0 > 0.30
	var ra := EconHouseholds.retirement_age(world)
	for d in EconUtil.sorted_keys(EconData.DISTRICTS):
		var pools: Array = []
		for gid in EconUtil.sorted_keys(world.table("hh")):
			if world.table("hh")[gid]["district"] == d:
				pools.append(gid)
		if pools.is_empty() or PopStore.count(world, {"hb": EconPop.hb_of(d)}) <= 0:
			continue
		var h := histogram(world, d)
		var rem: Dictionary = s["cohort_rem"].get(d, {})
		s["cohort_rem"][d] = rem
		var hacc := float(health.get(d, 1000)) / 1000.0
		_deaths(world, d, pools, h, rem, hacc, famine, ra)
		_births(world, d, pools, h, rem, float(edu.get(d, 1000)) / 1000.0)
		if world.month_of_year() == 1:
			_age_year(world, d, h, ra)
		_pending_moves(world, d, pools)
		_reentry(world, pools)
		if world.month_of_year() == 2:
			_reconcile(world, d, h, ra)
	_slum_watch(world)


static func _deaths(world: WorldState, d: String, pools: Array, h: Array, rem: Dictionary, hacc: float, famine: bool, ra: int) -> void:
	var occ := float(world.peek("district").get(d, {}).get("occupancy", 1000)) / 1000.0
	var crowd := 1.0 + 2.0 * maxf(0.0, occ - SLUM_OCC)
	var total_d := 0
	var n := {"c": 0, "w": 0, "o": 0}
	for a in AGES:
		var k := int(h[a])
		if k <= 0:
			continue
		var q := mortality(a, hacc) * crowd  # slums: crowding raises mortality
		if famine:
			q += 0.03 if a < 5 or a >= ra else 0.012
		var dd := mini(k, _whole(rem, "d%d" % a, float(k) * q / 12.0))
		if dd <= 0:
			continue
		h[a] = k - dd
		total_d += dd
		if a < ADULT:
			n["c"] += dd
		elif a < ra:
			n["w"] += dd
		else:
			n["o"] += dd
	var sd := EconUtil.st(world)
	sd["deaths_12m"] = _roll(sd.get("deaths_12m", []), total_d, world.month)
	var hb := EconPop.hb_of(d)
	EconHouseholds._die(world, {"hb": hb}, "CHILD", mini(int(n["c"]), PopStore.count(world, {"hb": hb, "status": "CHILD"})))
	EconHouseholds._die(world, {"hb": hb}, "RETIRED", mini(int(n["o"]), PopStore.count(world, {"hb": hb, "status": "RETIRED"})))
	var w := int(n["w"])
	var np := mini(w, PopStore.count(world, {"hb": hb, "status": "NOT_IN_LF", "occ": "NONE"}))
	EconHouseholds._die(world, {"hb": hb, "occ": "NONE"}, "NOT_IN_LF", np)
	EconHouseholds._die(world, {"hb": hb}, "UNEMPLOYED", mini(w - np, PopStore.count(world, {"hb": hb, "status": "UNEMPLOYED"})))


## Total fertility in a district now (the demographic transition).
static func tfr(world: WorldState, d: String, edu: float) -> float:
	var hb := EconPop.hb_of(d)
	var inc := 0.0
	var n := 0.0
	var bands := ["I1", "I2", "I3", "I4", "I5"]
	for i in bands.size():
		var c := float(PopStore.count(world, {"hb": hb, "inc": bands[i]}))
		inc += c * float(i) / 4.0
		n += c
	inc = inc / maxf(1.0, n)
	var dens := clampf(n / 1500.0, 0.0, 1.0)
	var occ := float(world.peek("district").get(d, {}).get("occupancy", 1000)) / 1000.0
	var crowd := clampf(1.0 - 0.5 * maxf(0.0, occ - 1.0), 0.6, 1.0)
	var t := TFR_BASE * (1.0 - 0.35 * inc - 0.25 * edu - 0.15 * dens) * crowd * EconHouseholds.food_brake(world)  # early ≈ 3.4, a rich dense colony ≈ 2.5
	return clampf(t, TFR_MIN, TFR_MAX)


static func _births(world: WorldState, d: String, pools: Array, h: Array, rem: Dictionary, edu: float) -> void:
	var t := tfr(world, d, edu)
	var b := 0.0
	for a in range(FERT_LO, FERT_HI + 1):
		b += float(h[a]) * 0.5 * fert_shape(a) * t / 12.0
	var births := _whole(rem, "births", b)
	if births <= 0:
		return
	h[0] = int(h[0]) + births
	# into the pools of the district by their working-age adults (parents' housing block and income band)
	var w: Array = []
	for gid in pools:
		var g: Dictionary = world.table("hh")[gid]
		w.append(float(g["lf"] + g["nonpart"] + g["owners"]) + 1.0)
	var parts := EconUtil.split_lr(births, w)
	for i in pools.size():
		if int(parts[i]) <= 0:
			continue
		var g2: Dictionary = world.table("hh")[pools[i]]
		var ck := PopStore.key_of({"hb": g2["hb"], "inc": g2["band"], "occ": "NONE", "status": "CHILD", "arch": EconPop.ARCH, "eff": "e0"})
		PopStore.birth(world, ck, int(parts[i]))
	var s := EconUtil.st(world)
	s["births_12m"] = _roll(s.get("births_12m", []), births, world.month)


## January: everyone a year older; the cohort turning 18 and the one reaching the retirement age queue their moves.
static func _age_year(world: WorldState, d: String, h: Array, ra: int) -> void:
	var turning_adult := int(h[ADULT - 1])
	var retiring := int(h[ra - 1])
	var top := int(h[AGES - 1]) + int(h[AGES - 2])
	for a in range(AGES - 2, 0, -1):
		h[a] = h[a - 1]
	h[0] = 0
	h[AGES - 1] = top
	var pend: Dictionary = EconUtil.st(world)["cohort_pending"].get(d, {"grow": 0, "retire": 0})
	pend["grow"] = int(pend.get("grow", 0)) + turning_adult
	pend["retire"] = int(pend.get("retire", 0)) + retiring
	pend["grow_q"] = maxi(1, int(pend["grow"]) / 12 + 1)
	pend["retire_q"] = maxi(1, int(pend["retire"]) / 12 + 1)
	EconUtil.st(world)["cohort_pending"][d] = pend


## The queued cohort moves, spread over the year: growing up (existing tiering by school access) and retiring.
static func _pending_moves(world: WorldState, d: String, pools: Array) -> void:
	var s := EconUtil.st(world)
	var pend: Dictionary = s["cohort_pending"].get(d, {})
	if pend.is_empty():
		return
	var edu: Dictionary = s.get("edu_access", {})
	var g_n := mini(int(pend.get("grow", 0)), int(pend.get("grow_q", 0)))
	if g_n > 0:
		var w: Array = []
		for gid in pools:
			w.append(float(world.table("hh")[gid]["children"]) + 1.0)
		var parts := EconUtil.split_lr(g_n, w)
		var done := 0
		for i in pools.size():
			var n_i: int = mini(int(parts[i]), int(world.table("hh")[pools[i]]["children"]) / S)
			if n_i <= 0:
				continue
			var g: Dictionary = world.table("hh")[pools[i]]
			var a := float(edu.get(d, 1000)) / 1000.0
			var split := EconUtil.split_lr(n_i, [a * 0.45 + (1.0 - a) * 0.85, a * 0.40 + (1.0 - a) * 0.15, a * 0.15])
			var tiers := ["G", "S", "Sp"]
			for j in 3:
				var n_t: int = split[j]
				var to_lf := n_t * 90 / 100  # E120: most young adults look for work (was 82%)
				EconHouseholds._grow_up(world, g, tiers[j], "UNEMPLOYED", to_lf)
				EconHouseholds._grow_up(world, g, tiers[j], "NOT_IN_LF", n_t - to_lf)
			done += n_i
		pend["grow"] = maxi(0, int(pend["grow"]) - maxi(done, g_n))
	var r_n := mini(int(pend.get("retire", 0)), int(pend.get("retire_q", 0)))
	if r_n > 0:
		var hb := EconPop.hb_of(d)
		var np := PopStore.count(world, {"hb": hb, "status": "NOT_IN_LF", "occ": "NONE"})
		var un := PopStore.count(world, {"hb": hb, "status": "UNEMPLOYED"})
		var em := PopStore.count(world, {"hb": hb, "status": "EMPLOYED"})
		var parts2 := EconUtil.split_lr(r_n, [float(np), float(un), float(em)])
		var m := PopStore.move_group(world, {"hb": hb, "status": "NOT_IN_LF", "occ": "NONE"}, int(parts2[0]), {"status": "RETIRED"}, "RETIRE")
		m += PopStore.move_group(world, {"hb": hb, "status": "UNEMPLOYED"}, int(parts2[1]), {"status": "RETIRED", "occ": "NONE"}, "RETIRE")
		m += retire_employed(world, hb, int(parts2[2]))
		pend["retire"] = maxi(0, int(pend["retire"]) - maxi(m, r_n))
		EconPop.sync(world)
	s["cohort_pending"][d] = pend


## n employed people of a housing block retire: their posts are released from the staff records (vacancies next month).
static func retire_employed(world: WorldState, hb: String, n: int) -> int:
	var left := n
	var done := 0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		if left <= 0:
			break
		var f: Dictionary = world.table("facility")[fid]
		left -= _retire_from(world, f["org"], f["type"], f["staff"], hb, left)
	for oid in EconUtil.sorted_keys(world.table("org")):
		if left <= 0:
			break
		var o: Dictionary = world.table("org")[oid]
		if o["is_contractor"]:
			left -= _retire_from(world, oid, "CREW", o["crew"], hb, left)
	return n - left


static func _retire_from(world: WorldState, org_id: String, ftype: String, staff: Dictionary, hb: String, want: int) -> int:
	var took := 0
	for t in EconUtil.sorted_keys(staff):
		var recs: Dictionary = staff[t]
		for k in EconUtil.sorted_keys(recs):
			if took >= want:
				return took
			var p := EconPop.lab_parts(k)
			if p[0] != hb:
				continue
			var have := int(recs[k]) / S
			var take := mini(have, want - took)
			if take <= 0:
				continue
			var occ := EconPop.person_occ(world, org_id, ftype, t)
			var moved := PopStore.move_group(world, {"hb": hb, "status": "EMPLOYED", "occ": occ}, take, {"status": "RETIRED", "occ": "NONE"}, "RETIRE", "skill:" + str(p[1]))
			if moved <= 0:
				continue
			recs[k] = int(recs[k]) - moved * S
			if int(recs[k]) <= 0:
				recs.erase(k)
			took += moved
	return took


## Adults outside the labour force come back to it, faster when there are vacancies.
static func _reentry(world: WorldState, pools: Array) -> void:
	var s := EconUtil.st(world)
	var vac := 0
	for t in s.get("vac_unfilled", {}):
		vac += int(s["vac_unfilled"][t])
	var lf := 0
	for gid in world.table("hh"):
		lf += int(world.table("hh")[gid]["lf"])
	var rate := REENTRY_BASE + REENTRY_VAC * clampf(float(vac) / maxf(1.0, float(lf)), 0.0, 1.0)
	for gid in pools:
		var g: Dictionary = world.table("hh")[gid]
		var rem: Dictionary = g.get("demo_rem", {})
		g["demo_rem"] = rem
		var n := EconHouseholds._whole(rem, "reentry", int(float(g["nonpart"]) * rate))
		if n > 0:
			PopStore.move_group(world, {"hb": g["hb"], "inc": g["band"], "status": "NOT_IN_LF", "occ": "NONE"}, n, {"status": "UNEMPLOYED"}, "REENTRY")


## February: rescale each life stage of the histogram to PopStore's counts (migrants, moves, rounding).
static func _reconcile(world: WorldState, d: String, h: Array, ra: int) -> void:
	var hb := EconPop.hb_of(d)
	var ch := PopStore.count(world, {"hb": hb, "status": "CHILD"})
	var ret := PopStore.count(world, {"hb": hb, "status": "RETIRED"})
	var adults := maxi(0, PopStore.count(world, {"hb": hb}) - ch - ret)
	_rescale(h, 0, ADULT - 1, ch)
	_rescale(h, ADULT, ra - 1, adults)
	_rescale(h, ra, AGES - 1, ret)


static func _rescale(h: Array, lo: int, hi: int, target: int) -> void:
	var cur := 0
	var w: Array = []
	for a in range(lo, hi + 1):
		cur += int(h[a])
		w.append(float(h[a]))
	if cur == target:
		return
	if cur <= 0:
		w = []
		for a in range(lo, hi + 1):
			w.append(1.0)
	var parts := EconUtil.split_lr(maxi(0, target), w)
	for i in parts.size():
		h[lo + i] = int(parts[i])


static func _roll(arr: Array, n: int, month: int) -> Array:
	arr.append([month, n])
	while not arr.is_empty() and month - int(arr[0][0]) >= 12:
		arr.pop_front()
	return arr


# ------------------------------------------------------------------ queries

## Colony age pyramid in 5-year bands (persons), and the current total fertility (mean over districts).
static func pyramid(world: WorldState) -> Array:
	var out: Array = []
	out.resize(AGES / 5)
	out.fill(0)
	for d in EconUtil.sorted_keys(EconUtil.peek_st(world).get("cohorts", {})):
		var h: Array = EconUtil.peek_st(world)["cohorts"][d]
		for a in AGES:
			out[a / 5] = int(out[a / 5]) + int(h[a])
	return out


# ------------------------------------------------------------------ migration (E120 phase 2)

const TL := preload("res://sim/law/trade_law.gd")
const SHIP_PASSENGERS := 450  # settlers a home-world ship can carry (HomeWorld may scale it later)
const EMIG_SHARE := 0.1  # of the unemployed young adults, × how unattractive the colony is
const SLUM_OCC := 1.2


## 0..1: how attractive the colony looks to would-be settlers — jobs, real wages, food, housing.
static func attractiveness(world: WorldState) -> float:
	var u := FirmAI.colony_unemployment(world)
	var jobs := clampf(1.0 - u / 0.25, 0.0, 1.0)
	var wage := clampf(0.5 + EconUnions.real_wage_growth(world) / 20.0, 0.0, 1.0)
	var food := EconHouseholds.food_brake(world)
	var units := 0
	var hh := 0
	for d in world.peek("district"):
		units += int(world.peek("district")[d].get("units", 0))
		hh += int(world.peek("district")[d].get("households", 0))
	var occ := float(hh) / maxf(1.0, float(units))
	var housing := clampf(1.0 - maxf(0.0, occ - 1.0) / 0.4, 0.0, 1.0)
	var a := 0.15 + 0.35 * jobs + 0.2 * wage + 0.15 * food + 0.15 * housing
	if bool(EconUtil.peek_st(world).get("famine", false)):
		a *= 0.3
	return clampf(a, 0.0, 1.0)


## On a ship: settlers arrive (ship space × attractiveness × LAW_IMMIGRATION openness) into the least crowded district,
## and unemployed young adults with no prospects leave. No hard unemployment or vacancy gate: a colony without homes
## crowds (slums), a colony without jobs loses its young. Returns {arrived, departed, district, attractiveness_pm}.
static func ship_migration(world: WorldState) -> Dictionary:
	var a := attractiveness(world)
	var open := TL.immigration_openness(world)
	var n := int(float(SHIP_PASSENGERS) * a * open * EconHouseholds.food_brake(world))
	var best := ""
	var best_occ := 1e9
	for d in EconUtil.sorted_keys(world.peek("district")):
		if PopStore.count(world, {"hb": EconPop.hb_of(d)}) <= 0:
			continue
		var occ := float(world.peek("district")[d].get("occupancy", 1000))
		if occ < best_occ:
			best_occ = occ
			best = d
	var arrived := 0
	if n > 0 and best != "":
		EconHouseholds.land_migrants(world, best, n)
		var h := histogram(world, best)
		var adults := n * 7 / 10
		_spread(h, adults, 20, 39, func(x): return 1.0)
		_spread(h, n - adults, 0, 11, func(x): return 1.0)
		arrived = n
		EconFacts.emit(world, "ECON_MIGRANTS_ARRIVED", best, [], [["GOVERNMENT", "government", 0.5], ["EXTERNAL", "origin", 0.5]],
			{}, 15, "PUBLIC", {"persons": n, "attractiveness_pct": int(a * 100.0), "openness_pct": int(open * 100.0)}, {"districts": [best]})
	# emigration: the unemployed young leave on the ship, more when the colony is unattractive
	var departed := 0
	for d in EconUtil.sorted_keys(world.peek("district")):
		var hb := EconPop.hb_of(d)
		var un := PopStore.count(world, {"hb": hb, "status": "UNEMPLOYED"})
		var go := int(float(un) * EMIG_SHARE * (1.0 - a))
		if go <= 0:
			continue
		var keys := PopStore.select(world, {"hb": hb, "status": "UNEMPLOYED"})
		var parts := PopStore.split_over(go, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
		for k in EconUtil.sorted_keys(parts):
			PopStore.depart(world, k, int(parts[k]), "EMIGRATION")
			departed += int(parts[k])
		var h2 := histogram(world, d)
		_take_ages(h2, go, ADULT, 35)
	if departed > 0:
		EconFacts.emit(world, "ECON_EMIGRATION", null, [], [["GOVERNMENT", "government", 0.8], ["NATURE", "market", 0.2]],
			{"JOBS": -mini(40, departed / 5)}, clampi(20 + departed / 10, 20, 60), "PUBLIC", {"persons": departed, "attractiveness_pct": int(a * 100.0)})
	EconPop.sync(world)
	var s := EconUtil.st(world)
	s["arrivals_12m"] = _roll(s.get("arrivals_12m", []), arrived, world.month)
	s["departures_12m"] = _roll(s.get("departures_12m", []), departed, world.month)
	return {"arrived": arrived, "departed": departed, "district": best, "attractiveness_pm": int(a * 1000.0)}


static func _take_ages(h: Array, n: int, lo: int, hi: int) -> void:
	var w: Array = []
	for a in range(lo, hi + 1):
		w.append(float(h[a]))
	var parts := EconUtil.split_lr(n, w)
	for i in parts.size():
		h[lo + i] = maxi(0, int(h[lo + i]) - int(parts[i]))


## Slums: a district above SLUM_OCC occupancy (crowded households doubling up in shacks) — a fact on entry; crowding
## raises mortality in the cohort step. Returns the slum districts.
static func slums(world: WorldState) -> Array:
	var out: Array = []
	for d in EconUtil.sorted_keys(world.peek("district")):
		if _is_slum(world, d):
			out.append(d)
	return out


static func _slum_watch(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var was: Dictionary = s.get("slum", {})
	for d in EconUtil.sorted_keys(world.peek("district")):
		var occ := int(world.peek("district")[d].get("occupancy", 1000))
		var now := _is_slum(world, d)
		if now and not bool(was.get(d, false)):
			EconFacts.emit(world, "ECON_SLUM", d, [], [["GOVERNMENT", "government", 0.7], ["NATURE", "market", 0.3]],
				{"HOUSING": -40, "PUBLIC_SERVICES": -10, "SAFETY": -10}, 45, "PUBLIC", {"district": d, "occupancy_pct": occ / 10}, {"districts": [d]})
		was[d] = now
	s["slum"] = was


## Forecast for GovBuilder's housing rule (Wilma): the age pyramid and the last 12 months' flows.
static func forecast(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var units := 0
	var hh := 0
	for d in world.peek("district"):
		units += int(world.peek("district")[d].get("units", 0))
		hh += int(world.peek("district")[d].get("households", 0))
	var sum12 := func(key: String) -> int:
		var t := 0
		for r in s.get(key, []):
			if world.month - int(r[0]) < 12:
				t += int(r[1])
		return t
	var births: int = sum12.call("births_12m")
	var arr: int = sum12.call("arrivals_12m")
	var dep: int = sum12.call("departures_12m")
	var pyr := pyramid(world)
	# households forming: the cohort reaching 20–24 (new adults leave home) plus arriving adults, about 2.5 persons/home
	var forming := int(float(pyr[4]) / 5.0 / 2.5) + int(float(arr) * 0.7 / 2.5)
	return {"pop_by_band": pyr, "births_12m": births, "deaths_12m": sum12.call("deaths_12m"), "arrivals_12m": arr,
		"departures_12m": dep, "households_forming_12m": forming, "housing_units": units / S, "occupancy_pct": int(100.0 * float(hh) / maxf(1.0, float(units))),
		"slums": slums(world), "attractiveness_pct": int(attractiveness(world) * 100.0)}


## A slum: overcrowded (≥ SLUM_OCC) or run-down housing (S3 mean condition < EconHousing.SLUM_COND) with no spare room.
static func _is_slum(world: WorldState, d: String) -> bool:
	var occ := float(world.peek("district")[d].get("occupancy", 1000)) / 1000.0
	if occ >= SLUM_OCC:
		return true
	return not EconUtil.off(world, "S3") and occ >= 1.0 and EconHousing.district_condition(world, d) < EconHousing.SLUM_COND
