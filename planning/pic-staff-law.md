# PIC Slice: Staff & Law

**Owner:** a9 · **Schema:** [pic-core.md](pic-core.md) v1 (used exactly; field names as in §3–6) · **Date:** 2026-11-10
**Detail specs:** [spec-staff-v1.md](spec-staff-v1.md), [spec-law-v1.md](spec-law-v1.md)

**Coverage vs pic-core §9 (staff/law must deliver):**

| Requirement | Delivered by |
|---|---|
| GOVERNANCE | `STAFF_DELIVERY_INDEX`, `LAW_RULE_OF_LAW`, `LAW_PERMIT_WAIT`, `LAW_COURT_DURATION` + facts |
| FAIRNESS | `LAW_TRUST_IN_JUSTICE`, `LAW_RULE_OF_LAW`, `LAW_ENFORCEMENT_CONSISTENCY` |
| SAFETY | `LAW_WORKPLACE_SAFETY` (workplace). **Public safety / crime is post-v1** (no police in v1); politics should weight SAFETY on workplace only in v1. |
| Implementation tasks for every lever type | 5 `STAFF_T_IMPL_*` classes (§3 column `implementation`). No lever has `null`. |
| Legal level for every lever | §3 here; law also adds `legalLevel` / `foundingEra` / `implementation` for **econ's levers**. 88 fills those columns using spec-law §6.1. |
| Drafting / negotiation / campaign / oversight tasks | §4 actions + spec-staff §10.1 |
| Permit / licence levers | §3 `LAW_LICENCE_*`, `LAW_PERMIT_*`, `LAW_FEE_*` |

**Ticks:**
- law runs in `DECISIONS` (1) for validation and in `JUSTICE` (7) for indicators, discovery and M6 cases.
- staff runs in `DECISIONS` (1) for assignment ops, in `STAFF` (2) for work and implementation completions, and in `RECORD` (11) for reports.

---

## 1. Indicators

`history: true` for all. "M6" marks indicators that are constant (shown value) until M6 ships.

| id | owner | unit | range | granularity | polarity | concerns | normalize {good, bad} | phase | visibility | perceptionLag |
|---|---|---|---|---|---|---|---|---|---|---|
| `STAFF_DELIVERY_INDEX` | staff | % | 0–100 | COLONY | +1 | GOVERNANCE 0.35 | {90, 40} | STAFF | PUBLIC | 2 |
| `LAW_RULE_OF_LAW` | law | index 0–100 | 0–100 | COLONY | +1 | GOVERNANCE 0.1, FAIRNESS 0.1 *(tuned, was 0.25/0.2)* | {100, 40} | JUSTICE | PUBLIC | 0 |
| `LAW_TRUST_IN_JUSTICE` | law | index 0–100 | 0–100 | VOTER_CELL | +1 | FAIRNESS 0.15 *(raise to 0.4 at M6 courts)* | {90, 30} | JUSTICE | PUBLIC | 0 (already smoothed) |
| `LAW_PERMIT_WAIT` | law | months | 0–24 | DISTRICT | −1 | GOVERNANCE 0.1. **Published only for districts with applications in the last 6 months.** | {0.5, 6} | JUSTICE | PUBLIC | 1 |
| `LAW_WORKPLACE_SAFETY` | law | accidents / 1,000 workers / yr | 0–50 | DISTRICT | −1 | SAFETY 0.6. **Published only when the economy runs (ECON_W_REF present).** | {1, 10} | JUSTICE | PUBLIC | 1 |
| `LAW_ENFORCEMENT_CONSISTENCY` (**not published before M6**) | law | % | 0–100 | COLONY | +1 | FAIRNESS 0.2 | {85, 30} | JUSTICE | PUBLIC | 3 |
| `LAW_COURT_DURATION` (**not published before M6**) | law | months | 0–36 | COLONY | −1 | GOVERNANCE 0.05, FAIRNESS 0.1 | {3, 18} | JUSTICE | PUBLIC | 3 |

**Tuning note (2026-11-10, `game/tools/measure_law_indicators.gd`, 18 politics soak runs × 240 months):** satisfaction is a weighted *average* of normalized indicators, so a near-constant indicator dilutes a concern's responsiveness. With the original weights, GOVERNANCE std fell 5.85 → 4.41 and SAFETY 7.06 → 4.61. With the tuned weights and publish-only-when-meaningful rules: approval std 5.05 → 4.95, GOVERNANCE std 5.85 → 5.18, FAIRNESS 4.77 → 4.27, SAFETY unchanged. Reveals still hit voters directly through the fact `impact` field. **Suggestion for pic-core v2 (Wilma):** an `exceptionOnly` indicator flag (counted only while normalized < 100) would remove the remaining dilution.

### Formulas
- **`STAFF_DELIVERY_INDEX`** = share of lever changes (rolling 24 months, weighted by the change's `magnitude`) whose operative value took effect within **6 months** of their legal effective month. Changes still pending count as failures once past 6 months. With no changes yet: 70.
- **`LAW_RULE_OF_LAW`** = `clamp(100 − Σ_k 20·(mag_k/50)·0.5^(age_k/12), 0, 100)` over `LAW_UNLAWFUL_GOV_ACTION_REVEALED` and against-government `LAW_RULING` facts. 20 points per revealed magnitude-50 act, with a half-life of 12 months. **Also feeds A6 legitimacy** (Wilma: suggest a collapse trigger if < 20 for 6 months).
- **`LAW_TRUST_IN_JUSTICE`**, per cell:
  - target = `30 + a·timeliness + b·consistency + c·lawfulness`
    - timeliness = `clamp(1 − wait/12, 0, 1)` (pre-M6: permit wait; M6: mean of permit wait and court duration ÷ 24)
    - consistency = enforcement consistency / 100
    - lawfulness = rule of law / 100
  - weights (a, b, c) by occupation:
    - BUSINESS_OWNER (35, 15, 20)
    - INDUSTRY and MINING (15, 35, 20)
    - all others (25, 25, 20)
  - Update: `T ← T + 0.1·(target − T)`. Start: 55.
- **`LAW_WORKPLACE_SAFETY`** = accidents from `COMP_WORKPLACE_ACCIDENT` facts per district, as an annualized rate over the trailing 12 months. **Needs 88:** an accident fact plus a probability model that reads `LAW_SAFETY_STANDARD`. Proposed multipliers: BASIC 1.0, STANDARD 0.7, STRICT 0.45; ×1.5 for facilities operating in violation.
- **`LAW_ENFORCEMENT_CONSISTENCY`** = % of `LAW_VIOLATION_REVEALED` facts (rolling 24 months) that received a sanction (fine, order or suspension) within 12 months.

---

## 2. Facts

`responsible` shares sum to 1. `impact` is per affected cell. Magnitude drives salience and briefing priority.

| type | owner | default visibility | subjects | responsible | impact | affected | magnitude | causes / data |
|---|---|---|---|---|---|---|---|---|
| `STAFF_IMPLEMENTATION_COMPLETE` | staff | PUBLIC | GOVERNMENT, OFFICIAL[] | GOVERNMENT 1.0 | GOVERNANCE +5 | ALL | 10–40 (by lever significance) | cause: `POL_LEVER_CHANGED`. data: instrument, levers, months_taken |
| `STAFF_IMPLEMENTATION_OVERDUE` | staff | PUBLIC | GOVERNMENT | GOVERNMENT 1.0 | GOVERNANCE −10 | ALL | 20 | Emitted once, at 6 months past effective |
| `STAFF_DRAFTING_DEFECT_REVEALED` | staff | PUBLIC | GOVERNMENT, OFFICIAL | GOVERNMENT 0.7, OFFICIAL 0.3 | GOVERNANCE −10 | ALL | 15 | cause: drafting task. data: clause |
| `STAFF_BUDGET_LATE` | staff | PUBLIC | GOVERNMENT | GOVERNMENT 1.0 | GOVERNANCE −20 | ALL | 40 | Budget rolled over |
| `STAFF_AUTO_DECISION_ERROR` | staff | PUBLIC | OFFICIAL, task target | GOVERNMENT 0.7, OFFICIAL 0.3 | GOVERNANCE −5 | district of the target | 10–30 | data: decision, preset |
| `STAFF_DUTY_UNMANAGED` | staff | OFFICIAL | GOVERNMENT | GOVERNMENT 1.0 | — | — | 10 | data: duty id |
| `STAFF_OFFICIAL_APPOINTED` | staff | PUBLIC | OFFICIAL, PARTY | PARTY 1.0 | — | — | 5 | |
| `STAFF_OFFICIAL_DISMISSED` | staff | PUBLIC | OFFICIAL, PARTY | PARTY 1.0 | GOVERNANCE −3 | ALL | 15 | |
| `STAFF_OFFICIAL_DEPARTED` | staff | PUBLIC | OFFICIAL | NATURE 1.0 | — | — | 5 | retire / death / resign |
| `STAFF_CIVIL_SERVANT_HIRED` | staff | OFFICIAL | OFFICIAL, GOVERNMENT | GOVERNMENT 1.0 | — | — | 5 | data: specialization |
| `STAFF_PARTNER_FRICTION` | staff | OFFICIAL | PARTY (partner), OFFICIAL | PARTY 1.0 | — | — | 10/month | **→ D1 coalition cohesion** |
| `STAFF_PARTNER_REFUSAL` | staff | OFFICIAL | PARTY, OFFICIAL | PARTY 1.0 | — | — | 20 | **→ D1 coalition cohesion** |
| `STAFF_POLL_RESULT` | staff | OFFICIAL (party-private; PUBLIC if the party publishes) | PARTY | PARTY 1.0 | — | — | 5 | data: shares, MoE |
| `LAW_ORDINANCE_ISSUED` | law | PUBLIC | COMMANDER | COMMANDER 1.0 | per lever estimators | ALL | 10–40 | data: clauses, lever deltas → commander's ideology (pic-core §5) |
| `LAW_ORDINANCE_DEEMED` | law | PUBLIC | COMMANDER | COMMANDER 1.0 | — | — | 5 | Transition |
| `LAW_CONSTITUTION_ADOPTED` | law | PUBLIC | PARLIAMENT | NATURE 1.0 | FAIRNESS +5 | ALL | 60 | |
| `LAW_ACTION_BLOCKED` | law | OFFICIAL | actor | actor 1.0 | — | — | 5 | data: trace (rule ids) |
| `LAW_UNLAWFUL_GOV_ACTION` | law | **SECRET** | GOVERNMENT, OFFICIAL | GOVERNMENT 0.8, OFFICIAL 0.2 | GOVERNANCE −15, FAIRNESS −10 (when revealed) | ALL | 30 (MINOR) / 50 (SERIOUS) / 70 (SEVERE) | data: action, rules broken |
| `LAW_UNLAWFUL_GOV_ACTION_REVEALED` | law | PUBLIC | GOVERNMENT, revealer (PARTY / OFFICIAL / INSTITUTION) | GOVERNMENT 0.8, OFFICIAL 0.2 | GOVERNANCE −15, FAIRNESS −10 | ALL | = original | cause: original; data: channel (LEAK / OVERSIGHT / COMPLAINT / COURT) |
| `LAW_VIOLATION` | law | **SECRET** | COMPANY | COMPANY 1.0 | SAFETY / ENV per type | district | 10–60 | Emitted when an actor executes a non-authorized action (comp's misconduct AI decides *whether*, per X7) |
| `LAW_VIOLATION_REVEALED` | law | PUBLIC | COMPANY, detector | **COMPANY 1.0 if found by inspection; COMPANY 0.7 / GOVERNMENT 0.3 if found by accident or whistleblower** (weak oversight is blamed) | SAFETY −, FAIRNESS − | district | = original | cause: original |
| `LAW_PERMIT_WRONGLY_DENIED` | law | PUBLIC | COMPANY, AUTHORITY | AUTHORITY 0.5, GOVERNMENT 0.5 | GOVERNANCE −3 | district | 10 | |
| `LAW_PERMIT_WRONGLY_GRANTED` / `_REVEALED` | law | SECRET / PUBLIC | COMPANY, AUTHORITY | AUTHORITY 0.5, GOVERNMENT 0.5 | SAFETY −5 | district | 15 | |
| `LAW_LICENCE_SUSPENDED` (M6) | law | PUBLIC | COMPANY | COMPANY 1.0 | JOBS − (via econ) | district | 20 | |
| `LAW_FINE_IMPOSED` (M6) | law | PUBLIC | COMPANY | COMPANY 1.0 | FAIRNESS +3 | district | 10–40 | data: amount, class |
| `LAW_RULING` (M6) | law | PUBLIC | winner, loser | Loser 1.0. **Against government: GOVERNMENT 1.0** | FAIRNESS +3. **Against government: GOVERNANCE −10, FAIRNESS −5 (unlawful act) / +2 (other)** | ALL | 15 / 25 against gov / 40 unlawful act | data: case, type, outcome, winner, against_government, duration, remedy (PERMIT_GRANTED / OVERTURNED / COMPENSATION / FINE), overturned (the unlawful action), amount/fine. Emitted only for the final judgment (after any appeal). |
| `LAW_CASE_FILED` (M6) | law | PUBLIC | claimant, respondent | claimant 1.0 | — | ALL | 10 | data: case, type |
| `LAW_CASE_SETTLED` (M6) | law | PUBLIC | claimant, respondent | respondent 1.0 | — | ALL | 10 | Contract cases only |
| `LAW_OVERSIGHT_FAILURE` (M6) | law | PUBLIC | GOVERNMENT | GOVERNMENT 1.0 | SAFETY −3, GOVERNANCE −3 | ALL | 20 | A violation surfaced through an accident or whistleblower instead of an inspection. This is how weak oversight is blamed, since `reveal()` copies the original responsibility. cause: the `*_REVEALED` fact |
| `LAW_WARNING_ISSUED` (M6) | law | OFFICIAL | COMPANY | COMPANY 1.0 | — | — | 5 | First MINOR violation in 24 months |
| `LAW_PERMIT_DENIED` | law | OFFICIAL | COMPANY, AUTHORITY | AUTHORITY 1.0 | — | — | 5 | Correct denial (for comp AI) |
| `LAW_ENACTMENT_REJECTED` | law | PUBLIC | instrument actor | actor (GOVERNMENT for laws) 1.0 | — | — | 15 | data: enactment, lever, errors[] |

**Lever facts:** law emits **`LAW_LEVER_EFFECTIVE`** for law-owned levers. Each owner emits `<OWNER>_LEVER_EFFECTIVE` for its own levers, **triggered by staff's `STAFF_IMPLEMENTATION_COMPLETE` + lag**. Staff publishes the schedule and the owner applies it.

**M6 indicators as built:** `LAW_ENFORCEMENT_CONSISTENCY` (FAIRNESS 0.2) and `LAW_COURT_DURATION` (GOVERNANCE 0.3, FAIRNESS 0.3, `exceptionOnly`) are published only once there is data (revealed violations / decided cases). `LAW_RULE_OF_LAW` is `exceptionOnly` with GOVERNANCE 1.0, FAIRNESS 0.5, and also counts against-government rulings at half weight. Soak re-measure with exceptionOnly: approval std 5.02 (baseline 5.05), GOVERNANCE std 5.83 (5.85).

---

## 3. Policy levers

Staff and law-owned levers. Ideology slopes are per unit (or per ENUM step upward). `fiscal`: estimator ref (owner function, monthly budget delta).

| id | owner | type | range / values | default | legalLevel | foundingEra | ideology (slope) | fiscal | implementation | lag | scope |
|---|---|---|---|---|---|---|---|---|---|---|
| `LAW_SAFETY_STANDARD` | law | ENUM | BASIC < STANDARD < STRICT (charter ≥ BASIC) | BASIC | LAW | COMMANDER | LABOR +15, ECON_ROLE +5 per step | `est_safety_compliance` (≈0; costs fall on companies via comp) | `STAFF_T_IMPL_REGULATORY` | 2 | COLONY |
| `LAW_LICENCE_REGIME_EXTRACTION` | law | ENUM | NONE, REQUIRED | REQUIRED | LAW | COMMANDER | REQUIRED: ENVIRONMENT +10, ECON_ROLE +5 | `est_fee_revenue` | `STAFF_T_IMPL_REGULATORY` | 1 | COLONY |
| `LAW_LICENCE_REGIME_HAZARD` | law | ENUM | NONE, REQUIRED | REQUIRED | LAW | COMMANDER | REQUIRED: LABOR +10, ECON_ROLE +5 | `est_fee_revenue` | `STAFF_T_IMPL_REGULATORY` | 1 | COLONY |
| `LAW_PERMIT_STRICTNESS` | law | ENUM | LENIENT < STANDARD < STRICT | STANDARD | REGULATION | COMMANDER | ENVIRONMENT +10, ECON_ROLE +5 per step | 0 | `STAFF_T_IMPL_ADMIN` | 0 | DISTRICT |
| `LAW_EXTRACTION_ROYALTY` | law | NUMBER | 0–30 % | 8 | LAW | COMMANDER | per +1pp: REDISTRIBUTION +1, ECON_ROLE +2 | `est_royalty` (rate × extraction value, econ data) | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_FEE_BUILDING_PERMIT` | law | NUMBER | 0–5 % of value | 0.5 | REGULATION | COMMANDER | per +1pp: ECON_ROLE +2 | `est_fee_revenue` | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_FEE_EXTRACTION` | law | NUMBER | 0–50 W_ref | 5 | REGULATION | COMMANDER | per +10: ECON_ROLE +1 | `est_fee_revenue` | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_FEE_HAZARD` | law | NUMBER | 0–50 W_ref | 3 | REGULATION | COMMANDER | per +10: ECON_ROLE +1 | `est_fee_revenue` | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_DIRECT_AWARD_THRESHOLD` | law | NUMBER | 0–500 W_ref | 50 | REGULATION | COMMANDER | per −10 W_ref: INSTITUTIONS +2 | 0 | `STAFF_T_IMPL_REGULATORY` | 0 | COLONY |
| `LAW_PERMIT_OFFICE_BUDGET` | law | NUMBER | 0–50 W_ref/month | 6 | LAW (appropriation) | COMMANDER | 0 | −value | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_COURT_BUDGET` (M6) | law | NUMBER | 0–200 W_ref/month | 15 | LAW (appropriation) | LOCKED | per +10: INSTITUTIONS +2 | −value | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_JUDGES` (M6) | law | NUMBER | 1–30 | 5 | LAW | LOCKED | per +1: INSTITUTIONS +1 | `est_judge_cost` (3 W_ref each) | `STAFF_T_IMPL_INSTITUTION` | 6 | COLONY |
| `LAW_INSPECTORATE_BUDGET` (M6) | law | NUMBER | 0–200 W_ref/month | 8 | LAW (appropriation) | LOCKED | per +10: ECON_ROLE +3, LABOR +2 | −value | `STAFF_T_IMPL_FISCAL` | 1 | COLONY |
| `LAW_INSPECTORS` (M6) | law | NUMBER | 0–60 | 4 | REGULATION | LOCKED | per +5: ECON_ROLE +2, LABOR +2 | `est_inspector_cost` (2 W_ref each) | `STAFF_T_IMPL_INSTITUTION` | 3 | COLONY |
| `LAW_FINE_SCALE` (M6) | law | NUMBER | 0.25–4.0 | 1.0 | LAW | LOCKED | per +1.0: ECON_ROLE +5, LABOR +3 | `est_fine_revenue` | `STAFF_T_IMPL_REGULATORY` | 1 | COLONY |
| `STAFF_CIVIL_RETIREMENT_AGE` | staff | NUMBER | 60–72 (charter) | 67 | LAW | COMMANDER | 0 | ≈0 | `STAFF_T_IMPL_ADMIN` | 12 | COLONY |
| `STAFF_DEFAULT_AUTHORITY_PRESET` | staff | ENUM | TIGHT < STANDARD < BROAD | STANDARD | ADMIN | COMMANDER | per step: INSTITUTIONS −5 (stronger executive) | 0 | `STAFF_T_IMPL_ADMIN` | 0 | COLONY |

### Rules for **all** levers (incl. econ's), from spec-law §6.1
- `implementation` must be one of the five `STAFF_T_IMPL_*` classes:

  | Class | Use for |
  |---|---|
  | FISCAL | Rates, fees, budget lines |
  | REGULATORY | Standards, licence regimes, minimum wage |
  | PROGRAM | Subsidies, service programs |
  | INSTITUTION | Bodies |
  | ADMIN | Small administrative changes |

  **`null` is not allowed in v1.**
- Charter bounds apply (spec-law §7.1): any tax ≤ 50%, `ECON_MIN_WAGE` ≥ 0.4 W_ref.
- `foundingEra: LOCKED` is required for anything electoral or constitutional.

---

## 4. Actions

`legalAction` names spec-law §3 types. `INTERNAL` = internal staff management: always authorized, never validated (**schema request to Wilma:** add `INTERNAL` to `LegalActionType`). Actor keys follow pic-core: PLAYER_GOV, AI_GOV, PARTY, OPPOSITION, COMMANDER.

| id | owner | actors | cost | legalAction | preconditions | effects | aiHints |
|---|---|---|---|---|---|---|---|
| `STAFF_START_TASK` | staff | all | per task definition (credits for poll/training) | INTERNAL (political tasks); per definition otherwise | Definition allowed for the actor (PARTY-tagged tasks not for civil servants; DRAFT_ORDINANCE only COMMANDER/GOV) | Creates a TaskInstance | task priority, expected months |
| `STAFF_ASSIGN` / `STAFF_UNASSIGN` / `STAFF_REPLACE` | staff | all (own staff only) | — | INTERNAL | Validation (staff §7.4, S §7.5) | Assignment ops (atomic) | W_i, q_i, vacancy pause |
| `STAFF_CANCEL_TASK` | staff | all | Sunk work; contractual effects via econ | INTERNAL / `TERMINATE_CONTRACT` if a contract is attached | — | Task cancelled | |
| `STAFF_SET_TASK_MODE` | staff | all | — | INTERNAL | — | Rush / Normal / Careful | speed vs defect trade-off |
| `STAFF_SET_AUTHORITY_PRESET` | staff | PLAYER_GOV, AI_GOV, COMMANDER | — | SET_LEVER (ADMIN) | — | Per assignment, or the default lever | interrupt rate vs error rate |
| `STAFF_ANSWER_DECISION` | staff | PLAYER_GOV, AI_GOV, COMMANDER | per option | per option | Open decision request | Unblocks the task | option utilities |
| `STAFF_APPOINT_POLITICAL` | staff | PLAYER_GOV, AI_GOV, PARTY, COMMANDER | — | APPOINT_OFFICIAL | Vacant seat allocated to the actor's party; candidate on its bench | `STAFF_OFFICIAL_APPOINTED` | suitability for priority tasks |
| `STAFF_DISMISS_POLITICAL` | staff | PLAYER_GOV, AI_GOV, PARTY, COMMANDER | — | DISMISS_OFFICIAL | Own party's official only | `STAFF_OFFICIAL_DISMISSED` | |
| `STAFF_HIRE_CIVIL_SERVANT` | staff | PLAYER_GOV, AI_GOV, COMMANDER | 2-month vacancy | APPOINT_OFFICIAL | Civil vacancy; pick 1 of 3 shortlist; chooses specialization | `STAFF_CIVIL_SERVANT_HIRED` | gap in specializations |
| `STAFF_REQUEST_PARTNER_RESHUFFLE` | staff | PLAYER_GOV, AI_GOV | partyTrust −3 (with partner) | INTERNAL | Partner official | Partner accepts with p = trust/100 | |
| `STAFF_TRAIN` | staff | all | 10 W_ref; staffTask `STAFF_T_TRAINING` | INTERNAL | Skill < 85 | +5 skill after 3 months | long-term capacity |
| `STAFF_COMMISSION_POLL` | staff | PLAYER_GOV, AI_GOV, PARTY, OPPOSITION, COMMANDER (Year 3+) | 20 W_ref; staffTask `STAFF_T_POLL` | CAMPAIGN | — | `STAFF_POLL_RESULT` | information value |
| `STAFF_LAUNCH_OVERSIGHT` | staff | PARTY, OPPOSITION | staffTask `STAFF_T_OVERSIGHT` | INTERNAL | Party has seats | SECRET facts in the domain → `*_REVEALED` with p (staff §3); OFFICIAL indicators of the domain visible 6 months | expected secrets in domain |
| `STAFF_GOV_COMMS` | staff | PLAYER_GOV, AI_GOV | staffTask `STAFF_T_GOV_COMMS` | INTERNAL | PUBLIC fact targeted | Attribution weight + | |
| `LAW_ISSUE_ORDINANCE` | law | COMMANDER | staffTask `STAFF_T_DRAFT_ORDINANCE` | SET_LEVER (LAW, provisional) | `world.era = FOUNDING`; levers `foundingEra = COMMANDER` | Rules + LeverChanges → impl tasks; `LAW_ORDINANCE_ISSUED`; moves the commander's ideology | lever ideology + concern estimators |
| `LAW_ISSUE_REGULATION` | law | PLAYER_GOV, AI_GOV | staffTask `STAFF_T_DRAFT_ORDINANCE` | SET_LEVER (REGULATION) | Lever level ≤ REGULATION, or delegated within bounds | Rules + LeverChanges → impl tasks; `POL_LEVER_CHANGED` | same |
| `LAW_ADMIN_DECISION` | law | PLAYER_GOV, AI_GOV, COMMANDER | staffTask `STAFF_T_IMPL_ADMIN` | SET_LEVER (ADMIN) | Lever level = ADMIN | LeverChange | |
| *(bills)* `POL_PROPOSE_BILL` | **pol** | PLAYER_GOV, AI_GOV, PARTY, OPPOSITION | staffTask `STAFF_T_DRAFT_BILL` (+ `STAFF_T_SUPPORT_NEGOTIATION` optional) | SET_LEVER (LAW) | **A completed draft with clauses from spec-law §6.3** | On passage, law compiles clauses → rules + LeverChanges | **payload:** lever deltas, fiscal, draft_quality |
| `LAW_PROCEED_UNLAWFULLY` | law | PLAYER_GOV, AI_GOV, COMMANDER | — (paid later) | the blocked action's type | `validate` returned PROHIBITED for this actor | Action executes; `LAW_UNLAWFUL_GOV_ACTION` (SECRET) | expected reveal p × magnitude (large penalty) |
| `LAW_FILE_CHALLENGE` (M6) | law | PARTY, OPPOSITION, PLAYER_GOV, AI_GOV | staffTask `STAFF_T_LEGAL_CHALLENGE`; litigation 1 W_ref/cp | INTERNAL | Target is a *revealed* unlawful act or a DISPUTED rule | Case filed (spec-law §11) | P̂(win) |
| `LAW_SETTLE_CASE` (M6) | law | PLAYER_GOV, AI_GOV | settlement credits | SPEND | Gov is a party to an open case | Case closed; ledger transfer | P̂(lose) × claim |
| `LAW_HIRE_JUDGE` (M6) | law | PLAYER_GOV, AI_GOV | 3 W_ref/month; 6-month lag | APPOINT_OFFICIAL | `LAW_JUDGES` allows it; pick 1 of 3 merit shortlist | Judge Person created | backlog |

Companies' licence/permit applications are **comp AI decisions** (not political actions). They call `law.validate` and enter the permit queue (spec-law §10).

---

## 5. Dependencies on other slices

| Need | From | Why |
|---|---|---|
| `INTERNAL` in `LegalActionType`; `<OWNER>_LEVER_EFFECTIVE` naming confirmed | Wilma (pic-core) | §4, §2 |
| Party `core_commitments` / `negotiable_positions` as lever-direction pairs; consumers for `draft_quality`, `negotiation_quality`, `campaign_effort`, poll MoE | Wilma (D1) | spec-staff §3, §7.3 |
| Formal election-period start month; budget month; formation-phase length | Wilma (D1/D2) | Campaign, budget deadline, caretaker rules |
| **W_ref** = average monthly Skilled-tier wage, published monthly | 88 | All money in staff/law |
| Fill `legalLevel`, `foundingEra`, `implementation` (5 classes), `lag` on every econ lever | 88 | spec-law §6.1 |
| `COMP_WORKPLACE_ACCIDENT` fact + accident model reading `LAW_SAFETY_STANDARD` | 88 | `LAW_WORKPLACE_SAFETY` (SAFETY concern) |
| Comp AI calls `validate` before `BUILD_FACILITY`, `OPERATE_FACILITY`, `EXTRACT_RESOURCE`; misconduct AI chooses whether to proceed when not authorized | 88 | Violations, X7 |
| Project size class (small/medium/large) and contract facts (delay > 3 months, non-payment) | 88 | Supervision WU, M6 contract disputes |
| Treasury account `FINES_REVENUE`; liabilities owed to the government feed insolvency (X9) | 88 | Fines (M6) |
| Origin credit line (lender) for the commander's `BORROW` authorization | 88 | Charter |
