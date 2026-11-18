# Audit: the whole rebuild plan against the shared tree's code (Terra)

Terra, 2026-11-18. Wilma's order: every line in the plan papers that carries the user's words, one row each: the user's
words | what the code does today (function, number) | SAME or DIFFERENT | what differs. Then every line that is a
proposal, a reading or a starting number of ours, and what was built from it. No fixes, no proposals.

- **Papers read:** rebuild-company.md (whole), rebuild-households.md, rebuild-building.md, rebuild-law-face.md, and
  MASTER-PLAN.md's "The rebuild: … (the user, verbatim)" sections.
- **Code read:** the shared tree game/sim, as committed after Otto's advert piece (rules.gd d2ddf83f, company.gd
  6e54dcfc). Bob's rule 8 / rule 4 hand-over is NOT in it.
- **How it was read:** in six parts (A to E, and T). A to E were read by five helpers I sent, each with the same
  instructions: read the code, not the comments; every number; SAME / DIFFERENT / NOT BUILT (step N) by section 13's
  build order. T is mine.
- **Checking:** I checked every DIFFERENT row below against the code myself, except where marked "(theirs, not
  re-read)".
- "NOT BUILT (step N)" means the build order puts it later and the code has not built it. That is not a difference.

## The DIFFERENT rows, merged (the user's words against the code): 18

1. **"FARMS DON'T SHUT"** (company 15e; MASTER-PLAN:1042).
   - rules.gd:346-347 staff_to_posts (19a) shuts any plant, farms included, when its payroll reaches 0 after unpaid
     wages (Company.close_plant "NO_STAFF").
   - building.gd:629 (LAW at the opening) cannot reach a farm today, because FARM is not hazardous.
   - Nothing reopens a NO_STAFF plant. (T11, C5, E5)
2. **"A family farm with no money still grows food"** (15e). The shut test counts Company.staff_count, the payroll only,
   not Company.family_count. When the hired hands are laid off unpaid, a family farm is shut with its family on its
   posts, and making.gd:52 makes nothing for a shut plant. (T10, C4)
3. **"it's plants shut down and it cant affort too replace them"** (8.3). The shutting is built in step 3, but the "cant
   affort" half is not: nothing checks whether the company can afford to reopen or replace, and nothing reopens. The
   company stays OPEN with its plant shut for good, which is an ending before step 5. (T7)
4. **"if you sell out all your producing produce MORE"** (rule 3, company:177). rules.gd output_rule rises only by
   step_pm(G, unmet_above, sold). A company that sold everything it offered, with no order left over, does not raise
   output. (A)
5. **"The production output is only lowered if over 50% of offered goods is not sold 3 months in a row"** (rule 4,
   company:178/202; MASTER-PLAN:1031). output_rule cuts in any month with anything unsold. There is no 50% test and no
   run of 3 months. (A, E; Bob's hand-over, not merged, is about this.)
6. **"A CUT IS 5%"** (company:209; MASTER-PLAN:1037). The cut is 5% × unsold / (unsold + sold), so 0 to 5% (60% unsold
   gives 3%). (A, E)
7. **"AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN"** (company:209). There is no run of months, so no fourth month.
   It cuts every month with anything unsold. (A, E)
8. **"Output moves at most 5% a month"** ("25?! 5!!!", company:200). Below one post's share of full, the rise is taken
   on that share and is at least 1 ‰, so it can pass 5% of the level (a family farm at 100 ‰ can rise 12%). This is
   already with Wilma for the user as a reading ("5% of the level, or of full?"). (A; E UNSURE)
9. **"increases should not stack for seperate offers … only climb max 5% if it cost not hire for one month"** (9.2,
   company:430-439; MASTER-PLAN:929). rules.gd:225 salary_rules keeps one offer per company, tier and area:
   - it climbs while any post of that tier in that area has been open a month, and every new opening there gets the
     climbed offer;
   - the climb drops back only when no post of that tier and area is open.
   (B, E)
10. **"I think you should avrage ask salleries in the company and underpayed is based on that line"** (company:369).
    company.gd:705 avg_pay is the average of ONE post tier in the company, not of all salaries in the company. (A)
11. **"noise polution should also drive down price of housing"** (company:135). Nothing reads the type table's noise
    column. Instead, town_grid.gd value() lowers a cell's value for industry within 1 km (part "industry"), in step 2/3;
    the plan puts noise at step 7. My own code. (A)
12. **"the closer to the coast you get the more expensive they get"** (9.8, company:598). town_grid.gd value(): "view"
    reaches 0.3 km and "water" 1.0 km, falling linearly to 0. Beyond 1 km, distance to the coast changes nothing. My
    own code. (T16)
13. **"not finished buildings"** (12.2 / 9.12, company:666; also line 1414). landing.gd:124 _shelters places finished
    homes (blocks of 50) in month one. This follows Wilma's decision 12.2 #11; the paper already marks it as hers. (B,
    C)
14. **"It sells too cover all monthly expences"** (hold-back, company:191/798). rules.gd hold_back counts the wage bill,
    inputs and upkeep. It leaves out the month's job adverts, layoff pay and debts paid through the law. (B)
15. **Rule 8, "the same signal says the work is covered"** (company:182, 836). rules.gd:653 founding has the share test
    only ("covers" = share ≥ cost). There is no test of the work in quantity against what standing plants deliver.
    Bob's hand-over, not merged, builds it. (B, T3)
16. **"winnings … wich comes after"** (15e, company:912). rules.gd winnings() also keeps back one more month of the hired
    wages, inputs and upkeep ("keep", Bob's reading), which is beyond what the farm owes that month. Debts owed later
    by instalment (layoff pay) are not held back. (C; T15 note)
17. **"they should not increase prices for claimed jobs"** (15c, company:948). building.gd:289-292: a plan that signs and
    must wait behind the book adds its whole BW once as unmet demand (unmet_pending → seller_signal unmet_above), so the
    claimed job raises the builder's price once. This is Wilma's decision of how to count it. (C, D)
18. **"It ends only if its owner gives it up (no builder, no money)"** (company 8.1:243; building 4.9:253). building.gd:239
    sign_round also gives a plan up when rule 7 no longer passes before signing (Otto's 4.4, which contradicts 4.9:262
    in the same paper). Source UNSURE: the line may be Wilma's wording, not the user's. (D)

## Lines that are not the user's words but break the paper's own step order

- **law-face:94, "Until step 6: every plan and plant is lawful as it stands, with no permit, licence or fee".**
  building.gd:242 may_sign checks zones and licences, and building.gd:627-629 may_open shuts a new plant lacking a
  licence, both in step 3. This is dormant today: only FARM is foundable (month.gd:27) and FARM is not hazardous. (E, D)
- **law-face:266-267.** The paper says the yearly raise does nothing until step 8, but the 2% minimum raise and the yearly
  negotiation run now. (E, theirs, not re-read)

## Stale paper lines, where the code follows a later ruling of the user's

- company:214 and 337 still say "the same three price rules set salaries". The user's later 9.2 ruling (the 5% climb,
  "fall back to the original rule") replaced that, and the code follows the ruling. (A)
- company:1395 (watch item 8) says plans are not counted in rule 7. The user's 15a ruling ("they do see plans booked …
  and plans that have accepted grants") replaced it, and the code follows the ruling. The comment at month.gd:124-125 is
  stale too. (C)
- rebuild-building 4.11: "The five builders' 180 crew is month one's figure, not a ceiling" (Otto's text). In step 3,
  output_rule never raises a level above 1000, so 180 is the ceiling. With Wilma for the user. (D, T3)

## UNSURE, not counted

- **The farm family's numbers** (15e, MASTER-PLAN:994): "THEY ARE THREE THEY CAN PRODUVE 30 … TAKE SIX OUT OF THIRTY
  SELL 24".
  - The mechanism is SAME: the family eats first and takes at most double, never offered.
  - The numbers differ: a family is about 2.5 persons (about 2 adults), a family farm has 4 posts, and it makes 37.6 a
    month at full (240 / 6 × 0.94; 9.4 a worker after the 6% penalty the user accepted, against the "one farm worker
    feeds ten people" ruling's 10), and the season changes it. (C, D, E)
- **"He should look for the shortest time"** (15d). The code takes the earliest start the plan can pay for; if the
  soonest builder is too dear, it signs a later one rather than waiting. The paper does not cover that case. (C)
- **"5 years worth of equipment"**: whether it means the size of the landing stock. Five years of the builders' work is
  about 10,600 BW, more than the 9,700 MATERIAL landed. (D)
- **The land law's default.** law_data.gd:649's lever table says SELL; land_law.gd:181 and law_query.gd:622 fall back to
  LEASE when the lever is absent. What a game gets depends on the lever being installed. Not the user's words. (D: "the
  plan leases"; checked by me, unsure.)

## The six parts in full

Each part has Table 1 (the user's words) and Table 2 (proposals, readings, starting numbers of ours, and what was built
from them).


---

### Audit A: rebuild-company.md lines 1 to 420 against game/sim

Read-only audit. Paths are relative to `game/sim/`. Build order from section 13 (paper line 1253 on).

#### Table 1: the user's own words

| # | paper line | the user's words (verbatim, short) | what the code does today | status | if DIFFERENT: what differs |
|---|---|---|---|---|---|
| 1 | 23 | "one object that is the company it's size family to large 4 sizes" | economy/company.gd:38 `create`: one record per company, with any type; type_table.gd:14-16 SIZES FAMILY/SMALL/AVERAGE/LARGE | SAME | |
| 2 | 23 | "the nine rules plugged into that" | rules.gd:59-93 `month`/`company_month`: one implementation for every OPEN company. Rules 1,2,3,4,7,8,9 built; 5 and 6 are not | SAME for 1-4, 7-9; NOT BUILT (step 6) for 5-6 | |
| 3 | 23 | "the offices as a bonus building" | type_table.gd:122 OFFICEBLOCK row (10 places); company.gd:67 `office` = "" and nothing reads it | NOT BUILT (step 9) | |
| 4 | 23 | "a 2d array of wich items a company type makes, if they pick from first or second output" | type_table.gd:66-170 ROWS, each with `lines` (first, second). company.gd:59 `line` = 0 and nothing ever changes it | SAME for the table; picking the line is NOT BUILT (step 4, all items) | |
| 5 | 23 | "roads and supply networks since the same company can become freight" | HAULIER row type_table.gd:109 (freight_room 20, trucks 6); company.gd:68 `fleet` = []; Market.offers subtracts `waiting` (market.gd:87), which nothing sets | NOT BUILT (step 4) | |
| 6 | 23 | "polution plugg ins to the same" | pollution column in each row; company.gd:69 `emissions` 0, never written | NOT BUILT (step 9) | |
| 7 | 23 | "Food output plus into the same" | FARM row type_table.gd:68 (FOOD 240 a month for the full row); made by making.gd:49 `make_plant`, sold on market.gd | SAME | |
| 8 | 23 | "services have no output but a client take in" | services sell "@client kind" (type_table.gd:64, 134-169); `clients()` type_table.gd:284; no client intake runs; making.gd:37 skips non-items | NOT BUILT (step 4) | |
| 9 | 23 | "stress for workers reduced output based on workers" | no stress anywhere in economy/ or households | NOT BUILT (step 9) | |
| 10 | 27 | "building fixes behind off switches is not a valid way to do large scale fixes" | no flag or off switch in economy/*.gd or population/households.gd (grep) | SAME | |
| 11 | 29 | "You will swich the fixes on one at the time ... report where the bottle neck is" | a working rule about testing, not code | UNSURE | process ruling; cannot be checked in code |
| 12 | 31 | "Same company types can come but not their code or balancing" | type_table.gd: 30 rows of new numbers; old table names not created (company.gd:11) | SAME | (cannot prove that no old code was copied; nothing found) |
| 13 | 34 | "set a credit prices we are going to have to adjust it anyway ..." | type_table.gd:322 `start_prices`: solved from the table (making cost + bill over PAYBACK_Y 10 years) | SAME | |
| 14 | 40 | "it does not really matter if he does not close ... its not meant too be a perfect economy for everyon" | no rescues, floors or subsidies in rules.gd/market.gd; no ending built either (status never leaves "OPEN") | SAME | |
| 15 | 83 | "No i said each COMPANY" (one price per company) | company.gd:64 `price` {item: one value} per company; set_price company.gd:94 | SAME | |
| 16 | 101 | "it's just a 2d array of wich items a company type makes, if they pick from first or second output" | as row 4 | SAME (table); picking NOT BUILT (step 4) | |
| 17 | 110 | "services have no output but a client take in" | as row 8 | NOT BUILT (step 4) | |
| 18 | 117 | "things can be done in two different ways based in company types how its this a problem?" | type_table.gd:60-64 `way` column {sells, reads, price, reach} per row | SAME | (the different ways are read only by Rules for BW, rules.gd:84; the rest are step 4 and later) |
| 19 | 133 | "per pupil plus staff is how taxes for schools are calibrated" | SCHOOL row sells "@pupil" (type_table.gd:149); no tax bracket price anywhere | NOT BUILT (step 8) | |
| 20 | 135 | "things like noise polution should also drive down price of housing so we don't have factories all in among the houses, or rather less." | the noise column (0..5) is read by nothing. Instead transport/town_grid.gd:37,41,515,654: every COUNTRY type but FARM counts as "industry", weight -2.0 within 1 km, which lowers a town cell's value; site.gd:394 `land_price` reads that value. No home rent exists yet (step 7) | DIFFERENT | A stand-in is built early (step 2/3) and in a different way: an "industry nearby" penalty (on/off by setting, weight -2, 1 km reach) on cell value and land price, not the type's noise figure, and not yet on housing prices. The plan puts noise at step 7 |
| 21 | 143 | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size ... small penalty" | type_table.gd:15-16 SIXTHS 1/2/4/6, PENALTY_PM 60/40/20/0; `output_milli` type_table.gd:254 = qty × sixths/6 × (1 − penalty) | SAME | |
| 22 | 152 | "You penalty is fine" | type_table.gd:16 6%, 4%, 2%, 0 | SAME | |
| 23 | 159 | "This sounds good" (400 m street block, 16 cells) | town_grid.gd:52 BLOCK_CELLS 4 (400 m, 16 cells); site.gd:112 `square_of`; site.gd:120 `square_sixths`, site.gd:232/328 refuse > 6 sixths per type | SAME | |
| 24 | 161 | "Depends on region, in a square if there are other companies they would have to buy out ... build a new" | no growing, no buy-out; set_level caps at 1000 (company.gd:671) | NOT BUILT (step 6) | |
| 25 | 176 | rule 2: "the more inventory you have, the more you reduce your price" | rules.gd:120 `price_rule`: down = 50‰ × unsold/(unsold+sold) (step_pm, rules.gd:111); unsold = offered − sold, offered excludes hold-back | SAME | |
| 26 | 177 | rule 3: "if you sell out all your producing produce MORE" | rules.gd:168 `output_rule`: up = step_pm(50, unmet_above, sold); unmet_above comes only from orders left SOLD_OUT/NO_SELLER (market.gd:247-270); no rise while it holds stock back (rules.gd:174) | DIFFERENT | It raises output only when orders went unfilled (unmet_above > 0). A company that sold out all it offered with no order left over does not raise. The size of the rise also scales with unmet/(unmet+sold), not a fixed step. Picking first or second output is not built (step 4) |
| 27 | 178 and 202 | rule 4: "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | rules.gd:175 down = step_pm(G_PM 50, unsold, sold); rules.gd:190 lowers the level in ANY month with unsold > 0, in the same month as the price cut. No 50% test, no count of months | DIFFERENT | No "over 50% unsold" condition and no "3 months in a row"; output falls in every month with anything unsold. This is exactly what the user struck (line 204) |
| 28 | 179 | rule 5: "if your selling out and all plants at max build a new one ... money is a limitor" | none | NOT BUILT (step 6) | |
| 29 | 180 | rule 6: "A hard rule here is fine" | none; close_plant is used only for NO_STAFF (rules.gd:347) and LAW (building.gd:629) | NOT BUILT (step 6) | |
| 30 | 181 | rule 7: "instead of reading the leftovers, they read an avrage of all avaliable jobs" | rules.gd:615 `work`: the orders for the item averaged over up to 12 months (WORK_MONTHS 12), × today's cheapest offer; rules.gd:653 `founding`: the newcomer's share = work × its sixths / (all standing plants' sixths + booked plans + granted plans + its own) | SAME | services give 0 (rules.gd:617), step 4 |
| 31 | 181 | "No cap on how many may form" | economy/month.gd:126-132 `while _found_one` until nobody passes, can pay or finds a site | SAME | |
| 32 | 183 | rule 9: "if below making price climbing allways had priority if above lowering has priority ... THEN DO THE SAME FOR BOTH" | rules.gd:130-132: both signals → R1 if price < making else R2; one signal acts alone; K_PM 50 both ways | SAME | at price exactly equal to making price, lowering wins (not said by the user) |
| 33 | 187 | "If something else than price stops sales it should not count on adjusting price!!" | no freight yet. market.gd:87 offers exclude `waiting` and the hold; NO_MONEY (could pay nothing) feeds no seller (market.gd:213, 247-270) | SAME | (freight-stopped sales do not exist until step 4) |
| 34 | 190 | "Ignore the stoch in that other place too" (MASTER-PLAN 363: the output rule must not read held-back stock) | output_rule reads `offered` from Market, which excludes the hold (market.gd:87) | SAME | |
| 35 | 191 | "It sells too cover all monthly expences" | rules.gd:149 `hold_back`: below making price, offers ceil((wage bill + inputs + upkeep of the month)/price), holds the rest | SAME | loan repayments not included (bank is step 5) |
| 36 | 196 | "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP ..." | rules.gd:46 K_PM = 50; price moves at most 5% (step_pm ≤ k) up and down | SAME | |
| 37 | 200 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" (output at most 5% a month) | rules.gd:50 G_PM = 50. Cut: lv × down/1000 ≤ 5%. Rise: rules.gd:190 = max(1, max(lv, 1000/n) × up / 1000) | DIFFERENT | The rise is taken of max(level, one post's share of full), at least 1‰. When the level is below one post's share (1000/n), the rise can exceed 5% of the level (e.g. family farm n=4: a level of 100‰ can rise 12‰ = 12% of itself) |
| 38 | 204 | "Then they cut output instead of lowering price output cut has been built wrong let me guess they just cut if they sell less???" | as row 27 | DIFFERENT | as row 27 (counted there) |
| 39 | 208 | "That's not going to do anything but delay it one month" (striking Wilma's reading) | the struck reading is not in code | SAME | |
| 40 | 209 | "A CUT IS 5% WHY IS THIS STILL A PROBLEM???? AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | rules.gd:175,190: the cut is 50‰ × unsold/(unsold+sold) of the level, so less than 5% unless nothing sold; no month count | DIFFERENT | The cut is not 5%: it is scaled by the unsold share (e.g. 60% unsold → 3%). No fourth-month repeat logic, as there is no run of months at all |
| 41 | 222 | "I think the offices should not be esencial ... 15% less ... one office building should be able to hold 10 plants extra workers" | OFFICEBLOCK row "@office place" qty 10 (type_table.gd:122); no 15% loss, no renting | NOT BUILT (step 9) | |
| 42 | 223 | "the same company can become freight" | as row 5 | NOT BUILT (step 4) | |
| 43 | 224 | "count the work que not passed work"; "That works" | no freight queue | NOT BUILT (step 4) | |
| 44 | 225 | "if you're truck breaks down you can fix it yourself in about 4 months or drive to a workship ..."; "Uses components and resets wear, about 5% are lost reach time" | TRUCKSHOP row "@truck repair" 12 a month with COMPONENT 6 (type_table.gd:113-117); no trucks, wear or repair run | NOT BUILT (step 4) | |
| 45 | 228 | "stress for workers reduced output based on workers" | none | NOT BUILT (step 9) | |
| 46 | 235 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... THAT'S BEFORE ACCEPTING A GRANT" | economy/month.gd:158-163 make_plan then Grants.apply; building.gd:141 plan table, not a company; building.gd:602 `open_due` makes the company when the building is done | SAME | |
| 47 | 235 | "you can't fail before you exist ... no worker but also no expenses beyond building" | plan record has no staff/stock/price (building.gd:151); its account pays land and builder only; given up plans are GIVEN_UP, not dead (building.gd:329) | SAME | (plan also given up when rule 7 no longer passes, building.gd:240, and "cannot pay the builder", building.gd:593) |
| 48 | 251 | "End of a company can happen in three ways ..." | company status never changes from "OPEN"; econ_face.gd:586 court_liquidation returns false | NOT BUILT (step 5) | |
| 49 | 262 | "Yes they are laied of its loans are payed in full if they can ... settlent might be reached" | no endings, no loans | NOT BUILT (step 5) | |
| 50 | 277 | "Okay i think we can take it wholesale as long as we make sure it fits in" | population/households.gd: new code; meets companies only through Company.staff_change/payroll and Market orders | SAME | |
| 51 | 278 | "Households, i mean we take how it works and transfer over not take the code" | households.gd written new (1842 lines, preload-based, milli units) | SAME | (cannot prove no copied code; none seen) |
| 52 | 302 | "Oh no wholesale does not mean unchecked" | process (the verdict table) | UNSURE | process ruling; spot checks: no self-employed, no home-world rations, no 10% migrant gate found; homes 130% at households.gd:547 |
| 53 | 308 | "That's fine" (pools) | households.gd:42 `pool_id(area, band)`, one account per pool (households.gd:46); PopStore key "hb" = the area | SAME | the "housing block" of the old code is the area |
| 54 | 314 | "what are you paying power and water on if you can't pay the rent?" | households.gd:598-653 `post_orders`: food from all money first, then rent set aside (rent_set_aside), then the store; water and power not bought yet | SAME | water/power come with step 4 |
| 55 | 332 | "Housholds follow terras latest plan" | households.gd:546 homes = AreaStore.capacity (Terra's cells) | SAME | |
| 56 | 337 | "Workers and sallery ... actually the three rules for price should be applied here too" | rules.gd:225 `salary_rules`: rules 1, 2, 9 are NOT applied to salaries; the hiring offer starts at the starting salary (2 × area rent × tier, rules.gd:203,270) and climbs 5% a month for a post unfilled a whole month, never lowered | DIFFERENT | The three price rules do not set any salary. Replaced by the user's later ruling of 2026-11-18 (paper line 435, outside this slice: "this replaces rules 1, 2 and 9 for a salary"); line 214 of the slice still says the three price rules set salaries |
| 57 | 342 | "No no, the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | company.gd:241 pay stored on the hire row at hiring; company.gd:422 `yearly_raise` max(company's choice, minimum); households.gd:1094-1100 every January from year two, lever ECON_YEARLY_RAISE_MIN_PCT default 2 | SAME | |
| 58 | 347 | "that's fine for hiring" (the price rules move the HIRING salary) | as row 56: only the hiring offer moves, but by the 5% climb, not by rules 1/2/9 | DIFFERENT | what moves the hiring salary is the later offer rule (line 435), not the three price rules; there is no lowering |
| 59 | 352 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | households.gd:993-1017: base 100‰, +10‰ per full year at the workplace (from hire row "since"), whole bar capped at 150‰; move only if new ≥ old × (1+bar) (households.gd:1049) | SAME | "less if stressful" waits for stress (step 9); QUIT_BAR_STRESSED_PM 50 is unused |
| 60 | 362 | "It's too create political drama, underpayed workers go to the union, they can quit if they think they can get better prices if not they may unionise" | quitting for better pay: households.gd:1023 `labour_month`; no union link | SAME for quitting; NOT BUILT (step 9) for unionising | |
| 61 | 369 | "I think you should avrage ask salleries in the company and underpayed is based on that line, that way both old and new can become underpayed" | company.gd:708 `avg_pay(world, cid, post_tier)`: the average PER POST TIER; households.gd:1075 underpaid = pay below the tier's average | DIFFERENT | The line is the average of one skill tier in the company, not of the salaries in the company as a whole (the paper: "The line is the average of the salaries paid in the company") |
| 62 | 373 | "I think we need something to motivate them to keep, costs of hiring ... 6 months training ... payment after fire ... three months of vages" | layoff pay: households.gd:257-329 (LAW_LAYOFF_PAY_MONTHS 3, work_law.gd:28); advert: rules.gd:432, media_ops.gd:916 ADVERT_PM 100; training: company.gd:129-130,352; weighing: rules.gd:472 | SAME | "can't fire" replaced by lower output, accepted by the user (line 384) |
| 63 | 374 | "On the workers rules i belive you have the right of it, and it should apply to builders" | builders' crews go through the same staff_to_posts with plant key "crew" (rules.gd:337-338), same layoff, advert and training | SAME | |
| 64 | 407 | "On posts when you many an open post you pay the first time not every consecutive month after" | rules.gd:419-450 `_advertised`/`_advertise`: a post paid once when it opens; kept paid while open (rules.gd:384-389); filled or no longer wanted → paid again if it opens anew | SAME | |
| 65 | 415 | "Lets as one more thing to the sallery, the manager, negotiation can bring it closer to avrage" | households.gd:1072 `_negotiate`, once a year in month 7: an underpaid row asks halfway to the tier average; granted if the account holds a year of the rise; never above the average (company.gd:734) | SAME | the manager (company chief "mgmt") is not read; see table 2 |

#### Table 2: proposals, readings and starting numbers with no user words behind them

| paper line | the proposal / number | what was built from it |
|---|---|---|
| 124 | builder price "a price per unit of building work with materials on top" (proposal: the builder reading) | building.gd:193-204 `quotes`: work = bill BW × builder's BW price, supplies at market price; type_table.gd:105 way price PER_BW |
| 125 | reach by grid for power and water (open, section 14) | type_table.gd:63 _GRID_WAY, ITEMS ENERGY/WATER grid true; market.gd:56 refuses grid orders; making.gd:79 skips grid inputs |
| 137-139 | types that only held staff go one by one (proposal) | type_table.gd:66-170: no office/party HQ/business-services rows; OFFICEBLOCK, SHOP, CAFE, SERVICEHUB, NEWSPAPER rows exist |
| 147-150 | penalty figures 6/4/2/0 (Wilma's, accepted) | type_table.gd:16 PENALTY_PM |
| 158 | 400 m street block (Terra's proposal, accepted) | town_grid.gd:52 BLOCK_CELLS 4 |
| 180 | rule 6: the idle time (proposal) | nothing built (step 6) |
| 195 | whether there is a cap and its size (open) | decided by the user at line 196: rules.gd:46 K_PM 50 |
| 198 | k of 0.2 in 15a (wrong) | replaced: rules.gd:46 K_PM 50 |
| 201 | g of 0.25 in 15b (wrong) | replaced: rules.gd:50 G_PM 50 |
| 207 | Wilma's struck reading ("only when lowering the price fails") | not built |
| 259 | "turn the price" = back above making price; buy-out = growing in a shared square (Wilma's readings) | nothing built (steps 5/6) |
| 271 | fourth ending: court winding up after convictions (open) | not built; core/econ_face.gd:586 stub returns false |
| 304-327 | the verdict table (first pass) | e.g. self-employed removed (none in households.gd); price floors removed; home-world rations removed; 10% migrant gate removed (households.gd:1700-1722 attractiveness from jobs/food/homes); 130% crowding households.gd:547 |
| 355-356 | "up to 15%" caps the whole bar (Wilma's reading) | households.gd:996 QUIT_BAR_MAX_PM 150, households.gd:1012 |
| 357-358 | until stress the bar starts at 10%; with stress toward 5% (Wilma's starting numbers) | households.gd:993-1002: 100‰ always; QUIT_BAR_STRESSED_PM 50 declared, unused |
| 386 | three months of layoff pay (Wilma's starting number) | law/work_law.gd:28 LAW_LAYOFF_PAY_MONTHS default 3 (clamped 0..12) |
| 386-387 | the advert = a tenth of one month's pay of the post, per person hired | media/media_ops.gd:916 ADVERT_PM 100, 949 `job_advert_cost`; costs 0 where no paper circulates (media_ops.gd:950) |
| 387 | training: half in the first month, rising evenly to full after six | company.gd:129-130 TRAIN_MONTHS 6, TRAIN_START_PM 500; company.gd:352 `trained_pm`; making.gd:64 reads trained_count |
| 391-394 | output in month a = 500 + 500 × a / 6 ‰; hire groups per staff entry; move within workplace brings no training; 1.75 months lost (Bob's proposal) | company.gd:241-247 (train month on hire rows), 253-264 `staff_move` keeps training; rules.gd:491-493 sums the loss (1.75) |
| 395-398 | idle = months in a row posts wanted fewer than held, at least 1, reset when posts want as many (Bob) | rules.gd:362-379, 409 `_slack`: idle = month − start + 1, erased when w ≥ have |
| 399-402 | weigh per person "at the tier's pay of the entry laid off first": idle × pay > months × pay + advert (tenth of hiring salary) + 1.75 × output × price (Bob) | rules.gd:472-497 `layoff_weighing`: same formula, but `pay` is the head-weighted AVERAGE pay of all rows of that tier at that plant (rules.gd:476-480), not the pay of the entry laid off first. Households.layoff lays off largest rows first (households.gd:264) |
| 403-404 | rule 19a not weighed; laid off as now, owed layoff pay as a debt | rules.gd:339-351 lays off in proportion with no weighing; households.gd:327 Justice.owe LAYOFF_PAY |
| 405-406 | a company that cannot pay the adverts for the people it wants hires none that month (Bob) | rules.gd:442-449: it pays for as many posts as its money reaches and hires into those (Otto's review); not "none" |
| 411-412 | advert paid in the month the post opens, whether or not anyone is hired; a post opening anew is paid anew (Wilma's reading) | rules.gd:352-389, 432-450 |
| 413-414 | every layoff decision row carries idle, pay, months, advert, training, price; keeping slack is logged | rules.gd:373-377 (LAYOFF row with the weighing; RULE row "keeps its slack staff") |
| 418-420 | negotiation once a year, before quitting or the union; how far depends on the manager (chief mgmt) and whether the company can pay; never above the average (proposal) | households.gd:490 NEGOTIATE_MONTH 7, 1024-1025 before quitting; 1078 always halfway, the chief's mgmt is NOT read; 1080 needs a year of the rise in the account; company.gd:734 never above the tier average |

---

### Audit B: rebuild-company.md lines 420-860 against the shared tree (game/sim)

Read-only audit, 2026-11-18. Paths are relative to `game/sim/`. "S" in the code = 1000 (milli-units).

#### Table 1: the user's own words in the slice

| # | paper line | the user's words (verbatim, short) | what the code does today (file:line, function, numbers) | verdict | if DIFFERENT: what differs |
|---|---|---|---|---|---|
| 1 | 432-434 | "Sallery should be calculated as avrage living in the area and food plus half of both again, that's the start then it should regulate itself"; "On sallery it's an avrage of the area." | Replaced by the user's ruling at line 464 (2 x rent). `economy/rules.gd:270` `starting_salary` = `area_rent` x 2000‰ x tier (G 1.0, S 1.5, Sp 2.25). `type_table.gd:395` `salary_line` (the 1.5 x (rent+food) formula) still exists but nothing calls it. `area_rent` (`rules.gd:282`) = plain average of `@home` asks of OPEN LANDLORD companies whose company area is the area (one value per landlord, not weighted by homes); none there -> `start_price_of("LANDLORD")/2`. | SAME (as superseded by line 464) | The "average of the area" is averaged per landlord, not per home; only the housing office exists in step 3, so the two agree today. |
| 2 | 439 | "It's not regulating correctly, increases should not stack for seperate offers, infact they should fall back to the original rule for settin on hire, then it should only climb max 5% if it cost not hire for one month" | `rules.gd:225` `salary_rules`, `OFFER_CLIMB_PM := 50` (`rules.gd:200`): climbs 5% (always 5%, Bob's reading of "max") for each month posts stay open; climb is x1.05 on the current offer (compounds). The offer is stored per company x TIER x AREA (`company.gd:61` `salary`, `company.gd:378` `hiring_salary`), not per post. It climbs when any post of that tier in that area was left open by last month's hiring and is still open (`by[tier|area][1] > 0`), and goes back to the start only when NO post of that tier/area has been open a whole month (`rules.gd:259`). | DIFFERENT | The climb belongs to the tier+area of the company, not to the unfilled post. While any one post of a tier in an area has been open a month, every other opening of that tier there (a separate offer) is offered the climbed salary and keeps climbing, so rises do stack across separate openings; and filling a post does not clear its rise if another post of the same tier/area is still open. |
| 3 | 441 | "5% each month, it goes i never said i wanted the rule for lowering that was your suggestion" | 5% per further month (`OFFER_CLIMB_PM 50`, `rules.gd:257`). No lowering rule: the only downward move is `clear_hiring_salary` back to the starting salary (`company.gd:406`). | SAME | |
| 4 | 442 | "Yes hand it built, this should stabilise workers and allow unemployed in" | Built (see rows 2-3). | SAME | (row 2's difference applies) |
| 5 | 444-449 (plain rules 1-4 from 439/441) | 1 new opening at the original rule; 2 +5% per whole month unfilled; 3 rise gone when filled, no stacking; 4 no lowering | 1: `hiring_salary` falls back to `starting_salary` when no climb is set (`company.gd:382`). 2: `rules.gd:255-258`. 3: `rules.gd:259-260`, per tier+area. 4: none. | DIFFERENT (rules 1 and 3 only) | As row 2: a "new opening" is offered the climbed figure whenever another post of its tier/area has been open a month; "when the post is filled" is "when no post of that tier/area is still open a month". Rules 2 and 4 SAME. |
| 6 | 452 | "Can we not make a 2d array to keep all things about the hires? Sallery start date so forth?" | `company.gd:241` `staff_change`, `:267` `_staff_write`: each staff entry holds `hires: [{n, pay, since, train}]`, one row per hire. | SAME | |
| 7 | 453 | "You can merge if all rows match" | `company.gd:328` `_row_key` = pay\|since\|training-left; `_tidy` (`:334`) merges rows only when that key matches. | SAME | |
| 8 | 458 | "Record it make them pay after our if they refused take it to court" | `population/households.gd:423` `pay_wages`: what is not paid is owed per pool through `justice_ops.owe(..., "UNPAID_WAGES")`, collected when the company has money. The court on refusal is step 5. | SAME (court part: step 5 / law side) | |
| 9 | 463-464 | "it's a form of self infation"; "Change the sallery from fod and rent to just rent at 2× we will have to find a better formula for it later" | `rules.gd:203` `STARTING_RENT_PM := 2000`; `starting_salary` = rent x 2 x tier; food not in it. | SAME | |
| 10 | 468 | "3 5x housing try it" | Trial only; superseded by row 11. Code holds 2000‰. | SAME (superseded) | |
| 11 | 472 | "2", then "Merge with 2" | `STARTING_RENT_PM := 2000` (`rules.gd:203`). At the landing: rent fallback 97 -> 194 for G. | SAME | |
| 12 | 478 | "The build crews at start should not be hiring at all. They should start with a job already active." | `economy/home_builders.gd:110` `_make` calls `Households.hire(..., trained=true, placed=true)`; `households.gd:184-196`: placed skips the needs test and adverts, starts trained. | SAME | |
| 13 | 483 | "Place the goverment staff from startb with the builders and lets set their sallery at 2.5 from start same for builders that would mean they don't jump either from start" | `rules.gd:207` `PLACED_RENT_PM := 2500`; `placed_salary` = rent x 2.5 x tier. `landing.gd:166` `_crew` places the administration, the housing office's shelter crews and Colony Stores (`placed=true`); builders and public works likewise (`home_builders.gd:110`). Later openings get `hiring_salary` (2 x). | SAME | (UNSURE on the exact figure: builders and the administration are placed before the housing office exists, so their rent is `start_price_of("LANDLORD")/2`; the housing office and Stores crews are placed after it, at its 97. Equal only if the new-house start rent is exactly 194; not computed.) |
| 14 | 491 | "Food is too expensive" | No food change; food price follows the table. | SAME | |
| 15 | 492 | "Screw lowering food, double the rent. Make the rent more reasonable in comparison to food. If food has to be there for them to earn money from a farm, we make rent worth more to those who have those buildings." | `type_table.gd:30` `HOME_RENT_PM := 2000` applied to `@LANDLORD` in `start_prices` (`:365`); `landing.gd:54` `SHELTER_RENT := 97 * S`. Food price unchanged. | SAME | |
| 16 | 497 | "10 purple each" | `type_table.gd:68` FARM: qty 240, labour G18+S5+Sp1 = 24 posts -> 10 per worker at full (large). Starting food price from `start_prices` with `SALARY_G 300` (value not computed here; plan says about 39). | SAME | |
| 17 | 500 | "that's fine for hiring" | Rules 1/2/9 for salary replaced (row 2); hiring is at `hiring_salary`. | SAME (superseded by 435-449) | |
| 18 | 501 | "The district the plant hiring is in." | `households.gd:187-194` `hire`: pay = `hiring_salary(cid, tier, plant_area(...))`, the AREA the plant stands in (`plant_area`, `:242`). | SAME | Note: the advert cost (`rules.gd:439`, `:483`), the needs test (`households.gd:195`, company area) and `Company.vacancies` (`company.gd:643-657`, company area) read the company's own area, not the plant's. |
| 19 | 504-505 | "every year a company can grant a bonus what the minimum of this is is up to the government, 2% is a good start" | `econ_publish.gd:59` lever `ECON_YEARLY_RAISE_MIN_PCT` default 2, range 0-20; `households.gd:1094` `yearly_raise_month` each new year; `company.gd:422` `yearly_raise` multiplies every hire row's pay by (1 + max(choice, minimum)) permanently. | SAME (UNSURE) | UNSURE: the user's word here is "bonus"; the code gives a permanent pay raise (following the other ruling "climbs based on yearly upps set by goverment"). No one-off bonus payment exists. |
| 20 | 506 | "But emplyees only apply to jobs that meet their needs" | `households.gd:195-198`: no hire when pay < `needs_per_worker(area)` = `rules.gd:299` `needs_line` = cheapest landlord rent there (fallback: the new-house start rent) + 2.5 x cheapest FOOD offer (else last sold, else start price). Placed hires skip it. `households.gd:884` `applicants` same test. | SAME | |
| 21 | 519 | "Company and people should be able to stock up if the price is low" | Companies: `making.gd:202-210` AHEAD order up to 2 months' need held, only for inputs spoiling < 50‰/month, when cheapest offer <= 800‰ of the input's worth. Households: `households.gd:629-649` AHEAD food order toward 6 months, at most one month's need a month, at any price (the later 15f ruling). | SAME | (households buy ahead at any price under the later 15f ruling, not only when low) |
| 22 | 523 | "No what's low should be against what its worth to the buyer, like when they buy normaly" | Companies: low = cheapest offer x 1000 <= `input_worth` x 800 (`making.gd:207`; `input_worth` `:217` = its output price less other inputs, per unit of this input), the same worth it puts on its ordinary order (`:199`). Households: worth = all their money (`households.gd:620`), so any affordable price counts. | SAME | |
| 23 | 545 | "the goverment starts with its subsidiaries as before" | `landing.gd:85` `land`: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL, POLICE (no plant, no staff), ADMIN (crew), housing office (LANDLORD, shelters), Colony Stores (SHOP), public works (`home_builders.gd:57`). | SAME | |
| 24 | 545-547 | "All company types needs to be able to be created as private, but maybe they're is only ever enough work for say one powerplant then the conitions for new ones don't get switched on" | `economy/month.gd:27` `FOUNDABLE := ["FARM"]`; `rules.gd:615` `work()` returns 0 for non-item types. Rules 7/8 (`founding`) are generic by type. | NOT BUILT (step 4) | |
| 25 | 548-549 | "per pulpe plus staff is how taxes for schools are calibrated Yea they all get tax brackets" | No tax brackets in sim (only a text label in `politics/gov_builder.gd:1320`). | NOT BUILT (step 8) | |
| 26 | 550-551 | "I DID NOT SAY GIVE EVERYONE ... GRANTS"; "No split trucks and workshops" | `economy/grants.gd:53` `KINDS`: FARM, BAKERY, TRUCKER (HAULIER), TRUCKSHOP, each FAMILY size; trucker and workshop separate levers. | SAME | |
| 27 | 553 | "the goverment can lean on companies if they don't comply or on the union" | Nothing found. | NOT BUILT (step 9) | |
| 28 | 560-561 | "They can't order when there's not a ship there to take the order. ... they have to ask for one when the ship is there, which means they have the full period of waiting every time." | `economy/ship.gd:167` `order`: refused with no ship in port; the order rides that ship (`taking` -> `bringing` at `_leave`) and lands on its next call (`_arrive`), paid on the dock. | SAME | Nobody calls `Ship.order` in the tree yet (no caller found); the government cannot order (`ship.gd:19`, step 8). |
| 29 | 569-570 | "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR" | `ship.gd:9`: no limit on imports beyond the ship (the hold's room, `HOLD_START 3000`, is the port's). | SAME | |
| 30 | 577 | "5 building companies and alot of oppretunity" | `home_builders.gd:33` five home-world builders (1 LARGE, 2 AVERAGE, 2 SMALL) + public works. | SAME | |
| 31 | 578-579 | "They should not need 90% of supplies up front they should need 3 months up front and add 1 month of additional supplies every month" | `building.gd:43` `UP_FRONT_M := 3`; `supply_orders` (`:375-399`) keeps 3 months' need on site (or the rest of the bill), topped up each month; ordered only when working or next in line. | SAME | |
| 32 | 591 | "This sounds good" (Terra's town grid) | `transport/town_grid.gd` exists (HOUSE 8 homes a cell, `:28`). | SAME | |
| 33 | 594 | "Below 250 start a gridd anyway and only use what you need" | `town_grid.gd:18`, `:854`: a town gets its grid with its first building. | SAME | |
| 34 | 598-599 | "the closer to the coast you get the more expensive they get; it can even shift from road to road." | `town_grid.gd:596-611` `value`: location value with shore, jobs, services, road, utilities parts. Rent does not read it yet (rent of a home = landlord's flat `@home`, 9.8 formula is step 7). | SAME (value) / NOT BUILT (step 7) (rent from value) | |
| 35 | 613 | "that's what changed rent levels for the landlord" | No home wear/renovation changing rent. | NOT BUILT (step 7) | |
| 36 | 615-616 | "I belive you should be able to buy your house out so you own it, and if an individual becomes richer than the neibouhood he was able to build his own larger house we could use the 1/6 of a farm for that" | Nothing found (no buy-out, no own house). | NOT BUILT (step 7) | |
| 37 | 621 | "That's fine" | As row 36. | NOT BUILT (step 7) | |
| 38 | 624-625 | "If you own an appartment there is a fee for uppkep to the landlord that owns the rest of they all own then they are a community and they all pay together" | Nothing found. | NOT BUILT (step 7) | |
| 39 | 629 | Unions blockquote ("Unions belong outside ... 2/3 normal sallery ... the goverment can lean on companies ...") | No economy union record, fee, shutdown or 2/3 pay found (`politics/union_politics.gd` is politics' endorsement code only). | NOT BUILT (step 9) | |
| 40 | 655 | "5 building companies and alot of oppretunity and the goverment starts with its subsidiaries as before, and all three grant types open, and no sectors beyond landfallpoint that's up to where things are built" | Five builders (row 30); subsidiaries (row 23); grants (row 41); one area: `population/area_store.gd:175` `found_landing` founds only the Landing. | SAME | |
| 41 | 660 | "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE" | `econ_publish.gd:37`, `:63-70`: all four grant levers default `GRANT_START_PCT 50` from month one (`grants.gd:6`). | SAME | Only FARM can be founded (row 24), so the bakery/truck/workshop grants are open but cannot be taken yet; the government's `grant_programmes` chooses the districts covered (`month.gd:113`). |
| 42 | 666 | "Okay materials come with the start not finished buildings 5 years worth of equipment that never changed they are companies from the world. Tell me in any colony builder do you place out fucking plants from start????" | No farm/mine/factory at start. Landing stock `landing.gd:58` `STOCK` FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20, held by Colony Stores. Builders `OWNER_HOME` HOME_WORLD (`home_builders.gd:40`). BUT `landing.gd:124-146` `_shelters` adds LANDLORD plants (blocks of 50 finished homes, one per founding household) placed on the town grid in month one. | DIFFERENT | Finished buildings stand at the start: the landing shelters are placed LANDLORD plants. This follows Wilma's decision 12.2 #11 ("people still have to sleep somewhere"), not the user's words. Everything else SAME. |
| 43 | 673-674 | "no the old system and the new for five years are not the same" | No "five years of running costs" for builders; builders land with `BUILDER_CAPITAL_MONTHS := 3` months of wage bill (`landing.gd:60`, `:99`). | SAME | |
| 44 | 759 | "start answering all the fucking questions that have obvius answers i don't want to hold you fucking hand for every decision" | Process instruction; nothing to build. | SAME (N/A, process) | |
| 45 | 797-798 | "It sells too cover all monthly expences" | `rules.gd:149` `hold_back`: below the making price it offers what covers wage bill + this month's booked inputs + upkeep, holds the rest. | DIFFERENT | "All monthly expenses" is narrowed to wages, inputs and upkeep: the month's adverts (`adverts`), layoff pay (`layoff_paid`) and debts paid through the law (unpaid wages, layoff pay) are booked expenses not counted. Loan repayments: step 5. |
| 46 | 809-810 | "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | `rules.gd:46` `K_PM := 50`; `step_pm` (`:111`) = k x num/(num+den); full k when sold 0; no move with no signal; same both ways; the builders' BW price uses it (`:89`). | SAME | |
| 47 | 816 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" | `rules.gd:50` `G_PM := 50`; `output_rule` (`:168`) never above 1000‰. | SAME | |
| 48 | 836 | "the same signal says the work is covered" (rule 8) | `rules.gd:653` `founding`: only the share test (work x own sixths / (all sixths + own) >= running cost). No test of the work in quantity against what the plants seen deliver; `work()` (`:615`) is money. | DIFFERENT | Rule 8 as written (work in quantity covered by what the seen plants deliver -> no plan of any size) is not in the code; the share test alone still stands in for it, which the paper says was the state "before 2026-11-18". Step 3 item. |

**DIFFERENT rows: 5** (rows 2, 5, 42, 45, 48). Rows 5 and 2 are the same difference (the hiring offer is per tier+area, not per post).

#### Table 2: proposals, readings, decisions and starting numbers in the slice

| paper line | the proposal / number | what was built from it (file:line) |
|---|---|---|
| 418-422 | (proposal) negotiation once a year, before quitting/union; how far depends on the manager's skill and on whether the company can pay; never above the average, never lowers; failed -> quit or unionise | `households.gd:490` `NEGOTIATE_MONTH := 7`; `_negotiate` (`:1072`) asks halfway to the average (Wilma/Maja's "halfway"), granted if the account holds a year of the rise; `company.gd:734` refuses lower or above average. The manager's skill (`chief.mgmt`) is NOT read. Union: step 9. |
| 423-424 | (proposal) average among the same kind of post | `company.gd:708` `avg_pay(cid, tier)`: per tier, whole company. Built. |
| 426-430 | (proposal) signal lines for salary rules 1, 2, 9 | Replaced by the user's ruling (435-449); not built. |
| 469 | Wilma's reading: "3 5x" = 3.5 x rent | Trial only; superseded by 2 x. |
| 485-488 | Wilma's reading: 2.5 = 2.5 x rent x tier share; later openings at the placed companies get 2 x | `rules.gd:207`, `:276` `placed_salary`; `households.gd:194`. Built. |
| 498 | Wilma's reading "10 people each" | FARM qty 240 / 24 posts (`type_table.gd:68`). Built. |
| 509-510 | (proposal) "their needs" = housing and food where they live | `rules.gd:299` `needs_line` = cheapest rent + 2.5 x cheapest food, at the company's area (`households.gd:195`). Built. |
| 511-512 | (proposal) only pay moves a salary; open posts for lack of housing/skill not a reason to raise | NOT built as written: `salary_rules` climbs on any post open a whole month whatever the reason. |
| 527-528 | (proposal) how much to stock: as far as money reaches and goods keep; nobody stocks far ahead on food | Companies: up to 2 months' need, only inputs spoiling < 50‰, at <= 800‰ of worth (`making.gd:22-23`, `:202-210`; numbers are Bob's). Households: food toward 6 months (the user's 15f, overrides). |
| 529-534 | Wilma's decision: AHEAD buys only what NEED orders leave, at today's price; counts as spending for rule 7; its shortfall not unmet demand | `market.gd:161` NEED cleared before AHEAD; `_summarise` (`:338-341`) counts AHEAD's bought part in "ordered"; `_turned_away` only for NEED (`:225`). Built. |
| 541 | (open) owners' money | Not built (step 5). |
| 555-556, 573 | (open) taxes, budget lines, reserve; ship schedule/fleet/hold/prices | Ship: `ship.gd:30-33` START numbers (hold 3000, home price 2 x start, 200 settlers a call). Taxes etc.: not built. |
| 582-583 | (proposal) the building contract is its own record | `building.gd` table "contract" (`:10-15`, `:310`). Built. |
| 605 | (proposal) land = 10% of the building bill | `type_table.gd:31` `LAND_PM := 100`; `building.gd:76` `bill_cr / 10` without a site. Built. |
| 640 | (proposal) (9.9 end, struck-shutdown not read as idle) | Not built (step 9). |
| 676 | (proposal) landing stock holds food | `landing.gd:58` FOOD 12000 (twelve months for the founding thousand). Built. |
| 686, 688, 698 | (open) budget headroom, union federation, press outlets | Not built. |
| 722-723, 755 | (open) storage space; quality/reputation; district list replacement | Not built. |
| 766 | 12.1 #1 an area grows from where homes and plants are built; month one one area | `area_store.gd:175` `found_landing`. Built. |
| 768 | #2 districts drawn by the government from areas | `law/districting.gd` (not audited in depth); `grants.gd:90` an undistricted area stands for itself. |
| 770 | #3 land belongs to the colony; plans buy land | `building.gd:284` plan buys the land at signing (`LandLaw`). Built. |
| 772 | #4 a square holds one full size per type | Siting in `transport/site.gd` (not audited in depth). |
| 773-774 | #5 plant site chosen by the siting code; pays its connection | `month.gd:150` `Site.choose_country/choose_town`. Connection payment: not checked. |
| 775-776 | #6 buildings kept/rebuilt/bought | Not built (step 6). |
| 777-778 | #7 order of the month: trade, production, settlement, rules, households | `month.gd:43`, `:51-64`. Built. |
| 779-780 | #8 money at the start set by us | `landing.gd:59` treasury 2,000,000; `:60` builders 3 months' wages. Built. |
| 784-785 | #9 landing stock is the colony's, sold by the government at starting prices; food is Wilma's addition | `landing.gd:150` `_stores` (price_fixed), `stores_takings` to treasury (`:311`). Built. |
| 786 | #10 settlers as in the old game, numbers new | Population side (not audited). |
| 787-788 | #11 first homes are landing shelters, housing office, low rent | `landing.gd:124` `_shelters`, rent 97 (`:54`). Built (see table 1 row 42). |
| 789 | #12 no roads beyond the landfall place | Not checked. |
| 790 | #13 the port at the landfall place, government's | `ship.gd:132` `port_tile` = landfall. Built. |
| 794-798 | #14 making price = month's cost (inputs, wages, upkeep, rent, freight, interest) / normal full output; repayments not a cost | `making.gd:~140-161` `making_price`: (wages_due + inputs + upkeep + other) / full output of open plants. Built (rent/freight/interest: `other`, none in step 3). |
| 799-808 | #15 price move k x s/(1+s); s definitions; refusals count for the cut | `rules.gd:111-143`. Refused orders enter the cut only through the seller's unsold stock (`unsold = offered - sold`); `sig["refused"]` is logged but not added. |
| 813-820 | 15b (Bob) output move g x s/(1+s), never above full | `rules.gd:168-193`. Built. |
| 821-825 | Bob's reading: levels in whole per mille; cut floored; rise at least one post's share of full and at least 1‰ | `rules.gd:190`. Built. |
| 826-828 | 15a rule 7's work: spent or tried to spend, averaged over the last twelve months, at today's prices | `rules.gd:615` `work`: NEED orders + AHEAD bought (`market.gd:338`), averaged over the months of history there are, x today's cheapest offer (else start price). Built. |
| 829-835 | Bob's reading: twelve months summed and divided by 12; first-year missing months counted at the grant's need (persons x need) | NOT built: `work()` divides by `h.size()` (the months there are, `rules.gd:625`), no filling of missing months at the eating need. |
| 840-848 | Bob's/Wilma's reading: what a plant seen delivers (made less family, 12 months, unlived months at full; plans booked/granted at full) | NOT built (rule 8 in quantity absent, table 1 row 48). Booked/granted plans counted by sixths in the share test: `rules.gd:663-677`. |
| 849-851 | 15a shares by plant size (1/6, 1/3, 2/3, 1), own included | `rules.gd:656-681` (sixths 1, 2, 4, 6). Built. |
| 852-853 | the test: share covers running cost; largest passing size money reaches | `rules.gd:683`; `month.gd:136-165` `_found_one` from the largest passing size. Built. |
| 854-858 | Bob with Wilma's yes: running cost = posts at the area's STARTING SALARY (2 x rent), inputs at today's offers, upkeep (quotes the user's "fall back to the original rule for settin on hire") | NOT built: `rules.gd:633-645` `running_cost` still charges `TypeTable.salary(t)` = `SALARY_G 300` x tier (`type_table.gd:292`), the type table's flat 300 a G post. |
| 858-859 | the same figure is the founder's opening money (rebuild-building.md 4.2 "three months of the new company's running costs") | `building.gd:44` `OPENING_M := 3`; `founder_needs` (`:84-86`) = land + building + 3 x `running_cost` (so also at 300 a post). |
| 860 | founder's skill and risk bend the reading (12.11, 77) | Not found in `founding`/`_found_one` (chief record exists, `company.gd:52`, unread here). |

Other numbers met in the code that the slice relies on (starting numbers of ours, no user words): `landing.gd:54` SHELTER_RENT 97; `landing.gd:58` landing stock; `grants.gd:48` PROGRAMME_M 24; `grants.gd:49` EXTRA_PM 100; `econ_publish.gd:37` GRANT_START_PCT 50; `making.gd:22-23` 800‰ / 50‰; `market.gd:30` ship goods 250‰ dearer; `ship.gd:30-33`; `company.gd:129-130` training 6 months from 500‰.

---

### Audit C: planning/rebuild-company.md lines 860 to 1423 against game/sim

Read-only audit, 2026-11-18. Paths below are relative to `game/sim/`. "rules.gd" is `economy/rules.gd` and so on.

#### Table 1: the user's own words in the slice

| # | paper line | the user's words (verbatim, short) | what the code does today | verdict | if DIFFERENT: what differs |
|---|---|---|---|---|---|
| 1 | 864 (15a) | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | rules.gd:651-686 `founding`. The plants that stand, plus `Building.booked` (building.gd:106/128: plans with status SIGNED, by sixths), plus MADE plans that are in `Grants.granted_plans` (grants.gd:323: grant row PAID, plan MADE or SIGNED), each plan counted once. A plan only MADE without a grant is not counted. `share = work*six/(have+six)`. Used by month.gd:137 `_found_one` and building.gd:92 `passing_sizes` (the re-read before signing uses except_plan). | SAME | (Stale comment at month.gd:124-125 still says "a plan does not" count; the code does count it.) |
| 2 | 869 (15d) | "He should look for the shortest time" | building.gd:251-273 `sign_round`. Quotes sorted by earliest `start`, then lowest `total`, then builder id. The plan then signs the first quote in that order **that its money covers** (`have >= land + total`). If it can cover none, it waits a month. | SAME, with an addition (UNSURE) | The paper says "takes the quote with the earliest start". The code takes the earliest start *it can pay for*. When the soonest quote is too dear, it signs a later-starting one instead of waiting. The paper says nothing about this case. |
| 3 | 872 (15e) | "ship food should be considered less desierable,bwich would men the swap happens sooner" | market.gd:30 `SHIP_LESS_WANTED_PM := 250`. market.gd:79-92 `offers` ranks each offer at `price*(1000+250*ship_share)/1000`, and the buyer pays the real price. households.gd:681 `food_by`: a buyer whose budget covers its whole need buys by RANK; otherwise it buys by real PRICE. | SAME | The PRICE fallback for short-of-money buyers is Wilma's addition (Table 2). |
| 4 | 873-878 (15e) | (the answer to "does the family … work it themselves, without wages?") A family farm with no money still grows food | rules.gd:518 `family_to_posts`: every month the founder's adults fill the posts of the first **open** plant (`Company.family_fill`), with no wage (company.gd:589 `family_set`; not in `staff`, so not on the payroll). company.gd:538 `hire_wanted` hires only for the posts the family leaves. But see row 5: a farm whose hired hands are all laid off unpaid is closed, and then makes nothing (making.gd:52). | DIFFERENT | "A family farm with no money still grows food" fails. With no money, the hired hands are laid off (rules.gd:338-345). Then rules.gd:346 sees `staff_count == 0` (staff_count, company.gd:463, counts the hired staff only, not the family) and closes the plant. After that `family_to_posts` finds no open plant, and the farm grows nothing. |
| 5 | 881 (15e) | "FARMS DON'T SHUT" | Callers of `Company.close_plant` (company.gd:853): (a) rules.gd:347 `staff_to_posts` 19a branch: if `wages_due > 0 and paid < due`, it lays off `ceil(n*(due-paid)/due)` per tier per plant key. Any non-crew plant left with `staff_count(...)==0` is closed, reason NO_STAFF. There is no type check, so FARM is included, both family farms and larger farms. The family is not counted in `staff_count`. (b) building.gd:629 `open_due`: it closes a plant with reason LAW when `LawCompany.may_open` fails. FARM has `hazard: false` (type_table.gd:70), and `licences_required` (law_company.gd:133) asks only HAZARD or MINE licences, so a farm is never closed here today. Reopening: only law_company.gd:210 `reopen_licensed`, for plants on the `law_closed` list. Nothing reopens a NO_STAFF plant. econ_face.gd:571 `inst_reopen` is a stub that returns not-ok. | DIFFERENT | A farm is still shut by 19a (rules.gd:346-347) when its hired staff fall to 0 after unpaid wages, even while the family works it. It is never reopened. This is the same mechanism as the 40 farms in the five-year run. |
| 6 | 885 (15e) | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" | households.gd:610-617 `post_orders`. For a founder whose FARM (any size; `own_farm`, households.gd:665, needs type FARM, status OPEN, family_of == founder), `Making.family_take` (making.gd:126) first takes `need + min(need, max(0, 6*need - held))` from the farm's whole stock, with no money. This runs in SETTLEMENT before `Market.clear`, so the take is never offered. The market NEED order is for `need - farm_eat`. | SAME | |
| 7 | 885 | numbers: "THEY ARE THREE", "PRODUVE 30", "TAKE SIX OUT OF THIRTY", "SELL 24", "ENOUGH TO HIRE ONE PERSON" | A family FARM in type_table.gd: posts = round(24*1/6) = **4** (G3, S1, Sp0, type_table.gd:240). Output at full = 240*1/6*(1-0.060) = **37.6 FOOD**/month (type_table.gd:250). Family size = adults + children (households.gd:1441), not fixed at 3. HOUSEHOLD_PERSONS_PM = 2.5 (rules.gd:54) is used for the needs line. The take of "six" is the need plus one month to the store (row 6), which matches the user's picture. Whether 24 sold pays one hire depends on the FOOD price and the hiring salary (rules.gd:271: 2 x area rent x tier share). Not computed here. | SAME in the mechanism; numbers UNSURE | The user's 30 a month for a family farm is not the table's 37.6, and the posts are 4. These may be meant only as an illustration. Whether "24 sold hires one" holds cannot be shown without a run. |
| 8 | 893 (15e) | "the farm would be their home, wich means they are paying on any loans they had to take and uppkeep" | landing.gd:282-287 `rent_due`: a founder for whom `lives_on_own_farm` is true (landing.gd:298: owns a plan whose company is FARM, FAMILY, OPEN) pays no rent. households.gd:542-545 `homes`: such a family is not counted as a household in town. Upkeep and the debts paid are taken off before winnings (rules.gd:564-566). | SAME | Loans are step 5 (not built). Today `debts` = Justice.paid_this_month. |
| 9 | 899 (15e) | "I think two is better" (a loss is carried forward) | rules.gd:568-573 `winnings`: `pays_down = clamp(earned,0,carried)`, `carried_after = carried - pays_down + max(0,-earned)`. The family takes only what is beyond that. Stored in `loss_carried` (rules.gd:597). | SAME | |
| 10 | 899/903 | "maybe the family can put some away for the hard months they know are coming" | The paper marks it as noted, not built. The code has no family-side holding back. But rules.gd:567/575 `winnings` caps the family's take at `balance - keep`, where `keep = wage_bill + inputs + upkeep` (one month of the hired staff's wages, inputs and upkeep, kept in the company's account). | NOT BUILT (step 4, as the paper says), but see row 11 | |
| 11 | 912 (15e) | "The owners of a family farm should take winnings no sallery, wich comes after and saves the issue" | rules.gd:560-575 `winnings`: `earned = rev - inputs - wages - upkeep - adverts - layoff_paid - debts - winnings already taken`. `amount = max(0, min(earned - pays_down, balance - keep))`. Paid in JUSTICE after collect_debts (month.gd:168, rules.gd:587). No salary: the family is not on the payroll. | DIFFERENT (in one part) | The paper says the family takes "what is left of the month's takings after everything else the farm owes that month is paid". The code also holds back one further month of the hired wages, inputs and upkeep (`keep`) in the company before paying any winnings. That reserve is not in the user's words or in the paper (it comes from Bob's reading). Everything else is SAME. |
| 12 | 923 (15f) | "they buy 2 units if food instead of one, store it and use it in emergencies" | households.gd:620-645: the NEED order covers the month's need, and a second AHEAD order is `min(need - farm_store, 6*need - held - farm_store)`, so at most one extra month. households.gd:744-747 `after_market`: it eats what was bought this month first and draws on the store only when that falls short. | SAME | |
| 13 | 924 | "They stockplie to have have six months of food in storage, i think as often as they can" | households.gd:498 `STORE_MONTHS := 6`. The store order is placed every month while below 6 months and the money allows (`store_budget`). | SAME | |
| 14 | 926 | "The first, if your running low and don't know how long the ossue will last i don't think you wait" | The store order's max price = `store_budget` (any price the money left can pay). It is capped only by `store_budget*S/cheapest` units. There is no waiting for a better price. With nothing on offer it posts none. | SAME | |
| 15 | 933 | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | As row 12: never more than one extra month's need a month, until 6 months are held. The farm's take is counted in the double too. | SAME | |
| 16 | 948 (15c) | "No they should not cut for the start" | building.gd:663-666 `seller_signal` returns {} until `first_quote_month >= 0` (set in sign_round, building.gd:246-249, when the first plan asks for quotes). rules.gd:116 `price_rule` returns unchanged on an empty signal. | SAME | |
| 17 | 948 (15c) | "they should not increase prices for claimed jobs" | The book of waiting contracts is not read as unmet. `unmet_above` = `unmet_wait_bw`, which is filled only in sign_round (building.gd:289-292). A plan that **signs** this month with `start > month+2` adds its whole BW bill once, as unmet, to that builder's next signal (building.gd:716). That feeds R1 (raise). | DIFFERENT (in part) | Paper line 950: "work signed and waiting in its book is not a customer turned away". The code still counts each newly signed job that waits behind the book as unmet demand, once, in the month it signs. So a claimed (signed) job does raise the price once. This is Wilma's decision (building.gd:288-290), not the user's words. |
| 18 | 955 (15c) | "At start id assume they know work is coming" | The same {} signal before the first quote means `output_rule` returns (rules.gd:170). So the crew level does not fall and `staff_to_posts` makes no LEVEL layoffs. home_builders.gd places the crews at landing. | SAME | (19a unpaid layoffs still apply, but that is not about the empty book.) |
| 19 | 977 (23a) | "if they want to but can't buy, bread goes too high — the company can win by lowering" | Unsold stock (`offered - sold`) drives R2 (rules.gd:122-133). A buyer whose budget runs out at the price leaves goods unsold. NO_MONEY orders carry max 0. | SAME | |
| 20 | 1008 (35) | "they should become individually counted on company start … don't malt to many people to track" | month.gd:155 `Households.make_founder` runs when the plan is made (before `Building.make_plan`), so it is one person per founder. Everyone else stays in the pools. | SAME (on Wilma's reading that the plan is the start, 60a) | |
| 21 | 1062 (50c) | (paraphrase) the user's decision of 2026-11-14 that bank lending must be able to grow the money stock | There is no bank lending in economy/ (no lending function or loan record found). | NOT BUILT (step 5) | |
| 22 | 1112 (61a) | "when a grant ends, they reset to zero so they have to start over on where to put it; grants should be limited time for when you can apply" | grants.gd:47 `PROGRAMME_M := 24`. grants.gd:345-364 `monthly` opens a programme when the lever is above 0 and ends it at `until`. `_end_programme` calls `LawOps.end_programme`, which puts the lever to 0. gov_builder.gd:555-561 erases `grant_cover` and `grant_sum` when the lever is 0. All four levers start at `GRANT_START_PCT := 50` (econ_publish.gd:37, 63-69), so they are open in month one. | SAME | |
| 23 | 1113 (61a) | "and where it covers too" | gov_builder.gd:560 `cover.erase(kind)`. A new programme chooses its districts again. | SAME | |
| 24 | 1119 (61b) | "The government should put a max sum into the grant based on how many darms they want maybe a little extra to be sure" | gov_builder.gd:630 `_grant_sum`, called when a programme opens, sets `Grants.budget_for` (grants.gd:300): `wanted * grant_planned * 1.1` (`EXTRA_PM := 100`). grants.gd:310 `sum_left`. `apply` refuses when what is left is under a grant. `quote` returns 0, so `pick_founder` can still pick a household that pays alone. | SAME | |
| 25 | 1163 (12.11) | "I think most of these needs to be worked in" | Points 77-109: mostly not present in economy/ (management, upgrades, mothballing, credit lines, home-world grant and others). The public works department exists (home_builders.gd, `ORIGIN_PUBLIC`; rules.gd:81). | NOT BUILT (mostly; the build order gives no step for most of 77-109) | UNSURE about which step each point belongs to. |
| 26 | 1277 (13, step 4) | "Can we add a prefernce for farms not being close to towns? … the government picks a spot away from towns …" | transport/site.gd:139 `choose_country` scores country sites away from settlement and town tiles (this existed before). No government grant "spot" in grants.gd, gov_builder.gd or site.gd. | NOT BUILT (step 4) | |
| 27 | 1278 | "Save it for when trucks and roads come Mark it for then" | As row 26. | NOT BUILT (step 4) | |
| 28 | 1282 | "1 . Far away wnough that a few years of development wont merge them, 2. … more spots would be more expencive … 3. Most comonly the government … 4. No farms payed fully from saving does not" | Nothing built. | NOT BUILT (step 4) | |
| 29 | 1301 (step 8) | "Mark that the government can order stockpiles to help in famin once we get back to politics" | No "stockpile" in politics/. | NOT BUILT (politics, later) | |
| 30 | 1309 | "Get everyone involved give them peaces … atleast one other reviews each peace of code made" | A process, not code. | n/a (process) | |
| 31 | 1321 | "Can we have a backend column somhere that records all things happening like a log we can investigate from?" | core/logbook.gd: `note`, `rows`, `counts`, `story`, `write`, `trim` (keep_months). Rows live on `world.log_rows`, which is not saved or hashed. | SAME | |
| 32 | 1394-1396 (watch-for 8) | (paraphrase) plans are NOT counted in rule 7's shares; "the user ruled that out as protecting companies from failing" | rules.gd:661-672 counts booked and granted plans (row 1). | DIFFERENT (the paper contradicts itself) | Line 1395 says plans are not counted. The later ruling of 2026-11-17 (15a, line 864) says booked and granted plans are seen, and the code follows 15a. The paper line is stale. |
| 33 | 1414 (14) | "not finished buildings" (the ruling on the landing) | landing.gd:12-13, 53-54: a state LANDLORD (the housing office) whose plants are the landing shelters, with `SHELTER_HOMES := 50` and `SHELTER_RENT := 97*S`. | DIFFERENT (flagged in the paper as Wilma's decision) | The user's ruling is "not finished buildings". The code gives the settlers shelter homes anyway, as Wilma decided and flagged. |
| 34 | 1417 | "give the others a new chance … review the whole thing from their perspectives" | A process, not code. | n/a (process) | |

#### Table 2: proposals, readings and starting numbers in the slice with no user words behind them

| paper line | the proposal / number | what was built from it (file:line) |
|---|---|---|
| 860-861 | A founder's management bends the reading; "nothing limits how many may plan at once" | month.gd:126-131: the `while _found_one` loop has no cap. Management (77) is not built. |
| 865-867 | Wilma's "So": a booked or granted plan counts "by its size" | rules.gd:661-672: counted in sixths (building.gd:117 `_plans_at`). |
| 871 | Before the ruling: the lowest price, with the start used only as a tie-break | Replaced. building.gd:253 now sorts by start first. |
| 874-876 | Wilma's decision: the months of layoff pay follow the law on the day of the layoff | population/households.gd (layoff, near line 268): `WorkLaw.layoff_pay_months(world)` read at the layoff. Also rules.gd:481. |
| 896-898 | **Wilma's:** the farm is the home from the day it opens; while a plan, the family pays its old rent; the home it leaves is free; a bakery is not covered | landing.gd:298 `lives_on_own_farm` needs FARM, FAMILY, status OPEN. households.gd:1540 `lives_apart` and :544. "The home it leaves is free": UNSURE (not traced). |
| 904-907 | Wilma's reading of "put some away": the family lives on winnings it does not spend; nothing more built | No family-side reserve. But rules.gd:567 `keep` (one month of the hired wages, inputs and upkeep held in the company before winnings) is Bob's, with no paper line (see Table 1, row 11). |
| 909-910 | **Wilma's details:** the founder household's adults fill the posts first; the rest are hired for wages | rules.gd:518-542 `family_to_posts`; company.gd:626 `family_fill`; company.gd:538 `hire_wanted`. |
| 916 | Wilma: winnings hold for every family-size company | building.gd:621-624 `family_set` for every FAMILY size, not only FARM. Eating first and the home stay FARM only (households.gd:665, landing.gd:298). |
| 917-918 | Ship food counted a quarter dearer ("A starting number") | market.gd:30 `SHIP_LESS_WANTED_PM := 250`; market.gd:91. |
| (no paper line) | Wilma's 15e decision: a buyer who cannot cover its whole need buys by real price, not by rank | households.gd:681 `food_by` ("RANK" or "PRICE"); market.gd:51. |
| 938-941 | **Wilma's details:** the store comes after food, then rent; stored food spoils; replaces the 2-month cap | households.gd:628-631 (store_budget = money - food_cost - rent); households.gd:752 (spoil at FOOD's 10 per mille); STORE_MONTHS 6. |
| 942-943 | The idea not chosen: tell farmers winter is coming, 10% hidden stock | Nothing found (no "hidden stock" or similar in the code). |
| 952-953 | **Wilma's reading of "the start":** until the first plan asks for a quote | building.gd:41 OPENED, :246-249 sets `first_quote_m`, :664-665 `seller_signal` is {} before it. |
| (no paper line, in code) | Wilma's decision: a plan that signs to wait behind the book counts as unmet once | building.gd:286-292; building.gd:716. See Table 1, row 17. |
| 957-991 | Rules 16-29, the plan's own: 18 (rule 3 not while holding back), 19a (lay off unpaid; a plant with no staff is shut), 22 (slot types do not hold back), 23 (hunger from need), 23a, 28 (no speed limits on hiring) | 18: rules.gd:168 `up := 0 if holding`. 19a: rules.gd:338-351 (this is the clause that shuts farms, see Table 1, row 5). 22: rules.gd:90 builder `output_rule(..., false)`. 23: households.gd:748-751. 23a: market.gd order `max`/`budget`. 16, 17, 20, 21, 24-27, 29: later steps, not checked further. |
| 1017-1025 | 37/37a: the starting salary formula (1.5 x (rent + household food)); prices fitted to it | type_table.gd:395 `salary_line`. But rules.gd:203/271 `starting_salary` is now 2 x area rent x tier share (from later 9.2 rulings outside this slice), so 37 as written here is not what hiring uses. |
| 1060 | The bank's capital ratio "set by us" | Not built (step 5). |
| 1079-1080 | 53a: a dead company's stock goes to the bank at the market price less 10% (Wilma's choice) | Not built (step 5). |
| 1100-1102 | 60a: **Wilma reads the plan as where a company starts** | month.gd:155 `make_founder` before make_plan. |
| 1115-1116 | 61a: a window of 24 months ("a starting number of ours") | grants.gd:47 `PROGRAMME_M := 24`. |
| 1123-1124 | 61b **Wilma's reading:** the bakery, truck driver and workshop grants get a sum the same way | grants.gd:252-275 `wanted`: BAKERY = the whole food need as bread, over a family bakery's output; TRUCKER and TRUCKSHOP = one per area with none standing or planned. |
| 1125-1126 | 61b **starting numbers:** farms to feed the colony at full output; the extra is one tenth | grants.gd:252-266: `ceil((need - output of farms standing and plans MADE/SIGNED) / family-farm output)`. It subtracts what stands and is planned (Wilma: "how many more"; the paper line says only "what it takes to feed the colony"). grants.gd:48 `EXTRA_PM := 100`. grants.gd:300 `grant_planned` uses the largest grant over the areas. sum_left adds back what given-up plans repaid (Wilma). |
| 1138-1139 | 65: the user's ruling for utilities "applied to all types" (Wilma's widening) | No law forbidding a private type found. Not built (later step). |
| 1290-1295 | Wilma's view and staging for the grant spot | Not built (step 4). |
| 1348-1351 | Food in the landing stock (Wilma's decision 12.2, 9); 12 months food / 4 months build as an outside run's figures | landing.gd:51 STORES "Colony Stores" holding the landing stock. The exact food months were not checked. |
| 1414 | Landing shelters (Wilma's flagged decision) | landing.gd:53-54 `SHELTER_HOMES := 50`, `SHELTER_RENT := 97*S`. |

---

### Audit D: rebuild-households.md and rebuild-building.md against the code

Read-only audit, 2026-11-18. The code was read in the shared tree `game/sim`. Build order: rebuild-company.md section 13.
H = planning/rebuild-households.md, B = planning/rebuild-building.md, RC = planning/rebuild-company.md.

#### Table 1: the user's own words

| # | paper:line | the user's words (verbatim, short) | what the code does today | verdict | if DIFFERENT |
|---|---|---|---|---|---|
| 1 | H:7 | "we take how it works and transfer over not take the code" | A process ruling. households.gd and demography.gd are new files written against the joins; no code in them is copied from game_full_copy. | SAME (process) | |
| 2 | H:8 | "Oh no wholesale does not mean unchecked" | A process ruling. H section 3 checks every old mechanism; the code follows the verdicts I sampled (P1 keys area\|band\|skill; H6 no food aid; I5 no switch). | SAME (process) | |
| 3 | H:27 | "don't malt to many people to track" (pools stay; founders counted one by one) | households.gd:42 `pool_id` = area\|band, with one account per pool; founders are in table "founder" (households.gd:486, `make_founder` :1199) and return through `release_founder` :1256. | SAME | |
| 4 | H:148 (RC 9.2: "But emplyees only apply to jobs that meet their needs") | workers apply only to jobs that meet their needs | households.gd:884 `applicants`: returns 0 when pay < `needs_per_worker` = `Rules.needs_line` (rules.gd:299) = the cheapest landlord rent + the cheapest FOOD offer × household persons. | SAME | |
| 5 | H:149 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | households.gd:993-1018: QUIT_BAR_GOOD_PM 100 (10%), +QUIT_BAR_PER_YEAR_PM 10 (1%) per full year (`years_at` = months/12), capped by QUIT_BAR_MAX_PM 150 (15%); `clears_bar` new ≥ old×(1+bar). "Less if stressful" is a stub: `quit_bar_base_pm` always returns 100 (stress is step 9). | SAME (the stress part is NOT BUILT, step 9) | |
| 6 | H:154 (RC 9.2: "On the workers rules i belive you have the right of it, and it should apply to builders") | three months of layoff pay, and it applies to builders | households.gd:314 `_layoff_pay`: owed months come from WorkLaw LAW_LAYOFF_PAY_MONTHS (default 3, range 0-12, work_law.gd:28); an unpaid rest becomes a Justice.owe LAYOFF_PAY debt. Builders use the same `Households.layoff`. | SAME | |
| 7 | H:155 / RC 15e | "The owners of a family farm should take winnings no sallery…" | rules.gd:560 `winnings`: revenue less inputs, wages, upkeep, adverts, layoff pay and debts paid, after a carried loss is made good; paid in JUSTICE after everything else (`pay_winnings` :587). The family's posts are on no payroll (`Company.family_set`, building.gd:623). | SAME | |
| 8 | H:155 / RC 15e | "the farm would be their home" ("…paying on any loans… and uppkeep") | landing.gd:285, :298 `lives_on_own_farm`: no rent once the family's FARM of FAMILY size is OPEN. Upkeep comes out before winnings (rules.gd:565). Loans are step 5. | SAME | |
| 9 | H:164 / RC 15e | "ship food should be considered less desierable" | market.gd:90: ship goods are ranked a quarter dearer (RANK). households.gd:684 `food_by`: a buyer that cannot afford its whole need in rank order buys by PRICE. | SAME | |
| 10 | H:165 / RC 9.2 | "the manager, negotiation can bring it closer to avrage" | households.gd:1072 `_negotiate`: in July (NEGOTIATE_MONTH 7), an entry paid below the company's average for its tier asks for half the gap. It is granted if the account holds 12 months of the rise; a refusal writes a row. | SAME | |
| 11 | H:199-201 / RC 15f | "They stockplie to have have six months of food in storage, i think as often as they can" | households.gd:498 STORE_MONTHS 6. `post_orders` :598 places an AHEAD order every month toward 6 × need held. | SAME | |
| 12 | H:201 | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT" | households.gd:634: the store order wants min(need − farm_store, 6·need − held − farm_store), so at most one extra month a month. Its budget is the money after the month's food and the rent. | SAME | |
| 13 | RC 15f (H:201) | "if your running low and don't know how long the ossue will last i don't think you wait" | The AHEAD order's worth = its whole store budget (households.gd:646), so it pays any price the money reaches. | SAME | |
| 14 | H:202 | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" | households.gd:611-617: before any order, `Making.family_take` (making.gd:127) takes need + up to one month for the store from the farm's stock, with no money. Offers are read from live stock at clear (market.gd:86), so the family takes before anything is sold. | SAME | |
| 15 | H:202 | "THEY ARE THREE THEY CAN PRODUVE 30 … TAKE SIX OUT OF THIRTY SELL 24 … ENOUGH TO HIRE ONE PERSON" | The family is not three. `_family_take` (households.gd:1408) gives the founder + (adults per household − 1) ≈ 0.95 + children ≈ 0.55, so about 2.5 persons and about 2 adults (HOUSEHOLD_SIZE 2.5). A FAMILY farm has 4 posts; output = 240×1/6×(1−0.060) = 37.6 at full, 9.4 per worker, × the season's yield (making.gd:72, type_table.gd:16). The take = family persons × 1 + the same for the store. | DIFFERENT | The rule (eat first, take double, sell the rest, 4 posts so one hire beside three) matches. The user's figures do not: about 2.5 persons, not 3; 9.4 a worker at family size (6% size penalty), not 10; and the season changes it. So the take is about 5 of about 28 in an average month, not 6 of 30. |
| 16 | B:13 / RC 8.1 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES … BEFORE ACCEPTING A GRANT" | month.gd:158-163: `Building.make_plan`, then `Households.own`, then `Grants.apply(plan)`. A plan is its own table (building.gd:151). It becomes a company only in `open_due` (:602). | SAME | |
| 17 | B:14 | "you can't fail before you exist ... no worker but also no expenses beyond building" | A plan record has no staff, stock or price (building.gd:151). Its account pays only land (`Site.buy_land`), the contract bill (`bill_month`) and site supplies (Market SITE orders). It is never counted as a company. | SAME | |
| 18 | B:15-16, B:183 | "They should not need 90% of supplies up front they should need 3 months up front and add 1 month of additional supplies every month" | building.gd:43 UP_FRONT_M 3. `_ready` :498 needs min(3×month_need, rest) on site before the first work. `supply_orders` :375 tops up to 3 months each month, which is about +1 month for each month worked. month_need = bill × planned_bw/bw, planned_bw = ceil(bw/months). | SAME | Note, not a difference from the words: a job of 3 months or fewer (every FAMILY plan: months = max(2, ceil(full×7/12)), e.g. a farm is 3) has to hold its whole bill up front. |
| 19 | B:17 | "5 building companies and alot of oppretunity" | home_builders.gd:33: five, LARGE + 2 AVERAGE + 2 SMALL, so 60+40+40+20+20 = 180 crew, owned by the home world, placed (not hired) and trained. The public works department is a sixth, state-owned, and not for hire (building.gd:184). | SAME | |
| 20 | B:17-18 | "materials come with the start not finished buildings" | landing.gd: no plant for the power, water, transit, clinic, school or police subsidiaries; Colony Stores holds STOCK {FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20} at fixed starting prices (price_fixed). The landing shelters ARE plants (8 LANDLORD blocks), by the separate 12.2-11 ruling. | SAME | |
| 21 | B:17-18, B:127 | "5 years worth of equipment that never changed they are companies from the world" | The builders are owned by the home world (OWNER_HOME). landing.gd:58 reads "5 years worth" as the size of the landing stock: MATERIAL 9700, COMPONENT 1060 = "five years of the five builders' full work". | UNSURE | It is not clear the user meant the stock size. And five years at 176.8 BW a month is about 10,600 BW, at about 1 MATERIAL per BW for most bills, which is more than 9,700. How Bob got 9,700 is not in the code. |
| 22 | B:165 / RC 15d | "He should look for the shortest time" | building.gd:253 sorts by earliest start, then lowest total, then builder id. :269 takes the first quote in that order that the plan's money covers (land + total). | SAME | |
| 23 | RC 15c (brief) | "No they should not cut for the start" | building.gd:663 `seller_signal` returns {} until `first_quote_month` ≥ 0 (set in sign_round :247), so `price_rule` (rules.gd:122) makes no change. | SAME | |
| 24 | RC 15c (brief) | "they should not increase prices for claimed jobs" | building.gd:291: a plan that signs with a start later than month+2 adds its whole BW bill to "unmet_pending". `_month_set` moves it to `unmet_wait_bw`, and `seller_signal` returns it as `unmet_above`, so `price_rule` R1 raises the BW price by k·unmet/(unmet+sold). This happens once per signed job. | DIFFERENT | A signed job that waits in the book is a claimed job. The code counts it once, in the month it signs, as unmet demand that raises the price. The user said claimed jobs do not raise prices, and RC 15c's bullet says "work signed and waiting in its book is not a customer turned away". The once-only count is Wilma's decision (the comment at :288), not the user's words. |
| 25 | RC 15c (brief) | "At start id assume they know work is coming" | The same {} signal means `output_rule` (rules.gd:169) returns, so there is no R4 crew cut before the first quote. The crew level starts at 1000 (company.gd:54). | SAME | |
| 26 | B:253 / RC 8.1:243 | "It ends only if its owner gives it up (no builder, no money)" (quoted in B; whether these are the user's own words or the plan's is UNSURE) | `give_up` is called (a) when no builder can be hired (building.gd:236), (b) when rule 7 no longer passes the plan's size before signing (:239-241), and (c) when a STOPPED job's plan holds less than it owes (:590-593). A plan short of money for a quote waits; a law refusal waits. | DIFFERENT | (b) is a third reason, "the work is no longer there (rule 7)", which is neither "no builder" nor "no money". It comes from Otto's 4.4. B:262 itself says "only when no builder is alive, or the plan's account cannot pay a bill". Also, (a) treats a builder whose crew is all untrained or laid off (bw_milli = 0) as "no builder". |
| 27 | B:99 (9.8, "the user's figures") | apartments 0.85 of the block, a tower 1.15 | TypeTable.bill has no form factor. Home forms exist only on Terra's grid (town_grid.gd:29). | NOT BUILT (step 7) | |
| 28 | B:318 / RC rule 5 | "money is a limitor" (rule 5: "if your selling out and all plants at max build a new one") | No rule 5, no SIZE_UP, no buy-out in economy/ (grep). output_rule caps the level at 1000. | NOT BUILT (step 6) | |
| 29 | B:331 (9.8) | homes keep "the user's 55" condition | Not in the code. Plants use CONDITION_FULL_FROM 50 (making.gd:19). | NOT BUILT (step 7) | |

#### Table 2: proposals, readings and decisions with no user words behind them

| paper:line | the proposal/number | what was built from it |
|---|---|---|
| H:84-90 | 1,000 settlers, 400 households of 2.5, 200 per band (150/44/6), 90% LF, skills by band, ages 350/450/200, savings 1,800…36,000, earners about 1.7 | households.gd:26-37: identical constants |
| H:89 | 180 builder crew + 40 public works | home_builders.gd:33-35 (5 builders = 180; PUBLIC_WORKS AVERAGE = 40) |
| H:101-104 (Wilma; Maja's reading of 60c) | a founder keeps their post until the plan signs; until then they eat with their pool | households.gd `_promise_post` :1468, `take_up_posts` :1483, `in_post` :1458; `buyers` subtracts in_post (:564) |
| H:105, H:189 (Bob's review) | a founder takes one household's share = pool balance × 2.5 ÷ persons | households.gd:1118 `household_share` |
| H:116-122 (Otto/Wilma) | shelters: LANDLORD plants of at most 50 homes; rent half a new house's | landing.gd:52-53 SHELTER_HOMES 50; SHELTER_RENT 97 (comment: "which the user doubled") |
| H:151 (Wilma's reading) | 15% caps the whole bar; stress lowers it toward 5% | QUIT_BAR_MAX_PM 150; QUIT_BAR_STRESSED_PM 50 is declared but unused |
| H:179-191 (Maja's additions) | seeded founder draw weighted by households able to pay; unemployed first; one grant per household by count; opening money counted in what a founder must pay | households.gd:1131 `pick_founder`, :1165 `_free_adult`, :1672 `mark_granted`; building.gd:44 OPENING_M 3 in `founder_needs` :84 |
| H:192-197 (Wilma's ruling) | each order's budget is its line's money; food worth = the whole food budget | households.gd:620-625 (worth = food_budget = all money) |
| H:203 (Wilma) | NEED cleared before AHEAD; store shortfalls are not a signal | Market KINDS NEED/AHEAD; the store order is kind "AHEAD" (households.gd:645) |
| H:209-210 (Maja: July, halfway, a year of the rise) | the negotiation's terms | households.gd:490 NEGOTIATE_MONTH 7; :1078-1080 |
| RC 9.2 proposal (H:165) | negotiate first, quit only if that fails | NOT followed as a sequence: `labour_month` (households.gd:1023) runs quitting every month, whatever any negotiation did |
| H:212-213 | leaving share; attractiveness 40/40/20 | households.gd:493 LEAVE_PM 100; :1723 (jobs×4 + fed×4 + homes×2)/10 |
| H:214-220 | life numbers: TFR 4.0, 40% lower at the top band, 90% of 18-year-olds in the LF, 1% re-entry, band EMA 1/6, 10% margin | demography.gd:42-51 TFR_BASE 4.0, TFR_INCOME_FALL 0.4, GROW_LF_PM 900, REENTRY_PM 10, BAND_EMA_PM 167, BAND_MARGIN_PM 100; MORTALITY_PM table :34 |
| H:221 | famine = a quarter uneaten 3 months; scarce = 1/20 | households.gd:775-777 FAMINE_PM 250, FAMINE_MONTHS 3, FOOD_FACT_PM 50 |
| H:241, H:275, H:286 etc. ((decided) rows in section 3) | the verdicts for later steps (rent, services, shacks, pollution deaths) | not built in step 3 (not checked line by line) |
| B:71-73 (Otto) | 1 BW = one worker-month × (1 − size penalty) | home_builders.gd:84 `bw_milli` (trained persons × (1000 − penalty)) |
| B:80-93 (agreed with Bob) | bill table | type_table.gd ROWS "bill": all checked rows match (FARM 240/240/12/4, BAKERY 300/240/24/4, MINE, PROCESSING, COMPONENTS, CONSUMERF, TEXTILE, FURNITURE, MEDWORKS, POWER, WATERWORKS, HAULIER as DEPOT 300/240/48/4, TRUCKSHOP, LANDLORD 1200/720/24/6, OFFICEBLOCK, BANK, BUILDER 120/120/6/2) |
| B:95-97 (Otto) | sizes 1/6, 1/3, 2/3; months = max(2, ceil(full×(1+share)/2)) | type_table.gd:15, :273 (ceil(full×(6+sixths)/12)): same |
| B:104 | builder row 60 workers (36/18/6) making 60 BW | type_table.gd:105: same |
| B:106-107 (proposal) | upkeep 1/400 of MATERIAL a month + 2% BW a year | not found in building/type_table |
| B:116-120 (Otto) | the five builders' sizes 1 large, 2 average, 2 small; 180 crew | home_builders.gd:33 |
| B:124-126 (Otto) | the landing stock posted by the purse at fixed starting prices | landing.gd `_stores`: a state SHOP company "Colony Stores" with price_fixed: true (a company, not the purse itself) |
| B:127-129 (Otto: open for the user) | trucks in the landing stock | landing.gd:58 TRUCK 20 ("enough for the first truck drivers", the step-2 brief) |
| B:140-143 (Otto) | three months of running costs as opening money | building.gd:44 OPENING_M 3; `founder_needs` :84 |
| B:147-149 (Otto/Bob) | founders taken in a fixed order; plans not counted in rule 7 | month.gd `founding` loops types × areas; but rule 7 DOES count booked and granted plans (building.gd:106-114; the user's 15a, which came later than B's text) |
| B:156-157 | estimate = BW × average builder price + materials at market | building.gd:71 `estimate` (cheapest offer, else the start price) |
| B:162-163 | start month from the book at the present crew | building.gd:210 `start_month` = month + 2 + work ahead / crew BW |
| B:170-173 (Otto) | before signing, re-read rule 7; give up if it fails | building.gd:239-241 (see Table 1 row 26) |
| B:174-175 | a plan refuses when the lowest quote exceeds its account, and waits | building.gd:278-281 (waits; the refused quotes go to refused_pending as a cut signal) |
| B:177-181 | at signing: buy land, grant paid, contract with price_bw/wage_bw | the land at signing via `Site.land_terms`/`buy_land`. Under the default LAW_LAND_DISPOSAL = "LEASE" the plan pays the first month's lease rent, not a price (site.gd:480; land_law.gd:181). The grant is paid at MAKING, not at signing (month.gd:163) |
| B:185-187 | planned BW = min(bill/months, the crew the builder can put on it) | building.gd:365 `planned_bw` = ceil(bill/months) only, with no crew term |
| B:188-197 (Otto as Bob proposed) | the supplies order is the client's, at the client's worth | building.gd:393-394 (SITE buyer, the client's account, worth = item price at signing) |
| B:205-209 (Otto) | a blocked job keeps its place; crews go on | building.gd:463 `work_month` |
| B:212-216 | the builder's price rules read unmet BW and refused quotes | building.gd:663 `seller_signal` (unmet = signed-to-wait once; refused = refused_pending) |
| B:225-229 | bill = BW × (price_bw + wage drift); stopped after 3 unpaid months | building.gd:555 `bill_month` (unpaid_m ≥ 3 → STOPPED; resumes when paid) |
| B:242-247 | opens next month; plan money moves; building as an asset | building.gd:602 `open_due`; the cost is recorded on the plan (land/work/supplies); no asset entry in the company books found |
| B:255-260 | given up: builder keeps pay, land stays the founder's, grant owed back, the rest to court later | building.gd:329 `give_up`; grants.gd:214 `reclaim` (plan, then founder, then a Justice.owe debt) |
| B:292-294 (Bob's review) | "The five builders' 180 crew is month one's figure, not a ceiling" | As built it IS a ceiling in step 3: the crew level starts at 1000 (company.gd:54) and `output_rule` never goes above 1000 (rules.gd:189). More crew needs a larger size (rule 5, step 6) |
| B:322-323 (rule 6) | mothball after 12 idle months | not built (step 6) |
| B:327-333 (Otto: 1 a month, 50) | wear and repair | making.gd:19 CONDITION_FULL_FROM 50 is built (a step-6 item now in the code); no wear per month was found |
| B:349-350 (step 6: permits and licences) | a plan applies for a licence when made | built now: law_company.gd:159 `may_sign` (zoning + HAZARD/EXTRACTION licences, applied for in sign_round; the plan waits) and `may_open` (closes the plant without a licence) |
| B:351-352 | how the state picks a builder | not built (the public works department is idle) |

---

### Audit E: rebuild-law-face.md (whole) and MASTER-PLAN.md "The rebuild" sections from line 883 to the end, against the shared tree

Read-only audit, 2026-11-18. Code paths are relative to `game/sim/`. Build order: rebuild-company.md section 13.
Money is in milli-credits (S = 1000) and levels in per mille.

#### Table 1: the user's own words

| # | paper:line | the user's words (verbatim, short) | what the code does today | verdict | if DIFFERENT: exactly what differs |
|---|---|---|---|---|---|
| 1 | MASTER-PLAN:887 | "1 . Far away wnough that a few years of development wont merge them, 2. Upp to the goverment ... 3. Most comonly the government ... 4. No farms payed fully from saving does not" | No grant spot, distance preference or road payer is in economy/ or planet/. A grep for "spot" or "away from town" finds nothing. | NOT BUILT (step 4) | |
| 2 | MASTER-PLAN:896 | "I think two is better" (a loss is carried forward) | economy/rules.gd:560-575 `winnings`: `pays_down = clampi(earned, 0, carried)`, `carried_after = carried - pays_down + max(0, -earned)`, and the family takes only `earned - pays_down`. economy/rules.gd:597 `pay_winnings` stores `loss_carried` once a month. | SAME | |
| 3 | MASTER-PLAN:896 | "but also maybe the family can put some away for the hard months they know are coming" | Nothing is built for it. The only thing held back is `keep` = one month of hired wages, inputs and upkeep (rules.gd:568). That is Bob's reading of a different point. | NOT BUILT (no step: the paper records it as a "maybe", noted but not ruled) | |
| 4 | MASTER-PLAN:905 | "they buy 2 units if food instead of one, store it and use it in emergencies" | population/households.gd:633: the store order is at most one month's need on top of the month's need, which doubles the buying. Farm families get the same cap, at households.gd:614 (`need + mini(need, ...)`). Settlement eats this month's food first and the store only when that is short (the comment at households.gd:719ff). | SAME | |
| 5 | MASTER-PLAN:907 | "They stockplie to have have six months of food in storage, i think as often as they can" | `STORE_MONTHS := 6` (households.gd:498). The store order is posted every month while `held < 6 x need` (households.gd:633-646). | SAME | |
| 6 | MASTER-PLAN:911 | "The first, if your running low ... i don't think you wait" | The store order's budget is `money - food_cost - rent`, at any price that money reaches (households.gd:631-646). There is no price test that makes a household wait. | SAME | |
| 7 | MASTER-PLAN:920 | "Mark that the government can order stockpiles to help in famin once we get back to politics" | No government stockpile exists. politics/emergency_politics.gd has only the old export ban, price control and rationing measures. | NOT BUILT (step 8) | |
| 8 | MASTER-PLAN:929 | "increases should not stack for seperate offers, infact they should fall back to the original rule for settin on hire" | economy/rules.gd:225-260 `salary_rules`. There is ONE offer per tier and area (`c["salary"][tier][area]`), not one per post. It climbs whenever, by head count, any post of that tier and area was open after last month's hiring and is still open now (`mini(open, before)`, line 244). It goes back to the start only in a month with no such post (lines 259-260). A new opening in a tier and area that already has a long-open post is therefore offered the climbed salary. If post A is filled while post B, opened later, stays open, the climb goes on from A's level. | DIFFERENT | Increases stack across separate posts. The climb is kept per tier and area and counted by head count, not per post. An opening is offered the original rule only when no post in its tier and area has been open a whole month. Example: A is open in months 1-3 (climbed twice). B opens in month 3 as A is filled. In month 4 the offer climbs a third time, although B has waited one month. |
| 9 | MASTER-PLAN:929 | "then it should only climb max 5% if it cost not hire for one month" | `OFFER_CLIMB_PM := 50` (rules.gd:200). It climbs only for posts left open after last month's hiring that are still open (`open_left`, rules.gd:241-244, 380-381). | SAME | (Bob reads "max 5%" as always 5%; the user's next answer, "5% each month", supports that.) |
| 10 | MASTER-PLAN:933 | "5% each month, it goes" | It climbs 5% again in each further month (rules.gd:255-258, `old x 1050/1000`). | SAME | (Rule 8 applies to how the months are counted.) |
| 11 | MASTER-PLAN:933 | "i never said i wanted the rule for lowering that was your suggestion" | No rule lowers the offer. `clear_hiring_salary` only returns it to the starting salary (company.gd:406-416). | SAME | |
| 12 | MASTER-PLAN:935 | "Yes hand it built, this should stabilise workers and allow unemployed in" | It is built (rules.gd:196-260). | SAME | (Its content: see rows 8-11.) |
| 13 | MASTER-PLAN:944 | "Can we not make a 2d array to keep all things about the hires? Sallery start date so forth?" | economy/company.gd:215-350. Each staff entry keeps `hires` rows of {n, pay, since, train}. `payroll` gives each row with its own pay. pay_wages pays each row its own pay (households.gd:431-436). | SAME | |
| 14 | MASTER-PLAN:946 | "You can merge if all rows match" | company.gd:326-350. `_row_key` is "pay\|since\|train", and `_tidy` merges only rows whose keys are equal. A row whose training is over is written as train -1 before the compare. | SAME | |
| 15 | MASTER-PLAN:950 | "Record it make them pay after our if they refused take it to court" | households.gd:417-448 `pay_wages`: the unpaid rest per pool becomes `Justice.owe(..., "UNPAID_WAGES")`. It is in `NO_PLAN_KINDS` (justice_ops.gd:1133), so it is owed whole and due next month, and collect_debts collects it. `debt_received` books it as wages. It is in `PETITION_KINDS`: after 12 months unpaid a petition is filed (justice_ops.gd:938-976). The court's answer, `EconFace.insolvency_court_liquidation`, returns false (core/econ_face.gd:586). | SAME (record and pay afterwards); the court: NOT BUILT (step 5) | "Refused" = 12 months unpaid is Bob's reading (table 2). |
| 16 | MASTER-PLAN:959 | "Change the sallery from fod and rent to just rent at 2× we will have to find a better formula for it later" | rules.gd:270-271 `starting_salary` = `area_rent x STARTING_RENT_PM(2000)/1000 x TIER_PM[tier]/1000`, with no food term. `area_rent` is the plain average of the area's open landlords' "@home" price; with none, `start_price_of("LANDLORD")/2` (rules.gd:282-292). | SAME | (The tier multipliers, 1.5 and 2.25, and the "average of landlords" are readings: table 2.) |
| 17 | MASTER-PLAN:963 | "3 5x housing try it" | This was a trial, superseded by rows 18-19. The code holds 2000, not 3500 (rules.gd:203). | SAME (superseded) | |
| 18 | MASTER-PLAN:969 | "2" | `STARTING_RENT_PM := 2000` (rules.gd:203). | SAME | |
| 19 | MASTER-PLAN:971 | "Merge with 2" | As in row 18. | SAME | |
| 20 | MASTER-PLAN:980 | "The build crews at start should not be hiring at all. They should start with a job already active." | economy/home_builders.gd:106-110 calls `Households.hire(..., -1, true, true)` with placed=true. Placed people skip the needs test (households.gd:196), start trained, pay no advert, and are paid `placed_salary`. | SAME | |
| 21 | MASTER-PLAN:989 | "Place the goverment staff from startb with the builders" | economy/landing.gd:164-177 `_crew`: the government's staff (housing office, shelters, Colony Stores, and so on) are placed with `Households.hire(..., -1, true, true)`. | SAME | |
| 22 | MASTER-PLAN:989 | "lets set their sallery at 2.5 from start same for builders" | `PLACED_RENT_PM := 2500` (rules.gd:207). `placed_salary` = area_rent x 2.5 x the tier's share (rules.gd:276-277), used for every placed hire (households.gd:194). | SAME | ("x the rent" and "x the tier's share" are Wilma's reading.) |
| 23 | MASTER-PLAN:998 | "the farmers themselves I RULED EATS THEMSELVES FIRST" | households.gd:610-617 `post_orders`: before any market order, a founder whose family farm is open takes food from the farm's stock (`Making.family_take`, economy/making.gd:115-135), with no money and never offered. The family then orders only `need - farm_eat`. | SAME | |
| 24 | MASTER-PLAN:998 | "THEY ARE THREE THEY CAN PRODUVE 30" | FARM row: 240 FOOD, 24 posts (type_table.gd:68-70). FAMILY = 1/6 of the row with a 60 per mille penalty: 4 posts and 37.6 FOOD at full. With 3 family workers that is about 28.2 (3/4 of 37.6). | SAME (UNSURE) | The user's figure is an example. The code gives about 9.4 per worker on a family farm because of the size penalty, a ruling made earlier. I could not tell whether "30" was meant exactly. |
| 25 | MASTER-PLAN:998 | "THEY WOULD TAKE SIX OUT OF THIRTY SELL 24" | The take is `need + min(need, 6 x need - held)`: up to twice the family's month of need (households.gd:614). For a family of 3 persons that is 6. The rest stays in stock and is offered. | SAME (UNSURE) | It equals 6 only for a 3-person family with less than six months held. Once the store is full, the take falls to 3. |
| 26 | MASTER-PLAN:998 | "AND THAT SHOULD BE ENOUGH TO HIRE ONE PERSON" | `hire_wanted` = posts at the level less the family working (company.gd:538-550). A 4-post family farm with 3 family members wants 1 hire. Whether the 24 sold pays for that hire depends on prices at run time. | SAME (UNSURE: depends on the run) | |
| 27 | MASTER-PLAN:1007 | "On posts when you many an open post you pay the first time not every consecutive month after" | rules.gd:419-464. `_advertise` pays only for `open - already paid` posts. `advertised[key]` is kept while the post stays open (rules.gd:382-389) and drops when it is filled (`_hire`, line 463) or no longer wanted. A post that reopens is paid again. | SAME | |
| 28 | MASTER-PLAN:1016 | "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP ..." (a price moves at most 5%, the same up and down) | `K_PM := 50` (rules.gd:46). `price_rule` moves the price by `step_pm(50, num, den)` = 50 x s/(1+s) per mille, never above 5%, with the same formula up and down (rules.gd:110-143). The builders' BW price uses the same rule. | SAME | |
| 29 | MASTER-PLAN:1022 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" (output moves at most 5% a month) | `G_PM := 50` (rules.gd:50). A cut is `lv x down/1000`, at most 5% of the level. A rise is `max(1, max(lv, 1000/n) x up/1000)` (rules.gd:190). | SAME (UNSURE) | At levels below one post's share (1000/n), the rise is 5% of one post's share, not of the level. Example: a 4-post farm at level 100 can rise by 12.5, i.e. 12.5% of its level. It is still under 5% of full. UNSURE whether the user's 5% means 5% of the current level. (Otto's and Terra's review additions.) |
| 30 | MASTER-PLAN:1031 | "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | rules.gd:168-193 `output_rule`: `down = step_pm(G_PM, unsold, sold)` acts in ANY month with `unsold > 0`. There is no 50% test and no count of months in a row; nothing in the record keeps one (a grep finds no streak field). | DIFFERENT | Output is cut in every month with anything unsold, not only after 3 months in a row with over 50% unsold. |
| 31 | MASTER-PLAN:1037 | "A CUT IS 5% ..." | The cut is 5% x unsold/offered (s/(1+s) with s = unsold/sold), so from 0 to 5%. With over 50% unsold it is 2.5% to 5%. | DIFFERENT | The cut is not a flat 5%; it scales with the unsold share. |
| 32 | MASTER-PLAN:1037 | "AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | There is no run of months. Every month with unsold goods cuts. | DIFFERENT | The cut is not tied to months 3, 4, 5 ... of a run of over-50%-unsold months. (It does cut again later, but for any unsold, from month 1.) |
| 33 | MASTER-PLAN:1046 | "FARMS DON'T SHUT" | rules.gd:339-347 (rule 19a): after a month of unpaid wages, each plant with `staff_count == 0` is closed with `Company.close_plant(..., "NO_STAFF")`, for every type, FARM included. `staff_count` does not count the family (company.gd:463-476 reads only `staff`; the family is in `family.work`). So a family farm whose hired staff were laid off is shut with the family still on it. Only the LAW reason ever reopens a plant (law_company.gd:222). | DIFFERENT | Farms are still shut ("NO_STAFF"). There is no FARM exception, and a family farm is closed even though the family works it. |
| 34 | MASTER-PLAN:1055 | "Food is too expensive" | This was answered by the next line (rent doubled, food price kept). Food's starting price comes from the table solve (type_table.gd `start_prices`). | SAME (no change asked by these words alone) | |
| 35 | MASTER-PLAN:1057 | "Screw lowering food, double the rent. ..." | `HOME_RENT_PM := 2000` multiplies LANDLORD's "@home" starting rent (type_table.gd:29 and the end of `start_prices`). The landing shelter rent is `SHELTER_RENT := 97 * S` (economy/landing.gd:54, half a new home). Food is not lowered by it. | SAME | |
| 36 | MASTER-PLAN:1066 | "10 purple each" (10 people per farm worker) | FARM line: qty 240 with labour 18+5+1 = 24 posts, which is 10 per worker at large size (type_table.gd:67-68). Smaller sizes carry the size penalty (FAMILY 6%, SMALL 4%, AVERAGE 2%). | SAME | |
| 37 | law-face:154-155 | "if not the owner is taking to court, where the bank can either settle for a smaller amount or demand payment over time, if he is rich or owns other companies a settlent might be reached" | No settlement or payment-over-time for a company's debts against its owners. Liquidation is refused (core/econ_face.gd:586 returns false). | NOT BUILT (step 5) | |
| 38 | law-face:234-235 | "No no, the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | Pay is set at hire per hire row (households.gd:194, company.gd:241). `Households.yearly_raise_month` runs every new year (not on landing day) and calls `Company.yearly_raise` with `max(company's choice, ECON_YEARLY_RAISE_MIN_PCT (default 2) x 10 per mille)` on every hire row (households.gd:1094-1100; company.gd:422-435; econ_publish.gd:59 lever 2, range 0-20). | SAME | It differs from the paper's own "until step 8" line 266-267: table 2. |
| 39 | law-face:239-240 | "On the workers rules i belive you have the right of it, and it should apply to builders" | Layoff pay: `LAW_LAYOFF_PAY_MONTHS` default 3, range 0-12 (law/law_data.gd:497; law/work_law.gd:28). `Households.layoff` pays `months x the row's own pay`, and the rest becomes a LAYOFF_PAY debt (households.gd:258-330). The advert (rules.gd:432) and training (company.gd:128-130, 352-353: 500 per mille rising to full at 6 months) apply to every company. Builders run the same staff_to_posts (rules.gd:91-92). | SAME | |
| 40 | law-face:250 and 259 | "a debt like unpaid wages, and can end the company" | LAYOFF_PAY is in `NO_PLAN_KINDS` (owed whole, next month; justice_ops.gd:1133) and in `PETITION_KINDS` (justice_ops.gd:938). Ending is refused until step 5. | SAME (the ending itself: NOT BUILT, step 5) | |
| 41 | law-face:251-252 | "Record it make them pay after our if they refused take it to court" | As in row 15. | SAME (the court: NOT BUILT, step 5) | |

**DIFFERENT rows in table 1: 5** (rows 8, 30, 31, 32 and 33).

#### Requested checks of the law paper's own "Until step N" lines (not the user's words)

| paper:line | the paper says | the code | verdict |
|---|---|---|---|
| law-face:94-95 | "Until step 6: every plan and plant is lawful as it stands, with no permit, licence or fee ... the old `law_bridge` gate is not rebuilt before then." | economy/building.gd:242 calls `LawCompany.may_sign` before signing. That checks the zone on every site key (law/law_company.gd:162-176) and applies for each licence `licences_required` names: HAZARD if the type row has `hazard` true and `LAW_LICENCE_REGIME_HAZARD` == REQUIRED (the default); EXTRACTION for MINE. building.gd:627-629 calls `may_open`, which closes a new plant with reason "LAW" if it lacks a required licence (law_company.gd:196-205). No fee is charged (law_ops.gd:646 `apply_licence` takes no money). In practice only FARM is foundable (economy/month.gd:27) and FARM is not hazardous, so no licence is asked for today. The zone check would block a plan if a government zoned against farms. | DIFFERENT: a step-6 gate (licences, plus the zone check) is built at step 3. No fee: SAME. |
| law-face:199 | "Until step 5: no company can end" | `EconFace.insolvency_court_liquidation` returns false (core/econ_face.gd:586-587). Petitions and conviction ladders call `_liquidate`, which logs "wind up refused" (justice_ops.gd:979-988). No code sets a company's status to ENDED or WOUND_UP. | SAME |
| law-face:141-142 | "Any fine raised before the court exists is recorded as owed and waits." | `Justice.collect_debts` collects every open debt monthly from step 3 (law-face 134, Wilma's ruling). | DIFFERENT from this line. Wilma's later collection ruling (line 134) supersedes it inside the same paper. |
| law-face:266-267 | "The minimum wage and the yearly raise's minimum have no effect until step 8. Until then the hiring salary moves by the three price rules alone, and a worker's salary stays where it was set on hire." | The yearly raise with its 2% minimum runs every January now (households.gd:1094-1100). A yearly negotiation also changes pay (households.gd `NEGOTIATE_MONTH := 7`, company.gd:722 `negotiate`). The hiring salary moves by the 5% climb rule, not the three price rules (superseded by the user's 2026-11-18 ruling). | DIFFERENT from this line (the paper is stale against the code and the user's later rulings). |

#### Table 2: proposals, readings and decisions with no user words behind them

| paper:line | the proposal / number | what was built from it (file:line) |
|---|---|---|
| MASTER-PLAN:939 / rc 9.2 | Bob builds the offer rule; "a whole month" = posts open after LAST month's hiring and still open (Bob's reading) | rules.gd:216-244 (`open_left`, `mini(open, before)`) |
| rules.gd:223-228 (Otto's review, Bob's reading) | After a month of 19a (could not pay wages), the offer is held, neither climbing nor falling back | rules.gd:227-228 (`no_hiring_m`), set at rules.gd:349 |
| MASTER-PLAN:965 | Wilma's reading: "3 5x" = 3.5 x the rent, a trial | superseded; STARTING_RENT_PM 2000 (rules.gd:203) |
| MASTER-PLAN:991 / rc 9.2 | Wilma's reading: 2.5 = 2.5 x the rent, times the tier's share; later openings at those companies get 2x | rules.gd:207, 276-277; households.gd:194 (placed vs hiring_salary) |
| rules.gd:268-269 (Bob) | Rent for the salary = the plain average of the open landlords' asks in the area; with no landlord, the shelter at half a new home | rules.gd:282-292 |
| rules.gd:265 | The starting salary is multiplied by the tier's share (S 1.5, Sp 2.25) | rules.gd:271, type_table.gd:21 (`TIER_PM`) |
| MASTER-PLAN:1000 / making.gd:122 | Bob's reading: the family takes from the farm's whole stock, not only this month's making; the take covers the month's need plus the store's double | making.gd:115-135; households.gd:614 |
| MASTER-PLAN:1009 / rc 9.2 | Wilma's reading: the advert is paid in the month the post opens, whether or not anyone is hired; a post that reopens later is paid anew | rules.gd:426-450, 382-392 |
| rc 9.2 (Wilma's starting numbers) | Advert = a tenth of a month's pay of the post (Ella's Media.job_advert_cost) | rules.gd:441 (via media_ops `job_advert_cost`; amount not re-verified here) |
| rc 9.2 (Otto's earlier review) | A company pays for as many adverts as its money reaches; an unpaid post is advertised the first month it can | rules.gd:442-450 |
| rc 9.2 (Wilma's starting numbers; Bob's proposal) | Training: 500 + 500 x a/6 per mille; full at a = 6; 1.75 months lost | company.gd:128-130, 352-353; rules.gd:491-493 |
| rc 9.2 (Bob's proposal) | Layoff weighing: idle x pay > months x pay + advert + training loss x price; idle = the run of slack months | rules.gd:367-377, 472-497 |
| rules.gd:187-190 (Terra's and Otto's reviews) | A rise is at least 1 per mille and at least 5% of one post's share; a cut is floored | rules.gd:190 |
| MASTER-PLAN:1068 | Wilma's reading: "10 purple" = 10 people | type_table.gd:67-68 (240 / 24) |
| MASTER-PLAN:1059 / rc 9.2 | Shelter 48 -> 97, new house 97 -> 194 (Wilma's figures) | landing.gd:54 (`SHELTER_RENT 97`); type_table.gd:29 (`HOME_RENT_PM 2000`) |
| MASTER-PLAN:896 / rules.gd:547-559 (Bob's reading, Otto's review) | Winnings = the month's earnings after inputs, wages, upkeep, adverts, layoff pay and debts paid; the founder's money and the grant are capital; keep back one month of the hired staff's wages, inputs and upkeep | rules.gd:560-575 |
| households.gd:584-590 (Wilma's detail) | Order: food, then rent, then the store; store order AHEAD with its own budget | households.gd:620-646 |
| law-face:126 (Wilma, 2026-11-18) | "One petition per company until the court answers, logged once, a refusal logged once" | justice_ops.gd:948-976 (`justice.petitioned`) |
| law-face:134 (Wilma, 2026-11-17) | "a debt nobody collects is a fault, not a design": monthly collection, oldest first | justice_ops `collect_debts` (not re-read line by line here) |
| law-face:243-245 (Wilma's decision) | The layoff months are the law on the day of the layoff, for everyone | households.gd:270 (`WorkLaw.layoff_pay_months` read at the layoff) |
| law-face:254-255 (Bob's reading) | "Refused" = unpaid 12 months past due, then the pool petitions | justice_ops.gd:938-939 (`PETITION_MONTHS := 12`) |
| law-face:256-260 (Anni) | UNPAID_WAGES and LAYOFF_PAY owed whole, not in small-firm instalments | justice_ops.gd:1133-1140 |
| law-face:37 (Anni's decision) | An unbuilt lever is shown "not in force yet" | not checked in the screens (UNSURE) |
| law-face:64 (Anni's decision) | The old "extraction only in district d:3" goes | no "d:3" in law/ (grep): gone |
| law-face:77-78 (Anni's decision) | The chief's risk appetite bends how the chance of being found is read; the old fixed test goes | no going ahead unlicensed is built (law_company.gd comment: "no going ahead unlicensed until step 6") |
| law-face:82-83 (Anni's decision) | `LAW_LICENCE_TERM` lever instead of the fixed 60/120 months | not built: `LICENCE_MONTHS := {"HAZARD": 60, "EXTRACTION": 120}` (law_company.gd:139) |
| law-face:84-89 (Anni's decision) | Month one: builders and the government's subsidiaries hold their licences free; shelters need no permit | the landing does not go through may_open; none of those types is hazardous (type_table) |
| law-face:131-132 (Anni's decision) | The fine's proportionality caps stay, with new numbers | not re-checked (fines are step 5) |
| law-face:156-161 (Anni's decision) | The order of creditors after an ending | NOT BUILT (step 5) |
| law-face:166-167 (Anni's decision) | Every creditor gets the bank's choice | NOT BUILT (step 5) |
| law-face:196-197 (Anni's decision) | A state company is not wound up | justice_ops.gd:980 (`_liquidate` refuses a state company) |
| law-face:218-219 (Anni's decision) | Overtime is how hours enter | not built (step 9) |
| law-face:225 (Anni's decision) | Staffing ratios become levers | not checked (step 9) |
| law-face:283 (Anni's decision) | The authority follows `LAW_MERGER_THRESHOLD` / `LAW_DOMINANCE_SHARE` instead of 70% / +15% | competition_law.gd:8-36 reads both levers (defaults 100 and 50); buy-outs are step 6 |
| law-face:300-312 (Anni's decision) | What each price/rent control does | not built (step 8) |
| law-face:332-333 (Anni's decision) | Buying at value x `LAW_LAND_PRICE_FLOOR_PCT` for every buyer | DIFFERENT from it: `land_law.terms` charges the plan's full price; the floor % is kept only "on record for a later sale" (land_law.gd:491-505). `land_offer` (land_law.gd:189-192) does apply the floor % under SELL. |
| law-face:334-335 (Anni's decision) | Lease rent = land value x the bank's rate instead of a fixed 0.6% a month | not built: `LEASE_YIELD_PER_MONTH := 0.006` (land_law.gd:22). Leases also exist at step 3 (LEASE/KEEP in `terms`), where law-face:351-352 puts them at step 5. |
| law-face:339-341 (Anni's decision) | KEEP becomes lease-only at double the lease rent | land_law.gd:182-185, 498; law_data.gd:255 |
| law-face:344-345 (Anni's decision) | `LAW_EVICTION_NOTICE_MONTHS` instead of a fixed 3 | law_data.gd:658 (default 3, range 1-12); land_law.gd:402 |
| law-face:373 (Anni's decision) | Unpaid bills: the supply is cut after the notice | not built (step 5) |
| law-face:395 (Anni's decision) | Essential services: power, water, clinics; half the crew | not checked (step 9) |
| law-face:399 (Anni's decision) | Lockout rules | not checked (step 9) |
| law-face:452-453 (Anni's decision) | Press licensing becomes a licence with a fee | not checked (step 4) |
| law-face:456-458 (Anni's decision) | Transit PUBLIC: private operators pay a route licence | not checked (step 4) |
| law-face:351-353 (Anni's note) | Land title and price at step 3, not step 6 | built at step 3: `LandLaw.pass_holder` at opening (building.gd:624), `Site.land_terms` at signing (building.gd:258) |
| law_company.gd:135-139 comment (Anni's "plainest form") | The licence regime and the zone check at step 3 | law_company.gd:141-176, 196-205 (see "Requested checks", law-face:94) |

---

#### T. Terra's own reading: the ground, sites, seasons, endings and what today's traces showed

Read from the shared tree's code (rules.gd d2ddf83f, company.gd 6e54dcfc), 2026-11-18.

### T1. The user's words

| # | paper:line | the user's words (short) | what the code does today | verdict | what differs |
|---|---|---|---|---|---|
| T1 | company:143 | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size the output for each is the same but with a small penalty" | type_table.gd SIXTHS 1/2/4/6; output_milli = row qty × share × (1 − penalty) | SAME | |
| T2 | company:152 | "You penalty is fine" (6%, 4%, 2%, 0) | type_table.gd:16 PENALTY_PM FAMILY 60, SMALL 40, AVERAGE 20, LARGE 0 | SAME | |
| T3 | company:154-157, 161-162 | "in a square if there are other companies they would have to buy out … three small in a square" (one full size per type a square) | site.gd square_sixths / place and hold refuse more than 6 sixths of one type in a square; the 3 km tile | SAME | |
| T4 | company:158-159 | town square = 400 m street block: "This sounds good" | town_grid.gd BLOCK_CELLS 4 × 100 m cells; a town plant's square is its first cell's block | SAME | |
| T5 | company:161-166 | growing: buy out, or "build a new" | not built (rule 5) | NOT BUILT (step 6) | |
| T6 | company:251-257 | sales death: "cant turn the price in two years its going to sell of its stock and shuts down" | no sales-death clock anywhere in sim/ | NOT BUILT (step 5) | |
| T7 | company:251-257 | "it's plants shut down and it cant affort too replace them" | rules.gd:347 staff_to_posts (19a) shuts a plant whose payroll reaches 0 (Company.close_plant "NO_STAFF"). Nothing in the tree reopens a NO_STAFF plant (Company.reopen_plant's only caller is law_company.gd reopen_licensed, for LAW). Nothing checks whether the company can afford to reopen or replace. The company stays OPEN with its plant shut for good. | DIFFERENT | The shut half is built in step 3; the "cant affort" half is not. A shut plant is shut for good while the plan says no company ends before step 5. Today's trace (t51, seed 1) had 40 farms shut so and none reopened in 60 months. |
| T8 | company:251-257 | buy-out: "someone buys them out … if they get enough they can buy another building and continue there" | not built | NOT BUILT (step 6) | |
| T9 | company:262-264 | after an ending: laid off, loans paid from the stock, court | not built (no ending exists) | NOT BUILT (step 5) | |
| T10 | company:877-878 (15e) | "The family that owns a family farm works it themselves, without wages … A family farm with no money still grows food" | rules.gd:347 shuts a plant when Company.staff_count(cid, "", pk) == 0. staff_count (company.gd:463) counts the payroll only, not Company.family_count. A family farm whose hired hands are laid off unpaid (19a) is shut with its family still on its posts. making.gd:52 then makes nothing for a closed plant. | DIFFERENT | The family is left out of the shut test; a family farm with no money stops growing food. |
| T11 | company:881 (15e), MASTER-PLAN:1042 | "FARMS DON'T SHUT" | Two paths shut a farm today. (1) rules.gd:347, 19a NO_STAFF: reachable, traced 40 times. (2) building.gd:629, LAW at the opening when law_company.gd may_open finds a licence missing. Not reachable for a FARM today, since licences_required gives none for a non-hazard type (type_table FARM "hazard": false). Company.close_plant (company.gd:853) shuts any type. | DIFFERENT | A farm can be shut (path 1), and close_plant has no rule that a farm is never shut. |
| T12 | company:885-890 (15e) | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST … TAKE SIX OUT OF THIRTY SELL 24" | households.gd post_orders: a founder with an open own farm takes need + min(need, what the six-month store lacks) through making.gd:126 family_take, before any order, never offered | SAME | |
| T13 | company:892-895 (15e) | "the farm would be their home, wich means they are paying on any loans … and uppkep" | landing.gd:285 rent_due returns {} for a founder who lives_on_own_farm; households.gd homes() leaves them out of town households; upkeep is in rules.gd winnings() before the family takes anything; loans: no bank yet | SAME (loans NOT BUILT, step 5) | |
| T14 | company:899 (15e) | "I think two is better" (a loss carried forward) | rules.gd winnings(): loss_carried paid down before winnings; pay_winnings stores carried_after | SAME | |
| T15 | company:912 (15e) | "winnings no sallery, wich comes after" | rules.gd winnings(): earned = rev − inputs − wages − upkeep − adverts − layoff_paid − debts paid this month − winnings already taken; paid in JUSTICE after the debt collector | SAME | Note: what is "owed that month" is read as debts paid this month. Layoff pay owed by instalment later (justice LAYOFF_PAY due months) is not held back, so a farm that sold its stock after being shut paid 8,426 winnings while owing 1,246 layoff pay (t51, company:17, month 21). Marked for Wilma; not a verdict of mine on the words. |
| T16 | company:598-599 (9.8) | "the closer to the coast you get the more expensive they get; it can even shift from road to road" | town_grid.gd value(): parts "view" (sea or river within REACH 0.3 km, weight 2.0) and "water" (shore within 1.0 km, weight 1.5), both falling linearly to 0 at their reach (_draw); "road" and "fast_road" parts per cell | DIFFERENT | Closer to the coast is dearer only within 1 km of it. Beyond 1 km, distance to the coast changes nothing. "Road to road" holds through the per-cell road parts. |
| T17 | company:594 (9.8) | "Below 250 start a gridd anyway and only use what you need" | town_grid.gd ensure_town lays a town's grid with its first building (always on); cells are laid one plant at a time | SAME | |
| T18 | company:595 (9.8) | a block of 50 homes "about 6 to 7 cells as houses, 1 cell as apartments, a quarter of a cell as a tower" (Terra's proposal accepted: "This sounds good") | town_grid.gd HOUSE 8 homes a cell (50 → 7 cells), APARTMENT 60, TOWER 200 | SAME | |
| T19 | company:615, 624 (9.8) | owning a home; "If you own an appartment there is a fee for uppkep …" | not built | NOT BUILT (step 7) | |
| T20 | company:1277-1288 (13, step 4) | farms away from towns, the grant's spot: "Save it for when trucks and roads come Mark it for then" | not built. site.gd choose_country's "next_to_homes" −6 is for every type except a farm, so it puts no farm away from homes | SAME (NOT BUILT, step 4, as ruled) | |

### T2. Lines with no user words behind them (proposals, readings, starting numbers of ours) in my ground

| paper:line | the proposal / number | what was built from it |
|---|---|---|
| company:605 (9.8) | land = 10% of the building's bill × the cell's value **(proposal: the 10%)** | site.gd:29 LAND_SHARE 0.10; land_price, land_value_milli; what every plan pays at signing (Site.buy_land, LandLaw.sell) |
| company:770 (12.1, 3; Wilma) | land belongs to the colony; a plan buys it at the land price | Site.buy_land → LandLaw.sell (memo LAND_SALE), building.gd sign_round |
| company:773-774 (12.1, 5; Wilma) | the best-scoring free place for its type; "a plant pays for its road, power and water connection as a home does" | site.gd choose_country / choose_town. The connection is NOT charged to a plant (no connection cost in Building.estimate). |
| company:775-776 (12.1, 6; Wilma) | an empty building after an ending stands, wears, can be bought | no ending exists; a shut plant stands and nothing can buy it |
| company:1002 (12.4, 34; Wilma) | "the planet sets a farm's yield by season and ecology" | site.gd yield_pm = PlanetSeasons.farm_pct × PlanetEcology.yield_pct; making.gd:106 yield_of reads it each month |
| company:963-965 (12.3, 19a; Wilma) | "a company that cannot pay its staff lays them off, and a plant with no staff is shut" | rules.gd:338-358, in step 3; see T7, T10, T11 |
| company:957 (12.3, 16; Wilma) | rule 6: twelve months idle | not built (step 6). No IDLE closing anywhere. |
| rebuild-step2-terra (mine) | siting scores: −1 a tile from the nearest settlement, road +3, fertile +4, ore +6, river +5, next to homes −6 (not for a farm); no reach limit | site.gd:33 SCORE, choose_country |
| rebuild-step2-terra (mine) | a town cell's value: VALUE_PER_POINT 100 ‰ a point, at least VALUE_MIN_PM 300; the weights and reaches of jobs, school, clinic, shops, utilities, view, water, road, fast road, industry | town_grid.gd:36-43, value(). The floor of 300 is a floor of ours, with no user words. |
| rebuild-step2-terra (mine) | the landing shelters: 8 plants of 50 homes, HOUSE form | landing / site place |
| rebuild-step3-terra (mine) | a low-yield log row below 700 ‰ | site.gd:413 YIELD_LOG_BELOW 700 (the log only) |
| rebuild-step3-terra (mine) | a country tile's land value is the land of a full-size farm; a town cell's is the land of 8 homes | site.gd land_value_milli |

### T3. Found by today's traces, outside my ground (for the owners; verdicts in the slices)

- **The founder's job, given up at making** (build trace, t45). In the shared tree it is now kept until signing (households.gd make_founder → _promise_post; take_up_posts). That is Maja's fix, reviewed.
- **Rule 8** ("the same signal says the work is covered", company:182). In the shared tree's rules.gd founding() (line ~652) there is no covered test: "covers" is share ≥ cost alone. Bob's rule-8 hand-over is not merged.
- **Builders' crew** (rebuild-building 4.11: "not a ceiling", Otto's text). Rules 3 and 4 hold a builder's level at 1000 at most (rules.gd:190 mini(1000, …)), so 180 is the ceiling in step 3. With Wilma for the user.
