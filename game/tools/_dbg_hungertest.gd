extends SceneTree
## Wilma: why does test_slump's hunger case propose a benefit-floor cut on the v9 defaults?
func _init() -> void:
	var sim: Simulation = EconSim.make(5, "BALANCED", {}, true)
	sim.run(66)
	var w := sim.world
	for lid in Legislature.HUNGER_LEVERS:
		w.levers[lid] = 50
	EconUtil.st(w)["food_shortfall"] = 300
	var g: Dictionary = w.table("pol")["state"]["government"]
	print("agreement: ", g.get("agreement", []))
	print("protected: ", Legislature.protected_levers(w))
	var bel := ""
	for pid in g["members"]:
		bel = pid
	var def: Dictionary = w.lever_defs["ECON_BENEFIT_FLOOR"]
	print("lobby tilt cut: ", Legislature.lobby_tilt(w, w.peek("party").get(String(g.get("pm_party", bel)), {}), "ECON_BENEFIT_FLOOR", -10.0))
	print("ideo cut: ", Legislature.ideo_alignment(def, -10.0, g["center"]))
	print("members: ", g["members"], " pm: ", g.get("pm_party", ""))
	quit()
