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

16. **A45 W1–W5 waste economy** (after housing; Anni's W6 law is in: game/sim/law/waste_law.gd, preload as WL).
   Hooks to read: WL.disposal_cost_factor / disposal_pollution_factor; recycling_target_pm, landfill_tax_per_tonne (mcr);
   sewage_removal_pm, sewage_cost_factor (private operator treating below the standard → record_greed DUMPING);
   cremation_share_pm(world, wished_pm), sanitation_fee_pm. Levers: LAW_WASTE_STANDARD, RECYCLING_TARGET, LANDFILL_TAX,
   SEWAGE_STANDARD, BURIAL_RULES (−100 cremation … +100 burial), SANITATION_FEE. Defaults change nothing.

17. **S7 (user, after v6; spec-settlements-v1 §S7)** right after the housing-bid fix. Economy part first, on districts:
   doubling-up ceiling ~130%; above it new households → SHACKS (informal stock: no utilities, health/fire/crime risk,
   FAIRNESS/HOUSING concern) or HOMELESS (counted indicator) when no land/materials; delayed household formation and
   lower fertility under crowding; working families emigrate when no home. Informal AREA kind (AreaStore INFORMAL) +
   map drawing with Terra once S1 areas land. Political choice (clear / legalise+upgrade / build) is Wilma's; Bob gives
   actions + hooks (clearance under Anni's eviction rules; upgrade as S3 renovation lots).

18. **S7 fix (opt-in now, 2026-11-13). Findings so far:** S7 itself barely acts (few shacks); it is a small perturbation
   that tips seed 1 into a FOOD TRAP that other perturbations (big PES, a materials advance) also trigger. The trap at
   Y30: farms hold 12k food unsold (state farms idle on full stores) while households order 4.2k at price 633 = 3.8×
   unit cost and buy 93% of that — need unmet ~30% (unaffordable). Market rule: unfilled orders (buyers out of money)
   count as shortage → price UP while stock piles; a construction side-trap: builders without cash or credit cannot buy
   material at spiking prices (CWD: 0 material, farm 41/250 WU for 18 years).
   Tried and REVERTED: E126 materials advance (owners prepay builders) and E127 "no shortage when supply ≥ orders" —
   each made seed 1 worse (E127: famine by Y5–10, farms stuck at 10; falling food prices kill the farm-building signal).
   Needed: a design that separates "scarce" (price up, build farms) from "unaffordable" (food assistance / benefits /
   price falls for unsold perishables WITHOUT killing investment — e.g. investment reads wanted_ema/need, not price).
   Original notes: with S7 on, seed 1 stalled at ~5.5k by Y50 (farms frozen at 20 for 30 years,
   ≥50% household food unmet in every income band incl. the rich, price 4–5× base, nameplate capacity "sufficient").
   Measure per year: farm output vs nameplate (labour fill, inputs, targets), other FOOD buyers (D2 bakeries, D1
   consignments, reserves, spoilage), FirmAI farm investment/entry signals, GovBuilder farm commissions + fiscal guard.
   Then switch S7 on by default.
19. **Emergency price control and rationing as real economics** (Wilma, low priority: after S7 and firm growth).
   LAW_PRICE_CONTROL "ESSENTIALS": cap on the consumer price of essentials — queues (unfilled orders), black-market
   leakage, weaker farm investment unless the state subsidises the gap. LAW_RATIONING "FOOD"/"FOOD_FUEL": per-person
   cap that spreads scarce food evenly (fewer deaths among the poor, less for the rich). Politics already declares and
   lifts them (EmergencyPolitics / LawOps.end_emergency); only the economic side is missing.
20. **Firm-count growth** (Wilma-agreed, after S7; also a FAIRNESS issue per planning/audit-bias-report.md: market-minded
   Cabinets see unemployment +2.2 pts/yr in office vs flat for state-minded — there is no channel by which market policy
   creates jobs; add tax and regulation effects on firm entry): private firms stay at 16–25 while the labour force triples —
   MAX_FORMING / entry vs labour-force size, survival of entrants; hub resale (liquidated hubs only to same-sector
   buyers, no worker buyout) and the service-hub output trap (E123 attempt dropped: no jobs effect, mothball risk).
21. **PES range back to [0, 20000]** together with Wilma's slump-rule cap (posts tied to unemployment), once the
   "big PES → hunger" effect is understood (seed 1: PES at 20M/yr from Y20; taxes maxed, benefit floor cut to 0).
22. **Labour lever hints vs delivery** (audit, low priority): hints overpromise ~30% on both sides; 30–54% of evidence
   judgements are exactly 0; pro-labour changes deliver 0.73 of their hints vs 0.62 for the opposite — recalibrate.
23. **Late housing decay (v7 outside review, low priority after jobs/demand):** seed 3, Y81–100: 192 blocks fell into
   disrepair vs ~38 renovations while the market could still build. Check long-run maintenance economics: do owners
   (CHO, private landlords) stop renovating because of rents (rent_factor falls with condition — a trap?), credit
   (landlord must pay a third and borrow the rest), or the ECON_BUDGET_HOUSING line being cut (CHO renovates only with
   headroom)? EconHousing quarterly owner decision is the place.
24. **E129 public-enterprise cash sweep** (Wilma-agreed, after the food trap): yearly, a public enterprise's cash above
   12 months of costs plus its pending investment (E105 plant estimates) goes to the treasury. Today ECON_PE_DIVIDEND_RATE
   only takes a share of quarterly profit; the accumulated stock (CPW 4.7M at Y30, seed 1) never moves.
25. **Menial and public-service labour pass** (user question via Wilma, after backlog 18; plan sent 2026-11-13, awaiting
   OK): jobs that grow with the population, sized by client group (Swedish-like full coverage): elder care 1 per 9
   retirees; childcare 1 per 5.5 children aged 1–5; sanitation ~30 per 10k (W1 of spec-waste, jobs only); building
   upkeep 1 per 150 homes × age factor (in the HOUSING recipe, paid by the owner); funerals/cemeteries 1 per ~20 deaths
   a year. ≈ 280–320 jobs per 10k at the colony pyramid. Public institutions on the PES pattern (facility scale =
   posts) with budget lines ECON_BUDGET_ELDER_CARE / CHILDCARE / SANITATION; default coverage elder 60%, child 50%,
   sanitation and cemetery full. Effects: elder care → retiree mortality and carer re-entry; childcare → parents'
   re-entry and fertility; sanitation shortfall → mortality, pollution, concern; no cemetery capacity → concern.
   Order: sanitation + upkeep → elder/childcare → cemetery, each with a 3-seed A/B.
   APPROVED by Wilma 2026-11-13. Notes: lever politics weights from the start (care: REDISTRIBUTION + and ECON_ROLE +,
   small and scaled by range as for PES; concerns PUBLIC_SERVICES + / FAIRNESS + / GOVERNANCE −; sanitation:
   ENVIRONMENT + and SAFETY + concerns) — Wilma reviews the rows before the A/B; effects measurable in the chronicle
   (coverage %, retiree mortality, parents' re-entry) for the next audit.
26. **Private care providers** (later; a privatisation fight): care companies under contract as an alternative to the
   public Care / Childcare Services.
27. **SUPPORT ECONOMY pass** (USER correction via Wilma, 2026-11-13; TOP economy priority after the food trap;
   supersedes and folds in item 25). User: "you have completely missed the support workers ... cleaners, janitors in
   every place, people in the lobby, office workers ... who pushes the papers at a power plant ... where do parties
   sit, where is the union HQ, who buys cookies for them, who delivers things, where are the pizza places ... who
   drives it to you?" Recipes count only direct production crews; Sweden: ~15% farming/mining/manufacturing.
   A. Overhead staff on every organisation (office/admin, management/planning, cleaning/janitors, reception,
      sales/logistics), a sector ratio per production worker (~0.3–0.6; heavier for utilities, admin, health, school;
      lighter for farms), working at an OFFICE (a building type: construction, upkeep, a site; on the map later, Terra).
   B. Non-production organisations employ people: party HQs (party money), union HQs (dues), newsrooms, ministries
      (is ADMIN scaled?), company HQs — with Anni: her staff system's party/government staff become real PopStore jobs
      paid from the org's account.
   C. Business services bought by organisations in proportion to their staff: cleaning companies, catering, couriers,
      office supplies — a B2B services market firms can enter.
   D. Household services driven by income: restaurants, cafés, takeaway, delivery drivers, taxis, retail, hairdressers —
      split SERVICEHUB or scale by spending categories so more income means more of these jobs.
   E. Item 25 (care, sanitation, upkeep, cemetery) stays as part of this.
   Calibration: employment structure near Sweden's for a 10k colony (industry + primary ~20–25% given the export base,
   services the rest). Check the money (overhead is real wages: prices and profits must still work); watch overshoot
   into labour shortage (fine if immigration responds). Short plan with jobs per 10k by category first, then build in
   steps with 3-seed A/Bs.
   **27-W. Workload and stress** (USER ruling via Wilma, 2026-11-13; fold into the 27 plan, a workload section):
   User: "workers stress when few are doing it should be a thing; an employer can earn more by making them do more
   but the industry suffers and the work becomes high stress; ... healthcare with five doctors for 1,500 people on a
   new planet. That's high stress if I ever saw one."
   1. WORKLOAD per facility = work demanded / (staff × normal capacity per worker) — production: target output vs crew;
      services (clinic, school, care, sanitation, offices): clients per staff (patients per doctor, children per carer).
   2. Running lean is a real FirmAI choice by firm type (greedy owners, squeezed public budgets run leaner): fewer staff
      than the ratio, more output per head, lower wage bill, short-run profit.
   3. STRESS builds with sustained workload above ~1.1; slow recovery. Effects: sick days (lower effective crew),
      errors/accidents (quality, reputation, accident facts), higher quits and burnout (leave job, sector or colony),
      harder hiring (sector reputation), worse service quality (a stressed clinic treats worse → health, mortality).
   4. Unions: staffing levels as a grievance and strike reason (union_disputes), esp. health, care, utilities.
   5. Visible: indicators (workload/stress by sector and district), news facts ("nurses at breaking point"), office items.
   6. Healthcare check: clinic capacity per staff today, clinics/doctors per 1,500 at founding — the founding colony
      should show a stressed health service unless the commander builds more (a real early choice).
   Anni: staffing-ratio and working-hours laws, the work-environment authority.
   **27-W data contract** (Wilma, for Ella / Wilma / Anni): (1) EconQuery.workload(world): peek-only, integers,
   {sector: stress milli 0..1000} colony-wide + per district (Ella: hot issues; Wilma: WORKING_LIFE concern).
   (2) per facility/org monthly: workload ‰ (1000 = normal), avg hours/week, staff, clients served, service tag
   (HEALTH, CARE, CHILDCARE, ...), saving from running lean (Anni: ratios, hours, fines).
   (3) facts: ECON_OVERLOAD_INCIDENT PUBLIC {sector, facility, district, owner_kind PUBLIC|PRIVATE, owner id, severity
   0..100, persons affected, workload ‰} — responsible: the Cabinet for public facilities, the company for private;
   weaker sick-day and quit-wave facts per sector; COMP_WORKPLACE_ACCIDENT gains data.workload;
   LawOps.record_greed(... OVERWORK / UNDERSTAFFING ...) monthly while it lasts (Anni's plan).
   Healthcare check done: CLINIC = 30 staff (5 G, 10 S, 15 Sp) serving 2,500; founding = 2 clinics (d:1 + the d:4
   founding project) ≈ 30 Sp for ~2,000 colonists = 15 doctors per 1,000 (Sweden ~4.3) — the founding health service is
   OVERstaffed, not stressed. Field-clinic idea CANCELLED (Wilma, 2026-11-13: the user's "five doctors" reacted to a
   misleading summary of hers). Keep CLINIC/SCHOOL staffing and the founding clinics; workload and stress arise only
   naturally (population growth, closures, lean employers or budgets) — no founding-scenario balance changes.
   **27-W law readers (Anni, in tree):** sim/law/work_law.gd (preload as WK, no class_name); levers LAW_MAX_WORKING_HOURS
   (40–70, default 60), LAW_STAFFING_RATIOS (0 none / 1 guidance / 2 binding, default 0), LAW_WORK_INSPECTORATE_BUDGET.
   WK.max_hours, WK.overtime(world, hours); WK.required_staff(world, service, clients); WK.staffing_check(world, service,
   clients, staff) → {mode, required, short, unlawful} (ratios: HEALTH 300 clients/worker, CARE 10, CHILDCARE 8);
   WK.stress_accident(workload_pm) true at ≥ 1300‰. Conduct: hours > max → LawOps.record_greed(world, org, {kind:
   "OVERWORK", facility, saving}); staffing_check unlawful → record_greed kind "UNDERSTAFFING" (Anni adds both GREED_KINDS,
   channel WORK, and the WORK inspection channel BEFORE I wire it). Stress facts carry data.workload ‰.
   Anni's staff persons (party/union/media/government) as real jobs: she suggests her persons table exposes the employer
   org/account per person and the labour market counts them in PopStore — my plan decides.
   **27-W record_greed READY (Anni):** OVERWORK and UNDERSTAFFING GREED_KINDS are in (channel WORK, SERIOUS → SEVERE
   after 6 months); WORK inspection channel via WK.inspections(world). Rules via LawOps.ensure_work_rules (law DECISIONS
   phase, new and old saves). OVERWORK: call only while avg hours > WK.max_hours(world) (always unlawful for a company).
   UNDERSTAFFING: report whenever WK.staffing_check(...).short > 0 (unlawful only at LAW_STAFFING_RATIOS = 2, otherwise
   lawful-harmful, inquiry-only). Rec fields as DUMPING: {kind, facility, saving}. Tests: tests/law/test_work_law.gd.
28. **COMPANY RIVALRY pass** (USER ruling via Wilma, 2026-11-13; plan first; after the support economy): "Do we have
   company rivalry, where they try to drive each other out or use market tactics to force each other out? Or undercut
   the competition? This should cause clashes with politics." Today firms price cost-plus; no undercutting or price
   wars; Anni's CARTEL / GOUGING / HOARDING greed kinds, MARKET channel, LAW_COMPETITION_BUDGET and leniency exist but
   no economy code records them.
   1. Market share as a goal: firms in the same good/service and district see each other.
   2. Tactics by CEO temperament and cash: undercutting; price war (below cost for a while, funded by cash/loans, to
      drive a weaker rival into insolvency, then raise prices); poaching key staff with higher wages; exclusive
      supplier/buyer contracts; hostile takeover offers to a struggling rival; buying a rival's plant from liquidation;
      cartel (agreed prices, CARTEL kind); gouging in shortages. Illegal ones via LawOps.record_greed.
   3. Consequences: concentration (market share / HHI indicator per good; ECON_MARKET_CONCENTRATION exists at COLONY
      level), monopoly prices; consumers pay; workers lose jobs when a rival dies; a news fact naming who drove it out.
   4. Politics hooks (Wilma): lobbying (donations with a request: subsidy, tariff, blocking a rival's licence, public
      contract); firms in a price war ask the government for help; monopoly prices as a voter concern.
   **28-early (Wilma-approved, right after the food trap):** (a) per-good, per-district market share and HHI;
   (b) GOUGING records — only when a SELLER sets its ask well above unit cost AND has stock to spare, never when the
   market price ratchets by itself (the food-trap price rule is not seller intent).
   **28 data contract (Anni's competition law, approved; builds after my data shape):** markets (good or sector) and
   monthly market shares ‰ per org; per firm and market: price and unit cost (predation); rival harm (share lost or
   exit, and by whom); exclusive contracts {supplier, buyer, good}; takeovers via CL.request_takeover(world, buyer,
   target, market, share_after_pm) {buyer, target, market, shares before/after, promised jobs and investment}, then
   CL.takeover_status to complete or cancel (closing a blocked deal = gun jumping, SEVERE); lobbying via
   CL.lobby(world, org, target_party_or_gov, request) with request {lever, dir} | {contract} | subsidy | tariff | block a
   rival (FirmAI decides what a firm wants, Wilma's Legislature weighs it); conduct via record_greed: PREDATORY_PRICING,
   ABUSE_DOMINANCE, EXCLUSIVE_DEALING, GOUGING, CARTEL.
   **28 competition law step 1 IN TREE (Anni):** LawOps.record_greed(world, org, {kind, market, rival, dominant:
   CL.dominant(world, share_pm), saving}) while conduct lasts. MARKET-channel kinds: PREDATORY_PRICING, ABUSE_DOMINANCE
   (SERIOUS, unlawful only when dominant), EXCLUSIVE_DEALING (MINOR, by lever), UNREGISTERED_LOBBYING (MINOR), plus
   CARTEL, GOUGING, HOARDING. CL = sim/law/competition_law.gd: dominance_pm, dominant(world, share_pm),
   needs_review(world, share_after_pm), exclusive_allowed. Merger review (request_takeover / takeover_status) is her
   step 2, before my takeovers land.
   **28 merger review IN TREE (Anni, 6/6 tests):** CL.request_takeover(world, {buyer, target, market, share_before_pm,
   share_after_pm, jobs, invest}) → {id, status CLEARED|REVIEW, due}; CL.takeover_status(world, id) → {status
   REVIEW|CLEARED|CONDITIONS|BLOCKED, conditions {divest, price_cap_months: 24}, recommendation, decision}. Complete on
   CLEARED or CONDITIONS (apply the conditions), drop on BLOCKED.
29. **CONDUCT PASS (E132) — Anni's finding, Wilma's priority: right after the support A/Bs, before more support pieces.**
   No economy code calls LawOps.record_greed: violation_track stays empty, the whole M11 company-misconduct chain
   (SAFETY/ENV/MARKET inspections, fines, licence suspension, escalation, whistleblowers, leniency, crisis-inquiry
   causes, press investigations of companies) is dormant. LawBridge._misconduct (spec §9.5: profitable and (risk ≥ 70,
   distressed, or risk ≥ 45 with ≤ 4 inspectors)) exists but only gates unlicensed operation.
   FirmAI decides misconduct by CEO risk, cash pressure and expected penalty; each kind saves real money and raises real
   risk: DEFERRED_UPKEEP (skip E116 upkeep → condition decays → hazards), SAFETY_CORNERS (accident chance up; workshops'
   quality cut at econ_consumer.gd:64 already), CONTRACT_CORNERS (builders: less supervision/quality), DUMPING (pollution
   up, WL disposal cost saved) first; then GOUGING (ask well above unit cost AND stock to spare, never the market
   ratchet); later OVERWORK / UNDERSTAFFING (27-W), CARTEL and the rivalry kinds (28). Call:
   LawOps.record_greed(world, org, {kind, facility, good, district, saving (mcr this month), since_month, ...}) monthly
   while it lasts; LawOps.greed_stop(world, fid) when it ends (record_greed returns the track id).
   **29 linking keys (Anni):** every COMP_WORKPLACE_ACCIDENT carries data.operator (org id; JO._accident_reveals then
   reveals that operator's open violations) + data.facility, and data.cause_records = [track ids] from my per-facility
   {kind → track id} map when conduct is active there. A crisis-size accident (data.crisis = true, magnitude ≥ 50) opens
   an inquiry that links by cause_records / data.hazard (vs record.hazard_ids) / data.facility → LAW_CRISIS_CAUSE_REVEALED
   + TORT. On record_greed: always rec.facility; rec.hazard_ids = the E116 HAZARD ids the conduct raises
   (DEFERRED_UPKEEP and SAFETY_CORNERS on hazardous plants); record_greed merges new hazard_ids.
30. **Public safety A60 (planning/plan-public-safety.md; Anni leads; after the support pieces: offices A/B, §8b, §8c,
   §9).** My part: economic crime drivers (unemployment, hunger, stress, inequality, informal housing, theft from
   warehouse stock), police and prison wages, budget lines LAW_BUDGET_POLICE and LAW_BUDGET_PRISONS; police stations get
   support staff under the A56 (office split) rules. Anni sends an interface note.
31. **Money stock / deflation (Wilma, right after §8b):** nominal wages and prices halve over 50 years in every arm
   (G ~1,500 → ~750) — undesigned deflation. Suspect: money piling up outside households (firm cash: private dividends
   only above 3 months of costs; PE cash, E129; the treasury) while the population grows. Track the money stock by holder
   (households, private firms, PEs, treasury, banks, off-world/EXTERNAL) every 5 years on one seed; find where it piles
   up. If idle firm cash is the cause: a general payout rule for all private firms (cash above ~1–2 months of costs,
   keeping an investment reserve for planned builds) instead of the comfort/retail special case.
32. **6-seed check of SUPPORT_A** (offices split) before it goes on by default (after §8b).
33. **A61 MONEY (USER ruling via Wilma; planning/plan-money.md).** User likes BOTH bank credit creation and an own
   currency after independence; notes it is not a closed loop — exports to the home world bring money in.
   - **M1 (cheap; after the E134 econ-only test):** a money-flow ledger by channel per year. IN: exports, migrants'
     savings, charter funding, other. OUT: imports, charter dues/taxes, profits sent home, emigrants, freight. Money
     grew only 66% in 50 years with exports running — find what eats the inflow (imports? dues? remitted profits?).
     Then propose exports as a real political lever: export promotion, export tax, home-world tariffs and quotas.
   - **M2 (after the support-economy pieces):** bank credit creation — deposits created by lending, a reserve ratio,
     capital, the interest rate; booms, bad loans, runs, bailouts.
   - **M3 (Wilma's, with me on mechanics):** after independence, the negotiation with the home world (currency union or
     own currency, savings conversion, reserves, debts, trade terms), then a central bank.
