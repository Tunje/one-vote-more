extends VBoxContainer
## Companies: directory (filter by type/status/sector/district) and profile with facilities, P&L, history (ui-econ §3).
## Each facility has a "why?" link (explain_facility). Financial columns are official (government) data.
## Reads: EconQuery (companies, company_profile, explain_facility, explain_fact). Writes: EconActions.ECON_SUBSIDIZE.

const Kit := preload("res://ui/panels/panel_kit.gd")
const EK := preload("res://ui/panels/econ_kit.gd")

var session
var body: VBoxContainer
var msg := ""
var selected := ""          # org id shown in the profile
var why_facility := ""      # facility whose causes are expanded
var why_fact := ""          # fact whose causal chain is expanded
var f_type := "ALL"
var f_sector := "ALL"
var f_district := "ALL"
var show_dissolved := false


func panel_title() -> String:
	return "Companies"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


## Open a company's profile (used by the Why? panel).
func open_company(oid: String) -> void:
	selected = oid
	refresh()


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	if msg != "":
		Kit.label(body, msg, 13, EK.WARN)
	if selected != "" and w.peek("org").has(selected):
		_profile(w)
		Kit.sep(body)
	_directory(w)


# ---------------------------------------------------------------- directory

func _directory(w: WorldState) -> void:
	var all: Array = EconQuery.companies(w, show_dissolved)
	var official := EK.official_visible(session)
	Kit.header(body, "Company directory")
	var types := ["ALL"]
	var sectors := ["ALL"]
	for c in all:
		if not types.has(c["type"]):
			types.append(c["type"])
		for s in c["sectors"]:
			if not sectors.has(s):
				sectors.append(s)
	sectors.sort()
	var row := Kit.hbox(body)
	_filter(row, "Type", types, f_type, func(v): f_type = v)
	_filter(row, "Sector", sectors, f_sector, func(v): f_sector = v)
	_filter(row, "District", ["ALL"] + EconUtil.sorted_keys(EconData.DISTRICTS), f_district, func(v): f_district = v)
	var chk := CheckBox.new()
	chk.text = "Dissolved"
	chk.button_pressed = show_dissolved
	chk.toggled.connect(func(on): show_dissolved = on; refresh())
	row.add_child(chk)
	var list: Array = all.filter(_matches)
	list.sort_custom(func(a, b): return a["employees"] > b["employees"] or (a["employees"] == b["employees"] and a["id"] < b["id"]))
	var heads := ["Company", "Type", "Status", "HQ", "Sectors", "Staff", "Reliab."]
	if official:
		heads += ["Cash", "Debt", "Profit/mo"]
	var g := EK.grid(body, heads)
	for c in list:
		var oid: String = c["id"]
		var b := Button.new()
		b.text = c["name"]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): selected = oid; why_facility = ""; why_fact = ""; refresh())
		g.add_child(b)
		EK.cell(g, String(c["type"]).to_lower().replace("_", " "))
		EK.cell(g, String(c["status"]).to_lower(), Color.WHITE if c["status"] == "ACTIVE" else EK.BAD)
		EK.cell(g, EK.district_name(c["hq"]))
		EK.cell(g, ", ".join(c["sectors"].map(func(s): return String(s).to_lower())))
		EK.cell(g, "%.0f" % c["employees"])
		EK.cell(g, str(c["reliability"]))
		if official:
			EK.cell(g, EK.money(c["cash"]))
			EK.cell(g, EK.money(c["debt"]))
			EK.cell(g, EK.money(c["profit_last_month"]), EK.GOOD if c["profit_last_month"] >= 0.0 else EK.BAD)
	if list.is_empty():
		Kit.label(body, "No companies match.", 12, EK.MUTED)


func _matches(c: Dictionary) -> bool:
	return (f_type == "ALL" or c["type"] == f_type) and (f_sector == "ALL" or c["sectors"].has(f_sector)) and (f_district == "ALL" or c["hq"] == f_district)


func _filter(row: HBoxContainer, label: String, values: Array, current: String, set_cb: Callable) -> void:
	Kit.label(row, label, 12, EK.MUTED)
	var o := OptionButton.new()
	for i in values.size():
		var v: String = values[i]
		o.add_item(EK.district_name(v) if v.begins_with("d:") else v.to_lower().replace("_", " "))
		if v == current:
			o.select(i)
	o.item_selected.connect(func(i): set_cb.call(values[i]); refresh())
	row.add_child(o)


# ---------------------------------------------------------------- profile

func _profile(w: WorldState) -> void:
	var p: Dictionary = EconQuery.company_profile(w, selected)
	var official := EK.official_visible(session)
	var top := Kit.hbox(body)
	Kit.header(top, "%s  (%s, %s)" % [p["name"], String(p["type"]).to_lower().replace("_", " "), String(p["status"]).to_lower()])
	Kit.button(top, "Close", func(): selected = ""; refresh())
	Kit.label(body, "HQ %s · CEO management %d, risk appetite %d, age %d · reliability %d · construction crew %.0f · %d active contracts" % [
		EK.district_name(p["hq"]), p["ceo"]["management"], p["ceo"]["risk"], p["ceo"]["age"], p["reliability"], p["crew"], p["contracts"].size()], 13)
	if official:
		Kit.label(body, "Cash %s · debt %s" % [EK.money(p["cash"]), EK.money(p["debt"])], 13)
		var pl: Dictionary = p["pl_last_month"]
		if not pl.is_empty():
			var keys: Array = pl.keys()
			keys.sort()
			Kit.label(body, "Last month: " + " · ".join(keys.map(func(k): return "%s %s" % [k, EK.money(pl[k])])), 12, EK.MUTED)
		_subsidy(w)
	Kit.label(body, "Facilities", 14, Color(0.85, 0.9, 1.0))
	if p["facilities"].is_empty():
		Kit.label(body, "  none", 12, EK.MUTED)
	for f in p["facilities"]:
		var r := Kit.hbox(body)
		var under: bool = f["utilization_pct"] < f["target_pct"] - 5.0 or f["mothballed"] or f["utilization_pct"] < 60.0
		Kit.label(r, "  %s %s in %s · running %.0f%% (plan %.0f%%) · staff %.0f · condition %.0f%s%s" % [String(f["type"]).capitalize(), f["id"],
			EK.district_name(f["district"]), f["utilization_pct"], f["target_pct"], f["staff"], f["condition"],
			" · MOTHBALLED" if f["mothballed"] else "", "" if f["licensed"] else " · UNLICENSED"], 13, EK.WARN if under else Color.WHITE)
		var fid: String = f["id"]
		Kit.button(r, "Why?" if why_facility != fid else "Hide", func(): why_facility = "" if why_facility == fid else fid; refresh())
		if why_facility == fid:
			EK.causes(body, EconQuery.explain_facility(w, fid)["causes"], "      ")
	Kit.label(body, "History", 14, Color(0.85, 0.9, 1.0))
	var hist: Array = p["history"].duplicate()
	hist.reverse()
	for h in hist.slice(0, 12):
		var r := Kit.hbox(body)
		Kit.label(r, "  month %d: %s" % [h["month"], String(h["type"]).trim_prefix("ECON_").replace("_", " ").to_lower()], 12)
		var fid2: String = h["fact"]
		Kit.button(r, "Why?" if why_fact != fid2 else "Hide", func(): why_fact = "" if why_fact == fid2 else fid2; refresh())
		if why_fact == fid2:
			for e in EconQuery.explain_fact(w, fid2):
				Kit.label(body, "      ← month %d %s %s" % [e["month"], String(e["type"]).replace("_", " ").to_lower(), str(e["data"])], 11, EK.MUTED)


func _subsidy(w: WorldState) -> void:
	var room := float(EconActions.headroom(w, "ECON_BUDGET_SUBSIDIES")) / 1000.0
	var r := Kit.hbox(body)
	Kit.label(r, "Grant a subsidy (Subsidies line, %s left):" % EK.money(room), 12, EK.MUTED)
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = maxf(0.0, room)
	spin.step = 1000
	spin.suffix = "cr"
	r.add_child(spin)
	var oid := selected
	var btn := Kit.button(r, "Subsidize", func(): _subsidize(oid, int(spin.value)), true)
	var why := Kit.label(r, "", 12, EK.BAD)
	var recheck := func(v: float):
		var c: Dictionary = EconActions.check(w, "ECON_SUBSIDIZE", {"org": oid, "amount": int(v)})
		btn.disabled = not c["ok"]
		btn.tooltip_text = c["error"]
		why.text = "" if c["ok"] or v <= 0.0 else "✗ " + String(c["error"])
	spin.value_changed.connect(recheck)
	recheck.call(spin.value)


func _subsidize(oid: String, amount: int) -> void:
	if amount <= 0:
		return
	var w: WorldState = session.world()
	var res: Dictionary = EconActions.enqueue(w, "ECON_SUBSIDIZE", {"org": oid, "amount": amount})
	if not res["ok"]:
		msg = "✗ " + String(res["error"])
		get_tree().call_group("pcs_refresh", "refresh_all")
		return
	msg = "Subsidy of %s queued for %s (public, paid when the month ends)." % [EK.money(float(amount)), w.peek("org")[oid]["name"]]
	get_tree().call_group("pcs_refresh", "refresh_all")
