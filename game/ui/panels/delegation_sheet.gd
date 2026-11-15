extends RefCounted
## Who decides: the delegation sheet (planning/design-delegation.md §2-3; Maja). Shown as the "Delegation" tab of the
## office (flag DELEGATION); the term-start email opens it. Not a panel itself (the name doesn't end in _panel.gd).
## Every decision type, grouped by the minister who holds it: its level (make the call / give me a suggestion / leave
## it to me), what the law allows, and who it can be handed to. Reads Desk.sheet; writes through Desk.set_level,
## Desk.hand_over and Desk.apply_preset (the delegation module's entry points), then refreshes the screen.

const Kit := preload("res://ui/panels/panel_kit.gd")
const Desk := preload("res://sim/office/decision_desk.gd")
const OStaff := preload("res://sim/staff/office_staff.gd")
const SHORT := {"CALL": "Make the call", "SUGGEST": "Suggest", "ME": "Leave it to me"}
const PRESET_TXT := {"TRUSTING": "Ministers make every call the law allows.", "BALANCED": "Ministers make the routine calls and suggest the rest.",
	"HANDS_ON": "Everything comes to your desk."}
const GREY := Color("#aaaaaa")


## Fill `body` with the sheet. `status` shows the result of a change; `done` is called after a change (the panel's
## refresh). Read-only when the player does not hold the office.
static func build(body: VBoxContainer, w: WorldState, status: Label, done: Callable) -> void:
	if not Desk.on(w):
		Kit.label(body, "Delegation is not switched on in this game.", 13, GREY)
		return
	var mine: bool = OfficeFeed.player_office(w)
	var d: Dictionary = w.peek("delegation")
	Kit.header(body, "Who decides")
	Kit.label(body, "For every kind of decision, choose how much the minister decides on their own. Make the call: they decide, you read it in the monthly summary. Suggest: it comes to you with their choice pre-selected. Leave it to me: it comes to you with their advice only.", 13)
	if not mine:
		Kit.label(body, "You don't hold the government's office: this is the government's sheet, for reading only.", 13, GREY)
	if int(d.get("term_start", -1)) >= 0 and String(d.get("sig", "")) != "":
		Kit.label(body, "This term began %s. Taking decisions away from a minister mid-term is noticed." % _month(int(d["term_start"])), 12, GREY)
	var prow := Kit.hbox(body)
	Kit.label(prow, "Presets:", 13)
	var cur := String(d.get("preset", Desk.DEFAULT_PRESET))
	for p in Desk.PRESETS:
		var b := Kit.button(prow, String(Desk.PRESET_NAMES[p]), func(): _show(status, Desk.apply_preset(w, p), done), not mine or p == cur)
		b.tooltip_text = String(PRESET_TXT[p])
	Kit.label(body, "Last preset: %s. %s" % [String(Desk.PRESET_NAMES.get(cur, cur)), String(PRESET_TXT.get(cur, ""))], 12, GREY)
	var holders := _holders(w)
	for g in Desk.sheet(w):
		Kit.sep(body)
		var role := String(g["role"])
		var who := String(g["title"]) if role in ["", "FM"] else "%s (%s)" % [String(g["title"]), String(g["name"])]
		who = who.left(1).to_upper() + who.substr(1)
		Kit.header(body, who)
		if role == "":
			Kit.label(body, "Nobody holds these portfolios: the decisions stay with you until you hand them to a minister.", 12, Color("#ff8a65"))
		for t in g["types"]:
			_row(body, w, t, role, mine, holders, status, done)


static func _row(body: VBoxContainer, w: WorldState, t: Dictionary, role: String, mine: bool, holders: Array, status: Label, done: Callable) -> void:
	var ty := String(t["type"])
	var row := Kit.hbox(body)
	var extra: Array = []
	if bool(t["outside"]):
		extra.append("outside their portfolio")
	if String(t["max_level"]) != "CALL":
		extra.append("%s matter by law: at most a suggestion" % String(t["ceiling"]).capitalize())
	if String(t["note"]) != "":
		extra.append(String(t["note"]))
	var name_l := Kit.label(row, String(t["name"]) + (("  (" + "; ".join(extra) + ")") if not extra.is_empty() else ""), 13)
	name_l.custom_minimum_size = Vector2(320, 0)
	if role == "FM" and String(t["portfolio"]) == "FM":
		Kit.label(row, "Your own decision", 12, GREY)
		return
	if role == "":
		Kit.label(row, "With you", 12, GREY)
	else:
		var top := Desk.LEVELS.find(String(t["max_level"]))
		for lv in Desk.LEVELS:
			var allowed: bool = Desk.LEVELS.find(lv) >= top
			var here: bool = String(t["level"]) == lv
			var b := Kit.button(row, ("● " if here else "") + String(SHORT[lv]), func(): _show(status, Desk.set_level(w, ty, lv), done), not mine or here or not allowed)
			if not allowed:
				b.tooltip_text = "The law keeps this on your desk."
	var opt := OptionButton.new()
	opt.add_item("Hand to…")
	var ids: Array = [""]
	for h in holders:
		if String(h["role"]) == role:
			continue
		opt.add_item(String(h["label"]))
		ids.append(String(h["role"]))
	if role != "" and role != "FM" and role != String(t["portfolio"]):
		opt.add_item("Give back to its own portfolio")
		ids.append("")
	opt.disabled = not mine or ids.size() <= 1
	opt.item_selected.connect(func(i: int):
		if i > 0:
			_show(status, Desk.hand_over(w, ty, String(ids[i])), done))
	row.add_child(opt)


## Ministers who can take a decision: the Cabinet's portfolios with somebody in them.
static func _holders(w: WorldState) -> Array:
	var out: Array = []
	for r in OStaff.portfolios(w):
		var p: Dictionary = OStaff.holder(w, String(r))
		if p.is_empty():
			continue
		var title := String(OStaff.minister_label(w, String(r)))
		out.append({"role": String(r), "label": "%s (%s)" % [title if title != "" else String(r), String(p.get("name", ""))]})
	return out


static func _show(status: Label, r: Dictionary, done: Callable) -> void:
	if status != null:
		status.text = "Done." if r.get("ok", false) else "✗ " + String(r.get("error", "failed"))
	done.call()


static func _month(m: int) -> String:
	return "%s Year %d" % [["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][posmod(m, 12)], m / 12 + 1]
