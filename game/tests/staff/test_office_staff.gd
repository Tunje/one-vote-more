extends TestCase
## O5 (planning/spec-office-v1.md): staff author office items, the chief of staff sorts (and buries), delegation,
## hiring by interview with hidden stats and bluffing, and beliefs that converge through work.

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const OFS := preload("res://sim/staff/office_staff.gd")
const Det := preload("res://sim/staff/det.gd")

const MARKET := {"ECON_ROLE": -80000}
const STATE := {"ECON_ROLE": 80000}


func _person(w: WorldState, skills: Dictionary, lean: Dictionary = {}, loyalty: int = 70) -> String:
	var pid := F.add(w, "CIVIL", skills)
	var p := Ops.person(w, pid)
	var l := {"ECON_ROLE": 0, "REDISTRIBUTION": 0, "SOVEREIGNTY": 0}
	l.merge(lean, true)
	p["lean"] = l
	p["loyalty"] = loyalty
	p["temper"] = 60
	return pid


func _world(fin_skill: int, fin_lean: Dictionary, chief_skill: int = 90) -> WorldState:
	var w := F.bare_world()
	var fin := _person(w, {"ECON": fin_skill}, fin_lean)
	var chief := _person(w, {"ADMIN": chief_skill, "POLI": chief_skill})
	OFS.assign_role(w, "FINANCE", fin)
	OFS.assign_role(w, "CHIEF_OF_STAFF", chief)
	return w


func _email(w: WorldState, ref: String, prio: int = 50, kind: String = "EMAIL", cat: String = "") -> String:
	return Office.post(w, {"kind": kind, "subject": "Tender", "role": "FINANCE", "category": cat, "priority": prio,
		"options": [{"id": "MARKET", "label": "Private bid", "action": {}}, {"id": "STATE", "label": "Public works", "action": {}}],
		"default_option": "STATE", "summary_lines": ["Two bids.", "The private bid is 20% cheaper.", "The union objects."],
		"source": {"system": "test", "ref": ref},
		"hidden": {"options": {"MARKET": {"merit": 10, "lean": MARKET}, "STATE": {"merit": 30, "lean": STATE}}}})


func test_roles_are_filled_by_fit() -> void:
	var s := F.sim(3, true)
	s.step()
	var r: Dictionary = s.world.peek("office_role")
	check(r.has("CHIEF_OF_STAFF") and String(r["CHIEF_OF_STAFF"]["person"]) != "", "a chief of staff")
	var people := {}
	for k in r:
		if String(r[k]["person"]) != "":
			check(not people.has(r[k]["person"]), "one role per person")
			people[r[k]["person"]] = true


func test_skilled_author_follows_merit_and_signs() -> void:
	var w := _world(95, MARKET)
	var o := Office.get_item(w, _email(w, "a"))
	check_eq(String(o["from"]["role"]), "FINANCE", "authored by finance")
	check_eq(String(o["recommendation"]), "STATE", "a skilled adviser recommends the better option despite their lean")
	check(not o.has("hidden") or not o["hidden"].is_empty(), "truth kept hidden")
	check_eq(String(o["hidden"]["truth"]["best"]), "STATE", "the truth is recorded")


func test_weak_partisan_author_follows_their_lean() -> void:
	var w := _world(25, MARKET)
	var market := 0
	for i in 60:
		if String(Office.get_item(w, _email(w, "b%d" % i))["recommendation"]) == "MARKET":
			market += 1
	check(market > 35, "a weak market-minded adviser mostly recommends the market option (%d/60)" % market)


func test_empty_role_means_nobody_briefed_you() -> void:
	var w := F.bare_world()
	var o := Office.get_item(w, _email(w, "c"))
	check(String(o["recommendation"]) == "" and bool(o["hidden"].get("unauthored", false)), "no author, no advice")
	check_eq(String(o["summary"]), "Two bids.", "a bare summary")


func test_a_weak_chief_buries_important_mail_but_never_a_call() -> void:
	var w := _world(80, {}, 5)
	var buried := 0
	for i in 200:
		if bool(Office.get_item(w, _email(w, "d%d" % i, 90))["hidden"].get("buried", false)):
			buried += 1
	check(buried > 20, "a weak chief buries some important emails (%d/200)" % buried)
	for i in 50:
		var o := Office.get_item(w, _email(w, "e%d" % i, 95, "CALL"))
		check(not bool(o["hidden"].get("buried", false)) and int(o["priority"]) == 95, "calls are never buried or reordered")
	var w2 := _world(80, {}, 95)
	var b2 := 0
	for i in 200:
		if bool(Office.get_item(w2, _email(w2, "f%d" % i, 90))["hidden"].get("buried", false)):
			b2 += 1
	check(b2 < buried / 3, "a strong chief rarely does (%d)" % b2)


func test_delegation_is_explicit_and_revocable() -> void:
	var w := _world(90, {})
	var keep := _email(w, "g", 50, "EMAIL", "TENDER")
	check(OFS.delegate(w, "TENDER", "FINANCE")["ok"], "delegate tenders to finance")
	var id := _email(w, "h", 50, "EMAIL", "TENDER")
	var call := _email(w, "i", 90, "CALL", "TENDER")
	var done := OFS.run_delegation(w)
	check_eq(done.size(), 1, "one delegated email answered")
	check_eq(String(Office.get_item(w, id)["status"]), "DELEGATED", "answered by the staffer")
	check_eq(String(Office.get_item(w, keep)["status"]), "NEW", "posted before the delegation: still the player's")
	check_eq(String(Office.get_item(w, call)["status"]), "NEW", "calls are never delegated")
	OFS.revoke(w, "TENDER")
	var id2 := _email(w, "j", 50, "EMAIL", "TENDER")
	OFS.run_delegation(w)
	check_eq(String(Office.get_item(w, id2)["status"]), "NEW", "revoked: back to the player")


func _recruitment(w: WorldState, integrity: int, primary: int) -> String:
	var rid := Ops.open_recruitment(w, "FINANCE")
	for c in w.table("recruitment")[rid]["shortlist"]:
		c["integrity"] = integrity
		c["skills"]["ECON"] = primary
	return rid


func test_interview_signals_and_the_bluff_trap() -> void:
	var w := F.bare_world()
	var honest := 0.0
	var liar := 0.0
	for i in 40:
		var r1 := _recruitment(w, 90, 50)
		var r2 := _recruitment(w, 15, 50)
		var a := OFS.ask(w, OFS.start_interview(w, r1, 0), "EXPERIENCE")
		var b := OFS.ask(w, OFS.start_interview(w, r2, 0), "EXPERIENCE")
		honest += float(a["answer"]["signals"][0]["est"])
		liar += float(b["answer"]["signals"][0]["est"])
		if i == 0:
			check(int(b["answer"]["signals"][0]["sd"]) < int(a["answer"]["signals"][0]["sd"]), "the bluffer sounds surer")
			check_eq(int(a["minutes"]), 10, "costs interview time")
	check(liar / 40.0 > honest / 40.0 + 6.0, "low integrity inflates the answers (%.1f vs %.1f)" % [liar / 40.0, honest / 40.0])


func test_references_take_a_month_and_hire_keeps_impressions() -> void:
	var w := F.bare_world()
	var rid := _recruitment(w, 60, 70)
	var iid := OFS.start_interview(w, rid, 1)
	check(OFS.ask(w, iid, "TECHNICAL")["ok"], "a technical question")
	check(not OFS.ask(w, iid, "TECHNICAL")["ok"], "once")
	OFS.ask(w, iid, "REFERENCES")
	check_eq(String(w.table("interview")[iid]["reference"]["status"]), "PENDING", "references requested")
	w.month += 1
	OFS.resolve_references(w)
	check_eq(String(w.table("interview")[iid]["reference"]["status"]), "DONE", "back after a month")
	check(w.table("interview")[iid]["hr_note"].has("PRIMARY"), "HR's combined note")
	check(OFS.hire_from_interview(w, iid)["ok"], "hired on impressions")
	var cand: Dictionary = w.table("recruitment")[rid]["shortlist"][1]
	check(cand.has("known") and cand["known"].has("PRIMARY"), "the impression travels with the hire")


func test_beliefs_converge_through_work() -> void:
	var w := F.bare_world()
	var pid := _person(w, {"ECON": 80})
	var p := Ops.person(w, pid)
	p["known"] = {"PRIMARY": [40, 20]}
	p["assignment_id"] = "asg:x"
	for i in 24:
		OFS.update_known(w)
	check(int(p["known"]["PRIMARY"][0]) >= 76 and int(p["known"]["PRIMARY"][1]) < 5, "work shows the truth (%s)" % [p["known"]])


## The Cabinet (A48 names): the coalition's political appointees take the portfolios, shared by party; civil
## servants keep the civil roles and act where no minister sits; a new coalition reshuffles.
func _cabinet_world() -> WorldState:
	var w := F.bare_world()
	w.table("party")["party:1"] = {"id": "party:1", "name": "Equal Share", "status": "ACTIVE", "positions": {"ECON_ROLE": 80000, "REDISTRIBUTION": 80000, "SOVEREIGNTY": 0}}
	w.table("party")["party:2"] = {"id": "party:2", "name": "Free Market", "status": "ACTIVE", "positions": {"ECON_ROLE": -80000, "REDISTRIBUTION": -60000, "SOVEREIGNTY": 0}}
	for i in 6:
		F.add(w, "POLITICAL", {"ECON": 40 + i * 5, "NEGO": 70 - i * 5, "PUBS": 50}, 50, 100, "party:1")
	for i in 3:
		F.add(w, "POLITICAL", {"ENG": 60 + i * 5, "ENV": 55, "LAW": 50}, 50, 100, "party:2")
	for i in 6:
		F.add(w, "CIVIL", {"ADMIN": 60 + i, "POLI": 50, "COMM": 60, "ECON": 90})
	return w


func test_ministers_take_the_portfolios_shared_by_party() -> void:
	var w := _cabinet_world()
	OFS.fill_roles(w)
	var by_party := {}
	for c in OFS.cabinet(w):
		if c["role"] in OFS.PORTFOLIOS:
			check(c["minister"], "%s is held by a minister" % c["role"])
			by_party[c["party"]] = int(by_party.get(c["party"], 0)) + 1
		else:
			check(not c["minister"], "%s stays with the civil service" % c["role"])
	check(int(by_party.get("party:1", 0)) == 6 and int(by_party.get("party:2", 0)) == 3, "shared by party size (%s)" % [by_party])
	check(String(OFS.holder(w, "FINANCE").get("party_id", "")) != "", "a civil servant with ECON 90 does not outrank a minister for Finance")
	var lab := OFS.minister_label(w, "LABOUR_LIAISON")
	check(lab.begins_with("the Minister of Labour (") and lab.ends_with(")"), "named with the party: %s" % lab)
	check_eq(w.facts.query("STAFF_CABINET_FORMED").size(), 1, "the Cabinet is announced")
	var fin := OFS.holder(w, "FINANCE")
	if String(fin.get("party_id", "")) == "party:1":
		check(int(fin["lean"]["ECON_ROLE"]) > 20000, "an Equal Share minister leans their party's way")


func test_a_new_coalition_reshuffles_a_replacement_does_not() -> void:
	var w := _cabinet_world()
	OFS.fill_roles(w)
	var before := OFS.cabinet(w).map(func(c): return c["person"])
	OFS.fill_roles(w)
	check_eq(OFS.cabinet(w).map(func(c): return c["person"]), before, "a quiet month: nobody moves")
	check_eq(w.facts.query("STAFF_CABINET_FORMED").size(), 1, "no second announcement")
	for pid in Det.ordered(w.table("person")):     # party:2 leaves the coalition
		if String(w.table("person")[pid]["party_id"]) == "party:2":
			w.table("person")[pid]["pool"] = ""
	OFS.fill_roles(w)
	check_eq(w.facts.query("STAFF_CABINET_FORMED").size(), 2, "a new Cabinet")
	var acting := OFS.cabinet(w).filter(func(c): return c["role"] in OFS.PORTFOLIOS and not c["minister"])
	check_eq(acting.size(), 3, "civil servants act in the portfolios no minister holds")
