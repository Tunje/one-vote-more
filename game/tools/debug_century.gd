extends SceneTree
## O-1 / M12 century probe: one line per N years with production, employment, utilities, materials, public finance,
## facility closures/reopenings, projects, defaults/restructurings and service access.
## Usage: godot --headless --path . --script res://tools/debug_century.gd -- [seed] [years] [every]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_v := int(a[0]) if a.size() > 0 else 1
	var years := int(a[1]) if a.size() > 1 else 100
	var every := int(a[2]) if a.size() > 2 else 5
	var sim := EconSim.make(seed_v)
	var w := sim.world
	var prev_m := 0
	for y in range(1, years + 1):
		sim.run(12)
		if y % every != 0 and y != 1:
			continue
		var s := EconUtil.st(w)
		var counts := {}
		for t in ["ECON_FACILITY_CLOSED_UNSAFE", "ECON_FACILITY_REOPENED", "ECON_PROJECT_COMPLETED", "ECON_SOVEREIGN_DEFAULT", "ECON_DEBT_RESTRUCTURED",
				"ECON_FACILITY_SOLD", "ECON_SHORTAGE", "ECON_UTILITY_OUTAGE", "COMP_INSOLVENCY", "ECON_SHIP_ARRIVED"]:
			counts[t.trim_prefix("ECON_").trim_prefix("COMP_").substr(0, 9)] = w.facts.query(t, prev_m).size()
		prev_m = w.month
		var run := {}
		var idle := 0
		var mb := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			if f["mothball"]:
				mb += 1
			elif f["util"] > 100:
				run[f["type"]] = int(run.get(f["type"], 0)) + 1
			else:
				idle += 1
		var emp := {}
		for gid in w.table("hh"):
			for occ in w.table("hh")[gid]["emp"]:
				emp[occ] = int(emp.get(occ, 0)) + w.table("hh")[gid]["emp"][occ] / 1000
		var rev := 0
		for v in s["gov_rev_hist"]:
			rev += int(v)
		var spend := 0
		for v in s.get("gov_spend_hist", []):
			spend += int(v)
		var ind := w.indicators
		var health := 0
		var edu := 0
		var nd := 0
		for d in ind.values.get("ECON_HEALTH_ACCESS", {}):
			health += ind.read("ECON_HEALTH_ACCESS", d)
			edu += ind.read("ECON_EDUCATION_ACCESS", d)
			nd += 1
		var rii := 0.0
		var nc := 0
		for k in ind.values.get("ECON_REAL_INCOME_INDEX", {}):
			rii += float(ind.read("ECON_REAL_INCOME_INDEX", k)) / 1000.0
			nc += 1
		print("Y%d pop %d u%.1f%% | out(ECON_GROWTH %.1f) running %d idle %d mb %d | E %d/%d W %d/%d food_short %d | pMat %d pComp %d | treas %dk debt %dk rev12 %dk spend12 %dk default %s | RII mean %.0f max %.0f | health %.0f edu %.0f | %s" % [
			y, PopStore.total(w), 100.0 * FirmAI.colony_unemployment(w), float(ind.read("ECON_GROWTH", "COLONY")) / 1000.0, _sum(run), idle, mb,
			s["util_supply"]["E"] / 1000, s["util_demand"]["E"] / 1000, s["util_supply"]["W"] / 1000, s["util_demand"]["W"] / 1000, s["food_shortfall"],
			s["prices"]["MATERIAL"] / 1000, s["prices"]["COMPONENT"] / 1000, w.ledger.balance(EconUtil.TREASURY) / 1000000, EconFinance.debt_of(w, "gov") / 1000000,
			rev / 1000000, spend / 1000000, str(s["sovereign_default"]), rii / maxf(1.0, float(nc)), _max_rii(w), float(health) / maxf(1.0, nd) / 1000.0, float(edu) / maxf(1.0, nd) / 1000.0, str(counts)])
		print("    running %s | emp %s" % [str(run), str(emp)])
	quit()


func _sum(d: Dictionary) -> int:
	var t := 0
	for k in d:
		t += d[k]
	return t


func _max_rii(w: WorldState) -> float:
	var m := 0.0
	for k in w.indicators.values.get("ECON_REAL_INCOME_INDEX", {}):
		m = maxf(m, float(w.indicators.read("ECON_REAL_INCOME_INDEX", k)) / 1000.0)
	return m
