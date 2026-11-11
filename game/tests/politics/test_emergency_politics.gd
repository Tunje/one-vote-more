extends TestCase
## M11 politics side of states of emergency (spec-events-v1 §4).

const EconSim := preload("res://sim/economy/econ_sim.gd")
const LQ := preload("res://sim/law/law_query.gd")


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(2, "BALANCED", {}, true)
	sim.run(60)
	return sim.world


func _drought(w: WorldState, mag: int) -> void:
	w.add_fact({"type": "ECON_DROUGHT", "owner": "econ", "subjects": [], "responsible": [], "impact": {"COST_OF_LIVING": -20},
		"magnitude": mag, "visibility": "PUBLIC", "data": {"crisis": true, "crisis_type": "DROUGHT"}})


func test_kind_mapping() -> void:
	check_eq(EmergencyPolitics.kind_of("ECON_FAMINE"), "FOOD", "famine is food")
	check_eq(EmergencyPolitics.kind_of("ECON_EPIDEMIC"), "HEALTH", "epidemic is health")
	check_eq(EmergencyPolitics.kind_of("ECON_PLANT_BREAKDOWN POWER"), "POWER", "breakdown is power")
	check_eq(EmergencyPolitics.kind_of("ECON_MINE_COLLAPSE"), "GENERAL", "other")


func test_no_crisis_no_emergency() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	EmergencyPolitics.monthly(w, st)
	check(not LQ.emergency(w)["active"], "nothing declared in calm times")


func test_serious_crisis_declared_voted_and_used() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	check(not st.get("government", {}).is_empty(), "a government exists")
	_drought(w, 95)
	EmergencyPolitics.monthly(w, st)
	var e: Dictionary = LQ.emergency(w)
	check(e["active"], "a severe drought leads to an emergency")
	check_eq(e.get("kind", ""), "FOOD", "food emergency")
	check_eq(w.facts.query("POL_EMERGENCY_VOTE").size(), 1, "parliament voted")
	if LQ.emergency(w).get("approved", false):
		EmergencyPolitics.monthly(w, st)
		var queued := 0
		for en in w.table("enactment").values():
			if en["lever"] in ["LAW_FOOD_EXPORT_BAN", "LAW_PRICE_CONTROL"]:
				queued += 1
		check(queued >= 1, "food measures enacted (%d)" % queued)
	# the crisis counts as active for 2 months, then 3 calm months: the government ends it
	for _i in 6:
		w.month += 1
		EmergencyPolitics.monthly(w, st)
	check(not LQ.emergency(w)["active"], "ended (or lapsed) once the crisis is over")


func test_minor_crisis_does_not_trigger() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	_drought(w, 41)
	EmergencyPolitics.monthly(w, st)
	check(not LQ.emergency(w)["active"], "a minor crisis is handled without emergency powers")
