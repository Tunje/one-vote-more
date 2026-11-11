extends SceneTree
## MATERIAL-chain diagnosis trace (Wilma time-box 2). Integrated config.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 84
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	for m in months:
		sim.step()
		var w := sim.world
		if (w.month - 1) % 4 != 0:
			continue
		var s := EconUtil.st(w)
		var ms: Dictionary = s["market_stats"]
		print("m%02d MIN S%d D%d F%d @%d (cost %.0f) | MAT S%d D%d W%d F%d @%d (cost %.0f) | unemp %.0f%%" % [w.month - 1,
			ms["MINERAL"]["S"] / 1000, ms["MINERAL"]["D"] / 1000, ms["MINERAL"]["filled"] / 1000, s["prices"]["MINERAL"] / 1000, FirmAI.unit_cost(w, "MINE") / 1000.0,
			ms["MATERIAL"]["S"] / 1000, ms["MATERIAL"]["D"] / 1000, ms["MATERIAL"]["wanted"] / 1000, ms["MATERIAL"]["filled"] / 1000, s["prices"]["MATERIAL"] / 1000, FirmAI.unit_cost(w, "PROCESSING") / 1000.0,
			100.0 * FirmAI.colony_unemployment(w)])
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if not (f["type"] in ["MINE", "PROCESSING"]):
				continue
			var o: Dictionary = w.table("org")[f["org"]]
			var inp := ""
			if f["type"] == "PROCESSING":
				inp = "MIN in stock %d" % (EconUtil.inv_get(w, f["org"], "MINERAL", f["district"]) / 1000)
			print("    %s %s %-8s %s cash %5dk T%3d util%3d staff %2d/%2d out %3d cond %2d scale %d %s %s steady%d" % [fid, f["type"].substr(0, 4), o["key"].substr(0, 8), o["status"].substr(0, 3),
				w.ledger.balance(EconUtil.acct(f["org"])) / 1000000, f["T"] / 10, f["util"] / 10, EconLabor.staff_total(f["staff"]) / 1000,
				int(float(EconData.RECIPES[f["type"]]["labor"].get("G", 0) + EconData.RECIPES[f["type"]]["labor"].get("S", 0)) * EconUtil.fscale(f)),
				f["out_last"] / 1000, f["condition"] / 1000, f.get("scale", 1000), "MB" if f["mothball"] else "", inp, f.get("steady_m", 0)])
		var exp := ""
		for pid in w.table("project"):
			var p: Dictionary = w.table("project")[pid]
			if p["type"] == "EXPAND" or p["type"] in ["MINE", "PROCESSING"]:
				exp += "%s(%s) " % [p["type"], p["status"]]
		if exp != "":
			print("    projects: ", exp)
	quit(0)
