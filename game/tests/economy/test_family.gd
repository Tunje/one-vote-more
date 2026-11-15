extends TestCase
## E160 / E162 family farms and bakeries (EconFamily, opt-in): off by default; grant programmes open and end; grant
## loans are repaid from the surplus and default only after LOAN_DEFAULT_M months with nothing paid; runs close.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(12)
	var w := sim.world
	for oid in w.table("org"):
		check(not bool(w.table("org")[oid].get("family", false)), "no family firms when off")
	check(not EconUtil.st(w).has("lever_need"), "no need signal when off")
	check(not EconUtil.st(w).has("fam_prog"), "no programmes when off")


func test_programme_opens_and_ends() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(2)
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	sim.run(1)
	check(EconFamily.prog_open(w, "FAMFARM"), "raising the grant from 0 opens a programme")
	var n_end := w.facts.query("ECON_GRANT_PROGRAMME_ENDED").size()
	sim.run(EconFamily.PROG_M + 1)
	check(not EconFamily.prog_open(w, "FAMFARM"), "the window closes after PROG_M months")
	check_eq(int(w.levers["ECON_FAMILY_FARM_GRANT"]), 0, "the lever goes back to 0 by itself")
	check_eq(w.facts.query("ECON_GRANT_PROGRAMME_ENDED").size(), n_end + 1, "a public fact reports the programme")
	check_eq(w.ledger.total(), 0, "ledger closed")


func _family_firm(w: WorldState) -> String:
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	var id := w.new_id("org")
	w.table("org")[id] = {"id": id, "key": "FAM_" + id, "name": "Test & Family", "type": "PRIVATE", "hq": "d:1", "status": "ACTIVE",
		"ceo": {"mgmt": 45, "risk": 25, "age_m": 456}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"family": true, "family_type": "FAMFARM"}
	w.ledger.open_account(EconUtil.acct(id))
	EconFinance.new_loan(w, id, 20000 * EconUtil.S, 0, true)
	for lid in w.table("loan"):
		if w.table("loan")[lid]["borrower"] == id:
			w.table("loan")[lid]["family"] = true
			w.table("loan")[lid]["zero_m"] = 0
			w.table("loan")[lid]["term_left"] = EconFamily.LOAN_TERM_M
	return id


func test_grant_loan_paid_from_surplus() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E160"]
	sim.run(2)
	var oid := _family_firm(w)
	var debt0 := EconFinance.debt_of(w, oid)
	EconFamily.service_loans(w)
	check(EconFinance.debt_of(w, oid) < debt0, "a surplus pays the loan down")
	# no surplus: nothing paid, interest added, no default before LOAN_DEFAULT_M months
	var acc := EconUtil.acct(oid)
	w.ledger.transfer(acc, Ledger.EXTERNAL, w.ledger.balance(acc), "TEST", w.month)
	for i in EconFamily.LOAN_DEFAULT_M - 1:
		EconFamily.service_loans(w)
	check_eq(w.table("org")[oid]["status"], "ACTIVE", "a bad stretch pays less, it is not a default")
	EconFamily.service_loans(w)
	check(w.table("org")[oid]["status"] != "ACTIVE", "12 months with nothing paid: the family has to sell")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E146", "E160", "E162"]
	sim.world.levers["ECON_FAMILY_FARM_GRANT"] = 50
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
