extends TestCase
## Thin law (spec-law §14): LT1–LT4, LT7, LT10-style checks, licences, principle of legality.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")


func _enact(w: WorldState, lever: String, value, level: String = "ORDINANCE", bill: String = "") -> String:
	var id := w.new_id("enact")
	w.table("enactment")[id] = {"id": id, "lever": lever, "value": value, "legal_level": level, "source_bill": bill,
		"decided_month": w.month, "earliest_effective_month": w.month + 1, "status": "PENDING"}
	return id


func _run_until(s: Simulation, eid: String, status: String, max_months: int = 12) -> int:
	var m := 0
	while s.world.table("enactment")[eid]["status"] != status and m < max_months:
		s.step()
		m += 1
	return m


## LT1: a commander ordinance -> legal -> implementation task (staffed) -> lag -> operative + fact.
func test_lt1_ordinance_pipeline() -> void:
	var s := F.sim(2, true)
	var w := s.world
	var eid := _enact(w, "LAW_SAFETY_STANDARD", "STANDARD")
	s.step()
	var e: Dictionary = w.table("enactment")[eid]
	check_eq(e["status"], "LEGAL", "legal after the check")
	check_eq(LawOps.legal_value(w, "LAW_SAFETY_STANDARD"), "STANDARD", "legal value")
	check_eq(w.levers["LAW_SAFETY_STANDARD"], "BASIC", "operative unchanged until implemented")
	var t := Staff.task(w, e["impl_task"])
	check_eq(t["def_id"], "STAFF_T_IMPL_REGULATORY", "implementation class from the lever")
	var months := _run_until(s, eid, "EFFECTIVE", 24)
	check(months < 24, "became effective")
	check_eq(w.levers["LAW_SAFETY_STANDARD"], "STANDARD", "operative written by law")
	check_eq(w.facts.query("LAW_LEVER_EFFECTIVE").size(), 1, "LAW_LEVER_EFFECTIVE fact")
	check(int(e["effective_month"]) - int(Staff.task(w, e["impl_task"])["completed_month"]) >= 2, "lag 2 respected")


## Without staff, nothing becomes effective ("enacted != implemented").
func test_unstaffed_implementation_never_effective() -> void:
	var s := F.sim(3, false)
	var eid := _enact(s.world, "LAW_EXTRACTION_ROYALTY", 1000)
	s.run(8)
	check_eq(s.world.table("enactment")[eid]["status"], "LEGAL", "stuck at LEGAL without staff")
	check_eq(s.world.levers["LAW_EXTRACTION_ROYALTY"], 800, "operative unchanged")
	check(s.world.facts.query("STAFF_IMPLEMENTATION_OVERDUE").size() == 1, "overdue fact after 6 months")


## LT2: charter rights bind the commander.
func test_lt2_charter_prohibits_postponing_election() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	var r := RE.validate(w, {"kind": "COMMANDER", "id": "commander"}, "POSTPONE_ELECTION", {"month": 50})
	check_eq(r["result"], "PROHIBITED", "postpone prohibited")
	check_eq(r["trace"].size(), 1, "trace names the charter rule")
	check_eq(RE.validate(w, {"kind": "COMMANDER", "id": "commander"}, "BUILD_FACILITY", {})["result"], "AUTHORIZED", "commander may build")
	check_eq(RE.validate(w, {"kind": "GOVERNMENT", "id": "government"}, "EXPROPRIATE", {"compensation_pct": 100})["result"],
		"PROHIBITED", "public actor without authority (principle of legality)")
	check_eq(RE.validate(w, {"kind": "COMPANY", "id": "co:1"}, "SELL_GOOD", {})["result"], "AUTHORIZED", "private default-allow")
	check_eq(RE.validate(w, {"kind": "COMPANY", "id": "co:1"}, "INTERNAL", {})["result"], "AUTHORIZED", "INTERNAL")


## LT3: first government -> constitution; commander powers expire; ordinances deemed statutes.
func test_lt3_transition() -> void:
	var s := F.sim(4, true)
	var w := s.world
	var eid := _enact(w, "LAW_EXTRACTION_ROYALTY", 1000)
	_run_until(s, eid, "EFFECTIVE", 24)
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "", "government": {"members": ["P1"], "pm_party": "P1",
		"agreement": [], "formed_month": w.month}})
	w.table("party")["P1"] = {"id": "P1", "seats": 80, "status": "ACTIVE", "commitments": []}
	var late := _enact(w, "LAW_SAFETY_STANDARD", "STANDARD")     # issued in the commander's last month
	s.step()
	check(LawOps.state(w)["constitution"], "constitution adopted")
	check(w.table("enactment")[late].get("deemed_statute", false), "a pending ordinance is deemed too")
	check_eq(w.table("enactment")[late]["status"], "LEGAL", "and survives the handover (v4: rejected at Y4-10)")
	check_eq(w.facts.query("LAW_CONSTITUTION_ADOPTED").size(), 1, "fact")
	check(w.table("enactment")[eid].get("deemed_statute", false), "ordinance deemed statute")
	check_eq(w.levers["LAW_EXTRACTION_ROYALTY"], 1000, "no lever cliff")
	var bad := _enact(w, "LAW_EXTRACTION_ROYALTY", 1200, "ORDINANCE")
	s.step()
	check_eq(w.table("enactment")[bad]["status"], "REJECTED", "commander can no longer issue ordinances")
	var ok := _enact(w, "LAW_EXTRACTION_ROYALTY", 1200, "LAW")
	s.step()
	check_eq(w.table("enactment")[ok]["status"], "LEGAL", "parliament can legislate")
	check_eq(RE.validate(w, {"kind": "GOVERNMENT", "id": "government"}, "SPEND", {})["result"], "REQUIRES_APPROVAL",
		"spending needs appropriation")
	check_eq(RE.validate(w, {"kind": "GOVERNMENT", "id": "government"}, "SPEND", {"appropriated": true})["result"],
		"AUTHORIZED", "appropriated spending")


## LT4: regulations can't change LAW-level levers unless delegated (within bounds).
func test_lt4_regulation_needs_delegation() -> void:
	var s := F.sim(5, true)
	var w := s.world
	F.set_pol(w, {"era": "PARLIAMENTARY", "government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	s.step()
	var r1 := _enact(w, "LAW_EXTRACTION_ROYALTY", 900, "REGULATION")
	s.step()
	check_eq(w.table("enactment")[r1]["status"], "REJECTED", "no delegation")
	LawOps.add_rule(w, {"level": "LAW", "kind": "DELEGATE", "action": "SET_LEVER", "subject": [], "where": [], "unless": [],
		"requirement": {}, "delegation": {"lever_id": "LAW_EXTRACTION_ROYALTY", "min": 500, "max": 1000},
		"supersedes": [], "defect": false, "provisional": false, "source": "TEST"})
	var r2 := _enact(w, "LAW_EXTRACTION_ROYALTY", 900, "REGULATION")
	var r3 := _enact(w, "LAW_EXTRACTION_ROYALTY", 1500, "REGULATION")
	s.step()
	check(w.table("enactment")[r2]["status"] != "REJECTED", "in delegated range accepted")
	check_eq(w.table("enactment")[r3]["status"], "REJECTED", "outside delegated range")


## Charter bounds and value validation.
func test_charter_bounds() -> void:
	var s := F.sim(6, true)
	var w := s.world
	var a := _enact(w, "STAFF_CIVIL_RETIREMENT_AGE", 72)
	s.step()
	check_eq(w.table("enactment")[a]["status"], "LEGAL", "72 allowed")
	var b := _enact(w, "STAFF_CIVIL_RETIREMENT_AGE", 75)
	var c := _enact(w, "LAW_SAFETY_STANDARD", "NONSENSE")
	s.step()
	check_eq(w.table("enactment")[b]["status"], "REJECTED", "75 outside range/charter")
	check_eq(w.table("enactment")[c]["status"], "REJECTED", "invalid enum")
	check(w.facts.query("LAW_ENACTMENT_REJECTED").size() >= 2, "rejection facts")


## LT7: a newer change of the same lever supersedes a pending one; operative never takes the old value.
func test_lt7_supersede_before_implementation() -> void:
	var s := F.sim(7, false)
	var w := s.world
	var e1 := _enact(w, "LAW_EXTRACTION_ROYALTY", 1000, "ORDINANCE", "bill:1")
	s.step()
	var t1: String = w.table("enactment")[e1]["impl_task"]
	var e2 := _enact(w, "LAW_EXTRACTION_ROYALTY", 600, "ORDINANCE", "bill:2")
	s.step()
	check_eq(w.table("enactment")[e1]["status"], "CANCELLED", "old change cancelled")
	check_eq(Staff.task(w, t1)["status"], "CANCELLED", "its implementation task cancelled")
	check_eq(w.table("enactment")[e2]["status"], "LEGAL", "new change legal")
	w.meta["staff_autoplay"] = true
	_run_until(s, e2, "EFFECTIVE", 24)
	check_eq(w.levers["LAW_EXTRACTION_ROYALTY"], 600, "only the newer value became operative")


## Licences: companies need an extraction licence while the regime is REQUIRED.
func test_licence_requirement() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	var co := {"kind": "COMPANY", "id": "co:1", "ownership": "PRIVATE"}
	var r := RE.validate(w, co, "EXTRACT_RESOURCE", {"resource": "MINERAL"})
	check_eq(r["result"], "AUTHORIZED_WITH_CONDITIONS", "needs licence")
	check_eq(r["missing"][0]["licence"], "EXTRACTION", "names the licence")
	LawOps.grant_licence(w, "co:1", "licence", "EXTRACTION", 120)
	check_eq(RE.validate(w, co, "EXTRACT_RESOURCE", {"resource": "MINERAL"})["result"], "AUTHORIZED", "licensed")
	check_eq(RE.validate(w, co, "OPERATE_FACILITY", {"hazard_class": "MEDIUM"})["result"], "AUTHORIZED", "medium hazard free")
	check_eq(RE.validate(w, co, "OPERATE_FACILITY", {"hazard_class": "HIGH"})["result"], "AUTHORIZED_WITH_CONDITIONS", "high hazard")
	w.levers["LAW_LICENCE_REGIME_HAZARD"] = "NONE"
	check_eq(RE.validate(w, co, "OPERATE_FACILITY", {"hazard_class": "HIGH"})["result"], "AUTHORIZED", "regime off")
	var fid := LawOps.record_violation(w, co, "OPERATE_FACILITY", {"hazard_class": "HIGH"})
	check_eq(w.facts.get_fact(fid)["visibility"], "SECRET", "violations are SECRET")


func test_law_deterministic_with_save_load() -> void:
	var a := F.sim(9, true)
	_enact(a.world, "LAW_SAFETY_STANDARD", "STRICT")
	a.run(3)
	check_eq(SaveIO.save(a, F.save_path("law.sav")), OK, "save")
	a.run(12)
	var b := Simulation.new(0, [F.LawProvider.new(), F.StaffProvider.new()])
	check_eq(SaveIO.load_into(b, F.save_path("law.sav")), OK, "load")
	b.run(12)
	check_eq(b.world.state_hash(), a.world.state_hash(), "identical after load")
	check_eq(a.world.levers["LAW_SAFETY_STANDARD"], "STRICT", "effective")
