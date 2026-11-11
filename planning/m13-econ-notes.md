# M13 areas: economy side (Bob) — working notes

Spec: `spec-areas-v1.md` (A35). Migration plan approved by Wilma, 2026-11-11:
- **EconGeo** is the single module that knows about space.
- The transition key changes from district to area.
- AREA indicators replace district ones.
- Saves: version bump, no migration.
- Private homes are HOUSING with 2–5 units.

## A1 API (Wilma)

**Terrain** (`sim/population/terrain.gd`):

| Call | Purpose |
|---|---|
| `generate(world)` | Builds the map. Call at the start of EconSetup if not `ready(world)`. |
| `at(world, x, y)` | Terrain code: `.` plain, `f` fertile, `r` river, `h` hills, `k` rock, `o` ore, `x` rare mineral, `n` native crop, `L` landing |
| `landing(world)` | The landing tile, as a Vector2i |
| `use_at(world, x, y)` / `set_use(world, x, y, use)` | Read or set a tile's use. Claim a tile with `{"facility": fid}`; release it with `{}`. |
| `nearest_free(world, x, y, codes, reach)` | A free tile of one of `codes` within `reach`, as a Vector2i, or (-1, -1) |
| `distance(a, b)` | Tile distance. BFS hops are Bob's, in EconGeo. |
| `BUILDABLE_HOUSING` | Terrain codes housing may go on |

**AreaStore** (`sim/population/area_store.gd`):

| Call | Purpose |
|---|---|
| `place_housing(world, tile, units, built_by, band, name)` | `built_by` is GOV, COMPANY or PRIVATE. Returns the area id. Extends the adjacent area or founds one (GOV → SETTLEMENT, COMPANY → CAMP, PRIVATE → ENCLAVE). |
| `areas(world)`, `get_area`, `area_of(world, tile)` | Area lookups |
| `capacity(world, id)` | Sum of tile units. Adjust units by rewriting the tile use. |
| `residents`, `centroid`, `nearest_area` | Reads |
| `found()` | Explicit founding |
| `yearly(world)` | January: size splits (> 800 residents) and enclave splits (≥ 2 contiguous PRIVATE tiles). Called from politics for now. |

- **Split hook:** `AreaStore.change_listeners.append(func(world, moves))`, with `moves = [{from, to, band, persons}]`, called after the PopStore transfers.
  - It is a static var and is not saved, so register it in the provider constructor.
  - Bob moves pool money pro rata on each move.
- **Indicators:** granularity "AREA", keyed by area id. Politics and UI aggregate to districts.

## A37 §9: housing life-cycle and land (Bob's part, in A3)

Bob builds:
- condition and age on the S-curve decay;
- owner choices: renovate, sell, cut rent;
- quality tiers BASIC / STANDARD / UPSCALE, and their rents;
- affordability and sorting;
- land purchase and lease economics.

**Land-title interface AGREED with Anni (2026-11-11).** Module LandLaw = `res://sim/law/land_law.gd`; reads go through LQ.

- **Levers (Anni's):**
  - LAW_LAND_DISPOSAL: KEEP / LEASE / SELL, default LEASE;
  - LAW_LAND_PRICE_FLOOR_PCT: default 90, for households and the Housing Office (companies always ≥ 90%);
  - LAW_RENT_CONTROL: NONE / CAP / FREEZE. **Bob applies it:** CAP = at most +3% a year, FREEZE = no increase;
  - LAW_EVICTION_NOTICE_MONTHS: default 3.
- **Registry:** table `land_title`, sparse, keyed "x,y"; absent = government freehold. Fields: `{owner, tenure: OWNED | LEASED, lessee, lease_rent, lease_until, zoning, acquired_month, price_paid, arrears_months, history}`.
- **Asking:** `LQ.land_offer(world, tile, buyer_ref, use)` → `{allowed, mode, price, lease_rent, reason}`.
  - SELL: price = land_value (floors as above).
  - LEASE: lease_rent = land_value × 0.6% a month.
- **Bob registers hooks at startup:**
  - `LandLaw.land_value_fn = func(w, t): return EconGeo.land_value(w, t)`. Until then Anni uses 12 W_ref per tile × terrain.
  - `LandLaw.on_land_taken_fn = func(w, t, owner): EconGeo.on_land_taken(...)`.
- **Doing:**
  - `LandLaw.grant_land(world, tile, buyer_ref, mode, price, lease_months = 1188)` → `{ok, reason}`, after Bob books the money.
  - Private resale: `LandLaw.transfer_title(world, tile, seller, buyer, price)`.
- **Lease rent:** Bob pays it in SETTLEMENT from the title row.
  - A lessee who can't pay: `LandLaw.report_arrears(world, tile, months_unpaid)`.
  - At 3 months unpaid: LAND_LEASE_TERMINATED.
  - If the land is occupied: an EVICTION case, then LAND_EVICTION_ORDERED `{tiles, area, residents}` after the notice period.
- **Expropriation:** `LandLaw.expropriate(world, tiles, by, purpose, compensation)` needs a public purpose and compensation ≥ 100% of land_value (plus the remaining lease value). It then calls Bob's hook: Bob pays, mothballs and rehouses.
- **Clearance:**
  - `LQ.may_clear(world, area_or_tiles, actor)` → `{allowed, needs_rehousing, residents, reason}`. Pass `{rehousing_units}`.
  - Lawful only with rehousing capacity ≥ residents, or a court eviction order.
  - An unlawful clearance by a private landlord is reported as greed kind ILLEGAL_EVICTION.
- **Before placing anything:** `LandLaw.can_build(world, actor, tile, use)` → `{ok, reasons}`. Building on government land without a title is refused unless the builder is the state.

## Planet (Terra, 2026-11-11)
- In A2, wherever EconSetup calls `Terrain.generate(world)`, call `Planet.generate(world)` (sim/planet/planet.gd) just before it.
- It is idempotent, uses its own RNG, and stores only a small "planet" table.
- The 64×40 colony grid lives inside the landing hex region of a 10,242-region globe (`spec-planet-v1.md`).
- Freight between globe regions may matter later.
