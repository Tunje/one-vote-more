extends TestCase
## MEDIA M5: hostile papers dig up old party scandals (MEDIA_SCANDAL_REVIVED), friendly ones try to bury them
## (MEDIA_SCANDAL_BURIED); opt-in via world.meta["on"] "SCANDAL_REVIVAL". Ella's scandal heat reads the facts.

const LawOps := preload("res://sim/law/law_ops.gd")
const MDT := preload("res://sim/media/media_data.gd")
const MQ := preload("res://sim/media/media_query.gd")

const WREF := 1200000
const LEFT := {"ECON_ROLE": 60000, "REDISTRIBUTION": 60000, "LABOR": 60000}
const RIGHT := {"ECON_ROLE": -60000, "REDISTRIBUTION": -60000, "LABOR": -60000}


func _line(d: Dictionary) -> Dictionary:
	var l := {}
	for ax in PolDefs.AXES:
		l[ax] = int(d.get(ax, 0))
	return l


func _world(on: bool = true) -> Dictionary:
	var w := WorldState.new(5)
	LawOps.init_world(w)
	w.month = 10
	w.values["ECON_W_REF"] = WREF
	if on:
		w.meta["on"] = ["SCANDAL_REVIVAL"]
	var sal := {}
	for c in PolDefs.CONCERNS:
		sal[c] = 100
	w.table("cell")["c1"] = {"key": "c1", "district": "district:1", "band": "MID", "pop": 600, "occ": "SERVICES",
		"ideology": _line(LEFT), "salience": sal}
	w.table("cell")["c2"] = {"key": "c2", "district": "district:1", "band": "MID", "pop": 600, "occ": "SERVICES",
		"ideology": _line(RIGHT), "salience": sal}
	w.table("party")["party:1"] = {"id": "party:1", "name": "Labour", "status": "ACTIVE", "support": 20000, "seats": 20,
		"positions": _line(LEFT), "leader": {"name": "New Boss", "integrity": 50}}
	Media.ensure_founding(w)
	var hostile: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:1"},
		{"name": "The Herald", "line": _line(RIGHT), "sens": 1.0, "invest": 3.0})["out_id"]
	var friend: String = Media.found_outlet(w, {"kind": "COMPANY", "id": "org:2"},
		{"name": "The Worker", "line": _line(LEFT), "ethics": 0.0})["out_id"]
	var fid := w.add_fact({"type": "POL_SCANDAL_REVEALED", "owner": "law", "subjects": [{"kind": "PARTY", "id": "party:1"}],
		"responsible": [{"actor": {"kind": "PARTY", "id": "party:1"}, "share": 1.0}], "impact": {"GOVERNANCE": -6},
		"magnitude": 70, "visibility": "PUBLIC", "data": {"party": "party:1", "leader": "Old Boss", "severity": 60,
			"kind": "DONATION", "donation": ""}})
	w.month = 10 + 24
	Media.run(w)     # readers, circulation, trust
	return {"w": w, "hostile": hostile, "friend": friend, "scandal": fid}


func _revived(w: WorldState) -> Array:
	return w.facts.query("MEDIA_SCANDAL_REVIVED", 0, w.month)


func _run_months(w: WorldState, n: int) -> void:
	for i in n:
		w.month += 1
		Media.run(w)


func test_off_by_default() -> void:
	var s := _world(false)
	var w: WorldState = s["w"]
	_run_months(w, 60)
	check_eq(_revived(w).size(), 0, "no revival without the switch")


func test_hostile_paper_revives_with_ella_fields() -> void:
	var s := _world()
	var w: WorldState = s["w"]
	_run_months(w, 80)
	var rv := _revived(w)
	check(rv.size() >= 1, "a hostile paper dug the story up")
	if rv.is_empty():
		return
	var d: Dictionary = rv[0]["data"]
	check_eq(String(d["outlet"]), String(s["hostile"]), "the hostile Herald, not the friendly paper")
	check_eq(String(d["scandal"]), String(s["scandal"]), "points at the original")
	check_eq(String(d["party"]), "party:1", "party")
	check_eq(int(d["n"]), 1, "first revival")
	check(int(d["strength_pm"]) > 0 and int(d["strength_pm"]) <= 1000, "strength 0..1000 (%d)" % int(d["strength_pm"]))
	check(d.has("escalated") and d.has("trigger") and d.has("person") and d.has("dragged"), "chronicle fields")
	check(int(d["age"]) >= MDT.REVIVE_MIN_AGE, "not before the minimum age")
	check_eq(MQ.revivals(w).size(), rv.size(), "query mirrors the facts")


func test_at_most_three_per_scandal() -> void:
	var s := _world()
	var w: WorldState = s["w"]
	_run_months(w, MDT.REVIVE_MAX_AGE)
	var rv := _revived(w)
	check(rv.size() <= MDT.REVIVE_MAX_N, "lifetime cap (%d)" % rv.size())
	for i in rv.size():
		check_eq(int(rv[i]["data"]["n"]), i + 1, "n counts up")


func test_person_trigger() -> void:
	var s := _world()
	var w: WorldState = s["w"]
	w.month += 1
	w.add_fact({"type": "POL_LEADER_CHANGED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": "party:1"}],
		"responsible": [], "impact": {}, "magnitude": 55, "visibility": "PUBLIC",
		"data": {"party": "party:1", "old": "X", "new": "Old Boss"}})
	var f := w.facts.get_fact(String(s["scandal"]))
	var t: Dictionary = Media._triggers(w, [f])[String(s["scandal"])]
	check_eq(String(t["trigger"]), "PERSON", "the old scandal's leader came back")
	check_eq(String(t["person"]), "Old Boss", "named")
	check(float(t["mult"]) >= 3.0, "chance multiplied")


func test_stale_repeat_costs_trust_near_the_party() -> void:
	var s := _world()
	var w: WorldState = s["w"]
	w.month = 10 + 72            # six years old: 3 stale years
	Media.run(w)
	var o := Media.outlet(w, String(s["hostile"]))
	var near: Dictionary = w.table("cell")["c1"]["trust"]
	var far: Dictionary = w.table("cell")["c2"]["trust"]
	var h := String(s["hostile"])
	var n0 := int(near[h])
	var f0 := int(far[h])
	var f := w.facts.get_fact(String(s["scandal"]))
	var t := {"mult": 1.0, "trigger": "NONE", "person": "", "post": ""}
	var rid := Media._publish_revival(w, o, f, t, w.rng.stream("test"), 1000.0)
	var d: Dictionary = w.facts.get_fact(rid)["data"]
	check_eq(int(d["cost"]), MDT.CRED_STALE * 3, "three stale years")
	check(int(near[h]) < n0, "trust falls among voters near the party (%d → %d)" % [n0, int(near[h])])
	check(n0 - int(near[h]) > f0 - int(far[h]), "far less among its opponents")
	var rid2 := Media._publish_revival(w, o, f, t, w.rng.stream("test"), 1000.0)
	check_eq(int(w.facts.get_fact(rid2)["data"]["cost"]), MDT.CRED_STALE * 3 + MDT.CRED_REVIVE_REPEAT, "same paper again: repeat cost")


func test_friendly_paper_buries() -> void:
	var s := _world()
	var w: WorldState = s["w"]
	var fr := String(s["friend"])
	var o := Media.outlet(w, String(s["hostile"]))
	var f := w.facts.get_fact(String(s["scandal"]))
	var t := {"mult": 1.0, "trigger": "NONE", "person": "", "post": ""}
	var buried := 0
	for i in 20:
		var rid := Media._publish_revival(w, o, f, t, w.rng.stream("test"), 1000.0)
		var c0 := int(Media.outlet(w, fr)["cred"])
		Media._bury(w, rid, w.rng.stream("media.revive"), 1000.0)
		var b := w.facts.query("MEDIA_SCANDAL_BURIED", w.month, w.month).filter(func(x): return String(x["data"]["revival"]) == rid)
		if not b.is_empty():
			buried += 1
			check_eq(String(b[0]["data"]["outlet"]), fr, "the friendly paper buries")
			check(int(Media.outlet(w, fr)["cred"]) < c0, "burying costs credibility")
			check(int(MQ.revivals(w).filter(func(r): return String(r["fid"]) == rid)[0]["buried_pm"]) > 0, "bury strength recorded")
	check(buried > 0, "some revivals get buried (%d/20)" % buried)
