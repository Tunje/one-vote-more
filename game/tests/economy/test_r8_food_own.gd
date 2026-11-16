extends TestCase
## Food under all eight rules: rules 1/2 on every FOOD and FINE_FOOD seller's own signals (R8F_OWNPX) and rules 5/6 for
## family farms and bakeries (R8F_FAM56). Both opt-in, with R8_FOOD; EconRulesMat.

var SAVE_PATH: String = TestCase.save_path("r8_food_own.sav")
const S := EconUtil.S


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


func _of(w: WorldState, ftype: String) -> String:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"]:
			return fid
	return ""


func _only(w: WorldState, fid: String, good: String, reach: int, cover: int, px: int) -> void:
	var pl: Dictionary = EconUtil.st(w)["r8"]["plants"]
	for f_id in pl:
		if String(pl[f_id]["g"]) == good:
			pl[f_id]["reach"] = 0
			pl[f_id]["cover"] = 0
	if not pl.has(fid):
		pl[fid] = {"g": good, "util": 1000, "sales": 1000, "cost_var": 0}
	pl[fid]["reach"] = reach
	pl[fid]["cover"] = cover
	w.table("facility")[fid]["r8_px"] = px
	w.table("org")[w.table("facility")[fid]["org"]].erase("offered")  # rule 2 reads the plant's cover until offers are recorded


func test_switch_needs_r8_food() -> void:
	var sim := _sim([], 2)
	check(not EconRulesMat.own_on(sim.world, "FOOD"), "off without R8F_OWNPX")
	sim.world.meta["on"].append("R8F_OWNPX")
	check(EconRulesMat.own_on(sim.world, "FOOD") and EconRulesMat.own_on(sim.world, "FINE_FOOD"), "on with R8_FOOD")
	check(not EconRulesMat.own_on(sim.world, "MATERIAL"), "materials keep their own switch")
	sim.world.meta["off"] = ["R8F_OWNPX"]
	check(not EconRulesMat.own_on(sim.world, "FOOD"), "meta off wins")


func test_farm_and_family_farm_set_their_own_price() -> void:
	var sim := _sim(["R8F_OWNPX"], 12)
	var w := sim.world
	for pair in [["FARM", "FOOD"], ["FAMBAKERY", "FINE_FOOD"]]:
		var ft: String = pair[0]
		var good: String = pair[1]
		var fid := _of(w, ft)
		if fid == "":
			check(false, "a %s exists" % ft)
			continue
		var f: Dictionary = w.table("facility")[fid]
		var cap := float(EconData.RECIPES[ft]["out"][1]) * float(S) * EconUtil.fscale(f)
		_only(w, fid, good, int(cap * 0.1), 0, 200 * S)
		EconRulesMat.own_prices(w)
		check(absf(float(int(f["r8_px"])) - 200.0 * S * (1.0 + EconRulesMat.OWN_ALPHA * 0.1)) <= float(S), ft + ": rule 1 raises on its reachable unfilled orders")
		_only(w, fid, good, 0, 3000, 200 * S)
		EconRulesMat.own_prices(w)
		check(absf(float(int(f["r8_px"])) - 200.0 * S * (1.0 - EconRulesMat.OWN_DOWN)) <= float(S), ft + ": rule 2 lowers on unsold stock")
		f["r8_px"] = 77 * S
		var alone := true
		for f_id in w.table("facility"):
			var g: Dictionary = w.table("facility")[f_id]
			if f_id != fid and g["org"] == f["org"] and g["district"] == f["district"] and EconRulesMat._makes(g, good):
				alone = false
		if alone:
			check_eq(EconRulesMat.own_ask(w, f["org"], good, f["district"]), 77 * S, ft + ": it asks its own price, no family ask floor")


func test_market_rule_and_dead_band_no_longer_set_food() -> void:
	var sim := _sim(["R8F_OWNPX"], 12)
	var w := sim.world
	var s := EconUtil.st(w)
	EconRulesMat.own_prices(w)
	var before := int(s["prices"]["FOOD"])
	s["market_stats"]["FOOD"] = {"S": 0, "D": 1000 * S, "wanted": 1000 * S, "filled": 0}
	EconMarket._update_prices(w)
	check_eq(int(s["prices"]["FOOD"]), before, "the old market step does not move food")


func _family_plant(w: WorldState, ftype: String) -> String:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"] and bool(w.table("org")[f["org"]].get("family", false)):
			return fid
	return ""


func test_a_family_bakery_grows_on_orders_and_keeps_its_plant_while_they_last() -> void:
	var sim := _sim(["R8F_FAM56"], 12)
	var w := sim.world
	var fid := _family_plant(w, "FAMBAKERY")
	if fid == "":
		check(false, "a family bakery exists")
		return
	var f: Dictionary = w.table("facility")[fid]
	var oid: String = f["org"]
	w.table("org")[oid]["status"] = "ACTIVE"
	f["r8_hi_m"] = 12
	f["r8_unf_m"] = 12
	check(EconRulesMat.keeps(w, f), "rule 6: not mothballed while orders it can reach go unfilled")
	# a price well above the family's own cost, a profitable year, cash for the work
	EconUtil.st(w)["prices"]["FINE_FOOD"] = int(EconRulesFood.family_full_cost(w, oid, "FAMBAKERY") * 2.0)
	w.table("org")[oid]["pl_ring"] = []
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), EconConstruction.estimate("FAMBAKERY"), "GRANT", w.month)
	for f_id in w.table("facility"):  # only this plant qualifies this quarter
		if f_id != fid:
			w.table("facility")[f_id]["r8_hi_m"] = 0
	check(EconRulesMat._expand_pending(w, fid) == false, "no expansion yet")
	EconRulesMat.capacity(w)
	check(EconRulesMat._expand_pending(w, fid) or EconConstruction.has_open_project(w, oid, "FAMBAKERY"), "rule 5: the family grows its own bakery")
	var plants := 0
	for f_id in w.table("facility"):
		if w.table("facility")[f_id]["org"] == oid:
			plants += 1
	check_eq(plants, 1, "never a second plant")
	w.meta["on"].erase("R8F_FAM56")
	check(not EconRulesMat.keeps(w, f), "off: the old rule (no family under rules 5/6)")


func test_runs_save_and_load_identically() -> void:
	var ref := _sim(["R8F_OWNPX", "R8F_FAM56"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
