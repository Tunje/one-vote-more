extends TestCase
## E148 correction (Otto): a builder's material order counts its supplier-credit room when it is sized
## (EconConstruction.contractor_plans), limited to what its signed, active jobs need.

const S := EconUtil.S


func _sim(on: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = on
	sim.run(6)
	return sim


func _builder(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"] and EconCredit.trades_on_account(w, oid):
			return oid
	return ""


## A started, paid-up job for builder `b`; its cash drained; returns the builder's MATERIAL order qty after planning.
func _order(w: WorldState, b: String) -> int:
	var o: Dictionary = w.table("org")[b]
	var ids: Array = EconConstruction.create_lots(w, "SERVICEHUB", String(o["hq"]), "gov", "gov", "ECON_BUDGET_INFRASTRUCTURE")
	var p: Dictionary = w.table("project")[ids[0]]
	p["status"] = "ACTIVE"
	p["contractor"] = b
	p["price"] = int(p["est_cost"])
	p["start_month"] = w.month
	p["bid_duration"] = 12
	(o["contracts"] as Array).append(ids[0])
	var cash := w.ledger.balance(EconUtil.acct(b))
	if cash > 0:
		w.ledger.transfer(EconUtil.acct(b), EconUtil.TREASURY, cash, "TEST", w.month)
	for lid in w.table("loan"):
		if w.table("loan")[lid]["borrower"] == b:
			w.table("loan")[lid]["missed"] = 1  # no working-capital loan either: only the credit room is left
	var s := EconUtil.st(w)
	s["orders"] = []
	EconConstruction.contractor_plans(w)
	var q := 0
	for od in s["orders"]:
		if od["buyer"] == b and od["good"] == "MATERIAL":
			q += int(od["qty"])
	return q


func test_credit_reaches_the_order() -> void:
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.erase("E140")  # no yearly line: only the supplier credit can carry the order
	var w := _sim(on).world
	var b := _builder(w)
	check(b != "", "a builder that trades on account")
	if b == "":
		return
	var room := EconCredit.room(w, b)
	check(room > 0, "the builder has credit room (its contract sales)")
	var q := _order(w, b)
	check(q > 0, "with no cash, the order goes on account")
	var p_need := 0
	for pid in w.table("org")[b]["contracts"]:
		var p: Dictionary = w.table("project")[pid]
		if p["status"] == "ACTIVE" and int(p["start_month"]) <= w.month and int(p["unpaid_m"]) == 0:
			p_need += int(p["mat_total"])
	check(q <= p_need, "never more than its signed jobs need")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_supplier_credit_adds_to_the_order() -> void:
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.erase("E140")
	var off: Array = on.duplicate()
	off.erase("E148")
	var w1 := _sim(on).world
	var w0 := _sim(off).world
	var b1 := _builder(w1)
	var b0 := _builder(w0)
	if b1 == "" or b0 == "":
		check(false, "a builder in both worlds")
		return
	var q1 := _order(w1, b1)
	var q0 := _order(w0, b0)
	check(q1 >= q0, "supplier credit never shrinks the order (%d vs %d without)" % [q1, q0])
	check_eq(w1.ledger.total(), 0, "ledger closed")
	check_eq(w0.ledger.total(), 0, "ledger closed without E148")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = EconSim.DEFAULT_ON.duplicate()
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
