extends TestCase
## Who decides (planning/design-delegation.md, flag DELEGATION). Step 1: the decision-type registry and the case
## counter. Step 2: levels per type (presets, ceilings, hand-over), ministers answering the cases they may call, the
## term-start sheet and the monthly summary.

const EconSim := preload("res://sim/economy/econ_sim.gd")
const Desk := preload("res://sim/office/decision_desk.gd")
const OS_ := preload("res://sim/staff/office_staff.gd")


func _sim(on: bool) -> Simulation:
	var sim: Simulation = EconFace.sim_make(1, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(Desk.FLAG)
	return sim


func _case(w: WorldState, ref: String) -> String:
	return Office.post(w, {"kind": "EMAIL", "role": "LABOUR_LIAISON", "category": "UNION_DEMAND", "subject": "Test demand " + ref,
		"options": [{"id": "ACCEPT", "label": "Accept", "action": {}}, {"id": "REFUSE", "label": "Refuse", "action": {}}],
		"recommendation": "ACCEPT", "default_option": "REFUSE", "deadline": w.month + 2, "source": {"system": "TEST", "ref": ref}})


func test_registry_is_well_formed() -> void:
	for ty in Desk.TYPES:
		var d: Dictionary = Desk.TYPES[ty]
		check(String(d.get("name", "")) != "", "%s has a name" % ty)
		check(String(d["ceiling"]) in Desk.CEILINGS, "%s has a legal ceiling" % ty)
		var p := String(d["portfolio"])
		check(p == "FM" or OS_.ROLES.has(p), "%s belongs to a known office role (%s)" % [ty, p])
		if d.has("fallback"):
			check(OS_.PORTFOLIOS.has(String(d["fallback"])), "%s falls back to a standing portfolio" % ty)
	for f in Desk.BUILD_TYPE:
		check(Desk.TYPES.has(Desk.BUILD_TYPE[f]), "build type for %s is registered" % f)
	for s in Desk.SOURCE_TYPE:
		check(Desk.TYPES.has(Desk.SOURCE_TYPE[s]), "office source %s maps to a registered type" % s)
	check_eq(Desk.build_type("ROAD", "ECON_BUDGET_PUBLIC_WORKS"), "PUBLIC_WORKS", "public-works orders count as public works")
	check_eq(Desk.build_type("ROAD", "ECON_BUDGET_INFRASTRUCTURE"), "BUILD_ROAD", "road needs count as road works")


func test_agriculture_falls_back_to_the_economy_without_its_minister() -> void:
	var w := _sim(false).world
	check_eq(Desk.portfolio(w, "GRANT_COVERAGE"), "ECON_ADVISER", "no Minister of Agriculture: the Economy holds it")
	(w.meta["on"] as Array).append("AGRI_MIN")
	check_eq(Desk.portfolio(w, "GRANT_COVERAGE"), "AGRICULTURE", "with one: Agriculture holds it")
	check_eq(Desk.portfolio(w, "BILL"), "FM", "bills are the First Minister's")


func test_presets_respect_the_law() -> void:
	var bal := Desk.preset_levels("BALANCED")
	check_eq(bal["BUILD_ROAD"], "CALL", "balanced: routine road works are the minister's call")
	check_eq(bal["BUILD_HOUSING"], "SUGGEST", "balanced: a housing block comes as a suggestion")
	check_eq(Desk.preset_levels("TRUSTING")["COMPETITION_REVIEW"], "SUGGEST", "a Cabinet matter is never a minister's call alone")
	check_eq(Desk.preset_levels("TRUSTING")["CHARTER_PETITION"], "SUGGEST", "a Parliament matter neither")
	for ty in Desk.TYPES:
		check_eq(Desk.preset_levels("HANDS_ON")[ty], "ME", "hands-on keeps %s" % ty)
	var w := _sim(true).world
	check(not Desk.set_level(w, "COMPETITION_REVIEW", "CALL")["ok"], "the law refuses handing a merger over")
	check(Desk.set_level(w, "COMPETITION_REVIEW", "ME")["ok"], "keeping it is allowed")
	check(not Desk.set_level(w, "BILL", "SUGGEST")["ok"], "bills are the First Minister's own")
	check_eq(Desk.level(w, "BILL"), "ME", "and stay on the desk")
	check(not Desk.set_level(_sim(false).world, "BUILD_ROAD", "CALL")["ok"], "nothing to set without the flag")


func test_flag_off_writes_nothing() -> void:
	var off := _sim(false)
	off.run(72)
	for t in ["decision_case", "decision_who", "delegation"]:
		check(off.world.peek(t).is_empty(), "without the flag there is no %s table" % t)
	for o in off.world.peek("office_item").values():
		check(not (String(o["source"].get("system", "")) in ["delegation", "delegation_summary"]), "and no delegation items")


func test_a_term_of_ministers() -> void:
	var sim := _sim(true)
	sim.run(72)
	var w := sim.world
	var c := Desk.counts(w, 0, 71)
	check(Desk.total(c) > 0, "decisions are counted (%s)" % str(c))
	check(c.has("BILL") or c.has("ORDINANCE"), "laws are among them")
	var d: Dictionary = w.peek("delegation")
	check(String(d.get("sig", "")) != "", "a term has started (%s)" % str(d.get("sig", "")))
	check_eq(String(d.get("preset", "")), "BALANCED", "an AI government starts balanced")
	var labour := Desk.holder_person(w, "LABOUR_LIAISON")
	check(not labour.is_empty(), "the Labour portfolio is held")
	# make the call: the minister answers the same month, the First Minister reads it in the summary
	check(Desk.set_level(w, "UNION_DEMAND", "CALL")["ok"], "union demands handed to Labour")
	var a := _case(w, "a")
	Desk.monthly(w, true)
	var oa := Office.get_item(w, a)
	check_eq(String(oa["status"]), "DELEGATED", "the minister answered")
	check_eq(String(oa.get("answered_by", "")), String(labour.get("id", "")), "as the Minister of Labour")
	var decided: Array = d["summary"]["decided"]
	check(decided.any(func(x): return x["item"] == a), "the summary lists it")
	var rep := Office.items(w, ["REPORT"]).filter(func(o): return String(o["source"].get("system", "")) == "delegation_summary")
	check(not rep.is_empty(), "the player gets the monthly summary")
	check(int(Desk.who_counts(w, w.month, w.month).get("MINISTER", 0)) >= 1, "counted as a minister's decision")
	# give me a suggestion / leave it to me: the case waits on the desk
	Desk.set_level(w, "UNION_DEMAND", "SUGGEST")
	var b := _case(w, "b")
	Desk.monthly(w, true)
	var ob := Office.get_item(w, b)
	check(String(ob["status"]) in Office.OPEN, "a suggestion waits for the First Minister")
	check_eq(Desk.preselected(w, ob), String(ob["recommendation"]), "with the minister's choice pre-selected")
	check((d["summary"]["waiting"] as Array).any(func(x): return x["item"] == b), "and is listed as waiting")
	Desk.set_level(w, "UNION_DEMAND", "ME")
	check_eq(Desk.preselected(w, ob), "", "left to me: nothing pre-selected")
	check((d["changes"] as Array).size() >= 3, "mid-term changes are logged for step 4")
	# a vacant portfolio: the First Minister keeps it until it is handed over; outside a portfolio is marked
	w.table("office_role")["ENVIRONMENT"]["person"] = ""
	check_eq(Desk.level(w, "WILDLIFE_REVIEW"), "ME", "nobody in Environment: the desk keeps the wildlife review")
	var vac: Array = Desk.sheet(w).filter(func(g): return g["role"] == "")
	check(not vac.is_empty() and (vac[0]["types"] as Array).any(func(t): return t["type"] == "WILDLIFE_REVIEW"), "the sheet shows it unheld")
	check(not Desk.hand_over(w, "WILDLIFE_REVIEW", "ENVIRONMENT")["ok"] or Desk.holder_role(w, "WILDLIFE_REVIEW") == "ENVIRONMENT", "cannot hand it to the empty portfolio")
	check(Desk.hand_over(w, "WILDLIFE_REVIEW", "FINANCE")["ok"], "handed to Finance")
	check(Desk.outside_portfolio(w, "WILDLIFE_REVIEW"), "outside Finance's portfolio")
	check(Desk.level(w, "WILDLIFE_REVIEW") != "ME", "Finance now decides it at its level")


func test_term_start_sheet() -> void:
	var w := _sim(true).world
	Desk._term(w, true)
	var d: Dictionary = w.peek("delegation")
	var sid := String(d["setup_item"])
	check(sid != "", "the player gets the term-start sheet")
	check_eq(Office.answer(w, sid, "HANDS_ON")["ok"], true, "answered")
	Desk._term(w, true)
	check_eq(String(d["preset"]), "HANDS_ON", "the chosen preset applies")
	check_eq(String(d["levels"]["BUILD_ROAD"]), "ME", "hands-on: road works come to the desk")
	check_eq(String(d["setup_item"]), "", "the sheet is done")
	(w.table("pol")["state"] as Dictionary)["era"] = "PARLIAMENTARY_TEST"
	Desk._term(w, false)
	check_eq(String(d["preset"]), "BALANCED", "a new term starts from the preset again")
	check(String(d["setup_item"]) == "", "an AI First Minister gets no sheet")
	check_eq(Desk.case_type(Office.get_item(w, sid)), "", "the sheet itself is no government decision")


func test_save_load_keeps_the_desk() -> void:
	var a := _sim(true)
	a.run(30)
	Desk.set_level(a.world, "BUILD_HOUSING", "CALL")
	var path := "user://test_decision_desk.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var b := EconFace.sim_for_load()
	check_eq(SaveIO.load_into(b, path), OK, "loaded")
	check_eq(var_to_str(Desk.counts(b.world, 0, 29)), var_to_str(Desk.counts(a.world, 0, 29)), "the counter survives save/load")
	check_eq(Desk.level(b.world, "BUILD_HOUSING"), "CALL", "the levels survive save/load")
	a.step()
	b.step()
	check_eq(b.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
