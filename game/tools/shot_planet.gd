extends SceneTree
## Terra: render the planet view to a PNG (needs a window, not --headless).
## godot --path game --script res://tools/shot_planet.gd -- <seed> <out.png> [yaw_offset_deg] [dist]
var _view: PlanetView
var _frames := 0
var _out := "user://planet.png"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	var s := GameSession.new()
	s.new_game(seed_v, true)
	_view = PlanetView.new()
	_view.session = s
	root.size = Vector2i(1600, 900)
	_view.size = Vector2(1600, 900)
	root.add_child(_view)
	_view.refresh()
	if args.size() > 2:
		_view._yaw += deg_to_rad(float(args[2]))
	if args.size() > 3:
		_view._dist = float(args[3])
	_view._place_camera()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_view._set_hover(Planet.landing(_view.session.world()))
		_view._update_info()
	if _frames < 8:
		return false
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	return true
