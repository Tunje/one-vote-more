extends TestCase
## A43 / T1: ROAD projects that name a link are checked and billed by Terra's planner (Transport.plan_link) and build
## the link on completion (Transport.complete_road); roads without a spec still work.


func _sim() -> Simulation:
	var sim := Simulation.new(1)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	for _i in 3:
		sim.step()
	return sim


func test_upgrade_road_is_priced_by_the_planner() -> void:
	var w := _sim().world
	var links: Array = Transport.network(w).get("links", [])
	check(not links.is_empty(), "the founding network exists")
	if links.is_empty():
		return
	var lid: String = str(links[0].get("id", ""))
	var spec := {"upgrade": lid}
	var plan: Dictionary = Transport.plan_link(w, spec)
	if not bool(plan.get("ok", false)):
		check(EconActions.validate(w, "ECON_COMMISSION_PROJECT", {"type": "ROAD", "district": "d:1", "link": spec}) != "", "a refused plan is a readable error")
		return
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 50000
	var err := EconActions.validate(w, "ECON_COMMISSION_PROJECT", {"type": "ROAD", "district": "d:1", "link": spec})
	check_eq(err, "", "a valid link upgrade can be commissioned")
	var n0 := w.table("project").size()
	EconActions.apply(w, "ECON_COMMISSION_PROJECT", {"type": "ROAD", "district": "d:1", "link": spec})
	check_eq(w.table("project").size(), n0 + 1, "a project was created")
	var p: Dictionary = {}
	for pid in w.table("project"):
		if w.table("project")[pid].has("link"):
			p = w.table("project")[pid]
	check(not p.is_empty(), "the project carries its link spec")
	if not p.is_empty():
		check_eq(int(p["est_cost"]), int(plan["cost"]), "billed from the route plan")
		check_eq(int(p["wu_total"]), int(plan["wu"]) * EconUtil.S, "work units from the route plan")


func test_bad_link_is_refused_with_a_reason() -> void:
	var w := _sim().world
	var err := EconActions.validate(w, "ECON_COMMISSION_PROJECT", {"type": "ROAD", "district": "d:1", "link": {"upgrade": "link:none"}})
	check(err != "", "an unknown link is refused: %s" % err)
