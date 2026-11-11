class_name LawBridge
extends RefCounted
## Companies ↔ law interface (spec §9.5, DECISIONS C10; a9's LawOps API).
## Without a law subsystem (econ-only soak), everything is AUTHORIZED.

const LawOps := preload("res://sim/law/law_ops.gd")
const S := EconUtil.S


static func law_loaded(world: WorldState) -> bool:
	return not world.table("legal_rule").is_empty()


static func actor_of(world: WorldState, org_id: String) -> Dictionary:
	var o: Dictionary = world.table("org").get(org_id, {})
	var t: String = o.get("type", "PRIVATE")
	var own := "PUBLIC" if t in EconData.PUBLIC_TYPES else ("COOP" if t == "COOPERATIVE" else "PRIVATE")
	return {"kind": "COMPANY", "id": org_id, "ownership": own}


## True if the company may go ahead (lawfully, after obtaining missing licences, or unlawfully by the misconduct rule).
## Sets out["unlawful"] = true when it proceeds in violation.
static func allowed(world: WorldState, org_id: String, action: String, params: Dictionary, out: Dictionary = {}) -> bool:
	out["unlawful"] = false
	if not law_loaded(world):
		return true
	var actor := actor_of(world, org_id)
	var res: Dictionary = LawOps.validate(world, actor, action, params)
	match res.get("result", "AUTHORIZED"):
		"AUTHORIZED":
			return true
		"AUTHORIZED_WITH_CONDITIONS":
			# apply through law's permit queue (once); operating before the grant is unlawful (misconduct rule decides)
			for m in res.get("missing", []):
				if m.has("licence") and not _pending(world, org_id, m["licence"]):
					_queue_licence(world, org_id, m["licence"], params.get("district", params.get("site_district", "")))
	if _misconduct(world, org_id):
		LawOps.record_violation(world, actor, action, params)
		out["unlawful"] = true
		return true
	return false


## Starting facilities: licence granted directly, free (spec §9.5).
static func _apply_licence(world: WorldState, org_id: String, ltype: String, _free: bool = true) -> void:
	LawOps.grant_licence(world, org_id, "licence", ltype, 120 if ltype == "EXTRACTION" else 60)


static func _pending(world: WorldState, org_id: String, ltype: String) -> bool:
	for aid in world.table("permit_application"):
		var a: Dictionary = world.table("permit_application")[aid]
		if a["holder_id"] == org_id and a["type"] == ltype and a["status"] == "QUEUED":
			return true
	return false


## New application via law's permit queue; fee paid at application (law fee levers are milli-W_ref).
static func _queue_licence(world: WorldState, org_id: String, ltype: String, district: String) -> void:
	var criteria_ok := ltype != "EXTRACTION" or district == "d:3"  # extraction needs a MINING-zone site (D5: Redrock)
	LawOps.apply_licence(world, org_id, "licence", ltype, district, criteria_ok, 120 if ltype == "EXTRACTION" else 60)
	var w_ref: int = world.values.get("ECON_W_REF", 1200 * S)
	var fee_milli := int(EconUtil.lever(world, "LAW_FEE_EXTRACTION" if ltype == "EXTRACTION" else "LAW_FEE_HAZARD", 5000 if ltype == "EXTRACTION" else 3000))
	var paid := EconUtil.pay_upto(world, EconUtil.acct(org_id), EconUtil.TREASURY, int(float(fee_milli) * float(w_ref) / 1000.0), "FEE")
	EconFinance._gov_rev(world, paid)


## Misconduct rule (spec §9.5): proceed unlawfully iff profitable and (risky CEO, distressed, or weak inspection).
static func _misconduct(world: WorldState, org_id: String) -> bool:
	var o: Dictionary = world.table("org").get(org_id, {})
	if o.is_empty() or o["type"] in EconData.PUBLIC_TYPES:
		return false
	var profitable := EconFinance.profit(o["pl_last"]) > 0 if not o["pl_last"].is_empty() else true
	var risk: int = o["ceo"]["risk"]
	var inspectors := int(EconUtil.lever(world, "LAW_INSPECTORS", 4))
	return profitable and (risk >= 70 or o["status"] == "DISTRESSED" or (risk >= 45 and inspectors <= 4))


## Re-validate operating facilities when law's rules version changes (and at month 0: starting licences, free).
static func revalidate(world: WorldState) -> void:
	if not law_loaded(world):
		return
	var s := EconUtil.st(world)
	var ver: int = world.values.get("LAW_RULES_VERSION", world.meta.get("LAW_RULES_VERSION", 0))
	if s.get("rules_version_seen", -1) == ver:
		return
	var first: bool = not s.has("rules_version_seen")
	s["rules_version_seen"] = ver
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES[f["type"]]
		if f["mothball"]:
			continue
		if first and r["licence"] != "":
			_apply_licence(world, f["org"], "EXTRACTION" if r["licence"] == "LICENCE_EXTRACTION" else "HAZARD", true)
			continue
		var out := {}
		var ok := true
		if f["type"] == "MINE":
			ok = allowed(world, f["org"], "EXTRACT_RESOURCE", {"resource": "MINERAL", "site_district": f["district"]}, out)
		if ok:
			ok = allowed(world, f["org"], "OPERATE_FACILITY", {"facility_type": f["type"], "district": f["district"], "hazard_class": r["hazard"]}, out)
		f["licensed"] = not out.get("unlawful", false)
		if not ok:
			f["mothball"] = true
