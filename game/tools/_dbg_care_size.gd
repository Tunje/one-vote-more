extends SceneTree
func _init() -> void:
	var sim := EconSim.make_econ_only(1)
	var w := sim.world
	for y in [1, 10, 20, 30]:
		sim.run(y * 12 - w.month)
		var ret := 0
		var kids := 0
		var pop := 0
		var np := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			ret += int(g["retired"]) / 1000
			pop += EconHouseholds.persons(g) / 1000
			np += int(g["nonpart"]) / 1000
		for d in EconData.DISTRICTS:
			var h := EconCohorts.histogram(w, d)
			if h.is_empty():
				continue
			for a in range(1, 6):
				kids += int(h[a])
		print("Y%d pop %d retired %d kids1-5 %d nonpart %d wageG %d S %d" % [y, pop, ret, kids, np, int(EconUtil.st(w)["wage"]["G"]) / 1000, int(EconUtil.st(w)["wage"]["S"]) / 1000])
	quit()
