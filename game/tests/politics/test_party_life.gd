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
	var cell: Dictionary = PolVoters.all(w).filter(func(c): return c["pop"] > 0)[0]
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
	for c in PolVoters.all(w):
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
	var old := {}
	for p in PartyLife.active(w):
		var before := {p["id"]: int(p["support"]) + 6000}
		p["factions"][1 - int(p["leader"]["faction"])]["strength"] = 800
		p["factions"][1 - int(p["leader"]["faction"])]["discontent"] = 90
		old[p["id"]] = PartyLife.leader_name(p)
		PartyLife.post_election_contests(w, st, before)
	# election year (Ella): a lost election opens a leadership race; the members vote at a congress two months later
	w.month += Congress.RACE_MONTHS
	Congress.monthly(w, st)
	for p in PartyLife.active(w):
		if PartyLife.leader_name(p) != old[p["id"]]:
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


## Two newest polls with the given estimates (per-100000); everyone else at `rest`.
func _plant_polls(w: WorldState, shares: Dictionary, rest: int) -> void:
	var est := {}
	for q in PartyLife.active(w):
		est[q["id"]] = int(shares.get(q["id"], rest))
	for k in 2:
		w.table("poll")["ztest%d" % k] = {"id": "ztest%d" % k, "month": w.month + 1 + k, "by": "test", "moe_milli": 0, "estimates": est.duplicate()}


func test_crowded_field_absorbs_a_small_party_above_the_threshold() -> void:
	var w := _sim().world
	var st := _st(w)
	var ps := PartyLife.active(w).filter(func(q): return not q["is_player"])
	var big: Dictionary = ps[0]
	var small: Dictionary = ps[1]
	small["founded_month"] = w.month - 100
	small["positions"] = big["positions"].duplicate()
	check(PartyLife.active(w).size() <= PartyLife.SOFT_MAX_PARTIES, "field not crowded yet")
	_plant_polls(w, {small["id"]: 6000}, 10000)
	PartyLife.check_mergers(w, st)
	check_eq(small["status"], "ACTIVE", "6% is safe in an uncrowded field")
	while PartyLife.active(w).size() <= PartyLife.SOFT_MAX_PARTIES:
		var pos: Dictionary = big["positions"].duplicate()
		pos[PolDefs.AXES[0]] = -int(pos[PolDefs.AXES[0]])
		PartyLife._new_party(w, st, pos, "TEST")   # fresh parties: inside their grace period
	_plant_polls(w, {small["id"]: 6000}, 10000)
	for q in PartyLife.active(w):
		if int(q["founded_month"]) == w.month:
			w.table("poll")["ztest0"]["estimates"][q["id"]] = 0
			w.table("poll")["ztest1"]["estimates"][q["id"]] = 0
	PartyLife.check_mergers(w, st)
	check_eq(small["status"], "MERGED", "a crowded field absorbs a 6% party")
	var f: Array = w.facts.query("POL_PARTIES_MERGED")
	check_eq(String(f.back()["data"]["reason"]), "CROWDED", "reason recorded")


func test_weak_splinter_folds_back_into_its_parent_after_two_terms() -> void:
	var w := _sim().world
	var st := _st(w)
	var pm: Dictionary = w.table("party")[st["government"]["pm_party"]]
	var np := PartyLife.split_party(w, st, pm, 1 - int(pm["leader"]["faction"]))
	check_eq(String(np["split_from"]), String(pm["id"]), "the splinter remembers its parent")
	np["positions"] = pm["positions"].duplicate()
	np["founded_month"] = w.month - PartyLife.FOLDBACK_MONTHS + 3
	_plant_polls(w, {np["id"]: 5000}, 12000)
	PartyLife.check_mergers(w, st)
	check_eq(np["status"], "ACTIVE", "not before two terms")
	np["founded_month"] = w.month - PartyLife.FOLDBACK_MONTHS
	_plant_polls(w, {np["id"]: 7000}, 12000)
	PartyLife.check_mergers(w, st)
	check_eq(np["status"], "ACTIVE", "a 7% splinter has made it")
	_plant_polls(w, {np["id"]: 5000}, 12000)
	PartyLife.check_mergers(w, st)
	check_eq(np["status"], "MERGED", "folded back")
	check_eq(String(np["merged_into"]), String(pm["id"]), "into the party it left")


func test_faction_line_is_judged_against_the_other_parties() -> void:
	var w := _sim().world
	var p: Dictionary = PartyLife.active(w).filter(func(q): return not q["is_player"])[0]
	var raw: Dictionary = PartyLife.faction_axis_scores(w, p)["scores"]
	var top := ""
	for ax in PolDefs.AXES:
		if raw.has(ax) and (top == "" or float(raw[ax]) > float(raw[top])):
			top = ax
	var flat := {}
	for ax in raw:
		flat[ax] = 1.0
	p["faction_axis"] = ""
	PartyLife.update_factions(w, p, flat)
	check_eq(p["faction_axis"], top, "a flat baseline keeps the raw choice")
	var heavy := flat.duplicate()
	heavy[top] = 1000.0   # every party is divided on this axis: not this party's own conflict
	p["faction_axis"] = ""
	PartyLife.update_factions(w, p, heavy)
	check(p["faction_axis"] != top, "an axis that divides everyone is not the party's own line (%s)" % p["faction_axis"])
	var base := PartyLife.axis_baseline(w)
	check_eq(base.size(), raw.size(), "baseline per axis")


func test_no_new_single_issue_party_while_the_issue_is_owned() -> void:
	var w := _sim().world
	var st := _st(w)
	var c := "HOUSING"
	var lc := PartyLife.lifecycle(st)
	var ps := PartyLife.active(w)
	for q in ps:
		q["ownership"][c] = 0
	var n0 := PartyLife.active(w).size()
	ps[0]["ownership"][c] = PartyLife.ISSUE_CREDIBLE
	lc["issue_months"][c] = PartyLife.ISSUE_MONTHS
	check(not PartyLife._found_single_issue(w, st, PartyLife.active(w)), "a credible owner blocks it")
	ps[0]["ownership"][c] = 0
	ps[1]["issue"] = c
	lc["issue_months"][c] = PartyLife.ISSUE_MONTHS
	check(not PartyLife._found_single_issue(w, st, PartyLife.active(w)), "an earlier single-issue party still around blocks it")
	ps[1].erase("issue")
	lc["issue_months"][c] = PartyLife.ISSUE_MONTHS
	check(PartyLife._found_single_issue(w, st, PartyLife.active(w)), "an unowned issue gets its party")
	var np: Dictionary = PartyLife.active(w).filter(func(q): return q.get("issue", "") == c)[0] if PartyLife.active(w).size() > n0 else {}
	check_eq(String(np.get("issue", "")), c, "the new party remembers its issue")
