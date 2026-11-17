# The rebuild of the economy: one company object

**Version 8, unified, 2026-11-17. Wilma.** This replaces drafts 1 to 7. It is one document: every ruling the user gave
for the rebuild is in it, in its place. Nothing is built.

How to read it:

- Text in quote marks or in a quote block is the user's own words, unchanged.
- **(proposal)** marks something Wilma filled in. It is not decided.
- **(open)** marks something nobody has decided. Section 14 collects them.
- Everything else is the user's ruling put into plain rules, or a fact of the code.

Where things are: the game as it was before the cut is `game_full_copy/` and commit 785c72f. In `game/` the economy is
removed and every call into it is left open; they are listed in [economy-connections.md](economy-connections.md). The
six sessions' first reviews and Terra's opinion on homes are in [rebuild-reviews.md](rebuild-reviews.md). The rulings
are also kept, by date, in [MASTER-PLAN.md](MASTER-PLAN.md).

---

## 1. The order

> Now you build it from the ground up one object that is the company it's size family to large 4 sizes, the nine rules plugged into that the offices as a bonus building the work they do behind states if needed otherwise it's just a 2d array of wich items a company type makes,  if they pick from first or second output all in one object, then roads and supply networks since the same company can become freight that's done already, polution plugg ins to the same okay? Food output plus into the same no more godawfull single sided junk services have no output but a client take in,  stress for workers reduced output based on workers all of it into the company okay? No more only this sector shit, they start with their own and ship out build a plan with all of it adjust the plan until you see every component in the relationships we have them in anything outside needing something how it gets it,  then you ask all the others to review from their and you rewiering FUCKING STOP

How the work is done (rulings of the same day):

- "building fixes behind off switches is not a valid way to do large scale fixes". Each part is built on the parts
  before it, with them on, and tested there. A part that works stays on. Nothing is merged switched off.
- "You will swich the fixes on one at the time until all are one run the tests for each and report where the bottle
  neck is at that time". The same holds for the rebuild's steps.
- "Same company types can come but not their code or balancing". The old type names are the starting list. No old rule
  code is copied and every number is set again. The one exception is the household side (section 9.1).
- "set a credit prices we are going to have to adjust it anyway i don't have a sheet of what costs what so i can't tell
  you what it should cost". Every price and quantity is ours to set and is adjusted in testing.

Why: the old economy had 72 files and about 31,000 lines. Each sector had its own copy of the rules. Fixes were tested
one at a time against a game that did not contain the others, and merged switched off. The first time all ran together
(v12) the colony was a third of v11's size, and the very first fix alone already broke the builders.

## 2. The whole picture

There is ONE kind of thing that produces: **the company**. A farm, a mine, a bakery, a builder, a haulier, a clinic, a
service hub, a landlord and a power plant are the same object with a different row of one table.

Around it are the things that are NOT a company. Each meets a company in a stated way and no other:

| Outside thing | It meets a company as |
|---|---|
| Households | its staff, its customers, its clients, its tenants, and the owners of family companies |
| The labour market | where it hires; a salary is a price |
| The market | where it posts offers and orders |
| The bank | its lender, and the keeper of its account |
| The government's purse | its tax collector, its owner (state companies), its client (commissions), its grant giver |
| Ships and the port | the only way its goods leave the colony or goods arrive |
| The building contract | the deal between a client and a builder company |
| Unions | an organisation of staff across companies that can stop its work |
| The law | its licences, the limits on what it may do, the court |
| The map | where its plants stand and what its trucks drive on |

## 3. The company object

One record per company. Everything below is a field of that record or a function that takes it.

| Field | What it is |
|---|---|
| `id`, `name`, `type` | `type` is a row of the type table (section 4) |
| `size` | family, small, average or large (section 5) |
| `owner` | a register of who holds it: a family, private owners, a co-op, the state, a party, a union, the home world |
| `plants` | the places it works at. Each has: where it stands (a 3 km tile in the country, a cell on a town grid), its form, its condition (0 to 100), whether it is closed, and how much of the type row it runs |
| `staff` | the actual people it employs, by skill tier and by the plant they work at, with their stress. Not head counts: the same people the households know (section 9.2) |
| `salary` | what it pays, per skill tier and per district of the hiring plant (section 9.2) |
| `stock` | what it holds of each item, at what cost, and what of it is waiting for freight |
| `money` | its account, its loans, its books by month and by year |
| `price` | ONE price per company for each thing it sells: "No i said each COMPANY". A type may have its own way of pricing (section 4) |
| `orders` | the orders it received, filled and unfilled, and for each unfilled one WHY (price, freight, road, the buyer's money) |
| `work slots` | for a type with nothing to stock: its client places, crews, homes or bays, taken and empty |
| `office` | the place it rents in an office building, or none |
| `fleet` | its trucks, each with a quality and its wear |
| `emissions`, `noise` | what its plants put out |
| `signals` | the nine rules' inputs, worked out once a month from the fields above |

A company's own state lives here and nowhere else. Other things keep their OWN records about a company, keyed by its
id: the law keeps licences, violations and court cases; the bank keeps the loan; a union keeps its members. They do not
keep copies of the company's fields.

A company does not exist before its plant opens. Before that it is a plan (section 8.1), which is not a company.

## 4. The type table: one 2D array

"it's just a 2d array of wich items a company type makes, if they pick from first or second output".

Rows are company types. Columns say, for ONE full-size unit per month:

| Column | Meaning |
|---|---|
| inputs | items it takes in (energy, water, mineral, material, component, food, consumer goods, medical) |
| first output | the item it makes by default |
| second output | another item the same plant can make instead; it picks by which pays (rule 3) |
| client intake | for a service: how many clients it serves. "services have no output but a client take in" |
| labour | workers by skill tier, and the occupation they count as |
| pollution, noise, accident risk, hazard | per unit |
| build bill | building work, material, components and months to build it |
| freight room | what one truck of it carries, for a type that carries |
| its way | how this type does the things that differ by type (below) |

**"things can be done in two different ways based in company types how its this a problem?"** The column "its way"
says, per type:

| What differs | The ordinary way | Another way, and who has it |
|---|---|---|
| What it sells | an item from stock | client places (services); building work (builders); homes (landlords); bay work on a truck (truck workshops) |
| What rules 2 and 4 read | unsold stock | "They have empty work slots": client places not taken, crews without a job, homes without a tenant, empty bays |
| Its price | one price per item | a tax bracket (a state service); a price per unit of building work with materials on top (a builder) **(proposal: the builder reading)**; a rent that follows each home's place and condition (a landlord, section 9.8) |
| How it reaches the buyer | by truck over the roads | through a grid (power and water) **(open, section 14)** |

Rulings the table carries:

- **First or second output.** A components works can build trucks as special orders, always at the lowest quality; a
  truck workshop builds them better. So the components row has a second output, trucks.
- **A service** (service hub, clinic, school, childcare, eldercare, police station, administration, truck workshop)
  serves N clients per unit. What a client pays, or the tax bracket for a public service ("per pupil plus staff is how
  taxes for schools are calibrated"), is its income. There is no "services" item on a market.
- **Food is an item like any other,** and a food producer is a company like any other.
- **Noise:** "things like noise polution should also drive down price of housing so we don't have factories all in among
  the houses, or rather less."
- The old table had 34 type names. They are the starting list. Types that only existed to hold staff (office, party
  headquarters, newsroom, business services, shops, comfort services) are gone through one by one: each either sells
  something or serves clients, or it goes. **(proposal)**

## 5. Sizes, squares and growing

> Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size the output for each is the same but with a small penalty for their smaller size

| Size | Share of the full-size row | Penalty on output |
|---|---|---|
| family | 1/6 | 6% less |
| small | 1/3 | 4% less |
| average | 2/3 | 2% less |
| large | full size | none |

The penalty figures are Wilma's, accepted: "You penalty is fine". A family company is run by one household.

**Squares.** A square holds one full size of company: one large, or three small, or six family.

- For plants in the country a square is the 3 km map tile.
- In a town it is the 400 m street block of the town grid (16 cells, about 128 houses). (Terra's proposal, accepted:
  "This sounds good".)

**Growing** (rule 5): "Depends on region, in a square if there are other companies they would have to buy out the other
company to make it larger, three small in a square of they can't buy out or it's too expenvice build a new".

1. Alone in its square, a company grows one size at a time.
2. If others share the square, it has to buy them out to grow there.
3. If it cannot, or that is too expensive, it builds a new plant in another square.

## 6. The nine rules

One implementation, called for every company every month. Each reads the company's own `signals` and the market. No
type has its own copy, and no rule is skipped for a type because it cannot take effect today.

| # | Rule | What it acts on |
|---|---|---|
| 1 | raise the price | it sold what it offered and orders went unfilled |
| 2 | lower the price | what it offered and did not sell: "the more inventory you have, the more you reduce your price" |
| 3 | raise output | "if you sell out all your producing produce MORE". Also picks first or second output |
| 4 | lower output | output that did not sell |
| 5 | add capacity | "if your selling out and all plants at max build a new one ... money is a limitor". How: section 5 |
| 6 | cut capacity | a plant that stands idle for a set time. "A hard rule here is fine". **(proposal: the time)** |
| 7 | start a company | the average of all available work: "instead of reading the leftovers, they read an avrage of all avaliable jobs". No cap on how many may form |
| 8 | do not start one | the same signal says the work is covered |
| 9 | which price rule goes first | "if below making price climbing allways had priority if above lowering has priority if both signals come in the same month only the one with priority happens, and if your going to cap it at 5% THEN DO THE SAME FOR BOTH" |

What goes with them:

- **Only price moves price.** "If something else than price stops sales it should not count on adjusting price!!" A
  sale stopped by freight, the road or the buyer's money counts neither as unsold stock (rules 2 and 4) nor as an
  unfilled order (rule 1). "Ignore the stoch in that other place too".
- **Held-back stock is nobody's signal.** A seller below its making price offers what covers its monthly expenses and
  holds the rest: "It sells too cover all monthly expences". Stock it did not offer does not lower its price.
- **Rule 9 only decides a tie.** When both signals come in the same month, the one with priority acts. One signal alone
  acts, whichever side of the making price the company is on. If there is a cap on a month's change it is the same up
  and down; 5% was the old code's figure, not the user's. **(open: whether there is a cap, and its size)**
- **No hard floors or ceilings** of our own, except where the user allowed one (rule 6).
- **No limit built on last month or last year.** Credit follows orders, contracts and forecasts, so a company can grow.
- **For types with nothing to stock,** rules 2 and 4 read empty work slots (section 4).
- **The same three price rules set salaries** (section 9.2).

## 7. What is plugged into the company

Each of these is a function over the company record, the same for every type.

| Part | The rule |
|---|---|
| **Office** | A bonus, not a condition. "I think the offices should not be esencial, if you done have one you lose out on some not all lets say something like 15% less, but also offices should not be owned by the company unless they have a huge company one office building should be able to hold 10 plants extra workers". An office building is a real building, put up by builders, owned by a "Private landlord" (itself a company whose clients are its tenants). It holds the office workers of ten plants. Only a huge company owns its own (huge = its office workers fill a whole building; that is not the same as size large). An office never hires ahead of anyone. |
| **Freight** | "the same company can become freight". Any company with trucks can carry, its own goods or others'. A haulier is a company whose row has freight room and nothing else. |
| **The freight queue** | What cannot be carried waits in a real queue and goes first the following month: "count the work que not passed work"; on the queue: "That works". A carrier sets its crew and trucks on that queue. Goods waiting for freight are not unsold stock. |
| **Trucks** | A truck's quality is set when it is built and stays. Trucks wear. "if you're truck breaks down you can fix it yourself in about 4 months or drive to a workship and have it fixed now". A workshop repair "Uses components and resets wear, about 5% are lost reach time". Trucks from a components works are always the lowest quality; a workshop's quality follows its workers' stress. |
| **Roads** | Terra's road network. A company ships from where its plant stands to where the buyer is. |
| **Pollution and noise** | The row's pollution and noise for what is running. The planet reads pollution by area; noise lowers the value of the homes near the plant (section 9.8). |
| **Stress** | "stress for workers reduced output based on workers". It comes from the hours and from how many are doing the work. It is also what a union reads (section 9.9). |
| **Wear and repair** | Every plant has a condition from 0 to 100. Upkeep holds it; without upkeep it falls. A worn plant produces less and has more accidents. Repair and renovation are jobs for a builder company. |

## 8. The life of a company

### 8.1 Before it exists: the plan

"PLANS ARE MADE BEFORE THEY BECOME COMPANIES DAMNED IT ALL THAT'S BEFORE ACCEPTING A GRANT". "you can't fail before you
exist ... no worker but also no expenses beyond building".

- A plan is not a company. It has no staff and no expenses beyond the building. It cannot fail, and it is counted
  neither as founded nor as dead.
- It is made when rule 7 says there is work. It gets a quote from a builder, with a start date, and signs.
- A grant, where one exists for the type, is accepted after the plan is made.
- It becomes a company on the day its plant opens.
- It ends only if its owner gives it up (no builder, no money).

### 8.2 Open: it runs, grows and shrinks

By the nine rules (section 6) and by section 5.

### 8.3 How it ends

> End of a company can happen in three ways,  each with its own survival clause, first sales death, if even with the company hording and just trying to stay afloat it cant turn the price in two years its going to sell of its stock and shuts down,  it's plants shut down and it cant affort too replace them and finally someone buys them out, the last one has to do with land and if they get enough they can buy another building and continue there

| # | How it ends | How it survives |
|---|---|---|
| 1 | **Sales death.** Even holding stock back and only trying to stay afloat, it cannot turn its price in two years. It sells off its stock and shuts down. | It turns the price within the two years. |
| 2 | **Its plants shut down** and it cannot afford to replace them. | It can afford to replace them. |
| 3 | **Someone buys it out.** This one has to do with land. | If it gets enough for it, it buys another building and continues there. |

**(proposal, Wilma's readings:)** "turn the price" means getting its price back above its making price. A buy-out is
the same event as growing in a shared square: the buyer wants the place.

What follows an ending: "Yes they are laied of its loans are payed in full if they can when selling their stock, if not
the owner is taking to court, where the bank can either settle for a smaller amount or demand payment over time, if he
is rich or owns other companies a settlent might be reached".

- The staff are laid off.
- The loans are paid in full if selling the stock brings in enough.
- If not, the owner is taken to court. The bank either settles for less or demands payment over time. A rich owner, or
  one with other companies, may reach a settlement.

A fourth way that is the law's own, not yet ruled: the court winding a company up after repeated convictions **(open)**.

## 9. The things outside the company

### 9.1 Households

"Okay i think we can take it wholesale as long as we make sure it fits in". The household side of the old game is taken
as a whole and fitted in. It is the one exception to "no old code". It stands in `game_full_copy/` (econ_households,
econ_pop, econ_cohorts, econ_informal). What it holds:

- **Pools, not single families:** one pool per housing block and income band, with one account. Each pool knows its
  workers and jobless, adults outside the labour force, retired, children, owners, the self-employed, and their skills.
- **Money in:** wages, the unemployment benefit, pensions, dividends to owners, the earnings of the self-employed, the
  savings migrants bring.
- **Money out, in this order:** rent and utility bills; food and the other essentials; then what is left, split between
  consumer goods, services, comfort spending, newspapers and saving. Orders are placed a month ahead; a household that
  cannot afford everything buys less of each.
- **Life:** ages 0 to 99 per area; births from women 18 to 42, fewer with income, schooling, density and crowding, and
  when food is short; deaths by age, worse with poor clinic access and in famine; growing up at 18 with a skill tier
  set by schooling; retirement at the legal age; adults outside the labour force returning to it.
- **No home:** beyond 130% occupancy nobody else squeezes in; those left build shacks or are homeless, with more deaths,
  fewer births and fires.
- **Arriving and leaving:** settlers on each ship, more when the colony is attractive; jobless young adults and
  homeless families leave on it.

"Fits in" means a household meets a company only as section 2 says. Where the old code reached into a sector's rules,
that reach is cut and replaced by the company record.

"Housholds follow terras latest plan": where a household lives, what its home is worth and what it wants near it follow
Terra's town grid (section 9.8).

### 9.2 Workers, skills and salaries

> Workers and sallery, skills and swapping jobs to better payed,  actually the three rules for price should be applied here too

- Workers have skills. A post asks for a skill tier.
- A job is recorded once: the people in a company's `staff` are the same people the household pools hold.
- Workers change jobs to better-paid ones.
- **A salary is a price.** Price rules 1, 2 and 9 set it.

| Rule | For a salary **(proposal: these two signal lines)** |
|---|---|
| 1 raise | its posts stay open, or its workers leave for better pay |
| 2 lower | more people apply at its salary than it has posts |
| 9 which goes first | the line is the starting salary below |

- **The starting salary:** "Sallery should be calculated as avrage living in the area and food plus half of both again,
  that's the start then it should regulate itself". So 1.5 x (average housing cost in the area + food). "On sallery it's
  an avrage of the area."
- **Hiring** is at that line; rule 9 for a salary turns on it ("that's fine for hiring").
- **A company with plants in two districts:** "The district the plant hiring is in."
- **The yearly bonus:** "every year a company can grant a bonus what the minimum of this is is up to the government, 2%
  is a good start". The minimum is a government lever, starting at 2%.
- **Who applies:** "But emplyees only apply to jobs that meet their needs" (the user, answering Bob's finding that
  salaries could fall without end). A worker applies only to a job whose salary meets their needs. So a salary below
  what people there need to live gets no applicants, the lowering rule has nothing to act on, and the raising rule
  (posts stay open) takes over. That is what stops the fall; no floor of ours is needed. **(proposal: "their needs" is
  their housing and food where they live, the same two things the starting salary is built from.)**
- Only pay moves a salary. A post that stays open because there is no housing nearby, or nobody in the colony has the
  skill, is not a reason to raise it. **(proposal: Wilma's carrying over of the price ruling to salaries.)**

### 9.3 The market

One order book per item. Companies and households post orders; companies post offers. The cheapest delivered offer
fills first. What a service sells is not on the market; its clients come to it (section 4).

### 9.4 The bank and owners' money

- One bank. It lends on orders, contracts and forecasts, never on a limit from last month or last year.
- It holds the accounts of households and companies.
- When a company ends owing money: section 8.3.
- Owners put money in to start a company and take profit out. **(open: how much, when)**

### 9.5 The government's purse

- **State companies.** "the goverment starts with its subsidiaries as before". "All company types needs to be able to be
  created as private, but maybe they're is only ever enough work for say one powerplant then the conitions for new ones
  don't get switched on". A state company is a company; rules 7 and 8 decide whether a private one appears beside it.
- **Tax brackets** pay the public services: "per pulpe plus staff is how taxes for schools are calibrated Yea they all
  get tax brackets". The bracket is that service's price.
- **Grants** only where ruled: family farms, family bakeries, truck drivers, truck workshops. "I DID NOT SAY GIVE
  EVERYONE ... GRANTS". Truck drivers and truck workshops are separate grant types ("No split trucks and workshops").
- **Commissioning:** the state orders a building, a road or a repair from builder companies like any client.
- **Leaning on:** "the goverment can lean on companies if they don't comply or on the union".
- **Levers** it sets include the yearly-bonus minimum.
- Taxes on companies and sales, the budget lines and what each has left, and the reserve of food and material the
  government can release: **(open, section 14)**.

### 9.6 Ships and the port

"They can't order when there's not a ship there to take the order. ... they have to ask for one when the ship is there,
which means they have the full period of waiting every time."

- Nothing enters or leaves the colony except on a ship in port. No order, request, payment or answer travels otherwise.
- An order placed with a ship in port comes back with that same ship on its next call: the full round trip, every time.
- **Imports are a backstop:** a good is ordered in only while no plant in the colony makes it.
- A company's exports are stock it puts on a ship in port.
- The ship schedule, the fleet, the hold, the port's stock and the home world's prices and quota belong to the port and
  the home world, not to any company. **(open: their design)**

### 9.7 Builders and the building contract

- A builder is a company. Month one has "5 building companies and alot of oppretunity".
- "They should not need 90% of supplies up front they should need 3 months up front and add 1 month of additional
  supplies every month".
- A builder keeps an order book and quotes a start date. A plan knows the wait before it signs.
- A building contract is between a client (a plan, a company, a household, the state) and a builder. It is neither
  party's field: it is its own record, with the work done and to do, the materials used, the agreed price, what has
  been paid, and the builder. **(proposal: that it is its own record. Its terms are open, section 14.)**
- What is built by contract: a new plant, a size up, a road, a repair or renovation, a block of homes, an office
  building, a household's own house.

### 9.8 Homes, landlords and the map

A landlord is a company. Its clients are its tenant households; its empty homes are its empty work slots.

**Where homes stand** (Terra's town grid, accepted: "This sounds good"):

- The country is 3 km tiles. A town has a grid of 100 m cells. A house cell holds 8 plots; a street block is 400 m.
- "Below 250 start a gridd anyway and only use what you need". Every place has a grid from its first house.
- A block of 50 homes takes about 6 to 7 cells as houses, 1 cell as apartments, a quarter of a cell as a tower. Which
  forms a town may build is the government's choice.
- Every cell has a value, from the view, the shore, jobs, school, clinic, shops, roads and utilities, less fast roads,
  industry and noise. "the closer to the coast you get the more expensive they get; it can even shift from road to
  road."
- A built cell keeps its building. A sale or a buy-out never moves houses around the map.
- The town grid is part of the rebuild and is on.

**What a home costs to build:** the bill for its form (apartment 0.85 of a house, tower 1.15), plus the street, pipe
and cable to reach it, plus the land at its cell's value. Land for one home on an ordinary cell: 10% of the home's
building bill, scaled by the cell's value **(proposal: the 10%)**. Payback aims at 12 to 15 years of rent on an
ordinary cell.

**Rent of a home** = the landlord's own rent (moved by the rules, empty homes as the signal) x the cell's value / 1000
x a condition factor. The condition factor is 1 above condition 55 and falls with condition below it. Value and
condition stay separate.

**Wear:** homes also lose condition with age, slowly for 20 years and then fast, half as fast when well kept. Below 55
the owner renovates (a builder's job) or lets it slide, and "that's what changed rent levels for the landlord".

**Owning:** "I belive you should be able to buy your house out so you own it, and if an individual becomes richer than
the neibouhood he was able to build his own larger house we could use the 1/6 of a farm for that".

- A renting household can buy its home. The price is the rent it brings in at that place and condition, times the
  payback years. After that the owner pays the upkeep and no rent.
- Households are pools, so owned homes are a count per block, and "an individual richer than the neighbourhood" is the
  top band of a block moving out, a few households at a time ("That's fine").
- An own larger house is a builder's job the size of a family unit (1/6), on two or four joined plots, with its land
  at the cell's value.
- "If you own an appartment there is a fee for uppkep to the landlord that owns the rest of they all own then they are
  a community and they all pay together".

### 9.9 Unions

> Unions belong outside, a union is started from one company with bad working conditions but any other company staff from others can join, unions protest bad conditions,  and get a small fee from every person in it,  the union orders protests and shutdowns they last depending on hour long the union can pay the workers, the workers get 2/3 normal sallery during this time,  the goverment can lean on companies if they don't comply or on the union,

- A union is not a company and is not inside one.
- It starts at one company with bad working conditions. Staff of any other company can join.
- It takes a small fee from every member; that is its fund.
- It protests bad conditions, and orders protests and shutdowns.
- A shutdown lasts as long as the union can pay the workers 2/3 of their normal salary.
- The government can lean on a company that does not comply, or on the union.
- A company whose staff are out on a shutdown is not read by the rules as idle, unsold or short of applicants.
  **(proposal)**

### 9.10 The law

The law keeps its own records about a company: licences, permit applications, violations, court cases, fines. What the
plan has from the user: the court after a company ends owing money (section 8.3). The rest of the law's hold on a
company is **(open, section 14)**.

### 9.11 What the economy publishes

The rest of the game reads the economy by name: 105 indicators and levers, the facts the press and politics react to,
and the read-only views the screens show. The rebuild publishes the same names where the thing still exists.

### 9.12 Month one

> 5 building companies and alot of oppretunity and the goverment starts with its subsidiaries as before,  and all three grant types open, and no sectors beyond landfallpoint that's up to where things are built

- Five building companies.
- The government's subsidiaries as before: power and water, transit, the housing office, the public works department,
  and the public services (clinics, schools, administration).
- All grant types open.
- **No sectors beyond the landfall point.** The colony starts as one place where it landed. No districts are laid out
  in advance; where things are built decides. (The old game started with six named districts, and much code reads that
  list.)
- **(proposal)** No private companies are placed by us. They appear through rule 7 and the grants. So what the
  government's subsidiaries cover at the start has to be enough to eat and to have power.

## 10. The connections: anything outside needing something, and how it gets it

From [economy-connections.md](economy-connections.md): 367 open lines in 61 files of the game and its screens.

| Asked for (old name, calls) | Who asks | How it gets it |
|---|---|---|
| General helpers: sorting, splitting, the money scale, the treasury account (`EconUtil`, 196) | everyone | not economy. They move to the core |
| The state acts: order a building, a road, a repair; re-tender; upgrade a plant; give a grant; release the reserve; approve a tariff (`EconActions`, 44) | politics, the office, road law, the map | one action entry per act, each on the government's purse (9.5) and the building contract (9.7) |
| What a budget line has left (`headroom`, 11 of the above) | politics, the press, the desk | the government's purse, per line **(open)** |
| Questions: prices, shortages, why a plant or project is stopped, workload, labour, tenders (`EconQuery`, 32) | screens, politics, the press | read-only views over the company records, the market, the building contracts and the households |
| Unions (`Unions`, `UnionDisputes`, 28) | politics, the press, staff, the office | the union's own record (9.9). The old code looked a union up by occupation and asked for a federation **(open)** |
| Ships and trade (`EconTrade`, 19) | the home world, the office, screens | the port (9.6) |
| Households: persons, income, paying wages (`EconHouseholds`, 8) | crime, the press, staff | the household pools (9.1) |
| Building: an estimate before any quote, the bids, award, refuse (`EconConstruction`, 8) | the desk, the map | the estimate from the type table's build bill at today's prices; award and refuse are acts on a building contract |
| People by work status; deaths at work (`EconPop`, 6) | the planet, roads | the households and the company's `staff` together, since they are the same people |
| Staff totals, occupation (`EconLabor`, 4) | the press, work law | `staff`; the occupation is a column of the type table |
| Police stations, prisons (7) | police, crime, criminal law | state service companies. A police station's clients are the people of its area; a prison's are prisoners in places |
| A firm's yearly revenue (`EconAnnual`, 3) | fines | `money` |
| Hunger (`food_shortfall`) | crime, the legislature | the market's unfilled household food orders |
| Winding a company up (`insolvency`, 1) | the court | section 8.3; the fourth way is open |
| Paying the press, press subsidies (6) | the press | an outlet's wages and a subsidy line **(open: whether an outlet is a company)** |

Also to be reconnected, not yet listed line by line: code that reads the old tables by name (`facility` 57 reads, `org`
37, `project` 20, `hh` 5, `union` 3). In the rebuild `org` and `facility` are the company and its plants, `project` is
a building contract, `hh` is the household pools.

## 11. Every part of the old economy, placed

All 72 files. None of the code or numbers carries over, except the household side.

**Inside the company object**

| Old part | What it was | Where it is now |
|---|---|---|
| firm_ai | each firm's monthly decisions | the nine rules |
| econ_rules, _food, _mat, _svc, _housing, _utilities, econ_builders, econ_haulier, econ_institutions | one copy of the rules per sector | the nine rules, once |
| econ_production | output, accidents, emissions | monthly output; wear; `emissions` |
| econ_family | family farms and bakeries | the family size of any type; the grant is the government's |
| econ_trucks, econ_haulier | truck drivers, hauliers | `fleet` |
| econ_truck_shop | truck workshops | a type whose clients are trucks |
| econ_office | office staff | the office bonus |
| econ_workload | workload and stress | stress |
| econ_annual | yearly books | `money` |
| econ_forecast | a founder's forecast | the signal of rules 7 and 8 |
| econ_warehouse | stock needs space | `stock` **(open: whether storage space stays)** |
| econ_consumer | durables, quality, reputation | type rows **(open: quality and reputation)** |
| econ_staple | bakery goods preferred | the bakery row; the preference is the households' |
| econ_housing, econ_rules_housing | housing wear; landlords | the landlord company; wear (section 9.8) |
| econ_police, econ_care, econ_sanitation, econ_public_jobs, econ_hq, econ_bizsvc, econ_retail, econ_comfort, econ_fleet, econ_commute | organisations that held staff or took a fee | each a service company with a client intake, or gone, type by type |
| econ_public_co | public companies, approved tariffs | a state-owned company |
| conduct | firms cutting corners | a company's choice when the law's cost exceeds its gain **(open)** |
| econ_shares, econ_plan_rescue | the share register; rescues | `owner` as a register |
| econ_ownership | public or private expansion | rules 7 and 8 for every owner |
| econ_unfinished | half-built buildings | a building contract that changes client |

**Outside the company**

| Old part | What it was | What it is now |
|---|---|---|
| econ_households, econ_pop, econ_cohorts, econ_informal | households | 9.1, taken wholesale |
| econ_labor, econ_training | the labour market | 9.2 |
| econ_market, econ_credit | the order books; buying on account | 9.3 |
| econ_bank, econ_bank_risk, econ_money, econ_finance (loans) | the bank | 9.4 |
| econ_finance (taxes, budget), econ_actions, econ_autopilot, econ_essentials | the state's money and acts | 9.5 |
| econ_trade, econ_imports | ships, port, exports, imports | 9.6 |
| econ_construction | projects, tenders, bids | 9.7 |
| insolvency | distress to liquidation | 8.3 |
| unions, union_disputes, econ_unions | unions | 9.9 |
| law_bridge | the law's gate | 9.10 |
| econ_victims | the victim fund | the law's, paid to households |
| econ_indicators, econ_pic, econ_facts, econ_query, econ_report | what the economy publishes | 9.11 |
| econ_setup, econ_sim, econ_provider | the month-one colony; the monthly steps | 9.12 and build step 1 |
| econ_util | helpers | the core |
| econ_foodsec | a fix for the old food trap | gone |

One old file was not cut: `game/data/econ/econ_data.gd`, in a separate data folder. It holds the old type table and
all the old numbers, and the list of six districts that much of the game reads. Its numbers do not carry over, and its
district list is against "no sectors beyond landfallpoint". **(open: what replaces the district list)**

## 12. Build order **(proposal)**

The first order could not work: the reviews showed steps needing things from later steps. This one puts each need
before its use. Each step is built on the steps before it, with them on, and tested there.

1. **The ground:** helpers in the core; the world and the monthly step (terrain, the landfall place, the road month,
   the planet's month) that the old economy's start-up used to set going. The game compiles and runs again, with no
   economy in it.
2. **Month one and the company:** the record, the type table with starting prices set by us, the sizes, where a plant
   stands; the government's subsidiaries and five builders exist.
3. **Households and work:** the household side fitted in; hiring; salaries from the starting line by the three rules.
4. **The market and the price rules** (1, 2, 9, hold-back, only price moves price) and the output rules (3, 4): first
   one item end to end, then every item, then the types with work slots.
5. **The bank and owners' money.**
6. **Building:** builders, the building contract, the plan stage; rules 5 to 8; wear and repair.
7. **Homes:** landlords, the town grid, rent, owning, own houses.
8. **Freight:** trucks on the roads, the queue, truck workshops.
9. **The government's purse:** taxes, brackets, grants, state companies under the rules, the reserve.
10. **The end of a company.**
11. **Offices, pollution and noise, stress, unions.**
12. **Ships and the home world.**
13. **The law's hold, what the economy publishes, and every remaining open connection.**

At each step: three 30-year games, and where the bottleneck is, before the next step starts.

## 13. Readings that are Wilma's

Collected, so a reviewer can find them: the two salary signal lines (9.2); a builder's one price per unit of work (4);
the building contract as its own record (9.7); "turn the price" as back above the making price, and a buy-out as the
same event as growing in a shared square (8.3); a shutdown not read by the rules (9.9); no private companies placed in
month one (9.12); 10% of the bill for land (9.8); the staff-only types gone through one by one (4); the time for rule
6; the build order (12).

## 14. Open: not decided by anyone

From the six first reviews. Each needs the user's word or a proposal the user accepts.

**About companies and the rules**

1. Whether a month's price change has a cap, and its size.
2. The time a plant stands idle before rule 6 cuts it.
3. "Cheapest delivered first" needs a freight price before the sale: who quotes it, who carries, and whether the sale
   is made before or after carrying.
4. Trucks differ by quality; a cheapest-first market cannot tell them apart.
5. How a household becomes a client of a service, how many clients it is, and how far it travels to one.
6. What being served does to a person: clinic to health, school to skill, childcare to parents working, police to crime.
7. Quality and reputation of consumer goods; goods that spoil; goods that need storage.
8. Who picks where a plant stands; private roads and tolls; the planet setting a farm's yield.
9. Supply contracts, and how a short good is shared between buyers.
10. Whether essential plants hire first, and whether hiring and layoffs have a speed.

**About the outside things**

11. Utilities: power and water go through a grid, cannot be stocked or trucked, and the government approves their
    price. How they sit under "one company object".
12. Taxes on companies and sales; the budget lines; the reserve; the state borrowing.
13. Owners' money: what goes in at the start, and when profit is paid out.
14. The bank's own limits and failure.
15. The port, the ship schedule, the home world's prices and the charter quota; the merchant who sells landed goods.
16. The terms of a building contract: payment as work goes on, the price moving with wages and materials, an unpaid
    job, a half-built building, the client refusing a quote.
17. Unions: what a union demands that a company can comply with; which company a shutdown hits once members are in
    several; whether the fee stops during one; whether there is a federation; what a union may spend on politics and
    papers; the law on strikes.
18. The law's hold: licences and the permit office, closing an unlicensed plant, land leases, the taxes and price
    controls the law sets, the court winding a company up for convictions.
19. Company donations to parties.
20. Commuting and buses.
21. Whether a newspaper is a company.
22. What replaces the list of six districts.
23. Which of the road systems that were opt-in in the old game (freight on roads, road works, private roads, road
    safety, siting, seasons, ecology) are part of the rebuild.

## 15. This review

The user: "give the others a new chance this time asked them to review the whole thing from their perspectives not just
their parts, this is what i sake for last time and you did not this time i really do want it".

Each of the six reads the WHOLE plan, every section, and judges all of it from where they stand: Bob as the one who
knows markets, money and freight; Otto building and housing; Maja people and institutions; Ella services, unions and
campaigns; Terra the map and the planet; Anni the law. Not "is my part in it", but "seen from my side, does the whole
thing hold".
