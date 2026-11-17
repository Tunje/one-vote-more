class_name PopStore
extends RefCounted
## M10 population store (population.md, planning/spec-population-v1.md §2, §13).
## Every resident belongs to exactly one LEAF: a group of identical people keyed
##   hb | inc | occ | status | arch | eff      e.g. "hb:d:1|I2|MINING|UNEMPLOYED|LABOR|e0"
## Leaves are the only stored population; housing/income/work/philosophy blocks are derived (PopQuery).
## All changes go through this API so that population is conserved (PD §2):
##   - transfer / move_group: people change category; their beliefs and composition travel with them
##   - birth / death / arrive / depart: the only sources and sinks
## Counts are int persons. Stateless; state lives in world tables "pop", "pop_flow" and values["pop_*"].

const KEY_PARTS := ["hb", "inc", "occ", "status", "arch", "eff"]
const INCOME_BANDS := ["I1", "I2", "I3", "I4", "I5"]
const OCCUPATIONS := ["MINING", "CONSTRUCTION", "MANUFACTURING", "AGRICULTURE", "LOGISTICS", "SERVICES",
	"PROFESSIONAL", "PUBLIC_SECTOR", "BUSINESS_OWNER", "NONE"]
const STATUSES := ["EMPLOYED", "UNEMPLOYED", "STUDENT", "RETIRED", "NOT_IN_LF", "CHILD"]
const AGE_BANDS := ["C", "Y", "A", "M", "O"]          # 0-17, 18-29, 30-49, 50-64, 65+
const SKILLS := ["G", "S", "Sp"]
## Composition fields: int counts that split with the people who move. "age" and "skill" sum to n.
const COMP_FIELDS := ["age", "skill"]
## Fields that are NOT beliefs (never mixed on transfer).
const NON_STATE := ["key", "n", "age", "skill", "recent", "hb", "inc", "occ", "status", "arch", "eff", "exposure",
	"district", "area", "vocc", "band", "cohort", "census_key", "pop",  # voter fields derived monthly (PolVoters)
	"diet", "news_blame", "news_agenda"]  # media (Anni, spec-media-v1 §7.6): derived monthly; trust and news_bias DO mix
const FLOW_KEEP_MONTHS := 24


# ======================================================================= keys

static func key_of(parts: Dictionary) -> String:
	var a: Array = []
	for p in KEY_PARTS:
		a.append(String(parts.get(p, "e0" if p == "eff" else "")))
	return "|".join(a)


static func parts_of(key: String) -> Dictionary:
	var s := key.split("|")
	var out := {}
	for i in KEY_PARTS.size():
		out[KEY_PARTS[i]] = s[i] if i < s.size() else ""
	return out


## Key with some parts replaced. change: {"status": "UNEMPLOYED", ...}
static func relabel(key: String, change: Dictionary) -> String:
	var p := parts_of(key)
	for k in change:
		p[k] = change[k]
	return key_of(p)


# ======================================================================= basic access

static func leaves(world: WorldState) -> Dictionary:
	return world.table("pop")


static func total(world: WorldState) -> int:
	return int(world.values.get("pop_total", 0))


## Leaf keys matching a filter on key parts, e.g. {"hb": "hb:d:1", "status": "EMPLOYED"}. Values may be
## a String or an Array of allowed values. Sorted (deterministic).
static func select(world: WorldState, filter: Dictionary) -> Array:
	var pop: Dictionary = world.peek("pop")
	var cand = pop  # keys to scan: the whole table, or an index bucket when the filter pins hb (and inc)
	if filter.has("hb") and typeof(filter["hb"]) == TYPE_STRING:
		var ix := _index(world)
		if filter.has("inc") and typeof(filter["inc"]) == TYPE_STRING:
			cand = ix["hbinc"].get(filter["hb"] + "|" + filter["inc"], {})
		else:
			cand = ix["hb"].get(filter["hb"], {})
	var out: Array = []
	for k in cand:
		var l: Dictionary = pop.get(k, {})
		if l.is_empty():
			continue
		var ok := true
		for f in filter:
			var want = filter[f]
			if typeof(want) == TYPE_ARRAY:
				if not (l[f] in want):
					ok = false
					break
			elif l[f] != want:
				ok = false
				break
		if ok:
			out.append(k)
	out.sort()
	return out


# ======================================================================= index (not saved; self-healing)
## Leaf keys by hb and by hb|inc, rebuilt whenever the pop table object changed (load) or its size disagrees.
## Kept current by _add_people / _take; other writers are caught by the size check.
static var _ix := {}


static func _index(world: WorldState) -> Dictionary:
	var pop: Dictionary = world.peek("pop")
	var id := world.get_instance_id()
	var e: Dictionary = _ix.get(id, {})
	if e.is_empty() or not is_same(e["table"], pop) or int(e["n"]) != pop.size():
		e = {"table": pop, "n": 0, "hb": {}, "hbinc": {}}
		for k in pop:
			_ix_add(e, k, pop[k])
		_ix[id] = e
	return e


static func _ix_add(e: Dictionary, k: String, l: Dictionary) -> void:
	var hb: String = l["hb"]
	var hi: String = hb + "|" + String(l["inc"])
	if not e["hb"].has(hb):
		e["hb"][hb] = {}
	if not e["hbinc"].has(hi):
		e["hbinc"][hi] = {}
	if not e["hb"][hb].has(k):
		e["n"] = int(e["n"]) + 1
	e["hb"][hb][k] = true
	e["hbinc"][hi][k] = true


static func _ix_created(world: WorldState, k: String) -> void:
	var e: Dictionary = _ix.get(world.get_instance_id(), {})
	if not e.is_empty() and is_same(e["table"], world.peek("pop")):
		_ix_add(e, k, world.peek("pop")[k])


static func _ix_deleted(world: WorldState, k: String, l: Dictionary) -> void:
	var e: Dictionary = _ix.get(world.get_instance_id(), {})
	if e.is_empty() or not is_same(e["table"], world.peek("pop")):
		return
	var hb: String = l["hb"]
	if e["hb"].get(hb, {}).has(k):
		e["hb"][hb].erase(k)
		e["n"] = int(e["n"]) - 1
	e["hbinc"].get(hb + "|" + String(l["inc"]), {}).erase(k)


## Count of people matching a filter; bucket "skill:S" / "age:O" counts only that composition bucket.
static func count(world: WorldState, filter: Dictionary, bucket: String = "") -> int:
	var t := 0
	for k in select(world, filter):
		t += _weight(world.peek("pop")[k], bucket)
	return t


static func _weight(l: Dictionary, bucket: String) -> int:
	if bucket == "":
		return int(l["n"])
	if bucket == "recent":
		return int(l["recent"])
	var b := bucket.split(":")
	return int(l[b[0]].get(b[1], 0))


# ======================================================================= leaf creation

static func _blank(key: String) -> Dictionary:
	var l := {"key": key, "n": 0, "age": {}, "skill": {}, "recent": 0, "exposure": []}
	for b in AGE_BANDS:
		l["age"][b] = 0
	for s in SKILLS:
		l["skill"][s] = 0
	var p := parts_of(key)
	for k in p:
		l[k] = p[k]
	return l


## Founding population (PD §2.3 "explicitly modeled arrival"): counted as the base, not as an arrival.
## comp: {"age": {...}, "skill": {...}} counts summing to n (missing → all adults "A" / all "G").
## state: initial beliefs etc. (copied).
static func seed_leaf(world: WorldState, parts: Dictionary, n: int, comp: Dictionary = {}, state: Dictionary = {}) -> String:
	var key := key_of(parts)
	_add_people(world, key, n, _full_comp(n, comp), 0, state)
	world.values["pop_total"] = total(world) + n
	world.values["pop_base"] = int(world.values.get("pop_base", 0)) + n
	return key


static func _full_comp(n: int, comp: Dictionary) -> Dictionary:
	var out := {"age": comp.get("age", {"A": n}).duplicate(), "skill": comp.get("skill", {"G": n}).duplicate()}
	for f in COMP_FIELDS:
		var s := 0
		for b in out[f]:
			s += int(out[f][b])
		assert(s == n, "composition %s sums to %d, not %d" % [f, s, n])
	return out


## Adds people with a given composition and belief state into `key` (creating it). Beliefs mix by weight.
static func _add_people(world: WorldState, key: String, n: int, comp: Dictionary, recent: int, state: Dictionary) -> void:
	if n <= 0:
		return
	var pop := world.table("pop")
	if not pop.has(key):
		var l := _blank(key)
		for f in state:
			if not (f in NON_STATE):
				l[f] = _copy(state[f])
		pop[key] = l
		_ix_created(world, key)
	else:
		var l: Dictionary = pop[key]
		var n0: int = l["n"]
		for f in state:
			if f in NON_STATE:
				continue
			l[f] = _mix(l.get(f), state[f], n0, n) if l.has(f) else _copy(state[f])
	var d: Dictionary = pop[key]
	d["n"] = int(d["n"]) + n
	d["recent"] = int(d["recent"]) + recent
	for f in COMP_FIELDS:
		for b in comp[f]:
			d[f][b] = int(d[f].get(b, 0)) + int(comp[f][b])


static func _copy(v):
	return v.duplicate(true) if typeof(v) in [TYPE_DICTIONARY, TYPE_ARRAY] else v


## Population-weighted mix of belief state a (weight na) and b (weight nb). Ints and floats average;
## dicts mix per key (a missing key counts as 0); anything else keeps a.
static func _mix(a, b, na: int, nb: int):
	if na + nb <= 0:
		return _copy(b)
	match typeof(a):
		TYPE_INT:
			if typeof(b) in [TYPE_INT, TYPE_FLOAT]:
				return int(round((float(a) * na + float(b) * nb) / float(na + nb)))
		TYPE_FLOAT:
			if typeof(b) in [TYPE_INT, TYPE_FLOAT]:
				return (a * na + float(b) * nb) / float(na + nb)
		TYPE_DICTIONARY:
			if typeof(b) == TYPE_DICTIONARY:
				var out := {}
				var ks: Array = a.keys()
				for k in b:
					if not a.has(k):
						ks.append(k)
				for k in ks:
					var va = a.get(k, 0 if typeof(b.get(k)) != TYPE_DICTIONARY else {})
					var vb = b.get(k, 0 if typeof(a.get(k)) != TYPE_DICTIONARY else {})
					out[k] = _mix(va, vb, na, nb)
				return out
	return a


# ======================================================================= moving people

## Takes k people out of `src` (composition split by largest remainder, or restricted to `only`
## e.g. {"skill": "S"} / {"age": "O"}). Returns {"n", "comp", "recent", "state"}; deletes empty leaves.
static func _take(world: WorldState, src: String, k: int, only: Dictionary = {}) -> Dictionary:
	var pop := world.table("pop")
	var l: Dictionary = pop[src]
	assert(k >= 0 and k <= int(l["n"]), "take %d from %s (n=%d)" % [k, src, l["n"]])
	var comp := {}
	for f in COMP_FIELDS:
		var buckets: Array = l[f].keys()
		buckets.sort()
		var w: Array = []
		for b in buckets:
			w.append(0 if (only.has(f) and only[f] != b) else int(l[f][b]))
		var wsum := 0
		for x in w:
			wsum += x
		assert(wsum >= k, "not enough %s in %s for %s" % [f, src, str(only)])
		var parts := EconUtil.split_lr(k, w)
		comp[f] = {}
		for i in buckets.size():
			if parts[i] > 0:
				comp[f][buckets[i]] = parts[i]
				l[f][buckets[i]] = int(l[f][buckets[i]]) - parts[i]
	# composition fields are split independently; where a selector is used on one field, the others follow
	# the leaf's mix (the joint distribution within a leaf is not tracked beyond its own key).
	var rec := 0
	if int(l["n"]) > 0:
		rec = EconUtil.split_lr(k, [int(l["recent"]), int(l["n"]) - int(l["recent"])])[0]
	l["recent"] = int(l["recent"]) - rec
	var state := {}
	for f in l:
		if not (f in NON_STATE):
			state[f] = _copy(l[f])
	l["n"] = int(l["n"]) - k
	if int(l["n"]) == 0:
		pop.erase(src)
		_ix_deleted(world, src, l)
	return {"n": k, "comp": comp, "recent": rec, "state": state}


## Moves k people from leaf `src` to leaf `dst`. Their beliefs mix into dst by weight (PD §1.2, §10.4.8).
static func transfer(world: WorldState, src: String, dst: String, k: int, reason: String, only: Dictionary = {}) -> void:
	if k <= 0 or src == dst:
		return
	var got := _take(world, src, k, only)
	_add_people(world, dst, k, got["comp"], got["recent"], got["state"])
	_flow(world, src, dst, k, reason)


## Moves k people matching `filter` (pro rata over matching leaves by largest remainder, weighted by
## `bucket`, e.g. "skill:S") into the same leaves relabelled by `change`. Returns people moved.
## This is the economy's main entry point: it never needs leaf keys.
static func move_group(world: WorldState, filter: Dictionary, k: int, change: Dictionary, reason: String, bucket: String = "") -> int:
	var keys := select(world, filter)
	var w: Array = []
	var avail := 0
	for key in keys:
		var x := _weight(world.peek("pop")[key], bucket)
		w.append(x)
		avail += x
	k = mini(k, avail)
	if k <= 0:
		return 0
	var parts := EconUtil.split_lr(k, w)
	var only := {}
	if bucket != "" and bucket != "recent":
		var b := bucket.split(":")
		only[b[0]] = b[1]
	for i in keys.size():
		if parts[i] > 0:
			transfer(world, keys[i], relabel(keys[i], change), parts[i], reason, only)
	return k


## Splits n over the given leaf keys by weights (largest remainder). Helper for flows computed per block.
static func split_over(n: int, keys: Array, weights: Array) -> Dictionary:
	var parts := EconUtil.split_lr(n, weights)
	var out := {}
	for i in keys.size():
		if parts[i] > 0:
			out[keys[i]] = parts[i]
	return out


# ======================================================================= sources and sinks

## Births into `key` (a CHILD leaf); they inherit `state` (or the key's existing state).
static func birth(world: WorldState, key: String, n: int, state: Dictionary = {}) -> void:
	if n <= 0:
		return
	_add_people(world, key, n, {"age": {"C": n}, "skill": {"G": n}}, 0, state)
	_count(world, "pop_births", n)
	_flow(world, "BIRTH", key, n, "BIRTH")


static func death(world: WorldState, key: String, n: int, only: Dictionary = {}) -> void:
	if n <= 0:
		return
	_take(world, key, n, only)
	_count(world, "pop_deaths", -n)
	_flow(world, key, "DEATH", n, "DEATH")


## Immigrants: comp as in seed_leaf; all count as `recent`.
static func arrive(world: WorldState, key: String, n: int, comp: Dictionary = {}, state: Dictionary = {}) -> void:
	if n <= 0:
		return
	_add_people(world, key, n, _full_comp(n, comp), n, state)
	_count(world, "pop_arrivals", n)
	_flow(world, "ARRIVAL", key, n, "ARRIVAL")


static func depart(world: WorldState, key: String, n: int, reason: String = "EMIGRATION", only: Dictionary = {}) -> void:
	if n <= 0:
		return
	_take(world, key, n, only)
	_count(world, "pop_departures", -n)
	_flow(world, key, "DEPARTURE", n, reason)


static func _count(world: WorldState, counter: String, delta: int) -> void:
	world.values[counter] = int(world.values.get(counter, 0)) + absi(delta)
	world.values["pop_total"] = total(world) + delta


# ======================================================================= transfer ledger (PD §8.7)

## Monthly flows aggregated by (month, src, dst, reason). Rows older than FLOW_KEEP_MONTHS are compacted
## to (year, src housing|income, dst housing|income, reason) by compact_flows().
static func _flow(world: WorldState, src: String, dst: String, n: int, reason: String) -> void:
	var fk := "%d|%s>%s|%s" % [world.month, src, dst, reason]
	var t := world.table("pop_flow")
	t[fk] = int(t.get(fk, 0)) + n


## Flows of one month: [{src, dst, reason, n}], sorted.
static func flows(world: WorldState, month: int) -> Array:
	var out: Array = []
	var pre := "%d|" % month
	var ks: Array = world.peek("pop_flow").keys()
	ks.sort()
	for fk in ks:
		if not String(fk).begins_with(pre):
			continue
		var rest := String(fk).substr(pre.length())
		var cut := rest.rfind("|")
		var sd := rest.substr(0, cut).split(">")
		out.append({"src": sd[0], "dst": sd[1], "reason": rest.substr(cut + 1), "n": world.peek("pop_flow")[fk]})
	return out


static func compact_flows(world: WorldState) -> void:
	var t := world.table("pop_flow")
	var keep_from := world.month - FLOW_KEEP_MONTHS
	var ks: Array = t.keys()
	ks.sort()
	for fk in ks:
		var s := String(fk)
		if s.begins_with("Y"):
			continue
		var m := int(s.get_slice("|", 0))
		if m >= keep_from:
			continue
		var rest := s.substr(s.find("|") + 1)
		var cut := rest.rfind("|")
		var sd := rest.substr(0, cut).split(">")
		var yk := "Y%d|%s>%s|%s" % [m / 12 + 1, _lvl2(sd[0]), _lvl2(sd[1]), rest.substr(cut + 1)]
		t[yk] = int(t.get(yk, 0)) + int(t[fk])
		t.erase(fk)


static func _lvl2(k: String) -> String:
	if not k.contains("|"):
		return k
	return k.get_slice("|", 0) + "|" + k.get_slice("|", 1)


# ======================================================================= reconcile (PD §21 phase 11)

## Returns a list of problems (empty = consistent).
static func reconcile(world: WorldState) -> Array:
	var errs: Array = []
	var sum := 0
	for k in world.peek("pop"):
		var l: Dictionary = world.peek("pop")[k]
		var n: int = l["n"]
		if n <= 0:
			errs.append("%s: n=%d" % [k, n])
		if key_of(l) != k:
			errs.append("%s: key parts do not match" % k)
		for f in COMP_FIELDS:
			var s := 0
			for b in l[f]:
				if int(l[f][b]) < 0:
					errs.append("%s: %s.%s negative" % [k, f, b])
				s += int(l[f][b])
			if s != n:
				errs.append("%s: %s sums to %d, n=%d" % [k, f, s, n])
		if int(l["recent"]) < 0 or int(l["recent"]) > n:
			errs.append("%s: recent=%d" % [k, l["recent"]])
		sum += n
	if sum != total(world):
		errs.append("leaves sum to %d, recorded total %d" % [sum, total(world)])
	var v := world.values
	var expect := int(v.get("pop_base", 0)) + int(v.get("pop_births", 0)) - int(v.get("pop_deaths", 0)) \
		+ int(v.get("pop_arrivals", 0)) - int(v.get("pop_departures", 0))
	if expect != total(world):
		errs.append("total %d != base + births - deaths + arrivals - departures = %d" % [total(world), expect])
	return errs
