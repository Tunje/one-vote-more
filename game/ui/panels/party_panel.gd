extends VBoxContainer
## My Party: shift your platform (slowly, at a credibility cost) and choose your election promises.

const Kit := preload("res://ui/panels/panel_kit.gd")
const AXIS_TEXT := {
	"ECON_ROLE": ["free market", "state-directed economy"],
	"REDISTRIBUTION": ["low taxes, low transfers", "high taxes, high transfers"],
	"LABOR": ["employer flexibility", "worker protection"],
	"ENVIRONMENT": ["development first", "environment first"],
	"AUTONOMY": ["central control", "district autonomy"],
	"FISCAL": ["balanced budget", "spend and borrow for growth"],
	"INSTITUTIONS": ["strong executive, order", "checks and civil liberties"],
	"SOVEREIGNTY": ["loyal to the home world", "independence"],
}

var session
var body: VBoxContainer
var msg := ""
var picked := {}   # lever -> dir (pending agenda selection)


func panel_title() -> String:
	return "My Party"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func _after(res: Dictionary, ok_text: String) -> void:
	msg = ok_text if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
	get_tree().call_group("pcs_refresh", "refresh_all")


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var pf := PolActions.player_platform(w)
	if not pf["ok"]:
		Kit.label(body, "Political parties form in Year 3. Until then, every ordinance you issue as commander shapes what your future party will stand for.", 14)
		return
	Kit.header(body, pf["name"])
	Kit.label(body, "Credibility %d/100: voters trust parties that keep promises and don't flip-flop." % pf["credibility"], 13)
	if msg != "":
		Kit.label(body, msg, 13, Color("#ffcc66"))
	_parliament_section(w)
	Kit.sep(body)
	Kit.header(body, "Platform")
	Kit.label(body, "Each axis can move %d points per year. Every 5 points costs 1 credibility." % PolActions.PLATFORM_YEARLY_MOVE, 12, Color("#aaaaaa"))
	for ax in PolDefs.AXES:
		var a: Dictionary = pf["axes"][ax]
		var row := Kit.hbox(body)
		var txt: Array = AXIS_TEXT[ax]
		var l := Kit.label(row, "%s ← %+d → %s" % [txt[0], a["position"], txt[1]], 13)
		l.custom_minimum_size = Vector2(330, 0)
		var left: int = a["left_this_year"]
		Kit.button(row, "◀ 5", func(): _after(PolActions.player_shift_platform(session.world(), ax, -5), "Platform moved."), left < 5)
		Kit.button(row, "5 ▶", func(): _after(PolActions.player_shift_platform(session.world(), ax, 5), "Platform moved."), left < 5)
		Kit.label(row, "(%d left this year)" % left, 12, Color("#aaaaaa"))
	Kit.sep(body)
	Kit.header(body, "Election promises (pick up to %d)" % PolActions.AGENDA_SIZE)
	Kit.label(body, "Voters judge your party on these at the next election. A government that delivers gains credibility.", 12, Color("#aaaaaa"))
	var cur: Array = pf["agenda"]
	if cur.is_empty():
		Kit.label(body, "No promises chosen: your party will campaign on its strongest commitments.", 13)
	else:
		for it in cur:
			Kit.label(body, "★ %s" % _promise_text(it), 13, Color("#8bc34a"))
	if picked.is_empty():
		for it in cur:
			picked[it["lever"]] = it["dir"]
	var cms: Array = pf["commitments"].duplicate()
	cms.sort_custom(func(a, b): return a["weight"] > b["weight"])
	for cm in cms.slice(0, 10):
		var row := Kit.hbox(body)
		var cb := CheckBox.new()
		cb.text = "%s  (%s)" % [_promise_text(cm), cm["kind"].to_lower()]
		cb.button_pressed = picked.has(cm["lever"])
		cb.toggled.connect(func(on):
			if on:
				picked[cm["lever"]] = cm["dir"]
			else:
				picked.erase(cm["lever"]))
		row.add_child(cb)
	var row2 := Kit.hbox(body)
	Kit.button(row2, "Set these promises", func():
		var items: Array = []
		for lv in picked:
			items.append({"lever": lv, "dir": picked[lv]})
		_after(PolActions.player_set_agenda(session.world(), items), "Election agenda set."))
	Kit.button(row2, "Clear", func():
		picked.clear()
		_after(PolActions.player_set_agenda(session.world(), []), "Agenda cleared."))


## Confidence and extra elections (GovCrisis via PolActions; procedures from the constitution via LQ).
func _parliament_section(w: WorldState) -> void:
	var st: Dictionary = w.peek("pol").get("state", {})
	var g: Dictionary = st.get("government", {})
	var me: String = st.get("player_party", "")
	if st.has("formation"):
		Kit.label(body, "Government formation in progress: PM vote round %d of %d." % [int(st["formation"]["round"]) + 1, PolDefs.MAX_FORMATION_ROUNDS], 13, Color("#ffcc66"))
	if st.has("extra_election_month"):
		Kit.label(body, "An extra election is scheduled for month %d." % st["extra_election_month"], 13, Color("#ffcc66"))
	if g.is_empty():
		return
	var row := Kit.hbox(body)
	if me in g["members"]:
		var coh: Dictionary = st.get("cohesion", {})
		for pid in coh:
			Kit.label(body, "Coalition partner %s: cohesion %d/100%s" % [session.party_name(pid), coh[pid], "  ⚠ may leave" if coh[pid] < 35 else ""], 13)
		if g.get("pm_party", "") == me:
			var chk: Dictionary = preload("res://sim/law/law_query.gd").extra_election_allowed(w)
			Kit.button(row, "Call extra election…", func(): _after(PolActions.player_call_extra_election(session.world()), "Extra election called (in 3 months)."), not chk.get("ok", false))
			if not chk.get("ok", false):
				Kit.label(row, String(chk.get("reason", "")), 12, Color("#aaaaaa"))
	else:
		var chk2: Dictionary = preload("res://sim/law/law_query.gd").can_move_no_confidence(w, me)
		Kit.button(row, "Move a motion of no confidence", func():
			var r := PolActions.player_move_no_confidence(session.world())
			_after(r, "Motion %s: %d votes against the PM (76 needed)." % ["PASSED, the government falls" if r.get("passed", false) else "failed", r.get("against", 0)]),
			not chk2.get("ok", false))
		if not chk2.get("ok", false):
			Kit.label(row, String(chk2.get("reason", "")), 12, Color("#aaaaaa"))


func _promise_text(it: Dictionary) -> String:
	var name := String(it["lever"]).trim_prefix("ECON_").trim_prefix("LAW_").replace("_", " ").to_lower()
	return ("Raise " if int(it["dir"]) > 0 else "Lower ") + name
