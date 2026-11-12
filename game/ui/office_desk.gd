class_name OfficeDesk
extends Control
## Terra (A44 §O3–O4): the office as a drawn scene, the governor's desk seen from the chair. Clickable objects:
## newspaper (Paper), in-tray (Reports), PC (Inbox), red phone (Calls), wall calendar (Calendar), door (Visitors) and
## the window (the colony outside). Presentation only: reads the office channel (Office, OfficeFeed) and the staff
## queries; clicking emits `object_clicked(tab)` and the office panel shows that tab's content.
## Drawn on a 1280×720 canvas, scaled to fit (letterboxed), so it reads the same at any window size.

signal object_clicked(tab: String)   # "Paper" | "Reports" | "Inbox" | "Calls" | "Calendar" | "Visitors" | "Outside"

const W := 1280.0
const H := 720.0
const SQ := preload("res://sim/staff/staff_query.gd")
const LQ := preload("res://sim/law/law_query.gd")
## The charter on the wall follows the colony's sovereignty (law): its title and seal colour.
const CHARTER_TITLE := {"COLONY": ["CHARTER COLONY", Color("#b8452f")], "INDEPENDENCE_DECLARED": ["INDEPENDENCE DECLARED", Color("#c9862f")],
	"AUTONOMY": ["AUTONOMOUS", Color("#2f7a5c")], "INDEPENDENT": ["INDEPENDENT", Color("#2f5d9c")]}
const Gazette := preload("res://ui/panels/gazette_panel.gd")
const MONTHS := ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
## Hotspots on the canvas: object -> [rect, tab, tooltip]
const SPOTS := {
	"window": [Rect2(60, 50, 380, 290), "Outside", "The window: look out over the colony"],
	"calendar": [Rect2(700, 50, 210, 250), "Calendar", "The wall calendar: the next twelve months"],
	"door": [Rect2(1010, 40, 220, 440), "Visitors", "The door: visitors and interviews"],
	"pc": [Rect2(442, 262, 254, 250), "Inbox", "Your computer: the inbox"],
	"tray": [Rect2(105, 470, 250, 160), "Reports", "The in-tray: reports"],
	"paper": [Rect2(470, 500, 330, 165), "Paper", "Today's paper and the press digest"],
	"phone": [Rect2(900, 520, 230, 150), "Calls", "The red phone"],
}
const C_WALL := Color("#e9d8b8")
const C_WALL_DARK := Color("#d4bf98")
const C_WOOD := Color("#8a5a35")
const C_WOOD_DARK := Color("#5f3c22")
const C_DESK := Color("#9b6a3f")
const C_DESK_EDGE := Color("#6e4526")
const C_INK := Color("#2b2620")

var session
var _hover := ""
var _t := 0.0
var _view_tex: ImageTexture
var _view_for := ""
var _data := {}
## What the window looks out on: "MAP" (the colony map, from close by) or "PLANET" (the globe, when the player was on
## the planet view). The main screen sets it when the office opens; clicking the window returns to that view.
var outside := "MAP":
	set(v):
		outside = v
		_place_vista()
var _globe_tex: ImageTexture
var _globe_for := ""
var _vista: ColonyVista            # the view out of the window (a child laid on the glass)
var _globe_mark := Vector2.ZERO   # where the colony is on the globe picture (-1..1, y up)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # the view outside in crisp pixels
	custom_minimum_size = Vector2(640, 360)


## Re-read the office (counts, headline, calendar marks) and redraw.
func refresh() -> void:
	_data = gather()
	if _vista == null:
		_vista = ColonyVista.new()
		add_child(_vista)
	_vista.session = session
	_vista.refresh()
	_place_vista()
	queue_redraw()


## The view sits exactly on the window's glass (canvas → screen), and shows only when the window looks on the colony.
func _place_vista() -> void:
	if _vista == null:
		return
	var glass: Rect2 = (SPOTS["window"][0] as Rect2).grow(-14)
	_vista.position = _offset() + glass.position * _scale()
	_vista.size = glass.size * _scale()
	_vista.visible = outside != "PLANET"
	_vista.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_vista()


## What the desk shows, as plain data (tests read this too).
func gather() -> Dictionary:
	var d := {"reports_new": 0, "reports": 0, "inbox": 0, "urgent": 0, "calls": 0, "visitors": 0, "hours": 0,
		"headline": "", "masthead": "THE GAZETTE", "marks": {}, "election": -1, "month": 0, "role": "Governor", "status": "COLONY"}
	if session == null:
		return d
	var w: WorldState = session.world()
	d["month"] = w.month
	d["status"] = String(LQ.sovereignty(w).get("status", "COLONY"))
	var reps := Office.items(w, ["REPORT"])
	d["reports"] = reps.size()
	d["reports_new"] = reps.filter(func(o): return o["status"] == "NEW").size()
	var mails := Office.items(w, ["EMAIL"])
	d["inbox"] = mails.size()
	d["urgent"] = mails.filter(func(o): return int(o.get("deadline", -1)) >= 0 and int(o.get("deadline", -1)) <= w.month + 1).size()
	d["calls"] = Office.items(w, ["CALL"]).size()
	d["visitors"] = SQ.recruitments(w).filter(func(r): return int(r.get("picked", -1)) < 0).size()
	d["hours"] = OfficeFeed.hours(w)
	var papers := Office.items(w, ["PAPER"])
	if not papers.is_empty():
		var dg: Array = papers[0].get("digest", [])
		if not dg.is_empty():
			var f: Dictionary = w.facts.get_fact(String(dg[0].get("fact", "")))
			if not f.is_empty():
				d["headline"] = Gazette.headline(w, f)
			d["masthead"] = String(dg[0].get("outlet_name", "THE GAZETTE")).to_upper()
	var marks := {}
	for o in Office.items(w, ["CALENDAR", "EMAIL", "CALL"]):
		var dl := int(o.get("deadline", -1))
		if dl >= w.month and dl < w.month + 12:
			marks[dl] = int(marks.get(dl, 0)) + 1
	d["marks"] = marks
	if session.has_method("next_election_month"):
		d["election"] = int(session.next_election_month())
	var era := String(session.pol_state().get("era", "")) if session.has_method("pol_state") else ""
	d["role"] = "Commander" if era == "FOUNDING" else ("Governor" if OfficeFeed.player_office(w) else "Party leader")
	return d


# ------------------------------------------------------------------ canvas mapping

func _scale() -> float:
	return minf(size.x / W, size.y / H)


func _offset() -> Vector2:
	return (size - Vector2(W, H) * _scale()) * 0.5


func to_canvas(p: Vector2) -> Vector2:
	return (p - _offset()) / maxf(_scale(), 0.001)


## Which object is under a canvas point ("" = none). Later entries (the desk things) win over the wall.
func spot_at(cp: Vector2) -> String:
	var hit := ""
	for k in ["window", "calendar", "door", "pc", "tray", "paper", "phone"]:
		if (SPOTS[k][0] as Rect2).has_point(cp):
			hit = k
	return hit


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var k := spot_at(to_canvas((event as InputEventMouseMotion).position))
		if k != _hover:
			_hover = k
			tooltip_text = String(SPOTS[k][2]) if k != "" else ""
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if k != "" else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var k2 := spot_at(to_canvas((event as InputEventMouseButton).position))
		if k2 != "":
			object_clicked.emit(String(SPOTS[k2][1]))
			accept_event()


## Click an object by name (tests, shot tool).
func click(obj: String) -> void:
	object_clicked.emit(String(SPOTS[obj][1]))


func _process(delta: float) -> void:
	if int(_data.get("calls", 0)) > 0 and is_visible_in_tree():
		_t += delta
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#1b1712"))
	draw_set_transform(_offset(), 0.0, Vector2(_scale(), _scale()))
	if _data.is_empty():
		_data = gather()
	_draw_room()
	_draw_window()
	_draw_calendar()
	_draw_clock()
	_draw_door()
	_draw_desk()
	_draw_pc()
	_draw_tray()
	_draw_paper()
	_draw_phone()
	_draw_plate()
	if _hover != "":
		var r: Rect2 = SPOTS[_hover][0]
		draw_rect(r.grow(4), Color(1.0, 0.92, 0.6, 0.9), false, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _font() -> Font:
	return get_theme_default_font()


func _text(p: Vector2, s: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(_font(), p, s, align, width, fs, col)


func _badge(c: Vector2, n: int, col: Color = Color("#d84a3a")) -> void:
	if n <= 0:
		return
	draw_circle(c, 17.0, Color(0, 0, 0, 0.35))
	draw_circle(c, 15.0, col)
	_text(c + Vector2(-15, 6), str(n) if n < 100 else "99+", 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 30.0)


func _draw_room() -> void:
	draw_rect(Rect2(0, 0, W, 470), C_WALL)
	for i in 14:   # faint wallpaper stripes
		draw_rect(Rect2(i * 92.0, 0, 46, 470), C_WALL_DARK * Color(1, 1, 1, 0.25))
	draw_rect(Rect2(0, 380, W, 90), C_WALL_DARK)   # wainscot
	draw_rect(Rect2(0, 376, W, 8), C_WOOD)
	draw_rect(Rect2(0, 466, W, 6), C_WOOD_DARK)
	# a framed charter on the wall
	var ct: Array = CHARTER_TITLE.get(String(_data.get("status", "COLONY")), CHARTER_TITLE["COLONY"])
	draw_rect(Rect2(480, 66, 200, 128), C_WOOD_DARK)
	draw_rect(Rect2(490, 76, 180, 108), Color("#f4ecd8"))
	_text(Vector2(490, 100), String(ct[0]), 14 if String(ct[0]).length() > 16 else 16, C_INK, HORIZONTAL_ALIGNMENT_CENTER, 180.0)
	for k in 5:
		draw_line(Vector2(506, 116 + k * 11), Vector2(640 - (k % 2) * 24, 116 + k * 11), Color(0.3, 0.27, 0.22, 0.6), 1.5)
	draw_circle(Vector2(650, 166), 11.0, ct[1])   # the seal
	draw_circle(Vector2(650, 166), 6.0, Color(ct[1]).lightened(0.25))


func _draw_window() -> void:
	var r: Rect2 = SPOTS["window"][0]
	draw_rect(r, C_WOOD_DARK)
	var glass := r.grow(-14)
	if session != null:
		_ensure_view()
		if outside == "PLANET":
			_ensure_globe()
	if outside == "PLANET" and _globe_tex != null:   # night sky, and the planet hanging in it
		draw_rect(glass, Color("#0d1424"))
		for k in 24:
			var sx := glass.position.x + float((k * 97) % int(glass.size.x))
			var sy := glass.position.y + float((k * 53) % int(glass.size.y))
			draw_circle(Vector2(sx, sy), 1.2, Color(1, 1, 1, 0.7))
		var dsz := minf(glass.size.x, glass.size.y) * 0.92
		draw_texture_rect(_globe_tex, Rect2(glass.get_center() - Vector2(dsz, dsz) * 0.5, Vector2(dsz, dsz)), false)
		var mk := glass.get_center() + Vector2(_globe_mark.x, -_globe_mark.y) * dsz * 0.5
		draw_arc(mk, 9.0, 0.0, TAU, 16, Color("#ffd75e"), 2.5)   # the colony
	elif _vista != null and _vista.visible:
		pass   # the view (ColonyVista) is laid on the glass as a child
	elif _view_tex != null:
		draw_texture_rect(_view_tex, glass, false)
	else:
		draw_rect(glass, Color("#8cc3e8"))
	draw_rect(Rect2(glass.position, Vector2(glass.size.x, glass.size.y * 0.18)), Color(0.7, 0.85, 1.0, 0.35))   # sky haze
	draw_line(Vector2(glass.get_center().x, glass.position.y), Vector2(glass.get_center().x, glass.end.y), C_WOOD_DARK, 8.0)
	draw_line(Vector2(glass.position.x, glass.get_center().y), Vector2(glass.end.x, glass.get_center().y), C_WOOD_DARK, 8.0)
	draw_rect(Rect2(r.position.x - 10, r.end.y - 4, r.size.x + 20, 14), C_WOOD)   # sill
	# curtains
	draw_rect(Rect2(r.position.x - 30, r.position.y - 16, 34, r.size.y + 40), Color("#9c3d2e"))
	draw_rect(Rect2(r.end.x - 4, r.position.y - 16, 34, r.size.y + 40), Color("#9c3d2e"))
	draw_rect(Rect2(r.position.x - 40, r.position.y - 24, r.size.x + 80, 10), C_WOOD_DARK)


## The view outside: the colony map's terrain, as a small picture (refreshed when the map changes).
func _ensure_view() -> void:
	var w: WorldState = session.world()
	if not Terrain.ready(w):
		return
	var key := "%d|%d" % [w.rng.derive_seed("map.terrain"), w.peek("area").size()]
	if key == _view_for and _view_tex != null:
		return
	_view_for = key
	var img := Image.create(Terrain.W, Terrain.H, false, Image.FORMAT_RGBA8)
	for y in Terrain.H:
		for x in Terrain.W:
			var c: Color = MapView.TERRAIN_COLORS.get(Terrain.at(w, x, y), Color.GRAY)
			if not Terrain.use_at(w, x, y).is_empty():
				c = c.lerp(Color("#e9c46a"), 0.6)
			img.set_pixel(x, y, c)
	for s in ColonyLayout.settlements(w):   # the towns, as warm roofs
		var t: Vector2i = s["tile"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if t.x + dx >= 0 and t.x + dx < Terrain.W and t.y + dy >= 0 and t.y + dy < Terrain.H:
					img.set_pixel(t.x + dx, t.y + dy, Color("#c8553d") if (dx + dy) % 2 == 0 else Color("#efe1c0"))
	_view_tex = ImageTexture.create_from_image(img)


## The globe as seen from space, centred on the colony (biome colours, a little shading, the landing hex marked).
func _ensure_globe() -> void:
	var w: WorldState = session.world()
	if not Planet.ready(w):
		return
	var key := "%d|%d" % [w.rng.derive_seed("planet.terrain"), Planet.landing(w)]
	if key == _globe_for and _globe_tex != null:
		return
	_globe_for = key
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fq := Planet.freq(w)
	var cs: PackedVector3Array = Planet.geometry(fq)["centers"]
	var home := Planet.landing(w)
	var h: Vector3 = cs[home].normalized()
	var r0 := Vector3.UP.cross(h).normalized()
	if r0.length() < 0.01:
		r0 = Vector3.RIGHT
	var u0 := h.cross(r0).normalized()
	var fwd := (h - r0 * 0.4 - u0 * 0.35).normalized()   # look a little past the colony: it sits in the upper-right pane
	var right := Vector3.UP.cross(fwd).normalized()
	if right.length() < 0.01:
		right = Vector3.RIGHT
	var up := fwd.cross(right).normalized()
	_globe_mark = Vector2(h.dot(right), h.dot(up))
	var bio := Planet.biomes(w)
	var hint := home
	for y in n:
		for x in n:
			var u := (float(x) + 0.5) / n * 2.0 - 1.0
			var v := 1.0 - (float(y) + 0.5) / n * 2.0
			var r2 := u * u + v * v
			if r2 > 1.0:
				continue
			var z := sqrt(1.0 - r2)
			var dir := right * u + up * v + fwd * z
			hint = Planet.cell_at(dir, fq, hint)
			var c: Color = PlanetView.BIOME_COLORS.get(bio.substr(hint, 1), Color.GRAY)
			c = c.darkened(0.55 * (1.0 - z))   # the limb darkens
			if hint == home:
				c = Color("#ffd75e")
			img.set_pixel(x, y, c)
	_globe_tex = ImageTexture.create_from_image(img)


func _draw_calendar() -> void:
	var r: Rect2 = SPOTS["calendar"][0]
	draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, 0.18))
	draw_rect(r, Color("#fbf7ee"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 46)), Color("#b8452f"))
	var m: int = int(_data.get("month", 0))
	_text(r.position + Vector2(0, 32), "YEAR %d" % (m / 12 + 1), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	draw_circle(r.position + Vector2(r.size.x * 0.5, -6), 5.0, Color("#555555"))   # the nail
	var marks: Dictionary = _data.get("marks", {})
	var el := int(_data.get("election", -1))
	for i in 12:
		var cx := r.position.x + 14 + (i % 4) * 47.0
		var cy := r.position.y + 58 + (i / 4) * 62.0
		var cell := Rect2(cx, cy, 42, 56)
		var mm := m + i
		draw_rect(cell, Color("#f1e9d6") if i > 0 else Color("#ffe9a8"))
		draw_rect(cell, Color("#cdbf9f"), false, 1.0)
		_text(Vector2(cx, cy + 20), MONTHS[posmod(mm, 12)], 16, C_INK, HORIZONTAL_ALIGNMENT_CENTER, 42.0)
		if mm == el:   # election day: a ballot cross
			draw_rect(Rect2(cx + 11, cy + 28, 20, 20), Color("#2f5d9c"), false, 2.0)
			draw_line(Vector2(cx + 14, cy + 31), Vector2(cx + 28, cy + 45), Color("#2f5d9c"), 2.5)
			draw_line(Vector2(cx + 28, cy + 31), Vector2(cx + 14, cy + 45), Color("#2f5d9c"), 2.5)
		elif marks.has(mm):   # deadlines: red ink circles
			draw_arc(Vector2(cx + 21, cy + 38), 11.0, 0.0, TAU, 18, Color("#c0392b"), 2.5)
			if int(marks[mm]) > 1:
				_text(Vector2(cx + 15, cy + 44), str(int(marks[mm])), 13, Color("#c0392b"))


func _draw_clock() -> void:
	var c := Vector2(955, 130)
	draw_circle(c, 30.0, C_WOOD_DARK)
	draw_circle(c, 25.0, Color("#fbf7ee"))
	var hrs := int(_data.get("hours", 0))
	var a := -PI / 2.0 + TAU * float(posmod(hrs, 12)) / 12.0
	draw_line(c, c + Vector2(cos(a), sin(a)) * 15.0, C_INK, 3.0)
	draw_line(c, c + Vector2(0, -20), C_INK, 2.0)
	_text(c + Vector2(-45, 50), "%d hours" % hrs, 15, C_INK, HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	_text(c + Vector2(-45, 68), "left", 15, C_INK, HORIZONTAL_ALIGNMENT_CENTER, 90.0)


func _draw_door() -> void:
	var r: Rect2 = SPOTS["door"][0]
	var n := int(_data.get("visitors", 0))
	draw_rect(r.grow(10), C_WOOD_DARK)
	if n > 0:   # ajar: light from the corridor and someone waiting
		draw_rect(r, Color("#f6e7b5"))
		var sil := Color("#3a3530")
		var hx := r.position.x + 68
		draw_circle(Vector2(hx, r.position.y + 150), 28.0, sil)   # head
		draw_rect(Rect2(hx - 9, r.position.y + 172, 18, 16), sil)   # neck
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 50, r.position.y + 210), Vector2(hx + 50, r.position.y + 210),
			Vector2(hx + 44, r.end.y), Vector2(hx - 44, r.end.y)]), sil)   # coat
		draw_circle(Vector2(hx - 34, r.position.y + 214), 18.0, sil)   # shoulders
		draw_circle(Vector2(hx + 34, r.position.y + 214), 18.0, sil)
		draw_line(Vector2(hx, r.position.y + 200), Vector2(hx, r.position.y + 290), Color("#efe1c0"), 2.0)   # shirt front
		var open := PackedVector2Array([r.position + Vector2(130, 0), r.end - Vector2(0, r.size.y), r.end, r.position + Vector2(130, r.size.y)])
		draw_colored_polygon(open, C_WOOD)
		draw_circle(Vector2(r.position.x + 146, r.position.y + 240), 7.0, Color("#d9b44a"))
		_badge(Vector2(r.end.x - 20, r.position.y + 20), n)
	else:
		draw_rect(r, C_WOOD)
		for k in 2:   # panels
			draw_rect(Rect2(r.position.x + 24, r.position.y + 24 + k * 205, r.size.x - 48, 180), C_WOOD_DARK, false, 3.0)
		draw_circle(Vector2(r.end.x - 26, r.position.y + 240), 8.0, Color("#d9b44a"))
	_text(Vector2(r.position.x, r.position.y - 16), "Visitors" if n > 0 else "", 16, C_INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_desk() -> void:
	var top := PackedVector2Array([Vector2(-40, 470), Vector2(W + 40, 470), Vector2(W + 40, H), Vector2(-40, H)])
	draw_colored_polygon(top, C_DESK)
	for i in 9:   # wood grain
		var y := 490.0 + i * 26.0
		draw_line(Vector2(0, y), Vector2(W, y + (i % 3) * 4.0), Color(0.35, 0.2, 0.1, 0.18), 2.0)
	draw_rect(Rect2(0, 466, W, 10), C_DESK_EDGE)
	# a desk lamp on the left
	var lx := 18.0   # the lamp stands at the far left edge, clear of the in-tray and the paper
	draw_rect(Rect2(lx, 560, 44, 10), Color("#2f3b33"))
	draw_line(Vector2(lx + 22, 560), Vector2(lx + 36, 498), Color("#2f3b33"), 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 12, 500), Vector2(lx + 62, 488), Vector2(lx + 68, 514), Vector2(lx + 18, 522)]), Color("#2e6b4f"))
	draw_circle(Vector2(lx + 40, 520), 20.0, Color(1.0, 0.92, 0.6, 0.12))


func _draw_pc() -> void:
	var r: Rect2 = SPOTS["pc"][0]
	var scr := Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, 170))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 190)), Color("#2b2d31"))
	draw_rect(scr, Color("#1d3a5c"))
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 18, r.position.y + 190, 36, 34), Color("#2b2d31"))   # stand
	draw_rect(Rect2(r.position.x + r.size.x * 0.5 - 70, r.position.y + 222, 140, 12), Color("#2b2d31"))
	draw_rect(Rect2(r.position.x + 5, r.position.y + 240, r.size.x - 10, 10), Color("#3d4046"))   # keyboard edge
	var n := int(_data.get("inbox", 0))
	_text(scr.position + Vector2(14, 34), "Inbox", 22, Color("#cfe3ff"))
	_text(scr.position + Vector2(14, 72), ("%d message%s" % [n, "" if n == 1 else "s"]) if n > 0 else "Nothing new", 18, Color.WHITE)
	var urgent := int(_data.get("urgent", 0))
	if urgent > 0:
		_text(scr.position + Vector2(14, 102), "%d due now" % urgent, 16, Color("#ff9a7a"))
	for k in mini(n, 4):   # message lines
		draw_rect(Rect2(scr.position.x + 14, scr.position.y + 118 + k * 12, scr.size.x - 40 - (k * 23) % 60, 6), Color(0.8, 0.88, 1.0, 0.35))
	_badge(Vector2(r.end.x - 12, r.position.y + 8), n)


func _draw_tray() -> void:
	var r: Rect2 = SPOTS["tray"][0]
	var total := int(_data.get("reports", 0))
	var fresh := int(_data.get("reports_new", 0))
	var base := Rect2(r.position.x + 10, r.end.y - 40, r.size.x - 20, 30)
	var stack := mini(total, 10)
	for k in stack:   # a little stack of paper, new ones on top in white
		var y := base.position.y - 6 - k * 7.0
		var col := Color("#ffffff") if k >= stack - fresh else Color("#e6dcc4")
		draw_rect(Rect2(base.position.x + 12 + (k % 3) * 3, y, base.size.x - 30, 10), col)
		draw_rect(Rect2(base.position.x + 12 + (k % 3) * 3, y, base.size.x - 30, 10), Color(0, 0, 0, 0.15), false, 1.0)
	draw_rect(base, Color("#4d4a45"))   # the tray
	draw_rect(Rect2(base.position, Vector2(base.size.x, 6)), Color("#6c6862"))
	_text(Vector2(base.position.x, base.end.y + 22), "IN", 18, Color("#f4ecd8"), HORIZONTAL_ALIGNMENT_CENTER, base.size.x)
	_badge(Vector2(r.end.x - 14, base.position.y - 18 - stack * 7.0), fresh)


func _draw_paper() -> void:
	var r: Rect2 = SPOTS["paper"][0]
	var pts := PackedVector2Array([r.position + Vector2(20, 10), r.position + Vector2(r.size.x, 0), r.end - Vector2(10, 0),
		r.position + Vector2(0, r.size.y)])
	draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(6, 6), pts[1] + Vector2(6, 6), pts[2] + Vector2(6, 6), pts[3] + Vector2(6, 6)]), Color(0, 0, 0, 0.2))
	draw_colored_polygon(pts, Color("#f2ede1"))
	draw_set_transform(_offset() + (r.position + Vector2(18, 8)) * _scale(), -0.03, Vector2(_scale(), _scale()))
	_text(Vector2(8, 34), String(_data.get("masthead", "THE GAZETTE")), 26, C_INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 36)
	draw_line(Vector2(8, 44), Vector2(r.size.x - 30, 44), C_INK, 2.0)
	var head := String(_data.get("headline", ""))
	if head == "":
		head = "Quiet month in the colony"
	var lines := _wrap(head, 18, r.size.x - 50)
	for i in mini(lines.size(), 2):
		_text(Vector2(8, 70 + i * 22), lines[i], 18, C_INK)
	for k in 4:   # columns of small print
		for c in 3:
			draw_line(Vector2(10 + c * 96, 118 + k * 9), Vector2(92 + c * 96, 118 + k * 9), Color(0.2, 0.18, 0.15, 0.4), 2.0)
	draw_set_transform(_offset(), 0.0, Vector2(_scale(), _scale()))


func _wrap(s: String, fs: int, width: float) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var t := word if cur == "" else cur + " " + word
		if _font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		out.append(cur)
	return out


func _draw_phone() -> void:
	var r: Rect2 = SPOTS["phone"][0]
	var n := int(_data.get("calls", 0))
	var c := r.get_center() + Vector2(0, 10)
	if n > 0:   # a call is waiting: the phone glows
		var a := 0.25 + 0.2 * sin(_t * 5.0)
		draw_circle(c, 95.0, Color(1.0, 0.3, 0.2, a * 0.5))
		draw_circle(c, 70.0, Color(1.0, 0.35, 0.25, a))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-80, 50), c + Vector2(80, 50), c + Vector2(60, -10), c + Vector2(-60, -10)]), Color("#b3261e"))
	draw_rect(Rect2(c + Vector2(-90, -40), Vector2(180, 34)), Color("#c62f25"))   # handset
	draw_circle(c + Vector2(-80, -23), 22.0, Color("#c62f25"))
	draw_circle(c + Vector2(80, -23), 22.0, Color("#c62f25"))
	draw_circle(c + Vector2(0, 22), 20.0, Color("#f2ede1"))   # the dial
	for k in 10:
		var ang := TAU * float(k) / 10.0
		draw_circle(c + Vector2(0, 22) + Vector2(cos(ang), sin(ang)) * 13.0, 2.5, C_INK)
	if n > 0:
		_text(Vector2(r.position.x, r.end.y + 6), "Ringing!", 20, C_INK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_badge(Vector2(r.end.x - 10, r.position.y + 10), n)


func _draw_plate() -> void:
	var role := String(_data.get("role", "Governor"))
	var r := Rect2(W * 0.5 - 140, H - 34, 280, 30)
	draw_rect(r, Color("#3a2a1a"))
	draw_rect(r.grow(-3), Color("#c9a34e"))
	_text(Vector2(r.position.x, r.position.y + 22), role.to_upper(), 18, Color("#3a2a1a"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
