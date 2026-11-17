extends TestCase
## Family grant programmes (user 2026-11-15): the government names the districts a programme covers, by need, leaning
## toward its own voters; favouring its strongholds over needier districts is a public, resented fact; the coverage is
## dropped when the programme ends.

const EconSim := preload("res://sim/economy/econ_sim.gd")


func _world() -> WorldState:
	var sim: Simulation = EconSim.make(4, "BALANCED", {}, true)
	for f in ["E160", "E162"]:      # on by default since v11: these tests open their own programme
		(sim.world.meta["on"] as Array).erase(f)
	sim.run(60)
	return sim.world


func test_coverage_follows_need_and_is_dropped_when_the_programme_ends() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var s := EconUtil.st(w)
	var ds: Array = EconUtil.sorted_keys(w.table("district"))
	check(ds.size() >= 3, "three districts")
	var need := {}
	for i in ds.size():
		need[ds[i]] = 0
	need[ds[0]] = 900
	need[ds[1]] = 500
	s["family_need_d"] = {"FARM": need, "BAKERY": {}}
	st["government"]["members"] = []   # no governing parties: choice by need alone
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	var cover: Array = s["grant_cover"].get("FARM", [])
	check(ds[0] in cover, "the neediest district is covered (%s)" % str(cover))
	for d in cover:
		check(int(need[d]) > 0, "no district without need is covered (%s)" % d)
	check_eq(w.facts.query("POL_GRANT_COVERAGE").size(), 1, "the coverage is announced")
	check(not s["grant_cover"].has("BAKERY"), "no bakery programme, no bakery coverage")
	GovBuilder._grant_cover(w, st)
	check_eq(w.facts.query("POL_GRANT_COVERAGE").size(), 1, "an open programme keeps its districts")
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	GovBuilder._grant_cover(w, st)
	check(not s["grant_cover"].has("FARM"), "the next programme starts over")


func test_favouring_strongholds_is_a_resented_public_fact() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var s := EconUtil.st(w)
	var ds: Array = EconUtil.sorted_keys(w.table("district"))
	var g: Dictionary = st["government"]
	check(not (g.get("members", []) as Array).is_empty(), "an elected government at month 60")
	# need is almost equal everywhere; the governing parties' voters all live in the last populated district
	var peopled := {}
	for c in PolVoters.all(w):
		if int(c.get("pop", 0)) > 0:
			peopled[String(c.get("district", ""))] = true
	ds = ds.filter(func(d): return peopled.has(String(d)))
	check(ds.size() >= 2, "two populated districts")
	var need := {}
	for i in ds.size():
		need[ds[i]] = 1000 - i
	s["family_need_d"] = {"FARM": need, "BAKERY": {}}
	for c in PolVoters.all(w):
		for pid in g["members"]:
			c["prev_share"][pid] = 90000 if String(c.get("district", "")) == String(ds[ds.size() - 1]) else 0
	g["center"]["REDISTRIBUTION"] = -50000   # an austere government: one district only
	g["center"]["FISCAL"] = -50000
	g["center"]["INSTITUTIONS"] = -80000
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	var cover: Array = s["grant_cover"].get("FARM", [])
	check_eq(cover, [ds[ds.size() - 1]], "the government's stronghold gets the programme")
	var fav: Array = w.facts.query("POL_GRANT_FAVOURITISM")
	check_eq(fav.size(), 1, "favouritism is recorded")
	if fav.size() == 1:
		check(int(fav[0]["impact"].get("FAIRNESS", 0)) < 0, "and resented")
		check(ds[0] in fav[0]["data"]["passed_over"], "the neediest district was passed over")


## A programme nobody takes up costs the government that opened it: more when the colony needed it.
func test_a_programme_without_takers_is_a_public_failure() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	var s := EconUtil.st(w)
	var ds: Array = EconUtil.sorted_keys(w.table("district"))
	var need := {}
	for d in ds:
		need[d] = 0
	need[ds[0]] = 800
	s["family_need_d"] = {"FARM": need, "BAKERY": {}}
	w.levers["ECON_FAMILY_FARM_GRANT"] = 10
	for i in 8:
		GovBuilder._grant_cover(w, st)   # eight months open, food needed throughout
		w.month += 1
	check_eq(w.facts.query("POL_GRANT_PROGRAMME_FAILED").size(), 0, "no verdict while the programme runs")
	# the programme ends with nothing paid
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	w.add_fact({"type": "ECON_GRANT_PROGRAMME_ENDED", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 20,
		"visibility": "PUBLIC", "data": {"lever": "ECON_FAMILY_FARM_GRANT", "level": 10, "paid": 0, "refused": 0}})
	GovBuilder._grant_cover(w, st)
	var failed: Array = w.facts.query("POL_GRANT_PROGRAMME_FAILED")
	check_eq(failed.size(), 1, "an empty programme is a public failure")
	if failed.size() == 1:
		check(bool(failed[0]["data"]["needed"]), "the colony needed it")
		check(int(failed[0]["impact"].get("GOVERNANCE", 0)) < 0, "and it costs trust")
	# a programme that paid grants is no failure
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	w.month += 2
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	w.add_fact({"type": "ECON_GRANT_PROGRAMME_ENDED", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 20,
		"visibility": "PUBLIC", "data": {"lever": "ECON_FAMILY_FARM_GRANT", "level": 50, "paid": 5, "refused": 1}})
	GovBuilder._grant_cover(w, st)
	check_eq(w.facts.query("POL_GRANT_PROGRAMME_FAILED").size(), 1, "a programme that paid grants is not a failure")
