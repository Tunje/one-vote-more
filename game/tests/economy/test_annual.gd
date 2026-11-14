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
	check_eq(EconAnnual.limit(w, o), 200000 * EconUtil.S, "limit = 2 months of average sales")
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
