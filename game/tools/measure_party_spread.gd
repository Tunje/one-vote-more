extends SceneTree
## How different are the parties, and how does the opposition actually vote?
##   godot --headless --path game --script res://tools/measure_party_spread.gd
## Vote noise is switched off (VOTE_NOISE_SD is const, so we re-score bills here noise-free).

func _initialize() -> void:
	for scenario in ["BALANCED", "RECESSION"]:
		var sim := PoliticalSim.make(1, scenario, {"REDISTRIBUTION": 70, "LABOR": 60, "ENVIRONMENT": 40, "ECON_ROLE": 50, "FISCAL": 40})
		sim.run(140)
		var w := sim.world
		var parties: Array = []
		for p in w.table("party").values():
			if p["status"] == "ACTIVE":
				parties.append(p)
		print("\n=== %s, month 140 ===" % scenario)
		print("Party positions (points, -100..100):  ECON  REDIS LABOR ENV   AUTON FISC  INST | support")
		for p in parties:
			var row := ""
			for ax in PolDefs.AXES:
				row += "%5d " % int(round(p["positions"][ax] / 1000.0))
			print("  %-26s %s| %.1f%%" % [p["name"], row, p["support"] / 1000.0])
		var dmin := INF
		var dmax := 0.0
		var dsum := 0.0
		var n := 0
		for i in parties.size():
			for j in range(i + 1, parties.size()):
				var d := VoteModel.distance(parties[i]["positions"], parties[j]["positions"])
				dmin = minf(dmin, d); dmax = maxf(dmax, d); dsum += d; n += 1
		print("Pairwise distance: min %.1f, mean %.1f, max %.1f (voter spread for comparison: %.1f)" % [dmin, dsum / n, dmax, _voter_spread(w)])
		# Re-vote every passed/defeated bill noise-free, tally opposition behaviour and why
		var tally := {"YES": 0, "NO": 0, "ABSTAIN": 0}
		var parts := {"ideology": 0.0, "relief": 0.0, "commit": 0.0, "n": 0}
		var g: Dictionary = w.table("pol")["state"]["government"]
		var cs: Array = PoliticsProvider.new().colony_concerns(w)
		for b in w.table("bill").values():
			for p in parties:
				if p["seats"] == 0 or p["id"] in g.get("members", []) or p["id"] in g.get("support", []):
					continue
				var v := Legislature.party_vote(p, b["clauses"], w, g, cs[0], cs[1], b.get("draft_quality", 50))
				tally[v] += 1
				for c in b["clauses"]:
					var def: Dictionary = w.lever_defs[c["lever"]]
					var delta := float(c["to"] - c["from"])
					parts["ideology"] += absf(Legislature.ideo_alignment(def, delta, p["positions"]))
					parts["relief"] += absf(1.5 * Legislature.relief(def, delta, cs[0], cs[1]))
					parts["n"] += 1
		print("Opposition votes on %d bills (noise-free, current government): %s" % [w.table("bill").size(), tally])
		print("Mean |ideology term| per clause %.1f vs |relief term| %.1f vs opposition reflex 3 and decision band +/-2" % [parts["ideology"] / maxf(1, parts["n"]), parts["relief"] / maxf(1, parts["n"])])
	quit(0)


func _voter_spread(w: WorldState) -> float:
	# mean distance of voter cells from the population-weighted centre
	var c := PolDefs.zero_axes()
	var tp := 0.0
	for cell in w.table("cell").values():
		tp += cell["pop"]
		for ax in PolDefs.AXES:
			c[ax] += float(cell["ideology"][ax]) * cell["pop"]
	for ax in PolDefs.AXES:
		c[ax] = c[ax] / tp
	var s := 0.0
	for cell in w.table("cell").values():
		s += VoteModel.distance(cell["ideology"], c) * cell["pop"]
	return s / tp
