extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	for fl in ["E146", "E147"]:
		(w.meta["on"] as Array).append(fl)
	for m in 120:
		sim.run(1)
		if m % 12 != 11:
			continue
		var s := EconUtil.st(w)
		var ents := {}
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			if o.has("entry_type"):
				var k: String = "%s:%s" % [o["entry_type"], o["status"]]
				ents[k] = int(ents.get(k, 0)) + 1
		print("y%d sig %s fail %s uc_bak %d ffpx %d forming? ents %s" % [m / 12 + 1, JSON.stringify(s.get("entry_signal", {})), JSON.stringify(s.get("entry_fail", {})),
			int(FirmAI.unit_cost(w, "BAKERY")), int(s["prices"]["FINE_FOOD"]), JSON.stringify(ents)])
	quit()
