extends TestCase
## Road works by choice (ROAD_WORKS on top of FREIGHT_ROADS; user 2026-11-15): the government picks among the ways to
## relieve a road by its own character, and may pick badly.

const EconSim := preload("res://sim/economy/econ_sim.gd")

const OPTS := [
	{"fix": "REPAIR", "cost": 100, "load_after_pm": 1150, "relief_pm": 150, "spec": {"repair": "l1"}},
	{"fix": "UPGRADE", "cost": 400, "load_after_pm": 950, "relief_pm": 350, "spec": {"upgrade": "l1"}},
	{"fix": "LANE", "cost": 900, "load_after_pm": 750, "relief_pm": 550, "spec": {"lane": "l1"}},
	{"fix": "NEW_LINK", "cost": 2500, "load_after_pm": 500, "relief_pm": 800, "spec": {"a": 1, "b": 2}},
]


func test_each_government_picks_its_own_fix() -> void:
	check_eq(String(GovBuilder.road_option(OPTS, -0.5, 0.0, 10000)["fix"]), "UPGRADE", "a thrifty government: the cheapest that ends the jam")
	check_eq(String(GovBuilder.road_option(OPTS, 0.0, 0.0, 10000)["fix"]), "LANE", "a middling government: the cheapest cure")
	check_eq(String(GovBuilder.road_option(OPTS, 0.4, 0.3, 10000)["fix"]), "NEW_LINK", "a builder government: room to spare")


func test_money_limits_the_choice() -> void:
	check_eq(String(GovBuilder.road_option(OPTS, 0.4, 0.3, 1200)["fix"]), "LANE", "a builder that can't afford the new road takes the cure")
	check_eq(String(GovBuilder.road_option(OPTS, 0.0, 0.0, 600)["fix"]), "UPGRADE", "no cure affordable: the biggest relief it can pay for")
	check_eq(String(GovBuilder.road_option(OPTS, -0.5, 0.0, 200)["fix"]), "REPAIR", "a thrifty government with little money patches")
	check(GovBuilder.road_option(OPTS, 0.0, 0.0, 50).is_empty(), "nothing affordable: nothing ordered")
	check(GovBuilder.road_option([], 0.0, 0.0, 10000).is_empty(), "no options: nothing ordered")


func test_off_unless_both_flags_are_on() -> void:
	var w: WorldState = EconSim.make(2, "BALANCED", {}, true).world
	check(not GovBuilder.road_works_on(w), "off by default")
	(w.meta["on"] as Array).append("ROAD_WORKS")
	check(not GovBuilder.road_works_on(w), "needs freight on the roads")
	(w.meta["on"] as Array).append("FREIGHT_ROADS")
	check(GovBuilder.road_works_on(w), "on with both")


func test_in_the_game_it_orders_roads_and_reloads_the_same() -> void:
	var sim: Simulation = EconSim.make(2, "BALANCED", {}, true)
	(sim.world.meta["on"] as Array).append_array(["FREIGHT_ROADS", "ROAD_WORKS"])
	sim.run(96)
	var roads := 0
	for f in sim.world.facts.query("POL_PROJECT_ORDERED"):
		if String(f["data"]["type"]) == "ROAD":
			roads += 1
	check(roads > 0, "roads are ordered (%d)" % roads)
	var path := "user://test_road_works.sav"
	check_eq(SaveIO.save(sim, path), OK, "saved")
	var copy := EconSim.for_load()
	check_eq(SaveIO.load_into(copy, path), OK, "loaded")
	sim.run(12)
	copy.run(12)
	check_eq(copy.world.state_hash(), sim.world.state_hash(), "a saved game continues the same")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_roads_case_for_the_budget() -> void:
	var sim: Simulation = EconSim.make(2, "BALANCED", {}, true)
	sim.run(60)
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	w.table("transport")["fpairs_last"] = {"a|b": [100, 900]}
	GovBuilder._road_budget_need(w, st)
	check(not st.has("lever_need"), "nothing reported without the flags")
	(w.meta["on"] as Array).append_array(["FREIGHT_ROADS", "ROAD_WORKS"])
	check_eq(FreightRoads.jam_share_pm(w), 900, "nine tenths of the freight is held")
	var cheapest := -1
	for r in Transport.road_needs(w):
		for o in r.get("options", []):
			if int(o["load_after_pm"]) <= 1000 and (cheapest < 0 or int(o["cost"]) < cheapest):
				cheapest = int(o["cost"])
	GovBuilder._road_budget_need(w, st)
	var need := int((st.get("lever_need", {}) as Dictionary).get("ECON_BUDGET_INFRASTRUCTURE", 0))
	if cheapest >= 0 and EconActions.headroom(w, "ECON_BUDGET_INFRASTRUCTURE") < cheapest * 11 / 10:
		check_eq(need, 2000, "a cure the line can't pay for while freight is held: the strongest case")
	else:
		check_eq(need, 0, "no case while the line can pay or nothing cures")
	w.table("transport")["fpairs_last"] = {"a|b": [1000, 0]}
	GovBuilder._road_budget_need(w, st)
	check(not st.has("lever_need"), "the case is withdrawn when the freight moves")
