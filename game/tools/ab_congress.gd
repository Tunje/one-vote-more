extends SceneTree
## A/B: party-system health with congresses/leadership races off vs on (owner Ella).
## Gate (Wilma): 4..9 active parties most of the run; brief dips to 3 / peaks of 10-11 fine; long stretches at <=2 or >=12 not.
##   godot --headless --path game --script res://tools/ab_congress.gd -- <months> <on|off|both> [seeds...]
const EconSim := preload("res://sim/economy/econ_sim.gd")
const KINDS := ["POL_PARTY_FOUNDED", "POL_PARTY_SPLIT", "POL_PARTIES_MERGED", "POL_PARTY_DISSOLVED", "POL_LEADER_CHANGED", "POL_LEADER_SURVIVED"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 480
	var arms: Array = [false, true]
	if args.size() > 1 and args[1] in ["on", "off"]:
		arms = [args[1] == "on"]
	var seeds: Array = []
	for i in range(2, args.size()):
		seeds.append(int(args[i]))
	if seeds.is_empty():
		seeds = [1, 2, 3]
	for on in arms:
		for seed_v in seeds:
			var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
			sim.world.meta["congress"] = on
			var hist := {}
			var counted := 0
			var in_band := 0
			var run_lo := 0
			var run_hi := 0
			var max_lo := 0
			var max_hi := 0
			var late := 0
			var late_in := 0
			var dec := {}
			for _m in months:
				sim.step()
				if sim.world.month <= PolDefs.PARTY_FORMATION_MONTH + 1:
					continue
				var n := PartyLife.active(sim.world).size()
				hist[n] = int(hist.get(n, 0)) + 1
				counted += 1
				if n >= 4 and n <= 9:
					in_band += 1
				var y := sim.world.month / 12
				var d: Array = dec.get(y / 10, [99, 0])
				dec[y / 10] = [mini(int(d[0]), n), maxi(int(d[1]), n)]
				if y >= 40:
					late += 1
					late_in += 1 if n >= 4 and n <= 9 else 0
				run_lo = run_lo + 1 if n <= 2 else 0
				run_hi = run_hi + 1 if n >= 12 else 0
				max_lo = maxi(max_lo, run_lo)
				max_hi = maxi(max_hi, run_hi)
			var row := {}
			for k in KINDS:
				row[k.trim_prefix("POL_").trim_prefix("PARTY_")] = sim.world.facts.query(k).size()
			var keys := hist.keys()
			keys.sort()
			var hs := ""
			for k in keys:
				hs += "%d:%d " % [k, hist[k]]
			print("congress %-5s seed %d: in 4..9 %d%%  longest <=2 %dmo  >=12 %dmo  hist[%s] %s" % [str(on), seed_v, 100 * in_band / maxi(1, counted), max_lo, max_hi, hs.strip_edges(), row])
			var ds := ""
			var dk := dec.keys()
			dk.sort()
			for k in dk:
				ds += "Y%d0s %d..%d  " % [k, dec[k][0], dec[k][1]]
			if late > 0:
				print("  seed %d from Y40: in 4..9 %d%%   %s" % [seed_v, 100 * late_in / late, ds.strip_edges()])
	quit(0)
