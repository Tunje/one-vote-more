extends SceneTree
## temp (Bob, Wilma's unemployment item): yearly jobs vs labour force, plants and use by type, entries/closures,
## entry signals, public-scheme posts, immigration law and arrivals. args: seed months
const S := 1000
const TYPES := ["FARM", "CONSUMERF", "SERVICEHUB", "PROCESSING", "COMPONENTS", "MINE", "TEXTILE", "FURNITURE", "BAKERY", "HOUSING", "PUBJOBS"]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 1200
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = Array(a[2].split(",")) if a.size() > 2 and a[2] != "-" else []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	var seen := {}
	for oid in w.table("org"):
		seen[oid] = true
	var last_arr := 0
	var u_sum := 0.0
	for m in months:
		sim.step()
		u_sum += FirmAI.colony_unemployment(w)
		if (m + 1) % 12 != 0:
			continue
		var y := (m + 1) / 12
		var born := 0
		for oid in w.table("org"):
			if not seen.has(oid):
				seen[oid] = true
				if not w.table("org")[oid]["is_contractor"]:
					born += 1
		var dead := 0
		var active := 0
		for oid in w.table("org"):
			var st: String = w.table("org")[oid]["status"]
			if st in ["LIQUIDATION", "DISSOLVED"]:
				dead += 1
			elif not w.table("org")[oid]["is_contractor"]:
				active += 1
		var lf := 0
		var emp := 0
		for gid in w.table("hh"):
			lf += int(w.table("hh")[gid]["lf"])
			emp += EconLabor.employed(w.table("hh")[gid])
		var req := 0
		var by := {}
		for fid in w.table("facility"):
			var f: Dictionary = w.table("facility")[fid]
			var r := EconLabor.required(f)
			for t in r:
				req += int(r[t])
			var row: Array = by.get(f["type"], [0, 0, 0.0])
			row[0] += 1
			if f["mothball"]:
				row[1] += 1
			else:
				row[2] += float(f.get("util", 0)) / 1000.0 if typeof(f.get("util", 0)) == TYPE_INT and int(f.get("util", 0)) > 10 else float(f.get("util", 0))
			by[f["type"]] = row
		var crew := 0
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			if o["is_contractor"] and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION"]:
				crew += EconLabor.staff_total(o["crew"])
		var parts := []
		for t in TYPES:
			if by.has(t):
				var r2: Array = by[t]
				var live: int = int(r2[0]) - int(r2[1])
				parts.append("%s %d/%d u%d" % [t.substr(0, 4), live, int(r2[0]), int(round(100.0 * float(r2[2]) / maxf(1.0, float(live))))])
		var hot := []
		var sig: Dictionary = EconUtil.st(w).get("entry_signal", {})
		for k in EconUtil.sorted_keys(sig):
			if int(sig[k]) >= 2:
				hot.append(k.substr(0, 4))
		var arr := int(w.values.get("pop_arrivals", 0)) - last_arr
		last_arr = int(w.values.get("pop_arrivals", 0))
		var kids := PopStore.count(w, {"status": "CHILD"})
		print("Y%d u_avg %.1f%% lf %d emp %d posts %d crew %d vac %d | firms %d +%d dead_total %d | imm %s arr %d kids %d | hot %s | %s" % [y, 100.0 * u_sum / 12.0,
			lf / S, emp / S, req / S, crew / S, maxi(0, (req + crew - emp)) / S, active, born, dead, str(w.levers.get("LAW_IMMIGRATION", "-")), arr, kids / S if kids > 100000 else kids, ",".join(hot), " ".join(parts)])
		u_sum = 0.0
	quit()
