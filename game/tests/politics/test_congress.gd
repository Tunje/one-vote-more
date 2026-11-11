extends TestCase
## Party congresses and leadership races (planning/spec-election-year-v1.md §9).

const FIRST_ELECTION := 44


func _sim(autoplay: bool = true) -> Simulation:
	var sim := PoliticalSim.make(3, "BALANCED", {}, autoplay)
	sim.run(50)   # after the first election; next one at m92
	return sim


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


func _ai_party(w: WorldState) -> Dictionary:
	return PartyLife.active(w).filter(func(q): return not q["is_player"])[0]


func test_lost_election_opens_a_race_decided_two_months_later() -> void:
	var w := _sim().world
	var st := _st(w)
	var p := _ai_party(w)
	PartyLife.leadership_contest(w, st, p, "ELECTION_LOSS")
	var race := Congress.race_of(w, p["id"])
	check(not race.is_empty(), "race opened")
	check(race["candidates"].size() >= 2, "a candidate per faction")
	check(bool(race["candidates"][0]["incumbent"]), "the leader defends")
	check_eq(w.facts.query("POL_LEADERSHIP_RACE_OPENED").size(), 1, "race news")
	var changed0 := w.facts.query("POL_LEADER_CHANGED").size() + w.facts.query("POL_LEADER_SURVIVED").size()
	w.month += 1
	Congress.monthly(w, st)
	check(Congress.race_of(w, p["id"]).is_empty() == false, "still running after one month")
	w.month += 1
	Congress.monthly(w, st)
	check(Congress.race_of(w, p["id"]).is_empty(), "decided")
	check_eq(w.facts.query("POL_LEADER_CHANGED").size() + w.facts.query("POL_LEADER_SURVIVED").size(), changed0 + 1, "one outcome fact")
	check(not race["result"].is_empty(), "result recorded")


func test_forced_contest_still_replaces_the_leader_at_once() -> void:
	var w := _sim().world
	var p := _ai_party(w)
	var old := PartyLife.leader_name(p)
	PartyLife.leadership_contest(w, _st(w), p, "SCANDAL")
	check(PartyLife.leader_name(p) != old, "replaced immediately")
	check(Congress.race_of(w, p["id"]).is_empty(), "no race")


func test_snap_race_close_to_an_election() -> void:
	var w := _sim().world
	var st := _st(w)
	w.month = int(st["next_election"]) - 2
	var p := _ai_party(w)
	PartyLife.leadership_contest(w, st, p, "ELECTION_LOSS")
	check(Congress.race_of(w, p["id"]).is_empty(), "decided on the spot")
	var f: Array = w.facts.query("POL_LEADERSHIP_RACE_OPENED")
	check(bool(f.back()["data"]["snap"]), "snap vote")


func test_a_strong_angry_faction_usually_wins_and_the_loser_gets_bitter() -> void:
	var wins := 0
	for k in 6:
		var sim := PoliticalSim.make(10 + k, "BALANCED", {})
		sim.run(50)
		var w := sim.world
		var st := _st(w)
		var p := _ai_party(w)
		var ch := 1 - int(p["leader"]["faction"])
		p["factions"][ch]["strength"] = 800
		p["factions"][1 - ch]["strength"] = 200
		p["factions"][ch]["discontent"] = 90
		var inc_disc := int(p["factions"][1 - ch]["discontent"])
		Congress.open_race(w, st, p, "ELECTION_LOSS")
		w.month += Congress.RACE_MONTHS
		Congress.monthly(w, st)
		if int(p["leader"]["faction"]) == ch:
			wins += 1
			check(int(p["factions"][1 - ch]["discontent"]) > inc_disc, "the old leadership's faction is bitter")
	check(wins >= 4, "the strong angry faction wins most races (%d/6)" % wins)


func test_per_term_congress_sets_the_manifesto_the_campaign_starts_from() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	var w := sim.world
	var st := _st(w)
	sim.run(92 - Congress.CONGRESS_AT_TO_GO + 1)   # through the congress month (T-18 before m92)
	var m := 92 - Congress.CONGRESS_AT_TO_GO
	check_eq(w.facts.query("POL_CONGRESS_HELD", m, m).size(), PartyLife.active(w).size(), "every party held a congress at T-18")
	var p := _ai_party(w)
	var cg := Congress.latest(w, p["id"])
	check_eq(cg["themes"].size(), 2, "manifesto themes")
	sim.run(Congress.CONGRESS_AT_TO_GO - Campaign.WINDOW_ORDINARY + 1)   # into election year
	var c := Campaign.current(w)
	check(not c.is_empty(), "campaign open")
	check_eq(c["parties"][p["id"]]["themes"], cg["themes"], "the campaign runs on the congress manifesto")


func test_human_party_answers_a_hostile_motion_within_the_yearly_limit() -> void:
	var w := _sim(false).world
	var st := _st(w)
	var pp: Dictionary = w.table("party")[st["player_party"]]
	PartyLife.ensure_factions(pp)
	var rebel := 1 - int(pp["leader"]["faction"])
	pp["factions"][rebel]["discontent"] = 80
	pp["factions"][rebel]["pole"] = int(pp["positions"][pp["faction_axis"]]) + 30000
	var row := Congress.hold_congress(w, st, pp)
	check_eq(row["motion"].get("status", ""), "PENDING", "a motion waits for the player")
	var ax: String = pp["faction_axis"]
	var before := int(pp["positions"][ax])
	check(Congress.player_answer_motion(w, "ACCEPT")["ok"], "accept")
	var moved := (int(pp["positions"][ax]) - before) / 1000
	check(moved > 0 and moved <= PolActions.PLATFORM_YEARLY_MOVE, "shifted toward the rebels inside the yearly limit (%d)" % moved)
	check(not Congress.player_answer_motion(w, "FIGHT")["ok"], "already answered")
	# fighting the next one costs popularity
	pp["factions"][rebel]["discontent"] = 80
	Congress.hold_congress(w, st, pp)
	var pop0 := int(pp["leader"]["popularity"])
	check(Congress.player_answer_motion(w, "FIGHT")["ok"], "fight")
	check(int(pp["leader"]["popularity"]) < pop0, "fighting the members costs popularity")


func test_congress_deterministic_and_save_load() -> void:
	var ref := PoliticalSim.make(5, "BALANCED", {})
	ref.run(75)
	check_eq(SaveIO.save(ref, save_path("congress.sav")), OK, "save")
	ref.run(30)
	var loaded := PoliticalSim.for_load()
	check_eq(SaveIO.load_into(loaded, save_path("congress.sav")), OK, "load")
	loaded.run(30)
	check_eq(loaded.world.state_hash(), ref.world.state_hash(), "save/load/continue identical")
