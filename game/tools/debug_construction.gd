extends SceneTree
## Construction pipeline trace (debugging aid).
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 24
	var sim := EconSim.make_econ_only(int(args[1]) if args.size() > 1 else 1)
	for m in months:
		sim.step()
		var w := sim.world
		var s := EconUtil.st(w)
		if (w.month - 1) % 2 != 0:
			continue
		print("m%02d MAT@%d COMP@%d" % [w.month - 1, s["prices"]["MATERIAL"] / 1000, s["prices"]["COMPONENT"] / 1000])
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if not o["is_contractor"]:
				continue
			var txt := ""
			for pid in o["contracts"]:
				var p: Dictionary = w.table("project")[pid]
				txt += "%s %s %d/%d prog%d dur%d start%d unpaid%d; " % [p["type"], p["district"], p["wu_done"] / 1000, p["wu_total"] / 1000, p["prog_m"] / 1000, p["bid_duration"], p["start_month"], p["unpaid_m"]]
			print("   %-7s %s crew %3d K %3d committed %4d cash %5dk MAT %d COMP %d blocked %s | %s" % [o["key"], o["status"].substr(0, 3), EconLabor.staff_total(o["crew"]) / 1000, EconConstruction.capacity(w, oid) / 1000, EconConstruction.committed(w, oid) / 1000, w.ledger.balance(EconUtil.acct(oid)) / 1000000, EconUtil.inv_get(w, oid, "MATERIAL", o["hq"]) / 1000, EconUtil.inv_get(w, oid, "COMPONENT", o["hq"]) / 1000, o.get("blocked_last", false), txt])
		var open := ""
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			if p["status"] in ["TENDER", "TENDERABLE"]:
				open += "%s %s %s(t%d) owner %s; " % [p["type"], p["district"], p["status"], p["tender_month"], p["owner"].substr(0, 8)]
		print("   open: ", open)
	quit(0)
