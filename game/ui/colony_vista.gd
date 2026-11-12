class_name ColonyVista
extends Control
## Terra (A44, user: the office window should be a VIEW, not a display of the grounds): the colony seen from an office
## window in Landing, looking north over the real colony map in perspective: the ground tile by tile (hills raised,
## the river, fields), the other settlements as roof clusters, distant hills on the horizon, Landing's own rooftops
## in front. Sky, light and ground follow the season and Terra's weather this month (rain, snow, storms, lightning,
## spore haze, factory smoke). Presentation only; deterministic per world (no RNG streams are touched).

const HEIGHT := {".": 0.0, "f": 0.0, "n": 0.0, "L": 0.0, "r": -0.06, "h": 0.55, "k": 0.95, "o": 0.65, "x": 0.95}
const EYE := 0.75            # eye height above the ground, in tiles (the office is on the first floor)
const HORIZON := 0.36        # horizon line, share of the height
const FOCAL := 0.5           # focal length, share of the width (about 90° across)
const MAX_DIST := 34         # tiles drawn ahead
## Ground colours by season (summer greens, autumn gold, winter browns; snow is mixed in when it is cold).
const GROUND := {
	"SUMMER": {".": Color("#8fb35a"), "f": Color("#6fa84a"), "n": Color("#7fbf8a"), "L": Color("#b5a77a"), "h": Color("#8c8a52"), "k": Color("#7d756c"), "o": Color("#8a6a4a"), "x": Color("#8a7a8f")},
	"AUTUMN": {".": Color("#a9a35a"), "f": Color("#c9a440"), "n": Color("#9fbf7a"), "L": Color("#b5a77a"), "h": Color("#94814a"), "k": Color("#7d756c"), "o": Color("#8a6a4a"), "x": Color("#8a7a8f")},
	"WINTER": {".": Color("#8d8a6c"), "f": Color("#857a58"), "n": Color("#7f9a80"), "L": Color("#a59f86"), "h": Color("#7f7a62"), "k": Color("#77716c"), "o": Color("#7a6450"), "x": Color("#827888")},
	"SPRING": {".": Color("#9cc463"), "f": Color("#7cbf55"), "n": Color("#8fd09a"), "L": Color("#b5a77a"), "h": Color("#8e9a58"), "k": Color("#7d756c"), "o": Color("#8a6a4a"), "x": Color("#8a7a8f")},
}
const WATER := Color("#4f86b8")

var session
var mullions := true           # draw the window's cross bars (the 2D desk); the 3D window has its own frame
var _d := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func refresh() -> void:
	_d = gather(session.world() if session != null else null)
	queue_redraw()


## Everything the view needs, as plain data (tests read it).
## Which way the office window faces: towards the river where it runs 6–20 tiles from Landing (the view people
## would want), else north. A unit vector in map coordinates (y grows southwards).
static func look_dir(w: WorldState) -> Vector2:
	var e := Vector2(Terrain.landing(w)) + Vector2(0.5, 0.5)
	var acc := Vector2.ZERO
	var n := 0
	for y in Terrain.H:
		for x in Terrain.W:
			if Terrain.at(w, x, y) != "r":
				continue
			var d := Vector2(x, y) + Vector2(0.5, 0.5) - e
			if d.length() >= 6.0 and d.length() <= 20.0:
				acc += d.normalized()
				n += 1
	var dir := (acc / float(n)).normalized() if n > 0 else Vector2(0, -1)
	# lean it northwards a little so the long view runs over the most land
	return (dir + Vector2(0, -0.6)).normalized()


static func gather(w: WorldState) -> Dictionary:
	var d := {"ok": false}
	if w == null or not Terrain.ready(w) or not Planet.ready(w):
		return d
	var home := Planet.landing(w)
	var cl := PlanetClimate.climate(w, home, w.month)
	var wx := PlanetClimate.weather(w, home)
	var storm := 0
	for s in PlanetClimate.storms_at(w, home):
		storm = maxi(storm, int(s["strength"]))
	var ph := {}
	for p in PlanetClimate.phenomena_at(w, home):
		ph[String(p["kind"])] = int(p["strength"])
	d["ok"] = true
	d["season"] = String(cl["season"])
	d["temp"] = float(wx["temp_c"])
	d["rain"] = int(wx["rain_pct"])
	d["storm"] = storm
	d["phenomena"] = ph
	d["smoke"] = PlanetClimate.air_pollution(w, home)
	d["eye"] = Terrain.landing(w)
	d["look"] = look_dir(w)
	d["seed"] = w.rng.derive_seed("ui.vista")
	var towns: Array = []
	for st in ColonyLayout.settlements(w):
		var t: Vector2i = st["tile"]
		if true:
			towns.append({"tile": t, "size": clampi(st["tiles"].size() / 6, 2, 9), "name": st["name"]})
	d["towns"] = towns
	var homes := 0
	for f in w.peek("facility").values():
		if String(f.get("district", "")) == "d:1" and String(f["type"]) == "HOUSING":
			homes += 1
	d["roofs"] = clampi(homes + 4, 5, 12)
	return d


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var W := size.x
	var H := size.y
	if not _d.get("ok", false):
		draw_rect(Rect2(Vector2.ZERO, size), Color("#8cc3e8"))
		return
	var w: WorldState = session.world()
	var hy := H * HORIZON
	_draw_sky(W, hy)
	_draw_far_hills(W, hy)
	_draw_ground(w, W, H, hy)
	_draw_towns(W, hy)
	_draw_smoke(W, hy)
	_draw_rooftops(W, H)
	_draw_weather(W, H)
	if mullions:
		draw_line(Vector2(W * 0.5, 0), Vector2(W * 0.5, H), Color("#5f3c22"), maxf(3.0, W * 0.02))
		draw_line(Vector2(0, H * 0.5), Vector2(W, H * 0.5), Color("#5f3c22"), maxf(3.0, W * 0.02))
	draw_rect(Rect2(0, 0, W, H * 0.16), Color(1, 1, 1, 0.06))   # a little glare on the glass


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = int(_d.get("seed", 1)) + salt
	return r


func _draw_sky(W: float, hy: float) -> void:
	var season := String(_d["season"])
	var storm := int(_d["storm"])
	var rain := int(_d["rain"])
	var top := {"SUMMER": Color("#4f8fd6"), "SPRING": Color("#6aa2dc"), "AUTUMN": Color("#7d9cc0"), "WINTER": Color("#9fb4c8")}.get(season, Color("#6aa2dc")) as Color
	var low := {"SUMMER": Color("#cfe6f7"), "SPRING": Color("#d9ecf6"), "AUTUMN": Color("#e6dccb"), "WINTER": Color("#e4e8ec")}.get(season, Color("#d9ecf6")) as Color
	var gloom := clampf(float(rain - 100) / 120.0, 0.0, 0.6) + 0.15 * storm
	top = top.lerp(Color("#4a5260"), clampf(gloom, 0.0, 0.85))
	low = low.lerp(Color("#8a9098"), clampf(gloom, 0.0, 0.85))
	var bands := 12
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(0, hy * t, W, hy / bands + 1.0), top.lerp(low, t))
	if gloom < 0.3:   # the sun, low in the south-west behind us: light from the left
		draw_circle(Vector2(W * 0.12, hy * 0.25), W * 0.05, Color(1.0, 0.97, 0.85, 0.5))
	var r := _rng(1)
	var clouds := 3 + int(gloom * 10.0)
	for k in clouds:   # clouds: soft blobs, darker in bad weather
		var cx := r.randf() * W
		var cy := hy * (0.1 + r.randf() * 0.55)
		var cw := W * (0.08 + r.randf() * 0.12)
		var cc := Color(1, 1, 1, 0.75).lerp(Color("#5a606a"), clampf(gloom, 0.0, 1.0))
		for b in 4:
			draw_circle(Vector2(cx + (float(b) - 1.5) * cw * 0.35, cy + (0.0 if b % 2 == 0 else -cw * 0.12)), cw * 0.32, cc)
	if storm >= 3:   # lightning
		var lx := W * (0.55 + r.randf() * 0.3)
		var pts := PackedVector2Array([Vector2(lx, hy * 0.2), Vector2(lx - W * 0.02, hy * 0.5), Vector2(lx + W * 0.01, hy * 0.52), Vector2(lx - W * 0.015, hy)])
		draw_polyline(pts, Color(1.0, 1.0, 0.85, 0.9), maxf(1.5, W * 0.005))


## The land beyond the colony map: hazy ridges on the horizon (blue with distance).
func _draw_far_hills(W: float, hy: float) -> void:
	var r := _rng(2)
	for layer in 2:
		var col := Color("#7d8fa6").lerp(Color("#5d7a5a"), float(layer) * 0.5)
		col.a = 0.9
		var pts := PackedVector2Array([Vector2(0, hy + 2)])
		var n := 14
		var base := hy - (8.0 - layer * 3.0) * W / 380.0
		for i in n + 1:
			var x := W * float(i) / n
			pts.append(Vector2(x, base - r.randf() * (14.0 - layer * 5.0) * W / 380.0))
		pts.append(Vector2(W, hy + 2))
		draw_colored_polygon(pts, col)


func _height(w: WorldState, x: int, y: int) -> float:
	return float(HEIGHT.get(Terrain.at(w, x, y), 0.0))


## Height at a tile corner: the mean of the tiles meeting there (smooth hills).
func _corner(w: WorldState, x: int, y: int) -> float:
	var s := 0.0
	var n := 0
	for t in [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]:
		if Terrain.at(w, t.x, t.y) != "":
			s += _height(w, t.x, t.y)
			n += 1
	return s / maxf(1.0, float(n))


## Project a point of the colony map (x, y in tiles, h height) seen from the office, looking north.
func _proj(p: Vector2, h: float, W: float, hy: float) -> Vector2:
	var fs := _fwd_side(p)
	var fwd := maxf(fs.x, 0.05)
	var f := W * FOCAL
	return Vector2(W * 0.5 + f * fs.y / fwd, hy + f * (EYE - h) / fwd)


## (distance ahead, distance to the right) of a map point, seen from the office.
func _fwd_side(p: Vector2) -> Vector2:
	var e: Vector2i = _d["eye"]
	var look: Vector2 = _d.get("look", Vector2(0, -1))
	var right := Vector2(-look.y, look.x)
	var rel := p - (Vector2(e) + Vector2(0.5, 0.5))
	return Vector2(rel.dot(look), rel.dot(right))


func _draw_ground(w: WorldState, W: float, H: float, hy: float) -> void:
	var e: Vector2i = _d["eye"]
	var pal: Dictionary = GROUND.get(String(_d["season"]), GROUND["SUMMER"])
	var cold := clampf((1.0 - float(_d["temp"])) / 6.0, 0.0, 0.85)   # snow cover below about 1 °C
	var base: Color = (pal["."] as Color).lerp(Color("#f4f6f8"), cold * 0.5)
	draw_rect(Rect2(0, hy, W, H - hy), base)   # the ground under everything (the nearest rows are rooftops)
	var tiles: Array = []   # [distance ahead, x, y] of the tiles in front of the window
	for yy in Terrain.H:
		for xx in Terrain.W:
			var fs := _fwd_side(Vector2(xx, yy) + Vector2(0.5, 0.5))
			if fs.x >= 1.6 and fs.x <= MAX_DIST and absf(fs.y) <= fs.x * 1.3 + 2.0:
				tiles.append([fs.x, xx, yy])
	tiles.sort_custom(func(a, b): return a[0] > b[0])   # far to near: nearer tiles paint over farther ones
	for tl in tiles:
		var x: int = tl[1]
		var y: int = tl[2]
		if true:
			var code := Terrain.at(w, x, y)
			var c00 := _proj(Vector2(x, y), _corner(w, x, y), W, hy)
			var c10 := _proj(Vector2(x + 1, y), _corner(w, x + 1, y), W, hy)
			var c11 := _proj(Vector2(x + 1, y + 1), _corner(w, x + 1, y + 1), W, hy)
			var c01 := _proj(Vector2(x, y + 1), _corner(w, x, y + 1), W, hy)
			if maxf(maxf(c00.x, c10.x), maxf(c11.x, c01.x)) < 0.0 or minf(minf(c00.x, c10.x), minf(c11.x, c01.x)) > W:
				continue
			if minf(minf(c00.y, c10.y), minf(c11.y, c01.y)) > H:
				continue
			var col: Color = WATER if code == "r" else (pal.get(code, pal["."]) as Color)
			if code == "r" and float(_d["temp"]) < -3.0:
				col = Color("#cfe0ea")   # ice
			# light from the south-west: slopes facing us are brighter, far land fades into haze
			var slope := (_corner(w, x, y) + _corner(w, x + 1, y)) - (_corner(w, x, y + 1) + _corner(w, x + 1, y + 1))
			col = col.lightened(clampf(slope * 0.25, 0.0, 0.25)).darkened(clampf(-slope * 0.3, 0.0, 0.3))
			if code != "r":
				col = col.lerp(Color("#f4f6f8"), cold * (0.6 if code in ["h", "k", "o", "x"] else 0.5))
			var fade := clampf(float(tl[0]) / float(MAX_DIST), 0.0, 1.0)
			col = col.lerp(Color("#9fb0c0"), fade * 0.55)
			if not Terrain.use_at(w, x, y).is_empty():
				col = col.lerp(Color("#d9b48a"), 0.35)   # built land
			draw_primitive(PackedVector2Array([c00, c10, c11, c01]), PackedColorArray([col, col, col, col]), PackedVector2Array())
			if code in ["f", "n"] and float(tl[0]) < 18.0:   # furrows and crop rows
				for k in 3:
					var t := (float(k) + 0.5) / 3.0
					draw_line(c00.lerp(c01, t), c10.lerp(c11, t), col.darkened(0.15), 1.0)


## Other settlements: little clusters of houses where they really stand.
func _draw_towns(W: float, hy: float) -> void:
	var r := _rng(3)
	for t in _d.get("towns", []):
		var tile: Vector2i = t["tile"]
		var base := _proj(Vector2(tile) + Vector2(0.5, 0.5), 0.0, W, hy)
		var dist := _fwd_side(Vector2(tile) + Vector2(0.5, 0.5)).x
		if dist < 2.0:
			continue
		var s := W * FOCAL * 0.45 / maxf(dist, 1.0)
		for k in int(t["size"]):
			var p := base + Vector2((float(k) - float(t["size"]) * 0.5) * s * 0.9 + r.randf_range(-s, s) * 0.3, -r.randf() * s * 0.5)
			_house(p, s * (0.7 + r.randf() * 0.4), Color("#efe1c0"), Color("#b0503a").lerp(Color("#6f4e37"), r.randf() * 0.5))


func _house(p: Vector2, s: float, wall: Color, roof: Color) -> void:
	draw_rect(Rect2(p.x - s * 0.5, p.y - s * 0.55, s, s * 0.55), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - s * 0.62, p.y - s * 0.5), Vector2(p.x, p.y - s * 1.05), Vector2(p.x + s * 0.62, p.y - s * 0.5)]), roof)


func _draw_smoke(W: float, hy: float) -> void:
	var sm := float(_d.get("smoke", 0.0))
	if sm < 5.0:
		return
	var r := _rng(4)
	for k in clampi(int(sm / 10.0), 1, 5):
		var x := W * (0.2 + r.randf() * 0.6)
		var y := hy + W * 0.02
		for b in 6:
			draw_circle(Vector2(x + b * W * 0.012, y - b * W * 0.022), W * (0.008 + b * 0.004), Color(0.55, 0.55, 0.55, clampf(sm / 120.0, 0.08, 0.35)))


## Landing's own rooftops in front of the window (the office is in town).
func _draw_rooftops(W: float, H: float) -> void:
	var r := _rng(5)
	var n := int(_d.get("roofs", 7))
	var snow := float(_d["temp"]) < 0.0
	for k in n:
		var cx := W * (float(k) + 0.5) / n + r.randf_range(-W * 0.02, W * 0.02)
		var s := W * (0.24 + r.randf() * 0.1)
		var base := H + s * (0.0 + r.randf() * 0.2)
		var roof := Color("#a5442f").lerp(Color("#5e4636"), r.randf() * 0.6)
		var pts := PackedVector2Array([Vector2(cx - s * 0.6, base), Vector2(cx - s * 0.35, base - s * 0.42), Vector2(cx + s * 0.35, base - s * 0.42), Vector2(cx + s * 0.6, base)])
		draw_primitive(pts, PackedColorArray([roof, roof, roof, roof]), PackedVector2Array())
		for t in 4:   # tile rows
			var ty := base - s * 0.42 * (float(t) + 0.5) / 4.0
			var half := s * (0.6 - 0.25 * (float(t) + 0.5) / 4.0)
			draw_line(Vector2(cx - half, ty), Vector2(cx + half, ty), roof.darkened(0.18), 1.0)
		draw_line(pts[1], pts[2], roof.darkened(0.3), maxf(1.0, s * 0.03))
		if snow:
			draw_colored_polygon(PackedVector2Array([pts[1], pts[2], pts[2] + Vector2(s * 0.06, s * 0.08), pts[1] + Vector2(-s * 0.06, s * 0.08)]), Color("#f2f4f6"))
		if r.randf() < 0.5:   # a chimney
			draw_rect(Rect2(cx + s * 0.15, base - s * 0.55, s * 0.08, s * 0.16), roof.darkened(0.35))


func _draw_weather(W: float, H: float) -> void:
	var rain := int(_d["rain"])
	var storm := int(_d["storm"])
	var r := _rng(6)
	var ph: Dictionary = _d.get("phenomena", {})
	if ph.has("SPORE_BLOOM"):   # a green shimmer in the air
		for k in 40:
			draw_circle(Vector2(r.randf() * W, r.randf() * H), W * 0.004, Color(0.6, 1.0, 0.5, 0.5))
	var wet := rain >= 130 or storm >= 1
	if not wet:
		return
	var n := clampi((rain - 100) / 2 + storm * 25, 20, 160)
	var snow := float(_d["temp"]) < 0.5
	for k in n:
		var p := Vector2(r.randf() * W, r.randf() * H)
		if snow:
			draw_circle(p, W * 0.004, Color(1, 1, 1, 0.85))
		else:
			draw_line(p, p + Vector2(-W * 0.012, W * 0.04), Color(0.85, 0.9, 1.0, 0.45), 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.55, 0.6, 0.68, clampf(float(rain - 100) / 400.0 + storm * 0.05, 0.0, 0.3)))
