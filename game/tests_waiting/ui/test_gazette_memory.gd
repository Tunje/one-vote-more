extends TestCase
## The paper's memory (the user, 2026-11-16): the same story must not lead month after month with only its number
## changed. Fresh news goes first; a running story follows with how long it has run; it is fresh again on its anniversary.

const Gazette := preload("res://ui/panels/gazette_panel.gd")


func _late(w: WorldState, months_late: int) -> void:
	w.add_fact({"type": "ECON_CONTRACT_SEVERELY_DELAYED", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 60,
		"visibility": "PUBLIC", "data": {"project": "project:7", "months_late": months_late}})


func _world() -> WorldState:
	var sim := EconSim.make_econ_only(3)
	sim.run(1)
	return sim.world


func test_same_kind_and_subject_is_the_same_story() -> void:
	var a := {"type": "ECON_CONTRACT_SEVERELY_DELAYED", "data": {"project": "project:7", "months_late": 31}}
	var b := {"type": "ECON_CONTRACT_SEVERELY_DELAYED", "data": {"project": "project:7", "months_late": 32}}
	var c := {"type": "ECON_CONTRACT_SEVERELY_DELAYED", "data": {"project": "project:9", "months_late": 32}}
	check_eq(Gazette.story_key(a), Gazette.story_key(b), "one more month late is the same story")
	check(Gazette.story_key(a) != Gazette.story_key(c), "another project is another story")


func test_a_running_story_does_not_lead_again() -> void:
	var w := _world()
	var m0 := w.month
	for i in 5:
		w.month = m0 + i
		_late(w, 28 + i)
	var month := m0 + 4
	var key := Gazette.story_key({"type": "ECON_CONTRACT_SEVERELY_DELAYED", "data": {"project": "project:7"}})
	check_eq(Gazette.months_running(w, key, month, {}), 4, "it has been in the news the four months before")
	check_eq(Gazette.months_running(w, key, m0, {}), 0, "in its first month it is fresh")
	var late := {"head": "NEW HOUSING IS 32 MONTHS LATE", "sub": "It is late.", "body": "", "score": 90, "key": key}
	var fresh := {"head": "A SHIP ARRIVES", "sub": "A ship.", "body": "", "score": 40, "key": "ECON_SHIP_ARRIVED"}
	var out: Array = Gazette._fresh_first(w, [late.duplicate(), fresh.duplicate()], month)
	check_eq(String(out[0]["head"]), "A SHIP ARRIVES", "fresh news leads although the old story scores higher")
	check(String(out[1]["sub"]).begins_with("Month 5 of this story"), "the running story says how long it has run (%s)" % String(out[1]["sub"]))
	var alone: Array = Gazette._fresh_first(w, [late.duplicate()], month)
	check_eq(String(alone[0]["head"]), "NO FRESH NEWS THIS MONTH", "with nothing fresh the front page says so")
	check_eq(String(alone[1]["head"]), "NEW HOUSING IS 32 MONTHS LATE", "and the running story stands below it")


func test_a_paper_returns_to_a_story_on_its_anniversary() -> void:
	var w := _world()
	var m0 := w.month
	for i in 13:
		w.month = m0 + i
		_late(w, 20 + i)
	var key := Gazette.story_key({"type": "ECON_CONTRACT_SEVERELY_DELAYED", "data": {"project": "project:7"}})
	var st := {"head": "NEW HOUSING IS 32 MONTHS LATE", "sub": "It is late.", "body": "", "score": 90, "key": key}
	var out: Array = Gazette._fresh_first(w, [st], m0 + 12)
	check_eq(String(out[0]["head"]), "NEW HOUSING IS 32 MONTHS LATE", "a year on it may lead again")
	check(String(out[0]["sub"]).begins_with("1 year on"), "and says so (%s)" % String(out[0]["sub"]))
