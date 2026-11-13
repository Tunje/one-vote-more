extends SceneTree
## Wilma: real staffing by facility type at given years. args: seed years(comma)
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var done := 0
	for y in String(a[1]).split(","):
		sim.run(int(y) * 12 - done)
		done = int(y) * 12
		var by := {}
		for fid in EconUtil.sorted_keys(w.table("facility")):
			var f: Dictionary = w.table("facility")[fid]
			var t := String(f["type"])
			if not by.has(t):
				by[t] = {"n": 0, "on": 0, "G": 0, "S": 0, "Sp": 0, "scale": 0}
			by[t]["n"] += 1
			if not f.get("mothball", false):
				by[t]["on"] += 1
			by[t]["scale"] += int(f.get("scale", 1000))
			for tier in ["G", "S", "Sp"]:
				by[t][tier] += EconLabor.tier_total(f.get("staff", {}), tier) / 1000
		var crews := {"G": 0, "S": 0, "Sp": 0}
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			for tier in ["G", "S", "Sp"]:
				crews[tier] += EconLabor.tier_total(o.get("crew", {}), tier) / 1000
		var L: Dictionary = EconQuery.labour(w)
		print("=== Year %s  residents %d  labour force %d  employed %d  unemployed %d (%.1f%%)" % [y, PopStore.total(w), int(L["labour_force"]), int(L["employed"]), int(L["unemployed"]), float(L["rate_pct"])])
		print("type | facilities (running) | G | S | Sp | total staff | staff per running facility")
		var tot := 0
		for t in EconUtil.sorted_keys(by):
			var b: Dictionary = by[t]
			var st: int = int(b["G"]) + int(b["S"]) + int(b["Sp"])
			tot += st
			print("%s | %d (%d) | %d | %d | %d | %d | %.1f" % [t, b["n"], b["on"], b["G"], b["S"], b["Sp"], st, float(st) / maxf(1.0, float(b["on"]))])
		print("CONSTRUCTION CREWS | - | %d | %d | %d | %d |" % [crews["G"], crews["S"], crews["Sp"], crews["G"] + crews["S"] + crews["Sp"]])
		print("TOTAL in facilities %d + crews %d" % [tot, crews["G"] + crews["S"] + crews["Sp"]])
	quit(0)
