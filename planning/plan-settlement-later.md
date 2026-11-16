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

## Three farm crops (user 2026-11-15; decided: after v11, as its own step)
User: "No splitting, a farm grows one or the other, same space"; "three types of farm crops: cotton for clothes,
grain for food with a by-product of hay, and beef; beef being more expensive but increasing enjoyment by those that
eat it; it would reduce food made too but increase happiness".
- A farm (big or family) grows one crop on its whole plot; switching takes time (cattle longest: a herd is built up).
- Grain: today's food; hay comes with it. Cotton: the input of the textile workshops (CLOTHING). Beef: uses the hay,
  dearer, feeds fewer per plot, a step above bread in what people like to eat (as bread is above raw food, E146).
- A second and third thing to grow is also the farmers' answer to a food glut.
- Each crop needs its eight rules and buyers who bid what it is worth to them (Bob's food step, R8_FOOD, keeps the
  farm's crop a single field so the switch can be added without rework). Cattle and Terra's predators (ECO) go together.
Not started.

## Town grids and housing form (user 2026-11-15; queued after v11, a free session may code it without game runs)
User: "I am thinking of it as something the game should model; 50 homes on 3x3 km is most likely separate housing,
just based on space alone"; on a finer scale: "The two level seems good, that way we can have small housing at start,
get apartments and eventually highrises; the towns and cities would look more like real ones."
- Two levels: the 3 km tile stays for the country (farms, mines, roads between settlements, wildlife); each
  settlement gets its own fine grid (about 100-300 m a cell) that exists only where a town is. Homes, shops, the
  clinic, streets, crossings and passes live there.
- Housing form per block: small houses at the start, then apartments, eventually high-rises. A cell takes about ten
  houses or one apartment block, so a town grows outward or upward.
- At today's scale land never forces apartments (a 900 ha tile would hold 9,000-18,000 houses), so the reasons must
  be the real ones: the cost of reaching each home with road, pipe and cable; distance to work and services; how fast
  and cheaply many homes can be built; what families prefer (a house over a flat); farmland lost at the town's edge.
- Belongs with town planning, land reserved by use (Terra's SITING), who picks a site, road safety near homes, and
  municipalities (building and roads first).
Today: a housing block is 50 homes with no form (EconRulesHousing.BLOCK_UNITS); a tile records a number of homes;
an area splits above 800 residents.

### Further rulings on town grids (user 2026-11-15)
- Cell size 100 m and three forms: "Yes, enough for now."
- Houses only at first or apartments from the start: "Up to the commander, I think." (a choice of whoever governs)
- Not perfect circles: "schools, utilities and other things should affect where things are made ... like coastals
  building along the water, or staying close to schools and bakeries to get good access, or near jobs, like Rydebäck
  that began as housing for a power plant."
- No finer level before it is needed: "like the main map, maps should not become the next level until necessary."
- Location value: "There needs to be a lucrativity score for buildings made; view, like the ocean or rivers, or
  nearness to things makes it more expensive, like the houses in Höganäs: the closer to the coast you get the more
  expensive they get; it can even shift from road to road."
- Why a town builds upward: "The step-up should come from many factors: an apartment complex on the beach may be
  more attractive because you can rent them all out, or a school district has no more space, or, the most common,
  they are simply cheaper living."
Design note: planning/design-town-grid.md (Terra). Groundwork under flag TOWN_GRID, unit tests only.

## Empty buildings: sold, reused or torn down (user 2026-11-16: "after 11, and yes") — ordered, after v11
Today a failed firm's plant that finds no buyer is "scrapped" (EconInsolvency.scrap): it stays standing for ever,
book value 0, crew laid off, never restarted; only the government can buy and restore it; nobody else can buy,
reopen or reuse it, and nothing is ever demolished. The bank recovers nothing on it and the site is lost.
User: "You telling me these buildings are just scrapped? Like torn down?"
To build after v11:
- a finished, empty building is sold, cheaply if need be, to whoever will take it: another firm, a founder, a family,
  the state; the proceeds go to the failed firm's creditors (the bank first today; Anni's creditor order, E174);
- the buyer reopens it or changes its use (Ella's EconConversion from HIRING stage 4b is the general change of use;
  Otto's EconUnfinished covers unfinished shells);
- a building nobody wants is in the end demolished, at a cost, and its site is free again (the first real demolition
  in the game; law_data has DEMOLISH_FACILITY as a name only).
Owner: Otto (ownership and sales), with Ella's conversion and Anni's creditor order.
