extends PicProvider
## Month one's government side, and the purse's monthly payments (rebuild step 2; plan 12.2 points 8, 9, 11, 13; 9.12;
## the step-2 brief; Wilma, reviewed by Bob and by Ella for the purse).
##
## "the goverment starts with its subsidiaries as before"; "materials come with the start not finished buildings";
## "they are companies from the world". So in month one this makes, in the Landing:
##   - the five home-world builders and the public works department (Otto's HomeBuilders.land), and gives the five
##     their capital;
##   - the government's subsidiaries as companies owned by the state. Power, water, transit, the clinic, the school and
##     the police exist as companies with NO plant and NO staff: the colony lands with no finished buildings, and their
##     buildings are for the government to commission. The administration works from the landing site with a crew;
##   - the housing office, a state LANDLORD whose plants are the landing shelters (12.2, 11): plain homes on the town
##     grid at the shelter rent, one home for every founding household;
##   - Colony Stores, a state SHOP with no building yet, which holds THE LANDING STOCK (12.2, 9) and offers it at the
##     starting prices: material, components, trucks, and food (food is Wilma's addition);
##   - the treasury's opening money.
## Every month after, in SETTLEMENT, the purse:
##   - pays the wages of every state company's staff from the treasury (they have no income of their own yet; from
##     step 3 a state company that sells pays its own staff and the purse covers only what the plan says it covers);
##   - pays the benefit to the jobless and the pension to the retired, at Ella's two levers: per cent of the area's
##     starting salary (12.5, 41);
##     When the treasury cannot pay the whole bill every line gets the same share, and a public fact says so;
##   - sweeps every other government account ("gov:...") into the treasury, one ledger entry and one log row per
##     source, so every credit of revenue is seen where it came from.
##
## NOT here: sales from the stock, rent collected, the builders paying their own crews, grants (step 3).
## Every figure marked START is a starting number of ours (plan 12.1, 8), to be adjusted from the reports.
##
## Every deed writes a Logbook row; Company and Households write their own for what they do.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Households := preload("res://sim/population/households.gd")
const HomeBuilders := preload("res://sim/economy/home_builders.gd")
const Site := preload("res://sim/transport/site.gd")

const OWNER := "landing"
const S := CoreUtil.S
const OWNER_STATE := {"kind": "STATE", "holders": {"gov": 1000}}
const TIERS := ["Sp", "S", "G"]   # highest first, as HomeBuilders hires

const ORIGIN_SUBSIDIARY := "STATE_SUBSIDIARY"
const ORIGIN_HOUSING := "HOUSING_OFFICE"
const ORIGIN_STORES := "COLONY_STORES"

## The subsidiaries with no plant and no staff in month one: type, name. START (the names are new).
const UNBUILT := [["POWER", "Colony Power"], ["WATERWORKS", "Colony Water"], ["TRANSIT", "Colony Transit"],
	["CLINIC", "Landing Clinic"], ["SCHOOL", "Landing School"], ["POLICE", "Colony Constabulary"]]
const ADMIN := ["ADMIN", "Colony Administration", "LARGE"]   # START: a full administration's posts, working as a crew
const HOUSING := "Colony Housing Office"
const STORES := ["SHOP", "Colony Stores", "LARGE"]

const SHELTER_HOMES := 50                 # a LARGE landlord plant is a block of 50 homes (type table)
const SHELTER_RENT := 48 * S              # START: the shelter rent the salary formula was worked with (type-table paper 9)
## The landing stock, in units. START. Material and components are Bob's reading of "5 years worth of equipment"
## (five years of the five builders' full work); food is twelve months for the founding thousand; trucks "enough for
## the first truck drivers" (the step-2 brief).
const STOCK := {"FOOD": 12000, "MATERIAL": 9700, "COMPONENT": 1060, "TRUCK": 20}
const TREASURY_START := 2000000           # START, credits: about two years of the purse's month-one spending
const BUILDER_CAPITAL_MONTHS := 3         # START: each home-world builder lands with three months of its wage bill

const PAYING := "gov:paying"               # a short month's shares pass through it, line by line; empty between payments
const BENEFIT_LEVER := "ECON_UNEMPLOYMENT_BENEFIT_RATE"
const PENSION_LEVER := "ECON_PENSION_RATE"


func owner_id() -> String:
	return OWNER


func phases() -> Array:
	return [TickPhase.SETTLEMENT]


## Registered after the population provider: the Landing exists and the founding settlers have landed.
func init_world(world: WorldState) -> void:
	land(world, AreaStore.found_landing(world))


func run_phase(_phase: int, world: WorldState) -> void:
	purse_month(world)


# ================================================================ month one

## Makes month one's government side in `area`. Once: a second call makes nothing. Returns what it made:
## {"builders": HomeBuilders' result, "unbuilt": {type: id}, "admin": id, "housing": id, "stores": id}.
static func land(world: WorldState, area: String) -> Dictionary:
	var t := world.table(OWNER)
	if t.has("made"):
		return (t["made"] as Dictionary).duplicate(true)
	if area == "":
		Logbook.note(world, "LAND", "gov", "nothing made: there is no landing place")
		return {}
	world.ledger.open_account(CoreUtil.TREASURY)
	world.ledger.open_account(CoreUtil.FINES)   # the law pays fines into it only if it exists; the sweep empties it (Ella's review)
	world.ledger.transfer(Ledger.EXTERNAL, CoreUtil.TREASURY, TREASURY_START * S, "LANDING_TREASURY", world.month)
	Logbook.note(world, "LAND", "gov", "treasury opened", {}, {"treasury": [0, TREASURY_START]})

	var builders := HomeBuilders.land(world, area)
	for cid in builders.get("home_world", []):
		var capital := Company.wage_bill(world, cid) * BUILDER_CAPITAL_MONTHS
		if capital > 0:
			world.ledger.transfer(Ledger.EXTERNAL, CoreUtil.acct(cid), capital, "LANDING_CAPITAL", world.month)
		Logbook.note(world, "LAND", cid, "capital from the home world", {"months_of_wages": BUILDER_CAPITAL_MONTHS},
			{"money": [0, capital / S]})

	var unbuilt := {}
	for spec in UNBUILT:
		var cid := Company.create(world, String(spec[0]), "LARGE", OWNER_STATE, String(spec[1]),
			{"origin": ORIGIN_SUBSIDIARY, "area": area})
		unbuilt[spec[0]] = cid
		Logbook.note(world, "LAND", cid, "state subsidiary, no building yet", {"type": spec[0], "area": area})

	var admin := Company.create(world, String(ADMIN[0]), String(ADMIN[2]), OWNER_STATE, String(ADMIN[1]),
		{"origin": ORIGIN_SUBSIDIARY, "area": area})
	Logbook.note(world, "LAND", admin, "the administration, working from the landing site", {"area": area})
	_crew(world, admin, "crew", String(ADMIN[0]), String(ADMIN[2]), area)

	var made := {"builders": builders, "unbuilt": unbuilt, "admin": admin,
		"housing": _shelters(world, area), "stores": _stores(world, area)}
	t["made"] = made
	return made.duplicate(true)


## The housing office and the landing shelters: one home for every founding household, in blocks of SHELTER_HOMES.
static func _shelters(world: WorldState, area: String) -> String:
	var cid := Company.create(world, "LANDLORD", "LARGE", OWNER_STATE, HOUSING, {"origin": ORIGIN_HOUSING, "area": area})
	Company.set_price(world, cid, "@home", SHELTER_RENT, {"why": "the shelter rent"}, "shelter rent set")
	var households := 0
	for pid in Households.pools(world):
		if String(world.peek("pool")[pid]["area"]) == area:
			households += int(Households.counts(world, pid)["households"]) / S
	var left := households
	var laid := 0
	while left > 0:
		var homes := mini(SHELTER_HOMES, left)
		var pid := Company.add_plant(world, cid, "LARGE")
		var sites := Site.choose_town(world, area, "LANDLORD", 6, 1)
		var why := "no free site in the town" if sites.is_empty() else Site.place(world, pid, sites[0], homes)
		if why != "":
			Logbook.note(world, "LAND", cid, "shelter block NOT laid", {"why": why, "homes": homes}, {}, "", pid)
			break
		Logbook.note(world, "LAND", cid, "landing shelters laid", {"homes": homes, "cell": sites[0]["cells"][0]}, {}, "", pid)
		_crew(world, cid, pid, "LANDLORD", "LARGE", area)
		left -= homes
		laid += homes
	Logbook.note(world, "LAND", cid, "the housing office", {"households": households}, {"homes": [0, laid]})
	return cid


## Colony Stores and the landing stock, each good at its starting price.
static func _stores(world: WorldState, area: String) -> String:
	var cid := Company.create(world, String(STORES[0]), String(STORES[2]), OWNER_STATE, String(STORES[1]),
		{"origin": ORIGIN_STORES, "area": area})
	_crew(world, cid, "crew", String(STORES[0]), String(STORES[2]), area)
	for item in CoreUtil.sorted_keys(STOCK):
		var price := TypeTable.start_price(String(item))
		var ok := Company.stock_add(world, cid, String(item), int(STOCK[item]) * S, price, "LANDING", "the landing stock")
		ok = Company.offer(world, cid, String(item), price, {"why": "the landing stock is sold at the starting price"}) and ok
		if not ok:
			Logbook.note(world, "LAND", cid, "landing stock NOT taken in or offered", {"item": item, "units": STOCK[item]})
	return cid


## Hires a full set of posts for one plant (or the crew) from the area's settlers; a CREW row when it comes up short.
static func _crew(world: WorldState, cid: String, plant_key: String, type: String, size: String, area: String) -> void:
	var posts := TypeTable.posts(type, size)
	var short := {}
	for tier in TIERS:
		var want := int(posts.get(tier, 0))
		if want <= 0:
			continue
		var got := Households.hire(world, cid, plant_key, tier, area, want, {"why": "month one, the government's staff"})
		if got < want:
			short[tier] = [want, got]
	if not short.is_empty():
		Logbook.note(world, "CREW", cid, "staff short in month one", {"wanted_got": short, "at": plant_key})


# ================================================================ the purse, every month

## Every company the state owns, in id order.
static func state_companies(world: WorldState) -> Array:
	var out: Array = []
	for cid in Company.ids(world):
		if Company.is_state(world, cid):
			out.append(cid)
	return out


## What one person on support gets a month in each area that has people, credits x S: `rate` per cent of the area's
## starting salary (12.5, 41). Until areas carry their own salary line (step 3) that is the type table's general salary.
static func support_rates(world: WorldState, rate_pct: int) -> Dictionary:
	var out := {}
	for pid in Households.pools(world):
		out[String(world.peek("pool")[pid]["area"])] = TypeTable.salary("G") * rate_pct / 100
	return out


## What a kind of support comes to this month at these rates, credits x S (what Households.pay_support will ask for).
static func support_due(world: WorldState, kind: String, rates: Dictionary) -> int:
	var status := "UNEMPLOYED" if kind == "benefit" else "RETIRED"
	var due := 0
	for pid in Households.pools(world):
		due += Households.persons(world, pid, status) * int(rates.get(String(world.peek("pool")[pid]["area"]), 0))
	return due


## The purse's month: the sweep, then ONE bill: every state company's wages, the benefit and the pensions. Returns
## what was due, paid and swept, credits x S. When the treasury cannot pay the whole bill, every line gets the same
## share of what it holds (Ella's review: no order of our own among them, and no state company before another), and a
## public fact says so.
static func purse_month(world: WorldState) -> Dictionary:
	var tre := CoreUtil.TREASURY
	if not world.ledger.has_account(tre):
		return {}
	var swept := sweep(world)   # first, so this month's payments can use what came in
	var b_rate := int(CoreUtil.lever(world, BENEFIT_LEVER, 0))
	var p_rate := int(CoreUtil.lever(world, PENSION_LEVER, 0))
	var b_rates := support_rates(world, b_rate)
	var p_rates := support_rates(world, p_rate)
	var cos := state_companies(world)
	var dues: Array = []   # one per line: the state companies in id order, then the benefit, then the pensions
	for cid in cos:
		dues.append(Company.wage_bill(world, cid))
	dues.append(support_due(world, "benefit", b_rates))
	dues.append(support_due(world, "pension", p_rates))
	var due := 0
	for d in dues:
		due += int(d)
	var have := maxi(0, world.ledger.balance(tre))
	var short := have < due
	var shares: Array = CoreUtil.split_lr(have, dues) if short else dues
	if short and not world.ledger.has_account(PAYING):
		world.ledger.open_account(PAYING)
	var paid: Array = []
	for i in dues.size():
		var from := tre
		if short:
			from = PAYING
			if int(shares[i]) > 0:
				world.ledger.transfer(tre, PAYING, int(shares[i]), "PURSE_SHARE", world.month)
		if i < cos.size():
			paid.append(Households.pay_wages(world, String(cos[i]), from, {"why": "the purse pays the state's staff"}))
		elif i == cos.size():
			paid.append(Households.pay_support(world, "benefit", from, b_rates, {"rate_pct": b_rate}))
		else:
			paid.append(Households.pay_support(world, "pension", from, p_rates, {"rate_pct": p_rate}))
		if short and world.ledger.balance(PAYING) > 0:   # a rounding's remainder goes back
			world.ledger.transfer(PAYING, tre, world.ledger.balance(PAYING), "PURSE_SHARE_BACK", world.month)
	var wages := 0
	for i in cos.size():
		wages += int(paid[i])
	var benefit := int(paid[cos.size()])
	var pension := int(paid[cos.size() + 1])
	var out := {"wages": wages, "benefit": benefit, "pension": pension, "swept": swept, "due": due,
		"wages_due": due - int(dues[cos.size()]) - int(dues[cos.size() + 1]), "benefit_due": int(dues[cos.size()]),
		"pension_due": int(dues[cos.size() + 1])}
	Logbook.note(world, "PURSE", "gov", "the month's payments SHORT" if short else "the month's payments",
		{"benefit_rate_pct": b_rate, "pension_rate_pct": p_rate, "due": due / S, "treasury_before": have / S},
		{"wages": [int(out["wages_due"]) / S, wages / S], "benefit": [int(out["benefit_due"]) / S, benefit / S],
		"pension": [int(out["pension_due"]) / S, pension / S], "swept": [0, swept / S],
		"treasury": [have / S, world.ledger.balance(tre) / S]})
	if short:
		world.add_fact({"type": "ECON_PURSE_SHORT", "owner": "econ", "subjects": [],
			"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}], "impact": {},
			"magnitude": 60, "visibility": "PUBLIC", "data": {"due": due / S, "paid": (wages + benefit + pension) / S,
			"wages": [int(out["wages_due"]) / S, wages / S], "benefit": [int(out["benefit_due"]) / S, benefit / S],
			"pension": [int(out["pension_due"]) / S, pension / S]}})
	return out


## Moves what every other government account holds into the treasury: one ledger entry per source ("SWEEP:<account>")
## and one log row. Returns the total, credits x S.
static func sweep(world: WorldState) -> int:
	var total := 0
	for k in CoreUtil.sorted_keys(world.ledger.balances):
		var a := String(k)
		if not a.begins_with("gov:") or a == CoreUtil.TREASURY:
			continue
		var amt := world.ledger.balance(a)
		if amt <= 0:
			continue
		world.ledger.transfer(a, CoreUtil.TREASURY, amt, "SWEEP:" + a, world.month)
		Logbook.note(world, "SWEEP", "gov", "revenue to the treasury", {"from": a}, {"amount": [0, amt / S]})
		total += amt
	return total
