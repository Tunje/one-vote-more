extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(3)
	var w := sim.world
	w.meta["on"] = ["WAREHOUSE"] if OS.get_cmdline_user_args().has("on") else []
	sim.run(3)
	print("a ", EconReport.goods_errors(w))
	EconUtil.inv_add(w, "gov", "MEDICAL", "d:1", 1000 * 1000, 0)
	EconUtil.qflow(w, "MEDICAL", "imported", 1000 * 1000)
	print("b ", EconReport.goods_errors(w))
	if OS.get_cmdline_user_args().has("call"): EconWarehouse.monthly(w)
	print("c ", EconReport.goods_errors(w))
	for m in 12:
		sim.run(1)
		var e := EconReport.goods_errors(w)
		if not e.is_empty():
			print("m", m, " ", e)
			break
	quit()
