extends SceneTree
## Bob (Wilma's v9 on-list check): full game, v8 defaults + flags. args: seed years flags(comma list | base) arm_name
## One line: adults Y-end, means over Y5..end of unemployment, food shortfall, real income; income/sales tax at the end.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconFace.sim_make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			if not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	var n := 0
	var su := 0.0
	var sf := 0.0
	var sr := 0.0
	for m in int(a[1]) * 12:
		sim.run(1)
		if m < 60:
			continue
		var s := CoreUtil.st(w)
		n += 1
		su += float(EconFace.query_labour(w)["rate_pct"])
		sf += float(int(s.get("food_shortfall", 0)))
		var disp := 0
		var persons := 0
		for gid in w.table("hh"):
			disp += EconFace.households_disposable(w.table("hh")[gid])
			persons += EconFace.households_persons(w.table("hh")[gid])
		var basket := float(EconData.NEED["FOOD"]) * float(s["prices"]["FOOD"]) + float(EconData.NEED["CONSUMER_MIN"]) * float(s["prices"]["CONSUMER"])
		sr += float(disp) / maxf(1.0, float(persons) / 1000.0 * basket)
	var adults := 0
	for gid in w.table("hh"):
		var g: Dictionary = w.table("hh")[gid]
		adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
	var k := float(maxi(1, n))
	print("V9 %s s%s adults %d u %.1f food %.0f real %.2f tax %d/%d ledger %d" % [a[3], a[0], adults, su / k, sf / k, sr / k,
		int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"]), w.ledger.total()])
	quit()
