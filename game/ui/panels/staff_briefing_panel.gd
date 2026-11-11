extends VBoxContainer
## Staff briefing: decisions first (answer them here), then the monthly reports by priority (ui-staff-law §2).

const Kit := preload("res://ui/panels/panel_kit.gd")
const SQ := preload("res://sim/staff/staff_query.gd")

var session
var body: VBoxContainer
var show_routine := false
var msg := ""


func panel_title() -> String:
	return "Staff briefing"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var c := Kit.ctx(session)
	var owners: Array = []
	if c["governing"]:
		owners.append([Kit.GOV_OWNER, c["gov_actor"], "Government"])
	if c["party_id"] != "":
		owners.append([{"kind": "PARTY", "id": c["party_id"]}, c["party_actor"], "Party"])
	if msg != "":
		Kit.label(body, msg, 13, Color(1, 0.85, 0.5))
	for o in owners:
		var b: Dictionary = SQ.briefing(w, o[0], -1, c["viewer"])
		if b.is_empty():
			continue
		if not b.get("failed_actions", []).is_empty():
			Kit.header(body, "%s — orders that were NOT carried out" % o[2])
			for fa in b["failed_actions"]:
				Kit.label(body, "✗ %s%s: %s" % [String(fa["action"]).trim_prefix("ECON_").replace("_", " ").capitalize(),
					(" in " + String(fa["district"])) if fa["district"] != null else "", fa["error"]], 14, Color(1, 0.55, 0.45))
			Kit.sep(body)
		Kit.header(body, "%s — decisions" % o[2])
		if b["decisions"].is_empty():
			Kit.label(body, "No decisions waiting.", 13, Color(0.7, 0.7, 0.7))
		for d in b["decisions"]:
			Kit.label(body, d["text"], 14, Color(1, 0.8, 0.5))
			var row := Kit.hbox(body)
			for opt in d["options"]:
				Kit.button(row, opt["label"] + (" (recommended)" if opt["recommended"] else ""), func():
					var res: Dictionary = Kit.A.apply(w, {"id": "STAFF_ANSWER_DECISION", "actor": o[1],
						"args": {"request_id": d["id"], "option": opt["id"]}})
					msg = "Answered." if res.get("ok", false) else "✗ " + String(res.get("error", ""))
					get_tree().call_group("pcs_refresh", "refresh_all"))
		Kit.sep(body)
		Kit.header(body, "%s — reports for %s" % [o[2], _month_text(b["month"])])
		var collapsed := 0
		for it in b["items"]:
			if it["collapsed"] and not show_routine:
				collapsed += 1
				continue
			var col := Color.WHITE
			match it["category"]:
				"DECISION_REQUIRED": col = Color(1, 0.8, 0.5)
				"ATTENTION": col = Color(1, 0.65, 0.65)
				"COMPLETED": col = Color(0.65, 1, 0.65)
			Kit.label(body, "[%s] %s" % [it["label"], it["text"]], 13, col)
		if collapsed > 0:
			Kit.button(body, "Show %d routine reports" % collapsed, func(): show_routine = true; refresh())
		elif show_routine:
			Kit.button(body, "Hide routine reports", func(): show_routine = false; refresh())
		Kit.sep(body)


func _month_text(m: int) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	if m < 0:
		return "—"
	return "%s, Year %d" % [MONTHS[m % 12], m / 12 + 1]
