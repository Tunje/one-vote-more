extends TestCase
## Assignment engine and political integration: S tests A–L, ST3, ST5, ST7.

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")


func _supervise(w: WorldState) -> String:
	return Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "MEDIUM"}, Ops.GOV)["id"]


## S-A/C/D: single assignment, ineligible rejected, alternative talent path accepted.
func test_assignment_and_qualification() -> void:
	var w := F.bare_world()
	var eng := F.add(w, "CIVIL", {"ENG": 70})
	var weak := F.add(w, "CIVIL", {"ENG": 50})
	var weak_fs := F.add(w, "CIVIL", {"ENG": 50}, 50, 100, "", ["FIELD_SUPERVISOR"])
	var t1 := _supervise(w)
	var t2 := _supervise(w)
	check(not Ops.assign(w, t1, 0, weak)["ok"], "ENG 50 without talent rejected")
	check(Ops.assign(w, t1, 0, weak_fs)["ok"], "ENG 50 + Field Supervisor accepted (alt path)")
	check(Ops.assign(w, t2, 0, eng)["ok"], "eng assigned")
	var t3 := _supervise(w)
	check(not Ops.assign(w, t3, 0, eng)["ok"], "one assignment per official")
	check(Ops.check_invariants(w).filter(func(e): return not e.begins_with("civil service")).is_empty(), "invariants")


## S-B/G/H/I: missing mandatory pauses; unassign keeps progress and others; replacement resumes.
func test_pause_unassign_replace_preserve_progress() -> void:
	var w := F.bare_world()
	var a := F.add(w, "CIVIL", {"ADMIN": 60, "ECON": 40})
	var b := F.add(w, "CIVIL", {"ENG": 60})
	var c := F.add(w, "CIVIL", {"ADMIN": 60})
	var tid: String = Ops.create_task(w, "STAFF_T_PROCURE", {"construction": true}, Ops.GOV)["id"]
	Ops.assign(w, tid, 0, a)
	F.work_month(w)
	check_eq(Ops.task(w, tid)["progress"], 0, "paused without technical adviser")
	check(Ops.task(w, tid)["paused"], "paused flag")
	Ops.assign(w, tid, 1, b)
	F.work_month(w)
	var p1: int = Ops.task(w, tid)["progress"]
	check(p1 > 0, "progress once staffed")
	Ops.unassign(w, a)
	check_eq(Ops.task(w, tid)["progress"], p1, "progress kept after unassign")
	check(Ops.person(w, b)["assignment_id"] != "", "other member stays")
	F.work_month(w)
	check_eq(Ops.task(w, tid)["progress"], p1, "paused again")
	check(Ops.replace(w, tid, 0, c)["ok"], "replace into vacant lead")
	check(Ops.replace(w, tid, 0, a)["ok"], "replace occupied lead")
	check_eq(Ops.person(w, c)["assignment_id"], "", "replaced person released")
	F.work_month(w)   # stage 0 (20 WU) was done in month 1, so this month is the 1-month tender gate
	check_eq(Ops.task(w, tid)["stage"], 2, "tender gate passed, evaluation stage")
	F.work_month(w)
	var t := Ops.task(w, tid)
	check(t["progress"] > p1 or t["status"] == "COMPLETED", "resumes without reset")
	check_eq(t["status"], "COMPLETED", "procurement done after evaluation")


## ST3: a partner official refuses a task that conflicts with a core commitment; negotiable -> friction.
func test_st3_partner_refusal_and_friction() -> void:
	var w := F.bare_world()
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1",
		"government": {"members": ["P1", "P2", "P3"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	w.table("party")["P1"] = {"id": "P1", "is_player": true, "seats": 50, "status": "ACTIVE", "commitments": []}
	w.table("party")["P2"] = {"id": "P2", "seats": 20, "status": "ACTIVE",
		"commitments": [{"lever": "LAW_SAFETY_STANDARD", "dir": -1, "kind": "CORE", "weight": 1}]}
	w.table("party")["P3"] = {"id": "P3", "seats": 10, "status": "ACTIVE",
		"commitments": [{"lever": "LAW_SAFETY_STANDARD", "dir": -1, "kind": "NEGOTIABLE", "weight": 1}]}
	var p2 := F.add(w, "POLITICAL", {"ADMIN": 70}, 60, 100, "P2")
	var p3 := F.add(w, "POLITICAL", {"ADMIN": 70}, 60, 100, "P3")
	var params := {"levers": 1, "lever_deltas": [{"lever": "LAW_SAFETY_STANDARD", "dir": 1}]}
	var t: String = Ops.create_task(w, "STAFF_T_IMPL_ADMIN", params, Ops.GOV)["id"]
	var r := Ops.assign(w, t, 0, p2)
	check(not r["ok"] and String(r["reason"]).begins_with("refused"), "core conflict refused: %s" % r)
	check(Ops.assign(w, t, 0, p3)["ok"], "negotiable conflict allowed")
	F.work_month(w)
	check_eq(w.facts.query("STAFF_PARTNER_FRICTION").size(), 1, "friction fact")


## ST5: party work while governing uses governing capacity; campaign effort = W·(0.5+Q/200).
func test_st5_campaign_costs_governing_capacity() -> void:
	var w := F.bare_world()
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1",
		"government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	w.table("party")["P1"] = {"id": "P1", "is_player": true, "seats": 80, "status": "ACTIVE", "commitments": []}
	var comm := F.add(w, "POLITICAL", {"COMM": 70, "POLI": 50}, 60, 100, "P1")
	var civil := F.add(w, "CIVIL", {"COMM": 80})
	var owner := {"kind": "PARTY", "id": "P1"}
	check_eq(Ops.available(w, Ops.GOV).size(), 2, "both serve government before")
	var camp: String = Ops.create_task(w, "STAFF_T_CAMPAIGN", {}, owner)["id"]
	check(not Ops.assign(w, camp, 0, civil)["ok"], "civil servant cannot campaign (neutrality)")
	check(Ops.assign(w, camp, 0, comm)["ok"], "own official campaigns")
	check_eq(Ops.available(w, Ops.GOV), [civil], "official no longer available to government")
	F.work_month(w)
	var t := Ops.task(w, camp)
	var p := Ops.person(w, comm)
	var suit := 0.7 * 70 + 0.3 * 50
	var w_i := 10.0 * (0.6 + 0.008 * 60) * (0.4 + 0.012 * suit)
	var q := 0.7 * suit + 0.3 * 100
	check_eq(t["outputs"]["campaign_effort"], int(round(w_i * (0.5 + q / 200.0) * 1000)), "campaign effort")
	check_eq(w.facts.query("STAFF_CAMPAIGN_EFFORT").size(), 1, "effort fact")
	check(p["assignment_id"] != "", "still assigned (coverage task)")


## ST7: unmanaged standing duty -> e = 0 (multiplier 0.85) and STAFF_DUTY_UNMANAGED once.
func test_st7_unmanaged_duty() -> void:
	var w := F.bare_world()
	var t: String = Ops.create_task(w, "STAFF_SD_SERVICES", {}, Ops.GOV)["id"]
	for _i in 6:
		F.work_month(w)
	check_eq(Ops.duty_effectiveness(w, "STAFF_SD_SERVICES"), 0, "e = 0")
	check_eq(w.facts.query("STAFF_DUTY_UNMANAGED").size(), 1, "emitted once")
	var pubs := F.add(w, "CIVIL", {"PUBS": 80}, 50, 90)
	Ops.assign(w, t, 0, pubs)
	F.work_month(w)
	check(Ops.duty_effectiveness(w, "STAFF_SD_SERVICES") > 500, "managed e > 0.5")


## S-L: delegated authority presets decide auto vs escalated commitments; escalation blocks the task.
func test_delegated_authority() -> void:
	var w := F.bare_world()
	var a := F.add(w, "CIVIL", {"ENG": 70})
	var t: String = Ops.create_task(w, "STAFF_T_SUPERVISE", {"size": "MEDIUM", "budget": 100000}, Ops.GOV)["id"]
	Ops.assign(w, t, 0, a)
	check_eq(Ops.request_commitment(w, t, 9000), "AUTO", "9% under STANDARD 10%")
	check_eq(Ops.request_commitment(w, t, 11000), "ESCALATED", "11% escalates")
	check(Ops.task_blocked(w, t), "task blocked by decision")
	var rid: String = w.table("decision_request").keys()[0]
	check(Ops.answer_decision(w, rid, "APPROVE")["ok"], "answer")
	check_eq(Ops.task(w, t)["spent"], 20000, "spent after approval")
	Ops.set_preset(w, t, "TIGHT")
	check_eq(Ops.request_commitment(w, t, 3000), "ESCALATED", "TIGHT 2%")


## Training: +5 after 3 months, capped at 85.
func test_training() -> void:
	var w := F.bare_world()
	var a := F.add(w, "CIVIL", {"LAW": 82})
	check(Ops.train(w, a, "LAW")["ok"], "start training")
	for _i in 3:
		F.work_month(w)
	check_eq(Ops.person(w, a)["skills"]["LAW"], 85, "capped at 85")
	check_eq(Ops.person(w, a)["assignment_id"], "", "released")


## Government formation: seats allocated, partner AI appoints its own officials, departing officials leave.
func test_government_formation_and_transition() -> void:
	var s := F.sim(4)
	var w := s.world
	F.set_pol(w, {"era": "FOUNDING", "player_party": "P1", "autoplay_player": false, "elections": []})
	w.table("party")["P1"] = {"id": "P1", "is_player": true, "seats": 0, "status": "ACTIVE", "commitments": []}
	s.step()
	var people := w.table("person")
	var appointees := 0
	for pid in people:
		if people[pid]["pool"] == "GOV" and people[pid]["roles"].has("GOV_POLITICAL"):
			appointees += 1
			check_eq(people[pid]["party_id"], "P1", "founding appointees join the player's party (X4)")
	check_eq(appointees, 10, "10 founding appointees")
	w.table("party")["P1"]["seats"] = 49
	w.table("party")["P2"] = {"id": "P2", "seats": 28, "status": "ACTIVE", "commitments": []}
	w.table("party")["P3"] = {"id": "P3", "seats": 19, "status": "ACTIVE", "commitments": []}
	w.table("party")["P4"] = {"id": "P4", "seats": 55, "status": "ACTIVE", "commitments": []}
	var st := Ops.pol_state(w)
	st["era"] = "PARLIAMENTARY"
	st["government"] = {"members": ["P1", "P2", "P3"], "pm_party": "P1", "agreement": [], "formed_month": w.month}
	s.step()
	var by_party := {}
	for sid in w.table("gov_seat"):
		var seat: Dictionary = w.table("gov_seat")[sid]
		by_party[seat["party_id"]] = int(by_party.get(seat["party_id"], 0)) + 1
		if seat["party_id"] != "P1":
			check(seat["person_id"] != "", "partner AI filled its seat")
	check_eq(by_party, {"P1": 5, "P2": 3, "P3": 2}, "seat allocation")
	var opp := 0
	for pid in people:
		if people[pid]["pool"] == "PARTY:P4":
			opp += 1
	check_eq(opp, Ops.opposition_pool_size(55), "opposition pool for P4")
	var errs := Ops.check_invariants(w)
	check(errs.is_empty(), "invariants: %s" % [errs])
