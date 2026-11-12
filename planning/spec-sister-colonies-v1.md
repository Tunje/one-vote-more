# Spec: Sister colonies (v1)

User decision 2026-11-13 (A48): "What about picking planets, and what if other colony ships leave at the same
time? We could have them pick their own planet, make a live version of governments' development — maybe future
trade partners or partners in breaking from the home world?" → "3–6 other colonies."

Builds on A47 (the expedition): of the candidate worlds, the player picks one; other expeditions leave at the same
time and settle others. **3–6 sister colonies** per game (setup option, default 4), each on its own generated planet.

Owners: **Wilma** C1, C3, C4, C6 (sister-colony politics, diplomacy, the League, office items), **Bob** C2, C5
(their light economies, inter-colony trade, migration), **Terra** (their planets = expedition candidates, shown on a
star map / home-world view), **Anni** C4 law (treaties, a League or federation charter), **Wilma + Anni** news.
Order: after A47. Integer state; deterministic from seed and expedition choices; saved with the world.

## C0. Distance and travel time (user, 2026-11-13)

"It should be one year to eight months minimum travel time to the nearest colony, one way."
- Each pair of colonies (and each colony and the home world) has a **one-way travel time**: the nearest sister at
  least **8–12 months**, farther ones longer (by Terra's star positions); a round trip is twice that plus port time.
- **Everything between colonies travels by ship and arrives late**: goods, migrants, letters, treaties, aid, and
  **news** — the papers report a sister's election or famine only when the ship carrying the news arrives, a year
  or more after it happened ("dispatches from Kepler Reach, written last spring"). Our picture of the others is
  always out of date; a treaty proposal may meet a government that has since fallen.
- **Diplomacy is slow**: an offer and its answer take a round trip; urgent aid (famine relief) arrives too late
  unless sent ahead; a joint independence needs months of coordination by letter — and the home world's ships
  may carry its own orders faster.
- **Trade** suits durable, valuable goods (minerals, fine goods, preserved food), not perishables; the light model
  carries cargo in transit (goods leave stock on departure and arrive months later).
- Routes: a ship's route through several colonies takes the sum of legs; colonies on short legs trade and talk more
  — distance shapes alliances.

## C1. The sister colonies (Wilma)

Each sister colony is a record `colony_sister[id]`: name, planet summary (from Terra's candidate), founding
expedition (preset style: corporate, state charter, co-op, …), founding month (same launch, arrival ± months).
It runs a **light model** monthly, not the full simulation:
- **Population** (births, deaths, migration — a few aggregate numbers), **economy** (output index, food balance,
  wealth per head, exports), **stability** (approval, unrest).
- **Politics**: a small party field (3–7 parties on the same axes as ours, generated from its colonists' mix);
  elections every 4 years (a simple vote model from conditions and ideology); a government with an ideology centre
  that drifts with its electorate; occasional crises (famine, strikes, scandal, uprising) drawn from its conditions.
- **Home-world relationship**: charter terms, loyalty, patience, its own independence movement and petitions.
- Distinct paths emerge from planet + expedition + chance: a corporate mining world, a radical co-op republic,
  a loyal state colony, a failing one.

## C2. Their economies and trade (Bob)

- Light economic model per sister: a few goods (food, minerals, materials, consumer, fine goods) with surpluses
  and shortages from its planet and choices.
- **Ship routes**: home-world ships call at several colonies on one route (the interval per colony follows the
  route), so **inter-colony trade** opens: goods sold to sisters on the same ship at negotiated prices (their
  shortage, our surplus). Competition for limited ship space and for the home world's favour.
- **Migration between colonies** on the ships: people move toward richer, freer or safer colonies; refugees in a
  crisis.

## C3. News from the other colonies (Wilma + Anni)

The papers and the press digest report the sisters' big events: elections, crises, independence moves, trade deals
— with each paper's slant. A REPORT in the office: "The colonies this year". They become part of our voters'
world (e.g. a sister's successful independence raises SOVEREIGNTY salience here).

## C4. Diplomacy (Wilma, Anni)

- Office EMAILs/MEETINGs from sister governments: trade agreements, mutual aid (famine relief), joint petitions to
  the home world, defence of shipping, migration accords; the player answers; AI governments answer by ideology
  (SOVEREIGNTY, ECON_ROLE, INSTITUTIONS) and interest.
- Treaties are law (Anni): ratified by parliament, binding, breakable (with consequences).
- Relations per sister (−100..100) move with treaties, trade, aid, betrayals and ideology distance.

## C5. Breaking away together (Wilma, Bob for consequences)

- **The League of Colonies**: an inter-colonial congress colonies can join; it coordinates petitions, trade and,
  finally, independence. Joint independence is stronger (the home world cannot crush all at once); going alone is
  riskier.
- Contagion: one colony's successful independence emboldens the others (SOVEREIGNTY drift, petitions); a crushed
  rebellion deters them.
- The home world plays them against each other: ship priority, charter favours for the loyal, sanctions and
  expeditions for the defiant.

## C6. Politics at home (Wilma)

Parties take positions: pro-League vs go-it-alone, open trade vs protection, solidarity vs rivalry; treaties and
League membership become election issues; refugees and migration from sisters are an immigration question.

## Acceptance (century runs, 3 seeds)

- 3–6 sister colonies develop visibly different histories (different governments, crises, wealth, independence
  outcomes) from the same launch.
- Inter-colony trade happens when surpluses meet shortages on shared routes; at least one treaty per seed.
- At least one seed shows coordinated action (a joint petition or League), and a sister's independence or crushed
  revolt measurably shifts politics here.
- The light model stays cheap (the full run slows by under 10%).
