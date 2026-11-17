extends TestCase
## Rivalries and grudges between parties (RIVALRY; user 2026-11-15).

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world() -> WorldState:
	var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
	sim.run(72)
	if not (sim.world.meta["on"] as Array).has("RIVALRY"):
		(sim.world.meta["on"] as Array).append("RIVALRY")
	(sim.world.table("pol")["state"] as Dictionary).erase("grudge")   # on by default since v11: start from no grudges
	return sim.world


func _two(w: WorldState) -> Array:
	var st: Dictionary = w.table("pol")["state"]
	var gov: Dictionary = st["government"]
	var pm := String(gov["pm_party"])
	for pid in CoreUtil.sorted_keys(w.table("party")):
		var p: Dictionary = w.table("party")[pid]
		if not (pid in gov["members"]) and p["status"] == "ACTIVE" and int(p["seats"]) > 0:
			return [pm, String(pid)]
	return [pm, ""]


func test_opposite_positions_make_rivals() -> void:
	var a := {"positions": {"ECON_ROLE": 80000, "REDISTRIBUTION": 70000, "LABOR": 60000}}
	var b := {"positions": {"ECON_ROLE": -80000, "REDISTRIBUTION": -70000, "LABOR": -60000}}
	var c := {"positions": {"ECON_ROLE": 70000, "REDISTRIBUTION": 60000, "LABOR": 60000}}
	check(Rivalry.opposition_pm(a, b) > Rivalry.opposition_pm(a, c) + 300, "far apart: %d, close: %d" % [Rivalry.opposition_pm(a, b), Rivalry.opposition_pm(a, c)])
	check_eq(Rivalry.opposition_pm(a, a), 0, "none with itself")
	check_eq(Rivalry.opposition_pm(a, b), Rivalry.opposition_pm(b, a), "the same both ways")


func test_off_without_the_flag() -> void:
	var w: WorldState = EconFace.sim_make(3, "BALANCED", {}, true).world
	(w.meta["on"] as Array).erase("RIVALRY")   # on by default since v11
	var h := w.state_hash()
	Rivalry.on_vote(w, {"votes": {"party:1": "NO"}, "status": "DEFEATED"}, {"members": ["party:2"], "pm_party": "party:2"})
	Rivalry.monthly(w, w.table("pol")["state"])
	check_eq(w.state_hash(), h, "nothing written")
	check_eq(Rivalry.score(w, "party:1", "party:2"), 0, "no score")
	check_eq(Rivalry.main_rival(w, "party:1"), "", "no rival")


func test_a_no_vote_is_remembered_and_fades() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var two := _two(w)
	check(two[1] != "", "an opposition party with seats")
	var pm: String = two[0]
	var opp: String = two[1]
	var before := Rivalry.score(w, pm, opp)
	var gov: Dictionary = st["government"]
	for i in 3:
		Rivalry.on_vote(w, {"votes": {opp: "NO"}, "status": "PASSED"}, gov)
	check_eq(Rivalry.grudge(w, pm, opp), 3 * Rivalry.G_NO, "the government holds three NO votes against them")
	check_eq(Rivalry.grudge(w, opp, pm), 3 * Rivalry.G_OUTVOTED, "and being outvoted is held against the government")
	check(Rivalry.score(w, pm, opp) > before, "the rivalry grows")
	var g0 := Rivalry.grudge(w, pm, opp)
	st.erase("government")          # no decisions to question in this check
	Rivalry.monthly(w, st)
	check(Rivalry.grudge(w, pm, opp) < g0, "it fades with time")
	st["government"] = gov
	Rivalry.on_vote(w, {"votes": {opp: "YES"}, "status": "PASSED"}, gov)
	check(Rivalry.grudge(w, pm, opp) < g0 - 20, "voting with the government mends it")


func test_a_partner_voting_no_is_a_betrayal() -> void:
	var w := _world()
	var gov := {"pm_party": "party:1", "members": ["party:1", "party:2"]}
	Rivalry.on_vote(w, {"votes": {"party:1": "YES", "party:2": "NO", "party:3": "NO"}, "status": "DEFEATED"}, gov)
	check_eq(Rivalry.grudge(w, "party:1", "party:2"), Rivalry.G_BETRAYAL, "a partner's NO weighs most")
	check_eq(Rivalry.grudge(w, "party:1", "party:3"), Rivalry.G_NO, "the opposition's NO is ordinary")
	check_eq(Rivalry.grudge(w, "party:3", "party:1"), 0, "a defeated bill overrode nobody")


func test_the_opposition_questions_a_decision() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var two := _two(w)
	var pm: String = two[0]
	var from_m := w.month
	var asked := 0
	for i in 24:
		w.add_fact({"type": "POL_ROAD_PATCHED", "owner": "pol", "subjects": [], "responsible": [], "impact": {}, "magnitude": 25,
			"visibility": "PUBLIC", "data": {"district": "d:1"}})
		Rivalry.monthly(w, st)
		asked = w.facts.query("POL_DECISION_QUESTIONED", from_m).filter(func(x): return String(x["data"]["about"]) == "POL_ROAD_PATCHED").size()
		w.month += 1
	check(asked > 0, "over two years somebody questions a patched road (%d)" % asked)
	if asked > 0:
		var f: Dictionary = w.facts.query("POL_DECISION_QUESTIONED", from_m).filter(func(x): return String(x["data"]["about"]) == "POL_ROAD_PATCHED")[0]
		check_eq(String(f["data"]["against"]), pm, "the First Minister's party is asked")
		check(not (String(f["data"]["by"]) in st["government"]["members"]), "by a party outside the Cabinet")
		check_eq(String(f["data"]["about"]), "POL_ROAD_PATCHED", "about the decision")
		check(Rivalry.grudge(w, pm, String(f["data"]["by"])) > 0, "the government holds it against them")


func test_in_the_game_deterministic_and_save_load() -> void:
	var sims: Array = []
	for i in 2:
		var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
		(sim.world.meta["on"] as Array).append("RIVALRY")
		sim.run(84)
		sims.append(sim)
	check_eq(sims[0].world.state_hash(), sims[1].world.state_hash(), "deterministic")
	var w: WorldState = sims[0].world
	check(not (w.table("pol")["state"].get("grudge", {}) as Dictionary).is_empty(), "grudges formed in seven years")
	var path := "user://test_rivalry.sav"
	check_eq(SaveIO.save(sims[0], path), OK, "saved")
	var c := EconFace.sim_for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	sims[0].run(12)
	c.run(12)
	check_eq(c.world.state_hash(), sims[0].world.state_hash(), "a saved game continues the same")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
