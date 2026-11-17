extends VBoxContainer
## Projects: commission public works, compare bids and choose a contractor, track projects and their blockers (ui-econ §2).
## Reads: EconQuery (commission_options, tenders, bid_breakdown, projects, explain_project).
## Writes: EconActions only (commission, award, re-tender, cancel; applied at the start of next month) and the
## manual-award player option.

const Kit := preload("res://ui/panels/panel_kit.gd")
const EK := preload("res://ui/panels/econ_kit.gd")

const PART_COLORS := [Color(0.45, 0.7, 1.0), Color(0.55, 0.9, 0.55), Color(1.0, 0.8, 0.4)]

var session
var body: VBoxContainer
var msg := ""
var show_done := false


func panel_title() -> String:
	return "Projects"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


## A button for an econ action, disabled with the reason (tooltip) when EconActions.check says it would fail.
func _act_button(parent: Node, label: String, id: String, params: Dictionary, text: String) -> Button:
	var c: Dictionary = EconActions.check(session.world(), id, params)
	var b := Kit.button(parent, label, func(): _queue(id, params, text), not c["ok"])
	b.tooltip_text = c["error"]
	return b


func _queue(id: String, params: Dictionary, text: String) -> void:
	var res: Dictionary = EconActions.enqueue(session.world(), id, params)
	msg = (text + " (takes effect when the month ends)") if res["ok"] else "✗ " + String(res["error"])
	get_tree().call_group("pcs_refresh", "refresh_all")


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	if msg != "":
		Kit.label(body, msg, 13, EK.WARN)
	var governing := EK.official_visible(session)
	if governing:
		_commission(w)
		Kit.sep(body)
	_tenders(w, governing)
	Kit.sep(body)
	_projects(w, governing)


# ---------------------------------------------------------------- commission

func _commission(w: WorldState) -> void:
	Kit.header(body, "Commission a public project")
	var opts: Array = EconQuery.commission_options(w)
	var row := Kit.hbox(body)
	var type_opt := OptionButton.new()
	for o in opts:
		type_opt.add_item("%s  ~%s%s" % [String(o["type"]).capitalize(), EK.money(o["estimate"]), "" if o["enabled"] else "  (no budget)"])
	row.add_child(type_opt)
	var dist_opt := OptionButton.new()
	var dists: Array = EconUtil.sorted_keys(EconData.DISTRICTS)
	for d in dists:
		dist_opt.add_item(EK.district_name(d))
	row.add_child(dist_opt)
	var info := Kit.label(body, "", 12, EK.MUTED)
	var sync := func(i: int):
		if i >= 0 and i < opts.size():
			var o: Dictionary = opts[i]
			info.text = "Paid from %s (%s uncommitted this year). Lines allowed: %s.%s" % [EconQuery.LINE_LABELS.get(o["line"], o["line"]), EK.money(o["headroom"]),
				", ".join(o["lines"].map(func(l): return "%s %s" % [l["label"], EK.money(l["headroom"])])), "" if o["enabled"] else "  ✗ " + String(o["reason"])]
			info.modulate = EK.MUTED if o["enabled"] else EK.BAD
	type_opt.item_selected.connect(sync)
	if not opts.is_empty():
		sync.call(0)
	var go := func():
		var o: Dictionary = opts[type_opt.selected]
		var d: String = dists[dist_opt.selected]
		_queue("ECON_COMMISSION_PROJECT", {"type": o["type"], "district": d, "line": o["line"]}, "Commissioned %s in %s; a tender opens" % [String(o["type"]).capitalize(), EK.district_name(d)])
	var btn := Kit.button(row, "Commission", go, opts.is_empty())
	var why := Kit.label(body, "", 12, EK.BAD)
	var recheck := func(_i = 0):
		if opts.is_empty():
			return
		var o: Dictionary = opts[type_opt.selected]
		var c: Dictionary = EconActions.check(w, "ECON_COMMISSION_PROJECT", {"type": o["type"], "district": dists[dist_opt.selected], "line": o["line"]})
		btn.disabled = not c["ok"]
		btn.tooltip_text = c["error"]
		why.text = "" if c["ok"] else "✗ " + String(c["error"])
	type_opt.item_selected.connect(recheck)
	dist_opt.item_selected.connect(recheck)
	recheck.call()
	var manual := CheckBox.new()
	manual.text = "I choose contractors myself (otherwise the procurement official awards the top score)"
	manual.button_pressed = bool(w.meta.get("manual_award", false))
	manual.toggled.connect(func(on): EconActions.set_manual_award(session.world(), on); refresh())
	body.add_child(manual)
	for r in EconActions.last_results(w, 5):
		if not r["ok"] and r["m"] >= w.month - 1:
			Kit.label(body, "  last month: %s failed — %s" % [String(r["id"]).trim_prefix("ECON_").replace("_", " ").to_lower(), r.get("error", "")], 12, EK.BAD)
	var pend: Array = EconActions.pending(w)
	for a in pend:
		Kit.label(body, "  queued: %s %s" % [String(a["id"]).trim_prefix("ECON_").replace("_", " ").to_lower(), str(a["params"])], 12, EK.MUTED)


# ---------------------------------------------------------------- tenders + bid comparison

func _tenders(w: WorldState, governing: bool) -> void:
	var ts: Array = EconQuery.tenders(w)
	Kit.header(body, "Open tenders (%d)" % ts.size())
	if ts.is_empty():
		Kit.label(body, "No open tenders.", 12, EK.MUTED)
	var manual := bool(w.meta.get("manual_award", false))
	for t in ts:
		var mine: bool = t["owner"] == "gov"
		Kit.label(body, "%s · %s in %s · estimate %s · at least %d months · %s%s" % [t["project"], String(t["type"]).capitalize(), EK.district_name(t["district"]),
			EK.money(t["est_cost"]), t["min_months"], "public" if mine else "private", "" if t["status"] == "TENDER" else " · NO VALID BIDS"], 14,
			Color.WHITE if t["status"] == "TENDER" else EK.BAD)
		if mine and manual and t["status"] == "TENDER":
			Kit.label(body, "  You have %d month(s) left to choose; otherwise the top score wins." % maxi(0, 3 - (w.month - int(t["tender_month"]))), 12, EK.WARN)
		_bids(t, governing and mine and manual)
		if governing and mine:
			var r := Kit.hbox(body)
			var pid: String = t["project"]
			_act_button(r, "Re-tender", "ECON_RETENDER_PROJECT", {"project": pid}, "Re-tendering " + pid)
			_act_button(r, "Cancel project", "ECON_CANCEL_PROJECT", {"project": pid}, "Cancelling " + pid)


## Stacked score bars: price / reliability / duration parts, so the player sees WHY a bid ranks where it does.
func _bids(t: Dictionary, can_award: bool) -> void:
	var bids: Array = t["bids"]
	if bids.is_empty():
		Kit.label(body, "    no bids yet", 12, EK.MUTED)
		return
	var legend := Kit.hbox(body)
	for i in 3:
		Kit.label(legend, ["■ price", "■ reliability", "■ duration"][i], 11, PART_COLORS[i])
	for b in bids:
		var row := Kit.hbox(body)
		Kit.label(row, "  #%d %s" % [b["rank"], b["name"]], 13).custom_minimum_size.x = 210
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 0)
		bar.custom_minimum_size = Vector2(200, 14)
		for i in 3:
			var part: float = [b["price_part"], b["reliability_part"], b["duration_part"]][i]
			var cr := ColorRect.new()
			cr.color = PART_COLORS[i]
			cr.custom_minimum_size = Vector2(maxf(1.0, 200.0 * part), 14)
			cr.tooltip_text = "%s part %.2f" % [["price", "reliability", "duration"][i], part]
			bar.add_child(cr)
		row.add_child(bar)
		Kit.label(row, "score %.2f · %s · %d months · reliability %d%s" % [b["score"], EK.money(b["price"]), b["duration"], b["reliability"],
			"  ⚠ in financial distress" if b["distressed"] and EK.official_visible(session) else ""], 12)
		if can_award:
			var pid: String = t["project"]
			var org: String = b["org"]
			var label := "Award" if b["rank"] == 1 else "Award (override)"
			_act_button(row, label, "ECON_AWARD_CONTRACT", {"project": pid, "org": org},
				"Awarding %s to %s%s" % [pid, b["name"], "" if b["rank"] == 1 else " — overriding the top bid is public and may look like favouritism"])


# ---------------------------------------------------------------- projects + blockers

func _projects(w: WorldState, governing: bool) -> void:
	var ps: Array = EconQuery.projects(w, "gov")
	var active: Array = ps.filter(func(p): return p["status"] == "ACTIVE")
	Kit.header(body, "Public projects under construction (%d)" % active.size())
	var chk := CheckBox.new()
	chk.text = "Show finished and cancelled"
	chk.button_pressed = show_done
	chk.toggled.connect(func(on): show_done = on; refresh())
	body.add_child(chk)
	for p in ps:
		if p["status"] in ["TENDER", "TENDERABLE"]:
			continue
		if not show_done and p["status"] != "ACTIVE":
			continue
		var org_name: String = w.peek("org").get(p["contractor"], {}).get("name", "—")
		var late: int = p["months_late"]
		Kit.label(body, "%s · %s in %s · %s · %.0f%% done · %s · paid %s of %s%s" % [p["project"], String(p["type"]).capitalize(), EK.district_name(p["district"]),
			p["status"].to_lower(), p["progress_pct"], org_name, EK.money(p["paid"]), EK.money(p["price"]), ("  · %d months late" % late) if late > 0 else ""], 13,
			EK.BAD if late > 2 else Color.WHITE)
		var pb := ProgressBar.new()
		pb.value = p["progress_pct"]
		pb.custom_minimum_size = Vector2(300, 10)
		pb.show_percentage = false
		body.add_child(pb)
		if p["status"] == "ACTIVE":
			if not p["blockers"].is_empty():
				Kit.label(body, "  Why is it slow?", 12, EK.MUTED)
				EK.causes(body, p["blockers"])
			if governing:
				var pid: String = p["project"]
				_act_button(body, "Cancel (pays progress + 5%)", "ECON_CANCEL_PROJECT", {"project": pid}, "Cancelling " + pid)
