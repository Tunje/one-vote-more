# M11 crises: economy side (88) — working notes

Spec: `spec-events-v1.md` (A33). Decisions from Wilma, 2026-11-11:

- **A. Survivability gate (hazards on):**
  - ≥ 4/6 seeds OK;
  - at most 1 famine across 6 seeds — a balance target, never a cap in code (if balancing yields 2, bring the traces);
  - conservation passes;
  - the guard test shows famine is reachable.
  - Item G stays as the gate with hazards off.
- **B. Guard test, "mismanaged colony":**
  - ECON_BUDGET_RESERVE_PURCHASES 0 and the reserve emptied;
  - ECON_FOOD_ASSISTANCE 0;
  - imports banned (a9's ban lever, or ECON_IMPORT_TARIFF 50);
  - ECON_BUDGET_INFRASTRUCTURE 0;
  - ECON_IMMIGRATION_QUOTA 120;
  - hazards on.
  - Origin food aid (E61) arrives only on a supply ship, so the ship hazard applies to it, and it is capped.
- **C.** Violations go through a9's API (below). No new table.
- **D. Order:**
  1. S2 leftovers (Gini and deprivation indicators, PD tests 4 and 5, J26 named headcount, docs) and the seed-2 unemployment look;
  2. then M11 steps 1 → 4: hazard engine, greed, preparation, facts.
  - The tree is frozen until Wilma releases it.

## a9 interface (final, from a9 2026-11-11; supersedes the earlier record_violation draft)

1. **Record greedy conduct:** `LawOps.record_greed(world, org_id, rec) -> fid`.
   - Call it every month the conduct continues. It is an upsert keyed by org + kind + facility + good.
   - `rec` fields:
     - `kind`: DEFERRED_UPKEEP, SAFETY_CORNERS, CONTRACT_CORNERS, DUMPING, HOARDING, GOUGING, EXPORT_IN_SHORTAGE or CARTEL;
     - `since_month`;
     - `saving`: milli-credits, added each call (`cumulative: true` sets the total instead);
     - `hazard_ids`: merged across calls;
     - `evidence`: 0..1000, latest value wins;
     - optional: `facility`, `good`, `food` (bool), `members`, `project`, `district`.
   - Legality comes from the rules engine:
     - upkeep, safety corners, contract corners and dumping are always unlawful;
     - gouging and hoarding are unlawful per LAW_PRICE_GOUGING (ALWAYS, or IN_EMERGENCY by default);
     - export in a shortage is unlawful only if LAW_FOOD_EXPORT_BAN is on and `food` is true;
     - cartels are unlawful unless LAW_COMPETITION is NONE;
     - lawful conduct is recorded as SECRET LAW_HARMFUL_CONDUCT (an inquiry can reveal it; it is never prosecuted).
   - When the firm stops, call `LawOps.greed_stop(world, fid)`. Evidence then decays 3%/month and can't be detected below 50.
2. **Detection** (a9, in JUSTICE):
   - inspections by channel (SAFETY, ENV, MARKET), whistleblowers, leniency (cartels) and accidents;
   - a revealed violation leads to an ENFORCEMENT case;
   - a won SEVERE case emits **LAW_MANAGER_CONVICTED {org, ceo, violation, case}**. 88 replaces the CEO (COMP_CEO_REPLACED) and rerolls greed.
3. **Crisis facts:**
   - `data` carries `{crisis: true, hazard, facility?, cause_records: [fid], damages (milli-credits), scope}` plus the `exposure` block;
   - magnitude ≥ 50 opens an inquiry, which reports in 3–6 months; a found cause emits LAW_CRISIS_CAUSE_REVEALED (PUBLIC);
   - damages lead to a TORT case, paid into ledger account "law:victim_fund" plus a row in table victim_award `{id, crisis, scope, amount, paid_out, status}`;
   - **88 needs a monthly payout:** move OPEN awards from law:victim_fund to the hh pools in the award's scope, then set paid_out and status PAID.
4. **Deterrence:** `LQ.expected_sanction(world, kind, org, params = {}, horizon = 24)` returns `{lawful, class, p_detect_month, p_detect_horizon, expected_fine, horizon}`. Compare it with the saving.
5. **Emergency levers (88 implements the market effects):**
   - LAW_RATIONING (NONE / FOOD / FOOD_FUEL);
   - LAW_PRICE_CONTROL (NONE / ESSENTIALS);
   - LAW_FOOD_EXPORT_BAN;
   - LAW_REQUISITION: validate `{kind: GOVERNMENT}`, "REQUISITION", `{compensation_pct}`; lawful only in an emergency and at ≥ 100%;
   - `LQ.emergency(world)` gives the current state.
6. **Closed economy:** staff costs go to hh pools; fines go to gov:fines_revenue.

## Planet climate interface (Terra, in the tree, 2026-11-11)
Module: PlanetClimate. Pure functions of the seed, valid for any hex.

| Query | Returns |
|---|---|
| `climate(world, cell, month)` | `{temp_c, rain_mm, season, growing 0..1}` |
| `weather(world, cell, month = current)` | `{rain_pct, rain_mm, temp_c, temp_anom_c, drought_months, season, growing}` |
| `storms_at(world, cell)` | `[{kind: CYCLONE \| RAIN_FRONT \| BLIZZARD \| DUST, strength 1..5}]`, strongest first |
| `phenomena_at(world, cell)` | `[{kind, strength}]`, alien phenomena (below) |
| `air_pollution(world, cell)` | 0..100, the downwind plume of econ emissions |
| `warming_c(world)` | global warming offset |
| `Planet.hex_of_tile(world, tile)` | the hex cell; today always the landing hex |

Alien phenomena:
- SOLAR_FLARE: global, ~0.5 a year, strength 1–5. Proposed effect: power and electronics.
- SPORE_BLOOM: drifts from jungle and wetland. Proposed effect: crop blight or health.
- MOON_SURGE: coastal, about every 2 years, predictable. Proposed effect: coastal flooding.

Calibration: the colony at 38°N should see about one strong rain front a decade, 1–2 cyclones a century, a flare every couple of years and a moon surge every 2 years. Per-band strike rates are in spec-planet-v1.md.

Facts PLANET_<KIND> are emitted for weather over settled hexes. Cite them as `causes` in damage facts.

Terra reads emissions via the peek_st stopgap. Ping her when `EconGeo.emissions` exists.
