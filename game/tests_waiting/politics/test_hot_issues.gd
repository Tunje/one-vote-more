extends TestCase
## Hot issues (planning/spec-election-year-v1.md §11, owner Ella): immigration, slums and emigration heat up from the
## sim's facts, name debate questions and themes, and fade.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _sim() -> Simulation:
	var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
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


# ---- workplace overload (Bob's 27-W ECON_OVERLOAD_INCIDENT; symmetric blame, A54) ----

func _overload(w: WorldState, owner_kind: String, owner: String, month: int = -1) -> void:
	w.facts.add(w.month if month < 0 else month, {"type": "ECON_OVERLOAD_INCIDENT", "owner": "econ", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 48, "visibility": "PUBLIC", "data": {"sector": "HEALTH", "facility": "f", "district": "d",
			"owner_kind": owner_kind, "owner": owner, "severity": 90, "persons": 12, "workload": 1600, "channel": "ECON"}})


func test_overload_incidents_heat_up_and_blame_falls_on_who_runs_the_workplace() -> void:
	var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
	sim.world.meta["off"] = ["WORKLOAD"]   # on in the full game since v8: start from a quiet colony
	sim.run(30)
	var w := sim.world
	check_eq(int(HotIssues.heat(w)["OVERLOAD"]), 0, "nothing while WORKLOAD is off")
	_overload(w, "PUBLIC", "org:state")
	_overload(w, "PUBLIC", "org:state")
	var hs := HotIssues.heat(w)
	var cn := HotIssues.concern("OVERLOAD")
	check(int(hs["OVERLOAD"]) >= HotIssues.HOT, "two fresh incidents are hot (%d)" % hs["OVERLOAD"])
	check_eq(HotIssues.issue_for(hs, cn), "OVERLOAD", "names the %s question" % cn)
	var ps := PartyLife.active(w)
	var g := String(ps[0]["id"])
	var o := String(ps[1]["id"])
	check_eq(HotIssues.blame(w, hs, cn, g, [g]), 1.0, "public clinics: the Cabinet answers")
	check_eq(HotIssues.blame(w, hs, cn, o, [g]), 0.0, "not the opposition")
	# a private firm's overload: its publicly funded party answers, government or not
	w.month += HotIssues.WINDOW
	_overload(w, "PRIVATE", "org:firm")
	_overload(w, "PRIVATE", "org:firm")
	w.add_fact({"type": "POL_DONATION", "owner": "pol", "subjects": [], "responsible": [], "impact": {}, "magnitude": 20,
		"visibility": "PUBLIC", "data": {"donor": "org:firm", "party": o, "amount": 1000, "lawful": true}})
	hs = HotIssues.heat(w)
	check_eq(HotIssues.blame(w, hs, cn, o, [g]), 1.0, "the firm's party in opposition answers")
	check_eq(HotIssues.blame(w, hs, cn, g, [g]), 0.0, "the Cabinet does not, for a private firm")
	# other issues stay as they were: the government answers
	check_eq(HotIssues.blame(w, {}, "HOUSING", g, [g]), 1.0, "unchanged elsewhere")
	check_eq(HotIssues.blame(w, {}, "HOUSING", o, [g]), 0.0, "unchanged elsewhere")


func test_overload_is_bursts_above_the_usual_rate() -> void:
	var sim: Simulation = EconFace.sim_make(3, "BALANCED", {}, true)
	sim.world.meta["off"] = ["WORKLOAD"]
	sim.run(30)
	var w := sim.world
	w.month += 60
	for k in range(2, HotIssues.OVERLOAD_RECENT + HotIssues.OVERLOAD_BASE, 2):   # one incident every two months
		_overload(w, "PUBLIC", "org:state", w.month - k)
	check(int(HotIssues.heat(w)["OVERLOAD"]) < HotIssues.HOT, "the usual drone is not hot (%d)" % HotIssues.heat(w)["OVERLOAD"])
	for i in 3:
		_overload(w, "PUBLIC", "org:state")
	check(int(HotIssues.heat(w)["OVERLOAD"]) >= HotIssues.HOT, "a burst above it is (%d)" % HotIssues.heat(w)["OVERLOAD"])
	w.month += HotIssues.OVERLOAD_RECENT
	check(int(HotIssues.heat(w)["OVERLOAD"]) < HotIssues.HOT, "and it passes")


func test_the_overload_label_names_who_and_how_long() -> void:
	var w := _sim().world
	var clinic := ""
	for fid in w.peek("facility"):
		if String(w.peek("facility")[fid]["type"]) == "CLINIC":
			clinic = String(fid)
			break
	check(clinic != "", "a clinic")
	w.add_fact({"type": "ECON_OVERLOAD_INCIDENT", "owner": "econ", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 48, "visibility": "PUBLIC", "data": {"sector": "PUBLIC_SECTOR", "facility": clinic, "district": "d",
			"owner_kind": "PUBLIC", "owner": "x", "severity": 90, "persons": 12, "workload": 1600, "channel": "ECON"}})
	check_eq(HotIssues.label_now(w, "OVERLOAD"), "nurses working 64-hour weeks", "the news line")
	check_eq(HotIssues.label_now(w, "SLUMS"), HotIssues.label("SLUMS"), "others unchanged")
