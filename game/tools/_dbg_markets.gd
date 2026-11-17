extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for y in [5, 15, 25]:
		sim.run(y * 12 - w.month)
		print("== Y%d" % y)
		for good in EconMarket.CLEAR_ORDER:
			var tot := 0
			var rows: Array = []
			for oid in EconUtil.sorted_keys(w.table("org")):
				var o: Dictionary = w.table("org")[oid]
				var q := int(o.get("sold", {}).get(good, 0))
				if q > 0:
					tot += q
					rows.append([q, "%s(%s,%s,risk%d)" % [oid, String(o["type"]).substr(0, 4), String(o["status"]).substr(0, 4), int(o["ceo"].get("risk", 0))]])
			rows.sort_custom(func(a, b): return a[0] > b[0])
			var line := "%s total %d:" % [good, tot / 1000]
			for r in rows:
				line += " %s %d‰" % [r[1], int(r[0]) * 1000 / maxi(1, tot)]
			print(line)
	quit()
