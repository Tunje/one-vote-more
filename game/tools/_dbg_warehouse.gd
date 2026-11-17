extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim := EconSim.make_econ_only(int(a[0]))
	var w := sim.world
	w.meta["on"] = ["WAREHOUSE"]
	for y in int(a[1]):
		sim.run(12)
		var s := EconUtil.st(w)
		var lab := EconQuery.labour(w)
		print("Y%d %s rev_ema %d u %.1f%% food price %d burned FOOD %d" % [y + 1, EconWarehouse.summary(w), int(s.get("storage_rev_ema", 0)) / 1000,
			float(lab["rate_pct"]), int(s["prices"]["FOOD"]) / 1000, int(s["qflow"].get("FOOD", {}).get("burned", 0)) / 1000])
	print("ledger %d goods %s" % [w.ledger.total(), EconReport.goods_errors(w)])
	quit()
