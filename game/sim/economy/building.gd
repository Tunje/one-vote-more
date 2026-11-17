extends RefCounted
## THE PLAN, THE BUILDING CONTRACT AND THE OPENING OF A PLANT, in their plainest form (rebuild step 3; Otto).
## Built from planning/rebuild-building.md section 4 and planning/rebuild-step3-joins.md; the plan's 8.1, 9.7, 12.9.
## Preload, no class_name: const Building := preload("res://sim/economy/building.gd").
##
## "PLANS ARE MADE BEFORE THEY BECOME COMPANIES DAMNED IT ALL THAT'S BEFORE ACCEPTING A GRANT"; "you can't fail before
## you exist ... no worker but also no expenses beyond building"; "they should need 3 months up front and add 1 month of
## additional supplies every month".
##
## Two tables of its own, each thing recorded once (plan 12.8, 50b):
## - "plan": a plan is not a company. It has an account of its own ("plan:N", the plan's id), a founder (a person), a
##   held site, and nothing else: no staff, no stock, no price. Never counted as founded or dead.
## - "contract": the deal between a client and a builder. Its record holds the work done, the supplies on the site and
##   built in, the price fixed at signing, what was paid and what is owed. A builder's BOOK is its contracts in signing
##   order (contract number), read from this table; the company record keeps no copy.
##
## Units: money milli-credits (CoreUtil.S per credit), quantities milli-units, building work milli-BW. One BW is one
## builder worker's month at full output (rebuild-building 2).
##
## Called by the conductor (sim/economy/month.gd) in the order of the joins:
##   PRODUCTION: open_due (first), work_month (after Making)
##   SETTLEMENT: supply_orders (orders posted), take_deliveries (after Market.clear), bill_month (before wages)
##   COMPANY_AI: make_plan (in the founding sequence), sign_round
## Every decision and deed writes a Logbook row with the numbers it read.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const HomeBuilders := preload("res://sim/economy/home_builders.gd")
const Market := preload("res://sim/economy/market.gd")
const Rules := preload("res://sim/economy/rules.gd")
const Grants := preload("res://sim/economy/grants.gd")
const Households := preload("res://sim/population/households.gd")
const Site := preload("res://sim/transport/site.gd")
const LandLaw := preload("res://sim/law/land_law.gd")
const LawCompany := preload("res://sim/law/law_company.gd")

const S := CoreUtil.S
const PLAN := "plan"
const CONTRACT := "contract"
const MONTH := "building_month"   # each builder's last month of work, for its signals
const OPENED := "building_market"  # {"first_quote_m": the month the first plan in the colony asked for quotes}
const ITEMS := ["MATERIAL", "COMPONENT"]
const UP_FRONT_M := 3             # "3 months up front" (the user)
const OPENING_M := 3              # a founder counts three months of running costs as opening money (Wilma: accepted)


# ================================================================ pure: estimates and what a founder needs

## The price per BW of the live builders, averaged (milli-credits); the starting price when there are none.
static func bw_price(world: WorldState) -> int:
	var sum := 0
	var n := 0
	for b in builders(world):
		sum += Company.price(world, b, "BW")
		n += 1
	return sum / n if n > 0 else TypeTable.start_price("BW")


## The price a buyer would pay for an item now: the cheapest offer on the market, else its starting price.
static func item_price(world: WorldState, item: String, area: String) -> int:
	var best := -1
	for o in Market.offers(world, item, area):
		var p := int(o.get("price", -1))
		if p >= 0 and (best < 0 or p < best):
			best = p
	return best if best >= 0 else TypeTable.start_price(item)


## The building's bill for a type and size at today's prices (rebuild-building 4.3), milli-credits. land: on an
## ordinary place (value 1000) when no site is given, else at the site's value (Terra's land price).
static func estimate(world: WorldState, type: String, size: String, area: String, site: Dictionary = {}) -> Dictionary:
	var b := TypeTable.bill(type, size)
	var work := int(b["bw"]) * bw_price(world) / S
	var supplies := int(b["material"]) * item_price(world, "MATERIAL", area) / S + int(b["component"]) * item_price(world, "COMPONENT", area) / S
	var bill_cr := Site.bill_credits(type, size)
	var land := (Site.land_price(world, site, bill_cr) if not site.is_empty() else bill_cr / 10) * S
	return {"bw": int(b["bw"]), "material": int(b["material"]), "component": int(b["component"]), "months": int(b["months"]),
		"work": work, "supplies": supplies, "land": land, "total": work + supplies}


## What a founder needs in hand to plan this (rebuild-building 4.2): land + the building + three months of running
## costs (Bob's Rules.running_cost, the same figure rule 7 compares the work with). A founder's own reckoning, not a
## gate (Wilma, step-2 brief).
static func founder_needs(world: WorldState, type: String, size: String, area: String) -> int:
	var e := estimate(world, type, size, area)
	return int(e["land"]) + int(e["total"]) + OPENING_M * Rules.running_cost(world, type, size, area)


## The sizes of a type that pass rule 7 in an area now (Bob's Rules.founding: {size: {covers}}).
## except_plan: the plan re-reading rule 7 for itself (sign_round), which must not count itself among the plans rule 7
## sees (it is seen through its grant before it signs; the user, plan 12.3 15a).
static func passing_sizes(world: WorldState, type: String, area: String, except_plan: String = "") -> Array:
	var f: Dictionary = Rules.founding(world, type, area, false, except_plan)
	var out: Array = []
	for size in TypeTable.SIZES:
		if bool(f.get(size, {}).get("covers", false)):
			out.append(size)
	return out


## The plans of `type` in `area` booked on a builder and not opened yet: {plan id: sixths} (pure). "It does not see
## plans made, but they do see plans booked on builders notes and plans that have accepted grants" (the user, plan
## 12.3 15a): a plan is booked from its signing until it opens (then its plant counts) or is given up. A job DONE and
## opening next month, or STOPPED for want of pay, is still booked. Keyed by plan, so rule 7 counts a plan that is both
## booked and granted once (Bob). except_plan is left out.
static func booked_plans(world: WorldState, type: String, area: String, except_plan: String = "") -> Dictionary:
	return _plans_at(world, "SIGNED", type, area, except_plan)


## The plans of `type` in `area` still only made, not booked on a builder: {plan id: sixths} (pure). Rule 7 keeps
## those that have accepted a grant (Grants.granted_plans, Ella's), so a granted plan counts while MADE and as booked
## once SIGNED: once either way (Bob). except_plan is left out.
static func made_plans(world: WorldState, type: String, area: String, except_plan: String = "") -> Dictionary:
	return _plans_at(world, "MADE", type, area, except_plan)


static func _plans_at(world: WorldState, status: String, type: String, area: String, except_plan: String) -> Dictionary:
	var out := {}
	for pid in CoreUtil.sorted_keys(world.peek(PLAN)):
		var p: Dictionary = world.peek(PLAN)[pid]
		if String(pid) == except_plan or String(p["status"]) != status or String(p["type"]) != type or String(p["area"]) != area:
			continue
		out[pid] = TypeTable.sixths(String(p["size"]))
	return out


## The sixths of every plan of `type` in `area` booked on a builder and not opened yet (pure; booked_plans summed).
static func booked(world: WorldState, type: String, area: String, except_plan: String = "") -> int:
	var n := 0
	var bp := booked_plans(world, type, area, except_plan)
	for pid in bp:
		n += int(bp[pid])
	return n


# ================================================================ the plan (COMPANY_AI, the founding sequence)

## Makes a plan for founder `person_id` ("founder:N", Maja's; its ledger account is the same string; counted individually, 12.9 60a): holds its site, opens its account and
## moves the founder's money in (as much as founder_needs, or all they have if less). Returns the plan id, or "" if
## the site cannot be held (a row says why).
static func make_plan(world: WorldState, person_id: String, type: String, size: String, area: String, site: Dictionary, why: Dictionary = {}) -> String:
	var id := world.new_id(PLAN)
	var hold := Site.hold(world, id, type, TypeTable.sixths(size), site)
	if hold != "":
		Logbook.note(world, "PLAN", id, "not made: the site cannot be held", why.merged({"type": type, "size": size, "site_why": hold}), {}, person_id)
		return ""
	world.ledger.open_account(account(id))
	var need := founder_needs(world, type, size, area)
	var have := maxi(0, world.ledger.balance(person_id)) if world.ledger.has_account(person_id) else 0
	var moved := CoreUtil.pay_upto(world, person_id, account(id), mini(need, have), "PLAN_FUNDS") if have > 0 else 0
	world.table(PLAN)[id] = {"id": id, "n": _num(id), "founder": person_id, "type": type, "size": size, "area": area,
		"site": _place_of(site), "status": "MADE", "made": world.month, "contract": "", "company": "",
		"cost": {"land": 0, "work": 0, "supplies": 0}}
	Logbook.note(world, "PLAN", id, "plan made", why.merged({"type": type, "size": size, "area": area, "needs": need / S,
		"founder_had": have / S}), {"plan_account": [0, moved / S]}, person_id)
	return id


## Where a site is, without how it scored: the score and its parts are decimals, and the game's state holds whole
## numbers and text only (a decimal does not survive the save file exactly). Found on merge by the save/load tests.
static func _place_of(site: Dictionary) -> Dictionary:
	var out := {}
	for k in ["where", "town", "cells", "tile", "block"]:
		if site.has(k):
			out[k] = site[k].duplicate() if site[k] is Array else site[k]
	return out


static func account(plan_id: String) -> String:
	return plan_id


## Every live builder (a BUILDER company), sorted by id.
## for_hire: only the builders a plan can hire, the ones with a crew (who can quote and take work) and not the public
## works department, which builds only when the government commissions it (plan 99; rebuild-building 4.1: idle in
## step 3). The average price per BW is read over these too. A builder whose crew was laid off keeps its book:
## work_month still runs it (it does nothing, and its month record shows why), so its jobs wait for it (Bob's review).
static func builders(world: WorldState, for_hire: bool = true) -> Array:
	var out: Array = []
	for cid in Company.ids(world):
		var r := Company.record(world, cid)
		if Company.type_of(world, cid) != "BUILDER" or String(r.get("status", "")) != "OPEN":
			continue
		if for_hire and String(r.get("origin", "")) == HomeBuilders.ORIGIN_PUBLIC:
			continue
		if not for_hire or HomeBuilders.bw_milli(world, cid) > 0:
			out.append(cid)
	return out


## Quotes from every live builder for a plan (rebuild-building 4.3). Pure. Each: {builder, bw_price, work, supplies,
## total (milli-credits), start (the month work would begin)}.
static func quotes(world: WorldState, plan_id: String) -> Array:
	var p: Dictionary = world.peek(PLAN).get(plan_id, {})
	if p.is_empty():
		return []
	var e := estimate(world, String(p["type"]), String(p["size"]), String(p["area"]), p["site"])
	var out: Array = []
	for b in builders(world):
		var px := Company.price(world, b, "BW")
		var work := int(e["bw"]) * px / S
		out.append({"builder": b, "bw_price": px, "work": work, "supplies": int(e["supplies"]), "total": work + int(e["supplies"]),
			"start": start_month(world, b)})
	return out


## The month a newly signed job would get crews from builder `b`: the work ahead of it in the book at the builder's
## present crew, after the month its first supplies take to arrive (signed in COMPANY_AI, bought next SETTLEMENT,
## worked the PRODUCTION after: the joins' timing). Pure.
static func start_month(world: WorldState, b: String) -> int:
	var ahead := 0
	for cid in book(world, b):
		var c: Dictionary = world.peek(CONTRACT)[cid]
		ahead += int(c["bill"]["bw"]) - int(c["done"])
	var cap := maxi(1, HomeBuilders.bw_milli(world, b))
	return world.month + 2 + ahead / cap


## A builder's book: its open contracts (not DONE, not ABANDONED) in signing order.
static func book(world: WorldState, b: String) -> Array:
	var rows: Array = []
	for cid in world.peek(CONTRACT):
		var c: Dictionary = world.peek(CONTRACT)[cid]
		if String(c["builder"]) == b and not String(c["status"]) in ["DONE", "ABANDONED"]:
			rows.append([int(c["n"]), cid])
	rows.sort()
	return rows.map(func(r): return r[1])


## Each plan still MADE, in plan order (rebuild-building 4.4): reads rule 7 again, asks the law, takes the lowest
## quote (earliest start on a tie), and signs if its account covers the land and the quote; buys the land and writes
## the contract. A plan that cannot pay waits a month; one whose signal has gone, or that has no builder, is given up.
static func sign_round(world: WorldState) -> void:
	for pid in _plans(world, "MADE"):
		var p: Dictionary = world.table(PLAN)[pid]
		if builders(world).is_empty():
			give_up(world, pid, "no builder")
			continue
		if not passing_sizes(world, String(p["type"]), String(p["area"]), pid).has(String(p["size"])):
			give_up(world, pid, "the work is no longer there (rule 7)")
			continue
		var law: Dictionary = LawCompany.may_sign(world, pid, String(p["type"]), p["site"])
		if not bool(law.get("ok", false)):
			Logbook.note(world, "PLAN", pid, "waits: the law", {"why": law.get("reasons", [])})
			continue
		var qs := quotes(world, pid)
		if not qs.is_empty() and first_quote_month(world) < 0:
			world.table(OPENED)["first_quote_m"] = world.month
			Logbook.note(world, "QUOTE", "builders", "the first plan asked the builders for quotes: their market is open",
				{"plan": pid, "builders": qs.size()}, {}, pid)
		# "He should look for the shortest time" (the user, plan 12.3 15d): the earliest start first, the lowest total
		# between equal starts. A far start is still taken: the soonest builder there is.
		qs.sort_custom(func(a, b): return int(a["start"]) < int(b["start"]) or (int(a["start"]) == int(b["start"]) and (int(a["total"]) < int(b["total"]) or (int(a["total"]) == int(b["total"]) and String(a["builder"]) < String(b["builder"])))))
		var cheapest: Dictionary = qs[0]
		for qq in qs:
			if int(qq["total"]) < int(cheapest["total"]):
				cheapest = qq
		var land := int(Site.land_terms(world, pid).get("due", 0))   # what the land costs at signing: its price, or a lease's first rent (Terra)
		var have := world.ledger.balance(account(pid))
		for qq in qs:
			Logbook.note(world, "QUOTE", String(qq["builder"]), "quoted", {"total": int(qq["total"]) / S, "start": qq["start"],
				"bw_price": int(qq["bw_price"]) / S}, {}, pid, pid)
		# the soonest quote its money covers; the sooner ones it cannot pay (or all, when it can pay none) are quotes
		# refused for their price (23a): the plan's BW once, shared among them, as the market shares a shortfall
		# among the sellers, not counted at each (Bob's review)
		var bw_bill := int(TypeTable.bill(String(p["type"]), String(p["size"]))["bw"])
		var q := {}
		var refused: Array = []
		for qq in qs:
			if have >= land + int(qq["total"]):
				q = qq
				break
			refused.append(String(qq["builder"]))
		for i in refused.size():
			# equal parts; the remainder one milli-BW each to the first, so the parts add up to the bill exactly
			var part := bw_bill / refused.size() + (1 if i < bw_bill % refused.size() else 0)
			_month_stat(world, String(refused[i]), "refused_pending", part)
		if q.is_empty():
			Logbook.note(world, "PLAN", pid, "waits: its money does not cover the land and any quote",
				{"has": have / S, "land": land / S, "lowest": int(cheapest["total"]) / S}, {}, String(cheapest["builder"]))
			continue
		var bought: Dictionary = Site.buy_land(world, pid, account(pid))
		if not bool(bought.get("ok", false)):
			Logbook.note(world, "PLAN", pid, "waits: the land", {"why": bought.get("why", "")})
			continue
		p["cost"]["land"] = int(bought.get("due", land))
		_sign(world, pid, q, cheapest)
		# asked for now and not to be had now: the plan waits behind the builder's book (later than the earliest any
		# builder could start, month + 2). Counted once, in the month it signs; the waiting book is never counted
		# again (Wilma's decision; the reading agreed with Bob)
		if int(q["start"]) > world.month + 2:
			_month_stat(world, String(q["builder"]), "unmet_pending", bw_bill)
			Logbook.note(world, "PLAN", pid, "signed to wait behind the builder's book", {"start": int(q["start"]),
				"earliest": world.month + 2, "bw": bw_bill / S}, {}, String(q["builder"]))


## cheapest: the lowest quote the plan had, for the CONTRACT row (what choosing the soonest cost; Wilma).
static func _sign(world: WorldState, pid: String, q: Dictionary, cheapest: Dictionary = {}) -> String:
	var p: Dictionary = world.table(PLAN)[pid]
	var b := String(q["builder"])
	var bill := TypeTable.bill(String(p["type"]), String(p["size"]))
	var cid := world.new_id(CONTRACT)
	var worth := {}
	for it in ITEMS:
		worth[it] = item_price(world, it, String(p["area"]))
	world.table(CONTRACT)[cid] = {"id": cid, "n": _num(cid), "kind": "NEW_PLANT", "client": pid, "client_acct": account(pid),
		"plan": pid, "builder": b, "type": p["type"], "size": p["size"], "area": p["area"],
		"bill": {"bw": int(bill["bw"]), "MATERIAL": int(bill["material"]), "COMPONENT": int(bill["component"])},
		"months": int(bill["months"]), "price_bw": int(q["bw_price"]), "wage_bw": wage_bw(world, b), "worth": worth,
		"signed": world.month, "start_quoted": int(q["start"]), "status": "SIGNED", "done": 0, "done_month": -1,
		"on_site": {"MATERIAL": 0, "COMPONENT": 0}, "used": {"MATERIAL": 0, "COMPONENT": 0},
		"delivered": {"MATERIAL": 0, "COMPONENT": 0}, "orders": {}, "bw_month": 0,
		"paid": 0, "owed": 0, "unpaid_m": 0}
	p["status"] = "SIGNED"
	p["contract"] = cid
	var low := cheapest if not cheapest.is_empty() else q
	Logbook.note(world, "CONTRACT", cid, "signed", {"price_bw": int(q["bw_price"]) / S, "quote": int(q["total"]) / S,
		"start": q["start"], "bw": int(bill["bw"]) / S, "material": int(bill["material"]) / S,
		"cheapest_quote": int(low["total"]) / S, "cheapest_start": low["start"], "cheapest_builder": String(low["builder"])},
		{"status": ["", "SIGNED"]}, b, pid)
	_fact(world, "ECON_CONTRACT_AWARDED", b, 20, {"contract": cid, "plan": pid, "type": p["type"], "price": int(q["total"]) / S})
	return cid


## A plan given up by its owner (rebuild-building 4.4 and 4.9; plan 12.9, 60b). Before signing nothing has been
## spent: the site is released and the money goes back. After signing the builder keeps what it was paid, the land
## and the half-built building stay the founder's (the site stays held under the plan), what is owed is recorded. The
## grant is reclaimed; the founder returns to their pool. Never counted as a failed company.
static func give_up(world: WorldState, pid: String, why: String) -> void:
	var p: Dictionary = world.table(PLAN).get(pid, {})
	if p.is_empty() or String(p["status"]) in ["OPEN", "GIVEN_UP"]:
		return
	var signed := String(p["contract"]) != ""
	var owed := 0
	if signed:
		var c: Dictionary = world.table(CONTRACT)[p["contract"]]
		owed = int(c["owed"])
		if String(c["status"]) != "DONE":
			c["status"] = "ABANDONED"
			_fact(world, "ECON_PROJECT_CANCELLED", String(c["builder"]), 25, {"contract": c["id"], "plan": pid, "why": why})
	else:
		Site.release(world, pid, "plan given up: " + why)
	var reclaimed: int = Grants.reclaim(world, pid)
	var back := maxi(0, world.ledger.balance(account(pid)))
	if back > 0:
		CoreUtil.pay_upto(world, account(pid), String(p["founder"]), back, "PLAN_RETURNED")
	p["status"] = "GIVEN_UP"
	p["given_up"] = world.month
	Households.disown(world, String(p["founder"]), pid)
	Households.release_founder(world, String(p["founder"]))
	Logbook.note(world, "PLAN", pid, "given up", {"why": why, "signed": signed, "owed_to_builder": owed / S, "grant_reclaimed": reclaimed / S},
		{"status": ["", "GIVEN_UP"], "back_to_founder": [0, back / S]}, String(p["founder"]))
	_fact(world, "COMP_PLAN_ABANDONED", String(p["founder"]), 15, {"plan": pid, "type": p["type"], "why": why})


# ================================================================ supplies (SETTLEMENT)

## A month of supplies for a job: the bill's item × (the BW a month planned / the bill's BW).
static func month_need(c: Dictionary, item: String) -> int:
	var bw := int(c["bill"]["bw"])
	return int(c["bill"][item]) * planned_bw(c) / maxi(1, bw)


## The BW a month a job takes: its bill over its fewest months (the builder's crew may give less).
static func planned_bw(c: Dictionary) -> int:
	var bw := int(c["bill"]["bw"])
	return (bw + int(c["months"]) - 1) / maxi(1, int(c["months"]))


## The client's orders for its site, placed by the builder on its behalf (rebuild-building 4.5): keep three months of
## supplies on the site, or the rest of the bill if less. A job being worked orders; a job not started orders only
## when it is next in line to start (next_in_line), not at signing: "up front" is before the work, and material bought
## years early is not that (Wilma's decision on the seed-6 probe). The order carries the client's account and its worth
## (the price in its estimate at signing). Orders go to the market; a STOPPED job orders nothing.
static func supply_orders(world: WorldState) -> void:
	var next := next_in_line(world)
	for cid in CoreUtil.sorted_keys(world.peek(CONTRACT)):
		var c: Dictionary = world.table(CONTRACT)[cid]
		c["orders"] = {}
		var st := String(c["status"])
		if st != "WORKING" and not (st == "SIGNED" and next.has(cid)):
			continue
		for it in ITEMS:
			var total := int(c["bill"][it])
			if total <= 0:
				continue
			var still := total - int(c["used"][it]) - int(c["on_site"][it])
			var want := mini(UP_FRONT_M * month_need(c, it) - int(c["on_site"][it]), still)
			if want <= 0:
				continue
			# a site is never a company's stock, whoever pays: the goods leave the seller as SOLD and the site books them
			# (Bob's review), with the client's account paying
			var buyer := {"kind": "SITE", "id": cid, "acct": String(c["client_acct"]), "area": String(c["area"])}
			var oid: String = Market.order(world, buyer, it, want, int(c["worth"][it]), "NEED")
			if oid == "":
				continue
			c["orders"][it] = oid
			Logbook.note(world, "SUPPLY", cid, "ordered for the site", {"item": it, "qty": want, "worth": int(c["worth"][it]),
				"on_site": int(c["on_site"][it]), "month_need": month_need(c, it)}, {}, String(c["client"]), oid)


## The jobs not yet started that are next in line to start, {contract id: true} (pure). For each builder, in its
## book's order: the first job not started is next in line; so is every further one that next month's crews would
## also reach, counting the crews the jobs being worked will still need (each its planned BW, or what is left of its
## bill if less). A builder without crews still has its first waiting job next in line.
static func next_in_line(world: WorldState) -> Dictionary:
	var out := {}
	for b in builders(world, false):
		var free := HomeBuilders.bw_milli(world, b)
		var waiting: Array = []
		for cid in book(world, b):
			var c: Dictionary = world.peek(CONTRACT)[cid]
			var left := int(c["bill"]["bw"]) - int(c["done"])
			match String(c["status"]):
				"WORKING":
					free -= mini(planned_bw(c), left)
				"SIGNED":
					waiting.append(cid)
		for i in waiting.size():
			if i > 0 and free <= 0:
				break
			var c2: Dictionary = world.peek(CONTRACT)[waiting[i]]
			out[waiting[i]] = true
			free -= mini(planned_bw(c2), int(c2["bill"]["bw"]) - int(c2["done"]))
	return out


## What the market filled for the sites is booked on them (the sale took it out of the seller as SOLD; joins).
static func take_deliveries(world: WorldState) -> void:
	for cid in CoreUtil.sorted_keys(world.peek(CONTRACT)):
		var c: Dictionary = world.table(CONTRACT)[cid]
		for it in CoreUtil.sorted_keys(c["orders"]):
			var f: Dictionary = Market.filled(world, String(c["orders"][it]))
			var q := int(f.get("qty", 0))
			if q <= 0:
				continue
			var old := int(c["on_site"][it])
			c["on_site"][it] = old + q
			c["delivered"][it] = int(c["delivered"][it]) + q
			var cost := int(f.get("paid", 0))
			if world.peek(PLAN).has(String(c["plan"])):
				world.table(PLAN)[c["plan"]]["cost"]["supplies"] = int(world.peek(PLAN)[c["plan"]]["cost"]["supplies"]) + cost
			Logbook.note(world, "SUPPLY", cid, "delivered to the site", {"item": it, "qty": q, "paid": cost,
				"short_why": f.get("why", "")}, {"on_site_" + it: [old, old + q]}, String(c["client"]), String(c["orders"][it]))
		c["orders"] = {}


## Goods lying on building sites (for the goods check: "nothing appears or vanishes").
static func goods_on_sites(world: WorldState) -> Dictionary:
	var out := {"MATERIAL": 0, "COMPONENT": 0}
	for cid in world.peek(CONTRACT):
		for it in ITEMS:
			out[it] += int(world.peek(CONTRACT)[cid]["on_site"][it])
	return out


# ================================================================ work (PRODUCTION)

## Each builder's crews go to its jobs in signing order (rebuild-building 4.6): a job takes up to its planned BW a
## month, as far as the supplies on its site allow; a job not yet started starts only with three months of supplies on
## site (or the rest of its bill). A job that cannot work keeps its place and the crews go on. Supplies are built in
## in proportion to the work. A job whose bill is done is DONE; it opens next month.
static func work_month(world: WorldState) -> void:
	for b in builders(world, false):
		var cap := HomeBuilders.bw_milli(world, b)
		var left := cap
		var due := 0
		var blocked := 0
		var short_crew := 0
		for cid in book(world, b):
			var c: Dictionary = world.table(CONTRACT)[cid]
			c["bw_month"] = 0
			var st := String(c["status"])
			if not st in ["SIGNED", "WORKING"]:
				continue
			var plan := mini(planned_bw(c), int(c["bill"]["bw"]) - int(c["done"]))
			due += plan
			if st == "SIGNED" and not _ready(c):
				blocked += plan
				continue
			var allows := mini(plan, _bw_material_allows(c))
			var x := mini(allows, left)
			short_crew += allows - maxi(0, x)   # work its supplies allowed that it had no crews for (the log only)
			if x <= 0:
				if allows <= 0:
					blocked += plan
				continue
			_do(world, b, c, x)
			left -= x
		var idle := maxi(0, left)
		var waiting := mini(idle, blocked)
		_month_set(world, b, {"cap": cap, "due": due, "done": cap - left, "waiting_material": waiting, "empty": idle - waiting,
			"short_crew": short_crew})
		Logbook.note(world, "WORK", b, "the month's building work", {"crews_bw": cap, "due": due, "blocked_by_supplies": blocked},
			{"done": [0, cap - left], "waiting_material": [0, waiting], "empty": [0, idle - waiting]})


static func _ready(c: Dictionary) -> bool:
	for it in ITEMS:
		var total := int(c["bill"][it])
		if total <= 0:
			continue
		var still := total - int(c["used"][it])
		if int(c["on_site"][it]) < mini(UP_FRONT_M * month_need(c, it), still):
			return false
	return true


## The most BW the supplies on the site allow this month.
static func _bw_material_allows(c: Dictionary) -> int:
	var bw := int(c["bill"]["bw"])
	var most := bw - int(c["done"])
	for it in ITEMS:
		var total := int(c["bill"][it])
		if total <= 0:
			continue
		most = mini(most, (int(c["used"][it]) + int(c["on_site"][it])) * bw / total - int(c["done"]))
	return maxi(0, most)


static func _do(world: WorldState, b: String, c: Dictionary, x: int) -> void:
	var bw := int(c["bill"]["bw"])
	var was := String(c["status"])
	c["status"] = "WORKING"
	c["done"] = int(c["done"]) + x
	c["bw_month"] = x
	var built := {}
	for it in ITEMS:
		var total := int(c["bill"][it])
		var now_used := total * int(c["done"]) / maxi(1, bw)
		var inc := now_used - int(c["used"][it])
		c["used"][it] = now_used
		c["on_site"][it] = int(c["on_site"][it]) - inc
		built[it] = inc
	if int(c["done"]) >= bw:
		c["status"] = "DONE"
		c["done_month"] = world.month
		_fact(world, "ECON_PROJECT_COMPLETED", b, 25, {"contract": c["id"], "plan": c["plan"], "type": c["type"]})
	Logbook.note(world, "WORK", String(c["id"]), "worked", {"bw": x, "built_in": built, "planned": planned_bw(c)},
		{"done": [int(c["done"]) - x, int(c["done"])], "status": [was, c["status"]]}, b, String(c["plan"]))


# ================================================================ paying (SETTLEMENT, before wages)

## The builder's wages per BW at its present crew (milli-credits per BW).
static func wage_bw(world: WorldState, b: String) -> int:
	var cap := HomeBuilders.bw_milli(world, b)
	return Company.wage_bill(world, b) * S / cap if cap > 0 else 0


## Each job's bill for this month's work, paid by its client before wages (rebuild-building 4.7; joins): the BW done
## × (the price per BW at signing + the change in the builder's wages per BW since). Supplies were paid at delivery.
## What the client cannot pay is owed; three months running unpaid and the builder stops (12.9, 56); paid up, it
## resumes. A plan that cannot pay what it owes on a stopped job is given up by its owner (4.9).
static func bill_month(world: WorldState) -> void:
	for cid in CoreUtil.sorted_keys(world.peek(CONTRACT)):
		var c: Dictionary = world.table(CONTRACT)[cid]
		var x := int(c["bw_month"])
		if x <= 0 and int(c["owed"]) <= 0:
			continue
		var b := String(c["builder"])
		var w_now := wage_bw(world, b)
		# the work at the signed price is billed on the running total, so monthly rounding never loses a credit
		var base := int(c["done"]) * int(c["price_bw"]) / S - int(c.get("base_billed", 0))
		c["base_billed"] = int(c.get("base_billed", 0)) + base
		var drift := maxi(-base, x * (w_now - int(c["wage_bw"])) / S)   # only the drift is clamped, never the signed base
		var bill := base + drift
		var owed_before := int(c["owed"])
		c["owed"] = owed_before + bill
		var paid := CoreUtil.pay_upto(world, String(c["client_acct"]), CoreUtil.acct(b), int(c["owed"]), "CONTRACT:" + cid)
		c["owed"] = int(c["owed"]) - paid
		c["paid"] = int(c["paid"]) + paid
		Company.book(world, b, "rev", paid)   # the builder's takings (revenue_12, the law's fines)
		c["bw_month"] = 0
		if world.peek(PLAN).has(String(c["plan"])) and String(world.peek(PLAN)[c["plan"]]["status"]) != "OPEN":
			world.table(PLAN)[c["plan"]]["cost"]["work"] = int(world.peek(PLAN)[c["plan"]]["cost"]["work"]) + paid
		var was := String(c["status"])
		if int(c["owed"]) > 0:
			c["unpaid_m"] = int(c["unpaid_m"]) + 1
			if int(c["unpaid_m"]) >= 3 and was in ["SIGNED", "WORKING"]:
				c["status"] = "STOPPED"
				_fact(world, "ECON_CONTRACT_PAYMENT_MISSED", b, 30, {"contract": cid, "client": c["client"], "owed": int(c["owed"]) / S})
		else:
			c["unpaid_m"] = 0
			if was == "STOPPED":
				c["status"] = "WORKING" if int(c["done"]) > 0 else "SIGNED"
		Logbook.note(world, "PAY", cid, "contract bill", {"bw": x, "price_bw": int(c["price_bw"]) / S, "wage_bw_then": int(c["wage_bw"]) / S,
			"wage_bw_now": w_now / S, "bill": bill / S, "owed_before": owed_before / S},
			{"paid": [0, paid / S], "owed": [owed_before / S, int(c["owed"]) / S], "status": [was, c["status"]]}, b, String(c["plan"]))
		if String(c["status"]) == "STOPPED" and world.peek(PLAN).has(String(c["plan"])):
			var p: Dictionary = world.peek(PLAN)[c["plan"]]
			if String(p["status"]) == "SIGNED" and world.ledger.balance(account(String(c["plan"]))) < int(c["owed"]):
				give_up(world, String(c["plan"]), "cannot pay the builder")


# ================================================================ the opening (PRODUCTION, first)

## Each plan whose building was finished last month becomes a company and a plant (the joins' order): the company and
## its plant; the site moves to the plant; the land title to the company; the law registers it and may close it; the
## plan's money moves to the company's account; an OPEN row with the plan as ref. It has no staff yet: it hires in
## COMPANY_AI by the output rules and makes from the month after.
static func open_due(world: WorldState) -> void:
	for cid in CoreUtil.sorted_keys(world.peek(CONTRACT)):
		var c: Dictionary = world.table(CONTRACT)[cid]
		if String(c["status"]) != "DONE" or int(c["done_month"]) >= world.month:
			continue
		var pid := String(c["plan"])
		var p: Dictionary = world.table(PLAN).get(pid, {})
		if p.is_empty() or String(p["status"]) != "SIGNED":
			continue
		var size := String(p["size"])
		var kind := "FAMILY" if size == "FAMILY" else "PRIVATE"
		var name := "%s %s %d" % [String(p["area"]), String(p["type"]).capitalize(), int(p["n"])]
		var co := Company.create(world, String(p["type"]), size, {"kind": kind, "holders": {String(p["founder"]): 1000}}, name,
			{"origin": "PLAN", "origin_n": int(p["n"]), "area": String(p["area"])})
		if co == "":
			Logbook.note(world, "OPEN", pid, "NOT opened: the company record refused it", {"type": p["type"], "size": size})
			continue
		var plant := Company.add_plant(world, co, size, pid)
		Site.open(world, pid, plant)
		LandLaw.pass_holder(world, pid, co, "OPENED")
		LawCompany.register(world, co, pid)
		var law: Dictionary = LawCompany.may_open(world, co, plant)
		if not bool(law.get("ok", true)):
			Company.close_plant(world, plant, "LAW")
		var money := maxi(0, world.ledger.balance(account(pid)))
		if money > 0:
			world.ledger.transfer(account(pid), CoreUtil.acct(co), money, "PLAN_TO_COMPANY", world.month)
		c["client"] = co
		c["client_acct"] = CoreUtil.acct(co)
		p["status"] = "OPEN"
		p["company"] = co
		p["opened"] = world.month
		var cost: Dictionary = p["cost"]
		Logbook.note(world, "OPEN", co, "plant opened: the plan became a company", {"type": p["type"], "size": size,
			"founder": p["founder"], "law_ok": bool(law.get("ok", true)), "building_cost": {"land": int(cost["land"]) / S,
			"work": int(cost["work"]) / S, "supplies": int(cost["supplies"]) / S}}, {"company_account": [0, money / S]},
			String(c["builder"]), pid)


# ================================================================ a builder's signals (pure)

## The month the first plan in the colony asked the builders for quotes, or -1 before then. "No they should not cut
## for the start, and they should not increase prices for claimed jobs" (the user, plan 12.3 15c): the start lasts
## until then (Wilma's reading), the colony's whole market, not each builder's (Bob's review: a builder not yet quoted
## must not sit frozen once the market is open). A whole number, so it survives the save file.
static func first_quote_month(world: WorldState) -> int:
	return int(world.peek(OPENED).get("first_quote_m", -1))


## A builder's month in the market's seller-signal shape (Market.seller_signal), so the one price rule and the one
## output rule read it like any seller's (plan section 6: no type has its own copy). In milli-BW:
##   offered: its crews' BW less crews waiting for supplies (12.3, 19: a missing input is not a price signal);
##   sold: the BW it did; unmet_above: the BW of plans that signed with it last month but must wait behind its book
##   (asked for and not to be had now, counted once; work already sold that waits in the book is not counted again;
##   Wilma's decision, the reading agreed with Bob); short_crew stays in the month record for the log only;
##   refused: the BW of quotes refused for their price (23a). price: its price per BW. {} before its first month, and
##   {} at the start, before any plan asked for a quote (no rule cuts its price or its crew then).
static func seller_signal(world: WorldState, b: String) -> Dictionary:
	if first_quote_month(world) < 0:
		return {}   # the start: no customer could exist yet, so no cut in price or crew (the user's ruling, plan 12.3 15c)
	var m: Dictionary = world.peek(MONTH).get(b, {})
	if m.is_empty() or int(m.get("m", -1)) != world.month:
		return {}
	return {"offered": int(m.get("cap", 0)) - int(m.get("waiting_material", 0)), "sold": int(m.get("done", 0)),
		"price": Company.price(world, b, "BW"), "unmet_above": int(m.get("unmet_wait_bw", 0)), "refused": int(m.get("refused_price_bw", 0))}


## What a builder's price and output rules read (rebuild-building 4.6; plan 12.3 19): its crews' BW last month, the work
## due, the work done, crews idle for want of supplies (not a price signal) and crews idle for want of work (empty
## slots), and quotes refused for their price. A plan never refuses a quote for its wait in step 3 (it waits), so
## refused_wait_bw is 0.
static func book_signals(world: WorldState, b: String) -> Dictionary:
	var m: Dictionary = world.peek(MONTH).get(b, {})
	return {"month": int(m.get("m", -1)), "cap": int(m.get("cap", 0)), "bw_due": int(m.get("due", 0)), "bw_done": int(m.get("done", 0)),
		"crews_waiting_material": int(m.get("waiting_material", 0)), "crews_empty": int(m.get("empty", 0)),
		"refused_price_bw": int(m.get("refused_price_bw", 0)), "refused_wait_bw": 0, "book_bw": _book_bw(world, b)}


static func _book_bw(world: WorldState, b: String) -> int:
	var n := 0
	for cid in book(world, b):
		var c: Dictionary = world.peek(CONTRACT)[cid]
		n += int(c["bill"]["bw"]) - int(c["done"])
	return n


# ================================================================ inside

static func _plans(world: WorldState, status: String) -> Array:
	var rows: Array = []
	for pid in world.peek(PLAN):
		if String(world.peek(PLAN)[pid]["status"]) == status:
			rows.append([int(world.peek(PLAN)[pid]["n"]), pid])
	rows.sort()
	return rows.map(func(r): return r[1])


static func _num(id: String) -> int:
	return int(id.get_slice(":", 1))


## A builder's month record, written by work_month in PRODUCTION. Quotes refused, and plans signed to wait behind the
## book, in the last COMPANY_AI (after the rules had read that month) wait as "refused_pending" and "unmet_pending"
## and are counted in the month the rules read next, once.
static func _month_set(world: WorldState, b: String, v: Dictionary) -> void:
	var t: Dictionary = world.table(MONTH)
	var old: Dictionary = t.get(b, {})
	v["m"] = world.month
	v["refused_price_bw"] = int(old.get("refused_pending", 0))
	v["refused_pending"] = 0
	v["unmet_wait_bw"] = int(old.get("unmet_pending", 0))
	v["unmet_pending"] = 0
	t[b] = v


static func _month_stat(world: WorldState, b: String, key: String, add: int) -> void:
	var t: Dictionary = world.table(MONTH)
	if not t.has(b):
		t[b] = {"m": -1}
	t[b][key] = int(t[b].get(key, 0)) + add


static func _fact(world: WorldState, type: String, who: String, mag: int, data: Dictionary) -> void:
	world.add_fact({"type": type, "owner": "econ", "subjects": [{"kind": "COMPANY", "id": who}],
		"responsible": [{"actor": {"kind": "COMPANY", "id": who}, "share": 1.0}], "impact": {}, "magnitude": mag,
		"visibility": "PUBLIC", "data": data})
