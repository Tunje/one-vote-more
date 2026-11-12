extends TestCase
## Hot issues (planning/spec-election-year-v1.md §11, owner Ella): immigration, slums and emigration heat up from the
## sim's facts, name debate questions and themes, and fade.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _sim() -> Simulation:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	sim.run(30)
	return sim


func _arrive(w: WorldState, persons: int) -> void:
	w.add_fact({"type": "ECON_MIGRANTS_ARRIVED", "owner": "econ", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 15, "visibility": "PUBLIC", "data": {"persons": persons, "channel": "ECON"}})


func test_a_wave_of_settlers_makes_immigration_hot_and_it_fades() -> void:
	var w := _sim().world
	var base := int(HotIssues.heat(w)["IMMIGRATION"])
	_arrive(w, PopStore.total(w) * 8 / 100)
	var hs := HotIssues.heat(w)
	check(int(hs["IMMIGRATION"]) >= HotIssues.HOT, "8%% of the colony arriving is hot (%d, was %d)" % [hs["IMMIGRATION"], base])
	check_eq(HotIssues.issue_for(hs, "HOUSING") in ["IMMIGRATION", "SLUMS"], true, "it names the housing question")
	check(int(HotIssues.concern_heat(hs)["HOUSING"]) >= int(hs["IMMIGRATION"]), "housing carries the heat")
	var m0 := w.month
	w.month = m0 + HotIssues.WINDOW
	check(int(HotIssues.heat(w)["IMMIGRATION"]) <= base + 50, "faded after %d months (%d)" % [HotIssues.WINDOW, HotIssues.heat(w)["IMMIGRATION"]])
	w.month = m0


func test_nothing_is_hot_below_the_line() -> void:
	check_eq(HotIssues.issue_for({"IMMIGRATION": HotIssues.HOT - 1}, "HOUSING"), "", "lukewarm is not hot")
	check_eq(HotIssues.issue_for({"IMMIGRATION": 400, "SLUMS": 900}, "HOUSING"), "SLUMS", "the hottest names it")
	check_eq(HotIssues.issue_for({"EMIGRATION": 900}, "HOUSING"), "", "another concern's issue")


func test_attacking_the_government_on_a_hot_issue_lands_better() -> void:
	var sim := _sim()
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	sim.run(1)
	var ps := PartyLife.active(w)
	check(ps.size() >= 2, "two parties")
	if ps.size() < 2:
		return
	var a: Dictionary = ps[0]
	var b: Dictionary = ps[1]
	st["government"] = {"members": [b["id"]], "pm_party": b["id"], "support": []}
	var c := {"parties": {a["id"]: {"themes": [], "target": b["id"]}}}
	var cs := Campaign.colony_concerns(w)
	cs[2] = {"HOUSING": 0}
	var cold := Campaign.stance_fit(w, st, c, a, "HOUSING", "ATTACK", cs)
	cs[2] = {"HOUSING": 1000}
	var hot := Campaign.stance_fit(w, st, c, a, "HOUSING", "ATTACK", cs)
	check(hot > cold or hot >= 0.8, "hot issue attack %.2f vs %.2f" % [hot, cold])


func test_a_hot_issue_names_the_debate_question_on_its_concern() -> void:
	var w := _sim().world
	_arrive(w, PopStore.total(w) * 20 / 100)
	var named := 0
	var housing := 0
	for k in 12:
		var c := {"election_month": w.month + 2 + k}
		var prep := Campaign.prepare_debate(w, c, 0)
		for q in prep["questions"]:
			if q["topic"] == "HOUSING":
				housing += 1
				if String(q.get("issue", "")) != "":
					named += 1
	check(housing > 0, "housing comes up (%d of 36)" % housing)
	check_eq(named, housing, "every housing question is about the hot issue")
