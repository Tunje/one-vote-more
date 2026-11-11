# UI Data Contract: Staff & Law (M5)

**Owner:** a9 · **Date:** 2026-11-10 · **For:** Wilma's Godot shell (M5 first playable)
**Code:** `game/sim/staff/staff_query.gd` (SQ), `game/sim/law/law_query.gd` (LQ), `game/sim/staff/staff_law_actions.gd` (A)
**Tests:** `game/tests/staff/test_ui_queries.gd` (purity: every query leaves `state_hash()` unchanged)

## 0. Rules for the UI

1. **Reads** are static functions on `SQ` / `LQ`. They are pure: they never create tables or change state. Call them as often as you like, e.g. every frame or on hover.
2. **Writes** go through exactly one function:
   ```gdscript
   const A := preload("res://sim/staff/staff_law_actions.gd")
   var res: Dictionary = A.apply(world, {"id": "STAFF_ASSIGN", "actor": {"kind": "GOVERNMENT", "id": "government"},
       "args": {"task_id": tid, "pos": 0, "person_id": pid}})
   # res = {ok: bool, error?: String, ...extra}
   ```
   - Writes apply **immediately** during the planning phase. Every call, successful or not, is logged in `world.table("action_log")`, which gives a replay and audit trail. The same entry point serves the player and the AI (pic-core §6).
   - `A.ACTION_DEFS` (also returned by both providers' `action_defs()`) lists every action with its pic-core §6 fields and argument names.
3. **Actors:**
   - `{"kind": "GOVERNMENT"}` (also used by the commander in the founding era) runs the government's staff: civil servants plus political seats.
   - `{"kind": "PARTY", "id": pid}` runs that party's staff: its opposition or formation pool, plus its own officials in government when doing party work.
4. `error` strings are **player-readable** and can be shown verbatim (e.g. "civil servants cannot do party-political work", "refused: conflicts with P2 core commitment", "does not meet qualifications").
5. Numbers in views are already UI units: percentages 0–100, quality 0–100, months. Raw milli-units only appear inside `outputs`.

---

## 1. (a) Personnel screen

| Function | Returns | Reads |
|---|---|---|
| `SQ.summary(world, owner) -> Dictionary` | `{total, available, assigned, vacant_seats, mandatory_vacancies, decisions}`: the header strip (S §10.1) | person, task, gov_seat, decision_request |
| `SQ.roster(world, owner) -> Array[PersonView]` | Everyone who can work for `owner`, **available first** | person, assignment, task |
| `SQ.person_view(world, pid) -> PersonView` | `{id, name, age, category: CIVIL_SERVANT/POLITICAL/PARTY_STAFF, party_id, specialization, skills{10}, talents[], work_speed, reliability, status: ACTIVE/UNAVAILABLE/…, pool, available: bool, assignment: {task_id, def_id, task_name, pos, role, start_month, task_progress_pct} or {}, career[]}` | person, assignment, task |
| `SQ.tasks(world, owner, include_closed=false) -> Array[TaskView]` | The owner's tasks | task |
| `SQ.task_view(world, tid) -> TaskView` | `{id, def_id, name, category, mode, preset, status, paused, blocked, owner, progress_pct, quality, coverage_pct, effectiveness_pct, stage, stages, positions: [{idx, role, mandatory, assigned, assigned_name, requirements}], outputs, start_month, source_bill, target}`. `requirements` is text such as "LAW ≥ 50 or LAW ≥ 35 + Legal Specialist". | task, person, decision_request |
| `SQ.open_positions(world, owner) -> Array` | `[{task_id, task_name, pos, role, mandatory, requirements}]`, for the **Official → select task** workflow | task |
| `SQ.candidates(world, tid, pos) -> Array` | Candidate comparison (S §10.7): `[{person_id, name, eligible, reason, path, suitability, est_work, est_quality, talent_matches[], coalition: ""/"KEEN"/"RELUCTANT"/"REFUSES", currently}]`. **Eligible first, then highest estimated work.** This is the **Task → select official** workflow. `reason` explains ineligibility. | person, task, party, pol |
| `SQ.seats(world) -> Array` | Government political seats `[{seat_id, party_id, person_id, name}]` | gov_seat, person |
| `SQ.bench(world, party_id) -> Array[PersonView]` | Who a party can appoint | person |
| `SQ.recruitments(world) -> Array` | Open civil-service vacancies `[{id, spec, opened_month, picked, hire_month, shortlist: [{name, skills, talents, work_speed, reliability}]}]` | recruitment |

**Actions:**

| Action id | args | Typical errors |
|---|---|---|
| `STAFF_ASSIGN` | `task_id, pos, person_id` | "person already assigned", "position occupied", "does not meet qualifications", "civil servants cannot do party-political work", "refused: conflicts with … core commitment", "not your task" |
| `STAFF_UNASSIGN` | `person_id` | "not assigned", "not your staff" |
| `STAFF_REPLACE` | `task_id, pos, person_id` (atomic swap) | as assign |
| `STAFF_START_TASK` | `def_id, params` | "caretaker government cannot start new political tasks", "X cannot be run by PARTY" |
| `STAFF_CANCEL_TASK` | `task_id` | implementation tasks cannot be cancelled here |
| `STAFF_SET_TASK_MODE` | `task_id, mode: RUSH/NORMAL/CAREFUL` | |
| `STAFF_SET_AUTHORITY_PRESET` | `task_id, preset: TIGHT/STANDARD/BROAD` | |
| `STAFF_APPOINT_POLITICAL` | `seat_id, person_id` | "this seat belongs to another party", "not on this party's bench" |
| `STAFF_DISMISS_POLITICAL` | `person_id` | "you can only dismiss your own party's officials" (civil servants: never) |
| `STAFF_SET_RECRUITMENT_SPEC` / `STAFF_HIRE_CIVIL_SERVANT` | `recruitment_id, spec` / `recruitment_id, candidate` (0–2) | "only the government recruits civil servants" |
| `STAFF_TRAIN` | `person_id, skill` | "skill already at training cap" |

---

## 2. (b) Monthly briefing

| Function | Returns | Reads |
|---|---|---|
| `SQ.briefing(world, owner, month=-1) -> Dictionary` | For the month just simulated (default `world.month − 1`): `{month, items, decisions, tasks, summary}`. `items` is `[{priority, category, label, staff_id, task_id, text, progress_change, problems[], collapsed}]`, sorted **by priority** (DECISION_REQUIRED 90 > COMPLETED 60 > ATTENTION 50 > ROUTINE 10 > AVAILABLE 5). `collapsed: true` for routine/available (S §14.4). `decisions` is the open decision list. `tasks` are consolidated TaskViews. | staff_report, person, task, decision_request |
| `SQ.decision_requests(world, owner) -> Array[DecisionView]` | `[{id, task_id, kind, month, text, options: [{id, label, recommended}]}]` | decision_request, task |
| `SQ.report_text(world, report) -> String` | e.g. "Ada Berg on Supervise: work paused: a mandatory position is vacant." | |

**Action:** `STAFF_ANSWER_DECISION` with `request_id, option`. A blocked task resumes next month.

---

## 3. (c) Drafting flow and decrees

**Flow:** pick levers → preview → request drafting → watch progress → submit (politics) → enacted → implementation → effective.

| Step | Function | Returns | Reads |
|---|---|---|---|
| 1. Pick | `LQ.lever_catalog(world, level="") -> Array` | Every lever: `{id, owner, type, range, values, default, operative, legal, legal_level, founding_era, ideology{}, implementation, lag, pending: {enactment, status, value} or {}, changeable, why_not}`. `level` defaults to ORDINANCE in the founding era and LAW after. | lever_defs, levers, enactment, legal_rule |
| 2. Preview | `LQ.preview_clauses(world, [{lever, to}], level="") -> Dictionary` | `{ok, level, clauses: [{lever, from, to, errors[], ideology{axis: shift}, implementation, lag, pending}], ideology{axis: total}, drafting: {task, work_wu, domain, second_policy_lead_required}}`. Show `errors` per clause; `ok` must be true to continue. | same |
| 3. Request | **Action** `STAFF_REQUEST_DRAFTING` with `bill_id, clauses` | `{ok, id: task_id}`. Rejected if any clause fails the legal check (returns the preview). Politics creates `bill_id` (A14). | |
| 4. Progress | `LQ.drafting_status(world, bill_id) -> Dictionary` | `{exists, task_id, status, progress_pct, staffed, positions[], draft_quality, ready}`. Staff the positions via §1. | task |
| 5. Submit | **Politics** (`POL_PROPOSE_BILL` / ordinance), with `source_bill = bill_id` | Then law's pipeline takes over. | |
| 6. Track | `LQ.enactments(world, include_final=false) -> Array` | `[{id, lever, from, to, level, status: PENDING/LEGAL/SCHEDULED/EFFECTIVE/REJECTED/CANCELLED, source_bill, legal_month, due_month, effective_month, errors, unlawful, deemed_statute, implementation: {task_id, progress_pct, status, staffed}}]`. "Enacted, not implemented" is visible here. | enactment, task |

**Decrees (government decision without parliament, parliamentary era only):**

| Function / action | Notes |
|---|---|
| `LQ.decree_check(world, lever, value) -> {allowed, lawful, level, result, warning, errors[], trace?}` | `lawful: true` means the lever is ADMIN-level, REGULATION-level, or a LAW-level lever that a law delegates (within bounds). `allowed: true, lawful: false` means **unlawful but possible**: show `warning` and require explicit confirmation. `allowed: false` means impossible (out of range, charter bound, founding era). |
| **Action** `LAW_DECREE` with `lever, value, confirm_unlawful=false[, burdened, executor, penalty_class]` | Lawful: `{ok, enactment, lawful: true}`. Unlawful without confirmation: `{ok: false, needs_confirmation: true, warning}`. With confirmation: `{ok, enactment, lawful: false}`. That records a SECRET `LAW_UNLAWFUL_GOV_ACTION`; the change is then implemented like any decision. |

**Warning text (`LQ.DECREE_WARNING`):**
> This decree is UNLAWFUL: only parliament can change LAW_EXTRACTION_ROYALTY (a LAW-level lever). If you proceed it will be implemented like any decision, but it is recorded as a secret unlawful act. It can leak from the civil service (about 3% a month), be exposed by an opposition inquiry, or be challenged in court by those it harms. If it comes out, voters punish the government (governance), the rule-of-law index falls, and a court will very likely overturn it.

Other: **action** `LAW_RESTART_IMPLEMENTATION` with `source_bill` re-creates stalled implementation tasks.

---

## 4. (d) Law register, constitution, courts

| Function | Returns | Reads |
|---|---|---|
| `LQ.law_register(world, filter={level?, status?, action?}) -> Array` | Rules, highest level first: `{id, level, kind, action, status, source, right, effective_month, text}`. `text` is generated English, e.g. "Commander, government, authority may not postpone election." | legal_rule |
| `LQ.rule_view(world, rid) -> Dictionary` | One rule (as above) | legal_rule |
| `LQ.constitution_view(world) -> Dictionary` | `{era, document: "EXPEDITION CHARTER"/"CONSTITUTION", adopted_month, rights[RuleView], powers[RuleView], charter_bounds[{lever, bounds}], amendment (text), rules_version}` | law_state, legal_rule |
| `LQ.cases(world, open_only=true) -> Array` | `[{id, type, court, claimant, respondent (display names), status, filed_month, progress_pct, expected_months, outcome, decided_month, is_appeal, against_government}]`. **Never exposes truth or evidence strength.** | case, court, judge, party, org |
| `LQ.courts(world) -> Array` | `[{id, kind, judges, capacity_cp, open_cases, backlog_cp, expected_wait_months}]` | court, judge, case |
| `LQ.permits(world, holder_id="") -> Array` | `[{id, holder, type, district, status, submitted_month, decided_month}]` | permit_application |

Indicators for the justice overview (`world.indicators`): `LAW_RULE_OF_LAW`, `LAW_TRUST_IN_JUSTICE` (voter cell), `LAW_PERMIT_WAIT` (district), `LAW_WORKPLACE_SAFETY` (district), `LAW_ENFORCEMENT_CONSISTENCY`, `LAW_COURT_DURATION`, `STAFF_DELIVERY_INDEX`. Facts for the news/briefing feed: see pic-staff-law.md §2.

---

## 5. D7 hooks for the AI government (and AI parties)

| Hook | Use |
|---|---|
| `StaffOps.auto_staff(world, owner)` | Runs automatically each DECISIONS phase for AI-controlled owners (and with autoplay). Mandatory positions are filled by **task priority**, then optional ones while ≥3 people stay free. If a mandatory slot can't be filled, it moves someone off a task at least 20 priority points lower (optional holders first), at most 2 moves per month. |
| `StaffOps.task_priority(task)` | `params.priority` if the creator set one. Otherwise by category: IMPLEMENTATION 70, POLITICAL 65, STANDING 60, PROJECT 50; +25 with a deadline, +15 if tied to a bill. **Politics AI: pass `params.priority` when it starts tasks to steer staffing.** |
| `LawQuery.decree_check(world, lever, value)` | Before an AI decree: `lawful` or not |
| `LawOps.unlawful_expected_cost(class, burdened, horizon)` | `{p_reveal, rule_of_law_drop, governance_impact, p_overturn_if_revealed}`. For a SERIOUS act against a burdened party over 24 months: p_reveal ≈ 0.95, a 20-point rule-of-law drop, and ~90% chance of being overturned. Put it in the AI utility as a large penalty term. |
| `LawQuery.preview_clauses(world, clauses)` | AI bill builders should drop clauses with `errors` before drafting. Otherwise the enactment is REJECTED after passage (`LAW_ENACTMENT_REJECTED`). |

## 6. Not in M5 (later)
- REGULATION-level decrees currently skip the drafting task (spec says `STAFF_T_DRAFT_ORDINANCE`). This will be added if playtests want it.
- Opposition legal challenges are an action (`STAFF_START_TASK` with `STAFF_T_LEGAL_CHALLENGE` and `params.target_fact`); the UI for choosing a target fact comes after M5.
- Visibility filtering for the opposition (OFFICIAL facts and indicators) is politics' access model. These queries return government-side data; filter by actor in the shell.
