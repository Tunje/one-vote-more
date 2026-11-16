extends TestCase
## The eight rules for public institutions (sim/economy/econ_institutions.gd, switch R8_INSTITUTIONS with R8): crews
## follow the clients within the line, budget requests, plants to build, plants to close.

const EconInst := preload("res://sim/economy/econ_institutions.gd")
const SAVE_PATH := "user://test_rules_inst.save"
const Desk := preload("res://sim/office/decision_desk.gd")


func _sim(extra: Array = []) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["R8", "R8_INSTITUTIONS"] + extra
	return sim


func _clinics(w: WorldState) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "CLINIC":
			out.append(w.table("facility")[fid])
	return out


func test_off_without_the_switch() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["R8"]
	sim.run(4)
	check(not EconUtil.st(sim.world).has("r8_inst"), "R8 alone: the institutions' rules do not run")
	var f: Dictionary = _clinics(sim.world)[0]
	check_eq(EconInst.target(sim.world, f, 0.42), 0.42, "the budget ratio stands")


func test_crews_follow_the_clients_when_the_line_pays() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	sim.run(3)
	var f: Dictionary = _clinics(w)[0]
	var d := String(f["district"])
	var t := int(EconUtil.st(w)["r8_inst"]["t"][f["id"]])
	var row: Dictionary = EconInst.needs(w)["CLINIC"][d]
	check(t > 0 and t <= 1000, "crew share in range (%d)" % t)
	check_eq(int(f["T"]), t, "FirmAI runs the clinic at the rules' share")
	# more room than clients: the crew falls with it
	f["scale"] = int(f.get("scale", 1000)) * 3
	EconInst.monthly(w)
	var t3 := int(EconUtil.st(w)["r8_inst"]["t"][f["id"]])
	check(t3 < t, "three times the room, a smaller crew share (%d -> %d)" % [t, t3])
	check(int(row["clients"]) > 0, "the district's clients are counted")


func test_a_short_line_cuts_every_ask_and_asks_for_more() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(1)
	w.levers["ECON_BUDGET_HEALTH"] = 10
	for i in EconInst.p("req_hold_m"):
		EconInst.monthly(w)
	var req: Dictionary = {}
	for q in EconInst.budget_requests(w):
		if q["line"] == "ECON_BUDGET_HEALTH":
			req = q
	check(not req.is_empty(), "a request row for the health line")
	check(bool(req.get("due", false)), "after %d months short, the request falls due" % EconInst.p("req_hold_m"))
	check(int(req.get("ask", 0)) > 10, "it asks for more than the line (%d)" % int(req.get("ask", 0)))
	check(int(req.get("unmet", 0)) > 0, "people go unserved")
	check(int(EconUtil.st(w)["lever_need"].get("ECON_BUDGET_HEALTH", 0)) >= 1000, "the legislature sees the need (%d)" % int(EconUtil.st(w)["lever_need"].get("ECON_BUDGET_HEALTH", 0)))
	var f: Dictionary = _clinics(w)[0]
	check(int(EconUtil.st(w)["r8_inst"]["t"][f["id"]]) < 200, "a short line cuts the crew far below the ask")
	EconInst.answered(w, "ECON_BUDGET_HEALTH", 10)
	for i in 6:
		EconInst.monthly(w)
	var again := false
	for q in EconInst.budget_requests(w):
		if q["line"] == "ECON_BUDGET_HEALTH":
			again = bool(q["due"])
	check(not again, "no new request within a year of the answer")


func test_full_room_short_lists_a_plant_to_build() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	sim.run(1)
	var f: Dictionary = _clinics(w)[0]
	f["scale"] = 50   # a clinic far too small for its district
	EconInst.monthly(w)
	var found := {}
	for b in EconInst.build_needs(w):
		if b["type"] == "CLINIC" and b["district"] == f["district"]:
			found = b
	check(not found.is_empty(), "the district needs another clinic")
	check(int(found.get("plants_needed", 0)) >= 1, "at least one plant (%d)" % int(found.get("plants_needed", 0)))


func test_an_empty_second_plant_closes_never_the_last() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	sim.run(1)
	var f: Dictionary = _clinics(w)[0]
	f["scale"] = 20000   # room for far more than the district has
	var g: Dictionary = f.duplicate(true)
	g["id"] = String(f["id"]) + "b"
	w.table("facility")[g["id"]] = g
	for i in EconInst.p("close_hold_m"):
		EconInst.monthly(w)
	var cands: Array = EconInst.close_candidates(w)
	check_eq(cands.size(), 2, "both plants are empty and either could take the other's clients")
	check(EconInst.close(w, String(cands[0]["fid"]))["ok"], "the government closes one")
	EconInst.monthly(w)
	check(EconInst.close_candidates(w).is_empty(), "the last open plant of a district is never a candidate")
	check(EconInst.reopen(w, String(cands[0]["fid"]))["ok"], "and can reopen it")


func test_care_lines_ask_too() -> void:
	var sim := _sim(["CARE"])
	var w := sim.world
	sim.run(2)
	w.levers["ECON_BUDGET_ELDER_CARE"] = 0
	for i in EconInst.p("req_hold_m"):
		EconInst.monthly(w)
	var row: Dictionary = {}
	for q in EconInst.budget_requests(w):
		if q["line"] == "ECON_BUDGET_ELDER_CARE":
			row = q
	check(not row.is_empty(), "a request row for elder care")
	check(int(row.get("ask", 0)) > 0, "it asks for the posts the retired need (%d)" % int(row.get("ask", 0)))


func test_runs_saves_and_loads_identically() -> void:
	var ref := _sim(["CARE"])
	ref.run(8)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(6)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(6)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash with the institutions' rules on")


func test_the_government_closes_an_empty_second_plant() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	sim.run(1)
	var f: Dictionary = _clinics(w)[0]
	f["scale"] = 20000
	var g: Dictionary = f.duplicate(true)
	g["id"] = String(f["id"]) + "b"
	w.table("facility")[g["id"]] = g
	for i in EconInst.p("close_hold_m"):
		EconInst.monthly(w)
	GovBuilder._inst_sites(w)
	var shut := 0
	for c in _clinics(w):
		if c["mothball"]:
			shut += 1
	check_eq(shut, 1, "one of the two empty clinics is closed, the other stays")


func test_under_delegation_a_due_request_is_a_case() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for fl in ["R8", "R8_INSTITUTIONS", Desk.FLAG]:
		if not (w.meta["on"] as Array).has(fl):
			(w.meta["on"] as Array).append(fl)
	sim.run(3)
	w.levers["ECON_BUDGET_HEALTH"] = 10
	for i in EconInst.p("req_hold_m"):
		EconInst.monthly(w)
	GovBuilder._inst_sites(w)
	check(Desk.pending(w, "INST_BUDGET|ECON_BUDGET_HEALTH"), "the minister has the budget request on the desk")
	var open := false
	for q in EconInst.budget_requests(w):
		if q["line"] == "ECON_BUDGET_HEALTH":
			open = bool(q["due"])
	check(not open, "the request is with the government, not asked again")
