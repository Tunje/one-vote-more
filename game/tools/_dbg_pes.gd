extends SceneTree
## temp (Bob, Wilma): does the public employment budget cap bind? args: seed from_year to_year
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var y0 := int(a[1]); var y1 := int(a[2])
	sim.run(y0 * 12)
	for m in (y1 - y0) * 12:
		sim.run(1)
		if w.month % 6 != 0:
			continue
		var sm := EconPublicJobs.summary(w)
		var un := PopStore.count(w, {"status": "UNEMPLOYED"}) / 1000
		var unGS := (PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:G") + PopStore.count(w, {"status": "UNEMPLOYED"}, "skill:S")) / 1000
		var pw: Variant = EconUtil.lever(w, "ECON_BUDGET_PUBLIC_WORKS", "-")
		print("m%d (Y%d) u %.1f%% unemployed %d (G+S %d) | PES lever %s k/yr → %d/month | pay %d | posts %d target %d | headroom %d | G wage %d | public works lever %s" % [w.month, w.month / 12,
			100.0 * FirmAI.colony_unemployment(w), un, unGS, str(sm["budget_pa"]), int(sm["budget_pa"]) * 1000 / 12, int(sm["pay"]), int(sm["posts"]), int(sm["target"]),
			int(sm["headroom"]), int(EconUtil.st(w)["wage"]["G"]) / 1000, str(pw)])
	quit()
