# Step 4 reading: all items (every good, its type-table row, its market)

Prepared 2026-11-18 for the step-4 brief. Read-only: papers and the code in the tree as it stood today. Scope: goods
and their markets only. Work-slot types, founding as such, and freight are other sessions' readings; they appear here
only where a good touches them.

Marks used:
- **The user, verbatim**: copied unchanged, spelling included, with file:line and date.
- **(ours: X)**: a session's own proposal, reading or decision, not the user's.
- Line numbers are as of today. MASTER-PLAN.md is being written to while this was read; its line numbers had already
  moved by about nine lines during the reading.

The step itself (rebuild-company.md:1389-1390, plan text, not the user's words): "4. **Everything that is sold, and how
it moves, together.** All items; the types with work slots (public services, shops, utilities on the grid); freight on
the roads with the queue, carriers' prices, trucks and truck workshops."

How step 4 is to be planned, the user, 2026-11-18, verbatim (MASTER-PLAN.md:1080): "Ah yes this is what i want a full
stage plan with who dose what, who reviews when what stages within it that go in in what order". Recorded there as
Ella drafting planning/rebuild-step4-brief.md (not in the tree yet).

Who builds (rebuild-company.md:1426-1428, the plan's own split): "Bob the rules, market, bank and freight; Otto building
and housing; Maja people and public services; Ella services, unions and what politics reads; Terra the ground, the
roads and the map; Anni the law's hold; Wilma the doorway, the start-up, politics' side and putting it together."

---

## Rulings that cover every piece below

- "it's just a 2d array of wich items a company type makes, if they pick from first or second output"
  (rebuild-company.md:104; also inside the order at :23 and MASTER-PLAN.md:480; 2026-11-17).
- "Food output plus into the same no more godawfull single sided junk" (inside the order, rebuild-company.md:23,
  2026-11-17). The plan's line from it, not the user's words: "Food is an item like any other, and a food producer is a
  company like any other" (rebuild-company.md:137).
- "No it's for all goods don't overcomplicatev with individual rules built seperatly by godsi hope you have not done so
  for all other food rules making the single object for plant a mess" (MASTER-PLAN.md:1110; rebuild-company.md:54;
  2026-11-18). Then, to Wilma's list of six places where the plant object named one type or good, with her
  recommendation for each (the family's work, plants shut for lack of staff, the builder's crew, the rent and a
  household's needs read from the type table and the needs list, a "grows from the land" column for the season):
  "Good, those" (MASTER-PLAN.md:1114). Then the corrections "No it's not for the Order family" (:1118), "Plants should
  shut" (:1122), "FAMILY FARMS FAMILY FARMS don't shut" (:1126). Wilma's summary of the outcome (ours: Wilma's
  wording, MASTER-PLAN.md:1130): "the season, the builder's crew, the rent and a household's needs are read from the type
  table and the needs list, not from a name".
- "Same company types can come but not their code or balancing" (rebuild-company.md:31; MASTER-PLAN.md:507,
  2026-11-17).
- "set a credit prices we are going to have to adjust it anyway i don't have a sheet of what costs what so i can't tell
  you what it should cost" (rebuild-company.md:34; MASTER-PLAN.md:564, 2026-11-17).
- "Every production needs 4 rules: when to increase price, when to decrease price, when to increase production, when
  to decrease production, rooted in the actual market" (eight-rules.md:3, 2026-11-15; written for the old economy).
- "All company types needs to be able to be created as private, but maybe they're is only ever enough work for say one
  powerplant then the conitions for new ones don't get switched on" (MASTER-PLAN.md:238-240, 2026-11-16;
  rebuild-company.md:572).

---

## 1. The item list

**The user's words.** None name items one by one. The list rests on "a 2d array of wich items a company type makes"
(above) and on "Same company types can come but not their code or balancing".

**In the tree.** `game/sim/economy/type_table.gd` `ITEMS`, lines 38-52: 13 items, each with unit, freight mass,
spoiling per mille a month, and whether it travels only on the grid.

| Item | Mass | Spoils ‰/month | Grid | Notes in code |
|---|---|---|---|---|
| FOOD | 1 | 10 | no | |
| BREAD | 1 | 250 | no | "one person's food for a month, baked" |
| FINE_FOOD | 1 | 100 | no | |
| MINERAL | 2 | 0 | no | |
| MATERIAL | 2 | 0 | no | |
| COMPONENT | 1 | 0 | no | |
| TRUCK | 0 | 0 | no | |
| CONSUMER | 1 | 0 | no | |
| CLOTHING | 1 | 0 | no | |
| FURNISHINGS | 2 | 0 | no | |
| MEDICAL | 1 | 5 | no | |
| ENERGY | 0 | 0 | yes | |
| WATER | 0 | 0 | yes | |

Not items (type_table.gd:54-55): building work "@BW", freight "@FREIGHT", and client kinds ("@household", "@pupil",
...). `TypeTable.is_item` (:205) is the test every other file uses.

**The sessions' own (ours).**
- The whole list, units, masses and spoiling (ours: Bob, rebuild-type-table.md:45-70, draft 1, 2026-11-17).
- FOOD spoils 1% a month, not the old 2% (ours: Bob, rebuild-type-table.md:67).
- "BREAD and FINE_FOOD spoil fast, so nobody stocks far ahead on them" (ours: Bob, rebuild-type-table.md:69).
- TEXTILE's FOOD input "stands for fibre crops ... It saves an item nobody else would use" (ours: Bob,
  rebuild-type-table.md:121).
- Plan section 4's inputs column names "energy, water, mineral, material, component, food, consumer goods, medical"
  (rebuild-company.md:110, plan text).

**Missing.** Nothing in the list itself. Quality and reputation of consumer goods are "Left out for now"
(rebuild-company.md:1365, 12.12, ours: Wilma's decision).

**Whose.** The type table: Bob (rebuild-type-table.md is his; plan 13: "Bob the rules, market").

---

## 2. The type-table rows for goods, and what can exist today for each item

**The user's words.**
- "it's just a 2d array of wich items a company type makes, if they pick from first or second output"
  (rebuild-company.md:104).
- Trucks as a second output: the plan states it as a ruling, without quote marks: "A components works can build trucks
  as special orders, always at the lowest quality; a truck workshop builds them better" (rebuild-company.md:132-133).
- "10 purple each" (MASTER-PLAN.md, the ruling "one farm worker feeds ten people", 2026-11-18; Wilma's reading: 10
  people each).

**In the tree.** `type_table.gd` `ROWS`, lines 66-170. Goods rows (way `_ITEM_WAY` or `_GRID_WAY`, :62-63):

| Type | Line 0 (first) | Line 1 (second) | Inputs (line 0) | Foundable today |
|---|---|---|---|---|
| FARM (:68) | FOOD 240 | | none | yes |
| BAKERY (:71-75) | BREAD 1,500 | FINE_FOOD 400 | FOOD, ENERGY, WATER | no |
| MINE (:76) | MINERAL 2,000 | | ENERGY, WATER | no |
| PROCESSING (:79) | MATERIAL 800 | | MINERAL, ENERGY, WATER | no |
| COMPONENTS (:82-86) | COMPONENT 200 | TRUCK 4 | MATERIAL, ENERGY | no |
| CONSUMERF (:87) | CONSUMER 1,200 | | MATERIAL, COMPONENT, ENERGY | no |
| TEXTILE (:90) | CLOTHING 1,000 | | FOOD, MATERIAL, ENERGY, WATER | no |
| FURNITURE (:93) | FURNISHINGS 300 | | MATERIAL, COMPONENT, ENERGY | no |
| MEDWORKS (:96) | MEDICAL 600 | | MATERIAL, COMPONENT, ENERGY, WATER | no |
| POWER (:99) | ENERGY 120,000 | | MINERAL, WATER | no (state company, no plant, at landing) |
| WATERWORKS (:102) | WATER 120,000 | | ENERGY, MATERIAL | no (state company, no plant, at landing) |
| TRUCKSHOP (:113-117) | "@truck repair" 12 | TRUCK 1 | COMPONENT, ENERGY | no |
| SHOP (:130-133) | "@household" 400, way sells ITEM, reach IN_REACH | | ENERGY | no (one state SHOP, Colony Stores) |

Rows that use goods as inputs without making one: HAULIER ENERGY (:109); OFFICEBLOCK ENERGY, WATER (:122); BANK ENERGY
(:126); CAFE FOOD, FINE_FOOD, ENERGY, WATER (:134); CHILDCARE FOOD (:140); ELDERCARE FOOD, MEDICAL (:143); CLINIC
MEDICAL (:146); SCHOOL MATERIAL (:149); PRISON FOOD (:155); NEWSPAPER MATERIAL (:167); every row's build bill and
upkeep in MATERIAL and COMPONENT (:270-280).

Founding: `game/sim/economy/month.gd` `FOUNDABLE: ["FARM"]` (:28), read by `founding` (:131-137). The comment (:26-27):
"Step 3 is tested on food alone first (plan 13): every other type is in the table but nobody may found it until food
passes."

Starting prices: `TypeTable.start_prices` (:322-368) solves every price together from the rows; an item two rows make
(TRUCK) starts at the cheaper (:351-354). The paper's figures (rebuild-type-table.md:47-61, e.g. FOOD 60.7) were
worked with a FARM of 156; the code's FARM is 240 by the user's "10 purple each", so the code's prices differ from the
paper's table (the plan gives FOOD's start as 39.43, rebuild-company.md:178).

**Per item, today** (from the code paths below):

| Item | Maker can be founded | Anyone offers it | Who orders it today |
|---|---|---|---|
| FOOD | yes (FARM) | farms; Colony Stores (12,000 landing, landing.gd:58) | households (households.gd:598-646) |
| BREAD | no | nobody | nobody |
| FINE_FOOD | no | nobody | nobody (CAFE never orders inputs, section 5) |
| MINERAL | no | nobody | nobody |
| MATERIAL | no | Colony Stores (9,700) | building sites (building.gd:433-466); plant upkeep (building.gd:471-497) |
| COMPONENT | no | Colony Stores (1,060) | building sites (building.gd:433-466) |
| TRUCK | no | Colony Stores (20) | nobody |
| CONSUMER, CLOTHING, FURNISHINGS | no | nobody | nobody |
| MEDICAL | no | nobody | nobody (CLINIC, ELDERCARE never order inputs) |
| ENERGY, WATER | no | cannot be offered | cannot be ordered (market.gd:56) |

**The sessions' own (ours).** Every row's numbers (ours: Bob, rebuild-type-table.md:89-109, 150-178, "All are
**(Bob)**, to be set in testing"); the pricing rule "making price at full output + the build bill (with its land) spread
over 10 years of full output" (ours: Bob, rebuild-type-table.md:22-23); the 34 old names to 30 rows (ours: Bob,
rebuild-type-table.md:194-228); "A farm takes no power or water at the start" (ours: Bob, :113); "Every other goods row
needs the grid" as a result, not a rule (ours: Bob, :117); the build bills (ours: Otto with Bob, :245-281).

**Missing.** No type but FARM can be founded (known: audit-rules-otto.md:357 row 3, audit-rules-ella.md:32,
audit-rules-maja.md B56, audit-rules-anni.md:338 row 7). Nothing missing in the table's columns for goods except the
season column (section 11).

**Whose.** The rows: Bob. `FOUNDABLE`: month.gd is Wilma's conductor (month.gd:2).

---

## 3. The market for goods other than food

**The user's words.**
- Rule 1 (2026-11-18, MASTER-PLAN.md, the ruling "a price rises on the buyers my own farm turned away"):
  "Ah that's my mistake, no orders go unfilled by my farm,  every seller that comes looking and goes somewhere else for
  food,  not orders unfilled by anyone"; "Important oders that are filled before they come to my farm does not count";
  "Yes that's the point everyone they pass raises that means only the one they ended on   or never reached lowers this
  contributes to price shift and swapping farms that get to sell,  and stabalises the wares roughly on that level"
  (rebuild-company.md:178, 190). Said about food and farms; the plan carries rule 1 to every seller.
- Rule 2: "Now, instead, add a rule that the more inventory you have, the more you reduce your price"
  (MASTER-PLAN.md:305; date not given on the line, in the 2026-11-16 section).
- "If something else than price stops sales it should not count on adjusting price!!" (rebuild-company.md:195).
- 23a, on bread, 2026-11-14: "if they want to but can't buy, bread goes too high — the company can win by lowering"
  (rebuild-company.md:1066-1067).
- "ship food should be considered less desierable,bwich would men the swap happens sooner" (MASTER-PLAN.md:881,
  2026-11-17). Said about food.
- Grid: "things can be done in two different ways based in company types how its this a problem?"
  (rebuild-company.md:120). The grid as a type's way of reaching the buyer is plan text marked **(open, section 14)**
  at :128, decided in 12.7, 49 (ours: Wilma's decision): "Power and water are companies whose way of reaching the buyer
  is the grid. They cannot be stocked."
- Trucks: 12.4, 32 (ours: Wilma's decision, rebuild-company.md:1087): "A truck is ordered from its maker, not bought
  cheapest-first off a market. The buyer chooses the maker by price and quality."

**In the tree.** `game/sim/economy/market.gd`.
- One book per item and area (header :5; `clear` :102-136 groups orders by "item|area" :114).
- Nothing in it names a good. `order` (:53-66) accepts any item; it refuses grid items: `if
  bool(TypeTable.ITEMS[item]["grid"]) ... return ""` (:56).
- `offers` (:80-94): only OPEN companies in the same area with a price for the item (:84); quantity is stock less
  "waiting" less the hold-back (:87). Ship goods ranked dearer by `SHIP_LESS_WANTED_PM` 250 for every item (:30,
  :90-92), not only food.
- `_clear_book` (:139-231): every open company in the area with a price for the item gets a signal even with nothing on
  offer (:144-148). `_came_looking` (:252-268) and `_turned_away` (:277-303) are written for any item; their comments
  quote the farm words.
- The month's summary per item and area is kept twelve months (`_summarise` :363-379, `history` :412); politics reads
  any item through `EconFace.market_month` (game/sim/core/econ_face.gd:28).
- Within one area only: no order reaches another area's offers (the freight piece).
- TRUCK is an ordinary market item: Colony Stores offers 20 at the starting price (landing.gd:58, `_stores` :150-160),
  through `Company.offer` (company.gd:111-123).

What it means for a company that sells two items: `Company.create` (company.gd:47-50) opens a price for every line's
item, so a BAKERY holds prices for BREAD and FINE_FOOD and a COMPONENTS works for COMPONENT and TRUCK, whichever line
it runs. `_clear_book` (:144-148) and `_came_looking` (:257-261) then count such a company as a seller passed for the
item it does not make, and `Rules.company_month` (rules.gd:74-80) runs the price rule and the hold-back on it.

**Missing (facts, no proposals).**
- No market path for ENERGY and WATER at all (refused at market.gd:56; making skips them, section 5). Already noted:
  audit-rules-terra.md:197.
- TRUCK sits on the market as an item; 12.4, 32 says a truck is ordered from its maker.
- No buyer of BREAD, FINE_FOOD, MINERAL, CONSUMER, CLOTHING, FURNISHINGS, MEDICAL or TRUCK posts an order anywhere
  today (sections 4 and 5).

**The sessions' own (ours).** One order book per item, cheapest delivered offer first (plan 9.3, rebuild-company.md:543,
plan text); 27 short goods shared in proportion (ours: Wilma, :1077); 23a (ours: Wilma and Bob's wording corrected,
:1064-1072); the quarter dearer for ship goods (ours: Wilma's starting number, rebuild-company.md:994; market.gd:27-29
applies it to every item); a household short of money buys by real price, "PRICE" order (ours: Wilma, 15e,
households.gd:684-688).

**Whose.** The market: Bob. The grid's way of reaching the buyer: the utilities piece (plan 13 step 4 names "utilities
on the grid"; the plan's split gives Bob freight and Ella services; nobody is named for the grid).

---

## 4. Households buying goods other than food

**The user's words.**
- "Okay i think we can take it wholesale as long as we make sure it fits in"; "Households, i mean we take how it works
  and transfer over not take the code" (rebuild-company.md:285-286; MASTER-PLAN.md:690; 2026-11-17).
- "Oh no wholesale does  not mean unchecked" (rebuild-company.md:310, 2026-11-17).
- On the order of paying: "what are you paying power and water on if you can't pay the rent?" (rebuild-company.md:322).
  The plan's result: "food, then rent, then water and power".
- "Good, those" to Wilma's recommendation that "a household's needs" be read "from the type table and the needs list,
  not from a type's or a good's name" (MASTER-PLAN.md:1112-1114, 2026-11-18).

**In the tree.** `game/sim/population/households.gd`.
- `NEED_PER_PERSON := {"FOOD": 1000}   # milli-units; step 3 is food alone` (:483).
- `post_orders` (:598-656): every line names FOOD: the need (:603), the store (:604), the family's take from its own farm
  (:614), the order (:624), the store order's offers and order (:635, :646). One budget line: "Step 3 has food alone,
  so the food line's budget is all the buyer's money" (comment :588).
- `after_market` (:725-770): FOOD only; spoiling only of FOOD (:752).
- `food_by`, `food_cost_of` (:684-702): FOOD only.
- `own_farm` (:658-664) names type "FARM".
- Moving between areas and pools carries every item in a household's stock (:1319-1328, :1398-1406), so the stock
  itself is per item.

**Missing.**
- No household buys BREAD, FINE_FOOD, CONSUMER, CLOTHING, FURNISHINGS, MEDICAL, ENERGY or WATER.
- The money-out order of plan 9.1 beyond food and rent: "water and power; the other essentials; then what is left,
  split between consumer goods, services, comfort spending, newspapers and saving" (rebuild-company.md:296-297, plan
  text of how the old side worked; verdict "keep" at :323).
- No choice between FOOD and BREAD. Plan text: "econ_staple | bakery goods preferred | the bakery row; the preference is
  the households' " (rebuild-company.md:751).
- The needs list is one entry; the households' code reads FOOD by name, not the list.

**The sessions' own (ours).**
- "What one person uses a month (proposal for Maja, who owns the household side ...): 1 FOOD (or 1 BREAD); 50 ENERGY
  and 50 WATER; 0.5 CONSUMER, 0.1 CLOTHING, 0.02 FURNISHINGS; 0.05 MEDICAL through the clinic" (ours: Bob,
  rebuild-type-table.md:72-78).
- BREAD "the households' preferred staple (econ_staple's place); counts as food" (ours: Bob, rebuild-type-table.md:50).
- "A household budgeting food at price plus freight, tax and the shop's margin | change | the shop is a company now; the
  household pays the shop's price" (ours: Wilma's first pass with Maja's check, rebuild-company.md:325).
- "Buying: essentials first, the rest split over goods, services, comfort, papers, saving | keep | every line now has a
  seller (12.6, 48)" (ours: same table, :323).

**Whose.** Maja (people; plan 9.1: "Maja owns the full check, line by line", rebuild-company.md:337).

---

## 5. Companies buying their inputs

**The user's words.** None on how a company buys inputs beyond the market and stocking up (section 7). Rule 19's
"Missing inputs are not a price signal" is plan text (ours: Wilma, rebuild-company.md:1055).

**In the tree.** `game/sim/economy/making.gd`.
- `post_orders` (:201-242): every open company whose line makes an item orders next month's inputs at its level, less
  stock, at `mini(worth, can)` (:228-230). Generic: no good named.
- It skips a company whose output is not an item (:209-211): services, builders, landlords, the SHOP never order
  inputs, so CAFE's FOOD and FINE_FOOD, CLINIC's and ELDERCARE's MEDICAL, SCHOOL's and NEWSPAPER's MATERIAL,
  CHILDCARE's and PRISON's FOOD are never bought.
- It skips grid inputs (:223-224).
- `input_worth` (:248-265): output price less the other inputs at today's cheapest offer (or starting price), over this
  input's share. Grid inputs are left out of the subtraction (:260).
- `make_plant` (:49-123): inputs taken from stock in proportion, the scarcest input limiting output (:92-110); grid
  inputs not needed ("power and water come over the grid (step 4); in step 3 no type that may be founded needs them",
  :100-101), so a plant needing them makes as if they were there.
- `month` (:29-45) makes nothing for a line that is not an item (:37-38).
- Building sites and upkeep buy MATERIAL and COMPONENT on the market as "SITE" buyers: `Building.supply_orders`
  (building.gd:433-466), `Building.upkeep_orders` (:471-497); `building.gd` `ITEMS := ["MATERIAL", "COMPONENT"]` (:44)
  is the bill's two goods.

**Missing.** Input orders for every type with work slots; grid inputs bought, paid and limiting output; the worth of an
input with grid inputs priced in.

**The sessions' own (ours).** The worth as "what the input is worth in what it makes and sells" (ours: Wilma's wording
in plan 9.3, rebuild-company.md:552-553, from the user's "like when they buy normaly"); the way it is computed (ours:
Bob, making.gd:245-247).

**Whose.** Bob (making and the market); Otto for site and upkeep orders; Ella and Maja for what services order (plan:
"Maja people and public services; Ella services").

---

## 6. Price, hold-back and output rules on goods other than food

**The user's words.**
- Rule 1's rise cap, 2026-11-18: "Easy fix at double it only climbs  1% and at four times it only ever climbs 0.5% and
  it still falls the same" (MASTER-PLAN.md:1104; rebuild-company.md:178), with "No it's for all goods ..." (above).
- The 5% cap: "TWENTY PERCENT WHAT HAPPENS TO THE FUCKING 5% CAP GOT FUCKING DAMNED IT GO BACK AND LOOK AT THE DAMNED
  RULES" (rebuild-company.md:204, 2026-11-18); rule 9: "if your going to cap it at 5% THEN DO THE SAME FOR BOTH"
  (:186).
- Output: "25?! 5!!! CHANGE IT!!! STOP HEDGING" (:207); "The production output is only lowered if over 50% of offered
  goods is not sold 3 months in a row" (:210); "A CUT IS 5% WHY IS THIS STILL A PROBLEM???? AND YES IF THERE'S IS A
  FOURTH MONTH LOWER AGAIN" (:217). All 2026-11-18.
- Hold-back: "It sells too cover all monthly expences" (rebuild-company.md:200); "I don't like hard rules you know that,
  but maybe a soft it will sell less just took keep afloat, build up stock for better prices, that's if your have not
  made everyone know all stocks at all times" (MASTER-PLAN.md:254-256, 2026-11-16).
- "The family farm is almost immune to it then,  that's fine, i think once farms fall below it there will be occelation
  but it's basically the farmers equivalent of dormant until needed" (MASTER-PLAN.md:1148, 2026-11-18). About the
  family farm.

**In the tree.** `game/sim/economy/rules.gd`.
- `company_month` (:70-103): for every item the company has a price for, the price rule (unless price-fixed), the
  hold-back, and the output rule only for the item of its current line (:74-82). No good named.
- `price_rule` (:130-153), `step_pm` (:121-126), `K_PM` 50 (:46): generic.
- `_rise_cap_pm` (:165-170) with `RISE_STEPS` (:162): against `TypeTable.start_price(item)`, any item or "BW".
- `hold_back` (:176-184) per item, against the company's one making price (`Making.making_price`, making.gd:177-192,
  which divides by the full output of its current line) and the whole company's `month_expenses` (:192-197).
- `output_rule` (:212-239), `G_PM` 50, `UNSOLD_MONTHS` 3: generic.

As the code stands, for a company holding prices for two items (section 3): each item is held back against the same
making price and against the whole month's expenses separately; the item it does not make gets price signals.

**Missing.** Nothing good-specific in these rules. What is not built is the second output (section 9).

**The sessions' own (ours).** Rule 1's built reading (ours: Bob, rebuild-company.md:178); "the original" is the
starting price of whatever is priced (ours: Wilma's reading, :178); k x s/(1+s) (ours: Wilma, 12.3, 15, :826-838); the
making price at normal full output (ours: Wilma, 12.3, 14, :821); 18, rule 3 does not act while holding back (ours:
Wilma, :1048); 22, work-slot types do not hold back (ours: Wilma, :1061).

**Whose.** Bob.

---

## 7. Stocking up on goods other than food

**The user's words.**
- "Company and people should be able to stock up if the price is low" (MASTER-PLAN.md:702; rebuild-company.md:546;
  2026-11-17).
- "No what's low should be against what its worth to the buyer, like when they buy normaly" (MASTER-PLAN.md:711;
  rebuild-company.md:550; 2026-11-17).
- Households and food: "I think citizens is the solution, they buy 2 units if food instead of one,  store it and use it
  in emergencies"; "They stockplie to have have six months of food in storage, i think as often as they can"; "The
  first, if your running low and don't know how long the ossue will last i don't think you wait" (rebuild-company.md
  15f, :995-1004; MASTER-PLAN.md:939-945; 2026-11-17); "You did not make what i said even I SAID THEY BUY DOUBLE UNTIL
  THEY FILL SIX MONTHS THAT WAS TOO EVEN IF OUT!!!!" (rebuild-company.md:1009, 2026-11-18). About food.
- "Mark that the government can order stockpiles to help in famin once we get back to politics, because that's great
  political debate" (MASTER-PLAN.md:954; rebuild-company.md:1416; 2026-11-17). Marked for step 8 and politics.

**In the tree.**
- Companies: `Making.post_orders` (making.gd:233-241): an AHEAD order up to two months' need held, only for inputs
  spoiling under `KEEPS_PM` 50 (:23), when the cheapest offer is at most `AHEAD_BELOW_PM` 800 per mille of the worth
  (:22). Generic over inputs.
- The market clears AHEAD after NEED and does not count an AHEAD shortfall for the sellers' rules or rule 7
  (market.gd:43-46, 157, 227-228, 371-375).
- Households: only the FOOD store (households.gd:498, 628-646), at any price.

**Missing.**
- Households stocking up on anything but food, and stocking up "if the price is low" at all (known: audit-rules-maja.md
  A29, A30; audit-rules-anni.md:467).
- The company numbers (80%, two months, the 5% spoil line) are ours, not the user's (known: audit-rules-anni.md:701,
  audit-rules-ella.md:60 and :206, audit-rules-otto.md:186, audit-rules-terra.md:296).

**The sessions' own (ours).**
- "how much: as far as its money reaches and the goods keep; food spoils, so nobody stocks far ahead on it" (ours:
  Wilma's proposal, rebuild-company.md:554-555).
- A stock-up order buys only what the month's own orders leave, at today's price; its shortfall is not unmet demand
  (ours: Wilma's decision, 2026-11-17, rebuild-company.md:556-561).
- `AHEAD_BELOW_PM` 800, two months, `KEEPS_PM` 50 (ours: Bob, making.gd:20-23).
- The landing stock as a stock-up source in month one: "For any buyer whose worth is above the starting price, that is
  'low' every month (9.3), so one plan or company may buy years of it in month one. That is a result." (ours: Bob's
  review in rebuild-building.md:322-324).

**Whose.** Bob (companies); Maja (households).

---

## 8. Spoiling of goods held

**The user's words.** None. The spoil rates are ours.

**In the tree.**
- `TypeTable.spoil_pm` (type_table.gd:210-211).
- Households: FOOD only (households.gd:752).
- Companies: no code spoils a company's stock. `Company.OUT_REASONS` lists "SPOILED" (company.gd:128) but nothing calls
  `stock_take` with it (grep over game/sim: no caller). The only reader of `spoil_pm` for companies is the stock-up gate
  (making.gd:237).

**Missing.** Spoiling of company stock for any item, FOOD included (not found in the six audits).

**The sessions' own (ours).** The rates (ours: Bob, rebuild-type-table.md:47-61, 66-70); "Storage space is left out
(12.12), so spoiling is the only cost of holding stock" (ours: Bob, :70).

**Whose.** Bob (company stock).

---

## 9. The second output

**The user's words.** "if they pick from first or second output" (rebuild-company.md:104); rule 3: "Also picks first
or second output" is plan text on rule 3's row (:180).

**In the tree.** `type_table.gd`: BAKERY, COMPONENTS and TRUCKSHOP have two lines. `company.gd` `create` sets
`"line": 0` (:62); nothing writes it again (known: audit-rules-anni.md:104, 128, 216; audit-rules-bob.md:22, 32, 161;
audit-rules-maja.md B8, B20; audit-rules-otto.md:24, 84; audit-rules-terra.md:129; audit-rules-ella.md:88). Rule 7
reads line 0 only: `Rules.work` and `work_qty` take `TypeTable.out_of(type, 0)` (rules.gd:762, 778); `_seen` counts a
plant toward the work only when its line makes line 0's item (:827, 836-838).

**Missing.** The choice and the switch.

**The sessions' own (ours).** "it picks by which pays (rule 3)" (plan text, rebuild-company.md:112); "24. The second
output is switched from one month to the next, at no cost" (ours: Wilma's decision, :1073); trucks from a components
works "always the lowest quality" (plan, :132).

**Whose.** Bob (rules).

---

## 10. Rules 7 and 8 for goods other than food

**The user's words.**
- "instead of reading the leftovers, they read an avrage of all avaliable jobs" (MASTER-PLAN.md:278, 2026-11-16;
  rebuild-company.md rule 7, :184).
- "All company types needs to be able to be created as private ..." (above).
- "AND WHEN I SAY THAT I DON'T MEAN REMOVE THE DAMNED SWITCH FOR IT What if for example we run 500 years at that poinr
  there might be a need for another powerplant" (MASTER-PLAN.md:246-247, 2026-11-16).
- "It does not see plans made, but they do see plans booked on builders notes and plans that have accepted grants"
  (rebuild-company.md 15a, 2026-11-17).

**In the tree.** `rules.gd`.
- `work` (:761-768) and `work_qty` (:777-796): the item of line 0, from the market's ordered quantity over twelve
  months. Generic. In the first year, months before the colony count at the household need: only for an item in
  `Households.NEED_PER_PERSON` (:787-791), today FOOD alone.
- So, from the orders that exist today (section 2): MATERIAL and COMPONENT have orders (sites and upkeep), so
  PROCESSING and COMPONENTS would read work; MINERAL, BREAD, CONSUMER, CLOTHING, FURNISHINGS, MEDICAL have none, so
  MINE, BAKERY, CONSUMERF, TEXTILE, FURNITURE and MEDWORKS read 0; POWER and WATERWORKS read 0 (grid items cannot be
  ordered).
- `running_cost` (:799-811) prices inputs at today's offers or the starting price, grid inputs included at their
  starting price.
- `Grants.wanted` (grants.gd:251-270) for BAKERY: "the same with bread ... It counts the whole food need, as if all ate
  bread" (comment :248-249), reading `NEED_PER_PERSON["FOOD"]` (:259).

**Missing.** Founding of any type but FARM (`FOUNDABLE`, section 2). Rule 7's signal for types with work slots
(`work` returns 0 for a non-item, :763: "services come with step 4") belongs to the work-slot reading.

**The sessions' own (ours).** 15a in full (ours: Bob's readings with Wilma's yes, rebuild-company.md:858-893); the
grant's sums for the bakery (ours: Wilma's reading, Ella builds, rebuild-company.md:1235; audit-rules-ella.md:70).

**Whose.** Bob (rules 7 and 8); Ella (grants); Wilma (`FOUNDABLE`).

---

## 11. Seasons beyond food

**The user's words.**
- "Good, those" to Wilma's list including "a 'grows from the land' column for the season" (MASTER-PLAN.md:1112-1114,
  2026-11-18).
- "I think two is better,  but also maybe the family can put some away for the hard months they know are coming"
  (MASTER-PLAN.md:930; rebuild-company.md:975-979; 2026-11-17). Plan text after it (ours: Wilma): "Whether a family
  should deliberately hold back from spending before a known hard season only matters once there is more to buy than
  food (step 4); it is noted for then, not built" (rebuild-company.md:980-983).

**In the tree.**
- `Making.yield_of` (making.gd:137-140): `if type != "FARM": return 1000`.
- `Site.yield_pm` / `_yield_parts` (game/sim/transport/site.gd:472-490): `String(wt["type"]) != "FARM"` returns no
  season (:478).
- No "grows from the land" column in `ROWS` (type_table.gd:66-170).
- Households save winnings they do not spend (rebuild-company.md:980-981, plan text); nothing holds money back for a
  known hard season.

**Missing.** The table column the user said "Good, those" to; the season read from it instead of the name "FARM" in
two places. Holding back before a hard season (marked for step 4 by the plan, not ruled).

**The sessions' own (ours).** 12.4, 34: "The planet sets a farm's yield by season and ecology" (ours: Wilma,
rebuild-company.md:1091); the yield formula (ours: Terra, site.gd:466-471).

**Whose.** Terra (the ground and the map: `Site.yield_pm`); Bob (the table column and `Making.yield_of`); Maja (a
household holding back).

---

## 12. Shops, and the landing stock as a seller

**The user's words.**
- "Okay materials come with the start not finished buildings 5 years worth of equipment  that never changed they are
  companies from the world. Tell me in any colony builder do you place out fucking plants from start????"
  (MASTER-PLAN.md:619; rebuild-company.md:693; 2026-11-17).
- "the goverment starts with its subsidiaries as before" (rebuild-company.md:572, 682).
- Shops: no user words. "services have no output but a client take in" (rebuild-company.md:113, inside the order :23).

**In the tree.**
- `landing.gd` `STOCK := {"FOOD": 12000, "MATERIAL": 9700, "COMPONENT": 1060, "TRUCK": 20}` (:58); `_stores`
  (:150-160) makes Colony Stores, a state SHOP, `price_fixed` true, and opens a price per item with `Company.offer`.
- SHOP row: way sells ITEM, reads UNSOLD, price ITEM, reach IN_REACH (type_table.gd:130-133); its line's out is
  "@household" (400 a month).
- `Company.create` opens no price for SHOP's "@household" line (company.gd:47-49); `Company.offer` (:111-123) lets only
  an IN_REACH type open a price for an item.
- Nothing makes a SHOP buy wholesale; Colony Stores only sells what it landed with. The market's `offers` has no reach
  test (market.gd:84, area only), so households buy straight from farms.
- `Rules.company_month` skips the price rule for a price-fixed company (rules.gd:78) but still runs `hold_back` on its
  items (:80), against `Making.making_price`, which for the SHOP divides by its "@household" output (making.gd:186-187).

**Missing.** A SHOP that buys on the market and resells; "within reach"; the shop's clients (work-slot reading).

**The sessions' own (ours).**
- The landing stock's size: "what the five builders can build in five years at full crews" (ours: Bob,
  rebuild-type-table.md:347-355); food in it (ours: Wilma's addition, rebuild-company.md:811, 702-703); trucks in it
  (ours: Wilma's decision in the step-2 brief, rebuild-type-table.md:319); sold at starting prices (ours: Wilma,
  12.2, 9, :811).
- "The landing stock caps prices. While it lasts, no colony maker of the same good can sell above the starting price"
  (ours: Bob's review, rebuild-building.md:325-326), a result to watch, not a rule.
- "48. Shops, cafés and the like are service companies with a client intake, so every line of household spending has a
  seller" (ours: Wilma, rebuild-company.md:1135).
- "(Bob, for Wilma to confirm:) a shop is a seller of items within the town grid's reach of homes. It buys wholesale on
  the market and posts its own price for each item; its client intake is how many households it can serve. Its rules 2
  and 4 read its unsold stock ... If Wilma reads 12.6, 48 as 'a shop sells only a service', the household side needs
  another way to buy goods." (ours: Bob, rebuild-type-table.md:183-192). No record found of Wilma's answer.

**Whose.** Wilma (the start-up: the landing and Colony Stores); Ella (services, so the shop as a client-intake type);
Bob (the market's side of a reseller).

---

## 13. Goods from the home world

**The user's words.**
- "They can't order when there's not a ship there to take the order. ... they have to ask for one when the ship is
  there, which means they have the full period of waiting every time." (rebuild-company.md:587).
- "1. Yes they may order in" (MASTER-PLAN.md:254, 2026-11-16; the question was material and components while no
  producer works) and "Why put so much fucking emphasis on the imports? Why? We talked about it as being a thing that
  was there if they needed it, not the primary means of getting resources." (MASTER-PLAN.md:314-315). The plan (9.6,
  rebuild-company.md:592-596) records that these were about the old code's monthly requests and are not a rule on when
  a colony may import: "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR".
- "ship food should be considered less desierable" (above): about food.

**In the tree.** `ship.gd` `order` (:167-200) takes any item but grid items; `home_price` (:158-160) = start price ×
`HOME_PRICE_PM` 2000 (:31). Nothing in sim calls `Ship.order` (known: audit-rules-otto.md:33, row 71 at :149, row 5
at :359).

**Missing.** Any caller; the government ordering for the colony (ship.gd:18 says "comes with the purse at step 8").

**The sessions' own (ours).** The home world's price at twice the starting price (ours: Bob, ship.gd:31,
rebuild-type-table.md:299); 26, no rule of ours on what may be imported (ours: Wilma, rebuild-company.md:1076).

**Whose.** Wilma (ship.gd's header: "Wilma, reviewed by Bob and by Terra for the port"). Exports and the charter quota
are step 10 (rebuild-company.md:1421; `law/charter_ops.gd:23` already lists `["COMPONENT", "MATERIAL", "MINERAL"]`).

---

## 14. Places in the economy's code that name one good or one type

**The user's words.** "No it's for all goods don't overcomplicatev with individual rules built seperatly by gods..."
and "Good, those" (above), with the corrections "No it's not for the Order family", "Plants should shut", "FAMILY FARMS
FAMILY FARMS don't shut" (MASTER-PLAN.md:1118-1126). The family's own work and the family farm not shutting are
farm-family rulings and stay on FARM by the user's corrections.

**In the tree** (grep over game/sim/economy and game/sim/population for item and type names):

| Where | What it names | Kept to the farm family by ruling? |
|---|---|---|
| company.gd:17 `FARM_TYPE`, :630 `is_family_farm_type`, :974 `close_plant` | FARM | yes (family farms don't shut) |
| making.gd:76 `make_plant` | FARM (the family's own work) | yes ("No it's not for the Order family") |
| making.gd:137-140 `yield_of` | FARM (season) | no: the season column (section 11) |
| transport/site.gd:478 `_yield_parts` | FARM (season) | no: the same |
| rules.gd:357-380 `needs_line`, `needs_food` | FOOD (a worker's needs) | the needs list; Wilma's summary names "a household's needs" |
| rules.gd:810 `running_cost`; building.gd:44, 86 | MATERIAL, COMPONENT (bill and upkeep) | the table's bill columns are those two goods |
| month.gd:28 `FOUNDABLE` | FARM | step 3's "food alone" |
| households.gd:483-770 | FOOD everywhere; FARM in `own_farm` :661 | the needs list (section 4) |
| grants.gd:55-57, 254-259 | FARM, BAKERY, HAULIER; FOOD need | the four grants are named by the user |
| landing.gd:47-58, 310 | POWER, WATERWORKS, ..., SHOP; STOCK items; FARM | the start-up |
| home_builders.gd:27 | BUILDER | the five builders |

**Missing.** Per the summary at MASTER-PLAN.md:1130 (ours: Wilma's wording): the season and a household's needs are
still read by name.

**Whose.** Bob (rules, making), Terra (site), Maja (households), Wilma (month, landing), Ella (grants).

---

## Questions

Points where the user's words do not decide. Plain questions; no answer is proposed.

1. Which goods does a household buy besides food, and how much of each a person needs a month? (Bob's figures at
   rebuild-type-table.md:72-78 are his proposal for Maja; the user has not ruled them.)
2. Does a household pay for water and power by what it uses, or as a fixed share? The user ruled only the order
   "food, then rent, then water and power".
3. Do households choose between FOOD and BREAD, and if so on what: price only, or a preference for bread?
4. Should households "stock up if the price is low" on goods other than food, and do they keep the six-month store
   only for food?
5. Should the government's stockpile (marked for politics) cover goods other than food?
6. Is a shop a reseller that buys goods on the market and sells them to households within reach, or a service that
   sells only client places? (Bob asked Wilma, rebuild-type-table.md:185-192; no answer found.)
7. Do households have to buy through a shop, or may they keep buying straight from a farm or works in their area?
8. Should company stock spoil each month at the item's rate, as the households' food does?
9. Is a truck sold on the market like other goods, as the landing stock now is, or only ordered from its maker
   (12.4, 32 is Wilma's decision, not the user's)?
10. Which goods other than food does a season touch: only FOOD from farms, or also others through the "grows from the
    land" column (TEXTILE's fibre, MINE outdoors)?
11. How many months of a known hard season should a family put away for, and does it hold back spending on other goods
    to do it? ("maybe the family can put some away for the hard months they know are coming" was said as a maybe.)
12. When a company's second output pays better, does it switch its whole plant, or can a plant split between the two
    lines?
13. Does a company that is not making its second item keep a price for it on the market meanwhile?
14. Which types may be founded in step 4, and in what order: all goods types at once, or one chain at a time
    (MINE, PROCESSING, COMPONENTS, then the workshops)? Step 3 opened FARM alone; the plan says "All items".
15. Before the bank lends (step 5), the type-table paper finds nobody can pay for a MINE, PROCESSING, COMPONENTS,
    CONSUMERF, MEDWORKS, POWER or WATERWORKS (rebuild-type-table.md:332, 336). Should step 4 test those chains with the
    government building them, with the bank brought forward, or report them as not reachable?
16. Do services (CAFE, CLINIC, ELDERCARE, SCHOOL, NEWSPAPER, CHILDCARE, PRISON) buy their goods inputs on the same
    market as companies, at the same worth rule?
17. While the landing stock lasts at its fixed starting price, should a colony maker of the same good be able to sell
    above it? (Bob's review calls the cap a result.)
18. May companies order goods from the home world as an everyday source for any good, limited only by the ship, or
    only when no colony producer works? (The plan reads the user's earlier "a thing that was there if they needed it"
    as about the old code's monthly requests.)
