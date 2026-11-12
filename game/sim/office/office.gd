class_name Office
extends RefCounted
## The office channel (A44, planning/spec-office-v1.md §O1): every system that needs the PLAYER posts one item here —
## a newspaper, a report to read, an email to answer, an urgent call, a meeting request or a calendar entry — and
## reads the answer back. Table "office_item" (integer state, saved). AI-held offices never get items: their
## systems decide as before. Nothing is decided silently: an unanswered item expires to its default_option at its
## deadline, and the expiry is logged as a fact.
##
## item = {id, kind, from: {kind, id, role}, subject, summary, recommendation (option id or ""), options:
##   [{id, label, action}], deadline (month or -1), default_option, priority 0..100, source: {system, ref},
##   status NEW|READ|ANSWERED|DELEGATED|EXPIRED|RESOLVED, answer, month, answered_month, role (the office role that
##   authors it), category (for delegation), summary_lines, hidden: {...} (author engine only; the UI never shows it)}
## action = {} (acknowledge only) | {via: "ECON", id, params} | {via: "STAFF", id, args} — the same entry points the
## tool windows use (EconActions.enqueue, staff_law_actions.apply), so answering an email is exactly the action.

const KINDS := ["PAPER", "REPORT", "EMAIL", "CALL", "MEETING", "CALENDAR"]
const OPEN := ["NEW", "READ"]
const SA := preload("res://sim/staff/staff_law_actions.gd")
## Anni's O5 author engine (staff as authors, chief-of-staff sorting, delegation). Loaded when present.
const AUTHOR_PATH := "res://sim/staff/office_staff.gd"


static func _t(world: WorldState) -> Dictionary:
	return world.table("office_item")


## Post (or refresh) an item. One open item per source {system, ref}: posting again updates it instead of
## duplicating (a union demand that changes stays one email). Returns the item id.
static func post(world: WorldState, item: Dictionary) -> String:
	assert(item.get("kind", "") in KINDS, "office item kind")
	var src: Dictionary = item.get("source", {})
	var t := _t(world)
	if not src.is_empty():
		for id in EconUtil.sorted_keys(t):
			var o: Dictionary = t[id]
			if o["status"] in OPEN and o["source"].get("system", "") == src.get("system", "") and o["source"].get("ref", "") == src.get("ref", ""):
				for k in ["subject", "summary", "recommendation", "options", "deadline", "default_option", "priority", "summary_lines", "digest"]:
					if item.has(k):
						o[k] = item[k]
				return id
	var nid := world.new_id("office")
	var fresh := {"id": nid, "kind": item["kind"], "from": item.get("from", {}), "subject": String(item.get("subject", "")),
		"summary": String(item.get("summary", "")), "recommendation": String(item.get("recommendation", "")),
		"options": item.get("options", []).duplicate(true), "deadline": int(item.get("deadline", -1)),
		"default_option": String(item.get("default_option", "")), "priority": clampi(int(item.get("priority", 50)), 0, 100),
		"source": src.duplicate(), "status": "NEW", "answer": "", "month": world.month, "answered_month": -1,
		"role": String(item.get("role", "")), "summary_lines": item.get("summary_lines", []).duplicate(),
		"category": String(item.get("category", "")),
		"digest": item.get("digest", []).duplicate(true),   # PAPER items: the press secretary's stories (O5)
		# hidden: owned by the staff author engine (true_priority, merit/lean per option, truth, buried). Never shown.
		"hidden": item.get("hidden", {}).duplicate(true)}
	if ResourceLoader.exists(AUTHOR_PATH):
		load(AUTHOR_PATH).author_item(world, fresh)
	t[nid] = fresh
	return nid


## Items, newest first within priority. Pure read.
static func items(world: WorldState, kinds: Array = [], open_only: bool = true) -> Array:
	var out: Array = []
	for o in world.peek("office_item").values():
		if not kinds.is_empty() and not (o["kind"] in kinds):
			continue
		if open_only and not (o["status"] in OPEN):
			continue
		out.append(o)
	out.sort_custom(func(a, b): return int(a["priority"]) > int(b["priority"]) or (a["priority"] == b["priority"] and (int(a["month"]) > int(b["month"]) or (a["month"] == b["month"] and String(a["id"]) > String(b["id"])))))
	return out


static func get_item(world: WorldState, id: String) -> Dictionary:
	return world.peek("office_item").get(id, {})


## Urgent items that block a quiet end of month: open CALLs and EMAILs at or past their deadline.
static func blocking(world: WorldState) -> Array:
	return items(world, ["CALL", "EMAIL"]).filter(func(o): return o["kind"] == "CALL" or (int(o["deadline"]) >= 0 and int(o["deadline"]) <= world.month))


static func mark_read(world: WorldState, id: String) -> void:
	var o: Dictionary = _t(world).get(id, {})
	if not o.is_empty() and o["status"] == "NEW":
		o["status"] = "READ"


## Answer an item with one of its options: performs the option's action through the normal entry point.
static func answer(world: WorldState, id: String, option_id: String, by: String = "PLAYER") -> Dictionary:
	var o: Dictionary = _t(world).get(id, {})
	if o.is_empty():
		return {"ok": false, "error": "No such item"}
	if not (o["status"] in OPEN):
		return {"ok": false, "error": "Already dealt with"}
	var opt := {}
	for x in o["options"]:
		if String(x.get("id", "")) == option_id:
			opt = x
	if opt.is_empty() and not o["options"].is_empty():
		return {"ok": false, "error": "No such option"}
	var r := _do(world, opt.get("action", {}))
	if not r.get("ok", false):
		return r
	o["status"] = "ANSWERED" if by in ["PLAYER", "AI"] else "DELEGATED"
	o["answered_by"] = by
	o["answer"] = option_id
	o["answered_month"] = world.month
	return {"ok": true, "error": ""}


## The source system settled the matter elsewhere (e.g. a dispute ended): the item closes without an answer.
static func resolve(world: WorldState, system: String, ref: String) -> void:
	for o in _t(world).values():
		if o["status"] in OPEN and o["source"].get("system", "") == system and o["source"].get("ref", "") == ref:
			o["status"] = "RESOLVED"
			o["answered_month"] = world.month


## DECISIONS phase: past-deadline items fall to their default option (logged as a fact); old read-only items
## (PAPER, REPORT, CALENDAR) are archived after 6 months.
static func expire(world: WorldState) -> void:
	var t := _t(world)
	for id in EconUtil.sorted_keys(t):
		var o: Dictionary = t[id]
		if not (o["status"] in OPEN):
			continue
		if o["kind"] in ["PAPER", "REPORT", "CALENDAR"]:
			if world.month - int(o["month"]) >= 6:
				o["status"] = "RESOLVED"
			continue
		if int(o["deadline"]) < 0 or int(o["deadline"]) >= world.month:
			continue
		var dflt := String(o["default_option"])
		var opt := {}
		for x in o["options"]:
			if String(x.get("id", "")) == dflt:
				opt = x
		if not opt.is_empty():
			_do(world, opt.get("action", {}))
		o["status"] = "EXPIRED"
		o["answer"] = dflt
		o["answered_month"] = world.month
		world.add_fact({"type": "OFFICE_ITEM_EXPIRED", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
			"impact": {"GOVERNANCE": -1}, "magnitude": 20, "visibility": "OFFICIAL",
			"data": {"item": id, "kind": o["kind"], "subject": o["subject"], "default": dflt, "label": String(opt.get("label", dflt)), "source": o["source"].duplicate()}})


static func _do(world: WorldState, action: Dictionary) -> Dictionary:
	match String(action.get("via", "")):
		"":
			return {"ok": true, "error": ""}
		"ECON":
			return EconActions.enqueue(world, String(action["id"]), action.get("params", {}))
		"STAFF":
			return SA.apply(world, {"id": String(action["id"]), "actor": action.get("actor", {"kind": "GOVERNMENT", "id": "government"}), "args": action.get("args", {})})
	return {"ok": false, "error": "Unknown action route"}
