extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	(w.meta["on"] as Array).append_array(["E136", "E137", "E138"])
	for y in [3, 6, 10, 15]:
		sim.run(y * 12 - w.month)
		var s := EconUtil.st(w)
		var line := "Y%d" % y
		for good in ["CLOTHING", "FURNISHINGS", "FINE_FOOD", "CONSUMER"]:
			var m: Dictionary = s.get("market_stats", {}).get(good, {})
			var ws := ""
			for ft in EconConsumer.WORKSHOPS:
				if EconConsumer.WORKSHOPS[ft] == good:
					ws = ft
			var uc := int(FirmAI.unit_cost(w, ws)) / 1000 if ws != "" else int(FirmAI.unit_cost(w, "CONSUMERF")) / 1000
			var sellers := 0
			for fid in w.table("facility"):
				var f: Dictionary = w.table("facility")[fid]
				if (f["type"] == ws or (ws == "" and f["type"] == "CONSUMERF")) and not f["mothball"]:
					sellers += 1
			line += " | %s wanted %d filled %d price %d base %d unitcost %d plants %d" % [good, int(m.get("wanted", 0)) / 1000, int(m.get("filled", 0)) / 1000,
				int(s["prices"].get(good, 0)) / 1000, int(s["base"].get(good, 0)) / 1000, uc, sellers]
		print(line)
	quit()
