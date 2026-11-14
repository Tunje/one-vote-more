extends SceneTree
## Bob: E139 full-game A/B. args: seed years [E139]. Prints Y10/20/30 and means over Y5..end.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var arm := "v8"
	if a.size() > 2:
		(w.meta["on"] as Array).append(a[2])
		arm = "E139"
	var n := 0
	var sums := {"u": 0.0, "food": 0.0, "real": 0.0, "cons_ratio": 0.0, "food_ratio": 0.0}
	for m in int(a[1]) * 12:
		sim.run(1)
		var s := EconUtil.st(w)
		if m < 60:
			continue
		n += 1
		sums["u"] += float(EconQuery.labour(w)["rate_pct"])
		sums["food"] += float(int(s.get("food_shortfall", 0)))
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			disp += EconHouseholds.disposable(w.table("hh")[gid])
			persons += EconHouseholds.persons(w.table("hh")[gid])
		var basket := float(EconData.NEED["FOOD"]) * float(s["prices"]["FOOD"]) + float(EconData.NEED["CONSUMER_MIN"]) * float(s["prices"]["CONSUMER"])
		sums["real"] += float(disp) / maxf(1.0, float(persons) / 1000.0 * basket)
		var cc := EconMarket._cheapest_cost(w, "CONSUMER")
		var fc := EconMarket._cheapest_cost(w, "FOOD")
		sums["cons_ratio"] += float(s["prices"]["CONSUMER"]) / maxf(1.0, cc) if cc > 0.0 else 0.0
		sums["food_ratio"] += float(s["prices"]["FOOD"]) / maxf(1.0, fc) if fc > 0.0 else 0.0
		if (m + 1) % 120 == 0:
			var adults := 0
			for gid in w.table("hh"):
				var g: Dictionary = w.table("hh")[gid]
				adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
			var pe := 0
			for oid in w.table("org"):
				if w.table("org")[oid]["type"] == "PUBLIC_ENTERPRISE":
					pe += w.ledger.balance(EconUtil.acct(oid))
			print("%s s%s Y%d adults %d u %.1f%% food %d‰ treasury %dM PE cash %dM tax %d/%d" % [arm, a[0], (m + 1) / 12, adults, float(EconQuery.labour(w)["rate_pct"]),
				int(s.get("food_shortfall", 0)), w.ledger.balance(EconUtil.TREASURY) / 1000000000, pe / 1000000000, int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"])])
	var k := float(maxi(1, n))
	print("%s s%s MEANS u %.1f%% food %.0f‰ real income %.2f consumer price/cost %.2f food price/cost %.2f" % [arm, a[0], sums["u"] / k, sums["food"] / k,
		sums["real"] / k, sums["cons_ratio"] / k, sums["food_ratio"] / k])
	quit()
