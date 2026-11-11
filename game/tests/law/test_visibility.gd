extends TestCase
## Information access model (planning/spec-visibility.md).

const F := preload("res://tests/support/staff_fixture.gd")
const Vis := preload("res://sim/law/visibility.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const SQ := preload("res://sim/staff/staff_query.gd")
const LQ := preload("res://sim/law/law_query.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")
const A := preload("res://sim/staff/staff_law_actions.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}


func _v(pid: String) -> Dictionary:
	return {"party_id": pid}


## Founding (P1 = player = commander's party) for 2 months, then a P2 cabinet with P3 as support party.
func _world() -> Simulation:
	var s := F.sim(21, true)
	var w := s.world
	F.set_pol(w, {"era": "FOUNDING", "player_party": "P1", "autoplay_player": true, "elections": []})
	for p in [["P1", 40], ["P2", 60], ["P3", 20], ["P4", 31]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "commitments": [], "is_player": p[0] == "P1"}
	s.run(2)
	return s


func _form_p2(s: Simulation) -> void:
	var st := Ops.pol_state(s.world)
	st["era"] = "PARLIAMENTARY"
	st["government"] = {"members": ["P2"], "pm_party": "P2", "support": ["P3"], "agreement": [], "formed_month": s.world.month}
	s.step()


func _fact(w: WorldState, type: String, vis: String, resp_kind: String = "GOVERNMENT", subjects: Array = []) -> Dictionary:
	var id := w.add_fact({"type": type, "owner": "law", "subjects": subjects,
		"responsible": [{"actor": {"kind": resp_kind, "id": "government"}, "share": 1.0}], "impact": {}, "magnitude": 30,
		"visibility": vis})
	return w.facts.get_fact(id)


func test_roles_over_time() -> void:
	var s := _world()
	var w := s.world
	check_eq(Vis.role(w, "P1"), "GOVERNING", "commander era: the player's party governs")
	check_eq(Vis.role(w, "P2"), "OPPOSITION", "others are opposition")
	_form_p2(s)
	check_eq(Vis.role(w, "P2"), "GOVERNING", "cabinet member")
	check_eq(Vis.role(w, "P3"), "SUPPORT", "support party")
	check_eq(Vis.role(w, "P1"), "OPPOSITION", "former government now in opposition")
	check_eq(Vis.role(w, "P1", 0), "GOVERNING", "but governed in month 0")


func test_fact_rules() -> void:
	var s := _world()
	var w := s.world
	var official_founding := _fact(w, "STAFF_BUDGET_READY", "OFFICIAL", "COMMANDER")
	s.step()
	_form_p2(s)
	var pub := _fact(w, "LAW_RULING", "PUBLIC")
	var secret := _fact(w, "LAW_UNLAWFUL_GOV_ACTION", "SECRET")
	var own := _fact(w, "STAFF_POLL_RESULT", "OFFICIAL", "PARTY", [{"kind": "PARTY", "id": "P4"}])
	s.step()
	for p in ["P1", "P2", "P3", "P4"]:
		check(Vis.can_see_fact(w, _v(p), pub), "PUBLIC for " + p)
	check(Vis.can_see_fact(w, _v("P1"), official_founding), "P1 governed when the OFFICIAL fact happened")
	check(Vis.can_see_fact(w, _v("P2"), official_founding), "current government inherits the files")
	check(not Vis.can_see_fact(w, _v("P4"), official_founding), "opposition cannot see OFFICIAL")
	check(not Vis.can_see_fact(w, _v("P3"), official_founding), "support party does not see OFFICIAL facts")
	check(Vis.can_see_fact(w, _v("P2"), secret), "the government knows its own secret")
	check(not Vis.can_see_fact(w, _v("P1"), secret), "others do not")
	check(not Vis.can_see_fact(w, _v("P3"), secret), "support party does not")
	check(Vis.can_see_fact(w, _v("P4"), own), "a party sees facts about itself")
	check(not Vis.can_see_fact(w, _v("P1"), own), "but not other parties' polls")
	check(Vis.can_see_fact(w, {}, secret), "the simulation sees everything")
	var rid := w.facts.reveal(w.month, secret["id"], [])
	check(Vis.can_see_fact(w, _v("P1"), w.facts.get_fact(rid)), "a reveal is PUBLIC")
	# A later government does not inherit the predecessor's secrets.
	var st := Ops.pol_state(w)
	st["government"] = {"members": ["P4"], "pm_party": "P4", "support": [], "agreement": [], "formed_month": w.month}
	s.step()
	check(not Vis.can_see_fact(w, _v("P4"), secret), "new government does not see the old secret")
	check(Vis.can_see_fact(w, _v("P2"), secret), "the old government still knows")


func test_indicators_and_oversight_grant() -> void:
	var s := _world()
	var w := s.world
	_form_p2(s)
	w.indicators.define({"id": "LAW_TEST_OFFICIAL", "owner": "law", "unit": "x", "range": [0, 1], "granularity": "COLONY",
		"polarity": 1, "concerns": {}, "normalize": {"good": 1, "bad": 0}, "phase": TickPhase.JUSTICE, "visibility": "OFFICIAL"})
	check(Vis.can_see_indicator(w, _v("P2"), "LAW_TEST_OFFICIAL"), "government sees OFFICIAL indicators")
	check(Vis.can_see_indicator(w, _v("P3"), "LAW_TEST_OFFICIAL"), "support party too")
	check(not Vis.can_see_indicator(w, _v("P4"), "LAW_TEST_OFFICIAL"), "opposition does not")
	check(Vis.can_see_indicator(w, _v("P4"), "LAW_RULE_OF_LAW"), "PUBLIC indicators for all")
	check_eq(LQ.indicator(w, _v("P4"), "LAW_TEST_OFFICIAL"), null, "hidden value is null")
	var old := _fact(w, "LAW_PERMIT_DENIED", "OFFICIAL")
	# Opposition inquiry into LAW_ (completed by staff): access to OFFICIAL LAW_ facts (24 months) and indicators (6 months).
	var t: String = Ops.create_task(w, "STAFF_T_OVERSIGHT", {"domain_prefixes": ["LAW_"]}, {"kind": "PARTY", "id": "P4"})["id"]
	Ops.complete_task(w, Ops.task(w, t))
	check(Vis.can_see_fact(w, _v("P4"), old), "inquiry reveals OFFICIAL facts in its domain")
	check(Vis.can_see_indicator(w, _v("P4"), "LAW_TEST_OFFICIAL"), "and the domain's OFFICIAL indicators")
	check(not Vis.can_see_fact(w, _v("P1"), old), "only for the inquiring party")
	w.month += 7
	check(not Vis.can_see_indicator(w, _v("P4"), "LAW_TEST_OFFICIAL"), "indicator access expires after 6 months")
	check(Vis.can_see_fact(w, _v("P4"), old), "facts once seen stay known")
	var later := _fact(w, "LAW_PERMIT_DENIED", "OFFICIAL")
	check(not Vis.can_see_fact(w, _v("P4"), later), "but not facts after the inquiry")
	check(LQ.access(w, "P4")["grants"].size() == 1, "access panel lists the live fact grant only")


func test_court_case_grants_party_access() -> void:
	var s := _world()
	var w := s.world
	_form_p2(s)
	var secret := _fact(w, "LAW_UNLAWFUL_GOV_ACTION", "SECRET")
	check(not Vis.can_see_fact(w, _v("P4"), secret), "secret before the case")
	J.file_case(w, "UNLAWFUL_GOV", {"kind": "PARTY", "id": "P4"}, GOV, true, {"unlawful_fact": secret["id"]})
	# Court access covers the case file (granted as FACT_IDS); SECRET facts stay limited to the actors themselves:
	check(LQ.access(w, "P4")["grants"].any(func(g): return g["kind"] == "FACT_IDS" and g["ids"].has(secret["id"])), "case grant recorded")


func test_queries_respect_viewer() -> void:
	var s := _world()
	var w := s.world
	_form_p2(s)
	check(not SQ.briefing(w, Ops.GOV, -1, _v("P2")).is_empty(), "government sees its briefing")
	check(SQ.briefing(w, Ops.GOV, -1, _v("P4")).is_empty(), "opposition does not")
	check(SQ.roster(w, Ops.GOV, _v("P4")).is_empty(), "nor the government roster")
	check(not SQ.roster(w, {"kind": "PARTY", "id": "P4"}, _v("P4")).is_empty(), "but its own staff")
	var civil: String = Ops.pool_members(w, Ops.GOV)[0]
	check(SQ.person_view(w, civil, _v("P4")).get("public_only", false), "public profile only for outsiders")
	check(not SQ.person_view(w, civil, _v("P2")).has("public_only"), "full profile for the government")
	check(not LQ.decree_check(w, "LAW_PERMIT_STRICTNESS", "STRICT", _v("P4"))["allowed"], "only the government decrees")
	A.apply(w, {"id": "LAW_DECREE", "actor": GOV, "args": {"lever": "LAW_EXTRACTION_ROYALTY", "value": 1500, "confirm_unlawful": true}})
	var e4: Array = LQ.enactments(w, true, _v("P4")).filter(func(e): return e["lever"] == "LAW_EXTRACTION_ROYALTY")
	var e2: Array = LQ.enactments(w, true, _v("P2")).filter(func(e): return e["lever"] == "LAW_EXTRACTION_ROYALTY")
	check(not e4[0]["unlawful"] and e4[0]["implementation"].is_empty(), "opposition sees the change, not that it is unlawful")
	check(e2[0]["unlawful"], "the government knows")
	var feed4 := LQ.fact_feed(w, _v("P4"), -1, "LAW_UNLAWFUL")
	check(feed4.is_empty(), "secret not in the opposition's feed")
	check(not LQ.fact_feed(w, _v("P2"), -1, "LAW_UNLAWFUL").is_empty(), "but in the government's")
