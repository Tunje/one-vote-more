extends TestCase
## Election year (planning/spec-election-year-v1.md): calendar, themes, ads, attacks and backfire, debates,
## opposition research, smears, ground game, tactical support votes, determinism and save/load.
## Works before and after the provider hook: Campaign.monthly is idempotent within a month.

const FIRST_ELECTION := 44


func _sim(seed_value: int = 3) -> Simulation:
	return PoliticalSim.make(seed_value, "BALANCED", {})


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


## One month: the campaign for month m runs at the start of m (before the provider's vote in m).
func _tick(sim: Simulation) -> void:
	if not sim.world.table("party").is_empty() and sim.world.month > PolDefs.PARTY_FORMATION_MONTH:
		Campaign.monthly(sim.world, _st(sim.world))
	sim.run(1)


func _run_to(sim: Simulation, month: int) -> void:
	while sim.world.month < month:
		_tick(sim)


func _campaign_for(w: WorldState, election_month: int) -> Dictionary:
	for cid in w.table("campaign"):
		if int(w.table("campaign")[cid]["election_month"]) == election_month:
			return w.table("campaign")[cid]
	return {}


func test_campaign_opens_twelve_months_out_with_themes_and_targets() -> void:
	var sim := _sim()
	_run_to(sim, FIRST_ELECTION - 12)
	check(_campaign_for(sim.world, FIRST_ELECTION).is_empty(), "not open 13 months out")
	_tick(sim)
	var c := _campaign_for(sim.world, FIRST_ELECTION)
	check(not c.is_empty(), "election year opened at T-12")
	check_eq(int(c["opened"]), FIRST_ELECTION - 12, "opened month")
	check_eq(sim.world.facts.query("POL_CAMPAIGN_OPENED").size(), 1, "opening fact")
	for pid in c["parties"]:
		var e: Dictionary = c["parties"][pid]
		check_eq(e["themes"].size(), 2, "two themes for " + pid)
		for cn in e["themes"]:
			check(PolDefs.CONCERNS.has(cn), "theme is a concern")
		check(int(e["quality"]) >= 500 and int(e["quality"]) <= 1000, "quality in range")


func test_full_campaign_spends_debates_and_finalises() -> void:
	var sim := _sim()
	_run_to(sim, FIRST_ELECTION - 6)
	var w := sim.world
	for p in PartyLife.active(w):   # the stub world has no households paying dues
		PartyLife.open_account(w, p["id"])
		w.ledger.transfer(Ledger.EXTERNAL, "party:" + p["id"], 1000000, "TEST_FUNDS", w.month)
	_run_to(sim, FIRST_ELECTION + 2)
	var c := _campaign_for(w, FIRST_ELECTION)
	check_eq(c["status"], "DONE", "closed after the vote")
	check_eq(c["debates"].size(), 2, "leaders' debate + final debate")
	check(bool(c["debates"][1]["final"]), "final debate last")
	check_eq(int(c["debates"][1]["month"]), FIRST_ELECTION, "final debate in the election month")
	var spent := 0
	for pid in c["parties"]:
		spent += int(c["parties"][pid]["spent"])
	check(spent > 0, "parties spent money")
	check(not c["result"]["shares"].is_empty(), "result recorded")
	check(w.facts.query("POL_DEBATE_HELD").size() == 2, "debate facts")
	check(w.facts.query("POL_POLITICS_WEEK").size() == 1, "politics week in July")
	for f in w.facts.query("POL_DEBATE_HELD"):
		check(f["data"].has("channel"), "facts carry a media channel")
	check(not _st(w).has("campaign_id"), "no open campaign after the vote")
	var months := {}
	for pid in w.table("poll"):
		months[int(w.table("poll")[pid]["month"])] = true
	for m in [FIRST_ELECTION - 2, FIRST_ELECTION - 1]:
		check(months.has(m), "a poll every month of the short campaign (m%d)" % m)


func _open_campaign(sim: Simulation) -> Dictionary:
	_run_to(sim, FIRST_ELECTION - 3)
	return Campaign.current(sim.world)


func test_attack_ads_hurt_the_target_and_backfire_among_civil_voters() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	var b: String = ids[1]
	for pid in ids:
		c["parties"][pid]["persuasion"] = {}
		c["parties"][pid]["backfire"] = {}
		c["parties"][pid]["tone"] = "POSITIVE"
	c["parties"][a]["tone"] = "NEGATIVE"
	c["parties"][a]["target"] = b
	var spend := {}
	for pid in ids:
		spend[pid] = {"ad": 1000000, "ground": 0, "oppo": 0}
	var seg := Campaign.segments(w)
	Campaign._ads(w, c, seg, spend)
	var bsum := 0
	for k in c["parties"][b]["persuasion"]:
		bsum += int(c["parties"][b]["persuasion"][k])
	var base: Dictionary = c["parties"][ids[2]]["persuasion"] if ids.size() > 2 else {}
	var csum := 0
	for k in base:
		csum += int(base[k])
	check(bsum < csum, "attacked party gains less than an unattacked one (%d vs %d)" % [bsum, csum])
	var bf: Dictionary = c["parties"][a]["backfire"]
	check(int(bf.get("INSTITUTION", 0)) < int(bf.get("*", 0)), "civility voters punish harder (%s)" % str(bf))
	check(int(bf.get("*", 0)) < 0, "everyone punishes a little")
	check_eq(w.facts.query("POL_ATTACK_AD").size(), 1, "attack fact once")


func test_voter_utility_combines_segment_momentum_and_backfire_with_cap() -> void:
	var cache := {"parties": {"p1": {"persuasion": {"d1|INDUSTRY": 300}, "momentum": 200, "backfire": {"STABILITY": -100, "*": -20}, "mob": 0},
		"p2": {"persuasion": {"d1|INDUSTRY": 2000}, "momentum": 0, "backfire": {}, "mob": 0}}}
	var v := {"district": "d1", "vocc": "INDUSTRY", "cohort": "STABILITY"}
	var u := Campaign.voter_utility(cache, v)
	check(absf(float(u["p1"]) - 0.4) < 0.0001, "300+200-100 = 0.4 (%s)" % str(u))
	check(absf(float(u["p2"]) - float(Campaign.CAMPAIGN_U_CAP) / 1000.0) < 0.0001, "capped")
	var v2 := {"district": "d1", "vocc": "INDUSTRY", "cohort": "LABOR"}
	check(absf(float(Campaign.voter_utility(cache, v2)["p1"]) - 0.48) < 0.0001, "default backfire for other cohorts")
	check(Campaign.voter_utility({}, v).is_empty(), "no campaign, no effect")


func test_media_tilt_scales_good_news_not_backfire() -> void:
	var parties := {"p1": {"persuasion": {"d1|INDUSTRY": 200}, "momentum": 0, "backfire": {"*": -100}, "mob": 0},
		"p2": {"persuasion": {"d1|INDUSTRY": -200}, "momentum": 0, "backfire": {}, "mob": 0}}
	var v := {"district": "d1", "vocc": "INDUSTRY", "cohort": "LABOR"}
	var plain := Campaign.voter_utility({"parties": parties, "tilt": {}}, v)
	var tilted := Campaign.voter_utility({"parties": parties, "tilt": {"d1": {"p1": 1.3, "p2": 0.7}}}, v)
	check(absf(float(plain["p1"]) - 0.1) < 0.0001, "untilted: 200-100")
	check(absf(float(tilted["p1"]) - 0.16) < 0.0001, "friendly papers amplify good news only: 260-100 (%s)" % str(tilted))
	check(absf(float(tilted["p2"]) - float(plain["p2"])) < 0.0001, "bad news is not dampened or amplified")


func test_opposition_research_finds_secret_donations_first() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	var b: String = ids[1]
	w.table("donation_track")["f999999"] = {"id": "f999999", "party": b, "donor": "x", "amount": 5000, "excess": 5000,
		"cap": 1000, "undisclosed": true, "month": w.month, "revealed": false}
	c["parties"][a]["dirt"] = []
	check(Campaign._find_dirt(w, c, a, b, w.rng.stream("test")), "found")
	var d: Dictionary = c["parties"][a]["dirt"][0]
	check_eq(d["kind"], "DONATION", "real secret first")
	check_eq(d["fid"], "f999999", "the tracked violation")
	# the same secret is not found twice
	c["parties"][ids[2] if ids.size() > 2 else a]["dirt"] = c["parties"][ids[2] if ids.size() > 2 else a]["dirt"]
	check(Campaign._taken(c, "f999999"), "taken")


func test_released_dirt_hurts_the_target() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	var b: String = ids[1]
	var tp: Dictionary = w.table("party")[b]
	var pop0 := PartyLife.leader_popularity(tp)
	var m0 := int(c["parties"][b]["momentum"])
	var d := {"kind": "PERSONAL", "target": b, "fid": "", "sev": 30, "found": w.month, "released": -1, "exposed": false}
	c["parties"][a]["dirt"].append(d)
	Campaign.release(w, c, a, d, false)
	check(PartyLife.leader_popularity(tp) < pop0, "leader popularity down")
	check(int(c["parties"][b]["momentum"]) < m0, "momentum down")
	check_eq(int(d["released"]), w.month, "marked released")
	check_eq(w.facts.query("POL_DIRT_RELEASED").size(), 1, "news")


func test_exposed_smear_backfires_on_the_smearer() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	var b: String = ids[1]
	var p: Dictionary = w.table("party")[a]
	var cred0 := int(p["credibility"])
	var d := {"kind": "SMEAR", "target": b, "fid": "", "sev": 30, "found": w.month, "released": w.month, "exposed": false}
	var mb := int(c["parties"][b]["momentum"])
	Campaign._expose_smear(w, c, a, d)
	check(int(p["credibility"]) < cred0, "smearer loses credibility")
	check(int(c["parties"][a]["momentum"]) < 0, "smearer loses momentum")
	check(int(c["parties"][b]["momentum"]) > mb, "victim gains sympathy")
	check_eq(w.facts.query("POL_SMEAR_EXPOSED").size(), 1, "news")
	check(String(w.facts.query("POL_SMEAR_EXPOSED")[0]["data"].get("case", "")) != "", "the victim sues for defamation (Anni's court)")


func test_ground_game_mobilises_and_is_capped() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var ids: Array = Det_ordered(c["parties"])
	var spend := {}
	for pid in ids:
		c["parties"][pid]["ground"] = 1000
		spend[pid] = {"ad": 0, "ground": 1000, "oppo": 0}
	c["parties"][ids[0]]["ground"] = 1000000
	Campaign._ground(w, c, spend)
	var mob := Campaign.mobilisation(c)
	for pid in ids:
		check(float(mob[pid]) >= 1.0 and float(mob[pid]) <= 1.0 + float(Campaign.MOB_MAX) / 1000.0, "mobilisation in range")
	check(float(mob[ids[0]]) > float(mob[ids[1]]), "big spender mobilises more")


func test_support_votes_lift_a_small_ally_over_the_threshold() -> void:
	var sim := _sim()
	var w := sim.world
	_run_to(sim, FIRST_ELECTION + 3)
	var st := _st(w)
	var ids: Array = Det_ordered(w.table("party"))
	st["government"] = {"members": [ids[0], ids[1]], "pm_party": ids[0], "support": []}
	var votes := {ids[0]: 400000.0, ids[1]: 33000.0, ids[2]: 567000.0}
	var moved := Campaign.tactical(w, votes)
	check(moved.has(ids[1]), "ally received support votes")
	check(float(votes[ids[1]]) / 1000000.0 >= 0.04, "ally over 4%% (%.4f)" % (float(votes[ids[1]]) / 1000000.0))
	check(absf(float(votes[ids[0]]) + float(votes[ids[1]]) - 433000.0) < 0.5, "votes conserved")
	var none := {ids[0]: 400000.0, ids[1]: 10000.0, ids[2]: 590000.0}
	check(Campaign.tactical(w, none).is_empty(), "a hopeless ally gets nothing")


func test_extra_election_gets_a_compressed_campaign() -> void:
	var sim := _sim()
	var w := sim.world
	_run_to(sim, FIRST_ELECTION + 12)
	var st := _st(w)
	st["extra_election_month"] = w.month + 3
	_tick(sim)
	var c := Campaign.current(w)
	check(not c.is_empty(), "opened")
	check(bool(c["extra"]), "extra")
	check_eq(int(c["election_month"]), w.month + 2, "for the extra election")


func test_player_runs_their_own_campaign() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {}, false)   # a human player: no autoplay
	_run_to(sim, FIRST_ELECTION - 4)
	var w := sim.world
	var pp := String(_st(w).get("player_party", ""))
	var c := Campaign.current(w)
	check(pp != "" and c["parties"].has(pp), "player party campaigns")
	var e: Dictionary = c["parties"][pp]
	check(bool(e["manual"]), "a human's campaign is not replanned by the AI")
	check_eq(e["themes"].size(), 2, "starts from the AI's suggestion")
	check(not Campaign.player_set_themes(w, ["JOBS", "HOUSING", "SAFETY"])["ok"], "at most two themes")
	check(Campaign.player_set_themes(w, ["JOBS"])["ok"], "set themes")
	check_eq(e["themes"], ["JOBS"], "themes stored")
	check(not Campaign.player_set_split(w, 500, 500, 100)["ok"], "split must sum to 100%")
	check(Campaign.player_set_split(w, 400, 400, 200)["ok"], "split")
	var rival := ""
	for pid in Det_ordered(c["parties"]):
		if pid != pp:
			rival = pid
			break
	check(not Campaign.player_set_tone(w, "NEGATIVE", "")["ok"], "negative needs a target")
	check(Campaign.player_set_tone(w, "NEGATIVE", rival)["ok"], "go negative")
	check_eq(e["target"], rival, "target stored")
	check_eq(w.facts.query("POL_CAMPAIGN_GOES_NEGATIVE").filter(func(f): return f["data"]["party"] == pp).size(), 1, "news")
	e["dirt"].append({"kind": "PERSONAL", "target": rival, "fid": "", "sev": 20, "found": w.month, "released": -1, "exposed": false})
	_tick(sim)
	check_eq(int(e["dirt"][0]["released"]), -1, "the player's dirt is held until they release it")
	check(Campaign.player_release_dirt(w, 0)["ok"], "release")
	check(not Campaign.player_release_dirt(w, 0)["ok"], "only once")


func test_pork_pressure_only_early_in_election_year() -> void:
	var sim := _sim()
	var w := sim.world
	_run_to(sim, FIRST_ELECTION - 8)
	check_eq(Campaign.pork_pressure(w, _st(w)), 1.0, "T-8: pork")
	w.meta["pork"] = false
	check_eq(Campaign.pork_pressure(w, _st(w)), 0.0, "switch for A/B runs")
	w.meta["pork"] = true
	_run_to(sim, FIRST_ELECTION - 2)
	check_eq(Campaign.pork_pressure(w, _st(w)), 0.0, "T-2: too late to pass anything")


func test_pork_is_credited_to_credible_governments_and_punished_otherwise() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var st := _st(w)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	st["government"] = {"members": [a], "pm_party": a, "support": []}
	# a clause that relieves something the colony cares about
	var cs := Campaign.colony_concerns(w)
	var clause := {}
	for lid in Det_ordered(w.lever_defs):
		var def: Dictionary = w.lever_defs[lid]
		if def.get("type", "") != "NUMBER" or def.get("concerns", {}).is_empty():
			continue
		var cur := int(w.levers[lid])
		for dir in [1, -1]:
			var cl := {"lever": lid, "from": cur, "to": cur + dir * 10}
			if Legislature.relief(def, Legislature.clause_delta(def, cl), cs[0], cs[1]) > 0.05:
				clause = cl
				break
		if not clause.is_empty():
			break
	check(not clause.is_empty(), "found a popular clause")
	var fact := {"type": "POL_ORDINANCE_ISSUED", "owner": "pol", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 30, "visibility": "PUBLIC", "data": {"clauses": [clause]}}
	w.table("party")[a]["credibility"] = 90
	c["parties"][a]["momentum"] = 0
	w.add_fact(fact.duplicate(true))
	Campaign._pork(w, st, c)
	var m_hi := int(c["parties"][a]["momentum"])
	check(m_hi > 0, "credible government gains (%d)" % m_hi)
	w.month += 1
	w.table("party")[a]["credibility"] = 10
	c["parties"][a]["momentum"] = 0
	w.add_fact(fact.duplicate(true))
	Campaign._pork(w, st, c)
	check(int(c["parties"][a]["momentum"]) < 0, "transparent pork is punished")
	check_eq(w.facts.query("POL_ELECTION_PORK").size(), 2, "news")


func test_debate_night_questions_are_known_a_month_ahead() -> void:
	var sim := _sim()
	var w := sim.world
	_run_to(sim, FIRST_ELECTION - 2)
	_tick(sim)   # campaign month T-2 runs: the leaders' debate (T-1) is prepared
	var c := Campaign.current(w)
	var prep: Dictionary = c.get("debate_prep", {})
	check(not prep.is_empty(), "prepared")
	check_eq(int(prep["month"]), FIRST_ELECTION - 1, "for next month's debate")
	check_eq(prep["questions"].size(), 3, "three questions")
	var topics := {}
	for q in prep["questions"]:
		topics[q["topic"]] = true
		check(PolDefs.CONCERNS.has(q["topic"]), "topic is a concern")
	check_eq(topics.size(), 3, "distinct topics")


func test_player_answers_shape_the_debate() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {}, false)
	var w := sim.world
	_run_to(sim, FIRST_ELECTION - 1)   # prep exists for the debate at T-1
	var st := _st(w)
	var pp := String(st["player_party"])
	check(not Campaign.player_debate_answer(w, 5, "ATTACK")["ok"], "bad index")
	check(not Campaign.player_debate_answer(w, 0, "SHOUT")["ok"], "bad stance")
	for i in 3:
		check(Campaign.player_debate_answer(w, i, "PIVOT")["ok"], "answer %d" % i)
	_tick(sim)
	var c := _campaign_for(w, FIRST_ELECTION)
	var d: Dictionary = c["debates"][0]
	check(d["answers"].has(pp), "player was on stage")
	for a in d["answers"][pp]:
		check_eq(a["stance"], "PIVOT", "the player's own stance was used")
	check(not c.has("debate_prep") or int(c["debate_prep"]["month"]) == FIRST_ELECTION, "next prep is the final")


func test_stance_fit_rewards_defending_a_good_record() -> void:
	var sim := _sim()
	var w := sim.world
	var c := _open_campaign(sim)
	var st := _st(w)
	var ids: Array = Det_ordered(c["parties"])
	var a: String = ids[0]
	st["government"] = {"members": [a], "pm_party": a, "support": []}
	var cs := Campaign.colony_concerns(w)
	var best := ""
	var worst := ""
	for cn in PolDefs.CONCERNS:
		if best == "" or int(cs[0][cn]) > int(cs[0][best]):
			best = cn
		if worst == "" or int(cs[0][cn]) < int(cs[0][worst]):
			worst = cn
	var p: Dictionary = w.table("party")[a]
	check(Campaign.stance_fit(w, st, c, p, best, "DEFEND") > Campaign.stance_fit(w, st, c, p, worst, "DEFEND"),
		"defending the best record beats defending the worst")
	var f := Campaign.stance_fit(w, st, c, p, worst, "ATTACK")
	check(f >= -0.6 and f <= 0.8, "fit in range")


func test_deterministic_and_save_load_mid_campaign() -> void:
	var ref := _sim(7)
	_run_to(ref, FIRST_ELECTION - 5)
	check_eq(SaveIO.save(ref, save_path("campaign.sav")), OK, "save")
	_run_to(ref, FIRST_ELECTION + 2)
	var loaded := PoliticalSim.for_load()
	check_eq(SaveIO.load_into(loaded, save_path("campaign.sav")), OK, "load")
	_run_to(loaded, FIRST_ELECTION + 2)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "save/load/continue identical")
	var again := _sim(7)
	_run_to(again, FIRST_ELECTION + 2)
	check_eq(again.world.state_hash(), ref.world.state_hash(), "deterministic")


static func Det_ordered(d: Dictionary) -> Array:
	var ks: Array = d.keys()
	ks.sort()
	return ks
