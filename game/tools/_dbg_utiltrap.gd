extends SceneTree
## Bob: S7 probe. args: seed years flags(comma|base) from_year. Yearly food + energy + water chain (v9 base = EconSim.make defaults).
func _plants(w: WorldState, ftype: String) -> String:
	var n := 0
	var moth := 0
	var cond := 0
	var util := 0
	var causes := {}
	for fid in EconUtil.sorted_keys(w.peek("facility")):
		var f: Dictionary = w.peek("facility")[fid]
		if f["type"] != ftype:
			continue
		n += 1
		if f["mothball"]:
			moth += 1
		cond += int(f["condition"]) / 1000
		util += int(f["util"])
		for c in EconQuery.explain_facility(w, fid)["causes"]:
			var cn: String = c["cause"]
			causes[cn] = int(causes.get(cn, 0)) + 1
	return "%s n%d moth%d cond%d util%d‰ %s" % [ftype, n, moth, cond / maxi(1, n), util / maxi(1, n), JSON.stringify(causes)]

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
	for y in int(a[1]):
		var sf := 0
		for m in 12:
			sim.run(1)
			sf += int(EconUtil.st(w).get("food_shortfall", 0))
		if y + 1 < from:
			continue
		var s := EconUtil.st(w)
		var es: Dictionary = EconQuery.essentials(w)
		var proj := {}
		for p in EconQuery.projects(w, ""):
			if p["status"] in ["ACTIVE", "TENDER", "OPEN", "AWARDED"]:
				var k: String = "%s:%s" % [p["type"], p["status"]]
				proj[k] = int(proj.get(k, 0)) + 1
		print("Y%d food %d‰ px %d treas %dM | E sup %d dem %d | W sup %d dem %d | FOODcap %s dem %s" % [y + 1, sf / 12, int(s["prices"]["FOOD"]),
			w.ledger.balance("gov:treasury") / 1000000000, int(s.get("util_supply", {}).get("E", 0)) / 1000, int(s.get("util_demand", {}).get("E", 0)) / 1000,
			int(s.get("util_supply", {}).get("W", 0)) / 1000, int(s.get("util_demand", {}).get("W", 0)) / 1000,
			str(int(es["FOOD"]["capacity"])), str(int(es["FOOD"]["demand"]))])
		print("   ", _plants(w, "POWER"), " | ", _plants(w, "WATERWORKS"))
		print("   ", _plants(w, "FARM"), " | proj ", JSON.stringify(proj))
	quit()
