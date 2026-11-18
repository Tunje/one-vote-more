# Audit: the plan's rules against the code (Anni, 2026-11-18)

**Asked by Wilma, for the user:** "STOP JUST STOP GO BACK AND LOOK AT THE FUCKING RULES".

**What was read.** Every line carrying the user's own words, in all of:
- rebuild-company.md (whole);
- rebuild-households.md;
- rebuild-building.md;
- rebuild-law-face.md;
- MASTER-PLAN.md's rebuild rulings (lines 665–1070).

Each line was checked against the code in the shared tree at commit 0c9e266, whoever owns the file. The papers were read in parts by helpers working for Anni, with the code read directly in each. Anni checked the main finding of each part in the code herself.

**What is in it.** No fixes and no proposals: only what the words say, what the code does, and whether they match.

**Verdicts:**
- **SAME:** the code does what the words say.
- **DIFFERENT:** the code does something else now.
- **NOT BUILT:** nothing does it yet. Each row says whether the plan puts it in a later step or in step 3.

**Evidence besides reading.** A seed-1, 60-month game at 0c9e266 with every ledger transfer tallied by memo. It is summarised in the law part below.

## Summary: DIFFERENT against the user's own words (20; duplicates across the papers merged)

**Code against the words (18):**
1. **When output is lowered (rule 4).** The user said: "only lowered if over 50% of offered goods is not sold 3 months in a row". `Rules.output_rule` (rules.gd:175–190) lowers it in any month with anything unsold. It has no 50% test and no count of months.
2. **The size of the cut.** The user said: "A CUT IS 5%". The cut is level × 5% × unsold/(unsold+sold), so anywhere from 0 to 5%; half unsold gives 2.5%.
3. **The fourth month.** The user said: "IF THERE'S IS A FOURTH MONTH LOWER AGAIN". No run of months is kept, so it cuts every month that has anything unsold.
4. **How far output rises.** The user said: "Output moves at most 5%". The rise is 5% × s/(1+s) of the larger of the level and one post's share of full, and at least 1 per mille (rules.gd:190). Below one post's share it moves more than 5% of the level. That is Bob's reading with Wilma's yes.
5. **"FARMS DON'T SHUT".** The 19a path (rules.gd:346–347) closes any plant whose hired staff count is 0, as "NO_STAFF". The family is not counted, so a family farm still worked by its family is shut once its hired hands are laid off unpaid. Nothing reopens it.
6. **Holding stock back.** The user said: "It sells too cover all monthly expences". `hold_back` (rules.gd:155) covers only wages, this month's inputs and upkeep. Upkeep is never booked, so it counts as 0. Adverts, layoff pay, debts and lease rent are left out.
7. **The starting salary in the running cost.** The user said: "just rent at 2×". `Rules.running_cost` (rules.gd:633–645) still prices posts at the type table's 300/450/675, not 2 × rent (194/291/436 at the landing). It feeds rules 7 and 8, `Building.founder_needs`, a founder's opening money and every grant amount.
8. **The starting salary in the benefit.** The user said: "just rent at 2×". `Landing.support_rates` (landing.gd:196) pays the benefit and the pension as a per cent of 300, not of the area's starting salary.
9. **Builders and claimed jobs.** The user said: "they should not increase prices for claimed jobs". A plan that signs to wait behind a builder's book is counted as unmet BW demand (building.gd:291–294). That raises the builder's price the next month.
10. **Who is underpaid.** The user said: "avrage ask salleries in the company". `Company.avg_pay(cid, tier)` (company.gd:708) averages one tier only, which follows the proposal at rebuild-company.md l.423.
11. **Layoff pay "part of the contract set on hire".** The months are read from the law on the day of the layoff (Wilma's decision). A later change of the law applies to people already hired.
12. **Layoff pay "should apply to builders".** In `layoff_weighing` the training loss reads `Company.price(cid, "@BW")`. A builder's price is kept under "BW", so the read gives −1, which becomes 0, and a builder's training loss is always 0.
13. **Negotiating with "the manager".** The user said negotiation "can bring it closer to avrage". The chief's management skill is never read. The negotiation is halfway or nothing, once a year in month 7, against the tier average.
14. **"increases should not stack for seperate offers".** The climbed offer is one number per company, tier and area, not per post:
    - a new opening gets an already-climbed salary;
    - the climb continues after a climbed post fills.
15. **"The district the plant hiring is in".** Job moves list and price a company's posts at the company's area (`Company.vacancies`, `move_job`), not the plant's.
16. **"the further under, the more reason" (stocking up).** Companies stock up only when an offer is at most 80% of what the input is worth to them (`AHEAD_BELOW_PM` 800). The amount is a fixed top-up to two months' need and does not grow with the discount.
17. **"materials come with the start not finished buildings".** The landing lays finished landing-shelter blocks of 50 homes at rent 97 (landing.gd:123–146). That is Wilma's decision 12.2/11, flagged in section 14 and not struck.
18. **A plan "ends only if its owner gives it up (no builder, no money)".** It is also given up when rule 7's signal is gone before signing (building.gd:239–240), which is Otto's decision in 4.4.

**Paper lines that contradict a later user ruling (2).** The code follows the later ruling; the paper line was never updated:
19. 9.3 l.521, "what they bought ahead they do not buy later": households still buy their whole month while holding a store, which is the user's later 15f.
20. 13 l.1395, "Plans are NOT counted … in rule 7": the code counts plans booked on builders and plans that took grants, which is the user's later 15a words.

## NOT BUILT that the plan puts in step 3 (now)

- **Rule 8's coverage test** (15a).
- **Orders to the home world.** `Ship.order` exists (ship.gd:167), but nothing calls it.
- **Workplace accidents** "may happen from production at step 3" (law-face 5, Anni's line). Nothing produces them.
- **The law's own staff** "hired and paid by the salary rules … from step 3" (law-face 12, on Wilma's 12.10, 70). Judges and inspectors come from levers and are paid nothing.
- **A company giving more than the minimum raise.** `set_raise_choice` has no caller, so every company gives exactly 2%. No step is named.

## Kept law acts each month that differ from a plan line (not the user's words; from Anni's and Wilma's papers)

- **Licences at step 3.** `may_sign` and `may_open` demand hazard and extraction licences, because both levers default to REQUIRED. Law-face 2 says "Until step 6 … no permit, licence or fee". It does not show today only because FARM is the only type founded.
- **Zoning at step 3.** `may_sign` makes a plan wait in the wrong zone. Nothing zones any land, so it does not show.
- **Fines.**
  - The law's yearly revenue reads the old `pl_ring` fields, which are always empty, so every fine would be the floor only.
  - A fine is taken at once, where the paper says it "is recorded as owed and waits".
  - No fine happens in a default game.
- **The victims' fund** is never paid out to households.
- **The contract case** (`_file_new_cases`) can be filed today, from fields the rebuilt fact does not have. It names the government as the client, a company with an empty id as the builder, and a claim of 0.
- **Land.**
  - Only the colony sells, while the line says "from whoever owns it".
  - The price is a share of the plan's own building bill, not the cells' value.
  - A given-up plan's land stays on the plan, not the founder's (60b).
  - The lease rent is a fixed 0.6% a month, not the bank rate, and a lessee in arrears never loses the lease.
  - Lease code runs from step 3, though the paper puts leases at step 5.
- **Acts with no plan line:**
  - road-accident court cases, always on, which make the treasury or a road company pay into the victims' fund;
  - `amend_constitution` and `home_world_amend` writing levers outside the pipeline;
  - emergency levers going back to their defaults when an emergency ends;
  - a grant programme's end cancelling a level the government had already enacted;
  - the `company_register` snapshot (law-face 1.1 says the law "keeps no copy");
  - job-advert money piling up in the state Gazette, with a fallback to `Ledger.EXTERNAL`;
  - the politics stub paying 5,000,000 credits into an account named "treasury", apart from `gov:treasury`.

The parts follow, as each was read. Each has its own full table, its list of lines that are someone's decision, reading or starting number, and what was built from each.

---


---

<!-- part: part_company_A -->
# Audit part company A: rebuild-company.md lines 1-272 and 792-992 against the code

Tree: commit 0c9e266. `git diff HEAD -- game/sim` is empty, so the working files are the commit. All paths are under game/sim/.
Step numbers are those in plan section 13 (step 3 = the first loop, food only; 4 = items/freight/trucks/services; 5 = money and endings; 6 = building in full, rules 5/6, wear; 7 = homes, noise; 9 = offices, pollution, stress, unions; 10 = exports).

## 1. The user's own words, line by line

| # | Plan ref (line) | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|---|
| 1 | 1 The order (23) | "one object that is the company it's size family to large 4 sizes" | economy/company.gd create(): one record per company for every type; type_table.gd SIZES FAMILY/SMALL/AVERAGE/LARGE | SAME | |
| 2 | 1 (23) | "the nine rules plugged into that" | economy/rules.gd month()/company_month(): one implementation for every OPEN company | SAME (rules 1-4, 7, 9 built; 5, 6, 8 not; see rows 30-37) | |
| 3 | 1 (23) | "the offices as a bonus building" | nothing in sim/economy (company field "office" = "", never written) | NOT BUILT (plan: step 9) | |
| 4 | 1 (23) | "a 2d array of wich items a company type makes, if they pick from first or second output" | type_table.gd ROWS, each row "lines" [first, second]; company "line" fixed 0, no code ever sets it (grep `["line"] =` in sim/economy: none) | SAME for the table; picking NOT BUILT | No rule switches a company to its second output (see row 31) |
| 5 | 1 (23) | "roads and supply networks since the same company can become freight" | no freight in step 3 (company "fleet" [] never written; market.gd: "no freight in step 3, so delivered = posted") | NOT BUILT (plan: step 4) | |
| 6 | 1 (23) | "polution plugg ins to the same" | type_table "pollution" column only; nothing reads it in economy | NOT BUILT (plan: step 9) | |
| 7 | 1 (23) | "Food output plus into the same" | FARM is a row like any other; FOOD an item on the one market (type_table.gd:68, market.gd) | SAME | |
| 8 | 1 (23) | "services have no output but a client take in" | service rows sell "@client" lines (type_table.gd:113-169), not items; is_item() false so they never reach the market | SAME (client intake itself: step 4) | |
| 9 | 1 (23) | "stress for workers reduced output based on workers" | no stress anywhere in sim/economy; making.gd make_plant output = full x level x staffed x condition x season | NOT BUILT (plan: step 9) | |
| 10 | 1 (27) | "building fixes behind off switches is not a valid way to do large scale fixes" | no on/off flag constants in sim/economy (grep) | SAME | |
| 11 | 1 (29) | "You will swich the fixes on one at the time ... run the tests for each" | process rule, not code | n/a | |
| 12 | 1 (31) | "Same company types can come but not their code or balancing" | old type names reused in ROWS; numbers set new (type_table.gd header) | SAME | |
| 13 | 1 (34) | "set a credit prices we are going to have to adjust it anyway" | type_table.gd start_prices(): solved starting prices | SAME | |
| 14 | 1 (40) | "it does not really matter if he does not close ... its not meant too be a perfect economy" | no rescue of private companies in economy (only the purse topping up STATE companies' wages, Landing.purse_month) | SAME | |
| 15 | 3 (83) | price: "No i said each COMPANY" | company.gd rec["price"]: one price per company per thing sold; set_price | SAME | |
| 16 | 4 (101) | "it's just a 2d array of wich items a company type makes, if they pick from first or second output" | as row 4 | SAME / picking NOT BUILT | as row 4 |
| 17 | 4 (110) | "services have no output but a client take in" | as row 8 | SAME | |
| 18 | 4 (117) | "things can be done in two different ways based in company types how its this a problem?" | type_table.gd "way" column {sells, reads, price, reach} per row | SAME | |
| 19 | 4 (133) | "per pupil plus staff is how taxes for schools are calibrated" | no service pricing or tax brackets in sim/economy | NOT BUILT (plan: steps 4 and 8) | |
| 20 | 4 (135) | "noise polution should also drive down price of housing" | type_table "noise" column only; nothing reads it | NOT BUILT (plan: step 7) | |
| 21 | 5 (143) | "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size" | type_table.gd:15 SIXTHS {FAMILY 1, SMALL 2, AVERAGE 4, LARGE 6} | SAME | |
| 22 | 5 (143,147-150,152) | "the output for each is the same but with a small penalty"; "You penalty is fine" (6/4/2/0 %) | type_table.gd:16 PENALTY_PM {60, 40, 20, 0}; output_milli() = qty x sixths/6 x (1000-penalty)/1000 | SAME | |
| 23 | 5 (154-159) | squares: Terra's proposal "This sounds good" (3 km tile, 400 m block, one full size per type) | transport/site.gd choose_country/choose_town/_lay: refuse when square_sixths + sixths > 6, per type | SAME | |
| 24 | 5 (161) | Growing: "in a square if there are other companies they would have to buy out ... or it's too expenvice build a new" | no growing, buy-out or second plant code | NOT BUILT (plan: step 6) | |
| 25 | 6 rule 1 (175) | raise price when it sold out and orders went unfilled | rules.gd price_rule:127 up = step_pm(K_PM, unmet_above, sold); market.gd _turned_away gives SOLD_OUT/NO_SELLER shortfall only to sellers with nothing left at or under the buyer's price | SAME | |
| 26 | 6 rule 2 (176) | "the more inventory you have, the more you reduce your price" | rules.gd:128 down = 50 x s/(1+s) per mille, s = (offered-sold)/sold: larger unsold, larger cut, up to 5% | SAME | |
| 27 | 6 rule 3 (177) | "if you sell out all your producing produce MORE" | rules.gd output_rule:174 up = step_pm(G_PM, unmet, sold) when unmet > 0 (only sold-out sellers get unmet), not while holding back | SAME | |
| 28 | 6 rule 3 (177) | "Also picks first or second output" | no code | NOT BUILT | step 3 is food-only (FARM has one line); the plan does not name a later step for it except "all items" in step 4 |
| 29 | 6 rule 4 (178) and 6 bullet (202) | "The production output is only lowered if over 50% of offered goods is not sold 3 months in a row" | rules.gd output_rule:175 down = step_pm(G_PM, unsold, sold) in ANY month with unsold > 0; no 50% test, no month count | DIFFERENT | Code cuts output every month anything offered is unsold, in the same month as the price cut. User: only if >50% of offered unsold, 3 months in a row; otherwise price falls and output does not move down. |
| 30 | 6 bullet (209) | "A CUT IS 5% ... AND YES IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | rules.gd:190 new_lv = lv - lv x down/1000, down = 50 x unsold/(unsold+sold) per mille, so 0 to 5% (5% only when nothing sold) | DIFFERENT | Code's cut is a variable 0-5% from s/(1+s); the user's cut is a flat 5%, again in a 4th and each further qualifying month. Example: 30% unsold gives a 1.15% cut today. |
| 31 | 6 rule 5 (179) | "if your selling out and all plants at max build a new one ... money is a limitor" | no code | NOT BUILT (plan: step 6) | |
| 32 | 6 rule 6 (180) | "A hard rule here is fine" | no idle-plant closing (close_plant reason IDLE never used) | NOT BUILT (plan: step 6) | |
| 33 | 6 rule 7 (181) | "instead of reading the leftovers, they read an avrage of all avaliable jobs"; no cap | rules.gd work():615 averages Market.history "ordered" (all NEED orders whole, AHEAD only what bought) over the months held; month.gd founding while-loop, no cap | SAME (averaging details: see list 2, 15a reading) | |
| 34 | 6 rule 8 (182) / 15a (836) | "the same signal says the work is covered" | rules.gd founding():653 has only the share test (share >= running cost); no coverage test in quantity | NOT BUILT | The plan (15a line 839) says it was not built before 2026-11-18 and is to be; it is still not built. |
| 35 | 6 rule 9 (183) | "if below making price climbing allways had priority if above lowering has priority ... only the one with priority happens" | rules.gd price_rule:130-132: both > 0 -> R1 if price < making else R2; one signal alone acts | SAME | |
| 36 | 6 rule 9 (183), bullet (196) | "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"; "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP" | rules.gd:46 K_PM := 50; step_pm caps at k both ways; builders' BW price uses the same price_rule (rules.gd:89) | SAME | |
| 37 | 6 bullet (199) | output: "25?! 5!!! CHANGE IT!!! STOP HEDGING" | rules.gd:50 G_PM := 50 (cap 5% up and down); rise at least 1 per mille (Bob's reading) | SAME (for the cap) | |
| 38 | 6 bullet (204) | "Then they cut output instead of lowering price output cut has been built wrong let me guess they just cut if they sell less???" | as row 29: still cuts whenever it sells less than it offered | DIFFERENT | as row 29 |
| 39 | 6 bullet (208) | "That's not going to do anything but delay it one month" (struck reading) | struck reading not built either | SAME | |
| 40 | 6 bullet (187) | "If something else than price stops sales it should not count on adjusting price!!" | market.gd: offers exclude stock "waiting" for freight and hold-back; NO_MONEY orders feed neither unmet nor refused; no freight/road yet | SAME | |
| 41 | 6 bullet (190) | "Ignore the stoch in that other place too" | market.gd offers(): q = qty - waiting - hold | SAME | |
| 42 | 6 bullet (192) and 12.3 14 (798) | hold-back: "It sells too cover all monthly expences" | rules.gd hold_back:155 expenses = wage_bill + this month's booked inputs + booked "upkeep" (never booked anywhere, so 0) | DIFFERENT | Leaves out adverts, layoff pay, debts paid through the court (Justice.paid_this_month) and any land-lease rent; 14 also says repayments included (no loans exist yet, step 5). Upkeep counts 0 because nothing books it. |
| 43 | 7 Office (222) | "if you done have one you lose out on some not all lets say something like 15% less ... one office building should be able to hold 10 plants" | no code | NOT BUILT (plan: step 9) | |
| 44 | 7 Freight queue (224) | "count the work que not passed work"; "That works" | no code | NOT BUILT (plan: step 4) | |
| 45 | 7 Trucks (225) | "fix it yourself in about 4 months or drive to a workship"; "Uses components and resets wear, about 5% are lost reach time" | no code (fleet [] ) | NOT BUILT (plan: step 4) | |
| 46 | 7 Stress (228) | "stress for workers reduced output based on workers" | as row 9 | NOT BUILT (plan: step 9) | |
| 47 | 8.1 (235) | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... THAT'S BEFORE ACCEPTING A GRANT" | month.gd _found_one: Building.make_plan then Grants.apply(plan); company created only in Building.open_due | SAME | |
| 48 | 8.1 (235) | "you can't fail before you exist ... no worker but also no expenses beyond building" | plan record has no staff or wages; plan account pays land and the contract only | SAME | |
| 49 | 8.3 (251) | three endings: sales death in two years, plants shut and cannot replace, bought out | no ending code (no company status other than OPEN is ever set) | NOT BUILT (plan: step 5) | |
| 50 | 8.3 (262) | "Yes they are laied of its loans are payed in full if they can ... the owner is taking to court ..." | no ending code | NOT BUILT (plan: step 5) | |
| 51 | 12.3 15 (809) | k = the user's 5% ("TWENTY PERCENT ... 5% CAP") | rules.gd:46 K_PM 50; step_pm = k x num/(num+den) = k x s/(1+s); den 0 -> full k; num 0 -> no move | SAME | |
| 52 | 12.3 15b (816) | g = the user's 5% ("25?! 5!!! CHANGE IT!!! STOP HEDGING") | rules.gd:50 G_PM 50, mini(1000, ...) never above full | SAME (cap); the cut size see row 30 | |
| 53 | 12.3 15a (862-867) | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | rules.gd founding:667-677 counts SIGNED plans (Building.booked) and MADE plans holding a grant (Grants.granted_plans), by sixths; plain MADE plans not counted | SAME | |
| 54 | 12.3 15a (855) | running cost reads salaries per "fall back to the original rule for settin on hire" (starting salary = 2 x rent) | rules.gd running_cost:637 cost += posts x TypeTable.salary(t) = SALARY_G 300 x tier (300 / 450 / 675 a post) | DIFFERENT | Bob's ruling-backed figure (posts at the area's starting salary, Rules.starting_salary) is not built; still the type table's 300 a post. Same function feeds founder_needs (3 months opening money, building.gd:86). |
| 55 | 12.3 15d (869) | "He should look for the shortest time" | building.gd sign_round:253 sorts quotes by start, then total; signs the soonest its money covers | SAME | |
| 56 | 12.3 15e (872) | "ship food should be considered less desierable, wich would men the swap happens sooner" | market.gd:30 SHIP_LESS_WANTED_PM 250 (ranked a quarter dearer, Wilma's starting number); PRICE order for buyers who cannot cover their need | SAME | |
| 57 | 12.3 15e (877) | family works its own family farm without wages (Wilma's question, user's "Yes, i agree") | rules.gd family_to_posts; Company.family_set; making.gd counts family_count; hire_wanted nets the family; family not on payroll | SAME | |
| 58 | 12.3 15e (881) | "FARMS DON'T SHUT" | rules.gd staff_to_posts:339-347: if wages unpaid, hired staff laid off and `if staff_count(plant) == 0: Company.close_plant(pk, "NO_STAFF")` for any type; staff_count excludes the family; nothing reopens a NO_STAFF plant (reopen_plant only by law) | DIFFERENT | A family farm whose hired hands are all laid off unpaid is still shut, with the family on it, for good; making.gd then skips it. No FARM exception exists. |
| 59 | 12.3 15e (885) | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST ... TAKE SIX OUT OF THIRTY SELL 24" | households.gd post_orders:613-617 Making.family_take(farm, FOOD, need + min(need, 6 x need - held)) before any order; never offered | SAME | |
| 60 | 12.3 15e (893) | "the farm would be their home" (no rent) | landing.gd rent_due:285 returns {} for a founder on an open FAMILY FARM (lives_on_own_farm) | SAME | |
| 61 | 12.3 15e (893-895) | "paying on any loans they had to take and uppkeep to keep it nice" (before winnings) | rules.gd winnings subtracts court debts paid and booked "upkeep"; no loans exist; upkeep is never booked or paid by any code | NOT BUILT (loans step 5, upkeep/wear step 6) | The farm family pays no upkeep at all today. |
| 62 | 12.3 15e (899) | "I think two is better" (loss carried forward) | rules.gd winnings:570-572 loss_carried, pays_down, carried_after | SAME | |
| 63 | 12.3 15e (903) | "maybe the family can put some away for the hard months" | not built; plan notes it for step 4 | NOT BUILT (plan defers it) | |
| 64 | 12.3 15e (912) | "The owners of a family farm should take winnings no sallery, wich comes after" | rules.gd pay_winnings in JUSTICE after debts: rev - inputs - wages - upkeep - adverts - layoff pay - debts, capped at balance - one month's keep | SAME | |
| 65 | 12.3 15f (923) | "they buy 2 units if food instead of one, store it and use it in emergencies" | households.gd post_orders:633 AHEAD order want = min(need - farm_store, 6 x need - held - farm_store); after_market eats store only when bought falls short | SAME | |
| 66 | 12.3 15f (924) | "They stockplie to have have six months of food in storage, i think as often as they can" | households.gd:498 STORE_MONTHS 6; store order every month money allows | SAME | |
| 67 | 12.3 15f (926) | "The first, if your running low ... i don't think you wait" | store order at any price its money reaches (no waiting for price) | SAME | |
| 68 | 12.3 15f (933) | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT" | at most one extra month's need a month (farm take included) | SAME | |
| 69 | 12.3 15c (948) | "they should not cut for the start" | building.gd seller_signal:664 returns {} until first_quote_m set -> no price or output move | SAME | |
| 70 | 12.3 15c (948) | "they should not increase prices for claimed jobs" | building.gd sign_round:291-292: a plan that signs with a start later than month+2 adds its whole BW to the builder's unmet_pending once, in the signing month; rules.gd price_rule raises the BW price on it | DIFFERENT | A job the builder has just claimed (signed, waiting in its book) raises its price once in the signing month (Wilma's decision, not in the user's words); later months do not count it again. |
| 71 | 12.3 15c (955) | "At start id assume they know work is coming" (no crew layoff) | empty signal -> output_rule returns, crew level stays 1000, so staff_to_posts lays nobody off for level (19a unpaid layoffs still possible) | SAME | |
| 72 | 12.3 23a (977) | "if they want to but can't buy, bread goes too high — the company can win by lowering" | market.gd: order max = budget; short orders PRICE (could pay something) -> refused to dearer sellers with stock left -> unsold -> rule 2; NO_MONEY only when max 0, cash 0 or budget 0 | SAME | |

Rows: 72. DIFFERENT: 8 (rows 29, 30, 38, 42, 54, 58, 70; row 38 is the same fault as row 29, so 7 distinct faults). NOT BUILT: 19 (rows 3, 5, 6, 9, 19, 20, 24, 28, 31, 32, 34, 43, 44, 45, 46, 49, 50, 61, 63; rows 4 and 16 are SAME for the table, and their picking part is row 28). Row 34 is the only one the plan says should be built now in step 3; 28 has no step named; the rest are scheduled for later steps).

## 2. Lines in range that are not the user's words

| Line | Whose | What was built | Same as the line? |
|---|---|---|---|
| 4 (124) builder price per BW with materials on top | proposal, Wilma | building.gd quotes: BW x builder's price + supplies at market | SAME |
| 4 (137) types that only held staff go one by one | proposal, Wilma | ROWS have no office/party HQ/business services; SHOP, NEWSPAPER kept as sellers/services | SAME |
| 4 (129) components works trucks always lowest quality | plan's rule (no quote) | no truck quality | NOT BUILT (step 4) |
| 6 rule 6 (180) the idle time; 12.3 16 "twelve months idle" | proposal / Wilma's decision | nothing | NOT BUILT (step 6) |
| 6 (211) no hard floors or ceilings of our own | plan text | output capped at full (rule 5's line); rise min 1 per mille and one post's share (Bob's reading) | SAME |
| 8.1 (243) a plan ends only if its owner gives it up (no builder, no money) | plan text | building.gd sign_round:236-241 gives up on "no builder" AND on "the work is no longer there (rule 7)"; a plan short of money waits instead of giving up | DIFFERENT: an extra ending (rule 7 re-read) not in the line; "no money" never ends a plan |
| 8.1 (241) grant accepted after the plan is made | plan text | month.gd: make_plan then Grants.apply | SAME |
| 8.3 (259) Wilma's readings ("turn the price" = above making price; buy-out = growing) | proposal, Wilma | nothing | NOT BUILT (step 5/6) |
| 15b (813) output step g x s/(1+s) | proposal, Bob | rules.gd output_rule, both ways | SAME as the proposal, but the proposal's cut contradicts the user's rule 4 and "A CUT IS 5%" (rows 29/30) |
| 15b (821) rounding: change computed, cut floored, rise of one post's share, at least 1 per mille | Bob's reading, Wilma's yes | rules.gd:190 | SAME |
| 15a (826-828) work = spent or tried to spend, average of last twelve months, at today's prices | Wilma's decision | rules.gd work(): Market.history ordered qty, divided by the months held (h.size()), x cheapest offer else start price | partly: divides by months held, not twelve |
| 15a (829) twelve months summed and divided by twelve; first-year months count at the grant's need | Bob's reading, Wilma's yes | not built: qty /= h.size(); no pre-colony months at need | DIFFERENT |
| 15a (840) what a plant seen delivers: made less family take, 12 months, unlived months at full; plans at full | Bob's reading, Wilma's yes | not built (no rule 8 coverage at all) | NOT BUILT |
| 15a (849) shares by plant, by size, whoever owns it | Wilma's decision | rules.gd founding: sixths of open plants of the type in companies of that area, plus booked/granted plans | SAME (closed plants are left out; 21's struck plant not applicable yet) |
| 15a (852) test: share covers running cost; largest size that passes and money reaches | Wilma's decision | rules.gd founding covers = share >= cost; month.gd _found_one tries largest first, pick_founder by needs | SAME |
| 15a (854) running cost = posts at area's starting salary, inputs at offers, upkeep | Bob, Wilma's yes | rules.gd running_cost uses TypeTable.salary (300 a post) | DIFFERENT (row 54) |
| 15a (860) founder's management and risk bend the reading | Wilma's decision (12.11, 77) | chief {mgmt, risk} stored at 50/50 on companies; never read; founders have none | NOT BUILT |
| 15a (861) nothing limits how many plan at once | Wilma's decision | while _found_one loop | SAME |
| 15c (952) "the start" lasts until the first plan asks for a quote | Wilma's reading | building.gd first_quote_month, colony-wide | SAME |
| 15e (896) farm is home from the day it opens; before that pays its old rent | Wilma's | landing.gd rent_due: no rent only when the FAMILY FARM company is OPEN | SAME |
| 15e (909) the family's adults fill posts first; the rest hired | Wilma's | Company.family_fill, hire_wanted | SAME |
| 15e (916) winnings for every family-size company | Wilma's | open_due family_set for every FAMILY size; pay_winnings for every company with a family | SAME |
| 15e (917) ship food counted a quarter dearer | Wilma's starting number | SHIP_LESS_WANTED_PM 250 | SAME |
| 15f (938) store after this month's food and rent; spoils; replaces 2-month cap | Wilma's | post_orders store_budget = money - food_cost - rent; FOOD spoils 10 per mille | SAME |
| 14 making price (cost / normal full output; interest in, repayments out) | Wilma's decision | making.gd making_price: (wages_due + inputs + booked upkeep + other=0) / full output of open plants | SAME in form; upkeep counts 0 (never booked); rent/freight/interest are 0 (none exist in step 3) |
| 16 rule 6: twelve months idle | Wilma's | nothing | NOT BUILT (step 6) |
| 17 rule 5 order | Wilma's | nothing | NOT BUILT (step 6) |
| 18 rule 3 not while holding back | Wilma's | rules.gd:174 up = 0 if holding | SAME |
| 19 missing inputs not a price signal | Wilma's | builder: offered = cap - waiting_material; plants: missing inputs make less, so nothing unsold | SAME (rule 6 part not built) |
| 19a cannot pay -> lay off; plant with no staff shut | Wilma's | rules.gd:339-351, in proportion to the unpaid share | SAME, but it shuts farms too (row 58) |
| 19b left out of signals but still pays | Wilma's | every OPEN company pays wages (month.gd settlement); no sales-death clock | SAME as far as built |
| 20 sales death counts only price months | Wilma's | nothing | NOT BUILT (step 5) |
| 21 union shutdown pauses clocks, struck plant counts for rule 8 | Wilma's | nothing | NOT BUILT (step 9) |
| 22 work-slot types do not hold back | Wilma's | builders' BW never goes through hold_back | SAME |
| 23 hunger counted from need | Wilma's | households.gd after_market hunger = need - eaten, split money/price/scarce | SAME |
| 23a short of money vs refusing the price | Wilma's (with the user's bread quote) | market.gd NO_MONEY / PRICE | SAME |
| 24 second output switched month to month, free | Wilma's | nothing | NOT BUILT |
| 25 export counts as sold when aboard | Wilma's | ship.gd: exports "step 10" | NOT BUILT (step 10) |
| 26 no import rule of ours | Wilma's | none | SAME |
| 27 short good shared in proportion, no class first | Wilma's | market.gd _clear_book split_lr by what each order still wants among all orders the offer is next for | SAME |
| 28 nobody hires first, pay decides, no speed limits | Wilma's | rules.gd month() hires company by company in sorted id order (staff_to_posts -> Households.hire), so unemployed go to the first company reached whose pay meets needs; pay decides only for staff quitting to better pay (households.gd labour_month) | DIFFERENT: hiring order is by company id, not by pay |
| 29 upkeep part of the making price | Wilma's | in the formula, but upkeep is never booked, so 0 | NOT BUILT in effect (wear/upkeep step 6) |


---

<!-- part: part_company_B -->
# Audit: planning/rebuild-company.md lines 273–513 (9.1 Households, 9.2 Workers, skills and salaries) against the code

Shared tree at 0c9e266, working files read 2026-11-18. Paths are under `game/sim/`. Money is in milli-credits in the
code (194,000 = 194 credits). Numbers marked "run" were printed by a headless Godot read of `TypeTable.start_prices()`.

## 1. Lines carrying the user's words

| # | Plan ref | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|---|
| 1 | 9.1, L277 | "take it wholesale as long as we make sure it fits in" | households.gd meets companies only through the company record (Company.payroll, staff_change, staff_of_pool, vacancies); it does not reach into any sector's rules | SAME | |
| 2 | 9.1, L278 | "we take how it works and transfer over not take the code" | households.gd / demography.gd are new files ("How the old side worked, written new", demography.gd:4); nothing is imported from game_full_copy | SAME | |
| 3 | 9.1, L284 (how it worked, under 2) | pools per housing block and income band, one account | pools keyed `area|band` (pool_id), one ledger account each; "hb" holds the AREA | SAME | keyed by area, as the verdict table's "keyed by area" row says |
| 4 | 9.1, L286 (under 2) | money in: wages, benefit, pensions, dividends to owners, the self-employed's earnings, migrants' savings | pay_wages (households.gd:423), pay_support benefit/pension (:456), settlers bring band savings (land_settlers); family winnings (Rules.pay_winnings) | NOT BUILT (part) | dividends to owners not built (owners' money is build step 5); self-employed removed by the verdict table |
| 5 | 9.1, L288 (under 2) | money out: food; rent; water and power; other essentials; then goods, services, comfort, papers, saving; orders a month ahead; short = less of each | post_orders (households.gd:598): food budget = all money; rent paid after the market (pay_rent :811); the store order from what food and rent leave. Food is the only item | NOT BUILT (part) | water/power, other essentials, goods, services, comfort, papers, saving: not built (step 4, "all items"). "Less of each" has only one item to act on |
| 6 | 9.1, L291 (under 2) | life: ages 0–99; births women 18–42, fewer with income, schooling, density, crowding, hunger; deaths by age, worse with poor clinic access and famine; grow up at 18 with tier by schooling; retire at legal age; return to labour force | demography.gd: AGES 100, FERT_LO 18 / FERT_HI 42, TFR_BASE 4.0 falling 40% with income, hunger and crowding; MORTALITY_PM table, HUNGER_MORT 4.0/2.0, CROWD_MORT 1.0; retire at the law's lever; REENTRY_PM 10 a month | NOT BUILT (part) | no clinic term in deaths; no schooling term in births; everyone grows up at the general tier (no schools yet, demography.gd:11) |
| 7 | 9.1, L294 (under 2) | beyond 130% nobody squeezes in; shacks or homeless, more deaths, fewer births, fires | Households.homes: fit = homes × 1300/1000 (households.gd:547); homeless = households above that; crowding raises deaths and lowers births | NOT BUILT (part) | "shacks" is always 0 and there are no shack fires (homes are step 7) |
| 8 | 9.1, L296 (under 2) | settlers on each ship, more when attractive; jobless young adults and homeless families leave | land_settlers / attractiveness (households.gd:1700ff); departures: unemployed Y-band × LEAVE_PM 100‰ × (1 − attractiveness), and all homeless households | SAME | |
| 9 | 9.1, L302 | "Oh no wholesale does not mean unchecked" | a process rule (Maja's line-by-line check before step 3); nothing in code to compare | n/a (process) | |
| 10 | 9.1, L308 | pools: "That's fine" | as row 3 | SAME | |
| 11 | 9.1, L312 | "ONE kind of thing that produces" (self-employed removed) | no self-employed status, income or selling anywhere in households.gd / demography.gd | SAME | |
| 12 | 9.1, L314 | "what are you paying power and water on if you can't pay the rent?" → food, then rent, then water and power | food budget first (all money), rent second (rent set aside before the store, paid in SETTLEMENT 5) | SAME (food, rent) / NOT BUILT (water, power) | no water or power bill yet (no grid until step 4) |
| 13 | 9.1, L316 | "No hard floors or ceilings of our own" | no price floor or ceiling in households.gd; demography.gd:10 "No clamp of ours"; the only clampi in households.gd (:1565) bounds a head count to what exists | SAME | |
| 14 | 9.1, L332 | "Housholds follow terras latest plan" | homes = AreaStore.capacity (Terra's cells), pools keyed by area | NOT BUILT (part) | a home's worth and what a household wants near it are not read (9.8, homes at step 7) |
| 15 | 9.2, L337 | "Workers and sallery, skills and swapping jobs to better payed, actually the three rules for price should be applied here too" | posts ask a tier (G/S/Sp), hire takes that skill or higher, never lower (Households.hire :202); quitting for better pay (labour_month :1023). The three rules are replaced for salaries by the 2026-11-18 ruling (row 26–29) | SAME (as superseded) | |
| 16 | 9.2, L342 | "the sallery is not fluent, they have a sallery set on hire then it climbs based on yearly upps set by goverment" | pay written into the hire row at hire (Company.staff_change :241); changed afterwards only by yearly_raise (company.gd:422), negotiate (:722), or moving job (move_job) | SAME | |
| 17 | 9.2, L347 / L500 | "that's fine for hiring" | only the hiring offer moves (Rules.salary_rules, Company.set_hiring_salary); nobody's pay is touched | SAME | |
| 18 | 9.2, L352 | "10% if it's a good job less if stressfull, and plus 1% per year in the same workplace up to 15%" | households.gd:993–996: QUIT_BAR_GOOD_PM 100, QUIT_BAR_PER_YEAR_PM 10 per full year of the hire row's "since", QUIT_BAR_MAX_PM 150 (caps the whole bar); clears_bar new×1000 ≥ old×(1000+bar) | SAME (10/1/15) / NOT BUILT ("less if stressful") | quit_bar_base_pm always returns 100; stress is step 9 (plan schedules it) |
| 19 | 9.2, L362 | "underpayed workers go to the union, they can quit if they think they can get better prices if not they may unionise" | quitting: SAME (labour_month). Union: nothing in households/economy reads underpayment for a union | SAME (quit) / NOT BUILT (union) | unions are build step 9 |
| 20 | 9.2, L369 | "avrage ask salleries in the company and underpayed is based on that line, that way both old and new can become underpayed" | Company.avg_pay(cid, post_tier) (company.gd:708): head-weighted average of the hire rows of ONE TIER; _negotiate compares each row with it | DIFFERENT | the line is the average of the same tier (G, S or Sp), not of the salaries paid in the company (the proposal at L423 narrowed it) |
| 21 | 9.2, L373–376 | "contracts should have clauses for payment after fire ... say three months of vages" (ruled: "you have the right of it") → owed three months of own pay | Households.layoff (:257): owed = persons × their hire row's pay × WorkLaw.layoff_pay_months; LAW_LAYOFF_PAY_MONTHS default 3, range 0–12 (law_data.gd:497, work_law.gd:28) | SAME (3 months, own pay, a law lever) | |
| 22 | 9.2, L376–377 (ruled) | "It is part of the contract set on hire" | the months are read from the law on the day of the layoff (households.gd:268, "the law on the day"); nothing is stored on the hire row | DIFFERENT | if the law changes, workers hired under the old law are owed the new number of months, not the number in force when they were hired |
| 23 | 9.2, L379 (ruled) | cannot pay → a debt like unpaid wages, can end the company | rest owed through Justice.owe kind LAYOFF_PAY (households.gd:327), collected by collect_debts | SAME (debt) / NOT BUILT (ending) | ending a company is step 5 (plan schedules it) |
| 24 | 9.2, L380 (ruled; user: "costs of hiring") | hiring costs an advert, paid to a newspaper | Rules._advertise → Media.job_advert: ADVERT_PM 100 (a tenth of the hiring salary) per post, transferred to the papers circulating in the district (media_ops.gd:916–982) | SAME | with no paper circulating in the district, job_advert_cost returns 0 and hiring costs nothing (media_ops.gd:950) |
| 25 | 9.2, L382 (ruled; user: "maybe 6 months training") | a new hire produces less for six months | Company.TRAIN_MONTHS 6, TRAIN_START_PM 500, trained_pm(a) = 500 + 500·a/6; Making reads trained_count (making.gd:64), builders' BW too (home_builders.gd:88) | SAME | |
| 26 | 9.2, L383 | "where they can't fire" replaced by training (user accepted) | no firing ban anywhere | SAME | |
| 27 | 9.2, L373 | "articles in the newspaper" (on layoffs) | Rules._publish_layoffs → EconPublish.layoffs, once a month per company with layoffs | SAME | |
| 28 | 9.2, L373 | "weigh say three months of vages without a worker against the profits" | Rules.layoff_weighing (rules.gd:472): lay off if idle × pay > months × pay + advert + training loss | SAME | |
| 29 | 9.2, L374 / L385 | "it should apply to builders" | builders' crews: placed/trained, layoff pay, adverts, the weighing all run through the same code | DIFFERENT (one part) | in the weighing the training loss is read at Company.price(cid, "@BW"); a builder's price is kept under "BW" (company.gd:936 _sells_key), so the price is −1 → 0 and a builder's training loss is always 0 |
| 30 | 9.2, L407 | "On posts when you many an open post you pay the first time not every consecutive month after" | Rules._advertised / _advertise (rules.gd:419–450): a post is paid once when it opens; still-open posts stay paid; a filled or no-longer-wanted post is dropped and paid again if it reopens | SAME | |
| 31 | 9.2, L415 | "the manager, negotiation can bring it closer to avrage" | Households._negotiate (:1072), in month NEGOTIATE_MONTH 7: a row below the tier average asks halfway; granted if the account holds 12 months of the rise; Company.negotiate refuses above the average or a cut | DIFFERENT | no manager enters: the chief's management skill (Company.chief) is never read; the result is always halfway or nothing, by the account alone; and the average is the tier's (row 20) |
| 32 | 9.2, L432 | "avrage living in the area and food plus half of both again" (1.5 × (rent + food)) | replaced by "2× rent" (row 37); TypeTable.salary_line (type_table.gd:395) still holds the old formula but nothing calls it | SAME (as superseded) | |
| 33 | 9.2, L433 | "On sallery it's an avrage of the area" | Rules.area_rent (rules.gd:282): plain average of the open landlords' "@home" price in the area; none → shelter at half a new home | SAME | |
| 34 | 9.2, L439–444 (rule 1) | "fall back to the original rule for settin on hire" | Company.hiring_salary returns Rules.starting_salary when no climb is stored (company.gd:378) | SAME | |
| 35 | 9.2, L439–446 (rule 2) | "only climb max 5% if it cost not hire for one month", "5% each month" | Rules.salary_rules: OFFER_CLIMB_PM 50; a post left open after last month's hiring and still open now climbs the offer × 1.05, again each month (compounding on the climbed offer) | SAME | |
| 36 | 9.2, L439, L447–448 (rule 3) | "increases should not stack for seperate offers" | the climbed offer is ONE number per company, tier and area (c["salary"][tier][area]); it falls back only when NO post of that tier in that area has waited a whole month | DIFFERENT | it is not per post: a new opening made while another post of the same tier and area has waited a month is offered the climbed salary, and if the climbed post fills while another has waited a month the climb carries on from the climbed figure instead of restarting |
| 37 | 9.2, L441, L449 (rule 4) | "i never said i wanted the rule for lowering" | no lowering of the hiring offer anywhere (only climb or clear) | SAME | |
| 38 | 9.2, L452–455 | "a 2d array to keep all things about the hires? Sallery start date so forth?" / "You can merge if all rows match" | staff entry {"n", "hires":[{n, pay, since, train}]}; _row_key = pay|since|train-left; _tidy merges only identical keys (company.gd:326–347) | SAME | |
| 39 | 9.2, L458 | "Record it make them pay after our if they refused take it to court" | pay_wages owes the short part per pool as Justice.owe kind UNPAID_WAGES (households.gd:440–445); collect_debts pays it when the company has money | SAME (record, pay after) / NOT BUILT (court) | the court is step 5 (plan schedules it) |
| 40 | 9.2, L464–466, L472 | "just rent at 2×", then "2", "Merge with 2" | Rules.STARTING_RENT_PM 2000; starting_salary = area_rent × 2 × tier share (1, 1.5, 2.25). Landing: 2 × 96,978 = 193,956 (194) for G (run) | SAME for hiring / DIFFERENT elsewhere | Rules.running_cost (rules.gd:637, rule 7/8 "posts at the starting salaries") uses TypeTable.salary = SALARY_G 300 (450, 675), not 2× rent; Landing.support_rates (landing.gd:196, benefit and pension "per cent of the area's starting salary") also uses TypeTable.salary("G") = 300 |
| 41 | 9.2, L468 | "3 5x housing try it" | a trial; superseded by "2" | SAME (as superseded) | |
| 42 | 9.2, L478 | "The build crews at start should not be hiring at all. They should start with a job already active." | HomeBuilders._make → Households.hire(..., trained=true, placed=true): no needs test, no advert, trained; also the public works department | SAME | |
| 43 | 9.2, L483 | "Place the goverment staff from startb with the builders and lets set their sallery at 2.5 from start same for builders" | Landing._crew (landing.gd:166) places administration, housing office, Colony Stores; Rules.PLACED_RENT_PM 2500; placed_salary = area_rent × 2.5 × tier share. G: 242,445 for builders/admin (placed before any landlord: rent fallback 96,978), 242,500 for housing office and stores (shelter rent 97,000) | SAME | |
| 44 | 9.2, L492 | "Screw lowering food, double the rent" | TypeTable.HOME_RENT_PM 2000 on homes only: new home 193,957 (run); Landing.SHELTER_RENT 97,000 | SAME (97→194, 48→97) | |
| 45 | 9.2, L497 | "10 purple each" | FARM row: qty 240, lab 18+5+1 = 24 (type_table.gd:68): 10 per worker at LARGE; FOOD start price 39,431 (run, "about 39") | SAME | smaller sizes lose the size penalty (FAMILY 37.6 food from 4 posts = 9.4 each), which is section 5's rule |
| 46 | 9.2, L501 | "The district the plant hiring is in." | hires through Rules: pay at Households.plant_area (households.gd:187–194); climb keyed by plant area (salary_rules) | SAME for hires / DIFFERENT for job moves | Company.vacancies (company.gd:643) lists posts by the COMPANY's area and prices them at hiring_salary(company area); move_job pays that figure. A plant standing in another area is offered to movers at the company area's salary (and only to workers of the company's area) |
| 47 | 9.2, L504 | "every year a company can grant a bonus what the minimum of this is is up to the government, 2% is a good start" | yearly_raise_month (households.gd:1094): January, from the first new year; ECON_YEARLY_RAISE_MIN_PCT default 2, range 0–20 (econ_publish.gd:59); raise = max(company choice, minimum) | SAME (minimum 2%, yearly) / NOT BUILT (a company giving more) | Company.raise_choice is the record's raise_pm, 0; set_raise_choice has no caller, so every company gives exactly the minimum |
| 48 | 9.2, L506 | "But emplyees only apply to jobs that meet their needs" | Households.hire: pay < needs_line → no applicants (households.gd:196); applicants() the same; the placed are exempt (rows 42–43) | SAME | |

Counts: 48 rows (1 of them a process rule, n/a); DIFFERENT 7; NOT BUILT (whole or part) 11.

Note on counting: rows that are partly SAME and partly DIFFERENT/NOT BUILT are counted under the worse verdict. DIFFERENT: 20, 22, 29, 31, 36, 40, 46 = 7. NOT BUILT (whole or in part): 4, 5, 6, 7, 12, 14, 18, 19, 23, 39, 47 = 11. Of these, 4, 5, 7, 12, 14, 18, 19, 23, 39 are scheduled by the plan for a later step (4, 5, 7, 9); 6 (clinics, schooling) is tied to services (step 4); 47 (a company choosing more than the minimum) has no step named.

## 2. Lines in the range that are a decision, reading, proposal or starting number (not the user's words)

| Plan ref | Whose | The line | What was built | Same as the line? |
|---|---|---|---|---|
| L304–327 verdict table (except the quoted cells) | Wilma's first pass, Maja's check | keep/change/remove per old mechanism | owners counted one by one (founder table): SAME; count per company (Company.staff_of_pool): SAME; household pays the shop's price: SAME; home-world emergency rations: none, SAME; 10% unemployment gate for migrants: none, SAME; keyed by area: SAME; deaths from wildlife, storms, road accidents taken from outdoor workers first: not built; household pollution: not built; numbers "set new": SAME | mostly SAME; two "keep" rows not built |
| L355 | Wilma's reading | "up to 15%" caps the whole bar | QUIT_BAR_MAX_PM 150 caps base + years | SAME |
| L357 | Wilma's starting numbers | bar 10% until stress; toward 5% at highest stress | QUIT_BAR_STRESSED_PM 50 defined, unused; base 100 | SAME (stress not yet built) |
| L359 | plan | record keeps how long each group has been there | hire row "since" | SAME |
| L376–385 | Wilma's proposal, made rule by the user's "you have the right of it" | three months, advert, training, builders | see rows 21–29 | as rows 21–29 |
| L386–389 | Wilma's starting numbers | 3 months; advert a tenth of a month's pay per person hired; half output first month rising evenly to full after six | 3 (lever default); ADVERT_PM 100 per post; TRAIN_START_PM 500, TRAIN_MONTHS 6 | SAME (advert now per post opened, by the later ruling at L407) |
| L391–394 | Bob's proposal | training per monthly hire group, 1.75 months lost; a move within the workplace brings no training | train month per hire row; loss sums to 1,750‰; a band move keeps the row's training (staff_move); a move to another company trains | SAME |
| L395–398 | Bob's proposal | idle = run of slack months, at least 1, reset when posts want as many as it has | Rules._slack: idle = month − start + 1; erased when w ≥ have | SAME |
| L399–402 | Bob's proposal | weigh per person "at the tier's pay of the entry laid off first"; advert a tenth of the hiring salary; 1.75 × output × price | pay = head-weighted AVERAGE pay of all rows of that tier at that plant (rules.gd:476–480), not the first-laid-off entry's; advert and training as written (training 0 for builders, row 29) | DIFFERENT (pay used; builders' training term) |
| L403–404 | Bob's proposal | 19a layoffs not weighed, owed layoff pay as a debt | 19a branch lays off in proportion with no weighing; Households.layoff owes the pay | SAME |
| L405–406 | Bob's proposal | cannot pay all adverts → hires none that month; pays for those hired | replaced: adverts paid when posts open, for as many posts as the money reaches (Otto's review, the user's L407 ruling) | DIFFERENT from the proposal (superseded by the user's ruling) |
| L411–412 | Wilma's reading | advert paid in the month the post opens, hired or not; reopened post paid anew | as written | SAME |
| L413–414 | Bob's proposal | each layoff decision row carries idle, pay, months, advert, training, price; keeping slack logged | LAYOFF why and RULE "keeps its slack staff" rows carry all six | SAME |
| L418–422 | proposal (Wilma's) | once a year, before quitting or union; depends on the manager and whether the company can pay; never above the average, never lowers; failure leaves the worker as before | month 7, before quitting in labour_month; can pay = account ≥ 12 months of the rise; halfway fixed; refuses above average or a cut | DIFFERENT (the manager does not enter) |
| L423–424 | proposal | average taken per kind of post | avg_pay per tier | SAME as the proposal (which differs from the user's words, row 20) |
| L426–430 | proposal | signal lines for salary rules 1, 2, 9 | superseded; no R1/R2/R9 on salaries in code | SAME (removed, per L449) |
| L469 | Wilma's reading | "3 5x" = 3.5 × rent, a trial | trial only; 2 merged | SAME |
| L485–486 | Wilma's reading | 2.5 × the rent × the tier's share | placed_salary | SAME |
| L487–488 | Wilma's reading | later openings at those companies get the starting salary (2×); 2.5 only for those placed at the start | only landing calls pass placed=true; Rules hires use hiring_salary | SAME |
| L497 | Wilma's reading | "10 purple" = 10 people | FARM 240 / 24 | SAME |
| L509–510 | proposal | "their needs" = housing and food where they live | Rules.needs_line: cheapest landlord rent in the area + cheapest FOOD offer (else last sold, else start) × 2.5 | SAME (with no landlord in the area it falls back to a NEW home's rent, 193,957, while area_rent falls back to the shelter's half) |
| L511–512 | Wilma's carrying over of the price ruling | an open post with no housing near or nobody with the skill is no reason to raise the salary | salary_rules climbs for any post open a whole month, whatever kept it open | DIFFERENT (the user's later L439 rule "if it cost not hire for one month" is what was built) |
| L474 | plan statement | at the landing 194 against 196 needs, so a new opening climbs 5% once before anyone applies | starting 193,956; needs 97,000 + 39,431 × 2.5 = 195,577; one climb → 203,653 | SAME |
| L499 | plan statement | starting food price about 39 where it was 60 | 39,431 (run) | SAME |

Not in my range but met on the way (for the owners of those sections): family winnings are taken in JUSTICE after debts with the loss carried (Rules.winnings); the household store buys at most one month's need extra a month toward STORE_MONTHS 6 (households.gd:498, 633).


---

<!-- part: part_company_C -->
# Audit, part company C: planning/rebuild-company.md lines 514–791 and 993–1423 against the code (shared tree at 0c9e266)

This is a read-only audit. No repo file was edited. Paths are under `game/sim/`. Step 3 is the current build step.

## 1. Lines with the user's words

| # | Plan ref (line) | The user's words (short) | What the code does today | Status | What differs |
|---|---|---|---|---|---|
| 1 | 9.3 (519) | "Company and people should be able to stock up if the price is low" | Companies: `Making.post_orders` (economy/making.gd:202-210) posts an AHEAD order up to two months' need held, only for inputs spoiling under 50‰ a month (KEEPS_PM 50). Households: `Households.post_orders` (population/households.gd:629-650) posts an AHEAD food order toward STORE_MONTHS=6, at most one month's need a month. | SAME | – |
| 2 | 9.3 (521-522, plan paraphrase) | "What they bought ahead they do not buy later" | Companies: want = need − held (making.gd:194). SAME. Households buy the month's food whole every month and eat from the store only when short (households.gd:584-586, after the user's later 15f ruling). | DIFFERENT (households only; explained by the user's later 15f ruling) | A household that holds a store still buys its full month. The paper line was not updated. |
| 3 | 9.3 (523) | "No what's low should be against what its worth to the buyer, like when they buy normaly" | Companies: worth = `Making.input_worth` (making.gd:217-234), the same max price as the ordinary order. Households: the food worth is the whole food budget (households.gd:619-620). | SAME | – |
| 4 | 9.3 (524-526, plan paraphrase of 3) | "A price is low when it is under that worth. The further under, the more reason to buy ahead." | Companies stock up only when the cheapest offer ≤ 800‰ of worth (AHEAD_BELOW_PM 800, making.gd:22,207, marked "Bob's proposal"). The amount is fixed (top up to 2 months) and does not grow with the discount. Households' store buys at any price the leftover money pays (user 15f). | DIFFERENT | Code uses a 20% discount cut-off, not "under worth". There is no grading by how far under. |
| 5 | 9.4 (538; the user's ruling "no limits from past sales") | "lends on orders, contracts and forecasts, never on a limit from last month or last year" | No bank, no lending anywhere in economy/. No credit cap from past sales was found. Rule 7's 12-month average is the founding signal (user 15a), not a credit limit. | NOT BUILT (later step 5) | – |
| 6 | 9.5 (545) / 9.12 (655) | "the goverment starts with its subsidiaries as before" | economy/landing.gd:47-51,105-118: POWER, WATERWORKS, TRANSIT, CLINIC, SCHOOL, POLICE (state, no plant, no staff); ADMIN LARGE as a working crew; Housing Office LANDLORD (shelters); Colony Stores SHOP. home_builders.gd:35,57: Public Works BUILDER AVERAGE (state). | SAME | – |
| 7 | 9.5 (545-547) | "All company types needs to be able to be created as private, but ... the conitions for new ones don't get switched on" | Rules 7/8 (`Rules.founding`, rules.gd:653) are generic, but month.gd:27 `FOUNDABLE = ["FARM"]`: only farms can be founded (step 3 "tested first on food alone"). | NOT BUILT (later step 4) | No private power/water/etc. can be founded yet. |
| 8 | 9.5 (548) | "per pulpe plus staff is how taxes for schools are calibrated Yea they all get tax brackets" | No taxes or brackets anywhere in economy/. | NOT BUILT (later step 8) | – |
| 9 | 9.5 (550-551) | Grants only family farms, bakeries, truck drivers, workshops; "I DID NOT SAY GIVE EVERYONE ... GRANTS"; "No split trucks and workshops" | grants.gd:53-58 KINDS = FARM, BAKERY, TRUCKER (HAULIER), TRUCKSHOP, each FAMILY size and each its own lever. `kind_of` returns "" for every other type. | SAME | – |
| 10 | 9.5 (553) / 9.9 (629) | "the goverment can lean on companies if they don't comply or on the union" | Nothing in economy/ or politics for this. | NOT BUILT (later step 9) | – |
| 11 | 9.5 (554; user 9.2 "2% is a good start") | Levers include the yearly-bonus minimum | econ_publish.gd:59 ECON_YEARLY_RAISE_MIN_PCT, range 0-20, default 2. Read by households.gd:1097 (`yearly_raise_month`, January, not in landing year). | SAME | – |
| 12 | 9.6 (560-561) | "They can't order when there's not a ship there ... the full period of waiting every time." | ship.gd:167-194 `Ship.order` refuses "no ship in port". The order rides that ship (`taking`→`bringing`) and lands on its next call (`_leave` line 73, `_arrive`). Payment is on the dock at arrival. | SAME (mechanism) | – |
| 13 | 9.6 (563) | Nothing enters or leaves except on a ship in port | Settlers and their savings come in `Ship._arrive` (ship.gd:90-94, households.gd:1761). Imports are paid to EXTERNAL on the dock (ship.gd:121). Month-one money (LANDING_TREASURY 2,000,000; LANDING_CAPITAL; LANDING_SAVINGS) comes with the landing ship. No other EXTERNAL inflow is in economy/ or population/. | SAME | – |
| 14 | 9.6 (564) | The full round trip every time | ship.gd:73 next call = month−1 + drawn interval (EconFace.trade_ship_interval). A ship leaving this month cannot return this month (line 56-63). | SAME | – |
| 15 | 9.6 (565-567) + 13 step 3 (1272 "orders to the home world") | A company or the government can order from the home world when a ship is in port | `Ship.order` exists but nothing calls it: a grep of game/sim finds no caller. No company ever orders. Government ordering is deferred to step 8 (ship.gd:19). | NOT BUILT (should be in step 3) | Plan 13 puts orders to the home world in step 3. The code has the function but no buyer uses it. |
| 16 | 9.6 (569-570) | "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR" (no backstop rule on imports) | `Ship.order` refuses only for no ship, bad item, or full hold (HOLD_START 3000 units a call, START). There is no monthly cap and no "backstop" condition. | SAME | – |
| 17 | 9.6 (571) | Exports are stock put on a ship | None (ship.gd:20, export_value 0). | NOT BUILT (later step 10) | – |
| 18 | 9.7 (577) / 9.12 (655) | "5 building companies and alot of oppretunity" | home_builders.gd:33-34: five home-world builders (1 LARGE, 2 AVERAGE, 2 SMALL), owner HOME_WORLD, crews placed and trained. | SAME | – |
| 19 | 9.7 (578-579) | "They should not need 90% of supplies up front they should need 3 months up front and add 1 month of additional supplies every month" | building.gd:43 UP_FRONT_M=3. `supply_orders` (388) keeps 3 months' need on site, topping up each month. `_ready` (504) lets a job start only with 3 months on site (or the rest of the bill). | SAME | – |
| 20 | 9.7 (580, plan line on 9.12 words) | A builder quotes a start date; a plan knows the wait before it signs | building.gd `quotes`/`start_month` (191-216). `sign_round` takes the earliest start, then the lowest total. | SAME | – |
| 21 | 9.8 (591-595) | Terra's grid accepted: "This sounds good" (3 km tiles, 100 m cells, 8 plots, 400 m blocks, 50 homes ≈ 6-7 house cells / 1 apartment / ¼ tower) | transport/town_grid.gd:24-52: PER_TILE 30 (3 km/100 m), HOUSE 8 homes/cell, APARTMENT 60, TOWER 200, BLOCK_CELLS 4 (400 m). 50 homes = 6.25 / 0.83 / 0.25 cells. | SAME | – |
| 22 | 9.8 (594) | "Below 250 start a gridd anyway and only use what you need" | town_grid.gd:18-20 and ensure_town (854): a town gets its grid with its first building. | SAME | – |
| 23 | 9.8 (598-599) | "the closer to the coast you get the more expensive they get; it can even shift from road to road." | town_grid.gd value parts include view (0.3 km) and water/shore (1.0 km), road and fast road, per 100 m cell (VALUE_PER_POINT 100‰, min 300‰). Land price reads it (site.gd:394). Rent by cell value is not built (step 7). | SAME (cell value) | – |
| 24 | 9.8 (613) | Wear below 55: "that's what changed rent levels for the landlord" | No home wear and no condition factor on rent. "upkeep" is never booked by any code. | NOT BUILT (later step 7) | – |
| 25 | 9.8 (615-616) | "I belive you should be able to buy your house out ... the 1/6 of a farm for that" | None. | NOT BUILT (later step 7) | – |
| 26 | 9.8 (621) | "That's fine" (top band moving out a few at a time) | None. | NOT BUILT (later step 7) | – |
| 27 | 9.8 (624-625) | "If you own an appartment there is a fee for uppkep to the landlord ... a community and they all pay together" | None. | NOT BUILT (later step 7) | – |
| 28 | 9.9 (629) | Union quote: started from one company; others join; small fee; protests/shutdowns lasting while the union can pay; "the workers get 2/3 normal sallery" | No union in economy/ or population/. Only law/union_law.gd lever reads exist (old spec). | NOT BUILT (later step 9) | – |
| 29 | 9.9 (633-634) / 9.2 | "underpayed workers go to the union ... if not they may unionise" | None. | NOT BUILT (later step 9) | – |
| 30 | 9.12 (655) | "...and all three grant types open, and no sectors beyond landfallpoint..." | All four grant levers default 50% (econ_publish.gd:37,63-70). Each opens a programme in month one (grants.gd:378-381). One area at the landing (landing.gd:78, AreaStore.found_landing); no districts laid out. | SAME | – |
| 31 | 9.12 (660) | "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE" | All four open from month one at 50%. Caveats: a grant pays only once the government has set the sum and the cover (gov_builder.gd:542-580). Without a politics state no sum is ever set, so `sum_left` = −1 and every grant is refused (grants.gd:180-182). The sum is chosen only for districts with need > 0. | SAME | – |
| 32 | 9.12 (666) | "materials come with the start not finished buildings 5 years worth of equipment that never changed they are companies from the world ... do you place out fucking plants from start" | No farm, mine or factory at landing. Subsidiaries have no plant (landing.gd:105-110). landing.gd:58 STOCK = MATERIAL 9700, COMPONENT 1060, TRUCK 20, FOOD 12000. Bob's reading: 5 years of the five builders' work (≈176.8 BW/month × 60 ≈ 10,600 BW; the farm bill uses 1 MATERIAL per BW, so ≈4.6 years at that ratio). Builders owned by HOME_WORLD. Exception: the landing shelters are finished buildings (row 45). | SAME | – |
| 33 | 9.12 (673-674) | "no the old system and the new for five years are not the same" | Builders land with BUILDER_CAPITAL_MONTHS = 3 months of wages (landing.gd:60,99), not five years of running costs. | SAME | – |
| 34 | 12.5, 35 (1008-1009) | "On company owners, they should become individually counted on company start ... but don't malt to many people to track" | `Households.make_founder` (households.gd:1199-1245): a "founder:N" record with its own account, made when the plan is made (month.gd:155). For a family size the whole household goes with it as BUSINESS_OWNER under that one record. Everyone else stays in pools. | SAME | – |
| 35 | 12.9, 61a (1112) | "when a grant ends, they reset to zero so they have to start over on where to put it; grants should be limited time for when you can apply" | grants.gd:48 PROGRAMME_M 24. At its end `LawOps.end_programme` sets the lever to 0 (387-389). gov_builder.gd:561 drops the cover and the sum when the lever is 0. A new programme needs the lever raised again. | SAME | – |
| 36 | 12.9, 61a (1113) | (2026-11-15) the government starts over on its level "and where it covers too" | Cover erased on lever 0 and chosen afresh (gov_builder.gd:556-562, 573+). | SAME | – |
| 37 | 12.9, 61b (1119) | "The government should put a max sum into the grant based on how many darms they want maybe a little extra to be sure" | `Grants.wanted` (248-263): farms wanted = (food need of buyers − output of standing and planned farms) ÷ a family farm's full output, rounded up. Sum = wanted × largest area grant × 1.1 (EXTRA_PM 100). It is set once when the programme opens (gov_builder `_grant_sum`). `apply` refuses when what is left < a grant (grants.gd:180-185), and `quote` returns 0 (141). | SAME | – |
| 38 | 12.9, 61b (1127, plan line) | "A founder who can pay without a grant is not stopped by it" | `pick_founder` (households.gd:1131-1160) admits households whose own share covers the needs with grant 0. | SAME | – |
| 39 | 12.11 (1164) | "I think most of these needs to be worked in" | Points 77-109 are placed in the paper. Almost none are in code (see list 2). | NOT BUILT (later steps) | – |
| 40 | 13 step 4 (1277-1289) | Farms away from towns / grant spot: "Can we add a prefernce for farms not being close to towns ..."; "Save it for when trucks and roads come Mark it for then"; the four answers | No grant spot; grant cover is by district (gov_builder). `Site.choose_country` (transport/site.gd:139-185) scores distance from the nearest settlement as a minus, so farms are placed close (the pre-existing siting). | NOT BUILT (later step 4) | – (as ruled: not before trucks and roads) |
| 41 | 13 step 8 (1301) | "Mark that the government can order stockpiles to help in famin once we get back to politics" | Nothing built (no government stockpile order; no emergency rations either). | NOT BUILT (later, politics) | – |
| 42 | 13 (1309) | "Get everyone involved ... atleast one other reviews each peace of code made" | Process, not code. Recent commits carry a named reviewer (0c9e266 "Otto, reviewed by Maja", 2111905, a66664a, 9e18bf8). | SAME (process) | – |
| 43 | 13 (1321) | "Can we have a backend column somhere that records all things happening like a log we can investigate from?" | core/logbook.gd: note/rows/counts/story/write/trim/clear. Kept on world.log_rows; not saved or hashed; keep_months. Rows are written by market, making, rules, building, grants, ship, landing, households. | SAME | – |
| 44 | 13 "to watch" 8 (1394-1396) | "Plans are NOT counted as companies in rule 7's shares; the user ruled that out as protecting companies from failing" | `Rules.founding` (rules.gd:653-686) counts plans booked on a builder and MADE plans that have a grant in `have`, as plants of their size. | DIFFERENT | The code follows the user's later words in 12.3 15a ("they do see plans booked on builders notes and plans that have accepted grants"). Paper line 1395 is stale and contradicts it. |
| 45 | 14 (1414) on 9.12 "not finished buildings" | "not finished buildings" | landing.gd:123-146 `_shelters` lays finished LANDLORD blocks of 50 homes, one home per founding household, rent SHELTER_RENT 97. | DIFFERENT | Finished shelter homes stand at landing. This is Wilma's decision 12.2/11, flagged in §14 and not struck by the user. |

## 2. Decision / reading / proposal / starting-number lines (no user words behind them)

| Plan ref (line) | Whose | What was built | Same as the line? |
|---|---|---|---|
| 9.3 (527) "how much: as far as its money reaches and the goods keep" | proposal | Companies are capped at 2 months' need held, for inputs spoiling < 50‰ (making.gd:204-207). Households go up to 6 months of food (food spoils 10‰/month) under the user's 15f ruling. | DIFFERENT: a cap in months, not money. Households stock food far ahead. |
| 9.3 (529-534) AHEAD buys only what NEED leaves; it counts as spending for rule 7; its shortfall is not unmet demand | Wilma's decision | market.gd:157-161 (NEED first, then AHEAD), 225-226 (only NEED turned away), 338-342 (AHEAD in "ordered" only for what it got) | SAME |
| 9.4 (541) owners' money: how much, when | open | Founder's money moves into the plan (building.gd:148-150) | – |
| 9.7 (583) contract is its own record | proposal | `contract` table in building.gd (_sign) | SAME |
| 9.8 (603-605) apartment 0.85, tower 1.15; land 10% of bill; payback 12-15 years | proposal (10%) / plan | site.gd:29 LAND_SHARE 0.10 is SAME. type_table PAYBACK_HOMES_Y 13.5 is SAME. Form bill factors: none. | 10% SAME; form factors NOT BUILT (step 7) |
| 9.8 (608-610) rent = own rent × value/1000 × condition factor (1 above 55) | plan | Rent is one company price (`@home`); no value or condition factor | NOT BUILT (step 7) |
| 9.9 (639-640) a striking company's staff are not read as idle | proposal | – | NOT BUILT (step 9) |
| 9.12 (676) landing stock holds food | proposal (Wilma) | landing.gd:58 FOOD 12000 (12 months for ~1000 settlers) | SAME |
| 12.1, 1 one area at landfall | Wilma | AreaStore.found_landing (landing.gd:78) | SAME |
| 12.1, 2 districts drawn later; one district = colony-wide | Wilma | Grants fall back to the area when no district exists (grants.gd:90-92) | SAME (district drawing not checked) |
| 12.1, 3 land bought at land price | Wilma | `Site.buy_land` at signing (building.gd sign_round) | SAME |
| 12.1, 4-5 one full size per square; best-scoring free place | Wilma | site.gd choose_country: ≤ 6 sixths per tile, sorted by score | SAME. A plant paying for road/power/water connection: NOT BUILT (step 4/7) |
| 12.1, 6 building kept by buyer / stands after ending | Wilma | – | NOT BUILT (step 6) |
| 12.1, 7 order: trade, production, settlement, rules, households | Wilma | month.gd:43 TRADE, PRODUCTION, SETTLEMENT, COMPANY_AI, JUSTICE, SOCIAL | SAME |
| 12.1, 8 money at start set by us | Wilma | TREASURY_START 2,000,000; builder capital 3 months of wages; settler savings per household I1 1800 … I5 36000 (households.gd:37) | SAME |
| 12.2, 9 landing stock sold by the government at starting prices | Wilma | Colony Stores price_fixed, offered at start_price; takings to treasury (landing.gd:150-160, 311-320) | SAME |
| 12.2, 10 settlers as in old game | Wilma | settle_founders, bands I1-I5 | SAME |
| 12.2, 11 landing shelters, low rent | Wilma | landing.gd:53-54 blocks of 50, SHELTER_RENT 97 ("half a new home's rent, which the user doubled") | SAME (see row 45) |
| 12.2, 12 no roads beyond landfall | Wilma | No road is built in landing.gd | SAME (nothing contrary found) |
| 12.2, 13 port at landfall, government's | Wilma | ship.gd:132 port_tile = Terrain.landing. There is no port record or owner. | Place SAME; government ownership NOT BUILT (port design open) |
| 12.4, 30-32 carriers' price per route, supplies by freight, trucks ordered from maker | Wilma | – | NOT BUILT (step 4) |
| 12.4, 33 roads on; private roads and tolls left out | Wilma | transport/private_roads.gd is behind the opt-in flag PRIVATE_ROADS (off by default) | SAME |
| 12.4, 34 planet sets farm yield by season and ecology | Wilma | making.gd:106-109 → Site.yield_pm (site.gd:422-439, season × land %) | SAME |
| 12.5, 36 old household side carried; 130% crowding | Wilma | households.gd:547 fit = homes × 1300/1000. Self-employed as family service companies: NOT BUILT (step 4). | 130% SAME |
| 12.5, 37 starting salary = (rent + food) × 1.5 | Wilma | rules.gd:270-272 starting_salary = 2 × area rent × tier (STARTING_RENT_PM 2000; S 1.5, Sp 2.25), food out, per the user's 9.2 ruling of 2026-11-18 | DIFFERENT (superseded by a user ruling; paper not updated) |
| 12.5, 37a farm output set so the formula closes | Wilma | type_table FARM 240 FOOD for 24 posts, from the user's "10 purple each" | DIFFERENT (set by user ruling, not by the formula) |
| 12.5, 38 needs = rent + food = two-thirds of starting salary | Wilma | rules.gd:299-310 needs_line = cheapest rent + 2.5 × cheapest FOOD | Rent + food SAME. "Two-thirds of the starting salary" no longer holds (salary = 2 × rent) |
| 12.5, 39 move when a job within reach pays more after travel | Wilma | households.gd labour_month: same area only, no travel; needs a bar of 10% + 1%/year, max 15% (user 9.2) | DIFFERENT in part: no reach or travel (step 4) |
| 12.5, 40 reach, travel, buses | Wilma | – | NOT BUILT (step 4) |
| 12.5, 41 benefit and pensions as % of the area's starting salary | Wilma | landing.gd:193-197 support_rates = TypeTable.salary("G") (300) × rate%. Levers ECON_UNEMPLOYMENT_BENEFIT_RATE default 40, ECON_PENSION_RATE default 35. | DIFFERENT: uses the type table's 300, not the area's starting salary (2 × area rent ≈ 194 at shelter rent 97). The comment still says "until areas carry their own salary line (step 3)". |
| 12.5, 42 arrivals and departures by ship with households | Wilma | ship.gd:90-94 | SAME |
| 12.6, 43-48 services | Wilma | – | NOT BUILT (step 4) |
| 12.7, 49 utilities | Wilma | – | NOT BUILT (step 4) |
| 12.8, 50, 50a, 50c bank as company; loans create money; ledger accounts | Wilma (50c carried from user's 2026-11-14 decision) | – | NOT BUILT (step 5) |
| 12.8, 50b one record of each sale | Wilma | market.gd:315-317 one `sale` record per sale | SAME |
| 12.8, 51 owners take profit once a year above six months of costs | Wilma | Non-family owners: none (step 5). Family companies: rules.gd winnings/pay_winnings take the month's earnings every month, keeping one month of costs (user 15e) | DIFFERENT for family companies (monthly, one month kept); rest NOT BUILT |
| 12.8, 52, 53, 53a, 54a, 55 liability, buy-out debts, dead stock to bank at −10%, eviction | Wilma | Unpaid rent is carried as rent_owed (households.gd:811-845); no eviction | NOT BUILT (steps 5-6) |
| 12.8, 54 state company covered from the money the government has | Wilma | landing.gd:214-274 pays what each state company lacks; a short treasury shares pro rata and publishes ECON_PURSE_SHORT | SAME (closing not built) |
| 12.9, 56 paid monthly; own-work price fixed; wages and material follow cost; stop after three unpaid months; takeover; refuse and wait | Wilma | building.gd bill_month: signed BW price + wage drift; three unpaid months gives STOPPED. Supplies: the site order's max price = the price at signing (`worth`), so material cannot be bought above the signing price. A plan that cannot pay waits. | DIFFERENT in part: material is capped at the signing price, not following cost. Takeover of a half-built job NOT BUILT (step 6) |
| 12.9, 57 book in signing order | Wilma | building.gd book() sorted by contract n; work_month walks it | SAME |
| 12.9, 58 upkeep | Wilma | Upkeep column only; never booked | NOT BUILT (step 6) |
| 12.9, 59 plant runs while built a size up | Wilma | – | NOT BUILT (step 6) |
| 12.9, 60 plan's money in its own account until it opens | Wilma | building.gd make_plan / open_due | SAME |
| 12.9, 60a founder counted from plan day | Wilma reading | month.gd:155 make_founder before make_plan | SAME |
| 12.9, 60b given-up plan settled | Wilma | Builder keeps what it was paid; grant reclaimed (plan, then founder, then debt to court); money back to founder. Land and half-built building are not sellable (site stays held under the plan). | SAME in part; land/building sale NOT BUILT (step 6) |
| 12.9, 60c founder is a household; back to the pool of the band they now belong to | Wilma | households.gd release_founder (1256+) returns them to their ORIGINAL area and band (r["area"], r["band"]) | DIFFERENT: no move to the band they now belong to |
| 12.9, 61 one grant per household | Wilma | grants.gd had(), mark_granted, pool "granted" count | SAME |
| 12.9, 61a window of 24 months | starting number | PROGRAMME_M 24 | SAME |
| 12.9, 61b other three grants' sums; farms = feed the colony at full output; extra one tenth | Wilma's reading / starting numbers | grants.gd wanted(): bakery the same with bread; trucker/truckshop one per area with none. Farm count nets off standing and planned farms. EXTRA_PM 100 | SAME |
| 12.10, 62 taxes, budget lines, reserve | Wilma | – | NOT BUILT (step 8) |
| 12.10, 63 levers kept | Wilma | Only ECON_YEARLY_RAISE_MIN_PCT, the 4 grants and benefit/pension are defined. ECON_MIN_WAGE etc. are not defined in the rebuild (only a law_data.gd:336 constraint). | NOT BUILT (step 8) |
| 12.10, 64-69, 71-72, 74-75 | Wilma | – | NOT BUILT (steps 5-9, 11) |
| 12.10, 70 state staff paid by the same salary rules | Wilma | State staff placed at 2.5 × rent (rules.gd:207 PLACED_RENT_PM, user 9.2) | SAME (by user ruling) |
| 12.10, 73 blame published | Wilma | Mass-layoff fact (econ_publish.gd:115-118), purse-short fact, grant-favouritism fact | Partly built |
| 12.10, 76 plain map | Wilma | not checked | – |
| 12.11, 77-98, 100-109 | Wilma | – | NOT BUILT (later steps) |
| 12.11, 99 public works builds at cost, not one of the five | Wilma | home_builders.gd:35,57 state BUILDER AVERAGE; excluded from hire (building.gd builders()) | SAME (idle until step 8) |
| 12.11 "not worked in": emergency rations | Wilma | No automatic rations anywhere in game/sim | SAME |
| 12.12 left out (supply contracts, credit, storage, quality, private roads, federation) | Wilma | None built; private roads off by flag | SAME |
| 13 "What step 3 is and is not"; tested first on food alone | plan | FOUNDABLE = FARM; no bank, no freight | SAME |


---

<!-- part: part_households_building -->
# Audit: rebuild-households.md and rebuild-building.md against the code (tree at 0c9e266, working files)

Read-only. Paths are relative to `game/sim/` unless stated. "hh" = population/households.gd.
Verdicts: SAME / DIFFERENT / NOT BUILT (later step) / n/a (a process ruling, not a mechanism; not counted).

## 1. Lines carrying the user's words

### rebuild-households.md

| # | Paper + line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|---|
| 1 | §intro l.7 | "we take how it works and transfer over not take the code" | Process ruling. The new files are new code | n/a | |
| 2 | §intro l.8 | "Oh no wholesale does not mean unchecked" | Process ruling | n/a | |
| 3 | §1.1 l.26 (35) | Pools stay, one per area and band with one account; a count per company | Table "pool", id "area\|band", account "pool:<id>" (hh:42-66); count per company read from Company staff (Company.staff_of_pool) | SAME | |
| 4 | §1.2 l.27 (35) | "don't malt to many people to track"; founders counted individually from the day the plan is made; back to the pool when they own nothing | make_founder at plan making (economy/month.gd:155, hh:1199); one record per founder (a family farm's family rides on the one record); release_founder / release_idle_founders every month (hh:1256, 1289), debts carried (hh:1301) | SAME | |
| 5 | §1.3 l.28 (36) | the self-employed become family-size service companies | No service types can be founded: FOUNDABLE = ["FARM"] (economy/month.gd:27) | NOT BUILT (later step: services) | |
| 6 | §1.4 l.29 (36) | no price floors or ceilings of ours | Household side has none: the food order's worth is the whole budget (hh:619-620); the store order pays any price (hh:646). No clamp on a price in hh | SAME | |
| 7 | §1.5 l.30 (9.6) | nothing from the home world except on a ship in port | Settlers land and people leave only inside Ship.month with a ship in port (economy/ship.gd:93-94); the home world's picture is kept as of the last departure (ship.gd:70, hh:1725) | SAME | |
| 8 | §1.6 l.31 (9.1) | a short household pays food, then rent | Food order's budget = all its money (hh:619); rent paid after the market from what is left (economy/month.gd:88-95, hh:811) | SAME | |
| 9 | §1.6 l.31 (9.1) | ... then water and power | No grid in step 3 | NOT BUILT (later step) | |
| 10 | §1.7 l.32 (9.3) | "Company and people should be able to stock up if the price is low"; "what's low should be against what its worth to the buyer" | For households only food: the AHEAD store order (hh:633-648) whose worth is its whole budget, so every price is under it | SAME for food | Other household goods: NOT BUILT (step 3 is food only) |
| 11 | §1.8 l.33, N2/N3 (9.8) | "I belive you should be able to buy your house out ... build his own larger house ... 1/6 of a farm" | No home buying, no own house | NOT BUILT (step 7) | |
| 12 | §1.9 l.34 (23) | hunger is counted from need | hunger = need − eaten (hh:741-747) | SAME | |
| 13 | §1.10 l.35 (23a) | short of money is not refusing the price | Hunger split NO_MONEY / PRICE / scarce from Market.filled's why (hh:749-751) | SAME | |
| 14 | §1.11 l.36 | nothing behind an off switch | No on/off switch in hh, population/demography.gd, economy/building.gd (only levers: yearly raise min, retirement age) | SAME | |
| 15 | §1.12 l.37 | every decision and move writes a Logbook row | Rows written for every built deed (BUDGET, EAT, STORE, RENT, HIRE, LAYOFF, JOB/STAY, FOUNDER, FAMILY, PAY, ARRIVE, DEPART, NEGOTIATE ...) | SAME (for what is built) | Rows for unbuilt deeds (home bought, shack, slum) come with them |
| 16 | I1 l.306 (36) | "The 130% crowding limit stays" | homes(): fit = homes × 1300/1000; homeless = households − fit (hh:547-549) | SAME | shacks are 0 until step 7 (hh:549) |
| 17 | H6 l.257 (12.11) | food aid ruled out: nothing arrives that was not ordered with a ship | No food aid anywhere in hh/landing | SAME | |
| 18 | H23 l.274 (9.1) | quarterly migrants ruled out | Arrivals only by ship (ship.gd:93) | SAME | |
| 19 | 2b l.148 (9.2) | "emplyees only apply to jobs that meet their needs" | Households.hire: pay < needs_per_worker → nobody hired, HIRE row "no applicants" (hh:195-198). Needs = Rules.needs_line: cheapest landlord rent in the area + cheapest FOOD price × 2.5 persons (economy/rules.gd:299-309, HOUSEHOLD_PERSONS_PM 2500). Placed landing crews exempt (user ruling "should not be hiring at all") | SAME | |
| 20 | 2b l.149 (9.2) | "10% if it's a good job" | QUIT_BAR_GOOD_PM = 100 (hh:993); move only if new × 1000 ≥ old × (1000 + bar) (hh:1016) | SAME | |
| 21 | 2b l.149 | "less if stressfull" | quit_bar_base_pm always returns 100 (hh:1001); QUIT_BAR_STRESSED_PM 50 unused | NOT BUILT (step 9, stress) | |
| 22 | 2b l.149 | "plus 1% per year in the same workplace" | + QUIT_BAR_PER_YEAR_PM 10 × full years since the entry's "since" month (hh:995, 1006-1012) | SAME | |
| 23 | 2b l.149 | "up to 15%" | min(QUIT_BAR_MAX_PM 150, bar) on the whole bar (hh:996, 1012) (Wilma's reading of the cap) | SAME | |
| 24 | 2b l.154 (9.2) | "contracts should have clauses for payment after fire ... say three months of vages" | Every layoff owes LAW_LAYOFF_PAY_MONTHS (default 3, law/law_data.gd:497; read via WorkLaw.layoff_pay_months, clamp 0-12, law/work_law.gd:28) × the person's own row pay (hh:268, 284); paid as far as the account reaches, rest owed via Justice.owe LAYOFF_PAY (hh:314-329) | SAME | |
| 25 | 2b l.154 | "it should apply to builders" | Households.layoff is the one layoff for every company, builders included | SAME | |
| 26 | 2b l.155 (15e) | "The owners of a family farm should take winnings no sallery, wich comes after" | Family adults are BUSINESS_OWNER on no payroll (hh:1556-1574); Rules.winnings = month's revenue − inputs − wages − upkeep − adverts − layoff pay − debts paid, after a carried loss (economy/rules.gd:560-575); paid in JUSTICE after debts (economy/month.gd:171, rules.gd:587) into the founder's account (hh:1580) | SAME | |
| 27 | 2b l.155 (15e) | "the farm would be their home" | Landing.rent_due returns nothing for a founder whose plan's company is an OPEN FAMILY FARM (economy/landing.gd:284-286, 298-306); homes() does not count them as a town household (hh:542) | SAME | |
| 28 | (same sentence, rebuild-company 15e) | "...wich means they are paying on any loans they had to take and uppkeep to keep it nice" | No company books "upkeep" anywhere (only read: rules.gd:564, making.gd:160), so upkeep is 0; no loans (step 5) | NOT BUILT (later steps: upkeep/wear step 6, bank step 5) | |
| 29 | 2b l.164 (15e) | "ship food should be considered less desierable" | Offers ranked with ship goods 25% dearer, SHIP_LESS_WANTED_PM 250 (economy/market.gd:30, 90-93); a household that cannot cover its need buys by PRICE (hh:684) | SAME | |
| 30 | 2b l.165 (9.2) | "the manager, negotiation can bring it closer to avrage" | _negotiate in July (NEGOTIATE_MONTH 7): ask = pay + half the gap to the average, granted if the company's account holds a year of the rise (hh:1072-1089); Company.negotiate never above the average, never lowers (economy/company.gd:734) | SAME | |
| 31 | 2b l.165 (9.2) | underpaid: "avrage ask salleries in the company and underpayed is based on that line" | Average is Company.avg_pay(cid, post_tier): per post tier only (economy/company.gd:708-715) | DIFFERENT | User: average of the salaries in the company. Code: average within the same post tier, from a "(proposal, one detail)" in rebuild-company.md 9.2 l.423, which the households paper presents as the user's ("for the post", "9.2, the user") |
| 32 | 2b l.166 (9.2) | "climbs based on yearly upps set by goverment" | January, from the second year: every company raises by max(its choice, lever ECON_YEARLY_RAISE_MIN_PCT default 2 → 20‰) (hh:1094-1100; economy/econ_publish.gd:59; company.gd:426) | SAME | |
| 33 | 2b l.199 (15f) | "They stockplie to have have six months of food in storage" | STORE_MONTHS = 6 (hh:498) | SAME | |
| 34 | 2b l.200 (15f) | "they buy 2 units if food instead of one, store it and use it in emergencies" | NEED order for the whole month every month; store eaten only after this month's food (hh:745) | SAME | |
| 35 | 2b l.201 (15f) | "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT" | AHEAD want = min(need − farm_store, 6·need − held − farm_store) (hh:633): never more than one extra month | SAME | |
| 36 | 2b l.201 (15f) | "if your running low and don't know how long the ossue will last i don't think you wait" | AHEAD order every month, max_price = its whole budget (any price) (hh:646) | SAME | |
| 37 | 2b l.202 (15e) | "THE FARMERS THEMSELVES I RULED EATS THEMSELVES FIRST ... THEY WOULD TAKE SIX OUT OF THIRTY SELL 24" | Before any order, a founder with an open family farm takes need + min(need, 6·need − held) from the farm's stock (hh:611-617; economy/making.gd:125-135), no money, never offered; market buys only what is missing | SAME | "enough to hire one person" is an outcome, not checked here |

### rebuild-building.md

| # | Paper + line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|---|
| 38 | l.13 | "PLANS ARE MADE BEFORE THEY BECOME COMPANIES ... THAT'S BEFORE ACCEPTING A GRANT" | Plan made (economy/building.gd:141), then Grants.apply into the plan's account (economy/month.gd:158-163); company created only at opening (building.gd:614) | SAME | |
| 39 | l.14 | "you can't fail before you exist" | A plan given up is GIVEN_UP in table "plan", never a company, not a failure (building.gd:329-353) | SAME | |
| 40 | l.14 | "no worker but also no expenses beyond building" | Plan account pays only land (Site.buy_land, building.gd:282), contract bills (bill_month, 570) and site supplies (SITE orders on the client's account, 393). No staff | SAME | |
| 41 | l.15 | "They should not need 90% of supplies up front" | No 90% rule anywhere | SAME | |
| 42 | l.15 | "they should need 3 months up front" | UP_FRONT_M = 3 (building.gd:43); a job starts only with min(3 × month_need, rest of the bill) on site (_ready, 498-506) | SAME | |
| 43 | l.15-16, §4.5 | "add 1 month of additional supplies every month" | Each month a working job orders up to 3 × month_need − on_site (building.gd:388), i.e. replaces the month used | SAME | |
| 44 | l.17 | "5 building companies and alot of oppretunity" | HomeBuilders.HOME_WORLD: five (LARGE, AVERAGE, AVERAGE, SMALL, SMALL) = 180 crew placed (economy/home_builders.gd) | SAME | |
| 45 | l.17 | "materials come with the start not finished buildings" | No farm/mine/factory at landing; subsidiaries have no plant (landing.gd:47, 105-110); BUT the housing office's landing shelters are laid as LANDLORD plants, 50 homes each (landing.gd:124-146) | DIFFERENT | Shelter plants are finished buildings at the start; Wilma's decision, flagged against this ruling in rebuild-company.md §14 ("I gave the settlers plain shelters anyway") |
| 46 | l.17 | "5 years worth of equipment" | Landing STOCK MATERIAL 9700, COMPONENT 1060, TRUCK 20, FOOD 12000 (landing.gd:58). Bob's reading: five years of the five builders' work (180 BW × 60 months = 10,800 BW ≈ 0.9 MATERIAL per BW) | SAME (as read) | The figure is a reading; trucks in it are the step-2 brief's, not user words |
| 47 | l.18 | "they are companies from the world" | Five builders owned {"kind": "HOME_WORLD"} (home_builders.gd OWNER_HOME) | SAME | |
| 48 | §4.3 l.165 (15d) | "He should look for the shortest time" | Quotes sorted by earliest start, then lowest total (building.gd:253); takes the soonest it can pay (269-273) | SAME | |
| 49 | §3 l.99 (9.8) | homes: apartments 0.85, tower 1.15 ("the user's figures") | No form factor on any bill; homes not built by contract | NOT BUILT (step 7) | |
| 50 | §4.9 l.253 (8.1) | "It ends only if its owner gives it up (no builder, no money)" | give_up on no builder (building.gd:236-237) and on a STOPPED job the account cannot pay (590-593); ALSO on "the work is no longer there (rule 7)" before signing (239-240) | DIFFERENT | A third reason, rule 7's signal gone before signing, ends plans; it is Otto's "(Otto)" decision in 4.4, not in the user's "only ... (no builder, no money)" |
| 51 | §5.1 l.318 | "money is a limitor" (growth) | No rule-5 growth, size-up or buy-out | NOT BUILT (step 6) | |
| 52 | §5.3 l.330 | homes keep "the user's 55" (condition) | No condition factor on rent; condition is not used | NOT BUILT (step 7) | |

Counts: 52 rows; 2 n/a (process); 50 counted: 39 SAME, 3 DIFFERENT (31, 45, 50), 8 NOT BUILT (later step) (5, 9, 11, 21, 28, 49, 51, 52). Row 10 is SAME for food with the rest NOT BUILT.

## 2. Lines that are a decision, reading, proposal or starting number (no user words behind them)

### rebuild-households.md

| Line | Whose | Built as the line? |
|---|---|---|
| 2a starting numbers: 1,000 settlers, 400 households of 2.5; 200/band = 150 working (90% LF), 44 children, 6 retired | Wilma accepted | SAME (hh:26-31, settle_founders 110-129) |
| skills ‰ I1 1000/0/0 … I5 200/550/250 | Wilma accepted | SAME (hh:33) |
| ages ‰ 350/450/200 | Wilma accepted | SAME (hh:35) |
| savings per household 1,800 / 3,600 / 7,200 / 14,400 / 36,000 | Bob's table | SAME (hh:37) |
| crews 180 builders + 40 public works | Otto / Wilma | SAME (5 builders 18 sixths = 180; public works AVERAGE = 40) |
| who fills a post: own skill, then higher; shared over bands by unemployed, largest remainder | Maja (decided) | SAME (hh:202-225) |
| short payer pays everyone the same share | Maja | SAME (_pay, hh:397-412) |
| founder: skilled/specialist first; unemployed and outside the LF before employed | Otto 4.2 / Maja | SAME (_free_adult, hh:1167-1182) |
| employed founder keeps the post until the plan signs; eats with the pool until then | Wilma / Maja's reading | SAME (hh:1213-1215, take_up_posts 1483, lives_apart 1540) |
| founder takes balance × 2.5 ÷ persons | Maja / Bob | SAME (hh:1118-1122, owners left out of persons) |
| tenancy slots, landlords' homes | Otto, step 7 | NOT BUILT (step 7); housing office only |
| shelter plants: 8 × 50 homes | Otto | SAME (landing.gd:53, 133-135) |
| shelter rent half a new house | Wilma | Code: SHELTER_RENT 97 ("half ... which the user doubled", landing.gd:54) |
| areas split by reach | Maja / Terra | not checked in this audit |
| founder drawn by seeded draw weighted by households | Maja / Wilma | SAME (pick_founder, hh:1131-1160) |
| one grant per household: pool "granted" count, mark_granted | Maja / Ella | SAME (hh:1138-1143, 1210, 1278, 1672) |
| opening money narrows who may found | Maja's reading | SAME (pick_founder needs ≥ founder_needs incl. 3 months, hh:1140; building.gd:84-86) |
| a returning founder goes back to the status it came from | Maja / Bob | SAME (hh:1266-1271) |
| each order's money is its line's budget | Wilma's ruling / Bob | SAME (hh:619-624, 646) |
| store from what food and rent leave; NEED cleared before AHEAD | Wilma / Bob | SAME (hh:629-631; market.gd:156-157) |
| store follows people on band moves / area moves | Maja / Terra | SAME (move_store hh:1311; _area_money_and_store 1370) |
| negotiation in July, halfway, if the account holds a year | Maja / Wilma | SAME (hh:490, 1078-1080) |
| "The worker negotiates first, and only if that fails do they look for better pay" (paper cites "9.2, the user"; it is a "(proposal)" in rebuild-company.md l.418) | proposal | DIFFERENT: labour_month moves workers for pay every month (hh:1023-1069); negotiation only in July and quitting does not wait on its failure |
| who leaves: LEAVE_PM 100 × (1 − attractiveness) of unemployed young; all homeless households | Maja | SAME (hh:493, 1791-1824) |
| attractiveness jobs 40 / food 40 / homes 20, known as of the last ship | Maja | SAME (hh:1722, ship.gd:70); departures read the current figure |
| life numbers: TFR 4.0, 40% lower at top; 90% of 18-year-olds to the LF; 1% re-entry; band EMA a sixth, margin 10% | Maja | SAME (demography.gd:42-51: 4.0, 0.4, 900, 10, 167, 100) |
| famine a quarter for three months; facts at a twentieth | Maja | SAME (hh:775-777: 250, 3, 50) |
| ship food a quarter dearer | Wilma's starting number | SAME (market.gd:30, 250) |
| H24 pollution raises deaths | Maja (decided) | NOT BUILT (no pollution in demography.gd) |
| N1 general stocking up for other goods | Maja | NOT BUILT (food only) |
| shacks, slums | Maja | NOT BUILT (shacks 0, hh:549) |

### rebuild-building.md

| Line | Whose | Built as the line? |
|---|---|---|
| §2 one BW = one builder worker's month; × (1 − size penalty) | Otto | SAME (home_builders.gd:84-89) |
| §3 every bill row (FARM 240/240/12/4 … BUILDER 120/120/6/2) | Otto / Bob | SAME (type_table.gd rows 60-172, all match) |
| §3 sizes: share of the bill; months = max(2, ceil(full × (1 + share)/2)) | Otto | SAME (type_table.gd:270-274) |
| §3 builder row 60 workers 36/18/6, 60 BW | Otto / Bob | SAME (type_table.gd:105) |
| §3 upkeep 1/400 of MATERIAL a month, 2% of BW a year | proposal | Constants SAME (type_table.gd:33-34, 280); never bought or booked in the month: NOT BUILT |
| §4.1 builders 1 large, 2 average, 2 small | Otto | SAME |
| §4.1 public works idle in step 3 | Bob | SAME (builders(for_hire) excludes it, building.gd:184) |
| §4.1 landing stock a fixed offer, not moved by rules | Otto | SAME (price_fixed, landing.gd:152) |
| §4.1 trucks: a truck-driver plan orders its truck from the home world by ship | Otto (open) | DIFFERENT: TRUCK 20 in the landing stock (landing.gd:58); truck drivers cannot be founded yet (FOUNDABLE = FARM) |
| §4.2 three months' opening money | Otto, Wilma accepted | SAME (OPENING_M 3, building.gd:44, 86) |
| §4.2 "not a limit on anyone: a founder may plan without it if they choose" | Otto | DIFFERENT: pick_founder admits only households whose share (+ grant) ≥ founder_needs incl. opening money (hh:1140, 1142); nobody plans without it |
| §4.2 largest size that passes and money reaches | Otto | SAME (month.gd:137-148) |
| §4.2 several founders taken in fixed order by pool id | Otto / Bob | DIFFERENT: seeded draw weighted by households (hh:1150) |
| §4.2 plans not counted in rule 7's shares | Otto / Bob | DIFFERENT: booked (SIGNED) and granted MADE plans are counted (building.gd:101-114), following the user's later 15a words |
| §4.3 estimate: avg BW price + materials at market | Otto | SAME (building.gd:71-78) |
| §4.3 quote: price × BW + materials + start from the book at present crew | Otto | SAME (193-216; start = month + 2 + work ahead / crew) |
| §4.4 re-read rule 7 before signing, give up, money back, founder back | Otto | SAME (239-240, 329-350) |
| §4.4 refuse a quote that is more than the account holds, ask next month | Otto | SAME (269-281) |
| §4.4 grant paid at signing | Otto | DIFFERENT: grant paid at making (month.gd:163) |
| §4.4 land bought at signing; price_bw, wage_bw fixed; end of book | Otto | SAME (282, 306-313) |
| §4.5 month of supplies: BW planned = bill / fewest months, "or the crew the builder can put on it, whichever is less" | Otto | DIFFERENT: planned_bw = ceil(bill / months) only, crew not considered (building.gd:365-367) |
| §4.5 supplies order is the client's, worth = estimate price, paid on delivery | Otto / Bob | SAME (building.gd:305, 393-394) |
| §4.5 waiting for material is not a price signal | Otto | SAME (offered = cap − waiting_material, building.gd:669) |
| §4.6 crews in signing order; a blocked job keeps its place; material in proportion | Otto | SAME (463-540) |
| §4.6 price rise reads BW its signed clients wanted that it had no crews for | Otto | DIFFERENT: rise reads plans that signed to wait behind the book, counted once (unmet_pending, 291-292); short_crew is for the log only (Wilma's decision) |
| §4.6 cut reads empty crews and quotes refused for price | Otto | SAME (669-670) |
| §4.7 bill = BW done × (price_bw + wage now − wage_bw); stop after 3 unpaid months; resume when paid | Otto (12.9, 56) | SAME (564-586) |
| §4.8 opens the next month, founder owner, condition 100, money moves | Otto | SAME (602-642; CONDITION_FULL company.gd:23) |
| §4.8 the building goes on the company's books as an asset | Otto | NOT BUILT: cost kept on the plan record only (p["cost"]) |
| §4.9 builder keeps what it was paid; contract ABANDONED; grant owed back; founder back; not a failure | Otto | SAME (329-353) |
| §4.9 another plan may take over an ABANDONED contract | Otto | NOT BUILT (no takeover code) |
| §5 everything for step 6 (size-up, buy-out, idle closing, wear 1 a month, below 50, repair half bill, permits, state picking a builder) | Otto | NOT BUILT (step 6) |


---

<!-- part: part_master -->
# Audit: planning/MASTER-PLAN.md lines 665-1070 against the code (shared tree at 0c9e266, working files read 2026-11-18)

Read-only. Step 3 is the current build step. Line numbers are MASTER-PLAN.md lines. Numbers: money in credits
(the code keeps milli-credits). Start prices were recomputed outside the game from `TypeTable.start_prices()`'s own
solve: FOOD 39.43, BW 391.99, a new home's rent 193.96 (= 96.98 x 2), so the landing shelter at 97 is half a new home.

## 1. The user's words against the code

| # | Ruling, line | The user's words (short) | What the code does today | Verdict | What differs |
|---|---|---|---|---|---|
| 1 | Wholesale not unchecked, 674 | "wholesale does not mean unchecked" | No home-world food aid or emergency rations anywhere in game/sim (grep: none). Households are new code (households.gd header). | SAME | |
| 2 | Old systems, 683 | "most of these needs to be worked in" | The 36 systems are spread over steps 4-11 (rebuild-company 12.11, section 13); not audited one by one here. | NOT BUILT (later steps, mostly) | Most belong to later steps; not checked system by system in this part. |
| 3 | Old systems, 683 | "the old system and the new for five years are not the same" | landing.gd:58 STOCK MATERIAL 9700, COMPONENT 1060 as the five years of equipment; builders bring BUILDER_CAPITAL_MONTHS = 3 months of wages (landing.gd:60), not five years of running costs. | SAME | |
| 4 | Households as behaviour, 690 | "we take how it works and transfer over not take the code" | households.gd written new ("no old code and no old numbers"). | SAME | |
| 5 | Order of paying, 690 | "water and power before rent what are you paying ... if you can't pay the rent?" (food, rent, then water and power) | Households.post_orders (households.gd:598-654): food budget = all money; rent set aside next and paid after the market (pay_rent, :811); no water/power line in step 3 (no grid). | SAME | |
| 6 | Stocking up, 702 | "Company ... should be able to stock up if the price is low" | Making.post_orders (making.gd:206-214): an AHEAD order up to 2 months' need when cheapest offer <= 800 per mille of input_worth and the input spoils < 50 per mille a month. | SAME | |
| 7 | Stocking up, 702 | "and people should be able to stock up" | Households' food store, AHEAD order toward STORE_MONTHS = 6 (households.gd:628-649). | SAME | |
| 8 | What low is, 711 | "low should be against what its worth to the buyer, like when they buy normaly" | Company: against Making.input_worth, the same worth its ordinary order carries (making.gd:200-201, 219). Household: its worth is its whole food budget (households.gd:619-620), so the store is not price-gated (15f). | SAME | |
| 9 | Everyone builds, 718 | "atleast one other reviews each peace of code" | Process, not code. | n/a | |
| 10 | Log, 725 | "a backend column ... that records all things happening like a log" | core/logbook.gd (Logbook.note); every rule, price, level, hire, pay, grant, plan writes a row in the files read. | SAME | |
| 11 | Salary set on hire, 734 | "they have a sallery set on hire" | Company.staff_change stores pay in the hire row (company.gd:246); nothing in the rules moves it; the offer rule moves only record["salary"] (company.gd:387). | SAME | |
| 12 | Salary set on hire, 734 | "then it climbs based on yearly upps set by goverment" | Households.yearly_raise_month (households.gd:1094-1100): every January from year 2, max(company choice, lever ECON_YEARLY_RAISE_MIN_PCT default 2%) -> Company.yearly_raise. | SAME | |
| 13 | Why set on hire, 743 | "underpayed workers go to the union ... if not they may unionise" | No union code in the economy (grep "unionis"/"underpa": none). Unions are step 9. | NOT BUILT (later step 9) | |
| 14 | Why set on hire, 743 | "they can quit if they think they can get better prices" | Households.labour_month (households.gd:1023-1069): moves to a better-paid vacancy over the quit bar. | SAME | |
| 15 | Underpaid line, 752 | "avrage ask salleries in the company and underpayed is based on that line" | Company.avg_pay (company.gd:708): head-weighted average pay of the company, per post tier (proposal detail). Used by _negotiate. | SAME | |
| 16 | Negotiating, 759 | "the manager, negotiation can bring it closer to avrage" | Households._negotiate (households.gd:1072-1089): in month 7, a row paid below the tier average asks halfway; granted if the account holds a year of the rise; Company.negotiate refuses above the average. | SAME | |
| 17 | Grant programme, 768-770 | "when a grant ends, they reset to zero so they have to start over on where to put it"; "and where it covers too" | Grants._end_programme -> LawOps.end_programme puts the lever to 0 (grants.gd:387-389); GovBuilder._grant_cover erases the cover and the sum when the lever is 0 (gov_builder.gd:557-563). | SAME | |
| 18 | Grant programme, 768 | "grants should be limited time for when you can apply" | PROGRAMME_M = 24 months (grants.gd:48), the window does not extend. | SAME | |
| 19 | Grant's maximum sum, 779 | "max sum into the grant based on how many darms they want maybe a little extra" | Grants.budget_for = wanted x largest area grant + EXTRA_PM 100 per mille (grants.gd:316-322); apply refuses when sum_left < grant (:180-185); quote 0 then. | SAME | |
| 20 | Builders, 788 | "they should not cut for the start" | Building.seller_signal returns {} until first_quote_month >= 0 (building.gd:663-665), so price_rule/output_rule do nothing. | SAME | |
| 21 | Builders, 788 | "they should not increase prices for claimed jobs" | sign_round (building.gd:291-294): a plan signed whose start is later than month+2 adds its whole BW bill to "unmet_pending", read next month as unmet_above (:668-670) and raises the BW price by rule 1 (rules.gd:127, K_PM). Waiting contracts are no longer counted every month. | DIFFERENT | A signed contract waiting in the builder's book (a claimed job) still raises the price once, in the month after signing; the plan (15c) says "work signed and waiting in its book is not a customer turned away". |
| 22 | Builders at start, 797 | "At start id assume they know work is coming" | Same empty signal stops rules 3/4 cutting crew before the first quote (rules.gd:169-170). (A 19a layoff for unpaid wages could still happen; they land with 3 months of wages.) | SAME | |
| 23 | Settlers' plans, 806 | "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants" | Rules.founding (rules.gd:663-677): standing plants + Building.booked (signed, not opened) + MADE plans with a PAID grant; plans only made not counted. | SAME | |
| 24 | Three answers Q2, 817 | "He should look for the shortest time" | sign_round sorts by earliest start, then lowest total (building.gd:253). | SAME | |
| 25 | Three answers Q3, 821 | "10% if it's a good job" | QUIT_BAR_GOOD_PM = 100 (households.gd:993); every job counts as good until stress. | SAME | |
| 26 | Three answers Q3, 821 | "less if stressfull" | quit_bar_base_pm always returns 100 (households.gd:1001-1002); QUIT_BAR_STRESSED_PM 50 is unused. Stress is step 9. | NOT BUILT (later step 9) | |
| 27 | Three answers Q3, 821 | "plus 1% per year in the same workplace up to 15%" | QUIT_BAR_PER_YEAR_PM 10 per full year from the row's "since", capped QUIT_BAR_MAX_PM 150 (households.gd:995-1012). | SAME | |
| 28 | Three answers Q5, 825 | "you're decisions are fine" | Approval, no mechanism. | n/a | |
| 29 | Keeping workers, 834/838 | "clauses for payment after fire ... say three months of vages" | Households.layoff owes WorkLaw.layoff_pay_months = lever LAW_LAYOFF_PAY_MONTHS, default 3 (law_data.gd:497, work_law.gd:28) of the row's own pay. | SAME | |
| 30 | Keeping workers, 834/838 | "costs of hiring, articles in the newspaper" | Rules._advertise pays Media.job_advert (ADVERT_PM 100 = a tenth of a month's pay per post, media_ops.gd:916, 949-952) to the papers. | SAME | |
| 31 | Keeping workers, 834/838 | "maybe 6 months training" (as lower output, accepted) | Company.TRAIN_MONTHS 6, TRAIN_START_PM 500, linear to full (company.gd:129-130, 352-353); making reads trained_count. | SAME | |
| 32 | Keeping workers, 836/838 | (Wilma's view, ruled right) a company with no money still owes the layoff pay as a debt | Households._layoff_pay: what the account does not reach is Justice.owe kind LAYOFF_PAY. | SAME | |
| 33 | Keeping workers, 838 | "it should apply to builders" | Builders go through staff_to_posts, _advertise, layoff and trained_count (home_builders.gd:84-89). | SAME | |
| 34 | Keeping workers, 834 | "weigh say three months of vages without a worker against the profits" | Rules.layoff_weighing (rules.gd:472-497): idle x pay > months x pay + advert + training loss. | SAME | |
| 35 | Family works farm, 847 | "Yes" (family works its farm without wages) | Rules.family_to_posts fills posts with the founder's adults, no payroll, never laid off (rules.gd:518-542). | SAME | |
| 36 | Family works farm, 847 | "ship food should be considered less desierable" | Market SHIP_LESS_WANTED_PM 250: ship goods ranked 25% dearer (market.gd:30, 90-92). | SAME | |
| 37 | Winnings, 856 | "take winnings no sallery, wich comes after" | Rules.winnings / pay_winnings, in JUSTICE after debts (rules.gd:560-607). | SAME | |
| 38 | Farm is home, 865 | "the farm would be their home" | Landing.rent_due returns {} for a founder on an open FAMILY FARM (landing.gd:285-286, 298-306). | SAME | |
| 39 | Farm is home, 865 | "they are paying on any loans they had to take and uppkeep to keep it nice" | No "upkeep" is ever booked (grep: only read, never written); no bank loans exist. Winnings read upkeep 0. | NOT BUILT | Upkeep and loans are not paid by anyone; the plan line itself names no later step (bank is step 5, wear and repair step 6). |
| 40 | Farms away from towns, 874/878 | "Save it for when trucks and roads come Mark it for then" | Nothing built. | NOT BUILT (later step 4) | |
| 41 | Four answers, 887 | "1. Far away enough ... 4. No farms payed fully from saving does not" | Nothing built. | NOT BUILT (later step 4) | |
| 42 | Loss carried forward, 896 | "I think two is better" | Rules.winnings: loss_carried paid down before the family takes anything (rules.gd:570-573, 597). | SAME | |
| 43 | Loss carried forward, 896 | "maybe the family can put some away for the hard months" | Nothing built (noted as a maybe). | NOT BUILT (noted, not ruled) | |
| 44 | Six months of food, 905 | "they buy 2 units if food instead of one" | Store order at most one month's need on top of the month's own (households.gd:633). | SAME | |
| 45 | Six months of food, 905 | "store it and use it in emergencies" | after_market eats the month's food first, the store only for a shortfall (households.gd:742-745). | SAME | |
| 46 | Six months of food, 907 | "six months of food in storage ... as often as they can" | STORE_MONTHS = 6 (households.gd:498); every month while money after food and rent allows. | SAME | |
| 47 | Six months of food, 911 | "if your running low ... i don't think you wait" | Store order posted at any price the money left pays (households.gd:638-646). (AHEAD orders clear after all NEED orders, Wilma's.) | SAME | |
| 48 | Government stockpiles, 920 | "Mark that the government can order stockpiles ... once we get back to politics" | Nothing built. | NOT BUILT (later step 8) | |
| 49 | Hiring offer, 929 | "increases should not stack for seperate offers" | Rules.salary_rules: one climb per tier and area per month, whatever the number of posts (rules.gd:232-258). | SAME | |
| 50 | Hiring offer, 929 | "fall back to the original rule for settin on hire" | Company.hiring_salary = starting_salary when no climb is set; clear_hiring_salary once no post was open a whole month (rules.gd:259-260). | SAME | |
| 51 | Hiring offer, 929 | "only climb max 5% if it cost not hire for one month" | OFFER_CLIMB_PM 50, only for posts left open after last month's hiring and still open (rules.gd:200, 241-257). | SAME | |
| 52 | Hiring offer, 933 | "5% each month" | Climbs 5% again each further month (old x 1050/1000). | SAME | |
| 53 | Hiring offer, 933 | "i never said i wanted the rule for lowering" | No lowering rule; only the fall-back. | SAME | |
| 54 | One row per hire, 944 | "a 2d array to keep all things about the hires? Sallery start date" | staff entry "hires": [{n, pay, since, train}] (company.gd:60, 241-247). | SAME | |
| 55 | One row per hire, 946 | "You can merge if all rows match" | Company._tidy merges rows only when pay, since and training-left all match (company.gd:328-347). | SAME | |
| 56 | Unpaid wages, 950 | "Record it make them pay after our if they refused take it to court" | Households.pay_wages: rest owed as Justice.owe kind UNPAID_WAGES (households.gd:439-445); collected later; petition to court (justice_ops.gd:938-970). | SAME | |
| 57 | Starting salary, 959/969/971 | "just rent at 2×", "2", "Merge with 2" | Rules.starting_salary = area_rent x STARTING_RENT_PM 2000 x tier (rules.gd:203, 270-271); area_rent = plain average of open landlords' @home in the area (97 at the landing) -> G 194, S 291, Sp 436.5. | SAME | |
| 58 | Starting salary, 959 (another instance) | same words | Rules.running_cost (rules.gd:633-645), used by rule 7/8 (Rules.founding), by Building.founder_needs (opening money, x3) and so by every grant amount: posts x TypeTable.salary = 300 x tier (type_table.gd:21, 292-293). | DIFFERENT | Uses 300 (G), 450 (S), 675 (Sp), not 2 x the rent (194 / 291 / 436.5 at the landing). The plan's own 15a line says it should be the starting salary. |
| 59 | Starting salary, 959 (another instance) | same words | Landing.support_rates (landing.gd:193-197): benefit and pension = rate% x TypeTable.salary("G") = 300; its comment says "per cent of the area's starting salary". | DIFFERENT | Base is 300, not the area's starting salary 2 x rent (194 at the landing). (Note, not counted: TypeTable.SALARY_G 300, "the starting salary" of the type table, is still the anchor of every starting price.) |
| 60 | Starting salary, 963 | "3 5x housing try it" | Trial, superseded by "2". | n/a | |
| 61 | Build crews not hired, 980 | "should not be hiring at all. They should start with a job already active" | HomeBuilders._make: Households.hire(..., trained=true, placed=true): no needs test, no advert, trained (home_builders.gd:110; households.gd:181-198). Public works the same. | SAME | |
| 62 | Government staff placed, 989 | "Place the goverment staff from start with the builders" | Landing._crew places admin, housing office and Colony Stores crews (placed=true) (landing.gd:166-177). | SAME | |
| 63 | Placed at 2.5, 989 | "set their sallery at 2.5 from start same for builders" | Rules.placed_salary = area_rent x PLACED_RENT_PM 2500 x tier (rules.gd:207, 276-277). Government: 2.5 x 97 = 242.5 (G). Builders are placed before the housing office exists, so their rent is the fallback start_price_of(LANDLORD)/2 = 96.98 -> 242.45. | SAME | (0.05 credit apart from the government's, from the order of landing) |
| 64 | Farm family eats first, 998 | "THE FARMERS THEMSELVES ... EATS THEMSELVES FIRST" | Households.post_orders calls Making.family_take before any order; never offered (households.gd:611-618; making.gd:127-137). | SAME | |
| 65 | Farm family eats first, 998 | "THEY ARE THREE THEY CAN PRODUVE 30" | A family farm: 4 posts, 37.6 FOOD at full (240 x 1/6 x 0.94, type_table.gd:254-256); three adults on 4 posts make 28.2 at full level and yield. | SAME | Close to the user's 30, not exactly: the 6% size penalty and 4 posts. |
| 66 | Farm family eats first, 998 | "TAKE SIX OUT OF THIRTY" | family_take wants need + up to one month's store = 2 x persons (6 for three). | SAME | |
| 67 | Farm family eats first, 998 | "SELL 24 AND THAT SHOULD BE ENOUGH TO HIRE ONE PERSON" | At start prices 24 x 39.43 = 946 against a G starting salary of 194. Hiring reads hire_wanted, not money, except the advert. | SAME | |
| 68 | Job advert once, 1007 | "you pay the first time not every consecutive month after" | Rules._advertise pays only posts not yet paid for; record["advertised"] kept while open (rules.gd:382-392, 432-450). | SAME | |
| 69 | Price cap, 1016/1018 | "5% CAP", "a price moves at most 5% ... same up and down" | K_PM 50; step = 50 x s/(1+s) per mille, full 50 only when nothing sold (rules.gd:46, 111-116, 139). Every price step: item prices and the builders' BW (rules.gd:76, 89). No other code moves a price (rents and Colony Stores are fixed). | SAME | |
| 70 | Output 5%, 1022 | "25?! 5!!! CHANGE IT!!!" (output moves at most 5% a month) | G_PM 50. A cut is <= 5% of the level. A rise is 50 x s/(1+s) per mille of max(level, one post's share of full), at least 1 per mille of full (rules.gd:190). | DIFFERENT | Below one post's share the rise is far more than 5% of the level (family farm, 4 posts: from level 0 or 10 per mille it rises by up to 12 per mille of full in a month). Bob's reading with Wilma's yes, not the user's. |
| 71 | When output is lowered, 1031 | "only lowered if over 50% of offered goods is not sold 3 months in a row" | Rules.output_rule lowers in ANY month with anything unsold: down = step_pm(G_PM, unsold, sold) (rules.gd:175-190). No 50% threshold, no count of months. | DIFFERENT | Lowers on any unsold amount, the same month; the rule needs > 50% unsold three months running. |
| 72 | When output is lowered, 1037 | "A CUT IS 5%" | Cut = level x 50 x unsold/(unsold+sold) / 1000 (e.g. 50% unsold -> 2.5%; 5% only when nothing sold). | DIFFERENT | Cut is not 5%; it is 5% x s/(1+s). |
| 73 | When output is lowered, 1037 | "IF THERE'S IS A FOURTH MONTH LOWER AGAIN" | No run of months is kept. | DIFFERENT | No streak counter; it cuts every month with unsold. |
| 74 | Farms don't shut, 1046 | "FARMS DON'T SHUT" | Rules.staff_to_posts 19a: after the unpaid layoff, any plant with staff_count == 0 is closed "NO_STAFF" (rules.gd:346-347), farms included. staff_count excludes the family, so a family farm with its family on it is shut once its hired hands go. Nothing reopens it. (Also building.gd:629 closes a plant at opening if the law refuses.) | DIFFERENT | Farms are still shut for NO_STAFF; no farm exemption in the tree. |
| 75 | Rent doubled, 1057 | "double the rent" | TypeTable.HOME_RENT_PM 2000: a new home 193.96 (was 96.98) (type_table.gd:30, 365-366); Landing.SHELTER_RENT 97 (was 48) (landing.gd:54). | SAME | |
| 76 | One worker feeds ten, 1066 | "10 purple each" | FARM row 24 posts, 240 FOOD (type_table.gd:68). Per size after the size penalty: FAMILY 4 posts 37.6 (9.4 each), SMALL 8 / 76.8 (9.6), AVERAGE 16 / 156.8 (9.8), LARGE 24 / 240 (10.0). | SAME | Exactly 10 only for LARGE (size penalty). |

## 2. Readings, proposals and starting numbers with no user words behind them

| Line / place | Whose | What it says | Built the same? |
|---|---|---|---|
| 772: 24 months | ours (Ella/Wilma) | programme window | SAME (PROGRAMME_M 24) |
| 61b "a little extra" = a tenth | Wilma | EXTRA_PM | SAME (100) |
| 61b "how many farms they want" | Wilma | need less farms standing and planned, over a family farm's full output | SAME (Grants.wanted) |
| 15c "the start" = until the first plan asks for a quote | Wilma | | SAME (first_quote_month) |
| 15c: a newly signed plan that waits is counted once as unmet | Wilma's decision, agreed with Bob | | SAME as the reading, but see row 21 against the user's words |
| 821 "up to 15%" caps the whole bar | Wilma | | SAME (150) |
| 821 "less if stressful" toward 5% | Wilma (starting number) | | NOT BUILT (step 9; constant unused) |
| 836 keeping workers: 3 months, advert a tenth, half output rising to full over 6 | Wilma | | SAME |
| 9.2 Bob's weighing (idle run, 1.75 months training loss) | Bob | | SAME (sum of 1000 - trained_pm(a), a=0..5 = 1750) |
| 9.2 Bob: a company that cannot pay the adverts hires none that month | Bob (proposal) | | DIFFERENT: it pays for as many posts as its money reaches (Otto's review, rules.gd:442) |
| 1009 advert paid in the month the post opens, hired or not | Wilma | | SAME |
| 9.2 negotiation: depends on the manager's skill and whether the company can pay | proposal | | DIFFERENT: fixed halfway, month 7 (Maja's numbers); chief "mgmt" is not read |
| 9.2 average among the same post tier | proposal | | SAME (avg_pay per tier) |
| 9.3 stock-up amount "as far as its money reaches and the goods keep; the further under, the more reason" | proposal | | DIFFERENT: Bob's numbers built instead: a fixed 80% threshold, at most 2 months' need, only goods spoiling < 5% a month |
| 9.3 a stock-up shortfall is not unmet demand | Wilma | | SAME (market history counts of AHEAD only what it bought) |
| 15e ship food a quarter dearer; a short budget buys by price | Wilma/Bob starting number | | SAME (250; food_by PRICE) |
| 15e farm is home from the day it opens; family FARM only | Wilma | | SAME (lives_on_own_farm needs an OPEN FAMILY FARM) |
| 15e winnings = month's earnings after everything; keep a month of expenses | Bob, Otto | | SAME |
| 15e family takes from the farm's whole stock | Bob | | SAME |
| 15f food, rent, then the store | Wilma | | SAME |
| 929 "max 5%" read as always 5%; "a whole month" = open after last month's hiring | Bob | | SAME |
| offer held after a 19a month | Bob, Otto | | SAME |
| starting-salary rent = plain average of open landlords; fallback half a new house | Bob | | SAME |
| 15a running cost at the starting salary (2 x rent) | Bob, with Wilma's yes | | DIFFERENT: still 300 x tier (row 58) |
| 15b output rise floor (one post's share, at least 1 per mille) | Bob, with Wilma's yes | | SAME as the reading, but exceeds the user's 5% (row 70) |
| 965 "3 5x" = 3.5 x rent | Wilma | | superseded by 2 |
| 991 "2.5" = 2.5 x rent | Wilma | | SAME (PLACED_RENT_PM 2500) |
| 1068 "10 purple" = 10 people | Wilma | | SAME |
| landing stock: 5 years of builders' work as MATERIAL 9700 / COMPONENT 1060; food 12 months 12000 | Bob, Wilma | | SAME |
| layoff months follow the law on the day of the layoff | Wilma | | SAME (WorkLaw.layoff_pay_months read at layoff) |
| the landing's placed staff start trained | Wilma | | SAME |
| 704 dead company's unsold stock: Wilma's opinion "the bank" | Wilma (user undecided) | | not built (step 5) |


---

<!-- part: part_law_anni -->
## Law: debts, layoff pay, unpaid wages, petitions, grants owed back, carried debts, the law's staff (Anni, read in the shared tree at 0c9e266)

| Plan ref | Words (whose) | What the code does today | Verdict | What differs |
|---|---|---|---|---|
| rebuild-company 9.2 "Keeping workers" (l.364) | user: "contracts should have clauses for payment after fire … say three months of vages" | `Households.layoff` (households.gd:268–284): owed = persons × their own hire row's `pay` × `WorkLaw.layoff_pay_months` | SAME | |
| 9.2 (l.367), ruled by the user ("you have the right of it") | Wilma's proposal, ruled: "owed three months of their own pay by the company" | `LAW_LAYOFF_PAY_MONTHS` default 3 (law_data.gd), read by work_law.gd:27; own pay = the hire row's pay | SAME | |
| 9.2 (l.368), ruled | "It is part of the contract set on hire." | months read from the lever on the day of the layoff, nothing stored on the hire row (Wilma's decision 2026-11-17, told to the user in 15e; no user ruling on it) | DIFFERENT | not fixed at hire: a later change of the law applies to people already hired |
| 9.2 (l.368), ruled | "The number of months is a law the government can change." | legislative NUMBER lever, range 0–12 (the range is Anni's) | SAME | |
| 9.2 (l.370), ruled | "A company that cannot pay it still owes it: it becomes a debt like unpaid wages" | `_layoff_pay` (households.gd ~309): pays what the account reaches, the rest `Justice.owe(…, "LAYOFF_PAY")`; `_owe` owes it whole, due next month (`NO_PLAN_KINDS`, justice_ops.gd:1133) like UNPAID_WAGES | SAME | |
| 9.2 (l.370), ruled | "and can end the company" | petition 12 months past due (`_petitions`, `PETITION_MONTHS` 12); `_liquidate` → `EconFace.insolvency_court_liquidation` returns false: no company can end | NOT BUILT | nothing can end a company before step 5 (law-face section 4 "Until step 5") |
| 9.2 (l.376), ruled | "It applies to builders" | `Rules` calls `Households.layoff` for every company type (rules.gd:345, 373) | SAME | |
| 9.2 (l.394), Bob's proposal | rule 19a: "laid off as now, and owed their layoff pay as a debt" | rules.gd:345 reason UNPAID → `Households.layoff` → layoff pay / LAYOFF_PAY debt | SAME | |
| 9.2 "Unpaid wages" (l.447) | user: "Record it" | `pay_wages` (households.gd ~440): the unpaid rest per pool → `Justice.owe(…, "UNPAID_WAGES")`; PAY row has "owed" | SAME | |
| 9.2 (l.447) | user: "make them pay after" | `collect_debts` (justice_ops.gd:276) every month in JUSTICE, after the month's wages, oldest first, as the balance allows; `debt_received` books it as "wages" | SAME | (seed 1, 60 months: DEBT company→pool 7 transfers, 2,851 credits) |
| 9.2 (l.447) | user: "if they refused take it to court" | refused = 12 months unpaid past due (Bob's reading, with the user); one petition per company (`justice.petitioned`); the doorway refuses every wind-up; no court exists | NOT BUILT | nothing reaches a court: a petition row and a refusal row only (the plan line: "the court is step 5") |
| 60b (l.1106) | (Wilma's decision 12.9; no quote) "The grant is owed back. What the founder cannot pay goes to court like any debt" | `Grants.reclaim`: from the plan's account, then the founder's own (Wilma 2026-11-17), the rest a GRANT liability; `collect_debts` takes it monthly from the founder's account until released | DIFFERENT (from the line) | "goes to court": no court; instead the collector takes it monthly from the founder's own account (Wilma's decision, no user words) |
| 60c (l.1103) | (decision) "their debts are settled or carried, they go back into the pool" | `release_founder` → `Justice.carry_debts`: OPEN rows marked carried, never collected, nothing from the pool | SAME | "carried" = Wilma's reading |
| law-face 3 (l.~125) | (Anni's paper, from v8) "A fine owed and unpaid for twelve months makes the purse petition the court, which winds the company up" | petitions for FINE, COMPENSATION, LAYOFF_PAY, UNPAID_WAGES after 12 months; once per company; refused by the doorway | SAME with its "until step 5" | |
| law-face 3 "Until step 5" (l.140) | (Anni) "Any fine raised before the court exists is recorded as owed and waits." | no fine is raised (seed 1, 60 months: 0 FINE rows, 0 to the fines account); but the fine code, if reached, pays from the account at once and `collect_debts` would collect the rest monthly | DIFFERENT (latent) | a fine would not wait: collected now (Wilma's collection decision contradicts this line) |
| law-face 3 "Collection" | Wilma 2026-11-17: "a debt nobody collects is a fault, not a design" | `collect_debts` as described | SAME | Wilma's words, not the user's |
| law-face 5.3 / 12.10, 69 "Until then" | (Anni) "Accidents may happen from production at step 3. They are published and counted, but nobody pays" | nothing produces a workplace accident: the type table has `accidents` per 1000 workers (type_table.gd:58) but no code reads it | NOT BUILT | the paper puts it at step 3 |
| law-face 12 | (Anni, on 12.10, 70) "The law's own staff are hired and paid by the salary rules … from step 3" | judges, inspectors, permit office still come from levers and the staff system; no person hired or paid; only state companies' placed staff get wages (`STATE_WAGES`, landing.gd `purse_month`; placed at 2.5 × rent) | DIFFERENT | not hired or paid as people in step 3 |

**Lines with no user words behind them, and what was built (law):**
- Small-firm instalments (`PLAN_PARTS` 8 over `PLAN_MONTHS` 24 below `SMALL_FIRM_REV_WREF` 200 W_ref a year): v8 code, in no plan paper. Built for every kind except UNPAID_WAGES and LAYOFF_PAY, including GRANT (a founder has no revenue, so a founder's grant debt is always in 8 instalments).
- `PETITION_MONTHS` 12 for every kind: from v8 fines; for layoff pay and wages it is Bob's reading of "refused", not yet answered by the user.
- `NO_PLAN_KINDS` (wages and layoff pay owed whole): Anni's decision, from "a debt like unpaid wages".
- Collection order (wages first, then debts oldest first): Wilma's and Anni's decisions.
- Months of layoff pay follow the law on the day: Wilma's decision (against "set on hire", row above).
- The layoff lever's range 0–12: Anni's.
- A grant owed back taken from the founder's own money before any debt: Wilma's decision.
- "Carried" = stays OPEN, never collected, nothing from the pool: Wilma's reading.
- One petition per company until the court answers: Wilma's decision.

**Money in a seed-1, 60-month game (0c9e266, every ledger transfer by memo):** nothing the law charged: no fine, fee, licence charge, court award or royalty; the fines account never moved. The law's only money is `DEBT:` collections of wages and layoff pay owed to pools (7 transfers, 2,851 credits). Not the law's, but money with no plan line: the politics stub world provider pays 5,000,000 credits from outside into an account named "treasury", separate from the government's treasury `gov:treasury` (stub_world_provider.gd:73, "founding funds", month 0).


---

<!-- part: part_land -->
## Land (read in the shared tree at 0c9e266; spot-checked by Anni)

**Whose words.** No land line in the papers is the user's own words except:
- the 8.3 quote: "the last one has to do with land and if they get enough they can buy another building and continue there";
- the 9.8 town-grid quotes (homes and owning, step 7);
- DECISIONS A37, which is Wilma's summary, not verbatim: "the government owns all land at founding and companies and households can buy plots (lease also allowed)".

Rebuild-company 12.1 point 3, 53, 60b and 67 are Wilma's decisions. Law-face section 8 is Anni's paper.

| Plan words (whose) | What the code does today | Verdict | What differs |
|---|---|---|---|
| 12.1.3 "Land belongs to the colony at landing." (Wilma; A37) | land_law.gd:5,101–119: with no title row the government owns it, OWNED, UNZONED. `ensure_rules` writes "the colony holds all land" | SAME | |
| 12.1.3 "A plan buys the land it builds on from whoever owns it" (Wilma) | `terms` (land_law.gd:511–513) refuses any key not owned by "gov" ("not the colony's to sell"). `transfer_title` exists but nothing calls it | DIFFERENT | Only the colony can sell; there is no purchase from a private owner |
| 12.1.3 "at the land price (the value of its cells)" (Wilma) | `Site.land_price` (transport/site.gd:394): the plan's own building bill at starting prices × `LAND_SHARE` 0.10 × the place's value_pm/1000. In the country only the tile's centre cell counts | DIFFERENT | The price depends on the type and size built, not only the cells. Land law's per-cell `land_value_fn` is not what a plan pays |
| 9.8 "10% of the home's building bill, scaled by the cell's value (proposal: the 10%)" | `LAND_SHARE` 0.10 is applied to every type; `TypeTable.LAND_PM` 100 is also inside every starting price | DIFFERENT in scope | A proposal written for homes is used for all types |
| 12.1.3 "A buy-out buys the land and the building together." / 53 "debts go with the plant" / 67 "refuse an offer below…" (Wilma) | no buy-out code | NOT BUILT (step 6) | |
| 60b "The land bought and the half-built building belong to the founder and can be sold; another plan may take them over." (Wilma) | `Building.give_up` (building.gd:329–353) does not pass the title; it stays on `plan:N` and the founder is disowned; there is no sale or take-over path | DIFFERENT | The founder never holds the land and cannot sell it; under a lease, rent would keep being charged to the emptied plan account and booked as debt |
| law-face 8 reads: "each cell's value … land law's `land_value_fn`" (Anni) | the plan's sale reads `Site.land_price`, not `land_value_fn` | DIFFERENT | Two land prices (agreed by Terra and Anni, not the user) |
| law-face 8 reads: "the zone" (Anni) | `terms`, `LawCompany.may_sign`, `Site.zone_allows` | SAME | |
| law-face 8.2 "A plan buys or leases its land from its owner before it signs" (Anni) | `sign_round` (building.gd:258–287): checks the account covers land plus quote, `Site.buy_land` → `LandLaw.sell`, then signs. Money goes plan → treasury, memo `LAND_SALE` | SAME on timing; DIFFERENT on "from its owner" | Only from the colony |
| law-face 8.2 "at the land's value × `LAW_LAND_PRICE_FLOOR_PCT` for every buyer" (Anni) | `terms` charges the full `Site.land_price`. The floor (× 90%) is only logged; `sell` passes `price_ok: true` | DIFFERENT | 100% of the bill-based price, not value × the floor |
| law-face 8.2 "The old fixed 90% for companies goes" (Anni) | `_floor_pct` reads only the lever; default still 90 | SAME | default 90 |
| law-face 8.2 lease rent "land's value × the bank's interest rate … instead of our fixed 0.6% a month" (Anni) | `LEASE_YIELD_PER_MONTH` 0.006 (land_law.gd:22) | DIFFERENT | Still a fixed 0.6% a month; no bank rate read |
| law-face 8.4 "`SELL` and `LEASE` stay" (Anni) | `LAW_LAND_DISPOSAL` default SELL | SAME | Fallbacks disagree: "LEASE" in land_offer/grant_land/law_query, "SELL" in `terms` |
| law-face 8.4 "KEEP … lease-only, at double the lease rent" (Anni) | rent × 2.0 under KEEP | SAME | |
| law-face 8.5 Zoning: five zones; unzoned allows every use (Anni) | `ZONES`, `ZONE_USES` as written; `zone()` exists but nothing calls it, so every key stays UNZONED | SAME (rules) | The government has no act that zones in a game |
| law-face 8.6 "a lessee behind for `LAW_EVICTION_NOTICE_MONTHS` loses the lease. The old fixed 3 months goes" (Anni) | `ARREARS_LIMIT` 3 is a constant in `report_arrears`, which nothing calls. `_collect_rent` turns unpaid rent into a `LAND_RENT` debt and the lease never ends for arrears | DIFFERENT | Still the constant 3, and unreachable |
| law-face 8.6 "Land with people on it then goes to an eviction" (Anni) | `_end_lease` → `request_eviction`, only when a lease expires | Partly | |
| law-face 8.7 Expropriation at the land's value (Anni) | `expropriate`: compensation = land_value + lease rent left, capped at 120 months; moves no money (the hook is never registered); no caller outside opt-in road law | NOT USED | The 120-month cap has no plan line; compensation is never paid |
| law-face 8 "Until then": title and price at step 3; leases and arrears at step 5 (Anni) | title and price at step 3: SAME. Lease rent collection `_collect_rent` runs every month from step 3 | DIFFERENT (timing) | Lease code is live at step 3; it does nothing only because the default is SELL |
| law-face 13 doorway act "pass title of land and building in a buy-out or sale" (Anni) | no title act in econ_face; `pass_holder` (plan → company, land only) | NOT BUILT | |
| build order step 6 "land sales" (Wilma) | the colony's sale is at step 3; sales between owners are not built | DIFFERENT from the build-order line | The plan's line still says step 6 (law-face 14 asked Wilma to move it) |
| A37 "companies and households can buy plots (lease also allowed)" (user, Wilma's summary) | only plans buy; no household buys land | NOT BUILT | |

Defaults today: `LAW_LAND_DISPOSAL` SELL; `LAW_LAND_PRICE_FLOOR_PCT` 90; `LAW_EVICTION_NOTICE_MONTHS` 3; constants `LEASE_YIELD_PER_MONTH` 0.006, `MAX_LEASE_MONTHS` 1188, `ARREARS_LIMIT` 3, `LAND_SHARE` 0.10.

**Land lines with no user words, and what was built from them:**
- 12.1.3 a plan buys at the land price (Wilma): built as `LandLaw.sell` + `Site.buy_land`, with the default switched to SELL (DECISIONS J37 had LEASE).
- Buy-outs, 53, 67 (Wilma): nothing built.
- 60b the founder's land (Wilma): only a comment on `pass_holder`.
- 9.8 "(proposal: the 10%)": built for every type.
- One land price = the plan's own bill (Wilma 2026-11-17; Terra and Anni): built.
- A country tile in sixths by holder (Terra and Anni): built (`plots`).
- law-face 8.2 value × floor (Anni): not built that way. Lease at value × bank rate (Anni): not built.
- law-face 8.4 KEEP lease-only at double rent (Anni): built.
- law-face 8.6 arrears limit = the lever (Anni): not built.
- `LAND_SALE` counts as capital, not income (Wilma, step-3 joins): built.
- The title passes to the company at the opening (Wilma, step-3 joins): built.
- Old DECISIONS J37 items carried over in the code: 99-year leases, the arrears limit 3, expropriation ≥ 100% plus the lease left, the RESERVE zone, the caretaker ban on SELL_LAND/ZONE_LAND/EXPROPRIATE.

**Land acts in a step-3 game with no line in the plan papers:**
1. `Site.land_price` uses starting-price bills, so land never reprices.
2. One price is split across a plan's keys, with one "land bought" row per key (hence 111 rows).
3. Caretaker ban: when `world.caretaker`, SELL_LAND is prohibited and every plan waits for its land.
4. The title passes plan → company at the opening (`pass_holder`; 94 rows), with no money moving. This is in the step-3 joins only.
5. Lease rent collection from step 3 (`_collect_rent`): money from the lessee to the treasury, the unpaid rest a LAND_RENT debt, and no end to the lease. Dormant under SELL.
6. A 99-year lease expires and files an eviction.
7. One holder, one plot per tile; at most 6 sixths per type per tile.
8. The landing shelters and the government companies stand on "gov" land with no title and pay nothing (landing.gd:136–137).
9. A given-up plan's land stays titled to `plan:N`.


---

<!-- part: part_law_sweep -->
# Kept law code in a default step-3 game: what it does to companies, households, money and levers

Read-only audit of the shared tree at HEAD 0c9e266 plus the working-tree changes, 2026-11-18. Nothing in the repo was edited.
I wrote a scratch run script at `scratchpad/law_audit.gd`, in `C:\Users\simon\AppData\Local\Temp\claude\2d9b615807f12236\735336d8-bdcc-45cb-9d1f-e751a72ca3cb\`. It makes a game with `GameSim.make(1)`, lands it with `Landing.land`, steps it 60 months, and writes `scratchpad/law_audit.out`.

## What the run showed

- **Opt-ins:** `meta["on"]` is `[]`, and `RoadSafety.on` returns `true`.
- **Law money:** the only law ledger rows were `DEBT:UNPAID_WAGES` company→pool (3 rows) and `DEBT:LAYOFF_PAY` company→pool (4 rows). There were none to or from `gov:fines_revenue`, `law:victim_fund` or `party:*`.
- **Tables (row counts):**
  - empty: `licence`, `permit_application`, `case`, `violation_track`, `unlawful_track`, `victim_award`, `law_closed`, `inquiry`, `lobby`, `takeover`, `donation_track`;
  - `liability` 648 rows: LAYOFF_PAY 341, UNPAID_WAGES 307;
  - `company_register` 57 rows;
  - no emergency was declared, and `gov_owed` was empty.
- **Logbook LAW rows:** may sign 57, registered 57, may open 57, programme ended 5, owed 648, petition 8, wind up refused 5, debt paid 7. These counts are lower than the brief's 111/94/94. The tree has changed since that run, so the counts differ, but the same kinds of rows appear.
- **Facts:** LAW_LEVER_EFFECTIVE 7, ECON_LEVER_EFFECTIVE 13, STUB_LEVER_EFFECTIVE 17, LAW_CHARTER_AMENDED 2, LAW_PETITION_SENT 1, LAW_CONSTITUTION_ADOPTED 1, LAW_ORDINANCE_DEEMED 1, LAW_DISTRICTING_EFFECTIVE 1.
  - There were no crisis facts of magnitude 50 or more.
  - There were no COMP_WORKPLACE_ACCIDENT and no POL_DONATION facts.
- **Levers the law wrote** (through `run_pipeline`, `end_programme` or `home_world_amend`):
  - LAW_STAFFING_RATIOS 0→1, LAW_POLICE_BUDGET 1000→1200, LAW_REVOKE_AFTER_CONVICTIONS 3→5, LAW_FARE_CAP 100→70, LAW_TRANSPORT_OPERATION 0→1, LAW_INVESTOR_PRIVILEGES 1→0, LAW_PUBLIC_SECTOR_STRIKE 1→0;
  - LAW_CHARTER_QUOTA_SHARE 40→30 and LAW_CHARTER_PRICE_PCT 35→50 (both by `home_world_amend`);
  - ECON_UNEMPLOYMENT_BENEFIT_RATE 40→72, ECON_PENSION_RATE 35→75;
  - ECON_FAMILY_FARM_GRANT 50→60→80→0 at month 24, then →90→100, then →0 at month 58; the other three grants 50→0 at month 24;
  - seven STUB_* levers.
- **What reads those levers:** the economy, population, transport and planet code read only LAW_LAYOFF_PAY_MONTHS, LAW_ROAD_TOLL and LAW_RETIREMENT_AGE. They read none of the LAW_ levers above. They do read the ECON_ benefit, pension and grant levers. The STUB_ levers feed only the stand-in world's indicators (`stub_world_provider.gd:90-110`).

The coordinator's own tally at 0c9e266 found the same: no law money apart from the DEBT: collections, and no staff task charges.

## How the opt-ins are read

| Opt-in | How it is read | On in a default game? |
|---|---|---|
| CRIME | `crime.gd:64` — `meta["on"]` has "CRIME" | **No.** `game_sim.gd:13` sets `meta["on"] = []` and nothing appends to it. |
| POLICE | `police.gd:56` | No |
| PRISONS | `criminal.gd:55` | No |
| PRIVATE_ROADS | `road_law.gd:65` — needs both PRIVATE_ROADS and FREIGHT_ROADS | No |
| ROAD_SAFETY | `road_safety_law.gd:43` calls `RoadSafety.on`, which is `return true` (`transport/road_safety.gd:45`) | **YES, always on.** The header comments in both files still say "opt-in". |
| E171 (charter) | `charter_ops.gd:137` | No |

## The doorway (`econ_face.gd`): acts the law calls

These return a plain answer and do nothing:

- `insolvency_court_liquidation` → false (used by `_liquidate`, which is excluded from this audit);
- `finance_gov_pay` → 0 and `finance_spend_line` → no-op (used by media);
- `households_pay_media_wages` → 0 (media);
- `pop_casualties` → 0 (road-safety deaths);
- `labor_occupation_of` → "";
- `unions_*` → empty;
- `actions_headroom` → 0.

These read real data:

- `EconFace.running` and `facts_emit`;
- `annual_revenue` exists, but **the law never calls it**. `justice_ops.annual_rev` (line 1057) still calls the old `annual_months`/`annual_sum12`/`annual_last_month`. Those read `pl_ring` and `pl_last`, fields the rebuilt company record does not have, so **annual revenue is always 0 for the law**.

The law's own acts on the economy do not go through `econ_face`. They are in `law_company.gd`: `may_sign`, `register`, `may_open` and `reopen_licensed` (which calls `Company.reopen_plant`). The economy calls them from `building.gd:242` and `building.gd:626-629`.

---

## 1. Table of acts

"Active" means it ran in the seed-1 run. "Reachable" means it is on in a default game but nothing triggered it in seed 1.

| Act (function, file:line) | Active in a default step-3 game? | What it touches, and how | Plan line that covers it | Does the code do what the line says? |
|---|---|---|---|---|
| `LawCompany.may_sign`, law_company.gd:159 (called by building.gd:242 in COMPANY_AI) | **Active** (57 rows) | **Company (plan).** It decides whether a plan may sign with a builder; if not, the plan waits ("waits: the law"). It checks the zone on every site key and, for each licence the type requires, files `LawOps.apply_licence` (no fee). In practice: only FARM can be founded (`month.gd:27`), FARM is not hazardous, and all land is UNZONED (nothing outside land_law calls `LandLaw.zone`), so it always says ok and only writes a Logbook row. | law-face 2: "Until step 6: every plan and plant is lawful as it stands, with no permit, licence or fee. The permit office has an empty queue" (Anni's paper; not the user's words). Also 12.10, 66: "Licences and permits work as before" (Wilma's decision), with permits at step 6 in the build order. | **DIFFERENT in the code, SAME in effect today.** At step 3 the code already requires HAZARD and EXTRACTION licences, because LAW_LICENCE_REGIME_HAZARD and _EXTRACTION both default to REQUIRED (law_data.gd:376-381). A MINE, PROCESSING, MEDWORKS or POWER plan would file a licence application and the permit office would take it into its queue. Zoning can also make a plan wait, though law-face 2.3 makes the zone a permit criterion at step 6. The header comment (law_company.gd:121-125) describes a licence regime at step 3. None of this bites while only FARM can be founded. |
| `LawCompany.register`, law_company.gd:179 (called by building.gd:626) | **Active** (57) | **Company.** It moves any licence and application records from the plan id to the company id, and writes a `company_register[company]` row = {plan, month, holders (owner shares), type}. | None says there is a register. law-face 1.1: "It keeps no copy of a company's fields." 1.2 lists the law's own records (licences, violations, cases, titles, takeover reviews) and does not list a register. | **DIFFERENT.** The register copies the holders and the type at opening. The code comment calls it a "dated snapshot by design", but no plan line allows it. |
| `LawCompany.may_open`, law_company.gd:196 (called by building.gd:627; when not ok, building.gd:629 calls `Company.close_plant(...,"LAW")`) | **Active** (57) | **Company / plant.** When a required licence is missing, the plant is closed by law and listed in `law_closed`. For FARM it is always ok, so only a Logbook row is written. | law-face 2.2: a hazardous plant needs a licence before it opens (step 6). law-face 2 "Until step 6" (see above). | **DIFFERENT in the code, SAME in effect** (same reason as may_sign). A hazardous plant would be closed at step 3. |
| `LawCompany.reopen_licensed`, law_company.gd:210 (JUSTICE) | Inactive: `law_closed` is empty | **Company / plant.** It calls `Company.reopen_plant(...,"LAW")` once licences are held. | law-face 2.7 and 13 "close a plant by law, and reopen it" (step 6) | Not reached. Same remark as may_open. |
| `Ops.process_permits` and `_queue_renewals`, law_ops.gd:684 and 669 | Inactive (no applications, no licences) | Law records. A granted application creates a licence (`grant_licence`, law_ops.gd:315). No money moves: there is no fee code anywhere. | law-face 2 (step 6; until then "an empty queue") | SAME today: the queue is empty. Note that `LICENCE_MONTHS` is fixed at 60/120 (law_company.gd:128); law-face 2.7 plans a lever at step 6. |
| `Ops.run_pipeline` → `_make_effective`, law_ops.gd:460 / 578 (DECISIONS) | **Active** (7 LAW, 13 ECON and 17 STUB levers made effective) | **Lever.** It writes `world.levers` for every enacted lever. Through the ECON levers it reaches **money to households**: the benefit and pension rates are read by the purse (`Landing.purse_month`), and the grant levels by Grants. The LAW levers set (STAFFING_RATIOS, FARE_CAP, TRANSPORT_OPERATION, REVOKE_AFTER_CONVICTIONS, POLICE_BUDGET, PUBLIC_SECTOR_STRIKE, INVESTOR_PRIVILEGES) are read by nothing in the rebuilt economy. | 12.10, 63: "Levers: every lever politics reads by name stays where its thing still exists, with its effect built new" (Wilma's decision). law-face 1.3: a lever whose effect is not built "does nothing until its step … the law screen marks it 'not in force yet'" (Anni's decision). | **SAME** for writing the levers. Part of law-face 1.3 is not built: nothing marks a lever "not in force yet" (no such flag in law_data or law_ops). LAW_TRANSPORT_OPERATION 1 and LAW_FARE_CAP are set with no effect, as 1.3 says they should be. |
| `Ops.end_programme`, law_ops.gd:972 (called by grants.gd:388) | **Active** (5: four grants at month 24, the farm grant again at month 58) | **Lever:** a grant lever is set to 0 at once, with "programme ended" and an EFFECTIVE enactment. `_supersede` cancels any LEGAL or SCHEDULED change already on its way for that lever. | 12.9, 61a, user's words: "when a grant ends, they reset to zero so they have to start over on where to put it; grants should be limited time for when you can apply". The 24 months is "a starting number of ours". | **SAME** on the reset to zero. One extra the plan does not have: a new level the government had already enacted (LEGAL or SCHEDULED, not yet in force) is cancelled by the sunset, so that decision is lost. The plan says only that "a new programme needs a new decision by the government". |
| `CharterOps.home_world_amend`, charter_ops.gd:87 (called by politics home_world.gd:150, 152, 387 and by `answer_petition`, charter_ops.gd:333) | **Active** (2: QUOTA_SHARE 40→30, PRICE_PCT 35→50) | **Lever.** It writes the charter levers directly, outside the pipeline. Nothing in the rebuilt economy reads them. | law-face 11: "The charter quota (12.11, 107) … at step 10 … Until step 8 (10): no charge is taken". law-face 1.3 (Anni's decision). | SAME (no effect before step 10). |
| `CharterOps.petition_home`, charter_ops.gd:325 | **Active** (1) | Facts and a petition record only. No company or money. | none needed | n/a |
| `Ops.amend_constitution`, law_ops.gd:396 (called by party_life.gd:1137) | Reachable, not seen | **Lever:** LAW_PERSONAL_MANDATE, directly. | none (political; outside the company plan) | n/a |
| `Ops.emergency_tick` → `end_emergency`, law_ops.gd:302 / 276 (DECISIONS); `declare_emergency` is called by emergency_politics on ECON_FAMINE | Reachable (Households emits ECON_FAMINE); not seen in seed 1 | **Lever:** at the end of an emergency, every L.EMERGENCY_LEVERS lever goes back to its default, and pending emergency enactments are CANCELLED. | law-face 7 mentions only "during a declared emergency" (price gouging) and requisition "in an emergency" (step 8). No line covers emergency levers reverting. | **NONE** |
| `Justice._file_new_cases` part 4: contract disputes, justice_ops.gd:574-592 | **Reachable today.** building.gd:582 emits `ECON_CONTRACT_PAYMENT_MISSED` when a contract stops after 3 unpaid months. Not seen in seed 1 (no LAW_CASE_FILED). | **Company / money (in intent).** It files a CONTRACT case, 30% of the time. It reads `f.data.project` and `f.data.amount_due`, but the rebuilt fact carries `contract`, `client` and `owed`. So `proj` = "", `p` = {} (and `world.table("project")` is created), the owner defaults to **GOVERNMENT**, the contractor is the company with id **""**, and the claim is **0**. The dedupe key "ECON_CONTRACT_PAYMENT_MISSED\|" is the same for every contract, so at most one case is ever filed per game. A claimant win produces a LAW_RULING `against_government` (rule-of-law indicator −) and pays 0. | law-face 4, "Other debts that go to court": "a building contract the client stopped paying (12.9, 56)", at step 5. "Until step 5: no company can end, so the court hears none of these cases." 12.9, 56 (Wilma's decision): "The builder stops after three unpaid months." | **DIFFERENT.** It is filed at step 3, against the wrong party (the government instead of the client plan or company), by a contractor with no id, for 0. |
| `Justice._file_new_cases` parts 1–3: unlawful-government challenges, staff legal challenges, permit-denial appeals, justice_ops.gd:528-573 | Reachable (politics, staff tasks, `land_law`/`road_law`/`work_law` `proceed_unlawfully`); not seen. Part 3 needs DENIED permits, of which there are none. | **Money (treasury):** if the claimant wins, the government pays LITIGATION_COSTS (`_final`, justice_ops.gd:691). **Lever:** `_revert` (1049) and justice_ops.gd:689 write `world.levers` back to their lawful value. | law-face 4: "The court's other work goes on as now: crime, defamation, the government's unlawful acts, appeals." Anni's paper, no decision mark. | SAME ("as now"). |
| `Justice._settlements`, justice_ops.gd:596 | Reachable only through the CONTRACT case above | **Money:** respondent→claimant COMPENSATION through `_pay`. With the faulty case: GOVERNMENT→`co:` with amount 0, so no money moves. | as for CONTRACT cases (law-face 4, step 5) | **DIFFERENT** (as above) |
| `Justice._process_courts` → `_decide` → `_final`, justice_ops.gd:617 / 637 / 661 | Reachable; no cases in seed 1 | **Money:** COMPENSATION, DAMAGES and LITIGATION_COSTS through `_pay`. An unpaid company part becomes a COMPENSATION liability (`_pay`, 1209-1213). An unpaid treasury part goes to `gov_owed`. **Company:** ENFORCEMENT → `_fine` and `_repeat_ladder` (licence REVOKED, `_liquidate`). ADMIN_APPEAL → `_grant` licence. **Lever:** UNLAWFUL_GOV → `_revert`. | per case type, rows below | see rows below |
| `Justice._fine`, justice_ops.gd:1067 (from ENFORCEMENT cases and `party_finance._donor_strike`) | Inactive: no violation records, so no ENFORCEMENT cases, and no donations. The brief's evidence agrees: no FINE. | **Money:** company→`gov:fines_revenue`; what it cannot pay becomes a FINE liability. **Company:** a SEVERE conviction, or a repeated SERIOUS one, suspends licences. | law-face 3: a fine "is a share of the company's yearly revenue, with a least amount in reference wages, times LAW_FINE_SCALE"; "Until step 5 … nothing to fine. Any fine raised before the court exists is recorded as owed and waits." 12.8, 55 (Wilma's decision). | **DIFFERENT if reached.** `annual_rev` is always 0 (old `pl_ring`/`pl_last` reads), so every fine is the floor alone and the cap = the floor. A fine raised before step 5 is not "recorded as owed and waits": it is taken from the company's account at once (justice_ops.gd:1090-1093). |
| `Justice._repeat_ladder`, justice_ops.gd:906 | Inactive (no convictions) | **Company:** licences REVOKED, `_liquidate` (excluded; the doorway answers false, so it returns early). | 12.10, 68: "The court can wind a company up after repeated convictions, as before" (Wilma's decision); law-face 4 (step 5) | Not reached. |
| `_final` TORT branch, justice_ops.gd:717-731; `_pay` to VICTIMS → `law:victim_fund` and `_award`, 1194-1204 / 891 | Reachable through road safety (next row) and `_stress_torts` / `cause_revealed` (no source of their facts today) | **Money:** respondent (company account or treasury) → `law:victim_fund`, and a `victim_award` row. **Nothing pays the fund out to households:** the comment names "EconVictims.monthly", which does not exist (grep: no reader of `victim_award` or `law:victim_fund` outside justice_ops). | law-face 12: "The victims' fund is the law's and pays households, as now" (Anni's paper). | **DIFFERENT.** Money paid in stays in `law:victim_fund`; no household receives it. |
| `Justice._pay_victims` → `_pay_gov_owed`, justice_ops.gd:899 / 992 | Inactive (`gov_owed` is empty) | **Money:** treasury → whoever a court order was for, oldest first. | law-face 4 / 12 ("as now") | SAME (no line asks for more). The function name says "victims", but it only pays the treasury's arrears. |
| `RoadSafetyLaw.justice`, road_safety_law.gd:204 (JUSTICE) | **Reachable — ROAD_SAFETY is always on.** It needs a `TRANSPORT_ROAD_ACCIDENT` with a refused pass, or a neglected private road. Not seen in seed 1. | **Money:** it files a TORT against the GOVERNMENT (public road) or the company owning the road; the claim is 15 reference wages per death and 2 per injury. The winning claim is paid treasury → `law:victim_fund` (see above). Deaths are always 0, because `EconFace.pop_casualties` returns 0, so only injuries count. | 12.4, 33 (Wilma's decision): "road safety … part of the rebuild and on." No line on road torts. law-face 5's "Accidents … nobody pays for them until the court exists at step 5" is about work accidents. | **NONE** for the payment. The road-accident court case moves treasury money at step 3, into a fund nothing pays out. |
| `RoadSafetyLaw.monthly` → `apply_statutory`, road_safety_law.gd:113 (DECISIONS) | Ran: the `speed_law` table has 5 keys. It sets limits only when LAW_SPEED_NEAR_HOMES > 0 (default 0). | Roads (link speed limits). No company, household or money. | 12.4, 33 | n/a |
| `Ops.discover`, `decay_greed_evidence`, `Justice._inspect`, `_accident_reveals`, `_stress_torts`, `_crisis_inquiries`, `_reactivate_licences` | Run every month; nothing is reached (no tracked violations; no COMP_WORKPLACE_ACCIDENT emitter; no crisis fact of magnitude 50 or more in seed 1, though `health_signal.gd:64` can emit one) | Law records and facts. Only through cases do they reach money or companies (TORT, ENFORCEMENT). | law-face 3 (detection), 5.3 (accidents, step 5) | SAME today (nothing to find). |
| `Justice.sync_judges` / `retire_judges`, justice_ops.gd:117 / 148 | **Active** | Creates judge persons up to LAW_JUDGES. **No pay:** no money moves. | law-face 12: "The law's own staff are hired and paid by the salary rules with the government as employer (12.10, 70) from step 3: judges, inspectors, the permit office, the competition authority." 12.10, 70 (Wilma's decision). | **DIFFERENT.** At step 3 they are made from the lever and nobody pays them. No salary rule and no treasury charge — this matches the coordinator's "no staff task charges". |
| `PF.run`, party_finance.gd:102: `_scan`, `_leaks_and_tips`, `_process_investigations` | Run, but find nothing: no POL_DONATION, because the `donation_offer` table has no writer in the rebuild and there are no unions | Parties; a fine on companies through `_donor_strike`. | law-face 12 / 12.10, 72: donations at step 9 | SAME (nothing before step 9). |
| `PF._public_funding`, party_finance.gd:143 | Reachable if LAW_PUBLIC_PARTY_FUNDING is raised (default 0; not raised in seed 1) | **Money:** treasury → `party:<id>` per seat per month. | none | **NONE** |
| `competition_law.monthly` (`favour_scan` and takeover reviews), competition_law.gd:126 | Inactive: nobody calls `request_takeover` or `lobby`, so `lobby` and `takeover` are empty | Companies (takeover decisions); facts. | law-face 6 (step 6), 12 (lobbying, step 9) | SAME (nothing to review). |
| `road_law.monthly`; `crime`, `police`, `criminal`.monthly | **Off** (opt-in flags not set) | — | law-face 12: road_law "dormant"; police until step 4 | SAME |
| `CD.check_revocation`, charter_deal.gd:136 | Runs; returns at once (no signed deal: `deal()` is {}), even though LAW_INVESTOR_PRIVILEGES went 1→0 | Facts only | — | n/a |
| `DL.ensure_founding_district` / `DL.tick` / `_apply`, districting.gd:297 / 207 / 215 | **Active** (1: every area in "The Colony") | Area→district assignment. No direct company, household or money act; Grants and media read districts. | 9.12 (user's words): "no sectors beyond landfallpoint" | SAME (one district, no laid-out sectors). |
| `Ops.ensure_*`, `CO.ensure_m12`, `Media.ensure_rules`, `Land.ensure_rules`, `maybe_adopt_constitution`, `Vis.note_government`, `write_indicators` | Active | Law rules, facts and indicators. No company, household, money or lever. (`maybe_adopt_constitution` changes rule levels, not levers.) | — | n/a |
| `Media.run`, media_ops.gd:426 (called from law JUSTICE) — `_finances` / `_owner_cover` / `_press_subsidy` / `manage` / `_refund`, 1921 / 1895 / 1873 / 1945 / 2004 | Runs once `EconFace.running` is true | **Money:** the state Gazette's cost is never paid (`finance_gov_pay` and `households_pay_media_wages` are plain answers, 0). Party papers (founded with party money, MEDIA_FOUNDING) are covered from `party:`; with wages paying 0 they reach deficit and close after 6 months; `_refund` returns their cash to the owner. If no owner account exists, `PartyLife._household_receive` finds no "hh" table and **sends the money to `Ledger.EXTERNAL` (out of the colony)**, party_life.gd:837-838. The JOB_ADVERT income (company→Gazette, called by Bob's rules) collects in `media:<gazette>` and never leaves: it is a STATE paper, so `manage` does not run and there is no payout. | 9.2 (user's words): "costs of hiring, articles in the newspaper"; the advert is paid to a newspaper. law-face 12 / 12.6, 48: newspapers become companies at step 4. The table in section 10: "Paying the press, press subsidies … (open: whether an outlet is a company)". | Advert payment: SAME as 9.2. **No line** covers where the papers' money goes at step 3: the advert money piles up in the Gazette, and the fallback can send money to EXTERNAL. |

## 2. Acts with NO plan line

1. **`LawCompany.register`**, law_company.gd:179. It writes a `company_register` copy of the holders and type at opening. The plan lists the law's records without a register and says the law "keeps no copy of a company's fields".
2. **`Ops.end_emergency` lever revert**, law_ops.gd:276-298, via `emergency_tick`. Emergency levers go back to their defaults, and pending emergency enactments are cancelled.
3. **`Ops.end_programme` cancelling a change already on its way**, law_ops.gd:978 (`_supersede`). The reset to zero itself is covered by 61a.
4. **`RoadSafetyLaw.justice` road torts**, road_safety_law.gd:204. Always on; the treasury (or a road-owning company) pays into `law:victim_fund` at step 3.
5. **`law:victim_fund` never paid out.** `justice_ops._pay` / `_award` takes money in, and nothing pays households. The plan line (law-face 12) says it pays households, so this is a code-vs-line difference. What is uncovered is the money stranded there at step 3.
6. **`PF._public_funding`**, party_finance.gd:143. Treasury → parties when LAW_PUBLIC_PARTY_FUNDING > 0.
7. **`Ops.amend_constitution`**, law_ops.gd:396, and **`CharterOps.home_world_amend`**, charter_ops.gd:87. Both write levers directly, outside the pipeline. Only the general law-face 1.3 (Anni's decision) covers them.
8. **Media money at step 3** (media_ops.gd `_finances` / `_refund` / `_household_receive` → EXTERNAL; advert money accumulating in the Gazette).
9. **The faulty CONTRACT case** (justice_ops.gd:574-592). Its line (law-face 4) puts such cases at step 5, against the client. The code files it now, against the government, for a company with no id and a claim of 0.

## The main differences between code and plan lines (repeated from the table)

- **Licences at step 3:** may_sign and may_open demand HAZARD and EXTRACTION licences because both regimes default to REQUIRED. The plan says "Until step 6: every plan and plant is lawful … no permit, licence or fee." Today this is masked only because FARM is the only foundable type.
- **Zoning at step 3:** may_sign makes a plan wait on its zone. Today this is masked because nothing zones land.
- **Fines:** revenue is always 0, so a fine is the floor alone. A fine is taken at once, not "recorded as owed and waits".
- **Law staff:** judges and the other law staff are not paid at step 3, though law-face 12 / 12.10, 70 say they are paid from step 3.
- **The victims' fund** does not pay households.
- **The CONTRACT case** as above.
- **Not built:** law-face 1.3's "not in force yet" mark on levers.

