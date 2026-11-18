# Rebuild step 4: the stage plan (on paper; no code)

Ella and Anni, 2026-11-18, at Wilma's request. Uncommitted. Draft: every session reads the whole of it before it goes to
the user.

The user, 2026-11-18, verbatim: "Ah yes this is what i want a full stage plan with who dose what, who reviews when what
stages within it that go in in what order".

**How to read it.** Part S is the plan: the stages in the order they go into the game, and who builds and who reviews
each piece. Parts A to D below it are the reference for each piece: the user's words it rests on, what exists in the
tree, what is missing, and what is ours. Part E lists the questions for the user, each at the stage it blocks.

## What step 4 is, in the plan's words

Section 13, step 4: "**Everything that is sold, and how it moves, together.** All items; the types with work slots
(public services, shops, utilities on the grid); freight on the roads with the queue, carriers' prices, trucks and truck
workshops."

Under it, marked by the user (2026-11-17), verbatim: "Can we add a prefernce for farms not being close to towns? This
might be the best way to start districts when the grant is made the government picks a spot away from towns where they
will be built, then that center soot can start getting buisness and then their own housing sectors, and a town grows
what do you think before we add it" and "Save it for when trucks and roads come Mark it for then". The four answers
stand in section 13 (quoted in part C below).

Added by Wilma today: the founding of every company type, builders among them. The user's words, 2026-11-18,
verbatim (rebuild-building 4.6): "Nothing they are shut gone dead, this is where opening of new companies comes in,
also the communal builder owned by the government that goes down to one or two but never empty of employees".

**How the reading was split.** Ella read the types with work slots (services, shops, utilities), the founding of every
type, and the marked farm spot. Anni read all items and their markets, freight and trucks, and the law's hold on all of
step 4. Anni's half is part D, filled from her notes.

**How the parts are marked.** The user's words are quoted verbatim, with where they stand. "Exists" is read from the
code in the shared tree today, not from memory. **(ours)** marks a reading or starting number of ours. **(Wilma's)**
marks Wilma's decisions in section 12, which the user may strike.

---

## S. The stages, in the order they go into the game

### The rules every stage keeps (section 13 and 15)

- **Each stage stands on the ones before it, with them on.** Nothing goes behind an off switch.
- **Every piece is read by another session** before it is committed. The reviewer reads the code against the plan's
  words and the user's, never only a summary, and answers in writing.
  - Pairs: Terra and Maja; Bob and Otto; Ella and Anni.
  - Wilma's code is read by whoever knows the ground it touches.
  - A piece that crosses into another session's ground is also read by that session.
- **Before building, reviewing or reporting,** each session reads the plan's words on its mechanism and writes said
  and built.
- **A stage is in** when all of these hold:
  1. its pieces are reviewed and committed;
  2. the full test suite passes on the whole tree;
  3. a five-year simulation on seeds 1, 2 and 3 has been read against what the stage lists, with the five lines of
     section 13's report.
  Only then does the next stage start building. A session may write on paper or trace for a later stage meanwhile.
- **Every stage's simulations** also show:
  - that money, goods, people in work and unfinished buildings add up from month to month;
  - that food is no worse than at the stage before, unless the stage's own report traces why;
  - the Logbook row for each new decision.
- **A ruling of the user's is placed at the stage it blocks.** Nothing of that stage is built before the word comes.
  Stages that do not need it go on.

### The rules every price and output rule keeps, for every way of selling (the user's words of 2026-11-18)

Every new way of selling in step 4 (client places, building work, freight per route) uses the price and output rules
as the user has now worded them. Bob's read: the draft still described rule 1 the old way.
- **Rule 1** counts those who came to THIS seller, found it full or sold out, and went elsewhere or nowhere: "every
  seller that comes looking and goes somewhere else ... not orders unfilled by anyone"; "oders that are filled before
  they come to my farm does not count"; "everyone they pass raises ... only the one they ended on or never reached
  lowers".
  - For a service: clients who came to it and found it full.
  - For a carrier: shippers who came to it and found no room.
  - For a builder: the same words. Otto's building_signal is older than them and is read against them in 4.1a.
- **Rule 3:** "if you sell out all your producing produce MORE". For a service, every place full.
- **Rule 4:** "only lowered if over 50% of offered goods is not sold 3 months in a row"; "A CUT IS 5%"; "A FOURTH
  MONTH LOWER AGAIN". For a service, over half its places empty three months running, then 5% a month while the run
  lasts.
- **The rise cap and its slow climb** ("No it's for all goods"): every price has its original.
  - A place: the type's starting price.
  - A route: the starting freight price per unit-km times the route's km.
  - Without that, these prices would climb with no cap. Bob builds it.
- **Rule 8's capacity** for each way of selling: places served, BW done, freight carried, not only items.

### Stage 4.0: what the game does today (no building)

- **What the game does:** the food loop of step 3.
  - Farms only can be founded (`FOUNDABLE = ["FARM"]`).
  - A builder left with nobody ENDS: its status is ENDED and nothing brings it back ("Nothing they are shut gone
    dead"). Its unstarted jobs go back to the market; its started jobs stand half-built in its book. (Otto's piece,
    merging after Bob's and Maja's.)
  - The public works department follows the rules down but never below two employees ("never empty of employees";
    Wilma's reading: two). The purse owes the two their wages.
  - The government cannot order anything (A5). There is no grid, no services and no freight; the delivered price is
    the posted price. The farm grant and the government's land zoning (61c) are in.
- **Already being built at step 3, so not in step 4:**
  - the "grows from the land" column (Terra);
  - the other places Wilma listed where the plant object named one type or good: Maja's rent and needs, Otto's crew,
    Bob's family column (the user: "Good, those").
  - FARM stays named in one place by the user's own word: "FAMILY FARMS FAMILY FARMS don't shut".
- **The check:** Wilma keeps the five-year simulations of seeds 1, 2 and 3 on that tree as the base every stage is
  read against. They show:
  - the month the last private builder ends;
  - the number of farms;
  - the food price;
  - plans left waiting for a builder.

### Stage 4.1: founding every type; new builders; crime on (first, since dead builders are gone for good)

- **Needs first:**
  - The land price is decided (Wilma, 4.1g).
  - Question 4 is answered (below, 4.1c). Nothing from the user blocks 4.1.
- **Pieces, in order:**
  - **4.1a. Rule 7's work for every type** (B1, 2).
    - Items: the market's summary already counts every buyer, companies and households. What is missing is every
      line's orders, not line 0 only, and a first-year fill that is not households' food needs only. Without these, a
      mine, bakery, works, power plant or waterworks never reads any work and is never founded.
    - Building work: at least the BW of the plans listed in the market (made, not claimed by any builder). A count
      of quoted and signed work is 0 exactly when every builder is dead, so no builder would ever be founded, and
      that would defeat "this is where opening of new companies comes in" (Otto). Whether claimed work counts too is
      Bob's reading of "an avrage of all avaliable jobs". The builders' price signal is read against rule 1's present
      words (above).
    - Client places, freight, homes, office places and loans: 0 until their stage.
    - Built by Bob. Reviewed by Otto.
  - **4.1b. Every type is foundable** (B1, 1). FOUNDABLE becomes every type in the table, so the conductor names no
    type.
    - Built by Wilma. Reviewed by Bob.
  - **4.1c. A builder founded in the colony** (B2): its plan, its yard, its opening as a crew, its hiring. It needs
    4.1a's count of listed plans.
    - The user, 2026-11-18, verbatim, asked who builds a new builder's yard when every private builder is dead:
      "They build it".
    - **(Wilma's reading, told to the user)** The government's builder, the public works department, builds a new
      builder's yard: a new builder's plan may sign with it. Today Building.builders(for_hire) leaves the public works
      department out of what a plan can hire, so this piece lets a builder's plan hire it.
    - Built by Otto. Reviewed by Bob, and by Terra for where a yard is sited.
  - **4.1d. What politics reads:** the number of builders, builders ended and founded, the wait for a builder.
    - Built by Ella. Reviewed by Anni.
  - **4.1e. No licence is asked before step 6** (L3: built differently from law-face 2 and the build order).
    LawCompany.licences_required stops demanding HAZARD and EXTRACTION licences until step 6.
    - Built by Anni. Reviewed by Ella.
    - It goes in before 4.2: Colony Power's plant is hazardous, and `may_open` would close it unlicensed.
  - **4.1j. Crime reads the rebuilt pools** (Maja; it lands before 4.1f). Today EconFace.query_crime_drivers is a
    stub that answers {}, so crime falls back to the old "hh" table, which the rebuild never makes. With crime on,
    every household driver would read 0. This piece fills query_crime_drivers with a households reader in crime's own
    driver shape, by district: population, unemployment, hunger, homelessness, inequality. crime.gd is untouched.
    - Built by Maja. Reviewed by Anni.
  - **4.1f. Crime on for good** (L8; law-face 12, Anni's paper: "Crime reads the households ... from step 3"; today
    crime is opt-in and off). It is its own piece here, so this stage's simulation shows what crime alone does before
    police come in 4.4. Crime reads households through the old doorway (EconFace.households_*). Maja checks those
    readers against the rebuilt pools before this piece starts.
    - Built by Anni. Reviewed by Maja.
  - **4.1g. The land price for every type** (Anni). Site.land_price takes 10% of the plan's own bill for every
    type, a proposal written for homes, against 12.1, 3 **(Wilma's)**: "the value of its cells". Founding every type
    makes it bite.
    - **Decided by Wilma (marked as hers), resting on 12.1, 3:** one land price per place, the same for every type.
      - A country plan pays its share of the tile (its sixths / 6) of the tile's land value.
      - A town plan pays the land value of the cells it takes.
      - Both are read through the land law's land_value_fn (Site.land_value_milli).
      - The base stays, so a farm's land price does not move.
      - No type is named and no new number is added.
    - Built by Terra (Site), after her two step 3 pieces are in, and Anni (land law). Each reviews the other.
  - **4.1h. Fines read a company's real revenue** (Anni): annual_rev reads EconFace.annual_revenue, not the empty
    old table. It must be in before any company can be fined.
    - Built by Anni. Reviewed by Ella.
  - **4.1i. Placeholder loans, for starting a company only** (the user, 2026-11-18, verbatim, relayed by Wilma and
    recorded in MASTER-PLAN): "Put in placeholder loans?" and, correcting Wilma's longer answer, "You wrong it's just
    for the starting and never hiring".
    - So: a placeholder loan covers what a founder's savings and grant do not cover of the cost to start a company.
      It is never for hiring: no loan pays wages or keeps a company going. The bank itself is still step 5, and the
      order of the steps stays.
    - The user, confirming (verbatim, relayed by Wilma): "Yes put the loans in we can dial them for the sim until the
      bank becomes real".
    - So its numbers are **dials**: set in one place, changed between simulations, and replaced by the bank when it
      becomes real at step 5. Every simulation report states what the dials stood at.
    - **The dials and their starting values (ours, dials):**
      - paid back over 10 years, in equal monthly parts (the type table's own payback, PAYBACK_Y);
      - interest at 5 per mille a month (the type table's starting bank rate, BANK_RATE_PM);
      - the money is new money, written into the plan's account and removed again as it is paid back, as the bank
        will lend at step 5 (12.8, 50c, Wilma's).
    - It lends only what the start costs (Building.founder_needs) less what the founder's savings and grant cover.
      Nothing else, so no cap of ours is put on it.
    - A loan that is not paid is recorded as owed. What follows is step 5's (endings and the court), and each report
      says how much stands unpaid.
    - Built by Bob (the bank's ground). Reviewed by Otto (what a founder must bring, founder_needs), and read by Maja
      (who can found).
- **Which types appear:** builders and farms, and, with the placeholder loans, the costly works a founder could not
  pay for from savings and a grant, wherever rule 7 reads work for them. Nobody orders their goods until the stages
  that bring the buyers (4.3 to 4.5), so most read no work yet. That is by design, not a cap.
- **The check:**
  - Test suite: a builder plan made, signed, built and opened, to the last credit; a crime counted; a fine read
    against real revenue; a placeholder loan written, used only for the start, and paid back to the credit, with no
    loan ever paying wages.
  - Simulation, read:
    - whether new builders are founded after the home-world ones end, at what BW price, and how long a plan waits
      for a builder;
    - whether farms are still built;
    - crime with no police, against 4.0;
    - land prices by type;
    - **the loan dials:** what they stood at; how many plans took a loan, by type, and how much; what is paid back
      and what stands unpaid; whether any type is founded only because of the loan. The same simulations are repeated
      with the dials changed, to show what they do.

### Stage 4.2: the state as a client (the government orders what it builds, roads included)

- **Needs first:**
  - 4.1e.
  - **The government's money before step 8** (Maja's trace, seed 1, months 40-59): the treasury takes in about 694
    credits a month, the landing stock's takings, and nothing else. Under 1% of the benefit due is paid. Every new
    state piece leans on that purse: the public works' wages, commissions, state utilities, public services, police.
    As written, 4.2 would commission nothing, and Colony Power, the clinic and the school would never get a plant.
    Taxes are step 8. Where the government's money comes from before then is Wilma's to decide (E2), or the user's if
    the order of steps moves. The plan's own home-world development grant (12.11, 90: "in the early years, tapering to
    nothing", by ship) is not built and is one answer to weigh. Nothing in 4.2 is built before this is decided. If it
    is decided that the government has no money until step 8, 4.2's report says it commissions nothing, and why.
- **Pieces, in order:**
  - **4.2a. A contract whose client is the state,** paid from the purse. A state plant opens into an existing state
    company (Colony Power gets its plant).
    - At step 4 a commission goes to the public works department, at cost (12.11, 99). How the state picks among
      builders by price, record and start (12.11, 98) is step 6 (rebuild-building 5.5).
    - The public works department hires up for a commission by rule 3 on its own book, as any builder, with the
      purse paying its wages. At two, a power plant (840 BW) would take years.
    - "At cost" **(ours)**: its wages per BW plus its upkeep, with no margin.
    - The land for a state plant **(ours)**: the state takes its own land with no payment, only a Logbook row.
    - Built by Otto. Reviewed by Bob.
  - **4.2b. A ROAD contract** (moved here from 4.7, on Terra's read: on the day 4.6 turns freight on, farms and
    mines already standing off the network would otherwise have no road, and food would fall for a reason that is
    not 4.6's).
    - The road's bill per link at today's prices. Transport's `plan_link` reads the old data file's prices.
    - A ROAD contract kind in the building code; today building.gd has none.
    - The bill: built by Terra. The contract: built by Otto. Each reviews the other.
  - **4.2c. The act through the doorway:** EconFace's commission act is made real for the rebuild, with the desk
    case for a player government.
    - Built by Wilma. Reviewed by Otto, and by Ella for the desk and politics' side.
  - **4.2d. The state company's proposal:** its own rule 7, read as a proposal.
    - Built by Bob. Reviewed by Maja.
  - **4.2e. The AI government's answer.**
    - To a plant: yes when the proposal's rule 7 passes and the purse can pay the estimate **(ours)**.
    - To a road: roads to plants standing off the network, from Terra's road needs (12.2, 12: "Roads are built as
      the colony spreads").
    - It writes the Logbook row and the fact politics reads.
    - Built by Ella. Reviewed by Anni, and by Terra for the roads.
  - **4.2f. The purse pays a state company's whole month,** inputs as well as wages (A2, ours). Today landing.gd's
    purse_month pays wages only, so Colony Power could not pay for its fuel, nor a clinic for its medical supplies.
    - Built by Wilma (landing.gd). Reviewed by Ella (the government's side).
  - **4.2g. The law's side of state contracts and staff** (Anni):
    - the contract case (`_file_new_cases`) reads fields the rebuilt fact lacks and names the government as client,
      an empty builder and a claim of 0. It is fixed now that state contracts exist;
    - the law's own staff (judges, inspectors) are hired and paid as people, with the government as employer. This
      was due at step 3 (law-face 12) and is not built.
    - Built by Anni. The contract case is reviewed by Otto, the staff by Maja.
  - **4.2h. Accidents at work** (L6; moved here from 4.5, on Anni's read: POWER is a hazard row, and Colony Power is
    the first hazardous plant to open). Whether an accident costs the company now, or is only counted until the court
    at step 5, is Wilma's to decide (E2) before this piece starts.
    - Built by Anni. Reviewed by Bob.
- **The check:**
  - Test suite: a commission by hand builds a state plant and a road, paid from the purse to the credit; the public
    works hiring up and down.
  - Simulation, read:
    - roads commissioned to standing plants off the network;
    - the public works department's staff;
    - the purse;
    - the food loop, unchanged from 4.1.
    - Plants are not yet proposed: power, water and services read 0 work until 4.3 and 4.4.

### Stage 4.3: power and water on the grid

- **Needs first:**
  - question 3 is answered (below, 4.3a);
  - Wilma's import rule (E2), for 4.3e (Bob: `Ship.order` has no caller, so ordinary buying never reaches the ship;
    without the rule, Colony Power stands with no mineral).
- **Pieces, in order:**
  - **4.3a. The grid,** a built network. The user, 2026-11-18, verbatim, asked whether the grid has to be built with
    lines to each place, or reaches every buyer once a plant stands: "Gridd".
    - So the grid has to be built, with lines to each place. It reaches who its lines reach.
    - Its bill per link, commissioned through 4.2 like a road, and its upkeep. Where lines follow roads, the roads
      come first.
    - Built by Terra. Reviewed by Maja, and by Bob for the market's side.
  - **4.3b. Selling ENERGY and WATER over the grid:** what the grid reaches is in reach; nothing is stocked; when
    short, water before power, and homes, farms and clinics before other users (104); the outage is published.
    - Today the market refuses grid goods, and making takes grid inputs free. Both end here.
    - Built by Bob (the market, as the plan's list has it; Terra's read moved it back). Reviewed by Terra.
  - **4.3c. Households pay for power and water third,** after food and rent (9.1). This is the demand that gives the
    utilities their rule 7 work.
    - The food store moves with it: food, rent, power and water, then the store, then the rest. As built, the store is
      paid before power and water, so a household would fill its store and then sit in the dark (Maja).
    - A worker's needs (12.5, 38) take in power and water at the grid's price from 4.3b. Bob's offer rule reads the
      same figure.
    - Built by Maja. Reviewed by Terra, and by Bob for the needs line.
  - **4.3d. The state utility's tariff proposal and the government's answer** (12.7, 49).
    - Built by Ella. Reviewed by Anni.
  - **4.3e. The import rule:** when a company orders from the home world (9.6: only with a ship in port, a full
    round trip), as Wilma decides.
    - Built by Bob. Reviewed by Otto.
- **The check:**
  - Test suite: a grid sale; the shortage order; a household paying food, rent, then power; an import ordered with a
    ship in port and landed on its next call.
  - Simulation, read:
    - when the government commissions Colony Power and Colony Water, and when they open;
    - the first ship with mineral;
    - outages and who went without;
    - whether households short of money skip power and not rent;
    - whether a private utility is ever founded (9.5: "maybe they're is only ever enough work for say one
      powerplant").

### Stage 4.4: services (client places), police, newspapers

- **Needs first:** 4.3 (services take power and water), 4.2f (the purse pays public services' inputs), 4.3e
  (medical supplies come only by ship before step 5).
- **Pieces, in order:**
  - **4.4a. Taking a place:** each month a household takes a place at the nearest service with room that it can
    pay, within reach (12.6, 43). Those who came and found it full are counted for that service. The newspaper is a
    client-place type, so a household taking a paper is a place taken here.
    - Built by Maja. Reviewed by Terra, for reach on the town grid.
  - **4.4b. A service's places in the rules:** rules 1, 3 and 4 as the rules above word them; the making price per
    place; rule 7's work and rule 8's capacity in places; and a service buys its goods inputs on the same market as
    any company (today Making.post_orders skips it). Also check that the services' starting prices are posted as each
    company's price under its key (Bob).
    - Built by Otto (offered, to take load off Bob). Reviewed by Bob and Maja.
  - **4.4c. The cap's original for places and routes** (the rules above).
    - Built by Bob. Reviewed by Otto.
  - **4.4d. Public services** (clinic, school, childcare, elder care, administration, transit, sanitation): what
    being served does (12.6, 44): fewer deaths with a clinic and elder care, a child's skill from school, parents
    working with childcare. These are the demography hooks in Maja's demography.gd, built there once. Their proposals
    go through 4.2.
    - Built by Maja. Reviewed by Terra.
  - **4.4e. Police and prisons as state service companies** (L8): a police company's staff count as officers, and
    prisoners are a prison's clients.
    - The companies: built by Maja, reviewed by Anni.
    - Crime and sentences wired to them: built by Anni, reviewed by Maja.
  - **4.4f. Private services** (café, service hub, private childcare and elder care; the family-size service company
    of 12.5, 36): founded by rule 7, one price per company.
    - Built by Ella. Reviewed by Anni, and by Maja for the household side.
  - **4.4g. The newspaper as a company** (L9): its readers are its clients; job adverts are paid to it (9.2, the
    user: "costs of hiring, articles in the newspaper"); the press licence fee.
    - Whether the press licence may still refuse owners opposed to the government is Wilma's (E2), not a fault (Anni:
      12.10, 65 is about forbidding a type, which the refusal does not do).
    - The outlet: built by Ella, reviewed by Anni. The fee and the adverts: built by Anni, reviewed by Ella.
    - Two old readers wake with the paper (Maja), both in the outlet piece:
      - media_ops.gd:818 reads each district's readers through EconFace.households_persons on the old "hh" table.
        It reads the rebuilt pools, and readers are the paper's clients (4.4a).
      - EconFace.households_pay_media_wages answers 0. Its own comment says that unconnected, "every paper that is
        not the state's runs a deficit and closes". It is connected with the pools.
  - **4.4h. Sickness where clinic places are short** (12.11, 86): part of the labour force is too ill to work. They
    stay employed and do not work, which the company's output reads.
    - Built by Maja (the households' counts), with Making's side. Reviewed by Ella (what politics publishes).
  - **4.4i. What politics reads:** those turned away, by area; sickness (4.4h); the services' prices.
    - Built by Ella. Reviewed by Anni.
- **The check:**
  - Test suite: a household served; one who found a service full; a place paid for; a crime counted against a police
    company's staff.
  - Simulation, read:
    - which services are commissioned or founded, and when;
    - those turned away, by area;
    - deaths and births against 4.3;
    - crime with police, against 4.1's crime without.

### Stage 4.5: all items

- **Needs first:** 4.3, because every goods row but the farm takes power and water. The full reading is in
  rebuild-step4-items-reading.md.
- **The order the pieces go in:** 4.5a, then 4.5c (the shop), then 4.5b (households buy through it from the
  start), then 4.5d to 4.5f (Maja).
- **Pieces:**
  - **4.5a. Companies buy their inputs on every line, and rule 3 picks the first or second output** (section 6:
    "Also picks first or second output"). Today a two-line type opens a price for both lines and its line never
    changes, so the price rules act on an item it does not make: a fault, fixed here.
    - **(ours, to propose)** whether a plant switches whole or splits between its lines, and whether an idle line's
      price stays posted.
    - Built by Otto (offered, to take load off Bob). Reviewed by Bob.
  - **4.5b. Households buy the other goods:** consumer goods, clothing, furnishings, medical, and bread (9.1's
    money-out order). For these goods they stock up when the price is low against what the good is worth to them
    (9.3, the user: "Company and people should be able to stock up if the price is low", "against what its worth to
    the buyer"). Food's six-month store is food's own ruling (15f, "THEY BUY DOUBLE UNTIL THEY FILL SIX MONTHS", at
    any price), and is not the model here (Maja).
    - A worker's needs (12.5, 38) take in these goods too, or workers take jobs that cannot pay for them (Maja).
    - **(ours, Maja to propose)** how much of each a person needs, from Bob's figures in rebuild-type-table section
      2, and the split of what is left over goods, services, comfort, newspapers and saving.
    - **(Wilma's)** that households prefer bread: section 11 places the preference with the households.
    - Built by Maja. Reviewed by Terra, and by Bob for the market's side.
  - **4.5c. The shop as the seller within reach** (A3: Bob's reading; Wilma confirms it before this piece starts).
    - Built by Bob. Reviewed by Otto and Maja.
  - **4.5d. Company stock spoiling,** only if Wilma rules it in (E2). Anni's read: the user's words do not decide
    it ("No it's for all goods" was said of the price climb). Today a company's food never spoils.
    - Built by Maja (she built households' spoiling). Reviewed by Bob.
  - **4.5e. The bakery's grant opens with the bakery** (12.9, 61b; Grants.wanted BAKERY exists).
    - Built by Ella. Reviewed by Anni.
  - **4.5f. Every place in the economy's code still naming one good or one type,** after step 3's eight are merged.
    It is a list read on the tree at that time, each fixed by its owner.
    - Reviewed by each owner's pair.
- **The goods chains and the money to start them:** a mine, processing, components, consumer or medical works cannot
  be paid for from savings and a grant alone (rebuild-type-table section 9). The user's answer is the placeholder loan
  for starting only (4.1i), so these chains can be founded in step 4 where rule 7 reads work.
- **The check:**
  - Test suite: a household buying each good; a second-output switch.
  - Simulation, read: which chains start, and which cannot be paid for; what is short and why, traced in the
    Logbook to the rule that acted; the staffing loop below.

### Stage 4.6: freight, trucks, commuting

- **Needs first:**
  - 4.5;
  - roads to the plants standing off the network, commissioned through 4.2 and built before freight is turned on.
- **The order the pieces go in** (Otto, Bob and Terra: a delivered price needs routes and carriers, and a carrier
  needs trucks): **4.6a routes, 4.6b commuting, 4.6c trucks, 4.6d the carrier, 4.6e the delivered price**, then
  4.6f to 4.6i. The full reading is in rebuild-step4-freight-reading.md.
  - **4.6a. Routes:** `Transport.route` wired to areas, plants and the port: km, time and cost. The old
    freight_roads code is made to read areas, and its numbers are set new. A route closed by weather (transport's
    `_fail` "ROAD", "CLOSED") stops carrying. Freight stopped by weather or by the road counts in no price rule
    (section 6).
    - **(ours)** a truck does not leave the road: goods for a plant with no road wait.
    - Built by Terra. Reviewed by Bob.
  - **4.6b. Commuting:** how far a worker travels to a plant, at what time and fare (12.5, 39-40; `commuting.gd`
    still reads the old tables). Wilma named the risk that hired farm workers need homes at the spot.
    - Built by Terra. Reviewed by Maja.
  - **4.6c. Trucks ordered from their maker** (12.4, 32, Wilma's), like a contract with a delivery. The truck's
    record: its quality, set at making ("No improvements for trucks set quality stays"), its wear, breakdowns, and
    self-repair in about four months.
    - The landing stock's trucks stop being sold off the market. Colony Stores sells them cheapest-first today,
      against 12.4, 32.
    - Built by Otto, with the truck record agreed with Bob and Ella. Reviewed by Bob.
  - **4.6d. The carrier:** any company with trucks carries; a price per route by the three price rules (the rules
    above, with the route's original); the queue, oldest first, as section 7 says ("goes first the following month");
    rule 7's work and rule 8's capacity in freight.
    - The price and rules: built by Bob, reviewed by Otto.
    - The queue and its routing: built by Terra, reviewed by Bob. Anni proposed this move from the plan's list
      ("Bob ... freight"); Wilma approves it, and section 13's list changes with it.
  - **4.6e. Trade between areas:** an offer reaches buyers in other areas at its delivered price: price plus the
    cheapest carrier for the route (12.4, 30, Wilma's). The sale record says whether the goods are carried (50b).
    - Built by Bob. Reviewed by Terra.
  - **4.6f. The truck workshop:** bay work with a truck as the client; a repair at once that uses components and
    resets wear, with about 5% lost each time (Wilma's reading, recorded); the workshop's own trucks, of a quality
    from its workers' stress (the middle quality until stress comes at step 9, **ours**).
    - Built by Ella. Reviewed by Otto.
  - **4.6g. Carrying from and to the port,** and builders' supplies to the site (12.4, 31; 12.3, 25).
    - Built by Terra, on the same move as 4.6d's queue (Wilma approves). Reviewed by Otto.
  - **4.6h. The truck driver's and the truck workshop's grants** open with their types.
    - Built by Ella. Reviewed by Anni.
  - **4.6i. Road accidents with trucks** (L7): who pays when a rebuilt carrier's truck is in an accident.
    - Built by Anni. Reviewed by Terra.
- **The check:**
  - Test suite: a sale between areas carried and paid; freight waiting in the queue and carried first the next
    month; a truck ordered, worn, broken, repaired; a closed route.
  - Simulation, read:
    - freight waiting;
    - building sites waiting longer for their three months of supplies, since goods on the road are not on site (a
      result, Otto);
    - sales stopped by freight, counted in no price rule;
    - the first haulier and truck driver;
    - farms far from town paying for distance;
    - how far workers travel.

### Stage 4.7: farms away from towns, and the grant's spot (the user's marked item)

- **Needs first:**
  - 4.6, since the user said "Save it for when trucks and roads come";
  - 4.2, since the government commissions the road;
  - questions 1 and 2 are answered (below);
  - question 2b, the road owner's charge and access, is the user's when 4.7 comes up (4.7d).
- **Pieces, in order:**
  - **4.7a. The farm's siting:** away from towns, and around a spot for a granted farm (C1, C2). Terra's measure of
    "far away enough" is in C2.
    - The user, 2026-11-18, verbatim, asked whether farms paid wholly from savings still prefer land away from towns:
      "Yes!!! Also away from factories!! They polute!"
    - So every farm, granted or from savings, prefers land away from towns. A farm from savings is not sited at the
      government's spot (answer 4).
    - **New, for every farm:** farm siting also prefers land away from factories, because they pollute.
      **(ours, Terra's; starting numbers)** "Factory" is read from the type table, not from a list of type names.
      - Every plant whose row does not have "grows" (the column going in at step 3 for the season) counts against a
        nearby farm site, weighted by its row's pollution. So farms do not push farms apart, which would work against
        the grant's spot. A clinic barely counts; a power plant counts most.
      - A site held by a plan for such a type counts like a standing plant, so a farm is not put beside a power plant
        that is already signed.
      - The row's column is read, not the planet's pollution by area: pollution's effect on the ground is step 9, and
        a farm sited next to a new plant would see none yet.
      - The score part is near_pollution = - sum of (row pollution / 10) x (1 - d / R) over every such plant or plan
        within R. Here d is in tiles between tile centres, and R = 3 tiles (9 km).
      - So next door a power station (80) costs -8, processing (60) -6 and a mine (40) -4; two tiles away, a third
        of that. On the same scale as fertile +4 and road +3, a farm takes poorer land rather than sit next to a power
        station, but takes good land two tiles from a mine.
      - It is one part in the site's log row, like the others, so the choice can be traced.
    - Built by Terra. Reviewed by Maja.
  - **4.7b. The government picks its spots** (how many is its choice, each costs a road) **and asks** whether any
    company wants to build the road (C2, C3). The road itself is a 4.2 commission.
    - Built by Ella. Reviewed by Anni.
  - **4.7c. The spot becomes a settlement and an area** when its first farm stands. AreaStore founds an area on a
    country tile with no homes. Until step 7 it holds the farm families and nobody else (15e: the family on its farm
    needs no home).
    - Built by Maja. Reviewed by Terra.
  - **4.7d. A company's road to the spot, with its charge** (L1). The user, 2026-11-18, verbatim, asked whether the
    company's road with its charge comes now or later: "Do we build freight in this if we do then yes if not then
    no!" Freight is stage 4.6 of this step, so yes: it is built now.
    - Its charge and access, the link's owner fields, and the toll booked as the road company's revenue.
    - **The permission (Wilma's decision, marked as hers):** the government's offer at the grant is the permission.
      The user's answer 3: "that could come in planing of grants the government asks and if any company wsnts it".
      A company that takes the road on has been asked by the government, so no second licence procedure is laid on
      top: no objection period, no minister's or Cabinet's decision. road_law's old licence procedure is not used for
      this road.
    - A company road that nobody was asked for is not in the user's words, and is not built in step 4.
    - The charge and the access. The user, 2026-11-18, verbatim, asked whether the owner may refuse other carriers
      and whether its charge is free or capped by law: "No they can't refuse others but they can demand a toll, in
      wich case the ball is on the other side in wich case they can choose not to".
      - So the owner cannot refuse anyone its road. It may demand a toll, and each carrier then chooses whether to use
        the road and pay, or not.
      - The user's words set no cap and name no law for the toll, so none is written in, and no limit is added.
      - **(Wilma's reading, marked; the user said only "they can demand a toll")** The owner sets the toll by the
        plan's own price rules, as for any price.
      - road_law's old LAW_PRIVATE_TOLL_CAP (200%) and its access levers that let an owner refuse carriers are not
        used for this road. Anni, 4.7d.
      - A carrier's choice is ordinary freight routing: a route over the toll road costs the toll, and the carrier
        takes it or another route as the price says (4.6a, 4.6d).
    - Built by Anni (the law), Terra (the link) and Bob (the money).
    - Reviewed: Terra reads Anni's, Anni reads Terra's, Otto reads Bob's.
- **The check:**
  - Test suite: a granted farm sited at a spot; a farm from savings not; a road commissioned and built to the spot.
  - Simulation, read: where farms stand against the towns; the first year's food (Wilma's named risk), reported and
    not tuned; whether a spot grows a settlement.

### Old readers of the households that wake after step 4 (Maja; placed here so they are not lost)

- party_life.gd:818-840: parties weight by households from the old "hh" rows. It wakes with politics at step 8.
  Owner: Wilma or Ella.
- staff_ops.gd:135-140: the staff charge is shared over the pools by headcount. Rebuild-households M6 says the cost
  goes to a company that sells the service, or to the treasury until one exists. It wakes at step 8 (the parties'
  and the government's staff), or at step 9 with offices. Owner: Wilma.

### Read in every stage's simulation: the staffing loop (Bob)

The starting salary is twice the rent, while the needs line follows food. Step 4 adds power, water and other goods to
a household's needs (4.3c, 4.5b), so the needs line rises at every stage and hiring gets harder. This is already open
with the user. Each stage's report reads it and says what it saw; nothing is tuned for it.

### Who carries what (to see that nobody is the bottleneck)

| Session | Builds | Reviews |
|---|---|---|
| Bob | 4.1a, 4.1i, 4.2d, 4.3b, 4.3e, 4.4c, 4.5c, 4.6d (price), 4.6e, 4.7d (money) | 4.1b, 4.1c, 4.2a, 4.2h, 4.3a, 4.3c, 4.4b, 4.5a, 4.5b, 4.5d, 4.6a, 4.6c, 4.6d (queue) |
| Otto | 4.1c, 4.2a, 4.2b (contract), 4.4b, 4.5a, 4.6c | 4.1a, 4.1i, 4.2b (bill), 4.2c, 4.2g (contract case), 4.3e, 4.4c, 4.5c, 4.6d (price), 4.6f, 4.6g, 4.7d (money) |
| Maja | 4.1j, 4.3c, 4.4a, 4.4d, 4.4e (companies), 4.4h, 4.5b, 4.5d, 4.7c | 4.1f, 4.1i, 4.2d, 4.2g (staff), 4.3a, 4.4b, 4.4e (crime), 4.4f, 4.5c, 4.6b, 4.7a |
| Ella | 4.1d, 4.2e, 4.3d, 4.4f, 4.4g (outlet), 4.4i, 4.5e, 4.6f, 4.6h, 4.7b | 4.1e, 4.1h, 4.2c, 4.2f, 4.4g (fee), 4.4h |
| Terra | 4.1g (Site), 4.2b (bill), 4.6a, 4.6b, 4.6d (queue), 4.6g, 4.7a, 4.7d (link) | 4.1c, 4.1g (law), 4.2b (contract), 4.2e (roads), 4.3b, 4.3c, 4.4a, 4.4d, 4.5b, 4.6e, 4.6i, 4.7c, 4.7d (law) |
| Anni | 4.1e, 4.1f, 4.1g (law), 4.1h, 4.2g, 4.2h, 4.4e (crime), 4.4g (fee), 4.6i, 4.7d (law) | 4.1d, 4.1j, 4.1g (Site), 4.2e, 4.3d, 4.4e (companies), 4.4f, 4.4g (outlet), 4.4i, 4.5e, 4.6h, 4.7b, 4.7d (link) |
| Wilma | 4.1b, 4.2c, 4.2f, putting each stage together, the base simulations | each stage's report |
| Each owner | 4.5f, in their own files | their pair |

---

## A. The types with work slots: services, shops, utilities on the grid (Ella)

### A1. A service sells client places, not an item

- **The user's words:**
  - "services have no output but a client take in" (section 4);
  - "They have empty work slots" (section 4, what rules 2 and 4 read);
  - "per pulpe plus staff is how taxes for schools are calibrated Yea they all get tax brackets" (9.5).
- **The plan:** 12.6, 43-48 **(Wilma's)**. A household is a client of the nearest service of the kind that it can
  pay for and that has a free place within reach: school 1.5 km, clinic 2 km, on the town grid. Each person who needs
  it is one client. What being served does is set by service: a clinic lowers deaths, a school sets a child's skill,
  childcare lets parents work, elder care lowers deaths of the retired, police lowers crime.
- **What exists:**
  - the service rows in type_table.gd: client intake per full unit, inputs, labour, and reach_m for the clinic and the
    school;
  - `TypeTable.clients()`;
  - a `slots` field on every company, never filled;
  - Site.choose_town reads clients for siting.
  - Nothing serves a client. Making.month skips every non-item line.
  - Rules 2 and 4 have no empty-slot reading for services. Builders have one of their own: crews.
- **What is missing:**
  1. **Filling places:** each month, households take places at the nearest service within reach that has room and
     that they can pay.
  2. **What serving does,** one effect per service as listed above.
  3. **The price rules on places:** rule 1 counts clients turned away, rules 2 and 4 count empty places.
  4. **A service's making price** per client place.
  5. **Logbook rows** for each.
- **Whose:**
  - the place-taking on the household side: Maja (people and public services);
  - the private services (shop, café, service hub, newspaper, and private childcare or elder care): Ella (services);
  - the price and output rules on slots: Bob (the rules).
- **(ours)**
  - A client place is held for a month and paid for that month.
  - A household that finds no place within reach goes without that month and is counted as unserved. That count is
    the service's rule 1 signal and the press's figure.

### A2. Who pays for a public service before taxes exist

- **The user's words:** "Yea they all get tax brackets" (9.5). Taxes and brackets are step 8 (section 13).
- **What exists:** landing.gd's purse pays every state company what its own account lacks for the month's wages
  (memo STATE_WAGES).
- **What is missing:** the costs of a public service other than wages (its inputs: energy, water, medical) have no
  payer.
- **(ours)** Until step 8, the purse covers a state service's whole month, inputs as well as wages, the same way it
  covers wages now. The fee at the door stays at nothing (12.11, 100). Step 8 replaces this with the bracket.

### A3. The shop

- **The plan:**
  - 12.6, 48 **(Wilma's)**: "Shops, cafés and the like are service companies with a client intake, so every line of
    household spending has a seller."
  - rebuild-type-table section 5 **(Bob's, "for Wilma to confirm")**: a shop buys wholesale on the market and posts its
    own price for each item within the town grid's reach of homes. Its rules 2 and 4 read its unsold stock.
- **What exists:**
  - the SHOP row, way IN_REACH;
  - `Company.offer`, which lets a shop open a price for any item;
  - the government's "Colony Stores" (a state SHOP), which sells the landing stock.
- **What is missing:**
  - households buying from the seller within reach, not from any seller in the area;
  - shops reordering what they sell.
- **Whose:** Bob (the market), with Maja for the household side.
- **For Wilma:** confirm Bob's reading. It is not a question for the user.

### A4. Utilities on the grid

- **The user's words:**
  - "All company types needs to be able to be created as private, but maybe they're is only ever enough work for say
    one powerplant then the conitions for new ones don't get switched on" (9.5);
  - on the order of paying: "what are you paying power and water on if you can't pay the rent?" (9.1).
- **The plan:**
  - 12.7, 49 **(Wilma's)**: power and water reach the buyer through the grid and cannot be stocked. A private
    utility prices by the rules; a state one proposes and the government approves.
  - 12.11, 104 **(Wilma's)**: when power or water runs short, water is served before power, and homes, farms and
    clinics before other users. An outage is published.
- **What exists:**
  - the POWER and WATERWORKS rows;
  - ENERGY and WATER marked "grid";
  - the state subsidiaries Colony Power and Colony Water, with no plant and no staff;
  - the old GovBuilder._tariff_proposals, which is not called in the rebuild.
  - There is no grid. Rebuild-type-table's notes 1-2 **(Bob's)**: every goods row except the farm takes energy and
    water, so it cannot run until the grid exists.
- **What is missing:**
  - the grid itself, a built network (the user: "Gridd"; 4.3a);
  - selling ENERGY and WATER to the buyers the grid reaches, with the shortage order of 104;
  - the state utility's tariff proposal and the government's answer;
  - households paying for power and water third, after food and rent (9.1).
- **Whose:** the plan names no owner for the grid.
  - **(ours)** Terra for the grid's shape (the ground and the map).
  - Bob for selling on it (the market).
  - Ella for the government's answer to a tariff (the government's decisions).
  - Maja for the household line.

### A5. The government commissions what the state builds

- **The plan:**
  - Section 10: "The state acts: order a building, a road, a repair ... one action entry per act".
  - 12.6, 47 **(Wilma's)**: a state service's rules propose a new plant or a closure; the government decides and
    commissions.
  - 12.11, 99: the public works department builds at cost when the government tells it to.
  - 12.11, 102: securing the essentials.
- **What exists:**
  - The government cannot commission anything in the rebuild. `EconFace.actions_enqueue` is a stub that answers
    "There is no economy yet". `GovBuilder.monthly`, which held the old commissioning, essentials and tariff logic, is
    called by nobody.
  - Building.gd knows one kind of contract only, NEW_PLANT, with a plan as the client.
  - So Colony Power, Colony Water, the clinic, the school, transit and police can never get a plant.
- **What is missing:**
  - a contract whose client is the state, paid from the purse;
  - the commissioning act;
  - the state company's own rule 7 as its proposal;
  - the AI government's answer to it, each with its Logbook row.
- **Why it comes first:** without it, step 4 has no grid, no public services and no road to the farm spot. It goes
  before everything else in step 4.
- **Whose:**
  - the act through the doorway: Wilma;
  - the contract with a state client: Otto;
  - the AI government's decision: Ella.
- **(ours)** The AI government says yes when the purse can pay the estimate and the proposal's rule 7 passes. The
  player decides for themselves.

### A6. To watch: the first chain of inputs

The landing stock holds FOOD, MATERIAL, COMPONENT and TRUCK. It holds no MINERAL. POWER needs MINERAL; the MINE needs
ENERGY and WATER; the WATERWORKS needs ENERGY. So the first power plant can only run on mineral ordered from the home
world with a ship in port (9.6). That is the plan's own path (12.11, 102), not a fault. It is written here so the first
step-4 simulation's report expects it.

---

## B. The founding of every company type (Ella)

### B1. Every type can be founded

- **The user's words:**
  - "All company types needs to be able to be created as private ... then the conitions for new ones don't get
    switched on" (9.5);
  - rule 7: "the average of all available work: instead of reading the leftovers, they read an avrage of all avaliable
    jobs" (section 6);
  - 2026-11-18, about builders: "Nothing they are shut gone dead, this is where opening of new companies comes in"
    (rebuild-building 4.6).
- **What exists:**
  - `month.gd FOUNDABLE = ["FARM"]` ("tested first on food alone"). The audits record it as built differently from 9.5:
    Bob D33, Anni 7.
  - `Rules.work` returns 0 for every type that sells no item. So even with FOUNDABLE widened, no service, builder,
    haulier or truck workshop would ever see work.
  - The founding sequence itself (rules 7 and 8, founder_needs, the grant quote, the founder draw, the site, the plan)
    takes any type.
- **What is missing:**
  1. FOUNDABLE becomes every type. With this, no type is named in the conductor.
  2. **Rule 7's work for each way of selling.**
     - Items: built.
     - Client places: the clients who came for a place within reach, served or turned away, at today's price. The
       turned-away clients are the ones counted in A1. **(ours, as the reading of "all available jobs")**
     - Building work: at least the BW of the plans listed in the market and not claimed, at today's price (see
       4.1a). **(ours; Otto's correction: it is not the price signal's count, which per 15c reads only open jobs)**
     - Freight: the freight ordered (part D).
     - Rule 8's capacity is what the standing companies of the type deliver, as for items.
  3. **Types whose market comes at a later step** (the bank at step 5, the landlord at step 7, the office block at
     step 9): rule 7 runs for them and reads 0 work until their market exists. **(ours: the plan's "no rule is skipped
     for a type because it cannot take effect today")**
  4. **State types.** A private one appears beside a state one only when rules 7 and 8 say so (9.5). The state
     company's own rule 7 is its proposal (A5).
  5. **The family size** of a service is the old self-employed (12.5, 36). It is founded like any family company.
- **Whose:**
  - rule 7's work by way of selling: Bob;
  - the plans and contracts: Otto;
  - the founder draw: Maja;
  - siting in town: Terra;
  - FOUNDABLE in the conductor: Wilma;
  - the three other grants (bakery, truck driver, truck workshop), which open with their types: Ella.

### B2. New builders

- **The user's words** (2026-11-18, verbatim, rebuild-building 4.6):
  - "All of this is pointless they have no 3mploees and should have shut";
  - "Nothing they are shut gone dead, this is where opening of new companies comes in, also the communal builder owned
    by the government that goes down to one or two but never empty of employees".
- **The plan:**
  - Section 3: "A company founded in the colony does not exist before its plant opens." The five home-world builders
    are the exception: "they arrive ... already operating ... and need no building in order to exist".
  - The BUILDER row has a bill, 120 BW and 2 months.
  - 12.11, 99: the public works department builds only when the government tells it to.
- **What exists:**
  - A builder left with nobody ends for good. The plan's words are in commit 4dce272; Otto's code for the ending is
    merging after Bob's and Maja's.
  - Building.builders(for_hire) leaves the public works department out of what a plan can hire.
  - Nothing founds a builder.
- **What is missing:**
  - a builder's rule 7 (B1, 2);
  - its plan, its yard built by a builder, its opening and its hiring.
- **The gap the user has now closed** ("They build it"; 4.1c): when every private builder was dead, a new builder's
  yard had nobody to build it, because the public works department took no plans. Now the public works department
  builds it (Wilma's reading).
- **Whose:** Otto (building), Bob (rule 7).

---

## C. The marked item: farms away from towns, and a grant's spot that grows into a town (Ella)

**The user's four answers** (2026-11-17, verbatim, section 13): "1 . Far away wnough that a few years of development
wont merge them, 2. Upp to the goverment, but since they pay for the road, more spots would be more expencive for them.
3. Most comonly the government but if a company out a collective wants to they should be able to, that could come in
planing of grants the government asks and if any company wsnts it but that would cost but they would be free to charge
for using it 4. No farms payed fully from saving does not"

### C1. The preference: farms away from towns

- **What exists:** `Site.choose_country` scores every free tile by minus its distance to the nearest settlement. So
  the best farm site is the one CLOSEST to a town, the opposite of the user's preference. Anni's audit, row 40, says
  the same.
  - Wilma's view in section 13 ("farms are already scored away from homes") does not match the code. Farms only miss
    the "next to homes" bonus that other types get.
- **What is missing:**
  - the farm's score turned to favour distance from towns;
  - for a farm going to the government's spot, a score around the spot.
  - Who the preference covers is question 1.
- **Whose:** Terra (siting).

### C2. The spot

- **The user's words:** answers 1, 2 and 4 above.
- **What exists:**
  - The grant has a "where": `GovBuilder._grant_cover` picks the districts or areas a programme covers. Grants.quote
    refuses a founder outside them.
  - The founding order quotes the grant before the site is chosen, so the order already lets the site follow the
    grant.
  - Areas grow from where things are built (rebuild-households, Maja).
- **What is missing:**
  1. **The government picks its spots** when it opens or renews a farm programme. How many is its own choice
     (answer 2), and each spot costs it a road.
  2. **Each spot is far enough from every town** that a few years of growth will not merge them (answer 1).
     **(ours: Terra's measure; "three years" is a starting number)**
     - "Merge" is what the code merges: two town grids touching.
     - The gap is measured on the 100 m town grid, from a town's outermost laid cell to the spot, in km.
     - A town's growth is its equivalent radius, sqrt(laid cells x 0.01 km2 / pi), now less three years ago. TownGrid
       keeps a small yearly record of laid cells. A town with under three years of record is read over the months it
       has, scaled to three years, with no floor.
     - The gap must be at least the town's three-year growth plus the spot's own, taken at the same rate since the
       spot has no history. That is why it is doubled.
     - The test is made against every settlement and every other spot, not only the nearest town.
  3. **A granted farm is sited at or around a spot.** A farm paid wholly from savings is not (answer 4).
  4. **The spot becomes a settlement and an area** when its first farm stands, so business and housing can follow
     ("then that center soot can start getting buisness and then their own housing sectors"). Shops, services and
     housing come at step 7 (Wilma's staging, section 13).
- **(ours)**
  - A granted farm may plan and sign at once. It does not wait for the road. Until the road reaches it, its food
    waits for freight like any farm off the roads.
  - Wilma named the risk that the first year's food is tight. That is a result to report, not to prevent (section 13,
    "No tuning around a missing part").
- **Whose:**
  - the government's choice of spots and its cost: Ella (the government's decisions, the grant's cover);
  - the distance measure and the siting: Terra;
  - the new area: Maja.

### C3. The road to the spot

- **The user's words:** answer 3 above.
- **The plan:**
  - 12.4, 33 **(Wilma's)**: "Private roads and tolls are left out for now."
  - 12.12: left out for now: "private roads and tolls".
  - The user's answer 3 lets a company build the road and charge for its use. That is a private road with a toll.
    Which one stands at step 4 is question 2.
- **What exists:**
  - the road network and the old road works code (Terra's; `GovBuilder._road_needs` and the others are not called);
  - design-private-roads-transport.md and design-law-private-roads.md from the old game.
  - No road can be commissioned in the rebuild (A5).
- **What is missing:**
  - the government's road to each spot, commissioned (A5) and built by a builder;
  - "the government asks" when the grant is planned: an offer that any company may take;
  - the company's road and its charge: in step 4 (the user: "Do we build freight in this if we do then yes"; 4.7d).
- **Whose:**
  - the road: Terra;
  - its contract: Otto;
  - the government's ask and its choice: Ella;
  - the right to charge: Anni (the law's hold).

---

## D. All items, freight and trucks, the law's hold

### D-items and D-freight (Ella's draft from the plan; Anni corrects it in place once her readers' claims are checked)

**D1. All items have a market**
- **The user's words:**
  - "it's just a 2d array of wich items a company type makes, if they pick from first or second output" (section 4);
  - "Food is an item like any other" (section 4);
  - "Company and people should be able to stock up if the price is low" (9.3).
- **What exists:**
  - every item in `TypeTable.ITEMS`, with its unit, freight mass and spoiling;
  - one order book per item and area (market.gd);
  - `Making.post_orders`, which already orders every non-grid input of any open item-maker, at its worth, with
    stocking up;
  - spoiling per item.
  - Households order FOOD only (`NEED_PER_PERSON = {"FOOD": 1000}`).
- **What is missing:**
  - households' lines for the other goods: consumer goods, clothing, furnishings, medical, and bread with the bakery
    preferred (9.1, money out: "the other essentials; then ... consumer goods, services, comfort spending,
    newspapers and saving");
  - rule 3 picking the first or second output ("Also picks first or second output", section 6). Today a company keeps
    line 0.
- **Whose:** the household lines, Maja; rule 3's pick, Bob.
- **(ours, Maja to propose)** The split of what is left after the essentials over goods, services, comfort,
  newspapers and saving. The user has not given it.

**D2. The truck is ordered from its maker, not bought off the market**
- **The plan:** 12.4, 32 **(Wilma's)**: "A truck is ordered from its maker, not bought cheapest-first off a market.
  The buyer chooses the maker by price and quality."
- **The user's words** (design-truck-drivers.md, 2026-11-16, verbatim):
  - "Also trucks for this should be able to be built at the component workshop as special orders";
  - "No improvements for trucks set quality stays";
  - "Yes they ware, yes and no the components ones are always lowest quality workshops make different depending on
    ware and quality of parts";
  - "Then leave it at workers are they stressed out not maybe they can add more parts to make better trucks".
- **What exists:**
  - TRUCK as an item, made by COMPONENTS (second line) and TRUCKSHOP (second line);
  - 20 trucks in the landing stock;
  - a `fleet` field, never written.
- **What is missing:**
  - a truck order with its maker (an order book like a builder's, not the market's clearing);
  - the truck's record: its quality, set at building, and its wear.
- **Whose:** as in part S (4.6c): Otto builds the order with a maker and the truck record, agreed with Bob and Ella.
  Design-truck-drivers (2026-11-16, before the rebuild) gave the trucks to Bob; this move is ours, to keep freight off
  one desk.

**D3. Freight: the delivered price, the queue, carriers' prices**
- **The user's words:**
  - "the same company can become freight" (section 7);
  - "count the work que not passed work"; on the queue, "That works" (section 7);
  - "If something else than price stops sales it should not count on adjusting price!!" (section 6).
- **The plan:**
  - 12.4, 30 **(Wilma's)**: a carrier posts a price per route, by the same three price rules. A buyer ranks offers
    by price plus freight. The sale is made before carrying, and goods on the road are the buyer's.
  - 12.4, 31: a builder's supplies are delivered to the site by freight.
  - 12.8, 50b: one sale record that says whether the goods have been carried.
  - 12.3: goods waiting for freight are not unsold.
- **What exists:**
  - market.gd ranks by posted price ("no freight in step 3, so delivered = posted");
  - offers already leave out stock "waiting" for freight, a field that is always 0;
  - the HAULIER row (freight room 20 a truck, 6 trucks);
  - Terra's old `freight_roads.gd`: route room, truck traffic on links, jams. It is keyed by the old districts. Its
    `on()` returns true (corrected from Anni's reading: its header still says "opt-in"), but nothing in the economy
    calls it, so it carries nothing;
  - `Transport.route` (Terra's kept code): km, time and cost between network nodes;
  - the market is per area: `Market.offers` skips any seller in another area, so no trade between areas exists yet;
  - a carrier has one freight price under the key "FREIGHT" (company.gd), not one per route;
  - imports skip the road: `Ship._deliver` puts them straight into the buyer's stock.
- **What is missing:**
  1. **The delivered price:** a buyer ranks offers by price plus the cheapest carrier's price for the route.
  2. **Carrying:** after the sale, goods move by the carriers that have room. What does not fit waits in the queue and
     goes first the next month.
  3. **The carrier's price per route** by the three price rules, read on its empty room (EMPTY_SLOTS, as the HAULIER
     row says). Rule 7's work for freight fills 4.1a's 0.
  4. **Any company with trucks carries** its own goods or others'.
  5. **The roads carry it:** route room and travel time on the rebuilt areas, from Terra's freight_roads made to
     read areas and switched on for good. There is no off switch: "No fixes behind off switches".
- **Whose:** as in part S (4.6a, 4.6d, 4.6e):
  - the delivered price and the carrier's price: Bob;
  - the routes, the queue and its routing: Terra. The queue's move from the plan's list ("Bob ... freight") is Anni's
    proposal, for Wilma to approve.

**D4. Trucks wear and are repaired; the truck workshop**
- **The user's words:**
  - section 7: "if you're truck breaks down you can fix it yourself in about 4 months or drive to a workship and have
    it fixed now";
  - section 7: a workshop repair "Uses components and resets wear, about 5% are lost reach time". Wilma's reading
    (design-truck-drivers) is that each repair brings the truck back to about 5% less than the time before.
  - Workshop trucks: quality follows the workers' stress (above).
- **What exists:** the TRUCKSHOP row (repair line and truck line), a service type.
- **What is missing:**
  - wear and breakdowns by quality and age;
  - a self-repair taking about four months;
  - a workshop repair at once, using components and resetting wear, with the 5% loss;
  - the workshop's clients are trucks;
  - a workshop truck's quality from its workers' stress.
  - Stress is step 9. **(ours)** Until then a workshop's trucks are built at the middle quality, and stress replaces
    that at step 9.
- **Whose:** as in part S:
  - wear and breakdowns on the truck record: Otto (4.6c);
  - the truck workshop: Ella (4.6f; design-truck-drivers: "Ella builds the truck workshops").
- **(ours)** How quality turns into breakdowns, and the rate of wear. These are starting numbers Bob and Ella
  propose, labelled.

**D5. The grants for truck drivers and truck workshops**
- **The plan:** 9.5: "Truck drivers and truck workshops are separate grant types ("No split trucks and workshops")".
  12.9, 61b: each grant's sum is set from how many of each the government wants **(Wilma's reading)**.
- **What exists:** `Grants.KINDS` holds TRUCKER and TRUCKSHOP, each family size. `Grants.wanted` gives one per area
  that has none **(Wilma's reading)**.
- **What is missing:** nothing beyond founding these types (4.1b) and the government deciding their programmes. The
  existing code covers both, once the types can be founded.
- **Whose:** Ella. The political side, as Wilma's design-truck-drivers lists it, is Wilma's.

### D-law (Anni, read in the shared tree after the 61c and benefit merges)

**L1. A road built and owned by a company, and charging for its use**
- **The user's words:**
  - answer 3 (above);
  - 2026-11-15, in road_law.gd's header: "private roads, bought and paid for by companies".
- **Against it in the plan:**
  - 12.4, 33 **(Wilma's)**: "Private roads and tolls are left out for now";
  - 12.12;
  - law-face 12 (Anni's): road_law stays and is dormant.
  - The user's answer 3 is the same age as these or newer.
- **What exists:**
  - `road_law.gd`: the licence, objection window, access and toll readers, maintenance duty, neglect, step-in,
    revocation;
  - the levers LAW_PRIVATE_ROADS, LAW_PRIVATE_ROAD_ACCESS and LAW_PRIVATE_TOLL_CAP (200%);
  - Terra's `private_roads.gd`: the owner, the regime, the toll, the build cost.
  - Both sit behind flags that are off in every game.
- **What is missing:**
  - the grant's road offered to companies ("the government asks");
  - a company taking it on, paying for it and owning it;
  - its toll booked as revenue;
  - the plan line letting private roads back in.
- **Whose:**
  - the law's hold: Anni;
  - the link and owner fields, and the route cost: Terra;
  - the money: Bob;
  - "the government asks": Ella.
- **(ours)** Every number in road_law is old design, not the user's.

**L2. The public road toll**
- No words from the user. Law-face 11: no charge until step 8. `road_toll` defaults to 0, and its only reader is off.
- **Missing for step 4:** nothing.

**L3. Licences when more types are founded**
- **The plan:**
  - 12.10, 66 **(Wilma's)**: licences "work as before";
  - build order step 6: "permits and licences";
  - law-face 2 (Anni's): "Until step 6: every plan and plant is lawful as it stands, with no permit, licence or fee."
- **What exists:** `LawCompany.licences_required` demands HAZARD for MINE, PROCESSING, MEDWORKS and POWER, and
  EXTRACTION for MINE, because both regimes default to REQUIRED. `may_sign` makes a plan wait for the licence, and
  `may_open` closes a plant without one.
- **This is built differently from the paper.** It is unseen only because FARM alone is founded. At step 4 it would
  hold the first power plant in the permit office's queue.
- **(Ella, folding in)** That is a fault against law-face 2 and the build order, to fix, not a question. Licences
  wait for step 6 as the paper says. Anni's question 3 is therefore not sent to the user.
- **Whose:** Anni, in law_company.gd. Reviewed by Ella.

**L4. Building permits:** step 6 on paper; nothing asked today. **Missing for step 4:** nothing.

**L5. Zoning for the new types:** `ZONE_USES` and `use_of` cover every type. The 61c colony zone INDUSTRIAL stops
farms only. **Missing:** nothing. It can sit anywhere in the order.

**L6. Workplace accidents**
- **The plan:**
  - 12.10, 69 **(Wilma's)**: "An accident at work is the company's to pay for";
  - law-face 5.3: at step 3 accidents are counted and nobody pays.
- **What exists:** the type table's `accidents`, which no code reads.
- **When it matters:** the dangerous types arrive at step 4.
- **Whose:** Anni, with Bob for output and staff.

**L7. Road accidents:** 12.4, 33: road safety is on. `RoadSafety.on` is true, and cases are filed.
- **Missing:** who pays when a rebuilt carrier's truck is in an accident. Today the treasury or a road company pays
  the victims' fund.
- **Whose:** Anni, reviewed by Terra.

**L8. Police stations and prisons as state service companies**
- **Law-face 12 (Anni's):**
  - police and prisons are state service companies at step 4;
  - "Crime reads the households ... from step 3";
  - until step 4 police strength comes from the lever.
- **What exists:**
  - the POLICE and PRISON rows;
  - crime and police are opt-in and off in a rebuilt game. That is built differently from "from step 3";
  - `crime._station_hours` reads `EconFace.police_hours` and falls back to the lever;
  - prisons are opt-in.
- **Missing:**
  - a police company's staff counted as officers;
  - prisoners as a prison's clients;
  - crime switched on for good.
- **(Ella, folding in)** Crime being off differs from Anni's paper (law-face 12), so it is fixed, not asked. It goes
  in at 4.1f, on its own, so its effect can be read before police come at 4.4e.
- **Whose:** the police and prison companies, Maja (public services); crime, the court and sentences, Anni.

**L9. Newspapers as companies**
- **The plan:**
  - 12.6, 48 **(Wilma's)**: a newspaper is a company whose clients are its readers;
  - law-face 12: the press licence "becomes a licence with a fee, never refused for being a newspaper", and the
    ownership cap stays;
  - 9.2, the user: "costs of hiring, articles in the newspaper".
- **What exists:**
  - the NEWSPAPER row;
  - media's outlets are objects of their own, not companies;
  - `media_ops.gd:1661`: under LICENCE "the government licenses only owners not opposed to it". That differs from
    law-face 12 read with 12.10, 65 ("No law may forbid a company type from being private; it may only make it
    dearer");
  - advert money goes to the state Gazette.
- **Missing:**
  - the outlet as a rebuilt company;
  - the licence fee;
  - adverts paid to the paper.
- **(Ella, folding in; corrected on Anni's read)** The refusal does not forbid the type, so 12.10, 65 does not decide
  it. "Never refused for being a newspaper" is Anni's paper, not the user's words. It takes a political lever away,
  so it is Wilma's to decide (E2). Until she rules, 4.4g builds the fee and the adverts only.
- **Whose:** the outlet as a company, Ella; the press law, Anni.

**Anni's questions, and where they went:**
- **Anni's 1** is the same as Ella's question 2. It is asked once.
- **Anni's 2** (whether the toll is capped by law, and whether the owner may refuse other carriers) only matters if
  question 2 says "now". It is asked with it, as 2b.
- **Anni's 3, 5 and 6** are the paper against the code: faults to fix (above).
- **Anni's 4** (do accidents cost the company at step 4, or are they only counted until the court at step 5?) sits
  between two of Wilma's decision lines, 12.10, 69 and law-face 5.3. It goes to Wilma, not to the user.

---

## E. Questions: for the user, for Wilma, and the ones the plan already answers

### E1. For the user

**Answered, 2026-11-18** (verbatim, in the order Wilma put them; recorded in MASTER-PLAN; placed at their stages):
- New builders (4.1c): "They build it". Wilma's reading, told to the user: the public works department builds a new
  builder's yard.
- The grid (4.3a): "Gridd". The grid is built, with lines to each place.
- Farms from savings (4.7a): "Yes!!! Also away from factories!! They polute!" Every farm prefers land away from towns
  and away from factories.
- The company road (4.7d): "Do we build freight in this if we do then yes if not then no!" Freight is in step 4, so
  the company road with its charge is built now.

- The road's charge and access (4.7d): "No they can't refuse others but they can demand a toll, in wich case the
  ball is on the other side in wich case they can choose not to". The owner cannot refuse others; it may demand a
  toll; the carrier chooses. No cap or law is written in.

**No question of the user's is open in this plan now.**

### E2. For Wilma: section 12 decisions, ours to settle (not sent to the user)

Each one stands at the stage that needs it, and is settled before that stage's piece starts.
- **4.1g, the land price for every type.** Decided by Wilma: one land price per place, the same for every type
  (4.1g).
- **4.2, the government's money before step 8** (Maja's trace: about 694 credits a month in, under 1% of the
  benefit paid). Every state piece of step 4 leans on it. One answer to weigh is the home world's development grant
  (12.11, 90). If the order of steps moves, it goes to the user.
- **4.2h, accidents at work.** Do they cost the company at step 4, or are they only counted until the court at step
  5? 12.10, 69 and law-face 5.3 differ (Anni's law 4).
- **4.3e, the import rule.** When a company orders from the home world. 9.6 sets only the limit, a ship in port and a
  full round trip; `Ship.order` has no caller (Bob).
- **4.4g, the press licence.** May it still refuse owners opposed to the government, or is it a fee only (Anni)?
- **4.5d, company stock spoiling.** The user's words do not decide it (Anni): "No it's for all goods" was said of the
  price climb.
- **4.6d and 4.6g, the queue and the port carrying with Terra:** a move from section 13's list, which changes with it.
- **4.7d, the licence for a company road to the spot.** Decided by Wilma: the government's offer at the grant is
  the permission, and road_law's licence procedure is not used for that road (4.7d).
- **4.6, a plant's road connection.** 12.1, 5 (Wilma's): "A plant pays for its road, power and water connection as
  a home does". Not built; in or out at step 4 (Terra).
- **4.5, the shop.** Bob's reading: a shop resells goods within reach, and households buy through it (A3; Anni's
  items 6 and 7). Bob asked for Wilma's answer; none is recorded.
- **4.5, the landing stock.** Its fixed starting price holds colony makers of the same good down while it lasts. Bob's
  review calls that a result (Anni's items 17).
- **4.5 and 4.3, starting numbers.** What a person needs of each good; the split of what is left; whether power and
  water are paid by use; how many months of a hard season a family puts away. The last was said as a "maybe" (15e),
  so it is not built unless Wilma rules it in. (Anni's items 1, 2, 11.)
- **4.6, freight.** Whether the queue is one per route or one per carrier; what a route is (a pair of areas is
  ours); whether freight applies inside one area; how many workers a truck needs; rule 7's work for a carrier (the
  freight ordered is ours); whether the truck grants read a freight need or "one per area" as built. (Anni's freight
  1, 4, 5, 14, 20, 21.)
- **4.6, trucks in the landing stock.** Wilma decided 20; Otto had marked it for the user. Wilma says whether it
  stands (Anni's freight 8).

### E3. What the plan or the user's words already answer (not asked again)

| Question (Anni's) | The answer, and where it stands |
|---|---|
| Freight 2: what goes first in the queue | the oldest: "goes first the following month" (section 7) |
| Freight 3: who pays the carrier | the buyer: buyers rank by price plus freight, goods on the road are the buyer's (12.4, 30, **Wilma's**) |
| Freight 6: does the climb cap apply to freight | yes: "No it's for all goods" (section 6) |
| Freight 7 and items 9: trucks off the market | 12.4, 32: ordered from the maker. The code selling them off the market is a fault, fixed in 4.6d |
| Freight 11: "about 5% are lost" | Wilma's reading is recorded (design-truck-drivers); built so |
| Freight 12: "maybe ... more parts" | an idea, not a ruling (design-truck-drivers); not built |
| Freight 13: who builds the workshop | Ella (design-truck-drivers, 2026-11-16, and "services") |
| Freight 15 and law 1 | the user's question 2 |
| Freight 16: how "a few years" is measured | ours, Terra proposes (C2) |
| Freight 17 | the user's question 1 |
| Freight 18: do the first spot farms wait for the road | ours: no (C2), reported as a risk |
| Freight 19: imports carried from the port | yes: "a company ships from where its plant stands to where the buyer is" (section 7); port stock waits for freight (12.3, 25) |
| Freight 22: the old roads' numbers | set new: "None of the code or numbers carries over" (section 11) |
| Items 3: food or bread | the households prefer bread (section 11's placement table, **Wilma's**: "the preference is the households'"); how much is ours |
| Items 4: stocking up on other goods | yes: "Company and people should be able to stock up if the price is low" (9.3). The six-month store is food's own ruling |
| Items 5: the government's stockpile | marked for when politics is taken up (step 8); not now |
| Items 10: seasons beyond food | from the "grows from the land" column ("Good, those"), not by name; Terra is building it at step 3 |
| Items 12 and 13: switching lines | ours, proposed with 4.5a |
| Items 14: which types open, in what order | every type, by rule 7: only where work is read (4.1) |
| Items 16: services buying inputs | yes, on the same market and by the same rule (4.4b) |
| Items 18: everyday imports | yes, limited only by the ship: "That is the whole limit" (9.6) |
| Items 15: no goods chain before the bank | the user: placeholder loans, for starting only (4.1i) |
| Law 3: licences at step 4 | no: lawful until step 6 (law-face 2, **Anni's**; the build order, **Wilma's**). The code differs, fixed in 4.1e |
| Law 5: crime at step 4 | on: "Crime reads the households ... from step 3" (law-face 12, **Anni's**). The code differs, fixed in 4.1f |

## What changed in this draft, and why

**First draft (after Anni's three readings)**
1. Part D was filled from Anni's readings of the law, freight and items. The full readings are kept beside this
   file: rebuild-step4-law-reading.md, rebuild-step4-freight-reading.md and rebuild-step4-items-reading.md.
2. Anni's 46 questions were sorted. Some went to the user, some to Wilma (E2), and the rest are answered by the
   plan (E3).
3. Corrected: freight_roads.gd is not behind an off flag; its `on()` returns true. It carries nothing only because
   nothing calls it.

**Second draft (after every session read the whole)**
1. **Rule 1, rule 4 and the rise cap, as the user now words them,** are written once for every new way of selling
   (Bob). The draft still described rule 1 the old way. A place's or a route's price would have had no original,
   so it would have climbed with no cap.
2. **The builders' work for rule 7 counts the plans listed and unclaimed** (Otto). Signed work is 0 exactly when
   every builder is dead, so no builder could ever be founded.
3. **A builder left with nobody ENDS; the public works department never goes below two** (Otto: today's ruling).
4. **At step 4 a commission goes to the public works department, at cost.** It hires up for the job (Otto).
5. **The road contract moved from 4.7 to 4.2,** with roads to the plants standing off the network before freight is
   turned on (Terra). Otherwise food would fall at 4.6 for a reason that is not 4.6's.
6. **The government's money before step 8 now blocks 4.2** (Maja's trace: the purse takes in about 694 credits a
   month). As written, 4.2 would have commissioned nothing. It is in E2.
7. **The import rule now blocks 4.3** (Bob: nothing calls `Ship.order`, so Colony Power would never get mineral).
   It is in E2.
8. **The purse paying a state company's inputs is a piece,** 4.2f, Wilma's (Bob).
9. **The orders inside 4.5 and 4.6 were fixed** (Otto, Bob, Terra, Maja): routes, then trucks, then the carrier,
   then the delivered price; the shop before households buy goods.
10. **Added:**
    - crime on its own, at 4.1f (Anni);
    - the land price for every type, at 4.1g (Anni);
    - fines on real revenue, at 4.1h (Anni);
    - the law's side of state contracts and staff, at 4.2g (Anni);
    - accidents at work, moved to 4.2h, since POWER is the first hazardous plant (Anni);
    - commuting, at 4.6b (Terra);
    - weather on routes, in 4.6a (Terra);
    - the grid's pieces under both answers to question 3, in 4.3a (Terra);
    - sickness, at 4.4h (Maja);
    - the order of paying with the food store, in 4.3c (Maja);
    - the needs line, in 4.3c and 4.5b (Maja);
    - the staffing loop, read at every stage (Bob).
11. **Placeholder loans for starting a company only,** 4.1i, from the user's words relayed by Wilma. The user then
    said "we can dial them for the sim until the bank becomes real", so their numbers are dials with starting
    values of ours, reported in every simulation and read in 4.1's check. No question is asked.
12. **Load moved off Bob:**
    - the sale over the grid back to Bob, as the plan's list has it (Terra);
    - services in the rules and the second output to Otto, who offered;
    - spoiling to Maja;
    - Otto's reviews in 4.2 eased.
13. **Lines that called our own decisions the user's were corrected** (Anni):
    - the press licence and company spoiling moved to Wilma's decisions;
    - E3 now marks which answers are Wilma's or Anni's.
14. **Two reviews moved from Bob to Ella** (Wilma, evening out the load): 4.2f, the purse paying state inputs, and
    4.4h, sickness.
15. **What step 3 already builds** (the "grows" column, the eight places that named a type) left step 4 (Terra,
    Bob).

**Third draft (the user's answers)**
1. The four answers are placed at their stages with the quotes beside them: 4.1c, 4.3a, 4.7a and 4.7d. Nothing from
   the user now blocks 4.1.
2. New in 4.7a, from the user's own words: farms prefer land away from factories, because they pollute. It is read
   from the type table's pollution column, not from type names (ours, with Terra).
3. 4.7d is no longer conditional: the company road with its charge is built in step 4. Question 2b stays at 4.7d for
   the user.
4. The grid in 4.3a is a built network only; the "if it reaches everyone" branch is gone.
5. 4.7a's "away from factories" is now Terra's measure, confirmed: every non-growing row counts, weighted by its
   pollution column, plans included, within 3 tiles. Farms do not count against farms. It is ours, with starting
   numbers.
6. Question 2b answered and placed at 4.7d: the owner cannot refuse others and may demand a toll; the carrier
   chooses. The toll is set by the plan's own price rules, with no cap. road_law's toll cap and refusal levers are
   not used. No question of the user's is open in the plan.
7. On Anni's read: in 4.7d, the toll set by the price rules is marked as Wilma's reading, not the user's words.
   Whether the old road licence applies to the spot's road is now Wilma's (E2); no licence step is built until she
   rules. A leftover "if question 2 says step 4" in C3 is gone.
8. Wilma decided the spot road's licence (4.7d): the government's offer at the grant is the permission, and
   road_law's old licence procedure is not used. A company road nobody was asked for is not built in step 4.
9. Wilma decided the land price (4.1g): one price per place, the same for every type, through the land law's
   land_value_fn; a farm's land price does not move. Wilma builds 4.1b last in 4.1, on a tree holding 4.1a, 4.1c,
   4.1e, 4.1g and 4.1i.
10. Maja's piece 4.1j: crime reads the rebuilt pools, before crime goes on (4.1f). Two old readers of the households
    wake with the newspaper (4.4g), and two after step 4 are placed in their own list.
