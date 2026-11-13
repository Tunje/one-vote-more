extends TestCase
## v7 review: in a slump (unemployment 15%+) governments fund public works and public jobs, past the fiscal guard
## from 20%, and do not cut them.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(5, "BALANCED", {}, true)
	sim.run(66)
	return sim.world


func _propose(w: WorldState) -> Array:
	var g: Dictionary = w.table("pol")["state"]["government"]
	var cs := PoliticsProvider.new().colony_concerns(w)
	return Legislature.propose(w, g["center"], cs[0], cs[1], g.get("agreement", []), "PARLIAMENT")


func _set_unemp(w: WorldState, pct: int) -> void:
	var v: Dictionary = w.indicators.values["ECON_UNEMPLOYMENT_RATE"]
	for k in v.keys():
		v[k] = pct * 1000


func _jobs_moves(clauses: Array) -> Array:
	var out: Array = []
	for c in clauses:
		if String(c.get("lever", "")) in Legislature.COUNTER_CYCLICAL:
			out.append(c)
	return out


func test_slump_reads_the_rate() -> void:
	var w := _world()
	_set_unemp(w, 35)
	check(absf(Legislature.unemployment(w) - 35.0) < 0.01, "reads the colony rate in percent")
	check(absf(Legislature._slump(w) - 2.0) < 0.01, "35% is a full slump")
	_set_unemp(w, 10)
	check_eq(Legislature._slump(w), 0.0, "10% is no slump")


func test_no_cuts_to_the_jobs_schemes_in_a_deep_slump() -> void:
	var w := _world()
	for lid in Legislature.COUNTER_CYCLICAL:
		w.levers[lid] = 3000
	_set_unemp(w, 40)
	for c in _jobs_moves(_propose(w)):
		check(float(c["to"]) > 3000.0, "never cut at 40%%: %s" % str(c))
	var g: Dictionary = w.table("pol")["state"]["government"]
	var cs := PoliticsProvider.new().colony_concerns(w)
	var ex := {}
	for lid in w.lever_defs:
		if not (lid in Legislature.COUNTER_CYCLICAL):
			ex[lid] = true
	for c in Legislature.propose(w, g["center"], cs[0], cs[1], g.get("agreement", []), "PARLIAMENT", 0.0, false, ex):
		check(float(c["to"]) > 3000.0, "even alone on the agenda, only raises: %s" % str(c))
