extends SceneTree
## M9 probe: union density, strikes/lockouts/mass layoffs and donation offers over an integrated run.
## Usage: godot --headless --path . --script res://tools/debug_unions.gd -- [seed] [months]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var months := int(args[1]) if args.size() > 1 else 120
	var sim := EconSim.make(seed_v)
	var offers_n := 0
	var offers_sum := 0
	var offerers := {}
	for m in months:
		sim.run(1)
		var w := sim.world
		for oid in w.peek("donation_offer"):
			var o: Dictionary = w.peek("donation_offer")[oid]
			offers_n += 1
			offers_sum += int(o["amount_milli"])
			offerers[oid] = str(o["prefers"])
		if (m + 1) % 12 == 0:
			var dens := []
			for occ in EconUtil.sorted_keys(EconUnions.BASE_DENSITY):
				dens.append("%s %d" % [occ.substr(0, 4), w.indicators.read("ECON_UNION_DENSITY", occ) / 1000])
			print("y%d rwg %.1f%% density [%s] strikes %d lockouts %d mass_layoffs %d offers %d (avg %d cr)" % [(m + 1) / 12,
				EconUnions.real_wage_growth(w), ", ".join(dens), w.facts.query("ECON_STRIKE", m - 11).size(),
				w.facts.query("ECON_LOCKOUT", m - 11).size(), w.facts.query("ECON_LAYOFFS_MASS", m - 11).size(),
				offers_n, offers_sum / maxi(1, offers_n) / 1000])
			offers_n = 0
			offers_sum = 0
	for f in sim.world.facts.query("ECON_STRIKE"):
		print("  strike m%d %s %s resp %s mag %d" % [f["month"], f["data"]["org"], f["data"]["cause"], str(f["responsible"].map(func(r): return r["actor"]["id"])), f["magnitude"]])
	for oid in EconUtil.sorted_keys(offerers):
		print("  donor %s prefers %s" % [oid, offerers[oid]])
	quit()
