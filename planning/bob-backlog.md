# Bob (economy & companies): backlog, in order

1. **Century gate** (running): 6 seeds × 100 years with E109 (construction fill order), E110 (A39) and E111 (demography). It must pass before the user's century chronicles. E108 alone did not pass (famine on every seed, years 10–36).
2. **E106 fabrication kits** (user, A38):
   - Kits Mk I → II → III. An upgrade consumes the previous tier's output; each tier raises output per worker and cuts waste.
   - Founding: a Mk I component workshop and a small smelter (CPW).
   - Action `ECON_UPGRADE_FACILITY {facility, line}`. New kits use `ECON_COMMISSION_PROJECT`.
   - `EconQuery.upgrade_options(world)`.
   - CPW plans upgrades first.
   - Ping Wilma so she can wire GovBuilder and the news line.
3. ~~**A39**~~ DONE as E110 (2026-11-12; Wilma wired GovBuilder). Original notes:
   - Public farms: a public enterprise "Colony Agricultural Board". Add FARM to `EconActions.OPERATOR`. Check that PROCESSING and COMPONENTS commission with CPW as operator.
   - `ECON_OFFER_INCENTIVE {type: FARM | PROCESSING | COMPONENTS | POWER | WATERWORKS | HOUSING, grant_pct: 10–50, months, cap}`:
     - paid from ECON_BUDGET_SUBSIDIES, on completion;
     - E102 treats an open offer as co-financing (a lower threshold: 1 quarter of scarcity, or price ≥ 1.1× unit cost);
     - facts ECON_INCENTIVE_OFFERED / ECON_INCENTIVE_CLAIMED.
   - `EconQuery.essentials(world)` → `{good: {capacity, demand_ema, margin_pct, trend}}` for FOOD, ENERGY, WATER, MATERIAL and COMPONENT, plus housing occupancy.
4. **M13 A2:** economy keyed by area and tile (see m13-econ-notes.md). Call `Planet.generate` before `Terrain.generate`.
5. **M13 A3:** housing builds, company housing, private enclaves, plus the §9 housing life-cycle and land (Anni's LandLaw interface agreed).
6. **M11:** hazard engine, greed (a9 API in m11-econ-notes.md), emergency levers, the victim-fund payout.
7. **M12 (2):** colonial goods, quotas, ship cargo, smuggling.
8. **Wilma's chronicle findings:** answer #3, #4, #6 and #7 with century data (indicators for the chronicle table).
9. **Media v1 M4** — DONE 2026-11-12 (economy half + company cover/sell/close; Anni: demand, finances, subsidy). Remaining: Anni drops her company branch in `_found_ai` when ready.
   - 2026-11-12: Anni added company-founded papers in `Media._found_ai` ("The X Courier", 20 W_ref via pay_upto "MEDIA_FOUNDING", no P&L line by agreement). At M4 Bob takes over the company-side decision (found/sell/close, money-driven exit) in firm AI, reading Anni's `Media.bad_press_12m(world, org)` for the motive and `org["media_out"]` for liquidation; Anni then drops her company branch.
   - `outlet` table with accounts `media:out:N`; quarterly settlement to the owner; deficits covered up to the subsidy, then `Media.on_insolvent`.
   - Copies booked in `_buy_services` from `Media.demand`, with actuals reported back via `Media.record_sales`.
   - Ad spend routed to outlets.
   - Firm AI founds, sells or closes papers through Anni's `found_outlet` / `transfer_outlet` / `close_outlet`.
10. **Population follow-ups (Wilma's notes, M12(2))**: ship volume driven by home-world demand for colonial goods and by colony attractiveness (wages, housing, food); emigration when the colony can't feed or house people.
11. **Policy fork harness** (Wilma, 2026-11-13): run a seed to month M, save, continue the same world N years with a lever forced on/off; the difference isolates the policy (6-seed A/Bs diverge politically and swamp 3–5 point effects — E117 A/B). Reusable for any lever.
12. **Transport T2–T4** (A43, after the v5 chronicles; spec-transport-v1.md). Contracts agreed:
   - Terra (T1): ROAD projects with p["link"] use Transport.validate_link / plan_link (bill) / complete_road (on _complete, link id on the fact); add_traffic(world, link_id, units) monthly for freight; route(world, from, to, mode). Wire only after transport.gd is registered; off switch "T1".
   - Anni (T5, sim/law/transport_law.gd, preload): capped_fare → {fare, subsidy}, fare_cap_binds, accident_factor / safety_cost_factor, tour_approval_p / tour_accident_factor, road_toll (PAVED links → treasury), operation() PUBLIC/FRANCHISE/OPEN.
   - Anni (T7): I maintain table "traffic_stat" keyed "LINK:<id>" / "NODE:<id>" {kind, id, name, load_pm, flow, accidents_12m, serious_12m, fatal_12m} monthly (ints), and emit ECON_TRAFFIC_ACCIDENT {target, serious, fatal}; Terra supplies "traffic_fix".
13. **Queue order (Wilma, 2026-11-13):** E120 + S3 (in progress) → S1 = A2 (economy on areas) → rest of A46 (settlements emerge; new games start with only the landing camp; old saves keep fixed districts behind a flag) → A47 expedition X3–X4 (spec-expedition-v1.md: passage/cargo price list and ship mass; a closing balance sheet money raised = spent + endowment + company capital; investors become the starting companies with capital, dividends home and mandates; debts repaid from exports; the first bank's owner from the funding mix; presets Balanced / Corporate / State charter / Pioneer co-op / Hard world) → banking spec (deposits → lending capacity, mortgages and home ownership, interest-rate policy, bank ownership and failures). S3 developers should be able to SELL homes on mortgages once banking lands.
14. **D2 follow-ups (Wilma/user):** EconQuery.shortages(world) → [{good, unmet_pct, producers, price_vs_home, months_short}]; action ECON_AUTHORISE_IMPORT {good, qty|pct, ships: 1} (merchants bring CLOTHING/FURNISHINGS/FINE_FOOD only when authorised; CONSUMER/MEDICAL stay automatic); TEXTILE/FURNITURE/BAKERY in INCENTIVE_TYPES and commissionable as state workshops; unmet durables feed a concern; a cheap BASIC fallback (home sewing, second-hand) so stock never hits zero.
15. **A48 sister colonies, C2 (after A47; spec-sister-colonies-v1.md):** a light economy per sister colony (a few goods, surpluses/shortages), ship ROUTES calling at several colonies (each colony's ship interval follows the route), inter-colony trade on shared ships, migration between colonies; under 10% extra run time. Design note: EconTrade.on_ship / EconCohorts.ship_migration are per-arrival hooks today — grow them toward a route object (ports of call, cargo per leg).

## For the banking spec (Wilma, user 2026-11-13): individual flat ownership
User: "Can people buy out their apartments and have companies renovate them themselves? That would be smaller
projects." — clarified: "I did not mean a bostadsrätt (co-op), I meant owning the apartment alone."
- A household buys ITS OWN FLAT outright (mortgage from the bank) from the landlord or the state housing office (CHO);
  buildings become mixed: some flats owned, others rented.
- Owners renovate their own flat when they choose and can afford it (kitchen, bathroom, windows, heating) by hiring
  small trade firms — a new small-firm trade sector (plumbers, electricians, carpenters, roofers) living off a steady
  flow of SMALL contracts.
- Shared parts (roof, façade, stairwell, pipes) are paid by all owners and the remaining landlord by share of flats;
  disputes and non-payers let the shared parts decay even when flats are fine.
- Owners maintain better than landlords (slower decay); ownership builds wealth (inequality owners vs renters);
  defaults and repossessions in a crash; selling CHO flats to tenants is a political issue (price, replacement).
- Correction (user): a tenant may buy their flat ONLY IF THE OWNER AGREES to sell (landlord's or CHO's decision:
  price, strategy, politics for CHO). And co-operatives (bostadsrätt) come in TOO, alongside individual ownership:
  tenants of a building may form a co-operative and buy the whole building if the owner sells; members own shares
  and the right to their flat; the co-op maintains the building and hires firms. So three tenures plus rental:
  rented (CHO / landlord), co-operative (bostadsrätt), owner-occupied flat.
