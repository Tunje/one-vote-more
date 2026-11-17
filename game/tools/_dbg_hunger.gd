extends SceneTree
## temp (Bob): why households go hungry with spare food capacity. args: seed from_year to_year step_years variant(base|old)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 4 and a[4] == "s7on":
		w.meta["on"] = ["S7"]
	if a.size() > 4 and a[4] == "old":
		w.lever_defs["ECON_BUDGET_PUBLIC_EMPLOYMENT"]["range"] = [0, 5000]
		w.lever_defs["ECON_BUDGET_PUBLIC_EMPLOYMENT"]["ideology"] = {"ECON_ROLE": 0.008, "FISCAL": 0.008, "LABOR": 0.006}
	sim.run(int(a[1]) * 12)
	var y := int(a[1])
	while y <= int(a[2]):
		var s := EconUtil.st(w)
		var by := {}
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			var b: String = g["band"]
			var p := EconHouseholds.persons(g)
			var row: Array = by.get(b, [0, 0, 0, 0])
			row[0] += int(p * EconData.NEED["FOOD"])
			row[1] += int(g.get("unmet", {}).get("FOOD", 0))
			row[2] += w.ledger.balance(EconUtil.hh_acct(gid))
			row[3] += p
			by[b] = row
		var aid := 0
		var rent := 0
		for gid in w.table("hh"):
			rent += int(w.table("hh")[gid].get("rent_paid", 0))
		var parts := []
		for b in EconUtil.sorted_keys(by):
			var r: Array = by[b]
			parts.append("%s unmet %d%% persons %d cash/p %d" % [b, int(100.0 * float(r[1]) / maxf(1.0, float(r[0]))), int(r[3]) / 1000, int(float(r[2]) / maxf(1.0, float(r[3]))) ])
		var stock := 0
		for k in s.get("inv", {}):
			if str(k).contains("|FOOD|"):
				stock += int(s["inv"][k])
		print("Y%d food price %d base %d | shortfall %d‰ | income tax %s sales %s benefit floor %s food assist %s | treasury %d debt default %s | PES %s posts %d | wage G %d | %s" % [y,
			int(s["prices"]["FOOD"]) / 1000, int(s["base"]["FOOD"]) / 1000, int(s.get("food_shortfall", 0)), str(w.levers.get("ECON_INCOME_TAX_RATE")), str(w.levers.get("ECON_SALES_TAX")),
			str(w.levers.get("ECON_BENEFIT_FLOOR")), str(w.levers.get("ECON_FOOD_ASSISTANCE")), w.ledger.balance(EconUtil.TREASURY) / 1000, str(s.get("sovereign_default", false)),
			str(w.levers.get("ECON_BUDGET_PUBLIC_EMPLOYMENT")), EconPublicJobs.posts(w), int(s["wage"]["G"]) / 1000, " | ".join(parts)])
		sim.run(int(a[3]) * 12)
		y += int(a[3])
	quit()
