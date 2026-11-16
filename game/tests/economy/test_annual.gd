extends TestCase
## E140 (EconAnnual, opt-in "E140", yearly payout "E140P"): firms plan on a 12-month P&L, keep a revolving credit line,
## fall into distress only with the line exhausted, and pay their owners once a year.


func _private(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and o.get("owner_group", "") != "":
			return oid
	return ""


## A year of steady, profitable months: revenue 100k, wages 60k, inputs 20k (credits).
func _good_year(o: Dictionary) -> void:
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 100000 * EconUtil.S
		pl["wages"] = 60000 * EconUtil.S
		pl["cogs"] = 20000 * EconUtil.S
		ring.append(pl)
	o["pl_ring"] = ring
	o["pl_last"] = (ring[11] as Dictionary).duplicate()


func _drain(w: WorldState, oid: String) -> void:
	EconUtil.pay_upto(w, EconUtil.acct(oid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(oid)), "TEST")


func test_ring_always_recorded() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(15)
	var oid := _private(w)
	check(oid != "", "a private firm")
	var o: Dictionary = w.table("org")[oid]
	check(EconAnnual.months(o) == 12, "ring capped at 12 months (%d)" % EconAnnual.months(o))
	var rev := 0
	for pl in o["pl_ring"]:
		rev += int(pl.get("rev", 0))
	check_eq(int(EconAnnual.sum12(o).get("rev", 0)), rev, "sum12 adds the ring")
	for lid in w.table("loan"):
		check(not bool(w.table("loan")[lid].get("revolving", false)), "no credit lines when E140 is off")


func test_line_covers_wages_interest_only() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var oid := _private(w)
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	check_eq(EconAnnual.limit(w, o), 2 * EconAnnual.expected_rev(w, o), "limit = 2 months of what it is going to sell")
	check(EconAnnual.limit(w, o) >= 200000 * EconUtil.S, "never below 2 months of its average sales")
	var ob0 := EconInsolvency.obligations(w, oid)
	_drain(w, oid)
	EconAnnual.pre_settle(w)
	var lid := EconAnnual.line_id(w, oid)
	check(lid != "", "the line was drawn")
	check_eq(w.ledger.balance(EconUtil.acct(oid)), 60000 * EconUtil.S, "drew this month's wage bill")
	check_eq(EconAnnual.drawn(w, oid), 60000 * EconUtil.S, "drawn balance")
	check_eq(EconInsolvency.obligations(w, oid), ob0, "the drawn line adds no principal to the obligations")
	var p0 := EconAnnual.drawn(w, oid)
	EconFinance._loan_service(w)
	check_eq(EconAnnual.drawn(w, oid), p0, "interest only: principal unchanged")
	check(int(o["pl"].get("interest", 0)) > 0, "interest booked")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_sweep_and_term_out() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var oid := _private(w)
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	_drain(w, oid)
	EconAnnual.draw(w, oid, 150000 * EconUtil.S)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), 300000 * EconUtil.S, "TEST", w.month)  # a good month's sales
	EconAnnual.post_settle(w)
	# cash 450k; keeps 2 × 80k costs = 160k; repays 150k
	check_eq(EconAnnual.drawn(w, oid), 0, "spare cash repays the line")
	_drain(w, oid)
	EconAnnual.draw(w, oid, 200000 * EconUtil.S)
	var lid := EconAnnual.line_id(w, oid)
	for m in EconAnnual.CONVERT_M:
		_drain(w, oid)
		EconAnnual.post_settle(w)
	check(not bool(w.table("loan")[lid].get("revolving", true)), "fully drawn for a year: termed out")
	check_eq(int(w.table("loan")[lid]["term_left"]), EconAnnual.CONVERT_TERM, "a term loan again")
	check(EconInsolvency.obligations(w, oid) >= 200000 * EconUtil.S / EconAnnual.CONVERT_TERM, "back in the obligations")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_distress_needs_exhausted_line() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var oid := _private(w)
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	check_eq(EconAnnual.distress(w, oid, true, 0), 0, "a missed payment with room on the line: no distress")
	EconAnnual.draw(w, oid, 10000000 * EconUtil.S)
	check_eq(EconAnnual.distress(w, oid, true, 0), 1, "missed with the line exhausted: distress")
	check_eq(EconAnnual.distress(w, oid, false, 0), 0, "no miss, profitable year: no distress")
	for pl in o["pl_ring"]:
		pl["wages"] = 120000 * EconUtil.S
	check_eq(EconAnnual.distress(w, oid, false, 0), 1, "loss-making year and cash below a month's costs: distress")
	w.meta["on"] = []
	check_eq(EconAnnual.distress(w, oid, true, 0), -1, "old rule when off")


func test_yearly_payout() -> void:
	var paid := {}
	for flags in [["PAYOUT", "E140"], ["PAYOUT", "E140", "E140P"]]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = flags
		sim.run(2)
		while w.month_of_year() != 3:
			sim.run(1)
		var oid := _private(w)
		var o: Dictionary = w.table("org")[oid]
		_good_year(o)
		_drain(w, oid)
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), 1000000 * EconUtil.S, "TEST", w.month)
		o["profit_q"] = 100000 * EconUtil.S
		var before := w.ledger.balance(EconUtil.acct(oid))
		EconFinance._profit_tax_and_dividends(w)
		paid[flags.size()] = before - w.ledger.balance(EconUtil.acct(oid))
	check(int(paid[2]) > 500000 * EconUtil.S, "quarterly PAYOUT empties the firm in March (%d)" % (int(paid[2]) / EconUtil.S))
	check(int(paid[3]) < 100000 * EconUtil.S, "E140P: only profit tax in March, no payout (%d)" % (int(paid[3]) / EconUtil.S))


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140", "E140P", "PAYOUT"]
	sim.run(30)
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])
	var lines := 0
	for lid in w.table("loan"):
		if bool(w.table("loan")[lid].get("revolving", false)):
			lines += 1
	check(lines >= 0, "lines open: %d" % lines)


## User 2026-11-16: "I said to remove the limits from last month". A firm plans and borrows on its year, so one bad
## month does not close its credit, and one good month does not open it wide.
func test_borrowing_reads_the_year_not_last_month() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(2)
	var oid := _private(w)
	check(oid != "", "a private firm")
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	check_eq(EconAnnual.plan_rev(w, o), 100000 * EconUtil.S, "the average month of the year")
	(o["pl_last"] as Dictionary)["rev"] = 0     # last month: nothing sold
	check_eq(EconAnnual.plan_rev(w, o), 100000 * EconUtil.S, "a month without sales does not change what it plans on")
	(o["pl_last"] as Dictionary)["rev"] = 900000 * EconUtil.S
	check_eq(EconAnnual.plan_rev(w, o), 100000 * EconUtil.S, "nor does one very good month")
	o["pl_ring"] = []
	check_eq(EconAnnual.plan_rev(w, o), 900000 * EconUtil.S, "with no history yet it has only last month to go on")
	w.meta["on"] = []
	_good_year(o)
	(o["pl_last"] as Dictionary)["rev"] = 5 * EconUtil.S
	check_eq(EconAnnual.plan_rev(w, o), 5 * EconUtil.S, "without yearly budgeting the old rule stands")


## E140 correction (user 2026-11-16: "THEY CAN NEVER GROW"): limits follow what a firm is going to sell, not its past.
func _set_plan(w: WorldState, oid: String, t_pm: int) -> void:
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["org"] == oid:
			f["T"] = t_pm


func test_orders_beyond_history_can_be_financed() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var oid := _private(w)
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	_set_plan(w, oid, 1000)
	var plan := EconAnnual._plan_value(w, o)
	check(plan > 0, "the firm plans output at full targets")
	for pl in o["pl_ring"]:
		(pl as Dictionary)["rev"] = plan / 2   # it sold half of what it now plans to make
	(o["pl_last"] as Dictionary)["rev"] = plan / 2
	check_eq(EconAnnual.expected_rev(w, o), plan, "it plans on its orders, twice its history")
	check_eq(EconAnnual.limit(w, o), 2 * plan, "the line follows the plan, not the past")
	var room0 := EconAnnual.input_draw(w, oid, 0, 3 * plan)
	check(room0 > plan / 2 * 2, "the input budget can buy beyond what its history would allow (%d)" % room0)


func test_no_orders_no_credit_beyond_steady_need() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var oid := _private(w)
	var o: Dictionary = w.table("org")[oid]
	_good_year(o)
	_set_plan(w, oid, 0)
	check_eq(EconAnnual.expected_rev(w, o), 100000 * EconUtil.S, "with no orders it plans on its steady history")
	check_eq(EconAnnual.limit(w, o), 200000 * EconUtil.S, "no more than 2 months of it")
	var lid := w.new_id("loan")
	w.table("loan")[lid] = {"id": lid, "borrower": oid, "principal": 1000 * EconUtil.S, "rate_ppm": 6000, "term_left": 12, "missed": 1}
	check_eq(EconAnnual.limit(w, o), 0, "a missed payment closes the line (the borrower's record)")
	w.table("loan").erase(lid)


func test_builder_with_a_contract_and_no_history_can_buy_material() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(2)
	var oid := ""
	for k in EconUtil.sorted_keys(w.table("org")):
		if bool(w.table("org")[k].get("is_contractor", false)) and w.table("org")[k]["status"] == "ACTIVE":
			oid = k
			break
	check(oid != "", "a builder")
	var o: Dictionary = w.table("org")[oid]
	o["pl_ring"] = []
	o["pl_last"] = EconFinance.empty_pl()
	var pid := w.new_id("project")
	w.table("project")[pid] = {"id": pid, "status": "ACTIVE", "price": 300000 * EconUtil.S, "paid": 0, "wu_total": 100 * EconUtil.S, "wu_done": 0, "min_months": 6}
	var old_c: Array = (o.get("contracts", []) as Array).duplicate()
	o["contracts"] = [pid]
	check_eq(EconAnnual.unbilled(w, o), 300000 * EconUtil.S, "the contract still pays its full price")
	check(EconAnnual.expected_rev(w, o) >= 50000 * EconUtil.S, "it expects the contract's pay, not its empty history")
	EconUtil.pay_upto(w, EconUtil.acct(oid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(oid)), "TEST")
	var got := FirmAI._working_capital(w, oid, 120000 * EconUtil.S)
	check(got > 0, "a builder with a signed contract and no history can borrow for its material (%d)" % got)
	o["contracts"] = old_c
	w.table("project").erase(pid)


func test_public_enterprise_plans_on_the_yearly_line() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140"]
	sim.run(4)
	var pe := ""
	for k in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[k]["type"] == "PUBLIC_ENTERPRISE" and w.table("org")[k]["status"] == "ACTIVE":
			pe = k
			break
	check(pe != "", "a public enterprise")
	var o: Dictionary = w.table("org")[pe]
	_good_year(o)
	check(EconAnnual.lends(w, o) and not EconAnnual.applies(w, o), "it gets the line, not E140's other rules")
	check(EconAnnual.limit(w, o) >= 200000 * EconUtil.S, "a line on what it is going to sell, like any firm")
	w.meta["on"] = []
	check_eq(EconAnnual.limit(w, o), 0, "without E140 no line")
