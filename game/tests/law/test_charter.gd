extends TestCase
## M12 law side (planning/spec-colony-v1.md §5-7): entrenched charter, home-world inspector and sanctions,
## petition, refusal, independence, militia cap.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")
const CO := preload("res://sim/law/charter_ops.gd")
const RE := preload("res://sim/law/rules_engine.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}


func _world() -> Simulation:
	var s := F.sim(51, true)
	var w := s.world
	for p in [["P1", 90], ["P2", 61]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "commitments": [], "is_player": p[0] == "P1"}
	w.table("election")["election:1"] = {"id": "election:1", "month": 0, "seats": {}, "votes": {}, "total": 0}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": true, "elections": ["election:1"],
		"next_election": 48, "caretaker": false,
		"government": {"members": ["P1"], "pm_party": "P1", "support": [], "agreement": [], "formed_month": 0}})
	s.step()
	s.step()
	return s


func test_charter_entrenched() -> void:
	var s := _world()
	var w := s.world
	check_eq(LQ.sovereignty(w)["status"], "COLONY", "starts as a colony")
	check_eq(LQ.quota_due(w), {"due": true, "share_pct": 40, "price_pct": 35, "reason": ""}, "quota due at charter terms")
	check(not LawOps.check_change(w, "LAW_CHARTER_QUOTA_SHARE", 10, "LAW").is_empty(), "parliament cannot change the quota")
	check(CO.home_world_amend(w, "LAW_CHARTER_QUOTA_SHARE", 55)["ok"], "the home world can")
	check_eq(w.levers["LAW_CHARTER_QUOTA_SHARE"], 55, "Stamp Act moment")
	var co := {"kind": "COMPANY", "id": "org:1"}
	check_eq(RE.validate(w, co, "SELL_COLONIAL_GOOD", {"buyer": "OTHER"})["result"], "PROHIBITED", "exclusive trade")
	check_eq(RE.validate(w, co, "SELL_COLONIAL_GOOD", {"buyer": "HOME_WORLD"})["result"], "AUTHORIZED", "sale home is lawful")
	check_eq(RE.validate(w, GOV, "LEVY_TAX", {"base": "COLONIAL_EXPORT"})["result"], "PROHIBITED", "no tax on the quota trade")
	check_eq(RE.validate(w, GOV, "LEVY_TAX", {"base": "INCOME"})["result"], "AUTHORIZED", "ordinary taxes unaffected")
	check(not LawOps.check_change(w, "LAW_MILITIA", 20, "LAW").is_empty(), "militia above the charter cap is unlawful")
	check(LawOps.check_change(w, "LAW_MILITIA", 5, "LAW").is_empty(), "a small militia is lawful")


func test_home_inspector_and_sanctions() -> void:
	var s := _world()
	var w := s.world
	check(not CO.home_sanction(w, "FINE")["lawful"], "no fine without proven evasion")
	check(not w.facts.query("HOME_UNLAWFUL_SANCTION").is_empty(), "an unlawful sanction is recorded (legitimacy)")
	check(CO.home_sanction(w, "WITHHOLD")["lawful"], "withholding ships is always the home world's right")
	check(not CO.home_sanction(w, "EXPEDITION")["lawful"], "no expedition against a loyal colony")
	var fids: Array = []
	for i in 6:
		fids.append(LawOps.record_greed(w, "org:%d" % i, {"kind": "SMUGGLING", "good": "RARE_MINERAL", "evidence": 900, "saving": 1000}))
	check(w.table("violation_track")[fids[0]]["unlawful"], "smuggling is unlawful under the charter")
	var found := CO.home_inspection(w, 80)
	check(found.size() >= 3, "the inspector finds most of it (%d of 6)" % found.size())
	check(CO.evasion_proven(w), "evasion proven")
	check(CO.home_sanction(w, "FINE")["lawful"], "fine now lawful")
	check(CO.home_sanction(w, "APPOINT_GOVERNOR")["lawful"] and LQ.sovereignty(w)["governor"], "governor installed")
	var eid := "enact:test"
	w.table("enactment")[eid] = {"id": eid, "lever": "LAW_MILITIA", "value": 5, "status": "PENDING"}
	check(CO.governor_veto(w, eid)["ok"] and w.table("enactment")[eid]["status"] == "VETOED", "governor veto")


func test_petition_and_refusal() -> void:
	var s := _world()
	var w := s.world
	var pid := CO.petition_home(w, {"LAW_CHARTER_QUOTA_SHARE": 30})
	CO.answer_petition(w, pid, true)
	check_eq(w.levers["LAW_CHARTER_QUOTA_SHARE"], 30, "accepted petition lowers the quota")
	var r := CO.refuse_quota(w)
	check(r["ok"] and not r["lawful"], "refusal is unlawful under the charter")
	check(not LQ.quota_due(w)["due"] and LQ.quota_due(w)["reason"] == "REFUSAL", "no quota while refusing")
	check(CO.home_sanction(w, "EXPEDITION")["lawful"], "a refusing colony may face an expedition")
	CO.end_refusal(w)
	check(LQ.quota_due(w)["due"], "compliance resumed")


func test_independence_procedure() -> void:
	var s := _world()
	var w := s.world
	check(not CO.can_declare_independence(w, 600, 400, 1500)["ok"], "no parliament vote yet")
	check(not CO.record_independence_vote(w, 100)["ok"], "100 seats is not 2/3")
	CO.record_independence_vote(w, 101)
	check(not CO.can_declare_independence(w, 500, 200, 1500)["ok"], "turnout 47% too low")
	check(not CO.can_declare_independence(w, 400, 400, 1500)["ok"], "a tie does not pass")
	check(CO.declare_independence(w, 600, 400, 1500)["ok"], "valid procedure")
	check_eq(LQ.sovereignty(w)["status"], "INDEPENDENCE_DECLARED", "declared")
	check(not LQ.quota_due(w)["due"], "no quota")
	var co := {"kind": "COMPANY", "id": "org:1"}
	check_eq(RE.validate(w, co, "SELL_COLONIAL_GOOD", {"buyer": "OTHER"})["result"], "AUTHORIZED", "charter suspended")
	check(LawOps.check_change(w, "LAW_MILITIA", 40, "LAW").is_empty(), "militia cap lifted")
	w.levers["LAW_MILITIA"] = 40
	check(CO.home_sanction(w, "EXPEDITION")["lawful"], "the home world may send an expedition")
	CO.restore_charter(w, {"LAW_CHARTER_QUOTA_SHARE": 60})
	check(LQ.sovereignty(w)["status"] == "COLONY" and LQ.sovereignty(w)["governor"], "brought back with a governor")
	check(w.levers["LAW_CHARTER_QUOTA_SHARE"] == 60 and w.levers["LAW_MILITIA"] == 5, "harsher terms; militia disbanded to the cap")
	check_eq(RE.validate(w, co, "SELL_COLONIAL_GOOD", {"buyer": "OTHER"})["result"], "PROHIBITED", "charter binds again")
	s.run(1)
	CO.record_independence_vote(w, 120)
	CO.declare_independence(w, 900, 100, 1500)
	CO.recognise_independence(w)
	check_eq(LQ.sovereignty(w)["status"], "INDEPENDENT", "recognised")
	check_eq(LQ.sovereignty(w)["militia_cap"], -1, "no cap")
	check_eq(RE.validate(w, GOV, "LEVY_TAX", {"base": "COLONIAL_EXPORT"})["result"], "AUTHORIZED", "may tax its own exports")
