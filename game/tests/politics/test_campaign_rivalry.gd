extends TestCase
## Campaigns aim by rivalry (RIVALRY; user 2026-11-15): targets, grudges from dirt, questioned decisions.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world(rivalry: bool) -> WorldState:
	var sim: Simulation = EconSim.make(3, "BALANCED", {}, true)
	(sim.world.meta["on"] as Array).erase("RIVALRY")   # on by default since v11: these tests switch it themselves
	sim.run(72)
	if rivalry:
		(sim.world.meta["on"] as Array).append("RIVALRY")
	return sim.world


func _opposition(w: WorldState) -> Array:
	var st: Dictionary = w.table("pol")["state"]
	var out: Array = []
	for p in PartyLife.active(w):
		if not (p["id"] in st["government"]["members"]):
			out.append(p)
	return out


func test_without_the_flag_the_opposition_aims_at_the_first_minister() -> void:
	var w := _world(false)
	var st: Dictionary = w.table("pol")["state"]
	var pm := String(st["government"]["pm_party"])
	for p in _opposition(w):
		var t := Campaign.pick_target(w, st, p)
		check(t == pm or Campaign._target_heat(w).has(t), "%s aims at the First Minister or a scandal (%s)" % [p["id"], t])


func test_rivals_draw_fire_even_out_of_government() -> void:
	var w := _world(true)
	var st: Dictionary = w.table("pol")["state"]
	var pm := String(st["government"]["pm_party"])
	var opp := _opposition(w)
	check(opp.size() >= 2, "an opposition to speak of")
	if opp.size() < 2:
		return
	var a: Dictionary = opp[0]
	var b: Dictionary = opp[1]
	# make a and b bitter enemies of similar size, far apart
	for ax in PolDefs.AXES:
		a["positions"][ax] = 90000
		b["positions"][ax] = -90000
	b["support"] = maxi(maxi(int(b["support"]), int(a["support"])), 20000)
	st["grudge"] = {String(a["id"]) + ">" + String(b["id"]): 1000}
	check_eq(Campaign.pick_target(w, st, a), String(b["id"]), "the bitter rival, not the First Minister")
	# with no grudge and no distance the First Minister's party draws the fire again
	st["grudge"] = {}
	for ax in PolDefs.AXES:
		b["positions"][ax] = a["positions"][ax]
	b["support"] = 1000
	var t := Campaign.pick_target(w, st, a)
	check(t != String(b["id"]), "a tiny like-minded party is not the target (%s)" % t)
	check(t != "", "someone is (%s, First Minister %s)" % [t, pm])


func test_dirt_breeds_a_grudge() -> void:
	var w := _world(true)
	var opp := _opposition(w)
	var st: Dictionary = w.table("pol")["state"]
	var pm := String(st["government"]["pm_party"])
	var a := String(opp[0]["id"])
	var g0 := Rivalry.grudge(w, pm, a)
	Rivalry.on_attack(w, a, pm, 1.0)
	check_eq(Rivalry.grudge(w, pm, a) - g0, Rivalry.G_ATTACKED, "the target remembers who threw the dirt")
	var w2 := _world(false)
	var h := w2.state_hash()
	Rivalry.on_attack(w2, a, pm, 1.0)
	check_eq(w2.state_hash(), h, "nothing without the flag")


func test_questioning_a_bad_decision_pays_and_carping_does_not() -> void:
	var w := _world(true)
	var st: Dictionary = w.table("pol")["state"]
	var pm := String(st["government"]["pm_party"])
	var a := String(_opposition(w)[0]["id"])
	var c := {"parties": {a: {"momentum": 0}, pm: {"momentum": 0}}}
	w.add_fact({"type": "POL_DECISION_QUESTIONED", "owner": "pol", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 50, "visibility": "PUBLIC", "data": {"by": a, "against": pm, "about": "POL_GRANT_FAVOURITISM", "district": ""}})
	Campaign._questioned(w, c)
	check_eq(int(c["parties"][a]["momentum"]), Campaign.QUESTION_LINE, "the questioner gains")
	check_eq(int(c["parties"][pm]["momentum"]), Campaign.QUESTION_HIT, "the government pays a little")
	var c2 := {"parties": {a: {"momentum": 0}, pm: {"momentum": 0}}}
	w.month += 1
	w.add_fact({"type": "POL_DECISION_QUESTIONED", "owner": "pol", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 30, "visibility": "PUBLIC", "data": {"by": a, "against": pm, "about": "POL_PROJECT_ORDERED", "district": ""}})
	Campaign._questioned(w, c2)
	check_eq(int(c2["parties"][a]["momentum"]), Campaign.QUESTION_CARP, "carping at an ordinary decision costs a little")
	check_eq(int(c2["parties"][pm]["momentum"]), 0, "and costs the government nothing")
