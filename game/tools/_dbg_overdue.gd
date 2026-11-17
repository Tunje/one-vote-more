extends SceneTree
## Bob: E148 overdue invoices by buyer status and kind. args: seed months flags
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	for fl in a[2].split(","):
		(w.meta["on"] as Array).append(fl)
	for m in int(a[1]):
		sim.run(1)
		if m % 24 != 23:
			continue
		var by := {}
		var open := 0
		for iid in w.peek("invoice"):
			var inv: Dictionary = w.peek("invoice")[iid]
			open += int(inv["amount"])
			if int(inv["overdue_m"]) <= 0:
				continue
			var o: Dictionary = w.table("org").get(inv["buyer"], {})
			var k: String = "%s/%s/%s" % [o.get("type", "?"), o.get("status", "?"), "od" + str(mini(6, int(inv["overdue_m"])))]
			by[k] = int(by.get(k, 0)) + int(inv["amount"]) / 1000000
		print("Y%d open %dk | overdue by type/status/months: %s" % [m / 12 + 1, open / 1000000, JSON.stringify(by)])
	quit()
