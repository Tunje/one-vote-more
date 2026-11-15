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
		+ float(bill[2]) * EconData.BASE_PRICE["COMPONENT"]) * 1.15 * EconUtil.S
	var cap := maxi(1, Transport.link_capacity(l, world))
	var wear := int(Transport.WEAR[k]) + maxi(0, int(l.get("traffic_last", 0)) - cap) * 10 / cap
	return roundi(full * float(wear) / 3000.0)


## Private links (of one org, or all), sorted.
static func links_of(world: WorldState, org: String = "") -> Array:
	var out: Array = []
	var links := Transport._links(world)
	for lid in EconUtil.sorted_keys(links):
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


## Struct-signature part of a link's terms (keys the route memos kept across months): "" for a public link.
static func sig(l: Dictionary) -> String:
	if not is_private(l):
		return ""
	return "|%s|%s|%d|%d" % [l["owner"], l.get("regime", ""), int(l.get("toll", 0)), int(l.get("reserved_pm", 0))]
