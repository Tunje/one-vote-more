# The rebuild: one company object

Status: DRAFT 7 by Wilma, 2026-11-17 (the seven decisions of section 8e are the user's). Reviewed by all six sessions ([rebuild-reviews.md](rebuild-reviews.md)). The places where the reviews caught this plan contradicting a ruling are corrected (rules 2, 4, 7 and 9, ships, the freight queue, "huge company", grants). The parts the reviews found MISSING are listed in section 13 and are not yet designed. Not reviewed. Nothing is built.

Sources: the user's order below; the open connections in [economy-connections.md](economy-connections.md); the rulings of
2026-11-14 to 2026-11-17 in [MASTER-PLAN.md](MASTER-PLAN.md); the old economy as it stood in commit 785c72f and
`game_full_copy/`.

Every line marked **(proposal)** is Wilma's and is not decided. Everything else is the user's ruling or a fact of the code.

## 1. The order (the user, 2026-11-17, verbatim)

> Now you build it from the ground up one object that is the company it's size family to large 4 sizes, the nine rules plugged into that the offices as a bonus building the work they do behind states if needed otherwise it's just a 2d array of wich items a company type makes,  if they pick from first or second output all in one object, then roads and supply networks since the same company can become freight that's done already, polution plugg ins to the same okay? Food output plus into the same no more godawfull single sided junk services have no output but a client take in,  stress for workers reduced output based on workers all of it into the company okay? No more only this sector shit, they start with their own and ship out build a plan with all of it adjust the plan until you see every component in the relationships we have them in anything outside needing something how it gets it,  then you ask all the others to review from their and you rewiering FUCKING STOP

What that means for the build:

1. There is ONE kind of thing that produces: the company. Farm, mine, bakery, builder, haulier, clinic, service hub,
   landlord, power plant are all the same object with a different row of the type table.
2. Four sizes, family to large.
3. The nine rules are part of the object. No company type has its own copy of a rule, and no rule is missing for a type.
4. What a company makes is a row in a table (type × item), with a first and a second output.
5. Offices are a bonus building, not a condition.
6. Freight, pollution, food, services, worker stress are parts of the same object, not separate systems beside it.
7. A company starts with what it has and ships out.
8. No fix is built behind an off switch (ruling of the same day). Each part is built on the parts before it, tested there,
   and stays on.

## 2. What went wrong before, in one paragraph

The old economy had 66 files and 31,000 lines. Each sector had its own rules file (`econ_rules_food`, `_mat`, `_svc`,
`_housing`, `_utilities`, builders, hauliers, institutions, workshops, families), each with its own version of price,
output, capacity and founding. A fix was written for one sector, tested against a game that did not contain the other
fixes, and merged switched off. When all 22 ran together for the first time (v12) the colony was a third of the size of
v11. The very first of them, alone, already broke the builders. One object with one set of rules removes the place where
that happened: there is nothing sector-specific to drift apart.

## 3. The company object

One record per company. Everything below is a field of that one record or a function that takes it.

| Field | What it is |
|---|---|
| `id`, `name`, `type` | `type` is a row of the type table (section 4) |
| `size` | 1 family, 2 small, 3 medium, 4 large (section 5) |
| `owner` | who owns it: a family, private owners, a co-op, the state, a party, a union, the home world |
| `plants` | the places it works at: each has a tile, a district, a condition, and how many units of the type row it runs |
| `staff` | the people it employs, by skill tier, with their stress |
| `stock` | what it holds of each item, at what cost |
| `money` | its account in the ledger, its loans, its yearly books |
| `price` | ONE price per company for each thing it sells (ruling: "No i said each COMPANY") |
| `orders` | the orders it has received, filled and unfilled, and why an unfilled one was unfilled |
| `plan` | while it is not yet open: the plan it is (ruling: plans are made before they become companies, before a grant is accepted; a plan cannot fail) |
| `office` | the place it rents in an office building, or none |
| `fleet` | its trucks, each with a quality and wear, if it carries freight |
| `emissions` | what its plants put out this month |
| `signals` | the nine rules' inputs, computed once a month from the fields above |

Nothing about a company lives anywhere else. The market, the bank, the builders and the government read and write this
record; they keep no copies.

## 4. The type table: one 2D array

Rows are company types, columns are items. A cell says how much of the item ONE unit of that type takes in or puts out
per month. The old `RECIPES` table had this shape for 34 types. Its type names are the starting list; none of its numbers carry over (section 8c).

| Column group | Meaning |
|---|---|
| inputs | items bought or taken from own stock (energy, water, mineral, material, component, food, consumer goods, medical) |
| first output | the item it makes by default |
| second output | another item the same plant can make instead; the company picks first or second by rule (section 6, rule 3) |
| clients | for services: how many clients one unit serves. A service has NO output item; it has a client intake |
| labour | workers per unit by tier (general, skilled, specialist) |
| pollution, accident, hazard | per unit |
| build bill | work, material, components and months to build one unit |
| freight room | how much it can carry per truck, for a type that carries |

Rulings this table carries:

- **First or second output.** Example the user gave earlier: a components works can build trucks as special orders
  (lowest quality); a truck workshop builds them better. So `COMPONENTS` has second output TRUCK, and `TRUCKSHOP` has
  first output TRUCK REPAIR and second output TRUCK.
- **Services have no output but a client intake.** A service hub, a clinic, a school, childcare, eldercare, a police
  station, administration: each serves N clients per unit. What a client pays (a price, or a tax bracket for a public
  service: "per pupil plus staff is how taxes for schools are calibrated") is the company's income. There is no
  SERVICES item on a market.
- **Food is an item like any other** and food producers are companies like any other. No separate food system.
- Types that only existed to hold staff (`OFFICE`, `HQOFFICE`, `NEWSROOM`, `BIZSVC`, `RETAIL`, `COMFORT`, ...) are
  looked at one by one in review: each either becomes a real row (it sells something or serves clients) or goes.
  **(proposal)**

## 5. Four sizes

The user, 2026-11-17, verbatim: "Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size the output for each is the same but with a small penalty for their smaller size"

| Size | Name | Share of the full-size row | What it is |
|---|---|---|---|
| 1 | family | 1/6 | one household runs it |
| 2 | small | 1/3 | |
| 3 | average | 2/3 | |
| 4 | large | full size | the type row as written |

Size is a multiplier on the type row (inputs, labour, output, build bill); it is not a different kind of company. Output
per unit of size is the same for all four, less a small penalty for the smaller ones. The penalty: family 6% less, small 4% less, average 2% less, large none
(Wilma's figures, accepted by the user: "You penalty is fine"). A company grows or shrinks one size at
a time by the capacity rules (5 and 6).

## 6. The nine rules, plugged into the object

One implementation, called for every company every month. Each reads only the company's own `signals` and the market.
No rule is skipped for a type because it cannot take effect today (ruling).

| # | Rule | Signal it acts on |
|---|---|---|
| 1 | raise the price | it sold what it offered and orders went unfilled FOR PRICE-INDEPENDENT REASONS EXCLUDED ("if something else than price stops sales it should not count on adjusting price") |
| 2 | lower the price | stock that was offered and went unsold BECAUSE OF PRICE ("the more inventory you have, the more you reduce your price"). Stock held back is nobody's signal. Stock that did not sell because of freight, the road or the buyer's money counts neither here nor in rule 1 (the same ruling as rule 1) |
| 3 | raise output | "if you sell out all your producing produce MORE"; also picks first or second output by which pays |
| 4 | lower output | output that went unsold because of price, with the same two exclusions as rule 2 ("Ignore the stoch in that other place too") |
| 5 | add capacity | "if your selling out and all plants at max build a new one ... money is a limitor". Growing: one size up in its own square; buy out the companies sharing the square; or, if it cannot or that is too expensive, a new plant elsewhere (section 8e) |
| 6 | cut capacity | a plant that stands idle for a set time. A hard rule is fine here (the user, section 8e). **(proposal: the time.)** |
| 7 | start a company | the average of all available work ("instead of reading the leftovers, they read an avrage of all avaliable jobs"), with no cap on how many may form |
| 8 | do not start one | the same signal says the work is already covered |
| 9 | priority | "if below making price climbing allways had priority if above lowering has priority if both signals come in the same month only the one with priority happens, and if your going to cap it at 5% THEN DO THE SAME FOR BOTH". So: priority matters only when BOTH signals come in the same month; one signal alone acts whichever side of the making price the company is on. If there is a cap it is the same both ways; 5% was the old code's figure, not the user's. |

Kept with them:

- **Hold-back:** a seller below cost offers what covers all its monthly expenses, not everything ("It sells too cover
  all monthly expences"). No hard floors.
- **No limit built on last month or last year.** Credit follows orders, contracts and forecasts.
- **Imports are a backstop:** ordered in only while no plant in the colony makes the good, and only on a ship in port;
  the answer or the goods come back with that same ship on its NEXT call, so the full round trip every time.

## 7. The parts plugged into the same object

Each is a function over the company record, not a system of its own.

| Part | How it plugs in |
|---|---|
| **Office** | a bonus building. A company with a staffed place in an office building works at full output; without one it loses about 15% ("you lose out on some not all lets say something like 15% less"). Office buildings are real buildings, put up by builders, owned by a private landlord (itself a company, type OFFICE BUILDING, clients = tenants); one building holds the office workers of ten plants; only a huge company owns its own (huge = its office workers fill a whole building, ten plants' worth or more; that is not the same as size 4). Offices are not essential and never hire first. |
| **Freight** | any company with trucks can carry ("the same company can become freight that's done already"). Freight is the company's own fleet moving its own or others' goods over Terra's road network; a haulier is a company whose type row has freight room and nothing else. Truck quality is set when built and stays; trucks wear; workshop repair uses components and resets wear, about 5% lost each time; self-repair takes about 4 months. |
| **Roads and supply networks** | Terra's `Transport` (kept, in `sim/transport`). A company ships from its plant's tile to the buyer's over the network; what cannot be carried waits in a real queue and is carried the following month (the user on the depot rule: "count the work que not passed work"; on the queue: "That works"). A haulier's output rule reads that queue. Goods waiting for freight are not unsold stock (rule 2). |
| **Pollution** | the type row's pollution × units running, written to `emissions`; the planet reads it. |
| **Food** | a food company's output is FOOD stock like any stock; households buy it on the same market. |
| **Services** | client intake (section 4). |
| **Stress** | per company from hours and staffing; stress reduces output ("stress for workers reduced output based on workers"). Truck workshop quality follows its workers' stress (ruling). |
| **Building** | a builder is a company (type BUILDER, output BUILD WORK). It needs 3 months of supplies up front and adds 1 month each month. It keeps an order book and quotes a start date. A plan signs with a builder before it becomes a company. |
| **Housing** | a landlord is a company (type HOUSING, clients = tenant households). |
| **Public services** | a clinic or school is a company owned by the state, paid by a tax bracket per client plus staff. All company types can be private; rules 7 and 8 decide whether one appears. |

## 8. What is NOT the company

These stay outside it, and each talks to companies only through the record above.

| Outside thing | What it is | How it meets the company |
|---|---|---|
| People and households | Maja's population (`sim/population`) | work for a company (`staff`), buy from companies (orders), are clients of services, own family companies |
| The market | one order book per item | companies post offers and orders; cheapest delivered first |
| The bank and money | the ledger (`sim/core/ledger.gd`) and one bank | lends on orders, contracts and forecasts |
| The government | politics (`sim/politics`) | owns state companies, sets tax brackets and levers, commissions buildings from builder companies. Grants only where the user ruled them: family farms and bakeries, truck drivers and truck workshops ("I DID NOT SAY GIVE EVERYONE ... GRANTS") |
| The home world | `home_world.gd` | ships: the only way anything enters or leaves; orders go and answers come with a ship in port |
| Unions | outside the company (ruling, section 8a) | protests and shutdowns act on a company's output; members are staff of any company |
| The map | Terra's planet, roads, town grid | a plant has a tile; a truck has a route |

### 8a. Unions (the user, 2026-11-17, verbatim)

> Unions belong outside, a union is started from one company with bad working conditions but any other company staff from others can join, unions protest bad conditions,  and get a small fee from every person in it,  the union orders protests and shutdowns they last depending on hour long the union can pay the workers, the workers get 2/3 normal sallery during this time,  the goverment can lean on companies if they don't comply or on the union,

As rules:

- A union is not a company and is not inside one.
- It starts at ONE company with bad working conditions. Staff of any other company can join it.
- It takes a small fee from every member. That is its fund.
- It protests bad conditions. It orders protests and shutdowns.
- A shutdown lasts as long as the union can pay the workers. The workers get 2/3 of their normal salary during it, paid
  by the union.
- The government can lean on a company that does not comply, or on the union.
- What it reads from a company: its working conditions (the stress part of section 7). What it does to a company: its
  staff stop work, so its output stops.

### 8b. Workers, salary, skills and changing jobs (the user, 2026-11-17, verbatim)

> Workers and sallery, skills and swapping jobs to better payed,  actually the three rules for price should be applied here too

As rules:

- A salary is a price, and the three price rules apply to it: rule 1 (raise), rule 2 (lower) and rule 9 (which of the
  two has priority, the same cap both ways). One salary per company and skill tier, as there is one price per company.
- Workers have skills. A post asks for a skill tier; a worker fills posts at their tier.
- Workers change jobs to better-paid ones. That movement is the signal the salary rules act on.

**(proposal, Wilma's reading of how the three rules map onto salaries; the user gave the principle, not these lines.)**

| Rule | For a product's price | For a salary |
|---|---|---|
| 1 raise | it sold what it offered and orders went unfilled | its posts stay open, or its workers leave for better pay |
| 2 lower | offered stock stays unsold | more people apply at its salary than it has posts |
| 9 priority | below making price, raising has priority; above, lowering | the line is the starting salary of section 8c (settled in section 8d) |

Only the pay signal moves the salary: a post that stays open for another reason (no housing nearby, no one with the
skill in the colony) is not a reason to raise it, as with prices ("if something else than price stops sales it should
not count on adjusting price").

### 8c. Households, company types and the starting salary (the user, 2026-11-17, verbatim)

> 3. Housholds follow terras latest plan, 4. Same company types can come but not their code or balancing 5. Sallery should be calculated as avrage living in the area and food plus half of both again, that's the start then it should regulate itself

As rules:

- **Households follow Terra's latest plan.** Wilma reads that as [design-town-grid.md](design-town-grid.md): homes on
  the town grid, and what each household type wants from where it lives. Terra confirms in review which document it is.
- **The same company types can come back, but not their code and not their balancing.** The 34 type names of the old
  table are the starting list. Every number in the table (inputs, outputs, labour, pollution, build bills, base prices,
  wages) is set again from nothing, and no old rule code is copied.
- **The starting salary** = the average cost of living in the area plus food, plus half of both again:
  1.5 x (average housing cost in the area + food). That is where a salary starts; from there it regulates itself by the
  three rules of section 8b.

### 8d. Hiring salary and the yearly bonus (the user, 2026-11-17, verbatim)

> You penalty is fine,  that's fine for hiring, then every year a company can grant a bonus what the minimum of this is is up to the government, 2% is a good start

As rules:

- **Rule nine for salaries** turns on the starting salary of section 8c (1.5 x housing plus food at today's prices in
  the area): below it raising has priority, above it lowering has priority. That is the salary a company HIRES at.
- **Every year a company can grant a bonus** to the people it already employs. The government sets the minimum; the
  minimum starts at 2%. It is a lever of the government's.

### 8e. The seven places where rulings met (the user, 2026-11-17, verbatim)

Wilma listed seven: 1 one price per company against rent that shifts from road to road; 2 one price against a builder
whose jobs differ; 3 one price set by the rules against a public service's tax bracket; 4 one salary per company
against a starting salary "in the area" with plants in two districts; 5 rules 2 and 4 read unsold stock, which a
service, builder, landlord and truck repair do not have; 6 growing one size at a time against rule 5's "build a new
one"; 7 rule 6 needing a fact for "idle". The user's answer:

> On sallery it's an avrage of the area.  2. I don't see the controdiction. 3. Again yes things can be done in two different ways based in company types how its this a problem? 4. The district the plant hiring is in.  5. They have empty work slots. 6. Depends on region, in a square if there are other companies they would have to buy out the other company to make it larger, three small in a square of they can't buy out or it's too expenvice build a new  7. A hard rule here is fine

As rules:

- **The principle (answer 3):** things can be done in two different ways depending on the company type. That is not a
  problem and not a contradiction. The type table says which way a type does it.
- **Salary:** it is an average of the area.
- **1, rent by street.** Not answered by number. **(Wilma's reading, from answer 3:)** a landlord is a company type
  that prices its own way: each home's rent follows its place, and the company still decides it by the same rules.
- **2, builders.** The user sees no contradiction. **(Wilma's reading:)** a builder has one price, per unit of build
  work; a bigger job is more units at that price, with its materials on top.
- **3, public services.** A state service's price is its tax bracket; that is that type's way of having a price.
- **4, salary with plants in two districts.** The line is that of the district the hiring plant is in. So a salary is
  per company, tier AND the district of the plant that hires.
- **5, types with nothing to stock.** Their signal is empty work slots: client places not taken, crews without a job,
  homes without a tenant, repair bays standing empty. Rules 2 and 4 read that where other types read unsold stock.
- **6, growing.** It depends on the region. A square holds a full size of company. A company alone in its square grows
  one size at a time. If other companies share the square (three small ones fill it), it has to buy the other out to
  grow there. If it cannot buy them out, or that is too expensive, it builds a new plant elsewhere. **(Wilma's reading
  of "a square": the map tile a plant stands on, which holds one full-size unit: one large, or one average and one
  small, or three small, or six family.)**
- **7, cutting capacity (rule 6).** A hard rule is fine here.

### 8f. Households taken wholesale; buildings wear (the user, 2026-11-17, verbatim)

> Okay i think we can take it wholesale as long as we make sure it fits in,  buildings,  did that belong to economy or something else ware and tear, repair all that,  that's what changed eent levels for the landlord

- **Households:** the old household side is taken as a whole, as long as it is made to fit: pools of people by housing
  block and income band with their money; wages, benefit, pensions, dividends in; rent and bills, then food and
  essentials, then the rest out; the job recorded with both the person and the company; ages, births, deaths, growing
  up, retirement; shacks and homelessness; settlers arriving and people leaving on ships. What it was is described from
  the old code in the conversation of 2026-11-17 and stands in `game_full_copy/` (econ_households, econ_pop,
  econ_cohorts, econ_informal). "Fits in" means it meets the company only through section 8's relationships: staff,
  customers, clients, tenants, owners. It is an exception to "no old code carries over", by the user's word.
- **Buildings: wear, repair and rent.** In the old game this was the economy's, and it was cut with it:
  - every plant had a condition from 0 to 100; upkeep (materials) kept it up, and without upkeep it fell;
  - a worn plant produced less and had more accidents; a hazardous plant below 25 was closed as unsafe and overhauled;
  - housing also lost condition with age, hardly at all for 20 years and then fast, half as fast when well kept;
  - below 55 the owner decided each quarter: renovate (a building job for the builders, about a third of a new block)
    or let it slide;
  - a block that slid had its RENT FALL WITH ITS CONDITION; below 35 it was run-down housing, and a district averaging
    below 35 was a slum.
  In the rebuild this is the `condition` of a company's plant, the same for every type: upkeep holds it, wear lowers
  output, repair is a job for a builder company, and for a landlord the condition of a home is part of what its rent
  can be.

### 8g. Owning your home; building your own house (the user, 2026-11-17, verbatim)

> I belive you should be able to buy your house out so you own it,  and if an individual becomes richer than the neibouhood he was able to build his own larger house we could use the 1/6 of a farm for that

- **Buying your home out.** A household that rents can buy its home from the landlord and own it. An owned home pays
  no rent; its upkeep and repair are the household's.
- **Building your own, larger house.** A household that has become richer than its neighbourhood can have its own
  larger house built. The size of that build is the family size, 1/6 of a full unit (the user: "we could use the 1/6 of
  a farm for that"). It is a building job for a builder company like any other.
- **Fitting in (accepted by the user: "That's fine"):** the household side taken from the old game counts people in
  pools by housing block and income band, not as single families. "An individual richer than the neighbourhood" is the
  top band of a block moving out to houses of their own, a few households at a time.
- The price a landlord sells a home for: settled in section 8h.
- **For reference, the OLD game's numbers (they do not carry over):** a housing block of 50 homes took 1,200 units of
  building work, 700 material, 20 components and 6 months, estimated at about 1,812,000 credits, or about 36,200 a
  home. Private rent started at 260 a home a month, so a full block took about 11.6 years of rent to pay for itself
  before upkeep. A 1/6 farm took 42 work, 42 material, 2 components and 2 months: about 74,200 credits.

### 8h. Homes on the map: Terra's proposal, accepted (the user, 2026-11-17)

Terra's opinion (in full in [rebuild-reviews.md](rebuild-reviews.md)) was put to the user point by point. The user:

> This sounds good

So these stand:

- **"A square":** for plants in the country, the 3 km tile. In a town with a grid, the 400 m street block (16 cells,
  about 128 houses): three small landlords fill a block, and one has to buy the others out to grow there.
- **What a home costs to build:** the bill for its form (apartment 0.85 of a house, tower 1.15), plus the street, pipe
  and cable to reach it, plus the land priced by its cell's value.
- **Payback:** aim for 12 to 15 years of rent on an ordinary cell.
- **Rent of a home** = the landlord's own rent (moved by the rules, with empty homes as the signal) x the cell's value
  / 1000 x a condition factor. The condition factor is 1 above condition 55 and falls in step with condition below it.
  Value and condition stay separate.
- **Sale price of a bought-out home:** the rent it brings in at that place and condition, times the same payback years.
  After the sale the owner pays the upkeep.
- **An own larger house:** a builder's job on two or four joined plots, its land at the cell's value; it needs a villa
  model.
- **A bought home stays where it stands.** A sale or buy-out never moves houses around the map. Owned homes are a count
  per block; the town view picks which plots show as owned.
- The town grid is part of the rebuild and is on (nothing behind an off switch).

**Upkeep of an apartment building with owned flats (the user, 2026-11-17, verbatim):**

> If you own an appartment there is a fee for uppkep to the landlord that owns the rest of they all own then they are a community and they all pay together

- The owner of a flat pays an upkeep fee to the landlord who owns the rest of the building; the landlord keeps the
  building up.
- When every flat in the building is owned, the owners are a community and pay for the upkeep together. The landlord
  is out of that building.

**Small places and the price of land (the user, 2026-11-17, verbatim):**

> Below 250 start a gridd anyway and only use what you need,  and set a credit prices we are going to have to adjust it anyway i don't have a sheet of what costs what so i can't tell you what it should cost

- **A place below 250 homes gets a town grid anyway,** and uses only as much of it as it needs. So every home has a
  cell and a value from the first house on. (This replaces the earlier threshold of 250 homes.)
- **Land has a price in credits, and we set it.** The user has no price sheet; all prices are ours to set and will be
  adjusted in testing. That holds for every number in the type table.
- **Starting figure for land (Wilma's, to be adjusted):** the land for one home on an ordinary cell costs 10% of that
  home's building bill, and scales with the cell's value (value / 1000).

### 8i. The end of a company (the user, 2026-11-17, verbatim)

> End of a company can happen in three ways,  each with its own survival clause, first sales death, if even with the company hording and just trying to stay afloat it cant turn the price in two years its going to sell of its stock and shuts down,  it's plants shut down and it cant affort too replace them and finally someone buys them out, the last one has to do with land and if they get enough they can buy another building and continue there

Three ways a company ends, each with its own way to survive:

| # | How it ends | What happens | How it survives |
|---|---|---|---|
| 1 | **Sales death** | Even while holding stock back and only trying to stay afloat, it cannot turn its price in two years. It sells off its stock and shuts down. | It turns the price within the two years. |
| 2 | **Its plants shut down** | Its plants shut down and it cannot afford to replace them. | It can afford to replace them. |
| 3 | **Someone buys it out** | Another company buys it out. This one has to do with land. | If it gets enough for it, it buys another building and continues there. |

**(Wilma's reading:)** the user gave the survival clause in words only for the third; for the first two it is taken from
the sentence itself (it ends "if it can't", so it survives if it can). "Turn the price" is read as: get its price back
above its making price, the line rule nine turns on. The buy-out is the same event as growing in a shared square
(section 8e, 6): the buyer wants the place; the seller is paid and may start again elsewhere.

What the old game had and this replaces: distress, administration, liquidation and dissolution as a state machine
driven by missed payments. Not carried over. Settled by the user in section 8j: the staff are laid
off; the loans are paid from the sale of the stock, and if that is not enough the owner is taken to court. Still to
place: the court winding a company up for convictions (the law's own fourth way, Anni's review 1b).

### 8j. Month one; noise; what follows an ending (the user, 2026-11-17, verbatim)

> 5 building companies and alot of oppretunity and the goverment starts with its subsidiaries as before,  and all three grant types open, and no sectors beyond landfallpoint that's up to where things are built, things like noise polution should also drive down price of housing so we don't have factories all in among the houses, or rather less. Yes they are laied of its loans are payed in full if they can when selling their stock, if not the owner is taking to court, where the bank can either settle for a smaller amount or demand payment over time, if he is rich or owns other companies a settlent might be reached

**Month one**

- **Five building companies,** and a lot of opportunity: much to be built and few to build it.
- **The government starts with its subsidiaries as before.** In the old game those were Colony Power & Water, the
  Colony Transit Authority, the Colony Housing Office and the Colony Works Department (the public builder of last
  resort), plus the public institutions (clinics, schools, administration).
- **All three grant types are open** from the start. **(Wilma's reading: family farms, family bakeries, and trucks,
  the last covering truck drivers and truck workshops, which the user introduced together "started by grants alla
  bakeries".)**
- **No sectors beyond the landfall point.** The colony starts as one place, where it landed. There are no districts
  laid out in advance; where things come to be is decided by where things are built. (The old game started with six
  named districts.)
- The old game also started with private founders: two farms, a mine, a material plant, a components works, a consumer
  goods maker, a service company, a landlord and two builders. The user's "a lot of opportunity" is read as: these are
  NOT placed by us; they appear through rule 7 and the grants. **(Wilma's reading; a colony needs food and power in
  month one, so what the government's subsidiaries cover at the start has to be enough to live on.)**

**Noise**

- Noise and the like from a plant lower the price of the homes near it, so factories do not end up in among the houses,
  or less so. On Terra's map this is part of a cell's value, which already falls near industry and fast roads; a
  company's type row carries how much noise it makes.

**After an ending (completes section 8i)**

- The staff are laid off.
- The company's loans are paid in full, if selling its stock brings in enough.
- If not, the owner is taken to court. There the bank either settles for a smaller amount or demands payment over
  time. If the owner is rich or owns other companies, a settlement may be reached.

## 9. Every outside connection, and how it gets what it needs

From [economy-connections.md](economy-connections.md): 367 open lines in 61 files. Grouped by what they ask for.

| Asked for (old name, calls) | Who asks | How it gets it from the company object |
|---|---|---|
| General helpers: sorting, splitting, money scale, treasury account (`EconUtil`, 196) | everyone | not economy: they move to the core, unchanged |
| Government acts on the economy: commission a project, check a budget line (`EconActions`, 44) | politics, office, road law, the map | one action entry: "the state orders a building of type T at tile X" creates a plan owned by the state; the budget line is the state's own account |
| Questions: budget, market prices, shortages, why a plant is stopped, workload, labour (`EconQuery`, 32) | screens, politics, press | one read-only view over the company records and the market |
| Unions (`Unions`, `UnionDisputes`, 28) | politics, press, staff, office | read from the union records (section 8) |
| Ships and trade (`EconTrade`, 19) | home world, office, screens | the port is a company's-eye view too: exports are stock shipped out on a ship in port |
| Households: persons, income, paying wages (`EconHouseholds`, 8) | crime, press, staff | from the population, which Maja owns |
| Building: estimate, bids, award (`EconConstruction`, 8) | decision desk, the map | builder companies' quotes on a state plan |
| People by work status, casualties (`EconPop`, 6) | planet, roads | from the population; a death removes a person from a company's `staff` |
| Staff totals, occupation (`EconLabor`, 4) | press, work law | `company.staff` |
| Police stations, prisons (4 + 3) | police, crime, criminal law | state service companies (type POLICE STATION, PRISON), clients = the district |
| Firm's yearly books (`EconAnnual`, 3) | fines | `company.money` |
| The rest (training, staple food, essentials, institutions: about 10) | politics, office | read from the same view |

Not yet in the list, to be added before review: code that reads the old data tables by name and not by a call. Counted
so far: `facility` 57 reads, `org` 37, `project` 20, `hh` 5, `union` 3, and 105 different `ECON_...` indicators and
levers. In the rebuild `org` and `facility` are the company and its plants; `project` is a plan under construction.

## 10. Build order

Each step is built on the steps before it, with them on, and tested there. Nothing is merged switched off.

1. The company record, the type table, the four sizes. A colony of companies that exist and do nothing.
2. Staff and wages: companies hire people and pay them.
3. The market and the nine rules for ONE item end to end (the user: "Only fix this item for now once we have it right
   we fix the rest"). **(proposal: material, because builders need it.)**
4. All items through the same rules. Food and services are here, not later.
5. Freight on the road network.
6. Builders and the plan stage: new companies and new plants.
7. Bank and credit.
8. The government's side: state companies, tax brackets, grants, commissioning.
9. Offices, pollution, stress.
10. Ships and the home world.
11. Reconnect every open connection of section 9 and the list. The game compiles and runs again at this step at the
    latest; the order of 9 to 11 can change to make it run earlier.

At each step: three 30-year games, and the bottleneck reported before the next step starts.

## 11. Open questions for the user

1. ANSWERED (section 5): 1/6, 1/3, 2/3, full size.
2. ANSWERED (section 8a): unions are outside.
3. ANSWERED (section 8c): households follow Terra's latest plan.
4. ANSWERED (section 8c): the same types, none of their code or balancing.
5. ANSWERED (section 5): Wilma's penalty figures are accepted.
6. ANSWERED (section 8d): the starting salary, for hiring; plus a yearly bonus with a government minimum, 2% to start.

## 12. Review

After the user has seen this draft: Bob (rules, market, bank, freight, food), Otto (builders, housing, plan stage),
Maja (population, institutions), Ella (services, unions, truck workshops), Terra (roads, map, tiles), Anni (law,
utilities) each review it from their side: what of theirs is missing, and which connection of theirs is not answered.

## 12a. Every component of the old economy, placed

The user's order was to "adjust the plan until you see every component in the relationships we have them in". Draft 1
did not do that: it described the company object and stopped. This table goes through all 72 files of the old economy
and puts each where it belongs in the rebuild. "In the company" means a field, rule or plug-in of the one object.
"Outside" means its own thing, with how it meets companies. Placements are Wilma's reading of the order unless a
ruling is quoted; none of the old code or numbers carries over.

**In the company object**

| Old component | What it was | Where it is now |
|---|---|---|
| firm_ai | each firm's monthly decisions: targets, orders, asks, investment, founding | the nine rules (section 6) |
| econ_rules, _food, _mat, _svc, _housing, _utilities, econ_builders, econ_haulier, econ_institutions | one copy of the eight rules per sector | the nine rules, once, for every type |
| econ_production | output from staff, inputs and condition; accidents; emissions | the company's monthly output; `emissions`; accidents as a plug-in |
| econ_family | family farms and bakeries started by grant | size 1 of any type; the grant is the government's (section 8) |
| econ_trucks, econ_haulier | truck drivers, hauliers | `fleet`; any company with trucks carries |
| econ_truck_shop | truck workshops | a type whose clients are trucks (client intake) |
| econ_office | office staff split from the plant | the office bonus (section 7) |
| econ_workload | workload and stress | stress lowers output (section 7) |
| econ_annual | yearly books | `money` |
| econ_forecast | a founder's forecast | the signal of rules 7 and 8 |
| econ_warehouse | stock needs space | `stock`; **(open: whether storage space stays)** |
| econ_consumer | durables, quality, reputation | type rows for the consumer industries; **(open: quality and reputation)** |
| econ_staple | bakery goods preferred over raw food | the bakery row's first output; households' preference is the households' (outside) |
| econ_housing, econ_rules_housing | housing ageing; landlords' rules | a landlord company (type HOUSING, clients = tenant households); ageing is plant `condition` |
| econ_police, econ_care, econ_sanitation, econ_public_jobs, econ_hq, econ_bizsvc, econ_retail, econ_comfort (the supplier side), econ_fleet (buses), econ_commute (the operator side) | organisations that only held staff or took a fee | each becomes a service company with a client intake, or goes: decided type by type (section 4) |
| econ_public_co | self-funding public companies, tariffs the government approves | a state-owned company; its price where the government sets it is a bracket or tariff (see section 13, C15) |
| conduct | firms cutting corners for money and risk | a plug-in on the company: what it does when the law's cost exceeds its gain |
| econ_shares, econ_plan_rescue | the share register; rescues of plans | `owner` as a register of holders; rescue is a change of holders |
| econ_ownership | who expands, public or private, by the government's ideology | rules 7 and 8 for every owner kind ("All company types needs to be able to be created as private") |
| econ_unfinished | a half-built building passed to a new company | a plant with no company; a plan can take it over |

**Outside the company, each its own thing**

| Old component | What it was | What it is now and how it meets companies |
|---|---|---|
| econ_households, econ_pop, econ_cohorts, econ_informal | household money, income, buying, births, deaths, ageing, migration, homelessness | HOUSEHOLDS. Taken wholesale from the old game and fitted in (section 8f). They are a company's staff, its customers, its clients, its tenants and the owners of family companies |
| econ_labor, econ_training | vacancies, matching, layoffs, training | THE LABOUR MARKET. A salary is a price under rules 1, 2 and 9 (section 8b); workers move to better pay |
| econ_market, econ_credit | the order books; buying on account | THE MARKET. Companies post offers and orders |
| econ_bank, econ_bank_risk, econ_money, econ_finance (loans, interest) | the bank | THE BANK. Lends on orders, contracts and forecasts; holds deposits |
| econ_finance (taxes, the grant, budget lines), econ_actions, econ_autopilot, econ_essentials | the state's money and its actions on the economy | THE GOVERNMENT'S PURSE. Taxes companies and sales, owns state companies, pays brackets, commissions buildings, holds the reserve |
| econ_trade, econ_imports | ships, the port, exports, imports | SHIPS AND THE PORT. The only way in or out; a company's exports are stock put on a ship in port |
| econ_construction, econ_unfinished | projects, tenders, bids, progress | THE BUILDING CONTRACT between a client (a plan, a company, the state) and a builder company |
| insolvency | distress to liquidation | THE END OF A COMPANY: three ways, each with its survival (section 8i) |
| unions, union_disputes, econ_unions | unions | UNIONS (section 8a) |
| law_bridge | licences and the law's gate | THE LAW'S HOLD on a company (Anni's review, 1a) |
| econ_victims | the victim fund paid to households | the law's, paid to households |
| econ_indicators, econ_pic, econ_facts, econ_query, econ_report | what the economy publishes: indicators, levers, facts, read-only views | THE PUBLISHED FACE: every indicator, lever and fact the rest of the game reads by name (105 names) |
| econ_setup, econ_sim, econ_provider | builds the month-1 colony; registers the monthly steps | THE START-UP: who exists in month 1 and with what |
| econ_util | helpers | the core |
| econ_foodsec | the food trap fix | gone: a fix for a fault of the old design |

## 13. What the reviews found missing

All six reviews are in [rebuild-reviews.md](rebuild-reviews.md). The same gaps came from several sides. Grouped:

**A. Things that are not a company and that the plan does not have at all**

1. **Households.** The population code holds who lives where and what they believe. Their money, income, what they buy
   each month, rent, births, deaths, ageing, migration, the benefit and pensions were all in the economy and are gone.
   Without them nobody buys consumer goods. (Maja, Bob, Terra)
2. **The labour market:** the link between actual people and the company that employs them, vacancies, layoffs,
   training, commuting. `staff` must be the actual people, not counts. (Maja, Ella, Terra)
3. **The bank beyond lending:** deposits, interest, missed payments, the bank failing, the state borrowing. (Bob)
4. **The state's money:** taxes on companies and sales, royalties, the budget lines with what each has left, the food
   and material reserve the government releases. (Bob, Anni, Maja)
5. **Ships and the port:** the schedule, the fleet, the hold, port stock, home-world prices, the charter quota, the
   merchant who sells landed goods. None of these is a company. (Bob, Anni)
6. **Utilities:** power and water go through a grid, cannot be stocked or trucked, and their price is approved by the
   government. (Anni)

**B. Things about a company the plan does not cover**

7. **The death of a company:** distress, administration, liquidation, the sale of its plants, the court winding it up.
   (Otto, Anni, Bob)
8. **The construction contract:** its terms, progress payments, the price moving with wages and materials, a half-built
   building, the client refusing a quote, roads as build jobs, repair and ageing. (Otto, Terra)
9. **Owners' money:** equity in, dividends out, and what a company holds at the start of a game. (Bob)
10. **The law's hold:** licences, the permit office, closing an unlicensed plant, land leases, taxes the law sets,
    price controls, the law's own records about a company. (Anni)
11. **What a service does to a person:** clinic to health, school to skill, childcare to parents working, police to
    crime; and how a household becomes a client of a service. (Maja, Ella)
12. **Company donations to parties,** which the scandal and campaign side lives on. (Ella)
13. **Where a plant stands:** who picks its tile, its form on the town grid, private roads and tolls, the planet setting
    farm yield. (Terra)

**C. Rules that cannot act as written**

14. ANSWERED (8e, 5): empty work slots. Was: Rules 2 and 4 read unsold stock. A service, a builder, a landlord and a truck repair have none. They need their own
    signal (empty client places, idle crews, empty homes), or a rule is missing for a type.
15. ANSWERED (8e, 3): the bracket is that type's price. Was: A free public service has no price at the door, and a state company's price is a tax bracket the government sets,
    while the rules set one price per company.
16. ANSWERED (8e, 1 to 3): a type can do it its own way. Was: One price per company against a builder whose jobs all differ, and against homes whose rent follows the street
    ("it can even shift from road to road").
17. ANSWERED (8e, 4): the district of the hiring plant. Was: One salary per company against a starting salary "in the area" when a company has plants in two districts.
18. "Cheapest delivered first" needs a freight price before the sale; trucks differ by quality, which a cheapest-first
    market cannot see.
19. ANSWERED (8e, 6): by size in its square, by buying out, or a new plant. Was: Growing "one size at a time" against rule 5's "build a new one": by size, by plants, or both.
20. A union shutdown reads to the rules as unsold output, an idle plant and open posts.
21. The build order: salaries need housing and food prices (step 4) at step 2; rules 5 and 7 need builders (step 6) at
    step 3; builders need credit (step 7) at step 6; the world itself (terrain, districts, the road month) was built by
    the old economy's start-up and is needed at step 1.
