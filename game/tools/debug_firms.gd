extends SceneTree
## Monthly P&L of selected firms (debugging aid).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 12
	var keys := ["VECTOR", "ATLAS"]
	var sim := EconSim.make_econ_only(int(args[1]) if args.size() > 1 else 1)
	for m in months:
		sim.step()
		var w := sim.world
		var s := EconUtil.st(w)
		print("m%02d prices F%d MIN%d MAT%d C%d CON%d MED%d svc%d wG%d" % [w.month - 1, s["prices"]["FOOD"] / 1000, s["prices"]["MINERAL"] / 1000, s["prices"]["MATERIAL"] / 1000, s["prices"]["COMPONENT"] / 1000, s["prices"]["CONSUMER"] / 1000, s["prices"]["MEDICAL"] / 1000, s["svc_price"]["d:1"] / 1000, s["wage"]["G"] / 1000])
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if not (o["key"] in keys):
				continue
			var pl: Dictionary = o["pl_last"]
			var stock := ""
			for good in FirmAI._org_outputs(w, oid):
				stock += "%s:%d sold%d ema%d " % [good.substr(0, 3), FirmAI._org_stock(w, oid, good) / 1000, o["sold"].get(good, 0) / 1000, o["sales_ema"].get(good, 0) / 1000]
			print("   %-8s %s cash %6dk rev %5dk cogs %5dk wages %5dk util %4dk frt %3dk int %3dk dep %3dk => %6dk | %s" % [o["key"], o["status"].substr(0, 3), w.ledger.balance(EconUtil.acct(oid)) / 1000000,
				pl.get("rev", 0) / 1000000, pl.get("cogs", 0) / 1000000, pl.get("wages", 0) / 1000000, pl.get("util", 0) / 1000000, pl.get("freight", 0) / 1000000, pl.get("interest", 0) / 1000000, pl.get("dep", 0) / 1000000, EconFinance.profit(pl) / 1000000, stock])
	quit(0)
