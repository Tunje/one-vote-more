extends SceneTree
## E70 probe: benefit floor per household group with the ordinary benefit rate at 0.
func _initialize() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(12)
	var w := sim.world
	w.levers["ECON_UNEMPLOYMENT_BENEFIT_RATE"] = 0
	sim.run(1)
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		print("%s lf %d emp %d unemp_now %d benefit %d ess %d adults %d short %s" % [gid, g["lf"], EconLabor.employed(g), g["lf"] - EconLabor.employed(g), g["income"].get("benefit", 0), EconHouseholds.essentials_cost(w, g), EconHouseholds.adults(g), EconUtil.st(w).get("treasury_short", false)])
	quit(0)
