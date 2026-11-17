extends SceneTree
## Compact monthly trace of the econ-only sim (debugging aid).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 12
	var sim := EconSim.make_econ_only(int(args[1]) if args.size() > 1 else 1)
	for m in months:
		sim.step()
		var w := sim.world
		var s := EconUtil.st(w)
		var lf := 0
		var emp := 0
		var cash := 0
		for gid in EconUtil.sorted_keys(w.table("hh")):
			var g: Dictionary = w.table("hh")[gid]
			lf += g["lf"]; emp += EconLabor.employed(g); cash += w.ledger.balance(EconUtil.hh_acct(gid))
		var line := "m%02d emp %4d/%4d hhcash %5dk " % [w.month - 1, emp / 1000, lf / 1000, cash / 1000000]
		for g in ["FOOD", "MINERAL", "MATERIAL", "CONSUMER"]:
			var ms: Dictionary = s["market_stats"].get(g, {})
			line += "%s %d/%d/%d@%d " % [g.substr(0, 3), ms.get("S", 0) / 1000, ms.get("D", 0) / 1000, ms.get("filled", 0) / 1000, s["prices"][g] / 1000]
		var bytype := {}
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			bytype[f["type"]] = bytype.get(f["type"], 0) + EconLabor.staff_total(f["staff"]) / 1000
		var crews := 0
		for oid in w.table("org"):
			if w.table("org")[oid]["is_contractor"]:
				crews += EconLabor.staff_total(w.table("org")[oid]["crew"]) / 1000
		line += " fcap %d staff %s crews %d" % [s["freight_cap"] / 1000, bytype, crews]
		print(line)
		var fl := "     "
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] in ["FARM", "MINE", "PROCESSING", "CONSUMERF"]:
				fl += "%s:T%d/s%d/o%d%s " % [f["type"].substr(0, 2), f["T"] / 10, EconLabor.staff_total(f["staff"]) / 1000, f["out_last"] / 1000, "M" if f["mothball"] else ""]
		print(fl)
		var ol := "     "
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if o["type"] != "PUBLIC_INSTITUTION":
				ol += "%s:%s:%dk " % [o["key"].substr(0, 4), o["status"].substr(0, 3), w.ledger.balance(EconUtil.acct(oid)) / 1000000]
		print(ol)
		var pl := "     projects: "
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			pl += "%s %s %s %d/%d bids%d; " % [p["type"], p["district"], p["status"], p["wu_done"] / 1000, p["wu_total"] / 1000, p["bids"].size()]
		print(pl, " actions ", s.get("action_log", []).slice(-3))
	quit(0)
