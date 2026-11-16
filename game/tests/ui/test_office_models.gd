extends TestCase
## Terra (the user: "yes use them", 2026-11-16): the 3D office loads the Modern Office pack (game/assets/office3d) when
## it is there and keeps its placeholders when it is not (the art is not committed); the clickable nodes, the pictures
## from the 2D desk and the live state are the same either way.

const OfficePanel := preload("res://ui/panels/office_panel.gd")
const NAMES := ["Desk", "Monitor", "Keyboard", "Mouse", "Tower", "InTray", "Paper", "Phone", "Lamp", "CoffeeCup", "Bin",
	"Window", "Charter", "Calendar", "WallClock", "Door", "Room", "Pens", "Stapler", "PictureFrame", "NamePlate"]


func _office(dir: String) -> OfficeDesk3D:
	OfficeDesk3D.model_dir = dir
	OfficeDesk3D._mats.clear()
	var s := GameSession.new()
	s.new_game(2, true)
	var d := OfficeDesk3D.new()
	d.session = s
	d.size = Vector2(1280, 720)
	d.refresh()
	return d


func _check_office(d: OfficeDesk3D, what: String) -> void:
	var sc := d.scene()
	for n in NAMES:
		check(sc.has_node(n), "%s: the node %s" % [what, n])
	for k in OfficeDesk3D.CLICK:
		check(d._aabb(sc.get_node(String(k))).size.length() > 0.05, "%s: %s can be picked" % [what, k])
	for p in ["Monitor/Screen", "Calendar/Sheet", "Paper/Sheet", "Window/Glass", "Charter/Sheet"]:
		var m := (sc.get_node(p) as MeshInstance3D).material_override as StandardMaterial3D
		check(m.albedo_texture is ViewportTexture, "%s: %s shows the 2D desk" % [what, p])
	check(sc.has_node("InTray/Stack") and sc.has_node("Phone/Glow") and sc.has_node("Phone/Badge") and sc.has_node("Lamp/Bulb")
		and sc.has_node("WallClock/Hand") and sc.has_node("Door/Hinge"), "%s: the live-state nodes" % what)
	var top := (sc.get_node("Monitor") as Node3D).position.y
	check_eq((sc.get_node("Keyboard") as Node3D).position.y, top, "%s: things stand on the desk top" % what)


func test_placeholders_without_the_pack() -> void:
	var d := _office("res://assets/no_such_office3d")
	_check_office(d, "placeholders")
	check(d.scene().has_node("Desk/Top") and not d.scene().has_node("Desk/Body"), "the drawn desk")
	check(d.scene().get_node("WallClock/Hand").visible, "the drawn clock's hand")
	d.free()
	OfficeDesk3D.model_dir = OfficeDesk3D.MODEL_DIR
	OfficeDesk3D._mats.clear()


func test_the_pack_when_it_is_there() -> void:
	if not ResourceLoader.exists(OfficeDesk3D.MODEL_DIR + "/Desk/Desk.obj"):
		check(true, "the pack is not in this tree: nothing to check")
		return
	var d := _office(OfficeDesk3D.MODEL_DIR)
	_check_office(d, "models")
	var sc := d.scene()
	check(sc.has_node("Desk/Body") and not sc.has_node("Desk/Top"), "the pack's desk")
	var body := sc.get_node("Desk/Body") as MeshInstance3D
	check(body.mesh is ArrayMesh, "a loaded mesh")
	var m := body.material_override as StandardMaterial3D
	check(m.albedo_texture != null and m.normal_enabled and m.ao_enabled, "its textures: colour, normal, AO")
	check_eq((sc.get_node("Monitor") as Node3D).position.y, body.get_aabb().end.y, "the desk top is the model's")
	check(sc.has_node("Monitor/Body") and sc.has_node("Phone/Handset") and sc.has_node("Lamp/Body"), "the desk things")
	check(not sc.get_node("WallClock/Hand").visible, "the pack's clock has its own hands")
	d.free()
	OfficeDesk3D._mats.clear()
