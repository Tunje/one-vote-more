extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for y in [5, 15, 25]:
		sim.run(y * 12 - w.month)
		var by := {}
		var orgs := {}
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "SERVICEHUB" and not f["mothball"]:
				var o: Dictionary = w.table("org")[f["org"]]
				var k := "%s/%s" % [o["type"], f["district"]]
				by[k] = int(by.get(k, 0)) + int(f.get("svc_sold", 0)) / 1000
				orgs[f["org"]] = o["type"]
		var types := {}
		for oid in w.table("org"):
			var o2: Dictionary = w.table("org")[oid]
			if o2["status"] in ["LIQUIDATION", "DISSOLVED"]:
				continue
			types[o2["type"]] = int(types.get(o2["type"], 0)) + 1
		var dead := 0
		for oid in w.table("org"):
			if w.table("org")[oid]["status"] in ["LIQUIDATION", "DISSOLVED"] and w.table("org")[oid]["type"] in ["PRIVATE", "COOPERATIVE"]:
				dead += 1
		print("Y%d hub sales by owner/district %s | hub orgs %s | live orgs by type %s | dead private %d" % [y, by, orgs, types, dead])
	quit()
