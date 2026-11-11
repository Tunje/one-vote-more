# Staff v1: Closed Specification

**Owner:** a9 (staff & justice) · **Status:** v1 closed for M3 · **Date:** 2026-11-10
**Supersedes for v1:** staffAndSkills.md §4, §5, §7, §9, §16 and §28 numbers; project.md §12.6 (workload, per X3)
**Binding inputs:** MASTER-PLAN §2.2 X3/X4/X6, §3; pic-core.md; DECISIONS A1–A6 (sim core is **GDScript**, RefCounted, headless)
**Companion docs:** [spec-law-v1.md](spec-law-v1.md), [pic-staff-law.md](pic-staff-law.md)

> **Role in the game:** staff are the government's (and every party's) **political capacity**. Every bill, budget, coalition deal, campaign, poll, oversight inquiry and lever implementation consumes staffed work. Scarce competent people make up the strategic constraint (staffAndSkills §29).

All numbers below are v1 defaults. They live in `game/data/staff/*.json` so balancing doesn't need code changes. **W_ref** is the reference monetary unit: 1 W_ref = the colony's average monthly wage for the *Skilled* tier, published by econ (88). All money in this spec is expressed in W_ref.

---

## 1. Person model (X6)

One `Person` base shared by government officials, party staff, corporate leaders (comp) and judges (law, M6). Every role skill set uses a 0–100 scale.

```
Person {
  id, name, birth_month              // age = (month - birth_month) / 12
  party_id: PartyId | null           // null = nonpartisan
  roles: [GOV_POLITICAL | CIVIL_SERVANT | PARTY_STAFF | JUDGE | CORP_LEADER]
  skills: { skillId: 0..100 }        // the role's skill set (§1.1). Judges use GOV skills (Law)
  talents: TalentId[]                // 0..2
  work_speed: 0..100
  reliability: 0..100
  integrity: 0..100                  // used post-v1 for corruption; generated now so saves are stable
  xp: { skillId: float }             // progress toward the next point
  status: ACTIVE | UNAVAILABLE(until_month) | RETIRED | DECEASED | DEPARTED
  bench_party_id: PartyId | null     // which party bench the person sits on (§5)
  assignment_id: AssignmentId | null // X3: at most one
  career: CareerEntry[]
}
```

### 1.1 Government / party skill set (10)
`ADMIN, ECON, ENG, LOGI, LAW, NEGO, POLI, COMM, ENV, PUBS` (staffAndSkills §4.2). Corporate leaders keep comp's set (comp §5.2), and 88 owns that.

**The player is not one of the 20.** The player is the commander (founding era) and then the party leader, and becomes head of government when governing. The 20 officials are the player's capacity, not avatars.

---

## 2. Work formula (closes S §9.2–9.4)

### 2.1 Individual monthly contribution
```
W_i = B_p × V(speed_i) × K(suit_i) × T_i × M_mode × A_i
```

| Symbol | Definition | v1 value |
|---|---|---|
| `B_p` | Base rate of the position | **Mandatory position 10 WU/month. Optional position 5 WU/month** |
| `V(s)` | Speed multiplier, linear | `V = 0.6 + 0.008·s` → s=0: 0.60, 50: 1.00, 100: 1.40 |
| `suit_i` | Weighted skill for this position | `Σ w_k·skill_k` with the position's `contribution_weights` (sum to 1) |
| `K(u)` | Suitability multiplier, linear, clamped | `K = clamp(0.4 + 0.012·u, 0.4, 1.6)` → u=50: 1.00, u=75: 1.30, u=100: 1.60 |
| `T_i` | Product of the person's applicable talent multipliers (§4) | Capped at **1.5** |
| `M_mode` | Task mode (§2.4) | Rush 1.25 · Normal 1.00 · Careful 0.85 |
| `A_i` | Coalition alignment (§7.3) | 1.10 agreement item · 1.00 neutral · 0.80 conflicts with a negotiable position · refused (0) for a core commitment |

**Typical values:** political official (speed ≈67, suit ≈60) gives W ≈ 10·1.14·1.12 ≈ **12.8**. Civil servant (speed ≈42, suit ≈72) gives W ≈ 10·0.94·1.26 ≈ **11.8**. Total government capacity ≈ **240 WU/month**.

### 2.2 Team aggregation by execution mode
Let `M` = mandatory members and `O` = optional members (at most 2 optional positions per task in v1).

| Mode | Monthly team work `W_team` | Used for |
|---|---|---|
| **PARALLEL** | `Σ_{M} W_i + Σ_{O} W_i` | Standing duties, supervision, campaign effort |
| **COORDINATED** | `n·(0.5·mean_M + 0.5·min_M)·C + Σ_{O} W_i`, where n = \|M\| and `C = 1 − 0.05·max(0, n−2) + 0.10·[team has Strong Organizer]` | Drafting, budget, negotiation, oversight |
| **SEQUENTIAL** | The task has stages. Each stage lists its owning positions. Owners count 1.0, other assigned members count 0.5, toward the *current* stage only. Leftover WU after a stage completes carries into the next stage. A stage can also be **time-gated** (fixed months, no WU), e.g. a tender period. | Procurement, implementation of complex programs |

**Pause rule:** if any *mandatory* position of the current stage (or of the whole task, for non-sequential modes) is vacant, `W_team = 0` for that month (S §12.3). Optional vacancies only remove that member's term.

### 2.3 Finite vs coverage tasks
- **Finite tasks** have `work_required` WU. Progress = Σ W_team. The task completes when progress ≥ work_required (S §9.7).
- **Coverage tasks** (standing duties, supervision, campaign) have `monthly_required` WU. Each month:
  - `coverage c = min(1, W_team / monthly_required)`
  - `effectiveness e = c × (0.5 + Q/200)`, so e ∈ [0, 1]
  - Consumers read `e`. The default consumer mapping is `multiplier = 0.85 + 0.25·e`, giving 0.85 when unmanaged and 1.10 at best.

### 2.4 Task mode
The player sets the mode per task instance (ADMIN-level decision, free to change during planning). Rush gives W ×1.25 and q −15. Careful gives W ×0.85 and q +10.

---

## 3. Quality (closes S §9.5)

Per member per month:
```
q_i = clamp(0.7·suit_i + 0.3·reliability_i + talentQ_i + modeQ, 0, 100)
```
**Task quality `Q`** = WU-weighted mean of `q_i` over every month of contribution, plus 3 if the team had a Strong Organizer that month. Coverage tasks use a rolling 6-month WU-weighted mean.

| Band | Q | Label |
|---|---|---|
| Poor | < 40 | Visible failures likely |
| Adequate | 40–69 | |
| Good | 70–84 | |
| Excellent | ≥ 85 | |

**Where Q goes. Every use is politically visible:**

| Task family | Q effect |
|---|---|
| Draft legislation | Per-clause **defect probability** `p = max(0, (70 − Q)/150)` (Q 40 → 20%). A defect adds 25% to implementation WU and makes the clause *legally vulnerable* (rule `defect = true` → `DISPUTED`, spec-law §5; appealable from M6, spec-law §11). It is discovered with p=0.5 at implementation start, which emits `STAFF_DRAFTING_DEFECT_REVEALED`. Q is also published to politics as `draft_quality`. **D1 uses it as "confidence in implementation"** (project §11.5). |
| Coalition / support negotiation | Publishes `negotiation_quality` (0–100) to the D1 bargaining function. Suggested D1 use: concession acceptance utility + (Q − 50)/10. |
| Campaign | `campaign_effort = W_team·(0.5 + Q/200)` per month → D1 |
| Poll | Margin of error (95%) = `2.0 + 3.0·(1 − Q/100)` pp. Bias is 0 in v1. |
| Oversight | Probability of finding each SECRET fact in scope = `0.3 + 0.5·Q/100` |
| Procurement | Probability of choosing a sub-optimal bid = `(100 − Q)/250`. The bid is chosen by 88's scoring, with noise added to scores of σ = (100 − Q)/10 % |
| Supervision | Monthly probability of detecting a contractor problem = `0.2 + 0.7·c·Q/100` |
| Permit administration | Wrong grant/deny probability per decision = `(100 − Q)/400` (spec-law §10.3) |
| Delegated auto-decisions | Error probability per auto decision = `(100 − Q)/300` (§9) |

**Reliability errors:** each assigned member each month has an error probability `(100 − reliability)/1000`. On an error, that member's W_i = 0 for the month and the task gets an `ATTENTION` report. If a Detail-Oriented teammate is present, the error is caught 50% of the time (no loss). Random draws use the RNG stream `staff.work`.

---

## 4. Talents (closes S §5.3, §5.5, §28)

All 16 talents are active in v1. Their effects are multipliers (T) or additive quality (Q+) applied **only** to tasks with a matching tag. Identical talents never stack. A team-wide talent counts once per team. The per-person T cap is 1.5.

| Talent | Effect | Scope / tag |
|---|---|---|
| Fast Learner | XP ×1.5 | self |
| Detail-Oriented | Own reliability errors ×0.5; catches teammates' errors 50%; Q+5 | self + team |
| Skilled Mediator | T 1.25, Q+10 | `NEGOTIATION` |
| Crisis Manager | T 1.25 | `CRISIS` (event-spawned tasks) |
| Industrial Expert | T 1.20 | `INDUSTRY` |
| Strong Organizer | Coordination C +0.10; Q+3 | team (once) |
| Cautious Planner | T 0.90, Q+10 | all |
| Persuasive Speaker | T 1.20, Q+10 | `CAMPAIGN`, `COMMS` |
| Procurement Specialist | T 1.20, Q+10; also an alternative qualification | `PROCUREMENT` |
| Financial Analyst | T 1.20, Q+10 | `BUDGET`, `FISCAL` |
| Legal Specialist | T 1.20, Q+10; also an alternative qualification | `DRAFTING`, `LEGAL` |
| Field Supervisor | T 1.20; supervision detection +0.10 | `SUPERVISION` |
| Adaptable | K floor 0.85 (instead of 0.4) | self |
| Institutional Memory | T 1.15, Q+5 | `STANDING`. Generated for civil servants only |
| Problem Solver | Blocked-by-resource tasks unblock 1 month sooner; delay events ×0.5 | self task |
| Resourceful | Task credit costs −10% | self task |

Talent count at generation: 0 talents 30%, 1 talent 50%, 2 talents 20%.

---

## 5. Roster generation and the source of new officials (closes review gaps #12, #13)

### 5.1 Distributions
All draws use the RNG stream `staff.gen` and are uniform unless noted.

| Attribute | Civil servant | Political / party staff |
|---|---|---|
| Age at start | 30–58 | 28–62 |
| Primary skill | **68–85** | **58–78** |
| Secondary skills (2) | 45–65 | 40–60 (1–2 of them) |
| Other skills | 15–45 | 10–40 |
| Work speed | 30–55 | 55–80 |
| Reliability | 60–90 | 45–80 |
| Integrity | 50–95 | 30–90 |

### 5.2 Templates (guarantee by construction)
**10 civil servants**, one per specialization (S §3.2), each with a fixed primary and secondaries:

| Specialization | Primary | Secondaries | Forced talent |
|---|---|---|---|
| Finance | ECON | ADMIN, LAW | — |
| Engineering | ENG | LOGI, ADMIN | — |
| Logistics | LOGI | ADMIN, ENG | — |
| Procurement | ADMIN | ECON, LAW | Procurement Specialist |
| Law | LAW | ADMIN, POLI | — |
| Public Administration | ADMIN | PUBS, COMM | — |
| Infrastructure | ENG | ENV, ADMIN | — |
| Healthcare | PUBS | ADMIN, ECON | — |
| Environment | ENV | ENG, LAW | — |
| Economic Development | ECON | NEGO, ENG | — |

**Political archetypes** (10 founding appointees; also the mix used to generate every party bench):

| Archetype | Count / 10 | Primary | Secondaries |
|---|---|---|---|
| Strategist | 2 | POLI | COMM, NEGO |
| Negotiator | 2 | NEGO | POLI, ECON |
| Communicator | 2 | COMM | POLI |
| Jurist | 1 | LAW | POLI, ADMIN |
| Economist | 1 | ECON | POLI |
| Manager | 1 | ADMIN | ENG or PUBS |
| Sector expert | 1 | ENG, PUBS or ENV (party-weighted) | POLI |

**Party flavour:** a party's ideology (D1) re-weights the sector-expert draw and adds +5 to the primary skill matching its top-salience concern (e.g. a green party gives ENV +5).

### 5.3 Staffability guarantee
**v1 catalogue rule:** no mandatory position threshold exceeds **60** (§10). Civil primaries are ≥68 and political primaries ≥58, so every position is fillable by construction.

After generation, `RosterValidator` runs a bipartite matching of the roster against the **founding starting slate** (§10.4, 9 mandatory positions):
1. If the matching fails, re-draw that person's skills on a sub-stream (at most 50 attempts; this stays deterministic).
2. If it still fails, raise the closest candidate's skill to the threshold. A matching failure is logged as a test failure.

The same validator runs on every party bench, requiring ≥1 LAW ≥50, ≥1 NEGO ≥50 and ≥1 COMM ≥50. This guarantees that any party can draft, negotiate and campaign.

### 5.4 Where people come from, and who picks (closes review Q3)

| Pool | Source | Who picks | When |
|---|---|---|---|
| **Founding appointees (X4)** | 16 political candidates are generated at game start | **Player (commander)** picks 10, or accepts the recommended 10 | Month 1 |
| **Party benches** | Every party has a bench of `6 + ceil(seats/10)` people (new parties: 6). At each election, each party gets +3 newly generated people. Over cap, the lowest-value people (by suitability and age) leave. | — | Election month |
| Player's party bench | The founding 10 join it at the first election (X4), plus 3 new | — | |
| **Government political seats** | Allocated to coalition parties (§7.1). **Each party fills its own seats from its own bench**: the player for the player's party, party AI for partners. Partner AI maximizes Σ suitability for its coalition-agreement priority tasks. | Party | Formation month, reshuffles |
| **Civil servants** | Permanent. Vacancies are filled from a **merit shortlist of 3** generated for a specialization that **the government chooses**. The person is nonpartisan by construction. Hiring takes 2 months. | Government (player or AI): must pick from the shortlist | Vacancy |
| **Opposition/party staff** | From the party's own bench (§8) | Party leader | Start of opposition, any planning phase |

- **Partner reshuffles:** a partner AI may reshuffle its own officials at most once per 12 months.
- **Player swap requests:** the player may request a swap of a partner's official (action `STAFF_REQUEST_PARTNER_RESHUFFLE`). It costs `partyTrust −3` with that partner, and the partner accepts with probability `trust/100`.
- **Dismissals:** the player can dismiss their *own party's* officials at any time. This emits `STAFF_OFFICIAL_DISMISSED` with magnitude 15. **Civil servants cannot be dismissed in v1.**

---

## 6. Staff lifecycle (closes review Q4)

| Event | Rule (monthly, RNG stream `staff.life`) |
|---|---|
| Illness / temporary unavailability | p = 0.003. Lasts 1–3 months. The assignment is kept but contributes 0, with an `ATTENTION` report. |
| Civil-servant voluntary departure | p = 0.001 (≈1.2%/yr) |
| Civil-servant retirement | Mandatory at age **67** (LAW-level lever `STAFF_CIVIL_RETIREMENT_AGE`, default 67, range 60–72) |
| Political/bench retirement | At age ≥ 60, p = 0.002/month. Mandatory at 72. |
| Death | p = 0.0005 under 60, 0.002 at 60+ |
| Coalition partner leaves government | Its officials depart immediately. Their positions go vacant and dependent work pauses. |
| Party loses all seats | Its bench shrinks to 3 |
| Skill growth (XP) | `XP/month = 10 × D × R × L`. D (difficulty) = 1.0 / 1.5 / 2.0 by task tier. R = the skill's weight in the position. L = 1.0, or 1.5 with Fast Learner. Cost to go from s to s+1: `5 + s²/200` XP (s=50: 17.5; s=80: 37; s=95: 50). Cap 100. |
| Training (`STAFF_T_TRAINING`) | 3 months. Cost 10 W_ref. +5 to one chosen skill (+8 with Fast Learner). Only allowed if the skill is < 85. Training occupies the person (S §16.4). |
| Age decline | None in v1 |

**30-year check:** mean civil-servant start age is 44, so retirement plus attrition gives about 7–9 replacements across a 30-year campaign. That is enough to make recruitment choices matter without churn.

---

## 7. Political integration

### 7.1 Seat allocation (closes review Q13)
- The 10 political positions are allocated by **Sainte-Laguë (divisors 1, 3, 5, …)** over coalition parties' seats. This is the same family as A5, but without the 1.2 first divisor, so that small partners still get seats. Example: 49/28/19 → 5/3/2.
- **Every formal coalition member gets at least 1 position.** The top-up is taken from the largest party's lowest winning quotient.
- **Support parties** (confidence-and-supply) get **0** positions. Their leverage is through D1 agreements.
- **Single-party government** gets all 10.

### 7.2 Founding era and transitions
- **Years 1–4:** all 10 political positions are commander appointees (X4). They are `GOV_POLITICAL` with `party_id = player's proto-party` once parties are registered in Year 3. Before that they have no party.
- **Election → formation (caretaker):** outgoing political officials stay in place. They may continue tasks that are already running and standing duties, but **no new `POLITICAL`-category tasks can start, except `STAFF_T_COALITION_NEGOTIATION`**, which every party runs with its party staff (§8).
- **Formation month:** departing parties' officials leave. Seats are re-allocated and each party appoints from its bench in the same planning phase. Assignments of departing officials close and progress is kept (S §19).
- **Civil servants** keep their assignments across governments. The new government may reassign them.

### 7.3 Coalition alignment (closes S §3.1.2 / review gap #20)
Every political task instance carries the **lever deltas** it advances (from the clause list for drafting and implementation tasks, and from the target for other tasks). For each partner official assigned:
- If a delta conflicts with a partner **core commitment** (D1 party model), the assignment is **refused**. It is rejected at validation with the reason shown.
- If a delta conflicts with a **negotiable position**, then A_i = 0.80, an `ATTENTION` report is filed, and the political core receives a `STAFF_PARTNER_FRICTION` fact (magnitude 10) each month.
- If the delta is a **coalition agreement item**, A_i = 1.10.

**Needs from Wilma (D1):** party `core_commitments` and `negotiable_positions` expressed as lever-direction pairs.

### 7.4 Neutrality of the civil service
Civil servants **cannot** hold positions in party-political tasks (tag `PARTY`): coalition negotiation, support negotiation, campaign, agenda, party polling, opposition oversight. They **can** work on government bills, the budget, regulations, implementation, supervision, procurement, standing duties and government information. This is enforced in qualification validation (S §7.5 step 2).

---

## 8. Opposition and party staff (closes review gap #22)

- **Opposition party staff pool size** = `2 + floor(seats/20)`, capped at 6. Examples: 20 seats → 3, 40 → 4, 60 → 5. Drawn from the party bench.
- Applies to **every** non-governing party, AI parties included.
- **Governing parties have no separate party pool.** Party work in government (campaign, agenda, party polling) must use that party's own political officials. **This is deliberate:** campaigning while governing costs governing capacity.
- **Extra party staff during formation:** during the formation phase, every party (governing or not) gets a temporary pool of `2 + floor(seats/20)`, capped at 6, from its bench for coalition negotiation.
- Opposition staff use the same engine, formulas, reports and catalogue (S §20.3).

---

## 9. Delegated authority (closes S §13.2 / review gap #19)

```
AuthorityProfile {
  preset: TIGHT | STANDARD | BROAD
  single_commitment_max_pct:    float   // of task authorized_budget
  cumulative_overrun_tolerance: float   // before escalation
  schedule_slip_tolerance_m:    int
  auto_admin_decisions:         bool    // issue routine admin decisions within the rules (permits under criteria)
  may_retender_failed_contract: bool
  may_accept_variation_pct:     float   // contractor change orders
}
```

| Field | TIGHT | **STANDARD (default)** | BROAD |
|---|---|---|---|
| Single commitment max (% of task budget) | 2% | 10% | 25% |
| Cumulative overrun tolerance | 0% | 5% | 10% |
| Schedule slip tolerance | 0 months | 2 months | 4 months |
| Auto admin decisions | no | yes | yes |
| Re-tender a failed contract | no | no | yes |
| Accept contractor variation | 0% | 0% | ≤10% |

- **Escalation triggers** (any one creates a `DECISION_REQUIRED` request; the affected work blocks until answered, S §13.6): commitment over the limit, cumulative overrun over tolerance, slip over tolerance, contractor insolvency, a required legal approval (rules engine returns `REQUIRES_APPROVAL`), coalition refusal, missing resources for ≥2 months, defect revealed.
- **Decision requests** carry 2–4 options plus a recommended option. Unanswered requests do not expire. AI governments answer them through D7 utility.
- **Auto decisions:** each one has an error probability `(100 − Q)/300` (§3). An error emits a fact with `responsible = GOVERNMENT 0.7 / OFFICIAL 0.3`.
- **Trade-off:** BROAD means fewer interruptions but more attributable mistakes. Changing the preset is an ADMIN-level action that costs no work.

---

## 10. v1 TaskDefinition catalogue

Notation: `SKILL≥n` is the minimum; `w:` gives the contribution weights. Alt = alternative qualification path. Tags drive talents and neutrality (`PARTY` = no civil servants).

### 10.1 Political tasks (first, per the M0 orders)

| Id | Name | Cat. / mode | Work | Mandatory positions | Optional | Tags | Output → politics |
|---|---|---|---|---|---|---|---|
| `STAFF_T_DRAFT_BILL` | Draft legislation | POLITICAL / COORD | `30 + 20·clauses` (a 3-clause bill = 90 WU ≈ 3 months with 2–3 people). **Bills with ≥4 clauses need a 2nd policy lead.** | Legal drafter: LAW≥50 (w: LAW .8, ADMIN .2); alt LAW≥35 + Legal Specialist. Policy lead: domain skill of the clauses ≥50 (w: domain .7, POLI .3) | Political coordinator: POLI≥40 | DRAFTING | Bill ready → `POL_PROPOSE_BILL` allowed. Outputs `draft_quality` and per-clause defects. |
| `STAFF_T_REVISE_BILL` | Revise bill in negotiation | POLITICAL / COORD | `10 + 10·changed clauses` | Legal drafter: LAW≥45 | Policy lead | DRAFTING | Revised bill |
| `STAFF_T_DRAFT_ORDINANCE` | Draft provisional ordinance (founding) or government regulation | POLITICAL / COORD | `15 + 10·clauses` | Legal drafter: LAW≥45 | Policy lead: domain≥45 | DRAFTING | Ordinance/regulation ready |
| `STAFF_T_BUDGET` | Prepare annual budget | POLITICAL / COORD | 80 (**deadline:** budget month; if missed, last year's budget rolls over and `STAFF_BUDGET_LATE` is emitted, magnitude 40) | Budget lead: ECON≥55 (w: ECON .7, ADMIN .3). Budget officer: ADMIN≥45 | POLI≥40 | BUDGET | Budget bill |
| `STAFF_T_COALITION_NEGOTIATION` | Negotiate coalition / agreement | POLITICAL / COORD | `30 per partner party` | Negotiator: NEGO≥50 (w: NEGO .7, POLI .3). Political lead: POLI≥50 | Policy adviser: ECON≥45 or LAW≥45 | PARTY, NEGOTIATION | `negotiation_quality` → D1 formation |
| `STAFF_T_SUPPORT_NEGOTIATION` | Secure parliamentary support for a bill | POLITICAL / COORD | `15 + 5·target parties` | Negotiator: NEGO≥45 | POLI≥40 | PARTY, NEGOTIATION | `negotiation_quality` → D1 vote bargaining |
| `STAFF_T_AGENDA` | Develop electoral agenda | POLITICAL / COORD | 40 | Strategist: POLI≥50 | Communicator: COMM≥40 | PARTY | Registers the manifesto (D1). **Required to campaign.** |
| `STAFF_T_CAMPAIGN` | Campaign | POLITICAL / PARALLEL, coverage | `monthly_required` 30. Runs from the formal election period start (D1) to the election. | Campaign lead: COMM≥50 (w: COMM .7, POLI .3) | Strategist: POLI≥45. Organiser: ADMIN≥40 | PARTY, CAMPAIGN | `campaign_effort` per month → D1 |
| `STAFF_T_POLL` | Commission poll | POLITICAL / COORD | 10. Cost 20 W_ref. | Analyst: COMM≥35 or ECON≥45 | — | PARTY | Poll result with MoE (§3) |
| `STAFF_T_OVERSIGHT` | Parliamentary oversight inquiry | POLITICAL / COORD | 30 | Investigator: LAW≥45 or ADMIN≥55 | Communicator: COMM≥40 | PARTY, LEGAL | Reveals SECRET facts in the chosen domain with p from §3 → `*_REVEALED` facts. Sees OFFICIAL indicators of the domain for 6 months. |
| `STAFF_T_LEGAL_CHALLENGE` | File legal challenge (M6) | POLITICAL / COORD | 20 | Counsel: LAW≥45 | — | PARTY, LEGAL | Files an administrative appeal against a *revealed* unlawful government action or a disputed rule (spec-law §11) |
| `STAFF_T_GOV_COMMS` | Government information campaign | POLITICAL / PARALLEL | 15 | Communicator: COMM≥45 | — | COMMS | Raises D1 attribution weight of one chosen PUBLIC fact by `+0.2·(Q/100)` for 3 months |

### 10.2 Implementation tasks (one per lever class; every lever references one, per pic-core §5)
Created automatically when a lever change passes the legal check. **One task instance is created per enacting instrument per class**, with work summed across its clauses. All have mode COORDINATED, tag IMPLEMENTATION and are open to civil servants.

| Id | Lever class | Work | Mandatory | Optional |
|---|---|---|---|---|
| `STAFF_T_IMPL_FISCAL` | Tax rates, fees, royalties, budget lines | `10 + 5·levers` | ECON≥45 or ADMIN≥50 | — |
| `STAFF_T_IMPL_REGULATORY` | Standards, licence regimes, prohibitions, minimum wage | `30 + 15·levers` | Implementation lead: ADMIN≥50. Domain specialist: domain≥45 | LAW≥45 |
| `STAFF_T_IMPL_PROGRAM` | New public programs, subsidies, service expansion | `50 + 20·levers`, mode SEQUENTIAL: design (40%) → set up (60%) | Program lead: ADMIN≥50. Domain specialist: domain≥50 | ECON≥45 |
| `STAFF_T_IMPL_INSTITUTION` | Establish/restructure an institution (permit office reforms; courts and regulators in M6) | 80, mode SEQUENTIAL | ADMIN≥55, LAW≥45 | ECON≥45 |
| `STAFF_T_IMPL_ADMIN` | ADMIN-level changes (zoning designation, permit criteria within regulation) | 5 | ADMIN≥40 | — |

A **defective clause** (§3) adds 25% to its share of the work.

### 10.3 Project, procurement and standing duties

| Id | Name | Mode | Work | Mandatory | Optional | Tags |
|---|---|---|---|---|---|---|
| `STAFF_T_PROCURE` | Run procurement | SEQUENTIAL | Specification 20 WU → tender **1 month time-gated** → evaluation 20 WU → award | Procurement lead: ADMIN≥50; alt ADMIN≥40 + Procurement Specialist; alt ECON≥60. Technical adviser: ENG≥50 *(construction only)* | Legal adviser: LAW≥40 | PROCUREMENT |
| `STAFF_T_SUPERVISE` | Supervise project | PARALLEL coverage | `monthly_required`: small 6, medium 12, large 24 (size class from 88's project) | Site supervisor: ENG≥55 (w: ENG .7, ADMIN .3); alt ENG≥45 + Field Supervisor | LOGI≥45; ADMIN≥40 | SUPERVISION, INDUSTRY* |
| `STAFF_T_REPORT` | Analytical report (economy/sector) | COORD | 20 | ECON≥50 | — | FISCAL |
| `STAFF_T_TRAINING` | Training | — | 3 months fixed | (self) | — | — |
| `STAFF_SD_FINANCE` | Public-finance oversight | PARALLEL coverage | 12/month | ECON≥50; alt ADMIN≥55 | — | STANDING, BUDGET |
| `STAFF_SD_INFRA` | Infrastructure maintenance oversight | PARALLEL coverage | 12/month | ENG≥45 | LOGI≥40 | STANDING |
| `STAFF_SD_PROCUREMENT` | Routine procurement | PARALLEL coverage | 10/month | ADMIN≥45 | — | STANDING, PROCUREMENT |
| `STAFF_SD_SERVICES` | Public-services administration | PARALLEL coverage | 12/month | PUBS≥50 | — | STANDING |
| `STAFF_SD_PERMITS` | Permit & licence administration | PARALLEL coverage | 10/month | ADMIN≥45; alt LAW≥45 | — | STANDING, LEGAL |
| `STAFF_SD_LEGAL` | Government legal compliance | PARALLEL coverage | 8/month | LAW≥50 | — | STANDING, LEGAL |
| `STAFF_SD_PARLIAMENT` | Parliamentary liaison (whip) | PARALLEL coverage | 8/month | POLI≥50 | — | STANDING, PARTY |

**Consumers of standing-duty effectiveness `e`:**
- `SD_FINANCE`: overspend escalation timeliness. Also econ's tax collection efficiency, if 88 adopts it.
- `SD_INFRA`: econ's maintenance multiplier.
- `SD_SERVICES`: econ service quality ×(0.85 + 0.25e).
- `SD_PERMITS`: permit throughput (spec-law §10.3).
- `SD_LEGAL`: legal-risk visibility in the validation UI, plus 50% lower probability of an unlawful *auto* decision.
- `SD_PARLIAMENT`: D1 party-discipline bonus for government parties of `+5·e` on vote-utility thresholds.

An **unmanaged** duty (no one assigned) gives e = 0 and emits `STAFF_DUTY_UNMANAGED` (magnitude 10) once per vacancy start.

### 10.4 Founding starting slate (validator target, §5.3)
Month 1, concurrently:
- `SD_FINANCE`
- `SD_INFRA`
- `SD_PERMITS`
- `PROCURE` ×1 (construction)
- `SUPERVISE` ×2 (medium)
- `DRAFT_ORDINANCE` ×1 (2 clauses)

That is 9 mandatory positions out of 20 people. The remaining ≥11 people give the player real choices from day one.

---

## 11. Monthly processing (fits pic-core §7)

| Tick phase | Staff work |
|---|---|
| `DECISIONS` (1) | Validate queued assign/unassign/replace (atomic, S §23). Create implementation task instances for lever changes that passed the legal check. Apply mode and preset changes. |
| `STAFF` (2) | Lifecycle rolls. Compute W_i, W_team, progress, Q, coverage e. Reliability errors. Complete tasks → release staff. **Implementation complete → schedule lever effect at `month + lever.lag`**, emitting `STAFF_IMPLEMENTATION_COMPLETE`. Escalations. XP. |
| `POLITICS` (9) | Politics reads draft_quality, negotiation_quality, campaign_effort, poll results and staff indicators |
| `RECORD` (11) | Build StaffReports (one per active official, S §14) plus consolidated task reports. Compress routine reports older than 12 months into monthly counts (S §14.7). |

Briefing priority (feeds the shared scheme): `DECISION_REQUIRED` 90 · task completed 60 · `ATTENTION` 50 · routine 10 · available 5. Routine and available reports are collapsed by default.

---

## 12. AI staffing (D7 hook)
Greedy, deterministic. Each month, in priority order (D7 provides priorities), for each vacant mandatory position, pick the available eligible person who maximizes `W_i × (0.5 + q_i/200)`. Ties break by Person id. Optional positions are filled only if ≥3 people stay free. Reassignments happen only on change events (completion, vacancy, new priority), not every month.

---

## 13. GDScript sketch (shape only)

```gdscript
# game/sim/staff/work_model.gd
class_name WorkModel extends RefCounted

const B_MANDATORY := 10.0
const B_OPTIONAL := 5.0
const T_CAP := 1.5

static func speed_mult(speed: float) -> float:
    return 0.6 + 0.008 * speed

static func suit_mult(suit: float, adaptable: bool) -> float:
    var k := clampf(0.4 + 0.012 * suit, 0.4, 1.6)
    return maxf(k, 0.85) if adaptable else k

static func coordinated(mandatory_w: Array[float], optional_w: Array[float], strong_org: bool) -> float:
    if mandatory_w.is_empty():
        return 0.0
    var n := mandatory_w.size()
    var mean := 0.0
    for w in mandatory_w:
        mean += w
    mean /= n
    var c := 1.0 - 0.05 * maxi(0, n - 2) + (0.10 if strong_org else 0.0)
    var total := n * (0.5 * mean + 0.5 * mandatory_w.min()) * c
    for w in optional_w:
        total += w
    return total
```
Fixed-point: if the kernel (M1) uses integer milli-units, then WU, Q and e are stored ×1000. The formulas are unchanged.

---

## 14. Acceptance tests added for v1 (beyond S §25 A–Q)

| # | Test | Pass |
|---|---|---|
| ST1 | 1,000 seeded rosters | Validator matches the founding slate in 100%, with ≤1% needing fallback |
| ST2 | 3-clause bill, typical 2-person team + 1 optional | Completes in 3 months ±1 |
| ST3 | Partner official on a task conflicting with a core commitment | Assignment refused at validation |
| ST4 | Coalition 49/28/19 | Seats 5/3/2. A 3-seat partner still gets 1 |
| ST5 | Government campaigning in an election year | Governing capacity drops by exactly the campaign team's W |
| ST6 | Rush vs Careful drafting | Rush finishes ~25% faster with a higher defect rate (seeded, statistically) |
| ST7 | Unmanaged SD_SERVICES for 6 months | Service multiplier = 0.85, and `STAFF_DUTY_UNMANAGED` emitted once |
| ST8 | 30-year soak | No invariant violations. Civil service always 10 (vacancies ≤ 2 months each) |

---

## 15. Kernel alignment (game/README.md rules, M1 API)

- **State:**
  - All staff state lives in `WorldState` tables: `person`, `task_instance`, `assignment`, `staff_report`, `decision_request`, `bench`.
  - Definitions (`task_definition`, `talent`) are data in `game/data/staff/*.json`.
  - `StaffProvider extends PicProvider` is stateless and runs in `DECISIONS`, `STAFF` and `RECORD`.
- **Integers only:** skills, speed, reliability and integrity are ints 0–100. WU, progress, Q and e are stored as **milli-units** (×1000) and rounded after each formula. XP is stored ×1000.
- **RNG streams:**

  | Stream | Used for |
  |---|---|
  | `staff.gen` | Roster and bench generation |
  | `staff.work` | Reliability errors, auto-decision errors |
  | `staff.life` | Lifecycle |
  | `staff.quality` | Defect, detection, oversight and poll draws |

- **Ids:** `world.new_id("person")`, `world.new_id("task")`, `world.new_id("asg")`.
- **Levers:** staff never writes lever values. On implementation completion it emits `STAFF_IMPLEMENTATION_COMPLETE`. The law provider (lever pipeline owner) schedules `operative := legal` at `month + lag` (spec-law §6.2).
- **Facts:** `world.add_fact()` only. Oversight reveals go through `world.facts.reveal(month, id, [revealer])`.
- **Tests per README rule 10:** ST1–ST8, plus a determinism test and a save/load round-trip mid-task.
