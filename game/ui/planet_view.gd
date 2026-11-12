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
## The colony on the globe: the 64x40 colony map (ui ColonyMap's terrain, areas, facilities) laid on the landing hex.
const COLONY_FILL := 0.7       # half-width of the colony map, as a share of the hex's smallest centre-corner distance
const COLONY_LIFT := 0.0006    # above the terrain, below the gold rim
const COLONY_PX := 4           # texture pixels per colony tile (facilities: the inner 2x2)
const MARKER_HIDE_DIST := 1.5  # closer than this the colony map itself is readable: hide the flag pole
var _colony_mesh: MeshInstance3D
var _colony_for := ""
var _alert_mesh: MeshInstance3D
var _alert_t := 0.0
var _marker_lbl: Label3D
## Tourist sites (A42, PlanetSites): a glowing pin and a name on the globe; the colony's own sites on its map.
const SITE_COLORS := {"WATERFALL": Color("#7fd4ff"), "RIVER_FALLS": Color("#7fd4ff"), "CANYON": Color("#ff9a5a"),
	"GLOWING_FIELD": Color("#9dff6e"), "GLOW_MEADOW": Color("#9dff6e"), "AURORA_PLAIN": Color("#c99bff"),
	"TIDAL_BORE": Color("#5ab0ff"), "SUMMIT": Color("#ffffff"), "CRYSTAL_CRAGS": Color("#ff8ce0"),
	"FIRST_LANDING": Color("#ffd75e")}
const SITE_LABEL_DIST := 2.6   # globe site names show closer than this
var _sites: Node3D
var _site_for := ""
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
	_cam.near = 0.004   # close enough to read the colony map on its hex
	_cam.far = 30.0
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
	_colony_mesh = MeshInstance3D.new()
	_vp.add_child(_colony_mesh)
	_alert_mesh = MeshInstance3D.new()
	_alert_mesh.visible = false
	_vp.add_child(_alert_mesh)
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
	var sig := "%d|%d|%d" % [Planet.landing(w), Planet.freq(w), Planet.seed_of(w)]
	if sig != _built_for:
		_built_for = sig
		_build_globe(w)
		focus_landing()
	if "%d|%s" % [w.month, sig] != _weather_for:
		_weather_for = "%d|%s" % [w.month, sig]
		_build_weather(w)
	var csig := "%d|%s|%d|%d" % [w.month, sig, w.peek("area").size(), w.peek("facility").size()]
	if csig != _colony_for:
		_colony_for = csig
		_build_colony(w)
	var ssig := "%s|%s|%d|%d" % [sig, str(w.peek("map").get("grid", {}).get("landing", [])), w.month, int(w.peek("transport").get("rev", 0))]
	if ssig != _site_for:
		_site_for = ssig
		_build_sites(w)
	_update_colony_status(w)
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
	_dist = clampf(_dist, 1.04, 6.0)
	if _marker != null:
		for ch in _marker.get_children():
			if ch is MeshInstance3D and ch.mesh is not ArrayMesh:   # pole and flag (the rim is an ArrayMesh)
				ch.visible = _dist >= MARKER_HIDE_DIST
	if _sites != null:
		for ch in _sites.get_children():
			if ch.has_meta("colony"):
				ch.visible = _dist < MARKER_HIDE_DIST
			elif ch is Label3D:
				ch.visible = _dist < SITE_LABEL_DIST and ch.position.normalized().dot(_cam_dir()) > 0.35
	if _weather_mesh != null:
		_weather_mesh.transparency = clampf((1.8 - _dist) / 0.6, 0.0, 0.92)   # see the colony through the clouds up close
	var dir := _cam_dir()
	_cam.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP if absf(_pitch) < 1.4 else Vector3.FORWARD), dir * _dist)


func _cam_dir() -> Vector3:
	return Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))


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
	_site_for = ""


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
	var at := c * _r(Planet.height(w, li))
	if Terrain.ready(w):   # the flag stands on the landing site of the colony map laid on the hex
		at = colony_point(w, Vector2(Terrain.landing(w)) + Vector2(0.5, 0.5), 0.0)
	_marker.transform = Transform3D(Basis(Quaternion(Vector3.UP, at.normalized())), at)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#ffd75e")
	mat.emission_enabled = true
	mat.emission = Color("#ffb300")
	mat.emission_energy_multiplier = 1.6
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.0025
	cy.bottom_radius = 0.0025
	cy.height = 0.03
	pole.mesh = cy
	pole.position = Vector3(0, 0.015, 0)
	pole.material_override = mat
	_marker.add_child(pole)
	var flag := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(0.012, 0.008, 0.002)
	flag.mesh = bx
	flag.position = Vector3(0.0065, 0.026, 0)
	flag.material_override = mat
	_marker.add_child(flag)
	var lbl := Label3D.new()
	lbl.text = "The colony"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0012
	lbl.fixed_size = true
	lbl.font_size = 22
	lbl.outline_size = 6
	lbl.position = Vector3(0, 0.004, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.offset = Vector2(18, 0)       # beside the flag, not over the colony map
	lbl.outline_modulate = Color(0, 0, 0, 0.85)
	lbl.no_depth_test = true
	_marker.add_child(lbl)
	_marker_lbl = lbl
	var ring := MeshInstance3D.new()   # permanent gold outline (in globe space, so not under the marker's basis)
	ring.mesh = _ring(w, li, Color("#ffcc33"), 0.9 if Terrain.ready(w) else 0.6, 0.0015)
	ring.transform = _marker.transform.affine_inverse()
	_marker.add_child(ring)


# ------------------------------------------------------------------ tourist sites

func _build_sites(w: WorldState) -> void:
	if _sites != null:
		_sites.queue_free()
	_sites = Node3D.new()
	_vp.add_child(_sites)
	var geo := Planet.geometry(Planet.freq(w))
	var f := _hex_frame(w) if Terrain.ready(w) else {}
	var placed: Array = []
	for site in PlanetSites.sites(w):
		var col: Color = SITE_COLORS.get(site["kind"], Color.WHITE)
		var colony: bool = site["where"] == "COLONY"
		var at: Vector3
		if colony:
			if f.is_empty() or site["kind"] == "FIRST_LANDING":   # the flag already marks the landing site
				continue
			at = colony_point(w, Vector2(site["tile"]) + Vector2(0.5, 0.5), 0.0, f)
		else:
			var c: Vector3 = geo["centers"][int(site["cell"])]
			at = c * _r(maxi(Planet.height(w, int(site["cell"])), 0)) * 1.002
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.4
		var pin := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.0007 if colony else 0.005
		sp.height = sp.radius * 2.0
		sp.radial_segments = 10
		sp.rings = 5
		pin.mesh = sp
		pin.material_override = mat
		pin.position = at
		_sites.add_child(pin)
		if colony:   # the colony map names its own sights; up close a label would cover it
			pin.set_meta("colony", true)
			continue
		var lbl := Label3D.new()
		lbl.text = "%s (%d)" % [site["name"], int(site["attraction"])]
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.fixed_size = true
		lbl.pixel_size = 0.001
		lbl.font_size = 16
		lbl.outline_size = 5
		lbl.outline_modulate = Color(0, 0, 0, 0.85)
		lbl.modulate = col.lerp(Color.WHITE, 0.4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.offset = Vector2(10, 0)
		for other in placed:   # a neighbour's name already there: write this one below it
			if Vector3(other).angle_to(at) < 0.08:
				lbl.offset.y -= 20.0
		placed.append(at)
		lbl.position = at
		lbl.no_depth_test = true   # hills must not cut names; labels on the far side are hidden in _place_camera
		_sites.add_child(lbl)
	_build_routes(w)
	_place_camera()


## Globe roads (A43): built links from the landing hex to tourist sites, hex centre to hex centre.
func _build_routes(w: WorldState) -> void:
	var geo := Planet.geometry(Planet.freq(w))
	var cols := {"TRACK": Color("#c9a27a"), "ROAD": Color("#e0e0e0"), "PAVED": Color("#ffffff")}
	for l in Transport.network(w)["links"]:
		if int(l.get("globe", 0)) != 1:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_LINES)
		var col: Color = cols.get(String(l["effective"]), Color.WHITE)
		if String(l["closed"]) != "":
			col = Color("#ff4040")
		var cells: Array = l["cells"]
		for k in range(1, cells.size()):
			var a: Vector3 = geo["centers"][int(cells[k - 1])]
			var b: Vector3 = geo["centers"][int(cells[k])]
			for q in 4:   # follow the ground in four steps per hex
				var p0 := a.slerp(b, float(q) / 4.0)
				var p1 := a.slerp(b, float(q + 1) / 4.0)
				st.set_color(col)
				st.add_vertex(p0 * (_r(maxi(Planet.height(w, int(cells[k - 1 if q < 2 else k])), 0)) + 0.002))
				st.set_color(col)
				st.add_vertex(p1 * (_r(maxi(Planet.height(w, int(cells[k - 1 if q < 1 else k])), 0)) + 0.002))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		_sites.add_child(mi)


## How tourists reach a site this month (Transport.reachable_sites).
func _reach_text(w: WorldState, site_id: String) -> String:
	for r in Transport.reachable_sites(w):
		if r["id"] == site_id:
			match String(r["mode"]):
				"ROAD":
					return "by road, %d days" % maxi(1, int(r["time_days"]))
				"ROVER":
					return "by rover tour, %d days" % maxi(1, int(r["time_days"]))
				"AIRSHIP":
					return "by airship, %d days" % maxi(1, int(r["time_days"]))
			return "unreachable: no road, no rover base or airship mast" if String(r["usual"]) == "UNREACHABLE" else "closed by the weather this month"
	return ""


# ------------------------------------------------------------------ the colony on its hex

## The landing hex's tangent frame and fan (2D in the tangent plane) for laying the colony map on the terrain.
func _hex_frame(w: WorldState) -> Dictionary:
	var li := Planet.landing(w)
	var geo := Planet.geometry(Planet.freq(w))
	var c: Vector3 = geo["centers"][li]
	var east := Vector3.UP.cross(c)
	east = east.normalized() if east.length() > 0.0001 else Vector3.RIGHT
	var north := c.cross(east).normalized()
	var poly: PackedVector3Array = geo["corners"][li]
	var ct: PackedInt32Array = geo["corner_tri"][li]
	var pts := PackedVector2Array()
	var rads := PackedFloat32Array()
	var reach := INF
	for k in poly.size():
		var q := Vector2(poly[k].dot(east), poly[k].dot(north))
		pts.append(q)
		rads.append(_r(_corner_h[ct[k]]))
		reach = minf(reach, q.length())
	var hw := COLONY_FILL * reach
	return {"c": c, "east": east, "north": north, "pts": pts, "rads": rads, "rc": _r(maxf(Planet.height(w, li), 0.0)),
		"hw": hw, "hh": hw * float(Terrain.H) / float(Terrain.W)}


## Terrain radius at a tangent-plane point of the landing hex (barycentric in the fan triangle that holds it).
static func _surface_r(f: Dictionary, q: Vector2) -> float:
	var pts: PackedVector2Array = f["pts"]
	var rads: PackedFloat32Array = f["rads"]
	var m := pts.size()
	for k in m:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % m]
		var den := a.x * b.y - a.y * b.x
		if absf(den) < 1e-12:
			continue
		var u := (q.x * b.y - q.y * b.x) / den
		var v := (a.x * q.y - a.y * q.x) / den
		if u >= -1e-6 and v >= -1e-6 and u + v <= 1.0 + 1e-6:
			return float(f["rc"]) * (1.0 - u - v) + rads[k] * u + rads[(k + 1) % m] * v
	return float(f["rc"])


## Where a colony-map point (tile units, x east, y south) sits on the globe, `lift` above the terrain.
func colony_point(w: WorldState, g: Vector2, lift: float = COLONY_LIFT, f: Dictionary = {}) -> Vector3:
	if f.is_empty():
		f = _hex_frame(w)
	var q := Vector2((g.x / Terrain.W - 0.5) * 2.0 * float(f["hw"]), (0.5 - g.y / Terrain.H) * 2.0 * float(f["hh"]))
	var dir: Vector3 = (Vector3(f["c"]) + Vector3(f["east"]) * q.x + Vector3(f["north"]) * q.y).normalized()
	return dir * (_surface_r(f, q) + lift)


## The colony map as a texture: terrain, areas by kind, facilities (ColonyMap's colours), a faint tile grid.
static func colony_image(w: WorldState) -> Image:
	var px := COLONY_PX
	var img := Image.create(Terrain.W * px, Terrain.H * px, false, Image.FORMAT_RGBA8)
	var rows: Array = w.peek("map")["grid"]["rows"]
	var fac: Dictionary = w.peek("facility")
	var fac_col := {}
	var tiles := ColonyMap.facility_tiles(w)
	for fid in tiles:
		var st: Array = ColonyMap.FAC_STYLE.get(String(fac[fid]["type"]), ["", Color.WHITE])
		fac_col[Terrain.key(tiles[fid].x, tiles[fid].y)] = st[1]
	if AreaStore.areas(w).is_empty():   # before A2: the six settlements
		var an := ColonyMap.econ_anchors(w)
		for d in an:
			fac_col[Terrain.key(an[d].x, an[d].y)] = Color("#fff3b0")
	for y in Terrain.H:
		var row: String = rows[y]
		for x in Terrain.W:
			var c: Color = MapView.TERRAIN_COLORS.get(row.substr(x, 1), Color.GRAY)
			var area := String(Terrain.use_at(w, x, y).get("area", ""))
			if area != "":
				c = c.lerp(ColonyMap.KIND_COLORS.get(String(AreaStore.get_area(w, area).get("kind", "SETTLEMENT")), Color.WHITE), 0.75)
			var dot: Color = fac_col.get(Terrain.key(x, y), Color(0, 0, 0, 0))
			for yy in px:
				for xx in px:
					var cc := c
					if dot.a > 0.0 and xx >= 1 and yy >= 1 and xx <= px - 2 and yy <= px - 2:
						cc = dot
					img.set_pixel(x * px + xx, y * px + yy, cc)
	return img


## Lay the colony map on the landing hex: a grid mesh following the terrain, textured with colony_image.
func _build_colony(w: WorldState) -> void:
	if not Terrain.ready(w) or _corner_h.is_empty():
		_colony_mesh.mesh = null
		return
	var f := _hex_frame(w)
	var nx := 32
	var ny := 20
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for j in ny + 1:
		var row: Array = []
		for i in nx + 1:
			var g := Vector2(float(i) / nx * Terrain.W, float(j) / ny * Terrain.H)
			row.append([colony_point(w, g, COLONY_LIFT, f), Vector2(float(i) / nx, float(j) / ny)])
		grid.append(row)
	for j in ny:
		for i in nx:
			var a: Array = grid[j][i]
			var b: Array = grid[j][i + 1]
			var c: Array = grid[j + 1][i + 1]
			var d: Array = grid[j + 1][i]
			for v in [a, b, c, a, c, d]:   # clockwise seen from outside (Godot front faces)
				st.set_normal(Vector3(v[0]).normalized())
				st.set_uv(v[1])
				st.add_vertex(v[0])
	var mat := StandardMaterial3D.new()
	var img := colony_image(w)
	img.generate_mipmaps()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.9
	st.set_material(mat)
	_colony_mesh.mesh = st.commit()


## What the weather is doing to the colony this month: [{kind, strength}] (storms and phenomena over the landing hex).
static func colony_hits(w: WorldState) -> Array:
	var li := Planet.landing(w)
	return PlanetClimate.storms_at(w, li) + PlanetClimate.phenomena_at(w, li)


## The flag label (colonists, areas, weather now) and a pulsing warning rim when weather hits the colony.
func _update_colony_status(w: WorldState) -> void:
	var hits := colony_hits(w)
	if _marker_lbl != null:
		var n := PopStore.total(w)
		var t := "The colony"
		if n > 0:
			t += "\n%d colonists" % n
		var na := AreaStore.areas(w).size()
		if na > 0:
			t += " · %d area%s" % [na, "" if na == 1 else "s"]
		for h in hits.slice(0, 2):
			t += "\n%s (%d)" % [String(PlanetClimate.NAMES.get(h["kind"], h["kind"])).capitalize(), int(h["strength"])]
		_marker_lbl.text = t
		_marker_lbl.modulate = Color("#ffb38a") if not hits.is_empty() else Color.WHITE
	_alert_mesh.visible = not hits.is_empty()
	if _alert_mesh.visible:
		_alert_mesh.mesh = _ring(w, Planet.landing(w), Color("#ff3d1f"), 0.95, 0.0024)
	set_process(_alert_mesh.visible)


func _process(delta: float) -> void:
	if _alert_mesh == null or not _alert_mesh.visible:
		return
	_alert_t += delta
	_alert_mesh.transparency = 0.4 + 0.4 * sin(_alert_t * 4.0)


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
	var thin: bool = i == Planet.landing(session.world()) and Terrain.ready(session.world())   # don't cover the colony map
	_hover_mesh.mesh = _ring(session.world(), i, Color.WHITE, 0.93 if thin else 0.75, 0.0018)


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
	var hits := colony_hits(w)
	if not hits.is_empty():
		head += "\nOver the colony this month: " + ", ".join(hits.map(func(h): return "%s (strength %d)" % [
			String(PlanetClimate.NAMES.get(h["kind"], h["kind"])), int(h["strength"])]))
	var news: Array = w.facts.query("PLANET_", w.month - 1, w.month, "PUBLIC")
	news.reverse()
	for f in news.slice(0, 2):
		head += "\n• " + NewsText.sentence(w, f)
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
	for site in PlanetSites.at_cell(w, _hover):
		if site["where"] != "COLONY":
			s += "\n★ %s: %s · attraction %d · this month %d%% · %d km, %d days from the colony" % [site["name"],
				PlanetSites.KIND_NAMES[site["kind"]], int(site["attraction"]), PlanetSites.season_pct(w, site),
				int(site["km"]), int(site["travel_days"])]
			s += " · " + _reach_text(w, String(site["id"]))
	if _hover == Planet.landing(w):
		var local: Array = PlanetSites.at_cell(w, _hover).map(func(x): return String(x["name"]))
		s = "★ Landing site: the colony · " + s + ("\nSights: " + ", ".join(local) if not local.is_empty() else "") + "\nClick to open the colony map"
	_info.text = head + "\n" + s
