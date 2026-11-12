extends TestCase
## T7 traffic engineering, staff side (planning/spec-transport-v1.md T7): yearly study, report quality from the
## team, the wrong fix from weak teams, late studies, and the ignored-report scandal.

const F := preload("res://tests/support/staff_fixture.gd")
const TR := preload("res://sim/staff/traffic_reports.gd")

const WREF := 1200000


func _stats() -> Dictionary:
	return {
		"NODE:j1": {"kind": "NODE", "id": "j1", "name": "Market Cross", "load_pm": 950, "accidents_12m": 6, "serious_12m": 2, "fatal_12m": 0},
		"LINK:l1": {"kind": "LINK", "id": "l1", "name": "Mine Road", "load_pm": 1100, "accidents_12m": 1, "serious_12m": 0, "fatal_12m": 0},
		"LINK:l2": {"kind": "LINK", "id": "l2", "name": "Quiet Lane", "load_pm": 300, "accidents_12m": 0, "serious_12m": 0, "fatal_12m": 0},
	}


func _fixes() -> Dictionary:
	return {
		"NODE:j1": {"options": [
			{"fix": "ROUNDABOUT", "cost": 20 * WREF, "months": 4, "cap_pm": 1300, "acc_pm": 400},
			{"fix": "SIGNALS", "cost": 45 * WREF, "months": 5, "cap_pm": 1500, "acc_pm": 700}]},
		"LINK:l1": {"options": [
			{"fix": "LANES_2", "cost": 60 * WREF, "months": 8, "cap_pm": 2000, "acc_pm": 900},
			{"fix": "PAVE", "cost": 30 * WREF, "months": 5, "cap_pm": 1300, "acc_pm": 800}]},
	}


func test_right_fix_and_ranking() -> void:
	check_eq(TR.best_option(_stats()["NODE:j1"], _fixes()["NODE:j1"]["options"], WREF), 0, "a roundabout for a crash-prone junction")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var items := TR.build_items(_stats(), _fixes(), 100.0, rng, WREF)
	check_eq(items.size(), 2, "both problems found by a strong team; the quiet lane is no problem")
	for it in items:
		check(not it["wrong"] and it["fix"] == it["best_fix"], "strong team picks the right fix (%s)" % it["key"])
		check(it["est_cost"] > 0 and it["est_months"] > 0, "with cost and time")


func test_weak_teams_miss_and_misjudge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wrong := [0, 0]
	var found := [0, 0]
	for i in 300:
		for k in 2:
			var items := TR.build_items(_stats(), _fixes(), 95.0 if k == 0 else 10.0, rng, WREF)
			found[k] += items.size()
			for it in items:
				if it["wrong"]:
					wrong[k] += 1
	check(wrong[1] > 3 * maxi(1, wrong[0]), "weak teams recommend the wrong fix more often (%d vs %d)" % [wrong[1], wrong[0]])
	check(found[0] > found[1], "and find fewer problems (%d vs %d)" % [found[0], found[1]])


func test_yearly_study_becomes_a_report() -> void:
	var s := F.sim(5, true)
	var w := s.world
	w.values["ECON_W_REF"] = WREF
	w.table("traffic_stat").merge(_stats())
	w.table("traffic_fix").merge(_fixes())
	w.month = 11
	var done := false
	for i in 14:
		s.step()
		if not w.peek("traffic_report").is_empty():
			done = true
			break
	check(done, "the department delivers a report")
	var f := w.facts.query("STAFF_TRAFFIC_REPORT")
	check(f.size() == 1 and String(f[0]["visibility"]) == "OFFICIAL", "an official fact")
	var open := TR.open_items(w)
	check(not open.is_empty() and not open[0].has("wrong") and not open[0].has("best_fix"), "open items hide the truth")
	check(TR.order_item(w, open[0]["report"], open[0]["idx"])["ok"], "the government orders a fix")
	check(not TR.order_item(w, open[0]["report"], open[0]["idx"])["ok"], "once")


func test_unstaffed_study_is_late() -> void:
	var s := F.sim(6, false)
	var w := s.world
	w.table("traffic_stat").merge(_stats())
	w.month = 11
	for i in 8:
		s.step()
	check_eq(w.facts.query("STAFF_TRAFFIC_REPORT_LATE").size(), 1, "late, once")
	check(w.peek("traffic_report").is_empty(), "and no report")


func test_ignored_report_then_fatal_crash_is_a_scandal() -> void:
	var w := F.bare_world()
	w.month = 20
	var fid := w.add_fact({"type": "STAFF_TRAFFIC_REPORT", "owner": "staff", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 20, "visibility": "OFFICIAL", "data": {}})
	var rng := RandomNumberGenerator.new()
	w.table("traffic_report")["treport:1"] = {"id": "treport:1", "month": 20, "kind": "YEARLY", "cause_fact": "", "task": "",
		"quality": 80, "fact": fid, "items": TR.build_items(_stats(), _fixes(), 100.0, rng, WREF)}
	var idx := -1
	for i in w.table("traffic_report")["treport:1"]["items"].size():
		if w.table("traffic_report")["treport:1"]["items"][i]["key"] == "NODE:j1":
			idx = i
	TR.decline_item(w, "treport:1", idx)
	w.month = 22
	w.add_fact({"type": "ECON_TRAFFIC_ACCIDENT", "owner": "econ", "subjects": [], "responsible": [], "impact": {"SAFETY": -3},
		"magnitude": 50, "visibility": "PUBLIC", "data": {"target": "NODE:j1", "serious": true, "fatal": 2}})
	TR.monthly(w)
	check(w.facts.query("STAFF_REPORT_IGNORED").is_empty(), "within the grace period: no scandal")
	w.month = 25
	var acc := w.add_fact({"type": "ECON_TRAFFIC_ACCIDENT", "owner": "econ", "subjects": [], "responsible": [], "impact": {"SAFETY": -3},
		"magnitude": 50, "visibility": "PUBLIC", "data": {"target": "NODE:j1", "serious": true, "fatal": 1}})
	TR.monthly(w)
	var sc := w.facts.query("STAFF_REPORT_IGNORED")
	check_eq(sc.size(), 1, "a fatal crash at a flagged spot is a scandal")
	check(sc[0]["data"]["declined"] and fid in sc[0]["causes"] and acc in sc[0]["causes"], "caused by the report and the crash")
	TR.monthly(w)
	check_eq(w.facts.query("STAFF_REPORT_IGNORED").size(), 1, "once per item")
