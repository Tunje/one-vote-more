extends SceneTree
## Dump bids/offers for one good before a given month's TRADE (debugging aid).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var month := int(args[0]) if args.size() > 0 else 18
	var good: String = args[1] if args.size() > 1 else "MINERAL"
	var sim := EconSim.make(1, "BALANCED", {}, true) if args.size() > 2 else EconSim.make_econ_only(1)
	sim.run(month)
	var w := sim.world
	var s := EconUtil.st(w)
	print("price ", s["prices"][good] / 1000, " freight_cap ", s["freight_cap"] / 1000)
	for o in s["offers"]:
		if o["good"] == good:
			print("  OFFER ", w.table("org").get(o["seller"], {"key": o["seller"]})["key"], " ", o["district"], " qty ", o["qty"] / 1000, " ask ", o["ask"] / 1000)
	for b in s["orders"]:
		if b["good"] == good:
			var who = w.table("org").get(b["buyer"], {"key": b["buyer"]})["key"]
			print("  BID ", who, " ", b["district"], " qty ", b["qty"] / 1000, " limit ", b["limit"] / 1000, " class ", b["class"], " cash ", w.ledger.balance(b["acct"]) / 1000000, "k")
	var short := 0
	var need := 0
	var cash := 0
	for gid in EconUtil.sorted_keys(w.table("hh")):
		var g: Dictionary = w.table("hh")[gid]
		short += g["unmet"].get("FOOD", 0)
		need += int(EconHouseholds.persons(g))
		cash += w.ledger.balance(EconUtil.hh_acct(gid))
	print("hh unmet FOOD %d of persons %d; hh cash %dk; food_shortfall ‰ %d; aid_streak %d" % [short / 1000, need / 1000, cash / 1000000, s.get("food_shortfall", 0), s.get("aid_streak", 0)])
	quit(0)
