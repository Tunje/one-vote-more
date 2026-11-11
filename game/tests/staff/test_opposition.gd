extends TestCase
## Opposition actions (M7 groundwork): AI oversight and legal challenges from what each party can see.

const F := preload("res://tests/support/staff_fixture.gd")
const Opp := preload("res://sim/staff/opposition.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const A := preload("res://sim/staff/staff_law_actions.gd")
const Vis := preload("res://sim/law/visibility.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}


## P1 = player (opposition, not AI), P2 = AI government, P4 = AI opposition (31 seats -> 3 staff).
func _world(seed_value: int, p4_commitments: Array = []) -> Simulation:
	var s := F.sim(seed_value, false)
	var w := s.world
	F.set_pol(w, {"era": "FOUNDING", "player_party": "P1", "autoplay_player": false, "elections": []})
	for p in [["P1", 40], ["P2", 80], ["P4", 31]]:
		w.table("party")[p[0]] = {"id": p[0], "name": p[0], "seats": p[1], "status": "ACTIVE", "is_player": p[0] == "P1",
			"commitments": p4_commitments if p[0] == "P4" else []}
	s.step()
	var st := Ops.pol_state(w)
	st["era"] = "PARLIAMENTARY"
	st["government"] = {"members": ["P2"], "pm_party": "P2", "support": [], "agreement": [], "formed_month": w.month}
	s.run(2)
	return s


func _tasks(w: WorldState, pid: String, def_id: String) -> Array:
	return w.table("task").values().filter(func(t): return t["def_id"] == def_id and t["owner"].get("id", "") == pid)


func test_ai_challenges_revealed_unlawful_act() -> void:
	var s := _world(31)
	var w := s.world
	check_eq(Vis.role(w, "P4"), "OPPOSITION", "P4 in opposition")
	check(Ops.pool_members(w, {"kind": "PARTY", "id": "P4"}).size() == 3, "P4 has 3 party staff")
	var r := LawOps.proceed_unlawfully(w, GOV, "RESTRICT_ASSEMBLY", {"scope": "D1"})
	w.table("revealed_fact")[r["fact"]] = true
	w.table("unlawful_track")[r["fact"]]["revealed"] = true
	w.facts.reveal(w.month, r["fact"], [{"kind": "OFFICIAL", "id": "civil_service"}])
	var opts := Opp.options(w, "P4")
	check(opts["challenges"].any(func(c): return c["kind"] == "REVEALED_UNLAWFUL"), "revealed act is a challenge option")
	var ruling: Array = []
	for _m in 60:
		s.step()
		ruling = w.facts.query("LAW_RULING")
		if not ruling.is_empty():
			break
	check(not _tasks(w, "P4", "STAFF_T_LEGAL_CHALLENGE").is_empty(), "AI started a legal challenge")
	check(w.table("case").values().any(func(c): return c["claimant"].get("id", "") == "P4"), "P4 filed the case")
	check(not ruling.is_empty() and ruling[0]["data"]["against_government"], "ruling against the government")


func test_ai_rarely_challenges_without_evidence() -> void:
	# P4 opposes higher royalties; the government lawfully raises a REGULATION-level fee it opposes too? Use a delegated lever:
	var s := _world(32, [{"lever": "LAW_FEE_HAZARD", "dir": -1, "kind": "CORE", "weight": 1}])
	var w := s.world
	var res := A.apply(w, {"id": "LAW_DECREE", "actor": GOV, "args": {"lever": "LAW_FEE_HAZARD", "value": 9000}})
	check(res["ok"] and res["lawful"], "lawful decree (REGULATION-level lever)")
	s.run(3)
	var opts := Opp.options(w, "P4")
	var hunch: Array = opts["challenges"].filter(func(c): return c["kind"] == "POLITICAL_HUNCH")
	check_eq(hunch.size(), 1, "the party sees a weak, political case")
	check(hunch[0]["p_win_est"] < 0.5, "low win estimate")
	s.run(12)
	check(_tasks(w, "P4", "STAFF_T_LEGAL_CHALLENGE").is_empty(), "AI does not file a weak case")


func test_ultra_vires_decree_spotted_challenged_and_inquiry_report() -> void:
	var s := _world(33)
	var w := s.world
	A.apply(w, {"id": "LAW_DECREE", "actor": GOV, "args": {"lever": "LAW_EXTRACTION_ROYALTY", "value": 1500, "confirm_unlawful": true}})
	# an OFFICIAL government failure the opposition cannot see yet
	w.add_fact({"type": "LAW_PERMIT_DENIED", "owner": "law", "subjects": [], "visibility": "OFFICIAL", "magnitude": 5,
		"responsible": [{"actor": {"kind": "AUTHORITY", "id": "permit_office"}, "share": 1.0}], "impact": {}})
	s.step()
	var opts := Opp.options(w, "P4")
	var spotted: bool = opts["challenges"].any(func(c): return c["kind"] == "DECREE_ULTRA_VIRES") \
		or _tasks(w, "P4", "STAFF_T_LEGAL_CHALLENGE").any(func(t): return t["params"].get("kind", "") == "DECREE_ULTRA_VIRES")
	check(spotted, "visible from public law (offered, or already challenged by the AI)")
	check_eq(opts["oversight"][0]["domain"], "LAW", "LAW inquiry has the best expected yield")
	for _m in 12:
		s.step()
	check(not w.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED").is_empty(), "filing exposed the hidden unlawful decree")
	var reports := w.facts.query("STAFF_OVERSIGHT_REPORT")
	check(not reports.is_empty(), "inquiry published a report")
	if not reports.is_empty():
		check_eq(reports[0]["visibility"], "PUBLIC", "public")
		check_eq(reports[0]["responsible"][0]["actor"]["kind"], "GOVERNMENT", "government blamed")
		check(int(reports[0]["data"]["findings"]) >= 1, "found the OFFICIAL failure")


func test_player_options_pure_and_actions() -> void:
	var s := _world(34)
	var w := s.world
	var h := w.state_hash()
	var o := Opp.options(w, "P1")
	check_eq(w.state_hash(), h, "options() is pure")
	check_eq(o["role"], "OPPOSITION", "player in opposition")
	check_eq(o["oversight"].size(), 4, "four inquiry domains")
	var bad := A.apply(w, {"id": "OPP_START_OVERSIGHT", "actor": {"kind": "PARTY", "id": "P2"}, "args": {"domain": "LAW"}})
	check(not bad["ok"], "governing party cannot run an opposition inquiry")
	check(A.apply(w, {"id": "OPP_START_OVERSIGHT", "actor": {"kind": "PARTY", "id": "P1"}, "args": {"domain": "STAFF"}})["ok"], "player starts an inquiry")
