extends TestCase
## v11 incumbent-loss switches (planning/ab-incumbent.md): RULE_COST3 halves the cost of ruling; TREND2 centres the trend; neither touches the base.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _cell(w: WorldState) -> Dictionary:
	for c in PolVoters.all(w):
		if int(c.get("pop", 0)) > 0 and c.has("approval"):
			return c
	return {}


func test_rule_cost3_halves_the_wear() -> void:
	var w := WorldState.new()
	w.meta["on"] = []
	check_eq(PoliticsProvider._rule_cost(w), PolDefs.COST_OF_RULING_PER_YEAR, "base unchanged without the flag")
	w.meta["on"] = ["RULE_COST3"]
	check_eq(PoliticsProvider._rule_cost(w), PolDefs.COST_OF_RULING_V11, "half with the flag")


func test_vote_model_reads_the_rule_cost() -> void:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	sim.run(60)
	var w := sim.world
	var cell := _cell(w)
	check(not cell.is_empty(), "a voter cell")
	if cell.is_empty():
		return
	var p: Dictionary = PartyLife.active(w)[0]
	var base := {"gov_share": {}, "prev_share": {}, "shock": {}, "tenure": {p["id"]: 48}}
	var half := base.duplicate()
	half["rule_cost"] = PolDefs.COST_OF_RULING_V11
	var d := VoteModel.utility(cell, p, half) - VoteModel.utility(cell, p, base)
	check(absf(d - 4.0 * (PolDefs.COST_OF_RULING_PER_YEAR - PolDefs.COST_OF_RULING_V11)) < 1e-6, "four years in office cost half as much (%f)" % d)


func test_trend2_changes_the_run_and_the_base_stays() -> void:
	var a: Simulation = EconSim.make(5, "BALANCED", {}, true)
	var b: Simulation = EconSim.make(5, "BALANCED", {}, true)
	(b.world.meta["on"] as Array).append("TREND2")
	a.run(60)
	b.run(60)
	check(a.world.state_hash() != b.world.state_hash(), "TREND2 changes the run")
	var c: Simulation = EconSim.make(5, "BALANCED", {}, true)
	c.run(60)
	check_eq(c.world.state_hash(), a.world.state_hash(), "without the flags the run is the same as before")
