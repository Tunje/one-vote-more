extends RefCounted
## Life in the colony, rebuild step 3 (planning/rebuild-households.md C1–C10, H18–H21, P16; rebuild-company.md 9.1
## "Life"; Wilma's step-3 joins: "births, deaths, growing up, retiring, the January band moves come in step 3"). Maja.
## How the old side worked, written new; every number here is new and set in testing.
##
## - Each area keeps an age histogram (persons aged 0..99) in table "demo": it is the authority on age; PopStore's
##   leaves keep the coarse age bands. Built from the leaves the first time an area is seen.
## - Deaths by age, worse with hunger (the pool's share of its food need not eaten this month) and with crowding (more
##   households than homes). There are no clinics yet: the schedule is the one without a clinic (C2).
## - Births from women 18 to 42 by an age schedule; fewer with income, hunger and crowding (C3). No clamp of ours.
## - January: everyone a year older; the cohort turning 18 grows up and the cohort reaching the retirement age (the
##   law's lever) retires, both spread over the following twelve months (C5–C7). No schools yet: everyone grows up at
##   the general tier (C6).
## - Adults outside the labour force come back to it at a monthly rate (C9).
## - January, after the ageing: income bands (P16). Each group of people alike in area, band, status and skill has an
##   income per person, averaged over the months; the colony's fifths of that income set the bands; a group past a cut
##   by more than BAND_MARGIN moves. Their children and others outside the labour force follow in proportion, their
##   jobs go with them at their own pay, their savings by head.
## Workers who die, retire or leave give up their posts through Households.end_jobs, so jobs = people holds.
## Every deed writes a Logbook row.
##
## Use: const Demography := preload("res://sim/population/demography.gd")

const Households := preload("res://sim/population/households.gd")
const Company := preload("res://sim/economy/company.gd")

const S := CoreUtil.S
const AGES := 100
const ADULT := 18
const FERT_LO := 18
const FERT_HI := 42

## Yearly death chance by age with no clinic (C2). [upper age (exclusive), chance per mille a year].
const MORTALITY_PM := [[1, 20.0], [5, 3.0], [18, 0.5], [40, 1.2], [55, 4.0], [65, 10.0], [75, 25.0], [85, 65.0], [95, 170.0], [AGES, 350.0]]
## Hunger: a death chance × (1 + this × the share of the pool's food need not eaten), for the young and old / others.
const HUNGER_MORT_FRAIL := 4.0
const HUNGER_MORT_ADULT := 2.0
## Crowding: × (1 + this × (households per home − 1)) when above one household per home.
const CROWD_MORT := 1.0
## Births: a woman's births over a lifetime at the lowest income, fed and housed (C3), and how far the highest income
## band lowers it (× (1 − this) at band I5).
const TFR_BASE := 4.0
const TFR_INCOME_FALL := 0.4
## Growing up: the share of 18-year-olds who look for work (the rest stay outside the labour force for now).
const GROW_LF_PM := 900
## Adults outside the labour force who come back to it, per mille a month (C9).
const REENTRY_PM := 10
## Bands (P16): the income average over months (each month this share of the new figure), and how far past a cut a
## group must be before it moves (‰ of the cut).
const BAND_EMA_PM := 167
const BAND_MARGIN_PM := 100


# ================================================================ state

static func _st(world: WorldState) -> Dictionary:
	var t := world.table("demo")
	if not t.has("hist"):
		t["hist"] = {}
		t["rem"] = {}
		t["pend"] = {}
		t["ema"] = {}
	return t


## The area's age histogram (persons aged 0..99), built from the leaves the first time.
static func histogram(world: WorldState, area: String) -> Array:
	var t := _st(world)
	if not t["hist"].has(area):
		t["hist"][area] = _init_hist(world, area)
	return t["hist"][area]


## From the leaves' age bands: children over 0–17, young adults 18–29, adults 30–49, the middle-aged 50 to the
## retirement age, the old from it to 90 (falling).
static func _init_hist(world: WorldState, area: String) -> Array:
	var ra := retirement_age(world)
	var by := {"C": 0, "Y": 0, "A": 0, "M": 0, "O": 0}
	for k in PopStore.select(world, {"hb": area}):
		var l: Dictionary = world.peek("pop")[k]
		for b in by:
			by[b] = int(by[b]) + int(l["age"].get(b, 0))
	var h: Array = []
	h.resize(AGES)
	h.fill(0)
	_spread(h, int(by["C"]), 0, ADULT - 1, func(_a): return 1.0)
	_spread(h, int(by["Y"]), ADULT, 29, func(_a): return 1.0)
	_spread(h, int(by["A"]), 30, 49, func(_a): return 1.0)
	_spread(h, int(by["M"]), 50, maxi(50, ra - 1), func(_a): return 1.0)
	_spread(h, int(by["O"]), ra, 90, func(a): return exp(-float(a - ra) / 8.0))
	return h


static func _spread(h: Array, n: int, lo: int, hi: int, weight: Callable) -> void:
	if n <= 0 or hi < lo:
		return
	var w: Array = []
	for a in range(lo, hi + 1):
		w.append(maxf(0.0, float(weight.call(a))))
	var parts := CoreUtil.split_lr(n, w)
	for i in parts.size():
		h[lo + i] = int(h[lo + i]) + int(parts[i])


## Whole persons from a flow in persons (float), the remainder carried under `key` (thousandths).
static func _whole(world: WorldState, key: String, x: float) -> int:
	var rem: Dictionary = _st(world)["rem"]
	var v := float(int(rem.get(key, 0))) / 1000.0 + x
	var n := int(floor(v))
	rem[key] = int(round((v - float(n)) * 1000.0))
	return n


## January, but not the landing's own: the colony lands in a January (month 0), and its first year turns in month 12.
## Ageing, the band moves and the yearly raise wait for it, so nothing ages, moves band or is raised on landing day.
static func new_year(world: WorldState) -> bool:
	return world.month_of_year() == 1 and world.month >= 12


static func retirement_age(world: WorldState) -> int:
	return int(CoreUtil.lever(world, "LAW_RETIREMENT_AGE", 62))


static func mortality_pm(a: int) -> float:
	for row in MORTALITY_PM:
		if a < int(row[0]):
			return float(row[1])
	return 350.0


static func fert_shape(a: int) -> float:
	if a < FERT_LO or a > FERT_HI:
		return 0.0
	var w := 1.0 - absf(float(a) - 26.0) / 17.0
	return maxf(0.05, w) / 15.8


# ================================================================ the month (population provider, SOCIAL)

static func monthly(world: WorldState) -> void:
	for a in AreaStore.areas(world):
		var area := String(a["id"])
		if PopStore.count(world, {"hb": area}) <= 0:
			continue
		var h := histogram(world, area)
		_deaths(world, area, h)
		_births(world, area, h)
		if new_year(world):
			_age_year(world, area, h)
		_pending(world, area, h)
		_reentry(world, area)
	_track_income(world)
	if new_year(world):
		band_moves(world)
	Households.reconcile_families(world)


## Status groups: who a death in each age group falls on.
const _GROUPS := {"c": ["CHILD"], "w": ["NOT_IN_LF", "UNEMPLOYED", "EMPLOYED"], "o": ["RETIRED"]}


static func _deaths(world: WorldState, area: String, h: Array) -> void:
	var ra := retirement_age(world)
	var ex := {"c": 0.0, "w": 0.0, "o": 0.0}
	var exa := {"c": [], "w": [], "o": []}   # expected deaths by age, for taking them off the histogram
	for a in AGES:
		var g := "c" if a < ADULT else ("o" if a >= ra else "w")
		var e := float(h[a]) * mortality_pm(a) / 1000.0 / 12.0
		ex[g] = float(ex[g]) + e
		exa[g].append([a, e])
	var crowd := 1.0 + CROWD_MORT * maxf(0.0, float(Households.homes(world, area)["occupancy_pm"]) / 1000.0 - 1.0)
	var totals := {"c": 0, "w": 0, "o": 0}
	# one remainder per area and age group (per pool, the fractions of a small colony never reach one person); the
	# whole deaths are then shared over the pools by their expected deaths, hunger included
	for g in ["c", "w", "o"]:
		var area_n := 0
		for st in _GROUPS[g]:
			area_n += PopStore.count(world, {"hb": area, "status": st})
		if area_n <= 0:
			continue
		var pids: Array = []
		var exp_p: Array = []
		var size_p: Array = []
		var hm_p: Array = []
		var sum := 0.0
		for pid in Households.pools(world):
			if String(world.peek("pool")[pid]["area"]) != area:
				continue
			var n := 0
			for st in _GROUPS[g]:
				n += Households.persons(world, pid, st)
			if n <= 0:
				continue
			var hungry := 1.0 - float(Households.fed_pm(world, pid)) / 1000.0
			var hm := 1.0 + (HUNGER_MORT_ADULT if g == "w" else HUNGER_MORT_FRAIL) * hungry
			var e := float(ex[g]) * float(n) / float(area_n) * hm * crowd
			pids.append(pid)
			exp_p.append(e)
			size_p.append(n)
			hm_p.append(hm)
			sum += e
		var d_all := _whole(world, "death|%s|%s" % [area, g], sum)
		if d_all <= 0:
			continue
		var parts := CoreUtil.split_lr(d_all, exp_p)
		for i in pids.size():
			var d := mini(int(parts[i]), int(size_p[i]))
			if d <= 0:
				continue
			var band := String(world.peek("pool")[pids[i]]["band"])
			var died := _kill(world, area, band, g, d)
			totals[g] = int(totals[g]) + died
			Logbook.note(world, "DEATH", String(pids[i]), "deaths", {"group": g, "expected": snappedf(float(exp_p[i]), 0.001),
				"hunger_x": snappedf(float(hm_p[i]), 0.01), "crowding_x": snappedf(crowd, 0.01)}, {"persons": [int(size_p[i]), int(size_p[i]) - died]})
	# off the histogram, by age within each group in proportion to the expected deaths
	for g in totals:
		if int(totals[g]) <= 0:
			continue
		var parts := CoreUtil.split_lr(int(totals[g]), (exa[g] as Array).map(func(r): return float(r[1])))
		for i in parts.size():
			var age: int = exa[g][i][0]
			h[age] = maxi(0, int(h[age]) - int(parts[i]))


## n deaths in pool (area, band) among the statuses of group g. Workers give up their posts first through end_jobs.
static func _kill(world: WorldState, area: String, band: String, g: String, n: int) -> int:
	var sts: Array = _GROUPS[g]
	var w: Array = sts.map(func(st): return PopStore.count(world, {"hb": area, "inc": band, "status": st}))
	var parts := CoreUtil.split_lr(n, w)
	var done := 0
	for i in sts.size():
		var k := int(parts[i])
		if k <= 0:
			continue
		if String(sts[i]) == "EMPLOYED":
			# a family working its own company is employed on no payroll (15e): its share dies from its own people
			var all_e := PopStore.count(world, {"hb": area, "inc": band, "status": "EMPLOYED"})
			var fam_e := PopStore.count(world, {"hb": area, "inc": band, "status": "EMPLOYED", "occ": "BUSINESS_OWNER"})
			var kf: int = CoreUtil.split_lr(k, [all_e - fam_e, fam_e])[1] if all_e > 0 else 0
			done += Households.end_jobs(world, area, band, k - kf, "DEATH")
			if kf > 0:
				done += _die_from(world, {"hb": area, "inc": band, "status": "EMPLOYED", "occ": "BUSINESS_OWNER"}, kf)
		else:
			done += _die_from(world, {"hb": area, "inc": band, "status": sts[i]}, k)
	return done


static func _die_from(world: WorldState, filter: Dictionary, n: int) -> int:
	var keys := PopStore.select(world, filter)
	var parts := PopStore.split_over(n, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
	var done := 0
	for k in CoreUtil.sorted_keys(parts):
		PopStore.death(world, k, int(parts[k]))
		done += int(parts[k])
	return done


## Births in the area (C3, C4): into the pools by their working-age adults, each pool's TFR from its band and hunger.
static func _births(world: WorldState, area: String, h: Array) -> void:
	var mothers := 0.0
	for a in range(FERT_LO, FERT_HI + 1):
		mothers += float(h[a]) * 0.5 * fert_shape(a)
	if mothers <= 0.0:
		return
	var adults_area := 0
	for st in _GROUPS["w"]:
		adults_area += PopStore.count(world, {"hb": area, "status": st})
	if adults_area <= 0:
		return
	var occ := float(Households.homes(world, area)["occupancy_pm"]) / 1000.0
	var crowd_f := 1.0 / (1.0 + maxf(0.0, occ - 1.0))
	var born := 0
	var pids: Array = []
	var exp_p: Array = []
	var tfr_p: Array = []
	var fed_p: Array = []
	var sum := 0.0
	for pid in Households.pools(world):
		var p: Dictionary = world.peek("pool")[pid]
		if String(p["area"]) != area:
			continue
		var n := 0
		for st in _GROUPS["w"]:
			n += Households.persons(world, pid, st)
		if n <= 0:
			continue
		var rank := float(Households.BANDS.find(String(p["band"]))) / float(Households.BANDS.size() - 1)
		var fed := float(Households.fed_pm(world, pid)) / 1000.0
		var tfr := TFR_BASE * (1.0 - TFR_INCOME_FALL * rank) * fed * crowd_f
		var e := mothers * float(n) / float(adults_area) * tfr / 12.0
		pids.append(pid)
		exp_p.append(e)
		tfr_p.append(tfr)
		fed_p.append(fed)
		sum += e
	var b_all := _whole(world, "birth|" + area, sum)
	if b_all > 0:
		var parts := CoreUtil.split_lr(b_all, exp_p)
		for i in pids.size():
			var b := int(parts[i])
			if b <= 0:
				continue
			var p2: Dictionary = world.peek("pool")[pids[i]]
			var ck := PopStore.key_of({"hb": area, "inc": String(p2["band"]), "occ": "NONE", "status": "CHILD", "arch": Households.ARCH, "eff": "e0"})
			PopStore.birth(world, ck, b)
			born += b
			Logbook.note(world, "BIRTH", String(pids[i]), "births", {"tfr": snappedf(float(tfr_p[i]), 0.01), "fed": snappedf(float(fed_p[i]), 0.001)}, {"births": [0, b]})
	h[0] = int(h[0]) + born


## January: everyone a year older; the cohorts turning 18 and reaching the retirement age queue their moves.
static func _age_year(world: WorldState, area: String, h: Array) -> void:
	var ra := retirement_age(world)
	var turning := int(h[ADULT - 1])
	var retiring := int(h[ra - 1])
	var top := int(h[AGES - 1]) + int(h[AGES - 2])
	for a in range(AGES - 2, 0, -1):
		h[a] = h[a - 1]
	h[0] = 0
	h[AGES - 1] = top
	var pend: Dictionary = _st(world)["pend"].get(area, {"grow": 0, "retire": 0})
	pend["grow"] = int(pend.get("grow", 0)) + turning
	pend["retire"] = int(pend.get("retire", 0)) + retiring
	pend["grow_q"] = int(pend["grow"]) / 12 + 1
	pend["retire_q"] = int(pend["retire"]) / 12 + 1
	_st(world)["pend"][area] = pend
	Logbook.note(world, "AGE", area, "a year older", {"turning_18": turning, "reaching_retirement": retiring, "retirement_age": ra}, {})


## The queued cohort moves, a twelfth a month: growing up (children -> the labour force or outside it, general
## tier: no schools yet) and retiring (outside the labour force, the unemployed, then the employed, in proportion).
static func _pending(world: WorldState, area: String, h: Array) -> void:
	var pend: Dictionary = _st(world)["pend"].get(area, {})
	if pend.is_empty():
		return
	var g_n := mini(int(pend.get("grow", 0)), int(pend.get("grow_q", 0)))
	if g_n > 0:
		var pids: Array = Households.pools(world).filter(func(p): return String(world.peek("pool")[p]["area"]) == area)
		var parts := CoreUtil.split_lr(g_n, pids.map(func(p): return Households.persons(world, p, "CHILD")))
		var done := 0
		for i in pids.size():
			var k := mini(int(parts[i]), Households.persons(world, pids[i], "CHILD"))
			if k <= 0:
				continue
			var band := String(world.peek("pool")[pids[i]]["band"])
			var lf := k * GROW_LF_PM / 1000
			_grow_up(world, area, band, "UNEMPLOYED", lf)
			_grow_up(world, area, band, "NOT_IN_LF", k - lf)
			done += k
		pend["grow"] = maxi(0, int(pend["grow"]) - maxi(done, g_n))
		if done > 0:
			Logbook.note(world, "GROW", area, "grew up", {"general_tier": true}, {"adults": [0, done]})
	var r_n := mini(int(pend.get("retire", 0)), int(pend.get("retire_q", 0)))
	if r_n > 0:
		var w: Array = [PopStore.count(world, {"hb": area, "status": "NOT_IN_LF", "occ": "NONE"}),
			PopStore.count(world, {"hb": area, "status": "UNEMPLOYED"}), PopStore.count(world, {"hb": area, "status": "EMPLOYED"})]
		var parts2 := CoreUtil.split_lr(r_n, w)
		var m := 0
		m += _retire_status(world, area, "NOT_IN_LF", int(parts2[0]))
		m += _retire_status(world, area, "UNEMPLOYED", int(parts2[1]))
		m += _retire_employed(world, area, int(parts2[2]))
		pend["retire"] = maxi(0, int(pend["retire"]) - maxi(m, r_n))
		if m > 0:
			Logbook.note(world, "RETIRE", area, "retired", {"retirement_age": retirement_age(world)}, {"retired": [0, m]})
	_st(world)["pend"][area] = pend


static func _grow_up(world: WorldState, area: String, band: String, status: String, n: int) -> void:
	if n <= 0:
		return
	var keys := PopStore.select(world, {"hb": area, "inc": band, "status": "CHILD"})
	var parts := PopStore.split_over(n, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
	for k in CoreUtil.sorted_keys(parts):
		var dst := PopStore.relabel(k, {"status": status, "occ": "NONE"})
		PopStore.transfer(world, k, dst, int(parts[k]), "GROW_UP", {"age": "C"})
		_recompose(world, dst, "age", "C", "Y", int(parts[k]))


## Outside the labour force or unemployed -> retired (occupation kept; age band O). Owners (BUSINESS_OWNER) are left
## alone: an owner retires when they give up what they own.
static func _retire_status(world: WorldState, area: String, status: String, n: int) -> int:
	if n <= 0:
		return 0
	var f := {"hb": area, "status": status}
	if status == "NOT_IN_LF":
		f["occ"] = "NONE"   # owners counted one by one are NOT_IN_LF with occupation BUSINESS_OWNER: not retired here
	var keys := PopStore.select(world, f)
	var parts := PopStore.split_over(n, keys, keys.map(func(k): return float(world.peek("pop")[k]["n"])))
	var done := 0
	for k in CoreUtil.sorted_keys(parts):
		var dst := PopStore.relabel(k, {"status": "RETIRED"})
		PopStore.transfer(world, k, dst, int(parts[k]), "RETIRE")
		_reage(world, dst, int(parts[k]))
		done += int(parts[k])
	return done


static func _retire_employed(world: WorldState, area: String, n: int) -> int:
	if n <= 0:
		return 0
	var bands: Array = Households.BANDS
	var w: Array = bands.map(func(b): return PopStore.count(world, {"hb": area, "inc": b, "status": "EMPLOYED"}))
	var parts := CoreUtil.split_lr(n, w)
	var done := 0
	for i in bands.size():
		done += Households.end_jobs(world, area, String(bands[i]), int(parts[i]), "RETIRE")
	return done


static func _reage(world: WorldState, key: String, n: int) -> void:
	var left := n
	for b in ["M", "A", "Y"]:
		if left <= 0:
			return
		left -= _recompose(world, key, "age", b, "O", left)


static func _recompose(world: WorldState, key: String, field: String, from_b: String, to_b: String, n: int) -> int:
	if n <= 0 or from_b == to_b or not world.peek("pop").has(key):
		return 0
	var c: Dictionary = world.table("pop")[key][field]
	var k := mini(n, int(c.get(from_b, 0)))
	c[from_b] = int(c.get(from_b, 0)) - k
	c[to_b] = int(c.get(to_b, 0)) + k
	return k


## Adults outside the labour force come back to it (C9).
static func _reentry(world: WorldState, area: String) -> void:
	var total := 0
	for band in Households.BANDS:
		var f := {"hb": area, "inc": band, "status": "NOT_IN_LF", "occ": "NONE"}
		var n := PopStore.count(world, f)
		if n <= 0:
			continue
		var k := _whole(world, "reentry|%s|%s" % [area, band], float(n) * float(REENTRY_PM) / 1000.0)
		if k > 0:
			total += PopStore.move_group(world, f, k, {"status": "UNEMPLOYED"}, "REENTRY")
	if total > 0:
		Logbook.note(world, "REENTRY", area, "back into the labour force", {"rate_pm": REENTRY_PM}, {"looking": [0, total]})


# ================================================================ income bands (P16)

## Monthly income per person of each group (area|band|status|skill), from wages (the staff entries' pay), the benefit
## and pensions (the pool's income this month ÷ its people of that status); averaged over months in "ema".
static func _track_income(world: WorldState) -> void:
	var ema: Dictionary = _st(world)["ema"]
	var now := {}
	for cid in Company.ids(world):
		for e in Company.payroll(world, cid):
			var lk := String(e["labour_key"])
			var lp := Households.labour_parts(lk)
			var gk := "%s|%s|EMPLOYED|%s" % [lp[0], lp[1], lp[2]]
			var acc: Array = now.get(gk, [0, 0])
			acc[0] = int(acc[0]) + int(e["n"]) * int(e["pay"]) / S
			acc[1] = int(acc[1]) + int(e["n"]) / S
			now[gk] = acc
	for pid in Households.pools(world):
		var p: Dictionary = world.peek("pool")[pid]
		var inc := Households.income(world, pid)
		for pair in [["UNEMPLOYED", "benefit"], ["RETIRED", "pension"]]:
			for sk in Households.TIERS:
				var n := PopStore.count(world, {"hb": String(p["area"]), "inc": String(p["band"]), "status": pair[0]}, "skill:" + sk)
				if n <= 0:
					continue
				var all := Households.persons(world, pid, pair[0])
				var amt := int(inc.get(pair[1], 0)) * n / maxi(1, all)
				now["%s|%s|%s|%s" % [p["area"], p["band"], pair[0], sk]] = [amt, n]
	for gk in now:
		var acc: Array = now[gk]
		if int(acc[1]) <= 0:
			continue
		var x := float(acc[0]) / float(acc[1])
		# kept as an int in thousandths of a milli-credit: a float does not come back from a save exactly (the game must
		# continue the same), and in thousandths a month's step is never rounded away (Terra's review)
		var x_k := int(round(x * 1000.0))
		ema[gk] = x_k if not ema.has(gk) else int(ema[gk]) + (x_k - int(ema[gk])) * BAND_EMA_PM / 1000


## January: the colony's fifths of income per person set the bands; a group past a cut by more than the margin moves,
## with its dependants, its jobs (at their own pay) and its savings.
static func band_moves(world: WorldState) -> int:
	var ema: Dictionary = _st(world)["ema"]
	var rows: Array = []   # [group key, income, persons]
	for gk in CoreUtil.sorted_keys(ema):
		var gp := String(gk).split("|")
		var n := PopStore.count(world, {"hb": gp[0], "inc": gp[1], "status": gp[2]}, "skill:" + gp[3])
		if n > 0:
			rows.append([gk, float(ema[gk]) / 1000.0, n])
	if rows.size() < 2:
		return 0
	var cuts := _quantiles(rows.map(func(r): return [r[1], r[2]]), [0.2, 0.4, 0.6, 0.8])
	var moved := 0
	for r in rows:
		var gp := String(r[0]).split("|")
		var b := Households.BANDS.find(gp[1])
		var t := _band_index(float(r[1]), cuts)
		if t > b and float(r[1]) <= float(cuts[b]) * (1.0 + float(BAND_MARGIN_PM) / 1000.0):
			t = b
		elif t < b and float(r[1]) >= float(cuts[b - 1]) * (1.0 - float(BAND_MARGIN_PM) / 1000.0):
			t = b
		if t == b:
			continue
		moved += _move_group(world, gp[0], gp[1], Households.BANDS[t], gp[2], gp[3], float(r[1]), cuts)
		ema["%s|%s|%s|%s" % [gp[0], Households.BANDS[t], gp[2], gp[3]]] = int(round(float(r[1]) * 1000.0))
		ema.erase(r[0])
	return moved


static func _move_group(world: WorldState, area: String, from_band: String, to_band: String, status: String, skill: String, income: float, cuts: Array) -> int:
	var src := Households.pool_id(area, from_band)
	var dst := Households.ensure_pool(world, area, to_band)
	var size0 := Households.persons(world, src)
	var earners0 := 0
	for st in ["EMPLOYED", "UNEMPLOYED", "RETIRED"]:
		earners0 += Households.persons(world, src, st)
	var bal0 := world.ledger.balance(Households.account(src))
	var f := {"hb": area, "inc": from_band, "status": status}
	# owners' households (BUSINESS_OWNER) keep the band their founder's record holds: they do not move here
	var n := PopStore.count(world, f, "skill:" + skill) - PopStore.count(world, f.merged({"occ": "BUSINESS_OWNER"}), "skill:" + skill)
	if n <= 0:
		return 0
	if status == "EMPLOYED":
		Households.move_jobs_band(world, area, from_band, to_band, skill)
	var k := 0
	for occ in PopStore.OCCUPATIONS:
		if occ != "BUSINESS_OWNER":
			var fo := f.merged({"occ": occ})
			k += PopStore.move_group(world, fo, PopStore.count(world, fo, "skill:" + skill), {"inc": to_band}, "INCOME_BAND", "skill:" + skill)
	# dependants follow in proportion to the earners who moved
	var dep := 0
	for st in ["CHILD", "NOT_IN_LF"]:
		var dn := PopStore.count(world, {"hb": area, "inc": from_band, "status": st, "occ": "NONE"})
		var take := mini(dn, int(round(float(dn) * float(k) / float(maxi(1, earners0)))))
		if take > 0:
			dep += PopStore.move_group(world, {"hb": area, "inc": from_band, "status": st, "occ": "NONE"}, take, {"inc": to_band}, "INCOME_BAND")
	var amt := mini(world.ledger.balance(Households.account(src)), int(float(bal0) * float(k + dep) / float(maxi(1, size0))))
	if amt > 0:
		world.ledger.transfer(Households.account(src), Households.account(dst), amt, "BAND_MOVE", world.month)
	Logbook.note(world, "BAND", src, "moved to " + to_band, {"status": status, "skill": skill, "income": int(income),
		"cuts": cuts.map(func(c): return int(c))}, {"persons": [0, k + dep], "savings": [0, amt]}, dst)
	return k + dep


static func _band_index(v: float, cuts: Array) -> int:
	var i := 0
	while i < cuts.size() and v > float(cuts[i]):
		i += 1
	return i


static func _quantiles(rows: Array, qs: Array) -> Array:
	var r := rows.duplicate()
	r.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var tot := 0.0
	for x in r:
		tot += float(x[1])
	var out: Array = []
	for q in qs:
		var target := float(q) * tot
		var cum := 0.0
		var v: float = float(r[-1][0])
		for x in r:
			cum += float(x[1])
			if cum >= target:
				v = float(x[0])
				break
		out.append(v)
	return out


## Settlers landed by a ship: their ages into the area's histogram (adults 18 to 39, children 0 to 11, as the
## founding mix: three quarters working-age, a fifth children, the rest old).
static func add_arrivals(world: WorldState, area: String, n: int) -> void:
	var h := histogram(world, area)
	var parts := CoreUtil.split_lr(n, [Households.BAND_WORKING, Households.BAND_CHILDREN, Households.BAND_RETIRED])
	var ra := retirement_age(world)
	_spread(h, int(parts[0]), ADULT, 39, func(_a): return 1.0)
	_spread(h, int(parts[1]), 0, 11, func(_a): return 1.0)
	_spread(h, int(parts[2]), ra, ra + 9, func(_a): return 1.0)


## People who left on a ship: off the area's histogram, from the working ages in proportion.
static func remove_departures(world: WorldState, area: String, n: int) -> void:
	var h := histogram(world, area)
	var w: Array = []
	for a in range(ADULT, 60):
		w.append(float(h[a]))
	var parts := CoreUtil.split_lr(n, w)
	for i in parts.size():
		h[ADULT + i] = maxi(0, int(h[ADULT + i]) - int(parts[i]))


## AreaStore's change listener (rebuild-households.md C1): when people move between areas (a split or a merge), their
## ages go with them, in proportion over each age; a merged-away area's remainders and queued moves fold into the
## survivor. Registered by the population provider.
static func on_area_moves(world: WorldState, moves: Array) -> void:
	var by_pair := {}
	for m in moves:
		var k := "%s>%s" % [m["from"], m["to"]]
		by_pair[k] = int(by_pair.get(k, 0)) + int(m["persons"])
	for k in CoreUtil.sorted_keys(by_pair):
		var from_a := String(k).get_slice(">", 0)
		var to_a := String(k).get_slice(">", 1)
		var hf := histogram(world, from_a)
		# a new area gets its ages only from the people moving in: built from its leaves it would count them twice
		var t := _st(world)
		if not t["hist"].has(to_a):
			var z: Array = []
			z.resize(AGES)
			z.fill(0)
			t["hist"][to_a] = z
		var ht: Array = t["hist"][to_a]
		var parts := CoreUtil.split_lr(int(by_pair[k]), hf.map(func(x): return float(x)))
		for a in AGES:
			var n := mini(int(parts[a]), int(hf[a]))
			hf[a] = int(hf[a]) - n
			ht[a] = int(ht[a]) + n
		if String(AreaStore.get_area(world, from_a).get("status", "")) == "MERGED":
			_fold(world, from_a, to_a)
	Households.on_area_moves(world, moves)


static func _fold(world: WorldState, from_a: String, to_a: String) -> void:
	var t := _st(world)
	var pend: Dictionary = t["pend"]
	if pend.has(from_a):
		var into: Dictionary = pend.get(to_a, {"grow": 0, "retire": 0})
		for f in ["grow", "retire", "grow_q", "retire_q"]:
			into[f] = int(into.get(f, 0)) + int(pend[from_a].get(f, 0))
		pend[to_a] = into
		pend.erase(from_a)
	t["hist"].erase(from_a)
	var rem: Dictionary = t["rem"]
	for k in CoreUtil.sorted_keys(rem):
		# the area is one whole part of the key: "hb:1" must not match inside "hb:12" (Terra's review)
		var parts := String(k).split("|")
		if not parts.has(from_a):
			continue
		for i in parts.size():
			if parts[i] == from_a:
				parts[i] = to_a
		var nk := "|".join(parts)
		rem[nk] = int(rem.get(nk, 0)) + int(rem[k])
		rem.erase(k)


## The colony's age pyramid in 5-year bands (persons).
static func pyramid(world: WorldState) -> Array:
	var out: Array = []
	out.resize(AGES / 5)
	out.fill(0)
	for area in CoreUtil.sorted_keys(_st(world)["hist"]):
		var h: Array = _st(world)["hist"][area]
		for a in AGES:
			out[a / 5] = int(out[a / 5]) + int(h[a])
	return out
