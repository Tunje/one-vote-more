extends TestCase
## The consumer workshops and the medical works under all eight rules (R8_WORKSHOPS; EconRulesMat).

var SAVE_PATH: String = TestCase.save_path("r8_workshops.sav")
const S := EconUtil.S
const TYPES := {"CONSUMERF": "CONSUMER", "TEXTILE": "CLOTHING", "FURNITURE": "FURNISHINGS", "MEDWORKS": "MEDICAL"}


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
		if f["type"] == ftype and not f["mothball"] and w.table("org")[f["org"]]["status"] == "ACTIVE":
			return fid
	return ""


func test_off_by_default() -> void:
	var sim := _sim([], 3)
	for ft in TYPES:
		check_eq(EconRulesMat.good_of(sim.world, ft), "", ft + ": no eight rules without R8_WORKSHOPS")
		check(not EconRulesMat.own_on(sim.world, TYPES[ft]), ft + ": no own price")
		check(not EconRulesMat.entry_on(sim.world, ft), ft + ": old entry")


func test_all_eight_switch_on_together_and_take_apart() -> void:
	var sim := _sim(["R8_WORKSHOPS"], 3)
	var w := sim.world
	for ft in TYPES:
		check_eq(EconRulesMat.good_of(w, ft), TYPES[ft], ft + ": its good")
		check(EconRulesMat.own_on(w, TYPES[ft]), ft + ": rules 1/2")
		check(EconRulesMat.output_on(w, ft), ft + ": rules 3/4")
		check(EconRulesMat.capacity_on(w, ft), ft + ": rules 5/6")
		check(EconRulesMat.entry_on(w, ft), ft + ": rules 7/8")
	w.meta["on"].append_array(["R8W_NOPX", "R8W_NOENTRY"])
	check(not EconRulesMat.own_on(w, "CONSUMER"), "R8W_NOPX takes out rules 1/2 only")
	check(EconRulesMat.output_on(w, "CONSUMERF"), "rules 3/4 stay")
	check(not EconRulesMat.entry_on(w, "MEDWORKS"), "R8W_NOENTRY takes out rules 7/8")
	w.meta["on"].erase("R8W_NOPX")
	w.meta["on"].erase("R8W_NOENTRY")
	w.meta["off"] = ["R8_WORKSHOPS"]
	check_eq(EconRulesMat.good_of(w, "CONSUMERF"), "", "meta off wins")


func test_a_workshop_prices_on_its_own_orders_and_stock() -> void:
	var sim := _sim(["R8_WORKSHOPS"], 6)
	var w := sim.world
	var fid := _of(w, "CONSUMERF")
	if fid == "":
		check(false, "a consumer factory runs")
		return
	var f: Dictionary = w.table("facility")[fid]
	var pl: Dictionary = EconUtil.st(w)["r8"]["plants"]
	for f_id in pl:
		if String(pl[f_id]["g"]) == "CONSUMER":
			pl[f_id]["reach"] = 0
			pl[f_id]["cover"] = 0
	var cap := _ocap(w, f)
	var p0 := int(EconUtil.st(w)["base"]["CONSUMER"])  # inside the bounds every price has
	pl[fid]["reach"] = int(cap * 1.0)
	w.table("org")[f["org"]].erase("offered")
	f["r8_px"] = p0
	EconRulesMat.own_prices(w)
	check(absf(float(int(f["r8_px"])) - float(p0) * (1.0 + EconRulesMat.OWN_UP)) <= 2.0, "rule 1: up on its reachable unfilled orders (capped at OWN_UP)")
	pl[fid]["reach"] = 0
	pl[fid]["cover"] = 2000
	pl[fid]["sales"] = int(cap)
	w.table("org")[f["org"]].erase("offered")
	f["r8_px"] = p0
	EconRulesMat.own_prices(w)
	check(absf(float(int(f["r8_px"])) - float(p0) * (1.0 - EconRulesMat.stock_cut(2.0))) <= 2.0, "rule 2: down on its stock")
	var before := int(EconUtil.st(w)["prices"]["CONSUMER"])
	EconUtil.st(w)["market_stats"]["CONSUMER"] = {"S": 0, "D": 1000 * S, "wanted": 1000 * S, "filled": 0}
	EconMarket._update_prices(w)
	check_eq(int(EconUtil.st(w)["prices"]["CONSUMER"]), before, "the old colony step no longer sets it")


func test_a_workshop_with_unfilled_orders_is_kept_and_grows() -> void:
	var sim := _sim(["R8_WORKSHOPS"], 6)
	var w := sim.world
	var fid := _of(w, "CONSUMERF")
	if fid == "":
		check(false, "a consumer factory runs")
		return
	var f: Dictionary = w.table("facility")[fid]
	var oid: String = f["org"]
	f["r8_unf_m"] = 12
	f["r8_hi_m"] = 12
	check(EconRulesMat.keeps(w, f), "rule 6: kept while orders it can reach go unfilled")
	for f_id in w.table("facility"):
		if f_id != fid:
			w.table("facility")[f_id]["r8_hi_m"] = 0
	var o: Dictionary = w.table("org")[oid]
	if o["type"] == "PUBLIC_ENTERPRISE" or bool(o.get("is_contractor", false)):
		check(false, "a private consumer factory")
		return
	EconUtil.st(w)["prices"]["CONSUMER"] = int(FirmAI.unit_cost(w, "CONSUMERF") * 2.0)
	o["pl_ring"] = []
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), EconConstruction.estimate("CONSUMERF"), "GRANT", w.month)
	var had := EconRulesMat._expand_pending(w, fid) or EconConstruction.has_open_project(w, oid, "CONSUMERF")
	EconRulesMat.capacity(w)
	check(had or EconRulesMat._expand_pending(w, fid) or EconConstruction.has_open_project(w, oid, "CONSUMERF"), "rule 5: it adds capacity on its orders")


func test_medical_works_have_an_entry_path() -> void:
	var sim := _sim(["R8_WORKSHOPS"], 6)
	var w := sim.world
	check(EconRulesMat.entry_on(w, "MEDWORKS"), "rules 7/8 for the medical works")
	var d := EconRulesMat.entry_district(w, "MEDWORKS", "d:1")
	check(EconData.DISTRICTS.has(d), "a district from the forecast")
	var fc := EconForecast.first_year(w, "MEDWORKS", d)
	check(fc.has("profit") and fc.has("reasons"), "the forecast runs for the medical works")


func test_runs_closed_and_save_load_identically() -> void:
	var ref := _sim(["R8_WORKSHOPS"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	var own := 0
	for fid in ref.world.table("facility"):
		var f: Dictionary = ref.world.table("facility")[fid]
		if TYPES.has(f["type"]) and f.has("r8_px"):
			own += 1
	check(own > 0, "workshops carry their own prices")


## The company's open capacity of the plant's type (one price per company: rule 1 reads its reach against this).
func _ocap(w: WorldState, f: Dictionary) -> float:
	var c := 0.0
	for f_id in w.table("facility"):
		var g: Dictionary = w.table("facility")[f_id]
		if g["org"] == f["org"] and g["type"] == f["type"] and not g["mothball"]:
			c += float(EconData.RECIPES[g["type"]]["out"][1]) * float(S) * EconUtil.fscale(g)
	return c
