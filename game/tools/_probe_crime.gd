extends SceneTree
## Wilma A60 probe: crime indicators feed SAFETY / FAIRNESS. args: seed years
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if not w.meta.has("on"):
		w.meta["on"] = ["CRIME"]
	elif not (w.meta["on"] as Array).has("CRIME"):
		(w.meta["on"] as Array).append("CRIME")
	for y in int(a[1]):
		sim.run(12)
		var ds: Array = []
		for k in w.indicators.values.get("LAW_CRIME_INDEX", {}):
			ds.append(k)
		var line := "Y%d unemp=%.1f colony=%s" % [y + 1, Legislature.unemployment(w), str(preload("res://sim/law/law_query.gd").crime_rate(w))]
		for d in ds:
			line += " %s:ci=%d fr=%d" % [d, w.indicators.read("LAW_CRIME_INDEX", d) / 1000, w.indicators.read("LAW_FRAUD_RATE", d) / 1000]
		print(line)
	quit(0)
