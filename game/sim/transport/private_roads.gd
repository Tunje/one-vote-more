class_name PrivateRoads
extends RefCounted
## Terra (user's go via Wilma 2026-11-15: "private roads, bought and paid for by companies"; design
## planning/design-private-roads-transport.md, law side planning/design-law-private-roads.md by Anni). Flag PRIVATE_ROADS,
## only with FREIGHT_ROADS on: a link can belong to a company.
##
## Step 1 (this file so far): who owns a link and on what terms, changes of hands, and private links kept out of the
## government's works.
##
## Fields, only on a private link (a public link has none of them): owner (org id), regime OWNER | OPEN_TOLL | OPEN_FREE,
## toll (mcr per truck trip; a car pays toll ÷ TRUCK_PCU), reserved_pm (the owner's share of capacity, ≤ 1000),
## build_cost (mcr: the plan's cost plus later works the owner paid for), public_money (mcr: state money put into it),
## licence (Anni's licence id, "" without one). private_link() adds upkeep (mcr a month, computed) and ytr_last.

const FLAG := "PRIVATE_ROADS"
const REGIMES := ["OWNER", "OPEN_TOLL", "OPEN_FREE"]
const WHY := ["SALE", "TAKEOVER", "REVERTED", "REVOKED"]
const FIELDS := ["owner", "regime", "toll", "reserved_pm", "build_cost", "public_money", "licence"]
const TransportLaw := preload("res://sim/law/transport_law.gd")   # Anni's (no class_name): LAW_ROAD_TOLL


## On with FREIGHT_ROADS, and "meta.off wins" (the standing rule; Anni's RoadLaw.on reads the same).
static func on(world: WorldState) -> bool:
	return FreightRoads.on(world) and (world.meta.get("on", []) as Array).has(FLAG) and not (world.meta.get("off", []) as Array).has(FLAG)


static func is_private(l: Dictionary) -> bool:
	return String(l.get("owner", "")) != ""


## An org that can own a road: an organisation in the world (not the government, not "").
static func _is_org(world: WorldState, who: String) -> bool:
	return who != "" and who != "gov" and world.peek("org").has(who)


## A finished ROAD project (Transport.complete_road): a new link built by a company becomes its own, on the terms in the
## spec; works on a private link paid by its owner add to build_cost, a step-in's to public_money.
static func on_built(world: WorldState, lid: String, p: Dictionary, plan: Dictionary) -> void:
	if not on(world):
		return
	var links: Dictionary = world.table("transport")["links"]
	if not links.has(lid) or int(links[lid].get("globe", 0)) == 1:
		return
	var l: Dictionary = links[lid]
	var who := String(p.get("owner", "gov"))
	var spec: Dictionary = p.get("link", {})
	if String(plan.get("job", "")) == "NEW":
		if not _is_org(world, who):
			return
		l["owner"] = who
		l["regime"] = String(spec.get("regime", "OWNER")) if String(spec.get("regime", "OWNER")) in REGIMES else "OWNER"
		l["toll"] = maxi(0, int(spec.get("toll", 0))) if l["regime"] == "OPEN_TOLL" else 0
		l["reserved_pm"] = clampi(int(spec.get("reserved_pm", 0)), 0, 1000)
		l["build_cost"] = int(plan.get("cost", 0))
		l["public_money"] = 0
		l["licence"] = String(p.get("licence", ""))
		Transport._bump(world)
	elif is_private(l):
		if bool(p.get("step_in", false)) or who == "gov":
			l["public_money"] = int(l.get("public_money", 0)) + int(plan.get("cost", 0))
		elif who == String(l["owner"]):
			l["build_cost"] = int(l.get("build_cost", 0)) + int(plan.get("cost", 0))


## A private link's record ({} for a public link or an unknown id).
static func link(world: WorldState, lid: String) -> Dictionary:
	var l: Dictionary = Transport._links(world).get(lid, {})
	if not is_private(l):
		return {}
	var out := {"id": lid, "cond": int(l["cond"]), "kind": String(l["kind"]), "km": Transport.link_km(l),
		"ytr_last": int(l.get("ytr_last", 0)), "lanes": int(l.get("lanes", 1))}
	for k in FIELDS:
		out[k] = l.get(k, "" if k in ["owner", "regime", "licence"] else 0)
	out["upkeep"] = upkeep(world, l)
	return out


## Upkeep a month (mcr): what repairing one month's wear costs, at the repair rate of the link's own bill (a repair of
## w ‰ of wear costs the full bill × w / 3000, as Transport.plan_link prices it). Wear: the kind's yearly-average age
## wear plus last month's traffic above capacity (storms left out). For Anni's cost-recovery toll.
static func upkeep(world: WorldState, l: Dictionary) -> int:
	if int(l.get("globe", 0)) == 1:
		return 0
	var k := String(l["kind"])
	var bill: Array = Transport._tile_bill(world, k, l["path"])
	var full := (float(bill[0]) * EconData.WU_COST_EST + float(bill[1]) * EconData.BASE_PRICE["MATERIAL"]
		+ float(bill[2]) * EconData.BASE_PRICE["COMPONENT"]) * 1.15 * CoreUtil.S
	var cap := maxi(1, Transport.link_capacity(l, world))
	var wear := int(Transport.WEAR[k]) + maxi(0, int(l.get("traffic_last", 0)) - cap) * 10 / cap
	return roundi(full * float(wear) / 3000.0)


## Private links (of one org, or all), sorted.
static func links_of(world: WorldState, org: String = "") -> Array:
	var out: Array = []
	var links := Transport._links(world)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if is_private(l) and (org == "" or String(l["owner"]) == org):
			out.append(lid)
	return out


## The owner sets the terms (after Anni's check). → "" or why not.
static func set_terms(world: WorldState, lid: String, regime: String, toll: int, reserved_pm: int) -> String:
	if not on(world):
		return "Private roads are not in this game"
	var links: Dictionary = world.table("transport")["links"]
	if not is_private(links.get(lid, {})):
		return "Not a private road"
	if not regime in REGIMES:
		return "Unknown regime '%s' (OWNER, OPEN_TOLL or OPEN_FREE)" % regime
	var l: Dictionary = links[lid]
	l["regime"] = regime
	l["toll"] = maxi(0, toll) if regime == "OPEN_TOLL" else 0
	l["reserved_pm"] = clampi(reserved_pm, 0, 1000)
	Transport._bump(world)
	return ""


## A change of hands: to another org (SALE), or to the colony ("": TAKEOVER, REVERTED, REVOKED and sold to the state),
## which clears the private fields and puts it in the government's works. A public fact; the law's facts are Anni's.
static func transfer_link(world: WorldState, lid: String, new_owner: String, why: String) -> String:
	if not on(world):
		return "Private roads are not in this game"
	var links: Dictionary = world.table("transport")["links"]
	if not is_private(links.get(lid, {})):
		return "Not a private road"
	if not why in WHY:
		return "Unknown reason '%s'" % why
	if new_owner != "" and not _is_org(world, new_owner):
		return "Unknown new owner '%s'" % new_owner
	var l: Dictionary = links[lid]
	var was := String(l["owner"])
	if new_owner == "":
		for k in FIELDS:
			l.erase(k)
	else:
		l["owner"] = new_owner
	Transport._bump(world)
	world.add_fact({"type": "TRANSPORT_LINK_CHANGED_HANDS", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 25, "visibility": "PUBLIC", "data": {"link": lid, "from": was, "to": new_owner if new_owner != "" else "gov", "why": why,
			"km": Transport.link_km(l), "kind": String(l["kind"])}})
	return ""


## State money put into a private link (a step-in repair, a contribution): Bob books the money, this counts it.
static func add_public_money(world: WorldState, lid: String, mcr: int) -> void:
	var links: Dictionary = world.table("transport").get("links", {})
	if is_private(links.get(lid, {})):
		links[lid]["public_money"] = int(links[lid].get("public_money", 0)) + maxi(0, mcr)


## What a truck-hour is worth when a route weighs a toll against time (mcr). Bob's EconRules.truck_trip_cost replaces
## it when it exists (agreed 2026-11-15); until then 1 credit an hour.
const TRUCK_HOUR_MCR := 1000


## A toll as hours_x100 on the route weight.
static func toll_hours_x100(world: WorldState, toll_mcr: int) -> int:
	return roundi(float(maxi(0, toll_mcr)) * 100.0 / float(TRUCK_HOUR_MCR))


## Firms that own private roads, sorted.
static func owners(world: WorldState) -> Array:
	var out := {}
	var links := Transport._links(world)
	for lid in links:
		if is_private(links[lid]):
			out[String(links[lid]["owner"])] = true
	return CoreUtil.sorted_keys(out)


## A firm's road between two districts (step 4): planned off the public roads, priced, with what it would free and
## the plan Anni's RoadLaw.may_build judges ({tiles ["x,y"], kind, districts crossed in order, regime, tile_district
## {"x,y": d}, junction_over [d], essential}). Pure.
static func road_case(world: WorldState, org: String, from_d: String, to_d: String, kind: String = "ROAD") -> Dictionary:
	var out := {"ok": false, "error": "", "spec": {}, "cost": 0, "months": 0, "km": 0, "freed_mu": 0, "freed_by_good": {},
		"relieves": [], "law_plan": {}}
	if not on(world):
		out["error"] = "Private roads are not in this game"
		return out
	var na := Commuting.district_node(world, from_d)
	var nb := Commuting.district_node(world, to_d)
	if from_d == to_d or na.is_empty() or nb.is_empty() or int(na["tile"]) < 0 or int(nb["tile"]) < 0:
		out["error"] = "Two districts with a place on the colony map are needed"
		return out
	# keep_off_public stays in the spec: the project plans the same way when it is built
	var spec := {"a": int(na["tile"]), "b": int(nb["tile"]), "kind": kind, "keep_off_public": true, "regime": "OWNER"}
	var plan := Transport.plan_link(world, spec)
	if not bool(plan["ok"]):
		out["error"] = String(plan["error"])
		return out
	var freed := FreightRoads.held_between(world, from_d, to_d)
	var relieves := FreightRoads.route_ids(world, from_d, to_d)
	# Anni's plan: tiles, districts crossed, which districts' public junctions the pair's traffic would overload, and
	# whether it would be the only good route (the public one 1.6x longer, or delivering under 80%)
	var setl := ColonyLayout.settlements(world)
	var keys: Array = []
	var td := {}
	var crossed: Array = []
	for ti in plan["path"]:
		var t := Transport.int_tile(int(ti))
		var k := "%d,%d" % [t.x, t.y]
		keys.append(k)
		var d := Transport._district_near(setl, t)
		td[k] = d
		if crossed.is_empty() or crossed[-1] != d:
			if not d in crossed:
				crossed.append(d)
	var trips := FreightRoads.pair_traffic(world, from_d, to_d)
	var jt := Transport.junctions(world)
	var on_path := {}
	for ti in plan["path"]:
		on_path[int(ti)] = true
	var over: Array = []
	for jid in CoreUtil.sorted_keys(jt):
		if not on_path.has(int(jt[jid]["tile"])):
			continue
		var cap := maxi(1, Transport.junction_capacity(world, jt[jid]))
		if (int(jt[jid].get("traffic_last", 0)) + trips) * 1000 > cap * FreightRoads.JAM_ALLOW_PM:
			var dj := Transport._district_near(setl, Transport.int_tile(int(jt[jid]["tile"])))
			if not dj in over:
				over.append(dj)
	var cd := Transport.commute_d(world, from_d, to_d)
	var essential := not bool(cd["ok"]) or int(cd["km"]) * 1000 >= int(plan["km"]) * FreightRoads.DETOUR_PM \
		or FreightRoads.deliverable_pm(world, from_d, to_d) < 800
	out["ok"] = true
	out["spec"] = spec
	out["cost"] = int(plan["cost"])
	out["months"] = int(plan["months"])
	out["km"] = int(plan["km"])
	out["freed_mu"] = int(freed["held"])
	out["freed_by_good"] = freed["goods"]
	out["relieves"] = relieves
	out["law_plan"] = {"tiles": keys, "kind": kind, "districts": crossed, "regime": "OWNER", "tile_district": td,
		"junction_over": over, "essential": essential}
	return out


## The works on a firm's own roads, worst first (step 4; Bob's rule 6: repair, or let it decay).
static func road_needs(world: WorldState, org: String) -> Array:
	var out: Array = []
	if not on(world):
		return out
	var links := Transport._links(world)
	for lid in links_of(world, org):
		var l: Dictionary = links[lid]
		var cap := maxi(1, Transport.link_capacity(l, world))
		var lpm := Transport.traffic_load(l) * 1000 / cap
		var cond := int(l["cond"])
		var congested := lpm > Transport.NEED_LOAD_PM
		var worn := cond < Transport.NEED_COND
		var opts: Array = []
		for o in Transport._link_options(world, lid, l, false):
			var after := lpm * 1000 / maxi(1, int(o["cap_pm"]))
			opts.append({"fix": String(o["fix"]), "type": String(Transport.NEED_TYPE.get(String(o["fix"]), "WIDEN")), "spec": o["spec"],
				"cost": int(o["cost"]), "months": int(o["months"]), "cap_pm": int(o["cap_pm"]), "load_after_pm": after, "relief_pm": lpm - after})
		if cond < 950:
			var plan := Transport.plan_link(world, {"repair": lid})
			if bool(plan["ok"]):
				var fresh := l.duplicate()
				fresh["cond"] = 1000
				var cap_pm := Transport.link_capacity(fresh, world) * 1000 / cap
				var after2 := lpm * 1000 / maxi(1, cap_pm)
				opts.append({"fix": "REPAIR", "type": "REPAIR", "spec": {"repair": lid}, "cost": int(plan["cost"]), "months": int(plan["months"]),
					"cap_pm": cap_pm, "load_after_pm": after2, "relief_pm": lpm - after2})
		opts.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]) or (a["cost"] == b["cost"] and String(a["fix"]) < String(b["fix"])))
		out.append({"key": "LINK:" + lid, "load_pm": lpm, "cond": cond, "upkeep": upkeep(world, l),
			"why": "BOTH" if congested and worn else ("CONGESTED" if congested else ("WORN" if worn else "OK")),
			"severity": maxi(0, lpm - Transport.NEED_LOAD_PM) + maxi(0, Transport.NEED_COND - cond), "options": opts})
	out.sort_custom(func(a, b): return int(a["severity"]) > int(b["severity"]) or (a["severity"] == b["severity"] and String(a["key"]) < String(b["key"])))
	return out


# ================================================================== tolls (step 5)
## Counted this month in transport "tolls" {lid: {"T|<payer org, '' = the carrier>": mu, "C|<home district>": trips}}.
## A toll is due on a private OPEN_TOLL link (to its owner; not from the owner itself) and, with PRIVATE_ROADS, on a
## public PAVED link when LAW_ROAD_TOLL is set (to "gov"; one toll path, Wilma 2026-11-15). A truck pays per trip
## (there and back: 2 a load), a commuter vehicle (bus, taxi) toll ÷ TRUCK_PCU per trip.

## Who is owed what per truck trip on a link for a payer: [owner ("gov" for the public toll), toll mcr] or [] for none.
static func toll_due(world: WorldState, l: Dictionary, payer: String) -> Array:
	if not on(world) or int(l.get("globe", 0)) == 1:
		return []
	if is_private(l):
		if String(l.get("regime", "")) == "OPEN_TOLL" and String(l["owner"]) != payer and int(l.get("toll", 0)) > 0:
			return [String(l["owner"]), int(l["toll"])]
		return []
	if String(l["kind"]) == "PAVED":
		var pt: int = TransportLaw.road_toll(world)
		if pt > 0:
			return ["gov", pt]
	return []


static func _count(world: WorldState, lid: String, key: String, n: int) -> void:
	var t := world.table("transport")
	if not t.has("tolls"):
		t["tolls"] = {}
	if not t["tolls"].has(lid):
		t["tolls"][lid] = {}
	t["tolls"][lid][key] = int(t["tolls"][lid].get(key, 0)) + n


## Freight on a link (FreightRoads.add_freight_traffic): counted if a toll is due.
static func count_freight_toll(world: WorldState, id: String, x: Dictionary, org: String, mu: int) -> void:
	if mu <= 0 or not x.has("path") or toll_due(world, x, org).is_empty():
		return
	_count(world, id, "T|" + org, mu)


## Commuter vehicle trips on a link (Commuting.add_commute_traffic), by the commuters' home district.
static func count_commuter_toll(world: WorldState, lid: String, home_d: String, trips: int) -> void:
	if trips <= 0:
		return
	var l: Dictionary = Transport._links(world).get(lid, {})
	if l.is_empty() or toll_due(world, l, "").is_empty():
		return
	_count(world, lid, "C|" + home_d, trips)


## This month's tolls to book (Bob, once a month): [{link, owner (org or "gov"), payer (org; "" = the carrier, CTA),
## district (CAR rows: the commuters' home), trips, mcr, kind TRUCK|CAR}], sorted. Pure.
static func toll_bill(world: WorldState) -> Array:
	var out: Array = []
	var tolls: Dictionary = world.peek("transport").get("tolls", {})
	var links := Transport._links(world)
	for lid in CoreUtil.sorted_keys(tolls):
		var l: Dictionary = links.get(lid, {})
		if l.is_empty():
			continue
		for k in CoreUtil.sorted_keys(tolls[lid]):
			var parts := String(k).split("|")
			var truck: bool = parts[0] == "T"
			var due := toll_due(world, l, parts[1] if truck else "")
			if due.is_empty():
				continue
			var n := int(tolls[lid][k])
			var trips := FreightRoads.trucks_pcu(n) / FreightRoads.TRUCK_PCU if truck else n
			var mcr := trips * int(due[1]) if truck else trips * int(due[1]) / FreightRoads.TRUCK_PCU
			out.append({"link": lid, "owner": String(due[0]), "payer": parts[1] if truck else "", "district": "" if truck else parts[1],
				"trips": trips, "mcr": mcr, "kind": "TRUCK" if truck else "CAR"})
	return out


## Bob booked the bill: the counts start again (last month's are kept for the commuters' tolls by district).
static func toll_bill_paid(world: WorldState) -> void:
	var t := world.table("transport")
	t["tolls_paid"] = commuter_tolls_now(world)
	t["tolls"] = {}


static func commuter_tolls_now(world: WorldState) -> Dictionary:
	var out := {}
	for r in toll_bill(world):
		if r["kind"] == "CAR":
			out[r["district"]] = int(out.get(r["district"], 0)) + int(r["mcr"])
	return out


## Tolls commuters paid last month, by their home district {d: mcr} (Wilma's COST_OF_LIVING). From the last booked
## bill, or (if Bob has not booked yet) the counts as the NATURE tick left them.
static func commuter_tolls(world: WorldState) -> Dictionary:
	if not on(world):
		return {}
	return (world.peek("transport").get("tolls_paid", {}) as Dictionary).duplicate()


## NATURE tick: counts Bob never booked are dropped after a month (nothing carries over).
static func step_month(world: WorldState) -> void:
	if not on(world):
		return
	var t := world.table("transport")
	if t.has("tolls") and not (t["tolls"] as Dictionary).is_empty():
		t["tolls_paid"] = commuter_tolls_now(world)
		t["tolls"] = {}


## Struct-signature part of a link's terms (keys the route memos kept across months): "" for a public link.
static func sig(l: Dictionary) -> String:
	if not is_private(l):
		return ""
	return "|%s|%s|%d|%d" % [l["owner"], l.get("regime", ""), int(l.get("toll", 0)), int(l.get("reserved_pm", 0))]
