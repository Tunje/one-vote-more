extends SceneTree
## Wilma: render Election Night to PNGs (mid-count and final). Needs a window.
##   godot --path game --script res://tools/shot_election.gd -- out_prefix [seed] [months]
var _n: ElectionNight
var _frames := 0
var _out := ""


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var s := GameSession.new()
	s.new_game(int(args[1]) if args.size() > 1 else 3, true)
	var eid := ""
	for _i in int(args[2]) if args.size() > 2 else 60:
		s.end_month()
		var w := s.world()
		for f in w.facts.query("POL_ELECTION_HELD", w.month - 1, w.month - 1):
			eid = String(f["data"]["election"])
	_n = ElectionNight.new()
	root.size = Vector2i(1280, 800)
	_n.size = Vector2(1280, 800)
	root.add_child(_n)
	_n.show_election(s.world(), eid)
	_n.set_process(false)
	_n.reported = maxi(1, _n.districts.size() / 2)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 4:
		root.get_texture().get_image().save_png(_out + "_mid.png")
		_n.skip()
	if _frames == 8:
		root.get_texture().get_image().save_png(_out + "_final.png")
		quit()
	return false
