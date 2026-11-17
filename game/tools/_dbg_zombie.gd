extends SceneTree
## Bob: E135 check — chronicle defaults, seed N, years: insolvencies, repeat insolvencies (same org within 4–6 months).
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	if a.size() > 2:
		w.meta["off"] = (w.meta.get("off", []) as Array) + [a[2]]
	var seen := {}
	var last := {}
	var n := 0
	var rep := 0
	var per := {}
	for m in int(a[1]) * 12:
		sim.run(1)
		for f in w.facts.query("COMP_INSOLVENCY"):
			if seen.has(f["id"]):
				continue
			seen[f["id"]] = true
			n += 1
			var oid := ""
			for sub in f.get("subjects", []):
				oid = String(sub[1]) if sub is Array else String(sub.get("id", ""))
			per[oid] = int(per.get(oid, 0)) + 1
			if last.has(oid) and w.month - int(last[oid]) <= 6:
				rep += 1
			last[oid] = w.month
	var worst := 0
	for k in per:
		worst = maxi(worst, int(per[k]))
	print("seed %s Y%s %s: insolvencies %d repeats %d worst firm %d" % [a[0], a[1], "E135 off" if a.size() > 2 else "E135 on", n, rep, worst])
	quit()
