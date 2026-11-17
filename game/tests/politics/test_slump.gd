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
	w.meta["test_unemployment"] = pct
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
		check(float(c["to"]) > 3000.0, "an ordinary government does not cut at 40%% (strong pressure, not a ban): %s" % str(c))
	var g: Dictionary = w.table("pol")["state"]["government"]
	var cs := PoliticsProvider.new().colony_concerns(w)
	var ex := {}
	for lid in w.lever_defs:
		if not (lid in Legislature.COUNTER_CYCLICAL):
			ex[lid] = true
	for c in Legislature.propose(w, g["center"], cs[0], cs[1], g.get("agreement", []), "PARLIAMENT", 0.0, false, ex):
		check(float(c["to"]) > 3000.0, "even alone on the agenda, only raises: %s" % str(c))


func test_hunger_protects_food_assistance_and_the_benefit_floor() -> void:
	var w := _world()
	for lid in Legislature.HUNGER_LEVERS:
		w.levers[lid] = 50
	_set_unemp(w, 5)
	CoreUtil.econ_state(w)["sovereign_default"] = false   # v9: seed 5 can be in default at m66, where only food aid keeps a case
	CoreUtil.econ_state(w)["food_shortfall"] = 300   # 30% of household food need unmet
	check(absf(Legislature.hunger(w) - 0.3) < 0.001, "reads the shortfall")
	check(Legislature.protected_levers(w).has("ECON_FOOD_ASSISTANCE"), "food assistance is protected")
	var g: Dictionary = w.table("pol")["state"]["government"]
	var cs := PoliticsProvider.new().colony_concerns(w)
	var ex := {}
	for lid in w.lever_defs:
		if not (lid in Legislature.HUNGER_LEVERS):
			ex[lid] = true
	for c in Legislature.propose(w, g["center"], cs[0], cs[1], g.get("agreement", []), "PARLIAMENT", 0.0, false, ex):
		check(float(c["to"]) > 50.0, "no cuts to food help while people go hungry: %s" % str(c))
	CoreUtil.econ_state(w)["food_shortfall"] = 0
	check(not Legislature.protected_levers(w).has("ECON_FOOD_ASSISTANCE"), "no protection without hunger")


## v10 (seed 3): cash aid is no remedy when the food is not there. With a fifth of food orders unfilled the food
## assistance lever loses its protection (more aid only bids the price up); the benefit floor keeps its own.
func test_food_aid_is_not_protected_when_food_is_scarce() -> void:
	var w := _world()
	_set_unemp(w, 5)
	var s := CoreUtil.econ_state(w)
	s["sovereign_default"] = false
	s["food_shortfall"] = 300
	if not s.has("market_stats"):
		s["market_stats"] = {}
	s["market_stats"]["FOOD"] = {"wanted": 1000000, "filled": 1000000, "D": 1000000, "S": 1000000}
	check(Legislature.protected_levers(w).has("ECON_FOOD_ASSISTANCE"), "hunger with every order filled: people can't afford it, aid is protected")
	s["market_stats"]["FOOD"]["filled"] = 900000
	var half: Dictionary = Legislature.protected_levers(w)
	check(half.has("ECON_FOOD_ASSISTANCE") and not bool(half["ECON_FOOD_ASSISTANCE"][1]), "10% unfilled: weaker, and no longer a hard protection")
	s["market_stats"]["FOOD"]["filled"] = 800000
	var out: Dictionary = Legislature.protected_levers(w)
	check(not out.has("ECON_FOOD_ASSISTANCE"), "20% unfilled: the food isn't there, aid is not protected")
	check(out.has("ECON_BENEFIT_FLOOR"), "the benefit floor keeps its hunger protection")

