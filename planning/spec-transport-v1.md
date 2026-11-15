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

### T3 network side implemented (Terra, 2026-11-13; agreed with Bob, plan-support-economy §8c): sim/transport/commuting.gd, tests/transport/test_commuting.gd
- `Transport.commutes(world)` → `[{from_d, to_d, n, fid}]`: home → work from facility staff and builder crews
  (the staff keys carry the home block; milli-persons ÷ 1000). District level; an area-level call keeps the shape.
- `Transport.commute_d(world, from_d, to_d)` → `{ok, hops, km, minutes, links, factor}`, and
  `Transport.route_factor(...)` → ‰ (1000 = a good road, normal traffic). Each link is weighted by km: condition,
  kind (TRACK 1300 / ROAD 1000 / PAVED 850), congestion above 80% of capacity (this month's or last month's count),
  a second lane ×0.9, closed this month 2500. Each junction passed weighs 3 km by type. No road: 3000, cross-country.
- `Transport.incident_site(world, from_d, to_d, salt, kind)` → `{link, junction, tile}`. Bob's "econ.buses" draw
  decides that a breakdown or crash happens; this picks where: breakdowns by km, crashes by link factor × km and
  junction risk. Bob calls `add_accident` for crashes and puts data.tile and data.link on BUS_BREAKDOWN / BUS_CRASH.
- `Transport.bus_lines(world, EconQuery.commuting rows)`: derived lines, one per district pair over the road route,
  with stops at the settlements and the junctions on the way, and the nearest DEPOT. No state.
- `Transport.add_commute_traffic(world, rows)`: the only write. Buses in service × 4 trips and taxis (users / 1.5)
  × 2 trips, over 22 working days, go onto the route's links and junctions (T7 counts). Bob calls it after his
  commuting step. The NATURE reset keeps `traffic_last` on links and junctions.
- Drawn (Terra, 2026-11-13, from Bob's `EconQuery.commuting`, d3f3e43; opt-in SUPPORT_T, so the default game
  shows none). `bus_lines` also gives `path` (the route's tiles in order) and `bus_tiles` (up to 12 buses spread
  along the line, shifting each month; display-only and pure). Incident marks are `Commuting.incident_marks`:
  last month's BUS_BREAKDOWN and BUS_CRASH facts (Bob's §8c, opt-in FLEET, 96571c6) that have a tile, drawn
  where his `incident_site` call put them. Colony map: orange lines beside the road, side by side where lines
  share it, red-tinged above 1300‰ load (overcrowded); white stop squares; bus boxes; yellow triangles for
  breakdowns and red stars for crashes. The hover text names the lines; the link panel lists each line's buses,
  commuters, load and last month's incidents; the network summary counts lines, buses and commuters. Vista: buses
  on the roads, a hazard sign at a broken-down bus, a tipped bus with a flash at a crash.
  `tools/shot_colony.gd … buses` renders it with a demo breakdown and crash fact.

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

## T8. Freight on the roads (Terra, user via Wilma 2026-11-15) — sim/transport/freight_roads.gd, tests/transport/test_freight_roads.gd

User: "Next thing you're going to run into is roads, they won't be able to take the new freight." / "also road
expansions, not just quality".

- **Before**: only commuters (buses, taxis) drove on the roads. Freight went by the economy's own district hops and
  never touched the network. Over capacity, roads only got slower and wore faster: nothing was held up. On the year-100
  save (seed 2), adding the freight as trucks would put the main signal junctions at 217% and the worn road to d:3 at
  678%.
- **Flag FREIGHT_ROADS** (opt-in; Bob A/Bs it). Agreed with Bob:
  - `Transport.freight_room_mu(world, from_d, to_d)`: the milli-units the road route can still take this month.
    Unlimited within a district or without a road.
  - `Transport.add_freight_traffic(world, from_d, to_d, moved_mu, held_mu)`: the only write.
    - Trucks = ceil(mu ÷ (UNITS_PER_TRUCK 25 × 1000)) × 2 (the empty return) × TRUCK_PCU 2 car-equivalents.
    - They go on every link and junction of the route, so wear, the commuters' route factor and road_needs see them.
  - `Transport.deliverable_pm(world, from_d, to_d)`: 0..1000.
    - Last month's moved ÷ (moved + held) for the pair.
    - If the roads held nothing back: the route's headroom, capacity × 1.25 ÷ last month's load, at most 1000.
  - `Transport.district_jam_pm(world, d)`: the worst last-month load ‰ of the freight roads in the district.
  - The allowance per link or junction:
    - Up to capacity × JAM_ALLOW 1.25, freight takes what the commuters leave.
    - Past that, trucks and commuters share the jam in proportion to last month's demand. Freight's demand counts at
      least a quarter of the allowance.
    - It runs down within the month as freight moves, so it cannot oscillate.
    - Bob adds what the roads cut to freight_deferred, as he does for the depot cap.
  - The month's freight routes ("froutes") and capacities ("fcap") are fixed in the NATURE tick and saved.
    - Queries in the market loop read only the table: pure, about 0.05 ms a call.
    - A link finished during the month carries freight from the next month.
- **Worn paved roads** (with the flag): they lose capacity in steps instead of at a cliff.
  - Under 40% condition a paved road works as a road (1,500 trips a month instead of 6,000).
  - Under 15% it works as a track (300), as before.
- **road_needs** (Wilma's gov_builder):
  - With the flag, congestion is judged on the load projected 18 months ahead at the yearly trend. Each link and
    junction keeps its monthly mean for the last two years. The trend is last year's mean less the year before's.
  - A worn link's severity grows with its load: a quiet one counts half, one at capacity double.
  - Every need lists all its options, flag or not:
    `options: [{fix, type REPAIR|UPGRADE|WIDEN|NEW, spec, cost, months, cap_pm, load_after_pm, relief_pm}]`.
    - Fixes: REPAIR; ROAD and PAVE (UPGRADE); LANES_2, BRIDGE_2, PRIORITY, ROUNDABOUT and SIGNALS (WIDEN); BYPASS
      and NEW_LINK (NEW).
  - Detours (flag only): two districts whose road route is at least 1.6 × the straight line, where a direct new road
    would save at least 30% of the km.
    - These are needs of their own: key "PAIR:a>b", why DETOUR, fix NEW_LINK (a new ROAD between the two district
      nodes), plus road_km, new_km and trips.
    - Severity = (‰ of km saved − 300) × min(trips, 1500) ÷ 500. trips is the pair's freight trucks and commuter
      buses and taxis a month.
    - A link on that route also lists the NEW_LINK option; its relief is the pair's trips leaving the route.
- **News and measures**:
  - TRANSPORT_FREIGHT_JAM (PUBLIC, once per spell): when the roads held back 20% or more of the freight coming to a
    district. data: {district, where (the worst-loaded link or junction on the routes in), where_kind, load_pm,
    held_pm, held_units}.
  - TRANSPORT_FREIGHT_JAM_ENDED: when the share falls under 5%.
  - No one is named responsible. Politics decides the blame.
  - Indicator TRANSPORT_FREIGHT_JAM: the colony's share of freight held back, ‰.
- **Shown**:
  - Colony map: links and junctions carry a load stripe from last month (green from 50%, amber from 80%, red over
    capacity), with or without the flag.
  - The link panel gives the load, the freight trucks in it and the yearly growth.
- **Left out**: freight on plants' own access tracks (plant to district, a second stage), freight within a district,
  and storm closures holding up freight.

## T9. Road speed, accidents near people, over- and underpasses (Terra, the user's design via Wilma 2026-11-15) — sim/transport/road_safety.gd, tests/transport/test_road_safety.gd

User: "accidents should [be in the game]. Any high speed road near utility people walk to, and near districts, have
chances for accidents; over and under passes reduce the chance. Also road types should not be speed." / "a motorway
around a village instead of through can be a thing."

The design is in plan-settlement-later.md.

- **Flag ROAD_SAFETY**: opt-in, base unchanged without it.
  - No A/B run yet: the user said to wait while the machine runs v11.
  - Unit tests only so far.
- **Speed apart from surface**:
  - A link is driven at its surface's design speed (track 40, road 80, paved 110 km/h), or at its limit, less for
    wear.
  - `Transport.set_limit(world, lid, kmh)` sets a limit (30 / 50 / 70 / 90; 0 lifts it). It costs nothing and takes
    effect at once, and the news gets TRANSPORT_SPEED_LIMIT_SET.
  - A limit slows every trip on the link (the route graph's speed), and it is part of the network's shape (route
    memos).
  - The surface keeps capacity and wear.
- **People near a road**: a link tile is a spot when it is within 1 tile (3 km) of people on foot.
  - Weights:
    - a town's tiles: 2;
    - housing: 3;
    - clinic, school, shop, service hub, child or elder care: 2;
    - offices, police, other workplaces: 1.
  - Spots are pure in the layout and the network.
- **Accidents** (NATURE tick, stream transport.safety):
  - Expected accidents a month on a link = 0.002 × Σ spot weight (less what a pass there takes away) ×
    ((km/h − 30) ÷ 40)² × last month's trips ÷ 1000 (0.2..3).
  - The chance to kill rises with speed, from 5% to 60%.
  - Deaths go through EconPop.casualties (the nearby workplace's staff first, then the district).
  - Each accident is a fact, TRANSPORT_ROAD_ACCIDENT (PUBLIC, no one responsible; Wilma does blame and politics), with:
    - where it happened: district, link, tile, the people weight and what stood near, the facility, and the road's
      owner if private;
    - the road: km/h, limit, kind;
    - pass_here;
    - pass_refused: a pass had been on offer for 3 or more months and was not built, with offered_since;
    - killed and injured.
- **Choices**: `Transport.safety_needs(world)` lists links with one expected accident in 10 years or more, worst first.
  - Each row: {key "SAFE:<lid>", link, district, kmh, limit, people, risk_pm, deaths_pm, spot, offered_since, options}.
  - Each option is {fix, type, spec, cost, months, risk_after_pm, hours_lost}.
  - Options on offer:
    - LIMIT_<k> or LIMIT_NONE (type LIMIT): no cost, but `hours_lost` trip-hours a month. Applied with set_limit.
    - OVERPASS (cuts 70% of the danger within 1 tile) or UNDERPASS (85%, dearer) at the worst uncovered spot. This is
      a ROAD project {pass: lid, tile, type}; when done: TRANSPORT_PASS_OPENED.
    - BYPASS (type NEW), the capacity option with its safety case: through traffic leaves, a guessed 30% of the
      danger stays.
- **Flyovers**: a junction type FLYOVER (capacity 6,000, accident risk 10 against a plain crossing's 100). It is
  offered in traffic_fixes and built by a ROAD project {junction, type FLYOVER}, only with the flag.
- **Saved** (only with the flag):
  - per link: "limit" and "passes";
  - transport: "safety_offered" {lid: month} and "safety_acc" (the months of the last year's accidents).
- **Shown**: the link panel gives the speed, the limit and the passes.
- **Left out**:
  - pedestrians as travellers;
  - speed in the commuters' route factor beyond time;
  - accidents on globe roads;
  - a pass drawn on the map;
  - the A/B (later, when the machine is free).

## T10. Site choice groundwork: land reserved by use, site options, a chosen site (Terra, Wilma's queued job 2026-11-15) — sim/transport/siting.gd, tests/transport/test_siting.gd

From plan-settlement-later.md, "Who picks where a building goes". Today the spot inside a district is the nearest free
tile of suitable terrain, and nothing weighs one site against another.

- **Flag SITING**: opt-in, base unchanged without it. Unit tests only (no game runs while the machine runs v11).
- **Land reserved by use**: `ColonyLayout.set_use(world, tiles, use, by)` marks tiles FARMLAND / HOUSING / INDUSTRY /
  NATURE / OPEN ("" lifts it); `use_at(world, tile)` reads it. `Siting.tiles_around(world, centre, r)` gives the land
  tiles of an area.
  - What may stand where:
    - FARMLAND: farms only.
    - HOUSING: homes, plus shops and services.
    - INDUSTRY: works, mines, power, depots and the like, plus shops and services.
    - NATURE: nothing.
    - OPEN or unreserved: anything.
  - The layout does not place a new building on land reserved for another use. Buildings already standing there keep
    their tile: they are pinned when the land is marked, so nothing on the map moves.
  - Each change is a public fact, LAND_USE_SET, with: district, use, tiles, tile, was (the old uses), kept (buildings
    standing against the new use), by.
- **Site options**: `ColonyLayout.site_options(world, ftype, district, n := 5)` (pure) gives candidate tiles.
  - The first is where the layout would put the building today (default). The others are spread over the free
    suitable land within 6 tiles of the district's settlements.
  - Each row: {tile, default, terrain, use, town_km, road_km, homes, near [{fid, type, km}] (within 3 tiles), mine_km,
    depot_km, farmland_lost, road}.
  - road is {link, kmh, risk_pm, added_pm}: the fastest road within a tile, its ROAD_SAFETY danger now, and how much
    this building's people would add.
- **A chosen site**: `ColonyLayout.place_at(world, fid_or_project, tile)`.
  - It works for a facility opened this month, or for a building project not yet built. A project's site is held
    while it is built, and its facility stands there from the month it opens (found through its
    ECON_PROJECT_COMPLETED fact; the NATURE tick then moves the site to the facility).
  - Refused: unsuitable terrain, a taken tile, land reserved for another use, a tile in another district, a building
    already standing.
- **Nothing chooses yet**: without a choice the old placement stands. The government side (cases, neighbours
  objecting, municipalities) is Wilma's and Maja's.
- **Saved** (only with the flag): table "siting" {use, placed, rev}. rev is part of ColonyLayout.key, so the layout
  memo stays pure in its key.
- **Left out**: housing areas (AreaStore) growing onto reserved land is not refused yet (`Siting.fits(use, ftype)` is
  there for it); no map drawing of reservations.

## Acceptance (century runs, 3 seeds)

- No tourist ever visits a site without a road, a rover route or an airship route (tested).
- Roads get built (by governments and the player) and link kinds upgrade over a century; at least one site opens to
  tourists through a new road or operator per seed.
- Commuting exists between areas; freight costs differ by route; storms close tracks.
- Junctions and lanes get upgraded where traffic and accidents grow (at least one roundabout or second lane per seed
  by Year 60), driven by engineers' reports; accident counts fall after a fix.
- Ledger closed, integer state, determinism and save/load hold.
