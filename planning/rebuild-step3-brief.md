# Rebuild step 3: the first loop, whole. Who builds what

Wilma, 2026-11-17. Step 2 is committed (3f1a7c0, report in [rebuild-step2-report.md](rebuild-step2-report.md)):
479 tests pass; month one adds up with the game's own numbers.

## What step 3 is (plan section 13)

"The first loop, whole. The households fitted in; hiring and salaries; the market with the price rules (1, 2, 9,
hold-back) and output rules (3, 4); the plan, the building contract and the opening of a plant in their plainest
form, with rules 7 and 8 and the four grants (they are open from month one); the ship schedule with arrivals,
departures and orders to the home world; seasons and farm yield. Tested first on food alone."

It is the first loop on one place, paid from savings and the purse. The bank does not lend (step 5), goods need no
trucks (step 4), companies do not grow or close idle plants (step 6). Nothing seen that comes from one of those missing
parts is a reason to change a number.

## The order of the month (the one rule every piece follows)

| Phase | What happens there | Whose |
|---|---|---|
| TRADE | A ship in port: what was ordered arrives and is paid; this month's orders and requests go aboard; it leaves | Wilma |
| PRODUCTION | Each company makes its output from its staff and inputs (seasons and yield for farms); builders put their work on their contracts; a finished plant opens the month after | Bob (making), Otto (building), Terra (yield) |
| SETTLEMENT | The market: households and companies buy, sales are paid; rent; every company pays its own wages; then the purse's bill (state companies that cannot pay their own wages, the benefit, pensions) and the sweep | Bob (market), Maja (what households buy, in which order), Wilma (purse) |
| COMPANY_AI | Each company works out its signals once and the rules act: price (1, 2, 9, hold-back), output (3, 4), hiring salary, hire and lay off to its output; founders read rule 7 and 8 and make plans; a plan asks builders for quotes and signs | Bob (rules), Otto (plan to contract), Maja (who founds) |
| SOCIAL | Households: applying, quitting for better pay, the yearly raise in its month; indicators final | Maja, Ella |

A rule decides in COMPANY_AI from what happened this month and acts from next month. Nothing decides twice in a month.

## Step 3, piece by piece

Same rules as step 2: your own scratch copy from HEAD; every decision and deed a Logbook row with the numbers it read;
nothing behind a switch; no old code copied; short exact tests to the last credit and unit (one sale, one hire, one
plan signed and built); "nothing appears or vanishes" checked in every test; your partner reads the code itself and
answers in writing; hand-over to Wilma with review, answers and merge guard.

| Piece | Builds | Reviews |
|---|---|---|
| The market: an order, a sale, an unfilled order with why (short of money or refusing the price, 23a); each company's month of making; its signals; price rules 1, 2, 9 and the hold-back; output rules 3 and 4 (15b); the hiring salary by the price rules; rule 7's and 8's signal (15a); a company paying its own wages; stocking up when the price is low against what it is worth to the buyer | Bob | Otto, and Maja for the buying side |
| The households' month: what a pool buys and in which order when short (food, rent, then water and power); applying only to jobs that meet their needs; quitting for better pay; hiring spread over pools; the yearly raise applied; who founds a company and with what money, owners counted individually (35, 60a to c) | Maja | Terra, and Bob for founders' money |
| The plan, the contract and the opening in their plainest form: a plan with its site and its cost; quotes from the builders; one contract with one builder; material bought from the Stores; work month by month; the opening; builders hiring to their books and paying their crews | Otto | Bob |
| A plan's site held and opened, the colony selling the land under it; seasons and farm yield from the planet | Terra | Maja, and Anni for land |
| The land title passing on a sale; what the law requires of a new company in its plainest form; the law's accounts by CoreUtil's constants | Anni | Ella |
| The four grants (family farm, family bakery, truck driver, truck workshop), paid from the treasury to a plan; what politics reads at step 3 and the doorway functions it fills; the press's wages connected with the pools; EconFace.running() | Ella | Anni |
| The ship: schedule, arrival, departure, orders to the home world and their payment, only ever on a ship in port, the full round trip every time; the Stores selling the landing stock and paying the treasury (memo LANDING_STOCK_SALE), the shelter rent; the purse paying only what state companies cannot; the order of the month in code; putting it together | Wilma | Bob, and Terra for the port |

## Before any code: the joins

Each piece calls the others. So first, each of you sends Wilma a short note (no code): the functions your piece
OFFERS (name, arguments, what it returns, which phase calls it) and the functions it NEEDS from the others. Wilma puts
them together as `planning/rebuild-step3-joins.md`, settles any that do not meet, and then you build against it.
Food alone first: the first tests and the first three 30-year games run with FARM, the Stores and the households;
every other type is in the table but nobody may found it until food passes.

## Carried over from the reviews

- The benefit follows the area's own salary line once areas have one (Bob).
- Negotiating a salary with the manager (the user, plan 9.2): step 3 builds the record's side (average pay per tier,
  the negotiated rise, a chief); the negotiation itself runs with quitting, in the households' month.
- The office screen's "does a person govern" must answer for real once the economy's state exists (Maja).
- Sixteen months of treasury with the grants, no taxes until step 8: reported, not tuned.
