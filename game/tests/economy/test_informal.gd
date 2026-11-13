extends TestCase
## S7: above the doubling-up ceiling households build shacks; with no land or material they are homeless; when homes
## are free again the shacks empty; homeless families (workers too) leave on the ship. Jobs = people, ledger closed.


func _squeeze(w: WorldState, d: String, scale: int) -> void:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "HOUSING" and f["district"] == d:
			f["scale"] = scale


func _crowded(w: WorldState) -> String:
	var best := ""
	var best_hh := 0
	for d in EconUtil.sorted_keys(w.table("district")):
		var hh := int(w.table("district")[d].get("households", 0))
		if hh > best_hh:
			best_hh = hh
			best = d
	return best


func test_shacks_appear_above_the_ceiling_and_empty_again() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["S7"]  # S7 is opt-in for now
	sim.run(2)
	var w := sim.world
	var d := _crowded(w)
	_squeeze(w, d, 250)  # three quarters of the district's homes gone
	sim.run(6)
	var dr: Dictionary = w.table("district")[d]
	check(int(dr["households"]) > int(dr["units"]) * EconInformal.OCC_CAP / 1000, "the district is past the ceiling")
	check(EconInformal.shacks(w, d) > 0, "households put up shacks (%d)" % [EconInformal.shacks(w, d) / EconUtil.S])
	check(not w.facts.query("ECON_SHANTYTOWN").is_empty(), "a shantytown makes news")
	check(EconInformal.shack_share(w, d) > 0.0, "indicator input: shack share %.2f" % EconInformal.shack_share(w, d))
	check(w.indicators.values.has("ECON_INFORMAL_HOUSING"), "informal housing indicator published")
	var peak := EconInformal.shacks(w, d)
	_squeeze(w, d, 1000)
	sim.run(12)
	check(EconInformal.shacks(w, d) < peak, "homes free again: shacks are abandoned (%d → %d)" % [peak / EconUtil.S, EconInformal.shacks(w, d) / EconUtil.S])
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_no_material_means_homeless_and_families_leave() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = ["S7"]  # S7 is opt-in for now
	sim.run(2)
	var w := sim.world
	var d := _crowded(w)
	_squeeze(w, d, 250)
	w.meta["s7_no_material"] = true  # no scrap material anywhere: nobody can build a shack
	sim.run(3)
	check_eq(EconInformal.shacks(w, d), 0, "no material, no shacks")
	check(EconInformal.homeless(w, d) > 0, "households are homeless (%d)" % [EconInformal.homeless(w, d) / EconUtil.S])
	check(not w.facts.query("ECON_HOMELESSNESS").is_empty(), "homelessness makes news")
	var pop0 := PopStore.total(w)
	var emp0 := PopStore.count(w, {"status": "EMPLOYED"})
	var left := EconCohorts._homeless_leave(w, 0.3)
	EconPop.sync(w)
	check(left > 0, "homeless families leave (%d)" % left)
	check_eq(PopStore.total(w), pop0 - left, "they depart from the population")
	check(PopStore.count(w, {"status": "EMPLOYED"}) < emp0, "workers among them quit their jobs")
	check(EconPop.check(w).is_empty(), "jobs still equal people: %s" % [EconPop.check(w)])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_switch_off_changes_nothing() -> void:
	var sim := EconSim.make_econ_only(3)  # default: S7 not switched on
	sim.run(2)
	var w := sim.world
	var d := _crowded(w)
	_squeeze(w, d, 250)
	sim.run(4)
	check_eq(EconInformal.shacks(w, d), 0, "S7 off: no shacks")
	check_eq(EconInformal.homeless(w, d), 0, "S7 off: no homeless count")
