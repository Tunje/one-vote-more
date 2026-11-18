# The households in the rebuild: the full check of the old household side

**Maja, 2026-11-17. Version 1, not reviewed yet** (review partner: Terra; section 13 of rebuild-company.md).

This is the full check that rebuild-company.md section 9.1 asks for before build step 3. Two rulings from the user govern it:

- "we take how it works and transfer over not take the code"
- "Oh no wholesale does not mean unchecked"

I read the four old files in `game_full_copy/sim/economy/` line by line: econ_pop (740 lines), econ_households (892), econ_cohorts (581) and econ_informal (117). For every mechanism this file gives:

- what it did;
- a verdict: **keep** (write it new to work the same), **change**, or **leave out**;
- for keep and change, how it works in the rebuild.

The household parts that lived in other files are checked too: rent, benefits, pensions, dividends, food assistance and the staff costs. No code is written yet.

How to read it:

- An old number is named only to say what it did. **Every number is set new** (rebuild-company.md section 1).
- **(decided)** marks an open point with an obvious answer, which I decided as the order allows. Wilma or the user strikes any that is wrong.
- **(fork)** marks a real choice that goes to Wilma.

## 1. The rulings this file is bound by

1. **Pools stay,** one per housing block and income band, with one account (12.5, 35). Each pool also keeps a count per company its members work for.
2. **Founders and owners are counted individually,** from the day the plan is made (35, 60a). When they no longer own anything and their debts are settled, they go back to the pool (60c). "don't malt to many people to track"
3. **The self-employed become family-size service companies** (9.1, 36).
4. **No price floors or ceilings of ours** (section 6). Every number the old code read from the old data file is set new (36).
5. **Nothing from the home world except on a ship in port,** with the full round trip every time (9.6).
6. **A short household pays food, then rent, then water and power** (9.1).
7. **Stocking up:** a household may buy ahead when a price is under what the good is worth to it (9.3).
8. **Owning a home:** a household can buy the home it rents, or build a larger house of its own (9.8).
9. **Hunger is counted from need,** not from orders (23).
10. **Short of money is not the same as refusing the price** (23a). Every order carries the most its buyer will and can pay.
11. **Nothing behind an off switch.** Every old switch on this side (E111, E120, S7, BANDS, E88 and the others) is gone. What is kept is simply on.
12. **The log** (section 13): every decision and every move of people or money writes a Logbook row. A decision with no row is a fault. Section 6 below lists the rows this side writes.

## 2. The ground: areas instead of the six districts

**What the old code did.** Every pool was keyed `hb:d:1` to `hb:d:6`: one fake housing block per fixed district. Everything hung on that list: the age histograms, rent, occupancy, shacks, the service price, pollution and where settlers landed.

The area code (`game/sim/population/area_store.gd`) was a separate design. Areas are founded where homes are built; they extend, split and merge; law draws districts from them (`game/sim/law/districting.gd`, with a founding district called "The Colony"). The old economy never used it. It ran only in tests.

**In the rebuild (12.1, points 1 and 2):**

- The colony starts as one area, the Landing, at the landfall place, holding the landing shelters.
- A pool is keyed by area id and income band.
- Wherever the old code said "district", the household side says "area": a salary's area, a household's area, where ages are kept, occupancy, shacks.
- Law draws districts from areas, for elections only. Redrawing them moves no person, no money and no salary.

**Settled with Terra, 2026-11-17:**

- **Month one:** one area, the Landing, on the landfall tile, founded when a new game starts. Law's charter puts it in the one district "The Colony", so all seats are colony-wide.
- **What an area is made of:** town-grid street blocks (400 m) inside a town, plus country tiles for homes outside a town.
  - Terra's town grid is on from month one, and the landing gets its grid with its first house.
  - Block keys are fixed by geography: "b:bx,by", with bx = fx ÷ 4 and by = fy ÷ 4 in global 100 m cells. They never change.
  - A block belongs to exactly one area. When two areas meet in one block, the first one to build there owns it.
  - Terra holds the cells, keyed to a company's plant. AreaStore holds which blocks and tiles belong to which area.
- **When an area splits:** the old fixed headcount (800) goes.
  - An area splits when a part of it is farther than a school's reach from the rest: "a neighbourhood is what's within walking distance of its school" (Terra).
  - The cut runs along, strongest first: the river, a fast road, a main street, the lattice street nearest the middle. Terra measures the candidate cuts (TownGrid.boundaries); AreaStore chooses.
- **Where a home is recorded (decided, Maja, 2026-11-17):** once, in Terra's town-grid cell, keyed to the landlord company's plant (or to its owner, for an owned home). AreaStore keeps no home counts: an area's homes are the homes in its blocks (TownGrid.block_homes). The home counts AreaStore keeps on tiles today (place_housing's "units") go at step 2, and a 3 km tile stays only as the country address of an area outside a town. The split by reach is built on this at step 2, with the landing shelters. Reviewed by Terra, and by Otto for the homes.
- **Districts on the screens:** every screen reads law's districts (LQ.districts: id, name, areas) instead of the old six-district list.
- **Who builds it:**
  - Maja: the Landing at a new game, blocks in AreaStore, the split by reach.
  - Terra: the block functions, the cut lines, the screens.
  - Each reviews the other's code.

## 2a. Step 2 as built (Maja, 2026-11-17)

**Where things are kept.** Each thing has one record:

- **People** are in PopStore leaves, keyed by area and band.
- **Pools** are in their own table, `"pool"`: id "area|band", record {id, area, band, income}, account "pool:<id>". They are NOT in the old "hh" table. Wilma's ruling: the old readers of "hh" (press costs, party dues and campaign money, staff charges, the crime fallback, press demand) stay asleep until each is connected on purpose through the doorway, at its own step.
- **A pool's head counts** are read from the people, never stored.
- **Jobs** are in the company record: company["staff"][plant id or "crew"][post tier]["area|band|skill"] = persons × S. They are written only through Bob's Company.staff_change, by Households.hire and Households.layoff. Those two move the people and write the entry in one call.
- **A pool's count per company** is read through Company.staff_of_pool.

**Who fills a post (decided):** people of the post's own skill first, then a higher skill, never a lower one. Within a skill nobody goes first (12.3, 28): the posts are shared over the income bands in proportion to their jobless of that skill, with a largest remainder so a run repeats. (Corrected after Bob's month-one check. The first version took the lowest band first, so in month one the poorest band filled 135 of 135 posts and the richest none. That was an ordering of ours, not a rule.) The occupation is the company's (Company.occupation: PUBLIC_SECTOR for a state company, PROFESSIONAL for a specialist post, otherwise the type's).

**The starting numbers (accepted by Wilma):**

- 1,000 settlers in 400 households of 2.5, in the Landing.
- Each income band holds 80 households (200 people): 150 working-age (90% in the labour force), 44 children, 6 retired.
- Adults' skills by band, ‰ G / S / Sp: I1 1000/0/0, I2 900/100/0, I3 600/350/50, I4 300/500/200, I5 200/550/250. Over all bands that is 60 / 30 / 10.
- Working-age adults by age, ‰ Y / A / M: 350 / 450 / 200.
- Savings per household by band, from Bob's table: 1,800 / 3,600 / 7,200 / 14,400 / 36,000. They arrive from outside with the settlers ("LANDING_SAVINGS").
- Everyone of working age in the labour force lands looking for work. Month one's companies hire their crews from them: 180 for the builders and 40 for the public works department.
- Earners per household, for the salary formula, are adults in the labour force: 675 ÷ 400, about 1.7.

**Money in:**

- Households.pay_wages: once per company per month, its staff × the salary of their tier in the area they live in.
- Households.pay_support: the benefit to the UNEMPLOYED and the pension to the RETIRED, per person by area, at the government's levers.
- A payer short of money pays everyone the same share of what it holds. Nobody is laid off by a payment; that is the company's decision.
- Each pool books its income by kind for the month.

**A founder (Otto's 4.2; decided, used from step 3):**

- The founder is one adult of the pool: a skilled or specialist one first, otherwise the oldest working-age one.
- The unemployed and those outside the labour force are picked before the employed.
- ~~If the founder holds a post, they leave it through Households.layoff first~~ (Otto's review; built as a QUIT at making). Replaced 2026-11-18: an employed founder, and an employed adult of a family founder's household, keeps their post until the plan signs (Wilma: "a person whose plan is given up the same month, or never signed, has not lost their job"; nothing in 60a or 60c gives the job up at making; Terra's trace showed the builders' crews emptied by plans given up the same month). The founder record is made at making as 60a says. The ones still in post stay in PopStore in their pool, listed on the record as in_post, and the pool marks them so no second founder draws them. When the plan signs, the SOCIAL step gives up their posts (QUIT) and they become owners. A plan given up leaves them in their job untouched.
  - **(Maja's reading of 60c, with Wilma's yes)** Until the plan signs, a founder still in post eats and is paid with their pool, not from their own account. The founder's account holds the plan's money (the household's share of the savings) from making; a plan given up returns what is left.
- What goes with them is one household's share of the pool's savings: the pool's balance × 2.5 ÷ the pool's persons.

**Tenancy (shape agreed with Otto, built at step 7):**

- Who lives in whose homes is held once, in the landlord's company record: slots {plant: {pool id: households}}.
- It is written only by the household side, when a household takes or leaves a home.
- Taken homes can never exceed that plant's homes in Terra's cells.
- Rent goes from the pool to that landlord; a landlord's empty homes = its homes in the cells − taken.
- An area split changes the movers' pool ids, so it moves their tenancies in the same step.
- Until step 7 the housing office is the only landlord, and none of this is needed.

**The shelter plants (Otto's review):** a LANDLORD plant is at most one full unit, a block of 50 homes. So the 400 shelters are 8 plants of the housing office, one per 50-home block. That is Wilma's start-up and Bob's record. Otto has told them.

**The landing shelters:**

- They are one LANDLORD plant of the housing office, laid by Wilma's start-up on Terra's grid in HOUSE form: 400 homes, one per landing household.
- They are recorded only in Terra's cells. Terra claims the blocks for the Landing.
- Rent is the housing office's (Wilma: set low, half a new house's rent to start). The starting salary comes out of the formula from that rent.

**Areas split by reach:**

- The headcount rule is gone.
- In January, an area whose homes reach farther than a school's catchment (TownGrid.CATCH_KM["SCHOOL"]) from their homes-weighted centre is split.
- The cut is chosen from Terra's TownGrid.boundaries:
  - the strongest kind of boundary first;
  - then the cut that leaves both parts most compact;
  - only cuts that leave homes on both sides.
- The side with fewer homes leaves, and people follow the homes, band by band.
- An area's homes are the homes in its blocks (TownGrid.block_homes).
- Homes recorded on country tiles (place_housing) remain only as tests' and tools' way to make an area outside a town. No game code writes them.

## 2b. Step 3 as built (Maja, 2026-11-17)

The households' month is built against Wilma's joins (rebuild-step3-joins.md): buying, eating, rent, applying, quitting, the negotiation, the yearly raise, founders, life and ships. Its code is in `households.gd` and `demography.gd`.

**What the plan gave, and where the code follows it:**

- **The order of paying when short:** food, then rent, then water and power (9.1). Food comes first, so its order may use all of a household's money. The rent is paid from what is left. Water and power have no grid in step 3.
- **Every order carries the most its buyer will and can pay** (23a). The market's answer gives each order's shortfall one "why", and hunger is split the same way:
  - no money behind the order;
  - could pay something but refused the price;
  - none to be had.
- **Hunger is counted from need** (23).
- **Workers apply only to jobs that meet their needs** (9.2, the user). A worker's needs are a household's rent and food in the area (12.5, 38 as revised: no longer divided by earners). They are Bob's Rules.needs_line, the one figure his salary rule reads too. A hire below it finds nobody, and the log says why.
- **Quitting for better pay** (12.5, 39): an employed worker moves to an open post in reach that pays more, over a bar. The user's ruling, verbatim (plan 9.2): "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%". The question was how much more another post must pay before a worker moves (game/tools/tenure.gd had shown jobs lasting two to four months, about half of them ended by a move for any gain at all).
  - A worker moves only to a post paying at least their own pay × (1 + bar): `Households.quit_bar_pm`.
  - Wilma's readings: "up to 15%" caps the whole bar (10%, rising to 15% after five full years). "Less if stressful" waits for stress at step 9. Until then the bar starts at 10%, and `quit_bar_base_pm` is where stress will lower it, toward 5% at the highest stress.
  - The years count from the "since" month on each staff entry (Bob's company record), averaged by head count when people join an entry, as pay is. A move to another company starts the years again. A band move keeps them, since it is the same workplace.
  - Every JOB row carries the bar, the old pay and the new pay. A better-paid post NOT taken because the bar was not reached gets one STAY row per company a month, giving each entry's bar, old pay, the best pay offered, persons and years.
- **Layoff pay** (the user's ruling on keeping workers, rebuild-company.md 9.2; Wilma's details): each person laid off is owed `WorkLaw`'s LAW_LAYOFF_PAY_MONTHS (Anni's lever, 3) months of their own pay. The months are read as the law stands on the day of the layoff (Wilma). It is paid into the pool they go back to, booked as income "layoff_pay", from the company's account as far as it reaches. The rest is owed to that pool through Justice.owe (kind LAYOFF_PAY). When Anni's collector later pays it, it calls Households.debt_received, which books it as "layoff_pay" too. Quitting, a move for better pay, death, retiring and leaving the colony owe nothing. Those laid off are unemployed and draw the benefit (Wilma). The LAYOFF row carries what was owed, paid and left as a debt.
- **The family on its own family farm** (the user, 15e, with two corrections: "The owners of a family farm should take winnings no sallery…" and "the farm would be their home"):
  - The founder's household is the family. For a FAMILY-size company, make_founder takes the founder, one more adult for each adult a household of the pool has beyond one, and the pool's children per household. All are whole persons, with the fractions carried per pool.
  - All of them become BUSINESS_OWNER in PopStore. So no pool, hire or jobs = people check counts them, and band moves leave them alone.
  - Their adults fill the farm's posts by skill (family_work; Bob fills the posts from them first). They are then employed in the counts and on no payroll.
  - Their income is the farm's winnings, paid by Bob after everything else the farm owes, and booked on the founder as "winnings".
  - On their own opened farm they pay no rent and need no home in town (Wilma's Landing.lives_on_own_farm).
  - Deaths and children growing up fall on people; reconcile_families keeps the founders' records in step with them.
  - When the farm ends, the whole household goes back to the pool (60c).
- **A founder's debts are carried** (60c, Wilma's ruling of "settled or carried"): a founder who owns nothing goes back to the pool even with a debt still open, so the household is fed and can work. The law marks the debt carried (Anni's Justice.carry_debts). It stays OPEN against the founder's id, with a stub in table "founder_carried" (id, pool, owed). Nothing is collected from a pool for it: what the founder cannot pay goes to step 5's court (60b). Every founder who owns nothing is retried each month in SOCIAL.
- **Ship food less wanted** (the user, 15e; Wilma's decision on who it binds): a household whose food budget covers its whole need, costed in the order buyers rank the offers (ship food a quarter dearer), posts "RANK". One whose budget does not posts "PRICE" and takes the cheapest real price first, so nobody goes hungry beside unsold ship food (Households.food_by; Bob's Market.order `by`).
- **The negotiation** (9.2, the user): underpaid = below the company's average for the post. The worker negotiates first, and only if that fails do they look for better pay.
- **The yearly raise:** the company's choice, and at least the government's minimum (the lever ECON_YEARLY_RAISE_MIN_PCT).
- **Founders** are counted individually from the day the plan is made, take their household's share, and go back into the pool when they own nothing (12.5, 35; 60a–60c).
- **Life:**
  - births and deaths by age;
  - growing up and retiring at the law's age;
  - rejoining the labour force;
  - the January band moves.
  The age histogram per area is the authority on age (C1).
- **Ships:** settlers land and people leave only with a ship in port (9.6, 12.5, 42). Nobody arrives or leaves otherwise.

**What I added where the plan is silent** (each is marked in the code; strike any):

- **Founders:**
  - A founder is drawn by a seeded draw among the households of the area that can pay (one household's share + the grant its pool would get), weighted by how many such households each pool holds (Wilma: no band before another).
  - The adult who founds: the unemployed first, then those outside the labour force, then the employed; skilled and specialists first within each.
  - The founders' table is `"founder"` (ids "founder:N"), because "person" is the staff side's.
  - One grant per household (61) survives a founder going back (agreed with Ella):
    - each pool counts its households that have had a grant;
    - the draw picks a household, which can pay only from its share if it had a grant, or from its share + the grant if not;
    - the founder record carries "had_grant", and Ella's Grants.apply calls Households.mark_granted;
    - a returning founder who had one goes back as a granted household.
    It is exact in number: a pool never takes more grants than it has households without one. Which family it is cannot be remembered, since households are counts.
  - A founder's household is themselves: they eat and pay rent from their own account. Their family stays in the pool.
  - The founder takes ONE household's share of the pool's savings with them, though only one adult leaves; the partner and children stay in the pool (Bob's review). Plan 35 speaks of one person taken out; the money is a household's because the plan is the household's venture.
  - What a founder must be able to pay includes Otto's three months of opening money. My reading of "the founder's own reckoning" is that a founder simply won't plan without it, so in effect it narrows who may found. Bob's 9.2 shows it moves a family farm from band I3 to I4. Strike it if the reckoning was meant to be optional.
  - A founder who goes back returns to the status they came from: outside the labour force stays outside, anyone else looks for work.
- **Each order's money is its line's budget (Wilma's ruling, Bob's Market.order budget argument):**
  - A household sets its money aside line by line in the ruled order: food, rent, water and power, the rest. Each order carries its line's money as its budget, so no line can spend another's money, whatever order the market clears its books in.
  - The order is the real need at the real worth. Food comes first, so a unit of it is worth all the money set aside for food.
  - What the budget does not reach is a refusal of the price, which the sellers hear (23a). A pool with half the money for its food buys half its food.
  - In step 3 households post food only, so the food line is all their money and the rent is paid from what it leaves.
  - Watch item (Bob): with food's worth = the whole food budget, a food order never refuses through its price, only by running out of money. So the farms' prices are held up only by how much money households have. That fits food alone in step 3: a hungry household pays what it has. When bread and other foods come (step 4), food gets a worth per unit below the whole budget, so households can switch or eat less at a high price.
- **The food store (the user, rebuild-company 12.3, 15f; built by Maja with Bob, 2026-11-17):**
  - A household (a pool, a founder, a family on its farm) aims to hold six months of its food need (STORE_MONTHS).
  - Each month it buys its whole month's food (NEED). The store is for emergencies; it does not eat from the store instead of buying.
  - Then a second order, AHEAD, goes toward six months held, at most one month's need a month: double, never more (the user, 2026-11-18: "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT", meaning to even it out; first built without the limit). Its budget is the money left after the month's food (costed on this month's offers) and the rent (this month's plus what is owed). It pays any price it can. It asks only for what that budget buys at today's cheapest offer (Bob: rule 7 founds farms on orders posted). It posts none when nothing is on offer.
  - A farm family eats from its own farm first (the user, 2026-11-18, rebuild-company 12.3 15e: "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST, THEY ARE THREE THEY CAN PRODUVE 30 ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24"). Before any order, a founder whose family farm is open takes the month's need and the store's double from the farm's stock (Bob's Making.family_take: no money, never offered). The market orders are for what is still missing; the double holds over farm and market together.
  - Bob's Market clears every NEED order before any AHEAD order, so no household's store takes another's month's food. A store order's shortfall is no unmet demand or refusal for the sellers' rules and no work for rule 7 (Wilma's decision); what it buys is a sale like any other.
  - It eats what it bought this month first and the store only when that falls short. The store spoils like any food. It refills at once.
  - The store follows people as savings do: on a band move in proportion, and a founder takes its persons' part (per mouth).
  - On an area split or merge, the pools' savings and store follow the people moved (Terra's review). Before, a merge stranded both in the merged-away pool. One AREA row per move.
  - Log: one STORE row per buyer per month (months held, bought for the store, eaten from the store). The BUDGET row shows the FOOD, RENT and STORE lines.
  - This replaces the earlier two-month cap for households' food. Companies' inputs keep theirs (making.gd).- **The negotiation's terms:**
  - It happens once a year, in July. Wilma said "once a year"; the month is mine.
  - The manager meets the worker halfway to the average, when the company's account holds a year of the rise.
  - A refusal is a log row.
- **Who leaves on a ship:** a share of the unemployed young adults × how unattractive the colony looks, and every homeless household (none while the shelters hold everyone).
- **How attractive the colony looks:** jobs 40%, food 40%, homes 20%. The home world knows it as of the last ship's departure.
- **The numbers of life, all new:**
  - death chances by age without a clinic;
  - hunger's and crowding's weight on deaths;
  - births: 4.0 a woman at the lowest band, 40% fewer at the highest, × the share fed × room;
  - 90% of 18-year-olds look for work, all at the general tier (no schools yet);
  - 1% a month of those outside the labour force come back;
  - bands: the income average moves a sixth a month, and the margin past a cut is 10%.
- **The press's notices:** a famine is a quarter of the colony's food need uneaten three months running. Food scarce or unaffordable is a twentieth of the need for that reason.
- **Deaths and births are carried as one remainder per area,** then shared over the pools. Per pool, a small colony's fractions never reached one person (found in testing).

## 3. The check, mechanism by mechanism

### 3.1 econ_pop: pools, jobs and income bands

| # | Old mechanism (where) | What it did | Verdict | How it works in the rebuild |
|---|---|---|---|---|
| P1 | ids (`hb_of`, `pool_id`, `lab_key`) | a pool is housing block × band; a worker on a company's staff is filed under "block\|skill" | **change** | A pool is area × band. A staff entry is keyed area\|band\|skill **(decided)**: the old key had no band, so wages were spread over all bands by headcount, and "a count per company" could not be read exactly. With the band in the key, a company's `staff` is the one record of a job, and each pool's count per company is read from it (one record of each thing, 50b). |
| P2 | `person_occ` | the occupation follows from the post and the employer: specialists are PROFESSIONAL, public employers PUBLIC_SECTOR, builders' crews CONSTRUCTION, otherwise the type's occupation | **keep** | The occupation is a column of the type table (section 4). A state-owned company gives PUBLIC_SECTOR; a specialist post gives PROFESSIONAL. |
| P3 | `ensure_pools` | five pools per district made in advance, each with an account | **change** | A pool is made when its first person arrives in an area and band, with its account. An empty pool with no money is removed. |
| P4 | `sync` | the pool's head counts (labour force, outside the labour force, retired, children, owners, self-employed, jobs by occupation, skills) worked out from the people records | **keep, plus a count per company** | Same counts. **Field names kept** (`lf`, `nonpart`, `retired`, `children`, `owners`), because the doorway reads them (EconFace.households_persons, staff_ops). New: `emp_by_company`, read from the companies' staff. `self_emp` goes. `owners` counts the pool's members who are owners counted individually (P13), so persons() still covers everyone. |
| P5 | `people_by_lab` | the unemployed per area and skill: who can be hired | **keep** | It is the labour market's supply (9.2). Only people whose needs a post's salary meets apply (9.2, 38). |
| P6 | `hire` | the unemployed take posts, people already in that occupation first | **keep** | Plus **changing jobs** (12.5, 39, new code): an employed worker moves when a post within reach pays more after travel. That is a move from one staff entry to another, so the old company's post opens. |
| P7 | `layoff`, `remove_staff`, `release_all` | people lose their jobs and keep their occupation and skill; a closed plant releases everyone | **keep** | With the company record. A company that cannot pay its staff lays them off (19a). Each layoff writes a log row with the reason. |
| P8 | `casualties`, `_kill_staff`, `_kill_residents` | deaths from wildlife and storms: the plant's own workers first, then the outdoor workers, the jobless adults, other workers, children; a dead worker's post leaves the staff | **keep** | Keyed by area. "Outdoor" is a column of the type table. A road accident takes the workers on that road. |
| P9 | `_mismatch` | a log of jobs that did not match people | **change** | A Logbook row, plus a failing check in tests ("no worker in two jobs", section 13). |
| P10 | `worker_index`, `split_to_pools`, `credit_status` | income booked per people record by kind (wages, benefit, pension, dividend, self-employed earnings), so income bands can be worked out | **keep** | Wages land directly in the right pool (P1). Benefits and pensions are paid per person of the right status. The record per kind stays; it is what income bands are read from. "self" goes. |
| P11 | `recompose` | changes a record's ages or skills without moving people (growing up, retiring, training) | **keep** | Training on the job (12.11, 85) uses it. |
| P12 | `seed_founding` | founders spread over six districts by fixed weights; bands set by skill tier; savings per person by tier; one capital owner made for each private company that existed at the start | **change** | All settlers start in the Landing area (12.2, 10), in the landing shelters (12.2, 11). Bands are set by skill tier until the first band reclassification, because nobody has an income yet **(decided)**. Savings are set new. **No owner is seeded:** month one has no private colony company. The five builders are owned from the home world (9.12). Owners come from plans (P13). |
| P13 | `make_owner` | a company's owner was one person moved into the top band's pool, outside the labour force | **change** | On the day their plan is made, the founder leaves the pool and becomes a person of their own (35, 60a). That person keeps a people record (so they age, die and vote) and has their own account and household spending (60c). Grants, profit, the court and settlements act on them. They go back to the pool when they own nothing and owe nothing carried (60c). **(decided)** If an owner dies, the ownership passes to an heir from the same pool, who becomes the new individual. The other owners of a shared company keep their shares. |
| P14 | `allocations`, `employed_buckets`, `check` | jobs equal people: the employed people in the records equal the posts filled at companies | **keep** | It is the "no worker in two jobs" check (section 13), run in every test and game. |
| P15 | `realign` | when a workplace changes owner its staff's occupation can change (a factory taken over by the state becomes PUBLIC_SECTOR) | **keep** | In buy-outs (81) and the state buying or selling a plant (95). |
| P16 | `reclassify`, `adult_equivalents`, `_quantiles`, `_gini` | **income bands:** income per adult equivalent, averaged over months, half the person's own income and half the pool's; the colony's fifths set the bands; a margin stops people flipping between bands; a large jump in income is taken at once; moves happen in January; children and others follow their adults; savings follow people per head; the Gini coefficient is published | **keep** | Numbers set new. A band move also rewrites the movers' staff keys (P1) in the same step. **(decided)** A move's savings follow per head as before. Each move writes a log row. |
| P17 | `deprivation` | the share of people whose income is below their essentials and whose savings cover less than a set number of months | **keep** | A published figure, by area. |

### 3.2 econ_households: money, buying, homes, life, ships

| # | Old mechanism | What it did | Verdict | How it works in the rebuild |
|---|---|---|---|---|
| H1 | `persons`, `adults`, `households` | households = persons ÷ a fixed household size | **keep** | **(decided)** Households are still read from persons. The size is a number set new. It is how many homes a pool needs. |
| H2 | `population_by_district`, `units_by_district` | homes counted from the government's HOUSING plants (50 homes per block) | **change** | Homes are the landlord companies' homes plus owned homes (9.8), by area. |
| H3 | `disposable` | income = wages + benefit + pension + dividend + self-employed earnings | **change** | Self-employed earnings go: they are family companies, and their owners are individuals. Dividends go to the owner person, not to a pool. |
| H4 | `essentials_cost` | a month's need for food and the minimum of consumer goods at the market price, energy and water at the tariff levers, district rent, bus fares | **change** | The same list, each at the price its actual seller charges: the shop for food and goods, the utility's tariff (approved by the government, 49), the household's own landlord's rent, the transit company's fare. Needs per person are set new. |
| H5 | `social` (the order of the month) | consume, newspapers, services, bands, self-employment, food assistance, orders for next month, housing, shacks, demography, ships, pollution, famine, spending habit | **change** | The households come last in the month, after trade, production, settlement and the companies' rules (12.1, 7). Their order: eat what was delivered (H7); pay food, then rent, then water and power (H15); buy services and newspapers; post next month's orders; homes and shacks; ages, births and deaths; ships, when one is in port; bands in January. |
| H6 | `_food_aid` | the home world's free emergency rations after two months of hunger | **leave out** | Ruled out (12.11): nothing arrives that was not ordered with a ship. |
| H7 | `_consume` | needs set against what was delivered; unmet need per good; the colony's food shortfall; a split between food that was ordered but not delivered (scarce) and food never ordered (unaffordable); a shortage fact naming the biggest food buyers; goods used up | **keep** | Hunger is counted from need (23). The scarce/unaffordable split stays: it is the published face of 23a. The level at which the papers notice is a press threshold, not a limit on anyone; set new. Utilities served come from the grid (104). |
| H8 | `discretionary_budget`, `disc_habit` | spending beyond the essentials = a share of the surplus + a share of savings above a target; habit: keep spending a share of the usual budget, from savings, when income drops | **keep** | It is how households spend and save; numbers set new. **(decided)** The habit is the household spending its own savings, not a floor on any price or anyone else, so it stays. |
| H9 | `_buy_media` | newspaper copies bought per pool from the papers' demand, at a price tied to the reference wage, from the services budget | **change** | A newspaper is a company whose clients are its readers (48). Its price is its own, moved by the rules. What each pool wants to read stays the media side's (Anni, Ella). |
| H10 | `pay_media_wages` | a paper's costs paid as wages to the district's pools by headcount | **leave out** | A paper employs its staff like any company. |
| H11 | `_buy_services` | services budget: private clinic and school places first, then comfort services, then service hubs at one district price (+10% from a neighbouring district); the district price moved by supply against demand, clamped between a floor and a ceiling | **change** | A household is a client of the nearest service of the kind that it can pay for and that has a free place within reach (43). Every service company has its own price (rules 1, 2, 9). Clamps removed. The neighbour +10% becomes the travel cost (40). |
| H12 | `_self_employed_sales` | self-employed residents served what the hubs did not, paid household to household, with income tax | **leave out** | They are family-size service companies (36). |
| H13 | `_self_employment_flow` | the jobless with a savings cushion became self-employed while the local service price stood above 90% of a base price; below the benefit's earnings they quit; capped at a share of the labour force | **change** | The same choice is rule 7 for a household founder: a jobless person with savings plans a family-size service company when rule 7's signal says there is work. The 90% gate, the benefit gate and the cap all go: rules 7 and 8 decide, and the company ends by section 8.3. |
| H14 | `food_price_eff` | food budgeted at the market price + 10% freight + sales tax + the shop's margin | **leave out** | The household pays the shop's price, which already holds its freight and margin, plus the sales tax. |
| H15 | `_post_orders` | orders for next month: food first, water and power reserved, rent reserved last, minimum consumer goods, bakery goods preferred, discretionary consumer goods up to a cap per person by band, then durables; each order's limit was "three times the price" | **change** | **Order of paying:** food, then rent, then water and power, then the other essentials (ruling). **Each order carries the most the household will and can pay** (23a): what the good is worth to it, capped by its money, instead of "three times the price". **(decided)** The cap per person goes; a good's worth to a household falls the more of it the household already has. So people stop buying when the price is above the worth, and the same worth is what stocking up reads (9.3). The bakery preference is the households' (11, econ_staple). Durables stay (D2); quality and reputation are left out for now (12.12). |
| H16 | `_housing` | occupancy per district; the private rent moved every quarter (up when full, down when empty or in arrears), with a cap on rises (a lever) and a floor | **change** | Rent is the landlord company's: its own rent × the cell's value × condition (9.8), moved by the rules on empty homes. The floor goes. The cap on rises stays as the government's legal ceiling (64). Occupancy per area stays: shacks and deaths read it. |
| H17 | `_demography` (the two earlier models) | births and deaths by fixed rates; the second version by age group | **leave out** | Replaced by the age histograms (C1 to C10), as in the old game's last version. |
| H18 | `retirement_age` | the law's retirement-age lever, clamped 50 to 75 | **keep** | A lever (12.5, 41); its range is the law's. |
| H19 | `food_brake` | births and settlers cut by the food shortfall, down to a floor | **change** | Births fall with the share of the pool's food need that was met, with no floor of ours. Settlers decide on the colony's attractiveness, which includes food (C12). |
| H20 | `_whole` | flows worked in thousandths of a person, paid in whole persons, remainders carried | **keep** | |
| H21 | `_die`, `_grow_up`, `_reage` | deaths, growing up and retiring applied to the people records | **keep** | |
| H22 | `_ships` | a ship every 18 to 30 months; settlers and departures; trade unloaded; a conversion for old saves | **change** | The ship schedule is the port's (9.6, Bob). The households own arrivals and departures (12.5, 42). The old-save conversion goes (no saves). |
| H23 | `_ship_migrants` (the old quarterly model) | settlers every quarter, only while unemployment was under 10% | **leave out** | Ruled out (9.1). |
| H24 | `_pollution` | pollution per district from emissions, decaying, with spill from neighbours; facts at two levels | **change** | "The planet reads pollution by area" (section 7). The planet (Terra) owns it; households read it. **(decided)** Pollution raises deaths through the mortality schedule, numbers set new. The old code had no such link, so this is new; strike it if unwanted. |
| H25 | `_famine_check` | famine = a large shortfall for three months; "has been a famine" kept apart from "famine now"; blame published | **keep** | Numbers set new; blame per 73. |
| H26 | `food_buyers` | the companies that bought the most food are named in shortage facts | **keep** | Blame (73). |
| H27 | `land_migrants` | settlers landed: adults by skill, most in the labour force, some children, with savings from home | **change** | They land in the port's area, in free homes or else the shelters. Their savings arrive with them on the ship (allowed: a ship in port). Shares and amounts set new. |

### 3.3 econ_cohorts: ages, births, deaths, migration

| # | Old mechanism | What it did | Verdict | How it works in the rebuild |
|---|---|---|---|---|
| C1 | `histogram`, `_init_district`, `_spread` | an age histogram 0 to 99 per district is the authority on age; the people records hold only coarse age bands | **change** | **One histogram per area (decided).** When an area splits or merges, its histogram is split or joined in proportion to the people moved (AreaStore's change listeners). |
| C2 | `mortality`, `_deaths` | yearly death chance by age, worse with poor clinic access, crowding over a level, shacks and homelessness; elder care lowers it for the retired; famine adds | **keep** | Numbers set new. Clinic access is whether people are served by a clinic (44). Elder care is served by a care home (44). |
| C3 | `fert_shape`, `tfr`, `_births` | births from women 18 to 42 by an age schedule; fertility falls with income, schooling, density, crowding, shacks and hunger; clamped between a minimum and a maximum | **keep** | Numbers set new. **(decided)** No clamp: the formula is shaped so it cannot go below zero. |
| C4 | births into pools | births go into the area's pools by their working-age adults | **keep** | |
| C5 | `_age_year` | every January everyone is a year older; the cohort turning 18 and the cohort reaching retirement age queue their moves | **keep** | |
| C6 | `_pending_moves` (growing up) | over the year the 18-year-olds become adults; their skill tier is split by the district's school access; most join the labour force | **change** | A school sets the skill a child grows up with (44): children who were served by a school grow up at the higher tiers, the rest at the general tier. Shares set new. |
| C7 | `_pending_moves` (retiring) | the retirement cohort retires over the year, from outside the labour force, the unemployed and the employed (their posts open) | **keep** | Pensions follow (M3). |
| C8 | `retire_employed`, `_retire_from` | a retiring worker's post is released from the company's staff | **keep** | |
| C9 | `_reentry` | adults outside the labour force come back to it, faster when there are vacancies and when childcare frees parents | **keep** | Numbers set new; childcare per 44. |
| C10 | `_reconcile`, `_rescale` | once a year the histogram is rescaled to the people records | **change** | Arrivals add their ages and departures remove them on the day they happen, so the rescale becomes a check that must find nothing to correct. A difference is a fault in the log. |
| C11 | `pyramid` | the colony's age pyramid | **keep** | Published. |
| C12 | `attractiveness` | how good the colony looks to settlers: jobs, real wage growth, food, housing; much lower during a famine | **change** | The same parts, but as the home world knows them: from what the last ship carried home **(decided)**. Nothing else reaches the home world (9.6). |
| C13 | `ship_migration` | settlers = ship space × attractiveness × the immigration lever; they land in the least crowded district; the unemployed young leave on the ship, more when the colony looks bad; families without homes leave too | **keep** | Ship space is the port's (Bob). Settlers land as in H27. Departures as before; each departure releases its post (C8). Numbers set new. |
| C14 | `_homeless_leave` | homeless and shack families leave: workers quit first, then whole families; at most a quarter of a district's people | **change** | The quarter cap goes: the number of homeless and shack households already bounds it. |
| C15 | `slums`, `_slum_watch`, `_is_slum` | a slum: crowding above a level, or run-down homes with no spare room; a fact on entry | **keep** | Home condition from 9.8. Published per area. |
| C16 | `forecast` | the age pyramid, the last year's flows and the households forming, for the government's housing rule | **keep** | Published. Landlords' rule 7 and the government read it like anyone. |
| C17 | `_roll` (12-month counts) | births, deaths, arrivals and departures over the last 12 months | **keep** | Published; read by the forecast only, never as a limit. |

### 3.4 econ_informal: crowding, shacks, the homeless

| # | Old mechanism | What it did | Verdict | How it works in the rebuild |
|---|---|---|---|---|
| I1 | `OCC_CAP` | above 130% households per home nobody else squeezes in | **keep** | Ruled (36): it is how many fit in a home. Per area. |
| I2 | shacks | a share of unsheltered households build a shack each month; free land allows a set number of shacks per formal home; no shack while material costs three times its base; shacks are abandoned when homes free up | **change** | **(decided)** A shack is built by the household itself from material bought on the market at the market price. No material, or no money for it, means no shack; that replaces the "three times the base" rule. Shacks stand on free cells in the area (Terra's grid), not at a set number per home. How fast is household behaviour, set new. |
| I3 | shack fire | a chance per shack each month; a fire destroys part of the shacks; a fact | **keep** | Numbers set new. |
| I4 | homeless | those with neither a home nor a shack are homeless; a fact once a share is reached | **keep** | |
| I5 | `active` (the S7 switch) | the whole of this was opt-in | **leave out the switch** | On. |
| I6 | `summary` | shacks and homeless per district for the screens | **keep** | Per area. |

### 3.5 Household parts that lived in other files

| # | Old mechanism (file) | What it did | Verdict | How it works in the rebuild |
|---|---|---|---|---|
| M1 | `_rent` (econ_finance) | a pool paid the average district rent, split over the district's landlords by homes; unpaid rent became arrears | **change** | A pool pays its own landlords for the homes it lives in, in the order food, then rent. Unpaid rent is a debt to that landlord and ends in eviction under the existing law (55). An owned flat pays its upkeep fee to the landlord of the rest (9.8). |
| M2 | `_benefits` (econ_finance) | benefit = a rate × the general-tier wage for the short-term unemployed, half for the long-term (by a duration lever); a benefit floor at a share of essentials | **change** | Benefit and pension are lines on the purse, each a share of the area's starting salary (41). The duration and the floor are the government's levers (88), not ours. |
| M3 | pensions (econ_finance) | a rate × the general-tier wage per retired person | **change** | As M2. |
| M4 | `_food_assistance` (econ_finance) | the government topped up pools that could not buy their food | **keep as a lever** | Food assistance is a lever of the purse (88), paid only from money the government has. |
| M5 | dividends (econ_annual, _bizsvc, _comfort, _finance) | a company's profit paid into its owner's pool | **change** | Paid to the owner person or persons by share (51), once a year from what the company holds above its reserve. |
| M6 | `charge` (game/sim/staff/staff_ops.gd 124–147) | the cost of party and government staff paid to all pools by headcount, as income for unseen trainers and recruiters | **change** | A payment with no seller, against "ONE kind of thing that produces". It is paid to a company that sells that service (business services, or the party's own office staff). **(decided)** Until that company exists the cost goes to the treasury account, not to the pools. Owner: whoever builds the parties' side (Ella or Wilma). |

## 4. What the rebuild adds on this side that the old code did not have

| # | What (ruling) | How |
|---|---|---|
| N1 | Stocking up (9.3) | A household orders ahead when the price is under what the good is worth to it (H15), the further under the more, as far as its money and the goods' keeping allow. Food spoils, so little food is stocked. A stock-up order is a real order. |
| N2 | Buying the home (9.8) | A renting pool buys a home at its rent × the payback years. After that it pays upkeep and no rent. Owned homes are a count per block. |
| N3 | A larger house of one's own (9.8) | Households of the top band in a block whose income runs well above the block's move out a few at a time, into a family-size house built by a builder. |
| N4 | Changing jobs (39) | P6. |
| N5 | Reach (40) | Jobs and services are taken within travel reach of the home; pay is compared after travel time and fare. |
| N6 | Founders as persons (35, 60a, 60c) | P13. |
| N7 | Settlers know the colony only by ship (9.6) | C12. |
| N8 | Sickness (86) | Where clinic places are short, part of the labour force is too ill to work. They stay employed but do not work that month, and the company's output falls. Published. |

## 5. Forks for Wilma

None that is a design choice for the user. Two are flagged for anyone to strike:

- **H24:** pollution raising deaths is new. The old code had no such link.
- **H8:** spending from savings out of habit is kept, as the household's own behaviour. If "no floors" was meant to cover it too, it goes.

## 6. The log rows this side writes

Every row is written with `Logbook.note(world, kind, who, what, why, change)`:

- hire;
- layoff;
- changing jobs (JOB: bar, old and new pay), and staying because a better offer did not reach the bar (STAY, one row per company a month);
- retiring;
- growing up;
- birth and death, with cause (age, hunger, clinic, crowding, shack, homeless, wildlife, storm, accident);
- arrival and departure, with reason;
- band move;
- a founder taken out of a pool and put back;
- a home bought;
- a house built;
- a shack built, lost or abandoned;
- homelessness;
- an unpaid bill (food, rent, water and power), with what was owed and what was paid;
- a stock-up order, with the price and the worth it read;
- famine;
- a slum.

## 7. What this side needs from others

| From | What |
|---|---|
| Terra | the area scale and when an area splits (section 2); free cells for shacks; cell values and reach distances |
| Bob | the market's orders, with the most each buyer will and can pay (23a); the labour market's posts and salaries (9.2); the ship schedule and ship space (9.6) |
| Otto | landlords' homes and rents per home; home sales and own houses (9.8) |
| Ella / Anni | what each pool wants to read (newspaper demand); the eviction law; the immigration lever |
| Wilma | the doorway fields kept (P4); the purse lines for benefit, pension and food assistance |

## 8. The old data numbers this side read (all set new)

From the old data file:

- the needs per person;
- the household size;
- the founding labour force, working-age, retired and children counts;
- savings per person by tier, and the owner's savings;
- migrant funds;
- the share of spending on consumer goods, the propensity to spend, spending from excess savings, the savings target in months, the habit share, the per-person consumer cap and its band multipliers;
- the base service price, the price floor and ceiling multipliers, the price-adjustment speed;
- the self-employed's output, entry, exit and maximum share;
- the retirement age and life expectancy;
- child and adult mortality, famine mortality, the birth rate;
- the food brake level and floor;
- the private rent, the rent-arrears cut;
- ship capacity, ship migrants, the ship quota share.

The ones the rebuild still needs are set new with the other numbers. The floors, ceilings, caps and gates among them are gone.

From the code itself, also set new:

- in econ_cohorts: the fertility schedule and its bounds, the mortality schedule, the re-entry rates, the slum level, the shack and homeless effects, ship passengers, the emigration shares;
- in econ_informal: the 130% limit (kept as a fact; its value set new), the shack rate, land, decay and fire numbers.
