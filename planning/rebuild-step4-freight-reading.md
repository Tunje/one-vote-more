# Step 4 reading: freight on the roads with the queue, carriers' prices, trucks and truck workshops

Prepared for the step 4 brief, 2026-11-18. Read-only reading of the plan papers and the tree; nothing decided here.

Conventions:
- **the user** = the user's own words, copied verbatim (spelling kept), with file:line and date.
- **(ours: X)** = the sessions' own design, proposal, reading or starting number, with whose it is.
- Line numbers are the files as they stand today. RC = planning/rebuild-company.md, MP = planning/MASTER-PLAN.md,
  TT = planning/rebuild-type-table.md, TD = planning/design-truck-drivers.md, RB = planning/rebuild-building.md.
- Code paths are under game/sim/.

General facts that hold for every piece below:
- Step 3 has no freight: "goods do not need trucks until step 4" (RC:1454, plan text, ours: Wilma). The conductor
  (economy/month.gd:68-120) calls no freight, carrier, truck or road function. `FOUNDABLE = ["FARM"]` (month.gd:28),
  so no haulier or workshop can be founded.
- The plan says of the old economy: "None of the code or numbers carries over" (RC:735). The old freight code is still
  readable in game_full_copy/sim/economy/ (econ_haulier.gd 262 lines with R8FR_QUEUE and R8FR_PRIVATE,
  econ_trucks.gd 651, econ_truck_shop.gd 572, econ_fleet.gd 283, econ_market.gd freight lines 34 and 150). It is not
  in the game.
- The transport folder (game/sim/transport) was NOT cut with the economy. It is Terra's old code, kept, and runs every
  month from the planet's NATURE tick (planet/planet_provider.gd:82 `Transport.step_month`).
- Who builds (RC:1426-1428, the user's order of 2026-11-17 at RC:1424, verbatim: "Get everyone involved give them
  peaces related to them make sure we get this done and atleast one other reviews each peace of code made"; the split
  itself is ours: Wilma): "Bob the rules, market, bank and freight; Otto building and housing; Maja people and public
  services; Ella services, unions and what politics reads; Terra the ground, the roads and the map; Anni the law's
  hold; Wilma the doorway, the start-up, politics' side and putting it together." Review pairs: Terra-Maja, Bob-Otto,
  Ella-Anni.

---

## 1. Freight demand: who needs goods moved, and the delivered price

**The user's words**
- RC:23 and MP:480 (2026-11-17, verbatim): "... then roads and supply networks since the same company can become
  freight that's done already ..."
- RC:196 and MP:338-340 (in the 2026-11-16 block, verbatim): "If something else than price stops sales it should not
  count on adjusting price!!" The plan's reading under it (RC:196, ours: Wilma): "A sale stopped by freight or the road
  counts neither as unsold stock (rules 2 and 4) nor as an unfilled order (rule 1)." MP:340-342 says the same of "want
  of freight, of a road, or of the buyer's money".

**The plan's own design (ours)**
- RC:543-544, 9.3 (ours: Wilma's plan text): "One order book per item ... The cheapest delivered offer fills first."
- RC:1082-1084, 12.4 point 30 (ours: Wilma's decision): "A buyer ranks offers by price plus freight. The sale is made
  before carrying; goods on the road are the buyer's."
- RC:1085, point 31 (ours: Wilma): "A builder's supplies are delivered to the building site by freight like any sale.
  'Up front' means at the site."
- RC:234, section 7 (ours): "A company ships from where its plant stands to where the buyer is."
- RC:84 and RC:87 (ours): the company's `stock` holds "what of it is waiting for freight"; `orders` keep WHY an order
  was unfilled "(price, freight, road, the buyer's money)".
- RC:1157-1159, 12.8 point 50b (ours: Wilma): a sale is "one record made by the market when the sale is agreed, which
  says who owns the goods, what is paid and whether they have been carried. The company, the bank and the carrier
  point to that record".
- RC:821, 12.3 point 14 (ours: Wilma): the making price includes "freight it pays".
- RC:1049-1058, points 19b and 20 (ours: Wilma): a company stopped by "a broken road" still pays its costs; "Months lost
  to freight, the road ... do not count toward the two years" of sales death.
- RC:1074-1075, point 25 (ours: Wilma): "Stock at the port waiting for a ship is waiting for freight, not unsold."
- RC:1519 (ours: the outside review as written in the plan): "A freight route fails | late goods, shortages, a company
  may fail | goods doubled, or gone without a recorded loss" is a fault.
- TT:47-63 (ours: Bob's table): freight mass per unit: FOOD, BREAD, FINE_FOOD, COMPONENT, CONSUMER, CLOTHING, MEDICAL
  1; MINERAL, MATERIAL, FURNISHINGS 2; TRUCK "drives itself"; ENERGY and WATER "grid only".

**What exists in the tree**
- economy/market.gd:5-8, header: "One order book per item and area ... the cheapest offer first ('The cheapest
  delivered offer fills first'; no freight in step 3, so delivered = posted)". Old? No: rebuilt in step 3 (Bob).
- economy/market.gd:80-96 `offers(world, item, area)`: a seller offers only to buyers of ITS OWN area
  (`String(c["area"]) != area` skips it) and offers `qty - waiting - hold`. So in a step-3 game there is no trade
  between areas at all; the market is per area, not per delivered price. Runs in step 3: yes.
- economy/company.gd:66, 178, 205-209: each stock line has a `"waiting"` field (milli-units waiting for freight). Nothing
  ever writes it above 0 (audit-rules-terra.md:130, audit-rules-bob.md:174).
- economy/market.gd:323-360 `_sell`: the sale record (table "sale") has id, m, item, qty, price, paid, seller, buyer,
  buyer_kind, order. It has no "carried" field and no place (50b asks for "whether they have been carried"). Goods move
  into the buyer's stock at once (`Company.stock_move`, or `stock_take` as SOLD for a household, plan or site).
- economy/type_table.gd:36-50 `ITEMS`: the "mass" column as in TT section 2 (TRUCK mass 0).
- economy/making.gd:174-191 `making_price(world, cid, other = 0)`: freight would go in `other`; every caller passes 0
  (audit-rules-bob.md:90, audit-rules-maja.md:184).

**What is missing**
- Any freight demand at all: who must have goods carried (seller's plant to buyer's area, builder's supplies to the
  site, imports from the port), the buyer ranking by price plus freight, orders reaching sellers in other areas.
- The sale record's carried / not carried state; goods "on the road" owned by the buyer.
- The freight cause on unfilled orders (WHY values today are only NO_MONEY, PRICE, SOLD_OUT, NO_SELLER: market.gd:36).
- Freight in the making price.

**Whose**: Bob (the market and freight). The sale record is Bob's (50b).

---

## 2. The freight queue

**The user's words**
- MP:400 (2026-11-16, verbatim), asked whether Bob may change how the transit authority's depot set its output: "Tell
  him to test if and if it does not work to just count the work que not passed work"
- MP:406 (2026-11-17, verbatim), on Bob's reading of the work queue: "That works"
- MP:410 (2026-11-17, verbatim), asked to merge R8FR_QUEUE and OFFICE_E99: "Yes to both"
- The context: these words were about the OLD game's public transit authority's depot (MP:398-412), not about carriers
  in general.

**The sessions' design (ours)**
- MP:404 (ours: Bob's reading, put to the user and answered "That works"): "unmoved freight stays in a real queue and is
  carried the following month; the queue is what still waits from last month plus this month's new freight orders, less
  what the other carriers take; the depot sets its crew on that queue."
- RC:232, section 7 (ours: the plan's carrying of that reading to every carrier): "What cannot be carried waits in a
  real queue and goes first the following month ... A carrier sets its crew and trucks on that queue. Goods waiting
  for freight are not unsold stock."

**What exists in the tree**
- Nothing in game/sim. The old queue is game_full_copy/sim/economy/econ_haulier.gd:117 and econ_market.gd:34, 150
  (switch R8FR_QUEUE), cut out with the economy. audit-rules-bob.md:174 and :220, audit-rules-anni.md:144,
  audit-rules-terra.md:168, audit-rules-otto.md:378: NOT BUILT (step 4).
- The only "waiting" today is the stock field above (never set) and FreightRoads' road-held freight (piece 9), which
  is a different thing: freight the roads could not take.

**What is missing**: the queue itself (where it is kept, per what, in what order it is served, who reads it), and
carriers setting crew and trucks on it.

**Whose**: Bob (freight).

---

## 3. Carriers' prices

**The user's words**
- MP:247-251 (2026-11-15, verbatim): "On private holliers its easy build them as if they're could be a profit to base
  making new companies on, and to reduce size on. They don't get skipped even if the rules won't be able to take affect
  because its free"
- RC:52-55 (2026-11-18, verbatim), the one-rule ruling: "No it's for all goods don't
  overcomplicatev with individual rules built seperatly by godsi hope you have not done so for all other food rules
  making the single object for plant a mess"; and "Good, those".
- The price caps that apply to every price (RC:199-205, 2026-11-18, verbatim): "TWENTY PERCENT WHAT HAPPENS TO THE
  FUCKING 5% CAP ..."; and MP:1095 (2026-11-18, verbatim): "Easy fix at double it only climbs  1% and at four times it
  only ever climbs 0.5% and it still falls the same" (built for every good in commit 92d5eff).
- Rule 9 (RC:185, verbatim, undated in the table): "if below making price climbing allways had priority if above
  lowering has priority ... THEN DO THE SAME FOR BOTH"
- RC:123-124, section 4: "They have empty work slots" (what rules 2 and 4 read for a type with nothing to stock).

**The sessions' design (ours)**
- RC:1082-1083, 12.4 point 30 (ours: Wilma): "A carrier posts a price per route, set by the same three price rules."
- TT:65 and TT:128 (ours: Bob's starting number): freight sells at 0.194 cr per unit-km at the start; "per route by the
  rules (12.4, 30)".
- MP:241-242 (ours: Wilma's reading): a private haulier "is paid for what it ... carries, so it has price rules 1 and 2".

**What exists in the tree**
- economy/type_table.gd:109-112 HAULIER row: `"way": {"sells": "FREIGHT", "reads": "EMPTY_SLOTS", "price":
  "PER_ROUTE", "reach": "ROAD"}`, line `"@FREIGHT"` qty 36000 unit-km. Rebuilt (step 2).
- economy/type_table.gd:320-366 `start_prices()` solves "FREIGHT" with the rest; :377-388 `start_price_of` returns it for
  PER_ROUTE. economy/company.gd:1057-1066 `_sells_key` keeps a carrier's price under the one key "FREIGHT". So today a
  carrier has ONE freight price, not one per route.
- Nothing applies rules 1, 2 or 9 to a freight price; no route exists to price.

**What is missing**: the route (what it is), a price per route, what a carrier's rules 1 and 2 read (empty slots of
freight room; the queue), and the price rules running on it.

**Whose**: Bob (rules and freight).

---

## 4. Carriers as companies: hauliers, truck drivers, freight room and the fleet

**The user's words**
- RC:23, MP:480 (2026-11-17): "the same company can become freight".
- MP:238-240 (2026-11-15, verbatim): "All company types needs to be able to be created as private, but maybe they're is
  only ever enough work for say one powerplant then the conitions for new ones don't get switched on"
- MP:247-251 (2026-11-15): the hauliers quote under piece 3 ("build them as if they're could be a profit to base making
  new companies on, and to reduce size on").
- TD:18-19 (2026-11-16, verbatim): "Two new businesses we are adding started by grants alla bakeries, truck drivers and
  truck workshops! Same rules as before what do you think? No not make think"

**The sessions' design (ours)**
- RC:231, section 7 (ours): "Any company with trucks can carry, its own goods or others'. A haulier is a company whose
  row has freight room and nothing else."
- RC:90 (ours): `fleet` = "its trucks, each with a quality and its wear". RC:117: "freight room: what one truck of it
  carries, for a type that carries".
- RC:745 (ours: Wilma's placing): econ_trucks and econ_haulier become `fleet`.
- TT:136-142 (ours: Bob; Otto 3): a truck carries 20 freight-mass units a load and does 6,000 unit-km a month on
  ordinary roads; "Terra's roads set the real distance and speed"; DEPOT and TRUCKER are one row; "a truck driver is a
  family-size haulier with one truck. It needs no building, only its truck"; a larger haulier has a yard (DEPOT bill
  300/240/48/4, TT:269).
- TT:128 (ours: Bob): HAULIER full unit 6 trucks x 6,000 = 36,000 unit-km; ENERGY 2,000 a truck; labour 2/6/0
  (transport); pollution/noise/accidents 10/3/15.
- TT:202, TT:226 (ours): TRUCKER and DEPOT folded into HAULIER.
- TD:48 (ours: Wilma's "Not settled" list): "a truck driver needs no building to start (the truck parks at home)".
- TD:51 (ours: Wilma): "founders reading the average of all the freight may start many at once" (a risk named).
- RB:101-102 (ours: Otto): "No building: ... a truck driver, whose bill is the truck, ordered from a maker (12.4, 32)."

**What exists in the tree**
- economy/type_table.gd:109-112: HAULIER row with `"freight_room": 20, "trucks": 6`, bill [300, 240, 48, 4], setting
  COUNTRY. Rebuilt (step 2).
- economy/company.gd:72: `"fleet": []` with the comment "its trucks (step 4)". Never written.
- economy/type_table.gd:270-274 `bill(type, size)`: no exception for a family haulier, so a truck-driver plan would be
  billed a share of the yard, not its truck (against TT:141 and RB:101). Not reached in step 3 (FOUNDABLE).
- economy/rules.gd:761-768 `work()` and :777-780 `work_qty()` return 0 for a type that sells no item, so rule 7's work
  for HAULIER is always 0 and no haulier could pass founding; the same function is the grants' need hook
  (month.gd:36). audit-rules-maja.md:119: empty work slots are built for builders only.
- economy/month.gd:28 `FOUNDABLE = ["FARM"]`.

**What is missing**: the fleet (trucks as records with quality and wear), freight room used by any company with
trucks, carrying own goods or others', the haulier's rules 1-8 on its own signals (the queue, empty room), founding a
truck driver without a building.

**Whose**: Bob (freight; TD:4-5 also gave Bob "the truck drivers and the trucks (family haulier, grant after the plan,
special orders at the components works)", 2026-11-16, before the rebuild).

---

## 5. Trucks as goods: who makes them and how they are bought

**The user's words**
- TD:22 (2026-11-16, verbatim): "Also trucks for this should be able to be built at the component workshop as special
  orders"
- TD:23-24 (2026-11-16, verbatim): "But trucks have quality that's what governs breakdown and a component factory is
  not the best at making them but the workshop can!"
- TD:25-26 (2026-11-16, verbatim), on one footing for trucks and buses: "Agreed"
- TD:78-79 (2026-11-16, verbatim): "No improvements for trucks set quality stays"
- TD:84-85 (2026-11-16, verbatim): "Yes they ware, yes and no the components ones are always lowest quality workshops
  make different depending on ware and quality of parts"
- TD:91-92 (2026-11-16, verbatim): "Then leave it at workers are they stressed out not maybe they can add more parts to
  make better trucks" (the "maybe" is an idea, not a ruling: TD:94-95).
- RC:23 (2026-11-17): "... if they pick from first or second output ..."
- Landing stock: RC section 9.12 / MP:619-621 (verbatim, 2026-11-17): "materials come with the start not finished
  buildings 5 years worth of equipment ..."

**The sessions' design (ours)**
- RC:132-133 (ours): the components row's second output is trucks, "always at the lowest quality; a truck workshop
  builds them better".
- RC:1087-1088, 12.4 point 32 (ours: Wilma): "A truck is ordered from its maker, not bought cheapest-first off a market.
  The buyer chooses the maker by price and quality."
- RC:233 (ours): "a workshop's quality follows its workers' stress".
- TT:55 (ours: Bob, Otto's review): TRUCK starting price 6,426, "it starts at the cheaper maker's price (the components
  works')".
- TT:103 (ours: Bob): COMPONENTS second line TRUCK 4 a month, MATERIAL 60, COMPONENT 40, ENERGY 6,000.
- TT:129 (ours: Bob): TRUCKSHOP second line TRUCK 1 a month, MATERIAL 15, COMPONENT 10, ENERGY 2,000.
- TT:151-153 (ours: Otto's review): "Vehicles are fleet, for every type": hauliers' trucks, transit buses, sanitation
  vehicles "are all TRUCKs ordered from a maker"; not in any building bill.
- TT:308, TT:314-319 (ours: Bob): a truck from the home world at twice the price, 12,850; "Wilma has decided the
  landing stock holds trucks, enough for the first truck drivers (step-2 brief)".
- RB:127-129 (ours: Otto, marked "open for the user"): whether the landing stock holds trucks "is the user's to say".
- audit-rules-ella.md:214 and audit-rules-anni.md:568: 20 TRUCK in the landing stock was "decided without the user's
  answer" / DIFFERENT from Otto's open point.

**What exists in the tree**
- economy/type_table.gd:45 TRUCK item (mass 0); :83-84 COMPONENTS second line TRUCK; :113-117 TRUCKSHOP second line
  TRUCK. Rebuilt.
- economy/type_table.gd:351-354: TRUCK's starting price is the cheaper of the two makers.
- economy/landing.gd:58 `STOCK := {... "TRUCK": 20}`, and :149-157: Colony Stores offers it on the ordinary market at
  the starting price. Runs in step 3: yes. So today a truck IS bought cheapest-first off the market, which is not
  12.4 point 32.
- No quality on any truck; no special order to a maker.

**What is missing**: ordering a truck from a maker (a special order), choosing the maker by price and quality, the
quality set at making (lowest at the components works; following workers' stress at a workshop), the truck becoming a
fleet record of its buyer.

**Whose**: Bob (trucks, TD:4-5); the workshop's making side Ella by TD:5 (see piece 7 and the questions).

---

## 6. Trucks wearing, breaking down and being repaired

**The user's words**
- TD:20-21 (2026-11-16, verbatim): "Ah no, like this workshop is too fix private trucks that break down, is do it like
  this if you're truck breaks down you can fix it yourself in about 4 months or drive to a workship and have it fixed
  now"
- TD:23 (2026-11-16): "But trucks have quality that's what governs breakdown ..."
- TD:84 (2026-11-16): "Yes they ware ..."
- TD:96-97 (2026-11-16, verbatim): "Uses components and resets wear, about 5% are lost reach time thought"
- TD:78-79 (2026-11-16): "No improvements for trucks set quality stays"

**The sessions' design (ours)**
- TD:33-34 (ours: Wilma's reading): "a workshop is never required for trucks to run; it sells speed."
- TD:97-99 (ours: Wilma's reading of "about 5% are lost"): "each repair brings the truck back to about 5% less than the
  time before, so a truck repaired many times is never quite new again".
- TD:80-82 (ours: Ella's proposals, "not yet answered" at the time): a self-repair leaves the wear; trucks wear with age
  like buses; a self-repair uses no components.
- TD:41-44 (ours: Wilma's "Not settled"): how quality turns into breakdowns; whether a self-repair needs parts
  ("Wilma's view: the self-repair should not").
- RC:233 (ours): the plan's section 7 line carrying the user's words.

**What exists in the tree**: nothing. audit-rules-terra.md:169, audit-rules-bob.md:175, audit-rules-anni.md:145,
audit-rules-maja.md:143: NOT BUILT (step 4). Old: game_full_copy/sim/economy/econ_trucks.gd, econ_fleet.gd (cut).

**What is missing**: wear, breakdowns from quality and wear, a broken truck out of work, self-repair in about four
months, the drive to a workshop, the ~5% loss per workshop repair.

**Whose**: Bob (trucks) with the workshop side (piece 7).

---

## 7. Truck workshops

**The user's words**
- TD:18-19, TD:20-21, TD:23-24 (2026-11-16): as quoted in pieces 4-6.
- TD:96-97 (2026-11-16): "Uses components and resets wear, about 5% are lost reach time thought"
- MP:587 (2026-11-17, verbatim): "No split trucks and workshops" (two separate grant types).
- RC:23 (2026-11-17): "services have no output but a client take in".

**The sessions' design (ours)**
- RC:752 (ours: Wilma's placing): econ_truck_shop is "a type whose clients are trucks".
- RC:125 and RC:134 (ours): a truck workshop sells "bay work on a truck"; it is listed among the services ("serves N
  clients per unit"); rules 2 and 4 read empty bays (RC:126).
- TT:129 (ours: Bob): TRUCKSHOP first line 12 repairs a month (COMPONENT 6, ENERGY 2,000), second line 1 TRUCK;
  labour 2/5/1 (transport trades); 488 a repair; bill 240/180/24/3 (TT:270, Otto).
- TD:4-5 (ours: Wilma's assignment of 2026-11-16, before the rebuild): "Ella builds the truck workshops (repairs, and
  better trucks)".

**What exists in the tree**
- economy/type_table.gd:113-117 TRUCKSHOP row: line `"@truck repair"` qty 12, line TRUCK qty 1, `"way": _SVC_WAY`
  (type_table.gd:64: sells CLIENTS, reads EMPTY_SLOTS, price PER_CLIENT, reach CLIENTS_COME), setting TOWN. Rebuilt.
- economy/company.gd:70 `"slots": {}` "(step 4)": empty slots are not built for services (audit-rules-maja.md:119).
- economy/grants.gd:58 TRUCKSHOP grant kind (piece 13).

**What is missing**: the bay work (a truck as the client), its price per repair under the price rules, empty bays as the
signal, the workshop's truck quality from its workers' stress, the TRUCK second output.

**Whose**: unclear between the plan's split (Bob freight and trucks; Ella services; Maja public services) and TD:5
(Ella the workshops). See the questions.

---

## 8. Truck workers and drivers

**The user's words**
- MP:480, RC:23 (2026-11-17): "stress for workers reduced output based on workers all of it into the company".
- The labour rulings of 9.2 apply to every type (e.g. RC section 9.2; not re-quoted here).

**The sessions' design (ours)**
- TT:128 (ours: Bob): HAULIER labour 2 general, 6 skilled, 0 specialist per full unit (6 trucks), occupation TRANSPORT,
  outdoor. TT:129: TRUCKSHOP 2/5/1, TRANSPORT_TRADES.
- TT:141 (ours: Otto 3): a truck driver is a family-size haulier with one truck.
- RC:334 (ours: verdict table "keep"): "Deaths from wildlife, storms and road accidents taken from outdoor workers first
  | keep | needs the occupation column of the type table".

**What exists in the tree**
- economy/type_table.gd:109-111: HAULIER `"occ": "TRANSPORT", "outdoor": true, "accidents": 15`. The hiring code of
  step 3 hires for any open company by its row (not freight-specific).
- transport/road_safety.gd: accidents near people on fast roads (always on, audit-rules-anni.md:866); its deaths go
  through EconFace.pop_casualties, which is a stub returning 0 (core/econ_face.gd:220; audit-rules-anni.md:876).

**What is missing**: drivers tied to trucks (how many staff a truck needs to run), road accidents falling on drivers.

**Whose**: Bob (freight) with Maja (people).

---

## 9. Roads as the carrier's path: distance, travel time, cost and capacity

**The user's words**
- MP via design-private-roads-transport.md:3 / freight_roads.gd:3-4 (2026-11-15, verbatim, via Wilma): "Next thing
  you're going to run into is roads, they won't be able to take the new freight." / "also road expansions, not just
  quality"
- RC:23 (2026-11-17): "then roads and supply networks".

**The sessions' design (ours)**
- RC:234, RC:70 (ours): "Roads: Terra's road network." The map is "what its trucks drive on".
- RC:1089-1090, 12.4 point 33 (ours: Wilma): "Roads: siting, seasons, ecology, freight on roads, road works and road
  safety are all part of the rebuild and on."
- RC:816, 12.2 point 12 (ours: Wilma): "The first roads: none beyond the landfall place. Roads are built as the colony
  spreads."
- TT:137-138 (ours: Bob): 6,000 unit-km a month per truck "on ordinary roads. Terra's roads set the real distance and
  speed."
- RC:801, 12.1 point 5 (ours: Wilma): "A plant pays for its road, power and water connection as a home does."
  audit-rules-terra.md:650: NOT charged in code.

**What exists in the tree** (old code kept, Terra's; runs every month in a step-3 game, but carries no freight)
- transport/transport.gd:554-576 `route(world, from_id, to_id, mode)` and :588 `_road_route`: between network nodes
  (settlements, "port", country PLANT nodes, sites, bases; :489-520 `_nodes`), returns km, time_h/time_days and
  cost_index. :27-29 SPEED, COST, CAPACITY per kind (TRACK/ROAD/PAVED). Pure queries.
- transport/transport.gd:117-127 `ensure` writes the founding network once: :137-195 `_founding` lays TRACKs joining
  the first settlements and spurs to founding plants outside a town. Plants founded later are nodes but get no link
  unless one is built.
- transport/transport.gd:1275-1318 `step_month`: wear by age, traffic over capacity and storms; then
  `FreightRoads.step_month`, `PrivateRoads.step_month`, `RoadSafety.step_month`, `Site.step_month`. Called by
  planet/planet_provider.gd:82.
- transport/freight_roads.gd (whole file, 504 lines; class FreightRoads): freight between DISTRICTS as trucks on
  links. `freight_room_mu` :165, `add_freight_traffic` :177 (the only write), `deliverable_pm` :218, `district_jam_pm`
  :238, `held_between` :295, `jam_share_pm` :314, `detours` :344, `step_month` :389. `on()` :45 returns true ("Always
  on"), though the header :4 still says "opt-in". Constants: UNITS_PER_TRUCK 25 (:31; the type table says 20 a load,
  TT:137), TRUCK_PCU 2, JAM_ALLOW_PM 1250. transport/transport.gd:1345-1364 wraps them.
- Nobody in game/sim/economy calls `add_freight_traffic` or `freight_room_mu` (grep), so in a step-3 game the freight
  counts stay 0, `jam_share_pm` is 0, and planet_provider.gd:84 publishes TRANSPORT_FREIGHT_JAM 0.
- transport/commuting.gd (bus lines from EconFace.query_commuting, a stub returning []).
- Tests: game/tests/transport/test_freight_roads.gd, test_transport.gd, test_private_roads.gd, test_road_safety.gd.

**What is missing**
- The carrier's trip: from a plant (or the port, or a seller's place) to the buyer's area, its km and time from
  `Transport.route`, turned into unit-km sold, truck-months used, and the freight price.
- The link between the rebuilt economy's AREAS and FreightRoads' DISTRICTS (FreightRoads routes "from_d, to_d"
  between district nodes; the rebuild has areas, and districts are drawn later by the government, RC:791-797).
- Reconciling 25 units a truck (freight_roads.gd:31) with 20 a load (TT:137).
- A plant's charge for its road connection.

**Whose**: Terra (the roads and the map); Bob for what freight reads and writes on them.

---

## 10. Building roads and the government's road works

**The user's words**
- RC:1397, MP:921 (2026-11-17, answer 3, verbatim): "Most comonly the government but if a company out a collective
  wants to they should be able to, that could come in planing of grants the government asks and if any company wsnts
  it but that would cost but they would be free to charge for using it"
- design-law-private-roads.md:3 and design-private-roads-transport.md:3 (2026-11-15, the user as quoted there): "private
  roads, bought and paid for by companies".

**The sessions' design (ours)**
- RC:579, 9.5 (ours): "Commissioning: the state orders a building, a road or a repair from builder companies like any
  client." RC:611, 9.7: "a road" is built by contract.
- RC:1333, 12.11 point 99 (ours: Wilma): the public works department builds at cost when the government tells it
  to. RB:120-122 (ours: Bob's review): it exists from month one and is idle in step 3.
- RB:103 and RB:394 (ours: Otto): "Roads are billed from Terra's road plan per link"; road contracts come "from the step
  that brings road works". TT:430: "The road bill per link is Terra's (Otto 3)."
- RC:1089-1090 (ours: Wilma, 12.4 point 33): "Private roads and tolls are left out for now." RC:1365-1366 (12.12) the
  same. rebuild-not-included.md:101-102: "left out for now by Wilma".
- Terra's private road design (ours: Terra, 2026-11-15), design-private-roads-transport.md sections 1-7: owner, regime,
  toll, reserved share on a link; owner views of the network; tolls counted by transport and booked by Bob.
- Anni's law design (ours: Anni, 2026-11-15), design-law-private-roads.md: LAW_PRIVATE_ROADS 0-2, the road licence,
  access and toll cap, takeover, neglect.

**What exists in the tree**
- transport/transport.gd:851 `plan_link` (prices a link from BILL_TILE/BILL_BRIDGE, :45-47; uses EconData.WU_COST_EST
  and EconData.BASE_PRICE of the old data file at :1025-1026), :1092-1147 `complete_road` (builds NEW, UPGRADE,
  REPAIR, LANES, BRIDGE, PASS, JUNCTION), :1178 `auto_job`, road_needs. Old code kept. Nothing in game/sim/economy
  calls `complete_road`; building.gd has no ROAD contract kind yet (RB:46: ROAD "from the steps that bring them").
- politics/gov_builder.gd:184-240 `_road_needs` reads `Transport.road_needs` and orders through `_order` :504-523,
  which calls `EconFace.actions_validate`/`actions_enqueue` (core/econ_face.gd:66-99), stubs that answer "There is no
  economy yet." So in a step-3 game the government cannot order a road.
- transport/private_roads.gd: behind the opt-in flag PRIVATE_ROADS (:15, :23-24), off by default; uses EconData at
  :86-87. audit-rules-anni.md:403: "SAME" (left out as 12.4, 33 says).

**What is missing**: a ROAD building contract carried by the rebuilt building code; the road's bill in the new prices;
the government (and, by answer 3, a company or collective) commissioning it; charging for a road's use.

**Whose**: Terra (the roads: plan and bill per link); Otto (the building contract); Wilma (the government's side of
ordering); Bob (any payment for use). See the questions.

---

## 11. The port side

**The user's words**
- RC:587-588, 9.6 (verbatim, undated there): "They can't order when there's not a ship there to take the order. ...
  they have to ask for one when the ship is there, which means they have the full period of waiting every time."
- RC:592-594 (verbatim): "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS WITHOUT THE CONTEXR"
- MP:1148 (2026-11-18, verbatim): "The ship comes about every two years"

**The sessions' design (ours)**
- RC:1074-1075, 12.3 point 25 (ours: Wilma): exports count as sold when they go aboard; "Stock at the port waiting
  for a ship is waiting for freight, not unsold."
- RC:817, 12.2 point 13 (ours: Wilma): "The port is at the landfall place and is the government's."
- RC:1348-1349, 12.11 point 106 (ours, from the old game): "The port has a size. What does not fit aboard or on the
  dock waits, and a full port is published." Step 10.

**What exists in the tree**
- economy/ship.gd (rebuilt, step 3, Wilma): :106-129 `_deliver` puts an import straight into the buyer's stock on
  arrival ("IMPORT"), wherever the buyer stands; no carrying from the port. :132 `port_tile` = the landfall tile. The
  port is also a transport node ("port", transport.gd:497).
- Exports, the port's size and the charter quota: not built (ship.gd:19-20, step 10).

**What is missing**: freight between the port and a buyer or seller (imports carried from the dock; exports carried to
the port and waiting there).

**Whose**: Bob (freight) with Wilma (the ship code is hers, ship.gd:2).

---

## 12. Farms away from towns, the grant's spot, and the road to the spot

**The user's words**
- RC:1392 and MP:908 (2026-11-17, verbatim): "Can we add a prefernce for farms not being close to towns? This might be
  the best way to start districts when the grant is made the government picks a spot away from towns where they will
  be built, then that center soot can start getting buisness and then their own housing sectors, and a town grows what
  do you think before we add it"
- RC:1393 and MP:912 (2026-11-17, verbatim): "Save it for when trucks and roads come Mark it for then"
- RC:1397 and MP:921 (2026-11-17, verbatim), the four answers: "1 . Far away wnough that a few years of development
  wont merge them, 2. Upp to the goverment, but since they pay for the road, more spots would be more expencive for
  them.  3. Most comonly the government but if a company out a collective wants to they should be able to,  that could
  come in planing of grants the government asks and if any company wsnts it but that would cost but they would be
  free to charge for using it 4. No farms payed fully from saving does not"
- RC:1394-1396 (ours: Wilma's note): "When step 4 is planned, bring it back to the user with these questions". The four
  questions are answered (above); RC:1404: "Still for step 4, not built before trucks and roads."

**The sessions' design (ours)**
- RC:1398-1403 (ours: Wilma's plain restatement of the four answers).
- RC:1405-1410 (ours: Wilma's view, given when asked): it fits; risks: "distance costs nothing until freight exists,
  the first year's food is tight if the first farms wait for a road, and hired farm workers need homes at the spot
  early. Staging proposed: the preference and the spot with freight at this step; shops, services and housing sectors
  around the spot with homes at step 7." Its line "farms are already scored away from homes" is false:
  audit-rules-ella.md:167 and audit-rules-terra.md:642 (site.gd places farms nearer settlements; the next_to_homes
  penalty is for every type EXCEPT a farm).
- RC:1404 / 12.9 point 61b (ours): the grant programme has a maximum sum; the government decides how many farms.

**What exists in the tree**
- transport/site.gd:139-185 `choose_country`: distance from the nearest settlement counts AGAINST a place (`"distance":
  -d`, a point a tile; SCORE at :33 road +3, fertile +4, next_to_homes -6 "for every type but a farm"). So a farm today
  is placed as NEAR a settlement as it can. Rebuilt in step 2 (Terra).
- economy/month.gd:155 `_found_one` calls `Site.choose_country(world, type, sixths, 1)`; no grant spot is passed.
- politics/gov_builder.gd `grant_programmes` names DISTRICTS a programme covers (audit-rules-anni.md:371), not a spot.
- economy/grants.gd: no spot. audit-rules-terra.md:369, :509: "A grep for 'spot' or 'away from town' finds nothing."

**What is missing**: the preference for farms away from towns; the government's spot per grant programme (how many is
its choice); farms paid by a grant going to the spot, farms paid wholly from savings not; the road to the spot (paid
most commonly by the government; a company or collective may take it on and charge for its use); the distance rule
("a few years of development wont merge them").

**Whose**: Terra (the map, siting, the road); Wilma (the government's choice of spot and road); Ella (grants.gd);
Bob only for freight from the spot. Not stated in the plan; see the questions.

---

## 13. The truck-driver and truck-workshop grants

**The user's words**
- TD:18 (2026-11-16): "Two new businesses we are adding started by grants alla bakeries, truck drivers and truck
  workshops! ..."
- MP:587 (2026-11-17, verbatim): "No split trucks and workshops"
- MP:608 and RC:687 (2026-11-17, verbatim): "JUST ALL FUCKING GRANTS DAMNED IT WHY CAN YOU NOT FIGURE THESE THINGS OUT?!
  I SAID ALL THEEE THE THREE WAS A MISTAKE"
- RC:577-578 (verbatim): "I DID NOT SAY GIVE EVERYONE ... GRANTS".
- RC:1230, 12.9 point 61b (2026-11-17, verbatim, about farms): "The government should  put a max sum into the grant
  based on how many darms they wantmaybe a little extra to be sure".

**The sessions' design (ours)**
- RC:1235-1236 (ours: Wilma's reading): the bakery, truck driver and workshop grants get their sum the same way; "The
  user spoke of farms."
- TT:296 (ours: Bob): grants truck driver 10,000, truck workshop 10,000.
- TT:303-330 (ours: Bob): a truck driver costs 15,740 with opening money, I2 and up can found one without opening money;
  a truck workshop I4 and up.
- TD:63-74 (ours: Wilma's political side): approved on need ("freight being left behind for drivers, broken trucks in
  reach for workshops"); ECON_ROLE; news; licences (Anni).

**What exists in the tree**
- economy/grants.gd:53-58 KINDS: TRUCKER (lever ECON_TRUCK_DRIVER_GRANT, type HAULIER, FAMILY), TRUCKSHOP (lever
  ECON_TRUCK_WORKSHOP_GRANT, FAMILY). Rebuilt (Ella).
- economy/grants.gd:250, :270-280 `wanted`: TRUCKER and TRUCKSHOP want "one in each area that has none standing or
  planned" (ours: Ella, on Wilma's reading; audit-rules-terra.md:403, audit-rules-ella.md:70).
- economy/econ_publish.gd:36, :67-70: both levers, default GRANT_START_PCT 50.
- Not payable in step 3: FOUNDABLE = FARM (audit-rules-maja.md:170, audit-rules-otto.md:399).

**What is missing**: the need these grants answer read from freight (the queue, broken trucks), rather than "one per
area"; the founding of the two types.

**Whose**: Ella (grants.gd) with Wilma (the government's decision); Bob for the freight signal they read.

---

## Questions

Points where the user's words do not decide. Plain questions; none answered here.

1. The work-queue words ("count the work que not passed work", "That works", 2026-11-16/17) were about the old transit
   authority's depot. Does the queue in the rebuild belong to each carrier, to each route, or is it one queue for the
   colony that every carrier works from?
2. Within the queue, what goes first: the oldest freight, the freight whose buyer pays the carrier more, or something
   else?
3. Who pays the carrier: the buyer (the plan's 12.4, 30 says goods on the road are the buyer's, ours) or the seller?
4. Does freight apply to every sale, including within one area (a farm to a shop in the same town), or only between
   places that are apart (a country plant to a town, one area to another, the port)? Do households carry what they buy
   themselves?
5. What is "a route" for a carrier's price: a pair of areas, a plant and an area, or the road links between them?
6. Does the price slow-down above double and four times the original ("at double it only climbs 1% ...", 2026-11-18)
   apply to a freight price per route, with the starting freight price as its original?
7. A truck is "ordered from its maker, not bought cheapest-first" (Wilma's 12.4, 32, not the user's). The code sells
   the landing stock's 20 trucks on the ordinary market. Which is it?
8. Does the landing stock hold trucks at all? Otto marked it for the user (rebuild-building.md:127-129); Wilma decided
   20 without an answer (audit-rules-ella.md:214).
9. How does a truck's quality turn into breakdowns, and how fast does a truck wear (TD "Not settled")?
10. While a driver fixes a truck himself "in about 4 months", does that truck carry nothing for the four months, and
    does a self-repair reset wear or use components?
11. "about 5% are lost reach time": is Wilma's reading right, that each workshop repair brings the truck back to about
    5% less than the time before?
12. "maybe they can add more parts to make better trucks": is that a rule to build at step 4 or an idea left aside?
13. Who builds the truck workshop: Ella (as TD:5 assigned on 2026-11-16, and as "services" in section 13), or Bob (as
    "freight" in section 13)?
14. When a carrier is a driver with one truck, how many workers does a truck need to run (one driver, or a crew)?
15. Answer 3 lets a company or collective build the road to the spot and "charge for using it". The plan's 12.4, 33
    and 12.12 (Wilma's) leave private roads and tolls out for now. Do private roads and tolls come in at step 4 for the
    road to the spot, or for every road?
16. "Far away enough that a few years of development won't merge them": is that measured in distance on the map, or
    by how fast towns are growing at the time?
17. Is the preference for farms away from towns for every farm, or only for the grant farms that go to the
    government's spot? (Answer 4 says only that farms paid wholly from savings do not go to the spot.)
18. Do the first grant farms wait for the road to their spot before they can be built or sell, and where do their hired
    workers live before homes come at step 7?
19. Should imports landed by ship be carried from the port to the buyer by truck, and exports carried to the port?
20. A carrier is founded by rules 7 and 8 like any company. What is a carrier's "work" for rule 7: the freight queue,
    the freight wanted, or something else? (Today the code's work for a type that sells no item is 0.)
21. Do the truck-driver and workshop grants open on a need read from freight (freight left waiting; broken trucks), as
    TD:65 (ours) had it, or on "one in each area that has none" as built (ours)?
22. The old FREIGHT_ROADS code works between districts and counts 25 units a truck; the rebuild has areas and 20 a load.
    Is the roads' capacity model kept as it is (Terra's old numbers), or set new with the rest of the step-4 numbers?
