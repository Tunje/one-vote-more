extends TestCase
## M9 living party system (planning/spec-politics-v2.md): leaders, factions, splits, mergers,
## dissolution, foundings, donations, endorsements.


func _sim(months: int = 50) -> Simulation:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	sim.run(months)
	return sim


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


func test_every_party_has_a_leader_and_factions() -> void:
	var w := _sim().world
	for p in PartyLife.active(w):
		var l: Dictionary = p["leader"]
		check(l.has("charisma") and l.has("competence") and l.has("integrity"), "leader traits")
		check(String(l["name"]) != "", "leader name")
		check_eq(p["factions"].size(), 2, "two factions")
		check(PolDefs.AXES.has(p["faction_axis"]), "faction axis")
		check(w.ledger.has_account("party:" + p["id"]), "party account")


func test_leader_popularity_moves_votes() -> void:
	var w := _sim().world
	var cell: Dictionary = w.table("cell").values().filter(func(c): return c["pop"] > 0)[0]
	var p: Dictionary = PartyLife.active(w)[1]
	p["leader"]["popularity"] = 20
	var lo := VoteModel.utility(cell, p, {})
	p["leader"]["popularity"] = 90
	var hi := VoteModel.utility(cell, p, {})
	check(hi > lo + 0.4, "popular leader raises utility (%.2f vs %.2f)" % [hi, lo])


func test_split_takes_seats_and_can_cost_the_government_its_majority() -> void:
	var w := _sim().world
	var st := _st(w)
	var g: Dictionary = st["government"]
	var pm: Dictionary = w.table("party")[g["pm_party"]]
	var before_seats: int = pm["seats"]
	var before_yes: int = g["yes"]
	var fi := 1 - int(pm["leader"]["faction"])
	pm["factions"][fi]["strength"] = 400
	var np := PartyLife.split_party(w, st, pm, fi)
	check_eq(np["kind"], "SPLINTER", "splinter party")
	check(int(np["seats"]) > 0, "splinter took MPs")
	check_eq(int(pm["seats"]) + int(np["seats"]), before_seats, "seats conserved")
	check_eq(int(g["yes"]), before_yes - int(np["seats"]), "government lost the splinter's seats")
	check_eq(w.facts.query("POL_PARTY_SPLIT").size(), 1, "split fact")


func test_merger_combines_parties() -> void:
	var w := _sim().world
	var st := _st(w)
	var ps := PartyLife.active(w).filter(func(q): return not q["is_player"])
	var big: Dictionary = ps[0]
	var small: Dictionary = ps[1]
	var seats: int = int(big["seats"]) + int(small["seats"])
	PartyLife.merge(w, st, big, small)
	check_eq(small["status"], "MERGED", "absorbed")
	check_eq(int(big["seats"]), seats, "seats combined")
	for c in w.table("cell").values():
		check_eq(int(c["prev_share"].get(small["id"], 0)), 0, "loyalty moved")
		break


func test_dissolution_only_after_three_years_under_a_tenth_of_a_percent() -> void:
	var w := _sim().world
	var st := _st(w)
	var p: Dictionary = PartyLife.active(w).filter(func(q): return not q["is_player"])[0]
	var ok := {}
	for q in PartyLife.active(w):
		ok[q["id"]] = 3000
	var low := ok.duplicate()
	low[p["id"]] = 99
	PartyLife.check_dissolutions(w, st, low)
	w.month += 35
	PartyLife.check_dissolutions(w, st, low)
	check_eq(p["status"], "ACTIVE", "35 months under 0.1% is survivable")
	PartyLife.check_dissolutions(w, st, ok)
	w.month += 1
	PartyLife.check_dissolutions(w, st, low)
	w.month += 36
	PartyLife.check_dissolutions(w, st, ok)
	check_eq(p["status"], "ACTIVE", "a recovery resets the clock; 3% is never dissolved")
	PartyLife.check_dissolutions(w, st, low)
	w.month += 36
	PartyLife.check_dissolutions(w, st, low)
	check_eq(p["status"], "DISSOLVED", "36 months running under 0.1% winds the party up")
	check_eq(w.facts.query("POL_PARTY_DISSOLVED").size(), 1, "dissolution fact")


func test_single_issue_party_founded_on_long_grievance() -> void:
	var w := _sim().world
	var st := _st(w)
	var lc := PartyLife.lifecycle(st)
	lc["last_founding"] = -99
	for p in PartyLife.active(w):
		p["ownership"].erase("HOUSING")
	lc["issue_months"]["HOUSING"] = PartyLife.ISSUE_MONTHS
	var n := PartyLife.active(w).size()
	PartyLife.check_foundings(w, st)
	check_eq(PartyLife.active(w).size(), n + 1, "new party")
	var f: Array = w.facts.query("POL_PARTY_FOUNDED")
	check_eq(f[-1]["data"]["kind"], "SINGLE_ISSUE", "single issue")
	check_eq(f[-1]["data"]["concern"], "HOUSING", "on housing")


func test_leadership_contest_after_election_loss() -> void:
	var w := _sim().world
	var st := _st(w)
	var changed := 0
	for p in PartyLife.active(w):
		var before := {p["id"]: int(p["support"]) + 6000}
		p["factions"][1 - int(p["leader"]["faction"])]["strength"] = 800
		p["factions"][1 - int(p["leader"]["faction"])]["discontent"] = 90
		var old := PartyLife.leader_name(p)
		PartyLife.post_election_contests(w, st, before)
		if PartyLife.leader_name(p) != old:
			changed += 1
	check(changed >= 1, "strong angry factions topple leaders (%d)" % changed)
	check_eq(w.facts.query("POL_LEADER_CHANGED").size() + w.facts.query("POL_LEADER_SURVIVED").size() >= PartyLife.active(w).size(), true, "every contest is a fact")


func test_donation_booked_to_best_matching_party() -> void:
	var w := _sim().world
	var co := EconUtil.acct("TESTCO")
	w.ledger.open_account(co)
	w.ledger.transfer(Ledger.EXTERNAL, co, 1000000, "TEST", w.month)
	var amount := 3000  # small, lawful and below the disclosure threshold
	w.table("donation_offer")["TESTCO"] = {"from": "TESTCO", "amount_milli": amount, "prefers": {"REDISTRIBUTION": -1, "LABOR": -1}, "month": w.month}
	# make one seated party the obvious match
	var target: Dictionary = PartyLife.active(w).filter(func(q): return int(q["seats"]) > 0)[0]
	target["positions"]["REDISTRIBUTION"] = -90000
	target["positions"]["LABOR"] = -90000
	var bal := w.ledger.balance("party:" + target["id"])
	PartyLife._book_donations(w)
	check_eq(w.ledger.balance("party:" + target["id"]), bal + amount, "money moved company -> party")
	var f: Array = w.facts.query("POL_DONATION")
	check_eq(f.size(), 1, "donation fact")
	check_eq(f[0]["data"]["party"], target["id"], "to the matching party")
	check_eq(w.ledger.total(), 0, "ledger balanced")


func test_union_endorsement_helps_pro_labour_party_among_members() -> void:
	var w := _sim().world
	var e := {"union": "P1", "business": "P2", "density": {"MINING": 60000}}
	var miner := {"occ": "MINING"}
	var owner := {"occ": "BUSINESS_OWNER"}
	check(PartyLife.endorsement_bonus(miner, e).get("P1", 0.0) > 0.4, "unionised miners follow the endorsement")
	check(PartyLife.endorsement_bonus(owner, e).get("P2", 0.0) > 0.2, "owners follow the business federation")
	check_eq(PartyLife.endorsement_bonus(owner, e).get("P1", 0.0), 0.0, "no union bonus without density")
