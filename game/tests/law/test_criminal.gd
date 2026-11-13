extends TestCase
## P2a criminal procedure (sim/law/criminal.gd): charges, the criminal docket in the courts, sentences under
## LAW_SENTENCING, holding cells, overcrowding, reoffending and named prisoners.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const C := preload("res://sim/law/criminal.gd")


func _world(on: bool = true) -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	JO.init_courts(w)
	w.month = 20
	if on:
		w.meta["on"] = ["CRIME", "PRISONS"]
	return w


## Fake one month of the crime model: solved cases per kind in d:1.
func _crime_month(w: WorldState, theft: int, violence: int, fraud: int, workload: int = 800) -> void:
	var s := LawOps.state(w)
	if not s.has("crime"):
		s["crime"] = {"d": {}}
	s["crime"]["d"]["d:1"] = {"month": w.month, "pop": 3000, "workload_pm": workload,
		"m": {"THEFT": [0, 0, theft], "VIOLENCE": [0, 0, violence], "FRAUD": [0, 0, fraud]}}


func test_off_by_default() -> void:
	var w := _world(false)
	_crime_month(w, 5, 5, 5)
	C.monthly(w)
	check(C.stats(w).is_empty(), "nothing without PRISONS")
	check_eq(C.named_months(w), 0, "no prison for named convicts while off")


func test_sentencing_lever_moves_prison_share_and_length() -> void:
	var w := _world()
	var mid: Array = C.sentence_terms(w, "VIOLENCE")
	check(is_equal_approx(float(mid[0]), 0.5) and is_equal_approx(float(mid[1]), 14.0), "default 40: half to prison, ~14 months")
	w.levers["LAW_SENTENCING"] = 100
	var harsh: Array = C.sentence_terms(w, "THEFT")
	w.levers["LAW_SENTENCING"] = 0
	var soft: Array = C.sentence_terms(w, "THEFT")
	check(float(harsh[0]) > float(soft[0]) and float(harsh[1]) > float(soft[1]), "harsher: more theft prison, longer")


func test_cases_are_heard_and_sentenced() -> void:
	var w := _world()
	for i in 12:
		w.month += 1
		_crime_month(w, 6, 3, 2)
		C.monthly(w)
	var st := C.stats(w)
	var tot: Dictionary = st["totals"]
	check(int(tot["charged"]) > 60, "solved cases charged (%d)" % int(tot["charged"]))
	check(int(tot["heard"]) >= int(tot["charged"]) - 10, "a working court keeps up (%d of %d)" % [int(tot["heard"]), int(tot["charged"])])
	check(int(tot["convicted"]) > 0 and int(tot["prison"]) > 0 and int(tot["fines"]) > 0, "fines and prison (%s)" % [tot])
	check(int(st["cp_share_pm"]) > 0, "the docket used court time")


func test_a_court_cut_builds_a_backlog_and_frees_detainees() -> void:
	var w := _world()
	w.levers["LAW_COURT_BUDGET"] = 200
	for i in 14:
		w.month += 1
		_crime_month(w, 20, 15, 10)
		C.monthly(w)
	check(w.facts.query("LAW_COURT_BACKLOG", 0, w.month).size() >= 1, "justice delayed")
	check(w.facts.query("LAW_RELEASED_ON_TIME_LIMIT", 0, w.month).size() >= 1, "pretrial detainees released on time limits")


func test_cells_overflow_and_reoffenders_raise_crime() -> void:
	var w := _world()
	var st := C.state(w)
	for i in 12:
		(st["prisoners"] as Array).append({"d": "d:1", "kind": "VIOLENCE", "n": 1, "since": w.month, "until": w.month + 8})
	var disturb := 0
	for i in 6:
		w.month += 1
		_crime_month(w, 0, 0, 0)
		C.monthly(w)
	check(w.facts.query("LAW_HELD_IN_CELLS", 0, w.month).size() == 1, "held in police cells for months")
	var esc := w.facts.query("LAW_PRISON_ESCAPE", 0, w.month).size()
	disturb = w.facts.query("LAW_PRISON_DISTURBANCE", 0, w.month).size()
	check(esc + disturb >= 1, "12 in 4 cells: trouble (%d disturbances, %d escapes)" % [disturb, esc])
	for i in 4:
		w.month += 1
		C.monthly(w)
	check(C.reoffending_milli(w, "d:1", "THEFT") > 0.0, "released prisoners add theft")
	var punitive := C.reoffending_milli(w, "d:1", "THEFT")
	w.levers["LAW_PRISON_REGIME"] = 100
	check(C.reoffending_milli(w, "d:1", "THEFT") < punitive, "a rehabilitative regime lowers reoffending")
	check_eq(C.reoffending_milli(w, "d:1", "FRAUD"), 0.0, "fraud is not driven by the pool")


func test_named_prisoners() -> void:
	var w := _world()
	var pid := w.new_id("person")
	w.table("person")[pid] = {"id": pid, "name": "Ada Boss", "status": "ACTIVE", "unavailable_until": -1}
	var fid := C.imprison_named(w, "LEADER", 14, {"name": "Ada Boss", "party": "party:1", "person": pid})
	var d: Dictionary = w.facts.get_fact(fid)["data"]
	check(String(d["who"]) == "LEADER" and bool(d["disqualified"]), "14 months: the seat is lost")
	check_eq(String(w.table("person")[pid]["status"]), "UNAVAILABLE", "cannot work while inside")
	var ceo := C.imprison_named(w, "CEO", 4, {"name": "Bo Corp", "org": "org:3"})
	check(not bool(w.facts.get_fact(ceo)["data"]["disqualified"]), "a short term")
	check_eq((C.stats(w)["named"] as Array).size(), 2, "both inside")
	w.month += 5
	C.monthly(w)
	var rel := w.facts.query("LAW_RELEASED_FROM_PRISON", 0, w.month)
	check(rel.size() == 1 and String(rel[0]["data"]["name"]) == "Bo Corp", "the CEO is out after 4 months")


## v8: victims who win against an empty treasury are owed, not forgotten; the state pays as money comes in.
func test_unpaid_government_awards_stay_owed() -> void:
	var w := _world()
	w.ledger.open_account("gov:treasury")
	w.ledger.open_account(JO.VICTIM_FUND)
	var victims := {"kind": "VICTIMS", "id": "f:1", "scope": {}}
	check_eq(JO._pay(w, JO.GOVERNMENT, victims, 1000, "COMPENSATION"), 0, "an empty treasury pays nothing now")
	check_eq(JO.gov_owed(w), 1000, "but the award is owed")
	w.ledger.transfer(Ledger.EXTERNAL, "gov:treasury", 600, "TAX", w.month)
	JO._pay_victims(w)
	check_eq(w.ledger.balance(JO.VICTIM_FUND), 600, "paid as the treasury allows")
	check_eq(JO.gov_owed(w), 400, "the rest still owed")
