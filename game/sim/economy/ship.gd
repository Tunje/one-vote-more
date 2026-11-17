extends RefCounted
## The ship (rebuild step 3; plan 9.6, 12.4 points 25 and 26, 12.5 point 42; Wilma, reviewed by Bob and by Terra for
## the port). Preload it: const Ship := preload("res://sim/economy/ship.gd").
##
## "They can't order when there's not a ship there to take the order. ... they have to ask for one when the ship is
## there, which means they have the full period of waiting every time."
##   - Nothing enters or leaves the colony except on a ship in port. No order, request, payment or answer otherwise.
##   - An order placed with a ship in port comes back with THAT ship on its next call: the full round trip, every time.
##   - That is the whole limit on imports. There is no rule here on what may be ordered or how often beyond it.
##
## A ship calls, lies in port for that month, and leaves at the start of the next. While it lies in port anyone may
## place an order with it (order()). When it comes back it lands what it took orders for, and the buyer pays then, on
## the dock: the payment goes home aboard the same ship. A buyer who cannot pay for all of it gets what it can pay
## for; the rest goes back.
##
## The ship that brought the settlers is in port in the first month, so the first orders can go with it.
## The time between a ship's calls is drawn from EconFace.trade_ship_interval (months; a treaty or sanction may set it).
##
## Only a company can order here. The government ordering for the colony (12.11, 102) comes with the purse at step 8.
## NOT here yet: exports and the charter quota (step 10), the port's size (106, step 10), the home world's prices
## moving (105, step 10), settlers and leavers (the households' side calls in through the conductor, 42).
## State: table "ship" {"ships": [...], "last": {...}, "n": orders made}. Every deed writes a Logbook row.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")

const TABLE := "ship"
const S := CoreUtil.S
const HOLD_START := 3000          # START: units of cargo one call can bring
const HOME_PRICE_PM := 2000       # START (Bob): the home world sells at twice the colony's starting price
const RNG := "econ.ship"


# ---------------------------------------------------------------- the month

## Month one: the ship that brought the colony lies in port. Once.
static func land(world: WorldState) -> void:
	var t := world.table(TABLE)
	if t.has("ships"):
		return
	t["ships"] = [{"id": "ship:1", "hold": HOLD_START, "next": world.month, "in_port": true, "calls": 1,
		"taking": [], "bringing": []}]
	t["last"] = {"ship": "ship:1", "month": world.month, "landed": {}, "returned": {}}
	t["n"] = 0
	Logbook.note(world, "SHIP", "ship:1", "in port at the landing", {"hold": HOLD_START})


## TRADE, once a month: the ships that lay in port leave with the orders they took; the ships due this month arrive
## and land what they went for.
static func month(world: WorldState) -> void:
	var t := world.table(TABLE)
	if not t.has("ships"):
		return
	var left := {}   # a ship that leaves this month is not back this month, however short the interval (Terra's review)
	for sh in t["ships"]:
		if bool(sh["in_port"]) and int(sh["next"]) < world.month:
			_leave(world, sh)
			left[sh["id"]] = true
	for sh in t["ships"]:
		if not bool(sh["in_port"]) and int(sh["next"]) <= world.month and not left.has(sh["id"]):
			_arrive(world, sh)


static func _leave(world: WorldState, sh: Dictionary) -> void:
	var gap: Array = EconFace.trade_ship_interval(world)
	var away := world.rng.stream(RNG).randi_range(int(gap[0]), int(gap[1]))
	sh["in_port"] = false
	sh["bringing"] = sh["taking"]
	sh["taking"] = []
	sh["next"] = maxi(world.month + 1, world.month - 1 + away)   # it lay in port last month; the round trip counts from then
	Logbook.note(world, "SHIP", String(sh["id"]), "left port", {"orders": (sh["bringing"] as Array).size(), "round_trip_m": away},
		{"next_call": [world.month - 1, int(sh["next"])]})


static func _arrive(world: WorldState, sh: Dictionary) -> void:
	sh["in_port"] = true
	sh["calls"] = int(sh["calls"]) + 1
	var landed := {}
	var returned := {}
	for o in sh["bringing"]:
		var got := _deliver(world, String(sh["id"]), o)
		if got > 0:
			landed[o["item"]] = int(landed.get(o["item"], 0)) + got
		if got < int(o["qty"]):
			returned[o["item"]] = int(returned.get(o["item"], 0)) + int(o["qty"]) - got
	sh["bringing"] = []
	world.table(TABLE)["last"] = {"ship": sh["id"], "month": world.month, "landed": landed, "returned": returned}
	Logbook.note(world, "SHIP", String(sh["id"]), "arrived", {"call": sh["calls"]}, {"landed": [{}, landed], "returned": [{}, returned]})
	world.add_fact({"type": "ECON_SHIP_ARRIVED", "owner": "econ", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 30, "visibility": "PUBLIC", "data": _at_port(world, {"ship": sh["id"], "landed": landed, "returned": returned,
		"migrants": 0, "export_value": 0})})   # the news reads both: settlers come with the households' side, exports at step 10


## Lands one order: the buyer pays on the dock for what it can, and that much goes into its stock as an IMPORT.
## Returns the quantity landed (milli-units).
static func _deliver(world: WorldState, ship_id: String, o: Dictionary) -> int:
	var buyer := String(o["buyer"])
	var acct := CoreUtil.acct(buyer)
	var qty := int(o["qty"])
	var price := int(o["price"])
	var why := {"ordered_m": o["month"], "qty": qty, "price": price}
	var rec := Company.record(world, buyer)
	if rec.is_empty() or String(rec["status"]) != "OPEN":
		Logbook.note(world, "IMPORT", buyer, "NOT landed: the buyer is gone", why, {}, ship_id, String(o["id"]))
		return 0
	var have := maxi(0, world.ledger.balance(acct))
	var can := qty if price <= 0 else mini(qty, have * S / price)
	if can > 0:
		var cost := can * price / S
		if cost > 0:
			world.ledger.transfer(acct, Ledger.EXTERNAL, cost, "IMPORT", world.month)
		Company.stock_add(world, buyer, String(o["item"]), can, price, "IMPORT", "ordered with %s in month %d" % [ship_id, int(o["month"])])
		world.add_fact({"type": "ECON_IMPORT_ARRIVED", "owner": "econ", "subjects": [], "responsible": [], "impact": {},
			"magnitude": 20, "visibility": "PUBLIC", "data": _at_port(world, {"buyer": buyer, "good": o["item"], "qty": can})})   # qty in milli-units, as the news reads it
	why["could_pay_for"] = can
	Logbook.note(world, "IMPORT", buyer, "landed and paid on the dock" if can == qty else "landed IN PART: short of money",
		why, {"stock": [0, can], "paid": [0, can * price / S]}, ship_id, String(o["id"]))
	return can


## Where the port is: the landfall tile. One function, so a second port changes one place (Terra's review).
static func port_tile(world: WorldState) -> Vector2i:
	return Terrain.landing(world)


## A fact's data with the port's place on it, as planet and transport facts carry theirs (the press and the map
## place a fact by "tile" and "hex").
static func _at_port(world: WorldState, data: Dictionary) -> Dictionary:
	var l := port_tile(world)
	data["place"] = "the landing port"
	data["tile"] = [l.x, l.y]
	data["hex"] = Planet.landing(world)
	return data


# ---------------------------------------------------------------- ordering

## The ships lying in port this month (ids). Empty: nobody can order, ask or send anything.
static func in_port(world: WorldState) -> Array:
	var out: Array = []
	for sh in world.peek(TABLE).get("ships", []):
		if bool(sh["in_port"]):
			out.append(String(sh["id"]))
	return out


## What the home world asks for one unit of an item, as the colony last heard it, milli-credits.
static func home_price(_world: WorldState, item: String) -> int:
	return TypeTable.start_price(item) * HOME_PRICE_PM / 1000


## A company orders goods from the home world. Only with a ship in port; it goes with the first ship in port that has
## room, and comes back on that ship's next call, to be paid then at the price heard today. One order rides one ship:
## when that ship has less room than asked, the order is cut to its room and the buyer orders again for the rest
## (with another ship in port, or at the next call).
## Returns {"ok", "why", "order" id, "qty" taken (milli-units; less than asked when the hold has less room), "ship"}.
static func order(world: WorldState, buyer_cid: String, item: String, qty_milli: int, why: Dictionary = {}) -> Dictionary:
	var refuse := ""
	if Company.record(world, buyer_cid).is_empty():
		refuse = "unknown company"
	elif not TypeTable.is_item(item) or bool(TypeTable.ITEMS[item]["grid"]):
		refuse = "not something a ship carries"
	elif qty_milli <= 0:
		refuse = "nothing ordered"
	elif in_port(world).is_empty():
		refuse = "no ship in port"
	if refuse == "":
		for sh in world.table(TABLE)["ships"]:
			if not bool(sh["in_port"]):
				continue
			var room := int(sh["hold"]) * S - _load(sh["taking"])
			if room <= 0:
				continue
			var t := world.table(TABLE)
			t["n"] = int(t["n"]) + 1
			var o := {"id": "order:%d" % int(t["n"]), "buyer": buyer_cid, "item": item, "qty": mini(qty_milli, room),
				"price": home_price(world, item), "month": world.month}
			(sh["taking"] as Array).append(o)
			Logbook.note(world, "IMPORT", buyer_cid, "ordered with the ship in port", why.merged({"asked": qty_milli, "room": room}),
				{"qty": [0, int(o["qty"])], "price": [0, int(o["price"])]}, String(sh["id"]), String(o["id"]))
			return {"ok": true, "why": "", "order": o["id"], "qty": int(o["qty"]), "ship": sh["id"]}
		refuse = "the hold is full"
	Logbook.note(world, "IMPORT", buyer_cid, "order NOT taken", why.merged({"item": item, "asked": qty_milli, "refused": refuse}))
	return {"ok": false, "why": refuse, "order": "", "qty": 0, "ship": ""}


static func _load(orders: Array) -> int:
	var n := 0
	for o in orders:
		n += int(o["qty"])
	return n


# ---------------------------------------------------------------- reads and the home world's hand

## The month of the next call (-1 with no ship); a ship in port counts as now.
static func next_call(world: WorldState) -> int:
	var best := -1
	for sh in world.peek(TABLE).get("ships", []):
		var m := world.month if bool(sh["in_port"]) else int(sh["next"])
		if best < 0 or m < best:
			best = m
	return best


static func last(world: WorldState) -> Dictionary:
	return (world.peek(TABLE).get("last", {}) as Dictionary).duplicate(true)


## Copies of the ship records: [{id, hold, next, in_port, calls, taking, bringing}].
static func fleet(world: WorldState) -> Array:
	return (world.peek(TABLE).get("ships", []) as Array).duplicate(true)


static func hold_of(world: WorldState, idx: int) -> int:
	var ships: Array = world.peek(TABLE).get("ships", [])
	return int(ships[idx]["hold"]) if idx >= 0 and idx < ships.size() else 0


## The home world enlarges a ship or sends one more (politics' home world decides; these only do it).
static func set_hold(world: WorldState, idx: int, hold: int) -> void:
	var ships: Array = world.table(TABLE).get("ships", [])
	if idx < 0 or idx >= ships.size() or hold < 0:
		return
	Logbook.note(world, "SHIP", String(ships[idx]["id"]), "hold changed", {}, {"hold": [int(ships[idx]["hold"]), hold]})
	ships[idx]["hold"] = hold


static func add_ship(world: WorldState, next_month: int, hold: int) -> void:
	var t := world.table(TABLE)
	if not t.has("ships"):
		return
	var id := "ship:%d" % ((t["ships"] as Array).size() + 1)
	(t["ships"] as Array).append({"id": id, "hold": hold, "next": maxi(next_month, world.month + 1), "in_port": false, "calls": 0,
		"taking": [], "bringing": []})
	Logbook.note(world, "SHIP", id, "a new ship sails for the colony", {"hold": hold}, {"next_call": [-1, maxi(next_month, world.month + 1)]})
