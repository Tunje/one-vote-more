extends RefCounted
## M13 land law (planning/spec-areas-v1.md §9.4, A37; agreed with Bob in planning/m13-econ-notes.md).
## Law owns titles and legality; Bob owns prices and money flows (he books the money, then calls grant_land).
##
## Registry: table land_title, sparse; no row = government freehold (all land is the colony's at landing, rebuild 12.1, 3).
## Keys: a 3 km country tile "x,y"; a 100 m town cell "c:fx,fy" (TownGrid's fine coordinates). A cell with no row of its
## own has its tile's title (rebuild step 2, agreed with Terra). Where a plant stands is Terra's (Site.of); land law
## holds only who owns or leases the land and its zone. Every deed writes a Logbook row (kind LAND).
## Row: {tile, owner "gov"|org id|pool id, owner_kind GOV|COMPANY|HOUSEHOLD, tenure OWNED|LEASED, lessee, lessee_kind,
##       lease_rent, lease_until, zoning, acquired_month, price_paid, arrears_months, history}
## People are never deleted: clearance and eviction only say WHEN people must move; Bob/Wilma move them.

const Det := preload("res://sim/staff/det.gd")
const L := preload("res://sim/law/law_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")

const GOV := {"kind": "GOVERNMENT", "id": "government"}
const ZONES := ["UNZONED", "RESIDENTIAL", "INDUSTRIAL", "FARM", "RESERVE"]
const ZONE_USES := {"UNZONED": ["HOUSING", "INDUSTRY", "MINE", "FARM", "SERVICE"], "RESIDENTIAL": ["HOUSING", "SERVICE"],
	"INDUSTRIAL": ["INDUSTRY", "MINE", "SERVICE"], "FARM": ["FARM"], "RESERVE": []}
const LEASE_YIELD_PER_MONTH := 0.006        # lease rent = land value x 0.6% a month
const MAX_LEASE_MONTHS := 1188              # 99 years
const ARREARS_LIMIT := 3                    # months unpaid before the lease ends
const PLACEHOLDER_VALUE_WREF := 12000       # milli-W_ref per tile until Bob registers land_value_fn

## Hooks: land value in milli-credits by key ("x,y" or "c:fx,fy"), registered by Terra (Site.land_value_milli);
## called after an expropriation with the tile.
static var land_value_fn: Callable = Callable()
static var on_land_taken_fn: Callable = Callable()


const RULES_VERSION := 3   # 3: KEEP leases (no law forbids a private company, rebuild 12.10, 65)


## Land rules, (re)installed when missing or older than RULES_VERSION (old LAND_LAW rules are retired).
static func ensure_rules(world: WorldState) -> void:
	var s := LawOps.state(world)
	if int(s.get("land_rules_v", 0)) >= RULES_VERSION:
		return
	if int(s.get("land_rules_v", 0)) == 0:
		Logbook.note(world, "LAND", "gov", "the colony holds all land", {"rule": "rebuild 12.1, 3"})
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


## The title key of a town cell (Vector2i or "fx,fy").
static func key_of_cell(cell) -> String:
	var c: Vector2i = cell if cell is Vector2i else _v(String(cell))
	return "c:%d,%d" % [c.x, c.y]


static func is_cell(key: String) -> bool:
	return key.begins_with("c:")


static func _v(key: String) -> Vector2i:
	var k := key.substr(2) if key.begins_with("c:") else key
	return Vector2i(int(k.get_slice(",", 0)), int(k.get_slice(",", 1)))


## The 3 km tile a key lies in (a cell's tile, or the tile itself).
static func tile_of_key(key: String) -> Vector2i:
	return TownGrid.tile_of(_v(key)) if is_cell(key) else _v(key)


static func _actor_kind(ref) -> String:
	if ref is Dictionary:
		return String(ref.get("kind", "GOVERNMENT"))
	var s := String(ref)
	if s == "gov" or s == "":
		return "GOVERNMENT"
	if s.begins_with("plan:"):
		return "PLAN"        # a plan is not a company (rebuild 8.1)
	if s.begins_with("founder:"):
		return "PERSON"      # a founder, counted individually (12.5, 35)
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
	if is_cell(k):
		# A cell's own row holds only what was set on the cell itself (its zone, its own sale or lease); everything
		# else is its tile's, so a tile sold or leased takes along every cell not dealt with on its own (Ella's review).
		var tt: Dictionary = title(world, _k(tile_of_key(k))).duplicate(true)
		for f in t:
			tt[f] = t[f]
		tt["tile"] = k
		if not t.has("history"):
			tt["history"] = []
		return tt
	if t.is_empty():
		return {"tile": k, "owner": "gov", "owner_kind": "GOVERNMENT", "tenure": "OWNED", "lessee": "", "lessee_kind": "",
			"lease_rent": 0, "lease_until": -1, "zoning": "UNZONED", "acquired_month": 0, "price_paid": 0, "arrears_months": 0,
			"history": []}
	return t


static func zone_of(world: WorldState, tile) -> String:
	return String(title(world, tile).get("zoning", "UNZONED"))


## The titles of a place: {key: title} for a list of keys ("x,y" tiles or "c:fx,fy" cells).
static func title_of_place(world: WorldState, keys: Array) -> Dictionary:
	var out := {}
	for k in keys:
		out[_k(k)] = title(world, k)
	return out


## OWNER | LESSEE | "" for an actor ({kind,id} or an id string) on a tile.
static func right_of(world: WorldState, actor, tile) -> String:
	var t := title(world, tile)
	var id := _actor_id(actor)
	var plot: Dictionary = (t.get("plots", {}) as Dictionary).get(id, {})
	if not plot.is_empty():   # a plot of a country tile (rebuild step 3)
		return "OWNER" if String(plot.get("mode", "SELL")) == "SELL" else "LESSEE"
	if t["tenure"] == "LEASED" and String(t["lessee"]) == id:
		return "LESSEE"
	if String(t["owner"]) == id and t["tenure"] == "OWNED":
		return "OWNER"
	if String(t["owner"]) == id and t["tenure"] == "LEASED":
		return ""   # an owner who leased the land out has no right to build on it
	return ""


static func land_value(world: WorldState, tile) -> int:
	if land_value_fn.is_valid():
		return int(land_value_fn.call(world, _k(tile)))
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
		"KEEP":   # the state keeps its land: it leases, never sells, at double the rent (no law forbids a private company, rebuild 12.10, 65)
			out["allowed"] = true
			out["mode"] = "LEASE"
			out["lease_rent"] = int(round(float(value) * LEASE_YIELD_PER_MONTH * 2.0))
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


## The legal least price of state land, % of its value: the government's lever, the same for every buyer.
static func _floor_pct(world: WorldState, _buyer) -> int:
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
		tt[k] = {"tile": k, "history": []} if is_cell(k) else title(world, k).duplicate(true)
	return tt[k]


## The stored row that holds the deed (owner, tenure, lease) for a key: a cell's own row once the cell was sold, leased
## or taken on its own, else its tile's row. A tile's own row for a tile.
static func _deed_row(world: WorldState, tile) -> Dictionary:
	var k := _k(tile)
	if is_cell(k) and not (world.peek("land_title").get(k, {}) as Dictionary).has("tenure"):
		return _row(world, _k(tile_of_key(k)))
	return _row(world, k)


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
		"area": AreaStore.area_of(world, tile_of_key(r["tile"]))}, 20)
	Logbook.note(world, "LAND", id, "land sold" if mode == "SELL" else "land leased", {"value": value, "floor": floor_price,
		"lease_months": lease_months if mode != "SELL" else 0}, {"owner" if mode == "SELL" else "lessee": ["gov" if mode == "SELL" else "", id],
		"price": [0, price]}, "gov", String(r["tile"]))
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
	Logbook.note(world, "LAND", _actor_id(buyer), "title passed", {"price": price}, {"owner": [_actor_id(seller), _actor_id(buyer)]},
		_actor_id(seller), String(r["tile"]))
	return {"ok": true, "reason": ""}


## Zone tiles (REGULATION: government or commander). Existing uses are grandfathered: nothing is removed.
static func zone(world: WorldState, tiles: Array, zoning: String, by: Dictionary = GOV) -> Dictionary:
	if not (zoning in ZONES):
		return {"ok": false, "reason": "unknown zone"}
	var res := LawOps.validate(world, by, "ZONE_LAND", {"zone": zoning})
	if res["result"] != "AUTHORIZED":
		return {"ok": false, "reason": "not authorized: %s" % res["reason"]}
	for tile in tiles:
		var zr := _row(world, tile)
		Logbook.note(world, "LAND", _actor_id(by), "zoned", {}, {"zoning": [zone_of(world, tile), zoning]}, "", String(zr["tile"]))
		zr["zoning"] = zoning
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
		var prev := String(title(world, tile)["owner"])
		r["history"].append({"month": world.month, "from": prev, "to": "gov", "kind": "EXPROPRIATION", "price": compensation})
		Logbook.note(world, "LAND", "gov", "expropriated", {"purpose": purpose, "compensation": compensation, "due": due},
			{"owner": [prev, "gov"]}, prev, String(r["tile"]))
		r["owner"] = "gov"
		r["owner_kind"] = "GOVERNMENT"
		r["tenure"] = "OWNED"
		r["lessee"] = ""
		r["lease_until"] = -1
		r["lease_rent"] = 0
		if on_land_taken_fn.is_valid():
			on_land_taken_fn.call(world, tile_of_key(r["tile"]), "gov")
	_fact(world, "LAND_EXPROPRIATED", {"tiles": tiles.map(func(t): return _k(t)), "purpose": purpose, "compensation": compensation,
		"due": due}, 45, [{"actor": by, "share": 1.0}])
	return {"ok": true, "reason": "", "compensation_due": due}


# =====================================================================================  leases, eviction, clearance

## Bob reports unpaid lease rent; at ARREARS_LIMIT months the lease ends and occupied land goes to an eviction case.
static func report_arrears(world: WorldState, tile, months_unpaid: int) -> void:
	var r := _deed_row(world, tile)
	if String(r.get("tenure", "")) != "LEASED":
		return
	r["arrears_months"] = months_unpaid
	if months_unpaid >= ARREARS_LIMIT:
		_end_lease(world, r, "ARREARS")


static func _end_lease(world: WorldState, r: Dictionary, why: String) -> void:
	var lessee := String(r["lessee"])
	r["history"].append({"month": world.month, "from": lessee, "to": "gov", "kind": "LEASE_END_" + why, "price": 0})
	Logbook.note(world, "LAND", lessee, "lease ended", {"why": why, "arrears_months": int(r.get("arrears_months", 0))},
		{"lessee": [lessee, ""]}, "gov", String(r["tile"]))
	r["tenure"] = "OWNED"
	r["lessee"] = ""
	r["lease_until"] = -1
	r["lease_rent"] = 0
	_fact(world, "LAND_LEASE_TERMINATED", {"tile": r["tile"], "lessee": lessee, "reason": why,
		"area": AreaStore.area_of(world, tile_of_key(r["tile"]))}, 25)
	if residents_on(world, [r["tile"]]) > 0:
		request_eviction(world, GOV, [r["tile"]], "LEASE_END" if why != "ARREARS" else "ARREARS")


## Residents on tiles: area residents x the tiles' share of the area's housing units.
static func residents_on(world: WorldState, tiles: Array) -> int:
	var by_area := {}
	for tile in tiles:
		var k := _k(tile)
		var v := tile_of_key(k)
		var a := AreaStore.area_of(world, v)
		if a == "":
			continue
		var units := int(Terrain.use_at(world, v.x, v.y).get("units", 0))
		if is_cell(k):
			units = TownGrid.homes_on_cell(world, k.substr(2))
		by_area[a] = int(by_area.get(a, 0)) + units
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
		"area": AreaStore.area_of(world, tile_of_key(keys[0])) if not keys.is_empty() else ""}
	Logbook.note(world, "LAND", _actor_id(landlord), "eviction filed", {"ground": ground, "notice_months": notice,
		"residents": residents_on(world, keys)}, {"status": ["", "PENDING"]}, "", id)
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
	_collect_rent(world)
	var ev := world.table("land_eviction")
	for id in Det.ordered(ev):
		var e: Dictionary = ev[id]
		if e["status"] == "PENDING" and world.month >= int(e["due_month"]):
			e["status"] = "ORDERED"
			e["ordered_month"] = world.month
			var n := residents_on(world, e["tiles"])
			Logbook.note(world, "LAND", String(e["landlord"]), "eviction ordered", {"ground": String(e["ground"]), "residents": n},
				{"status": ["PENDING", "ORDERED"]}, "court", String(id))
			_fact(world, "LAND_EVICTION_ORDERED", {"eviction": id, "tiles": e["tiles"], "area": e["area"], "residents": n,
				"by": e["landlord"], "ground": e["ground"]}, 40 if n > 0 else 20, [],
				{"scope": {"housing": [e["area"]]}, "share": 1000, "intensity": 600, "kind": "DISPLACEMENT", "decay": 100,
				"persistent": false} if n > 0 and e["area"] != "" else {})
	var tt := world.table("land_title")
	for k in Det.ordered(tt):
		var r: Dictionary = tt[k]
		if String(r.get("tenure", "")) == "LEASED" and int(r.get("lease_until", -1)) >= 0 and world.month >= int(r["lease_until"]):
			_end_lease(world, r, "EXPIRED")


## Housing cleared unlawfully by the state (no rehousing, no order): PUBLIC fact; also an unlawful government act.
static func record_unlawful_clearance(world: WorldState, tiles: Array, residents: int) -> void:
	var keys: Array = tiles.map(func(t): return _k(t))
	_fact(world, "LAND_UNLAWFUL_CLEARANCE", {"tiles": keys, "residents": residents}, 60, [{"actor": GOV, "share": 1.0}],
		{"scope": {"housing": [AreaStore.area_of(world, tile_of_key(keys[0]))]}, "share": 1000, "intensity": 900, "kind": "DISPLACEMENT",
		"decay": 50, "persistent": false} if not keys.is_empty() else {})
	var area := AreaStore.area_of(world, tile_of_key(keys[0])) if not keys.is_empty() else ""
	LawOps.proceed_unlawfully(world, GOV, "CLEAR_HOUSING", {"tiles": keys, "residents": residents}, "",
		{"kind": "HOUSEHOLD", "id": area}, "SERIOUS")


# =====================================================================================  rebuild step 3: a plan buys its land
# (planning/rebuild-step3-joins.md; Wilma's decisions of 2026-11-17: one price for land, Terra's Site.land_price for
# the plan's own bill, passed in; the floor and the lease rent on that same figure; a country tile keeps the plots sold
# off it, in sixths, by holder; land is sold by default.) Money is milli-credits.

## The zone use of a company type (land law keeps the zones; Site.zone_use asks here).
static func use_of(type: String) -> String:
	match type:
		"LANDLORD":
			return "HOUSING"
		"FARM":
			return "FARM"
		"MINE":
			return "MINE"
	if not TypeTable.has_type(type):
		return ""
	return "SERVICE" if TypeTable.setting(type) == "TOWN" else "INDUSTRY"


## The plots sold or leased off a country tile: {holder: {type, sixths, mode, price, rent, acct, month}}.
static func plots_of(world: WorldState, tile) -> Dictionary:
	return (title(world, _k(tile)).get("plots", {}) as Dictionary).duplicate(true)


## Does `holder` own or lease all of these keys (a cell, or a plot on a country tile)?
static func holds(world: WorldState, holder: String, keys: Array) -> bool:
	if keys.is_empty():
		return false
	for k in keys:
		if right_of(world, holder, _k(k)) == "":
			return false
	return true


## What a buyer would get for these keys: {allowed, mode SELL|LEASE, price, lease_rent (a month), floor, reason}. Pure.
## price: Site.land_price for the plan's own bill, × S. Under SELL the price is due at once, under LEASE (and KEEP, at
## double rent) a rent each month. The floor (LAW_LAND_PRICE_FLOOR_PCT of the price) is on record for a later sale
## between owners; the colony's own sale is at the price.
static func terms(world: WorldState, keys: Array, buyer: String, type: String, sixths: int, price: int) -> Dictionary:
	var policy := String(world.levers.get("LAW_LAND_DISPOSAL", "SELL"))
	var mode := "SELL" if policy == "SELL" else "LEASE"
	var rent := 0 if mode == "SELL" else int(round(float(price) * LEASE_YIELD_PER_MONTH * (2.0 if policy == "KEEP" else 1.0)))
	var out := {"allowed": false, "mode": mode, "price": price, "lease_rent": rent,
		"floor": int(round(float(price) * float(_floor_pct(world, buyer)) / 100.0)), "reason": ""}
	if keys.is_empty() or price < 0 or sixths <= 0:
		out["reason"] = "no land asked for"
		return out
	var use := use_of(type)
	for k in keys:
		var key := _k(k)
		var t := title(world, key)
		if use != "" and not (use in ZONE_USES.get(String(t["zoning"]), [])):
			out["reason"] = "the %s zone does not allow %s" % [String(t["zoning"]).to_lower(), use.to_lower()]
			return out
		if String(t["owner"]) != "gov" or String(t["tenure"]) != "OWNED":
			out["reason"] = "%s is not the colony's to sell" % key
			return out
		if not is_cell(key):
			var used := 0
			for h in t.get("plots", {}):
				var p: Dictionary = t["plots"][h]
				if h == buyer:
					out["reason"] = "the buyer already holds a plot on %s" % key
					return out
				if String(p.get("type", "")) == type:
					used += int(p.get("sixths", 0))
			if used + sixths > 6:
				out["reason"] = "no room on %s: %d sixths of %s taken" % [key, used, type.to_lower()]
				return out
	out["allowed"] = true
	return out


## The one deed of a land sale (step 3 joins): re-checks the terms, takes the whole price (a lease: the first month's
## rent) from payer_acct into the treasury only if it holds it all, and writes the title: each town cell passes to the
## buyer; on a country tile a plot {type, sixths} is the buyer's and the rest stays the colony's. One LAND row per key.
## -> {ok, mode, price, lease_rent, reason}
static func sell(world: WorldState, keys: Array, buyer: String, payer_acct: String, type: String, sixths: int, price: int) -> Dictionary:
	var t := terms(world, keys, buyer, type, sixths, price)
	var res := {"ok": false, "mode": t["mode"], "price": t["price"], "lease_rent": t["lease_rent"], "reason": String(t["reason"])}
	var lease: bool = t["mode"] == "LEASE"
	var due: int = int(t["lease_rent"]) if lease else price
	if t["allowed"]:
		var v := LawOps.validate(world, GOV, "LEASE_LAND" if lease else "SELL_LAND", {"price_ok": true, "price": price, "value": price})
		if v["result"] != "AUTHORIZED":
			res["reason"] = "land policy does not allow this"
		elif not world.ledger.has_account(CoreUtil.TREASURY):
			res["reason"] = "the colony has no treasury to pay into"
		elif not world.ledger.has_account(payer_acct) or world.ledger.balance(payer_acct) < due:
			res["reason"] = "the payer cannot pay %d" % due
	if res["reason"] != "":
		Logbook.note(world, "LAND", buyer, "land sale refused", {"keys": keys.map(func(k): return _k(k)), "type": type,
			"sixths": sixths, "price": price, "reason": res["reason"]}, {}, "gov")
		return res
	if due > 0:
		world.ledger.transfer(payer_acct, CoreUtil.TREASURY, due, "LAND_LEASE" if lease else "LAND_SALE", world.month)
	var first := true
	for k in keys:
		var key := _k(k)
		# each key's share; the remainder on the first key, so the titles add up to what was paid (Ella)
		var share_price: int = price / keys.size() + (price % keys.size() if first else 0)
		var share_rent: int = int(t["lease_rent"]) / keys.size() + (int(t["lease_rent"]) % keys.size() if first else 0)
		first = false
		var r := _row(world, key)
		if is_cell(key):
			if lease:
				r["owner"] = "gov"
				r["owner_kind"] = "GOVERNMENT"
				r["tenure"] = "LEASED"
				r["lessee"] = buyer
				r["lessee_kind"] = _actor_kind(buyer)
				r["lessee_acct"] = payer_acct
				r["lease_rent"] = share_rent
				r["lease_until"] = world.month + MAX_LEASE_MONTHS
				r["arrears_months"] = 0
			else:
				r["owner"] = buyer
				r["owner_kind"] = _actor_kind(buyer)
				r["tenure"] = "OWNED"
				r["lessee"] = ""
				r["price_paid"] = share_price
			r["acquired_month"] = world.month
		else:
			var plots: Dictionary = r.get("plots", {})
			plots[buyer] = {"type": type, "sixths": sixths, "mode": t["mode"], "price": 0 if lease else share_price,
				"rent": share_rent if lease else 0, "acct": payer_acct, "month": world.month}
			r["plots"] = plots
		r["history"].append({"month": world.month, "from": "gov", "to": buyer, "kind": "LEASE" if lease else "SELL",
			"price": share_rent if lease else share_price, "sixths": 0 if is_cell(key) else sixths})
		Logbook.note(world, "LAND", buyer, "land leased" if lease else "land bought", {"type": type, "sixths": sixths,
			"price": price, "floor": int(t["floor"]), "policy": String(world.levers.get("LAW_LAND_DISPOSAL", "SELL")),
			"keys": keys.size()}, {"holder": ["gov", buyer], "paid": [0, share_rent if lease else share_price]}, "gov", key)
	res["ok"] = true
	return res


## Moves every title, lease and plot held by from_id to to_id (a plan's land to its company at the opening; a given-up
## plan's land to its founder, 60b). A lease's rent is paid from to_acct from then on (default: CoreUtil.acct(to_id)).
## One LAND row per key. -> how many keys moved.
static func pass_holder(world: WorldState, from_id: String, to_id: String, why: String, to_acct: String = "") -> int:
	var acct := to_acct if to_acct != "" else acct_of(to_id)
	var tt := world.table("land_title")
	var n := 0
	for k in Det.ordered(tt):
		var r: Dictionary = tt[k]
		var moved := false
		if String(r.get("owner", "")) == from_id:
			r["owner"] = to_id
			r["owner_kind"] = _actor_kind(to_id)
			moved = true
		if String(r.get("lessee", "")) == from_id:
			r["lessee"] = to_id
			r["lessee_kind"] = _actor_kind(to_id)
			r["lessee_acct"] = acct
			moved = true
		var plots: Dictionary = r.get("plots", {})
		if plots.has(from_id):
			var p: Dictionary = plots[from_id]
			plots.erase(from_id)
			p["acct"] = acct
			plots[to_id] = p
			moved = true
		if moved:
			r["history"].append({"month": world.month, "from": from_id, "to": to_id, "kind": "PASSED_" + why, "price": 0})
			Logbook.note(world, "LAND", to_id, "title passed on", {"why": why}, {"holder": [from_id, to_id]}, from_id, String(k))
			n += 1
	return n


## A land holder's own account: a plan's and a founder's is its id ("plan:N", "founder:N"; Otto, Maja), a company's
## CoreUtil.acct, the government's the treasury.
static func acct_of(holder: String) -> String:
	if holder == "gov" or holder == "":
		return CoreUtil.TREASURY
	if holder.begins_with("plan:") or holder.begins_with("founder:"):
		return holder
	return CoreUtil.acct(holder)


## Monthly (JUSTICE): the rent of every lease made by a sale (cells and plots) from its lessee's account to the treasury;
## not in the month the lease began (its first rent was paid with it). What an account cannot pay is a debt to the
## government through Justice.owe (one record of each thing, 12.8, 50b); rent_owed on the title is only its running total.
## Arrears and eviction come with step 5. Under a lease a plan pays rent while its plant is built: the land is part of
## what it builds on, so the rent is the land's cost, not an expense beyond building (8.1; under SELL nothing recurs).
static func _collect_rent(world: WorldState) -> void:
	if not world.ledger.has_account(CoreUtil.TREASURY):
		return
	var tt := world.peek("land_title")
	for k in Det.ordered(tt):
		var r: Dictionary = tt[k]
		if String(r.get("tenure", "")) == "LEASED" and r.has("lessee_acct") and int(r.get("acquired_month", -1)) != world.month:
			_pay_rent(world, r, String(k), String(r["lessee"]), String(r["lessee_acct"]), int(r.get("lease_rent", 0)))
		var plots: Dictionary = r.get("plots", {})
		for h in Det.ordered(plots):
			var p: Dictionary = plots[h]
			if String(p.get("mode", "")) == "LEASE" and int(p.get("month", -1)) != world.month:
				_pay_rent(world, p, String(k), String(h), String(p.get("acct", "")), int(p.get("rent", 0)))


static func _pay_rent(world: WorldState, rec: Dictionary, key: String, holder: String, acct: String, rent: int) -> void:
	if rent <= 0:
		return
	var paid := 0
	if world.ledger.has_account(acct):
		paid = mini(rent, maxi(0, world.ledger.balance(acct)))
		if paid > 0:
			world.ledger.transfer(acct, CoreUtil.TREASURY, paid, "LAND_LEASE", world.month)
	if paid < rent:
		rec["rent_owed"] = int(rec.get("rent_owed", 0)) + rent - paid
		LawOps.Justice.owe(world, holder, "gov", CoreUtil.TREASURY, rent - paid, "LAND_RENT")
	Logbook.note(world, "LAND", holder, "rent paid" if paid == rent else "rent owed", {"rent": rent, "paid": paid,
		"owed_total": int(rec.get("rent_owed", 0))}, {}, "gov", key)
