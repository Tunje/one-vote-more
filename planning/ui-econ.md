# UI ↔ Economy: Panels and Accessors (M5)

**Owner:** agent 88 · **For:** Wilma (Godot shell, M5) · **Date:** 2026-11-10
**Code:** `game/sim/economy/econ_query.gd` (`EconQuery`, read-only, covered by `tests/economy/test_economy.gd::test_query_layer_for_ui`).
**Rules:**
- UI code never reads econ tables directly. It calls `EconQuery.*`, which returns plain Dictionaries and Arrays in display units (credits as floats, percentages 0..100).
- Player actions go through `EconActions.enqueue(world, id, params)`. They are applied at the start of the next TRADE phase, exactly like AI actions (pic-core §6).
- Refresh panels after a month's `RECORD` phase. Values are final after `SOCIAL` (pic-core §7).
- **Visibility:** fields marked *official* below are government data (pic-core §3 OFFICIAL). Hide or blur them when the player is in opposition, unless revealed through oversight (`ECON_REQUEST_ECON_BRIEFING`).

---

## 1. Budget panel (project §16.2 "Economy")
| Need | Accessor | Fields |
|---|---|---|
| Header numbers | `EconQuery.budget_view(world)` | `treasury`, `debt`, `credit_headroom`, `runway_months` *(official)*, `debt_ratio_pct`, `balance_pct`, `operating_balance_pct` *(official)*, `grant_this_month` |
| Budget lines table | same → `lines[]` | `lever`, `label`, `annual` (credits/yr), `spent_ytd`, `headroom` |
| Where money came from / went (12 months) | same → `revenue_12m{reason: cr}`, `spending_12m{reason: cr}` | Reason codes: `INCOME_TAX PROFIT_TAX ROYALTY FEE FINE DIVIDEND GRANT LOAN_DRAW` / `BUDGET_TRANSFER CONTRACT_PAYMENT BENEFIT PENSION SUBSIDY LOAN_SERVICE IMPORT` |
| Tax settings | same → `tax_levers` | income %, allowance, profit %, tariff % |
| Changing a line or tax | **not an econ action.** It's a bill or ordinance through politics/law (A8). | Show the lever's `concerns` hint and `fiscal` estimate from `world.lever_defs[id]` |
| Charts over time | `world.indicators.history[id]` | e.g. `ECON_PUBLIC_DEBT_RATIO`, `ECON_BUDGET_BALANCE`, `ECON_CPI_INFLATION` (values ×1000) |

## 2. Procurement: commission, tenders, bid comparison
| Need | Accessor | Fields |
|---|---|---|
| "What can I build?" | `EconQuery.commission_options(world)` | `type`, `line`, `estimate`, `headroom`, `enabled`, `reason` |
| Commission | `EconActions.enqueue(world, "ECON_COMMISSION_PROJECT", {"type", "district"})` | Opens a 1-month tender. With `world.meta["manual_award"] = true` the player has 3 months to choose; otherwise the delegated official awards the top score |
| Open tenders | `EconQuery.tenders(world)` | `project`, `type`, `district`, `status` (TENDER/TENDERABLE), `est_cost`, `min_months`, `size_class`, `bids[]` |
| **Bid comparison** | `EconQuery.bid_breakdown(world, project_id)` | per bid: `rank`, `name`, `price`, `duration`, `reliability`, `score`, `price_part`, `reliability_part`, `duration_part` (stacked bar), `distressed` *(official)* |
| Award | `EconActions.enqueue(world, "ECON_AWARD_CONTRACT", {"project", "org"})` | Picking a non-top bid emits `ECON_CONTRACT_AWARDED` with `override = true` (favouritism risk) |
| Re-tender / cancel | `ECON_RETENDER_PROJECT {project}` / `ECON_CANCEL_PROJECT {project}` | Cancel pays progress + 5% |
| Project list | `EconQuery.projects(world, "gov")` | `progress_pct`, `price`, `paid`, `months_late`, `supervision`, `blockers[]` (see §5) |

## 3. Company directory and profile
| Need | Accessor | Fields |
|---|---|---|
| Directory (filter by type, status, sector, district) | `EconQuery.companies(world, include_dissolved=false)` | `id`, `name`, `type`, `status`, `hq`, `sectors[]`, `employees`, `reliability`; *(official)* `cash`, `debt`, `profit_last_month` |
| Profile | `EconQuery.company_profile(world, id)` | `ceo{management, risk, age}`, `facilities[]` (utilization, target, staff, condition, scale, mothballed, licensed), `crew`, `contracts[]`, `pl_last_month{rev, cogs, wages, …}` *(official)*, `cash`/`debt` *(official)*, `history[]` (fact ids, open with §5) |
| Government interventions | `ECON_SUBSIDIZE {org, amount}`, `ECON_RESCUE_LOAN`, `ECON_BUY_FACILITY {facility}` | Each emits a public fact |

## 4. Markets, districts, colony
| Need | Accessor | Fields |
|---|---|---|
| Market overview | `EconQuery.market_overview(world)` | per good: `price`, `base_price`, `offered`, `demand`, `wanted`, `filled`, `seller_share_pct{name: %}`; ENERGY/WATER: `tariff`, `supply`, `demand` |
| District economy (map tooltip) | `EconQuery.district_economy(world, "d:4")` | every econ DISTRICT indicator (unemployment, shortfall, local price, overcrowding, utilities, infra, logistics, health, education, pollution, income ratio), plus `households`, `housing_units`, `private_rent` |
| Voter-cell values (political overlay) | `world.indicators.read(id, cell_key)`; cells from `world.table("census")` | VOTER_CELL indicators: `ECON_JOB_RISK`, `ECON_REAL_INCOME_INDEX`, `ECON_ESSENTIALS_SHARE`, `ECON_RENT_BURDEN`, `ECON_TAX_BURDEN`, `ECON_FINANCIAL_SECURITY`, `ECON_REAL_WAGE_GROWTH` |
| Emergency | `ECON_RELEASE_RESERVE {good, qty, price?}`, `ECON_ORDER_IMPORTS {good, qty}` (arrives on the next ship ≥ 3 months), `ECON_BORROW {amount}`, `ECON_REPAY_DEBT {amount}` | |

## 5. Shortage explainer ("why did this happen?", econ Rule 10, project §20.4)
| Need | Accessor | Output |
|---|---|---|
| Why is facility X under target? | `EconQuery.explain_facility(world, fid)` | `causes[]` sorted by `severity` (share of output lost): `MOTHBALLED`, `OWNER_<status>`, `LOW_DEMAND_TARGET`, `LABOR_<tier>`, `INPUT_<good>`, `ENERGY_RATIONED`, `WATER_RATIONED`, `CONDITION`, `UNLICENSED`, each with a readable `detail` |
| Why is project Y late? | `EconQuery.explain_project(world, pid)` | `NO_CONTRACTOR`, `CONTRACTOR_<status>`, `WORK_SUSPENDED_UNPAID`, `MATERIALS`, `UNSUPERVISED`, `NO_PROGRESS` |
| Why did this event happen? (briefing, news ticker, fact click) | `EconQuery.explain_fact(world, fact_id)` (wraps `FactStore.explain`) | chain `[{fact, month, type, location, data, responsible, magnitude}]`, root first |
| Suggested UI flow | Briefing item (fact) → explain_fact → if it references a facility/project in `data` → explain_facility / explain_project | |

## 6. Notifications (briefing feed)
Econ facts carry `magnitude` (briefing priority) and `visibility`. Suggested filter for the monthly report:
- always show magnitude ≥ 40 (shortages, outages, insolvencies, project completions, famine/default)
- group magnitude < 20 (accidents, rent rises) into one line per type.

Fact catalogue: [pic-economy.md §2](pic-economy.md).

## 6b. Implemented panels (M5)
`ui/panels/budget_panel.gd` (Budget), `projects_panel.gd` (Projects), `companies_panel.gd` (Companies), `why_panel.gd` (Why?), shared helpers `econ_kit.gd`.
New accessors: `EconQuery.shortages(world, threshold_pct=97)` (short goods/utilities → producers → causes), `EconQuery.recent_econ_facts(world, months, min_mag)`, `EconActions.pending(world)`, `EconActions.set_manual_award(world, on)` (player option), `EconActions.lines_for(type)` (E71).
"Propose…" in Budget pre-fills the Legislate panel (`prefill(lever, value)` if present, else its `clauses`). Interaction smoke: `tools/smoke_econ_ui.gd`.

## 7. Not provided yet (tell me if M5 needs them)
- Per-household-group drill-down (groups are internal; use VoterCells).
- Freight route visualisation (only aggregate capacity and deferrals are tracked).
- Company-level price history (only colony reference prices have history).
