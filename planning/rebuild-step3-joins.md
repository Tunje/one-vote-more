# Rebuild step 3: the joins

Wilma, 2026-11-17, from the six joins notes. This is what every piece builds against. Where two notes named the same
thing differently, the name here stands. Money is credits x S (milli-credits), quantities milli-units.

## The conductor

One provider, `game/sim/economy/month.gd` (Wilma), is the only thing registered for the economy's phases. Every
piece below is static functions; none registers itself. The conductor calls them in the order written here, so nothing
depends on registration order. The population provider keeps its own SOCIAL month and runs before the conductor's
SOCIAL; `econ_publish` moves to after both (Ella's point).

Phases that are not the economy's, in the game's order: DECISIONS (the law applies levers), STAFF, **NATURE** (this
month's weather, storms, road wear; `Site.step_month`), then TRADE, PRODUCTION, SETTLEMENT, COMPANY_AI, then
**JUSTICE** (licences decided, fines paid into the fines account), SOCIAL, POLITICS, EVENTS, RECORD.

### TRADE
1. `Ship.month(world)` (Wilma): a ship in port lands what was ordered (`Company.stock_add ... "IMPORT"`), settlers
   (`Households.land_settlers`), takes leavers (`Households.departures`), takes this month's orders aboard, leaves.

### PRODUCTION
1. `Building.open_due(world)` (Otto): each contract done last month becomes a company and a plant. In this order:
   `Company.create` + `add_plant`; `Site.open(plan, plant)`; `LandLaw.pass_holder(plan, company)`;
   `LawCompany.register`; `LawCompany.may_open` (not ok: `Company.close_plant(pid, "LAW")`); the plan account's money
   to the company's account; OPEN row with the plan as ref.
2. `Making.month(world)` (Bob): output = full output x staffed share x condition x output level x
   `Site.yield_pm(world, plant, month) / 1000` (Terra; 1000 for anything but a farm), limited by inputs held.
3. `Building.work_month(world)` (Otto).

### SETTLEMENT
1. Orders posted: `Households.post_orders` (Maja), `Making.post_orders` (Bob: companies' inputs),
   `Building.supply_orders` (Otto). All through `Market.order(world, buyer, item, qty, max_price, kind)`.
2. `Market.clear(world)` (Bob).
3. What was bought is taken in: `Households.after_market` (Maja), `Building.take_deliveries` (Otto), each reading
   `Market.filled`.
4. `Building.bill_month` (Otto): contract bills, before wages (Otto's change, accepted).
5. `Households.pay_rent` (Maja), reading `Landing.rent_due(world, pool_id) -> {landlord account: amount}` (Wilma).
6. `Company.pay_wages(world, cid)` for every company, state ones included, from its own account (Bob).
7. The purse (Wilma): Colony Stores' takings from the landing stock to the treasury (memo `LANDING_STOCK_SALE`); what
   a state company could not pay of its wages; the benefit; pensions; one bill, shared when short. Then the sweep.

### COMPANY_AI
1. `Rules.month(world)` (Bob): signals once, price, output, hiring salary, hire and lay off.
2. Founding (the conductor runs the sequence; each call is its owner's). For each type that may be founded (step 3
   starts with FARM only) and each area:
   - `Rules.founding(world, type, area)` (Bob): which sizes pass rule 7 and 8;
   - `Building.founder_needs(world, type, size, area)` (Otto) and `Grants.quote(world, kind, area, founder)` (Ella);
   - `Households.pick_founder(world, area, money_needed, grant)` (Maja);
   - `Site.choose_country / choose_town` and `LandLaw.terms` (Terra, Anni): the plan knows its site and land cost;
   - `Households.make_founder` (Maja) -> person id;
   - `Building.make_plan(world, person_id, type, size, area, site, why)` (Otto): opens `plan:<id>`, moves the
     founder's money in from `person:N`, calls `Site.hold`;
   - `Grants.apply(world, plan_id)` (Ella): the grant into the plan's account. Before signing, so the money is there
     when a builder's quote is accepted. (Otto's note had it at signing; this is the one place.)
3. `Building.sign_round(world)` (Otto): each made plan re-reads `Rules.founding`; `LawCompany.may_sign`; quotes; the
   lowest total; if its account covers land + total: `Site.buy_land(world, plan_id, acct)` (Terra), which calls
   `LandLaw.sell` (Anni: the ONE deed that takes the money, memo `LAND_SALE`, and writes the title); the contract.
   A plan given up: `Building.give_up` calls `Site.release`, `Grants.reclaim`, `Households.release_founder`.
4. `Grants.monthly(world)` (Ella).

### SOCIAL
1. (population provider) births, deaths, growing up, retiring, the January band moves. **They come in step 3** (Maja's
   question; "the households fitted in").
2. `Households.labour_month` (Maja): the negotiation, quitting for better pay. `Households.yearly_raise_month` in
   January.
3. `econ_publish` (Ella), last.

## Settled where notes differed

| Question | Settled |
|---|---|
| Market call | Bob's `Market.order` and `Market.filled`. Bob adds `Market.offers(world, item, area)`, `Market.history`, `Market.last_settled_month` |
| Farm yield | Terra's `Site.yield_pm`. Food grows month by month with the season; there is no four-month wait and no harvest lump |
| Who takes the land money | `LandLaw.sell` only. `Site.buy_land` holds nothing of its own; it calls it. Land sales are capital for the budget figures (memo `LAND_SALE` into Ella's CAPITAL_MEMOS) |
| Land: sell or lease | The default becomes SELL (plan 12.1, 3). LEASE and KEEP stay a government's choice; a lease's rent is collected in JUSTICE, arrears at step 5 |
| Goods to a building site | The sale takes them out of the seller as SOLD; the sale row is the record; Otto books them on the site from `Market.filled`. The goods check counts what lies on sites |
| Colony Stores | An ordinary seller with `price_fixed` on its record (Bob adds the create option); the rules leave its price alone |
| State companies' wages | Each pays from its own account first; the purse pays the rest |
| The record's side of salaries | Bob: `Company.vacancies(world, area)`, `avg_pay`, `negotiate`, `raise_choice`, `chief`, `revenue_12`, `months_on_books`, `close_plant` / `reopen_plant` (with a reason and a row) |
| The yearly raise's minimum | A lever, `ECON_YEARLY_RAISE_MIN_PCT`, default 2, defined in econ_publish (Ella) |
| The press's wages | `Households.pay_income(world, from_acct, amount, area, kind)` (Maja), called through the doorway |
| An area's district | `LawQuery.districts` (Anni's, exists) |
| `EconFace.running()` | True once the market has settled at least once |
| Who founds | As plan 12, 60a to c. Where the plan is silent no band comes before another: among the households that can pay, a seeded draw. Maja says in her hand-over what the plan gave her and what she added |
| Reach | One place in step 3: the same area |

## What the order does to time (state it, do not tune it)

- A rule decides in COMPANY_AI and acts from the next month.
- Households spend what they hold; this month's wages are next month's money. Month one runs on savings.
- Inputs bought in SETTLEMENT are used in next month's PRODUCTION.
- A plan signed in month m buys its first supplies in SETTLEMENT m+1 and is worked from PRODUCTION m+2. A family farm
  signed in month 1 is done in month 5, opens in 6, hires in 6 and makes food from month 7.
- **Bob redoes the food check** with this timeline and Terra's month-by-month yield before the first game is run. If
  twelve months of landed food does not reach, that goes to the user with the figures; nobody changes a number.

## Facts, each published by the piece that does the deed (Ella's paper, section 4)

Maja: company planned; famine, food scarce, food unaffordable; homelessness; arrivals and leavers. Bob: company
founded, mass layoffs, shortage. Otto: plan abandoned, project completed or cancelled, contract awarded, payment
missed. Wilma: ship arrived, import arrived, reserve released, purse short. Ella: grant ended, programme ended.

## Order of building

1. Bob: `Market`, `Making`, `Rules` and the record's additions, because everything else calls them. He hands over the
   record's additions and the market first, on their own.
2. Maja, Otto, Terra, Anni, Ella build against the names above at the same time; where a function of Bob's is not in
   the tree yet, test against a stand-in of that name in your own test file.
3. Wilma: the conductor with every call in place from the start (a call to a function not yet in the tree is added
   when its piece is merged), the ship, the Stores and the rent.
4. Food alone: FARM, the Stores, the households. Short exact tests; then three 30-year games and the report.
