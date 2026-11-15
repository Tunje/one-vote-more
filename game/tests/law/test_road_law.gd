extends TestCase
## Private roads, law side step 1 (planning/design-law-private-roads.md): levers, may_build, the licence procedure,
## refusals and the appeal, access and the toll cap.

const F := preload("res://tests/support/staff_fixture.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const RL := preload("res://sim/law/road_law.gd")
const Land := preload("res://sim/law/land_law.gd")


func _world(on: bool = true) -> WorldState:
	var w := F.bare_world()
	LawOps.init_world(w)
	if on:
		w.meta["on"] = ["FREIGHT_ROADS", "PRIVATE_ROADS"]
	return w


func _gov(w: WorldState, econ_role: int, autoplay: bool) -> void:
	w.table("party")["P1"] = {"id": "P1", "name": "Gov", "status": "ACTIVE", "positions": {"ECON_ROLE": econ_role}}
	F.set_pol(w, {"era": "PARLIAMENTARY", "player_party": "P1", "autoplay_player": autoplay,
		"government": {"members": ["P1"], "pm_party": "P1"}})


func _own(w: WorldState, k: String, owner: String) -> void:
	var t := Land.title(w, k).duplicate(true)
	t["owner"] = owner
	t["owner_kind"] = "COMPANY"
	w.table("land_title")[k] = t


func _plan(districts: Array, extra: Dictionary = {}) -> Dictionary:
	var p := {"tiles": ["10,10", "11,10", "12,10"], "kind": "ROAD", "districts": districts, "regime": "OWNER"}
	p.merge(extra, true)
	return p


func test_levers_are_gated_and_flag_off_does_nothing() -> void:
	var w := _world(false)
	for id in ["LAW_PRIVATE_ROADS", "LAW_PRIVATE_ROAD_ACCESS", "LAW_PRIVATE_TOLL_CAP"]:
		check(w.lever_defs.has(id) and bool(w.lever_defs[id]["legislative"]) and String(w.lever_defs[id]["legalLevel"]) == "LAW", id + " is parliament's")
		check_eq(w.lever_defs[id].get("requires", []), ["PRIVATE_ROADS"], id + " only with the flag")
	check_eq(RL.setting(w), "FORBIDDEN", "no flag: no private roads")
	check_eq(RL.may_build(w, "org:1", _plan(["D1"]))["reasons"], ["NO_PRIVATE_ROADS"], "refused, flag off")
	check_eq(RL.apply_licence(w, "org:1", _plan(["D1"])), "", "no licence filed")
	RL.monthly(w)
	check(w.peek("road_licence").is_empty(), "nothing written")
	w.meta["on"] = ["PRIVATE_ROADS"]
	check(not RL.on(w), "PRIVATE_ROADS needs FREIGHT_ROADS")


func test_settings_land_and_the_site_track() -> void:
	var w := _world()
	check_eq(RL.setting(w), "LICENCE", "by licence by default")
	var r := RL.may_build(w, "org:1", _plan(["D1"]))
	check_eq(String(r["status"]), "NEEDS_LICENCE", "state land: a licence and a wayleave")
	check_eq((r["wayleave"] as Array).size(), 3, "every tile leased from the state")
	w.levers["LAW_PRIVATE_ROADS"] = 0
	check_eq(RL.may_build(w, "org:1", _plan(["D1"]))["reasons"], ["FORBIDDEN"], "forbidden")
	w.levers["LAW_PRIVATE_ROADS"] = 2
	check_eq(String(RL.may_build(w, "org:1", _plan(["D1"]))["status"]), "LAWFUL", "free: no licence")
	w.levers["LAW_PRIVATE_ROADS"] = 1
	_own(w, "11,10", "org:2")
	r = RL.may_build(w, "org:1", _plan(["D1"]))
	check(String(r["status"]) == "REFUSED" and "LAND_NOT_HELD" in r["reasons"], "another firm's land: no forced sale")
	for k in ["10,10", "11,10", "12,10"]:
		_own(w, k, "org:1")
	check_eq(String(RL.may_build(w, "org:1", _plan(["D1"], {"kind": "TRACK"}))["status"]), "LAWFUL", "a track on its own site")
	check_eq(String(RL.may_build(w, "org:1", _plan(["D1", "D2"], {"kind": "TRACK"}))["status"]), "NEEDS_LICENCE", "across districts it is a road")
	var t := Land.title(w, "12,10")
	t["zoning"] = "RESERVE"
	check("ZONE_RESERVE" in RL.may_build(w, "org:1", _plan(["D1"]))["reasons"], "no roads through a reserve")


func test_a_market_government_grants_and_overrides_the_objection() -> void:
	var w := _world()
	_gov(w, -50000, true)
	var id := RL.apply_licence(w, "org:1", _plan(["D1", "D2"], {"junction_over": ["D2"]}))
	check(id != "", "filed")
	check_eq(w.facts.query("LAW_ROAD_LICENCE_FILED").size(), 1, "the filing is public")
	RL.monthly(w)
	check_eq(String(RL.licence(w, id)["status"]), "FILED", "the objection window runs")
	w.month += RL.OBJECTION_MONTHS
	RL.monthly(w)
	var row := RL.licence(w, id)
	check(String(row["status"]) == "GRANTED" and String(row["decision"]) == "GRANT", "granted")
	var o: Array = w.facts.query("LAW_ROAD_OBJECTION_OVERRIDDEN")
	check(o.size() == 1 and o[0]["affected"]["districts"] == ["D2"], "the objecting district feels the override")
	check_eq(String(o[0]["data"]["decided_by"]), "MINISTER", "two districts: the minister's call")


func test_a_state_minded_government_refuses_with_and_without_grounds() -> void:
	var w := _world()
	_gov(w, 100000, true)
	var a := RL.apply_licence(w, "org:1", _plan(["D1"], {"junction_over": ["D1"]}))
	var b := RL.apply_licence(w, "org:2", _plan(["D3"]))
	w.month += RL.OBJECTION_MONTHS
	RL.monthly(w)
	check_eq(String(RL.licence(w, a)["status"]), "REFUSED", "an objection gives a ground")
	var f: Array = w.facts.query("LAW_ROAD_LICENCE_REFUSED")
	var g: Array = f[0]["data"]["grounds"] if f.size() == 1 else []
	check(g.has("OBJECTIONS") and g.has("JUNCTIONS"), "grounds named")
	var rb := RL.licence(w, b)
	check_eq(String(rb["status"]), "APPEAL", "no ground: the firm appeals")
	check_eq(w.facts.query("LAW_ROAD_REFUSAL_UNGROUNDED").size(), 1, "its own fact")
	w.month = int(rb["appeal_due"])
	RL.monthly(w)
	check(String(RL.licence(w, b)["status"]) == "GRANTED" and String(RL.licence(w, b)["by"]) == "COURT", "the court grants it")
	check_eq(w.facts.query("LAW_ROAD_LICENCE_QUASHED").size(), 1, "quashed in public")


func test_three_districts_go_to_the_cabinet_and_the_player_answers() -> void:
	var w := _world()
	_gov(w, 0, false)
	var id := RL.apply_licence(w, "org:1", _plan(["D1", "D2", "D3"]))
	check(bool(RL.licence(w, id)["needs_cabinet"]), "3 districts: the Cabinet")
	w.month += RL.OBJECTION_MONTHS
	RL.monthly(w)
	var it := Office.get_item(w, String(RL.licence(w, id)["item"]))
	check(not it.is_empty() and String(it["kind"]) == "CALL" and String(it["role"]) == "CHIEF_OF_STAFF", "a Cabinet call")
	Office.answer(w, String(RL.licence(w, id)["item"]), "GRANT_COMMON_CARRIER")
	RL.monthly(w)
	var row := RL.licence(w, id)
	check(String(row["status"]) == "GRANTED" and String(row["conditions"]["regime_min"]) == "OPEN_TOLL", "granted on common carriage")
	check_eq(String(w.facts.query("LAW_ROAD_LICENCE_GRANTED")[0]["data"]["decided_by"]), "CABINET", "the Cabinet decided")


func test_access_and_the_toll_cap() -> void:
	var w := _world()
	var link := {"owner": "org:1", "build_cost": 240000, "upkeep": 2000, "ytr_last": 120}
	check_eq(RL.cost_toll(link), 300, "(2000 + 1000) ÷ 10 trips a month")
	check_eq(RL.toll_cap(w, link), 600, "default cap 200%")
	check(RL.check_terms(w, link, "OWNER", 0, 1000)["ok"], "the owner may keep it")
	check_eq(RL.check_terms(w, link, "OPEN_TOLL", 700, 0)["reasons"], ["TOLL_OVER_CAP"], "over the cap")
	w.levers["LAW_PRIVATE_TOLL_CAP"] = 300
	check_eq(RL.toll_cap(w, link), -1, "300: no cap")
	w.levers["LAW_PRIVATE_ROAD_ACCESS"] = 1
	check_eq(RL.check_terms(w, link, "OWNER", 0, 1000)["reasons"], ["COMMON_CARRIAGE"], "common carriage: must open")
	check_eq(RL.check_terms(w, link, "OPEN_TOLL", 100, 600)["reasons"], ["RESERVED_SHARE"], "keeps at most half")
	check(RL.check_terms(w, link, "OPEN_TOLL", 100, 500)["ok"], "open, half kept")
