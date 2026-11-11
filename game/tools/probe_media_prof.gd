extends SceneTree
## Temporary profiler for Media._readers (Anni). Delete after use.
func _initialize() -> void:
	var sim := Simulation.new(1)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	EconSim._register(sim)
	sim.new_game()
	for m in 30:
		sim.step()
	var w: WorldState = sim.world
	var t0 := Time.get_ticks_usec()
	for i in 10:
		PolVoters.all(w)
	var t1 := Time.get_ticks_usec()
	var n := 0
	for i in 10:
		for c in PolVoters.all(w):
			if c.has("ideology"):
				VoteModel.axis_weights(c.get("salience", {}))
				n += 1
	var t2 := Time.get_ticks_usec()
	for i in 10:
		Media._readers(w)
	var t3 := Time.get_ticks_usec()
	print("mode %s groups %d | all() %.2f ms | axis_weights %.2f ms | readers %.2f ms" % [w.meta.get("voters", "CELLS"), n / 10,
		(t1 - t0) / 10000.0, (t2 - t1) / 10000.0, (t3 - t2) / 10000.0])
	quit(0)
