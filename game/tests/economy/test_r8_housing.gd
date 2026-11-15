extends TestCase
## R8 step 8, housing (EconRulesHousing, opt-in R8 + R8_HOUSING): developers build on rent and profit.

const S := EconUtil.S


func _sim(on: Array) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	sim.world.meta["on"] = on
	return sim


## Sets a district's households, homes and private rent (what EconHouseholds._housing would have measured).
func _district(w: WorldState, d: String, hh: int, units: int, rent: int) -> void:
	var dr: Dictionary = w.table("district")[d]
	dr["households"] = hh * S
	dr["units"] = units * S
	dr["occupancy"] = hh * 1000 / maxi(1, units)
	dr["rent_private"] = rent * S


func _empty_all(w: WorldState) -> void:
	for d in w.table("district"):
		_district(w, d, 0, 100, 260)


func test_switch() -> void:
	check(not EconRulesHousing.on(_sim(["R8_HOUSING"]).world), "R8_HOUSING needs R8")
	check(not EconRulesHousing.on(_sim(["R8"]).world), "R8 alone leaves housing as before")
	check(EconRulesHousing.on(_sim(["R8", "R8_HOUSING"]).world), "both: on")


func test_rent_is_the_signal() -> void:
	var w := _sim(["R8", "R8_HOUSING"]).world
	_district(w, "d:1", 300, 200, 260)
	var low := EconRulesHousing.block_forecast(w, "d:1")
	check(not bool(low["ok"]) and low["why"] == "profit", "crowded but at the starting rent a block loses money")
	_district(w, "d:1", 300, 200, 900)
	var high := EconRulesHousing.block_forecast(w, "d:1")
	check(bool(high["ok"]), "the same district at a high rent: build")
	check(int(high["profit_y"]) > int(low["profit_y"]), "profit rises with rent")
	_district(w, "d:1", 150, 200, 900)
	check_eq(String(EconRulesHousing.block_forecast(w, "d:1")["why"]), "empty", "rule 8: no block where it would stand empty")


func test_pending_counts() -> void:
	var w := _sim(["R8", "R8_HOUSING"]).world
	_district(w, "d:1", 300, 200, 900)
	var f0 := EconRulesHousing.block_forecast(w, "d:1")
	var f1 := EconRulesHousing.block_forecast(w, "d:1", 50 * S)
	check(int(f1["occ_after_pm"]) < int(f0["occ_after_pm"]), "a block planned this round counts")
	var p0 := EconRulesHousing.pending_units(w, "d:1")
	EconConstruction.create_lots(w, "HOUSING", "d:1", "gov", "gov", "ECON_BUDGET_HOUSING")
	check(EconRulesHousing.pending_units(w, "d:1") - p0 >= 49 * S, "a block being built counts as homes coming")


func test_developers_build_where_it_pays() -> void:
	var w := _sim(["R8", "R8_HOUSING"]).world
	_empty_all(w)
	_district(w, "d:2", 400, 200, 900)
	_district(w, "d:3", 400, 200, 600)
	var before: Array = w.table("project").keys()
	var n0 := before.size()
	EconRulesHousing.developers(w)
	var by_d := {}
	for pid in w.table("project"):
		var p: Dictionary = w.table("project")[pid]
		if p["type"] == "HOUSING" and not before.has(pid):
			by_d[p["district"]] = int(by_d.get(p["district"], 0)) + 1
	check(w.table("project").size() > n0, "blocks tendered")
	check(int(by_d.get("d:2", 0)) >= int(by_d.get("d:3", 0)), "the dearer district first")
	check(not by_d.has("d:1"), "none where it doesn't pay")
	check(int(EconUtil.st(w)["r8h_stats"]["blocks"]) <= EconRulesHousing.MAX_BLOCKS_Q, "at most MAX_BLOCKS_Q a round")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_no_developer_without_a_loan() -> void:
	var w := _sim(["R8", "R8_HOUSING"]).world
	_empty_all(w)
	_district(w, "d:2", 400, 200, 900)
	var orgs0: int = w.table("org").size()
	var keep := w.ledger.balance(EconUtil.BANK) - EconData.BANK_MIN_CASH * EconUtil.S
	if not EconBank.active(w) and keep > 0:
		w.ledger.transfer(EconUtil.BANK, EconUtil.TREASURY, keep, "TEST", w.month)  # the bank has nothing to lend
	var before: Array = w.table("project").keys()
	EconRulesHousing.developers(w)
	var made := 0
	for pid in w.table("project"):
		if not before.has(pid):
			made += 1
	check_eq(made, 0, "no block without a loan")
	check_eq(w.table("org").size(), orgs0, "no developer founded for a block the bank won't finance")
	check(int(EconUtil.st(w)["r8h_stats"].get("no_loan", 0)) >= 1, "counted as no_loan")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_run_closes() -> void:
	var sim := EconSim.make_econ_only(5)
	sim.world.meta["on"] = ["R8", "R8_HOUSING"]
	sim.run(36)
	check_eq(sim.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(sim.world).is_empty(), "jobs equal people")
