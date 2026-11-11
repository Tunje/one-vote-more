extends TestCase
## M6 core (spec-law §11): courts, verdict model, the M6 exit path, inspectorate + fines through the ledger,
## administrative appeals, backlog (LT8), save/load mid-case.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}


func _parl(w: WorldState) -> void:
	F.set_pol(w, {"era": "PARLIAMENTARY", "government": {"members": ["P1"], "pm_party": "P1", "agreement": [], "formed_month": 0}})
	w.table("party")["P1"] = {"id": "P1", "seats": 80, "status": "ACTIVE", "commitments": []}
	w.table("party")["P2"] = {"id": "P2", "seats": 40, "status": "ACTIVE", "commitments": []}


func _accounts(w: WorldState, org: String, cash_wref: int) -> void:
	for a in ["gov:treasury", "gov:fines_revenue", "co:" + org]:
		if not w.ledger.has_account(a):
			w.ledger.open_account(a)
	w.ledger.transfer(Ledger.EXTERNAL, "co:" + org, cash_wref * 1200000, "seed", w.month)
	w.ledger.transfer(Ledger.EXTERNAL, "gov:treasury", 1000 * 1200000, "seed", w.month)
	w.table("org")[org] = {"id": org, "pl_last": {"rev": 100 * 1200000}}


func test_courts_and_capacity() -> void:
	var w := F.bare_world()
	LawOps.init_world(w)
	J.init_courts(w)
	var gen := J.court_of(w, "GENERAL")
	var adm := J.court_of(w, "ADMIN")
	check_eq(gen["judges"].size(), 3, "general court 3 judges")
	check_eq(adm["judges"].size(), 2, "administrative chamber 2 judges")
	var c := J.capacity(w, gen)
	check(c >= 3.0 * 6.4 - 0.01 and c <= 3.0 * 7.4 + 0.01, "3 judges x (4 + 4 LAW/100) = %f" % c)
	w.levers["LAW_COURT_BUDGET"] = 7500
	check(absf(J.capacity(w, gen) - c / 2.0) < 0.01, "half budget halves capacity")
	w.levers["LAW_JUDGES"] = 10
	J.retire_judges(w)
	check_eq(J.court_of(w, "GENERAL")["judges"].size() + J.court_of(w, "ADMIN")["judges"].size(), 10, "lever adds judges")


## Evidence != truth: true claims mostly win, false claims mostly lose (seeded statistics).
func test_verdict_model() -> void:
	var w := F.bare_world(9)
	LawOps.init_world(w)
	J.init_courts(w)
	var wins := {true: 0, false: 0}
	for i in 400:
		var truth := i % 2 == 0
		var id := J.file_case(w, "ADMIN_APPEAL", {"kind": "COMPANY", "id": "co"}, {"kind": "AUTHORITY", "id": "permit_office"}, truth, {})
		if w.rng.stream("t").randf() < J.p_win(w, w.table("case")[id]):
			wins[truth] += 1
	check(wins[true] > 140, "true claims win >70%% (%d/200)" % wins[true])
	check(wins[false] < 50, "false claims win <25%% (%d/200)" % wins[false])


## M6 EXIT: an unlawful government action is revealed, challenged, overturned, and the PUBLIC ruling blames GOVERNMENT.
func test_m6_exit_unlawful_action_overturned() -> void:
	var s := F.sim(12, true)
	var w := s.world
	_parl(w)
	w.table("census")["D1|INDUSTRY|MID"] = 500
	s.step()
	var r := LawOps.proceed_unlawfully(w, GOV, "SET_LEVER",
		{"lever_id": "LAW_EXTRACTION_ROYALTY", "instrument_level": "ADMIN", "founding_era": "COMMANDER", "lever_level": "LAW",
		"lawful_value": 800}, "", {"kind": "PARTY", "id": "P2"}, "SERIOUS")
	# A government decision setting a LAW-level lever without delegation breaks the legislative monopoly -> PROHIBITED.
	check(r["ok"], "recorded as unlawful: %s" % r)
	w.levers["LAW_EXTRACTION_ROYALTY"] = 2000   # the unlawful effect the caller executed
	var ruling: Dictionary = {}
	for _m in 120:
		s.step()
		var rs := w.facts.query("LAW_RULING")
		if not rs.is_empty():
			ruling = rs[0]
			break
	check(not ruling.is_empty(), "a ruling within 10 years")
	if ruling.is_empty():
		return
	check_eq(ruling["visibility"], "PUBLIC", "public ruling")
	check(ruling["data"]["against_government"], "against the government")
	check_eq(ruling["responsible"][0]["actor"]["kind"], "GOVERNMENT", "GOVERNMENT blamed")
	check(int(ruling["impact"].get("GOVERNANCE", 0)) < 0, "GOVERNANCE impact")
	check_eq(w.levers["LAW_EXTRACTION_ROYALTY"], 800, "unlawful lever change overturned")
	s.step()
	check(w.indicators.read("LAW_RULE_OF_LAW") < 100000, "rule of law below clean")
	check(w.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED").size() == 1, "revealed first")


## Inspectorate finds a SERIOUS violation -> enforcement case -> fine through the ledger (shortfall -> FINE liability).
func test_inspection_fine_ledger_and_liability() -> void:
	var s := F.sim(13, true)
	var w := s.world
	_parl(w)
	_accounts(w, "acme", 2)    # 2 W_ref cash; SERIOUS fine = max(4% of 1200 W_ref, 10 W_ref) = 48 W_ref
	w.levers["LAW_INSPECTORS"] = 60
	w.levers["LAW_INSPECTORATE_BUDGET"] = 200000
	LawOps.record_violation(w, {"kind": "COMPANY", "id": "acme"}, "EXTRACT_RESOURCE", {})
	var fine: Array = []
	for _m in 60:
		s.step()
		fine = w.facts.query("LAW_FINE_IMPOSED")
		if not fine.is_empty():
			break
	check_eq(fine.size(), 1, "fined")
	if fine.is_empty():
		return
	var amount: int = fine[0]["data"]["amount"]
	check_eq(amount, int(round(0.04 * 1200.0 * 1200000.0)), "4% of annual revenue")
	check_eq(w.ledger.balance("gov:fines_revenue"), 2 * 1200000, "cash on hand paid to fines account")
	var liab := w.table("liability").values().filter(func(l): return l["kind"] == "FINE" and l["status"] == "OPEN")
	check_eq(liab.size(), 1, "shortfall became a FINE liability")
	check_eq(liab[0]["amount"], amount - 2 * 1200000, "liability = remainder")
	check_eq(w.ledger.total(), 0, "money conserved")
	check(w.indicators.read("LAW_ENFORCEMENT_CONSISTENCY", "COLONY", -1) >= 0, "consistency published")


## A wrongly denied permit is usually appealed and the administrative chamber grants it.
func test_admin_appeal_grants_permit() -> void:
	var s := F.sim(14, true)
	var w := s.world
	_parl(w)
	var granted := 0
	for i in 20:
		var id := LawOps.apply_licence(w, "co:%d" % i, "licence", "HAZARD", "D1", true, 60)
		w.table("permit_application")[id]["status"] = "DENIED"
		w.table("permit_application")[id]["wrong"] = true
		w.table("permit_application")[id]["decided_month"] = w.month
	s.step()
	check(w.table("case").size() >= 10, "most wrongly denied firms appeal (%d)" % w.table("case").size())
	s.run(36)
	for a in w.table("permit_application").values():
		if a["status"] == "GRANTED":
			granted += 1
	check(granted >= 8, "appeals granted permits (%d)" % granted)


## LT8: backlog 3x capacity -> duration rises, no case lost; save/load mid-case identical.
func test_lt8_backlog_and_save_load() -> void:
	var s := F.sim(15, true)
	var w := s.world
	_parl(w)
	s.step()
	for i in 60:   # administrative appeals cannot settle: 60 x 3 cp against ~13 cp/month in the chamber
		J.file_case(w, "ADMIN_APPEAL", {"kind": "COMPANY", "id": "c%d" % i}, {"kind": "AUTHORITY", "id": "permit_office"},
			i % 3 != 0, {"application": ""})
	s.run(3)
	check_eq(SaveIO.save(s, F.save_path("justice.sav")), OK, "save mid-case")
	s.run(30)
	var open := w.table("case").values().filter(func(c): return c["status"] == "OPEN").size()
	var done := w.table("case").values().filter(func(c): return c["status"] in ["DECIDED", "SETTLED", "APPEALED"]).size()
	check_eq(open + done, w.table("case").size(), "no case lost")
	check(w.indicators.read("LAW_COURT_DURATION", "COLONY", -1) > 3000, "backlog lengthens duration")
	var b := Simulation.new(0, [F.LawProvider.new(), F.StaffProvider.new()])
	check_eq(SaveIO.load_into(b, F.save_path("justice.sav")), OK, "load")
	b.run(30)
	check_eq(b.world.state_hash(), w.state_hash(), "identical after load")
