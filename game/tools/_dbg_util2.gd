extends SceneTree
## temp (Bob, v6 P0): who holds the stuck CPW projects? args: seed months
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	for m in int(a[1]):
		sim.run(1)
		if w.month % 6 != 0:
			continue
		for pid in EconUtil.sorted_keys(w.table("project")):
			var p: Dictionary = w.table("project")[pid]
			if p["status"] == "ACTIVE" and int(p["wu_done"]) == 0 and w.month - int(p["start_month"]) >= 6:
				var c: String = p["contractor"]
				var o: Dictionary = w.table("org").get(c, {})
				print("m%d %s %s owner=%s start=%d contractor=%s c_status=%s listed=%s unpaid_m=%d paid=%d price=%d mat=%d comp=%d c_mat=%d c_comp=%d cap=%d" % [w.month, pid, p["type"], p["owner"], p["start_month"], c, o.get("status", "GONE"), str(o.get("contracts", []).has(pid)), p["unpaid_m"], p["paid"] / 1000, p["price"] / 1000, p["mat_total"] / 1000, p["comp_total"] / 1000, EconUtil.inv_get(w, c, "MATERIAL", o.get("hq", "d:1")) / 1000 if not o.is_empty() else -1, EconUtil.inv_get(w, c, "COMPONENT", o.get("hq", "d:1")) / 1000 if not o.is_empty() else -1, EconConstruction.capacity(w, c) / 1000 if not o.is_empty() else -1])
	quit()
