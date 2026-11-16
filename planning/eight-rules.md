# The eight rules for every producer (Bob, 2026-11-15)

User: "Every production needs 4 rules: when to increase price, when to decrease price, when to increase production,
when to decrease production, rooted in the actual market", then extended to eight ("you missed when to reduce capacity
and when not to make new companies, or we get the same issue again"). Decision: build the eight rules once, as one
shared mechanism every producer plugs into with its own numbers, and move the sectors onto it.

Sources:
- a code survey (every producer kind × the eight decisions; file:function references below);
- Wilma's idle-plant audit (planning/audit-idle-plants.md);
- the freight probe (seeds 1–3, 30 years).

## 1. What the code does today

Marks: **OK** = exists and reads a real signal. **WRONG** = exists but reads the wrong thing (colony-wide where the
buyer can't be reached, nameplate, sales instead of orders, unrelated gate). **NONE** = missing.

Cross-cutting facts:
- **One colony price per good.** Each good has one price for the whole colony, set from colony-wide orders
  (EconMarket._update_prices). Sellers' asks vary only by their own stock and never feed back.
- **Freight cuts trade, unseen.** Freight between districts caps trade (EconMarket._fill), but no producer, investor
  or planner reads the undelivered orders (freight_deferred). The only reader is a display indicator.
- **Capacity counts are nameplate.** _org_outputs counts mothballed plants too; E157 is opt-in.

| Producer | 1 raise price | 2 lower price | 3 produce more | 4 produce less | 5 add capacity | 6 reduce capacity | 7 new company | 8 no new company |
|---|---|---|---|---|---|---|---|---|
| FARM | WRONG: colony shortage >5%; dead band 0–5% freezes it below cost (E168 opt-in) | WRONG: colony cover >2 months | WRONG: sales EMA + share of colony-wide orders (nameplate share); stock <5% → full | OK-ish: same rule, 20% floor | WRONG: _investment (all plants ≥90% for 6 months), _new_plants (colony fill), gov _essentials (nameplate margin) | WRONG: mothball at T<25% for 12 months, but public enterprises kept running if unemployment ≥12% | WRONG: colony price ≥1.25 × recipe cost for 2 quarters; built in the founder's district, not where buyers are | partly: E128 sector cooling, founding slots, founder cash; no "incumbents have idle capacity" test |
| MINE / PROCESSING / COMPONENTS | WRONG: as FARM + cost-plus toward the cheapest cost (E149); recipe cost, not the plant's cost at its output | WRONG: as FARM; mines sell at 0.34 × cost at 85% use | **WRONG: target falls when its own stock can't be shipped (freight); nothing tells it why** | WRONG: same | WRONG: E115b "overbuilt" on nameplate blocks plants that are idle for want of freight | WRONG: as FARM | WRONG (MINE, PROCESSING); **NONE for COMPONENTS** | as FARM |
| Consumer workshops (CONSUMERF, TEXTILE, FURNITURE), MEDWORKS | WRONG: colony shortage; CONSUMER at 3.45 × cost is a freight shortage | WRONG | WRONG: as above | WRONG | WRONG | WRONG: co-op furniture almost all mothballed while furnishings short | WRONG (workshops); **NONE for MEDWORKS** | as FARM + unemployment and fill gates |
| BAKERY | WRONG | partly OK: E156 priced-out cut (opt-in, bread only); the only rule anywhere that lowers a price for customers priced out | WRONG: sales; bakeries run 0–67% while bread is short half the time (flour and freight) | WRONG | WRONG: gov _bakery_needs reads raw-food share (OK), private reads colony price | WRONG | WRONG | as FARM |
| FAMFARM / FAMBAKERY | as FARM / BAKERY | as FARM / BAKERY | **NONE: T fixed at 100%** | **NONE** | **WRONG: _expansion can expand a family plant** | NONE except insolvency | OK: district need, household, grant programme (E160/162) | partly OK: price test 1.3 × cost (it blocks foundings when food is short but cheap) |
| SERVICEHUB (all eight with R8_SERVICES: see 3g) | OK-ish: district price from district demand/supply, but neighbours' trade not counted | same | WRONG: T from last month's sales; step-up gated on unemployment (E134 opt-in); half of hubs mothballed, sold out 1% | WRONG | WRONG: _expansion only | **NONE: no mothball rule** | OK-ish: district price; micro co-ops on unemployment | partly |
| POWER / WATERWORKS (CPW) (all eight with R8_UTILITIES: see 3e) | lever, E150 tariff steps (OK with E150B) | lever, E150 (OK with E150B) | OK: metered demand ÷ effective capacity | OK | WRONG: nameplate margin unless E157 | NONE (by design, utilities) | NONE (public only, by design) | NONE |
| CLINIC / SCHOOL / ADMIN | n/a (free) | n/a | **WRONG: budget ratio only; clinics at 35% with 37% of need unmet** | WRONG: budget | OK-ish: gov builds on district access < bar | NONE | n/a | n/a |
| Builders (all eight with R8_BUILDERS: see 3f) | NONE: bid = cost estimate × fixed margin | NONE | WRONG: crews for active jobs only (E165Q: jobs starting within 3 months) | partly: shrink when blocked on material | as 3 | insolvency only | WRONG: tender backlog counts (E87/E117); E165Q book-based | partly |
| DEPOT / freight (CTA) | lever, E150 | lever, E150 | **NONE: T fixed at 100%** | NONE | **WRONG: only on "port full" facts; never on full trucks** | NONE | **NONE** | NONE |
| HOUSING (all eight with R8_HOUSING: see 3f) | OK: district occupancy → rent | OK | n/a (homes) | n/a | OK-ish: developers on district occupancy ≥105% (not rent or profit) | NONE | OK-ish | partly |
| Retail, warehouse, care, office, business services, police | fixed constants (margin, rent, fee) | fixed | posts from revenue or budget (OK for their role) | same | warehouse halls on use (slow) | posts to 0 | first use | n/a |

What this shows:
- **No producer reads deliverability.** Every demand signal is colony-wide.
- **Prices are colony-wide and blind to the producer's real cost at its output.**
- **"Produce more" is sales-led, with special cases** (fixed 100% for families and depots, budget for institutions).
- **"Reduce capacity" is a single mothball threshold with exceptions,** missing for hubs and depots.
- **Entry reads a colony price signal,** not reachable unmet demand net of incumbents' idle capacity, so firms are
  founded where they can't sell and not founded where they could.

## 2. The shared mechanism (design for review; nothing coded)

One module, **EconRules**, computes the same signals for every producer and runs the eight decisions as functions over
them. Each sector plugs in with a parameter row. Flag **R8** with a per-sector switch (R8_FREIGHT, R8_MATERIAL, …), so
each sector moves only when its switch is on and can be A/B-tested against the old rules.

### Signals (per producer, good and district, monthly; integers, saved)
- **Reachable orders:** orders from buyers the producer can deliver to this month at a price they will pay (limit ≥
  its ask). Unfilled reachable orders are the real shortage.
  - **Deliverability** = min(freight capacity left on the route, road capacity on the route).
  - The freight part is E172's. **The road part is a slot for Terra's per-route number;** until it exists, roads count
    as unlimited.
  - Undelivered orders for want of freight go to the **freight** signal, not the producer's.
- **Stock and cover:** stock ÷ sales EMA, in months.
- **Sales EMA** and **orders EMA** (filled + unfilled reachable).
- **Unit cost at current output:** fixed costs (crew core, upkeep, depreciation, loan service) ÷ actual output +
  variable cost. Also the variable cost alone, which is the floor for "keep running", and the full-load cost, which is
  the bar for "add capacity".
- **Utilisation:** output ÷ effective capacity (E157's: nameplate × served energy and water × crew fill).
- **Order book:** builders, and later any producer that takes orders ahead.
- **Profit over 12 months.**

### The eight decisions (each a function of the signals; per-sector parameters in brackets)
1. **Raise price:**
   - unfilled reachable orders > [s_up] for 2 months, or cover < [c_low], step up by [α] × the shortage;
   - also creep toward the unit cost at current output when it's below that cost and any reachable order is unfilled.
     This absorbs E168 and makes E149 read the real cost.
2. **Lower price:**
   - cover > [c_high] and utilisation < [u_low], step down by [α] × the excess;
   - plus, where buyers' willingness is known (households' recorded gates), the revenue-maximising cut toward
     [floor × variable cost]. That's E156, generalised from bread to every household good;
   - never below variable cost.
3. **Produce more:** target = min(effective capacity, orders EMA + stock gap), when price ≥ variable cost and inputs
   and crew are available. If output can't go up for want of an input, the input's producer sees it as a reachable
   order (E112 generalised).
4. **Produce less:** cover > [c_high] or price < variable cost for [n] months → step down toward sales, slow (−20% a
   month). Floor at [core] crew.
5. **Add capacity:**
   - all of these: utilisation ≥ [u_hi] for [n] months; unfilled reachable orders persist; price ≥ [m_add] × full-load
     cost; profit over 12 months > 0;
   - and the shortfall isn't deliverability (if it is, the signal goes to freight or roads instead).
   - **Imperfect knowledge:** the owner estimates next years' demand with an error from mgmt, risk and research (E170).
   - Replaces _investment, _expansion, _new_plants and the essentials planner's private path.
6. **Reduce capacity:**
   - mothball at utilisation < [u_lo] for [n] months with cover > [c_high] and profit over 12 months < 0;
   - sell or scrap after [n_scrap] months mothballed;
   - **never while it has unfilled reachable orders** (that's rule 3's job).
7. **A new company starts:** the E170 forecast:
   - reachable unmet demand in the district or route, minus incumbents' spare capacity (they serve it first, by rule 3);
   - minus what deliverability can't carry;
   - buildability: the builders' quoted wait and the material the plant needs against the material margin;
   - estimated with error;
   - starts if profit ≥ [margin]; picks the district the forecast supports.
8. **No new company:** any of the forecast's legs fails; incumbents have idle capacity; the route can't carry it; the
   sector cooled after forecast-founded failures (E170's 30%/15% memory); no builder or capital.

### Who decides in whose place
- **Private firms and co-ops:** all eight.
- **Public enterprises** (CPW, CTA, CAB, CHO):
  - **utilities** (POWER, WATERWORKS, DEPOT): price rules 1 and 2 become tariff proposals (E150/E150P: the government
    approves); rules 3, 4 and 6 are the company's; rule 5 is the government's chooser, which reads the same signals;
  - **other public plants:** like private firms, except that a sale (rule 6) goes through government policy (E137).
- **Public institutions** (clinics, schools, care):
  - rule 3 turns into a **budget request**: unmet access → the cost to serve it, a query for gov_builder;
  - the government decides the budget; rules 5 and 6 are the government's, on access gaps;
  - no price rules.
- **Family firms:**
  - rules 3 and 4 apply (no more fixed 100%), with the family's own food counted as sales;
  - rule 5 never (one family, one plant);
  - rules 7 and 8 are the family founding (E160/E162) using the same forecast.
- **Builders:** rule 1/2 = the bid margin, adapting to win rate and book length; rule 3/4 = crews to the book (E165Q2);
  rule 5 = crew growth; rules 7/8 = entry from the book (graded) plus the forecast.
- **Freight (E172, built in this shape from the start):**
  - **1/2:** CTA's tariff steps (E150B gauges) on freight cost at current use;
  - **3/4:** depot crews to the freight demanded (used + deferred);
  - **5 (add trucks or a depot):** used ≥ 95% of capacity in 6 of 12 months and deferred > [x]% of trade;
  - **6 (shed):** used < 60% for 12 months;
  - **7 (a private haulier enters):** trucks full for 12 months and no CTA depot project under way;
  - **8 (no haulier):** a CTA project is under way, or roads (Terra) are the limit on the route.
- **Housing:** rent rules 1/2 stay as they are (district occupancy); rule 5 = developers on occupancy plus rent and
  profit; rule 6 none.
- **Support plants** (retail, warehouse, office, business services): stay as they are; their sizing from revenue is
  already rule 3/4 in another form. The warehouse adds halls by rule 5.

### What it absorbs
- E134 (hubs' step-up: rule 3)
- E139 (contest drift: rule 2)
- E149 (cost-plus: rule 1 with the real unit cost)
- E156 (priced-out cut: rule 2, generalised)
- E157 (effective capacity: the utilisation signal)
- E165B / E165Q entry rules (rules 7/8 for builders)
- E168 (dead band: rule 1)
- E170 (market research: rules 7/8)
- E172 (freight: deliverability plus its own eight rules)
- the essentials planner's private path, _investment, _expansion, _new_plants (rule 5)
- mothballing and scrapping (rule 6)
- the founders' price test in _entry and EconFamily.found (rule 7)

The government's choosers (gov_builder) stay the government's but read the same signals through one query.

## 3. Build order (one sector at a time, each behind its R8 switch)
1. **R8 core:** the signals only, computed and published, no behaviour change. Includes reachable orders and
   deliverability (freight now, roads as a slot) and a query for gov_builder. Tests: the signals on known setups; base
   reproduces bit-identical.
2. **Freight (E172) and materials (MINE, PROCESSING, COMPONENTS):** where the jam is. A/B 10 × 30 and seeds 1–3 × 60.
3. **Food and bread** (FARM, BAKERY, FAMFARM, FAMBAKERY): rules 1–8, including the family rules.
4. **Builders:** bid margin, crews to the book, entry. The order book (E165Q2/Q3) is re-tested here, on top of
   working freight and materials.
5. **Consumer workshops and MEDWORKS** (including entry for COMPONENTS and MEDWORKS, which have none today).
6. **Service hubs:** district demand plus neighbours, mothballing.
7. **Utilities** (tariff proposals, government chooser reads the signals) and **institutions** (budget requests).
8. **Housing** (developers on rent and profit) and the support plants.
Each step: --check-only, unit tests per rule, A/B against the previous step, then on by default only after Wilma's
review.

## 3a. Addendum: answers to Wilma's review (2026-11-15)

**1. Prices: one price per good per district.**
- **What replaces the colony price:** each good gets a district price, s.prices_d[good][district], as services
  already have. Rules 1 and 2 run per district on that district's reachable shortage and cover.
- **How markets clear:**
  - each district market clears its own sellers first;
  - a buyer may buy from another district at that district's price plus freight (hops × tariff), while freight
    capacity lasts.
  - With trucks free, district prices stay within a freight margin of each other. With trucks full they split: bread
    dear where it can't get through, cheap where it piles up. That gap is the signal for hauliers (freight rule 7),
    founders (rule 7 picks the district) and producers' rule 5.
- **The colony price stays as a derived number:** the volume-weighted average of the district prices. It's read by:
  - **the CPI and wage indexing,** unchanged in meaning: the CPI becomes household-weighted over districts;
    district CPIs become available as an indicator, but wages keep indexing on the colony CPI unless you decide
    otherwise;
  - **the charter and exports:** the home-price comparisons and _consign read the **port district's** price, since
    that's where export goods are sold, and the quota's market value (E171) uses it too;
  - **indicators and old code paths** that read s.prices[good] during the move: kept as the colony average, so
    unmoved sectors see what they see today.
- **Sellers' asks** stay the seller's small adjustment around its district price, by its own stock cover, as now.
  They aren't the price.

**2. Rule 6:** agreed. Unfilled reachable orders block a capacity cut only if they're at or above the plant's
variable cost, the same test as rule 3. Orders below variable cost don't count anywhere in rules 3–6.

**3. Rule 8 for builders and hauliers (and every sector):** added. **No new company while most incumbents in the
sector lose money:** profit over 12 months < 0 for more than half of them, weighted by capacity. Long books or full
trucks alone don't pull in entrants who then starve, which is what E165Q2 did. While incumbents lose money with full
books, the signal goes to rule 1 (raise the bid margin or tariff) instead.

**4. Institutions' budget request: the query.** EconRules.institution_needs(world) → one row per institution type and
district:
```
{type: "CLINIC" | "SCHOOL" | "ELDERCARE" | "CHILDCARE" | "ADMIN",
 district,
 need,                 # clients this month (patients / pupils / cared-for people)
 served,               # clients served at current crews
 unmet,                # need − served
 budget_line,          # the lever that pays for it (INSTITUTION_BUDGET / care line)
 budget_now,           # credits a month going to this type in this district
 budget_to_serve,      # credits a month that would serve all of the need at current wages and input prices
 plants, plants_open,  # plants in the district, and how many are open
 crew_now, crew_to_serve,  # posts filled now / posts needed to serve the need
 plants_needed}        # extra plants if crew_to_serve exceeds what the open plants can hold
```
plus a colony total row per type. gov_builder and the legislature can read the gap (budget_to_serve − budget_now) as
the cost of meeting need, and plants_needed as a build decision.

**5.** Step 1 (signals only, base bit-identical) starts when you pass on the user's go.

## 3b. Selling parts of a company (every company; user, 2026-11-15)

"All companies should be able to sell parts of themselves." This adds a third option to **rule 6 (reduce capacity)**
beside mothballing and scrapping: **sell a plant or a division as a going concern.** What changes hands:
- the plant itself;
- its crew (they move with it, no layoffs);
- its stock of what it makes and uses;
- its customers (its share of sales history, so the buyer's planning starts warm);
- for builders, the crew's share of the order book.

**One sale mechanism for every case:** a plant offered for sale, with its terms, open to buyers for a while. It serves:
- rule 6's voluntary sale;
- the rescue of a firm short of cash (E166);
- plants sold in liquidation (today's _find_buyer and worker buy-out);
- forced sales of closed plants (E91);
- family buy-outs (E164);
- half-built buildings (E169);
- a public builder's parts (3c);
- public plants under the government's sale policy (E137 reprivatisation).

**When a firm sells** (rule 6):
- a plant its owner can't use fully: utilisation below the rule-6 bar while another firm's forecast says it could use
  it; or
- a plant it can't afford to keep: its share of costs exceeds what it earns, and the firm's cash is below
  [YOUNG_CASH_M]-style months of costs; or
- **a firm short of cash that would rather sell a part than fail.** This sits next to E166: within the rescue window,
  selling a plant comes before a stake, the bank and the government, if a buyer is found.

**The buyers are the other side of rules 5 and 7:**
- an existing firm can add capacity by **buying a plant instead of building one**: no wait in the builders' books.
  Rule 5 compares buying with building and takes the better one;
- a founder can **start a company by buying a plant** instead of planning a build: cheaper and less risky, because
  the plant, its crew and its customers exist. The E170 forecast applies to a purchase as to a build, using the
  plant's real output and sales;
- **who may bid:** any firm passing rule 5 for that good, or a founder passing rule 7, in a reachable district.

**The price:**
- **the seller's floor:** the larger of the plant's book value × [0.6] (the liquidation discount today) and what it
  would fetch scrapped;
- **the buyer's offer:** the value its own forecast supports, i.e. the present value of the plant's expected profit
  over [5] years (with the forecast's error), capped at the cost of building the same plant new;
- a sale happens at the midpoint of the offer and the floor, when the offer is at least the floor;
- the best offer within [3] months wins; with none, the seller falls back to mothball or scrap (rule 6), or to
  insolvency if it's in distress.

**Loans and crews:**
- **Loans:** a loan secured on the plant moves with it to the buyer, rescheduled (E152's pass_debt, by book share), or
  is repaid from the price first. The bank chooses, by the buyer's standing.
- **Crews:** they move with the plant. Their job slots go from the seller's staff to the buyer's (jobs stay equal to
  people), and their occupation follows the buyer (realign).

**Limits:**
- **A firm can't sell its last plant and stay a firm.** Selling the last one is a sale of the company (its shares, 3b
  of E166's ownership), or the firm closes.
- **Family firms: most won't sell while the farm or bakery still feeds them** (user, corrected 2026-11-15: "most
  would not sell even if they earned less, only if they had to" was "mostly", not a hard rule). Each family firm has a
  fixed **attachment**, pure from its id and the seed: three in four strongly attached, one in four less attached.
  - **Strongly attached** families sell only when they have to (distress, administration, liquidation, a grant-loan
    default).
  - **Less attached** families may also sell by choice, when both hold:
    - their income is below what four wage earners would make;
    - an offer is worth at least three years of the firm's profit and at least its book value.
  - **Forced sales apply to all.** Families buy first at the floor price.
  - The same rule goes into E164's design.
- **Public plants** sell only through the government's sale policy (E137): market-minded governments sell, state-minded
  ones keep; proceeds to the treasury.
- Utilities (POWER, WATERWORKS, DEPOT) are never sold while the colony is short of them, which matches today's
  public-only rule.

## 3c. Public builders and concessions (user, 2026-11-15; designed into step 4)

**a. A public building company the government can found or enlarge.** Today CWD is only a contractor of last resort.
- Under R8 the government reads the same builder signals as private founders:
  - the books (backlog in entrant-years, waits, public work waiting);
  - builders' profit over 12 months;
  - the material margin.
- Its choices:
  - **found** a public builder (a CWD-like enterprise with its own crews);
  - **enlarge** one (more crews, by rule 5's crew growth);
  - **leave it** to private entry.
- The rule-8 test applies: not while incumbents lose money. A public builder that bids at cost (no margin) would undercut
  private builders, so its bids carry the same margin rule as private ones unless the government chooses otherwise. That
  choice is exposed to gov_builder and the legislature, so it can be political.

**b. A public builder can be sold in parts** (3b's mechanism): a crew with its equipment and its share of the order
book is spun off.
- **Buyers:** a private firm or a new building company. This is a cheaper and safer start than from nothing, because
  the crew and work exist.
- **Who decides:** the government (E137's sale policy): market-minded governments sell, state-minded ones keep.
- **Price and proceeds:** 3b's price rule (book value of equipment and capital against what the book's work is worth);
  proceeds to the treasury.

**c. Concessions: a private builder appointed for a class of public work** (roads first; later also water mains, public
buildings).
- **The tender:** the government tenders a **concession** for [N] years, by default 5.
  - Builders bid a price basis (a margin over the estimate) and a retainer rate.
  - The government picks one by score (price, reliability, crew size) or by choice. Favouritism can enter here:
    choosing a lower-ranked bidder is a public fact (as ECON_CONTRACT_AWARDED's override is today) that Wilma's
    politics can use.
- **While it runs:**
  - every public job of that class goes to the concessionaire without a tender, at the agreed basis;
  - its crews are hired for that work (rule 3 for builders);
  - it still takes private work.
- **The retainer:** in months with no concession work, the government pays [40%] of the wages of the crew reserved for
  the concession (the "sort of part of the wages"), from the INFRASTRUCTURE line.
  - **Cost against tendering each job:** the retainer is paid only in idle months.
  - **The gain:** no tender delays, and a crew that exists when roads are needed.
  - I'll report retainer paid, months idle, and the price basis against the tenders it replaced, so the trade-off is
    visible.
- **How it ends:**
  - at the end of the term, renewed by a new tender;
  - early, by the government for poor performance (late jobs past a bar, as _check_late) with a public fact;
  - by the concessionaire's insolvency (its open jobs go back to tender).
- **Rule 8 sees concessions:** an entrant isn't founded for work a concession already holds.

## 3d. Public institutions: clinics, schools, care (Maja, 2026-11-16; switch R8_INSTITUTIONS with R8)

Code: sim/economy/econ_institutions.gd. Hooks:
- EconRules.monthly calls it once a month.
- FirmAI reads the crew share.
- gov_builder takes the government's side.
- The decision desk has two case types.

Numbers are in the INSTITUTIONS row of SECTORS.

| Rule | What it does now (with the switch) |
|---|---|
| 1/2 price | Public: in progress (fee proposals to the government; while the fee is 0 they do nothing). Private clinics and schools: their own fee per client a month, starting at 1.2 × cost per client. It rises 5% when the places were full and clients were turned away for 2 months. It falls 5% when places stand empty and clients in the district were priced out, never below cost per client. |
| 3/4 crew | Each open clinic or school asks for the crew that serves the people who actually come. That is its district's residents (clinic) or school-age children (school), plus a share, by capacity, of the clients from districts with no plant of that type, plus 5%. No floor: with no clients the ask falls to nothing. The line pays every ask in full if it can; if not, every ask is cut by the same share. So money goes where the clients are, instead of one budget ratio for every plant. ADMIN keeps the budget ratio, because nothing reads its output; a client measure for it is the user's decision. Care homes already size posts to need (EconCare). |
| 3 budget request | When the asks cost more than the line for 3 months (by over 10%), or under 85% of it for 12 months, the service publishes its need for the legislature (st["lever_need"][line]): +1000 plus the unserved share, or −1000 for less. Parties then vote on it by their politics. A request is also recorded (budget_requests, fact ECON_BUDGET_REQUEST), at most once a year per line. Under DELEGATION it is an INSTITUTION_BUDGET case for the minister, whose "yes" tables the bill. The health, education, elder-care and childcare lines all ask. |
| 5 add | build_needs lists the districts whose clients the open plants cannot hold at a full crew, and districts with no plant that the others' spare room leaves unserved. gov_builder builds as many as the line's headroom pays for (orders queued in the same quarter are counted against it), the most unserved first, so a district that already has one can now get another (before, only districts with none). A mothballed plant there is reopened first. |
| 6 reduce | A plant whose ask stays at or below 20% for 12 months is closed (mothballed), but only when another open plant in its district can serve all its clients at a full crew. Never the last plant of a district, never while anyone in reach is unserved. Under DELEGATION reopenings and closings are INSTITUTION_SITE cases. |
| 7/8 new body | Private or co-op clinics and schools (the user: every company type can be private). A household fills free public places first; only clients the public plants leave unserved buy, from their discretionary budget (at most 15% of it for a clinic, 12% for a school), own district first, then neighbours at +10%, the cheapest first. Rule 7: FirmAI._entry founds one where the forecast, with the founder's error, finds unserved clients in reach whose means cover the starting fee, less the private places already there, and the first year pays (fees less crew, inputs, upkeep and depreciation). Rule 8: not while nobody in reach is unserved, nor while the private plants of the type lose money. The founding path's own gates (founder capital, a builder) apply as for any firm. A private plant's crew follows its paying clients; it expands when full 6 months running and profitable, and mothballs after 12 months mostly empty at a loss. Probe (seed 3, econ-only, health line cut to 100): a private clinic founded in month 15 in d:2, under construction 18 months later. Care homes: next. |

Tests: tests/economy/test_rules_inst.gd. Without the switch nothing changes (state hash compared).

## 3e. Utilities: power and water (Anni, 2026-11-16; switch R8_UTILITIES with R8)

Code: sim/economy/econ_rules_utilities.gd (EconRulesUtil). Hooks:
- EconRules.monthly calls it once a month.
- FirmAI._set_target takes its output rule for POWER and WATERWORKS.
- FirmAI._new_plants, the essentials planner (E105) and the caretaker autopilot skip both types.
- E150's tariff step skips CPW.

Numbers are in the UTILITIES row of SECTORS; they are Anni's.

The utility's market is read once a month, per grid (power, water), from the month before:
- metered demand, what was delivered, unserved demand;
- effective capacity (condition and management, not nameplate);
- billed units (what was served, less the water works' own power);
- the bill (billed × tariff) and the grid's running cost (crews, upkeep, depreciation; water also pays for its own power
  at power's unit cost).

12 months are kept.

| Rule | What it does now (with the switch) |
|---|---|
| 1 raise | Quarterly, per grid. When the bill does not cover the cost (a 12-month loss, or the tariff below the cost per billed unit last quarter), the tariff goes to that cost per unit, at least +1. When it covers it but demand went unserved at full use (≥ 95% of effective capacity), +5%, at least +1. With E150P a rise is a proposal in pe_proposals (the E150P shape and fact; the government decides with EconPublicCo.approve). Without E150P it applies at once, as E150 does. Within the levers' legal ranges. |
| 2 lower | When the bill covers the cost and use stayed under 70% all quarter: −3%, at least −1, never below the cost per unit. Applies at once; a cut drops an open rise. |
| 3/4 output | The plants run to the metered demand: demand × 1.08 ÷ the grid's effective capacity (no 30% floor). A plant being wound down makes only what the others did not deliver. A plant reopened or newly built hires for the whole demand for its first 3 months, while the others keep running, so no customer goes unserved while its crew is found. |
| 5 add | When the grid was full in 6 of the last 12 months, demand went unserved at full use last quarter, or the forecast (a year on, at the last 12 months' trend) fills 95% of capacity. In order: keep a plant being wound down; reopen a mothballed plant; extend the smallest plant by 25% (up to 3×); build a new plant where the grid's first plant stands (law check: LawBridge BUILD_FACILITY). One project at a time per grid. CPW's cash, else a loan. With neither, nothing is built; the attempt is recorded as "unfunded" and there is no treasury money behind the government's back. |
| 6 reduce | When the other open plants could carry 1.08 × demand for 12 months, nothing went unserved, and the forecast would not fill them, the smallest plant is wound down. The others take its load and hire for it. At the next quarter it is mothballed if they delivered the whole demand. It is kept if anything went unserved, or if rule 5 wants capacity. Never the last open plant of a grid. |
| 7/8 new company | A private power or water company, or a second public one (the user, 2026-11-16: "All company types needs to be able to be created as private, but maybe they're is only ever enough work for say one powerplant then the conitions for new ones don't get switched on"; "WHEN I SAY THAT I DON'T MEAN REMOVE THE DAMNED SWITCH FOR IT. What if for example we run 500 years at that point there might be a need for another powerplant"). The condition is checked every quarter for as long as the game runs. Rule 7: founded when the forecast (demand a year on) leaves demand unserved that the incumbents do not clear (their capacity plus what is being built) and a plant serving it would make a profit at today's tariff (a full crew, upkeep, power for water, loan service). Rule 8: none while the incumbents have spare capacity or serve all demand, while CPW's grid or a private plant loses money, or while one is being founded. Who founds it follows the ownership policy (E137): market → private founders only; mixed → private first, then the state; state → a public company first, then private founders; without E137, private first, then public. A private founder and the licence are as for other private firms (FirmAI._entry, LawBridge). A public one is founded by the government with the founder's share from the treasury (INFRASTRUCTURE line) and a loan for the rest, never behind a human government's back. Either sells to the grid like any company that is not CPW, and starts with its price at today's tariff. Under the switch EconOwnership.PUBLIC_ONLY no longer applies. |
| private plants | CPW is the single grid buyer, and the tariff stays the customers' price (Wilma's yes, 2026-11-16). A private plant sells all the grid takes from it to CPW at its own price. Each month the grid takes the cheapest units first, with CPW's own plants at their running cost per unit and CPW first on a tie; a unit needed to avoid unserved demand is always bought. What CPW pays counts in its grid cost, so its tariff rule sees it. The private plant's own rules: 1 raise to its cost per unit at full use, or +5% when all it made was taken while demand went unserved; 2 −3% when taken for under 70% of its capacity, never below that cost; 3/4 output by the merit order; 5 a +25% extension when taken at 95% of capacity in 6 of 12 months; 6 mothballed when 12 months of sales do not cover its running cost, reopened when demand goes unserved at full use. |

Who decides:
- **CPW's board:** output, its own capacity from its own cash and loans, cuts, mothballing, and buying from private
  plants.
- **The government:** tariff rises (with E150P); founding a second public utility (the Cabinet's, since it spends
  treasury capital; the AI government does it by rule 7 under a state or mixed policy); subsidies or capital for CPW.
- **The government's own builder** (gov_builder._essentials, Wilma's) still orders power and water plants on its own
  reading. Whether it stays as the government's route beside rule 5 is Wilma's call.
- **A private utility's owners:** its price, output and capacity, by its own rules. A law may make one dearer (licence,
  levy); none may forbid it (the user, 2026-11-16).

The 12-month result is the grid's own (bill less running cost). Interest on CPW's loans and its other plants
(processing, components) are not in it.

Tests: tests/economy/test_rules_utilities.gd. Without the switch nothing changes.

## 3f. Builders and housing (Otto, 2026-11-16; switches R8_BUILDERS and R8_HOUSING with R8)

Code:
- builders: sim/economy/econ_builders.gd (EconBuilders), hooks in econ_construction.gd (bids, crews),
  econ_market.gd (the material each builder gets) and firm_ai.gd (entry);
- housing: sim/economy/econ_rules_housing.gd (EconRulesHousing), hooks in FirmAI._developers and EconHousing._owners_decide.

Second version, after the user's order of 2026-11-16 ("no floors, caps or locks of our own"). Removed:
- the crew cap at 2× the founding crew and the 5× exception;
- the +25%-a-month hiring cap;
- the −15% shrink when blocked;
- the 60% kept crew and the 30% core crew;
- the 300‰ margin ceiling;
- the one-builder-a-year entry gate;
- every test on last year's profit;
- housing's 3 blocks a quarter and its 95% occupancy gate.

**A builder's own market:**
- its book (signed jobs and their dates);
- its bids won, and the quotes its clients refused, on price or for the wait;
- job_margin: what the work left on its jobs earns at today's costs. That is the price × the share of work left, less
  the late penalty, wages and overhead, and inputs at award prices (the E76 escalation pays any change).
- fill_pm: the share of its material and component orders it actually got.

| Rule | Builders | Housing (developers and landlords) |
|---|---|---|
| 1 raise price | Margin +20‰ a quarter when it wins over 60% of its bids, or clients refused its quotes for the wait, or its jobs in hand lose at today's costs. Never in a quarter in which a client refused it on price. No ceiling: the clients' refusals are the ceiling. | Rent +3% a quarter while the district is ≥ 97% full (EconHouseholds._housing). |
| 2 lower price | Margin −20‰ when a client refused its quote on price, or it wins under 20% of its bids with no wait refusal. Never below its own cost. | Rent −2% under 85% full, −3% with rent arrears. |
| 3/4 output | Work done = its crews on started, paid-up jobs, as far as the material it got allows (_progress_fill). E76 stops work an owner does not pay for. A quote's start date = its book ÷ (crew output × fill_pm). | Homes are let when a household takes one; nobody holds homes back. |
| 5 add capacity | Crews to the work due now: started jobs at the pace their dates need, plus queued jobs starting within 3 months (the time to hire). When clients refused its quotes for the wait and its jobs pay at today's costs, crews to clear the whole book within that wait. Hiring is limited by the labour market only. | A new block when its forecast profit ≥ 10% a year on the developer's equity. Blocks are added until no district passes or the bank stops lending. |
| 6 reduce capacity | Crews shed to the work due. With fill_pm under 1000, the crew is only what its material supports. No crew of ours is kept. | An ageing block is renovated by its private landlord only when the renovation pays from the block's rent (renovation_forecast); otherwise it is let slide. Nobody is put out. |
| 7 new company | Quarterly. Work waits for a builder (tenders without a bid, or quotes refused for the wait) beyond what the incumbents' crews can start within the wait clients accept, and a founder has the equity. | A housing company is founded from the richest household's savings when no firm can put in the equity, for a block that passes rule 5. |
| 8 no new company | No waiting work; the incumbents' spare crews cover it; builders got under 90% of the material they ordered (a newcomer would get none either); or the incumbents' jobs lose at today's costs. | The block would make the district's rent rule cut rents (under 85% full or rent arrears); the forecast fails; no builder (quoted_wait −1); the bank would not lend (asked first); or the law says no. |

Tests:
- tests/economy/test_builders.gd: margin steps both ways and no ceiling; crews to the work and to the material;
  growth on a wait refusal and none on a losing book; fill_pm; entry rules 7/8.
- tests/economy/test_r8_housing.gd: rent is the signal; rents would fall; blocks until the forecast fails or the bank
  says no; rule 6.
- tests/economy/test_offswitch_v11.gd: both switches on v11, 48 months.

All pass, as do the plan, rescue, half-built, builder-credit, economy and money suites. Without the switches nothing
changes. Not yet run in a full game.

## 3g. Service hubs (Ella, 2026-11-16; switch R8_SERVICES with R8)

The user's order of 2026-11-16 (MASTER-PLAN.md). Code: sim/economy/econ_rules_svc.gd (preloaded as EconRulesSvc, not
a class name), with hooks in EconHouseholds._buy_services, FirmAI (_set_target, run, _expansion, _entry,
_small_business) and two lines in EconRules (the SERVICES signal). Kill switches for an A/B take-apart:
R8S_NOFILL, R8S_NOPX, R8S_NOOUT, R8S_NOCAP, R8S_NOENTRY.

**The hub's market.** Households buy services where they live, from hubs in their own district, or from a
neighbour's at +10%; what is left goes to self-employed sellers. Services can't be stored, so unsold hours are a
hub's glut and demand nobody served is its shortage.
- unfilled: st["r8"]["goods"]["SERVICES"][d].u
- reach: st["r8"]["plants"][fid].reach, the unfilled demand in its district and its neighbours
- unsold hours: f["svc_spare"]
- cost: cost_var and cost_full from st["r8"]["plants"]
- profit: the owner's last 12 months

**Signal fix (R8S_NOFILL).** The SERVICES row never arrived in st["r8"], so every hub's reach was 0.
- Why: households buy services after TRADE, when R8 had already totalled the month, and the next month's reset wiped
  them.
- Fix: EconRulesSvc.keep_fill holds the month's purchases (hubs plus self-employed sellers), and carry hands them
  to the next TRADE. The row therefore describes the month before.
- Each hub's svc_sold is now reset every month, also at zero output; before, it kept a frozen figure.

| Rule | What it does now (with the switch) |
|---|---|
| 1 raise | Per district, after the month's sales: price × (1 + ALPHA × (unfilled − unsold hours) ÷ the larger of wanted and offered). ALPHA is the colony's price speed, EconData.ALPHA. Customers nobody served raise it, in proportion. It replaces the old rule on district demand against hubs' output, which ignored neighbours and self-employed sellers. The general price band (PRICE_MIN_MULT / PRICE_MAX_MULT) stays, as for every price. |
| 2 lower | The same formula: the district's hubs' unsold hours lower it, in proportion. A cleared market holds it. |
| 3 serve more | Target = (what it sold + its capacity share of the unfilled demand it can reach) ÷ its capacity. While the district price pays its full cost (crew, inputs, the building), it also offers 10% more hours a month (step: Ella's). Unsold hours then lower the price (rule 2) until it no longer pays, so an idle hub competes instead of waiting while its neighbours sell dear. This replaces 1.1 × sales + 5% with a 30% floor, and E134's step-up gated on colony unemployment. No floor of ours. |
| 4 serve less | With unsold hours and a price under its full cost: back to what it sold. Below its variable cost (the price can't pay the energy and goods a service uses): none. |
| 5 add capacity | Sold out with customers waiting and its crew complete, in 6 of the last 12 months (Ella's window; a hub short of staff is helped by hiring, not building). Also the district price at or above its full cost, the owner earning over 12 months, and no project of its own under way. Then +25% (EXPAND), or at the largest scale (3×) a new hub beside it. Cash first, then a loan (EconRulesMat._finance). One per district a quarter. Replaces FirmAI._expansion for hubs. |
| 6 reduce capacity | Mothballed when, in 12 of the last 12 months, it had unsold hours or no output while the customers waiting near it fit in the other open hubs' unused capacity, and the owner lost money over 12 months. Never while customers wait that the others can't serve. A mothballed hub reopens when the unfilled demand it would reach exceeds the unused capacity of the open hubs near it for 3 months running (Ella's window). It is the cheapest capacity, so it comes before a founding. |
| 7 new company | In the district where it pays best, the volume a newcomer could serve is the unfilled demand it could reach, minus: the hours the hubs near it leave unused; hubs being built or expanded; mothballed hubs that would reopen. That volume is multiplied by the share of a crew the unemployed can fill. It founds when that volume makes a profit in the hub's first year at today's price, wages and inputs (crew, energy, goods, the building spread over its life). The same test serves a rich founder's full hub (_entry, in the forecast's district) and a household's micro co-op (_small_business, quarter size, founded by the pool in that district with the stake and the most idle hands). |
| 8 no new company | Nobody waiting net of the incumbents (including idle hubs, counted as room); the incumbents holding most of the capacity near it lose money; or the first year makes no profit. The micro co-op path loses its colony-unemployment trigger (8%), its 18-month gap, its two-per-district cap and its price gate. E128's cooling after a failed entrant still holds for _entry, as for materials. |

Step sizes and windows are Ella's and live in SECTORS["SERVICES"].params: win_m 12, add_m 6, cut_m 12,
sold_out_pm 50 (E134's sold-out test), reopen_m 3, offer_step_pm 100.

Tests: tests/economy/test_rules_svc.gd (11). They cover:
- the signal arrives;
- price rules 1 and 2;
- rules 3 and 4, including no floor and an idle hub offering hours;
- rule 6, never with customers waiting, and reopening;
- rule 5;
- rules 7 and 8, including idle hubs counted as room;
- micro founders;
- a 36-month run closes, keeps jobs equal to people, and saves and loads identically.

Also checked:
- With R8_SERVICES off, a run is bit-identical to the tree without the hooks (24 months, seed 3, defaults and R8
  alone; state hashes equal, on a scratch copy).
- The rules, materials, food, housing, economy, forecast, builders, builder-credit and rescue suites pass.

**Probe** (scratch, seed 3, 12 years, R8 + R8_SERVICES; not the game run):

| Measure | R8 alone (old rules) | R8 + R8_SERVICES |
|---|---|---|
| Hubs at zero output | 3–6 | 0 from year 9 |
| Hubs open / mothballed (Y12) | 8 / 5 | 15 / 2 |
| Expansions in 12 years | 0 | 27 |
| New hubs from rule 5 | 0 | 0 |
| Unemployment (Y12) | 11.4% | 10.2% |
| Population (Y12) | 4,337 | 4,198 (−3%) |
| Service price, mean (Y12) | 91 | 196 |

The service price stays high: hubs are sold out and short of specialists (the HIRING finding), so rule 5 waits for
complete crews. An earlier draft founded a micro co-op every quarter beside idle hubs; idle hubs now count as room.
Not yet run in a full game.

## 3h. Materials, food, workshops and freight (Bob, 2026-11-16)

The user's order of 2026-11-16 (MASTER-PLAN.md): every producer under all eight rules, each on its own market. Code:
EconRulesMat (sim/economy/econ_rules_mat.gd) for the goods, EconRules._freight_rules / _freight_tariff for freight,
hooks in FirmAI (_set_target, _post_inputs_and_offers, _expansion, _entry), EconMarket._update_prices and
EconPublicCo.quarterly. Every switch is off by default. Each step size is Bob's, not the user's: OWN_ALPHA 0.15, up at
most OWN_UP 5% a month, down at most OWN_DOWN 3% a month.

**Rules 1/2 for every goods sector (the same code).** Each plant has its own price, f["r8_px"]. It is set after each
month's clearing from the plant's own R8 readings:
- raise: the plant has reachable unfilled orders → up by OWN_ALPHA × reach ÷ its capacity;
- lower: no reachable unfilled order and stock left unsold → down by OWN_ALPHA × unsold ÷ sales.
There is no floor, no creep to cost, no "never below"; only the bounds every price in the game has (0.25 .. 4 × base ×
the wage level). The seller asks its own price, with no cover markup and no 0.9 × full-cost ask floor; families too.
The good's market price, which buyers' limits and rules 5/7 read, is the capacity-weighted mean of its open plants'
prices; the old colony step (E149, and for food the 0-5% dead band) no longer sets it.

**Mines, processing, components (R8 + R8_MATERIAL, on in v11; R8M_OWNPX, R8M_JOBVALUE)**

| Rule | In the code |
|---|---|
| 1 raise | R8M_OWNPX: the plant's own price, on its reachable unfilled orders |
| 2 lower | R8M_OWNPX: on its unsold stock while no order it can reach goes unfilled |
| 3 produce more | its capacity share of the reachable unfilled orders on top of last month's output, while its stock is under 2 months (target) |
| 4 produce less | below variable cost, the core crew only (20%) |
| 5 add capacity | use ≥ 85% and reachable unfilled ≥ 5% of capacity in 6 of 12 months, price ≥ 1.1 × full cost, owner not losing over 12 months → +25%, or a new plant beside it at 3× (capacity) |
| 6 reduce capacity | the mothball rule, never while it has reachable unfilled orders in the last 12 months (keeps) |
| 7 new company | the forecast's first year in the best district shows a profit with customers and no competitors in the way (entry_hot); COMPONENTS has an entry path |
| 8 no new company | not while the incumbents holding most of the capacity lose money, or the forecast shows no profit, "no_customers" or "competitors" |

Buyers' side (R8M_JOBVALUE): a builder bids for MATERIAL and COMPONENT what its jobs leave for the good, formula agreed
with Otto. Over its active, started jobs with no payment behind, per unit still needed: the award price of the good
(the E76 escalation repays rises above it) + ((price − today's late penalty) × the share of work left − the wages
still to pay − the other input still needed at its award price) ÷ the units still needed. It is the lower bound
(this month's wages count as still to pay). Without the switch the base price is the anchor.

Upkeep (OWN_FIRST, a defect fix): a producer keeps back from its offer what its own plants need of the good in that
district this month (inputs and upkeep). Before, its whole stock was sold in a shortage and buying it back was capped
by its cash, so the chain's own plants went without upkeep (Otto's trace). Probe, seed 3, economy-only, 40 years: without
it, condition 28-44 by year 20, mines closed from year 28, no material sold from year 22; with it, every chain plant at
condition 99-100 with full upkeep for 40 years, material at 215-270 (base 400), a fourth processing plant at year 40.

**Food (R8 + R8_FOOD, on in v11; R8F_OWNPX, R8F_FAM56)**

| Rule | Big farms and bakeries | Family farms and bakeries |
|---|---|---|
| 1 raise | R8F_OWNPX: own price, on its reachable unfilled orders | the same |
| 2 lower | R8F_OWNPX: on its unsold stock | the same |
| 3 produce more | as materials (target) | follows its sales like any producer (EconRulesFood) |
| 4 produce less | as materials | the same |
| 5 add capacity | as materials | R8F_FAM56: its own plant grows by a quarter on the same signals, with the family's own cost in the price test; never a second plant (Wilma: as built) |
| 6 reduce capacity | as materials | R8F_FAM56: the mothball rule, never while orders it can reach go unfilled |
| 7 new company | old entry today (colony price test); R8F_ENTRY (forecast, as materials) is in batch 3 | no family founds while the open plants could already make what buyers ordered (EconRulesFood.family_entry_block) |
| 8 no new company | old entry today; R8F_ENTRY in batch 3 | the same block |

Under R8F_FAM56 the old _expansion no longer grows family plants.

**Workshops and medical works (R8_WORKSHOPS: CONSUMERF, TEXTILE, FURNITURE, MEDWORKS)**

All eight under the one switch, the same code as materials: 1/2 own prices, 3/4 target, 5/6 capacity and keeps, 7/8
forecast entry. MEDWORKS gets an entry path (it had none). For these types the D2 month and unemployment gates on
entry go (not market signals). Kill switches: R8W_NOPX, R8W_NOOUT, R8W_NOCAP, R8W_NOENTRY.

**Freight (R8 + R8_FREIGHT, on in v11; R8FR_MARKET; R8FR_PRIVATE in batch 3)**

| Rule | In the code |
|---|---|
| 1 raise | R8FR_MARKET: CTA's tariff up on freight deferred in the last quarter, by OWN_ALPHA × deferred ÷ capacity (at least one lever step), quarterly, within the lever's range; E150 no longer steps CTA |
| 2 lower | R8FR_MARKET: down on idle trucks with nothing deferred, by OWN_ALPHA × idle ÷ capacity (at least one step) |
| 3 carry more | R8FR_MARKET: depots run at the freight demanded last month (carried + deferred) ÷ their full capacity |
| 4 carry less | the same, the core crew (20%) at least; before, always 100% |
| 5 add capacity | trucks ≥ 95% used (of the full fleet) in 6 of 12 months, or deferred > 5% of trade, or (EXP_PORT) cargo refused at the port → +25% depot or a new depot where freight waits |
| 6 reduce capacity | under 60% use for 12 months → mothball the smallest depot (never the last) |
| 7 new company | R8FR_PRIVATE (batch 3): a private haulier, founded on the forecast's profit from the freight CTA leaves deferred; paid for what its own depots carry; the cheapest carrier with room moves a shipment |
| 8 no new company | R8FR_PRIVATE (batch 3): not while CTA's trucks stand idle or carry everything, nor while hauliers lose money |

Tests: test_r8_ownpx (7), test_r8_food_own (5), test_r8_workshops (6), test_r8_freight_market (4), test_own_first (4).
With every new switch off the game is identical to the tree without them (seed 2).

## 4. The rest of the queue
- **Absorbed into R8:** E170 (rules 7/8), E172 (freight), the order book's entry and crew rules, E168, E156.
- **E171 (charter quota):** after step 2. It needs materials and freight to work first, because the quota competes
  with building and the ship's hold.
- **SEASONS:** after step 3. Winter stores need food's rules 3, 4 and 6 to be sound first.
- **E166 + E169 (plan rescues, half-built buildings):** after step 4, with the builders.
- **E164 (family buy-outs):** after step 3, with the family rules.
