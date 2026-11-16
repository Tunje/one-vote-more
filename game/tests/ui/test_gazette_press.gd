extends TestCase
## The written articles (the user, 2026-11-16): the paper prints an article from res://data/press where one is written
## and its blanks can be filled, and its own headline and sentence where not. The front page is laid out one of four
## ways, the same for the same paper and month.

const Gazette := preload("res://ui/panels/gazette_panel.gd")
const Press := preload("res://ui/press_library.gd")

const DIR := "user://press_test"
const TABLOID := {"id": "outlet:t", "name": "The Daily Shout", "owner": {"kind": "COMPANY", "id": "org:1"}, "sens": 800}


func _world() -> WorldState:
	var sim := EconSim.make_econ_only(3)
	sim.run(1)
	return sim.world


func _write(name: String, variants: Array) -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/articles")
	var f := FileAccess.open("%s/articles/%s" % [DIR, name], FileAccess.WRITE)
	f.store_string(JSON.stringify({"variants": variants}))
	f.close()


func _scratch() -> void:
	Press.dir = DIR
	Press._files.clear()
	Press._pics.clear()


func _real() -> void:
	Press.dir = "res://data/press"
	Press._files.clear()
	Press._pics.clear()


func test_the_voice_follows_the_owner() -> void:
	check_eq(Press.flavour({"owner": {"kind": "STATE"}}), "STATE", "the public paper")
	check_eq(Press.flavour({"owner": {"kind": "UNION"}}), "UNION", "a union's paper")
	check_eq(Press.flavour(TABLOID), "TABLOID", "a loud company paper is a tabloid")
	check_eq(Press.flavour({"owner": {"kind": "COMPANY"}, "sens": 300}), "BUSINESS", "a quiet one is a business paper")


func test_stance_follows_the_frame() -> void:
	check_eq(Press.stance("GOVERNMENT", 0.0, -1), "AGAINST", "blaming someone is against them")
	check_eq(Press.stance("NEUTRAL", 0.6, -1), "AGAINST", "bad news played up")
	check_eq(Press.stance("NEUTRAL", -0.6, -1), "FOR", "bad news played down")
	check_eq(Press.stance("NEUTRAL", 0.6, 1), "FOR", "good news played up")
	check_eq(Press.stance("NEUTRAL", 0.05, -1), "NEUTRAL", "told straight")


func test_a_blank_the_game_cannot_fill_is_not_printed() -> void:
	_scratch()
	check_eq(Press.fill("Hunger in {colony}", {"colony": "Landing"}), "Hunger in Landing", "a known blank is filled")
	check_eq(Press.fill("Blame {nobody}", {"colony": "Landing"}), "", "an unknown blank rejects the text")
	_write("X__STATE__NEUTRAL__LEAD.json", [{"headline": "A {mystery}", "sub": "", "body": "One."}, {"headline": "B in {colony}", "sub": "", "body": "Two."}])
	var a: Dictionary = Press.article("X", "STATE", "NEUTRAL", "LEAD", {"colony": "Landing"}, 0)
	check_eq(String(a.get("headline", "")), "B in Landing", "the variant that can be filled is the one used")
	check(Press.article("X", "STATE", "AGAINST", "LEAD", {"colony": "Landing"}, 0).size() > 0, "a stance not written falls back to the straight report")
	check(Press.article("Y", "STATE", "NEUTRAL", "LEAD", {}, 0).is_empty(), "nothing written, nothing returned")
	_real()


func test_the_paper_prints_the_written_article_and_keeps_its_own_for_the_rest() -> void:
	_scratch()
	var w := _world()
	_write("ECON_FAMINE__TABLOID__NEUTRAL__LEAD.json", [{"headline": "Hungry in {colony}", "sub": "What does {target} say?", "body": "{paper}, {month} of {year}."}])
	var famine := {"id": "fact:1", "type": "ECON_FAMINE", "data": {}, "responsible": [], "impact": {}, "magnitude": 90}
	var other := {"id": "fact:2", "type": "ECON_SHIP_ARRIVED", "data": {"migrants": 40}, "responsible": [], "impact": {}, "magnitude": 40}
	var stories: Array = [
		{"head": "FAMINE", "sub": "People are hungry.", "body": "", "score": 90, "key": "ECON_FAMINE", "fact": famine, "run": 0},
		{"head": "A SHIP ARRIVES", "sub": "A ship has come.", "body": "", "score": 40, "key": "ECON_SHIP_ARRIVED", "fact": other, "run": 0}]
	var out: Array = Gazette.write_up(w, stories, TABLOID, 14)
	check(String(out[0]["head"]).begins_with("HUNGRY IN "), "the written headline leads (%s)" % String(out[0]["head"]))
	check_eq(String(out[0]["sub"]), "What does the government say?", "with nobody else responsible the target is the government")
	check_eq(String(out[0]["body"]), "The Daily Shout, March of Year 2.", "paper, month and year are filled in")
	check_eq(String(out[1]["head"]), "A SHIP ARRIVES", "an event with no article keeps the paper's own headline")
	check(not out[1].get("written", false), "and is not marked as written")
	_real()


func test_a_running_story_takes_the_followup_and_says_when_it_began() -> void:
	_scratch()
	var w := _world()
	_write("ECON_FAMINE__TABLOID__NEUTRAL__LEAD.json", [{"headline": "First news", "sub": "", "body": "First."}])
	_write("ECON_FAMINE__TABLOID__NEUTRAL__FOLLOWUP.json", [{"headline": "Still hungry", "sub": "", "body": "Month {months_running}, since {first_reported}."}])
	var famine := {"id": "fact:1", "type": "ECON_FAMINE", "data": {}, "responsible": [], "impact": {}, "magnitude": 90}
	var out: Array = Gazette.write_up(w, [{"head": "FAMINE", "sub": "s", "body": "", "score": 90, "key": "ECON_FAMINE", "fact": famine, "run": 3}], TABLOID, 14)
	check_eq(String(out[0]["head"]), "STILL HUNGRY", "a story already running does not read like first news")
	check_eq(String(out[0]["body"]), "Month 4, since December of Year 1.", "it says how long and since when")
	_real()


func test_the_layout_is_fixed_for_a_paper_and_month_and_varies_between_them() -> void:
	check_eq(Gazette.layout_of("outlet:1", 30), Gazette.layout_of("outlet:1", 30), "the same edition is laid out the same way")
	var seen := {}
	for m in 48:
		var l: Dictionary = Gazette.layout_of("outlet:1", m)
		check(int(l["layout"]) >= 0 and int(l["layout"]) <= 3 and int(l["cols"]) >= 2 and int(l["cols"]) <= 4, "a layout the page knows")
		seen[int(l["layout"])] = true
	check_eq(seen.size(), 4, "over four years a paper uses all four layouts")


func test_the_real_folder_loads() -> void:
	_real()
	var w := _world()
	var bl: Dictionary = Press.blanks(w, {"type": "ECON_FAMINE", "data": {}, "responsible": []}, TABLOID, 14, 0)
	var a: Dictionary = Press.article("ECON_FAMINE", "TABLOID", "AGAINST", "LEAD", bl, 0)
	check(not a.is_empty(), "the famine article that has been written is found and filled")
	check(not String(a.get("body", "")).contains("{"), "no blank is left in it")
