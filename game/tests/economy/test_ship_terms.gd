extends TestCase
## A61 treaty readers: EconTrade.ship_interval / ship_hold / home_tariff default to today's constants and follow
## world.values overrides (set by the home-world treaty and sanction code).


func test_defaults_match_constants() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	check_eq(EconTrade.ship_interval(w), [int(EconData.SHIP_INTERVAL[0]), int(EconData.SHIP_INTERVAL[1])], "interval default")
	check_eq(EconTrade.ship_hold(w), EconData.SHIP_CARGO, "hold default")
	check_eq(EconTrade.home_tariff(w), 0, "no home tariff by default")


func test_interval_override_sets_the_next_ship() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.values["SHIP_INTERVAL"] = [6, 6]
	var s := EconUtil.st(w)
	var before := int(s.get("ship_next", -1))
	var arrived := false
	for _m in 40:
		sim.run(1)
		if int(s.get("ship_next", -1)) != before:
			arrived = true
			# the next ship is scheduled during the arrival month; w.month has already advanced past it
			check_eq(int(s["ship_next"]) - (w.month - 1), 6, "the next ship comes after the treaty interval")
			break
	check(arrived, "a ship arrived")


func test_home_tariff_cuts_export_income() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var g: String = EconTrade.EXPORT_GOODS[0]
	var free := int(EconTrade.prices(w)[g]["net"])
	w.values["HOME_TARIFF"] = 500
	var taxed := int(EconTrade.prices(w)[g]["net"])
	check(free > 0, "the good earns something abroad (%d)" % free)
	check(taxed <= free / 2 + 1, "a 50%% home tariff halves export income (%d → %d)" % [free, taxed])
	w.values["SHIP_HOLD"] = 0
	check_eq(EconTrade.ship_hold(w), 0, "a sanction can close the hold")
