extends TestCase
## E150B (opt-in with E150): a public enterprise keeps a real buffer before paying the treasury, and does not cut its
## tariffs while cash-short, after asking for money, or when its surplus went to the treasury. E150C: utility payroll
## lifeline under E150.


func _cpw(w: WorldState) -> Dictionary:
	return w.table("org")[EconFinance.org_by_key(w, "CPW")]


## A year of surpluses: revenue 200k against costs 100k a month.
func _good_year(o: Dictionary) -> void:
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 200000 * EconUtil.S
		pl["wages"] = 100000 * EconUtil.S
		ring.append(pl)
	o["pl_ring"] = ring


func _set_cash(w: WorldState, o: Dictionary, amount: int) -> void:
	var acc := EconUtil.acct(o["id"])
	var have := w.ledger.balance(acc)
	if have > amount:
		w.ledger.transfer(acc, Ledger.EXTERNAL, have - amount, "TEST", w.month)
	elif have < amount:
		w.ledger.transfer(Ledger.EXTERNAL, acc, amount - have, "TEST", w.month)


func test_keep_buffer() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E150"]
	check_eq(EconPublicCo.pe_keep(w, 1000), 1000, "E150 alone: one month, as before")
	w.meta["on"] = ["E150", "E150B"]
	check_eq(EconPublicCo.pe_keep(w, 1000), 1000 * EconPublicCo.PE_KEEP_M, "E150B: a real buffer")


func test_surplus_cuts_only_when_kept() -> void:
	for arm in ["E150", "short", "asked", "paidout", "healthy"]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["E150"] if arm == "E150" else ["E150", "E150B"]
		sim.run(2)
		var o := _cpw(w)
		_good_year(o)
		_set_cash(w, o, (100 if arm == "short" else 900000) * EconUtil.S)
		if arm == "asked":
			o["pe_req_m"] = w.month - 1
		if arm == "paidout":
			EconPublicCo.note_out(w, o["id"], 1100000 * EconUtil.S)  # the whole surplus went to the treasury
		w.levers["ECON_UTILITY_TARIFF_ENERGY"] = 40
		EconPublicCo.quarterly(w)
		var e := int(w.levers["ECON_UTILITY_TARIFF_ENERGY"])
		if arm in ["E150", "healthy"]:
			check(e < 40, "%s: a real surplus cuts the tariff" % arm)
		else:
			check_eq(e, 40, "%s: no cut" % arm)


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E150", "E150B", "E150C", "E148"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
