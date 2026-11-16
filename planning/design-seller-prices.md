# Design: each seller owns its price, and the colony price is a statistic (v12) (Bob, 2026-11-16, draft for the user)

**User ruling (via Wilma, 2026-11-16).** The user asked: "Do we have competitive measuring? If material business A loses
sales to B does it lower its prices or ignore it? I suspect ignore, or worse yet you have set a single material cost so
all businesses argue together to set prices, which is unrealistic." Shown what the code does, they ruled on the colony
price: "Yes, I want it only as a statistic."

**Today.**
- There is one colony index per good, `s["prices"][good]`, moved by a market rule (E45 / E149 cost-plus / the R8
  materials rules 1/2).
- Every seller asks that index × 0.90–1.05, depending on its own stock cover, floored at 0.9 × the full unit cost of
  its plant type.
- Buyers' limits are multiples of the same index (households × 3, firms × 1.3, public × 2), and dozens of decisions
  read it.

**What the index is not: what changes hands.** Findings from this week:
- MINERAL's index sat at 27–32 % of cost while 98 % of orders filled at the sellers' floors.
- The FOOD index fell to a third of cost under a 20 % shortfall, until households' 3 × index limits fell below every
  ask (planning/ab-r8-food.md).
- Builders' bids built on the index fed a price loop (planning/ab-r8-food.md, v11).

The index is a single number that everyone argues over, and it says nothing about any one seller.

## 1. The seller's price rule (rules 1/2 per seller, the same shape as Otto's builders)

**State.** Each seller keeps `org["r8p"][good] = {margin ‰, log}`.
- A plant type that sells in several districts keeps one margin. The delivered price differs by freight, as now.
- The log holds the last 3 months of: offered, sold, lost to price, lost to a rival, sold out.

**Ask.** ask = max(floor, own unit cost × (1 + margin)).
- *Own unit cost:* what the seller paid for its inputs (inventory WAC), its own wage bill and upkeep, per unit of last
  month's output. It is the seller's own books, not the type's cost at the colony index. A family firm uses
  `EconFamily.family_unit_cost` with its own grant share.
- *Floor:* never under what it will accept, which is its own variable cost (inputs, power, water, wages it cannot cut
  this month). A family firm's floor is its own cost sum. A distressed firm may go to its variable cost; that is the
  E116 / 0.7 rule, kept.
- *Start:* margin 200 ‰, today's E149 markup of 1.2. The founder's forecast margin for a new firm.

**Steps, monthly (goods sell monthly, builders quarterly).** Each signal is read from the market's fill, per seller.

| Signal over the last 2 of 3 months | Meaning | Step |
|---|---|---|
| Sold out with orders still unfilled (stock gone, buyers turned away) | Demand above what it makes | margin + STEP_UP (30 ‰) |
| Lost to price: a buyer's limit under its ask while it had stock | The ask is above the good's worth to buyers | margin − STEP (20 ‰) |
| Lost to a rival: a buyer took a cheaper delivered offer while it had stock, and its stock cover is over 2 months | Undercut | margin − STEP; − 2 × STEP if the cheapest rival ask (a price list, public) is more than 10 % under it |
| Stock building (cover over 3 months) and nothing above | Glut | margin − STEP |
| Otherwise | — | Hold |

**Important.** "Turned away" must separate stock-out (raise the price) from limit refusal (lower it). Today both count
as "unfilled", and the old rules 1/2 raised the price on both. That is half of why they locked prices up.

**Bounds.** There is no ceiling. The margin is bounded by the buyers' worth: an ask above every buyer's value limit sells
nothing and steps down.

**Output.** The output rules (3/4, reachable orders) and capacity rules (5/6) are unchanged. They read the seller's own
fill instead of the index.

**Rival price lists (user, 2026-11-16: "Companies should see each other's prices.").** These are in.
- A seller sees what others ask for the same good, delivered, in the districts where it sells.
- It reacts to being undercut with the faster step down in the table above.

**Same mechanism as construction.**
- Otto's builders keep a margin ‰ stepped by book and win rate, never under their own cost.
- Goods use the same shape: own cost × (1 + margin), stepped by own sales.
- Both live under the R8 rules 1/2 as "the seller's margin". One mechanism, two clocks: monthly for goods, quarterly
  for tenders.

## 2. Buyers: the cheapest delivered offer, up to what the good is worth to them (the 2026-11-15 ruling, extended)

| Buyer | Limit today | Limit under v12 |
|---|---|---|
| Households, essential FOOD | 3 × index (R8_FOOD: cash per unit) | Cash per unit after rent and utilities (R8_FOOD's hh_limit) |
| Households, CONSUMER minimum, FINE_FOOD | 3 × index | The same budget rule |
| Households, discretionary | 1.1 × index + freight | Their discretionary budget for the good ÷ quantity; quantity chosen at the last traded price |
| Producers' inputs | 1.3 × index (R8_MATERIAL: value) | Value bids for every producer and good (EconRulesMat.value_bids extended from materials to all) |
| Public services and utilities | 2 × index | Budget line per unit needed (institution budgets, utilities' tariff revenue) |
| Builders | 1.3 × index | The material allowance in each contract, fixed at signing (the v11 fix) |
| Warehouse, fleet | 1.5 × index | Their own value (rent earned, freight earned per unit) |
| Bakeries' FOOD | min(…, FINE_FOOD index × yield × share) | Value bid (FINE_FOOD's own price from its own sales × yield) |

Households still choose by delivered price × reputation (D2), as now.

## 3. The index becomes a statistic

- `s["prices"][good]` = the volume-weighted average of what changed hands last month (ask + nothing; freight and
  margins separately).
- There is also a per-district figure in `s["px_traded"][good][d]`.
- With no trade, the figure carries over.
- Nothing sets it. E45, E149 cost-plus and the materials rules 1/2 stop moving it under the flag.
- PRICE_MIN_MULT / PRICE_MAX_MULT stop clamping it. Government price control is a law lever on asks (§5, step 7).

## 4. Who reads the index today, and where each use goes

I counted 87 references in 26 files. They group into four kinds.

**A. Controls that move to the seller's or buyer's own figure (must change):**
- **Sellers' asks:** firm_ai.gd:505 (index × cover multiple) → §1 rule. firm_ai.gd:507 and conduct.gd:175 (gouging):
  gouging becomes "an ask far above the traded average during a shortage", a conduct test only.
- **Buyers' limits:** firm_ai.gd:454, 456, 465, 479; econ_households.gd:438–439, 473; econ_construction.gd:724 → §2.
- **The price update:** econ_market.gd:353–389 → the traded average (§3).
- **Government reserve and origin sellers:** econ_market.gd:117, 124, and E85. They become sellers with their own rule:
  the reserve sells at its cost plus a policy margin; the origin at landed cost × markup, as econ_trade.gd:320 already
  computes.
- **"Price vs cost" tests:**
  - firm_ai.gd:350 (E108: produce more when price ≥ 1.25 × cost) and firm_ai.gd:637 (investment test ≥ 1.1 × cost) →
    the seller's own realised price (its revenue ÷ units sold) against its own cost.
  - econ_family.gd:95 (found if price ≥ FOUND_MARK × cost) and :276 (food_needed by price) → the founder sees the
    traded average (a market observer), which is right for a newcomer.
- **R8 variable cost:** econ_rules.gd:185, 194 → own inventory WAC.

**B. Estimates by an observer: read the traded average (keep the call, change the source to the statistic):**
- **Unit costs for planning:** firm_ai.gd:370, 601, 606; econ_family.gd:165, 170, 568; econ_staple.gd:262 → "what I
  paid last" where the reader is the firm, the traded average otherwise.
- **The founder's forecast:** econ_forecast.gd:67, 76, 86; econ_rules_housing.gd:70; firm_ai.gd:698, 1135.
- **Construction estimates:**
  - econ_construction.gd:193–194 (builder's cost estimate) and :717 (builder budget);
  - :336–339 (escalation baseline) and :608 (escalation): contract indexation on the traded average is realistic;
  - econ_builders.gd:255–256 (the client's estimate) → Otto's client ceiling, the building's worth to the client
    (agreed 2026-11-15).
- **Households' budgeting:** econ_households.gd:48 (essentials cost), :432 (food_price_eff), econ_consumer.gd:206,
  econ_staple.gd:28, 218, econ_finance.gd:422 (benefit or food allowance) → traded average.
- **Other valuations:**
  - firm_ai.gd:414, 421 (upkeep value), conduct.gd:149 (deferred upkeep);
  - econ_fleet.gd:51, 77, econ_warehouse.gd:74, 147;
  - union_disputes.gd:408, econ_actions.gd:261, econ_trade.gd:104;
  - econ_informal.gd:52 and econ_autopilot.gd:93 (material tight);
  - econ_market.gd:91, 114 (reserve-release triggers, with fill);
  - firm_ai.gd:807 (scarcity for the planners, with fill).

**C. Statistics and reports, unchanged except for meaning:** CPI econ_market.gd:473 and econ_indicators.gd:311,
econ_query.gd:177, 361, 463, econ_report.gd:40, 66, econ_foodsec.gd:58, 62. The home world's prices are its own
constant figures (import landed costs), not the colony index.

**D. Setup:** econ_setup.gd:21, 89–100 and econ_consumer.gd:38–39 seed inventory WACs and the first traded average at
base prices.

The politics stub (stub_world_provider.gd) uses its own "prices" scenario key, not the index.

## 5. Order of work (each step opt-in, v12 as its own version)

1. **Instrument, with no behaviour change.**
   - Per-seller fill counters in EconMarket._fill: offered, sold, lost to price, lost to a rival, sold out.
   - The traded average beside the index.
   - Probe 3 seeds × 30 years to show index against traded average per good. It shows how far apart they are today.
2. **Value bids for every buyer (§2), flag SELLER_PX_BIDS.**
   - Extend value_bids from materials to all producers.
   - Households' budget limits for every essential.
   - Institutions by budget line.
   - Builders' frozen allowance (already written).
   - A/B on its own: buyers who pay the worth are the half that cures the deadlocks.
3. **The seller's margin rule (§1), flag SELLER_PX.** The ask from own cost × margin, stepped by own sales.
   - The R8 materials rules 1/2 (R8M_PX) and E149 cost-plus are retired under it.
   - Unit tests:
     - a seller undercut by a rival steps down;
     - a sold-out seller steps up;
     - a seller refused on price steps down, not up;
     - a family never asks under its own cost.
4. **Move the A and B readers (§4) under SELLER_PX.** The index becomes the traded average (§3).
5. **A/B v12:** 10 × 30 and seeds 1–3 × 60 against v11's defaults.
   - Take-apart: bids only / + seller margins / + readers moved / + rival price lists.
   - Report prices ÷ own cost by seller, the spread of asks per good, unfilled by cause (price / rival / stock-out /
     freight), and the usual adults, unemployment, food and real wage.
6. **Defaults after the A/B.** The R8 sector rules 1/2 rows in planning/eight-rules.md then read "the seller's margin".
7. **Government price control, a later step of v12.** User, 2026-11-16: "Yes, regulatory actions could come in from the
   government if needed, it's up to them, and as always governments should be allowed to make things worse, but it
   costs them."
   - **The lever:** a law lever on asks per good, either a cap (no ask above X) or a floor (no ask below X). Anni owns
     the law, the legal level and the ideology rows. The decision to use it goes on Maja's desk.
   - **The market obeys it, and the harm follows on its own:**
     - A cap under the sellers' cost means they don't offer below their floor. The shelves empty, the output and
       capacity rules shrink supply, and there are shortages and queues.
     - A floor above what buyers will pay means stock piles up. Buyers refuse, and producers cut output and jobs.
   - Nothing stops a government choosing a harmful control.
   - **Blame:** the government carries it through facts (shortage or glut under a price control). The papers and
     voters attribute what follows to the government.
   - **A/B:** a sensible cap in a shortage, and a harmful cap under cost, to show both outcomes.

User, 2026-11-16: no build before v11 is out. The note stands as the v12 plan, with rival price lists and the price
control above.

**Risks.**
- **Price wars to the floor in a glut.** Accepted: the floor is variable cost, and the capacity rules (6) take plants
  out.
- **A lone seller climbing.** Bounded by buyers' worth, not a ceiling.
- **Oscillation.** Small steps and 2-of-3-month signals.
- **A thin market's average jumps.** It is only a statistic, so nothing is controlled by it.
- **Collusion between sellers** is not modelled. The user may want it as conduct later.
