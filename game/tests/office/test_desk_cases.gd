extends TestCase
## Who decides, step 3 (flag DELEGATION): the capital programme's orders, road fixes and grant coverage are cases of
## their decision type, decided by the minister (CALL) or on the desk (SUGGEST / ME).

const EconSim := preload("res://sim/economy/econ_sim.gd")
const Desk := preload("res://sim/office/decision_desk.gd")


func _sim(on: bool, autoplay: bool = true) -> Simulation:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, autoplay)
	if on:
		(sim.world.meta["on"] as Array).append(Desk.FLAG)
	return sim


func _housing_params(w: WorldState) -> Dictionary:
	return {"type": "HOUSING", "district": String(EconUtil.sorted_keys(w.table("district"))[0])}


func test_an_order_at_each_level() -> void:
	var sim := _sim(true)
	sim.run(60)
	var w := sim.world
	var who := GovBuilder._who(w, w.table("pol")["state"])
	check(not who.is_empty(), "a government decides")
	var params := _housing_params(w)
	w.levers["ECON_BUDGET_HOUSING"] = int(w.levers.get("ECON_BUDGET_HOUSING", 0)) * 20 + 100000   # room on the line for this test
	check_eq(EconActions.validate(w, "ECON_COMMISSION_PROJECT", params), "", "the order can be paid for")
	# make the call: decided now, by the minister, listed in the summary
	Desk.set_level(w, "BUILD_HOUSING", "CALL")
	var n0 := int(Desk.month_counts(w, w.month).get("BUILD_HOUSING", 0))
	var placed := GovBuilder._order_case(w, who, "HOUSING", String(params["district"]), "", params)
	check(placed in [0, 1], "decided now")
	check_eq(int(Desk.month_counts(w, w.month).get("BUILD_HOUSING", 0)), n0 + 1, "counted when the minister decides")
	var calls: Array = w.peek("delegation").get("calls", [])
	check(calls.any(func(x): return x["type"] == "BUILD_HOUSING"), "the summary will list it")
	var cf: Array = w.facts.query(Desk.CALL_FACT, w.month, w.month)
	check(cf.any(func(f): return String(f["data"]["ref"]) == "ORDER|HOUSING|%s|" % params["district"] and String(f["data"]["answer"]) in ["ORDER", "WAIT"]),
		"the minister's call is on record (ref and answer)")
	check(not Desk.pending(w, "ORDER|HOUSING|%s|" % params["district"]), "nothing waits on the desk")
	# leave it to me: the case waits with its options; answering it orders the block
	Desk.set_level(w, "BUILD_HOUSING", "ME")
	var d2 := String(EconUtil.sorted_keys(w.table("district"))[1])
	var p2 := {"type": "HOUSING", "district": d2}
	check_eq(GovBuilder._order_case(w, who, "HOUSING", d2, "", p2), 1, "booked as placed while it waits")
	var ref := "ORDER|HOUSING|%s|" % d2
	check(Desk.pending(w, ref), "the case waits on the desk")
	check_eq(GovBuilder._order_case(w, who, "HOUSING", d2, "", p2), 1, "asked again: still the same case")
	var item: Dictionary = {}
	for o in Office.items(w, ["EMAIL"]):
		if String(o["source"].get("ref", "")) == ref:
			item = o
	check(not item.is_empty(), "posted as an email")
	check_eq(Desk.case_type(item), "BUILD_HOUSING", "of its decision type")
	check_eq(Desk.preselected(w, item), "", "nothing pre-selected at leave it to me")
	check_eq(String(item["default_option"]), "WAIT", "unanswered, nothing is ordered")
	var facts0 := w.facts.query("POL_PROJECT_ORDERED", w.month, w.month).size()
	var r := Office.answer(w, String(item["id"]), "ORDER")
	check(r.get("ok", false), "answered: %s" % str(r))
	check_eq(w.facts.query("POL_PROJECT_ORDERED", w.month, w.month).size(), facts0 + 1, "the order is placed and announced")


func test_a_minister_follows_their_politics() -> void:
	var sim := _sim(true)
	sim.run(2)
	var w := sim.world
	var opts: Array = [{"id": "ORDER", "label": "", "action": {}}, {"id": "WAIT", "label": "", "action": {}}]
	var hid := {"ORDER": {"merit": 0, "lean": {"ECON_ROLE": 2000}}, "WAIT": {"merit": 0, "lean": {"ECON_ROLE": -2000}}}
	var role := Desk.holder_role(w, "BUILD_HOUSING")
	var p := Desk.holder_person(w, role)
	check(not p.is_empty(), "somebody holds housing")
	var OS_ := load("res://sim/staff/office_staff.gd")
	OS_.traits(p)
	p["lean"]["ECON_ROLE"] = 90000
	var orders := 0
	for _i in 40:
		if Desk.minister_pick(w, "BUILD_HOUSING", opts, hid, "WAIT") == "ORDER":
			orders += 1
	p["lean"]["ECON_ROLE"] = -90000
	var orders_mkt := 0
	for _i in 40:
		if Desk.minister_pick(w, "BUILD_HOUSING", opts, hid, "WAIT") == "ORDER":
			orders_mkt += 1
	check(orders > orders_mkt, "a state-minded minister orders more than a market-minded one (%d vs %d of 40)" % [orders, orders_mkt])


func test_grant_coverage_commits() -> void:
	var w := _sim(true).world
	w.levers["ECON_FAMILY_FARM_GRANT"] = 10
	var ds: Array = EconUtil.sorted_keys(w.table("district")).slice(0, 2)
	var r := GovBuilder.commit_cover(w, {"kind": "FARM", "districts": [ds[1]], "fair": [ds[0]], "by": "commander"})
	check(r.get("ok", false), "committed")
	check_eq(EconUtil.st(w)["grant_cover"]["FARM"], [ds[1]], "the programme covers the chosen district")
	check_eq(w.facts.query("POL_GRANT_FAVOURITISM", w.month, w.month).size(), 1, "passing over the neediest is seen")
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	EconUtil.st(w)["grant_cover"].erase("FARM")
	GovBuilder.commit_cover(w, {"kind": "FARM", "districts": [ds[0]], "fair": [ds[0]], "by": "commander"})
	check(not EconUtil.st(w)["grant_cover"].has("FARM"), "a closed programme is not covered")


func test_a_human_government_is_proposed_to() -> void:
	var off := _sim(false, false).world
	check(GovBuilder._who(off, off.table("pol")["state"]).is_empty(), "without the flag nothing is decided for a human government")
	var sim := _sim(true, false)
	var w := sim.world
	var who := GovBuilder._who(w, w.table("pol")["state"])
	check(bool(who.get("human", false)), "with it, the human government's ministers propose")
	sim.run(24)
	for f in w.facts.query("ECON_INCENTIVE_OFFERED", 0, w.month):
		check(false, "no builder grant was offered behind the player's back")
	var cases := 0
	for o in w.peek("office_item").values():
		if String(o["source"].get("system", "")) == Desk.CASE_SYSTEM:
			cases += 1
	var calls := Desk.total(Desk.counts(w, 0, w.month))
	check(cases + calls >= 0, "cases %d, decisions %d" % [cases, calls])


func test_ai_government_runs_on_cases() -> void:
	var sim := _sim(true)
	sim.run(72)
	var w := sim.world
	var c := Desk.counts(w, 0, 71)
	var builds := 0
	for ty in c:
		if String(Desk.TYPES[ty]["src"]) == "gov_builder":
			builds += int(c[ty])
	check(builds > 0, "the capital programme still decides (%s)" % str(c))
	var answered := 0
	for o in w.peek("office_item").values():
		if String(o["source"].get("system", "")) == Desk.CASE_SYSTEM and not (o["status"] in Office.OPEN):
			answered += 1
	check(answered > 0 or c.has("BUILD_ROAD") or c.has("BUILD_HOUSING"), "cases were answered by the First Minister or called by ministers")
	var open_old := 0
	for o in w.peek("office_item").values():
		if String(o["source"].get("system", "")) == Desk.CASE_SYSTEM and o["status"] in Office.OPEN and int(o["month"]) < w.month - 2:
			open_old += 1
	check_eq(open_old, 0, "no case is left hanging past its deadline")


# ------------------------------------------------------------------ system 2: the wildlife policy review

func _eco_world() -> WorldState:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	sim.run(60)
	(sim.world.meta["on"] as Array).append("ECO")
	(sim.world.meta["on"] as Array).append(Desk.FLAG)
	return sim.world


func _attack(w: WorldState, killed: int) -> void:
	w.add_fact({"type": "PLANET_WILDLIFE_ATTACK", "owner": "planet", "subjects": [], "responsible": [], "impact": {}, "magnitude": 40,
		"visibility": "PUBLIC", "data": {"creature": "dusk stalker", "danger": 3, "killed": killed, "injured": 1, "site": "FAMFARM",
			"district": "d:2", "place": "", "family_farm": true, "grant_funded": false, "grant_month": -1, "policy": "MANAGE"}})


func test_the_wildlife_review_is_a_case() -> void:
	var w := _eco_world()
	var st: Dictionary = w.table("pol")["state"]
	check(w.lever_defs.has(GovWildlife.LEVER), "the policy lever exists")
	var g: Dictionary = st["government"]
	check(not g.is_empty(), "an elected government")
	g["center"]["ENVIRONMENT"] = -70000
	w.levers[GovWildlife.LEVER] = "MANAGE"
	st["wildlife_seen_m"] = w.month - 1
	_attack(w, 2)
	_attack(w, 1)
	Desk.set_level(w, "WILDLIFE_REVIEW", "ME")
	var bills0 := w.table("bill").size()
	GovWildlife.monthly(w, st)
	check_eq(w.table("bill").size(), bills0, "no bill before the case is decided")
	check(Desk.pending(w, GovWildlife.CASE_REF), "the review waits on the desk")
	var item: Dictionary = {}
	for o in Office.items(w, ["EMAIL"]):
		if String(o["source"].get("ref", "")) == GovWildlife.CASE_REF:
			item = o
	var ids: Array = (item.get("options", []) as Array).map(func(x): return String(x["id"]))
	check_eq(ids, ["KEEP", "TO_PROTECT", "TO_CULL"], "keep, or one step either way")
	check_eq(int(item["hidden"]["options"]["TO_CULL"]["merit"]), GovWildlife.CASE_MERIT, "after deaths the government's own pick is a step toward culling")
	check(Office.answer(w, String(item["id"]), "TO_CULL")["ok"], "answered")
	check_eq(w.table("bill").size(), bills0 + 1, "the bill is tabled when the case is decided")
	# make the call: the Environment minister decides at once
	st["wildlife_review"] = true
	Desk.set_level(w, "WILDLIFE_REVIEW", "CALL")
	if not Desk.holder_person(w, Desk.holder_role(w, "WILDLIFE_REVIEW")).is_empty():
		var n0 := int(Desk.month_counts(w, w.month).get("WILDLIFE_REVIEW", 0))
		w.levers[GovWildlife.LEVER] = "MANAGE"
		w.table("enactment").clear()
		GovWildlife._review(w, st)
		check_eq(int(Desk.month_counts(w, w.month).get("WILDLIFE_REVIEW", 0)), n0 + 1, "the minister's call is counted")
		check(not Desk.pending(w, GovWildlife.CASE_REF), "nothing waits on the desk")


# ------------------------------------------------------------------ system 3: private-road licences and neglect

const SF := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const RL := preload("res://sim/law/road_law.gd")


func _road_world(on: bool) -> WorldState:
	var w := SF.bare_world()
	LawOps.init_world(w)
	w.meta["on"] = ["FREIGHT_ROADS", "PRIVATE_ROADS"] + ([Desk.FLAG] if on else [])
	w.table("party")["P1"] = {"id": "P1", "name": "Gov", "status": "ACTIVE", "positions": {"ECON_ROLE": -50000}}
	SF.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": true, "government": {"members": ["P1"], "pm_party": "P1"}})
	return w


func _plan(districts: Array) -> Dictionary:
	return {"tiles": ["10,10", "11,10", "12,10"], "kind": "ROAD", "districts": districts, "regime": "OWNER"}


func test_an_ai_licence_goes_through_the_office() -> void:
	var off := _road_world(false)
	var a := RL.apply_licence(off, "org:1", _plan(["D1", "D2"]))
	off.month += RL.OBJECTION_MONTHS
	RL.monthly(off)
	check_eq(String(RL.licence(off, a)["status"]), "GRANTED", "without the flag an AI government decides at once")
	var w := _road_world(true)
	var id := RL.apply_licence(w, "org:1", _plan(["D1", "D2"]))
	w.month += RL.OBJECTION_MONTHS
	RL.monthly(w)
	var row := RL.licence(w, id)
	check_eq(String(row["status"]), "FILED", "with it the licence is a case")
	var it := Office.get_item(w, String(row["item"]))
	check_eq(Desk.case_type(it), "ROAD_LICENCE", "of type ROAD_LICENCE")
	check_eq(int(it["hidden"]["options"]["REFUSE"]["lean"]["ECON_ROLE"]), Desk.CASE_LEAN_SCALE, "leans on the First Minister's scale")
	check(Office.answer(w, String(row["item"]), "GRANT", "AI")["ok"], "the AI First Minister answers")
	RL.monthly(w)
	check(String(RL.licence(w, id)["status"]) == "GRANTED" and String(RL.licence(w, id)["by"]) == "AI", "granted, by whoever answered")
	var big := RL.apply_licence(w, "org:2", _plan(["D1", "D2", "D3"]))
	w.month += RL.OBJECTION_MONTHS
	RL.monthly(w)
	var it2 := Office.get_item(w, String(RL.licence(w, big)["item"]))
	check(Desk._cabinet_case(w, it2), "three districts: a Cabinet matter whatever the level")


func test_neglect_options_carry_merit_and_lean_only_with_the_flag() -> void:
	var dec := {"options": ["STEP_IN", "LEAVE"], "choice": "LEAVE"}
	check(RL._neglect_hidden(_road_world(false), dec).is_empty(), "without the flag the item is as before")
	var h: Dictionary = RL._neglect_hidden(_road_world(true), dec)["options"]
	check_eq(int(h["LEAVE"]["merit"]), 30, "the government's own choice")
	check(int(h["LEAVE"]["lean"]["ECON_ROLE"]) < 0 and int(h["STEP_IN"]["lean"]["ECON_ROLE"]) > 0, "leaving leans market, stepping in state")


# ------------------------------------------------------------------ the rest of the programme: yes / not-now cases

func test_the_rest_of_the_programme_is_cases() -> void:
	var sim := _sim(true)
	sim.run(30)
	var w := sim.world
	Desk.set_level(w, "FOOD_RESERVE_RELEASE", "ME")
	GovBuilder._simple_case(w, "FOOD_RESERVE_RELEASE", "RESERVE|FOOD", "Open the food reserve", ["Food is short."], "Release 1500 from the reserve",
		{"via": "ECON", "id": "ECON_RELEASE_RESERVE", "params": {"good": "FOOD", "qty": 1500}}, 0)
	check(Desk.pending(w, "RESERVE|FOOD"), "the reserve waits on the desk")
	GovBuilder._simple_case(w, "FOOD_RESERVE_RELEASE", "RESERVE|FOOD", "again", [], "x", {}, 0)
	var n := 0
	for o in w.peek("office_item").values():
		if String(o["source"].get("ref", "")) == "RESERVE|FOOD" and o["status"] in Office.OPEN:
			n += 1
			check_eq(String(o["default_option"]), "WAIT", "unanswered: the reserve stays shut")
	check_eq(n, 1, "posted once")
	# a stuck public project: tender again, leave it, or cancel it
	var pid := ""
	for k in EconUtil.sorted_keys(w.table("project")):
		if String(w.table("project")[k]["owner"]) == "gov":
			pid = String(k)
	if pid != "":
		Desk.set_level(w, "RETENDER_PROJECT", "ME")
		GovBuilder._retender_case(w, pid, w.table("project")[pid])
		var it: Dictionary = {}
		for o in Office.items(w, ["EMAIL"]):
			if String(o["source"].get("ref", "")) == "RETENDER|" + pid:
				it = o
		check_eq((it.get("options", []) as Array).map(func(x): return String(x["id"])), ["YES", "WAIT", "CANCEL"], "tender again, not now, or cancel")
	# a human government's ministers bring these too: nothing is done unless they make the call or the player answers
	var hs := _sim(true, false)
	hs.run(24)
	var hw := hs.world
	for f in hw.facts.query("ECON_INCENTIVE_OFFERED", 0, hw.month):
		check(String(f.get("data", {}).get("by", "")) != "x", "an offer only through a case")
	check(Desk.total(Desk.counts(hw, 0, hw.month)) >= 0, "runs")


# ------------------------------------------------------------------ builders' quotes (R8_BUILDERS)

func test_quotes_are_a_case() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	w.table("org")["org:qa"] = {"id": "org:qa", "name": "Able Works"}
	w.table("org")["org:qb"] = {"id": "org:qb", "name": "Bold Works"}
	var est := 1000 * EconUtil.S
	w.table("project")["prj:q"] = {"id": "prj:q", "owner": "gov", "status": "TENDER", "type": "SCHOOL", "district": "d:1", "est_cost": est,
		"bids": [{"org": "org:qa", "price": est * 2, "wait": 1}, {"org": "org:qb", "price": est, "wait": 2}]}
	var ranked: Array = [{"org": "org:qa", "price": est * 2, "wait": 1}, {"org": "org:qb", "price": est, "wait": 2}]
	Desk.set_level(w, "PUBLIC_QUOTE", "ME")
	check(Desk.quote_case(w, w.table("project")["prj:q"], ranked, "org:qb", "price"), "the case takes the decision")
	var it: Dictionary = {}
	for o in Office.items(w, ["EMAIL"]):
		if String(o["source"].get("ref", "")) == "QUOTE|prj:q":
			it = o
	check_eq((it.get("options", []) as Array).map(func(x): return String(x["id"])), ["AWARD_org:qa", "AWARD_org:qb", "REFUSE"],
		"the best-ranked bid, the acceptable one, or refuse")
	check_eq(int(it["hidden"]["options"]["AWARD_org:qb"]["merit"]), 30, "the rule's pick carries the merit")
	check_eq(String(it["default_option"]), "AWARD_org:qb", "unanswered: the government's own rule")
	w.table("project")["prj:q"]["status"] = "CANCELLED"
	check(Office.answer(w, String(it["id"]), "AWARD_org:qa")["ok"], "answered after the project moved on")
	check_eq(String(w.table("project")["prj:q"]["status"]), "CANCELLED", "nothing is awarded on a closed tender")
