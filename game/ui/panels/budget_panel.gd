extends VBoxContainer
## Budget: treasury and fiscal health, budget lines, taxes, 12-month revenue/spending (ui-econ §1).
## Changing a line or tax is a law (A8): "Propose…" pre-fills the Legislate panel, where the player drafts it.
## Reads: EconQuery.budget_view, LQ.lever_catalog. Writes: none here (drafting happens in Legislate).

const Kit := preload("res://ui/panels/panel_kit.gd")
const EK := preload("res://ui/panels/econ_kit.gd")

const TAX_LEVERS := [
	["ECON_INCOME_TAX_RATE", "Income tax", "%"], ["ECON_TAX_ALLOWANCE", "Tax-free allowance", "cr/month"],
	["ECON_PROFIT_TAX_RATE", "Profit tax", "%"], ["ECON_SALES_TAX", "Sales tax", "%"],
	["ECON_IMPORT_TARIFF", "Import tariff", "%"],
]
const PRICE_LEVERS := [
	["ECON_UTILITY_TARIFF_ENERGY", "Energy tariff", "cr/unit"], ["ECON_UTILITY_TARIFF_WATER", "Water tariff", "cr/unit"],
	["ECON_PUBLIC_RENT", "Public housing rent", ""], ["ECON_MIN_WAGE", "Minimum wage", ""],
]
const SOCIAL_LEVERS := [
	["ECON_UNEMPLOYMENT_BENEFIT_RATE", "Unemployment benefit", "% of wage"], ["ECON_BENEFIT_FLOOR", "Benefit floor", "% of basket"],
	["ECON_BENEFIT_DURATION", "Full benefit duration", "months"],
	["ECON_PENSION_RATE", "Pension", "% of wage"], ["ECON_FOOD_ASSISTANCE", "Food assistance", "%"],
]

var session
var body: VBoxContainer
var msg := ""
var edit_lever := ""     # lever whose "propose" editor is open


func panel_title() -> String:
	return "Budget"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	var b := EconQuery.budget_view(w)
	var official := EK.official_visible(session)
	if msg != "":
		Kit.label(body, msg, 13, EK.WARN)
	_header(b, official)
	Kit.sep(body)
	_lines(w, b)
	Kit.sep(body)
	_levers(w, "Taxes", TAX_LEVERS)
	_levers(w, "Social payments", SOCIAL_LEVERS)
	_levers(w, "Public prices", PRICE_LEVERS)
	Kit.sep(body)
	_flows(b)


func _header(b: Dictionary, official: bool) -> void:
	Kit.header(body, "Public finances")
	Kit.label(body, "Treasury %s   ·   Debt %s (%.0f%% of revenue)   ·   Bank credit left %s   ·   Origin grant this month %s" % [
		EK.money(b["treasury"]), EK.money(b["debt"]), b["debt_ratio_pct"], EK.money(b["credit_headroom"]), EK.money(b["grant_this_month"])], 14)
	var bal: float = b["balance_pct"]
	Kit.label(body, "Budget balance (12 months): %+.1f%% of revenue" % bal, 14, EK.GOOD if bal >= 0.0 else EK.BAD)
	if official:
		var rw: float = b["runway_months"]
		Kit.label(body, "Runway: %.0f months of spending in cash   ·   Operating balance %+.1f%%   (official)" % [rw, b["operating_balance_pct"]], 13,
			EK.BAD if rw < 12.0 else (EK.WARN if rw < 24.0 else EK.GOOD))
	else:
		Kit.label(body, "Runway and operating balance are government data (oversight can request a briefing).", 12, EK.MUTED)


func _lines(w: WorldState, b: Dictionary) -> void:
	Kit.header(body, "Budget lines (per year)")
	var g := EK.grid(body, ["Line", "Appropriated", "Spent this year", "Uncommitted", ""])
	for ln in b["lines"]:
		EK.cell(g, ln["label"])
		EK.cell(g, EK.money(ln["annual"]))
		var used: float = 0.0 if ln["annual"] <= 0.0 else 100.0 * ln["spent_ytd"] / ln["annual"]
		EK.cell(g, "%s (%.0f%%)" % [EK.money(ln["spent_ytd"]), used], EK.WARN if used > 90.0 else Color.WHITE)
		EK.cell(g, EK.money(ln["headroom"]), EK.BAD if ln["headroom"] < 0.0 else Color.WHITE)
		var lid: String = ln["lever"]
		Kit.button(g, "Propose…", func(): edit_lever = "" if edit_lever == lid else lid; refresh())
		if edit_lever == lid:
			_editor(w, lid, "k cr/year")


func _levers(w: WorldState, title: String, list: Array) -> void:
	Kit.header(body, title)
	var g := EK.grid(body, ["Setting", "Now", "Unit", ""])
	for row in list:
		var lid: String = row[0]
		if not w.lever_defs.has(lid):
			continue
		EK.cell(g, row[1])
		EK.cell(g, str(w.levers.get(lid, w.lever_defs[lid]["default"])))
		EK.cell(g, row[2], EK.MUTED)
		Kit.button(g, "Propose…", func(): edit_lever = "" if edit_lever == lid else lid; refresh())
		if edit_lever == lid:
			_editor(w, lid, row[2])


## Inline editor below the grid: new value, voter-concern hint, legality, "Add to draft".
func _editor(w: WorldState, lid: String, unit: String) -> void:
	var info := EK.lever_info(w, lid)
	var box := Kit.vbox(body)
	Kit.label(box, "Change %s" % lid, 13, Color(0.85, 0.9, 1.0))
	var hint := EK.concerns_text(w, lid)
	if hint != "":
		Kit.label(box, "Voters care about this (%s)." % hint, 12, EK.MUTED)
	if info.is_empty():
		Kit.label(box, "Not legislatable.", 12, EK.BAD)
		return
	if not info["pending"].is_empty():
		Kit.label(box, "A change to this setting is already in the legislative pipeline.", 12, EK.WARN)
	if not info["changeable"]:
		Kit.label(box, "Cannot be changed now: %s" % info["why_not"], 12, EK.BAD)
		return
	var row := Kit.hbox(box)
	var spin := SpinBox.new()
	spin.min_value = float(info["range"][0])
	spin.max_value = float(info["range"][1])
	spin.step = 1
	spin.value = float(w.levers.get(lid, info["default"]))
	spin.suffix = unit
	spin.custom_minimum_size.x = 160
	row.add_child(spin)
	var go := func():
		var err := EK.propose(self, lid, int(spin.value))
		msg = ("Added to your draft in Legislate: %s → %d. Draft and submit it there." % [lid, int(spin.value)]) if err == "" else "✗ " + err
		edit_lever = ""
		refresh()
	Kit.button(row, "Add to draft in Legislate", go)
	Kit.button(row, "Cancel", func(): edit_lever = ""; refresh())


func _flows(b: Dictionary) -> void:
	Kit.header(body, "Last 12 months")
	var cols := Kit.hbox(body)
	for pair in [["Revenue", b["revenue_12m"]], ["Spending", b["spending_12m"]]]:
		var v := Kit.vbox(cols)
		Kit.label(v, pair[0], 14, Color(0.85, 0.9, 1.0))
		var d: Dictionary = pair[1]
		var keys: Array = d.keys()
		keys.sort_custom(func(a, c): return d[a] > d[c])
		var total := 0.0
		for k in keys:
			total += d[k]
		for k in keys:
			Kit.label(v, "  %s  %s (%.0f%%)" % [String(k).replace("_", " ").to_lower(), EK.money(d[k]), 100.0 * d[k] / maxf(1.0, total)], 12)
		Kit.label(v, "  total %s" % EK.money(total), 12, EK.MUTED)
