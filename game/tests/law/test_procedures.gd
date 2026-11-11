extends TestCase
## M7 groundwork: constitutional procedures (no-confidence, extra elections, caretaker limits) and the staff side
## of a coalition partner leaving.

const F := preload("res://tests/support/staff_fixture.gd")
const LQ := preload("res://sim/law/law_query.gd")
const RE := preload("res://sim/law/rules_engine.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}


## Parliament with a P1+P2+P3 coalition formed in month 1 after an election in month 0.
func _world() -> Simulation:
	var s := F.sim(41, true)
	var w := s.world
	for p in [["P1", 50], ["P2", 20], ["P3", 15], ["P4", 40], ["P5", 10]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "commitments": [], "is_player": p[0] == "P1"}
	w.table("election")["election:1"] = {"id": "election:1", "month": 0, "seats": {}, "votes": {}, "total": 0}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": true, "elections": ["election:1"],
		"next_election": 48, "caretaker": false,
		"government": {"members": ["P1", "P2", "P3"], "pm_party": "P1", "support": [], "agreement": [], "formed_month": 0}})
	s.step()
	s.step()
	return s


func test_procedure_data() -> void:
	var s := _world()
	var p := LQ.procedures(s.world)
	check(p["in_force"], "constitution in force")
	check_eq(LQ.movers_needed(), 16, "one tenth of 151, rounded up")
	check_eq(int(p["no_confidence"]["topple_votes"]), 76, "absolute majority")
	check_eq(int(p["pm_votes"]["max_failed"]), 4, "four failed PM votes")
	check(not p["extra_election"]["resets_ordinary_calendar"], "extra elections don't reset the calendar")


func test_no_confidence_motion() -> void:
	var s := _world()
	var w := s.world
	check(LQ.can_move_no_confidence(w, "P4")["ok"], "40 seats may move a motion")
	var small := LQ.can_move_no_confidence(w, "P5")
	check(not small["ok"] and small["needed"] == 16, "10 seats may not: %s" % small["reason"])
	check(LQ.can_move_no_confidence(w, "P5", ["P3"])["ok"], "jointly with another party (25 seats)")
	Ops.pol_state(w)["caretaker"] = true
	check(not LQ.can_move_no_confidence(w, "P4")["ok"], "not against a caretaker")


func test_extra_election_rules() -> void:
	var s := _world()
	var w := s.world
	var r := LQ.extra_election_allowed(w)
	check(not r["ok"] and r["months_since_election"] < 3, "blocked within 3 months of the election: %s" % r["reason"])
	s.run(2)
	check(LQ.extra_election_allowed(w)["ok"], "allowed after 3 months")
	Ops.pol_state(w)["caretaker"] = true
	check(not LQ.extra_election_allowed(w)["ok"], "a caretaker may not call one")
	check(LQ.caretaker_limits(w)["caretaker"], "caretaker flagged")


## The rules engine enforces caretaker limits on the government.
func test_caretaker_enforced_by_engine() -> void:
	var s := _world()
	var w := s.world
	var reg := {"lever_id": "LAW_PERMIT_STRICTNESS", "instrument_level": "REGULATION", "founding_era": "COMMANDER", "lever_level": "REGULATION"}
	check_eq(RE.validate(w, GOV, "SET_LEVER", reg)["result"], "AUTHORIZED", "regular government may regulate")
	check_eq(RE.validate(w, GOV, "HOLD_ELECTION", {"extra": true})["result"], "AUTHORIZED", "may call an extra election")
	Ops.pol_state(w)["caretaker"] = true
	check_eq(RE.validate(w, GOV, "SET_LEVER", reg)["result"], "PROHIBITED", "caretaker may not regulate")
	check_eq(RE.validate(w, GOV, "HOLD_ELECTION", {"extra": true})["result"], "PROHIBITED", "caretaker may not call an extra election")
	check_eq(RE.validate(w, GOV, "GRANT_SUBSIDY", {"appropriated": true})["result"], "PROHIBITED", "no new subsidies")
	var adm := {"lever_id": "STAFF_DEFAULT_AUTHORITY_PRESET", "instrument_level": "ADMIN", "founding_era": "COMMANDER", "lever_level": "ADMIN"}
	check_eq(RE.validate(w, GOV, "SET_LEVER", adm)["result"], "AUTHORIZED", "admin decisions continue")


## A partner leaves: its officials go, tasks they held go vacant, seats are reallocated, a PUBLIC fact blames the leaver.
func test_partner_leaves_coalition() -> void:
	var s := _world()
	var w := s.world
	var seats_before := {}
	for sid in w.table("gov_seat"):
		var pty: String = w.table("gov_seat")[sid]["party_id"]
		seats_before[pty] = int(seats_before.get(pty, 0)) + 1
	check_eq(seats_before, {"P1": 6, "P2": 2, "P3": 2}, "Sainte-Laguë 50/20/15")
	var r := Ops.on_coalition_change(w, ["P1", "P2", "P3"], ["P1", "P2"])
	check_eq(r["departed"].size(), 2, "both P3 officials left")
	for pid in r["departed"]:
		check_eq(Ops.person(w, pid)["pool"] != "GOV", true, "no longer in government")
	var seats_after := {}
	for sid in w.table("gov_seat"):
		var pty: String = w.table("gov_seat")[sid]["party_id"]
		seats_after[pty] = int(seats_after.get(pty, 0)) + 1
	check_eq(seats_after, {"P1": 7, "P2": 3}, "10 seats reallocated 50/20")
	var f := w.facts.query("STAFF_OFFICIALS_WITHDRAWN")
	check_eq(f.size(), 1, "public fact")
	check_eq(f[0]["responsible"][0]["actor"]["id"], "P3", "the leaving party is responsible")
	check(Ops.pool_members(w, {"kind": "PARTY", "id": "P3"}).size() > 0, "P3 now has opposition staff")
	s.step()
	var errs := Ops.check_invariants(w)
	check(errs.is_empty(), "invariants: %s" % [errs])


## The single gate: discretionary extra elections go through the rules engine; mandatory ones always pass.
func test_check_extra_election_gate() -> void:
	var LawOps := preload("res://sim/law/law_ops.gd")
	var s := _world()
	var w := s.world
	s.run(2)
	check(LawOps.check_extra_election(w)["ok"], "regular government after 3 months")
	Ops.pol_state(w)["caretaker"] = true
	var r := LawOps.check_extra_election(w)
	check(not r["ok"] and not r["trace"].is_empty(), "caretaker blocked by a constitutional rule (trace): %s" % r["reason"])
	check(LawOps.check_extra_election(w, true)["ok"], "mandatory extra election (4 failed PM votes) always lawful")
	check_eq(LQ.extra_election_allowed(w)["ok"], false, "LQ delegates to the same gate")
