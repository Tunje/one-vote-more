extends TestCase
## UI accessors (planning/ui-staff-law.md): pure reads + every mutation through StaffLawActions.apply().

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const LQ := preload("res://sim/law/law_query.gd")
const A := preload("res://sim/staff/staff_law_actions.gd")

const GOV_ACTOR := {"kind": "GOVERNMENT", "id": "government"}


func _parl(w: WorldState) -> void:
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1",
		"government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	w.table("party")["P1"] = {"id": "P1", "name": "Unity", "is_player": true, "seats": 80, "status": "ACTIVE", "commitments": []}


## (a) roster, summary, candidates; queries never change state.
func test_personnel_queries_are_pure() -> void:
	var s := F.sim(1, false)
	var w := s.world
	var before := w.state_hash()
	var roster := SQ.roster(w, Ops.GOV)
	check_eq(roster.size(), 20, "20 officials")
	check(roster[0]["available"], "available listed first")
	var sm := SQ.summary(w, Ops.GOV)
	check_eq(sm["total"], 20, "summary total")
	check(sm["mandatory_vacancies"] >= 8, "founding slate vacancies (8 mandatory positions)")
	var pos := SQ.open_positions(w, Ops.GOV)
	check(not pos.is_empty(), "open positions")
	var c := SQ.candidates(w, pos[0]["task_id"], pos[0]["pos"])
	check_eq(c.size(), 20, "every official compared")
	check(c[0]["eligible"], "eligible first")
	for i in range(1, c.size()):
		if c[i]["eligible"] == c[i - 1]["eligible"]:
			check(c[i]["est_work"] <= c[i - 1]["est_work"], "sorted by estimated work")
	check(SQ.task_view(w, pos[0]["task_id"])["positions"][0]["requirements"] != "", "requirements text")
	SQ.briefing(w, Ops.GOV)
	LQ.lever_catalog(w)
	LQ.law_register(w)
	LQ.constitution_view(w)
	check_eq(w.state_hash(), before, "queries did not mutate the world")


## (a) assign/unassign through actions, with validation errors and the action log.
func test_assign_actions_and_errors() -> void:
	var s := F.sim(2, false)
	var w := s.world
	var pos: Dictionary = SQ.open_positions(w, Ops.GOV)[0]
	var best: Dictionary = SQ.candidates(w, pos["task_id"], pos["pos"])[0]
	var r := A.apply(w, {"id": "STAFF_ASSIGN", "actor": GOV_ACTOR, "args": {"task_id": pos["task_id"], "pos": pos["pos"], "person_id": best["person_id"]}})
	check(r["ok"], "assign ok")
	var r2 := A.apply(w, {"id": "STAFF_ASSIGN", "actor": GOV_ACTOR, "args": {"task_id": pos["task_id"], "pos": pos["pos"], "person_id": best["person_id"]}})
	check(not r2["ok"] and r2["error"] != "", "second assign rejected with a reason: %s" % r2)
	var r3 := A.apply(w, {"id": "STAFF_ASSIGN", "actor": {"kind": "PARTY", "id": "P9"}, "args": {"task_id": pos["task_id"], "pos": pos["pos"], "person_id": best["person_id"]}})
	check_eq(r3["error"], "not your task", "ownership enforced")
	check(A.apply(w, {"id": "STAFF_UNASSIGN", "actor": GOV_ACTOR, "args": {"person_id": best["person_id"]}})["ok"], "unassign")
	check_eq(w.table("action_log").size(), 4, "every action logged")


## (b) briefing ordered by priority with decisions and readable text.
func test_briefing() -> void:
	var s := F.sim(3, true)
	var w := s.world
	s.run(2)
	var b := SQ.briefing(w, Ops.GOV)
	check_eq(b["month"], w.month - 1, "last simulated month")
	check_eq(b["items"].size(), 20, "one report per official")
	for i in range(1, b["items"].size()):
		check(b["items"][i]["priority"] <= b["items"][i - 1]["priority"], "priority order")
	check(b["items"][0]["text"].length() > 10, "readable text")
	var tid: String = Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "MEDIUM", "budget": 1000}, Ops.GOV)["id"]
	Ops.request_commitment(w, tid, 900)
	var d := SQ.decision_requests(w, Ops.GOV)
	check_eq(d.size(), 1, "decision listed")
	check_eq(d[0]["options"].size(), 2, "options")
	check(A.apply(w, {"id": "STAFF_ANSWER_DECISION", "actor": GOV_ACTOR, "args": {"request_id": d[0]["id"], "option": "REJECT"}})["ok"], "answer via action")


## (c) drafting preview + request; decree lawful vs unlawful (needs confirmation, then SECRET + implemented).
func test_drafting_and_decree() -> void:
	var s := F.sim(4, true)
	var w := s.world
	var pv := LQ.preview_clauses(w, [{"lever": "LAW_EXTRACTION_ROYALTY", "to": 1000}, {"lever": "LAW_SAFETY_STANDARD", "to": "BOGUS"}])
	check(not pv["ok"], "invalid clause flagged")
	check(not pv["clauses"][1]["errors"].is_empty(), "per-clause errors")
	check(pv["clauses"][0]["ideology"].has("REDISTRIBUTION"), "ideology shift shown")
	var r := A.apply(w, {"id": "STAFF_REQUEST_DRAFTING", "actor": GOV_ACTOR,
		"args": {"bill_id": "bill:x", "clauses": [{"lever": "LAW_EXTRACTION_ROYALTY", "to": 1000}]}})
	check(r["ok"], "drafting requested: %s" % r)
	check(LQ.drafting_status(w, "bill:x")["exists"], "drafting visible")
	s.run(4)
	check(LQ.drafting_status(w, "bill:x")["ready"], "draft ready after a few months")
	# Decrees (parliamentary era)
	_parl(w)
	s.step()
	var lawful := LQ.decree_check(w, "LAW_PERMIT_STRICTNESS", "STRICT")
	check(lawful["allowed"] and lawful["lawful"], "REGULATION-level lever by decree is lawful")
	var ul := LQ.decree_check(w, "LAW_EXTRACTION_ROYALTY", 2000)
	check(ul["allowed"] and not ul["lawful"], "LAW-level lever by decree is unlawful")
	check(ul["warning"].contains("UNLAWFUL"), "warning text")
	var bad := LQ.decree_check(w, "LAW_EXTRACTION_ROYALTY", 99999)
	check(not bad["allowed"], "out-of-range can never be decreed")
	var r1 := A.apply(w, {"id": "LAW_DECREE", "actor": GOV_ACTOR, "args": {"lever": "LAW_EXTRACTION_ROYALTY", "value": 2000}})
	check(not r1["ok"] and r1.get("needs_confirmation", false), "needs confirmation")
	var r2 := A.apply(w, {"id": "LAW_DECREE", "actor": GOV_ACTOR, "args": {"lever": "LAW_EXTRACTION_ROYALTY", "value": 2000, "confirm_unlawful": true}})
	check(r2["ok"] and not r2["lawful"], "unlawful decree accepted after confirmation")
	check_eq(w.facts.query("LAW_UNLAWFUL_GOV_ACTION", -1, 9999, "SECRET").size(), 1, "recorded SECRET")
	for _i in 12:
		s.step()
	check_eq(w.levers["LAW_EXTRACTION_ROYALTY"], 2000, "implemented like any decision")
	check(LQ.enactments(w, true).any(func(e): return e["unlawful"]), "enactment marked unlawful in the register view")


## (d) register, constitution, cases (no truth exposed), courts.
func test_register_constitution_cases() -> void:
	var s := F.sim(5, true)
	var w := s.world
	var reg := LQ.law_register(w)
	check(reg.size() > 20, "charter rules listed")
	check_eq(reg[0]["level"], "CHARTER", "highest level first")
	check(reg[0]["text"].ends_with("."), "human-readable text")
	var cv := LQ.constitution_view(w)
	check_eq(cv["document"], "EXPEDITION CHARTER", "before the transition")
	check(cv["rights"].size() >= 5, "rights listed")
	_parl(w)
	s.step()
	check_eq(LQ.constitution_view(w)["document"], "CONSTITUTION", "after the first government")
	preload("res://sim/law/justice_ops.gd").file_case(w, "ADMIN_APPEAL", {"kind": "COMPANY", "id": "c1"},
		{"kind": "AUTHORITY", "id": "permit_office"}, true, {"application": ""})
	var cs := LQ.cases(w)
	check_eq(cs.size(), 1, "open case listed")
	check(not cs[0].has("truth") and not cs[0].has("evidence"), "no ground truth in the UI view")
	check(cs[0]["expected_months"] >= 1, "expected months")
	check_eq(LQ.courts(w).size(), 2, "two courts")


## D7: AI staffs by priority and moves people off low-priority work for a high-priority mandatory vacancy.
func test_ai_priority_staffing_and_poaching() -> void:
	var w := F.bare_world()
	var eng := F.add(w, "CIVIL", {"ENG": 70, "ADMIN": 60})
	var low: String = Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "SMALL", "priority": 20}, Ops.GOV)["id"]
	Ops.auto_staff(w, Ops.GOV)
	check_eq(Ops.task(w, low)["positions"][0]["assigned"], eng, "only task gets the engineer")
	var high: String = Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "LARGE", "priority": 90}, Ops.GOV)["id"]
	Ops.auto_staff(w, Ops.GOV)
	check_eq(Ops.task(w, high)["positions"][0]["assigned"], eng, "moved to the high-priority task")
	check_eq(Ops.task(w, low)["positions"][0]["assigned"], "", "low-priority task released")
	var mid: String = Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "SMALL", "priority": 85}, Ops.GOV)["id"]
	Ops.auto_staff(w, Ops.GOV)
	check_eq(Ops.task(w, mid)["positions"][0]["assigned"], "", "no poaching within the priority margin")
	check(Ops.check_invariants(w).filter(func(e): return not e.begins_with("civil service")).is_empty(), "invariants")


func test_unlawful_expected_cost() -> void:
	var LO := preload("res://sim/law/law_ops.gd")
	var c: Dictionary = LO.unlawful_expected_cost("SERIOUS", true, 24)
	check(c["p_reveal"] > 0.9, "burdened: very likely revealed within 2 years (%f)" % c["p_reveal"])
	check(LO.unlawful_expected_cost("SERIOUS", false, 24)["p_reveal"] < 0.6, "unburdened: leak only")
	check_eq(c["rule_of_law_drop"], 20.0, "rule of law drop per serious act")


## ENUM clauses (Wilma A: player bills may set ENUM levers): preview accepts string targets, shifts ideology by steps.
func test_preview_enum_clause() -> void:
	var s := F.sim(6, true)
	var w := s.world
	var pv := LQ.preview_clauses(w, [{"lever": "LAW_SAFETY_STANDARD", "to": "STRICT"}])
	check(pv["ok"], "ENUM clause valid: %s" % [pv["clauses"][0]["errors"]])
	check(is_equal_approx(float(pv["clauses"][0]["ideology"]["LABOR"]), 30.0), "two steps x LABOR 15")
	var bad := LQ.preview_clauses(w, [{"lever": "LAW_SAFETY_STANDARD", "to": "MAXIMUM"}])
	check(not bad["ok"], "unknown ENUM value rejected")


## 88's ECON_ACTION_FAILED reaches the government's briefing, stays hidden from others, and is not an inquiry finding.
func test_failed_actions_in_briefing_not_findings() -> void:
	var s := F.sim(7, true)
	var w := s.world
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1",
		"government": {"members": ["P2"], "pm_party": "P2", "support": [], "agreement": [], "formed_month": 0}})
	for p in [["P1", 40], ["P2", 80]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "is_player": p[0] == "P1", "commitments": []}
	s.step()
	w.add_fact({"type": "ECON_ACTION_FAILED", "owner": "econ", "subjects": [{"kind": "GOVERNMENT", "id": "government"}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 35,
		"visibility": "OFFICIAL", "data": {"action": "ECON_COMMISSION_PROJECT", "error": "not enough budget headroom", "params": {}}})
	s.step()
	var b2 := SQ.briefing(w, Ops.GOV, -1, {"party_id": "P2"})
	check_eq(b2["failed_actions"].size(), 1, "government sees the refused order")
	check_eq(b2["failed_actions"][0]["error"], "not enough budget headroom", "with the reason")
	check(SQ.briefing(w, Ops.GOV, -1, {"party_id": "P1"}).is_empty(), "opposition gets no government briefing")
	var t: String = Ops.create_task(w, "STAFF_T_OVERSIGHT", {"domain": "ECON", "domain_prefixes": ["ECON_"]}, {"kind": "PARTY", "id": "P1"})["id"]
	Ops.complete_task(w, Ops.task(w, t))
	var rep: Array = w.facts.query("STAFF_OVERSIGHT_REPORT")
	check_eq(int(rep[-1]["data"]["findings"]), 0, "a refused order is not an inquiry finding")
