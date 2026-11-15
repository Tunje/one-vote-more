extends TestCase
## R8 step 3 (EconRulesFood, opt-in R8 + R8_FOOD): food under the eight rules.


func _sim(flags: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = flags
	return sim


func test_off_changes_nothing() -> void:
	var sim := _sim(["R8", "E160"])
	sim.run(2)
	var w := sim.world
	check_eq(EconRulesFood.hh_limit(w, "FOOD", 300, 10000000, 1000, 1.2), 300, "households keep 3 × price")
	check_eq(EconRulesFood.family_entry_block(w, "FAMFARM", "d:1"), "", "families found as before")
	check(EconRulesFood.family_full_output(w, {"family": true}), "families work at full output as before")


func test_households_bid_what_they_can_spend() -> void:
	var sim := _sim(["R8", "R8_FOOD"])
	sim.run(2)
	var w := sim.world
	var s := EconUtil.st(w)
	var pf := int(s["prices"]["FOOD"])
	var old := pf * 3
	var qty := 10 * EconUtil.S
	var lim := EconRulesFood.hh_limit(w, "FOOD", old, pf * 50, qty, 1.0)  # cash for 5 × the price per unit
	check(lim > old, "a household with money bids above 3 × price (%d > %d)" % [lim, old])
	check_eq(lim, mini(5 * pf, int(float(s["base"]["FOOD"]) * EconData.PRICE_MAX_MULT * EconMarket.wage_level(w))), "up to its cash per unit, under the ceiling")
	check_eq(EconRulesFood.hh_limit(w, "FOOD", old, pf, qty, 1.0), old, "a poor household keeps the old limit")
	check(EconRulesFood.hh_limit(w, "FOOD", 0, pf * 20, qty, 1.25) < EconRulesFood.hh_limit(w, "FOOD", 0, pf * 20, qty, 1.0), "the shop margin and tax come off what it can bid")


func test_family_asks_its_own_cost() -> void:
	var sim := _sim(["R8", "R8_FOOD", "E160"])
	sim.run(2)
	var w := sim.world
	var oid := "test_fam"
	w.table("org")[oid] = {"id": oid, "family": true, "grant_paid": 0}
	var own := EconRulesFood.family_full_cost(w, oid, "FAMFARM")
	check(own > 0.0 and own < FirmAI.unit_cost(w, "FAMFARM"), "a family's cost is below a wage-paying company's (%d < %d)" % [int(own), int(FirmAI.unit_cost(w, "FAMFARM"))])
	w.table("org")[oid]["grant_paid"] = EconConstruction.estimate("FAMFARM")
	check(EconRulesFood.family_full_cost(w, oid, "FAMFARM") < own, "a granted building is not the family's to recover")
	w.table("org").erase(oid)


func test_families_follow_sales() -> void:
	var sim := _sim(["R8", "R8_FOOD", "E160"])
	sim.run(1)
	check(not EconRulesFood.family_full_output(sim.world, {"family": true}), "with R8_FOOD a family plant follows its sales")
	sim.world.meta["on"] = ["R8", "R8_FOOD", "E160", "R8F_NOFAMOUT"]
	check(EconRulesFood.family_full_output(sim.world, {"family": true}), "the kill switch restores full output")
	check(not EconRulesFood.family_full_output(sim.world, {"family": false}), "companies are untouched")


func test_no_family_farm_while_output_covers_orders() -> void:
	var sim := _sim(["R8", "R8_FOOD", "E160"])
	sim.run(3)
	var w := sim.world
	var ms: Dictionary = EconUtil.st(w)["market_stats"]["FOOD"]
	var cap := EconRulesFood.capacity(w, "FOOD")
	var out := EconRulesFood.output(w, "FOOD")
	check(out > 0.0, "the farms produce")
	ms["D"] = int(out / 2.0)
	ms["wanted"] = int(out / 2.0)
	check_eq(EconRulesFood.family_entry_block(w, "FAMFARM", "d:1"), "covered", "the farms made twice the orders")
	ms["D"] = int(out * 2.0)
	ms["wanted"] = int(out * 2.0)
	check(EconRulesFood.family_entry_block(w, "FAMFARM", "d:1") != "covered", "orders beyond what the farms make open the door")


func test_runs_and_saves() -> void:
	var sim := _sim(["R8", "R8_FOOD", "R8_FREIGHT", "E160", "E162"])
	sim.run(24)
	check(sim.world.ledger.balance(EconUtil.TREASURY) != 0, "runs two years")


func test_food_companies_get_rules_3_to_6() -> void:
	var sim := _sim(["R8", "R8_FOOD"])
	var w := sim.world
	check(EconRulesMat.output_on(w, "FARM") and EconRulesMat.capacity_on(w, "BAKERY"), "farms and bakeries on reachable orders")
	check(not EconRulesMat.output_on(w, "FAMFARM"), "families follow their own sales instead")
	check(not EconRulesMat.output_on(w, "MINE"), "materials stay off without R8_MATERIAL")
	w.meta["on"] = ["R8", "R8_FOOD", "R8F_NOOUT"]
	check(not EconRulesMat.output_on(w, "FARM") and EconRulesMat.capacity_on(w, "FARM"), "the food kill switches act on food alone")
