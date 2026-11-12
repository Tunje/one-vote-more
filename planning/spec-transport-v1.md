# Spec: Transport (v1)

User decision 2026-11-13 (A43): "Maybe transportation needs a boost now that there are places to go?" → "Go ahead,
but remember roads have to be built off-road to tourist places: they need either a road or specialised vehicles."

Today: freight is an abstract depot service with a tariff; ROAD projects employ builders but change nothing ("map owns
links; v1 keeps capacities fixed"); there is no passenger transport; Terra's tourist sites have travel_days that
nothing uses. The new demand (leisure venues, tourism, exports, consumer goods) needs a real way to move people and
goods, and transport becomes a place where politics, jobs and accidents happen.

Owners: **Terra** T1 (network and maps, starts now), **Bob** T2–T4 (economy, after the v5 chronicles), **Anni** T5
(law), **Wilma** T6 (politics, UI, news). Integer state only; determinism and save/load as always.

## Core rule (user)

**Nothing is reachable for free.** Off the built network the land is off-road. A place (area, plant, tourist site,
port) is reachable only
- by a **built link** (track, road or paved road) from the network, or
- by **specialised vehicles** that can go off-road: **rovers** (ground; slow, costly, small capacity, need a rover
  base) and, for far globe sites or across water, **airships** (expensive, weather-limited, need a mast).
A tourist site with neither cannot receive tourists. A road to a site is a real project that costs money and time;
an operator buying rovers or an airship is a real investment.

## T1. The network (Terra)

- Nodes: settlements/areas (AreaStore), the landing port, plants with a site, tourist sites (colony-map and globe).
- Links on the colony map (tiles): kind TRACK (cheap, slow, closes in heavy rain/storms), ROAD, PAVED (fast, high
  capacity); capacity (vehicles or units per month), condition (wears with traffic and weather, needs upkeep),
  terrain cost (river crossing needs a bridge, hills and rock cost more, by Terrain codes).
- Globe: long links from the landing hex to globe sites (hex paths); building them is a large project. Off-road reach
  by rover range (hexes) and airship range.
- Initial state: the landing area and the first settlements are joined by tracks; nothing else.
- Pure queries: Transport network(world) → nodes/links; route(world, from, to, mode) → {ok, time_days, cost_index,
  links, mode}; reachable_sites(world) → per site the best mode or "UNREACHABLE"; plus the cost estimate of a link
  (for GovBuilder and the player).
- Maps: links drawn on the colony map by kind and condition; site reach shown (road / rover / airship / unreachable);
  globe routes; a build-road tool in the colony map's Build tab (player) using the normal ECON_COMMISSION_PROJECT.
- ROAD projects (econ_construction) finally change a link: new link, or upgrade TRACK → ROAD → PAVED, or a bridge.

### T1 implemented (Terra, 2026-11-12): sim/transport/transport.gd, colony_layout.gd, tests/transport
- **State**, world table "transport", integers and strings only:
  `{links, junctions, bases, seq, rev}`.
  - A colony link: `{id, kind, path [tile = y*64+x], lanes, bridges, bridge_lanes, cond 0..1000, traffic, acc, built, globe 0}`.
  - A globe link: `{..., cells [hexes], site, globe 1}`.
  - Junctions are `junc:<tile>` (three or more branches) with type, traffic and acc.
  - Bases are ROVER_BASE or MAST, at a tile.
  - The first NATURE tick writes the founding network. Until then, queries see it as a pure function.
- **Founding network**: tracks join the settlements, nearest first from the landing. Spur tracks reach founding
  plants that stand outside every town. Path planning runs over the terrain: hills cost more, river tiles need bridges.
- **Scale**: one tile is about 3 km. Speeds in km a day: track 80, road 200, paved 400, rover 60, airship 900.
  Cost index: 100 = 100 km on a sound road.
- **Capacity** in trips a month: track 300, road 1 500, paved 6 000, times lanes, and limited by the bridges.
- **Junctions** carry, in trips a month: crossing 400, priority 900, roundabout 2 000, signals 3 000, times lanes.
  Accident risk per trip: 100, 70, 25 and 45.
- **Wear** each month: by kind, plus traffic above capacity, plus storms. A link below 15% condition works as a track.
- **Closures**: tracks close in storms of 2+ or rain at 160% of normal; roads close in storms of 4+; paved roads
  never close. Airships are grounded by storms of 2+, rovers stopped by storms of 3+.
- **Reach**: a node off the network is reached only by rover (it needs a ROVER_BASE; anywhere on the colony map,
  or land hexes within 5 of the colony) or by airship (it needs a MAST). Globe sites in the REGION can get a
  globe road, which is a large project. Far sites are airship-only.
- **ROAD projects** (Bob's hook): `link` specs are
  - new `{a, b, kind}`;
  - bypass `{a, b, kind, avoid}`;
  - `{upgrade}`, `{repair}`, `{lanes}`, `{bridge}`;
  - `{junction, type}`;
  - globe road `{site, kind}`.
  District roads without a spec pick the most useful job:
  1. a track to a plant off the network;
  2. repairing a link below 60%;
  3. a bottleneck fix above 80% of capacity;
  4. upgrading the busiest track.
  They never link tourist sites by themselves (T6).
- **T7 fixes for the engineers**: `Transport.traffic_fixes(world)` gives
  `{"LINK:<id>" | "NODE:<id>": {options: [{fix, cost, months, cap_pm, acc_pm, spec}]}}`. Ordering a fix means
  commissioning a ROAD with that spec.
- **UI**:
  - Colony map: links by kind, lanes, condition and closures; junctions by type; a coloured reach ring on each sight.
  - Link and junction panels list the works on offer, with an Order button.
  - A "Road link" tool in the Build tab: two clicks, a planned route and its cost, then Commission.
  - The globe draws globe roads, and the hover text gives each site's reach.

## T2. Freight (Bob)

- Freight cost and time per shipment follow the route (distance, link kind, condition, congestion), replacing the
  flat tariff. Ore from a mine on a track is dearer; the port needs good links for exports.
- Depots stay as fleet capacity; congestion when traffic exceeds link capacity (delays, higher cost).
- Weather (Terra's storms, rain) closes tracks and slows roads; a cut link isolates a plant (fact).

## T3. People (Bob)

- **Passenger service** between areas: buses (later rail), run by the transport authority (CTA) or a private
  operator, with fares; capacity per route.
- **Commuting**: people can take jobs in other areas when the trip is short enough (time by mode); good transport
  widens job markets (unemployment), bad transport traps people.
- **Leisure access**: a venue serves the areas within reach; an arena far from town on a dirt track draws little.

## T4. Tourism transport (Bob, with Terra's sites)

- Tourists reach a site by road coach (if a road exists), by rover tour (off-road, rover base, licensed operator),
  or by airship (far globe sites, a mast, weather permitting). Travel time and price cut the draw; unreachable
  sites draw nobody.
- Tour operators are companies (new kind): they buy rovers or airships (imported or built later with kits), hire
  guides and drivers (S/G jobs), and fail if tourists don't come.
- Accidents happen (rover crash, airship in a storm) — facts, inquiries, a hit to the colony's tourism reputation.

## T5. Law (Anni)

NUMBER levers where possible: LAW_FARE_CAP (public transport fares, % of cost), LAW_TRANSPORT_SAFETY (vehicle
inspection strictness: fewer accidents, higher cost), LAW_TOUR_LICENSING (strictness for rover/airship operators),
LAW_ROAD_TOLL (0–n per trip on paved roads); public vs private operation of routes as a policy (CTA franchise).

## T6. Politics, UI and news (Wilma)

- Parties: roads vs public transit, state vs private operators, opening nature to tourism vs protecting it
  (ENVIRONMENT); roads as election-year pork in districts.
- GovBuilder: governments order roads where traffic or isolation is worst, by ideology (development-minded build
  more, green parties prefer transit and fewer roads to wild sites); the player orders through the map.
- UI: a Transport window (network, worst links, routes, operators, accidents) and the map tools; news lines for road
  openings, closures, accidents, strikes, new operators, first tourists reaching a site.

## T7. Traffic engineering: lanes, junctions, engineers (user addition)

User: "Infrastructure architects? How do you know when you need a roundabout, when should a double-lane road be made,
what causes these things?" Answer: measured traffic and accidents, studied by engineers, paid for by politicians.

- **Counts** (Bob): every link and junction node gets monthly traffic counts from freight, commuters, buses and
  tourists, against its capacity (lanes × road kind × junction type).
- **Problems** (Bob): congestion above ~80% of capacity raises delay and cost (freight dearer, commutes longer,
  tourists fewer); accident risk rises with volume, speed, condition, junction type, darkness and storms; accidents
  are facts (news, inquiries, a fatal one is a scandal if a report was ignored). Growth (a new mine, arena,
  settlement) moves the flows, so problems appear where the colony grows.
- **Fixes** (Terra models them in the network): lanes 1→2 (capacity ×2, more land and cost), bypass link, second
  bridge, TRACK→ROAD→PAVED; junction types CROSSING → PRIORITY → ROUNDABOUT (medium multi-way traffic, far fewer
  serious accidents) → SIGNALS (more capacity, needs power, costs more). Each fix is a ROAD-family project with a
  target (link or junction) and params.
- **Engineers** (Anni, staff system): an infrastructure department with transport engineers (skill matters). Yearly,
  and after a serious accident, it issues a traffic report: worst links/junctions with counts, accidents and a
  recommended fix with cost and time. A strong department spots problems early and picks the right fix; a weak or
  understaffed one is late or wrong (lights where a roundabout would do). Report quality follows the staff model.
- **Decision** (Wilma): AI governments act on reports by ideology and budget (development-minded build more, green
  parties prefer transit and fewer roads, austere ones wait for the accidents); the player governs → the player
  reads the report and decides. Companies lobby for roads to their plants; districts press for bypasses. Ignoring a
  report before a fatal crash is a scandal (fact with the report as cause).
- UI: the Transport window lists the latest report and its recommendations with an "order it" button; the map shows
  traffic load colours and accident spots.

## Acceptance (century runs, 3 seeds)

- No tourist ever visits a site without a road, a rover route or an airship route (tested).
- Roads get built (by governments and the player) and link kinds upgrade over a century; at least one site opens to
  tourists through a new road or operator per seed.
- Commuting exists between areas; freight costs differ by route; storms close tracks.
- Junctions and lanes get upgraded where traffic and accidents grow (at least one roundabout or second lane per seed
  by Year 60), driven by engineers' reports; accident counts fall after a fix.
- Ledger closed, integer state, determinism and save/load hold.
