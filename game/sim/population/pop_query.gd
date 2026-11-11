class_name PopQuery
extends RefCounted
## Derived population blocks (spec-population-v1 D1): HOUSING, INCOME, WORK, PHILOSOPHY and EFFECT blocks
## are sums over leaves, so parent = Σ children by construction (PD §2). Read-only (uses world.peek).

const LEVELS := {"HOUSING": 1, "INCOME": 2, "WORK": 4, "PHILOSOPHY": 5, "EFFECT": 6}


## Block key of a leaf at a level, e.g. block_key("hb:d:1|I2|MINING|EMPLOYED|LABOR|e0", "WORK")
## = "hb:d:1|I2|MINING|EMPLOYED". (WORK = occupation + employment status, PD §5.2.)
static func block_key(leaf_key: String, level: String) -> String:
	var s := leaf_key.split("|")
	return "|".join(s.slice(0, LEVELS[level]))


## All blocks at a level: {block_key: n}, optionally only those under `parent` (a block key prefix).
static func blocks(world: WorldState, level: String, parent: String = "") -> Dictionary:
	var out := {}
	for k in world.peek("pop"):
		if parent != "" and not (k == parent or String(k).begins_with(parent + "|")):
			continue
		var bk := block_key(k, level)
		out[bk] = int(out.get(bk, 0)) + int(world.peek("pop")[k]["n"])
	return out


## One block: {"key", "level", "n", "age", "skill", "recent", "leaves", "children": {child_key: n},
## "mean": {field: population-weighted mean of numeric belief fields}}.
static func block(world: WorldState, level: String, key: String) -> Dictionary:
	var depth: int = LEVELS[level]
	var child_depth := 6
	for lv in ["HOUSING", "INCOME", "WORK", "PHILOSOPHY", "EFFECT"]:
		if LEVELS[lv] > depth:
			child_depth = LEVELS[lv]
			break
	var out := {"key": key, "level": level, "n": 0, "age": {}, "skill": {}, "recent": 0, "leaves": [], "children": {}, "mean": {}}
	var acc := {}
	for k in world.peek("pop"):
		if not (k == key or String(k).begins_with(key + "|")) or block_key(k, level) != key:
			continue
		var l: Dictionary = world.peek("pop")[k]
		var n: int = l["n"]
		out["n"] += n
		out["recent"] += int(l["recent"])
		out["leaves"].append(k)
		for f in PopStore.COMP_FIELDS:
			for b in l[f]:
				out[f][b] = int(out[f].get(b, 0)) + int(l[f][b])
		if depth < 6:
			var ck := "|".join(String(k).split("|").slice(0, child_depth))
			out["children"][ck] = int(out["children"].get(ck, 0)) + n
		for f in l:
			if f in PopStore.NON_STATE:
				continue
			_acc(acc, f, l[f], n)
	out["leaves"].sort()
	for f in acc:
		out["mean"][f] = _finish(acc[f], out["n"])
	return out


static func _acc(acc: Dictionary, f, v, n: int) -> void:
	match typeof(v):
		TYPE_INT, TYPE_FLOAT:
			acc[f] = float(acc.get(f, 0.0)) + float(v) * n
		TYPE_DICTIONARY:
			if not acc.has(f) or typeof(acc[f]) != TYPE_DICTIONARY:
				acc[f] = {}
			for k in v:
				_acc(acc[f], k, v[k], n)


static func _finish(a, n: int):
	if typeof(a) == TYPE_DICTIONARY:
		var out := {}
		for k in a:
			out[k] = _finish(a[k], n)
		return out
	return float(a) / float(maxi(1, n))
