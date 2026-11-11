extends TestCase
## Charter bounds must be in each lever's own unit (ECON_MIN_WAGE min 400 vs a 40-150 % range froze the legislature).

const F := preload("res://tests/support/staff_fixture.gd")
const L := preload("res://sim/law/law_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")


func test_bounds_match_lever_units() -> void:
	var w := F.sim(3, true).world
	for lid in L.LEVER_BOUNDS:
		check(w.lever_defs.has(lid), lid + " exists")
		if not w.lever_defs.has(lid):
			continue
		var def: Dictionary = w.lever_defs[lid]
		var b: Dictionary = L.LEVER_BOUNDS[lid]
		if b.has("min_enum"):
			check(def.get("values", []).has(b["min_enum"]), lid + " min_enum is a lever value")
			continue
		var r: Array = def["range"]
		for k in ["min", "max"]:
			if b.has(k):
				check(float(b[k]) >= float(r[0]) and float(b[k]) <= float(r[1]), "%s %s %s inside range %s" % [lid, k, b[k], r])
		check(LawOps._charter_bounds(w, def, def["default"]).is_empty(), lid + " default satisfies the charter")
	for lid in w.lever_defs:
		var def: Dictionary = w.lever_defs[lid]
		if def.get("is_tax", false):
			check(float(def["range"][1]) <= float(L.TAX_MAX_PCT) * 1.0 and float(def["range"][1]) >= 10.0,
				"%s range %s is in whole percent, as TAX_MAX_PCT" % [lid, def["range"]])
			check(LawOps._charter_bounds(w, def, def["range"][1]).is_empty(), lid + " top of range lawful")
