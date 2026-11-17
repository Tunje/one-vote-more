extends SceneTree
## Terra: render the town view (ui/town_view.gd, flag TOWN_GRID) to PNGs (needs a window, not --headless).
## godot --path game --script res://tools/shot_town.gd -- <seed> <out.png> [months] [town] [forms]
## Saves <out>.png (the whole town, a cell hovered) and <out>_close.png (a low view along a street).
## forms: e.g. "APARTMENT,HOUSE" (the commander allows apartments, set before the months run) to see other forms.
var _view: TownView
var _frames := 0
var _out := "user://town.png"
var _town := "d:1"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	var months := int(args[2]) if args.size() > 2 else 6
	if args.size() > 3:
		_town = args[3]
	var s := GameSession.new()
	s.new_game(seed_v, true)
	var on: Array = s.world().meta.get("on", [])
	if not TownGrid.FLAG in on:
		on.append(TownGrid.FLAG)
	s.world().meta["on"] = on
	if args.size() > 4 and args[4] != "":
		s.end_month()
		TownGrid.set_forms(s.world(), "*", Array(args[4].split(",")))
	for _m in months:
		s.end_month()
	_view = TownView.new()
	_view.session = s
	root.size = Vector2i(1600, 900)
	_view.size = Vector2(1600, 900)
	root.add_child(_view)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_view.open_town(_town)
		var w := _view._world()
		var cs: Dictionary = w.peek("town").get("towns", {}).get(_town, {}).get("cells", {})
		if not cs.is_empty():   # hover a busy cell: the first housing cell nearest the centre
			var c0 := Vector2i(int(_view._layout["centre"][0]), int(_view._layout["centre"][1]))
			var best := Vector2i.ZERO
			var bd := 1 << 30
			for ck in EconUtil.sorted_keys(cs):
				var c := ColonyLayout.as_tile(ck)
				var d := absi(c.x - c0.x) + absi(c.y - c0.y)
				if String(cs[ck][1]) != "" and d < bd:
					bd = d
					best = c
			_view._pinned = best
			_view._show_cell(best)
	if _frames == 10:
		root.get_texture().get_image().save_png(_out)
		print("saved ", _out)
		_view._pitch = 0.32
		_view._dist = 650.0
		_view._yaw = 2.4
		_view._place_camera()
	if _frames == 18:
		var p := _out.get_basename() + "_close.png"
		root.get_texture().get_image().save_png(p)
		print("saved ", p)
		return true
	return false
