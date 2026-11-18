# Audit: the user's rules against the code (Maja, 2026-11-18)

Wilma's order, after the user's "STOP JUST STOP GO BACK AND LOOK AT THE FUCKING RULES". No fixes and no proposals here: only what the user said, what the code in the shared tree does today, and whether they are the same.

Code read: the shared tree at commit 0c9e266 (households.gd 247d57b7, demography.gd 632f62ac), plus rules.gd, company.gd, market.gd, making.gd, landing.gd, grants.gd and law_data.gd as they stand there.

Legend: **SAME** means the code does what the user's words say. **DIFFERENT** means it does not, including "not built yet".

## Part A. Households, food, the store, needs, jobs, raises, training, founders and families

### A1. Rule lines with the user's words

| # | Paper:line | The user's words (verbatim, short) | What the code does today | SAME / DIFFERENT | What differs |
|---|---|---|---|---|---|
| A1 | company 277-278, 9.1 | "we take how it works and transfer over not take the code" | households.gd and demography.gd are written new; the old files are not used | SAME | |
| A2 | company 302 | "Oh no wholesale does not mean unchecked" | rebuild-households.md section 3 checks every old mechanism | SAME | |
| A3 | company 314 | "what are you paying power and water on if you can't pay the rent?" (order: food, rent, then water and power) | households.gd post_orders: food first with all the money; pay_rent from what is left. Water and power are not in the game | DIFFERENT | Food then rent: same. Water and power: not built (no grid in step 3) |
| A4 | company 332 | "Housholds follow terras latest plan" | homes() reads AreaStore.capacity (Terra's grid cells) | SAME | |
| A5 | company 337 | "Workers and sallery, skills and swapping jobs to better payed" | households.gd labour_month: an employed worker moves to an open post paying more, over the bar | SAME | |
| A6 | company 342 | "they have a sallery set on hire then it climbs based on yearly upps set by goverment" | hire() sets the row's pay; Company.yearly_raise each January (yearly_raise_month); nothing else lowers a row's pay | SAME | |
| A7 | company 352 | "10% if it's a good job" | QUIT_BAR_GOOD_PM = 100 (households.gd:993) | SAME | |
| A8 | company 352 | "less if stressfull" | quit_bar_base_pm returns 100 always (households.gd:1001); QUIT_BAR_STRESSED_PM = 50 is never read | DIFFERENT | Not built: no job counts as stressful (stress is step 9) |
| A9 | company 352 | "plus 1% per year in the same workplace" | QUIT_BAR_PER_YEAR_PM = 10 × full years since the hire row's own month (years_at) | SAME | |
| A10 | company 352 | "up to 15%" | QUIT_BAR_MAX_PM = 150 caps the whole bar (Wilma's reading) | SAME | Built on Wilma's reading of what the 15% caps |
| A11 | company 362 | "underpayed workers go to the union, they can quit ... if not they may unionise" | Quitting: built. Unions: not in the game | DIFFERENT | The union part is not built (step 9) |
| A12 | company 369 | "avrage ask salleries in the company and underpayed is based on that line" | Company.avg_pay(cid, post_tier) averages only rows of the same post tier (company.gd:708); _negotiate compares with it | DIFFERENT | The user said the company's average; the code takes the average per tier (built from the proposal at line 423) |
| A13 | company 373-374 | "contracts should have clauses for payment after fire ... three months of vages" ("you have the right of it") | layoff(): WorkLaw.layoff_pay_months, LAW_LAYOFF_PAY_MONTHS default 3 (law_data.gd:497) | SAME | |
| A14 | company 373 | "costs of hiring, articles in the newspaper" | rules.gd _advertise pays Media.job_advert to a paper | SAME | |
| A15 | company 373 | "maybe 6 months training" (the user accepted training in place of "can't fire") | company.gd TRAIN_MONTHS = 6, TRAIN_START_PM = 500 (half output in month 0, rising to full) | SAME | 500 is Wilma's starting number |
| A16 | company 374 | "it should apply to builders" | The layoff, layoff pay and training code makes no exception for builders | SAME | |
| A17 | company 407 | "you pay the first time not every consecutive month after" | rules.gd _advertise pays only for posts opened and not yet paid for (commit 0c9e266) | SAME | |
| A18 | company 415 | "the manager, negotiation can bring it closer to avrage" | _negotiate each July: ask = pay + (average − pay)/2 if the account holds a year of it | SAME | The manager's skill (12.11, 77) is not read: halfway every time |
| A19 | company 439-441 | "fall back to the original rule ... climb max 5% if it cost not hire for one month"; "5% each month"; "i never said i wanted the rule for lowering" | rules.gd OFFER_CLIMB_PM = 50; an opening starts at starting_salary; no lowering rule | SAME | |
| A20 | company 452-453 | "a 2d array to keep all things about the hires"; "You can merge if all rows match" | company.gd staff entries hold "hires" rows {n, pay, since, train}; _tidy merges only identical keys | SAME | |
| A21 | company 458 | "Record it make them pay after our if they refused take it to court" | households.gd pay_wages: owe(..., "UNPAID_WAGES"); collect_debts pays it later | DIFFERENT | Recorded and paid later: same. "take it to court": no court yet (step 5); the debt stays OPEN |
| A22 | company 464, 472 | "just rent at 2×"; "2", "Merge with 2" | rules.gd STARTING_RENT_PM = 2000 × area_rent (average landlord rent) | SAME | |
| A23 | company 478 | "The build crews at start should not be hiring at all. They should start with a job already active." | home_builders.gd hires with placed = true: no needs test, trained | SAME | |
| A24 | company 483 | "Place the goverment staff ... sallery at 2.5 from start same for builders" | landing.gd places the government's staff; hire(placed) pays Rules.placed_salary = 2.5 × area rent | SAME | 2.5 × rent is Wilma's reading |
| A25 | company 492 | "Screw lowering food, double the rent" | type_table.gd HOME_RENT_PM = 2000 | SAME | |
| A26 | company 497 | "10 purple each" (ten fed per farm worker) | type_table FARM qty 240 for 24 posts | SAME | |
| A27 | company 504 | "every year a company can grant a bonus ... 2% is a good start" | ECON_YEARLY_RAISE_MIN_PCT default 2; Company.yearly_raise(max(choice, min)) | SAME | |
| A28 | company 506 | "emplyees only apply to jobs that meet their needs" | hire() and applicants(): pay < needs_per_worker means nobody applies | SAME | Placed crews skip it (A23, by the later ruling) |
| A29 | company 519 | "Company and people should be able to stock up if the price is low" | Households: the six-month store (A33) buys at any price; nothing buys more because a price is low | DIFFERENT | Stocking up when the price is low is not built for households |
| A30 | company 523 | "what's low should be against what its worth to the buyer, like when they buy normaly" | Nothing compares a price with the household's worth to decide buying ahead | DIFFERENT | Not built (see A29) |
| A31 | company 923 | "they buy 2 units if food instead of one, store it and use it in emergencies" | post_orders: NEED is the month's need, AHEAD is at most one more month (mini(need, ...)); after_market eats the store only when the month's food falls short | SAME | |
| A32 | company 924 | "They stockplie to have have six months of food in storage, i think as often as they can" | STORE_MONTHS = 6; the store order goes every month that money is left | SAME | |
| A33 | company 926 | "if your running low ... i don't think you wait" | The store order buys at any price the money left can pay | SAME | |
| A34 | company 933 | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | want = mini(need, maxi(0, 6 × need − held)) | SAME | |
| A35 | company 872 | "Yes, i agree" (the family works its own family farm, without wages) | family_to_posts / family_work: the family's adults fill the posts, on no payroll | SAME | |
| A36 | company 872 | "ship food should be considered less desierable" | market.gd SHIP_LESS_WANTED_PM = 250: ship goods ranked a quarter dearer | SAME | The quarter is Wilma's starting number |
| A37 | company 881 | "FARMS DON'T SHUT" | rules.gd staff_to_posts (19a): when a company cannot pay its wages it lays its staff off, and any plant left with Company.staff_count(...) == 0 is closed (Company.close_plant, "NO_STAFF"). staff_count counts the payroll only, not the family on the farm's posts | DIFFERENT | A family farm whose hired hands it could not pay is laid off to zero hired staff and shut, with the family still on it. Any other farm with no staff left is shut too |
| A38 | company 885 | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST" | post_orders calls Making.family_take before any order; not offered | SAME | |
| A39 | company 885 | "THEY ARE THREE" | make_founder(family) takes the founder + one adult per extra adult of an average household + its children: seed 1 at month 42 showed 33 of 80 families of three (2 adults + 1 child), 39 of two adults, the rest one | DIFFERENT | Most families are two; no family has three working adults |
| A40 | company 885 | "THEY CAN PRODUVE 30" | A FAMILY farm makes 240 × 1/6 × (1 − 0.06) = 37.6 a month at full staff (4 posts) and yield 1.0. The family alone works 2 of 4 posts: 18.8 × the season's yield, about 35 at midsummer, 19 in spring and autumn, 3.6 at midwinter | DIFFERENT | Not 30: 18.8 on average with the family alone |
| A41 | company 885 | "THEY WOULD TAKE SIX OUT OF THIRTY" | family_take want = need + the store's double: 6 for three persons with an empty store | SAME | |
| A42 | company 885 | "SELL 24" | The rest stays in the farm's stock and is offered | SAME | As offered; whether it sells is the market's |
| A43 | company 885 | "THAT SHOULD BE ENOUGH TO HIRE ONE PERSON" | Nothing checks it; hired posts beyond the family are filled when the output level wants them and the offer meets needs | DIFFERENT | Not shown anywhere; at the outputs in A40 it is not checked whether the sales pay a hire |
| A44 | company 893 | "the farm would be their home ... paying on any loans ... and uppkeep" | Landing.rent_due returns nothing for a family on its own open farm. winnings() subtracts books "upkeep", but nothing in the code ever books upkeep (grep: no book(..., "upkeep")) | DIFFERENT | No rent: same. Upkeep is never charged, so the family pays none |
| A45 | company 899 | "I think two is better" (a loss is carried forward) | rules.gd winnings: carried loss paid down first | SAME | |
| A46 | company 899 | "maybe the family can put some away for the hard months" | The paper notes it for step 4, not built | DIFFERENT | Not built (said as a maybe) |
| A47 | company 912 | "The owners of a family farm should take winnings no sallery, wich comes after" | rules.gd pay_winnings in JUSTICE, after debts, reading the month just lived (commit 995d708) | SAME | |
| A48 | company 1008 | "individually counted on company start ... don't malt to many people to track" | make_founder: one founder record per plan, from the day the plan is made | SAME | "start" read as the plan's day (Wilma's 60a) |
| A49 | company 975-978 | "if they want to but can't buy, bread goes too high — the company can win by lowering" | Market: an order with money below the price is a PRICE refusal and counts for the cut; no money at all is NO_MONEY | SAME | |

### A2. Lines with no user words behind them: proposals, readings and starting numbers, and what was built from them

| Paper:line | The proposal or reading | What was built |
|---|---|---|
| company 355-358 | Wilma's: "up to 15%" caps the whole bar; stress lowers the 10% toward 5% | QUIT_BAR_MAX_PM 150; QUIT_BAR_STRESSED_PM 50, never read |
| company 386-389 | Wilma's starting numbers: 3 months; advert a tenth of a month's pay per person hired; output half in month 0, full after 6 | Layoff months 3; TRAIN_START_PM 500; the advert is now per post opened (A17) |
| company 390-414 | Bob's proposal: training groups, idle run, the layoff weighing; hiring none when the adverts can't all be paid | Built; the "hires none" line is superseded by Otto's per-post adverts |
| company 418-422 | Proposal: negotiation once a year, before quitting; how far it closes depends on the manager | July (NEGOTIATE_MONTH 7); halfway; no manager skill; quitting runs every month whatever the negotiation did |
| company 423-424 | Proposal: the average is per kind of post | Built as avg_pay per tier (see A12, DIFFERENT) |
| company 426-430 | Proposal: the salary's rule-1/2 signal lines | Superseded by the hiring-offer ruling (A19) |
| company 509-510 | Proposal: "their needs" is housing and food where they live | Rules.needs_line = the cheapest landlord rent in the area + food price × 2.5 persons |
| company 511-512 | Proposal: only pay moves a salary | Not read anywhere separately |
| company 527 | Proposal: how much to stock up | The store's six months and its double (15f) |
| company 529-534 | Wilma's decision: a stock-up order's shortfall is no signal | Market.AHEAD orders: no unmet demand, no rule-7 work |
| company 908-910 | Wilma's: the family fills its farm's posts first; the rest are hired | family_to_posts first, then staff_to_posts hires |
| company 917-918 | Starting number: ship food a quarter dearer | SHIP_LESS_WANTED_PM 250 |
| company 938-941 | Wilma's: this month's food, then rent, then the store; stored food spoils | post_orders store_budget = money − food − rent; FOOD spoil_pm 10 (1% a month) |
| company 1017-1021 (37) | Plan: the starting salary carries a household (1.5 ×) | Superseded by the user's 2 × rent (A22) |
| company 1026-1027 (38) | Plan: a worker's needs are two-thirds of the starting salary | Needs = rent + food (needs_line); no longer two-thirds of a salary that is now 2 × rent |
| company 1028-1030 (39, 40) | Plan: a worker moves when a job within reach pays more after travel | labour_month compares only posts in the worker's own area, with no travel time or fare |
| company 1031-1032 (41) | Plan: benefit and pensions are a share of the area's starting salary | landing.gd support_rates = TypeTable.salary("G") × rate (the type table's fixed salary, not the area's starting salary); levers 40% and 35% |
| company 1055-1063 (60a-60c) | Plan points (no user quote except 35's) | make_founder, release_founder, carry_debts |
| households 99-104 | Otto's / Maja's: who founds; an employed founder keeps the post until signing; eats with the pool until then (Maja's reading of 60c, Wilma's yes) | make_founder, take_up_posts, lives_apart |
| households 105, 189 | Maja's: a founder takes one household's share of the pool's savings | household_share = balance × 2.5 ÷ persons |
| households 179-191 | Maja's: the founder draw, adult order, opening money in what a founder must pay | pick_founder, _free_adult, Building.founder_needs (3 months' running cost) |
| households 188 | "A founder's household is themselves ... their family stays in the pool" | Out of date: a FAMILY-size founder takes its whole household (15e) |
| households 152 | "averaged by head count when people join an entry" | Out of date: each hire row keeps its own month (A20) |
| households 209-210 | Maja's: negotiation in July, halfway, if a year of the rise is in the account | NEGOTIATE_MONTH 7; halfway; cost_year test |
| households 212-213 | Maja's: who leaves on a ship; attractiveness 40/40/20 | LEAVE_PM 100; attractiveness weights |
| households 214-221 | Maja's numbers of life: deaths, births 4.0 and −40%, 90% at 18, 1% re-entry, band average 1/6 and margin 10%, famine 25% for 3 months, press notice 5% | demography.gd constants as listed; FAMINE_PM 250, FAMINE_MONTHS 3, FOOD_FACT_PM 50 |
| households 84-90 | Starting numbers, accepted by Wilma: 1,000 settlers, households of 2.5, band make-up, savings by band | households.gd BAND_*, BAND_SKILLS, SAVINGS_PER_HOUSEHOLD, HOUSEHOLD_SIZE 2.5 |
| type table | One person's food a month = 1 unit | NEED_PER_PERSON FOOD 1000 |

### A3. Plan points from the old game (12.11) on this side: not built

85 training on the job; 86 sickness; 87 public work for the jobless; 88 food assistance, a floor and a time limit on the benefit, a tax allowance. None is in the code. They carry no verbatim words of the user in the paper.

## Part B. The rest of the plan (other sessions' areas)

Read by three read-only helpers, one slice each. I checked every DIFFERENT row below in the code myself at commit dc0f9bd; the code files have not changed since 0c9e266. Where a helper said SAME and I disagree, my reading stands and is marked.

### B1. rebuild-company.md sections 1–8 and 12.3 (the rules)

| # | Paper:line | The user's words (short) | What the code does today | SAME / DIFFERENT | What differs |
|---|---|---|---|---|---|
| B1 | company 23 | "one object that is the company it's size family to large 4 sizes" | company.gd create(): one record; type_table SIZES FAMILY/SMALL/AVERAGE/LARGE | SAME | |
| B2 | company 23 | "the offices as a bonus building ... roads and supply networks ... polution plugg ins ... stress for workers reduced output" | The company record has office, fleet, emissions and noise fields, all empty. making.gd output = full × level × staffed × condition × yield | DIFFERENT | No office, freight, pollution or stress term (later steps) |
| B3 | company 23 | "services have no output but a client take in" | type_table has client lines. rules.gd runs only on items and builders' BW; making.gd skips non-items | DIFFERENT | Not built (step 4) |
| B4 | company 27 | "building fixes behind off switches is not a valid way" | No on/off flags in economy/. But politics/health_signal.gd (the pandemic signal) is opt-in: world.meta["on"] must hold "HEALTH_SIGNAL" | DIFFERENT | The pandemic news signal is behind an off switch |
| B5 | company 34 | "set a credit prices ... adjust it anyway" | type_table start_prices() solved from SALARY_G 300 | SAME | |
| B6 | company 40 | "it does not really matter if he does not close" | Nothing props up a losing company | SAME | |
| B7 | company 83 | "No i said each COMPANY" (one price per company) | company.gd price per company per item | SAME | |
| B8 | company 101 | "a 2d array of wich items a company type makes, if they pick from first or second output" | The table has the lines; company["line"] is set to 0 at creation and never written again | DIFFERENT | The pick between first and second output is not built |
| B9 | company 117 | "things can be done in two different ways based in company types" | type_table "way" column | SAME | |
| B10 | company 123 | "They have empty work slots" (rules 2 and 4 for types with no stock) | Builders only: building.gd seller_signal (offered = crews − waiting for material) | DIFFERENT | Built for builders only; services, landlords and hauliers are not |
| B11 | company 133 | "per pupil plus staff is how taxes for schools are calibrated" | No bracket pricing | DIFFERENT | Not built |
| B12 | company 135 | "noise polution should also drive down price of housing" | Rows carry noise 0–5; no rent reads it | DIFFERENT | Not built |
| B13 | company 143 | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size ... small penalty" | SIXTHS 1/2/4/6; PENALTY_PM 60/40/20/0 | SAME | |
| B14 | company 152 | "You penalty is fine" | PENALTY_PM 60/40/20/0 | SAME | |
| B15 | company 154-159 | "This sounds good" (a square holds one full size per type) | site.gd keeps ≤ 6 sixths per type per square | SAME | |
| B16 | company 161, 179 | "Depends on region ... buy out ... or ... build a new"; "money is a limitor" (rule 5) | Nothing grows a company: no size-up, buy-out or second plant | DIFFERENT | Not built (step 6) |
| B17 | company 175 | rule 1: raise the price when sold out with orders unfilled | rules.gd price_rule: up = step_pm(K_PM, unmet, sold) | SAME | |
| B18 | company 176 | "the more inventory you have, the more you reduce your price" | down = step_pm(K_PM, unsold, sold) | SAME | |
| B19 | company 177 | "if you sell out all your producing produce MORE" | output_rule up = step_pm(G_PM, unmet, sold) | SAME | |
| B20 | company 177 | rule 3 "Also picks first or second output" | Not built (B8) | DIFFERENT | Not built |
| B21 | company 178, 202 | "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | rules.gd output_rule: down = step_pm(G_PM, unsold, sold) in every month anything is unsold; no 50% test, no month count | DIFFERENT | Output is cut every month anything is left unsold |
| B22 | company 209 | "A CUT IS 5% ... AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | The cut is 5% × unsold ÷ (unsold + sold) of the level | DIFFERENT | Not a flat 5%; no fourth-month repeat (no count of months) |
| B23 | company 180, 957 | rule 6: "A hard rule here is fine" (twelve months idle) | No idle closing anywhere | DIFFERENT | Not built |
| B24 | company 181 | "instead of reading the leftovers, they read an avrage of all avaliable jobs" (rule 7) | rules.gd work(): average of the months in Market.history (up to 12) × today's cheapest offer | SAME | |
| B25 | company 181 | "No cap on how many may form" | month.gd while _found_one() | SAME | |
| B26 | company 182 | rule 8: "the same signal says the work is covered" | rules.gd founding(): the share test only; no test that the plants seen deliver the work (grep "covered": none) | DIFFERENT | Rule 8 is not built in the shared tree (Bob's t46/t51 copies have it) |
| B27 | company 183 | rule 9: "if below making price climbing allways had priority if above lowering has priority" | price_rule: both signals, raise if price < making, else cut | SAME | |
| B28 | company 196, 809 | "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"; "TWENTY PERCENT ... 5% CAP" | K_PM = 50, both ways | SAME | |
| B29 | company 199, 816 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" | G_PM = 50 | SAME | A rise is computed on max(level, one post's share), so a low level can rise more than 5% of itself |
| B30 | company 187 | "If something else than price stops sales it should not count on adjusting price!!" | Offers leave out stock waiting for freight and held back; NO_MONEY goes to no seller | SAME | |
| B31 | company 190 | "Ignore the stoch in that other place too" | market offers: qty − waiting − hold | SAME | |
| B32 | company 191, 798 | "It sells too cover all monthly expences" | rules.gd hold_back: expenses = wage bill + inputs + books "upkeep" (never booked, so 0) | DIFFERENT | Upkeep is always 0; loan repayments, rent and interest are not counted |
| B33 | company 222 | "something like 15% less ... one office building should be able to hold 10 plants" | OFFICEBLOCK has 10 places; no output loss without an office | DIFFERENT | The 15% is not built |
| B34 | company 223-225 | "the same company can become freight"; "count the work que not passed work"; truck "fix it yourself in about 4 months"; "about 5% are lost" | Not built (fleet empty) | DIFFERENT | Not built |
| B35 | company 228 | "stress for workers reduced output based on workers" | No stress term | DIFFERENT | Not built |
| B36 | company 235-236 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES"; "you can't fail before you exist" | month.gd make_plan then Grants.apply; the company is created at opening; a plan has no staff | SAME | |
| B37 | company 251, 262 | the three endings ("two years" of sales death; shut and can't replace; bought out); loans, court, settlement after an ending | No code ends a company | DIFFERENT | Not built |
| B38 | company 864 | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | founding(): standing + SIGNED plans + MADE plans with a grant | SAME | |
| B39 | company 869 | "He should look for the shortest time" | building.gd sign_round: quotes sorted by start, then price; takes the first one its money covers | DIFFERENT (partly) | When it cannot pay the soonest quote it signs a later one it can pay instead of the soonest |
| B40 | company 881 | "FARMS DON'T SHUT" | see A37 | DIFFERENT | (counted once, in A37) |
| B41 | MASTER-PLAN, 2026-11-18 (commit dc0f9bd), rebuild-company 15e | "the farm needs a buffer say 50% until it had 6 months worth built up then 10%" | rules.gd winnings(): keep = one month of the hired wage bill + inputs + upkeep; everything earned above it is paid out | DIFFERENT | No 50% / six months / 10% buffer |
| B42 | company 948, 955 | "No they should not cut for the start, and they should not increase prices for claimed jobs"; "At start id assume they know work is coming" | building.gd seller_signal empty until the first quote; signed-to-wait counted once | SAME | |
| B43 | company 977 | "if they want to but can't buy, bread goes too high" | see A49 | SAME | |

### B2. rebuild-building.md and the MASTER-PLAN rulings (not repeated above)

| # | Paper:line | The user's words (short) | What the code does today | SAME / DIFFERENT | What differs |
|---|---|---|---|---|---|
| B44 | building 15-16, company 578 | "3 months up front and add 1 month of additional supplies every month" | building.gd UP_FRONT_M 3; the site is topped up to 3 months | SAME | Orders go out when the job is next in line (Wilma's) |
| B45 | building 17, MP 578 | "5 building companies and alot of oppretunity" | home_builders.gd: 5 builders (1 large, 2 average, 2 small) | SAME | |
| B46 | building 17-18, MP 619 | "materials come with the start not finished buildings 5 years worth of equipment" | landing.gd STOCK FOOD 12000, MATERIAL 9700, COMPONENT 1060, TRUCK 20; no plants but the shelters | SAME | "Five years" read as five years of the builders' full work (Bob's) |
| B47 | building 99 | apartments 0.85 of the block, tower 1.15 | Not in the code | DIFFERENT | Not built (step 7) |
| B48 | building 330 | homes keep the user's 55 | Not read anywhere | DIFFERENT | Not built (step 7) |
| B49 | MP 434 | "This needs signals, pandemic in the newpaper" | health_signal.gd at 2% / 4%, opt-in only | DIFFERENT | Behind an off switch (B4) |
| B50 | MP 493 | strike pay "2/3 normal sallery" | No strike pay in the rebuilt economy | DIFFERENT | Not built |
| B51 | MP 525 | "On sallery it's an avrage of the area"; "The district the plant hiring is in" | area_rent = average of the area's landlords; hiring_salary at the plant's area | SAME | |
| B52 | MP 534 | buildings: "ware and tear, repair all that" | condition held at 100; upkeep never charged; no repair contract | DIFFERENT | Not built |
| B53 | MP 541, 557 | buy out your house; own larger house; flat owners pay upkeep | Not built | DIFFERENT | Not built (step 7) |
| B54 | MP 564 | "Below 250 start a gridd anyway"; "set a credit prices" | Grid laid with the first building; land = bill × 10% × value | SAME | |
| B55 | MP 578 | "the goverment starts with its subsidiaries as before" | landing.gd subsidiaries (unbuilt plants), admin, housing office, Colony Stores, public works | SAME | |
| B56 | MP 578, 587, 610 | "No split trucks and workshops"; "JUST ALL FUCKING GRANTS" | grants.gd: four programmes, all four levers at 50%. month.gd FOUNDABLE = ["FARM"] | DIFFERENT (in effect) | Only farms can be founded, so the bakery, truck-driver and workshop grants can never be paid |
| B57 | MP 578 | loans paid on selling stock; the owner to court; the bank settles | No bank in step 3 | DIFFERENT | Not built (step 5) |
| B58 | MP 642, 651 | imports: the only limit is the ship | ship.gd: order only with a ship in port, back on its next call | SAME | Only companies order |
| B59 | MP 702, 711 | "stock up if the price is low"; low "against what its worth to the buyer" (companies) | making.gd: AHEAD order when the cheapest offer ≤ 0.8 × the input's worth, up to 2 months held | SAME | 0.8 and 2 months are Bob's numbers. Households: see A29-A30 |
| B60 | MP 768-779 | "grants should be limited time ... reset to zero"; "max sum ... how many darms they want maybe a little extra" | PROGRAMME_M 24; lever back to 0; sum = wanted × grant + 10% | SAME | 24 and 10% are ours |
| B61 | MP 980, 989 | placed build crews and government staff at 2.5 | see A23-A24 | SAME | |
| B62 | MP 1057, 1066 | "double the rent"; "10 purple each" | see A25-A26 | SAME | |
| B63 | MP 723-727 | "a backend column ... records all things happening like a log" | core/logbook.gd; Logbook.note everywhere | SAME | |
| B64 | MP 752 | "avrage ask salleries in the company" | see A12 (the helper read per-tier as SAME; I read the user's "in the company" as the whole company) | DIFFERENT | (counted once, in A12) |

### B3. Proposals and readings in these slices, and what was built from them (where the build differs from the paper's own text)

| Paper:line | The proposal or reading | What was built |
|---|---|---|
| company 794 (14) | making price includes rent, freight, interest, upkeep | making_price called with other = 0; upkeep never booked |
| company 829 (15a, Bob's) | rule 7 work: the year's months, first-year months counted at the grant's need | ÷ the months that exist; no first-year fill |
| company 840 (15a, Bob's) | plants seen deliver made − family take; rule 8 coverage | Not built (B26) |
| company 854 (15a) | running cost at the area's starting salary (2 × rent) | rules.gd running_cost uses TypeTable.salary (SALARY_G 300 per G post), not the starting salary; the opening money is 3 × that |
| company 860 (15a) | the founder's management and risk bend the reading | Not read |
| company 990 (29) | upkeep is part of the making price | Upkeep never booked: 0 |
| building 107 (proposal) | upkeep 1/400 of MATERIAL a month + 2% BW a year | In the start prices and running cost only; never charged |
| building 177-181 | grant paid at signing | Paid at plan making (month.gd _found_one) |
| building 212-216 | a builder's price cut reads quotes refused for price | refused is logged but rules.gd reads only unsold and unmet: refused-for-price quotes do not lower a builder's price |
| building 239-247 | the building is booked as an asset at cost | Not booked (only in the log row) |
| building 255-260 | an ABANDONED half-building can be taken over | Not built |
| building 150-151 | site = best free place in the plan's area | Site.choose_country takes no area |
| company 963 (19a) | a plant with no staff is shut | Built for every plant, farms included, family not counted (A37) |

### B4. rebuild-company.md 9.3–12.12 and rebuild-law-face.md

Rows already counted above (stocking up, grants, the ship rule, the builders, the landing, salaries, layoff pay, unpaid wages, the court for an ending, buying homes, strike pay) are not repeated.

| # | Paper:line | The user's words (short) | What the code does today | SAME / DIFFERENT | What differs |
|---|---|---|---|---|---|
| B65 | company 545-546 | "All company types needs to be able to be created as private" | month.gd FOUNDABLE = ["FARM"]: founding runs for farms only | DIFFERENT | No other type can be founded privately |
| B66 | company 553, 629 | "the goverment can lean on companies if they don't comply or on the union" | No code | DIFFERENT | Not built |
| B67 | company 560-561, 569 | "They can't order when there's not a ship there ... the full period of waiting every time" | ship.gd order(): refused with no ship in port; delivered on that ship's next call | SAME | The rule holds, but nothing in sim/ ever calls Ship.order (grep): no company or government places an import |
| B68 | company 591-599 | Terra's grid "This sounds good"; "Below 250 start a gridd anyway"; "the closer to the coast ... more expensive" | town_grid.gd cells, blocks, value parts (view, water) | SAME | |
| B69 | company 613 | "that's what changed rent levels for the landlord" (wear of homes) | No wear on homes; the shelter rent is fixed (landing.gd SHELTER_RENT 97) | DIFFERENT | Not built |
| B70 | company 621 | "That's fine" (the top band moves out a few at a time into a house of its own) | No code | DIFFERENT | Not built |
| B71 | company 629 | the union: starts at one company, others join, a small fee, protests and shutdowns as long as the fund pays | econ_face.gd unions_active returns [] (a stub) | DIFFERENT | Not built (the 2/3 strike pay is B50) |
| B72 | company 655-666 | "all three grant types open"; "no sectors beyond landfallpoint"; "materials come with the start not finished buildings"; "they are companies from the world"; "the old system and the new for five years are not the same" | landing.gd and home_builders.gd as in B45-B46, B55; one area, the Landing | SAME | |
| B73 | company 1164 | "I think most of these needs to be worked in" (12.11, points 77–109) | 77: the chief's management and risk are stored (company.gd) but read by nothing; 108: the reference wage is published. The rest (78–107, 109) are not built | DIFFERENT | Almost all of 77–109 not built |
| B74 | law-face 234, 239-240 | the yearly raise "set by goverment"; "it should apply to builders" | see A6, A13, A16 | SAME | |

Two findings with no user words behind them, read in the code:

- **No import is ever ordered.** Ship.order is never called anywhere in sim/, so no company and not the government ever orders from the home world (plan 9.6 says both can).
- **No company can end.** EconFace.insolvency_court_liquidation always returns false; petitions are filed and kept but never answered (law-face 154-185; the court is step 5).

## Count

**47 DIFFERENT** among the lines with the user's words:

- **Part A (13):** A3 water and power; A8 "less if stressfull"; A11 unions; A12 the company's average; A21 the court for unpaid wages; A29 and A30 households stocking up when the price is low; A37 "FARMS DON'T SHUT"; A39 "THEY ARE THREE"; A40 "THEY CAN PRODUVE 30"; A43 "ENOUGH TO HIRE ONE PERSON"; A44 upkeep of the family's farm; A46 "put some away".
- **Part B1 (20):** B2 offices, freight, pollution, stress in the company; B3 services; B4 the pandemic signal behind a switch; B8 and B20 the second output; B10 empty slots except builders; B11 school brackets; B12 noise and rent; B16 rule 5; B21 rule 4's "over 50% ... 3 months in a row"; B22 "A CUT IS 5%" and the fourth month; B23 rule 6; B26 rule 8; B32 the hold-back's expenses; B33 the office's 15%; B34 freight and trucks; B35 stress; B37 the three endings; B39 the shortest time; B41 the farm's buffer.
- **Part B2 (8):** B47 apartment and tower bills; B48 the homes' 55; B49 the pandemic switch; B50 strike pay; B52 wear and repair; B53 owning homes; B56 only farm grants can ever be paid; B57 the bank.
- **Part B4 (6):** B65 only farms can be founded; B66 leaning on companies; B69 wear and rent; B70 the top band's own houses; B71 the union; B73 points 77–109.

Of the 47, these are built differently from the words (the rest are not built yet): A12, A37, A39, A40, A43, A44, B4, B21, B22, B32, B39, B41, B49, B56, B65.
