extends RefCounted
## Deterministic iteration over entity tables.
## Dictionaries lose insertion order across save/load (var_to_str writes keys sorted), so iterating a table
## directly gives a different order after loading. Ids are "<prefix>:<n>" from world.new_id, so sorting by
## (prefix, n) reproduces creation order both before and after a load.


static func ordered(d: Dictionary) -> Array:
	var keys: Array = d.keys()
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
