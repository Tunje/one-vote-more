# Law v1 (thin law): Closed Specification

**Owner:** a9 (staff & justice) · **Status:** v1 closed for M3/M6 · **Date:** 2026-11-10
**Binding inputs:** pic-core.md (§4 Facts, §5 Levers, §6 Actions, §7 tick); MASTER-PLAN A3, X7, X13; DECISIONS A1–A6 (GDScript core)
**Supersedes for v1:** justiceAndLaw.md §3, §4, §21, §27–29 (grammar and numbers). Everything in J that isn't listed here is **post-v1** (criminal law, police, emergency powers, constitutional review, alcohol, media law, corporate/insolvency procedure, labor courts).
**Companion docs:** [spec-staff-v1.md](spec-staff-v1.md), [pic-staff-law.md](pic-staff-law.md)

> **Role in the game:** law is **how political decisions become binding, and how they are constrained.** A passed bill is a bundle of *clauses*. Each clause compiles into **LegalRules** (what actors may or must do) and **LeverChanges** (parameters other systems read). The same rules engine checks every actor, including the player government, against those rules.

---

## 1. Concepts in one page

```
Bill / Ordinance / Regulation / AdminDecision   (an Instrument, with a legal level)
   └── Clause (from a ClauseTemplate + params)
          ├── emits LegalRule[]     → Rules engine (validate actions)
          └── emits LeverChange[]   → Lever pipeline (pic-core §5)
                Decision → legal check → implementation task (staff) → lag → effect
```

- **Legal value vs operative value.** Every lever has a *legal value* (what the law in force says) and an *operative value* (what the simulation uses). They differ while implementation is pending. Politics sees both. "Enacted but not implemented" is a political state (promise tracking).
- **Principle of legality (asymmetry):**
  - **Private actors** (companies, households, parties) may do anything *not prohibited*.
  - **Public actors** (government, commander, institutions) may do only what a rule *authorizes*.
  - This one rule produces most of J's intended constraint gameplay.

---

## 2. Legal levels (closes J §4)

| Level | Enum | Made by | Changes levers with `legalLevel` | Needs |
|---|---|---|---|---|
| 1 | `CHARTER` / `CONSTITUTIONAL` | Origin charter; after transition, the constitution | CHARTER | v1: **not changeable** (amendments post-v1, §9) |
| 2 | `LAW` | Parliament (bill passed by D1 vote). In the founding era: the commander's **provisional ordinance**. | LAW, REGULATION, ADMIN | Drafting task + vote (or ordinance in the founding era) |
| 3 | `REGULATION` | Government decision | REGULATION, ADMIN; LAW-level levers **only if a LAW delegates them** (DELEGATE clause), within the delegated bounds | `STAFF_T_DRAFT_ORDINANCE` task |
| 4 | `ADMIN` | Government / authority, individual decisions | ADMIN only | No drafting. Implementation `STAFF_T_IMPL_ADMIN` (5 WU) |

Contracts (J level 6) live in econ/comp in v1. The engine does not evaluate them.

**Precedence when rules conflict:**
1. Higher level wins.
2. Then the more specific rule wins (specificity = number of selector and condition predicates).
3. Then the later `effective_month` wins.
4. Then explicit `supersedes`.

If two rules are still tied (same level, same specificity, same month, contradictory effect), the result is `DISPUTED`. See §5.

---

## 3. Action taxonomy (`LegalActionType`, closes review gap #29)

A closed enum. Every pic-core Action names exactly one LegalActionType. Parameters are typed and become predicate fields.

| Group | LegalActionType | Params (predicate fields) | Typical actor |
|---|---|---|---|
| LAND | `ZONE_DISTRICT` | district, zone_type | GOV, COMMANDER |
| | `BUILD_FACILITY` | facility_type, district, owner_kind, value_wref | COMPANY, GOV |
| | `DEMOLISH_FACILITY` | facility_type, district, owner_kind | COMPANY, GOV |
| OPERATE | `OPERATE_FACILITY` | facility_type, district, hazard_class | COMPANY, INSTITUTION |
| | `EXTRACT_RESOURCE` | resource, site_district | COMPANY |
| | `SELL_GOOD` | resource, buyer_kind | COMPANY |
| | `IMPORT_GOOD` | resource, qty | COMPANY, GOV |
| EMPLOY | `HIRE` / `SET_WAGE` / `DISMISS_WORKERS` | employer_kind, skill_tier, wage | COMPANY, GOV |
| FISCAL | `LEVY_TAX` | tax_type, rate | GOV |
| | `SPEND` | budget_line, amount_wref | GOV |
| | `BORROW` | amount_wref, lender | GOV |
| | `GRANT_SUBSIDY` | sector, amount_wref | GOV |
| PROCURE | `AWARD_CONTRACT` | contract_type, value_wref, method (OPEN/RESTRICTED/DIRECT) | GOV |
| | `TERMINATE_CONTRACT` | contract_type, reason (BREACH/CONVENIENCE) | GOV, COMPANY |
| ADMIN | `ISSUE_PERMIT` / `DENY_PERMIT` | permit_type, applicant_kind | GOV/authority |
| | `ISSUE_LICENCE` / `REVOKE_LICENCE` | licence_type, holder_kind | GOV/authority |
| | `EXPROPRIATE` | asset_kind, compensation_pct | GOV |
| GOVERN | `SET_LEVER` | lever_id, value, instrument_level | GOV, COMMANDER, PARLIAMENT |
| | `APPOINT_OFFICIAL` / `DISMISS_OFFICIAL` | role, party_id | GOV, PARTY |
| | `HOLD_ELECTION` / `POSTPONE_ELECTION` | month | GOV, COMMANDER |
| | `RESTRICT_ASSOCIATION` | target_kind (PARTY/UNION) | GOV |
| | `RESTRICT_ASSEMBLY` / `RESTRICT_EXPRESSION` | scope | GOV |
| | `INSTRUCT_AUTHORITY_DECISION` | decision_id | GOV (individual instruction to an authority) |
| PARTY | `REGISTER_PARTY` / `CAMPAIGN` | — | PARTY |

**Actor kinds** (predicate `actor.kind`): `COMMANDER`, `GOVERNMENT`, `PARLIAMENT`, `AUTHORITY` (permit office; M6: courts, regulators), `COMPANY` (with `actor.ownership` PUBLIC/PRIVATE/COOP), `HOUSEHOLD`, `PARTY`. Public actors are COMMANDER, GOVERNMENT and AUTHORITY.

Adding a new LegalActionType is a data change (`game/data/law/actions.json`) plus the emitting subsystem calling `validate()`.

---

## 4. LegalRule grammar (closes J §27.1 gap)

```
LegalRule {
  id
  level:          CHARTER | CONSTITUTIONAL | LAW | REGULATION | ADMIN
  provisional:    bool                        // founding ordinance (§7.3)
  source:         { instrument_id, clause_idx, enacted_by: ActorRef }
  status:         PENDING | ACTIVE | EXPIRED | REPEALED | SUSPENDED
  effective_month, expiry_month | null
  kind:           PERMIT | PROHIBIT | REQUIRE | AUTHORIZE | DELEGATE
  subject:        Predicate[]                 // who: actor.kind, actor.ownership, actor.id …
  action:         LegalActionType | "*"
  where:          Predicate[]                 // conditions on action params / world (AND)
  unless:         Predicate[]                 // exceptions (OR)
  requirement:    { licence_type? | permit_type? | approval_by? (PARLIAMENT|AUTHORITY) | compensation_pct_min? } | null   // for REQUIRE
  delegation:     { lever_id, min, max, to_level } | null   // for DELEGATE
  penalty_class:  MINOR | SERIOUS | SEVERE | null           // used from M6 (§10)
  supersedes:     RuleId[]
  defect:         bool                        // from drafting quality (staff §3); legally vulnerable
}

Predicate { field: string, op: EQ|NEQ|IN|NIN|LT|LTE|GT|GTE, value }
```

- **Fields** come from a registry: `actor.kind`, `actor.ownership`, `actor.id`, `p.<param>` (action params), `district.zone`, `district.id`, `world.era` (FOUNDING/PARLIAMENTARY), `world.month`, `lever.<id>` (current operative value), `holder.has_licence.<type>`, `holder.has_permit.<type>`.
- **The grammar has no code and no nesting**, so it serializes to JSON for saves.
- Lever *values* are **not** LegalRules. They are LeverChange records (§6) that carry their own legal level and source. This keeps the engine small.

---

## 5. Rules engine: `validate(actor, action, params, world) → LegalResult`

1. **Index:** active rules are bucketed by `action` (plus a `*` bucket). There are ~100–300 rules in v1, so a linear scan per bucket is fine.
2. **Match:** keep the rules where all `subject` and `where` predicates hold and no `unless` predicate holds.
3. **Resolve:** apply precedence (§2) among matching PROHIBIT, PERMIT and AUTHORIZE rules.
4. **Decide the default** with the legality asymmetry (§1):
   - A public actor with no matching AUTHORIZE (or a higher-ranked PROHIBIT) → `PROHIBITED`.
   - A private actor with no matching PROHIBIT → allowed.
5. **Collect requirements:** add every matching REQUIRE rule (licence, permit, approval, compensation).
6. **Return** one of:

| Result | Meaning | Who sees it |
|---|---|---|
| `AUTHORIZED` | Go | — |
| `AUTHORIZED_WITH_CONDITIONS` | Allowed once the listed licences/permits are held. The engine lists what is missing. | UI warning (J §26.6) |
| `REQUIRES_APPROVAL` | Needs PARLIAMENT (e.g. spending beyond appropriation) or AUTHORITY | Becomes a staff escalation or a bill |
| `PROHIBITED` | List of rule ids | Blocked. See override (§8) |
| `DISPUTED` | Tie between contradictory rules, or a winning rule with `defect = true` | Allowed, but flagged *legally vulnerable*. From M6 it can be appealed. |
| `INSUFFICIENT_INFO` | A required param or field is missing | Developer error in v1. Asserted in tests. |

Every result carries `trace: RuleId[]` for explainability (project §20.4). Performance budget: ≤ 2,000 validations/month at < 20 ms total in GDScript. If that is exceeded, cache by `(actor.kind, action, params hash, rules_version)`.

---

## 6. Clauses → rules and levers (critical politics interface)

### 6.1 Lever registry contract (from pic-core §5)
Law adds these **law-owned fields** to every lever definition, whoever owns the lever:

| Field | Meaning |
|---|---|
| `legalLevel` | Minimum level allowed to set it (pic-core) |
| `foundingEra` | COMMANDER (an ordinance may set it) or LOCKED |
| `implementation` | One of the 5 `STAFF_T_IMPL_*` classes (staff §10.2). **No lever has null in v1.** Even a tax change needs `IMPL_FISCAL` (10 + 5 WU), so capacity always matters. |
| `lag` | Months between implementation completing and the operative change |
| `delegable` | Whether a LAW may delegate it to REGULATION, and the max bounds |
| `charter_bounds` | Optional hard [min, max] set by the charter (§7.1). Values outside are `PROHIBITED` for every level below CHARTER. |

### 6.2 Lever change pipeline
```
SET_LEVER action (with instrument) ── validate ──► rejected (PROHIBITED: level too low / outside charter bounds / no delegation)
        │ ok
        ▼ effective_month reached
  legal value := new            → fact POL_LEVER_CHANGED (pic-core)
  create/extend STAFF_T_IMPL_<class> task instance for the instrument
        │ task completes (staff phase)
        ▼ + lever.lag months
  operative value := new        → fact <OWNER>_LEVER_EFFECTIVE
```

- **Repeals and re-changes before implementation:** the pending implementation is cancelled or rescoped. Completed work is kept as progress on the new instance if the class matches.
- **Default `effective_month`:** passage month + 1, unless the clause specifies a later month.

### 6.3 ClauseTemplate catalogue (v1)
Each template is a **pure function**: `params → (LegalRule[], LeverChange[], political payload)`.

- **Political payload:**
  - lever deltas → ideology via the lever `ideology` slopes (pic-core §5)
  - fiscal estimate via the owners' estimators
  - `drafting_domain` (which skill the policy lead needs, staff §10.1)
  - `work` = 20 WU of drafting per clause (staff §10.1)
- **Parties vote on the payload, not on the clause text.**

| Template id | Params | Emits rules | Emits lever changes | Domain skill | Impl. class |
|---|---|---|---|---|---|
| `CL_SET_LEVER` | lever_id, value, scope (district?) | — | 1 LeverChange at the instrument's level | lever owner's domain (tax → ECON, labor → ECON/PUBS, env → ENV, infra → ENG) | lever's class |
| `CL_DELEGATE` | lever_id, min, max | `DELEGATE` (gov may set the lever by REGULATION within [min, max]) | — | LAW | ADMIN |
| `CL_REQUIRE_LICENCE` | activity: LegalActionType + where-predicates, licence_type, fee | `REQUIRE {licence_type}` on the activity | Lever `LAW_LICENCE_REGIME_<TYPE>` = REQUIRED. `LAW_LICENCE_FEE_<TYPE>` = fee | LAW + domain | REGULATORY |
| `CL_PROHIBIT` | activity, unless[] | `PROHIBIT`, penalty_class | — | LAW | REGULATORY |
| `CL_PERMIT` | activity | `PERMIT` (carve-out, more specific) | — | LAW | ADMIN |
| `CL_APPROPRIATE` | budget_line, amount_wref/yr, years | `AUTHORIZE SPEND where p.budget_line = X and cumulative ≤ amount` | Lever `ECON_BUDGET_<LINE>` | ECON | FISCAL |
| `CL_AUTHORIZE_PROJECT` | project spec (88), max value | `AUTHORIZE BUILD_FACILITY / AWARD_CONTRACT where p.value_wref ≤ max` | — (econ creates the Project) | ENG | PROGRAM |
| `CL_SUBSIDY` | sector, rate or amount, conditions | `AUTHORIZE GRANT_SUBSIDY where …` | `ECON_SUBSIDY_<SECTOR>` | ECON | PROGRAM |
| `CL_STANDARD` | standard lever (min wage, safety level, emission cap…), value | For caps: `PROHIBIT OPERATE_FACILITY where p.<metric> > lever` (enforced from M6) | The lever | ECON/PUBS/ENV | REGULATORY |
| `CL_PROGRAM` | program lever (housing allowance, service expansion) | `AUTHORIZE SPEND` on the program line | Program levers | PUBS | PROGRAM |
| `CL_INSTITUTION` | institution type (v1: permit office capacity; M6: court, inspectorate) | `AUTHORIZE` the institution's ADMIN actions | `LAW_<INST>_BUDGET`, `LAW_<INST>_SIZE` | ADMIN/LAW | INSTITUTION |
| `CL_PROCUREMENT_RULE` | direct-award threshold, open tender required | `REQUIRE {approval_by: AUTHORITY}` or `PROHIBIT AWARD_CONTRACT where method = DIRECT and value > t` | `LAW_DIRECT_AWARD_THRESHOLD` | LAW/ADMIN | REGULATORY |
| `CL_EXPROPRIATION_POWER` | purpose, compensation_pct (≥100 per charter) | `AUTHORIZE EXPROPRIATE where …` + `REQUIRE compensation_pct_min` | — | LAW | ADMIN |
| `CL_CONFIRM` | provisional rule ids | Re-issues them at LAW level, non-provisional | — | LAW | ADMIN |
| `CL_REPEAL` | rule ids or instrument id | Sets status REPEALED from the effective month. Lever changes revert to the next-highest active source or the default. | Reverting LeverChanges | LAW | class of the reverted levers |
| `CL_AMEND` | rule id, new params | New rule with `supersedes` | Changed LeverChange | as the original | as the original |

### 6.4 Worked example
**Bill "Fair Work Act" (3 clauses):**
1. `CL_STANDARD(ECON_MIN_WAGE, 0.75 W_ref)`
2. `CL_PROHIBIT(OPERATE_FACILITY where p.hazard_class = HIGH unless holder.has_licence.HAZARD)`
3. `CL_DELEGATE(ECON_MIN_WAGE, 0.6, 0.9)`

**Drafting:** `STAFF_T_DRAFT_BILL`, work 90 WU, domain ECON. The bill's payload sums its lever deltas: LABOR +, REDISTRIBUTION +.

**Passage (month t):**
- At month t+1 the legal values switch.
- One `IMPL_REGULATORY` instance is created, with work 30 + 15·2 = 60 WU, covering min wage + hazard licence.
- One `IMPL_ADMIN` instance (5 WU) is created for the delegation.

**Implementation done (month t+3) + lag (min wage lag 1):** the operative min wage switches at t+4 and `ECON_LEVER_EFFECTIVE` is emitted.

**From then on,** a company `OPERATE_FACILITY` with hazard HIGH and no licence → `AUTHORIZED_WITH_CONDITIONS[missing HAZARD]`. The company AI applies (§10 licences). Until it gets the licence, the facility operating is a violation: `LAW_VIOLATION` with visibility SECRET (detection from M6).

---

## 7. Founding charter and the transition (closes review gap #30)

### 7.1 Charter content (CHARTER level, immutable in v1)
About 25 rules. Data file `game/data/law/charter.json`.

**Rights, encoded as rules on public actors.** All are `PROHIBIT` with `subject actor.kind IN [COMMANDER, GOVERNMENT, AUTHORITY]`:

| Right (J §5) | Rule |
|---|---|
| Political participation | `PROHIBIT POSTPONE_ELECTION where p.month > 48` (first election) or beyond a term's end. `REQUIRE HOLD_ELECTION` every 48 months. |
| Association | `PROHIBIT RESTRICT_ASSOCIATION` (parties, unions) |
| Expression / assembly | `PROHIBIT RESTRICT_EXPRESSION`, `PROHIBIT RESTRICT_ASSEMBLY` *(safety exceptions post-v1)* |
| Property | `EXPROPRIATE` requires an AUTHORIZE from a LAW (or ordinance) **and** `compensation_pct_min = 100` |
| Due process / non-retroactivity | Penalties apply only to acts after the rule's effective month (engine invariant, M6) |
| Equality before the law | Rules may not select `actor.id` for burdens (PROHIBIT/REQUIRE). This is a **validation-time check** on clause params, so it can't be drafted. |
| Labor floor | Charter bound on `ECON_MIN_WAGE` ≥ 0.4 W_ref and `LAW_SAFETY_STANDARD` ≥ BASIC |
| Independence of authorities | `INSTRUCT_AUTHORITY_DECISION` is not authorized (so it is prohibited for public actors by default). See §8. |

**Commander powers (`AUTHORIZE`, `where world.era = FOUNDING`):**
- `SET_LEVER` for any lever with `foundingEra = COMMANDER` and `legalLevel ≤ LAW`, via **provisional ordinance** (level LAW, `provisional = true`). This needs `STAFF_T_DRAFT_ORDINANCE`.
- `ZONE_DISTRICT`, `BUILD_FACILITY` (public), `AWARD_CONTRACT`, `SPEND` within the founding budget, `ISSUE/DENY_PERMIT` (via the permit office), `APPOINT/DISMISS_OFFICIAL` (founding appointees).
- `BORROW` up to the origin credit line (88 defines the lender).

**Charter bounds** (hard limits for every level below CHARTER, through v1):

| Lever | Bound |
|---|---|
| Any single tax rate | ≤ 50% |
| `ECON_MIN_WAGE` | ≥ 0.4 W_ref |
| Expropriation compensation | ≥ 100% of market value |
| `STAFF_CIVIL_RETIREMENT_AGE` | 60–72 |

**Locked in the founding era (`foundingEra = LOCKED`):** the electoral system (A5), the size of parliament, and the charter itself. These are **not** levers the commander can touch.

**Property and resources:**
- All land and subsurface resources start public (expedition assets).
- Extraction requires `LICENCE_EXTRACTION` (§6.3). Royalty lever `LAW_EXTRACTION_ROYALTY` defaults to 8% of the extracted value.
- Land may be leased or sold by the government (`AUTHORIZE` for COMMANDER/GOVERNMENT). Prices are owned by 88.

### 7.2 Transition at the first government (not on election day)
The transition fires **in the month the first parliamentary government takes office**. Between the election and formation, the commander is a caretaker: only standing duties and running tasks continue, and no new ordinances can be made.

The transition is atomic, in the DECISIONS phase:
1. CHARTER rights rules are re-issued at **CONSTITUTIONAL** level (same content). The `Constitution` entity is created and the charter is archived.
2. Commander `AUTHORIZE` rules expire (`where world.era = FOUNDING` no longer matches). `world.era := PARLIAMENTARY`.
3. New constitutional rules:
   - `SET_LEVER` at LAW level is authorized for **PARLIAMENT only**.
   - GOVERNMENT gets REGULATION/ADMIN and anything delegated.
   - `SPEND` requires an appropriation: an annual budget law (`STAFF_T_BUDGET` → bill).
   - Amendment procedure recorded (§9).
4. **Provisional ordinances become "deemed statutes":** they are converted to LAW level with `provisional = false`. They keep their values and need no sunset or cliff. Parliament may amend or repeal them normally. Each conversion emits `LAW_ORDINANCE_DEEMED` (magnitude 5, responsible COMMANDER).
   - *Rationale:* avoids a lever cliff, and the commander era stays attributable (credit/blame) to the player's party.
5. Founding appointees move to the player's party bench (X4, staff §5.4). Seat allocation follows staff §7.1.
6. Emit `LAW_CONSTITUTION_ADOPTED` (magnitude 60, PUBLIC).

---

## 8. Unlawful government action (the player can break the law; it costs politically)

If `validate` returns `PROHIBITED` for a **public** actor (player government or AI government), the UI offers **"Proceed anyway (unlawful)"**. AI governments may also choose it, by D7 utility with a large legitimacy penalty term.

When chosen:
- The action executes.
- A fact `LAW_UNLAWFUL_GOV_ACTION` is emitted with visibility **SECRET**, magnitude 30–70 by penalty class, `responsible = GOVERNMENT 0.8 / OFFICIAL 0.2` (the official who executed it).
- **Discovery** (monthly, RNG stream `law.discovery`). The fact is promoted via `LAW_UNLAWFUL_GOV_ACTION_REVEALED`, which politics reacts to, when any of these fire:
  - Civil-service leak: p = 0.03 per month while effects persist. ×0.5 if the executing official has integrity < 40.
  - Opposition oversight (`STAFF_T_OVERSIGHT` on that domain): staff §3 probability.
  - Affected party complaint (when the action burdens a company/party): p = 0.10 per month.
  - From M6: an affected party files an administrative appeal, and the court reveals it on filing.
- **Revealed unlawful actions** feed `LAW_RULE_OF_LAW` (pic-staff-law §1) and, through D1, legitimacy (A6 soft-fail input).
- **From M6:** an appeal or review overturns the action (§10.3). Lever and permit effects revert, and compensation is paid through the ledger.

This satisfies the M6 exit criterion ("an unlawful government action is blocked or overturned, and it shows up in the polls"). **v1 before M6** still has blocking plus SECRET → REVEALED politics, just no overturning.

---

## 9. Constitutional amendment (closes review Q8)
- **Procedure** (implemented as data in v1; **no player-facing amendment clauses until post-v1**): two identical decisions by simple majority of votes cast, with an ordinary election between them. The first decision must be taken at least 9 months before that election. An early election counts as the intervening election.
- **v1 effect:** CHARTER/CONSTITUTIONAL rules and charter bounds are immutable during v1 play.
- **Post-v1:** constitutional clause templates plus constitutional review.

---

## 10. Licences and permits (v1)

### 10.1 Types

| Type | Kind | Required for (rule) | Criteria (auto-evaluated) | Term | Fee lever (default) | Level |
|---|---|---|---|---|---|---|
| `PERMIT_BUILDING` | Permit (one action) | `BUILD_FACILITY` (all) | District zone compatible with facility type (map); applicant owns or leases the plot; infrastructure link present | One-time | `LAW_FEE_BUILDING_PERMIT` = 0.5% of value, min 1 W_ref | REGULATION |
| `LICENCE_EXTRACTION` | Licence | `EXTRACT_RESOURCE` | Site in a MINING zone; `LAW_SAFETY_STANDARD` plan ≥ current | 120 months | `LAW_FEE_EXTRACTION` = 5 W_ref; royalty `LAW_EXTRACTION_ROYALTY` 8% (LAW) | LAW |
| `LICENCE_HAZARD` | Licence | `OPERATE_FACILITY where hazard_class = HIGH` (smelter, power, chemical) | Safety plan ≥ `LAW_SAFETY_STANDARD` | 60 months | `LAW_FEE_HAZARD` = 3 W_ref | REGULATION |
| `REG_BUSINESS` | Registration | All companies (comp C1) | None (automatic, 0 months) | Permanent | 0 | ADMIN |

**Regime levers:**
- `LAW_LICENCE_REGIME_<TYPE>`: ENUM `NONE / REQUIRED`. Default REQUIRED for the three above. LAW level. Founding era: COMMANDER.
- `LAW_PERMIT_STRICTNESS`: ENUM `LENIENT / STANDARD / STRICT`. Default STANDARD. REGULATION level.
  - LENIENT skips the infrastructure-link check.
  - STRICT adds an environmental check against `ENV` emission caps (88's facility pollution).

### 10.2 Who issues
In v1 the **Permit & Licence Office** is an AUTHORITY: one institution, colony-wide, created by the charter. Its management capacity is the standing duty `STAFF_SD_PERMITS` (staff §10.3). Its budget is lever `LAW_PERMIT_OFFICE_BUDGET` (LAW via the budget; default 6 W_ref/month), and that budget funds clerical baseline capacity.

### 10.3 Throughput and errors
- **Capacity:** `applications decided/month = floor(2 + 10·e_permits) × min(1, budget/6 W_ref)`, where e is the staff coverage effectiveness. Unmanaged: 2/month. Fully managed: 12/month.
- **Queue:** FIFO, colony-wide. `LAW_PERMIT_WAIT` = mean months in queue (indicator).
- **Decision:** criteria are evaluated by the rules engine. Wrong-outcome probability per decision = `(100 − Q)/400`, using staff Q.
  - A wrong **deny** emits `LAW_PERMIT_WRONGLY_DENIED` (PUBLIC, responsible AUTHORITY 0.5 / GOVERNMENT 0.5). From M6 it is appealable.
  - A wrong **grant** emits `LAW_PERMIT_WRONGLY_GRANTED` (SECRET; revealed if an accident or inspection hits that facility).
- **Government instruction on an individual case** (`INSTRUCT_AUTHORITY_DECISION`) is unlawful under §8.

---

## 11. M6 outline: courts, regulators, fines (numbers)

### 11.1 Institutions at M6 start (created by `CL_INSTITUTION` or by the transition)

| Institution | Start size | Capacity per unit | Budget lever (default) |
|---|---|---|---|
| General court | 3 judges | `4 + 4·LAW/100` case-points (cp)/month per judge (≈6.8) | `LAW_COURT_BUDGET` 3 W_ref/judge/month |
| Administrative chamber | 2 judges | same | same lever, split by size |
| Inspectorate (workplace + environment, one agency in v1) | 4 inspectors (aggregate count, not Persons) | 3 inspections/month each | `LAW_INSPECTORATE_BUDGET` 2 W_ref/inspector/month |

- **Funding:** effective capacity = nominal × `min(1, budget / required)`.
- **Growth:** the actions `LAW_HIRE_JUDGE` (6-month lag, from a merit shortlist of 3 Persons with LAW 60–85) and `LAW_SET_INSPECTORATE_SIZE` (3-month lag).
- **Judges cannot be dismissed by the government.** They retire at 70.
- **Judges and inspectors are capacity bought with budget.** They are not drawn from econ's labor pool (closes review Q14).

### 11.2 Case generation and throughput

| Case type | cp | Generated when | Filing probability |
|---|---|---|---|
| Administrative appeal (permit/licence) | 3 | Deny decision | Company AI files if `P̂(win)·value > cost`. Base ≈ 0.25 of denials |
| Appeal of unlawful gov action | 6 | `LAW_UNLAWFUL_GOV_ACTION` affecting a company/party | 0.5/month once known to the victim |
| Contract dispute | 5 | Delay > 3 months or non-payment (econ fact) | 0.3 |
| Regulatory enforcement | 4 | Violation detected (§11.4) with SERIOUS+ class | 1.0 (MINOR → warning, no case) |

- **Processing:** FIFO per court. Each month the court spends its capacity on the oldest cases.
- **Duration:** expected ≈ `(backlog_cp + own_cp) / capacity`.
- **Target at 2,000 population:** 3–8 new cases/month, which is ≈ 25 cp against 34 cp capacity, so the court is stable.
- **Litigation cost:** 1 W_ref per cp, split per party.

### 11.3 Verdict model (seeded, RNG stream `law.verdict`; closes review Q6)
- **Ground truth:** `truth ∈ {0,1}` comes from the Fact store (violation or unlawful act occurred). The court never reads it directly.
- **Evidence** is generated from truth. Each item has reliability r:
  - truth = 1: `n ~ 1 + Poisson(1.5)` items with `r ~ U[0.4, 0.9]`
  - truth = 0: `n ~ Poisson(0.7)` items with `r ~ U[0.0, 0.3]`
  - Government action records for `PROHIBITED`-override facts: 1 item, r = 0.9
- **Strength:** `S = 1 − Π(1 − r_i)`
- **Win probability:** `P(claimant/state wins) = 1 / (1 + exp(−(S − θ)/w))`
  - θ = 0.5 (civil/administrative, balance of probabilities). Criminal θ = 0.85, post-v1.
  - `w = 0.12 − 0.06·LAW_judge/100`: better judges give a sharper, more predictable outcome.
- **Settlement:** each party estimates P with noise σ = 0.1. They settle if `|P̂_a − P̂_b| < 0.15` and both expected values beat continuing after cost. Settlement amount = mean(P̂)·claim.
- **Appeal:** 1 level (administrative chamber → general court bench of 3). The losing party appeals if `P̂(win) > 0.4`. Appeal cp = 4.

### 11.4 Regulators and detection
- **Inspection probability:** per regulated entity per month, `p_insp = min(1, inspections / regulated_entities × risk)`. risk = 1, ×2 with a prior violation, ×1.5 with a complaint.
- **Detection:** `p_find | inspected = 0.6 + 0.3·Q_agency/100`. Q_agency defaults to 60, or comes from an assigned `STAFF_SD_LEGAL` standing duty.
- **Other channels:** whistleblower 0.01/month per violation. An accident reveals with p = 1.
- **On detection:** `COMP_VIOLATION` SECRET → `LAW_VIOLATION_REVEALED`.

**This is the evidence-vs-truth hook: underfunding the inspectorate lowers the number of *revealed* violations without changing the true ones (J §16.5).**

### 11.5 Fines and remedies through the ledger (closes review gap #33)

| Class | Fine | Additional |
|---|---|---|
| MINOR | Warning first; repeat within 24 months → 1% of trailing-12-month revenue, min 2 W_ref | — |
| SERIOUS | 4% of revenue, min 10 W_ref | Compliance order; 3-month correction window |
| SEVERE | 10% of revenue, min 30 W_ref | Licence suspension 3 months |

- **Scale:** all fines × lever `LAW_FINE_SCALE` (LAW, default 1.0, range 0.25–4.0).
- **Ledger:** company cash → treasury account `FINES_REVENUE` (econ Rule 4). If cash is insufficient, the remainder becomes a liability owed to the government and feeds econ's insolvency machine (X9).
- **Compensation** (contract and administrative wins): respondent → claimant, through the ledger.
- **Overturned government action:**
  - Effects revert: the lever goes back to its lawful value and permit status is restored.
  - The government pays the claimant's litigation cost plus proven loss.
  - `LAW_RULING` is emitted (PUBLIC, responsible GOVERNMENT 1.0 for an against-government ruling).

### 11.6 Government compliance with rulings
Compliance is automatic in v1/M6: rulings execute. Non-compliance and "institutional crisis" are post-v1. This keeps the player from ignoring courts without paying.

---

## 12. Scope table (what is in v1, closes review Q5)

| Feature (J §) | v1 | When |
|---|---|---|
| Legal hierarchy, rule grammar, engine (§4, §28) | ✅ | M3 (engine stubs used by drafting) → M6 full |
| Charter, ordinances, transition (§3) | ✅ | M3 data, M6 rules |
| Clause → rule/lever (§21) | ✅ | **M3** (legislation needs it) |
| Licences/permits, permit office (§12.3, §16) | ✅ | M6 (stubbed "always granted" before) |
| Unlawful gov action + reveal (§28.3) | ✅ | M6 |
| Courts, admin appeals, contract disputes, inspectorate, fines (§6–9, §13, §16) | ✅ | M6 second half |
| Constitution amendment *procedure* | data only | post-v1 for player use |
| Criminal law, police, prosecution, detention (§14–15) | ❌ | post-v1 |
| Corruption cases (§19) | ❌ | post-v1 (integrity stat already generated) |
| Emergency powers (§20) | ❌ | post-v1. **The commander has no emergency powers in v1.** |
| Constitutional review (§5.2) | ❌ | post-v1 |
| Media law, alcohol, corporate/insolvency/competition procedure, labor courts (§10, §11, §17, §18) | ❌ | post-v1 (insolvency stays econ's machine, X9) |

---

## 13. GDScript sketch (shape only)

```gdscript
# game/sim/law/rules_engine.gd
class_name RulesEngine extends RefCounted

enum Result { AUTHORIZED, WITH_CONDITIONS, REQUIRES_APPROVAL, PROHIBITED, DISPUTED, INSUFFICIENT_INFO }
const PUBLIC_KINDS := ["COMMANDER", "GOVERNMENT", "AUTHORITY"]

var _by_action: Dictionary = {}   # LegalActionType -> Array[Dictionary] (active rules)

func validate(actor: Dictionary, action: String, params: Dictionary, world) -> Dictionary:
    var ctx := {"actor": actor, "p": params, "world": world}
    var matched: Array = []
    for r in _by_action.get(action, []) + _by_action.get("*", []):
        if _all(r.subject, ctx) and _all(r.where, ctx) and not _any(r.unless, ctx):
            matched.append(r)
    var top := _resolve_precedence(matched)        # level > specificity > month > supersedes
    var is_public := PUBLIC_KINDS.has(actor.kind)
    # ... PROHIBIT wins / public default-deny / collect REQUIRE → missing licences
    return {"result": Result.AUTHORIZED, "trace": [], "missing": []}
```

---

## 14. Acceptance tests (subset of J §31, re-targeted)

| # | Test | Pass |
|---|---|---|
| LT1 | Commander ordinance sets a COMMANDER lever | AUTHORIZED; impl task created; operative after task + lag |
| LT2 | Commander tries `POSTPONE_ELECTION` past month 48 | PROHIBITED by a charter rule; trace shows it |
| LT3 | First government formed | Charter → constitution; ordinances deemed statutes with identical lever values; the commander can no longer set levers |
| LT4 | Government sets a LAW lever by regulation without delegation | PROHIBITED. With `CL_DELEGATE` in range: AUTHORIZED. Out of range: PROHIBITED |
| LT5 | Company operates a HIGH-hazard plant without a licence | WITH_CONDITIONS[HAZARD]; violation fact SECRET |
| LT6 | Player overrides a PROHIBITED action | Executes; SECRET fact; with a seeded leak, REVEALED within expected months; `LAW_RULE_OF_LAW` drops |
| LT7 | Repeal before implementation completes | Implementation cancelled; operative value never changed |
| LT8 | (M6) Court backlog 3× capacity | Duration rises linearly; no case lost; save/load mid-case identical |
| LT9 | (M6) Fine larger than the company's cash | Remainder becomes a liability; ledger balances |
| LT10 | Equality check | A clause targeting `actor.id` for PROHIBIT can't be drafted (validation error) |

---

## 15. Kernel alignment (game/README.md rules, M1 API)

- **State:**
  - `WorldState` tables: `legal_rule`, `instrument`, `lever_change` (pending/legal/operative + schedule), `licence`, `permit_application`, `institution`, and in M6 `case` and `evidence`.
  - The charter and clause templates are data: `game/data/law/charter.json`, `clauses.json`, `actions.json`.
  - `LawProvider extends PicProvider` is stateless. It runs in `DECISIONS` (validate; compile clauses; apply scheduled lever effects due this month) and `JUSTICE` (discovery, permits, indicators, M6 cases).
- **The lever pipeline is owned by law:**
  - Law calls `world.define_lever` for law-owned levers.
  - For **all** levers, law keeps the `lever_change` records.
  - In `DECISIONS` of month m, law applies every scheduled operative change with `effective_operative_month == m` into `world.levers`, then emits `<OWNER>_LEVER_EFFECTIVE`.
  - Owners only *read* `world.levers`.
  - **Wilma please confirm:** this makes law the single writer of operative lever values (rule 8).
- **Integers:** percentages are stored in basis points, money in milli-W_ref → converted to credits via econ's W_ref at use time, and probabilities in per-mille in data files.
- **RNG streams:**

  | Stream | Used for |
  |---|---|
  | `law.discovery` | Leaks, complaints, whistleblowers |
  | `law.permits` | Wrong grant/deny |
  | `law.verdict` | Evidence generation, verdicts, settlement noise (M6) |
  | `law.inspect` | Inspections (M6) |

- **Reveals:** `world.facts.reveal(month, secret_fact_id, [revealer])` produces the `*_REVEALED` fact (pic-core §4).
- **Tests per README rule 10:** LT1–LT10, plus determinism and a save/load round-trip with pending lever changes and an open permit queue.
