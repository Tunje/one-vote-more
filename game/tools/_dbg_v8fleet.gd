extends SceneTree
## Bob: v8 regression repro — chronicle defaults + FLEET, per 5 years: adults, buses, disruptions/yr, outages/yr, budget.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if not (w.meta["on"] as Array).has("FLEET"):
		(w.meta["on"] as Array).append("FLEET")
	if not (w.meta["on"] as Array).has("SUPPORT_T"):
		(w.meta["on"] as Array).append("SUPPORT_T")
	var dis := 0
	var outs := 0
	var seen := {}
	for m in int(a[1]) * 12:
		sim.run(1)
		for k in ["ECON_COMMUTE_DISRUPTION", "ECON_UTILITY_OUTAGE", "ECON_OUTAGE"]:
			for f in w.facts.query(k):
				if not seen.has(f["id"]):
					seen[f["id"]] = true
					if k == "ECON_COMMUTE_DISRUPTION":
						dis += 1
					else:
						outs += 1
		if (m + 1) % 60 != 0:
			continue
		var adults := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			adults += (int(g["lf"]) + int(g["nonpart"]) + int(g["owners"])) / 1000
		var s := EconUtil.st(w)
		var mx := 0
		for d in s.get("commute_absent_pm", {}):
			mx = maxi(mx, int(s["commute_absent_pm"][d]))
		print("s%s Y%d adults %d buses %d absent_max %d disruptions/5y %d outages/5y %d budget %d u %.1f%% famine %s" % [a[0], (m + 1) / 12, adults,
			w.table("bus").size(), mx, dis, outs, int(w.levers.get("ECON_BUDGET_PUBLIC_TRANSPORT", 0)), float(EconQuery.labour(w)["rate_pct"]), s.get("famine_now", false)])
		dis = 0
		outs = 0
	quit()
