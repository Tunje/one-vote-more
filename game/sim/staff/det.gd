extends RefCounted
## Deterministic iteration over entity tables.
## Dictionaries lose insertion order across save/load (var_to_str writes keys sorted), so iterating a table
## directly gives a different order after loading. Ids are "<prefix>:<n>" from world.new_id, so sorting by
## (prefix, n) reproduces creation order both before and after a load.


static func ordered(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort_custom(_less)
	return keys


## Same order as ordered(), for a key subset the caller already filtered (sort the few, not the whole table).
static func sort_ids(keys: Array) -> Array:
	keys.sort_custom(_less)
	return keys


static func _less(a, b) -> bool:
	var sa := String(a)
	var sb := String(b)
	var ia := sa.rfind(":")
	var ib := sb.rfind(":")
	if ia >= 0 and ib >= 0:
		var pa := sa.substr(0, ia)
		var pb := sb.substr(0, ib)
		if pa != pb:
			return pa < pb
		var na := sa.substr(ia + 1)
		var nb := sb.substr(ib + 1)
		if na.is_valid_int() and nb.is_valid_int():
			return na.to_int() < nb.to_int()
		return na < nb
	return sa < sb


## Facts from `from_month` on, in insertion order: same result as world.facts.query(prefix, from_month, now, vis)
## but O(recent facts) instead of O(all facts). Facts are appended in month order, so walk back from the end.
static func recent_facts(world: WorldState, type_prefix: String, from_month: int, visibility: String = "") -> Array:
	var arr: Array = world.facts.facts
	var out: Array = []
	var i := arr.size() - 1
	while i >= 0:
		var f: Dictionary = arr[i]
		if int(f["month"]) < from_month:
			break
		if String(f["type"]).begins_with(type_prefix) and (visibility == "" or f["visibility"] == visibility):
			out.append(f)
		i -= 1
	out.reverse()
	return out
