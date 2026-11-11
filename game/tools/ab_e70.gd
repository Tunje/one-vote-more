extends SceneTree
## A/B: integrated run with vs without E70 (smoothing share 0, benefit floor 0), or with arg3 "e69" the old 48000 guard.
##   godot --headless --path . --script res://tools/ab_e70.gd -- [seed] [months] [e69]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 3
	var months := int(args[1]) if args.size() > 1 else 120
	for off in [false, true]:
		var sim := EconSim.make(seed_v, "BALANCED", {}, true)
		if off:
			if args.size() > 2 and args[2] == "e69":
				sim.world.indicators.defs["ECON_TREASURY_RUNWAY"]["fiscalGuard"] = {"floor": 48000}
			else:
				sim.world.meta["disc_smooth_share"] = 0.0
				sim.world.levers["ECON_BENEFIT_FLOOR"] = 0
		var in_band := 0
		var first_diff := ""
		for m in months:
			sim.step()
			var lf := 0
			var emp := 0
			for gid in sim.world.table("hh"):
				lf += sim.world.table("hh")[gid]["lf"]
				emp += EconLabor.employed(sim.world.table("hh")[gid])
			var u := float(lf - emp) / float(maxi(1, lf))
			if u >= 0.03 and u <= 0.25:
				in_band += 1
			if (m + 1) % 24 == 0:
				print("  %s m%d u=%.3f treasury=%d" % ["OFF" if off else "ON ", m + 1, u, sim.world.ledger.balance(EconUtil.TREASURY)])
		print("%s seed %d in_band %d/%d hash %s" % ["E70 OFF" if off else "E70 ON ", seed_v, in_band, months, sim.world.state_hash()])
	quit(0)
