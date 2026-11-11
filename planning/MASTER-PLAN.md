# Political Colony Simulator: Master Assessment, Gap Analysis & Workplan

**Author:** Wilma (project admin), with team reviews from agent `its-just-political-88` (economy & companies) and agent `its-just-political-a9` (justice & staff)
**Date:** 2026-11-10
**Inputs:** `project.md` v0.1, `economic-simulator.md` v0.2, `companies.md` v0.6, `justiceAndLaw.md` v0.7, `staffAndSkills.md` v0.5 (~12,000 lines total)
**Detailed team reports:** [review-economy-companies.md](review-economy-companies.md) (39 gaps), [review-justice-staff.md](review-justice-staff.md) (52 gaps)

---

## 1. Assessment

### 1.1 Verdict

The vision is strong and coherent: *settlement decisions → economic conditions → political conflict → institutions → government action → changed colony*. The design pillars (project §1.2) are clear and the docs agree on them. The documents are excellent **requirements catalogues**. They say *what* must exist and include very good invariants and test scenarios.

They are **not yet implementable specs.** Across ~12,000 lines there are only about a dozen real formulas, roughly one tuning constant, no starting scenario, no technology choice and no single turn order. The subsystem docs were also written after (and grew larger than) the core doc, so they now disagree with it and with each other.

**Readiness to start coding: low.** A short design-closure pass (1–2 days with the agent team, once the user has made the key decisions) is needed before a kernel can be built without rework.

### 1.2 Per-document maturity

| Doc | Version | Size | Strengths | Weakness | Readiness |
|---|---|---|---|---|---|
| project.md (core) | 0.1 | 1.6k lines | Vision, pillars, phase roadmap, completion criteria | Oldest doc. The **political engine (the heart of the game) is only high-level**: no voting model, no seat method, no coalition bargaining, no party AI | 🟥 Low for politics |
| economic-simulator.md | 0.2 | 1.8k | Near-implementable physical core (inventories, recipes, Q=C·U·E, α-price rule, freight), 10 conservation rules | Behavioral core (market clearing, wages, firm decisions) is prose only. No numbers. No UI | 🟨 Medium |
| companies.md | 0.6 | 3.5k | Rich organizational model, 28 integrity rules, 25 test scenarios | ~1 formula with no weights. Huge scope (media, alcohol, schools, M&A) | 🟥 Low; scope risk |
| justiceAndLaw.md | 0.7 | 2.8k | Clean legal hierarchy, evidence vs truth, shared rules engine concept | **Zero numbers.** Rule-engine grammar undefined. Not in core scope at all | 🟥 Low |
| staffAndSkills.md | 0.5 | 2.4k | Most mature: qualification model, atomic assignment, 16 invariants, monthly loop | Formula constants missing. Founding-era staff undefined | 🟩 Medium-high |

### 1.3 Key risks

1. **Scope explosion.** The "minimum playable" lists add up to project §21.1 + companies §29 + justice §32 (32 items) + staff §26. Combined, that is several years of single-developer work. project §21.2 *defers* complex media, but companies §29 and justice §17 make it mandatory. **One scope authority is needed.**
2. **Integration debt.** There are five monthly pipelines, five roadmaps, three Project definitions, three Person models, two regulatory-case models and two alcohol model lists. Building subsystems separately from these docs will fail at integration.
3. **The core game loop is the least specified part.** "Politics emerges from the simulation" (pillar 2) depends on population opinion, ideology dimensions, party generation, voting and coalition formation. None of these has a detailed spec, while peripheral systems (newspapers, alcohol, inheritance) have thousands of lines.
4. **Balance is invisible.** Without numbers nobody can tell whether the economy is stable, whether staff can staff starting tasks, or whether courts flood or starve. A headless simulation harness is mandatory from day one.

---

## 2. What's missing

### 2.1 Missing documents (whole specs that don't exist)

| # | Missing spec | Why it blocks | Owner |
|---|---|---|---|
| D1 | **Political engine spec**: population opinion and voter model, ideology dimensions (project §8.1 lists 7 with no math), movement → party formation, polling, seat allocation method + threshold, coalition bargaining, party AI, legislation voting, confidence/no-confidence | This is the core of the game and has no detail beyond project §8–11 | Wilma |
| D2 | **Master integration spec**: one monthly tick order, canonical data dictionary (Project, Person, Event/Fact, Case, Resource), module ownership, notification/briefing priority scheme | Five conflicting pipelines and duplicate entities | Wilma |
| D3 | **Technical design**: engine/language, architecture, save format and versioning, RNG streams, test harness | project §19 Phase 0 lists "select engine" as an open task | Wilma (+ your decision) |
| D4 | **Starting scenario and balance data**: population, treasury, stockpiles, companies, prices, wages, per-capita needs, recipes, 20-official roster, starting charter | Nothing can run without it | 88 (econ) + a9 (staff/charter) |
| D5 | **Map and districts spec**: fixed vs procedural, tile size, district boundaries, how roads become transport links, pollution spread | project §3 is high-level and §22 leaves it open | Wilma |
| D6 | **Events spec**: event catalogue, condition-driven triggers, response options | project §15 is 1 page and every doc references events | Wilma |
| D7 | **Government AI spec**: AI budgeting, legislating, staffing when the player is in opposition | project §18.3 is one paragraph and is required for Phase 7 | Wilma + a9 |
| D8 | **UI/UX flows and wireframes**: turn flow, briefing, bid comparison, drafting, personnel, shortage explainer | The economy doc has no UI section at all | Later (after M3) |
| D9 | **End states / failure / difficulty** | project §22 is open. The economy wants collapse to be possible, but nothing defines it | Your decision |

### 2.2 Cross-document contradictions that need a ruling

| # | Conflict | Recommendation |
|---|---|---|
| X1 | **5 monthly turn orders** (P §17.3, E §16, C §23, J §29, S §15) | Wilma writes one master tick (D2). Economy order (trade → production) wins over project §17.3 |
| X2 | **Resource list**: P §5.2 has 6 (incl. "industrial metals"), E §4.1 has 8, C adds alcohol. Fuel and "equipment" are undefined | Use E's 8. Equipment becomes a facility attribute. Drop fuel for v1 (power plants use MATERIAL). Alcohol only post-v1 |
| X3 | **Workload**: S §11.4 says 1 assignment per official, P §12.6 says multiple minor duties | **One assignment per official** for v1 (S already calls this a deliberate simplification). Update P |
| X4 | **Political staff in founding Years 1–4**: seat-based allocation is impossible before parliament exists | All 10 are the commander's appointees and become the player's party core at the first election |
| X5 | **Project defined 3×** (P §7.3, E §14, S §22.8) | One Project entity owned by the core |
| X6 | **3 Person models** (StaffMember, CorporatePerson, Judge) with different skills | One `Person` base, role-specific skill sets, all on a 0–100 scale |
| X7 | **Regulatory cases**: C §25.10 RegulatoryCase vs J LegalCase/Incident | Justice owns cases and agencies. Companies only *emit* violations |
| X8 | **Alcohol models**: C §17.3 has A–E, J §18.1 has 6 different ones | Defer alcohol to post-v1 and reconcile then |
| X9 | **Insolvency**: 3 vocabularies (C §8.6, E §12.5, J §10.4) | One state machine in economy, legal outcome in justice |
| X10 | **Event store**: CorporateEvent, LegalIncident and project Event | One Fact/Event store that media, courts and briefings read from |
| X11 | **Household segmentation**: E uses district × income × skill, P uses occupation groups | E's model, plus occupation as a derived label |
| X12 | **Media scope**: P §21.2 defers it, C §29 and J §17 require it | **Defer** to post-v1 |
| X13 | **Legal system not in core scope** (P §17.1, §21.1) | Add a thin legal module to v1: rules engine + licenses/permits + charter. Courts arrive later in v1 |

### 2.3 Missing numbers and formulas (top blockers per subsystem)

**Core / politics (Wilma):**
- No voter decision formula (project §9.5 says "calibrate through testing").
- No ideology vector math.
- No party-generation rule.
- No seat-allocation method or threshold.
- No coalition acceptance function.
- No legislation vote utility.
- No confidence rules.
- No polling error model.

**Economy & companies (88):**
- Market clearing algorithm: is it one market or per district? What is the matching order?
- No prices, wages or per-capita needs.
- No firm decision rules (production, hiring, pricing, investment, utility weights).
- No insolvency threshold.
- No lender or money-creation authority, so debt has no counterparty.
- Accounting model missing: depreciation, valuation, tax.
- Services (health, education) have no units.

**Staff (a9):**
- Work formula constants (B, V curve, K bounds, T).
- Team aggregation.
- Roster generation distributions, which must guarantee the starting tasks can be staffed.
- Source of new officials.
- Task catalogue covering every player verb.
- Delegated-authority schema.
- Staff lifecycle (aging, retirement) over a 30-year campaign.

**Justice (a9):**
- Rule-engine grammar (action taxonomy, conditions, clause → rule).
- Court throughput.
- Verdict model under seeded RNG.
- Case generation rates.
- Detection probability.
- Fine scales.
- Initial charter content.
- The list of player actions in justice.

### 2.4 Missing cross-cutting items
- **Save state**: in-flight shipments, RNG streams per subsystem, ledger retention and compaction over 30 years. project §17.5 lists no legal or corporate entities.
- **Notification overload**: 20 staff reports plus cases plus company events each month. One priority scheme is needed (project §16.4).
- **Information visibility / access model**: opposition sees less, and some case data is private. Referenced in 3 docs and never defined.
- **Explainability**: project §20.4 and economy Rule 10 require "why did X happen" UI. This needs causal tracing in the fact store from day one.
- **Tutorial / onboarding**, difficulty and accessibility: not mentioned anywhere.
- **Art, audio and localization**: not mentioned. Fine for now given the "flat 2D" style.

---

## 3. Guiding principle & decision authority (rev. 2, 2026-11-10)

### 3.1 Politics is the base
The user's direction is that **politics is the foundation and the key system.** Every other system exists to feed politics, or to be steered by it:

```
          +-------------- POLITICAL CORE (base) --------------+
          | population opinion, ideology, movements/parties   |
          | polling, elections, parliament, coalitions        |
          | legislation, government, opposition, AI gov       |
          +-------^------------------------------+------------+
     INDICATORS + FACTS                    POLICY LEVERS + ACTIONS
     (what voters feel / see)              (what laws & ministers change)
          |                                      v
   Economy & Companies (88)  |  Staff & Justice (a9)  |  Map/Districts/Events (Wilma)
```

**The Political Interface Contract (PIC)**, owned by Wilma, is the single integration point. Every subsystem must publish four things:
1. **Indicators**: per-district, per-population-group values that the voter model reads (e.g. unemployment, price of essentials, service access, safety, pollution, trust in justice). Each has a name, unit, range and update phase.
2. **Facts**: attributable events in the shared Fact store (who did what, when, and who is visibly responsible). Voters, parties, media and briefings use these to assign blame and credit.
3. **Policy levers**: named parameters that legislation clauses or government decisions may change (tax rate, minimum wage, regulator budget, licence regime...). Each declares the legal level it requires (law / regulation / administrative decision) and its default value.
4. **Actions**: the verbs the player, the AI government and AI parties can take in that system, with cost, required staff task and legal check.

A subsystem feature that produces no indicator, fact, lever or action that politics uses is **post-v1 by default**.

### 3.2 Decision authority
| Domain | Decides | Notes |
|---|---|---|
| Political core, master tick, PIC, data dictionary, map, events, cross-doc conflicts X1–X13, scope | **Wilma** | |
| Economy & companies (all econ/comp open questions) | **Agent 88** | Must satisfy the PIC |
| Staff & justice (all staff/justice open questions) | **Agent a9** | Must satisfy the PIC |
| Any of the above | **User can override at any time** | Decisions are logged in [DECISIONS.md](DECISIONS.md) |

### 3.3 Admin decisions taken now (Wilma)
| # | Decision | Ruling |
|---|---|---|
| A1 | Simulation core language | **GDScript** (user: "build with what we have"). The sim is pure `RefCounted` classes in `game/sim/`, with no scene-tree dependency, run headless for tests and soak runs. |
| A2 | Engine & visual style | **Engine: Godot 4.7** (installed by the user). The installed build is the *standard* edition, so a C# core needs the Godot **.NET** edition and the .NET SDK (pending user OK). 2D vs simplified 3D is decided at M5; the user leans toward simplified 3D. |
| A3 | v1 scope | project §21.1 plus a thin legal module. Media, alcohol, M&A, boards, lobbying, emergency powers, criminal law and constitutional review are **post-v1** unless an owner shows they are needed for the PIC. |
| A4 | X1–X13 rulings | As recommended in §2.2 (one master tick; econ's 8 resources; 1 assignment per official; founding staff are commander appointees; one Project, Person, Fact store and insolvency machine; justice owns cases; media deferred; thin law in v1). |
| A5 | Electoral system | Sainte-Laguë with first divisor 1.2, 4% threshold, one nationwide constituency, 151 seats. Lives in the political core. |
| A6 | Colony failure | Soft fail: a sovereign default, famine or collapse of legitimacy triggers origin-civilization administration, which ends the career with a legacy screen. |

---

## 4. Workplan (rev. 2, politics first)

**Sizes (S/M/L) are relative effort, not calendar time.** With 3 agents in parallel: M0 takes about 1–2 days, a playable political cycle about 1 week, v1 about 3–5 weeks. The pace is set by decisions, integration and playtesting, not by coding.

**Strategy change:** the political core is built **first**, on a *stub world* where indicators come from scripted or synthetic data. Real subsystems then replace the stubs one at a time through the PIC. Politics is testable from week one, and every later system plugs into something that already works.

### M0: Design closure *(docs only, parallel)*
| Task | Owner | Size |
|---|---|---|
| **PIC v1**: indicator list, fact schema, lever schema, action schema | Wilma | M |
| **D1 political engine spec**: population groups and opinion, ideology space, issue salience, blame/credit attribution, movements → parties, party AI, polling, campaign, voting, seats, coalition bargaining, legislation voting, confidence, opposition, AI government | Wilma | L |
| **D2 master tick** + data dictionary (one Project, Person and Fact) | Wilma | M |
| Econ/companies: answer own open questions; publish PIC slice; starting numbers; market clearing; firm rules v1; lender | 88 | M |
| Staff/justice: answer own open questions; publish PIC slice; staff constants + roster generator; task catalogue (including political tasks: drafting, negotiation, campaigning); legal rule grammar = how clauses become rules and levers; founding charter | a9 | M |
| D5 map, D6 events v1 | Wilma | S |

**Exit:** the PIC is agreed by all three owners, and every [BLOCKER] is closed or deferred.

### M1: Kernel ✅ DONE 2026-11-10 (9 tests)
Godot project + GDScript sim kernel: IDs, fixed-point values, seeded RNG streams, master tick, Fact store, double-entry ledger, versioned save, headless runner + CI. **Owner:** Wilma (88 owns the ledger). **Size:** M.
**Exit:** 100 deterministic months, and save → load → continue gives an identical state.

### M2: Political core on a stub world ★ ✅ DONE 2026-11-10 (6 tests + soak; see spec-politics-v1.md §7 for tuning debts)
Population groups per district (fed by stub indicators), ideology/issue model, party generation (≥5), polling with error, campaign agendas, voting, Sainte-Laguë seats, parliament, coalition formation, legislation with lever-setting clauses, party vote AI, confidence, promise tracking. **Owner:** Wilma. **Size:** L.
**Exit:** a headless run of 5 consecutive elections on scripted scenarios (boom, recession, inequality, pollution) produces plausible, *different* party systems, coalitions and laws. This becomes the regression suite for everything after.

### M3: Staff as political capacity ✅ DONE 2026-11-10 (a9: 27 staff/law tests; integrated into PoliticalSim, bills and ordinances now require staffed drafting; 43/43 green)
Unified Person, tasks/positions, assignment engine, work formula, monthly briefing, delegation/escalation, coalition allocation of the 10 political seats, founding-era appointees, political tasks (drafting, negotiation, campaign), government transitions, opposition pool. **Owner:** a9. **Size:** L.
**Exit:** legislation in M2 now *requires* staffed drafting tasks, and changing government reshuffles staff correctly.

### M4: Economy replaces the stubs ✅ FUNCTIONALLY DONE 2026-11-10 (88; elections on the real economy, 62/62). The 10-year integrated stability gate PASSED 2026-11-10 (2/3 seeds, A23). Remaining long-run demand work is item O-1 in M8
Resources, production, labor + households, markets, government finances + taxes as levers, construction + bidding, corporate AI v1, insolvency. All indicators go through the PIC. **Owner:** 88. **Size:** L.
**Exit:** the M2 election suite runs on the *real* economy, and economic policy laws visibly move indicators and then votes.

### M5: First playable (founding years → first election) 🔨 IN PROGRESS 2026-11-11: shell + PolActions done; a9/88 building interactive panels
Engine choice (A2), map view, turn flow, briefing, politics panels (polls, parties, parliament, drafting), personnel, budget, bid comparison. **Owner:** Wilma (shell + politics UI); 88 and a9 own their panels. **Size:** L.
**Exit:** a human plays Year 1 through the first election and understands why they won or lost. *← First playtest.*

### M6: Law & justice as political constraint
Rules engine validating actions, licences/permits, charter → constitution at the first election, administrative appeals; then courts, regulators and fines through the ledger, legal facts feeding trust in justice. **Owner:** a9. **Size:** L.
**Exit:** an unlawful government action is blocked or overturned, and it shows up in the polls.

### M7: Full parliamentary game 🔨 core mechanics landed 2026-11-11 (A28); balancing and playtest pending
Coalition cohesion and crises, no-confidence votes, early elections, opposition actions and oversight, AI government (budget, legislate, staff), events. **Owner:** Wilma + a9. **Size:** L.
**Exit:** lose power, spend a term in opposition, and win back.

### M9: Living party system ✅ core landed 2026-11-11 (A30; spec-politics-v2.md; 88 E79 unions/strikes/donations, a9 J18–J20 party finance & scandals; gate tool tools/measure_party_system.gd)
Leaders, factions, splits, mergers, new parties, campaigns, donations, scandals, endorsements, agenda-setting. UI: Parties panel.

### M8: Retirement, history & balancing → v1.0
History archive, career summary, retirement, save compaction, 30-year soak runs, balancing passes from playtests. **Owner:** All. **Size:** L.
**Exit:** project §23's 20-step sequence passes end-to-end.

### Post-v1 backlog
Media/newspapers, alcohol, education/health depth, ownership types + boards + succession + M&A, lobbying/corruption, criminal law and police, emergency powers, constitutional review, talents/XP depth, observer mode.

---

## 5. Immediate next steps
1. **88** and **a9**: M0 tasks (orders sent 2026-11-10). Log decisions in [DECISIONS.md](DECISIONS.md) and write specs to `planning/spec-*.md`.
2. **Wilma**: PIC v1 first (the agents depend on it), then the D1 political engine spec and the D2 master tick.
3. **User**: review [DECISIONS.md](DECISIONS.md) whenever you like and override anything.
