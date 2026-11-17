extends TestCase
## Grant programmes (user 2026-11-15) after rebuild step 2: which programme is open and which districts it covers is
## politics' own memory, kept in the politics state, not in the economy's. The economy publishes the need
## (EconFace.grant_need) and reads the choice (GovBuilder.grant_cover). Every decision writes a Logbook row.
## (Rewritten from tests_waiting/politics/test_grant_cover.gd, which needs the old economy.)

const DS := ["d:1", "d:2", "d:3"]


func _world() -> WorldState:
	var sim := GameSim.make(4)
	sim.run(2)
	return sim.world


## The economy's grant need, as Grants.monthly publishes it (rebuild step 3).
func _need(w: WorldState, farm: Dictionary) -> void:
	var t := w.table("grant_prog")
	if not t.has("s"):
		t["s"] = {"progs": {}, "need": {}, "seen": {}}
	t["s"]["need"] = {"FARM": farm, "BAKERY": {}}


## No governing parties: the cover is chosen by need alone.
func _by_need(st: Dictionary) -> void:
	if st.has("government"):
		st["government"]["members"] = []


func test_the_memory_is_politics_own() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	_by_need(st)
	_need(w, {"d:1": 900, "d:2": 500, "d:3": 0})
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	check(st.has("grant_prog") and (st["grant_prog"] as Dictionary).has("FARM"), "the open programme is in the politics state")
	check(st.has("grant_cover") and (st["grant_cover"] as Dictionary).has("FARM"), "and its cover")
	var econ := CoreUtil.peek_st(w)
	check(not econ.has("grant_prog") and not econ.has("grant_cover"), "nothing of it in the economy's state")
	var c := GovBuilder.grant_cover(w)
	check("d:1" in c["FARM"], "the economy reads the choice")
	(c["FARM"] as Array).clear()
	check(not (GovBuilder.grant_cover(w)["FARM"] as Array).is_empty(), "and cannot change it through what it read")


func test_coverage_follows_need_and_is_dropped_when_the_programme_ends() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	_by_need(st)
	var need := {"d:1": 900, "d:2": 500, "d:3": 0}
	_need(w, need)
	var before := w.facts.query("POL_GRANT_COVERAGE").size()
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	var cover: Array = GovBuilder.grant_cover(w).get("FARM", [])
	check("d:1" in cover, "the neediest district is covered (%s)" % str(cover))
	for d in cover:
		check(int(need[d]) > 0, "no district without need is covered (%s)" % d)
	check_eq(w.facts.query("POL_GRANT_COVERAGE").size(), before + 1, "the coverage is announced")
	check(not GovBuilder.grant_cover(w).has("BAKERY"), "no bakery programme, no bakery coverage")
	GovBuilder._grant_cover(w, st)
	check_eq(w.facts.query("POL_GRANT_COVERAGE").size(), before + 1, "an open programme keeps its districts")
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	GovBuilder._grant_cover(w, st)
	check(not GovBuilder.grant_cover(w).has("FARM"), "the next programme starts over")


func test_every_decision_is_in_the_logbook() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	_by_need(st)
	_need(w, {"d:1": 900, "d:2": 500, "d:3": 0})
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	GovBuilder._grant_cover(w, st)
	# politics' decision is the cover; the programme's opening and end are the grants' deeds (Grants logs them)
	var rows := Logbook.rows(w, {"kind": "GRANT", "ref": "ECON_FAMILY_FARM_GRANT"})
	var whats: Array = rows.map(func(r): return String(r["what"]))
	check_eq(whats, ["cover chosen"], "the cover chosen, once")
	if rows.size() == 1:
		check(not (rows[0]["change"]["cover"][1] as Array).is_empty(), "the chosen districts are on the row")


func test_no_need_published_nothing_happens() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	var h := w.state_hash()
	GovBuilder._grant_cover(w, st)
	check(not st.has("grant_prog"), "no programme is counted while the economy publishes no need")
	check_eq(Logbook.rows(w, {"kind": "GRANT"}).size(), 0, "and nothing is logged")
	check_eq(w.state_hash(), h, "nothing changes")


func test_the_decision_desk_route_writes_politics_state() -> void:
	var w := _world()
	w.levers["ECON_FAMILY_FARM_GRANT"] = 30
	var r := GovBuilder.commit_cover(w, {"kind": "FARM", "districts": ["d:2"], "fair": ["d:1"], "by": "commander"})
	check(bool(r["ok"]), "committed")
	check_eq(GovBuilder.grant_cover(w)["FARM"], ["d:2"], "the programme covers the chosen district")
	check(not CoreUtil.peek_st(w).has("grant_cover"), "not in the economy's state")
	check_eq(w.facts.query("POL_GRANT_FAVOURITISM").size(), 1, "passing over the fairer choice is a public fact")
	check_eq(Logbook.rows(w, {"kind": "GRANT", "what": "cover chosen"}).size(), 1, "logged")


func test_a_programme_without_takers_is_a_public_failure() -> void:
	var w := _world()
	var st: Dictionary = w.table("pol")["state"]
	_need(w, {"d:1": 800, "d:2": 0, "d:3": 0})
	w.levers["ECON_FAMILY_FARM_GRANT"] = 10
	for i in 8:
		GovBuilder._grant_cover(w, st)   # eight months open, food needed throughout
		w.month += 1
	check_eq(w.facts.query("POL_GRANT_PROGRAMME_FAILED").size(), 0, "no verdict while the programme runs")
	w.levers["ECON_FAMILY_FARM_GRANT"] = 0
	w.add_fact({"type": "ECON_GRANT_PROGRAMME_ENDED", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 20,
		"visibility": "PUBLIC", "data": {"lever": "ECON_FAMILY_FARM_GRANT", "level": 10, "paid": 0, "refused": 0}})
	GovBuilder._grant_cover(w, st)
	var failed: Array = w.facts.query("POL_GRANT_PROGRAMME_FAILED")
	check_eq(failed.size(), 1, "an empty programme is a public failure")
	if failed.size() == 1:
		check(bool(failed[0]["data"]["needed"]), "the colony needed it")


func test_the_memory_survives_save_and_load() -> void:
	var sim := GameSim.make(4)
	sim.run(2)
	var w := sim.world
	var st: Dictionary = w.table("pol")["state"]
	_by_need(st)
	_need(w, {"d:1": 900, "d:2": 500, "d:3": 0})
	w.levers["ECON_FAMILY_FARM_GRANT"] = 50
	GovBuilder._grant_cover(w, st)
	var path := save_path("grant_memory.sav")
	check_eq(SaveIO.save(sim, path), OK, "save")
	var l := GameSim.for_load()
	check_eq(SaveIO.load_into(l, path), OK, "load")
	check_eq(GovBuilder.grant_cover(l.world), GovBuilder.grant_cover(w), "the cover is kept")
	check_eq((l.world.table("pol")["state"] as Dictionary).get("grant_prog", {}), st["grant_prog"], "and the open programme")
