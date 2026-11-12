extends VBoxContainer
## Legislate: the core player verb (ui-staff-law §3).
##   build clauses -> preview (legal check, ideology, drafting work, predicted vote) -> start drafting (staffed)
##   -> submit when done (ordinance in the founding era, bill + vote in parliament) -> track implementation.
## Plus government decrees, with an explicit confirmation when a decree would be unlawful.
## Politics owns bills (PolActions); law owns the legal preview (LQ) and decrees (A.apply LAW_DECREE).

const Kit := preload("res://ui/panels/panel_kit.gd")
const LQ := preload("res://sim/law/law_query.gd")

var session
var body: VBoxContainer
var clauses: Array = []            # [{lever, to}]
var msg := ""
var decree_lever := ""
var decree_value = null
var decree_check := {}
var dialog: ConfirmationDialog


func panel_title() -> String:
	return "Legislate"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)
	dialog = ConfirmationDialog.new()
	dialog.title = "Unlawful decree"
	dialog.ok_button_text = "Proceed anyway (unlawful)"
	dialog.cancel_button_text = "Cancel"
	dialog.confirmed.connect(_decree_unlawful)
	add_child(dialog)


## Public entry for other panels (e.g. Budget "Propose…"): add or replace a clause and show the preview.
func prefill(lever: String, to: int) -> void:
	clauses = clauses.filter(func(x): return x["lever"] != lever)
	if clauses.size() >= 4:
		msg = "A bill holds at most 4 clauses: remove one to add %s." % lever
	else:
		clauses.append({"lever": lever, "to": to})
		msg = "Added %s → %d from another panel. Check the preview, then start drafting." % [lever, to]
	refresh()


func _say(res: Dictionary, ok_text: String) -> void:
	msg = ok_text if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var c := Kit.ctx(session)
	if msg != "":
		Kit.label(body, msg, 14, Color(1, 0.85, 0.5))
	var can: Dictionary = PolActions.player_can_legislate(w)
	if not can["ok"]:
		Kit.label(body, can["error"], 14, Color(0.8, 0.8, 0.8))
	else:
		Kit.label(body, "You legislate as %s: %s." % [can["as"].to_lower(),
			"commander ordinances take effect without a vote" if can["as"] == "COMMANDER" else "bills go to a vote in the Colonial Assembly (76 of 151 seats)"], 13)
		if can["as"] == "COMMANDER":
			var left: int = session.next_election_month() - w.month
			if left <= 4:
				Kit.label(body, "⚠ The election is in %d month(s). Drafts not submitted before the first government forms LAPSE." % maxi(0, left),
					14, Color(1, 0.6, 0.4))
		_builder(w, c, can)
	_drafts(w, c)
	_pipeline(w, c)
	if c["governing"] and c["era"] == "PARLIAMENTARY":
		_decrees(w, c)


# ---------------------------------------------------------------- 1. clause builder + preview

func _builder(w: WorldState, c: Dictionary, can: Dictionary) -> void:
	Kit.header(body, "New %s" % ("ordinance" if can["as"] == "COMMANDER" else "bill"))
	var levers: Array = LQ.lever_catalog(w).filter(func(l): return l["type"] in ["NUMBER", "ENUM", "BOOL"] \
		and l["changeable"] and l["pending"].is_empty())
	var row := Kit.hbox(body)
	var opt := OptionButton.new()
	for l in levers:
		opt.add_item("%s (now %s)" % [l["id"], str(l["legal"])])
	row.add_child(opt)
	var spin := SpinBox.new()
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.custom_minimum_size.x = 120
	row.add_child(spin)
	var choice := OptionButton.new()      # ENUM values / BOOL true-false
	row.add_child(choice)
	var choice_values: Array = []
	var sync := func(i: int):
		if i < 0 or i >= levers.size():
			return
		var l: Dictionary = levers[i]
		spin.visible = l["type"] == "NUMBER"
		choice.visible = l["type"] != "NUMBER"
		if l["type"] == "NUMBER":
			spin.min_value = float(l["range"][0])
			spin.max_value = float(l["range"][1])
			spin.step = 1
			spin.value = float(l["legal"])
		else:
			choice.clear()
			choice_values.clear()
			for v in (l["values"] if l["type"] == "ENUM" else [false, true]):
				choice_values.append(v)
				choice.add_item(str(v))
			choice.select(maxi(0, choice_values.find(l["legal"])))
	opt.item_selected.connect(sync)
	if not levers.is_empty():
		sync.call(0)
	var add_cb := func():
		if opt.selected >= 0 and clauses.size() < 4:
			var l: Dictionary = levers[opt.selected]
			var lid: String = l["id"]
			var to = int(spin.value) if l["type"] == "NUMBER" else choice_values[maxi(0, choice.selected)]
			clauses = clauses.filter(func(x): return x["lever"] != lid)
			clauses.append({"lever": lid, "to": to})
			msg = ""
			refresh()
	Kit.button(row, "Add clause", add_cb, clauses.size() >= 4 or levers.is_empty())
	Kit.label(body, "Values are in the lever's own units (rates in basis points, money in milli-units). Up to 4 clauses.", 11, Color(0.7, 0.7, 0.7))
	if clauses.is_empty():
		return
	var pv: Dictionary = LQ.preview_clauses(w, clauses)
	for i in pv["clauses"].size():
		var cl: Dictionary = pv["clauses"][i]
		var r := Kit.hbox(body)
		var shift: Array = []
		for ax in cl["ideology"]:
			if absf(float(cl["ideology"][ax])) >= 0.5:
				shift.append("%s %+d" % [ax, int(round(float(cl["ideology"][ax])))])
		Kit.label(r, "• %s: %s → %s   %s   (implementation: %s, lag %d)" % [cl["lever"], str(cl["from"]), str(cl["to"]),
			" ".join(shift), String(cl["implementation"]).trim_prefix("STAFF_T_IMPL_").to_lower(), cl["lag"]], 13)
		var idx: int = i
		Kit.button(r, "Remove", func(): clauses.remove_at(idx); refresh())
		for e in cl["errors"]:
			Kit.label(body, "     ✗ " + e, 12, Color(1, 0.55, 0.55))
	Kit.label(body, "Drafting: %d work units, policy skill %s%s." % [pv["drafting"]["work_wu"], pv["drafting"]["domain"],
		", needs a second policy lead" if pv["drafting"]["second_policy_lead_required"] else ""], 13)
	if can["as"] == "GOVERNMENT":
		var vote: Dictionary = PolActions.predict_vote(w, _with_from(w), 50)
		var parts: Array = []
		for pid in vote["votes"]:
			parts.append("%s %s" % [session.party_name(pid), vote["votes"][pid]])
		Kit.label(body, "Expected vote (average draft): YES %d – NO %d → %s.   %s" % [vote["yes"], vote["no"],
			"passes" if vote["passes"] else "fails", ", ".join(parts)], 13, Color(0.7, 1, 0.7) if vote["passes"] else Color(1, 0.7, 0.6))
	var r2 := Kit.hbox(body)
	var draft_cb := func():
		var res: Dictionary = PolActions.player_draft(w, clauses)
		if res.get("ok", false):
			clauses = []
		_say(res, "Drafting started. Staff the drafting task in Personnel; submit here when it is done.")
	Kit.button(r2, "Start drafting", draft_cb, not pv["ok"])
	Kit.button(r2, "Clear", func(): clauses = []; refresh())


func _with_from(w: WorldState) -> Array:
	return clauses.map(func(x): return {"lever": x["lever"], "from": w.levers.get(x["lever"], 0), "to": x["to"]})


# ---------------------------------------------------------------- 2. drafts and submission

func _drafts(w: WorldState, c: Dictionary) -> void:
	var drafts: Array = PolActions.player_drafts(w)
	if drafts.is_empty():
		return
	Kit.sep(body)
	Kit.header(body, "Your drafts")
	for d in drafts:
		var st: Dictionary = LQ.drafting_status(w, d["bill"], c["viewer"])
		var row := Kit.hbox(body)
		var what: String = ", ".join(d["clauses"].map(func(x): return "%s %s→%s" % [x["lever"], str(x["from"]), str(x["to"])]))
		var state: String = d["status"]
		if d["status"] == "DRAFTING":
			state = "ready (quality %d)" % d["quality"] if d["ready"] else "drafting %d%%%s" % [st.get("progress_pct", 0),
				"" if st.get("staffed", true) else " — NOT STAFFED (see Personnel)"]
		var unstaffed: bool = d["status"] == "DRAFTING" and not d["ready"] and not st.get("staffed", true)
		Kit.label(row, "%s: %s — %s" % [d["bill"], what, state], 13,
			Color(0.7, 1, 0.7) if d["ready"] else (Color(1, 0.45, 0.45) if unstaffed else Color.WHITE))
		if unstaffed:
			Kit.button(row, "Let my chief of staff assign people", func():
				var r: Dictionary = Kit.A.apply(w, {"id": "STAFF_AUTO_ASSIGN", "actor": c["gov_actor"], "args": {}})
				_say(r, "Assigned %d position(s)." % int(r.get("filled", 0))))
		if d["ready"]:
			var bid: String = d["bill"]
			Kit.button(row, "Submit", func():
				var res: Dictionary = PolActions.player_submit(w, bid)
				var txt := "Submitted."
				if res.get("result", "") == "ORDINANCE_ISSUED":
					txt = "Ordinance issued: it takes effect once implemented."
				elif res.has("yes"):
					txt = "Vote: YES %d – NO %d → %s." % [res["yes"], res["no"], res["result"]]
				_say(res, txt))


# ---------------------------------------------------------------- 3. enacted changes in the pipeline

func _pipeline(w: WorldState, c: Dictionary) -> void:
	var rows: Array = LQ.enactments(w, false, c["viewer"])
	Kit.sep(body)
	Kit.header(body, "Enacted, not yet in effect")
	if rows.is_empty():
		Kit.label(body, "Nothing pending.", 13, Color(0.7, 0.7, 0.7))
	for e in rows:
		var impl: Dictionary = e["implementation"]
		var how := ""
		if not impl.is_empty():
			how = " — implementation %d%%%s" % [impl["progress_pct"], "" if impl["staffed"] else " (NOT STAFFED)"]
		elif e["status"] == "SCHEDULED":
			how = " — takes effect in month %d" % e["due_month"]
		Kit.label(body, "%s: %s → %s [%s]%s%s" % [e["lever"], str(e["from"]), str(e["to"]), e["status"].to_lower(), how,
			"  ⚠ unlawful decree" if e["unlawful"] else ""], 13)
	if c["governing"]:
		Kit.label(body, "Changes only take effect after a staffed implementation task and the lever's lag.", 11, Color(0.7, 0.7, 0.7))


# ---------------------------------------------------------------- 4. decrees

func _decrees(w: WorldState, c: Dictionary) -> void:
	Kit.sep(body)
	Kit.header(body, "Government decision (decree)")
	Kit.label(body, "Regulation- and admin-level levers can be set by decree; Assembly-level ones only by law.", 12, Color(0.75, 0.75, 0.75))
	var levers: Array = LQ.lever_catalog(w, "REGULATION").filter(func(l): return l["pending"].is_empty())
	var row := Kit.hbox(body)
	var opt := OptionButton.new()
	for l in levers:
		opt.add_item("%s [%s] (now %s)" % [l["id"], l["legal_level"].to_lower(), str(l["legal"])])
	row.add_child(opt)
	var spin := SpinBox.new()
	spin.custom_minimum_size.x = 120
	var enum_opt := OptionButton.new()
	row.add_child(spin)
	row.add_child(enum_opt)
	var sync := func(i: int):
		if i < 0 or i >= levers.size():
			return
		var l: Dictionary = levers[i]
		spin.visible = l["type"] == "NUMBER"
		enum_opt.visible = l["type"] == "ENUM"
		if l["type"] == "NUMBER":
			spin.min_value = float(l["range"][0])
			spin.max_value = float(l["range"][1])
			spin.value = float(l["legal"])
		else:
			enum_opt.clear()
			for v in l["values"]:
				enum_opt.add_item(String(v))
			enum_opt.select(maxi(0, l["values"].find(l["legal"])))
	opt.item_selected.connect(sync)
	var sel := 0
	for i in levers.size():
		if levers[i]["id"] == decree_lever:
			sel = i
	if not levers.is_empty():
		opt.select(sel)
		sync.call(sel)
	var check_cb := func():
		var l: Dictionary = levers[opt.selected]
		decree_lever = l["id"]
		decree_value = int(spin.value) if l["type"] == "NUMBER" else l["values"][enum_opt.selected]
		decree_check = LQ.decree_check(w, decree_lever, decree_value, c["viewer"])
		msg = ""
		refresh()
	Kit.button(row, "Check", check_cb, levers.is_empty())
	if decree_check.is_empty() or decree_lever == "":
		return
	if not decree_check["allowed"]:
		Kit.label(body, "✗ Not possible: " + ("; ".join(decree_check["errors"]) if not decree_check["errors"].is_empty() else decree_check["warning"]), 13, Color(1, 0.55, 0.55))
	elif decree_check["lawful"]:
		Kit.label(body, "✓ Lawful: %s → %s by %s decision." % [decree_lever, str(decree_value), decree_check.get("level", "").to_lower()], 13, Color(0.7, 1, 0.7))
		Kit.button(body, "Issue decree", func(): _decree(false))
	else:
		Kit.label(body, "⚠ " + decree_check["warning"], 13, Color(1, 0.6, 0.4))
		Kit.button(body, "Issue anyway…", func():
			dialog.dialog_text = decree_check["warning"]
			dialog.popup_centered(Vector2i(560, 240)))


func _decree(unlawful: bool) -> void:
	var c := Kit.ctx(session)
	var res: Dictionary = Kit.A.apply(session.world(), {"id": "LAW_DECREE", "actor": c["gov_actor"],
		"args": {"lever": decree_lever, "value": decree_value, "confirm_unlawful": unlawful}})
	decree_check = {}
	_say(res, "Decree issued: it takes effect once implemented." + (" It is recorded as a secret unlawful act." if unlawful else ""))


func _decree_unlawful() -> void:
	_decree(true)
