extends RefCounted
## MAKING (rebuild step 3; planning/rebuild-step3-joins.md, PRODUCTION 2 and SETTLEMENT 1). Each company's month of
## making, and the orders it posts for its inputs. Preload it: const Making := preload("res://sim/economy/making.gd").
##
## A plant makes: its full output × its output level (rules 3 and 4) × how fully it is staffed for that level × its
## condition × the season (Terra's Site.yield_pm for a farm; 1000 for anything else), and no more than the inputs it
## holds allow. The inputs are taken out of its stock (USED) and the output goes in (OUTPUT). Services and builders do
## not make stock here: a builder's work is Otto's (Building.work_month), a service's clients come with step 4.
## Its making price (plan 12.3, 14) is a month's cost of making divided by its normal full output.
## Money in milli-credits, quantities in milli-units.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Market := preload("res://sim/economy/market.gd")
const Site := preload("res://sim/transport/site.gd")

const S := 1000
## Below this condition a plant makes less, in proportion (Otto's 5.3, rebuild-building.md; plants, not homes).
const CONDITION_FULL_FROM := 50
## Stocking up on an input (plan 9.3, Bob's proposal): when the cheapest offer is at most this share of what the input
## is worth to the company, it orders one month more, for inputs that keep (spoiling less than KEEPS_PM a month).
const AHEAD_BELOW_PM := 800
const KEEPS_PM := 50


# ---------------------------------------------------------------- PRODUCTION

## Every open company's plants make their month. Returns {company id: {item: milli-units made}}.
static func month(world: WorldState) -> Dictionary:
	var out := {}
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["status"]) != "OPEN":
			continue
		var line := int(c["line"])
		var item := TypeTable.out_of(String(c["type"]), line)
		if not TypeTable.is_item(item):
			continue
		for pid in c["plants"]:
			var made := make_plant(world, cid, String(pid))
			if made > 0:
				if not out.has(cid):
					out[cid] = {}
				out[cid][item] = int(out[cid].get(item, 0)) + made
	return out


## One plant's month. Returns the milli-units made. Writes a MAKE row with every factor it used.
static func make_plant(world: WorldState, cid: String, pid: String) -> int:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var p := Company.plant(world, pid)
	if p.is_empty() or bool(p["closed"]):
		return 0
	var type := String(c["type"])
	var line := int(c["line"])
	var item := TypeTable.out_of(type, line)
	var size := String(p["size"])
	var full := TypeTable.output_milli(type, size, line)
	var level := Company.level_of(world, cid, pid)
	# staffed is read against the work the level asks for, not rounded (posts × level): one person on a quarter of a
	# family farm's work does it, and makes it (Wilma's fault, the user: "NO ROUNDING ERRORS ...")
	var want_n := Company.work_wanted(world, cid, pid)
	# trained workers (new hires count less while they learn, 9.2) and the family (15e)
	var trained := Company.trained_count(world, cid, "", pid)
	var fam := Company.family_count(world, cid, "", pid)
	var staffed := 0 if want_n <= 0 else mini(1000, (trained + fam) * 1000 / want_n)
	# the family's own work counts at the row's output a worker with no size penalty, whatever the output level (the
	# user, 15e: "10 purple each"; a family alone "can make 20 at a minimum"; "The rest goes down the two adults owning
	# dose not"; Wilma's (b): the penalty stays on the size, "You penalty is fine", for hired hands). The level governs
	# the rest: the hired hands' work on the posts the family leaves, at the size's share (a family farm's 9.4 a post)
	# The user spoke of the family FARM ("10 purple each", "the two adults owning"): another family company's family
	# works as staff, at the size's share, within the level's work, as before (Terra's review: a ruling is kept to what
	# it was about)
	var hired_part := 0
	var family_part := 0
	if TypeTable.family_works_full(type):
		var posts := TypeTable.posts(type, size, line)
		var total := (int(posts["G"]) + int(posts["S"]) + int(posts["Sp"])) * S
		var rest_full := 0 if total <= 0 else full * maxi(0, total - fam) / total
		var want_h := Company.hired_work_wanted(world, cid, pid)
		var hired_used := mini(trained, want_h)
		hired_part = 0 if want_h <= 0 else rest_full * level / 1000 * (hired_used * 1000 / want_h) / 1000
		family_part = fam * _per_worker(type, line) / S
	else:
		var used := mini(trained + fam, want_n)
		hired_part = 0 if want_n <= 0 else full * level / 1000 * (used * 1000 / want_n) / 1000
	var cond := int(p["condition"])
	var cond_pm := 1000 if cond >= CONDITION_FULL_FROM else cond * 1000 / CONDITION_FULL_FROM
	var yield_pm := yield_of(world, type, pid)
	var out := (hired_part + family_part) * cond_pm / 1000 * yield_pm / 1000
	# inputs: what this output needs, limited by what is held
	var need := {}
	var full_in := TypeTable.inputs_milli(type, size, line)
	var num := 1   # the share of the output its inputs allow: num / den, exactly (the scarcest input)
	var den := 1
	for k in full_in:
		if full <= 0:
			continue
		need[k] = int(full_in[k]) * out / full
		if TypeTable.ITEMS[k]["grid"]:
			continue   # power and water come over the grid (step 4); in step 3 no type that may be founded needs them
		var held := int(Company.stock_of(world, cid, String(k))["qty"])
		if int(need[k]) > held and held * den < num * int(need[k]):
			num = held
			den = int(need[k])
	var limit_pm := num * 1000 / den
	if num < den:
		out = out * num / den
		for k in need:
			need[k] = int(need[k]) * num / den
	var inputs_value := 0
	for k in CoreUtil.sorted_keys(need):
		if TypeTable.ITEMS[k]["grid"] or int(need[k]) <= 0:
			continue
		inputs_value += maxi(0, Company.stock_take(world, cid, String(k), int(need[k]), "USED", "input for " + item))
	if out > 0:
		var cost := 0 if out <= 0 else (inputs_value + _share_of_wages(world, cid)) * S / out
		Company.stock_add(world, cid, item, out, cost, "OUTPUT", "made")
	Company.book(world, cid, "made:" + item, out)
	Company.book(world, cid, "inputs", inputs_value)
	Logbook.note(world, "MAKE", cid, "made " + item, {"full": full, "level_pm": level, "staffed_pm": staffed, "condition_pm": cond_pm,
		"yield_pm": yield_pm, "inputs_pm": limit_pm}, {item: [0, out]}, "", pid)
	return out


## What one worker makes a month at full on a type's line, milli-units, with no size penalty: the full-size row's
## output over its posts (a farm: 240 over 24, ten; the user: "10 purple each"). A family's own work counts at this.
static func _per_worker(type: String, line: int) -> int:
	var ln: Dictionary = TypeTable.line(type, line)
	var posts := 0
	for t in ln["lab"]:
		posts += int(ln["lab"][t])
	return 0 if posts <= 0 else int(ln["qty"]) * S / posts


## The season's share for a plant this month, per mille: Terra's Site.yield_pm for a type that grows from the land
## (TypeTable.grows), 1000 for any other.
static func yield_of(world: WorldState, type: String, pid: String) -> int:
	if not TypeTable.grows(type):
		return 1000
	return Site.yield_pm(world, pid, world.month)


static func _share_of_wages(world: WorldState, cid: String) -> int:
	var n := maxi(1, Company.plant_ids_of(world, cid).size())
	return Company.wage_bill(world, cid) / n


# ---------------------------------------------------------------- the family eats first (15e)

## A farm family eats from its own farm first, before anything is sold (rebuild-company.md 12.3 15e, the user,
## 2026-11-18: "the farmers themselves I RULED EATS THEMSELVES FIRST, THEY ARE THREE THEY CAN PRODUVE 30 ... THEY WOULD
## TAKE SIX OUT OF THIRTY SELL 24"). Takes up to `want` milli-units of `item` out of the company's stock for the family
## that works it, at book value and with no money (it is their own farm), and returns what it took. The household side
## (Maja's post_orders, before Market.clear) says how much the family wants and where it goes; so the take is never
## offered, and rules 3 and 4, which read what was offered and sold, never see it. Bob's reading: from the farm's whole
## stock, not only this month's making: food it made and has not sold is still its own. Books "took:<item>"; one TAKE
## row. A company with no family, or nothing held, gives nothing.
static func family_take(world: WorldState, cid: String, item: String, want: int) -> int:
	var fam := Company.family_of(world, cid)
	var held := int(Company.stock_of(world, cid, item)["qty"])
	var took := mini(want, held)
	if fam == "" or took <= 0:
		return 0
	Company.stock_take(world, cid, item, took, "FAMILY", "the family eats first")
	Company.book(world, cid, "took:" + item, took)
	Logbook.note(world, "TAKE", cid, "the family took %s from its own farm" % item, {"family": fam, "want": want},
		{item: [held, held - took]}, fam)
	return took


# ---------------------------------------------------------------- making price

## The making price of what a company makes (plan 12.3, 14), milli-credits per unit: this month's cost of making
## (wages due, inputs used, upkeep, and `other` a month: rent, freight it pays, the interest on its loans; not loan
## repayments) divided by its NORMAL FULL output (all its open plants at full), not by what it made or sold. 0 for a
## company with no open plant.
static func making_price(world: WorldState, cid: String, other: int = 0) -> int:
	var c: Dictionary = world.peek(Company.TABLE).get(cid, {})
	if c.is_empty():
		return 0
	var full := 0
	for pid in c["plants"]:
		var p := Company.plant(world, String(pid))
		if not bool(p["closed"]):
			full += TypeTable.output_milli(String(c["type"]), String(p["size"]), int(c["line"]))
	if full <= 0 and bool(c["crew_posts"]):
		full = TypeTable.output_milli(String(c["type"]), String(c["size"]), int(c["line"]))   # a builder's crew
	if full <= 0:
		return 0
	var b := Company.books_month(world, cid)
	var cost := int(b.get("wages_due", Company.wage_bill(world, cid))) + int(b.get("inputs", 0)) + int(b.get("upkeep", 0)) + other
	return cost * S / full


# ---------------------------------------------------------------- SETTLEMENT 1: companies' input orders

## Every open company that makes from inputs orders what next month's making at its level needs, less what it holds,
## at most at what the input is worth to it and what its money reaches (plan 12.3, 23a); and, when the cheapest offer
## is well under that worth, more of an input that keeps, up to two months' need held (stocking up, plan 9.3).
## Returns the order ids.
static func post_orders(world: WorldState) -> Array:
	var ids: Array = []
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["status"]) != "OPEN":
			continue
		var type := String(c["type"])
		var line := int(c["line"])
		var item := TypeTable.out_of(type, line)
		if not TypeTable.is_item(item):
			continue
		var need := {}
		for pid in c["plants"]:
			var p := Company.plant(world, String(pid))
			if bool(p["closed"]):
				continue
			var full_in := TypeTable.inputs_milli(type, String(p["size"]), line)
			for k in full_in:
				need[k] = int(need.get(k, 0)) + int(full_in[k]) * Company.level_of(world, cid, String(pid)) / 1000
		var acct := CoreUtil.acct(cid)
		var buyer := {"kind": "COMPANY", "id": cid, "acct": acct, "area": String(c["area"])}
		for k in CoreUtil.sorted_keys(need):
			if TypeTable.ITEMS[k]["grid"]:
				continue
			var want := int(need[k]) - int(Company.stock_of(world, cid, String(k))["qty"])
			if want <= 0:
				continue
			var worth := input_worth(world, cid, String(k))
			var can := world.ledger.balance(acct) * S / want
			var oid := Market.order(world, buyer, String(k), want, mini(worth, can))
			if oid != "":
				ids.append(oid)
			# stocking up tops it up to two months' need at most: what it bought ahead it does not buy again
			var held := int(Company.stock_of(world, cid, String(k))["qty"])
			var ahead_q := 2 * int(need[k]) - maxi(held, int(need[k]))
			var offs := Market.offers(world, String(k), String(c["area"]))
			if ahead_q > 0 and not offs.is_empty() and TypeTable.spoil_pm(String(k)) < KEEPS_PM \
					and int(offs[0]["price"]) * 1000 <= worth * AHEAD_BELOW_PM:
				var ahead := Market.order(world, buyer, String(k), ahead_q, mini(worth, can), "AHEAD")
				if ahead != "":
					ids.append(ahead)
	return ids


## What a unit of an input is worth to a company (the most it will pay on an ordinary order, plan 9.3): what its
## output sells for, less the other inputs at today's offers, spread over this input's share of a unit of output.
## Never below 0.
static func input_worth(world: WorldState, cid: String, input: String) -> int:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var type := String(c["type"])
	var line := int(c["line"])
	var ln := TypeTable.line(type, line)
	var item := String(ln["out"])
	var q_out := int(ln["qty"])
	var per := float(int(ln["in"][input])) / float(q_out)   # units of the input per unit of output
	if per <= 0.0:
		return 0
	var value := float(Company.price(world, cid, item))
	for k in ln["in"]:
		if k == input or TypeTable.ITEMS[k]["grid"]:
			continue
		var offs := Market.offers(world, String(k), String(c["area"]))
		var p := TypeTable.start_price(String(k)) if offs.is_empty() else int(offs[0]["price"])
		value -= float(int(ln["in"][k])) / float(q_out) * float(p)
	return maxi(0, int(value / per))
