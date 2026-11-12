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
9. **Media v1 M4** (Anni leads; spec-media-v1.md §9; answered 2026-11-12):
   - 2026-11-12: Anni added company-founded papers in `Media._found_ai` ("The X Courier", 20 W_ref via pay_upto "MEDIA_FOUNDING", no P&L line by agreement). At M4 Bob takes over the company-side decision (found/sell/close, money-driven exit) in firm AI, reading Anni's `Media.bad_press_12m(world, org)` for the motive and `org["media_out"]` for liquidation; Anni then drops her company branch.
   - `outlet` table with accounts `media:out:N`; quarterly settlement to the owner; deficits covered up to the subsidy, then `Media.on_insolvent`.
   - Copies booked in `_buy_services` from `Media.demand`, with actuals reported back via `Media.record_sales`.
   - Ad spend routed to outlets.
   - Firm AI founds, sells or closes papers through Anni's `found_outlet` / `transfer_outlet` / `close_outlet`.
10. **Population follow-ups (Wilma's notes, M12(2))**: ship volume driven by home-world demand for colonial goods and by colony attractiveness (wages, housing, food); emigration when the colony can't feed or house people.
