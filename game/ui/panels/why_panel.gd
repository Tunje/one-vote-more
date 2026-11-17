extends VBoxContainer
## Why? — the shortage explainer (econ Rule 10, ui-econ §5). Starts from what is short (goods and utilities), lists
## the producing facilities with their causes, and explains recent economic events through their causal chain.
## Reads: EconQuery (shortages, explain_facility via shortages, recent_econ_facts, explain_fact, market_overview). Writes: none.

const Kit := preload("res://ui/panels/panel_kit.gd")
const EK := preload("res://ui/panels/econ_kit.gd")

var session
var body: VBoxContainer
var open_good := ""
var open_fact := ""


func panel_title() -> String:
	return "Why?"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	_shortages(w)
	Kit.sep(body)
	_markets(w)
	Kit.sep(body)
	_events(w)


func _shortages(w: WorldState) -> void:
	var sh: Array = EconQuery.shortages(w)
	Kit.header(body, "What is short right now?")
	if sh.is_empty():
		Kit.label(body, "Nothing: every market and utility met at least 97% of demand last month.", 13, EK.GOOD)
		return
	for s in sh:
		var good: String = s["good"]
		var r := Kit.hbox(body)
		var price_txt := "" if s["base_price"] <= 0.0 else " · price %s (normal %s)" % [EK.money(s["price"]), EK.money(s["base_price"])]
		Kit.label(r, "%s: %.0f%% of demand met (%.0f of %.0f)%s" % [good.capitalize(), s["filled_pct"], s["filled"], s["wanted"], price_txt], 14,
			EK.BAD if s["filled_pct"] < 80.0 else EK.WARN)
		Kit.button(r, "Why?" if open_good != good else "Hide", func(): open_good = "" if open_good == good else good; refresh())
		if open_good == good:
			_producers(s["producers"])


func _producers(list: Array) -> void:
	if list.is_empty():
		Kit.label(body, "    Nobody in the colony produces this. Build or import it.", 12, EK.WARN)
		return
	var shown := 0
	for p in list:
		if shown >= 8:
			Kit.label(body, "    … %d more facilities" % (list.size() - shown), 12, EK.MUTED)
			break
		shown += 1
		var r := Kit.hbox(body)
		Kit.label(r, "    %s %s in %s (%s): running at %.0f%%" % [String(p["type"]).capitalize(), p["facility"], EK.district_name(p["district"]), p["owner"], p["utilization_pct"]], 13)
		var fid: String = p["facility"]
		var oid: String = session.world().peek("facility").get(fid, {}).get("org", "")
		Kit.button(r, "Company", func(): _open_company(oid))
		EK.causes(body, p["causes"], "        ")


func _open_company(oid: String) -> void:
	var c := EK.find_panel(self, "", "open_company")
	if c == null:
		return
	c.open_company(oid)
	EK.show_panel(self, c.panel_title())


func _markets(w: WorldState) -> void:
	Kit.header(body, "Markets last month")
	var g := EK.grid(body, ["Good", "Price", "vs normal", "Supply", "Demand", "Main sellers"])
	for m in EconQuery.market_overview(w):
		if not m.has("price"):
			EK.cell(g, String(m["good"]).capitalize())
			EK.cell(g, "tariff %s" % str(m["tariff"]))
			EK.cell(g, "")
			EK.cell(g, "%.0f" % m["supply"])
			EK.cell(g, "%.0f" % m["demand"], EK.BAD if m["demand"] > m["supply"] * 1.01 else Color.WHITE)
			EK.cell(g, "public utility", EK.MUTED)
			continue
		var rel: float = 100.0 * m["price"] / maxf(0.001, m["base_price"])
		EK.cell(g, String(m["good"]).capitalize())
		EK.cell(g, EK.money(m["price"]))
		EK.cell(g, "%.0f%%" % rel, EK.BAD if rel > 150.0 else (EK.WARN if rel > 115.0 else Color.WHITE))
		EK.cell(g, "%.0f" % m["offered"])
		EK.cell(g, "%.0f" % m["wanted"])
		var sellers: Dictionary = m["seller_share_pct"]
		var names: Array = sellers.keys()
		names.sort_custom(func(a, b): return sellers[a] > sellers[b])
		EK.cell(g, ", ".join(names.slice(0, 3).map(func(n): return "%s %.0f%%" % [n, sellers[n]])), EK.MUTED)


func _events(w: WorldState) -> void:
	Kit.header(body, "Recent economic events")
	var official := EK.official_visible(session)
	var shown := 0
	for f in EconQuery.recent_econ_facts(w, 6, 30):
		if not official and String(w.facts.get_fact(f["fact"]).get("visibility", "PUBLIC")) != "PUBLIC":
			continue
		if shown >= 20:
			break
		shown += 1
		var r := Kit.hbox(body)
		var where := "" if f["location"] == null else " in " + EK.district_name(str(f["location"]))
		Kit.label(r, "month %d: %s%s" % [f["month"], String(f["type"]).trim_prefix("ECON_").replace("_", " ").to_lower(), where], 13)
		var fid: String = f["fact"]
		Kit.button(r, "Why?" if open_fact != fid else "Hide", func(): open_fact = "" if open_fact == fid else fid; refresh())
		if open_fact == fid:
			_explain(w, fid)
	if shown == 0:
		Kit.label(body, "No notable economic events in the last 6 months.", 12, EK.MUTED)


func _explain(w: WorldState, fid: String) -> void:
	var chain: Array = EconQuery.explain_fact(w, fid)
	for i in chain.size():
		var e: Dictionary = chain[i]
		var resp: Array = e["responsible"].map(func(x): return "%s %d%%" % [str(x.get("actor", {}).get("id", "?")), int(round(100.0 * float(x.get("share", 0.0))))]) if e["responsible"] is Array else []
		Kit.label(body, "    %s month %d %s %s%s" % ["•" if i == 0 else "  ← caused by", e["month"], String(e["type"]).replace("_", " ").to_lower(),
			_data_text(e["data"]), ("   responsible: " + ", ".join(resp)) if not resp.is_empty() else ""], 12, EK.MUTED if i > 0 else Color.WHITE)
		# facility / project referenced by the fact → their own causes
		var data: Dictionary = e["data"] if e["data"] is Dictionary else {}
		if data.has("facility") and w.peek("facility").has(data["facility"]):
			EK.causes(body, EconQuery.explain_facility(w, data["facility"])["causes"], "        ")
		if data.has("project") and w.peek("project").has(data["project"]) and w.peek("project")[data["project"]]["status"] == "ACTIVE":
			EK.causes(body, EconQuery.explain_project(w, data["project"]), "        ")


func _data_text(d) -> String:
	if not (d is Dictionary) or d.is_empty():
		return ""
	var parts: Array = []
	for k in d:
		if parts.size() >= 4:
			break
		parts.append("%s %s" % [k, str(d[k])])
	return "(" + ", ".join(parts) + ")"
