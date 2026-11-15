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

## Still to do

The order-book retest (E165 + E165Q on top of R8_BUILDERS, ± E155BLD) waits for Bob's freight and material steps (R8
2a/2b), because the materials shortage was largely freight.
