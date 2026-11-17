extends TestCase
## Politics of the food pyramid (ECO stage 2; user 2026-11-15): blame for wildlife attacks, alarm at a collapse, and
## the government's yearly choice between PROTECT, MANAGE and CULL.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world() -> WorldState:
	var sim: Simulation = EconFace.sim_make(4, "BALANCED", {}, true)
	sim.run(60)
	(sim.world.meta["on"] as Array).append("ECO")
	return sim.world


func _attack(w: WorldState, killed: int, policy: String, grant_month: int) -> void:
	w.add_fact({"type": "PLANET_WILDLIFE_ATTACK", "owner": "planet", "subjects": [], "responsible": [], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"creature": "dusk stalker", "danger": 3, "killed": killed, "injured": 1, "site": "FAMFARM",
			"district": "d:2", "place": "", "family_farm": true, "grant_funded": grant_month >= 0, "grant_month": grant_month, "policy": policy}})


func test_what_a_government_wants() -> void:
	check_eq(GovWildlife.target(0.8, 0.0, 0.0, 1.0), "PROTECT", "a planet-first government with a quiet year protects")
	check_eq(GovWildlife.target(-0.6, 3.0, 2.0, 1.0), "CULL", "a development-minded government after deaths culls")
	check_eq(GovWildlife.target(0.0, 1.0, 0.0, 1.0), "MANAGE", "a centrist government with one attack manages")
	check_eq(GovWildlife.target(0.2, 0.0, 0.0, 0.2), "PROTECT", "a collapsing food web pulls toward protection")
	check_eq(GovWildlife.target(0.8, 2.0, 3.0, 1.0), "MANAGE", "deaths pull even a planet-first government off PROTECT")


func test_blame_follows_policy_and_a_fresh_grant() -> void:
	var cull := GovWildlife.blame_share("CULL", false, -1)
	var manage := GovWildlife.blame_share("MANAGE", false, -1)
	var protect := GovWildlife.blame_share("PROTECT", false, -1)
	check(cull < manage and manage < protect, "protecting predators costs a government more when they kill (%.2f < %.2f < %.2f)" % [cull, manage, protect])
	check(GovWildlife.blame_share("MANAGE", true, 12) > manage, "the farm the government just funded: more blame")
	check_eq(GovWildlife.blame_share("MANAGE", true, 200), manage, "an old grant adds nothing")


func test_an_attack_becomes_an_outcry_once() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	st["wildlife_seen_m"] = w.month - 1
	_attack(w, 1, "PROTECT", w.month - 6)
	GovWildlife.monthly(w, st)
	var out: Array = w.facts.query("POL_WILDLIFE_OUTCRY")
	check_eq(out.size(), 1, "one outcry for one attack")
	if out.size() == 1:
		check(int(out[0]["impact"].get("SAFETY", 0)) < 0, "people feel less safe")
		check(bool(out[0]["data"]["fresh_grant"]), "it says the farm was just funded")
		check(float(out[0]["responsible"][0]["share"]) >= 0.7, "a protecting government that funded the farm carries most of it")
	w.month += 1
	GovWildlife.monthly(w, st)
	check_eq(w.facts.query("POL_WILDLIFE_OUTCRY").size(), 1, "not reported twice")
	check(not GovWildlife.on(EconFace.sim_make(4, "BALANCED", {}, true).world), "off unless ECO is switched on")


func test_a_deadly_year_brings_a_culling_bill() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	check(w.lever_defs.has(GovWildlife.LEVER), "the policy lever exists")
	var g: Dictionary = st["government"]
	check(not g.is_empty(), "an elected government")
	g["center"]["ENVIRONMENT"] = -70000
	st["wildlife_seen_m"] = w.month - 1
	_attack(w, 2, "MANAGE", -1)
	_attack(w, 1, "MANAGE", -1)
	var bills_before := w.table("bill").size()
	GovWildlife.monthly(w, st)
	check_eq(w.table("bill").size(), bills_before + 1, "the government tables a wildlife bill after deaths")
	var found := false
	for b in w.table("bill").values():
		for c in b.get("clauses", []):
			if String(c["lever"]) == GovWildlife.LEVER:
				found = true
				check_eq(String(c["to"]), "CULL", "one step from MANAGE toward CULL")
	check(found, "the bill carries the wildlife policy")


func test_the_birds_did_not_come() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	st["wildlife_seen_m"] = w.month - 1
	for own in [true, false]:
		w.add_fact({"type": "PLANET_BIRDS_FAILED", "owner": "planet", "subjects": [], "responsible": [], "impact": {}, "magnitude": 30,
			"visibility": "PUBLIC", "data": {"flock": 0, "name": "bell cranes", "role": "BREEDS", "size": 300, "last_year": 900,
				"worst_hex": 1, "worst_harm": 500, "worst_is_colony": own}})
	GovWildlife.monthly(w, st)
	var out: Array = w.facts.query("POL_BIRDS_MISSED")
	check_eq(out.size(), 2, "each failed arrival is noticed")
	if out.size() == 2:
		check(float(out[0]["responsible"][0]["share"]) > float(out[1]["responsible"][0]["share"]), "the government carries more when the colony's own land is the worst on the route")
		check(int(out[0]["impact"].get("ENVIRONMENT_QUALITY", 0)) < int(out[1]["impact"].get("ENVIRONMENT_QUALITY", 0)), "and it weighs more on people")

