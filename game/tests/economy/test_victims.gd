extends TestCase
## The victim fund pays out to households (EconVictims, opt-in with CONDUCT): a sixth of the balance a month, to the
## award's districts or else the poorer half; awards marked paid; ledger closed.


func _seed_fund(w: WorldState, amount: int, scope: Dictionary) -> void:
	if not w.ledger.has_account(EconVictims.FUND):
		w.ledger.open_account(EconVictims.FUND)
	w.ledger.transfer(EconUtil.TREASURY, EconVictims.FUND, amount, "TEST", w.month)
	var id := w.new_id("award")
	w.table("victim_award")[id] = {"id": id, "crisis": "", "scope": scope, "amount": amount, "paid_out": 0, "status": "OPEN", "month": w.month}


func test_off_without_conduct() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	_seed_fund(sim.world, 6000000, {})
	sim.run(2)
	check_eq(sim.world.ledger.balance(EconVictims.FUND), 6000000, "the fund waits while CONDUCT is off")


func test_fund_pays_the_named_district() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["CONDUCT"]
	sim.run(2)
	var d: String = EconUtil.sorted_keys(w.table("district"))[0]
	var before := {}
	for gid in w.table("hh"):
		before[gid] = w.ledger.balance(EconUtil.hh_acct(gid))
	_seed_fund(w, 60000000, {"districts": [d]})
	EconVictims.monthly(w)
	var bal := w.ledger.balance(EconVictims.FUND)
	check(bal < 60000000 and bal >= 49000000, "about a sixth went out: %d left" % bal)
	var outside := 0
	var inside := 0
	for gid in w.table("hh"):
		var gain := w.ledger.balance(EconUtil.hh_acct(gid)) - int(before[gid])
		if w.table("hh")[gid]["district"] == d:
			inside += gain
		else:
			outside += gain
	check(inside > 0 and outside == 0, "only the named district was paid (in %d, out %d)" % [inside, outside])
	for i in 80:
		EconVictims.monthly(w)
	check(w.ledger.balance(EconVictims.FUND) == 0, "the fund drains: %d" % w.ledger.balance(EconVictims.FUND))
	for aid in w.table("victim_award"):
		check_eq(String(w.table("victim_award")[aid]["status"]), "PAID", "the award is paid")
	check_eq(w.ledger.total(), 0, "ledger closed")
