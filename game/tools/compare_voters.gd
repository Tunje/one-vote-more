extends SceneTree
## M10 S3b: the same colony with legacy voter cells vs population leaves as voters.
##   godot --headless --path game --script res://tools/compare_voters.gd -- [years=30] [seed=1]
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 30
	var seed_v := int(args[1]) if args.size() > 1 else 1
	for mode in ["CELLS", "LEAVES"]:
		var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
		sim.world.meta["voters"] = mode
		var t0 := Time.get_ticks_msec()
		print("=== %s ===" % mode)
		for _m in years * 12:
			sim.step()
			var w := sim.world
			for f in w.facts.query("POL_ELECTION_HELD", w.month - 1, w.month - 1):
				var e: Dictionary = w.table("election")[f["data"]["election"]]
				var parts: Array = []
				var ids: Array = e["votes"].keys()
				ids.sort_custom(func(a, b): return e["votes"][a] > e["votes"][b])
				for pid in ids:
					parts.append("%s %.1f%%/%d" % [w.table("party")[pid]["name"], float(e["votes"][pid]) / maxf(1.0, e["total"]) * 100.0, int(e["seats"].get(pid, 0))])
				print("  Y%d election (%d voters): %s" % [w.month / 12 + 1, e["total"], ", ".join(parts)])
			if w.month % 60 == 0:
				var n := PolVoters.all(w).filter(func(c): return int(c["pop"]) > 0).size()
				print("  Y%d approval %.1f%%  voter groups %d  parties %d" % [w.month / 12, w.indicators.read("POL_GOV_APPROVAL") / 1000.0, n, PartyLife.active(w).size()])
		print("  ms/month %d" % ((Time.get_ticks_msec() - t0) / (years * 12)))
	quit()
