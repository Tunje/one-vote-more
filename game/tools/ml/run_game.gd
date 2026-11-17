extends SceneTree
## A53 L2: play one game with a fixed strategy genome for one party and print a JSON score line.
##   godot --headless --path game --script res://tools/ml/run_game.gd -- <genome.json|-> <seed> <years> [party|auto]
## genome.json = {"G_DRIFT": 0..1000, ...}; "-" = the default genome (all 500). The genome is given to the party
## when parties form (month PolDefs.PARTY_FORMATION_MONTH + 1); "auto" = the largest founding party at that point.
## Output: one line starting "SCORE " followed by JSON.


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var genome := {}
	if a.size() > 0 and a[0] != "-":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(a[0]))
		if parsed is Dictionary:
			for g in Learn.GENES:
				if parsed.has(g):
					genome[g] = clampi(int(round(float(parsed[g]))), 0, 1000)
	var seed_v := int(a[1]) if a.size() > 1 else 1
	var years := int(a[2]) if a.size() > 2 else 40
	var want := String(a[3]) if a.size() > 3 else "auto"
	var sim: Simulation = EconFace.sim_make(seed_v, "BALANCED", {}, true)
	sim.run(PolDefs.PARTY_FORMATION_MONTH + 1)
	var w := sim.world
	var pid := want
	if want == "auto":
		w.meta["learning_party"] = "auto"
		pid = Learn.learning_party(w)
		w.meta.erase("learning_party")
	if pid == "" or not w.table("party").has(pid):
		print("SCORE " + JSON.stringify({"error": "no party", "seed": seed_v}))
		quit(1)
		return
	if not genome.is_empty():
		w.table("party")[pid]["strategy"] = genome
	var months := years * 12 - w.month
	var sup := 0.0
	var seats := 0.0
	var pm := 0
	var cab := 0
	var alive := 0
	var n := 0
	for i in months:
		sim.run(1)
		var p: Dictionary = w.peek("party").get(pid, {})
		if p.get("status", "") != "ACTIVE":
			continue
		alive += 1
		n += 1
		sup += float(p.get("support", 0)) / 1000.0
		seats += float(p.get("seats", 0))
		var g: Dictionary = w.peek("pol").get("state", {}).get("government", {})
		if String(g.get("pm_party", "")) == pid:
			pm += 1
		if pid in g.get("members", []):
			cab += 1
	var out := {"seed": seed_v, "years": years, "party": pid, "genome": genome,
		"support": sup / maxf(1.0, float(n)), "seats": seats / maxf(1.0, float(n)),
		"pm_share": float(pm) / float(months), "cabinet_share": float(cab) / float(months),
		"survival": float(alive) / float(months)}
	# the objective: votes, seats, and above all governing (the same weights as Learn.score)
	out["score"] = out["support"] + 0.3 * out["seats"] + 25.0 * out["pm_share"] + 10.0 * out["cabinet_share"] - 20.0 * (1.0 - out["survival"])
	print("SCORE " + JSON.stringify(out))
	quit(0)
