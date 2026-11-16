extends TestCase
## R8 step 6 (EconRulesSvc, opt-in R8 + R8_SERVICES): the service hubs' eight rules.

const EconRulesSvc := preload("res://sim/economy/econ_rules_svc.gd")

const S := EconUtil.S


func _sim(on: bool, seed_v: int = 3) -> Simulation:
	var sim := EconSim.make_econ_only(seed_v)
	var fl: Array = (sim.world.meta.get("on", []) as Array).duplicate()
	fl.append("R8")
	if on:
		fl.append("R8_SERVICES")
	sim.world.meta["on"] = fl
	return sim


func _hub(w: WorldState) -> Dictionary:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "SERVICEHUB" and not f["mothball"]:
			return f
	return {}


func _losing(w: WorldState, oid: String) -> void:
	var o: Dictionary = w.table("org")[oid]
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 1000 * S
		pl["wages"] = 5000 * S
		ring.append(pl)
	o["pl_ring"] = ring


func _earning(w: WorldState, oid: String) -> void:
	var o: Dictionary = w.table("org")[oid]
	var ring: Array = []
	for i in 12:
		var pl := EconFinance.empty_pl()
		pl["rev"] = 9000 * S
		pl["wages"] = 1000 * S
		ring.append(pl)
	o["pl_ring"] = ring


## Every open hub sold all it could (unused 0) or nothing (all unused).
func _sold(w: WorldState, all_of_it: bool) -> void:
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "SERVICEHUB":
			f["svc_sold"] = int(EconRulesSvc._cap(f)) if all_of_it else 0


func _set_unfilled(w: WorldState, d: String, u: int) -> void:
	var r8: Dictionary = EconUtil.st(w)["r8"]
	var goods: Dictionary = r8.get("goods", {})
	var row: Dictionary = goods.get("SERVICES", {})
	for d2 in EconData.DISTRICTS:
		row[d2] = {"w": u if d2 == d else 0, "f": 0, "u": u if d2 == d else 0, "hf": 0, "hr": 0}
	goods["SERVICES"] = row
	r8["goods"] = goods


func test_off_changes_nothing() -> void:
	var a := _sim(false)
	var b := EconSim.make_econ_only(3)
	b.world.meta["on"] = (b.world.meta.get("on", []) as Array) + ["R8"]
	a.run(12)
	b.run(12)
	check_eq(a.world.state_hash(), b.world.state_hash(), "R8 without R8_SERVICES: same run as before the hooks")
	check(not EconRulesSvc.on(a.world), "the sector switch is off")


func test_the_service_signal_arrives() -> void:
	var off := _sim(false)
	off.run(4)
	check(not EconUtil.st(off.world)["r8"].get("goods", {}).has("SERVICES"), "without R8_SERVICES the row is lost (the old bug)")
	var sim := _sim(true)
	sim.run(4)
	var row: Dictionary = EconUtil.st(sim.world)["r8"].get("goods", {}).get("SERVICES", {})
	check(not row.is_empty(), "with it, the SERVICES row is in the month's signals")
	var w_all := 0
	for d in row:
		w_all += int(row[d]["w"])
		check(int(row[d]["f"]) <= int(row[d]["w"]), "filled never exceeds wanted")
	check(w_all > 0, "households wanted services")
	var f := _hub(sim.world)
	check(EconRules.plant(sim.world, String(f["id"])).has("reach"), "a hub has a reach reading")


func test_price_rules_1_and_2() -> void:
	var p := 30000.0
	check(EconRulesSvc.price(p, 1000 * S, 300 * S, 0, 800 * S) > p, "rule 1: customers nobody served raise the price")
	check(EconRulesSvc.price(p, 1000 * S, 0, 400 * S, 1200 * S) < p, "rule 2: unsold hours lower it")
	check_eq(int(EconRulesSvc.price(p, 1000 * S, 0, 0, 1000 * S)), int(p), "a cleared market holds it")
	var small := EconRulesSvc.price(p, 1000 * S, 50 * S, 0, 1000 * S)
	var big := EconRulesSvc.price(p, 1000 * S, 500 * S, 0, 1000 * S)
	check(big > small, "in proportion to the shortage")


func test_price_moves_on_the_district_market_in_a_run() -> void:
	var sim := _sim(true)
	sim.run(6)
	var w := sim.world
	var s := EconUtil.st(w)
	var d := "d:1"
	var p0 := int(s["svc_price"][d])
	for fid in w.table("facility"):  # every hub near d shut: its customers go unserved
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "SERVICEHUB":
			f["T"] = 0
	sim.run(1)
	check(int(s["svc_price"][d]) >= p0, "unserved customers do not lower the price (%d → %d)" % [p0, int(s["svc_price"][d])])


func test_rules_3_and_4_target() -> void:
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	var f := _hub(w)
	var cap := float(EconData.RECIPES["SERVICEHUB"]["out"][1]) * float(S) * EconUtil.fscale(f)
	var pl := EconRules.plant(w, String(f["id"]))
	f["svc_sold"] = int(cap * 0.5)
	pl["reach"] = 0
	pl["cost_var"] = 0
	pl["cost_full"] = int(EconUtil.st(w)["svc_price"][f["district"]]) + 1
	f["T"] = 900
	check_eq(int(EconRulesSvc.target(w, f, cap) * 1000.0), 500, "rule 4: unsold hours, nobody waiting, price under its full cost: back to what it sold")
	pl["cost_full"] = 1
	f["T"] = 200
	check_eq(int(round(EconRulesSvc.target(w, f, cap) * 1000.0)), 500, "the price pays: never under what it sold")
	f["svc_sold"] = 0
	check_eq(int(round(EconRulesSvc.target(w, f, cap) * 1000.0)), 200 + int(EconRules.SECTORS["SERVICES"]["params"]["offer_step_pm"]), "an idle hub the price pays offers more hours")
	pl["cost_full"] = int(EconUtil.st(w)["svc_price"][f["district"]]) + 1
	f["svc_sold"] = int(cap * 0.5)
	pl["reach"] = int(cap * 3.0)
	check(EconRulesSvc.target(w, f, cap) > 0.5, "rule 3: customers waiting within reach: serve more")
	pl["reach"] = 0
	f["svc_sold"] = 0
	check_eq(EconRulesSvc.target(w, f, cap), 0.0, "no customers at all: no floor of ours keeps it serving")
	f["svc_sold"] = int(cap * 0.5)
	pl["cost_var"] = int(EconUtil.st(w)["svc_price"][f["district"]]) + 1
	check_eq(EconRulesSvc.target(w, f, cap), 0.0, "below its variable cost it serves none")


func test_rule_6_mothballs_an_idle_losing_hub_and_never_with_customers() -> void:
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	var f := _hub(w)
	_losing(w, String(f["org"]))
	f["r8s_cut_bits"] = 0x7FF  # 11 of 12
	check(not EconRulesSvc.capacity_down_or_reopen(w, f), "11 idle months: kept")
	f["r8s_cut_bits"] = 0xFFF
	_earning(w, String(f["org"]))
	check(not EconRulesSvc.capacity_down_or_reopen(w, f), "an owner earning money keeps it")
	_losing(w, String(f["org"]))
	check(EconRulesSvc.capacity_down_or_reopen(w, f), "a year idle with nobody waiting, owner losing: mothballed")
	check(bool(f["mothball"]), "mothballed")
	# the cut window only counts months when the customers waiting near it fit in the other hubs' unused hours
	var g := _hub(w)
	var pl := EconRules.plant(w, String(g["id"]))
	_sold(w, true)
	pl["reach"] = 10 * S
	g["svc_spare"] = 100 * S
	g["r8s_cut_bits"] = 0
	EconRulesSvc.note(w, g)
	check_eq(int(g["r8s_cut_bits"]) & 1, 0, "customers waiting that the others can't serve: not an idle month")
	_sold(w, false)
	g["svc_spare"] = 100 * S
	EconRulesSvc.note(w, g)
	check_eq(int(g["r8s_cut_bits"]) & 1, 1, "the others have room for them: an idle month for this one")


func test_a_mothballed_hub_reopens_when_customers_wait() -> void:
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	var f := _hub(w)
	f["mothball"] = true
	var d := String(f["district"])
	_sold(w, true)
	_set_unfilled(w, d, 500 * S)
	for i in EconRules.SECTORS["SERVICES"]["params"]["reopen_m"] - 1:
		check(not EconRulesSvc.capacity_down_or_reopen(w, f), "not yet (month %d)" % (i + 1))
	check(EconRulesSvc.capacity_down_or_reopen(w, f), "customers waiting month after month: reopened")
	check(not bool(f["mothball"]), "open again")
	_set_unfilled(w, d, 0)
	var g := _hub(w)
	g["mothball"] = true
	g["r8s_open_m"] = 0
	for i in 6:
		EconRulesSvc.capacity_down_or_reopen(w, g)
	check(bool(g["mothball"]), "nobody waiting: it stays shut")


func test_rule_5_a_sold_out_earning_hub_expands() -> void:
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	var f := _hub(w)
	var oid := String(f["org"])
	_earning(w, oid)
	w.ledger.transfer("EXTERNAL", EconUtil.acct(oid), EconConstruction.estimate("SERVICEHUB") * 2, "TEST", w.month)
	var pl := EconRules.plant(w, String(f["id"]))
	pl["cost_full"] = 1
	f["r8s_add_bits"] = 0x01F  # 5 of 12
	EconRulesSvc.capacity_up(w)
	check(not EconRulesMat._expand_pending(w, String(f["id"])), "5 sold-out months: not yet")
	f["r8s_add_bits"] = 0x03F
	_losing(w, oid)
	EconRulesSvc.capacity_up(w)
	check(not EconRulesMat._expand_pending(w, String(f["id"])), "an owner losing money doesn't expand")
	_earning(w, oid)
	EconRulesSvc.capacity_up(w)
	check(EconRulesMat._expand_pending(w, String(f["id"])), "6 sold-out months with customers waiting, earning: +25%")
	check_eq(int(f["r8s_add_bits"]), 0, "the window starts again")


func test_rules_7_and_8_founding() -> void:
	# the user, 2026-11-16: a newcomer reads the average of all the work in its reach, not the leftovers
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	var d := "d:3"
	var near := [d] + EconUtil.neighbours(d)
	var cap := float(EconData.RECIPES["SERVICEHUB"]["out"][1]) * float(S)
	_sold(w, true)
	_set_unfilled(w, d, 3000 * S)
	var fc := EconRulesSvc.forecast(w, d, 1000)
	var share := minf(3000.0 * S * cap / maxf(1.0, EconRulesSvc._cap_in_reach(w, d) + cap), cap)
	check(absi(int(fc["volume"]) - int(share * EconRulesSvc._crew_fill(w, 1000))) <= 1, "volume = its capacity's share of all the work in reach")
	if (fc["reasons"] as Array).is_empty():
		check(int(fc["profit"]) > 0, "a profit when nothing blocks it")
		check(EconRulesSvc.entry_district(w, 1000) != "", "rule 7: a district where a hub pays")
	# every customer served already: the newcomer still counts its share of them (no leftovers reading)
	var row: Dictionary = EconUtil.st(w)["r8"]["goods"]["SERVICES"]
	row[d]["f"] = 3000 * S
	row[d]["u"] = 0
	check_eq(int(EconRulesSvc.forecast(w, d, 1000)["volume"]), int(fc["volume"]), "filled work counts like unfilled work")
	_set_unfilled(w, d, 0)
	check(EconRulesSvc.forecast(w, d, 1000)["reasons"].has("no_customers"), "rule 8: no work in reach, no founding")
	check_eq(EconRulesSvc.entry_district(w, 1000), "", "no district")
	# more hub capacity in reach: a smaller share
	_set_unfilled(w, d, 3000 * S)
	var before := EconRulesSvc._cap_in_reach(w, d)
	var hub := ""
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "SERVICEHUB" and String(f["district"]) in near and not f["mothball"]:
			hub = fid
			break
	if hub != "":
		var v0 := int(EconRulesSvc.forecast(w, d, 1000)["volume"])
		w.table("facility")[hub]["scale"] = int(w.table("facility")[hub].get("scale", 1000)) + 1000
		check(EconRulesSvc._cap_in_reach(w, d) > before, "the bigger hub counts in reach")
		check(int(EconRulesSvc.forecast(w, d, 1000)["volume"]) < v0 or v0 == 0, "more capacity in reach, a smaller share")
		w.table("facility")[hub]["scale"] = int(w.table("facility")[hub]["scale"]) - 1000
	var any_near := false
	for fid in w.table("facility"):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "SERVICEHUB" and String(f["district"]) in near and not f["mothball"]:
			f["svc_sold"] = int(EconRulesSvc._cap(f))
			_losing(w, String(f["org"]))
			any_near = true
	if any_near:
		check(EconRulesSvc.forecast(w, d, 1000)["reasons"].has("incumbents_losing"), "rule 8: not while the incumbents near it lose money")


func test_micro_founder_needs_a_paying_district_not_unemployment() -> void:
	var sim := _sim(true)
	sim.run(4)
	var w := sim.world
	_set_unfilled(w, "d:1", 0)
	check_eq(EconRulesSvc.micro_founder(w), "", "no customers waiting anywhere: no micro co-op")


func test_runs_closes_and_saves_identically() -> void:
	var path := "user://test_rules_svc.save"
	var ref := _sim(true, 7)
	ref.run(36)
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	check_eq(SaveIO.save(ref, path), OK, "save")
	ref.run(12)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, path), OK, "load")
	check(EconRulesSvc.on(loaded.world), "the switch survives the save")
	loaded.run(12)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash with R8_SERVICES on")
