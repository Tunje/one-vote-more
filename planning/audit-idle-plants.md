# Audit: plants that run below capacity while what they make is short (2026-11-15)

User: "Check every company type and its facilities for this type of error" (after the MATERIAL finding).
Tool: game/tools/audit_idle_plants.gd. v10 defaults, seeds 1-3, 30 years, every plant sampled twice a year from year 5.
Input for Bob's eight-rules table (planning, in progress).

Columns: plant-samples (and mothballed samples) · output target % of capacity · how hard they actually ran % · crew %
of the recipe's full crew · share of samples with the target at or under 30% · share of demand unmet (goods: unfilled
market orders; clinics and schools: 100 - access; power and water: households not served) · share of samples with more
than 5% unmet · share of samples both under 60% and short · price / the plant type's unit cost · seeds flagged (ran
under 60% on average while short in a third of samples or more).

| Owner | Plant | Makes | Samples | Mothballed | Target | Ran | Crew | Low target | Unmet | Short >5% | Idle and short | Price/cost | Flagged seeds |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Public institution | CLINIC | health | 685 | 0 | 49 | 35 | 33 | 0 | 37 | 64 | 63 | - | 3 of 3 |
| Public institution | SCHOOL | education | 502 | 0 | 64 | 53 | 45 | 0 | 41 | 86 | 73 | - | 2 |
| Public enterprise | PROCESSING | MATERIAL | 834 | 0 | 63 | 55 | 51 | 20 | 18 | 40 | 26 | 0.91 | 2 |
| Public enterprise | BAKERY | bread | 75 | 0 | 94 | 30 | 77 | 3 | 46 | 55 | 45 | 3.33 | 2 |
| Co-operative | FURNITURE | furnishings | 9 | 68 | 74 | 8 | 50 | 33 | 85 | 100 | 100 | 4.02 | 2 |
| Public enterprise | COMPONENTS | COMPONENT | 560 | 0 | 52 | 46 | 41 | 29 | 13 | 25 | 21 | 1.10 | 1 |
| Public enterprise | CONSUMERF | CONSUMER | 237 | 0 | 66 | 58 | 51 | 31 | 24 | 61 | 38 | 3.45 | 1 |
| Private | FURNITURE | furnishings | 20 | 2 | 79 | 51 | 57 | 10 | 31 | 54 | 40 | 5.02 | 1 |
| Co-operative | BAKERY | bread | 4 | 191 | 100 | 0 | 80 | 0 | 50 | 50 | 50 | 2.39 | 1 |
| Private | BAKERY | bread | 13 | 4 | 100 | 67 | 69 | 0 | 10 | 18 | 9 | 3.19 | 0 |
| Public enterprise | MEDWORKS | MEDICAL | 237 | 0 | 75 | 69 | 56 | 9 | 9 | 18 | 10 | 1.44 | 0 |
| Public enterprise | MINE | MINERAL | 350 | 0 | 90 | 85 | 69 | 6 | 5 | 12 | 1 | 0.34 | 0 |
| Public enterprise | FARM | FOOD | 2436 | 0 | 89 | 86 | 75 | 0 | 2 | 15 | 0 | 1.31 | 0 |
| Private | FARM | FOOD | 206 | 10 | 89 | 76 | 64 | 0 | 0 | 2 | 0 | 1.75 | 0 |
| Co-operative | FARM | FOOD | 36 | 0 | 89 | 64 | 67 | 0 | 3 | 25 | 8 | 1.34 | 0 |
| Private | SERVICEHUB | services | 762 | 620 | 61 | 36 | 50 | 20 | sold out 1% | 0 | 0 | - | 0 |
| Co-operative | SERVICEHUB | services | 887 | 835 | 69 | 45 | 61 | 19 | sold out 1% | 2 | 0 | - | 0 |
| Public enterprise | POWER | ENERGY | 774 | 0 | 73 | 72 | 58 | 0 | 0 | 0 | 0 | - | 0 |
| Public enterprise | WATERWORKS | WATER | 894 | 0 | 72 | 72 | 63 | 0 | 0 | 1 | 1 | - | 0 |
| Public institution | ADMIN | administration | 150 | 0 | 59 | 56 | 33 | 11 | - | - | - | - | 0 |

Running at or near full with no measure of unmet demand here: HOUSING (all owners), DEPOT (freight), TRANSIT, WAREHOUSE,
CHILDCARE, ELDERCARE, POLICE_STATION, PUBJOBS. OFFICE rows are support posts, not producers (private and co-op offices
are mostly mothballed samples: 1,681 and 2,368).

## What stands out
1. **Clinics and schools** are the worst case and the clearest: they run at a third to a half with crews at 33-45%,
   while 37-41% of the need goes unmet, in every seed. Their output target is the budget ratio (CLINIC, SCHOOL: T =
   budget / cost), so the "produce more" rule is a government budget decision that nothing ties to unmet need.
2. **MATERIAL, COMPONENT and CONSUMER goods plants** (all public enterprise) run at 46-58% while their goods are short
   in 25-61% of samples. Bob's freight finding explains MATERIAL (stock that can't be shipped); the same check is
   needed for COMPONENT and CONSUMER. CONSUMER sells at 3.45x cost and still isn't made at capacity.
3. **Bakeries and furniture workshops** barely run (0-67%) while their goods are short half the time or more, at prices
   2.4-5x cost. Co-op bakeries and furniture workshops are almost all mothballed (191 and 68 samples against 4 and 9
   running). Inputs (flour, materials) and freight are the suspects; price is no obstacle.
4. **Service hubs**: half of all samples are mothballed, the running ones at 36-45%, yet they were sold out in only 1%
   of samples: here it looks like too little demand reaching them (or prices too high), the opposite fault.
5. **Mines** sell at a third of cost (0.34) while running at 85%: no rule lowers output or raises the price when the
   ore isn't wanted (rules 1 and 4).
6. **Farms** are the healthy case: 64-86%, short in few samples, price 1.3-1.75x cost.
7. **Housing, freight depot, transit, warehouse, care, police** run full, but this audit has no unmet-demand measure for
   them; the freight depot at 100% with trade deferred is exactly Bob's jam and needs its own measure (E172).
