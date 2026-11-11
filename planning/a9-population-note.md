# a9 note: law and justice parts of M10 (population blocks)

Answers spec-population-v1 §4.2, §5.3, §5.4, §6.1 and §12 for the law/justice side. Decisions are J21–J27 in DECISIONS.md.
Status: (1) levers and the count function are in now; the hook-up waits for Wilma's S1 API. (2) and (3) are proposals for S3/S5.

## 1. Eligibility (§4.2, PD §9.6) — levers in, count function ready

| Lever | Type | Default | Meaning |
|---|---|---|---|
| `LAW_VOTING_AGE` | ENUM "16" / "18" / "21" | "18" | minimum voting age |
| `LAW_RESIDENCY_FOR_VOTE` | NUMBER months 0–24 | 0 | months in the colony before a newcomer may vote |
| `LAW_NONCITIZEN_VOTE` | BOOL | true | false: newcomers (`recent`, under 24 months) may not vote at all |

All three are LAW level and LOCKED in the founding era. They have ideology slopes on today's axes (INSTITUTIONS, REDISTRIBUTION). When S3 adds the new axes, they move to STABILITY / LIBERTY.

**Citizenship in v1:** a person becomes a citizen after 24 months in the colony, which is exactly when they stop counting in `recent`. Nothing else is needed to track it.

**Calls for politics:**
- `LQ.eligible_voters(world, leaf)` takes `{n, age:{C,Y,A,M,O}, recent}` and returns an int. It is pure and cheap; call it per leaf or per philosophy node.
  - Ages are spread evenly within each band. Voting at 16 adds 2/18 of the children (C). Voting at 21 removes 3/12 of the young adults (Y).
  - Newcomers are assumed to be spread like the rest of the leaf, with arrival dates spread evenly over their 24 months. A residency rule of R months therefore bars R/24 of them. With no non-citizen vote, all of them are barred.
- `LQ.eligibility(world)` returns `{voting_age, residency_months, noncitizen_vote, text}`. The `text` field is the rule text for the UI.

**Timing (J22):** a change to the voting law applies only to elections held at least 6 months after it takes effect. This stops a government changing the electorate just before a vote. I'll add `LQ.eligibility_for_election(world, month)` together with the S1 hook-up.

## 2. Justice trust (§5.4, PD §16.4)

Per leaf `trust.justice` (0–100000). It is moved by a **target** plus **shocks**, the same model as the other trust types.

**Target**, recomputed monthly. Wilma moves trust 5% per month toward it.
- The target is a weighted mean of four indicators (each 0–100):
  - `LAW_RULE_OF_LAW` 0.30
  - court timeliness = 100 − scaled `LAW_COURT_DURATION` (0.25)
  - `LAW_ENFORCEMENT_CONSISTENCY` 0.20
  - **new** `LAW_JUDICIAL_INDEPENDENCE` 0.25
- An indicator that has not been published yet counts as 60.
- I'll provide `LawOps.justice_trust_target(world) -> int`. Archetype weights adjust it on Wilma's side: INSTITUTION leaves weight independence ×1.5, LIBERTY leaves weight rights violations ×1.5.

**`LAW_JUDICIAL_INDEPENDENCE`** (new, colony-wide). It starts at 100 and loses:
- 30 × the court budget shortfall (`LAW_COURT_BUDGET` against what the judges cost);
- 15 for each ruling against the government that it then defied (it acted unlawfully again on the same lever or act), decaying with a 12-month half-life;
- 10 for 24 months after a law that cuts `LAW_JUDGES`.

**Shocks**, from PUBLIC law facts. These are trust points applied once to leaves that perceive the fact:

| Fact | Justice trust | Note |
|---|---|---|
| `LAW_LEADER_CONVICTED` | +3 | no one above the law |
| `LAW_RULING`, `against_government`, type UNLAWFUL_GOV | +2 | the courts check power. Government trust is Wilma's, already blamed |
| `LAW_RULING` acquitting a PARTY or GOVERNMENT respondent on strong evidence (`data.strong`) | −3 | the powerful walk free. I'll add `data.strong` |
| `LAW_OVERSIGHT_FAILURE` | −2 | |
| any `*_REVEALED` unlawful government act, no ruling yet | −2 | rights violation |
| `LAW_INVESTIGATION_CLOSED`, CLEARED, after a scandal was revealed | −1 | looks like a whitewash |
| personal experience | ±(exposure) | via the S4 `exposure` on rulings (§4 below) |

## 3. FREEDOM concern indicator (§5.3)

**`LAW_FREEDOM`**: 0–100, colony-wide, polarity +1. It feeds concern FREEDOM with weight 1.0 and is `exceptionOnly`, so a free colony at 100 does not dilute satisfaction.

FREEDOM = 100 minus the following deductions:
- a restriction score from the rights levers;
- revealed rights violations: unlawful acts by the government that burden households, with the same decay as rule of law (20 points per magnitude-50 act, 12-month half-life);
- 10 while a caretaker government is in office past its formation limit (later).

The rights levers are new, added at S3 together with the concern. Each has a real trade-off, so the choice is not one-sided:

| Lever | Values (default first) | FREEDOM cost | Benefit / mechanism |
|---|---|---|---|
| `LAW_PRESS_FREEDOM` | FREE / LICENSED / CENSORED | 0 / 15 / 40 | S8: CENSORED hides OFFICIAL/PUBLIC government blame facts from reports (visibility); LICENSED delays them 3 months |
| `LAW_ASSEMBLY` | FREE / NOTIFY / PERMIT | 0 / 5 / 20 | fewer and shorter `ECON_STRIKE`s (88 reads the lever) |
| `LAW_SEARCH_POWERS` | WARRANT / ADMIN / BROAD | 0 / 8 / 25 | inspectorate find probability +0.1 / +0.2; later, police |
| `LAW_VOTING_AGE` "21", no non-citizen vote | — | 3 each | (§1) |

S9 alcohol prohibition, when it comes, adds a cost here too.

## 4. Facts that get an `exposure` block (S4, §6.1)

| Fact | Scope | kind | Notes |
|---|---|---|---|
| `LAW_RULING`, ENFORCEMENT (company fined) | employer = company | `ENFORCEMENT` | workers: insecurity, but WORK_CONDITIONS improves; intensity by fine class |
| `LAW_LICENCE_SUSPENDED` | employer | `JOB_INSECURITY` | 3 months, decays |
| `*_REVEALED` unlawful government act with `burdened_ref` | district / status / occ of the burdened group | `RIGHTS_VIOLATION` | grievance; justice and government trust |
| `LAW_RULING` UNLAWFUL_GOV won by the burdened side | same scope as the violation | `REDRESS` | partly offsets RIGHTS_VIOLATION |
| `LAW_OVERSIGHT_FAILURE` (from an accident or whistleblower) | employer of the violator | `UNSAFE_WORK` | only if 88's accident fact does not already cover it |
| permit denials | — | — | no exposure: `LAW_PERMIT_WAIT` is already a district indicator |
| `POL_SCANDAL_REVEALED`, `LAW_LEADER_CONVICTED` | — | — | colony-wide: a shared effect, no split |

## 5. Named staff in labour accounting (§12, PD §11.5)

**`SQ.named_headcount(world)`** (implemented now) returns `{political, civil, judges, party, public}`:
- `public` = political officials + civil servants + judges. This is what 88 subtracts from PUBLIC_SECTOR employment.
- `party` = opposition party staff. These are private employees, to subtract from PROFESSIONAL.

Only ACTIVE and UNAVAILABLE people are counted; the bench is not employed. It is about 20 + 5 judges today. Recruits come from the population, so a hire is a PUBLIC_SECTOR job filled by a transfer, and a retirement is a status change (S2/S5, together with 88).
