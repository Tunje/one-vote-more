extends TestCase
## Terra (user's go via Wilma 2026-11-15): private roads, flag PRIVATE_ROADS on FREIGHT_ROADS
## (sim/transport/private_roads.gd). Step 1: ownership, terms, changes of hands, kept out of the government's works.


func _game(seed_v: int = 1, months: int = 3, on: bool = true) -> Simulation:
	var sim := EconSim.make(seed_v, "BALANCED", {}, true)
	if on:
		(sim.world.meta["on"] as Array).append_array([FreightRoads.FLAG, PrivateRoads.FLAG])
	for _m in months:
		sim.step()
	return sim


## A company (any org that is not the government).
func _firm(w: WorldState, skip: String = "") -> String:
	for oid in EconUtil.sorted_keys(w.peek("org")):
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
	var fr := EconSim.make(1, "BALANCED", {}, true)
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
	var c := EconSim.for_load()
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
