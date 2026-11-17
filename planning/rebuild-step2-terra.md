# Rebuild step 2: Terra's piece. Where a plant stands, the land under it, and the plain map

Terra, 2026-11-17. Wilma's step-2 brief: "Where a plant stands: land owned by the colony, a plant on cells or tiles,
siting for a new plant; the plain map showing plants". Reviewed by Maja, and by Anni for land. Written against
rebuild-company.md 3, 5, 9.8, 12.1 points 3 to 6, and against what Bob, Anni and Maja agreed with me today.

## What it does

**One record of where a plant stands, on the map** (agreed with Bob). The new module is
`game/sim/transport/site.gd` (`Site`, preloaded). Bob's plant record keeps no place.
- A TOWN plant holds town-grid cells, in the "town" table: cell → [id, form, homes].
- A COUNTRY plant holds its 3 km tile, in the "site" table under "placed".
- Which setting a type stands in is Bob's type-table column (`TypeTable.setting`).
- Read a place with `Site.of(world, id)`: {where, tile, cells, town, block, homes}.

**Homes are recorded once, in the cells** (Wilma's step-2 decision). Whoever lays a homes plant passes its number of
homes. A landlord's client places are `TownGrid.homes_of(world, plant_id)`. Bob keeps no homes field.

**Siting for a new plant** (12.1 point 5: "the best-scoring free place for its type"):
- `Site.choose_country(world, type, sixths, n)` scores every free tile of the type's terrain anywhere on the colony
  map:
  - distance from the nearest settlement counts against it (a point a tile);
  - a road beside it +3;
  - fertile land for a farm +4;
  - ore under a mine +6;
  - a river for a waterworks +5;
  - next to homes −6 for anything but a farm.
  - Not offered: settlement or town tiles, the sea, the river, a zone that forbids the type (land law's zones, Anni),
    or a full square.
- `Site.choose_town(world, area, type, sixths, n)` uses the town grid's cell scoring and blocked cells. It skips:
  cells taken, the wrong terrain, the zone, a street block another area owns, and a full square.
- Both are pure.

**A plan holds its site, and the plant gets it the day it opens:**
- `Site.hold(world, plan_id, type, sixths, site, homes)`;
- `Site.open(world, plan_id, plant_id)`, whose log row has the plan as `ref`, so it joins Bob's PLANT row;
- `Site.release(world, id, why)`.
- `Site.place(world, plant_id, site, homes)` lays a plant directly: the government's plants and the landing shelters
  in month one.
- Each month, `Site.step_month` frees places whose id is neither a plant nor a held plan.

**Squares** (5, 12.1 point 4): one full size per type (6 sixths) in a square. The square is the 3 km tile in the
country and the 400 m street block in a town (the block of the plant's first cell). The chooser never offers a full
square, and place/hold refuse one. A closed plant still stands and still counts (12.1 point 6).

**Land** (Anni's decisions: titles per cell "c:fx,fy" with the tile's as fallback; no row = the colony's):
- Step 2 writes no titles; all land is the colony's.
- `Site.land_price(world, site, bill_credits)` = 10% of the bill × the mean value of the place / 1000 (9.8, 12.1
  point 3). That is what a plan pays at step 3; land law's offer calls it with the plan's bill.
- `Site.land_value_milli(world, key)` is registered as land law's `land_value_fn`:
  - a town cell is the land of 8 homes (8 × 10% of a home's bill × value);
  - a country tile is the land of a full-size farm (10% of its bill × value).
- Bills are the type table's (`Site.bill_credits(type, size)`: building work, material and components at their
  starting prices).

**Zoning is land law's one record.** Siting's own reservations (FARMLAND/HOUSING/INDUSTRY/NATURE/OPEN) are gone; nobody
called them. A type's zone use: a farm FARM, a mine MINE, homes HOUSING, other country plants INDUSTRY, town
buildings SERVICE.

**Blocks claimed** (owed from step 1): when the town grid lays a cell, it claims the cell's block for its town's area
(`AreaStore.claim_block`). The town candidates skip blocks another area owns.

**A town gets its grid with its first building** (`TownGrid.ensure_town`): public fact TOWN_GRID_LAID plus a log row.
The old "due" thresholds, the step-up and the monthly laying from the facility list are gone; every plant is laid
explicitly.

**The plain map shows plants.** ColonyLayout reads them from their recorded places:
- `ColonyLayout.facility_tiles(w)` gives id → tile;
- `ColonyLayout.plants(w)` gives id → {type, sixths, plan, closed, company, tile, area, district}.
There is no guessed placement any more. The colony map draws every plant by type with the type table's 30 names and
icons:
- a closed plant darker;
- a plan's site faint, "being built".
Its card shows the size, the company, the town, cells and homes or the tile, the district, and what its land is worth.
The planet view, the window vista, the town view, transport's nodes, road safety, wildlife, the waste map and the
planet's attack facts read plants the same way.

**Logbook rows:** SITE placed / held / opened / released (why: type, sixths, where, tile, cells, homes, score and its
parts, square); TOWN grid laid; TOWN forms set.

## Decided by me (obvious answers)

- A country plant may stand anywhere on the colony map; distance is in the score, not a cut-off. The nearest ore lies
  25 to 38 tiles from the landing in seeds 1, 2, 3 and 7, so any reach short of the map would forbid mines.
- A town plant's square is the block of its first cell, even when a big homes plant spills into the next block.
- The landing shelters are laid in HOUSE form, 8 to a cell (agreed with Maja); 400 homes take 50 cells.
- A held plan's type and size are kept with the hold. The plan itself is Otto's; this is the site's own note, dropped
  when the plant opens.

## Tests

`tests/transport/test_site.gd`, 6 tests:
- a farm on its best tile, recorded once, in the log;
- one full size per type in a square;
- the landing shelters as 400 homes on 50 cells in the Landing's blocks;
- a plan holding a site and handing it to its plant, a plan given up, and the monthly tidy;
- the zone deciding;
- the land price and land law's hook.

`tests/transport/test_landfall.gd`:
- the systems-on check no longer names siting (its file is gone);
- the "grid from the first home" test moved into test_site, where the shelters do it.

## Maja's review (2026-11-17) and my answers

1. The shelters as ONE plant of 400 homes was wrong: a LANDLORD's full unit is a block of 50 homes (Bob's row; Otto's
   count). **Fixed:**
   - place / hold refuse more homes than the plant's size holds (`Site.homes_cap`: the type row's client places for
     its size), and any homes for a type that has none;
   - the test lays 8 plants of 50: 7 cells each, one per street block, 400 homes in the Landing's blocks.
2. Towns and neighbourhoods (from my review of Maja's piece; she added `AreaStore.town_of`, `areas_of_town` and
   `area_for_new_block`). **Fixed:**
   - blocked() refuses a block of another TOWN, not another area;
   - lay() lets a block nobody owns join the neighbourhood `area_for_new_block` picks;
   - a plant's area is the owner of its first cell's block.
   - New test: a neighbourhood split off the Landing stays in its town, the town still builds there, and a shop there
     is the neighbourhood's.
   - `boundaries()` now orders cuts by kind, then the more compact parts (`TownGrid.spread_km`, Maja's measure, now
     one rule), then the even split, then position.
3. Nothing in the plan said differently.
4. A block claimed only by a plan that was given up should go back to free. Agreed. Maja adds
   `AreaStore.release_block`, and `TownGrid.free_cells` calls it for each block left with no cells.
5. Noted for Bob's endings (step 5): `Site.step_month` runs in NATURE, so a plant deleted later in a month keeps its
   cells until the next month.
6. Noted for step 3: `choose_country` loops tiles × settlements. Watch its cost once rule 7 makes plans every month.

## Anni's review of the land side (2026-11-17) and my answers

1. A town placement checked the tile's zone, not the cell's own (Anni zones cells, "c:fx,fy"). **Fixed:**
   `Site.zone_allows` takes a cell key or a tile, and `TownGrid.blocked` asks the cell. Tested: a cell zoned FARM is not
   offered to a shop.
2. **Added** `TownGrid.homes_on_cell(world, cell)`, which land law reads for evictions. Tested.
3. Two prices for one piece of land (a plan's land_price on its own bill against land law's land_value per key).
   **Agreed with Anni; for Wilma at step 3:** the sale price is `Site.land_price` for the plan's bill; land law's floor
   and lease rent are taken on that figure, passed in by the plan; land_value per key stays for leases with no plan,
   expropriation and screens.
4. Who owns a country tile shared by six family farms. **Agreed with Anni; she builds it at step 3:** the tile's title
   keeps the plots sold off it in sixths ({holder: {type, sixths}}), and the rest stays the colony's.
- The zoning in test_site now goes through land law (`LawOps.init_world`, `ensure_rules`, `LandLaw.zone`), not its
  private `_row`.

## Owed

- `commuting.gd` still reads the old facility and org tables. It comes back with staff and commuting at step 3.
- The tests waiting in tests_waiting/transport (siting, town grid, transport, freight roads, road safety) are rewritten
  against Site when the first plants are founded in a game (step 3).
- Siting's old site-study panel on the colony map (site_options) is gone with Siting. The map shows plants; a site
  study for the player comes back with the government's commissioning (step 8).
