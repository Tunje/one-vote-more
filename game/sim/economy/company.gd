extends RefCounted
## THE COMPANY (rebuild plan section 3): one record per company, in world.table("company"); its plants in
## world.table("plant"). "There is ONE kind of thing that produces: the company." A farm, a builder, a clinic and a
## landlord are the same record with a different row of the type table (type_table.gd).
## Preload it: const Company := preload("res://sim/economy/company.gd").
##
## A company's own state lives here and nowhere else. Other things keep their OWN records keyed by its id (the law its
## licences, the bank its loans, a union its members). Where a plant stands is Terra's (Site.of(world, plant_id)); a
## landlord's homes are counted in the town grid's cells (TownGrid.homes_of). Its staff are written only by the
## household side (Households.hire / layoff) through staff_change, so a job is recorded once (plan 9.2).
## No old table name ("org", "facility", "project", "hh") is created: old readers stay asleep until the doorway
## connects them.
##
## Every decision and deed writes a Logbook row (plan section 13).

## The farm type: a farm with its owning family is a family farm, which is never shut (is_family_farm; the user,
## 2026-11-18: "FAMILY FARMS FAMILY FARMS don't shut").
const FARM_TYPE := "FARM"
const TypeTable := preload("res://sim/economy/type_table.gd")

const TABLE := "company"
## The rules (the starting salary of an area); loaded when needed, as the rules preload this file.
const HOUSEHOLDS_PATH := "res://sim/population/households.gd"
const RULES_PATH := "res://sim/economy/rules.gd"
const PLANT_TABLE := "plant"
const OWNER_KINDS: Array[String] = ["STATE", "HOME_WORLD", "FAMILY", "PRIVATE", "COOP", "PARTY", "UNION"]
const CONDITION_FULL := 100 * 1000   # a plant's condition, 0..100 in milli-points


# ---------------------------------------------------------------- making a company and its plants

## Makes a company record and its account, with the starting price of everything its type sells, and returns its id
## ("company:N"). It has no plants, staff or money yet: plants come with add_plant (a home-world builder has none),
## staff through the household side, money by a payment into its account. Returns "" (and writes nothing) when the
## type, size or owner register is not valid.
## owner: {"kind": one of OWNER_KINDS, "holders": {holder id: share per mille}}, the shares adding up to 1000.
## opts: optional fields the creator sets once: "origin" (e.g. "HOME_WORLD_LANDING"), "origin_n" (its number among
## those of the same origin), "area" (its home area), "price_fixed" (true: the price rules leave its prices alone, as
## for Colony Stores, which sells the landing stock at the starting prices, plan 12.2, 9), "crew_posts" (true: a
## company with no plant that still has posts to fill as a crew, like the administration; a BUILDER always has),
## "chief" ({"mgmt": 0..100, "risk": 0..100}, plan 12.11, 77; 50 and 50 if not given).
static func create(world: WorldState, type: String, size: String, owner: Dictionary, name: String, opts: Dictionary = {}) -> String:
	if not TypeTable.has_type(type) or not TypeTable.is_size(size) or not _owner_ok(owner):
		return ""
	var id := world.new_id(TABLE)
	var price := {}
	for i in TypeTable.line_count(type):
		# a type that sells items it buys in (a SHOP) has no price of its own row: it opens one per item with offer()
		if String(TypeTable.way(type)["sells"]) == "ITEM" and not TypeTable.is_item(TypeTable.out_of(type, i)):
			continue
		price[_sells_key(type, i)] = TypeTable.start_price_of(type, i)
	var rec := {
		"id": id, "name": name, "type": type, "size": size, "status": "OPEN", "opened": world.month,
		"origin": String(opts.get("origin", "")), "origin_n": int(opts.get("origin_n", 0)), "area": String(opts.get("area", "")),
		"price_fixed": bool(opts.get("price_fixed", false)), "crew_posts": bool(opts.get("crew_posts", false)) or works_as_crew(type),
		"chief": {"mgmt": int(opts.get("chief", {}).get("mgmt", 50)), "risk": int(opts.get("chief", {}).get("risk", 50))},
		"raise_pm": 0,             # the yearly raise this company chooses to give, per mille (at least the government's minimum)
		"crew_level_pm": 1000,     # output level of its crew (rule 3/4), per mille of full; plants keep their own
		"hold": {},                # {item: milli-units held back from sale this month (the hold-back, set by the rules)}
		"market": {},              # this month's sales signals per thing it sells, written by the market's clear
		"owner": {"kind": String(owner["kind"]), "holders": (owner["holders"] as Dictionary).duplicate()},
		"plants": [],              # plant ids; the plants are in table "plant"
		"line": 0,                 # which output line it runs (first = 0, second = 1)
		"staff": {},               # {plant id or "crew": {post tier: {"area|band|skill": {"n": persons × S, "hires": [{"n", "pay", "since", "train"}]}}}}
		"salary": {},              # a base offer of its own for a new opening, {tier: {area: milli-credits}}; nothing in the game sets it (tests do)
		"openings": {},            # its open posts, each with its whole months unfilled: {"plant|tier": {"m", "open": [months...]}} (9.2)
		"stock": {},               # {item: {"qty": milli-units, "value": milli-credits in all, "waiting": milli-units}}
		"books": {"month": {}, "year": []},   # the open month's lines, and the last 12 closed months (oldest first)
		"price": price,            # ONE price per company for each thing it sells: {item or "BW"/"FREIGHT"/"@client": milli-credits}
		"orders": {},              # filled and unfilled, each unfilled one with WHY (step 3)
		"slots": {},               # for types with nothing to stock: {kind: {"taken": n, "empty": n}} (step 4)
		"office": "",              # the office place it rents, or "" (step 9)
		"fleet": [],               # its trucks (step 4)
		"emissions": 0, "noise": 0,
		"signals": {},             # the nine rules' inputs, worked out once a month (step 3)
	}
	world.table(TABLE)[id] = rec
	world.ledger.open_account(CoreUtil.acct(id))
	Logbook.note(world, "OPEN", id, "company created", {"type": type, "size": size, "owner": owner["kind"], "origin": rec["origin"]},
		{"price": [{}, price.duplicate()]}, "", "")
	return id


## Adds a plant of this size to a company; returns its id ("plant:N"), or "" if the company or size is unknown.
## The plant holds no place: Terra records where it stands under this id (Site.place / Site.open).
static func add_plant(world: WorldState, cid: String, size: String, ref: String = "") -> String:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.is_size(size):
		return ""
	var pid := world.new_id(PLANT_TABLE)
	world.table(PLANT_TABLE)[pid] = {"id": pid, "company": cid, "type": String(c["type"]), "size": size,
		"condition": CONDITION_FULL, "closed": false, "closed_why": "", "level_pm": 1000, "opened": world.month}
	(c["plants"] as Array).append(pid)
	Logbook.note(world, "PLANT", cid, "plant added", {"size": size, "type": c["type"]}, {"plants": [(c["plants"] as Array).size() - 1, (c["plants"] as Array).size()]}, "", pid if ref == "" else ref)
	return pid


## Sets the price of one thing a company sells. why: the numbers the decision read (the rules give them from step 3).
static func set_price(world: WorldState, cid: String, key: String, value: int, why: Dictionary = {}, what: String = "price set") -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not (c["price"] as Dictionary).has(key) or value < 0:
		return false
	var old := int(c["price"][key])
	c["price"][key] = value
	Logbook.note(world, "PRICE", cid, what, why, {key: [old, value]})
	return true


## Opens a price for an item a company sells beyond its row's own outputs: a SHOP's goods (it sells what it buys in).
## Only a type whose way sells items within reach (SHOP) may; returns false otherwise, or if the item already has a
## price (then set_price moves it). Writes a PRICE row.
static func offer(world: WorldState, cid: String, item: String, value: int, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or String(TypeTable.way(String(c["type"]))["reach"]) != "IN_REACH" or not TypeTable.is_item(item):
		return false
	if (c["price"] as Dictionary).has(item) or value < 0 or bool(TypeTable.ITEMS[item]["grid"]):
		return false
	c["price"][item] = value
	Logbook.note(world, "PRICE", cid, "offer opened", why, {item: [-1, value]})
	return true


# ---------------------------------------------------------------- stock

## Where goods may come INTO the colony's stocks from (plan section 13: "no goods from nowhere"): the landing stock, a
## plant's own output, or a ship from the home world. Goods passing from one company to another go by stock_move,
## which takes them out of the one in the same step.
const SOURCES: Array[String] = ["LANDING", "OUTPUT", "IMPORT"]
const OUT_REASONS: Array[String] = ["USED", "SPOILED", "SOLD", "EXPORTED", "LOST", "FAMILY"]
## Ship goods: what came in by ship (the landed stock, imports). A stock entry counts how much of it is ship goods
## ("ship", milli-units); goods leaving take ship goods in proportion, so a mixed stock stays mixed in the same share.
const SHIP_SOURCES: Array[String] = ["LANDING", "IMPORT"]
## Training (9.2): a new hire makes half in the month hired, rising evenly to full after TRAIN_MONTHS.
const TRAIN_MONTHS := 6
const TRAIN_START_PM := 500


## Puts goods into a company's stock from a source outside every company (SOURCES): qty_milli units at cost_milli
## milli-credits per unit (0 allowed; a quantity of 0 is refused, so no row of nothing is written). The stock keeps the quantity and its total book value, so its average cost per
## unit is value / qty. Only items, and not grid goods (12.7). Writes a STOCK row with the source as `with`. Returns
## false (nothing changed) for an unknown company or source, a non-item, a grid good, or a quantity or cost below 0.
static func stock_add(world: WorldState, cid: String, item: String, qty_milli: int, cost_milli: int, source: String, why: String) -> bool:
	if not SOURCES.has(source):
		return false
	return _stock_in(world, cid, item, qty_milli, cost_milli, source, why)


## Takes goods out of a company's stock for a reason that is not a passing to another company (OUT_REASONS: an input
## USED, SPOILED, SOLD to households, EXPORTED, LOST, or eaten by the FAMILY that works a family farm, 15e). Returns the book value taken out (at the average cost), or -1
## (nothing changed) if it holds less than asked or the reason is unknown. Writes a STOCK row.
static func stock_take(world: WorldState, cid: String, item: String, qty_milli: int, reason: String, why: String) -> int:
	if not OUT_REASONS.has(reason):
		return -1
	return _stock_out(world, cid, item, qty_milli, reason, why)


## Moves goods from one company's stock to another's in one step, valued at the buyer at unit_price milli-credits per
## unit. Money is not moved here: that is the sale's. Returns false (nothing changed) if the seller holds less, the
## buyer is unknown, or the two are the same. Writes a STOCK row on each side, each naming the other.
static func stock_move(world: WorldState, from_cid: String, to_cid: String, item: String, qty_milli: int, unit_price: int, why: String) -> bool:
	# both sides are checked before anything moves, so a refusal never leaves goods half moved: every check _stock_in
	# makes is made here first
	if from_cid == to_cid or (world.peek(TABLE).get(to_cid, {}) as Dictionary).is_empty() or unit_price < 0 or qty_milli <= 0:
		return false
	if not TypeTable.is_item(item) or bool(TypeTable.ITEMS[item]["grid"]) or int(stock_of(world, from_cid, item)["qty"]) < qty_milli:
		return false
	var e: Dictionary = world.peek(TABLE)[from_cid]["stock"][item]
	var ship := int(e.get("ship", 0)) * qty_milli / maxi(1, int(e["qty"]))   # ship goods go with the goods moved
	_stock_out(world, from_cid, item, qty_milli, "MOVED", why, to_cid)
	return _stock_in(world, to_cid, item, qty_milli, unit_price, from_cid, why, ship)


static func _stock_in(world: WorldState, cid: String, item: String, qty_milli: int, cost_milli: int, source: String, why: String, ship_milli: int = -1) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.is_item(item) or bool(TypeTable.ITEMS[item]["grid"]) or qty_milli <= 0 or cost_milli < 0:
		return false
	var st: Dictionary = c["stock"]
	if not st.has(item):
		st[item] = {"qty": 0, "value": 0, "waiting": 0, "ship": 0}
	var old := int(st[item]["qty"])
	st[item]["qty"] = old + qty_milli
	var ship := ship_milli if ship_milli >= 0 else (qty_milli if SHIP_SOURCES.has(source) else 0)
	st[item]["ship"] = int(st[item].get("ship", 0)) + mini(ship, qty_milli)
	st[item]["value"] = int(st[item]["value"]) + qty_milli * cost_milli / CoreUtil.S
	Logbook.note(world, "STOCK", cid, why, {"item": item, "qty": qty_milli, "cost": cost_milli, "in": source}, {item: [old, old + qty_milli]}, source)
	return true


static func _stock_out(world: WorldState, cid: String, item: String, qty_milli: int, reason: String, why: String, to: String = "") -> int:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or qty_milli <= 0 or not (c["stock"] as Dictionary).has(item):
		return -1
	var e: Dictionary = c["stock"][item]
	var old := int(e["qty"])
	if old < qty_milli:
		return -1
	var value := 0 if old == 0 else int(e["value"]) * qty_milli / old
	if old > 0:
		e["ship"] = int(e.get("ship", 0)) - int(e.get("ship", 0)) * qty_milli / old
	e["qty"] = old - qty_milli
	e["value"] = int(e["value"]) - value
	Logbook.note(world, "STOCK", cid, why, {"item": item, "qty": -qty_milli, "out": reason}, {item: [old, old - qty_milli]}, to)
	return value


## A company's stock of one item: {"qty": milli-units, "value": milli-credits, "waiting": milli-units waiting for
## freight, "ship": milli-units of it that came by ship}, all 0 when it holds none.
static func stock_of(world: WorldState, cid: String, item: String) -> Dictionary:
	var e: Dictionary = world.peek(TABLE).get(cid, {}).get("stock", {}).get(item, {})
	return {"qty": int(e.get("qty", 0)), "value": int(e.get("value", 0)), "waiting": int(e.get("waiting", 0)),
		"ship": int(e.get("ship", 0))}


# ---------------------------------------------------------------- staff (written only by the household side)

## A worker's salary (plan 9.2, the user: "they have a sallery set on hire then it climbs based on yearly upps set by
## goverment"): it is set when they are hired and is theirs from then on. The company never moves it; it rises once a
## year by the yearly raise (yearly_raise). The offer rule moves only the HIRING salary, record["salary"], what the
## company offers a new hire this month. People are counts in pools, so a staff entry (plant, post tier, labour key)
## keeps its people as HIRE ROWS, one row per hire (the user: a table that keeps everything about a hire; "You can
## merge if all rows match"): {"n": persons × S in all, "hires": [{"n": persons × S, "pay": milli-credits a month per
## person, "since": the month they came to this workplace, "train": the month their training began, or -1 if they came
## trained}, ...]}. Two rows are one only when every field matches: the same pay, the same month at the workplace and
## the same training left (a row whose training is over has none left). So nobody's pay, years or training moves when
## someone joins or leaves (Wilma's bugs against 9.2). A raise or a negotiated rise changes pay only. "since" is how
## long a row has been at the workplace, for quitting (plan 9.2: "plus 1% per year in the same workplace up to 15%";
## Maja's side reads it). Rows run highest pay first, then the longest at the workplace, then the earliest training.
## A consequence of the ruling, not a fault to fix: after a few raises the people already employed earn more than the
## hiring salary, so a new hire can cost less than the person beside them. The rules move only the hiring line.

## Adds delta (persons × S, may be negative) to one staff entry: company["staff"][plant_key][post_tier][labour_key].
## plant_key is a plant id of the company, or "crew": a builder's crews (they work at the clients' sites, not at its
## yard, rebuild-building 1, 4.6), whether or not it has a yard; and the staff of a company that has no plant yet
## (a home-world builder, a government subsidiary before its building). labour_key is the household side's
## "area|band|skill" (the area the workers LIVE in, which need not be where the plant hires: reach, 12.5 rule 40).
## pay: for a hire (delta > 0), the salary the joiners are hired at, milli-credits a month each, and required: the
## hirer reads it from hiring_salary(world, cid, tier, the AREA THE PLANT STANDS IN) (plan 9.2: "The district the plant
## hiring is in"). When people leave (delta < 0) and no row is named: the rows at that pay, in order; -1 any row.
## since: for a hire, the month the joiners came to this workplace; -1 (the default) is this month, a new hire, in
## training (9.2); 0 or more: they came trained (the landing's own hires). Ignored when people leave.
## row: when people leave, the hire row they leave (payroll's "row"); "" takes them from the rows in order.
## A move between entries of the same workplace keeps its row whole: staff_move.
## Writes no Logbook row: the household side's hire or layoff row is the one for the deed.
## Refuses (false, nothing changed) if the company or plant is unknown, the tier is not a tier, or it would go below 0
## (in the entry, or in the rows named).
static func staff_change(world: WorldState, cid: String, plant_key: String, post_tier: String, labour_key: String, delta: int, pay: int = -1, since: int = -1, row: String = "") -> bool:
	if delta > 0 and pay < 0:
		return false
	var hire := {}
	if delta > 0:
		hire = {"n": delta, "pay": pay, "since": world.month if since < 0 else since, "train": world.month if since < 0 else -1}
	return _staff_write(world, cid, plant_key, post_tier, labour_key, delta, hire, pay, row)


## Moves n persons × S of one hire row (payroll's "row") from one labour key to another in the same plant and tier,
## keeping the row whole: its pay, its month at the workplace and its training (a band move, Demography.band_moves).
## False, nothing changed, if the row does not hold n.
static func staff_move(world: WorldState, cid: String, plant_key: String, post_tier: String, from_key: String, to_key: String, row: String, n: int) -> bool:
	var e: Dictionary = world.peek(TABLE).get(cid, {}).get("staff", {}).get(plant_key, {}).get(post_tier, {}).get(from_key, {})
	var r: Dictionary = {}
	for x in _tidy(world, e.get("hires", [])):   # the merged view: rows that came to match since the last write are one
		if _row_key(world, x) == row:
			r = x
	if r.is_empty() or int(r["n"]) < n or n <= 0:
		return false
	var hire := {"n": n, "pay": int(r["pay"]), "since": int(r["since"]), "train": _train_now(world, r)}
	if not _staff_write(world, cid, plant_key, post_tier, from_key, -n, {}, -1, row):
		return false
	return _staff_write(world, cid, plant_key, post_tier, to_key, n, hire, -1, "")


## Does a type work as a crew with no plant (its posts under "crew")? Read from its type-table row, not its name (the
## user, 2026-11-18: "No it's for all goods don't overcomplicatev with individual rules built seperatly"; then, of the
## places that named one type, "Good, those"): every type whose row sells building work (way "sells": "BW").
static func works_as_crew(type: String) -> bool:
	return TypeTable.ROWS.has(type) and crew_way(TypeTable.way(type))


## The same read on a row's way alone (pure): a row that sells building work works as a crew.
static func crew_way(way: Dictionary) -> bool:
	return String(way.get("sells", "")) == "BW"


static func _staff_write(world: WorldState, cid: String, plant_key: String, post_tier: String, labour_key: String, delta: int, hire: Dictionary, pay: int, row: String) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.TIER_PM.has(post_tier):
		return false
	if plant_key == "crew":
		if not works_as_crew(String(c["type"])) and not (c["plants"] as Array).is_empty():
			return false
	elif not (c["plants"] as Array).has(plant_key):
		return false
	var st: Dictionary = c["staff"]
	var e: Dictionary = st.get(plant_key, {}).get(post_tier, {}).get(labour_key, {})
	var now := int(e.get("n", 0))
	if now + delta < 0:
		return false
	if delta == 0:
		return true
	var rows: Array = (e.get("hires", []) as Array).duplicate(true)
	if delta > 0:
		rows.append(hire)
	elif not _leave(world, rows, -delta, pay, row):
		return false
	if not st.has(plant_key):
		st[plant_key] = {}
	if not st[plant_key].has(post_tier):
		st[plant_key][post_tier] = {}
	if now + delta == 0:
		st[plant_key][post_tier].erase(labour_key)
		if (st[plant_key][post_tier] as Dictionary).is_empty():
			st[plant_key].erase(post_tier)
		if (st[plant_key] as Dictionary).is_empty():
			st.erase(plant_key)
		return true
	st[plant_key][post_tier][labour_key] = {"n": now + delta, "hires": _tidy(world, rows)}
	return true


## k persons × S leave a staff entry's hire rows: from the row named, else from the rows at `pay` (-1: any), in order.
## False if they do not hold k (the caller works on a copy, so nothing is changed).
static func _leave(world: WorldState, rows: Array, k: int, pay: int, row: String) -> bool:
	var left := k
	for r in rows:
		if left <= 0:
			break
		if row != "" and _row_key(world, r) != row:
			continue
		if row == "" and pay >= 0 and int(r["pay"]) != pay:
			continue
		var take := mini(left, int(r["n"]))
		r["n"] = int(r["n"]) - take
		left -= take
	return left <= 0


## A hire row's training start while it lasts, else -1 (trained: nothing left to learn).
static func _train_now(world: WorldState, r: Dictionary) -> int:
	var m := int(r.get("train", -1))
	return m if m >= 0 and world.month - m < TRAIN_MONTHS else -1


## A hire row's key within its entry: every field but the head count ("pay|since|train"). Rows with the same key match
## in every field, so they are one row.
static func _row_key(world: WorldState, r: Dictionary) -> String:
	return "%d|%d|%d" % [int(r["pay"]), int(r["since"]), _train_now(world, r)]


## Hire rows put in order (a new array; the rows are copies): empty rows dropped, finished training written as -1, rows that match in every field made one
## ("You can merge if all rows match"), highest pay first, then the longest at the workplace, then the earliest training.
static func _tidy(world: WorldState, rows: Array) -> Array:
	var by := {}
	for r in rows:
		if int(r["n"]) <= 0:
			continue
		var k := _row_key(world, r)
		if by.has(k):
			by[k]["n"] = int(by[k]["n"]) + int(r["n"])
		else:
			by[k] = {"n": int(r["n"]), "pay": int(r["pay"]), "since": int(r["since"]), "train": _train_now(world, r)}
	var out: Array = by.values()
	out.sort_custom(func(a, b): return int(a["pay"]) > int(b["pay"]) or (int(a["pay"]) == int(b["pay"]) and (int(a["since"]) < int(b["since"])
		or (int(a["since"]) == int(b["since"]) and int(a["train"]) < int(b["train"])))))
	return out


## What a new hire makes, per mille of a trained worker's output, in their month `a` at the workplace (0: the month
## hired): half in the first month, rising evenly to full after six (9.2, Wilma's starting numbers).
static func trained_pm(a: int) -> int:
	return 1000 if a >= TRAIN_MONTHS else TRAIN_START_PM + (1000 - TRAIN_START_PM) * maxi(0, a) / TRAIN_MONTHS


## Staff as trained workers, persons × S, optionally in one post tier and/or at one plant key: each hire row still in
## training counts at trained_pm of its months. Making reads this, not the head count.
static func trained_count(world: WorldState, cid: String, post_tier: String = "", plant_key: String = "") -> int:
	var st: Dictionary = world.peek(TABLE).get(cid, {}).get("staff", {})
	var n := 0
	for pk in st:
		if plant_key != "" and String(pk) != plant_key:
			continue
		for t in st[pk]:
			if post_tier != "" and String(t) != post_tier:
				continue
			for lk in st[pk][t]:
				for r in st[pk][t][lk]["hires"]:
					var m := _train_now(world, r)
					n += int(r["n"]) if m < 0 else int(r["n"]) * trained_pm(world.month - m) / 1000
	return n


## What a NEW opening of this tier is offered at a plant standing in `area` (the plant's area, Terra's Site.of; for
## "crew", the company's own "area"), milli-credits a month: the starting salary of that area (9.2, the user
## 2026-11-18: "fall back to the original rule for settin on hire"; Rules.starting_salary, the user's formula). An
## opening that has stood unfilled climbs from it on its own count (opening_offer). A base set with set_hiring_salary stands in
## for the starting salary; nothing in the game sets one (tests do).
static func hiring_salary(world: WorldState, cid: String, post_tier: String, area: String) -> int:
	var sal: Dictionary = world.peek(TABLE).get(cid, {}).get("salary", {})
	if sal.has(post_tier) and (sal[post_tier] as Dictionary).has(area):
		return int(sal[post_tier][area])
	return int((load(RULES_PATH) as GDScript).call("starting_salary", world, area, post_tier))


## Sets the hiring offer for a tier in an area (Rules.salary_rules: the 5% climb, plan 9.2). It changes what new hires
## are offered, never what anyone already employed is paid. Writes a SALARY row.
static func set_hiring_salary(world: WorldState, cid: String, post_tier: String, area: String, value: int, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.TIER_PM.has(post_tier) or value < 0:
		return false
	var old := hiring_salary(world, cid, post_tier, area)
	if not (c["salary"] as Dictionary).has(post_tier):
		c["salary"][post_tier] = {}
	c["salary"][post_tier][area] = value
	Logbook.note(world, "SALARY", cid, "hiring salary set", why.merged({"tier": post_tier, "area": area}), {"hiring_salary": [old, value]})
	return true


## What an opening that has stood unfilled `months` whole months is offered (9.2, the user, 2026-11-18: "it should
## only climb max 5% if it cost not hire for one month"; "5% each month"): the new opening's offer (hiring_salary)
## climbed Rules.OFFER_CLIMB_PM that many times, each on the last.
static func opening_offer(world: WorldState, cid: String, post_tier: String, area: String, months: int) -> int:
	var climb := int((load(RULES_PATH) as GDScript).get("OFFER_CLIMB_PM"))
	var x := hiring_salary(world, cid, post_tier, area)
	for i in maxi(0, months):
		x = x * (1000 + climb) / 1000
	return x


## The open posts at one plant key and tier ("plant|tier") as written last, each the whole months it has stood
## unfilled, the longest-open first (9.2, built per opening: "increases should not stack for seperate offers").
static func openings(world: WorldState, cid: String, key: String) -> Array:
	var e: Dictionary = world.peek(TABLE).get(cid, {}).get("openings", {}).get(key, {})
	return (e.get("open", []) as Array).duplicate()


## The month the openings at `key` were last written (-1 if none).
static func openings_month(world: WorldState, cid: String, key: String) -> int:
	return int(world.peek(TABLE).get(cid, {}).get("openings", {}).get(key, {}).get("m", -1))


## The openings at `key` fitted to `open` posts open now: when fewer are open the newest close first (Maja's reading
## (b), with Wilma's yes); when more, the new ones start at 0 months. Pure.
## Only a post whose advert is paid is an opening (9.2, the user: "costs of hiring, articles in the newspaper"; "it
## should only climb max 5% if it cost not hire for one month"; Wilma's reading, agreed: an opening is an offer only
## once its advert is paid), so the openings are at most the posts advertised and not yet filled (advertised).
static func fitted_openings(world: WorldState, cid: String, key: String, open: int) -> Array:
	var cap := mini(maxi(0, open), advertised(world, cid, key))
	var ms := openings(world, cid, key)
	while ms.size() > cap:
		ms.pop_back()
	while ms.size() < cap:
		ms.append(0)
	return ms


## The posts at `key` ("plant|tier") whose advert the company has paid and that are not filled yet (Rules._advertise
## writes them; a hire, or a worker moving in, uses one each: advert_used).
static func advertised(world: WorldState, cid: String, key: String) -> int:
	return int(world.peek(TABLE).get(cid, {}).get("advertised", {}).get(key, 0))


## k advertised posts at `key` are filled (a worker moving in for pay is a hire like any other: 9.2).
static func advert_used(world: WorldState, cid: String, key: String, k: int) -> void:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not c.has("advertised") or not (c["advertised"] as Dictionary).has(key):
		return
	c["advertised"][key] = maxi(0, int(c["advertised"][key]) - k)
	if int(c["advertised"][key]) == 0:
		(c["advertised"] as Dictionary).erase(key)


## Writes the openings at `key` (longest-open first), stamped this month; none erases them.
static func set_openings(world: WorldState, cid: String, key: String, months: Array) -> void:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty():
		return
	if not c.has("openings"):
		c["openings"] = {}
	var ms := months.duplicate()
	ms.sort()
	ms.reverse()
	if ms.is_empty():
		(c["openings"] as Dictionary).erase(key)
	else:
		c["openings"][key] = {"m": world.month, "open": ms}


## k openings at `key` that had stood `months` whole months are filled (a hire, a worker moving in): they go, and their
## climb with them (the user: "When the post is filled that rise is gone").
static func fill_openings(world: WorldState, cid: String, key: String, months: int, k: int) -> void:
	var ms := openings(world, cid, key)
	for i in k:
		var at := ms.find(months)
		if at < 0:
			break
		ms.remove_at(at)
	var m := openings_month(world, cid, key)
	set_openings(world, cid, key, ms)
	if m >= 0 and not ms.is_empty():
		world.table(TABLE)[cid]["openings"][key]["m"] = m   # filling does not restamp the month the counts were taken


## The offers of the posts open now at one plant key and tier, the dearest first (for the screens and tests).
static func opening_offers(world: WorldState, cid: String, plant_key: String, post_tier: String) -> Array:
	var have := staff_count(world, cid, post_tier, plant_key) / CoreUtil.S
	var open := maxi(0, int(hire_wanted(world, cid, plant_key)[post_tier]) - have)
	var area := String((load(HOUSEHOLDS_PATH) as GDScript).call("plant_area", world, cid, plant_key))
	return fitted_openings(world, cid, "%s|%s" % [plant_key, post_tier], open).map(func(m): return opening_offer(world, cid, post_tier, area, int(m)))


## The yearly raise (plan 9.2): every hire row's pay × (1 + raise), the raise being at least the government's minimum
## (a lever, 2% to start). Both in per mille. Writes a RAISE row with what the wage bill was and became, also when it
## has nobody on staff (0 to 0): the decision was made.
static func yearly_raise(world: WorldState, cid: String, raise_pm: int, minimum_pm: int) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty():
		return false
	var r := maxi(raise_pm, minimum_pm)
	var before := wage_bill(world, cid)
	for pk in c["staff"]:
		for t in c["staff"][pk]:
			for lk in c["staff"][pk][t]:
				for h in c["staff"][pk][t][lk]["hires"]:   # distinct pays stay distinct, so the rows and their order hold
					h["pay"] = int(h["pay"]) * (1000 + r) / 1000
	Logbook.note(world, "RAISE", cid, "yearly raise", {"raise_pm": raise_pm, "minimum_pm": minimum_pm, "given_pm": r},
		{"wage_bill": [before, wage_bill(world, cid)]})
	return true


## Every hire row of every staff entry, in a fixed order (plant key, tier, labour key, then the rows' own order):
## [{plant_key, post_tier, labour_key, n (persons × S), pay (milli-credits a month per person), since, train (the month
## their training began, -1 trained), row (the row's key)}]. What the household side's pay_wages pays from; a caller
## moving people out of a row passes its "row" to staff_change or staff_move, so they leave their own row.
static func payroll(world: WorldState, cid: String) -> Array:
	var out: Array = []
	var st: Dictionary = world.peek(TABLE).get(cid, {}).get("staff", {})
	for pk in CoreUtil.sorted_keys(st):
		for t in CoreUtil.sorted_keys(st[pk]):
			for lk in CoreUtil.sorted_keys(st[pk][t]):
				for h in _tidy(world, st[pk][t][lk]["hires"]):   # merged: rows whose training ended since the last write
					out.append({"plant_key": pk, "post_tier": t, "labour_key": lk, "n": int(h["n"]), "pay": int(h["pay"]),
						"since": int(h["since"]), "train": _train_now(world, h), "row": _row_key(world, h)})
	return out


## What a month's wages come to, milli-credits: Σ n × pay / S over the staff entries.
static func wage_bill(world: WorldState, cid: String) -> int:
	var total := 0
	for e in payroll(world, cid):
		total += int(e["n"]) * int(e["pay"]) / CoreUtil.S
	return total


## Persons × S employed, optionally in one post tier and/or at one plant key.
static func staff_count(world: WorldState, cid: String, post_tier: String = "", plant_key: String = "") -> int:
	var c: Dictionary = world.peek(TABLE).get(cid, {})
	if c.is_empty():
		return 0
	var n := 0
	for pk in c["staff"]:
		if plant_key != "" and pk != plant_key:
			continue
		for t in c["staff"][pk]:
			if post_tier != "" and t != post_tier:
				continue
			for lk in c["staff"][pk][t]:
				n += int(c["staff"][pk][t][lk]["n"])
	return n


## A copy of a company's whole staff dictionary (for the household side's check): each entry {"n", "hires"}.
static func staff_entries(world: WorldState, cid: String) -> Dictionary:
	return (world.peek(TABLE).get(cid, {}).get("staff", {}) as Dictionary).duplicate(true)


## The household pool's "count per company" (plan 12.5, 35), read, never stored: {company id: persons × S} for the
## people whose labour key starts with "area|band|".
static func staff_of_pool(world: WorldState, area: String, band: String) -> Dictionary:
	var prefix := "%s|%s|" % [area, band]
	var out := {}
	for cid in ids(world):
		var st: Dictionary = world.peek(TABLE)[cid]["staff"]
		var n := 0
		for pk in st:
			for t in st[pk]:
				for lk in st[pk][t]:
					if String(lk).begins_with(prefix):
						n += int(st[pk][t][lk]["n"])
		if n > 0:
			out[cid] = n
	return out


## The occupation a post of this company counts as (Maja's rule): PUBLIC_SECTOR for a state company, PROFESSIONAL for
## a specialist post, otherwise the type row's occupation.
static func occupation(world: WorldState, cid: String, post_tier: String) -> String:
	var c: Dictionary = world.peek(TABLE).get(cid, {})
	if c.is_empty():
		return ""
	if String(c["owner"]["kind"]) == "STATE":
		return "PUBLIC_SECTOR"
	if post_tier == "Sp":
		return "PROFESSIONAL"
	return String(TypeTable.occupation(String(c["type"]))["occ"])


# ---------------------------------------------------------------- posts, wages, books (step 3)

## Posts a company wants filled at one plant key (a plant id, or "crew"), whole persons by tier: the persons the
## level's work needs, the type row's labour for the plant's size × its output level (rules 3 and 4), rounded UP to
## whole persons (the user: "NO ROUNDING ERRORS ARE NOT THINGS YOU BRING TO ME YOU FIX THEM": rounded down, a plant
## under one post's work wanted nobody and made nothing with people on it). A closed plant wants none; "crew" has posts
## only for a company with crew posts (a builder, or one created with "crew_posts"). Hiring, the layoff weighing, the
## open posts and the vacancies read this; what is made reads work_wanted, unrounded.
static func posts_wanted(world: WorldState, cid: String, plant_key: String) -> Dictionary:
	var pl := _posts_at_level(world, cid, plant_key)
	if pl.is_empty():
		return {"G": 0, "S": 0, "Sp": 0}
	var full: Dictionary = pl["full"]
	var weights: Array = []
	for t in ["G", "S", "Sp"]:
		weights.append(float(int(full[t])))
	var parts := CoreUtil.split_lr((int(pl["total"]) * int(pl["level"]) + 999) / 1000, weights)
	return {"G": int(parts[0]), "S": int(parts[1]), "Sp": int(parts[2])}


## The strangers a plant key wants hired, whole persons by tier: the persons its level's work needs (posts_wanted's
## count) less the family working there, whatever post the family stands on (15e: "the family's posts are not hired
## for": hire for what it leaves; Otto's review), split over the posts the family leaves. Never below 0.
static func hire_wanted(world: WorldState, cid: String, plant_key: String) -> Dictionary:
	var pl := _posts_at_level(world, cid, plant_key)
	if pl.is_empty():
		return {"G": 0, "S": 0, "Sp": 0}
	var full: Dictionary = pl["full"]
	# the posts the family leaves, at the level (the user, 15e: "The rest goes down the two adults owning dose not"):
	# the family works its posts whatever the level; the hired posts follow it, rounded up to whole persons
	var fam := family_count(world, cid, "", plant_key) / CoreUtil.S
	var n := 0
	if family_works_full(world, cid):
		n = (maxi(0, int(pl["total"]) - fam) * int(pl["level"]) + 999) / 1000
	else:   # another family company: the family counts against the level's work, as before (the ruling was the farm's)
		n = maxi(0, (int(pl["total"]) * int(pl["level"]) + 999) / 1000 - fam)
	var weights: Array = []
	for t in ["G", "S", "Sp"]:
		weights.append(float(maxi(0, int(full[t]) - family_count(world, cid, t, plant_key) / CoreUtil.S)))
	var parts := CoreUtil.split_lr(n, weights)
	return {"G": int(parts[0]), "S": int(parts[1]), "Sp": int(parts[2])}


## Whether a company's owning family works its posts at the row's output a worker whatever the level: the type table's
## "family_works_full" column (only the farm row has it; 15e), so no type is named here.
static func family_works_full(world: WorldState, cid: String) -> bool:
	return TypeTable.family_works_full(String(world.peek(TABLE).get(cid, {}).get("type", "")))


## The hired hands' work a plant key's level asks for, persons × S, not rounded: the posts the family leaves × the
## level (15e, the user: "The rest goes down the two adults owning dose not"). Without a family it is work_wanted.
static func hired_work_wanted(world: WorldState, cid: String, plant_key: String) -> int:
	var pl := _posts_at_level(world, cid, plant_key)
	if pl.is_empty():
		return 0
	if not family_works_full(world, cid):
		return work_wanted(world, cid, plant_key)
	return maxi(0, int(pl["total"]) * CoreUtil.S - family_count(world, cid, "", plant_key)) * int(pl["level"]) / 1000


## The work a plant key's level asks for, in persons × S, not rounded: all its posts × its output level. What a plant
## makes is read against this (Making.make_plant), so a level under one post's work is done by one person in proportion.
static func work_wanted(world: WorldState, cid: String, plant_key: String) -> int:
	var pl := _posts_at_level(world, cid, plant_key)
	return 0 if pl.is_empty() else int(pl["total"]) * CoreUtil.S * int(pl["level"]) / 1000


## A plant key's full posts and its level: {"full": {tier: posts}, "total", "level"}, or {} for none (closed, unknown,
## a crew without crew posts).
static func _posts_at_level(world: WorldState, cid: String, plant_key: String) -> Dictionary:
	var c: Dictionary = world.peek(TABLE).get(cid, {})
	if c.is_empty():
		return {}
	var size := String(c["size"])
	var level := int(c["crew_level_pm"])
	if plant_key == "crew":
		if not bool(c["crew_posts"]):
			return {}
	else:
		var p: Dictionary = world.peek(PLANT_TABLE).get(plant_key, {})
		# a plant shut for want of staff (19a) still has its posts to fill: it opens again when it has people (Wilma's
		# reading, 2026-11-18; Rules.staff_to_posts reopens it). Shut for any other reason (LAW), it wants nobody.
		if p.is_empty() or String(p["company"]) != cid or (bool(p["closed"]) and String(p.get("closed_why", "")) != "NO_STAFF"):
			return {}
		size = String(p["size"])
		level = int(p["level_pm"])
	var full := TypeTable.posts(String(c["type"]), size, int(c["line"]))
	return {"full": full, "total": int(full["G"]) + int(full["S"]) + int(full["Sp"]), "level": level}


# ---------------------------------------------------------------- the family that works its own company (15e)

## "The owners of a family farm should take winnings no sallery" (the user, plan 12.3 15e; Wilma: every FAMILY-size
## company). The founder's household fills the posts it can, is on no payroll, and lives on the winnings (Rules). The
## record keeps who the family is (the founder, Maja's) and how many of them work each post tier at each plant key:
## record["family"] = {"founder": id, "work": {plant_key: {tier: persons × S}}}. Wages, 19a, layoffs, raises and
## negotiation never touch them; making counts them with the staff; hiring fills only the posts they leave.

## Puts the family in its posts at `plant_key`: work = {tier: whole persons}. Replaces what was there. No row: the
## household side's row (family_work) is the deed.
static func family_set(world: WorldState, cid: String, plant_key: String, founder: String, work: Dictionary) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or (plant_key != "crew" and not (c["plants"] as Array).has(plant_key)):
		return false
	if not c.has("family") or (c["family"] as Dictionary).is_empty():
		c["family"] = {"founder": founder, "work": {}}
	var tiers := {}
	for t in ["G", "S", "Sp"]:
		if int(work.get(t, 0)) > 0:
			tiers[t] = int(work[t]) * CoreUtil.S
	if tiers.is_empty():
		c["family"]["work"].erase(plant_key)
	else:
		c["family"]["work"][plant_key] = tiers
	return true


## Is this company a family farm: a farm with its owning family recorded on it (family_of; the family is put on a
## company at its opening when it was a founder's family-size plan)? The user: "FAMILY FARMS FAMILY FARMS don't shut".
## A family-size farm with no owning family (the state's, the home world's, a company's) is not one. Pure.
static func is_family_farm(world: WorldState, cid: String) -> bool:
	return String(world.peek(TABLE).get(cid, {}).get("type", "")) == FARM_TYPE and family_of(world, cid) != ""


## The founder whose family works this company, or "".
static func family_of(world: WorldState, cid: String) -> String:
	return String(world.peek(TABLE).get(cid, {}).get("family", {}).get("founder", ""))


## Family members working, persons × S, optionally in one post tier and/or at one plant key.
static func family_count(world: WorldState, cid: String, post_tier: String = "", plant_key: String = "") -> int:
	var work: Dictionary = world.peek(TABLE).get(cid, {}).get("family", {}).get("work", {})
	var n := 0
	for pk in work:
		if plant_key != "" and String(pk) != plant_key:
			continue
		for t in work[pk]:
			if post_tier == "" or String(t) == post_tier:
				n += int(work[pk][t])
	return n


## How a family's adults by skill ({"G", "S", "Sp"}: whole persons, Maja's Households.family_adults) fill a plant's
## posts ({"G", "S", "Sp"}): each tier from the adults of that skill or above, the most skilled posts first. Pure.
static func family_fill(posts: Dictionary, adults: Dictionary) -> Dictionary:
	var free := {"G": int(adults.get("G", 0)), "S": int(adults.get("S", 0)), "Sp": int(adults.get("Sp", 0))}
	var out := {"G": 0, "S": 0, "Sp": 0}
	var order := {"Sp": ["Sp"], "S": ["S", "Sp"], "G": ["G", "S", "Sp"]}
	for t in ["Sp", "S", "G"]:
		var need := int(posts.get(t, 0))
		for k in order[t]:
			var take := mini(need, int(free[k]))
			free[k] = int(free[k]) - take
			out[t] = int(out[t]) + take
			need -= take
	return out


## Every open post in an area, for the households' applying (plan 9.2: a worker applies only to a job whose salary
## meets their needs): [{"cid", "plant_key", "tier", "open" (whole persons), "months" (whole months these openings have
## stood unfilled), "pay" (their offer)}], one entry per group of openings with the same months, in a fixed
## order. Until plants carry Terra's area here, a company's posts are in its own area.
static func vacancies(world: WorldState, area: String) -> Array:
	var out: Array = []
	for cid in ids(world):
		var c: Dictionary = world.peek(TABLE)[cid]
		if String(c["status"]) != "OPEN" or String(c["area"]) != area:
			continue
		var keys: Array = ["crew"]
		keys.append_array(c["plants"])
		for pk in keys:
			var want := hire_wanted(world, cid, String(pk))   # the family netted whatever post it stands on (15e)
			for t in ["Sp", "S", "G"]:
				var have := staff_count(world, cid, t, String(pk)) / CoreUtil.S
				if int(want[t]) > have:
					# each opening at its own offer (9.2, per opening): one entry per group with the same months open,
					# the dearest first
					var ms := fitted_openings(world, cid, "%s|%s" % [pk, t], int(want[t]) - have)
					var i := 0
					while i < ms.size():
						var j := i
						while j < ms.size() and int(ms[j]) == int(ms[i]):
							j += 1
						out.append({"cid": cid, "plant_key": String(pk), "tier": t, "open": j - i, "months": int(ms[i]),
							"pay": opening_offer(world, cid, t, area, int(ms[i]))})
						i = j
	return out


## The output level of a plant (or of a company's crew with plant_key "crew"), per mille of full.
static func level_of(world: WorldState, cid: String, plant_key: String) -> int:
	if plant_key == "crew":
		return int(world.peek(TABLE).get(cid, {}).get("crew_level_pm", 0))
	return int(world.peek(PLANT_TABLE).get(plant_key, {}).get("level_pm", 0))


## Sets an output level (rules 3 and 4), per mille of full, 0..1000 (above full is rule 5's job). Writes a LEVEL row.
static func set_level(world: WorldState, cid: String, plant_key: String, level_pm: int, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or level_pm < 0 or level_pm > 1000:
		return false
	var old := level_of(world, cid, plant_key)
	if plant_key == "crew":
		c["crew_level_pm"] = level_pm
	else:
		var p: Dictionary = world.table(PLANT_TABLE).get(plant_key, {})
		if p.is_empty() or String(p["company"]) != cid:
			return false
		p["level_pm"] = level_pm
	Logbook.note(world, "LEVEL", cid, "output level set", why, {"level_pm": [old, level_pm]}, "", plant_key)
	return true


## Holds back stock from sale (plan section 6: a seller below its making price offers what covers its monthly expenses
## and holds the rest). qty in milli-units; 0 offers everything. Writes a HOLD row when it changes.
static func set_hold(world: WorldState, cid: String, item: String, qty_milli: int, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or qty_milli < 0:
		return false
	var old := int(c["hold"].get(item, 0))
	if old == qty_milli:
		return true
	if qty_milli == 0:
		c["hold"].erase(item)
	else:
		c["hold"][item] = qty_milli
	Logbook.note(world, "HOLD", cid, "hold-back set", why, {item: [old, qty_milli]})
	return true


static func hold_of(world: WorldState, cid: String, item: String) -> int:
	return int(world.peek(TABLE).get(cid, {}).get("hold", {}).get(item, 0))


## The average pay a worker of `post_tier` is measured against, milli-credits a month, head-weighted over the hire rows
## of their group in the company (the user: "I think you should avrage ask salleries in the company and underpayed is
## based on that line, that way both old and new can become underpayed"; and, told that a company-wide average puts
## its general workers under it beside its specialists: "Specialists spoilt have been counted seperatly"). Wilma's
## reading: two groups, the specialists, and everyone else (general and skilled together). 0 with nobody in the group.
static func avg_pay(world: WorldState, cid: String, post_tier: String) -> int:
	var n := 0
	var sum := 0
	for e in payroll(world, cid):
		if pay_group(String(e["post_tier"])) == pay_group(post_tier):
			n += int(e["n"])
			sum += int(e["n"]) * int(e["pay"])
	return 0 if n == 0 else sum / n


## The group a post tier's pay is averaged in (avg_pay): "Sp" for the specialists, "GS" for general and skilled.
static func pay_group(post_tier: String) -> String:
	return "Sp" if post_tier == "Sp" else "GS"


## A negotiated rise for one hire row of a staff entry (plan 9.2: "the manager, negotiation can bring it closer to
## avrage"): the row named (payroll's "row"; "": the entry's lowest-paid row) is paid new_pay from now on. Refused if it
## would lower the pay or go above the company's average for that tier. A row that then matches another in every field
## becomes one with it. How far it goes is the rules' and the households' to decide. Writes a NEGOTIATE row.
static func negotiate(world: WorldState, cid: String, plant_key: String, post_tier: String, labour_key: String, new_pay: int, why: Dictionary = {}, from_row: String = "") -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty():
		return false
	var e: Dictionary = c["staff"].get(plant_key, {}).get(post_tier, {}).get(labour_key, {})
	if e.is_empty():
		return false
	var rows: Array = _tidy(world, e["hires"])   # the merged view, as payroll gives it
	var r: Dictionary = rows[-1] if from_row == "" else {}
	for x in rows:
		if from_row != "" and _row_key(world, x) == from_row:
			r = x
	if r.is_empty() or new_pay < int(r["pay"]) or new_pay > avg_pay(world, cid, post_tier):
		return false
	var old := int(r["pay"])
	r["pay"] = new_pay
	e["hires"] = _tidy(world, rows)
	Logbook.note(world, "NEGOTIATE", cid, "pay negotiated", why.merged({"tier": post_tier, "entry": labour_key, "at": plant_key}),
		{"pay": [old, new_pay]})
	return true


## The yearly raise this company chooses (per mille, 0 = only what the government's minimum requires).
static func raise_choice(world: WorldState, cid: String) -> int:
	return int(world.peek(TABLE).get(cid, {}).get("raise_pm", 0))


static func set_raise_choice(world: WorldState, cid: String, raise_pm: int, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or raise_pm < 0:
		return false
	var old := int(c["raise_pm"])
	c["raise_pm"] = raise_pm
	Logbook.note(world, "RAISE", cid, "yearly raise chosen", why, {"raise_pm": [old, raise_pm]})
	return true


## The company's chief (plan 12.11, 77): {"mgmt": 0..100, "risk": 0..100}.
static func chief(world: WorldState, cid: String) -> Dictionary:
	return (world.peek(TABLE).get(cid, {}).get("chief", {}) as Dictionary).duplicate()


## The reference wage (plan 12.11, 108): the average pay over every company's staff, head-weighted, in one area
## (by the company's area) or the whole colony (""). milli-credits a month; 0 with nobody employed.
static func reference_wage(world: WorldState, area: String = "") -> int:
	var n := 0
	var sum := 0
	for cid in ids(world):
		if area != "" and String(world.peek(TABLE)[cid]["area"]) != area:
			continue
		for e in payroll(world, cid):
			n += int(e["n"])
			sum += int(e["n"]) * int(e["pay"])
	return 0 if n == 0 else sum / n


## A company pays its own staff from its own account (step 3; the joins: SETTLEMENT 6). Short of money, everyone is
## paid the same share (the household side's _pay). Books what was due and what was paid. Returns what was paid.
static func pay_wages(world: WorldState, cid: String) -> int:
	if world.peek(TABLE).get(cid, {}).is_empty():
		return 0
	var due := wage_bill(world, cid)
	var paid: int = load("res://sim/population/households.gd").pay_wages(world, cid, CoreUtil.acct(cid), {"why": "its own wages"})
	book(world, cid, "wages_due", due)
	book(world, cid, "wages", paid)
	return paid


## Adds to a line of the open month's books (milli-credits, or milli-units for quantities): "rev", "wages", "inputs",
## "upkeep", "made:<item>", ... No row: the deed that books it writes its own.
static func book(world: WorldState, cid: String, key: String, amount: int) -> void:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty():
		return
	var m: Dictionary = c["books"]["month"]
	m[key] = int(m.get(key, 0)) + amount


## The open month's books (a copy).
static func books_month(world: WorldState, cid: String) -> Dictionary:
	return (world.peek(TABLE).get(cid, {}).get("books", {}).get("month", {}) as Dictionary).duplicate()


## The closed books of `month`, from the ring (a copy), or {} when that month is not closed (or is older than the ring).
static func books_closed(world: WorldState, cid: String, month: int) -> Dictionary:
	for m in world.peek(TABLE).get(cid, {}).get("books", {}).get("year", []):
		if int(m.get("m", -1)) == month:
			return (m as Dictionary).duplicate()
	return {}


## Books into the closed books of `month` (what is settled after the close but belongs to that month: the family's
## winnings, paid in JUSTICE). Returns false (nothing booked) when that month is not in the ring.
static func book_closed(world: WorldState, cid: String, month: int, key: String, amount: int) -> bool:
	for m in world.table(TABLE).get(cid, {}).get("books", {}).get("year", []):
		if int(m.get("m", -1)) == month:
			m[key] = int(m.get(key, 0)) + amount
			return true
	return false


## Closes the month's books into the ring of the last 12 closed months and opens an empty one. Called once a month for
## every company, after the rules have read the month. Writes no row (the deeds were logged as they happened).
static func close_month(world: WorldState, cid: String) -> void:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty():
		return
	var m: Dictionary = (c["books"]["month"] as Dictionary).duplicate()
	m["m"] = world.month
	var ring: Array = c["books"]["year"]
	ring.append(m)
	while ring.size() > 12:
		ring.pop_front()
	c["books"]["month"] = {}


## Revenue over the last twelve closed months (or as many as it has had), milli-credits. For the law's fines (Ella).
static func revenue_12(world: WorldState, cid: String) -> int:
	var total := 0
	for m in world.peek(TABLE).get(cid, {}).get("books", {}).get("year", []):
		total += int(m.get("rev", 0))
	return total


## How many closed months a company has on its books, up to 12.
static func months_on_books(world: WorldState, cid: String) -> int:
	return (world.peek(TABLE).get(cid, {}).get("books", {}).get("year", []) as Array).size()


## Closes a plant, with a reason (LAW, IDLE, NO_STAFF, ...); it keeps its place and wears (step 6). Its staff are not
## laid off here: the household side's layoff does that. Writes a CLOSE row.
## A family farm is never shut, by any path (the user, 2026-11-18, verbatim, told 40 family farms were shut for "no
## staff": "FARMS DON'T SHUT", then "Plants should shut" and "FAMILY FARMS FAMILY FARMS don't shut"; rebuild-company.md
## 15e). Every shutting comes through here, so the refusal is here: it returns false and writes a CLOSE_REFUSED row (its
## own kind, so nothing counts it as a closing) with the reason asked. Any other plant shuts, a farm with no family too.
static func close_plant(world: WorldState, pid: String, reason: String, why: Dictionary = {}) -> bool:
	var p: Dictionary = world.table(PLANT_TABLE).get(pid, {})
	if p.is_empty() or bool(p["closed"]):
		return false
	if is_family_farm(world, String(p["company"])):
		Logbook.note(world, "CLOSE_REFUSED", String(p["company"]), "family farm not shut: family farms don't shut (the user)",
			why.merged({"reason": reason, "family": family_of(world, String(p["company"]))}), {}, "", pid)
		return false
	p["closed"] = true
	p["closed_why"] = reason
	Logbook.note(world, "CLOSE", String(p["company"]), "plant closed", why.merged({"reason": reason}), {"closed": [false, true]}, "", pid)
	return true


## A company ends (the user, 2026-11-18, of builders left with no employees: "Nothing they are shut gone dead"): its
## status becomes ENDED (one of the law's DEAD names, LawCompany: no longer trading; Anni's yes) and every part of the
## economy that reads only OPEN companies leaves it. Nothing else is done to it: its account stays as it is, its debts
## stay owed (Justice collects what the account holds), no liquidation (step 5). One END row. False if not OPEN.
static func end_company(world: WorldState, cid: String, reason: String, why: Dictionary = {}) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or String(c["status"]) != "OPEN":
		return false
	c["status"] = "ENDED"
	c["ended_m"] = world.month
	c["ended_why"] = reason
	Logbook.note(world, "END", cid, "company ended", why.merged({"reason": reason, "balance": world.ledger.balance(CoreUtil.acct(cid)) / CoreUtil.S}),
		{"status": ["OPEN", "ENDED"]})
	return true


static func reopen_plant(world: WorldState, pid: String, reason: String, why: Dictionary = {}) -> bool:
	var p: Dictionary = world.table(PLANT_TABLE).get(pid, {})
	if p.is_empty() or not bool(p["closed"]):
		return false
	p["closed"] = false
	p["closed_why"] = ""
	Logbook.note(world, "REOPEN", String(p["company"]), "plant reopened", why.merged({"reason": reason}), {"closed": [true, false]}, "", pid)
	return true


static func is_price_fixed(world: WorldState, cid: String) -> bool:
	return bool(world.peek(TABLE).get(cid, {}).get("price_fixed", false))


# ---------------------------------------------------------------- reading (for every other part of the game)

## Every company id, sorted as text ("company:10" before "company:2"): a fixed order, not the order of creation.
static func ids(world: WorldState) -> Array:
	return CoreUtil.sorted_keys(world.peek(TABLE))


## A copy of a company's record, or {} if there is none.
static func record(world: WorldState, cid: String) -> Dictionary:
	return (world.peek(TABLE).get(cid, {}) as Dictionary).duplicate(true)


static func size_of(world: WorldState, cid: String) -> String:
	return String(world.peek(TABLE).get(cid, {}).get("size", ""))


static func type_of(world: WorldState, cid: String) -> String:
	return String(world.peek(TABLE).get(cid, {}).get("type", ""))


static func owner(world: WorldState, cid: String) -> Dictionary:
	return (world.peek(TABLE).get(cid, {}).get("owner", {}) as Dictionary).duplicate(true)


static func owner_kind(world: WorldState, cid: String) -> String:
	return String(world.peek(TABLE).get(cid, {}).get("owner", {}).get("kind", ""))


static func is_state(world: WorldState, cid: String) -> bool:
	return owner_kind(world, cid) == "STATE"


## The price a company posts for one thing it sells (milli-credits; the bank's rate in per mille), or -1.
static func price(world: WorldState, cid: String, key: String) -> int:
	return int(world.peek(TABLE).get(cid, {}).get("price", {}).get(key, -1))


## A plant: {id, company, type, size, sixths, condition (0..100), closed, closed_why ("" when open), line}, or {}.
static func plant(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.peek(PLANT_TABLE).get(pid, {})
	if p.is_empty():
		return {}
	var c: Dictionary = world.peek(TABLE).get(String(p["company"]), {})
	return {"id": pid, "company": String(p["company"]), "type": String(p["type"]), "size": String(p["size"]),
		"sixths": TypeTable.sixths(String(p["size"])), "condition": int(p["condition"]) / 1000,
		"closed": bool(p["closed"]), "closed_why": String(p.get("closed_why", "")), "line": int(c.get("line", 0))}


## Every plant id, sorted, closed ones included.
static func plant_ids(world: WorldState) -> Array:
	return CoreUtil.sorted_keys(world.peek(PLANT_TABLE))


static func plant_ids_of(world: WorldState, cid: String) -> Array:
	return (world.peek(TABLE).get(cid, {}).get("plants", []) as Array).duplicate()


# ---------------------------------------------------------------- inside

## The key a line's price is kept under: the item, "BW", "FREIGHT", "RATE", or "@<client kind>".
static func _sells_key(type: String, idx: int) -> String:
	var o := TypeTable.out_of(type, idx)
	if TypeTable.is_item(o):
		return o
	match String(TypeTable.way(type)["price"]):
		"PER_BW":
			return "BW"
		"PER_ROUTE":
			return "FREIGHT"
		"RATE":
			return "RATE"
	return o


static func _owner_ok(owner: Dictionary) -> bool:
	if not owner.has("kind") or not OWNER_KINDS.has(String(owner["kind"])) or not owner.get("holders") is Dictionary:
		return false
	var sum := 0
	for h in owner["holders"]:
		if int(owner["holders"][h]) <= 0:
			return false
		sum += int(owner["holders"][h])
	return sum == 1000
