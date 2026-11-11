extends RefCounted
## M13 land law (planning/spec-areas-v1.md §9.4, A37; agreed with Bob in planning/m13-econ-notes.md).
## Law owns titles and legality; Bob owns prices and money flows (he books the money, then calls grant_land).
##
## Registry: table land_title, sparse, keyed "x,y"; no row = government freehold (all land is the state's at founding).
## Row: {tile, owner "gov"|org id|pool id, owner_kind GOV|COMPANY|HOUSEHOLD, tenure OWNED|LEASED, lessee, lessee_kind,
##       lease_rent, lease_until, zoning, acquired_month, price_paid, arrears_months, history}
## People are never deleted: clearance and eviction only say WHEN people must move; Bob/Wilma move them.

const Det := preload("res://sim/staff/det.gd")
const L := preload("res://sim/law/law_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}
const ZONES := ["UNZONED", "RESIDENTIAL", "INDUSTRIAL", "FARM", "RESERVE"]
const ZONE_USES := {"UNZONED": ["HOUSING", "INDUSTRY", "MINE", "FARM", "SERVICE"], "RESIDENTIAL": ["HOUSING", "SERVICE"],
	"INDUSTRIAL": ["INDUSTRY", "MINE", "SERVICE"], "FARM": ["FARM"], "RESERVE": []}
const COMPANY_FLOOR_PCT := 90
const LEASE_YIELD_PER_MONTH := 0.006        # lease rent = land value x 0.6% a month
const MAX_LEASE_MONTHS := 1188              # 99 years
const ARREARS_LIMIT := 3                    # months unpaid before the lease ends
const PLACEHOLDER_VALUE_WREF := 12000       # milli-W_ref per tile until Bob registers land_value_fn

## Hooks registered by the economy (Bob, A2): land value in milli-credits; called after an expropriation.
static var land_value_fn: Callable = Callable()
static var on_land_taken_fn: Callable = Callable()


const RULES_VERSION := 2


## Land rules, (re)installed when missing or older than RULES_VERSION (old LAND_LAW rules are retired).
static func ensure_rules(world: WorldState) -> void:
	var s := LawOps.state(world)
	if int(s.get("land_rules_v", 0)) >= RULES_VERSION:
		return
	s["land_rules_v"] = RULES_VERSION
	for k in ["land_title", "land_eviction"]:
		world.table(k)
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		if rules[rid].get("source", "") == "LAND_LAW" and rules[rid]["status"] == "ACTIVE":
			rules[rid]["status"] = "REPEALED"
	for r in L.land_rules():
		r["effective_month"] = world.month
		LawOps.add_rule(world, r)
	LawOps.bump_rules_version(world)


static func _k(tile) -> String:
	return tile if typeof(tile) == TYPE_STRING else "%d,%d" % [tile.x, tile.y]


static func _v(key: String) -> Vector2i:
	return Vector2i(int(key.get_slice(",", 0)), int(key.get_slice(",", 1)))


static func _actor_kind(ref) -> String:
	if ref is Dictionary:
		return String(ref.get("kind", "GOVERNMENT"))
	var s := String(ref)
	if s == "gov" or s == "":
		return "GOVERNMENT"
	return "HOUSEHOLD" if s.begins_with("hh:") else "COMPANY"


static func _actor_id(ref) -> String:
	if ref is Dictionary:
		return "gov" if ref.get("kind", "") in ["GOVERNMENT", "COMMANDER"] else String(ref.get("id", ""))
	return String(ref)


# =====================================================================================  reads

## The title of a tile (a default government row when none is stored).
static func title(world: WorldState, tile) -> Dictionary:
	var k := _k(tile)
	var t: Dictionary = world.peek("land_title").get(k, {})
	if t.is_empty():
		return {"tile": k, "owner": "gov", "owner_kind": "GOVERNMENT", "tenure": "OWNED", "lessee": "", "lessee_kind": "",
			"lease_rent": 0, "lease_until": -1, "zoning": "UNZONED", "acquired_month": 0, "price_paid": 0, "arrears_months": 0,
			"history": []}
	return t


static func zone_of(world: WorldState, tile) -> String:
	return String(title(world, tile).get("zoning", "UNZONED"))


## OWNER | LESSEE | "" for an actor ({kind,id} or an id string) on a tile.
static func right_of(world: WorldState, actor, tile) -> String:
	var t := title(world, tile)
	var id := _actor_id(actor)
	if t["tenure"] == "LEASED" and String(t["lessee"]) == id:
		return "LESSEE"
	if String(t["owner"]) == id and t["tenure"] == "OWNED":
		return "OWNER"
	if String(t["owner"]) == id and t["tenure"] == "LEASED":
		return ""   # an owner who leased the land out has no right to build on it
	return ""


static func land_value(world: WorldState, tile) -> int:
	if land_value_fn.is_valid():
		return int(land_value_fn.call(world, _v(_k(tile))))
	return int(PLACEHOLDER_VALUE_WREF * LawOps.Staff.w_ref_milli(world) / 1000)


## May `actor` build `use` (HOUSING|INDUSTRY|MINE|FARM|SERVICE) on this tile? Land right + zone.
## The state may build on its own land; everyone else needs to own or lease the tile.
static func can_build(world: WorldState, actor, tile, use: String) -> Dictionary:
	var reasons: Array = []
	var t := title(world, tile)
	var kind := _actor_kind(actor)
	var state_builds: bool = kind in ["GOVERNMENT", "COMMANDER"] and t["owner"] == "gov" and t["tenure"] == "OWNED"
	if not state_builds and right_of(world, actor, tile) == "":
		reasons.append("no title or lease on this land")
	if not (use in ZONE_USES.get(String(t["zoning"]), [])):
		reasons.append("the %s zone does not allow %s" % [String(t["zoning"]).to_lower(), use.to_lower()])
	return {"ok": reasons.is_empty(), "reasons": reasons}


## What the state offers this buyer for this tile under current land policy (Bob: then book money, then grant_land).
static func land_offer(world: WorldState, tile, buyer, use: String = "") -> Dictionary:
	var t := title(world, tile)
	var out := {"allowed": false, "mode": "NONE", "price": 0, "lease_rent": 0, "reason": ""}
	if t["owner"] != "gov" or t["tenure"] != "OWNED":
		out["reason"] = "not state land on offer"
		return out
	if use != "" and not (use in ZONE_USES.get(String(t["zoning"]), [])):
		out["reason"] = "the %s zone does not allow %s" % [String(t["zoning"]).to_lower(), use.to_lower()]
		return out
	var value := land_value(world, tile)
	match String(world.levers.get("LAW_LAND_DISPOSAL", "LEASE")):
		"KEEP":
			out["reason"] = "land policy: the state keeps its land"
		"LEASE":
			out["allowed"] = true
			out["mode"] = "LEASE"
			out["lease_rent"] = int(round(float(value) * LEASE_YIELD_PER_MONTH))
		"SELL":
			out["allowed"] = true
			out["mode"] = "SELL"
			out["price"] = int(round(float(value) * float(_floor_pct(world, buyer)) / 100.0))
			out["lease_rent"] = int(round(float(value) * LEASE_YIELD_PER_MONTH))
	return out


static func _floor_pct(world: WorldState, buyer) -> int:
	if _actor_kind(buyer) == "COMPANY":
		return COMPANY_FLOOR_PCT
	return int(world.levers.get("LAW_LAND_PRICE_FLOOR_PCT", 90))


# =====================================================================================  writes

static func _fact(world: WorldState, type: String, data: Dictionary, mag: int = 25, resp: Array = [], exposure: Dictionary = {}) -> String:
	var f := {"type": type, "owner": "law", "subjects": [GOV], "responsible": resp, "impact": {}, "magnitude": mag,
		"visibility": "PUBLIC", "data": data}
	if not exposure.is_empty():
		f["exposure"] = exposure
	return world.add_fact(f)


static func _row(world: WorldState, tile) -> Dictionary:
	var k := _k(tile)
	var tt := world.table("land_title")
	if not tt.has(k):
		tt[k] = title(world, k).duplicate(true)
	return tt[k]


## Grant state land to a buyer (Bob has booked the money). mode SELL | LEASE. Re-validates against current law.
static func grant_land(world: WorldState, tile, buyer, mode: String, price: int, lease_months: int = MAX_LEASE_MONTHS, by: Dictionary = GOV) -> Dictionary:
	var t := title(world, tile)
	if t["owner"] != "gov" or t["tenure"] != "OWNED":
		return {"ok": false, "reason": "not state land"}
	var value := land_value(world, tile)
	var floor_price := int(round(float(value) * float(_floor_pct(world, buyer)) / 100.0))
	var action := "SELL_LAND" if mode == "SELL" else "LEASE_LAND"
	var res := LawOps.validate(world, by, action, {"price_ok": price >= floor_price, "price": price, "value": value})
	if res["result"] != "AUTHORIZED":
		var why: String = "land policy does not allow this" if res["reason"] == "no legal authority" else String(res["reason"])
		if mode == "SELL" and String(world.levers.get("LAW_LAND_DISPOSAL", "LEASE")) == "SELL" and price < floor_price:
			why = "below the legal price floor (%d of %d)" % [price, floor_price]
		return {"ok": false, "reason": why}
	var r := _row(world, tile)
	var id := _actor_id(buyer)
	if mode == "SELL":
		r["owner"] = id
		r["owner_kind"] = _actor_kind(buyer)
		r["tenure"] = "OWNED"
		r["price_paid"] = price
	else:
		r["tenure"] = "LEASED"
		r["lessee"] = id
		r["lessee_kind"] = _actor_kind(buyer)
		r["lease_rent"] = price
		r["lease_until"] = world.month + clampi(lease_months, 1, MAX_LEASE_MONTHS)
		r["arrears_months"] = 0
	r["acquired_month"] = world.month
	r["history"].append({"month": world.month, "from": "gov", "to": id, "kind": mode, "price": price})
	_fact(world, "LAND_SOLD" if mode == "SELL" else "LAND_LEASED", {"tile": r["tile"], "to": id, "to_kind": _actor_kind(buyer),
		"price": price, "value": value, "discount_pct": 0 if value <= 0 else maxi(0, int(round(100.0 - 100.0 * float(price) / float(value)))),
		"area": AreaStore.area_of(world, _v(r["tile"]))}, 20)
	return {"ok": true, "reason": ""}


## Private resale between owners (Bob books the money first).
static func transfer_title(world: WorldState, tile, seller, buyer, price: int) -> Dictionary:
	var t := title(world, tile)
	if String(t["owner"]) != _actor_id(seller) or t["owner"] == "gov":
		return {"ok": false, "reason": "the seller does not own this land"}
	var r := _row(world, tile)
	r["owner"] = _actor_id(buyer)
	r["owner_kind"] = _actor_kind(buyer)
	r["price_paid"] = price
	r["acquired_month"] = world.month
	r["history"].append({"month": world.month, "from": _actor_id(seller), "to": _actor_id(buyer), "kind": "RESALE", "price": price})
	return {"ok": true, "reason": ""}


## Zone tiles (REGULATION: government or commander). Existing uses are grandfathered: nothing is removed.
static func zone(world: WorldState, tiles: Array, zoning: String, by: Dictionary = GOV) -> Dictionary:
	if not (zoning in ZONES):
		return {"ok": false, "reason": "unknown zone"}
	var res := LawOps.validate(world, by, "ZONE_LAND", {"zone": zoning})
	if res["result"] != "AUTHORIZED":
		return {"ok": false, "reason": "not authorized: %s" % res["reason"]}
	for tile in tiles:
		_row(world, tile)["zoning"] = zoning
	_fact(world, "LAND_ZONED", {"tiles": tiles.map(func(t): return _k(t)), "zone": zoning}, 20, [{"actor": by, "share": 1.0}])
	return {"ok": true, "reason": ""}


## Expropriation: public purpose and compensation >= 100% of land value (+ the remaining lease value to a lessee).
## The title goes to the state; Bob's hook pays, mothballs and rehouses. Occupied housing then needs clearance
## (rehousing) or an eviction order before anyone has to move. -> {ok, reason, compensation_due}
static func expropriate(world: WorldState, tiles: Array, by: Dictionary, purpose: String, compensation: int) -> Dictionary:
	var due := 0
	for tile in tiles:
		var t := title(world, tile)
		if t["owner"] != "gov":
			due += land_value(world, tile)
		if t["tenure"] == "LEASED":
			var left := maxi(0, int(t["lease_until"]) - world.month)
			due += int(t["lease_rent"]) * mini(left, 120)    # remaining lease value, capped at 10 years of rent
	var pct := 100 if due <= 0 else int(floor(100.0 * float(compensation) / float(due)))
	var res := LawOps.validate(world, by, "EXPROPRIATE", {"public_purpose": purpose != "", "compensation_pct": pct})
	if res["result"] != "AUTHORIZED":
		return {"ok": false, "reason": "unlawful: %s" % (res["reason"] if purpose != "" else "no public purpose"), "compensation_due": due}
	for tile in tiles:
		var r := _row(world, tile)
		var prev := String(r["owner"])
		r["history"].append({"month": world.month, "from": prev, "to": "gov", "kind": "EXPROPRIATION", "price": compensation})
		r["owner"] = "gov"
		r["owner_kind"] = "GOVERNMENT"
		r["tenure"] = "OWNED"
		r["lessee"] = ""
		r["lease_until"] = -1
		r["lease_rent"] = 0
		if on_land_taken_fn.is_valid():
			on_land_taken_fn.call(world, _v(r["tile"]), "gov")
	_fact(world, "LAND_EXPROPRIATED", {"tiles": tiles.map(func(t): return _k(t)), "purpose": purpose, "compensation": compensation,
		"due": due}, 45, [{"actor": by, "share": 1.0}])
	return {"ok": true, "reason": "", "compensation_due": due}


# =====================================================================================  leases, eviction, clearance

## Bob reports unpaid lease rent; at ARREARS_LIMIT months the lease ends and occupied land goes to an eviction case.
static func report_arrears(world: WorldState, tile, months_unpaid: int) -> void:
	var r := _row(world, tile)
	if r["tenure"] != "LEASED":
		return
	r["arrears_months"] = months_unpaid
	if months_unpaid >= ARREARS_LIMIT:
		_end_lease(world, r, "ARREARS")


static func _end_lease(world: WorldState, r: Dictionary, why: String) -> void:
	var lessee := String(r["lessee"])
	r["history"].append({"month": world.month, "from": lessee, "to": "gov", "kind": "LEASE_END_" + why, "price": 0})
	r["tenure"] = "OWNED"
	r["lessee"] = ""
	r["lease_until"] = -1
	r["lease_rent"] = 0
	_fact(world, "LAND_LEASE_TERMINATED", {"tile": r["tile"], "lessee": lessee, "reason": why,
		"area": AreaStore.area_of(world, _v(r["tile"]))}, 25)
	if residents_on(world, [r["tile"]]) > 0:
		request_eviction(world, GOV, [r["tile"]], "LEASE_END" if why != "ARREARS" else "ARREARS")


## Residents on tiles: area residents x the tiles' share of the area's housing units.
static func residents_on(world: WorldState, tiles: Array) -> int:
	var by_area := {}
	for tile in tiles:
		var v := _v(_k(tile))
		var a := AreaStore.area_of(world, v)
		if a == "":
			continue
		by_area[a] = int(by_area.get(a, 0)) + int(Terrain.use_at(world, v.x, v.y).get("units", 0))
	var n := 0
	for a in by_area:
		var cap := maxi(1, AreaStore.capacity(world, a))
		n += int(round(float(AreaStore.residents(world, a)) * minf(1.0, float(by_area[a]) / float(cap))))
	return n


## May housing on these tiles (or a whole area) be cleared now? -> {allowed, needs_rehousing, residents, reason}
## Lawful only with committed rehousing capacity (params.rehousing_units >= residents) or a court eviction order.
static func may_clear(world: WorldState, where, actor = GOV, params: Dictionary = {}) -> Dictionary:
	var tiles: Array = where if where is Array else AreaStore.get_area(world, String(where)).get("tiles", [])
	var n := residents_on(world, tiles)
	var ordered := _has_order(world, tiles)
	var rehoused := int(params.get("rehousing_units", 0)) >= n
	var act: Dictionary = {"kind": _actor_kind(actor), "id": _actor_id(actor)} if not (actor is Dictionary) else actor
	var res := LawOps.validate(world, act, "CLEAR_HOUSING", {"rehoused": rehoused, "eviction_order": ordered, "residents": n})
	var ok: bool = n == 0 or res["result"] == "AUTHORIZED"
	var reason := ""
	if not ok:
		reason = "%d residents need lawful rehousing or a court eviction order" % n
	return {"allowed": ok, "needs_rehousing": n > 0 and not ordered, "residents": n, "reason": reason}


## Start an eviction: the order comes after LAW_EVICTION_NOTICE_MONTHS (court routine). ground ARREARS | LEASE_END |
## DEMOLITION | EXPROPRIATION. -> eviction id
static func request_eviction(world: WorldState, landlord, tiles: Array, ground: String) -> String:
	var id := world.new_id("evict")
	var notice := int(world.levers.get("LAW_EVICTION_NOTICE_MONTHS", 3))
	var keys: Array = tiles.map(func(t): return _k(t))
	world.table("land_eviction")[id] = {"id": id, "landlord": _actor_id(landlord), "tiles": keys, "ground": ground,
		"filed_month": world.month, "due_month": world.month + notice, "status": "PENDING",
		"area": AreaStore.area_of(world, _v(keys[0])) if not keys.is_empty() else ""}
	_fact(world, "LAND_EVICTION_FILED", {"eviction": id, "tiles": keys, "ground": ground, "notice_months": notice,
		"residents": residents_on(world, keys)}, 30)
	return id


static func _has_order(world: WorldState, tiles: Array) -> bool:
	var keys: Array = tiles.map(func(t): return _k(t))
	for id in Det.ordered(world.peek("land_eviction")):
		var e: Dictionary = world.peek("land_eviction")[id]
		if e["status"] == "ORDERED" and keys.all(func(k): return e["tiles"].has(k)):
			return true
	return false


## Monthly (JUSTICE): evictions whose notice is over become orders; expired leases end.
static func tick(world: WorldState) -> void:
	var ev := world.table("land_eviction")
	for id in Det.ordered(ev):
		var e: Dictionary = ev[id]
		if e["status"] == "PENDING" and world.month >= int(e["due_month"]):
			e["status"] = "ORDERED"
			e["ordered_month"] = world.month
			var n := residents_on(world, e["tiles"])
			_fact(world, "LAND_EVICTION_ORDERED", {"eviction": id, "tiles": e["tiles"], "area": e["area"], "residents": n,
				"by": e["landlord"], "ground": e["ground"]}, 40 if n > 0 else 20, [],
				{"scope": {"housing": [e["area"]]}, "share": 1000, "intensity": 600, "kind": "DISPLACEMENT", "decay": 100,
				"persistent": false} if n > 0 and e["area"] != "" else {})
	var tt := world.table("land_title")
	for k in Det.ordered(tt):
		var r: Dictionary = tt[k]
		if r["tenure"] == "LEASED" and int(r["lease_until"]) >= 0 and world.month >= int(r["lease_until"]):
			_end_lease(world, r, "EXPIRED")


## Housing cleared unlawfully by the state (no rehousing, no order): PUBLIC fact; also an unlawful government act.
static func record_unlawful_clearance(world: WorldState, tiles: Array, residents: int) -> void:
	var keys: Array = tiles.map(func(t): return _k(t))
	_fact(world, "LAND_UNLAWFUL_CLEARANCE", {"tiles": keys, "residents": residents}, 60, [{"actor": GOV, "share": 1.0}],
		{"scope": {"housing": [AreaStore.area_of(world, _v(keys[0]))]}, "share": 1000, "intensity": 900, "kind": "DISPLACEMENT",
		"decay": 50, "persistent": false} if not keys.is_empty() else {})
	var area := AreaStore.area_of(world, _v(keys[0])) if not keys.is_empty() else ""
	LawOps.proceed_unlawfully(world, GOV, "CLEAR_HOUSING", {"tiles": keys, "residents": residents}, "",
		{"kind": "HOUSEHOLD", "id": area}, "SERIOUS")
