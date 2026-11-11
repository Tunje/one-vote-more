extends SceneTree
## M10 S2 probe: economy on population leaves. Runs N months and checks every month:
## PopStore.reconcile, EconPop.check (jobs = employed people), ledger total, mismatches.
## Usage: godot --headless --path . --script res://tools/debug_pop_econ.gd -- [seed] [months] [integrated 0/1]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var months := int(args[1]) if args.size() > 1 else 24
	var integ := args.size() > 2 and args[2] == "1"
	var t0 := Time.get_ticks_msec()
	var sim := EconSim.make(seed_v) if integ else EconSim.make_econ_only(seed_v)
	_report(sim.world, "setup")
	for m in months:
		sim.run(1)
		var w := sim.world
		var errs: Array = PopStore.reconcile(w) + EconPop.check(w)
		if not errs.is_empty() or w.ledger.total() != 0:
			print("m%d PROBLEMS ledger=%d %s" % [w.month, w.ledger.total(), str(errs.slice(0, 6))])
		if (m + 1) % 6 == 0:
			_report(w, "m%d" % w.month)
	print("mismatches: ", EconUtil.st(sim.world).get("pop_mismatch", []))
	var v := sim.world.values
	print("births %d deaths %d arrivals %d departures %d" % [v.get("pop_births", 0), v.get("pop_deaths", 0), v.get("pop_arrivals", 0), v.get("pop_departures", 0)])
	print("ms total %d" % (Time.get_ticks_msec() - t0))
	quit()


func _report(w: WorldState, tag: String) -> void:
	var st := {}
	for k in w.peek("pop"):
		var l: Dictionary = w.peek("pop")[k]
		st[l["status"]] = int(st.get(l["status"], 0)) + int(l["n"])
	var bands := {}
	for k in w.peek("pop"):
		var l: Dictionary = w.peek("pop")[k]
		bands[l["inc"]] = int(bands.get(l["inc"], 0)) + int(l["n"])
	print("%s pop %d leaves %d status %s bands %s u=%.1f%% food_short=%d‰" % [tag, PopStore.total(w), w.peek("pop").size(), str(st), str(bands),
		100.0 * FirmAI.colony_unemployment(w), EconUtil.st(w).get("food_shortfall", 0)])
