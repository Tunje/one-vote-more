extends SceneTree
func _initialize() -> void:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	sim.run(100)
	for m in 0:
		sim.step()
		if m % 6 != 5:
			continue
		var w := sim.world
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "FARM":
				var o: Dictionary = w.table("org")[f["org"]]
				print("m%d depot T%d util%d staff %d/30 out %d cond %d mb %s owner %s %s cash %dk energy_served %s" % [m, f["T"], f["util"], EconLabor.staff_total(f["staff"]) / 1000, f["out_last"] / 1000, f["condition"] / 1000, f["mothball"], o["key"], o["status"], w.ledger.balance(EconUtil.acct(f["org"])) / 1000000, EconUtil.st(w).get("util_supply", {})])
	var w := sim.world
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] in ["WATERWORKS", "POWER"]:
			var o: Dictionary = w.table("org")[f["org"]]
			print("%s %s T%d util%d staff %d out %d cond %d mb %s owner %s %s cash %dk stock %d" % [fid, f["type"], f["T"], f["util"], EconLabor.staff_total(f["staff"]) / 1000, f["out_last"] / 1000, f["condition"] / 1000, f["mothball"], o["key"], o["status"], w.ledger.balance(EconUtil.acct(f["org"])) / 1000000, EconUtil.inv_get(w, f["org"], "FOOD", f["district"]) / 1000])
	for fid in EconUtil.sorted_keys(w.table("facility")):
		if w.table("facility")[fid]["type"] == "WATERWORKS":
			print(EconQuery.explain_facility(w, fid))
	print("util supply/demand ", EconUtil.st(w)["util_supply"], EconUtil.st(w)["util_demand"])
	quit(0)
