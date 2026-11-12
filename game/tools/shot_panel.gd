extends SceneTree
## Wilma: render any ui/panels/<name>_panel.gd to a PNG after N months (needs a window).
##   godot --path game --script res://tools/shot_panel.gd -- out.png <panel name e.g. unions> [seed=3] [months=60]
var _p
var _frames := 0
var _out := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var s := GameSession.new()
	s.new_game(int(args[2]) if args.size() > 2 else 3, true)
	for _i in int(args[3]) if args.size() > 3 else 60:
		s.end_month()
	_p = load("res://ui/panels/%s_panel.gd" % args[1]).new()
	root.size = Vector2i(1000, 1200)
	_p.size = Vector2(1000, 1200)
	root.add_child(_p)
	_p.setup(s)
	_p.refresh()


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_texture().get_image().save_png(_out)
		quit()
	return false
