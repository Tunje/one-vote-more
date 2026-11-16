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
- **Growth** (replaced by section 9, from the user's answer 3).
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

## 8. Questions for the user, and the answers (via Wilma, 2026-11-15)

1. Is 100 m for a cell right, and are three forms enough (house, apartment, high-rise)?
   **User: "Yes, enough for now."** 100 m cells; house, apartment and high-rise; no row-house yet.
2. Should the first towns start as houses only, or may a new block be built as apartments from the start?
   **User: "Up to the commander, I think."** So the allowed forms are a choice of whoever governs (the commander in the
   founding era, later the government or a municipality), not a fixed rule. They are a policy per town or for the whole
   colony, read by the growth step. The default is houses. It will become a decision type on Maja's desk and a law of
   Anni's.
3. Apartments in the larger towns, high-rises rare: is that the intended feel?
   **User: "Yes, but also: schools, utilities and other things should affect where things are made, this to not get
   perfect circular towns; like coastals building along the water, or staying close to schools and bakeries to get
   good access, or near jobs, like Rydebäck that began as housing for a power plant."**
   So growth is not ring by ring (section 4's "Growth" is replaced by section 9).

## 9. Where a town grows: scoring cells (from the user's answer 3)

New homes go to the free cells that draw people most, not to the next ring.

- **Candidates:**
  - the free cells next to the town's cells;
  - the cells around the town centre, while the town is empty;
  - cells within about 1 km of a workplace within 12 km of the centre. A new neighbourhood can start at a plant, a
    mine or the port, away from the centre, as Rydebäck did.
- **A block's cells.** A block takes its first cell at the best score. Its other cells go to the best free cells next
  to the ones it already has.
- **The score** is the sum of these parts. Each part is kept, so a site case can show why.

  | Part | Kind | Drawn from |
  |---|---|---|
  | jobs | draw | the nearest workplace (any facility that is not housing), or the port |
  | school | draw | the nearest school |
  | clinic | draw | the nearest clinic |
  | shops | draw | the nearest shop or bakery |
  | utilities | draw | closeness to cells already built (water and power are laid there); far from them is worse |
  | water | draw | the shore or a river close by |
  | road | draw | a colony road close by |
  | centre | draw | closeness to the town centre (a town keeps a core) |
  | fast_road | penalty | a fast road within 300 m, worse the faster it is (ROAD_SAFETY's speed) |
  | industry | penalty | a mine, plant or depot within 1 km |
  | noise | random | a little randomness per seed and cell, so two towns do not come out alike |

  Land reserved by SITING for a use housing may not have is refused outright, as SITING refuses it everywhere. It is
  shown as the reason, not as a penalty.
- **What it makes:** towns stretch along shores and roads, cluster around schools and works, and keep away from fast
  roads and mines.
- **The query is pure:** `TownGrid.cell_score(world, town, cell, ftype)` and `TownGrid.site_scores(world, town, ftype,
  n)`, with the parts.
- **Computed today:** every draw above, from facility positions, their types, the terrain, the roads and the town's own
  cells.
- **Needs an owner:**
  - jobs weighted by the number of jobs at each workplace (Bob's and Otto's data; today each workplace counts the
    same);
  - what a household type wants most (Otto: a family weighs the school more, the old the clinic);
  - utilities really laid by Bob's networks (today, "built cells" stand in for them).
- **The allowed forms** are a policy: `TownGrid.set_forms(world, town or "*", forms)`. The first form listed is what a
  new block is built as, unless the block names another allowed form. The default is ["HOUSE"]. A change is a public
  fact, TOWN_FORMS_SET.

## 10. A grid only when it is needed (the user, via Wilma, 2026-11-15)

User: "like the main map, maps should not become the next level until necessary."

- **Until it is due**, a settlement has no grid. A new camp or village is a number of homes on its country tile: nothing
  is stored, and there are no forms and no streets.
- **The step up.** When the settlement is due, it gets its grid. The homes and town buildings already there are laid out
  on it at once, in the order they were built, by the same draw scoring. This is deterministic, and it makes a public
  fact, TOWN_GRID_LAID, with: town, why, homes, buildings, cells.
- **What makes a settlement due** (proposed, as built): any one of these.
  - **Homes:** 250 homes or more (`GRID_HOMES`, about 500 adults). Where things stand now matters for a few hundred
    households.
  - **Uses competing for land:** 100 homes or more and at least 3 town buildings of at least 2 kinds (`GRID_SOME_HOMES`,
    `GRID_BUILDINGS`). Shops, a school and a clinic compete with the homes for the same land.
  - **Designated a municipality:** `TownGrid.step_up(world, town, "designated")`, called by whoever designates (Anni,
    Wilma). The user's floor for that is about 1,000 adults.
  - In seed 1 the four larger district towns are due at the start and two are not.
- **A settlement without a grid** gets tile-level answers from the queries:
  - `form_of` is "HOUSE" (a village is houses);
  - `connection_m` is the HOUSE figure;
  - `centre_km` is the distance from the building's tile to the settlement's tile;
  - `footprint` is the settlement's homes on its own tile;
  - `homes_in_tile` counts blocks on their own country tile.
- **Upward the same way:** no high-rise exists in a town until it has apartments. TOWER is left out of the allowed
  forms until then, even when the policy lists it.

## 11. What a home there is worth, and why a town builds up (the user, via Wilma, 2026-11-15)

User: "There needs to be a lucrativity score for buildings made; view, like the ocean or rivers, or nearness to things
makes it more expensive, like the houses in Höganäs: the closer to the coast you get the more expensive they get; it
can even shift from road to road. The step-up should come from many factors: an apartment complex on the beach may be
more attractive because you can rent them all out, or a school district has no more space, or, the most common, they
are simply cheaper living."

- **Location value per cell**: `TownGrid.value(world, cell)` → {value_pm, score, parts}. It is pure.
  - value_pm: 1000 is an ordinary cell, plus 100 ‰ for each point of score, never below 300.
  - The parts:
    - view (the sea or a river within 300 m);
    - the shore (within 1 km);
    - jobs, school, clinic, shops and bakeries;
    - a road;
    - utilities laid (any built cell within 1 km);
    - minus a fast road beside the cell, and minus a mine, plant or depot within 1 km.
  - It is per cell, so it changes from one street to the next.
  - It has no randomness, so it stays the same month to month unless something near the cell changes.
  - The growth score in section 9 is this value plus the pull of the town centre and the seeded noise.
- **Rent and price** follow the value. Otto's housing reads `value(cell)` to set what a home there rents or sells for,
  so the same house costs more by the water. TownGrid only publishes the value; Otto owns rents.
- **Building up** is a builder's or owner's decision from several motives, not one rule. What each motive reads from
  the grid:
  - **Dear land** (the beach complex): where the value is high, a block that can be let in full earns more as
    apartments than as ten houses. It reads `value(cell)` and the homes per cell in `form_table()`.
  - **No room left where people want to be:** a school's or a workplace's reach is full, so the only way to add homes
    there is upward. It reads `TownGrid.catchment(world, fid)` → {reach_km, cells, free, homes, full}.
    - Reach: school 1.5 km, clinic 2 km, a workplace 3 km.
    - The reach is full when fewer free cells are left than one 50-home block of houses takes (5).
  - **Cheaper living**, the most common motive: apartments cost less per home to build and to connect, so they house
    people who cannot pay for a house. It reads `form_table()` → per form: homes per cell, storeys, land per home (HOUSE
    1,000 m², APARTMENT about 170 m², TOWER 50 m²) and connection metres per home; also `connection_m(fid)` for a
    block.
- **The choosing** is Otto's (developers under R8) and the government's (the allowed forms are the commander's choice,
  section 8). TownGrid applies a choice with `set_form(fid, form)`, or reads it from a new block's "form" field.


## 12. The town view, planned next (the user, directly and via Wilma, 2026-11-16; nothing here is built yet)

The town view (ui/town_view.gd, committed e18ceda) draws the grid with placeholder blocks. The user is making the
models in SketchUp (low-poly, one kit at one scale). What was settled for the next build, in order:

**The model kit and the 25 m grid.**
- **Scale:** the kit is made with every piece on a 26.4 m road tile. The game shrinks the whole kit by one factor (to
  25 m tiles), so it all still fits together, and four tiles span a 100 m cell edge.
  - The factor is 25 / 26.4 if a kit car measures about 4.5 m (real metres).
  - If the car is clearly bigger, the factor is scaled to match.
  - To ask: the length of one car.
- **Road pieces**, chosen per spot from the neighbouring streets: straight, crosswalk, T, cross, corner, dead end,
  plain plaza, grass (parks, the round green). Not used: diagonals, tunnel, rock. Roads between towns stay drawn
  strips.
- **A house cell is 4 × 4 tiles:**
  - half a tile of street on its north and south edges;
  - a row of 4 house plots facing each street, with the back-garden row between them.
  - That is 8 houses, or 6 where a north–south street takes a column.
  - **TownGrid.FORMS HOUSE goes from 10 to 8 homes** so the count matches what is drawn (TOWN_GRID is off and
    nothing in the economy reads it).
- **The plot:**
  - the house sits back, its centre 2/3 of the way from the street (the user's rule);
  - the front third holds the yard, the driveway and the garage beside it;
  - sheds and trees go in the back-garden row.
  - The driveway side and the variants are picked from the plot's spot (pure, stable).
- **Slots added:** GARAGE, SHED, FENCE_FRONT, FENCE, and ROAD_* (the road pieces).
  - FENCE_FRONT is the plot's whole front, with the car opening and the gate in the same place on every piece. It is
    mirrored when the driveway is on the left.
  - FENCE is a 3.3 or 2.2 m segment for the sides and back. Where two neighbours meet, the left plot's fence is drawn
    once. Some plots get none.
  - A front piece and a segment with matching names (`picket_front`, `picket`) belong together.
- **Painting by the game:** walls, roof, windows, door and trim as named materials (`wall`, `roof`, `window`, `door`,
  `trim`). The game paints each house from a palette per plot, and a garage matches its house. `window` is what
  glows at night.
- **Apartments:** the user's are narrow. They get one 25 m tile each, so up to 8 to a cell along the streets.

**A street pattern per town** (the user: "I think it sounds excellent"; after the new houses and road pieces are in,
Wilma confirms the go then).
- The pattern is pure in the seed and the town's id, and nothing is saved.
- It varies: block sizes 1×2 to 2×4 cells, the main street and its bend, T-junctions and dead ends, a square or
  park in the centre, and the spacing of the cross streets.
- It is defined over the ground ahead of the town, so streets never move as the town grows.
- New rule: a cell without a street to its north or south turns its houses to a side street, or becomes a garden or
  park.
- Curves and diagonals are later.
- Nothing in transport or save/load changes. connection_m's Manhattan distance stays an approximation.

**One clock: day and night, the sky, cars** (the user: the day must be long enough that cars drive to work, stay,
and drive home).
- The game's months are untouched. Within the current month the view runs one clock with speeds: pause, 1× (real
  time), 10×, 60× (a 24-minute day). Everything shares it, so a car parks exactly a workday at any speed.
- **Sun:** from the town's latitude, the planet's 26° tilt and the game's month (day length and sun height follow
  the season).
- **The twin moons:** on the planet's 7- and 11-month cycles, the same ones that make the twin-moon surge.
- **Cars are real commuters,** from the commuting rows (home district, work, distance, road speed). Each car belongs
  to a household:
  - it parks at home overnight (in its garage if the plot has one);
  - it leaves at the shift start minus the trip time;
  - it drives the route and parks at work;
  - it drives home after the shift.
- **Night traffic comes only from real night work:** plant shift changes at 22:00 and 06:00, clinics, police and
  care round the clock, bakeries before dawn. Nothing drives to fill the screen.
- **Controls:** a clock in the corner, pause, and a "daylight" setting that keeps it noon for reading the map.

**Lights** (the user asked for towns seen lit "like you do in real life from space"; not ordered yet).
- **Town view:**
  - no real light per building;
  - the `window` material glows at night, with bloom (about 1 ms a frame, whatever the number of buildings);
  - the share of lit windows follows the clock (most in the evening, few after midnight, more where night shifts
    live);
  - street lamps are a glowing bulb plus a light patch on the ground.
- **Globe:**
  - the sun is fixed in the planet's sky (today it rides with the camera), so there is a night side and a moving
    terminator;
  - each settlement is a patch of light points on the night side (homes and density, from the town grid or homes
    per tile), drawn as one batch;
  - the colony map darkens at night with the same points per cell.
- **Decision on scale (the user, 2026-11-16): "Brightened".** The town lights get brighter the further out you zoom,
  so the colony reads as a clear cluster on the night side, not true to physical scale. The rest of the planet stays
  dark.

**Order of work** (as given to the user; each waits for its go):
1. the user's models and road pieces in, laid out on the 25 m grid;
2. the street pattern;
3. the clock and the sky;
4. window lights and lamps;
5. the globe's night side with the town lights;
6. cars on the clock.

All of it is UI only: no simulation, saves or v11 touched, except the HOUSE form's 10 → 8.
