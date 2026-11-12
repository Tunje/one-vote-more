# Spec: Demand: exports, luxury, leisure and tourism (v1)

User decision 2026-11-13 (A42): "if the colony can't use something there is no point in making it, that is why they
have so high unemployment! Three ways: luxury goods, arenas and places for leisure, tourism, and exports — not just
what the home world demands but general exports, going out on the same transports and sold on the home world."

Diagnosis it answers (Bob's E115 trace): capacity runs 2–9× above demand, plants hire only for what they sell, and
colony demand stops growing once basic needs are met. Benefits and public works only recycle money inside the
colony. These channels create **reasons to produce**: outside buyers (exports, tourists) and new wants at home
(luxury, leisure) that grow with income.

Owners: **Bob** D1–D3 (economy), **Terra** D4 sites (planet), **Anni** D5 (law), **Wilma** D6 (politics, UI, news),
**Ella** campaign hooks (optional). Order: **D1 exports first** (biggest lever, uses existing goods and ships),
then D2 luxury + D3 leisure, then D4 tourism. Merge with M12(2) colonial goods: the quota cargo and general exports
share the same ships.

## D1. Exports (Bob)

- Every ship (18–30 months, irregular) has **cargo space**. Out: the charter quota first (M12(2)), then general
  exports. In: migrants and anything the colony ordered.
- **Home-world prices**: each exportable good has a home-world price (a slow random walk with its own trend, ±30%
  over decades), minus freight per unit. Goods that don't keep (FOOD beyond preserved stock, ENERGY, WATER) can't be
  exported; MINERAL, MATERIAL, COMPONENT, CONSUMER, LUXURY, MEDICAL and the native crop / rare mineral can.
- **Export houses**: firms (and the public utility) consign stock to the next ship when the home price net of freight
  beats the local price. Because ships are rare, firms **stockpile** between ships; a warehouse (DEPOT) limits it.
  This gives plants a reason to run at fuller output between ships.
- **Money**: export revenue enters from EXTERNAL "home_world" (a legitimate external flow, like migrants' savings),
  paid to the exporter when the ship docks. Part can be taken by the charter (export levy) or colony export tax.
- **Imports (later)**: earnings can buy home-world goods on the next ship (tools, luxury, later technology). v1 keeps a
  small import list (CONSUMER, LUXURY, MEDICAL) so that foreign earnings have something to buy; the trade balance
  is a new indicator.
- Risks: a ship can be lost (M11), a price collapse can hit a colony that bet on one export, the home world can raise
  tariffs or ban a good (HomeWorld actor), independence changes the terms. Dependence on one export is a real choice.

## D2. Luxury goods (Bob)

- New market good **LUXURY**: made in workshops from MATERIAL + COMPONENT + skilled labour (S/Sp heavy), with quality
  tiers. Exportable.
- Household demand: only after essentials are met, rising steeply with income band (the I4/I5 households spend most),
  plus status: more luxury where inequality is high. Rich enclaves (areas) want more.
- Effect: high earners' surplus becomes jobs instead of idle savings; the luxury trade shows inequality on the street.

## D3. Leisure (Bob, with Wilma for the state side)

- New facility types: **ARENA** (sport and events, big crowd days), **PARK**, **THEATRE / CULTURE HALL**, plus
  private **TAVERN / RESTAURANT** venues (service sector, many G jobs).
- Households buy a new service, **LEISURE**, from venues near them, with a basic share for everyone and more with
  income. Arenas run events (monthly), with fact `ECON_EVENT_HELD` (crowd, takings) — good for the papers.
- State-built parks and arenas are public projects ordered by governments (GovBuilder, D6) or the player; private
  venues open by E102-style demand.
- Quality of life: leisure access per area feeds a new voter concern **LEISURE** (or into PUBLIC_SERVICES if a new
  concern is too much — Wilma decides in D6), so "bread and circuses" is a political tool.

## D4. Tourism (Terra sites, Bob economy)

- **Sites**: the planet has attractions: alien phenomena, striking terrain (falls, canyons, glowing fields), the
  landing site, later the colony's own arenas. Terra marks sites on the globe / colony map with an attraction score;
  phenomena seasons make some sites seasonal.
- **Visitors**: wealthy home-world visitors arrive on ships (a share of passenger space), stay until the next ship or
  a set number of months, and spend on HOTEL (new facility, service jobs), guides (SERVICES), LEISURE and LUXURY.
  Their money enters from EXTERNAL like export revenue.
- Tourist numbers depend on attraction, hotel capacity, safety (crime, unrest, strikes), the colony's reputation in
  the home world (independence talk, scandals) and the visa law. A riot or epidemic empties the hotels.
- Politics: locals may resent tourists (prices, crowding) — a concern hit in tourist areas.

## D5. Law (Anni)

NUMBER levers where possible: LAW_EXPORT_TAX (0–50%), LAW_EXPORT_BAN list stays player-only (enum), LAW_TOURIST_VISA
(0 closed … 100 open), LAW_TOURIST_TAX (0–30%), LAW_LEISURE_LICENSING (venue licence strictness, alcohol), LAW_LUXURY_TAX
(0–50%). Charter interplay: the home world may forbid exports of some goods to anyone but itself (it's the only
market for now) or claim an export levy; refusing it is part of colony politics.

## D6. Politics, UI and news (Wilma)

- Parties: positions on trade (open/protect) map to existing axes (ECON_ROLE, SOVEREIGNTY, ENVIRONMENT for tourism
  vs nature); new commitments on export tax, luxury tax, tourist visas.
- GovBuilder: governments build parks/arenas by ideology and unemployment ("bread and circuses" for populists and
  spenders; parks for green parties); an export drive (incentives for export firms) for development-minded ones.
- Concern LEISURE (if adopted) in PolDefs with occupation weights.
- UI: Economy group gets a **Trade** window (next ship, cargo booked, home prices, last ship's earnings, trade balance,
  tourists in the colony); the Gazette markets box shows home-world prices.
- News lines for every new fact (ship loaded/sold, price swings, event held, tourist season, export ban).

## Acceptance (century runs, 3+ seeds)

- Exports exist on every seed after the first ship (cargo value per ship > 0), and plants run closer to capacity:
  capacity/demand above +100% on no essential good for more than 10 years.
- Mean unemployment falls clearly against the current tree on the same seeds (target: century mean under 14%) without
  forcing it, and it still differs by politics.
- Luxury spending rises with inequality; leisure venues exist in every area over 300 people by Year 30.
- Tourist arrivals vary with safety and law (a strike-heavy or riot decade shows fewer tourists).
- Ledger: EXTERNAL flows only for exports, tourist spending, imports and migrants; determinism and save/load hold;
  integer state only.
