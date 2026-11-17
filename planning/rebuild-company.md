# The rebuild of the economy: one company object

**Version 13, 2026-11-17. Wilma.** What the old economy had that this plan does not include is listed in [rebuild-not-included.md](rebuild-not-included.md). Unified, reviewed twice by all six sessions, and with every open point decided (section 12). This replaces all earlier versions. It is one document: every ruling the user gave
for the rebuild is in it, in its place. Nothing is built.

How to read it:

- Text in quote marks or in a quote block is the user's own words, unchanged.
- **(proposal)** marks something Wilma filled in. It is not decided.
- **(open)** in sections 1 to 11 marks a point that was open when the section was written. Every one of them is decided in section 12.
- Everything else is the user's ruling put into plain rules, or a fact of the code.

Where things are: the game as it was before the cut is `game_full_copy/` and commit 785c72f. In `game/` the economy is
removed and every call into it is left open; they are listed in [economy-connections.md](economy-connections.md). The
six sessions' first reviews and Terra's opinion on homes are in [rebuild-reviews.md](rebuild-reviews.md); their second
reviews, of the whole plan, are in [rebuild-reviews-2.md](rebuild-reviews-2.md). The rulings
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
  code is copied and every number is set again. That holds for the household side too: HOW it worked is carried
  over, not its code (section 9.1).
- "set a credit prices we are going to have to adjust it anyway i don't have a sheet of what costs what so i can't tell
  you what it should cost". Every price and quantity is ours to set and is adjusted in testing.

**What the rebuild is judged by.** It does not have to keep companies alive, prices affordable, people employed or the
colony from collapsing. A company can misjudge demand, borrow too much, lose its customers or be outcompeted, and fail.
A colony can have a recession; its bank can fail; a government can make ruinous choices. Those are results, not
faults. The user, on a producer that sells below cost for years: "it does not really matter if he does not close ...
its not meant too be a perfect economy for everyon". The fault to hunt is a result that does NOT follow from the rules:
a missing connection, two sums that disagree, a payment made twice, goods from nowhere. So: do not fix a company
because it fails; fix the simulation only when it fails for a reason the rules do not contain.

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
| `salary` | what it pays, per skill tier and per area of the hiring plant (section 9.2) |
| `stock` | what it holds of each item, at what cost, and what of it is waiting for freight |
| `money` | its account and its books by month and by year. Its loans are the bank's records; the company only points to them |
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

A company founded in the colony does not exist before its plant opens. Before that it is a plan (section 8.1), which is
not a company. The five builders of month one are different: they arrive from the home world already operating, with
their crews and equipment, and need no building in order to exist (section 9.12).

## 4. The type table: one 2D array

"it's just a 2d array of wich items a company type makes, if they pick from first or second output".

Rows are company types. Columns say, for ONE full-size unit per month:

| Column | Meaning |
|---|---|
| inputs | items it takes in (energy, water, mineral, material, component, food, consumer goods, medical) |
| first output | the item it makes by default |
| second output | another item the same plant can make instead; it picks by which pays (rule 3). Each output has its OWN line of inputs, labour and quantity, so what is used up and made always follows what is actually being made |
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

**Squares.** A square holds one full size of company PER TYPE: one large, or three small, or six family companies of
the same type. A shop does not take a landlord's room in the same square; another landlord does.

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
  sale stopped by freight or the road counts neither as unsold stock (rules 2 and 4) nor as an unfilled order (rule 1).
  A buyer who is short of money is different, and is spelled out in 12.3, 23a: being unable to pay THIS price is a
  matter of price. "Ignore the stoch in that other place too".
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

"Okay i think we can take it wholesale as long as we make sure it fits in". And, when Wilma had written this down as
taking the old code: "Households, i mean we take how it works and transfer over not take the code".

So: HOW the old household side worked is carried over as a whole. Its code is not. It is written new, like everything
else, to do what the old one did. The old code in `game_full_copy/` (econ_households, econ_pop, econ_cohorts,
econ_informal) is the description to work from. How it worked:

- **Pools, not single families:** one pool per housing block and income band, with one account. Each pool knows its
  workers and jobless, adults outside the labour force, retired, children, owners, the self-employed, and their skills.
- **Money in:** wages, the unemployment benefit, pensions, dividends to owners, the earnings of the self-employed, the
  savings migrants bring.
- **Money out, in this order:** food; rent (unpaid rent becomes a debt to the landlord); water and power; the other
  essentials; then what is left, split between consumer goods, services, comfort spending, newspapers and saving. Orders are placed a month ahead; a household that
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

**Wholesale is not unchecked** (the user, 2026-11-17: "Oh no wholesale does  not mean unchecked"). Nothing of the old household code comes in
unlooked at. Before the household side is written at build step 3, every mechanism of the old one is gone through and
given one of three verdicts: keep (write it new to work the same), change, or leave out. The first pass, from the function lists of the four files and Maja's check:

| Mechanism in the old household code | Verdict | Why |
|---|---|---|
| Pools by housing block and income band, with an account | keep | the user accepted pools ("That's fine") |
| Company owners inside the pool | change | owners are counted individually from the company's start (12.5, 35) |
| Head counts by work status, occupation and skill | change | each pool also keeps a count per company its members work for |
| Wages, dividends, the benefit, pensions as money in | keep | the payers are the company, the owner's company and the purse |
| The self-employed selling services from the pool | remove | "ONE kind of thing that produces"; they become family-size service companies |
| What a household needs each month, per person | change | the amounts are in the old units and are set new |
| The order of paying when short | change | the old order was food, water and power, then rent. The user: "what are you paying power and water on if you can't pay the rent?" So: food, then rent, then water and power |
| Buying: essentials first, the rest split over goods, services, comfort, papers, saving | keep | every line now has a seller (12.6, 48) |
| Price floors and ceilings inside the household code | remove | "No hard floors or ceilings of our own" |
| A household budgeting food at price plus freight, tax and the shop's margin | change | the shop is a company now; the household pays the shop's price |
| The home world's emergency rations after two months of hunger | remove | nothing comes from the home world except on a ship in port, ordered with a ship |
| Ages 0 to 99, births, deaths, growing up, retirement, returning to work | keep | with the numbers set new |
| Deaths and births worsened by hunger, poor clinic access, shacks and homelessness | keep | they are what makes a failure cost something |
| The 130% crowding limit, shacks, homelessness, shack fires | keep | it is how many fit in a home, not a rule of ours on prices |
| Settlers arriving and people leaving, by ship | keep | only with a ship in port |
| Migrants "only while the colony has jobs" (a fixed 10% unemployment gate) | remove | a hard gate; how attractive the colony looks already decides it |
| Everything keyed by the six districts | change | keyed by area |
| Reaches into the old sector rules (food rules, service rules, shops, trade, commuting) | remove | each is replaced by the company record and the market |
| Deaths from wildlife, storms and road accidents taken from outdoor workers first | keep | needs the occupation column of the type table |
| Household pollution | keep | |

This table is the first pass. Maja owns the full check, line by line, before step 3, and anything not in this table is
looked at then, not assumed.

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
- **A company with plants in two places:** "The district the plant hiring is in." In the rebuild that is the AREA the
  plant stands in (12.1, 1). Districts are drawn for elections and can be redrawn; a salary's reference place does not
  move when they are.
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

**Stocking up** (the user, 2026-11-17, verbatim): "Company and people should be able to stock up if the price is low".

- A company may buy more of an input than it needs this month when the price is low, and a household more of what it
  uses. What they bought ahead they do not buy later.
- **What "low" is measured against** (the user, correcting Wilma's "below its average over twelve months"): "No what's low should be against what its worth to the buyer, like when they buy normaly". Every
  buyer already has a worth for what it buys: the most it will pay, which is what it puts on an ordinary order (for a
  company, what the input is worth in what it makes and sells; for a household, what the thing is worth to it). A
  price is low when it is under that worth. The further under, the more reason to buy ahead.
- **(proposal, the rest:)** how much: as far as its money reaches and the goods keep; food spoils, so nobody stocks far
  ahead on it. A stock-up order is a real order with money behind it, so it counts as demand for the seller's price
  rules like any other.

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
- **Imports:** a company or the government can order from the home world what it needs, but only when a ship is in
  port to take the order, and the goods come back with that ship on its next call. That is the whole limit. It is what
  stops imports from being an everyday, monthly source: there is no ordering between ships. (The user's remarks about
  imports being a backstop were about the old code's MONTHLY requests and limiting those. They were not a rule about
  when a colony may import, and are not applied as one. The user: "YOU CAN'T TAKE A THING I SAY AND APPLY IT TO THINGS
  WITHOUT THE CONTEXR".)
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
- ALL grant types open: family farms, family bakeries, truck drivers, truck workshops. (The "three" in the quote was a slip; the user: "JUST ALL FUCKING GRANTS ... THE THREE WAS A MISTAKE".)
- **No sectors beyond the landfall point.** The colony starts as one place where it landed. No districts are laid out
  in advance; where things are built decides. (The old game started with six named districts, and much code reads that
  list.)
- **What the colony lands with** (the user, 2026-11-17, verbatim):

  > Okay materials come with the start not finished buildings 5 years worth of equipment  that never changed they are companies from the world. Tell me in any colony builder do you place out fucking plants from start????

  - **No plants are placed at the start.** No farm, mine or factory stands in month one; as in any colony builder,
    everything is built by the colony. This was always the design ("that never changed").
  - **The colony lands with materials, not finished buildings: five years' worth of equipment.** That is what is
    built from until the colony's own makers are open, and it breaks the deadlock all six reviews named.
  - **The five builders are companies from the home world.**
  - This is NOT the old game's rule that a home-world builder brings five years of its running costs. The user: "no the
    old system and the new for five years are not the same". Wilma had merged the two; they are separate, and only the
    new one is in this plan.
  - **(proposal)** The landing stock also holds food until the first farms open. The user has not said so.

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

All 72 files. None of the code or numbers carries over. For the household side, how it worked carries over.

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
| conduct | firms cutting corners | a company's choice when its gain is worth more than the fine it risks (12.10, 66) |
| econ_shares, econ_plan_rescue | the share register; rescues | `owner` as a register |
| econ_ownership | public or private expansion | rules 7 and 8 for every owner |
| econ_unfinished | half-built buildings | a building contract that changes client |

**Outside the company**

| Old part | What it was | What it is now |
|---|---|---|
| econ_households, econ_pop, econ_cohorts, econ_informal | households | 9.1: how it worked, written new |
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

## 12. Decided by Wilma: every open point with an obvious answer

The user, 2026-11-17: "start answering all the fucking questions that have obvius answers i don't want to hold you
fucking hand for every decision". So every point the two reviews left open is decided here, from the user's rulings,
from what several reviewers proposed alike, or from plain sense. These are Wilma's decisions. The user strikes any that
is wrong; nothing here is asked again.

### 12.1 The ground

1. **An area** grows out of where homes and plants are built (the population code already makes such areas). A salary's
   area, a household's area and a service's reach are that. Month one has one area: the landfall place.
2. **Districts** are drawn by the government from the areas, by the existing districting law, as the colony spreads.
   The Assembly's seats follow them. With one district all seats are colony-wide.
3. **Land** belongs to the colony at landing. A plan buys the land it builds on from whoever owns it, at the land price
   (the value of its cells). A buy-out buys the land and the building together.
4. **A square** holds one full size of company per type (now also said in section 5).
5. **Where a plant stands** is a set of cells or tiles, chosen by its plan with the siting code: the best-scoring free
   place for its type. A plant pays for its road, power and water connection as a home does.
6. **A building** is kept by a buyer of the same type. Another type rebuilds it. An empty building after an ending
   stands and wears, and can be bought.
7. **The order of a month:** trade, then production, then settlement (wages, rent, taxes, loans), then the companies'
   rules, then the households. The rules read the month just finished.
8. **Money at the start** (the treasury, the bank, the settlers' savings, the builders' capital) is set by us with the
   other numbers.

### 12.2 Month one

9. **The landing stock** is five years' worth of equipment and materials (the user's words, section 9.12). It is the
   colony's; the government sells from it at the starting prices. Food in it is Wilma's addition.
10. **The settlers** arrive as in the old game: a founding population with ages, skills and savings, numbers set new.
11. **The first homes** are the landing shelters: plain homes at the landfall place, the housing office's, with a low
    rent. Real homes are built. (The colony lands with no finished buildings; people still have to sleep somewhere.)
12. **The first roads:** none beyond the landfall place. Roads are built as the colony spreads.
13. **The port** is at the landfall place and is the government's.

### 12.3 The rules

14. **The making price** of a thing is a month's cost of making it (inputs, wages, upkeep, rent, freight it pays, and
    the interest on its loans) divided by what the plant makes at its normal full output. Not by what it happened to
    sell, so a bad month does not inflate it. Paying a loan BACK is not a cost of making: a company that borrows to
    build a second plant does not raise its prices for that. The hold-back is separate and still covers every monthly
    expense, repayments included ("It sells too cover all monthly expences").
15. **How far a price moves in a month:** by the share k x s / (1 + s) of the price, the same formula up and down.
    s is a ratio of quantities, not money.
    - For a rise, s = the quantity ordered at or above its price that it could not supply because it had sold out,
      divided by the quantity it sold.
    - For a cut, s = the quantity it offered and did not sell, divided by the quantity it sold. An order that went
      unfilled because the buyer would not pay the asking price is a refusal of the price: it counts here, for the cut,
      and not as unmet demand for a rise.
    - First there has to be a signal at all. A company that offered nothing and had no orders it could have filled
      has neither, and its price does not move.
    - If there is a signal and it sold nothing at all, s is taken as without limit and the price moves by the full k.
    - k is one number for the whole economy. It starts at 0.2 (a fifth of the price at most in a month) and is set in
      testing. A small signal moves the price a little, a large one more,
      and never by more than k in a month. So there is a bound, the same both ways, as the user's rule nine asks.
    (This is the shape of the stock cut the user ordered into the price table on 2026-11-16.)
15a. **Rule 7's signal, exactly.** Everything is in money per month.
    - The work: what buyers and clients in the area spent, or tried to spend, on what this type sells, averaged per
      month over the last twelve months, at today's prices.
    - The shares: by PLANT, not by company. Every plant of the type that serves the area counts by its size (family
      1/6, small 1/3, average 2/3, large 1), whoever owns it. A company with three large plants counts 3. The
      newcomer's share is its own plant's size divided by the sizes of all those plants, its own included.
    - The test: a plan is made when that share of the work, per month, covers what a company of that size costs to run
      per month. A founder plans the largest size that passes and that their money reaches.
    - A founder's management skill and appetite for risk (12.11, 77) bend how they read it, so founders misjudge.
    - Nothing limits how many may plan at once. If five do and the work carries two, three fail.
16. **Rule 6:** twelve months idle.
17. **Rule 5 runs section 5's order:** a size up in its own square; else a buy-out; else a new plant.
18. **Rule 3 does not act while a company is holding stock back.** It has more to sell already.
19b. **Being left out of a signal is not being spared the cost.** A company stopped by a broken road, a missing
    input or a shutdown is not read by the price rules or the sales-death clock, but it still pays its wages, rent and
    loans, and can run out of money.
19a. **A company that cannot pay its staff lays them off, and a plant with no staff is shut.** A shut plant the
    company cannot afford to reopen or replace is the second way a company ends (section 8.3). So a company that is
    stopped by something other than price, for good, ends through its money, not through the price rules.
19. **Missing inputs are not a price signal.** A builder whose crews wait for material, or a plant without power, has
    empty slots or unsold output from a cause that is not price; rules 2, 4 and 6 do not read it.
20. **Sales death counts only months when price was the cause.** Months lost to freight, the road, missing inputs or a
    shutdown do not count toward the two years.
21. **A union shutdown** pauses the sales-death clock and the idle time, and a struck plant still counts as covering
    its work for rule 8.
22. **Types with work slots do not hold back.** An empty slot is lost that month whatever they do.
23. **Hunger is counted from need, not from orders.** A household's food need that is not met, for any reason
    including its own money, is hunger. Only the price rules ignore the part stopped by money.
23a. **Short of money, or refusing the price.** Every order carries the most its buyer will and can pay per unit.
    - The buyer could pay something, but less than the asking price: that is a refusal of the price. The goods left
      unsold because of it count for a cut (rule 2). The user, 2026-11-14, on bread: "if they want to but can't buy,
      bread goes too high — the company can win by lowering".
    - The buyer has nothing at all to pay with: no order with money behind it exists, so there is nothing for the
      price rules to read. That is the only case that is "not price".
    So when a colony is poor and food piles up unsold, food prices fall. Earlier versions of this plan lumped both
    cases together as "the buyer's money" and would have kept prices up while people went hungry; that wording was
    Wilma's and Bob's, not the user's.
24. **The second output** is switched from one month to the next, at no cost.
25. **An export** counts as sold, at the home world's price, when it goes aboard. Stock at the port waiting for a ship
    is waiting for freight, not unsold.
26. **Imports:** no rule of ours on what may be imported. The limit is the ship (section 9.6).
27. **A short good** is shared in proportion among the buyers offering the same price. No buyer goes first by class.
28. **Hiring:** nobody hires first. Pay decides. No speed limits on hiring or laying off.
29. **Saving for replacement:** upkeep is part of the making price, so a company that sells at or above it can keep its
    plant up.

### 12.4 Freight and trucks

30. **A carrier posts a price per route,** set by the same three price rules. A buyer ranks offers by price plus
    freight. The sale is made before carrying; goods on the road are the buyer's.
31. **A builder's supplies** are delivered to the building site by freight like any sale. "Up front" means at the site.
32. **A truck is ordered from its maker,** not bought cheapest-first off a market. The buyer chooses the maker by price
    and quality.
33. **Roads:** siting, seasons, ecology, freight on roads, road works and road safety are all part of the rebuild and
    on. Private roads and tolls are left out for now.
34. **The planet** sets a farm's yield by season and ecology; storms and wildlife act on plants and outdoor workers as
    before.

### 12.5 People

35. **Households stay pools,** each with a count per company its members work for. **Company owners are counted
    individually** (the user, 2026-11-17, verbatim: "On company owners, they should become individually counted on
    company start, that divides them from the others but don't malt to many people to track"). The founder
    is taken out of the pool and becomes a person of their own, with their own account, on the day their plan is made
    (60a). A plan is still not a company; its founder is a named person from its first day. That is who the court,
    a grant, the profit and a settlement act on. Everyone else stays in the pools, so the number of people tracked one
    by one stays small: one per company owner.
36. **The old household side is carried over like this (as behaviour, written new):** its district keys become areas; its self-employed become family-size
    service companies; its price floors and ceilings and the ceiling on the self-employed are removed; every number it
    read from the old data file is set new. The 130% crowding limit stays: it is how many people fit in a home.
37. **The starting salary is per worker:** the housing and food of a household in the area, divided by its earners,
    plus half again.
38. **A worker's needs** (below which they do not apply) are that same housing and food per worker.
39. **Changing jobs:** an employed worker moves when a job within reach pays more after travel. This is new code.
40. **Reach:** a worker takes a job within travel reach of home; pay is compared after travel time and fare. Buses are
    the transit company's, with riders as clients.
41. **The benefit and pensions** are lines on the government's purse, each a share of the area's starting salary. The
    retirement age stays a lever.
42. **Arrivals and departures** by ship are built with the households, not with exports.

### 12.6 Services

43. **A household is a client** of the nearest service of the kind that it can pay for and that has a free place within reach (school 1.5 km,
    clinic 2 km, from the town grid). Each person who needs it is one client.
44. **What being served does:** a clinic lowers deaths, a school sets the skill a child grows up with, childcare lets
    parents work, elder care lowers deaths of the retired, police lowers crime.
45. **Who cannot pay:** a public service is paid by its bracket, and by a fee at the door if the government sets one
    (12.11, 100). The fee starts at nothing. A private service serves who pays.
46. **A bracket** is proposed by the service's own rules (it needs more, or less) and decided by the government. The
    same holds for the tariff of a state-owned utility.
47. **A state service's size:** its rules propose a new plant or a closure; the government decides and commissions.
48. **Shops, cafés and the like** are service companies with a client intake, so every line of household spending has a
    seller. A newspaper is a company whose clients are its readers. A party's office staff are the party's own.

### 12.7 Utilities

49. **Power and water** are companies whose way of reaching the buyer is the grid. They cannot be stocked. A private
    one prices by the rules; a state one proposes and the government approves.

### 12.8 Money, owners and endings

50. **The bank is a company.** Its clients are its borrowers and its price is the interest rate, set by the same three
    price rules. The government borrows from it like anyone.
50c. **How the bank lends.** A loan creates money: the bank writes the loan into its records and the same amount into
    the borrower's account. Paying it back removes that money again. So the money in the colony grows and shrinks with
    lending. What limits lending is the bank's own capital set against the loans it has out, at a ratio set by us, and
    its judgement of the borrower. A loan that is not paid back is a loss to the bank's capital; when the capital is
    gone the bank has failed (50a). (The old game worked this way after the user's decision of 2026-11-14 that bank
    lending must be able to grow the money stock with the economy. It is carried here by Wilma as the model to build.)
50a. **Accounts are kept in the game's ledger,** not inside the bank company, so nothing vanishes because a bank is
    gone. But a bank that ends owing more than it has is a real loss: what it cannot cover is taken from its
    depositors in proportion, as recorded payments. Its loans pass to whoever buys it out, or to a new bank; a
    borrower's debt does not vanish. Credit can dry up and companies can fall with it.
50b. **One record of each thing.** Money: the ledger. A loan: the bank's record. A sale: one record made by the market
    when the sale is agreed, which says who owns the goods, what is paid and whether they have been carried. The
    company, the bank and the carrier point to that record and keep no version of their own.
51. **Owners** put in what a plan needs beyond its loan and grant, and take profit out once a year from what the
    company holds above six months of its costs.
52. **The owner is liable** for the company's debts, as the court ruling says. The court can take back what the owner
    took out in the company's last year.
53. **In a buy-out the debts go with the plant.** One owner's companies selling to each other is allowed and is taxed
    like any sale.
53a. **A dead company's unsold stock** goes to the bank against what the company owes it, counted at today's market
    price less 10%, and only as much as covers the debt. The rest stays the owner's to sell. The bank sells what it
    took like any seller; the government can buy it for the reserve like any buyer. (The user asked Wilma which of two
    ways she would take, this or the stock going to the government as surplus; this is the one she chose.)
54. **A state company that cannot pay** is covered by the government out of the money the government actually has, or
    closed by it. There is no bottomless subsidy: a government can spend itself into the ground. Nobody takes the state
    to court.
54a. **Liability with more than one owner:** each owner answers for the debt by their share. An owner that is an
    organisation (a co-op, a union, a party) pays from its own account. What the home world owns, the home world writes
    off.
55. **Other non-payment:** unpaid rent ends in eviction under the existing law; an unpaid upkeep fee, tax or fine goes
    to court like a loan.

### 12.9 Building

56. **A building contract** is paid month by month as the work is done. The price of the builder's own work is fixed at
    signing. Only the part that is wages and material follows what those cost during the build; a builder raising its
    price for NEW jobs does not raise a job already signed. The builder stops after three unpaid months. A half-built building stays and another plan can
    take it over. A client may refuse a quote and wait.
57. **A builder's book** is worked in the order the jobs were signed.
58. **Upkeep** uses material and a little builder's work.
59. **A plant keeps running** while it is built a size up.
60. **A plan's money** is held in an account of its own until the plant opens.
60a. **The founder is counted individually from the day the plan is made,** not from the opening, so that a grant, a
    loan and "one grant per household" have a named person to attach to while the venture is still a plan. (The user
    ruled individual counting "on company start"; Wilma reads the plan as where a company starts.)
60c. **A founder or owner is still a household.** Counted individually, they eat, pay rent and buy like any household,
    from their own account. When they no longer own a company or a plan and their debts are settled or carried, they go
    back into the pool of the block they live in, in the income band they now belong to.
60b. **A plan that is given up is settled, not erased.** The builder keeps what it was paid for work done. The land
    bought and the half-built building belong to the founder and can be sold; another plan may take them over. The loan
    is still owed. The grant is owed back. What the founder cannot pay goes to court like any debt (8.3). A given-up
    plan is still not counted as a company that failed.
61. **One grant per household.**

### 12.10 The government, the law, politics

62. **Taxes** keep their old kinds (income, profit, sales, royalties, the charges the law sets), with every number set
    new. **Budget lines** stay, each with what it has left. **The reserve** is the landing stock and whatever the
    government buys for it.
63. **Levers:** every lever politics reads by name stays where its thing still exists, with its effect built new: the
    minimum wage, union rights, public pay, benefit and pension rates, rent and price controls, tariffs, the
    yearly-bonus minimum.
64. **A legal ceiling on a price or rent** stops the rules at the ceiling. That is the government's doing, and allowed.
65. **No law may forbid a company type from being private;** it may only make it dearer. (The user's ruling for
    utilities, applied to all types.)
66. **Licences and permits** work as before: the law is checked, the licence queues in the permit office, and a company
    may go ahead unlicensed when its gain is worth more than the fine it risks.
67. **A buy-out** goes through the existing competition law. The company being bought can refuse an offer below what
    its land, building and stock are worth.
68. **The court can wind a company up** after repeated convictions, as before.
69. **An accident at work** is the company's to pay for.
70. **People the state employs outside any company** (judges, inspectors, ministries) are hired and paid by the same
    salary rules, with the government as the employer.
71. **Unions:** what a union demands is better conditions or pay at the company where it started the dispute; a
    shutdown hits that company; members pay no fee while out and the company pays them nothing; there is no federation;
    a union may spend on politics and papers only what it holds beyond one month of shutdown pay; the existing law on
    strikes applies.
72. **Donations:** companies give to parties from their profit, as before. A party buys its advertising from
    newspapers. A party-owned company's profit goes to the party, on the record.
73. **Blame:** every ending, mass layoff, shutdown and famine publishes who is responsible and where, so voters can
    act on it.
74. **Prices for voters:** a price index per area, from the companies' prices weighted by what they sold.
75. **The decision desk:** every act of the government in section 10 that a minister would decide is a case on the
    desk, as before.
76. **The player's view:** a plain map that shows plants from step 2; a run-down building looks run-down.

### 12.11 Worked in from the old game

The user, 2026-11-17, on the list of 36 old systems the plan did not include
([rebuild-not-included.md](rebuild-not-included.md)): "I think most of these needs to be worked in". Each is placed
here. Where a thing used to happen by itself to save someone, it is now something a person or a government CHOOSES to
do and pays for; nothing is rescued automatically.

**In the company**

77. **Management.** A company has a chief with a management skill and an appetite for risk. Management decides how much
    of a plant's normal output it really reaches and how well a founder reads rule 7's signal. Owners replace a chief
    whose company is doing badly.
78. **Upgrades.** A plant can be rebuilt to a better grade of the same size, taking less in or giving more out. It is a
    building job the company chooses when it pays.
79. **Mothballing.** An owner may close a plant and keep it: no staff, a small upkeep cost, and it wears. Reopening
    takes hiring again. Rule 6 is what tells it to.
80. **Unsafe plants.** A hazardous plant in bad condition is closed under the law, keeps a small repair crew and
    reopens when it has been put right. If the owner cannot afford that, it is the second way a company ends.
81. **Who may buy a plant.** In a buy-out or after an ending, the buyer can be another company, the plant's own workers
    as a co-op, or the government. Each pays for it like any buyer.
82. **Trying to avoid the end.** A company or a plan in trouble may sell a share of itself, ask the bank for more time,
    or ask the government for help. The bank and the government may say no. None of it happens by itself.
83. **Credit lines.** Besides a loan for building, the bank offers a running line for wages and supplies. It has a
    price, and the bank can refuse it or call it in.
84. **Cutting corners** includes putting off upkeep and running short-staffed. Both save money now and raise wear,
    accidents and stress.

**People**

85. **Training on the job.** A company with skilled posts it cannot fill trains people from the tier below, at its own
    cost. The government may pay part from a budget line.
86. **Sickness.** Where clinic places are short, part of the labour force is too ill to work. It is published, so
    voters and the papers see it.
87. **Public work for the jobless:** a government may fund a scheme that hires the jobless at low pay, from a budget
    line. Its workers move to any better job.
88. **Food assistance, a floor and a time limit on the benefit, a tax allowance** are levers of the purse beside the
    benefit and pensions.
89. **Lockouts and arbitration.** A company may lock its staff out in a dispute. Where the law bans a strike, the
    dispute goes to arbitration.

**The government and money**

90. **The home world's grant.** The home world pays the colony's government a development grant in the early years,
    tapering to nothing. It arrives by ship like everything else.
91. **The bank's remittance.** A bank owned from the home world sends part of its profit home, by ship.
92. **A government that cannot pay** defaults. After a time its creditors write part of the debt off, and nobody lends
    to it meanwhile.
93. **Helping the bank.** A government may put money into a bank that is failing, in return for a share of it. It may
    also let it fail.
94. **Subsidies and co-financing.** A government may subsidise a company or pay part of a plant it wants built, as a
    choice of policy with a budget line. This is not a grant to every new company.
95. **Buying and selling plants.** A government may buy a plant from its owner or sell one of its own.
96. **Who expands, as a policy.** A lever from market to state: whether the state's companies start new plants or leave
    the field to private plans. Private companies can always start (12.10, 65).
97. **State companies pay a dividend** to the treasury from their profit, at a rate the government sets.
98. **How the state picks a builder:** by price, the builder's record of finishing and how soon it can start, weighed by
    a lever. A builder has a record.
99. **The public works department** builds at cost when the government tells it to. It is a builder like the others
    and is not one of the five home-world ones.
100. **Fees at the door** for a clinic or school are levers. At zero the service is paid by its bracket alone.
101. **Cleaner production** is a lever: it cuts a plant's pollution and raises its costs.
102. **Securing the essentials.** The government watches food, power, water and material. When one runs short it can
     order a plant built, order from the home world with the next ship, or release from the reserve. It is the
     government's choice, and a government may choose badly or not at all.
103. **A caretaker government** runs the purse by a plain rule in test games that have no politics.

**Utilities, the port, the home world**

104. **When power or water runs short:** water is served before power, and homes, farms and clinics before other
     users. An outage is published.
105. **The home world's prices** for what the colony sells move over time, and the colony learns the new ones only
     when a ship calls.
106. **The port has a size.** What does not fit aboard or on the dock waits, and a full port is published.
107. **The charter quota:** the colony owes the home world set amounts of certain goods at a fixed price, collected
     by ship.

**What other parts read**

108. **A reference wage** is published per area and for the colony: the average salary paid. The law's fines, the
     press's costs and the benefit read it.
109. **The fiscal report and the economic briefing** are read from the purse and the published figures.

**Not worked in**

- **The home world's emergency rations** arriving by themselves after two months of hunger. Nothing arrives that was
  not ordered with a ship (12.10, 102 covers ordering food).

### 12.12 Left out for now

Supply contracts; buying on account between firms; storage space; quality and reputation of consumer goods; private
roads and tolls; a union federation. Each can come back once the base runs.

## 13. Build order

Reworked from the second review and from an outside review the user passed on. Each step is built on the steps before
it, with them on, and tested there. Things that depend on each other are in the same step.

No plant stands at the start, so nothing can be made or sold until something has been built. The first economic step is
therefore the whole loop once, end to end, through the real company object:

> a need that is not met → someone makes a plan and signs with a builder → material and work become a building → the
> company opens and hires → it makes, sells, pays what it owes and is paid → the nine rules decide its next month.

1. **The ground.** Helpers in the core; the world, areas and the landfall place; the order of the month; the planet's
   and the roads' month; a plain answer for every open connection so politics, law and the screens run ("no unions",
   "no budget yet"); a plain map. The game compiles and runs with no economy in it.
2. **Month one.** The company record, the type table with starting prices, sizes, squares, land and siting; the
   landing stock; the five home-world builders, operating; the government's subsidiaries; the settlers and the landing
   shelters; the ledger with everyone's account; the purse paying its own staff, the benefit and pensions.
3. **The first loop, whole.** The households fitted in; hiring and salaries; the market with the price rules (1, 2, 9,
   hold-back) and output rules (3, 4); the plan, the building contract and the opening of a plant in their plainest
   form, with rules 7 and 8 and the four grants (they are open from month one); the ship schedule with arrivals, departures and orders to the home world; seasons and farm
   yield. Tested first on food alone.
4. **Everything that is sold, and how it moves, together.** All items; the types with work slots (public services,
   shops, utilities on the grid); freight on the roads with the queue, carriers' prices, trucks and truck workshops.
5. **Money and endings.** The bank lending; owners' money; the three ways a company ends; the court.
6. **Building in full.** Rules 5 and 6 and growing by size, buy-out or a new plant; wear and repair; permits and
   licences; land sales.
7. **Homes.** Landlords, the town grid, rent, owning, own houses; noise.
8. **The government's purse in full.** Taxes, brackets, budget lines, levers, the reserve, price controls.
9. **Offices, pollution, stress, unions, donations.**
10. **Exports and the home world's demands.**
11. **Everything the economy publishes, every remaining connection, the screens.**

**Who builds, and who checks** (the user, 2026-11-17, verbatim): "Get everyone involved give them peaces related to them make sure we get this done and atleast one other reviews each peace of code made"

- Every session has a piece that is its own: Bob the rules, market, bank and freight; Otto building and housing; Maja
  people and public services; Ella services, unions and what politics reads; Terra the ground, the roads and the map;
  Anni the law's hold; Wilma the doorway, the start-up, politics' side and putting it together.
- **No code is committed until at least one other session has read it.** The reviewer reads the code itself, not a
  summary of it, against the plan, and answers in writing: what is wrong, what the plan says differently, what is
  missing. The author fixes or answers each point. Wilma commits only with the review attached to the hand-over.
- Review pairs: Terra and Maja; Bob and Otto; Ella and Anni. Wilma's code is reviewed by whichever of them knows the
  ground it touches. A pair is the default, not a limit: anything that crosses into another's ground is also read by
  that session.

**How each step is tested**

- **What step 3 is and is not.** It is the first loop on one place, paid from savings and the purse. The bank does not
  lend until step 5, goods do not need trucks until step 4, and companies do not grow or close idle plants until step 6.
  Each step-3 report says so, and nothing seen there that comes from one of those missing parts is a reason to change
  a number.
- **Month one has to add up, on paper, before step 3 is run.** With the starting numbers of step 2: can a settler's
  savings plus the grant pay for the land, the three months of material up front and the builder for a family farm,
  and for a truck driver? If not, nobody can plan anything and the colony only eats its stock. That is a mistake in
  our starting numbers, not a result.
  And, since the bank does not lend until step 5: which types can be paid for from savings and a grant alone? Only
  those appear in step 3, and the report says which could not.
  And (food in the landing stock is Wilma's decision, 12.2, 9; if it is struck, this check asks where the first
  months' food comes from at all): does the food the colony lands with last longer than it takes to plan, build and open the first farms and
  bring in a first harvest? An outside run with made-up numbers (12 months of food, 4 months to build a family farm)
  got through with food to spare; with 8 months to build, or under 8 months of food, the stock ran out first.
- **Short, exact tests first:** one sale, one hire, one plan signed and built, one loan, one ending, each checked to
  the last credit and unit. A 30-year game says little until the loop of step 3 runs.
- **Nothing appears or vanishes.** Every test and every game checks that money, goods, people in work and unfinished
  buildings add up from month to month: no payment made twice, no goods from nowhere, no worker in two jobs.
- **Then three 30-year games,** and where the bottleneck is, before the next step starts. From step 3 on each report
  also says which companies would have ended, even before endings are built at step 5.
- **No tuning around a missing part.** If a 30-year game is bad because a later step is not built yet, that is written
  down and left; numbers are not bent to hide it. A bad result is first traced through the payments and decisions that
  made it. Grants, floors, rescues or more starting money are never the first answer.

**What each step's report says**

1. Which parts are now on for good.
2. Whether their payments and changes add up with everything built before.
3. What happened in the games, failures and shortages included.
4. The main limits seen, and which decisions caused them.
5. For each limit: is it what the design should produce, is it a fault in the code, or is it there because the next
   step is not built yet. This fifth line is what stops one workaround being piled on another.

**To watch for and report, not to prevent**

A second outside review (2026-11-17) found no contradiction in the plan and named five things the rules will produce.
Each is a result, not a fault. A step's report says when one is seen, and nothing is changed to stop it.

1. **A plant running below its normal output** has a making price that understates what each unit really costs it that
   month, because the making price is taken at normal full output. It can sell at a loss in cash while standing above
   its making price, and end through its money before the two-year clock ever starts.
2. **Waves of entry.** A shortage can set off many plans at once. They all open months later, together, into a market
   that carries a few of them, and the rest fail. While they are being built they also take the builders and the
   material.
3. **Sharp price moves** if k is set high: one bad month at the port or a turn of the season can swing a price far
   enough to break the buyers downstream.
4. **Five builders and everything to build:** in month one building is a seller's market, and its price can climb fast
   enough to eat the landing stock and the settlers' money before the first farm opens.
5. **Holding back at a low price:** a company below its making price that owes a lot each month may have to sell
   nearly all it has just to cover its expenses, so the hold-back holds little.

6. **A job that costs more than it was signed for,** because wages and material rose while it was being built, and a
   plan that cannot pay the difference.
7. **A plant that opens before what it needs exists:** a bakery finished before the first harvest pays its staff for
   months with nothing to bake and can run out of money as the grain arrives. A founder is free to plan it.
8. **Many plans for the same thing in the same month.** All of them read the same signal before any has opened. What
   holds them back is the builders: a plan knows the wait before it signs (9.7), and with five builders booked the
   wait grows long. Plans are NOT counted as companies in rule 7's shares; the user ruled that out as protecting
   companies from failing.

**What counts as a fault, by example**

| Case | A valid result | A fault |
|---|---|---|
| Several companies enter one market | too much supply, falling prices, some fail | they ignore each other's sales or count demand differently |
| A supplier cannot get material | it stops, orders stay unfilled, it loses money | the same stock is used up and sold elsewhere |
| A freight route fails | late goods, shortages, a company may fail | goods doubled, or gone without a recorded loss |
| The bank cannot pay | depositors lose, lending stops, companies fall | balances change because a record was deleted |
| An employer raises pay | workers move, its costs rise, it may fail | a worker counted at both companies |
| A builder is not paid | work stops after three months, the building stands half done | building goes on without work, material or pay |
| A colony has a deep recession | closures, unemployment, people leave, politics reacts | two parts of the game report different jobs or money |

## 14. What I am least sure of

One of the decisions above changes what a ruling does in practice. It is decided, and flagged so the user can find it:

- **11, the landing shelters.** The ruling is "not finished buildings"; I gave the settlers plain shelters anyway.
## 15. This review

The user: "give the others a new chance this time asked them to review the whole thing from their perspectives not just
their parts, this is what i sake for last time and you did not this time i really do want it".

Each of the six reads the WHOLE plan, every section, and judges all of it from where they stand: Bob as the one who
knows markets, money and freight; Otto building and housing; Maja people and institutions; Ella services, unions and
campaigns; Terra the map and the planet; Anni the law. Not "is my part in it", but "seen from my side, does the whole
thing hold".
