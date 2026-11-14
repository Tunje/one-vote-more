extends TestCase
## E146 bakery staples (EconStaple, opt-in "E146") and E147 start-up working capital (opt-in "E147").


func test_off_by_default() -> void:
	var sim := EconSim.make_econ_only(3)
	sim.run(3)
	var s := EconUtil.st(sim.world)
	check(not s.has("raw_food"), "no raw-food measure unless E146 is on")
	for gid in sim.world.table("hh"):
		check(int(sim.world.table("hh")[gid].get("ff_ord", 0)) == 0, "no staple orders when off")
	check(EconActions.validate(sim.world, "ECON_COMMISSION_PROJECT", {"type": "BAKERY", "district": "d:1"}) != "", "no bakery commissions when off")


## With no bakery in the colony every staple order falls back to raw FOOD the same month: no extra hunger.
func test_fallback_feeds() -> void:
	var short := {}
	for on in [false, true]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["E146"] if on else []
		var t := 0
		for m in 12:
			# hold fine food at its base price so the price gate stays open (with no bakery the price would spiral)
			EconUtil.st(w)["prices"]["FINE_FOOD"] = EconData.BASE_PRICE["FINE_FOOD"] * EconUtil.S
			sim.run(1)
			t += int(EconUtil.st(w)["food_shortfall"])
		short[on] = t
		if on:
			var ordered := 0
			for gid in w.table("hh"):
				ordered += int(w.table("hh")[gid].get("ff_ord", 0))
			check(ordered > 0, "households order bakery staples")
		check_eq(w.ledger.total(), 0, "ledger closed")
	check(int(short[true]) <= int(short[false]) + 24, "fallback: no extra hunger (%d vs %d ‰-months)" % [short[true], short[false]])


## (d) no taste, no unhappiness; taste grows with what households get, and a collapse is then felt.
func test_taste_and_raw_share() -> void:
	var g := {"ff_ord": 1000, "ff_got": 0, "ff_taste": 0}
	EconStaple.update_taste(g)
	check_eq(int(g["ff_taste"]), 0, "nothing bought: no taste")
	g["ff_got"] = 1000
	for i in 24:
		EconStaple.update_taste(g)
	check(int(g["ff_taste"]) > 800, "two years of bakery goods: a taste for them (%d)" % int(g["ff_taste"]))
	var t0 := int(g["ff_taste"])
	g["ff_got"] = 0
	EconStaple.update_taste(g)
	check(int(g["ff_taste"]) < t0 and int(g["ff_taste"]) > t0 * 9 / 10, "a collapse: the taste fades slowly")
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E146"]
	sim.run(3)
	check_eq(int(EconUtil.st(w).get("raw_food", -1)), 0, "a colony that never had bakeries misses nothing")
	for gid in w.table("hh"):
		w.table("hh")[gid]["ff_taste"] = 1000
	sim.run(2)
	check(int(EconUtil.st(w)["raw_food"]) > 500, "used to bakery goods, none to be had: raw share %d‰" % int(EconUtil.st(w)["raw_food"]))
	check(w.indicators.read("ECON_RAW_FOOD_SHARE", "d:1", -1) > 50.0, "the indicator is written")


func test_commission_bakery() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["E146"]
	sim.run(1)
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 100000
	var r := EconActions.enqueue(w, "ECON_COMMISSION_PROJECT", {"type": "BAKERY", "district": "d:2"})
	check(bool(r["ok"]), "a bakery can be commissioned under E146: %s" % r["error"])
	sim.run(1)
	var found := false
	for pid in w.table("project"):
		var p: Dictionary = w.table("project")[pid]
		if p["type"] == "BAKERY" and p["owner"] == "gov":
			found = true
			check_eq(w.table("org")[p["operator"]]["key"] if p.has("operator") else "CAB", "CAB", "run by the Agricultural Board")
	check(found, "the bakery project exists")


func test_startup_capital() -> void:
	var paid := {}
	for on in [false, true]:
		var sim := EconSim.make_econ_only(3)
		var w := sim.world
		w.meta["on"] = ["E147"] if on else []
		sim.run(1)
		var g := ""
		for gid in EconUtil.sorted_keys(w.table("hh")):
			if w.ledger.balance(EconUtil.hh_acct(gid)) > 500000 * EconUtil.S:
				g = gid
				break
		if g == "":
			w.ledger.transfer(Ledger.EXTERNAL, EconUtil.hh_acct(EconUtil.sorted_keys(w.table("hh"))[0]), 1000000 * EconUtil.S, "TEST", w.month)
			g = EconUtil.sorted_keys(w.table("hh"))[0]
		var oid := w.new_id("org")
		w.table("org")[oid] = {"id": oid, "key": "T_" + oid, "type": "PRIVATE", "status": "FORMING", "owner_group": g, "hq": "d:1",
			"premium_m": {"G": 0, "S": 0, "Sp": 0}, "ceo": {"mgmt": 50, "risk": 30, "age_m": 480}}
		w.ledger.open_account(EconUtil.acct(oid))
		var fid := EconSetup.add_facility(w, "BAKERY", oid, "d:1", false)
		var before := w.ledger.balance(EconUtil.acct(oid))
		EconStaple.startup_capital(w, oid, fid)
		paid[on] = w.ledger.balance(EconUtil.acct(oid)) - before
		check_eq(w.ledger.total(), 0, "ledger closed")
	check_eq(int(paid[false]), 0, "no working capital when off")
	check(int(paid[true]) > 0, "the founder pays in working capital (%dk)" % (int(paid[true]) / 1000 / EconUtil.S))
