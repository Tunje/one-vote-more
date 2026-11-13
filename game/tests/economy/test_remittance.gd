extends TestCase
## A61: the bank's yearly remittance home follows LAW_BANK_RETENTION and LAW_REMITTANCE_TAX (defaults = the old 50%).


func _remit(w: WorldState, profit: int) -> Array:  # [to home world, to treasury]
	EconUtil.st(w)["bank_profit_ytd"] = profit
	w.ledger.transfer("EXTERNAL", EconUtil.BANK, profit, "TEST", w.month)
	var ext0 := w.ledger.balance("EXTERNAL")
	var tr0 := w.ledger.balance(EconUtil.TREASURY)
	EconFinance._bank_remit(w)
	return [w.ledger.balance("EXTERNAL") - ext0, w.ledger.balance(EconUtil.TREASURY) - tr0]


func test_defaults_send_half_home() -> void:
	var sim := EconSim.make_econ_only(3)
	var r := _remit(sim.world, 1000000)
	check_eq(int(r[0]), 500000, "half the profit goes home")
	check_eq(int(r[1]), 0, "no tax by default")
	check(not sim.world.facts.query("ECON_REMITTANCE").is_empty(), "the remittance is a public fact")


func test_retention_and_tax() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.levers["LAW_BANK_RETENTION"] = 80
	w.levers["LAW_REMITTANCE_TAX"] = 50
	var r := _remit(w, 1000000)
	check_eq(int(r[0]), 100000, "20% leaves, half of it taxed: 10% goes home")
	check_eq(int(r[1]), 100000, "the other 10% goes to the treasury")
	check_eq(w.ledger.total(), 0, "ledger closed")
