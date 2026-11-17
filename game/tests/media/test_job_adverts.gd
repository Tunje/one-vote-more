extends TestCase
## Job adverts (the user's ruling on keeping workers, rebuild-company.md 9.2; Media.job_advert): hiring pays the papers
## a tenth of a month's pay per person hired, to the papers read in the district by their circulation there, else every
## paper by its whole circulation, else nothing is charged. Never overdrawn. The papers count it in their books and
## margin. Exact to the last credit; nothing appears or vanishes.

const LawOps := preload("res://sim/law/law_ops.gd")
const S := 1000


func _world() -> WorldState:
	var w := WorldState.new(7)
	LawOps.init_world(w)
	w.month = 5
	return w


## Two papers: A read by 300 in district:1 and 100 in district:2, B by 100 in district:1. Returns [a, b].
func _papers(w: WorldState) -> Array:
	var a: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:1"}, {"quality": 100})["out_id"]
	var b: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:2"}, {"quality": 100})["out_id"]
	for id in Media.outlets(w):
		if not (id in [a, b]):
			Media.close_outlet(w, id, "TEST")
	Media.state(w)["circ"] = {a: {"district:1": 300, "district:2": 100}, b: {"district:1": 100}}
	return [a, b]


func _company(w: WorldState, cash: int) -> String:
	w.ledger.open_account("co:1")
	if cash > 0:
		w.ledger.transfer(Ledger.EXTERNAL, "co:1", cash, "TEST", w.month)
	return "co:1"


func _acct(w: WorldState, id: String) -> String:
	return String(Media.outlet(w, id)["account"])


func test_an_advert_pays_the_papers_read_in_the_district() -> void:
	var w := _world()
	var p := _papers(w)
	var acct := _company(w, 10000 * S)
	var total := w.ledger.total()
	var a0 := w.ledger.balance(_acct(w, p[0]))
	var b0 := w.ledger.balance(_acct(w, p[1]))
	var paid := Media.job_advert(w, "company:1", acct, "district:1", 1000 * S, 3)
	check_eq(paid, 300 * S, "a tenth of a month's pay for each of the three hired")
	check_eq(w.ledger.balance(acct), 9700 * S, "from the company")
	check_eq(w.ledger.balance(_acct(w, p[0])) - a0, 225 * S, "A has three quarters of the readers there")
	check_eq(w.ledger.balance(_acct(w, p[1])) - b0, 75 * S, "B the other quarter")
	check_eq(w.ledger.total(), total, "nothing appears or vanishes")
	check_eq(Media.adverts_of(w, p[0]), 225 * S, "in A's advert income this month")
	var rows := Logbook.rows(w, {"kind": "ADVERT", "what": "job advert"})
	check_eq(rows.size(), 1, "logged")
	if rows.size() == 1:
		check_eq(int(rows[0]["why"]["due"]), 300, "with what was due")
	w.month += 1
	check_eq(Media.adverts_of(w, p[0]), 0, "a new month starts at nothing")


func test_where_no_paper_is_read_every_paper_shares_it() -> void:
	var w := _world()
	var p := _papers(w)
	var acct := _company(w, 10000 * S)
	var a0 := w.ledger.balance(_acct(w, p[0]))
	check_eq(Media.job_advert(w, "company:1", acct, "district:9", 1000 * S, 1), 100 * S, "the advert is paid")
	check_eq(w.ledger.balance(_acct(w, p[0])) - a0, 80 * S, "A by its whole circulation: 400 of 500")


func test_a_company_pays_what_it_holds_and_no_paper_no_charge() -> void:
	var w := _world()
	_papers(w)
	var h := w.state_hash()
	check_eq(Media.job_advert_cost(w, "district:1", 1000 * S, 3), 300 * S, "the cost, asked before hiring")
	check_eq(Media.job_advert_cost(w, "district:9", 1000 * S, 3), 300 * S, "the same where the colony's papers share it")
	check_eq(w.state_hash(), h, "asking changes nothing")
	var acct := _company(w, 50 * S)
	check_eq(Media.job_advert(w, "company:1", acct, "district:1", 1000 * S, 3), 50 * S, "never overdrawn")
	check_eq(w.ledger.balance(acct), 0, "all it held")
	var w2 := _world()
	for id in Media.outlets(w2):
		Media.close_outlet(w2, id, "TEST")
	var acct2 := _company(w2, 10000 * S)
	check_eq(Media.job_advert_cost(w2, "district:1", 1000 * S, 3), 0, "no paper: the advert costs nothing")
	check_eq(Media.job_advert(w2, "company:1", acct2, "district:1", 1000 * S, 3), 0, "no paper: nothing charged")
	check_eq(w2.ledger.balance(acct2), 10000 * S, "the company keeps it")
	check_eq(Logbook.rows(w2, {"kind": "ADVERT", "what": "no advert: no paper"}).size(), 1, "and that is logged")


func test_the_papers_books_count_the_adverts() -> void:
	var w := _world()
	var p := _papers(w)
	Media.job_advert(w, "company:1", _company(w, 10000 * S), "district:1", 1000 * S, 4)
	var o: Dictionary = w.table("outlet")[p[0]]
	o["fin"] = {"month": w.month, "cost": 100 * S, "paid": 100 * S, "sales": 0, "adverts": Media.adverts_of(w, p[0])}
	check_eq(Media.margin(w, o), 300 * S - 100 * S, "the margin counts the advert income")


## The real path: a hiring area, the district drawn over it, the papers read there (Anni's review).
func test_an_area_reaches_the_papers_of_its_district() -> void:
	var sim := GameSim.make(3)
	var w: WorldState = sim.world
	var p := _papers(w)
	var area := String(AreaStore.areas(w)[0]["id"])
	AreaStore.set_district(w, area, "district:1")
	var acct := _company(w, 10000 * S)
	var a0 := w.ledger.balance(_acct(w, p[0]))
	var b0 := w.ledger.balance(_acct(w, p[1]))
	check_eq(Media.job_advert(w, "company:1", acct, area, 1000 * S, 3), 300 * S, "paid")
	check_eq(w.ledger.balance(_acct(w, p[0])) - a0, 225 * S, "A by its readers in the area's district")
	check_eq(w.ledger.balance(_acct(w, p[1])) - b0, 75 * S, "B the same")
	var rows := Logbook.rows(w, {"kind": "ADVERT", "what": "job advert"})
	check(rows.size() == 1 and String(rows[0]["why"]["district"]) == "district:1", "the district it was read in")
