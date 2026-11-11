extends VBoxContainer
## Personnel: tasks and their positions, candidate comparison, assign/unassign, roster (ui-staff-law §1).
## Reads: SQ (staff_query). Writes: A.apply only.

const Kit := preload("res://ui/panels/panel_kit.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const SD := preload("res://sim/staff/staff_data.gd")

var session
var body: VBoxContainer
var owner_choice := "GOV"          # "GOV" | "PARTY"
var selected := {}                 # {"task_id", "pos"} position whose candidates are shown
var msg := ""


func panel_title() -> String:
	return "Personnel"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func _owner(c: Dictionary) -> Dictionary:
	if owner_choice == "PARTY" and c["party_id"] != "":
		return {"kind": "PARTY", "id": c["party_id"]}
	return Kit.GOV_OWNER


func _actor(c: Dictionary) -> Dictionary:
	return c["party_actor"] if owner_choice == "PARTY" else c["gov_actor"]


func _do(action: Dictionary) -> void:
	var res: Dictionary = Kit.A.apply(session.world(), action)
	msg = "Done." if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var c := Kit.ctx(session)
	if not c["governing"]:
		owner_choice = "PARTY"
	# --- owner switch
	var top := Kit.hbox(body)
	if c["governing"]:
		Kit.button(top, "Government staff", func(): owner_choice = "GOV"; selected = {}; refresh(), owner_choice == "GOV")
	if c["party_id"] != "":
		Kit.button(top, "My party's staff", func(): owner_choice = "PARTY"; selected = {}; refresh(), owner_choice == "PARTY")
	var owner := _owner(c)
	var sm: Dictionary = SQ.summary(w, owner, c["viewer"])
	if sm.is_empty():
		Kit.label(body, "You have no access to this staff.")
		return
	Kit.label(top, "  %d people · %d available · %d mandatory vacancies · %d decisions waiting" % [
		sm["total"], sm["available"], sm["mandatory_vacancies"], sm["decisions"]])
	var auto_row := Kit.hbox(body)
	Kit.button(auto_row, "Let my chief of staff assign people", func(): _do({"id": "STAFF_AUTO_ASSIGN", "actor": _actor(c), "args": {}}),
		sm["mandatory_vacancies"] == 0)
	Kit.label(auto_row, "fills vacant positions with the best available people (you can still change them)", 11, Color(0.7, 0.7, 0.7))
	if msg != "":
		Kit.label(body, msg, 13, Color(1, 0.85, 0.5))
	if session.autoplay():
		Kit.label(body, "AI is playing your role: it may reassign staff at month end.", 12, Color(0.7, 0.7, 0.7))
	var cols := Kit.hbox(body)
	var left := Kit.vbox(cols)
	var right := Kit.vbox(cols)
	_tasks(left, w, c, owner)
	_candidates(right, w, c)
	Kit.sep(right)
	_roster(right, w, c, owner)
	Kit.sep(left)
	_start_task(left, c, owner)


func _tasks(parent: VBoxContainer, w: WorldState, c: Dictionary, owner: Dictionary) -> void:
	Kit.header(parent, "Tasks")
	for t in SQ.tasks(w, owner, false, c["viewer"]):
		var line := "%s — %d%%%s%s" % [t["name"], t["progress_pct"], "  [PAUSED]" if t["paused"] else "",
			"  [WAITING FOR DECISION]" if t["blocked"] else ""]
		if t["category"] == "STANDING" or t["def_id"] in ["STAFF_T_SUPERVISE", "STAFF_T_CAMPAIGN"]:
			line = "%s — coverage %d%%, effectiveness %d%%" % [t["name"], t["coverage_pct"], t["effectiveness_pct"]]
		Kit.label(parent, line, 15, Color(1, 0.6, 0.6) if t["paused"] else Color.WHITE)
		var modes := Kit.hbox(parent)
		Kit.label(modes, "   mode:", 12)
		for m in ["RUSH", "NORMAL", "CAREFUL"]:
			Kit.button(modes, m.capitalize(), func(): _do({"id": "STAFF_SET_TASK_MODE", "actor": _actor(c),
				"args": {"task_id": t["id"], "mode": m}}), t["mode"] == m)
		for p in t["positions"]:
			var row := Kit.hbox(parent)
			Kit.label(row, "   %s%s (%s): " % [p["role"], " *" if p["mandatory"] else "", p["requirements"]], 13)
			if p["assigned"] != "":
				Kit.label(row, p["assigned_name"], 13, Color(0.7, 1, 0.7))
				Kit.button(row, "Unassign", func(): _do({"id": "STAFF_UNASSIGN", "actor": _actor(c), "args": {"person_id": p["assigned"]}}))
				Kit.button(row, "Replace…", func(): selected = {"task_id": t["id"], "pos": p["idx"]}; refresh())
			else:
				Kit.label(row, "vacant", 13, Color(1, 0.6, 0.6) if p["mandatory"] else Color(0.7, 0.7, 0.7))
				Kit.button(row, "Assign…", func(): selected = {"task_id": t["id"], "pos": p["idx"]}; refresh())
	Kit.label(parent, "* mandatory position: the task pauses while it is vacant.", 11, Color(0.7, 0.7, 0.7))


func _candidates(parent: VBoxContainer, w: WorldState, c: Dictionary) -> void:
	Kit.header(parent, "Candidates")
	if selected.is_empty():
		Kit.label(parent, "Pick Assign… on a position to compare candidates.", 13)
		return
	var tv: Dictionary = SQ.task_view(w, selected["task_id"], c["viewer"])
	if tv.is_empty() or tv["status"] != "ACTIVE":
		selected = {}
		return
	var pos: Dictionary = tv["positions"][selected["pos"]]
	Kit.label(parent, "%s → %s (needs %s)" % [tv["name"], pos["role"], pos["requirements"]], 14)
	for cand in SQ.candidates(w, selected["task_id"], selected["pos"], c["viewer"]):
		var row := Kit.hbox(parent)
		var busy: String = (" — now on " + cand["currently"]["task_name"]) if not cand["currently"].is_empty() else ""
		var txt := "%s  work %.1f/mo  quality %d%s%s%s" % [cand["name"], cand["est_work"], cand["est_quality"],
			("  talents: " + ", ".join(cand["talent_matches"])) if not cand["talent_matches"].is_empty() else "",
			("  [" + cand["coalition"] + "]") if cand["coalition"] != "" else "", busy]
		Kit.label(row, txt, 13, Color.WHITE if cand["eligible"] else Color(0.6, 0.6, 0.6))
		if cand["eligible"] and cand["currently"].is_empty():
			var action_id := "STAFF_REPLACE" if pos["assigned"] != "" else "STAFF_ASSIGN"
			Kit.button(row, "Assign", func():
				selected = {}
				_do({"id": action_id, "actor": _actor(c), "args": {"task_id": tv["id"], "pos": pos["idx"], "person_id": cand["person_id"]}}))
		elif not cand["eligible"]:
			Kit.label(row, "(%s)" % cand["reason"], 11, Color(0.8, 0.5, 0.5))
	Kit.button(parent, "Close", func(): selected = {}; refresh())


func _roster(parent: VBoxContainer, w: WorldState, c: Dictionary, owner: Dictionary) -> void:
	Kit.header(parent, "Roster")
	for p in SQ.roster(w, owner, c["viewer"]):
		var where: String = "available" if p["available"] else (p["assignment"].get("task_name", p["status"].to_lower()))
		Kit.label(parent, "%s (%s%s, %d) — %s — speed %d, reliability %d%s" % [p["name"], p["category"].to_lower().replace("_", " "),
			(", " + session.party_name(p["party_id"])) if p["party_id"] != "" else "", p["age"], Kit.top_skills(p["skills"]),
			p["work_speed"], p["reliability"], ("; talents: " + ", ".join(p["talents"])) if not p["talents"].is_empty() else ""],
			13, Color(0.7, 1, 0.7) if p["available"] else Color.WHITE)
		Kit.label(parent, "      → " + where, 12, Color(0.75, 0.75, 0.75))


## Start a task the owner may run (drafting and implementation are created elsewhere).
func _start_task(parent: VBoxContainer, c: Dictionary, owner: Dictionary) -> void:
	Kit.header(parent, "Start a task")
	var row := Kit.hbox(parent)
	var opt := OptionButton.new()
	var ids: Array = []
	for id in SD.TASKS:
		var d: Dictionary = SD.TASKS[id]
		if not d["owners"].has(owner["kind"]) or d["category"] in ["IMPLEMENTATION", "TRAINING"] \
				or id.begins_with("STAFF_T_DRAFT") or id in ["STAFF_T_REVISE_BILL", "STAFF_T_LEGAL_CHALLENGE", "STAFF_T_OVERSIGHT"]:
			continue
		ids.append(id)
		opt.add_item(SQ.task_name(id))
	row.add_child(opt)
	Kit.button(row, "Start", func():
		if opt.selected >= 0:
			var params := {"size": "MEDIUM"} if ids[opt.selected] == "STAFF_T_SUPERVISE" else {}
			_do({"id": "STAFF_START_TASK", "actor": _actor(c), "args": {"def_id": ids[opt.selected], "params": params}}))
