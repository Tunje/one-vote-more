extends TestCase
## Terra: the transport network (A43 T1/T7, sim/transport/transport.gd).


func _game(seed_v: int = 1) -> Simulation:
	return EconSim.make(seed_v, "BALANCED", {}, true)


func _site(w: WorldState, kind: String) -> Dictionary:
	for s in PlanetSites.sites(w):
		if s["kind"] == kind:
			return s
	return {}


func _storm_over_colony(w: WorldState, strength: int) -> void:
	w.table("planet")["storms"] = [{"id": "test", "kind": "RAIN_FRONT", "strength": strength, "cells": [Planet.landing(w)], "global": false}]


func test_founding_network_joins_the_settlements_and_reading_is_pure() -> void:
	for seed_v in [1, 2, 7]:
		var w := _game(seed_v).world
		var h := w.state_hash()
		var net := Transport.network(w)
		check_eq(w.state_hash(), h, "reading the network changes nothing (seed %d)" % seed_v)
		var setl := ColonyLayout.settlements(w)
		check(net["links"].size() >= setl.size() - 1, "tracks join the settlements (%d links)" % net["links"].size())
		for l in net["links"]:
			check_eq(l["kind"], "TRACK", "the founders built tracks only")
			check(l["path"].size() >= 2 and int(l["km"]) > 0, "a track has a path")
		for s in setl:
			var r := Transport.route(w, "port", s["id"], "ROAD")
			check(r["ok"], "seed %d: %s is on the network (%s)" % [seed_v, s["name"], r["reason"]])
			check(int(r["time_h"]) >= 0 and int(r["cost_index"]) >= 0, "a trip has a time and a cost")
		for n in net["nodes"]:
			if n["kind"] == "PLANT":
				check(Transport.route(w, "port", n["id"], "ROAD")["ok"], "founding plant %s is reachable" % n["id"])
		for x in Transport.reachable_sites(w):
			if x["where"] != "COLONY":
				check_eq(x["mode"], "UNREACHABLE", "seed %d: %s needs a road, rovers or an airship" % [seed_v, x["name"]])


func test_nothing_is_reachable_for_free() -> void:
	var w := _game(1).world
	var off := {}
	for x in Transport.reachable_sites(w):
		if x["mode"] == "UNREACHABLE":
			off[x["id"]] = x
	check(off.size() >= 10, "most sites start unreachable (%d)" % off.size())
	# a rover base at the port: colony sites and nearby land sites open to rover tours; far ones still need airships
	Transport.add_base(w, "ROVER_BASE", Transport.tile_int(Terrain.landing(w)), "test")
	var by_rover := 0
	for x in Transport.reachable_sites(w):
		if x["mode"] == "ROVER":
			by_rover += 1
			check(off.has(x["id"]) and x["where"] != "GLOBE", "rovers open off-road sites nearby (%s)" % x["name"])
	check(by_rover >= 1, "rovers reach some sites")
	var far := _site(w, "AURORA_PLAIN")
	check_eq(Transport.route(w, "port", far["id"], "BEST")["ok"], false, "a far site needs an airship")
	Transport.add_base(w, "MAST", Transport.tile_int(Terrain.landing(w)), "test")
	var air := Transport.route(w, "port", far["id"], "BEST")
	check(air["ok"] and air["mode"] == "AIRSHIP" and int(air["time_days"]) >= 1, "an airship flies there: %s" % str(air))
	_storm_over_colony(w, 3)
	check_eq(Transport.route(w, "port", far["id"], "AIRSHIP")["reason"], "GROUNDED", "storms ground airships")
	check(Transport.route(w, "port", far["id"], "AIRSHIP", true)["ok"], "in fair weather it flies")


func test_storms_and_mud_close_tracks_not_paved_roads() -> void:
	var w := _game(1).world
	var d: String = ColonyLayout.settlements(w)[-1]["id"]
	check(Transport.route(w, "port", d, "ROAD")["ok"], "open in fair weather")
	_storm_over_colony(w, 2)
	check(not Transport.closures(w).is_empty(), "a storm closes tracks")
	var r := Transport.route(w, "port", d, "ROAD")
	if r["ok"]:
		check(r["links"].is_empty(), "only streets stay open")
	else:
		check_eq(r["reason"], "CLOSED", "closed, not missing")
	Transport.ensure(w)
	for lid in w.table("transport")["links"]:
		w.table("transport")["links"][lid]["kind"] = "PAVED"
	Transport._bump(w)
	check(Transport.closures(w).is_empty(), "paved roads stay open")
	check(Transport.route(w, "port", d, "ROAD")["ok"], "the trip works on paved roads")


func test_road_projects_build_upgrade_and_engineer() -> void:
	var w := _game(1).world
	var meadow := _site(w, "GLOW_MEADOW")
	check_eq(Transport.route(w, "port", meadow["id"], "ROAD")["ok"], false, "the meadow starts off the network")
	Transport.ensure(w)
	var near := Transport._nearest_link_tile(w, w.table("transport")["links"], meadow["tile"])
	var spec := {"a": Transport.tile_int(near), "b": Transport.tile_int(meadow["tile"]), "kind": "TRACK"}
	var plan := Transport.plan_link(w, spec)
	check(plan["ok"] and int(plan["wu"]) > 0 and int(plan["cost"]) > 0 and int(plan["months"]) >= 2, "a track has a bill: %s" % str(plan))
	check_eq(var_to_str(plan), var_to_str(Transport.plan_link(w, spec)), "planning is deterministic")
	check(Transport.validate_link(w, {"a": 0, "b": 0, "kind": "ROAD"}) != "", "a readable reason for a bad link")
	check(Transport.validate_link(w, {"a": 0, "b": 70, "kind": "HIGHWAY"}) != "", "unknown kinds are refused")
	var lid := Transport.complete_road(w, {"id": "p1", "type": "ROAD", "district": "d:1", "owner": "gov", "link": spec})
	check(lid != "", "the project builds a link")
	check(Transport.route(w, "port", meadow["id"], "ROAD")["ok"], "the meadow is now reachable by road")
	check(w.facts.query("TRANSPORT_LINK_OPENED").size() == 1, "a link-opened fact")
	# upgrades: kind, lanes, bridge, junction
	var cap0 := Transport.link_capacity(w.table("transport")["links"][lid])
	check(Transport.validate_link(w, {"lanes": lid}) != "", "no second lane on a dirt track")
	Transport.complete_road(w, {"id": "p2", "type": "ROAD", "district": "d:1", "owner": "gov", "link": {"upgrade": lid}})
	check_eq(w.table("transport")["links"][lid]["kind"], "ROAD", "track → road")
	Transport.complete_road(w, {"id": "p3", "type": "ROAD", "district": "d:1", "owner": "gov", "link": {"lanes": lid}})
	var l: Dictionary = w.table("transport")["links"][lid]
	check_eq(int(l["lanes"]), 2, "a second lane")
	if int(l["bridges"]) > 0:
		check_eq(Transport.link_capacity(l), int(Transport.CAPACITY["ROAD"]), "one bridge holds the two lanes back")
		Transport.complete_road(w, {"id": "p4", "type": "ROAD", "district": "d:1", "owner": "gov", "link": {"bridge": lid}})
	check(Transport.link_capacity(w.table("transport")["links"][lid]) > cap0, "capacity grows with kind and lanes")
	var js := Transport.junctions(w)
	check(not js.is_empty(), "links meet at junctions")
	var jid: String = EconUtil.sorted_keys(js)[0]
	var jcap := Transport.junction_capacity(w, js[jid])
	check_eq(Transport.complete_road(w, {"id": "p5", "type": "ROAD", "district": "d:1", "owner": "gov", "link": {"junction": jid, "type": "ROUNDABOUT"}}), jid, "a junction rebuilt")
	check_eq(Transport.junctions(w)[jid]["type"], "ROUNDABOUT", "now a roundabout")
	check(Transport.junction_capacity(w, Transport.junctions(w)[jid]) > jcap, "roundabouts carry more")
	# a road to a region site (a large project) opens it to coaches
	for st in PlanetSites.sites(w):
		if st["where"] == "REGION" and Transport.plan_link(w, {"site": st["id"], "kind": "TRACK"})["ok"]:
			Transport.complete_road(w, {"id": "p6", "type": "ROAD", "district": "d:1", "owner": "gov", "link": {"site": st["id"], "kind": "TRACK"}})
			var r := Transport.route(w, "port", st["id"], "ROAD", true)
			check(r["ok"] and int(r["km"]) >= 200, "a road through the wild to %s (%s)" % [st["name"], str(r)])
			break
	# T7: the fixes on offer (Anni's engineers) are orderable ROAD projects
	var fixes := Transport.traffic_fixes(w)
	var kinds := {}
	for key in fixes:
		check(String(key).begins_with("LINK:") or String(key).begins_with("NODE:"), "keys like the traffic counts: %s" % key)
		for o in fixes[key]["options"]:
			kinds[o["fix"]] = true
			check(int(o["cost"]) > 0 and int(o["months"]) >= 2 and int(o["cap_pm"]) > 0 and int(o["acc_pm"]) > 0, "a priced fix %s" % str(o))
			check_eq(Transport.validate_link(w, o["spec"]), "", "%s %s can be ordered" % [key, o["fix"]])
	check(kinds.has("ROAD") and (kinds.has("PRIORITY") or kinds.has("SIGNALS")), "tracks can become roads, junctions be rebuilt (%s)" % str(kinds.keys()))
	var fkey: String = EconUtil.sorted_keys(fixes)[0]
	var fopt: Dictionary = fixes[fkey]["options"][0]
	check(Transport.complete_road(w, {"id": "p8", "type": "ROAD", "district": "d:1", "owner": "gov", "link": Transport.fix_spec(w, fkey, fopt["fix"])}) != "", "ordering a fix builds it")
	# district roads without a spec still do something useful
	check(not Transport.auto_job(w, "d:3").is_empty(), "GovBuilder's district road finds a job")
	check(Transport.complete_road(w, {"id": "p7", "type": "ROAD", "district": "d:3", "owner": "gov"}) != "", "and does it")


func test_wear_and_save_load_in_the_game() -> void:
	var a := _game(2)
	for _m in 14:
		a.step()
	var t: Dictionary = a.world.peek("transport")
	check(t.has("links"), "the first NATURE tick writes the network")
	var worn := false
	for lid in t["links"]:
		worn = worn or int(t["links"][lid]["cond"]) < 1000
		for k in t["links"][lid]:
			check(typeof(t["links"][lid][k]) != TYPE_FLOAT, "integer state (%s.%s)" % [lid, k])
	check(worn, "links wear")
	var path := "user://test_transport.sav"
	check_eq(SaveIO.save(a, path), OK, "saved")
	var b := EconSim.for_load()
	check_eq(SaveIO.load_into(b, path), OK, "loaded")
	check_eq(var_to_str(b.world.peek("transport")), var_to_str(t), "the network survives save/load")
	a.step()
	b.step()
	check_eq(b.world.state_hash(), a.world.state_hash(), "save/load/continue stays identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
