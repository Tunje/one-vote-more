extends RefCounted
## The one place the law finds a company (rebuild step 2; planning/rebuild-law-face.md section 1). Owner: Anni.
## Preload it (no class_name): const LawCompany := preload("res://sim/law/law_company.gd").
##
## The law keeps its OWN records about a company, keyed by the company's id ("company:N"), and never a copy of the
## company's fields (rebuild-company.md section 3):
##   licence (holder_id), permit_application (holder_id), violation_track (company), liability (debtor),
##   case (respondent {kind COMPANY, id}), the court's convictions and wound_up (law_state justice), land_title (owner,
##   lessee), competition takeovers (buyer, target).
## Everything the law reads about the company itself goes through the functions below, which read Bob's company record
## (game/sim/economy/company.gd). A change in his record touches this file only.

const Company := preload("res://sim/economy/company.gd")

## Statuses after which a company no longer trades (the endings come at step 5; their names are Bob's then).
const DEAD := ["ENDED", "WOUND_UP", "DISSOLVED", "LIQUIDATION"]


## A read-only copy of the company's record ({} if none), for the doorway's readers of its books (EconFace.annual_*).
static func record(world: WorldState, id: String) -> Dictionary:
	return Company.record(world, id)


## A plant: {id, company, type, size, sixths, condition, closed, line}, {} if none.
static func plant(world: WorldState, plant_id: String) -> Dictionary:
	return Company.plant(world, plant_id)


## The record itself, read in place (no copy) for the plain fields below: a company's stock, books and staff are
## large, and the law asks these questions per licence, case and company every month (Ella's review). Read-only.
static func _peek(world: WorldState, id: String) -> Dictionary:
	return world.peek(Company.TABLE).get(id, {})


static func exists(world: WorldState, id: String) -> bool:
	return world.peek(Company.TABLE).has(id)


## Still trading: it exists and has not ended.
static func trading(world: WorldState, id: String) -> bool:
	var r := _peek(world, id)
	return not r.is_empty() and not (String(r.get("status", "")) in DEAD)


static func name_of(world: WorldState, id: String) -> String:
	return String(_peek(world, id).get("name", id))


static func type_of(world: WorldState, id: String) -> String:
	return Company.type_of(world, id)


## The district the company's home area lies in (12.1, 1-2), "" when it has none yet.
static func district_of(world: WorldState, id: String) -> String:
	var area := String(_peek(world, id).get("area", ""))
	return String(AreaStore.get_area(world, area).get("district", "")) if area != "" else ""


## The company's account in the ledger.
static func account(id: String) -> String:
	return CoreUtil.acct(id)


## A state company: owned by the government. The court never takes it to court (12.8, 54); the purse answers.
static func is_state(world: WorldState, id: String) -> bool:
	return exists(world, id) and bool(Company.is_state(world, id))


## {holder id: share ‰}, adding up to 1000 (12.8, 54a: each owner answers by their share). {} if no company.
static func holders(world: WorldState, id: String) -> Dictionary:
	return (_peek(world, id).get("owner", {}).get("holders", {}) as Dictionary).duplicate()


## The name of the company's chief, for the facts about a conviction ("" until the company has a chief, 12.11, 77).
static func chief_name(world: WorldState, id: String) -> String:
	var c = _peek(world, id).get("chief", {})
	return String(c.get("name", "")) if c is Dictionary else str(c)


static func plant_ids(world: WorldState, id: String) -> Array:
	return Company.plant_ids_of(world, id) if exists(world, id) else []


## Every record the law keeps about this company, by kind: {licences, applications, violations, liabilities, cases,
## convictions, wound_up, titles}. Ids only; each record is read from its own table.
static func records_of(world: WorldState, id: String) -> Dictionary:
	var out := {"licences": [], "applications": [], "violations": [], "liabilities": [], "cases": [], "convictions": [],
		"wound_up": {}, "titles": []}
	for k in CoreUtil.sorted_keys(world.peek("licence")):
		if String(world.peek("licence")[k].get("holder_id", "")) == id:
			out["licences"].append(String(k))
	for k in CoreUtil.sorted_keys(world.peek("permit_application")):
		if String(world.peek("permit_application")[k].get("holder_id", "")) == id:
			out["applications"].append(String(k))
	for k in CoreUtil.sorted_keys(world.peek("violation_track")):
		if String(world.peek("violation_track")[k].get("company", "")) == id:
			out["violations"].append(String(k))
	for k in CoreUtil.sorted_keys(world.peek("liability")):
		if String(world.peek("liability")[k].get("debtor", "")) == id:
			out["liabilities"].append(String(k))
	for k in CoreUtil.sorted_keys(world.peek("case")):
		var resp = world.peek("case")[k].get("respondent", {})
		if resp is Dictionary and String(resp.get("kind", "")) == "COMPANY" and String(resp.get("id", "")) == id:
			out["cases"].append(String(k))
	var js: Dictionary = world.peek("law_state").get("s", {}).get("justice", {})
	out["convictions"] = (js.get("convictions", {}).get(id, []) as Array).duplicate()
	out["wound_up"] = (js.get("wound_up", {}).get(id, {}) as Dictionary).duplicate()
	for k in CoreUtil.sorted_keys(world.peek("land_title")):
		var t: Dictionary = world.peek("land_title")[k]
		if String(t.get("owner", "")) == id or String(t.get("lessee", "")) == id:
			out["titles"].append(String(k))
	return out
