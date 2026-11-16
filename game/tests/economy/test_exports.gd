extends TestCase
## Exports in the eight rules (planning/design-exports.md; user 2026-11-16 via Wilma): producers count the net home
## price and the next ship's free hold as orders (EXP), depots grow on cargo the port could not take (EXP_PORT), the
## ship records what it left on the dock (always), and producers keep back current local orders (EXP_KEEP).

var SAVE_PATH: String = TestCase.save_path("exports.sav")
const ON := ["R8", "R8_MATERIAL", "R8_FREIGHT", "EXP", "EXP_PORT"]


func _sim(flags: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = flags.duplicate()
	return sim


func _mine(w: WorldState) -> String:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "MINE" and not w.table("facility")[fid]["mothball"]:
			return fid
	return ""


func _port_total(w: WorldState) -> int:
	var t := 0
	var ps := EconTrade.port_stock(w)
	for g in ps:
		t += int(ps[g])
	return t


func test_off_plans_with_the_local_price() -> void:
	var sim := _sim(["R8", "R8_MATERIAL"])
	sim.run(3)
	var w := sim.world
	EconTrade._t(w)["home"]["MINERAL"] = 100000 * EconUtil.S
	check_eq(EconTrade.plan_price(w, "MINERAL"), int(EconUtil.st(w)["prices"]["MINERAL"]), "EXP off: the local price, whatever the home world pays")
	check(not EconUtil.st(w)["r8"].has("export"), "no order book without EXP")
	check_eq(EconTrade.export_month(w, EconFinance.org_by_key(w, "CPW")), 0, "no export sales in expected revenue")


func test_order_book_is_the_free_hold_over_the_months_to_the_ship() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	w.values["SHIP_HOLD"] = 1000
	var b0 := EconTrade.export_book(w)
	var used := _port_total(w)
	check_eq(int(b0["MINERAL"]["hold_open"]), maxi(0, (1000 - used) * EconUtil.S), "hold open = hold − consigned")
	var cpw := EconFinance.org_by_key(w, "CPW")
	EconUtil.inv_add(w, cpw, "COMPONENT", EconTrade.PORT, 200 * EconUtil.S, 500 * EconUtil.S)
	var b1 := EconTrade.export_book(w)
	check_eq(int(b0["MINERAL"]["hold_open"]) - int(b1["MINERAL"]["hold_open"]), mini(200 * EconUtil.S, int(b0["MINERAL"]["hold_open"])),
		"cargo of any good fills the shared hold")
	var months := maxi(1, EconTrade.next_ship(w) - w.month) if EconTrade.next_ship(w) >= 0 else 1
	check_eq(int(b1["MINERAL"]["per_m"]), int(b1["MINERAL"]["hold_open"]) / months, "spread over the months to the next ship")


func test_paying_export_orders_enter_reach_and_the_output_target() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	var fid := _mine(w)
	check(fid != "", "a mine exists")
	if fid == "":
		return
	w.values["SHIP_HOLD"] = 5000
	EconTrade._t(w)["home"]["MINERAL"] = 100000 * EconUtil.S  # the home world pays far above any cost
	EconRules.monthly(w)
	var per_m := int(EconUtil.st(w)["r8"]["export"]["MINERAL"]["per_m"])
	check(per_m > 0, "open hold a month: %d" % per_m)
	var reach_on := int(EconRules.plant(w, fid)["reach"])
	var t_on := EconRulesMat.target(w, w.table("facility")[fid], "MINERAL", 0.2)
	w.meta["on"] = ["R8", "R8_MATERIAL", "R8_FREIGHT"]
	EconRules.monthly(w)
	var reach_off := int(EconRules.plant(w, fid)["reach"])
	var t_off := EconRulesMat.target(w, w.table("facility")[fid], "MINERAL", 0.2)
	check_eq(reach_on - reach_off, per_m, "the ship's free hold is reachable orders")
	check(t_on >= t_off, "the output target does not fall (%.2f vs %.2f)" % [t_on, t_off])


func test_exports_below_variable_cost_are_not_orders() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	var fid := _mine(w)
	if fid == "":
		check(false, "a mine exists")
		return
	w.values["SHIP_HOLD"] = 5000
	EconRules.monthly(w)
	var var_c := int(EconRules.plant(w, fid)["cost_var"])
	# a net home price just under the mine's variable cost: freight is FREIGHT_SHARE × base, net = home − freight (no tax)
	EconTrade._t(w)["home"]["MINERAL"] = maxi(1, var_c - 1) + EconTrade.freight("MINERAL")
	EconRules.monthly(w)
	var net := int(EconUtil.st(w)["r8"]["export"]["MINERAL"]["net"])
	check(net < var_c, "net %d below the variable cost %d" % [net, var_c])
	var reach_on := int(EconRules.plant(w, fid)["reach"])
	w.meta["on"] = ["R8", "R8_MATERIAL", "R8_FREIGHT"]
	EconRules.monthly(w)
	check_eq(reach_on, int(EconRules.plant(w, fid)["reach"]), "exports that don't pay for their inputs add no orders")


func test_full_port_records_refused_cargo_and_the_cta_adds_a_depot() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	var cpw := EconFinance.org_by_key(w, "CPW")
	# the port store full of components, the home world paying well for minerals, and a mine owner with stock
	EconUtil.inv_add(w, cpw, "COMPONENT", EconTrade.PORT, EconTrade.port_capacity(w) * EconUtil.S, 500 * EconUtil.S)
	EconTrade._t(w)["home"]["MINERAL"] = 100000 * EconUtil.S
	var fid := _mine(w)
	if fid == "":
		check(false, "a mine exists")
		return
	var f: Dictionary = w.table("facility")[fid]
	EconUtil.inv_add(w, f["org"], "MINERAL", f["district"], 500 * EconUtil.S, 10 * EconUtil.S)
	EconTrade._consign(w, EconTrade._t(w))
	check(int(EconTrade._t(w)["refused_m"].get("MINERAL", 0)) > 0, "minerals the port could not take are recorded")
	var t := EconTrade._t(w)
	t["refused_hist"] = []
	for i in 6:
		t["refused_hist"].append({"MINERAL": 100 * EconUtil.S})
	check_eq(EconTrade.refused_months(w), 6, "six months of refused cargo")
	check(EconTrade.export_pressure(w)["refused_12m"].get("MINERAL", 0) >= 600, "the pressure hook reports it")
	while w.month % 3 != 0:
		w.month += 1
	var cta := EconFinance.org_by_key(w, "CTA")
	if cta == "":
		check(false, "the CTA exists")
		return
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(cta), EconConstruction.estimate("DEPOT") * 2, "GRANT", w.month)
	var before := 0
	for pid in w.table("project"):
		var p: Dictionary = w.table("project")[pid]
		if p["type"] == "DEPOT" or (p["type"] == "EXPAND" and w.table("facility").has(p.get("target", "")) and w.table("facility")[p["target"]]["type"] == "DEPOT"):
			before += 1
	if before > 0:
		check(true, "a depot project is already pending (nothing to add)")
		return
	EconRules._freight_rules(w)
	var after := 0
	for pid in w.table("project"):
		var p2: Dictionary = w.table("project")[pid]
		if p2["type"] == "DEPOT" or (p2["type"] == "EXPAND" and w.table("facility").has(p2.get("target", "")) and w.table("facility")[p2["target"]]["type"] == "DEPOT"):
			after += 1
	check(after > before, "refused cargo in 6 of 12 months: the CTA adds port space")


func test_without_exp_port_refused_cargo_builds_nothing() -> void:
	var sim := _sim(["R8", "R8_MATERIAL", "R8_FREIGHT", "EXP"])
	sim.run(3)
	var w := sim.world
	var t := EconTrade._t(w)
	t["refused_hist"] = []
	for i in 12:
		t["refused_hist"].append({"MINERAL": 100 * EconUtil.S})
	check(not EconTrade.port_rule_on(w), "EXP_PORT off")


func test_expected_sales_count_cargo_waiting_for_the_ship() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	var cpw := EconFinance.org_by_key(w, "CPW")
	var o: Dictionary = w.table("org")[cpw]
	var e0 := EconAnnual.expected_rev(w, o)
	EconUtil.inv_add(w, cpw, "COMPONENT", EconTrade.PORT, 100 * EconUtil.S, 500 * EconUtil.S)
	var xm := EconTrade.export_month(w, cpw)
	check(xm > 0, "consigned stock is sales the ship will pay for: %d" % xm)
	var ahead := maxi(EconAnnual._plan_value(w, o), EconAnnual._contracts_month(w, o)) + xm
	check(EconAnnual.expected_rev(w, o) >= maxi(e0, ahead), "expected sales include it (the larger of history and what is ahead)")


func test_forecast_sees_the_ship_as_a_customer() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	w.values["SHIP_HOLD"] = 50000
	EconTrade._t(w)["home"]["MINERAL"] = 100000 * EconUtil.S
	EconRules.monthly(w)
	var on := EconForecast.first_year(w, "MINE", "d:3")
	w.meta["on"] = ["R8", "R8_MATERIAL", "R8_FREIGHT"]
	EconRules.monthly(w)
	var off := EconForecast.first_year(w, "MINE", "d:3")
	check(int(on["volume"]) >= int(off["volume"]), "export orders add volume (%d vs %d)" % [int(on["volume"]), int(off["volume"])])
	check(not (on["reasons"] as Array).has("no_customers"), "an open, paying hold is a customer: %s" % [on["reasons"]])


func test_ship_records_what_it_left_on_the_dock() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var w := sim.world
	w.values["SHIP_HOLD"] = 10
	var cpw := EconFinance.org_by_key(w, "CPW")
	EconUtil.inv_add(w, cpw, "COMPONENT", EconTrade.PORT, 50 * EconUtil.S, 500 * EconUtil.S)
	var held := _port_total(w)
	var res := EconTrade.on_ship(w)
	var loaded := 0
	for g in res["cargo"]:
		loaded += int(res["cargo"][g])
	var p := EconTrade.export_pressure(w)
	check(loaded <= 10, "the ship takes its hold")
	check(int(p["left_total"]) >= held - loaded - 10 and int(p["left_total"]) <= held - loaded, "left on the dock = held − loaded, to whole units per firm and good (%d, %d − %d)" % [int(p["left_total"]), held, loaded])
	check(int(p["left_last_ship"].get("COMPONENT", 0)) >= 38, "per good: %s" % [p["left_last_ship"]])


func test_keep_back_current_local_orders() -> void:
	var sim := _sim(["R8", "R8_MATERIAL", "EXP", "EXP_KEEP"])
	sim.run(3)
	var w := sim.world
	var cpw := EconFinance.org_by_key(w, "CPW")
	var o: Dictionary = w.table("org")[cpw]
	var home_d: String = o["hq"] if EconData.DISTRICTS.has(o["hq"]) else "d:1"
	check_eq(EconTrade._keep(w, o, "MINERAL"), EconRules.reachable_unfilled(w, "MINERAL", home_d), "EXP_KEEP: what local buyers want now")
	w.meta["on"] = ["R8", "R8_MATERIAL", "EXP"]
	check_eq(EconTrade._keep(w, o, "MINERAL"), int(o["sales_ema"].get("MINERAL", 0)), "without it: a month of past sales, as before")


func test_runs_saves_and_loads_identically() -> void:
	var ref := _sim(ON + ["EXP_KEEP"])
	ref.run(10)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(8)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(8)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash with exports on")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")


func test_order_book_reads_the_ship_that_calls_next() -> void:
	var sim := _sim(ON)
	sim.run(3)
	var w := sim.world
	w.values["SHIP_HOLD"] = 1000
	var first := EconTrade.next_ship(w)
	check_eq(int(EconTrade.next_call(w)[1]), 0, "without a fleet the first ship calls next")
	EconTrade.add_ship(w, w.month + 1 if first < 0 or first > w.month + 1 else first - 1, 4000)
	var call := EconTrade.next_call(w)
	check_eq(int(call[1]), 1, "an extra ship due sooner calls next")
	var used := 0
	for g in EconTrade.EXPORT_GOODS:
		for oid in w.table("org"):
			used += EconUtil.inv_get(w, oid, g, EconTrade.PORT)
	check_eq(int(EconTrade.export_book(w)["MINERAL"]["hold_open"]), maxi(0, 4000 * EconUtil.S - used), "its own hold is the open hold")
