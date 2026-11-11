extends SceneTree
## Election-year health on the integrated game (planning/spec-election-year-v1.md §6; owner Ella).
## Per election: themes, debates, gaffes, attacks, dirt, smears, how far the campaign moved each party
## (pp vs the poll when election year opened) and turnout. Gates printed at the end.
##   godot --headless --path game --script res://tools/measure_campaigns.gd -- [months] [seeds...]
const EconSim := preload("res://sim/economy/econ_sim.gd")
const KINDS := ["POL_DEBATE_HELD", "POL_DEBATE_GAFFE", "POL_ATTACK_AD", "POL_CAMPAIGN_GOES_NEGATIVE", "POL_DIRT_RELEASED", "POL_SMEAR_EXPOSED", "POL_POLITICS_WEEK"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var months := int(args[0]) if args.size() > 0 else 480
	var seeds: Array = []
	for i in range(1, args.size()):
		seeds.append(int(args[i]))
	if seeds.is_empty():
		seeds = [1, 2, 3, 4, 5, 6]
	var n_elections := 0
	var n_moved3 := 0
	var turnout_lo := 1.0
	var turnout_hi := 0.0
	var seeds_with_gaffe := 0
	var seeds_with_oppo := 0
	var seeds_with_backfire := 0
	for seed_v in seeds:
		var sim: Simulation = EconSim.make(seed_v, "BALANCED", {}, true)
		var seen := 0
		print("=== seed %d ===" % seed_v)
		for _m in months:
			sim.step()
			var w := sim.world
			var st: Dictionary = w.peek("pol").get("state", {})
			var els: Array = st.get("elections", [])
			if els.size() > seen:
				seen = els.size()
				var e: Dictionary = w.peek("election")[els.back()]
				var elig := 0
				for v in PolVoters.all(w):
					elig += maxi(0, int(v["pop"]))
				var t := float(e["total"]) / maxf(1.0, float(elig))
				turnout_lo = minf(turnout_lo, t)
				turnout_hi = maxf(turnout_hi, t)
				n_elections += 1
				var c := _campaign_for(w, int(e["month"]))
				var line := "  m%3d election: turnout %.1f%%" % [e["month"], 100.0 * t]
				if c.is_empty():
					print(line + " | no campaign")
					continue
				var best := 0
				var parts: Array = []
				for pid in Det.ordered(c["parties"]):
					var sh := int(round(float(e["votes"].get(pid, 0)) / maxf(1.0, float(e["total"])) * 100000.0))
					var mv := sh - int(c["start_poll"].get(pid, 0))
					best = maxi(best, absi(mv))
					var ce: Dictionary = c["parties"][pid]
					parts.append("%s %+.1f [%s %s→%s]" % [_short(w, pid), mv / 1000.0, ce["tone"].substr(0, 3), "/".join(ce["themes"].map(func(x): return String(x).substr(0, 6))), _short(w, ce["target"])])
				if best >= 3000:
					n_moved3 += 1
				print(line + " | max move %.1f pp%s" % [best / 1000.0, " (extra)" if c["extra"] else ""])
				print("      " + "; ".join(parts))
				for fid in c["events"]:
					var f: Dictionary = w.facts.get_fact(fid)
					if f["type"] in ["POL_DEBATE_HELD", "POL_DEBATE_GAFFE", "POL_DIRT_RELEASED", "POL_SMEAR_EXPOSED", "POL_POLITICS_WEEK"]:
						print("      m%3d %s" % [f["month"], NewsText.sentence(w, f).replace("[b]", "").replace("[/b]", "")])
		var w2 := sim.world
		var counts := {}
		for k in KINDS:
			counts[k] = w2.facts.query(k).size()
		var oppo := 0
		for f in w2.facts.query("POL_SCANDAL_REVEALED"):
			if f["data"].get("channel", "") == "OPPO_RESEARCH":
				oppo += 1
		var backfire: int = int(counts["POL_SMEAR_EXPOSED"])
		for f in w2.facts.query("POL_DIRT_RELEASED"):
			if f["data"].get("leaked", false):
				backfire += 1
		if counts["POL_DEBATE_GAFFE"] > 0:
			seeds_with_gaffe += 1
		if oppo > 0 or counts["POL_DIRT_RELEASED"] > 0:
			seeds_with_oppo += 1
		if backfire > 0:
			seeds_with_backfire += 1
		print("  totals: %s | oppo scandals via law %d | backfires %d" % [counts, oppo, backfire])
	print("\nGATES over %d seeds x %d months, %d elections:" % [seeds.size(), months, n_elections])
	print("  campaign moved a party >=3 pp: %d/%d elections (want >=50%%)" % [n_moved3, n_elections])
	print("  seeds with a gaffe: %d/%d (want all)" % [seeds_with_gaffe, seeds.size()])
	print("  seeds with released dirt: %d/%d (want all)" % [seeds_with_oppo, seeds.size()])
	print("  seeds with a backfire: %d/%d (want >= 1 per 3)" % [seeds_with_backfire, seeds.size()])
	print("  turnout range %.1f%%..%.1f%% (want 70..90)" % [100.0 * turnout_lo, 100.0 * turnout_hi])
	quit(0)


const Det := preload("res://sim/staff/det.gd")


func _campaign_for(w: WorldState, month: int) -> Dictionary:
	for cid in w.peek("campaign"):
		var c: Dictionary = w.peek("campaign")[cid]
		if int(c["election_month"]) == month and c["status"] != "SUPERSEDED":
			return c
	return {}


func _short(w: WorldState, pid) -> String:
	if String(pid) == "":
		return "-"
	return String(w.peek("party").get(String(pid), {}).get("name", "?")).get_slice(" ", 0)
