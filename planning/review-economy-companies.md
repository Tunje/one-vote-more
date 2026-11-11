# Review: Economy & Companies Subsystems

**Scope:** `economic-simulator.md` (v0.2, 1,780 lines, "econ") and `companies.md` (v0.6, 3,495 lines, "comp"). Read in full. `project.md` was skimmed for context, and `staffAndSkills.md` / `justiceAndLaw.md` were spot-checked for interfaces only.
**Reviewer:** its-just-political (peer session), 2026-11-10. Read-only review, no code written.
**Citation format:** `econ §9.3 (L612–636)` = section and line range in that file.

---

## 1. Summary

1. **Economy (econ)** is a monthly stock-flow simulation with conservation. It has 8 physical commodities plus credits, owned inventories, recipe-based facilities with a min-of-inputs production function, 3 labor tiers, aggregated household groups, per-commodity reference prices, a link-based freight network, slow capped imports, company and government ledgers, construction contracts and a 10-phase monthly pipeline. It produces district and colony indicators for the political sim.
2. **Companies (comp)** layers *organizations* on top of that economy. It adds ownership tables, governance (owner/CEO/board), named corporate leaders with skills and talents, succession and inheritance, utility-based corporate AI, firm formation, market share and monopoly, institutions (schools, hospitals), readable newspapers with an accuracy/bias model, lobbying and corruption, a regulated alcohol sector, misconduct and enforcement, and M&A.
3. Both docs are **strong on principles and invariants**: econ §19 lists 10 conservation rules and comp §26 lists 28 integrity rules. They are **weak on numbers**. Econ has about 6 concrete formulas and one tuning constant (α = 0.15). Comp has one formula with no weights. Almost every behavior ("companies decide…", "reputation changes…", "readers trust…") is prose only.
4. Comp is about **3× the size of econ**, and much of it (media, alcohol, schools, lobbying, M&A) falls outside project.md's minimum playable game (project §21.1) or is explicitly deferred there (project §21.2 "Complex media organizations"). Scope control is the biggest planning risk.
5. Several **shared concepts are defined differently** in each doc: the resource list, the monthly phase order, the skill system, reputation, company attributes, household segmentation and insolvency states. They have to be reconciled before any data model is frozen.

---

## 2. Entities and data model

### 2.1 Economy entities (econ §2, L38–62)
| Entity | Defined fields / stats | Source |
|---|---|---|
| Government | treasury cash; approved allocations; outstanding commitments; debt (principal, rate, schedule) | §13.1, §13.5, §13.7 |
| Company | balance sheet: cash, inventories, facilities, equipment, receivables / loans, payables, contract obligations / equity; reputation | §12.1, §12.6 |
| Facility | owner, operator (can differ); recipes; capacity C_f; efficiency E_f; condition; utility connection | §3.1, §5.1–5.4, §6.4 |
| District | housing capacity, occupied, available, quality, cost, utility access; plus 11 reported indicators | §8.6, §18.1 |
| Household group | key = District × income category × skill; population, working-age, available/employed/unemployed by skill, wage income, savings, financial security | §7.2, §8.1, §8.4 |
| Resource | FOOD, WATER, ENERGY, MINERAL, MATERIAL, COMPONENT, CONSUMER, MEDICAL (+ credits as currency) | §4.1 (L138–149) |
| Inventory | type, qty, owner, location, max capacity, reserved, available (= physical − reserved) | §4.2 (L157–169) |
| Transport link | origin, destination, distance/cost c_e, monthly cargo capacity, condition, operating cost | §10.1 |
| Shipment | origin, dest, owner, commodity, qty, depart month, ETA, transport reservation, status | §10.4 (L736–746) |
| Contract (construction) | contractor, client, project, price, duration, payment schedule, material responsibility, performance reqs, penalties, termination | §14.3 (L1094–1103) |
| Project | site, authorization, funding, materials, components, workforce, equipment, logistics; progress | §14.1, §14.4 |
| Transaction | payer, payee, amount (source/destination mandatory) | §16 Ph7, §19 R4 |
| Employment allocation | worker capacity to employer, unique per month | §7.7, §19 R2 |
| Labor categories | General / Skilled / Specialist | §7.1 (L377–381) |
| Price state per commodity | P_r, S_r, D_r, P_min, P_max | §9.2 (L601–606) |
| Import order | P_origin, freight, handling, tariff, delay, cargo-quota share | §11.1–11.4 |
| Delegated assignment (gov't staff) | official, objective, budget, authorized actions, reporting freq, escalation, workload, review date | §15.3 (L1176–1185) |

### 2.2 Companies entities (comp §25, L2394–2656)
| Entity | Key fields |
|---|---|
| **Company** | id, name, founding_month, industry_ids[], legal_structure, ownership_structure, governance_model, operating_status, HQ district, owner_ids[], ownership_stakes[], board_member_ids[], ceo_id, cash_account_id, asset/liability/facility/inventory ids, employee_groups[], contract_ids[], supplier_relationships[], subsidiary_ids[], strategic_priorities[], political_interests[], political_activity_status, reputation_profile, compliance_record, history[] |
| **CorporatePerson** | id, name, career_stage, skills{}, talents[], experience{}, ethics, risk_tolerance, strategic_preferences[], wealth, ownership_stakes[], management/board position ids, relationships[], career_history[] |
| **OwnershipStake** | company_id, owner_entity_id, ownership_%, voting_%, share_class, acquisition_month, transfer_restrictions[] |
| **Board** | member_ids[] (3–7, §6.4), chair_id, voting_rules, decision_authority[], meeting_schedule, pending/history decisions |
| **CorporateDecision** | proposer, type, options[], expected_outcomes[], required_authority, status, votes[], selected_option, effective_month |
| **Institution** | organization_id, type (school/hospital/research/training/cultural/utility/news/social, §11.1), ownership_model, operator_id, facilities, staffing_requirements, service_capacity, service_quality, funding_sources[], fees, regulatory_status, service districts |
| **School stats** (§12.3) | capacity, enrollment, teachers, teacher qualifications, facilities, funding, fees, quality, accessibility, management, operating cost, student outcomes |
| **Newspaper** | company_id, name, editor_id, editorial_priorities[], journalistic_capacity, editorial_independence, accuracy_record, correction_record, readership_groups[], circulation, subscription_price, advertising_revenue, edition_ids[] |
| **NewsArticle** | newspaper, month, headline, article_type (news/investigation/editorial/opinion/announcement/correction, §14.4), author, body, referenced_event_ids[], factual_claims[], editorial_framing, source_quality, accuracy_status, correction_status, readership, credibility_effects[] |
| **CorporateInfluenceAction** | company, action_type, target entity/policy, resources_spent, legality_status, expected/actual result, detection_status, reputation_effects[] |
| **RegulatoryCase** | target company, regulator, alleged_violation, underlying_event_ids[], evidence[], investigation/legal status, findings[], penalties[], appeal_status |
| **CorporateEvent** | month, companies[], persons[], event_type, factual_outcome, economic/legal/reputation effects, public_visibility, related_article_ids[] |

**Enumerations defined in prose only (no data definition):**
- Company types (9): owner-operated, CEO-managed private, board-governed, publicly traded, cooperative, government-owned, mixed, nonprofit, government institution (§3.1–3.9)
- Operating status (11): Forming, Active, Expanding, Stable, Contracting, Financially distressed, Under administration, Insolvent, Being liquidated, Acquired, Dissolved (§8.6, L739–751)
- Leader skills (10): Business Mgmt, Finance, Engineering, Logistics, Negotiation, HR, Strategy, Communication, Legal Knowledge, Industry Expertise (§5.2). **No scale stated.**
- Leader talents (17), positive, negative or situational (§5.3, L411–427). **No effects defined.**
- Owner objectives (10) (§4.3)
- Reputation dimensions (8): quality, contract reliability, financial reliability, employee treatment, environment, compliance, public trust, management credibility (§19.1). These are also split by audience (§19.2) and into long-term / recent / leadership confidence (§7.5)
- Political activity (6 levels) (§16.1); influence methods (11) (§16.3)
- Alcohol regulatory models A–E (§17.3); consumer tiers: abstainer/occasional/moderate/heavy (§17.7)
- Misconduct categories (11) (§18.1); enforcement responses (10) (§18.4)
- Market concentration (6 types) (§10.2); relationship types (8) (§20.1)

---

## 3. Core loops and formulas

### 3.1 Actually specified (with math or numbers)
| Item | Spec | Ref |
|---|---|---|
| Available stock | `available = physical − reserved` | econ §4.2 L169 |
| Inventory identity | `close = open + prod + received − inputs − dispatched − consumed − losses` | econ §4.4 L194 |
| Production | `Q_f = C_f × U_f × E_f`; `U_f = min(1, r_1..r_n)`; r_i = available/required | econ §5.3 L247–264 |
| Efficiency | `E_f = E_condition × E_skill` (**sub-terms undefined**) | econ §5.4 L294–296 |
| Recipes | 6 illustrative monthly recipes (mine, processing, component, farm, consumer, medical), "not balanced" | econ §5.2 L226–235 |
| Production lag | output usable downstream only next month | econ §5.5, §16 Ph6 |
| Quantities | fixed-point thousandths recommended | econ §5.6 |
| Energy rationing | 5-tier priority list | econ §6.2 L345–349 |
| Disposable income | `gross − taxes + transfers` | econ §8.2 L493–499 |
| Price update | `P' = clamp(P(1 + α(D−S)/max(D,S,ε)), Pmin, Pmax)`, **α = 0.15** | econ §9.3 L616–634 |
| Delivered price | competition on price + freight (110 vs 95+25 example) | econ §9.6 |
| Freight | `C = Q × Σ c_e` | econ §10.3 L716–721 |
| Import price | `P_origin + freight + handling + tariff`; target 2–4× local; 3-month baseline delay | econ §11.2–11.3 |
| Operating profit | revenue − materials − wages − utilities − logistics − maintenance − other | econ §12.2 L877–893 |
| Bid | material + labor + logistics + equipment + risk allowance + margin | econ §14.2 L1070–1084 |
| Construction progress | `base rate × input availability × contractor efficiency` (**no values**) | econ §14.4 L1115–1123 |
| Monthly pipeline | 10 phases | econ §16 L1218–1341 |
| Worked example | 1,000 residents, mine→plant→housing (100 MAT), first progress in month 3, done after 5 supplied months | econ §17 |
| Corporate utility | `U(a) = w_p P + w_g G + w_s S + w_r R + w_o O`, after feasibility checks (**no weights, no normalization, no action list**) | comp §22.4 L2074–2093 |
| Board size | 3–7; majority default, configurable supermajority | comp §6.4–6.5, §30 |
| Articles per edition | 3–7 | comp §30 |
| Ownership | stakes sum to 100% | comp §4.1 L313 |
| Monthly company pipeline | 11 phases | comp §23 L2125–2244 |

### 3.2 Prose only (no formula, no numbers)
- **Econ:** labor matching score (§7.4), wage adjustment (§7.6), company vacancy creation (§7.3), household essential minimums and the discretionary split (§8.3, §8.5), savings and "financial security" (§8.4), housing rent dynamics (§8.6), well-being indicators (§8.7), seller asking price (§9.4), the market-clearing algorithm (§9.5, which only says "deterministic priority or price-based"), CPI basket weights (§9.7), shipment duration (§10.4), import quotas (§11.4), company investment (§12.4), the insolvency trigger (§12.5), reputation (§12.6), tax rates and loss treatment (§13.4), debt terms (§13.7), contractor workload (§14.5), official "management effectiveness" (§15.4), pollution, and income inequality (§18.1).
- **Comp:** essentially everything, including how leader skills and talents change decisions (§5.4, §22.2), board voting outcomes and disagreement (§6.5–6.6), CEO replacement triggers (§6.7), succession and heir generation (§7), lifecycle transitions (§8.6, "must follow defined conditions", none given), entrepreneur generation and startup evaluation (§9), market share and concentration thresholds (§10), institution service output (§11–13), education outcomes (§12.4), healthcare outcomes (§13.3), article selection and generation (§15.3), accuracy, credibility and readership (§14.6–14.11), household trust in media (§14.11), media effect on opinion (**not specified anywhere**), lobbying effectiveness (§16.5), corruption probability (§16.7, §18.2), alcohol demand, health and turnout (§17.8–17.11), detection probability (§18.3), reputation update and decay (§19.3–19.4), cascading failure (§20.4), company valuation for M&A (§21.1) and forecasting error (§22.5).

**Bottom line:** econ's *physical* core (inventories → recipes → production) is close to implementable. Its *behavioral* core (prices, wages, demand, firm decisions) and nearly all of comp need formulas before coding starts.

---

## 4. Dependencies

### 4.1 Needs FROM other docs
| Need | From | Where referenced |
|---|---|---|
| Calendar, monthly turn, seeded RNG, save versioning | project §2.1, §17.4, §17.5 | econ §16; comp §26.28 |
| Map / tiles → districts, transport links, facility sites, terrain cost | project §3.1–3.5 | econ §10.1, §14.1 ("approved site") |
| Population groups, migration, satisfaction aggregation | project §4.1–4.4 | econ §7.5, §8.1, §8.7 |
| Tax rates, budgets, subsidies, minimum wage, energy-priority law, tariffs, import authorization | project §11 (legislation); justice §4, §11 (labor law) | econ §6.2, §7.6, §11.1, §13.8 |
| Business registration and licensing (License entity) | justice §10.1, §27.10 | comp §9.1, §9.4, §17.3 |
| Corporate law: director authority, insolvency proceedings, ownership disputes, competition law | justice §10.2–10.6 | comp §6, §8.6, §10.4, §21.5 |
| Contract law: validity, breach, enforcement, ownership-change continuity | justice §9 | econ §14.3; comp §20.2, §21.4 |
| Regulatory agencies (capacity, inspections, enforcement) | justice §16 | comp §18.3–18.5 |
| Press freedom, defamation | justice §17 | comp §14.8–14.9, §15.4 |
| Alcohol licensing and illegal-production enforcement | justice §18 | comp §17 |
| Corruption detection and consequences | justice §19 | comp §16.7 |
| Gov't officials: skills, workload, delegation, procurement, contractor supervision | staff §4, §13, §18.2–18.4 | econ §15; comp (procurement implied) |
| Parties (to receive donations, lobbying, alignment) and voters (turnout) | project §8, §9 | comp §16, §17.11 |
| Event/history store | project §15, §17.2 | comp §14.5, §25.11 |

### 4.2 Feeds INTO other docs
| Output | Consumer | Ref |
|---|---|---|
| District and colony indicators + trends | political sim (project §4.3, §9.5) | econ §18 |
| Unemployment, prices (CPI), housing, utility reliability | population satisfaction (project §4.4) | econ §8.7, §9.7 |
| Facts/events (missed deadlines, bankruptcies, violations) | newspapers, courts, staff briefings | comp §14.5; justice §29 Ph4; staff §14 |
| Legal incidents (breach, insolvency, misconduct) | justice case pipeline | comp §18; justice §7, §10.4 |
| Contractor progress and failure | staff project tasks (staff §12.6, §18.4) | econ §14.4–14.6 |
| Fines / compensation payments | ledger (justice §8.5 requires the ledger) | econ §19 R4 |
| Lobbying, donations, media coverage | party AI, voter opinion | comp §16, §14 |

### 4.3 Overlaps that need a single owner
- **Regulatory enforcement:** comp §18 + `RegulatoryCase` (§25.10) duplicates justice §16 + `LegalCase`/`RegulatoryAgency` (§27). *Recommendation:* justice owns cases and agencies, and comp only emits violations/incidents.
- **Alcohol:** comp §17 and justice §18 both define the 5 market models.
- **Insolvency:** comp §8.6 (11 states), econ §12.5 (6 consequences) and justice §10.4 (5 outcomes) use three vocabularies.
- **Events/facts:** comp `CorporateEvent`, justice `LegalIncident` (§27.8) and project "Event" (§17.2) should be one fact store that media reads from.
- **People:** comp `CorporatePerson` and staff `StaffMember` (staff §22.1) are two person models with different skill lists.

---

## 5. Gaps and missing

### 5.1 Contradictions
1. **[BLOCKER] Resource list differs across docs.** project §5.2 (L288–301) lists Food, Energy, Construction materials, **Industrial metals**, **Advanced components**, Credits. econ §4.1 lists 8 resources with Water, Minerals, Consumer, Medical and no "metals". comp §17.1 / C12 adds **ALCOHOL**, a 9th commodity with no recipe and undefined inputs ("suitable agricultural or industrial inputs", §17.2). Power stations need "fuel" (econ §6.1) but no fuel resource exists. "Equipment" appears in econ §3.4, §12.1 and §14.2 and comp §8.4 but is neither a commodity nor an asset type.
2. **[BLOCKER] Five different monthly phase orders.** econ §16 (10 phases), comp §23 (11), project §17.3 (10), justice §29 (10) and staff §15 (9). Specific conflicts:
   - project §17.3 advances projects (step 3) *before* logistics (4) and production (5), while econ runs trade (Ph5) before production/projects (Ph6).
   - econ Ph1 applies "company production decisions", but comp plans in Ph2 and econ plans next month in Ph9.
   - comp Ph6 "institutional services" is separate from production, and econ has no services phase.
   - Media (comp Ph7) runs *before* regulation and investigations (Ph8), so the same month's findings can't be reported.
   A single master pipeline is needed.
3. **[IMPORTANT] Labor tiers vs recipes.** econ §7.1 has 3 tiers and puts *mining* under Skilled, but the mine recipe (§5.2 L228) uses "20 workers" (general), and recipes only distinguish "workers" vs "skilled workers". Specialist is never used in a recipe.
4. **[IMPORTANT] Household segmentation conflict.** econ §8.1 groups by District × income × skill. project §4.2 groups by occupation (industrial, mining, service, public-sector, owners, unemployed, retired). comp §17.7 adds 4 alcohol tiers and comp §14.11 adds per-group media trust. The dimensions multiply, and retired/owner groups have no skill tier.
5. **[IMPORTANT] Reputation model.** econ §12.6 treats it as a single implicit value. project §6.2 has separate `Reputation` and `Reliability`. comp §19 has 8 dimensions × audiences × (long-term / recent / leadership). comp §25.1 has `reputation_profile` without a schema.
6. **[IMPORTANT] Company attributes.** project §6.2 lists Capital, Equipment, Specialization, Price strategy, Logistics capability, Work quality, Labor practices and Environmental practices. Most of these are missing from comp §25.1 and econ §12.1. In econ, capacity lives on *facilities*, not on companies.
7. **[IMPORTANT] Skill systems.** Corporate leaders have 10 skills with **no scale**. The §7.3 heir example uses 24/12/30/18, which implies 0–100. Staff have 10 *different* skills on 0–100 (staff §4.2), and the talent libraries differ. Can a CEO become a minister, or vice versa? This is undefined.
8. **[IMPORTANT] Scope conflict with project.md.**
   - project §21.2 *defers* "Complex media organizations" and "Complex orbital and interplanetary trade".
   - comp §29 makes readable newspapers with 4 truthfulness modes, alcohol, schools, lobbying and M&A *mandatory* for the first playable version.
   - econ §11 imports and §10 routing are at least modest, but project §21.2 defers "sophisticated transportation pathfinding" while econ §10.2 requires route-capacity reservation.
9. **[IMPORTANT] Money conservation vs personal wealth.** `CorporatePerson.wealth` (comp §25.2) and dividends to owners (comp §16.4) are a separate pool of money from household groups' "business income distributions" (econ §8.2). It's undefined whether owners live inside a household group or outside it. Under econ §19 R4/R9, money can be double-counted or leak.
10. **[NICE] Version skew.** comp v0.6 says "Companies use the economic simulation already specified" (§8, L661), but econ is v0.2 and lacks the services, advertising, donations, dividends and shares that comp assumes.

### 5.2 Undefined formulas and missing numbers
11. **[BLOCKER] No starting scenario numbers.** econ §3.4 lists the ingredients only. There is no treasury, stockpiles, population, number or type of companies, facilities, wages or prices. project §5.1 requires that "founding supplies are exhausted" eventually, but there's no runway target. econ §17 (1,000 residents, 500 workers) is the only sizing hint.
12. **[BLOCKER] No price/currency scale.** There are no initial reference prices, P_min/P_max or ε (§9.3), no wage levels, and no per-capita essential consumption (food, water, energy per person per month, §8.3). The only magnitudes are "110 credits" (§9.6) and "2 million credits" (§13.6), which are mutually unanchored.
13. **[BLOCKER] Market clearing algorithm unspecified** (econ §9.5). Open points:
    - Is there one colony market or per-district markets? §8.5 says "local prices", but §9.2 defines one P_r per commodity.
    - What is the matching order (price, contracts, priority)?
    - How do seller asking prices (§9.4) relate to P_r?
    - How are partial fills allocated among households?
    This is the core loop and can't be improvised.
14. **[BLOCKER] Firm behavior has no decision rules.** Production target (comp §8.2), hiring and wage offers (econ §7.3, §7.6), pricing (§9.4), investment thresholds (econ §12.4, §22) and the utility weights w_p…w_o (comp §22.4) are all undefined, along with the candidate action set and how P/G/S/R/O are normalized. Without these, econ §20 acceptance tests E10 and E11 can't be met.
15. **[BLOCKER] Insolvency and lifecycle transitions.** "Persistent inability to meet obligations" (econ §22) has no threshold (months of negative cash? payables overdue?). comp §8.6 demands defined transitions between 11 states and gives none. The map to justice §10.4 proceedings is also missing.
16. **[BLOCKER] No lender / money-creation authority.** econ §13.7 says "the game should define who provides the loan", but doesn't. There's no bank entity, so company loans (econ §12.1, comp §21.2) and government debt have no counterparty. econ §19 R4 requires explicit currency creation, yet no monetary authority exists.
17. **[IMPORTANT] Production efficiency terms.** E_condition (decay/maintenance curve) and E_skill (mapping from workforce tier mix) are undefined. Facility condition decay and maintenance cost are undefined too. Q_f has no "planned output" term, although comp §8.2 lets firms produce below capacity.
18. **[IMPORTANT] Missing recipes.** There are no recipes for power, water, transport/logistics firms, construction contractors (econ §17 assumes "20 units/month"), retail, alcohol, schools, hospitals or newspapers. Facility capacity C_f, construction cost and construction recipes (econ §20 E7 lists "construction recipes") are missing. Housing has only the one example (100 MAT).
19. **[IMPORTANT] Accounting model.** econ §12.2 says taxes, financing and capex are "handled according to the accounting model", but none exists. Undefined items:
    - inventory valuation method (needed for "materials consumed")
    - depreciation
    - asset valuation (needed for M&A §21.1 and liquidation)
    - tax loss rule (explicitly demanded by econ §13.4)
    - public-enterprise dividend rule (econ §3.2)
20. **[IMPORTANT] Tax design.** No rates, brackets, profit-tax periodicity or who sets them in the founding period. VAT, alcohol excise and tariffs are mentioned (econ §11.2, comp §17.3) but not modeled.
21. **[IMPORTANT] Services aren't modeled economically.** Households buy "medical services", "other services" and housing (econ §8.3), and institutions have "service capacity / quality" (comp §11.2). There's no service unit, price, capacity formula or outcome formula (education → skill tier transitions, comp §12.4; health → worker availability and mortality, comp §13.3).
22. **[IMPORTANT] Media core loop missing.** comp gives no story-selection score, accuracy/error/dishonesty probability, credibility update, readership model or, critically, **any effect of articles on household opinion or party support**. Without that effect the newspapers are flavor text. Article text generation (templates? LLM?) isn't specified either.
23. **[IMPORTANT] Lobbying and corruption mechanics.** There's no effect size on party agendas (comp §16.5) and no misconduct probability (§18.2). The detection model must align with justice §16.5 / §19.4.
24. **[IMPORTANT] Logistics vs map.** Links (econ §10.1) vs tiles (project §3.1) is undefined: are links derived from road tiles? How do logistics-firm fleet capacity (econ §10.5) and link capacity interact? What is the routing algorithm (shortest path vs cheapest)?
25. **[IMPORTANT] Demographics.** Migration (econ §7.5, project §4.1), births/deaths, aging, training time (econ §7.5) and leader aging/death/heirs (comp §7, needed for succession) have no model or owner.
26. **[IMPORTANT] Pollution and inequality.** Both are listed as district indicators (econ §18.1), but there's no per-facility emission value or inequality metric (Gini? ratio?).
27. **[NICE] Concentration thresholds** ("configurable by sector", comp §30). Suggest HHI and pick defaults.
28. **[NICE] Contract bid evaluation.** There's no scoring rule for the AI/staff evaluator. Who picks the contractor after parliament starts: the player, the delegated official (staff §18.2) or rules? Contractor efficiency (econ §14.4) isn't defined.
29. **[NICE] Perishability and storage losses** are deferred (econ §4.2). Note that FOOD then never spoils, which makes stockpiling trivially safe.

### 5.3 Edge cases
30. **[IMPORTANT] Negative balances.** Can the treasury, a company or a household go below 0 cash mid-settlement? What is the order of creditor priority when cash runs out in Ph7 (wages vs suppliers vs taxes vs debt)?
31. **[IMPORTANT] Simultaneous shortages.** Energy priority (econ §6.2) is defined, but there's no rationing rule for food, water or medical among household groups, or between households and institutions.
32. **[IMPORTANT] Ownership edge cases.** Cyclic ownership (A owns B owns A), subsidiaries owning parents, "Employee investment group" as owner type (comp §4.1, L308) with no entity, and the government as shareholder (voting through which official?).
33. **[NICE] Price formula at zero.** If D = S = 0 the price is frozen. Prices of goods nobody sells (new commodity) are undefined.
34. **[NICE] Fixed-point rounding.** Remainder distribution when splitting 1/1000 units among many buyers is undefined. This matters for conservation tests (econ §20 E1).

### 5.4 UI
35. **[IMPORTANT] econ has no UI section at all.** Screens needed but undefined:
    - budget / tax setting
    - energy-priority editor (§6.2)
    - import ordering and cargo prioritization (§11.4)
    - bid comparison (project §6.3)
    - the "explain this shortage" inspector that Rule 10 (§19) mandates
    - commodity/price charts
    - household-group view
    project §16.2 gives one line per panel.
36. **[NICE] comp §24 lists screen contents, but there are no wireframes, information-visibility rules** ("only visible with legitimate access", §24.2, which needs a defined access model), or notification thresholds (§24.8).

### 5.5 Win/lose and save state
37. **[BLOCKER] No failure/end-state definition for the economy.** project §22 leaves "whether the colony can fail" open, while econ §21 H says "economic collapse should remain possible". What happens on famine, a sovereign default, total unemployment or zero population? Does the treasury hard-floor? Is there a game over, a forced bailout from the origin civilization, or emergency powers (justice §20)?
38. **[IMPORTANT] Save state.** econ never mentions saving. comp §26.28 lists what must persist. Missing items:
    - in-flight shipments, reservations, partially filled orders
    - price history
    - RNG streams for corporate AI, misconduct rolls and article generation (these must be seeded per project §17.4)
    - the full transaction ledger over 30 years
    comp §30 says "compress routine records", but there's no retention policy, which risks save bloat.
39. **[NICE] Determinism.** The utility AI with "imperfect information" and forecasting error (comp §22.5) must draw from seeded streams in a fixed entity order, or reproducibility (project §17.4) breaks.

---

## 6. Build order

The plan interleaves econ stages (E#) and comp phases (C#) and targets project.md's minimum playable game first (project §19 Phase 2, §21.1). Sizes: **S** ≈ days, **M** ≈ 1–3 weeks, **L** ≈ 1–2 months (single dev, rough).

| # | Item | Contents | Size | Prereq |
|---|---|---|---|---|
| 0 | **Shared kernel** | stable IDs, fixed-point qty type, seeded RNG streams, unified monthly pipeline skeleton (resolve contradiction #2), fact/event store, save/load w/ version | M | design decisions #1, #2 |
| 1 | E1 Resource accounting | resources (data-driven), inventories, reservations, transfers, conservation tests | S | 0 |
| 2 | E3 Money & ledger | double-entry ledger, gov't + company accounts, explicit mint/external accounts, lender entity | M | 0, decision on lender |
| 3 | C1 Company core (thin) | Company entity, facilities ownership vs operator, status enum, link to ledger/inventory | S | 1, 2 |
| 4 | E2 Production | recipes as data, Q=C·U·E, efficiency stub (E=1), next-month availability | M | 1, 3 |
| 5 | E4 Labor & households | household groups (pick one segmentation), 3 tiers, simple greedy matching, wages, income tax withholding, essential consumption | L | 2, 4 |
| 6 | E5 Markets & prices | order collection, deterministic matching, delivered price, α-price update, CPI | L | 4, 5 |
| 7 | E6 Logistics (simple) | link graph from map, Dijkstra on cost, capacity reservation, multi-month shipments | M | 6, map |
| 8 | E7 Construction & bidding | construction recipes, bid formula, contract records, milestones, progress, failure | M | 6, 7 |
| 9 | E8 Government economy | budgets / commitments / cash, taxes, subsidies, public enterprises, debt | M | 2, 8 |
| 10 | E10 + C5 Corporate AI v1 | rule-based first (production target, hire/fire, price, bid/no-bid, invest threshold), then utility layer | L | 5–9 |
| 11 | C14 (part) Insolvency | distress detection, state transitions, asset retention, contract interruption | M | 10, justice L4/L6 |
| 12 | E11 Political indicators | district/colony indicators + trends, history | S | 5, 6 |
| 13 | UI: economy & companies MVP | budget, bid compare, company directory/profile, shortage inspector | L | 1–12 |
| — | **= Minimum playable economy (project §21.1)** | | | |
| 14 | E9 Imports | external supplier, cargo quota, delay, private imports | S | 6, 7 |
| 15 | C2 Ownership & types (subset) | owner-operated, CEO-managed, public enterprise; ownership table | M | 10 |
| 16 | C3 Corporate leaders | CorporatePerson (shared Person base with staff), skills → decision noise/bias | M | 15 |
| 17 | C6 Formation & competition | entrepreneur spawn, startup eval, market share, HHI | M | 10, 16 |
| 18 | C7 Succession & M&A | aging, heirs, sale, merger, valuation | M | 16, accounting model |
| 19 | C4 Boards | board voting, CEO dismissal | S | 15, 16 |
| 20 | C8/C9 Institutions & schools | service units, staffing, education → skill-tier flow | L | 5, services spec |
| 21 | C13 Misconduct (emit only) | violation generation → justice incidents | M | justice L9 |
| 22 | C10 Media | fact selection, templates, accuracy/bias, credibility, opinion effect, reader UI, archive | L | 0 fact store, political opinion model |
| 23 | C11 Lobbying | influence budget, party-agenda hook | M | parties AI |
| 24 | C12 Alcohol | commodity, recipe, 5 models, consumption tiers, health/turnout hooks | M | 20, justice L12 |
| 25 | C15/C16/C17 | gov't integration, full UI, multidecade balancing harness | L | all |

**Recommendation:** build a **headless simulation harness** (run N years, dump CSV of indicators, assert conservation) at step 1 and keep it running through every step. econ §21 scenarios A–H become CI tests.

---

## 7. Open questions for the designer

1. **Canonical resource list.** Is it econ's 8, project's 6 or 8+alcohol? Is "equipment" a commodity, an asset or a facility attribute? Do power stations need a fuel input?
2. **One market or many?** Is there a single colony-wide price per commodity, or per-district prices with freight arbitrage?
3. **Who lends money and who creates it?** Is there an origin-civilization bank, a colony central bank or a private bank company? Can the government print credits?
4. **Can the colony fail?** If so, what are the end states (famine, default, depopulation) and what does the player see? Or is collapse only a political consequence?
5. **Starting scenario.** What population, treasury, stockpiles and company roster? How many months of runway should founding supplies give?
6. **Household segmentation.** Pick one: econ's District × income × skill, or project's occupation groups. Where do business owners and their wealth live?
7. **Person model.** Should corporate leaders and government staff share one Person entity and skill scale (0–100)? Can people move between the private sector and government?
8. **Scope for v1.** Do media, alcohol, schools, lobbying and M&A stay in the "minimum complete" set as comp §29 says, or are they deferred as project §21.2 says?
9. **Contractor selection.** After parliament forms, does the player still pick contractors, or do delegated officials pick by a scoring rule? What are the weights (price, reliability, schedule)?
10. **How much should newspapers move opinion,** and through what pathway (per-household-group trust × readership × article sentiment)? Who owns this formula: comp or the political doc?
11. **Phase order authority.** Which doc owns the master monthly pipeline? Do we agree to collapse the 5 versions into one?
12. **Article text generation.** Should articles use hand-written templates with slots, or runtime LLM generation? This affects determinism, save size and cost.
13. **Tax system in the founding period.** Does the commander set rates freely? What are the starting rates?
14. **Perishability and storage.** Is perishable food acceptable to defer, given that stockpiling then has no cost?
15. **Regulatory ownership.** Does justiceAndLaw own RegulatoryCase, agencies and alcohol licensing, so that comp §18 and §25.10 can be cut down to "emit violations"?
