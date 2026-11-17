extends SceneTree
## Runs the game for some years and prints what happened.  godot --headless --path game --script res://tools/run_check.gd [-- years seed]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 20
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var s := GameSession.new()
	s.new_game(seed_v, true)
	for i in years * 12:
		s.end_month()
	var w := s.world()
	print("RUN OK seed ", seed_v, " month ", w.month, " parties ", w.peek("party").size(), " elections ", w.peek("election").size(), " bills ", w.peek("bill").size(),
		" facts ", w.facts.query("", 0, w.month).size(), " approval ", w.indicators.read("POL_GOV_APPROVAL") / 1000.0)
	print(PoliticalSim.summary(s.sim))
	quit()
