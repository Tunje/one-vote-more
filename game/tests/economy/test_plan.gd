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


## Rule of ours (Wilma 2026-11-16): under E165Q a material-chain job is quoted with no wait; others queue.
func test_material_chain_starts_ahead_of_the_queue() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var w := sim.world
	w.meta["on"] = ["E165", "E165B", "E165Q"]
	var b := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["type"] == "PRIVATE" and o["status"] == "ACTIVE":
			b = oid
			break
	check(b != "", "a private builder")
	if b == "":
		return
	var big := EconConstruction.create(w, "TEXTILE", "d:1", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	var bp: Dictionary = w.table("project")[big]
	bp["status"] = "ACTIVE"
	bp["contractor"] = b
	bp["price"] = int(bp["est_cost"])
	bp["start_month"] = w.month
	bp["bid_duration"] = 12
	bp["wu_total"] = 5000 * EconUtil.S  # a long book
	(w.table("org")[b]["contracts"] as Array).append(big)
	var mine := EconConstruction.create(w, "MINE", "d:1", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	var shop := EconConstruction.create(w, "SERVICEHUB", "d:1", "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	EconConstruction.bid_round(w)
	var wm := -1
	var ws := -1
	for x in w.table("project")[mine]["bids"]:
		if x["org"] == b:
			wm = int(x["wait"])
	for x in w.table("project")[shop]["bids"]:
		if x["org"] == b:
			ws = int(x["wait"])
	check_eq(wm, 0, "a mine is quoted with no wait")
	check(ws > 0, "another job waits behind the book (%d)" % ws)
	check(EconConstruction.material_chain_job(w, w.table("project")[mine]), "a mine is a material-chain job")
	check(not EconConstruction.material_chain_job(w, w.table("project")[shop]), "a service hub is not")


## The user 2026-11-16 ("PLANS ARE MADE BEFORE THEY BECOME COMPANIES"): a plan cannot fail and no count of months ends
## it; it waits for a builder, back in tender when its builder fails, and ends only by its owner's decision.
func test_plan_waits_and_ends_only_by_its_owner() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165"]
	var oid := _plan(w)
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", oid, oid, "")
	var p: Dictionary = w.table("project")[pid]
	var o: Dictionary = w.table("org")[oid]
	o["build_started"] = true
	p["status"] = "TENDERABLE"  # its builder failed: the job is back in tender
	o["forming_idle"] = 40
	o["planned_month"] = w.month - 100
	EconInsolvency._step(w, oid)
	check_eq(o["status"], "FORMING", "40 idle months, 100 months old, the job in tender: the plan waits")
	p["status"] = "CANCELLED"
	EconInsolvency._step(w, oid)
	check_eq(o["status"], "DISSOLVED", "nothing left to build: the owner withdraws it")
	check(bool(o.get("plan_abandoned", false)), "a withdrawal, not a death")
	check_eq(int(EconUtil.st(w)["plan_stats"]["abandoned_no_building"]), 1, "counted as no_building")
	check_eq(int(EconUtil.st(w)["plan_stats"]["withdrawn"]), 1, "and as withdrawn")


func test_plan_not_withdrawn_on_the_entry_signal() -> void:
	# the entry signal counts the capacity being built, the plan's own included: it says nothing about this plan
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165", "E165Q"]
	var oid := _plan(w)
	EconConstruction.create(w, "TEXTILE", "d:1", oid, oid, "")
	EconUtil.st(w)["entry_signal"] = {"TEXTILE": 0}
	check_eq(EconInsolvency.plan_withdrawal(w, oid), "", "the signal is off because the plan exists: it waits")

## The user 2026-11-16: a family's grant comes after its plan has a builder; without the money, nothing is signed.
func test_family_plan_funded_at_the_award() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165"]
	var oid := _plan(w)
	var o: Dictionary = w.table("org")[oid]
	var b := ""
	for o0 in EconUtil.sorted_keys(w.table("org")):
		if bool(w.table("org")[o0].get("is_contractor", false)) and w.table("org")[o0]["status"] == "ACTIVE":
			b = o0
			break
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", oid, oid, "")
	var p: Dictionary = w.table("project")[pid]
	p["bids"] = [{"org": b, "price": 1000 * EconUtil.S, "duration": 12, "reliability": 50, "wait": 0}]
	o["fund_on_award"] = true
	o["family_type"] = "FAMFARM"
	o["fund_gid"] = "hh:none"  # the household is gone: no money
	check(not EconConstruction.award(w, pid, b), "no money: no award")
	check_eq(p["status"], "CANCELLED", "nothing signed")
	check(not (w.table("org")[b]["contracts"] as Array).has(pid), "not in the builder's book")
	check_eq(o["status"], "DISSOLVED", "the owner withdraws")
	check_eq(int(EconUtil.st(w)["plan_stats"]["abandoned_no_funding"]), 1, "as no_funding")


## The plan's credit follows its contract: asked at the award for the accepted price, not the base-price estimate.
func test_plan_credit_follows_the_contract() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.meta["on"] = ["E165", "E165B"]
	var oid := _plan(w)
	var o: Dictionary = w.table("org")[oid]
	o["plan_credit"] = 10 * EconUtil.S  # approved on an old estimate
	var b := ""
	for o0 in EconUtil.sorted_keys(w.table("org")):
		if bool(w.table("org")[o0].get("is_contractor", false)) and w.table("org")[o0]["status"] == "ACTIVE":
			b = o0
			break
	var pid := EconConstruction.create(w, "TEXTILE", "d:1", oid, oid, "")
	var p: Dictionary = w.table("project")[pid]
	var cash := w.ledger.balance(EconUtil.acct(oid))
	var price := cash + 5000 * EconUtil.S
	p["bids"] = [{"org": b, "price": price, "duration": 12, "reliability": 50, "wait": 0}]
	check(EconConstruction.award(w, pid, b), "awarded")
	check_eq(int(o["plan_credit"]) + (w.ledger.balance(EconUtil.acct(oid)) - (cash - price / 10)), price - cash,
		"the bank's share is the accepted price less the plan's cash")
	var o2 := _plan(w)
	var pid2 := EconConstruction.create(w, "TEXTILE", "d:1", o2, o2, "")
	w.table("org")[o2]["plan_credit"] = 0
	w.table("project")[pid2]["bids"] = [{"org": b, "price": 999999999 * EconUtil.S, "duration": 12, "reliability": 50, "wait": 0}]
	check(not EconConstruction.award(w, pid2, b), "the bank will not lend that much: nothing signed")
	check_eq(w.table("org")[o2]["status"], "DISSOLVED", "the owner withdraws")
