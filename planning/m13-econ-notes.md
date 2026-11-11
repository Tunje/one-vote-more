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
