extends TestCase
## E135: a restructured firm's due liabilities go on a payment plan; a third administration within 36 months ends the
## workouts (liquidation instead of an endless insolvency loop).


func test_payment_plan_and_zombie_rule() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	var oid := ""
	for o in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[o]["type"] == "PRIVATE":
			oid = o
			break
	check(oid != "", "a private firm exists")
	var lid := w.new_id("liability")
	w.table("liability")[lid] = {"id": lid, "debtor": oid, "creditor": "gov", "kind": "FINE", "amount": 5000000, "status": "OPEN", "due_month": w.month}
	EconInsolvency._payment_plan(w, oid)
	check_eq(int(w.table("liability")[lid]["due_month"]), w.month + EconInsolvency.PLAN_M, "the fine is rescheduled, not forgiven")
	check_eq(int(w.table("liability")[lid]["amount"]), 5000000, "the amount stays")
	EconInsolvency._enter_administration(w, oid)
	check(not bool(w.table("org")[oid]["no_workout"]), "a first administration may end in a workout")
	w.month += 10
	EconInsolvency._enter_administration(w, oid)
	w.month += 10
	EconInsolvency._enter_administration(w, oid)
	check(bool(w.table("org")[oid]["no_workout"]), "the third within 36 months: no more workouts")
	w.month += 40
	EconInsolvency._enter_administration(w, oid)
	check(not bool(w.table("org")[oid]["no_workout"]), "old administrations age out")
