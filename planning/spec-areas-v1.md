# spec-areas-v1 — Areas that are built, grow and split; districts drawn by law (M13)

Owner: Wilma (map, area store, splits, politics, UI). Economy: Bob. Law: Anni.
Implements population.md §3 (housing blocks from the map, PD §3.1–3.9) properly; it replaces the stop-gap
"housing block = district" (spec-population-v1 §0) and the six fixed, populated districts.

User decisions (2026-11-11, A35):
- **Areas are built, not given.** You build your areas, and they can **split**.
- **The colony starts as a landing settlement plus a couple of resource outposts.** The rest is open land.
- **District boundaries are drawn by law** (a districting act), not automatically.
- **Individuals matter in aggregate:** rich households can have private houses built, and that should change how the population groups.
- **2D for now** (a 3D view could sit on the same tiles later).

## 1. Map and terrain (Wilma)

A 2D tile grid (about 64 × 40) generated per seed (stream `map.terrain`). Terrain is simulation state, not decoration:

| Terrain | Used for |
|---|---|
| plain | housing, most plants |
| fertile / river | farms (river also helps waterworks) |
| hills, rock | mines, harder building |
| ore deposit | mines (finite) |
| rare-mineral deposit | RARE_MINERAL mines (M12) |
| native-crop land | NATIVE_CROP plantations (M12) |
| the landing site | the first settlement |

Each tile holds at most one use: an area tile, a facility, or open land. Distances between tiles replace the fixed `LINKS` table for freight, commuting and service reach.

## 2. Areas (housing blocks)

An area is a contiguous patch of residential tiles. It is a PD housing block:
- id `hb:N`, a generated name (e.g. "Landing", "Redrock Camp", "Riverside Heights");
- tiles, district;
- housing capacity (from housing buildings), quality, rent;
- `kind`: SETTLEMENT / CAMP / VILLAGE / ENCLAVE / SHELTER;
- founded month and parent ids.

PopStore leaves are keyed by area (`hb` part), so population, beliefs and votes are per area.

- **Building housing next to an area extends it. Building it apart from every area founds a new one.**
- **Who builds:**
  - the government or the player (public housing);
  - companies (company housing next to a remote mine or plantation, which makes a CAMP or VILLAGE);
  - **rich households** (Bob, below): wealthy pools commission private homes, usually as an ENCLAVE beside a high-quality area.
- Capacity, overcrowding, unhoused residents and moving between areas follow PD §3.4–3.8 (Bob's housing market, keyed by area).

## 3. The start

- **Landing**: the settlement at the landing site. Most colonists live here.
- **Two outposts**: a mining camp at the nearest ore deposit and a farm village on river or fertile land. Each is a small area with company housing, holding the charter's first mine and farms.
- The founding facilities (power, water, processing, components, depot, clinic, school) sit on tiles in and around Landing.
- Everything else is open land to settle.
- **One district** at founding ("the Colony"), set by the commander's founding ordinance.

## 4. Splits (Wilma; PD §3.9)

Every year an area is checked for:
- **Size:** above `SPLIT_SIZE` residents (≈ 800), it splits into two contiguous halves along the tile layout.
- **Divergence:** a contiguous cluster of its tiles whose residents differ sharply from the rest (income band mix, e.g. an enclave of private homes; or exposure, e.g. a slum by a polluting plant) becomes its own area.

On a split:
- residents are transferred by where they live (PopStore transfers, with beliefs travelling as always);
- new ids record their parent;
- old ids stay valid for history and past elections.

Merging (two areas grown together) is the reverse, with predecessor ids recorded.

## 5. Districts by law (Anni + Wilma)

A district is a named administrative grouping of areas. It matters for:
- local budgets and service allocation;
- district statistics, map overlays and district politics;
- electoral geography, if constituencies are ever introduced (PD §20.5).

**Districts are created, changed and split only by a DISTRICTING act** (parliament: a LAW-level bill with a district map; the commander by ordinance in the founding era). Rules (Anni: constitution/charter) may require contiguity and rough population balance, and may limit how often the map is redrawn. Areas founded between acts join the nearest district until the next act.

**AI governments propose districting acts:**
- when a cluster of areas is far from its district's seat;
- when districts are badly unbalanced;
- when it suits them. **Gerrymandering is possible.** Parties judge a districting bill by its effect on their own voters' areas.

## 6. Economy (Bob)

- Re-key everything that is about **where people live or where a plant stands** from district to area or tile: housing, rent, occupancy, pollution exposure, service access, commuting, facility location, freight distance.
- What's administrative (district budgets, if any) stays per district.
- Facilities get a tile, and new facilities need a suitable tile (terrain).
- **Private housing:** wealthy pools (I4/I5) with savings and crowded or low-quality housing commission private homes, at a cost from their savings, built by builders. This creates enclaves and income segregation.
- **Company housing** for remote plants.
- **The start (§3):** the founding endowment placed on tiles around Landing and the two outposts.

## 7. Politics and UI (Wilma)

- **Votes and opinion** per area (cells/leaves keyed by area). District means for neighbour influence and district politics.
- **Map:** terrain tiles, areas coloured by kind or overlay, facility icons, district borders.
- **Player actions on the map:**
  - choose a tile for public housing or a public building;
  - propose a districting act by drawing groups;
  - click an area to open its housing-block panel (PD §23.1).
- The chronicle records areas founded and split and districting acts.

## 8. Steps

| Step | Owner | Content | Gate |
|---|---|---|---|
| A1 | Wilma | terrain map, tile ownership, area store (create, extend, split, merge), PopStore area keys | tests: create, extend, split, conservation through splits (PD tests 1, 3) |
| A2 | Bob | economy keyed by area/tile; facility tiles; distances from tiles; the new start (§3) | economy gate re-baselined; ships, M11/M12 unaffected |
| A3 | Bob | housing builds extend or found areas; company housing; rich private housing (enclaves) | enclaves appear in rich colonies; segregation measurable |
| A4 | Anni + Wilma | DISTRICTING act, rules, AI redistricting, gerrymandering | test: a districting bill passes, areas move district, history kept |
| A5 | Wilma | map UI: tiles, areas, placement, area panel, district drawing | smoke test; playtest |

Order: A1 first (the store the others write to), then A2 and A4 in parallel, then A3 and A5.
