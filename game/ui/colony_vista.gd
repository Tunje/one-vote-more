class_name ColonyVista
extends Control
## TRUTHFUL (user: "if you don't settle there, will there be nothing?"): only what the colony has built is drawn —
## fields only where farms stand, plants where they stand, houses on their tiles, the built roads and bridges,
## landfills and cemeteries; the rest stays wild. No housing yet: Landing is a tent camp.
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
	# what stands where (facility tiles: A2 tiles, or the display placement before A2)
	var ft := ColonyLayout.facility_tiles(w)
	var fac: Dictionary = w.peek("facility")
	var things: Array = []   # [{kind, tile}] drawn as objects
	var farm := {}           # tile int -> true: farmed land (a farm and its fields around it)
	var land := Terrain.landing(w)
	var homes_here := 0
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty() or f.get("closed_m", 0) == null:
			continue
		var t: Vector2i = ft[fid]
		var ty := String(f["type"])
		things.append({"kind": ty, "tile": t, "fid": fid})
		if ty == "HOUSING" and maxi(absi(t.x - land.x), absi(t.y - land.y)) <= 4:
			homes_here += 1
		if ty == "FARM":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if Terrain.at(w, t.x + dx, t.y + dy) in ["f", "n", "."]:
						farm[(t.y + dy) * Terrain.W + t.x + dx] = true
	for k in w.peek("map").get("uses", {}):   # area housing tiles (after A2)
		var u: Dictionary = w.peek("map")["uses"][k]
		if String(u.get("area", "")) != "":
			things.append({"kind": "HOUSING", "tile": ColonyLayout.as_tile(k), "fid": ""})
	d["things"] = things
	d["farm"] = farm
	d["homes_here"] = homes_here
	var links: Array = []
	for l in Transport.network(w)["links"]:
		if int(l.get("globe", 0)) == 0:
			links.append({"path": l["path"], "kind": String(l["effective"])})
	d["links"] = links
	var waste := {}
	for ws in WasteMap.sites(w):
		for ti in ws["tiles"]:
			waste[int(ti)] = String(ws["kind"])
	d["waste"] = waste
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
	_draw_roads(w, W, H, hy)
	_draw_things(w, W, H, hy)
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
			var ti := y * Terrain.W + x
			var farmed: bool = _d["farm"].has(ti)
			var col: Color = WATER if code == "r" else (pal.get(code, pal["."]) as Color)
			if code == "f" and not farmed:   # fertile but wild: meadow, no fields
				col = (pal["."] as Color).lerp(Color("#6aa04a"), 0.35)
			elif code == "." and farmed:
				col = pal["f"]
			var wk := String(_d["waste"].get(ti, ""))
			if wk == "LANDFILL":
				col = Color("#8a7a62")
			elif wk == "CEMETERY":
				col = Color("#6f8a68")
			if code == "r" and float(_d["temp"]) < -3.0:
				col = Color("#cfe0ea")   # ice
			# light from the south-west: slopes facing us are brighter, far land fades into haze
			var slope := (_corner(w, x, y) + _corner(w, x + 1, y)) - (_corner(w, x, y + 1) + _corner(w, x + 1, y + 1))
			col = col.lightened(clampf(slope * 0.25, 0.0, 0.25)).darkened(clampf(-slope * 0.3, 0.0, 0.3))
			if code != "r":
				col = col.lerp(Color("#f4f6f8"), cold * (0.6 if code in ["h", "k", "o", "x"] else 0.5))
			var fade := clampf(float(tl[0]) / float(MAX_DIST), 0.0, 1.0)
			col = col.lerp(Color("#9fb0c0"), fade * 0.55)
			if not Terrain.use_at(w, x, y).is_empty() and wk == "":
				col = col.lerp(Color("#d9b48a"), 0.35)   # built land
			draw_primitive(PackedVector2Array([c00, c10, c11, c01]), PackedColorArray([col, col, col, col]), PackedVector2Array())
			if farmed and code != "r" and float(tl[0]) < 18.0:   # furrows and crop rows: only where a farm works the land
				for k in 3:
					var t := (float(k) + 0.5) / 3.0
					draw_line(c00.lerp(c01, t), c10.lerp(c11, t), col.darkened(0.15), 1.0)


## The built roads and tracks across the land, with plank bridges over the river.
func _draw_roads(w: WorldState, W: float, H: float, hy: float) -> void:
	var cols := {"TRACK": Color("#b8a07a"), "ROAD": Color("#9a9a9a"), "PAVED": Color("#d8d8d8")}
	for l in _d.get("links", []):
		var path: Array = l["path"]
		for i in range(1, path.size()):
			var a := Transport.int_tile(int(path[i - 1]))
			var b := Transport.int_tile(int(path[i]))
			var pa := Vector2(a) + Vector2(0.5, 0.5)
			var pb := Vector2(b) + Vector2(0.5, 0.5)
			var da := _fwd_side(pa).x
			var db := _fwd_side(pb).x
			if da < 1.2 or db < 1.2 or da > MAX_DIST:
				continue
			var sa := _proj(pa, maxf(_height(w, a.x, a.y), 0.0) + 0.02, W, hy)
			var sb := _proj(pb, maxf(_height(w, b.x, b.y), 0.0) + 0.02, W, hy)
			if (sa.x < -W and sb.x < -W) or (sa.x > 2.0 * W and sb.x > 2.0 * W) or (sa.y > H and sb.y > H):
				continue
			var wd := clampf(W * 0.05 / minf(da, db), 1.0, 7.0)
			var bridge := Terrain.at(w, b.x, b.y) == "r" or Terrain.at(w, a.x, a.y) == "r"
			if bridge:
				draw_line(sa, sb, Color("#5e4632"), wd * 2.2)
			draw_line(sa, sb, cols.get(String(l["kind"]), Color("#b8a07a")), wd)


## What the colony has built, far to near: houses, plants (mines with spoil heaps and headframes, works with stacks and
## smoke, waterworks, depots, farm barns, public buildings), cemetery graves.
func _draw_things(w: WorldState, W: float, H: float, hy: float) -> void:
	var items: Array = []
	for t in _d.get("things", []):
		var p := Vector2(t["tile"]) + Vector2(0.5, 0.5)
		var dist := _fwd_side(p).x
		if dist >= 2.0 and dist <= MAX_DIST:
			items.append([dist, t])
	for ti in _d.get("waste", {}):
		if _d["waste"][ti] == "CEMETERY":
			var tv := Transport.int_tile(int(ti))
			var dd := _fwd_side(Vector2(tv) + Vector2(0.5, 0.5)).x
			if dd >= 2.0 and dd <= MAX_DIST:
				items.append([dd, {"kind": "GRAVES", "tile": tv, "fid": ""}])
	items.sort_custom(func(a, b): return a[0] > b[0])
	var smoke := float(_d.get("smoke", 0.0))
	var r := _rng(3)
	for it in items:
		var t: Dictionary = it[1]
		var tile: Vector2i = t["tile"]
		var p := _proj(Vector2(tile) + Vector2(0.5, 0.5), maxf(_height(w, tile.x, tile.y), 0.0), W, hy)
		if p.x < -W * 0.1 or p.x > W * 1.1 or p.y > H + 10.0:
			continue
		var s := W * FOCAL * 0.42 / float(it[0])
		var fade := clampf(float(it[0]) / float(MAX_DIST), 0.0, 1.0) * 0.5
		var haze := func(c: Color) -> Color: return c.lerp(Color("#9fb0c0"), fade)
		match String(t["kind"]):
			"HOUSING":
				_house(p, s * (0.8 + r.randf() * 0.3), haze.call(Color("#efe1c0")), haze.call(Color("#b0503a").lerp(Color("#6f4e37"), r.randf() * 0.5)))
			"MINE":
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.9, 0), p + Vector2(-s * 0.3, -s * 0.55), p + Vector2(s * 0.2, -s * 0.5), p + Vector2(s * 0.7, 0)]), haze.call(Color("#6e6258")))
				var top := p + Vector2(s * 0.45, -s * 1.3)
				draw_line(p + Vector2(s * 0.2, 0), top, haze.call(Color("#3a3530")), maxf(1.0, s * 0.06))
				draw_line(p + Vector2(s * 0.7, 0), top, haze.call(Color("#3a3530")), maxf(1.0, s * 0.06))
				draw_arc(top, s * 0.16, 0.0, TAU, 12, haze.call(Color("#3a3530")), maxf(1.0, s * 0.04))
			"WATERWORKS":
				draw_rect(Rect2(p.x - s * 0.5, p.y - s * 0.35, s, s * 0.35), haze.call(Color("#9fb4c0")))
				draw_circle(p + Vector2(s * 0.2, -s * 0.45), s * 0.28, haze.call(Color("#7a9fb5")))
			"FARM":
				draw_rect(Rect2(p.x - s * 0.35, p.y - s * 0.45, s * 0.7, s * 0.45), haze.call(Color("#9c3d2e")))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.42, -s * 0.42), p + Vector2(0, -s * 0.75), p + Vector2(s * 0.42, -s * 0.42)]), haze.call(Color("#5e3a2a")))
			"DEPOT":
				draw_rect(Rect2(p.x - s * 0.8, p.y - s * 0.4, s * 1.6, s * 0.4), haze.call(Color("#a08a6a")))
				draw_rect(Rect2(p.x - s * 0.85, p.y - s * 0.48, s * 1.7, s * 0.1), haze.call(Color("#6e5e4a")))
			"CLINIC", "SCHOOL", "ADMIN", "SERVICEHUB":
				draw_rect(Rect2(p.x - s * 0.5, p.y - s * 0.55, s, s * 0.55), haze.call(Color("#f2ede1")))
				draw_rect(Rect2(p.x - s * 0.55, p.y - s * 0.62, s * 1.1, s * 0.09), haze.call(Color("#8a8a8a")))
			"GRAVES":
				for k in 3:
					var g := p + Vector2((float(k) - 1.0) * s * 0.35, -s * 0.05)
					draw_line(g, g + Vector2(0, -s * 0.25), haze.call(Color("#f4f2ea")), maxf(1.0, s * 0.04))
					draw_line(g + Vector2(-s * 0.07, -s * 0.18), g + Vector2(s * 0.07, -s * 0.18), haze.call(Color("#f4f2ea")), maxf(1.0, s * 0.04))
			_:   # works: a block with a saw-tooth roof and a stack (smoke as the air is fouled)
				draw_rect(Rect2(p.x - s * 0.7, p.y - s * 0.5, s * 1.4, s * 0.5), haze.call(Color("#8f8a84")))
				for k in 3:
					var x0 := p.x - s * 0.7 + float(k) * s * 0.466
					draw_colored_polygon(PackedVector2Array([Vector2(x0, p.y - s * 0.5), Vector2(x0 + s * 0.466, p.y - s * 0.5), Vector2(x0 + s * 0.466, p.y - s * 0.72)]), haze.call(Color("#6f6a64")))
				var st := Rect2(p.x + s * 0.35, p.y - s * 1.3, s * 0.14, s * 0.8)
				draw_rect(st, haze.call(Color("#5e5a56")))
				if smoke >= 1.0:
					for b in 5:
						draw_circle(Vector2(st.position.x + st.size.x * 0.5 + b * s * 0.12, st.position.y - b * s * 0.2), s * (0.1 + b * 0.05),
							Color(0.6, 0.6, 0.6, clampf(smoke / 100.0, 0.08, 0.4)))


func _house(p: Vector2, s: float, wall: Color, roof: Color) -> void:
	draw_rect(Rect2(p.x - s * 0.5, p.y - s * 0.55, s, s * 0.55), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - s * 0.62, p.y - s * 0.5), Vector2(p.x, p.y - s * 1.05), Vector2(p.x + s * 0.62, p.y - s * 0.5)]), roof)


## In front of the window: Landing's own roofs, as many as Landing has homes; without homes, the shelter camp's tents.
func _draw_rooftops(W: float, H: float) -> void:
	var r := _rng(5)
	var n := mini(int(_d.get("homes_here", 0)), 10)
	var tents := 0 if n >= 6 else (7 if n == 0 else 6 - n)
	for k in tents:   # tents and shelter modules of the landing camp, behind the first roofs
		var cx := W * (float(k) + 0.5) / maxf(1.0, float(tents)) + r.randf_range(-W * 0.03, W * 0.03)
		var s := W * (0.13 + r.randf() * 0.05)
		var base := H - W * 0.01 + r.randf() * W * 0.02
		var cloth := Color("#d9cfae").lerp(Color("#b8b09a"), r.randf())
		if k % 3 == 2:   # a ship module: a rounded shelter
			draw_rect(Rect2(cx - s * 0.6, base - s * 0.45, s * 1.2, s * 0.45), Color("#c7ccd0"))
			draw_circle(Vector2(cx - s * 0.6, base - s * 0.225), s * 0.225, Color("#c7ccd0"))
			draw_circle(Vector2(cx + s * 0.6, base - s * 0.225), s * 0.225, Color("#c7ccd0"))
			draw_rect(Rect2(cx - s * 0.1, base - s * 0.3, s * 0.2, s * 0.3), Color("#5a6066"))
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.55, base), Vector2(cx, base - s * 0.6), Vector2(cx + s * 0.55, base)]), cloth)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - s * 0.12, base), Vector2(cx, base - s * 0.3), Vector2(cx + s * 0.12, base)]), cloth.darkened(0.45))
			draw_line(Vector2(cx, base - s * 0.6), Vector2(cx, base - s * 0.72), Color("#5e4a36"), 1.5)
	var snow := float(_d["temp"]) < 0.0
	for k in n:
		var cx := W * (float(k) + 0.5) / maxf(1.0, float(n)) + r.randf_range(-W * 0.02, W * 0.02)
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
