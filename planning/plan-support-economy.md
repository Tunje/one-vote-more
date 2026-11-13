# Plan: the support economy (backlog 27) — Bob, 2026-11-13

User ruling (via Wilma): "you have completely missed the support workers … cleaners, janitors in every place, people in
the lobby, office workers … who pushes the papers at a power plant … where do parties sit, where is the union HQ, who
buys cookies for them, who delivers things, where are the pizza places … who drives it to you?" Plus the workload and
stress ruling (27-W) and the earlier care / sanitation plan (25), folded in here.

Today the recipes count only direct crews (farms, plants, utilities, builders, clinics, schools, ADMIN, one SERVICEHUB
type with 25 G). Sweden's employment is ~15% farming, mining and manufacturing; the rest is services. The colony stays
more primary (export base), but most jobs should still be support and services — and they grow with the population.

## 1. Target: jobs per 10,000 residents

Sweden ≈ 5,100 employed per 10k residents. The colony is younger (more children), so ≈ 4,500 at full employment.

| Category | Sweden /10k | Colony target /10k | Today (est.) | How it is built |
|---|---|---|---|---|
| Primary + industry + utilities (farms, mines, plants, CPW) | ~700 | 1,000–1,100 (22–25%) | ~1,100 | existing recipes |
| Construction (builders) | ~360 | 300–350 | ~250–450 | existing crews |
| **A. Overhead inside organisations** (office/admin, planning, cleaning, reception, logistics) | (spread over all sectors) | ~450 | 0 | ratio per production worker, at an OFFICE |
| **B. Non-production organisations** (party HQs, union HQs, newsrooms, ministries, company HQs) | ~350 | ~250 | ADMIN only | PopStore jobs paid from the org's account |
| **C. Business services** (cleaning firms, catering, couriers, office supplies) | ~400 | ~300 | 0 | a B2B market bought per staff |
| **D. Household services** (retail, cafés/restaurants/takeaway, delivery, taxis, hairdressers) | ~900 | ~550 | ~25 per hub | spending categories → several service types |
| **E. Care and public services** (elder care, childcare, sanitation, building upkeep, funerals) | ~600 | ~300 | 0 | public institutions (PES pattern) + HOUSING upkeep |
| Health and schools (CLINIC, SCHOOL, unchanged) | ~800 | as now | as now | unchanged (Wilma: no founding changes) |
| **Total** | ~5,100 | ~4,300–4,500 | ~2,500–3,000 | |

So roughly **+1,800 jobs per 10k** when everything is in — more than today's unemployment (~2,000 at 13k residents).
Overshoot into a labour shortage is possible and acceptable if immigration responds (E120 attractiveness reads jobs).

## 2. Design by part

**A. Overhead.** Every organisation gets an office staff target = production crew × sector ratio: farms 0.15,
mines and plants 0.30, utilities (CPW) 0.45, services and workshops 0.25, public institutions 0.50, builders 0.20.
Mix ~50% G (cleaning, reception, logistics), 40% S (office, admin), 10% Sp (management, planning). They work at an
**OFFICE** facility (new type: construction, upkeep, a site; on the map later with Terra), one per organisation, scale =
posts. Their wages are part of the firm's unit cost, so prices rise ~10–20%; demand rises too, because they are paid.
Watch: profits and price levels in the A/B (a ratio cut if firms fail en masse).

**B. Non-production organisations.** Party HQs (paid from party money), union HQs (dues), newsrooms (outlet
accounts), ministries (ADMIN scaled with population, not one facility), company HQs (= part A). Anni's staff persons
keep the individuals (employer org + skill tier); my labour market counts their posts in the org's OFFICE and pays them
through payroll from the org's account, so they are EMPLOYED in PopStore.

**C. Business services.** Organisations buy cleaning, catering, courier and supply services in proportion to their
staff (a new market good, BIZ_SERVICES, priced like services). Firms can enter it (a SERVICES-like plant type,
G-heavy). Later this is where rivalry (backlog 28) bites first.

**D. Household services.** Split SERVICEHUB demand into spending categories by income band: retail (goods
distribution), food service (cafés, restaurants, takeaway), transport (delivery, taxis), personal (hairdressers etc.).
Either several hub types or one hub with category-weighted staff; more income → more of these jobs.

**E. Care and public services** (the approved plan 25): elder care 1 per 9 retirees, childcare 1 per 5.5 children aged
1–5, sanitation ~30 per 10k (W1 of spec-waste), building upkeep 1 per 150 homes × age factor (in the HOUSING recipe,
paid by the owner), funerals 1 per ~20 deaths a year. Public institutions on the PES pattern with budget lines
(ECON_BUDGET_ELDER_CARE / CHILDCARE / SANITATION), default coverage elder 60%, child 50%. Lever politics weights from
the start (Wilma reviews the rows).

## 3. Workload and stress (27-W)

- **Workload ‰** per facility = work demanded / (staff × normal capacity). Production: target output vs crew.
  Services: clients per staff (Anni's WK ratios: HEALTH 300, CARE 10, CHILDCARE 8 clients per worker).
- **Running lean** is a FirmAI choice: greedy CEOs and squeezed public budgets staff below the ratio — lower wage
  bill, more output per head, short-run profit.
- **Stress** builds when workload stays above ~1,100‰, recovers slowly. Effects: sick days (lower effective crew),
  errors and accidents (quality, reputation, COMP_WORKPLACE_ACCIDENT with data.workload), quits and burnout (leave job,
  sector, colony), harder hiring, worse service quality (a stressed clinic treats worse → mortality).
- **Unions:** staffing levels as a grievance and strike reason (health, care, utilities first).
- **Law (Anni, in tree):** OVERWORK recorded while average hours > WK.max_hours; UNDERSTAFFING whenever
  WK.staffing_check(...).short > 0 (unlawful only at LAW_STAFFING_RATIOS = 2); WK.stress_accident at ≥ 1,300‰.
- **Data contract:** EconQuery.workload(world) {sector: stress ‰} colony + per district (Ella, Wilma's WORKING_LIFE);
  per facility/org monthly workload ‰, average hours, staff, clients, service tag, lean saving (Anni);
  ECON_OVERLOAD_INCIDENT {sector, facility, district, owner_kind, owner, severity, persons, workload ‰} — the Cabinet
  responsible for public facilities, the company for private ones; weaker sick-day and quit-wave facts.
- No founding changes: the founding clinics stay as they are; stress arises only when demand outgrows capacity.

## 4. Build order (each step with a 3-seed × 50-year A/B before the next)

1. **E (sanitation + building upkeep)** — simplest, fixed ratios, no new markets.
2. **A (overhead + OFFICE)** — the largest block; watch prices and profits.
3. **B (non-production organisations)** — with Anni's staff persons.
4. **E (elder care + childcare)** — with mortality and re-entry effects and coverage indicators.
5. **D (household services split)**.
6. **C (business services market)**.
7. **Workload and stress** over all of the above (it needs the staffing ratios that 1–6 create).
8. Funerals / cemetery.

Prerequisite: a stable baseline. The shared tree regressed between 4eb059f and now (seed 1, Y50: 10,779 → ~5,000),
so A/Bs wait until that is found.

## 5. Open questions for Wilma

- Overhead ratios: the numbers above, or lighter to start (it is the biggest money effect)?
- Should ministries (ADMIN) scale with population automatically, or only through ECON_BUDGET_ADMIN?
- B2B services as one good (BIZ_SERVICES), or separate goods per service?

## 6. Wilma's answers (2026-11-13) — plan APPROVED

1. Overhead ratios: keep the proposed ratios as the target, phased in (half for the first A/B, then full) to see the
   cost to firms' margins. If profits go negative, prices rise; overhead is not trimmed.
2. ADMIN: need-based by default (ministries scale with population and the number of public functions), with a budget
   line on top. A government may run it lean → overworked civil servants (slow permits, errors, Anni's StaffOps
   overload): a "bureaucracy" fight for both camps.
3. B2B: three categories matching the user's examples — FACILITY (cleaning, security, janitorial), CATERING ("who buys
   cookies"), LOGISTICS (couriers, deliveries). Office supplies go through CONSUMER, not a new service.
A/Bs wait for a stable baseline; baseline-independent parts (data tables, OFFICE recipe, unit tests) may start.

## 7. Lever rows (Wilma) for A/B time

- ECON_BUDGET_SANITATION: `["ECON_BUDGET_SANITATION", [0, 5000], <default = the line that funds full coverage at
  founding>, "LAW", {"ENVIRONMENT": 0.004, "ECON_ROLE": 0.002, "FISCAL": 0.003}, {"ENVIRONMENT_QUALITY": 30,
  "PUBLIC_SERVICES": 15, "SAFETY": 10, "GOVERNANCE": -15}, "STAFF_T_IMPL_PROGRAM", 1, false]`. Full coverage as the
  default (the fight is about cutting it), with the shortfall effects (district mortality, pollution).

## 8. Part D design note (household services) — for Wilma before building

Today: one SERVICEHUB type (25 G, high output per worker); households spend ~10% of income on services (≈ 4M/yr at
13k residents ≈ 180 jobs). Sweden has ~550 per 10k in retail, hospitality, transport and personal services. Two
things are missing, and a pure split of the hub would not add jobs:
1. **Retail.** Goods go from plant to household with no shop. Add a retail margin: household purchases of CONSUMER,
   FOOD and the D2 goods pass through shops (RETAIL facilities per district, G-heavy) that take a markup
   (RETAIL_MARGIN ~15–25%) and employ ~1 worker per X of sales. Prices to households rise by the margin; the margin is
   wages and shop profits (local income again). Food could carry a lower margin (or none at a market stall level) so the
   food trap is not made worse.
2. **Labour-intensive services by category.** Split household service spending by income band into FOOD_SERVICE
   (cafés, restaurants, takeaway — the "pizza"), TRANSPORT (delivery, taxis) and PERSONAL (hairdressers etc.), each a
   hub type with more workers per unit of service than today's SERVICEHUB. Richer households spend a larger share on
   them (the existing DISC_CAP_BAND idea), so more income → more of these jobs.
Order: retail first (the bigger block, ~300/10k), then the service categories. Opt-in ("SUPPORT_D") with a 3-seed A/B.
Open: food through retail or not; the margin level.

### 8b. Service categories — revised with the user's input (2026-11-13)

User: "services would be increased with these: think of commuting using services like buses, and with hairdressers
and the like we can increase comfort spending and add stress buying." The household services share is no longer a
fixed ~10%; three drivers set it, each with its own jobs:

1. **COMMUTING → TRANSPORT.** Each employed person travels home → work (transport spec T3). Monthly fare per commuter
   = base fare × (1 + hops between home and work district × 0.5); bus fares go to the public transport operator (CTA,
   LAW_TRANSPORT_OPERATION, bus lines on roads), with taxis a share for the I4/I5 bands. Jobs: drivers, depot staff,
   mechanics ≈ 1 per 60 commuters (bus) and 1 per 25 taxi users. Sprawl and the district jobs mix change the bill.
   Target share: 3–5% of a working household's income (Sweden ≈ 4–5% on transport services excl. own cars).
2. **COMFORT → PERSONAL and FOOD_SERVICE.** A share of income ABOVE essentials, rising by band: I1 4%, I2 6%, I3 9%,
   I4 12%, I5 15% of the surplus, split ~60% eating out / takeaway (FOOD_SERVICE) and ~40% hair, gym, entertainment
   (PERSONAL). Labour-heavy: ~1 worker per 8–10k credits a month of sales (wages ~60% of revenue).
3. **STRESS BUYING.** A household whose workers' sector stress is above 1,100‰ (27-W) shifts savings and goods
   spending into convenience: comfort share × (1 + stress excess), capped at +50% and never beyond the household's
   surplus over essentials (no spiral: it cannot push a household into debt or below its food).
Resulting household services share (incl. today's SERVICEHUB) ≈ 12–20% of disposable income depending on band,
stress and commute — about +250–350 jobs per 10k on top of retail.
Build after the A/Bs of A, E and D-retail; commuting needs Terra's home–work hops (T3) — use district hops until then.

### 8c. Commuting fleet, breakdowns and the blame chain (USER ruling via Wilma, 2026-11-13; build with the commuting step)

User: "Vehicle maintenance? Do public buses break down? Cause accidents? What if there aren't enough? What happens to
work then, wouldn't companies be furious? What if the power station shuts down because the workers can't get to work
when a bus broke down. Scandal! And what if this happened because the leaders cut funding to public transport again?"

1. **Fleet.** CTA owns buses (table "bus": count via ids, age, condition 0..1000, seats ~50). Maintenance from fares +
   a new line ECON_BUDGET_PUBLIC_TRANSPORT (row for Wilma to review). Condition decays ~0.5%/month, ×3 when the
   maintenance budget is short; mechanics' work restores it. New buses are bought (imported kits or local assembly
   later) when capacity is short and money allows.
2. **Breakdowns and accidents.** Monthly breakdown chance per bus = 0.2% + 3% × (1 − condition) × age factor; a
   breakdown takes the bus out for 1–3 months (repair queue = mechanics). Accident chance per bus ≈ 0.02% × (1 +
   road-condition and traffic factor from Terra) × (2 − condition); injuries → an accident fact (CTA responsible,
   with data.condition, data.maintenance_short), Anni's TORT case and the vehicle-safety inspection.
3. **Capacity.** Seats in service vs commuters per district pair (district hops until T3). Load > 100%: overcrowding
   (WORKING_LIFE and stress input); > 130%: the excess commuters cannot get to work that day.
4. **Absence bites.** Commuters who cannot reach work reduce the employing facility's effective crew that month
   (by district pair). Output falls with crew; an ESSENTIAL plant (POWER, WATERWORKS) below its minimum crew trips the
   existing utility outage. Firms with missed output emit ECON_COMMUTE_DISRUPTION (business complaint, the employer
   named) and may lobby via CL.lobby for transport money (FirmAI decides).
5. **Blame chain.** Every fact in the chain carries `cause` links (fact explain chains exist): outage ← commuters
   absent ← breakdowns ← fleet neglect (maintenance short N months) ← the budget cut (bill id and the governing
   parties, from the lever history). The press, Ella's hot issues and the opposition can then say "the blackout
   started with a bus" and name who cut the line.
Jobs: drivers 2.5 per bus in service, mechanics 1 per 4 buses, depot staff 1 per 10 buses (≈ 1 bus per 60 commuters →
~40–50 transport jobs per 1,000 commuters).
Terra (cc): road condition / traffic factor per district pair, and later the T3 home–work routes.
- ECON_BUDGET_PUBLIC_TRANSPORT (Wilma, for A/B time): `["ECON_BUDGET_PUBLIC_TRANSPORT", [0, 5000], <default = full
  maintenance at founding>, "LAW", {"ECON_ROLE": 0.004, "ENVIRONMENT": 0.003, "FISCAL": 0.003}, {"INFRASTRUCTURE": 30,
  "JOBS": 10, "WORKING_LIFE": 10 (SAFETY 10 until WORKING_LIFE exists), "GOVERNANCE": -15}, "STAFF_T_IMPL_PROGRAM", 1,
  false]`. §8c APPROVED.
- **Terra network contract (agreed 2026-11-13):** Transport.route_factor(world, from_d, to_d) → int ‰ (1000 good road;
  condition, kind, congestion, lanes, junctions, closures; no road 3000) and Transport.commute_d(world, from_d, to_d) →
  {hops, km, minutes, links, factor}; Transport.incident_site(world, from_d, to_d, salt) → {link, tile, junction} (my
  "econ.buses" draw decides IF, Terra WHERE); crashes call Transport.add_accident; facts BUS_BREAKDOWN / BUS_CRASH carry
  data.tile and data.link. Bus lines derived by Terra from my EconQuery.commuting(world) (per pair: commuters,
  bus_commuters, taxi_users, buses_in_service, seats, load_pm, breakdowns_m, crashes_m; plus fleet totals); T7 reads
  vehicle counts from it (buses × trips, taxis ≈ users / 1.5). T3: I consume Terra's Transport.commutes(world) →
  [{from_d, to_d, n, fid}] (from staff keys incl. builder crews), area-level later with the same shape.
