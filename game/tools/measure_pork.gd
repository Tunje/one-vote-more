extends SceneTree
## A/B for election-year pork (spec-election-year-v1 §2.6; owner Ella). Same seeds with world.meta["pork"] off and on.
## Gate (Wilma): bills passed/defeated within ±20%, and fiscal-guard blocks (pol.state.leg_stats) don't drop.
##   godot --headless --path game --script res://tools/measure_pork.gd -- [months] [seeds...]
const EconSim := preload("res://sim/economy/econ_sim.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 300
	var seeds: Array = []
	for i in range(1, args.size()):
		seeds.append(int(args[i]))
	if seeds.is_empty():
		seeds = [1, 2, 3]
	var tot := {false: {}, true: {}}
	for on in [false, true]:
		for seed_v in seeds:
			var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
			sim.world.meta["pork"] = on
			sim.run(months)
			var r := _count(sim.world)
			print("pork %-5s seed %d: %s" % [str(on), seed_v, r])
			for k in r:
				tot[on][k] = int(tot[on].get(k, 0)) + int(r[k])
	print("\nTOTAL off: %s\nTOTAL on:  %s" % [tot[false], tot[true]])
	for k in ["passed", "defeated"]:
		var a := float(tot[false].get(k, 0))
		var b := float(tot[true].get(k, 0))
		print("  %s: %+.0f%% (want within ±20%%)" % [k, 100.0 * (b - a) / maxf(1.0, a)])
	print("  guard_blocked: off %d, on %d (want on >= off)" % [tot[false].get("guard_blocked", 0), tot[true].get("guard_blocked", 0)])
	quit(0)


func _count(w: WorldState) -> Dictionary:
	var passed := 0
	var defeated := 0
	for b in w.peek("bill").values():
		if b.get("status", "") == "PASSED":
			passed += 1
		elif b.get("status", "") == "DEFEATED":
			defeated += 1
	var st: Dictionary = w.peek("pol").get("state", {})
	var pork_good := 0
	var pork_bad := 0
	for f in w.facts.query("POL_ELECTION_PORK"):
		if f["data"].get("believed", true):
			pork_good += 1
		else:
			pork_bad += 1
	return {"passed": passed, "defeated": defeated, "ordinances": w.facts.query("POL_ORDINANCE_ISSUED").size(),
		"guard_blocked": int(st.get("leg_stats", {}).get("guard_blocked", 0)), "pork_believed": pork_good, "pork_seen_through": pork_bad}
