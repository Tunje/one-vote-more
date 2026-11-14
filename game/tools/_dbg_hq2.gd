extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	(w.meta["on"] as Array).append("SUPPORT_B")
	for m in 30:
		sim.run(1)
		if m % 6 != 5:
			continue
		var s := EconUtil.st(w)
		for oid in EconUtil.sorted_keys(w.table("org")):
			var o: Dictionary = w.table("org")[oid]
			if String(o.get("key", "")).begins_with("HQ|"):
				var f := EconHQ._site(w, oid)
				print("m%d %s %s cash %dk funder %dk ema %dk cost %d posts %d staff %d" % [m + 1, o["key"], o["hq_type"], w.ledger.balance(EconUtil.acct(oid)) / 1000000,
					w.ledger.balance(o["funder"]) / 1000000, int(s.get("news_paid_ema", {}).get(oid, 0)) / 1000000, EconHQ._post_cost(w, oid, o["hq_type"]) / 1000,
					int(f.get("hq_posts", 0)), EconLabor.staff_total(f["staff"]) / 1000])
	quit()
