class_name ColonyMap
extends Control
## The colony map up close (M13 A5, planning/spec-areas-v1.md §7; Terra for Wilma). Hosted by MapView for the
## TERRAIN overlay. Draws the terrain grid, areas (outlined, coloured by kind, named), facility icons and district
## territories, and gives the player four tools in a side panel:
##   INSPECT  click an area, a facility or a tile: its panel (residents, capacity, income mix, district, history…)
##   BUILD    choose a free tile for public housing or a public building (the action is stubbed until Bob's A2
##            accepts a tile: see submit_build)
##   DISTRICTS  district territories and borders (law districts; before A2 the six economic districts)
##   DRAW     assemble a districting plan {name: [area ids]} by clicking areas, preview it live
##            (LQ.districting_preview: validity, balance, contiguity) and submit it as a bill
## Pure view: it mutates the game only through action entry points (EconActions, DistrictPolitics/law).
## Wheel zooms around the cursor, right or middle drag pans.

signal district_selected(district_id: String)   # an economic district (pre-A2 settlement) was clicked

const LQ := preload("res://sim/law/law_query.gd")
const DL := preload("res://sim/law/districting.gd")

const PANEL_W := 340.0
const KIND_COLORS := {"SETTLEMENT": Color("#e9c46a"), "CAMP": Color("#e07a5f"), "VILLAGE": Color("#9cc97a"),
	"ENCLAVE": Color("#c39be8"), "SHELTER": Color("#a8a8a8"), "SLUM": Color("#8d6e63")}
const KIND_NAMES := {"SETTLEMENT": "settlement", "CAMP": "company camp", "VILLAGE": "village", "ENCLAVE": "private enclave",
	"SHELTER": "shelter", "SLUM": "slum"}
## Facility icons: glyph, colour.
const FAC_STYLE := {"POWER": ["P", Color("#f4d03f")], "WATERWORKS": ["W", Color("#4fa3e0")], "DEPOT": ["D", Color("#b08968")],
	"ROAD": ["R", Color("#8d8d8d")], "HOUSING": ["H", Color("#f1e3c8")], "FARM": ["F", Color("#7cc06a")],
	"MINE": ["M", Color("#c97b43")], "PROCESSING": ["Pr", Color("#9aa5b1")], "COMPONENTS": ["C", Color("#7f9cb8")],
	"MEDWORKS": ["Md", Color("#f28fb1")], "CONSUMERF": ["G", Color("#e8a85c")], "SERVICEHUB": ["S", Color("#4fc1b0")],
	"CLINIC": ["+", Color("#ef5350")], "SCHOOL": ["Sc", Color("#a58ad8")], "ADMIN": ["A", Color("#f5f5f5")]}
const FAC_NAMES := {"POWER": "power plant", "WATERWORKS": "waterworks", "DEPOT": "depot", "ROAD": "road", "HOUSING": "housing block",
	"FARM": "farm", "MINE": "mine", "PROCESSING": "processing plant", "COMPONENTS": "component workshop", "MEDWORKS": "medical works",
	"CONSUMERF": "consumer goods factory", "SERVICEHUB": "service hub", "CLINIC": "clinic", "SCHOOL": "school", "ADMIN": "administration"}
const DISTRICT_COLORS := [Color("#5dade2"), Color("#f5b041"), Color("#58d68d"), Color("#ec7063"), Color("#af7ac5"),
	Color("#f4d03f"), Color("#48c9b0"), Color("#eb984e"), Color("#85929e"), Color("#f1948a"), Color("#7fb3d5"), Color("#c39bd3")]
## Where facilities may stand (display placement before A2, and build validity).
const FAC_TERRAIN := {"MINE": ["o", "x", "k", "h"], "FARM": ["f", "n", "."], "HOUSING": [".", "f", "L", "n"]}
const BUILD_TERRAIN := [".", "f", "L", "n", "h"]
## What the player can place: public housing and public buildings (EconActions.OPERATOR ∩ EconData.BUILD).
const BUILD_TYPES := ["HOUSING", "CLINIC", "SCHOOL", "POWER", "WATERWORKS", "DEPOT"]
## Display anchors for the six economic districts until areas and facility tiles exist (A2): what each one
## looks for on the terrain, how far from the landing site, in which direction.
const ECON_ANCHORS := {
	"d:2": {"want": [".", "f"], "near": "r", "dist": 9.0, "dir": Vector2(1, -0.4)},     # Riverside
	"d:3": {"want": ["h", "k", "o"], "near": "", "dist": 13.0, "dir": Vector2(-1, 0.6)},  # Redrock
	"d:4": {"want": [".", "h"], "near": "", "dist": 6.0, "dir": Vector2(-1, -0.2)},     # Foundry
	"d:5": {"want": ["h", "."], "near": "", "dist": 10.0, "dir": Vector2(0.6, 1)},      # Greenhill
	"d:6": {"want": ["f", "."], "near": "", "dist": 11.0, "dir": Vector2(-0.2, -1)},    # Northfield
}
const TERRITORY_REACH := 6   # tiles of open land a district's areas claim around them (display)

var session: GameSession
var mode := "INSPECT"        # INSPECT | BUILD | DISTRICTS | DRAW
var selected := {}           # {"kind": AREA|FACILITY|SETTLEMENT|TILE, "id": …, "tile": Vector2i}
var build_type := "HOUSING"
var build_tile := Vector2i(-1, -1)
var plan := {}               # DRAW: district name -> [area ids]
var draw_group := ""
var last_message := ""

var _zoom := 1.0
var _pan := Vector2.ZERO
var _dragging := false
var _user_view := false      # the player zoomed or panned: stop framing the landing site automatically
const FRAME_TILE_PX := 18.0  # opening view: zoom in on the landing site until tiles are this big
var _hover := Vector2i(-1, -1)
var _fac_tiles := {}         # fid -> Vector2i (A2 tile or display placement)
var _fac_at := {}            # "x,y" -> fid
var _anchors := {}           # econ district -> Vector2i (pre-A2 settlements)
var _territory: Array = []   # [y * W + x] -> district key or ""
var _dist_keys: Array = []   # district keys in colour order
var _dist_names := {}        # district key -> display name

var _info: RichTextLabel
var _mode_buttons := {}
var _build_box: HBoxContainer
var _build_pick: OptionButton
var _draw_box: VBoxContainer
var _draw_groups: HFlowContainer
var _draw_name: LineEdit
var _act_btn: Button
var _act2_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_W
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#20262c")
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Colony map"
	title.add_theme_font_size_override("font_size", 17)
	v.add_child(title)
	var modes := HFlowContainer.new()
	v.add_child(modes)
	var bg := ButtonGroup.new()
	for m in [["INSPECT", "Inspect"], ["BUILD", "Build"], ["DISTRICTS", "Districts"], ["DRAW", "Draw districts"]]:
		var b := Button.new()
		b.text = m[1]
		b.toggle_mode = true
		b.button_group = bg
		b.button_pressed = m[0] == mode
		var key: String = m[0]
		b.pressed.connect(func(): set_mode(key))
		modes.add_child(b)
		_mode_buttons[key] = b
	_build_box = HBoxContainer.new()
	v.add_child(_build_box)
	var bl := Label.new()
	bl.text = "Build:"
	_build_box.add_child(bl)
	_build_pick = OptionButton.new()
	for t in BUILD_TYPES:
		_build_pick.add_item(("Public housing" if t == "HOUSING" else String(FAC_NAMES[t]).capitalize()))
	_build_pick.item_selected.connect(func(i: int): build_type = BUILD_TYPES[i]; build_tile = Vector2i(-1, -1); _update_panel(); queue_redraw())
	_build_box.add_child(_build_pick)
	_draw_box = VBoxContainer.new()
	v.add_child(_draw_box)
	_draw_groups = HFlowContainer.new()
	_draw_box.add_child(_draw_groups)
	var dr := HBoxContainer.new()
	_draw_box.add_child(dr)
	_draw_name = LineEdit.new()
	_draw_name.placeholder_text = "district name"
	_draw_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draw_name.text_submitted.connect(func(t: String): rename_group(draw_group, t))
	dr.add_child(_draw_name)
	_small_button(dr, "Rename", func(): rename_group(draw_group, _draw_name.text))
	var dr2 := HBoxContainer.new()
	_draw_box.add_child(dr2)
	_small_button(dr2, "+ New district", func(): new_group())
	_small_button(dr2, "Reset to current map", func(): start_drawing())
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.scroll_active = true
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 13)
	_info.add_theme_font_size_override("italics_font_size", 13)
	v.add_child(_info)
	var acts := HBoxContainer.new()
	v.add_child(acts)
	_act_btn = Button.new()
	_act_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act_btn.pressed.connect(_on_action)
	acts.add_child(_act_btn)
	_act2_btn = Button.new()
	_act2_btn.pressed.connect(func(): selected = {}; build_tile = Vector2i(-1, -1); last_message = ""; _update_panel(); queue_redraw())
	_act2_btn.text = "Clear"
	acts.add_child(_act2_btn)
	_update_panel()


func _small_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _world() -> WorldState:
	return session.world() if session != null else null


func refresh() -> void:
	var w := _world()
	if w == null or not Terrain.ready(w):
		return
	_anchors = econ_anchors(w)
	_fac_tiles = facility_tiles(w, _anchors)
	_fac_at.clear()
	for fid in _fac_tiles:
		_fac_at[Terrain.key(_fac_tiles[fid].x, _fac_tiles[fid].y)] = fid
	if mode == "DRAW" and plan.is_empty():
		start_drawing()
	_build_territory(w)
	_frame_landing()
	_update_panel()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_frame_landing()


## Opening view: centred on the landing site, zoomed so tiles are readable (until the player moves the view).
func _frame_landing() -> void:
	var w := _world()
	if _user_view or w == null or not Terrain.ready(w) or size.x <= PANEL_W + 40.0:
		return
	var r := _map_rect()
	var base := minf(r.size.x / Terrain.W, r.size.y / Terrain.H)
	_zoom = clampf(FRAME_TILE_PX / maxf(1.0, base), 1.0, 6.0)
	_pan = Vector2.ZERO
	if _zoom > 1.0:
		var t := _tile_px()
		var l := Vector2(Terrain.landing(w)) + Vector2(0.5, 0.5)
		_pan = r.get_center() - r.position - (r.size - Vector2(Terrain.W, Terrain.H) * t) * 0.5 - l * t
	queue_redraw()


func set_mode(m: String) -> void:
	mode = m
	last_message = ""
	build_tile = Vector2i(-1, -1)
	if m == "DRAW":
		start_drawing()
	if _mode_buttons.has(m) and not _mode_buttons[m].button_pressed:
		_mode_buttons[m].set_pressed_no_signal(true)
	refresh()


# ======================================================================= display layout (static, pure reads)

## Settlements of the six economic districts (display, until areas exist): d:1 at the landing site, the others
## on suitable terrain around it. Deterministic in the terrain.
static func econ_anchors(w: WorldState) -> Dictionary:
	var l := Terrain.landing(w)
	var out := {"d:1": l}
	for d in ECON_ANCHORS:
		var spec: Dictionary = ECON_ANCHORS[d]
		var dir: Vector2 = Vector2(spec["dir"]).normalized()
		var best := l
		var bs := INF
		for y in Terrain.H:
			for x in Terrain.W:
				if not (Terrain.at(w, x, y) in spec["want"]):
					continue
				var off := Vector2(x - l.x, y - l.y)
				var s := absf(off.length() - float(spec["dist"])) + 6.0 * (1.0 - off.normalized().dot(dir))
				if String(spec["near"]) != "" and not _near_code(w, Vector2i(x, y), String(spec["near"]), 2):
					s += 8.0
				for o in out.values():
					if Vector2(x - o.x, y - o.y).length() < 5.0:
						s += 20.0
				if s < bs:
					bs = s
					best = Vector2i(x, y)
		out[d] = best
	return out


static func _near_code(w: WorldState, t: Vector2i, code: String, r: int) -> bool:
	for yy in range(t.y - r, t.y + r + 1):
		for xx in range(t.x - r, t.x + r + 1):
			if Terrain.at(w, xx, yy) == code:
				return true
	return false


## Where each facility is drawn: its own tile once Bob's A2 gives facilities one (f["tile"]), otherwise a free
## tile of suitable terrain nearest its area or its district's settlement (display only, deterministic).
static func facility_tiles(w: WorldState, anchors: Dictionary = {}) -> Dictionary:
	if anchors.is_empty():
		anchors = econ_anchors(w)
	var out := {}
	var taken := {}
	for k in w.peek("map").get("uses", {}):
		taken[k] = true
	var fac: Dictionary = w.peek("facility")
	var ids: Array = EconUtil.sorted_keys(fac)
	for fid in ids:   # facilities that already stand on a tile
		var tv = fac[fid].get("tile", null)
		if tv != null:
			var t := _as_tile(tv)
			out[fid] = t
			taken[Terrain.key(t.x, t.y)] = true
	for k in anchors:
		taken[Terrain.key(anchors[k].x, anchors[k].y)] = true
	for fid in ids:
		if out.has(fid):
			continue
		var f: Dictionary = fac[fid]
		var a: Vector2i = anchors.get(String(f.get("district", "")), Terrain.landing(w))
		if f.has("area") and not AreaStore.get_area(w, String(f["area"])).is_empty():
			var c := AreaStore.centroid(w, String(f["area"]))
			a = Vector2i(roundi(c.x), roundi(c.y))
		var codes: Array = FAC_TERRAIN.get(String(f["type"]), BUILD_TERRAIN)
		var t := _nearest_untaken(w, a, codes, taken, 40)
		if t.x < 0:
			t = _nearest_untaken(w, a, BUILD_TERRAIN + ["k", "o", "x"], taken, 40)
		if t.x >= 0:
			out[fid] = t
			taken[Terrain.key(t.x, t.y)] = true
	return out


static func _as_tile(v) -> Vector2i:
	if v is Vector2i:
		return v
	if v is String:
		return Vector2i(int(String(v).get_slice(",", 0)), int(String(v).get_slice(",", 1)))
	if v is Array:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(-1, -1)


## Nearest tile to `a` (ring by ring, rows then columns: deterministic) of one of `codes` that is not taken.
static func _nearest_untaken(w: WorldState, a: Vector2i, codes: Array, taken: Dictionary, reach: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for yy in range(maxi(0, a.y - reach), mini(Terrain.H, a.y + reach + 1)):
		for xx in range(maxi(0, a.x - reach), mini(Terrain.W, a.x + reach + 1)):
			if taken.has(Terrain.key(xx, yy)) or not (Terrain.at(w, xx, yy) in codes):
				continue
			var d := Vector2(xx - a.x, yy - a.y).length()
			if d < bd:
				bd = d
				best = Vector2i(xx, yy)
	return best


## Law districts from areas once they exist; before that the economic districts (settlements and facilities).
func _build_territory(w: WorldState) -> void:
	_territory.clear()
	_territory.resize(Terrain.W * Terrain.H)
	_territory.fill("")
	_dist_keys.clear()
	_dist_names.clear()
	var seeds := {}   # "x,y" -> key
	if mode == "DRAW" and not plan.is_empty():
		var names: Array = plan.keys()
		names.sort()
		for n in names:
			_dist_keys.append(n)
			_dist_names[n] = n
			for a in plan[n]:
				for t in AreaStore.tiles_of(w, String(a)):
					seeds[Terrain.key(t.x, t.y)] = n
	elif not AreaStore.areas(w).is_empty():
		for d in LQ.districts(w):
			_dist_keys.append(d["id"])
			_dist_names[d["id"]] = d["name"]
		for a in AreaStore.areas(w):
			var dk := String(a["district"])
			if dk == "":
				continue
			if not _dist_names.has(dk):
				_dist_keys.append(dk)
				_dist_names[dk] = DL.district_name(w, dk) if DL.district_name(w, dk) != "" else "The Colony"
			for t in AreaStore.tiles_of(w, a["id"]):
				seeds[Terrain.key(t.x, t.y)] = dk
	else:
		var ids: Array = _anchors.keys()
		ids.sort()
		for d in ids:
			_dist_keys.append(d)
			_dist_names[d] = String(EconData.DISTRICTS.get(d, {}).get("name", d))
			seeds[Terrain.key(_anchors[d].x, _anchors[d].y)] = d
		for fid in _fac_tiles:
			var dk := String(w.peek("facility")[fid].get("district", ""))
			if _dist_names.has(dk):
				seeds[Terrain.key(_fac_tiles[fid].x, _fac_tiles[fid].y)] = dk
	# multi-source breadth-first growth, TERRITORY_REACH steps; ties go to the first key in sorted seed order
	var frontier: Array = []
	var keys: Array = seeds.keys()
	keys.sort()
	for k in keys:
		var t := _as_tile(k)
		_territory[t.y * Terrain.W + t.x] = seeds[k]
		frontier.append(t)
	for _step in TERRITORY_REACH:
		var nxt: Array = []
		for t in frontier:
			var dk: String = _territory[t.y * Terrain.W + t.x]
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = t + d
				if n.x < 0 or n.y < 0 or n.x >= Terrain.W or n.y >= Terrain.H or _territory[n.y * Terrain.W + n.x] != "":
					continue
				_territory[n.y * Terrain.W + n.x] = dk
				nxt.append(n)
		frontier = nxt


func _district_color(k: String) -> Color:
	var i := _dist_keys.find(k)
	return DISTRICT_COLORS[i % DISTRICT_COLORS.size()] if i >= 0 else Color(0.6, 0.6, 0.6)


# ======================================================================= geometry

func _map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(10.0, size.x - PANEL_W), size.y))


func _tile_px() -> float:
	var r := _map_rect()
	return minf(r.size.x / Terrain.W, r.size.y / Terrain.H) * _zoom


func _origin() -> Vector2:
	var r := _map_rect()
	var t := _tile_px()
	return r.position + (r.size - Vector2(Terrain.W, Terrain.H) * t) * 0.5 + _pan


func _tile_rect(x: int, y: int) -> Rect2:
	var t := _tile_px()
	return Rect2(_origin() + Vector2(x, y) * t, Vector2(t, t))


func _tile_center(t: Vector2i) -> Vector2:
	return _origin() + (Vector2(t) + Vector2(0.5, 0.5)) * _tile_px()


func _to_tile(p: Vector2) -> Vector2i:
	var q := (p - _origin()) / _tile_px()
	return Vector2i(floori(q.x), floori(q.y))


func _in_map(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < Terrain.W and t.y < Terrain.H


# ======================================================================= drawing

func _draw() -> void:
	var w := _world()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#161a1e"))
	if w == null or not Terrain.ready(w):
		return
	var t := _tile_px()
	var gap := 1.0 if t >= 7.0 else 0.0
	var show_dist := mode in ["DISTRICTS", "DRAW"]
	var rows: Array = w.peek("map")["grid"]["rows"]
	for y in Terrain.H:
		var row: String = rows[y]
		for x in Terrain.W:
			var code := row.substr(x, 1)
			var c: Color = MapView.TERRAIN_COLORS.get(code, Color.GRAY)
			c = c.darkened(float((x * 31 + y * 17) % 5) * 0.02)
			var use := Terrain.use_at(w, x, y)
			var area := String(use.get("area", ""))
			if area != "":
				var kind := String(AreaStore.get_area(w, area).get("kind", "SETTLEMENT"))
				c = c.lerp(KIND_COLORS.get(kind, Color.WHITE), 0.75)
			if show_dist:
				var dk: String = _territory[y * Terrain.W + x]
				if dk != "":
					c = c.lerp(_district_color(dk), 0.55 if area != "" else 0.3)
				else:
					c = c.darkened(0.35)
			draw_rect(Rect2(_tile_rect(x, y).position, Vector2(t - gap, t - gap)), c)
	_draw_area_outlines(w, t)
	if show_dist:
		_draw_district_borders(t)
	_draw_facilities(w, t)
	if not show_dist:
		_draw_sites(w, t)
	_draw_labels(w, t)
	_draw_cursor(w, t)
	if mode == "DISTRICTS" or mode == "DRAW":
		_draw_legend()


## Outline each area along edges where the neighbour is not the same area; selected area in white.
func _draw_area_outlines(w: WorldState, t: float) -> void:
	var sel_area := String(selected.get("id", "")) if selected.get("kind", "") == "AREA" else ""
	for a in AreaStore.areas(w):
		var id := String(a["id"])
		var col: Color = KIND_COLORS.get(String(a["kind"]), Color.WHITE).darkened(0.45)
		var width := maxf(1.5, t * 0.12)
		if id == sel_area:
			col = Color.WHITE
			width = maxf(2.5, t * 0.2)
		for tv in AreaStore.tiles_of(w, id):
			var r := _tile_rect(tv.x, tv.y)
			if AreaStore.area_of(w, tv + Vector2i(0, -1)) != id:
				draw_line(r.position, r.position + Vector2(t, 0), col, width)
			if AreaStore.area_of(w, tv + Vector2i(0, 1)) != id:
				draw_line(r.position + Vector2(0, t), r.end, col, width)
			if AreaStore.area_of(w, tv + Vector2i(-1, 0)) != id:
				draw_line(r.position, r.position + Vector2(0, t), col, width)
			if AreaStore.area_of(w, tv + Vector2i(1, 0)) != id:
				draw_line(r.position + Vector2(t, 0), r.end, col, width)


## Borders between district territories (thick, light).
func _draw_district_borders(t: float) -> void:
	var col := Color(1, 1, 1, 0.85)
	var width := maxf(2.0, t * 0.18)
	for y in Terrain.H:
		for x in Terrain.W:
			var k: String = _territory[y * Terrain.W + x]
			if k == "":
				continue
			var r := _tile_rect(x, y)
			if x + 1 < Terrain.W and _territory[y * Terrain.W + x + 1] != "" and _territory[y * Terrain.W + x + 1] != k:
				draw_line(r.position + Vector2(t, 0), r.end, col, width)
			if y + 1 < Terrain.H and _territory[(y + 1) * Terrain.W + x] != "" and _territory[(y + 1) * Terrain.W + x] != k:
				draw_line(r.position + Vector2(0, t), r.end, col, width)


func _draw_facilities(w: WorldState, t: float) -> void:
	var font := get_theme_default_font()
	var fac: Dictionary = w.peek("facility")
	var sel_fac := String(selected.get("id", "")) if selected.get("kind", "") == "FACILITY" else ""
	for fid in _fac_tiles:
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty():
			continue
		var st: Array = FAC_STYLE.get(String(f["type"]), [String(f["type"]).substr(0, 1), Color.WHITE])
		var p := _tile_center(_fac_tiles[fid])
		var r := maxf(2.5, t * 0.42)
		var col: Color = st[1]
		if f.get("mothball", false) or int(f.get("closed_m", 0)) > 0:
			col = col.darkened(0.5)
		draw_circle(p, r + 1.0, Color(0.05, 0.05, 0.05, 0.9))
		draw_circle(p, r, col)
		if fid == sel_fac:
			draw_arc(p, r + 3.0, 0.0, TAU, 24, Color.WHITE, 2.0)
		if t >= 13.0:
			var fs := int(clampf(t * 0.5, 8.0, 18.0))
			var g: String = st[0]
			var gw := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, p + Vector2(-gw * 0.5, fs * 0.36), g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.08))


## Tourist sites on the colony map (A42, PlanetSites; the landing site has its own flag label).
func _draw_sites(w: WorldState, t: float) -> void:
	var font := get_theme_default_font()
	var fs := int(clampf(t * 0.7, 9.0, 15.0))
	for s in PlanetSites.sites(w):
		if s["where"] != "COLONY" or s["kind"] == "FIRST_LANDING":
			continue
		var col: Color = PlanetView.SITE_COLORS.get(s["kind"], Color.WHITE)
		var p := _tile_center(s["tile"])
		var r := maxf(3.0, t * 0.38)
		var pts := PackedVector2Array()
		for k in 10:   # a five-pointed star
			var rr := r if k % 2 == 0 else r * 0.45
			var a := -PI / 2.0 + float(k) * PI / 5.0
			pts.append(p + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.8), 1.0)
		if t >= 9.0:
			_label(font, p + Vector2(0, t * 0.9 + fs * 0.5), String(s["name"]), fs, col.lerp(Color.WHITE, 0.5))


func _label(font: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos - Vector2(tw * 0.5, 0)
	for o in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		draw_string(font, p + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_labels(w: WorldState, t: float) -> void:
	var font := get_theme_default_font()
	var fs := int(clampf(t * 0.95, 11.0, 18.0))
	var areas := AreaStore.areas(w)
	if mode in ["DISTRICTS", "DRAW"]:
		# district names at the mean of their territory
		var acc := {}
		for y in Terrain.H:
			for x in Terrain.W:
				var k: String = _territory[y * Terrain.W + x]
				if k != "":
					var a: Array = acc.get(k, [Vector2.ZERO, 0])
					acc[k] = [a[0] + Vector2(x, y), a[1] + 1]
		for k in acc:
			var c: Vector2 = acc[k][0] / float(acc[k][1])
			_label(font, _origin() + (c + Vector2(0.5, 0.5)) * t, String(_dist_names.get(k, k)).to_upper(), fs + 2, Color.WHITE)
		return
	for a in areas:
		var c := AreaStore.centroid(w, a["id"])
		_label(font, _origin() + (c + Vector2(0.5, -0.3)) * t, String(a["name"]), fs, Color.WHITE)
	if areas.is_empty():
		for d in _anchors:
			var nm := String(EconData.DISTRICTS.get(d, {}).get("name", d))
			_label(font, _tile_center(_anchors[d]) + Vector2(0, -t * 0.9), nm, fs, Color("#fff3b0"))
			draw_circle(_tile_center(_anchors[d]), maxf(3.0, t * 0.3), Color("#fff3b0"))
	var l := Terrain.landing(w)
	if areas.is_empty() or AreaStore.area_of(w, l) == "":
		_label(font, _tile_center(l) + Vector2(0, t * 1.6), "⚑ landing site", maxi(10, fs - 2), Color("#fff3b0"))


func _draw_cursor(w: WorldState, t: float) -> void:
	if mode == "BUILD":
		if _in_map(_hover):
			var why := build_problem(w, build_type, _hover, _fac_at)
			draw_rect(_tile_rect(_hover.x, _hover.y), Color(0.3, 1.0, 0.4, 0.45) if why == "" else Color(1.0, 0.3, 0.3, 0.45))
		if _in_map(build_tile):
			draw_rect(_tile_rect(build_tile.x, build_tile.y), Color("#fff3b0"), false, maxf(2.0, t * 0.2))
		return
	if _in_map(_hover):
		draw_rect(_tile_rect(_hover.x, _hover.y), Color(1, 1, 1, 0.8), false, 1.5)
	if selected.get("kind", "") == "TILE":
		var s: Vector2i = selected["tile"]
		draw_rect(_tile_rect(s.x, s.y), Color("#fff3b0"), false, 2.0)


func _draw_legend() -> void:
	var font := get_theme_default_font()
	var y := 10.0
	var wmax := 0.0
	for k in _dist_keys:
		wmax = maxf(wmax, font.get_string_size(String(_dist_names.get(k, k)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
	draw_rect(Rect2(4, 4, wmax + 36, _dist_keys.size() * 18.0 + 10), Color(0.08, 0.09, 0.1, 0.85))
	for k in _dist_keys:
		draw_rect(Rect2(10, y, 14, 14), _district_color(k))
		draw_string(font, Vector2(30, y + 12), String(_dist_names.get(k, k)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		y += 18.0


# ======================================================================= input

func _gui_input(event: InputEvent) -> void:
	var w := _world()
	if w == null or not Terrain.ready(w):
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and _map_rect().has_point(mb.position):
			click_tile(_to_tile(mb.position))
			accept_event()
			return
	if event is InputEventMouseButton:
		var mb2 := event as InputEventMouseButton
		if mb2.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb2.pressed
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_user_view = true
			_pan += mm.relative
			queue_redraw()
			return
		var t := _to_tile(mm.position)
		if not _map_rect().has_point(mm.position):
			t = Vector2i(-1, -1)
		if t != _hover:
			_hover = t
			tooltip_text = hover_text(w, t) if _in_map(t) else ""
			queue_redraw()


func _zoom_at(p: Vector2, f: float) -> void:
	_user_view = true
	var nz := clampf(_zoom * f, 1.0, 6.0)
	var before := (p - _origin()) / _tile_px()
	_zoom = nz
	if is_equal_approx(_zoom, 1.0):
		_pan = Vector2.ZERO
	else:
		_pan += p - (_origin() + before * _tile_px())
	queue_redraw()


func hover_text(w: WorldState, t: Vector2i) -> String:
	var s := String(Terrain.NAMES.get(Terrain.at(w, t.x, t.y), "?")).capitalize()
	var area := AreaStore.area_of(w, t)
	if area != "":
		s += " · " + String(AreaStore.get_area(w, area)["name"])
	var fid := String(_fac_at.get(Terrain.key(t.x, t.y), ""))
	if fid != "":
		s += " · " + String(FAC_NAMES.get(String(w.peek("facility")[fid]["type"]), "facility"))
	if mode == "BUILD":
		var why := build_problem(w, build_type, t, _fac_at)
		s += "\n" + ("Free: click to place here" if why == "" else why)
	return s


## A click on a tile, by mode (public so the smoke test and shot tool can drive it).
func click_tile(t: Vector2i) -> void:
	var w := _world()
	if not _in_map(t):
		return
	last_message = ""
	match mode:
		"BUILD":
			build_tile = t
		"DRAW":
			var a := AreaStore.area_of(w, t)
			if a != "" and draw_group != "":
				assign_area(a, draw_group)
			elif a != "":
				selected = {"kind": "AREA", "id": a, "tile": t}
		_:
			selected = _pick(w, t)
			if selected.get("kind", "") == "SETTLEMENT":
				district_selected.emit(String(selected["id"]))
	if mode == "DRAW":
		_build_territory(w)
	_update_panel()
	queue_redraw()


func _pick(w: WorldState, t: Vector2i) -> Dictionary:
	var fid := String(_fac_at.get(Terrain.key(t.x, t.y), ""))
	if fid != "":
		return {"kind": "FACILITY", "id": fid, "tile": t}
	var a := AreaStore.area_of(w, t)
	if a != "":
		return {"kind": "AREA", "id": a, "tile": t}
	for d in _anchors:
		if Vector2(_anchors[d] - t).length() <= 1.5 and AreaStore.areas(w).is_empty():
			return {"kind": "SETTLEMENT", "id": d, "tile": t}
	return {"kind": "TILE", "id": "", "tile": t}


# ======================================================================= build placement

## Why `type` cannot be built on tile `t`, or "" if it can (terrain, free tile, land title). Pure read.
static func build_problem(w: WorldState, type: String, t: Vector2i, fac_at: Dictionary = {}) -> String:
	var code := Terrain.at(w, t.x, t.y)
	if code == "":
		return "Outside the map"
	if not Terrain.use_at(w, t.x, t.y).is_empty():
		return "Taken: %s" % ("part of " + String(AreaStore.get_area(w, AreaStore.area_of(w, t)).get("name", "an area")) if AreaStore.area_of(w, t) != "" else "already in use")
	if fac_at.has(Terrain.key(t.x, t.y)):
		return "Taken by a facility"
	var allowed: Array = FAC_TERRAIN.get(type, BUILD_TERRAIN) if type == "HOUSING" else BUILD_TERRAIN
	if not code in allowed:
		return "Cannot build %s on %s" % [String(FAC_NAMES.get(type, type)), String(Terrain.NAMES.get(code, code))]
	var title: Dictionary = LQ.land_title(w, t)
	if not title.is_empty() and String(title.get("owner", "gov")) != "gov":
		return "The land is privately owned (%s)" % String(title.get("owner", ""))
	return ""


## The economic district a tile belongs to for today's EconActions (nearest settlement), until A2 keys by tile.
static func econ_district_near(w: WorldState, t: Vector2i, anchors: Dictionary = {}) -> String:
	if anchors.is_empty():
		anchors = econ_anchors(w)
	var best := "d:1"
	var bd := INF
	var ids: Array = anchors.keys()
	ids.sort()
	for d in ids:
		var dd := Vector2(anchors[d] - t).length()
		if dd < bd:
			bd = dd
			best = d
	return best


## Params for ECON_COMMISSION_PROJECT at a tile.
static func build_params(w: WorldState, type: String, t: Vector2i, anchors: Dictionary = {}) -> Dictionary:
	return {"type": type, "district": econ_district_near(w, t, anchors), "tile": [t.x, t.y]}


## TILE_BUILD_LIVE: flip to true when Bob's A2 makes ECON_COMMISSION_PROJECT honour params.tile.
const TILE_BUILD_LIVE := false


## Commission a public project on a tile. STUB until A2: checks the budget with EconActions.check but queues
## nothing, so no project is built in the wrong place. Returns {ok, message}.
static func submit_build(w: WorldState, type: String, t: Vector2i, anchors: Dictionary = {}) -> Dictionary:
	var params := build_params(w, type, t, anchors)
	var chk: Dictionary = EconActions.check(w, "ECON_COMMISSION_PROJECT", params)
	if not chk["ok"]:
		return {"ok": false, "message": String(chk["error"])}
	if not TILE_BUILD_LIVE:
		return {"ok": false, "message": "Placement is ready, but building on a chosen tile goes live with the economy's tile update (A2). Nothing was commissioned."}
	var r: Dictionary = EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", params)
	return {"ok": r["ok"], "message": "Commissioned: the tender opens next month." if r["ok"] else String(r["error"])}


# ======================================================================= district drawing

## Start from the map in force.
func start_drawing() -> void:
	var w := _world()
	plan = {}
	draw_group = ""
	if w == null or AreaStore.areas(w).is_empty():
		return
	plan = DistrictPolitics.current_plan(w)
	var names: Array = plan.keys()
	names.sort()
	draw_group = names[0] if not names.is_empty() else ""


func new_group() -> void:
	var i := plan.size() + 1
	while plan.has("District %d" % i):
		i += 1
	draw_group = "District %d" % i
	plan[draw_group] = []
	_build_territory(_world())
	_update_panel()
	queue_redraw()


func rename_group(old: String, to: String) -> void:
	to = to.strip_edges()
	if old == "" or to == "" or to == old or plan.has(to) or not plan.has(old):
		return
	plan[to] = plan[old]
	plan.erase(old)
	draw_group = to
	_build_territory(_world())
	_update_panel()
	queue_redraw()


## Move an area into a group of the draft plan (empty groups are kept until submit, so you can fill them).
func assign_area(area_id: String, group: String) -> void:
	for n in plan:
		plan[n].erase(area_id)
	if not plan.has(group):
		plan[group] = []
	plan[group].append(area_id)


## The draft without empty districts, as the law expects.
func clean_plan() -> Dictionary:
	var out := {}
	for n in plan:
		if not plan[n].is_empty():
			out[n] = plan[n].duplicate()
	return out


## Submit the draft as a districting bill. For now DistrictPolitics.vote_and_enact (Wilma will give the call).
func submit_plan() -> Dictionary:
	var w := _world()
	var st := session.pol_state()
	if st.get("government", {}).is_empty():
		return {"ok": false, "message": "There is no parliamentary government to vote on a districting bill yet."}
	var p := clean_plan()
	var pv: Dictionary = LQ.districting_preview(w, p, "LAW")
	if not pv["ok"]:
		return {"ok": false, "message": "The map is not valid: " + "; ".join(pv["errors"] + ([pv["reason"]] if not pv["allowed_now"] else []))}
	var r: Dictionary = DistrictPolitics.vote_and_enact(w, st, p, DistrictPolitics.current_plan(w), "PLAYER")
	var msg := "Parliament %s the districting bill, %d–%d." % ["passed" if r["passed"] else "rejected", r["yes"], r["no"]]
	if r["passed"]:
		msg += " It takes effect after the transition." if r["enacted"] else " The law rejected it."
	return {"ok": bool(r["passed"]) and bool(r["enacted"]), "message": msg}


# ======================================================================= side panel

func _on_action() -> void:
	var w := _world()
	if w == null:
		return
	match mode:
		"BUILD":
			if _in_map(build_tile):
				last_message = String(submit_build(w, build_type, build_tile, _anchors)["message"])
		"DRAW":
			last_message = String(submit_plan()["message"])
			if is_inside_tree():
				get_tree().call_group("pcs_refresh", "refresh_all")
	_update_panel()


func _update_panel() -> void:
	if _info == null:
		return
	_build_box.visible = mode == "BUILD"
	_draw_box.visible = mode == "DRAW" and not plan.is_empty()
	_act_btn.visible = mode in ["BUILD", "DRAW"]
	var w := _world()
	if w == null or not Terrain.ready(w):
		_info.text = "No colony map yet."
		return
	var t := ""
	match mode:
		"BUILD":
			t = _build_text(w)
		"DISTRICTS":
			t = _districts_text(w)
		"DRAW":
			t = _draw_text(w)
		_:
			t = _inspect_text(w)
	if last_message != "":
		t = "[color=#ffcc66]%s[/color]\n\n" % last_message + t
	_info.text = t
	if mode == "DRAW":
		_refresh_draw_controls()


func _inspect_text(w: WorldState) -> String:
	match String(selected.get("kind", "")):
		"AREA":
			return area_text(w, String(selected["id"]))
		"FACILITY":
			return facility_text(w, String(selected["id"]))
		"SETTLEMENT":
			return settlement_text(w, String(selected["id"]))
		"TILE":
			return tile_text(w, selected["tile"])
	var n := AreaStore.areas(w).size()
	var t := "[b]%d area%s, %d facilities[/b]\n" % [n, "" if n == 1 else "s", _fac_tiles.size()]
	t += "Click an area, a facility or a tile.\nWheel zooms (out to the whole map), right-drag pans.\n\n"
	t += "[b]Areas by kind[/b]\n"
	for k in KIND_COLORS:
		t += "[color=#%s]■[/color] %s\n" % [KIND_COLORS[k].to_html(false), String(KIND_NAMES[k]).capitalize()]
	if n == 0:
		t += "\n[i]Housing is still counted per economic district (before the economy's area update, A2): the six settlements are shown at their districts.[/i]\n"
	return t


## The area panel (PD §23.1): residents, capacity, income mix, work, opinion, district, history.
func area_text(w: WorldState, id: String) -> String:
	var a := AreaStore.get_area(w, id)
	if a.is_empty():
		return "Unknown area."
	var kind := String(a["kind"])
	var t := "[b][color=#%s]■[/color] %s[/b]\n%s" % [KIND_COLORS.get(kind, Color.WHITE).to_html(false), a["name"], String(KIND_NAMES.get(kind, kind)).capitalize()]
	var dn := DL.district_name(w, String(a["district"]))
	t += " · district [b]%s[/b]\n" % (dn if dn != "" else "none yet")
	t += "Founded %s" % _month_text(int(a["founded"]))
	if not a["parents"].is_empty():
		t += ", split from %s" % ", ".join(a["parents"].map(func(p): return String(AreaStore.get_area(w, String(p)).get("name", p))))
	t += "\n"
	if a.get("status", "ACTIVE") != "ACTIVE":
		t += "[i]%s; now part of %s[/i]\n" % [String(a["status"]).capitalize(), ", ".join(a.get("children", []).map(func(p): return String(AreaStore.get_area(w, String(p)).get("name", p))))]
	var res := AreaStore.residents(w, id)
	var cap := AreaStore.capacity(w, id)
	t += "\n[b]Housing[/b]\nResidents %d, homes for %d (%s)\n" % [res, cap, ("%d%% full" % roundi(100.0 * res / cap)) if cap > 0 else "no housing"]
	var by := {}
	for tv in AreaStore.tiles_of(w, id):
		var u := Terrain.use_at(w, tv.x, tv.y)
		by[String(u.get("by", "GOV"))] = int(by.get(String(u.get("by", "GOV")), 0)) + int(u.get("units", 0))
	var parts: Array = []
	for k in ["GOV", "COMPANY", "PRIVATE"]:
		if int(by.get(k, 0)) > 0:
			parts.append("%s %d" % [{"GOV": "public", "COMPANY": "company", "PRIVATE": "private"}[k], by[k]])
	t += "%d tiles%s\n" % [a["tiles"].size(), (": " + ", ".join(parts)) if not parts.is_empty() else ""]
	t += _people_text(w, id)
	var facs := {}
	for fid in _fac_tiles:
		if AreaStore.area_of(w, _fac_tiles[fid]) == id or AreaStore.adjacent_area(w, _fac_tiles[fid]) == id:
			var fn := String(FAC_NAMES.get(String(w.peek("facility")[fid]["type"]), "facility"))
			facs[fn] = int(facs.get(fn, 0)) + 1
	if not facs.is_empty():
		var names: Array = facs.keys()
		names.sort()
		t += "\n[b]Next door[/b]\n%s\n" % ", ".join(names.map(func(n): return n if facs[n] == 1 else "%d %ss" % [facs[n], n]))
	return t


## Income mix, work and opinion of the people keyed under `hb` (an area id, or hb:d:N before A2).
func _people_text(w: WorldState, hb: String) -> String:
	var inc := PopQuery.blocks(w, "INCOME", hb)
	var total := 0
	for k in inc:
		total += int(inc[k])
	if total == 0:
		return "\n[i]Nobody lives here yet.[/i]\n"
	var t := "\n[b]Income mix[/b]\n"
	for band in ["I1", "I2", "I3", "I4", "I5"]:
		var n := int(inc.get(hb + "|" + band, 0))
		var pct := 100.0 * n / total
		t += "%s [color=#8fbf5f]%s[/color] %d%%\n" % [band, "█".repeat(roundi(pct / 5.0)), roundi(pct)]
	var work := PopQuery.blocks(w, "WORK", hb)
	var by_status := {}
	var by_occ := {}
	for k in work:
		var s := String(k).split("|")
		by_status[s[3]] = int(by_status.get(s[3], 0)) + int(work[k])
		if s[3] == "EMPLOYED":
			by_occ[s[2]] = int(by_occ.get(s[2], 0)) + int(work[k])
	var emp := int(by_status.get("EMPLOYED", 0))
	var unemp := int(by_status.get("UNEMPLOYED", 0))
	t += "\n[b]Work[/b]\nEmployed %d, unemployed %d (%.0f%%)\n" % [emp, unemp, 100.0 * unemp / maxf(1.0, emp + unemp)]
	var occs: Array = by_occ.keys()
	occs.sort_custom(func(x, y): return by_occ[x] > by_occ[y] or (by_occ[x] == by_occ[y] and String(x) < String(y)))
	t += ", ".join(occs.slice(0, 4).map(func(o): return "%s %d" % [String(o).capitalize(), by_occ[o]])) + "\n"
	# opinion: voter leaves of this area
	var pop := 0.0
	var appr := 0.0
	var shares := {}
	for l in PolVoters.all(w):
		if String(l.get("hb", "")) != hb:
			continue
		var p := float(l.get("pop", 0))
		pop += p
		appr += float(l.get("approval", 0)) / 1000.0 * p
		var ps: Dictionary = l.get("prev_share", {})
		for pid in ps:
			shares[pid] = float(shares.get(pid, 0.0)) + float(ps[pid]) / 1000.0 * p
	if pop > 0.0:
		t += "\n[b]Opinion[/b] (%d voters)\nGovernment approval %.0f%%\n" % [roundi(pop), appr / pop]
		var pids: Array = shares.keys()
		pids.sort_custom(func(x, y): return shares[x] > shares[y] or (shares[x] == shares[y] and String(x) < String(y)))
		var lines: Array = []
		for pid in pids.slice(0, 3):
			var party: Dictionary = w.peek("party").get(pid, {})
			if party.is_empty():
				continue
			lines.append("[color=%s]■[/color] %s %.0f%%" % [party.get("color", "#cccccc"), party.get("name", pid), shares[pid] / pop])
		if not lines.is_empty():
			t += "Last vote: " + ", ".join(lines) + "\n"
	return t


func settlement_text(w: WorldState, d: String) -> String:
	var nm := String(EconData.DISTRICTS.get(d, {}).get("name", d))
	var t := "[b]%s[/b]\nSettlement of the %s district (shown at its district until the economy keys housing by area, A2)\n" % [nm, nm]
	var res := PopStore.count(w, {"hb": "hb:" + d})
	var cap := 0
	for fid in _fac_tiles:
		var f: Dictionary = w.peek("facility")[fid]
		if String(f["type"]) == "HOUSING" and String(f.get("district", "")) == d:
			cap += 1
	t += "\nResidents %d, %d housing block%s\n" % [res, cap, "" if cap == 1 else "s"]
	t += _people_text(w, "hb:" + d)
	return t


func facility_text(w: WorldState, fid: String) -> String:
	var f: Dictionary = w.peek("facility").get(fid, {})
	if f.is_empty():
		return "Unknown facility."
	var ty := String(f["type"])
	var org: Dictionary = w.peek("org").get(String(f.get("org", "")), {})
	var t := "[b]%s[/b] (%s)\nOwner: %s\n" % [String(FAC_NAMES.get(ty, ty)).capitalize(), fid, org.get("name", "?")]
	var d := String(f.get("district", ""))
	if d != "":
		t += "District: %s\n" % String(EconData.DISTRICTS.get(d, {}).get("name", d))
	if f.has("tile"):
		t += "Tile %s\n" % str(f["tile"])
	else:
		t += "[i]Shown near its district: facilities get their own tile with the economy's tile update (A2).[/i]\n"
	t += "\nUtilisation %.0f%%, condition %.0f%%" % [float(f.get("util", 0)) / 10.0, float(f.get("condition", 0)) / 1000.0]
	if int(f.get("tier", 0)) > 0:
		t += ", Mk %s" % ["I", "II", "III"][clampi(int(f["tier"]) - 1, 0, 2)]
	t += "\n"
	if f.get("mothball", false):
		t += "[color=#ef5350]Mothballed[/color]\n"
	if int(f.get("stop_until", 0)) > w.month:
		t += "[color=#ef5350]Stopped (%s) until %s[/color]\n" % [String(f.get("stop_kind", "")).to_lower(), _month_text(int(f["stop_until"]))]
	var ex: Dictionary = EconQuery.explain_facility(w, fid)
	for c in ex.get("causes", []).slice(0, 3):
		t += "• %s\n" % String(c.get("detail", c.get("cause", "")))
	return t


func tile_text(w: WorldState, tv: Vector2i) -> String:
	var code := Terrain.at(w, tv.x, tv.y)
	var t := "[b]%s[/b] at %d,%d\n" % [String(Terrain.NAMES.get(code, code)).capitalize(), tv.x, tv.y]
	var title: Dictionary = LQ.land_title(w, tv)
	if not title.is_empty():
		var owner := String(title.get("owner", "gov"))
		t += "Land: %s%s\n" % ["state land" if owner == "gov" else "owned by " + owner,
			(", leased to " + String(title["lessee"])) if String(title.get("lessee", "")) != "" else ""]
	var uses: Array = []
	if code in Terrain.BUILDABLE_HOUSING:
		uses.append("housing")
	if code in ["f", "r", "n"]:
		uses.append("farms")
	if code in ["o", "x", "h", "k"]:
		uses.append("mines" if code in ["o", "x"] else "quarries and hard building")
	if not uses.is_empty():
		t += "Good for: %s\n" % ", ".join(uses)
	for s in PlanetSites.sites(w):
		if s["where"] == "COLONY" and Vector2i(s["tile"]) == tv:
			t += "[color=#ffe08a]Sight: %s[/color] (%s), attraction %d, this month %d%% of an average month\n" % [
				s["name"], PlanetSites.KIND_NAMES[s["kind"]], int(s["attraction"]), PlanetSites.season_pct(w, s)]
	return t


func _build_text(w: WorldState) -> String:
	var name := "public housing" if build_type == "HOUSING" else String(FAC_NAMES.get(build_type, build_type))
	var t := "[b]Build %s[/b]\nChoose a free tile: green is buildable, red is not.\n" % name
	var est := EconConstruction.estimate(build_type) / EconUtil.S
	t += "Estimated cost %s, paid from %s\n" % [_money(est), String(EconActions.lines_for(build_type)[0]).trim_prefix("ECON_BUDGET_").replace("_", " ").to_lower()]
	_act_btn.disabled = true
	_act_btn.text = "Commission here"
	if not _in_map(build_tile):
		return t
	t += "\n[b]Tile %d,%d[/b]: %s\n" % [build_tile.x, build_tile.y, String(Terrain.NAMES.get(Terrain.at(w, build_tile.x, build_tile.y), "?"))]
	var why := build_problem(w, build_type, build_tile, _fac_at)
	if why != "":
		return t + "[color=#ef5350]%s[/color]\n" % why
	var near := AreaStore.adjacent_area(w, build_tile)
	if build_type == "HOUSING":
		t += ("Extends [b]%s[/b]\n" % AreaStore.get_area(w, near)["name"]) if near != "" else "Founds a new settlement here\n"
	var chk: Dictionary = EconActions.check(w, "ECON_COMMISSION_PROJECT", build_params(w, build_type, build_tile, _anchors))
	if not chk["ok"]:
		t += "[color=#ef5350]%s[/color]\n" % chk["error"]
	else:
		t += "[color=#8bc34a]The budget allows it.[/color]\n"
		_act_btn.disabled = false
	if not TILE_BUILD_LIVE:
		t += "[i]Building on a chosen tile goes live with the economy's tile update (A2).[/i]\n"
	return t


func _districts_text(w: WorldState) -> String:
	var ds := LQ.districts(w)
	if ds.is_empty():
		var t := "[b]Economic districts[/b]\n[i]No districts have been drawn by law yet: they come with areas (A2, A4). Shown: the six economic districts.[/i]\n\n"
		for d in _dist_keys:
			t += "[color=#%s]■[/color] %s: %d residents\n" % [_district_color(d).to_html(false), _dist_names[d], PopStore.count(w, {"hb": "hb:" + d})]
		return t
	var pv: Dictionary = DL.preview_current(w)
	var res := {}
	var total := 0
	for d in ds:
		var r := 0
		for a in d["areas"]:
			r += AreaStore.residents(w, String(a))
		res[d["id"]] = r
		total += r
	var mean := float(total) / float(maxi(1, ds.size()))
	var t := "[b]Districts in force[/b]\n"
	for d in ds:
		t += "[color=#%s]■[/color] [b]%s[/b]: %d area%s, %d residents (%+d%% of the mean)\n" % [_district_color(d["id"]).to_html(false), d["name"],
			d["areas"].size(), "" if d["areas"].size() == 1 else "s", res[d["id"]], roundi((float(res[d["id"]]) - mean) / maxf(1.0, mean) * 100.0)]
	if not pv["errors"].is_empty():
		t += "\n[color=#ffcc66]%s[/color]\n" % "\n".join(pv["errors"])
	var acts := LQ.districting_acts(w)
	if not acts.is_empty():
		t += "\n[b]Districting acts[/b]\n"
		for a in acts.slice(0, 5):
			t += "• %s, %s: %d districts (%s)\n" % [_month_text(int(a["month"])), String(a["level"]).to_lower(), a["map"].size(), String(a["status"]).to_lower()]
	return t


func _draw_text(w: WorldState) -> String:
	_act_btn.text = "Submit as a bill"
	_act_btn.disabled = true
	if plan.is_empty():
		return "[b]Draw districts[/b]\n[i]Districts are groups of areas; areas arrive with the economy's area update (A2). Nothing to draw yet.[/i]"
	var t := "[b]Draw districts[/b]\nPick a district above, then click areas to move them into it.\n\n"
	var p := clean_plan()
	var pv: Dictionary = LQ.districting_preview(w, p, "LAW")
	var names: Array = plan.keys()
	names.sort()
	for n in names:
		var info: Dictionary = pv["districts"].get(n, {})
		var mark := "▶ " if n == draw_group else ""
		t += "[color=#%s]■[/color] %s[b]%s[/b]: %d areas, %d residents" % [_district_color(n).to_html(false), mark, n, plan[n].size(), int(info.get("residents", 0))]
		if not info.is_empty():
			t += " (%+d%%)%s" % [int(info.get("deviation_pct", 0)), "" if info.get("contiguous", true) else " [color=#ef5350]not contiguous[/color]"]
		t += "\n"
	if pv["ok"]:
		t += "\n[color=#8bc34a]Valid map: balanced and contiguous.[/color]\n"
		_act_btn.disabled = false
	else:
		t += "\n[color=#ef5350]%s[/color]\n" % "\n".join(pv["errors"])
		if not pv["allowed_now"]:
			t += "[color=#ffcc66]%s[/color]\n" % pv["reason"]
	var gov := DistrictPolitics.score(w, p, session.pol_state().get("government", {}).get("members", [])) if not session.pol_state().get("government", {}).is_empty() else 0.0
	var cur := DistrictPolitics.score(w, DistrictPolitics.current_plan(w), session.pol_state().get("government", {}).get("members", [])) if not session.pol_state().get("government", {}).is_empty() else 0.0
	if gov != cur:
		t += "\nGovernment parties would lead in %+.0f district%s compared with today.\n" % [gov - cur, "" if absf(gov - cur) == 1.0 else "s"]
	return t


func _refresh_draw_controls() -> void:
	for c in _draw_groups.get_children():
		c.queue_free()
	var names: Array = plan.keys()
	names.sort()
	for n in names:
		var b := Button.new()
		b.text = String(n)
		b.toggle_mode = true
		b.button_pressed = n == draw_group
		b.add_theme_color_override("font_color", _district_color(n).lightened(0.3))
		var key: String = n
		b.pressed.connect(func(): draw_group = key; _draw_name.text = key; _update_panel())
		_draw_groups.add_child(b)
	if not _draw_name.has_focus():
		_draw_name.text = draw_group


func _month_text(m: int) -> String:
	const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s Year %d" % [MONTHS[posmod(m, 12)], m / 12 + 1]


static func _money(credits: float) -> String:
	if absf(credits) >= 1_000_000.0:
		return "%.2fM" % (credits / 1_000_000.0)
	if absf(credits) >= 1000.0:
		return "%.0fk" % (credits / 1000.0)
	return "%.0f" % credits
