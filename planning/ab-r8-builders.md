# A/B: builders under the eight rules (R8 step 4, Otto, 2026-11-15)

Code: game/sim/economy/econ_builders.gd (opt-in R8 + R8_BUILDERS), hooks in econ_construction.gd and FirmAI
(_auto_award, _builder_entry). Design: planning/eight-rules.md §2 "Builders" and §3c a, reviewed by Wilma.

Method: tools/ab_full.gd, 10 seeds × 30 years, in a scratch copy of the shared tree. Each table shows the 10-seed means.
The base arm (flags off) reproduces Bob's base11 (commit fa3f6df, DEFAULT_ON, args "base") on all 10 seeds, value for
value, so the code is bit-identical with the switch off.

Columns:
- adults at Y30; unemployment % and food shortfall ‰ (means over Y5–30); real income;
- builders alive and their crew at Y30; builder entries; failed tenders (cumulative);
- refusals per seed (government on budget / on price; private on price).

## 1. First arm (all rules as first built)

| Arm | Adults | Unemployment | Food ‰ | Real income | Builders alive | Crew | Entries | Failed tenders | Refusals: gov budget / gov price / private price |
|---|---|---|---|---|---|---|---|---|---|
| base | 4698 | 17.4 | 18.6 | 3.08 | 3.3 | 249 | 29.6 | 373 | – |
| r8b | 4165 | 20.3 | 37.5 | 2.87 | 1.5 | 159 | 17.7 | 744 | 250–470 a seed, nearly all budget |

**Cause:** the government's budget test compared prices with the reservation made at base prices, while prices ran
about 2.5× base (CPI ~250) and lines were often over-committed. So nearly every public bid was refused, public work
stalled, and builders lost revenue and died.

## 2. Refusals fixed

**What changed:**
- the government refuses a price above its own estimate at this month's prices × 1.3 (GOV_TOL);
- it refuses on budget only when the overrun is beyond the line's headroom plus a quarter of its annual budget
  (GOV_LINE_SLACK);
- the owner's estimate uses a builder crew's wage mix.

| Arm | Adults | Unemployment | Food ‰ | Real income | Builders alive | Crew | Entries | Failed tenders | Refusals: gov budget / gov price / private price |
|---|---|---|---|---|---|---|---|---|---|
| base | 4698 | 17.4 | 18.6 | 3.08 | 3.3 | 249 | 29.6 | 373 | – |
| r8b2 | 4314 | 22.0 | 27.4 | 2.72 | 1.2 | 130 | 15.5 | 355 | 132 / 62 / 18 |

Failed tenders were back at base level, but builders' capacity halved.

## 3. Ablation (each arm: all rules but one)

The switches existed only in the scratch copy.

| Arm | Adults | Unemployment | Food ‰ | Real income | Builders alive | Crew | Entries | Failed tenders | Refusals: gov budget / gov price / private price |
|---|---|---|---|---|---|---|---|---|---|
| base | 4698 | 17.4 | 18.6 | 3.08 | 3.3 | 249 | 29.6 | 373 | – |
| all rules (r8b2) | 4314 | 22.0 | 27.4 | 2.72 | 1.2 | 130 | 15.5 | 355 | 132 / 62 / 18 |
| − refusals | 4156 | 22.8 | 46.0 | 2.45 | 1.2 | 134 | 15.9 | 486 | – |
| − margin | 4325 | 22.1 | 29.8 | 2.51 | 1.3 | 210 | 20.5 | 460 | 68 / 8 / 3 |
| **− crew rule** | **4736** | **17.7** | **13.1** | **3.06** | **3.8** | 215 | 26.8 | **247** | 40 / 42 / 28 |
| − entry rule | 4278 | 21.3 | 30.0 | 2.75 | 1.7 | 218 | 19.6 | 342 | 152 / 60 / 17 |

**Reading:**
- With the old crew rule, the margin, refusals and entry rules beat base: more adults, less food shortfall, a third fewer
  failed tenders, and more builders alive.
- Removing refusals or the margin costs 150–400 adults, so both earn their place.
- **My crew rule was the fault:**
  - its cash cap stopped crews growing (builders run near zero cash);
  - keeping 85% of an idle crew cost them wages.

**Fix:**
- back to the old crew rule: ≤ +25% a month, ≤ 2× the founding crew, a 3-month hiring horizon, 60% kept while holding
  work;
- plus rule 5 only: the cap rises to 5× when the book holds more than 12 months of the crew's work and the year was
  profitable;
- no cash cap.

## 4. Final arm

r8b3 is the fix above, 10 × 30.

| Arm | Adults | Unemployment | Food ‰ | Real income | Builders alive | Crew | Entries | Failed tenders | Refusals: gov budget / gov price / private price |
|---|---|---|---|---|---|---|---|---|---|
| base | 4698 | 17.4 | 18.6 | 3.08 | 3.3 | 249 | 29.6 | 373 | – |
| − crew rule | 4736 | 17.7 | 13.1 | 3.06 | 3.8 | 215 | 26.8 | 247 | 40 / 42 / 28 |
| **r8b3** | **4806** | 17.6 | 20.9 | **3.11** | 3.8 | 302 | 25.4 | **232** | 62 / 94 / 38 |

**Reading:**
- r8b3 is the best arm on:
  - adults (+108 over base);
  - real income;
  - failed tenders (−38%).
- Private firms dead: 67.3 against 69.4.
- Food shortfall is 20.9‰, against base's 18.6 and the "− crew rule" arm's 13.1. Seeds spread from 6 to 35 in both
  arms, so this is within the seed noise of 10 runs but worth watching. Rule 5's larger crews (302) take more workers.
- Unemployment is level with base.
- Rule 8 blocked 4.3 entries a run while most builders lost money.

## 5. E169 (half-built buildings) and E166 (plan rescues), against base12 (HEAD 3a9b5d6)

Base on HEAD reproduces base12 exactly (4739 / 17.2 / 18.0 / 3.11, firms dead 68.6).

**E169, 20 seeds** (seeds 1–10 pre-9f95b56 plus seeds 11–20, both arms in the same copy):

| arm | adults | u % | food ‰ | real | priv alive | priv dead | opened | builders alive Y30 | crew Y30 | failed tenders |
|---|---|---|---|---|---|---|---|---|---|---|
| plan (E165, E165B) | 4750 | 17.6 | 24.9 | 2.86 | 11.6 | 43.4 | 11.7 | 3.9 | 268 | 439 |
| + E169 | 4721 | 18.7 | 26.1 | 2.75 | 8.2 | 43.5 | 10.1 | 2.9 | 188 | 376 |

Reading: E169 is neutral to slightly worse (−29 adults, within noise). Builders lose work, because a takeover tenders
only the remaining work (fewer builders and a smaller crew at Y30). Most shells decay unsold (217 of 313 left behind in the E166 + E169 arm, 69%).

**E166, 10 seeds on HEAD:**

| arm | adults | u % | food ‰ | real | priv alive | priv dead | plans | opened | surv36 (opened plans) | rescued, alive at 36 m |
|---|---|---|---|---|---|---|---|---|---|---|
| base | 4739 | 17.2 | 18.0 | 3.11 | 11.0 | 68.6 | 39.8 | 13.6 | – | – |
| plan | 4854 | 16.5 | 12.6 | 3.02 | 14.8 | 45.0 | 29.3 | 14.4 | 63/138 | – |
| + E166 | 4666 | 18.5 | 25.8 | 2.88 | 15.2 | 44.0 | 32.0 | 13.8 | 46/121 | 15/167 |
| + E166 + E169 | 4766 | 17.1 | 16.1 | 3.14 | 8.4 | 46.1 | 28.8 | 13.4 | 45/126 | 10/161 |

Rescues by kind (10-seed sums, E166 arm): stakes bought by firms 133, by households 28, bank top-ups 24, plans that
saved themselves during the window 17, failed and withdrawn 89. The state never rescued (no AI uses ECON_RESCUE_PLAN yet).

Reading: E166 as built is harmful. It costs 188 adults against plan, doubles food shortfall and lowers real income. The
plans it rescues almost all fail later: 9% are alive 36 months after the rescue, against 46% of opened plans in
general. A plan in trouble is mostly a bad plan, and the stake buyers (other firms in 83% of stake rescues) lose their money.
Next step: trace where rescued plans die (before or after opening) and what the buyers lose, before changing the price
test.

**Trace (E166 arm, 10 seeds, 168 windows; scratch copy):**
- The price test filters nothing: the good's price is a median 5.5× its unit cost, which assumes full output (test: 1.2×).
- Windows open a median 3 months after the plan starts, when 10% of the contract is paid. The "shortfall" is a gap on
  paper (left to pay − cash − credit) of 13–22% of the price. Plans start short, and no payment has been missed yet.
- 90 windows failed and were withdrawn after 4 months. Buyers had already paid 13.7M credits for partial stakes in
  them, all lost.
- Rescued plans that opened died a median 12–15 months later. The rescue covered the build but no running costs.
  Dividends returned 0.7M of the bank's 3.5M, 0.5M of firms' 9.0M and almost nothing of households' 8.5M.

**Stricter rescues, 10 seeds, same copy (pre-fd5f422; the founders' forecast still had Bob's 12× interest slip):**
- E166B: money moves only if pledges cover the whole need. The need includes 3 months of forecast running costs.
  Buyers want ≥ 10% a year from their share of the forecast profit (EconForecast.first_year, visible that month). The
  bank lends only if forecast profit repays all the plan's debt in 5 years.
- E166T: a plan is in trouble only once it has missed a payment. One window per plan. A plan with no rescue is left to
  E165's own rules (stalled, limit) instead of being withdrawn.

| arm | adults | u % | food ‰ | real | plans opened | surv36 (opened) | windows | rescued | rescued alive 36 m |
|---|---|---|---|---|---|---|---|---|---|
| plan | 4854 | 16.5 | 12.6 | 3.02 | 14.4 | 63/138 | – | – | – |
| + E166 | 4666 | 18.5 | 25.8 | 2.88 | 13.8 | 46/121 | 293 | 185 | 15/167 |
| + E166 + B | 4698 | 17.6 | 26.7 | 3.05 | 5.0 | 15/41 | 307 | 42 | 0/41 |
| + E166 + T | 4788 | 17.4 | 25.0 | 2.89 | 13.3 | 44/124 | 105 | 96 | 3/84 |
| + E166 + B + T | 4839 | 16.3 | 20.9 | 2.87 | 13.6 | 55/125 | 104 | 7 | 0/6 |

Reading:
- Most of E166's harm was its own trigger and kill: a gap on paper opened the window, and 4 months without a rescue
  withdrew plans that would otherwise often have opened. B alone makes it worse, since the forecast rejects almost
  every plan (1178 "no profit"), so almost every window ends in withdrawal.
- With a real trigger (T), 96 of 104 windows close by themselves (the plan pays its arrears) when the buyers are strict.
  Loose buyers (T without B) rescue 96 plans, of which 3 of 84 are alive at 36 months.
- B + T is near-neutral on adults (−15). It rescues almost nothing, because the forecast stub sees no profit in plans
  in trouble. Seeds 2, 5, 8 and 9 are identical to plan. Food and real income are a little worse; the 6 rescues are
  not enough to explain that, so it is likely noise.
- Finding for the user: in this economy, a plan in trouble is almost always a bad plan. Buyers who can judge it refuse,
  and buyers who can't lose their money.

## 6. Order-book retest (E165 + E165Q, ± E155BLD), fresh base on HEAD 6039704

10 seeds × 30 years. R = R8 + R8_BUILDERS + R8_FREIGHT + R8_MATERIAL in every arm except base (the v11 candidates
the order book has to live with). Base reproduces Bob's base13 exactly.

| arm | flags | adults | unemp % | food ‰ | real | firms alive | firms dead | plans | opened | wait mo | builders alive Y30 | builder entries / deaths | matblk / builder-months |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| base | defaults | 4735 | 17.8 | 21.1 | 2.96 | 11.5 | 69.1 | 40.2 | 13.6 | 9.7 | 3.3 | 29.5 / 28.2 | 445 / 1437 (31%) |
| r8 | R | 4715 | 18.5 | 14.6 | 3.05 | 20.4 | 62.5 | 40.7 | 12.6 | 8.2 | 3.3 | 21.4 / 20.1 | 447 / 1338 (33%) |
| plan | R, E165, E165B | 4616 | 17.9 | 20.8 | 3.28 | 11.1 | 35.1 | 24.3 | 8.1 | 9.4 | 2.6 | 22.6 / 21.7 | 453 / 1416 (32%) |
| book | plan + E165Q | 3811 | 18.4 | 29.4 | 2.73 | 6.0 | 33.4 | 6.3 | 2.2 | 18.6 | 2.7 | 27.7 / 27.0 | 365 / 1327 (28%) |
| bookbld | book + E155BLD | 4085 | 16.9 | 57.5 | 2.80 | 17.4 | 21.6 | 30.0 | 8.4 | 35.8 | 10.1 | 16.8 / 8.7 | 1044 / 3393 (31%) |

Adults per seed: plan 4215–5147; book 3588–4025 (below plan on all 10 seeds); bookbld 3516–4552. Food ‰ per seed for
bookbld: 137, 14, 30, 188, 40, 12, 25, 14, 102, 13 (three seeds have hunger crises).

Readings:
- E165Q (founders see the builders' order book before planning) is still harmful with freight and material markets on:
  −805 adults against plan, on every seed. Founders see long queues (wait 18.6 months) and stop planning (6.3 plans
  against 24.3), so the colony ends with 6 private firms alive. The queue it reads is real, but the economy needs the
  firms more than it gains from not waiting.
- E155BLD (more builders) shortens nothing: builders alive go from 2.7 to 10.1 and the quoted wait doubles to 35.8
  months. More builders means more half-paid crews competing for the same material, and food deaths jump to 57.5‰.
- Material-blocked months stay about 30% of builder-months in every arm, with or without R8_MATERIAL's bidding (base
  31%, r8 33%). R8_MATERIAL did not cure the builders' material shortage; buyers who bid what the input is worth
  still leave builders blocked a third of the time. Why is not yet traced (whether builders lose the bidding or the
  material is simply not there).
- Recommendation: keep E165Q and E155BLD off for v11. plan (E165 + E165B) remains the order-book arm worth carrying:
  −99 adults, best real income (3.28), firm deaths cut from 62.5 to 35.1.

## 7. Why builders are material-blocked (trace, HEAD a563d55, 10 seeds × 30 years)

A builder counts as blocked in a month when its work falls under 70% of what its crew and workable jobs allow
(EconConstruction._progress_fill). A scratch trace gave every blocked builder-month one cause. Share of blocked months:

| cause | base | R8 + BUILDERS + FREIGHT | + R8_MATERIAL | + E165 + E165B |
|---|---|---|---|---|
| blocked, share of builder-months | 31% | 32% | 33% | 32% |
| own cash: the MATERIAL order was cut to the builder's budget | 80.1% | 78.4% | 82.6% | 80.3% |
| components only | 6.7% | 5.9% | 6.2% | 6.4% |
| nothing ordered (the job started after the month's order) | 4.8% | 5.0% | 4.3% | 4.7% |
| lost the bidding: others bought first | 4.1% | 6.7% | 5.1% | 6.9% |
| lost the bidding: offers above the bid | 1.3% | 1.7% | 0.1% | 0.2% |
| not delivered (freight) | 1.8% | 0 | 0 | 0 |
| not made (nothing on sale) | 0.6% | 0.5% | 0.4% | 0.8% |
| owner one payment behind (E76 buys no material, work goes on) | 0.5% | 1.1% | 0.5% | 0.5% |
| filled in full, ordered too little | 0.2% | 0.6% | 0.7% | 0.4% |

When a builder was outbid, its limit was already about 1.4 × the price. No arm had a stale flag (a builder with no job
keeps last month's flag, but the trace found none counted).

Readings:

- The blocking is the builders' cash, not the market.
  - The share is the same with or without the value bids (R8_MATERIAL), freight and the plan stage.
  - Value bids remove "offers above the bid", which was never the problem.
- Why builders lack cash.
  - They are paid 10% at award, 80% of each month's work after it is done, and 10% at completion.
  - They buy two months of material ahead.
  - Their order is sized on cash − half a month's costs, topped up only by FirmAI._working_capital (at most 2 × last
    month's revenue and 0.6 × assets − debt, and builders have almost no assets but cash).
- Builders are outside both credit rulings in practice.
  - E148 (supplier credit) applies only at the till. The order is sized before that, on cash, so the room is never used.
  - Producers add the E140 annual line (EconAnnual.input_draw) when sizing; builders never call it.
- Fixes to test, opt-in, in separate arms (Wilma):
  - (s) supplier credit counted when the builder sizes its order, limited to what its signed jobs still need;
  - (a) the client pays for material at cost as delivered;
  - (c) working capital against the signed order book.
  - Each arm with and without R8_FOOD + R8_MATERIAL + R8_FREIGHT, and the best one on Bob's frozen allowance.

## Still to do

Housing under the eight rules: see planning/ab-r8-housing.md.
