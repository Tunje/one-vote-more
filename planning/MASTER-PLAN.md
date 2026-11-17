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

### ORDER, 2026-11-16: every producer gets all eight rules (the user, verbatim)
> "Then you can GO FUCKING BACK IN AND DAMNED WELL FUCKING MAKE IT SO!!! WE KEEP TRYING TO FIX ISSUES THAT THE EIGHT
> RULES FIX AND YOU KEEP BEING THE DAMNED PROBLEM"

Given after Wilma's table showed that no sector in v11 runs all eight (reeval-off-switches.md). The standing ruling
(2026-11-15): every producer has eight rules, each on a real market signal: raise its price, lower it, produce more,
produce less, add capacity, reduce capacity, when a new company starts, when not. This order overrides the feature
freeze for this work. Owners: Bob: mines, processing, components (rules 1/2), food and bread (1/2; families 1/2 and
5/6), workshops and medical works (all eight), freight (check all eight). Otto: builders and housing (all eight
working and fit to switch on). Ella: service hubs (all eight). Wilma: utilities, clinics, schools, administration (all
eight). Each rule reads the producer's own market (orders it can reach, unfilled orders, unsold stock, cost, use,
profit); no floors, caps or locks of our own. Done means: every row of the table in eight-rules.md shows eight rules
in the code, unit-tested, and one game run with all of them on.

**Ruling, same day (the user, verbatim), on who may found a power plant, clinic, school or haulier:** "All company
types needs to be able to be created as private, but maybe they're is only ever enough work for say one powerplant
then the conitions for new ones don't get switched on". So no company type is public-only by rule; rules 7 and 8
(when a new company starts, when not) decide, on the market. Follows from it (Wilma's reading): a private clinic,
school, power plant or haulier is paid for what it serves or carries, so it has price rules 1 and 2; the public ones
stay as they are. Still open with the user: whether public clinics and schools ever charge a fee; a client measure
for administration.

**The user, same day (verbatim), on rules that cannot take effect yet:** "AND WHEN I SAY THAT I DON'T MEAN REMOVE THE
DAMNED SWITCH FOR IT What if for example we run 500 years at that poinr there might be a need for another powerplant
On private holliers its easy build them as if they're could be a profit to base making new companies on, and to
reduce size on. They don't get skipped even if the rules won't be able to take affect because its free". So: no rule
is left out for any company type because its condition would not come true today. A second power plant's founding
rule exists and waits. Private hauliers are built with founding and shrinking on profit. Free services (clinics,
schools, care, administration) get their price rules too; they do nothing while the service is free.

**Three answers, same day (the user, verbatim):** "1. Yes they may order in, 2. I don't like hard rules you know that,
but maybe a soft it will sell less just took keep afloat, build up stock for better prices, that's if your have not
made everyone know all stocks at all times. 3. Schools and charge it's a bracket in taxes". The questions were:
1 may material and components come from the home world when the colony has no working producer; 2 may a seller
refuse to sell below its own cost; 3 do public clinics and schools ever charge. So: (1) material and components may
be ordered in from the home world. (2) No hard "never below cost" anywhere; a seller short of its cost may sell less
and build up stock for better prices, and that only works if the stock it holds back is not known to everyone, so
held-back stock must not count as supply in anyone's price reading. (3) What a school charges is a bracket in taxes,
not a fee at the door (Wilma's reading: the same shape for clinics and care unless the user says otherwise).

**On the brackets (the user, verbatim):** "Ah but per pulpe plus staff is how taxes for schools are calibrated Yea
they all get tax brackets". So the school bracket is calibrated per pupil plus staff, and clinics, care homes and
administration each get a tax bracket of their own in the same way.

**Hard limits (the user, verbatim, on hearing that at most six companies may be forming at once):** "A hard limit?"
Earlier the same day: "I don't like hard rules you know that". Wilma's order to every owner on that: list every
number of ours in your files that caps, floors, gates or times what a company, household or government may do (at
most N, never below, not before month M, once a year, after K months), say what market fact stands behind it, and
replace those that have none. The list goes in planning/hard-limits.md, by owner. Known so far: ENTRY_MAX_FORMING 6
and MAX_FORMING 3 (companies forming at once), a plan abandoned after 6 months without an active job, a firm
dissolved after 6 months in administration, the clients' wait limits (GOV_WAIT_M, PRIV_WAIT_BASE_M).

### ORDER, 2026-11-16, and the only work until it is done (the user, verbatim)
> "Okay new companies need the same suggar coating the farms and bakeries got for grants, and instead of reading the
> leftovers, they read an avrage of all avaliable jobs Focus only on this"

1. WITHDRAWN: Wilma read this as "every new company gets a grant like the family farms and bakeries" and ordered it
built. The user, an hour later: "WHAT THE FUCK NO I DID NOT SAY GIVE EVERYONE DUCKING GRANTS". No grant for new
companies is built. The user then said what was meant: "YOU SAID THERE WAS A LIMIT ON HOW MANY COMPANIES CAN FORM
THAT LIMIT REMOVE THAT LIMIT!!!! NO NOT THE GRANT PASSES ... JUST THE FUCKING MAX CAP ON HOW MANY TOTAL COMPANIES CAN
BE MADE". So the "sugar coating" is what the family farms and bakeries had just been given: they do not count
against the cap. Every new company gets the same: the cap on how many companies can be forming is removed, for all,
in every game. Nothing about grants changes.
2. A company deciding whether to start reads an average of all the available work (all jobs, all orders), not what
the existing firms left over.
Everything else waits: the hard-limits lists, the traces not needed for this, the re-evaluation screen's reading.

### The plan stage as the user designed it (verbatim, both dates)
2026-11-14: "I see it, you have made a misstake, a company that needs a building to exist would not start without the
building it would start when the building is finished, you can't fail before you exist, it would exist in a planning
stage no worker but also no expenses beyond building"
2026-11-16, on hearing that family farms "die" at 12 months while waiting for a builder, grant already taken: "But
then the plan Iis not what i designed PLANS ARE MADE BEFORE THEY BECOME COMPANIES DAMNED IT ALL THAT'S BEFORE
ACCEPTING A GRANT"
So: a plan is not a company. It has no workers and no expenses beyond the building. It cannot fail, because it does
not exist yet. It becomes a company when its building is finished. A grant is accepted after the plan, not before.
What the code does today, which is wrong by this: a family farm is created as a company in FORMING with its grant
approved at founding, counts as founded, and is dropped as "stalled" after 12 months without a build (6 months for
other plans), counted as a death.

**Price rule 2, the user's ruling (verbatim), after the recorder showed sellers at 3-4.7 times cost with goods piling
up:** "Now, instead, add a rule that the more inventory you have, the more you reduce your price. That way, the
further up they have in supplies, the more they reduce their price. That would solve this problem much faster. And
it would be a soft lock, not a hard lock, like your 9-month one would be." So: a seller's price cut grows with the
inventory it holds, continuously; no threshold of months or of any other kind.

**Builders' supplies, the user's ruling (verbatim):** "They should not need 90% of supplies up front they should need
3 months up front and add 1 month of additional supplies every month". So a builder starts a job with three months
of that job's supplies and adds one more month's supplies every month; it is not held to having 90% of its supplies.

**Imports are a backstop (the user, verbatim):** "Why put so much fucking emphasis on the imports? Why? We talked
about it as being a thing that was there if they needed it, not the primary means of getting resources." The
question the user had answered with "Yes they may order in" was: may material and components come from the home
world when the colony has no working producer. Wilma approved a wider build (any buyer short in any month whose
limit reached the landed price), which made imports routine: 14.7M paid out in 60 years. Corrected: ordering in only
while the colony has no working producer of the good.

**No word to the home world without a ship (the user, verbatim):** "Okay, let me explain something that you seem to
have completely bloody missed. They can't order when there's not a ship there to take the order. There is no magical
sending money through space without ships. They can't order, they can't ask for, they have to ask for one when the
ship is there, which means they have the full period of waiting every time. There's no ordering when it's 6 months
out because that ship's already left Earth and they have no way of sending a message to it." So every order, request
and payment to the home world is handed to a ship that is in port; the answer or the goods come back with that same
ship on its next call; a ship that calls in between left home before the message arrived. Every instance in the tree:
goods ordered in (ORDER_IN), the government's imports (ECON_ORDER_IMPORTS, which today arrive next quarter with no
ship), buses and parts bought from the home world, petitions and requests for more shipping (home_world.gd, done),
recapitalising the bank from home, builders and capital arriving from home.

**Decision, 2026-11-16 (the user, verbatim), after discussing tearing out and rebuilding the economy's decision
layer (about 11,000 of 23,731 lines) in a side copy from a written design:** "Lets work on the current build once we
have a functioning economy we will return to to this later". So: no rebuild and no side copy now. The work is to get
a functioning economy on the current code. The rebuild (one table of rules, one piece of code applying it, design
written and read first, no switches) is to be raised again once the economy functions.

**Only price moves price (the user, verbatim), on hearing that offers at the going price go unsold while buyers are
short, for some reason other than price:** "There is you fucking problem!!! If something else than price stops sales
it should not count on adjusting price!!" So a sale that did not happen for want of freight, of a road, or of the
buyer's money is not a price signal: it neither counts as unsold stock that lowers the price nor as an unfilled order
that raises it. Only goods that buyers would not take at the price, and orders that found no goods at the price,
move the price.

**What the hold-back sells (the user, verbatim), when told that a seller with cash offered nothing:** "No that's not true, it puts out to cover
its expences!!! It's not siposed to sit on stock and lose money on purpose hoping for a better price!!! It sells too
cover all monthly expences!!!" So below its cost a seller offers enough to cover all of its month's expenses,
whatever cash it holds, and keeps the rest. (As first built it offered its expenses less its cash, so a seller with
money offered nothing.)

### RULE NINE (the user, 2026-11-16, verbatim)
> "Okay no, one more rule rule nine, if below making price climbing allways had priority if above lowering has
> priority if both signals come in the same month only the one with priority happens, and if your going to cap it
> at 5% THEN DO THE SAME FOR BOTH"

So, for every price a producer sets: while the price is below what the good costs to make, raising has priority;
while it is above, lowering has priority; when the signal to raise and the signal to lower both come in the same
month, only the one with priority acts, the other does nothing that month. Whatever limit there is on how far a
price moves in a month is the same for a rise and for a cut (it was 5% up and 10% down).

**Held-back stock is nobody's signal (the user, verbatim):** on the price cut: "since he only offered 1000 the 15000
in storage should never have triggered the damned reduction!!!"; on the rule that sets how much a plant makes, which
still read the whole store: "Ignore the stoch in that other place too". And: "Only fix this item for now once we
have it right we fix the rest" (the item: the material price; the other sectors hold rule nine until it is right).

**Adding capacity, the user's rule (verbatim), when a material maker sold out for twelve years at up to six times cost
and added nothing:** "THE OTHER RULES ARE LITERALLY MADE TO ADD CAPACITY!!! THERE IS A RULE FOR IT IN MY RULE SET!!!!";
"So you over complicated it!!! It's simple if you sell out all your producing produce MORE!!!"; "you can add in if
your selling out and all plants at max build a new one, the price at that point will have crimbed enough and of
course money is a limitor". As built it had six conditions (85% use in 6 of 12 months, unfilled orders in 6 of 12,
price at least 1.1 times cost, no other project open, at most three times its size, money). Now, for the processing
plants only: sold out and every plant at full output, it builds one more; money is the only limiter.

**The rebuild, the user's intent (verbatim, later the same day):** "once we test this im going to commision a rebuild
of the whole economics using these working systems as the baseline". "This" is the truck drivers and workshops.
Not started and not to be started until the user commissions it. The rulings of 2026-11-16 recorded in this file
and in design-truck-drivers.md are the working systems meant.

### Queued future work (the user, 2026-11-16: "Que it as future work"; not started, waits for the end of the feature freeze)
The user's words on what it is: "Also firms in trouble should be able to be bought up by larger firms why did they not
renegotiate jobs that was a loss? We talked about improving them and the new way contractors work with the plan and
build list was made to fix this".
- **A larger firm buys a firm in trouble while it still trades.** Designs to build from: E166 (design-e166-e169.md),
  Anni's sale law with flag E174 (design-law-company-sales.md), the merger review in competition_law (exists, nothing
  calls it).
- **A builder renegotiates a job that runs at a loss.** Design to build from: design-law-construction-contracts.md
  (price revision at the start date, deposit, cancellation fee; none coded).
- **Subcontracting** (the user, same day: "can we use a sell jobs on module where they take in sub co tractors to
  help?"; then, asked whether it joins the queue: "No that's what i meant"). A builder sells part of a job on to
  subcontractors. Nothing designed; spec-economy-v1.md §20 lists it as post-v1. First step when it starts: measure
  why jobs sit unbid while builders sit idle.
Detail and the state of the code: reeval-off-switches.md.

---

### The transit authority's depot rule (the user, 2026-11-16, verbatim)

Asked whether Bob may change how the depot sets its output (he proposed: all freight asked for, averaged over three months, less the other carriers' room), the user answered:

> Tell him to test if and if it does not work to just count the work que not passed work

Passed to Bob the same turn. He tests his change in his scratch copy; if it does not work the depot counts the work queue, not the work it carried.

Bob's test of the averaged rule (2026-11-16, scratch t2): it never fell into the swing but left 140–670 units of freight behind a month in every year; the old rule ran tight but fell into the swing on seed 2 (1,655 and 2,323 left behind in years 9–10). So the work queue is next. Bob's reading of "the work queue", put to the user: unmoved freight stays in a real queue and is carried the following month; the queue is what still waits from last month plus this month's new freight orders, less what the other carriers take; the depot sets its crew on that queue. The user's answer, 2026-11-17, verbatim:

> That works

Passed to Bob the same turn; he builds it in his scratch copy behind a switch and reports before merging.

Bob's results (2026-11-17, scratch): the queue (switch R8FR_QUEUE) is nearly perfect in years 5–8 but still collapsed around year 9. The cause was not the depot rule: essential plants hire first, but the depot's posts moved to the transit authority's office were not counted as essential, so the office lost every hiring round. His fix (switch OFFICE_E99): an office counts as essential when an essential plant of its own company has moved posts to it. Queue plus fix left 13–327 behind a month in years 5–10 on both seeds. Asked "1. Merge R8FR_QUEUE? 2. Merge the office fix OFFICE_E99, after a full A/B in scratch?", the user answered, verbatim:

> Yes to both

Passed to Bob the same turn: the A/B on the office fix first, then both merged behind their switches.

### Newspapers: each paper its own look (the user, 2026-11-16, verbatim)

> Oh and make sure other newpapers have their own fonts and layouts


### Newspaper articles name who they are about (the user, 2026-11-16, verbatim)

On the written article headed "A large loss of jobs at a company":

> No on the articles, at a company? No it should be named

Done the same turn: the writer's brief, the wanted list (`must_name`) and the checker demand the name; the game does not print a written article that leaves it out and keeps its own sentence, which names it.


### Untreated illness needs signals (the user, 2026-11-17, verbatim)

After v12 (clinics closed, clinic access near zero in five districts, 8% of the labour force held back as sick, and nothing reported):

> This needs signals,  pandemic in the newpaper

Built the same turn (Wilma, switch HEALTH_SIGNAL, `game/sim/politics/health_signal.gd`): a public fact ECON_PANDEMIC each month while the people too ill to work are at least 2% of the labour force, counted the way the labour market counts them. The government answers for it, voters' concern for public services and safety falls with its size, the papers print it, and from 4% it is a crisis a government can declare an emergency over. The 2% and 4% are Wilma's numbers, not the user's.


### Offices (the user, 2026-11-17, verbatim)

Asked what offices do now, and told (an office holds a share of each plant's crew; a plant cannot produce more than its office is staffed; the office hires last; Bob's fix OFFICE_E99 would make the offices of essential plants hire first), the user answered:

> I think the offices should not be esencial, if you done have one you lose out on some not all lets say something like 15% less, but also offices should not be owned by the company unless they have a huge company one office building should be able to hold 10 plants extra workers, does that answer the questions?

Asked "1. Who owns an office building? For example a private landlord who rents out the space, or the state. 2. Is it a real building that builders have to put up? 3. Shall I give this to Bob to build now?", the user answered, verbatim:

> Private landlord, and yes, what was the first question again?

Read as: 1 = a private landlord; the "yes" answers 2 (a real building that builders put up). Whether it also answers 3 was asked again.

Not built yet. Follows directly: OFFICE_E99 stays off and gets no narrower version. Open, asked of the user: who owns and builds the office buildings; whether Bob builds this now; the full test of the freight queue on its own.


### How large fixes are built (the user, 2026-11-17, verbatim)

After v12, where 22 fixes that had each been tested alone and merged switched off ran together for the first time:

> Okay but that implies that each system builds and tested to fix you shut off before the next switch is literally the worse way to deal with this type of problem

> And hear this building fixes behind off switches is not a valid way to do large scale fixes

> You will swich the fixes on one at the time until all are one run the tests for each and report where the bottle neck is at that time

The series (one more fix on at each step, three 30-year games per step, the bottleneck reported at each) was started the same turn.


### The economy is cut out (the user, 2026-11-17, verbatim)

> THAT'S IT CANCLE IT ALL YOU CLEARLY HAVE NO IDEA WHAT YOUR DOING+!! FUCK!!! CUT THE ECONM6

> MAKE A COPY AND CUT ALL THE ECONOMY OUT

> SPECIFY YOU MAKE A FULL COPY THEN CUT THE ECONOMY OUT OF THE ORIGINAL OTHERWISE YOU DOUBLE TOKEN USE

Done by Wilma: the full copy of the game as it stood at commit 785c72f is `game_full_copy/` (not in git; the same state is commit 785c72f). The economy (sim/economy, sim/companies, sim/transport, sim/waste and everything that calls them) is removed from `game/`. All peers were told to stop work in `game/`.


### The rebuild: one company object (the user, 2026-11-17, verbatim)

> Now you build it from the ground up one object that is the company it's size family to large 4 sizes, the nine rules plugged into that the offices as a bonus building the work they do behind states if needed otherwise it's just a 2d array of wich items a company type makes,  if they pick from first or second output all in one object, then roads and supply networks since the same company can become freight that's done already, polution plugg ins to the same okay? Food output plus into the same no more godawfull single sided junk services have no output but a client take in,  stress for workers reduced output based on workers all of it into the company okay? No more only this sector shit, they start with their own and ship out build a plan with all of it adjust the plan until you see every component in the relationships we have them in anything outside needing something how it gets it,  then you ask all the others to review from their and you rewiering FUCKING STOP

> But you already lost all the conections when you rewierd so

> RUST WAS THE POINT IT DIDN'T WORK I WANTED OPRN CONNECTIONS SO IT WAS EASY TO FIND THEM AND START THE PLANNING

Wilma had patched over the calls into the removed economy (commit 8b39828). That was undone the same turn: `game/` is the game as it was at 785c72f with only `sim/economy`, `sim/companies` and the economy's tests removed, every call into them left open. The open connections are listed in [economy-connections.md](economy-connections.md). The plan for the one company object is built from that list.


### The rebuild: sizes and unions (the user, 2026-11-17, verbatim)

Answering the plan's questions 1 (what separates the sizes) and 2 (are unions outside the company):

> 1. Family is the smallest 1/6 then small 1/3 then avrage 2/3 and large full size the output for each is the same but with a small penalty for their smaller size 2. Unions belong outside, a union is started from one company with bad working conditions but any other company staff from others can join, unions protest bad conditions,  and get a small fee from every person in it,  the union orders protests and shutdowns they last depending on hour long the union can pay the workers, the workers get 2/3 normal sallery during this time,  the goverment can lean on companies if they don't comply or on the union,

Written into [rebuild-company.md](rebuild-company.md) sections 5 and 8a the same turn.


### The rebuild: workers and salaries (the user, 2026-11-17, verbatim)

> Workers and sallery, skills and swapping jobs to better payed,  actually the three rules for price should be applied here too

Written into [rebuild-company.md](rebuild-company.md) section 8b the same turn.


### The rebuild: households, company types, the starting salary (the user, 2026-11-17, verbatim)

> 3. Housholds follow terras latest plan, 4. Same company types can come but not their code or balancing 5. Sallery should be calculated as avrage living in the area and food plus half of both again, that's the start then it should regulate itself

Written into [rebuild-company.md](rebuild-company.md) section 8c the same turn.


### The rebuild: size penalty, hiring salary, yearly bonus (the user, 2026-11-17, verbatim)

Answering: Wilma's size penalty (6%, 4%, 2%, none) and her reading that rule nine for salaries turns on the starting salary:

> You penalty is fine,  that's fine for hiring, then every year a company can grant a bonus what the minimum of this is is up to the government, 2% is a good start

Written into [rebuild-company.md](rebuild-company.md) sections 5 and 8d the same turn. The plan then went to the six sessions for review, as the user's order of the rebuild says ("then you ask all the others to review from their").


### The rebuild: the seven places where rulings met (the user, 2026-11-17, verbatim)

Wilma's seven, in order: rent by street; a builder's differing jobs; a public service's bracket; a salary with plants in two districts; rules 2 and 4 for types with no stock; growing by size or by plant; the fact behind rule 6.

> On sallery it's an avrage of the area.  2. I don't see the controdiction. 3. Again yes things can be done in two different ways based in company types how its this a problem? 4. The district the plant hiring is in.  5. They have empty work slots. 6. Depends on region, in a square if there are other companies they would have to buy out the other company to make it larger, three small in a square of they can't buy out or it's too expenvice build a new  7. A hard rule here is fine

Written into [rebuild-company.md](rebuild-company.md) section 8e the same turn, with Wilma's readings marked as hers.


### The rebuild: households wholesale; buildings (the user, 2026-11-17, verbatim)

After being told what the old household side held:

> Okay i think we can take it wholesale as long as we make sure it fits in,  buildings,  did that belong to economy or something else ware and tear, repair all that,  that's what changed eent levels for the landlord

Written into [rebuild-company.md](rebuild-company.md) section 8f the same turn.


### The rebuild: owning your home (the user, 2026-11-17, verbatim)

> I belive you should be able to buy your house out so you own it,  and if an individual becomes richer than the neibouhood he was able to build his own larger house we could use the 1/6 of a farm for that

Written into [rebuild-company.md](rebuild-company.md) section 8g the same turn.


### The rebuild: homes on the map (the user, 2026-11-17, verbatim)

Asked: "What is terras opinion based on what her and i talked about the map". After Terra's opinion on where homes stand, what "a square" is, what a home costs, how rent follows value and condition and what a bought-out home sells for was put to them:

> This sounds good

Written into [rebuild-company.md](rebuild-company.md) section 8h the same turn; Terra's full text is in [rebuild-reviews.md](rebuild-reviews.md).


### The rebuild: upkeep of owned flats (the user, 2026-11-17, verbatim)

> If you own an appartment there is a fee for uppkep to the landlord that owns the rest of they all own then they are a community and they all pay together

Written into [rebuild-company.md](rebuild-company.md) section 8h the same turn.


### The rebuild: small places and the price of land (the user, 2026-11-17, verbatim)

> Below 250 start a gridd anyway and only use what you need,  and set a credit prices we are going to have to adjust it anyway i don't have a sheet of what costs what so i can't tell you what it should cost

Written into [rebuild-company.md](rebuild-company.md) section 8h the same turn. Consequence: prices in the rebuild are set by us and adjusted in testing; the user has no price sheet.


### The rebuild: the end of a company (the user, 2026-11-17, verbatim)

> End of a company can happen in three ways,  each with its own survival clause, first sales death, if even with the company hording and just trying to stay afloat it cant turn the price in two years its going to sell of its stock and shuts down,  it's plants shut down and it cant affort too replace them and finally someone buys them out, the last one has to do with land and if they get enough they can buy another building and continue there

Written into [rebuild-company.md](rebuild-company.md) section 8i the same turn.


### The rebuild: month one, noise, after an ending (the user, 2026-11-17, verbatim)

> 5 building companies and alot of oppretunity and the goverment starts with its subsidiaries as before,  and all three grant types open, and no sectors beyond landfallpoint that's up to where things are built, things like noise polution should also drive down price of housing so we don't have factories all in among the houses, or rather less. Yes they are laied of its loans are payed in full if they can when selling their stock, if not the owner is taking to court, where the bank can either settle for a smaller amount or demand payment over time, if he is rich or owns other companies a settlent might be reached

Written into [rebuild-company.md](rebuild-company.md) section 8j the same turn.


### The rebuild: grant types (the user, 2026-11-17, verbatim)

Correcting Wilma's reading that counted truck drivers and truck workshops as one grant type:

> No split trucks and workshops

The grant types: family farms, family bakeries, truck drivers, truck workshops. All open in month one.


## 5. Immediate next steps
1. **88** and **a9**: M0 tasks (orders sent 2026-11-10). Log decisions in [DECISIONS.md](DECISIONS.md) and write specs to `planning/spec-*.md`.
2. **Wilma**: PIC v1 first (the agents depend on it), then the D1 political engine spec and the D2 master tick.
3. **User**: review [DECISIONS.md](DECISIONS.md) whenever you like and override anything.
