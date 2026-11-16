extends TestCase
## R8 utilities (EconRulesUtil, opt-in R8 + R8_UTILITIES; Anni): CPW's eight rules on its own market.

const S := EconUtil.S


func _sim(flags: Array = ["R8", "R8_UTILITIES"], months: int = 4) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	sim.world.meta["on"] = flags
	sim.run(months)
	return sim


func _row(dem: int, cap: int, unserved: int = 0, bill: int = 1000, cost: int = 1000) -> Dictionary:
	return {"m": 0, "dem": dem, "sup": dem - unserved, "cap": cap, "unserved": unserved, "served": dem - unserved,
		"billed": dem - unserved, "bill": bill, "cost": cost}


func _hist(w: WorldState, g: String, rows: Array) -> Dictionary:
	var u: Dictionary = EconUtil.st(w).get("r8u", {"hist": {}, "acts": [], "entry": {}})
	u["hist"][g] = rows
	EconUtil.st(w)["r8u"] = u
	return u


func _cpw(w: WorldState) -> String:
	return EconFinance.org_by_key(w, "CPW")


func _fund(w: WorldState, amt: int) -> void:
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(_cpw(w)), amt, "TEST", w.month)


func _plants(w: WorldState, ftype: String) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == ftype:
			out.append(fid)
	return out


func _projects(w: WorldState, ptype: String) -> int:
	var n := 0
	for pid in w.table("project"):
		if w.table("project")[pid]["type"] == ptype:
			n += 1
	return n


func test_off_without_switch() -> void:
	var sim := _sim(["R8"])
	check(not EconUtil.st(sim.world).has("r8u"), "nothing measured without R8_UTILITIES")
	check(not EconRulesUtil.capacity_on(sim.world, "POWER"), "the planners keep power")


func test_measures_the_grid() -> void:
	var sim := _sim()
	var u: Dictionary = EconUtil.st(sim.world)["r8u"]
	for g in ["E", "W"]:
		var h: Array = u["hist"][g]
		check(h.size() >= 2, "%s: months recorded" % g)
		var row: Dictionary = h[h.size() - 1]
		check(int(row["served"]) <= int(row["dem"]) and int(row["billed"]) <= int(row["served"]), "%s: billed <= served <= demand" % g)
		check(int(row["cost"]) > 0 and int(row["cap"]) > 0, "%s: cost and capacity" % g)
	check(EconRulesUtil.capacity_on(sim.world, "WATERWORKS"), "rule 5 is the utility's")


func test_output_follows_metered_demand() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var fid: String = _plants(w, "POWER")[0]
	var cap := EconRulesUtil.eff_cap(w, "POWER")
	EconUtil.st(w)["util_demand"]["E"] = int(cap / 2.0)
	check(absf(EconRulesUtil.target(w, w.table("facility")[fid]) - 0.54) < 0.01, "half the demand → 0.54 (8% over)")
	EconUtil.st(w)["util_demand"]["E"] = 0
	check(EconRulesUtil.target(w, w.table("facility")[fid]) == 0.0, "no demand → no output, no 30% floor")


func test_rise_proposed_when_cost_not_covered() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E150", "E150P"])
	var w: WorldState = sim.world
	var old := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	var rows: Array = []
	for i in 6:
		rows.append(_row(10 * S, 20 * S, 0, 1000, (old + 10) * 10 * S))  # 10 units cost (old+10) each
	var u := _hist(w, "E", rows)
	EconRulesUtil._tariffs(w, _cpw(w), u)
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), old, "a rise only proposed")
	var pend: Dictionary = EconPublicCo.pending(w)
	check(pend.has(_cpw(w)), "proposal filed in pe_proposals")
	var lv: Array = pend[_cpw(w)]["levers"][0]
	check_eq(int(lv[2]), mini(120, old + 10), "to the cost per unit")
	check(EconPublicCo.approve(w, _cpw(w)), "the government can approve it")
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), mini(120, old + 10), "approved")


func test_rise_applies_without_e150p() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var old := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_WATER", 20))
	var rows: Array = []
	for i in 6:
		rows.append(_row(10 * S, 10 * S, S, old * 9 * S, old * 9 * S))  # covered, but unserved at full use
	var u := _hist(w, "W", rows)
	EconRulesUtil._tariffs(w, _cpw(w), u)
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_WATER", 20)), old + 1, "scarcity step (5%%, at least 1)")


func test_cut_when_covered_and_idle() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var old := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	var rows: Array = []
	for i in 6:
		rows.append(_row(10 * S, 20 * S, 0, old * 10 * S, 5 * 10 * S))  # half used, costs 5 a unit
	var u := _hist(w, "E", rows)
	EconRulesUtil._tariffs(w, _cpw(w), u)
	var nv := int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40))
	check(nv < old and nv >= 5, "cut, not below the cost per unit (%d → %d)" % [old, nv])
	# costs at the tariff: no cut below the cost
	var rows2: Array = []
	for i in 6:
		rows2.append(_row(10 * S, 20 * S, 0, nv * 10 * S, nv * 10 * S))
	EconRulesUtil._tariffs(w, _cpw(w), _hist(w, "E", rows2))
	check_eq(int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), nv, "no cut below the cost")


func test_full_grid_expands_smallest_plant() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	_fund(w, EconConstruction.estimate("POWER"))
	var rows: Array = []
	for i in 12:
		rows.append(_row(19 * S, 20 * S))
	var u := _hist(w, "E", rows)
	var before: int = _projects(w, "EXPAND")
	check_eq(EconRulesUtil.capacity_signal(w, "E", u), "full", "full in 12 of 12")
	check(EconRulesUtil._capacity(w, _cpw(w), "E", u), "acted")
	check_eq(_projects(w, "EXPAND"), before + 1, "an extension")
	check(not EconRulesUtil._capacity(w, _cpw(w), "E", u), "one project at a time")


func test_reopens_a_mothballed_plant_first() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var ps := _plants(w, "POWER")
	if ps.size() < 2:
		w.table("facility")[ps[0]]["mothball"] = true  # a single plant: still reopens
	else:
		w.table("facility")[ps[1]]["mothball"] = true
	var rows: Array = []
	for i in 4:
		rows.append(_row(20 * S, 20 * S, S))
	var u := _hist(w, "E", rows)
	var before: int = w.table("project").size()
	check(EconRulesUtil._capacity(w, _cpw(w), "E", u), "acted")
	for fid in ps:
		check(not w.table("facility")[fid]["mothball"], "reopened %s" % fid)
	check_eq(w.table("project").size(), before, "no project needed")


func test_idle_plant_mothballed_never_the_last() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var ps := _plants(w, "WATERWORKS")
	var rows: Array = []
	for i in 12:
		rows.append(_row(S, 50 * S))
	var u := _hist(w, "W", rows)
	if ps.size() >= 2:
		EconRulesUtil._reduce(w, _cpw(w), "W", u)
		var wound := ""
		for fid in ps:
			check(not w.table("facility")[fid]["mothball"], "step 1 closes nothing")
			if w.table("facility")[fid].has("r8u_wind"):
				wound = fid
		check(wound != "", "a plant is wound down first")
		EconRulesUtil._reduce(w, _cpw(w), "W", u)
		var shut := 0
		for fid in ps:
			if w.table("facility")[fid]["mothball"]:
				shut += 1
		check_eq(shut, 1, "one idle plant mothballed")
	for i in 5:
		EconRulesUtil._reduce(w, _cpw(w), "W", u)
	var open := 0
	for fid in ps:
		if not w.table("facility")[fid]["mothball"]:
			open += 1
	check_eq(open, 1, "the last plant stays open")


func test_no_mothball_while_unserved() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var ps := _plants(w, "WATERWORKS")
	var rows: Array = []
	for i in 12:
		rows.append(_row(S, 50 * S, 1 if i == 11 else 0))
	EconRulesUtil._reduce(w, _cpw(w), "W", _hist(w, "W", rows))
	for fid in ps:
		check(not w.table("facility")[fid]["mothball"], "kept open: demand went unserved")


func test_entry_verdict_follows_the_law() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	for fid in _plants(w, "POWER"):
		w.table("facility")[fid]["scale"] = 3000
	var rows: Array = []
	for i in 12:
		rows.append(_row((20 + i) * S, 20 * S, i * S, 2000, 1000))
	var u := _hist(w, "E", rows)
	EconRulesUtil._entry(w, _cpw(w), "E", u)
	check(u["entry"]["E"]["want"], "rule 7: the incumbent cannot clear it")
	check(not u["entry"]["E"]["allowed"], "power stays public by law")
	check_eq(String(u["entry"]["E"]["why"]), "wanted_but_public_only", "recorded, nothing founded")
	var rows2: Array = []
	for i in 12:
		rows2.append(_row(10 * S, 20 * S))
	EconRulesUtil._entry(w, _cpw(w), "E", _hist(w, "E", rows2))
	check_eq(String(u["entry"]["E"]["why"]), "incumbent_spare", "rule 8: spare capacity")


func test_e150_leaves_cpw_to_the_rules() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E150"], 13)
	var e150_cpw := 0
	for fact in sim.world.facts.query("ECON_TARIFF_CHANGE"):
		if String(fact["data"].get("org", "")) == _cpw(sim.world) and not fact["data"].has("rule"):
			e150_cpw += 1
	check_eq(e150_cpw, 0, "E150's P&L step skips CPW")


func test_runs_two_years() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E150", "E150P"], 24)
	var u: Dictionary = EconUtil.st(sim.world)["r8u"]
	check_eq((u["hist"]["E"] as Array).size(), 12, "a year kept")
	check(PopStore.total(sim.world) > 0, "colony alive")


func test_wind_down_hands_the_load_over() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var ps := _plants(w, "POWER")
	if ps.size() < 2:
		return
	var a: Dictionary = w.table("facility")[ps[0]]
	var b: Dictionary = w.table("facility")[ps[1]]
	var dem := int(EconRulesUtil._plant_cap(w, a) * 0.5)
	EconUtil.st(w)["util_demand"]["E"] = dem
	var b_before := EconRulesUtil.target(w, b)
	a["r8u_wind"] = w.month
	for fid in ps:
		w.table("facility")[fid]["out_last"] = 0
	b["out_last"] = dem / 2
	check(EconRulesUtil.target(w, b) > b_before, "the others plan for the whole demand")
	check(EconRulesUtil.target(w, a) > 0.0, "the wound plant fills what they did not deliver")
	var rows: Array = []
	for i in 12:
		rows.append(_row(dem, 50 * S, 1 if i == 11 else 0))
	var u := _hist(w, "E", rows)
	EconRulesUtil._reduce(w, _cpw(w), "E", u)
	check(not a.has("r8u_wind") and not a["mothball"], "unserved demand: the wind-down is cancelled")
	a["r8u_wind"] = w.month
	var rows2: Array = []
	for i in 12:
		rows2.append(_row(dem, 50 * S))
	u = _hist(w, "E", rows2)
	var full_rows: Array = []
	for i in 12:
		full_rows.append(_row(20 * S, 20 * S))
	u["hist"]["E"] = full_rows
	_fund(w, EconConstruction.estimate("POWER"))
	check(EconRulesUtil._capacity(w, _cpw(w), "E", u) and not a.has("r8u_wind"), "rule 5 keeps the wound plant first")


func test_reopened_plant_ramps_up() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var ps := _plants(w, "POWER")
	if ps.size() < 2:
		return
	var a: Dictionary = w.table("facility")[ps[0]]
	var b: Dictionary = w.table("facility")[ps[1]]
	EconUtil.st(w)["util_demand"]["E"] = int(EconRulesUtil._plant_cap(w, b) * 0.5)
	var before := EconRulesUtil.target(w, b)
	a["r8u_ramp"] = w.month
	check(EconRulesUtil.target(w, b) >= before, "the others keep planning without the ramping plant")
	check(EconRulesUtil.target(w, a) > 0.0, "the ramping plant hires")
	var u: Dictionary = EconUtil.st(w)["r8u"]
	a["r8u_ramp"] = w.month - 3
	EconRulesUtil._ramps(w, u)
	check(not a.has("r8u_ramp"), "the ramp ends after a quarter")
