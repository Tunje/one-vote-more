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
	for sd in range(1, seeds + 1):
		var sim := Simulation.new(sd)
		sim.world.meta["scenario"] = "BALANCED"
		sim.world.meta["persona"] = {}
		sim.world.meta["autoplay_player"] = true
		sim.world.meta["off"] = off
		EconSim._register(sim)
		sim.new_game()
		var inb := 0
		var usum := 0.0
		for m in months:
			sim.step()
			var u := FirmAI.colony_unemployment(sim.world)
			usum += u
			if u >= 0.03 and u <= 0.25:
				inb += 1
		var s := EconUtil.st(sim.world)
		tot += inb
		fam += 1 if s["famine"] else 0
		dfl += 1 if s["sovereign_default"] else 0
		print("%s seed %d in_band %d famine %s default %s mean_u %.1f%%" % [label, sd, inb, str(s["famine"]), str(s["sovereign_default"]), 100.0 * usum / months])
	print("%s TOTAL in_band %d famine %d default %d" % [label, tot, fam, dfl])
	quit()
