extends TestCase
## E150 self-funding public companies (EconPublicCo, opt-in "E150"): tariffs follow costs; E44 support only from the
## voted subsidy line.


func _cpw(w: WorldState) -> Dictionary:
	return w.table("org")[EconFinance.org_by_key(w, "CPW")]


## A year of deficits: revenue 100k against costs 150k a month.
func _losing_year(o: Dictionary) -> void:
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 100000 * EconUtil.S
		pl["wages"] = 150000 * EconUtil.S
		ring.append(pl)
	o["pl_ring"] = ring


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	_losing_year(_cpw(w))
	var e0 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	EconPublicCo.quarterly(w)
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), e0, "no tariff change when off")
	check_eq(EconPublicCo.support_cap(w), -1, "old support cap when off")


func test_deficit_raises_tariffs() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E150"]
	sim.run(2)
	w.levers["ECON_BUDGET_SUBSIDIES"] = 0
	_losing_year(_cpw(w))
	var e0 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	var w0 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_WATER", 20))
	EconPublicCo.quarterly(w)
	check(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)) > e0, "energy tariff up")
	check(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_WATER", 20)) > w0, "water tariff up")
	check(not w.facts.query("ECON_TARIFF_CHANGE").is_empty(), "a tariff fact")
	# a voted subsidy that covers the gap: no rise
	w.levers["ECON_BUDGET_SUBSIDIES"] = 3000
	var e1 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	EconPublicCo.quarterly(w)
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), e1, "the subsidy line covers it: tariffs stay")


func test_support_only_from_the_voted_line() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E150"]
	sim.run(2)
	w.levers["ECON_BUDGET_SUBSIDIES"] = 0
	var oid := EconFinance.org_by_key(w, "CPW")
	EconUtil.pay_upto(w, EconUtil.acct(oid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.acct(oid)), "TEST")
	EconInsolvency._pe_support(w, oid)
	check_eq(w.ledger.balance(EconUtil.acct(oid)), 0, "no vote, no automatic support (no payroll lifeline)")
	w.levers["ECON_BUDGET_SUBSIDIES"] = 3000
	EconInsolvency._pe_support(w, oid)
	check(w.ledger.balance(EconUtil.acct(oid)) > 0, "a voted subsidy line pays")
	check_eq(w.ledger.total(), 0, "ledger closed")


## E150P: a rise is only proposed; the government approves it with ECON_APPROVE_TARIFF.
func test_proposal_and_approval() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E150", "E150P"]
	sim.run(2)
	w.levers["ECON_BUDGET_SUBSIDIES"] = 0
	_losing_year(_cpw(w))
	var oid := EconFinance.org_by_key(w, "CPW")
	var e0 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	EconPublicCo.quarterly(w)
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), e0, "no rise without approval")
	check(EconPublicCo.pending(w).has(oid), "a proposal waits")
	check(not w.facts.query("ECON_PE_FUNDING_REQUEST").is_empty(), "the company files its request")
	check(EconActions.validate(w, "ECON_APPROVE_TARIFF", {"org": "nobody"}) != "", "no proposal, no approval")
	var r := EconActions.enqueue(w, "ECON_APPROVE_TARIFF", {"org": oid})
	check(bool(r["ok"]), "approval queued: %s" % r["error"])
	sim.run(1)
	check(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)) > e0, "approved: the tariff rises")
	var approved := false
	for f in w.facts.query("ECON_TARIFF_CHANGE"):
		if bool(f.get("data", {}).get("approved", false)):
			approved = true
	check(approved, "the approval is news (a later quarter may already file the next proposal)")


## The computer government answers a tariff proposal (GovBuilder._tariff_proposals): a market-minded government at
## once, an egalitarian state-minded one only after the proposal has waited.
func test_government_answers_a_proposal() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E150", "E150P"]
	sim.run(2)
	w.levers["ECON_BUDGET_SUBSIDIES"] = 0
	_losing_year(_cpw(w))
	var oid := EconFinance.org_by_key(w, "CPW")
	EconPublicCo.quarterly(w)
	check(EconPublicCo.pending(w).has(oid), "a proposal waits")
	var q0: int = (EconUtil.st(w)["queue"] as Array).size()
	GovBuilder._tariff_proposals(w, 0.8, 0.8)
	check_eq((EconUtil.st(w)["queue"] as Array).size(), q0, "a reluctant government does not approve a fresh proposal")
	EconPublicCo.quarterly(w)
	check_eq(int(EconPublicCo.pending(w)[oid]["since"]), int(EconPublicCo.pending(w)[oid]["month"]), "same month: since = month")
	EconPublicCo.pending(w)[oid]["since"] = w.month - 12
	EconPublicCo.quarterly(w)
	check_eq(int(EconPublicCo.pending(w)[oid]["since"]), w.month - 12, "a repeated proposal keeps the month it was first made")
	GovBuilder._tariff_proposals(w, 0.8, 0.8)
	check_eq((EconUtil.st(w)["queue"] as Array).size(), q0 + 1, "after a year of waiting the same government approves")
	(EconUtil.st(w)["queue"] as Array).pop_back()
	EconPublicCo.pending(w)[oid]["since"] = w.month
	GovBuilder._tariff_proposals(w, -0.5, -0.5)
	check_eq((EconUtil.st(w)["queue"] as Array).size(), q0 + 1, "a market-minded government approves at once")
	var e0 := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	sim.run(1)
	check(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)) > e0, "and the tariff rises")
