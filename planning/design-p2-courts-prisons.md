# Design note P2 — criminal courts and prisons (Anni, 2026-11-13; plan-public-safety.md P2, A60)

Status: DESIGN, for Wilma's review. P1 (crime, police, misconduct, political control) is committed.

The basics are the same as P1:

- Everything is opt-in (`meta["on"]` "PRISONS"); `meta["off"]` wins.
- State is integer, and the RNG streams are `law.criminal` and `law.prison`.
- Owner files: `sim/law/criminal.gd` (new), `sim/law/prison.gd` (new), levers in `law_data.gd`, readers in
  `law_query.gd`.

## 0. Scale first

At Swedish rates (about 70 prisoners per 100k) a colony of 3,000 holds about 2 prisoners, and one of 10,000 about 7.
At US rates (about 500 per 100k) the same colonies hold about 15 and 50.

So for the first decades the prison question is whether the colony builds a prison at all, and how bad the police
cells are, not how a big prison system runs. The design keeps that:

- **Early on, holding cells.** Before a prison exists, prisoners sit in the police station cells: 4 places per
  station, nothing to do, rising stress, and an "inmates kept in police cells for months" scandal.
- **A prison is a choice.** It is a public project (Bob's construction pipeline) that the government starts when the
  cells overflow, or never. It has staff, a budget and a regime.

## 1. Criminal procedure (aggregate)

Solved offences from the crime model (`crime.gd`, `m[kind][2]` per district and month) become **charges**. Ordinary
crime stays aggregate: there are no individual offenders and no rows in the `case` table, because that would swamp
the courts' table.

- **Charging.** A share of solved cases is prosecuted: THEFT 70%, VIOLENCE 90%, FRAUD 80%. The rest end in a caution.
- **The criminal docket.** Charged cases join a per-kind queue in `law_state.s.criminal.docket`. Each case costs court
  points: THEFT 0.2, VIOLENCE 1.0, FRAUD 1.5. These are taken from the same court capacity the civil cases use
  (`JusticeOps.capacity`), criminal cases first.
  - A congested court builds a backlog, which gives the "justice delayed" fact and, past a limit, releases on time
    limits.
  - Expected size: about 2 cases a month at 3,000 residents, so about 1 court point of the courts' roughly 30.
    Courts only feel crime in a crime wave or after cuts to LAW_COURT_BUDGET.
- **Verdicts.** Conviction rate by kind is 85 / 75 / 65%, scaled by evidence quality (police workload: a stressed
  station's cases are weaker).
- **Sentences.** These follow the new **LAW_SENTENCING** lever (0..100, default 40, about Swedish).
  - Each conviction becomes a fine, community service or prison, with prison length drawn per kind:

    | kind | prison share at 40 → at 100 | months (mean) at 40 → at 100 |
    |---|---|---|
    | THEFT | 10% → 35% | 3 → 9 |
    | VIOLENCE | 50% → 85% | 14 → 36 |
    | FRAUD | 25% → 60% | 8 → 24 |

  - Repeat offenders (§3) serve double, which extends the ×2 fine rule to sentences.
- **Pretrial detention.** Charged VIOLENCE cases are held while they wait, at a share scaled by LAW_POLICE_POWERS.
  They count against prison places. This is where a slow court fills the cells.

**Facts** (state carries the monthly totals; only notable events become facts):

- LAW_COURT_BACKLOG (PUBLIC, district-free): the docket is above 3 months of capacity for 3 months.
  responsible: GOVERNMENT.
- LAW_RELEASED_ON_TIME_LIMIT (PUBLIC): pretrial detainees freed because the court did not reach them.
  responsible: GOVERNMENT.

## 2. Prisons

**Places.** The places available are 4 cells per police station, plus prison places (Bob's PRISON facility).

**Occupancy** is pretrial detainees plus sentenced prisoners, kept as integer prisoner-months per kind and district
of origin.

**PRISON facility** (Bob, on the police pattern, opt-in "PRISONS"):

- Places come from the facility scale (a 20-place unit first).
- Staff: 1 officer per 2 places, plus support (10% Sp, 80% S, 10% G). Swedish ratios are close to 1 to 1 counting
  all staff; the colony runs leaner.
- Wages are paid from **LAW_PRISON_BUDGET** (‰ of the reference strength per prisoner place, as the police lever).
- Workload comes through Bob's workload contract (service tag PRISON): inmates ÷ (staff × 2).
- Building one: I publish `law_state.s.prison.places_needed` (the 12-month peak of occupancy × 1.2).
  - The AI government starts a prison project when the cells have been over 100% for 6 months.
  - The player can start one at any time.
  - Bob's construction pipeline builds it, at a cost Wilma's budget sees.

**Overcrowding** (occupancy ÷ places), checked monthly:

- Above 100%: stress for the staff (Bob's model) and a mounting chance of a **disturbance**.
- Above 130%: a chance of an **escape**: a number of prisoners return to their district at once.
- Holding cells always count as overcrowded once a prisoner has been held more than 3 months.

**Regime: LAW_PRISON_REGIME** (0 = punitive, 100 = rehabilitative, default 50):

- It sets the reoffending rate after release: 50% at 0, 35% at 50, 20% at 100.
- It also sets the cost per place (×0.8 at 0, ×1.4 at 100), and how the public reads escapes. A rehabilitative regime
  is called soft after an escape; a punitive one is called cruel after a riot.

**Facts:**

- **LAW_PRISON_DISTURBANCE** (PUBLIC, SAFETY −3): responsible GOVERNMENT, with blame scaled by the budget shortfall.
- **LAW_PRISON_ESCAPE** (PUBLIC, SAFETY −5): data includes the number escaped, the district and whether a convicted
  public figure was among them.
- **LAW_HELD_IN_CELLS** (PUBLIC): prisoners held more than 3 months in police cells. It fires once a year while true.
- **LAW_PRISON_OPENED** and **LAW_PRISON_CLOSED**.

## 3. Reoffending (closing the loop with P1a)

- Released prisoners (served, escaped or freed on time limits) join a per-district pool of recent offenders. The
  pool decays over 24 months.
- The pool adds to that district's expected THEFT and VIOLENCE through a new driver multiplier (pool × reoffend rate ÷
  population). This is the "prisons that don't rehabilitate feed crime" link.
- Incapacitation: prisoners don't offend while inside. This is small at these scales, and the code removes it from
  the population that drives crime.

## 4. Named prisoners: convicted bosses and politicians

These are the user's "convicted CEOs and politicians can actually go to prison".

- **Who.** Two existing convictions gain a prison sentence when LAW_SENTENCING puts the class in the prison band:
  - LAW_MANAGER_CONVICTED (SEVERE company violations: the CEO);
  - LAW_LEADER_CONVICTED (party finance: the leader).
- **The new fact LAW_IMPRISONED** (PUBLIC, magnitude 60): data `{who (CEO|LEADER|PERSON), name, org|party, person,
  months, until, case}`.
- **Removal from post:**
  - A CEO is replaced (Bob: `ceo` regenerated, with a management-quality hit).
  - A leader must step down. This reuses the existing must_step_down path; Wilma's party_life already replaces them.
  - A staff person becomes UNAVAILABLE until release.
- **On release:** LAW_RELEASED_FROM_PRISON (PUBLIC, magnitude 30), for the comeback story.
- **Places:** a named prisoner uses a place like anyone else. A named prisoner who escapes is a large story.
- **The political-arrest link (P1c):** a detained opposition leader sits in the same cells. If the court later
  convicts them, which is unlikely without evidence, they move to a sentence. Otherwise they are released as today.

## 5. Levers

All NUMBER and legislative. Wilma reviews the ideology rows.

| lever | range, default | ideology | concern hints (A54 symmetric) |
|---|---|---|---|
| LAW_SENTENCING | 0..100, 40 | INSTITUTIONS −0.3 (order: harsher) | SAFETY +6 / FAIRNESS −4 |
| LAW_PRISON_BUDGET | 0..2000‰, 1000 | FISCAL +0.0015 | SAFETY +3 / GOVERNANCE −3 |
| LAW_PRISON_REGIME | 0..100, 50 | INSTITUTIONS +0.2, REDISTRIBUTION +0.1 | FAIRNESS +5 / SAFETY −2 |

## 6. Interfaces

**From Bob:**

1. PRISON facility and org (key "PRISON", PUBLIC_INSTITUTION), opt-in "PRISONS", on the police pattern:
   - staff target from my `law_state.s.prison.staff_target` (else his default from places);
   - wages booked to `spent_ytd["LAW_PRISON_BUDGET"]`;
   - no labour hoarding;
   - places in `f.places`;
   - `EconQuery.prisons(world) → [{id, district, places, staff, workload_pm, stress_pm}]`.
2. A prison project (construction) the government can order: `EconPolice`-style `order_prison(world, places)`, or
   whatever his construction pipeline wants.
3. CEO replacement on LAW_IMPRISONED with who = CEO.
4. Police cells: 4 places per station. I count them, so Bob needs nothing for this.

**From Wilma:**

1. The three lever rows and the SAFETY/FAIRNESS pulls.
2. The AI rule for ordering a prison: I suggest the trigger in §2, through Bob's order call.
3. LAW_IMPRISONED for a party leader → step down (the existing path) and public sympathy or outrage.

**From Terra:** prisons on the colony map from EconQuery.prisons, and the cell occupancy in the station panel.

**From Ella:** read only. LAW_PRISON_ESCAPE, LAW_PRISON_DISTURBANCE, LAW_HELD_IN_CELLS and LAW_IMPRISONED make campaign
and press material ("soft on crime" or "inhumane").

## 7. Build order and tests

1. **P2a criminal procedure and holding cells.** No new facility is needed: docket, verdicts, sentences, cells,
   occupancy, overcrowding facts, reoffending and named prisoners.
   - Tests: docket and backlog under a court cut; sentences by lever; cells overflow at a slump; reoffending raises
     theft; a convicted CEO is imprisoned and replaced; a leader is imprisoned and steps down.
2. **P2b prisons** (needs Bob 1 and 2): places, staff, budget, regime cost, disturbances, escapes, the build trigger.
3. **P2c workload link:** prison stress via Bob's contract. Riots get likelier with staff stress.
4. A/B "PRISONS" on vs off, 3 seeds × 50 years, with chronicles.

## 8. Open questions for Wilma

1. Default LAW_SENTENCING 40 (Swedish) or harsher for a frontier colony?
2. Should an AI government ever choose not to build a prison and keep using cells? It is a real choice, and it is
   cheap.
3. Do imprisoned party leaders keep their seat (Swedish rules differ for MPs), or does the party replace them on the
   list?
