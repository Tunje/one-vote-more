extends SceneTree
func _initialize() -> void:
	var sim := EconSim.make_econ_only(1)
	sim.run(17)
	var w := sim.world
	for oid in EconUtil.sorted_keys(w.table("org")):
		var o: Dictionary = w.table("org")[oid]
		if not o["is_contractor"]:
			continue
		for pid in o["contracts"]:
			var p: Dictionary = w.table("project")[pid]
			var months_left := maxi(1, p["start_month"] + p["bid_duration"] - w.month)
			var rate := minf(float(p["wu_total"] - p["wu_done"]) / float(months_left), float(p["wu_total"]) / float(p["min_months"]))
			print(o["key"], " ", pid, " status ", p["status"], " mat_total ", p["mat_total"], " wu_total ", p["wu_total"], " rate ", rate, " months_left ", months_left, " monthly_costs ", EconFinance._monthly_costs(o), " cash ", w.ledger.balance(EconUtil.acct(oid)))
	quit(0)
