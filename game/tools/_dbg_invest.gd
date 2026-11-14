extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sim: Simulation = EconSim.make(int(a[0]), "BALANCED", {}, true)
	var w := sim.world
	(w.meta["on"] as Array).append_array(["E136", "E137"])
	var seen := {}
	var pol_n := {}
	for m in int(a[1]) * 12:
		sim.run(1)
		var p := EconOwnership.policy(w)
		pol_n[p] = int(pol_n.get(p, 0)) + 1
		for f in w.facts.query("COMP_INVESTMENT"):
			if seen.has(f["id"]):
				continue
			seen[f["id"]] = true
			var oid := ""
			for sub in f.get("subjects", []):
				oid = String(sub[1]) if sub is Array else String(sub.get("id", ""))
			var o: Dictionary = w.table("org").get(oid, {})
			print("m%d INVEST %s by %s (%s) reason %s" % [w.month, f["data"].get("type", "?"), oid, o.get("type", "?"), f["data"].get("reason", "")])
	print("policy months ", pol_n)
	for pid in EconUtil.sorted_keys(w.table("project")):
		var p2: Dictionary = w.table("project")[pid]
		var o2: Dictionary = w.table("org").get(p2["owner"], {})
		if o2.get("type", "") in ["PRIVATE", "COOPERATIVE"] and p2["type"] in ["MINE", "PROCESSING", "COMPONENTS", "FARM", "CONSUMERF", "MEDWORKS", "POWER", "WATERWORKS"]:
			print("project %s %s owner %s status %s" % [pid, p2["type"], p2["owner"], p2["status"]])
	quit()
