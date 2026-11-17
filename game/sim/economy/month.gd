extends PicProvider
## THE ECONOMY'S MONTH: the one conductor (rebuild step 3; planning/rebuild-step3-joins.md; Wilma).
##
## This is the only provider registered for the economy's phases. Every piece of the economy is static functions that
## this file calls, in the order written in the joins paper, so nothing depends on the order providers were registered
## in and the market can never clear before every order is posted.
##
## A call to a function whose piece is not merged yet is NOT here: it is added, at its place, in the same commit that
## merges the piece. The list of what is still to come is at each phase.
##
## The conductor decides nothing and moves nothing itself. It writes no Logbook rows: the pieces write their own.

const Company := preload("res://sim/economy/company.gd")
const Households := preload("res://sim/population/households.gd")
const Landing := preload("res://sim/economy/landing.gd")
const Ship := preload("res://sim/economy/ship.gd")
const Market := preload("res://sim/economy/market.gd")
const Making := preload("res://sim/economy/making.gd")
const Rules := preload("res://sim/economy/rules.gd")

const OWNER := "econ_month"


func owner_id() -> String:
	return OWNER


func phases() -> Array:
	return [TickPhase.TRADE, TickPhase.PRODUCTION, TickPhase.SETTLEMENT, TickPhase.COMPANY_AI, TickPhase.SOCIAL]


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
		TickPhase.SOCIAL:
			social(world)


## 1. the ship.   To come: settlers landing and leavers going aboard (Maja), inside Ship.month's call in port.
static func trade(world: WorldState) -> void:
	Ship.month(world)


## To come: 1. Building.open_due (Otto), first;  3. Building.work_month (Otto), last.  Here now: 2. Making.month (Bob).
static func production(world: WorldState) -> void:
	Making.month(world)


## To come: 1. orders posted (Maja, Bob, Otto), before the clear;  3. what was bought taken in (Maja, Otto)
## 4. Building.bill_month (Otto)  5. Households.pay_rent (Maja), all three between the clear and the purse.
## Here now: 2. Market.clear (Bob);  6. the purse's bill, which gives a state company what it lacks for its wages, and pays the benefit and
## pensions;  7. every company pays its own wages from its own account;  8. Colony Stores' takings to the treasury,
## and the sweep.
## The market and the rent, when they come, go BEFORE the purse's bill: a state company's takings and rent must be in
## its account when the purse works out what it lacks (Bob's and Ella's reviews).
## (The joins paper had the purse after the wages. A state company can only pay its wages once the purse has given it
## what it lacks, so the purse's bill comes first; nothing else moved.)
static func settlement(world: WorldState) -> void:
	Making.post_orders(world)   # 1. companies' inputs
	Market.clear(world)
	Landing.purse_month(world)
	for cid in Company.ids(world):
		if String(Company.record(world, cid)["status"]) == "OPEN":
			Company.pay_wages(world, cid)   # books what was due and what was paid, which rule 19a reads (Bob)
	Landing.stores_takings(world)
	Landing.sweep(world)


## Here now: 1. Rules.month (Bob), which also closes each company's books for the month.
## To come: 2. founding (the sequence in the joins paper)  3. Building.sign_round (Otto)  4. Grants.monthly (Ella).
static func company_ai(world: WorldState) -> void:
	Rules.month(world)


## To come: Households.labour_month and yearly_raise_month (Maja). The population's own month runs before this, and
## what politics reads (econ_publish) after it.
static func social(_world: WorldState) -> void:
	pass
