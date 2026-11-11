extends Control
## M5 shell: top bar, 2D colony map, and information tabs. Built in code so agents can add panels
## without scene merge conflicts: each panel is a function that returns BBCode for a tab
## (later: its own Control scene under ui/panels/).

const SQ := preload("res://sim/staff/staff_query.gd")
const GOV := {"kind": "GOVERNMENT", "id": "government"}

var session := GameSession.new()
var map: MapView
var planet: PlanetView   # Terra: the 3D globe; the colony map (MapView) is the landing region up close
var lbl_date: Label
var lbl_gov: Label
var lbl_stats: Label
var chk_auto: CheckBox
var tabs: TabContainer
var panels := {}          # tab name -> RichTextLabel
var selected_district := "d:1"


func _ready() -> void:
	session.new_game(int(Time.get_unix_time_from_system()) % 100000, true)
	_build_ui()
	_refresh()


# ---------------------------------------------------------------- layout

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1e2328")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	root.add_child(bar)
	lbl_date = _label(bar, "", 18)
	lbl_gov = _label(bar, "", 14)
	lbl_stats = _label(bar, "", 14)
	lbl_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk_auto = CheckBox.new()
	chk_auto.text = "AI plays my role"
	chk_auto.button_pressed = true
	chk_auto.toggled.connect(func(on): session.set_autoplay(on))
	bar.add_child(chk_auto)
	_button(bar, "Save", _on_save)
	_button(bar, "Load", _on_load)
	_button(bar, "+12 months", func(): _advance(12))
	_button(bar, "End Month ▶", func(): _advance(1))

	# Tools open as windows (playtest: 17 side tabs were too many). Grouped by what you are doing.
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left)
	var overlays := HBoxContainer.new()
	left.add_child(overlays)
	_button(overlays, "🌍 Planet", func(): _show_planet(true))
	for o in ["TERRAIN", "DISTRICTS", "UNEMPLOYMENT", "APPROVAL", "LEAN"]:
		_button(overlays, o.capitalize(), func(): _show_planet(false); map.overlay = o; map.refresh())
	map = MapView.new()
	map.session = session
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.district_selected.connect(func(d): selected_district = d; tabs.current_tab = 1; _refresh_panels())
	left.add_child(map)
	planet = PlanetView.new()
	planet.session = session
	planet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	planet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	planet.colony_requested.connect(func(): _show_planet(false); map.overlay = "TERRAIN"; map.refresh())
	left.add_child(planet)
	_show_planet(true)

	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(520, 0)
	split.add_child(tabs)
	for name in ["Briefing", "District", "Politics", "Economy", "Laws", "News"]:
		var r := RichTextLabel.new()
		r.name = name
		r.bbcode_enabled = true
		r.scroll_following = false
		r.add_theme_font_size_override("normal_font_size", 14)
		tabs.add_child(r)
		panels[name] = r
	_load_extra_panels()
	tabs.tab_changed.connect(func(_i): _refresh_panels())


## Interactive panels are auto-discovered: every res://ui/panels/*_panel.gd becomes a tab.
## Contract: extends Control; has `panel_title() -> String`, `setup(session: GameSession)`, `refresh()`.
## A panel mutates the game ONLY through action entry points (staff/law A.apply, EconActions) and then calls
## `get_tree().call_group("pcs_refresh", "refresh_all")` so the whole screen updates.
var extra_panels: Array = []
var failed_panels: Array = []   # file names that did not load (shown in smoke test)


func _load_extra_panels() -> void:
	add_to_group("pcs_refresh")
	var d := DirAccess.open("res://ui/panels")
	if d == null:
		return
	var files: Array = []
	for f in d.get_files():
		if f.ends_with("_panel.gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script = load("res://ui/panels/" + f)
		if script == null or not script.can_instantiate():
			push_error("Panel %s failed to load (parse error?) and was skipped" % f)
			failed_panels.append(f)
			continue
		var p = script.new()
		p.name = p.panel_title()
		p.setup(session)
		extra_panels.append(p)
		_make_window(p)
	_build_toolbar()


## Which window group each tool belongs to (by panel title). Unlisted panels go under "More".
const WINDOW_GROUPS := [
	["Govern", ["Legislate", "Personnel", "Staff briefing"]],
	["Politics", ["Parliament", "Parties", "My Party", "Campaign", "Opposition"]],
	["Economy", ["Budget", "Projects", "Companies"]],
	["Help", ["Why?"]],
]
var toolbar: HBoxContainer
var windows := {}   # panel title -> Window


func _make_window(p: Control) -> void:
	var win := Window.new()
	win.title = p.name
	win.size = Vector2i(1000, 760)
	win.min_size = Vector2i(600, 400)
	win.transient = true
	win.exclusive = true          # modal: finish here, then close
	win.visible = false
	win.close_requested.connect(func(): win.hide(); _refresh())
	var bg := ColorRect.new()
	bg.color = Color("#23282e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	win.add_child(m)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(p)
	add_child(win)
	windows[String(p.name)] = win


func _build_toolbar() -> void:
	var placed := {}
	var groups: Array = WINDOW_GROUPS.duplicate(true)
	var more: Array = []
	for t in windows:
		var known := false
		for g in groups:
			if t in g[1]:
				known = true
		if not known:
			more.append(t)
	if not more.is_empty():
		groups.append(["More", more])
	for g in groups:
		var any := false
		for t in g[1]:
			if windows.has(t):
				any = true
		if not any:
			continue
		var lab := _label(toolbar, "  " + String(g[0]) + ":", 13)
		lab.modulate = Color("#9aa4ad")
		for t in g[1]:
			if windows.has(t) and not placed.has(t):
				placed[t] = true
				_button(toolbar, t, func(): open_window(t))


func open_window(title: String) -> void:
	var win: Window = windows.get(title)
	if win == null:
		return
	var p: Control = win.get_child(1).get_child(0)
	p.refresh()
	win.popup_centered()


func refresh_all() -> void:
	_refresh()
	for t in windows:
		var win: Window = windows[t]
		if win.visible:
			win.get_child(1).get_child(0).refresh()


func _label(parent: Node, text: String, size_px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- actions

func _advance(months: int) -> void:
	for _i in months:
		session.end_month()
	_refresh()


func _on_save() -> void:
	var err := session.save()
	lbl_gov.text = "Saved." if err == OK else "Save failed (%d)" % err


func _on_load() -> void:
	var err := session.load_game()
	map.session = session
	planet.session = session
	chk_auto.set_pressed_no_signal(session.autoplay())
	_refresh()
	if err != OK:
		lbl_gov.text = "No save found (%d)" % err


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	var w := session.world()
	lbl_date.text = session.date_text()
	lbl_gov.text = session.government_text()
	var b := EconQuery.budget_view(w)
	var months_to_el := session.next_election_month() - w.month
	lbl_stats.text = "Treasury %s  |  Approval %.0f%%  |  Unemployment %.1f%%  |  Next election in %d months" % [
		_money(b["treasury"]), w.indicators.read("POL_GOV_APPROVAL") / 1000.0, _colony_unemployment(w), months_to_el]
	map.refresh()
	planet.refresh()
	_refresh_panels()


## Terra: swap between the globe and the colony map (same screen space).
func _show_planet(on: bool) -> void:
	planet.visible = on
	map.visible = not on
	if on:
		planet.refresh()


func _refresh_panels() -> void:
	var cur := tabs.get_child(tabs.current_tab)
	var name: String = cur.name
	var r: RichTextLabel = panels[name]
	r.clear()
	r.append_text(call("_panel_" + name.to_lower()))


func _colony_unemployment(w: WorldState) -> float:
	var s := 0.0
	var n := 0.0
	for d in EconData.DISTRICTS:
		var pop := float(EconData.DISTRICTS[d]["pop"])
		s += w.indicators.read("ECON_UNEMPLOYMENT_RATE", d) / 1000.0 * pop
		n += pop
	return s / maxf(1.0, n)


static func _money(credits: float) -> String:
	if absf(credits) >= 1_000_000.0:
		return "%.2fM" % (credits / 1_000_000.0)
	if absf(credits) >= 1000.0:
		return "%.0fk" % (credits / 1000.0)
	return "%.0f" % credits


# ---------------------------------------------------------------- panels (BBCode)

func _panel_briefing() -> String:
	var w := session.world()
	var t := "[b]Monthly briefing, %s[/b]\n\n" % session.date_text()
	var br := SQ.briefing(w, GOV)
	if br.is_empty():
		t += "[i]You are not in government: staff briefings are not available to you.[/i]\n"
	else:
		var shown := 0
		for it in br.get("items", []):
			if it.get("collapsed", false):
				continue
			t += "• [b]%s[/b]: %s\n" % [it["label"], it["text"]]
			shown += 1
		if shown == 0:
			t += "[i]Nothing needs your attention. Routine work is progressing.[/i]\n"
		var dec: Array = br.get("decisions", [])
		if not dec.is_empty():
			t += "\n[color=#ffcc66][b]%d decision(s) waiting for you[/b][/color]\n" % dec.size()
	t += "\n[b]What happened last month[/b]\n"
	var facts := w.facts.query("", w.month - 1, w.month - 1, "PUBLIC")
	var lines := NewsText.digest(w, facts, 12, 30)
	if lines.is_empty():
		t += "[i]A quiet month.[/i]\n"
	for line in lines:
		t += "• %s\n" % line
	return t


func _panel_district() -> String:
	var w := session.world()
	var e := EconQuery.district_economy(w, selected_district)
	var dp: Dictionary = session.district_politics().get(selected_district, {})
	var t := "[b]%s[/b]\n\n" % e.get("name", selected_district)
	t += "Population (voters): %d\nGovernment approval here: %.0f%%\nEconomic lean: %s\n\n" % [
		int(dp.get("pop", 0)), dp.get("approval", 0.0), _lean_text(dp.get("lean", 0.0))]
	t += "[b]Conditions[/b]\n"
	var keys := e.keys()
	keys.sort()
	for k in keys:
		if String(k).begins_with("ECON_"):
			t += "  %s: %.1f\n" % [String(k).trim_prefix("ECON_").replace("_", " ").capitalize(), e[k]]
	t += "\nHouseholds %.0f, housing units %.0f, private rent %s\n" % [e.get("households", 0.0), e.get("housing_units", 0.0), _money(e.get("private_rent", 0.0))]
	return t


func _panel_politics() -> String:
	var w := session.world()
	var st := session.pol_state()
	var t := "[b]%s[/b]\n" % session.government_text()
	t += "Next election: month %d (%s)\n\n" % [session.next_election_month(), "%d months away" % (session.next_election_month() - w.month)]
	var parties: Array = w.peek("party").values().filter(func(p): return p["status"] == "ACTIVE")
	if parties.is_empty():
		t += "[i]No parties yet. Political movements will organise into parties in Year 3.[/i]\n"
		for m in st.get("movements", []):
			t += "• Movement over [b]%s[/b] (since month %d)\n" % [String(m["concern"]).capitalize(), m["month"]]
		return t
	parties.sort_custom(func(a, b): return a["seats"] > b["seats"])
	var poll: Dictionary = w.peek("poll").get(st.get("last_poll", ""), {})
	t += "[table=4][cell][b]Party[/b][/cell][cell][b]Seats[/b][/cell][cell][b]Last poll[/b][/cell][cell][b]Leader[/b][/cell]"
	for p in parties:
		var col: String = p["color"]
		var nm: String = p["name"] + (" (you)" if p["is_player"] else "")
		t += "[cell][color=%s]■[/color] %s[/cell][cell]%d[/cell][cell]%.1f%%[/cell][cell]%s[/cell]" % [
			col, nm, p["seats"], poll.get("estimates", {}).get(p["id"], 0) / 1000.0, PartyLife.leader_name(p)]
	t += "[/table]\n\n[b]Platforms[/b] (left/right on each axis)\n"
	for p in parties:
		var pos: Dictionary = p["positions"]
		t += "[color=%s]■[/color] %s: econ %+d, redistrib %+d, labour %+d, environment %+d\n" % [
			p["color"], p["name"], pos["ECON_ROLE"] / 1000, pos["REDISTRIBUTION"] / 1000, pos["LABOR"] / 1000, pos["ENVIRONMENT"] / 1000]
	return t


func _panel_economy() -> String:
	var b := EconQuery.budget_view(session.world())
	var t := "[b]Public finances[/b]\n"
	t += "Treasury %s, debt %s, credit headroom %s\nRunway %d months, budget balance %d%%, origin grant this month %s\n\n" % [
		_money(b["treasury"]), _money(b["debt"]), _money(b["credit_headroom"]), b["runway_months"], b["balance_pct"], _money(b["grant_this_month"])]
	t += "[b]Budget lines (annual)[/b]\n"
	for l in b["lines"]:
		t += "  %s: %s (spent this year %s)\n" % [l["label"], _money(l["annual"]), _money(l["spent_ytd"])]
	t += "\n[b]Taxes[/b]\n  Income %s%%, profit %s%%, tariff %s%%\n" % [b["tax_levers"]["income"], b["tax_levers"]["profit"], b["tax_levers"]["tariff"]]
	return t


func _panel_laws() -> String:
	var w := session.world()
	var t := "[b]Recent bills and ordinances[/b]\n"
	var bills: Array = w.peek("bill").values()
	bills.reverse()
	for b in bills.slice(0, 20):
		var cl: Array = b["clauses"].map(func(c): return "%s %s→%s" % [String(c["lever"]).trim_prefix("ECON_").replace("_", " ").to_lower(), c["from"], c["to"]])
		t += "• m%d [b]%s[/b] (%d–%d): %s\n" % [b["month"], b["status"], b["yes"], b["no"], ", ".join(cl)]
	if bills.is_empty():
		t += "[i]No parliamentary bills yet.[/i]\n"
	t += "\n[b]Decided policy changes[/b] (ordinances, laws, decisions)\n"
	var rows: Array = w.peek("enactment").values()
	rows.reverse()
	for e in rows.slice(0, 25):
		var st: String = e["status"]
		var col: String = {"EFFECTIVE": "#8bc34a", "REJECTED": "#ef5350", "CANCELLED": "#9e9e9e"}.get(st, "#ffcc66")
		t += "• m%d %s: %s → %s  [color=%s]%s[/color]\n" % [e["decided_month"], e["legal_level"].to_lower(),
			String(e["lever"]).trim_prefix("ECON_").replace("_", " ").to_lower(), e["value"], col, st.to_lower()]
	return t


func _panel_news() -> String:
	var w := session.world()
	var t := "[b]Colony record (last 6 months)[/b]\n"
	var facts := w.facts.query("", w.month - 6, w.month, "PUBLIC")
	facts.reverse()
	for f in facts.slice(0, 40):
		t += "m%d  %s\n" % [f["month"], _fact_text(f)]
	return t


func _fact_text(f: Dictionary) -> String:
	return NewsText.sentence(session.world(), f)


static func _lean_text(v: float) -> String:
	if v > 15: return "clearly left"
	if v > 5: return "centre-left"
	if v < -15: return "clearly right"
	if v < -5: return "centre-right"
	return "centre"
