extends SceneTree
## M4 gate: headless economy soak. No player; EconAutopilot as caretaker government.
##   godot --headless --path game --script res://tools/soak_economy.gd -- [years] [seeds]
## Prints a yearly table per seed and a PASS/FAIL verdict on: conserved money, conserved goods,
## bounded prices, fed population (no famine), no sovereign default.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 10
	var seeds := int(args[1]) if args.size() > 1 else 3
	var all_ok := true
	for seed_v in range(1, seeds + 1):
		var sim := EconSim.make_econ_only(seed_v)
		print("=== seed %d ===" % seed_v)
		print(EconReport.header())
		for y in years:
			sim.run(12)
			print(EconReport.year_line(sim.world))
		var verdict := EconReport.verdict(sim.world)
		print(verdict["text"])
		all_ok = all_ok and verdict["ok"]
	print("SOAK %s" % ("PASS" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)
