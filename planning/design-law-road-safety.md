# Road safety law (Anni, 2026-11-15): speed limits, the default limit near homes, liability for road deaths

Status: coded behind Terra's flag ROAD_SAFETY in sim/law/road_safety_law.gd, with tests in
tests/law/test_road_safety_law.gd. Unit tests only, no game runs. The transport side is spec-transport-v1.md T9; the
government's own speed-limit and pass decisions are Maja's cases in gov_builder (SPEED_LIMIT, ROAD_PASS).

## 1. Who sets a speed limit
| Act | Who | Level |
|---|---|---|
| A limit on any colony road, public or private | Minister of Infrastructure, alone | traffic order (no money, only travel time); the government's case SPEED_LIMIT |
| A default limit on every road with homes, a school or childcare in reach | Parliament | lever LAW_SPEED_NEAR_HOMES (0 none / 1 → 70 / 2 → 50 / 3 → 30 km/h), requires ROAD_SAFETY |
| An exemption from the default limit for one road | Minister, alone | raising or lifting a limit the law set exempts the road from then on (fact LAW_SPEED_EXEMPTION) |
| A lower limit on its own private road | the owner | never above the law's or the minister's limit, never lifting one (may_set_limit, owner_limit) |
| Later: limits on roads inside a municipality | the municipal council | the colony keeps roads between municipalities and the default limit |

How the default limit is applied:
- It is applied monthly. It lowers any faster road that it reaches.
- When parliament loosens it, the roads the law limited follow. When parliament repeals it, they go back to the limit
  they had before.
- When the minister sets a road lower, the minister's limit governs.

The default limit costs travel time on those roads through Terra's route speeds. Party leanings: concerns SAFETY +4 and
INFRASTRUCTURE −2 per step; ideology ECON_ROLE +1.5 per step.

## 2. Liability for deaths and injuries (the courts)
The victims sue (a TORT case into the victim fund, 15 W_ref a death and 2 W_ref an injury) when whoever kept the road
failed a duty:
- **A pass refused** (Terra's pass_refused: an over- or underpass on offer 3+ months and not built):
  - on a public road, the state;
  - on a private road, the owner 0.6 and the state 0.4 (as traffic authority it could have imposed a limit).
  - Fact: LAW_ROAD_LIABLE_PASS.
- **A neglected private road** (a neglect notice under the private-roads law): the owner. If the government chose to
  leave the road neglected (LAW_PRIVATE_ROAD_UNENFORCED in the last year), the owner 0.8 and the state 0.2.
  Fact: LAW_ROAD_LIABLE_NEGLECT.
- **Blame only, no court case** (setting limits is policy):
  - a death within 12 months of the government declining a limit (its SPEED_LIMIT case answered WAIT):
    LAW_ROAD_DEATH_LIMIT_DECLINED;
  - a death on a road exempted from the default limit: LAW_ROAD_DEATH_EXEMPT.

All facts are PUBLIC and carry "affected": {"districts": [the accident's district]}.

## 3. Suggested opposition weights (Wilma)
| Fact | Weight |
|---|---|
| LAW_ROAD_LIABLE_PASS | 2.5 |
| LAW_ROAD_LIABLE_NEGLECT | 1.5 (the owner carries most) |
| LAW_ROAD_DEATH_LIMIT_DECLINED | 2.0 |
| LAW_ROAD_DEATH_EXEMPT | 2.5 |
| LAW_SPEED_EXEMPTION | 1.0 |
| LAW_SPEED_LIMITS_BY_LAW | none (parliament's act) |

## 4. Not done
- Drivers' own fault (no drivers are modelled).
- Criminal charges for a death on a neglected road (manslaughter by a firm; it could use PRISONS later).
- The state's liability for a dangerous junction (only links carry accidents today).
