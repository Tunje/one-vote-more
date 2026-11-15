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
	w.table("transport")["fpairs_last"] = {"d:1>d:2": [100, 900]}
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
	w.table("transport")["fpairs_last"] = {"d:1>d:2": [1000, 0]}
	GovBuilder._road_budget_need(w, st)
	check(not st.has("lever_need"), "the case is withdrawn when the freight moves")


func test_a_district_passed_over_for_another_road_resents_it() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	(sim.world.meta["on"] as Array).append_array(["FREIGHT_ROADS", "ROAD_WORKS"])
	sim.run(60)
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	for pid in w.table("project"):                     # no road work under way anywhere
		if w.table("project")[pid]["type"] == "ROAD":
			w.table("project")[pid]["status"] = "DONE"
	var bad := ""
	for r in Transport.road_needs(w):
		if int(r.get("severity", 0)) >= GovBuilder.ROAD_FELT_SEV:
			bad = str(r["district"])
			break
	check(bad != "", "a district with a badly overloaded road by year 5")
	if bad == "":
		return
	var who := {"by": "commander", "pos": {}}
	st.erase("road_wait")
	st["road_q_orders"] = ["somewhere:else"]
	GovBuilder._road_feelings(w, st, who)
	var facts: Array = w.facts.query("POL_ROAD_PASSED_OVER", w.month, w.month).filter(func(f): return String(f["data"]["district"]) == bad)
	check_eq(facts.size(), 1, "passed over once")
	if facts.size() == 1:
		check_eq(facts[0]["affected"]["districts"], [bad], "felt in that district only")
		check(int(facts[0]["impact"]["INFRASTRUCTURE"]) < 0, "they think less of the roads")
		check_eq(String(facts[0]["data"]["instead"]), "somewhere:else", "it names the road that went first")
	check_eq(int(st["road_wait"][bad]), 1, "one quarter waited")
	var first := int(facts[0]["impact"]["INFRASTRUCTURE"]) if facts.size() == 1 else 0
	for i in 6:
		w.month += 3
		st["road_q_orders"] = ["somewhere:else"]
		GovBuilder._road_feelings(w, st, who)
	var later: Array = w.facts.query("POL_ROAD_PASSED_OVER", w.month, w.month).filter(func(f): return String(f["data"]["district"]) == bad)
	check(later.size() == 1 and int(later[0]["impact"]["INFRASTRUCTURE"]) < first, "it gets worse the longer they wait")
	w.month += 3
	st["road_q_orders"] = [bad]
	GovBuilder._road_feelings(w, st, who)
	check(not (st.get("road_wait", {}) as Dictionary).has(bad), "a road ordered for them ends the wait")
	check_eq(w.facts.query("POL_ROAD_PASSED_OVER").filter(func(f): return String(f["data"]["district"]) == bad).size(), 7, "and no new complaint from them")


func test_the_road_that_frees_most_freight_goes_first() -> void:
	var w: WorldState = EconSim.make(2, "BALANCED", {}, true).world
	var cure := [{"fix": "LANE", "cost": 1000, "load_after_pm": 700, "relief_pm": 600, "spec": {}}]
	var quarry := {"key": "LINK:q", "district": "d:1", "severity": 900, "held_mu": 4000, "held_by_good": {"MINERAL": 4000}, "options": cure}
	var food := {"key": "LINK:f", "district": "d:1", "severity": 500, "held_mu": 3000, "held_by_good": {"FOOD": 3000}, "options": cure}
	var quiet := {"key": "LINK:x", "district": "d:1", "severity": 700, "held_mu": 0, "held_by_good": {}, "options": cure}
	check(GovBuilder.road_benefit(food) > GovBuilder.road_benefit(quarry), "held food counts for more than held ore")
	var order: Array = GovBuilder.road_ranking(w, [quarry, quiet, food], []).map(func(r): return String(r["key"]))
	check_eq(order, ["LINK:f", "LINK:q", "LINK:x"], "food road, then the quarry road, then the merely busy one")
	var dear := food.duplicate()
	dear["key"] = "LINK:d"
	dear["options"] = [{"fix": "NEW_LINK", "cost": 9000, "load_after_pm": 500, "relief_pm": 800, "spec": {}}]
	check(GovBuilder.road_benefit(dear) < GovBuilder.road_benefit(food), "the same freight freed for nine times the money is worth less")


func test_tolls_are_felt_where_the_commuters_live() -> void:
	check_eq(GovBuilder.toll_impact(1000, 1000, 100000), 0, "a trifle goes unnoticed")
	check(GovBuilder.toll_impact(500000, 1000, 100000) < 0, "half a percent of a wage per head is noticed")
	check(GovBuilder.toll_impact(5000000, 1000, 100000) < GovBuilder.toll_impact(500000, 1000, 100000), "more toll, more felt")
	check_eq(GovBuilder.toll_impact(99000000, 1000, 100000), -GovBuilder.TOLL_MAX_IMPACT, "up to a limit")
	check_eq(GovBuilder.toll_impact(5000, 0, 100000), 0, "nobody lives there")
	var w: WorldState = EconSim.make(2, "BALANCED", {}, true).world
	w.month = GovBuilder.QUARTER_MONTH
	var before := w.facts.query("POL_ROAD_TOLLS_FELT").size()
	GovBuilder._toll_feelings(w)
	check_eq(w.facts.query("POL_ROAD_TOLLS_FELT").size(), before, "nothing without private roads")
