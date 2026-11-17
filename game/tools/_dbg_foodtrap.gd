extends SceneTree
## Bob: small probe. args: seed years flags(comma|base) from_year. Yearly food-chain detail from from_year.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			if not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	var from := int(a[3])
	for y in int(a[1]):
		sim.run(12)
		if y + 1 < from:
			continue
		var es: Dictionary = EconQuery.essentials(w)["FOOD"]
		var farms := 0
		var moth := 0
		var causes := {}
		var care_staff := 0
		var farm_staff := 0
		for fid in EconUtil.sorted_keys(w.peek("facility")):
			var f: Dictionary = w.peek("facility")[fid]
			var ft: String = f["type"]
			if ft in ["ELDERCARE", "CHILDCARE"]:
				for t in f["staff"]:
					care_staff += int(EconLabor.tier_total(f["staff"], t)) / 1000
			if ft != "FARM":
				continue
			farms += 1
			if f["mothball"]:
				moth += 1
			for t in ["U", "S", "G"]:
				farm_staff += int(EconLabor.tier_total(f["staff"], t)) / 1000
			for c in EconQuery.explain_facility(w, fid)["causes"]:
				var cn: String = c["cause"]
				causes[cn] = int(causes.get(cn, 0)) + 1
		var s := EconUtil.st(w)
		var ms: Dictionary = s.get("market_stats", {}).get("FOOD", {})
		print("Y%d farms %d moth %d farm_staff %d care_staff %d cap %s dem %s margin %s%% fill %s offered %d wanted %d filled %d px %d u %.1f causes %s" % [y + 1, farms, moth, farm_staff, care_staff,
			str(es["capacity"]), str(es["demand"]), str(es["margin_pct"]), str(es["labour_fill"]),
			int(ms.get("S", 0)) / 1000, int(ms.get("wanted", 0)) / 1000, int(ms.get("filled", 0)) / 1000, int(s["prices"]["FOOD"]),
			float(EconQuery.labour(w)["rate_pct"]), JSON.stringify(causes)])
	quit()
