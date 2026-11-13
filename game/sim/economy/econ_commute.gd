class_name EconCommute
extends RefCounted
## Support economy §8b step 2 (planning/plan-support-economy.md; user: "think of commuting using services like buses"):
## workers travel home → work (Terra's Transport.commutes, from the staff records) and pay bus fares to the transport
## operator (CTA). Fare per commuter a month = FARE_PM of the General wage × (1 + 0.5 × hops between home and work
## district); inside one district only BUS_SHARE_LOCAL ride the bus. Each home district's fares are split over its
## households by their employed members and count in their essentials. CTA staffs its TRANSIT operation (drivers,
## depot staff, mechanics) from the smoothed fare revenue, wages taking WAGE_SHARE of it (CTA must not become a cash
## sink: the money-stock check). Per district pair the rows feed Terra's bus lines and road traffic
## (EconQuery.commuting / Transport.add_commute_traffic). The fleet with breakdowns and accidents is §8c (later).
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_T").

const S := EconUtil.S
const FARE_PM := 30  # ‰ of the General wage per commuter-month on a same-district trip by bus
const BUS_SHARE_LOCAL := 500  # ‰ of same-district commuters who take the bus (the rest walk)
const WAGE_SHARE := 0.95
const POSTS_PER_UNIT := 5  # TRANSIT recipe labour per 1000 scale (4 G + 1 S)
const COMMUTERS_PER_BUS := 60
const SEATS_PER_BUS := 50
const EMA_KEEP := 0.8


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_T") and not EconUtil.off(world, "SUPPORT_T")


## Fare per employed person for a home district (milli, last month), for the essentials basket (0 when off).
static func fare_per_worker(world: WorldState, d: String) -> int:
	if not active(world):
		return 0
	return int(EconUtil.peek_st(world).get("fare_pw", {}).get(d, 0))


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "TRANSIT":
			return f
	return {}


## Hops between home and work district: Terra's road route when the map exists, else the economy's district hops
## (econ-only worlds have no terrain grid).
static func _hops(world: WorldState, from_d: String, to_d: String) -> int:
	if (world.peek("map").get("grid", {}) as Dictionary).is_empty():
		return maxi(0, EconUtil.hops(from_d, to_d))
	return int(Transport.commute_d(world, from_d, to_d).get("hops", 0))


static func _has_map(world: WorldState) -> bool:
	return not (world.peek("map").get("grid", {}) as Dictionary).is_empty()


## Per district pair this month: [{from_d, to_d, commuters, bus_commuters, fare}] (fare = milli per bus commuter).
static func _pairs(world: WorldState) -> Array:
	var wage := int(EconUtil.st(world)["wage"]["G"])
	var by := {}
	for row in Transport.commutes(world):
		var k := "%s>%s" % [row["from_d"], row["to_d"]]
		if not by.has(k):
			by[k] = {"from_d": row["from_d"], "to_d": row["to_d"], "commuters": 0}
		by[k]["commuters"] = int(by[k]["commuters"]) + int(row["n"])
	var out: Array = []
	for k in EconUtil.sorted_keys(by):
		var p: Dictionary = by[k]
		var hops := _hops(world, p["from_d"], p["to_d"])
		var riders: int = int(p["commuters"]) if hops > 0 else int(p["commuters"]) * BUS_SHARE_LOCAL / 1000
		p["bus_commuters"] = riders
		p["fare"] = wage * FARE_PM / 1000 * (1000 + 500 * hops) / 1000
		out.append(p)
	return out


## COMPANY_AI, before FirmAI.run: charge this month's fares, staff the TRANSIT operation, report traffic to Terra.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var cta := EconFinance.org_by_key(world, "CTA")
	if cta == "":
		return
	var s := EconUtil.st(world)
	var pairs := _pairs(world)
	var due_d := {}  # home district -> fares due (milli)
	for p in pairs:
		due_d[p["from_d"]] = int(due_d.get(p["from_d"], 0)) + int(p["bus_commuters"]) * int(p["fare"])
	var rev := 0
	var fare_pw := {}
	for d in EconUtil.sorted_keys(due_d):
		var gids: Array = []
		var w8: Array = []
		var emp_total := 0
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var g: Dictionary = world.table("hh")[gid]
			if g["district"] == d:
				var e := EconLabor.employed(g)
				if e > 0:
					gids.append(gid)
					w8.append(float(e))
					emp_total += e
		if gids.is_empty():
			continue
		fare_pw[d] = int(due_d[d]) * S / maxi(1, emp_total)
		var parts := EconUtil.split_lr(int(due_d[d]), w8)
		for i in gids.size():
			if int(parts[i]) > 0:
				rev += EconUtil.pay_upto(world, EconUtil.hh_acct(gids[i]), EconUtil.acct(cta), int(parts[i]), "FARE")
	s["fare_pw"] = fare_pw
	EconFinance.pl_add(world, cta, "rev", rev)
	# staff the buses from the smoothed fare revenue
	var ema := int(EMA_KEEP * float(s.get("fare_rev_ema", rev)) + (1.0 - EMA_KEEP) * float(rev))
	s["fare_rev_ema"] = ema
	var f := _site(world, cta)
	if f.is_empty():
		var fid := EconSetup.add_facility(world, "TRANSIT", cta, "d:1", false)
		world.table("facility")[fid]["book"] = 0
		f = world.table("facility")[fid]
	var posts := int(float(ema) * WAGE_SHARE / float(maxi(1, int(s["wage"]["G"]))))
	f["scale"] = posts * 1000 / POSTS_PER_UNIT
	f["T"] = 1000
	# Terra: bus lines and road traffic from the pair rows
	var rows := query_rows(world, pairs)
	s["commute_rows"] = rows
	if _has_map(world):
		Transport.add_commute_traffic(world, rows)


## The rows of EconQuery.commuting / Terra's bus lines (agreed shape; taxis and breakdowns come with §8c).
static func query_rows(_world: WorldState, pairs: Array) -> Array:
	var out: Array = []
	for p in pairs:
		var riders := int(p["bus_commuters"])
		var buses := (riders + COMMUTERS_PER_BUS - 1) / COMMUTERS_PER_BUS
		var seats := buses * SEATS_PER_BUS
		out.append({"from_d": p["from_d"], "to_d": p["to_d"], "commuters": int(p["commuters"]), "bus_commuters": riders,
			"taxi_users": 0, "buses_in_service": buses, "seats": seats, "load_pm": riders * 1000 / maxi(1, seats),
			"breakdowns_m": 0, "crashes_m": 0})
	return out
