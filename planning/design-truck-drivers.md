# Truck drivers and truck workshops

Status: ORDERED by the user on 2026-11-16 ("Get it started"), after being discussed as an idea the same day ("what do
you think? No not make think"). Owners: Bob builds the truck drivers and the trucks (family haulier, grant after the
plan, special orders at the components works); Ella builds the truck workshops (repairs, and better trucks). They
agree the truck record between them. The numbers under "Not settled" are to be proposed by them, labelled theirs.

## Why it came up

In the 30-year games with every sector's rules on, freight is what kills the building boom. The whole colony runs on
one depot of the public transit authority. Truck capacity is added a quarter of a depot at a time, one job at a time,
and the extension ordered in year 5 sat at 0% done for six years because the material for it could not be
delivered: the trucks were full. In years 9 and 10 over 7,000 units a month were left behind against 2,400 to 3,500
carried. No private haulier has ever been founded in any game: starting one means building a whole depot.

## The user's words (verbatim, in order)

1. "Two new businesses we are adding started by grants alla bakeries, truck drivers and truck workshops! Same rules as
   before what do you think? No not make think"
2. "Ah no, like this workshop is too fix private trucks that break down, is do it like this if you're truck breaks
   down you can fix it yourself in about 4 months or drive to a workship and have it fixed now"
3. "Also trucks for this should be able to be built at the component workshop as special orders"
4. "But trucks have quality that's what governs breakdown and a component factory is not the best at making them but
   the workshop can!"
5. On Wilma's suggestion to build trucks on the same footing as the bus fleet, so there is one way vehicles work and
   not two: "Agreed"

## What that says

- Two new kinds of business, started with grants the way the family bakeries are, under the same rules as every
  other producer: truck drivers, and truck workshops.
- A truck has a quality. Quality governs how often it breaks down.
- A broken truck can be fixed by its owner in about four months, or driven to a workshop and fixed at once. So a
  workshop is never required for trucks to run; it sells speed.
- Trucks can be built at the components works as special orders. The components works is not the best at it: its
  trucks are of lower quality. A truck workshop can build better ones.
- Trucks work the way buses already do (EconFleet: breakdowns, repairs, parts), one footing for vehicles.

## Not settled (Wilma's list, none of it decided by the user)

- How quality turns into breakdowns; how often a poor truck fails against a good one.
- Whether a workshop repair improves a truck or only restores it; whether a self-repair costs quality; whether a
  truck wears with age.
- Whether a repair needs parts (Wilma's view: the self-repair should not, so nothing can stop for want of parts).
- What a truck costs the components works to make, and how much one truck carries against the depot's 2,200 to 3,500
  units a month.
- Whether the transit authority can order trucks by special order too, and whether its trucks use the workshops.
- That a truck driver needs no building to start (the truck parks at home); otherwise it joins the builders' queue.
- What happens when no components works is running (by the existing rule: ordered from the home world, with a ship
  in port, a full round trip).
- The risk seen with the service hubs: founders reading the average of all the freight may start many at once.

## Parts that exist

- Private hauliers with their own rate, cheapest carrier with room first: sim/economy/econ_haulier.gd (R8FR_PRIVATE).
- The grant machinery of the family farms and bakeries: sim/economy/econ_family.gd, with the plan first and the
  grant after the plan.
- The bus fleet: sim/economy/econ_fleet.gd.

## The political side (Wilma's; the user, 2026-11-16: "Don't forget the political side")

Owner: Wilma. Built with the economy side, not after it.
- Two grant programmes decided by governments, like the family farm and bakery grants: a law-level lever each (how
  generous an approved grant is), opened for a limited time, reset when the programme ends, a new decision needed
  for a new one. Approved on need only: freight being left behind for drivers, broken trucks in reach for workshops.
- The need reaches Parliament the way the farm grants' need does (the economy publishes it per lever; parties vote
  it by their politics, so a government may refuse and live with the freight jam).
- Where a programme lands (which districts) is a government decision, as for the family grants; a case on the desk
  under DELEGATION.
- Private drivers against the public transit authority is a question of who should run the economy (ECON_ROLE):
  state-minded governments favour the authority's own depots and trucks, market-minded ones the drivers' grants.
  The authority's crews and their union have an interest against it.
- News: a programme opened and ended with what it paid, the first private driver, a freight jam, trucks off the road.
- Law (Anni): whether a driver or a workshop needs a licence is a law that may make it dearer, never forbid it.

## Rulings as they come

- 2026-11-16, on Ella's proposal that a workshop repair restores a truck but never raises its quality (the user,
  verbatim): "No improvements for trucks set quality stays". So a truck's quality is set when it is built and never
  changes. Ella's other proposals (a repair brings wear back to new; a self-repair leaves the wear; trucks wear with
  age like buses; a workshop repair uses components and a self-repair none; a workshop's trucks are better as a fact
  of who made them) are not yet answered.
- 2026-11-16, on whether trucks wear with age and whether a workshop's trucks are simply better than the components
  works' (the user, verbatim): "Yes they ware, yes and no the components ones are always lowest quality workshops
  make different depending on ware and quality of parts". So trucks wear with age. A truck from the components works
  is always of the lowest quality. A truck from a workshop is of a quality that depends on wear and on the quality of
  the parts it is built from (Wilma's reading: the workshop's own wear, and the components it gets; to be confirmed
  with the user if Ella needs it narrower). Still not answered: whether a workshop repair brings a truck's wear back
  to new while a self-repair leaves it; whether a workshop repair uses components.
