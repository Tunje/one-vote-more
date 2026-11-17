extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	w.meta["on"] = ["M2"]
	var prev := EconBank.capital(w)
	for m in 150:
		w.levers["ECON_INCOME_TAX_RATE"] = 24
		w.levers["ECON_SALES_TAX"] = 8
		var before := {}
		for lid in w.table("loan"):
			before[lid] = int(w.table("loan")[lid]["principal"])
		sim.run(1)
		var cap := EconBank.capital(w)
		if prev - cap > 500000000:
			var line := "m%d capital %dk → %dk:" % [m + 1, prev / 1000000, cap / 1000000]
			for lid in EconUtil.sorted_keys(before):
				var l: Dictionary = w.table("loan").get(lid, {})
				var now := int(l.get("principal", 0))
				if int(before[lid]) - now > 300000000:
					line += " %s %s %dk→%dk" % [lid, l.get("borrower", "?"), int(before[lid]) / 1000000, now / 1000000]
			var flows := {}
			for e in w.ledger.journal:
				if int(e["m"]) == w.month - 1 and (e["from"] == "bank" or e["to"] == "bank"):
					var k := "%s %s→%s" % [e["memo"], String(e["from"]).substr(0, 4), String(e["to"]).substr(0, 4)]
					flows[k] = int(flows.get(k, 0)) + int(e["amt"]) / 1000000
			print(line, " flows ", flows)
		prev = cap
	quit()
