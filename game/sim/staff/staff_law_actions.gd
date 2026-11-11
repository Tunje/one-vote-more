extends RefCounted
## The single entry point for every staff/law state change made by the UI or an AI (pic-core §6: same actions
## for player and AI). apply() validates ownership, performs the op immediately (planning phase), and logs it in
## world.table("action_log"). Returns {ok, error?, ...result}.
##
## action = {"id": ACTION_ID, "actor": {"kind": "GOVERNMENT"|"PARTY"|"COMMANDER", "id"}, "args": {...}}

const Ops := preload("res://sim/staff/staff_ops.gd")
const D := preload("res://sim/staff/staff_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")

## pic-core §6 schema (abridged; costs in W_ref). Providers return these from action_defs().
const ACTION_DEFS := [
	{"id": "STAFF_ASSIGN", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["task_id", "pos", "person_id"]},
	{"id": "STAFF_UNASSIGN", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["person_id"]},
	{"id": "STAFF_REPLACE", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["task_id", "pos", "person_id"]},
	{"id": "STAFF_START_TASK", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {"credits": "per task"}, "legalAction": "INTERNAL", "args": ["def_id", "params"]},
	{"id": "STAFF_AUTO_ASSIGN", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": []},
	{"id": "STAFF_CANCEL_TASK", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["task_id"]},
	{"id": "STAFF_SET_TASK_MODE", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["task_id", "mode"]},
	{"id": "STAFF_SET_AUTHORITY_PRESET", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["task_id", "preset"]},
	{"id": "STAFF_ANSWER_DECISION", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["request_id", "option"]},
	{"id": "STAFF_APPOINT_POLITICAL", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "COMMANDER"], "cost": {}, "legalAction": "APPOINT_OFFICIAL", "args": ["seat_id", "person_id"]},
	{"id": "STAFF_DISMISS_POLITICAL", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "COMMANDER"], "cost": {}, "legalAction": "DISMISS_OFFICIAL", "args": ["person_id"]},
	{"id": "STAFF_SET_RECRUITMENT_SPEC", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["recruitment_id", "spec"]},
	{"id": "STAFF_HIRE_CIVIL_SERVANT", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "APPOINT_OFFICIAL", "args": ["recruitment_id", "candidate"]},
	{"id": "STAFF_TRAIN", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {"credits": 10, "staffTask": "STAFF_T_TRAINING"}, "legalAction": "INTERNAL", "args": ["person_id", "skill"]},
	{"id": "STAFF_REQUEST_DRAFTING", "owner": "staff", "actors": ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"], "cost": {"staffTask": "STAFF_T_DRAFT_BILL"}, "legalAction": "INTERNAL", "args": ["bill_id", "clauses"]},
	{"id": "LAW_DECREE", "owner": "law", "actors": ["PLAYER_GOV", "AI_GOV"], "cost": {"staffTask": "STAFF_T_IMPL_*"}, "legalAction": "SET_LEVER", "args": ["lever", "value", "confirm_unlawful"]},
	{"id": "OPP_START_OVERSIGHT", "owner": "staff", "actors": ["PARTY", "OPPOSITION"], "cost": {"staffTask": "STAFF_T_OVERSIGHT"}, "legalAction": "INTERNAL", "args": ["domain"]},
	{"id": "OPP_FILE_CHALLENGE", "owner": "law", "actors": ["PARTY", "OPPOSITION"], "cost": {"staffTask": "STAFF_T_LEGAL_CHALLENGE"}, "legalAction": "INTERNAL", "args": ["option (from opposition options)"]},
	{"id": "LAW_RESTART_IMPLEMENTATION", "owner": "law", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": ["source_bill"]},
	{"id": "LAW_DECLARE_EMERGENCY", "owner": "law", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "DECLARE_EMERGENCY", "args": ["kind (FOOD|HEALTH|POWER|GENERAL)"]},
	{"id": "LAW_END_EMERGENCY", "owner": "law", "actors": ["PLAYER_GOV", "AI_GOV", "COMMANDER"], "cost": {}, "legalAction": "INTERNAL", "args": []},
]


static func _owner(actor: Dictionary) -> Dictionary:
	if actor.get("kind", "") == "PARTY":
		return {"kind": "PARTY", "id": actor["id"]}
	return Ops.GOV   # GOVERNMENT and COMMANDER both run the government's staff


static func _owns_task(actor: Dictionary, tid: String, world: WorldState) -> bool:
	var t := Ops.task(world, tid)
	return not t.is_empty() and Ops.owner_key(t["owner"]) == Ops.owner_key(_owner(actor))


static func _owns_person(actor: Dictionary, pid: String, world: WorldState) -> bool:
	return Ops.pool_members(world, _owner(actor)).has(pid)


static func apply(world: WorldState, action: Dictionary) -> Dictionary:
	var res := _apply(world, action)
	var id := world.new_id("action")
	world.table("action_log")[id] = {"id": id, "month": world.month, "action": action.get("id", ""),
		"actor": action.get("actor", {}).duplicate(), "args": action.get("args", {}).duplicate(true), "ok": res.get("ok", false),
		"error": res.get("error", "")}
	return res


static func _err(msg: String) -> Dictionary:
	return {"ok": false, "error": msg}


static func _wrap(r: Dictionary) -> Dictionary:
	if r.get("ok", false):
		return r
	return {"ok": false, "error": String(r.get("reason", r.get("error", "failed")))}


static func _apply(world: WorldState, action: Dictionary) -> Dictionary:
	var a: Dictionary = action.get("args", {})
	var actor: Dictionary = action.get("actor", {})
	match String(action.get("id", "")):
		"STAFF_ASSIGN":
			if not _owns_task(actor, a["task_id"], world):
				return _err("not your task")
			return _wrap(Ops.assign(world, a["task_id"], int(a["pos"]), a["person_id"]))
		"STAFF_UNASSIGN":
			if not _owns_person(actor, a["person_id"], world):
				return _err("not your staff")
			return _wrap(Ops.unassign(world, a["person_id"]))
		"STAFF_REPLACE":
			if not _owns_task(actor, a["task_id"], world):
				return _err("not your task")
			return _wrap(Ops.replace(world, a["task_id"], int(a["pos"]), a["person_id"]))
		"STAFF_AUTO_ASSIGN":
			# "Let my chief of staff assign people": the same algorithm the AI uses, for the actor's own staff.
			var before := Ops.open_positions_count(world, _owner(actor))
			Ops.auto_staff(world, _owner(actor))
			return {"ok": true, "filled": before - Ops.open_positions_count(world, _owner(actor))}
		"STAFF_START_TASK":
			return _wrap(Ops.create_task(world, a["def_id"], a.get("params", {}), _owner(actor)))
		"STAFF_CANCEL_TASK":
			if not _owns_task(actor, a["task_id"], world):
				return _err("not your task")
			if D.TASKS[Ops.task(world, a["task_id"])["def_id"]]["category"] == "IMPLEMENTATION":
				return _err("implementation tasks end when the law is repealed (or stall if unstaffed)")
			return _wrap(Ops.cancel_task(world, a["task_id"]))
		"STAFF_SET_TASK_MODE":
			if not _owns_task(actor, a["task_id"], world) or not D.MODE_W.has(String(a["mode"])):
				return _err("invalid")
			Ops.set_mode(world, a["task_id"], a["mode"])
			return {"ok": true}
		"STAFF_SET_AUTHORITY_PRESET":
			if not _owns_task(actor, a["task_id"], world) or not D.PRESETS.has(String(a["preset"])):
				return _err("invalid")
			Ops.set_preset(world, a["task_id"], a["preset"])
			return {"ok": true}
		"STAFF_ANSWER_DECISION":
			var r: Dictionary = world.table("decision_request").get(a["request_id"], {})
			if r.is_empty() or not _owns_task(actor, r["task_id"], world):
				return _err("not your decision")
			return _wrap(Ops.answer_decision(world, a["request_id"], a["option"]))
		"STAFF_APPOINT_POLITICAL":
			var seat: Dictionary = world.table("gov_seat").get(a["seat_id"], {})
			var my_party := String(actor.get("id", "")) if actor.get("kind", "") == "PARTY" else Ops.player_party(world)
			if seat.is_empty() or (seat["party_id"] != "" and seat["party_id"] != my_party):
				return _err("this seat belongs to another party")
			return _wrap(Ops.appoint_political(world, a["seat_id"], a["person_id"]))
		"STAFF_DISMISS_POLITICAL":
			var party := String(actor.get("id", "")) if actor.get("kind", "") == "PARTY" else String(Ops.person(world, a["person_id"]).get("party_id", ""))
			if actor.get("kind", "") != "PARTY" and party != Ops.player_party(world) and party != "":
				return _err("you can only dismiss your own party's officials")
			return _wrap(Ops.dismiss_political(world, a["person_id"], party))
		"STAFF_SET_RECRUITMENT_SPEC":
			if actor.get("kind", "") == "PARTY":
				return _err("only the government recruits civil servants")
			Ops.set_recruitment_spec(world, a["recruitment_id"], a["spec"])
			return {"ok": true}
		"STAFF_HIRE_CIVIL_SERVANT":
			if actor.get("kind", "") == "PARTY":
				return _err("only the government recruits civil servants")
			return _wrap(Ops.pick_candidate(world, a["recruitment_id"], int(a["candidate"])))
		"STAFF_TRAIN":
			if not _owns_person(actor, a["person_id"], world):
				return _err("not your staff")
			return _wrap(Ops.train(world, a["person_id"], a["skill"], _owner(actor)))
		"STAFF_REQUEST_DRAFTING":
			var pv := LQ.preview_clauses(world, a["clauses"])
			if not pv["ok"]:
				return {"ok": false, "error": "a clause fails the legal check", "preview": pv}
			var bill_id: String = String(a.get("bill_id", ""))
			if bill_id == "":
				bill_id = world.new_id("bill")   # player-initiated draft: politics submits it later by this id
			var r := _wrap(Ops.request_drafting(world, _owner(actor), bill_id, a["clauses"]))
			if r.get("ok", false):
				r["bill_id"] = bill_id
			return r
		"LAW_DECREE":
			return _decree(world, actor, a)
		"LAW_DECLARE_EMERGENCY", "LAW_END_EMERGENCY":
			if not (actor.get("kind", "") in ["GOVERNMENT", "COMMANDER"]):
				return _err("only the government (or the commander) declares or ends a state of emergency")
			if action["id"] == "LAW_END_EMERGENCY":
				LawOps.end_emergency(world, "ENDED_BY_GOVERNMENT")
				return {"ok": true}
			return _wrap(LawOps.declare_emergency(world, String(a.get("kind", "GENERAL")), actor))
		"LAW_RESTART_IMPLEMENTATION":
			LawOps.restart_implementation(world, a["source_bill"])
			return {"ok": true}
		"OPP_START_OVERSIGHT", "OPP_FILE_CHALLENGE":
			var Opp = preload("res://sim/staff/opposition.gd")
			if actor.get("kind", "") != "PARTY" or preload("res://sim/law/visibility.gd").role(world, actor["id"]) == "GOVERNING":
				return _err("only parties outside government hold inquiries or challenge the government")
			if action["id"] == "OPP_START_OVERSIGHT":
				return _wrap(Opp.start_oversight(world, actor["id"], a["domain"]))
			return _wrap(Opp.start_challenge(world, actor["id"], a["option"]))
	return _err("unknown action " + str(action.get("id", "")))


## Government decision on a lever (ADMIN level). Lawful -> enactment through the normal pipeline.
## Unlawful -> only with confirm_unlawful: recorded as a SECRET unlawful act, then implemented like any decision.
static func _decree(world: WorldState, actor: Dictionary, a: Dictionary) -> Dictionary:
	if actor.get("kind", "") != "GOVERNMENT":
		return _err("only the government can decree")
	var chk := LQ.decree_check(world, a["lever"], a["value"])
	if not chk["allowed"]:
		return {"ok": false, "error": chk["warning"] if chk["warning"] != "" else "; ".join(chk["errors"]), "check": chk}
	var id := world.new_id("enact")
	var level := LQ.decree_level(world, a["lever"])
	var row := {"id": id, "lever": a["lever"], "value": a["value"], "legal_level": level, "source_bill": "",
		"decided_month": world.month, "earliest_effective_month": world.month + 1, "status": "PENDING"}
	if not chk["lawful"]:
		if not a.get("confirm_unlawful", false):
			return {"ok": false, "error": "unlawful decree needs confirmation", "needs_confirmation": true, "warning": chk["warning"]}
		var d: Dictionary = world.lever_defs[a["lever"]]
		var r := LawOps.proceed_unlawfully(world, LawOps.GOVERNMENT, "SET_LEVER", {"lever_id": a["lever"],
			"instrument_level": level, "lever_level": d["legalLevel"], "founding_era": d["foundingEra"],
			"lawful_value": LawOps.legal_value(world, a["lever"])}, String(a.get("executor", "")), a.get("burdened", {}),
			String(a.get("penalty_class", "SERIOUS")))
		if not r["ok"]:
			return _err(r["reason"])
		row["unlawful"] = true
		row["unlawful_fact"] = r["fact"]
	world.table("enactment")[id] = row
	return {"ok": true, "enactment": id, "lawful": chk["lawful"]}
