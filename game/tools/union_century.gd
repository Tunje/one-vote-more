extends SceneTree
## Union acceptance check (planning/spec-unions-v1.md §6) over a long run of one seed: active unions after year 5,
## leader changes per union per 20 years, strikes per decade, won/lost strikes, strikes on an empty fund, ledger.
## Usage: godot --headless --path . --script res://tools/union_century.gd -- <seed> [months]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var months := int(a[1]) if a.size() > 1 else 1200
	var sim := Simulation.new(sd)
	sim.world.meta["scenario"] = "BALANCED"
	sim.world.meta["persona"] = {}
	sim.world.meta["autoplay_player"] = true
	sim.world.meta["off"] = []
	EconSim._register(sim)
	sim.new_game()
	var w := sim.world
	var min_active := 99
	var max_active := 0
	var fed_missing := 0
	var empty_strike_m := 0
	var worst_empty := 0
	var empty_run := {}
	for m in months:
		sim.step()
		if w.month >= 60:
			var act := Unions.active(w).filter(func(u): return not u["federation"])
			min_active = mini(min_active, act.size())
			max_active = maxi(max_active, act.size())
			if Unions.federation(w).is_empty():
				fed_missing += 1
		for d in UnionDisputes.pending_demands(w):
			if d["status"] != "STRIKE":
				continue
			var did: String = d["id"]
			if Unions.fund(w, d["union"]) <= 0:
				empty_run[did] = int(empty_run.get(did, 0)) + 1
				empty_strike_m += 1
				worst_empty = maxi(worst_empty, int(empty_run[did]))
			else:
				empty_run[did] = 0
	var strikes := w.facts.query("UNION_STRIKE_CALLED")
	var by_decade := {}
	var general := 0
	for f in strikes:
		var dec := int(f.get("month", 0)) / 120
		by_decade[dec] = int(by_decade.get(dec, 0)) + 1
		if bool(f["data"].get("general", false)):
			general += 1
	var dec_rows: Array = []
	for i in months / 120:
		dec_rows.append(int(by_decade.get(i, 0)))
	var outcomes := {}
	for id in w.peek("union_demand"):
		var d: Dictionary = w.peek("union_demand")[id]
		if int(d["strike_months"]) > 0 or d["outcome"] in ["WON", "COMPROMISE", "LOST"]:
			outcomes[d["outcome"]] = int(outcomes.get(d["outcome"], 0)) + 1
	var changes := {}
	for f in w.facts.query("UNION_LEADER_ELECTED"):
		if not bool(f["data"].get("re_elected", true)):
			var uid := str(f["data"]["union"])
			changes[uid] = int(changes.get(uid, 0)) + 1
	var leader_rows: Array = []
	for id in EconUtil.sorted_keys(w.peek("union")):
		var u: Dictionary = w.peek("union")[id]
		var life := maxi(1, (int(u.get("dissolved", w.month)) if u["status"] == "DISSOLVED" else w.month) - int(u["founded"]))
		leader_rows.append("%s:%s %dy %d changes" % [u["name"].substr(0, 14), u["status"].substr(0, 3), life / 12, int(changes.get(id, 0))])
	print("seed %d: active sector unions after Y5 %d..%d, federation missing %d months" % [sd, min_active, max_active, fed_missing])
	print("seed %d: strikes per decade %s (general %d); strike outcomes %s" % [sd, dec_rows, general, outcomes])
	print("seed %d: strike-months on an empty fund %d, longest %d" % [sd, empty_strike_m, worst_empty])
	print("seed %d: demands %d, settled %d, talks failed %d, collapsed %d, founded %d, merged %d, split %d, dissolved %d" % [sd,
		w.facts.query("UNION_DEMAND").size(), w.facts.query("UNION_SETTLED").size(), w.facts.query("UNION_TALKS_FAILED").size(),
		w.facts.query("UNION_STRIKE_COLLAPSED").size(), w.facts.query("UNION_FOUNDED").size(), w.facts.query("UNION_MERGED").size(),
		w.facts.query("UNION_SPLIT").size(), w.facts.query("UNION_DISSOLVED").size()])
	print("seed %d: leaders %s" % [sd, leader_rows])
	print("seed %d: ledger %d" % [sd, w.ledger.total()])
	quit()
