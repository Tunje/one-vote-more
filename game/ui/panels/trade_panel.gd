extends VBoxContainer
## Trade (A42 D1, spec-demand-v1 §D6): the next ship, what waits at the port, home-world prices against local prices
## (after freight, the charter levy and the export tax), the last ship's cargo and earnings, and the trade balance.
## Read-only; trade itself is decided by firms (and taxed by law).

const Kit := preload("res://ui/panels/panel_kit.gd")
const Gazette := preload("res://ui/panels/gazette_panel.gd")
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var session
var body: VBoxContainer


func panel_title() -> String:
	return "Trade"


func setup(s) -> void:
	session = s
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	body = Kit.scroll_body(self)


func refresh() -> void:
	if session == null or body == null:
		return
	Kit.clear(body)
	var w: WorldState = session.world()
	if not w.table("econ").has("s"):
		Kit.label(body, "No economy yet.", 14)
		return
	var nxt := int(EconTrade.next_ship(w))
	Kit.header(body, "Next ship from the home world")
	Kit.label(body, "Expected around %s (%s from now). Ships come every 18–30 months; nobody knows the exact month." % [_month(nxt), NewsText.months(maxi(0, nxt - w.month))], 13)
	# port
	var stock: Dictionary = EconTrade.port_stock(w)
	var cap := int(EconTrade.port_capacity(w))
	var used := 0
	for g in stock:
		used += int(stock[g])
	Kit.header(body, "Waiting at the port")
	if used == 0:
		Kit.label(body, "Nothing consigned for export yet.", 12, Color("#aaaaaa"))
	else:
		for g in _sorted(stock):
			if int(stock[g]) <= 0:
				continue
			Kit.label(body, "  %s: %d units" % [_good(g), int(stock[g])], 12)
	Kit.label(body, "Warehouse space used: %d of %d units (depots add space)." % [used, cap], 12, Color("#aaaaaa"))
	# prices
	Kit.header(body, "Prices: home world vs colony (credits per unit)")
	var pr: Dictionary = EconTrade.prices(w)
	for g in _sorted(pr):
		var p: Dictionary = pr[g]
		var net := float(p.get("net", 0)) / 1000.0
		var local := float(p.get("local", 0)) / 1000.0
		var better := net > local * 1.1
		var extra := ""
		if int(p.get("levy", 0)) > 0 or int(p.get("tax", 0)) > 0:
			extra = "  (levy %d, export tax %d)" % [int(p.get("levy", 0)) / 1000, int(p.get("tax", 0)) / 1000]
		if p.get("reserved", false):
			extra += "  · reserved for the home world's buyer"
		Kit.label(body, "  %s: home %d − freight %d → %d net · colony %d%s%s" % [_good(g), int(p.get("home", 0)) / 1000, int(p.get("freight", 0)) / 1000, int(net), int(local),
			"  ← worth exporting" if better else "", extra], 12, Color("#8bc34a") if better else Color.WHITE)
	# last ship
	var ls: Dictionary = EconTrade.last_ship(w)
	Kit.header(body, "Last ship")
	if ls.is_empty() or int(ls.get("month", -1)) < 0:
		Kit.label(body, "No ship has called yet.", 12, Color("#aaaaaa"))
	else:
		Kit.label(body, "%s: exports worth %d cr (export tax %d, home-world levy %d); imports worth %d cr." % [_month(int(ls["month"])),
			int(ls.get("export_value", 0)) / 1000, int(ls.get("tax", 0)) / 1000, int(ls.get("levy", 0)) / 1000, int(ls.get("import_value", 0)) / 1000], 13)
		var ex: Dictionary = ls.get("exports", {})
		if not ex.is_empty():
			Kit.label(body, "  Out: " + ", ".join(_sorted(ex).map(func(g): return "%s %d" % [_good(g), int(ex[g])])), 12)
		var im: Dictionary = ls.get("imports", {})
		if not im.is_empty():
			Kit.label(body, "  In: " + ", ".join(_sorted(im).map(func(g): return "%s %d" % [_good(g), int(im[g])])), 12)
		var by: Dictionary = ls.get("by_org", {})
		if not by.is_empty():
			var orgs := by.keys()
			orgs.sort_custom(func(a, b): return int(by[a]) > int(by[b]) or (by[a] == by[b] and String(a) < String(b)))
			Kit.label(body, "  Top exporters: " + ", ".join(orgs.slice(0, 4).map(func(o): return "%s %d cr" % [NewsText.org(w, o), int(by[o]) / 1000])), 12)
	# balance
	var b: Dictionary = EconTrade.balance(w)
	var bal := int(b.get("balance_24m", 0)) / 1000
	Kit.header(body, "Trade balance (last 24 months)")
	Kit.label(body, "Exports %d cr · imports sold %d cr · balance %s%d cr" % [int(b.get("exports_24m", 0)) / 1000, int(b.get("imports_24m", 0)) / 1000, "+" if bal >= 0 else "", bal], 13,
		Color("#8bc34a") if bal >= 0 else Color("#ff8a65"))
	# history
	var rows: Array = w.facts.query("ECON_EXPORTS_SOLD", -1, 1 << 30, "PUBLIC") + w.facts.query("ECON_HOME_PRICE_SWING", -1, 1 << 30, "PUBLIC")
	if not rows.is_empty():
		rows.sort_custom(func(x, y): return x["month"] > y["month"] or (x["month"] == y["month"] and String(x["id"]) > String(y["id"])))
		Kit.header(body, "Trade news")
		for f in rows.slice(0, 15):
			Kit.label(body, "%s: %s" % [_month(int(f["month"])), Gazette.plain(NewsText.sentence(w, f))], 12)


static func _sorted(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


static func _good(g) -> String:
	return String(g).to_lower().replace("_", " ").capitalize()


static func _month(m: int) -> String:
	return "%s Year %d" % [MONTHS[posmod(m, 12)], m / 12 + 1]
