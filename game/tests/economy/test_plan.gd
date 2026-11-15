extends TestCase
## E165 planning stage: a new firm is a plan until its plant opens — no loan service, it cannot fail, an abandoned plan
## repays the bank from its cash, returns the rest to the founder and is not a liquidation.


func _plan(w: WorldState) -> String:
	var id := w.new_id("org")
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	w.table("org")[id] = {"id": id, "key": "NEW_" + id, "name": "Plan Ltd", "type": "PRIVATE", "hq": "d:1", "status": "FORMING",
		"ceo": {"mgmt": 50, "risk": 50, "age_m": 480}, "reliability": 0, "is_contractor": false, "crew": {}, "crew_target": {},
		"premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0, "pl": EconFinance.empty_pl(), "pl_last": {},
		"missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0, "admin_months": 0, "liq_months": 0,
		"missed_this_month": false, "owner_group": gid, "sales_ema": {}, "contracts": [], "dividends_ytd": 0, "sold": {},
		"entry_type": "TEXTILE", "planned_month": w.month}
	w.ledger.open_account(EconUtil.acct(id))
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(id), 40000 * EconUtil.S, "TEST", w.month)
	EconFinance.new_loan(w, id, 60000 * EconUtil.S, 0, true)
	return id


func test_plan_pays_no_loan_service() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165"]
	var oid := _plan(w)
	var cash := w.ledger.balance(EconUtil.acct(oid))
	var debt := EconFinance.debt_of(w, oid)
	EconFinance._loan_service(w)
	check_eq(w.ledger.balance(EconUtil.acct(oid)), cash, "no interest, no principal while a plan")
	check_eq(EconFinance.debt_of(w, oid), debt, "the loan is untouched")
	w.meta["on"] = []
	EconFinance._loan_service(w)
	check(w.ledger.balance(EconUtil.acct(oid)) < cash, "off: the old rule services the loan from month 1")


func test_abandon_is_not_a_liquidation() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165"]
	var oid := _plan(w)
	var gid: String = w.table("org")[oid]["owner_group"]
	var hh0 := w.ledger.balance(EconUtil.hh_acct(gid))
	var bank0 := w.ledger.balance(EconUtil.BANK)
	var n_liq := w.facts.query("COMP_LIQUIDATED").size()
	EconInsolvency.abandon_plan(w, oid, "no_builder")
	var o: Dictionary = w.table("org")[oid]
	check_eq(o["status"], "DISSOLVED", "the plan is dropped")
	check(bool(o.get("plan_abandoned", false)), "marked as an abandoned plan")
	check_eq(EconFinance.debt_of(w, oid), 0, "no debt left")
	check_eq(w.ledger.balance(EconUtil.BANK) - bank0, 60000 * EconUtil.S, "the drawn loan goes back to the bank first")
	check_eq(w.ledger.balance(EconUtil.hh_acct(gid)) - hh0, 40000 * EconUtil.S, "the unspent equity goes back to the founder")
	check_eq(w.facts.query("COMP_LIQUIDATED").size(), n_liq, "not a liquidation")
	check_eq(w.facts.query("COMP_PLAN_ABANDONED").size(), 1, "a plan-abandoned fact")
	check_eq(int(EconUtil.st(w)["plan_stats"]["abandoned_no_builder"]), 1, "cause counted")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E165"]
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
	for oid in sim.world.table("org"):
		var o: Dictionary = sim.world.table("org")[oid]
		if bool(o.get("plan_abandoned", false)):
			check(not o.has("opened_month"), "an abandoned plan never opened")


func test_e165b_credit_drawn_as_paid() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165", "E165B"]
	var oid := _plan(w)
	var o: Dictionary = w.table("org")[oid]
	# _plan drew a 60k loan the old way; clear it to model a credit line instead
	for lid in w.table("loan"):
		if w.table("loan")[lid]["borrower"] == oid:
			w.ledger.transfer(EconUtil.acct(oid), EconUtil.BANK, int(w.table("loan")[lid]["principal"]), "TEST", w.month)
			w.table("loan")[lid]["principal"] = 0
	o["plan_credit"] = 60000 * EconUtil.S
	var cash := w.ledger.balance(EconUtil.acct(oid))
	EconInsolvency.draw_plan_credit(w, oid, cash + 10000 * EconUtil.S)
	check_eq(EconFinance.debt_of(w, oid), 10000 * EconUtil.S, "only the missing part is drawn")
	check_eq(int(o["plan_credit"]), 50000 * EconUtil.S, "the rest stays undrawn")
	EconInsolvency.abandon_plan(w, oid, "no_builder")
	check(not o.has("plan_credit"), "an abandoned plan's credit is closed")
	var fails: Dictionary = EconUtil.st(w).get("entry_fail", {})
	var left := FirmAI.ENTRY_FAIL_COOL_M - (w.month - int(fails.get("TEXTILE", -9999)))
	check_eq(left, EconInsolvency.NO_BUILDER_COOL_M, "a no-builder abandon cools the sector for 12 months")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_e165b_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E165", "E165B", "E155BLD"]
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")


func test_e165q_order_book() -> void:
	var sim := EconSim.make_econ_only(5)
	var w := sim.world
	w.meta["on"] = ["E165", "E165Q"]
	sim.run(48)
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people")
	check_eq(int(EconUtil.st(w).get("plan_stats", {}).get("abandoned_no_builder", 0)), 0, "no plan is dropped for want of a builder")
	# a queued job gets no work before its start
	for pid in w.table("project"):
		var p: Dictionary = w.table("project")[pid]
		if p["status"] == "ACTIVE" and int(p["start_month"]) > w.month:
			check_eq(int(p["wu_done"]), 0, "a queued job is not worked on")
			check(bool(p.get("advance_due", false)), "its advance waits for the start")
