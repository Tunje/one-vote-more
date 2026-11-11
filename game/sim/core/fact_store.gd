class_name FactStore
extends RefCounted
## Shared, immutable Fact store (planning/pic-core.md §4).
## Facts drive blame/credit, briefings, explainability and history. Corrections are new facts; nothing is edited.

const REQUIRED := ["type", "owner", "subjects", "responsible", "impact", "magnitude", "visibility"]
const VISIBILITIES := ["PUBLIC", "OFFICIAL", "SECRET"]
const COMPACT_BELOW_MAGNITUDE := 20
const COMPACT_AFTER_MONTHS := 24

var facts: Array = []         # Array[Dictionary], read-only dicts, in insertion order
var by_id: Dictionary = {}    # id -> index into facts
var aggregates: Dictionary = {} # "month|type" -> count  (compacted low-magnitude facts)
var _next: int = 1


## Adds a fact for the given month. Returns its id. Missing optional fields get defaults.
func add(month: int, fact: Dictionary) -> String:
	for k in REQUIRED:
		assert(fact.has(k), "fact missing field '%s': %s" % [k, fact])
	assert(fact["visibility"] in VISIBILITIES, "bad visibility")
	var share_sum := 0.0
	for r in fact["responsible"]:
		share_sum += float(r["share"])
	assert(fact["responsible"].is_empty() or absf(share_sum - 1.0) < 0.001, "responsible shares must sum to 1")
	var f := fact.duplicate(true)
	f["id"] = "F%d" % _next
	_next += 1
	f["month"] = month
	if not f.has("location"): f["location"] = null
	if not f.has("affected"): f["affected"] = "ALL"
	if not f.has("causes"): f["causes"] = []
	if not f.has("data"): f["data"] = {}
	f.make_read_only()
	by_id[f["id"]] = facts.size()
	facts.append(f)
	return f["id"]


func get_fact(id: String) -> Dictionary:
	return facts[by_id[id]] if by_id.has(id) else {}


## SECRET -> PUBLIC promotion (law: evidence != truth). Emits a new *_REVEALED fact caused by the original.
func reveal(month: int, id: String, revealed_by: Array = []) -> String:
	var orig := get_fact(id)
	assert(not orig.is_empty() and orig["visibility"] == "SECRET", "can only reveal SECRET facts")
	return add(month, {
		"type": orig["type"] + "_REVEALED", "owner": orig["owner"], "subjects": orig["subjects"],
		"responsible": orig["responsible"], "impact": orig["impact"], "affected": orig["affected"],
		"magnitude": orig["magnitude"], "visibility": "PUBLIC", "location": orig["location"],
		"causes": [id], "data": {"revealed_by": revealed_by},
	})


func query(type_prefix: String = "", from_month: int = -1, to_month: int = 1 << 30, visibility: String = "") -> Array:
	return facts.filter(func(f):
		return f["type"].begins_with(type_prefix) and f["month"] >= from_month and f["month"] <= to_month \
			and (visibility == "" or f["visibility"] == visibility))


## Causal chain for "why did this happen?" (project §20.4), as a breadth-first list of ancestor facts.
func explain(id: String, max_depth: int = 6) -> Array:
	var out: Array = []
	var frontier: Array = [id]
	var seen := {}
	for _d in max_depth:
		var nxt: Array = []
		for fid in frontier:
			for c in get_fact(fid).get("causes", []):
				if not seen.has(c) and by_id.has(c):
					seen[c] = true
					out.append(get_fact(c))
					nxt.append(c)
		frontier = nxt
	return out


## Replace old low-magnitude facts with monthly per-type counts. Facts referenced as causes of kept facts survive.
func compact(current_month: int) -> void:
	var cutoff := current_month - COMPACT_AFTER_MONTHS
	var referenced := {}
	for f in facts:
		for c in f["causes"]:
			referenced[c] = true
	var kept: Array = []
	for f in facts:
		if f["month"] < cutoff and f["magnitude"] < COMPACT_BELOW_MAGNITUDE and not referenced.has(f["id"]):
			var key := "%d|%s" % [f["month"], f["type"]]
			aggregates[key] = aggregates.get(key, 0) + 1
		else:
			kept.append(f)
	if kept.size() != facts.size():
		facts = kept
		by_id.clear()
		for i in facts.size():
			by_id[facts[i]["id"]] = i


func to_dict() -> Dictionary:
	var plain: Array = []
	for f in facts:
		plain.append(f.duplicate(true))  # duplicates are writable; fine for serialization
	return {"facts": plain, "aggregates": aggregates.duplicate(), "next": _next}


static func from_dict(d: Dictionary) -> FactStore:
	var s := FactStore.new()
	for f in d["facts"]:
		var c: Dictionary = f.duplicate(true)
		c.make_read_only()
		s.by_id[c["id"]] = s.facts.size()
		s.facts.append(c)
	s.aggregates = d["aggregates"].duplicate()
	s._next = d["next"]
	return s
