extends TestCase
## §9 (EconWarehouse, opt-in "WAREHOUSE"): stock above the free buffer needs warehouse space, rented from CTA; the
## reserve pays from the reserve line; stock with no space shrinks; the halls are staffed from the rent.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	check(EconWarehouse.summary(sim.world).is_empty(), "no halls unless WAREHOUSE is on")


func test_rent_space_and_reserve() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["WAREHOUSE"]
	sim.run(3)
	var sm := EconWarehouse.summary(w)
	check(int(sm.get("halls", 0)) > 0 and int(sm.get("stored", 0)) > 0, "halls founded and stock stored: %s" % [sm])
	# the reserve has no free buffer: put 1,000 MEDICAL in it and see the reserve line pay rent
	EconUtil.inv_add(w, "gov", "MEDICAL", "d:1", 1000 * 1000, 0)
	EconUtil.qflow(w, "MEDICAL", "imported", 1000 * 1000)
	var before := int(EconUtil.st(w)["spent_ytd"].get(EconWarehouse.RESERVE_LINE, 0))
	sim.run(1)
	check(int(EconUtil.st(w)["spent_ytd"].get(EconWarehouse.RESERVE_LINE, 0)) > before, "the reserve pays storage from its line")
	sim.run(12)
	check(int(EconWarehouse.summary(w)["posts"]) > 0, "the halls have staff: %s" % [EconWarehouse.summary(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])
	check(EconPop.check(w).is_empty(), "jobs equal people: %s" % [EconPop.check(w)])


func test_no_space_shrinks() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["WAREHOUSE"]
	sim.run(2)
	var cta := EconFinance.org_by_key(w, "CTA")
	var f := EconWarehouse._site(w, cta)
	f["halls"] = 0  # the halls burned down
	EconUtil.inv_add(w, "gov", "MATERIAL", "d:1", 5000 * 1000, 0)
	EconUtil.qflow(w, "MATERIAL", "imported", 5000 * 1000)
	sim.run(1)  # (shrinkage runs before firms post their offers: calling monthly() mid-month would sell stock twice)
	var sm := EconWarehouse.summary(w)
	check(int(sm["shrunk"]) >= 150, "3%% of the unhoused stock is lost: %s" % [sm])
	check(int(EconWarehouse.summary(w)["no_space"]) > 0, "the shortage is reported")
	check(not w.facts.query("ECON_STORAGE_SHORTAGE").is_empty(), "it makes news")
	check(EconReport.goods_errors(w).is_empty(), "goods conserved: %s" % [EconReport.goods_errors(w)])
