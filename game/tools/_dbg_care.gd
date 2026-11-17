extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim := EconSim.make_econ_only(int(a[0]))
	var w := sim.world
	w.meta["on"] = Array(a[2].split(","))
	for y in int(a[1]):
		sim.run(12)
		if (y + 1) % 3 != 0:
			continue
		var s := EconUtil.st(w)
		var lab := EconQuery.labour(w)
		var sm := EconCare.summary(w)
		print("Y%d E %s | C %s | spentE %dk C %dk | u %.1f%% lf %d" % [y + 1, sm["ELDER"], sm["CHILD"],
			int(s["spent_ytd"].get("ECON_BUDGET_ELDER_CARE", 0)) / 1000000, int(s["spent_ytd"].get("ECON_BUDGET_CHILDCARE", 0)) / 1000000,
			float(lab["rate_pct"]), int(lab.get("labour_force", lab.get("lf", 0)))])
	print("ledger %d goods %s jobs %s" % [w.ledger.total(), EconReport.goods_errors(w), EconPop.check(w)])
	quit()
