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

const TypeTable := preload("res://sim/economy/type_table.gd")

const TABLE := "company"
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
## those of the same origin), "area" (its home area).
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
		"owner": {"kind": String(owner["kind"]), "holders": (owner["holders"] as Dictionary).duplicate()},
		"plants": [],              # plant ids; the plants are in table "plant"
		"line": 0,                 # which output line it runs (first = 0, second = 1)
		"staff": {},               # {plant id or "crew": {post tier: {"area|band|skill": {"n": persons × S, "pay": milli-credits a month each}}}}
		"salary": {},              # the HIRING salary: {tier: {area: milli-credits a month}}, moved only by the price rules
		"stock": {},               # {item: {"qty": milli-units, "value": milli-credits in all, "waiting": milli-units}}
		"books": {"month": {}, "year": {}},
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
		"condition": CONDITION_FULL, "closed": false, "opened": world.month}
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
const OUT_REASONS: Array[String] = ["USED", "SPOILED", "SOLD", "EXPORTED", "LOST"]


## Puts goods into a company's stock from a source outside every company (SOURCES): qty_milli units at cost_milli
## milli-credits per unit (0 allowed; a quantity of 0 is refused, so no row of nothing is written). The stock keeps the quantity and its total book value, so its average cost per
## unit is value / qty. Only items, and not grid goods (12.7). Writes a STOCK row with the source as `with`. Returns
## false (nothing changed) for an unknown company or source, a non-item, a grid good, or a quantity or cost below 0.
static func stock_add(world: WorldState, cid: String, item: String, qty_milli: int, cost_milli: int, source: String, why: String) -> bool:
	if not SOURCES.has(source):
		return false
	return _stock_in(world, cid, item, qty_milli, cost_milli, source, why)


## Takes goods out of a company's stock for a reason that is not a passing to another company (OUT_REASONS: an input
## USED, SPOILED, SOLD to households, EXPORTED, LOST). Returns the book value taken out (at the average cost), or -1
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
	_stock_out(world, from_cid, item, qty_milli, "MOVED", why, to_cid)
	return _stock_in(world, to_cid, item, qty_milli, unit_price, from_cid, why)


static func _stock_in(world: WorldState, cid: String, item: String, qty_milli: int, cost_milli: int, source: String, why: String) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.is_item(item) or bool(TypeTable.ITEMS[item]["grid"]) or qty_milli <= 0 or cost_milli < 0:
		return false
	var st: Dictionary = c["stock"]
	if not st.has(item):
		st[item] = {"qty": 0, "value": 0, "waiting": 0}
	var old := int(st[item]["qty"])
	st[item]["qty"] = old + qty_milli
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
	e["qty"] = old - qty_milli
	e["value"] = int(e["value"]) - value
	Logbook.note(world, "STOCK", cid, why, {"item": item, "qty": -qty_milli, "out": reason}, {item: [old, old - qty_milli]}, to)
	return value


## A company's stock of one item: {"qty": milli-units, "value": milli-credits, "waiting": milli-units waiting for
## freight}, all 0 when it holds none.
static func stock_of(world: WorldState, cid: String, item: String) -> Dictionary:
	var e: Dictionary = world.peek(TABLE).get(cid, {}).get("stock", {}).get(item, {})
	return {"qty": int(e.get("qty", 0)), "value": int(e.get("value", 0)), "waiting": int(e.get("waiting", 0))}


# ---------------------------------------------------------------- staff (written only by the household side)

## A worker's salary (plan 9.2, the user: "they have a sallery set on hire then it climbs based on yearly upps set by
## goverment"): it is set when they are hired and is theirs from then on. The company never moves it; it rises once a
## year by the yearly raise (yearly_raise). The three price rules move only the HIRING salary, record["salary"], what
## the company offers a new hire this month. People are counts in pools, so the pay is kept per staff entry (plant,
## post tier, labour key): {"n": persons × S, "pay": milli-credits a month per person}. When people join an entry their
## pay at hire is blended in by head count; people leaving do not change the entry's pay.
## A consequence of the ruling, not a fault to fix: after a few raises the people already employed earn more than the
## hiring salary, so a new hire can cost less than the person beside them. The rules move only the hiring line.

## Adds delta (persons × S, may be negative) to one staff entry: company["staff"][plant_key][post_tier][labour_key].
## plant_key is a plant id of the company, or "crew": a builder's crews (they work at the clients' sites, not at its
## yard, rebuild-building 1, 4.6), whether or not it has a yard; and the staff of a company that has no plant yet
## (a home-world builder, a government subsidiary before its building). labour_key is the household side's
## "area|band|skill" (the area the workers LIVE in, which need not be where the plant hires: reach, 12.5 rule 40).
## pay: for a hire (delta > 0), the salary the joiners are hired at, milli-credits a month each, and required: the
## hirer reads it from hiring_salary(world, cid, tier, the AREA THE PLANT STANDS IN) (plan 9.2: "The district the plant
## hiring is in"), or passes a person's own pay when moving them between entries. Ignored when people leave.
## Writes no Logbook row: the household side's hire or layoff row is the one for the deed.
## Refuses (false, nothing changed) if the company or plant is unknown, the tier is not a tier, or it would go below 0.
static func staff_change(world: WorldState, cid: String, plant_key: String, post_tier: String, labour_key: String, delta: int, pay: int = -1) -> bool:
	var c: Dictionary = world.table(TABLE).get(cid, {})
	if c.is_empty() or not TypeTable.TIER_PM.has(post_tier):
		return false
	if plant_key == "crew":
		if String(c["type"]) != "BUILDER" and not (c["plants"] as Array).is_empty():
			return false
	elif not (c["plants"] as Array).has(plant_key):
		return false
	var st: Dictionary = c["staff"]
	var e: Dictionary = st.get(plant_key, {}).get(post_tier, {}).get(labour_key, {})
	var now := int(e.get("n", 0))
	if now + delta < 0 or (delta > 0 and pay < 0):
		return false
	if delta == 0:
		return true
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
	var old_pay := int(e.get("pay", 0))
	var new_pay := old_pay
	if delta > 0:
		new_pay = (now * old_pay + delta * pay) / (now + delta)
	st[plant_key][post_tier][labour_key] = {"n": now + delta, "pay": new_pay}
	return true


## The salary the company offers a new hire of this tier this month at a plant standing in `area` (the plant's area,
## Terra's Site.of; for "crew", the company's own "area"), milli-credits a month: its own hiring salary there if it has
## set one, else the type table's starting salary. Only the price rules move it.
static func hiring_salary(world: WorldState, cid: String, post_tier: String, area: String) -> int:
	var sal: Dictionary = world.peek(TABLE).get(cid, {}).get("salary", {})
	if sal.has(post_tier) and (sal[post_tier] as Dictionary).has(area):
		return int(sal[post_tier][area])
	return TypeTable.salary(post_tier)


## Sets the hiring salary for a tier in an area (the price rules 1, 2 and 9 for a salary, plan 9.2). It changes what
## new hires are offered, never what anyone already employed is paid. Writes a SALARY row.
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


## The yearly raise (plan 9.2): every staff entry's pay × (1 + raise), the raise being at least the government's minimum
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
				var e: Dictionary = c["staff"][pk][t][lk]
				e["pay"] = int(e["pay"]) * (1000 + r) / 1000
	Logbook.note(world, "RAISE", cid, "yearly raise", {"raise_pm": raise_pm, "minimum_pm": minimum_pm, "given_pm": r},
		{"wage_bill": [before, wage_bill(world, cid)]})
	return true


## Every staff entry with its pay, in a fixed order (plant key, tier, labour key): [{plant_key, post_tier, labour_key,
## n (persons × S), pay (milli-credits a month per person)}]. What the household side's pay_wages pays from.
static func payroll(world: WorldState, cid: String) -> Array:
	var out: Array = []
	var st: Dictionary = world.peek(TABLE).get(cid, {}).get("staff", {})
	for pk in CoreUtil.sorted_keys(st):
		for t in CoreUtil.sorted_keys(st[pk]):
			for lk in CoreUtil.sorted_keys(st[pk][t]):
				var e: Dictionary = st[pk][t][lk]
				out.append({"plant_key": pk, "post_tier": t, "labour_key": lk, "n": int(e["n"]), "pay": int(e["pay"])})
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


## A copy of a company's whole staff dictionary (for the household side's check): each entry {"n", "pay"}.
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


## A plant: {id, company, type, size, sixths, condition (0..100), closed, line}, or {} if there is none.
static func plant(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.peek(PLANT_TABLE).get(pid, {})
	if p.is_empty():
		return {}
	var c: Dictionary = world.peek(TABLE).get(String(p["company"]), {})
	return {"id": pid, "company": String(p["company"]), "type": String(p["type"]), "size": String(p["size"]),
		"sixths": TypeTable.sixths(String(p["size"])), "condition": int(p["condition"]) / 1000,
		"closed": bool(p["closed"]), "line": int(c.get("line", 0))}


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
