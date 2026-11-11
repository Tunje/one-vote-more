extends RefCounted
## Shared helpers for a9's panels (staff/law). Not a panel itself (the name doesn't end in _panel.gd).

const A := preload("res://sim/staff/staff_law_actions.gd")
const GOV_OWNER := {"kind": "GOVERNMENT", "id": "government"}


## Who the player is right now: {party_id, governing, era, viewer, gov_actor, party_actor}.
static func ctx(session) -> Dictionary:
	var st: Dictionary = session.pol_state()
	var pp := String(st.get("player_party", ""))
	var era := String(st.get("era", "FOUNDING"))
	var governing := era == "FOUNDING"
	if not governing and pp != "":
		governing = st.get("government", {}).get("members", []).has(pp)
	return {"party_id": pp, "governing": governing, "era": era,
		"viewer": {"party_id": pp} if pp != "" else {},
		"gov_actor": {"kind": "GOVERNMENT", "id": "government"},
		"party_actor": {"kind": "PARTY", "id": pp} if pp != "" else {}}


## Run an action, show the result in `status`, and refresh the whole screen.
static func act(node: Node, session, action: Dictionary, status: Label) -> Dictionary:
	var res: Dictionary = A.apply(session.world(), action)
	if status != null:
		status.text = "OK" if res.get("ok", false) else "✗ " + String(res.get("error", "failed"))
		status.modulate = Color(0.6, 1.0, 0.6) if res.get("ok", false) else Color(1.0, 0.6, 0.6)
	node.get_tree().call_group("pcs_refresh", "refresh_all")
	return res


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func label(parent: Node, text: String, size_px: int = 14, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.modulate = color
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label has no natural width: inside a row (HBoxContainer) it would be squeezed to zero and
	# print one letter per line. Give it room to grow and a sensible minimum.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	parent.add_child(l)
	return l


static func header(parent: Node, text: String) -> Label:
	var l := label(parent, text, 18, Color(0.85, 0.9, 1.0))
	return l


static func button(parent: Node, text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func hbox(parent: Node) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	return h


static func vbox(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


static func sep(parent: Node) -> void:
	parent.add_child(HSeparator.new())


## A scrollable body inside a panel; returns the VBox to fill.
static func scroll_body(panel: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	return body


static func top_skills(skills: Dictionary, n: int = 3) -> String:
	var keys: Array = skills.keys()
	keys.sort_custom(func(a, b): return int(skills[a]) > int(skills[b]))
	return ", ".join(keys.slice(0, n).map(func(k): return "%s %d" % [k, int(skills[k])]))


static func status_label(parent: Node) -> Label:
	return label(parent, "", 13, Color(0.8, 0.8, 0.8))
