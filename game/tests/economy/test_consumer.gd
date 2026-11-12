extends TestCase
## D2 (A42): consumer industries — household stocks that wear out, quality and reputation, the FINE tier and its
## luxury tax, workshops founded by entry.


func test_household_stock_wears_and_purchases_add() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	var g: Dictionary = w.table("hh")[gid]
	g["dur"] = {"CLOTHING": 1200 * EconUtil.S, "FURNISHINGS": 0}
	g["dur_q"] = {"CLOTHING": 50}
	g["bought"]["FURNISHINGS"] = 10 * EconUtil.S
	g["bought_q"] = {"FURNISHINGS": 80 * 10}
	EconUtil.qflow(w, "FURNISHINGS", "made", 10 * EconUtil.S)  # the bought units came from somewhere
	EconConsumer.absorb(w, g)
	check(int(g["dur"]["CLOTHING"]) < 1200 * EconUtil.S, "clothing wears out")
	check_eq(int(g["dur_worn"]["CLOTHING"]), 1200 * EconUtil.S / 24, "a 24-month life at quality 50")
	check(int(g["dur"]["FURNISHINGS"]) > 9 * EconUtil.S, "bought furnishings join the stock")
	check_eq(int(g["dur_q"]["FURNISHINGS"]), 80, "stock quality from what was bought")


func test_fine_tier_pays_luxury_tax() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	w.levers["LAW_LUXURY_TAX"] = 20
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[3]
	var g: Dictionary = w.table("hh")[gid]
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	EconConsumer.on_hh_purchase(w, g, EconUtil.hh_acct(gid), {"good": "CLOTHING", "q": 85}, 5 * EconUtil.S, 1000 * EconUtil.S)
	check(w.ledger.balance(EconUtil.TREASURY) > t0, "luxury tax on a FINE purchase")
	var t1 := w.ledger.balance(EconUtil.TREASURY)
	EconConsumer.on_hh_purchase(w, g, EconUtil.hh_acct(gid), {"good": "CLOTHING", "q": 50}, 5 * EconUtil.S, 1000 * EconUtil.S)
	check_eq(w.ledger.balance(EconUtil.TREASURY), t1, "no luxury tax on ordinary goods")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_corner_cutting_ceo_lowers_quality() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var oid := EconFinance.org_by_key(w, "HEARTH")
	var fa := EconSetup.add_facility(w, "TEXTILE", oid, "d:4", false)
	var fb := EconSetup.add_facility(w, "TEXTILE", oid, "d:4", false)
	var o: Dictionary = w.table("org")[oid]
	for i in 24:
		o["ceo"]["risk"] = 30
		w.table("facility")[fb]["quality"] = int(w.table("facility")[fa].get("quality", 40))
		EconConsumer.quality_monthly(w)
	var careful := int(w.table("facility")[fa]["quality"])
	o["ceo"]["risk"] = 90
	for i in 24:
		EconConsumer.quality_monthly(w)
	check(int(w.table("facility")[fa]["quality"]) < careful, "a corner-cutting CEO lowers quality (%d → %d)" % [careful, int(w.table("facility")[fa]["quality"])])


func test_workshops_appear_and_goods_conserved() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(72)
	var w := sim.world
	var n := 0
	for fid in w.table("facility"):
		if EconConsumer.WORKSHOPS.has(w.table("facility")[fid]["type"]):
			n += 1
	check(n > 0, "consumer workshops were founded (%d)" % n)
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	var off := EconSim.make_econ_only(3)
	off.world.meta["off"] = ["D2"]
	off.run(12)
	for o in EconUtil.st(off.world).get("orders", []):
		check(not o["good"] in EconConsumer.GOODS, "D2 off: no household orders for the new goods")
