extends TestCase
## R8 step 2b (EconRulesMat, opt-in R8 + R8_MATERIAL): the materials chain's eight rules.


func _sim(on: bool) -> Simulation:
	var sim := EconSim.make_econ_only(3)
	if on:
		sim.world.meta["on"] = ["R8", "R8_MATERIAL"]
	return sim


func test_off_changes_nothing() -> void:
	var a := EconSim.make_econ_only(3)
	var b := EconSim.make_econ_only(3)
	b.world.meta["on"] = ["R8"]
	a.run(12)
	b.run(12)
	for g in ["MINERAL", "MATERIAL", "COMPONENT"]:
		check_eq(int(EconUtil.st(b.world)["prices"][g]), int(EconUtil.st(a.world)["prices"][g]), "R8 alone leaves %s's price" % g)
	check(not EconRulesMat.on(b.world), "the sector switch is off")


func test_price_rises_toward_cost_while_orders_go_unfilled() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	var uc := FirmAI.unit_cost(w, "PROCESSING")
	var p := 0.6 * uc
	var p2 := EconRulesMat.price(w, "MATERIAL", p, 0.03, 0.5)  # a small shortage, lots of (unsellable) stock
	check(p2 > p, "below cost with unfilled orders the price creeps up (%d → %d)" % [int(p), int(p2)])
	check(p2 <= uc, "but not past the full cost in one step")
	var p3 := EconRulesMat.price(w, "MATERIAL", p, 0.50, 0.5)
	check(p3 > p2, "a real shortage moves it faster")


func test_price_never_falls_while_orders_go_unfilled() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	var uc := FirmAI.unit_cost(w, "PROCESSING")
	var p := 2.0 * uc
	check(EconRulesMat.price(w, "MATERIAL", p, 0.01, 1.0) >= p, "above the markup, unfilled orders hold the price")
	check(EconRulesMat.price(w, "MATERIAL", p, 0.0, 0.0) < p, "with every order filled it drifts back toward the markup")


func test_glut_lowers_price_only_with_idle_plants() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	var pl: Dictionary = EconUtil.st(w)["r8"]["plants"]
	var p := 1.2 * FirmAI.unit_cost(w, "MINE")
	for fid in pl:
		if String(pl[fid]["g"]) == "MINERAL":
			pl[fid]["util"] = 950
	check(EconRulesMat.price(w, "MINERAL", p, 0.0, 1.0) >= p * 0.97, "busy mines: stock alone is not a glut")
	for fid in pl:
		if String(pl[fid]["g"]) == "MINERAL":
			pl[fid]["util"] = 300
			pl[fid]["cost_var"] = int(p * 0.99)
	var p2 := EconRulesMat.price(w, "MINERAL", p, 0.0, 1.0)
	check(p2 < p, "idle mines with stock cut the price")
	check(p2 >= p * 0.99 - 1.0, "never below the variable cost")


func test_unfilled_orders_block_mothballing() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "PROCESSING":
			f["r8_unf_m"] = 2
			check(EconRulesMat.keeps(w, f), "a smelter with reachable unfilled orders is kept")
			f["r8_unf_m"] = 0
			check(not EconRulesMat.keeps(w, f), "without them the old rule applies")
			return
	check(false, "a smelter exists")


## The windowed rule 5, still in force for mines and components works. Processing plants (MATERIAL) follow the user's
## simple rule since 2026-11-16: tests/economy/test_sold_out_builds.gd.
func test_busy_plant_with_orders_expands() -> void:
	var sim := _sim(true)
	sim.run(3)
	var w := sim.world
	var s := EconUtil.st(w)
	var target := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "COMPONENTS" and not f["mothball"] and w.table("org")[f["org"]]["type"] == "PUBLIC_ENTERPRISE":
			target = fid  # (private smelters are still in their start-up loss: rule 5 waits for a profitable year)
			break
	var f0: Dictionary = w.table("facility")[target]
	f0["r8_hi_m"] = 6
	f0["r8_unf_m"] = 6
	s["prices"]["COMPONENT"] = int(2.0 * FirmAI.unit_cost(w, "COMPONENTS"))
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(f0["org"]), 5000000 * EconUtil.S, "TEST", w.month)
	EconRulesMat.capacity(w)
	var acts: Array = s.get("r8_mat_actions", [])
	check(acts.size() == 1 and String(acts[0][1]) == "COMPONENTS", "one capacity step for the components works (%s)" % str(acts))
	check(int(f0["r8_hi_m"]) == 0, "counters reset after the step")
	EconRulesMat.capacity(w)
	check((s.get("r8_mat_actions", []) as Array).size() == 1, "no second step while the first is open")


func test_runs_and_saves() -> void:
	var sim := _sim(true)
	sim.run(24)
	var w := sim.world
	check(w.ledger.balance(EconUtil.TREASURY) != 0, "runs two years")
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f.has("r8_hi_m"):
			check(typeof(f["r8_hi_m"]) == TYPE_INT and typeof(f["r8_unf_m"]) == TYPE_INT, "counters are integers")


func test_value_bids_carry_the_bid_above_the_market() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["R8", "R8_MATERIAL", "R8M_NOVALUE"]
	sim.run(2)
	check(EconRulesMat.value_bids(w).is_empty(), "off with R8M_NOVALUE")
	w.meta["on"] = ["R8", "R8_MATERIAL"]
	var s := EconUtil.st(w)
	s["prices"]["MATERIAL"] = int(0.4 * float(s["base"]["MATERIAL"]))  # the deadlock: material far below its worth
	var vb := EconRulesMat.value_bids(w)
	var comp_org := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "COMPONENTS":
			comp_org = w.table("facility")[fid]["org"]
			break
	var v := int(vb.get(comp_org + "|MATERIAL", 0))
	var old := int(float(s["prices"]["MATERIAL"]) * EconData.INPUT_LIMIT_MULT)
	check(v > old, "a component works values material above 1.3 × a depressed price (%d > %d)" % [v, old])
	var lim := EconRulesMat.value_limit(w, "MATERIAL", old, v, 0)
	check(lim > old and lim <= int(float(s["base"]["MATERIAL"]) * EconData.PRICE_MAX_MULT * EconMarket.wage_level(w)), "the limit rises to the value, under the ceiling")
	check(EconRulesMat.value_limit(w, "MATERIAL", old, 0, 0) == old, "no value, the old limit")
	sim.run(3)
	check(w.ledger.balance(EconUtil.TREASURY) != 0, "runs with value bids")
