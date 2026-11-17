extends SceneTree
## Bob: road commissions vs projects and their timelines (Terra's trace). seed 1, defaults, 20 years.
func _init() -> void:
	var sim: Simulation = EconSim.make(1, "BALANCED", {}, true)
	var w := sim.world
	var hist := {}
	var fails := 0
	var seen := {}
	for m in 240:
		sim.run(1)
		for pid in w.table("project"):
			var p: Dictionary = w.table("project")[pid]
			if String(p.get("type", "")) != "ROAD":
				continue
			var h: Array = hist.get(pid, [])
			if h.is_empty() or String(h[-1][1]) != String(p["status"]):
				h.append([w.month, p["status"], int(p.get("progress", p.get("done", 0)))])
			hist[pid] = h
		for f in w.facts.query("ECON_ACTION_FAILED"):
			if not seen.has(f["id"]) and String(f["data"].get("action", "")) == "ECON_COMMISSION_PROJECT":
				seen[f["id"]] = true
				fails += 1
				print("m%d FAILED %s: %s" % [w.month, f["data"].get("params", {}).get("type", "?"), f["data"].get("error", "")])
	for pid in EconUtil.sorted_keys(hist):
		print(pid, " ", hist[pid])
	print("commission failures: ", fails)
	quit()
