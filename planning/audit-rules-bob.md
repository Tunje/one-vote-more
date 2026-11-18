# Audit of the rules against the code (Bob, 2026-11-18)

Wilma's order, after the user: "STOP JUST STOP GO BACK AND LOOK AT THE FUCKING RULES". No fixes and no proposals here:
only what the rules say and what the code does.

- **Code:** the shared tree as committed after Otto's advert piece (rules.gd d2ddf83f, company.gd 6e54dcfc, making.gd
  a0855ac0, market.gd c9954c64, building.gd, households.gd, landing.gd, type_table.gd), read today. My uncommitted
  copies (t52/t54: rule 8, the first-year average, rule 7's cost, rule 4) are NOT in it, and are not counted as built.
- **Paper:** rebuild-company.md sections 3–6, 9.2, 12.3 points 14–29 with 15a–15f, and the type table's numbers.

**Status:**
- **SAME:** the code does what the words say.
- **DIFFERENT:** it does not. Where the reason is that the plan itself puts the part in a later step, it says so ("not
  built, step N"); it is still DIFFERENT today.

## A. Lines that carry the user's words

| # | Where | The user's words (short) | What the code does today | Status | If different, what exactly |
|---|---|---|---|---|---|
| 1 | §3 price | "No i said each COMPANY" (one price per company per thing it sells) | `Company.price(world, cid, item)`, one entry per company and item | SAME | |
| 2 | §4 | "it's just a 2d array of wich items a company type makes" | TypeTable.ROWS: per type, `lines` (out, qty, in, lab), `way`, bill | SAME | |
| 3 | §4 | "if they pick from first or second output" (rule 3 picks by which pays) | Types have 1–2 `lines`; a company's `line` is set at creation and never changes. No rule picks or switches. | DIFFERENT | No second-output choice is built (also 12.3 24). |
| 4 | §4 | "things can be done in two different ways based in company types" | `TypeTable.way(type)`: sells / reads / price / reach per type | SAME | |
| 5 | §4 | "services have no output but a client take in" | Service rows have `@<type>` outputs, but no client intake runs | DIFFERENT | Not built (step 4 by plan). |
| 6 | §4 | "per pupil plus staff is how taxes for schools are calibrated" | Nothing | DIFFERENT | Not built (step 4). |
| 7 | §4 | "noise polution should also drive down price of housing" | Nothing reads noise into rent | DIFFERENT | Not built. |
| 8 | §5 | sizes 1/6, 1/3, 2/3, full; "a small penalty for their smaller size"; penalties "You penalty is fine" (6/4/2/0%) | `SIXTHS` 1/2/4/6; `PENALTY_PM` 60/40/20/0; `output_milli` = qty × sixths/6 × (1 − penalty) | SAME | |
| 9 | §5 | growing: "in a square if there are other companies they would have to buy out ... or build a new" | Nothing grows a company | DIFFERENT | Rule 5 is not built (step 6 by plan). |
| 10 | §6 r1 | raise the price: sold what it offered and orders went unfilled | `price_rule`: up = 5% × unmet_above/(unmet_above + sold); unmet_above = orders at or above the price left for SOLD_OUT | SAME | |
| 11 | §6 r2 | "the more inventory you have, the more you reduce your price" | down = 5% × unsold/(unsold + sold) | SAME | |
| 12 | §6 r3 | "if you sell out all your producing produce MORE" | `output_rule`: up = 5% × unmet/(unmet + sold), not while holding back | SAME | |
| 13 | §6 r3 | "Also picks first or second output" | Not built | DIFFERENT | As 3. |
| 14 | §6 r4 | "only lowered if over 50% of offered goods is not sold 3 months in a row" | `output_rule`: down = 5% × unsold/(unsold + sold) in ANY month with anything unsold, together with rule 2 | DIFFERENT | No 50% test and no 3-month run: it cuts every month with unsold goods. |
| 15 | §6 r4 | "A CUT IS 5%" | cut = 5% × unsold/(unsold + sold), below 5% unless nothing sold | DIFFERENT | The cut is the step formula, not the whole 5%. |
| 16 | §6 r4 | "IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | No run is counted | DIFFERENT | As 14. |
| 17 | §6 r5 | "if your selling out and all plants at max build a new one ... money is a limitor" | Nothing | DIFFERENT | Not built (step 6). |
| 18 | §6 r6 | a plant idle for a set time; "A hard rule here is fine" | Nothing | DIFFERENT | Not built (step 6). |
| 19 | §6 r7 | "instead of reading the leftovers, they read an avrage of all avaliable jobs" | `Rules.work`: all orders (NEED and AHEAD) for the item in the area, averaged over the months on record (up to 12), × today's price | SAME on "all orders, not leftovers" | The averaging is in row B3. |
| 20 | §6 r7 | "No cap on how many may form" | No cap in `founding` or in the founding sequence | SAME | |
| 21 | §6 r8 | do not start one when "the same signal says the work is covered" | `founding`: nothing compares the work with what the plants seen make or deliver; only the share test (`share >= cost`) decides | DIFFERENT | Rule 8 is not built in the shared tree. |
| 22 | §6 r9 | "if below making price climbing allways had priority if above lowering has priority if both signals come in the same month only the one with priority happens" | `price_rule`: both > 0 → R1 if price < making, else R2; one signal alone acts | SAME | |
| 23 | §6 r9 / §6 | "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"; "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | K_PM 50 for up and down; most a month is 5% | SAME | |
| 24 | §6 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" (output at most 5%) | G_PM 50, up and down; a rise below one post's share of full is on that share and at least 1 per mille (15b reading, Wilma's yes) | SAME | |
| 25 | §6 | "If something else than price stops sales it should not count on adjusting price!!" | Step 3 has no freight or roads; `Market` keeps NO_MONEY out of the signals; inputs missing lower what is made and offered, not a price signal | SAME (step 3) | |
| 26 | §6 | "Ignore the stoch in that other place too" / "It sells too cover all monthly expences" (held-back stock is no signal) | `hold_back`: below making price it offers what covers wage bill + inputs + upkeep; `Market.offers` subtracts the hold | SAME | |
| 27 | §9.2 | "the three rules for price should be applied here too" (salaries) | Replaced by the user's offer rule (row 35) | SAME (as replaced) | |
| 28 | §9.2 | "the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | Each hire row keeps its pay; `Company.yearly_raise` once a year from `Households.yearly_raise_month` | SAME | |
| 29 | §9.2 | yearly bonus: "what the minimum of this is is up to the government, 2% is a good start" | lever ECON_YEARLY_RAISE_MIN_PCT, default 2; given = max(company's choice, minimum) | SAME | |
| 30 | §9.2 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | `quit_bar_pm`: 10% + 1%/year at the workplace, capped at 15%; stress not read (every job "good") | DIFFERENT (part) | "less if stressful" is not built (stress is step 9 by plan); the rest is the same. |
| 31 | §9.2 | "underpayed workers go to the union, they can quit if they think they can get better prices if not they may unionise" | Quitting for pay is built; nothing sends an underpaid worker to a union | DIFFERENT (part) | Unions not built (step 9). |
| 32 | §9.2 | "avrage ask salleries in the company and underpayed is based on that line, that way both old and new can become underpayed" | `_negotiate` uses `Company.avg_pay(world, cid, tier)`: the average of the same post tier only | DIFFERENT | The user's line is the company's average. Built is per tier, from our proposal (B11). |
| 33 | §9.2 | "costs of hiring ... maybe 6 months training ... payment after fire ... three months of vages" and "i belive you have the right of it, and it should apply to builders" | layoff pay = WorkLaw.layoff_pay_months (law, 3); advert = 10% of a month's pay (ADVERT_PM 100) to the papers; `trained_pm(a)` = 500 + 500 × a/6, full from 6 (TRAIN_MONTHS 6); builders the same | SAME | |
| 34 | §9.2 | "On posts when you many an open post you pay the first time not every consecutive month after" | `_advertise` pays for open posts not yet paid, once; `_hire` fills paid posts with no further payment; a filled post that reopens is paid again | SAME | |
| 35 | §9.2 | offer: "fall back to the original rule for settin on hire, then it should only climb max 5% if it cost not hire for one month"; "5% each month"; "i never said i wanted the rule for lowering" | `salary_rules`: a new opening at the starting salary; +5% (OFFER_CLIMB_PM 50) each month a post stayed unfilled a whole month; back to the start once none has; no lowering | SAME | |
| 36 | §9.2 | "Change the sallery from fod and rent to just rent at 2×" ... "Merge with 2" | `starting_salary` = area_rent × 2 (STARTING_RENT_PM 2000) × the tier's share | SAME | |
| 37 | §9.2 | "On sallery it's an avrage of the area" | `area_rent`: the plain average of what the area's open landlords ask; none → half a new house | SAME | |
| 38 | §9.2 | "Can we not make a 2d array to keep all things about the hires?"; "You can merge if all rows match" | staff entry → `hires` rows {n, pay, since, train}; `_tidy` merges only equal keys | SAME | |
| 39 | §9.2 | unpaid wages: "Record it make them pay after our if they refused take it to court" | `pay_wages` records the unpaid rest as an UNPAID_WAGES debt (Justice.owe), collected when the company has money; no court | DIFFERENT (part) | The court is not built (step 5 by plan). |
| 40 | §9.2 | "The build crews at start should not be hiring at all. They should start with a job already active." | HomeBuilders.land places the crews (placed = true), trained | SAME | |
| 41 | §9.2 | "Place the goverment staff from startb with the builders and lets set their sallery at 2.5 from start same for builders" | Landing._crew places; `placed_salary` = area_rent × 2.5 × tier | SAME | |
| 42 | §9.2 | "double the rent" | `HOME_RENT_PM` 2000 on the solve's home rent (194); `SHELTER_RENT` 97 | SAME | |
| 43 | §9.2 | "10 purple each" (one farm worker feeds ten) | FARM line qty 240 with 24 posts | SAME | |
| 44 | §9.2 | "The district the plant hiring is in" (salary's place) | the hiring salary is kept per tier and per area of the plant (`Households.plant_area`) | SAME | |
| 45 | §9.2 | "But emplyees only apply to jobs that meet their needs" | `Households.hire`: pay < `needs_per_worker` (Rules.needs_line) → no applicants, unless placed | SAME | |
| 46 | 12.3 15a | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | `founding`: standing sixths + booked + granted-and-made; plans only made not seen | SAME | |
| 47 | 12.3 15c | "No they should not cut for the start, and they should not increase prices for claimed jobs"; "At start id assume they know work is coming" | `Building.seller_signal` returns {} until the first quote (no price or crew cut); a waiting plan counts once as unmet, the month it signs | SAME | |
| 48 | 12.3 15d | "He should look for the shortest time" | `sign_round`: the earliest start, then the lowest total | SAME | |
| 49 | 12.3 15e | a family works its own family farm, without wages ("Yes, i agree") | `family_to_posts` fills the full posts from the family's adults; no wages are paid to the family | SAME | |
| 50 | 12.3 15e | "ship food should be considered less desierable" | `SHIP_LESS_WANTED_PM` 250 in the offers' rank | SAME | |
| 51 | 12.3 15e | "FARMS DON'T SHUT" | `staff_to_posts` 19a: a plant left with no hired staff is closed NO_STAFF, farms included, family or not; nothing reopens it | DIFFERENT | Farms are shut. |
| 52 | 12.3 15e | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" ... "TAKE SIX OUT OF THIRTY SELL 24" | `Households.post_orders` → `Making.family_take`: need + the store's double out of the farm's stock before the market; the rest offered | SAME | |
| 53 | 12.3 15e | "THEY ARE THREE THEY CAN PRODUVE 30" ... "THAT SHOULD BE ENOUGH TO HIRE ONE PERSON" | A family farm (4 posts) at full makes 37.6 a month. A family of three (usually 2 adults) works 2 posts: half, about 18.8 a month over a year (about 35 in summer, under 4 in winter) | DIFFERENT | 30 a month is not reached on average by a family of three alone; 24 sold × 39.4 = 946 against one wage of 194 does hold. |
| 54 | 12.3 15e | "the farm would be their home ... paying on any loans they had to take and uppkeep" | `Landing.rent_due` gives no rent for a founder whose family farm is open | SAME | |
| 55 | 12.3 15e | "I think two is better" (loss carried forward) | `winnings`: carried loss paid down before the family takes anything | SAME | |
| 56 | 12.3 15e | "The owners of a family farm should take winnings no sallery, wich comes after" | `pay_winnings` in JUSTICE after debts, reading the month just lived (fixed today) | SAME | |
| 57 | 12.3 15f | "they buy 2 units if food instead of one, store it and use it in emergencies"; "six months of food in storage"; "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | `post_orders`: AHEAD want = min(need, 6 × need − held); STORE_MONTHS 6; eating from the store only after the month's food | SAME | |
| 58 | 12.3 15f | "if your running low ... i don't think you wait" | the store order posts at any price the money left reaches | SAME | |
| 59 | 12.3 23a | "if they want to but can't buy, bread goes too high — the company can win by lowering" | `Market`: a buyer short of THIS price is a refusal (PRICE, counted for the cut); only a buyer with nothing is NO_MONEY | SAME | |

## B. Lines that are a proposal, a reading or a starting number of ours (no user words behind them)

| # | Where | Ours | What was built from it | Status against the paper |
|---|---|---|---|---|
| B1 | §4 | builder price per BW with materials on top (proposal) | a builder's BW price + site supplies | built as written |
| B2 | §6 r6 / 12.3 16 | the idle time: twelve months (proposal) | nothing (rule 6 not built) | not built |
| B3 | 12.3 15a | the work "in money per month", "averaged per month over the last twelve months, at today's prices" (paper); my reading with Wilma's yes, 2026-11-18: sum over 12, months before the colony at the eating need | `Rules.work`: qty ÷ months on record (`h.size()`), × today's cheapest offer | DIFFERENT from the paper: divides by the months on record, not 12, and has no eating-need months |
| B4 | 12.3 15a | rule 8's capacity: made − took over the last twelve, unlived months at full (my reading, Wilma's yes) | nothing (rule 8 not built) | DIFFERENT (as A21) |
| B5 | 12.3 15a | shares by plant, by sixths; a plan when share ≥ running cost; the founder plans the largest size that passes and their money reaches | `founding`: share = work × own sixths/(have + own); covers = share ≥ running_cost | SAME |
| B6 | 12.3 15a | what a company costs to run: posts at the area's starting salary (Bob, Wilma's yes, today) | `running_cost`: posts × `TypeTable.salary(t)` (300 general, 450 skilled, 675 specialist) | DIFFERENT: the table's 300, not the starting salary (2 × rent: 194) |
| B7 | 12.3 14 | the making price: (inputs, wages, upkeep, rent, freight, interest) ÷ normal full output | `Making.making_price`: (wages_due or wage bill + inputs + upkeep + other) ÷ full output; `other` is passed 0 | SAME for step 3 (rent, freight and interest are not in step 3) |
| B8 | 12.3 15 / 15b | the step shape k × s/(1+s) (price) and g × s/(1+s) (output) (proposal) | `step_pm` | SAME |
| B9 | 12.3 15b | output rise below one post's share is on that share, at least 1 per mille (my reading, Wilma's yes) | `output_rule` new_lv line | SAME |
| B10 | §9.2 | the quit bar's "up to 15%" as the whole bar (Wilma's reading); "less if stressful" toward 5% (starting number) | QUIT_BAR_MAX_PM 150; QUIT_BAR_STRESSED_PM 50, unused | SAME (stress unused) |
| B11 | §9.2 | the negotiation: once a year, closes toward the average, never above it, never lowers; the average within the same post tier (proposals) | NEGOTIATE_MONTH 7; ask = pay + (avg − pay)/2 per tier; refused if the company cannot pay a year of it | SAME as the proposal; against the user's words see A32 |
| B12 | §9.2 | layoff weighing: idle × pay > months × pay + advert + 1.75 × output × price (Bob's proposal); the training curve 500 + 500 × a/6 | `layoff_weighing`, `trained_pm` | SAME |
| B13 | §9.2 | three months' layoff pay, a tenth of a month's pay as the advert (Wilma's starting numbers) | law lever 3; ADVERT_PM 100 | SAME |
| B14 | §9.2 | the advert paid in the month the post opens, whether or not anyone is hired (Wilma's reading) | `_advertise` before `_hire` | SAME |
| B15 | §9.2 | the hiring-offer table: rule 1 = posts open or leavers, rule 2 = more applicants than posts, rule 9 = the starting salary (proposal, superseded by the user's offer rule) | not built; the offer rule replaced it | superseded (the user's 4-point rule is built, A35) |
| B16 | §9.2 | "a whole month" = posts left open after last month's hiring and still open now; "max 5%" = always 5% (Bob's readings) | `salary_rules` | SAME |
| B17 | §9.2 | the offer held after a month of 19a (Bob's reading) | `salary_rules` returns early when no_hiring_m == month − 1 | SAME |
| B18 | §9.2 | the placed 2.5 is x the rent; later openings at the starting salary (Wilma's readings) | `placed_salary`; later hires at `hiring_salary` | SAME |
| B19 | §9.2 | "their needs" = their housing and food where they live (proposal) | `needs_line` = the cheapest home asked in the area (no landlord: a new home's full rent) + the cheapest FOOD × 2.5 | SAME as the proposal (note: with no landlord it reads a NEW home's rent, 194, while `area_rent` reads half of it, 97) |
| B20 | §9.2 | "Only pay moves a salary": a post open for want of housing or skill does not raise the offer (Wilma's carrying over) | `salary_rules` climbs on any post left open a whole month, whatever the cause | DIFFERENT from the proposal |
| B21 | 12.3 15c | "the start" = until the first plan has asked for a quote (Wilma's reading) | `first_quote_month < 0` → {} | SAME |
| B22 | 12.3 15e | ship food a quarter dearer in the rank (starting number) | SHIP_LESS_WANTED_PM 250 | SAME |
| B23 | 12.3 15e | the family's adults fill the posts first; posts beyond are hired (Wilma's) | `family_to_posts` / `hire_wanted` nets the family whatever tier | SAME |
| B24 | 12.3 15e | the farm is home from the day it opens; a town family company is not covered (Wilma's) | `lives_on_own_farm`: an OPEN family-size FARM | SAME |
| B25 | 12.3 15e | winnings for every family-size company (Wilma's) | `pay_winnings` for any company with a family | SAME |
| B26 | 12.3 15f | this month's food, then the rent, then the store; stored food spoils (Wilma's) | `post_orders` budget order; spoilage in `after_market` | SAME |
| B27 | §9.2 | unpaid wages "refused" = still unpaid 12 months after due, until the court (Bob's reading, with the user) | Justice PETITION_KINDS includes UNPAID_WAGES (Anni) | built as the reading |
| B28 | type table | the general salary the table solves at (SALARY_G 300); tier shares S 1.5, Sp 2.25; payback 10 years (homes and offices 13.5, the middle of the user's "12 to 15 years"); land 10% of the bill; upkeep 1/400 of material a month and 2% of BW a year | the table's solve | built as written; no user word for 300, 1.5, 2.25, 10 years, 10%, 1/400 or 2% |
| B29 | type table | the farm's posts G 18, S 5, Sp 1 (the old table's labour); every other row's quantities, inputs and posts | the table | built as written; the user's word is only on the farm's output per worker (A43) |
| B30 | 12.3 19a | a company that cannot pay lays off what it cannot pay, in proportion; a plant with no staff is shut | `staff_to_posts` | SAME as the paper; against the user's "FARMS DON'T SHUT" see A51 |

## C. The count

**DIFFERENT against the user's words (part A): 21 rows.**

Not built because the plan puts them in a later step (still DIFFERENT today):
- 3 / 13: the second output (rule 3)
- 5, 6: services' client intake; school taxes per pupil
- 9 / 17: rule 5, growing
- 18: rule 6, cutting capacity
- 30: "less if stressful" (stress)
- 31: underpaid workers to the union
- 39: the court for unpaid wages

Built, but differently from the words:
- 14, 15, 16: rule 4. It cuts every month with unsold goods by the step formula, not only after over 50% unsold 3 months in a row, not by the whole 5%, and not again in a fourth month.
- 21: rule 8 (the work covered) is not built at all. The share test alone stands in for it.
- 32: the underpaid line is the average within the post tier, not the company's average.
- 51: farms are shut (19a, NO_STAFF).
- 53: a family of three makes about 19 a month on average, not 30.
- 7: noise does not touch rent.

**DIFFERENT against our own paper (part B): 4 rows.** B3 (rule 7's averaging), B4 (rule 8), B6 (rule 7's cost at the table's 300), B20 (only pay moves a salary).

## A, continued: the buffer ruling (15e, new today)

| # | Where | The user's words | What the code does today | Status | If different |
|---|---|---|---|---|---|
| 60 | 12.3 15e | "the farm needs a buffer say 50% until it had 6 months worth built up then 10%" | `Rules.winnings`: amount = min(earned − loss paid down, balance − keep), keep = one month of wage bill + inputs + upkeep; everything above that goes to the family | DIFFERENT | No buffer: no 50% kept back, no six months built up, no 10% after. |

---

# The whole plan (Wilma's widening, 2026-11-18)

The other papers, read against the shared tree. I read rebuild-company §3–6, 9.2 and 12.3 myself (part A above). The
other papers were read for me by reading helpers on the same rules (the code, not memory). I checked every DIFFERENT
they found against the code. Where a line they gave as the user's turned out to be paper text, I moved it to the
lists of our own lines and say so.

## D. rebuild-company.md, the other sections (1, 2, 7, 8, 9.1, 9.3–9.12, 10–14) and MASTER-PLAN's rulings of 11-17/18

| # | Where | The user's words (short) | What the code does today | Status | If different |
|---|---|---|---|---|---|
| D1 | §1 | "one object that is the company" | `Company.create`: one record per company, every type a TypeTable row | SAME | |
| D2 | §1 | "it's size family to large 4 sizes" | SIZES F/S/A/L, SIXTHS 1/2/4/6, PENALTY_PM 60/40/20/0 | SAME | |
| D3 | §1 | "the nine rules plugged into that" | `Rules.company_month`: rules 1–4 and 9; 7/8 in `founding` | DIFFERENT | Rules 5 and 6 not built (step 6); rule 8 not built (A21). |
| D4 | §1 | "the offices as a bonus" | `office` field never set; OFFICEBLOCK row only | DIFFERENT | Not built (step 9). |
| D5 | §1 | "if they pick from first or second output" | `line` is 0 at creation and never changes | DIFFERENT | As A3. |
| D6 | §1 | "the same company can become freight" | HAULIER row; `fleet` never filled; nothing carries | DIFFERENT | Not built (step 4). |
| D7 | §1 | "polution plugg ins to the same" | rows carry pollution and noise; `emissions` and `noise` never computed | DIFFERENT | Not built (step 9). |
| D8 | §1 | "Food output plus into the same" | FARM is an ordinary row; `Making.make_plant` as for any item | SAME | |
| D9 | §1 | "services have no output but a client take in" | `Making.month` skips non-items; `slots` never filled | DIFFERENT | Not built (step 4). |
| D10 | §1, §7 | "stress for workers reduced output based on workers" | no stress figure; output never lowered by stress | DIFFERENT | Not built (step 9). |
| D11 | §1 | "No more only this sector shit" | one rules.gd, making.gd and market.gd for every type | SAME | |
| D12 | §1 | "they start with their own and ship out" | no exports; `Ship.order` exists with no caller | DIFFERENT | Exports not built (step 10). |
| D13 | §1 | "building fixes behind off switches is not a valid way to do large scale fixes" | politics/health_signal.gd: `on()` needs "HEALTH_SIGNAL" in `world.meta["on"]`; game_sim.gd sets that list to `[]` | DIFFERENT | One fix is still behind an off switch (checked). |
| D14 | §1 | "Same company types can come but not their code or balancing" | old names reused, numbers new, no old code | SAME | |
| D15 | §1 | "set a credit prices we are going to have to adjust it anyway" | prices solved from SALARY_G 300, PAYBACK_Y 10, LAND_PM 100; starting figures marked START | SAME | |
| D16 | §1 | "not meant too be a perfect economy" | no rescue or survival guarantee | SAME | |
| D17 | §7; MP 11-17 | "offices should not be esencial ... 15% less ... 10 plants" | OFFICEBLOCK row (10 places) only | DIFFERENT | Not built (step 9). |
| D18 | §7; MP | "count the work que not passed work" | no freight queue; stock "waiting" never above 0 | DIFFERENT | Not built (step 4). |
| D19 | §7 | truck repair "about 4 months ... or a workship"; "about 5% are lost" | TRUCKSHOP row only; no wear, quality or repair | DIFFERENT | Not built (step 4). |
| D20 | §8.1 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... BEFORE ACCEPTING A GRANT" | `make_plan`, then `Grants.apply(plan)`; the company only at `open_due` | SAME | |
| D21 | §8.1 | "you can't fail before you exist ... no expenses beyond building" | the plan has no staff, stock or price; it pays land, contract and supplies | SAME | |
| D22 | §8.3 | "End of a company can happen in three ways" | no company ever ends; only plants close | DIFFERENT | Not built (step 5). |
| D23 | §8.3 | "they are laied of its loans are payed in full ... the owner is taking to court" | no bank, no ending, no court | DIFFERENT | Not built (step 5). |
| D24 | §9.1 | "we take how it works ... not take the code" | households.gd and demography.gd new | SAME | |
| D25 | §9.1 | "That's fine" (pools by housing block and income band) | `Households.pool_id(area, band)`: keyed by AREA | DIFFERENT | Pools are by area, not by housing block (checked). |
| D26 | §9.1 | "what are you paying power and water on if you can't pay the rent?" | food first from all money; rent after the market; no grid in step 3 | SAME | |
| D27 | §9.1 | "No hard floors or ceilings of our own" | none in households or economy | SAME | |
| D28 | §9.1; MP | "Oh no wholesale does not mean unchecked" | the remove verdicts are done | SAME | Some "keep" items not built yet (shacks, storm and wildlife deaths, pollution). |
| D29 | §9.1 | "Housholds follow terras latest plan" | shelters on Terra's town grid; rent reads no cell value | DIFFERENT | Home value and wants not built (step 7). |
| D30 | §9.3; MP | "Company and people should be able to stock up if the price is low" | companies: AHEAD up to 2 months' need; people: the 15f store | SAME | |
| D31 | §9.3; MP | "what's low should be against what its worth to the buyer" | companies: AHEAD when the offer ≤ 80% of `input_worth`; households: no low test | SAME for companies | Households follow the user's later 15f ("i don't think you wait"), which I read as superseding "low" for them. |
| D32 | §9.5 | "the goverment starts with its subsidiaries as before" | `Landing.land`: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL, POLICE, ADMIN, housing office, Stores, Public Works | SAME | |
| D33 | §9.5 | "All company types needs to be able to be created as private" | `month.FOUNDABLE = ["FARM"]` | DIFFERENT | Only FARM can be founded (food first in step 3; the rest at step 4). |
| D34 | §9.5 | "per pulpe plus staff ... tax brackets" | no brackets, no taxes | DIFFERENT | Not built (step 8). |
| D35 | §9.5 | "I DID NOT SAY GIVE EVERYONE ... GRANTS" | `Grants.KINDS`: FARM, BAKERY, TRUCKER, TRUCKSHOP, all family size | SAME | |
| D36 | §9.5 | "No split trucks and workshops" | separate kinds and levers | SAME | |
| D37 | §9.5, §9.9 | "the goverment can lean on companies ... or on the union" | no union; `EconFace.unions_*` stubs | DIFFERENT | Not built (step 9). |
| D38 | §9.6 | "They can't order when there's not a ship there ... full period of waiting" | `Ship.order` refuses without a ship in port; lands on the next call, paid on the dock | SAME | Nothing calls `Ship.order` yet. |
| D39 | §9.6; MP | "Import stops when a plant makes it? Not what i fucking meant" | no rule ties imports to plants | SAME | |
| D40 | §9.7 | "5 building companies and alot of oppretunity" | 5 builders (1 L, 2 A, 2 S), HOME_WORLD | SAME | |
| D41 | §9.7 | "3 months up front and add 1 month ... every month" | UP_FRONT_M 3; `_ready`; `supply_orders` tops up to 3 months | SAME | |
| D42 | §9.8; MP | "This sounds good" (Terra's grid) | town_grid.gd: 3 km tile, 100 m cells, 400 m blocks | SAME | |
| D43 | §9.8; MP | "Below 250 start a gridd anyway" | `TownGrid.ensure_town` | SAME | |
| D44 | §9.8 | "the closer to the coast ... more expensive ... road to road" | `TownGrid.value` computes view, water and road; rent charges the landlord's flat price | DIFFERENT | No rent or home price reads the value (step 7). |
| D45 | §9.8; MP | "that's what changed rent levels for the landlord" (wear) | condition never falls; rent ignores condition | DIFFERENT | Not built (steps 6–7). |
| D46 | §9.8; MP | "buy your house out ... the 1/6 of a farm for that" | nothing | DIFFERENT | Not built (step 7). |
| D47 | §9.8 | "That's fine" (the top band moving out) | nothing | DIFFERENT | Not built (step 7). |
| D48 | §9.8; MP | "If you own an appartment there is a fee for uppkep to the landlord" | nothing | DIFFERENT | Not built (step 7). |
| D49 | §9.9; MP | "Unions belong outside ... 2/3 normal sallery" | no union record | DIFFERENT | Not built (step 9). |
| D50 | §9.12; MP | "5 building companies ... subsidiaries ... all grant types open ... no sectors beyond landfallpoint" | 5 builders; all four grant levers open in month 0; one area | SAME | |
| D51 | §9.12; MP | "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE" | all four open from month one | SAME | |
| D52 | §9.12; MP | "materials come with the start not finished buildings" | `Landing.STOCK` FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20; but `Landing._shelters` lays finished LANDLORD plants (blocks of 50 homes) in month one | DIFFERENT | Finished shelter buildings stand from month one (Wilma's 12.2, 11). |
| D53 | §9.12; MP | "the old system and the new for five years are not the same" | builders land with 3 months of wages | SAME | |
| D54 | §12.5, 35; MP | "individually counted on company start ... don't malt to many people to track" | `make_founder` "founder:N" at plan making; `release_founder` | SAME | |
| D55 | §12.9, 61a; MP | "when a grant ends, they reset to zero ... limited time"; "and where it covers too" | PROGRAMME_M 24; lever to 0 at the end; cover dropped | SAME | |
| D56 | §12.9, 61b; MP | "put a max sum into the grant based on how many darms they want" | `budget_for`: wanted × grant + EXTRA_PM 100; `sum_left` limits | SAME | |
| D57 | §12.11; MP | "I think most of these needs to be worked in" (points 77–109) | a few parts: the chief (unused), a colony reference wage, idle Public Works | DIFFERENT | The rest not built (steps 5–10). |
| D58 | §13 step 4; MP | "a prefernce for farms not being close to towns"; "Save it for when trucks and roads come" | nothing | DIFFERENT | Not built (step 4). |
| D59 | §13 step 8; MP | "the government can order stockpiles to help in famin" | nothing | DIFFERENT | Not built (step 8). |
| D60 | §13; MP | "atleast one other reviews each peace of code made" | commits name a reviewer | SAME (process) | |
| D61 | §13; MP | "a backend column somhere that records all things happening like a log" | core/logbook.gd | SAME | |
| D62 | MP 11-17 | "This needs signals, pandemic in the newpaper" | health_signal.gd off by default; reads the old economy's stubs | DIFFERENT | Off by default (D13), and reads cut figures. |
| D63 | MP 11-17 | "Private landlord, and yes" (who owns office buildings) | no landlord owns offices | DIFFERENT | Not built (step 9). |
| D64 | MP 11-17 | "Yes to both" (R8FR_QUEUE, OFFICE_E99) | neither is in game/sim | DIFFERENT | The queue is not rebuilt (step 4); OFFICE_E99 absent. |
| D65 | MP 11-17 | "CUT THE ECONM6" / "MAKE A FULL COPY THEN CUT THE ECONOMY OUT" | game_full_copy/; economy rewritten | SAME | |
| D66 | MP 11-17 | "I WANTED OPRN CONNECTIONS SO IT WAS EASY TO FIND THEM" | core/econ_face.gd keeps one stub per old call | SAME | |
| D67 | MP 11-17 | "skip all it's mumbo jumbo about garaneeing company survival" | no protection | SAME | |

Process-only lines (no code to compare): "swich the fixes on one at the time", "start answering all the fucking
questions that have obvius answers", "you're decisions are fine at can always go back later".

Ours (no user words), DIFFERENT against the paper: 9.3 stocking up "as far as money reaches" (built: a 2-month cap);
12.1, 5 connection costs (none in the estimate); 12.1, 6 buildings after endings; 12.2, 13 port owned by the
government (no owner record); 12.4 freight (not built); 12.4, 34 storms and wildlife on plants and outdoor workers (not
built); 12.5, 37/37a (superseded by the user's 9.2 rulings; the paper's 12.5 text is outdated); 12.5, 39–40 reach and
travel cost (own area only); 12.5, 41 benefit from the area's starting salary (built from SALARY_G 300); 12.6–12.10
(steps 4, 5, 8, 9); 12.8, 54 closing a state company (not built); 12.9, 56 takeover of a half-built building (not
built); 12.9, 58–59 upkeep (never charged); 12.10, 66 going ahead unlicensed (not built); 12.10, 73 famine names no
area; 13 step 4 staging (not built).

## E. rebuild-households.md

| # | Where | The user's words (short) | What the code does today | Status | If different |
|---|---|---|---|---|---|
| E1 | intro | "we take how it works and transfer over not take the code" | no old household file in game/sim | SAME | |
| E2 | intro | "Oh no wholesale does not mean unchecked" | a verdict per old mechanism (section 3) | SAME | |
| E3 | 1.2 | "don't malt to many people to track" | pools of counts; only founders are records | SAME | |
| E4 | 2b | "emplyees only apply to jobs that meet their needs" | `Households.hire` refuses below `needs_line`; but `labour_month` → `move_job` (quitting for pay) moves a worker to any better-paid post over the bar with no needs test | DIFFERENT | Quitting for pay can move a worker into a post below their needs (checked: no needs read in move_job). |
| E5 | 2b | "10% if it's a good job ... plus 1% per year ... up to 15%" | `quit_bar_pm` = min(150, 100 + 10 × years) | SAME | |
| E6 | 2b | "less if stressfull" | `quit_bar_base_pm` always 100; QUIT_BAR_STRESSED_PM 50 unused | DIFFERENT | Not built (step 9); the same as A30. |
| E7 | 2b | layoff pay (the user's keeping-workers ruling) | `Households.layoff`: law months × own pay; the rest owed (LAYOFF_PAY) | SAME | |
| E8 | 2b | "take winnings no sallery" | family on posts with no payroll; `Rules.winnings` / `pay_winnings` | SAME | Except the new buffer, row 60. |
| E9 | 2b | "the farm would be their home" | `rent_due` {} for an open own family farm | SAME | |
| E10 | 2b | "ship food should be considered less desierable" | SHIP_LESS_WANTED_PM 250 in the rank; RANK or PRICE by budget | SAME | |
| E11 | 2b | "underpayed is based on that line" (9.2) | `avg_pay` per post tier | see A32 | The paper here says "for the post"; the user's 9.2 words say the company's average. |
| E12 | 2b | the food store (15f) | STORE_MONTHS 6; NEED every month; AHEAD from what food and rent leave | SAME | |
| E13 | 2b | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | want = min(need − farm_store, 6·need − held − farm_store) | SAME | |
| E14 | 2b | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" | `Making.family_take` before any order | SAME | |

Moved to ours: "The worker negotiates first, and only if that fails do they look for better pay" (2b) is Maja's paper
text, not the user's words. Built: quitting runs every month whatever the negotiation; DIFFERENT against the paper.

Ours, DIFFERENT against the paper: month-one placing (more than the paper's 220: the government staff and the shelter
and Stores crews are placed too); earners per household (not used, and the paper's own later line drops it); "the
oldest working-age one" as founder (age not used); landlord slots (not built, step 7); "one landlord plant of 400
homes" (the paper's own later line gives 8 of 50, which the code follows); the owner's heir (not built); the spending
habit, the per-person cap, pollution deaths, shacks, staff costs to a seller (not built, later steps).

## F. rebuild-building.md

| # | Where | The user's words (short) | What the code does today | Status | If different |
|---|---|---|---|---|---|
| F1 | 4.2 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... BEFORE ACCEPTING A GRANT" | make_plan → Grants.apply → company at open_due | SAME | The grant is paid right after the plan is made; the paper's 4.4 says "at signing". |
| F2 | 1 | "you can't fail before you exist ... no expenses beyond building" | plan pays land, bills, supplies only | SAME | |
| F3 | 4.5 | "3 months up front and add 1 month of additional supplies every month" | UP_FRONT_M 3; `_ready`; `supply_orders` | SAME | `planned_bw` ignores the paper's "or the crew the builder can put on it, whichever is less" (ours). |
| F4 | 4.1 | "5 building companies and alot of oppretunity" | 5 builders + idle Public Works | SAME | |
| F5 | 4.1 | "materials come with the start not finished buildings" | STOCK; no production plant | SAME | Shelters stand finished: see D52. |
| F6 | 4.1 | "5 years worth of equipment that never changed" | MATERIAL 9700, COMPONENT 1060, added once | SAME | |
| F7 | 4.1 | "they are companies from the world" | HOME_WORLD owner; crews placed | SAME | |
| F8 | 3 | apartments 0.85, a tower 1.15 (the user's figures, 9.8) | no form factor anywhere | DIFFERENT | Not built (step 7). |
| F9 | 4.3 | "He should look for the shortest time" | `sign_round` by start, then total | SAME | If the soonest is unaffordable it takes a later one it can pay. |
| F10 | 5.1 | "money is a limitor" | no rule 5 | DIFFERENT | Not built (step 6); the same as A17. |
| F11 | 5.3 | homes keep the user's 55 (9.8) | no home condition, no 55 | DIFFERENT | Not built (step 6/7). |

Moved to ours: "It ends only if its owner gives it up (no builder, no money)" is paper text (rebuild-company 8.1), not
the user's. Built: a plan is also given up when rule 7 no longer passes before signing (Otto's 4.4), and a SIGNED plan
whose builder is gone is never given up. Both are DIFFERENT against 8.1.

Ours, DIFFERENT against the paper: upkeep bought by the plant and the upkeep builder job (not built); the landing stock
sold by a state Stores company with staff, not the purse; trucks in the landing stock, not ordered by ship; the
founder's opening money is a gate on who is picked, with no "plan without it"; founders drawn by a seeded weighted
draw, not pool-id order; building worth, wear and repair (not built, step 6).

## G. rebuild-law-face.md

| # | Where | The user's words (short) | What the code does today | Status | If different |
|---|---|---|---|---|---|
| G1 | §4 | "if not the owner is taking to court ... settle for a smaller amount or demand payment over time" | no court against owners; `EconFace.insolvency_court_liquidation` returns false (checked) | DIFFERENT | Not built (step 5). |
| G2 | §4.4 | the choice given to the bank (settle or payment over time) | none | DIFFERENT | Not built (step 5). |
| G3 | §5.5 | "they have a sallery set on hire then it climbs based on yearly upps set by goverment" | hire rows keep pay; `yearly_raise_month` each January ≥ lever ECON_YEARLY_RAISE_MIN_PCT 2 | SAME | |
| G4 | §5.6 | "it should apply to builders" (layoff pay) | LAW_LAYOFF_PAY_MONTHS 3 (0–12) for every company and crew | SAME | |
| G5 | §5.6 | "a debt like unpaid wages, and can end the company" | the debt: SAME; the ending: the court stub refuses every wind-up | DIFFERENT | "Can end the company" not built (step 5). |
| G6 | §5.7 | "Record it make them pay after our" | UNPAID_WAGES owed; collected in JUSTICE oldest first; booked as wages | SAME | |
| G7 | §5.7 | "if they refused take it to court" | petition filed after 12 months; the court stub refuses | DIFFERENT | Not built (step 5); the same as A39. |
| G8 | §5.7 | layoff pay "a debt like unpaid wages" (owed whole) | NO_PLAN_KINDS UNPAID_WAGES, LAYOFF_PAY | SAME | |
| G9 | §7 | "failing is a result, not a fault" (a capped seller below its making price) | no price ceiling acts; LAW_PRICE_CONTROL read nowhere | DIFFERENT | Not built (step 8). |

Ours, DIFFERENT against the paper: "every plan and plant is lawful with no permit or licence until step 6" (licences
are in force now: LAW_LICENCE_REGIME_* default REQUIRED); the unbuilt lever marked "not in force yet" (no such text);
the deposit criterion; the licence term as a lever (LICENCE_MONTHS 60/120 constant); builders and subsidiaries licensed
from landing (no grant); fine numbers "set new" (the v8 values are still in place); creditor order and the bank's
choice for all; the court clearing "petitioned"; a state company's fine paid by the purse with a minister's desk case;
overtime and ratios as levers; "the yearly raise's minimum has no effect until step 8" (it is applied every January
now); land sold at the full plan price, not value × LAW_LAND_PRICE_FLOOR_PCT; lease rent at 0.6% a month, not the
bank's rate (and leases built before step 5); arrears limit 3 fixed, not the eviction lever; utility cut-offs,
essential services, lockouts (not built); press licensing refuses by opposition, with no fee; transit route licences
(not built).

---

## H. The whole count

**DIFFERENT against the user's words: 64 rows.**

| Group | Rows |
|---|---|
| Part A (my sections) | 22, with the buffer |
| D (company, other sections, and the MASTER-PLAN rulings) | 32 |
| E (households) | 2 |
| F (building) | 3 |
| G (law face) | 5 |

Some rows are the same thing seen in two papers: the second output (A3, A13, D5), rule 5 (A9, A17, D3, F10), stress
(A30, D10, E6), unions (A31, D37, D49), the court (A39, G7) and noise (A7, D44).

**Built, but differently from the user's words (not a later step):**
1. Rule 4 cuts output every month anything is unsold, by the step formula. The words: only after over 50% unsold 3
   months in a row, the whole 5%, again in a fourth month (A14–16).
2. Rule 8, "the same signal says the work is covered", is not built; the share test stands in for it (A21).
3. The underpaid line is the average within the post tier; the user said the company's average (A32).
4. "FARMS DON'T SHUT": 19a shuts a farm with no hired staff (A51).
5. "THEY ARE THREE THEY CAN PRODUVE 30": a family of three makes about 19 a month over a year (A53).
6. "the farm needs a buffer say 50% until it had 6 months worth built up then 10%": no buffer; everything above one
   month of costs is paid out (A60).
7. "emplyees only apply to jobs that meet their needs": quitting for pay moves workers into posts below their needs
   (E4).
8. "building fixes behind off switches is not a valid way to do large scale fixes": HEALTH_SIGNAL is still opt-in and
   off (D13, D62).
9. "That's fine" to pools by housing block and income band: pools are by area (D25).
10. "materials come with the start not finished buildings": finished shelters stand from month one (D52).
11. "noise polution should also drive down price of housing": it does not (A7).

**Not built, the plan itself putting them in a later step (4 to 10):** every other DIFFERENT row.
