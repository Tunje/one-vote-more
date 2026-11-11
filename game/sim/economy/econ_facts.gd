class_name EconFacts
extends RefCounted
## Thin helper to emit pic-core §4 facts from econ/comp (types listed in planning/pic-economy.md §2).


## subjects: [[kind, id], ...]; responsible: [[kind, id, share], ...] (shares sum to 1).
static func emit(world: WorldState, type: String, location, subjects: Array, responsible: Array, impact: Dictionary,
		magnitude: int, visibility: String, data: Dictionary = {}, affected = "ALL", causes: Array = []) -> String:
	var subj: Array = []
	for x in subjects:
		subj.append({"kind": x[0], "id": x[1]})
	var resp: Array = []
	for x in responsible:
		resp.append({"actor": {"kind": x[0], "id": x[1]}, "share": float(x[2])})
	var f := {"type": type, "owner": "comp" if type.begins_with("COMP_") else "econ", "subjects": subj, "responsible": resp,
		"impact": impact, "magnitude": clampi(magnitude, 0, 100), "visibility": visibility, "data": data,
		"affected": affected, "causes": causes}
	if location != null:
		f["location"] = location
	return world.add_fact(f)


## Blame split for something a company did: public enterprises are mostly blamed on the government.
static func company_blame(world: WorldState, org_id: String, company_share: float) -> Array:
	var o: Dictionary = world.table("org").get(org_id, {})
	if o.get("type", "") in EconData.PUBLIC_TYPES:
		return [["COMPANY", org_id, 0.2], ["GOVERNMENT", "government", 0.8]]
	return [["COMPANY", org_id, company_share], ["GOVERNMENT", "government", 1.0 - company_share]]
