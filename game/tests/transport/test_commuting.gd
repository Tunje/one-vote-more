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
