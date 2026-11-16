extends TestCase
## Batch 3 of the eight rules (Bob): forecast entry for big farms and bakeries (R8F_ENTRY), the seller's hold-back
## below its own cost (with the own-price switches; kill OWN_NOHOLD), and private hauliers (R8FR_PRIVATE).

const EconHaulier := preload("res://sim/economy/econ_haulier.gd")
var SAVE_PATH: String = TestCase.save_path("r8_batch3.sav")
const S := EconUtil.S
const FR := ["R8FR_MARKET", "R8FR_PRIVATE"]


func _sim(extra: Array, months: int, sd: int = 3) -> Simulation:
	var sim := EconSim.make_econ_only(sd)
	var on: Array = EconSim.DEFAULT_ON.duplicate()
	on.append_array(extra)
	sim.world.meta["on"] = on
	sim.run(months)
	return sim


func test_food_entry_on_the_forecast() -> void:
	var sim := _sim([], 2)
	check(not EconRulesMat.entry_on(sim.world, "FARM"), "off by default: the old entry")
	sim.world.meta["on"].append("R8F_ENTRY")
	check(EconRulesMat.entry_on(sim.world, "FARM") and EconRulesMat.entry_on(sim.world, "BAKERY"), "rules 7/8 on the forecast")
	var d := EconRulesMat.entry_district(sim.world, "FARM", "d:1")
	check(EconData.DISTRICTS.has(d), "a district from the forecast")
	sim.world.meta["off"] = ["R8F_ENTRY"]
	check(not EconRulesMat.entry_on(sim.world, "FARM"), "meta off wins")


## The processing plants' owner offers MATERIAL at `px` with `cash` in its account; returns [offered, its full cost].
func _offer_at(w: WorldState, px: int, cash: int) -> Array:
	var fid := ""
	for f_id in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[f_id]
		if f["type"] == "PROCESSING" and not f["mothball"]:
			fid = f_id
			break
	if fid == "":
		return []
	var oid: String = w.table("facility")[fid]["org"]
	for f_id in w.table("facility"):
		var f2: Dictionary = w.table("facility")[f_id]
		if f2["org"] == oid and f2["type"] == "PROCESSING":
			f2["r8_px"] = px
	var bal := w.ledger.balance(EconUtil.acct(oid))
	if bal > cash:
		w.ledger.transfer(EconUtil.acct(oid), Ledger.EXTERNAL, bal - cash, "TEST", w.month)
	elif bal < cash:
		w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), cash - bal, "TEST", w.month)
	var d: String = w.table("facility")[fid]["district"]
	var have := EconUtil.inv_get(w, oid, "MATERIAL", d)
	if have < 2000 * S:
		EconUtil.inv_add(w, oid, "MATERIAL", d, 2000 * S - have, px)
	var s := EconUtil.st(w)
	s["orders"] = []
	s["offers"] = []
	FirmAI._post_inputs_and_offers(w)
	var q := 0
	var value := 0
	for o in s["offers"]:
		if o["seller"] == oid:
			value += EconUtil.val(int(o["qty"]), int(o["ask"]))
			if o["good"] == "MATERIAL":
				q += int(o["qty"])
	return [q, FirmAI.unit_cost(w, "PROCESSING"), oid, value, w.ledger.balance(EconUtil.acct(oid))]


func test_below_its_cost_a_seller_keeps_stock_back_but_stays_afloat() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var full := FirmAI.unit_cost(w, "PROCESSING")
	var hi := _offer_at(w, int(full * 1.5), 0)
	if hi.is_empty():
		check(false, "a processing plant runs")
		return
	check(int(hi[0]) >= 1000 * S, "at or above its cost it offers its stock")
	var rich := _offer_at(w, int(full * 0.5), 1000000 * S)
	check_eq(int(rich[0]), 0, "below its cost with cash for the month it keeps everything back")
	var oid: String = rich[2]
	var short := _offer_at(w, int(full * 0.5), 0)
	var need := EconFinance._monthly_costs(w.table("org")[oid])
	check(int(short[0]) > 0 and int(short[0]) < 2000 * S, "short of cash it sells just enough (%d of 2000 units)" % [int(short[0]) / S])
	var gap := need - int(short[4])  # its month's costs less the cash it holds when it offers (a credit-line draw included)
	check(int(short[3]) >= gap - int(full * 0.5), "its offers (all its goods) cover what its cash does not (%d of %d)" % [int(short[3]) / S, gap / S])
	w.meta["on"].append("OWN_NOHOLD")
	var all := _offer_at(w, int(full * 0.5), 1000000 * S)
	check(int(all[0]) >= 1000 * S, "OWN_NOHOLD: no hold-back")


func test_rule_2_reads_only_what_it_offered_and_did_not_sell() -> void:
	var sim := _sim(["R8M_OWNPX"], 6)
	var w := sim.world
	var fid := ""
	for f_id in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[f_id]["type"] == "PROCESSING" and not w.table("facility")[f_id]["mothball"]:
			fid = f_id
			break
	var f: Dictionary = w.table("facility")[fid]
	var o: Dictionary = w.table("org")[f["org"]]
	var r := {"cover": 5000, "reach": 0}
	o["offered"] = {"MATERIAL": 100 * S}
	o["sold"] = {"MATERIAL": 100 * S}
	check_eq(EconRulesMat._unsold(w, f, "MATERIAL", r), 0.0, "all it offered sold: no cut, whatever it keeps in store")
	o["sold"] = {"MATERIAL": 50 * S}
	check(absf(EconRulesMat._unsold(w, f, "MATERIAL", r) - 1.0) < 0.001, "half of it unsold: unsold ÷ sold")
	o.erase("offered")
	check(absf(EconRulesMat._unsold(w, f, "MATERIAL", r) - 5.0) < 0.001, "before any offer is recorded: its cover")


func test_carriers_cheapest_first_and_cta_first_on_a_tie() -> void:
	var sim := _sim(FR, 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var cta := EconFinance.org_by_key(w, "CTA")
	var priv := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[oid]["type"] == "PRIVATE":
			priv = oid
			break
	w.table("org")[priv]["fr_rate"] = 2 * S
	w.levers["ECON_FREIGHT_TARIFF"] = 5
	s["fr_room_by"] = {cta: 100 * S, priv: 50 * S}
	EconHaulier.start_month(w)
	check_eq(String(s["fr_carriers"][0]["org"]), priv, "the cheaper haulier first")
	check_eq(EconHaulier.pick(s, 2), 0, "it has room")
	EconHaulier.carried(s, 0, priv, 50 * S)
	check_eq(EconHaulier.pick(s, 2), 1, "full: the next carrier")
	w.table("org")[priv]["fr_rate"] = 5 * S
	s["fr_room_by"] = {cta: 100 * S, priv: 50 * S}
	EconHaulier.start_month(w)
	check_eq(String(s["fr_carriers"][0]["org"]), cta, "a tie: CTA first")


func test_haulier_rate_rules_and_capacity() -> void:
	var sim := _sim(FR, 3)
	var w := sim.world
	var priv := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		if w.table("org")[oid]["type"] == "PRIVATE":
			priv = oid
			break
	var o: Dictionary = w.table("org")[priv]
	o["fr_rate"] = 10 * S
	EconHaulier._rate_rules(w, o, [[100 * S, 100 * S, 30 * S], [100 * S, 100 * S, 30 * S], [100 * S, 100 * S, 30 * S]])
	check(int(o["fr_rate"]) > 10 * S, "full and freight left behind: up")
	o["fr_rate"] = 10 * S
	EconHaulier._rate_rules(w, o, [[100 * S, 40 * S, 0], [100 * S, 40 * S, 0], [100 * S, 40 * S, 0]])
	check(int(o["fr_rate"]) < 10 * S, "idle trucks: down")
	o["fr_rate"] = 20 * S
	EconHaulier._rate_rules(w, o, [[100 * S, 100 * S, 900 * S], [100 * S, 100 * S, 900 * S], [100 * S, 100 * S, 900 * S]])
	check_eq(int(o["fr_rate"]), 20 * S, "within the lever's range")


func test_entry_waits_for_freight_left_behind_and_full_trucks() -> void:
	var sim := _sim(FR, 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var cta := EconFinance.org_by_key(w, "CTA")
	s["fr_ring"] = {cta: [[100 * S, 60 * S, 0], [100 * S, 60 * S, 0], [100 * S, 60 * S, 0]]}
	check(not bool(EconHaulier.entry(w)["hot"]), "rule 8: CTA's trucks idle, nothing left behind")
	s["fr_ring"] = {cta: [[100 * S, 100 * S, 0], [100 * S, 100 * S, 0], [100 * S, 100 * S, 0]]}
	check(not bool(EconHaulier.entry(w)["hot"]), "rule 8: CTA carries everything")
	var big := 5000 * S
	s["fr_ring"] = {cta: [[100 * S, 100 * S, big], [100 * S, 100 * S, big], [100 * S, 100 * S, big]]}
	w.levers["ECON_FREIGHT_TARIFF"] = 20
	var e := EconHaulier.entry(w)
	check(bool(e["hot"]) == (int(e["profit"]) > 0), "rule 7 follows the forecast's profit (%d)" % int(e["profit"]))
	w.levers["ECON_FREIGHT_TARIFF"] = 1
	check(not bool(EconHaulier.entry(w)["hot"]) or int(EconHaulier.entry(w)["profit"]) > 0, "at the lowest tariff only a profit founds one")


func test_a_haulier_carries_is_paid_and_the_run_stays_closed() -> void:
	var sim := _sim(FR, 6)
	var w := sim.world
	var priv := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not bool(o.get("is_contractor", false)):
			priv = oid
			break
	var dep := ""
	var n := 0
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "DEPOT" and not f["mothball"]:
			n += 1
			dep = fid
	if n < 1 or priv == "":
		check(false, "an open depot and a private firm")
		return
	w.table("facility")[dep]["org"] = priv  # a private haulier with one depot
	w.table("org")[priv]["fr_rate"] = 1 * S  # cheaper than the lever: it carries first
	var rev0 := int(EconAnnual.sum12(w.table("org")[priv]).get("rev", 0))
	sim.run(3)
	var carried: Dictionary = EconUtil.st(w).get("fr_last", {}).get("carried", {})
	check(int(carried.get(priv, 0)) > 0, "the haulier carried freight (%d)" % [int(carried.get(priv, 0)) / S])
	check(int(EconAnnual.sum12(w.table("org")[priv]).get("rev", 0)) > rev0, "and was paid for it")
	check_eq(w.ledger.total(), 0, "ledger closed")
	check(EconPop.check(w).is_empty(), "jobs equal people")


func test_save_load_identical() -> void:
	var ref := _sim(FR + ["R8F_ENTRY", "R8M_OWNPX", "R8F_OWNPX", "ORDER_IN", "INV_EXPECT"], 14)
	check_eq(SaveIO.save(ref, SAVE_PATH), OK, "save")
	ref.run(10)
	var loaded := EconSim.econ_only_for_load()
	check_eq(SaveIO.load_into(loaded, SAVE_PATH), OK, "load")
	loaded.run(10)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "continued state hash")


const EconImports := preload("res://sim/economy/econ_imports.gd")


func _buyer(w: WorldState) -> String:
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE":
			return oid
	return ""


func test_order_in_only_when_the_buyers_limit_reaches_the_landed_price() -> void:
	var sim := _sim(["ORDER_IN"], 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var b := _buyer(w)
	w.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(b), 100000000 * S, "TEST", w.month)
	var unit := EconImports.landed(w, "MATERIAL")
	var bid := {"buyer": b, "acct": EconUtil.acct(b), "good": "MATERIAL", "district": "d:2", "kind": "org", "qty": 0, "limit": unit - 1}
	EconImports.note_short(w, bid, 40 * S)
	EconImports.order_round(w)
	check(s.get("imp_pending", []).is_empty(), "below the landed price: the colony's sellers are the source, nothing ordered")
	bid["limit"] = unit
	var cash0 := w.ledger.balance(EconUtil.acct(b))
	EconImports.note_short(w, bid, 40 * S)
	EconImports.order_round(w)
	check_eq(EconImports._on_order(s, b, "MATERIAL"), 40 * S, "ordered what it was short")
	check_eq(cash0 - w.ledger.balance(EconUtil.acct(b)), EconUtil.val(40 * S, unit), "paid on order at the landed price")
	EconImports.note_short(w, bid, 50 * S)
	EconImports.order_round(w)
	check_eq(EconImports._on_order(s, b, "MATERIAL"), 50 * S, "next month: only the part not on order yet")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_ordered_goods_come_in_the_ships_hold_first_ordered_first() -> void:
	var sim := _sim(["ORDER_IN"], 3)
	var w := sim.world
	var s := EconUtil.st(w)
	var b := _buyer(w)
	var have := EconUtil.inv_get(w, b, "MATERIAL", "d:2")
	s["imp_pending"] = [{"holder": b, "good": "MATERIAL", "qty": 30 * S, "unit_cost": 1000 * S, "district": "d:2", "month": 1},
		{"holder": b, "good": "COMPONENT", "qty": 30 * S, "unit_cost": 1000 * S, "district": "d:2", "month": 2}]
	check_eq(EconImports.unload(w, 40), 40 * S, "a hold of 40 units")
	check_eq(EconUtil.inv_get(w, b, "MATERIAL", "d:2") - have, 30 * S, "the first order in full, to the buyer's district")
	check_eq(EconImports._on_order(s, b, "COMPONENT"), 20 * S, "the rest waits for the following ship")
	check_eq(EconImports.unload(w, 40), 20 * S, "and comes with it")
	check(s["imp_pending"].is_empty(), "nothing left on order")


func test_off_nothing_is_ordered() -> void:
	var sim := _sim([], 3)
	var w := sim.world
	var b := _buyer(w)
	EconImports.note_short(w, {"buyer": b, "acct": EconUtil.acct(b), "good": "MATERIAL", "district": "d:2", "kind": "org", "qty": 0, "limit": 99999999 * S}, 40 * S)
	EconImports.order_round(w)
	check(not EconUtil.st(w).has("imp_pending") or EconUtil.st(w)["imp_pending"].is_empty(), "off by default")
