# Rebuild step 1: Terra's part (the ground, the map, the roads, the planet)

Terra, 2026-11-17. Wilma's order for step 1 (rebuild-company.md v13, 12.1, 12.2, 12.4 point 33, 13 step 1). Settled
with Maja; her side is planning/rebuild-households.md section 2. Reviewer: Maja.

## What is on for good now

1. **The colony starts as one place.** ColonyLayout no longer lays out six display districts (ECON_ANCHORS and the
   anchor search are gone). Settlements are the areas. Before the first area is founded, there is one place,
   `ColonyLayout.LANDING`, at the landfall tile. With Maja's population provider, the landing area "Landing" exists
   from new_game. `ColonyLayout.anchors(w)` (renamed from `econ_anchors`) gives each district the tile of its first
   settlement, so it is `{}` until districts exist. Readers fall back to the landing tile.
2. **No roads beyond the landfall place.** The founding network joins the settlements that exist at the first NATURE
   tick. With one place that is no link at all. The port is at the landfall place and reachable from it.
3. **The town grid is on, with a grid from the first home** ("Below 250 start a gridd anyway and only use what you
   need"). The GRID_HOMES, GRID_SOME_HOMES and GRID_BUILDINGS thresholds are gone; a settlement is due as soon as it
   has a home or a town building. A house cell holds **8** homes (the user's house plots, 2026-11-16), not 10.
4. **Street blocks**, the pieces Maja's areas are made of: one global lattice (a street every 4 cells), so a block
   is fixed by geography.
   - `TownGrid.block_of(cell)` → "b:bx,by"
   - `block_cells(block)` → its 16 cells
   - `blocks(world, town)` → the blocks with anything built
   - `block_homes(world, block)`
   - `boundaries(world, blocks)` → every street line that would cut a set of blocks in two, strongest first:
     RIVER, FAST_ROAD (70 km/h or more), MAIN_STREET (any colony road), STREET. Within a kind the cut that splits the
     homes most evenly comes first. Maja's split by reach chooses from it.
5. **On, not behind switches** (12.4, 33): town grid, siting, seasons, ecology, freight on roads, road works and road
   safety. Each `on()` returns true. Their readers elsewhere follow:
   - the road safety law (`road_safety_law.gd`);
   - the government's wildlife duty (`gov_wildlife.gd`);
   - road works (`GovBuilder.road_works_on`);
   - the lever LAW_SPEED_NEAR_HOMES and the planet's ECO lever, which no longer carry `"requires"`.
   **Private roads and tolls stay off** (left out for now, 12.12), with the three toll levers still requiring
   PRIVATE_ROADS.

## Tests

- New: `tests/transport/test_landfall.gd`, 5 tests:
  - one place and no roads at the start;
  - the systems on and private roads off;
  - blocks fixed by geography, and 8 houses to a cell;
  - a grid from the first home;
  - where an area could be cut (a river beats a street).
- Back from `tests_waiting/`, made to pass: `planet/test_seasons.gd` (6), `planet/test_ecology.gd` (6),
  `planet/test_wildlife.gd` (7). Their "with the flag off nothing changes" checks are deleted, since the systems
  cannot be off now. One more check is deleted: "the colony's emissions reach the planet", because no company emits
  until the company object exists (it comes back with pollution).
- Deleted: `test_the_mining_town_stands_at_its_ore` in `tests/planet/test_colony_region.gd`. It tested where the old
  display district Redrock stood, which the rebuild removed.
- Still waiting, and why (all now call `GameSim.make` instead of the missing `EconFace.sim_make`):

  | Test | Waits for |
  |---|---|
  | transport/test_transport, test_freight_roads, test_road_safety, test_commuting | a second place joined by road (areas growing, step 2/3) |
  | transport/test_town_grid, test_siting, ui/test_colony_map, ui/test_town_view, waste/test_waste_map | plants and homes (the plant record, step 2) |
  | planet/test_expedition_worlds | reads EconSim; rewritten when the new start exists |
  | transport/test_private_roads | left out for now (12.12) |

## Decided by me (obvious answers)

- Before any area exists, the landfall place's id is `"landing"`. Once Maja's area is founded, the area's id is used.
- The street-block key is "b:bx,by" on a global lattice, so it never depends on which town a block belongs to.
- A cut line counts a river or road as "along" it when the run is more along the line than across it and lies nearer
  that street than the next one. Rivers and roads are taken as straight runs between 3 km tile middles, the same way
  the town view draws them.
- 70 km/h and over is a fast road for a boundary (road safety's design speeds: track 40, road 80, paved 110).

## What step 2 needs from me, and what I need from step 2

- **The plant record.** The map, the town grid, siting, wildlife, waste and the town view all read plants from the
  old `facility` table: type, tile, area, district, form, scale, closed. I propose the step-2 plant record keeps those
  field names, or gives one read (`EconFace.plants(world)`) that returns them, so the plain map shows plants by place
  and type as soon as they exist. Until then the map shows the landfall place and nothing else.
- **Prices for roads.** `transport.gd:1025` and `private_roads.gd:86` still price a road with the old EconData
  numbers. They move to the new type table's prices at step 2.
- **Districts on the screens.** The screens still name districts from EconData.DISTRICTS. Law already has the reader:
  `LQ.districts(world)` and `LQ.district_of(world, area)` (Maja). The screens move to it at step 11, as the plan says.

## Maja's review (2026-11-17) and my answers

1. `facility_tiles(w, anchors)` had a parameter with the same name as the function `anchors(w)`. **Fixed:** it is
   `given_anchors` now.
2. `TownGrid.town_for` falls back to matching the plant's district against the settlement's district. Those are
   different things now: an old economy id against law's district. **Owed at step 2:** a plant's town is the area of
   its tile or block (`AreaStore.area_of`, `area_of_block`), not a district.
3. The `boundaries()` comment said "below / above". **Fixed:** "the smaller-coordinate side (west for x, north for y)".
4. `on()` always true keeps the switch in shape. Accepted for step 1. **Owed:** remove the `on()` calls and their
   else branches. The readers of the seven, by file (call sites):
   - planet_provider 4, planet_wildlife 3, planet_birds 1;
   - transport 4, colony_layout 1, siting 1, town_grid 1, private_roads 1;
   - gov_builder 5, gov_wildlife 1, road_safety_law 1;
   - colony_map 3, colony_vista 2, planet_view 4, town_view 1;
   - plus the `if not on(world)` guards inside siting (7), freight_roads (10), road_safety (6) and planet_ecology (2).
5. `ColonyLayout.LANDING` gives the same place a second id. Checked: nothing stores it. Transport's nodes are read live
   from the settlements, and links store tiles only. With Maja's provider the Landing area exists from new_game, so a
   running game never sees "landing"; only bare worlds without GameSim do. test_landfall passes both ways.
6. **Owed once Maja's piece is merged:** TownGrid calls `AreaStore.claim_block(world, tid, block_of(cell))` when it
   lays a cell, and the candidates skip a cell whose block belongs to another area.
7. **Owed once Logbook is committed:** a Logbook row beside TOWN_GRID_LAID and TOWN_FORMS_SET.

Also fixed after the full suite:
- With ecology always on, bird facts appear in every game. They had no "hex", so `planet_provider._report_birds` now
  gives them the colony's landing hex (test_climate checks that every planet fact names its hex).
- `tests/planet/test_climate.gd` (and the planet tests' setup) wrote the old "econ" table directly. The shared tree's
  core_util now keeps that state in "econ_wait", so the tests write through `CoreUtil.st(w)` instead.
- `tests/ui/test_office_desk.gd` checked that the window view shows roads. At the start
there are none now (12.2), so it checks that the view shows exactly the built roads.

## Maja's piece, reviewed by me

Faults I sent her, both in `area_store.gd`:
- `claim_block` writes through a peeked dictionary.
- `split` does not move blocks.

Risks:
- `area_of_block` is a linear search; it needs an index.
- `found_landing` returns the first area, not necessarily the Landing.
- Two providers generate the terrain.

## Limits seen

- None in a game yet: nothing is built in step 1, so the town grid, the roads and siting have nothing to act on.
