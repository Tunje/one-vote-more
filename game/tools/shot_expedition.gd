extends SceneTree
## Terra (A47): render the expedition's world picker (needs a window). godot --path game --script res://tools/shot_expedition.gd -- <seed> <out.png> [k]
var _p: ExpeditionPicker
var _frames := 0
var _out := "user://expedition.png"
var _k := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	if args.size() > 1:
		_out = args[1]
	_k = int(args[2]) if args.size() > 2 else 0
	var bg := ColorRect.new()
	bg.color = Color("#1e2328")
	bg.size = Vector2(1600, 900)
	root.add_child(bg)
	_p = ExpeditionPicker.new()
	_p.size = Vector2(1600, 900)
	root.add_child(_p)
	_p.setup(seed_v)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		_p.size = Vector2(root.size)
		_p.select(_k)
	if _frames < 12:
		return false
	root.get_texture().get_image().save_png(_out)
	print("saved ", _out)
	quit()
	return true
