# spec-colony-v1 — The colonial relationship (M12)

Owner: Wilma (spec; the home world as an actor; politics). Economy: 88. Law and constitution: a9.

User decisions (2026-11-11, A34):
- The home world does **not** support the colony. Historically colonies supported the home world, not the other way round.
- **No food transports** and no subsidy lifeline. The colony starts with **its own resources** to build its economy.
- **Ships about every 2 years, irregular.** Even every 6 months is far too often.
- The colony **owes things the home world cannot get otherwise**: minerals it can no longer mine at home, things that only grow on this planet. (The American colonies had what England lacked; that was the point of having them.)
- The colony **can break away**: refuse, renegotiate, declare independence.

## 1. What is removed

| Removed | Was |
|---|---|
| Founding cash grant | ORIGIN_GRANT monthly to m48, taper to m120 (E58) |
| Free food aid | E61, up to 30% of food need |
| Monthly origin shuttle / import backstop | E65/E75/E85/E94 MATERIAL and COMPONENT backstop |
| Quarterly ship with government import orders | ECON_ORDER_IMPORTS arriving every 3 months |

Every essential (food, water, power, materials, components, housing) must be produced **locally**. The deadlocks the backstop used to solve must be solved locally:
- starting stockpiles;
- repair using local inputs (E84);
- priority rules (E89b, E95);
- government reserves;
- the forced sale of unrepairable plants (E91).

## 2. The founding endowment (replaces all support)

The colonists land with what the charter gave them, once:

- **Stockpiles** of food, seed, building materials, components and spare parts, enough for the first ~3 years while production builds up. Held by the government reserve and the founding companies.
- **Built capacity** at founding: power, water, farms, a mine, processing, a component works, a depot, housing. Small, but able to grow from local inputs.
- **Capital**: treasury reserves, founding-company equity and bank capital.
- **Tools/know-how**: the skill mix of the first colonists.

88 sizes it so that a reasonably run colony becomes self-sufficient before the stockpiles run out, and a wasteful one doesn't. Running down the reserve before building capacity is a real way to starve.

## 3. Colonial goods: why the colony exists

Two new goods the home world cannot get elsewhere (names are placeholders; the user may rename them):

- **RARE_MINERAL**: deposits exist in some districts only, are finite per deposit, and get harder to mine as a deposit depletes. New facility: rare-mineral mine (high hazard).
- **NATIVE_CROP**: grows only on suitable planet land; plantation facility; competes with food farming for land and water.

Both have little local use. Their value is export to the home world. They create planter/mine-owner wealth, a dependency on the home world as the only buyer, and land and water conflicts with food.

## 4. Ships

- Interval **18–30 months** (seeded draw), so roughly every 2 years and never on a fixed calendar. M11 hazards can delay or lose a ship.
- **Outbound to the colony:** migrants (a larger batch, since ships are rare), the home world's officials and inspector, and a small amount of high-value cargo that can't be made locally yet. It is very expensive and limited by cargo space. No food.
- **Return to the home world:** the colony's obligations (§5) and any legal sales of colonial goods.
- A ship's arrival is a political event: demands, news, inspections, new migrants.

## 5. What the colony owes (the charter)

The founding charter (a9: charter rules, constitutionally entrenched) sets:

- **Quota:** a share of colonial-goods output (default 40%), delivered on each ship at a **charter price** well below their value (the home world's profit).
- **Exclusive trade:** colonial goods may be sold **only** to the home world, at the charter price (navigation-acts style). Selling to anyone else, or holding back, is smuggling or evasion.
- The colony may not tax or obstruct the quota.

The gap between the value and the charter price is the colony's real burden. It falls on producers, workers and the treasury, depending on law. This becomes a measurable grievance (a new concern, §7).

## 6. The home world as an actor (Wilma)

A simple off-planet actor with its own state:
- **demand pressure**: home-world need, which can rise at random (shortages at home, war, a new ruler);
- **patience**, and its **perception of colonial loyalty**.

On each ship it:
- collects the quota;
- inspects through an inspector who can detect evasion (a9's detection machinery);
- may **raise the quota or cut the charter price** (a "Stamp Act" moment);
- answers petitions.

Its sanctions for evasion or defiance:
- fines;
- withholding migrants and cargo;
- revoking privileges;
- appointing a governor with veto powers;
- a **punitive expedition** that arrives on a later ship.

## 7. Breaking away

Three paths, escalating:

1. **Renegotiation.** Parliament petitions the home world, which answers on the next ship. Acceptance depends on the colony's leverage (share of the home world's supply, colony unity, self-sufficiency) and on home-world need.
2. **Refusal.** The colony stops delivering the quota or ignores the charter price. Sanctions follow (§6) and the crisis escalates on every ship.
3. **Independence.** A constitutional act (a9: procedure, e.g. a parliamentary supermajority plus a referendum). The home world's response, decided when the next ship comes:
   - **accept**: trade as equals at market prices;
   - **blockade**: no ships at all, for years;
   - **punitive expedition**: an abstract confrontation resolved by the colony's self-sufficiency, unity, preparation (a militia lever) and distance; no combat simulation.

   Outcomes: independence won, a negotiated autonomy, or the colony brought back under a harsher charter.

After independence the era becomes INDEPENDENT: no obligations, ships as trade partners, and the colony's constitution stands alone.

## 8. Politics (Wilma)

- **New axis SOVEREIGNTY** (loyal to the home world ↔ independence), alongside spec-population D3's 9 axes, giving 10 in total.
- **New concern COLONIAL_BURDEN**: quota share, the charter-price gap and sanctions.
- Who leans which way:
  - **colony-born** people (spec-population `recent` = 0, second generation) lean toward independence over time;
  - **new arrivals** and people tied to the home-world trade lean loyal;
  - **planters and mine owners** are split: they gain from the trade but hate the charter price.
- **Parties:** loyalist and independence parties can form through the existing founding rules (unrepresented / single-issue). Every party takes a SOVEREIGNTY position. Campaigns peak around ship arrivals and home-world demands.
- **Government AI:** petitions, compliance or defiance, and independence motions, decided by its position, the colony's leverage and public mood.
- **The chronicle** records:
  - every ship: arrival, cargo, migrants, quota delivered;
  - every home-world demand and sanction;
  - petitions, refusals, independence votes and outcomes.

## 9. Ownership

- **88:**
  - remove the support (§1);
  - the founding endowment (§2);
  - RARE_MINERAL and NATIVE_CROP with their facilities, deposits and land (§3);
  - ships: schedule, cargo, migrants (§4);
  - quota delivery and the economics of smuggling and evasion (§5);
  - the economy gate rebaselined without support.
- **a9:**
  - the charter's obligations as entrenched rules (§5);
  - the home-world inspector's detection and the legality of sanctions (§6);
  - renegotiation and independence procedures and the INDEPENDENT era (§7);
  - a militia lever.
- **Wilma:**
  - the home-world actor (§6);
  - the SOVEREIGNTY axis, the COLONIAL_BURDEN concern, parties and the AI (§8);
  - the chronicle.

## 10. Gates

1. **Self-sufficiency:** with no support at all, a reasonably run colony survives (≥ 4/6 seeds on the rebaselined economy gate). A deliberately wasteful one (stockpiles spent, no capacity built) collapses.
2. Colonial goods are produced and shipped, and the burden is felt (a COLONIAL_BURDEN grievance exists).
3. Over 6 seeds × 100 years: home-world demands vary; at least one run reaches renegotiation or refusal; independence happens in some runs but not all; outcomes differ.
4. Ship intervals vary between 18 and 30 months, plus hazard delays. Deterministic per seed.
5. M11 interplay: a lost ship, a home-world blockade and a famine are all possible, and none of them is a scripted certainty.

## 11. Order

M11 (crises) and M12 are built together: ships are an M11 hazard target, and self-sufficiency is what M11 tests. 88 starts with §1 + §2 (support removed, endowment) because everything else depends on a self-sufficient economy; then §3–§5. a9 builds the charter rules and procedures in parallel. I build the home-world actor and politics.
