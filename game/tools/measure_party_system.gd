extends SceneTree
## Party-system health on the real economy (spec-politics-v2 §7): parties per election, foundings, splits,
## mergers, dissolutions, leadership changes, who governs.
##   godot --headless --path game --script res://tools/measure_party_system.gd -- [months] [seeds...]
const EconSim := preload("res://sim/economy/econ_sim.gd")
const EVENTS := ["POL_PARTY_FOUNDED", "POL_PARTY_SPLIT", "POL_PARTIES_MERGED", "POL_PARTY_DISSOLVED", "POL_LEADER_CHANGED", "POL_LEADER_SURVIVED", "POL_SCANDAL_REVEALED"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 480
	var seeds: Array = []
	for i in range(1, args.size()):
		seeds.append(int(args[i]))
	if seeds.is_empty():
		seeds = [1, 2, 3]
	var totals := {}
	var min_active := 99
	var max_active := 0
	for seed_v in seeds:
		var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
		var last_pm := ""
		print("=== seed %d ===" % seed_v)
		for _m in months:
			sim.step()
			var st: Dictionary = sim.world.peek("pol").get("state", {})
			var n := PartyLife.active(sim.world).size()
			if sim.world.month > PolDefs.PARTY_FORMATION_MONTH:
				min_active = mini(min_active, n)
				max_active = maxi(max_active, n)
			for t in EVENTS:
				if t == "POL_SCANDAL_REVEALED" or t == "POL_LEADER_CHANGED" or t == "POL_LEADER_SURVIVED":
					continue
				for f in sim.world.facts.query(t, sim.world.month - 1, sim.world.month - 1):
					var p: Dictionary = sim.world.table("party").get(f["data"].get("party", f["data"].get("into", "")), {})
					print("  m%3d %-22s %-28s %s" % [sim.world.month, t.trim_prefix("POL_"), p.get("name", ""), _brief(f["data"], sim.world)])
			var g: Dictionary = st.get("government", {})
			if g.get("pm_party", "") != last_pm and g.get("pm_party", "") != "":
				last_pm = g["pm_party"]
				var names: Array = g["members"].map(func(pid): return sim.world.table("party")[pid]["name"])
				print("  m%3d GOVERNMENT %s (yes %d)" % [sim.world.month, ", ".join(names), g.get("yes", 0)])
		for t in EVENTS:
			totals[t] = totals.get(t, 0) + sim.world.facts.query(t).size()
		var parties := sim.world.table("party")
		for eid in sim.world.table("pol")["state"]["elections"]:
			var e: Dictionary = sim.world.table("election")[eid]
			var parts: Array = []
			for pid in e["seats"]:
				if e["seats"][pid] > 0:
					parts.append("%s %d" % [parties[pid]["name"].get_slice(" ", 0), e["seats"][pid]])
			print("  election m%d: %s" % [e["month"], " | ".join(parts)])
		for pid in parties:
			var p: Dictionary = parties[pid]
			print("  %-28s %-12s %-9s founded m%d leader %s pop %d" % [p["name"], p.get("kind", ""), p["status"], p["founded_month"], PartyLife.leader_name(p), PartyLife.leader_popularity(p)])
	print("\nTOTALS over %d runs x %d months: %s | active parties min %d max %d" % [seeds.size(), months, totals, min_active, max_active])
	quit(0)


func _brief(d: Dictionary, w: WorldState) -> String:
	var out := d.duplicate()
	for k in ["splinter", "absorbed", "heir"]:
		if out.has(k):
			out[k] = w.table("party").get(out[k], {}).get("name", out[k])
	out.erase("party")
	out.erase("into")
	return str(out)
