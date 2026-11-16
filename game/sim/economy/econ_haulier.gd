extends RefCounted
## Private hauliers: freight under all eight rules for any owner (R8FR_PRIVATE, with R8 + R8_FREIGHT + R8FR_MARKET; the
## user, 2026-11-16: "All company types needs to be able to be created as private, but maybe they're is only ever
## enough work for say one powerplant then the conitions for new ones don't get switched on" and "build them as if
## they're could be a profit to base making new companies on, and to reduce size on"). Bob; planning/eight-rules.md 3h.
## Preloaded as EconHaulier (no class name).
##
## CARRIERS. Every depot owner is a carrier: the transport authority (CTA, its rate is the ECON_FREIGHT_TARIFF lever)
## and each private haulier (its own rate, org["fr_rate"], mcr per unit and hop). A carrier's room this month is what its
## own depots carry (EconProduction, st["fr_room_by"]). A shipment goes to the cheapest carrier with room (Wilma's yes,
## 2026-11-16); the buyer pays that carrier's rate and the charge goes to that carrier (what its depots moved). One
## carrier per offer and bid: when it fills up, the buyer's next offer takes the next carrier.
## A HAULIER'S RULES (CTA keeps EconRules' rules under R8FR_MARKET; under this switch they read CTA's own carrying):
##   1/2 its rate: up when its trucks were full and freight was still left behind in the colony, down when its trucks
##       stood idle; quarterly, OWN_ALPHA / OWN_UP / OWN_DOWN (Bob's numbers), within the lever's range.
##   3/4 its depots run at what it carried plus the freight left behind, of its full capacity (core crew 20%).
##   5   +25% to its smallest depot when its trucks were full in FULL_M of 12 months, freight was left behind, and it
##       earned over 12 months.
##   6   its smallest depot mothballed when it lost money over 12 months, or its trucks stood under IDLE_PCT used for
##       12 months (the last one too: a haulier with no work closes).
##   7   founded (FirmAI._entry) when a depot's first year shows a profit on the freight the carriers leave behind,
##       at today's tariff (forecast).
##   8   none while CTA's trucks stand idle or carry everything (no freight left behind in the last 3 months), while a
##       haulier loses money, or while one is being founded.
## With work for one carrier the condition for a second never comes true; it is checked every quarter for as long as
## the game runs.

const S := EconUtil.S
const FULL_PCT := 95
const FULL_M := 6
const IDLE_PCT := 60
const Q_M := 3


static func on(world: WorldState) -> bool:
	var o: Array = world.meta.get("on", []) as Array
	return EconRules.freight_market_on(world) and o.has("R8FR_PRIVATE") and not EconUtil.off(world, "R8FR_PRIVATE")


static func is_haulier(world: WorldState, oid: String) -> bool:
	var o: Dictionary = world.peek("org").get(oid, {})
	return not o.is_empty() and o.get("key", "") != "CTA" and o["status"] in ["ACTIVE", "DISTRESSED", "ADMINISTRATION", "FORMING"] \
		and _owns_depot(world, oid)


static func _owns_depot(world: WorldState, oid: String) -> bool:
	for fid in world.peek("facility"):
		var f: Dictionary = world.peek("facility")[fid]
		if f["org"] == oid and f["type"] == "DEPOT":
			return true
	return false


static func rate_of(world: WorldState, oid: String) -> int:
	var lever := int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S
	if world.peek("org").get(oid, {}).get("key", "") == "CTA":
		return lever
	return int(world.peek("org")[oid].get("fr_rate", lever))


static func _bounds(p: float) -> int:
	var row: Array = EconPublicCo.TARIFFS["CTA"][0]
	return clampi(int(p), int(row[1]) * S, int(row[2]) * S)


## TRADE start: this month's carriers, cheapest first (CTA first on a tie), each with its room (mu × hops).
static func start_month(world: WorldState) -> void:
	var s := EconUtil.st(world)
	var room_by: Dictionary = s.get("fr_room_by", {})
	var rows: Array = []
	for oid in EconUtil.sorted_keys(room_by):
		if not world.table("org").has(oid):
			continue
		rows.append({"org": oid, "rate": rate_of(world, oid), "room": int(room_by[oid]), "cta": world.table("org")[oid].get("key", "") == "CTA"})
	rows.sort_custom(func(a, b): return int(a["rate"]) < int(b["rate"]) or (int(a["rate"]) == int(b["rate"]) and (bool(a["cta"]) and not bool(b["cta"]) \
		or (bool(a["cta"]) == bool(b["cta"]) and String(a["org"]) < String(b["org"])))))
	s["fr_carriers"] = rows
	s["fr_carried"] = {}


## The cheapest carrier with room for at least one unit over `h` hops (-1: none).
static func pick(s: Dictionary, h: int) -> int:
	var rows: Array = s.get("fr_carriers", [])
	for i in rows.size():
		if int(rows[i]["room"]) >= h * S:
			return i
	return -1


static func carried(s: Dictionary, i: int, oid: String, amount: int) -> void:
	s["fr_carriers"][i]["room"] = int(s["fr_carriers"][i]["room"]) - amount
	var c: Dictionary = s.get("fr_carried", {})
	c[oid] = int(c.get(oid, 0)) + amount
	s["fr_carried"] = c


## The open depots' full capacity of one owner (mu).
static func full_of(world: WorldState, oid: String) -> int:
	var full := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "DEPOT" and not f["mothball"] and f["org"] == oid:
			full += float(EconData.RECIPES["DEPOT"]["out"][1]) * float(S) * EconUtil.fscale(f) * EconProduction._eff(world, f)
	return int(full)


## Rules 3/4 for a depot under R8FR_PRIVATE: what its owner carried last month plus the freight left behind, of its
## owner's full capacity (core crew 20% at least).
static func depot_target(world: WorldState, f: Dictionary) -> float:
	var s := EconUtil.peek_st(world)
	var oid: String = f["org"]
	var full := float(full_of(world, oid))
	if full <= 0.0 or not s.has("fr_last"):
		return 1.0
	var last: Dictionary = s["fr_last"]
	var want := float(int(last.get("carried", {}).get(oid, 0)) + int(last.get("deferred", 0)))
	return clampf(want / full, 0.2, 1.0)


## Monthly after TRADE (from EconRules._freight_rules): the month's carrying per carrier, and every quarter the
## hauliers' rules 1/2, 5 and 6.
static func monthly(world: WorldState, deferred: int) -> void:
	var s := EconUtil.st(world)
	var carried_m: Dictionary = s.get("fr_carried", {})
	s["fr_last"] = {"carried": carried_m.duplicate(), "deferred": deferred}
	var rings: Dictionary = s.get("fr_ring", {})
	for row in s.get("fr_carriers", []):
		var oid := String(row["org"])
		var ring: Array = rings.get(oid, [])
		var full := full_of(world, oid)
		ring.append([full, int(carried_m.get(oid, 0)), deferred])
		while ring.size() > 12:
			ring.pop_front()
		rings[oid] = ring
	s["fr_ring"] = rings
	if world.month % Q_M != 0:
		return
	for oid in EconUtil.sorted_keys(rings):
		if not world.table("org").has(oid) or world.table("org")[oid].get("key", "") == "CTA":
			continue
		var o: Dictionary = world.table("org")[oid]
		if not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		_rate_rules(world, o, rings[oid])
		_capacity_rules(world, o, rings[oid])


static func _rate_rules(world: WorldState, o: Dictionary, ring: Array) -> void:
	var full := 0
	var carried_q := 0
	var deferred_q := 0
	for i in range(maxi(0, ring.size() - Q_M), ring.size()):
		full += int(ring[i][0])
		carried_q += int(ring[i][1])
		deferred_q += int(ring[i][2])
	if full <= 0:
		return
	var p := float(rate_of(world, o["id"]))
	if carried_q * 100 >= full * FULL_PCT and deferred_q > 0:
		p *= 1.0 + minf(EconRulesMat.OWN_UP, EconRulesMat.OWN_ALPHA * float(deferred_q) / float(full))
	elif carried_q < full:
		p *= 1.0 - minf(EconRulesMat.OWN_DOWN, EconRulesMat.OWN_ALPHA * float(full - carried_q) / float(full))
	o["fr_rate"] = _bounds(p)


static func _capacity_rules(world: WorldState, o: Dictionary, ring: Array) -> void:
	var oid: String = o["id"]
	var full_m := 0
	var idle_m := 0
	var left := false
	for h in ring:
		if int(h[0]) > 0 and int(h[1]) * 100 >= int(h[0]) * FULL_PCT:
			full_m += 1
		if int(h[0]) <= 0 or int(h[1]) * 100 < int(h[0]) * IDLE_PCT:
			idle_m += 1
		if int(h[2]) > 0:
			left = true
	var depots: Array = []
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["type"] == "DEPOT" and f["org"] == oid and not f["mothball"]:
			depots.append(fid)
	if depots.is_empty():
		return
	var smallest := String(depots[0])
	for fid in depots:
		if int(world.table("facility")[fid].get("scale", 1000)) < int(world.table("facility")[smallest].get("scale", 1000)):
			smallest = fid
	var res := EconPublicCo.result12(o)
	var acts: Array = EconUtil.st(world).get("r8_fr_actions", [])
	if full_m >= FULL_M and left and res > 0 and int(world.table("facility")[smallest].get("scale", 1000)) < EconRules.DEPOT_MAX_SCALE \
			and not EconConstruction.has_open_project(world, oid, "EXPAND"):
		var est := EconConstruction.estimate("DEPOT") / 4
		var cash := world.ledger.balance(EconUtil.acct(oid))
		if cash >= est or (cash >= est * 3 / 10 and EconFinance.new_loan(world, oid, est - cash, 0, true)):
			EconConstruction.create_expansion(world, smallest, oid)
			acts.append([world.month, "haulier_expand", oid])
	elif (EconAnnual.months(o) >= 12 and res < 0) or (ring.size() >= 12 and idle_m >= 12):
		world.table("facility")[smallest]["mothball"] = true
		acts.append([world.month, "haulier_mothball", oid])
	EconUtil.st(world)["r8_fr_actions"] = acts


## Rules 7/8: whether a haulier would be founded now, and where (the district where most freight was left behind).
static func entry(world: WorldState) -> Dictionary:
	var s := EconUtil.peek_st(world)
	var no := {"hot": false, "district": "d:1", "profit": 0}
	var rings: Dictionary = s.get("fr_ring", {})
	# rule 8: freight left behind in each of the last 3 months (otherwise CTA's trucks carry everything or stand idle)
	var cta := EconFinance.org_by_key(world, "CTA")
	var cta_ring: Array = rings.get(cta, [])
	if cta_ring.size() < Q_M:
		return no
	var deferred := 0
	for i in range(cta_ring.size() - Q_M, cta_ring.size()):
		if int(cta_ring[i][2]) <= 0:
			return no
		deferred += int(cta_ring[i][2])
		if int(cta_ring[i][1]) * 100 < int(cta_ring[i][0]) * FULL_PCT:
			return no  # CTA's trucks stood partly idle while freight waited (they are not the bottleneck)
	for oid in rings:
		if oid != cta and world.table("org").has(oid) and EconPublicCo.result12(world.table("org")[oid]) < 0 \
				and EconAnnual.months(world.table("org")[oid]) >= 12:
			return no  # rule 8: a haulier is losing money
	# rule 7: a depot's first year on the freight left behind, at today's tariff
	var cap := float(EconData.RECIPES["DEPOT"]["out"][1]) * float(S)
	var vol := minf(float(deferred) / float(Q_M), cap)
	var rate := float(int(EconUtil.lever(world, "ECON_FREIGHT_TARIFF", 5)) * S)
	var revenue := vol * rate / float(S)
	var costs := FirmAI.unit_cost(world, "DEPOT") * cap / float(S)
	var profit := int(12.0 * (revenue - costs))
	var best_d := "d:1"
	var best_v := -1
	for d in EconUtil.sorted_keys(s.get("freight_deferred", {})):
		if int(s["freight_deferred"][d]) > best_v:
			best_v = int(s["freight_deferred"][d])
			best_d = String(d)
	return {"hot": profit > 0, "district": best_d, "profit": profit}
