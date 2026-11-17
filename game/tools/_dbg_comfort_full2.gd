extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	(w.meta["on"] as Array).append("SUPPORT_S")
	for m in 96:
		sim.run(1)
		if m % 6 != 5:
			continue
		var line := "m%d" % (m + 1)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if String(o.get("key", "")).begins_with("COMFORT|"):
				line += " %s:%s cash %dk rev %dk" % [o["key"].substr(8), o["status"], w.ledger.balance(EconUtil.acct(oid)) / 1000000, int(EconUtil.st(w).get("comfort_rev_ema", {}).get(o["hq"], 0)) / 1000000]
		var hubs := 0
		for fid in w.table("facility"):
			if w.table("facility")[fid]["type"] == "SERVICEHUB" and not w.table("facility")[fid]["mothball"]:
				hubs += 1
		print(line, " hubs ", hubs)
	quit()
