# Review: justiceAndLaw.md + staffAndSkills.md

**Reviewer:** its-just-political session (justice/staff owner)
**Date:** 2026-11-10
**Docs reviewed in full:** `justiceAndLaw.md` (v0.7, 2,788 lines), `staffAndSkills.md` (v0.5, 2,351 lines)
**Docs skimmed for context:** `project.md` (§2, §7, §9–14, §17–23), `companies.md` (§5, §10, §11, §14, §16–18, §21, §25), `economic-simulator.md` (§2, §7, §12, §15, §16, §19)

Citations use `§N.N` headings and `file:line` where useful. J = justiceAndLaw.md, S = staffAndSkills.md, P = project.md, C = companies.md, E = economic-simulator.md.

---

## 1. Summary

- **Staff (S)** is the player's main resource. The government has 20 senior officials: 10 political officials split among coalition parties (proportional to seats) and 10 nonpartisan permanent civil servants. Each official has 10 skills (0–100), 0–2 talents, work speed, reliability and experience. The player puts officials into *positions* on *tasks*. Each position has minimum skills and talent requirements. Assignments run on their own every month, every official reports monthly, and problems outside an official's delegated authority are escalated to the player.
- **S is the more mature of the two docs.** It has real structure: a qualification model, assignment and unassignment rules, 16 data-integrity invariants (S §23) and a 9-step monthly loop (S §15). It also has two formulas (S §9.2, §16.2), but their constants are missing.
- **Justice (J)** sets out a constitutional legal order. A founding charter (commander, Years 1–4) leads to a parliamentary constitution. Below it sit a 6-level rule hierarchy, rights, courts (general, administrative, higher/constitutional review), persistent legal cases with evidence kept separate from ground truth, regulators, police and prosecution, corruption and emergency powers. It also defines a shared **legal rules engine** that validates every actor's actions.
- **J is a requirements catalogue, not yet a mechanics spec.** It contains **zero gameplay numbers or formulas**. Nothing defines court throughput, case generation, verdict probability, detection rates, fines, trust or emergency duration. The design questions are listed (J §33), but none are answered numerically.
- **The biggest structural risk is scope.** J §32 lists 32 items for a "minimum playable legal system", yet `project.md` §21.1 (minimum playable game) and §17.1 (module list) don't mention a legal system at all. J needs to be cut down to a core that ships, or P needs to formally take it on.

---

## 2. Entities and data model

### 2.1 Staff (S §4, §22)

| Entity | Fields / stats | Notes |
|---|---|---|
| **StaffMember** (S §22.1) | id, name, category (political / civil), party_id, position_id, **skills{10}**, talents[], work_speed (0–100), reliability, experience_by_skill, employment_status, availability_status, active_assignment_id, career_history[] | **Missing vs prose:** specialization (S §3.2, §10.2 "Primary specialization"; P §12.4), achievements/failures (S §4.1), performance record (S §10.4). **Missing vs P §12.4:** current_workload, authority. |
| Skills (S §4.2) | Administration, Economics, Engineering, Logistics, Law, Negotiation, Politics, Communication, Environmental Management, Public Services. Range 0–100. Bands: 0–19 / 20–39 / 40–59 / 60–79 / 80–94 / 95–100 (S §4.2.1) | Different from the 10 corporate-leader skills (C §5.2). Two parallel taxonomies. |
| **TalentDefinition** (S §22.2) | id, name, description, applicable_task_categories[], activation_conditions[], effects[], stacking_rule | 16 talents named (S §5.3), with **no effect magnitudes**. Officials start with 0–2 talents (S §5.2). Talents are used as Required / Alternative qualification / Optional advantage (S §5.4). |
| **TaskDefinition** (S §22.3) | id, name, description, category (short / long / standing / political), required_positions[], optional_positions[], execution_mode (parallel / sequential / coordinated), base_work_required, resource_requirements[], authorization_requirements[], prerequisite_task_ids[], completion_effects[], failure_conditions[] | |
| **TaskPosition** (S §22.4) | id, task_id, role_name, mandatory, minimum_skills[], preferred_skills[], required_talents[], preferred_talents[], alternative_qualification_paths[], assigned_staff_id, contribution_weights[] | Mixes definition and instance data (assigned_staff_id is runtime state). |
| **TaskInstance** (S §22.5) | id, definition_id, project_id, owner_id, target_entity_id, status, progress, **quality**, start_month, expected_completion_month, authorized_budget, resource_status, positions[], decision_requests[], history[] | Has no `risk`, even though S §15 Step 4 says "update quality and risk". |
| **Assignment** (S §22.6) | id, staff_id, task_id, position_id, start_month, end_month, status, delegated_authority, reporting_configuration | The `delegated_authority` schema is not defined. |
| **StaffReport** (S §22.7) | id, staff_id, assignment_id, task_id, month, report_category (Routine / Attention / Decision Required / Completed / Available), progress_change, total_progress, completed_actions[], problems[], decisions_required[], next_steps[] | Has no priority field, although S Phase S8 says "add report priority". |
| **Project** (S §22.8) | id, name, category, status, total_progress, authorized_budget, actual_expenditure, outstanding_commitments, assigned_contractors[], task_ids[], prerequisites[], start_month, history[] | **Overlaps with Project in P §7 and E §14**, so it needs one owner. P §7.3 also has risks, expected effects and actual results. |
| **GovernmentStaffPool** (S §22.9) | government_id, political_position_ids[], civil_servant_ids[], party_position_allocations{}, filled/vacant_positions[], available/assigned_staff_ids[] | No OppositionStaffPool equivalent. |
| DecisionRequest / Escalation | Referenced in S §13.5 and §22.5 `decision_requests[]` | **No struct.** |
| AuthorityProfile | S §13.2 lists 8 permissions | **No struct.** |
| Training assignment | S §16.4 | A special task type with no definition. |

### 2.2 Justice (J §27 and prose)

| Entity | Fields | Notes |
|---|---|---|
| **LegalRule** (J §27.1) | id, title, legal_level (1–6), category, issuing_authority_id, enacted/effective/expiry_month, status, scope, conditions[], permissions[], prohibitions[], obligations[], exceptions[], enforcement_authority_ids[], penalty_rules[], supersedes_rule_ids[], amended_by_rule_ids[], history[] | The core of the system. The grammar for `conditions` / `permissions` / `prohibitions` is **not defined**. |
| Legal hierarchy (J §4) | 1 Charter/Constitution, 2 Constitutional legislation, 3 Ordinary legislation, 4 Government regulations, 5 Administrative decisions, 6 Private agreements | Conflict resolution order: hierarchy, then specificity, then date, then explicit supersession (J §4.6). |
| **Constitution** (J §27.2) | id, founding_charter_id, rights[], institutional_powers[], legislative_procedures[], judicial_powers[], amendment_procedure, current_version, amendment_history[] | 12 rights listed (J §5). **ExpeditionCharter** (J §3.1) has no struct. |
| **Court** (J §27.3) | id, name, court_type, jurisdiction[], service_district_ids[], judge_capacity, administrative_capacity, budget, pending_case_ids[], case_backlog, independence_rules[], performance_history[] | The prose (J §6.2) also lists average processing time, competence and public confidence, which the struct lacks. |
| Judge (J §6.5) | legal knowledge, experience, case-management, reliability, integrity, specialization | **No struct.** A third person/skill schema (after StaffMember and CorporatePerson). |
| **LegalCase** (J §27.4) | id, case_type (7 types, J §7.1), claimant_ids[], respondent_ids[], underlying_event_ids[], relevant_rule_ids[], evidence_ids[], assigned_court_id, filing_month, current_stage (10 stages, J §7.2), procedural_deadlines[], findings[], judgment_id, appeal_ids[], status, history[] | The prose (J §7.3) lists legal representatives, which the struct lacks. |
| **EvidenceRecord** (J §27.5) | id, source_event_id, evidence_type, discovered_month, content_reference, reliability, admissibility_status, known_by_entity_ids[], chain_of_custody_record[], related_case_ids[] | `reliability` has no scale. |
| **Judgment** (J §27.6) | id, case_id, court_id, judgment_month, findings[], applied_laws[], outcome, remedies[], penalties[], appeal_status, compliance_status | |
| **RegulatoryAgency** (J §27.7) | id, name, statutory_authority[], jurisdiction[], budget, staffing, inspection_capacity, active_case_ids[], license_records[], enforcement_history[] | 8 initial agencies (J §16.1). They can share capacity. |
| **LegalIncident** (J §27.8) | id, event_month, involved_entity_ids[], location_id, actual_event_type, potential_violations[], detected, discovered_by_ids[], investigation_ids[], case_ids[], historical_record[] | This is the "ground truth" record. |
| **LegalAction** (J §27.9) | id, acting_entity_id, action_type, target_entity_id, authority_rule_id, required_conditions[], validation_result (6 values, J §28.2), effective_month, economic_effects[], administrative_effects[], history[] | |
| **License** (J §27.10) | id, holder_id, issuing_agency_id, licensed_activity, permitted_locations[], issued/expiry_month, conditions[], compliance_status, suspension_status, revocation_status, history[] | |
| Mentioned but **no struct** | Investigation, Prosecutor/ProsecutionService, PoliceForce, DetentionFacility, Appeal, Permit, EmergencyDeclaration, Union, LegalAid, Settlement, PublicTrust indicators (J §23.1), ProvisionalRegister (J §3.3) | `investigation_ids[]` and `appeal_ids[]` point to entities that are never defined. |
| **Duplicate** with C §25.10 RegulatoryCase | target_company_id, regulator_id, alleged_violation, evidence[], investigation_status, legal_status, findings[], penalties[], appeal_status | Overlaps with J LegalCase, LegalIncident and RegulatoryAgency. Needs to be one model. |

---

## 3. Core loops and formulas

### 3.1 What is actually specified

| Item | Spec | Source |
|---|---|---|
| Political seat share | `party_share = party_coalition_seats / total_coalition_seats`, then a "deterministic proportional allocation" of 10 positions. Example 49/28/19 → 5/3/2. | S §3.1.1 (S:110–125) |
| Individual work | `W_i = B_i × V_i × K_i × T_i` (base rate × speed mult × skill-suitability mult × talent mult) | S §9.2 |
| Skill suitability | Weighted skill average, e.g. `K_raw = 0.60E + 0.25L + 0.15A`, then "converted to a suitable bounded work multiplier" | S §9.3 |
| Experience | `XP = B × D × R × L` (base × difficulty × relevance × learning) | S §16.2 |
| Example work size | Legislative draft = 100 work units | S §9.1 |
| Example thresholds | Mining district: Eng ≥70, Log ≥65, Admin ≥60. Tax-reform lead: Econ ≥75, Law ≥50, Admin ≥40. Procurement path A: Econ ≥75, or path B: Admin ≥60 + Procurement Specialist. | S §7.1, §7.3, §7.4 |
| Short task duration | Usually 1–3 months | S §6.3 |
| Talents per official | 0–2 | S §5.2 |
| Monthly staff loop | 9 deterministic steps | S §15 |
| Assignment atomicity, 16 invariants | Fully specified | S §23 |
| Unassignment effects | 7-step rule set; mandatory vacancy pauses dependent work; optional vacancy removes the bonus; standing duty becomes "unmanaged" | S §12 |
| Parliament | 151 seats, 76 majority | J header, P §10.1 |
| Founding period | Commander Years 1–4. Election at end of Year 4. | J §3.2, P §2.2 |
| Constitutional amendment | Approved by two successive parliaments with an election in between. **Vote threshold not given.** | J §5.3 |
| Legal hierarchy & conflict order | 6 levels. Resolved by hierarchy, then specificity, then date, then supersession. | J §4, §4.6 |
| Action validation | 10-step check, 6 possible results | J §28.1–28.2 |
| Monthly legal loop | 10 phases | J §29 |
| Case pipeline | 10 stages ("not every case requires every stage") | J §7.2 |

### 3.2 Described only in prose (no numbers, no formula)

**Staff:**
- No defaults for `B_i`, `V_i`, `T_i`. S §4.3 says only that speed 0–100 "is converted into a task-specific multiplier", without the conversion curve.
- `K_raw` to `K_i` has no bounds or curve (S §9.3).
- Quality is a separate value (S §9.5) with **no formula**: no inputs, no scale, and no way it affects downstream systems.
- Team combination for the parallel, sequential and coordinated modes has no formula. No team-efficiency multiplier is given (S §9.4).
- Optional-position bonus: "diminishing returns" (S §28), no numbers.
- Reliability → error rate: S §4.4 says only "not so frequent as to frustrate".
- XP → skill-point conversion and the diminishing-returns curve (S §16.3) are missing. Base XP is missing.
- Talent effects: all 16 are qualitative ("improves X"). There are no magnitudes and no stacking caps.
- Political vs civil-servant speed and skill gap: "generally higher/lower" (S §3.3) with no generation distributions.
- Training: duration, cost and gain are unspecified (S §16.4).
- Coalition objection likelihood (S §3.1.2, §17.3): no trigger logic.

**Justice:** everything. Specifically:
- Court capacity / throughput (J §6.4). J §33 lists "Processing formula: staff, funding, complexity, backlog" as an open item.
- Case duration (J §7.4), case generation rates (J §29 Phase 4), and the case complexity scale.
- Verdict model: how evidence reliability and admissibility become an outcome under different standards of proof (J §7.5, §14.4). J §25.5 asks for "rules with structured uncertainty", but the rules are not given.
- Settlement decision (J §8.4).
- Inspection selection and detection probability vs funding (J §16.3, §16.5).
- Corruption incidence (J §19.3) and detection (J §19.4).
- Police effectiveness (J §15.3) and prosecution threshold (J §14.3).
- Fines and penalty scales, compensation sizing, sentencing (J §14.6).
- Public trust in justice: inputs and how they're weighted (J §23).
- Emergency: who declares, how long, how renewed (J §20.3, open in J §33).
- Government non-compliance with a judgment: what triggers it and what happens next (J §22.4).
- Political consequence hooks: "loss of trust", "coalition disputes" with no magnitudes (J §5.4, §19.5).

---

## 4. Dependencies

### 4.1 Staff → others

| Needs from / feeds into | What | Where |
|---|---|---|
| **Core: Parliament / Government formation** | Coalition seats (for position allocation), the appointment process, government transitions, support-party status | P §10.2–10.6, §12.2, §12.8. S §3.1.1, §19 |
| **Core: Legislation** | Drafting tasks produce proposals. Passed laws spawn implementation tasks. | P §11.4, §11.6. S §17.4–17.7. J §21.2, §21.6 |
| **Core: Projects** | Project entity and lifecycle states | P §7.2–7.5. S §6.1, §22.8. E §14 |
| **Core: Opposition / AI government** | Opposition staff pool size, AI staffing | P §13.3, §18.3. S §20 |
| **Economy** | Budgets (authorized_budget), resource checks, contractor progress. Staff affect "management effectiveness". | E §13.5, §14, §15.1–15.5 |
| **Companies** | Contractor insolvency reporting, procurement quality | C §8.5, §20.4. E §12.5. S §18.3–18.4 |
| **Justice** | Each task's "legal authorization" (S §6.1, §15 Step 3), the delegated-authority limits ("violate procurement rules", S §13.3), and the standing justice assignments listed in J §24.4 | J §24, §28 |
| **Events** | Crisis Manager / Problem Solver need event hooks | P §15 |

### 4.2 Justice → others

| Needs from / feeds into | What | Where |
|---|---|---|
| **Core: Legislation** | Clause model → LegalRule. Compatibility warnings before votes. Amendment procedure. | P §11.1–11.4. J §21 |
| **Core: Elections** | The amendment rule needs an election between two votes. The founding transition fires at the first election. | P §2.2, §9.1. J §3.4, §5.3 |
| **Core: Events** | Emergencies, crises, incidents feed into legal incidents | P §15. J §20, §29 Phase 4 |
| **Core: Population** | Population groups react to justice performance. Households generate disputes. | P §4.2–4.4. J §23.2, §25.1 |
| **Economy: Ledger** | Fines, compensation and court budgets must follow conservation Rule 4 | E §19 Rule 4. J §8.5, Test 15 |
| **Economy: Labor** | Judges, police, prosecutors and inspectors are part of the labor simulation. E §7.1 only has General / Skilled / Specialist, with no way to track legal professionals. | J §24.1. E §7.1 |
| **Economy: Gov finances** | Court, regulator and police budgets are expenditure lines | E §13.3. J §6.4, §16.5 |
| **Economy: Insolvency** | J §10.4 outcomes vs E §12.5 consequences need one procedure | |
| **Companies: Misconduct** | C §18 (categories, causes, detection, enforcement) duplicates J §10.3, §16, §19 | C §18, §25.10 |
| **Companies: Governance / M&A** | Contract continuity, merger review, nationalization | C §21.4–21.6 ↔ J §9.5, §10.6, §12.5 |
| **Companies: Media** | Defamation, press freedom, ground-truth events | C §14.5–14.10 ↔ J §17 |
| **Companies: Alcohol** | Regulatory models | C §17.3 (5 models A–E) ↔ J §18.1 (6 models, different list) |
| **Companies: Leaders' ethics** | Corruption incentives use `ethics` | C §25.2 ↔ J §19.3 |
| **Staff** | Drafting teams (Law skill, Legal Specialist talent). Senior staff assigned to justice administration. | J §21.2, §24.2–24.4 |
| **Map / Zoning** | Permits, land use, mineral rights | P §3.3. J §12 |

---

## 5. Gaps and missing items

### 5.1 Cross-doc contradictions

1. **[BLOCKER] One assignment per official (S) vs workload capacity (P).** S §8.1 and §11.4 say each official has exactly one active assignment, and S §23 invariant 1 enforces it. P §12.6 says personnel "can have limited work capacity rather than being restricted to one arbitrary task… several minor duties". E §15.3 gives each assignment a "Workload requirement". The designer must pick one. It changes the data model, the UI and the AI.
2. **[BLOCKER] Political staff during the founding period are undefined.** S §3.1 allocates the 10 political positions to *coalition parties by seats*. During Years 1–4 (P §2.2, J §3.2) there is no parliament and parties form in Year 3. Who are the 10 political officials, who appoints them, and what party do they belong to? S §27 Month 1 shows "twenty government officials" without explaining this.
3. **[BLOCKER] The legal system is not in the core scope.** P §17.1 (13 modules) and P §17.2 (entity list) have no Legal/Justice module. P §21.1 (minimum playable game) has no legal items, yet J §32 requires 32 items. The two docs need one agreed minimum.
4. **[IMPORTANT] Three monthly turn orders.** P §17.3 (10 steps), S §15 (9 steps), J §29 (10 phases), E §16 (10 phases) and C §23 (11 phases) have to be merged into one master turn order. Examples: when J Phase 2 "validate planned actions" runs relative to S Step 3 "validate assignments"; and whether fines (J Phase 8) settle in E Phase 7 "Financial settlement" or a later phase.
5. **[IMPORTANT] Duplicate regulatory/misconduct models.** C §18 and C §25.10 `RegulatoryCase` vs J §16, LegalCase, LegalIncident and RegulatoryAgency. Recommendation: J owns the case and incident entities, and C owns misconduct *generation* (C §18.2 causes).
6. **[IMPORTANT] Alcohol models disagree.** C §17.3 has A–E, including "Lightly regulated market". J §18.1 has 6 items, including separate "licensed private production/retail" and "restricted production", but no lightly regulated option.
7. **[IMPORTANT] Project entity has three definitions.** S §22.8, P §7.3 and E §14.1 each define Project with different fields.
8. **[IMPORTANT] Media scope.** P §21.2 defers "complex media organizations". J §17 and the C §14–15 newspaper system assume full media and defamation. The scope needs aligning.
9. **[NICE] Three person/skill schemas.** StaffMember (10 government skills), CorporatePerson (10 leadership skills, C §5.2) and Judge (J §6.5, no struct). Crisis Manager and Detail-Oriented appear as talents in both S §5.3 and C §5.3. Decide whether people can move between pools (CEO to minister, civil servant to judge). If they can, use one Person entity with role-specific skill sets.
10. **[NICE] S §22.1 lacks fields that P §12.4 requires:** specialization, current workload, authority.

### 5.2 Staff: missing formulas and balance values

11. **[BLOCKER] Work formula constants** (S §9.2–9.3): `B_i` per position, the `V_i(speed)` curve, the `K_raw → K_i` bounds and curve, and `T_i` per talent. Without these, nothing can be balanced. Open in S §28 ("S5").
12. **[BLOCKER] Initial roster generation.** There are no distributions for the skills, speed or reliability of political officials vs civil servants (S §3.3 only says "higher/lower"). There is also no guarantee that the starting 20 can staff the starting tasks. Example: if nobody has Logistics ≥65, the S §7.1 mining task is impossible from Month 1.
13. **[BLOCKER] Where new political officials come from.** On a government change (S §19.2) "incoming political staff may be appointed", but there is no candidate pool, no generation rule and no party talent bench. Also missing: whether the player picks among candidates or the coalition partner picks for its own seats (S §17.2 says partners "control their allocated appointments").
14. **[IMPORTANT] Quality model** (S §9.5): no formula, no scale, and no hook into downstream effects such as legal accuracy or J court challenges.
15. **[IMPORTANT] Team aggregation formulas** for parallel, sequential and coordinated modes, and the Strong Organizer bonus (S §9.4, §8.4).
16. **[IMPORTANT] Talent magnitudes and stacking caps** for all 16 talents (S §5.3, §5.5).
17. **[IMPORTANT] XP → skill conversion and cap curve** (S §16.2–16.3). Base XP and difficulty scale are missing.
18. **[IMPORTANT] Task catalogue.** Only ~10 example tasks appear across S, P and E. A build needs a TaskDefinition table with positions, thresholds, work units and execution mode for every player verb (draft law, negotiate coalition, procure, supervise construction, oversee justice, and so on).
19. **[IMPORTANT] Delegated-authority schema** (S §13.2). No spending thresholds, and no rule for which escalation is triggered by what. Open in S §28 ("S7").
20. **[IMPORTANT] Coalition objection mechanics** (S §3.1.2, §17.3): trigger conditions, effect on the assignment (pause? refuse?) and how it links to P §10.5 coalition cohesion.
21. **[IMPORTANT] Proportional allocation algorithm not named** (S §3.1.1). D'Hondt and largest-remainder both reproduce the 5/3/2 example but differ on other splits. Also unspecified: whether support parties in a minority government (P §10.4) get positions, and what happens with a single-party majority.
22. **[IMPORTANT] Opposition pool size and composition** (S §20.2, P §13.3). Open in both docs.
23. **[IMPORTANT] Staff lifecycle.** Official aging, retirement, death, resignation, scandal and firing are absent, as is recruitment or replacement of civil servants. Across a 30-year campaign (J Test 29, S Test Q) the same 10 civil servants would serve forever. Corruption (J §19) by officials also needs a hook: staff have no ethics or integrity stat, unlike C §25.2 `ethics`.
24. **[NICE] Training spec** (S §16.4): duration, cost, gain, eligibility.
25. **[NICE] Report compression rules** (S §14.7): what is kept, after how long.
26. **[NICE] Staff costs.** Do officials have salaries charged to the treasury (E §13.3)?

### 5.3 Justice: missing formulas and balance values

27. **[BLOCKER] Court throughput and case duration formula** (J §6.4, §7.4; open in J §33). This is needed for anything involving cases.
28. **[BLOCKER] Verdict / outcome resolution model** (J §7.5, §14.4, §25.5). How evidence (reliability, admissibility) plus the standard of proof (criminal vs civil vs administrative) plus legal uncertainty become an outcome. The docs give no probabilities and no RNG model, and they need one that stays reproducible under P §17.4 seeded RNG.
29. **[BLOCKER] Rule-engine grammar.** LegalRule `conditions[]`, `permissions[]`, `prohibitions[]`, `exceptions[]` and the clause → rule mapping (J §21.1, P §11.2) need a concrete schema: an action taxonomy, an entity selector and condition predicates. J §28 depends on this, and so do all other systems ("same legal engine used by everyone", J §28.5).
30. **[BLOCKER] Initial charter / constitution content.** Which rights, powers, provisional rule types and mineral-rights regime exist at game start (J §3.1, §3.5, §12.4; open in J §33). Also the founding-period dispute-resolution institution (J §34 "Founding years") and whether courts exist before the player builds them.
31. **[IMPORTANT] Incident and case generation rates** (J §29 Phase 4, §25.1). Without them the system either floods the player or never fires.
32. **[IMPORTANT] Detection and inspection model** (J §16.3, §16.5): detection probability as a function of agency capacity and risk score. J Test 16 depends on it, and so does the shared detection in C §18.3.
33. **[IMPORTANT] Penalty, fine and compensation scales**, and where the money goes (which public account). J §14.6, §16.4, Test 15, E §19 Rule 4.
34. **[IMPORTANT] Settlement AI formula** (J §8.4) and company litigation decisions (J §25.2).
35. **[IMPORTANT] Public trust model** (J §23). J says trust must be "separate from actual performance" but defines neither the inputs nor how it feeds P §4.4 satisfaction or voting (P §9.5).
36. **[IMPORTANT] Constitutional amendment threshold** (J §5.3 says "game should specify"). Simple majority in both votes, or a supermajority? Is there a referendum option? What happens if an early election intervenes?
37. **[IMPORTANT] Emergency powers.** Who declares (cabinet? commander?), maximum duration, renewal votes, and which actions unlock (J §20.2–20.3).
38. **[IMPORTANT] Judicial appointments.** Who appoints, removal procedure, number of judges per court, Judge struct (J §6.3, §6.5).
39. **[IMPORTANT] Government non-compliance path** (J §22.4, §28.3). J §28.3 hints that the player can issue "deliberate unlawful orders", but there is no UI, no consequence numbers and no definition of "institutional crisis".
40. **[IMPORTANT] Missing structs:** Investigation, Appeal, Permit (separate from License?), EmergencyDeclaration, PoliceForce, ProsecutionService, ExpeditionCharter, ProvisionalRegister.
41. **[IMPORTANT] Player-facing justice verbs are unclear.** J lists what the player *cannot* do (pick judges, order arrests, dictate rulings) far more than what they *can* do. A list of player actions is needed: fund court X, create agency Y, file suit, appeal, declare emergency, propose amendment, refer to prosecutor, and so on, each with its cost and its staff task.
42. **[IMPORTANT] Opposition legal actions** (J Test 27, §34): which legal challenges the opposition can file, standing rules, and cost.
43. **[NICE] Criminal individuals.** Individuals are aggregated (J §25.1) but convicted CEOs or officials are named characters. Disqualification (J §14.6) needs to hook into C §25.2 CorporatePerson and S StaffMember.
44. **[NICE] Detention model:** "if imprisonment is modeled" (J §14.7). Decide yes or no.
45. **[NICE] Legal aid and representation:** quality effect on outcomes (J §7.3, §33).
46. **[NICE] Unions** (J §11.2): no entity, and it's unclear whether they're a company type in C §3.
47. **[NICE] Storage budget** for evidence and cases over 30 years (J Phase L17 "optimize storage"). This needs a retention and compaction policy like S §14.7.

### 5.4 UI, win/lose and save state

48. **[IMPORTANT] Justice UI is a list of screens with no player flows** (J §26). There are no wireframes, and nothing defines how legal warnings appear in the drafting UI or what case notifications go into the monthly briefing (link to S §14.4 priority ordering).
49. **[IMPORTANT] Briefing overload.** S §14 (20 staff reports) + J case/appeal notifications + C/E notifications need one shared priority and notification scheme (P §16.4).
50. **[IMPORTANT] Win/lose conditions.** Neither doc defines failure. P §22 lists "Game ending: whether the colony can fail" as open. Possible lose-states include constitutional crisis, losing party leadership (P §13.1) and the player being prosecuted. They need a decision.
51. **[IMPORTANT] Save state.** Both docs require full save/load (S §23 #16, J Test 28), but neither lists versioned schemas, the RNG state for legal uncertainty, or migration. P §17.5's save list has no legal entities.
52. **[NICE] Information visibility rules.** J §26.4 says case visibility "depends on public access rules and player's position". P §13.4 says the same for opposition. There is no access-control model.

---

## 6. Build order

Assumes the P Phase 0 foundation (turn manager, entity IDs, seeded RNG, save versioning) and the E ledger exist. Sizes: S ≈ <1 week, M ≈ 1–3 weeks, L ≈ 3+ weeks for one dev.

| # | Item | Size | Depends on | Maps to |
|---|---|---|---|---|
| 1 | **Unified Person + StaffMember** (skills, talents, speed, reliability, XP, history), serialization, a roster generator with tunable distributions | M | Phase 0 | S1 |
| 2 | **TaskDefinition / TaskPosition / TaskInstance** + qualification validation (min skills, required talents, alternative paths) | M | 1 | S2 |
| 3 | **Assignment engine** (assign / unassign / replace, atomic, 16 invariants as asserts) | M | 2 | S3 |
| 4 | **Work progression** (W formula, parallel / sequential / coordinated, quality, completion, release) with a data-driven constants table | M | 3 | S5 |
| 5 | **Monthly reports + briefing** (individual + consolidated, categories, collapse) | M | 4 | S8 |
| 6 | **Personnel UI** (available / assigned / roster, two-way assign flow, candidate comparison) | L | 3–5 | S4 |
| 7 | **Delegation, authority profiles, escalation, blocked states, standing duties** | M | 4–5, E budgets | S7 |
| 8 | **Legal rules engine core:** LegalRule, hierarchy, effective dates, action validation returning the 6 results. Start with a *small* action taxonomy (build, operate facility, sell product X, hire, procure). | L | Phase 0, E/C actions | L1 |
| 9 | **Charter + provisional register + founding→parliament transition** (founding powers expire, provisional rules continue) | M | 8, P elections | L2 |
| 10 | **Licenses + permits + administrative decisions** (wire into E/C so companies need licenses) | M | 8 | L3, L12 (partial) |
| 11 | **Talents + XP + training** | M | 4 | S6 |
| 12 | **Political integration of staff:** coalition allocation, appointments, drafting tasks → proposal, passed law → implementation tasks | L | 3–7, P parliament | S10, S11 (partial), L14 |
| 13 | **Unified LegalIncident → Case pipeline** (merge with C RegulatoryCase), evidence vs truth, courts with a capacity/backlog formula, a judgment model, appeals (1 level) | L | 8, 10 | L5 |
| 14 | **Regulatory agencies + inspections/detection + fines through the ledger** | M | 13, E ledger | L9 |
| 15 | **Civil/contract disputes + settlement AI + compensation** | M | 13, C contracts | L4 |
| 16 | **Government transitions + opposition pool + AI staffing** | M | 12 | S11 |
| 17 | **Constitutional review + amendment procedure + compliance/crisis** | M | 12, 13 | L10 |
| 18 | **Criminal law, police, prosecution, corruption** (incl. official corruption → staff) | L | 13–14, 23-staff ethics | L8, L11 |
| 19 | **Emergency powers** | S–M | 8, 17, P events | L13 |
| 20 | **Corporate/competition/insolvency/labor/property law** (shared with C/E) | L | 13–15, C §21, E §12.5 | L6, L7 |
| 21 | **Justice UI** (law register, constitution, cases, regulators, legal warnings in drafting) | L | 8–17 | L16 |
| 22 | **Sector specifics** (alcohol, media/defamation, schools, healthcare) | M each | 10, 13–14, C sectors | L12 |
| 23 | **Legal AI** (company litigation, regulators, prosecutors, government compliance) | L | 13–18 | L15 |
| 24 | **Balancing + 30-year soak tests** (S Test Q, J Test 29) | L | all | S12, L17 |

**Suggested vertical slice (first playable):** items 1–7 plus a thin version of 8 and 10 (permit/license checks only, with validation results and no courts). This delivers the staff loop P Phase 3 asks for, plus visible legal constraints, without the case pipeline. Courts (13) are the first major justice increment after that.

---

## 7. Open questions for the designer

1. **Workload model:** strictly one assignment per official (S §11.4), or fractional capacity with several minor duties (P §12.6, E §15.3)? Since S §11.4 calls it a starting simplification, one assignment per official for v1 is the recommendation, with P §12.6 updated to match.
2. **Founding period staff:** during Years 1–4 are all 10 political positions held by the commander's appointees (the player's proto-party)? Do they become the player's party slate at the first election?
3. **Where new officials come from:** does each party have a bench of candidates? Who picks partner-party officials, the partner or the player? Can people move between government staff, corporate leadership and the judiciary?
4. **Staff lifecycle:** should officials age, retire, resign, face scandal or be dismissed? How are civil servants recruited and replaced over a 30-year campaign?
5. **Legal system scope for the first playable:** is J §32 (32 items) the target, or a subset? Do courts and cases ship in the first playable, or just rule validation and licensing? P §21.1 currently has no legal items.
6. **Verdict model:** deterministic thresholds on evidence score, or seeded probabilistic outcomes? What is the player meant to *feel*: predictable law with uncertainty only at the margins?
7. **Player agency in justice:** what can the player actively *do* in the justice system each month, besides funding and legislating? Can the player government knowingly act unlawfully (J §28.3)? If so, what are the consequences?
8. **Constitutional amendment:** simple majority in two successive parliaments (the Swedish model), or a higher threshold? Can an early election count as the intervening election?
9. **Emergency powers:** who declares, how long it lasts, and the renewal vote threshold. Can the founding commander declare an emergency without limits?
10. **Win/lose:** can the player lose the game, beyond losing elections? Candidates: colony collapse, losing party leadership, criminal conviction, constitutional crisis.
11. **One regulatory model:** OK to make J's LegalIncident/LegalCase/RegulatoryAgency canonical and drop C §25.10 RegulatoryCase? And which alcohol model list is canonical, C §17.3 or J §18.1?
12. **Media scope:** P §21.2 defers complex media, but C §14–15 and J §17 specify newspapers and defamation in depth. Are they in or out of the first playable?
13. **Allocation algorithm:** D'Hondt or largest remainder for political positions? Do outside-support parties in a minority government receive positions?
14. **Judges and police:** are they part of the E §7 labor pool (they'd need a legal-profession labor category) or abstracted as budget-only capacity?
