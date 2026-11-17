extends SceneTree
## Bob: E136/E137 full-game A/B. args: seed years [flags comma list]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var arm := "v8"
	if a.size() > 2:
		for fl in a[2].split(","):
			(w.meta["on"] as Array).append(fl)
		arm = "v8+" + a[2]
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 10 != 0:
			continue
		var adults := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
		var priv := 0
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			if o["type"] in ["PRIVATE", "COOPERATIVE"] and not (o["status"] in ["LIQUIDATION", "DISSOLVED"]):
				priv += 1
		var goods_priv := 0
		var goods_all := 0
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			for good in o.get("sold", {}):
				if good in ["SERVICES"]:
					continue
				goods_all += int(o["sold"][good])
				if o["type"] in ["PRIVATE", "COOPERATIVE"]:
					goods_priv += int(o["sold"][good])
		print("%s s%s Y%d adults %d u %.1f%% private firms %d private goods share %d‰ treasury %dM tax %d/%d" % [arm, a[0], y + 1, adults,
			float(EconQuery.labour(w)["rate_pct"]), priv, goods_priv * 1000 / maxi(1, goods_all), w.ledger.balance(EconUtil.TREASURY) / 1000000000,
			int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"])])
	quit()
