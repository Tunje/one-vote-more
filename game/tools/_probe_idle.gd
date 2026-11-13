extends SceneTree
## Wilma A61 probe: idle treasury money. args: seed years [off-list]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2 and a[2] != "-":
		w.meta["off"] = Array(a[2].split(","))
	var un_sum := 0.0
	for y in int(a[1]):
		sim.run(12)
		var u := Legislature.unemployment(w)
		un_sum += u
		if (y + 1) % 10 == 0:
			var hh := 0
			var tot := 0
			for acc in w.ledger.balances:
				var b := int(w.ledger.balances[acc])
				if str(acc).begins_with("hh:"):
					hh += b
				if b > 0:
					tot += b
			var tr := int(w.ledger.balances.get(EconUtil.TREASURY, 0))
			print("Y%d pop=%d unemp=%.1f runway=%.1f treasury=%dM (%d%%) hh=%dM wageG=%d itax=%s stax=%s pe=%s pw=%s" % [y + 1, PopStore.total(w), u, Legislature._runway(w), tr / 1000000, 100 * tr / maxi(1, tot), hh / 1000000, int(EconUtil.st(w)["wage"]["G"]) / 1000,
				str(w.levers.get("ECON_INCOME_TAX_RATE")), str(w.levers.get("ECON_SALES_TAX")), str(w.levers.get("ECON_BUDGET_PUBLIC_EMPLOYMENT")), str(w.levers.get("ECON_BUDGET_PUBLIC_WORKS"))])
	print("MEAN_UNEMP %.1f" % (un_sum / float(int(a[1]))))
	quit(0)
