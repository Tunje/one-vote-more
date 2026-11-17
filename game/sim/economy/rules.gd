extends RefCounted
## THE NINE RULES, step 3's part (rebuild plan section 6 and 12.3; planning/rebuild-step3-joins.md, COMPANY_AI 1 and
## the founding signal). One implementation, called for every company every month; no type has its own copy.
## Preload it: const Rules := preload("res://sim/economy/rules.gd").
##
## In COMPANY_AI, from what happened this month, for each open company in id order:
##   1. its signals, once, from the market's clear (Market.seller_signal) and its books;
##   2. price, rules 1, 2 and 9: by k × s / (1 + s) of the price, the same both ways (12.3, 15); rule 9 decides only
##      when both signals come in one month; a company whose prices are fixed (the Stores) is left alone;
##   3. the hold-back: a seller below its making price offers what covers its monthly expenses and holds the rest
##      ("It sells too cover all monthly expences");
##   4. output, rules 3 and 4: the output level by g × s / (1 + s), never above full (12.3, 15b); rule 3 does not act
##      while it holds stock back (12.3, 18);
##   5. the hiring salary, rules 1, 2 and 9 for a salary (9.2): up while posts stay open, down while more apply than it
##      has posts; the starting-salary line decides only a tie;
##   6. a company that could not pay its wages lays off what it could not pay, and a plant left with nobody is shut
##      (12.3, 19a); then it hires or lays off toward the posts its output level wants, through the household side,
##      at the hiring salary of the plant's area;
##   7. its books close for the month.
## And, for the founders and the plans, rule 7's and rule 8's signal (12.3, 15a): work() and founding().
## Every decision writes a RULE row with the numbers it read. Money in milli-credits, quantities in milli-units.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Market := preload("res://sim/economy/market.gd")
const Making := preload("res://sim/economy/making.gd")
const Households := preload("res://sim/population/households.gd")
const HomeBuilders := preload("res://sim/economy/home_builders.gd")

const S := 1000
## k: how far a price (or a hiring salary) can move in a month, per mille (12.3, 15: "starts at 0.2").
const K_PM := 200
## g: how far an output level can move in a month, per mille (12.3, 15b: "g = 0.25 to start"; k·e + g < 2).
const G_PM := 250
## The months of work rule 7 averages (15a: "averaged per month over the last twelve months").
const WORK_MONTHS := 12
## Persons in a household for the needs line (the type table's 2.5), per mille.
const HOUSEHOLD_PERSONS_PM := 2500


# ---------------------------------------------------------------- the month

static func month(world: WorldState) -> void:
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["status"]) != "OPEN":
			continue
		company_month(world, cid)


static func company_month(world: WorldState, cid: String) -> void:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var making := Making.making_price(world, cid)
	var holding := false
	for item in CoreUtil.sorted_keys(c["price"]):
		if not TypeTable.is_item(String(item)):
			continue
		var sig := Market.seller_signal(world, cid, String(item))
		if not Company.is_price_fixed(world, cid):
			price_rule(world, cid, String(item), sig, making)
		holding = hold_back(world, cid, String(item), making) or holding
		if String(item) == TypeTable.out_of(String(c["type"]), int(c["line"])):
			output_rule(world, cid, sig, holding)
	# The public works department (known by its origin mark, not its name) does not sell on a market: it builds only
	# when the government commissions it (plan 99), so the price and output rules have nothing to read for it. Its
	# crew stays and is paid until the government decides otherwise, which is the purse's business at step 8 (Wilma).
	var public_works := String(c.get("origin", "")) == HomeBuilders.ORIGIN_PUBLIC
	if String(TypeTable.way(String(c["type"]))["sells"]) == "BW" and not public_works:
		# a builder runs the same price and output rules on its building work, from its own signal (Otto's
		# Building.seller_signal, in Market.seller_signal's shape); it does not hold back (12.3, 22)
		var bsig := building_signal(world, cid)
		if not Company.is_price_fixed(world, cid):
			price_rule(world, cid, "BW", bsig, making)
		output_rule(world, cid, bsig, false)
	salary_rules(world, cid)
	staff_to_posts(world, cid)
	Company.close_month(world, cid)


## A builder's market signal for its building work, from the building side (Otto): {"offered", "sold", "price",
## "unmet_above", "refused"} in BW milli-units, or {} until that piece is in the tree.
static func building_signal(world: WorldState, cid: String) -> Dictionary:
	const PATH := "res://sim/economy/building.gd"
	if not ResourceLoader.exists(PATH):
		return {}
	var b: GDScript = load(PATH)
	for m in b.get_script_method_list():
		if String(m["name"]) == "seller_signal":
			return b.call("seller_signal", world, cid)
	return {}


# ---------------------------------------------------------------- price: rules 1, 2, 9

## The share a price or level moves by: k × s / (1 + s), per mille; s = num / den; den 0 with a signal = the full k.
static func step_pm(k_pm: int, num: int, den: int) -> int:
	if num <= 0:
		return 0
	if den <= 0:
		return k_pm
	return k_pm * num / (num + den)


## Rules 1, 2 and 9 for one thing a company sells. Returns the new price.
static func price_rule(world: WorldState, cid: String, item: String, sig: Dictionary, making: int) -> int:
	var price := Company.price(world, cid, item)
	if sig.is_empty() or price < 0:
		return price
	var sold := int(sig["sold"])
	var unmet := int(sig["unmet_above"])
	var unsold := int(sig["offered"]) - sold
	var up := step_pm(K_PM, unmet, sold)
	var down := step_pm(K_PM, unsold, sold)
	var which := ""
	if up > 0 and down > 0:
		# rule 9: below the making price climbing has priority, above it lowering
		which = "R1" if price < making else "R2"
	elif up > 0:
		which = "R1"
	elif down > 0:
		which = "R2"
	if which == "":
		return price
	var new_price := price * (1000 + up) / 1000 if which == "R1" else price * (1000 - down) / 1000
	var why := {"sold": sold, "unmet_above": unmet, "unsold": unsold, "refused": int(sig["refused"]), "making_price": making,
		"step_pm": up if which == "R1" else down, "both": up > 0 and down > 0}
	Company.set_price(world, cid, item, new_price, why, "%s %s price" % [which, "raise" if which == "R1" else "lower"])
	return new_price


## The hold-back (section 6): below its making price a seller offers only what covers its monthly expenses (its wage
## bill and what its making used up; repayments come with the bank) and holds the rest. At or above it, it holds
## nothing. Returns true while it holds stock back.
static func hold_back(world: WorldState, cid: String, item: String, making: int) -> bool:
	var price := Company.price(world, cid, item)
	var stock := int(Company.stock_of(world, cid, item)["qty"])
	var hold := 0
	if price > 0 and price < making and stock > 0:
		var b := Company.books_month(world, cid)
		var expenses := Company.wage_bill(world, cid) + int(b.get("inputs", 0)) + int(b.get("upkeep", 0))
		var cover := mini(stock, (expenses * S + price - 1) / price)
		hold = stock - cover
	Company.set_hold(world, cid, item, hold, {"price": price, "making_price": making, "stock": stock})
	return hold > 0


# ---------------------------------------------------------------- output: rules 3, 4

## Rules 3 and 4 on every plant of a company (or on its crew, for a company with crew posts and no plant): up while it
## sold out with orders left (not while it holds stock back), down while it offered and did not sell. Never above full.
## A level rises by g·s/(1+s) of itself, but at least of one post's share of full: output comes in whole people, and a
## level walked down to 0 must be able to climb back when it is asked for more (Otto's review).
static func output_rule(world: WorldState, cid: String, sig: Dictionary, holding: bool) -> void:
	if sig.is_empty():
		return
	var sold := int(sig["sold"])
	var unmet := int(sig["unmet_above"])
	var unsold := int(sig["offered"]) - sold
	var up := 0 if holding else step_pm(G_PM, unmet, sold)
	var down := step_pm(G_PM, unsold, sold)
	if up <= 0 and down <= 0:
		return
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var keys: Array = Company.plant_ids_of(world, cid)
	if keys.is_empty() and bool(c["crew_posts"]):
		keys = ["crew"]
	for pk in keys:
		var lv := Company.level_of(world, cid, String(pk))
		var size := String(c["size"]) if String(pk) == "crew" else String(Company.plant(world, String(pk))["size"])
		var posts := TypeTable.posts(String(c["type"]), size, int(c["line"]))
		var n := maxi(1, int(posts["G"]) + int(posts["S"]) + int(posts["Sp"]))
		var new_lv := mini(1000, lv + maxi(lv, 1000 / n) * up / 1000) if up > 0 else lv * (1000 - down) / 1000
		if new_lv != lv:
			Company.set_level(world, cid, String(pk), new_lv, {"rule": "R3" if up > 0 else "R4", "sold": sold, "unmet_above": unmet,
				"unsold": unsold, "step_pm": up if up > 0 else down, "holding": holding})


# ---------------------------------------------------------------- the hiring salary: rules 1, 2, 9 for a salary

## For each tier the company has posts in: up while posts stay open (rule 1), down while more people out of work in
## its area have that skill than it has open posts (rule 2: more apply than it has posts). The starting-salary line
## decides a tie (rule 9). Only the HIRING salary moves; nobody's pay (9.2).
static func salary_rules(world: WorldState, cid: String) -> void:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var area := String(c["area"])
	var keys: Array = ["crew"]
	keys.append_array(c["plants"])
	for tier in ["G", "S", "Sp"]:
		var want := 0
		for pk in keys:
			want += int(Company.posts_wanted(world, cid, String(pk))[tier])
		if want <= 0:
			continue
		var have := Company.staff_count(world, cid, tier) / S
		var open := maxi(0, want - have)
		var sal := Company.hiring_salary(world, cid, tier, area)
		# who applies (9.2): the household side's own count, the same one its hiring uses: the jobless of this skill
		# or higher, and only if this salary meets their needs (needs_line). Below the line nobody applies, so the
		# lowering rule has nothing to act on and the salary cannot fall through it.
		var jobless := _applicants(world, area, tier, sal)
		var surplus := maxi(0, jobless - open)
		var up := step_pm(K_PM, open, have)
		var down := step_pm(K_PM, surplus, want) if open == 0 else 0
		var line := TypeTable.salary(tier)
		var which := ""
		if up > 0 and down > 0:
			which = "R1" if sal < line else "R2"
		elif up > 0:
			which = "R1"
		elif down > 0:
			which = "R2"
		if which == "":
			continue
		var new_sal := sal * (1000 + up) / 1000 if which == "R1" else sal * (1000 - down) / 1000
		Company.set_hiring_salary(world, cid, tier, area, new_sal, {"rule": which, "posts": want, "staff": have, "open": open,
			"applicants": jobless, "needs": needs_line(world, area), "step_pm": up if which == "R1" else down, "line": line})


## Applicants for a post of this tier at this pay: the household side's Households.applicants when it has one (Maja,
## step 3), else the jobless of exactly this skill while the pay meets the needs line.
static func _applicants(world: WorldState, area: String, tier: String, pay: int) -> int:
	var h: GDScript = Households
	for m in h.get_script_method_list():
		if String(m["name"]) == "applicants":
			return int(h.call("applicants", world, area, tier, pay))
	if pay < needs_line(world, area):
		return 0
	var n := 0
	var free: Dictionary = Households.unemployed(world, area, tier)
	for pid in free:
		n += int(free[pid])
	return n


## A worker's needs in an area (plan 12.5, 38, as revised): the rent of a home there and a household's food, the same
## two things the starting salary is built from (12.5, 37). milli-credits a month. Rent: the cheapest home a landlord
## there asks for (the landing shelters at first); food: the cheapest FOOD offered there, else its starting price.
## One figure for the rules and the households (Maja's applying reads it too).
static func needs_line(world: WorldState, area: String) -> int:
	var rent := -1
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["type"]) == "LANDLORD" and String(c["status"]) == "OPEN" and String(c["area"]) == area:
			var r := Company.price(world, cid, "@home")
			if r >= 0 and (rent < 0 or r < rent):
				rent = r
	if rent < 0:
		rent = TypeTable.start_price_of("LANDLORD")
	var offs := Market.offers(world, "FOOD", area)
	var food := TypeTable.start_price("FOOD") if offs.is_empty() else int(offs[0]["price"])
	return rent + food * HOUSEHOLD_PERSONS_PM / 1000


# ---------------------------------------------------------------- staff to the posts

## First 19a: wages it could not pay are laid off in proportion; a plant left with nobody is shut. Then each plant key
## hires or lays off toward the posts its output level wants, at the hiring salary of the plant's area.
static func staff_to_posts(world: WorldState, cid: String) -> void:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var b := Company.books_month(world, cid)
	var due := int(b.get("wages_due", 0))
	var paid := int(b.get("wages", due))
	var keys: Array = ["crew"]
	keys.append_array(c["plants"])
	if due > 0 and paid < due:
		for pk in keys:
			for tier in ["G", "S", "Sp"]:
				var n := Company.staff_count(world, cid, tier, String(pk)) / S
				var go := (n * (due - paid) + due - 1) / due
				if go > 0:
					Households.layoff(world, cid, String(pk), tier, go, {"reason": "UNPAID", "due": due, "paid": paid})
			if String(pk) != "crew" and Company.staff_count(world, cid, "", String(pk)) == 0:
				Company.close_plant(world, String(pk), "NO_STAFF", {"due": due, "paid": paid})
		Logbook.note(world, "RULE", cid, "19a could not pay its staff", {"due": due, "paid": paid})
		return
	for pk in keys:
		var want := Company.posts_wanted(world, cid, String(pk))
		for tier in ["Sp", "S", "G"]:
			var have := Company.staff_count(world, cid, tier, String(pk)) / S
			var w := int(want[tier])
			if w > have:
				Households.hire(world, cid, String(pk), tier, String(c["area"]), w - have, {"rule": "posts"})
			elif w < have:
				Households.layoff(world, cid, String(pk), tier, have - w, {"reason": "LEVEL"})


# ---------------------------------------------------------------- rules 7 and 8: the founding signal

## Rule 7's work for a type in an area (15a), milli-credits a month: what buyers ordered of the item the type makes
## (what they spent or tried to spend), averaged over up to the last WORK_MONTHS settled months, at today's price
## (the cheapest offer there, else the starting price). 0 for a type that sells no item (services come with step 4).
static func work(world: WorldState, type: String, area: String) -> int:
	var item := TypeTable.out_of(type, 0)
	if not TypeTable.is_item(item):
		return 0
	var h := Market.history(world, item, area, WORK_MONTHS)
	if h.is_empty():
		return 0
	var qty := 0
	for m in h:
		qty += int(m["ordered"])
	qty /= h.size()
	var offs := Market.offers(world, item, area)
	var price := TypeTable.start_price(item) if offs.is_empty() else int(offs[0]["price"])
	return qty * price / S


## What a company of this type and size costs to run a month at full, milli-credits: its posts at the starting
## salaries, its inputs at today's offers (the starting price where none), and its upkeep.
static func running_cost(world: WorldState, type: String, size: String, area: String) -> int:
	var cost := 0
	var posts := TypeTable.posts(type, size)
	for t in posts:
		cost += int(posts[t]) * TypeTable.salary(String(t))
	var inp := TypeTable.inputs_milli(type, size)
	for k in inp:
		var offs := Market.offers(world, String(k), area)
		var p := TypeTable.start_price(String(k)) if offs.is_empty() else int(offs[0]["price"])
		cost += int(inp[k]) * p / S
	var u := TypeTable.upkeep_milli(type, size)
	cost += int(u["material"]) * TypeTable.start_price("MATERIAL") / S + int(u["bw"]) * TypeTable.start_price("BW") / S
	return cost


## Rules 7 and 8 (15a): for each size, the newcomer's share of the work (its plant's sixths over every plant of the type
## serving the area, its own included; plans do not count) and whether that share covers what a company of that size
## costs to run. {size: {"work_share", "cost", "covers"}}. A founder plans the largest size that covers and that their
## money reaches; the founder's own reading (12.11, 77) bends it on their side. log_row false: a plain read (a plan's
## re-read before signing), with no row.
static func founding(world: WorldState, type: String, area: String, log_row: bool = true) -> Dictionary:
	var w := work(world, type, area)
	var have := 0
	for pid in Company.plant_ids(world):
		var p := Company.plant(world, String(pid))
		if String(p["type"]) != type or bool(p["closed"]):
			continue
		if String(world.peek(Company.TABLE)[p["company"]]["area"]) != area:
			continue
		have += int(p["sixths"])
	var out := {}
	for size in TypeTable.SIZES:
		var six := TypeTable.sixths(size)
		var share := w * six / (have + six)
		var cost := running_cost(world, type, size, area)
		out[size] = {"work_share": share, "cost": cost, "covers": share >= cost}
	if log_row:
		Logbook.note(world, "RULE", type, "R7/8 founding signal", {"area": area, "work": w, "plants_sixths": have},
			{"covers": [{}, out.keys().filter(func(s): return out[s]["covers"])]})
	return out
