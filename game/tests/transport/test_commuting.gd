extends TestCase
## Terra (T3 + plan-support-economy §8c, agreed with Bob): the network side of commuting (sim/transport/commuting.gd).


func _game(seed_v: int, months: int = 4) -> Simulation:
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
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


func test_commutes_read_who_works_where() -> void:
	var w := _game(1).world
	var h := w.state_hash()
	var rows := Transport.commutes(w)
	check(not rows.is_empty(), "people work somewhere")
	var total := 0
	var cross := 0
	for r in rows:
		check(String(r["from_d"]).begins_with("d:") and String(r["to_d"]).begins_with("d:") and int(r["n"]) > 0, "a row %s" % str(r))
		total += int(r["n"])
		cross += int(r["n"]) if r["from_d"] != r["to_d"] else 0
	var staff := 0
	for f in w.peek("facility").values():
		for t in f.get("staff", {}):
			for k in f["staff"][t]:
				staff += int(f["staff"][t][k])
	for o in w.peek("org").values():
		for t in o.get("crew", {}):
			for k in o["crew"][t]:
				staff += int(o["crew"][t][k])
	check(absi(total - staff / EconUtil.S) <= rows.size(), "every worker counted once (%d vs %d)" % [total, staff / EconUtil.S])
	check_eq(var_to_str(rows), var_to_str(Transport.commutes(w)), "deterministic")
	check_eq(w.state_hash(), h, "pure")


func test_commute_and_route_factor_follow_the_road() -> void:
	var w := _game(1).world
	var p := _pair(w)
	check(not p.is_empty(), "two districts joined by road")
	var same := Transport.commute_d(w, p[0], p[0])
	check(same["hops"] == 0 and same["factor"] == 1000, "within a district: no trip on the network")
	var cd := Transport.commute_d(w, p[0], p[1])
	check(int(cd["hops"]) >= 1 and int(cd["km"]) > 0 and int(cd["minutes"]) > 0, "a trip by road %s" % str(cd))
	var f0 := Transport.route_factor(w, p[0], p[1])
	check(f0 >= 800 and f0 <= Commuting.NO_ROAD_F, "a sensible factor (%d)" % f0)
	var h := w.state_hash()
	Transport.route_factor(w, p[1], p[0])
	check_eq(w.state_hash(), h, "reading is pure")
	# a worn road is worse
	for lid in cd["links"]:
		w.table("transport")["links"][lid]["cond"] = 200
	Transport._bump(w)
	var f1 := Transport.route_factor(w, p[0], p[1])
	check(f1 > f0, "worn roads raise the factor (%d → %d)" % [f0, f1])
	# congestion (last month's count) is worse again
	for lid in cd["links"]:
		var l: Dictionary = w.table("transport")["links"][lid]
		l["traffic_last"] = Transport.link_capacity(l) * 2
	Transport._bump(w)
	check(Transport.route_factor(w, p[0], p[1]) > f1, "congestion raises it more")


func test_incidents_happen_on_the_route() -> void:
	var w := _game(2).world
	var p := _pair(w)
	var cd := Transport.commute_d(w, p[0], p[1])
	var on := {}
	var links: Dictionary = w.peek("transport")["links"]
	for lid in cd["links"]:
		for ti in links[lid]["path"]:
			on[int(ti)] = true
	var spots := {}
	for salt in 40:
		for kind in ["BREAKDOWN", "CRASH"]:
			var s := Transport.incident_site(w, p[0], p[1], salt * 7919, kind)
			check(on.has(int(s["tile"])), "%s at a tile of the route (%s)" % [kind, str(s)])
			check(String(s["link"]) in cd["links"] or String(s["junction"]) != "", "on a route link or junction")
			spots[int(s["tile"])] = true
			check_eq(var_to_str(s), var_to_str(Transport.incident_site(w, p[0], p[1], salt * 7919, kind)), "deterministic")
	check(spots.size() >= 3, "incidents spread along the route (%d spots)" % spots.size())


func test_bus_lines_and_commuter_traffic() -> void:
	var w := _game(1).world
	var p := _pair(w)
	var rows := [
		{"from_d": p[0], "to_d": p[1], "bus_commuters": 120, "taxi_users": 15, "buses_in_service": 3, "seats": 150, "load_pm": 800, "breakdowns_m": 1, "crashes_m": 0},
		{"from_d": p[1], "to_d": p[0], "bus_commuters": 40, "taxi_users": 0, "buses_in_service": 1, "seats": 50, "load_pm": 900, "breakdowns_m": 0, "crashes_m": 1},
		{"from_d": p[0], "to_d": p[0], "bus_commuters": 99, "taxi_users": 3, "buses_in_service": 2, "seats": 100, "load_pm": 990, "breakdowns_m": 0, "crashes_m": 0},
	]
	var lines := Transport.bus_lines(w, rows)
	check_eq(lines.size(), 1, "one line per pair of districts (both directions), none inside a district")
	var ln: Dictionary = lines[0]
	check(int(ln["commuters"]) == 160 and int(ln["buses"]) == 4 and int(ln["load_pm"]) == 900 and int(ln["crashes_m"]) == 1, "the pair's figures add up %s" % str(ln))
	check(ln["stops"].size() >= 2 and not ln["links"].is_empty(), "stops at both settlements, over the road")
	var cd := Transport.commute_d(w, p[0], p[1])
	var lid: String = cd["links"][0]
	var before := int(w.peek("transport")["links"][lid]["traffic"])
	Transport.add_commute_traffic(w, rows)
	var want := (3 + 1) * Commuting.BUS_TRIPS_DAY * Commuting.WORK_DAYS + ceili(15.0 / 1.5) * Commuting.TAXI_TRIPS_DAY * Commuting.WORK_DAYS
	check_eq(int(w.peek("transport")["links"][lid]["traffic"]) - before, want, "buses and taxis count on the roads")
	var sim := _game(1, 0)
	sim.step()
	sim.step()
	var any_last := false
	for l in sim.world.peek("transport")["links"].values():
		any_last = any_last or l.has("traffic_last")
	check(any_last, "the monthly reset keeps last month's count")


## Bob's EconQuery.commuting (opt-in SUPPORT_T) drawn: bus lines follow their road in order, buses stand on the line,
## incidents on the route; the colony map and the window view show them. Display placement is pure.
func test_bus_lines_are_drawn_from_bobs_rows() -> void:
	var sim := EconSim.make(1, "BALANCED", {}, true)
	sim.world.meta["on"] = ["SUPPORT_T"]
	for _m in 4:
		sim.step()
	var w := sim.world
	var rows := EconQuery.commuting(w)
	check(not rows.is_empty(), "Bob's commuting rows with SUPPORT_T on")
	var lines := Transport.bus_lines(w, rows)
	check(not lines.is_empty(), "at least one bus line between districts")
	var h := w.state_hash()
	for ln in lines:
		var path: Array = ln["path"]
		if ln["links"].is_empty():
			continue
		check(path.size() >= 2, "a line has a path %s" % ln["id"])
		for i in range(1, path.size()):
			var a := Transport.int_tile(int(path[i - 1]))
			var b := Transport.int_tile(int(path[i]))
			check(maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1 or Terrain.at(w, (a.x + b.x) / 2, (a.y + b.y) / 2) in ["r", Terrain.SEA],
				"the path runs on (%s → %s, or a bridge)" % [str(a), str(b)])
		check_eq(ln["bus_tiles"].size(), mini(int(ln["buses"]), Commuting.SHOW_BUSES), "one mark per bus (capped)")
		for bt in ln["bus_tiles"]:
			check(int(bt) in path, "buses stand on the line")
	check_eq(var_to_str(lines), var_to_str(Transport.bus_lines(w, rows)), "deterministic")
	check_eq(w.state_hash(), h, "pure")
	# incidents (0 until Bob's §8c): injected, they land on the route
	var r0: Dictionary = rows[0].duplicate()
	for r in rows:
		if r["from_d"] != r["to_d"] and not Transport.commute_d(w, r["from_d"], r["to_d"])["links"].is_empty():
			r0 = r.duplicate()
			break
	r0["breakdowns_m"] = 2
	r0["crashes_m"] = 1
	var l2: Array = Transport.bus_lines(w, [r0])
	check_eq(l2[0]["incidents"].size(), 3, "two breakdowns and a crash")
	for inc in l2[0]["incidents"]:
		check(int(inc["tile"]) in l2[0]["path"] or String(inc["junction"]) != "", "an incident on the line %s" % str(inc))
	# the colony map and the window view
	var s := GameSession.new()
	s.new_game(1, true)
	s.sim = sim
	var v := ColonyMap.new()
	v.session = s
	v._ready()
	v.size = Vector2(1600, 900)
	v.refresh()
	check(not v._bus_lines.is_empty(), "the map has the bus lines")
	var lid := String(v._bus_lines[0]["links"][0]) if not v._bus_lines[0]["links"].is_empty() else ""
	if lid != "":
		check(v.link_text(w, lid).contains("Bus line"), "the link panel lists its bus lines")
	check(v._network_summary(w).contains("Buses"), "the network summary counts the buses")
	v.free()
	var vd := ColonyVista.gather(w)
	check(vd.has("vehicles"), "the window view knows the buses")
