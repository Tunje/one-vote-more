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


## To come: 1. Building.open_due (Otto)  2. Making.month (Bob)  3. Building.work_month (Otto).
static func production(_world: WorldState) -> void:
	pass


## To come before the wages: 1. orders posted (Maja, Bob, Otto)  2. Market.clear (Bob)  3. what was bought taken in
## (Maja, Otto)  4. Building.bill_month (Otto)  5. Households.pay_rent (Maja).
## Here now: 6. the purse's bill, which gives a state company what it lacks for its wages, and pays the benefit and
## pensions;  7. every company pays its own wages from its own account;  8. Colony Stores' takings to the treasury,
## and the sweep.
## The market and the rent, when they come, go BEFORE the purse's bill: a state company's takings and rent must be in
## its account when the purse works out what it lacks (Bob's and Ella's reviews).
## (The joins paper had the purse after the wages. A state company can only pay its wages once the purse has given it
## what it lacks, so the purse's bill comes first; nothing else moved.)
static func settlement(world: WorldState) -> void:
	Landing.purse_month(world)
	for cid in Company.ids(world):
		if String(Company.record(world, cid)["status"]) == "OPEN":
			Households.pay_wages(world, cid, CoreUtil.acct(cid), {"why": "its own wages, from its own account"})
	Landing.stores_takings(world)
	Landing.sweep(world)


## To come: 1. Rules.month (Bob)  2. founding (the sequence in the joins paper)  3. Building.sign_round (Otto)
## 4. Grants.monthly (Ella).
static func company_ai(_world: WorldState) -> void:
	pass


## To come: Households.labour_month and yearly_raise_month (Maja). The population's own month runs before this, and
## what politics reads (econ_publish) after it.
static func social(_world: WorldState) -> void:
	pass
