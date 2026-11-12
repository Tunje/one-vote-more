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

### Map and river side implemented (Terra, 2026-11-12): sim/waste/waste_map.gd, tests/waste/test_waste_map.gd
- **River flow (pure, cached per terrain)**: the river runs north to south and leaves the colony map at the south
  edge. The tributary flows into it; stretches cut off where it meets hills join the nearest flowing tile (the
  stream runs under the hills).
- **River state**, table "river", with string tile keys and integer values: `load` (this month's discharges) and
  `poll`. In NATURE, last month's load flows downstream: each tile passes on 97%, and 30% of last month's
  pollution lingers. Units: 1 000 ≈ the untreated sewage of 1 000 people for a month. Water quality is
  100·1500/(1500+poll), so 3 000 units at Landing give quality 33 there and about 40 further downstream.
- **Siting (pure)**: `candidates(world, kind)` returns the 10 best free footprints, at least 3 tiles apart.
  - Footprints: landfill 3×3, cemetery 2×2, the others 1 tile.
  - Terrain by kind. Distance wishes: landfills ≥ 6 tiles from towns and ≥ 4 from the river; incinerators ≥ 4
    from towns; recycling works and cemeteries 2–6 from towns; treatment plants by the river and downstream of
    every town.
  - Road access counts: a site off the network needs a road first. Land cost counts too: farmland and housing land
    cost more, private land double.
  - Each candidate carries its neighbours: the settlements within the NIMBY radius (landfill and incinerator 6,
    treatment and crematorium 4, recycling and cemetery 3).
- **Sites (state)**, table "waste_sites": Bob registers a footprint when he builds. Landfill fill is in ‰ and set by
  Bob. A cemetery tile holds 400 graves; burials fill it, and the overflow is returned to Bob. Once 150 lie in the
  first cemetery, it becomes a colony sight ("The Founders' Cemetery", attraction 40).
- **Map**: the river turns murky olive-brown where it is polluted. Landfills and cemeteries fill tile by tile (rows
  of graves). The Build tab gains a siting study for the six kinds: a numbered shortlist, the red "next door"
  frame, and the study in the panel. Commissioning waits for Bob's W3–W5 (WASTE_BUILD_LIVE).

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
