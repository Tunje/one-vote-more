extends TestCase
## Part C (EconBizSvc, opt-in "SUPPORT_C"): organisations pay a per-worker fee to their district's business-services
## firm, which employs cleaners, caterers and couriers from it; the fee rides on unit costs; ledger and jobs closed.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check_eq(EconBizSvc.cost_factor(sim.world), 1.0, "no fee when off")
	check(EconBizSvc.summary(sim.world)["colony"]["posts"] == 0, "no service firms when off")


func test_fees_buy_jobs() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_C"]
	sim.run(18)
	check(EconBizSvc.PROFIT_ONLY or EconBizSvc.cost_factor(w) > 1.0, "the fee is in unit costs unless bought from profit")
	var sm := EconBizSvc.summary(w)
	check(int(sm["colony"]["posts"]) > 0, "service workers employed: %s" % [sm])
	var dead := 0
	for oid in w.table("org"):
		var o: Dictionary = w.table("org")[oid]
		if String(o["key"]).begins_with("BIZSVC|") and o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			dead += 1
	check_eq(dead, 0, "the service firms stay solvent")
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])
