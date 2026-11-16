extends TestCase
## R8_FORECAST2: a newcomer's first year forecast just under the going price, by its capacity's share of the filled
## market, with the crew for its volume; and family firms out of the founding count.

const S := EconUtil.S


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


## A cleared CONSUMER market at four times the workshop's cost: everything ordered was bought.
func _cleared(w: WorldState) -> void:
	var s := EconUtil.st(w)
	var uc := FirmAI.unit_cost(w, "CONSUMERF")
	s["prices"]["CONSUMER"] = int(uc * 4.0)
	s["market_stats"]["CONSUMER"] = {"S": 3000 * S, "D": 2000 * S, "wanted": 2000 * S, "filled": 2000 * S}
	s["fill_last"] = {}
	s["r8"]["goods"]["CONSUMER"] = {"d:1": {"w": 2000 * S, "f": 2000 * S, "u": 0, "hf": 0, "hr": 0}}  # all bought, nothing left over


func test_off_the_old_forecast() -> void:
	var sim := _sim([], 6)
	var w := sim.world
	_cleared(w)
	var a := EconForecast.first_year(w, "CONSUMERF", "d:1")
	w.meta["on"].append("R8_FORECAST2")
	w.meta["off"] = ["R8_FORECAST2"]
	var b := EconForecast.first_year(w, "CONSUMERF", "d:1")
	check_eq(int(a["profit"]), int(b["profit"]), "meta off wins: the old forecast")


func test_a_market_at_four_times_cost_shows_a_profit() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	_cleared(w)
	var fc := EconForecast.first_year(w, "CONSUMERF", "d:1")
	check(int(fc["profit"]) > 0, "a cleared market at 4× cost: a newcomer would profit (%dk)" % [int(fc["profit"]) / S / 1000])
	check(int(fc["volume"]) > 0, "it takes a share of what buyers bought")
	w.meta["on"].erase("R8_FORECAST2")
	var old := EconForecast.first_year(w, "CONSUMERF", "d:1")
	check(int(fc["profit"]) > int(old["profit"]), "more than the old forecast (%dk vs %dk)" % [int(fc["profit"]) / S / 1000, int(old["profit"]) / S / 1000])


func test_price_just_under_the_going_price() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	_cleared(w)
	var fc := EconForecast.first_year(w, "CONSUMERF", "d:1")
	var p := float(EconUtil.st(w)["prices"]["CONSUMER"]) * (1.0 - float(EconForecast.UNDERCUT_PM) / 1000.0)
	var expect := float(int(fc["volume"])) / float(S) * p * 12.0
	check(absf(float(int(fc["revenue"])) - expect) <= 12.0 * float(S), "revenue at the undercut price")


func test_capacity_being_built_counts_as_competition() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	_cleared(w)
	var a := int(EconForecast.first_year(w, "CONSUMERF", "d:1")["volume"])
	for i in 3:
		var pid := EconConstruction.create(w, "CONSUMERF", "d:1", "gov", "gov", "")
		w.table("project")[pid]["status"] = "ACTIVE"
	var b := int(EconForecast.first_year(w, "CONSUMERF", "d:1")["volume"])
	check(b < a, "three workshops being built shrink a newcomer's share (%d → %d)" % [a / S, b / S])


func test_a_breakeven_market_still_says_no() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	_cleared(w)
	EconUtil.st(w)["prices"]["CONSUMER"] = int(FirmAI.unit_cost(w, "CONSUMERF") * 0.8)
	var fc := EconForecast.first_year(w, "CONSUMERF", "d:1")
	check(int(fc["profit"]) <= 0, "below cost: no profit, no founding")


func test_the_average_work_not_the_leftovers() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	_cleared(w)
	var r: Dictionary = EconData.RECIPES["CONSUMERF"]
	var cap := float(r["out"][1]) * float(S)
	var inc := EconForecast._incumbent_cap(w, "CONSUMERF", r, "")
	var expect := 2000.0 * float(S) * cap / (inc + cap)
	check(absf(EconForecast.share_of_work(w, "CONSUMERF", "d:1") - expect) <= 1.0, "every order in reach × its capacity ÷ everyone's capacity")
	check(EconForecast.share_of_work(w, "CONSUMERF", "d:1") > 0.0, "work although nothing was left unfilled")
	check(absf(EconForecast.share_of_work(w, "CONSUMERF", "d:1", -1.0, "", 900.0 * S) - 900.0 * S * cap / (inc + cap)) <= 1.0, "a sector's own demand figure replaces the reading")
	var fc := EconForecast.first_year(w, "CONSUMERF", "d:1")
	check(not (fc["reasons"] as Array).has("competitors"), "no leftovers test")


func test_a_sector_may_count_the_incumbents_in_its_own_reach() -> void:
	var sim := _sim(["R8_FORECAST2"], 6)
	var w := sim.world
	var cap := float(EconData.RECIPES["SERVICEHUB"]["out"][1]) * float(S)
	check(absf(EconForecast.share_of_work(w, "SERVICEHUB", "d:3", -1.0, "", 400.0 * S, 3.0 * cap) - 100.0 * S) <= 1.0, "400 of work, 3 incumbents' capacity near it and itself: a quarter")
	var colony := EconForecast.share_of_work(w, "SERVICEHUB", "d:3", -1.0, "", 400.0 * S)
	check(colony <= 100.0 * S, "without inc: every hub of the colony counts (%d)" % [int(colony / S)])
