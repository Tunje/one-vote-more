extends TestCase
## Terra (user's go via Wilma 2026-11-15): private roads, flag PRIVATE_ROADS on FREIGHT_ROADS
## (sim/transport/private_roads.gd). Step 1: ownership, terms, changes of hands, kept out of the government's works.


func _game(seed_v: int = 1, months: int = 3, on: bool = true) -> Simulation:
	var sim := GameSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append_array([FreightRoads.FLAG, PrivateRoads.FLAG])
	for _m in months:
		sim.step()
	return sim


## A company (any org that is not the government).
func _firm(w: WorldState, skip: String = "") -> String:
	for oid in CoreUtil.sorted_keys(w.peek("org")):
		if String(oid) != "gov" and String(oid) != skip:
			return String(oid)
	return ""


## A new link between the first two district nodes, built for `owner` on `terms`.
func _build(w: WorldState, owner: String, terms: Dictionary = {}) -> String:
	var ds: Array = []
	for s in ColonyLayout.settlements(w):
		if not String(s["district"]) in ds:
			ds.append(String(s["district"]))
	var a := Commuting.district_node(w, ds[0])
	var b := Commuting.district_node(w, ds[1])
	var spec := {"a": int(a["tile"]), "b": int(b["tile"]), "kind": "ROAD"}
	spec.merge(terms)
	return Transport.complete_road(w, {"id": "proj:t", "link": spec, "owner": owner, "district": ds[0], "licence": "lic:1"})


func test_a_firms_road_is_its_own() -> void:
	var w := _game().world
	var firm := _firm(w)
	check(firm != "", "a firm")
	var lid := _build(w, firm, {"regime": "OPEN_TOLL", "toll": 500, "reserved_pm": 300})
	check(lid != "", "built")
	var pl := Transport.private_link(w, lid)
	check_eq(String(pl.get("owner", "")), firm, "owned by the firm")
	check(pl["regime"] == "OPEN_TOLL" and int(pl["toll"]) == 500 and int(pl["reserved_pm"]) == 300 and pl["licence"] == "lic:1", "on its terms %s" % str(pl))
	check(int(pl["build_cost"]) > 0 and int(pl["public_money"]) == 0, "its cost recorded")
	check(int(pl["upkeep"]) > 0 and int(pl["upkeep"]) < int(pl["build_cost"]) / 20, "an upkeep a month, small beside the cost (%d of %d)" % [int(pl["upkeep"]), int(pl["build_cost"])])
	check_eq(Transport.private_links(w, firm), [lid], "listed for its owner")
	# a government road stays public
	var pub := _build(w, "gov")
	check(Transport.private_link(w, pub).is_empty(), "the government's road is public")
	# terms
	check_eq(Transport.set_terms(w, lid, "OWNER", 999, 0), "", "the owner closes it")
	check(Transport.private_link(w, lid)["regime"] == "OWNER" and int(Transport.private_link(w, lid)["toll"]) == 0, "no toll on an owner road")
	check(Transport.set_terms(w, lid, "SOMETIMES", 0, 0) != "", "an unknown regime refused")
	check(Transport.set_terms(w, pub, "OWNER", 0, 0) != "", "a public road has no terms")


func test_the_government_never_works_on_a_private_road() -> void:
	var w := _game().world
	var firm := _firm(w)
	var lid := _build(w, firm)
	var l: Dictionary = w.table("transport")["links"][lid]
	l["cond"] = 200
	l["traffic_last"] = Transport.link_capacity(l, w) * 3
	Transport._bump(w)
	for n in Transport.road_needs(w):
		check(String(n["key"]) != "LINK:" + lid, "not among the government's needs")
	check(not Transport.traffic_fixes(w).has("LINK:" + lid), "no works offered")
	for s in ColonyLayout.settlements(w):
		var job := Transport.auto_job(w, String(s["district"]))
		check(not lid in job.values(), "the auto job leaves it alone (%s)" % str(job))
	# repairs: by its owner (adds to its cost), by a step-in (public money)
	var c0 := int(Transport.private_link(w, lid)["build_cost"])
	Transport.complete_road(w, {"id": "proj:r1", "link": {"repair": lid}, "owner": firm})
	check(int(Transport.private_link(w, lid)["build_cost"]) > c0, "the owner's repair adds to its cost")
	w.table("transport")["links"][lid]["cond"] = 200
	Transport.complete_road(w, {"id": "proj:r2", "link": {"repair": lid}, "owner": "gov", "step_in": true})
	check(int(Transport.private_link(w, lid)["public_money"]) > 0, "a step-in counts as public money")
	Transport.add_public_money(w, lid, 1000)
	# taken over: public again, and the government's works see it
	w.table("transport")["links"][lid]["cond"] = 200
	check_eq(Transport.transfer_link(w, lid, "", "TAKEOVER"), "", "taken over")
	check(Transport.private_link(w, lid).is_empty() and not w.table("transport")["links"][lid].has("public_money"), "the private fields are gone")
	var keys := Transport.road_needs(w).map(func(n): return String(n["key"]))
	check("LINK:" + lid in keys, "now a government need")


func test_changes_of_hands_are_news() -> void:
	var w := _game().world
	var a := _firm(w)
	var b := _firm(w, a)
	var lid := _build(w, a)
	var sig0 := Transport._struct_sig(w)
	check_eq(Transport.transfer_link(w, lid, b, "SALE"), "", "sold")
	check_eq(String(Transport.private_link(w, lid)["owner"]), b, "the buyer owns it")
	check(Transport._struct_sig(w) != sig0, "a change of hands changes the network's shape (route memos refresh)")
	check(Transport.transfer_link(w, lid, "nobody", "SALE") != "", "an unknown buyer refused")
	check(Transport.transfer_link(w, lid, b, "STOLEN") != "", "an unknown reason refused")
	var f := w.facts.query("TRANSPORT_LINK_CHANGED_HANDS", 0, 1 << 30)
	check_eq(f.size(), 1, "one public fact")
	if f.size() == 1:
		check(f[0]["data"]["from"] == a and f[0]["data"]["to"] == b and f[0]["data"]["why"] == "SALE", "who, to whom, why %s" % str(f[0]["data"]))


func test_flag_off_and_save_load() -> void:
	var off := _game(1, 3, false).world
	var lid0 := _build(off, _firm(off))
	check(Transport.private_link(off, lid0).is_empty() and not off.table("transport")["links"][lid0].has("owner"), "flag off: every road is public")
	var fr := GameSim.make(1, "BALANCED", {}, true)
	(fr.world.meta["on"] as Array).append(FreightRoads.FLAG)   # FREIGHT_ROADS alone is not enough
	fr.step()
	var lid1 := _build(fr.world, _firm(fr.world))
	check(Transport.private_link(fr.world, lid1).is_empty(), "PRIVATE_ROADS is needed too")
	var w2 := _game(1, 1).world
	w2.meta["off"] = [PrivateRoads.FLAG]
	check(not PrivateRoads.on(w2), "meta.off wins")
	w2.meta["off"] = [FreightRoads.FLAG]
	check(not FreightRoads.on(w2) and not PrivateRoads.on(w2), "and for FREIGHT_ROADS too")
	var a := _game(2, 2)
	var lid := _build(a.world, _firm(a.world), {"regime": "OPEN_FREE"})
	var path := "user://test_private_roads.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var c := GameSim.for_load()
	check_eq(SaveIO.load_into(c, path), OK, "loaded")
	check_eq(var_to_str(Transport.private_link(c.world, lid)), var_to_str(Transport.private_link(a.world, lid)), "the road's record survives")
	a.step()
	c.step()
	check_eq(c.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The first two districts.
func _two(w: WorldState) -> Array:
	var ds: Array = []
	for s in ColonyLayout.settlements(w):
		if not String(s["district"]) in ds:
			ds.append(String(s["district"]))
	return [ds[0], ds[1]]


func _road_route(w: WorldState, d: Array, view: String = "") -> Dictionary:
	var a := Commuting.district_node(w, d[0])
	var b := Commuting.district_node(w, d[1])
	return Transport.route(w, String(a["id"]), String(b["id"]), "ROAD", true, view)


func test_who_may_drive_where_and_tolls_against_time() -> void:
	var w := _game().world
	var firm := _firm(w)
	var d := _two(w)
	var lid := _build(w, firm, {"kind": "PAVED", "regime": "OWNER"})
	check(not lid in _road_route(w, d)["links"], "an owner road is not on the public network")
	check(not lid in Transport.commute_d(w, d[0], d[1])["links"], "nor on the commute")
	var own := _road_route(w, d, "org:" + firm)
	check(lid in own["links"], "its owner drives on it (%s)" % str(own["links"]))
	check(not lid in _road_route(w, d, "org:" + _firm(w, firm))["links"], "another firm doesn't")
	Transport.set_terms(w, lid, "OPEN_FREE", 0, 0)
	var free := _road_route(w, d)
	check(lid in free["links"], "open and free: everyone uses it")
	check(lid in Transport.commute_d(w, d[0], d[1])["links"], "commuters too")
	Transport.set_terms(w, lid, "OPEN_TOLL", 1000000000, 0)
	check(not lid in _road_route(w, d)["links"], "a dear toll: the public goes round")
	var own2 := _road_route(w, d, "org:" + firm)
	check(lid in own2["links"], "the owner pays no toll on its own road")
	check_eq(int(own2["time_h"]), int(free["time_h"]), "the time is the real time, the toll only weighs the choice")
	Transport.set_terms(w, lid, "OPEN_TOLL", 1, 0)
	check(lid in _road_route(w, d)["links"], "a cheap toll: worth the time saved")


func test_a_firms_freight_takes_its_own_road() -> void:
	var w := _game().world
	var firm := _firm(w)
	var d := _two(w)
	var lid := _build(w, firm, {"kind": "PAVED", "regime": "OWNER"})
	w.month += 1
	Transport.step_month(w)   # the month's freight routes are fixed in NATURE
	var fr: Dictionary = w.peek("transport")["froutes"]
	check(fr.has("%s|%s" % [firm, FreightRoads._pk(d[0], d[1])]), "the firm's own route is kept: %s" % str(fr.keys()))
	check(lid in FreightRoads.route_ids(w, d[0], d[1], firm), "its freight goes on its road")
	check(not lid in FreightRoads.route_ids(w, d[0], d[1]), "nobody else's does")
	check(not lid in FreightRoads.route_ids(w, d[0], d[1], _firm(w, firm)), "not another firm's either")
	var links: Dictionary = w.table("transport")["links"]
	var t0 := int(links[lid]["traffic"])
	Transport.add_freight_traffic(w, d[0], d[1], 50000, 0, "FOOD", firm)
	check(int(links[lid]["traffic"]) > t0, "trucks on the owner's road")
	var t1 := int(links[lid]["traffic"])
	Transport.add_freight_traffic(w, d[0], d[1], 50000, 0, "FOOD")
	check_eq(int(links[lid]["traffic"]), t1, "public freight stays off it")
	check(Transport.freight_room_mu(w, d[0], d[1], firm) > 0, "room on the firm's route")


func test_the_owner_keeps_its_share_of_an_open_road() -> void:
	var w := _game().world
	var firm := _firm(w)
	var other := _firm(w, firm)
	var d := _two(w)
	var lid := _build(w, firm, {"kind": "PAVED", "regime": "OPEN_FREE", "reserved_pm": 500})
	w.month += 1
	Transport.step_month(w)
	check(lid in FreightRoads.route_ids(w, d[0], d[1]), "the open road carries public freight")
	var x := FreightRoads._item(w, lid)
	for k in ["traffic_last", "fpcu_last", "fwt_last", "frt", "fro"]:
		x[k] = 0
	var full := FreightRoads._room_mu(w, lid, firm)
	var pub := FreightRoads._room_mu(w, lid, other)
	check(full > pub and pub > 0, "the owner may use all of it, others half (%d vs %d)" % [full, pub])
	check(absi(pub * 2 - full) <= FreightRoads.UNITS_PER_TRUCK * 1000 * 2, "about half for others")
	# others fill their half: the owner's share is still there
	Transport.add_freight_traffic(w, d[0], d[1], pub, 0, "FOOD", other)
	check(FreightRoads._room_mu(w, lid, other) <= 0, "others' half is full")
	check(FreightRoads._room_mu(w, lid, firm) >= full - pub - FreightRoads.UNITS_PER_TRUCK * 1000, "the owner's half is untouched")
	# the owner going past its share eats into the others' half
	x["frt"] = 0
	x["fro"] = 0
	Transport.add_freight_traffic(w, d[0], d[1], full * 3 / 4, 0, "FOOD", firm)
	check(FreightRoads._room_mu(w, lid, other) < pub, "the owner past its share leaves others less")
	# a public road and the flag-off rule are as before
	var pubroad := String(FreightRoads.route_ids(w, d[0], d[1])[0])
	if pubroad != lid:
		check_eq(FreightRoads._room_mu(w, pubroad, firm), FreightRoads._room_mu(w, pubroad, other), "no reservations on a public road")


func test_a_firms_case_for_a_road_and_its_own_needs() -> void:
	var w := _game().world
	var firm := _firm(w)
	var d := _two(w)
	var h := w.state_hash()
	var c := Transport.private_road_case(w, firm, d[0], d[1])
	check_eq(w.state_hash(), h, "pure")
	check(bool(c["ok"]), "a case %s" % str(c.get("error", "")))
	if not bool(c["ok"]):
		return
	check(int(c["cost"]) > 0 and int(c["months"]) > 0 and int(c["km"]) > 0, "priced")
	check(bool(c["spec"]["keep_off_public"]) and c["spec"]["regime"] == "OWNER", "a ROAD project's spec")
	var lp: Dictionary = c["law_plan"]
	check(not (lp["tiles"] as Array).is_empty() and String(lp["tiles"][0]).contains(","), "tiles as land keys")
	check(d[0] in lp["districts"] and (lp["tile_district"] as Dictionary).size() == (lp["tiles"] as Array).size(), "districts crossed, by tile")
	check(lp.has("junction_over") and lp.has("essential"), "junctions and essential for the licence")
	var plan := Transport.plan_link(w, c["spec"])
	check(not Transport._runs_along(w, plan["path"]), "it never runs along a public road")
	# built from the case: the firm's road, and its own works list
	var spec: Dictionary = c["spec"].duplicate()
	var lid := Transport.complete_road(w, {"id": "proj:c", "link": spec, "owner": firm, "district": d[0]})
	check(lid != "" and String(Transport.private_link(w, lid).get("owner", "")) == firm, "built and owned")
	var l: Dictionary = w.table("transport")["links"][lid]
	l["cond"] = 300
	var needs := Transport.private_road_needs(w, firm)
	check_eq(needs.size(), 1, "one road to look after")
	if needs.size() == 1:
		check(needs[0]["why"] == "WORN" and needs[0]["key"] == "LINK:" + lid, "worn %s" % str(needs[0]["why"]))
		var fixes := (needs[0]["options"] as Array).map(func(o): return String(o["fix"]))
		check("REPAIR" in fixes and "PAVE" in fixes, "repair or upgrade on offer: %s" % str(fixes))
		check(int(needs[0]["upkeep"]) > 0, "with its upkeep")
	check(Transport.private_road_needs(w, _firm(w, firm)).is_empty(), "another firm has none")
	var off := _game(1, 2, false).world
	check(not bool(Transport.private_road_case(off, _firm(off), d[0], d[1])["ok"]), "flag off: no case")


func test_tolls_are_counted_billed_and_felt_at_home() -> void:
	var w := _game().world
	var firm := _firm(w)
	var other := _firm(w, firm)
	var d := _two(w)
	var lid := _build(w, firm, {"kind": "PAVED", "regime": "OPEN_TOLL", "toll": 10})
	w.month += 1
	Transport.step_month(w)
	check(lid in FreightRoads.route_ids(w, d[0], d[1]), "a cheap toll road carries the public freight")
	var mu := FreightRoads.UNITS_PER_TRUCK * 1000 * 2   # two loads
	Transport.add_freight_traffic(w, d[0], d[1], mu, 0, "FOOD", other)
	Transport.add_freight_traffic(w, d[0], d[1], mu, 0, "FOOD")       # the carrier's freight
	Transport.add_freight_traffic(w, d[0], d[1], mu, 0, "FOOD", firm)  # the owner pays no toll on its own road
	Transport.add_commute_traffic(w, [{"from_d": d[0], "to_d": d[1], "buses_in_service": 1, "taxi_users": 0}])
	var h := w.state_hash()
	var bill := Transport.toll_bill(w)
	check_eq(w.state_hash(), h, "the bill is pure")
	var by := {}
	for r in bill:
		if r["link"] == lid:
			by["%s|%s|%s" % [r["kind"], r["payer"], r["district"]]] = r
	check(by.has("TRUCK|%s|" % other), "the other firm pays: %s" % str(by.keys()))
	if by.has("TRUCK|%s|" % other):
		var r: Dictionary = by["TRUCK|%s|" % other]
		check(r["owner"] == firm and int(r["trips"]) == 4 and int(r["mcr"]) == 40, "two loads, there and back, 10 a trip %s" % str(r))
	check(by.has("TRUCK||"), "the carrier pays for freight without a named firm")
	check(not by.has("TRUCK|%s|" % firm), "the owner pays nothing on its own road")
	var car_key := "CAR||%s" % d[0]
	check(by.has(car_key), "commuters pay by home district")
	if by.has(car_key):
		var trips := 1 * Commuting.BUS_TRIPS_DAY * Commuting.WORK_DAYS
		check(int(by[car_key]["trips"]) == trips and int(by[car_key]["mcr"]) == trips * 10 / FreightRoads.TRUCK_PCU, "a bus pays the car toll %s" % str(by[car_key]))
	check(int(w.table("transport")["links"][lid].get("ytr", 0)) >= 8, "the road counts its truck trips")
	Transport.toll_bill_paid(w)
	check(Transport.toll_bill(w).is_empty(), "booked: the counts start again")
	check(int(Transport.commuter_tolls(w).get(d[0], 0)) > 0, "what commuters paid, by home district")
	# the public toll, on paved public roads, through the same counting
	w.levers["LAW_ROAD_TOLL"] = 5
	Transport.set_terms(w, lid, "OWNER", 0, 0)
	for x in Transport._links(w).values():
		if not PrivateRoads.is_private(x) and int(x.get("globe", 0)) == 0:
			x["kind"] = "PAVED"
	Transport._bump(w)
	w.month += 1
	Transport.step_month(w)   # the month's routes: the owner road is closed to others now
	check(not lid in FreightRoads.route_ids(w, d[0], d[1], other), "others go the public way")
	Transport.add_freight_traffic(w, d[0], d[1], mu, 0, "FOOD", other)
	var gov := Transport.toll_bill(w).filter(func(r): return r["owner"] == "gov")
	check(not gov.is_empty() and int(gov[0]["mcr"]) == int(gov[0]["trips"]) * int(PrivateRoads.TransportLaw.road_toll(w)), "the public toll on paved roads %s" % str(gov))
	# a year on: last year's truck trips
	w.month = 23
	Transport.step_month(w)
	w.month = 24
	Transport.step_month(w)
	check(Transport.truck_trips_last_year(w, lid) >= 8, "last year's truck trips (%d)" % Transport.truck_trips_last_year(w, lid))
	var off := _game(1, 2, false).world
	off.levers["LAW_ROAD_TOLL"] = 5
	Transport.add_commute_traffic(off, [{"from_d": d[0], "to_d": d[1], "buses_in_service": 1, "taxi_users": 0}])
	check(not off.peek("transport").has("tolls"), "flag off: no tolls counted")
