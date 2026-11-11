extends SceneTree
## Counts econ actions by id/result over an integrated run (did any player/AI action get rejected?).
func _initialize() -> void:
	var seed_v := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var counts := {}
	var seen := 0
	for m in 120:
		sim.step()
		var log: Array = EconUtil.peek_st(sim.world).get("action_log", [])
		for e in log:
			if e["m"] == sim.world.month - 1 or e["m"] == sim.world.month:
				pass
		for e in log.slice(maxi(0, log.size() - 50)):
			var k: String = "%s %s" % [e["id"], "ok" if e["ok"] else "REJECTED"]
			var key := "%d|%s|%d" % [e["m"], k, log.find(e)]
			if not counts.has(key):
				counts[key] = k
	var tally := {}
	for v in counts.values():
		tally[v] = tally.get(v, 0) + 1
	print(tally)
	quit(0)
