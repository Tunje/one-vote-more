extends SceneTree
## Bob: why SUPPORT_S costs people in the full game. args: seed years [S]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var arm := "v8"
	if a.size() > 2 and a[2] == "S":
		(w.meta["on"] as Array).append("SUPPORT_S")
		arm = "v8+S"
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 5 != 0:
			continue
		var s := EconUtil.st(w)
		var pop := 0
		var top := 0
		var hhm := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			pop += EconHouseholds.persons(g) / 1000
			var m := w.ledger.balance(EconUtil.hh_acct(gid))
			hhm += m
			top = maxi(top, m)
		var hubs := 0
		var com := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "SERVICEHUB":
				hubs += EconLabor.staff_total(f["staff"]) / 1000
			if f["type"] == "COMFORT":
				com += EconLabor.staff_total(f["staff"]) / 1000
		print("%s Y%d pop %d u %.1f%% attract %.2f hh money %dM (top pool %dM) hubs %d comfort %d food %d‰ taxes %d/%d treasury %dM" % [arm, y + 1, pop,
			float(EconQuery.labour(w)["rate_pct"]), EconCohorts.attractiveness(w), hhm / 1000000000, top / 1000000000, hubs, com,
			int(s.get("food_shortfall", 0)), int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"]), w.ledger.balance(EconUtil.TREASURY) / 1000000000])
	quit()
