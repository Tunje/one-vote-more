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
				if String(l["occ"]) == "BUSINESS_OWNER":
					out["owners"] += n
				else:
					out["nonpart"] += n
	out["households"] = int(float(out["persons"]) / HOUSEHOLD_SIZE)
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
static func hire(world: WorldState, cid: String, plant_key: String, post_tier: String, area: String, n: int, why: Dictionary = {}, pay: int = -1) -> int:
	if n <= 0:
		return 0
	var occ := String(Company.occupation(world, cid, post_tier))
	var at := plant_area(world, cid, plant_key)
	if pay < 0:
		if at == "":
			Logbook.note(world, "HIRE", cid, "no hire: the post's plant stands nowhere", {"plant": plant_key, "wanted": n})
			return 0
		pay = Company.hiring_salary(world, cid, post_tier, at)
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
			if not Company.staff_change(world, cid, plant_key, post_tier, labour_key(area, band, skill), k * S, pay):
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


## Company `cid` lays off up to n people from posts of `post_tier` at `plant_key`: the largest holders first, then by
## key, so the outcome repeats. They keep their occupation and skill (P7). Returns persons laid off.
static func layoff(world: WorldState, cid: String, plant_key: String, post_tier: String, n: int, why: Dictionary = {}) -> int:
	if n <= 0:
		return 0
	var occ := String(Company.occupation(world, cid, post_tier))
	var entries: Dictionary = Company.staff_entries(world, cid).get(plant_key, {}).get(post_tier, {})
	var keys: Array = CoreUtil.sorted_keys(entries)
	var nn := func(k) -> int: return int(entries[k]["n"])
	keys.sort_custom(func(a, b): return nn.call(a) > nn.call(b) or (nn.call(a) == nn.call(b) and String(a) < String(b)))
	var done := 0
	var given := {}
	for lk in keys:
		if done >= n:
			break
		var p := labour_parts(String(lk))
		var k := mini(n - done, int(entries[lk]["n"]) / S)
		k = PopStore.move_group(world, {"hb": p[0], "inc": p[1], "status": "EMPLOYED", "occ": occ}, k,
			{"status": "UNEMPLOYED"}, String(why.get("reason", "LAYOFF")), "skill:" + p[2])
		if k <= 0:
			continue
		var ok: bool = Company.staff_change(world, cid, plant_key, post_tier, String(lk), -k * S)
		assert(ok, "staff_change refused a layoff")
		given[lk] = k
		done += k
	if done > 0:
		var w := why.duplicate()
		w["wanted"] = n
		Logbook.note(world, "LAYOFF", cid, "laid off %s %s" % [post_tier, plant_key], w, {"staff": [done, 0], "to": [{}, given]})
	return done


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
## share of what it holds; laying people off is the company's decision (12.3, 19a), not this function's. Returns the
## amount paid. One Logbook PAY row.
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
	var w := why.duplicate()
	w["due"] = due
	Logbook.note(world, "PAY", cid, "wages", w, {"paid": [0, got], "short": [0, due - got]})
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


# ================================================================ for other pieces' tests

## n unemployed adults of skill `tier` in pool (area, band), with the pool and its account. Tests only.
static func seed_test(world: WorldState, area: String, band: String, tier: String, n: int) -> String:
	var pid := ensure_pool(world, area, band)
	var by := [0, 0, 0]
	by[TIERS.find(tier)] = n
	_seed(world, area, band, "UNEMPLOYED", by, true)
	return pid
