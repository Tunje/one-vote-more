extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_C"]
	for y in 20:
		sim.run(12)
		if (y + 1) % 4 == 0:
			print("Y%d %s u %.1f%%" % [y + 1, EconBizSvc.summary(w)["colony"], float(EconQuery.labour(w)["rate_pct"])])
	print("ledger %d goods %s jobs %s" % [w.ledger.total(), EconReport.goods_errors(w), EconPop.check(w)])
	quit()
