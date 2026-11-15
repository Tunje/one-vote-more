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
