extends RefCounted
## Person generation, founding-roster validator and benches (spec-staff §5).
## All functions take an explicit RandomNumberGenerator (a world stream), so results are reproducible.

const D := preload("res://sim/staff/staff_data.gd")
const Q := preload("res://sim/staff/qualification.gd")

const FIRST := ["Ada", "Bror", "Cecilia", "Dag", "Edith", "Folke", "Greta", "Hugo", "Ingrid", "Jonas", "Karin",
	"Lars", "Maja", "Nils", "Olga", "Per", "Ronja", "Sten", "Tove", "Ulf", "Vera", "Wilhelm", "Ylva", "Arvid",
	"Signe", "Elof", "Hedda", "Ivar", "Liv", "Malte"]
const LAST := ["Alm", "Berg", "Dahl", "Ek", "Falk", "Holm", "Lind", "Lund", "Nord", "Ros", "Sand", "Sjö",
	"Strand", "Vik", "Wall", "Hagen", "Moberg", "Ekdahl", "Lindqvist", "Norén", "Asp", "Brink", "Kvist", "Ström"]


static func _r(rng: RandomNumberGenerator, range_pair: Array) -> int:
	return rng.randi_range(int(range_pair[0]), int(range_pair[1]))


## One generated person (no id yet). kind = "CIVIL" | "POLITICAL".
static func make_person(rng: RandomNumberGenerator, kind: String, primary: String, secondaries: Array,
		forced_talent: String, month: int) -> Dictionary:
	var g: Dictionary = D.GEN[kind]
	var skills := {}
	for s in D.SKILLS:
		if s == primary:
			skills[s] = _r(rng, g["primary"])
		elif secondaries.has(s):
			skills[s] = _r(rng, g["secondary"])
		else:
			skills[s] = _r(rng, g["other"])
	var age := _r(rng, g["age"])
	var talents: Array = []
	if forced_talent != "":
		talents.append(forced_talent)
	var roll := rng.randf()
	var n := 0
	while n < D.TALENT_COUNT_CDF.size() and roll > float(D.TALENT_COUNT_CDF[n]):
		n += 1
	var guard := 0
	while talents.size() < n and guard < 50:
		guard += 1
		var t: String = D.TALENT_ORDER[rng.randi_range(0, D.TALENT_ORDER.size() - 1)]
		if talents.has(t):
			continue
		if D.TALENTS[t].get("civil_only", false) and kind != "CIVIL":
			continue
		talents.append(t)
	return {
		"name": "%s %s" % [FIRST[rng.randi_range(0, FIRST.size() - 1)], LAST[rng.randi_range(0, LAST.size() - 1)]],
		"birth_month": month - age * 12 - rng.randi_range(0, 11),
		"party_id": "",
		"roles": ["CIVIL_SERVANT"] if kind == "CIVIL" else ["GOV_POLITICAL"],
		"skills": skills,
		"talents": talents,
		"work_speed": _r(rng, g["speed"]),
		"reliability": _r(rng, g["reliability"]),
		"integrity": _r(rng, g["integrity"]),
		"xp": {},
		"status": "ACTIVE",
		"unavailable_until": -1,
		"pool": "",
		"bench_party_id": "",
		"assignment_id": "",
		"specialization": primary,
		"career": [],
	}


static func make_civil(rng: RandomNumberGenerator, template: Dictionary, month: int) -> Dictionary:
	var p := make_person(rng, "CIVIL", template["primary"], template["secondary"], template.get("talent", ""), month)
	p["specialization"] = template["spec"]
	return p


static func make_archetype(rng: RandomNumberGenerator, arch: String, month: int, flavour_skill: String = "") -> Dictionary:
	var a: Dictionary = D.ARCHETYPES[arch]
	var primary: String = a["primary"]
	var secondaries: Array = a["secondary"].duplicate()
	if arch == "SECTOR":
		primary = flavour_skill if D.SECTOR_PRIMARIES.has(flavour_skill) \
			else D.SECTOR_PRIMARIES[rng.randi_range(0, D.SECTOR_PRIMARIES.size() - 1)]
	elif arch == "MANAGER":
		secondaries.append(D.MANAGER_SECONDARY[rng.randi_range(0, D.MANAGER_SECONDARY.size() - 1)])
	var p := make_person(rng, "POLITICAL", primary, secondaries, "", month)
	if flavour_skill != "" and flavour_skill == primary:
		p["skills"][primary] = mini(100, int(p["skills"][primary]) + 5)
	p["specialization"] = arch
	return p


static func civil_template(spec: String) -> Dictionary:
	for t in D.CIVIL_TEMPLATES:
		if t["spec"] == spec:
			return t
	return D.CIVIL_TEMPLATES[0]


## Founding roster: 10 civil servants + 16 political candidates (first 10 = recommended appointees).
static func generate_founding_raw(rng: RandomNumberGenerator, month: int) -> Dictionary:
	var civil: Array = []
	for t in D.CIVIL_TEMPLATES:
		civil.append(make_civil(rng, t, month))
	var cands: Array = []
	for arch in D.FOUNDING_ARCHETYPES:
		cands.append(make_archetype(rng, arch, month))
	var keys: Array = D.ARCHETYPES.keys()
	while cands.size() < D.FOUNDING_CANDIDATES:
		cands.append(make_archetype(rng, keys[rng.randi_range(0, keys.size() - 1)], month))
	return {"civil": civil, "candidates": cands}


## Mandatory positions of a slate as matching slots: [{position, domain, def}].
static func slate_slots(slate: Array) -> Array:
	var slots: Array = []
	for entry in slate:
		var def: Dictionary = D.TASKS[entry["def"]]
		var params: Dictionary = entry["params"]
		for pi in Q.active_positions(def, params):
			var pos: Dictionary = def["positions"][pi]
			if pos["mandatory"]:
				slots.append({"position": pos, "domain": Q.domain_of(params), "def": def})
	return slots


## Maximum bipartite matching (Kuhn). Returns slot index -> person index (-1 if unmatched).
static func match_slots(slots: Array, people: Array) -> Array:
	var adj: Array = []
	for s in slots:
		var row: Array = []
		for j in people.size():
			if Q.neutrality_ok(people[j], s["def"]) and Q.path_index(people[j], s["position"], s["domain"]) >= 0:
				row.append(j)
		adj.append(row)
	var owner_of: Array = []
	owner_of.resize(people.size())
	owner_of.fill(-1)
	for i in slots.size():
		var seen: Array = []
		seen.resize(people.size())
		seen.fill(false)
		_augment(i, adj, owner_of, seen)
	var result: Array = []
	result.resize(slots.size())
	result.fill(-1)
	for j in people.size():
		if owner_of[j] >= 0:
			result[owner_of[j]] = j
	return result


static func _augment(i: int, adj: Array, owner_of: Array, seen: Array) -> bool:
	for j in adj[i]:
		if seen[j]:
			continue
		seen[j] = true
		if owner_of[j] < 0 or _augment(owner_of[j], adj, owner_of, seen):
			owner_of[j] = i
			return true
	return false


static func slate_staffable(people: Array, slate: Array) -> bool:
	return not match_slots(slate_slots(slate), people).has(-1)


## Generates until the founding slate is staffable (<= 50 retries), then falls back to raising skills.
## Returns {civil, candidates, retries, fallback}.
static func generate_founding(rng: RandomNumberGenerator, month: int, slate: Array = D.FOUNDING_SLATE) -> Dictionary:
	var r: Dictionary = {}
	for attempt in D.VALIDATOR_MAX_RETRIES + 1:
		r = generate_founding_raw(rng, month)
		var people: Array = r["civil"] + r["candidates"].slice(0, D.POLITICAL_SEATS)
		if slate_staffable(people, slate):
			r["retries"] = attempt
			r["fallback"] = false
			return r
	# Fallback: raise the closest unused person to the first path's minimums for each unmatched slot.
	var people2: Array = r["civil"] + r["candidates"].slice(0, D.POLITICAL_SEATS)
	var slots := slate_slots(slate)
	var m := match_slots(slots, people2)
	var used := {}
	for j in m:
		if j >= 0:
			used[j] = true
	for i in slots.size():
		if m[i] >= 0:
			continue
		var mins: Dictionary = slots[i]["position"]["paths"][0].get("min", {})
		var best := -1
		var best_score := -1
		for j in people2.size():
			if used.has(j) or not Q.neutrality_ok(people2[j], slots[i]["def"]):
				continue
			var sc := 0
			for k in mins:
				sc += int(people2[j]["skills"].get(slots[i]["domain"] if k == "DOMAIN" else k, 0))
			if sc > best_score:
				best_score = sc
				best = j
		if best >= 0:
			used[best] = true
			for k in mins:
				var sk: String = slots[i]["domain"] if k == "DOMAIN" else k
				people2[best]["skills"][sk] = maxi(int(people2[best]["skills"][sk]), int(mins[k]))
	r["retries"] = D.VALIDATOR_MAX_RETRIES
	r["fallback"] = true
	return r


## Party bench of n political people; guarantees LAW/NEGO/COMM >= 50 (spec §5.3).
static func generate_bench(rng: RandomNumberGenerator, n: int, month: int, flavour_skill: String = "", offset: int = 0) -> Array:
	var out: Array = []
	for i in n:
		out.append(make_archetype(rng, D.BENCH_ARCHETYPES[(i + offset) % D.BENCH_ARCHETYPES.size()], month, flavour_skill))
	return out


## Raise the best person in `people` to the bench minimums if nobody meets one.
static func enforce_bench_minimums(people: Array) -> void:
	for skill in D.BENCH_REQUIRED:
		var need: int = D.BENCH_REQUIRED[skill]
		var best: Dictionary = {}
		var ok := false
		for p in people:
			if int(p["skills"][skill]) >= need:
				ok = true
				break
			if best.is_empty() or int(p["skills"][skill]) > int(best["skills"][skill]):
				best = p
		if not ok and not best.is_empty():
			best["skills"][skill] = need
