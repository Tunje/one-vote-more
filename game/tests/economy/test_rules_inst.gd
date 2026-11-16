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


# ------------------------------------------------------------------ private clinics and schools

func _private_clinic(w: WorldState) -> Dictionary:
	var oid := ""
	for o in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[o]["type"] == "PRIVATE" and w.table("org")[o]["status"] == "ACTIVE":
			oid = String(o)
			break
	var f: Dictionary = _clinics(w)[0].duplicate(true)
	f["id"] = "f_private_clinic"
	f["org"] = oid
	f["staff"] = {}
	w.table("facility")[f["id"]] = f
	return f


func _buy_all(w: WorldState) -> int:
	var spent := 0
	for gid in EconUtil.sorted_keys(w.table("hh")):
		spent += EconInst.buy_places(w, w.table("hh")[gid], 1000000 * EconUtil.S)
	return spent


func test_the_unserved_buy_private_places_the_served_do_not() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	w.levers["ECON_BUDGET_HEALTH"] = 10   # the public clinics can hardly pay a crew
	EconInst.monthly(w)
	var f := _private_clinic(w)
	check(String(f["org"]) != "", "a private owner")
	var cash0 := w.ledger.balance(EconUtil.acct(f["org"]))
	var spent := _buy_all(w)
	check(spent > 0 and int(f["inst_sold"]) > 0, "unserved patients buy places (%d sold)" % int(f["inst_sold"]))
	check(int(f["inst_sold"]) <= EconInst.places(w, f), "never more than its places")
	check_eq(w.ledger.balance(EconUtil.acct(f["org"])) - cash0, spent, "the fees reach the owner")
	# the state serves everyone: nobody pays
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	for c in _clinics(w):
		if c["id"] != f["id"]:
			c["scale"] = 50000
	EconInst.monthly(w)
	w.month += 1
	check_eq(_buy_all(w), 0, "with free places for all, nobody buys a private one")
	check_eq(EconInst.entry_district(w, "CLINIC"), "", "and no founder sees a market")


func test_the_fee_rises_when_full_and_falls_when_priced_out() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	EconInst.monthly(w)
	var f := _private_clinic(w)
	var fe := EconInst.fee(w, f)
	var r: Dictionary = EconUtil.st(w)["r8_inst"]
	for i in EconInst.FEE_HOLD_M:
		f["inst_sold"] = EconInst.places(w, f)
		f["inst_away"] = 10
		var t := {}
		EconInst._private_month(w, r, t)
	check(EconInst.fee(w, f) > fe, "full and turning patients away: the fee rises (%d -> %d)" % [fe, EconInst.fee(w, f)])
	var high := EconInst.fee(w, f)
	f["inst_sold"] = 0
	f["inst_away"] = 0
	r["priced"] = {"CLINIC": {String(f["district"]): 50}}
	EconInst._private_month(w, r, {})
	check(EconInst.fee(w, f) < high, "empty places and patients priced out: the fee falls")
	var cpc := EconInst.cost_per_client(w, "CLINIC")
	f["fee"] = cpc
	EconInst._private_month(w, r, {})
	check(EconInst.fee(w, f) < cpc, "no floor of ours: the fee may fall below its cost")
	check(EconInst.offered(w, f) < EconInst.places(w, f), "below its cost it offers fewer places (%d of %d)" % [EconInst.offered(w, f), EconInst.places(w, f)])


func test_a_private_crew_follows_its_paying_clients() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	EconInst.monthly(w)
	var f := _private_clinic(w)
	f["inst_sold"] = EconInst.places(w, f) / 2
	var t := {}
	EconInst._private_month(w, EconUtil.st(w)["r8_inst"], t)
	check(int(t[f["id"]]) > 450 and int(t[f["id"]]) < 600, "half its places sold, about half a crew (%d)" % int(t[f["id"]]))
	check(EconInst.target(w, f, 1.0) >= 0.0, "FirmAI reads it")


# ------------------------------------------------------------------ ADMIN (Maja's client measure: residents)

func _of_type(w: WorldState, typ: String) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == typ:
			out.append(w.table("facility")[fid])
	return out


func test_admin_crews_follow_the_residents() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_ADMIN"] = 4000
	sim.run(2)
	var f: Dictionary = _of_type(w, "ADMIN")[0]
	var t := int(EconUtil.st(w)["r8_inst"]["t"].get(f["id"], -1))
	check(t > 0 and t <= 1000, "the office has a crew share from its residents (%d)" % t)
	var row: Dictionary = EconInst.needs(w)["ADMIN"][String(f["district"])]
	check(int(row["clients"]) > 0, "residents are its clients")
	f["scale"] = int(f.get("scale", 1000)) * 4
	EconInst.monthly(w)
	check(int(EconUtil.st(w)["r8_inst"]["t"][f["id"]]) < t, "four times the room, a smaller crew share")


func test_an_office_can_be_commissioned_only_with_the_switch() -> void:
	var sim := _sim()
	var w := sim.world
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 40000
	sim.run(1)
	var d := String(_of_type(w, "ADMIN")[0]["district"])
	check_eq(EconActions.validate(w, "ECON_COMMISSION_PROJECT", {"type": "ADMIN", "district": d}), "", "with R8_INSTITUTIONS an office is buildable")
	w.meta["on"] = ["R8"]
	check(EconActions.validate(w, "ECON_COMMISSION_PROJECT", {"type": "ADMIN", "district": d}) != "", "without it, not")


# ------------------------------------------------------------------ tax brackets (the user: "they all get tax brackets")

func test_every_bracket_is_charged_and_earmarked() -> void:
	var sim := _sim(["CARE"])
	var w := sim.world
	sim.run(1)
	for k in EconInst.BRACKETS:
		w.levers[EconInst.BRACKETS[k][0]] = 10
	var cash0 := {}
	for k in EconInst.BRACKETS:
		var org := EconFinance.org_by_key(w, String(EconInst.BRACKETS[k][1]))
		cash0[k] = w.ledger.balance(EconUtil.acct(org)) if org != "" else 0
	sim.run(2)
	for k in EconUtil.sorted_keys(EconInst.BRACKETS):
		check(EconInst.earmarked(w, k) > 0, "the %s bracket raised money (%d)" % [k, EconInst.earmarked(w, k)])
	var off := EconSim.make_econ_only(3)
	off.world.meta["on"] = ["R8"]
	off.world.levers["ECON_SCHOOL_TAX"] = 20
	check_eq(EconInst.bracket_pm(off.world, "SCHOOL"), 0, "without the switch no bracket is charged")
	check_eq(EconInst.earmark_all(off.world, EconUtil.TREASURY, 1000000), 0, "and nothing is earmarked")


func test_bracket_proposals_are_calibrated_on_clients_plus_staff() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	for i in EconInst.p("req_hold_m") + 1:
		EconInst.monthly(w)
	check(not EconUtil.st(w)["r8_inst"]["req"].has("ECON_SCHOOL_TAX"), "a bracket at 0: nothing proposed")
	w.levers["ECON_SCHOOL_TAX"] = 10
	w.levers["ECON_BUDGET_EDUCATION"] = 10   # the line pays almost nothing
	var r: Dictionary = EconUtil.st(w)["r8_inst"]
	r["earmark"] = {"SCHOOL": {"month": w.month, "now": 1000 * EconUtil.S, "last": 0}}   # the bracket raised little
	for i in EconInst.p("req_hold_m"):
		EconInst.monthly(w)
	var q: Dictionary = r["req"].get("ECON_SCHOOL_TAX", {})
	check(int(q.get("ask", 0)) > 10, "rule 1: the bracket that pays pupils plus staff is higher (%d)" % int(q.get("ask", 0)))
	check(int(EconUtil.st(w)["lever_need"].get("ECON_SCHOOL_TAX", 0)) >= 1000, "the legislature sees the need")
	check(bool(q.get("due", false)) and String(q.get("kind", "")) == "bracket", "a bracket proposal falls due")
	r["earmark"] = {"SCHOOL": {"month": w.month, "now": 1000000000 * EconUtil.S, "last": 0}}   # it raises far more than needed
	for i in EconInst.p("cut_hold_m"):
		EconInst.monthly(w)
	q = r["req"].get("ECON_SCHOOL_TAX", {})
	check(int(q.get("ask", 99)) < 10, "rule 2: a lower bracket (%d)" % int(q.get("ask", 99)))
	check_eq(int(EconUtil.st(w)["lever_need"].get("ECON_SCHOOL_TAX", 0)), -1000, "the legislature sees the bracket can fall")


# ------------------------------------------------------------------ private care homes

func _private_home(w: WorldState, typ: String, d: String) -> Dictionary:
	var oid := ""
	for o in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[o]["type"] == "PRIVATE" and w.table("org")[o]["status"] == "ACTIVE":
			oid = String(o)
			break
	var fid := EconSetup.add_facility(w, typ, oid, d, false)
	return w.table("facility")[fid]


func test_private_care_homes_serve_the_uncared_and_count_in_coverage() -> void:
	var sim := _sim(["CARE"])
	var w := sim.world
	check(EconInst.private_types(w).has("ELDERCARE"), "with CARE, care homes can be private")
	w.levers["ECON_BUDGET_ELDER_CARE"] = 0   # the public service cares for nobody
	sim.run(3)
	var rows: Dictionary = EconInst.needs(w).get("ELDERCARE", {})
	var d := ""
	for dd in EconUtil.sorted_keys(rows):
		if int(rows[dd]["clients"]) > 0:
			d = String(dd)
			break
	check(d != "", "care rows by district (the retired)")
	var f := _private_home(w, "ELDERCARE", d)
	check(EconInst.places(w, f) > 0, "a home's places from its posts (%d)" % EconInst.places(w, f))
	w.month += 1
	check(_buy_all(w) > 0 and int(f["inst_sold"]) > 0, "the uncared-for buy places (%d)" % int(f.get("inst_sold", 0)))
	var before := EconCare.coverage(w, "ELDER", d)
	EconCare.monthly(w)
	check(EconCare.coverage(w, "ELDER", d) > before, "the people it cares for count in the district's coverage (%d -> %d)" % [before, EconCare.coverage(w, "ELDER", d)])
	check(EconInst.forecast(w, "ELDERCARE", d) >= 0, "founders can read the market")
	var off := _sim()
	check(not EconInst.private_types(off.world).has("ELDERCARE"), "without CARE, no private care homes")


func test_founders_read_the_average_not_the_leftovers() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	w.levers["ECON_BUDGET_HEALTH"] = 4000   # the public clinics serve everyone: no leftovers
	EconInst.monthly(w)
	var d := String(_clinics(w)[0]["district"])
	var n := EconInst.forecast(w, "CLINIC", d)
	check(n > 0, "the founder still reads its average share of the clients in reach (%d)" % n)
	check(n <= EconInst.new_places("CLINIC"), "never more than its places")
	for c in _clinics(w):
		c["scale"] = int(c.get("scale", 1000)) * 4
	var n4 := EconInst.forecast(w, "CLINIC", d)
	check(n4 < n, "more places in reach, a smaller share (%d -> %d)" % [n, n4])


func test_founders_count_the_plants_being_built() -> void:
	var sim := _sim()
	var w := sim.world
	sim.run(2)
	w.levers["ECON_BUDGET_HEALTH"] = 4000
	EconInst.monthly(w)
	var d := String(_clinics(w)[0]["district"])
	var n := EconInst.forecast(w, "CLINIC", d)
	EconConstruction.create(w, "CLINIC", d, "gov", "HEALTH", "ECON_BUDGET_HEALTH")
	var nb := EconInst.forecast(w, "CLINIC", d)
	check(nb < n, "a clinic being built in reach shares the clients too (%d -> %d)" % [n, nb])
