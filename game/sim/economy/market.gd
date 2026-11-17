extends RefCounted
## THE MARKET (rebuild plan 9.3, 12.3 points 23a and 27, 12.8 point 50b; planning/rebuild-step3-joins.md).
## Preload it: const Market := preload("res://sim/economy/market.gd"). Static functions; the conductor calls them.
##
## One order book per item and area. Households, companies, plans and the government post ORDERS during SETTLEMENT;
## companies' OFFERS are their stock less what they hold back, at their one price. clear() runs once a month:
##   - for each item and area, the cheapest offer first ("The cheapest delivered offer fills first"; no freight in
##     step 3, so delivered = posted);
##   - every order whose most-it-will-pay is at or above that price shares it in proportion to what it still wants
##     ("A short good is shared in proportion among the buyers offering the same price. No buyer goes first by class");
##   - each pays the seller's price; money moves at once; the goods move at once (stock_move into a company, out of
##     the seller as SOLD for a household, plan or the government, whose side books it from the sale);
##   - each sale is ONE record in table "sale" (50b), which the buyer and seller point to;
##   - an order left unfilled keeps WHY: NO_MONEY (it could pay nothing at all), PRICE (it could pay something but
##     less than the asking price, or its money ran out at that price partway: a refusal of the price, 23a), SOLD_OUT
##     (it would pay, but all offers at its price were sold), NO_SELLER (nobody offered the item there).
## What each seller offered, sold, and what demand it met or turned away is written to its record ("market") for its
## rules; a month's summary per item and area is kept twelve months for rule 7 and for politics.
## Money in milli-credits, quantities in milli-units (CoreUtil.S = 1000 per credit or unit).

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")

const TABLE := "market"
const SALES := "sale"
const KEEP_MONTHS := 12
## Ship goods are less wanted (the user, plan 12.3 15e: "ship food should be considered less desierable"): a buyer
## ranking offers of one item counts ship goods this much dearer than their price, per mille (a starting number,
## Wilma's), so colony goods up to that much dearer are bought first. The buyer pays the seller's real price.
const SHIP_LESS_WANTED_PM := 250
## SITE: a building site's supplies (Otto's contracts), paid from the client's account whoever the client is; the goods
## leave the seller as SOLD and only the site books them, never a company's stock.
const BUYER_KINDS: Array[String] = ["COMPANY", "POOL", "PLAN", "GOV", "SITE"]
const KINDS: Array[String] = ["NEED", "AHEAD"]
const WHYS: Array[String] = ["NO_MONEY", "PRICE", "SOLD_OUT", "NO_SELLER"]
const S := 1000


# ---------------------------------------------------------------- orders

## Posts an order to buy, for this month's clear. buyer: {"kind": COMPANY|POOL|PLAN|GOV|SITE, "id": ..., "acct": its ledger
## account, "area": where it buys}. max_price: the most it will AND can pay per unit, milli-credits (0 = it can pay
## nothing: the order is NO_MONEY). kind: NEED (an ordinary order) or AHEAD (stocking up, plan 9.3); both are real
## orders with money behind them and count alike. budget: the most this order may spend in all, milli-credits (-1: no
## limit beyond the buyer's account). A buyer that sets money aside line by line (households: food, rent, then water
## and power) gives each order its line's money as budget, so no order spends another's money; when the budget runs
## out at the seller's price the order buys less, and its rest is a refusal of the price (23a), as when an account
## runs out. Returns the order id, or "" if refused (bad buyer, item or numbers).
## by: RANK (the default: ship goods counted dearer, 15e) or PRICE (a buyer whose money does not cover its whole need
## takes the cheapest real price first: "less desirable" is a preference, not a reason to go hungry; Wilma, 15e).
static func order(world: WorldState, buyer: Dictionary, item: String, qty_milli: int, max_price: int, kind: String = "NEED", budget: int = -1, by: String = "RANK") -> String:
	if not BUYER_KINDS.has(String(buyer.get("kind", ""))) or String(buyer.get("acct", "")) == "" or not TypeTable.is_item(item):
		return ""
	if bool(TypeTable.ITEMS[item]["grid"]) or qty_milli <= 0 or max_price < 0 or not KINDS.has(kind) or budget < -1 or not by in ["RANK", "PRICE"]:
		return ""
	var st := _state(world)
	var oid := world.new_id("order")
	st["orders"][oid] = {"id": oid, "m": world.month, "buyer": {"kind": String(buyer["kind"]), "id": String(buyer.get("id", "")),
		"acct": String(buyer["acct"]), "area": String(buyer.get("area", ""))}, "item": item, "qty": qty_milli, "max": max_price,
		"kind": kind, "got": 0, "paid": 0, "why": "", "cleared": false, "broke": false, "broke_price": 0, "cash0": 0,
		"budget": budget, "by": by}
	Logbook.note(world, "ORDER", String(buyer.get("id", "")), "order posted", {"item": item, "qty": qty_milli, "max": max_price, "kind": kind,
		"budget": budget, "by": by}, {}, "", oid)
	return oid


## What an order got: {"qty", "paid", "why" ("" if filled in full), "cleared"}. {} for an unknown order. Orders are
## kept until the next month's clear.
static func filled(world: WorldState, oid: String) -> Dictionary:
	var o: Dictionary = world.peek(TABLE).get("orders", {}).get(oid, {})
	if o.is_empty():
		return {}
	return {"qty": int(o["got"]), "paid": int(o["paid"]), "why": String(o["why"]), "cleared": bool(o["cleared"])}


## The offers there are right now for an item in an area: [{"seller", "price", "qty"}], cheapest first, then by id.
## A seller offers its stock less its hold-back and less what waits for freight, at its one price; only OPEN companies.
static func offers(world: WorldState, item: String, area: String) -> Array:
	var out: Array = []
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["status"]) != "OPEN" or String(c["area"]) != area or not (c["price"] as Dictionary).has(item):
			continue
		var s := Company.stock_of(world, cid, item)
		var q := int(s["qty"]) - int(s["waiting"]) - Company.hold_of(world, cid, item)
		if q > 0:
			var price := int(c["price"][item])
			# a stock part ship goods ranks in proportion: all ship goods a quarter dearer, a mixed stock by its share
			var ship_pm := int(s["ship"]) * 1000 / maxi(1, int(s["qty"]))
			out.append({"seller": cid, "price": price, "qty": q, "rank": price * (1000 + SHIP_LESS_WANTED_PM * ship_pm / 1000) / 1000})
	out.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]) or (int(a["rank"]) == int(b["rank"]) and String(a["seller"]) < String(b["seller"])))
	return out


# ---------------------------------------------------------------- the clear

## Offers are filled in order of their rank: the price, ship goods counted dearer (SHIP_LESS_WANTED_PM).
## Clears every order posted this month, item by item and area by area. Once a month, in SETTLEMENT, after all orders
## are posted (the conductor). Orders and sales older than KEEP_MONTHS are dropped first. Returns the number of sales.
static func clear(world: WorldState) -> int:
	var st := _state(world)
	_prune(world, st)
	for cid in Company.ids(world):
		world.table(Company.TABLE)[cid]["market"] = {}
	var books := {}   # item|area -> [order ids]
	for oid in CoreUtil.sorted_keys(st["orders"]):
		var o: Dictionary = st["orders"][oid]
		if int(o["m"]) != world.month or bool(o["cleared"]):
			continue
		var acct := String(o["buyer"]["acct"])
		o["cash0"] = world.ledger.balance(acct) if world.ledger.has_account(acct) else 0
		var k := "%s|%s" % [o["item"], o["buyer"]["area"]]
		if not books.has(k):
			books[k] = []
		books[k].append(oid)
	var n := 0
	var month_sum := {}
	for k in CoreUtil.sorted_keys(books):
		var item := String(k).get_slice("|", 0)
		var area := String(k).substr(item.length() + 1)
		n += _clear_book(world, st, item, area, books[k])
		month_sum[k] = _summarise(st, books[k])
	# a seller whose offer met no order at all still learns it offered and sold nothing (rule 2)
	for cid in Company.ids(world):
		var c: Dictionary = world.table(Company.TABLE)[cid]
		for item in CoreUtil.sorted_keys(c["price"]):
			if (c["market"] as Dictionary).has(item) or books.has("%s|%s" % [item, c["area"]]):
				continue
			for off in offers(world, String(item), String(c["area"])):
				if String(off["seller"]) == cid:
					c["market"][item] = {"offered": int(off["qty"]), "sold": 0, "price": int(off["price"]), "unmet_above": 0, "refused": 0}
	st["sum"][str(world.month)] = month_sum
	st["settled"] = world.month
	return n


static func _clear_book(world: WorldState, st: Dictionary, item: String, area: String, oids: Array) -> int:
	var sales := 0
	var offs := offers(world, item, area)
	# every open company there with a price for the item gets a signal, even with nothing to offer: a seller with no
	# stock still learns what it was asked for at its price (rules 1 and 3; Otto's review)
	var sig := {}
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["status"]) == "OPEN" and String(c["area"]) == area and (c["price"] as Dictionary).has(item):
			sig[cid] = {"offered": 0, "sold": 0, "price": int(c["price"][item]), "unmet_above": 0, "refused": 0}
	for off in offs:
		sig[off["seller"]]["offered"] = int(off["qty"])
	# Each order takes from the first offer in its own sequence that still has stock at or under its most-it-pays: a
	# RANK order in the offers' rank order (ship goods counted dearer), a PRICE order (a buyer whose money does not
	# cover its whole need: Wilma, 15e) in real price order. Offers are visited in rank order; each shares what it has
	# left among the orders it is the next offer for, pro rata by what they still want; passes repeat while anything
	# moves (an order whose cheaper offer ran out turns to its next one). With every order RANK this is one sale per
	# offer in rank order, shared among all who would pay it, as before.
	var left: Array = offs.map(func(off): return int(off["qty"]))
	var by_price: Array = range(offs.size())
	by_price.sort_custom(func(a, b): return int(offs[a]["price"]) < int(offs[b]["price"]) or (int(offs[a]["price"]) == int(offs[b]["price"]) and int(a) < int(b)))
	var progress := true
	while progress:
		progress = false
		for i in offs.size():
			var seller := String(offs[i]["seller"])
			var price := int(offs[i]["price"])
			# share among the orders this offer is next for; repeat while money shortfalls free some of the offer
			while int(left[i]) > 0:
				var takers: Array = []
				var weights: Array = []
				for oid in oids:
					var o: Dictionary = st["orders"][oid]
					var want := int(o["qty"]) - int(o["got"])
					if want > 0 and not bool(o["broke"]) and _next_offer(offs, left, by_price, o) == i:
						takers.append(oid)
						weights.append(float(want))
				if takers.is_empty():
					break
				var total := 0
				for wv in weights:
					total += int(wv)
				var shares: Array = CoreUtil.split_lr(mini(int(left[i]), total), weights)
				var moved := 0
				for k in takers.size():
					var q := int(shares[k])
					if q <= 0:
						continue
					var got := _sell(world, st, seller, String(takers[k]), item, q, price)
					moved += got
					if got > 0:
						sales += 1
						if not st.has("last"):
							st["last"] = {}
						st["last"][item + "|" + area] = {"price": price, "m": world.month}
				left[i] = int(left[i]) - moved
				sig[seller]["sold"] = int(sig[seller]["sold"]) + moved
				if moved == 0:
					break
				progress = true
	# why each order is short
	var cheapest_left := -1   # the cheapest offer left unsold, to tell a refusal of the price from sold out
	for off in offs:
		var unsold := int(sig[off["seller"]]["offered"]) - int(sig[off["seller"]]["sold"])
		if unsold > 0 and (cheapest_left < 0 or int(off["price"]) < cheapest_left):
			cheapest_left = int(off["price"])
	for oid in oids:
		var o: Dictionary = st["orders"][oid]
		var short := int(o["qty"]) - int(o["got"])
		o["cleared"] = true
		if short <= 0:
			continue
		if int(o["max"]) <= 0 or int(o["cash0"]) <= 0 or int(o["budget"]) == 0:
			o["why"] = "NO_MONEY"   # it could pay nothing at all: the only case that is not price (23a)
		elif bool(o["broke"]):
			o["why"] = "PRICE"      # it paid for some, and could not pay THIS price for the rest: a refusal of the price
		elif offs.is_empty():
			o["why"] = "NO_SELLER"
		elif cheapest_left >= 0 and int(o["max"]) < cheapest_left:
			o["why"] = "PRICE"
		else:
			o["why"] = "SOLD_OUT"
		Logbook.note(world, "ORDER", String(o["buyer"]["id"]), "order short", {"item": item, "why": o["why"], "max": o["max"]},
			{"short": [0, short]}, "", oid)
		_turned_away(world, sig, o, short)
	for s in sig:
		world.table(Company.TABLE)[s]["market"][item] = sig[s]
	return sales


## The index in offs of the next offer an order takes from: the first in its own sequence (rank order, or real price
## order for a PRICE order) with stock left, at or under its most-it-pays, and not its own. -1 if none.
static func _next_offer(offs: Array, left: Array, by_price: Array, o: Dictionary) -> int:
	var seq: Array = by_price if String(o.get("by", "RANK")) == "PRICE" else range(offs.size())
	for i in seq:
		if int(left[i]) > 0 and int(offs[i]["price"]) <= int(o["max"]) and String(offs[i]["seller"]) != String(o["buyer"]["id"]):
			return int(i)
	return -1


## Shares one order's shortfall among the sellers who turned it away, so the sum over sellers is the real shortfall
## (Otto's review): SOLD_OUT or NO_SELLER goes to every seller at or under its price that had nothing left, in
## proportion to what it offered plus what its plants can make (so a seller with no stock still learns it, rule 1 and
## 3); PRICE goes to every seller above what the order could pay that still had stock, in proportion to what it had
## left (rule 2).
static func _turned_away(world: WorldState, sig: Dictionary, o: Dictionary, short: int) -> void:
	var why := String(o["why"])
	var to: Array = []
	var weights: Array = []
	for s in CoreUtil.sorted_keys(sig):
		var p := int(sig[s]["price"])
		var unsold := int(sig[s]["offered"]) - int(sig[s]["sold"])
		if (why == "SOLD_OUT" or why == "NO_SELLER") and p <= int(o["max"]) and unsold <= 0:
			to.append(s)
			weights.append(float(int(sig[s]["offered"]) + _capacity(world, String(s))))
		elif why == "PRICE" and unsold > 0 and (p > int(o["max"]) or (bool(o["broke"]) and p >= int(o["broke_price"]))):
			to.append(s)
			weights.append(float(unsold))
	if to.is_empty():
		return
	var sum := 0.0
	for wv in weights:
		sum += float(wv)
	if sum <= 0.0:
		weights = to.map(func(_x): return 1.0)
	var parts: Array = CoreUtil.split_lr(short, weights)
	var key := "refused" if why == "PRICE" else "unmet_above"
	for i in to.size():
		sig[to[i]][key] = int(sig[to[i]][key]) + int(parts[i])


## What a company's open plants make in a month at full, milli-units (its crew's full output if it has crew posts and
## no plant): the weight for sharing what it turned away.
static func _capacity(world: WorldState, cid: String) -> int:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var n := 0
	for pid in c["plants"]:
		var p := Company.plant(world, String(pid))
		if not bool(p["closed"]):
			n += TypeTable.output_milli(String(c["type"]), String(p["size"]), int(c["line"]))
	if n == 0 and bool(c.get("crew_posts", false)):
		n = TypeTable.output_milli(String(c["type"]), String(c["size"]), int(c["line"]))
	return n


## One sale: money from the buyer (as much as it holds, at most q), the goods from the seller, one sale record.
## Returns the quantity sold. A buyer whose money runs out at this price is marked broke: it takes no more this month,
## and its rest is a refusal of the price (23a), unless it could pay nothing at all from the start (NO_MONEY).
static func _sell(world: WorldState, st: Dictionary, seller: String, oid: String, item: String, q: int, price: int) -> int:
	var o: Dictionary = st["orders"][oid]
	var acct := String(o["buyer"]["acct"])
	var cash := world.ledger.balance(acct) if world.ledger.has_account(acct) else 0
	if int(o["budget"]) >= 0:
		cash = mini(cash, int(o["budget"]) - int(o["paid"]))   # what is left of this order's own money
	var afford := q if price <= 0 else mini(q, maxi(0, cash) * S / price)
	if afford < q:
		o["broke"] = true
		o["broke_price"] = price
	if afford <= 0:
		return 0
	var pay := afford * price / S
	if pay > 0 and not world.ledger.transfer(acct, CoreUtil.acct(seller), pay, "SALE:" + item, world.month):
		o["broke"] = true
		o["broke_price"] = price
		return 0
	var moved := false
	if String(o["buyer"]["kind"]) == "COMPANY":
		moved = Company.stock_move(world, seller, String(o["buyer"]["id"]), item, afford, price, "bought")
	else:
		moved = Company.stock_take(world, seller, item, afford, "SOLD", "sold to %s" % o["buyer"]["id"]) >= 0
	assert(moved, "the market sold goods the seller did not hold")
	o["got"] = int(o["got"]) + afford
	o["paid"] = int(o["paid"]) + pay
	var sid := world.new_id("sale")
	world.table(SALES)[sid] = {"id": sid, "m": world.month, "item": item, "qty": afford, "price": price, "paid": pay,
		"seller": seller, "buyer": String(o["buyer"]["id"]), "buyer_kind": String(o["buyer"]["kind"]), "order": oid}
	Company.book(world, seller, "rev", pay)
	Company.book(world, seller, "sold:" + item, afford)
	if String(o["buyer"]["kind"]) == "COMPANY":
		Company.book(world, String(o["buyer"]["id"]), "bought", pay)
	Logbook.note(world, "SALE", seller, "sold " + item, {"price": price, "order": oid}, {"qty": [0, afford], "paid": [0, pay]},
		String(o["buyer"]["id"]), sid)
	return afford


static func _summarise(st: Dictionary, oids: Array) -> Dictionary:
	var out := {"ordered": 0, "filled": 0, "paid": 0, "unfilled": {"NO_MONEY": 0, "PRICE": 0, "SOLD_OUT": 0, "NO_SELLER": 0}}
	for oid in oids:
		var o: Dictionary = st["orders"][oid]
		out["ordered"] += int(o["qty"])
		out["filled"] += int(o["got"])
		out["paid"] += int(o["paid"])
		var short := int(o["qty"]) - int(o["got"])
		if short > 0 and WHYS.has(String(o["why"])):
			out["unfilled"][o["why"]] += short
	return out


# ---------------------------------------------------------------- reading

## The month of the last clear, or -1 if the market has never cleared.
static func last_settled_month(world: WorldState) -> int:
	return int(world.peek(TABLE).get("settled", -1))


## One month's figures for an item: {"ordered", "filled", "paid", "avg_price", "unfilled": {why: qty}}. area "" sums
## every area; month -1 is the last settled month. All zero for a month or item with no orders.
static func summary(world: WorldState, item: String, area: String = "", month: int = -1) -> Dictionary:
	var m := last_settled_month(world) if month < 0 else month
	var out := {"ordered": 0, "filled": 0, "paid": 0, "avg_price": 0, "unfilled": {"NO_MONEY": 0, "PRICE": 0, "SOLD_OUT": 0, "NO_SELLER": 0}}
	var sums: Dictionary = world.peek(TABLE).get("sum", {}).get(str(m), {})
	for k in sums:
		if String(k).get_slice("|", 0) != item:
			continue
		if area != "" and String(k).substr(item.length() + 1) != area:
			continue
		var s: Dictionary = sums[k]
		for f in ["ordered", "filled", "paid"]:
			out[f] += int(s[f])
		for w in WHYS:
			out["unfilled"][w] += int(s["unfilled"][w])
	out["avg_price"] = 0 if int(out["filled"]) == 0 else int(out["paid"]) * S / int(out["filled"])
	return out


## The last `months` settled months' summaries for an item and area, oldest first (each with its "m").
static func history(world: WorldState, item: String, area: String, months: int = KEEP_MONTHS) -> Array:
	var out: Array = []
	var ms: Array = []
	for k in world.peek(TABLE).get("sum", {}):
		ms.append(int(k))
	ms.sort()
	for m in ms.slice(maxi(0, ms.size() - months)):
		var s := summary(world, item, area, m)
		s["m"] = m
		out.append(s)
	return out


## A sale record (a copy), or {}.
## The price `item` last sold at in `area` (milli-credits), and the month: {"price", "m"}, or {} if it never sold
## there. Kept for good (one entry per item and area), not pruned with the sale records.
static func last_sold(world: WorldState, item: String, area: String) -> Dictionary:
	return (world.peek(TABLE).get("last", {}).get(item + "|" + area, {}) as Dictionary).duplicate()


static func sale(world: WorldState, sid: String) -> Dictionary:
	return (world.peek(SALES).get(sid, {}) as Dictionary).duplicate(true)


## What a company's market looked like this month for one thing it sells: {"offered", "sold", "price", "unmet_above",
## "refused"}, or {} if it offered none. For its rules (rule 1 reads unmet_above, rule 2 reads offered - sold).
static func seller_signal(world: WorldState, cid: String, item: String) -> Dictionary:
	return (world.peek(Company.TABLE).get(cid, {}).get("market", {}).get(item, {}) as Dictionary).duplicate()


# ---------------------------------------------------------------- inside

static func _state(world: WorldState) -> Dictionary:
	var t := world.table(TABLE)
	if not t.has("orders"):
		t["orders"] = {}
		t["sum"] = {}
		t["settled"] = -1
	return t


static func _prune(world: WorldState, st: Dictionary) -> void:
	for oid in st["orders"].keys():
		if int(st["orders"][oid]["m"]) < world.month:
			st["orders"].erase(oid)
	for k in st["sum"].keys():
		if int(k) <= world.month - KEEP_MONTHS:
			st["sum"].erase(k)
	var sales := world.table(SALES)
	for sid in sales.keys():
		if int(sales[sid]["m"]) <= world.month - KEEP_MONTHS:
			sales.erase(sid)
