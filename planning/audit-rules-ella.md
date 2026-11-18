# Audit: the user's words in the rebuild papers against the code (Ella)

Asked by Wilma, 2026-11-18, after the user's "STOP JUST STOP GO BACK AND LOOK AT THE FUCKING RULES". The whole plan, read
from where Ella stands (the government's money and the order of a month), others' areas first. No fixes, no proposals.

**Code read:** the shared tree at commit dc0f9bd plus the uncommitted working files. Read-only; nothing was run.

**Not yet in the shared tree:** Bob's reviewed pieces for rule 4, rule 8, the first-year average and the cost at the
starting salary. The shared code is audited as it is, so those rows read DIFFERENT.

**How each verdict was reached:** parts B to E were read by helpers working from Ella's brief. Ella checked every
DIFFERENT row in the code herself. Where they disagreed, or a claim did not hold, her verdict is the one given, with
the reason.

**Verdicts:**
- **SAME:** the code does what the words say.
- **DIFFERENT:** it does not.
- **NOT BUILT (step N):** the plan's own build order (rebuild-company.md 13) puts it at a later step.
- **n/a:** process, not code.

## A. Grants, the purse and the landing's government side, the market, the press side of adverts (Ella, read directly)

Code: the shared tree as of commit 2111905 plus the uncommitted working files (read 2026-11-18).

### A1. Lines with the user's words

| § / line | The user's words (verbatim, short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| 9.3 (518) | "Company and people should be able to stock up if the price is low" | Households: `households.gd:post_orders` 624–646 posts an AHEAD order toward 6 months of food at any price (15f governs it). Companies: `making.gd:post_orders` 199–211 posts an AHEAD order only for an input that spoils under 5% a month (`KEEPS_PM` 50), only when the cheapest offer is at most 80% of the input's worth (`AHEAD_BELOW_PM` 800), topping up to 2 months' need. | DIFFERENT (companies) | The paper's reading under the user's words: "A price is low when it is under that worth." Built: low means at most 80% of the worth. The amount is capped at 2 months' need; the paper's proposal says "as far as its money reaches and the goods keep". Households: SAME. |
| 9.3 (522) | "No what's low should be against what its worth to the buyer, like when they buy normaly" | The worth is `making.gd:input_worth` (line ~214), the same figure the ordinary NEED order uses as its most-it-will-pay (line 199). | SAME (the measure) | The threshold on that measure is 80%, not "under" (row above). |
| 9.5 (545) | "the goverment starts with its subsidiaries as before" | `landing.gd:land` 85–121: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL and POLICE as state companies with no plant and no staff (`UNBUILT` 47–48); the administration with a placed crew; the housing office with the shelters; Colony Stores; Colony Public Works (`home_builders.gd:35`). | SAME | 9.12's list does not name the police or Colony Stores; the stores hold the landing stock (12.2, 9). |
| 9.5 (545) | "All company types needs to be able to be created as private ... then the conitions for new ones don't get switched on" | `month.gd:27` `FOUNDABLE = ["FARM"]`: only farms are founded in step 3; rules 7 and 8 (`rules.gd:founding`) would apply to every type. | NOT BUILT (step 4: "All items") | Step 3 is "tested first on food alone" (13, step 3). Consequence: the BAKERY, TRUCKER and TRUCKSHOP programmes are open from month one with sums set (seed 1: bakery wants 5, sum 145,867), but no bakery, haulier or truck workshop can be founded, so they can pay nothing. |
| 9.5 (548) | "per pulpe plus staff is how taxes for schools are calibrated Yea they all get tax brackets" | Not found (grep "bracket" in sim/economy). | NOT BUILT (step 8) | |
| 9.5 (550) | "I DID NOT SAY GIVE EVERYONE ... GRANTS" | `grants.gd` `KINDS` 54–59: FARM, BAKERY, TRUCKER, TRUCKSHOP, all family size; no other grant. | SAME | |
| 9.5 (551) | "No split trucks and workshops" | Two kinds, TRUCKER (HAULIER) and TRUCKSHOP, two levers. | SAME | |
| 9.5 (553) | "the goverment can lean on companies if they don't comply or on the union" | Not found in sim/economy or sim/politics. | NOT BUILT | Section 13 names no step for it (unions are step 9). |
| 9.12 (655) | "5 building companies" | `home_builders.gd:33` `HOME_WORLD`: five (1 large, 2 average, 2 small), owned HOME_WORLD. | SAME | |
| 9.12 (655, 662) | "all three grant types open"; "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE" | `econ_publish.gd:63–69`: the four grant levers at `GRANT_START_PCT` 50 from month one; `grants.gd:monthly` opens the four programmes in month 0; since 9e18bf8 the government decides each before anyone founds (`month.gd:company_ai`). | SAME | 50% is a starting number of ours. |
| 9.12 (655) | "no sectors beyond landfallpoint" | One area at landing (`AreaStore.found_landing`, "hb:1"). The districting law draws one district over it in month 0 ("ldist:1", `districting.gd:225`). | SAME | One district over the landfall place, none beyond it. |
| 9.12 (669) | "materials come with the start not finished buildings 5 years worth of equipment ... they are companies from the world" | `landing.gd` `STOCK` 58: MATERIAL 9,700, COMPONENT 1,060, TRUCK 20, FOOD 12,000, held by Colony Stores and sold at the starting prices (`_stores` 150–160, `price_fixed`). The builders are home-world companies. | SAME | MATERIAL and COMPONENT are Bob's reading of "5 years" (five years of the builders' full work); FOOD is Wilma's addition (12.2, 9). |
| 9.12 (669) | "Tell me in any colony builder do you place out fucking plants from start????" | No farm, mine or factory at the start; the subsidiaries have no plant (`UNBUILT`). Only the shelters are plants (landlord blocks, 12.2, 11). | SAME | |
| 9.12 (678) | "no the old system and the new for five years are not the same" | `landing.gd:60` `BUILDER_CAPITAL_MONTHS` 3: each home-world builder lands with 3 months of its wage bill, not five years of running costs. | SAME | 3 is a starting number. |
| 12.9 61 | "One grant per household." | `grants.gd:_refusal` → `had()` (founder's `had_grant` or a grant row on the founder); `apply` calls `Households.mark_granted` (since 9e18bf8); a founder going back takes it to the pool (`households.gd:release_founder`, `granted`). | SAME | |
| 12.9 61a | "grants should be limited time for when you can apply" | `grants.gd:monthly`: each programme opens with `until` = start + `PROGRAMME_M` (24); at `until` → `_end_programme`. | SAME | 24 months is a starting number. |
| 12.9 61a | "when a grant ends, they reset to zero" | `LawOps.end_programme` (`law_ops.gd:972`): the lever goes to 0 by law, in force at once. | SAME | |
| 12.9 61a | "start over on where to put it"; "and where it covers too" | `gov_builder.gd:_grant_cover`: at lever 0, cover and sum are erased; reopening chooses again. | SAME | |
| 12.9 61b | "put a max sum into the grant" | `gov_builder.gd:_grant_sum` sets `grant_sum[kind]` at opening; `grants.gd:apply` refuses past `sum_left`; `quote` returns 0 past it. | SAME | Before 9e18bf8 this was DIFFERENT: the sum was set after month one's applicants (sum 0). Fixed and merged. |
| 12.9 61b | "based on how many darms they want" | `grants.gd:wanted`: persons × 1 FOOD over a family farm's full output, less what stands and plans MADE or SIGNED make, rounded up. Seed 1, month 0: 27. | SAME | "How many more" (less standing and planned) is Wilma's reading. |
| 12.9 61b | "maybe a little extra to be sure" | `grants.gd` `EXTRA_PM` 100: a tenth on top. | SAME | A tenth is Wilma's starting number. |
| 12.9 61b | "A founder who can pay without a grant is not stopped by it" (the paper's "So", not the user's words) | `households.gd:pick_founder` draws households that can pay without a grant; rule 8 (`rules.gd:founding`, covered) is what stops plans. | SAME as the paper | See the next row. |
| Not in any paper | The user, 2026-11-18 (relayed by Wilma): "WHY IS THE GIVERMENT LETTING 89 BE FOUNDED THEN THEY CAN STOP THE FUCKING GRANT REMEBER????" | The grant stops at the sum (above). Founding without a grant goes on until rule 8 says the food is covered. | NOT RECORDED | These words are in no planning paper (grep). The paper's line "a founder who can pay without a grant is not stopped by it" stands beside them unreconciled. |
| 9.2 (380) | Hiring costs an advert paid to a newspaper (the user's ruling on keeping workers, relayed) | `rules.gd:_advertise` 431–450 → `media_ops.gd:job_advert` 957: paid to the papers read in the area's district by their circulation, else every paper by its whole circulation; booked as the paper's advert income and in its margin. | SAME | |
| 9.2 (407) | "On posts when you many an open post you pay the first time not every consecutive month after" | `rules.gd:_advertise`: pays only for posts not yet paid for (`advertised[key]`); `_hire` uses a paid post up when it is filled. | SAME | |
| 12.10, 65 | (the user's ruling for utilities) No law may forbid a company type from being private | `land_law.gd:33,182`: the state's KEEP land is leased, never sold, "no law forbids a private company". No law bans a private type (grep). | SAME | |

### A2. Lines that are a proposal, a reading or a starting number (no user words behind them)

| § / line | The paper's text (short) | Marked as | What was built | Matches the paper? |
|---|---|---|---|---|
| 9.3 (526) | how much to stock up: "as far as its money reaches and the goods keep" | proposal | Companies: up to 2 months' need, inputs spoiling < 5% a month (`making.gd` 204–207). | NO: a 2-month cap and a 5% spoil limit are not in the paper |
| 9.3 (528) | a stock-up order buys only what the month's orders leave; counts as spending for rule 7; its shortfall is not unmet demand | Wilma's decision | `market.gd:_clear_book`: NEED first, then AHEAD; `_summarise`: AHEAD counts only what it got in "ordered"; `_turned_away` only for NEED. | YES |
| 9.2 (386) | the advert: a tenth of one month's pay of the post, per person hired | Wilma's starting number | `media_ops.gd` `ADVERT_PM` 100. | YES |
| 9.2 (405) | "a company that cannot pay the adverts for the people it wants this month hires none that month" | Bob's proposal | `rules.gd:_advertise`: pays for as many posts as its money reaches, and hires into those. | NO: the paper still says "none" |
| 9.12 (677) | the landing stock also holds food | proposal | `landing.gd` `STOCK` FOOD 12,000 (twelve months for the founding thousand). | YES (the amount is ours) |
| 12.2, 9 | the government sells from the landing stock at the starting prices | Wilma's | `landing.gd:_stores`: offered at `start_price`, `price_fixed`; `stores_takings` → treasury. | YES |
| 12.2, 11 | the first homes are the landing shelters, with a low rent | Wilma's | `landing.gd` `SHELTER_RENT` 97 ("half a new home's rent, which the user doubled"). | YES |
| 12.5, 41 | "The benefit and pensions are lines on the government's purse, each a share of the area's starting salary" | Wilma's decision | `landing.gd:support_rates` 193–197: `TypeTable.salary("G")` × rate (benefit 40%, pension 35%, `econ_publish.gd:53–55`), the type table's 300. The area's starting salary is `Rules.starting_salary` (2 × the rent, about 194 at the landing). | NO: the type table's 300 is used, not the area's starting salary. The comment says "until areas carry their own salary line (step 3)", and step 3 has that line now. |
| 12.9 61a | window of 24 months | starting number | `PROGRAMME_M` 24. | YES |
| politics-face 86 | each grant starts open at a percentage | (E) | `GRANT_START_PCT` 50. | YES |
| 12.9 61b | the other three grants get their sum the same way | Wilma's reading | `grants.gd:wanted`: BAKERY counts the whole FOOD need as bread; TRUCKER and TRUCKSHOP one in each area with none. | YES |
| 12.10, 62 | taxes, budget lines, the reserve | Wilma's | Not built. | NOT BUILT (step 8) |
| 12.10, 64 | a legal ceiling on a price or rent stops the rules | Wilma's | Not found. | NOT BUILT (step 8, price controls) |
| 12.10, 72 | "A party buys its advertising from newspapers" | Wilma's | `media_ops.gd:pay_ads` 868–903: paid to the papers by circulation in the targeted districts; the part the papers' circulation does not cover goes to households (`PartyLife._household_receive`). | NO: part of a party's ad money goes to households, not to newspapers |
| 12.10, 73 | every ending, mass layoff, shutdown and famine publishes who is responsible | Wilma's | Mass layoffs: `econ_publish.gd:layoffs` (ECON_LAYOFFS_MASS), called by `rules.gd:_publish_layoffs` 505. Famine: `households.gd` ECON_FAMINE. Endings and shutdowns: not found in step 3. | PARTLY (endings are step 5) |
| 12.10, 74 | a price index per area for voters | Wilma's | Not found. | NOT BUILT (step 11) |
| Comment only | `media_ops.gd` job advert header: "Bob's hiring calls job_advert once per hiring" | (code comment, Ella's) | Hiring now pays once, when the post opens (`rules.gd:_advertise`). | NO: the comment is out of date |

## B. rebuild-company.md sections 1 to 9.2 (lines 1–513)

| § / line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| 1 L23 | "one object that is the company ... 2d array" | One record per company (`company.gd:create` 38–76); one type table (`type_table.gd` ROWS 66–170); one rules function for every company (`rules.gd:month` 59, `company_month` 67). | SAME | |
| 1 L27 | "building fixes behind off switches is not a valid way" | No on/off flags in rules, market, making, company, month, households (grep). | SAME | |
| 1 L31 | "Same company types can come but not their code or balancing" | New files; numbers set new. | SAME | Copying cannot be checked from the code. |
| 1 L34 | "set a credit prices we are going to have to adjust it anyway" | `type_table.gd:start_prices` 322–368 (PAYBACK_Y 10, PAYBACK_HOMES_Y 13.5, LAND_PM 100, SALARY_G 300). | SAME | |
| 1 L40 | "not meant too be a perfect economy" | Nothing props up a losing private company. | SAME | |
| 3 L83 | "No i said each COMPANY" (one price per company) | `price` on each company record (`company.gd` 64). | SAME | |
| 4 L101 | "a 2d array of wich items a company type makes, if they pick from first or second output" | ROWS with `lines` [first, second]. Nothing ever changes a company's `line` (no writer). | SAME (table); picking NOT BUILT (step 4) | |
| 4 L110 | "services have no output but a client take in" | Service rows sell "@client"; nothing sells places yet. | NOT BUILT (step 4) | |
| 4 L117 | "things can be done in two different ways" | `way` column (`type_table.gd` 60–64). | SAME | |
| 4 L132 | "per pupil plus staff is how taxes for schools are calibrated" | No bracket. | NOT BUILT (step 8) | |
| 4 L135 | "noise polution should also drive down price of housing" | Nothing reads the row's noise. | NOT BUILT (step 7) | |
| 5 L143, L152 | "Family 1/6 small 1/3 avrage 2/3 large full ... small penalty"; "You penalty is fine" | SIXTHS 1/2/4/6; PENALTY_PM 60/40/20/0 (`type_table.gd` 15–16). | SAME | |
| 5 L159 | "This sounds good" (400 m block) | BLOCK_CELLS 4 (`town_grid.gd` 52); one full size per type per square (`site.gd` 167, 232, 328). | SAME | |
| 5 L161, 6 L179 | "buy out the other company ... or build a new"; "money is a limitor" | No rule 5. | NOT BUILT (step 6) | |
| 6 L176 | "the more inventory you have, the more you reduce your price" | Rule 2: 5% × unsold/(unsold+sold) (`rules.gd:price_rule` 120–143). | SAME | |
| 6 L177 | "if you sell out all your producing produce MORE" | Rule 3 on unmet_above (`rules.gd:output_rule` 174, 190). | SAME | The step size is the next row. |
| 6 L200; MASTER 1022 | "25?! 5!!! CHANGE IT!!! STOP HEDGING" (output at most 5% a month) | `G_PM` 50. A rise is `max(1, max(lv, 1000/posts) × up / 1000)` (`rules.gd` 190). | DIFFERENT | Below one post's share of full, the rise is more than 5% of the level (family farm at 10‰ → +12‰). Recorded in 15b as Bob's reading with Wilma's yes; the user's words say 5%. |
| 6 L178, L202, L204; MASTER 1031 | "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | `rules.gd:output_rule` 175: `down := step_pm(G_PM, unsold, sold)` in ANY month with anything unsold. No 50% test, no run of months. | DIFFERENT | It cuts on any unsold amount, every month. This is the fault the user named ("let me guess they just cut if they sell less???"). Bob's fix is reviewed but not in the shared tree. |
| 6 L209; MASTER 1037 | "A CUT IS 5% ... IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | The cut is 5% × unsold/(unsold+sold), 0–5%; no run counter. | DIFFERENT | Not a flat 5%, and nothing counts a fourth month. |
| 6 L180 | "A hard rule here is fine" (rule 6) | No idle-plant closing. | NOT BUILT (step 6) | |
| 6 L181 | "they read an avrage of all avaliable jobs"; no cap | `rules.gd:work` 615–628; `month.gd:founding` loops with no cap. | SAME | Its 12-month division is row 15a in F. |
| 6 L183 | "if below making price climbing allways had priority ... cap it at 5% THEN DO THE SAME FOR BOTH" | Tie: below making R1, else R2 (`rules.gd` 130–132); `K_PM` 50 both ways. | SAME | |
| 6 L187 | "If something else than price stops sales it should not count on adjusting price!!" | NO_MONEY counts for no seller (`market.gd` 213–214); waiting stock is not offered (87). | SAME | |
| 6 L192; 12.3 14 | "It sells too cover all monthly expences" | `rules.gd:hold_back` 148–159: expenses = wage bill + the month's inputs + upkeep. | DIFFERENT | Adverts, layoff pay paid, and debts the law collects are monthly expenses (all booked; all in `winnings` 566–567) but are not in the hold-back's expenses. "upkeep" is never booked, so it is always 0. The helpers disagreed; Ella read the code. |
| 6 L196; MASTER 1016 | "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | `K_PM` 50 (`rules.gd` 46, 111–116). | SAME | |
| 7 L222–228 | offices, "the same company can become freight", the work queue, truck repair, stress | Rows only; no code. | NOT BUILT (steps 4 and 9) | |
| 8.1 L235 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... BEFORE ACCEPTING A GRANT" | `month.gd:_found_one` 158–163: make_plan, own, then `Grants.apply`; company created only at `building.gd:open_due`. | SAME | |
| 8.1 L235 | "you can't fail before you exist ... no expenses beyond building" | A plan has no staff or wages; a given-up plan is never a failed company (`building.gd:give_up` 325–353). | SAME | |
| 8.3 L251, L262 | "End of a company can happen in three ways ..."; "taken to court ... settle" | No company ending; court liquidation returns false (`econ_face.gd` 586). | NOT BUILT (step 5) | |
| 9.1 L277, L302, L308 | "take it wholesale ..."; "wholesale does not mean unchecked"; "That's fine" (pools) | Pools by area and band (`households.gd:pool_id` 42). | SAME / n/a | |
| 9.1 L314 | "what are you paying power and water on if you can't pay the rent?" | Food budget = all money (`households.gd` 619); rent after (`pay_rent` 811). | SAME | |
| 9.2 L337 | "the three rules for price should be applied here too" | Superseded by the 2026-11-18 offer rule (`rules.gd:salary_rules` 225–260). | superseded | |
| 9.2 L342; MASTER 734 | "they have a sallery set on hire then it climbs based on yearly upps set by goverment" | Pay fixed per hire row (`company.gd:staff_change` 241–247); only `yearly_raise` 422–435 and `negotiate` change it; minimum lever `ECON_YEARLY_RAISE_MIN_PCT` 2. | SAME | |
| 9.2 L352; MASTER 821 | "10% if it's a good job less if stressfull, and plus 1% per year ... up to 15%" | `households.gd` 993–1017: 100‰, +10‰ a year, cap 150‰; the stress part always 100. | SAME (stress NOT BUILT, step 9) | |
| 9.2 L362 | "underpayed workers go to the union, they can quit ..., if not they may unionise" | Quitting for pay built (`labour_month` 1023); no union. | SAME / union NOT BUILT (step 9) | |
| 9.2 L369; MASTER 752 | "avrage ask salleries in the company and underpayed is based on that line" | `company.gd:avg_pay` 708–715 averages within a post tier (G, S, Sp). | DIFFERENT | Not the company's average: the tier's, from the "(proposal, one detail)" in 9.2. |
| 9.2 L373–374; MASTER 834/838 | "costs of hiring, articles in the newspaper", "6 months training", "payment after fire ... three months", "it should apply to builders" | Layoff pay `LAW_LAYOFF_PAY_MONTHS` 3 × own pay (`households.gd:layoff` 268–287), the unpaid part a LAYOFF_PAY debt; advert `ADVERT_PM` 100; training 6 months from 500‰; builders run the same rules. | SAME | The months follow the law on the layoff day, as Wilma told the user (15e). |
| 9.2 L407; MASTER 1007 | "you pay the first time not every consecutive month after" | `rules.gd:_advertise` 431–450 pays once per opened post. | SAME | |
| 9.2 L415; MASTER 759 | "the manager, negotiation can bring it closer to avrage" | `households.gd:_negotiate` 1072–1089 (July, halfway, if a year of the rise is held); `company.gd:negotiate` never above the average. The chief's management skill is never read. | SAME (the words) | Whether the manager takes part: table F. |
| 9.2 L439; MASTER 929 | "increases should not stack for seperate offers ... fall back to the original rule for settin on hire" | The offer is one per company × tier × area (`company.gd:hiring_salary` 378–382); `rules.gd:salary_rules` 250–260 climbs it while ANY post of that tier and area has been open a month, and clears it only when none has. | DIFFERENT | A separate new opening in the same tier and area is offered the climbed salary, not the original rule. |
| 9.2 L441; MASTER 929/933 | "5% each month ... i never said i wanted the rule for lowering" | `OFFER_CLIMB_PM` 50 a month; no lowering. | SAME | |
| 9.2 L452–453; MASTER 944/946 | "a 2d array to keep all things about the hires"; "You can merge if all rows match" | Hire rows {n, pay, since, train}; merged only on equal pay\|since\|train (`company.gd` 283–347). | SAME | |
| 9.2 L458; MASTER 950 | "Record it make them pay after our if they refused take it to court" | `Justice.owe` UNPAID_WAGES (`households.gd:pay_wages` 439–445); collected monthly (`justice_ops.gd:collect_debts`); petition at 12 months; the court's answer is a stub. | SAME (court NOT BUILT, step 5) | |
| 9.2 L464–472; MASTER 959–971 | "just rent at 2×"; "3 5x housing try it"; "2", "Merge with 2" | `STARTING_RENT_PM` 2000; `starting_salary` = area rent × 2 × tier (`rules.gd` 203, 270–271). | SAME | |
| 9.2 L478; MASTER 980 | "The build crews at start should not be hiring at all" | Placed and trained (`home_builders.gd` 110). | SAME | |
| 9.2 L483; MASTER 989 | "Place the goverment staff ... sallery at 2.5 from start same for builders" | `landing.gd:_crew` places them; `PLACED_RENT_PM` 2500 (`rules.gd` 207, 276–277). | SAME | |
| 9.2 L492; MASTER 1055 | "Screw lowering food, double the rent" | `HOME_RENT_PM` 2000 (`type_table.gd` 30); `SHELTER_RENT` 97. | SAME | |
| 9.2 L497; MASTER 1066 | "10 purple each" | FARM 24 posts, 240 a month. | SAME | |
| 9.2 L501 | "The district the plant hiring is in." | Pay at hire uses the plant's area (`households.gd` 187, 194). But `company.gd:vacancies` 643–657 lists posts and pay by the company's own area, and `rules.gd` 365–366 advertises and hires at `c["area"]`. | DIFFERENT | For a plant outside the company's own area, the vacancy list, the advert and the hiring use the company's area. Latent while step 3 has one area. |
| 9.2 L504 | "a company can grant a bonus ... 2% is a good start" | `ECON_YEARLY_RAISE_MIN_PCT` default 2; max(choice, minimum). | SAME | |
| 9.2 L506; HH 2b L148 | "emplyees only apply to jobs that meet their needs" | `households.gd:hire` 195–198. | SAME | |

## C. rebuild-company.md 9.4 to 12.9 point 60c (lines 536–1128; 9.5, 9.12 and 61–61b are in A)

| § / line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| 9.6 560 | "They can't order when there's not a ship there to take the order ... the full period of waiting every time." | `ship.gd:order` 167–194 refuses "no ship in port"; the order rides that ship home and back (`_leave`, `_arrive`). | SAME | Nothing calls `Ship.order` yet. |
| 9.6 569 | "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR" | No import rule beyond the hold. | SAME | |
| 9.7 577–579 | "5 building companies"; "3 months up front and add 1 month of additional supplies every month" | Five home-world builders; `UP_FRONT_M` 3 (`building.gd` 43, `_ready` 498–506, `supply_orders` 388). | SAME | |
| 9.8 591–599 | "This sounds good" (grid); "Below 250 start a gridd anyway"; "the closer to the coast ... more expensive" | `town_grid.gd` (PER_TILE 30, HOUSE 8, APARTMENT 60, TOWER 200; value 596–613); land = bill × 0.10 × value. | SAME (grid and land); rents from value NOT BUILT (step 7) | |
| 9.8 613–625 | wear below 55; buying your house; the top band moving out; apartment owners' fee | Not found. | NOT BUILT (step 7) | |
| 9.9 629, 634 | unions | Stubs. | NOT BUILT (step 9) | |
| 11 755 | "no sectors beyond landfallpoint" (the old district list) | The economy starts on one area; the old `econ_data.gd` district list is still read by `gov_builder.gd`, `home_world.gd`, `transport.gd`, `private_roads.gd`. | open in the paper | |
| 12.3 15a 836 | Rule 8: "the same signal says the work is covered" | `rules.gd:founding` 653–688 has only the share test; no covered test (grep "covered": none). | DIFFERENT | Not built in the shared tree, though step 3 is "rules 7 and 8". Bob's reviewed piece is not merged. |
| 12.3 15a 864; MASTER 806 | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | `rules.gd:founding` 663–677: standing + booked (SIGNED) + MADE with a PAID grant, by sixths. | SAME | 13's watch item 8 ("Plans are NOT counted") and the comments at `rules.gd` 647–648 and `month.gd` 124–125 are out of date. |
| 12.3 15d 869; MASTER 817 | "He should look for the shortest time" | `building.gd:sign_round` 253, 269–273: earliest start first; the soonest quote the plan's money covers. | SAME | A quote it cannot pay is no choice; the helpers disagreed, and Ella's reading is SAME. |
| 12.3 15e 872 | "Yes, i agree" (the family works its own farm without wages) | `rules.gd:family_to_posts` 518–542; `company.gd:hire_wanted`. | SAME | |
| 12.3 15e 872; MASTER 847 | "ship food should be considered less desierable" | `market.gd` `SHIP_LESS_WANTED_PM` 250, rank 89–93. | SAME | |
| 12.3 15e 881; MASTER 1046 | "FARMS DON'T SHUT" | `rules.gd:staff_to_posts` 339–347: with wages unpaid, hired staff are laid off and a plant whose `staff_count` is 0 is closed "NO_STAFF". `staff_count` (`company.gd` 461–475) does not count the family, so a family farm is shut with the family on it. `building.gd:open_due` 628–629 closes a plant "LAW". `close_plant` has no farm exception. | DIFFERENT | Farms still shut. The same rows break 15e's "A family farm with no money still grows food". |
| 12.3 15e 881 (new, dc0f9bd) | "the farm needs a buffer say 50% until it had 6 months worth built up then 10%" | `rules.gd:winnings` 560–575: the family takes everything earned above one month's wages, inputs and upkeep (`keep`). | DIFFERENT | No 50% / 10% buffer and no six months' worth. |
| 12.3 15e 885; MASTER 998 | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST ... TAKE SIX OUT OF THIRTY SELL 24" | `households.gd:post_orders` 611–617 → `making.gd:family_take` 127–137: need + one more month's need, before the market, never offered. | SAME (mechanism) | The numbers come out differently: a family farm makes 37.6 at full (`type_table.gd` 68, 254), and a family is about 2.5 people. |
| 12.3 15e 893; MASTER 865 | "the farm would be their home, wich means they are paying on any loans ... and uppkeep" | `landing.gd:rent_due` 284–286: no rent on their own open farm. | SAME (no rent) | Upkeep is never booked; loans are step 5. |
| 12.3 15e 899; MASTER 896 | "I think two is better" (a loss carried forward) | `rules.gd:winnings` 570–573, `loss_carried`. | SAME | |
| 12.3 15e 912; MASTER 856 | "The owners of a family farm should take winnings no sallery, wich comes after" | `rules.gd:winnings`, paid in JUSTICE after the debt collector. | SAME | The buffer is the row above. |
| 12.3 15f 923–933; MASTER 905–911 | "they buy 2 units if food instead of one"; "six months of food in storage"; "i don't think you wait"; "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS" | `STORE_MONTHS` 6; store order at most one need a month, at any price its money pays (`households.gd` 629–649); eaten only when short (742–745). | SAME | |
| 12.3 15c 948, 955; MASTER 788, 797 | "they should not cut for the start, and they should not increase prices for claimed jobs"; "At start id assume they know work is coming" | `building.gd:seller_signal` returns {} until the first quote; the book is never re-counted. | SAME | A plan signing to wait is counted once as unmet in its signing month (Wilma's decision). |
| 12.3 23a 977 | "if they want to but can't buy, bread goes too high — the company can win by lowering" | `market.gd` 213–222: NO_MONEY only with nothing at all; otherwise PRICE, a refusal for rule 2. | SAME | |
| 12.5 35; 12.9 60a | "they should become individually counted on company start ... don't malt to many people to track" | `households.gd:make_founder` at plan making (`month.gd` 155). | SAME | |
| 12.8 50c | bank lending must grow the money stock (a paraphrase) | No bank. | NOT BUILT (step 5) | |

## D. rebuild-company.md 12.11 to the end, and rebuild-building.md

| Paper / line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| RC 12.11 1163 | "I think most of these needs to be worked in" | Items 77–109 are not built at step 3. | NOT BUILT (later steps) | `gov_builder.gd` 51–58 still wires the old automatic reserve release (1500 FOOD at shortfall > 50‰); it does nothing because `EconFace.actions_enqueue` is a stub. |
| RC 13 step 4 (1277–1282) | "a prefernce for farms not being close to towns ..."; "Save it for when trucks and roads come"; the four answers | Not built. | NOT BUILT (step 4, as ordered) | Wilma's view in the same note, "farms are already scored away from homes", is false: `site.gd` 171 and 180 place farms nearer settlements. |
| RC 13 step 8 1301 | "the government can order stockpiles to help in famin once we get back to politics" | Not built. | NOT BUILT (step 8) | |
| RC 13 1309; 15 1417 | "Get everyone involved ... atleast one other reviews each peace of code"; "review the whole thing from their perspectives" | Process. | n/a | |
| RC 13 1321; MASTER 725 | "a backend column somhere that records all things happening like a log" | `core/logbook.gd` (note, rows, counts, story, write; keeps all). | SAME | |
| RC 14 1414; RB L17 | "not finished buildings" | `landing.gd:_shelters` 124–146: finished LANDLORD blocks of 50 homes stand in month one. | DIFFERENT | Flagged by the planner in 14 as a deliberate deviation ("I gave the settlers plain shelters anyway"). No production plant stands. |
| RB L13–14 | "PLANS ARE MADE BEFORE ..."; "you can't fail before you exist" | As in B. | SAME | |
| RB L15–16 | "3 months up front and add 1 month of additional supplies every month" | As in C. | SAME | |
| RB L17–18 | "5 building companies"; "5 years worth of equipment ... companies from the world" | As in A. | SAME | |
| RB 4.3 164 | "He should look for the shortest time" | As in C. | SAME | |
| RB 3, 5.1, 5.3 | apartments 0.85 / tower 1.15; "money is a limitor"; homes 55 | Not built. | NOT BUILT (steps 6 and 7) | |

## E. rebuild-households.md and rebuild-law-face.md

| Paper / line | The user's words or ruling (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| HH L7–8 | "we take how it works and transfer over not take the code"; "wholesale does not mean unchecked" | Written new. | SAME / n/a | |
| HH 1.1–1.2 | pools; "don't malt to many people to track" | `ensure_pool`; `make_founder`, `release_founder`, debts carried. | SAME | |
| HH 1.5 | nothing from the home world except on a ship in port | Money and settlers arrive only at the landing and at `ship.gd:_arrive`. | SAME | |
| HH 1.6 | food, then rent, then water and power | As in B. | SAME | |
| HH 1.9–1.10 | hunger from need; short of money is not refusing the price | `after_market` 741–751; `market.gd` 214–220. | SAME | |
| HH 1.11 | nothing behind an off switch | None found. | SAME | |
| HH 2b 148–166 | needs; quit bar; layoff pay; winnings; the farm is home; ship food; negotiation; set on hire | As in B and C. | SAME | Two exceptions, both covered in B: the tier average (DIFFERENT) and the manager (table F). |
| HH 2b 198–202 | the store; "THEY BUY DOUBLE ..."; "EATS THEMSELVES FIRST" | As in C. | SAME | |
| HH 3.4 I1 | the 130% crowding limit stays | `households.gd:homes` 547. | SAME | |
| LF 5.6 250 | layoff pay "a debt like unpaid wages, and can end the company" | LAYOFF_PAY in PETITION_KINDS; liquidation a stub. | SAME (ending NOT BUILT, step 5) | |
| LF 4 154–166 | "if not the owner is taking to court, where the bank can either settle ..." | Not built. | NOT BUILT (step 5) | |
| LF 7 316 | "failing is a result, not a fault" (a price ceiling) | No ceiling. | NOT BUILT (step 8) | |

## F. Lines that are a reading, a proposal or a starting number, where what was built does not match the paper

(Every number from those lines that does match is in the part tables above and in A2.)

| Paper / line | The paper's text | Marked as | What was built | Mismatch |
|---|---|---|---|---|
| RC 12.3 15a 829–835 | the work: 12 months summed ÷ 12; first-year months at the grant's need | Bob's reading, Wilma's yes | `rules.gd:work` 625 divides by the months present (`h.size()`); no first-year fill | Not built in the shared tree (Bob's piece unmerged) |
| RC 12.3 15a 840–848 | what a plant seen delivers (made less the family's take; unlived months at full) | Bob's reading, Wilma's yes | not built | as above |
| RC 12.3 15a 854–859 | cost to run at the area's starting salary; the same figure is the opening money | Bob, Wilma's yes | `rules.gd:running_cost` 637 uses `TypeTable.salary` (300 × tier); `building.gd:founder_needs` uses it | as above |
| RC 12.5 41 | benefit and pensions: a share of the area's starting salary | Wilma's | `landing.gd:support_rates` 193–197: `TypeTable.salary("G")` (300) × 40% / 35% | the type table's 300, not 2 × the rent |
| RC 12.5 37–38 | starting salary 1.5 × (rent + food); needs = two-thirds of it | Wilma's | 2 × rent (the user's later ruling); `needs_line` = cheapest rent + food × 2.5 | the paper's 37 is outdated; 38 no longer holds as written |
| RC 9.3 526 | stock up "as far as its money reaches and the goods keep" | proposal | `making.gd` 204–207: only at ≤ 80% of worth (`AHEAD_BELOW_PM` 800), up to 2 months' need, inputs spoiling < 5% | 80% and 2 months are ours, in no paper (the paper says "low = under that worth") |
| RC 9.2 405 | "a company that cannot pay the adverts ... hires none that month" | Bob's proposal | pays for as many posts as its money reaches | paper outdated |
| RC 9.2 399–402 | the layoff weighing at "the tier's pay of the entry laid off first" | Bob's proposal | `rules.gd:layoff_weighing` 476–480 uses the tier's average pay | different pay basis |
| RC 9.2 418–422; HH 165 | negotiation before quitting; depends on the manager | proposal | quitting runs every month regardless; the chief's skill is never read | partly built |
| RC 9.2 511–512 | only pay moves a salary; a post open for lack of skill or housing is no reason to raise it | proposal, Wilma's | the offer climbs for any post open a whole month | different |
| RC 12.9 56 | wages and material follow their cost during the build | Wilma's | supplies are ordered at most at the worth at signing (`building.gd:supply_orders` 394); above it the order is refused | material does not follow a rise |
| RC 12.9 60c | back "in the income band they now belong to" | Wilma's | `release_founder` returns them to the band they left | different |
| RC 12.10 72 | "A party buys its advertising from newspapers" | Wilma's | `media_ops.gd:pay_ads`: what the papers' circulation does not cover goes to households | different |
| RB 4.1 127–129 | trucks: from the home world by ship until the user answers | Otto, open for the user | 20 TRUCK in the landing stock | decided without the user's answer |
| RB 4.2 147–149 | founders in pool-id order | Otto | a seeded draw (HH 179 later decided the draw) | RB outdated |
| RB 4.5 185–187 | BW a month = bill / fewest months, or the crew available, whichever is less | Otto | `planned_bw` = ceil(bw / months); crew ignored | crew limit missing |
| RC 13 1290–1295 | "farms are already scored away from homes" | Wilma's view | farms score nearer settlements (`site.gd` 171, 180) | false |
| HH 2a 101 | founder "otherwise the oldest working-age one" | Otto's | no "oldest" (`_free_adult` 1165–1183) | not built |
| HH 2a 89, 120 | crews of 180 hired; one landlord plant of 400 | Wilma's start-up | crews placed; 8 plants of 50 | HH outdated |
| LF 5.5 237–238, 266–267 | the yearly raise's minimum has no effect until step 8 | Anni | in force from step 3 (`households.gd` 1097) | LF disagrees with the code and with HH |
| LF 2 94–95 | no permit, licence or fee before step 6 | Anni | `law_company.gd:may_sign` and `may_open` check zones and licences from step 3 | different |
| LF 8.2 332–335 | land at value × the floor pct; lease at the bank's rate | Anni | floor pct recorded but not applied; lease at a fixed 0.6% | different |
| LF 1.3 37 | the law screen marks levers "not in force yet" | Anni | not found | not built |
| Code comments | `media_ops.gd` "once per hiring"; `rules.gd` 647–648 and `month.gd` 124–125 "plans do not count"; RC 13 watch 8 | — | the code follows the later rulings | comments and paper out of date |

## G. The count

**DIFFERENT against the user's words: 12.**
1. Rule 4: output is cut in any month with anything unsold; not "over 50% ... 3 months in a row" (`rules.gd:output_rule` 175).
2. Rule 4: the cut is a sliding 0–5%, not "A CUT IS 5%", and nothing counts "a fourth month" (same lines).
3. Output may rise more than 5% of the level below one post's share ("5!!!"; `rules.gd` 190).
4. Rule 8, "the same signal says the work is covered": not built in the shared tree (`rules.gd:founding`).
5. "FARMS DON'T SHUT": family farms are shut "NO_STAFF" with the family on them, and any plant can be shut "LAW" at opening (`rules.gd` 346–347; `building.gd` 628–629).
6. The farm's buffer, "50% until it had 6 months worth built up then 10%": winnings keep only one month's costs (`rules.gd:winnings` 568–573).
7. "It sells too cover all monthly expences": the hold-back leaves out adverts, layoff pay and debts (`rules.gd:hold_back` 155).
8. "increases should not stack for seperate offers ... fall back to the original rule": the climbed offer is shared by every opening of a tier and area (`rules.gd:salary_rules` 250–260).
9. "avrage ask salleries in the company": the average is per tier (`company.gd:avg_pay`).
10. "The district the plant hiring is in": vacancies, adverts and hiring use the company's area (`company.gd:vacancies` 647, 657; `rules.gd` 365–366). Latent with one area.
11. "Company and people should be able to stock up if the price is low" (companies): only at ≤ 80% of worth, at most 2 months (`making.gd` 204–207).
12. "not finished buildings": the landing shelters (deliberate, flagged in RC 14).

**Readings and decisions, built differently (table F):** 24 rows. The ones on money the purse or the founders pay every month:
- the benefit and pension base (12.5, 41): the type table's 300;
- rule 7's year (15a);
- rule 7's cost at the starting salary (15a);
- a party's ad money (12.10, 72).

**Not recorded in any paper:** the user's "WHY IS THE GIVERMENT LETTING 89 BE FOUNDED THEN THEY CAN STOP THE FUCKING GRANT REMEBER????" (2026-11-18). It stands beside 61b's "a founder who can pay without a grant is not stopped by it".

**Reviewed but not merged:** Bob's three pieces already fix rows 1, 2 and 4 of the count and the first three rule-7 rows of table F.
