extends PicProvider
## THE ECONOMY'S MONTH: the one conductor (rebuild step 3; planning/rebuild-step3-joins.md; Wilma).
##
## This is the only provider registered for the economy's phases. Every piece of the economy is static functions that
## this file calls, in the order written in the joins paper, so nothing depends on the order providers were registered
## in and the market can never clear before every order is posted.
##
## Every piece of step 3 is called here.
##
## The conductor decides nothing and moves nothing itself; the pieces write their own Logbook rows. Its one row is
## "no plan: no free site", which no piece can write because none was called.

const Company := preload("res://sim/economy/company.gd")
const Households := preload("res://sim/population/households.gd")
const Landing := preload("res://sim/economy/landing.gd")
const Ship := preload("res://sim/economy/ship.gd")
const Market := preload("res://sim/economy/market.gd")
const Making := preload("res://sim/economy/making.gd")
const Rules := preload("res://sim/economy/rules.gd")
const Building := preload("res://sim/economy/building.gd")
const Grants := preload("res://sim/economy/grants.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Site := preload("res://sim/transport/site.gd")

## The types a settler may found. Step 3 is tested on food alone first (plan 13): every other type is in the table but
## nobody may found it until food passes.
const FOUNDABLE: Array[String] = ["FARM"]

const OWNER := "econ_month"


## The grants read what a founder must bring and what work a type has from the pieces that know (Ella's two hooks).
func _init() -> void:
	Grants.needs_fn = func(w, type, size, area): return Building.founder_needs(w, type, size, area)
	Grants.need_fn = func(w, type, _size, area): return Rules.work(w, type, area)


func owner_id() -> String:
	return OWNER


func phases() -> Array:
	return [TickPhase.TRADE, TickPhase.PRODUCTION, TickPhase.SETTLEMENT, TickPhase.COMPANY_AI, TickPhase.JUSTICE, TickPhase.SOCIAL]


## Registered after Landing (month one's government side): the ship that brought the colony lies in port.
func init_world(world: WorldState) -> void:
	Ship.land(world)


func run_phase(phase: int, world: WorldState) -> void:
	match phase:
		TickPhase.TRADE:
			trade(world)
		TickPhase.PRODUCTION:
			production(world)
		TickPhase.SETTLEMENT:
			settlement(world)
		TickPhase.COMPANY_AI:
			company_ai(world)
		TickPhase.JUSTICE:
			justice(world)
		TickPhase.SOCIAL:
			social(world)


## 1. the ship. Settlers land and leavers go aboard inside it, when a ship arrives (the households' side, 12.5, 42).
static func trade(world: WorldState) -> void:
	Ship.month(world)


## 1. plants whose building was done last month open;  2. every company makes;  3. the builders work their contracts.
static func production(world: WorldState) -> void:
	Building.open_due(world)
	Making.month(world)
	Building.work_month(world)


## 1. everyone's orders: households, companies' inputs, building sites' supplies;  2. Market.clear (Bob);  3. what was
## bought is taken in (households eat; sites take their supplies);  4. contract bills, before wages;  5. the rent;  6. the purse's bill, which gives a state company what it lacks for its wages, and pays the benefit and
## pensions;  7. every company pays its own wages from its own account;  8. Colony Stores' takings to the treasury,
## and the sweep.
## The market and the rent, when they come, go BEFORE the purse's bill: a state company's takings and rent must be in
## its account when the purse works out what it lacks (Bob's and Ella's reviews).
## (The joins paper had the purse after the wages. A state company can only pay its wages once the purse has given it
## what it lacks, so the purse's bill comes first; nothing else moved.)
static func settlement(world: WorldState) -> void:
	Households.post_orders(world, func(id): return Landing.rent_due(world, id))   # 1. what households need, each line with its budget; the store from what food and rent leave (15f)
	Making.post_orders(world)       # 1. companies' inputs
	Building.supply_orders(world)   # 1. building sites' supplies
	Building.upkeep_orders(world)   # 1. plants' upkeep material (12.3, 14 and 58; its builder part is step 6)
	Market.clear(world)
	Households.after_market(world)
	Building.take_deliveries(world)
	Building.take_upkeep(world)
	Building.bill_month(world)
	Households.pay_rent(world, func(id): return Landing.rent_due(world, id))
	Landing.purse_month(world)
	for cid in Company.ids(world):
		if String(Company.record(world, cid)["status"]) == "OPEN":
			Company.pay_wages(world, cid)   # books what was due and what was paid, which rule 19a reads (Bob)
	Landing.stores_takings(world)
	Landing.sweep(world)


## 1. Rules.month (Bob), which also closes each company's books for the month;  2. the grant programmes' month (Ella):
## programmes open and close and the need is published;  3. the government decides each programme it has not decided
## (GovBuilder.grant_programmes: its sum and the districts it covers);  4. founding;  5. plans sign with builders (Otto).
## 2 and 3 come before founding so a founder applies to a programme the government has already decided (Wilma,
## 2026-11-18: in month one every farm applied before the government had chosen, so none was covered and the sum, set
## after them, counted them as farms already planned).
static func company_ai(world: WorldState) -> void:
	Rules.month(world)
	Grants.monthly(world)
	GovBuilder.grant_programmes(world)
	founding(world)
	Building.sign_round(world)


## The founding sequence (joins paper, COMPANY_AI 2), for every type that may be founded and every area. Each call is
## its owner's; this only puts them in order. For one plan:
##   rule 7 and 8 say which sizes pass (Bob); from the largest passing size down, what a founder must bring (Otto) and
##   what grant each pool would get (Ella); a founder is drawn among the households that can pay (Maja); a site is
##   chosen (Terra); the founder is counted one by one (Maja); the plan is made, holding its site, with the founder's
##   money (Otto); the grant is paid into the plan's account (Ella).
## "Nothing limits how many may plan at once" (plan 12.3, 15a): it goes on while rule 7 passes, a household can pay
## and a site is free. A plant counts in rule 7 once it stands; a plan does not. So many may plan into the same work.
static func founding(world: WorldState) -> void:
	for type in FOUNDABLE:
		for a in AreaStore.areas(world):
			var area := String(a["id"])
			Rules.founding(world, type, area)   # the month's row: what each size read
			while _found_one(world, type, area):
				pass


## Makes one plan of `type` in `area` if anyone can and will. Returns false when nobody did.
static func _found_one(world: WorldState, type: String, area: String) -> bool:
	var sizes: Array = Building.passing_sizes(world, type, area)
	sizes.reverse()   # the largest that passes first
	for size in sizes:
		var needs := Building.founder_needs(world, type, String(size), area)
		var kind := Grants.kind_of(type, String(size))
		var grants := {}
		for pid in Households.pools(world):
			if String(world.peek("pool")[pid]["area"]) == area:
				grants[pid] = Grants.quote(world, kind, area, String(pid)) if kind != "" else 0
		var pool := Households.pick_founder(world, area, needs, grants)
		if pool == "":
			continue
		var sixths := TypeTable.sixths(String(size))
		var sites: Array = Site.choose_country(world, type, sixths, 1) if Site.setting(type) == "COUNTRY" else Site.choose_town(world, area, type, sixths, 1)
		if sites.is_empty():
			Logbook.note(world, "PLAN", area, "no plan: no free site", {"type": type, "size": size})
			return false
		# a family-size company is the family's own: the whole household goes with the founder and works it (15e)
		var founder := Households.make_founder(world, pool, "", String(size) == "FAMILY")
		if founder == "":
			return false
		var plan := Building.make_plan(world, founder, type, String(size), area, sites[0], {"needs": needs / CoreUtil.S})
		if plan == "":
			Households.release_founder(world, founder)
			return false
		Households.own(world, founder, plan)
		Grants.apply(world, plan)
		return true
	return false


## After the law's own JUSTICE (it is registered first, so its debt collector has run): the owners of family
## companies take their winnings, last of everything the company owes that month (15e; Bob).
static func justice(world: WorldState) -> void:
	Rules.pay_winnings(world)


## Nothing of the conductor's: the population provider runs life, the labour month and the yearly raise before this,
## and what politics reads (econ_publish) is registered after it.
static func social(_world: WorldState) -> void:
	pass
