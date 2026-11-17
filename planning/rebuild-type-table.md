# The rebuild: the type table (plan section 4), for build step 2

**Bob, 2026-11-17. Draft 1, on paper; nothing is built.** It fills in section 4 of
[rebuild-company.md](rebuild-company.md) (version 13). Every number is new: "Same company types can come but not their
code or balancing"; "set a credit prices we are going to have to adjust it anyway". The old table was used only as a
list of names. The build bills and building times were agreed with Otto and are explained in
[rebuild-building.md](rebuild-building.md) section 3. Where the plan gave no number, I set one and say why in a line.
**(Bob)** marks those. The user strikes any that are wrong.

The working is [rebuild_type_table_calc.py](rebuild_type_table_calc.py): one script that sets every price from the rows below and prints the month-one check. Everything here can
be recomputed from the rows.

---

## 1. How the starting prices are set

One rule for every item and every service, so no type is priced by hand. **(Bob)**

> **starting price = making price at full output + the build bill (with its land) spread over 10 years of full
> output.**

- The **making price** is plan 12.3, 14: a month's wages, inputs and upkeep, divided by the full-size output. At month
  one there are no loans, so there is no interest in it.
- The **10 years** means a plant that sells all it makes at its starting price earns back its building in about nine
  to ten years. A shorter time would set off waves of entry (plan section 13, watch item 2). A longer one would mean
  nobody plans anything without the bank. Homes and office places use 13.5 years, the middle of the user's "12 to 15
  years" (9.8).
- **The anchor:** the general-skill salary is 300 credits a month. Every price follows from that one number, so the
  whole table scales with it, and changing it changes nothing relative.
- **The salary formula holds at landing** (plan 12.5, 37 as Wilma revised it: the starting salary carries a household,
  1.5 × (the rent of a home in the area + the food of a household of 2.5), no division by earners).
  - With the landing shelter at half a new house's rent (48 against 97), it gives back 300 only for one farm output:
    **a full farm makes 156 FOOD a month.** That is the number the calculator solves for: 1.5 × (48 + 2.5 × 60.7) =
    300.
  - Because every price moves with the salary, this holds at any salary level: it is a property of the rows, not of
    the 300.
  - A worker's needs, below which they do not apply for a job, are the same household's rent and food: 200, which is
    two-thirds of the starting salary (12.5, 38).
  - Skilled is 1.5 times the general salary (450) and specialist 2.25 times (675). **(Bob)** These ratios keep a
    specialist post worth training for (12.11, 85) without making a specialist a different class.
- **Money:** credits. The code keeps them at fixed point × 1000 (CoreUtil.S), as now.

This rule sets the START only. From month two every price is the company's own, moved by the nine rules.

## 2. The items

| Item | Unit | Starting price (cr) | Freight mass per unit | Spoils per month | Notes |
|---|---|---|---|---|---|
| FOOD | one person's basic food for a month | 60.7 | 1 | 1% | raw farm produce; a person eats 1 a month (FOOD or BREAD) |
| BREAD | as FOOD | 58.3 | 1 | 25% | the households' preferred staple (econ_staple's place); counts as food |
| FINE_FOOD | one portion-month | 129 | 1 | 10% | delicatessen; cafés use it |
| MINERAL | one tonne of ore | 7.7 | 2 | none | |
| MATERIAL | one tonne of processed building material | 37.1 | 2 | none | Otto's bills are in this unit |
| COMPONENT | one crate of machined parts | 138 | 1 | none | about 4 MATERIAL in worth |
| TRUCK | one truck | 6,426 | drives itself | wears (plan 7) | ordered from a maker (12.4, 32); built with a quality. Two rows make it; it starts at the cheaper maker's price (the components works'), since a buyer takes the cheaper offer (Otto's review) |
| CONSUMER | one household good | 18.7 | 1 | none | |
| CLOTHING | one garment-set | 19.3 | 1 | none | |
| FURNISHINGS | one piece | 63.9 | 2 | none | |
| MEDICAL | one treatment-kit | 27.3 | 1 | 0.5% | clinics and eldercare use it |
| ENERGY | one unit on the grid | 0.189 | grid only | cannot be stocked (12.7) | |
| WATER | one unit on the grid | 0.093 | grid only | cannot be stocked (12.7) | |

- **Building work (BW)** is not an item on the market. It is what a builder sells, at 392 cr per BW at the start
  (section 4, the builder row).
- **Freight** is not an item either. It is what a carrier sells: 0.194 cr per unit-km at the start (the haulier row).
- **Spoiling:**
  - FOOD at 1% a month **(Bob)**. The old 2% would eat a fifth of a year's landing stock, and the landing food is
    stored food.
  - BREAD and FINE_FOOD spoil fast, so nobody stocks far ahead on them (9.3).
  - Storage space is left out (12.12), so spoiling is the only cost of holding stock.

**What one person uses a month (proposal for Maja, who owns the household side; I need it to size the colony's
demand):**
- 1 FOOD (or 1 BREAD);
- 50 ENERGY and 50 WATER;
- 0.5 CONSUMER, 0.1 CLOTHING, 0.02 FURNISHINGS;
- 0.05 MEDICAL through the clinic.

At the starting prices a household of 2.5 people spends:
- 152 cr on food (146 if it eats bread, which is the cheaper of the two);
- 35 cr on power and water;
- its rent (section 6).

## 3. The rows: goods

One full-size (large) unit per month. Labour is G / S / Sp.

- **Pollution** is in pollution units a month, read by the planet by area.
- **Noise** is 0 to 5 at the plant's cell, read by the town grid's home values (9.8).
- **Accident risk** is accidents per 1000 workers a year (plan section 7; Otto's wear raises it).
- **Hazard** marks a plant the law closes when it is unsafe (12.11, 80).

All are **(Bob)**, to be set in testing.

| Type | Output (first / second) | Quantity | Inputs per month | Labour G/S/Sp (occupation) | Pollution | Noise | Accidents | Hazard |
|---|---|---|---|---|---|---|---|---|
| FARM | FOOD | 156 | none at the start (see note 1) | 18/5/1 (agriculture, outdoor) | 10 | 1 | 8 | |
| BAKERY | 1st BREAD | 1,500 | FOOD 1,300, ENERGY 3,000, WATER 1,500 | 12/5/1 (food trades) | 5 | 1 | 4 | |
| BAKERY | 2nd FINE_FOOD | 400 | FOOD 700, ENERGY 3,000, WATER 1,000 | 10/6/2 (food trades) | 5 | 1 | 4 | |
| MINE | MINERAL | 2,000 | ENERGY 8,000, WATER 2,000 | 20/8/2 (mining, outdoor) | 40 | 5 | 25 | yes |
| PROCESSING | MATERIAL | 800 | MINERAL 1,600, ENERGY 12,000, WATER 4,000 | 18/10/2 (industry) | 60 | 4 | 15 | yes |
| COMPONENTS | 1st COMPONENT | 200 | MATERIAL 250, ENERGY 8,000 | 10/14/6 (industry) | 25 | 3 | 8 | |
| COMPONENTS | 2nd TRUCK, always lowest quality | 4 | MATERIAL 60, COMPONENT 40, ENERGY 6,000 | 10/14/6 (industry) | 25 | 3 | 8 | |
| CONSUMERF | CONSUMER | 1,200 | MATERIAL 150, COMPONENT 20, ENERGY 6,000 | 16/10/2 (industry) | 15 | 3 | 6 | |
| TEXTILE | CLOTHING | 1,000 | FOOD 100 (fibre), MATERIAL 40, ENERGY 4,000, WATER 2,000 | 18/6/1 (industry) | 20 | 2 | 5 | |
| FURNITURE | FURNISHINGS | 300 | MATERIAL 200, COMPONENT 5, ENERGY 3,000 | 14/8/1 (crafts) | 10 | 3 | 6 | |
| MEDWORKS | MEDICAL | 600 | MATERIAL 30, COMPONENT 10, ENERGY 5,000, WATER 3,000 | 6/10/6 (industry) | 10 | 1 | 4 | yes |
| POWER | ENERGY | 120,000 | MINERAL 1,200 (fuel), WATER 5,000 | 8/8/4 (utilities) | 80 | 4 | 10 | yes |
| WATERWORKS | WATER | 120,000 | ENERGY 15,000, MATERIAL 10 | 6/5/2 (utilities) | 3 | 2 | 5 | |

Notes:

1. **A farm takes no power or water at the start.** **(Bob)** No plant stands at landing, so there is no grid until the
   government's first power plant and waterworks open, which is 8 and 6 months of building after the job starts. A farm
   that needed the grid could not grow the colony's first food. With the grid built, a farm row may take power and
   water; that is a number to add in testing, not a different rule.
2. **Every other goods row needs the grid,** and so cannot run until it exists. That is a result (12.3, 19: a missing
   input is not a price signal), and it is the second constraint on month one after the builders (section 9).
3. **TRUCK** has two makers. The components works makes it as a second output, always at the lowest quality (section
   4's ruling). The truck workshop makes it better, at a quality that follows its workers' stress (plan 7).
4. **TEXTILE's** FOOD input stands for fibre crops. **(Bob)** It saves an item nobody else would use.

## 4. The rows: building, freight, homes, offices and money

| Type | What it sells | Quantity per full unit | Inputs | Labour G/S/Sp (occupation) | Starting price | Pollution / noise / accidents |
|---|---|---|---|---|---|---|
| BUILDER | building work, BW | 60 BW | none; the job's material is the client's (Otto 4.5) | 36/18/6 (construction, outdoor) | 392 per BW, material on top at what the builder paid | 5 / 3 / 20 |
| HAULIER | freight, per unit-km | 6 trucks × 6,000 unit-km = 36,000 | ENERGY 2,000 a truck | 2/6/0 (transport) | 0.194 per unit-km, per route by the rules (12.4, 30) | 10 / 3 / 15 |
| TRUCKSHOP | 1st bay work on a truck: 12 repairs; 2nd TRUCK: 1 | 12 bays / 1 truck | repair: COMPONENT 6, ENERGY 2,000; truck: MATERIAL 15, COMPONENT 10, ENERGY 2,000 | 2/5/1 (transport trades) | 488 a repair; TRUCK 6,426 (the item's price) | 5 / 3 / 6 |
| LANDLORD | homes | a block of 50 homes | none; upkeep (Otto's column) | 2/0/0 caretakers (property) | rent 97 a month for a new house on an ordinary cell, by 9.8's formula | 0 / 0 / 1 |
| OFFICEBLOCK | office places (7, the office bonus) | 10 places | ENERGY 4,000, WATER 1,000 | 2/0/0 (property) | 256 a place a month | 1 / 1 / 1 |
| BANK | loans (12.8, 50) | 60 loans managed | ENERGY 1,000 | 2/6/4 (finance) | its price is the interest rate: 0.5% a month at the start **(Bob)** | 1 / 1 / 1 |

Notes:

- **The haulier.**
  - A truck carries 20 freight-mass units a load and does 6,000 unit-km a month on ordinary roads **(Bob)**. Terra's
    roads set the real distance and speed.
  - **Freight room** (section 4's column) is this: 20 a load per truck, for any company that has trucks. A haulier is
    the row with freight room and nothing else (plan 7).
  - The old DEPOT and TRUCKER are this one row: a truck driver is a family-size haulier with one truck. It needs no
    building, only its truck (Otto 3). A larger haulier has a yard (Otto's DEPOT bill).
- **The bank.**
  - "60 loans managed" is its client intake: its empty work slots are lending it could do and does not.
  - Its capital ratio, set by us (12.8, 50c), starts at 10%: loans out at most ten times its own capital. **(Bob)**
  - Its ONE price is the interest rate (12.8, 50). The calculator prints the bank as a service at 122 a loan-month.
    That is what the bank needs to earn per loan to cover its staff and building, not a second price. At 0.5% a month
    it is covered by a loan of about 24,400 (Otto's review).
- **Builder.** The 392 per BW includes about 7 cr of a yard's payback. The five home-world builders have no yard (plan
  section 3), so for them it is margin. It is a starting price only, not a cost they pay (Otto's review).
- **Vehicles are fleet, for every type** (Otto's review). A haulier's trucks, the transit company's buses and the
  sanitation company's collection vehicles are all TRUCKs ordered from a maker (12.4, 32). They wear and are repaired
  like any truck (plan 7). They are not in any building bill. A bus is not a second kind of vehicle.
- **Landlord rent.** Otto's block bill is 1,200 BW, 720 MATERIAL and 24 COMPONENT for 50 homes, so 9,830 cr a home.
  Add 10% for land and spread it over 13.5 years, then add the caretakers and upkeep: 97 a month at condition 100 on a
  cell of value 1000. Rent then follows 9.8: the landlord's own rent × the cell's value / 1000 × the condition factor.

## 5. The rows: services (client intake, no output)

"services have no output but a client take in". Each row serves N clients a month at full size. What rules 2 and 4
read is empty client places (section 4). A public service's price is its tax bracket (9.5): the figure in the price
column is what one client costs at full use. That is what the bracket starts from, and the government decides it
(12.6, 46).

| Type | Client | Clients per full unit | Inputs per month | Labour G/S/Sp (occupation) | Price per client-month | Reach |
|---|---|---|---|---|---|---|
| SHOP | a household that shops there | 400 | ENERGY 3,000 | 8/2/0 (retail) | see note | town grid |
| CAFE | a visit | 1,500 | FOOD 150, FINE_FOOD 60, ENERGY 3,000, WATER 2,000 | 8/2/0 (hospitality) | 14.7 | town grid |
| SERVICEHUB | a household (repairs, laundry, hairdressing) | 300 | ENERGY 2,000, WATER 1,000 | 6/4/0 (personal services) | 17.4 | town grid |
| CHILDCARE | a child | 120 | FOOD 60, ENERGY 2,000, WATER 1,000 | 4/10/1 (care) | 97 | town grid |
| ELDERCARE | a resident | 80 | FOOD 80, MEDICAL 20, ENERGY 3,000, WATER 2,000 | 8/10/2 (care) | 194 | town grid |
| CLINIC | a person covered | 2,000 | MEDICAL 80, ENERGY 4,000, WATER 2,000 | 4/10/6 (health) | 7.6 | 2 km (12.6, 43) |
| SCHOOL | a pupil | 300 | MATERIAL 5, ENERGY 3,000, WATER 1,000 | 2/12/4 (education) | 39 | 1.5 km (12.6, 43) |
| POLICE | a resident of its area | 2,500 | ENERGY 2,000 | 4/10/1 (public order) | 3.4 | its area |
| PRISON | a prisoner place | 50 | FOOD 50, ENERGY 3,000, WATER 2,000 | 4/10/1 (public order) | 261 | the colony |
| ADMIN | a resident | 3,000 | ENERGY 2,000 | 4/8/3 (public administration) | 3.0 | its area |
| TRANSIT | a rider (12.5, 40: buses) | 1,000 | ENERGY 20,000 | 2/10/0 (transport) | 10.3 | its lines |
| SANITATION | a home or plant collected from | 1,500 | ENERGY 4,000, WATER 6,000 | 10/2/0 (sanitation, outdoor) | 4.2 | its area |
| NEWSPAPER | a reader (12.6, 48) | 2,000 | MATERIAL 4 (paper), ENERGY 2,000 | 3/6/3 (media) | 3.5 | the colony |

Pollution 1 to 15, noise 1 to 2, accidents 2 to 6 per 1000, for all services. **(Bob)** None is hazardous.

- **SHOP.** 12.6, 48 makes shops service companies, and the old household side bought food "at the shop's price"
  (9.1).
  - **(Bob, for Wilma to confirm:)** a shop is a seller of items within the town grid's reach of homes. It buys
    wholesale on the market and posts its own price for each item; its client intake is how many households it can
    serve. Its rules 2 and 4 read its unsold stock, like any seller of items.
  - A household buys from any seller within its reach. Farms and works usually stand outside that reach, so in a town
    households buy through shops. In month one the government's landing stock (Otto 4.1) is the one seller within
    reach.
  - This needs no rule of its own. If Wilma reads 12.6, 48 as "a shop sells only a service", the household side needs
    another way to buy goods.
- **Services that need the grid** cannot open before it exists (section 3, note 2). That holds for clinics and schools
  too. It is a result, and the government decides what it commissions first (12.11, 102).

## 6. Types: the 34 old names, and what became of each

| Old name | Now | Why |
|---|---|---|
| FARM, FAMFARM | **FARM** | a family farm is FARM at family size (plan 11) |
| BAKERY, FAMBAKERY | **BAKERY** | the same |
| TRUCKER, DEPOT | **HAULIER** | a truck driver is a family haulier; DEPOT was the old haulier's yard |
| MINE, PROCESSING, COMPONENTS, CONSUMERF, TEXTILE, FURNITURE, MEDWORKS | the same | sell items |
| POWER, WATERWORKS | the same | sell through the grid (12.7) |
| TRUCKSHOP | the same | bay work on trucks, and trucks |
| SERVICEHUB, CLINIC, SCHOOL, CHILDCARE, ELDERCARE, POLICE_STATION (now POLICE), ADMIN, TRANSIT, SANITATION | the same | serve clients |
| RETAIL | **SHOP** | sells items to households within reach (section 5) |
| COMFORT | **CAFE** | serves visits; the household line "comfort" has a seller (12.6, 48) |
| NEWSROOM | **NEWSPAPER** | readers are its clients (12.6, 48) |
| HOUSING | **LANDLORD** | homes are its client places (9.8) |
| OFFICE | **OFFICEBLOCK** | the private landlord of office places (plan 7) |
| HQOFFICE | gone | office staff sit in OFFICEBLOCK places; a head office was a staff holder |
| BIZSVC | gone | it served no client the rules or households need. It can come back as a service if the user wants one |
| PUBJOBS | gone as a type | the public work scheme (12.11, 87) hires into the public works department's crews (a BUILDER the state owns). **(Bob)** |
| WAREHOUSE | gone | storage space is left out (12.12) |

**New rows the plan asks for:**
- BUILDER (9.7);
- BANK (12.8, 50);
- PRISON (section 10: "a prison's [clients] are prisoners in places").

A party's office staff are the party's own (12.6, 48), not a type.

So the table has **30 rows**: 11 that make goods, 6 for building, freight, homes, offices and money, and 13 services,
SHOP among them. Of the 34 old names:
- six became three rows (FAMFARM into FARM, FAMBAKERY into BAKERY, TRUCKER and DEPOT into HAULIER);
- four are gone;
- six are renamed (RETAIL, COMFORT, NEWSROOM, HOUSING, OFFICE, POLICE_STATION);
- the rest keep their names.

## 7. Sizes

Every row comes in all four sizes ("All company types needs to be able to be created as private").

| Size | Share of the row | Output penalty | Bill share | Fewest months (Otto) |
|---|---|---|---|---|
| family | 1/6 | 6% | 1/6 | max(2, ceil(full × 7/6 / 2)) |
| small | 1/3 | 4% | 1/3 | max(2, ceil(full × 4/3 / 2)) |
| average | 2/3 | 2% | 2/3 | max(2, ceil(full × 5/3 / 2)) |
| large | 1 | none | 1 | full |

- **Labour and inputs** scale with the share. A fraction of a worker rounds to whole people per plant, by largest
  remainder over the tiers (CoreUtil.split_lr). **(Bob)**
- **The penalty** comes off the output, not off the inputs.
- **A family company is one household.**
  - A family farm's 4 workers (3 general, 1 skilled) are mostly the founding household. The row asks for 4 posts;
    who fills them is hiring.
  - At the starting prices a family farm makes 24.4 FOOD a month, worth 1,483. Its wages and upkeep are 1,417. It
    pays its family a living, not its building back; that is what the grant is for.

## 8. Build bills (agreed with Otto)

From [rebuild-building.md](rebuild-building.md) section 3, for one full unit: BW / MATERIAL / COMPONENT / the fewest
months. The upkeep column for every row is Otto's: 1/400 of the MATERIAL bill a month, plus 2% of the BW a year as a
builder's job.

| Type | Bill | Cost at starting prices (cr, without land) |
|---|---|---|
| FARM | 240 / 240 / 12 / 4 | 104,650 |
| BAKERY | 300 / 240 / 24 / 4 | 129,830 |
| MINE | 600 / 480 / 72 / 6 | 262,960 |
| PROCESSING | 720 / 600 / 96 / 8 | 317,770 |
| COMPONENTS | 720 / 600 / 120 / 8 | 321,090 |
| CONSUMERF | 480 / 480 / 60 / 6 | 214,270 |
| MEDWORKS | 480 / 360 / 96 / 6 | 214,780 |
| TEXTILE, FURNITURE | 420 / 360 / 48 / 5 | 184,640 |
| POWER | 840 / 840 / 180 / 8 | 385,330 |
| WATERWORKS | 540 / 540 / 72 / 6 | 241,670 |
| HAULIER (yard; a truck driver has none) | 300 / 240 / 48 / 4 | 133,140 |
| TRUCKSHOP | 240 / 180 / 24 / 3 | 104,080 |
| SERVICEHUB, CHILDCARE, ELDERCARE, SHOP, CAFE | 240 / 240 / 12 / 3 | 104,650 |
| SANITATION (as the other services; its vehicles are fleet) | 240 / 240 / 12 / 3 | 104,650 |
| TRANSIT (as a haulier's yard; its buses are fleet) | 300 / 240 / 48 / 4 | 133,140 |
| CLINIC | 480 / 420 / 36 / 6 | 208,730 |
| SCHOOL | 480 / 480 / 18 / 6 | 208,470 |
| POLICE | 360 / 360 / 24 / 4 | 157,800 |
| ADMIN | 360 / 360 / 12 / 4 | 156,150 |
| PRISON | 600 / 720 / 36 / 6 | 266,910 |
| BANK | 240 / 240 / 12 / 3 | 104,650 |
| NEWSPAPER | 180 / 180 / 12 / 3 | 78,900 |
| OFFICEBLOCK | 300 / 300 / 15 / 4 | 130,810 |
| LANDLORD (a block of 50 homes, house form) | 1200 / 720 / 24 / 6 | 500,440 |
| BUILDER (a yard, for a builder founded in the colony) | 120 / 120 / 6 / 2 | 52,330 |

TRANSIT and SANITATION were not in Otto's list. TRANSIT has a yard like the haulier's. SANITATION is billed like the
other services. Both carry their vehicles as fleet, not in the bill (section 4). Agreed with Otto.

## 9. Month one, on paper (plan section 13: "Month one has to add up")

### 9.1 The starting numbers this check uses

| What | Figure | Whose |
|---|---|---|
| General salary | 300 (S 450, Sp 675) | this table |
| Settlers' savings per household, by income band I1 to I5 | 1,800 / 3,600 / 7,200 / 14,400 / 36,000 (6, 12, 24, 48 and 120 months of a general salary) | **(Bob; Maja owns the founding population)** |
| Grants | family farm 15,000; family bakery 15,000; truck driver 10,000; truck workshop 10,000 | **(Bob)** |
| Land | 10% of the building's bill, as for homes (9.8) | Terra owns the land price; this is a stand-in |
| A founder's opening money | three months of running costs (Otto 4.2) | counted both with and without |
| The home world's price for a good it sells | 2 × the colony's starting price **(Bob)** | 12.11, 105 sets that it moves |
| The landing stock: material | 9,700 MATERIAL and 1,060 COMPONENT | **(Bob)** see 9.4 |
| The landing stock: food | 12 months for the founding population (Wilma's addition, 12.2, 9) | |

### 9.2 Can a settler found a family farm, and a truck driver?

| Plan (family size) | Building | Land | Opening money | Total | Grant | Who can (with opening / without) |
|---|---|---|---|---|---|---|
| **Family farm** (40 BW, 40 MAT, 2 COMP, 3 months) | 17,440 | 1,740 | 4,250 | 23,440 | 15,000 | I4 and up / I3 and up |
| **Truck driver** (one truck, no building) | 12,850 (from the home world at twice the price) | none | 2,890 | 15,740 | 10,000 | I3 and up / I2 and up |

- **Yes for both,** from the middle band up.
  - The farm's "three months of material up front" is all of its 40 MATERIAL and 2 COMPONENT (1,760 cr). A family
    farm's whole bill is under three months' supplies.
  - I1 and I2 households (the poorer 40% if the bands are even) cannot found anything.
- **The truck driver waits for a ship.**
  - No truck maker stands at landing, so the truck comes from the home world. It is ordered with a ship in port and
    arrives on its next call, which is a year and a half or more away (9.6).
  - In step 3 that does not matter (no freight until step 4). In a full game, the first colony-made truck needs a
    components works, which no settler can pay for without the bank (9.3).
  - Wilma has decided the landing stock holds trucks, enough for the first truck drivers (step-2 brief), so the first
    drivers need not wait for a ship.

### 9.3 Which types can be paid from savings and a grant alone (no bank until step 5)

At family size, the poorest band whose savings (with the grant, where the type has one) reach the plan:

| Can | Types |
|---|---|
| I2 and up | truck driver (without opening money) |
| I3 and up | family farm (without opening money), truck driver (with opening money) |
| I4 and up | family farm (with opening money), truck workshop, family bakery (without opening money) |
| I5 only | family bakery (with opening money); SERVICEHUB, SHOP, CAFE, CHILDCARE, ELDERCARE, BANK, NEWSPAPER, SANITATION, OFFICEBLOCK, POLICE, ADMIN, TRANSIT, BUILDER (21,000 to 32,000); TEXTILE and FURNITURE without opening money (33,850) |
| nobody | MINE, PROCESSING, COMPONENTS, CONSUMERF, MEDWORKS, POWER, WATERWORKS, CLINIC, SCHOOL, PRISON (38,000 to 72,000), and a family landlord (8 homes, 92,000) |

What follows for step 3 (a result to report, not a number to change):

- **Nobody in the colony can found a mine, a processing works or a components works before the bank lends.** Until
  step 5 the colony's material and components come only from the landing stock, unless the government builds the
  works itself (12.11, 102). This is the main limit step 3 will show.
- **No private landlord can start before the bank.** In step 3 there are no new homes at all: homes come at step 7, so
  the settlers live in the landing shelters. In a full game, new homes come from the housing office (the government)
  until the bank lends.
- **The only buildings in step 3 are family-size plans** of founders in bands I3 to I5, and the government does not
  commission until its purse comes (step 8). Otto adds the same to rebuild-building.md.
- **A family bakery needs power and water,** so it cannot run before the grid, whoever pays for it.
- POLICE, ADMIN, PRISON, CLINIC and SCHOOL are public services in month one (9.12), so the government is their founder.

### 9.4 The landing stock

"5 years worth of equipment": I read it as **what the five builders can build in five years at full crews, at the
average mix of Otto's bills**. **(Bob)**

- The five builders are 3 full units (Otto 4.1), so 180 BW a month: 10,800 BW in five years.
- Otto's bills average 0.90 MATERIAL and 0.098 COMPONENT per BW, so the stock is **9,700 MATERIAL and 1,060
  COMPONENT**, worth 507,000 cr at the starting prices.
- **This reading assumes crews that do not grow.** But builders hire, with no speed limit (12.3, 28; Otto 4.6), and
  in month one most settlers are jobless. So once crews grow, the stock lasts well under five years. The other reading,
  "five years of the colony's expected building", gives a larger stock. "5 years worth" is the user's phrase, so the
  choice is the user's (Otto's review).
- It is offered by the government at those prices (12.2, 9). While it lasts, nobody can sell those goods above them
  (Otto 4.1). Watch item: a buyer may stock up from it in month one (9.3), because its fixed price is below what the
  material is worth to most buyers.

### 9.5 Does the landing food outlast the first harvest?

The colony needs 1 FOOD per person a month. A full farm makes 156, so a family farm makes 24.4 (156 / 6, less 6%) and
feeds 24 people.

The timeline for one family farm, if its plan is signed in month 1 and a builder starts at once:

| Months | What happens |
|---|---|
| 1 to 3 | built (the fewest months for a family farm is 3; a builder puts 13 BW a month on it) |
| 4 | the plant opens (the month after it is done, Otto 4.8) |
| 4 to 7 | the crop grows. Its first harvest comes 4 months after opening **(Bob: growing time; the planet's seasons may move it, 12.4, 34)** |
| 8 | the first harvest |

For Maja's founding population (1,000 settlers in 400 households; 675 adults in the labour force):

- They need 1,000 FOOD a month: **41 family farms** (or 6.4 large ones). 41 family farms make 1,002 a month.
- 41 family farms are 1,640 BW and 1,640 MATERIAL (17% of the landing material). Once open they employ 164 people.
- **A contract is with one builder** (Otto 4.3). A job takes at most its bill BW ÷ its fewest months a month: 13 BW
  for a family farm, 105 for a power plant, 90 for a waterworks. It also takes no more than that builder's crew.
- **Builders hire** toward the work in their books, with no speed limit (12.3, 28). But the labour force is a limit
  now: 41 farm jobs at once take 547 builder crew, out of 675 adults, of whom about 100 work for the government's
  subsidiaries **(Bob: stand-in for Wilma's staff figure)**.
  The crews and the farms need the people one after the other, not together (Otto's re-read): the 547 are hired for
  about three months and are free again (rule 4) when the farms open and hire their 164. That is why 675 adults is
  enough.
- **The founders read rule 7 from month 1:** the colony buys food from the landing stock, and that counts as work for
  farms (15a).
- Food: 12 months landed (12,000), spoiling at 1% a month. Worked month by month:

| Case | Farm jobs at once | Farms harvesting | Landing food | Result |
|---|---|---|---|---|
| **Step 3, builders hire** to 547 crew (no government jobs; the purse comes at step 8) | all 41 | 40 from month 8, all from month 9 | 5,400 at month 6, 4,300 at month 9, then a slow fall | **holds, with about 3,500 to spare** |
| **Step 3, crews stay at 180** | 13 | 13 from month 8, 26 from 11, 39 from 14, 41 from 15 | 2,900 at month 9, 1,500 at 12, 900 at 18 | **holds, with about 800 to spare** |
| **A full game, crews that cannot grow,** the government's power plant and waterworks on the large and one average builder | 6 (80 BW) | 5 from month 8, 10 from 11, 15 from 14 ... 41 from month 30 | 2,600 at month 9, 100 at month 12 | **runs out in month 13.** At month 18 the colony is short by about 3,500 meals, and it is short every month until about month 30 |
| **A full game, builders hire** | as step 3, less the 100 BW on the big jobs | about month 9 | as step 3 | holds |

So with farms making 156: **12 months of landing food holds in step 3 whether or not builders grow, and in a full game
only if builders hire.** If the crews cannot grow and the government's big jobs come first, the colony runs out of food
in month 13. That is a result, not a fault (plan section 13, watch item 4), but it is a real one. The labour force is
the new limit: 41 farm jobs at once need 547 of the 675 adults on building crews.

**A second limit:** the founders must be in bands I3 to I5 (with the grant). For 41 farms that is 41 households of
the richer 60% (240 households), one grant each (12.9, 61). Enough.

**A family farm is still within reach.** Its building does not change with the farm's output (17,440, land 1,740,
opening money 4,250; total 23,440 with a 15,000 grant): bands I4 and up with opening money, I3 and up without.

### 9.6 The salary line at landing and after

The salary formula, as Wilma revised plan 12.5 (37): one salary carries a household's home and food with half again.

> salary line = 1.5 × (rent of a home in the area + 2.5 × food price)

| When | Rent | Food for 2.5 | Line |
|---|---|---|---|
| Landing: shelters at half a new house | 48 | 152 | **300** (the anchor; it holds by the farm's output, section 1) |
| When new houses replace the shelters | 97 | 152 | **373** (+24%) |

- **The line RISES as houses replace shelters.** Rent doubles from 48 to 97, and the line follows.
- Salaries themselves move only by the rules (9.2). The line is the tie-breaker of rule 9 for a salary, and what a
  worker needs (two-thirds of the line: 200 at landing, 249 with houses) before they apply for a job.
- So once houses stand, workers need more before they apply, and a company paying the landing salary of 300 still
  gets applicants (300 is above 249).

## 10. What is not in this table

- **The road bill per link** is Terra's (Otto 3).
- **The upkeep column** is Otto's (section 8).
- **What a household needs** (section 2) is Maja's to set; it is here only so the colony's demand can be sized.
- **Quality and reputation** of consumer goods are left out (12.12). A truck's quality is set when it is made and
  stays.
- **Supply contracts and storage space** are left out (12.12).
