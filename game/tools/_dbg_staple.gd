extends SceneTree
## Bob: E146 monthly food flows. args: seed months flags
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			(w.meta["on"] as Array).append(fl)
	for m in int(a[1]):
		sim.run(1)
		if m + 1 < 58 or m + 1 > 72:
			continue
		var s := EconUtil.st(w)
		var need := 0
		var food := 0
		var ffo := 0
		var ffg := 0
		var cash := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			need += int(EconHouseholds.persons(g) * EconData.NEED["FOOD"])
			food += int(g["bought"].get("FOOD", 0))
			ffo += int(g.get("ff_ord", 0))
			ffg += int(g.get("ff_got", 0))
			cash += w.ledger.balance(EconUtil.hh_acct(gid))
		var fb := 0
		for k in s.get("food_buyers_m", {}):
			fb += int(s["food_buyers_m"][k])
		var bak := ""
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["type"] == "BAKERY":
				bak += " %s:T%d,u%d,in%d" % [fid, int(f["T"]), int(f["util"]), EconUtil.inv_get(w, f["org"], "FOOD", f["district"]) / 1000]
		var farm_out := 0
		for fid in w.table("facility"):
			var f2: Dictionary = w.table("facility")[fid]
			if f2["type"] == "FARM" and not f2["mothball"]:
				farm_out += int(f2.get("out_last", 0))
		print("   orgfood %d farmout %d bak%s" % [fb / 1000, farm_out / 1000, bak])
		var ms: Dictionary = s.get("market_stats", {}).get("FOOD", {})
		print("m%d short %d need %d food %d ffo %d ffg %d | FOOD px %d S %d D %d filled %d wanted %d | FF px %d | hhcash %dk" % [m + 1, int(s["food_shortfall"]), need / 1000, food / 1000, ffo / 1000, ffg / 1000,
			int(s["prices"]["FOOD"]), int(ms.get("S", 0)) / 1000, int(ms.get("D", 0)) / 1000, int(ms.get("filled", 0)) / 1000, int(ms.get("wanted", 0)) / 1000, int(s["prices"].get("FINE_FOOD", 0)), cash / 1000000])
	quit()
