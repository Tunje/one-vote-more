extends VBoxContainer
## Opposition: inquiries and legal challenges, computed only from what your party can see (Opp.options).

const Kit := preload("res://ui/panels/panel_kit.gd")
const Opp := preload("res://sim/staff/opposition.gd")

var session
var body: VBoxContainer
var msg := ""


func panel_title() -> String:
	return "Opposition"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func _do(action_id: String, args: Dictionary) -> void:
	var c := Kit.ctx(session)
	var res: Dictionary = Kit.A.apply(session.world(), {"id": action_id, "actor": c["party_actor"], "args": args})
	msg = "Started. Staff it in Personnel (My party's staff)." if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var c := Kit.ctx(session)
	if c["party_id"] == "":
		Kit.label(body, "Parties form in Year 3. Until then you govern as commander.", 14)
		return
	if c["governing"]:
		Kit.label(body, "Your party is in government. Inquiries and court challenges are tools of the opposition.", 14)
		return
	var o: Dictionary = Opp.options(w, c["party_id"])
	if msg != "":
		Kit.label(body, msg, 13, Color(1, 0.85, 0.5))
	var pool: Dictionary = o["pool"]
	Kit.label(body, "Role: %s · party staff %d (%d free)%s%s" % [o["role"].to_lower(), pool["size"], pool["free"],
		"" if pool["qualified_investigator"] else " · no free investigator", "" if pool["qualified_counsel"] else " · no free counsel"], 14)
	Kit.header(body, "Parliamentary inquiry")
	Kit.label(body, "An inquiry opens the government's internal records in one area (24 months back) and its internal indicators for 6 months. Findings are published.", 12, Color(0.75, 0.75, 0.75))
	var busy_inquiry: bool = o["running"].any(func(r): return r["def_id"] == "STAFF_T_OVERSIGHT")
	for d in o["oversight"]:
		var row := Kit.hbox(body)
		Kit.label(row, "%s — expected yield %.1f%s" % [d["label"], d["expected_yield"],
			(": " + "; ".join(d["reasons"])) if not d["reasons"].is_empty() else ": nothing visible points here"], 13)
		var dom: String = d["domain"]
		Kit.button(row, "Start inquiry", func(): _do("OPP_START_OVERSIGHT", {"domain": dom}), busy_inquiry)
	Kit.sep(body)
	Kit.header(body, "Court challenges")
	if o["challenges"].is_empty():
		Kit.label(body, "No visible grounds for a challenge.", 13, Color(0.7, 0.7, 0.7))
	var busy_case: bool = o["running"].any(func(r): return r["def_id"] == "STAFF_T_LEGAL_CHALLENGE")
	for ch in o["challenges"]:
		var row := Kit.hbox(body)
		var col := Color(0.7, 1, 0.7) if ch["p_win_est"] >= 0.5 else Color(1, 0.75, 0.6)
		Kit.label(row, "%s%s — estimated chance %d%%" % [ch["label"], " (you were harmed)" if ch["grievance"] else "",
			int(round(100.0 * float(ch["p_win_est"])))], 13, col)
		var option: Dictionary = ch
		Kit.button(row, "File challenge", func(): _do("OPP_FILE_CHALLENGE", {"option": option}), busy_case)
		if ch["p_win_est"] < 0.5:
			Kit.label(body, "     A weak case usually loses, and the loss is blamed on your party.", 11, Color(1, 0.7, 0.6))
	Kit.sep(body)
	Kit.header(body, "In progress")
	if o["running"].is_empty():
		Kit.label(body, "Nothing running.", 13, Color(0.7, 0.7, 0.7))
	for r in o["running"]:
		Kit.label(body, "%s — %d%%" % [r["def_id"].trim_prefix("STAFF_T_").replace("_", " ").capitalize(), r["progress"]], 13)
