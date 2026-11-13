class_name Commuting
extends RefCounted
## Terra (T3 + §8c of planning/plan-support-economy.md, agreed with Bob 2026-11-13): the network side of commuting.
## Bob's econ step decides IF buses break down or crash and how many people commute; this file says WHO goes from
## where to where (commutes), HOW the trip is (commute_d, route_factor), WHERE an incident happens (incident_site),
## the bus LINES to draw (bus_lines, derived from Bob's EconQuery.commuting rows) and the vehicle trips the
## commuters put on the roads (add_commute_traffic, the only write). Called through Transport (same names).
## Districts are "d:N". Home → work is district level today (the staff keys carry the home block "hb:d:N"); an area
## level call can take area ids later with the same shapes.

## Route factor ‰ by road kind (1000 = a good road), and at a junction passed by type.
const KIND_F := {"TRACK": 1300, "ROAD": 1000, "PAVED": 850, "STREET": 1000}
const JUNCTION_F := {"CROSSING": 1100, "PRIORITY": 1050, "ROUNDABOUT": 950, "SIGNALS": 900}
const JUNCTION_KM := 3          # a junction weighs like this many km of road in the route's average
const CLOSED_F := 2500          # a link closed by this month's weather (storm, mud)
const NO_ROAD_F := 3000         # no road between the two: cross-country
const CROSS_COUNTRY_KMH := 15   # minutes for a trip without a road
## Vehicle trips a month on the roads: a bus in service makes this many one-way trips a working day; a taxi carries
## 1.5 users and makes 2 trips a working day.
const BUS_TRIPS_DAY := 4
const TAXI_TRIPS_DAY := 2
const WORK_DAYS := 22


## Who works where: [{from_d (home district), to_d (work district), n (persons), fid (facility or builder org)}],
## from facility staff and builder crews (milli-persons ÷ 1000, rounded per row). Sorted by fid, then from_d.
static func commutes(world: WorldState) -> Array:
	var acc := {}
	var fac: Dictionary = world.peek("facility")
	for fid in EconUtil.sorted_keys(fac):
		var f: Dictionary = fac[fid]
		_add_staff(acc, f.get("staff", {}), String(fid), String(f.get("district", "")))
	var orgs: Dictionary = world.peek("org")
	for oid in EconUtil.sorted_keys(orgs):
		var o: Dictionary = orgs[oid]
		if o.has("crew"):
			_add_staff(acc, o["crew"], String(oid), String(o.get("hq", "")))
	var out: Array = []
	for k in EconUtil.sorted_keys(acc):
		var p := String(k).split("#")
		var n := (int(acc[k]) + EconUtil.S / 2) / EconUtil.S
		if n > 0:
			out.append({"from_d": p[1], "to_d": p[2], "n": n, "fid": p[0]})
	return out


static func _add_staff(acc: Dictionary, staff: Dictionary, fid: String, to_d: String) -> void:
	for t in staff:
		var row: Dictionary = staff[t]
		for key in row:
			var hb := String(key).split("|")[0]
			if not hb.begins_with("hb:"):
				continue
			var k := "%s#%s#%s" % [fid, EconPop.district_of(hb), to_d]
			acc[k] = int(acc.get(k, 0)) + int(row[key])


## The settlement node of a district (its own settlement, else the first area settlement in it). {} if none.
static func district_node(world: WorldState, d: String) -> Dictionary:
	var best := {}
	for s in ColonyLayout.settlements(world):
		if String(s["district"]) != d:
			continue
		if String(s["id"]) == d:
			return Transport.node(world, d)
		if best.is_empty():
			best = Transport.node(world, String(s["id"]))
	return best


## The commute between two districts: {ok (a road exists), hops (links on the route; 0 within a district), km,
## minutes, links: [lid], factor ‰ (route_factor)}. Without a road: cross-country (ok false, factor NO_ROAD_F).
## Peek-only. The route (hops, km, minutes, links) is memoised across months while the network's shape
## (Transport._struct_sig, worn-down kinds included) and the colony layout stay the same (Bob/Wilma 2026-11-13:
## commuting asks every month); the factor (condition, traffic, this month's closures) is worked out on each call.
static func commute_d(world: WorldState, from_d: String, to_d: String) -> Dictionary:
	var r: Dictionary = Transport._memoised(world, "commute|%s|%s" % [from_d, to_d], func(): return _commute_d(world, from_d, to_d), false)
	var out := r.duplicate()
	if r["ok"] and not (r["links"] as Array).is_empty():
		out["factor"] = _factor(world, {"links": r["links"]})
	return out


static func _commute_d(world: WorldState, from_d: String, to_d: String) -> Dictionary:
	if from_d == to_d:
		return {"ok": true, "hops": 0, "km": 0, "minutes": 0, "links": [], "factor": 1000}
	var a := district_node(world, from_d)
	var b := district_node(world, to_d)
	if a.is_empty() or b.is_empty():
		return {"ok": false, "hops": 0, "km": 0, "minutes": 0, "links": [], "factor": NO_ROAD_F}
	var r := Transport.route(world, String(a["id"]), String(b["id"]), "ROAD", true)
	if not r["ok"]:
		var km := roundi(Vector2(Transport.int_tile(int(a["tile"]))).distance_to(Vector2(Transport.int_tile(int(b["tile"])))) * Transport.KM_PER_TILE * 1.3)
		return {"ok": false, "hops": maxi(1, ceili(float(km) / 40.0)), "km": km, "minutes": km * 60 / CROSS_COUNTRY_KMH,
			"links": [], "factor": NO_ROAD_F}
	var links: Array = r["links"]
	return {"ok": true, "hops": maxi(1, links.size()), "km": int(r["km"]), "minutes": int(r["time_h"]) * 60,
		"links": links, "factor": _factor(world, r)}


## Road condition / traffic factor ‰ between two districts (1000 = a good road, normal traffic; higher is worse):
## each link by km — condition, kind, congestion above 80% of capacity, a second lane, this month's closures — and
## each junction passed (weighted as JUNCTION_KM km) by type. No road: NO_ROAD_F.
static func route_factor(world: WorldState, from_d: String, to_d: String) -> int:
	return int(commute_d(world, from_d, to_d)["factor"])


## Factor ‰ of one link this month.
static func link_factor(world: WorldState, l: Dictionary) -> int:
	if Transport.closed_reason(world, l) != "":
		return CLOSED_F
	var f := 1000.0 * (1.0 + 0.8 * float(1000 - clampi(int(l["cond"]), 0, 1000)) / 1000.0)
	f *= float(KIND_F.get(Transport.effective_kind(l), 1000)) / 1000.0
	var cap := maxi(1, Transport.link_capacity(l))
	var traffic := maxi(int(l.get("traffic", 0)), int(l.get("traffic_last", 0)))   # this month so far, or last month's
	f *= 1.0 + 2.0 * maxf(0.0, float(traffic) / float(cap) - 0.8)
	if int(l.get("lanes", 1)) >= 2:
		f *= 0.9
	return roundi(f)


static func _factor(world: WorldState, r: Dictionary) -> int:
	var links := Transport._links(world)
	var sum := 0.0
	var w := 0.0
	for lid in r["links"]:
		if not links.has(lid):
			continue
		var km := float(maxi(1, Transport.link_km(links[lid])))
		sum += km * float(link_factor(world, links[lid]))
		w += km
	var jt := Transport.junctions(world)
	for jid in Transport.route_junctions(world, r):
		sum += float(JUNCTION_KM) * float(JUNCTION_F.get(String(jt[jid]["type"]), 1000))
		w += float(JUNCTION_KM)
	return roundi(sum / w) if w > 0.0 else 1000


## Where on the commute between two districts an incident happens (Bob's draw decides that it happens; `salt` is
## from his RNG). kind "BREAKDOWN": anywhere, weighted by km; "CRASH": weighted by each link's factor × km and each
## junction's risk. → {link, junction ("" unless at a junction), tile (y*W+x)}. Peek-only, deterministic.
static func incident_site(world: WorldState, from_d: String, to_d: String, salt: int, kind: String = "BREAKDOWN") -> Dictionary:
	var cd := commute_d(world, from_d, to_d)
	var a := district_node(world, from_d)
	var b := district_node(world, to_d)
	var u := Planet._mix(salt, 0x5173)
	if cd["links"].is_empty():   # within a town or cross-country: between the two settlements
		var ta := Transport.int_tile(int(a.get("tile", 0))) if not a.is_empty() else Terrain.landing(world)
		var tb := Transport.int_tile(int(b.get("tile", 0))) if not b.is_empty() else ta
		var t := Vector2(ta).lerp(Vector2(tb), float(u % 1000) / 1000.0)
		return {"link": "", "junction": "", "tile": Transport.tile_int(Vector2i(roundi(t.x), roundi(t.y)))}
	var links := Transport._links(world)
	var cands: Array = []   # [weight, link, junction]
	for lid in cd["links"]:
		if not links.has(lid) or int(links[lid].get("globe", 0)) == 1:
			continue
		var km := maxi(1, Transport.link_km(links[lid]))
		cands.append([km * (link_factor(world, links[lid]) if kind == "CRASH" else 1000), String(lid), ""])
	if kind == "CRASH":
		var jt := Transport.junctions(world)
		var r := {"links": cd["links"]}
		for jid in Transport.route_junctions(world, r):
			cands.append([JUNCTION_KM * int(Transport.JUNCTION_RISK[String(jt[jid]["type"])]) * 10, "", String(jid)])
	var total := 0
	for c in cands:
		total += int(c[0])
	var pick := u % maxi(1, total)
	for c in cands:
		pick -= int(c[0])
		if pick < 0:
			if String(c[2]) != "":
				return {"link": "", "junction": c[2], "tile": int(Transport.junctions(world)[c[2]]["tile"])}
			var path: Array = links[c[1]]["path"]
			return {"link": c[1], "junction": "", "tile": int(path[Planet._mix(salt, 0x7a11) % path.size()])}
	return {"link": "", "junction": "", "tile": Transport.tile_int(Terrain.landing(world))}


## Bus lines to draw, from Bob's EconQuery.commuting rows ({from_d, to_d, bus_commuters, buses_in_service, seats,
## load_pm, breakdowns_m, crashes_m, ...}): one line per pair of districts (both directions together) over the road
## route. → [{id, a, b, links, stops: [tiles], depot (tile of the nearest DEPOT, -1 if none), commuters, buses,
## seats, load_pm (the fuller direction), breakdowns_m, crashes_m, path (route tiles in order from the first stop),
## bus_tiles (display placement, see _place)}]. The incident marks are incident_marks (Bob's facts). Pairs within one district have no line.
static func bus_lines(world: WorldState, pairs: Array) -> Array:
	var by := {}
	for p in pairs:
		var fa := String(p.get("from_d", ""))
		var fb := String(p.get("to_d", ""))
		if fa == fb or fa == "" or fb == "" or int(p.get("buses_in_service", 0)) + int(p.get("bus_commuters", 0)) <= 0:
			continue
		var a := fa if fa < fb else fb
		var b := fb if fa < fb else fa
		var k := a + "~" + b
		if not by.has(k):
			by[k] = {"id": "bus:%s~%s" % [a, b], "a": a, "b": b, "commuters": 0, "buses": 0, "seats": 0, "load_pm": 0,
				"breakdowns_m": 0, "crashes_m": 0}
		var ln: Dictionary = by[k]
		ln["commuters"] = int(ln["commuters"]) + int(p.get("bus_commuters", 0))
		ln["buses"] = int(ln["buses"]) + int(p.get("buses_in_service", 0))
		ln["seats"] = int(ln["seats"]) + int(p.get("seats", 0))
		ln["load_pm"] = maxi(int(ln["load_pm"]), int(p.get("load_pm", 0)))
		ln["breakdowns_m"] = int(ln["breakdowns_m"]) + int(p.get("breakdowns_m", 0))
		ln["crashes_m"] = int(ln["crashes_m"]) + int(p.get("crashes_m", 0))
	var depots: Array = []
	var ft := ColonyLayout.facility_tiles(world)
	var fac: Dictionary = world.peek("facility")
	for fid in EconUtil.sorted_keys(ft):
		if String(fac.get(fid, {}).get("type", "")) == "DEPOT":
			depots.append(ft[fid])
	var out: Array = []
	for k2 in EconUtil.sorted_keys(by):
		var ln2: Dictionary = by[k2]
		var cd := commute_d(world, ln2["a"], ln2["b"])
		ln2["links"] = cd["links"]
		var stops: Array = []
		for d in [ln2["a"], ln2["b"]]:
			var nd := district_node(world, d)
			if not nd.is_empty():
				stops.append(int(nd["tile"]))
		var jt := Transport.junctions(world)
		for jid in Transport.route_junctions(world, {"links": cd["links"]}):
			stops.append(int(jt[jid]["tile"]))
		ln2["stops"] = stops
		var dep := -1
		var bd := INF
		for t in depots:
			for s in stops.slice(0, 1):
				var dd := Vector2(t).distance_to(Vector2(Transport.int_tile(int(s))))
				if dd < bd:
					bd = dd
					dep = Transport.tile_int(t)
		ln2["depot"] = dep
		ln2["path"] = route_path(world, cd["links"], stops[0] if not stops.is_empty() else -1)
		_place(world, ln2)
		out.append(ln2)
	return out


## The road route's tiles in order from `start` (the first stop): each link turned to continue where the last ended.
static func route_path(world: WorldState, lids: Array, start: int) -> Array:
	var links := Transport._links(world)
	var out: Array = []
	var at := start
	for lid in lids:
		if not links.has(lid):
			continue
		var p: Array = (links[lid]["path"] as Array).duplicate()
		if p.is_empty():
			continue
		var tail := at
		if not out.is_empty():
			tail = int(out[out.size() - 1])
		if tail >= 0:
			var tv := Vector2(Transport.int_tile(tail))
			if tv.distance_to(Vector2(Transport.int_tile(int(p[p.size() - 1])))) < tv.distance_to(Vector2(Transport.int_tile(int(p[0])))):
				p.reverse()
		for ti in p:
			if out.is_empty() or int(out[out.size() - 1]) != int(ti):
				out.append(int(ti))
	return out


const SHOW_BUSES := 12      # buses drawn on a line at most (one mark each)

## Display only (pure, no RNG stream): where this month's buses are along the line ("bus_tiles").
static func _place(world: WorldState, ln: Dictionary) -> void:
	var path: Array = ln["path"]
	var h := String(ln["id"]).hash()
	var buses: Array = []
	if path.size() >= 2:
		var n := mini(int(ln["buses"]), SHOW_BUSES)
		for i in n:   # spread along the line, shifted a little each month
			var f := (float(i) + float(Planet._mix(world.month * 131 + i, h) % 1000) / 1000.0) / float(maxi(1, n))
			buses.append(int(path[clampi(roundi(f * float(path.size() - 1)), 0, path.size() - 1)]))
	ln["bus_tiles"] = buses


## The marks of last month's bus breakdowns and crashes, from Bob's BUS_BREAKDOWN / BUS_CRASH facts (§8c, opt-in
## FLEET; he places them with incident_site): [{kind (BREAKDOWN | CRASH), tile, link, month, fact}], those with a
## tile on the map, in fact order. Pure read.
static func incident_marks(world: WorldState) -> Array:
	var out: Array = []
	for kind in ["BREAKDOWN", "CRASH"]:
		for f in world.facts.query("BUS_" + kind, world.month - 1):
			var d: Dictionary = f.get("data", {})
			if int(d.get("tile", -1)) >= 0:
				out.append({"kind": kind, "tile": int(d["tile"]), "link": String(d.get("link", "")), "month": int(f.get("month", world.month)),
					"fact": String(f.get("id", ""))})
	return out


## The only write: the commuters' vehicle trips this month go onto the roads (T7 counts, congestion, wear). Bob calls
## it once a month after his commuting step with the same rows as bus_lines: buses_in_service × BUS_TRIPS_DAY and
## taxis (taxi_users / 1.5) × TAXI_TRIPS_DAY, over WORK_DAYS, on every link and junction of the pair's road route.
static func add_commute_traffic(world: WorldState, pairs: Array) -> void:
	for p in pairs:
		var fa := String(p.get("from_d", ""))
		var fb := String(p.get("to_d", ""))
		if fa == fb:
			continue
		var trips := int(p.get("buses_in_service", 0)) * BUS_TRIPS_DAY * WORK_DAYS
		trips += ceili(float(int(p.get("taxi_users", 0))) / 1.5) * TAXI_TRIPS_DAY * WORK_DAYS
		if trips <= 0:
			continue
		var cd := commute_d(world, fa, fb)
		for lid in cd["links"]:
			Transport.add_traffic(world, String(lid), trips)
		for jid in Transport.route_junctions(world, {"links": cd["links"]}):
			Transport.add_traffic(world, String(jid), trips)
