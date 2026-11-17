extends SceneTree
## Wilma: how governments respond to essentials shortfalls (A39/E110). Prints per-5-year counts.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var years := int(args[0]) if args.size() > 0 else 30
	var seed := int(args[1]) if args.size() > 1 else 1
	var sim: Simulation = EconSim.make(seed, "BALANCED", {}, true)
	var w: WorldState = sim.world
	var famine := 0
	for m in years * 12:
		sim.step()
		var s: Dictionary = EconUtil.peek_st(w)
		if int(s.get("food_shortfall", 0)) > 50:
			famine += 1
		if (m + 1) % 60 == 0:
			var c := {}
			for f in w.facts.query("", m - 59):
				var t: String = f["type"]
				var d: Dictionary = f.get("data", {})
				if t == "POL_PROJECT_ORDERED":
					t += ":" + String(d["type"])
				elif t in ["ECON_INCENTIVE_OFFERED", "ECON_INCENTIVE_CLAIMED", "COMP_INVESTMENT"]:
					t += ":" + String(d.get("type", ""))
				else:
					continue
				c[t] = int(c.get(t, 0)) + 1
			var e: Dictionary = EconQuery.essentials(w)
			var farms := 0
			for fid in w.table("facility"):
				if w.table("facility")[fid]["type"] == "FARM":
					farms += 1
			print("Y%d pop=%d unemp=%.1f%% farms=%d food_margin=%d%% famine_months=%d  %s" % [(m + 1) / 12, PopStore.total(w), 100.0 * FirmAI.colony_unemployment(w), farms, int(e["FOOD"]["margin_pct"]), famine, str(c)])
			famine = 0
			var pst: Dictionary = w.table("pol")["state"]
			var g: Dictionary = pst.get("government", {})
			var fp := []
			for pid in w.table("project"):
				var pr: Dictionary = w.table("project")[pid]
				if pr["type"] == "FARM" and pr["status"] in ["TENDER", "ACTIVE", "TENDERABLE"]:
					fp.append("%s:%s:%s:start%d:%d%%:contractor=%s:unpaid=%d" % [pid, pr["status"], pr.get("owner", "?"), int(pr.get("start_month", -1)), int(100.0 * float(pr.get("wu_done", 0)) / maxf(1.0, float(pr.get("wu_total", 1)))), pr.get("contractor", ""), int(pr.get("unpaid_m", 0))])
			print("    era=%s gov=%s ECON_ROLE=%s actor=%s farm_projects=%s offers=%s" % [pst.get("era", ""), g.get("members", []), g.get("center", {}).get("ECON_ROLE", "?"), not GovBuilder._actor(w, pst).is_empty(), fp, EconEssentials.offers(w).keys()])
	quit()
