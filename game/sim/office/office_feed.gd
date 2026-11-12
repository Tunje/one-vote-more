class_name OfficeFeed
extends RefCounted
## Feeds the office channel (A44 §O1/§O6) from systems that already need the player, while the player holds the
## office. Runs at the end of the POLITICS phase each month; closes items whose source settled elsewhere.
## v1 feeds: public-sector union demands (EMAIL, LABOUR_LIAISON), staff decision requests (EMAIL, the task lead),
## staff reports (REPORT), and the calendar. Other systems post through Office.post themselves as they migrate.

const SQ := preload("res://sim/staff/staff_query.gd")
const KIND_TXT := {"WAGE": "a pay rise", "SAFETY": "safer workplaces", "JOBS": "no job cuts", "RECOGNITION": "recognition"}
const HOURS_PER_MONTH := 40


## Whether the player holds the government's office now (the founding commander counts when the player commands).
static func player_office(world: WorldState) -> bool:
	return not world.table("econ").has("s") or EconEssentials.human_governs(world)


## Every government governs through the office (user, 2026-11-13: "the AI parties in game need to use the cabinet
## too"): items are posted whoever governs; when the AI holds the office, its First Minister answers them the same
## month on the responsible minister's advice, overruling it only when it runs strongly against the government's
## ideology. A weak or partisan minister gives the AI the same bad advice it would give the player.
static func monthly(world: WorldState) -> void:
	_union_demands(world)
	if player_office(world):
		_decisions(world)
		_calendar(world)
	else:
		ai_answer(world)


## The AI First Minister answers open EMAILs and CALLs: the minister's recommendation unless the government's
## ideology strongly favours another option (lean · centre).
static func ai_answer(world: WorldState) -> void:
	var g: Dictionary = world.table("pol")["state"].get("government", {})
	if g.is_empty():
		return
	var centre: Dictionary = g.get("center", {})
	for o in Office.items(world, ["EMAIL", "CALL"]):
		var opts: Array = o.get("options", [])
		if opts.is_empty():
			continue
		var rec := String(o.get("recommendation", ""))
		var hid: Dictionary = o.get("hidden", {}).get("options", {})
		var best := ""
		var best_v := -INF
		for x in opts:
			var oid := String(x.get("id", ""))
			var v := (1.0 if oid == rec else 0.0)
			var lean: Dictionary = hid.get(oid, {}).get("lean", {})
			for ax in lean:
				v += float(lean[ax]) / 1000.0 * float(centre.get(ax, 0)) / 100000.0 * 2.0
			if v > best_v or (v == best_v and oid < best):
				best_v = v
				best = oid
		if best != "":
			Office.answer(world, String(o["id"]), best, "AI")


## Office hours left this month (meetings, interviews and some answers spend them).
static func hours(world: WorldState) -> int:
	var st: Dictionary = world.table("pol")["state"]
	if int(st.get("office_hours_month", -1)) != world.month:
		return HOURS_PER_MONTH
	return int(st.get("office_hours", HOURS_PER_MONTH))


## Interview and meeting minutes: they add up, and every full hour comes off the month's office hours.
static func spend_minutes(world: WorldState, m: int) -> bool:
	var st: Dictionary = world.table("pol")["state"]
	var acc := int(st.get("office_minutes", 0)) if int(st.get("office_hours_month", -1)) == world.month else 0
	var total := acc + m
	var hours_needed := total / 60
	if hours_needed > 0 and not spend_hours(world, hours_needed):
		return false
	st["office_minutes"] = total % 60
	st["office_hours_month"] = world.month
	if not st.has("office_hours") or int(st.get("office_hours_month", -1)) != world.month:
		st["office_hours"] = hours(world)
	return true


static func spend_hours(world: WorldState, h: int) -> bool:
	var st: Dictionary = world.table("pol")["state"]
	var left := hours(world)
	if h > left:
		return false
	st["office_hours"] = left - h
	st["office_hours_month"] = world.month
	return true


static func _union_demands(world: WorldState) -> void:
	var open := {}
	for d in UnionDisputes.pending_demands(world, "gov"):
		var did := String(d["id"])
		open[did] = true
		var u: Dictionary = world.peek("union").get(String(d.get("union", "")), {})
		var striking := String(d.get("status", "")) == "STRIKE"
		var size := int(d.get("size_pm", 0))
		var opts: Array = [
			{"id": "ACCEPT", "label": "Accept", "action": {"via": "ECON", "id": "ECON_ANSWER_UNION_DEMAND", "params": {"demand": did, "answer": "ACCEPT"}}},
			{"id": "REFUSE", "label": "Refuse", "action": {"via": "ECON", "id": "ECON_ANSWER_UNION_DEMAND", "params": {"demand": did, "answer": "REFUSE"}}}]
		if String(d.get("kind", "")) == "WAGE" and size > 1:
			opts.insert(1, {"id": "COUNTER", "label": "Counter-offer (+%.1f%%)" % (float(size / 2) / 10.0),
				"action": {"via": "ECON", "id": "ECON_ANSWER_UNION_DEMAND", "params": {"demand": did, "answer": "COUNTER", "counter_pm": size / 2}}})
		var lines: Array = ["The %s (%d members) demands %s%s." % [u.get("name", "union"), int(u.get("members", 0)) / 1000, KIND_TXT.get(String(d.get("kind", "")), "a deal"),
			(" of %.1f%%" % (float(size) / 10.0)) if String(d.get("kind", "")) == "WAGE" else ""],
			"Their leader %s is %s; the union's mood is %d/100 and its fund covers %d weeks of strike pay." % [u.get("leader", {}).get("name", "?"),
				"militant" if int(u.get("leader", {}).get("militancy", 50)) >= 70 else ("moderate" if int(u.get("leader", {}).get("militancy", 50)) < 45 else "pragmatic"),
				int(u.get("mood", 0)), int(Unions.strike_weeks(world, String(u.get("id", ""))))]]
		if striking:
			lines.append("They are ON STRIKE: public services are cut until this is settled.")
		Office.post(world, {"kind": "CALL" if striking else "EMAIL", "role": "LABOUR_LIAISON", "category": "UNION_DEMAND",
			"subject": ("STRIKE: " if striking else "") + "%s demands %s" % [u.get("name", "A union"), KIND_TXT.get(String(d.get("kind", "")), "a deal")],
			"summary": " ".join(lines), "summary_lines": lines, "options": opts, "deadline": int(d.get("deadline", -1)) if not striking else -1,
			"default_option": "REFUSE", "priority": 85 if striking else 60, "source": {"system": "UNION", "ref": did},
			"hidden": {"true_priority": 90 if striking else 65, "options": _union_merits(u, striking)}})
	for o in Office.items(world, ["EMAIL", "CALL"]):
		if o["source"].get("system", "") == "UNION" and not open.has(String(o["source"].get("ref", ""))):
			Office.resolve(world, "UNION", String(o["source"]["ref"]))


static func _decisions(world: WorldState) -> void:
	var open := {}
	for r in SQ.decision_requests(world, {"kind": "GOVERNMENT", "id": "government"}):
		var rid := String(r.get("id", ""))
		open[rid] = true
		var opts: Array = []
		var rec := ""
		for op in r.get("options", []):
			var oid := String(op.get("id", ""))
			if op.get("recommended", false):
				rec = oid
			opts.append({"id": oid, "label": String(op.get("label", oid)), "action": {"via": "STAFF", "id": "STAFF_ANSWER_DECISION", "args": {"request_id": rid, "option": oid}}})
		Office.post(world, {"kind": "EMAIL", "role": "CHIEF_OF_STAFF", "category": "STAFF_DECISION", "subject": "%s needs your decision" % String(r.get("kind", "A task")).capitalize(),
			"summary": String(r.get("text", "A task needs your decision before it can continue.")), "options": opts,
			"recommendation": rec, "deadline": int(r.get("month", world.month)) + 2,
			"default_option": rec, "priority": 50, "source": {"system": "STAFF_DECISION", "ref": rid}})
	for o in Office.items(world, ["EMAIL"]):
		if o["source"].get("system", "") == "STAFF_DECISION" and not open.has(String(o["source"].get("ref", ""))):
			Office.resolve(world, "STAFF_DECISION", String(o["source"]["ref"]))


## Calendar: the next election, the expected ship, and open deadlines (one entry per source, refreshed).
static func _calendar(world: WorldState) -> void:
	var st: Dictionary = world.table("pol")["state"]
	if int(st.get("next_election", -1)) > world.month:
		Office.post(world, {"kind": "CALENDAR", "subject": "General election", "summary": "Election day.", "deadline": int(st["next_election"]),
			"priority": 40, "source": {"system": "CALENDAR", "ref": "election"}})
	if world.table("econ").has("s"):
		var ship := int(EconTrade.next_ship(world))
		if ship >= world.month:
			Office.post(world, {"kind": "CALENDAR", "subject": "Ship from the home world (expected)", "summary": "Ships come every 18–30 months; the date is an estimate.",
				"deadline": ship, "priority": 30, "source": {"system": "CALENDAR", "ref": "ship"}})


## The system's own judgement of each answer (hidden; the staff author weighs it against their leanings): an angry,
## well-funded union is worth settling with; a calm or broke one can be refused. Leans: giving in is pro-labour.
static func _union_merits(u: Dictionary, striking: bool) -> Dictionary:
	var mood := int(u.get("mood", 50))
	var fight := (mood - 50) + (25 if striking else 0)
	return {"ACCEPT": {"merit": clampi(fight, -100, 100), "lean": {"REDISTRIBUTION": 400, "ECON_ROLE": 200}},
		"COUNTER": {"merit": clampi(20 + fight / 3, -100, 100), "lean": {}},
		"REFUSE": {"merit": clampi(-fight, -100, 100), "lean": {"REDISTRIBUTION": -400, "ECON_ROLE": -200}}}
