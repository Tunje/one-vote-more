# Re-evaluation, step 1: Terra's switches (desk review)

The user's order (2026-11-16): "I want them all reevaluated and given a proper consideration because some of those
could be holding the answer". Method: planning/reeval-off-switches.md (Wilma). This is step 1 only: reading the
code, unit tests, `--check-only`. No game was run for this review.

**Base:** HEAD 3e20850. v11's DEFAULT_ON includes R8, R8_FREIGHT, R8_MATERIAL and R8_FOOD. None of my switches is
in it.

**Unit tests on HEAD, 2026-11-16:** every test passes.
- test_freight_roads
- test_road_works
- test_siting
- test_town_grid
- test_ecology
- test_wildlife
- test_seasons
- test_town_view

Each file includes an in-game test of determinism and save/load with its switch on.

## Summary for the screen

| Switch | Ever run in a full game? | Does it change the economy alone? | Screen it as |
|---|---|---|---|
| FREIGHT_ROADS | Yes: base11, 10×30 and 3×60 (Bob) | Yes: it limits freight between districts | **alone** |
| ROAD_WORKS | Yes: 10×30 on af1feda, on top of FREIGHT_ROADS (Wilma) | **No**: alone it is a no-op, because it needs FREIGHT_ROADS | **FREIGHT_ROADS + ROAD_WORKS**, against FREIGHT_ROADS alone |
| SITING | No | **No**: nothing in the game chooses or reserves a site yet | **skip** (the run would be identical to base) |
| TOWN_GRID | No (only short runs for tests, timing and screenshots) | **No**: nothing in the economy reads the grid | **skip** (the economy would be identical to base) |
| ECO | No economic A/B; only calibration runs of harm and wildlife (seeds 1–3, 30–40 years) | Yes: farm yields, wildlife deaths, rougher rain | **alone** |
| SEASONS | No | Yes: farm output follows the farm year, plus droughts | **alone**, and **ECO + SEASONS** |

So 4 arms are worth the machine: FREIGHT_ROADS, FREIGHT_ROADS + ROAD_WORKS, ECO, SEASONS. ECO + SEASONS is
optional.

**My honest expectation:** none of the six holds the answer to the bank, the private firms or the jobs. All except
the two no-ops add a real-world limit or loss. On the bank and private-firm measures I expect them level or worse.
The one that could teach something about the bank is SEASONS: seasonal working capital is the classic job of a bank.
Details are below.

---

## FREIGHT_ROADS

**What it was built to fix.** The user said: "Next thing you're going to run into is roads, they won't be able to
take the new freight." Freight between districts drives on the colony's roads as trucks. The roads limit what gets
through, and road_needs sees the jam coming.

**Mechanics:**
- A truck carries 25 units and counts as 2 car-equivalents. It also drives back empty.
- Freight shares a jammed road with the commuters.
- Held freight waits, like deferred freight.
- The government's default road fix, the cheapest cure by severity, already responds to freight needs when the
  switch is on. So this arm includes roads that respond.

**When it was judged.** Bob, planning/ab-r8-freight.md, base11 (fa3f6df), measured adults, unemployment, food
shortfall, real wage, food price and dead firms.

| Run | Adults | Unemployment | Food shortfall | Real wage | Dead firms |
|---|---|---|---|---|---|
| 10×30, with FREIGHT_ROADS | 4330 | 18.7% | 54.4‰ | 2.53 | 76 |
| 10×30, base | 4698 | 17.4% | 18.6‰ | 3.07 | 69 |
| 3×60, R8_FREIGHT + FREIGHT_ROADS | 7191 | — | 85.7‰ | — | — |
| 3×60, R8_FREIGHT alone | 8450 | — | 18.0‰ | — | — |

- Verdict then: "stays off until roads respond". Never judged on bank capital or on private firms alive.
- Since then:
  - bottleneck_mu has landed, so the ranking credits held freight only to the most loaded item on a route.
  - Repair-first (condition under 400) has landed in gov_builder.
  - Neither has been re-run.

**Does it work on v11?** Yes.
- The tests pass.
- The switch is read in three places:
  - FreightRoads.on in the transport tick;
  - econ_market (the room on each route);
  - econ_rules._road_pm (R8's deliverable share).
- One flaw, Bob's lines, harmless to the screen:
  - The two economy reads use `meta.on` only.
  - So with FREIGHT_ROADS in both `meta.on` and `meta.off`, the market still limits freight while the roads table
    stops updating.
  - "meta.off wins" is broken there. Wilma's screen only adds the switch to `meta.on`, so it is unaffected.
  - Fix: use `FreightRoads.on(world)` in both places.

**What it should move if it holds part of the answer.** Only one reading would help: cross-district trade killing
local private producers. If that is happening, a road limit protects the outlying districts' own makers.

- Look for:
  - more private firms alive outside the landing district;
  - fewer dead firms;
  - the jam share (TRANSPORT_FREIGHT_JAM, fpairs held);
  - government road spending, because more public construction means more public jobs, which goes the wrong way.
- Expected:
  - fewer adults and more hunger, as on base11;
  - a bank no better, because fewer sales mean fewer repayments.

**Needs with it.** Nothing to run. For sense it needs roads that respond: the default fix is inside it, and
ROAD_WORKS is the alternative. PRIVATE_ROADS (Anni) sits on top of it.

## ROAD_WORKS

**What it was built to fix.** The government picks among every way to cure a road need: repair, widen, junction,
bypass or a new link. It asks the budget for it (lever_need for ECON_BUDGET_INFRASTRUCTURE) and ranks by freight
freed. Districts passed over resent it. The desk gets road cases. The user: "also road expansions, not just quality".

**When it was judged.** Wilma, planning/ab-road-works.md, 10×30 on af1feda. Every arm had R8 + R8_FREIGHT +
FREIGHT_ROADS.

| Arm | Adults | Food shortfall |
|---|---|---|
| Whole ROAD_WORKS | 4296 | 66.8‰ |
| Default fix | 4450 | 48.6‰ |
| ROAD_WORKS without the ranking | 4536 | 46.1‰ |

- The ranking by held freight did the harm.
- Repair-first helped (50.3‰).
- Seeds 9 and 10 were bad in every arm that chooses a fix, unexplained.
- Since then:
  - Repair-first went in.
  - The ranking now uses bottleneck_mu.
  - Neither has been re-run; the "rerun on HEAD" in that note's Next is still open.

**Does it work on v11?** Yes; the tests pass. But `GovBuilder._road_works_on` requires FreightRoads.on too, so
**ROAD_WORKS alone is identical to base**. Its other readers (the desk's road cases, the legislature's own lever_need)
only fire from that path.

**What it should move.**
- Within the FREIGHT_ROADS arm: less held freight, food shortfall back towards the base.
- The money:
  - more infrastructure budget, which means more public spending and public jobs;
  - if the bypasses go to private builders, more private construction work.
- Read:
  - held freight;
  - the infrastructure budget share;
  - public versus private jobs;
  - seeds 9 and 10.

**Needs with it.** FREIGHT_ROADS, required. DELEGATION (Maja) only for the desk cases.

## SITING

**What it was built to fix.** Who picks where a building goes:
- land reserved by use (farmland, housing, industry, town);
- site options with what stands near;
- `place_at` to choose a site.

The standing buildings are pinned, so a reservation moves nothing.

**Ever run in a full game?** No. It has only the in-game test of determinism and save/load.

**Does it change the game alone? No.**
- Nothing in the simulation calls `place_at` or `set_use`. The commander, desk or law that would choose is the
  "Nothing chooses yet" of spec T10.
- So the table stays empty:
  - `Siting.pins` returns empty;
  - nothing is blocked;
  - `step_month` returns at once.
- The only change is a constant added to the layout memo's key.
- A screen run would reproduce base. **Recommend: skip it**, and give the verdict "no effect until something
  chooses sites" (Anni's land-use law, design-law-land-use.md, or the commander).

**What it could move later.** Through the layout: commute distances, then commuters absent (econ_fleet), then labour.
It could also put industry beside its workers. That is small next to the bank.

## TOWN_GRID

**What it was built to fix.** Towns as 100 m cells with housing forms, chosen by the commander's policy. Growth scored
per cell. A location value. The catchment and form figures that give a motive to build up.

**Ever run in a full game?** No. It has short runs only: tests, the one-off cost of the step-up (about 1 s) and the
screenshots.

**Does it change the economy alone? No.**
- It writes its own "town" table and two PUBLIC facts, TOWN_GRID_LAID and TOWN_FORMS_SET.
- Its random salt is derived from the seed, not drawn, so the game's random streams are untouched.
- Nothing in the economy, population or layout reads it. The only reader is the town view.
- The economy would be identical to base. **Recommend: skip it.**

**What it could move later, with owners.**
- Otto's rents and forms reading the location value and `catchment` / `form_table`.
- Bob's connection cost.
- The layout switched over to the grid. That needs its own A/B.

Then: denser housing means lower cost per home and shorter commutes. The housing side of the bank (R8_HOUSING, Otto)
is the only route to "the answer", and it goes through those owners.

## ECO

**What it was built to fix.** The user asked for a planet that answers pollution:
- pollution released at each district, which spreads and harms the land;
- rougher weather over harmed land;
- dust storms;
- a food pyramid of five levels (pollinators, pests, foragers, grazers, predators);
- wildlife attacks on people;
- the lever ECO_WILDLIFE_POLICY;
- birds.

**Ever run in a full game?** Not with the economy measured. The calibration runs found:

| Run | What was measured |
|---|---|
| Seed 1, 30 years | Landing-hex harm 390‰ |
| Seed 3, 30 years | Landing-hex harm 143‰ |
| Seed 2, 40 years | Pollinators fell to 25–35%; farms lost about 10%; 7 attacks, 1 death |

**Does it work on v11?** Yes; the tests pass. The switch is read by:
- PlanetEcology.on: production yield, climate roughness, planet tick, indicators;
- GovWildlife: `meta.off` honoured.

**Open hooks that are not built:**
- the employer's duty of care for wildlife deaths;
- the victims' fund.

**What it should move.** Food: farm yield is cut by harm (up to −30%, −60% on FRAGILE worlds) and by the food web
(up to −15%, −20% and −10%).

- The harm builds over decades, so 60 years is the right horizon. The first 20 years show little.
- Wildlife deaths remove workers.
- It is a cost layer: less food, higher food prices.
- One possible upside: dearer food lifts family farms' and farms' revenue, so private farm firms may live better.
- Read:
  - food shortfall and food price;
  - private farms alive;
  - PLANET_ECO_HARM;
  - the deaths.

**Needs with it.** Nothing. SEASONS adds the winter behaviour and the birds' timing.

## SEASONS

**What it was built to fix.** The user: "Don't forget birds, preferably that migrate, and seasons." Farm output
follows the farm year and droughts. The yearly mean of the farm year is 100, so the year's food is unchanged on
average. The harvest comes in the growing months, and winter runs on stores. Drought costs 5% a month from the 3rd
dry month, up to 30%.

**Ever run in a full game?** No. planning/eight-rules.md set the order: "SEASONS: after step 3. Winter stores need
food's rules 3, 4 and 6 to be sound first."

**Does it work on v11?** Yes; the tests pass. The switch is read in econ_production on the farm and family-farm lines.

**It is now eligible.** R8_FOOD, step 3, is in v11's defaults, so the prerequisite the eight-rules note named is met.

**What it should move.** This is the one switch of mine that touches the bank question directly:
- Farms earn in the harvest months and pay wages all year, so they need working capital across winter.
- Food is stored from autumn to spring.

The base's food year is flat, so it never tests whether credit carries a seasonal business. Things to watch:
- **Spoilage:** FOOD loses 2% a month in stock (EconData.SPOILAGE_PERMILLE), so a 6-month winter store loses about
  11%. The year's food is effectively a little lower.
- **Price swings:**
  - Stock cover over 2 months pushes the price down, so farms sell the harvest cheap.
  - Spring shortage pushes it up.
  - Watch the swing, and whether R8_FOOD's output and capacity rules mistake the season for demand. They read yearly
    figures since 5a55d61, which should see through it.
- **Read:**
  - food shortfall by month of year (winter against summer);
  - farm firms' cash low points;
  - working-capital loans and bank capital;
  - private farms alive.

Expectation:
- If the bank fails earlier with SEASONS, the bank's credit is not fit for a real seasonal economy. That is worth
  knowing for Bob's bank build, even though it does not make SEASONS a fix.
- If nothing moves, it is safe to add for realism.

**Needs with it.** R8_FOOD (on in v11). ECO is optional; with it come the winter wildlife, the birds and the
PLANET_HARVEST's harm share. Bob's household heating (`heating_pct`) is a query nobody reads yet.

## Proposed verdict path (for step 2 onward)

- **SITING and TOWN_GRID:** verdict "no effect until an owner reads them". No machine time.
- **ROAD_WORKS:** screen only on FREIGHT_ROADS, against FREIGHT_ROADS alone; check seeds 9 and 10 at the second
  look.
- **FREIGHT_ROADS, ECO and SEASONS:** each alone, 3×60, on Wilma's measures. SEASONS should be repeated after Bob's
  bank build: step 4 of the method matters most for it.
