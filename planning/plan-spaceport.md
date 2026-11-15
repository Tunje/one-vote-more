# Spaceport and the colony's own ship (A62, 2026-11-14)

Status: an idea of the user's ("a what if, not a plan"), kept on the user's word 2026-11-15 for later. Not ordered, not scheduled, nothing built.

User: "Maybe that's why we need to include a spaceport and the building of an extremely expensive own ship that can be
used for export, imports, and most importantly, if the homeworld decides to cut everything off, to send diplomats back
and negotiate an opening of trade routes."

Why: today independence is nearly free once recognised (quota, levy, governor and colonial laws all go; no sanctions).
All trade still rides on home-world ships, so a home world that cuts the colony off controls its only money channel
(A61: net exports are where new money comes from). The colony needs a way to trade and talk on its own, and it should
be costly, slow and politically contested. Part of A61 M3 (the negotiation after independence).

## First: what happens today (Wilma, before design work)
- Check whether home-world ships keep calling and buying exports after independence and during a WITHHOLD sanction
  (econ_households ship clock, EconTrade.ship_interval / ship_hold / home_tariff, home_world.gd).
- If ships stop, independence already has a big unnegotiated drawback; if they continue unchanged, it has none.
  Either way the result goes into the treaty design below.

## S1 Spaceport (Bob builds and runs; Terra draws)
- A SPACEPORT facility that grows from the existing landing port store (EconTrade.port_capacity): levels 1–3.
- Needs land near the capital, power, skilled staff (port crew, customs, maintenance) and support staff (A56 rules).
- Level 1 = today's landing port. Level 2 can service and refit ships. Level 3 can build a ship (the shipyard).
- Expensive public project (several years of the infrastructure budget), with upkeep; a political choice, not autopilot.

## S2 The colony's own ship (Bob: build and economics; Terra: drawing and launch)
- Built only at a level-3 spaceport: an extremely expensive multi-year project (order of 2–3 years of total
  government revenue, 5–8 years to build), using large amounts of COMPONENT and MATERIAL and skilled labour.
- Running costs: crew wages, energy/fuel, maintenance; a round trip takes about as long as a home-world ship's interval.
- Risks: rare loss in transit; a hostile home world can seize it on arrival (an expensive asset put at risk).
- One ship at first; a second only much later.

### Uses
1. **Trade on the colony's own schedule and terms.** It carries exports and brings back imports independent of the
   home world's ships (more cargo, more money in), as long as the home world lets it dock (a treaty term).
2. **Diplomacy.** When the home world cuts trade off (WITHHOLD, embargo, or after independence), the government can send
   a delegation. On arrival a negotiation resolves: reopen trade, tariff (HOME_TARIFF), ship access
   (SHIP_INTERVAL / SHIP_HOLD), currency, reserves and debts (A61 M3), recognition. The outcome depends on the colony's
   leverage (goods the home world needs, self-sufficiency, unity), the home world's need and legitimacy, and the skill
   of the head of delegation (Anni's staff bench).
3. Later: migrants it brings.
4. **The home world's nations, after the break (user, 2026-11-14).** "In the start, when you're negotiating with the
   home world like we've had it so far. Later, once you get independence ... think of the home world as the UN, built up
   by many nations, but covering the whole planet ... And the individual nations as something you can decide to
   negotiate with after you've broken with the home world."
   - **Under the charter (as today):** the colony deals with the home world as one body, a planet-wide authority like a
     UN made up of many nations. Nothing changes before independence.
   - **After independence:** the colony can also go past that body and deal with its member nations one by one. They
     differ in what they need from the colony, what they pay, and how they stand toward the home-world authority.
     Reaching them needs the colony's own ship.
   - A nation can offer recognition, a trade treaty, loans or protection, and asks for something back (favoured access
     for its firms, a say over exports, a base at the spaceport): the risk of trading one master for another.
   - The home-world authority reacts to the colony going around it: tariffs, closing its ports, pressure on the member
     nation, seizing the ship, or better terms to bring the colony back to the table. Dealing nation by nation is the
     colony's leverage once it has broken away.
   - Politics: after independence a foreign-policy choice opens (keep dealing with the home world as a whole, go to
     individual nations, or self-reliance); envoys and treaties are Anni's law and staff; Ella's campaigns.
   - Without its own ship, an independent colony can only deal with the home world as a whole, on its terms.

## S3 Politics (Wilma; Ella for campaigns)
- Building the spaceport and the ship are bills with a budget line; parties split on the AUTONOMY axis and on cost
  ("our lifeline" vs "a white elephant"). Delays and overruns are scandal material.
- The home world reads a colony ship as a step toward independence: patience and loyalty fall when it is ordered.
- Home-world reactions to a delegation, and the treaty itself, live in home_world.gd and charter_ops (Anni: treaty law).
- After independence without a ship, the colony depends on the home world's goodwill for trade: that is the drawback
  independence should have, and the ship is how a colony earns its way out of it.

## Owners and order
Wilma: the check above, home-world reactions, negotiation, politics. Bob: spaceport levels, ship project, trade economics.
Terra: spaceport on the map, the ship and its launch. Anni: treaty law and the delegation's staff. Ella: campaign issue.
Queue: after the v10 items (landslide fix, S7, E140, optimiser exploits); the check comes first and is cheap.
Everything opt-in with its own A/B; integer state; RNG streams; --check-only every edited file.
