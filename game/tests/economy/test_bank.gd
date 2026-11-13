extends TestCase
## M2 (EconBank, opt-in "M2"): the bank lends beyond its cash (credit creation) within its capital limit; losses shrink
## the room; a bank with no capital fails and lends nothing until a bailout; the ledger stays closed.


func _drain_bank(w: WorldState) -> void:
	var cash := w.ledger.balance(EconUtil.BANK)
	if cash > 0:
		w.ledger.transfer(EconUtil.BANK, EconUtil.TREASURY, cash, "TEST", w.month)


func test_off_lends_only_cash() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	_drain_bank(w)
	var oid: String = EconUtil.sorted_keys(w.table("org"))[0]
	check(not EconFinance.new_loan(w, oid, 1000000, 0, true), "without M2 an empty bank cannot lend")


func test_credit_creation_failure_and_bailout() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["M2"]
	sim.run(2)
	var cap0 := EconBank.capital(w)
	_drain_bank(w)  # the cash moves out, so capital falls by it too: put it back as capital via a bailout below
	EconBank.bailout(w, cap0)
	var oid: String = EconUtil.sorted_keys(w.table("org"))[0]
	var dep0 := EconBank.deposits(w)
	check(EconFinance.new_loan(w, oid, 1000000, 0, true), "with M2 the bank lends beyond its cash")
	check(w.ledger.balance(EconUtil.BANK) < 0 or EconBank.deposits(w) > dep0, "the loan created deposits")
	check(not w.facts.query("ECON_BANK_BAILOUT").is_empty(), "the bailout makes news")
	# wipe out the loan book: the bank fails and stops lending
	for lid in w.table("loan"):
		w.table("loan")[lid]["principal"] = 0
	_drain_bank(w)
	w.ledger.transfer(EconUtil.BANK, EconUtil.TREASURY, 5000000, "TEST", w.month)
	EconBank.monthly(w)
	check(EconBank.capital(w) <= 0 and bool(EconUtil.st(w)["bank_failed"]), "no capital: the bank has failed")
	check(not w.facts.query("ECON_BANK_FAILURE").is_empty(), "the failure makes news")
	check(not EconFinance.new_loan(w, oid, 1000000, 0, true), "a failed bank lends nothing")
	EconBank.bailout(w, 20000000)
	check(not bool(EconUtil.st(w)["bank_failed"]) and EconBank.room(w) > 0, "a bailout restores lending")
	check_eq(w.ledger.total(), 0, "ledger closed")
