extends VBoxContainer
## Parliament (read-only): seat chart, government and partner cohesion, procedures, recent bills, motions and
## crisis events. Reads world.peek + LQ only. Actions (motions, extra elections) live in the My Party panel.

const Kit := preload("res://ui/panels/panel_kit.gd")
const LQ := preload("res://sim/law/law_query.gd")

const CRISIS_TYPES := ["POL_GOVERNMENT_FORMED", "POL_FORMATION_FAILED", "POL_NO_CONFIDENCE_PASSED", "POL_NO_CONFIDENCE_FAILED",
	"POL_EXTRA_ELECTION_CALLED", "POL_PARTNER_LEFT", "POL_PM_VOTE_FAILED", "STAFF_OFFICIALS_WITHDRAWN"]

var session
var body: VBoxContainer


func panel_title() -> String:
	return "Parliament"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func _color(i: int) -> Color:
	return Color.from_hsv(fmod(0.08 + 0.137 * float(i), 1.0), 0.55, 0.85)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var st: Dictionary = w.peek("pol").get("state", {})
	var c := Kit.ctx(session)
	if String(st.get("era", "FOUNDING")) == "FOUNDING":
		Kit.label(body, "There is no parliament yet: the first election is in month %d (%s)." % [session.next_election_month(),
			"parties form in Year 3" if c["party_id"] == "" else "parties are campaigning"], 14)
	var parties: Dictionary = w.peek("party")
	var ids: Array = parties.keys().filter(func(p): return int(parties[p].get("seats", 0)) > 0)
	ids.sort_custom(func(a, b): return int(parties[a]["seats"]) > int(parties[b]["seats"]))
	var gov: Dictionary = st.get("government", {})
	var members: Array = gov.get("members", [])
	var support: Array = gov.get("support", [])
	# --- seat chart: one bar of 151 seats, government parties first
	if not ids.is_empty():
		Kit.header(body, "Seats (151, majority 76)")
		var order: Array = ids.filter(func(p): return members.has(p)) + ids.filter(func(p): return support.has(p)) \
			+ ids.filter(func(p): return not members.has(p) and not support.has(p))
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 1)
		bar.custom_minimum_size = Vector2(0, 26)
		body.add_child(bar)
		var all_ids: Array = parties.keys()
		for pid in order:
			var r := ColorRect.new()
			r.color = _color(all_ids.find(pid))
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.size_flags_stretch_ratio = float(parties[pid]["seats"])
			r.tooltip_text = "%s: %d" % [parties[pid]["name"], parties[pid]["seats"]]
			bar.add_child(r)
		var coh: Dictionary = st.get("cohesion", {})
		var gov_seats := 0
		for pid in order:
			var role := "government" if members.has(pid) else ("support" if support.has(pid) else "opposition")
			if members.has(pid):
				gov_seats += int(parties[pid]["seats"])
			var extra := ""
			if pid == gov.get("pm_party", ""):
				extra += "  · PM"
			if coh.has(pid):
				var cv := int(coh[pid])   # 0..100
				extra += "  · cohesion %d%s" % [cv, "  ⚠ restless" if cv < 40 else ""]
			var row := Kit.hbox(body)
			var sw := ColorRect.new()
			sw.color = _color(all_ids.find(pid))
			sw.custom_minimum_size = Vector2(14, 14)
			row.add_child(sw)
			Kit.label(row, "%s%s — %d seats — %s%s" % [parties[pid]["name"], " (you)" if parties[pid].get("is_player", false) else "",
				parties[pid]["seats"], role, extra], 13)
		Kit.sep(body)
		# --- government
		Kit.header(body, "Government")
		if gov.is_empty():
			Kit.label(body, "No government: %s." % ("caretaker, formation under way" if st.get("caretaker", false) else "awaiting formation"), 14, Color(1, 0.7, 0.5))
		else:
			var names: Array = members.map(func(p): return parties.get(p, {}).get("name", p))
			Kit.label(body, "%s — %d seats (%s)%s" % [" + ".join(names), gov_seats, "majority" if gov_seats >= 76 else "minority",
				"  · CARETAKER" if st.get("caretaker", false) else ""], 14)
			if not support.is_empty():
				Kit.label(body, "Supported by: " + ", ".join(support.map(func(p): return parties.get(p, {}).get("name", p))), 13)
		var nxt := int(st.get("next_election", -1))
		Kit.label(body, "Next ordinary election: month %d%s" % [nxt,
			("   · extra election scheduled: month %d" % int(st["extra_election_month"])) if int(st.get("extra_election_month", -1)) >= 0 else ""], 13)
		Kit.sep(body)
	# --- procedures
	var p: Dictionary = LQ.procedures(w)
	Kit.header(body, "Procedures")
	Kit.label(body, "No-confidence: moved by at least %d members; topples the government with %d votes against the PM. " % [LQ.movers_needed(),
		int(p["no_confidence"]["topple_votes"])] + "Extra elections: called by the government, not within %d months of an election, never by a caretaker; " % \
		int(p["extra_election"]["blocked_months_after_election"]) + "the ordinary 4-year calendar continues. %d failed PM votes force an extra election." % int(p["pm_votes"]["max_failed"]), 12)
	if c["party_id"] != "" and LawOps_in_force(p):
		var nc: Dictionary = LQ.can_move_no_confidence(w, c["party_id"])
		Kit.label(body, "Your party %s move a no-confidence motion alone%s." % ["can" if nc["ok"] else "cannot",
			"" if nc["ok"] else " (" + nc["reason"] + ")"], 12, Color(0.8, 0.8, 0.8))
	Kit.sep(body)
	# --- recent bills
	Kit.header(body, "Recent bills")
	var bills: Dictionary = w.peek("bill")
	var bids: Array = bills.keys()
	bids.sort_custom(func(a, b): return int(bills[a].get("month", 0)) > int(bills[b].get("month", 0)))
	if bids.is_empty():
		Kit.label(body, "None yet.", 13, Color(0.7, 0.7, 0.7))
	for bid in bids.slice(0, 8):
		var b: Dictionary = bills[bid]
		var what: String = ", ".join(b.get("clauses", []).map(func(x): return "%s %s→%s" % [x.get("lever", "?"), str(x.get("from", "")), str(x.get("to", ""))]))
		Kit.label(body, "m%d  %s: %s  — %s (%d–%d)" % [int(b.get("month", 0)), parties.get(b.get("sponsor", ""), {}).get("name", "?"), what,
			String(b.get("status", "")).to_lower(), int(b.get("yes", 0)), int(b.get("no", 0))], 12,
			Color(0.7, 1, 0.7) if b.get("status", "") == "PASSED" else Color(1, 0.7, 0.6))
	Kit.sep(body)
	# --- motions and crises
	Kit.header(body, "Motions and government crises")
	var events: Array = []
	for typ in CRISIS_TYPES:   # query each type: a mixed feed would be crowded out by routine facts
		events.append_array(LQ.fact_feed(w, c["viewer"], w.month - 48, typ, 20).filter(func(f): return f["type"] == typ))
	events.sort_custom(func(a, b): return int(a["month"]) > int(b["month"]) if a["month"] != b["month"] else String(a["id"]) > String(b["id"]))
	var shown := 0
	for f in events.slice(0, 12):
		Kit.label(body, "m%d  %s  %s" % [int(f["month"]), String(f["type"]).trim_prefix("POL_").trim_prefix("STAFF_").replace("_", " ").capitalize(),
			_data_text(f["data"])], 12)
		shown += 1
	if shown == 0:
		Kit.label(body, "None in the last four years.", 13, Color(0.7, 0.7, 0.7))


static func LawOps_in_force(p: Dictionary) -> bool:
	return bool(p.get("in_force", false))


func _data_text(d: Dictionary) -> String:
	var parts: Array = []
	for k in ["yes", "no", "party", "mover", "against", "members", "remaining", "seats", "round", "by", "mandatory", "reason", "month"]:
		if d.has(k):
			var v = d[k]
			if v is Array or v is PackedStringArray:
				var names: Array = []
				for x in v:
					names.append(session.party_name(x) if str(x).begins_with("party:") else str(x))
				v = ", ".join(names)
			elif str(v).begins_with("party:"):
				v = session.party_name(v)
			parts.append("%s %s" % [k, str(v)])
	return ("(" + "; ".join(parts) + ")") if not parts.is_empty() else ""
