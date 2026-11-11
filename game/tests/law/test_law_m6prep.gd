extends TestCase
## M6 prep: permit queue (spec-law §10), unlawful action + reveal (§8, LT6), law indicators (pic-staff-law §1).

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")


func _census(w: WorldState) -> void:
	for d in ["D1", "D2"]:
		for occ in ["INDUSTRY", "BUSINESS_OWNER", "RETIRED"]:
			w.table("census")["%s|%s|MID" % [d, occ]] = 500


## Unmanaged office decides 2 per month FIFO; a staffed permit duty raises capacity toward 12.
func test_permit_queue_capacity_and_fifo() -> void:
	var s := F.sim(1, false)
	var w := s.world
	_census(w)
	var ids: Array = []
	for i in 10:
		ids.append(LawOps.apply_licence(w, "co:%d" % i, "licence", "EXTRACTION", "D1", true, 120))
	check_eq(LawOps.permit_capacity(w), 2, "unmanaged capacity 2")
	s.step()
	var decided := ids.filter(func(id): return w.table("permit_application")[id]["status"] != "QUEUED")
	check_eq(decided, [ids[0], ids[1]], "FIFO, 2 decided")
	check(w.indicators.read("LAW_PERMIT_WAIT", "D1", -1) >= 0, "permit wait published for D1")
	check_eq(w.indicators.read("LAW_PERMIT_WAIT", "D2", -1), -1, "no applications in D2 -> no value")
	w.meta["staff_autoplay"] = true
	s.run(3)
	check(LawOps.permit_capacity(w) >= 8, "staffed capacity %d" % LawOps.permit_capacity(w))
	var granted := 0
	for id in ids:
		if w.table("permit_application")[id]["status"] == "GRANTED":
			granted += 1
	check(granted >= 8, "most applications granted (%d)" % granted)
	check(RE_ok(w, "co:9") or w.table("permit_application")[ids[9]]["status"] != "GRANTED", "licence usable when granted")
	var budget_cut := LawOps.permit_capacity(w)
	w.levers["LAW_PERMIT_OFFICE_BUDGET"] = 3000
	check(LawOps.permit_capacity(w) <= budget_cut / 2 + 1, "half budget, about half capacity")


func RE_ok(w: WorldState, co: String) -> bool:
	return LawOps.validate(w, {"kind": "COMPANY", "id": co}, "EXTRACT_RESOURCE", {})["result"] == "AUTHORIZED"


## Wrong decisions: low quality produces wrongly denied (PUBLIC) and wrongly granted (SECRET) facts.
func test_permit_errors_from_low_quality() -> void:
	var s := F.sim(2, false)
	var w := s.world
	_census(w)
	for i in 400:
		LawOps.apply_licence(w, "co:%d" % i, "licence", "HAZARD", "D1", i % 2 == 0, 60)
	for _m in 200:
		LawOps.process_permits(w)
		w.month += 1
	var wrong_deny := w.facts.query("LAW_PERMIT_WRONGLY_DENIED").size()
	var wrong_grant := w.facts.query("LAW_PERMIT_WRONGLY_GRANTED", -1, 9999, "SECRET").size()
	# unmanaged Q = 40 -> p_wrong = 15%: ~30 of 200 eligible wrongly denied, ~30 of 200 ineligible wrongly granted
	check(wrong_deny > 10 and wrong_deny < 55, "wrongly denied %d" % wrong_deny)
	check(wrong_grant > 10 and wrong_grant < 55, "wrongly granted %d" % wrong_grant)


## LT6: an unlawful government action is SECRET, gets revealed (seeded), and drops LAW_RULE_OF_LAW.
func test_lt6_unlawful_action_revealed_hits_rule_of_law() -> void:
	var s := F.sim(3, false)
	var w := s.world
	_census(w)
	var gov := {"kind": "GOVERNMENT", "id": "government"}
	check(not LawOps.proceed_unlawfully(w, {"kind": "COMMANDER", "id": "commander"}, "BUILD_FACILITY", {})["ok"],
		"lawful actions are not 'unlawful'")
	F.set_pol(w, {"era": "PARLIAMENTARY", "government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	var r := LawOps.proceed_unlawfully(w, gov, "RESTRICT_ASSEMBLY", {"scope": "D1"}, "", {"kind": "PARTY", "id": "P2"}, "SERIOUS")
	check(r["ok"], "recorded")
	check_eq(w.facts.get_fact(r["fact"])["visibility"], "SECRET", "secret")
	s.step()
	check_eq(w.indicators.read("LAW_RULE_OF_LAW"), 100000, "nothing revealed yet -> 100")
	var m := 0
	while w.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED").is_empty() and m < 60:
		s.step()
		m += 1
	check(m < 60, "revealed within 60 months (leak 3% + complaint 10%/month)")
	s.step()
	var rol := w.indicators.read("LAW_RULE_OF_LAW")
	check(rol < 85000 and rol > 70000, "rule of law dropped by ~20 (%d)" % rol)
	s.run(24)
	check(w.indicators.read("LAW_RULE_OF_LAW") > rol, "recovers as the reveal ages")


## Oversight (staff) and law discovery share revealed_fact: no double reveal.
func test_oversight_reveal_not_duplicated() -> void:
	var s := F.sim(4, true)
	var w := s.world
	F.set_pol(w, {"era": "PARLIAMENTARY", "government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	var r := LawOps.proceed_unlawfully(w, {"kind": "GOVERNMENT", "id": "government"}, "RESTRICT_EXPRESSION", {})
	w.table("revealed_fact")[r["fact"]] = true   # as if STAFF_T_OVERSIGHT revealed it
	w.facts.reveal(w.month, r["fact"], [{"kind": "PARTY", "id": "P2"}])
	s.run(36)
	check_eq(w.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED").size(), 1, "revealed once")


## Trust in justice per occupation; workplace safety only with a real economy (ECON_W_REF), lever-driven stub rate.
func test_trust_and_safety_indicators() -> void:
	var s := F.sim(5, false)
	var w := s.world
	_census(w)
	s.step()
	var t_ind := w.indicators.read("LAW_TRUST_IN_JUSTICE", "D1|INDUSTRY|MID")
	check(t_ind > 55000, "trust moves up from 55 toward its target (%d)" % t_ind)
	check_eq(w.indicators.read("LAW_WORKPLACE_SAFETY", "D1", -1), -1, "no safety series under the stub world")
	w.meta["ECON_W_REF"] = 1200000
	s.step()
	check_eq(w.indicators.read("LAW_WORKPLACE_SAFETY", "D1"), 3750, "BASIC expected rate")
	w.levers["LAW_SAFETY_STANDARD"] = "STRICT"
	s.step()
	check_eq(w.indicators.read("LAW_WORKPLACE_SAFETY", "D1"), 1700, "STRICT expected rate")
	w.add_fact({"type": "COMP_WORKPLACE_ACCIDENT", "owner": "comp", "subjects": [], "responsible": [], "impact": {"SAFETY": -5},
		"magnitude": 10, "visibility": "PUBLIC", "data": {"district": "D1", "workers_affected": 2}})
	s.step()
	# 1 accident / 1000 workers (INDUSTRY+BUSINESS_OWNER in D1) annualized over months elapsed
	check(w.indicators.read("LAW_WORKPLACE_SAFETY", "D1") > 0, "fact-based rate")
	check_eq(w.indicators.read("LAW_WORKPLACE_SAFETY", "D2"), 0, "no accidents in D2")


## Licences are renewed through the permit queue before expiry and stay valid while the renewal is decided.
func test_licence_renewal() -> void:
	var s := F.sim(9, true)
	var w := s.world
	var RE := preload("res://sim/law/rules_engine.gd")
	var lid := LawOps.grant_licence(w, "org:77", "licence", "HAZARD", 6)
	var exp0 := int(w.table("licence")[lid]["expiry_month"])
	for _i in 10:
		s.step()
		check(RE.has_licence(w, "org:77", "licence", "HAZARD"), "valid at month %d" % w.month)
	var l: Dictionary = w.table("licence")[lid]
	check(int(l["expiry_month"]) > exp0, "renewed: expiry %d > %d" % [l["expiry_month"], exp0])
	var renewals := w.table("permit_application").values().filter(func(a): return a.get("renews", "") == lid)
	check(renewals.size() >= 1, "renewed through the queue (%d applications)" % renewals.size())
