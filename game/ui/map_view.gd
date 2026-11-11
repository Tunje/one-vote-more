class_name MapView
extends Control
## 2D tile map of the colony (A2: 2D for the first playable). Districts are regions of a fixed tile grid,
## generated deterministically from hand-placed district seeds (presentation only, not simulation state).

signal district_selected(district_id: String)

const W := 48
const H := 30
## Presentation layout for D5 v1 districts: tile seed position and region weight.
const LAYOUT := {
	"d:1": {"pos": Vector2i(24, 15), "w": 3.0},   # Landing
	"d:2": {"pos": Vector2i(35, 11), "w": 1.5},   # Riverside
	"d:3": {"pos": Vector2i(8, 24), "w": 1.0},    # Redrock
	"d:4": {"pos": Vector2i(14, 17), "w": 1.2},   # Foundry
	"d:5": {"pos": Vector2i(37, 23), "w": 0.8},   # Greenhill
	"d:6": {"pos": Vector2i(21, 4), "w": 1.0},    # Northfield
}
const BASE_COLORS := {"d:1": Color("#7fa6c9"), "d:2": Color("#8cc59a"), "d:3": Color("#c98a6b"),
	"d:4": Color("#a9a2c4"), "d:5": Color("#b9d27c"), "d:6": Color("#d9cf9a")}
const WILD := Color("#3b4a3f")
const MAX_REACH := 13.0

var overlay := "DISTRICTS"   # DISTRICTS | UNEMPLOYMENT | APPROVAL | LEAN
var session: GameSession
var selected := ""
var _owner: Array = []       # [y][x] -> district id or ""
var _values := {}            # district -> overlay value


func _ready() -> void:
	_build_grid()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_grid() -> void:
	_owner.clear()
	for y in H:
		var row: Array = []
		for x in W:
			var best := ""
			var bd := INF
			for d in LAYOUT:
				var p: Vector2i = LAYOUT[d]["pos"]
				var dist := Vector2(x - p.x, y - p.y).length() / sqrt(LAYOUT[d]["w"])
				# deterministic jagged borders
				dist += float((x * 73856093 ^ y * 19349663) % 7) * 0.08
				if dist < bd:
					bd = dist
					best = d
			row.append(best if bd < MAX_REACH else "")
		_owner.append(row)


func refresh() -> void:
	_values.clear()
	if session == null:
		queue_redraw()
		return
	var w := session.world()
	match overlay:
		"UNEMPLOYMENT":
			for d in LAYOUT:
				_values[d] = w.indicators.read("ECON_UNEMPLOYMENT_RATE", d) / 1000.0
		"APPROVAL", "LEAN":
			var dp := session.district_politics()
			for d in dp:
				_values[d] = dp[d]["approval" if overlay == "APPROVAL" else "lean"]
	queue_redraw()


func _tile_size() -> float:
	return minf(size.x / W, size.y / H)


func _color_for(d: String) -> Color:
	if d == "":
		return WILD
	match overlay:
		"UNEMPLOYMENT":
			return Color("#4caf50").lerp(Color("#d32f2f"), clampf(_values.get(d, 0.0) / 30.0, 0.0, 1.0))
		"APPROVAL":
			return Color("#d32f2f").lerp(Color("#4caf50"), clampf(_values.get(d, 50.0) / 100.0, 0.0, 1.0))
		"LEAN":
			var v: float = clampf(_values.get(d, 0.0) / 40.0, -1.0, 1.0)  # + = left
			return Color("#e8e8e8").lerp(Color("#c0392b") if v > 0 else Color("#2f6db5"), absf(v))
	return BASE_COLORS.get(d, Color.GRAY)


func _draw() -> void:
	var t := _tile_size()
	for y in H:
		for x in W:
			var d: String = _owner[y][x]
			var c := _color_for(d)
			var shade := float((x * 31 + y * 17) % 5) * 0.02
			c = c.darkened(shade)
			if d != "" and d == selected:
				c = c.lightened(0.25)
			draw_rect(Rect2(x * t, y * t, t - 1, t - 1), c)
	# roads between linked districts
	for l in EconData.LINKS:
		var a: Vector2i = LAYOUT[l[0]]["pos"]
		var b: Vector2i = LAYOUT[l[1]]["pos"]
		draw_line(Vector2(a) * t + Vector2(t, t) * 0.5, Vector2(b) * t + Vector2(t, t) * 0.5, Color("#5b4636"), maxf(2.0, t * 0.25))
	# labels
	var font := get_theme_default_font()
	for d in LAYOUT:
		var p: Vector2i = LAYOUT[d]["pos"]
		var label: String = EconData.DISTRICTS.get(d, {}).get("name", d)
		if overlay != "DISTRICTS" and _values.has(d):
			label += "  %.0f%s" % [_values[d], "%" if overlay != "LEAN" else ""]
		var pos := Vector2(p) * t + Vector2(-t, -t * 0.6)
		draw_string(font, pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tile_size()
		var x := int(event.position.x / t)
		var y := int(event.position.y / t)
		if x >= 0 and x < W and y >= 0 and y < H and _owner[y][x] != "":
			selected = _owner[y][x]
			district_selected.emit(selected)
			queue_redraw()
