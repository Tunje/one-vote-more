class_name PlanetView
extends Control
## Terra: the 3D globe. About 10 000 hex regions on smooth terrain (each centre and corner has its own height;
## oceans flat, mountain ranges rising continuously), coloured by biome, with the landing region marked. Drag to turn the globe, wheel to zoom, hover for info,
## click the landing region to open the colony map (signal colony_requested).
## Presentation only: reads Planet (world table "planet"); never writes the world.

signal colony_requested
signal cell_selected(cell: int)

const RELIEF := 0.0008         # radius per height step (heights reach ~95: peaks stand ~7% above the sea; exaggerated)
const EDGE_DARK := 0.1         # corner vertices this much darker: a faint hex grid
const BIOME_COLORS := {
	"D": Color("#173b6b"), "S": Color("#2d6aa3"), "I": Color("#e8f0f4"), "T": Color("#8c9a86"),
	"d": Color("#d8c07a"), "s": Color("#b5b06a"), "g": Color("#7fae55"), "f": Color("#5fa140"),
	"F": Color("#2f6b3a"), "j": Color("#1f7a4a"), "w": Color("#4f7a5e"), "h": Color("#8a8a55"),
	"H": Color("#7d6a4f"), "M": Color("#6b625c"), "P": Color("#f2f2f2"),
}

var session: GameSession
var _vp: SubViewport
var _cam: Camera3D
var _globe: MeshInstance3D
var _hover_mesh: MeshInstance3D
var _marker: Node3D
var _info: Label
var _built_for := ""           # planet signature the mesh was built for
var _yaw := 0.0
var _pitch := 0.3
var _dist := 3.0
var _dragging := false
var _drag_moved := 0.0
var _hover := -1
var _corner_h := PackedFloat32Array()   # display height per corner (geometry triangle)
var _weather_mesh: MeshInstance3D
var _weather_for := ""                  # month|planet the weather layer was built for
const CLOUD_R := 1.0 + RELIEF * 100.0   # storms drift above the highest peaks
const WEATHER_COLORS := {"CYCLONE": Color(1, 1, 1, 0.55), "RAIN_FRONT": Color(0.82, 0.86, 0.95, 0.45),
	"BLIZZARD": Color(0.85, 0.93, 1.0, 0.6), "DUST": Color(0.85, 0.68, 0.42, 0.5),
	"SPORE_BLOOM": Color(0.55, 0.95, 0.45, 0.45), "MOON_SURGE": Color(0.4, 0.75, 1.0, 0.55)}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.transparent_bg = false
	box.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#05070d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#4a5a78")
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.05
	_vp.add_child(_cam)
	# the sun rides with the camera (from upper left), so the side you look at is always lit
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.rotation = Vector3(deg_to_rad(-25), deg_to_rad(-62), 0)
	_cam.add_child(sun)
	_globe = MeshInstance3D.new()
	_vp.add_child(_globe)
	_hover_mesh = MeshInstance3D.new()
	_vp.add_child(_hover_mesh)
	_weather_mesh = MeshInstance3D.new()
	_vp.add_child(_weather_mesh)
	_vp.add_child(_stars())
	_vp.add_child(_atmosphere())
	_info = Label.new()
	_info.position = Vector2(12, 8)
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_shadow_color", Color.BLACK)
	_info.add_theme_constant_override("shadow_offset_x", 1)
	_info.add_theme_constant_override("shadow_offset_y", 1)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_place_camera()
	refresh()

## Rebuild the globe if the world's planet changed (new game / load); otherwise just update the label.
func refresh() -> void:
	if _vp == null:
		return
	if session == null or not Planet.ready(session.world()):
		_globe.mesh = null
		_info.text = "No planet yet."
		return
	var w := session.world()
	var sig := "%d|%d|%d" % [Planet.landing(w), Planet.freq(w), w.rng.derive_seed("planet.terrain")]
	if sig != _built_for:
		_built_for = sig
		_build_globe(w)
		focus_landing()
	if "%d|%s" % [w.month, sig] != _weather_for:
		_weather_for = "%d|%s" % [w.month, sig]
		_build_weather(w)
	_update_info()


## Turn the globe so the landing region faces the camera.
func focus_landing() -> void:
	var w := session.world()
	var c: Vector3 = Planet.geometry(Planet.freq(w))["centers"][Planet.landing(w)]
	_yaw = atan2(c.x, c.z)
	_pitch = asin(clampf(c.y, -1.0, 1.0))
	_place_camera()


func _place_camera() -> void:
	if _cam == null:
		return
	_pitch = clampf(_pitch, -1.45, 1.45)
	_dist = clampf(_dist, 1.15, 6.0)
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(_pitch) < 1.4 else Vector3.FORWARD), dir * _dist)


# ------------------------------------------------------------------ mesh

## Display radius of a (display) height: the sea is flat at radius 1, land rises above it.
func _r(h: float) -> float:
	return 1.0 + RELIEF * maxf(h, 0.0)


func _cell_color(code: String, h: int, i: int) -> Color:
	if h < 0 and code != "I":
		return BIOME_COLORS["S"].lerp(BIOME_COLORS["D"], clampf(-float(h) / 30.0, 0.0, 1.0))
	var col: Color = BIOME_COLORS.get(code, Color.MAGENTA)
	# small per-cell variation so neighbouring cells of one biome stay distinguishable
	return col.darkened(float(posmod(i * 7919, 7)) * 0.012)


## Smooth terrain: each cell is a fan from its centre (its own height) to its corners; a corner's height is the
## mean of the three cells meeting there, so slopes run continuously across cells. The corner vertices are a
## little darker, which draws the hex grid faintly.
func _build_globe(w: WorldState) -> void:
	var geo := Planet.geometry(Planet.freq(w))
	var cs: PackedVector3Array = geo["centers"]
	var tris: PackedInt32Array = geo["tris"]
	var hts := Planet.heights(w)
	var bio := Planet.biomes(w)
	var nt := tris.size() / 3
	_corner_h = PackedFloat32Array()
	_corner_h.resize(nt)
	var tn := PackedVector3Array()
	tn.resize(nt)
	for t in nt:
		var a := tris[3 * t]
		var b := tris[3 * t + 1]
		var c := tris[3 * t + 2]
		var ha := maxf(hts[a], 0.0)
		var hb := maxf(hts[b], 0.0)
		var hc := maxf(hts[c], 0.0)
		_corner_h[t] = (ha + hb + hc) / 3.0
		var pa := cs[a] * _r(ha)
		var nn := (cs[b] * _r(hb) - pa).cross(cs[c] * _r(hc) - pa).normalized()
		tn[t] = nn if nn.dot(pa) > 0.0 else -nn
	var surf := [_arrays(), _arrays()]   # 0 land, 1 water
	for i in cs.size():
		var s: Array = surf[1 if hts[i] < 0 else 0]
		var v: PackedVector3Array = s[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = s[Mesh.ARRAY_NORMAL]
		var co: PackedColorArray = s[Mesh.ARRAY_COLOR]
		var ix: PackedInt32Array = s[Mesh.ARRAY_INDEX]
		var col := _cell_color(bio.substr(i, 1), hts[i], i)
		var edge := col.darkened(EDGE_DARK)
		var poly: PackedVector3Array = geo["corners"][i]
		var ct: PackedInt32Array = geo["corner_tri"][i]
		var m := poly.size()
		var base := v.size()
		var cn := Vector3.ZERO
		for k in m:
			cn += tn[ct[k]]
		v.append(cs[i] * _r(hts[i]))
		nr.append(cn.normalized())
		co.append(col)
		for k in m:
			v.append(poly[k] * _r(_corner_h[ct[k]]))
			nr.append(tn[ct[k]])
			co.append(edge)
		for k in m:
			# corners run counter-clockwise seen from outside; Godot's front faces are clockwise
			ix.append(base)
			ix.append(base + 1 + (k + 1) % m)
			ix.append(base + 1 + k)
		s[Mesh.ARRAY_VERTEX] = v
		s[Mesh.ARRAY_NORMAL] = nr
		s[Mesh.ARRAY_COLOR] = co
		s[Mesh.ARRAY_INDEX] = ix
	var mesh := ArrayMesh.new()
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lm.roughness = 0.92
	var wm := StandardMaterial3D.new()
	wm.vertex_color_use_as_albedo = true
	wm.vertex_color_is_srgb = true
	wm.roughness = 0.6
	wm.metallic_specular = 0.3
	for k in 2:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf[k])
		mesh.surface_set_material(k, lm if k == 0 else wm)
	_globe.mesh = mesh
	_build_marker(w)
	_set_hover(-1)


func _arrays() -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	a[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	a[Mesh.ARRAY_COLOR] = PackedColorArray()
	a[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return a


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color) -> void:
	# Godot's front faces wind clockwise as seen: emit in whichever order faces along n
	var order: Array = [a, c, b] if (b - a).cross(c - a).dot(n) > 0.0 else [a, b, c]
	for p in order:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	_tri(st, a, b, c, n, col)
	_tri(st, a, c, d, n, col)


func _build_marker(w: WorldState) -> void:
	if _marker != null:
		_marker.queue_free()
	var li := Planet.landing(w)
	var c: Vector3 = Planet.geometry(Planet.freq(w))["centers"][li]
	_marker = Node3D.new()
	_vp.add_child(_marker)
	_marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, c)), c * _r(Planet.height(w, li)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffd75e")
	mat.emission_enabled = true
	mat.emission = Color("#ffb300")
	mat.emission_energy_multiplier = 1.6
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.0025
	cy.bottom_radius = 0.0025
	cy.height = 0.08
	pole.mesh = cy
	pole.position = Vector3(0, 0.04, 0)
	pole.material_override = mat
	_marker.add_child(pole)
	var flag := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.03, 0.018, 0.003)
	flag.mesh = bx
	flag.position = Vector3(0.016, 0.071, 0)
	flag.material_override = mat
	_marker.add_child(flag)
	var lbl := Label3D.new()
	lbl.text = "Landing"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0012
	lbl.fixed_size = true
	lbl.font_size = 22
	lbl.outline_size = 6
	lbl.position = Vector3(0, 0.1, 0)
	lbl.no_depth_test = true
	_marker.add_child(lbl)
	var ring := MeshInstance3D.new()   # permanent gold outline (in globe space, so not under the marker's basis)
	ring.mesh = _ring(w, li, Color("#ffcc33"), 0.6, 0.0015)
	ring.transform = _marker.transform.affine_inverse()
	_marker.add_child(ring)


## This month's storms and phenomena as translucent cloud bands over their tracks, and the colony's smoke as a
## brown haze drifting downwind (PlanetClimate, drawn in NATURE).
func _build_weather(w: WorldState) -> void:
	var geo := Planet.geometry(Planet.freq(w))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var pl := w.peek("planet")
	for k in pl.get("air", {}):
		var v := float(pl["air"][k]) / 1000.0
		if v >= 1.0:
			_blob(st, geo, int(k), 1.0 + RELIEF * 60.0, Color(0.45, 0.33, 0.2, clampf(v / 90.0, 0.08, 0.55)), 1.1)
			any = true
	for s in pl.get("storms", []) + pl.get("phenomena", []):
		if s.get("global", false):
			continue
		var col: Color = WEATHER_COLORS.get(String(s["kind"]), Color(1, 1, 1, 0.4))
		col.a = clampf(col.a * (0.6 + 0.15 * float(s["strength"])), 0.1, 0.85)
		var grow := 1.25 + 0.12 * float(s["strength"])
		for c in s["cells"]:
			_blob(st, geo, int(c), CLOUD_R, col, grow)
			any = true
	if not any:
		_weather_mesh.mesh = null
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_weather_mesh.mesh = st.commit()


## A soft hex-shaped blob over a cell (opaque centre fading to clear at the rim), `grow` times the cell's size.
func _blob(st: SurfaceTool, geo: Dictionary, i: int, radius: float, col: Color, grow: float) -> void:
	var c: Vector3 = geo["centers"][i]
	var poly: PackedVector3Array = geo["corners"][i]
	var m := poly.size()
	var clear := Color(col.r, col.g, col.b, 0.0)
	for k in m:
		var a := (c + (poly[k] - c) * grow).normalized() * radius
		var b := (c + (poly[(k + 1) % m] - c) * grow).normalized() * radius
		for pv in [[c * radius, col], [b, clear], [a, clear]]:
			st.set_color(pv[1])
			st.set_normal(c)
			st.add_vertex(pv[0])


func _set_hover(i: int) -> void:
	_hover = i
	if i < 0 or session == null:
		_hover_mesh.mesh = null
		return
	_hover_mesh.mesh = _ring(session.world(), i, Color.WHITE, 0.75, 0.0015)


## An outline ring following a cell's surface (inner edge at `inner` of the way from centre to corners).
func _ring(w: WorldState, i: int, col: Color, inner: float, lift: float) -> ArrayMesh:
	var geo := Planet.geometry(Planet.freq(w))
	var poly: PackedVector3Array = geo["corners"][i]
	var ct: PackedInt32Array = geo["corner_tri"][i]
	var c: Vector3 = geo["centers"][i]
	var cp := c * (_r(Planet.height(w, i)) + lift)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := poly.size()
	for k in m:
		var k2 := (k + 1) % m
		var a: Vector3 = poly[k] * (_r(_corner_h[ct[k]]) + lift)
		var b: Vector3 = poly[k2] * (_r(_corner_h[ct[k2]]) + lift)
		_quad(st, cp.lerp(a, inner), a, b, cp.lerp(b, inner), c, col)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	st.set_material(mat)
	return st.commit()


func _stars() -> MeshInstance3D:
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_POINTS)
	for _i in 900:
		var d := Vector3(r.randfn(), r.randfn(), r.randfn()).normalized()
		var b := r.randf_range(0.35, 1.0)
		im.surface_set_color(Color(b, b, b * 1.05))
		im.surface_add_vertex(d * 40.0)
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.use_point_size = true
	mat.point_size = 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = mat
	return mi


func _atmosphere() -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = vec3(0.35, 0.6, 1.0);
	ALPHA = pow(rim, 4.0) * 0.7;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sp := SphereMesh.new()
	sp.radius = 1.11
	sp.height = 2.22
	sp.radial_segments = 64
	sp.rings = 32
	var mi := MeshInstance3D.new()
	mi.mesh = sp
	mi.material_override = mat
	return mi


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist *= 0.92
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist *= 1.08
			_place_camera()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 4.0 and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(_pick(mb.position))
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_drag_moved += mm.relative.length()
			var k := 0.006 * (_dist - 1.0) / 2.0   # slower when zoomed in
			_yaw -= mm.relative.x * k
			_pitch += mm.relative.y * k
			_place_camera()
		else:
			var i := _pick(mm.position)
			if i != _hover:
				_set_hover(i)
				_update_info()


## Cell under a point of this control, or -1 (ray against the globe at mid-elevation).
func _pick(pos: Vector2) -> int:
	if session == null or not Planet.ready(session.world()):
		return -1
	var p := pos * Vector2(_vp.size) / size if size.x > 0 and size.y > 0 else pos
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	var R := 1.0 + RELIEF * 5.0
	var b := o.dot(d)
	var disc := b * b - (o.dot(o) - R * R)
	if disc < 0.0:
		return -1
	var hit := o + d * (-b - sqrt(disc))
	return Planet.cell_at(hit, Planet.freq(session.world()), maxi(_hover, 0))


func _click(i: int) -> void:
	if i < 0:
		return
	cell_selected.emit(i)
	if i == Planet.landing(session.world()):
		colony_requested.emit()


func _update_info() -> void:
	var w := session.world()
	var head := "Planet · %d regions · drag to turn, wheel to zoom" % Planet.cell_count(w)
	var pl := w.peek("planet")
	var n_storms: int = pl.get("storms", []).size()
	var notes: Array = ["%d storm%s this month" % [n_storms, "" if n_storms == 1 else "s"]]
	for p in pl.get("phenomena", []):
		if p["kind"] in ["SOLAR_FLARE", "MOON_SURGE"]:
			notes.append("%s (strength %d)" % [String(PlanetClimate.NAMES[p["kind"]]).capitalize(), int(p["strength"])])
	var warm := PlanetClimate.warming_c(w)
	if warm >= 0.01:
		notes.append("warming +%.2f °C" % warm)
	head += "\n" + " · ".join(notes)
	if _hover < 0:
		_info.text = head
		return
	var s := Planet.describe(w, _hover)
	var wx := PlanetClimate.weather(w, _hover)
	s += "\n%s: %.0f °C, rain %d%% of normal%s" % [String(wx["season"]).capitalize(), float(wx["temp_c"]), int(wx["rain_pct"]),
		(" · dry for %d months" % int(wx["drought_months"])) if int(wx["drought_months"]) > 0 else ""]
	for h in PlanetClimate.storms_at(w, _hover) + PlanetClimate.phenomena_at(w, _hover):
		s += " · %s (%d)" % [PlanetClimate.NAMES.get(h["kind"], h["kind"]), int(h["strength"])]
	var air := PlanetClimate.air_pollution(w, _hover)
	if air >= 1.0:
		s += " · smoke %.0f" % air
	if _hover == Planet.landing(w):
		s = "★ Landing site: the colony · " + s + "\nClick to open the colony map"
	_info.text = head + "\n" + s
