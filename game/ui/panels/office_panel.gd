extends VBoxContainer
## The office, tabs view (A44 §O4): Paper · Reports · Inbox · Calls · Calendar, all read from the office channel
## (Office / office_item). Emails show who wrote them, their summary and recommendation, and the options; answering
## performs the option's action. Hidden author fields are never shown. The drawn desk view reads the same items.

const Kit := preload("res://ui/panels/panel_kit.gd")
const Gazette := preload("res://ui/panels/gazette_panel.gd")
const TABS := ["Paper", "Reports", "Inbox", "Calls", "Calendar", "Visitors"]
const SQ := preload("res://sim/staff/staff_query.gd")
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const NOTE := {"STRONGLY_RECOMMEND": "I strongly recommend", "ON_BALANCE": "On balance I'd go with", "CAREFUL": "I'd be careful; perhaps"}

var session
var tab := "Inbox"
var visited := {}   # tab -> month it was last opened (UI only; dims tabs already looked at this month)
var bar: HBoxContainer
var body: VBoxContainer
var status: Label
## Drawn desk view (A44 §O4, Terra): with the setting ui.office_view = OFFICE the panel opens on OfficeDesk; clicking
## an object shows that tab here, and "◀ Desk" goes back. The window object asks the main screen to show the colony.
signal outside_requested(view: String)   # "MAP" | "PLANET": what the desk's window showed
var desk: OfficeDesk
var desk3d: OfficeDesk3D   # made on first use (DESK3D)
var at_desk := true


func panel_title() -> String:
	return "Office"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk = OfficeDesk.new()
	desk.session = s
	desk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desk.object_clicked.connect(_on_desk)
	add_child(desk)
	bar = HBoxContainer.new()
	add_child(bar)
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	var w: WorldState = session.world()
	var view := UserSettings.office_view()
	var desk_mode := view != "TABS"
	if view == "DESK3D" and desk3d == null:
		desk3d = OfficeDesk3D.new()
		desk3d.session = session
		desk3d.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desk3d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desk3d.object_clicked.connect(_on_desk)
		desk3d.outside = desk.outside
		add_child(desk3d)
		move_child(desk3d, 1)
	desk.visible = view == "DESK2D" and at_desk
	if desk3d != null:
		desk3d.visible = view == "DESK3D" and at_desk
	var on_desk := desk.visible or (desk3d != null and desk3d.visible)
	bar.visible = not on_desk
	body.get_parent().visible = not on_desk
	if desk.visible:
		desk.refresh()
		return
	if desk3d != null and desk3d.visible:
		desk3d.refresh()
		return
	for c in bar.get_children():
		c.queue_free()
	if desk_mode:
		Kit.button(bar, "◀ Desk", func(): at_desk = true; refresh())
	visited[tab] = w.month
	for t in TABS:
		var n := _count(w, t)
		var b := Kit.button(bar, "%s%s" % [t, (" (%d)" % n) if n > 0 else ""], func(): tab = t; refresh())
		b.disabled = t == tab
		if t != tab and int(visited.get(t, -1)) == w.month:
			b.modulate = Color(1, 1, 1, 0.55)   # already looked at this month
	var hrs := Kit.label(bar, "   Office hours left: %d" % OfficeFeed.hours(w), 13, Color("#aaaaaa"))
	hrs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Kit.clear(body)
	status = Kit.status_label(body)
	if not OfficeFeed.player_office(w):
		Kit.label(body, "You don't hold the government's office right now. (The opposition desk comes later.)", 13, Color("#aaaaaa"))
	match tab:
		"Paper": _paper(w)
		"Reports": _list(w, ["REPORT"], "Nothing new on your desk.")
		"Inbox": _list(w, ["EMAIL"], "Your inbox is empty.")
		"Calls": _list(w, ["CALL"], "The phone is quiet.")
		"Calendar": _calendar(w)
		"Visitors": _visitors(w)


func _count(w: WorldState, t: String) -> int:
	match t:
		"Reports": return Office.items(w, ["REPORT"]).filter(func(o): return o["status"] == "NEW").size()
		"Inbox": return Office.items(w, ["EMAIL"]).size()
		"Calls": return Office.items(w, ["CALL"]).size()
	return 0


func _paper(w: WorldState) -> void:
	var digests := Office.items(w, ["PAPER"])
	if digests.is_empty():
		Kit.label(body, "No press digest yet. Open the Gazette for the papers themselves.", 13, Color("#aaaaaa"))
		return
	var d: Dictionary = digests[0]
	Office.mark_read(w, String(d["id"]))
	Kit.header(body, String(d.get("subject", "Press digest")))
	_author(w, d)
	for st in d.get("digest", []):
		var f: Dictionary = w.facts.get_fact(String(st.get("fact", "")))
		var head := Gazette.headline(w, f) if not f.is_empty() else String(st.get("type", ""))
		var note: String = {"SOFTENED": "  (softened)", "PLAYED_UP": "  (played up)"}.get(String(st.get("slant_note", "")), "")
		Kit.label(body, "%s — %s%s" % [String(st.get("outlet_name", "")), head, note], 13)
		if not f.is_empty():
			Kit.label(body, "    " + Gazette.plain(NewsText.sentence(w, f)), 12, Color("#cccccc"))


func _list(w: WorldState, kinds: Array, empty: String) -> void:
	var rows := Office.items(w, kinds)
	if rows.is_empty():
		Kit.label(body, empty, 13, Color("#aaaaaa"))
		return
	for o in rows:
		_item(w, o)
		Kit.sep(body)


func _item(w: WorldState, o: Dictionary) -> void:
	var dl := int(o.get("deadline", -1))
	var due := ""
	if dl >= 0:
		due = "  ·  due %s" % _month(dl) if dl > w.month else "  ·  DUE NOW"
	Kit.header(body, "%s%s%s" % ["● " if o["status"] == "NEW" else "", String(o["subject"]), due])
	_author(w, o)
	var lines: Array = o.get("summary_lines", [])
	if lines.is_empty():
		Kit.label(body, String(o.get("summary", "")), 13)
	else:
		Kit.label(body, String(o.get("summary", " ".join(lines))), 13)
	if o["kind"] == "REPORT":
		Kit.button(body, "Mark as read", func(): Office.mark_read(w, String(o["id"])); refresh())
		return
	var rec := String(o.get("recommendation", ""))
	if rec != "":
		var lbl := rec
		for x in o.get("options", []):
			if String(x.get("id", "")) == rec:
				lbl = String(x.get("label", rec))
		Kit.label(body, "%s: %s." % [NOTE.get(String(o.get("author_note", "")), "Recommended"), lbl], 12, Color("#8bc34a"))
	var row := Kit.hbox(body)
	for x in o.get("options", []):
		var oid := String(x.get("id", ""))
		Kit.button(row, String(x.get("label", oid)), func(): _answer(w, String(o["id"]), oid))
	var dflt := String(o.get("default_option", ""))
	if dflt != "" and dl >= 0:
		Kit.label(body, "If you don't answer: %s." % dflt.to_lower(), 11, Color("#aaaaaa"))


func _author(w: WorldState, o: Dictionary) -> void:
	var fr: Dictionary = o.get("from", {})
	var role := String(fr.get("role", o.get("role", ""))).replace("_", " ").capitalize()
	if String(fr.get("kind", "")) == "STAFF_ROLE" or (fr.is_empty() and role != ""):
		Kit.label(body, "From: (%s — post vacant: nobody briefed you)" % role, 12, Color("#ff8a65"))
	elif not fr.is_empty():
		var title := String(OStaff.minister_label(w, String(fr.get("role", o.get("role", "")))))
		Kit.label(body, "From: %s, %s" % [String(fr.get("name", fr.get("id", "?"))), title if title != "" else role], 12, Color("#aaaaaa"))


func _answer(w: WorldState, id: String, oid: String) -> void:
	var r := Office.answer(w, id, oid)
	if status != null:
		status.text = "Done." if r.get("ok", false) else "✗ " + String(r.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func _calendar(w: WorldState) -> void:
	var rows: Array = Office.items(w, ["CALENDAR"]) + Office.items(w, ["EMAIL", "CALL"]).filter(func(o): return int(o.get("deadline", -1)) >= 0)
	rows.sort_custom(func(a, b): return int(a.get("deadline", 0)) < int(b.get("deadline", 0)) or (a.get("deadline", 0) == b.get("deadline", 0) and String(a["id"]) < String(b["id"])))
	if rows.is_empty():
		Kit.label(body, "Nothing on the calendar.", 13, Color("#aaaaaa"))
		return
	for o in rows:
		var dl := int(o.get("deadline", 0))
		if dl > w.month + 24:
			continue
		Kit.label(body, "%s  ·  %s%s" % [_month(dl), String(o["subject"]), "  (answer due)" if o["kind"] != "CALENDAR" else ""], 13)


static func _month(m: int) -> String:
	return "%s Year %d" % [MONTHS[posmod(m, 12)], m / 12 + 1]


# ------------------------------------------------------------------ Visitors: the door (hiring by interview, A44 §O5)

const OStaff := preload("res://sim/staff/office_staff.gd")
const Q_LABEL := {"EXPERIENCE": "Tell me about your experience", "TECHNICAL": "Walk me through a hard case in your field",
	"POLITICAL": "Where do you stand on the state and the market?", "WHY_LEFT": "Why did you leave your last post?",
	"STRESS": "It's 3 a.m. and everything is failing. What do you do?", "REFERENCES": "May we contact your references? (takes a month)"}
const SAYS := {
	"EXPERIENCE_STRONG": "\"I ran that whole office for six years. I know where every file is buried.\"",
	"EXPERIENCE_SOLID": "\"A few good years in the field, and I learned something every one of them.\"",
	"EXPERIENCE_VAGUE": "\"I've… been involved in a lot of things. Various projects. Many of them.\"",
	"EXPERIENCE_WEAK": "\"Honestly? Not much yet. But I learn fast.\"",
	"TECHNICAL_STRONG": "They sketch the problem on your notepad and solve it before you finish the question.",
	"TECHNICAL_SOLID": "A careful, correct answer — a little slow, but sound.",
	"TECHNICAL_VAGUE": "They circle the question without landing.",
	"TECHNICAL_WEAK": "They get it wrong, and don't notice.",
	"POLITICAL_DODGE": "\"I serve whoever governs. My views don't come to work with me.\"",
	"POLITICAL_MARKET": "\"Let people build. The state should get out of the way more often than not.\"",
	"POLITICAL_STATE": "\"Some things are too important to leave to the market. The colony must plan.\"",
	"WHY_LEFT_STRONG": "\"They needed someone else for the next stage. We parted friends — call them.\"",
	"WHY_LEFT_SOLID": "\"I wanted something bigger. I gave them three months' notice.\"",
	"WHY_LEFT_VAGUE": "\"There were… differences. I'd rather not go into it.\"",
	"WHY_LEFT_WEAK": "\"My boss was an idiot. They all were, really.\"",
	"STRESS_STRONG": "\"Triage. Call the right three people, fix the worst thing first, sleep later.\"",
	"STRESS_SOLID": "\"I'd follow the procedure and keep you informed.\"",
	"STRESS_VAGUE": "\"I'd… escalate it? To someone?\"",
	"STRESS_WEAK": "They visibly tense up at the question.",
	"REFERENCES_REQUESTED": "\"Of course.\" You send letters; answers should come back next month.",
}
const TRAIT_TXT := {"PRIMARY": "skill in the post", "SECONDARY": "second skill", "INTEGRITY": "honesty", "RELIABILITY": "reliability",
	"LOYALTY": "loyalty", "TEMPER": "steadiness", "LEAN": "politics"}
var door := {}   # recruitment id -> shortlist index currently in the room (UI only)


func _visitors(w: WorldState) -> void:
	var recs: Array = SQ.recruitments(w)
	if recs.is_empty():
		Kit.label(body, "Nobody is waiting at the door. (Open a vacancy in Personnel to interview candidates.)", 13, Color("#aaaaaa"))
		return
	for r in recs:
		var rid := String(r["id"])
		Kit.header(body, "Vacancy: %s" % String(r["spec"]).to_lower().replace("_", " "))
		if int(r.get("picked", -1)) >= 0:
			Kit.label(body, "Filled — the new hire starts in %s." % _month(int(r.get("hire_month", w.month))), 12, Color("#8bc34a"))
			continue
		var n: int = r["shortlist"].size()
		var idx := int(door.get(rid, 0))
		var cand: Dictionary = r["shortlist"][idx]
		Kit.label(body, "Candidate %d of %d: %s" % [idx + 1, n, cand.get("name", "?")], 14)
		var iv := _interview_for(w, rid, idx)
		var row := Kit.hbox(body)
		if iv.is_empty():
			Kit.button(row, "Invite in (interview)", func(): OStaff.start_interview(w, rid, idx); refresh())
		else:
			for a in iv["asked"]:
				Kit.label(body, "You: %s" % Q_LABEL.get(String(a["q"]), String(a["q"])), 12, Color("#aaaaaa"))
				Kit.label(body, "    " + String(SAYS.get(String(a["text_key"]), "…")), 13)
			if String(iv["reference"]["status"]) == "PENDING":
				Kit.label(body, "References requested — due %s." % _month(int(iv["reference"]["due_month"])), 12, Color("#aaaaaa"))
			elif String(iv["reference"]["status"]) == "DONE":
				Kit.label(body, "References are back (see HR's notes).", 12, Color("#8bc34a"))
			var asked := {}
			for a in iv["asked"]:
				asked[String(a["q"])] = true
			var qrow := Kit.vbox(body)
			for q in OStaff.QUESTION_ORDER:
				if asked.has(q):
					continue
				Kit.button(qrow, "Ask: %s  (%d min)" % [Q_LABEL[q], int(OStaff.QUESTIONS[q]["minutes"])], func(): _ask(w, String(iv["id"]), q))
			var note: Dictionary = iv.get("hr_note", {})
			if not note.is_empty():
				var parts: Array = []
				for k in note:
					var est := int(note[k][0])
					var sd := int(note[k][1])
					if k == "LEAN":
						parts.append("politics: %s" % ("market-leaning" if est < -15000 else ("state-leaning" if est > 15000 else "hard to read")))
					else:
						parts.append("%s ~%d (±%d)" % [TRAIT_TXT.get(k, k), est, sd])
				Kit.label(body, "HR adviser's notes: " + ", ".join(parts), 12, Color("#ffd166"))
			Kit.button(row, "Offer the job", func(): _hire(w, String(iv["id"])))
		if idx + 1 < n:
			Kit.button(row, "Next candidate", func(): door[rid] = idx + 1; refresh())
		if idx > 0:
			Kit.button(row, "Previous", func(): door[rid] = idx - 1; refresh())
		Kit.sep(body)


func _interview_for(w: WorldState, rid: String, idx: int) -> Dictionary:
	for iv in w.peek("interview").values():
		if String(iv["recruitment"]) == rid and int(iv["idx"]) == idx:
			return iv
	return {}


func _ask(w: WorldState, iid: String, q: String) -> void:
	var mins := int(OStaff.QUESTIONS[q]["minutes"])
	if not OfficeFeed.spend_minutes(w, mins):
		if status != null:
			status.text = "✗ Not enough office hours left this month."
		return
	var r: Dictionary = OStaff.ask(w, iid, q)
	if status != null and not r.get("ok", false):
		status.text = "✗ " + String(r.get("reason", "failed"))
	refresh()


func _hire(w: WorldState, iid: String) -> void:
	var r: Dictionary = OStaff.hire_from_interview(w, iid)
	if status != null:
		status.text = "Offer accepted." if r.get("ok", false) else "✗ " + String(r.get("reason", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")



## A click on the drawn desk: open that tab here (or look out of the window).
func _on_desk(what: String) -> void:
	if what == "Outside":
		outside_requested.emit(desk.outside)
		return
	tab = what
	at_desk = false
	refresh()



## What the office window looks out on ("MAP" | "PLANET"), set by the main screen when the office opens.
func set_outside(v: String) -> void:
	desk.outside = v
	if desk3d != null:
		desk3d.outside = v
