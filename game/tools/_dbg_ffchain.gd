extends SceneTree
## Bob: E146 food chain by year. args: seed years flags
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	for fl in a[2].split(","):
		(w.meta["on"] as Array).append(fl)
	var acc := {}
	for m in int(a[1]) * 12:
		sim.run(1)
		var s := EconUtil.st(w)
		var fb := 0
		for k in s.get("food_buyers_m", {}):
			fb += int(s["food_buyers_m"][k])
		var ffout := 0
		var nb := 0
		var bin := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "BAKERY" and not f["mothball"]:
				nb += 1
				ffout += int(f.get("out_last", 0))
				bin += EconUtil.inv_get(w, f["org"], "FOOD", f["district"])
		var ffg := 0
		var ffo := 0
		var hhfood := 0
		var need := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			ffg += int(g.get("ff_got", 0))
			ffo += int(g.get("ff_ord", 0))
			hhfood += int(g["bought"].get("FOOD", 0))
			need += int(EconHouseholds.persons(g) * EconData.NEED["FOOD"])
		for k in ["fb", "ffout", "ffg", "ffo", "hhfood", "need", "short"]:
			pass
		acc["fb"] = int(acc.get("fb", 0)) + fb
		acc["ffout"] = int(acc.get("ffout", 0)) + ffout
		acc["ffg"] = int(acc.get("ffg", 0)) + ffg
		acc["ffo"] = int(acc.get("ffo", 0)) + ffo
		acc["hh"] = int(acc.get("hh", 0)) + hhfood
		acc["need"] = int(acc.get("need", 0)) + need
		acc["short"] = int(acc.get("short", 0)) + int(s["food_shortfall"])
		if m % 12 == 11:
			var farm := 0
			for fid in w.table("facility"):
				if w.table("facility")[fid]["type"] == "FARM" and not w.table("facility")[fid]["mothball"]:
					farm += 1
			print("Y%d farms %d bak %d binv %d | need %d hhFOOD %d staple ord %d got %d | bakery FOOD bought %d FF out %d | short %d‰ FOODpx %d FFpx %d raw %d" % [m / 12 + 1, farm, nb, bin / 1000,
				int(acc["need"]) / 12000, int(acc["hh"]) / 12000, int(acc["ffo"]) / 12000, int(acc["ffg"]) / 12000, int(acc["fb"]) / 12000, int(acc["ffout"]) / 12000, int(acc["short"]) / 12,
				int(s["prices"]["FOOD"]) / 1000, int(s["prices"]["FINE_FOOD"]) / 1000, int(s.get("raw_food", 0))])
			acc = {}
	quit()
