extends SceneTree
func _init() -> void:
	var sim := EconSim.make(1)
	var w := sim.world
	print("famine flag month: ")
	for y in 20:
		sim.run(12)
		var s := EconUtil.st(w)
		var farms := 0
		var fout := 0
		var mb := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "FARM":
				farms += 1
				fout += f["out_last"] / 1000
				mb += 1 if f["mothball"] else 0
		var need := 0
		for gid in w.table("hh"):
			need += int(EconHouseholds.persons(w.table("hh")[gid]) * EconData.NEED["FOOD"]) / 1000
		var res := EconUtil.inv_get(w, "gov", "FOOD", "d:1") / 1000
		var resm := EconUtil.inv_get(w, "gov", "MATERIAL", "d:1") / 1000
		var stocks := {}
		for g in ["MATERIAL", "COMPONENT"]:
			stocks[g] = EconUtil.inv_sum(w, g) / 1000
		print("y%d pop %d farms %d(mb%d) food_out %d need %d short %d famine %s pFood %d | E %d/%d W %d/%d | reserve F%d M%d | stocks %s pMat %d pComp %d | treas %dk" % [y + 1, PopStore.total(w), farms, mb, fout, need, s["food_shortfall"], str(s["famine"]),
			s["prices"]["FOOD"] / 1000, s["util_supply"]["E"] / 1000, s["util_demand"]["E"] / 1000, s["util_supply"]["W"] / 1000, s["util_demand"]["W"] / 1000, res, resm, str(stocks),
			s["prices"]["MATERIAL"] / 1000, s["prices"]["COMPONENT"] / 1000, w.ledger.balance(EconUtil.TREASURY) / 1000000])
	quit()
