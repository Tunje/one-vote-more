extends RefCounted
## Person-vs-position qualification (staffAndSkills §7.5, spec-staff §7.4). Pure functions.

const D := preload("res://sim/staff/staff_data.gd")


## Does the person satisfy at least one qualification path? Returns the path index or -1.
static func path_index(person: Dictionary, position: Dictionary, domain: String) -> int:
	var paths: Array = position["paths"]
	for i in paths.size():
		var p: Dictionary = paths[i]
		var ok := true
		var mins: Dictionary = p.get("min", {})
		for k in mins:
			var skill: String = domain if k == "DOMAIN" else k
			if int(person["skills"].get(skill, 0)) < int(mins[k]):
				ok = false
				break
		if ok:
			for t in p.get("talents", []):
				if not person["talents"].has(t):
					ok = false
					break
		if ok:
			return i
	return -1


## Positions that exist for this task instance given its params (only_if / min_clauses).
static func active_positions(def: Dictionary, params: Dictionary) -> Array:
	var out: Array = []
	var all: Array = def["positions"]
	for i in all.size():
		var p: Dictionary = all[i]
		if p.has("only_if") and not params.get(p["only_if"], false):
			continue
		if p.has("min_clauses") and int(params.get("clauses", 0)) < int(p["min_clauses"]):
			continue
		out.append(i)
	return out


static func domain_of(params: Dictionary) -> String:
	return String(params.get("domain", "ADMIN"))


## Civil servants may not hold PARTY-tagged positions (political neutrality).
static func neutrality_ok(person: Dictionary, def: Dictionary) -> bool:
	return not (person["roles"].has("CIVIL_SERVANT") and def["tags"].has("PARTY"))
