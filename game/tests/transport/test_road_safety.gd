extends TestCase
## Terra (the user's design via Wilma 2026-11-15): road speed apart from surface, accidents near people on foot,
## over- and underpasses, flyovers (sim/transport/road_safety.gd, flag ROAD_SAFETY). Unit tests only (no long runs).


func _game(seed_v: int = 1, months: int = 3, on: bool = true) -> Simulation:
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(RoadSafety.FLAG)
	for _m in months:
		sim.step()
	return sim


## The colony link with the most people near it.
func _busiest(w: WorldState) -> String:
	var best := ""
	var bw := -1
	for lid in EconUtil.sorted_keys(Transport._links(w)):
		var s := 0
		for sp in RoadSafety.spots(w, String(lid)):
			s += int(sp[1])
		if s > bw:
			bw = s
			best = String(lid)
	return best


## Make a link a fast, busy paved road.
func _fast(w: WorldState, lid: String) -> Dictionary:
	var l: Dictionary = w.table("transport")["links"][lid]
	l["kind"] = "PAVED"
	l["cond"] = 1000
	l["traffic_last"] = 3000
	Transport._bump(w)
	return l


func test_flag_off_changes_nothing() -> void:
	var w := _game(1, 3, false).world
	var lid := _busiest(w)
	var h := w.state_hash()
	check(Transport.set_limit(w, lid, 50) != "", "no limits without the flag")
	check(Transport.safety_needs(w).is_empty(), "no safety needs")
	check_eq(RoadSafety.speed_factor(w, {"limit": 30, "kind": "PAVED", "cond": 1000}), 1.0, "a stray limit is ignored")
	check(not bool(Transport.plan_link(w, {"pass": lid, "tile": 0, "type": "OVERPASS"})["ok"]), "no passes")
	var js := Transport.junctions(w)
	if not js.is_empty():
		check(not bool(Transport.plan_link(w, {"junction": EconUtil.sorted_keys(js)[0], "type": "FLYOVER"})["ok"]), "no flyovers")
	check_eq(w.state_hash(), h, "nothing written")
	w.month += 1
	Transport.step_month(w)
	check(not w.peek("transport").has("safety_offered") and w.facts.query("TRANSPORT_ROAD_ACCIDENT", 0, 1 << 30).is_empty(), "no accidents drawn")


func test_speed_is_apart_from_surface() -> void:
	var w := _game().world
	var lid := _busiest(w)
	var l := _fast(w, lid)
	var cap := Transport.link_capacity(l, w)
	check_eq(RoadSafety.kmh(w, l), 110, "a paved road's design speed")
	var sig0 := Transport._struct_sig(w)
	var a := String(Transport.nodes(w)[0]["id"])
	var b := String(Transport.nodes(w)[1]["id"])
	check_eq(Transport.set_limit(w, lid, 50), "", "a limit is set")
	check_eq(RoadSafety.kmh(w, l), 50, "driven at the limit")
	check_eq(Transport.link_capacity(l, w), cap, "the surface keeps its capacity")
	check(Transport._struct_sig(w) != sig0, "a limit changes route times (memo key)")
	check(Transport.set_limit(w, lid, 65) != "", "only the listed limits")
	check(not w.facts.query("TRANSPORT_SPEED_LIMIT_SET", 0, 1 << 30).is_empty(), "a limit is news")
	# a slower link makes a slower trip along it
	var g := Transport._graph(w, true)
	var slow := 0
	for e in g["adj"].get(int(l["path"][0]), []):
		if String(e[2]) == lid:
			slow = int(e[5])
	Transport.set_limit(w, lid, 0)
	var g2 := Transport._graph(w, true)
	var fast := 0
	for e in g2["adj"].get(int(l["path"][0]), []):
		if String(e[2]) == lid:
			fast = int(e[5])
	check(slow > fast and fast > 0, "the limit slows the trip (%d vs %d hundredths of an hour)" % [slow, fast])
	check(a != b, "two nodes")


func test_people_near_fast_roads_are_at_risk_and_passes_help() -> void:
	var w := _game().world
	var lid := _busiest(w)
	check(not RoadSafety.spots(w, lid).is_empty(), "a road through a town has people near it")
	var l := _fast(w, lid)
	var r110 := RoadSafety.risk(w, lid)
	check(r110 > 0.0, "a fast road near people is dangerous")
	check(RoadSafety.risk(w, lid, 50) < r110 and RoadSafety.risk(w, lid, 30) == 0.0, "slower is safer; 30 km/h almost safe")
	l["traffic_last"] = 300
	check(RoadSafety.risk(w, lid) < r110, "less traffic, less danger")
	l["traffic_last"] = 3000
	var h := w.state_hash()
	var needs := Transport.safety_needs(w)
	check_eq(w.state_hash(), h, "the choices are pure")
	var row := {}
	for n in needs:
		if n["link"] == lid:
			row = n
	check(not row.is_empty(), "the road is listed")
	if row.is_empty():
		return
	check(int(row["risk_pm"]) > 0 and int(row["people"]) > 0 and int(row["kmh"]) == 110 and String(row["spot"]).contains(","), "its danger %s" % str(row))
	var by := {}
	for o in row["options"]:
		by[String(o["fix"])] = o
		check(int(o["risk_after_pm"]) < int(row["risk_pm"]), "%s makes it safer" % o["fix"])
	check(by.has("LIMIT_50") and by.has("OVERPASS") and by.has("UNDERPASS"), "limits and passes on offer: %s" % str(by.keys()))
	check(int(by["LIMIT_50"]["cost"]) == 0 and int(by["LIMIT_50"]["hours_lost"]) > 0, "a limit costs nothing but time")
	check(int(by["UNDERPASS"]["cost"]) > int(by["OVERPASS"]["cost"]) and int(by["UNDERPASS"]["risk_after_pm"]) < int(by["OVERPASS"]["risk_after_pm"]),
		"an underpass costs more and saves more")
	# built: the pass stands and the danger at that spot falls
	var spec: Dictionary = by["UNDERPASS"]["spec"]
	check_eq(Transport.complete_road(w, {"id": "proj:p", "link": spec, "owner": "gov", "district": String(row["district"])}), lid, "a pass is built")
	check_eq((l.get("passes", []) as Array).size(), 1, "on the road")
	check(RoadSafety.risk(w, lid) < r110, "less danger")
	check(not w.facts.query("TRANSPORT_PASS_OPENED", 0, 1 << 30).is_empty(), "news")
	check(not bool(Transport.plan_link(w, spec)["ok"]), "not twice at one place")


func test_accidents_happen_and_name_the_refused_pass() -> void:
	var w := _game().world
	var lid := _busiest(w)
	w.month += 1
	Transport.step_month(w)   # the first tick re-plans old crossings once; then make the road fast
	var l := _fast(w, lid)
	var m0 := w.month + 1
	var seen := 0
	for _m in 60:
		w.month += 1
		Transport.step_month(w)
		l = w.table("transport")["links"][lid]   # the tick may re-plan a link into a new record
		l["kind"] = "PAVED"
		l["cond"] = 1000
		l["traffic_last"] = 3000
		Transport._bump(w)
	var f := w.facts.query("TRANSPORT_ROAD_ACCIDENT", m0, 1 << 30)
	check(not f.is_empty(), "accidents near people on a fast busy road (%d in 5 years)" % f.size())
	var killed := 0
	var refused := 0
	for x in f:
		var d: Dictionary = x["data"]
		seen += 1
		killed += int(d["killed"])
		refused += 1 if bool(d["pass_refused"]) and String(d["link"]) == lid else 0
		check(String(d["district"]).begins_with("d:") and int(d["people"]) > 0 and String(d["tile"]).contains(",") and d.has("near")
			and int(d["kmh"]) > int(RoadSafety.SAFE_KMH) and int(d["killed"]) + int(d["injured"]) >= 1, "a full fact %s" % str(d))
		if String(d["link"]) == lid:
			check_eq(int(d["kmh"]), 110, "the fast road at its design speed")
		check_eq(x["visibility"], "PUBLIC", "public")
	check(refused > 0, "a pass on offer and not built is in the news")
	check(Transport.road_accidents_last_year(w) >= 0, "counted")
	check(seen == f.size(), "all checked")


func test_a_flyover_where_fast_roads_meet() -> void:
	var w := _game().world
	var js := Transport.junctions(w)
	if js.is_empty():
		check(true, "no junction on this map")
		return
	var jid := String(EconUtil.sorted_keys(js)[0])
	var fx: Array = Transport.traffic_fixes(w).get("NODE:" + jid, {}).get("options", [])
	var fly := fx.filter(func(o): return o["fix"] == "FLYOVER")
	check(fly.size() == 1 and int(fly[0]["cap_pm"]) > 1000 and int(fly[0]["acc_pm"]) < 1000, "a flyover on offer: more capacity, fewer crashes")
	check_eq(Transport.complete_road(w, {"id": "proj:f", "link": {"junction": jid, "type": "FLYOVER"}, "owner": "gov"}), jid, "built")
	check_eq(String(Transport.junctions(w)[jid]["type"]), "FLYOVER", "the roads cross on two levels")


func test_in_the_game_deterministic_and_save_load() -> void:
	var a := _game(2, 2)
	var b := _game(2, 2)
	for s in [a, b]:
		var lid := _busiest(s.world)
		_fast(s.world, lid)
		Transport.set_limit(s.world, lid, 90)
		s.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "deterministic")
	var path := "user://test_road_safety.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := EconSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
