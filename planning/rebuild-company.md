# The rebuild: one company object

Status: DRAFT 3 by Wilma, 2026-11-17 (sizes, unions and salaries from the user's answers). Not reviewed. Nothing is built.

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
per month. The old `RECIPES` table already has this shape for 34 types; it becomes the one table.

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
| 4 | large | full size | the type row as written; "a huge company" that fills an office building of its own |

Size is a multiplier on the type row (inputs, labour, output, build bill); it is not a different kind of company. Output
per unit of size is the same for all four, less a small penalty for the smaller ones. **(proposal, the penalty is not
given as a number: family 6% less, small 4% less, average 2% less, large none.)** A company grows or shrinks one size at
a time by the capacity rules (5 and 6).

## 6. The nine rules, plugged into the object

One implementation, called for every company every month. Each reads only the company's own `signals` and the market.
No rule is skipped for a type because it cannot take effect today (ruling).

| # | Rule | Signal it acts on |
|---|---|---|
| 1 | raise the price | it sold what it offered and orders went unfilled FOR PRICE-INDEPENDENT REASONS EXCLUDED ("if something else than price stops sales it should not count on adjusting price") |
| 2 | lower the price | unsold stock that was actually offered ("the more inventory you have, the more you reduce your price"); stock held back is nobody's signal |
| 3 | raise output | "if you sell out all your producing produce MORE"; also picks first or second output by which pays |
| 4 | lower output | unsold output |
| 5 | add capacity | "if your selling out and all plants at max build a new one ... money is a limitor" |
| 6 | cut capacity | a plant idle for long |
| 7 | start a company | a real signal of unmet orders in reach; founding reads the average of all available work, with no cap on how many may form |
| 8 | do not start one | the same signal says the work is already covered |
| 9 | priority | below making price, climbing has priority; above it, lowering has priority; only the one with priority acts in a month; the same cap (5%) both ways |

Kept with them:

- **Hold-back:** a seller below cost offers what covers all its monthly expenses, not everything ("It sells too cover
  all monthly expences"). No hard floors.
- **No limit built on last month or last year.** Credit follows orders, contracts and forecasts.
- **Imports are a backstop:** ordered in only while no plant in the colony makes the good, and only on a ship in port;
  the answer comes back with that ship.

## 7. The parts plugged into the same object

Each is a function over the company record, not a system of its own.

| Part | How it plugs in |
|---|---|
| **Office** | a bonus building. A company with a staffed place in an office building works at full output; without one it loses about 15% ("you lose out on some not all lets say something like 15% less"). Office buildings are real buildings, put up by builders, owned by a private landlord (itself a company, type OFFICE BUILDING, clients = tenants); one building holds the office workers of ten plants; only a huge company owns its own. Offices are not essential and never hire first. |
| **Freight** | any company with trucks can carry ("the same company can become freight that's done already"). Freight is the company's own fleet moving its own or others' goods over Terra's road network; a haulier is a company whose type row has freight room and nothing else. Truck quality is set when built and stays; trucks wear; workshop repair uses components and resets wear, about 5% lost each time; self-repair takes about 4 months. |
| **Roads and supply networks** | Terra's `Transport` (kept, in `sim/transport`). A company ships from its plant's tile to the buyer's over the network; what cannot be carried stays in its stock. **(proposal: no separate "freight left behind" bookkeeping; it is simply stock that did not move.)** |
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
| The government | politics (`sim/politics`) | owns state companies, sets tax brackets and levers, grants, commissions buildings from builder companies |
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
| 9 priority | below making price, raising has priority; above, lowering | **(open)** what plays the part of the making price for a salary: the cost of living, or what the worker's output earns the company |

Only the pay signal moves the salary: a post that stays open for another reason (no housing nearby, no one with the
skill in the colony) is not a reason to raise it, as with prices ("if something else than price stops sales it should
not count on adjusting price").

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
3. Do households stay as Maja's population built them, or are they rebuilt too?
4. Does the old type table (34 types) carry over as the starting point, or do you want to go through the types?
5. How large is the "small penalty" for the smaller sizes? (Wilma's proposal is in section 5.)
6. For salaries, what is the line that rule nine turns on (the "making price" of a worker)? (Section 8b.)

## 12. Review

After the user has seen this draft: Bob (rules, market, bank, freight, food), Otto (builders, housing, plan stage),
Maja (population, institutions), Ella (services, unions, truck workshops), Terra (roads, map, tiles), Anni (law,
utilities) each review it from their side: what of theirs is missing, and which connection of theirs is not answered.
