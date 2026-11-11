extends SceneTree
## O-1 A/B: integrated runs with mechanisms switched off via world.meta["off"].
## Usage: godot --headless --path . --script res://tools/ab_o1.gd -- <label> <months> <seeds> [OFF1,OFF2,...]
## Prints per seed: in-band months (unemployment 3–25%), famine, default, mean unemployment.


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var label: String = a[0] if a.size() > 0 else "base"
	var months := int(a[1]) if a.size() > 1 else 120
	var seeds := int(a[2]) if a.size() > 2 else 6
	var off: Array = []
	if a.size() > 3 and a[3] != "-":
		off = Array(a[3].split(","))
	var tot := 0
	var fam := 0
	var dfl := 0
	var first := int(a[4]) if a.size() > 4 else 1
	for sd in range(first, first + seeds):
		var sim := Simulation.new(sd)
		sim.world.meta["scenario"] = "BALANCED"
		sim.world.meta["persona"] = {}
		sim.world.meta["autoplay_player"] = true
		sim.world.meta["off"] = off
		if off.has("SUPPORT_ON"):
			sim.world.meta["support"] = true  # M12 A/B: old home-world support model
		if off.has("AUTOPILOT_ON"):  # A/B: the pre-GovBuilder setup (econ caretaker autopilot instead of GovBuilder)
			sim.register(preload("res://sim/law/law_provider.gd").new())
			sim.register(preload("res://sim/staff/staff_provider.gd").new())
			sim.register(EconAutopilot.new())
			sim.register(EconProvider.new())
			sim.register(PoliticsProvider.new())
		else:
			EconSim._register(sim)
		sim.new_game()
		var inb := 0
		var usum := 0.0
		var fam_m := -1
		for m in months:
			sim.step()
			var u := FirmAI.colony_unemployment(sim.world)
			usum += u
			if u >= 0.03 and u <= 0.25:
				inb += 1
			if fam_m < 0 and EconUtil.st(sim.world)["famine"]:
				fam_m = sim.world.month
			if months > 240 and (m + 1) % 120 == 0:
				var s0 := EconUtil.st(sim.world)
				print("%s seed %d y%d pop %d u %.1f%% food_short %d E %d/%d famine_m %d" % [label, sd, (m + 1) / 12, PopStore.total(sim.world), 100.0 * u, s0["food_shortfall"],
					s0["util_supply"]["E"] / 1000, s0["util_demand"]["E"] / 1000, fam_m])
		var s := EconUtil.st(sim.world)
		tot += inb
		fam += 1 if s["famine"] else 0
		dfl += 1 if s["sovereign_default"] else 0
		print("%s seed %d in_band %d famine %s default %s mean_u %.1f%%" % [label, sd, inb, str(s["famine"]), str(s["sovereign_default"]), 100.0 * usum / months])
	print("%s TOTAL in_band %d famine %d default %d" % [label, tot, fam, dfl])
	quit()
