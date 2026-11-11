extends RefCounted
## Shared helpers for agent 88's economy panels (budget, projects, companies, why?). Not a panel itself.
## Reads: EconQuery / world.peek / LQ. Writes: EconActions only (+ pre-filling the Legislate panel, which drafts).

const Kit := preload("res://ui/panels/panel_kit.gd")
const LQ := preload("res://sim/law/law_query.gd")

const MUTED := Color(0.72, 0.72, 0.72)
const GOOD := Color(0.6, 1.0, 0.6)
const BAD := Color(1.0, 0.6, 0.6)
const WARN := Color(1.0, 0.85, 0.5)


static func money(credits: float) -> String:
	if absf(credits) >= 1_000_000.0:
		return "%.2fM" % (credits / 1_000_000.0)
	if absf(credits) >= 10_000.0:
		return "%.0fk" % (credits / 1000.0)
	return "%.0f" % credits


## Official (government-only) data is visible only when the player governs (pic-core §3 OFFICIAL).
static func official_visible(session) -> bool:
	return bool(Kit.ctx(session)["governing"])


static func district_name(d: String) -> String:
	return EconData.DISTRICTS.get(d, {}).get("name", d)


## Grid row helper: a GridContainer with `cols` columns and a header row.
static func grid(parent: Node, headers: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = headers.size()
	g.add_theme_constant_override("h_separation", 14)
	parent.add_child(g)
	for h in headers:
		Kit.label(g, h, 12, Color(0.75, 0.82, 0.95))
	return g


static func cell(g: GridContainer, text: String, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.modulate = color
	g.add_child(l)
	return l


## Lever info for a "propose change" control: {changeable, why_not, pending, legal, range}.
static func lever_info(world: WorldState, lever: String) -> Dictionary:
	for l in LQ.lever_catalog(world):
		if l["id"] == lever:
			return l
	return {}


## Panels live in modal windows (main.gd `windows`: title -> Window). Find a panel by title, or "" = any panel with `method`.
static func find_panel(node: Node, title: String, method: String = "") -> Node:
	for m in node.get_tree().get_nodes_in_group("pcs_refresh"):
		if not ("windows" in m):
			continue
		for t in m.windows:
			var p: Node = m.windows[t].get_child(1).get_child(0)
			if (title != "" and t == title) or (method != "" and p.has_method(method)):
				return p
	return null


## Close the caller's window and open the window titled `title` (modal windows cannot stack).
static func show_panel(node: Node, title: String) -> void:
	for m in node.get_tree().get_nodes_in_group("pcs_refresh"):
		if m.has_method("open_window"):
			var own := node.get_window()
			if own != null and own != node.get_tree().root:
				own.hide()
			m.open_window(title)
			return


## Pre-fill the Legislate panel with a clause and switch to it. Changing a budget line or tax is a law (A8):
## the player still drafts and submits it there. Returns an error text, or "" on success.
static func propose(node: Node, lever: String, value: int) -> String:
	var leg: Node = find_panel(node, "Legislate")
	if leg == null:
		return "Legislate panel not found"
	if leg.has_method("prefill"):
		leg.prefill(lever, value)
	else:
		var cl: Array = leg.clauses.filter(func(x): return x["lever"] != lever)
		if cl.size() >= 4:
			return "The draft already has 4 clauses"
		cl.append({"lever": lever, "to": value})
		leg.clauses = cl
	node.get_tree().call_group("pcs_refresh", "refresh_all")
	show_panel(node, "Legislate")
	return ""


## Short text of a lever's voter-concern hint (pic-core lever `concerns`, per full range).
static func concerns_text(world: WorldState, lever: String) -> String:
	var c: Dictionary = world.lever_defs.get(lever, {}).get("concerns", {})
	var parts: Array = []
	for k in c:
		parts.append("%s %+d" % [String(k).to_lower().replace("_", " "), int(c[k])])
	return ("raising it: " + ", ".join(parts)) if not parts.is_empty() else ""


## A cause list (explain_facility / explain_project) as labels with a severity bar.
static func causes(parent: Node, list: Array, indent: String = "    ") -> void:
	if list.is_empty():
		Kit.label(parent, indent + "No problems found.", 12, MUTED)
		return
	for c in list:
		var sev := clampf(float(c.get("severity", 0.0)), 0.0, 1.0)
		var bar := "█".repeat(int(round(sev * 10.0))) + "░".repeat(10 - int(round(sev * 10.0)))
		Kit.label(parent, "%s%s  %s: %s" % [indent, bar, String(c["cause"]).replace("_", " ").to_lower(), c["detail"]], 12,
			BAD if sev >= 0.5 else (WARN if sev >= 0.2 else MUTED))
