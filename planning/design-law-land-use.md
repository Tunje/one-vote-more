# Land-use law: reserved land, siting, compensation, farms that move (Anni, design note, 2026-11-15)

Status: design note only, no code. It is the law side of Terra's reserved land and site options (flag SITING;
planning/plan-settlement-later.md, "Who picks where a building goes" and §1–§3). Everything here is opt-in behind
SITING, with levers carrying `"requires": ["SITING"]`. Nothing starts before the user's go.

User, on what this is for:
- "This could lead to governments locking out certain types of building in some hexes, like we have agricultural land
  in real life."
- On farms: "they don't shut down until after the new is built, or we will have famines every time"; "this could be
  something the government gives incentives to, but some farmers should resist."
- On municipalities: "they start primarily with building and roads."

## 0. What exists today (sim/law/land_law.gd, M13)
- **Titles**: every tile is the state's until granted. A title is owned or leased, by a company, a household or the
  state.
- **Zones per tile**: UNZONED, RESIDENTIAL, INDUSTRIAL, FARM, RESERVE. `can_build` checks the title and the zone's
  uses. `zone()` is an executive act (rule ZONE_LAND; private actors never hold it).
- **Expropriation**: lawful with a public purpose and at least 100% of the land's value, plus the rest of any lease.
  Below that it is unlawful; the rules engine records it.
- **Eviction and clearance**: these only set when people must move. Bob and Wilma move them.
- **Not there yet**: a reservation as a planning act (zones are now only a check), permits against a zone, neighbours'
  objections, compensation for lost value, and anything about farms moving.

What this note adds: a reservation is the existing zone. It gets a legal level, a permit procedure, a hearing,
compensation rules and a relocation order. Terra keys reservations to her cells; the law follows her key.

## 1. Who reserves land, and at what level
| Act | Legal level | Who | Notes |
|---|---|---|---|
| The rules: what a reservation may forbid, how hard it binds, what owners get | LAW (parliament) | levers below | Base: today's zones |
| Reserve cells for a use (farm, nature, housing, industry), or lift a reservation | REGULATION | Minister of Infrastructure (planning). With AGRI_MIN, farmland is Agriculture's; with ECO, nature reserves are Environment's. | Alone up to RESERVE_CABINET_CELLS (proposed 6) cells and within 2 districts |
| A larger plan: more cells, 3+ districts, or a whole settlement's plan | Cabinet decision | Cabinet | Like the road licence's 3-district rule |
| Lift a reservation the Cabinet made | Cabinet | Cabinet | A minister cannot undo the Cabinet |
| Later: a local plan inside a municipality | Municipal decision | Municipal council | Must fit the colony plan; see §7 |

- A reservation is public: fact LAW_LAND_RESERVED {cells, use, by, decided_by, districts}.
- It is felt where it lies: the districts' HOUSING, JOBS or ENVIRONMENT_QUALITY, by what it allows or keeps out.
- Existing buildings stay. A building already standing is an "existing use": it may keep running and be repaired,
  but not enlarged against the reservation. This is the hook for §5 (farms told to move).

## 2. Building against a reservation
Three routes, each a pressure, not a ban:
1. **A permit to depart** (variance), asked for by the builder, the state included:
   - The application opens a 2-month objection window, as for road licences.
   - The minister who holds the reservation decides, or the Cabinet if the Cabinet made it or the site touches 3+
     districts.
   - Lawful grounds: no other reasonable site (Terra's site options list none outside the reservation within reach),
     an essential service (clinic, water, power, a road), or a temporary use.
   - **Granted with grounds**: LAW_RESERVE_PERMIT_GRANTED.
   - **Granted without grounds**: lawful but appealable. An objecting district (or any party, at a lever's
     strictness) can go to the administrative court, which quashes it after the court's duration.
     Facts LAW_RESERVE_PERMIT_UNGROUNDED, then LAW_RESERVE_PERMIT_QUASHED. A building already begun stops; what
     was built is the builder's loss.
   - **Refused**: LAW_RESERVE_PERMIT_REFUSED. The builder looks for another site.
2. **Building without a permit**:
   - A greed kind for companies, BUILD_IN_RESERVE (channel MARKET, class MINOR; MAJOR on nature reserves).
   - Detected by the usual inspection and discovery.
   - The remedy is a fine plus either a demolition order or a retroactive permit (a fee of the permit's worth, twice
     over). Which one is the minister's decision, with its options in one function.
   - Retroactive permits for a firm with ties to the governing parties (donations, party finance records) are the
     corruption channel: LAW_RESERVE_FAVOUR when revealed, QUESTIONABLE.
3. **The state building on its own reservation without a permit or a re-zoning**:
   - Lawful only by Cabinet decision.
   - Done by a minister alone, it is an UNLAWFUL_GOV act. A district or the opposition can bring the case.
   - It happens if the government chooses it; the court and the facts are the cost.

Strictness lever **LAW_LAND_PLAN_FORCE** [0..2], default 1:
- **0 guidance**: a permit is a formality and nobody can appeal.
- **1 permit with grounds**: the routes above.
- **2 strict**: only the Cabinet may permit, and only on essential grounds.
- Party leanings: ideology ECON_ROLE +4 per step; concerns ENVIRONMENT_QUALITY +4, HOUSING −3, JOBS −2.

## 3. Neighbours' objections to a site, and what an override costs
Terra's site options carry their neighbours: settlements within the use's nuisance radius, as for waste sites.
- **Who may object**: districts within the radius, for any site of a nuisance kind (landfill, incinerator, treatment
  works, crematorium, mine, heavy industry, the spaceport) and for any building against a reservation.
- **Grounds**: HOUSING (homes within the radius), FARM_LAND, NATURE (with ECO), and TRAFFIC (with ROAD_SAFETY: a
  busy road past homes).
- **Weight**: as for road licences, grounds × the district's satisfaction with what it would lose (ENVIRONMENT_QUALITY
  for nuisances, HOUSING for housing land) × the government's vote share there.
- **The decision**: the minister picks a site from Terra's options, or the Cabinet when 3+ districts object.
  - Overriding an objection is lawful. Each overridden district gets LAW_SITE_OBJECTION_OVERRIDDEN with
    "affected": {"districts": [d]}, felt in that district only (the road-licence pattern, already accepted by Wilma).
  - Picking a site no district objects to is the cheap choice. Terra's options say what it costs: distance, land
    price, a road first.
- **The cost of an override**:
  - The fact itself.
  - Optionally a nuisance payment (lever LAW_NUISANCE_COMPENSATION [0..2]: 0 none; 1 a one-off payment to the
    households within the radius; 2 a yearly one while the site runs). Bob books the money.
  - Ideology REDISTRIBUTION +3 per step; concerns ENVIRONMENT_QUALITY +3, COST_OF_LIVING +1.
- **No objection window**: emergencies (Wilma's emergency powers), and sites inside an existing reservation for that
  use. Reserving the land was the hearing.

## 4. Compensation when a reservation takes value from an owner
Three cases:
- **An existing use is forbidden or ended** (a farm's land reserved for housing and the farm ordered out, §5):
  - That is a taking. The state pays the full value of the land and the buildings, plus the cost of moving
    (disturbance).
  - Below that it is unlawful, the same rule as expropriation, which already exists.
- **A use the owner held a permit or a plan for is forbidden** (a licence granted, a building in the builders' order
  book): the owner gets back what it spent.
- **Only hope value is lost** (land that might one day have been built on): nothing, unless the lever says otherwise.

Lever **LAW_PLANNING_COMPENSATION** [0..2], default 1:
- **0**: only takings are paid.
- **1**: takings, plus spending on permits and plans.
- **2**: also the drop in land value from a reservation, on Bob's land value before and after.
- Party leanings: ideology ECON_ROLE −4 per step (owners' protection); concerns FAIRNESS +2, COST_OF_LIVING −1.

**Purchase notice**: an owner whose land is left with no reasonable use may require the state to buy it at its value
before the reservation. The minister must buy or lift the reservation within 6 months. Doing neither is unlawful and
appealable. Fact LAW_PURCHASE_NOTICE, then LAW_LAND_BOUGHT or LAW_RESERVATION_LIFTED.

Money flows are Bob's. The law says what is owed, by whom, and when: liabilities as in road law.

## 5. Farms told to move
The user's order of events is the rule:
1. **The order**: the minister holding the reservation may order a farm standing on land reserved for something else
   to move. It is a relocation order, a REGULATION act. It needs the Cabinet if it covers more than 3 farms or any
   family farm against its will.
2. **The offer comes first**:
   - The order names a new site from Terra's options for a farm (better land further out).
   - The order also names an incentive. That is a grant from the government's own programme, Wilma's and Bob's: time-
     limited, by need, with its coverage and its politics. The law only requires that it exists, and that the old
     site's value is paid if the state takes the old land.
3. **The new farm is built first**: it waits in the builders' order book while the old one produces. The old farm
   shuts only when the new one opens. No gap, no famine.
   - The law enforces the order of events: a relocation order that shuts the old farm before the new opens is
     unlawful (an UNLAWFUL_GOV case).
4. **The farmer answers**: ACCEPT, or REFUSE. A trait per farmer or family is Bob's; the user says some refuse whatever
   is offered.
   - A holdout may keep farming as an existing use, lawfully, for as long as it likes. Fact LAW_FARM_HOLDOUT, public:
     the press likes these.
   - The government's choices against a holdout, one function with its options:
     - **WAIT**: the farm stays and the reservation is not used there.
     - **RAISE**: a better offer, a larger grant.
     - **EXPROPRIATE**: a compulsory purchase at full value, plus the move and the new farm. It is a Cabinet
       decision with a public purpose (the housing the reservation is for). Fact LAW_FARM_EXPROPRIATED, magnitude
       high for a family farm, with "affected" for its district.
     - Paying less than the value is unlawful (the existing EXPROPRIATE rule) and is proceeded with only at the
       government's choice, through proceed_unlawfully, as everywhere else.
5. **Clawback**: a farm that took the incentive and did not move within the order's time repays it. This is a
   liability, as with family grants.

## 6. Bending the plan for favoured firms
Covered by §2 and the existing corruption channel. A permit or a re-zoning given to a firm with ties to the
governing parties is recorded with the tie. When it is revealed (discovery, the press, a rival's dirt), it is
LAW_RESERVE_FAVOUR, QUESTIONABLE weight 3.0, like POL_GRANT_FAVOURITISM. The law does not stop it.

## 7. What belongs to a municipality when those exist
The user: municipalities start with building and roads.

| Power | Municipality | Colony (minister or Cabinet) |
|---|---|---|
| Local plan: reservations for housing, local services, local industry inside its borders | yes | sets the colony plan they must fit, and may call a local plan in (a Cabinet decision, with a fact) |
| Farmland and nature reserves | may add, not lift | holds them |
| Permits to depart from a local reservation, and objections to local sites | yes | appeals go to the administrative court, not to the minister |
| Nuisance sites of colony importance (landfill, incinerator, treatment works, spaceport) | is heard as an objector | decides |
| Speed limits and local roads (road safety law) | on roads inside it | on roads between municipalities, and the default limit |
| Expropriation | may ask the minister | decides (Cabinet); the law sets compensation |
| Compensation rules, purchase notices | pays for its own reservations | sets the rules (levers) |
| Farm relocation orders | may ask | decides; the incentive is the colony's programme |

A municipality's budget pays for its own planning decisions: its reservations' compensation, and its nuisance
payments on its sites. That makes the tax arrangement (design-delegation.md §9) bite.

## 8. Facts, and suggested opposition weights (Wilma)
| Fact | Who is blamed | Suggested weight |
|---|---|---|
| LAW_LAND_RESERVED | government | public, no weight (policy) |
| LAW_RESERVE_PERMIT_GRANTED | government | 1.0 |
| LAW_RESERVE_PERMIT_UNGROUNDED | government | 2.0 |
| LAW_RESERVE_PERMIT_QUASHED | government | 2.5 |
| LAW_RESERVE_PERMIT_REFUSED | government | none |
| LAW_SITE_OBJECTION_OVERRIDDEN | government, one per district | 2.0 |
| LAW_RESERVE_FAVOUR | government and the firm | 3.0 |
| LAW_PURCHASE_NOTICE / LAW_LAND_BOUGHT / LAW_RESERVATION_LIFTED | government | none |
| LAW_FARM_MOVE_ORDERED | government | 1.0 |
| LAW_FARM_HOLDOUT | government | none |
| LAW_FARM_EXPROPRIATED | government | 2.5 |
| Greed kind BUILD_IN_RESERVE | the firm | through the usual violation facts |

None of these types is a prefix of another, so world.facts.query matches them correctly.

## 9. What I need from others
- **Terra**:
  - reservation storage per cell, and whether it stays on land_title zoning or moves to her cells;
  - site options with the neighbours and grounds per option;
  - "no other reasonable site" as a field on an option.
- **Bob**:
  - land value before and after a reservation (§4, level 2);
  - the farmer's resist trait, and the new farm in the order book linked to the old one;
  - money for compensation and nuisance payments.
- **Wilma and Maja**:
  - the decisions are cases: reserve, permit, site, relocation, holdout, unpermitted building;
  - the incentive programme is the government's;
  - the weights in §8.
- **The user**:
  - whether a reservation can cover existing homes (never forcing anyone out without expropriation, as here);
  - whether parties may campaign on a specific site;
  - whether municipalities get appeals against colony call-ins.

## 10. Build order (once SITING exists and the user says go)
1. The levers, the reservation act with its legal levels, permits and appeals, and BUILD_IN_RESERVE.
2. The hearing and overrides on Terra's site options, and the nuisance payment.
3. Compensation, purchase notices, relocation orders, holdouts and farm expropriation.
4. Municipal powers, when municipalities exist.
