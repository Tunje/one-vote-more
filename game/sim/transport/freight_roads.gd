class_name FreightRoads
extends RefCounted
## Terra (user via Wilma 2026-11-15: "Next thing you're going to run into is roads, they won't be able to take the new
## freight." / "also road expansions, not just quality"). Flag FREIGHT_ROADS (opt-in): freight between districts drives
## on the colony's roads as trucks, the roads limit what gets through, and road_needs sees it coming.
##
## Bob's market (per trade, or per pair summed; agreed with Bob 2026-11-15):
##   freight_room_mu(from_d, to_d)   milli-units the road route can still take this month (BIG when unlimited)
##   add_freight_traffic(from_d, to_d, moved_mu, held_mu, good)   the only write: trucks onto every link and
##                                   junction of the route; held_mu = what the roads held back (it waits, as
##                                   freight_deferred); good (optional) names what was held, for road_needs' benefit
##   deliverable_pm(from_d, to_d)    0..1000: last month's moved / (moved + held) for the pair; when nothing was held,
##                                   the route's headroom (capacity × JAM_ALLOW ÷ last month's load, at most 1000)
##   district_jam_pm(d)              worst last-month load ‰ (1000 = at capacity) of the freight roads in district d
## Trucks: ceil(mu / (UNITS_PER_TRUCK × 1000)) × 2 (the empty return) × TRUCK_PCU car-equivalents, counted in the
## link's traffic (wear, commuters' route factor, road_needs).
## The allowance, per link or junction: up to capacity × JAM_ALLOW_PM ‰ freight takes what the commuters leave; past
## that, trucks and commuters share the jam in proportion to last month's demand (freight wanted, at least a quarter of
## the allowance, against commuters). It runs down within the month as freight moves (like the depots' freight_cap /
## freight_used), so it cannot oscillate.
## The month's freight routes and capacities are fixed in the NATURE tick and saved (a link finished during the month
## carries freight from the next): queries in the market loop read only the table, so they are pure and cheap.
## State (only with the flag): per colony link and junction "frt"/"fwt" (mu moved / wanted this month), "fpcu_last"/
## "fwt_last" (car-equivalents last month), "fcap" (this month's capacity), the yearly trend "ys"/"yn" (this year's
## traffic sum and months), "yl"/"yp" (last year's and the year before's monthly mean; -1 = not yet); transport
## "froutes" {"a|b" (a < b): [link and junction ids]} and "froutes_last" (last month's), "fjam" {d: ‰},
## "fpairs"/"fpairs_last" {"a>b": [moved_mu, held_mu]}, "fheld"/"fheld_last" {"a>b": {good ("?" unnamed): held_mu}},
## "jams" {d: 1}.

const FLAG := "FREIGHT_ROADS"
const UNITS_PER_TRUCK := 25
const TRUCK_PCU := 2
const JAM_ALLOW_PM := 1250        # roads take this ‰ of their capacity before traffic must wait (slow, but moving)
const BIG := 1 << 40
const JAM_FACT_PM := 200          # a district's freight is jammed when the roads held back this ‰ of it
const JAM_CLEAR_PM := 50
## A new link between two districts is on offer when the road route is this ‰ of the straight line or longer ...
const DETOUR_PM := 1600
## ... and the new link would save at least this ‰ of the route's km.
const DETOUR_SAVE_PM := 300
const DETOUR_MIN_KM := 12


static func on(world: WorldState) -> bool:   # meta.off wins (the standing rule)
	return (world.meta.get("on", []) as Array).has(FLAG) and not (world.meta.get("off", []) as Array).has(FLAG)


## Car-equivalents of mu milli-units of freight a month on one road (out loaded, back empty).
static func trucks_pcu(mu: int) -> int:
	if mu <= 0:
		return 0
	return ceili(float(mu) / float(UNITS_PER_TRUCK * 1000)) * 2 * TRUCK_PCU


## The road route between two districts: {links: [lid], juncs: [jid]} ({} for none). Monthly memo. org
## (PRIVATE_ROADS): that firm's view (the public network plus its own private roads).
static func route_items(world: WorldState, from_d: String, to_d: String, org: String = "") -> Dictionary:
	if from_d == to_d:
		return {}
	return Transport._memoised(world, "froute|%s|%s|%s" % [from_d, to_d, org], func():
		var lids: Array = []
		if org == "":
			var cd := Transport.commute_d(world, from_d, to_d)
			if not bool(cd["ok"]):
				return {}
			lids = cd["links"]
		else:
			var a := Commuting.district_node(world, from_d)
			var b := Commuting.district_node(world, to_d)
			if a.is_empty() or b.is_empty():
				return {}
			var r := Transport.route(world, String(a["id"]), String(b["id"]), "ROAD", true, "org:" + org)
			if not bool(r["ok"]):
				return {}
			lids = r["links"]
		if lids.is_empty():
			return {}
		return {"links": lids.duplicate(), "juncs": Transport.route_junctions(world, {"links": lids})})


static func _pk(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## This month's freight route between two districts: link and junction ids ([] for none). From the table once the
## NATURE tick has fixed it, else computed. org (PRIVATE_ROADS): that firm's route where its own roads change it.
static func route_ids(world: WorldState, from_d: String, to_d: String, org: String = "") -> Array:
	if from_d == to_d:
		return []
	var t := world.peek("transport")
	if t.has("froutes"):
		if org != "" and t["froutes"].has("%s|%s" % [org, _pk(from_d, to_d)]):
			return t["froutes"]["%s|%s" % [org, _pk(from_d, to_d)]]
		return t["froutes"].get(_pk(from_d, to_d), [])
	var r := route_items(world, from_d, to_d, org if PrivateRoads.on(world) else "")
	return [] if r.is_empty() else r["links"] + r["juncs"]


## Capacity of every colony link and junction now {id: trips}. Monthly memo.
static func capacities(world: WorldState) -> Dictionary:
	return Transport._memoised(world, "fcaps", func():
		var out := {}
		var links := Transport._links(world)
		for lid in links:
			if int(links[lid].get("globe", 0)) == 0:
				out[lid] = Transport.link_capacity(links[lid], world)
		var jt := Transport.junctions(world)
		for jid in jt:
			out[jid] = Transport.junction_capacity(world, jt[jid])
		return out)


static func _item(world: WorldState, id: String) -> Dictionary:
	var t := world.peek("transport")
	if t.get("links", {}).has(id):
		return t["links"][id]
	return t.get("junctions", {}).get(id, {})


static func _cap(world: WorldState, id: String, x: Dictionary) -> int:
	if x.has("fcap"):
		return int(x["fcap"])
	return int(capacities(world).get(id, 1))


## Milli-units one link or junction can still take this month.
## PRIVATE_ROADS: on an open private road with a reserved share, the owner's freight (org = owner) may use its share
## first and whatever is left beyond it; everyone else shares the rest (less what the owner took beyond its share).
static func _room_mu(world: WorldState, id: String, org: String = "") -> int:
	var x := _item(world, id)
	if x.is_empty():
		return BIG
	var allow := _cap(world, id, x) * JAM_ALLOW_PM / 1000
	var res := 0
	var owner := ""
	if PrivateRoads.is_private(x) and String(x.get("regime", "")) != "OWNER" and PrivateRoads.on(world):
		res = clampi(int(x.get("reserved_pm", 0)), 0, 1000)
		owner = String(x["owner"])
	if res <= 0:
		return maxi(0, _mu_of(_share(x, allow)) - int(x.get("frt", 0)))
	var res_mu := _mu_of(allow * res / 1000)
	var own := int(x.get("fro", 0))
	if org == owner:
		return maxi(maxi(0, res_mu - own), _mu_of(_share(x, allow)) - int(x.get("frt", 0)))
	var others := int(x.get("frt", 0)) - own + maxi(0, own - res_mu)
	return maxi(0, _mu_of(_share(x, allow * (1000 - res) / 1000)) - others)


## Car-equivalents freight may use of an allowance: what the commuters leave, or past a jam a share by demand.
static func _share(x: Dictionary, allow: int) -> int:
	var commuters := maxi(0, int(x.get("traffic_last", 0)) - int(x.get("fpcu_last", 0)))
	var want := maxi(int(x.get("fwt_last", 0)), allow / 4)
	var room := allow - commuters
	if commuters + want > allow:   # a jam: trucks and commuters share it by demand
		room = maxi(room, allow * want / maxi(1, commuters + want))
	return maxi(0, room)


## Milli-units a number of car-equivalents carries (whole trucks there and back).
static func _mu_of(pcu: int) -> int:
	return maxi(0, pcu) / (2 * TRUCK_PCU) * UNITS_PER_TRUCK * 1000


static func freight_room_mu(world: WorldState, from_d: String, to_d: String, org: String = "") -> int:
	if not on(world) or from_d == to_d:
		return BIG
	var ids := route_ids(world, from_d, to_d, org)
	if ids.is_empty():
		return BIG
	var room := BIG
	for id in ids:
		room = mini(room, _room_mu(world, String(id), org))
	return room


static func add_freight_traffic(world: WorldState, from_d: String, to_d: String, moved_mu: int, held_mu: int = 0, good: String = "", org: String = "") -> void:
	if not on(world) or from_d == to_d or (moved_mu <= 0 and held_mu <= 0):
		return
	Transport.ensure(world)
	var t := world.table("transport")
	if not t.has("fpairs"):
		t["fpairs"] = {}
	var k := "%s>%s" % [from_d, to_d]
	var p: Array = t["fpairs"].get(k, [0, 0])
	moved_mu = maxi(0, moved_mu)
	held_mu = maxi(0, held_mu)
	t["fpairs"][k] = [int(p[0]) + moved_mu, int(p[1]) + held_mu]
	if held_mu > 0:
		if not t.has("fheld"):
			t["fheld"] = {}
		if not t["fheld"].has(k):
			t["fheld"][k] = {}
		var g := good if good != "" else "?"
		t["fheld"][k][g] = int(t["fheld"][k].get(g, 0)) + held_mu
	for id in route_ids(world, from_d, to_d, org):
		var x := _item(world, String(id))
		if x.is_empty():
			continue
		x["fwt"] = int(x.get("fwt", 0)) + moved_mu + held_mu
		if moved_mu > 0 and org != "" and String(x.get("owner", "")) == org:   # the owner's own freight on its road
			x["fro"] = int(x.get("fro", 0)) + moved_mu
		if moved_mu > 0:
			var before := trucks_pcu(int(x.get("frt", 0)))
			x["frt"] = int(x.get("frt", 0)) + moved_mu
			x["traffic"] = int(x.get("traffic", 0)) + trucks_pcu(int(x["frt"])) - before
			if PrivateRoads.is_private(x):   # truck trips a year, for Anni's cost-recovery toll
				x["ytr"] = int(x.get("ytr", 0)) + (trucks_pcu(int(x["frt"])) - before) / TRUCK_PCU
			PrivateRoads.count_freight_toll(world, String(id), x, org, moved_mu)


## Last month's load ‰ (traffic ÷ capacity) of a link or junction.
static func load_pm(world: WorldState, id: String) -> int:
	var x := _item(world, id)
	return int(x.get("traffic_last", 0)) * 1000 / maxi(1, _cap(world, id, x))


static func deliverable_pm(world: WorldState, from_d: String, to_d: String, org: String = "") -> int:
	if not on(world) or from_d == to_d:
		return 1000
	var p: Array = world.peek("transport").get("fpairs_last", {}).get("%s>%s" % [from_d, to_d], [0, 0])
	if int(p[1]) > 0:
		return int(p[0]) * 1000 / maxi(1, int(p[0]) + int(p[1]))
	var out := 1000
	for id in route_ids(world, from_d, to_d, org):
		var x := _item(world, String(id))
		out = mini(out, _cap(world, String(id), x) * JAM_ALLOW_PM / maxi(1, int(x.get("traffic_last", 0))))
	return out


static func _districts(world: WorldState) -> Array:
	var ds := {}
	for s in ColonyLayout.settlements(world):
		ds[String(s["district"])] = true
	return EconUtil.sorted_keys(ds)


static func district_jam_pm(world: WorldState, d: String) -> int:
	if not on(world):
		return 0
	return int(world.peek("transport").get("fjam", {}).get(d, 0))


## What a road would free (Wilma 2026-11-15, user: "what road is going to help the colony more"): last month's freight
## held back by the roads on every link and junction it would have used, {id: {held (mu), goods {good: mu}, to
## {district: mu}, bottleneck (mu: held credited only to the route's most loaded items last month, ties sharing)}},
## along last month's routes. Monthly memo (it reads only last month's records).
static func held_through(world: WorldState) -> Dictionary:
	if not on(world):
		return {}
	return Transport._memoised(world, "fheld", func(): return _held_through(world))


static func _held_through(world: WorldState) -> Dictionary:
	var out := {}
	var t := world.peek("transport")
	var fp: Dictionary = t.get("fpairs_last", {})
	var fh: Dictionary = t.get("fheld_last", {})
	var routes: Dictionary = t.get("froutes_last", t.get("froutes", {}))
	for k in EconUtil.sorted_keys(fp):
		var held := int(fp[k][1])
		if held <= 0:
			continue
		var ab := String(k).split(">")
		if ab.size() != 2:   # not a pair key ("a>b"): skip it rather than fail
			continue
		var goods: Dictionary = fh.get(k, {"?": held})
		var ids: Array = routes.get(_pk(ab[0], ab[1]), [])
		# the bottleneck: the items at the route's highest load last month (ties share); only they free the freight
		var top := -1
		var tops: Array = []
		for id in ids:
			var lp := load_pm(world, String(id))
			if lp > top:
				top = lp
				tops = [id]
			elif lp == top:
				tops.append(id)
		for id in ids:
			if not out.has(id):
				out[id] = {"held": 0, "goods": {}, "to": {}, "bottleneck": 0}
			var row: Dictionary = out[id]
			row["held"] = int(row["held"]) + held
			var ti := tops.find(id)
			if ti >= 0:
				var share := held / tops.size()
				row["bottleneck"] = int(row["bottleneck"]) + (held - share * (tops.size() - 1) if ti == 0 else share)
			row["to"][ab[1]] = int(row["to"].get(ab[1], 0)) + held
			for g in goods:
				row["goods"][g] = int(row["goods"].get(g, 0)) + int(goods[g])
	return out


## The same for a pair of districts, both ways (a new link between them would free it): {held, goods, to}.
static func held_between(world: WorldState, a: String, b: String) -> Dictionary:
	var out := {"held": 0, "goods": {}, "to": {}}
	var t := world.peek("transport")
	var fp: Dictionary = t.get("fpairs_last", {})
	var fh: Dictionary = t.get("fheld_last", {})
	for k in ["%s>%s" % [a, b], "%s>%s" % [b, a]]:
		var held := int(fp.get(k, [0, 0])[1])
		if held <= 0:
			continue
		var to := String(k).split(">")[1]
		out["held"] = int(out["held"]) + held
		out["to"][to] = int(out["to"].get(to, 0)) + held
		var goods: Dictionary = fh.get(k, {"?": held})
		for g in goods:
			out["goods"][g] = int(out["goods"].get(g, 0)) + int(goods[g])
	return out


## Colony-wide share of last month's freight between districts that the roads held back, ‰.
static func jam_share_pm(world: WorldState) -> int:
	var moved := 0
	var held := 0
	var fp: Dictionary = world.peek("transport").get("fpairs_last", {})
	for k in fp:
		moved += int(fp[k][0])
		held += int(fp[k][1])
	return held * 1000 / maxi(1, moved + held)


## Car-equivalents a month between two districts, both ways: last month's freight trucks and this month's commuter
## buses and taxis (Bob's commute rows).
static func pair_traffic(world: WorldState, a: String, b: String) -> int:
	var fp: Dictionary = world.peek("transport").get("fpairs_last", {})
	var n := 0
	for k in ["%s>%s" % [a, b], "%s>%s" % [b, a]]:
		if fp.has(k):
			n += trucks_pcu(int(fp[k][0]))
	for row in EconUtil.peek_st(world).get("commute_rows", []):
		var fa := String(row.get("from_d", ""))
		var fb := String(row.get("to_d", ""))
		if (fa == a and fb == b) or (fa == b and fb == a):
			n += int(row.get("buses_in_service", 0)) * Commuting.BUS_TRIPS_DAY * Commuting.WORK_DAYS
			n += ceili(float(int(row.get("taxi_users", 0))) / 1.5) * Commuting.TAXI_TRIPS_DAY * Commuting.WORK_DAYS
	return n


## Pairs of districts joined only the long way round, with the new link that would join them:
## [{a, b (districts), road_km, new_km, spec {a, b (tiles), kind ROAD}, cost, months, items (the old route's links
## and junctions), trips (pair_traffic)}]. Monthly memo; the new link's plan is pure in the terrain (kept longer).
static func detours(world: WorldState) -> Array:
	if not on(world):
		return []
	return Transport._memoised(world, "fdetours", func(): return _detours(world))


static func _detours(world: WorldState) -> Array:
	var out: Array = []
	var ds := _districts(world)
	for i in ds.size():
		for j in range(i + 1, ds.size()):
			var a := String(ds[i])
			var b := String(ds[j])
			var na := Commuting.district_node(world, a)
			var nb := Commuting.district_node(world, b)
			if na.is_empty() or nb.is_empty() or int(na["tile"]) < 0 or int(nb["tile"]) < 0:
				continue
			var cd := Transport.commute_d(world, a, b)
			if not bool(cd["ok"]):
				continue
			var straight := Vector2(Transport.int_tile(int(na["tile"]))).distance_to(Vector2(Transport.int_tile(int(nb["tile"])))) * Transport.KM_PER_TILE
			var road_km := int(cd["km"])
			if straight < DETOUR_MIN_KM or float(road_km) * 1000.0 < straight * DETOUR_PM:
				continue
			var spec := {"a": int(na["tile"]), "b": int(nb["tile"]), "kind": "ROAD"}
			var plan: Dictionary = Transport._memoised(world, "fplan", func(): return Transport.plan_link(world, spec), false,
				"%d|%d" % [int(spec["a"]), int(spec["b"])])
			if not bool(plan["ok"]) or (road_km - int(plan["km"])) * 1000 < road_km * DETOUR_SAVE_PM:
				continue
			var r := route_items(world, a, b)
			out.append({"a": a, "b": b, "road_km": road_km, "new_km": int(plan["km"]), "spec": spec, "cost": int(plan["cost"]),
				"months": int(plan["months"]), "items": r.get("links", []) + r.get("juncs", []), "trips": pair_traffic(world, a, b)})
	return out


## The trend of a link or junction: car-equivalents a month gained per year (last year's monthly mean less the year
## before's; 0 until two years are counted or when traffic falls).
static func trend(x: Dictionary) -> int:
	if int(x.get("yp", -1)) < 0 or int(x.get("yl", -1)) < 0:
		return 0
	return maxi(0, int(x["yl"]) - int(x["yp"]))


## NATURE tick (at the end of Transport.step_month, after last month's counts moved to traffic_last): last month's
## freight, the yearly trend, and jam facts.
static func step_month(world: WorldState) -> void:
	if not on(world):
		return
	var t := world.table("transport")
	var ids: Array = []
	for lid in EconUtil.sorted_keys(t["links"]):
		if int(t["links"][lid].get("globe", 0)) == 0:
			ids.append(lid)
	var jt: Dictionary = t.get("junctions", {})
	ids += EconUtil.sorted_keys(jt)
	var year_end := posmod(world.month, 12) == 0
	for id in ids:
		var x := _item(world, String(id))
		x["fpcu_last"] = trucks_pcu(int(x.get("frt", 0)))
		x["fwt_last"] = trucks_pcu(int(x.get("fwt", 0)))
		x["frt"] = 0
		if x.has("fro"):
			x["fro"] = 0
		x["fwt"] = 0
		x["fcap"] = Transport.link_capacity(x, world) if t["links"].has(id) else Transport.junction_capacity(world, x)
		x["ys"] = int(x.get("ys", 0)) + int(x.get("traffic_last", 0))
		x["yn"] = int(x.get("yn", 0)) + 1
		if year_end and x.has("ytr"):
			x["ytr_last"] = int(x["ytr"])
			x["ytr"] = 0
		if year_end:
			x["yp"] = int(x.get("yl", -1))
			x["yl"] = int(x["ys"]) / maxi(1, int(x["yn"]))
			x["ys"] = 0
			x["yn"] = 0
	# this month's freight routes, and each district's worst freight road
	var routes := {}
	var on_route := {}
	var ds := _districts(world)
	for i in ds.size():
		for j in range(i + 1, ds.size()):
			var r := route_items(world, String(ds[i]), String(ds[j]))
			if r.is_empty():
				continue
			routes[_pk(String(ds[i]), String(ds[j]))] = r["links"] + r["juncs"]
			for id in r["links"] + r["juncs"]:
				on_route[id] = true
	if PrivateRoads.on(world):   # each road-owning firm's own routes, where its roads change them ("org|a|b")
		for org in PrivateRoads.owners(world):
			for i in ds.size():
				for j in range(i + 1, ds.size()):
					var ro := route_items(world, String(ds[i]), String(ds[j]), String(org))
					if ro.is_empty():
						continue
					var ids_o: Array = ro["links"] + ro["juncs"]
					var pk := _pk(String(ds[i]), String(ds[j]))
					if ids_o != routes.get(pk, []):
						routes["%s|%s" % [org, pk]] = ids_o
						for id in ids_o:
							on_route[id] = true
	t["froutes_last"] = t.get("froutes", {})
	t["froutes"] = routes
	var setl := ColonyLayout.settlements(world)
	var fjam := {}
	for id in EconUtil.sorted_keys(on_route):
		var x := _item(world, String(id))
		if x.is_empty():
			continue
		var tile := int(x["tile"]) if x.has("tile") else int(x["path"][(x["path"] as Array).size() / 2])
		var d := Transport._district_near(setl, Transport.int_tile(tile))
		fjam[d] = maxi(int(fjam.get(d, 0)), load_pm(world, String(id)))
	t["fjam"] = fjam
	t["fpairs_last"] = t.get("fpairs", {})
	t["fpairs"] = {}
	t["fheld_last"] = t.get("fheld", {})
	t["fheld"] = {}
	_jam_facts(world, t)


## A district's freight jammed (the roads held back JAM_FACT_PM of what came to it last month): PUBLIC, once per
## spell, naming the worst-loaded link or junction on the routes in. No one responsible: politics decides the blame.
static func _jam_facts(world: WorldState, t: Dictionary) -> void:
	var by := {}
	var fp: Dictionary = t["fpairs_last"]
	for k in EconUtil.sorted_keys(fp):
		var ab := String(k).split(">")
		if ab.size() != 2:
			continue
		var d := ab[1]
		if not by.has(d):
			by[d] = [0, 0, []]
		by[d][0] += int(fp[k][0])
		by[d][1] += int(fp[k][1])
		if int(fp[k][1]) > 0:
			by[d][2].append(ab[0])
	if not t.has("jams"):
		t["jams"] = {}
	var jams: Dictionary = t["jams"]
	for d in EconUtil.sorted_keys(jams):
		var row: Array = by.get(d, [0, 0, []])
		if int(row[1]) * 1000 / maxi(1, int(row[0]) + int(row[1])) < JAM_CLEAR_PM:
			jams.erase(d)
			world.add_fact({"type": "TRANSPORT_FREIGHT_JAM_ENDED", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
				"magnitude": 20, "visibility": "PUBLIC", "data": {"district": d}})
	for d in EconUtil.sorted_keys(by):
		var held_pm := int(by[d][1]) * 1000 / maxi(1, int(by[d][0]) + int(by[d][1]))
		if held_pm < JAM_FACT_PM or jams.has(d):
			continue
		jams[d] = 1
		var worst := ""
		var wl := -1
		for src in by[d][2]:
			for id in route_ids(world, String(src), String(d)):
				var l := load_pm(world, String(id))
				if l > wl:
					wl = l
					worst = String(id)
		world.add_fact({"type": "TRANSPORT_FREIGHT_JAM", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
			"magnitude": clampi(20 + held_pm / 20, 0, 80), "visibility": "PUBLIC",
			"data": {"district": d, "where": worst, "where_kind": "LINK" if worst.begins_with("link:") else "JUNCTION", "load_pm": wl,
				"held_pm": held_pm, "held_units": int(by[d][1]) / 1000}})
