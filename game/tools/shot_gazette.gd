extends SceneTree
## Wilma: render the Gazette front page to a PNG (needs a window).
var _p
var _frames := 0
var _out := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var s := GameSession.new()
	s.new_game(int(args[1]) if args.size() > 1 else 3, true)
	for _i in int(args[2]) if args.size() > 2 else 60:
		s.end_month()
	_p = load("res://ui/panels/gazette_panel.gd").new()
	root.size = Vector2i(1200, 1400)
	_p.size = Vector2(1200, 1400)
	root.add_child(_p)
	_p.setup(s)
	_p.refresh()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_texture().get_image().save_png(_out)
		quit()
	return false
