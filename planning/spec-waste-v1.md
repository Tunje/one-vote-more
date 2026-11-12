# Spec: Waste, sewage and the dead (v1)

User decision 2026-11-13 (A45): "Cemeteries, disposal, do we handle trash? What happens to that? Becomes
pollution?" → "I think we can do all once the current chronicles have run; until then build a plan for it."

Today: a district pollution index fed by plants (recipe "poll") and decaying monthly; illegal dumping exists only as
a crime type in law (DISCHARGE_WASTE) with nothing producing waste; no household trash, no sewage, no cemeteries —
the dead simply leave the population. With E120 (age-structured demography) the colony grows to 6–15k and the
founders' death wave arrives around Year 40–60, so this becomes visible.

Owners: **Bob** W1–W3, W5 (economy), **Terra** W4 + sites (map, river), **Anni** W6 (law), **Wilma** W7 (politics,
UI, news). Order after the v5 chronicles: W1 waste + W2 collection first (they create the visible story), then W3
disposal, W5 sewage, W4 cemeteries. Integer state; ledger closed; determinism and save/load.

## W1. Waste is produced (Bob)

- Households: kg per person per month rising with income band and with durable goods replaced (D2 wear) —
  richer colonies make more trash.
- Industry: per plant type (MINE tailings, PROCESSING slag, BAKERY food waste, POWER ash, TEXTILE offcuts…),
  scaled by output and plant tier (kits cut waste: TIER_IN already models input waste).
- Waste is a quantity per district per month in two streams: MUNICIPAL and INDUSTRIAL (hazardous share by type).

## W2. Collection (Bob)

- A service with jobs (G heavy): the public Sanitation Department (CHO-like) or private contractors under a
  franchise; capacity from crews and trucks; cost from the ECON_BUDGET_SANITATION line or fees.
- Uncollected waste accumulates per district: smell and rats (concern hits: HEALTH, ENVIRONMENT, HOUSING
  attractiveness), disease risk (feeds M11 epidemics), and a front-page story. A sanitation strike (unions) makes
  piles grow fast — the classic.
- Industrial waste: firms pay a disposal fee per tonne, or a greedy CEO dumps it (DISCHARGE_WASTE, hidden; adds
  pollution where dumped; discovered by inspections, inquiries or journalists → Anni's crime path, a scandal).

## W3. Disposal (Bob, sites with Terra)

Each option is a real facility on the map with capacity and side effects:
- **Landfill**: cheap; uses land tiles; fills up over years (capacity in tonnes); leaks into ground and river water
  (pollution downstream, W5); a full landfill must be replaced by a new site.
- **Incinerator**: burns waste, produces some ENERGY, air pollution in its district, ash to landfill.
- **Recycling works**: sorting labour and power; returns MATERIAL (and some COMPONENT scrap) to the market — fewer
  mines and imports; quality of sorting by skill.
- **Composting**: food and farm waste → fertiliser that raises farm yield a little.
- Collected waste goes to the cheapest legal option with capacity; when all are full, it piles at the edge of town.

## W4. Cemeteries and the dead (Terra sites, Bob economy)

- Every death needs a burial plot or a cremation. Cemeteries occupy tiles near settlements and fill up (plots per
  tile); the founders' death wave fills them fast.
- Cremation needs a crematorium (energy, some air pollution).
- New cemetery land competes with housing and farms; a full cemetery forces a choice (extend, new site, cremation).
- Attitudes come from philosophies: some archetypes insist on burial (tradition, institutions), others accept
  cremation (market, development) — a small cultural issue; burial law can offend.
- Memorials and the colony's first cemetery (the founders' graves) can become a tourist sight later.

## W5. Sewage and the river (Bob economy, Terra river)

- Waterworks supply water; homes and plants return sewage. Treatment plants (capacity, energy, staff) clean it.
- Untreated sewage and landfill leachate enter the river and pollute it **downstream** along Terra's river path:
  water quality for waterworks, farm yields along the banks, health, and tourist sites (River Falls) downstream.
- River pollution is drawn on the colony map and decays with distance and time.

## W6. Law (Anni)

NUMBER levers where possible: LAW_WASTE_STANDARD (disposal rules strictness: cost vs pollution),
LAW_RECYCLING_TARGET (% of municipal waste), LAW_LANDFILL_TAX (per tonne), LAW_SEWAGE_STANDARD (treatment level),
LAW_BURIAL_RULES (0 free choice … 100 strict: cremation required / burial only, by direction), sanitation fees.
Illegal dumping uses the existing DISCHARGE_WASTE crime; standards set the inspection rate and fines.

## W7. Politics, UI and news (Wilma)

- Parties: green vs cheap disposal; public vs private collection; recycling mandates; the landfill/incinerator
  siting fight — districts near a proposed site oppose it (NIMBY; local votes and petitions), so siting becomes a
  political decision with winners and losers on the map.
- GovBuilder / the player: order collection capacity, landfills, incinerators, recycling works, treatment plants
  and cemetery extensions; engineers-style reports for sanitation (Anni's staff: a sanitation officer).
- Office: a sanitation strike or overflowing landfill is a CALL; a siting decision an EMAIL with district reactions.
- News lines: trash piles up, sanitation strike, landfill full, new landfill fight, dumping scandal, river polluted
  downstream, cemetery full, the founders' memorial.

## Acceptance (century runs, 3 seeds)

- Waste produced grows with population and income; at least one landfill fills and is replaced per seed.
- An underfunded or struck collection service shows as piles, concern hits and news; recovery after.
- Recycling and incineration appear where governments choose them (by ideology and cost).
- Every death is buried or cremated; cemeteries expand; the founders' death wave is visible in burial counts.
- Untreated sewage pollutes downstream districts on the river; treatment fixes it.
- Ledger closed, integer state, determinism and save/load hold.
