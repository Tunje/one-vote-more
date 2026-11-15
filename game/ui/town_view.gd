class_name TownView
extends Control
## Terra (the user via Wilma 2026-11-15: "Let her build it. I'll make some SketchUp models later ... we will have
## townships, low-poly ones with variety"): one town in 3D, opened from a settlement on the colony map (flag
## TOWN_GRID). Presentation only: reads TownGrid, ColonyLayout, Terrain and Transport; never writes the world.
## - 1 unit = 1 m; a town cell is 100 m × 100 m. Cell (fx, fy) has its north-west corner at
##   ((fx − centre.x) × 100, 0, (fy − centre.y) × 100): x east, z south, y up.
## - A building kind (HOUSE, APARTMENT, TOWER, SHOP, CLINIC, ...) is a slot: models in res://assets/town/<KIND>/
##   (*.glb, *.gltf) are used if there are any, else a low-poly placeholder of the slot's size. Several models give
##   variety: one is picked per building from its cell and lot, with a small turn and tint. See
##   planning/guide-town-models.md.
## - Houses: up to ten to a cell in two rows facing the streets on the cell's north and south edges; apartments: one
##   or two slabs; towers: one or two; a town building: one, facing south.
## - Hover a cell for what stands there and its location value (TownGrid.value) with its parts; click to keep it.

signal closed

const MODEL_DIR := "res://assets/town"
const CELL := 100.0
## Slots: size in m [width x, height y, depth z] (the placeholder's, and the most a model should take), colour.
const SLOTS := {
	"HOUSE": {"size": [10.0, 9.0, 9.0], "color": Color("#d9c7a3"), "roof": Color("#a5523f")},
	"APARTMENT": {"size": [48.0, 15.0, 16.0], "color": Color("#cfc6b8"), "roof": Color("#6f6a66")},
	"TOWER": {"size": [24.0, 50.0, 24.0], "color": Color("#b9c2c9"), "roof": Color("#5d666e")},
	"SHOP": {"size": [26.0, 6.0, 18.0], "color": Color("#e3b778"), "roof": Color("#7a6a5a")},
	"BAKERY": {"size": [14.0, 7.0, 12.0], "color": Color("#efd9a8"), "roof": Color("#9a5a3a")},
	"CLINIC": {"size": [40.0, 9.0, 26.0], "color": Color("#eef2f2"), "roof": Color("#c94c4c")},
	"SCHOOL": {"size": [56.0, 9.0, 34.0], "color": Color("#e8d07a"), "roof": Color("#7a6250")},
	"CARE": {"size": [30.0, 7.0, 20.0], "color": Color("#d8e4c4"), "roof": Color("#7c8a5a")},
	"OFFICE": {"size": [30.0, 15.0, 20.0], "color": Color("#a9b8c8"), "roof": Color("#58616b")},
	"POLICE": {"size": [26.0, 8.0, 18.0], "color": Color("#9fb0d0"), "roof": Color("#2f4a7a")},
	"WORKS": {"size": [70.0, 16.0, 50.0], "color": Color("#9a9184"), "roof": Color("#5b5650")},
	"DEPOT": {"size": [70.0, 10.0, 44.0], "color": Color("#b49a72"), "roof": Color("#6b5a44")},
	"MINE": {"size": [40.0, 22.0, 40.0], "color": Color("#7d6a58"), "roof": Color("#4a3e34")},
	"FARM": {"size": [16.0, 8.0, 12.0], "color": Color("#c9a77a"), "roof": Color("#8a3b2e")},
	"TREE": {"size": [8.0, 11.0, 8.0], "color": Color("#4f7a3a"), "roof": Color("#5a4632")},
}
## Facility types to slots (housing goes by its form; anything not listed that is a TOWN building is an OFFICE).
const TYPE_SLOT := {"RETAIL": "SHOP", "COMFORT": "SHOP", "BAKERY": "BAKERY", "FAMBAKERY": "BAKERY", "CLINIC": "CLINIC",
	"SCHOOL": "SCHOOL", "CHILDCARE": "CARE", "ELDERCARE": "CARE", "POLICE_STATION": "POLICE", "OFFICE": "OFFICE",
	"BIZSVC": "OFFICE", "SERVICEHUB": "OFFICE", "PUBJOBS": "OFFICE", "DEPOT": "DEPOT", "WAREHOUSE": "DEPOT",
	"TRANSIT": "DEPOT", "MINE": "MINE", "FARM": "FARM", "FAMFARM": "FARM"}
const GROUND := {".": Color("#8fb35a"), "f": Color("#6fa84a"), "n": Color("#7fbf8a"), "L": Color("#b5a77a"),
	"h": Color("#8c8a52"), "k": Color("#7d756c"), "o": Color("#8a6a4a"), "x": Color("#8a7a8f"), "r": Color("#79a86e"),
	"~": Color("#3f78ad")}
const WATER := Color("#4f86b8")
const ROAD_W := {"TRACK": 6.0, "ROAD": 8.0, "PAVED": 12.0}
const ROAD_COL := {"TRACK": Color("#9a8564"), "ROAD": Color("#6e6e6e"), "PAVED": Color("#454545")}
const STREET_W := 6.0
const STREET_COL := Color("#8a8a86")
const MARGIN := 15            # cells of country around the town in the fine window
const MIN_WINDOW := 40
const MAX_WINDOW := 140
const COUNTRY_R := 6          # 3 km tiles of coarse country drawn around the window
const TREE_PM := 120          # trees on this ‰ of empty country cells
const RIVER_W := 120.0

var session                   # GameSession (or any object with world())
var world_override: WorldState = null
var town := ""
var _vp: SubViewport
var _cam: Camera3D
var _content: Node3D
var _hover_mesh: MeshInstance3D
var _info: RichTextLabel
var _title: Label
var _layout := {}
var _ctx := {}
var _yaw := 0.6
var _pitch := 0.85
var _dist := 3000.0
var _target := Vector3.ZERO
var _drag := 0                # mouse button held (0 none)
var _drag_moved := 0.0
var _hover := Vector2i(-99999, -99999)
var _pinned := Vector2i(-99999, -99999)

static var model_dir := MODEL_DIR   # where the slot folders are (tests point it elsewhere)
static var _variants := {}    # kind -> [paths]
static var _templates := {}   # path -> Node3D (a loaded model, duplicated per building)
static var _tints := {}       # "<material id>|<tint>" -> Material


func _world() -> WorldState:
	if world_override != null:
		return world_override
	return session.world() if session != null else null


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
	box.add_child(_vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#4f8fd6")
	sm.sky_horizon_color = Color("#cfe6f7")
	sm.ground_horizon_color = Color("#cfe6f7")
	sm.ground_bottom_color = Color("#9a9a8c")
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("#cfe0ee")
	e.fog_density = 0.00002
	env.environment = e
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 6000.0
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-35), 0)
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.near = 2.0
	_cam.far = 60000.0
	_vp.add_child(_cam)
	_content = Node3D.new()
	_vp.add_child(_content)
	_hover_mesh = MeshInstance3D.new()
	_vp.add_child(_hover_mesh)
	# the bar on top and the cell panel on the right
	var bar := HBoxContainer.new()
	bar.position = Vector2(10, 8)
	add_child(bar)
	var back := Button.new()
	back.text = "◀ Colony map"
	back.pressed.connect(func(): closed.emit())
	bar.add_child(back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(_title)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -360
	panel.offset_top = 48
	panel.offset_bottom = -10
	panel.offset_right = -10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("normal_font_size", 13)
	_info.add_theme_font_size_override("bold_font_size", 13)
	panel.add_child(_info)
	if town != "":
		open_town(town)


## Show a town: rebuild the scene from the grid (the model folders are scanned again, so new models show).
func open_town(tid: String) -> void:
	town = tid
	_variants.clear()
	var w := _world()
	if w == null or _content == null:
		return
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_layout = layout(w, tid)
	_ctx = TownGrid._context(w)
	if _layout.is_empty():
		_title.text = "  No town grid here"
		_info.text = "This settlement has no town grid yet: it is still homes on its country tile."
		return
	_build(w)
	var ext: Vector3 = _layout["extent"]   # frame the town, not the whole window
	_dist = maxf(ext.x, ext.z) * 1.5 + 600.0
	_target = _layout["middle"]
	_place_camera()
	_title.text = "  %s — %d homes on %d cells" % [String(_layout["name"]), int(_layout["homes"]), int(_layout["cells"])]
	_info.text = overview_text(w, tid)


# ================================================================== plain data (tests read it)

## Which slot a building takes: housing by its form; town buildings by type; other works are WORKS.
static func slot_of(ftype: String, form: String = "") -> String:
	if ftype == "HOUSING":
		return form if form in ["HOUSE", "APARTMENT", "TOWER"] else "HOUSE"
	if TYPE_SLOT.has(ftype):
		return String(TYPE_SLOT[ftype])
	return "OFFICE" if Siting.kind_of(ftype) == "TOWN" else "WORKS"


## Everything the scene is built from, as plain data: {name, centre [fx, fy], window {x0, y0, w, h} (fine cells),
## homes, cells, items [{slot, pos Vector3, yaw (degrees), cell "fx,fy", fid, seed}], streets [[a, b]] (m),
## roads [[a, b, kind]], rivers [[a, b]], sea [tile Vector2i], fields [[centre, size]]}. {} without a grid. Pure.
static func layout(w: WorldState, tid: String) -> Dictionary:
	var t: Dictionary = w.peek("town").get("towns", {}).get(tid, {})
	if t.is_empty():
		return {}
	var c0 := Vector2i(int(t["c"][0]), int(t["c"][1]))
	var cells: Dictionary = t["cells"]
	var lo := c0
	var hi := c0
	for ck in cells:
		var c := ColonyLayout.as_tile(ck)
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var size := Vector2i(clampi(hi.x - lo.x + 1 + 2 * MARGIN, MIN_WINDOW, MAX_WINDOW), clampi(hi.y - lo.y + 1 + 2 * MARGIN, MIN_WINDOW, MAX_WINDOW))
	var mid := (lo + hi) / 2
	var win := {"x0": mid.x - size.x / 2, "y0": mid.y - size.y / 2, "w": size.x, "h": size.y}
	var name := tid
	for s in ColonyLayout.settlements(w):
		if String(s["id"]) == tid:
			name = String(s["name"])
	var fac: Dictionary = w.peek("facility")
	var items: Array = []
	var street := {}
	var homes := 0
	for ck in EconUtil.sorted_keys(cells):
		var row: Array = cells[ck]
		var c := ColonyLayout.as_tile(ck)
		var fid := String(row[0])
		var ftype := String(fac.get(fid, {}).get("type", "HOUSING"))
		var slot := slot_of(ftype, String(row[1]))
		var h := int(row[2])
		homes += h
		var o := _corner(c, c0)
		street["h|%d|%d" % [c.x, c.y]] = true          # the street on the cell's north edge
		street["h|%d|%d" % [c.x, c.y + 1]] = true      # ... and its south edge
		if posmod(c.x, 4) == 0:
			street["v|%d|%d" % [c.x, c.y]] = true      # a cross street every 400 m
		if posmod(c.x + 1, 4) == 0:
			street["v|%d|%d" % [c.x + 1, c.y]] = true
		for lot in _lots(slot, h):
			var lp: Vector3 = lot[0]
			items.append({"slot": slot, "pos": o + lp, "yaw": float(lot[1]), "cell": String(ck), "fid": fid,
				"seed": Planet._mix(Planet._mix(c.x & 0x7fffffff, c.y & 0x7fffffff), int(lot[2]))})
	var streets: Array = []
	for k in EconUtil.sorted_keys(street):
		var p := String(k).split("|")
		var x := int(p[1])
		var y := int(p[2])
		var a := _corner(Vector2i(x, y), c0)
		streets.append([a, a + (Vector3(CELL, 0, 0) if p[0] == "h" else Vector3(0, 0, CELL))])
	# the country: roads, rivers, the sea, buildings outside the town, trees
	var ct := TownGrid.tile_of(c0)
	var roads: Array = []
	var links := Transport._links(w)
	for lid in EconUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var path: Array = l.get("path", [])
		for i in range(1, path.size()):
			var ta := Transport.int_tile(int(path[i - 1]))
			var tb := Transport.int_tile(int(path[i]))
			if _near_tile(ta, ct) or _near_tile(tb, ct):
				roads.append([_tile_mid(ta, c0), _tile_mid(tb, c0), Transport.effective_kind(l, w)])
	var rivers: Array = []
	var sea: Array = []
	for dy in range(-COUNTRY_R, COUNTRY_R + 1):
		for dx in range(-COUNTRY_R, COUNTRY_R + 1):
			var tt := ct + Vector2i(dx, dy)
			var code := Terrain.at(w, tt.x, tt.y)
			if code == Terrain.SEA:
				sea.append(tt)
			elif code == "r":
				for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
					if Terrain.at(w, tt.x + d.x, tt.y + d.y) == "r":
						rivers.append([_tile_mid(tt, c0), _tile_mid(tt + d, c0)])
	var fields: Array = []
	var ft := ColonyLayout.facility_tiles(w)
	for fid in EconUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		var ty := String(f.get("type", ""))
		if f.is_empty() or ty == "HOUSING" or Siting.kind_of(ty) == "TOWN" or not TownGrid.cells_of(w, String(fid)).is_empty():
			continue
		var tl := ColonyLayout.as_tile(ft[fid])
		if not _near_tile(tl, ct):
			continue
		var slot2 := slot_of(ty)
		var mp := _tile_mid(tl, c0)
		if slot2 == "FARM":
			fields.append([mp, 700.0])
			mp += Vector3(-380.0, 0, 0)
		items.append({"slot": slot2, "pos": mp, "yaw": 0.0, "cell": "", "fid": String(fid), "seed": Planet._mix(tl.x, tl.y)})
	var salt := w.rng.derive_seed("town.view") & 0x7fffffff
	for y in range(int(win["y0"]), int(win["y0"]) + int(win["h"])):
		for x in range(int(win["x0"]), int(win["x0"]) + int(win["w"])):
			if cells.has("%d,%d" % [x, y]):
				continue
			var tl2 := TownGrid.tile_of(Vector2i(x, y))
			if not Terrain.at(w, tl2.x, tl2.y) in [".", "n", "h", "f"]:
				continue
			var r := Planet._mix(Planet._mix(salt, x & 0x7fffffff), y & 0x7fffffff)
			if r % 1000 < TREE_PM and not _on_street(street, x, y):
				var off := Vector3(20.0 + float(r % 60), 0, 20.0 + float((r / 60) % 60))
				items.append({"slot": "TREE", "pos": _corner(Vector2i(x, y), c0) + off, "yaw": float(r % 360), "cell": "", "fid": "", "seed": r})
	var lo_m := _corner(lo, c0)
	var hi_m := _corner(hi + Vector2i(1, 1), c0)
	return {"name": name, "centre": [c0.x, c0.y], "window": win, "homes": homes, "cells": cells.size(), "items": items,
		"middle": (lo_m + hi_m) / 2.0, "extent": hi_m - lo_m,
		"streets": streets, "roads": roads, "rivers": rivers, "sea": sea, "fields": fields}


static func _corner(c: Vector2i, c0: Vector2i) -> Vector3:
	return Vector3(float(c.x - c0.x) * CELL, 0.0, float(c.y - c0.y) * CELL)


static func _tile_mid(t: Vector2i, c0: Vector2i) -> Vector3:
	return _corner(Vector2i(t.x * TownGrid.PER_TILE + TownGrid.PER_TILE / 2, t.y * TownGrid.PER_TILE + TownGrid.PER_TILE / 2), c0)


static func _near_tile(t: Vector2i, ct: Vector2i) -> bool:
	return absi(t.x - ct.x) <= COUNTRY_R and absi(t.y - ct.y) <= COUNTRY_R


static func _on_street(street: Dictionary, x: int, y: int) -> bool:
	return street.has("h|%d|%d" % [x, y]) or street.has("h|%d|%d" % [x, y + 1])


## Where buildings stand in a cell: [[offset from the cell's NW corner, yaw degrees, lot number]].
## yaw 0: the front faces +z (south); 180: north.
static func _lots(slot: String, homes: int) -> Array:
	var out: Array = []
	match slot:
		"HOUSE":
			var n := clampi(homes, 1, 10)
			for i in n:   # alternate rows so a half-full cell has houses on both streets
				var row := i % 2
				var k := i / 2
				out.append([Vector3(10.0 + 20.0 * k, 0, 20.0 if row == 0 else 80.0), 180.0 if row == 0 else 0.0, i])
		"APARTMENT":
			var n2 := clampi(ceili(float(homes) / 30.0), 1, 2)
			for i in n2:
				out.append([Vector3(50.0, 0, 24.0 if i == 0 else 76.0), 180.0 if i == 0 else 0.0, i])
		"TOWER":
			var n3 := clampi(ceili(float(homes) / 100.0), 1, 2)
			for i in n3:
				out.append([Vector3(30.0 if n3 == 2 and i == 0 else (70.0 if n3 == 2 else 50.0), 0, 50.0), 0.0, i])
		_:
			out.append([Vector3(50.0, 0, 55.0), 0.0, 0])
	return out


## The models dropped into a slot's folder (sorted), [] if none.
static func variants(slot: String) -> Array:
	if _variants.has(slot):
		return _variants[slot]
	var out: Array = []
	var d := DirAccess.open(model_dir + "/" + slot)
	if d != null:
		for f in d.get_files():
			var lf := f.to_lower()
			if lf.ends_with(".glb") or lf.ends_with(".gltf"):
				out.append(model_dir + "/" + slot + "/" + f)
	out.sort()
	_variants[slot] = out
	return out


## What a hovered cell is: what stands there (or why nothing can), and its location value with the parts. Pure.
static func cell_text(w: WorldState, tid: String, cell: Vector2i, ctx: Dictionary = {}) -> String:
	if ctx.is_empty():
		ctx = TownGrid._context(w)
	var ck := "%d,%d" % [cell.x, cell.y]
	var tl := TownGrid.tile_of(cell)
	var code := Terrain.at(w, tl.x, tl.y)
	var t := "[b]Cell %s[/b] · %s (tile %d,%d)\n" % [ck, String(Terrain.NAMES.get(code, code)), tl.x, tl.y]
	var idx: Dictionary = TownGrid._index(w)["cells"]
	if idx.has(ck):
		var row: Array = idx[ck]
		var f: Dictionary = w.peek("facility").get(String(row[0]), {})
		var ty := String(f.get("type", ""))
		if ty == "HOUSING":
			var org: Dictionary = w.peek("org").get(String(f.get("org", "")), {})
			t += "%s: %d home%s (block %s, %s)\n" % [String(row[1]).capitalize(), int(row[2]), "" if int(row[2]) == 1 else "s",
				String(row[0]), String(org.get("name", "?"))]
			t += "Connection: %d m of street, pipe and cable a home\n" % TownGrid.connection_m(w, String(row[0]))
		else:
			t += "%s (%s)\n" % [ty.capitalize().replace("_", " "), String(row[0])]
	else:
		var why := TownGrid.blocked(w, cell, "HOUSING", ctx)
		t += "Empty: %s\n" % ("free for homes" if why == "" else why)
		var use := Siting.use_at(w, tl) if Siting.on(w) else ""
		if use != "":
			t += "Reserved for %s\n" % use.to_lower()
	var v := TownGrid.value(w, cell, ctx)
	t += "\n[b]Location value %d[/b] (1000 = an ordinary cell)\n" % int(v["value_pm"])
	var parts: Dictionary = v["parts"]
	var keys: Array = parts.keys()
	keys.sort_custom(func(a, b): return absf(float(parts[a])) > absf(float(parts[b])))
	for k in keys:
		var x := float(parts[k])
		if absf(x) < 0.05:
			continue
		t += "  %s %s%.1f\n" % [String(PART_NAMES.get(k, k)), "+" if x >= 0.0 else "−", absf(x)]
	return t


const PART_NAMES := {"jobs": "jobs near", "school": "a school near", "clinic": "a clinic near", "shops": "shops and bakeries",
	"utilities": "water and power laid", "view": "a view of the water", "water": "the shore near", "road": "a road near",
	"fast_road": "a fast road beside it", "industry": "works next door"}


static func overview_text(w: WorldState, tid: String) -> String:
	var t := "[b]%s[/b]\n" % tid
	var forms := {}
	var cs: Dictionary = w.peek("town").get("towns", {}).get(tid, {}).get("cells", {})
	for ck in cs:
		var fm := String(cs[ck][1]) if String(cs[ck][1]) != "" else "town building"
		forms[fm] = int(forms.get(fm, 0)) + 1
	for fm in EconUtil.sorted_keys(forms):
		t += "%s: %d cell%s\n" % [String(fm).capitalize(), int(forms[fm]), "" if int(forms[fm]) == 1 else "s"]
	t += "Allowed forms: %s\n" % ", ".join(TownGrid.forms_allowed(w, tid))
	var models := 0
	for s in SLOTS:
		models += variants(String(s)).size()
	t += "\nModels loaded: %d (placeholders for the rest; see planning/guide-town-models.md)\n" % models
	t += "\nHover a cell for what stands there and what a home there is worth. Click to keep it.\n"
	t += "Left-drag turns, right-drag pans, the wheel zooms."
	return t


# ================================================================== the scene

func _build(w: WorldState) -> void:
	var c0 := Vector2i(int(_layout["centre"][0]), int(_layout["centre"][1]))
	_content.add_child(_ground(w, c0))
	var flat := SurfaceTool.new()
	flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in _layout["sea"]:
		var a := _tile_mid(s, c0) - Vector3(1500, 0, 1500)
		_quad(flat, a + Vector3(0, 0.6, 0), Vector3(3000, 0, 0), Vector3(0, 0, 3000), WATER)
	for r in _layout["rivers"]:
		_ribbon(flat, r[0], r[1], RIVER_W, 0.7, WATER)
	for fd in _layout["fields"]:
		var fc: Vector3 = fd[0]
		var fs := float(fd[1])
		for i in 6:   # strips of crop
			var col := Color("#c9b35a") if i % 2 == 0 else Color("#9fb54a")
			_quad(flat, fc + Vector3(-fs / 2.0 + fs / 6.0 * i, 0.4, -fs / 2.0), Vector3(fs / 6.0, 0, 0), Vector3(0, 0, fs), col)
	for r in _layout["roads"]:
		_ribbon(flat, r[0], r[1], float(ROAD_W.get(String(r[2]), 8.0)), 1.2, ROAD_COL.get(String(r[2]), Color.DIM_GRAY))
	for s in _layout["streets"]:
		_ribbon(flat, s[0], s[1], STREET_W, 1.0, STREET_COL)
	var mi := MeshInstance3D.new()
	mi.mesh = flat.commit()
	mi.material_override = _vc_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_content.add_child(mi)
	# buildings: models where a slot has them, else placeholders in one mesh
	var ph := SurfaceTool.new()
	ph.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it in _layout["items"]:
		var slot := String(it["slot"])
		var vs := variants(slot)
		var seed_v := int(it["seed"])
		var yaw := float(it["yaw"]) + float(seed_v % 9 - 4)   # a small turn
		var tint := 0.92 + 0.04 * float((seed_v / 9) % 5)     # 0.92 .. 1.08
		if not vs.is_empty():
			var node := _model(String(vs[seed_v % vs.size()]))
			if node != null:
				node.position = it["pos"]
				node.rotation.y = deg_to_rad(yaw)
				_tint(node, (seed_v / 9) % 5)
				_content.add_child(node)
				continue
		_placeholder(ph, slot, it["pos"], yaw, tint)
	var pm := MeshInstance3D.new()
	pm.mesh = ph.commit()
	pm.material_override = _vc_material()
	_content.add_child(pm)


func _ground(w: WorldState, c0: Vector2i) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ct := TownGrid.tile_of(c0)
	for dy in range(-COUNTRY_R, COUNTRY_R + 1):   # the country, coarse and a little lower
		for dx in range(-COUNTRY_R, COUNTRY_R + 1):
			var tt := ct + Vector2i(dx, dy)
			var col: Color = GROUND.get(Terrain.at(w, tt.x, tt.y), GROUND["."])
			_quad(st, _tile_mid(tt, c0) - Vector3(1500, 0.5, 1500), Vector3(3000, 0, 0), Vector3(0, 0, 3000), col)
	var win: Dictionary = _layout["window"]
	for y in range(int(win["y0"]), int(win["y0"]) + int(win["h"])):
		for x in range(int(win["x0"]), int(win["x0"]) + int(win["w"])):
			var tl := TownGrid.tile_of(Vector2i(x, y))
			var code := Terrain.at(w, tl.x, tl.y)
			var col2: Color = GROUND.get(code, GROUND["."])
			var j := float(Planet._mix(x & 0x7fffffff, y & 0x7fffffff) % 9 - 4) * 0.012
			_quad(st, _corner(Vector2i(x, y), c0), Vector3(CELL, 0, 0), Vector3(0, 0, CELL), col2.lightened(j) if j > 0.0 else col2.darkened(-j))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _vc_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _vc_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	m.metallic_specular = 0.15
	return m


## A flat quad from corner a along u and v, facing up.
static func _quad(st: SurfaceTool, a: Vector3, u: Vector3, v: Vector3, col: Color) -> void:
	_face(st, [a, a + u, a + u + v, a + v], col, a + (u + v) / 2.0 - Vector3(0, 10, 0))


static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, width: float, lift: float, col: Color) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var side := Vector3(-d.z, 0, d.x).normalized() * (width / 2.0)
	var y := Vector3(0, lift, 0)
	var a0 := a - side + y
	_quad(st, a0, d, side * 2.0, col)


## A box with walls and a flat or gabled top, turned by yaw, standing on pos (its footprint's centre).
static func _placeholder(st: SurfaceTool, slot: String, pos: Vector3, yaw: float, tint: float) -> void:
	var sp: Dictionary = SLOTS.get(slot, SLOTS["OFFICE"])
	var sz: Array = sp["size"]
	var wall: Color = (sp["color"] as Color) * tint
	wall.a = 1.0
	var roof: Color = sp["roof"]
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	match slot:
		"TREE":
			var h := float(sz[1])
			_prism(st, pos, basis, 1.2, 3.0, 1.2, roof)
			_cone(st, pos + Vector3(0, 3.0, 0), float(sz[0]) / 2.0, h - 3.0, (sp["color"] as Color) * tint)
		"HOUSE", "BAKERY", "FARM", "CARE":
			var hw := float(sz[1]) * 0.62
			_prism(st, pos, basis, float(sz[0]), hw, float(sz[2]), wall)
			_gable(st, pos + Vector3(0, hw, 0), basis, float(sz[0]) + 1.0, float(sz[1]) - hw, float(sz[2]) + 1.0, roof)
		"MINE":
			_prism(st, pos, basis, float(sz[0]), 8.0, float(sz[2]), wall)
			_prism(st, pos + basis * Vector3(8, 8, 0), basis, 6.0, float(sz[1]) - 8.0, 6.0, roof)
		_:
			_prism(st, pos, basis, float(sz[0]), float(sz[1]), float(sz[2]), wall)
			_prism(st, pos + Vector3(0, float(sz[1]), 0), basis, float(sz[0]) * 0.96, 0.8, float(sz[2]) * 0.96, roof)


## An upright box of w × h × d on pos (footprint centre), flat-shaded, without a bottom.
static func _prism(st: SurfaceTool, pos: Vector3, basis: Basis, w: float, h: float, d: float, col: Color) -> void:
	var hx := w / 2.0
	var hz := d / 2.0
	var c: Array = []
	for p in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
		c.append(pos + basis * p)
	var up := Vector3(0, h, 0)
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		_face(st, [a, b, b + up, a + up], col.darkened(0.08 * float(i % 2)), pos + up / 2.0)
	_face(st, [c[0] + up, c[1] + up, c[2] + up, c[3] + up], col.lightened(0.06), pos + up / 2.0)


## A pitched roof over w × d at pos (eaves height), ridge along x, rising h.
static func _gable(st: SurfaceTool, pos: Vector3, basis: Basis, w: float, h: float, d: float, col: Color) -> void:
	var hx := w / 2.0
	var hz := d / 2.0
	var p := func(v: Vector3) -> Vector3: return pos + basis * v
	var a: Vector3 = p.call(Vector3(-hx, 0, -hz))
	var b: Vector3 = p.call(Vector3(hx, 0, -hz))
	var c: Vector3 = p.call(Vector3(hx, 0, hz))
	var dd: Vector3 = p.call(Vector3(-hx, 0, hz))
	var r1: Vector3 = p.call(Vector3(-hx, h, 0))
	var r2: Vector3 = p.call(Vector3(hx, h, 0))
	var inside := pos + Vector3(0, h * 0.3, 0)
	_face(st, [b, a, r1, r2], col, inside)
	_face(st, [dd, c, r2, r1], col.darkened(0.12), inside)
	_face(st, [a, dd, r1], col.darkened(0.2), inside)
	_face(st, [c, b, r2], col.darkened(0.2), inside)


static func _cone(st: SurfaceTool, pos: Vector3, r: float, h: float, col: Color) -> void:
	var top := pos + Vector3(0, h, 0)
	for i in 6:
		var a0 := TAU * float(i) / 6.0
		var a1 := TAU * float(i + 1) / 6.0
		_face(st, [pos + Vector3(cos(a0) * r, 0, sin(a0) * r), pos + Vector3(cos(a1) * r, 0, sin(a1) * r), top], col.darkened(0.05 * float(i % 3)),
			pos + Vector3(0, h * 0.3, 0))


## A flat-shaded polygon (3 or 4 points, in order around it): its normal points away from `inside`, and it is wound
## clockwise seen from that side (Godot's front face).
static func _face(st: SurfaceTool, pts: Array, col: Color, inside: Vector3) -> void:
	var a: Vector3 = pts[0]
	var b: Vector3 = pts[1]
	var c: Vector3 = pts[2]
	var n := (b - a).cross(c - a).normalized()
	var flip := n.dot(a - inside) < 0.0
	if flip:
		n = -n
	for tri in ([[0, 1, 2]] if pts.size() == 3 else [[0, 1, 2], [0, 2, 3]]):
		var order: Array = [tri[0], tri[1], tri[2]] if flip else [tri[0], tri[2], tri[1]]
		for k in order:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(pts[k])


# ================================================================== models

func _model(path: String) -> Node3D:
	if not _templates.has(path):
		var node: Node3D = null
		if ResourceLoader.exists(path):
			var ps = load(path)
			if ps is PackedScene:
				node = (ps as PackedScene).instantiate() as Node3D
		if node == null:   # not imported yet (dropped in while the game runs): read the file directly
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			if doc.append_from_file(ProjectSettings.globalize_path(path), state) == OK:
				node = doc.generate_scene(state) as Node3D
		_templates[path] = node
	var tpl: Node3D = _templates[path]
	return tpl.duplicate() as Node3D if tpl != null else null


## Tint a model's materials (one of five levels, 0.92 .. 1.08); materials are shared per level.
func _tint(node: Node, level: int) -> void:
	if level == 2:
		return
	var f := 0.92 + 0.04 * float(level)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null:
			continue
		for s in m3.mesh.get_surface_count():
			var m := m3.get_active_material(s)
			if not m is BaseMaterial3D:
				continue
			var key := "%d|%d" % [m.get_instance_id(), level]
			if not _tints.has(key):
				var dm := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				dm.albedo_color = Color(dm.albedo_color.r * f, dm.albedo_color.g * f, dm.albedo_color.b * f, dm.albedo_color.a)
				_tints[key] = dm
			m3.set_surface_override_material(s, _tints[key])


# ================================================================== camera and picking

func _place_camera() -> void:
	if _cam == null:
		return
	_pitch = clampf(_pitch, 0.15, 1.45)
	_dist = clampf(_dist, 150.0, 20000.0)
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	_cam.look_at_from_position(_target + dir * _dist, _target, Vector3.UP)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist *= 0.9
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist *= 1.1
			_place_camera()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_drag = mb.button_index
				_drag_moved = 0.0
			else:
				if _drag_moved < 4.0 and mb.button_index == MOUSE_BUTTON_LEFT:
					_pinned = _pick(mb.position)
					_show_cell(_pinned)
				_drag = 0
		accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag != 0:
			_drag_moved += mm.relative.length()
			if _drag == MOUSE_BUTTON_LEFT:
				_yaw -= mm.relative.x * 0.006
				_pitch += mm.relative.y * 0.006
			else:
				var k := _dist * 0.0012
				var right := _cam.global_transform.basis.x
				var fwd := Vector3(-sin(_yaw), 0, -cos(_yaw))
				_target += (-right * mm.relative.x + fwd * mm.relative.y) * k
			_place_camera()
		else:
			hover_at(mm.position)
		accept_event()


## The cell under a point of the view (on the ground plane), or (-99999, -99999).
func _pick(p: Vector2) -> Vector2i:
	if _cam == null or _layout.is_empty():
		return Vector2i(-99999, -99999)
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	if absf(d.y) < 1e-5:
		return Vector2i(-99999, -99999)
	var t := -o.y / d.y
	if t <= 0.0:
		return Vector2i(-99999, -99999)
	var g := o + d * t
	var c0 := Vector2i(int(_layout["centre"][0]), int(_layout["centre"][1]))
	return Vector2i(floori(g.x / CELL) + c0.x, floori(g.z / CELL) + c0.y)


func hover_at(p: Vector2) -> void:
	var c := _pick(p)
	if c == _hover:
		return
	_hover = c
	if _pinned.x == -99999:
		_show_cell(c)


func _show_cell(c: Vector2i) -> void:
	var w := _world()
	if w == null or _layout.is_empty() or c.x == -99999:
		_hover_mesh.visible = false
		return
	_info.text = cell_text(w, town, c, _ctx)
	var c0 := Vector2i(int(_layout["centre"][0]), int(_layout["centre"][1]))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := _corner(c, c0) + Vector3(0, 1.5, 0)
	var col := Color(1, 0.85, 0.3, 1)
	_ribbon(st, a, a + Vector3(CELL, 0, 0), 3.0, 0.0, col)
	_ribbon(st, a + Vector3(0, 0, CELL), a + Vector3(CELL, 0, CELL), 3.0, 0.0, col)
	_ribbon(st, a, a + Vector3(0, 0, CELL), 3.0, 0.0, col)
	_ribbon(st, a + Vector3(CELL, 0, 0), a + Vector3(CELL, 0, CELL), 3.0, 0.0, col)
	_hover_mesh.mesh = st.commit()
	var m := _vc_material()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_hover_mesh.material_override = m
	_hover_mesh.visible = true
