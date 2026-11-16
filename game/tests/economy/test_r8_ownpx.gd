extends TestCase
## Price rules 1/2 for MINE, PROCESSING and COMPONENTS on the seller's own signals (R8M_OWNPX) and a builder's value of
## material from what its jobs leave (R8M_JOBVALUE). Both opt-in; EconRulesMat.

var SAVE_PATH: String = TestCase.save_path("r8_ownpx.sav")
const S := EconUtil.S


func _sim(extra: Array, months: int) -> Simulation:
	var sim := EconSim.make_econ_only(1)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


func _plant(w: WorldState, ftype: String) -> String:
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == ftype and not f["mothball"]:
			return fid
	return ""


func _cap(f: Dictionary) -> float:
	return float(EconData.RECIPES[f["type"]]["out"][1]) * float(S) * EconUtil.fscale(f)


## Sets one plant's R8 reading and its own price; every other plant of the type reads "nothing to do" (no reach, no cover).
func _only(w: WorldState, fid: String, reach: int, cover: int, px: int) -> void:
	var pl: Dictionary = EconUtil.st(w)["r8"]["plants"]
	var ft: String = w.table("facility")[fid]["type"]
	for f_id in w.table("facility"):
		var f: Dictionary = w.table("facility")[f_id]
		if f["type"] == ft and pl.has(f_id):
			pl[f_id]["reach"] = 0
			pl[f_id]["cover"] = 0
	if not pl.has(fid):
		pl[fid] = {"g": EconRulesMat.GOOD_FOR[ft], "util": 1000, "sales": 1000, "cost_var": 0}
	pl[fid]["reach"] = reach
	pl[fid]["cover"] = cover
	w.table("facility")[fid]["r8_px"] = px
	w.table("org")[w.table("facility")[fid]["org"]].erase("offered")  # rule 2 reads the plant's cover until offers are recorded


func test_off_sets_no_own_prices() -> void:
	var sim := _sim([], 6)
	for fid in sim.world.table("facility"):
		check(not sim.world.table("facility")[fid].has("r8_px"), "no own price without R8M_OWNPX")
	check(not EconRulesMat.own_on(sim.world, "MATERIAL"), "off")


func test_rule1_unfilled_orders_raise_the_sellers_price() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var fid := _plant(w, "PROCESSING")
	if fid == "":
		check(false, "a processing plant exists")
		return
	var f: Dictionary = w.table("facility")[fid]
	var cap := _cap(f)
	var p0 := 500 * S
	_only(w, fid, int(cap * 0.1), 0, p0)  # orders worth 10% of its capacity it could reach
	EconRulesMat.own_prices(w)
	var step := minf(EconRulesMat.OWN_UP, EconRulesMat.OWN_ALPHA * 0.1)
	check_near(float(int(f["r8_px"])), float(p0) * (1.0 + step), float(S), "up by ALPHA × reach ÷ capacity (1.5%)")
	_only(w, fid, int(cap * 2.0), 0, p0)  # a large shortfall: capped
	EconRulesMat.own_prices(w)
	check_near(float(int(f["r8_px"])), float(p0) * (1.0 + EconRulesMat.OWN_UP), float(S), "at most OWN_UP a month")


func test_rule2_unsold_stock_with_every_order_filled_lowers_it_with_no_floor() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var fid := _plant(w, "PROCESSING")
	if fid == "":
		check(false, "a processing plant exists")
		return
	var f: Dictionary = w.table("facility")[fid]
	var p0 := 500 * S
	_only(w, fid, 0, 100, p0)  # a tenth of a month's sales unsold
	EconRulesMat.own_prices(w)
	check_near(float(int(f["r8_px"])), float(p0) * (1.0 - EconRulesMat.OWN_ALPHA * 0.1), float(S), "down by ALPHA × unsold ÷ sales")
	_only(w, fid, 0, 3000, p0)
	EconRulesMat.own_prices(w)
	check_near(float(int(f["r8_px"])), float(p0) * (1.0 - EconRulesMat.OWN_DOWN), float(S), "at most OWN_DOWN a month")
	# no floor at cost: a price already below the plant's full cost still falls while stock goes unsold
	var full := FirmAI.unit_cost(w, "PROCESSING")
	var low := int(full * 0.5)
	_only(w, fid, 0, 3000, low)
	EconRulesMat.own_prices(w)
	var base := float(EconUtil.st(w)["base"]["MATERIAL"])
	if float(low) * (1.0 - EconRulesMat.OWN_DOWN) > base * EconData.PRICE_MIN_MULT:
		check(int(f["r8_px"]) < low, "below full cost it still falls (%d < %d)" % [int(f["r8_px"]), low])
	_only(w, fid, 0, 0, p0)
	EconRulesMat.own_prices(w)
	check_eq(int(f["r8_px"]), p0, "no reach and nothing unsold: unchanged")


func test_market_price_is_the_capacity_weighted_mean_and_e149_leaves_it() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var s := EconUtil.st(w)
	EconRulesMat.own_prices(w)
	var ws := 0.0
	var cs := 0.0
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "PROCESSING" and not f["mothball"]:
			ws += float(int(f["r8_px"])) * _cap(f)
			cs += _cap(f)
	if cs <= 0.0:
		check(false, "open processing plants")
		return
	check_near(float(int(s["prices"]["MATERIAL"])), ws / cs, 2.0, "the market price is the sellers' mean")
	var before := int(s["prices"]["MATERIAL"])
	s["market_stats"]["MATERIAL"] = {"S": 0, "D": 1000 * S, "wanted": 1000 * S, "filled": 0}  # a shortage E149 would answer
	EconMarket._update_prices(w)
	check_eq(int(s["prices"]["MATERIAL"]), before, "E149 does not move a good its sellers price")


func test_the_seller_asks_its_own_price() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var fid := _plant(w, "PROCESSING")
	if fid == "":
		check(false, "a processing plant exists")
		return
	var f: Dictionary = w.table("facility")[fid]
	f["r8_px"] = 123 * S
	check_eq(EconRulesMat.own_ask(w, f["org"], "MATERIAL", f["district"]), 123 * S if _alone(w, f) else EconRulesMat.own_ask(w, f["org"], "MATERIAL", f["district"]), "its own price")


func _alone(w: WorldState, f: Dictionary) -> bool:
	for fid in w.table("facility"):
		var g: Dictionary = w.table("facility")[fid]
		if g["id"] != f["id"] and g["org"] == f["org"] and g["type"] == f["type"] and g["district"] == f["district"]:
			return false
	return true


func test_the_jobs_left_value_of_material() -> void:
	var sim := _sim(["R8M_JOBVALUE"], 3)
	var w := sim.world
	var bid := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if bool(o.get("is_contractor", false)) and o["status"] in ["ACTIVE", "DISTRESSED"]:
			bid = oid
			break
	if bid == "":
		check(false, "a builder exists")
		return
	var pid := EconConstruction.create(w, "FARM", "d:1", "gov", "gov", "")
	var p: Dictionary = w.table("project")[pid]
	p["status"] = "ACTIVE"
	p["contractor"] = bid
	p["wu_total"] = 100 * S
	p["wu_done"] = 50 * S
	p["mat_total"] = 40 * S
	p["comp_total"] = 0
	p["price"] = 100000 * S
	p["paid"] = 40000 * S
	p["start_month"] = w.month
	p["bid_duration"] = 24
	p["supervision"] = 1000
	p["unpaid_m"] = 0
	p["esc_mat_price"] = 300 * S
	p["esc_comp_price"] = 900 * S
	w.table("org")[bid]["contracts"] = [pid]
	var wage := EconConstruction._crew_wage(w, bid) * 1.08
	var money := 300.0 * S * 20.0 + float(100000 * S) * 0.5 - 50.0 * wage  # award price × 20 units + the half of the price the work left earns − wages
	var expect := maxi(0, int(money * float(S) / float(20 * S)))
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), expect, "award price + (money still to come − wages) per unit still needed")
	check_eq(EconRulesMat.builder_value(w, bid, "MATERIAL"), expect, "the bid uses it under R8M_JOBVALUE")
	p["comp_total"] = 10 * S  # 5 component units still needed, at their award price
	var expect_c := maxi(0, int((money - 5.0 * 900.0 * S) * float(S) / float(20 * S)))
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), expect_c, "the other input at its award price comes off")
	p["comp_total"] = 0
	p["bid_duration"] = -6  # due 6 months ago: 6% of the price as penalty
	var expect_l := maxi(0, int((money - 0.06 * float(100000 * S) * 0.5) * float(S) / float(20 * S)))
	check_near(float(EconRulesMat.job_value(w, bid, "MATERIAL")), float(expect_l), 2.0, "the late penalty owed today comes off")
	p["bid_duration"] = 24
	p["unpaid_m"] = 1
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), 0, "a job a payment behind buys no material: not counted")
	p["unpaid_m"] = 0
	p["start_month"] = w.month + 2
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), 0, "a queued job not counted")
	p["start_month"] = w.month
	p["price"] = 1000 * S
	p["esc_mat_price"] = 0
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), 0, "nothing left for material: 0 (the old limit stands)")
	p["price"] = 100000 * S
	p["esc_mat_price"] = 300 * S
	p["paid"] = 10000 * S
	check_eq(EconRulesMat.job_value(w, bid, "MATERIAL"), expect, "the advance already paid does not change what the work left earns")
	w.meta["on"].erase("R8M_JOBVALUE")
	p["paid"] = 40000 * S
	var old := int(float(EconData.BASE_PRICE["MATERIAL"]) * float(S) * float(p["price"]) / float(maxi(1, int(p["est_cost"]))))
	check_eq(EconRulesMat.builder_value(w, bid, "MATERIAL"), old, "off: the old base-price value")


func test_both_run_save_and_load_identically() -> void:
	var ref := _sim(["R8M_OWNPX", "R8M_JOBVALUE"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")
	check_eq(ref.world.ledger.total(), 0, "ledger closed")
	check(EconPop.check(ref.world).is_empty(), "jobs equal people")
	var any := false
	for fid in ref.world.table("facility"):
		if ref.world.table("facility")[fid].has("r8_px"):
			any = true
	check(any, "plants carry their own prices")


func check_near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (%.0f vs %.0f)" % [msg, a, b])
