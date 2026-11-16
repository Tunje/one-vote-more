# Hard limits: every number of ours that caps, floors, gates or times what a company, household or government may do

## Maja (econ_institutions, econ_care, and my institution code in gov_builder)

Format: constant · file · what it limits · the market fact that should stand there (or "keep: reason" / "law").

### econ_institutions.gd — public clinics, schools, offices
- `ADMIN_RESIDENTS 3000` · econ_institutions · residents one office serves at a full crew, so how many offices are needed · keep: a recipe output (what one crew produces), like a farm's yield, not a limit on what anyone may do.
- `BUILD_EXTRA` (ADMIN 450/450/15/6, care homes 120/120/5/3) · econ_institutions · the bill of material and labour to build these types · keep: a recipe.
- `TYPES[*].lever_max` (4000 …) and `CARE_MAX` (elder care 1500, childcare 3000) · econ_institutions · the largest budget a service may ask for · law: a government's choice (the lever's legal range).
- `BRACKET_MAX 50` · econ_institutions · the largest tax bracket ‰ (in bracket_pm and in the ask) · law: a government's choice (the lever's range).
- `empty_pm 200` · econ_institutions (INSTITUTIONS params) · a plant counts as low, and so a closing candidate, only when its ask is ≤ 20% of a full crew · fact: the other plants in reach hold its clients with their measured swing, and closing saves the plant's upkeep and depreciation (no fixed share).
- `margin 50` · econ_institutions · crews and capacity planned 5% above clients · fact: the measured month-to-month swing of the service's clients, per type.
- `req_gap_pm 100` · econ_institutions · a budget request counts as "up" only when the ask is 10% above the line · fact: any unmet clients beyond the measured swing (the bracket clock already uses ask > now).
- `cut_pm 850` · econ_institutions · a "lower the budget" request only when the ask is 15% below the line · fact: the line pays for more than the forecast clients plus their measured swing.
- `req_hold_m 3` · econ_institutions · a gap must stand 3 months before a request · fact: the year's forecast clients (EconForecast) exceed what the line pays; no month count.
- `cut_hold_m 12` · econ_institutions · a surplus must stand 12 months before asking for less · fact: the forecast clients stay below the line's capacity for the coming year.
- `req_every_m 12` · econ_institutions · at most one request per line a year after an answer · fact: ask again when the answer left clients unmet once the granted posts are hired (the gap measured after the answer), not on a yearly clock.
- `close_hold_m 12` · econ_institutions · a plant must stand low 12 months before closing is proposed · fact: the forecast clients stay within the other plants' room.
- `build_min_pm 300` · econ_institutions · a shortfall counts for building only from 30% of one plant · fact: build when the forecast shortfall × cost per client covers a new plant's fixed cost (upkeep + depreciation), compared with spilling those clients to plants with room.
- `0.95` in build_needs · econ_institutions · plants needed are counted at 95% of a plant's output · fact: 1 ÷ (1 + the measured swing), the same fact as margin.
- "never the last plant of a district" (plants_open < 2) and "unmet > 0 blocks closing" · econ_institutions close_candidates · closing only when the district keeps another open plant · fact: the plants in reach (the district plus those taking its spill) hold its clients; districts without a plant are already served from the others.
- the ask rounded to 10 kcr (_round10) · econ_institutions · the budget asked for · keep: the lever's step, a government's unit.
- crew share clamped 0..1000, coverage capped at 1000 · econ_institutions · a crew above full / coverage above all clients · keep: physical (more than a full crew is an extension; more than everyone is nobody).

### econ_institutions.gd — private clinics, schools, offices and care homes
- `WILL_PM` (ADMIN 30, CHILDCARE 120, CLINIC 150, ELDERCARE 150, SCHOOL 120 ‰) · econ_institutions · the most of a pool's discretionary budget it will spend on each service · fact: what the service is worth to the pool, priced from the economy: childcare the wage a parent earns by working, a clinic the workdays lost to illness, a school the wage gap of schooled workers, elder care the carer's wage freed.
- `FEE_START 1.2` · econ_institutions · a new private plant's first fee (and the fee in the founder's forecast) · fact: the fees of the private places in reach, else cost plus the measured margin of private service firms.
- `FEE_STEP 0.05` · econ_institutions · the fee moves 5% a step · fact: in proportion to clients turned away (up) or priced out (down) over places, as the freight tariff now does.
- `FEE_HOLD_M 2` · econ_institutions · the fee rises only after 2 months full · fact: none needed once the step is proportional; move each month.
- `800‰` in rule 2 · econ_institutions · the fee falls only when under 80% of places are sold · fact: any unsold place while priced-out clients stand in the district.
- `FULL_PM 950` · econ_institutions · "full" means 95% of places sold · fact: clients turned away (inst_away > 0), already counted.
- `EMPTY_PM 200` (private) · econ_institutions · "mostly empty" means under 20% sold · fact: the forecast sales at the fee do not cover staying open (crew to the sold places plus upkeep) above standing mothballed.
- `FULL_M 6` and `result12 > 0` · econ_institutions · expand only after 6 months full and a year in profit · fact: the forecast demand (turned away plus priced out at the fee) covers the extension's cost (entry_profit on the extension); no months, no last-year result (the no-last-year ruling).
- `EMPTY_M 12` and `result12 < 0` · econ_institutions · mothball only after 12 months mostly empty and a losing year · fact: the same forecast as for EMPTY_PM; no month count, no last-year result.
- rule 8 "more than half the private places lost money over 12 months" (_private_losing) · econ_institutions · no founder enters a type whose incumbents lose · fact: the founder's entry_profit priced at the incumbents' actual fees and costs (the forecast already takes their places off); drop the 12-month loss gate.
- `ENTRY_ERR 0.2`, clamped ±0.6 · econ_institutions · the founder's forecast error · fact: the measured error of earlier founders' forecasts (sales got ÷ sales forecast), with no clamp.
- `11/10` neighbour price · econ_institutions forecast · clients from neighbouring districts pay 10% more · fact: the travel cost between districts if the game has one; else drop it.
- extension cost `estimate / 4` · econ_institutions _expand · the price of an extension · keep: the shared EconRulesMat convention (Bob's list), a build bill.
- a bracket is proposed only once it is above 0 (_bracket_clock) · econ_institutions · no bracket asked for from 0 · fact: the tax base (incomes above the allowance) is known; ask = (cost of clients plus staff − line) ÷ base, so it can be proposed from 0.

### gov_builder.gd (my institution code there)
- at most one reopen and one close a month (`break` in _inst_sites) · gov_builder · the government acts on one site of each kind a month · fact: every site the build needs or close candidates name; the desk or the headroom decides.
- `estimate × 11/10` against headroom (_inst_builds) · gov_builder · a plant is ordered only when the line holds 10% over its estimate · fact: the builders' quoted price, or the measured overrun of past quotes over estimates.
- no new build in a district with a mothballed plant (mothballed > 0 skip) · gov_builder · building while a closed plant stands · keep: reopening costs less, so it goes to _inst_sites (a cost comparison in all but name; could be made explicit).

### econ_care.gd — public elder care and childcare (CARE)
- `POSTS_PER_UNIT 5` · econ_care · posts come in units of 5; a district needing less than one unit gets no site · keep the unit (the recipe, 4 G + 1 S, with E49 hoarding); replace the floor: such a district is served from the nearest site with room, as institutions spill.
- `normal` 9 (elder) / 5.5 (child) clients per worker · econ_care · how many one worker cares for · keep: a recipe.
- `STRETCH 1.3` · econ_care · staff care for at most 1.3 × normal · fact: EconWorkload's measured load (quality falls as the load rises), no hard ceiling.
- `OPEN_M 3` / `CLOSE_M 6` · econ_care · enrolment follows the places over 3 months up, 6 down · fact: enrolment follows the staff actually hired and present (EconLabor), and families leave at the rate they find other care.
- units capped at need (min(budget_posts, need_total …)) · econ_care · no more posts than clients need · keep: no clients for extra posts (plus the measured swing once margin is a fact).
- `ELDER_DEF 600`, `CHILD_DEF 500`, `ELDER_MORT 0.4`, `CHILD_REENTRY 1.0` · econ_care · centre and slope of the mortality and re-entry effects · keep: calibration of an effect (zero effect at today's coverage), not a limit on anyone.
- care sites always at a full crew (T = 1000) · econ_care · the public care crew · fact: R8_INSTITUTIONS rules 3/4 (crew to the clients) once the care lines join TYPES; today only private homes follow sales.

### Not mine, but applies to my founders
- `ENTRY_FAIL_COOL_M 36` · firm_ai (Bob) · a type stays closed to founders for 3 years after an entrant failed · on Bob's list; for institutions the fact would be the founder's forecast at the failed firm's real costs.
- the cap on companies forming at once · firm_ai (Bob) · on Bob's list.
