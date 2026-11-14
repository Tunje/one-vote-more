extends SceneTree
## temp (Bob, backlog 18): material chain with S7 on/off. args: seed from to on|off
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[3] == "on":
		w.meta["on"] = ["S7"]
	sim.run(int(a[1]) * 12)
	var dep0 := int(w.values.get("pop_departures", 0))
	for y in range(int(a[1]), int(a[2]) + 1):
		var parts := []
		for ft in ["PROCESSING", "COMPONENTS", "MINE"]:
			var n := 0; var st := 0; var rq := 0; var out := 0
			for fid in w.table("facility"):
				var f: Dictionary = w.table("facility")[fid]
				if f["type"] != ft or f["mothball"]:
					continue
				n += 1
				st += EconLabor.staff_total(f["staff"])
				var r := EconLabor.required(f)
				for t in r:
					rq += int(r[t])
				out += int(f.get("out_last", 0))
			parts.append("%s n%d staff %d/%d out %d" % [ft.substr(0, 4), n, st / 1000, rq / 1000, out / 1000])
		var s := EconUtil.st(w)
		var dep := int(w.values.get("pop_departures", 0))
		print("Y%d %s | MAT price %d COMP %d | departures this year %d | shacks %s" % [y, " | ".join(parts), int(s["prices"]["MATERIAL"]) / 1000, int(s["prices"]["COMPONENT"]) / 1000, dep - dep0, str(EconInformal.summary(w))])
		dep0 = dep
		sim.run(12)
	quit()
