extends RefCounted
## The one place the law finds a company (rebuild step 2; planning/rebuild-law-face.md section 1). Owner: Anni.
## Preload it (no class_name): const LawCompany := preload("res://sim/law/law_company.gd").
## Its preloads form cycles (law_company -> land_law, law_ops -> justice_ops -> law_company). Godot resolves them, but
## never write a const that reads another script's const across the cycle (const X := LandLaw.Y): it would load-order.
##
## The law keeps its OWN records about a company, keyed by the company's id ("company:N"), and never a copy of the
## company's fields (rebuild-company.md section 3):
##   licence (holder_id), permit_application (holder_id), violation_track (company), liability (debtor),
##   case (respondent {kind COMPANY, id}), the court's convictions and wound_up (law_state justice), land_title (owner,
##   lessee), competition takeovers (buyer, target).
## Everything the law reads about the company itself goes through the functions below, which read Bob's company record
## (game/sim/economy/company.gd). A change in his record touches this file only.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const LandLaw := preload("res://sim/law/land_law.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

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
		if String(t.get("owner", "")) == id or String(t.get("lessee", "")) == id or (t.get("plots", {}) as Dictionary).has(id):
			out["titles"].append(String(k))
	return out


# ------------------------------------------------------------------ what the law requires of a new company (step 3)
# Plainest form (planning/rebuild-step3-joins.md; rebuild-law-face.md section 2): the land is the plan's (LandLaw.sell),
# the zone allows the type, and where the government's licence regime requires it a licence. Applied for when the plan
# signs (COMPANY_AI), decided by the permit office in JUSTICE the same month; no fee and no building permit until step 6;
# no going ahead unlicensed until step 6. A plan's licence passes to its company at the opening (register).

const LICENCE_KIND := "licence"
const LICENCE_MONTHS := {"HAZARD": 60, "EXTRACTION": 120}   # until the licence term is a lever (law face 2.7, step 6)


## The licences a type needs under the government's regimes: "HAZARD" (a hazardous row, LAW_LICENCE_REGIME_HAZARD
## REQUIRED) and "EXTRACTION" (a mine, LAW_LICENCE_REGIME_EXTRACTION REQUIRED).
static func licences_required(world: WorldState, type: String) -> Array:
	var out: Array = []
	if TypeTable.has_type(type) and bool(TypeTable.row(type).get("hazard", false)) 			and String(world.levers.get("LAW_LICENCE_REGIME_HAZARD", "REQUIRED")) == "REQUIRED":
		out.append("HAZARD")
	if type == "MINE" and String(world.levers.get("LAW_LICENCE_REGIME_EXTRACTION", "REQUIRED")) == "REQUIRED":
		out.append("EXTRACTION")
	return out


static func _site_keys(site: Dictionary) -> Array:
	var cells: Array = site.get("cells", [])
	if not cells.is_empty():
		return cells.map(func(c): return "c:" + String(c).trim_prefix("c:"))
	return [String(site.get("tile", ""))] if String(site.get("tile", "")) != "" else []


static func _applied(world: WorldState, holder: String, ltype: String) -> bool:
	for aid in world.peek("permit_application"):
		var a: Dictionary = world.peek("permit_application")[aid]
		if String(a["holder_id"]) == holder and String(a["type"]) == ltype and String(a["status"]) == "QUEUED":
			return true
	return false


## Before a plan signs with a builder (COMPANY_AI): the zone must allow the type on every key of its site; each licence
## the regime requires is applied for (once). -> {ok, needs: [licence types applied for or held], reasons: [why not]}
static func may_sign(world: WorldState, plan_id: String, type: String, site: Dictionary) -> Dictionary:
	var reasons: Array = []
	var use := String(LandLaw.use_of(type))
	for key in _site_keys(site):
		var zone := String(LandLaw.zone_of(world, key))
		if use != "" and not (use in (LandLaw.ZONE_USES.get(zone, []) as Array)):
			reasons.append("the %s zone at %s does not allow %s" % [zone.to_lower(), key, use.to_lower()])
	var needs := licences_required(world, type)
	if reasons.is_empty():
		for lt in needs:
			if not RE.has_licence(world, plan_id, LICENCE_KIND, lt) and not _applied(world, plan_id, lt):
				LawOps.apply_licence(world, plan_id, LICENCE_KIND, lt, "", true, int(LICENCE_MONTHS.get(lt, 60)))
	Logbook.note(world, "LAW", plan_id, "may sign" if reasons.is_empty() else "may not sign", {"type": type, "needs": needs,
		"reasons": reasons}, {}, "permit_office")
	return {"ok": reasons.is_empty(), "needs": needs, "reasons": reasons}


## The law's record that a company exists, at its opening (PRODUCTION): its plan, its owners that day; the plan's
## licences and applications become the company's. The owners and type in company_register are a dated snapshot by
## design (who founded it), the law's own record, not a copy of the company's fields kept up to date.
static func register(world: WorldState, company_id: String, plan_id: String) -> void:
	var moved := 0
	for t in ["licence", "permit_application"]:
		var tb := world.table(t)
		for id in CoreUtil.sorted_keys(tb):
			if String(tb[id].get("holder_id", "")) == plan_id:
				tb[id]["holder_id"] = company_id
				moved += 1
	world.table("company_register")[company_id] = {"plan": plan_id, "month": world.month, "holders": holders(world, company_id),
		"type": type_of(world, company_id)}
	Logbook.note(world, "LAW", company_id, "registered", {"plan": plan_id, "holders": holders(world, company_id),
		"licence_records_moved": moved}, {}, "", plan_id)


## May the company's new plant run (PRODUCTION, at the opening)? Every licence its type requires must be active.
## When not, the opener closes the plant (Company.close_plant, reason "LAW") and the law keeps it on its list; it is
## reopened in JUSTICE the month the licence is granted (reopen_licensed). -> {ok, reasons}
static func may_open(world: WorldState, company_id: String, plant_id: String) -> Dictionary:
	var reasons: Array = []
	for lt in licences_required(world, type_of(world, company_id)):
		if not RE.has_licence(world, company_id, LICENCE_KIND, lt):
			reasons.append("no %s licence" % lt.to_lower())
	if not reasons.is_empty():
		world.table("law_closed")[plant_id] = {"company": company_id, "month": world.month, "reasons": reasons}
	Logbook.note(world, "LAW", company_id, "may open" if reasons.is_empty() else "may not run", {"plant": plant_id,
		"reasons": reasons}, {}, "permit_office", plant_id)
	return {"ok": reasons.is_empty(), "reasons": reasons}


## Monthly (JUSTICE, after the permit office): a plant closed by the law reopens once its company holds every licence its
## type requires (Company.reopen_plant, reason "LAW").
static func reopen_licensed(world: WorldState) -> void:
	var lc := world.peek("law_closed")
	for pid in CoreUtil.sorted_keys(lc):
		var cid := String(lc[pid]["company"])
		if not trading(world, cid):
			world.table("law_closed").erase(pid)
			continue
		var ok := true
		for lt in licences_required(world, type_of(world, cid)):
			if not RE.has_licence(world, cid, LICENCE_KIND, lt):
				ok = false
		if ok:
			Company.reopen_plant(world, String(pid), "LAW")
			world.table("law_closed").erase(pid)
			Logbook.note(world, "LAW", cid, "may run", {"plant": String(pid)}, {"closed": [true, false]}, "permit_office", String(pid))
