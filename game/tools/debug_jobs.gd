extends SceneTree
## O-1 jobs-gap diagnosis (integrated): labour supply vs job slots vs utilization vs household demand.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	var prev_lf := 0
	for y in 10:
		var migrants := 0
		var spend := 0
		var income := 0
		for m in 12:
			sim.step()
			for f in sim.world.facts.query("ECON_MIGRANTS_ARRIVED", sim.world.month - 1, sim.world.month - 1):
				migrants += int(f["data"].get("persons", 0))
			for gid in sim.world.table("hh"):
				var g: Dictionary = sim.world.table("hh")[gid]
				income += EconHouseholds.disposable(g)
				spend += g.get("spent_goods", 0)
		var w := sim.world
		var lf := 0
		var emp := 0
		var selfe := 0
		for gid in w.table("hh"):
			var g: Dictionary = w.table("hh")[gid]
			lf += g["lf"]; emp += EconLabor.employed(g); selfe += g.get("self_emp", 0)
		var slots_full := 0
		var slots_now := 0
		var by_type := {}
		var tsum := 0.0
		var tn := 0
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			var r: Dictionary = EconData.RECIPES[f["type"]]
			var full := 0
			for t in r["labor"]:
				full += int(float(r["labor"][t]) * EconUtil.fscale(f))
			if not f["mothball"]:
				slots_full += full
			slots_now += EconLabor.staff_total(f["staff"]) / 1000
			by_type[f["type"]] = by_type.get(f["type"], 0) + EconLabor.staff_total(f["staff"]) / 1000
			if r["out"][0] in EconData.MARKET_GOODS or r["out"][0] == "SERVICES":
				tsum += float(f["T"]) / 10.0; tn += 1
		var crews := 0
		for oid in w.table("org"):
			if w.table("org")[oid]["is_contractor"]:
				crews += EconLabor.staff_total(w.table("org")[oid]["crew"]) / 1000
		var built := 0
		for pid in w.table("project"):
			if w.table("project")[pid]["status"] == "DONE":
				built += 1
		var active_orgs := 0
		for oid in w.table("org"):
			if w.table("org")[oid]["status"] in ["ACTIVE", "DISTRESSED"]:
				active_orgs += 1
		print("Y%d lf %d (+%d, migrants %d) emp %d (self %d) u=%.0f%% | facility staff %d / full slots %d, crews %d | avgT %.0f%% | hh spend/income %.0f%% | built %d orgs %d" % [y + 1,
			lf / 1000, (lf - prev_lf) / 1000, migrants, emp / 1000, selfe / 1000, 100.0 * (1.0 - float(emp) / float(lf)), slots_now, slots_full, crews,
			tsum / maxf(1.0, float(tn)), 100.0 * float(spend) / maxf(1.0, float(income)), built, active_orgs])
		print("    staff by type: ", by_type)
		prev_lf = lf
	quit(0)
