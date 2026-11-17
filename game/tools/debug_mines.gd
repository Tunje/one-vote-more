extends SceneTree
func _initialize() -> void:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	sim.run(60)
	var w := sim.world
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] == "MINE":
			var o: Dictionary = w.table("org")[f["org"]]
			print(fid, " owner ", o["key"], " ", o["status"], " mothball ", f["mothball"], " abandoned ", f.get("abandoned", false), " T ", f["T"], " low_util_m ", f["low_util_m"], " licensed ", f["licensed"])
			print("   ", EconQuery.explain_facility(w, fid)["causes"])
	print("MIN price ", EconUtil.st(w)["prices"]["MINERAL"], " stocks ", EconUtil.inv_sum(w, "MINERAL"))
	quit(0)
