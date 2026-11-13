extends TestCase
## Part B (EconHQ, opt-in "SUPPORT_B"): a paper's wage money employs its own newsroom; union offices are paid from
## the fund; funders get back what their offices do not need; ledger and jobs stay closed.


func test_off_routes_media_wages_to_households() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(2)
	w.ledger.open_account("media:test")
	w.ledger.transfer(EconUtil.TREASURY, "media:test", 10000000, "TEST", w.month)
	EconHouseholds.pay_media_wages(w, "media:test", 5000000, "")
	check_eq(EconHQ.org_for(w, "media:test"), "", "no newsroom unless SUPPORT_B is on")


func test_newsroom_and_union_office() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_B"]
	sim.run(2)
	w.ledger.open_account("media:test")
	w.ledger.transfer(EconUtil.TREASURY, "media:test", 200000000, "TEST", w.month)
	for m in 8:
		EconHouseholds.pay_media_wages(w, "media:test", 8000000, "")  # ~8k a month: about four journalists
		sim.run(1)
	var oid := EconHQ.org_for(w, "media:test")
	check(oid != "", "the paper has a newsroom")
	var f := EconHQ._site(w, oid)
	check(int(f.get("hq_posts", 0)) >= 2 and EconLabor.staff_total(f["staff"]) > 0, "journalists employed: %s" % [EconHQ.summary(w)])
	check(w.ledger.balance(EconUtil.acct(oid)) <= 8000000 * 3, "the newsroom keeps no hoard: %d" % w.ledger.balance(EconUtil.acct(oid)))
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])
