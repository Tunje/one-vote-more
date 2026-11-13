extends TestCase
## Support economy D, step 1 (EconRetail): household purchases pay a shop margin to the district's shops, which staff
## up from that revenue (opt-in "SUPPORT_D"). Jobs = people, ledger closed, goods conserved.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check_eq(EconRetail.margin_pm(sim.world, "CONSUMER"), 0, "no margin when off")
	check(EconRetail.summary(sim.world).is_empty(), "no shops when off")


func test_shops_take_a_margin_and_hire() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["SUPPORT_D"]
	sim.run(8)
	var w := sim.world
	check_eq(EconRetail.margin_pm(w, "FOOD"), 50, "a 5% grocer margin on food")
	check_eq(EconRetail.margin_pm(w, "CONSUMER"), 200, "20% on goods")
	var sm := EconRetail.summary(w)
	check(not sm.is_empty(), "district shops opened (%s)" % [sm])
	var posts := 0
	var margin := 0
	for d in sm:
		posts += int(sm[d]["posts"])
		margin += int(sm[d]["margin_ema"])
	check(margin > 0, "shops earn a margin (%d)" % margin)
	check(posts > 0, "shops employ staff (%d)" % posts)
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])
