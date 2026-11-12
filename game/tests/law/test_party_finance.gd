extends TestCase
## M9 party finance law and donation scandals (planning/spec-politics-v2.md §6).

const F := preload("res://tests/support/staff_fixture.gd")
const LQ := preload("res://sim/law/law_query.gd")
const PF := preload("res://sim/law/party_finance.gd")
const J := preload("res://sim/law/justice_ops.gd")
const Staff := preload("res://sim/staff/staff_ops.gd")
const PartyGen := preload("res://sim/politics/party_gen.gd")


func _world() -> Simulation:
	var s := F.sim(43, true)
	var w := s.world
	for p in [["P1", 60, 0], ["P2", 50, 90], ["P3", 41, 50]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "commitments": [], "is_player": p[0] == "P1",
			"leader": {"name": "Leader " + p[0], "charisma": 50, "competence": 50, "integrity": p[2], "faction": "", "since": 0, "popularity": 50}}
	w.table("election")["election:1"] = {"id": "election:1", "month": 0, "seats": {}, "votes": {}, "total": 0}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": true, "elections": ["election:1"],
		"next_election": 48, "caretaker": false,
		"government": {"members": ["P1", "P2"], "pm_party": "P1", "support": [], "agreement": [], "formed_month": 0}})
	s.step()
	return s


func _donate(w: WorldState, donor: String, party: String, amount: int, vis: String) -> String:
	var pref := {"kind": "PARTY", "id": party}
	return w.add_fact({"type": "POL_DONATION", "owner": "politics", "subjects": [pref], "responsible": [{"actor": pref, "share": 1.0}],
		"impact": {}, "magnitude": 10, "visibility": vis, "data": {"donor": donor, "party": party, "amount": amount}})


func _wref(w: WorldState) -> int:
	return Staff.w_ref_milli(w)


func test_levers_registered_with_slopes() -> void:
	var s := _world()
	var w := s.world
	for lid in ["LAW_DONATION_CAP", "LAW_DONATION_DISCLOSURE", "LAW_PUBLIC_PARTY_FUNDING", "LAW_CONVICTED_CAN_HOLD_OFFICE"]:
		check(w.lever_defs.has(lid), lid + " registered")
		check(not w.lever_defs[lid]["ideology"].is_empty(), lid + " has an ideology slope")
	check_eq(w.levers["LAW_DONATION_DISCLOSURE"], "ABOVE_THRESHOLD", "default disclosure")
	check_eq(w.levers["LAW_CONVICTED_CAN_HOLD_OFFICE"], true, "default: no ban")
	# A clean-institutions, redistributive party wants a lower cap, more disclosure and a ban on convicted leaders.
	var pos := {"ECON_ROLE": 30000, "REDISTRIBUTION": 60000, "LABOR": 0, "ENVIRONMENT": 0, "AUTONOMY": 0, "FISCAL": 20000, "INSTITUTIONS": 70000, "SOVEREIGNTY": 0}
	var want := {}
	for c in PartyGen.commitments(pos, w.lever_defs):
		want[c["lever"]] = c["dir"]
	check_eq(want.get("LAW_DONATION_CAP", 0), -1, "lower the cap")
	check_eq(want.get("LAW_DONATION_DISCLOSURE", 0), 1, "more disclosure")
	check_eq(want.get("LAW_CONVICTED_CAN_HOLD_OFFICE", 0), -1, "ban convicted office holders")
	check_eq(want.get("LAW_PUBLIC_PARTY_FUNDING", 0), 1, "public funding")


func test_donation_allowed() -> void:
	var s := _world()
	var w := s.world
	var cap := 50 * _wref(w)
	var r := LQ.donation_allowed(w, cap / 2, "org:1")
	check(r["ok"] and r["cap"] == cap and r["given"] == 0, "first gift under the cap: %s" % [r])
	check(r["disclose"], "above the 2 W_ref threshold: must be disclosed")
	check(not LQ.donation_allowed(w, _wref(w), "org:1")["disclose"], "1 W_ref is below the threshold")
	_donate(w, "org:1", "P1", cap / 2, "PUBLIC")
	_donate(w, "org:1", "P2", cap / 4, "PUBLIC")
	r = LQ.donation_allowed(w, cap / 2, {"kind": "COMPANY", "id": "org:1"})
	check(not r["ok"] and r["given"] == cap * 3 / 4 and r["remaining"] == cap / 4, "cap counts gifts to all parties: %s" % [r])
	check(LQ.donation_allowed(w, cap / 2, "org:2")["ok"], "per donor")
	w.levers["LAW_DONATION_DISCLOSURE"] = "NONE"
	check(not LQ.donation_allowed(w, cap, "org:2")["disclose"], "NONE: nothing must be disclosed")
	w.levers["LAW_DONATION_DISCLOSURE"] = "ALL"
	check(LQ.donation_allowed(w, 1, "org:2")["disclose"], "ALL: everything")
	w.levers["LAW_DONATION_CAP"] = 500000
	check(LQ.donation_allowed(w, cap * 100, "org:1")["ok"] and LQ.donation_allowed(w, 1, "org:1")["cap"] == -1, "range max = no cap")
	s.run(13)
	w.levers["LAW_DONATION_CAP"] = 50000
	check_eq(LQ.donation_allowed(w, cap, "org:1")["given"], 0, "rolling 12 months")


## A hidden over-cap gift is tracked; an investigation of the leader finds it; the scandal and a prosecution follow.
func test_investigation_reveals_scandal() -> void:
	var s := _world()
	var w := s.world
	var cap := 50 * _wref(w)
	var fids: Array = []
	for i in 6:
		fids.append(_donate(w, "org:%d" % i, "P2", cap * 2, "SECRET"))
	_donate(w, "org:9", "P3", _wref(w), "SECRET")            # small, under the threshold: lawful secrecy
	s.step()
	var track := w.table("donation_track")
	check_eq(track.size(), 6, "six violations tracked, the lawful one not")
	check_eq(int(track[fids[0]]["excess"]), cap, "excess over the cap")
	var iid := PF.open_investigation(w, {"kind": "LEADER", "id": "P2"})
	check(iid != "" and w.table("investigation")[iid]["party"] == "P2", "a LEADER target resolves to the party")
	check_eq(PF.open_investigation(w, {"kind": "PARTY", "id": "P2"}), iid, "one open investigation per party")
	s.run(PF.INVESTIGATION_MONTHS + 1)
	var sc := w.facts.query("POL_SCANDAL_REVEALED").filter(func(f): return f["data"]["party"] == "P2")
	check(not sc.is_empty(), "scandal revealed")
	var d: Dictionary = sc[0]["data"]
	check(d["leader"] == "Leader P2" and int(d["severity"]) >= 60 and int(d["severity"]) <= 100, "data {party, leader, severity}: %s" % [d])
	check(not w.facts.query("POL_DONATION_REVEALED").is_empty(), "the SECRET donation became public")
	check(w.table("investigation")[iid]["outcome"] == "FINDINGS", "investigation closed with findings")
	var cases: Array = w.table("case").values().filter(func(c): return c["type"] == "PARTY_FINANCE")
	check(not cases.is_empty() and cases[0]["respondent"]["id"] == "P2", "prosecution filed")
	check(LQ.party_finance(w)["investigations"].size() == 1, "UI read")


func test_conviction_and_office_ban() -> void:
	var s := _world()
	var w := s.world
	w.ledger.open_account("party:P3")
	if not w.ledger.has_account("gov:fines_revenue"):
		w.ledger.open_account("gov:fines_revenue")
	w.ledger.transfer(Ledger.EXTERNAL, "party:P3", 1000 * _wref(w), "seed", w.month)
	var fid := _donate(w, "org:1", "P3", 100 * _wref(w), "SECRET")
	s.step()
	w.table("party")["P3"]["leader"]["integrity"] = 0          # certainly knew: charged
	w.levers["LAW_CONVICTED_CAN_HOLD_OFFICE"] = false
	PF._scandal(w, fid, {"kind": "PRESS", "id": "press"}, "LEAK")
	var c: Dictionary = w.table("case").values().filter(func(x): return x["type"] == "PARTY_FINANCE")[0]
	check(c["data"]["leader_charged"], "integrity 0: the leader is charged")
	var before := w.ledger.balance("party:P3")
	J._final(w, c, true)
	var conv := w.facts.query("LAW_LEADER_CONVICTED")
	check_eq(conv.size(), 1, "leader convicted")
	check(conv[0]["data"]["must_step_down"] and conv[0]["data"]["leader"] == "Leader P3", "ban in force: must step down")
	check_eq(before - w.ledger.balance("party:P3"), 2 * 50 * _wref(w), "fine = 2 x excess (50 W_ref over the cap)")
	check(not LQ.may_hold_office(w, "Leader P3"), "convicted leader barred")
	check(LQ.may_hold_office(w, "Leader P1"), "others unaffected")
	w.levers["LAW_CONVICTED_CAN_HOLD_OFFICE"] = true
	check(LQ.may_hold_office(w, "Leader P3"), "no ban: may stay")


func test_public_party_funding() -> void:
	var s := _world()
	var w := s.world
	if not w.ledger.has_account("gov:treasury"):
		w.ledger.open_account("gov:treasury", true)
	w.ledger.open_account("party:P1")
	w.levers["LAW_PUBLIC_PARTY_FUNDING"] = 500
	var before := w.ledger.balance("party:P1")
	s.step()
	check_eq(w.ledger.balance("party:P1") - before, 60 * _wref(w) / 2, "0.5 W_ref x 60 seats")


## Legacy saves / politics still writing a string leader.
func test_string_leader_tolerated() -> void:
	var s := _world()
	var w := s.world
	w.table("party")["P1"]["leader"] = "Old Name"
	check_eq(PF.leader_name(w, "P1"), "Old Name", "string leader")
	check_eq(PF._leader_integrity(w, "P1"), 50, "default integrity")


## Gifts are judged by the cap stamped at booking (data.cap / data.lawful), not by a cap that drifted with W_ref.
func test_judged_at_booking_time() -> void:
	var s := _world()
	var w := s.world
	var cap := 50 * _wref(w)
	var pref := {"kind": "PARTY", "id": "P1"}
	var mk := func(donor: String, amount: int, vis: String, data_extra: Dictionary) -> String:
		var d := {"donor": donor, "party": "P1", "amount": amount}
		d.merge(data_extra)
		return w.add_fact({"type": "POL_DONATION", "owner": "politics", "subjects": [pref],
			"responsible": [{"actor": pref, "share": 1.0}], "impact": {}, "magnitude": 10, "visibility": vis, "data": d})
	var ok_pub: String = mk.call("org:1", cap - 1, "PUBLIC", {"cap": cap, "lawful": true})
	var ok_cap: String = mk.call("org:2", cap - 1, "PUBLIC", {"cap": cap})                 # no lawful flag: cap only
	var bad: String = mk.call("org:3", cap * 2, "SECRET", {"cap": cap, "lawful": false})
	var hid: String = mk.call("org:4", cap / 10, "SECRET", {"cap": cap, "lawful": false})  # within cap, should have been public
	w.levers["LAW_DONATION_CAP"] = 25000                                                   # cap halves before the scan
	s.step()
	var track := w.table("donation_track")
	check(not track.has(ok_pub) and not track.has(ok_cap), "lawful at booking stays lawful")
	check(track.has(bad) and int(track[bad]["excess"]) == cap, "excess against the booking cap")
	check(track.has(hid) and track[hid]["undisclosed"] and int(track[hid]["excess"]) == 0, "secrecy breach")
	check(w.facts.query("POL_SCANDAL_REVEALED").filter(func(f): return f["data"]["channel"] == "PUBLIC_RECORD").is_empty(),
		"no PUBLIC_RECORD scandal from drift")


## Election year (Ella): a rival's opposition research exposes a hidden violation.
func test_reveal_by_rival() -> void:
	var s := _world()
	var w := s.world
	var fid := _donate(w, "org:1", "P2", 100 * _wref(w), "SECRET")
	s.step()
	check(w.table("donation_track").has(fid), "tracked")
	check(PF.reveal_by_rival(w, fid, "P1"), "fired")
	check(not PF.reveal_by_rival(w, fid, "P3"), "only once")
	check(not PF.reveal_by_rival(w, "F999999", "P1"), "unknown entry")
	var sc := w.facts.query("POL_SCANDAL_REVEALED")
	check(sc.size() == 1 and sc[0]["data"]["channel"] == "OPPO_RESEARCH" and sc[0]["data"]["party"] == "P2", "channel OPPO_RESEARCH")


## Election year (Ella): an exposed smear is defamation; the smearer pays damages.
func test_defamation() -> void:
	var s := _world()
	var w := s.world
	for p in ["P1", "P2"]:
		w.ledger.open_account("party:" + p)
	w.ledger.transfer(Ledger.EXTERNAL, "party:P2", 100 * _wref(w), "seed", w.month)
	var cid := J.file_defamation(w, "P1", "P2", 50)
	check(w.table("case").has(cid) and w.table("case")[cid]["type"] == "DEFAMATION", "case filed")
	var before := w.ledger.balance("party:P1")
	J._final(w, w.table("case")[cid], true)
	var f := w.facts.query("LAW_DEFAMATION_RULED")
	check(f.size() == 1 and f[0]["data"]["guilty"] and f[0]["data"]["smearer"] == "P2", "verdict fact: %s" % [f])
	check_eq(w.ledger.balance("party:P1") - before, int(round(50 * 0.3 * _wref(w))), "damages smearer -> victim")
	check_eq(f[0]["responsible"][0]["actor"]["id"], "P2", "the smearer is responsible")
	var cid2 := J.file_defamation(w, "P1", "P2", 20)
	J._final(w, w.table("case")[cid2], false)
	check(not w.facts.query("LAW_DEFAMATION_RULED")[1]["data"]["guilty"], "an acquittal is ruled too")


## A party that can't pay hands over what its account holds; the verdict fact records award and payment.
func test_defamation_partial_payment() -> void:
	var s := _world()
	var w := s.world
	for p in ["P1", "P2"]:
		w.ledger.open_account("party:" + p)
	w.ledger.transfer(Ledger.EXTERNAL, "party:P2", 4 * _wref(w), "seed", w.month)
	var cid := J.file_defamation(w, "P1", "P2", 50)
	J._final(w, w.table("case")[cid], true)
	var d: Dictionary = w.facts.query("LAW_DEFAMATION_RULED")[0]["data"]
	check_eq(int(d["damages"]), int(round(50 * 0.3 * _wref(w))), "the full award")
	check_eq(int(d["paid"]), 4 * _wref(w), "paid what the account held")
	check_eq(w.ledger.balance("party:P2"), 0, "the smearer is cleaned out, not negative")
	check_eq(w.ledger.balance("party:P1"), 4 * _wref(w), "the victim received it")
