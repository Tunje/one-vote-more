extends TestCase
## E168 (opt-in): inside the price dead band (0–5% unfilled, under 2 months of cover) a FOOD price below the cheapest
## farm's unit cost drifts up toward that cost; nothing else changes.


func _setup(on: bool, unfilled_pm: int) -> WorldState:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	sim.run(3)
	w.meta["on"] = ["E168"] if on else []
	var s := EconUtil.st(w)
	var uc := EconMarket._cheapest_cost(w, "FOOD")
	s["prices"]["FOOD"] = int(uc * 0.6)
	var wanted := 1000 * EconUtil.S
	s["market_stats"] = {"FOOD": {"D": wanted, "S": wanted, "wanted": wanted, "filled": wanted - wanted * unfilled_pm / 1000}}
	return w


func test_drift_up_in_band() -> void:
	var w := _setup(true, 20)  # 2% unfilled: inside the band
	var p0 := int(EconUtil.st(w)["prices"]["FOOD"])
	EconMarket._update_prices(w)
	var p1 := int(EconUtil.st(w)["prices"]["FOOD"])
	check(p1 > p0, "below cost with a small shortage: the price rises (%d -> %d)" % [p0, p1])
	check(p1 <= int(float(p0) * (1.0 + EconData.ALPHA * EconMarket.DEADBAND_STEP)) + 1, "by the small step only")


func test_off_and_outside() -> void:
	var w := _setup(false, 20)
	var p0 := int(EconUtil.st(w)["prices"]["FOOD"])
	EconMarket._update_prices(w)
	check_eq(int(EconUtil.st(w)["prices"]["FOOD"]), p0, "off: the dead band freezes the price")
	var w2 := _setup(true, 0)  # every order filled: no shortage, no drift
	var q0 := int(EconUtil.st(w2)["prices"]["FOOD"])
	EconMarket._update_prices(w2)
	check_eq(int(EconUtil.st(w2)["prices"]["FOOD"]), q0, "no shortage: no drift")
	var w3 := _setup(true, 200)  # 20% unfilled: the normal famine response (full ALPHA step)
	var r0 := int(EconUtil.st(w3)["prices"]["FOOD"])
	EconMarket._update_prices(w3)
	check(int(EconUtil.st(w3)["prices"]["FOOD"]) >= int(float(r0) * (1.0 + EconData.ALPHA * 0.2)) - 1, "a real shortage still uses the full step")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["E168"]
	sim.run(24)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
