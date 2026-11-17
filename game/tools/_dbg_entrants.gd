extends SceneTree
## temp (Bob, backlog 20): fate of every new firm. args: seed years
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	var seen := {}
	for oid in w.table("org"):
		seen[oid] = true
	var rec := {}  # oid -> {born, sector, peak, end, end_status}
	for m in int(a[1]) * 12:
		sim.run(1)
		for oid in w.table("org"):
			var o: Dictionary = w.table("org")[oid]
			if not seen.has(oid):
				seen[oid] = true
				if o["is_contractor"]:
					continue
				var key: String = o["key"]
				var sector := "MICRO" if key.begins_with("MICRO") else ("HOMES" if key.begins_with("HOMES") else "?")
				rec[oid] = {"born": w.month, "sector": sector, "peak": 0, "end": -1, "st": "", "built": false}
			if rec.has(oid):
				var r: Dictionary = rec[oid]
				var staff := 0
				for fid in w.table("facility"):
					var f: Dictionary = w.table("facility")[fid]
					if f["org"] == oid:
						staff += EconLabor.staff_total(f["staff"])
						r["built"] = true
						if r["sector"] == "?":
							r["sector"] = f["type"]
				if r["sector"] == "?":
					for pid in w.table("project"):
						if w.table("project")[pid]["owner"] == oid:
							r["sector"] = w.table("project")[pid]["type"]
				r["peak"] = maxi(int(r["peak"]), staff / 1000)
				if r["end"] < 0 and o["status"] in ["LIQUIDATION", "DISSOLVED"]:
					r["end"] = w.month
					r["st"] = "built-then-failed" if r["built"] else "never-built"
	var by := {}
	for oid in rec:
		var r: Dictionary = rec[oid]
		var k: String = r["sector"]
		var row: Array = by.get(k, [0, 0, 0, 0, 0, 0])  # founded, alive, never-built, built-then-failed, sum peak, sum life of dead
		row[0] += 1
		if r["end"] < 0:
			row[1] += 1
		elif r["st"] == "never-built":
			row[2] += 1
		else:
			row[3] += 1
			row[5] += int(r["end"]) - int(r["born"])
		row[4] += int(r["peak"])
		by[k] = row
	for k in EconUtil.sorted_keys(by):
		var r2: Array = by[k]
		print("%-11s founded %3d alive %3d never-built %3d failed-after-building %3d | avg peak staff %d | avg life of failed %d months" % [k, r2[0], r2[1], r2[2], r2[3], int(r2[4]) / maxi(1, int(r2[0])), int(r2[5]) / maxi(1, int(r2[3]))])
	print("labour force %d, unemployment %.1f%%" % [EconQuery.labour(w)["labour_force"], 100.0 * FirmAI.colony_unemployment(w)])
	quit()
