extends TestCase
## The plan, the building contract and the opening (rebuild-building.md 4; step-3 joins): one family farm planned,
## quoted, signed, supplied three months up front, worked month by month, paid and opened, each to the last credit and
## unit, with nothing appearing or vanishing.

const Building := preload("res://sim/economy/building.gd")
const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const HomeBuilders := preload("res://sim/economy/home_builders.gd")
const Market := preload("res://sim/economy/market.gd")
const Site := preload("res://sim/transport/site.gd")
const Rules := preload("res://sim/economy/rules.gd")
const S := CoreUtil.S

var _people := 0


func _world() -> WorldState:
	var w := GameSim.make(7).world
	_work(w, 20000)
	return w


## Rule 7's work for farms: a settled month in which the Landing's buyers ordered `food` FOOD (test-only: written into
## the market's month summary, as Market.clear would).
func _work(w: WorldState, food: int) -> void:
	var area := AreaStore.found_landing(w)
	var st := w.table("market")
	if not st.has("orders"):
		st["orders"] = {}
		st["sum"] = {}
	st["sum"] = {str(w.month): {"FOOD|" + area: {"ordered": food * S, "filled": 0, "paid": 0,
		"unfilled": {"NO_MONEY": 0, "PRICE": 0, "SOLD_OUT": 0, "NO_SELLER": 0}}}}
	st["settled"] = w.month


func _founder(w: WorldState, credits: int) -> String:
	_people += 1
	var id := "founder:%d" % (900 + _people)
	w.ledger.open_account(id)
	w.ledger.transfer(Ledger.EXTERNAL, id, credits * S, "TEST", w.month)
	return id


func _plan(w: WorldState, credits: int) -> String:
	var area := AreaStore.found_landing(w)
	var site: Dictionary = Site.choose_country(w, "FARM", 1, 1)[0]
	return Building.make_plan(w, _founder(w, credits), "FARM", "FAMILY", area, site, {"test": true})


## The building side of one month, in the joins' order.
func _month(w: WorldState) -> void:
	w.month += 1
	Building.open_due(w)
	Building.work_month(w)
	Building.supply_orders(w)
	Market.clear(w)
	Building.take_deliveries(w)
	Building.bill_month(w)
	Building.sign_round(w)


func _stores(w: WorldState) -> String:
	for cid in Company.ids(w):
		if String(Company.record(w, cid).get("origin", "")) == "COLONY_STORES":
			return cid
	return ""


func test_one_family_farm_from_plan_to_opening() -> void:
	var w := _world()
	var stores := _stores(w)
	check(stores != "", "the Colony Stores exist")
	var mat0 := int(Company.stock_of(w, stores, "MATERIAL")["qty"])
	var comp0 := int(Company.stock_of(w, stores, "COMPONENT")["qty"])
	var tre0 := w.ledger.balance(CoreUtil.TREASURY)
	var pid := _plan(w, 40000)
	check(pid != "", "a plan is made")
	var p: Dictionary = w.peek("plan")[pid]
	check_eq(String(p["status"]), "MADE", "made, not a company")
	check(not Site.of(w, pid).is_empty(), "its site is held")
	var need := Building.founder_needs(w, "FARM", "FAMILY", String(p["area"]))
	check_eq(w.ledger.balance(pid), need, "the founder's money moved in, as much as the plan needs")
	check_eq(Company.ids(w).filter(func(c): return Company.type_of(w, c) == "FARM").size(), 0, "no farm company yet")

	Building.sign_round(w)
	var m0 := w.month
	check_eq(String(p["status"]), "SIGNED", "signed in the month it was made")
	var cid := String(p["contract"])
	var c: Dictionary = w.peek("contract")[cid]
	var b := String(c["builder"])
	check_eq(int(c["bill"]["bw"]), 40 * S, "a family farm is 40 BW")
	check_eq(int(c["bill"]["MATERIAL"]), 40 * S, "and 40 MATERIAL")
	check_eq(int(c["bill"]["COMPONENT"]), 2 * S, "and 2 COMPONENT")
	check_eq(int(c["months"]), 3, "in 3 months at the fewest")
	check_eq(int(c["price_bw"]), Company.price(w, b, "BW"), "the builder's price per BW fixed at signing")
	var land := int(p["cost"]["land"])
	check(land > 0, "the land was bought")
	check_eq(w.ledger.balance(CoreUtil.TREASURY), tre0 + land, "the land money went to the colony")
	var builder0 := w.ledger.balance(CoreUtil.acct(b))

	_month(w)   # m0+1: the first supplies arrive; no work yet
	check_eq(int(c["done"]), 0, "no work before the supplies are on the site")
	check_eq(int(c["on_site"]["MATERIAL"]), 40 * S, "three months up front: all 40 MATERIAL (the bill is under three months)")
	check_eq(int(c["on_site"]["COMPONENT"]), 1998, "three months of components: 3 x 666")
	_month(w)   # m0+2
	check_eq(String(c["status"]), "WORKING", "work starts")
	check_eq(int(c["done"]), 13334, "a third of the bill a month: 13.334 BW")
	_month(w)   # m0+3
	_month(w)   # m0+4
	check_eq(String(c["status"]), "DONE", "done in the fourth month after signing")
	check_eq(int(c["done_month"]), m0 + 4, "done month")
	check_eq(int(c["used"]["MATERIAL"]), 40 * S, "every unit of material built in")
	check_eq(int(c["used"]["COMPONENT"]), 2 * S, "every component built in")
	check_eq(Building.goods_on_sites(w), {"MATERIAL": 0, "COMPONENT": 0}, "nothing left lying on the site")
	check_eq(mat0 - int(Company.stock_of(w, stores, "MATERIAL")["qty"]), 40 * S, "the Stores sold exactly the 40 MATERIAL")
	check_eq(comp0 - int(Company.stock_of(w, stores, "COMPONENT")["qty"]), 2 * S, "and exactly the 2 COMPONENT")
	check_eq(int(c["owed"]), 0, "nothing owed")
	check_eq(w.ledger.balance(CoreUtil.acct(b)) - builder0, int(c["paid"]), "the builder received exactly what the plan paid")
	check_eq(int(c["paid"]), 40 * int(c["price_bw"]), "40 BW at the price fixed at signing (wages unchanged)")

	_month(w)   # m0+5: it opens
	check_eq(String(p["status"]), "OPEN", "the plan became a company")
	var co := String(p["company"])
	check(co != "" and co != pid, "a company of its own id")
	check_eq(Company.type_of(w, co), "FARM", "a farm")
	check_eq(Company.size_of(w, co), "FAMILY", "family size")
	check_eq(Company.owner_kind(w, co), "FAMILY", "owned by the founding family")
	var plants := Company.plant_ids_of(w, co)
	check_eq(plants.size(), 1, "one plant")
	check(not Site.of(w, plants[0]).is_empty() and Site.of(w, pid).is_empty(), "the site moved from the plan to the plant")
	check_eq(w.ledger.balance(pid), 0, "the plan's account is empty")
	check(w.ledger.balance(CoreUtil.acct(co)) > 0, "its money is the company's")
	check_eq(Company.staff_count(w, co), 0, "no staff yet: it hires by the output rules")
	check_eq(Logbook.rows(w, {"kind": "OPEN", "who": co, "ref": pid}).size(), 1, "an OPEN row with the plan as ref")
	check_eq(Logbook.rows(w, {"kind": "QUOTE", "ref": pid}).size(), Building.builders(w).size(), "every builder quoted")
	check_eq(Logbook.rows(w, {"kind": "CONTRACT", "who": cid}).size(), 1, "one CONTRACT row")
	check(Logbook.rows(w, {"kind": "PAY", "who": cid}).size() == 3, "one bill a month of work")
	check_eq(w.facts.query("ECON_CONTRACT_AWARDED").size(), 1, "the award published")
	check_eq(w.facts.query("ECON_PROJECT_COMPLETED").size(), 1, "the completion published")
	check_eq(w.ledger.total(), 0, "the ledger adds up")


func test_crews_go_on_to_the_next_job_when_one_site_has_no_supplies() -> void:
	var w := _world()
	var a := _plan(w, 40000)
	var b2 := _plan(w, 40000)
	var b: String = Building.builders(w)[0]
	var q := {"builder": b, "bw_price": Company.price(w, b, "BW"), "total": 0, "start": w.month + 2}
	w.table(Building.OPENED)["first_quote_m"] = w.month   # signed by hand, past the start: the builders' market is open
	var ca := Building._sign(w, a, q)
	var cb := Building._sign(w, b2, q)
	w.table("contract")[ca]["worth"]["MATERIAL"] = 0   # its client will pay nothing for material: no supplies come
	_month(w)
	_month(w)
	check_eq(int(w.peek("contract")[ca]["done"]), 0, "the job without supplies waits, keeping its place")
	check_eq(int(w.peek("contract")[cb]["done"]), 13334, "the crews work the next job")
	var sig := Building.book_signals(w, b)
	check(int(sig["crews_waiting_material"]) > 0, "crews idle for want of supplies are counted apart")
	check_eq(int(sig["crews_waiting_material"]) + int(sig["crews_empty"]) + int(sig["bw_done"]), int(sig["cap"]), "every crew-month accounted for")
	check_eq(Building.book(w, b), [ca, cb], "the book in signing order")
	var ss := Building.seller_signal(w, b)
	check_eq(int(ss["sold"]), 13334, "the market-shaped signal: the BW it did")
	check_eq(int(ss["offered"]), int(sig["cap"]) - int(sig["crews_waiting_material"]), "offered: crews less those waiting for supplies")
	check_eq(int(ss["offered"]) - int(ss["sold"]), int(sig["crews_empty"]), "unsold = the empty crews, the rule-2 signal")
	check_eq(int(ss["unmet_above"]), 0, "it had crews for all the work its supplies allowed")


func test_three_unpaid_months_stop_the_builder_and_the_plan_is_given_up() -> void:
	var w := _world()
	var pid := _plan(w, 40000)
	Building.sign_round(w)
	var cid := String(w.peek("plan")[pid]["contract"])
	_month(w)   # supplies arrive
	var left := w.ledger.balance(pid)
	w.ledger.transfer(pid, Ledger.EXTERNAL, left, "TEST_DRAIN", w.month)
	_month(w)
	check_eq(int(w.peek("contract")[cid]["unpaid_m"]), 1, "one month unpaid")
	_month(w)
	_month(w)
	check_eq(int(w.peek("contract")[cid]["unpaid_m"]), 3, "three months unpaid")
	check_eq(String(w.peek("plan")[pid]["status"]), "GIVEN_UP", "its owner gives it up: it cannot pay the stopped job")
	check_eq(String(w.peek("contract")[cid]["status"]), "ABANDONED", "the half-built job is left")
	check(int(w.peek("contract")[cid]["owed"]) > 0, "what is owed stays recorded")
	check(not Site.of(w, pid).is_empty(), "the land and the half-built building stay the founder's")
	check_eq(w.facts.query("ECON_CONTRACT_PAYMENT_MISSED").size(), 1, "the missed payments published")
	check_eq(w.facts.query("COMP_PLAN_ABANDONED").size(), 1, "the abandoned plan published")
	check_eq(Company.ids(w).filter(func(c): return Company.type_of(w, c) == "FARM").size(), 0, "never a company, so never a failed one")
	check_eq(w.ledger.total(), 0, "the ledger adds up")


func test_a_plan_waits_while_its_money_does_not_cover_the_quote() -> void:
	var w := _world()
	var pid := _plan(w, 2000)
	Building.sign_round(w)
	check_eq(String(w.peek("plan")[pid]["status"]), "MADE", "it waits")
	check_eq(Logbook.rows(w, {"kind": "PLAN", "who": pid, "what_has": "waits"}).size(), 1, "and says why")
	var b := String(Logbook.rows(w, {"kind": "PLAN", "who": pid, "what_has": "waits"})[0]["with"])
	Building.work_month(w)   # the next month's PRODUCTION: the refusal is in the month its rules read
	check(int(Building.book_signals(w, b)["refused_price_bw"]) > 0, "the builder hears its quote was too dear")
	w.ledger.transfer(Ledger.EXTERNAL, pid, 40000 * S, "TEST", w.month)
	Building.sign_round(w)
	check_eq(String(w.peek("plan")[pid]["status"]), "SIGNED", "with the money it signs")


func test_a_plan_given_up_before_signing_spends_nothing() -> void:
	var w := _world()
	var pid := _plan(w, 40000)
	var founder := String(w.peek("plan")[pid]["founder"])
	_work(w, 0)   # the work is no longer there
	Building.sign_round(w)
	check_eq(String(w.peek("plan")[pid]["status"]), "GIVEN_UP", "given up")
	check(Site.of(w, pid).is_empty(), "the site is free again")
	check_eq(w.ledger.balance(pid), 0, "nothing left in the plan")
	check_eq(w.ledger.balance(founder), 40000 * S, "every credit back with the founder")
	check_eq(w.peek("contract").size(), 0, "no contract")


func test_the_bill_follows_the_builders_wages_not_its_price() -> void:
	var w := _world()
	var pid := _plan(w, 40000)
	Building.sign_round(w)
	var c: Dictionary = w.peek("contract")[w.peek("plan")[pid]["contract"]]
	var b := String(c["builder"])
	_month(w)
	Company.set_price(w, b, "BW", int(c["price_bw"]) * 2, {"test": true})   # a new price is for new jobs only
	Company.yearly_raise(w, b, 100, 0)   # wages rise 10%
	var dw := Building.wage_bw(w, b) - int(c["wage_bw"])
	check(dw > 0, "its wages per BW rose")
	_month(w)
	var row: Dictionary = Logbook.rows(w, {"kind": "PAY", "who": c["id"]})[0]
	check_eq(int(row["why"]["bill"]), 13334 * (int(c["price_bw"]) + dw) / S / S, "the bill: work done x (price at signing + the wage rise)")


func test_a_site_paid_by_a_company_never_fills_the_companys_stock() -> void:
	var w := _world()
	var pid := _plan(w, 40000)
	Building.sign_round(w)
	var c: Dictionary = w.table("contract")[w.peek("plan")[pid]["contract"]]
	var payer: String = Building.builders(w)[1]   # any company as the client (a size-up or repair, steps 6 and 8)
	w.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(payer), 5000 * S, "TEST", w.month)
	c["client"] = payer
	c["client_acct"] = CoreUtil.acct(payer)
	var held0 := int(Company.stock_of(w, payer, "MATERIAL")["qty"])
	_month(w)
	check_eq(int(c["on_site"]["MATERIAL"]), 40 * S, "the supplies are on the site")
	check_eq(int(Company.stock_of(w, payer, "MATERIAL")["qty"]), held0, "not in the paying company's stock: counted once")
	check_eq(Building.goods_on_sites(w)["MATERIAL"], 40 * S, "the goods check sees them on the site")


func test_the_public_works_department_never_quotes_for_a_private_plan() -> void:
	var w := _world()
	var pw := String(HomeBuilders.existing(w)["public_works"])
	check(pw != "" and HomeBuilders.bw_milli(w, pw) > 0, "the public works department exists with its crew")
	check(not Building.builders(w).has(pw), "not among the builders a plan can hire")
	check(Building.builders(w, false).has(pw), "but its month is still run")
	var pid := _plan(w, 40000)
	for q in Building.quotes(w, pid):
		check(String(q["builder"]) != pw, "no quote from the public works department")
	_month(w)
	var cid := String(w.peek("plan")[pid]["contract"])
	check(cid != "", "the plan signed with a builder")
	check(String(w.peek("contract")[cid]["builder"]) != pw, "and not with the public works department")
	check_eq(Building.book(w, pw).size(), 0, "its book stays empty")


func test_a_site_orders_its_supplies_when_its_job_is_next_in_line_not_at_signing() -> void:
	var w := _world()
	var b: String = Building.builders(w)[0]
	var q := {"builder": b, "bw_price": Company.price(w, b, "BW"), "total": 0, "start": w.month + 2}
	var cs: Array = []
	for i in 8:
		cs.append(Building._sign(w, _plan(w, 40000), q))
	var line := Building.next_in_line(w)
	var k := 0
	while k < cs.size() and line.has(cs[k]):
		k += 1
	check(k >= 1 and k < cs.size(), "some jobs are next in line, not all eight")
	for i in range(k, cs.size()):
		check(not line.has(cs[i]), "next in line is the front of the book, in signing order")
	# the crews free next month cover every job in line but the last
	var c0: Dictionary = w.peek("contract")[cs[0]]
	var per := Building.planned_bw(c0)
	check_eq(k, (HomeBuilders.bw_milli(w, b) + per - 1) / per, "as many as next month's crews would reach")
	_month(w)
	for i in cs.size():
		var c: Dictionary = w.peek("contract")[cs[i]]
		var held := int(c["on_site"]["MATERIAL"]) + int(c["on_site"]["COMPONENT"])
		if i < k:
			check(held > 0, "a job next in line has its supplies on site")
		else:
			check_eq(held, 0, "a job further back has bought nothing yet")
			check_eq(int(w.peek("plan")[c["plan"]]["cost"]["supplies"]), 0, "and its plan's money is untouched")
			check_eq(Logbook.rows(w, {"kind": "SUPPLY", "who": cs[i]}).size(), 0, "no order in the log")
	check_eq(w.ledger.total(), 0, "the ledger adds up")


func test_plans_signed_to_wait_behind_a_full_book_count_once_as_unmet() -> void:
	var w := _world()
	var b: String = Building.builders(w)[0]
	var q := {"builder": b, "bw_price": Company.price(w, b, "BW"), "total": 0, "start": w.month + 2}
	for i in 8:
		Building._sign(w, _plan(w, 40000), q)
	# the cheapest builder, so both new plans take it although they must wait behind its book
	Company.set_price(w, b, "BW", Company.price(w, b, "BW") / 2, {"test": true}, "test price")
	var p1 := _plan(w, 40000)
	var p2 := _plan(w, 40000)
	check(Building.start_month(w, b) > w.month + 2, "its book is full: a new job would wait")
	Building.sign_round(w)
	for pid in [p1, p2]:
		var cid := String(w.peek("plan")[pid]["contract"])
		check(cid != "" and String(w.peek("contract")[cid]["builder"]) == b, "signed with the cheap builder")
	var bw := int(TypeTable.bill("FARM", "FAMILY")["bw"])
	_month(w)
	check_eq(int(Building.seller_signal(w, b)["unmet_above"]), 2 * bw, "next month: the two plans' BW, once")
	_month(w)
	check(Building.book(w, b).size() >= 8, "the book is still there")
	check_eq(int(Building.seller_signal(w, b)["unmet_above"]), 0, "the month after: nothing, the waiting book is not counted again")
	var other: String = Building.builders(w)[1]
	check_eq(int(Building.seller_signal(w, other)["unmet_above"]), 0, "a builder nobody waited for counts nothing")



func test_at_the_start_no_rule_cuts_a_builders_price_or_crew_until_the_first_plan_asks() -> void:
	var w := _world()
	var b: String = Building.builders(w)[0]
	var px := Company.price(w, b, "BW")
	var lv := Company.level_of(w, b, "crew")
	var crew := Company.staff_count(w, b, "", "crew")
	for i in 3:
		w.month += 1
		Building.work_month(w)
		check(not w.peek(Building.MONTH).get(b, {}).is_empty(), "its month is recorded")
		check(Building.seller_signal(w, b).is_empty(), "no signal at the start: no customer could exist yet")
		Rules.month(w)
	check_eq(Building.first_quote_month(w), -1, "nobody has asked for a quote")
	check_eq(Company.price(w, b, "BW"), px, "no cut for the start: the price stays")
	check_eq(Company.level_of(w, b, "crew"), lv, "nor the crew level")
	check_eq(Company.staff_count(w, b, "", "crew"), crew, "nor the crew")
	var pid := _plan(w, 40000)
	Building.sign_round(w)
	check_eq(Building.first_quote_month(w), w.month, "the first plan asked: the market is open from this month")
	var other: String = Building.builders(w)[1]
	w.month += 1
	Building.work_month(w)
	check(not Building.seller_signal(w, b).is_empty(), "after the first quote the signal is there")
	check(not Building.seller_signal(w, other).is_empty(), "for every builder, quoted or chosen or not")
	check_eq(Logbook.rows(w, {"kind": "QUOTE", "who": "builders"}).size(), 1, "the opening of the market is in the log once")
