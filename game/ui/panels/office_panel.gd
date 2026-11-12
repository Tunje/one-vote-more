extends VBoxContainer
## The office, tabs view (A44 §O4): Paper · Reports · Inbox · Calls · Calendar, all read from the office channel
## (Office / office_item). Emails show who wrote them, their summary and recommendation, and the options; answering
## performs the option's action. Hidden author fields are never shown. The drawn desk view reads the same items.

const Kit := preload("res://ui/panels/panel_kit.gd")
const Gazette := preload("res://ui/panels/gazette_panel.gd")
const TABS := ["Paper", "Reports", "Inbox", "Calls", "Calendar"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const NOTE := {"STRONGLY_RECOMMEND": "I strongly recommend", "ON_BALANCE": "On balance I'd go with", "CAREFUL": "I'd be careful; perhaps"}

var session
var tab := "Inbox"
var visited := {}   # tab -> month it was last opened (UI only; dims tabs already looked at this month)
var bar: HBoxContainer
var body: VBoxContainer
var status: Label


func panel_title() -> String:
	return "Office"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar = HBoxContainer.new()
	add_child(bar)
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	var w: WorldState = session.world()
	for c in bar.get_children():
		c.queue_free()
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
		Kit.label(body, "From: %s, %s" % [String(fr.get("name", fr.get("id", "?"))), role], 12, Color("#aaaaaa"))


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
