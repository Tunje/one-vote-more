extends TestCase
## MEDIA v1 M4 (planning/spec-media-v1.md §9, §16): demand per household group, sales feedback, running costs
## paid as wages, owner cover, press subsidy, insolvency and the refund on closure.

const LawOps := preload("res://sim/law/law_ops.gd")

const WREF := 1200000
const LEFT := {"ECON_ROLE": 60000, "REDISTRIBUTION": 60000, "LABOR": 60000}


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func _hh(w: WorldState, gid: String, district: String, persons: int) -> void:
	w.table("hh")[gid] = {"id": gid, "district": district, "hb": "hb:1", "band": "MID", "lf": persons, "nonpart": 0,
		"retired": 0, "children": 0, "owners": 0, "emp": {"SERVICES": persons}, "income": {"wages": 0}}
	w.ledger.open_account("hh:" + gid)


func _world() -> WorldState:
	var w := WorldState.new(11)
	LawOps.init_world(w)
	w.month = 30
	w.values["ECON_W_REF"] = WREF
	w.table("econ")["s"] = {"spent_ytd": {}}
	w.ledger.open_account("gov:treasury")
	w.ledger.transfer(Ledger.EXTERNAL, "gov:treasury", 1000 * WREF, "seed", w.month)
	var sal := {}
	for c in PolDefs.CONCERNS:
		sal[c] = 100
	w.table("cell")["c1"] = {"key": "c1", "district": "district:1", "band": "MID", "pop": 600, "occ": "SERVICES",
		"ideology": _line(LEFT), "salience": sal}
	_hh(w, "hb:1|MID", "district:1", 3000000)
	_hh(w, "hb:1|LOW", "district:1", 1000000)
	Media.ensure_founding(w)
	return w


func _party_paper(w: WorldState, cash_wref: float) -> String:
	w.table("party")["party:1"] = {"id": "party:1", "name": "Labour", "status": "ACTIVE", "support": 20000, "seats": 20,
		"positions": _line(LEFT)}
	w.ledger.open_account("party:party:1")
	w.ledger.transfer(Ledger.EXTERNAL, "party:party:1", int(cash_wref * WREF), "seed", w.month)
	return Media.found_outlet(w, {"kind": "PARTY", "id": "party:1"}, {"line": _line(LEFT)})["out_id"]


func test_demand_is_per_household_group() -> void:
	var w := _world()
	Media.run(w)
	var gz: String = Media.outlets(w)[0]
	var circ := int(Media.outlet(w, gz)["circulation"])
	check(circ > 0, "the Gazette has readers")
	var d := Media.demand(w)
	check(d.has("hb:1|MID") and d.has("hb:1|LOW"), "keyed by hh group (%s)" % [d.keys()])
	var tot := int(d["hb:1|MID"][gz]) + int(d["hb:1|LOW"][gz])
	check_eq(tot, circ * 1000, "copies in milli, all of the district's readers")
	check(int(d["hb:1|MID"][gz]) == 3 * int(d["hb:1|LOW"][gz]), "split by persons")


func test_sales_shape_readership() -> void:
	var w := _world()
	Media.run(w)
	var gz: String = Media.outlets(w)[0]
	var cell: Dictionary = w.table("cell")["c1"]
	var share0 := int(cell["diet"][gz])
	Media.record_sales(w, {gz: 0})            # nobody could pay
	check(int(Media.outlet(w, gz)["sales_pm"]) < 200, "sales factor drops")
	w.month += 1
	Media.run(w)
	check(int(cell["diet"].get(gz, 0)) < share0 / 2, "readership follows what was bought (%d → %d)" % [share0, int(cell["diet"].get(gz, 0))])
	for i in 30:
		Media.record_sales(w, {gz: 1 << 40})     # everything wanted was bought
	check_eq(int(Media.outlet(w, gz)["sales_pm"]), 1000, "recovers when sales come back")


func test_costs_are_paid_as_wages_and_the_state_covers_the_gazette() -> void:
	var w := _world()
	var gz: String = Media.outlets(w)[0]
	var t0 := w.ledger.balance("gov:treasury")
	Media.run(w)
	var o := Media.outlet(w, gz)
	var cost := Media.running_cost(w, o)
	check(cost > WREF, "quality 60 + invest + printing ≈ %.2f W_ref" % [float(cost) / WREF])
	check_eq(int(o["fin"]["paid"]), cost, "paid in full")
	check_eq(w.ledger.balance("hh:hb:1|MID") + w.ledger.balance("hh:hb:1|LOW"), cost, "as wages to the district's households")
	check(int(w.table("hh")["hb:1|MID"]["income"]["wages"]) > 0, "booked as wage income")
	check_eq(t0 - w.ledger.balance("gov:treasury"), cost, "the treasury covered the Gazette")
	check_eq(int(w.peek("econ")["s"]["spent_ytd"]["ECON_BUDGET_SUBSIDIES"]), cost, "on the subsidies line")
	check_eq(int(o.get("deficit_months", 0)), 0, "no deficit")


func test_party_covers_then_paper_goes_insolvent() -> void:
	var w := _world()
	var pp := _party_paper(w, 2.5)            # covers 1.5 W_ref, then hits its 1 W_ref reserve
	var closed_at := -1
	for i in 12:
		Media.run(w)
		if Media.outlet(w, pp)["status"] == "CLOSED":
			closed_at = i
			break
		w.month += 1
	check(w.ledger.balance("party:party:1") >= WREF, "the party keeps its reserve")
	check(closed_at >= 0, "the paper closes when costs go unpaid")
	check(closed_at >= 5, "after six months in deficit (%d)" % closed_at)
	check(not w.facts.query("MEDIA_OUTLET_CLOSED").filter(func(f): return f["data"]["reason"] == "INSOLVENT").is_empty(), "as INSOLVENT")
	check_eq(w.ledger.balance("media:" + pp), 0, "nothing left in the account")
	check_eq(String(Media.outlet(w, Media.outlets(w)[0])["status"]), "ACTIVE", "the Gazette never closes")


func test_closure_refunds_the_owner() -> void:
	var w := _world()
	var pp := _party_paper(w, 2.0)
	w.ledger.transfer(Ledger.EXTERNAL, "media:" + pp, 5 * WREF, "seed", w.month)
	var before := w.ledger.balance("party:party:1")
	Media.close_outlet(w, pp, "TEST")
	check_eq(w.ledger.balance("party:party:1") - before, 5 * WREF, "cash back to the party")


func test_press_subsidy_by_circulation_within_budget() -> void:
	var w := _world()
	var pp := _party_paper(w, 0.0)
	w.levers["LAW_PRESS_SUBSIDY"] = 2
	w.levers["ECON_BUDGET_SUBSIDIES"] = 100            # thousand cr a year: plenty of headroom
	Media.run(w)
	check(int(w.peek("econ")["s"]["spent_ytd"]["ECON_BUDGET_SUBSIDIES"]) >= 2 * WREF, "booked on the subsidies line")
	w.levers["ECON_BUDGET_SUBSIDIES"] = 0
	w.peek("econ")["s"]["spent_ytd"] = {}
	var t0 := w.ledger.balance("gov:treasury")
	w.month += 1
	Media._press_subsidy(w)
	check_eq(w.ledger.balance("gov:treasury"), t0, "no subsidy without budget headroom")
	check(Media.outlet(w, pp)["status"] == "ACTIVE", "party paper alive this month")


func test_a_sale_resets_the_deficit_clock() -> void:
	var w := _world()
	var pp := _party_paper(w, 0.0)
	w.table("outlet")[pp]["deficit_months"] = 5
	w.table("org")["org:1"] = {"id": "org:1", "name": "Buyer Ltd", "type": "PRIVATE", "status": "ACTIVE"}
	check(Media.transfer_outlet(w, pp, {"kind": "COMPANY", "id": "org:1"}, 0)["ok"], "sold")
	check_eq(Media.deficit_months(w, pp), 0, "the buyer starts with a clean slate")


func test_union_federation_covers_its_paper() -> void:
	var w := _world()
	w.table("union")["union:9"] = {"id": "union:9", "acct": "union:union:9", "status": "ACTIVE", "federation": true,
		"members": 0, "sectors": [], "share": {}}
	w.ledger.open_account("union:union:9")
	w.ledger.transfer(Ledger.EXTERNAL, "union:union:9", 3 * WREF, "seed", w.month)
	var up: String = Media.found_outlet(w, {"kind": "UNION", "id": "union:9"}, {"line": _line(LEFT)})["out_id"]
	Media.run(w)
	var o := Media.outlet(w, up)
	check(int(o["fin"]["paid"]) >= WREF, "the federation paid up to its 1 W_ref cap (%d of %d)" % [int(o["fin"]["paid"]), int(o["fin"]["cost"])])
	check(w.ledger.balance("union:union:9") < 3 * WREF, "from its fund")
	for i in 12:
		w.month += 1
		Media.run(w)
	check(w.ledger.balance("union:union:9") >= WREF / 2, "keeps its floor")
	w.table("union")["union:9"]["status"] = "DISSOLVED"
	if Media.outlet(w, up)["status"] != "CLOSED":
		w.month += 1
		Media.run(w)
		check_eq(String(Media.outlet(w, up)["status"]), "CLOSED", "the paper dies with the federation")
