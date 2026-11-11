extends SceneTree
## Terra scratch: screenshot of the real main screen (needs a window).
var _f := 0
var _out := ""


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1600, 900)
	root.add_child(load("res://ui/main.tscn").instantiate())


func _process(_d: float) -> bool:
	_f += 1
	if _f < 10:
		return false
	root.get_texture().get_image().save_png(_out)
	return true
