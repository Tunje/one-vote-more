# Later: where farms sit, and planning towns and villages (user, 2026-11-15)

Status: noted for later at the user's request. Nothing is designed, queued or assigned. No work starts from this file
until the user says so.

User, after the ecology and food-pyramid design (pollution starts in a hex and spreads; damaged land yields less;
wildlife at the colony's edge):
"This would mean farms may have to start moving too, central land in a village would not be optimal, I want this
planned for later, also with this huge a map we might have to go into planning of towns and villages."

## 1. Farms may have to move
- With the ecology on, the land in and around a settlement is the most polluted and the most cleared, so it is the worst
  place to farm; the best land lies further out, where wildlife is also thickest.
- So farms (company and family) would want to sit outside the village, and to move outward as the land near the centre
  wears out, while the centre fills with housing, shops, bakeries and services.
- Questions for when this is taken up: can an existing farm relocate or does it close and a new one open; what moving
  costs; how far from homes people will work (commuting and buses already exist); food transport back to town; the
  greater risk of wildlife attacks on outlying farms; what happens to worn-out central farmland (housing, rest and
  recovery, industry).

User, 2026-11-15, settling the first question: "On moving they would have to shut down and be rebuilt; this could be
something the government gives incentives to, but some farmers should resist."
- Moving = a new farm is built further out FIRST, and the old one shuts down only once the new one is open (user,
  correcting the order: "they don't shut down until after the new is built, or we will have famines every time").
  The new farm waits as a plan in the builders' order book while the old one keeps producing; no gap in output.
- The government can offer an incentive to move (a grant programme like the family grants: time-limited, by need,
  with its coverage and its politics).
- Some farmers refuse, whatever is offered (the user on selling: "most would not sell even if they earned less, only if
  they had to"). A trait per farmer or family, so a relocation scheme never clears everyone, and pressure on holdouts
  becomes political.

## 2. Planning towns and villages
- The planet has 10,242 hexes and a century-old colony touches perhaps 10 to 40 of them. With that much room, where
  things are built becomes a question of its own: one growing town, or a town with villages around it.
- Questions for when this is taken up: who decides where a new settlement goes (government plan, founders following
  land and water, or both); zoning inside a settlement (homes, farms, industry, wild land kept as a buffer); roads and
  services to new villages; whether districts follow settlements; how planning law and the parties come into it
  (growth against protection, centre against outskirts).

## 3. Land-use rules per hex
User, 2026-11-15: "This could lead to governments locking out certain types of building in some hexes, like we have
agricultural land in real life."
- A government could reserve a hex for farming, for nature, or for housing and industry, and forbid other building
  there, as real zoning and protected farmland do.
- Questions for when this is taken up: who sets it (law, so Anni's area) and at what level; what happens to buildings
  already there; whether owners are compensated; how parties split (planet-first and farmers against developers and
  industry); whether it can be bent for favoured firms, and what that costs politically when it comes out.

## Connects to
- Terra's ecology and food pyramid (opt-in ECO), her planet map, transport and road needs.
- Family farms and bakeries (E160/E162), six family farms to a plot, neighbourhood bakeries placed by demand.
- The business-size ladder and shared plots the user raised on 2026-11-14 (also noted as "later", not planned).
- Districting law (Anni) and the government's building programme (Wilma).

## Who picks where a building goes (queued 2026-11-15; user: "I want a working colony first, but queue it with the other things")
Today nobody decides a site. The district is picked by a fixed rule (the government's building programme: the most
overcrowded district for housing, the worst access for a clinic or school; a founder: its best market signal), and the
spot inside the district is the nearest free tile of suitable terrain (ColonyLayout). Nothing weighs one site against
another, considers the neighbours, or reserves land.
Queued, not to start before the colony works: site choice as a real decision (options, neighbours' objections, land
reserved by use), belonging with town and village planning and the per-hex land-use rules above, and the natural first
power of municipalities (user: they start with building and roads). It is probably the largest missing source of
decisions for the First Minister's desk (Maja's desk count, chronicles/desk_count_v1: the code takes about 1.2 to 1.5
decisions a month because whole areas, siting among them, have no decision at all).

## Road speed, accidents near people, over- and underpasses (user 2026-11-15; reading confirmed by the user; queued)
User: "I'm not sure pedestrians need to really be in game, but accidents should. Any high speed road near utility
people walk to, and near districts, have chances for accidents; over and under passes reduce the chance. Also road
types should not be speed." And: "this would mean a motorway around a village instead of through can be a thing."
- No pedestrians as travellers.
- A fast road close to where people go on foot (housing, and what they walk to: clinics, schools, shops, workplaces)
  has a chance of accidents with injuries and deaths; faster road and more people nearby, higher chance.
- Over- and underpasses at such a spot reduce the chance: a thing to build, or to skip.
- Speed is its own property of a road, not its surface (track / road / paved sets what it carries and how it wears).
  A speed limit becomes a decision: slower near a district costs travel time and freight, and saves lives.
- So a fast road around a village instead of through it is a real choice (Terra's options already offer a BYPASS for
  capacity; with this it also has a safety case).
Today: accidents exist only for the transport fleet (vehicle condition and junction risk); nothing depends on where a
road runs; speed follows the surface (SPEED in transport.gd). Flyovers do not exist (every meeting of roads is a level
junction of four types). Deaths would go through the blame rules used for wildlife attacks and can be questioned by
the opposition (Rivalry). Changes the core road model, so it needs its own A/B. Not started.
