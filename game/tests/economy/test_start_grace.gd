extends TestCase
## E136 (opt-in): a firm still FORMING borrows interest-only for START_GRACE_M months.


func test_forming_firm_gets_grace() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E136"]
	sim.run(2)
	var oid := ""
	for o in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[o]["type"] == "PRIVATE":
			oid = o
			break
	w.table("org")[oid]["status"] = "FORMING"
	check(EconFinance.new_loan(w, oid, 1000000, 0, false), "loan booked")
	var lid := ""
	for l in EconUtil.sorted_keys(w.table("loan")):
		if w.table("loan")[l]["borrower"] == oid:
			lid = l
	check_eq(int(w.table("loan")[lid].get("grace_until", -1)), w.month + EconFinance.START_GRACE_M, "grace set for a forming firm")
	w.table("org")[oid]["status"] = "ACTIVE"
	w.ledger.transfer(EconUtil.TREASURY, EconUtil.acct(oid), 5000000, "TEST", w.month)
	var p0 := int(w.table("loan")[lid]["principal"])
	sim.run(3)
	check_eq(int(w.table("loan")[lid]["principal"]), p0, "no principal repaid in grace")
	check_eq(w.ledger.total(), 0, "ledger closed")
