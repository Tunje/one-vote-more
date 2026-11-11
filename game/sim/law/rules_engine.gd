extends RefCounted
## Legal rules engine (planning/spec-law-v1.md §4–§5). Stateless; rules live in world.table("legal_rule").
##
## validate(world, actor, action, params) -> {result, trace, missing, reason}
##   actor  = {kind: COMMANDER|GOVERNMENT|PARLIAMENT|AUTHORITY|COMPANY|HOUSEHOLD|PARTY, id, ownership?}
##   result = AUTHORIZED | AUTHORIZED_WITH_CONDITIONS | REQUIRES_APPROVAL | PROHIBITED | DISPUTED | INSUFFICIENT_INFO
## Principle of legality (J2): public actors need an AUTHORIZE; private actors are free unless PROHIBITed.

const Det := preload("res://sim/staff/det.gd")
const L := preload("res://sim/law/law_data.gd")


static func era(world: WorldState) -> String:
	return String(world.peek("pol").get("state", {}).get("era", "FOUNDING"))


static func _field(world: WorldState, ctx: Dictionary, field: String):
	if field.begins_with("actor."):
		return ctx["actor"].get(field.substr(6), null)
	if field.begins_with("p."):
		return ctx["params"].get(field.substr(2), null)
	if field == "world.era":
		return era(world)
	if field == "world.month":
		return world.month
	if field == "world.caretaker":
		return bool(world.peek("pol").get("state", {}).get("caretaker", false))
	if field.begins_with("lever."):
		return world.levers.get(field.substr(6), null)
	if field.begins_with("holder.has_licence.") or field.begins_with("holder.has_permit."):
		var kind := "licence" if field.begins_with("holder.has_licence.") else "permit"
		var typ := field.get_slice(".", 2)
		return has_licence(world, String(ctx["actor"].get("id", "")), kind, typ)
	return null


static func has_licence(world: WorldState, holder: String, kind: String, typ: String) -> bool:
	var lic := world.table("licence")
	for id in Det.ordered(lic):
		var l: Dictionary = lic[id]
		if l["holder_id"] == holder and l["kind"] == kind and l["type"] == typ and l["status"] == "ACTIVE" \
				and (int(l.get("expiry_month", -1)) < 0 or int(l["expiry_month"]) > world.month \
				or String(l.get("renewal_app", "")) != ""):   # valid while a timely renewal is decided
			return true
	return false


static func _pred(world: WorldState, ctx: Dictionary, p: Dictionary) -> bool:
	var v = _field(world, ctx, p["field"])
	var x = p["value"]
	match p["op"]:
		"EQ": return _eq(v, x)
		"NEQ": return not _eq(v, x)
		"IN": return v != null and _in(v, x)
		"NIN": return v == null or not _in(v, x)
		"LT": return v != null and float(v) < float(x)
		"LTE": return v != null and float(v) <= float(x)
		"GT": return v != null and float(v) > float(x)
		"GTE": return v != null and float(v) >= float(x)
	assert(false, "unknown predicate op " + str(p["op"]))
	return false


## Type-safe equality (GDScript errors on == between e.g. int and String).
static func _eq(a, b) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if ta == tb:
		return a == b
	var nums := [TYPE_INT, TYPE_FLOAT]
	if nums.has(ta) and nums.has(tb):
		return float(a) == float(b)
	return false


static func _in(v, list: Array) -> bool:
	for x in list:
		if _eq(v, x):
			return true
	return false


static func _all(world: WorldState, ctx: Dictionary, preds: Array) -> bool:
	for p in preds:
		if not _pred(world, ctx, p):
			return false
	return true


static func _any(world: WorldState, ctx: Dictionary, preds: Array) -> bool:
	for p in preds:
		if _pred(world, ctx, p):
			return true
	return false


## Precedence key: level rank, then specificity, then effective month (spec §2).
static func _key(r: Dictionary) -> Array:
	return [int(L.LEVEL_RANK.get(r["level"], 0)), r["subject"].size() + r["where"].size(), int(r.get("effective_month", 0))]


static func _better(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false


static func matching_rules(world: WorldState, actor: Dictionary, action: String, params: Dictionary) -> Array:
	var ctx := {"actor": actor, "params": params}
	var out: Array = []
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		var r: Dictionary = rules[rid]
		if r["status"] != "ACTIVE" or (r["action"] != action and r["action"] != "*"):
			continue
		if _all(world, ctx, r["subject"]) and _all(world, ctx, r["where"]) and not _any(world, ctx, r["unless"]):
			out.append(r)
	return out


static func validate(world: WorldState, actor: Dictionary, action: String, params: Dictionary = {}) -> Dictionary:
	if action == "INTERNAL":
		return {"result": "AUTHORIZED", "trace": [], "missing": [], "reason": "internal"}
	if not L.ACTIONS.has(action) or not actor.has("kind"):
		return {"result": "INSUFFICIENT_INFO", "trace": [], "missing": [], "reason": "unknown action or actor"}
	var matched := matching_rules(world, actor, action, params)
	var best_pro: Dictionary = {}
	var best_ok: Dictionary = {}
	var superseded := {}
	for r in matched:
		for s in r["supersedes"]:
			superseded[s] = true
	for r in matched:
		if superseded.has(r["id"]):
			continue
		if r["kind"] == "PROHIBIT":
			if best_pro.is_empty() or _better(_key(r), _key(best_pro)):
				best_pro = r
		elif r["kind"] == "PERMIT" or r["kind"] == "AUTHORIZE":
			if best_ok.is_empty() or _better(_key(r), _key(best_ok)):
				best_ok = r
	var is_public: bool = L.PUBLIC_KINDS.has(actor["kind"])
	if not best_pro.is_empty():
		if best_ok.is_empty() or _better(_key(best_pro), _key(best_ok)):
			return {"result": "PROHIBITED", "trace": [best_pro["id"]], "missing": [], "reason": "prohibited"}
		if not _better(_key(best_ok), _key(best_pro)):
			return {"result": "DISPUTED", "trace": [best_pro["id"], best_ok["id"]], "missing": [], "reason": "conflicting rules"}
	if is_public and best_ok.is_empty():
		return {"result": "PROHIBITED", "trace": [], "missing": [], "reason": "no legal authority"}
	var trace: Array = [] if best_ok.is_empty() else [best_ok["id"]]
	var missing: Array = []
	var approval := ""
	for r in matched:
		if r["kind"] != "REQUIRE":
			continue
		var req: Dictionary = r["requirement"]
		if req.has("compensation_pct_min") and float(params.get("compensation_pct", 0)) < float(req["compensation_pct_min"]):
			return {"result": "PROHIBITED", "trace": trace + [r["id"]], "missing": [], "reason": "insufficient compensation"}
		if req.has("licence_type") and not has_licence(world, String(actor.get("id", "")), "licence", req["licence_type"]):
			missing.append({"licence": req["licence_type"], "rule": r["id"]})
		if req.has("permit_type") and not has_licence(world, String(actor.get("id", "")), "permit", req["permit_type"]):
			missing.append({"permit": req["permit_type"], "rule": r["id"]})
		if req.has("approval_by"):
			approval = req["approval_by"]
			trace.append(r["id"])
	if not best_ok.is_empty() and best_ok.get("defect", false):
		return {"result": "DISPUTED", "trace": trace, "missing": missing, "reason": "legally vulnerable (drafting defect)"}
	if approval != "":
		return {"result": "REQUIRES_APPROVAL", "trace": trace, "missing": missing, "reason": "approval by " + approval}
	if not missing.is_empty():
		return {"result": "AUTHORIZED_WITH_CONDITIONS", "trace": trace, "missing": missing, "reason": "missing licence/permit"}
	return {"result": "AUTHORIZED", "trace": trace, "missing": [], "reason": ""}


static func is_ok(res: Dictionary) -> bool:
	return res["result"] == "AUTHORIZED" or res["result"] == "AUTHORIZED_WITH_CONDITIONS" or res["result"] == "DISPUTED"
