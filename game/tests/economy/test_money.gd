extends TestCase
## The money fix: E152 a sound bank (reschedule, debt passes with a bought-out plant, no remittance below the capital
## floor) and E153 working-capital lines secured on stock and receivables.


func _firm(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE":
			return oid
	return ""


func test_reschedule_keeps_principal() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E152"]
	sim.run(2)
	var oid := _firm(w)
	EconFinance.new_loan(w, oid, 100000 * EconUtil.S, 0, true)
	var lid := ""
	for k in EconUtil.sorted_keys(w.table("loan")):
		if w.table("loan")[k]["borrower"] == oid:
			lid = k
	var p0 := int(w.table("loan")[lid]["principal"])
	var t0 := int(w.table("loan")[lid]["term_left"])
	EconMoney.reschedule(w, oid)
	check_eq(int(w.table("loan")[lid]["principal"]), p0, "no write-down")
	check_eq(int(w.table("loan")[lid]["term_left"]), t0 + EconMoney.RESCHEDULE_M, "a longer term")
	check(int(w.table("loan")[lid]["grace_until"]) > w.month, "interest only for a while")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_pass_debt() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E152"]
	sim.run(2)
	var oid := _firm(w)
	var before := EconFinance.debt_of(w, oid)
	EconFinance.new_loan(w, oid, 100000 * EconUtil.S, 0, true)
	var total := EconFinance.debt_of(w, oid)
	EconMoney.pass_debt(w, oid, "org:coop_test", 400)
	check_eq(EconFinance.debt_of(w, "org:coop_test") + EconFinance.debt_of(w, oid), total, "debt is moved, not lost")
	check(EconFinance.debt_of(w, "org:coop_test") >= (total - before) * 4 / 10 - 2, "40% passes to the co-op")


func test_remittance_floor() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	check(EconMoney.remit_allowed(w), "off: remittance as before")
	w.meta["on"] = ["E152"]
	EconUtil.pay_upto(w, EconUtil.BANK, Ledger.EXTERNAL, w.ledger.balance(EconUtil.BANK), "TEST")
	check(not EconMoney.remit_allowed(w), "a bank below its capital floor keeps its profit")


func test_asset_line_limit() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E140", "E153"]
	sim.run(5)
	var oid := _firm(w)
	var o: Dictionary = w.table("org")[oid]
	var expect := EconMoney.stock_value(w, oid) * EconMoney.STOCK_PCT / 100 + EconMoney.receivables(w, oid) * EconMoney.RECV_PCT / 100 \
		+ int(EconMoney.REV_M * float(EconAnnual.avg_rev(o)))
	check_eq(EconAnnual.limit(w, o), expect, "line = stock + receivables + a month of sales")
	# no profit test: a loss-making year still has a line
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 50000 * EconUtil.S
		pl["wages"] = 90000 * EconUtil.S
		ring.append(pl)
	o["pl_ring"] = ring
	check(EconAnnual.limit(w, o) > 0, "a loss-making firm still gets working capital against what it owns")
	w.meta["on"] = ["E140"]
	check(EconAnnual.limit(w, o) > 0, "E140 (user 2026-11-16): a loss-making year alone no longer closes the line")
	var bad_l := w.new_id("loan")
	w.table("loan")[bad_l] = {"id": bad_l, "borrower": o["id"], "principal": 1000 * EconUtil.S, "rate_ppm": 6000, "term_left": 12, "missed": 1}
	check_eq(EconAnnual.limit(w, o), 0, "the borrower's record does: a missed payment, no line")
	w.table("loan").erase(bad_l)
	var cpw: Dictionary = w.table("org")[EconFinance.org_by_key(w, "CPW")]
	w.meta["on"] = ["E140", "E153"]
	check(EconAnnual.applies(w, cpw), "public enterprises get lines under E153")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E140", "E148", "E152", "E153", "E154"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
