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
				if t == "POL_PROJECT_ORDERED" and String(d.get("type", "")) in ["FARM", "POWER", "WATERWORKS", "PROCESSING", "COMPONENTS"]:
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
			print("Y%d pop=%d farms=%d food_margin=%d%% famine_months=%d  %s" % [(m + 1) / 12, PopStore.total(w), farms, int(e["FOOD"]["margin_pct"]), famine, str(c)])
			famine = 0
	quit()
