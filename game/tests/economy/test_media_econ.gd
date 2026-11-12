extends TestCase
## Media M4, economy half: households buy copies from Media.demand() ({hh group: {outlet: copies (milli)}}) out of the
## services budget, paid to the outlet's account; outlets pay running costs as wages to district households.


func _setup() -> Array:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	w.table("outlet")["out:T"] = {"id": "out:T", "status": "ACTIVE", "price_mw": 2, "account": "media:out:T"}
	w.ledger.open_account("media:out:T")
	var gid := ""
	for k in EconUtil.sorted_keys(w.table("hh")):
		if gid == "" or EconHouseholds.discretionary_budget(w, w.table("hh")[k]) > EconHouseholds.discretionary_budget(w, w.table("hh")[gid]):
			gid = k  # the group with most to spend (the poorest bands have nothing left after essentials)
	return [sim, w, gid]


func test_households_buy_copies_and_ledger_closes() -> void:
	var r := _setup()
	var w: WorldState = r[1]
	var gid: String = r[2]
	var d: String = w.table("hh")[gid]["district"]
	Media.state(w)["circ"] = {"out:T": {d: 200}}  # Anni's circulation (copies per district); demand() maps it to groups
	var before := w.ledger.balance("media:out:T")
	EconHouseholds._buy_media(w)
	var got := w.ledger.balance("media:out:T") - before
	check(got > 0, "the outlet earned from copy sales (%d)" % got)
	var spent := 0
	for k in w.table("hh"):
		spent += int(w.table("hh")[k].get("media_spent", 0))
	check_eq(spent, got, "household spend equals outlet revenue")
	check(int(w.table("hh")[gid]["media_spent"]) > 0, "the better-off group bought copies")
	var sales: Dictionary = Media.state(w).get("sales", {})
	check(int(sales.get("out:T", 0)) > 0, "sales recorded back to media: %s" % [sales])
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_media_wages_go_to_district_households() -> void:
	var r := _setup()
	var w: WorldState = r[1]
	var gid: String = r[2]
	var d: String = w.table("hh")[gid]["district"]
	EconUtil.pay_upto(w, EconUtil.hh_acct(gid), "media:out:T", 10000 * EconUtil.S, "TEST")
	var paid := EconHouseholds.pay_media_wages(w, "media:out:T", 4000 * EconUtil.S, d)
	check_eq(paid, 4000 * EconUtil.S, "paid in full from a funded account")
	var short := EconHouseholds.pay_media_wages(w, "media:out:T", 1000000 * EconUtil.S, d)
	check(short <= 6000 * EconUtil.S and w.ledger.balance("media:out:T") >= 0, "never pays more than the account holds")
	check_eq(w.ledger.total(), 0, "ledger closed")


func test_switch_off_buys_nothing() -> void:
	var r := _setup()
	var w: WorldState = r[1]
	var gid: String = r[2]
	Media.state(w)["circ"] = {"out:T": {w.table("hh")[gid]["district"]: 200}}
	w.meta["off"] = ["MEDIA_M4"]
	EconHouseholds._buy_media(w)
	check_eq(w.ledger.balance("media:out:T"), 0, "MEDIA_M4 off: no purchases")


func _company_paper(w: WorldState) -> Array:
	var best := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not o["is_contractor"]:
			if best == "" or w.ledger.balance(EconUtil.acct(oid)) > w.ledger.balance(EconUtil.acct(best)):
				best = oid
	var r: Dictionary = Media.found_outlet(w, {"kind": "COMPANY", "id": best}, {"name": "Test Courier"})
	return [best, String(r.get("out_id", ""))]


## Company side: an owner with bad press covers its paper's shortfall from retained cash.
func test_company_covers_its_paper_when_willing() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var p := _company_paper(w)
	var oid: String = p[0]
	var out_id: String = p[1]
	check(out_id != "", "paper founded")
	var acc := String(w.table("outlet")[out_id]["account"])
	w.add_fact({"type": "TEST_BAD", "owner": "econ", "subjects": [{"kind": "COMPANY", "id": oid}], "responsible": [],
		"impact": {"JOBS": -10}, "magnitude": 60, "visibility": "PUBLIC", "data": {}})  # a grievance: the paper is worth more
	EconUtil.pay_upto(w, acc, Ledger.EXTERNAL, w.ledger.balance(acc), "TEST")  # endowment spent
	var cash0 := w.ledger.balance(EconUtil.acct(oid))
	FirmAI._media_owners(w)
	var cover := w.ledger.balance(acc)
	check(cover > 0 and cover <= Media.running_cost(w, w.table("outlet")[out_id]) * 11 / 10, "covered up to next month's cost + 10%% (%d)" % cover)
	check_eq(cash0 - w.ledger.balance(EconUtil.acct(oid)), cover, "paid from the owner's cash")


## An owner in liquidation sells its paper to a willing company with bad press of its own.
func test_liquidated_owner_sells_paper() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(2)
	var w := sim.world
	var p := _company_paper(w)
	var seller: String = p[0]
	var out_id: String = p[1]
	var buyer := ""
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if oid != seller and o["type"] == "PRIVATE" and o["status"] == "ACTIVE" and not o["is_contractor"]:
			buyer = oid
			break
	check(buyer != "", "a second private firm exists")
	EconUtil.pay_upto(w, EconUtil.acct(seller), EconUtil.acct(buyer), 200 * int(w.values.get("ECON_W_REF", 1200000)), "TEST")
	w.add_fact({"type": "TEST_BAD", "owner": "econ", "subjects": [{"kind": "COMPANY", "id": buyer}], "responsible": [],
		"impact": {"JOBS": -10}, "magnitude": 60, "visibility": "PUBLIC", "data": {}})
	w.table("org")[seller]["status"] = "LIQUIDATION"
	FirmAI._media_owners(w)
	if Media.bad_press_12m(w, buyer) > 0:
		check_eq(String(w.table("outlet")[out_id]["owner"]["id"]), buyer, "paper sold to the willing buyer")
		check_eq(String(w.table("org")[buyer].get("media_out", "")), out_id, "buyer records the paper")
	else:
		check(String(w.table("outlet")[out_id]["owner"]["id"]) == seller, "no motivated buyer: no sale")
	check_eq(w.ledger.total(), 0, "ledger closed")
