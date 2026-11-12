extends VBoxContainer
## Unions (spec-unions-v1 §5, A41): the federation and every union — members, density, fund, leader, mood — their
## open demands and disputes, and the party each one backs. When the player governs, public-sector demands
## (employer "gov") are answered here: nothing is settled on the player's behalf. Read-only otherwise.

const Kit := preload("res://ui/panels/panel_kit.gd")
const Gazette := preload("res://ui/panels/gazette_panel.gd")
const EVENTS := {"UNION_FOUNDED": "founded", "UNION_LEADER_ELECTED": "new leader", "UNION_MERGED": "merger",
	"UNION_SPLIT": "breakaway", "UNION_DEMAND": "demand", "UNION_SETTLED": "settled", "UNION_TALKS_FAILED": "talks failed",
	"UNION_STRIKE_CALLED": "strike", "UNION_STRIKE_COLLAPSED": "strike collapsed", "UNION_ENDORSEMENT_WITHDRAWN": "endorsement withdrawn"}
const KIND_TEXT := {"WAGE": "a pay rise", "SAFETY": "safer workplaces", "JOBS": "no job cuts", "RECOGNITION": "recognition"}

var session
var body: VBoxContainer
var status: Label
var counter := {}   # demand id -> SpinBox


func panel_title() -> String:
	return "Unions"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	counter.clear()
	var w: WorldState = session.world()
	var rows: Array = w.peek("union").values().filter(func(u): return String(u.get("status", "")) == "ACTIVE")
	if rows.is_empty():
		Kit.label(body, "Workers organise unions once the colony's first year of work is done.", 14)
		return
	status = Kit.status_label(body)
	_demands(w)
	rows.sort_custom(func(a, b): return (a.get("federation", false) and not b.get("federation", false)) or (a.get("federation", false) == b.get("federation", false) and int(a.get("members", 0)) > int(b.get("members", 0))) or (a.get("federation", false) == b.get("federation", false) and int(a.get("members", 0)) == int(b.get("members", 0)) and String(a["id"]) < String(b["id"])))
	var endorse: Dictionary = _endorsements(w)
	for u in rows:
		_union(w, u, endorse)
		Kit.sep(body)
	_history(w)


func _union(w: WorldState, u: Dictionary, endorse: Dictionary) -> void:
	var fed: bool = u.get("federation", false)
	Kit.header(body, "%s%s" % [u["name"], "  (federation)" if fed else ""])
	var acct := String(u.get("acct", ""))
	var fund := w.ledger.balance(acct) / 1000 if acct != "" and w.ledger.has_account(acct) else 0
	if fed:
		var aff := w.peek("union").values().filter(func(x): return String(x.get("affiliated_to", "")) == String(u["id"]) and x.get("status", "") == "ACTIVE")
		Kit.label(body, "%d affiliated unions · fund %d cr · founded Year %d" % [aff.size(), fund, int(u.get("founded", 0)) / 12 + 1], 12, Color("#aaaaaa"))
	else:
		var secs: Array = u.get("sectors", []).map(func(o): return String(o).to_lower().replace("_", " "))
		Kit.label(body, "%s · %d members (%d%% of the sector) · fund %d cr (%s of strike pay)%s" % [
			", ".join(secs), int(u.get("members", 0)) / 1000, int(u.get("density", 0)) / 10, fund, _weeks(w, u),
			"" if String(u.get("affiliated_to", "")) != "" else " · not affiliated"], 12, Color("#aaaaaa"))
	var l: Dictionary = u.get("leader", {})
	if not l.is_empty():
		Kit.label(body, "Leader %s since Year %d — %s, competence %d" % [l.get("name", "?"), int(l.get("since", 0)) / 12 + 1, _temper(int(l.get("militancy", 50))), int(l.get("competence", 50))], 13)
	var mood := int(u.get("mood", 0))
	var mtxt := "calm" if mood < 35 else ("restless" if mood < 65 else "angry")
	var last := String(u.get("last_strike_result", ""))
	Kit.label(body, "Mood: %s (%d/100)%s" % [mtxt, mood, ("  ·  last strike: " + last.to_lower()) if last != "" else ""], 12, Color("#ff8a65") if mood >= 65 else Color.WHITE)
	var pid := String(endorse.get(String(u["id"]), ""))
	if pid != "":
		Kit.label(body, "Backs: %s" % NewsText.party(w, pid), 12)


func _weeks(w: WorldState, u: Dictionary) -> String:
	var n := int(Unions.strike_weeks(w, String(u["id"])))
	return "%d week%s" % [n, "" if n == 1 else "s"]


static func _temper(m: int) -> String:
	if m >= 70:
		return "militant"
	if m >= 45:
		return "pragmatic"
	return "moderate"


## Endorsements per union (Ella's U3: PartyLife.endorsements()["unions"], federation under its own id).
func _endorsements(w: WorldState) -> Dictionary:
	var e: Dictionary = PartyLife.endorsements(w)
	var out: Dictionary = (e.get("unions", {}) as Dictionary).duplicate()
	var fed: Dictionary = Unions.federation(w)
	if not fed.is_empty() and String(e.get("federation", e.get("union", ""))) != "":
		out[String(fed["id"])] = String(e.get("federation", e.get("union", "")))
	return out


## Open demands; public-sector ones can be answered by the player while governing.
func _demands(w: WorldState) -> void:
	var open: Array = w.peek("union_demand").values().filter(func(d): return String(d.get("status", "")) in ["OPEN", "STRIKE"])
	if open.is_empty():
		return
	open.sort_custom(func(a, b): return int(a.get("made", 0)) < int(b.get("made", 0)) or (int(a.get("made", 0)) == int(b.get("made", 0)) and String(a["id"]) < String(b["id"])))
	Kit.header(body, "Open demands and disputes")
	var c := Kit.ctx(session)
	for d in open:
		var u: Dictionary = w.peek("union").get(String(d.get("union", "")), {})
		var emp := String(d.get("employer", ""))
		var who := "the government (public sector)" if emp == "gov" else NewsText.org(w, emp)
		var striking := String(d["status"]) == "STRIKE"
		Kit.label(body, "%s%s demands %s from %s%s — %s" % ["⚠ ON STRIKE: " if striking else "", u.get("name", "A union"), KIND_TEXT.get(String(d.get("kind", "")), "a deal"), who,
			(" (+%.1f%%)" % (float(d.get("size_pm", 0)) / 10.0)) if String(d.get("kind", "")) == "WAGE" else "",
			"deadline %s" % _month(int(d.get("deadline", 0)))], 13, Color("#ff5252") if striking else Color.WHITE)
		if emp == "gov" and c["governing"] and not striking and String(d["status"]) == "OPEN":
			var row := Kit.hbox(body)
			var id := String(d["id"])
			Kit.button(row, "Accept", func(): _answer(id, "ACCEPT", 0))
			var sb := SpinBox.new()
			sb.min_value = 0
			sb.max_value = maxi(1, int(d.get("size_pm", 0)))
			sb.value = int(d.get("size_pm", 0)) / 2
			sb.suffix = "‰"
			row.add_child(sb)
			counter[id] = sb
			Kit.button(row, "Counter-offer", func(): _answer(id, "COUNTER", int(counter[id].value)))
			Kit.button(row, "Refuse", func(): _answer(id, "REFUSE", 0))


func _answer(id: String, answer: String, pm: int) -> void:
	var params := {"demand": id, "answer": answer}
	if answer == "COUNTER":
		params["counter_pm"] = pm
	var r: Dictionary = EconActions.enqueue(session.world(), "ECON_ANSWER_UNION_DEMAND", params)
	if status != null:
		status.text = ("Answer sent: " + answer.to_lower()) if r.get("ok", false) else "✗ " + String(r.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func _history(w: WorldState) -> void:
	var rows: Array = []
	for t in EVENTS:
		for f in w.facts.query(t, -1, 1 << 30, "PUBLIC"):
			rows.append(f)
	if rows.is_empty():
		return
	rows.sort_custom(func(a, b): return a["month"] > b["month"] or (a["month"] == b["month"] and String(a["id"]) > String(b["id"])))
	Kit.header(body, "Union history")
	for f in rows.slice(0, 25):
		Kit.label(body, "%s: %s" % [_month(int(f["month"])), Gazette.plain(NewsText.sentence(w, f))], 12)


const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func _month(m: int) -> String:
	return "%s Year %d" % [MONTHS[m % 12], m / 12 + 1]
