extends SceneTree
## Bob (Wilma's regression hunt): seed years variant (base | noE124 | noE124b | noBoth). Every 5 years: population,
## food margin and brake, farms, famine facts, PES and public-works levers, unemployment, attractiveness.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var v: String = a[2]
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if v in ["noE124", "noBoth"]:
		w.meta["off"] = ["E124"]
	if v in ["s7on", "s7on_noE126"]:
		w.meta["on"] = ["S7"]
	if v == "s7on_noE126":
		w.meta["off"] = ["E126"]
	if v == "s7on_noE130":
		w.meta["on"] = ["S7"]
		w.meta["off"] = ["E130"]
	if v == "base_noE130":
		w.meta["off"] = ["E130"]
	if v in ["noS7", "noS7b"]:
		w.meta["off"] = ["S7"]
	if v in ["noE124b", "noBoth", "noS7b"]:
		var d: Dictionary = w.lever_defs["ECON_BUDGET_PUBLIC_EMPLOYMENT"]
		d["range"] = [0, 5000]
		d["ideology"] = {"ECON_ROLE": 0.008, "FISCAL": 0.008, "LABOR": 0.006}
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 5 != 0:
			continue
		var e := EconEssentials.measure(w)
		var farms := 0
		for fid in w.table("facility"):
			if w.table("facility")[fid]["type"] == "FARM" and not w.table("facility")[fid]["mothball"]:
				farms += 1
		print("%s Y%d pop %d | food margin %d%% brake %.2f farms %d famine %d | PES %s PW %s posts %d | u %.1f%% attract %.0f%%" % [v, y + 1, PopStore.total(w),
			int(e["FOOD"]["margin_pct"]), EconHouseholds.food_brake(w), farms, w.facts.query("ECON_FAMINE").size(),
			str(w.levers.get("ECON_BUDGET_PUBLIC_EMPLOYMENT", "-")), str(w.levers.get("ECON_BUDGET_PUBLIC_WORKS", "-")), EconPublicJobs.posts(w),
			100.0 * FirmAI.colony_unemployment(w), 100.0 * EconCohorts.attractiveness(w)])
	quit()
