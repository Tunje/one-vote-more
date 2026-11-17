# Rebuild step 2: month one and the company. Who builds what

Wilma, 2026-11-17. Step 1 is committed (72733eb): the game runs with no economy, the colony starts as one place (the
Landing), the town grid and road systems are on, the log exists, 387 tests pass.

## Decisions on what you raised (Wilma's, for the user to strike)

- **Land** (Anni): its price and who holds it are needed in the first loop, so plain land (the colony owns it, a plan
  buys it at the price of its cells) is in step 3; sales between owners stay at step 6.
- **Three levers changed by "no law may forbid a private company type"** (Anni): accepted as she wrote them.
- **The yearly bonus** (Anni): the company's choice; when it gives one it is at least the government's minimum.
- **Trucks in the landing stock** (Otto): yes, trucks are equipment. Enough for the first truck drivers.
- **Three months of running costs as a founder's own opening money** (Otto): accepted as the founder's own reckoning,
  not a gate.
- **"Five years' worth of equipment"** (Bob): his reading, five years of the five builders' full work, is the starting
  figure for the landing stock of material and components.
- **Shops** (Bob): a shop sells goods to the households within its reach; its client intake is its limit.
- **Farms need no power or water at the start** (Bob): accepted, so the first food can grow before a power plant.
- **The shelter rent** (Bob, Otto): taken from the salary formula; the salary line drifts as houses replace shelters.
- **A home is recorded once,** in the town grid's cell (Maja): accepted. AreaStore keeps no home counts.
- **Pollution raising deaths** (Maja's H24, new): kept, flagged for the user.
- **What politics reads** (Ella): her list and her decisions are accepted, including: the stand-in's levers and
  indicators stay whole for voters until step 11; the grant levers start open; unions have no leader and no federation.
- **The 180 builder crew** among the founding settlers (Otto): Maja puts them in the settlers.

## Step 2, piece by piece

Every piece: code in your own scratch copy, written against the plan and the papers; a row in the Logbook for every
decision and deed (`Logbook.note`, see `game/sim/core/logbook.gd`); nothing behind a switch; no old code copied; short
exact tests. Your partner reads the code and answers in writing; you hand it to Wilma with the review, your answers
and the merge guard (the shared file still equals the copy you worked from). Wilma runs the whole suite and commits.

| Piece | Builds | Reviews |
|---|---|---|
| The company record and the type table as code: `game/sim/economy/company.gd`, `type_table.gd`; the four sizes; the items and starting prices from rebuild-type-table.md | Bob | Otto |
| The five home-world builders, existing and operating, with their crews; the public works department | Otto | Bob |
| The settlers, the household pools (as rebuild-households.md, written new), the landing shelters as homes on the town grid | Maja | Terra, and Otto for the homes |
| Where a plant stands: land owned by the colony, a plant on cells or tiles, siting for a new plant; the plain map showing plants | Terra | Maja, and Anni for land |
| The landing stock held by the government and sold at the starting prices; the government's subsidiaries as companies; the purse paying its staff, the benefit and pensions; every account in the ledger | Wilma | Bob, and Ella for the purse |
| The law's records keyed by company id; the land title | Anni | Ella |
| The names step 2 must publish for politics (from rebuild-politics-face.md), and the doorway functions step 2 fills | Ella | Anni |

When all pieces are in: the month-one check with the real numbers (Bob), then the step-2 report, then step 3.
