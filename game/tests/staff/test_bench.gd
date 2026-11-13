extends TestCase
## A51 B1–B2 (planning/spec-bench-v1.md): party recruitment drives with sourced prospects, interviews at the door,
## ambitions and grievances from the record, challengers, defection under the mandate law, leaks, the secretary's mail.

const F := preload("res://tests/support/staff_fixture.gd")
const Ops := preload("res://sim/staff/staff_ops.gd")
const OFS := preload("res://sim/staff/office_staff.gd")
const B := preload("res://sim/staff/bench.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

const WREF := 1200000
const LEFT := {"ECON_ROLE": 70000, "REDISTRIBUTION": 70000, "SOVEREIGNTY": 0}
const RIGHT := {"ECON_ROLE": -70000, "REDISTRIBUTION": -70000, "SOVEREIGNTY": 0}


func _world() -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	w.values["ECON_W_REF"] = WREF
	_party(w, "party:1", "Equal Share", LEFT, 30)
	_party(w, "party:2", "Free Market", RIGHT, 20)
	F.set_pol(w, {"player_party": "party:9"})       # neither is the player's: both AI
	return w


func _party(w: WorldState, id: String, name: String, pos: Dictionary, seats: int) -> void:
	w.table("party")[id] = {"id": id, "name": name, "status": "ACTIVE", "positions": pos.duplicate(), "seats": seats,
		"leader": {"name": "L", "faction": 0}}
	w.ledger.open_account("party:" + id)
	w.ledger.transfer(Ledger.EXTERNAL, "party:" + id, 20 * WREF, "seed", w.month)


## A bench member of `party` (pool "") with the given skills, lean and B2 state.
func _member(w: WorldState, party: String, skills: Dictionary, lean: Dictionary, amb: String = "OFFICE", loyalty: int = 70, grievance: int = 0) -> String:
	var pid := F.add(w, "POLITICAL", skills, 50, 100, party)
	var p := Ops.person(w, pid)
	p["pool"] = ""
	p["bench_party_id"] = party
	OFS.traits(p)
	var l := {"ECON_ROLE": 0, "REDISTRIBUTION": 0, "SOVEREIGNTY": 0}
	l.merge(lean, true)
	p["lean"] = l
	p["lean_party"] = party
	p["ambition"] = amb
	p["cause"] = ""
	p["loyalty"] = loyalty
	p["grievance"] = grievance
	p["grievances"] = []
	return pid


func test_a_drive_costs_money_and_brings_sourced_prospects() -> void:
	var w := _world()
	var before := w.ledger.balance("party:party:1")
	var d := B.start_drive(w, "party:1")
	check(d["ok"], "a drive opens (%s)" % d["reason"])
	check_eq(before - w.ledger.balance("party:party:1"), int(d["cost"]), "paid from the party account")
	check_eq(int(d["minutes"]), B.DRIVE_MINUTES, "the secretary's time")
	var list: Array = w.table("recruitment")[d["rid"]]["shortlist"]
	check_eq(list.size(), B.SHORTLIST, "a shortlist")
	for p in list:
		check(p["source"] in B.SOURCES and p["source"] != "UNION" and p["source"] != "COMPANY", "no unions or companies in this colony: %s" % p["source"])
		check(int(p["lean"]["REDISTRIBUTION"]) > 0, "drawn to a left party: they lean left (%s)" % [p["lean"]])
		check(p.has("ambition") and p.has("ties"), "an ambition and ties")
	var n0 := B.bench_of(w, "party:1").size()
	check(B.pick(w, d["rid"], 0)["ok"], "picked")
	check_eq(B.bench_of(w, "party:1").size(), n0 + 1, "on the bench")
	check(not B.pick(w, d["rid"], 1)["ok"], "one pick per drive")
	check_eq(w.facts.query("STAFF_BENCH_RECRUITED").size(), 1, "announced")
	for i in B.soft_cap(w, "party:1") + 2:
		_member(w, "party:1", {"POLI": 50}, {})
	check(B.drive_cost(w, "party:1") > int(d["cost"]), "over the soft cap a drive costs more")


func test_prospects_are_interviewed_at_the_door() -> void:
	var w := _world()
	var d := B.start_drive(w, "party:1")
	var iid := OFS.start_interview(w, d["rid"], 2)
	check(iid != "", "the O5 interview engine takes a party drive")
	check(OFS.ask(w, iid, "POLITICAL")["ok"], "ask about their politics")
	check(OFS.hire_from_interview(w, iid)["ok"], "taken on")
	var pid := String(w.table("recruitment")[d["rid"]]["person_id"])
	check_eq(String(Ops.person(w, pid)["bench_party_id"]), "party:1", "onto the party's bench, not the civil service")
	check_eq(String(Ops.person(w, pid)["pool"]), "", "no government post")
	Ops.process_recruitment(w)
	check_eq(String(w.table("recruitment")[d["rid"]]["status"]), "FILLED", "civil hiring leaves party drives alone")


func test_passed_over_and_promoted() -> void:
	var w := _world()
	var minister := _member(w, "party:1", {"ECON": 50}, LEFT)
	var keen := _member(w, "party:1", {"ECON": 90}, LEFT, "OFFICE")
	var calm := _member(w, "party:1", {"ECON": 95}, LEFT, "QUIET")
	var m := Ops.person(w, minister)
	m["pool"] = "GOV"
	w.table("office_role")["FINANCE"] = {"role": "FINANCE", "person": minister, "since": w.month, "by": "CABINET", "party": "party:1"}
	B.monthly(w)
	check_eq(int(Ops.person(w, keen)["grievances"].size()), 1, "the abler, ambitious member is passed over")
	check_eq(String(Ops.person(w, keen)["grievances"][0]["kind"]), "PASSED_OVER", "with the cause on record")
	check(Ops.person(w, calm)["grievances"].is_empty(), "someone who wants a quiet life does not mind")
	w.table("office_role")["FINANCE"]["person"] = keen
	Ops.person(w, keen)["pool"] = "GOV"
	m["pool"] = ""
	B.monthly(w)
	check(Ops.person(w, minister)["grievances"].any(func(e): return e["kind"] == "SACKED"), "the old minister is sacked")


func test_restless_members_become_challengers() -> void:
	var w := _world()
	var pid := _member(w, "party:1", {"POLI": 75, "COMM": 70}, LEFT, "LEADERSHIP", 20, 80)
	_member(w, "party:1", {"POLI": 75}, LEFT, "LEADERSHIP", 90, 0)
	B.monthly(w)
	var ch := B.challengers(w, "party:1")
	check_eq(ch.size(), 1, "one restless member")
	check_eq(String(ch[0]["person"]), pid, "the disloyal, aggrieved, able one")
	check_eq(w.facts.query("STAFF_BENCH_RESTLESS").size(), 1, "flagged once for Ella")
	var ld := B.as_leader(w, pid)
	check(String(ld["person"]) == pid and int(ld["charisma"]) > 50, "a leader dict linked to the person")
	B.contest_result(w, "party:1", pid, false)
	check(Ops.person(w, pid)["grievances"].any(func(e): return e["kind"] == "CONTEST_LOST"), "a bitter loser")
	B.contest_result(w, "party:1", pid, true)
	check_eq(int(Ops.person(w, pid)["grievance"]), 0, "a winner is content")


func test_defection_and_the_personal_mandate() -> void:
	var w := _world()
	var pid := _member(w, "party:2", {"POLI": 60}, LEFT, "OFFICE", 10)
	check_eq(B.defection_target(w, pid), "party:1", "a left-leaning member of a right party looks left")
	Ops.person(w, pid)["assembly_seat"] = true
	check(B.defect(w, pid, "party:1")["ok"], "defects")
	check_eq(String(Ops.person(w, pid)["party_id"]), "party:1", "a new party")
	check(int(w.peek("party")["party:1"]["seats"]) == 31 and int(w.peek("party")["party:2"]["seats"]) == 19, "personal mandate: the seat goes with them")
	var f: Array = w.facts.query("STAFF_DEFECTED")
	check(f.size() == 1 and String(f[0]["data"]["seat"]) == "CARRIED" and f[0]["data"]["to"] == "party:1", "public, with the seat")
	w.levers["LAW_PERSONAL_MANDATE"] = 0
	var q := _member(w, "party:2", {"POLI": 60}, LEFT, "OFFICE", 10)
	Ops.person(w, q)["assembly_seat"] = true
	check_eq(String(B.defect(w, q, "party:1")["seat"]), "STAYS", "party mandate: the seat stays")
	check_eq(int(w.peek("party")["party:2"]["seats"]), 19, "with the party")


func test_a_government_insider_leaks() -> void:
	var w := _world()
	var pid := _member(w, "party:1", {"POLI": 60}, LEFT, "OFFICE", 20, 90)
	Ops.person(w, pid)["pool"] = "GOV"
	var gov := {"kind": "GOVERNMENT", "id": "government"}
	var sec := w.add_fact({"type": "TEST_COVER_UP", "owner": "law", "subjects": [gov], "responsible": [{"actor": gov, "share": 1.0}],
		"impact": {}, "magnitude": 50, "visibility": "SECRET", "data": {}})
	B._leak(w, pid, Ops.person(w, pid), w.rng.stream("test"))
	check(w.peek("revealed_fact").has(sec), "the secret is out")
	var lk: Array = w.facts.query("STAFF_LEAKED")
	check(lk.size() == 1 and String(lk[0]["data"]["fact"]) == sec, "a public leak story")


func test_the_party_secretary_writes_and_ignoring_hurts() -> void:
	var w := _world()
	F.set_pol(w, {"player_party": "party:1"})
	var pid := _member(w, "party:1", {"POLI": 40, "ADMIN": 30}, LEFT, "OFFICE", 60, 60)
	_member(w, "party:1", {"ADMIN": 80}, LEFT, "QUIET")
	B.monthly(w)
	var mails := Office.items(w, ["EMAIL"]).filter(func(o): return String(o["source"].get("system", "")) == "bench")
	check_eq(mails.size(), 1, "one email about a restless member")
	check_eq(String(mails[0]["category"]), "PARTY", "party business")
	check_eq(String(mails[0]["from"]["role"]), "PARTY_SECRETARY", "from the party secretary")
	check(mails[0]["options"].any(func(o): return o["id"] == "PORTFOLIO"), "the founding government's party can offer a portfolio")
	check_eq(String(mails[0]["default_option"]), "IGNORE", "left alone, it is ignored")
	var g0 := int(Ops.person(w, pid)["grievance"])
	Office.answer(w, String(mails[0]["id"]), "IGNORE")
	B.monthly(w)
	check(Ops.person(w, pid)["grievances"].any(func(e): return e["kind"] == "IGNORED"), "ignored, and it is remembered")
	B.monthly(w)
	check_eq(Office.items(w, ["EMAIL"]).filter(func(o): return String(o["source"].get("system", "")) == "bench").size(), 0, "no second email within the year")
	check(int(Ops.person(w, pid)["grievance"]) >= g0 - 2 * B.GRIEVANCE_DECAY, "grievance held up (%d)" % int(Ops.person(w, pid)["grievance"]))


func test_the_free_mandate_is_constitutional() -> void:
	var w := _world()
	check_eq(String(w.lever_defs["LAW_PERSONAL_MANDATE"]["legalLevel"]), "CONSTITUTIONAL", "a constitutional rule")
	check(not LawOps.check_change(w, "LAW_PERSONAL_MANDATE", 0, "LAW").is_empty(), "an ordinary law cannot end it")
	check(not LawOps.amend_constitution(w, "LAW_PERSONAL_MANDATE", 0, 120)["ok"], "no constitution yet")
	LawOps.state(w)["constitution"] = true
	check_eq(LawOps.amend_seats(), 101, "2/3 of 151")
	check(not LawOps.amend_constitution(w, "LAW_PERSONAL_MANDATE", 0, 100)["ok"], "100 seats are not enough")
	check_eq(w.facts.query("LAW_AMENDMENT_FAILED").size(), 1, "a failed amendment is news")
	check(LawOps.amend_constitution(w, "LAW_PERSONAL_MANDATE", 0, 101)["ok"], "101 seats amend it")
	check_eq(int(w.levers["LAW_PERSONAL_MANDATE"]), 0, "anti-defection now")


func test_no_independents_until_politics_provides_them() -> void:
	var w := _world()
	var pid := _member(w, "party:2", {"POLI": 60}, RIGHT, "OFFICE", 5)
	check(not B.defect(w, pid, "")["ok"], "no seat: nothing to sit on as an independent")
	Ops.person(w, pid)["assembly_seat"] = true
	w.levers["LAW_PERSONAL_MANDATE"] = 0
	check(not B.defect(w, pid, "")["ok"], "anti-defection: the seat is the party's")


func test_orphans_find_a_new_party_or_retire() -> void:
	var w := _world()
	_party(w, "party:3", "Gone", LEFT, 0)
	var a := _member(w, "party:3", {"POLI": 60}, LEFT)
	var b := _member(w, "party:3", {"POLI": 60}, {"ECON_ROLE": 0, "REDISTRIBUTION": 0, "SOVEREIGNTY": 100000})
	w.table("party")["party:3"]["status"] = "DISSOLVED"
	B.monthly(w)
	check_eq(String(Ops.person(w, a)["party_id"]), "party:1", "a left member of a dissolved party joins the left party")
	check_eq(String(Ops.person(w, a)["bench_party_id"]), "party:1", "on its bench")
	check_eq(String(Ops.person(w, b)["status"]), "RETIRED", "nobody fits a lone sovereigntist: they retire")
	check_eq(w.facts.query("STAFF_BENCH_JOINED").size(), 1, "the move is public")


func test_scandals_stick_to_the_person() -> void:
	var w := _world()
	var off := _member(w, "party:1", {"POLI": 60}, LEFT)
	var lead := _member(w, "party:2", {"POLI": 60}, RIGHT)
	w.table("party")["party:2"]["leader"] = B.as_leader(w, lead)
	var sec := w.add_fact({"type": "LAW_UNLAWFUL_ACT", "owner": "law", "subjects": [], "visibility": "SECRET", "impact": {}, "magnitude": 40,
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.8}, {"actor": Ops.official_ref(off), "share": 0.2}], "data": {}})
	w.facts.reveal(w.month, sec, [])
	w.add_fact({"type": "POL_SCANDAL_REVEALED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": "party:2"}], "responsible": [],
		"impact": {}, "magnitude": 60, "visibility": "PUBLIC", "data": {}})
	B.monthly(w)
	check_eq(int(Ops.person(w, off).get("scandals", 0)), 1, "the official who carried it out")
	check_eq(int(Ops.person(w, lead).get("scandals", 0)), 1, "the leader whose party took the money")
	B.monthly(w)
	check_eq(int(Ops.person(w, off).get("scandals", 0)), 1, "counted once")


## Regression (Bob's Y50→Y70 run): a person with loyalty but no lean crashed OFS.traits. Fifty years of monthly
## bench life with founders that never had traits derived, a party dissolving, scandals and defeats.
func test_fifty_years_of_bench_life_without_traits() -> void:
	var w := _world()
	var raw := F.add(w, "POLITICAL", {"POLI": 60}, 50, 100, "party:2")
	Ops.person(w, raw)["pool"] = ""
	Ops.person(w, raw)["bench_party_id"] = "party:2"
	Ops.person(w, raw)["loyalty"] = 40                 # loyalty without lean: the crash
	check(OFS.traits(Ops.person(w, raw)).has("lean"), "traits backfills the lean")
	for i in 12:
		var pid := F.add(w, "POLITICAL", {"POLI": 40 + i * 4, "COMM": 50}, 50, 100, "party:1" if i % 2 == 0 else "party:2")
		Ops.person(w, pid)["pool"] = ""
		Ops.person(w, pid)["bench_party_id"] = Ops.person(w, pid)["party_id"]
	_party(w, "party:3", "Short-lived", LEFT, 5)
	var orphan := F.add(w, "POLITICAL", {"POLI": 50}, 50, 100, "party:3")
	Ops.person(w, orphan)["pool"] = ""
	Ops.person(w, orphan)["bench_party_id"] = "party:3"
	Ops.person(w, orphan)["loyalty"] = 50
	for m in 600:
		if m == 120:
			w.table("party")["party:3"]["status"] = "DISSOLVED"
		if m % 48 == 0:
			w.add_fact({"type": "POL_SCANDAL_REVEALED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": "party:2"}],
				"responsible": [], "impact": {}, "magnitude": 60, "visibility": "PUBLIC", "data": {}})
		B.monthly(w)
		w.month += 1
	for pid in B.members(w):
		check(Ops.person(w, pid).has("lean") and Ops.person(w, pid).has("ambition"), "%s has its traits after 50 years" % pid)
	check(String(Ops.person(w, orphan)["party_id"]) != "party:3", "the orphan moved on")
