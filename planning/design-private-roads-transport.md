# Design note: private roads (transport side)

Terra, 2026-11-15, for Wilma (user: "private roads, bought and paid for by companies"). Design only, no code. Anni's
`design-law-private-roads.md` says what the law allows and who decides. Bob's firms decide to build from their
held-freight signal. This note says what the link model has today, and what it needs so a link can belong to a company.

Flag: **PRIVATE_ROADS**, which only works with FREIGHT_ROADS on. Without it nothing changes.

## 0. What exists today

- **Links** (`Transport`, table "transport"):
  - A colony link is `{id, kind TRACK|ROAD|PAVED, path [tiles], bridges, spans, lanes, bridge_lanes, cond 0..1000,
    traffic, traffic_last, acc, built, globe 0}`.
  - With FREIGHT_ROADS a link also carries `frt/fwt` (this month's freight moved and wanted, mu), `fpcu_last/fwt_last`,
    `fcap`, and the yearly trend `ys/yn/yl/yp`.
  - **There is no owner field: every link is the colony's.**
- **Building**: Bob's ROAD project carries a spec; `Transport.plan_link` prices it; `Transport.complete_road(world, p)`
  builds it.
  - Specs: new link `{a, b, kind}`, `{upgrade}`, `{repair}`, `{lanes}`, `{bridge}`, `{junction, type}`, or a globe road
    `{site, kind}`.
  - `p.owner` is read only to name the government responsible in the opening fact.
  - Junctions are derived where links meet, so a new link joins the public network on its own.
- **Routing**: one network for everyone.
  - Commuters and freight both use `commute_d(from_d, to_d)`: the fastest road route between two district nodes, memoised
    per month.
  - FREIGHT_ROADS fixes each month's freight routes (`froutes`) at the NATURE tick.
  - No route depends on who is travelling. No route counts money, only time.
- **Wear and works**:
  - `step_month` wears every link (age, traffic above capacity, storms).
  - `road_needs` and `traffic_fixes` list every link, and the government's road works (ROAD_WORKS, `gov_builder`) may
    order any of them.
- **Tolls**: `TransportLaw.road_toll` turns LAW_ROAD_TOLL into a toll per trip on paved roads, **but nothing charges it
  yet**. No route or market reads it.
- **Signals a firm can read**:
  - Bob's `st["r8"]["goods"][g][d]["hr"]` (freight held by roads);
  - `Transport.deliverable_pm`, `district_jam_pm`;
  - `road_needs` with `held_mu`, `held_by_good`, `to_districts` and the NEW_LINK / DETOUR options (each with a ready
    `spec`, cost and months).

## 1. The link record (small additions, only on private links)

| field | meaning | who writes |
|---|---|---|
| `owner` | org id; absent or "" = public | `complete_road` (from `p.owner` when it is an org), `transfer_link` |
| `regime` | OWNER, OPEN_TOLL or OPEN_FREE (Anni §3.1) | the owner, through a setter |
| `toll` | mcr per truck trip, OPEN_TOLL only (a car pays toll ÷ TRUCK_PCU) | the owner |
| `reserved_pm` | share of capacity kept for the owner's freight under common carriage (≤ 500) | the owner, within the law |
| `build_cost` | the plan's cost when built, plus later works the owner paid for | `complete_road` |
| `public_money` | state money put into it (step-in repairs, contributions) | Bob's bookings, through a counter call |
| `licence` | Anni's licence id ("" under FREE or for a farm track) | `complete_road` from the project |
| `ytr` / `ytr_last` | truck trips this year and last year (for Anni's cost-recovery toll) | `add_freight_traffic`, `step_month` |
| `tolls` | {org: trips} this month (the bill) | `add_freight_traffic`; read and reset by Bob monthly |

Ownership is also part of the network's shape. `_struct_sig` (the key of memos kept across months) adds
`owner` / `regime` / `toll` / `reserved_pm`, so route memos never outlive a change of access.

## 2. Who may drive where: network views

Routes must depend on the traveller. The plan is three views, each memoised like today's graph:

- **Public view**: public links, plus private links that are OPEN_TOLL or OPEN_FREE. Commuters and everyone's freight
  use it.
  - Route choice weighs the toll: generalised cost = time + toll ÷ VALUE_OF_TIME (a constant per truck-hour, and per
    car-hour for commuters).
  - A dear private road is then avoided when a free public road is nearly as fast. That keeps tolls honest without the
    law having to act.
- **Owner view** (one per org that owns an OWNER road): the public view plus that org's own OWNER links.
  - Used only for freight whose seller or buyer is that org. Anni: "its suppliers' or customers' deliveries to it".
  - So the call becomes `freight_room_mu(world, from_d, to_d, org := "")`, and `add_freight_traffic(..., org := "")`.
    Bob passes the org: the buyer for deliveries in, the seller for goods out.
- **Freight routes** (`froutes`) become `{"a|b": ids}` for the public view plus `{"org|a|b": ids}` for owner views,
  only for the pairs and orgs that differ from the public route. They stay small: a handful of private roads at most.

## 3. Capacity and the jam on a private link

- **OWNER road**: all its capacity is the owner's. There are no commuters on it.
- **OPEN road**: as today's sharing, plus the owner's reservation.
  - The owner's freight may use `reserved_pm` of the allowance first.
  - Everyone else (and the owner, past its share) shares the rest by demand, as on a public road.
  - Refusing traffic within the open part is Anni's ROAD_ACCESS_REFUSED. The model never refuses: a refusal would be a
    firm decision (Bob) that the law then judges.
- Private capacity counts in `deliverable_pm` and `district_jam_pm` for those it serves. Private roads that relieve a
  public route show up as lower held freight on the public needs.

## 4. Maintenance and the government's works

- Private links wear by the same rules.
- `road_needs` and `traffic_fixes` **leave private links out** of the government's list. A separate query
  `Transport.private_road_needs(world, org)` gives the owner the same rows (repair, upgrade, widen), for Bob's firm
  rules. This keeps Anni's §7: the budget never touches a private road.
- **Exception: a step-in.** `fix_spec` for a private link is allowed when Anni's `RoadLaw` has ordered a step-in. The
  project then carries `owner: "gov"` and `step_in: lid`, and Bob books the cost to the owner.
- Anni's neglect ladder reads `cond` against 400 (where FREIGHT_ROADS already steps a paved road down to road
  capacity), so that threshold already means something on the road.

## 5. Building one

- A ROAD project with `owner: org`, paid by the firm (Bob's construction job). The spec is the same as a public new link
  `{a, b, kind}`, plus `regime`, `toll` and `reserved_pm`.
- **Two checks `plan_link` would add for private specs:**
  1. **Not on a public line.** The path may not reuse a public link's tiles except where it joins one, at either end or
     at a crossing. The planner today may run alongside an existing link, so it needs an `avoid` for public tiles, as
     the bypass planner already has.
  2. **The land.** The plan returns its tiles. Anni's `RoadLaw.may_build` judges them (title, zoning, wayleave), so
     transport only exposes them.
- **What a firm should build**: `Transport.private_road_case(world, org, from_d, to_d)` → `{spec, cost, months, km,
  freed_mu (held freight on that pair last month, from fpairs_last and fheld_last), relieves [link ids]}`. It is pure,
  and reuses the DETOUR planner (a direct link between the two district nodes) or a bypass of the worst link on the
  route. Bob's rule 8 then compares freed freight × margin lost with the cost.
- The farm or mine haul track (Anni's "small exception") is a TRACK from the plant to the nearest public link. FREIGHT_ROADS
  doesn't route plant-to-district freight yet (a stage-2 item), so it would carry nothing until that comes.

## 6. Changes of hands

One write does them all: `Transport.transfer_link(world, lid, new_owner, why)`.

- `new_owner` "" makes the link public: the toll, regime and reservation are cleared, and it joins the government's
  works.
- `why` is SALE, TAKEOVER, REVERTED or REVOKED, for the fact `TRANSPORT_LINK_CHANGED_HANDS`. Anni's facts carry the law.
- It bumps the network revision so every route memo refreshes.
- Anni's `RoadLaw.value` reads `build_cost`, `cond` and `public_money` from the link (§1). Land value is hers.
- **In administration** the road keeps its regime. Transport needs nothing for that: the model never closes a link for
  an owner.

## 7. Tolls and money

- Transport only counts. With PRIVATE_ROADS, `add_freight_traffic(..., org)` adds the trucks on each private OPEN_TOLL
  link to `tolls[org]`. Commuter traffic (bus trips by the operator) is added the same way for the bus operator's org.
- Bob reads `Transport.toll_bill(world)` → `[{link, owner, payer, trips, mcr}]` once a month, books the payments, then
  resets the counts. Unpaid tolls are his, as for freight.
- Anni's cost-recovery toll needs `build_cost`, the owner's upkeep (Bob) and last year's truck trips (`ytr_last`).
  Transport gives `Transport.truck_trips_last_year(world, lid)`.
- The public LAW_ROAD_TOLL could be charged the same way on public PAVED links. That's a separate decision; today it is
  a lever with no effect.

## 8. Shown

- Colony map: a private link is drawn in its kind's style, plus a thin outline in the owner's colour. OWNER roads get a
  small barrier mark at each junction with the public network.
- The link panel gives the owner, regime, toll, reserved share and licence.
- The Build tab shows a firm's planned road (from `private_road_case`) like a public plan.

## 9. Work and order

| part | size | depends on |
|---|---|---|
| link fields, `transfer_link`, `_struct_sig`, facts, panel text | small | nothing |
| network views (owner view, tolls in route choice), `froutes` per org, `org` arguments | the main work (~1 day) | Bob passes the org |
| capacity: reservation and the owner's share | small | views |
| `private_road_needs`, works exclusion and step-in | small | Anni's RoadLaw step-in |
| `private_road_case` (planner reuse, the not-on-a-public-line check) | small | views |
| toll counting, `toll_bill`, `ytr` | small | Bob books |
| tests: access by view, tolls avoided when dear, works exclusion, a change of hands refreshes routes, save/load, flag off | | |

## 10. Questions

- **Bob:**
  - Do you pass the org (buyer for deliveries in, seller for goods out) to `freight_room_mu` and `add_freight_traffic`?
  - VALUE_OF_TIME per truck-hour: yours (wages, fuel) or a constant of mine?
- **Wilma:**
  - Should a district or the government see private roads in its politics, beyond Anni's facts? For example, a toll that
    commuters pay felt as COST_OF_LIVING in the district.
  - Should the public road toll (LAW_ROAD_TOLL, uncharged today) be charged through the same counting?
- **Anni:**
  - Your §10 needs `owner / regime / toll / build_cost / public_money / licence / condition` and the truck trips: all are
    in §1.
  - Your §12 question: private links are kept out of the government's works (§4) and out of LAW_ROAD_TOLL (a public toll
    would read only public links).
