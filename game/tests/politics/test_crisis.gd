extends TestCase
## M7: formation rounds, mandatory extra elections, partner exit, no-confidence.

const FAR := 100000


func _sim_with_government(min_members: int = 1) -> Simulation:
	for seed_v in range(1, 20):
		var sim := PoliticalSim.make(seed_v, "BALANCED", {})
		sim.run(50)
		var g: Dictionary = sim.world.peek("pol")["state"]["government"]
		if not g.is_empty() and g["members"].size() >= min_members:
			return sim
	return null


func _facts(w: WorldState, t: String) -> Array:
	return w.facts.query(t)


func test_failed_formation_forces_extra_election_without_resetting_calendar() -> void:
	var sim := _sim_with_government()
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	var ordinary: int = st["next_election"]
	# Make every party irreconcilable: alternating corners, so every cabinet is voted down.
	# [7,3,4] simplex code: every pair of platforms differs on exactly 4 of 7 axes (= 114 points), beyond
	# the most tolerant round (75), and two-party centres sit > 50 from each member, so every cabinet fails.
	var g1 := [0, 0, 0, 1, 1, 1, 1, 0]
	var g2 := [0, 1, 1, 0, 0, 1, 1, 0]
	var g3 := [1, 0, 1, 0, 1, 0, 1, 0]
	var active: Array = w.table("party").values().filter(func(p): return p["status"] == "ACTIVE")
	var i := 0
	for p in active:
		for k in PolDefs.AXES.size():
			var bit: int = ((i & 1) * g1[k]) ^ (((i >> 1) & 1) * g2[k]) ^ (((i >> 2) & 1) * g3[k])
			p["positions"][PolDefs.AXES[k]] = FAR if bit == 1 else -FAR
		p["seats"] = 151 / active.size() + (151 % active.size() if i == 0 else 0)
		i += 1
	GovCrisis.start_formation(w, st, "TEST")
	for _r in PolDefs.MAX_FORMATION_ROUNDS:
		GovCrisis.formation_step(w, st)
	check(not st.has("formation"), "formation ends after max rounds")
	check(st.has("extra_election_month"), "extra election scheduled")
	check_eq(_facts(w, "POL_PM_VOTE_FAILED").size() >= PolDefs.MAX_FORMATION_ROUNDS, true, "each failed PM vote is a fact")
	var elections_before: int = st["elections"].size()
	sim.run(GovCrisis.EXTRA_ELECTION_DELAY + 1)
	check_eq(st["elections"].size(), elections_before + 1, "extra election held")
	check_eq(st["next_election"], ordinary, "ordinary calendar unchanged")


func test_partner_walks_out_when_cohesion_collapses() -> void:
	var sim := _sim_with_government()
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	var g: Dictionary = st["government"]
	# Build a two-party coalition by hand (the stub colony tends to produce single-party minority cabinets).
	var partner := ""
	for pid in w.table("party"):
		if not (pid in g["members"]) and w.table("party")[pid]["seats"] > 0:
			partner = pid
			break
	var old: Array = g["members"].duplicate()
	g["members"].append(partner)
	preload("res://sim/staff/staff_ops.gd").on_coalition_change(w, old, g["members"])
	st["cohesion"] = {partner: 70}
	st["cohesion"][partner] = 5
	st["cohesion_low"] = {partner: GovCrisis.EXIT_MONTHS - 1}
	st["next_election"] = w.month + 40
	GovCrisis.cohesion_step(w, st)
	check(not (partner in st["government"]["members"]), "partner left")
	check_eq(_facts(w, "POL_PARTNER_LEFT").size(), 1, "partner exit fact")
	check(_facts(w, "STAFF_OFFICIALS_WITHDRAWN").size() >= 1, "officials withdrawn")


func test_no_confidence_topples_government() -> void:
	var sim := _sim_with_government()
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	var g: Dictionary = st["government"]
	var old_pm: String = g["pm_party"]
	var mover := ""
	for pid in w.table("party"):
		var p: Dictionary = w.table("party")[pid]
		if not (pid in g["members"]):
			for ax in PolDefs.AXES:
				p["positions"][ax] = -int(g["center"][ax]) if absi(int(g["center"][ax])) > 30000 else (FAR if int(g["center"][ax]) <= 0 else -FAR)
			if mover == "" or p["seats"] > w.table("party")[mover]["seats"]:
				mover = pid
	var hostile := 0
	for pid in w.table("party"):
		if not (pid in g["members"]):
			hostile += int(w.table("party")[pid]["seats"])
	var r := GovCrisis.vote_no_confidence(w, st, mover)
	check_eq(r["passed"], hostile >= PolDefs.MAJORITY, "passes iff the opposition holds a majority (%d seats)" % hostile)
	if r["passed"]:
		check(st.has("formation") or st["government"].get("formed_month", -1) == w.month, "new formation started")
		check(_facts(w, "POL_NO_CONFIDENCE_PASSED").size() == 1, "fact")
		check(old_pm != "" , "had a PM")


func test_player_cannot_move_no_confidence_while_governing() -> void:
	var sim := _sim_with_government()
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	st["government"]["members"].append(st["player_party"]) if not (st["player_party"] in st["government"]["members"]) else null
	check(not PolActions.player_move_no_confidence(w)["ok"], "governing party refused")


func test_crisis_runs_deterministic() -> void:
	var a := PoliticalSim.make(8, "RECESSION", {})
	var b := PoliticalSim.make(8, "RECESSION", {})
	a.run(150)
	b.run(150)
	check_eq(a.world.state_hash(), b.world.state_hash(), "deterministic with crisis mechanics")
