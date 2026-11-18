extends RefCounted
## The household side of the rebuild, build step 2 (planning/rebuild-households.md; rebuild-company.md 9.1, 12.5).
## Maja. How the old household side worked, written new; no old code and no old numbers.
##
## PEOPLE live in PopStore leaves (hb = the area id, inc = the income band). They are the one record of who exists.
## POOLS ("pool" table): one per area × income band, id "area|band", with one account "pool:<id>". A pool holds money and
##   nothing else that can be read from elsewhere: its head counts are read from the leaves (counts()), and its "count
##   per company" (12.5, 35) from the companies' staff (Company.staff_of_pool). Not the old "hh" table: the old readers
##   of "hh" stay asleep until each is connected on purpose (Wilma, 2026-11-17).
## JOBS: a job is recorded once (9.2), in the company record: company["staff"][plant_key][post_tier]["area|band|skill"]
##   = persons × S, written only through Company.staff_change. hire() and layoff() move the people AND write the entry in
##   one call, so jobs = people holds in one place (check()). The company's rules decide how many; these decide who.
## Every deed writes a Logbook row (rebuild-company.md 13).
##
## Use: const Households := preload("res://sim/population/households.gd")

const Company := preload("res://sim/economy/company.gd")

const S := CoreUtil.S
const ARCH := "MIX"
const BANDS := ["I1", "I2", "I3", "I4", "I5"]
const TIERS := ["G", "S", "Sp"]

## ---------------------------------------------------------------- starting numbers (Maja; Wilma accepted 2026-11-17)
## The founding settlers: 1,000 people in 400 households, 80 households (200 people) in each income band.
const HOUSEHOLD_SIZE := 2.5                 # persons per household: how many homes a pool needs (H1)
const BAND_PERSONS := 200
const BAND_WORKING := 150                   # aged 18 to the retirement age
const BAND_CHILDREN := 44
const BAND_RETIRED := 6
const LF_PM := 900                          # of the working-age, in the labour force (looking for work at landing)
## Adults' skills by band (‰ G / S / Sp): all bands together 60 / 30 / 10.
const BAND_SKILLS := {"I1": [1000, 0, 0], "I2": [900, 100, 0], "I3": [600, 350, 50], "I4": [300, 500, 200], "I5": [200, 550, 250]}
## Working-age adults by age band (‰ Y 18–29 / A 30–49 / M 50–64): a settler ship is young.
const ADULT_AGES := [350, 450, 200]
## Savings a household brings, by band (credits; Bob's type table 9.1: 6, 12, 24, 48 and 120 months of a general salary).
const SAVINGS_PER_HOUSEHOLD := {"I1": 1800, "I2": 3600, "I3": 7200, "I4": 14400, "I5": 36000}


# ================================================================ pools

static func pool_id(area: String, band: String) -> String:
	return area + "|" + band


static func account(pid: String) -> String:
	return "pool:" + pid


static func labour_key(area: String, band: String, skill: String) -> String:
	return "%s|%s|%s" % [area, band, skill]


## [area, band, skill] of a labour key (area ids hold no "|").
static func labour_parts(k: String) -> Array:
	var p := k.split("|")
	return [p[0], p[1], p[2]]


## The pool for (area, band), made with its account on first use.
static func ensure_pool(world: WorldState, area: String, band: String) -> String:
	var pid := pool_id(area, band)
	if not world.peek("pool").has(pid):
		world.table("pool")[pid] = {"id": pid, "area": area, "band": band}
		world.ledger.open_account(account(pid))
	return pid


static func pools(world: WorldState) -> Array:
	return CoreUtil.sorted_keys(world.peek("pool"))


## Head counts of a pool, read from the people (persons × S, the doorway's units): lf, unemployed, employed, nonpart,
## retired, children, owners, persons, households.
static func counts(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.peek("pool").get(pid, {})
	var out := {"lf": 0, "unemployed": 0, "employed": 0, "nonpart": 0, "retired": 0, "children": 0, "owners": 0, "persons": 0}
	if p.is_empty():
		out["households"] = 0
		return out
	for k in PopStore.select(world, {"hb": String(p["area"]), "inc": String(p["band"])}):
		var l: Dictionary = world.peek("pop")[k]
		var n: int = int(l["n"]) * S
		out["persons"] += n
		if String(l["occ"]) == "BUSINESS_OWNER":   # a founder or a founder's family: households of their own (60c, 15e)
			out["owners"] += n
			continue
		match String(l["status"]):
			"EMPLOYED":
				out["lf"] += n
				out["employed"] += n
			"UNEMPLOYED":
				out["lf"] += n
				out["unemployed"] += n
			"RETIRED":
				out["retired"] += n
			"CHILD":
				out["children"] += n
			_:
				out["nonpart"] += n
	out["households"] = int(float(out["persons"] - out["owners"]) / HOUSEHOLD_SIZE)   # owners are households of their own (60c)
	return out


# ================================================================ the founding settlers (12.2, 10)

## Lands the founding settlers in `area` (the Landing): people, pools and the savings they bring. All of working age
## in the labour force are looking for work; the companies of month one hire from them (hire()). Counted as the
## founding population, not as arrivals. Does nothing if anyone lives in the colony already.
static func settle_founders(world: WorldState, area: String) -> int:
	if PopStore.total(world) > 0:
		return 0
	var landed := 0
	for band in BANDS:
		var pid := ensure_pool(world, area, band)
		var sk: Array = BAND_SKILLS[band]
		var lf := BAND_WORKING * LF_PM / 1000
		var np := BAND_WORKING - lf
		_seed(world, area, band, "UNEMPLOYED", CoreUtil.split_lr(lf, sk), true)
		_seed(world, area, band, "NOT_IN_LF", CoreUtil.split_lr(np, sk), true)
		_seed(world, area, band, "RETIRED", CoreUtil.split_lr(BAND_RETIRED, sk), false)
		_seed_children(world, area, band, BAND_CHILDREN)
		var homes := int(float(BAND_PERSONS) / HOUSEHOLD_SIZE)
		var money := homes * int(SAVINGS_PER_HOUSEHOLD[band]) * S
		world.ledger.transfer(Ledger.EXTERNAL, account(pid), money, "LANDING_SAVINGS", world.month)
		Logbook.note(world, "ARRIVE", pid, "founding settlers landed", {"persons": BAND_PERSONS, "households": homes,
			"savings_per_household": SAVINGS_PER_HOUSEHOLD[band]}, {"persons": [0, BAND_PERSONS], "savings": [0, money / S]})
		landed += BAND_PERSONS
	return landed


## Adults of one status in a band, split by skill (counts G, S, Sp), aged as working-age or retired.
static func _seed(world: WorldState, area: String, band: String, status: String, by_skill: Array, working: bool) -> void:
	for i in TIERS.size():
		var n: int = by_skill[i]
		if n <= 0:
			continue
		var ages := {"O": n}
		if working:
			var a := CoreUtil.split_lr(n, ADULT_AGES)
			ages = {"Y": a[0], "A": a[1], "M": a[2]}
		PopStore.seed_leaf(world, {"hb": area, "inc": band, "occ": "NONE", "status": status, "arch": ARCH, "eff": "e0"}, n,
			{"age": ages, "skill": {TIERS[i]: n}})


static func _seed_children(world: WorldState, area: String, band: String, n: int) -> void:
	if n > 0:
		PopStore.seed_leaf(world, {"hb": area, "inc": band, "occ": "NONE", "status": "CHILD", "arch": ARCH, "eff": "e0"}, n,
			{"age": {"C": n}, "skill": {"G": n}})


# ================================================================ jobs (9.2; rebuild-households.md P1, P5–P7, P14)

## The unemployed of skill `skill` in `area`, by pool: {pool id: persons}.
static func unemployed(world: WorldState, area: String, skill: String) -> Dictionary:
	var out := {}
	for band in BANDS:
		var n := PopStore.count(world, {"hb": area, "inc": band, "status": "UNEMPLOYED"}, "skill:" + skill)
		if n > 0:
			out[pool_id(area, band)] = n
	return out


## Company `cid` hires up to n people into posts of `post_tier` at `plant_key` (a plant id, or "crew"), from the
## unemployed living in `area`: people of the post's own skill first, then of a higher skill, never a lower one; within
## a skill nobody goes first: the posts are shared over the income bands in proportion to their unemployed of that
## skill (largest remainder, so the outcome repeats; Bob's month-one check). Moves them to EMPLOYED in the
## occupation the company gives the post, and writes the staff entry. `pay`: the salary these hires get, theirs from
## now on (plan 9.2: set at hire, raised only by the yearly raise); -1 = the company's hiring salary for the post's tier
## in the area the PLANT stands in ("The district the plant hiring is in"; plant_area), not where the workers live.
## The staff entry is written first and the people are moved only once the company record has taken it, so a refusal
## is no hire, never people employed without a post. Returns persons hired.
## trained = true: the landing's own hires, "arrived from the home world, operating" (Wilma's decision): they start
## trained, so no training group is opened for them (Bob's staff_change: since >= 0 is not a new hire). Every other
## hire trains (9.2: half output the first month, full after six).
## placed = true: the landing's build crews (rebuild-company.md 9.2, the user: "The build crews at start should not be
## hiring at all. They should start with a job already active.") and the government's staff ("Place the goverment
## staff from startb with the builders"): they are placed, not hired: no application test against their needs,
## trained (they arrived operating), and paid 2.5 x the rent (Rules.placed_salary) unless a pay is given. The HIRE
## row says "placed". Everything else as a hire.
static func hire(world: WorldState, cid: String, plant_key: String, post_tier: String, area: String, n: int, why: Dictionary = {}, pay: int = -1, trained: bool = false, placed: bool = false) -> int:
	if n <= 0:
		return 0
	if placed:
		trained = true
	var occ := String(Company.occupation(world, cid, post_tier))
	var at := plant_area(world, cid, plant_key)
	if pay < 0:
		if at == "":
			Logbook.note(world, "HIRE", cid, "no hire: the post's plant stands nowhere", {"plant": plant_key, "wanted": n})
			return 0
		# the placed are paid 2.5 x the rent from the start (9.2, the user, 2026-11-18: "lets set their sallery at 2.5
		# from start same for builders"); every hire is offered the company's hiring salary
		pay = int(load("res://sim/economy/rules.gd").placed_salary(world, at, post_tier)) if placed else Company.hiring_salary(world, cid, post_tier, at)
	var needs := needs_per_worker(world, area)
	if pay < needs and not placed:   # "emplyees only apply to jobs that meet their needs" (9.2)
		Logbook.note(world, "HIRE", cid, "no applicants: the pay is below their needs", {"pay": pay, "needs": needs, "area": area, "wanted": n})
		return 0
	var hired := 0
	var taken := {}
	var refused := false
	for skill in TIERS.slice(TIERS.find(post_tier)):
		if hired >= n or refused:
			break
		# within a skill nobody goes first (12.3, 28): the posts are shared over the bands in proportion to their
		# unemployed of that skill (largest remainder, so a run repeats)
		var avail: Array = BANDS.map(func(b): return PopStore.count(world, {"hb": area, "inc": b, "status": "UNEMPLOYED"}, "skill:" + skill))
		var total := 0
		for x in avail:
			total += int(x)
		var parts: Array = CoreUtil.split_lr(mini(n - hired, total), avail)
		for i in BANDS.size():
			var band: String = BANDS[i]
			var k := int(parts[i])
			if k <= 0:
				continue
			if not Company.staff_change(world, cid, plant_key, post_tier, labour_key(area, band, skill), k * S, pay, world.month if trained else -1):
				Logbook.note(world, "HIRE", cid, "no hire: the company record refused the post", {"plant": plant_key, "tier": post_tier, "pay": pay})
				refused = true
				break
			var moved := PopStore.move_group(world, {"hb": area, "inc": band, "status": "UNEMPLOYED"}, k,
				{"status": "EMPLOYED", "occ": occ}, "HIRE", "skill:" + skill)
			assert(moved == k, "hire: counted %d, moved %d" % [k, moved])
			taken[labour_key(area, band, skill)] = k
			hired += k
	if hired > 0:
		var w := why.duplicate()
		w["wanted"] = n
		w["occupation"] = occ
		w["pay"] = pay
		w["trained"] = trained
		if placed:
			w["placed"] = true
		w["plant_area"] = at
		Logbook.note(world, "HIRE", cid, "hired %s %s" % [post_tier, plant_key], w, {"staff": [0, hired], "from": [{}, taken]}, area)
	return hired


## The area a post's plant stands in: for "crew", the company's home area (its record's "area"); for a plant, the area
## Terra's map gives it (ColonyLayout.plants: the area of its block, else of its tile, else the nearest). "" when the
## plant stands nowhere yet.
static func plant_area(world: WorldState, cid: String, plant_key: String) -> String:
	if plant_key == "crew":
		return String(Company.record(world, cid).get("area", ""))
	return String(ColonyLayout.plants(world).get(plant_key, {}).get("area", ""))


## Company `cid` lays off up to n people from posts of `post_tier` at `plant_key`: the largest hire rows first (a
## staff entry keeps one row per hire, Company.payroll), then by key and the rows' own order, so the outcome repeats.
## They keep their occupation and skill (P7). Returns persons laid off.
## Pay owed after a layoff (rebuild-company.md 9.2, the user's ruling on keeping workers): each person laid off is owed
## WorkLaw.layoff_pay_months (Anni's law lever LAW_LAYOFF_PAY_MONTHS, 3) months of their own pay (their hire row's pay). It is paid into the pool they
## go back to, booked as income "layoff_pay", from the company's account as far as it reaches; the rest is owed to that
## pool through the law (Justice.owe, kind LAYOFF_PAY). Every layoff owes it, the 19a layoffs too; quitting, a move for
## better pay, death, retiring and leaving the colony owe nothing (they do not come here). The people are unemployed
## from the day they are laid off, so they draw the benefit too (Wilma's decision).
static func layoff(world: WorldState, cid: String, plant_key: String, post_tier: String, n: int, why: Dictionary = {}) -> int:
	if n <= 0:
		return 0
	var occ := String(Company.occupation(world, cid, post_tier))
	var groups: Array = Company.payroll(world, cid).filter(func(e): return String(e["plant_key"]) == plant_key and String(e["post_tier"]) == post_tier)
	for i in groups.size():
		groups[i]["at"] = i   # payroll's own order: by key, then the rows' order
	groups.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]) or (int(a["n"]) == int(b["n"]) and int(a["at"]) < int(b["at"])))
	var done := 0
	var given := {}
	var owed_by_pool := {}
	var months := int(load("res://sim/law/work_law.gd").layoff_pay_months(world))   # Anni's one reader, the law on the day
	for e in groups:
		if done >= n:
			break
		var lk := String(e["labour_key"])
		var p := labour_parts(lk)
		var k := mini(n - done, int(e["n"]) / S)
		k = PopStore.move_group(world, {"hb": p[0], "inc": p[1], "status": "EMPLOYED", "occ": occ}, k,
			{"status": "UNEMPLOYED"}, String(why.get("reason", "LAYOFF")), "skill:" + p[2])
		if k <= 0:
			continue
		var pay_k := int(e["pay"])   # their own hire row's pay
		var ok: bool = Company.staff_change(world, cid, plant_key, post_tier, lk, -k * S, -1, -1, String(e["row"]))
		assert(ok, "staff_change refused a layoff")
		given[lk] = int(given.get(lk, 0)) + k
		var pid := pool_id(p[0], p[1])
		owed_by_pool[pid] = int(owed_by_pool.get(pid, 0)) + k * pay_k * months
		done += k
	if done > 0:
		var lp := _layoff_pay(world, cid, owed_by_pool)
		Company.book(world, cid, "layoff_owed", int(lp["owed"]))   # the company's month (Bob: he publishes the month's layoffs)
		Company.book(world, cid, "layoff_paid", int(lp["paid"]))
		var w := why.duplicate()
		w["wanted"] = n
		w["layoff_pay_months"] = months
		Logbook.note(world, "LAYOFF", cid, "laid off %s %s" % [post_tier, plant_key], w, {"staff": [done, 0], "to": [{}, given],
			"layoff_pay_owed": [0, int(lp["owed"])], "layoff_pay_paid": [0, int(lp["paid"])], "layoff_pay_debt": [0, int(lp["debt"])]})
	return done


## The law's debt collector paid `amount` of a debt of `kind` to `creditor` (Anni's collect_debts calls it after each
## payment, loaded at call time): layoff pay collected later is booked in the pool's month as "layoff_pay", as if paid
## on the day (Wilma); unpaid wages collected later as "wages" in the month they come (Bob's reading: they are the
## wages, paid late). Any other creditor or kind: nothing to book.
static func debt_received(world: WorldState, creditor: String, kind: String, amount: int) -> void:
	if amount <= 0 or not world.peek("pool").has(creditor):
		return
	if kind == "LAYOFF_PAY":
		_book(world, creditor, "layoff_pay", amount)
	elif kind == "UNPAID_WAGES":
		_book(world, creditor, "wages", amount)


## The layoff pay of one layoff: {pool id: credits x S owed}. Paid from the company's account as far as it reaches
## (shared over the pools in proportion, as wages are), the rest owed to each pool through the law. Returns
## {owed, paid, debt}.
static func _layoff_pay(world: WorldState, cid: String, owed_by_pool: Dictionary) -> Dictionary:
	var owed := 0
	for pid in owed_by_pool:
		owed += int(owed_by_pool[pid])
	if owed <= 0:
		return {"owed": 0, "paid": 0, "debt": 0}
	var paid_by: Dictionary = _pay(world, CoreUtil.acct(cid), owed_by_pool, "layoff_pay", "LAYOFF_PAY")
	var paid := 0
	var debt := 0
	for pid in CoreUtil.sorted_keys(owed_by_pool):
		paid += int(paid_by.get(pid, 0))
		var rest := int(owed_by_pool[pid]) - int(paid_by.get(pid, 0))
		if rest > 0:
			load("res://sim/law/justice_ops.gd").owe(world, cid, String(pid), account(String(pid)), rest, "LAYOFF_PAY")
			debt += rest
	return {"owed": owed, "paid": paid, "debt": debt}


## Jobs = people (P14, plan 13 "no worker in two jobs"): every company's staff, summed by (area, band, skill,
## occupation), equals the employed people in the leaves. Returns the problems (empty = consistent).
static func check(world: WorldState) -> Array:
	var errs: Array = []
	var jobs := {}
	for cid in Company.ids(world):
		var st: Dictionary = Company.staff_entries(world, cid)
		for pk in CoreUtil.sorted_keys(st):
			for t in CoreUtil.sorted_keys(st[pk]):
				var occ := String(Company.occupation(world, cid, String(t)))
				for lk in CoreUtil.sorted_keys(st[pk][t]):
					var v := int(st[pk][t][lk]["n"])
					if v % S != 0 or v < 0:
						errs.append("%s %s %s %s: %d is not whole persons" % [cid, pk, t, lk, v])
					var bk := "%s|%s" % [lk, occ]
					jobs[bk] = int(jobs.get(bk, 0)) + v / S
	var people := {}
	for k in world.peek("pop"):
		var l: Dictionary = world.peek("pop")[k]
		if String(l["status"]) != "EMPLOYED" or String(l["occ"]) == "BUSINESS_OWNER":
			continue
		for sk in l["skill"]:
			var c := int(l["skill"][sk])
			if c > 0:
				var bk := "%s|%s" % [labour_key(String(l["hb"]), String(l["inc"]), String(sk)), String(l["occ"])]
				people[bk] = int(people.get(bk, 0)) + c
	var keys: Array = jobs.keys()
	for k in people:
		if not jobs.has(k):
			keys.append(k)
	keys.sort()
	for k in keys:
		if int(jobs.get(k, 0)) != int(people.get(k, 0)):
			errs.append("%s: %d in posts, %d employed people" % [k, int(jobs.get(k, 0)), int(people.get(k, 0))])
	return errs


# ================================================================ money in (rebuild-households.md H3, M2, M3, P10)

## Persons of `status` in pool `pid` (whole persons): EMPLOYED, UNEMPLOYED, NOT_IN_LF, RETIRED, CHILD; "" = all.
static func persons(world: WorldState, pid: String, status: String = "") -> int:
	var p: Dictionary = world.peek("pool").get(pid, {})
	if p.is_empty():
		return 0
	var f := {"hb": String(p["area"]), "inc": String(p["band"])}
	if status != "":
		f["status"] = status
	return PopStore.count(world, f)


## This month's income of a pool by kind (wages, benefit, pension, ...), credits x S. Starts afresh each month.
static func income(world: WorldState, pid: String) -> Dictionary:
	var inc: Dictionary = world.peek("pool").get(pid, {}).get("income", {})
	return inc.duplicate() if int(inc.get("month", -1)) == world.month else {}


static func _book(world: WorldState, pid: String, kind: String, amount: int) -> void:
	var p: Dictionary = world.table("pool")[pid]
	if int(p.get("income", {}).get("month", -1)) != world.month:
		p["income"] = {"month": world.month}
	p["income"][kind] = int(p["income"].get(kind, 0)) + amount


## Pays `bill` {pool id: amount} from `from_acct`: all of it if the account holds it, else what it holds, shared in
## proportion (largest remainder), never overdrawing. Books each pool's income under `kind`. Returns {pool id: paid}.
static func _pay(world: WorldState, from_acct: String, bill: Dictionary, kind: String, memo: String) -> Dictionary:
	var ids: Array = CoreUtil.sorted_keys(bill)
	var due := 0
	for pid in ids:
		due += int(bill[pid])
	var have := due if from_acct == Ledger.EXTERNAL else mini(due, maxi(0, world.ledger.balance(from_acct)))
	var parts: Array = CoreUtil.split_lr(have, ids.map(func(x): return int(bill[x])))
	var out := {}
	for i in ids.size():
		var a := int(parts[i])
		if a <= 0:
			continue
		world.ledger.transfer(from_acct, account(String(ids[i])), a, memo, world.month)
		_book(world, String(ids[i]), kind, a)
		out[ids[i]] = a
	return out


## A company's wages for the month (H3): every staff entry's people at that entry's own pay (plan 9.2: a salary is set
## at hire and is the worker's from then on; Company.payroll), into the pools the entries' labour keys name. Paid once a
## month per company, from `from_acct` (its account). When the account cannot cover the bill everyone gets the same
## share of what it holds; laying people off is the company's decision (12.3, 19a), not this function's. What it could
## not pay is owed to each pool (rebuild-company.md 9.2, "Unpaid wages", the user: "Record it make them pay after our
## if they refused take it to court"): a debt of kind UNPAID_WAGES through the law (Justice.owe), collected like layoff
## pay when the company has money (collect_debts; debt_received books it as wages). Returns the amount paid. One Logbook
## PAY row, with what was owed.
static func pay_wages(world: WorldState, cid: String, from_acct: String, why: Dictionary = {}) -> int:
	var bill := {}
	for e in Company.payroll(world, cid):
		var lp := labour_parts(String(e["labour_key"]))
		var amt := int(e["n"]) * int(e["pay"]) / S   # the same sum as Company.wage_bill, so paid and billed never differ
		if amt > 0:
			var pid := pool_id(lp[0], lp[1])
			bill[pid] = int(bill.get(pid, 0)) + amt
	if bill.is_empty():
		return 0
	var paid := _pay(world, from_acct, bill, "wages", "WAGES")
	var due := 0
	var got := 0
	for pid in bill:
		due += int(bill[pid])
		got += int(paid.get(pid, 0))
	var owed := 0
	if from_acct != Ledger.EXTERNAL:
		for pid in CoreUtil.sorted_keys(bill):
			var rest := int(bill[pid]) - int(paid.get(pid, 0))
			if rest > 0:
				load("res://sim/law/justice_ops.gd").owe(world, cid, String(pid), account(String(pid)), rest, "UNPAID_WAGES")
				owed += rest
	var w := why.duplicate()
	w["due"] = due
	Logbook.note(world, "PAY", cid, "wages", w, {"paid": [0, got], "short": [0, due - got], "owed": [0, owed]})
	return got


## The benefit (kind "benefit", the jobless: UNEMPLOYED) or the pension (kind "pension", the RETIRED), from
## `from_acct` (the treasury), per person by area: per_person {area: credits x S a month}. The rates are the
## government's levers (M2, M3); this only pays. Short of money, everyone gets the same share. Returns the amount paid.
## One Logbook PAY row with what each pool got.
static func pay_support(world: WorldState, kind: String, from_acct: String, per_person: Dictionary, why: Dictionary = {}) -> int:
	var status := String({"benefit": "UNEMPLOYED", "pension": "RETIRED"}.get(kind, ""))
	assert(status != "", "pay_support: kind is benefit or pension")
	var bill := {}
	for pid in pools(world):
		var area := String(world.peek("pool")[pid]["area"])
		var amt := persons(world, pid, status) * int(per_person.get(area, 0))
		if amt > 0:
			bill[pid] = amt
	if bill.is_empty():
		return 0
	var paid := _pay(world, from_acct, bill, kind, kind.to_upper())
	var due := 0
	var got := 0
	for pid in bill:
		due += int(bill[pid])
		got += int(paid.get(pid, 0))
	var w := why.duplicate()
	w["due"] = due
	w["by_pool"] = paid.duplicate()
	Logbook.note(world, "PAY", from_acct, kind, w, {"paid": [0, got]})
	return got


# ================================================================ the households' month (rebuild step 3; the joins)

## What one person needs a month (Bob's type table section 2, taken as the household side's starting figure).
const NEED_PER_PERSON := {"FOOD": 1000}   # milli-units; step 3 is food alone
## Founders are counted one by one (12.5, 35): table "founder", ids "founder:N". Their household is themselves (60c: "a founder or owner
## is still a household": they eat and pay rent from their own account).
const PERSON_TABLE := "founder"   # not "person": that table is the staff side's people (politicians)
## The negotiation (9.2, the user): once a year, in this month of the year, an underpaid staff entry (paid below its
## company's average for the tier) asks; the manager meets it halfway when the company's account holds a year of the
## rise. (Wilma: "once a year"; the month and halfway are mine.)
const NEGOTIATE_MONTH := 7
## Departures (C13): of the unemployed young adults, per mille who leave on a ship in port, × how unattractive the
## colony looks (1 − attractiveness).
const LEAVE_PM := 100
## The household's food store (the user, plan 12.3 15f: "They stockplie to have have six months of food in storage, i
## think as often as they can"): it aims to hold this many months of its food need, buying double to get there ("they
## buy 2 units if food instead of one, store it and use it in emergencies"; "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS
## THAT WAS TOO EVEN IF OUT", 2026-11-18, to even it out): the store order in a month is at most one month's need.
const STORE_MONTHS := 6

const Market := preload("res://sim/economy/market.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")


static func _month_rec(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.table("pool")[pid]
	if int(p.get("month", {}).get("m", -1)) != world.month:
		p["month"] = {"m": world.month, "food_need": 0, "food_bought": 0, "food_eaten": 0, "hunger": 0, "hunger_money": 0,
			"hunger_price": 0, "hunger_scarce": 0, "spoiled": 0, "rent_due": 0, "rent_paid": 0, "orders": {},
			"store_bought": 0, "store_eaten": 0, "store_pm": 0, "farm_eat": 0, "farm_store": 0}
	return p["month"]


## This month's money and food of a pool (for the indicators, through the doorway). See _month_rec for the fields.
static func month_of(world: WorldState, pid: String) -> Dictionary:
	var m: Dictionary = world.peek("pool").get(pid, {}).get("month", {})
	return m.duplicate(true) if int(m.get("m", -1)) == world.month else {}


## How much of its food need a pool ate this month, per mille (1000 when it has no record yet).
static func fed_pm(world: WorldState, pid: String) -> int:
	var m: Dictionary = world.peek("pool").get(pid, {}).get("month", {})
	if m.is_empty() or int(m.get("food_need", 0)) <= 0:
		return 1000
	return int(m["food_eaten"]) * 1000 / int(m["food_need"])


static func savings(world: WorldState, pid: String) -> int:
	return world.ledger.balance(account(pid))


## Homes and households in an area: {homes, households, occupancy_pm, shacks, homeless}. Shacks (9.1: "those left build
## shacks or are homeless") come with homes at step 7, as homes on Terra's grid in a form of their own; until then
## "homeless" stands for both, and "shacks" is 0. Homes are AreaStore's (the
## homes in the area's blocks, Terra's cells); households are the pools' plus the owners counted one by one.
static func homes(world: WorldState, area: String) -> Dictionary:
	var hh := 0
	for pid in pools(world):
		if String(world.peek("pool")[pid]["area"]) == area:
			hh += int(counts(world, pid)["households"]) / S
	var landing = load("res://sim/economy/landing.gd")
	for id in world.peek(PERSON_TABLE):
		if String(world.peek(PERSON_TABLE)[id]["area"]) == area and not bool(landing.lives_on_own_farm(world, String(id))) \
				and lives_apart(world, String(id)):
			hh += 1   # "the farm would be their home" (15e): a family on its own farm is no household in town; one
			# whose people are all still in their posts lives in its pool until the plan signs (Terra's review)
	var h := AreaStore.capacity(world, area)
	var fit := h * 1300 / 1000   # beyond 130% nobody else squeezes in (I1)
	return {"homes": h, "households": hh, "occupancy_pm": hh * 1000 / maxi(1, h) if h > 0 else (0 if hh == 0 else 9999),
		"shacks": 0, "homeless": maxi(0, hh - fit)}


# ---------------------------------------------------------------- SETTLEMENT 1: orders

## Every buyer of the household side (pools and owners counted one by one): [{id, acct, area, persons}].
static func buyers(world: WorldState) -> Array:
	var out: Array = []
	for pid in pools(world):
		var c := counts(world, pid)
		var n := (int(c["persons"]) - int(c["owners"])) / S
		if n > 0:
			out.append({"id": pid, "acct": account(pid), "area": String(world.peek("pool")[pid]["area"]), "persons": n})
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		var r: Dictionary = world.peek(PERSON_TABLE)[id]
		out.append({"id": id, "acct": String(r["account"]), "area": String(r["area"]), "persons": family_size(world, String(id)) - in_post(world, String(id))})
	return out


static func _stock(world: WorldState, id: String) -> Dictionary:
	var t := world.table(PERSON_TABLE if id.begins_with("founder:") else "pool")
	var r: Dictionary = t[id]
	if not r.has("stock"):
		r["stock"] = {}
	return r["stock"]


## SETTLEMENT, before Market.clear: each buyer's orders, with its money set aside line by line in the ruled order
## (9.1): food first, then rent (paid after the market), then water and power (no grid in step 3), then the rest. Each
## order carries its line's money as its BUDGET (Bob's Market.order: an order never spends more than its budget,
## whatever order the books clear in), so no line can spend another's money (Otto's review, Wilma's ruling).
## The order is the real need (the month's need less what is held) at the real worth (max_price, 23a: the most it will
## pay per unit). Food is what a household needs first, so a unit of it is worth all the money set aside for food:
## max_price = the food line's budget. What the budget does not reach is a refusal of the price, which the sellers hear.
## Step 3 has food alone, so the food line's budget is all the buyer's money. One BUDGET row per buyer.
## The store (15f, the user): the month's food is bought whole every month (the store is for emergencies, not for
## eating instead of buying); then, from what is left after this month's food and the rent (Wilma's detail: food, rent,
## then the store), a second order, AHEAD, toward STORE_MONTHS months of need held, at most one month's need a month
## (double, never more: 15f as corrected 2026-11-18), at any price the money left can pay ("if your running low and
## don't know how long the ossue will last i don't think you wait"). Its own budget, so
## the month's eating is never crowded out by the store (Bob's Market clears every NEED order before any AHEAD one).
## The store order asks only for what its money buys at today's cheapest offer (Bob's review: rule 7 founds farms on the
## orders posted, and an order nobody can pay for is no work for a farm); with nothing on offer it posts none.
## rent_of: the conductor's Landing.rent_due (as for pay_rent); rent owed from earlier months is set aside too.
## A farm family eats from its own farm first (rebuild-company.md 12.3 15e, the user, 2026-11-18: "THE FARMERS
## THEMSELVES I RULED EATS THEMSELVES FIRST, THEY ARE THREE THEY CAN PRODUVE 30 ... THEY WOULD TAKE SIX OUT OF THIRTY
## SELL 24"): before any order, a founder whose family farm is open takes from its stock the month's need and the
## store's double (Bob's Making.family_take: no money, never offered); the market orders are for what is still missing,
## and the double holds over farm and market together.
static func post_orders(world: WorldState, rent_of: Callable = Callable()) -> int:
	var posted := 0
	for b in buyers(world):
		var id := String(b["id"])
		var area := String(b["area"])
		var need := int(b["persons"]) * int(NEED_PER_PERSON["FOOD"])
		var held := int(_stock(world, id).get("FOOD", 0))
		var money := maxi(0, world.ledger.balance(String(b["acct"])))
		var rec := _rec_of(world, id)
		rec["food_need"] = need
		if need <= 0:
			continue
		var buyer := {"kind": "POOL", "id": id, "acct": String(b["acct"]), "area": area}
		var farm := own_farm(world, id) if id.begins_with("founder:") else ""
		var took := 0
		if farm != "":   # the family eats from its own farm first (15e): the month's need, then the store's double
			took = int(load("res://sim/economy/making.gd").family_take(world, farm, "FOOD", need + mini(need, maxi(0, STORE_MONTHS * need - held))))
			_stock(world, id)["FOOD"] = held + took
			rec["farm_eat"] = mini(took, need)
			rec["farm_store"] = took - int(rec["farm_eat"])
		var buy := need - int(rec["farm_eat"])
		var food_budget := money   # food first: everything; rent and the rest are paid from what it leaves
		var worth := food_budget
		var by := food_by(world, area, buy, food_budget)
		var oid := ""
		if buy > 0:
			oid = Market.order(world, buyer, "FOOD", buy, worth, "NEED", food_budget, by)
		if oid != "":
			rec["orders"]["FOOD"] = oid
			posted += 1
		# the store, from what is left after this month's food (costed on this month's offers) and the rent
		var food_cost := mini(money, food_cost_of(world, area, buy))
		var rent := rent_set_aside(world, id, rent_of)
		var store_budget := maxi(0, money - food_cost - rent)
		# double, never more, until six months are held: what the farm gave the store counts toward both
		var want := mini(need - int(rec["farm_store"]), maxi(0, STORE_MONTHS * need - held - int(rec["farm_store"])))
		var cheapest := -1
		for off in Market.offers(world, "FOOD", area):
			if cheapest < 0 or int(off["price"]) < cheapest:
				cheapest = int(off["price"])
		if cheapest > 0:
			want = mini(want, store_budget * S / cheapest)
		elif cheapest < 0:
			want = 0   # nothing on offer: nothing to store
		var sid := ""
		var sby := ""
		if want > 0 and store_budget > 0:
			sby = food_by(world, area, want, store_budget)
			sid = Market.order(world, buyer, "FOOD", want, store_budget, "AHEAD", store_budget, sby)
			if sid != "":
				rec["orders"]["FOOD_STORE"] = sid
				posted += 1
		Logbook.note(world, "BUDGET", id, "food set aside first, then the rent, then the store", {"need": need, "held": held,
			"money": money, "worth": worth, "lines": {"FOOD": food_budget, "FOOD_COST": food_cost, "RENT": rent, "STORE": store_budget},
			"by": by, "store_by": sby, "store_want": want, "farm": farm}, {"ordered": [0, buy], "store_ordered": [0, want if sid != "" else 0],
			"from_farm": [0, took]}, "", oid)
	return posted


## The open family farm whose family is founder `fid`'s household (15e), or "".
static func own_farm(world: WorldState, fid: String) -> String:
	for cid in Company.ids(world):
		var c := Company.record(world, cid)
		if String(c["type"]) == "FARM" and String(c["status"]) == "OPEN" and Company.family_of(world, cid) == fid:
			return String(cid)
	return ""


## What a buyer sets aside for rent before its store (15f): this month's rent (rent_of, the landlord side's) and what it
## still owes from earlier months.
static func rent_set_aside(world: WorldState, id: String, rent_of: Callable) -> int:
	var r: Dictionary = world.peek(PERSON_TABLE if id.begins_with("founder:") else "pool").get(id, {})
	var total := 0
	for la in (r.get("rent_owed", {}) as Dictionary):
		total += int(r["rent_owed"][la])
	if rent_of.is_valid() and (not id.begins_with("founder:") or lives_apart(world, id)):
		var due: Dictionary = rent_of.call(id)
		for la in due:
			total += int(due[la])
	return total


## How a household's food order is filled (15e, Wilma's decision): "less desirable" is a preference, not a reason to go
## hungry. A household whose food budget covers its whole need, bought in the order buyers rank the offers (ship food a
## quarter dearer), ranks them so ("RANK"); one whose budget does not, takes the cheapest real price first ("PRICE"),
## so nobody goes hungry beside unsold ship food. Costed on this month's offers (Bob's Market.offers, in rank order).
static func food_by(world: WorldState, area: String, qty: int, budget: int) -> String:
	return "RANK" if food_cost_of(world, area, qty) <= budget else "PRICE"


## What qty of food costs on this month's offers, bought in rank order; what is not on offer is costed at the dearest
## offer walked (Bob's review). 0 with no offers.
static func food_cost_of(world: WorldState, area: String, qty: int) -> int:
	var cost := 0
	var left := qty
	var dearest := 0
	for off in Market.offers(world, "FOOD", area):
		if left <= 0:
			break
		var q := mini(left, int(off["qty"]))
		cost += q * int(off["price"]) / S
		dearest = maxi(dearest, int(off["price"]))
		left -= q
	cost += left * dearest / S   # what is not on offer, costed at the dearest offer walked (Bob's review)
	return cost


## A buyer's month record (a pool's or an owner's).
static func _rec_of(world: WorldState, id: String) -> Dictionary:
	if not id.begins_with("founder:"):
		return _month_rec(world, id)
	var r: Dictionary = world.table(PERSON_TABLE)[id]
	if int(r.get("month", {}).get("m", -1)) != world.month:
		r["month"] = {"m": world.month, "food_need": 0, "food_bought": 0, "food_eaten": 0, "hunger": 0, "hunger_money": 0,
			"hunger_price": 0, "hunger_scarce": 0, "spoiled": 0, "rent_due": 0, "rent_paid": 0, "orders": {},
			"store_bought": 0, "store_eaten": 0, "store_pm": 0, "farm_eat": 0, "farm_store": 0}
	return r["month"]


# ---------------------------------------------------------------- SETTLEMENT 3: what was bought

## SETTLEMENT, after Market.clear: what each buyer bought (its month's food and what it bought for its store, 15f) goes
## into its stock; it eats the month's need from the stock: what it bought this month first, the store only when that
## falls short (the user: "store it and use it in emergencies");
## what it could not eat is hunger, counted from need (23), split by why (Bob's Market.filled: NO_MONEY = no money,
## PRICE = refused the price, SOLD_OUT and NO_SELLER = none to be had); then the stock spoils at the item's rate.
## Facts: ECON_FAMINE, ECON_FOOD_SCARCE, ECON_FOOD_UNAFFORDABLE (Ella's paper 4b) from the colony's month.
static func after_market(world: WorldState) -> Dictionary:
	var tot := {"need": 0, "hunger": 0, "money": 0, "price": 0, "scarce": 0}
	for b in buyers(world):
		var id := String(b["id"])
		var rec := _rec_of(world, id)
		var st := _stock(world, id)
		var oid := String(rec["orders"].get("FOOD", ""))
		var got := {}
		if oid != "":
			got = Market.filled(world, oid)
			st["FOOD"] = int(st.get("FOOD", 0)) + int(got.get("qty", 0))
			rec["food_bought"] = int(got.get("qty", 0))
		var sid := String(rec["orders"].get("FOOD_STORE", ""))
		if sid != "":
			rec["store_bought"] = int(Market.filled(world, sid).get("qty", 0))
			st["FOOD"] = int(st.get("FOOD", 0)) + int(rec["store_bought"])
		var need := int(rec["food_need"])
		var eat := mini(need, int(st.get("FOOD", 0)))
		st["FOOD"] = int(st.get("FOOD", 0)) - eat
		rec["food_eaten"] = eat
		rec["store_eaten"] = maxi(0, eat - int(rec["food_bought"]) - int(rec.get("farm_eat", 0)))   # the month's own food (farm, then bought) first, then the store
		var hunger := need - eat
		rec["hunger"] = hunger
		if hunger > 0:
			var why := String(got.get("why", "NO_SELLER" if oid == "" else ""))
			var key := String({"NO_MONEY": "hunger_money", "PRICE": "hunger_price"}.get(why, "hunger_scarce"))
			rec[key] = int(rec[key]) + hunger
		var sp := int(st.get("FOOD", 0)) * TypeTable.spoil_pm("FOOD") / 1000
		st["FOOD"] = int(st.get("FOOD", 0)) - sp
		rec["spoiled"] = sp
		rec["store_pm"] = int(st.get("FOOD", 0)) * 1000 / maxi(1, need)   # months of need held, per mille
		tot["need"] += need
		tot["hunger"] += hunger
		tot["money"] += int(rec["hunger_money"])
		tot["price"] += int(rec["hunger_price"])
		tot["scarce"] += int(rec["hunger_scarce"])
		if hunger > 0 or sp > 0:
			Logbook.note(world, "EAT", id, "food eaten", {"need": need, "bought": int(rec["food_bought"]), "why": got.get("why", "")},
				{"hunger": [0, hunger], "spoiled": [0, sp], "stock": [0, int(st.get("FOOD", 0))]})
		if need > 0:
			Logbook.note(world, "STORE", id, "the food store", {"need": need, "months_pm": int(rec["store_pm"])},
				{"bought": [0, int(rec["store_bought"])], "eaten": [0, int(rec["store_eaten"])], "stock": [0, int(st.get("FOOD", 0))],
				"from_farm": [0, int(rec.get("farm_eat", 0)) + int(rec.get("farm_store", 0))]})
	_food_facts(world, tot)
	return tot


## A famine: a quarter of the colony's food need uneaten three months running. Scarce or unaffordable: a twentieth of
## the need uneaten for that reason this month. Each fact once when it begins. (The thresholds are a press's notice,
## not a limit on anyone; set new.)
const FAMINE_PM := 250
const FAMINE_MONTHS := 3
const FOOD_FACT_PM := 50


static func _food_facts(world: WorldState, tot: Dictionary) -> void:
	var t := world.table("pool_facts")
	if int(tot["need"]) <= 0:
		return
	var short_pm := int(tot["hunger"]) * 1000 / int(tot["need"])
	t["streak"] = int(t.get("streak", 0)) + 1 if short_pm >= FAMINE_PM else 0
	t["famine_now"] = int(t["streak"]) >= FAMINE_MONTHS
	var gov := [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}]
	if bool(t["famine_now"]) and not bool(t.get("famine_was", false)):
		world.add_fact({"type": "ECON_FAMINE", "owner": "econ", "subjects": [], "responsible": gov, "impact": {"COST_OF_LIVING": -80, "GOVERNANCE": -40},
			"magnitude": 100, "visibility": "PUBLIC", "data": {"shortfall_pm": short_pm}})
	t["famine_was"] = t["famine_now"]
	for pair in [["scarce", "ECON_FOOD_SCARCE"], ["money", "ECON_FOOD_UNAFFORDABLE"]]:
		var pm := int(tot[pair[0]]) * 1000 / int(tot["need"])
		var on := pm >= FOOD_FACT_PM
		if on and not bool(t.get(pair[1], false)):
			world.add_fact({"type": pair[1], "owner": "econ", "subjects": [], "responsible": gov, "impact": {"COST_OF_LIVING": -20},
				"magnitude": 40, "visibility": "PUBLIC", "data": {"unmet_pm": pm}})
		t[pair[1]] = on


static func famine_now(world: WorldState) -> bool:
	return bool(world.peek("pool_facts").get("famine_now", false))


# ---------------------------------------------------------------- SETTLEMENT 5: rent

## SETTLEMENT, after what was bought: each pool (and owner) pays its homes' rent from what is left after food. Rent
## owed from earlier months is paid first. What it cannot pay is owed to that landlord, carried to next month (step 5
## brings eviction). rent_of(id) -> {landlord account: credits × S} is the landlord side's (Wilma's Landing.rent_due),
## passed in by the conductor.
static func pay_rent(world: WorldState, rent_of: Callable) -> int:
	var paid_all := 0
	for b in buyers(world):
		var id := String(b["id"])
		var acct := String(b["acct"])
		var rec := _rec_of(world, id)
		var r: Dictionary = world.table(PERSON_TABLE if id.begins_with("founder:") else "pool")[id]
		var owed: Dictionary = r.get("rent_owed", {})
		if id.begins_with("founder:") and not lives_apart(world, id):
			continue   # all of them still live in their pool, which pays the rent for them (Terra's review)
		var due: Dictionary = (rent_of.call(id) as Dictionary).duplicate()
		for la in owed:
			due[la] = int(due.get(la, 0)) + int(owed[la])
		var total := 0
		for la in due:
			total += int(due[la])
		if total <= 0:
			continue
		var have := mini(total, maxi(0, world.ledger.balance(acct)))
		var keys: Array = CoreUtil.sorted_keys(due)
		var parts := CoreUtil.split_lr(have, keys.map(func(k): return int(due[k])))
		var left := {}
		for i in keys.size():
			var a := int(parts[i])
			if a > 0:
				world.ledger.transfer(acct, String(keys[i]), a, "RENT", world.month)
			if int(due[keys[i]]) - a > 0:
				left[keys[i]] = int(due[keys[i]]) - a
		r["rent_owed"] = left
		rec["rent_due"] = total
		rec["rent_paid"] = have
		paid_all += have
		Logbook.note(world, "RENT", id, "rent", {"due": total, "owed_before": owed.duplicate()}, {"paid": [0, have], "owed": [0, total - have]})
	return paid_all


# ---------------------------------------------------------------- money in from others

## Income paid into an area's pools (Ella's press wages, through the doorway): shared by their EMPLOYED persons (by all
## persons where nobody works); never overdrawn; booked as `kind`. area "" = every area. Returns the amount paid.
static func pay_income(world: WorldState, from_acct: String, amount: int, area: String, kind: String) -> int:
	if amount <= 0:
		return 0
	var bill := {}
	var ids: Array = pools(world).filter(func(p): return area == "" or String(world.peek("pool")[p]["area"]) == area)
	var w: Array = ids.map(func(p): return persons(world, p, "EMPLOYED"))
	if w.all(func(x): return int(x) == 0):
		w = ids.map(func(p): return persons(world, p))
	var parts := CoreUtil.split_lr(amount, w)
	for i in ids.size():
		if int(parts[i]) > 0:
			bill[ids[i]] = int(parts[i])
	if bill.is_empty():
		return 0
	var paid := _pay(world, from_acct, bill, kind, kind.to_upper())
	var got := 0
	for pid in paid:
		got += int(paid[pid])
	Logbook.note(world, "PAY", from_acct, kind, {"area": area, "due": amount, "by_pool": paid.duplicate()}, {"paid": [0, got]})
	return got


# ---------------------------------------------------------------- work: needs, applying, leaving posts

## A worker's needs in an area (12.5, 38 as revised: a household's rent and food, not divided by its earners): Bob's
## Rules.needs_line, the ONE figure his salary rule and this side's applying both read, so a post below it gets no
## applicants on either side. Loaded at call time: rules.gd preloads this file.
static func needs_per_worker(world: WorldState, area: String) -> int:
	return int(load("res://sim/economy/rules.gd").needs_line(world, area))


## How many of the area's unemployed of skill `post_tier` or higher would apply to a post paying `pay` (9.2): all of
## them when it meets their needs, none when it does not. Bob's salary rule 2 reads it.
static func applicants(world: WorldState, area: String, post_tier: String, pay: int) -> int:
	if pay < needs_per_worker(world, area):
		return 0
	var n := 0
	for skill in TIERS.slice(TIERS.find(post_tier)):
		n += PopStore.count(world, {"hb": area, "status": "UNEMPLOYED"}, "skill:" + skill)
	return n


## n employed people of pool (area, band) leave their posts for `reason`: DEATH (they die), RETIRE (they retire), DEPART
## (they leave the colony), QUIT (they become unemployed). Posts are given up largest hire rows first across
## companies (Company.payroll), each from its own row, so jobs = people holds. Returns persons. One LEAVE row per
## company.
static func end_jobs(world: WorldState, area: String, band: String, n: int, reason: String, skill_only: String = "") -> int:
	if n <= 0:
		return 0
	var cand: Array = []   # [cid, plant_key, tier, labour_key, persons, pay, row, order]
	for cid in Company.ids(world):
		for e in Company.payroll(world, cid):
			var lp := labour_parts(String(e["labour_key"]))
			if lp[0] == area and lp[1] == band and int(e["n"]) >= S and (skill_only == "" or lp[2] == skill_only):
				cand.append([cid, String(e["plant_key"]), String(e["post_tier"]), String(e["labour_key"]), int(e["n"]) / S, int(e["pay"]),
					String(e["row"]), cand.size()])
	cand.sort_custom(func(a, b): return int(a[4]) > int(b[4]) or (int(a[4]) == int(b[4]) and ((String(a[0]) + String(a[1]) + String(a[3])) < (String(b[0]) + String(b[1]) + String(b[3]))
		or ((String(a[0]) + String(a[1]) + String(a[3])) == (String(b[0]) + String(b[1]) + String(b[3])) and int(a[7]) < int(b[7])))))
	var done := 0
	var by_co := {}
	for c in cand:
		if done >= n:
			break
		var k := mini(n - done, int(c[4]))
		var occ := String(Company.occupation(world, c[0], c[2]))
		var skill := String(labour_parts(String(c[3]))[2])
		var f := {"hb": area, "inc": band, "status": "EMPLOYED", "occ": occ}
		var have := PopStore.count(world, f, "skill:" + skill)
		k = mini(k, have)
		if k <= 0 or not Company.staff_change(world, c[0], c[1], c[2], c[3], -k * S, -1, -1, String(c[6])):
			continue
		match reason:
			"DEATH":
				_people_out(world, f, k, skill, "DEATH")
			"DEPART":
				_people_out(world, f, k, skill, "DEPART")
			"RETIRE":
				PopStore.move_group(world, f, k, {"status": "RETIRED"}, "RETIRE", "skill:" + skill)
			_:
				PopStore.move_group(world, f, k, {"status": "UNEMPLOYED"}, reason, "skill:" + skill)
		by_co[c[0]] = int(by_co.get(c[0], 0)) + k
		done += k
	for cid in CoreUtil.sorted_keys(by_co):
		Logbook.note(world, "LEAVE", cid, "left their posts", {"reason": reason, "pool": pool_id(area, band)}, {"staff": [int(by_co[cid]), 0]})
	return done


static func _people_out(world: WorldState, f: Dictionary, k: int, skill: String, how: String) -> void:
	var keys := PopStore.select(world, f).filter(func(x): return int(world.peek("pop")[x]["skill"].get(skill, 0)) > 0)
	var parts := PopStore.split_over(k, keys, keys.map(func(x): return float(world.peek("pop")[x]["skill"].get(skill, 0))))
	for key in CoreUtil.sorted_keys(parts):
		if how == "DEATH":
			PopStore.death(world, key, int(parts[key]), {"skill": skill})
		else:
			PopStore.depart(world, key, int(parts[key]), "EMIGRATION", {"skill": skill})


## A group's jobs follow it to another income band (Demography.band_moves): every hire row of a staff entry
## area|from|skill moves whole to area|to|skill (Company.staff_move): its pay, its month at the workplace and its
## training go with it; it becomes one with a row there only if they match in every field.
static func move_jobs_band(world: WorldState, area: String, from_band: String, to_band: String, skill: String) -> void:
	var lk_from := labour_key(area, from_band, skill)
	var lk_to := labour_key(area, to_band, skill)
	for cid in Company.ids(world):
		for e in Company.payroll(world, cid):
			if String(e["labour_key"]) != lk_from:
				continue
			var n := int(e["n"])
			var ok := Company.staff_move(world, cid, String(e["plant_key"]), String(e["post_tier"]), lk_from, lk_to, String(e["row"]), n)
			assert(ok, "move_jobs_band: the row refused the move")


## One group of staff moves to another post at its pay (quitting for better pay, 12.5, 39): k persons of hire row e
## ({cid, plant_key, post_tier, labour_key, pay, row}: they leave that row; without "row", the entry's rows in order)
## to vacancy v ({cid, plant_key, tier, pay}). Occupation follows the new
## company; the years at the workplace start again there. `bar_pm` is the bar the new pay had to reach (for the row).
## Returns persons moved.
static func move_job(world: WorldState, e: Dictionary, v: Dictionary, k: int, reason: String, bar_pm: int = 0) -> int:
	var lp := labour_parts(String(e["labour_key"]))
	var occ_old := String(Company.occupation(world, e["cid"], e["post_tier"]))
	var occ_new := String(Company.occupation(world, v["cid"], v["tier"]))
	var f := {"hb": lp[0], "inc": lp[1], "status": "EMPLOYED", "occ": occ_old}
	k = mini(k, PopStore.count(world, f, "skill:" + lp[2]))
	if k <= 0:
		return 0
	if not Company.staff_change(world, v["cid"], v["plant_key"], v["tier"], String(e["labour_key"]), k * S, int(v["pay"])):
		return 0
	var left: bool = Company.staff_change(world, e["cid"], e["plant_key"], e["post_tier"], String(e["labour_key"]), -k * S, -1, -1, String(e.get("row", "")))
	assert(left, "move_job: the old post refused the leavers")
	if occ_new != occ_old:
		PopStore.move_group(world, f, k, {"occ": occ_new}, reason, "skill:" + lp[2])
	Logbook.note(world, "JOB", String(v["cid"]), reason, {"from": e["cid"], "old_pay": int(e.get("pay", 0)), "new_pay": int(v["pay"]),
		"bar_pm": bar_pm, "years": int(e.get("years", 0))},
		{"staff": [0, k]}, String(e["cid"]))
	return k


# ---------------------------------------------------------------- SOCIAL: the labour month

## The bar for quitting (9.2, the user's ruling, verbatim: "10% if it's a good job less if stressfull, and plus 1% per
## year in the same workplace up to 15%"): a worker moves only to a post paying at least their own pay x (1 + bar).
## Wilma's readings: "up to 15%" caps the whole bar (10% rising to 15% after five full years); per mille here.
const QUIT_BAR_GOOD_PM := 100       # 10% in a good job
const QUIT_BAR_STRESSED_PM := 50    # Wilma's reading: toward 5% at the highest stress (step 9)
const QUIT_BAR_PER_YEAR_PM := 10    # + 1% per full year at the same workplace
const QUIT_BAR_MAX_PM := 150        # up to 15%


## The bar before the years: 10% in a good job, less in a stressful one. Stress comes at step 9; it will lower the bar
## here, toward QUIT_BAR_STRESSED_PM at the highest stress. Until then every job is a good job: 10%.
static func quit_bar_base_pm(_world: WorldState, _cid: String, _post_tier: String) -> int:
	return QUIT_BAR_GOOD_PM


## Full years a hire row has been at its workplace (its own "since" month).
static func years_at(world: WorldState, e: Dictionary) -> int:
	return maxi(0, world.month - int(e["since"])) / 12


## The whole bar for one staff entry, per mille: the base + 1% per full year, at most 15%.
static func quit_bar_pm(world: WorldState, cid: String, e: Dictionary) -> int:
	return mini(QUIT_BAR_MAX_PM, quit_bar_base_pm(world, cid, String(e["post_tier"])) + QUIT_BAR_PER_YEAR_PM * years_at(world, e))


## Does `new_pay` reach the bar over `old_pay`? new >= old x (1 + bar), in whole milli-credits without rounding.
static func clears_bar(old_pay: int, new_pay: int, bar_pm: int) -> bool:
	return new_pay * 1000 >= old_pay * (1000 + bar_pm)


## SOCIAL: the negotiation (in NEGOTIATE_MONTH), then quitting for better pay, over the bar (quit_bar_pm). Staff a
## better-paid vacancy did not move because its pay did not reach their bar get one STAY row per company a month, with
## each entry's bar, old pay and the best pay it was offered. Returns persons who changed post.
static func labour_month(world: WorldState) -> int:
	if world.month_of_year() == NEGOTIATE_MONTH:
		_negotiate(world)
	var moved := 0
	var stay := {}   # cid -> {entry key: [bar_pm, old pay, best pay offered, persons, years]}
	for a in AreaStore.areas(world):
		var area := String(a["id"])
		var vac: Array = Company.vacancies(world, area)
		if vac.is_empty():
			continue
		vac.sort_custom(func(x, y): return int(x["pay"]) > int(y["pay"]) or (int(x["pay"]) == int(y["pay"]) and String(x["cid"]) < String(y["cid"])))
		for v in vac:
			var open := int(v["open"])
			for cid in Company.ids(world):
				if open <= 0:
					break
				if cid == String(v["cid"]):
					continue
				for e in Company.payroll(world, cid):
					if open <= 0:
						break
					var lp := labour_parts(String(e["labour_key"]))
					if lp[0] != area or int(e["pay"]) >= int(v["pay"]) or TIERS.find(lp[2]) < TIERS.find(String(v["tier"])):
						continue
					var ek := "%s|%s|%s|%s" % [e["plant_key"], e["post_tier"], e["labour_key"], e["row"]]   # one per hire row
					var bar := quit_bar_pm(world, cid, e)
					if not clears_bar(int(e["pay"]), int(v["pay"]), bar):
						if not stay.has(cid):
							stay[cid] = {}
						var best: int = maxi(int(v["pay"]), int(stay[cid][ek][2])) if stay[cid].has(ek) else int(v["pay"])
						stay[cid][ek] = [bar, int(e["pay"]), best, int(e["n"]) / S, years_at(world, e)]
						continue
					var ent := {"cid": cid, "plant_key": e["plant_key"], "post_tier": e["post_tier"], "labour_key": e["labour_key"],
						"pay": e["pay"], "row": e["row"], "years": years_at(world, e)}
					var k := move_job(world, ent, v, mini(open, int(e["n"]) / S), "QUIT_FOR_PAY", bar)
					open -= k
					moved += k
	for cid in CoreUtil.sorted_keys(stay):
		var rows: Dictionary = stay[cid]
		var persons := 0
		var entries := {}
		for ek in CoreUtil.sorted_keys(rows):
			var r: Array = rows[ek]
			persons += int(r[3])
			entries[ek] = {"bar_pm": int(r[0]), "old_pay": int(r[1]), "new_pay": int(r[2]), "persons": int(r[3]), "years": int(r[4])}
		Logbook.note(world, "STAY", String(cid), "better pay below the bar", {"entries": entries}, {"stayed": [0, persons]})
	return moved


static func _negotiate(world: WorldState) -> void:
	for cid in Company.ids(world):
		for e in Company.payroll(world, cid):
			var avg := Company.avg_pay(world, cid, String(e["post_tier"]))
			if int(e["pay"]) >= avg:
				continue
			var ask := int(e["pay"]) + (avg - int(e["pay"])) / 2
			var cost_year := (ask - int(e["pay"])) * int(e["n"]) / S * 12
			var ok := world.ledger.balance(CoreUtil.acct(cid)) >= cost_year and Company.negotiate(world, cid, String(e["plant_key"]),
				String(e["post_tier"]), String(e["labour_key"]), ask, {"asked": ask, "average": avg}, String(e["row"]))
			# a row that an earlier rise this month made one with another is gone from the record: it was raised there
			var still := false
			for x in Company.payroll(world, cid):
				var same := String(x["plant_key"]) == String(e["plant_key"]) and String(x["post_tier"]) == String(e["post_tier"])
				if same and String(x["labour_key"]) == String(e["labour_key"]) and String(x["row"]) == String(e["row"]):
					still = true
			if not ok and still:
				Logbook.note(world, "NEGOTIATE", cid, "refused", {"entry": e["labour_key"], "pay": int(e["pay"]), "asked": ask, "average": avg, "year_cost": cost_year}, {})


## SOCIAL, January: every company's yearly raise, its own choice and at least the government's minimum (9.2; lever
## ECON_YEARLY_RAISE_MIN_PCT, Ella's).
static func yearly_raise_month(world: WorldState) -> void:
	if not preload("res://sim/population/demography.gd").new_year(world):
		return   # the first raise is a year after landing, not on landing day
	var min_pm := int(CoreUtil.lever(world, "ECON_YEARLY_RAISE_MIN_PCT", 2)) * 10
	for cid in Company.ids(world):
		if not Company.payroll(world, cid).is_empty():
			Company.yearly_raise(world, cid, Company.raise_choice(world, cid), min_pm)


# ---------------------------------------------------------------- founders (12.5, 35; 12.9, 60a–60c)

static func person(world: WorldState, id: String) -> Dictionary:
	return (world.peek(PERSON_TABLE).get(id, {}) as Dictionary).duplicate(true)


static func persons_of_pool(world: WorldState, pid: String) -> Array:
	var out: Array = []
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		if String(world.peek(PERSON_TABLE)[id]["pool"]) == pid:
			out.append(id)
	return out


## One household's share of a pool's savings (what a founder takes with them, 60c): balance × 2.5 ÷ persons.
static func household_share(world: WorldState, pid: String) -> int:
	var n := persons(world, pid) - int(counts(world, pid)["owners"]) / S
	if n <= 0:
		return 0
	return int(float(maxi(0, savings(world, pid))) * HOUSEHOLD_SIZE / float(n))


## Who would found a company needing `money_needed` (12.9, 60a): the plan names nobody, so a seeded draw ("econ.founder")
## among the HOUSEHOLDS of the area that can pay and that have an adult free to found, so no band comes before another
## (Wilma). A household that has had a grant (12.9, 61: one grant per household; the pool's "granted" count) can pay
## only from one household's share of its pool's savings; one that has not, from that share + the grant its pool would
## get (`grants` {pool id: credits x S}, Ella's quote). The draw remembers which kind of household it drew, for
## make_founder. Returns the pool id or "".
static func pick_founder(world: WorldState, area: String, money_needed: int, grants: Dictionary) -> String:
	var rows: Array = []   # [pool id, had a grant, households]
	for pid in pools(world):
		var p: Dictionary = world.peek("pool")[pid]
		if String(p["area"]) != area or _free_adult(world, pid).is_empty():
			continue
		var hh := int(counts(world, pid)["households"]) / S
		var granted := mini(hh, int(p.get("granted", 0)))
		var share := household_share(world, pid)
		if hh - granted > 0 and share + int(grants.get(pid, 0)) >= money_needed:
			rows.append([pid, false, hh - granted])
		if granted > 0 and share >= money_needed:
			rows.append([pid, true, granted])
	var total := 0
	for r in rows:
		total += int(r[2])
	var pick := ""
	var had := false
	if total > 0:
		var x := world.rng.stream("econ.founder").randi_range(0, total - 1)
		for r in rows:
			x -= int(r[2])
			if x < 0:
				pick = String(r[0])
				had = bool(r[1])
				break
		world.table("pool")[pick]["pick"] = {"m": world.month, "had_grant": had}
	Logbook.note(world, "FOUNDER", area, "picked" if pick != "" else "nobody can pay", {"money_needed": money_needed,
		"eligible": rows.map(func(r): return "%s%s:%d" % [r[0], " (had a grant)" if r[1] else "", r[2]])}, {"pool": ["", pick], "had_grant": [false, had]})
	return pick


## The adult who would found: the unemployed first, then those outside the labour force, then the employed; within
## each, skilled and specialists first. {status, skill} or {}.
static func _free_adult(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.peek("pool")[pid]
	for st in ["UNEMPLOYED", "NOT_IN_LF", "EMPLOYED"]:
		for sk in ["Sp", "S", "G"]:
			var f := {"hb": String(p["area"]), "inc": String(p["band"]), "status": st}
			if st == "NOT_IN_LF":
				f["occ"] = "NONE"
			# an owner's household is never free (a family working its own company is EMPLOYED; Terra's review); an
			# employed adult must hold a post of that skill to give up
			var n := PopStore.count(world, f, "skill:" + sk)
			if not f.has("occ"):   # outside the labour force the filter is occ NONE already (Terra's re-check)
				n -= PopStore.count(world, f.merged({"occ": "BUSINESS_OWNER"}), "skill:" + sk)
			if st == "EMPLOYED":
				n -= int(p.get("in_post", {}).get(sk, 0))   # already a founder's, still in their post until the plan signs
				if _posts_of(world, String(p["area"]), String(p["band"]), sk) <= 0:
					n = 0
			if n > 0:
				return {"status": st, "skill": sk}
	return {}


## The founder leaves the pool the day the plan is made (60a): one adult becomes a person of their own, an owner
## (NOT_IN_LF, BUSINESS_OWNER in PopStore, so they age, vote and are counted), with their own account holding one
## household's share of the pool's savings. An employed founder keeps their post until the plan signs (Wilma,
## 2026-11-18: "a person whose plan is given up the same month, or never signed, has not lost their job"; nothing in
## 60a or 60c gives the job up at making): they stay in PopStore as they are, in their pool, listed on the record as
## in_post, and eat and are paid with their pool until then (Maja's reading of 60c, with Wilma's yes). take_up_posts
## moves them out when the plan signs; a plan given up leaves them where they are. `ref`: the plan (or company) they
## found. Returns "founder:N" ("" if the pool has nobody free). Fact COMP_COMPANY_PLANNED.
## family = true (a FAMILY-size company, 15e: "the family that owns a family farm works it themselves"): the founder's
## whole household leaves with them (the founder's household is the family, Wilma's detail): one more adult for each
## adult a household of the pool has beyond one, and its children, both as whole persons with a carried remainder. They
## all become BUSINESS_OWNER in PopStore (so no pool, hire or jobs = people check counts them); adults stay outside
## the labour force until family_work puts them on the farm's posts. They eat from the founder's account.
static func make_founder(world: WorldState, pid: String, ref: String, family: bool = false) -> String:
	var who := _free_adult(world, pid)
	if who.is_empty():
		return ""
	var p: Dictionary = world.peek("pool")[pid]
	var area := String(p["area"])
	var band := String(p["band"])
	var share := household_share(world, pid)
	var pk: Dictionary = p.get("pick", {})
	var had := int(pk.get("m", -1)) == world.month and bool(pk.get("had_grant", false))
	world.table("pool")[pid].erase("pick")
	if had:   # a household that had a grant leaves the pool: one fewer granted household there
		world.table("pool")[pid]["granted"] = maxi(0, int(p.get("granted", 0)) - 1)
	var adults: Array = []
	if String(who["status"]) == "EMPLOYED":
		_promise_post(world, pid, String(who["skill"]))   # in their post until the plan signs
		adults.append({"skill": String(who["skill"]), "was": "EMPLOYED", "in_post": true})
	else:
		var f := {"hb": area, "inc": band, "status": String(who["status"])}
		if String(who["status"]) == "NOT_IN_LF":
			f["occ"] = "NONE"
		if PopStore.move_group(world, f, 1, {"status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}, "FOUNDER", "skill:" + String(who["skill"])) <= 0:
			return ""   # nobody was taken: no record without a person behind it
		adults.append({"skill": String(who["skill"]), "was": "NOT_IN_LF" if String(who["status"]) == "NOT_IN_LF" else "UNEMPLOYED"})
	var children := 0
	if family:
		var fam := _family_take(world, pid)
		adults.append_array(fam["adults"])
		children = int(fam["children"])
	var id := world.new_id("founder")
	world.ledger.open_account(id)
	world.table(PERSON_TABLE)[id] = {"id": id, "area": area, "band": band, "pool": pid, "account": id, "skill": String(who["skill"]),
		"owns": [ref] if ref != "" else [], "founded": world.month, "had_grant": had,
		"was": "NOT_IN_LF" if String(who["status"]) == "NOT_IN_LF" else "UNEMPLOYED",
		"family": {"adults": adults, "children": children, "working": {}}}
	var amt := mini(share, maxi(0, savings(world, pid)))
	if amt > 0:
		world.ledger.transfer(account(pid), id, amt, "FOUNDER_SAVINGS", world.month)
	# and its share of the pool's food store (15f), per mouth: the store is months of each person's food, so the
	# founder's household takes its persons' part of it (its money is a household's share; Terra's question)
	# only the mouths that left: those still in their posts eat with the pool until the plan signs
	var gone := adults.filter(func(ad): return not bool(ad.get("in_post", false))).size() + children
	move_store(world, pid, id, gone, gone + persons(world, pid) - int(counts(world, pid)["owners"]) / S)
	Logbook.note(world, "FOUNDER", id, "a founder counted one by one", {"pool": pid, "skill": who["skill"], "was": who["status"],
		"family": family}, {"money": [0, amt], "household": [0, adults.size() + children]}, pid, ref)
	world.add_fact({"type": "COMP_COMPANY_PLANNED", "owner": "econ", "subjects": [{"kind": "FOUNDER", "id": id}], "responsible": [],
		"impact": {}, "magnitude": 10, "visibility": "PUBLIC", "data": {"founder": id, "plan": ref, "area": area}})
	return id


## A founder who owns nothing any more and owes nothing carried goes back into the pool of their area and band (60c),
## with their money. Returns true if they went back. "When they no longer own a company or a plan and their debts are
## settled or carried" (60c): a debt still OPEN (a grant owed back after a given-up plan) is CARRIED (Wilma): the
## household goes back like any other, to be hired and draw the benefit as pool people do; the debt stays OPEN against
## the founder's id, its liability rows marked "carried", and a stub record (table "founder_carried": id, pool, owed)
## keeps the debt's name. Nothing is collected from a pool for it: what the founder cannot pay goes to court like any
## debt (60b), which is step 5's court.
static func release_founder(world: WorldState, id: String) -> bool:
	var r: Dictionary = world.peek(PERSON_TABLE).get(id, {})
	if r.is_empty() or not (r["owns"] as Array).is_empty():
		return false
	_carry_debts(world, id, String(r["pool"]))
	var pid := ensure_pool(world, String(r["area"]), String(r["band"]))
	family_work(world, id, {})   # off the farm's posts first
	var f := {"hb": String(r["area"]), "inc": String(r["band"]), "status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}
	# back to where they came from: outside the labour force stays outside it; anyone else looks for work (Bob's review).
	# The whole household goes back together (60c), the founder first.
	var fam: Dictionary = r.get("family", {"adults": [{"skill": r["skill"], "was": r.get("was", "UNEMPLOYED")}], "children": 0})
	for ad in fam["adults"]:
		if bool(ad.get("in_post", false)):   # never left their post: they stay where they are, in their job
			_promise_post(world, String(r["pool"]), String(ad["skill"]), -1)
			continue
		PopStore.move_group(world, f, 1, {"status": String(ad["was"]), "occ": "NONE"}, "FOUNDER_BACK", "skill:" + String(ad["skill"]))
	if int(fam["children"]) > 0:
		PopStore.move_group(world, {"hb": String(r["area"]), "inc": String(r["band"]), "status": "CHILD", "occ": "BUSINESS_OWNER"},
			int(fam["children"]), {"occ": "NONE"}, "FOUNDER_BACK")
	var amt := maxi(0, world.ledger.balance(id))
	if amt > 0:
		world.ledger.transfer(id, account(pid), amt, "FOUNDER_BACK", world.month)
	if bool(r.get("had_grant", false)):   # it goes back as one of the pool's households that have had a grant
		world.table("pool")[pid]["granted"] = int(world.peek("pool")[pid].get("granted", 0)) + 1
	for k in (r.get("stock", {}) as Dictionary):
		_stock(world, pid)[k] = int(_stock(world, pid).get(k, 0)) + int(r["stock"][k])
	world.table(PERSON_TABLE).erase(id)
	Logbook.note(world, "FOUNDER", id, "back into the pool", {"pool": pid}, {"money": [amt, 0]}, pid)
	return true


## SOCIAL, every month: every founder who owns nothing goes back into the pool (60c; Ella: the grant's reclaim does
## not retry, this does). Returns how many went back.
static func release_idle_founders(world: WorldState) -> int:
	take_up_posts(world)
	var n := 0
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		if (world.peek(PERSON_TABLE)[id]["owns"] as Array).is_empty() and release_founder(world, String(id)):
			n += 1
	return n


## A founder going back with debts still OPEN carries them (60c): the law marks its own rows carried (Anni's
## Justice.carry_debts: they stay OPEN, for step 5's court, and the collector skips them), and a stub keeps the
## debtor's name: founder_carried[id] = {id, pool, owed}. Returns what is owed.
static func _carry_debts(world: WorldState, id: String, pool: String) -> int:
	var owed := int(load("res://sim/law/justice_ops.gd").carry_debts(world, id, pool))
	if owed > 0:
		world.table("founder_carried")[id] = {"id": id, "pool": pool, "owed": owed}
		Logbook.note(world, "FOUNDER", id, "goes back carrying a debt", {"pool": pool}, {"owed": [0, owed]}, pool)
	return owed


## Moves num/den of one buyer's stock to another (a pool's or a founder's): the store follows the people who move, as
## their savings do (a band move, a founder leaving the pool). Returns the food moved.
static func move_store(world: WorldState, from_id: String, to_id: String, num: int, den: int) -> int:
	if num <= 0 or den <= 0:
		return 0
	var src := _stock(world, from_id)
	var dst := _stock(world, to_id)
	var food := 0
	for k in CoreUtil.sorted_keys(src):
		var q := int(src[k]) * mini(num, den) / den
		if q > 0:
			src[k] = int(src[k]) - q
			dst[k] = int(dst.get(k, 0)) + q
			if String(k) == "FOOD":
				food = q
	return food


## Persons holding posts of `skill` in an area's band, over every company.
static func _posts_of(world: WorldState, area: String, band: String, skill: String) -> int:
	var lk := labour_key(area, band, skill)
	var n := 0
	for cid in Company.ids(world):
		for e in Company.payroll(world, cid):
			if String(e["labour_key"]) == lk:
				n += int(e["n"]) / S
	return n


## AreaStore's moves (through Demography.on_area_moves): a split leaves owners' households where they are; a merge
## moves everyone, so the founders of a merged-away area, and the stubs of carried debts, now live in the area it
## merged into, in the same band (Terra's review).
## The pools' savings and food store follow their people (Terra's review of 15f): each source pool gives each
## destination pool its share, persons moved there over persons moved out plus those left (a merge leaves nobody, so
## it moves everything), of what the pool held before the moves. One AREA row per move.
static func on_area_moves(world: WorldState, moves: Array) -> void:
	_area_money_and_store(world, moves)
	var into := {}
	for m in moves:
		if String(AreaStore.get_area(world, String(m["from"])).get("status", "")) == "MERGED":
			into[String(m["from"])] = String(m["to"])
	if into.is_empty():
		return
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		var r: Dictionary = world.table(PERSON_TABLE)[id]
		if into.has(String(r["area"])):
			var old_pool := String(r["pool"])
			r["area"] = String(into[String(r["area"])])
			r["pool"] = ensure_pool(world, String(r["area"]), String(r["band"]))
			for ad in r.get("family", {}).get("adults", []):   # its marks of people still in post go with it (Terra's review)
				if bool(ad.get("in_post", false)):
					_promise_post(world, old_pool, String(ad["skill"]), -1)
					_promise_post(world, String(r["pool"]), String(ad["skill"]))
			Logbook.note(world, "FOUNDER", id, "moved with a merge", {}, {"area": ["", r["area"]]})
	for id in CoreUtil.sorted_keys(world.peek("founder_carried")):
		var c: Dictionary = world.table("founder_carried")[id]
		var a := String(c["pool"]).get_slice("|", 0)
		if into.has(a):
			c["pool"] = pool_id(String(into[a]), String(c["pool"]).get_slice("|", 1))


static func _area_money_and_store(world: WorldState, moves: Array) -> void:
	var out := {}   # source pool -> {destination area: persons}
	for m in moves:
		var src := pool_id(String(m["from"]), String(m["band"]))
		if not world.peek("pool").has(src) or int(m["persons"]) <= 0:
			continue
		if not out.has(src):
			out[src] = {}
		out[src][String(m["to"])] = int(out[src].get(String(m["to"]), 0)) + int(m["persons"])
	for src in CoreUtil.sorted_keys(out):
		var moved := 0
		for to_a in out[src]:
			moved += int(out[src][to_a])
		var den := moved + maxi(0, persons(world, src) - int(counts(world, src)["owners"]) / S)
		var bal0 := maxi(0, savings(world, src))
		var stock0: Dictionary = _stock(world, src).duplicate()
		var band := String(world.peek("pool")[src]["band"])
		for to_a in CoreUtil.sorted_keys(out[src]):
			var n := int(out[src][to_a])
			var dst := ensure_pool(world, String(to_a), band)
			var amt := mini(maxi(0, savings(world, src)), bal0 * n / den)
			if amt > 0:
				world.ledger.transfer(account(src), account(dst), amt, "AREA_MOVE", world.month)
			var food := 0
			for k in CoreUtil.sorted_keys(stock0):
				var q := mini(int(_stock(world, src).get(k, 0)), int(stock0[k]) * n / den)
				if q > 0:
					_stock(world, src)[k] = int(_stock(world, src)[k]) - q
					_stock(world, dst)[k] = int(_stock(world, dst).get(k, 0)) + q
					if String(k) == "FOOD":
						food = q
			Logbook.note(world, "AREA", src, "savings and food store follow the people who moved", {"to": to_a, "persons": n, "of": den},
				{"savings": [0, amt], "store": [0, food]}, dst)


## The rest of a founder's household for a family company: for each adult a household of the pool has beyond one, one
## more adult (unemployed, then outside the labour force, then employed, who gives up their post), and the pool's
## children per household; whole persons, the fractions carried per pool. Returns {adults: [{skill, was}], children}.
static func _family_take(world: WorldState, pid: String) -> Dictionary:
	var p: Dictionary = world.peek("pool")[pid]
	var area := String(p["area"])
	var band := String(p["band"])
	var c := counts(world, pid)
	var hh := float(c["persons"] - c["owners"]) / float(S) / HOUSEHOLD_SIZE
	var out := {"adults": [], "children": 0}
	if hh <= 0.0:
		return out
	var D = load("res://sim/population/demography.gd")
	var adults_hh := float(c["persons"] - c["owners"] - c["children"]) / float(S) / hh
	var more := int(D._whole(world, "fam_ad|" + pid, maxf(0.0, adults_hh - 1.0)))
	for i in more:
		var who := _free_adult(world, pid)
		if who.is_empty():
			break
		if String(who["status"]) == "EMPLOYED":   # in their post until the plan signs, as the founder (take_up_posts)
			_promise_post(world, pid, String(who["skill"]))
			out["adults"].append({"skill": String(who["skill"]), "was": "EMPLOYED", "in_post": true})
			continue
		var f := {"hb": area, "inc": band, "status": String(who["status"])}
		if String(who["status"]) == "NOT_IN_LF":
			f["occ"] = "NONE"
		if PopStore.move_group(world, f, 1, {"status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}, "FOUNDER_FAMILY", "skill:" + String(who["skill"])) > 0:
			out["adults"].append({"skill": String(who["skill"]), "was": "NOT_IN_LF" if String(who["status"]) == "NOT_IN_LF" else "UNEMPLOYED"})
	var kids := int(D._whole(world, "fam_ch|" + pid, float(c["children"]) / float(S) / hh))
	if kids > 0:
		out["children"] = PopStore.move_group(world, {"hb": area, "inc": band, "status": "CHILD", "occ": "NONE"}, kids,
			{"occ": "BUSINESS_OWNER"}, "FOUNDER_FAMILY")
	return out


## How many persons a founder's household holds (the founder, their family's adults and children).
static func family_size(world: WorldState, id: String) -> int:
	var fam: Dictionary = world.peek(PERSON_TABLE).get(id, {}).get("family", {})
	return maxi(1, (fam.get("adults", []) as Array).size() + int(fam.get("children", 0)))


## The founder's household's adults who can work, by skill (the founder among them): {"G", "S", "Sp"}. Bob fills a
## family company's posts from them first, each post tier from adults of that tier or higher.
static func family_adults(world: WorldState, id: String) -> Dictionary:
	var out := {"G": 0, "S": 0, "Sp": 0}
	for ad in world.peek(PERSON_TABLE).get(id, {}).get("family", {}).get("adults", []):
		if not bool(ad.get("in_post", false)):   # still in their own job until the plan signs
			out[String(ad["skill"])] = int(out[String(ad["skill"])]) + 1
	return out


## How many of a founder's household are still in their posts (the plan not signed yet): they eat and are paid with
## their pool until take_up_posts moves them.
static func in_post(world: WorldState, id: String) -> int:
	var n := 0
	for ad in world.peek(PERSON_TABLE).get(id, {}).get("family", {}).get("adults", []):
		if bool(ad.get("in_post", false)):
			n += 1
	return n


## Marks (d = 1) or frees (d = -1) one employed adult of a pool as a founder's, still in their post, so no second
## founder draws the same person (pool["in_post"] {skill: persons}).
static func _promise_post(world: WorldState, pid: String, skill: String, d: int = 1) -> void:
	var p: Dictionary = world.table("pool").get(pid, {})
	if p.is_empty():
		return
	if not p.has("in_post"):
		p["in_post"] = {}
	p["in_post"][skill] = maxi(0, int(p["in_post"].get(skill, 0)) + d)
	if int(p["in_post"][skill]) == 0:
		p["in_post"].erase(skill)


## SOCIAL, every month (before founders go back): a founder whose plan has signed (any plan it owns past MADE, or a
## company) takes up the venture: each of its household still in a post gives it up now (QUIT, from their own pool and
## skill) and becomes an owner, with their part of the pool's food store, per mouth. One whose post is gone meanwhile
## (a death, a layoff) is taken as unemployed, or from outside the labour force, with no job ended. Returns persons.
static func take_up_posts(world: WorldState) -> int:
	var moved := 0
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		var r: Dictionary = world.table(PERSON_TABLE)[id]
		if in_post(world, String(id)) <= 0 or not _signed(world, r):
			continue
		var area := String(r["area"])
		var band := String(r["band"])
		var pid := String(r["pool"])
		var n := 0
		var gone: Array = []
		for ad in r["family"]["adults"]:
			if not bool(ad.get("in_post", false)):
				continue
			var sk := String(ad["skill"])
			_promise_post(world, pid, sk, -1)
			ad.erase("in_post")
			var emp := PopStore.count(world, {"hb": area, "inc": band, "status": "EMPLOYED"}, "skill:" + sk) \
				- PopStore.count(world, {"hb": area, "inc": band, "status": "EMPLOYED", "occ": "BUSINESS_OWNER"}, "skill:" + sk)
			var st := ""
			if emp > 0 and end_jobs(world, area, band, 1, "QUIT", sk) > 0:
				st = "UNEMPLOYED"   # end_jobs moved them EMPLOYED -> UNEMPLOYED
			elif PopStore.count(world, {"hb": area, "inc": band, "status": "UNEMPLOYED"}, "skill:" + sk) > 0:
				st = "UNEMPLOYED"
			elif PopStore.count(world, {"hb": area, "inc": band, "status": "NOT_IN_LF", "occ": "NONE"}, "skill:" + sk) > 0:
				st = "NOT_IN_LF"
			if st == "":
				gone.append(ad)   # nobody of that skill left to be them (died meanwhile): off the record
				continue
			var f := {"hb": area, "inc": band, "status": st}
			if st == "NOT_IN_LF":
				f["occ"] = "NONE"
			PopStore.move_group(world, f, 1, {"status": "NOT_IN_LF", "occ": "BUSINESS_OWNER"}, "FOUNDER", "skill:" + sk)
			ad["was"] = st
			n += 1
		var self_gone: bool = not gone.is_empty() and (r["family"]["adults"] as Array).find(gone[0]) == 0
		for ad in gone:
			r["family"]["adults"].erase(ad)
		if n > 0 and world.peek("pool").has(pid):
			move_store(world, pid, String(id), n, n + persons(world, pid) - int(counts(world, pid)["owners"]) / S)
		moved += n
		Logbook.note(world, "FOUNDER", String(id), "the plan signed: gave up their posts", {"pool": pid, "gone": gone.size(),
			"founder_themself_gone": self_gone}, {"took_up": [0, n]}, pid)
	return moved


## Has any plan this founder owns signed (SIGNED or OPEN; a plan GIVEN_UP never counts), or does it own a company?
static func _signed(world: WorldState, r: Dictionary) -> bool:
	for ref in r.get("owns", []):
		var pl: Dictionary = world.peek("plan").get(String(ref), {})
		if pl.is_empty() or String(pl.get("status", "")) in ["SIGNED", "OPEN"]:
			return true
	return false


## Does any of this founder's household live outside its pool (has anyone left: not all of them still in their posts)?
## Until then the founder is no household of its own: it lives, eats and pays rent with its pool (Terra's review).
static func lives_apart(world: WorldState, id: String) -> bool:
	return family_size(world, id) - in_post(world, id) > 0


## The family adults now working its own company's posts, by skill.
static func family_working(world: WorldState, id: String) -> Dictionary:
	var out := {"G": 0, "S": 0, "Sp": 0}
	var w: Dictionary = world.peek(PERSON_TABLE).get(id, {}).get("family", {}).get("working", {})
	for sk in w:
		out[sk] = int(w[sk])
	return out


## The family works its own company's posts (15e): `by_skill` {skill: persons} of its adults are EMPLOYED (still of
## occupation BUSINESS_OWNER: on no payroll, employed in the counts); the rest outside the labour force. Never more
## than the family has. Bob's opening (and his month, when it changes) calls it; {} takes them all off.
static func family_work(world: WorldState, id: String, by_skill: Dictionary) -> void:
	var r: Dictionary = world.table(PERSON_TABLE).get(id, {})
	if r.is_empty() or not r.has("family"):
		return
	var have := family_adults(world, id)
	var now := family_working(world, id)
	var base := {"hb": String(r["area"]), "inc": String(r["band"]), "occ": "BUSINESS_OWNER"}
	var w := {}
	for sk in TIERS:
		var want := clampi(int(by_skill.get(sk, 0)), 0, int(have[sk]))
		var d := want - int(now[sk])
		if d > 0:
			PopStore.move_group(world, base.merged({"status": "NOT_IN_LF"}), d, {"status": "EMPLOYED"}, "FAMILY_WORK", "skill:" + sk)
		elif d < 0:
			PopStore.move_group(world, base.merged({"status": "EMPLOYED"}), -d, {"status": "NOT_IN_LF"}, "FAMILY_WORK", "skill:" + sk)
		if want > 0:
			w[sk] = want
	r["family"]["working"] = w
	Logbook.note(world, "FAMILY", id, "works its own company", {"adults": have}, {"working": [now, family_working(world, id)]})


## The owners of a family company take its winnings, no salary (the user, 15e: "The owners of a family farm should take
## winnings no sallery, wich comes after and saves the issue"). Bob decides when and how much; this moves it into the
## founder's account, never more than `from_acct` holds, booked as the household's income "winnings". Returns paid.
static func pay_winnings(world: WorldState, id: String, from_acct: String, amount: int) -> int:
	var r: Dictionary = world.table(PERSON_TABLE).get(id, {})
	var amt := mini(amount, maxi(0, world.ledger.balance(from_acct)))
	if r.is_empty() or amt <= 0:
		return 0
	world.ledger.transfer(from_acct, String(r["account"]), amt, "WINNINGS", world.month)
	if int(r.get("income", {}).get("month", -1)) != world.month:
		r["income"] = {"month": world.month}
	r["income"]["winnings"] = int(r["income"].get("winnings", 0)) + amt
	Logbook.note(world, "PAY", from_acct, "winnings", {"founder": id, "asked": amount}, {"paid": [0, amt]}, id)
	return amt


## This month's income of a founder's household by kind (winnings), credits x S.
static func founder_income(world: WorldState, id: String) -> Dictionary:
	var inc: Dictionary = world.peek(PERSON_TABLE).get(id, {}).get("income", {})
	return inc.duplicate() if int(inc.get("month", -1)) == world.month else {}


## Keeps the founders' households in step with PopStore after deaths and children growing up (which fall on people,
## not on records): per area and band, where fewer owners' adults or children stand in PopStore than the records hold,
## the records give them up, the largest households first (a founder themself last). The working count follows.
## Demography.monthly calls it at its end.
static func reconcile_families(world: WorldState) -> void:
	var by_ab := {}
	for id in CoreUtil.sorted_keys(world.peek(PERSON_TABLE)):
		var r: Dictionary = world.peek(PERSON_TABLE)[id]
		var k := "%s|%s" % [r["area"], r["band"]]
		if not by_ab.has(k):
			by_ab[k] = []
		by_ab[k].append(String(id))
	for k in CoreUtil.sorted_keys(by_ab):
		var area := String(k).get_slice("|", 0)
		var band := String(k).get_slice("|", 1)
		var ids: Array = by_ab[k]
		ids.sort_custom(func(a, b): return family_size(world, a) > family_size(world, b) or (family_size(world, a) == family_size(world, b) and a < b))
		var f := {"hb": area, "inc": band, "occ": "BUSINESS_OWNER"}
		var kids_real := PopStore.count(world, f.merged({"status": "CHILD"}))
		var kids_rec := 0
		for id in ids:
			kids_rec += int(world.peek(PERSON_TABLE)[id].get("family", {}).get("children", 0))
		var short := kids_rec - kids_real
		for id in ids:
			if short <= 0:
				break
			var fam: Dictionary = world.table(PERSON_TABLE)[id].get("family", {})
			var k2 := mini(short, int(fam.get("children", 0)))
			if k2 > 0:
				fam["children"] = int(fam["children"]) - k2
				short -= k2
				Logbook.note(world, "FAMILY", id, "a child is gone (grown up or died)", {}, {"children": [int(fam["children"]) + k2, int(fam["children"])]})
		for sk in TIERS:
			var real := PopStore.count(world, f.merged({"status": "NOT_IN_LF"}), "skill:" + sk) + PopStore.count(world, f.merged({"status": "EMPLOYED"}), "skill:" + sk)
			var rec := 0
			for id in ids:
				rec += int(family_adults(world, id)[sk])
			var gone := rec - real
			for pass_founder in [false, true]:
				for id in ids:
					if gone <= 0:
						break
					var fam: Dictionary = world.table(PERSON_TABLE)[id].get("family", {})
					var ads: Array = fam.get("adults", [])
					for i in range(ads.size() - 1, -1, -1):
						if gone <= 0:
							break
						if String(ads[i]["skill"]) != sk or (i == 0 and not pass_founder):
							continue
						ads.remove_at(i)
						gone -= 1
						var wk: Dictionary = fam.get("working", {})
						if int(wk.get(sk, 0)) > int(family_adults(world, id)[sk]):
							wk[sk] = int(family_adults(world, id)[sk])
						Logbook.note(world, "FAMILY", id, "an adult of the household died", {"skill": sk}, {"adults": [ads.size() + 1, ads.size()]})
			# and those working the posts: the EMPLOYED owners' people of this skill (a death may fall on one at work)
			var emp := PopStore.count(world, f.merged({"status": "EMPLOYED"}), "skill:" + sk)
			var wrec := 0
			for id in ids:
				wrec += int(family_working(world, id)[sk])
			var off := wrec - emp
			for id in ids:
				if off <= 0:
					break
				var wk: Dictionary = world.table(PERSON_TABLE)[id].get("family", {}).get("working", {})
				var d := mini(off, int(wk.get(sk, 0)))
				if d > 0:
					wk[sk] = int(wk[sk]) - d
					off -= d
					Logbook.note(world, "FAMILY", id, "one fewer at work on its own company", {"skill": sk}, {"working": [int(wk[sk]) + d, int(wk[sk])]})


## The grant was paid to this founder's plan (Ella's Grants.apply calls it): their household has had its one grant (61).
static func mark_granted(world: WorldState, id: String) -> void:
	var r: Dictionary = world.table(PERSON_TABLE).get(id, {})
	if not r.is_empty() and not bool(r.get("had_grant", false)):
		r["had_grant"] = true
		Logbook.note(world, "FOUNDER", id, "had its grant", {"pool": r["pool"]}, {"had_grant": [false, true]})


## A founder's person record takes on one thing it owns (the plan made for them, right after it is made: the plan's
## id is not known before). The founding sequence calls it (Wilma, on merge; for Maja to read).
static func own(world: WorldState, id: String, ref: String) -> void:
	var r: Dictionary = world.table(PERSON_TABLE).get(id, {})
	if not r.is_empty() and ref != "" and not (r["owns"] as Array).has(ref):
		(r["owns"] as Array).append(ref)
		Logbook.note(world, "FOUNDER", id, "owns", {}, {"owns": [(r["owns"] as Array).size() - 1, (r["owns"] as Array).size()]}, "", ref)


## A founder's person record gives up one thing it owned (a plan given up, a company ended). The conductor or Otto's
## give_up calls it before release_founder.
static func disown(world: WorldState, id: String, ref: String) -> void:
	var r: Dictionary = world.table(PERSON_TABLE).get(id, {})
	if not r.is_empty():
		(r["owns"] as Array).erase(ref)


# ---------------------------------------------------------------- ships (12.5, 42; C12, C13)

## How good the colony looks to settlers (0..1000, C12): jobs, food, homes. Kept as of the last ship's departure: the
## home world learns nothing else (9.6). The ship piece calls remember_attractiveness when a ship leaves.
static func attractiveness_now(world: WorldState) -> int:
	var lf := 0
	var emp := 0
	for pid in pools(world):
		var c := counts(world, pid)
		lf += int(c["lf"])
		emp += int(c["employed"])
	var jobs := 1000 if lf == 0 else emp * 1000 / lf
	var fed := 1000
	var need := 0
	var eaten := 0
	for pid in pools(world):
		var m := month_of(world, pid)
		need += int(m.get("food_need", 0))
		eaten += int(m.get("food_eaten", 0))
	if need > 0:
		fed = eaten * 1000 / need
	var h_ok := 1000
	for a in AreaStore.areas(world):
		var hm := homes(world, String(a["id"]))
		if int(hm["households"]) > 0:
			h_ok = mini(h_ok, int(hm["homes"]) * 1000 / maxi(1, int(hm["households"])))
	return (jobs * 4 + fed * 4 + mini(1000, h_ok) * 2) / 10


static func remember_attractiveness(world: WorldState) -> int:
	var a := attractiveness_now(world)
	world.table("pool_facts")["attract"] = a
	return a


static func attractiveness(world: WorldState) -> int:
	return int(world.peek("pool_facts").get("attract", 1000))


## Settlers landing from a ship in port (12.5, 42), in `area` = the PORT's area: the conductor passes
## AreaStore.area_of(Terrain.landing(world)) at each call, so a split or merge of the Landing still finds it. n persons in the mix of the founding settlers (bands, ages,
## skills), arriving (not founders), with the savings a household of their band brings. Returns persons landed.
## Fact ECON_MIGRANTS_ARRIVED.
static func land_settlers(world: WorldState, area: String, n: int) -> int:
	if n <= 0:
		return 0
	var per_band := CoreUtil.split_lr(n, BANDS.map(func(_b): return 1))
	var landed := 0
	for i in BANDS.size():
		var band: String = BANDS[i]
		var m := int(per_band[i])
		if m <= 0:
			continue
		var pid := ensure_pool(world, area, band)
		var parts := CoreUtil.split_lr(m, [BAND_WORKING, BAND_CHILDREN, BAND_RETIRED])
		var working := int(parts[0])
		var lf := working * LF_PM / 1000
		var sk: Array = BAND_SKILLS[band]
		_arrive(world, area, band, "UNEMPLOYED", CoreUtil.split_lr(lf, sk), "W")
		_arrive(world, area, band, "NOT_IN_LF", CoreUtil.split_lr(working - lf, sk), "W")
		_arrive(world, area, band, "RETIRED", CoreUtil.split_lr(int(parts[2]), sk), "O")
		if int(parts[1]) > 0:
			PopStore.arrive(world, PopStore.key_of({"hb": area, "inc": band, "occ": "NONE", "status": "CHILD", "arch": ARCH, "eff": "e0"}),
				int(parts[1]), {"age": {"C": int(parts[1])}, "skill": {"G": int(parts[1])}})
		var money := int(float(m) / HOUSEHOLD_SIZE * float(SAVINGS_PER_HOUSEHOLD[band])) * S
		world.ledger.transfer(Ledger.EXTERNAL, account(pid), money, "SETTLER_SAVINGS", world.month)
		landed += m
	preload("res://sim/population/demography.gd").add_arrivals(world, area, n)
	Logbook.note(world, "ARRIVE", area, "settlers landed", {"attractiveness": attractiveness(world)}, {"persons": [0, landed]})
	world.add_fact({"type": "ECON_MIGRANTS_ARRIVED", "owner": "econ", "subjects": [], "responsible": [], "impact": {}, "magnitude": 15,
		"visibility": "PUBLIC", "data": {"persons": landed, "area": area}})
	return landed


static func _arrive(world: WorldState, area: String, band: String, status: String, by_skill: Array, ages: String) -> void:
	for i in TIERS.size():
		var k := int(by_skill[i])
		if k <= 0:
			continue
		var age := {"O": k}
		if ages == "W":
			var a := CoreUtil.split_lr(k, ADULT_AGES)
			age = {"Y": a[0], "A": a[1], "M": a[2]}
		PopStore.arrive(world, PopStore.key_of({"hb": area, "inc": band, "occ": "NONE", "status": status, "arch": ARCH, "eff": "e0"}), k,
			{"age": age, "skill": {TIERS[i]: k}})


## The leaving's whole persons, the remainder carried per area and band (a small colony's fractions add up).
static func _leave_whole(world: WorldState, area: String, band: String, x: float) -> int:
	return preload("res://sim/population/demography.gd")._whole(world, "leave|%s|%s" % [area, band], x)


## People leaving on a ship in port (C13): of the unemployed young adults (the Y age band), LEAVE_PM per mille × how
## unattractive the colony looks; and the homeless households of the area, all of them (their workers give up their
## posts first). Returns persons gone. Fact ECON_EMIGRATION.
static func departures(world: WorldState, area: String) -> int:
	var unattractive := 1000 - attractiveness_now(world)
	var gone := 0
	for band in BANDS:
		var f := {"hb": area, "inc": band, "status": "UNEMPLOYED"}
		var young := PopStore.count(world, f, "age:Y")
		var k := _leave_whole(world, area, band, float(young) * float(LEAVE_PM) * float(unattractive) / 1000000.0)
		if k > 0:
			var keys := PopStore.select(world, f)
			var parts := PopStore.split_over(k, keys, keys.map(func(x): return float(world.peek("pop")[x]["age"].get("Y", 0))))
			for key in CoreUtil.sorted_keys(parts):
				PopStore.depart(world, key, int(parts[key]), "EMIGRATION", {"age": "Y"})
				gone += int(parts[key])
	var hl := int(homes(world, area)["homeless"])
	if hl > 0:
		# homes are not kept by band, so who is homeless is not known by band: the homeless leave in equal shares over
		# the bands (largest remainder, so nobody is dropped)
		var persons_hl := int(float(hl) * HOUSEHOLD_SIZE)
		var hl_parts := CoreUtil.split_lr(persons_hl, BANDS.map(func(_b): return 1))
		for bi in BANDS.size():
			var band: String = BANDS[bi]
			var share := int(hl_parts[bi])
			var emp := PopStore.count(world, {"hb": area, "inc": band, "status": "EMPLOYED"})
			var all_b := PopStore.count(world, {"hb": area, "inc": band})
			if all_b <= 0:
				continue
			gone += end_jobs(world, area, band, share * emp / all_b, "DEPART")
			var rest := PopStore.select(world, {"hb": area, "inc": band}).filter(func(x): return String(world.peek("pop")[x]["status"]) != "EMPLOYED" and String(world.peek("pop")[x]["occ"]) != "BUSINESS_OWNER")
			var parts2 := PopStore.split_over(share - share * emp / all_b, rest, rest.map(func(x): return float(world.peek("pop")[x]["n"])))
			for key in CoreUtil.sorted_keys(parts2):
				var kk := mini(int(parts2[key]), int(world.peek("pop").get(key, {}).get("n", 0)))
				if kk > 0:
					PopStore.depart(world, key, kk, "EMIGRATION")
					gone += kk
	if gone > 0:
		preload("res://sim/population/demography.gd").remove_departures(world, area, gone)
		Logbook.note(world, "DEPART", area, "left on the ship", {"unattractive_pm": unattractive, "homeless_households": hl}, {"persons": [0, gone]})
		world.add_fact({"type": "ECON_EMIGRATION", "owner": "econ", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
			"impact": {"JOBS": -mini(40, gone / 5)}, "magnitude": clampi(20 + gone / 10, 20, 60), "visibility": "PUBLIC",
			"data": {"persons": gone, "area": area}})
	return gone


# ================================================================ for other pieces' tests

## n unemployed adults of skill `tier` in pool (area, band), with the pool and its account. Tests only.
static func seed_test(world: WorldState, area: String, band: String, tier: String, n: int) -> String:
	var pid := ensure_pool(world, area, band)
	var by := [0, 0, 0]
	by[TIERS.find(tier)] = n
	_seed(world, area, band, "UNEMPLOYED", by, true)
	return pid
