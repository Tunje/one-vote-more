extends SceneTree
## Bob: full-game A/B (v9 base = EconSim.make defaults). args: seed years flags(comma | base; -FLAG removes) arm_name
## One "AB" line: adults at the end; means over Y5..end of unemployment, food shortfall, unaffordable / scarce food
## (S7F arms), food-assistance dependence, real income; taxes at the end; private firms: alive, dead, distress entries
## (and those profitable over 12 months), credit lines; private share of sales by good (Y5..end); ledger.
const GOODS := ["FOOD", "MATERIAL", "COMPONENT", "CONSUMER", "CLOTHING", "FURNISHINGS", "FINE_FOOD", "MINERAL"]


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
	var n := 0
	var su := 0.0
	var sf := 0.0
	var sua := 0.0
	var ssc := 0.0
	var sap := 0.0
	var sr := 0.0
	var sold_all := {}
	var sold_priv := {}
	for m in int(a[1]) * 12:
		sim.run(1)
		if m < 60:
			continue
		var s := EconUtil.st(w)
		n += 1
		su += float(EconQuery.labour(w)["rate_pct"])
		sf += float(int(s.get("food_shortfall", 0)))
		sua += float(int(s.get("food_unaff", 0)))
		ssc += float(int(s.get("food_scarce", 0)))
		sap += float(int(s.get("food_assist_pm", 0)))
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			disp += EconHouseholds.disposable(w.table("hh")[gid])
			persons += EconHouseholds.persons(w.table("hh")[gid])
		var basket := float(EconData.NEED["FOOD"]) * float(s["prices"]["FOOD"]) + float(EconData.NEED["CONSUMER_MIN"]) * float(s["prices"]["CONSUMER"])
		sr += float(disp) / maxf(1.0, float(persons) / 1000.0 * basket)
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			for g in o.get("sold", {}):
				var q := int(o["sold"][g])
				sold_all[g] = int(sold_all.get(g, 0)) + q
				if o["type"] in ["PRIVATE", "COOPERATIVE"]:
					sold_priv[g] = int(sold_priv.get(g, 0)) + q
	var adults := 0
	for gid in w.table("hh"):
		var g: Dictionary = w.table("hh")[gid]
		adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
	var alive := 0
	var dead := 0
	for oid in w.table("org"):
		var o: Dictionary = w.table("org")[oid]
		if o["type"] != "PRIVATE":
			continue
		if o["status"] in ["LIQUIDATION", "DISSOLVED"]:
			dead += 1
		else:
			alive += 1
	var lines := 0
	for lid in w.table("loan"):
		if bool(w.table("loan")[lid].get("revolving", false)) and int(w.table("loan")[lid]["principal"]) > 0:
			lines += 1
	var share := []
	for g in GOODS:
		if int(sold_all.get(g, 0)) > 0:
			share.append("%s:%d" % [g, 100 * int(sold_priv.get(g, 0)) / int(sold_all[g])])
	var s2 := EconUtil.st(w)
	var k := float(maxi(1, n))
	print("AB %s s%s adults %d u %.1f food %.0f unaff %.0f scarce %.0f assist %.0f real %.2f tax %d/%d priv alive %d dead %d distress %d pos12 %d lines %d share %s ledger %d" % [
		a[3], a[0], adults, su / k, sf / k, sua / k, ssc / k, sap / k, sr / k,
		int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"]), alive, dead,
		int(s2.get("distress_n", 0)), int(s2.get("distress_pos12_n", 0)), lines, ",".join(share), w.ledger.total()])
	quit()
