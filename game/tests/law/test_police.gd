extends TestCase
## P1c police (sim/law/police.gd): misconduct through the M11 chain on channel OVERSIGHT, the police reveal chain,
## the powers law, trust in the police, and political arrests (lawful referral vs the always-unlawful arrest).

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const JO := preload("res://sim/law/justice_ops.gd")
const P := preload("res://sim/law/police.gd")


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	LawOps.ensure_m11_rules(w)
	P.ensure_rules(w)
	JO.init_courts(w)
	w.month = 30
	w.meta["on"] = ["POLICE"]
	return w


func _record(w: WorldState, kind: String) -> String:
	return LawOps.record_greed(w, "org:police", {"kind": kind, "facility": "fac:st1", "district": "d:2"})


func test_misconduct_is_unlawful_and_found_by_the_complaints_authority() -> void:
	var w := _world()
	var fid := _record(w, "EXCESSIVE_FORCE")
	var v: Dictionary = w.table("violation_track")[fid]
	check(bool(v["unlawful"]), "excessive force is unlawful")
	check_eq(String(v["channel"]), "OVERSIGHT", "the complaints authority's case")
	var p0 := float(JO.detect_p(JO.detect_ctx(w), v)["inspect"])
	w.levers["LAW_POLICE_OVERSIGHT"] = 0
	var p_none := float(JO.detect_p(JO.detect_ctx(w), v)["inspect"])
	w.levers["LAW_POLICE_OVERSIGHT"] = 8000
	var p_big := float(JO.detect_p(JO.detect_ctx(w), v)["inspect"])
	check(p_none > 0.0, "victims still complain without an authority (%.3f)" % p_none)
	check(p_none < p0 and p0 < p_big, "a bigger authority finds more (%.3f < %.3f < %.3f)" % [p_none, p0, p_big])
	w.levers["LAW_POLICE_POWERS"] = 100
	check(bool(w.table("violation_track")[_record(w, "IMPROPER_SEARCH")]["unlawful"]), "strong powers do not make misconduct lawful")


func test_a_reveal_runs_the_police_chain_not_a_fine() -> void:
	var w := _world()
	var fid := _record(w, "UNLAWFUL_DETENTION")
	JO._reveal_violation(w, fid, JO.STATE, "INSPECTION")
	var rv := w.facts.query("LAW_POLICE_MISCONDUCT_REVEALED", 0, w.month)
	check_eq(rv.size(), 1, "misconduct revealed")
	if rv.is_empty():
		return
	var d: Dictionary = rv[0]["data"]
	check(String(d["kind"]) == "UNLAWFUL_DETENTION" and not bool(d["repeat"]), "kind, first finding")
	var gov := 0.0
	for r in rv[0]["responsible"]:
		if String(r["actor"]["kind"]) == "GOVERNMENT":
			gov = float(r["share"])
	check_eq(gov, 0.6, "the government carries most of the blame")
	var torts := 0
	for c in w.table("case").values():
		check(c["type"] != "ENFORCEMENT", "no enforcement case against the police")
		if c["type"] == "TORT" and bool(c["data"].get("police", false)):
			torts += 1
			check_eq(String(c["respondent"]["kind"]), "GOVERNMENT", "the treasury pays the victims")
	check_eq(torts, 1, "the victims sue")
	check(int(P.state(w)["shock"].get("d:2", 0)) > 0, "trust shock in the district")
	w.month += 12
	JO._reveal_violation(w, _record(w, "UNLAWFUL_DETENTION"), JO.STATE, "INSPECTION")
	check_eq(w.facts.query("LAW_POLICE_INQUIRY_OPENED", 0, w.month).size(), 1, "a repeat opens an inquiry")


func test_powers_raise_clearance_and_misconduct() -> void:
	var w := _world()
	check(P.powers_clearance(w) == 1.0 and P.powers_misconduct(w) == 1.0, "neutral at the default 40")
	w.levers["LAW_POLICE_POWERS"] = 100
	check(is_equal_approx(P.powers_clearance(w), 1.4) and is_equal_approx(P.powers_misconduct(w), 3.0), "+40% clearance, 3x misconduct")
	w.levers["LAW_POLICE_POWERS"] = 0
	check(P.powers_clearance(w) < 1.0 and P.powers_misconduct(w) < 1.0, "weak powers: fewer solved, fewer abuses")


func test_strong_powers_split_trust_by_institutions_view() -> void:
	var w := _world()
	w.table("cell")["lib"] = {"key": "lib", "district": "d:2", "pop": 100, "ideology": {"INSTITUTIONS": 60000}}
	w.table("cell")["ord"] = {"key": "ord", "district": "d:2", "pop": 100, "ideology": {"INSTITUTIONS": -60000}}
	w.levers["LAW_POLICE_POWERS"] = 100
	var st := P.state(w)
	for i in 60:
		P._trust(w, st)
	var lib := int(w.table("cell")["lib"]["trust_police"])
	var ord := int(w.table("cell")["ord"]["trust_police"])
	check(lib < P.TRUST_START and ord > P.TRUST_START, "liberty-minded lose trust, order-minded gain it (%d / %d)" % [lib, ord])
	check_eq(P.trust_pm(w, "d:2"), int(round((lib + ord) / 2.0)), "district trust is population-weighted")


func test_political_arrest_paths() -> void:
	var w := _world()
	w.table("party")["party:2"] = {"id": "party:2", "name": "Opposition", "status": "ACTIVE", "support": 30000,
		"leader": {"name": "Ada Opp"}}
	var gov := {"kind": "GOVERNMENT", "id": "government"}
	var r := P.order_investigation(w, gov, {"kind": "PARTY", "id": "party:2"}, "rumours")
	check_eq(String(r["path"]), "DECLINED", "no evidence: the prosecutor declines")
	w.table("donation_track")["f:don"] = {"party": "party:2", "revealed": false}
	r = P.order_investigation(w, gov, {"kind": "PARTY", "id": "party:2"}, "donations")
	check_eq(String(r["path"]), "REFERRAL", "hidden violations: a lawful investigation")
	r = P.order_investigation(w, gov, {"kind": "PARTY", "id": "party:2"}, "", true)
	check(bool(r["ok"]) and String(r["path"]) == "ARREST", "the unlawful order is carried out")
	var order := w.facts.get_fact(String(r["order"]))
	check(String(order["type"]) == "LAW_UNLAWFUL_GOV_ACTION" and String(order["visibility"]) == "SECRET", "a secret unlawful act")
	check_eq(String(order["data"]["action"]), "POLITICAL_ARREST", "the action")
	check(bool(w.table("unlawful_track")[String(r["order"])]["burdened"]), "the target party can complain")
	var arrest := w.facts.get_fact(String(r["fact"]))
	check(String(arrest["visibility"]) == "PUBLIC" and String(arrest["data"]["name"]) == "Ada Opp", "the detention itself is public")
	check(not arrest["data"].has("order"), "the public fact does not leak the secret order")
	check_eq(P.arrests(w).size(), 1, "counted for the drift")
	check(P.detained(w).has(String(r["fact"])), "detained")
	w.month += 7
	P._releases(w, P.state(w))
	check(P.detained(w).is_empty() and w.facts.query("LAW_DETAINEE_RELEASED", 0, w.month).size() == 1, "released")
	var pid := w.new_id("person")
	w.table("person")[pid] = {"id": pid, "name": "Bo Staff", "party_id": "party:2", "status": "ACTIVE", "unavailable_until": -1}
	r = P.order_investigation(w, gov, {"kind": "PERSON", "id": pid}, "", true)
	check(String(w.table("person")[pid]["status"]) == "UNAVAILABLE", "a detained staff person cannot work")


func _ai_world(inst: int, cornered: bool) -> WorldState:
	var w := _world()
	w.table("party")["party:1"] = {"id": "party:1", "status": "ACTIVE", "support": 20000, "positions": {"INSTITUTIONS": inst},
		"leader": {"name": "Gov Boss"}}
	w.table("party")["party:2"] = {"id": "party:2", "status": "ACTIVE", "support": 35000, "positions": {}, "leader": {"name": "Ada Opp"}}
	w.table("pol")["state"] = {"government": {"pm_party": "party:1", "members": ["party:1"]}, "player_party": "party:9"}
	if cornered:
		LawOps.state(w)["emergency"] = {"active": true}
	return w


func test_ai_arrests_only_when_order_minded_cornered_and_trailing() -> void:
	var calm := _ai_world(-60000, false)
	var liberal := _ai_world(-20000, true)
	var cornered := _ai_world(-60000, true)
	for i in 600:
		P.ai_monthly(calm)
		P.ai_monthly(liberal)
		P.ai_monthly(cornered)
	check_eq(P.arrests(calm).size(), 0, "no crisis: never")
	check_eq(P.arrests(liberal).size(), 0, "not order-minded enough: never")
	var n := P.arrests(cornered).size()
	check(n >= 1 and n <= 15, "cornered: rare (%d in 600 months)" % n)
	if n > 0:
		check_eq(String(P.arrests(cornered)[0]["party"]), "party:2", "the leading opposition party")
	cornered.table("party")["party:1"]["support"] = 50000
	var before := P.arrests(cornered).size()
	for i in 600:
		P.ai_monthly(cornered)
	check_eq(P.arrests(cornered).size(), before, "leading in the polls: never")
