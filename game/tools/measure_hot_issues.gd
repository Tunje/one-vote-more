extends SceneTree
## Hot issues (owner Ella, spec-election-year §11): how hot immigration / slums / emigration run over a century, and
## which campaigns and debates they name.
##   godot --headless --path game --script res://tools/measure_hot_issues.gd -- <months> <seed>
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 1200
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
	var hot_months := {}
	var peak := {}
	var line := PackedStringArray()
	for m in months:
		sim.run(1)
		var hs := HotIssues.heat(sim.world)
		for i in hs:
			peak[i] = maxi(int(peak.get(i, 0)), int(hs[i]))
			if int(hs[i]) >= HotIssues.HOT:
				hot_months[i] = int(hot_months.get(i, 0)) + 1
		if sim.world.month % 60 == 0:
			line.append("Y%d %s" % [sim.world.month / 12, ",".join(PackedStringArray(HotIssues.ISSUES.keys().map(func(i): return "%s=%d" % [String(i).substr(0, 4), int(hs.get(i, 0))])))])
	var w := sim.world
	print("== seed %d, %d months; pop %d" % [seed_v, months, PopStore.total(w)])
	for i in HotIssues.ISSUES:
		print("  %-13s hot months %4d  peak %d" % [i, int(hot_months.get(i, 0)), int(peak.get(i, 0))])
	print("  every 5 years: " + " | ".join(line))
	for f in w.facts.query("POL_CAMPAIGN_OPENED"):
		print("  campaign Y%d hot: %s" % [int(f["month"]) / 12, str(f["data"].get("hot", []))])
	var named := 0
	var qs := 0
	for f in w.facts.query("POL_DEBATE_HELD"):
		for i in f["data"].get("issues", []):
			qs += 1
			if String(i) != "":
				named += 1
	print("  debate questions naming a hot issue: %d of %d" % [named, qs])
	print("  arrivals %d, emigration facts %d, slum facts %d" % [w.facts.query("ECON_MIGRANTS_ARRIVED").size(), w.facts.query("ECON_EMIGRATION").size(), w.facts.query("ECON_SLUM").size()])
	quit(0)
