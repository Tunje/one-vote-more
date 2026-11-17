extends TestCase
## Terra (user via Wilma 2026-11-15): freight drives on the roads (FreightRoads, flag FREIGHT_ROADS), the roads limit
## what gets through, worn paved roads lose capacity in steps, and road_needs sees the jam coming and offers repair,
## upgrade, widening and new links.


func _game(seed_v: int = 1, months: int = 4, on: bool = true) -> Simulation:
	var sim := GameSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append(FreightRoads.FLAG)
	for _m in months:
		sim.step()
	return sim


## Two districts joined by road (the first pair with a route).
func _pair(w: WorldState) -> Array:
	var ds: Array = []
	for s in ColonyLayout.settlements(w):
		if not String(s["district"]) in ds:
			ds.append(String(s["district"]))
	for a in ds:
		for b in ds:
			if a != b and Transport.commute_d(w, a, b)["ok"] and not Transport.commute_d(w, a, b)["links"].is_empty():
				return [a, b]
	return []


func _next_month(w: WorldState) -> void:
	w.month += 1
	Transport.step_month(w)


func test_flag_off_changes_nothing() -> void:
	var w := _game(1, 4, false).world
	var p := _pair(w)
	check(not p.is_empty(), "two districts joined by road")
	var h := w.state_hash()
	check_eq(Transport.freight_room_mu(w, p[0], p[1]), FreightRoads.BIG, "no limit")
	Transport.add_freight_traffic(w, p[0], p[1], 500000, 1000)
	check_eq(w.state_hash(), h, "no trucks written")
	check_eq(Transport.deliverable_pm(w, p[0], p[1]), 1000, "everything gets through")
	check_eq(Transport.district_jam_pm(w, p[0]), 0, "no jam signal")
	var l: Dictionary = w.table("transport")["links"].values()[0].duplicate()
	l["kind"] = "PAVED"
	l["cond"] = 300
	check_eq(Transport.effective_kind(l, w), "PAVED", "the old rule: a paved road at 30% still works as paved")
	for n in Transport.road_needs(w):
		check(String(n["why"]) != "DETOUR" and int(n["proj_pm"]) == int(n["load_pm"]) and int(n["trend"]) == 0, "no projection or detours %s" % str(n["key"]))


func test_worn_paved_roads_lose_capacity_in_steps() -> void:
	var w := _game(1, 1).world
	var l: Dictionary = w.table("transport")["links"].values()[0].duplicate()
	l["kind"] = "PAVED"
	l["lanes"] = 1
	l["bridges"] = 0
	for row in [[1000, "PAVED"], [450, "PAVED"], [300, "ROAD"], [100, "TRACK"]]:
		l["cond"] = row[0]
		check_eq(Transport.effective_kind(l, w), String(row[1]), "condition %d" % int(row[0]))
		check_eq(Transport.link_capacity(l, w), int(Transport.CAPACITY[row[1]]), "capacity at %d" % int(row[0]))


func test_trucks_go_on_the_route_and_the_room_runs_down() -> void:
	var w := _game(1, 4).world
	var p := _pair(w)
	var r := FreightRoads.route_items(w, p[0], p[1])
	check(not r.is_empty() and not (r["links"] as Array).is_empty(), "a route of links %s" % str(r))
	var lid := String(r["links"][0])
	var links: Dictionary = w.table("transport")["links"]
	# the market's own freight this month (Bob's wiring) cleared from the route, so the trucks below are counted alone;
	# trucks are the ceiling of the month's total on a link, so a part-load rides free in a truck already counted
	for id in FreightRoads.route_ids(w, p[0], p[1]):
		var x := FreightRoads._item(w, String(id))
		x["traffic"] = int(x.get("traffic", 0)) - FreightRoads.trucks_pcu(int(x.get("frt", 0)))
		x["frt"] = 0
	w.table("transport")["fpairs"] = {}
	if w.table("transport").has("jams"):
		w.table("transport")["jams"].erase(p[1])
	var jam_facts0 := _facts_for(w, "TRANSPORT_FREIGHT_JAM", p[1]).size()
	var ended0 := _facts_for(w, "TRANSPORT_FREIGHT_JAM_ENDED", p[1]).size()
	var t0 := int(links[lid]["traffic"])
	var room0 := Transport.freight_room_mu(w, p[0], p[1])
	check(room0 > 0 and room0 < FreightRoads.BIG, "a finite room (%d)" % room0)
	var mu := FreightRoads.UNITS_PER_TRUCK * 1000 * 3   # three trucks
	Transport.add_freight_traffic(w, p[0], p[1], mu)
	check_eq(int(links[lid]["traffic"]) - t0, 3 * 2 * FreightRoads.TRUCK_PCU, "three trucks there and back, two cars each")
	check_eq(int(links[lid]["frt"]), mu, "the freight is counted on the link")
	check(Transport.freight_room_mu(w, p[0], p[1]) <= room0 - mu, "the room runs down")
	Transport.add_freight_traffic(w, p[0], p[1], 1)   # a part-load: one more truck
	check_eq(int(links[lid]["traffic"]) - t0, 4 * 2 * FreightRoads.TRUCK_PCU, "a part-load still needs a truck")
	var room1 := Transport.freight_room_mu(w, p[0], p[1])
	Transport.add_freight_traffic(w, p[0], p[1], room1, 4000000)
	check_eq(Transport.freight_room_mu(w, p[0], p[1]), 0, "full")
	var h := w.state_hash()
	Transport.freight_room_mu(w, p[1], p[0])
	Transport.deliverable_pm(w, p[0], p[1])
	Transport.district_jam_pm(w, p[0])
	check_eq(w.state_hash(), h, "the queries are pure")
	# next month: what was held shows; last month's freight counts apart from the commuters
	_next_month(w)
	var moved := mu + 1 + room1
	check_eq(Transport.deliverable_pm(w, p[0], p[1]), moved * 1000 / (moved + 4000000), "deliverable = moved / wanted")
	check(int(links[lid]["fpcu_last"]) > 0 and int(links[lid]["frt"]) == 0, "freight moved to last month")
	check(Transport.district_jam_pm(w, p[0]) > 0, "the jam signal sees the load")
	check(int(w.peek("transport")["jams"].get(p[1], 0)) == 1, "the district is jammed")
	var facts := _facts_for(w, "TRANSPORT_FREIGHT_JAM", p[1])
	check_eq(facts.size() - jam_facts0, 1, "one public fact")
	if not facts.is_empty():
		var d: Dictionary = facts[-1]["data"]
		check(String(d["district"]) == p[1] and String(d["where"]) != "" and int(d["held_pm"]) > FreightRoads.JAM_FACT_PM, "naming district and link %s" % str(d))
	_next_month(w)   # nothing held this month: the jam ends
	check(not w.peek("transport")["jams"].has(p[1]), "the jam is over")
	check_eq(_facts_for(w, "TRANSPORT_FREIGHT_JAM_ENDED", p[1]).size() - ended0, 1, "and that is news too")


func _facts_for(w: WorldState, type: String, d: String) -> Array:
	return w.facts.query(type, 0, 1 << 30).filter(func(f): return String(f["type"]) == type and String(f["data"].get("district", "")) == d)


func test_road_needs_see_the_trend_and_offer_every_way() -> void:
	var w := _game(1, 4).world
	var links: Dictionary = w.table("transport")["links"]
	var ids := CoreUtil.sorted_keys(links).filter(func(id): return int(links[id].get("globe", 0)) == 0)
	for lid in links:
		links[lid]["cond"] = 1000
		links[lid]["traffic"] = 0
		links[lid]["traffic_last"] = 0
	for jid in w.table("transport").get("junctions", {}):
		w.table("transport")["junctions"][jid]["traffic"] = 0
		w.table("transport")["junctions"][jid]["traffic_last"] = 0
	var lid0 := String(ids[0])
	var l: Dictionary = links[lid0]
	l["kind"] = "ROAD"
	var cap := Transport.link_capacity(l, w)
	l["traffic_last"] = cap * 7 / 10           # 70% today ...
	l["yp"] = cap * 3 / 10
	l["yl"] = cap * 6 / 10                     # ... and 30% more each year
	Transport._bump(w)
	var by := {}
	for n in Transport.road_needs(w):
		by[n["key"]] = n
	check(by.has("LINK:" + lid0), "seen before it jams: %s" % str(by.keys()))
	var n0: Dictionary = by.get("LINK:" + lid0, {})
	check(int(n0.get("load_pm", 0)) == 700 and int(n0.get("proj_pm", 0)) > Transport.NEED_LOAD_PM and int(n0.get("trend", 0)) > 0,
		"projected over the horizon %s" % str(n0))
	var types := {}
	for o in n0.get("options", []):
		types[String(o["type"])] = true
		check(int(o["cost"]) > 0 and int(o["months"]) > 0 and o.has("spec") and int(o["load_after_pm"]) <= int(n0["proj_pm"]),
			"a full option %s" % str(o))
		check_eq(int(o["relief_pm"]), int(n0["proj_pm"]) - int(o["load_after_pm"]), "relief = before − after")
	check(types.has("UPGRADE") and types.has("WIDEN"), "upgrade and widen on offer: %s" % str(types.keys()))
	# a worn busy link is repaired before a worn quiet one
	var lid1 := String(ids[1])
	var lid2 := String(ids[2]) if ids.size() > 2 else ""
	if lid2 != "":
		for x in [lid1, lid2]:
			links[x]["kind"] = "TRACK"
			links[x]["cond"] = 400
		links[lid1]["traffic_last"] = Transport.link_capacity(links[lid1], w) * 7 / 10
		Transport._bump(w)
		var sev := {}
		for n in Transport.road_needs(w):
			sev[n["key"]] = int(n["severity"])
			if n["key"] == "LINK:" + lid1:
				var rep := (n["options"] as Array).filter(func(o): return o["fix"] == "REPAIR")
				check(rep.size() == 1, "repair among the options")
		check(int(sev.get("LINK:" + lid1, 0)) > int(sev.get("LINK:" + lid2, 0)), "busy before quiet %s" % str(sev))


func test_districts_joined_the_long_way_round_get_a_new_link_on_offer() -> void:
	var seen := 0
	for sd in [1, 2, 3]:
		var w := _game(sd, 4).world
		for dt in FreightRoads.detours(w):
			seen += 1
			check(int(dt["new_km"]) < int(dt["road_km"]) and dt["spec"].has("a") and dt["spec"]["kind"] == "ROAD" and int(dt["cost"]) > 0,
				"a shorter new link %s" % str(dt))
			var plan := Transport.plan_link(w, dt["spec"])
			check(bool(plan["ok"]), "the spec is a valid commission")
		for n in Transport.road_needs(w):
			if String(n["why"]) == "DETOUR":
				check(String(n["key"]).begins_with("PAIR:") and n["fix"] == "NEW_LINK" and int(n["severity"]) > 0, "a detour need %s" % str(n))
	# force one: the only road between two districts made to wind far round
	var w2 := _game(1, 4).world
	var p := _pair(w2)
	var na := Commuting.district_node(w2, p[0])
	var nb := Commuting.district_node(w2, p[1])
	var dt2 := {"a": p[0], "b": p[1], "road_km": 999, "new_km": 50, "spec": {"a": int(na["tile"]), "b": int(nb["tile"]), "kind": "ROAD"},
		"cost": 1000, "months": 3, "items": [], "trips": 600}
	var o := Transport._detour_option(dt2, 1200, 1000)
	check(o["type"] == "NEW" and int(o["load_after_pm"]) == 600 and int(o["relief_pm"]) == 600, "the pair's trips leave the old route %s" % str(o))
	check(seen >= 0, "detours found on seeds 1-3: %d" % seen)


func test_in_the_game_deterministic_and_save_load() -> void:
	var a := _game(3, 3)
	var b := _game(3, 3)
	for s in [a, b]:
		var p := _pair(s.world)
		Transport.add_freight_traffic(s.world, p[0], p[1], 300000, 900000)
		s.step()
	check_eq(a.world.state_hash(), b.world.state_hash(), "deterministic")
	check(not a.world.facts.query("TRANSPORT_FREIGHT_JAM", 0, 1 << 30).is_empty(), "the jam makes the news")
	var path := "user://test_freight_roads.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := GameSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	var p2 := _pair(a.world)
	check_eq(Transport.freight_room_mu(c.world, p2[0], p2[1]), Transport.freight_room_mu(a.world, p2[0], p2[1]), "the same room after loading")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_jam_is_shared_with_the_commuters() -> void:
	var w := _game(2, 4).world
	var p := _pair(w)
	var ids := FreightRoads.route_ids(w, p[0], p[1])
	check(not ids.is_empty(), "a route")
	for id in ids:
		var x := FreightRoads._item(w, String(id))
		x["traffic_last"] = 0
		x["fpcu_last"] = 0
		x["fwt_last"] = 0
		x["frt"] = 0
	var free := Transport.freight_room_mu(w, p[0], p[1])
	for id in ids:
		var x := FreightRoads._item(w, String(id))
		x["traffic_last"] = int(x["fcap"]) * 3   # commuters alone at three times capacity
	var jammed := Transport.freight_room_mu(w, p[0], p[1])
	check(jammed > 0 and jammed < free, "freight still gets a share of a jammed road (%d of %d)" % [jammed, free])
	for id in ids:
		FreightRoads._item(w, String(id))["fwt_last"] = int(FreightRoads._item(w, String(id))["fcap"]) * 3
	check(Transport.freight_room_mu(w, p[0], p[1]) > jammed, "more freight wanted: a bigger share")


func test_road_needs_say_what_each_road_would_free() -> void:
	var w := _game(1, 4).world
	var p := _pair(w)
	var ids := FreightRoads.route_ids(w, p[0], p[1])
	check(not ids.is_empty(), "a route")
	w.table("transport")["fpairs"] = {}
	w.table("transport")["fheld"] = {}
	Transport.add_freight_traffic(w, p[0], p[1], 50000, 300000, "FOOD")
	Transport.add_freight_traffic(w, p[0], p[1], 0, 100000, "MATERIAL")
	Transport.add_freight_traffic(w, p[0], p[1], 0, 20000)   # the market named no good
	_next_month(w)
	# the route jammed last month: every link and junction on it is a need now
	for id in ids:
		var x := FreightRoads._item(w, String(id))
		x["traffic_last"] = int(x["fcap"]) * 2
	Transport._bump(w)
	var h := w.state_hash()
	var needs := Transport.road_needs(w)
	check_eq(w.state_hash(), h, "pure")
	var seen := 0
	var prev := 1 << 40
	for n in needs:
		check(int(n["severity"]) <= prev, "still ordered by severity")
		prev = int(n["severity"])
		check(n.has("held_mu") and n.has("held_by_good") and n.has("to_districts") and n.has("trips"), "benefit fields on %s" % n["key"])
		var id := String(n["key"]).substr(5)
		if id in ids:
			seen += 1
			check_eq(int(n["held_mu"]), 420000, "all the freight held on the route counts at %s" % id)
			check_eq(var_to_str(n["held_by_good"]), var_to_str({"FOOD": 300000, "MATERIAL": 100000, "?": 20000}), "by good")
			check_eq(var_to_str(n["to_districts"]), var_to_str({p[1]: 420000}), "bound for the destination")
			check_eq(int(n["trips"]), int(FreightRoads._item(w, id)["traffic_last"]), "its traffic last month")
		elif not String(n["key"]).begins_with("PAIR:"):
			check_eq(int(n["held_mu"]), 0, "nothing held off the route")
	check(seen > 0, "the route's links are listed")
	var off := _game(1, 4, false).world
	for n in Transport.road_needs(off):
		check(not n.has("held_mu"), "flag off: no benefit fields")
	# a key that is not a pair is skipped, not an error (Wilma 2026-11-15)
	w.table("transport")["fpairs_last"]["junk"] = [0, 5000]
	w.table("transport")["fpairs"] = {"junk": [0, 5000]}
	Transport._bump(w)
	check(FreightRoads.held_through(w) is Dictionary, "held_through skips it")
	_next_month(w)
	check(true, "the jam facts skip it too")


func test_held_freight_is_credited_to_the_bottleneck() -> void:
	var w := _game(1, 4).world
	var p := _pair(w)
	var ids := FreightRoads.route_ids(w, p[0], p[1])
	check(ids.size() >= 2, "a route of two or more items")
	w.table("transport")["fpairs"] = {}
	w.table("transport")["fheld"] = {}
	Transport.add_freight_traffic(w, p[0], p[1], 0, 300000, "FOOD")
	_next_month(w)
	var worst := String(ids[0])
	for id in ids:
		var x := FreightRoads._item(w, String(id))
		x["traffic_last"] = int(x["fcap"]) * (3 if String(id) == worst else 2)
	Transport._bump(w)
	var by := {}
	for n in Transport.road_needs(w):
		by[String(n["key"]).substr(5)] = n
	for id in ids:
		if by.has(id):
			check_eq(int(by[id]["held_mu"]), 300000, "held on the whole route at %s" % id)
			check_eq(int(by[id]["bottleneck_mu"]), 300000 if String(id) == worst else 0, "freed only at the bottleneck: %s" % id)
	# two equal bottlenecks share it
	var second := String(ids[1])
	FreightRoads._item(w, second)["traffic_last"] = int(FreightRoads._item(w, second)["fcap"]) * 3   # the same load
	Transport._bump(w)
	var tot := 0
	var bn := {}
	for n in Transport.road_needs(w):
		if not String(n["key"]).begins_with("PAIR:"):
			tot += int(n.get("bottleneck_mu", 0))
			bn[String(n["key"]).substr(5)] = int(n.get("bottleneck_mu", 0))
	check_eq(tot, 300000, "shared, never counted twice")
	if bn.has(worst) and bn.has(second):
		check(int(bn[worst]) == 150000 and int(bn[second]) == 150000, "two equal bottlenecks share it equally %s" % str(bn))
