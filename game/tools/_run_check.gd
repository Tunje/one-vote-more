extends SceneTree
## Runs the game without the economy for some years and prints what happened.
func _initialize() -> void:
	var s := GameSession.new()
	s.new_game(1, true)
	for i in 240:
		s.end_month()
	var w := s.world()
	print("RUN OK month ", w.month, " parties ", w.peek("party").size(), " elections ", w.peek("election").size(), " bills ", w.peek("bill").size(),
		" facts ", w.facts.query("", 0, w.month).size(), " approval ", w.indicators.read("POL_GOV_APPROVAL") / 1000.0)
	print(PoliticalSim.summary(s.sim))
	quit()
