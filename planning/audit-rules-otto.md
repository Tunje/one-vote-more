# Audit of the rules: the user's words against the code (Otto)

2026-11-18. The whole plan was read: rebuild-company.md (whole), rebuild-households.md, rebuild-building.md,
rebuild-law-face.md, and the economy rulings in MASTER-PLAN.md. Each line was checked against the code in the shared
tree as it stands (commit 0c9e266 plus the uncommitted plan line on the farm's buffer; rules.gd d2ddf83f, company.gd
6e54dcfc, households.gd 247d57b7, making.gd a0855ac0). Each row gives the user's words | what the code does, with the
number | SAME or DIFFERENT | what differs. The code was read, not memory and not doc comments. No fixes and no
proposals are made here. The second table in each section lists the paper lines with no user words behind them
(proposals, readings and starting numbers of ours) and what was built from them.

Sections: A rebuild-company 1–700; B rebuild-company 700–1423; C rebuild-households and rebuild-law-face;
D MASTER-PLAN rulings; E rebuild-building and the builders' lines; T the builders trace.

## DIFFERENT, counted once each (22). Where the same ruling appears in several papers, the rows are named together.

1. Rule 4, "only lowered if over 50% of offered goods is not sold 3 months in a row": output_rule cuts in any month
   with anything unsold. There is no 50% test and no count of months. (A18, D87)
2. "A CUT IS 5% ... A FOURTH MONTH LOWER AGAIN": the cut is 5% × unsold/(unsold+sold), a share of 5%, and nothing
   counts the months. (A19, D88)
3. Output "5!!!": a rise is computed on max(level, one post's share of full), so at a low level it can be more than
   5% of the level (level 100 of 4 posts: up to 12.5%). (A26)
4. "No hard floors or ceilings of our own": stocking up stops at 2 × need (Making.post_orders), and a rise has a
   minimum. (A29)
5. Rule 3, "picks first or second output": nothing ever changes a company's line. (A6)
6. "avrage ask salleries in the company and underpayed is based on that line": Company.avg_pay is the average of one
   post tier, not of the company. (A49, D58)
7. "the manager, negotiation can bring it closer to avrage": _negotiate reads no manager. It asks half the gap and
   gets it if the account holds a year of the rise. (A53)
8. Hiring offer, "increases should not stack for seperate offers ... fall back to the original rule for settin on
   hire": there is one offer per tier and area. A new opening gets the climbed offer while another post of that tier
   and area has been open a month, and a fill does not reset it then. The 5% a month and the missing lowering rule
   match. (A50)
9. "Yes they may order in" and imports limited only by the ship: Ship.order exists, but nothing in sim calls it, so
   no import is ever ordered. (A71, D5, D15)
10. "All company types needs to be able to be created as private": month.gd FOUNDABLE = ["FARM"], so only farms are
    ever planned. The step-3 line says "Tested first on food alone". (D3)
11. "If something else than price stops sales it should not count on adjusting price": goods left unsold because
    the buyers had no money still lower the price and the output; only the buyer's side leaves NO_MONEY out. (D17)
12. "It sells too cover all monthly expences": hold_back covers wages, inputs and upkeep only. It leaves out adverts,
    layoff pay and debts paid, and upkeep is never booked, so it is 0. (D18)
13. "just rent at 2×" (the salary): Rules.running_cost, which rule 7 and a founder's opening money read, still prices
    posts at TypeTable.salary (300 G), as do the benefit and the pension. New openings use 2 × rent. (B7, D50)
14. "materials come with the start not finished buildings": the landing shelters (8 blocks of 50 homes) stand finished
    in month one, as the plan's own month-one section puts them. (D51, partly)
15. "individually counted on company start": founders are counted from the day the plan is made, so they are made
    and released monthly for plans that never become companies. (C3, D53)
16. "THEY ARE THREE THEY CAN PRODUVE 30 ... SELL 24": three of the family make 28.2 (4 posts and the family-size
    penalty of 6%, ours) and sell 22.2. The take of 6 and "enough to hire one" match. (B12, C16, D82)
17. "FARMS DON'T SHUT": in a 19a month a plant with no hired staff is closed NO_STAFF, the family not counted, and
    never reopens. A plant can also be closed by the law at opening. (B11, D89)
18. "they should not increase prices for claimed jobs": a plan signed to wait behind a builder's book is counted once
    as unmet demand above the price, so it raises the BW price (R1) and the crew level (R3). (B21)
19. Rule 8, "the same signal says the work is covered": not built in the shared tree (Bob's t51 is not merged). (B6)
20. Supplies, "add 1 month of additional supplies every month": the site is topped back up to 3 months, which is less
    than a month whenever a job works below its planned BW. (E4)
21. A plan "ends only if its owner gives it up (no builder, no money)": a third reason, the signal gone before
    signing, is added. "No builder" is read as "no builder with trained crew", so builders alive with 0 crew count
    as none; in seed 1 every plan of months 27, 28, 49, 50 and 59 was given up that way. (E9, trace)
22. The farm's buffer, "50% until it had 6 months worth built up then 10%": not built. Rules.winnings keeps back one
    month of hired wages, inputs and upkeep, and the family takes the rest. (E16)

Also noted in the tables, counted SAME: the job advert's price and the needs test read the company's area, not the
plant's (D35). Two readings in the households and law papers (no user words) differ from the code (C, table 2): the
order of negotiating and quitting, and the yearly raise running now.

My own approval earlier today of item 8 (the hiring offer) was wrong. I checked the climb and the reset for one post,
not for a second opening of the same tier while another is open.

# Audit A: rebuild-company.md lines 1–700 against the shared tree (Otto)

Code read: rules.gd d2ddf83f, company.gd 6e54dcfc, households.gd 247d57b7, making.gd a0855ac0, ship.gd 8ad7e1f8,
landing.gd 52ad4e73, plus type_table.gd, building.gd, grants.gd, market.gd, month.gd, site.gd, media_ops.gd and
work_law.gd as they stand in game/ today. A doc comment is not evidence; the code lines are.

## Table 1: every line with the user's words

| # | paper:line | the user's words (verbatim, short) | what the code does today | verdict | what differs |
|---|---|---|---|---|---|
| 1 | 23 | "one object that is the company it's size family to large 4 sizes ... a 2d array of wich items a company type makes" | Company record (company.gd TABLE), one row per company; TypeTable.TYPES rows with "lines" | SAME | |
| 2 | 27 | "building fixes behind off switches is not a valid way to do large scale fixes" | no on/off flags in sim/economy or households.gd (grep for enabled/flag/feature: none) | SAME | |
| 3 | 31 | "Same company types can come but not their code or balancing" | type_table.gd written new; old type names | SAME | |
| 4 | 40 | "its not meant too be a perfect economy for everyon" | a judging rule, no code | SAME (no code) | |
| 5 | 83 | "No i said each COMPANY" (one price per company per item) | Company.set_price / price(world,cid,item): one price per company and item; Market offers at it | SAME | |
| 6 | 101, 109, 177 | "if they pick from first or second output"; rule 3 "Also picks first or second output" | TypeTable has 2 lines for BAKERY and COMPONENTS; no code anywhere in sim/ changes a company's "line" after creation (grep set_line / ["line"] =: only gov_builder's create params) | DIFFERENT | Not built: rule 3 never picks the second output |
| 7 | 110, 122 | "services have no output but a client take in" | service types are not foundable (Month.FOUNDABLE = ["FARM"]); no client intake code | LATER STEP (4) | "4. ... the types with work slots (public services ...)" |
| 8 | 117 | "things can be done in two different ways based in company types how its this a problem?" | TypeTable "way" column (sells, ...); builders sell "BW" (Rules.company_month) | SAME | |
| 9 | 132 | "per pupil plus staff is how taxes for schools are calibrated" | not built | LATER STEP (8) | "8. ... Taxes, brackets" |
| 10 | 135 | "noise polution should also drive down price of housing" | not built | LATER STEP (7) | "7. Homes ... noise" |
| 11 | 143 | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size ... a small penalty" | TypeTable.SIXTHS {FAMILY 1, SMALL 2, AVERAGE 4, LARGE 6}; PENALTY_PM {60, 40, 20, 0}; output_milli = qty × sixths/6 × (1000 − penalty) | SAME | |
| 12 | 152 | "You penalty is fine" (6/4/2/0%) | PENALTY_PM 60/40/20/0 | SAME | |
| 13 | 154–159 | squares, one full size per type; town block "This sounds good" | Site.square_sixths; choose_country offers no place where the type's sixths pass 6 | SAME | |
| 14 | 161 | rule 5 growing: "they would have to buy out the other company ... build a new" | not built | LATER STEP (6) | "6. Building in full. Rules 5 and 6" |
| 15 | 175 | rule 1 raise the price (sold what it offered, orders unfilled) | Rules.price_rule: up = K_PM × unmet/(unmet+sold) | SAME | |
| 16 | 176 | rule 2: "the more inventory you have, the more you reduce your price" | price_rule: down = K_PM × unsold/(unsold+sold) | SAME | |
| 17 | 177 | rule 3: "if you sell out all your producing produce MORE" | Rules.output_rule: up = step_pm(G_PM, unmet, sold); not while holding | SAME | |
| 18 | 178, 202 | rule 4: "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | Rules.output_rule: down = step_pm(G_PM, unsold, sold) in ANY month with unsold > 0; no count of months; no 50% test | DIFFERENT | Output is cut in every month anything goes unsold, from the first month; neither the over-50% test nor the 3-months-in-a-row run is in the shared tree |
| 19 | 209 | "A CUT IS 5% ... AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | output_rule: the cut is lv × (50 × unsold/(unsold+sold))/1000, so less than 5% unless nothing sold; no run counter | DIFFERENT | The cut is a fraction of 5%, not the whole 5%; no month-by-month run (fourth month) logic |
| 20 | 179 | rule 5: "if your selling out and all plants at max build a new one ... money is a limitor" | not built | LATER STEP (6) | |
| 21 | 180 | rule 6: "A hard rule here is fine" | not built | LATER STEP (6) | |
| 22 | 181 | rule 7: "they read an avrage of all avaliable jobs"; no cap on how many may form | Rules.work: ordered qty averaged over up to WORK_MONTHS 12 settled months × today's price; share = work × six/(have + six); Month.founding loops _found_one until nobody plans | SAME | |
| 23 | 182 | rule 8: do not start one when the same signal says the work is covered | Rules.founding: covers = share >= running_cost; passing_sizes empty → no plan | SAME | |
| 24 | 183 | rule 9: "if below making price climbing allways had priority if above lowering has priority ... only the one with priority happens" | price_rule: both signals → "R1" if price < making else "R2"; one signal alone acts | SAME | |
| 25 | 183, 196 | "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"; "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | K_PM 50, up and down; step ≤ 5% | SAME | |
| 26 | 199 | output: "25?! 5!!! CHANGE IT!!! STOP HEDGING" | G_PM 50. But a rise is maxi(1, maxi(lv, 1000/n) × up/1000): at a low level it is computed on one post's share of full, not on the level | DIFFERENT | At a level below 1000/n a rise can exceed 5% of the level (e.g. level 100 of 4 posts: up to +12 per mille = 12.5% of the level); the cut side is ≤ 5% |
| 27 | 187 | "If something else than price stops sales it should not count on adjusting price!!" | no freight in step 3; Market offers stock − waiting − hold | SAME (freight LATER STEP 4) | |
| 28 | 190, 192 | "Ignore the stoch in that other place too"; "It sells too cover all monthly expences" | Rules.hold_back: below making price offers what covers wage_bill + inputs + upkeep; Market offers stock − hold_of; held stock is not "offered" | SAME | |
| 29 | 211 | no hard floors or ceilings of our own, except rule 6 | Making.post_orders caps stocking up at 2 × need (ahead_q = 2 × need − held); output_rule rise floor maxi(1, …) and maxi(lv, 1000/n) | DIFFERENT | Two limits of ours: stocking up stops at two months' need; an output rise has a minimum (1 per mille, and one post's share as base) |
| 30 | 212 | no limit on last month or last year; credit follows orders, contracts, forecasts | bank not built; nothing found capping on last month in rules/making/market | SAME (credit LATER STEP 5) | |
| 31 | 222 | office: "if you done have one you lose out on ... 15% less ... one office building should be able to hold 10 plants" | not built | LATER STEP (9) | "9. Offices" |
| 32 | 223–225 | freight, "count the work que not passed work", trucks "fix it yourself in about 4 months", workshop "about 5% are lost" | not built | LATER STEP (4) | |
| 33 | 228 | "stress for workers reduced output based on workers" | not built (Households.quit_bar_base_pm returns 10% always) | LATER STEP (9) | |
| 34 | 235 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... BEFORE ACCEPTING A GRANT"; "you can't fail before you exist ... no worker but also no expenses beyond building" | Building PLAN table (not a company, no staff); Month line 163: Grants.apply(world, plan) after the plan is made; the company is created when the plant opens | SAME | |
| 35 | 251 | three ways a company ends: sales death in two years, plants shut, buy-out | not built (EconFace.insolvency refused before step 5) | LATER STEP (5) | "5. ... the three ways a company ends; the court" |
| 36 | 262 | "they are laied of its loans are payed in full ... the owner is taking to court" | not built | LATER STEP (5) | |
| 37 | 277–278 | "we take how it works and transfer over not take the code" | households.gd written new (PopStore pools by hb and inc band) | SAME | |
| 38 | 302 | "Oh no wholesale does  not mean unchecked" | a process rule (Maja's verdict table), no code | SAME (no code) | |
| 39 | 308 | pools: "That's fine" | PopStore leaves keyed hb (area) + inc (band), pool accounts | SAME | |
| 40 | 314 | "what are you paying power and water on if you can't pay the rent?" (food, then rent, then water and power) | Households.post_orders: food budget = all money, then rent_set_aside, then the store; no grid in step 3 | SAME | |
| 41 | 316 | "No hard floors or ceilings of our own" (household price floors removed) | no price floor or ceiling in households.gd orders (worth = food budget) | SAME | |
| 42 | 332 | "Housholds follow terras latest plan" | homes on the town grid not built beyond the landing shelters | LATER STEP (7) | |
| 43 | 337 | "the three rules for price should be applied here too" (salaries) | replaced by the 2026-11-18 hiring-offer ruling (row 50) | SAME (superseded) | |
| 44 | 342 | "the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | hire row pay fixed (Company.staff_change "pay"); changes only by yearly_raise, negotiate, or a move | SAME | |
| 45 | 345, 504 | yearly raise: "the minimum of this is up to the government, 2% is a good start" | Households.yearly_raise_month: lever ECON_YEARLY_RAISE_MIN_PCT default 2 (×10 per mille); Company.yearly_raise(raise_choice, min) | SAME | |
| 46 | 347 | "that's fine for hiring" (the hiring salary moves) | Company.hiring_salary / set_hiring_salary per tier and area; Rules.salary_rules | SAME | |
| 47 | 352 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | QUIT_BAR_GOOD_PM 100, QUIT_BAR_PER_YEAR_PM 10 per full year at the row's "since", QUIT_BAR_MAX_PM 150; clears_bar new ≥ old × (1 + bar); stress part waits (step 9) | SAME | |
| 48 | 362 | "underpayed workers go to the union, they can quit ... if not they may unionise" | quitting: Households.labour_month (SAME); unions not built | SAME / LATER STEP (9) for the union part | |
| 49 | 369 | "avrage ask salleries in the company and underpayed is based on that line, that way both old and new can become underpayed" | Company.avg_pay(world, cid, post_tier): the average of one post tier only; _negotiate compares each row to its tier's average | DIFFERENT | The line is the average of the same post tier (Wilma's proposal, line 423), not of the salaries in the company |
| 50 | 439–449 | "increases should not stack for seperate offers, infact they should fall back to the original rule for settin on hire, then it should only climb max 5% if it cost not hire for one month"; "5% each month ... i never said i wanted the rule for lowering" | Rules.salary_rules: ONE offer per company per tier and area; it climbs OFFER_CLIMB_PM 50 when any post of that tier and area was open a whole month (open_left), and clears back to starting_salary only when no post of that tier and area has been open a whole month; no lowering rule | DIFFERENT | Increases stack across separate openings: a new opening of the same tier and area is offered the climbed offer, not the original rule; and filling "the post" does not end the rise while another post of that tier and area has been open a whole month. Climb 5% each month and no lowering rule: SAME |
| 51 | 373–374 | keeping workers: "costs of hiring ... 6 months training ... payment after fire ... weigh say three months of vages"; "you have the right of it, and it should apply to builders" | Households.layoff owes WorkLaw.layoff_pay_months (lever LAW_LAYOFF_PAY_MONTHS 3) of the row's pay; unpaid → Justice.owe LAYOFF_PAY; adverts paid to papers (Media.job_advert, ADVERT_PM 100); TRAIN_MONTHS 6, TRAIN_START_PM 500; Rules.layoff_weighing; builders' crews go through the same staff_to_posts | SAME | |
| 52 | 407 | "On posts when you many an open post you pay the first time not every consecutive month after" | Rules._advertise pays open − paid_for once, in the month opened; _hire hires only into paid posts and pays nothing; record clipped to posts still open | SAME | |
| 53 | 415 | "the manager, negotiation can bring it closer to avrage" | Households._negotiate: once a year (NEGOTIATE_MONTH 7), rows below their tier's average ask half the gap; granted if the account holds a year of the rise; no manager or chief read | DIFFERENT | No manager in the negotiation: the outcome does not depend on any manager; a fixed half of the gap |
| 54 | 432 | "Sallery should be calculated as avrage living in the area and food plus half of both again"; "On sallery it's an avrage of the area" | superseded by row 56; area_rent is the plain average of open landlords' @home asks in the area | SAME (superseded; "avrage of the area" kept) | |
| 55 | 442 | "Yes hand it built, this should stabilise workers and allow unemployed in" | built (row 50) | (see row 50) | |
| 56 | 464, 472 | "just rent at 2×"; "3 5x housing try it"; then "2", "Merge with 2" | Rules.starting_salary = area_rent × STARTING_RENT_PM 2000/1000 × TIER_PM | SAME | |
| 57 | 452–453 | "Can we not make a 2d array to keep all things about the hires? Sallery start date so forth?"; "You can merge if all rows match" | staff entry {"n", "hires": [{"n","pay","since","train"}]}; Company._tidy merges only rows with the same pay, since and training state | SAME | |
| 58 | 458 | "Record it make them pay after our if they refused take it to court" | Households: unpaid rest → Justice.owe(... "UNPAID_WAGES"); collected next month; petition after PETITION_MONTHS 12, wind-up refused before step 5 | SAME (court LATER STEP 5) | |
| 59 | 478 | "The build crews at start should not be hiring at all. They should start with a job already active." | HomeBuilders.land: Households.hire(..., placed=true): no needs test, no advert, trained | SAME | |
| 60 | 483 | "Place the goverment staff from startb with the builders and lets set their sallery at 2.5 from start same for builders" | Landing line 173: Households.hire(..., -1, true, true) placed; pay = Rules.placed_salary = area_rent × PLACED_RENT_PM 2500/1000 × TIER_PM | SAME | |
| 61 | 492 | "Screw lowering food, double the rent" | TypeTable.HOME_RENT_PM 2000 (new home 193.96); Landing.SHELTER_RENT 97 | SAME | |
| 62 | 497 | "10 purple each" | TypeTable FARM line qty 240, labour G18 S5 Sp1 (24) | SAME | |
| 63 | 501 | "The district the plant hiring is in." | Households.hire pays Company.hiring_salary(world, cid, tier, plant_area); salary_rules keys by plant_area | SAME | |
| 64 | 506 | "But emplyees only apply to jobs that meet their needs" | Households.hire: pay < needs_per_worker(area) and not placed → "no applicants: the pay is below their needs", 0 hired | SAME | |
| 65 | 519, 523 | "Company and people should be able to stock up if the price is low"; "what's low should be against what its worth to the buyer" | companies: Making.post_orders AHEAD order when cheapest ≤ worth × AHEAD_BELOW_PM 800 and the input keeps; households: the food store (15f ruling) at any price | SAME (households follow the later 15f ruling) | |
| 66 | 545 | "the goverment starts with its subsidiaries as before"; "All company types needs to be able to be created as private ... the conitions for new ones don't get switched on" | Landing: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL, POLICE (no plant), ADMIN, housing office LANDLORD, Colony Stores SHOP, public works; only FARM is foundable in step 3 (Month.FOUNDABLE, plan 13 "tested first on food alone") | SAME | |
| 67 | 548 | "Yea they all get tax brackets" | not built | LATER STEP (8) | |
| 68 | 550–551 | "I DID NOT SAY GIVE EVERYONE ... GRANTS"; "No split trucks and workshops" | Grants.KINDS: FARM, BAKERY, TRUCKER (HAULIER), TRUCKSHOP, all FAMILY size | SAME | |
| 69 | 553, 638 | "the goverment can lean on companies if they don't comply or on the union" | not built | LATER STEP (9) | |
| 70 | 560 | "They can't order when there's not a ship there to take the order ... the full period of waiting every time" | Ship.order refuses with no ship in port; delivered when that ship calls again | SAME | |
| 71 | 565–567 | imports: "a company or the government can order from the home world what it needs" (step 3: "orders to the home world") | Ship.order exists, but nothing in sim/ calls it (grep: Ship is used only in month.gd for land and month) | DIFFERENT | No company ever orders from the home world: imports are never placed |
| 72 | 569 | "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR" | Ship has no limit beyond the ship in port | SAME | |
| 73 | 577 | "5 building companies and alot of oppretunity" | HomeBuilders.land: five home-world builders (1 large, 2 average, 2 small) + the public works department | SAME | |
| 74 | 578 | "they should need 3 months up front and add 1 month of additional supplies every month" | Building.UP_FRONT_M 3: work starts when the site holds 3 months (or the remainder); every month tops up to 3 months ahead | SAME | |
| 75 | 591, 594, 598 | town grid "This sounds good"; "Below 250 start a gridd anyway"; "the closer to the coast you get the more expensive" | landing shelters on the town grid (Site/ColonyLayout); cell values, rents by cell not built | LATER STEP (7) | |
| 76 | 613, 615, 624 | "that's what changed rent levels"; buy your house out; apartment fee "they all pay together" | not built | LATER STEP (7) | |
| 77 | 629 | unions: "a small fee ... the workers get 2/3 normal sallery" | not built | LATER STEP (9) | |
| 78 | 655, 660 | "the goverment starts with its subsidiaries as before, and all three grant types open"; "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE" | EconPublish: the four grant levers at GRANT_START_PCT 50 from month one | SAME | |
| 79 | 655 | "no sectors beyond landfallpoint that's up to where things are built" | AreaStore.found_landing: one area | SAME | |
| 80 | 666 | "materials come with the start not finished buildings 5 years worth of equipment ... do you place out fucking plants from start????" | no plant placed at landing; Landing.STOCK MATERIAL 9700, COMPONENT 1060, TRUCK 20 (and FOOD 12000) | SAME | |
| 81 | 673 | "no the old system and the new for five years are not the same" | builders' capital = 3 months of their wage bill (BUILDER_CAPITAL_MONTHS 3), not five years of running costs | SAME | |

## Table 2: proposals, readings and starting numbers of ours (no user words behind them)

| paper:line | whose | what it says | what was built from it |
|---|---|---|---|
| 124 | Wilma | a builder's price: per unit of BW, materials on top | Company price "BW"; supplies ordered on the client's account (Building) |
| 139 | Wilma | old type names gone through one by one | type_table.gd TYPES |
| 180 | Wilma | rule 6's idle time | not built |
| 259 | Wilma | "turn the price" = back above the making price; buy-out = growing in a shared square | not built |
| 355 | Wilma | "up to 15%" caps the whole bar | QUIT_BAR_MAX_PM 150 |
| 357 | Wilma | stress lowers the bar toward 5%; 10% until step 9 | QUIT_BAR_STRESSED_PM 50 (unused); quit_bar_base_pm 100 |
| 386 | Wilma | three months' pay; advert a tenth of a month's pay per person hired; training half rising to full after six | LAW_LAYOFF_PAY_MONTHS 3; ADVERT_PM 100 (now per post opened); TRAIN_START_PM 500, TRAIN_MONTHS 6 |
| 391 | Bob | training as monthly hire groups; 1.75 months lost | hire rows with "train"; Company.trained_pm, trained_count |
| 395 | Bob | idle = the run of slack months | Rules._slack |
| 399 | Bob | lay off only if idle × pay > months × pay + advert + 1.75 × output × price | Rules.layoff_weighing |
| 403 | Bob | 19a staff not weighed | staff_to_posts 19a branch |
| 405 | Bob | can't pay the adverts → hires none that month | superseded: Rules._advertise pays post by post as money reaches |
| 411 | Wilma | advert paid in the month the post opens, whether or not hired; anew when it opens anew | Rules._advertise, record clipped to open posts |
| 418 | Wilma | negotiation once a year, depends on the manager and on money, never above average | Households._negotiate July, half the gap, account ≥ a year of the rise; Company.negotiate refuses above the tier average; no manager |
| 423 | Wilma | the average among the same kind of post | Company.avg_pay per post tier |
| 426 | Wilma | salary signal lines for rules 1, 2, 9 | superseded by salary_rules |
| 469 | Wilma | "3 5x" = 3.5 × rent, a trial | superseded by STARTING_RENT_PM 2000 |
| 485, 487 | Wilma | 2.5 × rent × the tier's share; later openings at 2 × | PLACED_RENT_PM 2500 × TIER_PM; Households.hire non-placed pays hiring_salary |
| 497 | Wilma | "10 purple each" = 10 people each | FARM qty 240 |
| 509 | Wilma | "their needs" = housing and food where they live | Rules.needs_line = cheapest landlord ask (else start_price_of LANDLORD, the full new-home rent) + 2.5 × needs_food |
| 512 | Wilma | only pay moves a salary; no raise for a post open for want of housing or skill | not built as such: salary_rules climbs on any post open a whole month, whatever the cause |
| 527 | Wilma | stock up as far as money reaches and goods keep | Making: up to 2 months' need, price ≤ 80% of worth (AHEAD_BELOW_PM 800), spoil < KEEPS_PM 50 |
| 529 | Wilma (decision) | a stock-up order buys only what NEED orders leave; its shortfall is not a signal | Market kind AHEAD, cleared after NEED |
| 583 | Wilma | the contract is its own record | Building CONTRACT table |
| 605 | Wilma | land 10% of the building bill | not read for this audit (Site.land_terms) |
| 639 | Wilma | a company on shutdown is not idle | not built |
| 676 | Wilma | the landing stock holds food | Landing.STOCK FOOD 12000 |
| (code) | Bob | the area's rent is the plain average of open landlords' asks; with none, the shelter at half a new house | Rules.area_rent |
| (code) | Bob | "a whole month" = open after last month's hiring and still open now | open_left, min(last, now) |
| (code) | Bob | "max 5%" = always 5% | OFFER_CLIMB_PM 50 |
| (code) | Bob | after a 19a month the offer holds | no_hiring_m |
| 243 / (code) | Otto (rebuild-building 4.4) | a plan re-reads rule 7 before signing and is given up if the signal is gone | Building.sign_round: give_up "the work is no longer there (rule 7)", besides "no builder" and "cannot pay the builder" |
| (code) | Wilma / Bob | landing START numbers | BUILDER_CAPITAL_MONTHS 3, TREASURY_START 2,000,000, SHELTER_RENT 97, STOCK, GRANT_START_PCT 50, PROGRAMME_M 24, EXTRA_PM 100, POLICE among the subsidiaries |

# Audit part B: rebuild-company.md lines 700–1423 against the shared tree (Otto's fork, 2026-11-18)

Shared tree as of commit 0c9e266 (the advert piece in). Code read for every row; comments not taken as evidence.

## Table 1: lines carrying the user's words

| # | paper:line | the user's words (short) | what the code does today | verdict | what differs |
|---|---|---|---|---|---|
| 1 | company:759 | "start answering all the fucking questions that have obvius answers" | process instruction, no code | not code | — |
| 2 | company:784 (12.2, 9) | landing stock = "five years' worth of equipment and materials" (9.12) | landing.gd STOCK {FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20}, offered by Colony Stores at the starting prices (Landing, lines 154–157) | SAME | (MATERIAL/COMPONENT = Bob's reading of the five years; FOOD 12 months is Wilma's addition, table 2) |
| 3 | company:798 (12.3, 14) | "It sells too cover all monthly expences" | rules.gd hold_back: below making price it offers enough to cover wage_bill + inputs + upkeep, holds the rest | SAME | loan repayments: no loans until step 5 — LATER STEP (5) for that part |
| 4 | company:809 (12.3, 15) | k = 5%: "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | rules.gd K_PM := 50; price_rule step_pm(K_PM, …) = k·s/(1+s), full k when sold 0 | SAME | — |
| 5 | company:816 (15b) | g = 5%: "25?! 5!!! CHANGE IT!!! STOP HEDGING" | rules.gd G_PM := 50; output_rule steps by step_pm(G_PM, …) | SAME (the number) | out of this range but read here: output_rule cuts the level in any month with unsold output (down = step_pm(G_PM, unsold, sold)); the user's rule 4 ruling in section 3 ("only lowered if over 50% … not sold 3 months in a row") is NOT in the shared tree's output_rule (no run count, no 50% test) |
| 6 | company:836 (15a) | rule 8 "the same signal says the work is covered" | rules.gd founding: only the share test (share ≥ running_cost); no coverage test in quantity | DIFFERENT | rule 8 not built in the shared tree (Bob's t51 not merged) |
| 7 | company:855 (15a) | running cost at the starting salary, citing "fall back to the original rule for settin on hire" | rules.gd running_cost: posts × TypeTable.salary(tier) (the type table's 300 G / 450 S / …) | DIFFERENT | posts are priced at TypeTable.salary, not Rules.starting_salary (2 × the area rent × tier share); Building.founder_needs reads the same running_cost × OPENING_M 3 |
| 8 | company:864 (15a) | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | rules.gd founding: have = standing sixths + Building.booked(…) + MADE plans holding a grant (Grants.granted_plans) | SAME | — |
| 9 | company:869 (15d) | "He should look for the shortest time" | building.gd sign_round line 253: quotes sorted by start, then total, then builder id | SAME | — |
| 10 | company:872 (15e) | family works its own farm; "ship food should be considered less desierable" | family posts filled by Rules.family_to_posts, not on payroll; Market.offers rank = price × (1000 + SHIP_LESS_WANTED_PM 250 × ship share)/1000 | SAME | (a quarter = Wilma's starting number, table 2) |
| 11 | company:881 (15e) | "FARMS DON'T SHUT" | rules.gd staff_to_posts 19a branch (lines ~346–347): any non-crew plant whose hired staff_count reaches 0 is Company.close_plant(…, "NO_STAFF"); staff_count does not count the family; building.gd:629 closes a newly opened plant for "LAW"; only law_company.gd:222 ever reopens (LAW). A closed plant makes nothing (Making) and family_to_posts skips closed plants | DIFFERENT | a FARM plant is still shut NO_STAFF when 19a lays off its last hired hand, family on it or not, and never reopens; a farm can also be shut at opening by LAW. Only the plan paper was changed (commit 90ed8b3), not the code |
| 12 | company:885 (15e) | farmers eat first: "THEY ARE THREE THEY CAN PRODUVE 30 … TAKE SIX OUT OF THIRTY SELL 24 … ENOUGH TO HIRE ONE PERSON" | households.gd post_orders: a founder with an open family farm takes Making.family_take(need + up to one more need) before any order (2 per person → 6 for 3); type_table: FARM FAMILY posts 4 (24 × 1/6), output_milli 240/6 × (1 − PENALTY_PM FAMILY 60‰) = 37.6 | DIFFERENT (the 30) | eating first and the 6 of a family of three: same. Three working on the four posts at full level make 3/4 × 37.6 = 28.2, not 30 (the family-size 6% penalty); so they sell 22.2, not 24. "Enough to hire one": 22.2 × FOOD 39.43 ≈ 875 against a G starting salary of 194 — enough |
| 13 | company:893 (15e) | "the farm would be their home … paying on any loans … and uppkeep" | households.gd homes(): a founder on its own farm is no town household; rent_set_aside charges a founder rent only while lives_apart; Rules.winnings subtracts upkeep before winnings | SAME | loans: LATER STEP (5) |
| 14 | company:899 (15e) | "I think two is better" (a loss is carried forward) | rules.gd winnings/pay_winnings: loss_carried, pays_down, carried_after | SAME | — |
| 15 | company:899 (15e) | "maybe the family can put some away for the hard months" | not built; paper: "noted for then, not built" (step 4) | LATER STEP (4) | — |
| 16 | company:912 (15e) | "take winnings no sallery, wich comes after" | family not on payroll; Rules.winnings = rev − inputs − wages − upkeep − adverts − layoff pay − debts, capped at balance − keep; paid in JUSTICE after collect_debts | SAME | — |
| 17 | company:923 (15f) | "they buy 2 units if food instead of one, store it and use it in emergencies" | households.gd post_orders: store order want ≤ need (double, never more); eats from store only when the month's food falls short (line ~720) | SAME | — |
| 18 | company:924, 933 (15f) | "six months of food in storage"; "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | STORE_MONTHS := 6; want = min(need − farm_store, 6·need − held − farm_store) | SAME | — |
| 19 | company:926 (15f) | "The first, if your running low … i don't think you wait" | store order is posted at today's offers whatever the price, limited only by store_budget | SAME | — |
| 20 | company:948 (15c) | "they should not cut for the start" | building.gd seller_signal returns {} until first_quote_month ≥ 0, so price_rule and output_rule do nothing for builders | SAME | — |
| 21 | company:948 (15c) | "they should not increase prices for claimed jobs" | building.gd sign_round line 292: a plan "signed to wait behind the builder's book" adds its whole bill BW to unmet_pending; _month_set moves it to unmet_wait_bw; seller_signal gives it as unmet_above, which price_rule reads for R1 (rise) and output_rule for R3 | DIFFERENT | a job signed and waiting in the book is counted once (the month after signing) as unmet demand above the price: it raises the BW price and the crew level |
| 22 | company:955 (15c) | "At start id assume they know work is coming" (no crew layoffs before the first quote) | same seller_signal {} → no level change; crews placed at level 1000 | SAME | — |
| 23 | company:977 (23a) | bread: "the company can win by lowering" (refusal of price counts for a cut) | price_rule down = step_pm(K, offered − sold, sold): goods left unsold for any reason with money behind them count | SAME | — |
| 24 | company:1008 (35) | owners "individually counted on company start" | Households.make_founder at plan made (Building) | SAME (by Wilma's reading 60a, table 2) | — |
| 25 | company:1112 (61a) | grants "limited time … reset to zero" | grants.gd monthly: programme until start + PROGRAMME_M 24; at the end LawOps.end_programme sets the lever to 0 | SAME | (24 months = starting number, table 2) |
| 26 | company:1119 (61b) | "put a max sum into the grant based on how many darms they want maybe a little extra" | grants.gd budget_for: wanted × grant_planned + EXTRA_PM 100‰; sum_left stops grants at 0 | SAME | — |
| 27 | company:1163 (12.11) | "I think most of these needs to be worked in" | placement of 36 old systems; most are later steps | not code (placement) | — |
| 28 | company:1276–1288 (13, step 4) | farms away from towns; the four answers | not built | LATER STEP (4) ("Still for step 4, not built before trucks and roads") | — |
| 29 | company:1301 (13, step 8) | "the government can order stockpiles to help in famin once we get back to politics" | not built | LATER STEP (8 / politics) | — |
| 30 | company:1309 | "atleast one other reviews each peace of code made" | process | not code | — |
| 31 | company:1321 | "a backend column … that records all things happening like a log" | core/logbook.gd; world_state.gd log_rows not saved/hashed; tests/core/test_logbook.gd | SAME | — |
| 32 | company:1417 (15) | review the whole thing from their perspectives | process | not code | — |

## Table 2: proposals, readings and starting numbers of ours in this range (no user words behind them)

| paper:line | whose | what it says | what was built from it |
|---|---|---|---|
| company:757–762 (12) | Wilma | points 1–109 are Wilma's decisions, not the user's | as below |
| company:766–780 (12.1, 1–8) | Wilma | areas, districts, land bought at land price, squares, siting, order of the month, money at start set by us | land bought at signing (Building); builders' capital: 3 months of their landing wage bill (seed 1: company:1 55,641 = 3 × 18,547) |
| company:784 (9) | Wilma / Bob | food in the landing stock is Wilma's addition; material/components = Bob's reading of "5 years" | STOCK FOOD 12000 (12 months), MATERIAL 9700, COMPONENT 1060 |
| company:787 (11) | Wilma | landing shelters with a low rent | SHELTER_RENT 97 (half a new home's 194) |
| company:794 (14) | Wilma | making price = month's costs / normal full output | Making.making_price |
| company:799–808 (15) | Wilma | the k·s/(1+s) shape, s definitions, signal needed, sold 0 = full k | step_pm, price_rule |
| company:813–820 (15b) | Bob (proposal) | output moves by g·s/(1+s); for rule 4 s = unsold/sold | output_rule cuts by step_pm(G, unsold, sold) every month with unsold output (see row 5) |
| company:821–825 (15b) | Bob's reading, Wilma's yes | change computed; cut floored; rise at least one post's share and ≥ 1‰ | output_rule new_lv line |
| company:826–828 (15a) | Wilma | work = spent or tried, averaged per month over the last twelve months, at today's prices | Rules.work: average over the history's months present (h.size(), up to WORK_MONTHS 12), × cheapest offer |
| company:829–835 (15a) | Bob's reading, Wilma's yes | sum twelve months / 12; months before the colony at the eating need | not in the shared tree: work() divides by h.size() and does not count the pre-colony months at the need |
| company:840–848 (15a) | Bob's reading, Wilma's yes | what a plant seen delivers for rule 8 | not built (rule 8 not built) |
| company:849–853 (15a) | Wilma | shares by plant, by sixths; plan the largest size that passes and money reaches | founding: share = work × six / (have + six); Building picks the size |
| company:854–859 (15a) | Bob, Wilma's yes | running cost at the starting salary | not built (TypeTable.salary, row 7) |
| company:860–861 | Wilma | management bends the reading; nothing limits plans at once | management: not built here (12.11, 77); no limit: built |
| company:896–898 (15e) | Wilma | family moves to the farm from the day it opens; rents until then | lives_on_own_farm / lives_apart; founder keeps job until signed (Maja, 2111905) |
| company:908–910 (15e) | Wilma | family adults fill the farm's posts first; beyond them hired | Company.family_fill; hire_wanted nets the family |
| company:916 (15e) | Wilma | winnings for every family-size company, not only farms | Rules.pay_winnings for any company with a family |
| company:917–918 (15e) | Wilma (starting number) | ship food ranked a quarter dearer | SHIP_LESS_WANTED_PM 250 |
| company:938–941 (15f) | Wilma | store after the month's needs: food, then rent, then store; replaces the two-month cap | post_orders: food_budget, rent_set_aside, store_budget |
| company:952 (15c) | Wilma | "the start" = until the first plan asked for a quote | Building.first_quote_month |
| company:957–991 (16–29) | Wilma | rule 6 at 12 idle months (step 6); rule 5 order (step 6); 18 no rule 3 while holding; 19, 19a, 19b, 20–29 | 18: output_rule up = 0 when holding; 19a: staff_to_posts lays off in proportion and closes the plant (row 11); 28: no speed limits; rules 5, 6, sales death: not built (steps 5–6) |
| company:995–1002 (30–34) | Wilma | freight, trucks, roads, planet | step 4 |
| company:1007–1033 (35–42) | Wilma | pools; starting salary 1.5 × (rent + food) (37, 37a); needs = rent + food (38); changing jobs; reach; benefit; ships | 37 superseded by the user's 2 × rent (STARTING_RENT_PM 2000); needs_line = cheapest rent + 2.5 × food; the rest not checked in this part |
| company:1037–1051 (43–49) | Wilma | services and utilities | step 4 |
| company:1056–1088 (50–55) | Wilma | bank, owners, liability, buy-outs | step 5 |
| company:1092–1110 (56–61) | Wilma | contract paid monthly, price fixed at signing, stops after 3 unpaid months; book in signing order; plan money in its own account; founder at plan made (60a); given-up plan settled; one grant per household | building.gd unpaid_m ≥ 3 stops (line 580); book() sorted by n; plan account; make_founder at plan; Grants.reclaim; Grants.had |
| company:1115–1116 (61a) | Wilma (starting number) | programme window 24 months; all four open in month one | PROGRAMME_M 24 |
| company:1123–1126 (61b) | Wilma (reading, starting numbers) | the other three grants the same way; farms wanted = feed the colony at full output; extra a tenth | Grants.wanted (food kinds: short of need / family output; others: one per area with none); EXTRA_PM 100 |
| company:1131–1159 (62–76) | Wilma | taxes, levers, law, unions, blame, prices for voters | later steps; not checked here |
| company:1170–1235 (77–107) | Wilma | worked-in old systems (management, upgrades, mothballing, …, public works 99 "builds at cost when the government tells it to") | public works: placed at landing, never commissioned (no purse commissions until step 8); the rest later steps |
| company:1239–1241 (108–109) | Wilma | reference wage, fiscal report | not checked here |
| company:1290–1295 (13) | Wilma | view on farms away from towns, staging | not built (step 4) |
| company:1338–1360 (13) | Wilma | how each step is tested; month one must add up on paper | process |
| company:1371–1396 (13) | outside review / Bob | eight things to watch, results not faults | process |
| company:1414 (14) | Wilma | landing shelters despite "not finished buildings" | shelters built (SHELTER_RENT 97) |

# Audit part C: rebuild-households.md and rebuild-law-face.md against the shared tree

The code was read in `game/` of the shared tree on 2026-11-18. Every row was checked against the code lines themselves, not against doc comments.

## Table 1: lines carrying the user's words

| # | paper:line | the user's words (verbatim, short) | what the code does today | SAME / DIFFERENT | what differs |
|---|---|---|---|---|---|
| 1 | households:7 | "we take how it works and transfer over not take the code" | A ruling on how the work was done; no code mechanism to check. | n/a (process) | |
| 2 | households:8 | "Oh no wholesale does not mean unchecked" | A ruling on how the work was done; no code mechanism to check. | n/a (process) | |
| 3 | households:27, plan 35 | "they should become individually counted on company start ... but don't malt to many people to track" | month.gd `_found_one` → `Households.make_founder` makes the founder record (table "founder", own account, household's share of savings) when the PLAN is made, before any company exists. `release_founder` / `release_idle_founders` put them back when they own nothing. There is one record per founder. | DIFFERENT | The user said "on company start". Built: counted at plan making (60a, Wilma's decision). With plans made and given up every month (seed 1: 40–60 a month), founders are made and released monthly whether or not a company ever starts. "Not too many to track" holds: one record per plan. |
| 4 | households:29, plan 36 | price floors and ceilings removed (36) | Read in households.gd `post_orders`, `pay_rent`, `hire`, `labour_month`: no floor or ceiling of ours on any price. The only cap is QUIT_BAR_MAX_PM 150, which is the user's own "up to 15%". | SAME | |
| 5 | households:31, 142 | a short household pays "food, then rent, then water and power" (9.1) | `post_orders`: the food order's budget is all the money (`food_budget := money`); `pay_rent` runs in SETTLEMENT after the buying, from what is left. There is no water or power. | SAME for food then rent. Water and power: LATER STEP ("Water and power have no grid in step 3", households:142) | |
| 6 | households:148 | "But emplyees only apply to jobs that meet their needs" (9.2) | `Households.hire`: if `pay < needs_per_worker(area)` and not placed → 0 hired, row "no applicants: the pay is below their needs". Needs = `Rules.needs_line` = the cheapest rent + 2.5 × the food price. | SAME | |
| 7 | households:149 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | `quit_bar_pm` = min(QUIT_BAR_MAX_PM 150, QUIT_BAR_GOOD_PM 100 + QUIT_BAR_PER_YEAR_PM 10 × full years at the row's "since"). `clears_bar`: new ≥ old × (1 + bar). | SAME for 10%, +1%/year and the 15% cap. "Less if stressfull": LATER STEP (9) ("waits for stress at step 9"); `quit_bar_base_pm` always returns 100. | |
| 8 | households:154; law-face:239 | layoff pay, ruled "On the workers rules i belive you have the right of it, and it should apply to builders" (3 months, a law) | `WorkLaw.layoff_pay_months` = lever LAW_LAYOFF_PAY_MONTHS, default 3, clamp 0–12, read on the day. `Households.layoff` owes k × the row's own pay × months to the pool, pays it from the company's account as far as it reaches, and the rest goes to `Justice.owe(... "LAYOFF_PAY")`. Builders' crews are laid off through the same `Households.layoff`. | SAME | |
| 9 | households:155, 159 | "The owners of a family farm should take winnings no sallery" | `Company.family_*`: the family fills posts and is on no payroll. `Rules.winnings` / `Rules.pay_winnings` run in JUSTICE after `collect_debts` and pay into the founder's account (`Households.pay_winnings`, booked "winnings"). | SAME | |
| 10 | households:155, 160 | "the farm would be their home" | `Landing.rent_due`: a founder whose plan's company is an open FAMILY FARM → {} (no rent). `lives_on_own_farm` checks type FARM, size FAMILY, OPEN. | SAME | |
| 11 | households:164 (plan 15e) | "ship food should be considered less desierable, wich would men the swap happens sooner" | `Market.order` rank: price × (1000 + SHIP_LESS_WANTED_PM 250 × ship share)/1000. `Households.food_by` → "RANK" when the budget covers the need, else "PRICE" (cheapest first). | SAME (the 25% is ours: Table 2) | |
| 12 | households:165 (plan 9.2) | "the manager, negotiation can bring it closer to avrage" | `_negotiate`, in NEGOTIATE_MONTH 7: a row below `Company.avg_pay` of its tier asks pay + half the gap. It is granted if the account holds 12 months of the rise (`Company.negotiate`), otherwise a "refused" row. | SAME (the terms are ours: Table 2) | |
| 13 | households:166; law-face:234 | "the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | `yearly_raise_month` (January, from the first new year): `Company.yearly_raise(raise_choice, lever ECON_YEARLY_RAISE_MIN_PCT 2 × 10)` multiplies every hire row's pay by 1 + max(choice, minimum). `raise_choice` defaults to 0, so the minimum is given. Pay is otherwise set on hire (the hire row's pay). | SAME | Note: law-face:266 says the minimum "has no effect until step 8 ... a worker's salary stays where it was set on hire". The code applies it now; this is a paper-vs-code difference on a line that is not the user's (Table 2). |
| 14 | households:198–201 (plan 15f) | "They stockplie to have have six months of food in storage, i think as often as they can"; "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT" | STORE_MONTHS 6. `post_orders`: a NEED order for the month, then an AHEAD order of min(need, 6 × need − held), from the money left after food and rent, at any price, sized to today's cheapest offer. | SAME | |
| 15 | households:202 (plan 15e) | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" | `post_orders`: before any order, a founder with an open own farm takes `Making.family_take(farm, FOOD, need + min(need, 6·need − held))` from the farm's stock, with no money and never offered. | SAME | |
| 16 | households:202 (plan 15e) | "THEY ARE THREE THEY CAN PRODUVE 30 ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24" | TypeTable FARM LARGE: qty 240 with 24 posts. FAMILY = 1 sixth with PENALTY_PM FAMILY 60, so `output_milli(FARM, FAMILY)` = 40 × 0.94 = 37.6 on 4 posts (G3 S1). Three of the family on it: 3/4 × 37.6 = 28.2. Take for 3 persons: need 3 + double 3 = 6. | DIFFERENT | Three workers make 28.2, not 30: 9.4 a worker, not 10, because of the family-size penalty of 60‰ (ours, type table). The take of six matches; the sale would be 22.2, not 24. |
| 17 | households:174 (9.6) | home world only by ship (ruling) | Settlers land and leavers go only in `Ship._arrive` (`land_settlers`, `departures`), with savings brought in the same call. No food aid (H6): no code path found. | SAME | |
| 18 | law-face:154 (plan 8.3) | "if not the owner is taking to court, where the bank can either settle for a smaller amount or demand payment over time ..." | `Justice._liquidate` → `EconFace.insolvency_court_liquidation`: refused before step 5, row "wind up refused". There is no creditor order, settlement or payment over time. | LATER STEP (5) ("Until step 5: no company can end") | |
| 19 | law-face:166 | the choice between settling and payment over time "the user gave that choice to the bank" | Not built. | LATER STEP (5) | |
| 20 | law-face:250 | layoff pay "a debt like unpaid wages, and can end the company" | justice_ops NO_PLAN_KINDS = ["UNPAID_WAGES", "LAYOFF_PAY"]: one whole row, due next month, also for a small firm. PETITION_KINDS holds LAYOFF_PAY. After PETITION_MONTHS 12 overdue, one petition per company (`justice.petitioned`), then `_liquidate` (refused before step 5). | SAME. Ending the company: LATER STEP (5) | |
| 21 | law-face:251 (plan 9.2) | "Record it make them pay after our if they refused take it to court" | `Households.pay_wages` (line ~444): the unpaid rest goes to `Justice.owe(... "UNPAID_WAGES")`, collected by `collect_debts` and booked by the pool as "wages" (`debt_received`). After 12 months overdue → petition (Bob's reading of "refused"). The court is refused before step 5. | SAME. The court: LATER STEP (5) | |
| 22 | law-face:316 | ceilings: "failing is a result, not a fault" (section 1 of the plan) | No ceilings are built. | LATER STEP (8) | |
| 23 | households:32 (9.3) | stocking up: buy ahead when a price is under what the good is worth | Food only in step 3: the AHEAD order pays any price it can (15f, the later ruling). No other goods are on sale. | SAME for food under 15f. Other goods: LATER STEP (4) | |
| 24 | households:34, 147 (23) | hunger counted from need, not from orders | STORE / BUDGET rows: need = persons × NEED_PER_PERSON FOOD 1000. The famine test is short_pm ≥ FAMINE_PM 250 of need for FAMINE_MONTHS 3. | SAME | |
| 25 | households:35 (23a) | short of money is not the same as refusing the price | Market unfilled reasons NO_MONEY / PRICE / SOLD_OUT / NO_SELLER; orders carry a budget per line. | SAME | |

## Table 2: proposals, readings and starting numbers with no user words behind them

| paper:line | whose | what it says | what was built from it |
|---|---|---|---|
| households:80 | Maja (decided) | posts go to the post's own skill first, then higher; shared over bands in proportion to their jobless | `Households.hire`: TIERS from the post's tier up; `split_lr` over BANDS by unemployed count |
| households:84–90 | Maja, accepted by Wilma | 1,000 settlers, 400 households of 2.5; 80 households a band; working-age 150, children 44, retired 6; LF 90%; skills ‰ by band; ages 350/450/200; savings 1,800/3,600/7,200/14,400/36,000; 180 builders' crew + 40 public works | HOUSEHOLD_SIZE 2.5, BAND_PERSONS 200, BAND_WORKING 150, BAND_CHILDREN 44, BAND_RETIRED 6, LF_PM 900, BAND_SKILLS, ADULT_AGES, SAVINGS_PER_HOUSEHOLD as listed. Crews wanted = `TypeTable.posts(BUILDER, size)`: LARGE 60, AVERAGE 40 ×2, SMALL 20 ×2 = 180; public works AVERAGE 40. Placed (hire placed=true) at `Rules.placed_salary` (2.5 × rent). |
| households:103 | Wilma | an employed founder keeps their post until the plan signs | `make_founder`: `_promise_post`, `in_post` adult; QUIT at signing (`take_up_posts`) |
| households:104 | Maja's reading of 60c, Wilma's yes | until signing, a founder still in post eats and is paid with the pool | `pay_rent` skips founders not `lives_apart`; `move_store` moves only the mouths that left |
| households:105 | ours | a founder takes one household's share: pool balance × 2.5 ÷ persons | `household_share` = savings × HOUSEHOLD_SIZE / n; `make_founder` transfers min(share, savings) |
| households:122 | Wilma | the landing shelter rent is half a new house's rent | the shelter rent = half the type table's new home (97 after the user doubled rent) |
| households:151 | Wilma's readings | "up to 15%" caps the whole bar; stress lowers the base toward 5% at step 9 | QUIT_BAR_MAX_PM 150 caps base + years; QUIT_BAR_STRESSED_PM 50, not read yet |
| households:163 | Wilma's ruling of "settled or carried" | a founder with open debt goes back; the debt is carried | `release_founder` → `_carry_debts`, table "founder_carried" |
| households:164 | Wilma's decision on who it binds; number ours | ship food a quarter dearer, RANK vs PRICE | SHIP_LESS_WANTED_PM 250; `food_by` |
| households:165 | proposal (plan 9.2 "(proposal, how a negotiation goes)") | the worker negotiates first, and only if that fails looks for better pay | Not built in that order: `labour_month` runs the quitting EVERY month and `_negotiate` only in July, so in eleven months of the year a worker moves for pay with no negotiation first. |
| households:179–191 | Maja (what the plan is silent on) | seeded founder draw weighted by able households; unemployed first then outside LF then employed, skilled first; one grant per household; the founder takes a household's share; opening money narrows founders; going back to the status they came from | `pick_founder`, `_free_adult`, pool "granted" count, `household_share`, `founder_needs` (3 × running_cost), `release_founder` "was" |
| households:193–197 | Wilma's ruling, Bob's budget argument | each order's money is its line's budget; food's worth = the whole food budget | `post_orders`: `worth := food_budget := money` |
| households:199–201 | ours (on the user's 15f) | AHEAD after NEED; budget = money − food − rent; posts none when nothing is offered | as described in Table 1 row 14 |
| households:203 | Wilma's decision | a store order's shortfall is no signal for the sellers or rule 7 | Market clears NEED before AHEAD; AHEAD shortfall not counted |
| households:209–210 | Maja (July is hers; "once a year" Wilma's) | the negotiation once a year in July; halfway to the average if the account holds a year of the rise | NEGOTIATE_MONTH 7; ask = pay + gap/2; cost_year = rise × persons × 12 |
| households:212–213 | Maja | who leaves on a ship; attractiveness jobs 40% / food 40% / homes 20% | `departures`, `remember_attractiveness`; SETTLERS_PER_CALL 200 × attractiveness (ship.gd, START) |
| households:215–220 | Maja, new numbers | births 4.0 a woman at the lowest band, 40% fewer at the highest, × fed × room; 90% of 18-year-olds in LF; 1% a month re-entry; band averaging a sixth, 10% margin | demography.gd TFR_BASE 4.0, TFR_INCOME_FALL 0.4, GROW_LF_PM 900, ... |
| households:221 | Maja | famine = a quarter of need uneaten 3 months running | FAMINE_PM 250, FAMINE_MONTHS 3 |
| law-face:126 | Wilma, 2026-11-18 | "One petition per company until the court answers, logged once, a refusal logged once" | `_petitions`: `justice.petitioned[org]`, skipped after the first |
| law-face:134 | Wilma, 2026-11-17 | "a debt nobody collects is a fault, not a design": collect every open due debt monthly, oldest first | `Justice.collect_debts` |
| law-face:243 | Wilma's decision | layoff months as the law stands on the day | `layoff_pay_months` read at layoff |
| law-face:254 | Bob's reading | "refused" = unpaid 12 months past due | PETITION_MONTHS 12 for UNPAID_WAGES |
| law-face:256–260 | Anni | wages and layoff pay owed whole, not in the small-firm instalments (8 over 24 months, from v8) | NO_PLAN_KINDS; PLAN_PARTS kept for other kinds |
| law-face:266 | Anni (paper) | the yearly raise's minimum has no effect until step 8; salaries stay where set on hire | The code differs from this paper line: `yearly_raise_month` raises every January from now by at least ECON_YEARLY_RAISE_MIN_PCT 2. |
| law-face (all "(Anni's decision)") | Anni | creditor order, settlement terms, licence terms, lease rent, KEEP→lease, ratios as levers, essential services, lockout | Step 5–9 items; none built in step 3 except as levers |

# Audit D: MASTER-PLAN.md, the economy rulings against the shared tree

Otto, 2026-11-18. The code was read in the shared tree as it stands (game/, rules.gd d2ddf83f, company.gd 6e54dcfc,
making.gd a0855ac0, market.gd c9954c64, building.gd 739c04b6, households.gd 247d57b7, landing.gd 52ad4e73,
justice_ops.gd 204b892f, type_table.gd 5a1338e3, grants.gd 3f832ea3, ship.gd 8ad7e1f8, month.gd 7563b979). Code lines,
not comments. "LATER STEP (n)" = the plan's build order (rebuild-company.md section 13) puts it in step n.

## Table 1: the user's words against the code

| # | paper:line | the user's words (verbatim, short) | what the code does today | SAME / DIFFERENT | what differs |
|---|---|---|---|---|---|
| 1 | MP:224-236 | "every producer gets all eight rules" (price up, down, produce more, less, add capacity, reduce capacity, start, not start) | Rules.price_rule R1/R2 (K_PM 50); output_rule R3/R4 (G_PM 50); founding() R7/R8 (covers = share >= running_cost). No rule 5 or 6 code anywhere in sim/economy (company.gd:668 only names rule 5 in a comment). | SAME for 1-4, 7, 8; LATER STEP (6) for 5, 6 | Rules 5 and 6 are not built: step 6 "Rules 5 and 6 and growing by size, buy-out or a new plant". |
| 2 | MP:235 | "no floors, caps or locks of our own" (the order's terms) | rules.gd:190 a rise is at least maxi(lv, 1000/n)×up/1000 and at least 1 per mille (a minimum step of ours so a level at 0 can climb); no other floor or cap in the price and output rules. | SAME, one note | The rise has a minimum step of ours (one post's share of full); it is a floor on a rise, not on the level. |
| 3 | MP:238-240 | "All company types needs to be able to be created as private ... then the conitions for new ones don't get switched on" | month.gd:27 FOUNDABLE := ["FARM"]; month.gd:127 founding() loops only over FOUNDABLE. | DIFFERENT | Only FARM can ever be founded. No BAKERY, HAULIER, TRUCKSHOP or any other type is ever planned, though their grants are open (grants.gd KINDS). The plan's step 3 says "Tested first on food alone" (Wilma's). |
| 4 | MP:246-252 | "They don't get skipped even if the rules won't be able to take affect because its free" | Rules.work() returns 0 for a type that sells no item (services); no service type is foundable (row 3). | LATER STEP (4) | Services and work slots are step 4 ("the types with work slots (public services, shops, utilities on the grid)"). |
| 5 | MP:254, 257 | "1. Yes they may order in" (material and components from the home world) | ship.gd:167 Ship.order exists (refuses only: unknown company, not an item, nothing asked, no ship in port, hold full). Nothing in sim calls Ship.order (grep: no caller outside ship.gd). | DIFFERENT | No company or plan ever orders from the home world: imports are never placed. Step 3 lists "the ship schedule with arrivals, departures and orders to the home world". |
| 6 | MP:254-261 | "I don't like hard rules ... a soft it will sell less just took keep afloat, build up stock for better prices ... if your have not made everyone know all stocks" | rules.gd:149 hold_back: below the making price it offers what covers expenses and holds the rest; market.gd:87 an offer is stock − waiting − hold. Held stock is in no offer, so in no one's price reading. | SAME | |
| 7 | MP:256, 262 | "3. Schools and charge it's a bracket in taxes" | No school, clinic or tax bracket code in the rebuild economy. | LATER STEP (8) | Step 8: "Taxes, brackets, budget lines". |
| 8 | MP:264-266 | "per pulpe plus staff is how taxes for schools are calibrated Yea they all get tax brackets" | Not built. | LATER STEP (8) | |
| 9 | MP:268-274 | "A hard limit?"; "I don't like hard rules you know that" (on at most six forming) | No ENTRY_MAX_FORMING / MAX_FORMING in sim (grep empty); month.gd:126 founding loops while rule 7 passes, a household can pay and a site is free. | SAME | |
| 10 | MP:282-286 | "REMOVE THAT LIMIT ... JUST THE FUCKING MAX CAP ON HOW MANY TOTAL COMPANIES CAN BE MADE" | No cap on companies or plans in month.gd / building.gd (row 9). | SAME | |
| 11 | MP:277-278, 287 | "instead of reading the leftovers, they read an avrage of all avaliable jobs" | Rules.work (rules.gd:615): ordered quantity of the type's item averaged over up to WORK_MONTHS 12 settled months × today's cheapest offer; founding() shares it by sixths over standing plants + booked + granted plans. Items only (services 0, row 4). | SAME | Services' work is not read (step 4). |
| 12 | MP:292-299 | "it would exist in a planning stage no worker but also no expenses beyond building"; "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... THAT'S BEFORE ACCEPTING A GRANT" | Building.make_plan writes a PLAN row (no company); Company.create only at building.gd:614 when the plant opens; month.gd:158-161 make_plan then Grants.apply (grant after the plan). A plan pays land, the build and its supplies only. | SAME | |
| 13 | MP:304-308 | "the more inventory you have, the more you reduce your price ... a soft lock" | price_rule: down = K_PM × unsold/(unsold+sold), unsold = offered − sold; continuous, no month threshold; at most 5%. | SAME | |
| 14 | MP:310-312 | "they should need 3 months up front and add 1 month of additional supplies every month" | building.gd:43 UP_FRONT_M 3; :388 each month orders up to 3 × month_need − on site; :504 a job starts only with min(3 months, the rest of the bill) on site. | SAME | |
| 15 | MP:314-319, 638-653 | "Import stops when a plant makes it? Not what i fucking meant"; "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR" (only limit is the ship) | ship.gd:167 no rule on what or how often beyond ship in port and hold room (HOLD_START 3000 units a call). But no caller (row 5). | SAME in ship.gd; DIFFERENT in effect (row 5) | Nothing restricts imports, and nothing ever places one. |
| 16 | MP:321-330 | "They can't order when there's not a ship there ... they have the full period of waiting every time" | ship.gd:175 refuses with no ship in port; an order rides "taking" and lands with the same ship's next call. Landing capital and treasury come at month 0 with the landing ship (landing.gd:94, :101). | SAME | |
| 17 | MP:338-343 | "If something else than price stops sales it should not count on adjusting price!!" (freight, road, the buyer's money) | market.gd:214 a NO_MONEY order is not put into unmet_above or refused. But price_rule's down step reads unsold = offered − sold (rules.gd:126), which counts every unit left unsold whatever the cause. Freight: market.gd:87 stock waiting for freight is not offered. | DIFFERENT | Goods left unsold because the buyers had no money still count as unsold stock and lower the price (rule 2) and, through output_rule, the level. Only the order side excludes NO_MONEY. |
| 18 | MP:345-349 | "It sells too cover all monthly expences!!!" | hold_back (rules.gd:155): expenses = wage_bill + this month's inputs + upkeep. | DIFFERENT | Leaves out adverts, layoff pay and debts paid (all booked costs of the month); upkeep is never booked anywhere in the rebuild (grep: no book "upkeep"), so it is 0. |
| 19 | MP:351-359 | "if below making price climbing allways had priority if above lowering has priority ... DO THE SAME FOR BOTH" | price_rule (rules.gd:130-132): both signals → R1 if price < making else R2; K_PM 50 both ways. Also on a builder's BW price (rules.gd:89). | SAME | |
| 20 | MP:361-363 | "the 15000 in storage should never have triggered the damned reduction"; "Ignore the stoch in that other place too" | price_rule and output_rule read sig offered/sold; offered = stock − waiting − hold (market.gd:87). | SAME | |
| 21 | MP:366-372 | "if your selling out and all plants at max build a new one ... money is a limitor" | Rule 5 not built (row 1). | LATER STEP (6) | |
| 22 | MP:368 | "It's simple if you sell out all your producing produce MORE!!!" | output_rule: up = G_PM × unmet/(unmet+sold) when orders above were left unmet; not while holding back. | SAME | |
| 23 | MP:379-391 | "firms in trouble should be able to be bought up ... renegotiate jobs ... sub co tractors" | Not built. | LATER (queued, "Que it as future work") | |
| 24 | MP:396-414 | depot: "count the work que not passed work"; "That works"; "Yes to both" | No transit or freight code in the rebuild economy (old code cut out 2026-11-17). | LATER STEP (4) | Freight is step 4. |
| 25 | MP:439-451 | offices "should not be esencial ... 15% less ... one office building should be able to hold 10 plants"; "Private landlord, and yes" | No office code in sim/economy. | LATER STEP (9) | Step 9 "Offices, pollution, stress, unions, donations". |
| 26 | MP:458-462 | "building fixes behind off switches is not a valid way to do large scale fixes" | No flag or switch read in sim/economy or households.gd (grep "flag|switch" empty). | SAME | |
| 27 | MP:480 | "one object that is the company it's size family to large 4 sizes, the nine rules plugged into that ... a 2d array of wich items a company type makes, if they pick from first or second output" | company.gd one TABLE "company" for every type; type_table.gd ROWS lines (out, qty, in, lab); c["line"] picks the output line. | SAME | Offices, pollution, stress (step 9), freight and services (step 4) not yet in it. |
| 28 | MP:493 | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size the output for each is the same but with a small penalty" | type_table.gd:15 SIXTHS 1/2/4/6; :16 PENALTY_PM 60/40/20/0; output_milli = qty × sixths/6 × (1 − penalty). | SAME | |
| 29 | MP:493 | unions "belong outside ... small fee ... 2/3 normal sallery" during shutdowns | Not built. | LATER STEP (9) | |
| 30 | MP:500, 736 | "skills and swapping jobs to better payed"; "they have a sallery set on hire then it climbs based on yearly upps" | Tiers G/S/Sp (TIER_PM 1000/1500/2250); households.gd:1020 quitting for better pay over quit_bar_pm; company.gd:422 yearly_raise changes pay only; salary_rules moves only the hiring offer. | SAME | |
| 31 | MP:507 (5.) | "Sallery should be calculated as avrage living in the area and food plus half of both again" | Replaced by row 50 (the user, 2026-11-18). type_table.gd:395 salary_line still exists; no caller (grep). | SAME (superseded by row 50) | |
| 32 | MP:516 | "You penalty is fine" (6%, 4%, 2%, none) | PENALTY_PM 60/40/20/0. | SAME | |
| 33 | MP:516 | "every year a company can grant a bonus what the minimum of this is is up to the government, 2% is a good start" | households.gd:1097 min = lever ECON_YEARLY_RAISE_MIN_PCT (default 2) × 10 per mille; company.gd:426 r = max(company's choice, minimum), January. | SAME | |
| 34 | MP:525 (1.) | "On sallery it's an avrage of the area" | Rules.area_rent: plain average of the open landlords' @home asks in the area (else start_price LANDLORD/2); starting_salary = area_rent × 2. | SAME | |
| 35 | MP:525 (4.) | "The district the plant hiring is in" (a salary with plants in two places) | Households.hire (households.gd:186-191) pays the hiring salary of plant_area(cid, plant_key); salary_rules groups by plant_area. But rules.gd:365-366 pass the COMPANY's area to _advertise (the advert's pay) and to Households.hire's needs test (needs_per_worker(area)). | SAME for the pay; one note | The advert is priced, and the needs test read, at the company's area, not the plant's. |
| 36 | MP:525 (5.) | "They have empty work slots" (rules 2 and 4 for types with no stock) | building.gd:669 a builder's signal: offered = crew BW − crews waiting for material, sold = BW done, so unsold = empty slots. | SAME | |
| 37 | MP:525 (6.) | "in a square if there are other companies they would have to buy out ... three small in a square ... build a new" | Not built. | LATER STEP (6) | |
| 38 | MP:525 (7.) | "A hard rule here is fine" (the fact behind rule 6) | Rule 6 not built. | LATER STEP (6) | |
| 39 | MP:534 | "buildings ... ware and tear, repair all that" | No wear or repair code (upkeep never booked, row 18). | LATER STEP (6) | |
| 40 | MP:541, 548-559 | owning a home; homes on the map; upkeep of owned flats | Not built. | LATER STEP (7) | |
| 41 | MP:564 | "Below 250 start a gridd anyway and only use what you need, and set a credit prices" | transport/town_grid.gd: a town gets its grid with its first building; start prices are ours (type_table.gd). | SAME | |
| 42 | MP:571 | "End of a company can happen in three ways ... sales death ... two years" | Not built; EconFace.insolvency_court_liquidation refuses endings before step 5 (justice_ops.gd:982). | LATER STEP (5) | |
| 43 | MP:578 | "5 building companies" | home_builders.gd:33 HOME_WORLD: 5 (1 LARGE, 2 AVERAGE, 2 SMALL), plus PUBLIC_WORKS AVERAGE. | SAME | |
| 44 | MP:578 | "the goverment starts with its subsidiaries as before" | landing.gd: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL, POLICE (no plant, no staff), ADMIN crew, the housing office, Colony Stores. | SAME | |
| 45 | MP:578, 589, 610-612 | "all three grant types open"; "No split trucks and workshops"; "JUST ALL FUCKING GRANTS" | grants.gd KINDS: FARM, BAKERY, TRUCKER, TRUCKSHOP. | SAME for the grants; see row 3 | Only FARM can be founded, so three of the four grants can never be used. |
| 46 | MP:578 | "no sectors beyond landfallpoint that's up to where things are built" | One area at the start (AreaStore.found_landing). | SAME | |
| 47 | MP:578 | "noise polution should also drive down price of housing" | Not built. | LATER STEP (7) | |
| 48 | MP:578 | "they are laied of its loans are payed in full ... the owner is taking to court" | Not built (endings refused before step 5). | LATER STEP (5) | |
| 49 | MP:603 | "But emplyees only apply to jobs that meet their needs" | households.gd:194 a hire whose pay < needs_per_worker(area) gets nobody ("no applicants"), except the placed. | SAME | |
| 50 | MP:959-971 | "just rent at 2×"; "2"; "Merge with 2" | rules.gd:203 STARTING_RENT_PM 2000; starting_salary = area_rent × 2 × TIER_PM. Company.hiring_salary falls back to it. But rules.gd:637 running_cost (rule 7's cost) prices posts at TypeTable.salary (SALARY_G 300 × tier), and landing.gd:196 support_rates (benefit, pension) is TypeTable.salary("G") × rate. | SAME for the hiring offer; DIFFERENT in two places | Rule 7's running cost and the benefit and pension still read the old 300 general salary, not the starting salary (2 × the rent, 194 at the landing). |
| 51 | MP:619-621 | "materials come with the start not finished buildings ... do you place out fucking plants from start????" | landing.gd STOCK FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20; no farm, mine or works placed. But landing.gd:_shelters creates the housing office with LANDLORD plants (8 blocks of 50 homes) standing at month 0. | DIFFERENT, one part | The landing shelters are finished buildings at month 0 (the plan's own 12.2, 11 has them; the user's words say no finished buildings). |
| 52 | MP:619 | "5 years worth of equipment" | landing.gd STOCK: MATERIAL 9700, COMPONENT 1060 (Bob's reading: five years of the five builders' full work). | SAME as a reading (table 2) | |
| 53 | MP:633 | "they should become individually counted on company start" | month.gd:155 Households.make_founder when the PLAN is made (before the building, before the company exists). | DIFFERENT | Counted from the day the plan is made, not from the company's start (the plan's 12.9, 60a, after the outside review). |
| 54 | MP:690 | "water and power before rent what are you paying power and water on if you can't pay the rent?" (food, then rent, then water and power) | households.gd post_orders: food first with all money, then the rent set aside, then the store. No water or power yet. | SAME; water and power LATER STEP (4) | |
| 55 | MP:702, 711 | "Company and people should be able to stock up if the price is low"; "low should be against what its worth to the buyer" | making.gd:206 a company orders AHEAD when the cheapest offer ≤ AHEAD_BELOW_PM 800 × its worth, up to 2 months' need; households: row 66. | SAME | 80% and 2 months are ours (table 2). |
| 56 | MP:725 | "a backend column somhere that records all things happening like a log" | core/logbook.gd; rows written throughout. | SAME | |
| 57 | MP:743 | "underpayed workers go to the union, they can quit if they think they can get better prices if not they may unionise" | Quitting: households.gd:1020. Unions not built. | SAME for quitting; LATER STEP (9) for unions | |
| 58 | MP:752 | "avrage ask salleries in the company and underpayed is based on that line" | households.gd:1075 avg = Company.avg_pay(cid, post_tier): the average of that TIER only. | DIFFERENT | The line is per skill tier, not the average of all salaries in the company. |
| 59 | MP:759 | "the manager, negotiation can bring it closer to avrage" | households.gd:1078 ask = pay + half the gap to the tier average, once a year, if the account covers a year of it; company.gd:734 never above the average. No manager is read. | SAME | The half and the money test are ours (table 2). |
| 60 | MP:768 | "when a grant ends, they reset to zero ... grants should be limited time for when you can apply" | grants.gd PROGRAMME_M 24; _end_programme → LawOps.end_programme sets the lever to 0; gov_builder.gd:557-561 drops the cover and the sum. | SAME | 24 is ours. |
| 61 | MP:779 | "put a max sum into the grant based on how many darms they want maybe a little extra" | grants.gd wanted() (food need over a family farm's output, less standing and planned) and budget_for: that many grants + EXTRA_PM 100. | SAME | 10% is Wilma's. |
| 62 | MP:788 | "they should not cut for the start, and they should not increase prices for claimed jobs" | building.gd:664 seller_signal {} before the first quote; unmet_above = BW of plans that signed LAST month and must wait (work waiting in the book not counted again). | SAME | |
| 63 | MP:797 | "At start id assume they know work is coming" | Same {} signal before the first quote: no price or crew cut. | SAME | |
| 64 | MP:806 | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | founding(): standing + Building.booked + made plans with a grant; made plans without a grant not counted. | SAME | |
| 65 | MP:817 | "He should look for the shortest time" | building.gd:253 quotes sorted by start, then total, then builder. | SAME | |
| 66 | MP:821 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | QUIT_BAR_GOOD_PM 100, QUIT_BAR_PER_YEAR_PM 10, QUIT_BAR_MAX_PM 150; quit_bar_base_pm returns 100 always (stress comes at step 9). | SAME; "less if stressful" LATER STEP (9) | |
| 67 | MP:834-838 | "should have clauses for payment after fire ... weigh say three months of vages"; "it should apply to builders" | WorkLaw.layoff_pay_months = lever LAW_LAYOFF_PAY_MONTHS default 3 (clamped 0..12); Households.layoff owes it, debt LAYOFF_PAY whole (justice_ops.gd:1133); advert (Media ADVERT_PM 100); TRAIN_MONTHS 6, 500→1000; layoff_weighing; builders go through the same staff_to_posts. | SAME | |
| 68 | MP:847 | "ship food should be considered less desierable" | market.gd:30 SHIP_LESS_WANTED_PM 250 in the offers' rank; households.gd food_by PRICE order when the budget is short. | SAME | 25% is ours. |
| 69 | MP:847 (Wilma's question, "Yes") | the family works its own farm without wages | rules.gd:518 family_to_posts; Company.family_set at opening (building.gd:620-623). | SAME | |
| 70 | MP:856 | "The owners of a family farm should take winnings no sallery" | rules.gd:560 winnings / 587 pay_winnings after debts. | SAME | |
| 71 | MP:865 | "the farm would be their home, wich means they are paying on any loans they had to take and uppkeep" | landing.gd:285 no rent for a founder on an open family FARM. Loans: no bank. Upkeep: never booked (row 18). | SAME for rent; LATER STEP (5) loans, (6) upkeep | |
| 72 | MP:874-889 | farms away from towns; the four answers | Not built. | LATER STEP (4) (marked) | |
| 73 | MP:896 | "I think two is better" (a loss carried forward) | rules.gd:570-572 loss_carried paid down before the family takes anything. | SAME | "maybe the family can put some away" noted, not built (a maybe). |
| 74 | MP:905-911 | "they buy 2 units if food instead of one"; "six months of food in storage ... as often as they can"; "The first ... i don't think you wait" | households.gd:498 STORE_MONTHS 6; AHEAD order up to one more month's need a month while below six, every month, whatever the price, within what money is left after food and rent. | SAME | |
| 75 | MP:920 | the government ordering stockpiles | Not built. | LATER STEP (8) (marked) | |
| 76 | MP:929-935 | "fall back to the original rule for settin on hire, then it should only climb max 5% if it cost not hire for one month"; "5% each month ... i never said i wanted the rule for lowering" | salary_rules: OFFER_CLIMB_PM 50 for posts open a whole month; clear_hiring_salary when none stayed open; no lowering rule. | SAME | |
| 77 | MP:944-946 | "a 2d array to keep all things about the hires? Sallery start date so forth?"; "You can merge if all rows match" | company.gd staff hires [{"n","pay","since","train"}]; _tidy merges rows whose pay, since and training now all match. | SAME | |
| 78 | MP:950 | "Record it make them pay after our if they refused take it to court" | households.gd:444 owes UNPAID_WAGES (whole, next month, justice_ops.gd:1133); collected as money allows; petition after PETITION_MONTHS 12, one per company; the court's wind-up refused before step 5. | SAME; the court LATER STEP (5) | 12 months is Bob's reading. |
| 79 | MP:980 | "The build crews at start should not be hiring at all. They should start with a job already active." | home_builders.gd:110 Households.hire(..., placed = true): no needs test, no advert, trained. | SAME | |
| 80 | MP:989 | "Place the goverment staff from startb with the builders and lets set their sallery at 2.5 from start same for builders" | landing.gd:173 _crew placed for ADMIN, the housing office, Colony Stores; Rules.placed_salary = area_rent × PLACED_RENT_PM 2500 × tier. | SAME | |
| 81 | MP:998 | "THEY EATS THEMSELVES FIRST ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24" | households.gd:613 a founder on its own open farm takes need + up to one more need (the store's double) from the farm's stock before any order (Making.family_take); for 3 persons that is 6. | SAME | |
| 82 | MP:998 | "THEY ARE THREE THEY CAN PRODUVE 30" | A FAMILY farm: posts G3 S1 (4), output_milli = 240/6 × 0.94 = 37.6; three of the family on four posts make 28.2 (staffed 750). | DIFFERENT | Three make 28.2, not 30 (the 6% size penalty and four posts for a family farm). |
| 83 | MP:998 | "THAT SHOULD BE ENOUGH TO HIRE ONE PERSON" | Company.hire_wanted at full: ceil(4) − 3 family = 1 stranger. | SAME | |
| 84 | MP:1007 | "On posts when you many an open post you pay the first time not every consecutive month after" | rules.gd:432 _advertise pays only posts not yet paid for; _hire pays nothing; the record is clipped to what stays open. | SAME | |
| 85 | MP:1016 | "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | K_PM 50; step = K_PM × s/(1+s) ≤ 5%, both ways. | SAME | |
| 86 | MP:1022 | "25?! 5!!! CHANGE IT!!!" (output moves at most 5% a month) | G_PM 50; up = G_PM × s/(1+s); down = G_PM × s/(1+s). | SAME | |
| 87 | MP:1031 | "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | output_rule (rules.gd:175): down = step_pm(G_PM, unsold, sold) in ANY month with anything unsold; no count of months. | DIFFERENT | Output falls every month with any unsold goods; not only after 3 months in a row with over half unsold. |
| 88 | MP:1037 | "A CUT IS 5% ... IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | down = 50 × unsold/(unsold+sold) per mille: less than 5% unless nothing sold. | DIFFERENT | The cut is a share of 5%, not the whole 5%. |
| 89 | MP:1046 | "FARMS DON'T SHUT" | rules.gd:346-347 in a month it could not pay all wages (19a) any plant with staff_count 0 is closed "NO_STAFF"; staff_count counts hired staff only (company.gd:463), not the family. Also building.gd:629 closes a plant at opening if the law refuses (LAW). | DIFFERENT | A family farm whose hired staff are all laid off for unpaid wages is shut with its family still on it. (The LAW closure at opening is another context.) |
| 90 | MP:1057 | "Screw lowering food, double the rent" | type_table.gd:30 HOME_RENT_PM 2000 (a new home 193.96); landing.gd SHELTER_RENT 97. | SAME | |
| 91 | MP:1066 | "10 purple each" (10 people per farm worker) | FARM line qty 240, lab G18 S5 Sp1 = 24 posts. | SAME | |

Outside the rebuild economy, not audited: newspapers' looks (MP:416), articles name who (MP:421), untreated illness
signals (MP:430), the process rulings (MP:454-464 the switch-on series, 467-486 cutting the economy and the open
connections, 594 reviews of the whole, 626, 674, 683, 718), the outside reviews (MP:656-668, 695-697: no user rule
beyond "skip ... guaranteeing company survival", which no code does), and the sections before 224 (M0-M9, post-v1).

## Table 2: lines in MASTER-PLAN that are a proposal, a reading or a starting number of ours, and what was built

| paper:line | whose | what it says | what was built from it |
|---|---|---|---|
| MP:241-242 | Wilma's reading | a private clinic, school, power plant or haulier has price rules 1 and 2 | nothing yet (services step 4) |
| MP:262 | Wilma's reading | the same tax-bracket shape for clinics and care | nothing yet |
| MP:299-302 | Wilma | what the old code did wrong (FORMING, stalled after 12 months) | the plan record in building.gd (row 12) |
| MP:404 | Bob's reading | the depot's "work queue" | old code, cut out |
| MP:436 | Wilma | the 2% and 4% of the illness signal | health_signal.gd (outside the rebuild) |
| MP:449 | Wilma | "yes" read as: offices are real buildings builders put up | nothing yet (step 9) |
| MP:621 | Bob's reading (in landing.gd) | "5 years worth of equipment" = five years of the five builders' full work | landing.gd STOCK MATERIAL 9700, COMPONENT 1060; FOOD 12000 (12 months, Wilma's addition); TRUCK 20 |
| MP:628 | Wilma | section 12's 76 decisions; "you're decisions are fine" (MP:825) | throughout |
| MP:772 | ours | the 24 months of a grant programme | grants.gd PROGRAMME_M 24 |
| MP:781 / grants.gd | Wilma's | "a little extra" = a tenth | grants.gd EXTRA_PM 100 |
| MP:836 | Wilma's view, accepted ("you have the right of it") | pay after a layoff (three months, a law), an advert to a paper, six months' training as lower output, layoff pay a debt | WorkLaw lever 3 (range 0-12, ours); Media ADVERT_PM 100 (a tenth of a month's pay, Wilma's number); TRAIN_MONTHS 6, TRAIN_START_PM 500 |
| MP:845 | Wilma's decision | the months of layoff pay follow the law on the day of the layoff | WorkLaw.layoff_pay_months read at each layoff |
| MP:965 | Wilma's reading | "3 5x" = 3.5 × the rent | superseded by "2" |
| MP:991 | Wilma's reading | the 2.5 is 2.5 × the rent, times the tier's share | rules.gd PLACED_RENT_PM 2500 × TIER_PM |
| MP:1009 / rebuild-company 9.2 | Wilma's reading | the advert is paid in the month the post opens, whether or not anyone is hired | rules.gd _advertise |
| MP:1068 | Wilma's reading | "10 purple each" = 10 people each | FARM qty 240 for 24 posts |
| code, row 2 | Otto's review | a rise is at least one post's share of full | rules.gd:190 |
| code, row 18 | Bob's reading | the hold-back's expenses = wage bill + inputs + upkeep | rules.gd:155 |
| code, row 34 | Bob's reading | the area's rent = plain average of the open landlords' asks; with none, half a new house | Rules.area_rent |
| code, row 55 | Bob's proposal (9.3) | a company stocks up when the price ≤ 80% of worth, up to two months | making.gd AHEAD_BELOW_PM 800, 2 × need, KEEPS_PM 50 |
| code, row 59 | ours | a negotiation asks half the gap, if the account covers a year of it | households.gd:1078 |
| code, row 66 | Wilma's reading | "less if stressful": toward 5% at the highest stress (step 9) | QUIT_BAR_STRESSED_PM 50, unused until step 9 |
| code, row 68 | ours | ship goods ranked a quarter dearer; a short budget buys by real price | market.gd SHIP_LESS_WANTED_PM 250; households.gd food_by |
| code, row 78 | Bob's reading | unpaid 12 months after due counts as "refused" | justice_ops.gd PETITION_MONTHS 12 |
| code | ours (START) | builders' capital = 3 months of wages; treasury 2,000,000; ship hold 3,000; home-world price 2 × start; 200 settlers a call | landing.gd BUILDER_CAPITAL_MONTHS 3, TREASURY_START; ship.gd HOLD_START, HOME_PRICE_PM 2000, SETTLERS_PER_CALL |
| code, row 3 | the plan's step 3 ("Tested first on food alone") | only farms are founded | month.gd FOUNDABLE ["FARM"] |

## E. rebuild-building.md (whole), and the builders' lines that carry the user's words

Code read in the shared tree: sim/economy/building.gd, home_builders.gd, month.gd (founding), grants.gd, rules.gd, type_table.gd.

### E1. Lines with the user's words

| # | paper:line | the user's words | what the code does today | SAME / DIFFERENT | what differs |
|---|---|---|---|---|---|
| E1 | building 13; company 235; MASTER 296 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES DAMNED IT ALL THAT'S BEFORE ACCEPTING A GRANT" | Building.make_plan writes a PLAN record (status MADE), no company. Month.gd:163 calls Grants.apply(world, plan) right after make_plan. The company is created only in Building.open_due, the month after the contract is DONE. | SAME | |
| E2 | building 14; company 235; MASTER 293 | "you can't fail before you exist ... no worker but also no expenses beyond building" | A plan has no staff record and no price. It pays only: the land (Site.buy_land at signing), the contract bill (bill_month) and its site's supplies (supply_orders, client's account). give_up writes COMP_PLAN_ABANDONED, never a company ending. | SAME | |
| E3 | building 15; company 578; MASTER 310 | "they should need 3 months up front" | UP_FRONT_M = 3. _ready: a SIGNED job starts only with on_site ≥ min(3 × month_need, rest of bill) for MATERIAL and COMPONENT. | SAME | |
| E4 | building 15; company 578; MASTER 311 | "and add 1 month of additional supplies every month" | supply_orders orders min(3 × month_need − on_site, still), so each month the site is topped back up to 3 months. month_need = bill item × planned_bw / bill BW, where planned_bw = ceil(bill BW / fewest months). | DIFFERENT | It is "top up to 3 months", not "add 1 month every month". The two agree only when the job works its full planned BW. A month that works less (a short crew, a builder whose crew left) adds only what was used, which is less than one month. |
| E5 | building 17; company 577, 655; MASTER 578 | "5 building companies and alot of oppretunity" | HomeBuilders.land: HOME_WORLD = 5 named builders (1 LARGE, 2 AVERAGE, 2 SMALL), plus Colony Public Works (AVERAGE, ORIGIN_PUBLIC) as the government's. | SAME | |
| E6 | building 17 | "materials come with the start not finished buildings" | Landing.land places no farm, mine or factory; the landing stock is offered by the purse; the only companies at landing are the 5 builders and the government's subsidiaries. | SAME | |
| E7 | building 18 | "5 years worth of equipment that never changed they are companies from the world" | Builders are owned OWNER_HOME {"home_world": 1000}. They have no plant and no yard (crew key "crew"). The type table gives BUILDER an upkeep (upkeep_milli), which is counted only in Rules.running_cost. No code pays upkeep: no Company.book(…"upkeep"…) anywhere in sim. | SAME | (Their equipment does not change, and no upkeep is paid.) |
| E8 | building 164; company 868 (15d); MASTER 817 | "He should look for the shortest time" | sign_round sorts quotes by start, then total, then builder id, and takes the first that the plan's account covers (land + total). start_month = month + 2 + (BW ahead in the book) / bw_milli. | SAME | |
| E9 | building 253; company 243 | "It ends only if its owner gives it up (no builder, no money)" | give_up is called for three reasons: "no builder" (Building.builders() empty); "cannot pay the builder" (job STOPPED after 3 months unpaid and the account below what is owed); and "the work is no longer there (rule 7)" (passing_sizes re-read before signing, Otto's 4.4). builders() counts only OPEN, for-hire builders with bw_milli > 0 (trained crew), so a builder company alive with no trained crew counts as "no builder". | DIFFERENT | (a) A third reason, the signal gone before signing, is not in the user's two. (b) "no builder" is read as "no builder with trained crew this month". In the seed-1 trace, builders 2–5 stayed OPEN with 0 crew from month 23 and the plans of months 27, 28, 49, 50 and 59 were all given up "no builder". |
| E10 | company 471–474 (9.2); landing | "The build crews at start should not be hiring at all. They should start with a job already active." | HomeBuilders._make: Households.hire(…, -1, trained=true, placed=true) for each tier's posts. That means no needs test and no advert, trained from the start, and the HIRE row is marked "placed". | SAME | Placed as ruled. In seed 1 the crews placed are 48/32/32/16/16 = 144 of the 180 posts: the pools hold too few S and Sp ("crew short in month one" row). That is the paper's 180, not a user number. |
| E11 | company 474 (9.2) | "lets set their sallery at 2.5 from start same for builders" | Rules.PLACED_RENT_PM = 2500. Households.hire with placed and pay −1 pays Rules.placed_salary(area) = area rent × 2500/1000 × TIER_PM. The public works go through the same _make. | SAME | |
| E12 | company 365 (9.2) | "On the workers rules i belive you have the right of it, and it should apply to builders" | Builders run the same Rules.staff_to_posts (hire, slack, layoff_weighing, 19a), the same training (bw_milli reads Company.trained_count), and owe layoff pay through Households.layoff. | SAME | |
| E16 | company 881 (15e; added to the paper during this audit) | "the farm needs a buffer say 50% until it had 6 months worth built up then 10%" | Rules.winnings: amount = min(earned − loss paid down, balance − keep), keep = one month of wage_bill + inputs + upkeep. Rules.pay_winnings pays that to the family each month. | DIFFERENT | No 50% or 10% share is kept and no 6-month mark exists. The farm keeps back one month of its hired staff's wages, inputs and upkeep (for a family farm with no hired staff that is about 0), and the family takes everything earned above that. |
| E13 | building 99 | homes: apartments 0.85, a tower 1.15 ("the user's figures, 9.8") | not built | LATER STEP (7) | building 355: "homes, landlords' blocks and own houses, at step 7 (9.8)". |
| E14 | building 330 | "homes keep the user's 55 of 9.8" (condition) | not built | LATER STEP (6/7) | 5.3 is "What step 6 adds". |
| E15 | building 318; company 179 | "money is a limitor" (rule 5) | not built | LATER STEP (6) | 5.1 is "What step 6 adds". |

### E2. Lines with no user words behind them (proposals, readings, starting numbers of ours), and what was built

| paper:line | whose | what it says | what was built from it |
|---|---|---|---|
| building 71 | Otto | one BW = one worker-month at full output; a builder makes staff × (1 − size penalty) | HomeBuilders.bw_milli = trained_count × (1000 − penalty_pm)/1000 |
| building 77–93 | Otto/Bob | the build bills and fewest months table | TypeTable rows "bill" (FARM 240/240/12/4, BUILDER 120/120/6/2, …) |
| building 95–97 | Otto | smaller sizes take 1/6, 1/3, 2/3; fewest months = max(2, ceil(full × (1 + share)/2)) | TypeTable.bill per size |
| building 104 | Otto/Bob | builder row: 60 workers (36/18/6) making 60 BW | type_table BUILDER lab G36 S18 Sp6, qty 60 |
| building 106 | Otto | upkeep about 1/400 of MATERIAL a month plus 2% of BW a year as a builder job | TypeTable.upkeep_milli (UPKEEP_MAT_DIV, UPKEEP_BW_PM_Y); read only by Rules.running_cost; never paid, never a builder job |
| building 116–120 | Otto | the five's sizes: 1 large, 2 average, 2 small; 180 crew | HOME_WORLD sizes as said; crews placed by posts (seed 1: 144 placed) |
| building 121–124 | Bob | the public works is idle in step 3, paid until the purse decides (Wilma's reading in rules.gd 83–85) | company_month skips its price/output rules; wages paid from the purse; seed 1: unpaid from m38 (19a), 0 crew by m44 |
| building 125–127 | Otto | the landing stock is posted by the purse as an ordinary offer at the starting prices | landing.gd |
| building 138–143 | Otto | the founder needs land + estimate + 3 months of running costs (OPENING_M = 3) | Building.founder_needs; running_cost priced at TypeTable.salary (shared tree; Bob's t51 moves it to starting_salary) |
| building 146–149 | Otto/Bob | founders in a fixed order by pool id | month.gd founding loop |
| building 156–158 | Otto | estimate = bill BW × average live builders' BW price + materials at market | Building.estimate, bw_price |
| building 162–163 | Otto | start month from the book at the present crew | start_month = month + 2 + ahead / max(1, bw_milli) |
| building 170–173 | Otto | before signing, re-read rule 7; give up if gone | sign_round → give_up "the work is no longer there (rule 7)" (see E9) |
| building 174–175 | Otto | refuse a quote over the account and ask next month | sign_round "waits: its money does not cover the land and any quote" |
| building 177–178 | Otto | the grant is paid at signing | DIFFERENT from built: Grants.apply runs when the plan is made (month.gd:163); the user's words (E1) say "after the plan", which the code meets |
| building 187–189 | Otto | a month's supplies = bill × (planned BW / bill BW); planned BW = bill/fewest months or the crew, whichever less | month_need uses planned_bw = ceil(bill/fewest months) only; the crew part is not built |
| building 190–197 | Otto/Bob | the supplies order is the client's, at its estimate's worth | supply_orders: buyer kind SITE, the client's account, worth = item price at signing |
| building (Wilma, in code) | Wilma | supplies are ordered only for jobs WORKING or next in line | supply_orders + next_in_line |
| building 203–205 | Otto | crews to jobs in signing order; a job that cannot work keeps its place | work_month |
| building 213–219 | Otto | price rules read unmet/refused; output rules are hiring; making price | Building.seller_signal, Rules.output_rule, staff_to_posts |
| building 221–231 | Otto | the client pays BW × (price_bw + wage drift); 3 months unpaid → STOPPED | bill_month (unpaid_m ≥ 3 → STOPPED) |
| building 242–247 | Otto | the plan becomes a company the next month; the account moves | open_due |
| building 255–260 | Otto | a given-up plan: builder keeps what was paid, land stays the founder's, grant owed back | give_up (Grants.reclaim) |
| building 262–263 | Otto | given up only when no builder is alive or the account cannot pay a bill; a long wait is not a reason | see E9: "alive" is built as "has trained crew" |

## T. The builders trace, seed 1, months 12–59 (a copy of Bob's t51; facts only)

This trace was run on Bob's copy t51, not on the shared tree. t51 holds his unmerged pieces: the rule-4 cut after 3 months over half unsold, rule 8, K/G, and running_cost at the starting salary. So the months here are t51's.
Read per builder at each month's end: crew, account, BW, wages due and paid, revenue, the general hiring offer against the needs line, the book, and the log rows (hires, layoffs and their reason, rules).

| months | what happened | rows that show it |
|---|---|---|
| 0 | The five builders are placed with 48/32/32/16/16 crew (144 of 180 posts: too few S and Sp in the pools). Public works (company:6) gets 32. General openings after that find no applicants: the offer is 194 against needs of 195. | "crew short in month one"; "no applicants: the pay is below their needs" |
| 12–16 | Wave one is worked. Every builder is full (60/40/40/20/20) and paid in full, and the accounts grow (company:1 121k at m16). | PAY wages = due |
| 17–19 | The books empty: builders 2–5 at m17, company:1 at m19. Revenue falls to 0. | book [] |
| 17–23 | The crews are kept whole with an empty book. company:1 keeps 60 crew at 18,193 a month for 5 months ("keeps its slack staff: a layoff costs more than their wages while idle"). Its level is cut 5% a month only from the third month over half unsold (1000 → 950 → 903 → 858 → 816 → 776). The accounts drain: company:2 from 71k (m16) to 0 (m22); company:1 from 121k to 0 (m24). | RULE "keeps its slack staff"; LEVEL R4 |
| 22–23 | Builders 2–5 can't pay their wages, and 19a lays off everyone (company:2 34 → 0 at m23). | RULE "19a could not pay its staff"; LAYOFF (UNPAID) |
| 24 | 63 plans are made. company:1 signs 17 of them while it still has 49 crew. That month's payroll: 19a pays 5,063 of 14,793 and leaves 9 crew; at m25 it has 0. Its book holds 18 jobs, quoted to start at month 101 (later 132). | PLAN "signed to wait behind the builder's book" ×17 |
| 24–59 | No builder rebuilds. With account 0, every month logs "fewer hired: it cannot pay all the job adverts" (company:2 m31–32: wanted G19 S10 Sp3, can 0, balance 0). A builder's only income is BW done, so with no crew there is never money. When a few are hired (company:2 10 at m32, 19 at m33), their wages go unpaid the next month and 19a follows again, every month m33–44. | HIRE "fewer hired…"; RULE 19a each month |
| 23–34 | A crewless builder's level stays put (company:2 at 776 from m23 to m34). Rule 4 counts a month only when the builder offered something, and with no crew it offers nothing. So its posts keep asking for 32 people with an empty book. | LEVEL unchanged |
| 0–44 | Public works: paid from the purse with its own account at 0 until m37. Then 19a (m38 paid 9,630 of 13,473; m39 paid 0) and 40 → 0 crew by m44. | PAY; RULE 19a |
| 27–59 | Building.builders() needs bw_milli > 0, so builders 2–5 with 0 crew drop out. Every plan made in m27 (17), m28 (15), m49, m50 and m59 (54–59 each) is given up "no builder". The few signed in m24, m51 and m56 go behind company:1's frozen book (start 101, then 132). | PLAN "given up" (why "no builder") |

What these rows touch in the audit tables: E9 (when a plan is given up, and builders() reads "has trained crew"); the rule-4 rows (a cut needs offered goods); the layoff-weighing rows (9.2 keeping workers); the advert rows; 19a; and the public works line (building 121–124, Bob's and Wilma's readings, not the user's).

