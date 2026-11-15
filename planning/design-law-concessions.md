# Design note: public procurement, concessions and the retainer (law side)

Anni, 2026-11-15. Job 2.1 from the law survey (planning/law-survey-economy-2026-11.md §2.3), for Bob's §3c
(planning/eight-rules.md). Design only. **Agreed with Bob 2026-11-15; flag E173** (Bob's §3c, built with R8 step 4). Code only behind E173.

## 0. Today

- Every public building job is **tendered**:
  - ranked by `EconConstruction.ranked_bids` (price weight ECON_PROCUREMENT_PRICE_WEIGHT, then reliability and time);
  - awarded by `FirmAI._auto_award` (top score), or by the player through ECON_AWARD_CONTRACT.
  - Choosing a lower-ranked bidder emits ECON_CONTRACT_AWARDED with `override: true` (magnitude 40).
- **LAW_DIRECT_AWARD_THRESHOLD** (0–500,000, default 50,000; REGULATION level) is defined but **never read**. The award
  calls no law check.
- **CWD** (public works) bids only as last resort.

## 1. Procurement law (makes the threshold real)

One law check for every public award: `ProcLaw.award_check(world, job, builder, method) → {lawful, reason, method}`.

| method | lawful when | notes |
|---|---|---|
| **TENDER** | always | the default |
| **DIRECT** (award without tender) | the job price is below LAW_DIRECT_AWARD_THRESHOLD × W_ref ÷ 1000; or an emergency is declared (existing emergency state); or the job falls under a valid concession of its class (§2) | small jobs go to whoever can start soonest; no ranking needed |
| **OVERRIDE** (tendered, but not the top score) | lawful, but public (as today) | the procurement rule asks for the best score; a minister may depart with reasons. Kept political, not illegal |

**An unlawful direct award** (above the threshold, no emergency, no concession) is an unlawful government act:

- it goes through `LawOps.proceed_unlawfully`, action DIRECT_AWARD, SECRET, class SERIOUS;
- burdened: the losing bidders `{COMPANY}`, who can complain;
- found by the usual channels (leaks, complaints, the press's GOV_ACT investigations, the audit);
- revealed → LAW_UNLAWFUL_GOV_ACTION_REVEALED, a court case, and the award can be quashed: the job is re-tendered and
  the builder keeps payment for work done.

**New rule** (CHARTER-free, LAW level, source PROCUREMENT_LAW): PROHIBIT DIRECT_AWARD for GOVERNMENT/AUTHORITY unless
`p.below_threshold`, or `p.emergency`, or `p.concession`. The lever becomes live with no change to its range.

## 2. Concessions

**What a concession is.** The right and duty to do all public work of one class (ROAD first; later WATER_MAIN,
PUBLIC_BUILDING) in the whole colony or a district set, for a fixed term, at an agreed price basis, without tendering
each job.

### 2.1 Granting

- **The concession itself must be tendered.** Builders bid:
  - a **price basis**: their margin over the cost estimate, applied to every job;
  - a **retainer rate**: the share of the reserved crew's wages paid in idle months;
  - the **reserved crew**: how many workers they hold ready for the class.
- **Scoring:** the usual weights (price basis for price, reliability, crew size for time), plus the retainer rate as
  part of price.
- **Term:** at most **LAW_CONCESSION_MAX_YEARS** (new lever, 1–10, default 5). No automatic renewal; a new tender at the
  end.
- **One concession per class and area at a time.** No overlap.
- **Fact:** ECON_CONCESSION_AWARDED (PUBLIC), with the basis, retainer, term and rank. As for contracts, choosing a
  lower-ranked bidder is an override (public, political).
- **Without a tender:** an unlawful act, as in §1 (action AWARD_CONCESSION_DIRECT, SERIOUS; the press and the courts
  can find it). This is where favouritism lives; Wilma's politics can use the override and the unlawful version.

### 2.2 While it runs

- Every public job of the class goes to the concessionaire as a lawful **DIRECT** award at the agreed basis
  (`award_check` with `p.concession = true`).
- The concessionaire may take private work. **Start duty (Bob's form):** its quoted book wait for a concession job (active
  plus public-queued work ÷ capacity; public work is queued ahead of private under E165Q2) must be ≤ 3 months, and a
  concession job's start may not slip past its quote. A breach counts toward the cause test (2 in 12 months).
- **The retainer:** in a month with no concession job running, the government pays the retainer rate × the reserved
  crew's wages, from the INFRASTRUCTURE budget line.
  - **Legal cap: LAW_RETAINER_CAP** (new lever, 0–60% of wages, default 40%). A bid above the cap is invalid.
  - The retainer is not paid in months the crew works on concession jobs, or works private jobs that would stop it
    starting a concession job within 3 months.
- **Price revision:** the job price is the basis × the cost estimate at the time of the order. The existing escalation
  clause (E76) applies from the order, as for any contract.

### 2.3 Ending

- **At the term's end:** the concession lapses. Open jobs finish under it. The next concession is tendered.
- **Early, by the government, for poor performance:** lawful when the concessionaire missed the start duty or ran late
  past the late-job bar (as `_check_late`) on 2 or more jobs in 12 months.
  - Fact: ECON_CONCESSION_TERMINATED (PUBLIC, reason).
  - Open jobs go back to tender (the half-built rules, E169).
  - No compensation is owed.
- **Early, by the government, without cause** (e.g. a new government wants another builder): lawful, but the
  concessionaire is owed **compensation**: 6 months of retainer plus 5% of the value of the jobs already ordered. That's
  a COMPENSATION liability of the treasury, through the existing gov_owed path if the treasury is empty. It is public.
- **By the concessionaire's insolvency:** it ends. Open jobs go to tender.
- **Parliament** may end all concessions of a class by law (e.g. a "public works only" policy). That counts as without
  cause, so compensation is due.

### 2.4 Other law it touches

- **Competition:** a concession is a lawful exclusive right granted by tender; it's not abuse of dominance. If the
  concessionaire is dominant in the building market, the competition authority's view goes into the tender score: it
  can recommend splitting the concession into districts. That's advice to the government, not binding.
- **Rule 8 (no new company):** no entrant is founded for work a concession holds (Bob's side).
- **Public builder (CWD) bidding for a concession:** it may bid. If it bids at cost while dominant, it counts as
  predation (the competition law's PRICE_BELOW_COST rule) unless parliament exempts public builders by law. That needs
  Otto's lever **ECON_PUBLIC_BUILDER_AT_COST** (0/1, default 0; econ_pic, requires R8_BUILDERS), at LAW level, so the choice is political, as §3c wants.
- **Labour:** the reserved crew are ordinary employees. The retainer is paid to the firm, not the workers, and the firm
  still pays full wages.

## 3. Who decides (Wilma's request: minister, alone or not)

| decision | owner | alone? | needs |
|---|---|---|---|
| Award a tendered job to the top score | **Minister of Infrastructure** (civil service if routine) | yes | none |
| Award to a lower-ranked bidder (override) | **Minister of Infrastructure** | yes, but public | none; Wilma's politics may make large overrides First-Minister items |
| Direct award below the threshold | **Minister of Infrastructure** (civil service) | yes | none |
| Direct award above the threshold in an emergency | **Minister of Infrastructure** | yes, while the emergency lasts | the emergency itself is the First Minister's or parliament's |
| Unlawful direct award or concession | whoever does it | n/a | it's unlawful: risk of discovery |
| Tender a concession (start, class, area) | **Minister of Infrastructure** | yes, for terms up to LAW_CONCESSION_MAX_YEARS | a concession worth more than [X] a year (proposed: 2% of annual public spending) goes to **the Cabinet (First Minister)** |
| Choose the concessionaire | **Minister of Infrastructure** on the tender score | yes; an override is public | the same Cabinet threshold as above |
| End early for cause | **Minister of Infrastructure** | yes | none |
| End early without cause (compensation due) | **the Cabinet (First Minister)** | no | it's a spending decision with a political cost |
| End all concessions of a class | **parliament** (a law) | no | a bill |
| LAW_DIRECT_AWARD_THRESHOLD | **Minister of Finance** (REGULATION level, as today) | yes, within its range | none |
| LAW_CONCESSION_MAX_YEARS, LAW_RETAINER_CAP, ECON_PUBLIC_BUILDER_AT_COST | **parliament** (LAW level) | no | a bill |

Most decisions stay with one minister. Only large concessions, early termination without cause and the laws go
higher.

## 4. The interface for Bob (code behind his flag)

```
ProcLaw.award_check(world, job, builder, method, opts) -> {lawful, reason, method, needs_cabinet}
    method: TENDER | DIRECT | OVERRIDE; opts: {emergency, concession_id}
ProcLaw.concession_open(world, cls, area, term_years) -> {ok, reason, needs_cabinet}       # the tender may start
ProcLaw.concession_bid_ok(world, bid) -> {ok, reason}         # retainer ≤ cap, term ≤ max
ProcLaw.concession_award(world, cls, area, bid, rank) -> concession id (row in law state, fact)
ProcLaw.concession_for(world, cls, district) -> {} or the active concession
ProcLaw.retainer_due(world, conc_id, idle: bool, crew_wages: int) -> int (milli-credits)
ProcLaw.concession_end(world, conc_id, cause: "TERM"|"CAUSE"|"NO_CAUSE"|"INSOLVENCY"|"LAW") -> {compensation}
ProcLaw.unlawful_direct(world, job, builder) -> unlawful_track id      # when the AI/player awards against the rule
```

**Bob's hook:** one wrapper in `EconConstruction.award()` (every award lands there) calls `award_check` for government jobs;
unlawful → `unlawful_direct` (the award is still made, so the courts can quash it).

The concession row lives in law state (`law_state.s.concessions`), so the courts and the press can read it. Bob keeps
the crews, the jobs, the retainer payment and the scoring.

## 5. Tests (when coded)

1. A small job is direct-awarded lawfully. The same job above the threshold is unlawful (SECRET record, burdened
   bidders).
2. An emergency allows a direct award above the threshold.
3. A concession tender: bids above the retainer cap are rejected. The winner gets the class's jobs as direct awards.
4. The retainer is paid only in idle months.
5. Early termination for cause pays nothing; without cause, it pays 6 months of retainer + 5%, owed by the treasury if
   it's empty.
6. Insolvency ends it, and jobs go to tender.
7. A dominant public builder bidding at cost is predation unless ECON_PUBLIC_BUILDER_AT_COST.
8. Flag off: nothing changes (deterministic).

## 6. For Wilma

New levers and their ideology (proposals):

- **LAW_CONCESSION_MAX_YEARS** (1–10, default 5): ECON_ROLE −0.3 (longer = more market), INSTITUTIONS 0. Concerns:
  INFRASTRUCTURE +5 / GOVERNANCE −3.
- **LAW_RETAINER_CAP** (0–60%, default 40): FISCAL +0.05 (a higher cap costs more). Concerns: INFRASTRUCTURE +4 /
  FISCAL −3.
- **ECON_PUBLIC_BUILDER_AT_COST** (Otto's, 0/1, default 0; legalLevel LAW, so parliament decides, because 1 exempts the
  public builder from the predation rule): ECON_ROLE +10 (state-minded want it). Concerns: INFRASTRUCTURE +8 / JOBS −4
  (private builders undercut).

One new rule (DIRECT_AWARD) and one new unlawful act (unlawful concession).
