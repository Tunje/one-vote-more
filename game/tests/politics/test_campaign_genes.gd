extends TestCase
## A53 campaign genes (Ella; planning/spec-learning-party-v1.md L0): G_ISSUE, G_NEGATIVE, G_SPEND, G_PORK, G_UNION.
## A genome of 500s reproduces today's campaign exactly; each gene moves its decision the documented way.

const FIRST_ELECTION := 44


func _st(w: WorldState) -> Dictionary:
	return w.table("pol")["state"]


func _run_to(sim: Simulation, month: int) -> void:
	while sim.world.month < month:
		if not sim.world.table("party").is_empty() and sim.world.month > PolDefs.PARTY_FORMATION_MONTH:
			Campaign.monthly(sim.world, _st(sim.world))
		sim.run(1)


func _set_all(w: WorldState, genes: Dictionary) -> void:
	for pid in w.table("party"):
		w.table("party")[pid]["strategy"] = genes.duplicate()


func test_a_genome_of_500s_changes_nothing() -> void:
	var a := PoliticalSim.make(3, "BALANCED", {})
	var b := PoliticalSim.make(3, "BALANCED", {})
	_run_to(a, PolDefs.PARTY_FORMATION_MONTH + 2)
	_run_to(b, PolDefs.PARTY_FORMATION_MONTH + 2)
	var g := {}
	for k in Learn.GENES:
		g[k] = 500
	_set_all(b.world, g)
	_run_to(a, FIRST_ELECTION + 1)
	_run_to(b, FIRST_ELECTION + 1)
	check_eq(var_to_str(a.world.table("campaign")), var_to_str(b.world.table("campaign")), "same campaigns")
	check_eq(var_to_str(a.world.table("pol")["state"].get("last_result", {})), var_to_str(b.world.table("pol")["state"].get("last_result", {})), "same result")


func test_spend_and_negative_genes_move_their_decisions() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	_run_to(sim, FIRST_ELECTION - 6)
	var w := sim.world
	var c := Campaign.current(w)
	var p: Dictionary = PartyLife.active(w)[0]
	var acc := "party:" + String(p["id"])
	w.ledger.transfer(Ledger.EXTERNAL, acc, 100_000_000, "TEST", w.month)
	var spent := {}
	for g in [0, 1000]:
		p["strategy"] = {"G_SPEND": g}
		var before := int(c["parties"][p["id"]]["spent"])
		var bal := w.ledger.balance(acc)
		Campaign._spend(w, c, 6)
		spent[g] = int(c["parties"][p["id"]]["spent"]) - before
		w.ledger.transfer(Ledger.EXTERNAL, acc, bal - w.ledger.balance(acc), "TEST", w.month)   # same purse for both
	check(int(spent[1000]) > 2 * int(spent[0]), "a spender spends (%d vs %d)" % [spent[1000], spent[0]])
	var e: Dictionary = c["parties"][p["id"]]
	e["manual"] = false
	if String(e["target"]) == "":
		e["target"] = PartyLife.active(w)[1]["id"]
	var tones := {}
	for g in [0, 1000]:
		p["strategy"] = {"G_NEGATIVE": g}
		Campaign._set_tone(w, _st(w), c, p, e)
		tones[g] = Campaign.TONES.find(String(e["tone"]))
	check(int(tones[1000]) >= int(tones[0]), "attack-minded goes no less negative")
	p["strategy"] = {"G_NEGATIVE": 1000}
	var l: Dictionary = p["leader"]
	var integ := int(l["integrity"])
	l["integrity"] = 50
	Campaign._set_tone(w, _st(w), c, p, e)
	check_eq(String(e["tone"]), "NEGATIVE", "an attack-minded party at middling integrity goes negative")
	p["strategy"] = {"G_NEGATIVE": 0}
	l["integrity"] = 80
	Campaign._set_tone(w, _st(w), c, p, e)
	check(String(e["tone"]) != "NEGATIVE", "a clean one with an honest leader does not")
	l["integrity"] = integ
	p.erase("strategy")


func test_issue_gene_trades_own_issues_for_the_voters_worries() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	_run_to(sim, FIRST_ELECTION - 6)
	var w := sim.world
	var st := _st(w)
	var p: Dictionary = PartyLife.active(w)[0]
	# a party owning one niche concern: the low gene keeps it, the high gene drops it for what voters worry about
	var own := {}
	for cn in PolDefs.CONCERNS:
		own[cn] = 0
	own["COLONIAL_BURDEN"] = 100
	var keep: Dictionary = p.get("ownership", {})
	p["ownership"] = own
	var picks := {}
	for g in [0, 1000]:
		p["strategy"] = {"G_ISSUE": g}
		picks[g] = Campaign.pick_themes(w, st, p, Campaign.segments(w))
	check("COLONIAL_BURDEN" in picks[0], "core-issue party pushes its own issue (%s)" % str(picks[0]))
	check(picks[0] != picks[1000], "the worry-chaser picks differently (%s vs %s)" % [str(picks[0]), str(picks[1000])])
	p["ownership"] = keep
	p.erase("strategy")


func test_pork_and_union_genes() -> void:
	var sim := PoliticalSim.make(3, "BALANCED", {})
	_run_to(sim, FIRST_ELECTION - 8)
	var w := sim.world
	var st := _st(w)
	var p: Dictionary = PartyLife.active(w)[0]
	st["government"] = {"members": [p["id"]], "pm_party": p["id"], "support": []}
	var base := Campaign.pork_pressure(w, st)
	check_eq(base, 1.0, "election year, default gene")
	p["strategy"] = {"G_PORK": 1000}
	check_eq(Campaign.pork_pressure(w, st), 1.5, "a pork-barrel First Minister's party")
	p["strategy"] = {"G_PORK": 0}
	check_eq(Campaign.pork_pressure(w, st), 0.5, "a frugal one")
	var u := {"id": "u", "sectors": ["MINING"], "federation": false, "leader": {"militancy": 50}}
	p["strategy"] = {}
	var s0 := UnionPolitics.score(w, u, p)
	p["strategy"] = {"G_UNION": 1000}
	check(absf(UnionPolitics.score(w, u, p) - s0 - Campaign.GENE_UNION_PTS) < 1e-6, "courting the unions")
	p.erase("strategy")
