# Rebuild step 2: month one and the company

Wilma, 2026-11-17. Commits 9f74dbc to c69d85d.

## What is on for good now

| Piece | Built by | Read by |
|---|---|---|
| The company record and the type table (30 types, 13 items, four sizes, a salary set on hire) | Bob | Otto |
| Where a plant stands, the land under it, the plain map showing plants | Terra | Maja, Anni |
| The settlers (1,000 in 400 households, five income bands), the household pools, hiring, wages and support | Maja | Terra, Otto |
| The five home-world builders and the public works department, with crews | Otto | Bob |
| The law's records by company, land titles | Anni | Ella |
| What politics reads of the purse; politics' own memory of grants; the landing treasury as capital | Ella | Anni |
| The treasury, the state's companies, the landing shelters, the landing stock, the purse's monthly bill | Wilma | Bob, Ella |

Every piece was read by another session and every point answered before it was committed. Everything is on; nothing
sits behind a switch.

## Does it add up

- Every script compiles (146). **479 tests pass, 0 fail.** A 20-year game runs with no script error.
- Money: every credit in the game came in through a named ledger entry (the settlers' savings, the treasury, the
  builders' capital). The purse's tests check that paying moves money and makes none.
- Goods: the only goods in the colony are the landing stock, taken in from the one allowed source, LANDING.
- People: a job is recorded once. The household side's own check is clean in a new game.
- Bob's month-one check with the game's own numbers ([rebuild-step2-month-one.md](rebuild-step2-month-one.md)): the
  game lands with exactly what the paper assumed, and the paper's four questions answer the same. 240 households can
  afford to found a family farm against 41 needed; trucks are within reach; 594 people are available for the 547
  builder crew the farm wave needs; twelve months of food lasts past the first harvest.

## What the game shows already (results, not faults)

1. **The treasury runs dry at month 24.** It pays out about 83,000 a month (state wages, the benefit for 414 jobless,
   pensions) and has no income: taxes come at step 8. With step 3's grants it will be about month 14. From then on
   every line of the bill is paid short in the same proportion, and a public fact says so. The fact carries no weight
   with voters until step 8 (Ella), so a government is not punished for a part that is not built.
2. **Politics moved the benefit** from 40% to 56% on its own during the test game. The lever is live.
3. **The five builders' crews are paid by nobody** in step 2: employed, so no benefit, and living on savings. From
   step 3 a builder pays its own crew. Their capital (three months of wages) sits untouched until then.
4. **Nobody eats.** There is no market until step 3, so households' savings rise by exactly what the treasury pays.
5. **State companies' income** (stock sales, shelter rent) will collect in their own accounts while the treasury pays
   their wages. Step 3 decides who pays whom.

## Found by the reviews and fixed

| Found by | What | Done |
|---|---|---|
| Ella | A short treasury paid wages first, and state companies in id order: priorities nobody ruled | One bill, every line the same share |
| Ella | Nothing in the game opened the fines account, so a fine was never collected, only owed | Opened at landing; swept into the treasury monthly (Anni checked the law) |
| Ella, Anni | The opening treasury counted as income, so the budget read +100% for a year | It is capital; the figures leave it out |
| Bob | Wages paid and the wage bill were summed in different orders | The same sum |
| Bob | Hiring took people pool by pool in id order: the poorest band fully employed, the richest not at all | Maja is changing it to spread a hire in proportion over the pools that have people looking (in review) |

## Starting numbers that are ours (plan 12.1, 8), to adjust from reports

Treasury 2,000,000. Twenty trucks in the landing stock. Each home-world builder lands with three months of its wage
bill. The administration is a full one (15 posts). Benefit 40% and pension 35% of the general salary of 300.

## For step 3 to remember

- The press's wages must be connected together with the household pools (Ella, step 1).
- The office screen's "does a person govern" must answer for real once the economy's state exists (Maja, step 1).
- The benefit follows the area's own salary line once areas have one: 300 at landing, 373 when houses replace
  shelters (Bob).
- Selling the landing stock is the sale of an asset: its own ledger memo, counted as capital (Anni, Ella).
- How far output moves in a month under rules 3 and 4 is Bob's proposal in the plan (12.3, 15b).
- Negotiating a salary with the manager (the user's ruling, plan 9.2): the record needs the company's average pay per
  tier, a writer for a negotiated rise, and a chief (Bob).
- The bank's loans to the purse must count as capital, not income (step 5; Ella's paper, section 6).
