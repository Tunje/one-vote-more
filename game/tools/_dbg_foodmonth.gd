extends SceneTree
## Bob: S7 probe. args: seed years flags(comma|base; -FLAG removes) from_year. Monthly FOOD: need / ordered (budget-capped)
## / wanted / filled / offered / stock / farm target & util / price vs unit cost / aid.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			if fl.begins_with("-"):
				(w.meta["on"] as Array).erase(fl.substr(1))
			elif not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	var from := int(a[3])
	if a.size() > 4:  # LEVER=VALUE[,LEVER=VALUE]
		for kv in a[4].split(","):
			w.levers[kv.split("=")[0]] = int(kv.split("=")[1])
	for m in int(a[1]) * 12:
		sim.run(1)
		if m + 1 < from * 12 - 11:
			continue
		var s := EconUtil.st(w)
		var need := 0
		for gid in w.table("hh"):
			need += EconHouseholds.persons(w.table("hh")[gid]) * int(EconData.NEED["FOOD"])
		var ordered := 0
		var org_ord := 0
		for o in s["orders"]:
			if o["good"] == "FOOD":
				if o["kind"] == "hh":
					ordered += int(o["qty"])
				else:
					org_ord += int(o["qty"])
		var stock := 0
		for k in w.peek("inv"):
			if String(k).split("|")[1] == "FOOD":
				stock += int(w.peek("inv")[k]["q"])
		var tsum := 0
		var usum := 0
		var n := 0
		var cap := 0
		for fid in w.peek("facility"):
			var f: Dictionary = w.peek("facility")[fid]
			if f["type"] == "FARM" and not f["mothball"]:
				n += 1
				tsum += int(f["T"])
				usum += int(f["util"])
		var ms: Dictionary = s.get("market_stats", {}).get("FOOD", {})
		print("M%d Y%d short %d‰ need %d ordered %d (%d%%) org %d | wanted %d filled %d offered %d | stock %d (%.1f mo) | farms %d T %d‰ util %d‰ | px %d base %d | unaff %d scarce %d assist %dk hh %d lever %d" % [m + 1, m / 12 + 1,
			int(s.get("food_shortfall", 0)), need / 1000, ordered / 1000, 100 * ordered / maxi(1, need), org_ord / 1000,
			int(ms.get("wanted", 0)) / 1000, int(ms.get("filled", 0)) / 1000, int(ms.get("S", 0)) / 1000,
			stock / 1000, float(stock) / maxf(1.0, float(need)), n, tsum / maxi(1, n), usum / maxi(1, n), int(s["prices"]["FOOD"]), int(s["base"]["FOOD"]),
			int(s.get("food_unaff", -1)), int(s.get("food_scarce", -1)), int(s.get("food_assist_m", 0)) / 1000000, int(s.get("food_assist_hh", 0)),
			int(w.levers.get("ECON_FOOD_ASSISTANCE", -1))])
	quit()
