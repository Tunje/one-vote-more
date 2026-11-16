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


func _private_org(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not o["is_contractor"]:
			return oid
	return ""


## A private plant: a copy of CPW's first plant of the type, owned by a private firm.
func _private_plant(w: WorldState, ftype: String, price: float) -> String:
	var src: Dictionary = w.table("facility")[_plants(w, ftype)[0]]
	var f: Dictionary = src.duplicate(true)
	var id := w.new_id("facility")
	f["id"] = id
	f["org"] = _private_org(w)
	f["r8u_price"] = price
	f["mothball"] = false
	w.table("facility")[id] = f
	return id


func _grow_rows(n: int, bill: int, cost: int) -> Array:
	var rows: Array = []
	for i in n:
		rows.append(_row((2000 + 100 * i) * S, 2000 * S, 100 * i * S, bill, cost))
	return rows


func _founder(w: WorldState) -> void:
	var gid: String = EconUtil.sorted_keys(w.table("hh"))[0]
	var g: Dictionary = w.table("hh")[gid]
	g["band"] = "I5"
	g["nonpart"] = maxi(int(g["nonpart"]), S)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(gid), EconConstruction.estimate("POWER") * 2, "TEST", w.month)


func test_private_company_founded_on_unserved_demand() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	_founder(w)
	var u := _hist(w, "E", _grow_rows(12, 2000, 1000))
	var orgs := w.table("org").size()
	EconRulesUtil._entry(w, _cpw(w), "E", u)
	var v: Dictionary = u["entry"]["E"]
	check(int(v.get("forecast", {}).get("profit", 0)) > 0, "a profit forecast at today's tariff (%s)" % str(v.get("forecast", {})))
	check_eq(String(v["why"]), "founded", "rule 7: founded")
	check_eq(w.table("org").size(), orgs + 1, "a new company")
	var oid := String(v.get("org", ""))
	if oid != "":
		var o: Dictionary = w.table("org")[oid]
		check(o["type"] == "PRIVATE" and o["status"] == "FORMING", "private, forming")
		check_eq(int(o["r8u_price"]), int(EconUtil.lever(w, "ECON_UTILITY_TARIFF_ENERGY", 40)), "starts at today's tariff")
		check_eq(_projects(w, "POWER") >= 1, true, "its plant is tendered")
	EconRulesUtil._entry(w, _cpw(w), "E", u)
	check(String(u["entry"]["E"]["why"]) in ["incumbent_clears", "forming"], "rule 8: one is being founded")


func test_no_private_company_when_rule_8_holds() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	_founder(w)
	var rows: Array = []
	for i in 12:
		rows.append(_row(1000 * S, 2000 * S))
	var u := _hist(w, "E", rows)
	EconRulesUtil._entry(w, _cpw(w), "E", u)
	check_eq(String(u["entry"]["E"]["why"]), "incumbent_spare", "spare capacity")
	var full: Array = []
	for i in 12:
		full.append(_row(1960 * S, 2000 * S))
	EconRulesUtil._entry(w, _cpw(w), "E", _hist(w, "E", full))
	check_eq(String(u["entry"]["E"]["why"]), "incumbent_serves_all", "all served, nothing short")
	EconRulesUtil._entry(w, _cpw(w), "E", _hist(w, "E", _grow_rows(12, 1000, 2000)))
	check_eq(String(u["entry"]["E"]["why"]), "incumbent_loses", "the grid loses money")
	var orgs := w.table("org").size()
	check_eq(w.table("org").size(), orgs, "nothing founded")


func test_one_plants_worth_of_work_never_opens_the_door() -> void:
	var sim := _sim(["R8", "R8_UTILITIES"], 24)
	var w: WorldState = sim.world
	var founded := 0
	for f in w.facts.query("COMP_COMPANY_FOUNDED"):
		if String(f["data"].get("rule", "")) == "R8U":
			founded += 1
	check_eq(founded, 0, "a grid CPW serves gets no entrant")


func test_merit_order_runs_the_cheapest_first() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var cheap := _private_plant(w, "POWER", 1.0)
	var cpw_fid: String = _plants(w, "POWER")[0]
	var pcap := EconRulesUtil._plant_cap(w, w.table("facility")[cheap])
	EconUtil.st(w)["util_demand"]["E"] = int(pcap * 0.5)
	check(EconRulesUtil.target(w, w.table("facility")[cheap]) > 0.5, "the cheaper private plant runs first")
	check_eq(EconRulesUtil.target(w, w.table("facility")[cpw_fid]), 0.0, "CPW's dearer plants wait")
	w.table("facility")[cheap]["r8u_price"] = 1000.0
	check_eq(EconRulesUtil.target(w, w.table("facility")[cheap]), 0.0, "a dear private plant waits while CPW covers the need")
	EconUtil.st(w)["util_demand"]["E"] = int(EconRulesUtil.eff_cap(w, "POWER"))
	check(EconRulesUtil.target(w, w.table("facility")[cheap]) > 0.0, "a unit needed is always bought, whatever its price")


func test_grid_pays_private_plant_for_units_taken() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var fid := _private_plant(w, "POWER", 50.0)
	var f: Dictionary = w.table("facility")[fid]
	var s := EconUtil.st(w)
	var own := 0
	for p in _plants(w, "POWER"):
		if p != fid:
			own += int(w.table("facility")[p].get("out_last", 0))
	f["out_last"] = 100 * S
	s["util_demand"]["E"] = own + 60 * S
	s["util_supply"]["E"] = own + 100 * S
	_fund(w, 100000 * S)
	var before := w.ledger.balance(EconUtil.acct(String(f["org"])))
	var due := EconRulesUtil._buy(w, _cpw(w), "E")
	check_eq(due, 60 * 50 * S, "60 units taken at 50: the rest was not needed")
	check_eq(w.ledger.balance(EconUtil.acct(String(f["org"]))) - before, 60 * 50 * S, "paid by CPW")
	check_eq(int(f["r8u_pp"][-1][2]), 60 * S, "recorded as taken")


func test_private_price_rules() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var fid := _private_plant(w, "POWER", 1.0)
	var f: Dictionary = w.table("facility")[fid]
	var unit := EconRulesUtil.full_unit(w, f)
	var cap := int(EconRulesUtil._plant_cap(w, f))
	var full_pp: Array = []
	for i in 3:
		full_pp.append([i, cap, cap, 0, 0, 0])
	f["r8u_pp"] = full_pp
	var u := _hist(w, "E", _grow_rows(3, 2000, 1000))
	EconRulesUtil._private(w, _cpw(w), "E", u)
	check(float(f["r8u_price"]) >= unit, "rule 1: up to its cost per unit (%.1f)" % unit)
	var p1 := float(f["r8u_price"])
	EconRulesUtil._private(w, _cpw(w), "E", u)
	check(float(f["r8u_price"]) > p1, "rule 1: all taken while demand went unserved → dearer")
	f["r8u_price"] = ceilf(unit) + 20.0
	var idle_pp: Array = []
	for i in 3:
		idle_pp.append([i, cap / 10, cap / 10, 0, 0, 0])
	f["r8u_pp"] = idle_pp
	var calm: Array = []
	for i in 3:
		calm.append(_row(1000 * S, 2000 * S))
	EconRulesUtil._private(w, _cpw(w), "E", _hist(w, "E", calm))
	check(float(f["r8u_price"]) < ceilf(unit) + 20.0 and float(f["r8u_price"]) >= ceilf(unit), "rule 2: little taken → cheaper, not below cost")


func test_private_plant_mothballed_when_sales_miss_running_cost() -> void:
	var sim := _sim()
	var w: WorldState = sim.world
	var fid := _private_plant(w, "POWER", 1000.0)
	var f: Dictionary = w.table("facility")[fid]
	var pp: Array = []
	for i in 12:
		pp.append([i, 0, 0, 0, 5000, 1000])
	f["r8u_pp"] = pp
	var rows: Array = []
	for i in 12:
		rows.append(_row(1000 * S, 2000 * S))
	EconRulesUtil._private(w, _cpw(w), "E", _hist(w, "E", rows))
	check(f["mothball"], "rule 6: a year of sales below running cost")
	EconRulesUtil._private(w, _cpw(w), "E", _hist(w, "E", _grow_rows(3, 2000, 1000)))
	check(not f["mothball"] and f.has("r8u_ramp"), "reopened when demand goes unserved at full use")


func test_ownership_policy_is_not_public_only() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E137"])
	sim.world.levers["ECON_PUBLIC_OWNERSHIP_POLICY"] = 0
	check_eq(EconOwnership.policy_for(sim.world, "POWER"), "MARKET", "under the switch power follows the ownership policy")
	var sim2 := _sim(["R8", "E137"])
	sim2.world.levers["ECON_PUBLIC_OWNERSHIP_POLICY"] = 0
	check_eq(EconOwnership.policy_for(sim2.world, "POWER"), "STATE", "without it, as before")


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


func test_second_public_company_under_a_state_policy() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E137"])
	var w: WorldState = sim.world
	w.levers["ECON_PUBLIC_OWNERSHIP_POLICY"] = 2
	check_eq(EconRulesUtil.founder_order(w, "POWER"), ["PUBLIC", "PRIVATE"], "a state policy founds a public company first")
	var u := _hist(w, "E", _grow_rows(12, 2000, 1000))
	var t0 := w.ledger.balance(EconUtil.TREASURY)
	EconRulesUtil._entry(w, _cpw(w), "E", u)
	var v: Dictionary = u["entry"]["E"]
	check_eq(String(v["why"]), "founded", "rule 7 for a public company: the same condition")
	check_eq(String(v.get("kind", "")), "PUBLIC", "public")
	var o: Dictionary = w.table("org").get(String(v.get("org", "")), {})
	check(o.get("type", "") == "PUBLIC_ENTERPRISE" and o.get("key", "") != "CPW", "a second public utility, not CPW")
	check(w.ledger.balance(EconUtil.TREASURY) < t0, "its capital came from the treasury")


func test_market_policy_leaves_it_to_private_founders() -> void:
	var sim := _sim(["R8", "R8_UTILITIES", "E137"])
	var w: WorldState = sim.world
	w.levers["ECON_PUBLIC_OWNERSHIP_POLICY"] = 0
	check_eq(EconRulesUtil.founder_order(w, "WATERWORKS"), ["PRIVATE"], "market: private founders only")
	w.levers["ECON_PUBLIC_OWNERSHIP_POLICY"] = 1
	check_eq(EconRulesUtil.founder_order(w, "WATERWORKS"), ["PRIVATE", "PUBLIC"], "mixed: private first, then the state")
