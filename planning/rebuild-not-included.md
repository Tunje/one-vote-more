# What the old economy had that the new plan does not include

Asked by the user, 2026-11-17: "Go through the old version listing any system we gave not included in the new".

How it was made: Wilma went through the old economy as it stood in commit 785c72f (`game_full_copy/`): the 72 files,
its 50 levers, 39 indicators, 26 government actions, about 150 published events and about 110 numbered mechanisms, and
checked each against [rebuild-company.md](rebuild-company.md) version 11. Listed here is every SYSTEM of the old game
that the new plan does not have. Old fixes for faults of the old design are not systems and are left out.

Each line says what it was. Nothing here is decided.

## A. Not in the new plan at all

### Companies

1. **Management.** Every company had a chief with a management skill and an appetite for risk. Management changed how
   much a plant could really make, how well a builder used its crew and how a founder judged a market. A failing
   company replaced its chief.
2. **Plant upgrades.** A plant could be upgraded to a better tier, taking less in and giving more out, as a building
   job. The new plan has sizes and nothing about a better plant of the same size.
3. **Mothballing.** An owner could close a plant for a while and reopen it, keeping it without running it. The new plan
   has a "closed" state on a plant but no rule for when an owner does it or what it costs.
4. **A plant closed as unsafe.** A hazardous plant in bad condition was closed, kept a small repair crew and reopened
   after an overhaul.
5. **Workers buying a failed plant.** When a company died its workers could take a plant over as a co-op.
6. **The state taking over a failed company's essential plants.**
7. **Rescue before the end:** a company in trouble could be run by an administrator, have its debts rescheduled, or sell
   a stake in itself to raise money. A plan in trouble could sell shares, get a bank extension or a government
   bail-out. (The new plan has three endings and no rescue. The user's ruling on endings does not mention one.)
8. **Credit lines.** Besides loans, a company had a running credit line for wages and supplies in a bad month.
9. **Corner-cutting detail:** deferring upkeep and under-staffing for money, with the risk of accidents. The new plan
   keeps the choice to break the law for gain but not these two ways of doing it.

### People and work

10. **On-the-job training.** A firm with open skilled posts trained people from the tier below; the state could pay
    part of it. The new plan has schools setting a child's skill and nothing that changes an adult's.
11. **Sickness.** Poor clinic access kept part of the labour force too ill to work. The new plan has clinics lowering
    deaths only.
12. **The public employment scheme:** the state hiring the jobless for upkeep work at low pay.
13. **Food assistance** for households that cannot afford food; **a floor and a time limit on the benefit**; **a tax
    allowance.** The new plan names the benefit and pensions only.
14. **Lockouts and arbitration.** An employer could lock workers out, and a banned strike went to arbitration. The new
    plan has shutdowns ordered by a union.
15. **Who pays first when a household is short.** The old order was food, then water and power, then rent, with unpaid
    rent becoming a debt to the landlord. The new plan says rent and bills are set aside first.

### Money and the state

16. **The home world's development grant:** money from the home world to the colony's government in the early years,
    tapering to nothing.
17. **The bank's yearly remittance** of profit to the home world.
18. **A government that cannot pay:** sovereign default, and creditors writing off part of the debt after a time.
19. **Bank rescue:** the government bailing out or recapitalising the bank, the bank selling shares, a credit freeze.
20. **Subsidies and incentives.** The government could subsidise a company, pay part of the cost of a plant it wanted
    built, and subsidise strategic goods. (The new plan has four grant types and nothing else, on the user's ruling
    that not everyone gets grants.)
21. **The government buying and selling plants:** nationalising and privatising.
22. **Who expands the economy as a policy:** a lever for market, mixed or state, which decided whether new plants went
    to private investors or to the state's companies.
23. **State companies paying a dividend** to the treasury.
24. **How the state picks a builder:** a lever weighing price against the builder's record and speed. Builders had a
    reliability record.
25. **The public builder of last resort:** the public works department bid only when no private builder would, at cost.
26. **Fees at the door** for clinics and schools, as levers.
27. **The cost of cleaner production:** a lever that cut emissions and raised costs.
28. **The government securing the essentials:** a government watching food, power, water, material and components and
    commissioning a plant when one ran short. (The code that decides this is politics' and still stands in `game/`; it
    has nothing to act on in the new plan.)
29. **The caretaker government** that ran the economy in tests without politics.

### Utilities

30. **Who is cut first when power or water runs short:** water before power for households, farms and clinics; outages
    as events.

### The home world and the port

31. **The home world's prices,** which moved, and what the colony's exports earned.
32. **The port's size:** a full port left cargo on the dock.
33. **The charter quota:** goods the colony owed the home world at a fixed low price.
34. **The home world's food aid** after two months of serious hunger. (It sits inside the household code that is taken
    wholesale, so it may come in with it unnoticed.)

### What other parts of the game read

35. **The reference wage.** One number for the colony's general wage, which the law used for fines, the press for its
    costs, and benefits for their size. With a salary per company and area it no longer exists.
36. **The fiscal report and the economic briefing** a government could publish or ask its staff for.

## B. Left out on purpose, by a ruling or a decision

- **Fabrication kits** (the colony landing with a crude smelter and workshop): against "materials come with the start
  not finished buildings".
- **Companies placed at the start** (farms, a mine, a material plant, a landlord): against the same ruling.
- **The six districts:** "no sectors beyond landfallpoint".
- **Essential plants hiring first; speed limits on hiring; price floors and ceilings of our own; the cap on companies
  forming:** the user's rulings against hard rules.
- **The emergency import shuttle** that delivered between ships: against "nothing reaches the home world except on a
  ship in port".
- **Supply contracts, buying on account, storage space, quality and reputation of goods, private roads, a union
  federation:** left out for now by Wilma (plan section 12.11).
- **The self-employed** as producers outside any company: they become family-size service companies (plan 12.5).

## C. One thing the plan may have wrong

The user said the colony starts with "5 years worth of equipment that never changed they are companies from the world".
Wilma wrote that into the plan as a stock of material, components and food belonging to the colony.

The old game has the user's earlier words on this: "a company going to a colony would have 5 years of costs calculated
and saved before going". That was built as each home-world builder arriving with five years of its own running costs.

So "that never changed" most likely points at that: the five YEARS belong to the home-world companies, each arriving
with five years' worth of what it needs, and "materials come with the start" is the separate statement that the colony
lands with materials and no buildings. The plan is corrected to say so; whether the colony's own stock includes food is
not something the user has said.
