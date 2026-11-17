extends SceneTree
## Bob: small probe. args: seed years flags(comma|base). Yearly adults, unemployment, food shortfall, care access, treasury.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a[2] != "base":
		for fl in a[2].split(","):
			if not (w.meta["on"] as Array).has(fl):
				(w.meta["on"] as Array).append(fl)
	for y in int(a[1]):
		var sf := 0
		for m in 12:
			sim.run(1)
			sf += int(EconUtil.st(w).get("food_shortfall", 0))
		var adults := 0
		var kids := 0
		var elders := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
			kids += int(g.get("kids", 0)) / 1000
			elders += int(g.get("elders", 0)) / 1000
		var s := EconUtil.st(w)
		print("Y%d adults %d kids %d elders %d u %.1f food %d treas %dM food_px %d tax %d/%d eldline %d chline %d" % [y + 1, adults, kids, elders,
			float(EconQuery.labour(w)["rate_pct"]), sf / 12, w.ledger.balance("gov:treasury") / 1000000,
			int(s["prices"]["FOOD"]), int(w.levers["ECON_INCOME_TAX_RATE"]), int(w.levers["ECON_SALES_TAX"]),
			int(w.levers.get("ECON_BUDGET_ELDER_CARE", -1)), int(w.levers.get("ECON_BUDGET_CHILDCARE", -1))])
	quit()
