class_name OfficeDesk3D
extends SubViewportContainer
## Terra (A44, user: a 3D office): the governor's office in 3D, seen from the chair. PLACEHOLDER primitives in the
## layout and scale of the "Modern Office 3D PBR" pack (1 unit = 1 m), every object a named node, so the OBJ models
## (game/assets/office3d) replace the meshes later without touching the logic.
## The same objects as the 2D desk (OfficeDesk), the same data (OfficeDesk.gather) and the same signal: clicking emits
## object_clicked(tab). Flat things that carry information (calendar, charter, newspaper, monitor screen, the view out
## of the window) are cut from a hidden render of the 2D desk, so both desks always show the same content.
## Seated camera: the view drifts gently with the mouse, and dragging looks further around.

signal object_clicked(tab: String)

## Clickable objects: node name -> [OfficeDesk spot, tab, tooltip]
const CLICK := {
	"Paper": ["paper", "Paper", "Today's paper and the press digest"],
	"InTray": ["tray", "Reports", "The in-tray: reports"],
	"Monitor": ["pc", "Inbox", "Your computer: the inbox"],
	"Phone": ["phone", "Calls", "The red phone"],
	"Calendar": ["calendar", "Calendar", "The wall calendar: the next twelve months"],
	"Door": ["door", "Visitors", "The door: visitors and interviews"],
	"Window": ["window", "Outside", "The window: the colony outside"],
}
const EYE := Vector3(0.0, 1.22, 0.9)
const LOOK_AT := Vector3(0.0, 1.0, -1.0)
const C_WOOD := Color("#8a5a35")
const C_WOOD_DARK := Color("#5f3c22")
const C_WALL := Color("#e9d8b8")

var session
var outside := "MAP":
	set(v):
		outside = v
		if _art != null:
			_art.outside = v
			_art.refresh()
var _vp: SubViewport
var _cam: Camera3D
var _scene: Node3D
var _art_vp: SubViewport
var _art: OfficeDesk
var _data := {}
var _hover := ""
var _hl: MeshInstance3D
var _yaw := 0.0
var _pitch := 0.0
var _yaw_t := 0.0
var _pitch_t := 0.0
var _drag := false
var _drag_moved := 0.0
var _t := 0.0
var _built := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(640, 360)


func refresh() -> void:
	if not _built:
		_build()
	_art.session = session
	_art.outside = outside
	_art.refresh()
	_data = _art.gather()
	_update_objects()


func gather() -> Dictionary:
	if not _built:
		_build()
	_art.session = session
	return _art.gather()


## The scene graph, by name (tests and the model swap use it).
func scene() -> Node3D:
	if not _built:
		_build()
	return _scene


# ------------------------------------------------------------------ building the room

func _build() -> void:
	_built = true
	# the 2D desk, rendered off-screen: source of the calendar, charter, paper, screen and window pictures
	_art_vp = SubViewport.new()
	_art_vp.size = Vector2i(1280, 720)
	_art_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_art = OfficeDesk.new()
	_art.size = Vector2(1280, 720)
	_art_vp.add_child(_art)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(1280, 720)
	add_child(_vp)
	_vp.add_child(_art_vp)   # inside the 3D viewport: the container's stretch would resize it otherwise
	_scene = Node3D.new()
	_scene.name = "Office"
	_vp.add_child(_scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1b1712")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#fff1dc")
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_scene.add_child(env)
	var sun := DirectionalLight3D.new()   # daylight through the window, from the left
	sun.rotation_degrees = Vector3(-35, -60, 0)
	sun.light_energy = 0.9
	sun.light_color = Color("#fff4e0")
	sun.shadow_enabled = true
	_scene.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.05
	_scene.add_child(_cam)
	_room()
	_window()
	_wall_things()
	_door()
	_desk()
	_desk_things()
	_hl = MeshInstance3D.new()
	_hl.name = "Highlight"
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.9, 0.5, 0.18)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hl.material_override = hm
	_hl.visible = false
	_scene.add_child(_hl)
	_place_camera()


func _mat(c: Color, rough := 0.8, emit := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
	return m


func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, col: Color, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(col, rough)
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, name: String, r_top: float, r_bot: float, h: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	mi.mesh = c
	mi.position = pos
	mi.material_override = _mat(col)
	parent.add_child(mi)
	return mi


## A flat picture cut from the 2D desk render (canvas rect), facing +z, `w` metres wide.
func _picture(parent: Node3D, name: String, region: Rect2, w: float, pos: Vector3, unshaded := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = Vector2(w, w * region.size.y / region.size.x)
	mi.mesh = q
	mi.position = pos
	var m := StandardMaterial3D.new()   # the region of the 2D desk render, by UV (atlas regions don't work in 3D)
	m.albedo_texture = _art_vp.get_texture()
	m.uv1_scale = Vector3(region.size.x / 1280.0, region.size.y / 720.0, 1.0)
	m.uv1_offset = Vector3(region.position.x / 1280.0, region.position.y / 720.0, 0.0)
	m.roughness = 0.9
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _node(name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	_scene.add_child(n)
	return n


func _room() -> void:
	var room := _node("Room")
	_box(room, "Floor", Vector3(5.6, 0.04, 4.0), Vector3(0, -0.02, -0.1), Color("#6b4a32"), 0.6)
	_box(room, "Rug", Vector3(2.6, 0.01, 1.8), Vector3(0, 0.005, 0.0), Color("#7a2e2a"), 1.0)
	_box(room, "BackWall", Vector3(5.6, 2.9, 0.06), Vector3(0, 1.45, -1.83), C_WALL)
	_box(room, "Wainscot", Vector3(5.6, 0.9, 0.04), Vector3(0, 0.45, -1.78), Color("#d4bf98"))
	_box(room, "LeftWall", Vector3(0.06, 2.9, 4.0), Vector3(-2.8, 1.45, -0.1), C_WALL.darkened(0.08))
	_box(room, "RightWall", Vector3(0.06, 2.9, 4.0), Vector3(2.8, 1.45, -0.1), C_WALL.darkened(0.08))
	_box(room, "Ceiling", Vector3(5.6, 0.04, 4.0), Vector3(0, 2.9, -0.1), Color("#f2eadb"))
	_box(room, "FileCabinet", Vector3(0.5, 1.3, 0.6), Vector3(-2.4, 0.65, -1.4), Color("#7d8288"), 0.5)
	for k in 4:   # binders on the cabinet
		_box(room, "Binder%d" % k, Vector3(0.07, 0.3, 0.26), Vector3(-2.58 + k * 0.09, 1.45, -1.4), [Color("#2f5d9c"), Color("#b8452f"), Color("#2f7a5c"), Color("#c9a34e")][k])


func _window() -> void:
	var win := _node("Window", Vector3(-1.2, 1.6, -1.79))
	var region: Rect2 = (OfficeDesk.SPOTS["window"][0] as Rect2).grow(-14)
	var glass := _picture(win, "Glass", region, 1.4, Vector3.ZERO, true)
	var h: float = (glass.mesh as QuadMesh).size.y
	_box(win, "FrameTop", Vector3(1.56, 0.08, 0.08), Vector3(0, h * 0.5 + 0.04, 0.02), C_WOOD_DARK)
	_box(win, "FrameBottom", Vector3(1.56, 0.08, 0.14), Vector3(0, -h * 0.5 - 0.04, 0.05), C_WOOD)
	_box(win, "FrameLeft", Vector3(0.08, h + 0.16, 0.08), Vector3(-0.74, 0, 0.02), C_WOOD_DARK)
	_box(win, "FrameRight", Vector3(0.08, h + 0.16, 0.08), Vector3(0.74, 0, 0.02), C_WOOD_DARK)
	_box(win, "CurtainLeft", Vector3(0.22, h + 0.5, 0.05), Vector3(-0.9, -0.1, 0.08), Color("#9c3d2e"), 1.0)
	_box(win, "CurtainRight", Vector3(0.22, h + 0.5, 0.05), Vector3(0.9, -0.1, 0.08), Color("#9c3d2e"), 1.0)
	var light := OmniLight3D.new()   # daylight spilling in
	light.name = "Daylight"
	light.position = Vector3(0, 0, 0.6)
	light.light_energy = 0.9
	light.omni_range = 3.5
	light.light_color = Color("#eaf2ff")
	win.add_child(light)


func _wall_things() -> void:
	var ch := _node("Charter", Vector3(0.12, 1.92, -1.795))
	_box(ch, "Frame", Vector3(0.62, 0.42, 0.03), Vector3(0, 0, -0.01), C_WOOD_DARK)
	_picture(ch, "Sheet", Rect2(490, 76, 180, 108), 0.54, Vector3(0, 0, 0.008))
	var cal := _node("Calendar", Vector3(0.98, 1.58, -1.795))
	_picture(cal, "Sheet", OfficeDesk.SPOTS["calendar"][0], 0.44, Vector3.ZERO)
	var clk := _node("WallClock", Vector3(1.3, 2.15, -1.79))
	var face := _cyl(clk, "Face", 0.15, 0.15, 0.03, Vector3.ZERO, Color("#fbf7ee"))
	face.rotation_degrees = Vector3(90, 0, 0)
	var rim := _cyl(clk, "Rim", 0.165, 0.165, 0.02, Vector3(0, 0, -0.01), C_WOOD_DARK)
	rim.rotation_degrees = Vector3(90, 0, 0)
	var hand := _box(clk, "Hand", Vector3(0.012, 0.1, 0.005), Vector3(0, 0.04, 0.02), Color("#2b2620"))
	hand.name = "Hand"
	var lbl := Label3D.new()
	lbl.name = "HoursLeft"
	lbl.position = Vector3(0, -0.24, 0.02)
	lbl.font_size = 40
	lbl.pixel_size = 0.0013
	lbl.modulate = Color("#2b2620")
	lbl.outline_size = 0
	clk.add_child(lbl)
	var frame := _node("PictureFrame", Vector3(-2.77, 1.7, -0.7))
	var pf := _box(frame, "Frame", Vector3(0.03, 0.4, 0.55), Vector3.ZERO, C_WOOD_DARK)
	pf.name = "Frame"
	_box(frame, "Art", Vector3(0.01, 0.32, 0.47), Vector3(0.02, 0, 0), Color("#6a8fb0"))


func _door() -> void:
	var door := _node("Door", Vector3(2.05, 0, -1.79))
	var way := MeshInstance3D.new()   # the doorway: the lit corridor shows when the door opens
	way.name = "Doorway"
	var q := QuadMesh.new()
	q.size = Vector2(0.92, 2.06)
	way.mesh = q
	way.position = Vector3(0, 1.03, 0.005)
	way.material_override = _mat(Color("#f6e7b5"), 1.0, Color("#6b5a30"))
	door.add_child(way)
	_box(door, "FrameLeft", Vector3(0.08, 2.14, 0.1), Vector3(-0.5, 1.07, 0.02), C_WOOD_DARK)
	_box(door, "FrameRight", Vector3(0.08, 2.14, 0.1), Vector3(0.5, 1.07, 0.02), C_WOOD_DARK)
	_box(door, "FrameTop", Vector3(1.08, 0.08, 0.1), Vector3(0, 2.1, 0.02), C_WOOD_DARK)
	var hinge := Node3D.new()   # the leaf swings on its left hinge
	hinge.name = "Hinge"
	hinge.position = Vector3(-0.46, 0, 0.04)
	door.add_child(hinge)
	var leaf := _box(hinge, "Leaf", Vector3(0.92, 2.04, 0.05), Vector3(0.46, 1.02, 0), C_WOOD)
	leaf.name = "Leaf"
	_cyl(hinge, "Handle", 0.03, 0.03, 0.06, Vector3(0.82, 1.0, 0.05), Color("#d9b44a")).rotation_degrees = Vector3(90, 0, 0)
	var vis := Node3D.new()   # someone waiting (a placeholder figure)
	vis.name = "Visitor"
	vis.position = Vector3(0.12, 0, 0.12)
	door.add_child(vis)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.45
	body.mesh = cap
	body.position = Vector3(0, 0.75, 0)
	body.material_override = _mat(Color("#3a3530"))
	vis.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	head.mesh = sp
	head.position = Vector3(0, 1.62, 0)
	head.material_override = _mat(Color("#3a3530"))
	vis.add_child(head)
	door.add_child(_badge("Badge", Vector3(0.3, 2.0, 0.1)))


func _badge(name: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.name = name
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.pixel_size = 0.0016
	l.outline_size = 34
	l.outline_modulate = Color("#d84a3a")
	l.modulate = Color.WHITE
	l.no_depth_test = true
	l.visible = false
	return l


func _desk() -> void:
	var desk := _node("Desk", Vector3(0, 0, -0.25))
	_box(desk, "Top", Vector3(1.7, 0.05, 0.85), Vector3(0, 0.75, 0), Color("#9b6a3f"), 0.55)
	_box(desk, "ModestyPanel", Vector3(1.6, 0.55, 0.03), Vector3(0, 0.45, -0.38), Color("#7e5331"))
	_box(desk, "PedestalLeft", Vector3(0.42, 0.72, 0.78), Vector3(-0.62, 0.36, 0), Color("#8a5d36"))
	_box(desk, "PedestalRight", Vector3(0.42, 0.72, 0.78), Vector3(0.62, 0.36, 0), Color("#8a5d36"))
	var plate := _node("NamePlate", Vector3(0, 0.79, 0.12))
	_box(plate, "Plate", Vector3(0.3, 0.05, 0.02), Vector3.ZERO, Color("#c9a34e"), 0.3).rotation_degrees = Vector3(-20, 0, 0)
	var pl := Label3D.new()
	pl.name = "Role"
	pl.position = Vector3(0, 0.002, 0.013)
	pl.rotation_degrees = Vector3(-20, 0, 0)
	pl.font_size = 40
	pl.pixel_size = 0.0011
	pl.modulate = Color("#3a2a1a")
	pl.outline_size = 0
	plate.add_child(pl)


func _desk_things() -> void:
	var top := 0.775
	var mon := _node("Monitor", Vector3(0.0, top, -0.5))
	_box(mon, "Stand", Vector3(0.06, 0.18, 0.06), Vector3(0, 0.09, 0), Color("#2b2d31"))
	_box(mon, "Base", Vector3(0.24, 0.015, 0.16), Vector3(0, 0.008, 0), Color("#2b2d31"))
	_box(mon, "Bezel", Vector3(0.52, 0.33, 0.03), Vector3(0, 0.34, 0), Color("#2b2d31"), 0.4)
	var r: Rect2 = OfficeDesk.SPOTS["pc"][0]
	var scr := _picture(mon, "Screen", Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, 170)), 0.48, Vector3(0, 0.34, 0.017), true)
	scr.name = "Screen"
	mon.add_child(_badge("Badge", Vector3(0.26, 0.52, 0.03)))
	_box(_node("Keyboard", Vector3(-0.08, top, -0.16)), "Body", Vector3(0.44, 0.02, 0.14), Vector3(0, 0.01, 0), Color("#3d4046"))
	_box(_node("Mouse", Vector3(0.24, top, -0.16)), "Body", Vector3(0.06, 0.025, 0.1), Vector3(0, 0.012, 0), Color("#3d4046"))
	_box(_node("Tower", Vector3(0.95, 0, -0.45)), "Case", Vector3(0.2, 0.45, 0.45), Vector3(0, 0.225, 0), Color("#2b2d31"))
	var tray := _node("InTray", Vector3(-0.56, top, -0.3))
	_box(tray, "Tray", Vector3(0.36, 0.04, 0.28), Vector3(0, 0.02, 0), Color("#4d4a45"))
	var stack := Node3D.new()
	stack.name = "Stack"
	tray.add_child(stack)
	tray.add_child(_badge("Badge", Vector3(0.16, 0.2, 0.1)))
	var paper := _node("Paper", Vector3(0.36, top + 0.004, 0.05))
	paper.rotation_degrees = Vector3(0, -8, 0)
	var pr: Rect2 = OfficeDesk.SPOTS["paper"][0]
	var sheet := _picture(paper, "Sheet", pr, 0.44, Vector3.ZERO)
	sheet.rotation_degrees = Vector3(-90, 0, 0)
	var phone := _node("Phone", Vector3(0.62, top, -0.32))
	_box(phone, "Body", Vector3(0.2, 0.07, 0.17), Vector3(0, 0.035, 0), Color("#b3261e"), 0.35)
	_box(phone, "Handset", Vector3(0.24, 0.045, 0.06), Vector3(0, 0.09, -0.02), Color("#c62f25"), 0.35)
	var dial := _cyl(phone, "Dial", 0.045, 0.045, 0.01, Vector3(0, 0.072, 0.045), Color("#f2ede1"))
	dial.name = "Dial"
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.position = Vector3(0, 0.2, 0.05)
	glow.light_color = Color("#ff5a40")
	glow.omni_range = 0.45
	glow.light_energy = 0.0
	phone.add_child(glow)
	phone.add_child(_badge("Badge", Vector3(0.12, 0.25, 0.05)))
	var lamp := _node("Lamp", Vector3(-0.72, top, -0.5))
	_cyl(lamp, "Base", 0.08, 0.09, 0.02, Vector3(0, 0.01, 0), Color("#2f3b33"))
	_box(lamp, "Arm", Vector3(0.02, 0.36, 0.02), Vector3(0, 0.19, 0.03), Color("#2f3b33")).rotation_degrees = Vector3(12, 0, 0)
	_cyl(lamp, "Shade", 0.05, 0.11, 0.12, Vector3(0, 0.38, 0.1), Color("#2e6b4f"))
	var bulb := SpotLight3D.new()
	bulb.name = "Bulb"
	bulb.position = Vector3(0, 0.36, 0.1)
	bulb.rotation_degrees = Vector3(-90, 0, 0)
	bulb.light_color = Color("#ffe2a8")
	bulb.light_energy = 1.4
	bulb.spot_range = 1.2
	bulb.spot_angle = 38.0
	lamp.add_child(bulb)
	var cup := _node("CoffeeCup", Vector3(-0.3, top, -0.05))
	_cyl(cup, "Cup", 0.04, 0.035, 0.09, Vector3(0, 0.045, 0), Color("#f2ede1"))
	_cyl(_node("Bin", Vector3(-1.05, 0, 0.1)), "Body", 0.14, 0.12, 0.32, Vector3(0, 0.16, 0), Color("#5d6166"))
	var pens := _node("Pens", Vector3(-0.38, top, -0.42))
	_cyl(pens, "Holder", 0.035, 0.035, 0.1, Vector3(0, 0.05, 0), Color("#2b2d31"))
	_box(_node("Stapler", Vector3(-0.2, top, -0.4)), "Body", Vector3(0.05, 0.04, 0.16), Vector3(0, 0.02, 0), Color("#8a1f1f"))


# ------------------------------------------------------------------ live state

func _update_objects() -> void:
	var d := _data
	var n_rep := int(d.get("reports", 0))
	var stack: Node3D = _scene.get_node("InTray/Stack")
	for c in stack.get_children():
		c.queue_free()
	var fresh := int(d.get("reports_new", 0))
	var shown := mini(n_rep, 14)
	for k in shown:
		_box(stack, "Sheet%d" % k, Vector3(0.3, 0.006, 0.22), Vector3(0.004 * (k % 3), 0.045 + k * 0.008, 0), Color("#ffffff") if k >= shown - fresh else Color("#e6dcc4"), 1.0)
	_set_badge("InTray/Badge", fresh)
	_set_badge("Monitor/Badge", int(d.get("inbox", 0)))
	_set_badge("Phone/Badge", int(d.get("calls", 0)))
	var vis := int(d.get("visitors", 0))
	_set_badge("Door/Badge", vis)
	(_scene.get_node("Door/Hinge") as Node3D).rotation_degrees = Vector3(0, 55.0 if vis > 0 else 0.0, 0)
	(_scene.get_node("Door/Visitor") as Node3D).visible = vis > 0
	(_scene.get_node("WallClock/HoursLeft") as Label3D).text = "%d hours left" % int(d.get("hours", 0))
	var hand: Node3D = _scene.get_node("WallClock/Hand")
	hand.rotation_degrees = Vector3(0, 0, -30.0 * float(posmod(int(d.get("hours", 0)), 12)))
	(_scene.get_node("NamePlate/Role") as Label3D).text = String(d.get("role", "Governor")).to_upper()


func _set_badge(path: String, n: int) -> void:
	var l: Label3D = _scene.get_node(path)
	l.visible = n > 0
	l.text = str(n)


func _process(delta: float) -> void:
	if not _built or not is_visible_in_tree():
		return
	_t += delta
	_yaw = lerpf(_yaw, _yaw_t, minf(1.0, delta * 4.0))
	_pitch = lerpf(_pitch, _pitch_t, minf(1.0, delta * 4.0))
	_place_camera()
	var glow: OmniLight3D = _scene.get_node("Phone/Glow")
	glow.light_energy = (0.45 + 0.35 * sin(_t * 6.0)) if int(_data.get("calls", 0)) > 0 else 0.0


func _place_camera() -> void:
	var dir := (LOOK_AT - EYE).normalized().rotated(Vector3.UP, _yaw)
	var right := dir.cross(Vector3.UP).normalized()
	dir = dir.rotated(right, _pitch)
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), EYE)


# ------------------------------------------------------------------ input and picking

func _gui_input(event: InputEvent) -> void:
	if not _built:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag:   # dragging looks around further
			_drag_moved += mm.relative.length()
			_yaw_t = clampf(_yaw_t - mm.relative.x * 0.004, -1.0, 1.0)
			_pitch_t = clampf(_pitch_t - mm.relative.y * 0.003, -0.45, 0.35)
		else:   # the gaze drifts gently towards the mouse
			var c := (mm.position / size - Vector2(0.5, 0.5)) * 2.0
			_yaw_t = lerpf(_yaw_t, -c.x * 0.22, 0.15)
			_pitch_t = lerpf(_pitch_t, -c.y * 0.12, 0.15)
		_set_hover(pick(mm.position))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				_drag = false
				if _drag_moved < 6.0:
					var hit := pick(mb.position)
					if hit != "":
						object_clicked.emit(String(CLICK[hit][1]))
						accept_event()


## Click an object by its 2D-desk name (tests, shot tool): paper, tray, pc, phone, calendar, door, window.
func click(obj: String) -> void:
	for k in CLICK:
		if CLICK[k][0] == obj:
			object_clicked.emit(String(CLICK[k][1]))


## The clickable object under a point of this control ("" = none): a ray from the camera against each object's box.
func pick(pos: Vector2) -> String:
	if not _built or size.x <= 0.0:
		return ""
	var vp_pos := pos * Vector2(_vp.size) / size
	var o := _cam.project_ray_origin(vp_pos)
	var d := _cam.project_ray_normal(vp_pos)
	var best := ""
	var bt := INF
	for k in CLICK:
		var box := _aabb(_scene.get_node(String(k)))
		var hit = box.intersects_ray(o, d)
		if hit != null:
			var t := (Vector3(hit) - o).length()
			if t < bt:
				bt = t
				best = k
	return best


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not (mi as MeshInstance3D).is_visible_in_tree() and mi.name != "Leaf":
			continue
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out.grow(0.02)


func _set_hover(k: String) -> void:
	if k == _hover:
		return
	_hover = k
	tooltip_text = String(CLICK[k][2]) if k != "" else ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if k != "" else Control.CURSOR_ARROW
	if k == "":
		_hl.visible = false
		return
	var b := _aabb(_scene.get_node(k))
	var bm := BoxMesh.new()
	bm.size = b.size
	_hl.mesh = bm
	_hl.position = b.get_center()
	_hl.visible = true
