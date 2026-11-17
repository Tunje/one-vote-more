extends SceneTree
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	w.meta["on"] = ["SUPPORT_T", "FLEET"]
	for m in 36:
		sim.run(1)
		if m % 3 != 2:
			continue
		var s := EconUtil.st(w)
		var riders := 0
		for r in s.get("commute_rows", []):
			riders += int(r["bus_commuters"])
		var cta := EconFinance.org_by_key(w, "CTA")
		print("m%d buses %d riders %d cap %d comp_stock %d price %d fare_ema %d absent %s spent %d" % [m, w.table("bus").size(), riders,
			w.table("bus").size() * 65, EconUtil.inv_get(w, cta, "COMPONENT", "d:1") / 1000, int(s["prices"]["COMPONENT"]) / 1000,
			int(s.get("fare_rev_ema", 0)) / 1000, s.get("commute_absent_pm", {}), int(s["spent_ytd"].get("ECON_BUDGET_PUBLIC_TRANSPORT", 0)) / 1000])
	quit()
