extends TestCase
## M11 law side (planning/spec-events-v1.md §3-4): greed conduct records, detection, emergency powers,
## crisis inquiries, civil liability.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")
const J := preload("res://sim/law/justice_ops.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}
const CMD := {"kind": "COMMANDER", "id": "commander"}


func _crisis(w: WorldState, mag: int = 60, data: Dictionary = {}) -> String:
	var d := {"crisis": true}
	d.merge(data)
	return w.add_fact({"type": "ECON_MINE_COLLAPSE", "owner": "economy", "subjects": [], "responsible": [], "impact": {"SAFETY": -20},
		"magnitude": mag, "visibility": "PUBLIC", "data": d})


func _parliament() -> Simulation:
	var s := F.sim(41, true)
	var w := s.world
	for p in [["P1", 80], ["P2", 71]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "commitments": [], "is_player": p[0] == "P1"}
	w.table("election")["election:1"] = {"id": "election:1", "month": 0, "seats": {}, "votes": {}, "total": 0}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": true, "elections": ["election:1"],
		"next_election": 48, "caretaker": false,
		"government": {"members": ["P1"], "pm_party": "P1", "support": [], "agreement": [], "formed_month": 0}})
	s.step()
	s.step()
	return s


func test_greed_record_upsert_and_legality() -> void:
	var s := F.sim(21, true)
	var w := s.world
	var a := LawOps.record_greed(w, "org:1", {"kind": "DEFERRED_UPKEEP", "facility": "fac:1", "saving": 1000, "evidence": 300,
		"hazard_ids": ["hz:1"]})
	var b := LawOps.record_greed(w, "org:1", {"kind": "DEFERRED_UPKEEP", "facility": "fac:1", "saving": 500, "evidence": 400,
		"hazard_ids": ["hz:2"]})
	check_eq(a, b, "same conduct continues: one record")
	var v: Dictionary = w.table("violation_track")[a]
	check(v["unlawful"] and v["saving"] == 1500 and v["evidence"] == 400 and v["hazard_ids"] == ["hz:1", "hz:2"], "upsert: %s" % [v])
	check_eq(w.facts.get_fact(a)["type"], "LAW_VIOLATION", "deferring safety upkeep is always unlawful")
	check_eq(w.facts.get_fact(a)["visibility"], "SECRET", "actual cause SECRET")
	var g := LawOps.record_greed(w, "org:2", {"kind": "GOUGING", "good": "FOOD"})
	check(not w.table("violation_track")[g]["unlawful"], "gouging is lawful outside an emergency (default IN_EMERGENCY)")
	check_eq(w.facts.get_fact(g)["type"], "LAW_HARMFUL_CONDUCT", "lawful harmful conduct recorded")
	check_eq(J.detect_p(J.detect_ctx(w), w.table("violation_track")[g])["inspect"], 0.0, "lawful conduct is not inspected")
	w.levers["LAW_COMPETITION"] = "NONE"
	check(not w.table("violation_track")[LawOps.record_greed(w, "org:3", {"kind": "CARTEL", "good": "FOOD"})]["unlawful"], "no cartel law")
	w.levers["LAW_COMPETITION"] = "CARTEL_BAN"
	check(w.table("violation_track")[LawOps.record_greed(w, "org:4", {"kind": "CARTEL", "good": "FOOD"})]["unlawful"], "cartel ban")
	s.run(6)
	LawOps.record_greed(w, "org:1", {"kind": "DEFERRED_UPKEEP", "facility": "fac:1", "since_month": 0})
	if not v["revealed"]:
		check_eq(w.table("violation_track")[a]["class"], "SEVERE", "6+ months of deferred safety upkeep is SEVERE")


func test_detection_scales_with_budget() -> void:
	var s := F.sim(22, true)
	var w := s.world
	var row := {"company": "org:9", "channel": "ENV", "unlawful": true, "evidence": 500, "kind": "DUMPING", "active": true}
	w.levers["LAW_ENV_INSPECTORATE_BUDGET"] = 0
	var p0: float = J.detect_p(J.detect_ctx(w), row)["inspect"]
	w.levers["LAW_ENV_INSPECTORATE_BUDGET"] = 40000
	var p1: float = J.detect_p(J.detect_ctx(w), row)["inspect"]
	check(p0 == 0.0 and p1 > 0.5, "no budget, no inspections (%.2f); a big budget finds most dumping (%.2f)" % [p0, p1])
	var e0 := LQ.expected_sanction(w, "DUMPING", "org:9")
	w.levers["LAW_ENV_INSPECTORATE_BUDGET"] = 0
	var e1 := LQ.expected_sanction(w, "DUMPING", "org:9")
	check(not e0["lawful"] and e0["expected_fine"] > e1["expected_fine"], "deterrence follows the budget: %s vs %s" % [e0, e1])
	check(LQ.expected_sanction(w, "GOUGING", "org:9")["lawful"], "lawful conduct: no sanction")
	w.levers["LAW_WHISTLEBLOWER_PROTECTION"] = true
	check(J.detect_p(J.detect_ctx(w), row)["whistle"] > J.P_WHISTLE, "whistleblower protection")


func test_emergency_powers_founding() -> void:
	var s := F.sim(23, true)
	var w := s.world
	check(not LawOps.declare_emergency(w, "FOOD", CMD)["ok"], "no crisis: no emergency")
	check(not LawOps.check_change(w, "LAW_RATIONING", "FOOD", "REGULATION").is_empty(), "emergency lever locked outside an emergency")
	_crisis(w)
	var r := LawOps.declare_emergency(w, "FOOD", CMD)
	check(r["ok"] and not r["needs_approval"], "commander declares, in force at once: %s" % [r])
	check(LQ.emergency(w)["active"], "LQ read")
	check(LawOps.check_change(w, "LAW_RATIONING", "FOOD", "REGULATION").is_empty(), "rationing allowed during the emergency: %s" %
		[LawOps.check_change(w, "LAW_RATIONING", "FOOD", "REGULATION")])
	var g := LawOps.record_greed(w, "org:2", {"kind": "GOUGING", "good": "FOOD"})
	check(w.table("violation_track")[g]["unlawful"], "gouging unlawful in an emergency")
	check_eq(RE.validate(w, CMD, "REQUISITION", {"compensation_pct": 50})["result"], "PROHIBITED", "requisition needs full compensation")
	check_eq(RE.validate(w, CMD, "REQUISITION", {"compensation_pct": 100})["result"], "AUTHORIZED", "requisition with compensation")
	w.levers["LAW_RATIONING"] = "FOOD"
	LawOps.end_emergency(w)
	check_eq(w.levers["LAW_RATIONING"], "NONE", "emergency levers revert")
	check_eq(RE.validate(w, CMD, "REQUISITION", {"compensation_pct": 100})["result"], "PROHIBITED", "no requisition after it")
	check(not w.facts.query("LAW_EMERGENCY_ENDED").is_empty(), "public end fact")


func test_emergency_needs_parliament() -> void:
	var s := _parliament()
	var w := s.world
	_crisis(w)
	var r := LawOps.declare_emergency(w, "HEALTH", GOV)
	check(r["ok"] and r["needs_approval"], "government declares, parliament must approve: %s" % [r])
	s.run(3)
	check(not LQ.emergency(w)["active"], "lapsed without approval")
	check_eq(w.facts.query("LAW_EMERGENCY_ENDED")[0]["data"]["reason"], "LAPSED", "reason LAPSED")
	_crisis(w)
	LawOps.declare_emergency(w, "HEALTH", GOV)
	LawOps.approve_emergency(w, true)
	s.run(3)
	check(LQ.emergency(w)["active"], "approved: in force")
	Staff.pol_state(w)["caretaker"] = true
	check(LawOps.check_change(w, "LAW_PRICE_CONTROL", "ESSENTIALS", "REGULATION").is_empty(), "even a caretaker may use emergency levers")
	check(not LawOps.check_change(w, "LAW_PERMIT_STRICTNESS", "STRICT", "REGULATION").is_empty(), "but not other regulations")
	Staff.pol_state(w)["caretaker"] = false
	check(LawOps.renew_emergency(w)["ok"], "renewal")
	s.run(LawOps.EMERGENCY_MAX_MONTHS + 1)
	check(not LQ.emergency(w)["active"], "expires after 6 months without a new renewal")


## A crisis inquiry finds the hidden cause: scandal for company and government, TORT case, victims compensated.
func test_inquiry_reveals_cause_and_tort() -> void:
	var s := F.sim(24, true)
	var w := s.world
	var wref := Staff.w_ref_milli(w)
	var fid := LawOps.record_greed(w, "org:5", {"kind": "DEFERRED_UPKEEP", "facility": "fac:5", "since_month": w.month - 14,
		"evidence": 1000, "hazard_ids": ["hz:mine5"], "saving": 3 * wref})
	for _i in 3:
		_crisis(w, 70, {"hazard": "hz:mine5", "facility": "fac:5", "damages": 40 * wref, "scope": {"employer": "org:5"}})
	s.run(8)
	var rev := w.facts.query("LAW_CRISIS_CAUSE_REVEALED")
	check(not rev.is_empty(), "cause revealed by the inquiry")
	if rev.is_empty():
		return
	var d: Dictionary = rev[0]["data"]
	check(d["org"] == "org:5" and d["months_hidden"] >= 12 and is_equal_approx(float(d["gov_share"]), 0.3), "scandal data: %s" % [d])
	var resp: Array = rev[0]["responsible"]
	check(resp.size() == 2 and resp[1]["actor"]["kind"] == "GOVERNMENT", "company and government blamed")
	check(w.table("violation_track")[fid]["revealed"], "the SECRET cause is public")
	var torts: Array = w.table("case").values().filter(func(c): return c["type"] == "TORT")
	check(not torts.is_empty() and int(torts[0]["data"]["claim"]) == 40 * wref, "TORT filed for the damages")
	check(not w.facts.query("LAW_INQUIRY_CLOSED").is_empty(), "inquiry report")
	# Judgment: company pays 70%, the state 30% (oversight failure), into the victim fund as an award.
	if not w.ledger.has_account("gov:treasury"):
		w.ledger.open_account("gov:treasury", true)
	w.ledger.open_account("co:org:5")
	w.ledger.transfer(Ledger.EXTERNAL, "co:org:5", 100 * wref, "seed", w.month)
	J._final(w, torts[0], true)
	var paid := 0
	for a in w.table("victim_award").values():
		paid += int(a["amount"])
	check_eq(paid, 40 * wref, "victims awarded the full damages")


func test_severe_conviction_names_manager() -> void:
	var s := F.sim(25, true)
	var w := s.world
	w.table("org")["org:7"] = {"id": "org:7", "ceo": {"name": "R. Greed"}, "pl_last": {}}
	var fid := LawOps.record_greed(w, "org:7", {"kind": "DUMPING", "facility": "fac:7"})
	w.table("violation_track")[fid]["class"] = "SEVERE"
	var cid := J.file_case(w, "ENFORCEMENT", J.STATE, {"kind": "COMPANY", "id": "org:7"}, true, {"violation": fid, "class": "SEVERE"})
	J._final(w, w.table("case")[cid], true)
	var m := w.facts.query("LAW_MANAGER_CONVICTED")
	check(m.size() == 1 and m[0]["data"]["ceo"] == "R. Greed", "manager convicted")
