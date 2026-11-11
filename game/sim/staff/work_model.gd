extends RefCounted
## Pure work and quality formulas (planning/spec-staff-v1.md §2–§4). Floats inside, callers round to milli-units.

const D := preload("res://sim/staff/staff_data.gd")


static func speed_mult(speed: float) -> float:
	return 0.6 + 0.008 * speed


static func suit_mult(suit: float, talents: Array) -> float:
	var k := clampf(0.4 + 0.012 * suit, 0.4, 1.6)
	if talents.has("ADAPTABLE"):
		k = maxf(k, D.TALENTS["ADAPTABLE"]["k_floor"])
	return k


## Weighted skill for a position; "DOMAIN" resolves to `domain`.
static func suitability(person: Dictionary, weights: Dictionary, domain: String) -> float:
	if weights.is_empty():
		return 50.0
	var s := 0.0
	for k in weights:
		var skill: String = domain if k == "DOMAIN" else k
		s += float(weights[k]) * float(person["skills"].get(skill, 0))
	return s


static func _tag_match(talent_tags: Array, task_tags: Array) -> bool:
	if talent_tags.has("ALL"):
		return true
	for t in talent_tags:
		if task_tags.has(t):
			return true
	return false


## Product of the person's applicable talent multipliers, capped (spec §4).
static func talent_t(talents: Array, task_tags: Array) -> float:
	var t := 1.0
	for id in talents:
		var td: Dictionary = D.TALENTS.get(id, {})
		if td.has("t") and _tag_match(td.get("tags", []), task_tags):
			t *= float(td["t"])
	return minf(t, D.T_CAP)


static func talent_q(talents: Array, task_tags: Array) -> float:
	var q := 0.0
	for id in talents:
		var td: Dictionary = D.TALENTS.get(id, {})
		if td.has("q") and _tag_match(td.get("q_tags", td.get("tags", [])), task_tags):
			q += float(td["q"])
	return q


## Individual monthly contribution W_i in WU (float).
static func individual_w(person: Dictionary, mandatory: bool, suit: float, task_tags: Array, mode: String, align: float) -> float:
	var b := D.B_MANDATORY if mandatory else D.B_OPTIONAL
	return b * speed_mult(float(person["work_speed"])) * suit_mult(suit, person["talents"]) \
		* talent_t(person["talents"], task_tags) * float(D.MODE_W.get(mode, 1.0)) * align


## Member quality q_i 0..100.
static func member_q(person: Dictionary, suit: float, task_tags: Array, mode: String) -> float:
	return clampf(0.7 * suit + 0.3 * float(person["reliability"]) + talent_q(person["talents"], task_tags)
		+ float(D.MODE_Q.get(mode, 0)), 0.0, 100.0)


## Team aggregation. `mandatory_w` / `optional_w` are member W values.
static func team_parallel(mandatory_w: Array, optional_w: Array) -> float:
	var t := 0.0
	for w in mandatory_w:
		t += float(w)
	for w in optional_w:
		t += float(w)
	return t


static func team_coordinated(mandatory_w: Array, optional_w: Array, strong_organizer: bool) -> float:
	var t := 0.0
	if not mandatory_w.is_empty():
		var n := mandatory_w.size()
		var mean := 0.0
		var mn := INF
		for w in mandatory_w:
			mean += float(w)
			mn = minf(mn, float(w))
		mean /= float(n)
		var c := 1.0 - 0.05 * float(maxi(0, n - 2)) + (D.TALENTS["STRONG_ORGANIZER"]["team_c"] if strong_organizer else 0.0)
		t = float(n) * (0.5 * mean + 0.5 * mn) * c
	for w in optional_w:
		t += float(w)
	return t


## Coverage effectiveness e in [0,1] (spec §2.3).
static func effectiveness(coverage: float, quality: float) -> float:
	return clampf(coverage * (0.5 + quality / 200.0), 0.0, 1.0)


## Default consumer mapping: 0.85 unmanaged .. 1.10 best.
static func consumer_multiplier(e: float) -> float:
	return 0.85 + 0.25 * e


static func defect_probability(q: float) -> float:
	return maxf(0.0, (D.DEFECT_Q_PIVOT - q) / D.DEFECT_DIVISOR)


static func poll_moe_pp(q: float) -> float:
	return D.POLL_MOE_BASE + D.POLL_MOE_RANGE * (1.0 - q / 100.0)


static func oversight_find_probability(q: float) -> float:
	return D.OVERSIGHT_BASE + D.OVERSIGHT_RANGE * q / 100.0


static func xp_cost(skill: int) -> float:
	return 5.0 + float(skill * skill) / 200.0
