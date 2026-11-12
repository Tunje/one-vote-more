extends SceneTree
## Wilma: render the office's Visitors tab with an interview in progress (needs a window).
var _p
var _frames := 0
var _out := ""


func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var s := GameSession.new()
	s.new_game(1, false)
	for _i in 6:
		s.end_month()
	var w: WorldState = s.world()
	var D := preload("res://sim/staff/staff_data.gd")
	var rid: String = preload("res://sim/staff/staff_ops.gd").open_recruitment(w, String(D.CIVIL_TEMPLATES[0]["spec"]))
	var OStaff := preload("res://sim/staff/office_staff.gd")
	var iid: String = OStaff.start_interview(w, rid, 0)
	for q in ["EXPERIENCE", "POLITICAL", "STRESS"]:
		OStaff.ask(w, iid, q)
	_p = load("res://ui/panels/office_panel.gd").new()
	root.size = Vector2i(1100, 1000)
	_p.size = Vector2(1100, 1000)
	root.add_child(_p)
	_p.setup(s)
	_p.tab = "Visitors"
	_p.refresh()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_texture().get_image().save_png(_out)
		quit()
	return false
