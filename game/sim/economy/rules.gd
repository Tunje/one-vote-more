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
##   5. the hiring offer (9.2, the user 2026-11-18, replacing rules 1, 2 and 9 for a salary): a new opening is offered
##      the starting salary; it climbs 5% for each month a post stays unfilled, and the rise is gone once filled;
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
const Grants := preload("res://sim/economy/grants.gd")
const WorkLaw := preload("res://sim/law/work_law.gd")
## Ella's job adverts (media) and the month's layoffs fact; loaded when needed.
const MEDIA_PATH := "res://sim/media/media_ops.gd"
const PUBLISH_PATH := "res://sim/economy/econ_publish.gd"
## What a new hire makes less than a trained worker over their training, in months of a worker's output, per mille:
## the sum of (1000 - Company.trained_pm(a)) for a = 0 .. TRAIN_MONTHS - 1 (1.75 months with half rising to full).
## Anni's law (what a company paid on its debts this month); loaded when needed.
const JUSTICE_PATH := "res://sim/law/justice_ops.gd"
## Otto's building side; it preloads this file, so this file loads it when it is needed.
const BUILDING_PATH := "res://sim/economy/building.gd"

const S := 1000
## k: how far a price can move in a month at most, per mille, the same up and down: the user's 5% (rebuild-company.md
## section 3, 2026-11-18: "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP GOT FUCKING DAMNED IT GO BACK AND LOOK AT
## THE DAMNED RULES"; rule 9: "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"). It was 0.2 from the paper's
## 15, which was wrong. Every price rule steps by it: rules 1 and 2 for what a company sells, a builder's BW price.
const K_PM := 50
## g: how far an output level can move in a month at most, per mille, the same up and down: the user's 5% (section 3,
## 2026-11-18, told it was built at 25%: "25?! 5!!! CHANGE IT!!! STOP HEDGING"). It was 0.25 from Bob's 15b proposal.
## Every output rule steps by it: rules 3 and 4 on plants and on crews.
const G_PM := 50
## Rule 4: output is lowered only after this many months in a row with over half of what was offered unsold (the user,
## section 3, 2026-11-18: "only lowered if over 50% of offered goods is not sold 3 months in a row").
const UNSOLD_MONTHS := 3
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
	if not ResourceLoader.exists(BUILDING_PATH):
		return {}
	var b: GDScript = load(BUILDING_PATH)
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

## Rules 3 and 4 on every plant of a company (or on its crew, for a company with crew posts and no plant): up the whole
## 5% when it sold out (the user: "if you sell out all your producing produce MORE": everything it offered sold, or
## nothing to offer while orders came), not while it holds stock back. Down only as the user ruled (section 3, rule 4,
## 2026-11-18): "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row";
## in every other month unsold goods lower the price (rule 2) and the level stays. A month counts when more than half
## of what it offered went unsold (exactly half does not; a month that offered nothing does not); any other month
## starts the count again. The cut is the whole 5% (G_PM), and each further month of the run cuts 5% again (the user:
## "A CUT IS 5% WHY IS THIS STILL A PROBLEM???? AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN"). Never above full.
## A rise is 5% of the level, at least 1 per mille (the smallest step a level has), so a level walked down to 0 climbs
## back when it is asked for more and no rise passes the user's 5% except that one-per-mille step.
static func output_rule(world: WorldState, cid: String, sig: Dictionary, holding: bool) -> void:
	if sig.is_empty():
		return
	var sold := int(sig["sold"])
	var unmet := int(sig["unmet_above"])
	var offered := int(sig["offered"])
	var unsold := offered - sold
	# rule 3, the user: "if you sell out all your producing produce MORE": sold out is everything it offered sold, or
	# nothing to offer while orders came; then up by the whole 5% (G_PM), not while it holds stock back (12.3, 18)
	var sold_out := (offered > 0 and sold >= offered) or (offered == 0 and unmet > 0)
	var up := G_PM if sold_out and not holding else 0
	var run := _unsold_run(world, cid, offered > 0 and unsold * 2 > offered)
	var down := G_PM if run >= UNSOLD_MONTHS else 0   # the whole 5%, each month of the run from the third
	if up <= 0 and down <= 0:
		return
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var keys: Array = Company.plant_ids_of(world, cid)
	if keys.is_empty() and bool(c["crew_posts"]):
		keys = ["crew"]
	for pk in keys:
		var lv := Company.level_of(world, cid, String(pk))
		# the change is computed, not the new level (Terra's review; the user: "NO ROUNDING ERRORS"): a cut is floored, so
		# never more than 5% of the level; a rise is 5% of the level (Otto measured the old "one post's share" base at up
		# to 12.5% of a low level), but at least 1 per mille, the smallest step a level has, so a level at 0 still climbs
		var new_lv := mini(1000, lv + maxi(1, lv * up / 1000)) if up > 0 else lv - lv * down / 1000
		if new_lv != lv:
			Company.set_level(world, cid, String(pk), new_lv, {"rule": "R3" if up > 0 else "R4", "sold": sold, "unmet_above": unmet,
				"unsold": unsold, "step_pm": up if up > 0 else down, "holding": holding, "months_over_half": run})


## The months in a row, this one included, that a company offered goods and more than half went unsold (rule 4, the
## user: "over 50% of offered goods is not sold 3 months in a row"). Counted once a month: a second call in the same
## month recounts from the months before it. 0 when this month does not count.
static func _unsold_run(world: WorldState, cid: String, over_half: bool) -> int:
	var c: Dictionary = world.table(Company.TABLE)[cid]
	var run: Dictionary = c.get("unsold_run", {"m": -99, "n": 0, "before": 0})
	var before := 0
	if int(run["m"]) == world.month - 1:
		before = int(run["n"])
	elif int(run["m"]) == world.month:
		before = int(run["before"])
	var n := before + 1 if over_half else 0
	c["unsold_run"] = {"m": world.month, "n": n, "before": before}
	return n


# ---------------------------------------------------------------- the hiring offer (9.2, replacing rules 1, 2, 9)

## How far the offer climbs for each month a post stays unfilled, per mille (the user, 2026-11-18: "it should only
## climb max 5% if it cost not hire for one month", "5% each month"). Bob's reading of "max 5%": always 5%.
const OFFER_CLIMB_PM := 50
## The starting salary is this many per mille of the area's rent (9.2, the user, 2026-11-18: "just rent at 2×", then
## "3 5x housing try it"). One constant, so the multiple is set by the user's word.
const STARTING_RENT_PM := 2000   # the user, 2026-11-18, after the 2x and 3.5x trials: "2", "Merge with 2"
## Those placed in a job at the landing (the government's staff and the build crews) are paid this many per mille of
## the area's rent from the start (9.2, the user, 2026-11-18: "Place the goverment staff from startb with the builders
## and lets set their sallery at 2.5 from start same for builders that would mean they don't jump either from start").
const PLACED_RENT_PM := 2500


## The hiring offer (rebuild-company.md 9.2, "How the hiring offer moves"; the user 2026-11-18, verbatim: "increases
## should not stack for seperate offers, infact they should fall back to the original rule for settin on hire, then it
## should only climb max 5% if it cost not hire for one month"; "5% each month, it goes i never said i wanted the rule
## for lowering"). For each tier and each area the company's plants (or its crew) stand in:
##   1. a new opening is offered the starting salary (Company.hiring_salary when no climb is set);
##   2. if a post could not be filled for a whole month, the offer climbs 5%, and again each further month;
##      Bob's reading of "a whole month": posts of the tier left open after LAST month's hiring that are still open now
##      (per plant key, the smaller of the two; staff_to_posts records what its hiring left open). A post opened since
##      then has not waited a whole month;
##   3. once no post has stayed unfilled a whole month, the rise is gone and the offer is the starting salary again,
##      so a later opening starts from it: increases do not stack for separate offers;
##   4. there is no rule for lowering.
## The family's posts are not hired for (15e), so they are never open. Only the HIRING offer moves; nobody's pay (9.2).
## After a month in which the company did not hire because it could not pay its wages (19a), the offer is held, neither
## climbing nor falling back: no post was filled, and it did not try (Otto's review; Bob's reading).
static func salary_rules(world: WorldState, cid: String) -> void:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	if int(c.get("no_hiring_m", -1)) == world.month - 1:
		return
	var left: Dictionary = c.get("open_left", {})
	var keys: Array = ["crew"]
	keys.append_array(c["plants"])
	var by := {}   # "tier|area": [posts open now, posts open a whole month]
	for pk in keys:
		var at := Households.plant_area(world, cid, String(pk))
		if at == "":
			continue
		var want := Company.hire_wanted(world, cid, String(pk))   # the family netted whatever post it stands on (15e)
		for tier in ["G", "S", "Sp"]:
			var w := int(want[tier])
			var open := maxi(0, w - Company.staff_count(world, cid, tier, String(pk)) / S)
			var l: Array = left.get("%s|%s" % [pk, tier], [-1, 0])
			var before := int(l[1]) if int(l[0]) == world.month - 1 else 0
			var acc: Array = by.get("%s|%s" % [tier, at], [0, 0])
			by["%s|%s" % [tier, at]] = [int(acc[0]) + open, int(acc[1]) + mini(open, before)]
	var sal: Dictionary = c["salary"]
	for tier in sal:
		for area in sal[tier]:
			if not by.has("%s|%s" % [tier, area]):
				by["%s|%s" % [tier, area]] = [0, 0]   # a climbed offer where it has no posts left: back to the start
	for k in CoreUtil.sorted_keys(by):
		var parts := String(k).split("|", true, 1)
		var tier := parts[0]
		var area := parts[1]
		var a: Array = by[k]
		if int(a[1]) > 0:
			var old := Company.hiring_salary(world, cid, tier, area)
			Company.set_hiring_salary(world, cid, tier, area, old * (1000 + OFFER_CLIMB_PM) / 1000, {"rule": "OFFER_CLIMB",
				"open": int(a[0]), "open_a_month": int(a[1]), "step_pm": OFFER_CLIMB_PM, "start": starting_salary(world, area, tier)})
		elif Company.offer_has_climbed(world, cid, tier, area):
			Company.clear_hiring_salary(world, cid, tier, area, {"rule": "OFFER_BACK", "open": int(a[0])})


## The starting salary of a tier in an area (9.2, the user, 2026-11-18: "Change the sallery from fod and rent to just
## rent at 2× we will have to find a better formula for it later", then "3 5x housing try it", then after both trials "2"; "On sallery
## it's an avrage of the area"): STARTING_RENT_PM (2) x the rent of a home, times the tier's share (S 1.5, Sp 2.25
## times general); food is out of it. What a new opening is offered (the user, 2026-11-18: "fall back to the original
## rule for settin on hire"). milli-credits a month.
## Bob's readings: the rent is the plain average of what the open landlords of the area ask for a home; with no landlord
## there, the landing's shelter at half a new house (the type table's own basis).
static func starting_salary(world: WorldState, area: String, tier: String) -> int:
	return area_rent(world, area) * STARTING_RENT_PM / 1000 * int(TypeTable.TIER_PM[tier]) / 1000


## The salary of a person placed in a job at the landing (9.2, the user, 2026-11-18: "their sallery at 2.5 from start
## same for builders"): PLACED_RENT_PM (2.5) x the rent of a home, times the tier's share. milli-credits a month.
static func placed_salary(world: WorldState, area: String, tier: String) -> int:
	return area_rent(world, area) * PLACED_RENT_PM / 1000 * int(TypeTable.TIER_PM[tier]) / 1000


## The rent the salaries above are counted from: the plain average of what the open landlords of the area ask for a
## home; with no landlord there, the landing's shelter at half a new house.
static func area_rent(world: WorldState, area: String) -> int:
	var sum := 0
	var n := 0
	for cid in Company.ids(world):
		var c: Dictionary = world.peek(Company.TABLE)[cid]
		if String(c["type"]) == "LANDLORD" and String(c["status"]) == "OPEN" and String(c["area"]) == area:
			var r := Company.price(world, cid, "@home")
			if r >= 0:
				sum += r
				n += 1
	return sum / n if n > 0 else TypeTable.start_price_of("LANDLORD") / 2


## A worker's needs in an area (plan 12.5, 38, as revised): the rent of a home there and a household's food (the
## starting salary is rent only since 2026-11-18, 9.2). milli-credits a month. Rent: the cheapest home a landlord
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
	return rent + int(needs_food(world, area)["price"]) * HOUSEHOLD_PERSONS_PM / 1000


## The FOOD price the needs line reads in an area: {"price", "from"}. The cheapest FOOD offered there; when nothing is
## offered (sold out), the last price FOOD actually sold at there; the starting price only if it never sold there
## (Wilma: a sold-out market is not a cheap one). "from": OFFER, LAST_SOLD or START, for the rows that weigh it.
static func needs_food(world: WorldState, area: String) -> Dictionary:
	var offs := Market.offers(world, "FOOD", area)
	if not offs.is_empty():
		return {"price": int(offs[0]["price"]), "from": "OFFER"}
	var last := Market.last_sold(world, "FOOD", area)
	if not last.is_empty():
		return {"price": int(last["price"]), "from": "LAST_SOLD"}
	return {"price": TypeTable.start_price("FOOD"), "from": "START"}


# ---------------------------------------------------------------- staff to the posts

## First 19a: wages it could not pay are laid off in proportion; a plant left with nobody is shut. Then each plant key
## hires or lays off toward the posts its output level wants, at the hiring salary of the plant's area, and notes what
## its hiring left open (_note_open_left).
static func staff_to_posts(world: WorldState, cid: String) -> void:
	family_to_posts(world, cid)   # the family first: its posts are never hired for, and it is never laid off (15e)
	var staff0 := Company.staff_count(world, cid)
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
		world.table(Company.TABLE)[cid]["no_hiring_m"] = world.month   # no hiring this month: next month's offer holds
		_publish_layoffs(world, cid, staff0)
		return
	var ad := _advertised(world, cid)
	var seen := {}
	for pk in keys:
		var want := Company.hire_wanted(world, cid, String(pk))
		for tier in ["Sp", "S", "G"]:
			var have := Company.staff_count(world, cid, tier, String(pk)) / S
			# the family's posts are not hired for and the family is never laid off (15e): hire for what it leaves,
			# the family netted from the persons the work needs whatever post it stands on (Company.hire_wanted)
			var w := int(want[tier])
			var key := "%s|%s" % [pk, tier]
			var slack: Dictionary = _slack(world, cid)
			if w > have:
				slack.erase(key)
				_advertise(world, cid, key, tier, String(c["area"]), w - have)
				_hire(world, cid, String(pk), tier, String(c["area"]), w - have)
			elif w < have:
				if not slack.has(key):
					slack[key] = world.month
				var idle := world.month - int(slack[key]) + 1
				var wg := layoff_weighing(world, cid, String(pk), tier, idle)
				if bool(wg["lay_off"]):
					Households.layoff(world, cid, String(pk), tier, have - w, wg.merged({"reason": "LEVEL"}))
					slack.erase(key)
				else:
					Logbook.note(world, "RULE", cid, "keeps its slack staff: a layoff costs more than their wages while idle",
						wg.merged({"plant": pk, "tier": tier, "slack": have - w}))
			else:
				slack.erase(key)
			var open_now := maxi(0, w - Company.staff_count(world, cid, tier, String(pk)) / S)
			_note_open_left(world, cid, key, open_now)
			# the posts paid for stay paid while they stay open; a post filled or no longer wanted is gone, so if it opens
			# again it is paid again (9.2, the user, 2026-11-18)
			var still := mini(int(ad.get(key, 0)), open_now)
			if still > 0:
				ad[key] = still
				seen[key] = true
			else:
				ad.erase(key)
	for key in ad.keys():
		if not seen.has(key):
			ad.erase(key)   # a plant gone from the company: its open posts with it
	_publish_layoffs(world, cid, staff0)


## What this month's hiring left open at one plant key and tier ("plant|tier"), for next month's offer (salary_rules:
## a post still open then could not be filled for a whole month).
static func _note_open_left(world: WorldState, cid: String, key: String, n: int) -> void:
	var c: Dictionary = world.table(Company.TABLE)[cid]
	if not c.has("open_left"):
		c["open_left"] = {}
	if n > 0:
		c["open_left"][key] = [world.month, n]
	else:
		c["open_left"].erase(key)


## Months in a row each post tier at each plant has wanted fewer people than it has: {plant|tier: the month it began}.
static func _slack(world: WorldState, cid: String) -> Dictionary:
	var c: Dictionary = world.table(Company.TABLE)[cid]
	if not c.has("slack"):
		c["slack"] = {}
	return c["slack"]


## The open posts at one plant key and tier ("plant|tier") whose job advert a company has paid and that are not filled
## yet: {key: posts}. A post is advertised once, when it opens (9.2, the user, 2026-11-18, verbatim: "On posts when you
## many an open post you pay the first time not every consecutive month after").
static func _advertised(world: WorldState, cid: String) -> Dictionary:
	var c: Dictionary = world.table(Company.TABLE)[cid]
	if not c.has("advertised"):
		c["advertised"] = {}
	return c["advertised"]


## Pays the job adverts for the posts open at `key` that are not paid for yet (9.2: hiring costs an advert in the
## papers, a tenth of a month's pay of the post, Ella's Media.job_advert_cost). Paid once, in the month the post opens,
## whether or not anyone is hired that month (Wilma's reading of the user's words). A company that cannot pay the
## advert cannot hire into that post: it pays for as many as its money reaches (each advert is one post's; Otto's
## earlier review: all or none would trap a company that could restart with a few), and a post it could not pay for is
## advertised in the first month it can. Returns the posts paid for now.
static func _advertise(world: WorldState, cid: String, key: String, tier: String, area: String, open: int) -> int:
	var ad := _advertised(world, cid)
	var paid_for := mini(int(ad.get(key, 0)), open)
	var new := open - paid_for
	if new <= 0:
		return 0
	var media: GDScript = load(MEDIA_PATH)
	var pay := Company.hiring_salary(world, cid, tier, area)
	var acct := CoreUtil.acct(cid)
	var one := int(media.call("job_advert_cost", world, area, pay, 1))
	var can := new if one <= 0 else mini(new, maxi(0, world.ledger.balance(acct)) / one)
	if can < new:
		Logbook.note(world, "HIRE", cid, "fewer posts advertised: it cannot pay all the job adverts", {"post": key,
			"opened": new, "can": can, "advert_each": one / S, "balance": world.ledger.balance(acct) / S})
	if can > 0:
		var paid := int(media.call("job_advert", world, cid, acct, area, pay, can))
		Company.book(world, cid, "adverts", paid)
	ad[key] = paid_for + can
	return can


## Hires up to n for a post tier, into the open posts whose advert is paid (_advertise); nothing is paid at the hire, so
## a post that stays open month after month costs no more and is filled with no advert money in the account.
static func _hire(world: WorldState, cid: String, pk: String, tier: String, area: String, n: int) -> int:
	var key := "%s|%s" % [pk, tier]
	var ad := _advertised(world, cid)
	var can := mini(n, int(ad.get(key, 0)))
	if can <= 0:
		return 0
	var k := Households.hire(world, cid, pk, tier, area, can, {"rule": "posts", "advertised": int(ad[key])})
	if k > 0:
		ad[key] = int(ad[key]) - k   # filled: that post's advert is used
	return k


## How a company weighs laying off slack staff at one post tier and plant (9.2, the user: "they would have to weigh say
## three months of vages without a worker against the profits"; Bob's reading in rebuild-company.md): per person,
## the wages it saves while the post stands idle against the layoff pay owed, the advert and the training's lower
## output when it hires again. idle: the months the slack has lasted (the expected months it lasts on). Returns the
## numbers it weighed and "lay_off".
static func layoff_weighing(world: WorldState, cid: String, pk: String, tier: String, idle: int) -> Dictionary:
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var n := 0
	var sum := 0
	for e in Company.payroll(world, cid):
		if String(e["plant_key"]) == pk and String(e["post_tier"]) == tier:
			n += int(e["n"])
			sum += int(e["n"]) * int(e["pay"]) / S
	var pay := sum * S / n if n > 0 else Company.hiring_salary(world, cid, tier, String(c["area"]))
	var months := WorkLaw.layoff_pay_months(world)
	var media: GDScript = load(MEDIA_PATH)
	var advert := int(media.call("job_advert_cost", world, String(c["area"]), Company.hiring_salary(world, cid, tier, String(c["area"])), 1))
	var size := String(c["size"]) if pk == "crew" else String(Company.plant(world, pk)["size"])
	var posts := TypeTable.posts(String(c["type"]), size, int(c["line"]))
	var n_posts := maxi(1, int(posts["G"]) + int(posts["S"]) + int(posts["Sp"]))
	var per_worker := TypeTable.output_milli(String(c["type"]), size, int(c["line"])) / n_posts
	var item := TypeTable.out_of(String(c["type"]), int(c["line"]))
	var price := maxi(0, Company.price(world, cid, item))
	var loss_pm := 0
	for a in Company.TRAIN_MONTHS:
		loss_pm += 1000 - Company.trained_pm(a)
	var training := per_worker * loss_pm / 1000 * price / S
	var saved := idle * pay
	var costs := months * pay + advert + training
	return {"lay_off": saved > costs, "idle": idle, "pay": pay / S, "layoff_months": months, "advert": advert / S,
		"training": training / S, "price": price / S, "saved": saved / S, "costs": costs / S}


## The month's layoffs at one company, once (Ella's EconPublish.layoffs decides whether they are news): how many, its
## staff before, and the layoff pay owed and paid (Maja's layoff books them).
static func _publish_layoffs(world: WorldState, cid: String, staff0: int) -> void:
	var n := (staff0 - Company.staff_count(world, cid)) / S
	if n <= 0:
		return
	var b := Company.books_month(world, cid)
	var pub: GDScript = load(PUBLISH_PATH)
	pub.call("layoffs", world, {"company": cid, "area": String(world.peek(Company.TABLE)[cid]["area"]), "n": n,
		"staff": staff0 / S, "owed": int(b.get("layoff_owed", 0)), "paid": int(b.get("layoff_paid", 0)),
		"months_pay": WorkLaw.layoff_pay_months(world)})


## A family company's family in its posts, every month before hiring (15e): the founder's household's adults by skill
## (Maja's Households.family_adults, kept in step with deaths by her reconcile_families) fill the full posts of its
## first open plant (or its crew), each tier from adults of that skill or above (Company.family_fill). They work every
## post they can, whatever the output level: they are never laid off. Maja's family_work marks them employed; the
## record follows. A company with no family does nothing here.
static func family_to_posts(world: WorldState, cid: String) -> void:
	var fam := Company.family_of(world, cid)
	if fam == "":
		return
	var c: Dictionary = world.peek(Company.TABLE)[cid]
	var pk := "crew"
	var size := String(c["size"])
	for p in Company.plant_ids_of(world, cid):
		if not bool(Company.plant(world, String(p))["closed"]):
			pk = String(p)
			size = String(Company.plant(world, pk)["size"])
			break
	if pk == "crew" and not bool(c["crew_posts"]):
		return
	var fill := Company.family_fill(TypeTable.posts(String(c["type"]), size, int(c["line"])), Households.family_adults(world, fam))
	var now := {}
	for t in ["G", "S", "Sp"]:
		now[t] = Company.family_count(world, cid, t) / S
	if now == fill:
		return
	Households.family_work(world, fam, fill)
	for other in Company.plant_ids_of(world, cid):
		if String(other) != pk:
			Company.family_set(world, cid, String(other), fam, {})
	Company.family_set(world, cid, pk, fam, fill)


# ---------------------------------------------------------------- the family's winnings (15e)

## What a family company's family takes this month (the user, plan 12.3 15e: "The owners of a family farm should take
## winnings no sallery, wich comes after and saves the issue"): what the month earned after everything else it owed
## that month was paid (Bob's reading, on Wilma's brief; Otto's review: the founder's opening money and a grant are the
## company's capital, not winnings). Taken in JUSTICE after the debts are collected, so the month's takings less its
## inputs, the wages it paid, upkeep, adverts, layoff pay and the debts it paid. Never more than the account holds above
## what it keeps back: one month of what the family does not do (the hired staff's wages, inputs and upkeep, the same
## expenses the hold-back covers). A loss is carried forward (the user, 15e: "I think two is better"): a month that
## earned less than nothing adds to the company's carried loss; a month that earned something first pays it down, and
## the family takes only what is beyond it. Pure: pay_winnings applies it once a month.
## {"amount", "earned", "carried" (before this month), "pays_down", "carried_after", "balance", "keep", ...}.
## It reads the month just lived (_month_lived): in the real month the rules have closed its books (Rules.month, in
## COMPANY_AI) before JUSTICE pays the winnings, so the open books are already the next month's and empty (Wilma's
## fault: no family was ever paid).
static func winnings(world: WorldState, cid: String) -> Dictionary:
	var b := _month_lived(world, cid)
	var wages := Company.wage_bill(world, cid)
	var inputs := int(b.get("inputs", 0))
	var upkeep := int(b.get("upkeep", 0))
	var debts := int((load(JUSTICE_PATH) as GDScript).call("paid_this_month", world, cid))
	var earned := int(b.get("rev", 0)) - inputs - int(b.get("wages", 0)) - upkeep - int(b.get("adverts", 0)) \
		- int(b.get("layoff_paid", 0)) - debts - int(b.get("winnings", 0))   # less what it already took this month
	var keep := wages + inputs + upkeep
	var bal := world.ledger.balance(CoreUtil.acct(cid))
	var carried := int(world.peek(Company.TABLE)[cid].get("loss_carried", 0))
	var pays_down := clampi(earned, 0, carried)
	var after := carried - pays_down + maxi(0, -earned)
	return {"amount": maxi(0, mini(earned - pays_down, bal - keep)), "earned": earned, "carried": carried,
		"pays_down": pays_down, "carried_after": after, "balance": bal, "keep": keep, "wages": wages, "inputs": inputs,
		"upkeep": upkeep, "debts": debts}


## The books of the month just lived: this month's closed books once the rules have closed them, else the open month.
static func _month_lived(world: WorldState, cid: String) -> Dictionary:
	var closed := Company.books_closed(world, cid, world.month)
	return closed if not closed.is_empty() else Company.books_month(world, cid)


## Pays every family company's winnings to its family (the conductor, JUSTICE, after Justice.collect_debts): Maja's
## Households.pay_winnings moves the money and books it as the household's income; the company books "winnings". A
## month with none is logged too: the family lives on what it has.
static func pay_winnings(world: WorldState) -> void:
	for cid in Company.ids(world):
		var fam := Company.family_of(world, String(cid))
		if fam == "" or String(world.peek(Company.TABLE)[cid]["status"]) != "OPEN":
			continue
		var rec: Dictionary = world.table(Company.TABLE)[cid]
		if int(rec.get("winnings_m", -1)) == world.month:
			continue   # once a month: the carried loss moves once
		var wn := winnings(world, String(cid))
		rec["winnings_m"] = world.month
		rec["loss_carried"] = int(wn["carried_after"])
		var amount := int(wn["amount"])
		if amount > 0:
			amount = int(Households.pay_winnings(world, fam, CoreUtil.acct(String(cid)), amount))
			if not Company.book_closed(world, String(cid), world.month, "winnings", amount):
				Company.book(world, String(cid), "winnings", amount)   # the books not closed yet: the month's own
		Logbook.note(world, "WINNINGS", String(cid), "the family took its winnings" if amount > 0 else "no winnings this month",
			{"earned": int(wn["earned"]) / S, "debts": int(wn["debts"]) / S, "loss_carried": int(wn["carried"]) / S,
			"pays_down": int(wn["pays_down"]) / S, "loss_carried_after": int(wn["carried_after"]) / S,
			"balance": int(wn["balance"]) / S, "keep": int(wn["keep"]) / S, "wages": int(wn["wages"]) / S,
			"inputs": int(wn["inputs"]) / S, "upkeep": int(wn["upkeep"]) / S}, {"winnings": [0, amount / S]}, fam)


# ---------------------------------------------------------------- rules 7 and 8: the founding signal

## What a company brings to the market of the item a month (milli-units), over the last WORK_MONTHS: in each closed
## month there, what it made less what its family took (the family's food is not in the orders, 15e); each month it
## has not yet lived counts at `full`, its plants' full output (Wilma, from Terra's trace: a farm founded in autumn
## was read at its winter yield, 3 to 4 a month, a tenth of a farm, and kept founding open). So a new plant starts at
## full output and moves to what it really makes as its first year fills in; with no closed month it is its full
## output. Rule 8's capacity for a standing plant: what it really delivers, not what it could make at full output
## (Wilma's trace: 41 farms "at full output" 1,541 a month, really making about 750). Made, not sold: food on offer
## that buyers could not or would not pay for still covers the work (Ella's review, Wilma's yes), and made counts
## carried stock once, in the month it was made.
static func _delivered_a_month(world: WorldState, cid: String, item: String, full: int) -> int:
	var sum := 0
	var n := 0
	for m in world.peek(Company.TABLE).get(cid, {}).get("books", {}).get("year", []):
		if int(m.get("m", -1)) > world.month - WORK_MONTHS:
			sum += int(m.get("made:" + item, 0)) - int(m.get("took:" + item, 0))
			n += 1
	return (sum + maxi(0, WORK_MONTHS - n) * full) / WORK_MONTHS


## A plan's full output a month by its sixths (plans carry their size as sixths): the size with those sixths.
static func _full_of_sixths(type: String, sixths: int) -> int:
	for size in TypeTable.SIZES:
		if TypeTable.sixths(size) == sixths:
			return TypeTable.output_milli(type, size)
	return 0

## Rule 7's work for a type in an area (15a), milli-credits a month: what buyers ordered of the item the type makes
## (what they spent or tried to spend), averaged over up to the last WORK_MONTHS settled months, at today's price
## (the cheapest offer there, else the starting price). 0 for a type that sells no item (services come with step 4).
static func work(world: WorldState, type: String, area: String) -> int:
	var item := TypeTable.out_of(type, 0)
	if not TypeTable.is_item(item):
		return 0
	var qty := work_qty(world, type, area)
	var offs := Market.offers(world, item, area)
	var price := TypeTable.start_price(item) if offs.is_empty() else int(offs[0]["price"])
	return qty * price / S


## Rule 7's work in quantity (15a): the item ordered in the area a month, milli-units, "averaged per month over the
## last twelve months": the last WORK_MONTHS settled months summed over WORK_MONTHS. In the colony's first year the
## months before it count at the need the government counts for its grant (12.9, 61b; Grants.wanted: the persons who
## buy the item x a person's need), the plan's month-one answer (Bob's reading, Wilma's yes): so the first months'
## store filling (households buy double until six months are held, 15f) is not read as a year of it, and founding does
## not wait for the year to fill. 0 for a type that sells no item. Rule 8 reads it against what the plants seen make.
static func work_qty(world: WorldState, type: String, area: String) -> int:
	var item := TypeTable.out_of(type, 0)
	if not TypeTable.is_item(item):
		return 0
	var h := Market.history(world, item, area, WORK_MONTHS)
	if h.is_empty():
		return 0
	var qty := 0
	for m in h:
		qty += int(m["ordered"])
	var need := 0   # a month before the colony: the persons in the area x a person's need (0 for an item no household needs)
	if Households.NEED_PER_PERSON.has(item):
		for b in Households.buyers(world):
			if String(b["area"]) == area:
				need += int(b["persons"]) * int(Households.NEED_PER_PERSON[item])
	qty += maxi(0, WORK_MONTHS - h.size()) * need
	return qty / WORK_MONTHS


## What a company of this type and size costs to run a month at full, milli-credits: its posts at the area's starting
## salaries (Rules.starting_salary, the user's 2 x the rent, 9.2; it read the type table's 300 before, which is no
## salary anyone is offered), its inputs at today's offers (the starting price where none), and its upkeep.
static func running_cost(world: WorldState, type: String, size: String, area: String) -> int:
	var cost := 0
	var posts := TypeTable.posts(type, size)
	for t in posts:
		cost += int(posts[t]) * starting_salary(world, area, String(t))
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
## costs to run. {size: {"work_share", "cost", "covers"}}. Rule 8 first (the user: do not start one when "the same
## signal says the work is covered"): when what the plants a founder sees deliver a month reaches the work in quantity
## a month (work_qty), the work is covered and no size covers. A standing plant counts what its company really delivered a
## month over the last twelve, made less its family's take, each month it has not yet lived at its full output
## (_delivered_a_month);
## booked and granted plans count at full output (they make nothing yet). In quantity, not money: a dear month does not make the same food look like more work (Wilma's
## fault: the colony founded two to three times the farms it needs). A founder plans the largest size that covers and that their
## money reaches; the founder's own reading (12.11, 77) bends it on their side. log_row false: a plain read (a plan's
## re-read before signing), with no row.
static func founding(world: WorldState, type: String, area: String, log_row: bool = true, except_plan: String = "") -> Dictionary:
	var w := work(world, type, area)
	var standing := 0
	var capacity := 0   # what every plant seen delivers a month, milli-units (rule 8)
	var item := TypeTable.out_of(type, 0)
	var full_of := {}   # a company's plants that make the item, at full output: its delivery is read once (below)
	for pid in Company.plant_ids(world):
		var p := Company.plant(world, String(pid))
		if String(p["type"]) != type or bool(p["closed"]):
			continue
		if String(world.peek(Company.TABLE)[p["company"]]["area"]) != area:
			continue
		standing += int(p["sixths"])
		var line := int(world.peek(Company.TABLE)[p["company"]]["line"])
		if TypeTable.out_of(type, line) != item:
			continue   # only a line that makes the item the work is in counts toward it (Ella)
		full_of[p["company"]] = int(full_of.get(p["company"], 0)) + TypeTable.output_milli(type, String(p["size"]), line)
	for cid in CoreUtil.sorted_keys(full_of):
		capacity += _delivered_a_month(world, String(cid), item, int(full_of[cid]))
	# "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted
	# grants" (the user, plan 12.3 15a): a plan in a builder's book, or a plan still MADE that has its grant, counts
	# by its size as a plant would, each plan once; a plan only made does not. except_plan: the plan re-reading rule 7
	# before it signs, whose own size is the newcomer's below ("its own included"), so it is not counted twice.
	var booked := 0
	var granted := 0
	if ResourceLoader.exists(BUILDING_PATH):
		var b: GDScript = load(BUILDING_PATH)   # building.gd preloads this file, so it is loaded, not preloaded
		var bp: Dictionary = b.call("booked_plans", world, type, area, except_plan)
		for plan_id in bp:
			booked += int(bp[plan_id])
			capacity += _full_of_sixths(type, int(bp[plan_id]))
		var made: Dictionary = b.call("made_plans", world, type, area, except_plan)
		var with_grant: Dictionary = Grants.granted_plans(world)
		for plan_id in made:
			if with_grant.has(plan_id):
				granted += int(made[plan_id])
				capacity += _full_of_sixths(type, int(made[plan_id]))
	var have := standing + booked + granted
	var wq := work_qty(world, type, area)
	var covered := capacity >= wq
	var out := {}
	for size in TypeTable.SIZES:
		var six := TypeTable.sixths(size)
		var share := w * six / (have + six)
		var cost := running_cost(world, type, size, area)
		out[size] = {"work_share": share, "cost": cost, "covers": share >= cost and not covered}
	if log_row:
		Logbook.note(world, "RULE", type, "R7/8 founding signal", {"area": area, "work": w, "plants_sixths": have,
			"standing": standing, "booked": booked, "granted": granted, "work_qty": wq, "capacity": capacity, "covered": covered},
			{"covers": [{}, out.keys().filter(func(s): return out[s]["covers"])]})
	return out
