# Spec: Settlements that emerge, grow and decline (v1)

User decision 2026-11-13 (A46): "Clusters should dominate and nothing pre-designed. That's the point of the first 4
years: select and build. It should be more of the intro to the game, where you learn to manage." + "The population
boom will fix the no-housing-built, but there needs to be an understanding that in a few years a lot of new homes
are going to be needed." + "What happened to housing becoming dilapidated? Should that not at least have held
builders in work? Buildings need more and more maintenance — we talked about that." (A37)

Today: five pre-designed settlements (EconData.DISTRICTS: Landing 900, Riverside 400, Foundry 300, Redrock 250,
Greenhill 150, Northfield empty) with fixed facilities; the area system (AreaStore: found, extend, split, merge,
enclaves) exists but the economy is keyed by the fixed districts (A2 not done); housing stock frozen at ~1,000 units
from Year 10 to 100 (no developers); the A37 housing life-cycle (spec-areas-v1 §9) was specified but never built.

Owners: **Bob** S1 (economy on areas = A2), S3 (housing life-cycle = A3 §9, developers, forecast), E120 (population);
**Terra** S2 (founding sites, settlement drawing, tiers), **Wilma** S4–S6 (founding intro, politics, forecast use),
**Anni** (land and district law, already in place). Order: E120 + S3 together (growth needs homes, decay needs
work), then S1, then S2/S4–S6. Integer state; determinism; save/load (old saves keep their fixed districts).

## S1. The economy runs on areas (Bob, = M13 A2)

Households, housing, facilities, jobs, prices and indicators keyed by AreaStore areas instead of the fixed d:1–d:6.
Districts become electoral units drawn by law over areas (as already designed). Commuting between areas comes with
transport T3.

## S2. Settlements emerge as clusters (Terra)

- A **settlement** is a cluster of areas: housing tiles plus the facilities within walking distance. It has a name
  from its place (terrain, river, compass, a founder's name, a nearby sight: "Eastfalls", "Copper Gully",
  "Okafor's Rest"), a tier and a centre.
- **Tiers by population**: CAMP (the landing camp, temporary), OUTPOST (<100), VILLAGE (100–500), TOWN (500–2,000),
  CITY (>2,000). Each tier draws differently on the map (tents → huts → houses → streets → dense blocks) and changes
  what it expects: a school at VILLAGE, a clinic and bus line at TOWN, a council at CITY (S5).
- **Founding**: new housing placed on free buildable land beyond walking distance of an existing settlement founds a
  new one (who places it: the founding commander, the government, developers, company housing at a mine).
- **Merging and splitting**: two settlements that grow into each other merge (the bigger name wins or a new one);
  a large one splits by the existing area rules (rich enclave, slum, a new quarter).
- **Decline**: a settlement whose jobs leave (mine closed, plant scrapped) loses people; below OUTPOST it becomes
  ABANDONED (ruins on the map; land can be reused).

## S3. Housing ages, needs maintenance, and the boom is foreseen (Bob, = A3 + spec-areas §9)

- Every housing block has age and condition on the A37 S-curve: barely noticeable for years, then fast decline.
  **Maintenance demand grows with age** — a steady flow of repair and renovation work for builders, using
  materials and components; owners (state housing CHO, companies, landlords) pay or neglect.
- Neglected blocks become cheap housing, then slums (with overcrowding); renovation or rebuild resets them.
  Expensive builds earn more and widen income divides; land is the state's at founding, sold or leased (A37).
- **Private developers** build when rents and occupancy are high (E120).
- **Forecast**: EconQuery.demography(world) (E120) gives births, arrivals, households forming over the next years;
  the government's planning (S6) can see the wave coming.

## S4. The founding years are the introduction (Wilma)

- The colony starts with **only the landing camp**: ~2,000 settlers in temporary shelters (tents, ship modules) at
  the landing site, the fabrication kits, seed stock and the founding endowment. No pre-built settlements.
- The first ~4 years (the commander era) are the **learning phase**, played through the office:
  - The advisers walk the commander through the first decisions as office items with recommendations and
    explanations: where to put the first farms (fertile banks), the first mine (deposits), the workshop, power and
    water, and **where to found the first settlements** (Terra's siting candidates, with pros and cons: near fields,
    near ore, on the river, near a road).
  - Each decision is a real order (housing, plants, roads); settlements emerge from where the commander builds.
  - The shelter camp is uncomfortable (concern hits, health risk) until homes exist — an early, honest pressure.
  - Guidance fades as the commander handles more alone; parliament takes over in Year 4 as today.
- AI commander (autoplay): the same choices by its persona and the siting scores, so chronicles keep running.
- Old saves keep their fixed districts (a flag); new games use the emergent start.

## S5. Politics of settlements (Wilma, Anni's law)

- Growing towns want representation: district maps are redrawn when settlements shift (the existing DistrictPolitics
  and law); a new TOWN can demand its own district.
- Tier expectations become concerns of the settlement's people (school, clinic, bus, council); unmet ones hurt the
  government there.
- Declining settlements become political (job losses, abandoned homes; parties promise revival or relocation).
- Roads decide which village thrives (transport T1/T3).

## S6. Planning ahead (Wilma)

- GovBuilder reads the forecast: state-minded governments build homes ahead of the wave; market-minded ones offer
  land and incentives to developers; a weak planning department (staff) misreads the forecast.
- When the player governs, the planning adviser sends a REPORT ("in 3 years we need about 400 more homes") and
  EMAILs with options (build, sell land to developers, incentives, wait).

## Acceptance (century runs, 3 seeds)

- No pre-designed settlements in new games; 3–10 settlements founded by Year 30 at different places per seed;
  at least one reaches TOWN, at least one declines or is abandoned by Year 100 on some seed.
- Housing stock grows with population (no 90-year freeze); maintenance and renovation keep a steady share of
  construction work; at least one area becomes a slum and at least one is renovated per seed.
- The founding years can be played through the office with adviser guidance; autoplay chronicles still run.
