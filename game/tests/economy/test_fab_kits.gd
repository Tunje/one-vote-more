extends TestCase
## E106 (user decision A38): fabrication kits — crude Mk I smelter and component workshop at landing, upgradeable
## by local projects to Mk II / Mk III (more output per worker, less input waste).


func _kits(w: WorldState) -> Array:
	var out: Array = []
	for fid in EconUtil.sorted_keys(w.table("facility")):
		var f: Dictionary = w.table("facility")[fid]
		if f["type"] in EconData.KIT_TYPES and int(f.get("tier", 2)) == 1:
			out.append(fid)
	return out


func test_colony_lands_with_mk1_kits() -> void:
	var sim := EconSim.make_econ_only(2)
	var w := sim.world
	var kits := _kits(w)
	check_eq(kits.size(), 2, "a Mk I smelter and a Mk I component workshop at landing")
	var types := kits.map(func(k): return w.table("facility")[k]["type"])
	check(types.has("PROCESSING") and types.has("COMPONENTS"), "both kit types: %s" % [types])
	for k in kits:
		check_eq(w.table("org")[w.table("facility")[k]["org"]]["key"], "CPW", "kits run by the public utility")
	var f: Dictionary = w.table("facility")[kits[0]]
	check(EconUtil.tier_out(f) < 1.0 and EconUtil.tier_in(f) > 1.0, "Mk I is crude: less output, more input waste")


func test_upgrade_action_and_completion() -> void:
	var sim := EconSim.make_econ_only(2)
	sim.run(2)
	var w := sim.world
	var kit: String = _kits(w)[0]
	w.levers["ECON_BUDGET_INFRASTRUCTURE"] = 15000
	var opts := EconQuery.upgrade_options(w)
	var row: Dictionary = opts.filter(func(o): return o["facility"] == kit)[0]
	check(row["next_tier"] == 2 and row["output_gain_pct"] > 0 and row["waste_cut_pct"] > 0, "upgrade option listed: %s" % [row])
	var c := EconActions.check(w, "ECON_UPGRADE_FACILITY", {"facility": kit})
	check(c["ok"], "upgrade allowed: %s" % c["error"])
	var bad := EconActions.check(w, "ECON_UPGRADE_FACILITY", {"facility": "fac:999"})
	check(not bad["ok"], "unknown facility refused")
	EconActions.enqueue(w, "ECON_UPGRADE_FACILITY", {"facility": kit})
	sim.run(1)
	var pid := ""
	for p in w.table("project"):
		if w.table("project")[p]["type"] == "UPGRADE" and w.table("project")[p]["target"] == kit:
			pid = p
	check(pid != "", "an UPGRADE project was created")
	check(not EconActions.check(w, "ECON_UPGRADE_FACILITY", {"facility": kit})["ok"], "no second upgrade while one is under way")
	if pid != "":
		# finish it directly and check the effect
		var p: Dictionary = w.table("project")[pid]
		p["contractor"] = p.get("contractor", "") if p.get("contractor", "") != "" else EconUtil.sorted_keys(w.table("org")).filter(func(o): return w.table("org")[o]["is_contractor"])[0]
		if p["start_month"] < 0:
			p["start_month"] = w.month
		if not w.table("org")[p["contractor"]]["contracts"].has(pid):
			w.table("org")[p["contractor"]]["contracts"].append(pid)
		EconConstruction._complete(w, p)
		check_eq(int(w.table("facility")[kit].get("tier", 2)), 2, "kit upgraded to Mk II")
		check_eq(EconUtil.tier_out(w.table("facility")[kit]), 1.0, "Mk II output multiplier")
