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
| SERVICEHUB | OK-ish: district price from district demand/supply, but neighbours' trade not counted | same | WRONG: T from last month's sales; step-up gated on unemployment (E134 opt-in); half of hubs mothballed, sold out 1% | WRONG | WRONG: _expansion only | **NONE: no mothball rule** | OK-ish: district price; micro co-ops on unemployment | partly |
| POWER / WATERWORKS (CPW) | lever, E150 tariff steps (OK with E150B) | lever, E150 (OK with E150B) | OK: metered demand ÷ effective capacity | OK | WRONG: nameplate margin unless E157 | NONE (by design, utilities) | NONE (public only, by design) | NONE |
| CLINIC / SCHOOL / ADMIN | n/a (free) | n/a | **WRONG: budget ratio only; clinics at 35% with 37% of need unmet** | WRONG: budget | OK-ish: gov builds on district access < bar | NONE | n/a | n/a |
| Builders | NONE: bid = cost estimate × fixed margin | NONE | WRONG: crews for active jobs only (E165Q: jobs starting within 3 months) | partly: shrink when blocked on material | as 3 | insolvency only | WRONG: tender backlog counts (E87/E117); E165Q book-based | partly |
| DEPOT / freight (CTA) | lever, E150 | lever, E150 | **NONE: T fixed at 100%** | NONE | **WRONG: only on "port full" facts; never on full trucks** | NONE | **NONE** | NONE |
| HOUSING | OK: district occupancy → rent | OK | n/a (homes) | n/a | OK-ish: developers on district occupancy ≥105% (not rent or profit) | NONE | OK-ish | partly |
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

## 4. The rest of the queue
- **Absorbed into R8:** E170 (rules 7/8), E172 (freight), the order book's entry and crew rules, E168, E156.
- **E171 (charter quota):** after step 2. It needs materials and freight to work first, because the quota competes
  with building and the ship's hold.
- **SEASONS:** after step 3. Winter stores need food's rules 3, 4 and 6 to be sound first.
- **E166 + E169 (plan rescues, half-built buildings):** after step 4, with the builders.
- **E164 (family buy-outs):** after step 3, with the family rules.
