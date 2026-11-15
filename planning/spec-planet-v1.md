# spec-planet-v1 — The planet (Terra)

Owner: Terra (sim/planet, ui/planet_view.gd). User brief (2026-11-11): replace the flat square map with a 3D view
of the whole planet, made of hexes with elevation, so that the colony grid survives inside them.

## User decisions
- **A whole planet of hexes in 3D.** Goldberg sphere, frequency 32: **10 242 regions** (10 230 hexagons and the
  12 pentagons any hex sphere needs). User: "I was hoping for the 10 000 range."
- **Smooth terrain, not stepped hexes.** Each region's centre has its own height, and each corner is the mean of
  the three regions that meet there. Slopes run continuously across regions; the hex grid is drawn faintly.
- **The colony grid survives inside one hex.** The 64×40 `Terrain` grid (areas, districts, land law) is the
  landing region up close. Nothing in the area, districting or land code changes.

## Simulation state (Wilma's rules: small, deterministic)
- World table `planet` = `{freq, gen, landing, uses}`. That's all that is saved.
- Heights and biomes are a pure function of (master seed, freq, gen). They are regenerated into a bounded cache
  on first use and after a load. Generation runs on its own RNG seed (`derive_seed("planet.terrain")`), so no
  shared stream moves. 10 242 regions take < 0.2 s.
- Heights: sea level 0, land 0..~95 steps (80 m per step, peaks ~7 600 m), sea floor to -40. Coarse levels
  (`Planet.level_of`): -2 deep sea, -1 shallow, 0 lowland, 1 upland, 2 hills, 3 highlands, 4 mountains, 5 peaks.
- Biomes come from height, latitude temperature and moisture (wet equator, dry belts at ~25°, wetter coasts):
  deep ocean, shallow sea, ice, tundra, desert, steppe, grassland, fertile lowland, forest, jungle, wetland,
  hills, highlands, mountains, peaks.
- Landing: temperate grassland, fertile land or forest below 1 600 m, preferably on the coast with hills nearby.
- `GEN_VERSION`: bump it when the generator changes. Saves keep the planet they were made with.

## Hooks
- `PoliticsProvider.init_world` calls `Planet.generate(world)` (idempotent) before `Terrain.generate`.
  Bob's EconSetup should call it first as well.
- `ui/main.gd`: the "🌍 Planet" button (default view) swaps the globe and the colony map. Clicking the landing
  region opens the colony map on the Terrain overlay.

## Climate, weather and pollution (DRAFT, awaiting the user's go and Bob's agreement)

**Rule (Wilma, 2026-11-11): the planet supplies CONDITIONS; it never applies economic damage.** Bob's hazard
engine (M11, spec-events-v1) turns conditions into probabilities, farm yields and damage events. Pollution drift
and greenhouse warming are Terra's physical model; Bob reads them. Politics reads the published indicators.

### What the planet computes each month (Terra)
- **Climate baseline per hex** (pure function, nothing stored): `Planet.climate(world, cell, month)` →
  `{temp_c, rain_mm, season}` from latitude, axial tilt (seasons, opposite hemispheres), height, distance to the sea
  and biome, plus the global warming offset.
- **Weather anomalies for settled hexes only** (rolled on stream `planet.weather`, persistent so dry spells last):
  `Planet.weather(world, cell)` → `{rain_pct, temp_anom_c, drought_months}` (rain_pct 100 = normal).
- **Storms**: each month, storms form where the season allows (cyclones over warm sea, dust storms from deserts,
  blizzards near the poles, heavy-rain fronts) and travel hex by hex with the prevailing winds (trade winds,
  westerlies, polar easterlies by latitude). Saved: this month's tracks only, `[{id, kind, strength 1..5, cells}]`.
  `Planet.storms_at(world, cell)` → `[{kind, strength}]` for storms that crossed that hex this month.
- **Pollution drift**: reads Bob's per-district `emissions` (last month), puts them at the settlement's hex and
  spreads a share downwind to the neighbouring hexes. `Planet.air_pollution(world, cell)` → 0..100.
- **Greenhouse stock**: one global number accumulating all emissions, with slow natural decay.
  `Planet.warming_c(world)` → global °C offset. It raises the temperature baseline and storm frequency and strength.
- **Indicators** (PUBLIC, for politics and news): `PLANET_RAIN_ANOMALY`, `PLANET_TEMP_ANOMALY` (per settlement),
  `PLANET_STORM_HIT` facts with the hex and strength, `PLANET_WARMING` (global).

### What Bob does with it (Bob)
- Drought/blight probability and farm yields from `weather()` (rain_pct, drought_months) and `climate()` (season).
- Storm damage events from `storms_at()` (housing, farms, facilities, power lines) as his hazard events. Damage is
  lowered by preparedness he and Anni already model (building quality, codes, upkeep).
- Health and environment effects from `air_pollution()` on settlements downwind (his existing pollution index
  stays the local, per-district measure).

### Others
- **Anni**: building codes and storm-proofing as law levers; liability when a greedy builder's housing fails in a storm.
- **Wilma**: blame (was the colony prepared?), the green issue from `PLANET_WARMING`, news lines for storms.
- **A weather service** (forecasting, warnings that cut storm damage): proposed as a budget line. Owner to agree.

### Tick and state
- Runs once a month in **TickPhase.NATURE** (Wilma added it: after STAFF, before TRADE), so this month's weather
  is known when farms produce. `PlanetProvider.phases()` returns `[TickPhase.NATURE]`; registered in
  `EconSim._register` (Wilma's file).
- Saved state stays small: weather anomalies for settled hexes, this month's storm tracks and one greenhouse number.
  Everything else is a pure function of the seed. Deterministic on stream `planet.weather`.

### Agreed with Bob (2026-11-11)
- `weather()` and `storms_at()` work for **any** hex, not only settled ones (outposts and ships in other hexes).
  So weather is a pure function of (seed, month, hex): smooth space-time noise gives anomalies that last months
  and cover regions, and `drought_months` is derived by looking back. Nothing per hex is stored.
- `climate()` includes `growing` (0..1 for that month), so farm yields follow the seasons without re-deriving them.
- Storm frequency per hex will be documented (expected strikes per year by kind and latitude band) for calibration.
- Emissions: never read econ internals. The final read is `EconGeo.emissions(world)` → `[{tile, amount_milli}]`
  (Bob, with A2). Stopgap until then: `EconUtil.peek_st(world).get("emissions", {})` (district → milli), read-only,
  every district treated as the landing hex.
- Phase: NATURE (Wilma's new phase, before TRADE/PRODUCTION; farms read this month's weather in PRODUCTION).
- Keyed by hex. `Planet.hex_of_tile(world, tile: Vector2i) → cell` maps colony-grid tiles to hexes (today: every
  tile maps to the landing hex). Bob queries weather per area via its centroid tile.

### Implemented (2026-11-11): sim/planet/planet_climate.gd, planet_provider.gd, tests/planet/test_climate.gd
- **Seasons**: tilt 26°, northern summer peaks in July, southern seasons reversed. Annual mean
  28 − 32·sin²φ − 18·sin⁴φ °C, minus 0.52 °C per height step (6.5 °C/km), plus warming. The seasonal swing grows
  with latitude and is smaller on coasts. The colony (38°N, 560 m) runs ~3 °C in January and ~16 °C in July.
- **Rain**: 8 + 170·moisture² mm a month; the tropics get monsoon summers, mid-latitudes slightly wetter winters.
  Weather anomalies range from 50% to 170% of normal; droughts (3+ months under 70%) start ~10 times per century.
- **Alien phenomena** (A40):
  - SOLAR_FLARE: the star's 11-year cycle. Global, strength 1..5 (mostly 1–2), about 0.5 a year. It hits every hex
    (power and electronics are Bob's call).
  - SPORE_BLOOM: jungle, wetland and forest hexes in a warm, wet season release spore clouds that drift downwind
    (blight and health are Bob's call).
  - MOON_SURGE: the two moons (7- and 11-month cycles) line up about every 2 years for coastal surges, strength 1..3.
    **Predictable**, so a prepared colony can forecast them. It hits settled coastal hexes.
  - Query: `PlanetClimate.phenomena_at(world, cell)`, alongside `storms_at`.
- **Storm strikes per hex per year** (seed 1, 100 years; for Bob's damage calibration):

  | kind | 0–15° | 15–30° | 30–45° | 45–60° | 60–90° |
  |---|---|---|---|---|---|
  | CYCLONE | 0.02 | 0.06 | 0.01 | 0 | 0 |
  | DUST | 0.01 | 0.02 | 0.01 | 0 | 0 |
  | RAIN_FRONT | 0 | 0 | 0.10 | 0.12 | 0.01 |
  | BLIZZARD | 0 | 0 | 0 | 0.05 | 0.04 |

  So a colony at 38°N should expect about one strong rain front a decade, a cyclone or two a century, solar flares
  every couple of years and, on a coast, a moon surge every two years.
- **Air pollution**: the settlements' total emissions (stopgap: econ `emissions`), smoothed (0.7 old + 0.3 new), at
  the landing hex, with a plume of 50/25/12/6% over the next 4 hexes downwind. The colony runs ~25–40.
- **Greenhouse**: stock += monthly emissions, −0.2%/month absorbed. `WARMING_PER_STOCK = 0.00002` °C per unit
  gives +0.11 °C after 20 years of the real game (seed 1) and stays below 0.3 °C after a century: barely
  noticeable (A40). A tech/industry system scales this one constant.
- **Facts**: `PLANET_<KIND>` for every storm or phenomenon over a settled hex, and `PLANET_DROUGHT` at 3, 6 and 12
  dry months. PUBLIC, no one responsible (nature), `data.hex`, `data.strength`. Damage, blame and news are for
  Bob and Wilma.
- **Indicators** (owner `planet`, NATURE, COLONY): PLANET_RAIN_PCT, PLANET_TEMP_ANOM, PLANET_DROUGHT_MONTHS,
  PLANET_AIR_POLLUTION, PLANET_WARMING. Concerns are left empty for Wilma to wire.
- **Globe**: storm tracks as cloud bands (colour by kind), smoke haze downwind, this month's weather in the hover line.

### User answers (A40)
- Alien phenomena: **yes** (solar flares, spore blooms, twin-moon surges above).
- Warming: **barely noticeable for now**; one tunable constant for a future tech system.

## The colony on its hex (2026-11-12, after A5)
- Zoom in on the landing region and the colony map itself lies on it: the 64×40 grid (terrain, areas by kind,
  facilities in ColonyMap's colours) as a texture on a mesh that follows the hex's terrain, inside the gold rim
  (`PlanetView.colony_image`, `colony_point`). Clouds thin out as you zoom in; the flag pole hides up close.
  The camera now comes in to distance 1.04.
- The flag stands on the landing site within that map. Its label shows the colony (colonists, areas) and any
  storm or phenomenon over the colony this month.
- Weather hitting the colony (`PlanetView.colony_hits`) gets a pulsing red rim. The info header gets "Over the
  colony this month: …" and last month's PLANET_* news lines.
- The colony map UI itself (A5) is `ui/colony_map.gd` (TERRAIN overlay), spec-areas-v1 §7.

## The colony map is the landing region (2026-11-12, user orders via Wilma: "fit the globe", then "the tall map") — Terrain.derive, tests/planet/test_colony_region.gd
- **Shape**: 96 × 96 tiles of 3 km (288 km) centred on the landing hex.
  - Hexes are ~210 km centre to centre but ~250 km corner to corner (median bbox 85 tiles, at most 97), so 96 holds
    the whole hex for 99% of cells.
  - The map's corners show the neighbouring hexes. ColonyMap draws the hex border faintly; on the globe the overlay
    is clear outside the hex, so the globe shows the neighbours itself.
  - `Planet.colony_frame` / `colony_dir` give the frame. `Planet.hex_of_tile` / `tile_hexes` give the hex of each tile.
  - There is no old-save compatibility for the map (user: no saves to keep).
- **Globe rivers and deposits** (pure, nothing saved, no world RNG stream):
  - `Planet.downstream(i)` / `river_flow(i)` / `is_river(i)` / `inflows(i)`: a priority flood from the sea, so every
    land cell drains to the sea. A river is a cell gathering `RIVER_MIN` = 14 cells of rain.
  - `Planet.deposit(i)`: "o" ore in hills and mountains, "x" rare minerals among the peaks, from a hash of the planet
    seed. Map and display only: the economy does not read it until Bob agrees.
  - The globe draws rivers as ribbons, and the hex tooltip names a river and any deposit.
- **Derivation** (own RNG from the planet seed and the landing cell):
  - Every tile takes the globe cell it lies in, with borders wobbling by `WARP` = 2.5 tiles. Sea cells become sea
    "~". Heights blend smoothly between cell centres, like the globe's terrain, so a higher neighbour is hillier. The
    biome is the cell's own.
  - Detail: relief noise (hills with rocky cores, more on high ground), and meadows and native-crop land by biome
    (`FERTILE_SHARE`, `NATIVE_SHARE`). River banks are fertile.
  - River: it enters from the neighbour that drains into the landing hex; with no inflow it rises at a spring on the
    landing hex's high ground. It leaves toward `Planet.downstream(landing)`, into the sea when that is the sea.
    There is one mouth and no forks: a tributary (the second inflow, else a hill stream) joins it. The grid stores
    `"mouth"`.
  - Deposits: each hex's own, as patches on its hills, plus at least 5 ore and 2 rare. If there is no ore within
    `ORE_NEAR` = 30 tiles of the middle, a 3–5 tile ore patch goes into the largest hill range there, so a mining
    town always has a site.
  - Redrock (ColonyLayout d:3, `"ore": true`) stands at its ore: ore within 3 tiles at the foot of the hills, even
    if that is further out (Wilma 2026-11-12: +0–10% road length is worth it).
  - Expedition worlds use the same derivation.
- **Sea "~"**: nothing is built on it (every build whitelist excludes it), and roads cannot enter it or cut its
  corners. Waste flow starts at the stored mouth.
- **Scale knock-ons**: tile ints are still y*W+x. The transport path heap keys use `TILE_BITS` = 14.
  `ColonyLayout.ECON_ANCHORS` distances are unchanged: the km per tile is the same, so towns sit as far apart as before.

## Tourist sites (A42, spec-demand-v1 §D4; 2026-11-12) — sim/planet/planet_sites.gd, tests/planet/test_sites.gd
- **Pure, nothing saved**: a function of the seed (globe), the colony grid (sites on the colony map) and the month.
  All numbers are ints. `Planet.sites(world)` = `PlanetSites.sites(world)` →
  `[{id, name, kind, attraction 0..100, season_mult [12 × %, January first, 100 = an average month], cell,
  dist (hex steps from the colony), km, travel_days, where, tile}]`, colony sites first, then by distance.
- **where**: `COLONY` (on the colony map, `tile` set, no trip), `REGION` (≤ 8 hex steps, a few days away),
  `GLOBE` (farther). One hex step is ~210 km (planet radius 6 100 km); `travel_days` = km / 400, rounded up.
- **Kinds**. On the colony map: FIRST_LANDING (30), RIVER_FALLS (where the river leaves the hills), GLOW_MEADOW
  (the native-crop land glows), CRYSTAL_CRAGS (rare-mineral rock). On the globe, the best of each kind in the
  region plus the two best elsewhere (spaced apart): WATERFALL (wet scarps), CANYON (dry land cut deep),
  GLOWING_FIELD (alien flora in wet jungle, wetland and forest; up to 95), AURORA_PLAIN (56–75° latitude),
  TIDAL_BORE (narrow bays the twin moons flood), SUMMIT (local tops above ~4 800 m). About 20 sites per planet.
- **Seasons**: comfort (near 20 °C) for most; waterfalls follow the rain; glowing flora peaks in the warm wet
  season; auroras in the dark winter; summits only in the climbing season.
- **This month's draw**: `PlanetSites.season_pct(world, site, month)`. It is the calendar season, then:
  - a tidal bore gets ×3 or ×4 in a twin-moon surge month (predictable: `next_surge(month)`) and ×0.6 otherwise;
  - an aurora gets +60% per solar-flare strength;
  - a glowing field gets +40% per strength of a spore bloom over it;
  - a storm over the site cuts the draw (–20% per strength, at least 20% left).
  Storms and phenomena count only for the current month.
- **Shown**: glowing pins and names (with attraction) on the globe, the site line in the hover text, sights listed on
  the landing hex; stars and names on the colony map, and the site in the tile panel.
- Bob owns visitors, hotels and spending; Wilma owns news and resentment.

## Ecology, stage 1: pollution on the land (user order via Wilma, 2026-11-15; opt-in flag ECO) — sim/planet/planet_ecology.gd, tests/planet/test_ecology.gd

User: "something with a little randomness so the planet feels different every time, potentially affected by pollution,
maybe weather can get rougher, maybe the pollution is only released in your hex then spreads to surrounding."
Rougher weather is local, over the land the colony harmed ("exactly what I wanted"). Global warming stays as A40 set it.

- **State**: planet table key "eco": {"<cell>": [poll_milli, harm‰]}, only for hexes the colony touched (a hex
  drops out under 0.5 units with no harm; a founding colony touches ~200 hexes after 30 years).
- **Random per world** (pure in the seed, nothing saved): `character()` gives resilience and sensitivity (each
  ×0.5–2) and one trait: SCRUBBER (pollution breaks down twice as fast), FRAGILE (harm costs twice the harvest),
  SPORE_PRONE (harmed land releases SPORE_BLOOM), or HARDY. `vitality(cell)` is the richness of the living layer, by
  biome × seeded noise (0 at sea).
- **Release and spread**: each economic district's emissions (Bob's recipe `poll` × activity) are released at the
  hex of the district's centre tile. To-do for Bob: per-facility emissions at the facility's own tile. Each month:
  12% drifts downwind, 6% spreads to all neighbours, 5% runs downstream (land), 3% breaks down (× resilience,
  ×2 SCRUBBER), and the rest stays.
- **Harm**: capacity = (100 + vitality/4) / sensitivity units. Harm moves toward 1000·(1 − capacity/load): it rises
  by 1.5% of the gap a month (× sensitivity) and heals by 0.4% (× resilience), so damage takes years and recovery
  decades.
- **Effects (ECO only)**:
  - Rain anomalies over a harmed hex swing up to (1 + ROUGH) = 1.6× wider (`PlanetClimate._rain_pct`).
  - Dust storms rise from land harmed above 400‰, on their own stream `planet.eco`.
  - Farm and family-farm output × `yield_pct` of the district's hex: −30% at full harm, −60% if FRAGILE
    (EconProduction, one guarded line).
  - Indicator PLANET_ECO_HARM (landing hex, milli-‰).
  - Facts PLANET_ECO_DAMAGE at 300/600/900‰ and PLANET_ECO_RECOVERY back under 300 (settled hexes and their
    neighbours, PUBLIC, no one responsible).
  - Globe: harmed land is tinted brown, turning ash grey; the hover line shows harm, pollution, capacity and
    yield; the header names the planet's trait. Vista: the ground browns with the landing hex's harm.
- **Calibration** (founding colony, ~60–100 units a month): by year 30 the landing hex has 390‰ harm on sensitive
  seed 1 and 143‰ on seed 3, with no dust storms yet. A careful colony (under ~20 units) does no harm.
- **Left out**: health (Bob's district pollution index covers it), species, ocean chemistry, clean-up and
  restoration, ecology per colony-map tile, and any change to global warming.
- **Stage 2 (agreed, next)**: a food pyramid per hex (pollinators, pests, foragers, grazers, predators), wildlife
  attacks as facts, and lever ECO_WILDLIFE_POLICY.

## Next (proposed)
1. Terrain.generate reads the landing region and its neighbours (coast → a sea edge, mountains → more hills,
   desert/forest → different local mix). Approved by Wilma (A35 follow-up).
2. Expansion: new settlements and outposts in other regions (mining camps in mountain regions, farms on fertile
   lowland), with distance on the globe for freight. Each settled region gets its own local grid.
3. Political overlays on the globe (who holds which region, district colours) when the colony spreads.
4. Rivers along region edges; climate seasons.
