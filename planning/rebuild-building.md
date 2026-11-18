# The rebuild: plans, building contracts and the opening of a plant

**Otto, 2026-11-17. Draft 2, on paper; nothing is built. Reviewed by Bob; his points are worked in.** It works out sections 8.1, 9.7, 12.1, 12.9 and 12.11 of
[rebuild-company.md](rebuild-company.md) (version 13) for build step 3, the first loop, and says what step 6 adds.
Where the plan gave no answer and one was obvious, it is decided here and marked **(Otto)**. The user strikes any that
is wrong. The build bills and building times are agreed with Bob. His type table
([rebuild-type-table.md](rebuild-type-table.md)) holds them and points here. His units: one MATERIAL is about a tonne
of processed building material; one COMPONENT is a crate of machined parts, worth about 4 MATERIAL at his starting
prices.

What the user ruled, and this file keeps to:

- "PLANS ARE MADE BEFORE THEY BECOME COMPANIES DAMNED IT ALL THAT'S BEFORE ACCEPTING A GRANT"
- "you can't fail before you exist ... no worker but also no expenses beyond building"
- "They should not need 90% of supplies up front they should need 3 months up front and add 1 month of additional
  supplies every month"
- "5 building companies and alot of oppretunity"; "materials come with the start not finished buildings 5 years worth
  of equipment that never changed they are companies from the world"

---

## 1. Three records

Each thing has one record (plan 12.8, 50b). Nothing below is copied into another record; the others point to it.

### The plan (before a company exists)

| Field | What it is |
|---|---|
| `id` | |
| `founder` | the person who made it, counted individually from this day (12.9, 60a) |
| `type`, `size` | the type-table row and the size it was planned at (rule 7, 12.3 15a) |
| `area`, `site` | the area, and the cells or tile chosen for it (12.1, 5) |
| `account` | its own account in the ledger (12.9, 60) |
| `grant` | the grant paid in, if any, and its type |
| `contract` | the building contract, once signed |
| `status` | MADE → SIGNED → OPEN (it has become a company); or GIVEN_UP |

A plan has no staff, no stock, no price and no expenses but the land and the building. It is never counted as a
founded or a dead company.

### The building contract

| Field | What it is |
|---|---|
| `id`, `kind` | NEW_PLANT at step 3; SIZE_UP, NEW_PLANT for an open company, REPAIR, UPGRADE, ROAD, HOMES, OFFICE, OWN_HOUSE from the steps that bring them |
| `client` | a plan, a company, a household or the state |
| `builder` | a builder company |
| `type`, `size`, `site` | what is built and where |
| `bill` | BW, MATERIAL and COMPONENT in all, and the fewest months (section 3) |
| `price_bw` | the builder's price per unit of building work at signing |
| `wage_bw` | the builder's wages per unit of building work at signing |
| `signed`, `start_quoted` | the month signed, and the start the builder quoted |
| `done` | BW done |
| `on_site` | MATERIAL and COMPONENT delivered to the site and not yet used |
| `used` | MATERIAL and COMPONENT built into the building |
| `paid`, `owed`, `unpaid_m` | what the client has paid, what it owes now, and for how many months running it has not paid |
| `status` | SIGNED (in the book, not started) → WORKING → DONE; or STOPPED (unpaid); or ABANDONED (a given-up plan's; it can be taken over) |

### The builder company

A builder is an ordinary company (plan section 3) with the builder row. What is particular to it lives in the
ordinary fields:

- its `price` is one price per unit of building work, BW (plan section 4);
- its `orders` are its book: the contracts it has signed, in signing order;
- its `work slots` are its crews. A crew-month with no job is an empty slot.

## 2. The unit of building work

**One BW is one builder worker's month at full output.** A builder makes, in a month, its staff × (1 − its size
penalty) BW. Management and stress bend that from the step that brings them. A plant's bill is so many BW plus its
MATERIAL and COMPONENT. **(Otto)**

## 3. Build bills and times (agreed with Bob)

For ONE full-size unit: BW / MATERIAL / COMPONENT / the fewest months, in Bob's units. At his starting prices an
ordinary plant's bill is mostly labour: a family farm is about 85% building work and 15% material and components.

| Type | Bill | Type | Bill |
|---|---|---|---|
| FARM | 240 / 240 / 12 / 4 | POWER | 840 / 840 / 180 / 8 |
| BAKERY | 300 / 240 / 24 / 4 | WATERWORKS | 540 / 540 / 72 / 6 |
| MINE | 600 / 480 / 72 / 6 | DEPOT (haulier yard) | 300 / 240 / 48 / 4 |
| PROCESSING (material) | 720 / 600 / 96 / 8 | TRUCKSHOP | 240 / 180 / 24 / 3 |
| COMPONENTS | 720 / 600 / 120 / 8 | SERVICEHUB, CHILDCARE, ELDERCARE, shops, cafés | 240 / 240 / 12 / 3 |
| CONSUMERF | 480 / 480 / 60 / 6 | CLINIC | 480 / 420 / 36 / 6 |
| MEDWORKS | 480 / 360 / 96 / 6 | SCHOOL | 480 / 480 / 18 / 6 |
| TEXTILE | 420 / 360 / 48 / 5 | POLICE_STATION | 360 / 360 / 24 / 4 |
| FURNITURE | 420 / 360 / 48 / 5 | ADMIN | 360 / 360 / 12 / 4 |
| BANK | 240 / 240 / 12 / 3 | PRISON | 600 / 720 / 36 / 6 |
| NEWSPAPER | 180 / 180 / 12 / 3 | OFFICEBLOCK (ten plants' office places) | 300 / 300 / 15 / 4 |
| HOUSING (a block of 50 homes, house form) | 1200 / 720 / 24 / 6 | BUILDER (yard) | 120 / 120 / 6 / 2 |

- **Sizes.** A smaller size takes its share of BW, MATERIAL and COMPONENT: family 1/6, small 1/3, average 2/3 (plan
  section 5). Its fewest months = max(2, ceil(full × (1 + share) / 2)): half of the time is the site whatever the size,
  half grows with it. So a 4-month farm is 3 months at family size. **(Otto)**
- **The fewest months is a floor on time,** not a promise. A builder whose crew is small takes longer.
- **Homes:** apartments 0.85 of the block, a tower 1.15 (the user's figures, 9.8). The street, pipe, cable and land
  come on top (9.8), and so does a plant's connection (12.1, 5).
- **No building:** the five home-world builders (plan section 3); a truck driver, whose bill is the truck, ordered from
  a maker (12.4, 32).
- **Roads** are billed from Terra's road plan per link, not from this table.
- **The builder row:** per full unit, 60 workers (36 general, 18 skilled, 6 specialist) making 60 BW a month. It has no
  stocked inputs: the job's materials are the client's.
- **Upkeep** (12.9, 58): every row also has an upkeep column, set in testing. The proposal: about 1/400 of its MATERIAL
  bill a month, bought by the plant itself, plus 2% of its BW a year as a small job for a builder.

## 4. Step 3: the plainest form

Step 3 runs the first loop on one place, paid from savings, grants and the purse. The bank does not lend, goods need no
trucks, and nothing grows or closes idle plants (plan section 13). What follows is all that step 3 builds of building.

### 4.1 Month one

- **The five builders** arrive from the home world operating, with their crews and equipment, and need no yard
  (plan section 3). The proposal for their sizes is one large, two average and two small: three full units, 180 crew.
  Their crews are settlers, in the household pools like everyone else (a job is recorded once, 9.2), already employed
  by their builder on day one. Their money is set with the other starting numbers (12.1, 8). **(Otto: sizes and
  crews; Maja needs the 180 for the founding population)**
- **The public works department** (12.11, 99) is not one of the five. It exists from month one among the government's
  subsidiaries (9.12; step 2). In step 3 it is idle, because nobody commissions it yet. Its commissions come with the
  government's purse. (Bob's review)
- **The landing stock** is the colony's, and the government sells from it at the starting prices (12.2, 9). In step 3
  the purse posts it on the market as an ordinary offer at those prices. The government is not a company, so its offer
  is not moved by the price rules; changing it is a lever, from step 8. **(Otto)**
- **Trucks.** Step 3 needs none (no freight until step 4). Whether "five years worth of equipment" holds trucks a
  truck driver can buy is the user's to say; until then a truck-driver plan in step 3 orders its truck from the home
  world with a ship (12.11). **(Otto: open for the user)** The home world's truck price is in Bob's table (12.11, 105).
- **No plant stands.** The first contracts are plans' contracts.

### 4.2 A plan is made

1. **Rule 7** (12.3, 15a) finds that a type's share of the area's work covers what a company of some size costs to
   run. The person who would found it is picked from the households as Maja's household side says. They are taken out
   of their pool and counted individually from this day (12.9, 60a).
2. **The money the founder needs** is reached when the founder's own money plus the grant covers:
   - the land at its price (12.1, 3);
   - the estimate of the building (4.3 below);
   - three months of the new company's running costs, its opening money. **(Otto)** Without it a company opens with
     nothing and its first payroll lays everyone off (12.3, 19a). This is the founder's sum for deciding, not a limit
     on anyone: a founder may plan without it if they choose, and may fail. It does narrow 15a: fewer founders reach
     any size. Bob runs section 13's month-one check both with and without it.

   The founder plans the largest size that passes rule 7 and that their money reaches (15a). If no size is reached,
   no plan is made.
   When several possible founders read the same signal in one month, they are taken in a fixed order (by pool id),
   so a run repeats. Each one reads the signal as it stands; plans are not counted in rule 7's shares (13, watch item
   8). **(Otto, as Bob proposed)**
3. **The site** is the best-scoring free place for its type in the area, by the siting code (12.1, 5). In step 3 the
   area is the landfall place.
4. The plan opens its own account, and the founder moves the money in. Nothing is paid out yet.

### 4.3 The estimate and the quotes

- **The estimate** is the bill at today's prices: BW × the average price per BW of the live builders, plus MATERIAL and
  COMPONENT at the market price. It is pure, and is also what the government's desk shows before any quote exists
  (plan section 10).
- **A quote** from a builder is its price per BW × the bill's BW, the materials at their market price, and a start
  month. Only the BW part is fixed at signing, apart from its wage part (4.7). The material part is an estimate: the
  client pays what the material really costs when it is delivered.
- **The start month** comes from the builder's book: the jobs before it in signing order, worked at the builder's
  present crew, with material assumed to be there. It is the first month in which this job would get crews.
- **Every live builder quotes.** The plan takes the quote with the earliest start; between equal starts, the lowest
  price (the user, plan 12.3 15d, verbatim: "He should look for the shortest time"). This replaces "the lowest total;
  with two equal, the earlier start", written before the ruling.

### 4.4 Signing

**The user's rulings on claiming (verbatim):**
- 2026-11-15: "What you just said about builders and no jobs show another fault, job cues, but firms cue work up we do this in three months, that's why businesses need to be plans,  also they compeete for jobs,  both have the job listed whoever gets their first wins,  competitiv buisness here but also patience they want fall for not fining jobs when 350 jobs just got canncled form not fining builders"
- 2026-11-18: "Builders did not claim infinitely in the build we talked about"
- 2026-11-18 (12.3, 15c): "Should not raise from climed jobs is right open jobs in the market hoping to be claimed I'd what counts and i don't know why you only recorded half of that"
- 2026-11-18: "A plan can be listed for a year before cancled and they only claim a year or too forwards"
- 2026-11-18: "The or two should be up to the manager"

So: a plan is listed in the market for up to twelve months; unclaimed after that it is cancelled, as any plan given
up. A builder claims a job only if it can start it within its reach, between one year and two; where in that range is
its manager's choice. (Wilma's earlier reading of three months, and her "up to two years", are struck by these words.)
**(Otto's reading, with Wilma's yes, 2026-11-18)** The manager is the company's chief (plan 12.11, 77: "a chief with a
management skill and an appetite for risk"). A builder's reach is its chief's appetite for risk: 12 months at risk 0
to 24 at risk 100 (12 + 12 × risk / 100, rounded down), since claiming work far ahead is a risk taken on. The five
landing builders' chiefs are drawn once from the world's seeded random when they land and kept; any other company's
chief stays at the record's 50 until section 77 is built. A plan no builder can claim within its reach stays listed
for every builder, and the first that can start it wins (15d: the soonest start, then the lowest price); while it is
listed its bill's BW counts every month as open work, which raises the builders' price (one 5% step at most a month)
and their crews, shared in equal parts among the builders for hire that quoted it (those with crews; a builder with
no crew could not have claimed it: Terra's review). Listed twelve months from the month it was
made and still unclaimed, it is given up like any plan (4.9): the site released, the money back to the founder, the
grant owed back, the founder back in their pool.

These replace "the job goes to the end of the builder's book" below and the endless wait behind a book (4.9): a builder
claims a job only within how far it queues work; an unclaimed job stays open in the market for every builder, and the
first that can take it wins; the plan waits, patient, and is not given up for finding no builder.

- **Before signing** the plan reads rule 7 again. If the signal no longer passes, its owner gives it up: nothing has
  been spent, so there is nothing to settle. The money in the plan's account goes back to the founder, and the
  founder goes back into the pool of their block (12.9, 60c). **(Otto)** After signing it is never given up for its
  signal.
- **A client may refuse a quote and wait** (12.9, 56). A plan refuses when the lowest quote is more than its account
  holds. It asks again next month.
- **At signing:**
  - the plan buys its land from the owner (the purse at landing) at the land price;
  - the grant, where the type has one, is paid into the plan's account by the purse (12.9, 61: one grant per
    household);
  - the contract is written, with `price_bw` and `wage_bw` fixed at this month's figures;
  - the job goes to the end of the builder's book.

### 4.5 Supplies: "3 months up front and add 1 month every month"

- **A month of supplies** for a job is the bill's MATERIAL and COMPONENT × (the BW the builder plans for it in a
  month / the bill's BW). The BW planned a month is the bill's BW / its fewest months, or the crew the builder can put
  on it, whichever is less.
- **Before work starts** the site must hold three months of supplies, or the whole remainder of the bill if that is
  less. "Up front" means at the site (12.4, 31).
- **Every month of work** the builder orders one more month, so the site stays three months ahead until the bill is
  covered.
- **The supplies order is the client's, placed by the builder on its behalf.** It carries the client's account and
  the client's worth: the most it will pay, which is the material price in its estimate. So it is a real order with
  money behind it, and the sellers' price rules read it (12.3, 23a). The builder only schedules it: what, how much and
  when. The client pays for each delivery on the month it arrives, and the material on the site is the client's. That
  is why section 13's check counts "the three months of material up front" in what a settler's savings and a grant
  must cover. A builder does not need money for its clients' materials. **(Otto, as Bob proposed)**
- **A short good** is shared among the buyers who offer the same price, in proportion (12.3, 27). A site that holds
  less than a month's supplies works only as far as what it holds allows.
- **Waiting for material is not a price signal** (12.3, 19). Crews that have a job but no material are neither empty
  slots nor idle time for rules 2, 4 and 6. They still cost their wages (19b).

### 4.6 Working the book

- **Each month a builder's crews go to its jobs in signing order** (12.9, 57). A job takes up to its planned BW a
  month. The rest go to the next job.
- **A job that cannot work this month** (it waits for material, or is stopped unpaid) keeps its place in the book,
  and the crews go on to the next job that can work. **(Otto)** Otherwise one short site would idle a builder whose
  other sites have their material.
- **BW done uses material in proportion:** a month that does x% of the bill's BW builds in x% of the bill's MATERIAL
  and COMPONENT from what is on site.
- **The builder's price rules** (plan section 6) read:
  - for a rise, the BW its signed clients wanted done this month that it had no crews for, and the quotes refused for
    their wait. Both are work ordered at its price that it could not supply because it was sold out (12.3, 15). A wait
    is a price signal, not a cause outside price;
  - for a cut, its empty crews (without crews waiting for material) and the quotes refused for their price (12.3, 23a).
- **Its output rules** are its hiring. Rule 3: crews short of the work due → hire. Rule 4: empty crews → let go.
- **Its making price** is its monthly costs (wages, upkeep, its own interest) / its BW at full output. Clients'
  materials are not in it.

### 4.7 Paying

Each month the client owes:

- the BW done × (`price_bw` + this month's wages per BW − `wage_bw`), so the builder's own work is fixed at signing and
  only its wage part follows what wages cost (12.9, 56);
- the supplies delivered this month, at what the builder paid.

The client pays from its account. **A month unpaid adds to `unpaid_m`. After three unpaid months the builder stops**
(12.9, 56). The job keeps its place in the book and the crews go elsewhere. It resumes when the client pays what it
owes.

A plan whose account cannot pay is short. Its owner puts more in or gives the plan up (4.9). A rise of wages or
material during the build is a cost that falls on the client, and a plan may not be able to pay it (plan section 13,
watch-item 6). That is a result, not a fault.

### 4.8 The plant opens

When BW done reaches the bill and its supplies are built in:

- the contract is DONE;
- **the plan becomes a company** on the first day of the next month. Its record has the plan's type, size and owner
  (the founder) and one plant at the site, at condition 100;
- whatever the plan's account holds moves to the company's account;
- the building goes on the company's books as an asset at what it cost: land, building work and supplies. The buy-out
  worth (5.1) and the bank's lending from step 5 read that, less wear;
- the company hires (step 3's hiring) and starts by the nine rules.

The plan's record stays as GIVEN_UP or OPEN for the history.

### 4.9 A plan given up

"It ends only if its owner gives it up (no builder, no money)", settled as 12.9, 60b says:

- the builder keeps what it was paid for work done;
- the land and the half-built building are the founder's, and can be sold. The contract becomes ABANDONED, and another
  plan of the same type may take it over by paying the founder (12.11: a contract that changes client);
- the grant is owed back to the purse;
- what the founder cannot pay goes to court like any debt (in step 5; until then it is recorded as owed);
- it is not counted as a failed company.

An owner gives a plan up only when no builder is alive, or the plan's account cannot pay a bill. A long wait in a
builder's book is not a reason: the plan waits.

### 4.10 Checks that every step-3 test and game makes

- **Money:** what plans and companies paid for building = what builders and sellers of land and material received.
  Land paid to the purse = land money the purse received.
- **Goods:** material and components sold to sites = on site + built in. No site uses what was not delivered.
- **Work:** BW done in a month ≤ the builder's crews' BW that month.
- **People:** a builder's crew are people of the pools, each in one job.
- **Plans:** none is counted as a company; none has staff; none pays anything but land, building and its supplies.

The short exact tests, each to the last credit and unit:

- one plan made, quoted, signed, supplied three months up front, worked, paid and opened;
- one builder with two jobs, the first waiting for material: the crews work the second;
- one plan that cannot pay: stopped after three months, given up, settled.

### 4.11 To watch for and report, not to prevent (Bob's review)

- **Stocking up from the landing stock.** The landing stock is offered at fixed starting prices. For any buyer whose
  worth is above the starting price, that is "low" every month (9.3), so one plan or company may buy years of it in
  month one. That is a result. It is why the size of the landing stock (Bob's table) matters.
- **The landing stock caps prices.** While it lasts, no colony maker of the same good can sell above the starting
  price (12.2, 9), so for up to five years the colony's own material makers face that ceiling.
- **What step 3 can build at all** (Bob's type table, 9.3). Without the bank, only family-size plans of the richer
  household bands (I3 to I5, with the grant) reach any building. Nobody can pay for a mine, a processing works, a
  components works or a landlord's block. So in step 3 material and components come only from the landing stock, and
  the settlers live in the landing shelters. That holds until the bank lends (step 5) or the government builds the
  works itself (step 8). It is a step-3 result, not a number to change.
- **Builders hire.** Rules 3 and 4 act on a builder's crew from step 3, and nothing limits the speed of hiring
  (12.3, 28). The five builders' 180 crew is month one's figure, not a ceiling. Once crews grow, the landing material
  and the plans' money are the limits.
- **A quote's material part moves.** The client pays what the material costs on delivery, not what was quoted
  (4.3; 13, watch item 6).

## 5. What step 6 adds

### 5.1 Rule 5: growing by size, buy-out or a new plant

In section 5's order (12.3, 17):

1. **A size up in its own square,** when the square has room for the type (one full size per type, plan section 5).
   - A SIZE_UP contract's bill is the difference between the two sizes' shares of the full bill. Family to small is
     1/6 of the full bill.
   - The plant keeps running while it is built (12.9, 59). On DONE it has the new size and hires for it.
2. **A buy-out,** when others of the same type fill the square.
   - The buyer offers for the other company's plant. The plant can refuse an offer below what its land, building and
     stock are worth (12.10, 67). The building's worth is its bill at today's prices × condition / 100. **(Otto)**
   - Competition law applies. Debts go with the plant (53).
   - A buyer of the same type keeps the building; a buyer of another type rebuilds it at its own type's full bill,
     with nothing of the old one recovered (12.1, 6). **(Otto: no salvage)**
   - After it, the size up follows as in 1.
3. **A new plant in another square,** by a NEW_PLANT contract with the company itself as client. It pays from its own
   money and, from step 5, its loans.

Money is the limit ("money is a limitor"). A company that cannot pay for the next step does not take it.

### 5.2 Rule 6: a plant idle for twelve months

A plant idle for twelve months for price's sake (12.3, 16 and 19) is closed and kept (mothballed, 12.11, 79): no staff,
a small upkeep, and it wears. Its owner may sell it, or reopen it by hiring again.

### 5.3 Wear and repair

- **Condition** runs from 100 down to 0. With upkeep paid (section 3's upkeep column) it holds. Without it, it falls
  by a set amount a month **(Otto: the amount is set in testing; the proposal is 1 a month)**.
- **Below 50**, output falls in proportion to condition / 50, and accidents rise (plan section 7). **(Otto: 50 is the
  proposal for plants; homes keep the user's 55 of 9.8)**
- **Upkeep's builder part** is a small yearly job in a builder's book, signed and paid like any other.
- **A repair or renovation** is a REPAIR contract back to 100. Its bill is (100 − condition) / 100 × half the full
  bill. **(Otto)**
- **Cutting corners** (12.11, 84) means skipping upkeep: the money is saved now and the condition falls.
- **An unsafe plant** (80) is closed under the law until it is repaired.
- **Upgrades** (78) are an UPGRADE contract to a better grade of the same size, chosen when it pays.

### 5.4 Land sales

- **Land** is the colony's at landing (12.1, 3). The purse sells it to whoever builds on it, at the land price.
- **Every later sale** is between owners: land with its building, at a price the two agree. The seller can refuse
  below the worth in 5.1.
- **A given-up plan's land and half-built building** (4.9), and **an ended company's land and building** (12.1, 6: it
  stands and wears), are sold the same way. The buyer is another company, the workers as a co-op, or the government
  (12.11, 81).

### 5.5 Also at step 6

- **Permits and licences** (12.10, 66): a plan applies when it is made. The contract can be signed when the licence
  is granted, or earlier if the founder goes ahead unlicensed and risks the fine.
- **How the state picks a builder** (12.11, 98): by price, record and start, weighed by a lever. A builder's record
  is the share of its jobs finished by the quoted start plus the fewest months.
- **The other contract kinds:**
  - roads (Terra's plan), from the step that brings road works;
  - homes, landlords' blocks and own houses, at step 7 (9.8);
  - office buildings, at step 9.
  Each is the same contract with its own kind.

## 6. For other sessions

- **Bob** (agreed in his review):
  - the bills, months and upkeep column of section 3, held in his type table;
  - a builder's price per BW with materials on top;
  - the supplies order as the client's;
  - the landing stock as a fixed offer from the purse;
  - the home world's truck price.
- **Maja:**
  - the 180 builder crew among the founding settlers;
  - who in a pool becomes a founder, and how much of the pool's savings goes with them (4.2).
- **Terra:**
  - siting for a plan's site;
  - the land price per cell or tile;
  - road links billed per link (section 3).
- **Wilma:**
  - whether the landing stock holds trucks (4.1);
  - the three months of opening money a founder counts (4.2), which the user may strike.
