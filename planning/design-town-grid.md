# Town grids and housing form — design note (Terra, 2026-11-15)

For: Wilma and the user; Otto (housing, R8), Bob (economy, utilities), the population side (AreaStore), Maja (desk).
Status: a note for the user to look at. Nothing is built yet. Source: plan-settlement-later.md, "Town grids and housing
form", and the user's words there.

## 1. What is wrong today

- **A settlement is a disc 12 km across.** Areas (AreaStore) never come into being in today's game: `place_housing`
  has no caller. So each of the six districts is a display settlement, a disc of radius 4 tiles (about 50 tiles of 3 km,
  some 450 km²) around a fixed anchor (`ColonyLayout.TOWN_R`).
- **Every building takes a whole 3 km tile.** That includes a clinic, a shop or a 50-home block: each takes the nearest
  free tile. About 75 buildings at the start cover some 650 km².
- **Housing has no form.** A block is 50 homes (`EconRulesHousing.BLOCK_UNITS`). There is nothing like houses,
  apartments or high-rises, and nothing to make a town grow outward or upward.
- **Commuting inside a district is free:** 0 km and 0 minutes (`Commuting.commute_d`).
- **Road safety is spread too thin.** It counts "people near a road" from those 50 town tiles, so the danger is spread
  over the whole disc.

**Scale check.** Seed 1 (v9) has 1,500 adults in year 1, 4,500 in year 25 and 6,700 in year 50. That is a few thousand
homes over six towns, or 10–25 blocks a town. As houses, a town of 1,000 homes covers about 1 km². That is a third of
one 3 km tile.

## 2. The two levels

- **The country keeps the 3 km tile.** Farms, mines, plants, depots, roads between settlements, wildlife, freight,
  private roads and SITING's land uses all stay as they are.
- **Each town gets a fine grid of 100 m cells** (1 ha; 30 × 30 cells to a 3 km tile). The fine grid exists only where a
  town is.
- **Why 100 m.** One cell holds "about ten houses or one apartment block", as the plan says. A town of a few thousand
  homes stays at a few hundred cells. At 300 m a cell would hold 90 houses, too coarse to see a town's shape.
- **Global fine coordinates.** Fine cell (fx, fy) lies in 3 km tile (fx ÷ 30, fy ÷ 30). A town is a window in these
  coordinates, so two towns can never overlap, and the tile of any cell is one integer division.

## 3. What the town grid stores, and how it stays small

Table "town", only with the flag:

```
"town": { "<settlement id>": {
    "c":     [fx, fy],                        # the centre cell (the settlement's anchor tile, middle cell)
    "cells": { "<fx,fy>": [fid, form, homes] }  # occupied cells only
  },
  "rev": int }                                # part of the layout key, as SITING's rev
```

- **Only occupied cells are stored.**
  - Streets are not stored. They are derived:
    - a lattice every 4 cells (400 m blocks) inside the town;
    - the 3 km road links through the town as main streets;
    - a local street from each occupied cell to the nearest lattice line.
  - Empty cells are not stored either.
- **Size.**
  - 6,000 homes as houses come to about 600 cells, roughly 15 KB in a save.
  - As apartments they come to about 100 cells.
  - Town buildings (clinic, school, shops, care, offices, police) add a few dozen cells.
- **Stored, not recomputed.** A cell, once built on, keeps its building until the building is gone or the cell is
  rebuilt.
  - Today's 3 km layout is worked out afresh from the facility list. It can shuffle when ids sort differently.
  - A town that shuffles its houses would look wrong, and would break "this street, this house".

## 4. Housing form

A form belongs to a housing block (the 50-home facility). The economy keeps counting homes as today. The form only says
how the homes sit on the land.

| Form | Homes per cell (1 ha) | Storeys | A 50-home block takes | Street, pipe and cable per home |
|---|---|---|---|---|
| HOUSE (detached and semi) | 10 | 1–2 | 5 cells | about 15 m |
| APARTMENT (walk-up, 3–5 storeys) | 60 | 3–5 | 1 cell (with a little left) | about 3 m |
| TOWER (high-rise, 10–20 storeys) | 200 | 10–20 | a quarter of a cell | about 1 m, plus a lift |

- **Starting forms.** The founding stock is HOUSE. A block that never names a form is HOUSE.
- **Connection length** is the local street frontage per home plus each cell's share of the trunk. The trunk runs from
  the town centre to the cell, along the street lattice, and is shared by the homes of the cells beyond it. So a home at
  a sprawling edge costs more than a home in a dense core. That is the first real reason to build up.
- **Farmland lost.** A cell on fertile or native-crop land, or on land SITING reserves for farms, counts as farmland
  lost to the town.
- **Growth.**
  - Outward: new HOUSE cells go at the free edge cell nearest the centre. Edge cells are taken ring by ring, skipping
    water, unbuildable terrain and land SITING reserves for another use.
  - Upward: an old cell is rebuilt as APARTMENT or TOWER when its block is renovated or replaced. The renovation wave
    of years 25–35 (S3) is the natural moment.
- **Why a town would build up.** Land alone never forces it at this scale: a 3 km tile holds 9,000 houses. The real
  reasons are the ones in the plan:
  1. the cost of connecting each home;
  2. distance to work and services (from section 5's in-town distances);
  3. how fast and cheaply many homes can be built;
  4. what families prefer;
  5. farmland at the edge;
  6. land SITING keeps from housing (a river, farmland or nature reserved around the town).
- **What to expect.** With today's colony sizes, apartments will appear in the larger towns and high-rises will be
  rare, unless land is reserved around a town. That is how it should be, and the user should know it before we build.

## 5. What each side would read (proposals; the owners decide)

### Otto (housing, R8)
- **Cost per form**, as factors on the 50-home block's build cost and months. Starting guesses:
  - HOUSE 1.00, APARTMENT 0.85, TOWER 1.15 per home (structure and lifts).
  - Build months: HOUSE 1.0, APARTMENT 1.2, TOWER 1.6.
- **Appeal by household type.**
  - Families with children prefer HOUSE.
  - Singles and the old accept APARTMENT near services.
  - TOWER is the least liked by families.
- **Form choice** joins the developer's rule 5 (build): the form with the best forecast profit wins.
- **Rent by distance to the centre**, which TownGrid can give per block. With it, rebuilding upward near the centre
  pays and outward at the edge does not.
- **Reads:** `TownGrid.form_of(fid)`, `TownGrid.connection_m(fid)` (per home), `TownGrid.centre_km(fid)`, and
  `TownGrid.edge_cells(town)` (room to grow outward).
- **Writes:** the form of a new or rebuilt block, `TownGrid.set_form(fid, form)`, or a field on the project that the
  grid reads when the block opens.

### Bob (economy and utilities)
- **Connection cost**: `connection_m(fid)` × a price per metre for road, pipe and cable. It is paid when built, and as
  upkeep and losses per metre after. Power and water are counted by district today, and this would be their first
  per-home cost.
- **Commuting inside a town**: `TownGrid.in_town_km(home fid, work fid)`, or a district average by block. That gives
  minutes and a mode (walk under 1.5 km, else bus or car) instead of 0 km. A bigger, sprawling town then really costs
  time.

### Population (AreaStore)
- **An area becomes a neighbourhood** of the town grid, once areas are switched on: a set of contiguous cells bounded
  by streets, instead of a set of 3 km tiles.
  - Its "tiles" stay as the 3 km tiles its cells touch, so readers of `tiles_of` keep working.
  - It gains "cells".
- **The 800-resident split** cuts along a lattice street through the area's cells, so the two halves are real
  neighbourhoods.
- **Until areas exist**, a town is the whole district settlement.

### SITING (mine, already built)
- **Uses become two-level.** A 3 km tile reserved HOUSING is where a town may grow. Fine cells inside a town can carry
  their own use (a park as NATURE, a shopping street).
- **Town buildings get fine cells.** `site_options` for a clinic, school, shop or care home gives fine cells in the
  town. Each option says how far it is from the homes it serves (homes within 500 m) and from the main road.
  `place_at` takes a cell.
- **Country buildings** (farms, mines, plants, depots) keep 3 km tiles.

### ROAD_SAFETY (mine, already built)
- **People near a road** are counted from homes in cells within 300 m of the road's line through the town, not from
  whole 3 km tiles. A road through a dense core is dangerous; the same road past the edge houses much less so.
- **Over- and underpasses** stand at a cell where a lattice street meets the main road.
- **A bypass** keeps the old road at the town's edge, out of the cells.

### Maja's desk and the government (later)
- Plan a town: reserve uses on cells.
- Allow apartments or towers in a quarter.
- Choose a clinic's cell.
- Neighbours objecting to a tower next to their houses.
- Municipalities' first powers: building and streets.

## 6. How the town view could be drawn

- **The country map** draws each town as its real footprint: the 3 km tiles its cells touch, shaded by how full they
  are. It no longer draws the 12 km disc.
- **The town view** opens on a click or zoom:
  - its own window of cells, 4–8 pixels a cell;
  - HOUSE cells as small roofs, APARTMENT as blocks, TOWER as tall blocks, shaded by storeys;
  - streets as thin lines (the lattice) and main roads as thick ones, with crossings and passes marked;
  - town buildings as their icons;
  - the land use and the farmland at the edge.
- **Hovering** shows a cell's block: form, homes, owner, condition, connection metres, and distance to the centre.

## 7. What is groundwork (flag TOWN_GRID), and what needs its owner

**Groundwork I can build alone, behind TOWN_GRID, with nothing reading it** (as with SITING):
1. TownGrid: the fine coordinates, the "town" table, FORMS (the table in section 4) and a monthly sync in the NATURE
   tick.
   - Each new HOUSING block gets cells at its town's edge, in its form (HOUSE unless set).
   - Each new town building (clinic, school, shop, care, office, police) gets a cell near the centre.
   - Blocks and buildings that are gone free their cells.
   - It is stored, deterministic, and identical after save and load.
2. Queries: `cells_of`, `town_of`, `form_of`, `set_form`, `connection_m`, `centre_km`, `in_town_km`, `edge_cells`,
   `footprint`, and `homes_in(cells or tile)`. All are pure.
3. Unit tests and `--check-only` only. No game runs.

**Needs its owner, or a switch-over with its own A/B later:**
- the forms in housing cost, choice and appeal (Otto);
- connection costs and in-town commuting (Bob);
- areas as neighbourhoods (population);
- the layout reading the grid: town buildings on cells, the town footprint instead of the disc, and ROAD_SAFETY and
  SITING on cells.
  - This moves buildings off their own 3 km tiles. It changes routes, commuting and accidents, so it needs an A/B when
    the machine is free.
- the town view (UI);
- the desk's decisions (Wilma, Maja).

## 8. Questions for the user

1. Is 100 m for a cell right, and are three forms enough (house, apartment, high-rise)? A row-house or terrace form
   between house and apartment would be easy to add.
2. Should the first towns start as houses only, with apartments only by rebuilding, or may a new block be built as
   apartments from the start when it pays?
3. Expect apartments in the larger towns and high-rises to be rare at today's colony sizes, unless land is reserved
   around a town. Is that the intended feel, or should towns build up sooner?
