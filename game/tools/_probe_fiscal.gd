extends SceneTree
## Wilma A55 probe: yearly pop, unemployment, income/sales tax, treasury runway. args: seed years
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var un_sum := 0.0
	for y in int(a[1]):
		sim.run(12)
		var u := Legislature.unemployment(w)
		un_sum += u
		if (y + 1) % 5 == 0:
			print("Y%d pop=%d unemp=%.1f imm=%s food=%s itax=%s stax=%s runway=%.1f pe=%s pw=%s" % [y + 1, PopStore.total(w), u, str(w.levers.get("LAW_IMMIGRATION")), str(EconUtil.peek_st(w).get("food_shortfall", 0)),
				str(w.levers.get("ECON_INCOME_TAX_RATE")), str(w.levers.get("ECON_SALES_TAX")), Legislature._runway(w),
				str(w.levers.get("ECON_BUDGET_PUBLIC_EMPLOYMENT")), str(w.levers.get("ECON_BUDGET_PUBLIC_WORKS"))])
	print("MEAN_UNEMP %.1f" % (un_sum / float(int(a[1]))))
	quit(0)
