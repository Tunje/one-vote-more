class_name PlanetView
extends Control
## Terra: the 3D globe. Big hex regions extruded by elevation level (oceans flat, mountains tall), coloured by
## biome, with the landing region marked. Drag to turn the globe, wheel to zoom, hover for info,
## click the landing region to open the colony map (signal colony_requested).
## Presentation only: reads Planet (world table "planet"); never writes the world.

signal colony_requested
signal cell_selected(cell: int)

const STEP := 0.02            # radius per elevation level
const LAND_BASE := 0.008       # lowland sits this far above sea level
const INSET := 0.9             # hex top inset: the rim between INSET and 1.0 is drawn darker (crisp hex edges)
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
var _dist := 3.2
var _dragging := false
var _drag_moved := 0.0
var _hover := -1


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
	sun.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-35), 0)
	_cam.add_child(sun)
	_globe = MeshInstance3D.new()
	_vp.add_child(_globe)
	_hover_mesh = MeshInstance3D.new()
	_vp.add_child(_hover_mesh)
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
	var sig := "%d|%s|%s" % [Planet.landing(w), String(w.peek("planet")["elev"]).md5_text(), String(w.peek("planet")["biome"]).md5_text()]
	if sig != _built_for:
		_built_for = sig
		_build_globe(w)
		focus_landing()
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
	_dist = clampf(_dist, 1.6, 6.0)
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(_pitch) < 1.4 else Vector3.FORWARD), dir * _dist)


# ------------------------------------------------------------------ mesh

func _radius(level: int) -> float:
	return 1.0 if level < 0 else 1.0 + LAND_BASE + STEP * float(level)


func _build_globe(w: WorldState) -> void:
	var fq := Planet.freq(w)
	var geo := Planet.geometry(fq)
	var cs: PackedVector3Array = geo["centers"]
	var land := SurfaceTool.new()
	var water := SurfaceTool.new()
	land.begin(Mesh.PRIMITIVE_TRIANGLES)
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in cs.size():
		var lv := Planet.level(w, i)
		var st := water if lv < 0 else land
		var col: Color = BIOME_COLORS.get(Planet.biome(w, i), Color.MAGENTA)
		# small per-cell variation so neighbouring cells of one biome stay distinguishable
		col = col.darkened(float(posmod(i * 7919, 9)) * 0.012)
		var r := _radius(lv)
		var poly: PackedVector3Array = geo["corners"][i]
		var c: Vector3 = cs[i]
		var top := c * r
		var rim := col.darkened(0.22) if lv >= 0 else col.darkened(0.08)
		var m := poly.size()
		for k in m:
			var a: Vector3 = poly[k] * r
			var b: Vector3 = poly[(k + 1) % m] * r
			var ai := top.lerp(a, INSET)
			var bi := top.lerp(b, INSET)
			_tri(st, top, ai, bi, c, col)
			_quad(st, ai, a, b, bi, c, rim)
		# walls down to each lower neighbour
		var en: PackedInt32Array = geo["edge_nbr"][i]
		for k in m:
			var j := en[k]
			var rn := _radius(Planet.level(w, j)) if j >= 0 else 1.0
			if rn >= r:
				continue
			var a2: Vector3 = poly[k]
			var b2: Vector3 = poly[(k + 1) % m]
			var nrm := ((a2 + b2) * 0.5 - c).normalized()
			var wall := col.darkened(0.38)
			_quad(st, a2 * r, a2 * rn, b2 * rn, b2 * r, nrm, wall)
	var mesh := ArrayMesh.new()
	var lm := StandardMaterial3D.new()
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lm.roughness = 0.92
	var wm := StandardMaterial3D.new()
	wm.vertex_color_use_as_albedo = true
	wm.vertex_color_is_srgb = true
	wm.roughness = 0.4
	wm.metallic_specular = 0.45
	land.set_material(lm)
	water.set_material(wm)
	land.commit(mesh)
	water.commit(mesh)
	_globe.mesh = mesh
	_build_marker(w)
	_set_hover(-1)


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
	var base := c * _radius(Planet.level(w, li))
	_marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, c)), base)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffd75e")
	mat.emission_enabled = true
	mat.emission = Color("#ffb300")
	mat.emission_energy_multiplier = 1.6
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.0035
	cy.bottom_radius = 0.0035
	cy.height = 0.14
	pole.mesh = cy
	pole.position = Vector3(0, 0.07, 0)
	pole.material_override = mat
	_marker.add_child(pole)
	var flag := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.05, 0.03, 0.004)
	flag.mesh = bx
	flag.position = Vector3(0.027, 0.124, 0)
	flag.material_override = mat
	_marker.add_child(flag)
	var lbl := Label3D.new()
	lbl.text = "Landing"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0006
	lbl.font_size = 40
	lbl.outline_size = 10
	lbl.position = Vector3(0, 0.19, 0)
	lbl.no_depth_test = true
	_marker.add_child(lbl)
	var ring := MeshInstance3D.new()   # permanent gold outline (in globe space, so not under the marker's basis)
	ring.mesh = _ring(w, li, Color("#ffcc33"), 0.8, 0.001)
	ring.transform = _marker.transform.affine_inverse()
	_marker.add_child(ring)


func _set_hover(i: int) -> void:
	_hover = i
	if i < 0 or session == null:
		_hover_mesh.mesh = null
		return
	_hover_mesh.mesh = _ring(session.world(), i, Color.WHITE, 0.84, 0.002)


## An outline ring on a cell's top (inner edge at `inner` of the way to the corners).
func _ring(w: WorldState, i: int, col: Color, inner: float, lift: float) -> ArrayMesh:
	var geo := Planet.geometry(Planet.freq(w))
	var poly: PackedVector3Array = geo["corners"][i]
	var c: Vector3 = geo["centers"][i]
	var r := _radius(Planet.level(w, i)) + lift
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var m := poly.size()
	for k in m:
		var a: Vector3 = poly[k] * r
		var b: Vector3 = poly[(k + 1) % m] * r
		_quad(st, (c * r).lerp(a, inner), a, b, (c * r).lerp(b, inner), c, col)
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
			var k := 0.006 * (_dist - 0.9) / 2.3   # slower when zoomed in
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
	var R := 1.0 + LAND_BASE + STEP
	var b := o.dot(d)
	var disc := b * b - (o.dot(o) - R * R)
	if disc < 0.0:
		return -1
	var hit := o + d * (-b - sqrt(disc))
	return Planet.cell_at(hit, Planet.freq(session.world()))


func _click(i: int) -> void:
	if i < 0:
		return
	cell_selected.emit(i)
	if i == Planet.landing(session.world()):
		colony_requested.emit()


func _update_info() -> void:
	var w := session.world()
	var head := "Planet · %d regions · drag to turn, wheel to zoom" % Planet.cell_count(w)
	if _hover < 0:
		_info.text = head
		return
	var s := Planet.describe(w, _hover)
	if _hover == Planet.landing(w):
		s = "★ Landing site: the colony · " + s + "\nClick to open the colony map"
	_info.text = head + "\n" + s
