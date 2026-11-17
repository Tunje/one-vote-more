extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim := EconSim.make_econ_only(int(a[0]))
	var w := sim.world
	w.meta["on"] = [] if a[1] == "base" else ["M2"]
	for y in 30:
		for m in 12:
			w.levers["ECON_INCOME_TAX_RATE"] = 24
			w.levers["ECON_SALES_TAX"] = 8
			sim.run(1)
		if (y + 1) % 3 != 0:
			continue
		var v := EconBank.view(w)
		print("%s Y%d cap %dk loans %dk room %dk util %d deposits %dk failed %s | u %.1f%% | bank bal %dk treasury %dk" % [a[1], y + 1, v["capital"] / 1000, v["loans"] / 1000,
			v["room"] / 1000, v["utilisation_pm"], v["deposits"] / 1000, v["failed"], float(EconQuery.labour(w)["rate_pct"]),
			w.ledger.balance(EconUtil.BANK) / 1000000, w.ledger.balance(EconUtil.TREASURY) / 1000000])
	print("ledger %d jobs %s" % [w.ledger.total(), EconPop.check(w)])
	quit()
