extends SceneTree
## Bob (diagnosis 5): builders over time — crew, active contracts, cash, wages vs revenue, status; idle months.
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	var idle := {}
	var months := {}
	for m in 240:
		sim.run(1)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if not o["is_contractor"] or o["status"] in ["LIQUIDATION", "DISSOLVED"]:
				continue
			var active := 0
			for q in o["contracts"]:
				if w.table("project").has(q) and w.table("project")[q]["status"] == "ACTIVE":
					active += 1
			months[oid] = int(months.get(oid, 0)) + 1
			if active == 0:
				idle[oid] = int(idle.get(oid, 0)) + 1
		if (m + 1) % 24 != 0:
			continue
		var line := "Y%d" % ((m + 1) / 12)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if not o["is_contractor"]:
				continue
			var active2 := 0
			for q in o["contracts"]:
				if w.table("project").has(q) and w.table("project")[q]["status"] == "ACTIVE":
					active2 += 1
			var pl: Dictionary = o.get("pl_last", {})
			line += " | %s %s %s crew %d act %d cash %dk rev %dk wages %dk idle %d/%d" % [oid, String(o["type"]).substr(0, 4), String(o["status"]).substr(0, 4),
				EconLabor.staff_total(o["crew"]) / 1000, active2, w.ledger.balance(EconUtil.acct(oid)) / 1000000, int(pl.get("rev", 0)) / 1000000,
				int(pl.get("wages", 0)) / 1000000, int(idle.get(oid, 0)), int(months.get(oid, 0))]
		var waiting := 0
		for pid in w.table("project"):
			if w.table("project")[pid]["status"] in ["TENDER", "TENDERABLE"]:
				waiting += 1
		print(line, " | waiting projects ", waiting)
	quit()
