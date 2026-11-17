# Reviews of the rebuild plan

Reviews of [rebuild-company.md](rebuild-company.md) (commit afd582a) by the six sessions, each from its own side, as the
user ordered. Collected by Wilma, 2026-11-17. Each review is given as the session sent it, shortened only in wording.

## Otto: builders, plan stage, order books, housing, office buildings

### 1. Missing from the plan

a) **The construction contract has no home.** The plan says nothing about a company lives outside its record, and `plan`
   exists only until the company opens. The old `project` record covered more than plans: a new plant for an open
   company (rule 5), an expansion, an upgrade, a renovation, a road, a state building. Each had work done and total,
   material and components used, the agreed price, what has been paid, start month, quoted wait, bids and the builder.
   The plan names the builder's `orders` but not the contract between builder and client.
b) **The contract terms:** payment as the work progresses; the clause that moves the price with wages and material
   prices; a builder cancels a private job after 3 unpaid months; what happens to a half-built building.
c) **The client's side:** the owner refuses a quote on price or on wait against its own estimate, and the tender
   reopens. The player can award or refuse by hand, or switch awards to manual.
d) **The plan stage is one line.** Missing: "no worker but also no expenses beyond building"; a grant is accepted after
   the plan; the plan is funded at the award; who funds it (family savings, founder's equity, credit on the contract);
   it ends only by its owner; it is not counted as founded or dead.
e) **Building condition over time:** ageing, repair, renovation, a block let slide, mothballing. Plants have a
   `condition` field but no rule acts on it. Repair is a build job.
f) **Failing companies:** distress, administration, liquidation, the sale of plants, the worker buyout, the state
   taking over a failed landlord's homes. The nine rules cover growth and shrinking but not a company's death.
g) **Housing:** rent arrears; households with no home (overcrowding, informal housing, slums); public housing and its
   levers (public rent, the rent increase cap, the housing budget).
h) **Roads as build jobs:** a road was a project built by a builder, plus the road-takeover payment. The plan gives
   roads to Terra but does not say who builds them.

### 2. Connections not answered

a) `EconConstruction.estimate`, 6 calls: a price is needed before any quote exists. An estimate from the type table's
   build bill at today's prices would answer it; the plan does not say so.
b) The decision desk's award and refuse are the player's writes, not reads. "Quotes on a state plan" does not cover
   them. The projects panel's manual-award switch is not answered either.
c) Government actions not answered: re-tender a project, upgrade a facility, offer an incentive (grants), the yearly
   re-tender switch.
d) Tenders, projects, "why is this project stopped", commission options: the read-only view cannot show projects
   while the project has no record (1a).
e) Court-ordered liquidation: no row in section 9.

### 3. Against a ruling

a) Section 3 keeps the plan inside the company record. The user: "PLANS ARE MADE BEFORE THEY BECOME COMPANIES" and
   "you can't fail before you exist ... no worker but also no expenses beyond building". A company row in a
   not-yet-open state is what the old FORMING row was. It may be fine if that record has no staff and no expenses,
   cannot fail and is not counted, but the plan says none of that. The user decides.
b) Rule 9, "the same cap (5%) both ways". The user's words were conditional ("if your going to cap it at 5% THEN DO
   THE SAME FOR BOTH"), and the same week: "I don't like hard rules you know that". The plan states a 5% cap as decided.
c) Rule 7 reads the average of all available work: no conflict; it was given for builders and is applied to all types,
   which matches "No more only this sector shit".

### 4. Cannot work as written

a) Rules 2 and 4 act on unsold stock. A builder's work, a service's client places and a landlord's homes cannot be
   stocked, so these types never have unsold stock. The plan does not say what counts as unsold for them (empty homes,
   free client places, idle crews).
b) One price per company for a builder: jobs differ in size and bill. It works only if the price is per unit of build
   work with materials charged on top. The plan does not say which.
c) Build order: step 3 runs the nine rules for one item, but rules 5 and 7 need builders (step 6). Step 6 needs credit
   at the award (step 7). Step 2 pays the starting salary from housing and food prices that come at step 4.
d) Section 5 says a company grows one size at a time by rules 5 and 6; rule 5 says "build a new one" (a plant). The plan
   does not say whether going up a size is a build job, a new plant, or neither.

Office buildings as real buildings (landlord company, ten plants a building, not essential, the 15%) match the user's
rulings as Otto knows them.

## Anni: law, utilities, police and prisons, levers

### 1. Missing from the plan

a) **The law's gate on companies.** The old bridge between companies and the law was cut with the economy and is not an
   "open connection", because the economy called the law and not the other way. It did: check the law before building,
   operating or extracting; queue a licence in the permit office with its fee; the misconduct choice (go ahead
   unlicensed, recorded as a violation); close a plant whose licence lapsed or whose rule changed, and reopen it. The
   company record has no field for any of it, and no build step covers it.
b) **Winding up.** A conviction count revokes licences and the court winds the firm up. The plan has no insolvency or
   liquidation, no creditor order, and no sale of a company; road law needs the sale (a revoked road must be sold
   within 12 months).
c) **Taxes and charges the law lays on a company's sales or output:** extraction royalty, export tax, luxury tax,
   tourist tax, landfill tax, sanitation fee, the charter's export levy. Section 8 names only tax brackets.
d) **The charter:** the home world's quota of components, material and mineral at the charter price. The ships row
   covers exports as stock on a ship, not the quota obligation.
e) **Law limits on prices,** which rules 1 and 9 must respect: price control on essentials, price gouging, rationing,
   the food export ban, requisition, the fare cap. Competition law reads market shares (dominance, mergers, cartels).
f) **Union law gates the union of section 8a:** strike ballot, public sector strikes, essential services (none, minimum
   service, no strike), strike liability, closed shop, recognition, the political levy.
g) **Work law:** the maximum working hours (the company has no hours field); staffing ratios per occupation (health,
   care, childcare, police), which needs an occupation per type row.
h) **Land:** a plant's tile is leased or bought from public land; the plant record has a tile but not its lease or title.
i) **Waste law:** the waste and sewage standards scale a plant's cost and its pollution.
j) **Utilities: nothing in the plan.** Power and water reach customers through a colony-wide grid, not trucks and not
   an order book: metered demand, plants run in price order, the price is a government lever whose rises the
   government approves, and neither can be stocked.
k) **Transport law:** passenger routes, the fare cap, tour operator licences. The plan has freight only.
l) **Media:** outlets pay staff, are founded with an endowment, get press subsidies from a budget line and are counted
   under the media ownership cap. The plan must say whether an outlet is a company (clients = readers) or stays outside.
m) **Private roads:** a company may own road links, take tolls and carry the neglect duties. Not in the record.
n) **Law records about a company:** licences, permit applications, violations, court cases, fines are held by the law,
   keyed by the company id.

### 2. Connections not answered

- Court-ordered liquidation: not answered.
- Road works ordered by the road law: the plan's action is "a building of type T at tile X"; a road works order names a
  link, not a tile and not a company type.
- Work law asks for a company's occupation; `staff` does not give it. The type table needs an occupation column.
- Prisons: "clients = the district" is wrong; a prison's clients are prisoners in places.
- Hunger in the crime drivers is unmet food orders of households, a market fact, not the population.
- The press subsidy and public media need a named budget line with headroom, not one account.
- Paying media wages: not answered.
- Law, staff and press code also read the company and plant tables directly by name; not in the list.

### 3. Against a ruling

- "All company types needs to be able to be created as private": three law levers let a government forbid private
  operators (transport operation defaults to public only, private roads forbidden, press licensing). For utilities the
  ruling was that no law may forbid them, only make them dearer. Whether the same holds for transport and roads is the
  user's call.

### 4. Cannot work as written

- "Nothing about a company lives anywhere else": the law's records must live with the law.
- Freight for power and water: neither can be carried by truck or stocked.
- Prisons with clients = the district.
- The yearly-bonus minimum: a lever needs a legal range and an owner; the user gave only the start.

## Maja: population, institutions, the decision desk

### 1. Missing from the plan

a) **Households themselves.** The plan says households are the population. But the population code holds only who
   lives where, with income band, occupation, work status and beliefs. Everything that makes a household live was in
   the economy and was cut with it: the household pools with their accounts and money; income, disposable income and
   savings; consumption, rent and bills; births, deaths and the age structure (growing up, retirement); migration and
   the informal sector (doubling up, shacks, homelessness); the link between people and jobs; the labour market
   (vacancies, layoffs, matching, the wage index); on-the-job training; commuting; the unemployment benefit and
   pensions. None of this is in the object or in section 8, and no build step covers it. Without the pools there is no
   buyer for consumer goods.
b) **What being served does to a person:** clinic access to mortality and health; school to the skill tier people
   reach; childcare to parents re-entering work; elder care to mortality of the retired; police to crime. Section 8b
   says workers have skills, but nothing in the plan makes a skill change.
c) **Family companies** need the household's account and its members counted as working in it. Both depend on (a).
d) **Public institutions:** who sizes a state company (rule 5 on its bracket income, or the government commissioning);
   what happens when clients exceed capacity; the old services had a budget line AND a bracket, and "paid by a tax
   bracket" drops the lines, which removes the desk's institution budget cases.
e) **Essentials and the food reserve:** "governments secure the essentials" and the food reserve the government
   releases are a government actor, not a read. Neither is in the plan.

### 2. Connections not answered

- Household persons, disposable income, paying media wages: answered "from the population". Wrong as things stand;
  income and wages need the pools and accounts of 1a.
- Casualties: the old call picks victims by work type and by plant, so it needs the people and the company's staff
  allocation together.
- Demography, commuting, labour, workload, slums, training: put under "one read-only view", but what they read is cut
  and not rebuilt anywhere in the plan.
- Colony unemployment (2 calls): not in the table.
- The desk's refuse and award are writes, not reads.
- Institutions: the desk and the building programme WRITE (budget, close, reopen); a read-only view does not cover them.
- The 16 government actions carried more than "order a building": re-tender, upgrade, manual award, release the food
  reserve, the institutions' actions.
- Delegation: the hiring and institution decision types stay in the desk; their sources are gone.

### 3. Against a ruling

- Rule 7's signal reads "a real signal of unmet orders in reach". The user: "instead of reading the leftovers, they read
  an avrage of all avaliable jobs". Unmet orders are the leftovers. The second half of the plan's line is the ruling;
  the first half contradicts it.
- Rule 6, "a plant idle for long": as written "long" becomes a fixed month count, a hard rule. It needs the market fact
  that ends it.

### 4. Cannot work as written

- Step 2 pays the starting salary from housing and food costs that arrive only in step 4.
- Steps 3 and 4 have no consumer demand and no household money until households are rebuilt.
- Changing jobs and union membership need the company's `staff` to be the allocation of actual people, not counts by tier.
- A free public service has no price at the door, so price rules 1, 2 and 9 have nothing to move. It works only if the
  bracket is that company's price, moved through the government. The plan must say so, or a rule is missing for a type.

## Ella: services, unions, unions in politics, truck workshops

### 1. Missing from the plan

a) **Company donations to parties.** Companies offered money to parties by their profit and their exposure to levers;
   secret or illegal gifts are what leaks, tips and investigations turn into scandals. The plan has no company-to-party
   money. The table is read by name, so the connection list does not show it.
b) **Union membership per person.** The ruling has a fee "from every person in it". `staff` holds only tier and stress;
   nothing records who is a member, so the fee, the 2/3 pay and the shutdown have no list of people to act on.
c) **Union records.** Section 8a defines no record: no fund account, no members, no founding company, no state. The old
   row also had a leader (militancy, elections), mood, mergers, breakaways and a federation. The ruling names none of
   these except the fee; which exist is open.
d) **What "comply" means.** The ruling says the government can lean on companies "if they don't comply". The plan has no
   demand a company could comply with. The old system had demands (wage, safety, jobs, recognition, staffing), the
   employer's answer, and the player answering public-sector demands. "Lean on" has no action either.
e) **The law on strikes** (Anni's side; flagged).
f) **Services: who is a client of whom.** The plan says a service serves N clients per unit, but not how a household
   becomes a client, how many clients a household is, or reach (own district and neighbours, by travel). A service has
   no item, so there is no order book to post on.
g) **Self-employed service providers** (households selling services themselves) are not in the plan: family-size
   companies, or gone. The user's call.
h) **Facts and indicators** the company and union records must emit: strikes, lockouts, mass layoffs, famine, slums,
   emigration, overload incidents, company founded, union density and others. Politics, the press and campaigns read
   them by name.
i) **Labour levers:** unions campaign on the minimum wage, union rights, public pay and the unemployment benefit. The
   plan's salary sections have one lever, the bonus minimum. Whether the others remain is not answered.

### 2. Connections not answered

- Unions were by occupation, with a federation; politics, the press and staff look a union up by occupation and ask for
  "the federation". Under 8a a union starts at one company, so there is no occupation to look up and no federation
  unless the user rules one.
- What a union may give away (donations to parties, owning a paper) without touching its shutdown fund is not defined.
- Open demands and the player's answer to them: no demand exists in the plan.
- Unions donating to parties and owning papers: not in the plan.

### 3. Against a ruling

a) Rule 9: the plan says "only the one with priority acts in a month". The ruling: "if both signals come in the same
   month only the one with priority happens". Priority applies only when both signals come together; one signal alone
   acts on either side. As written, a lone lowering signal below cost would never act.
b) The 5% cap: the ruling is conditional ("IF you're going to cap it at 5%"); 5% was our proposal, not the user's figure.
c) Grants: "I DID NOT SAY GIVE EVERYONE ... GRANTS". Section 8 says the government "grants" with no limit on who. The
   rulings give grants to family farms and bakeries, and to truck drivers and truck workshops ("started by grants alla
   bakeries").
d) The truck rulings are carried correctly.

### 4. Cannot work as written

a) Rules 1 to 4 for services: no item, no stock, no order book. The signals need defining: clients turned away because
   the company was full (raise), empty client places (lower).
b) TRUCK REPAIR as an output item: a repair cannot be stocked or shipped; it is the client-intake shape (trucks as
   clients).
c) TRUCK as an item with a quality: a market of "cheapest delivered first" cannot tell trucks apart by quality.
d) Shutdowns and the nine rules: a shutdown stops output and sales. Rules 4, 6 and 8 and the salary rules would read a
   long shutdown as unsold output, an idle plant, uncovered work and open posts.
e) Which company a shutdown hits once a union spans several: the founding one, the one with bad conditions, or every
   employer of its members.
f) Who pays during a shutdown: whether the company pays anything, and whether the members' fee stops.

## Bob: rules, market, bank, freight, food, materials, ships, salaries

### 1. Missing from the plan

a) **Taxes:** what a company pays the government and when (profit tax, sales tax, luxury tax, mining royalties).
b) **Owners' money:** founders' equity in, dividends out to households, the state, a party or a union.
c) **Insolvency:** the whole way from distress to dissolved, missed loan payments, asset sales.
d) **The bank beyond lending:** household deposits, interest, loan service, the bank's own room and failure, the state
   borrowing and defaulting.
e) **Household demand:** what forms the monthly orders (essentials against the rest, quality and reputation, the shop's
   margin) and what happens when households cannot afford food. The plan does not say who owns that.
f) **Household income other than wages:** unemployment pay, pensions, food assistance.
g) **The state's reserve** of food, material and components, released when scarce.
h) **Supply contracts,** which filled first; politics has supply deals.
i) **Buyer classes and how a short good is shared:** contracts, households' essentials pro rata, institutions,
   government, firms, construction, households' other buying. The plan says only "cheapest delivered first".
j) **Commuting and buses:** missing buses kept workers from work and cut output.
k) **The merchant on both ends of a ship:** the importer selling landed goods, and export consignments.
l) **Item properties:** which items spoil and which need storage.
m) **Hiring order and speed:** whether essential plants still hire first, and whether hiring and layoff speeds stay.
n) **Firm-to-firm trade on account,** if it is meant to stay.

### 2. Connections not answered

a) Ships: the schedule and fleet, the hold, port stock and capacity, home-world prices, the tariff, the trade balance,
   cargo left on the dock. None is a company; they need an owner outside it.
b) What a budget line has left (11 calls) is per line; "the state's own account" gives one account.
c) Government payments and spending against a line (press subsidies): not in the table.
d) Colony unemployment: not in the table.
e) Two of "the rest" are actions, not reads: approving a public operator's tariff (which collides with one price per
   company set by the rules) and releasing the reserve.
f) The legislature reads food shortfall, food assistance, unaffordable food and sovereign default: measures of
   mechanisms the plan does not have.
g) Household accounts and wage payment sit in the ledger, not in the population.

### 3. Against a ruling

a) Ships: the plan left out "on its next call", the full round trip. (Corrected in draft 6.)
b) Freight that did not move: the plan's proposal contradicted "count the work que not passed work" / "That works" and
   "If something else than price stops sales it should not count on adjusting price!!". (Corrected in draft 6.)
c) Rules 2 and 4 did not exclude stock unsold for freight, road or the buyer's money. (Corrected in draft 6.)
d) "A huge company" is ten plants' worth of office workers, not size 4. (Corrected in draft 6.)

### 4. Cannot work as written

a) "Cheapest delivered first" needs a freight price on the route before the sale; the plan does not say how a buyer's
   ranking gets it, who carries, or whether the sale is made before or after carrying.
b) Services under rules 2 and 4 have no stock; a state service's price has two owners (the government's bracket and
   the rules).
c) The salary line "in the area" against one salary per company with plants in two districts.
d) Capacity by size, by plants, or both.
e) Starting money: what a company, the bank and the state hold at the start of a game.

## Terra: roads, map, town grid, planet

**Households.** Terra cannot tell which part of her plan the user means and asks that the user be asked. Her latest plan
is [design-town-grid.md](design-town-grid.md), sections 3–4 and 9–12 (12 is the newest). In it a household is one home
on the town grid: a plot in a house cell (8 to a cell) or a flat in an apartment or tower cell, inside a housing block
on 100 m cells. A household has a type (family with children, single, old) that weights what draws it. A home's value
follows its cell, and "Rent and price follow the value". Each household owns a car and commutes home to work on its
shift. She never wrote a household record; her plan assumes Maja's population plus a housing block per 50 homes.

### 1. Missing from the plan

a) **The month step and the world itself.** The old economy's start-up built the world (terrain, layout, districts) and
   registered the planet's month (climate, wildlife, roads, waste). The plan has no world builder.
b) **Picking a plant's tile:** the plan says a plant has a tile but not who picks it.
c) **Town buildings on the fine grid:** a plant needs a form and homes per unit.
d) **Commuting:** home-to-work trips fed bus fares, the bus lines on the map, road congestion and the planned cars.
e) **The roads' own state the economy wrote:** freight and commuter traffic (wear, jams), how much can move between two
   districts a month, breakdowns and crashes on a road.
f) **The planet's effect on a company:** ecology and seasons set farm output; storms and wildlife kill outdoor workers.
g) **Private roads:** a company can own a road and take tolls.
h) **Roads as building work:** a road is a link along a path, not a building at a tile.

### 2. Connections not answered

- `EconData` was not cut: it is still in `game/data/econ/econ_data.gd`, holds the old balancing numbers the roads price
  themselves with, and holds the district list everything uses. The plan never says where districts live.
- Commuting is missing from section 9.
- The planet reads emissions per district; the plan writes them per company; something must sum them.
- Casualties are capped by who works outdoors at a plant, which needs the plant's staff by occupation.
- Road works do not fit "a building of type T at tile X".
- The map needs each police station's tile.
- A plant needs a form and a closed or mothballed state for the town grid and the map.

### 3. Against a ruling

- One price per company against "the closer to the coast you get the more expensive they get; it can even shift from
  road to road": a landlord with one rent cannot have homes that differ by street. The user decides.
- Nothing stays behind an off switch, but every part of the roads that ties them to the economy was opt-in and off in
  v11 (freight roads, road works, private roads, road safety, siting, town grid, seasons, ecology). Without them the
  "road network" is a district distance table. The plan must say which of them are "roads and supply networks ...
  that's done already". Freight roads lost 8–12% of adults in its old test.
- The allowed housing forms are the government's choice; the plan's housing row carries no form.

### 4. Cannot work as written

- Steps 1 and 5 need the world built and the road month running, which the plan puts at step 11.
- The plan ships tile to tile; the road code routes district to district.
- The starting salary needs an average housing cost per area; nothing publishes one until a landlord sets a rent.
