extends TestCase
## S7 food trap (EconFoodSec, opt-in "S7F"): the household food gap is split into SCARCE and UNAFFORDABLE; farms short
## of MATERIAL keep up by hand; under INDUSTRY_FIRST energy rationing, industry comes after farms.


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var s := EconUtil.st(sim.world)
	check(not s.has("food_unaff") and not s.has("food_scarce"), "no split unless S7F is on")
	check_eq(EconFoodSec.unaffordable_pm(sim.world, "d:1"), 0, "0 when off")
	check_eq(EconProduction._prio("CONSUMERF", false), 1, "old INDUSTRY_FIRST tier when off")


func test_split_adds_up() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["S7F"]
	for m in 24:
		sim.run(1)
		var s := EconUtil.st(w)
		var parts := int(s["food_unaff"]) + int(s["food_scarce"])
		check(absi(parts - int(s["food_shortfall"])) <= 2, "M%d: unaffordable %d + scarce %d = shortfall %d" % [m + 1,
			int(s["food_unaff"]), int(s["food_scarce"]), int(s["food_shortfall"])])
	check(w.indicators.read("ECON_FOOD_UNAFFORDABLE", "d:1", -1) >= 0.0, "the indicator is written")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_record_facts() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["S7F"]
	sim.run(1)
	while w.month % 3 != 0:
		sim.run(1)
	EconFoodSec.record(w, {"d:1": 1000000, "d:2": 1000000}, {"d:1": 300000, "d:2": 0}, {"d:1": 0, "d:2": 100000})
	var s := EconUtil.st(w)
	check_eq(int(s["food_unaff"]), 150, "colony unaffordable ‰")
	check_eq(int(s["food_scarce"]), 50, "colony scarce ‰")
	check_eq(EconFoodSec.unaffordable_pm(w, "d:1"), 300, "district unaffordable ‰")
	var ua: Array = w.facts.query("ECON_FOOD_UNAFFORDABLE")
	check(not ua.is_empty(), "unaffordable fact")
	check(not w.facts.query("ECON_FOOD_SCARCE").is_empty(), "scarce fact")
	if not ua.is_empty():
		check_eq(ua[ua.size() - 1]["location"], "d:1", "fact sits in the worst district")


func test_farm_hand_upkeep() -> void:
	var drops := {}
	for on in [false, true]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["S7F"] if on else []
		sim.run(2)
		var farm := ""
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "FARM" and not f["mothball"] and EconFoodSec.labour_fill(f) >= 0.9:
				farm = fid
				break
		check(farm != "", "a fully crewed farm")
		if farm == "":
			return
		var f2: Dictionary = w.table("facility")[farm]
		f2["condition"] = 60 * EconUtil.S
		var before := int(f2["condition"])
		for d in EconData.DISTRICTS:  # no MATERIAL anywhere for the owner
			var k := EconUtil._ikey(f2["org"], "MATERIAL", d)
			if w.table("inv").has(k):
				w.table("inv")[k]["q"] = 0
		EconProduction._upkeep(w, f2, true)
		drops[on] = before - int(f2["condition"])
	check_eq(int(drops[false]), EconUtil.S, "off: a farm with no material loses 1 point a month")
	check(int(drops[true]) < 0, "on: a full crew restores a run-down farm by hand (change %d)" % -int(drops[true]))


func test_industry_after_farms() -> void:
	check_eq(EconProduction._prio("CONSUMERF", false, true), 3, "INDUSTRY_FIRST: industry after farms under S7F")
	check(EconProduction._prio("FARM", false, true) < EconProduction._prio("CONSUMERF", false, true), "farms first")
	check_eq(EconProduction._prio("CONSUMERF", true, true), 4, "HOUSEHOLDS_FIRST unchanged")


func test_assistance_before_orders() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["S7F"]
	sim.run(3)
	for gid in w.table("hh"):  # nobody can afford food
		EconUtil.pay_upto(w, EconUtil.hh_acct(gid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.hh_acct(gid)), "TEST")
	w.levers["ECON_FOOD_ASSISTANCE"] = 0
	EconFoodSec.assist(w)
	check_eq(int(EconUtil.st(w)["food_assist_m"]), 0, "lever 0: no assistance")
	w.levers["ECON_FOOD_ASSISTANCE"] = 100
	EconFoodSec.assist(w)
	var s := EconUtil.st(w)
	check(int(s["food_assist_pm"]) > 0 and int(s["food_assist_pm"]) <= 1000, "dependence stat %d‰" % int(s["food_assist_pm"]))
	check(int(s["food_assist_m"]) > 0 and int(s["food_assist_hh"]) > 0, "assistance paid: %d to %d groups" % [int(s["food_assist_m"]), int(s["food_assist_hh"])])
	var pf := EconHouseholds.food_price_eff(w)
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		var p := EconHouseholds.persons(g)
		if p <= 0:
			continue
		var cost := EconUtil.val(int(p * EconData.NEED["FOOD"]), pf)
		check(w.ledger.balance(EconUtil.hh_acct(gid)) >= cost - 1, "%s can afford its food need" % gid)
	s["orders"] = []
	EconHouseholds._post_orders(w)
	for o in s["orders"]:
		if o["good"] == "FOOD" and o["kind"] == "hh":
			var g2: Dictionary = w.table("hh")[o["buyer"]]
			check(int(o["qty"]) >= int(EconHouseholds.persons(g2) * EconData.NEED["FOOD"]) - 1, "%s orders its full need" % o["buyer"])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_settlement_skips_e63_under_s7f() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["S7F"]
	sim.run(2)
	for gid in w.table("hh"):
		EconUtil.pay_upto(w, EconUtil.hh_acct(gid), Ledger.EXTERNAL, w.ledger.balance(EconUtil.hh_acct(gid)), "TEST")
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	EconFinance._food_assistance(w)
	check_eq(w.ledger.balance(EconUtil.TREASURY), t0, "no E63 payout in settlement under S7F")
	w.meta["on"] = []
	EconFinance._food_assistance(w)
	check(int(EconUtil.st(w)["food_assist_pm"]) > 0, "E63 records the dependence stat when S7F is off (%d‰)" % int(EconUtil.st(w)["food_assist_pm"]))


func test_surplus_drift() -> void:
	var res := {}
	for on in [false, true]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["S7F", "S7C"] if on else ["S7F"]
		sim.run(2)
		var s := EconUtil.st(w)
		var fc := EconMarket._cheapest_cost(w, "FOOD")
		check(fc > 0.0, "a farm cost")
		s["prices"]["FOOD"] = int(3.0 * fc)
		s["market_stats"]["FOOD"] = {"S": 3000 * EconUtil.S, "D": 2000 * EconUtil.S, "wanted": 2000 * EconUtil.S, "filled": 2000 * EconUtil.S}
		EconMarket._update_prices(w)
		res[on] = float(s["prices"]["FOOD"]) / (3.0 * fc)
		# scarce: no drift even with S7C
		s["prices"]["FOOD"] = int(3.0 * fc)
		s["market_stats"]["FOOD"] = {"S": 3000 * EconUtil.S, "D": 2000 * EconUtil.S, "wanted": 2000 * EconUtil.S, "filled": 1500 * EconUtil.S}
		EconMarket._update_prices(w)
		check(float(s["prices"]["FOOD"]) >= 3.0 * fc * 0.999, "S7C=%s: unfilled orders never lower the price" % on)
	check(absf(float(res[false]) - 1.0) < 0.002, "off: price held at 1.5 months' cover (%.4f)" % float(res[false]))
	check(absf(float(res[true]) - (1.0 - EconMarket.SURPLUS_DRIFT)) < 0.002, "S7C: price drifts 2%% (%.4f)" % float(res[true]))
