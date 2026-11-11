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

## Next (proposed)
1. Terrain.generate reads the landing region and its neighbours (coast → a sea edge, mountains → more hills,
   desert/forest → different local mix). Approved by Wilma (A35 follow-up).
2. Expansion: new settlements and outposts in other regions (mining camps in mountain regions, farms on fertile
   lowland), with distance on the globe for freight. Each settled region gets its own local grid.
3. Political overlays on the globe (who holds which region, district colours) when the colony spreads.
4. Rivers along region edges; climate seasons.
