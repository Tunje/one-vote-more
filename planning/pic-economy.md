# PIC Slice: Economy & Companies (owner `econ` / `comp`)

**Owner:** agent 88 · **Schema:** [pic-core.md](pic-core.md) v1 (used exactly) · **Mechanics:** [spec-economy-v1.md](spec-economy-v1.md) · **Date:** 2026-11-10
**Data files (M4):** `game/data/pic/econ_indicators.json`, `econ_facts.json`, `econ_levers.json`, `econ_actions.json`. The tables below are the source for those files.

---

## 0. Household → VoterCell mapping & census (pic-core §1.1, spec-politics §1)

**Census:** econ writes the census every month in `SOCIAL`:
```
world.table("census")[PolDefs.cell_key(district_id, OCC, BAND)] = voting adults (int)
```
- **Group key:** District × SkillTier(G/S/Sp) × IncomeBand.
- **Band:** each group's band **is** the VoterCell band. It is re-cut every January as population terciles of per-adult disposable income.
- **Occupation:** comes from members' employer sector (spec §7.2):

  | Employer sector | Occupation |
  |---|---|
  | Mines | MINING |
  | Farms | **AGRICULTURE** (8th occupation, A11) |
  | Utilities, plants, factories, contractors | INDUSTRY |
  | Service hubs, private landlords | SERVICES |
  | Public enterprises, institutions, administration | PUBLIC_SECTOR |
  | Private firm owners | BUSINESS_OWNER |
  | Unemployed | UNEMPLOYED |
  | Retired | RETIRED |

  Non-participating adults follow their group's employed mix.

  **Class rules (E67, 9 occupations).** All of these emerge from economy state; none is a quota.

  | Occupation | Who counts |
  |---|---|
  | **PROFESSIONAL** | Anyone filling a **Specialist-tier job slot**, whatever the employer: engineers, doctors, senior teachers, managers, technical administration, contractor engineers. Specialists working in lower-tier slots keep their employer-sector occupation. |
  | **BUSINESS_OWNER** | (a) the owner of each private firm; (b) 20% of non-specialist members of **agricultural co-ops** (the member-farmers; the rest are hired hands); (c) all worker-owners of **micro service co-ops** (E54); (d) **sole proprietors** (self-employed in local services/retail/private practice) |

  How sole proprietors work:
  - A founding 5% of the G/S labour force start as sole proprietors.
  - Entry: 5% a month of a group's unemployed, if the group has ≥ 3 months of essentials saved and local service prices are ≥ 90% of base.
  - They sell into local service demand after the hubs, and pay income tax.
  - Exit: 15% a month when earnings fall below the benefit level. Cap: 12% of a group's labour force.

  Measured with tools/measure_society.gd: BUSINESS_OWNER ≈ 7% (years 1–2), rising in slumps; PROFESSIONAL ≈ 5–6%.
- **Rounding:** cell populations are rounded by largest remainder, and zero cells are omitted.
- **Cell values:** a `VOTER_CELL` indicator value is the population-weighted mean of its contributing groups.
- **District ids:** `d:1`…`d:6` = Landing, Riverside, Redrock, Foundry, Greenhill, Northfield (D5 v1).
- **Size:** about 6 × 8 × 3 ≈ 100 non-empty cells at start.

**Storage convention:** indicator values are ints ×1000 of the display unit (6.5% → 6500; index 62 → 62000). The `normalize {good, bad}` values below are written in display units and are ×1000 in the data files.

## 1. Indicators

All indicators are finalized in `SOCIAL` unless stated otherwise. Normalize is linear and clamped to 0..100 satisfaction. Concern weights sum ≤ 1 per row.

| id | unit | range | gran. | pol. | concerns | normalize good / bad | phase | vis. | lag | Why voters care |
|---|---|---|---|---|---|---|---|---|---|---|
| ECON_UNEMPLOYMENT_RATE | % | 0–100 | DISTRICT | −1 | JOBS 1.0 | 3 / 15 | SOCIAL | PUBLIC | 0 | "Are there jobs here?" |
| ECON_JOB_RISK | % (unemployment of the cell's skill tiers in its district, incl. underemployed downgrades at 0.5) | 0–100 | VOTER_CELL | −1 | JOBS 0.8 · FAIRNESS 0.1 | 3 / 20 | SOCIAL | PUBLIC | 0 | "Could *I* lose my job / find one?" |
| ECON_REAL_INCOME_INDEX | index, 100 = month-1 value of the cell | 0–300 | VOTER_CELL | +1 | COST_OF_LIVING 0.5 · JOBS 0.2 | 115 / 85 | SOCIAL | PUBLIC | 3 | Living standards rising or falling |
| ECON_ESSENTIALS_SHARE | % of disposable income spent on food, water, energy, rent, min. goods | 0–200 | VOTER_CELL | −1 | COST_OF_LIVING 0.8 · HOUSING 0.1 | 40 / 85 | SOCIAL | PUBLIC | 0 | "Can we pay for the basics?" |
| ECON_ESSENTIAL_SHORTFALL | % of essential need unmet (food, water, energy, min. goods) | 0–100 | DISTRICT | −1 | COST_OF_LIVING 0.6 · PUBLIC_SERVICES 0.2 · GOVERNANCE 0.1 | 0 / 10 | SOCIAL | PUBLIC | 0 | Empty shelves and rationing are felt instantly |
| ECON_CPI_INFLATION | % year-on-year | −50–300 | COLONY | −1 | COST_OF_LIVING 0.5 · GOVERNANCE 0.1 | 2 / 12 | TRADE | PUBLIC | 2 | Rising prices erode wages |
| ECON_LOCAL_PRICE_INDEX | index, district delivered essentials price ÷ colony average × 100 | 50–200 | DISTRICT | −1 | COST_OF_LIVING 0.3 · FAIRNESS 0.2 | 95 / 120 | TRADE | PUBLIC | 1 | "Why is food dearer out here?" (remote districts) |
| ECON_RENT_BURDEN | % of disposable income on rent | 0–200 | VOTER_CELL | −1 | HOUSING 0.6 · COST_OF_LIVING 0.3 | 20 / 45 | SOCIAL | PUBLIC | 0 | Rent eating the paycheck |
| ECON_OVERCROWDING | households per dwelling unit | 0.5–3.0 | DISTRICT | −1 | HOUSING 1.0 | 0.95 / 1.30 | SOCIAL | PUBLIC | 0 | Families doubled up; no room for newcomers |
| ECON_UTILITY_RELIABILITY | % of household energy + water demand served (3-month avg) | 0–100 | DISTRICT | +1 | INFRASTRUCTURE 0.6 · PUBLIC_SERVICES 0.3 | 100 / 85 | PRODUCTION | PUBLIC | 0 | Blackouts and dry taps |
| ECON_INFRA_CONDITION | avg condition of road links and utility plants serving the district | 0–100 | DISTRICT | +1 | INFRASTRUCTURE 0.6 · SAFETY 0.1 | 90 / 50 | SOCIAL | PUBLIC | 3 | Visible decay of roads and plants |
| ECON_LOGISTICS_DELAY | % of deliveries into the district deferred for capacity (3-month avg) | 0–100 | DISTRICT | −1 | INFRASTRUCTURE 0.5 · COST_OF_LIVING 0.1 | 0 / 20 | TRADE | PUBLIC | 1 | Late goods, congested roads |
| ECON_HEALTH_ACCESS | % of residents covered by clinic capacity | 0–100 | DISTRICT | +1 | PUBLIC_SERVICES 0.6 · SAFETY 0.1 | 100 / 60 | PRODUCTION | PUBLIC | 0 | "Can we see a doctor?" |
| ECON_EDUCATION_ACCESS | % of school-age children with a seat | 0–100 | DISTRICT | +1 | PUBLIC_SERVICES 0.4 · FAIRNESS 0.2 | 100 / 60 | PRODUCTION | PUBLIC | 1 | Children's future; social mobility |
| ECON_POLLUTION_INDEX | index | 0–100 | DISTRICT | −1 | ENVIRONMENT_QUALITY 0.9 · SAFETY 0.1 | 10 / 70 | SOCIAL | PUBLIC | 2 | Smoke, dust, health worry next to industry |
| ECON_INCOME_RATIO | HIGH-band ÷ LOW-band mean disposable income per adult | 1–20 | DISTRICT | −1 | FAIRNESS 0.7 | 2.0 / 5.0 | SOCIAL | PUBLIC | 6 | Visible gap between rich and poor |
| ECON_TAX_BURDEN | % of gross income paid in income tax | 0–100 | VOTER_CELL | −1 | COST_OF_LIVING 0.3 · FAIRNESS 0.1 | 10 / 35 | SETTLEMENT | PUBLIC | 1 | Take-home pay |
| ECON_FINANCIAL_SECURITY | months of essentials covered by savings | 0–60 | VOTER_CELL | +1 | COST_OF_LIVING 0.3 · JOBS 0.2 | 6 / 0.5 | SOCIAL | PUBLIC | 1 | A cushion against bad months |
| ECON_REAL_WAGE_GROWTH | % yoy of the wage index deflated by CPI (cell's tiers) | −50–50 | VOTER_CELL | +1 | JOBS 0.3 · COST_OF_LIVING 0.3 | +3 / −5 | SOCIAL | PUBLIC | 3 | "Are my wages keeping up?" |
| ECON_GROWTH | % yoy change of real colony output | −50–50 | COLONY | +1 | JOBS 0.3 · GOVERNANCE 0.1 | +6 / −4 | SOCIAL | PUBLIC | 3 | "The economy is booming / stalling" |
| ECON_PROJECT_DELIVERY | % of government projects on schedule (12-month rolling) | 0–100 | COLONY | +1 | GOVERNANCE 0.5 · INFRASTRUCTURE 0.3 | 90 / 40 | PRODUCTION | PUBLIC | 1 | Does the government deliver what it promises? |
| ECON_COMPANY_FAILURES | firms entering ADMINISTRATION, 12-month count | 0–50 | COLONY | −1 | JOBS 0.2 · GOVERNANCE 0.1 | 0 / 4 | SETTLEMENT | PUBLIC | 0 | Closures signal a sick economy |
| ECON_IMPORT_DEPENDENCY | % of essentials supply (FOOD, MEDICAL) from imports, 12-month | 0–100 | COLONY | −1 | COST_OF_LIVING 0.1 · GOVERNANCE 0.1 | 5 / 50 | TRADE | PUBLIC | 3 | Self-reliance; exposure to ship delays |
| ECON_PUBLIC_DEBT_RATIO | % gov debt ÷ trailing-12-month revenue | 0–1000 | COLONY | −1 | GOVERNANCE 0.4 | 0 / 150 | SETTLEMENT | PUBLIC | 6 | Fear of bankruptcy / burden on the future |
| ECON_BUDGET_BALANCE | % (12-month surplus or deficit ÷ revenue) | −500–100 | COLONY | +1 | GOVERNANCE 0.3 | +5 / −40 | SETTLEMENT | PUBLIC | 6 | Competent stewardship |
| ECON_TREASURY_RUNWAY | months of government spending covered by cash + unused credit line | 0–240 | COLONY | +1 | GOVERNANCE 0.2 | 24 / 3 | SETTLEMENT | **OFFICIAL** | 0 | Government's own warning light (opposition via oversight) |
| ECON_MARKET_CONCENTRATION | HHI 0–10,000, max over essential sectors | 0–10,000 | COLONY | −1 | FAIRNESS 0.1 | 1,500 / 6,000 | SOCIAL | **OFFICIAL** | 6 | Monopoly pricing power (competition debates) |

**Concern coverage (pic-core §9):**
| Concern | Indicators |
|---|---|
| JOBS | 7 |
| COST_OF_LIVING | 11 |
| HOUSING | 3 |
| PUBLIC_SERVICES | 4 |
| SAFETY | 3 (minor weights). **Workplace safety itself is law's `LAW_WORKPLACE_SAFETY`, computed from econ's `COMP_WORKPLACE_ACCIDENT` facts** (agreed with a9, so it isn't double-counted) |
| ENVIRONMENT_QUALITY | 1 |
| INFRASTRUCTURE | 4 |
| FAIRNESS | 6 |
| GOVERNANCE | 9 (extra, allowed) |

**Month-1 expected satisfaction (for M2 stub calibration):**
- Unemployment 7.3% → JOBS ≈ 64.
- Essentials share ~55% average (LOW band ~75%) → ≈ 67 average / ≈ 22 LOW.
- Foundry pollution ≈ 62 → ≈ 13. Overcrowding Foundry/Greenhill 1.20 → ≈ 29.

---

## 2. Facts (`type` → schema fields)

**Phase and location:**
- Facts are emitted in the phase where they become true. Location is the district if any.
- `subjects` are the actors involved. `responsible` is the default visible split (politics splits GOVERNMENT further by ministry).
- PE = public enterprise (a `COMPANY` actor whose owner is government).

**Magnitude:** `clamp(base × share of colony population affected × 4, 5, 100)`, unless given explicitly.

| type | emitted in | subjects | responsible (shares) | impact (signed, per affected cell) | affected | magnitude | visibility | causes |
|---|---|---|---|---|---|---|---|---|
| ECON_SHORTAGE | TRADE | commodity sellers, buyers | Private supply failure: COMPANY 0.4 / GOVERNMENT 0.6 · import delay: EXTERNAL 0.5 / GOVERNMENT 0.5 · event: NATURE 0.6 / GOVERNMENT 0.4 | COST_OF_LIVING −(3 × shortfall%), cap −60 | districts with shortfall | 2 × shortfall% × pop share | PUBLIC | rationing record, upstream facts |
| ECON_UTILITY_OUTAGE | PRODUCTION | CPW | COMPANY(CPW) 0.3 / GOVERNMENT 0.7 | INFRASTRUCTURE −(4 × unserved%), PUBLIC_SERVICES −(1 × unserved%) | affected districts | 3 × unserved% | PUBLIC | capacity / condition facts |
| ECON_PRICE_SPIKE (≥ 10% in a month or ≥ 25% over 3 months) | TRADE | sellers | NATURE (market) 0.4 / COMPANY 0.2 / GOVERNMENT 0.4 | COST_OF_LIVING −(rise% × basket weight × 2) | ALL | rise% × weight × 3 | PUBLIC | shortage facts |
| ECON_LAYOFFS (≥ 10 workers or ≥ 20% of a firm) | PRODUCTION | company | COMPANY 0.7 / GOVERNMENT 0.3 | JOBS −(laid-off ÷ district workforce × 200) | district, occupations of the laid-off | n ÷ district workforce × 300 | PUBLIC | distress / mothball fact |
| ECON_HIRING_WAVE (≥ 20 net hires) | PRODUCTION | company | COMPANY 0.6 / GOVERNMENT 0.4 (credit) | JOBS +(hires ÷ workforce × 150) | district | as above | PUBLIC | project / facility fact |
| ECON_FACILITY_OPENED | PRODUCTION | owner, operator | Public: GOVERNMENT 0.7 / COMPANY 0.3 · private: COMPANY 0.8 / GOVERNMENT 0.2 | JOBS +5, + the facility's service concern +5 | district | 30 | PUBLIC | ECON_PROJECT_COMPLETED |
| ECON_FACILITY_CLOSED / _UNSAFE / _MOTHBALLED | PRODUCTION | operator | COMPANY 0.7 / GOVERNMENT 0.3 (PE: GOVERNMENT 0.8) | JOBS −10 (unsafe: SAFETY −10 too) | district | 35 | PUBLIC | condition / distress facts |
| ECON_TENDER_OPENED | DECISIONS | GOVERNMENT, project | GOVERNMENT 1.0 | none (announcement) | district | 10 | PUBLIC | action |
| ECON_TENDER_FAILED | COMPANY_AI | project | GOVERNMENT 0.7 / NATURE 0.3 | GOVERNANCE −5 | district | 20 | PUBLIC | contractor capacity |
| ECON_CONTRACT_AWARDED | DECISIONS | GOVERNMENT, OFFICIAL (awarder), contractor | GOVERNMENT 1.0 | none (`data.override`, `data.score_rank`) | district | 15 (40 if override) | PUBLIC | tender |
| ECON_CONTRACT_DELAYED (each late month) | PRODUCTION | contractor, project | COMPANY 0.6 / GOVERNMENT 0.4 | GOVERNANCE −3, INFRASTRUCTURE −2 | district | 15 + 5/month late | PUBLIC | shortage / labor / overrun facts |
| ECON_CONTRACT_SEVERELY_DELAYED (delay first reaches 4 months; law M6 dispute hook) | PRODUCTION | contractor, client | COMPANY 0.6 / GOVERNMENT 0.4 | GOVERNANCE −8 | district | 40 | PUBLIC | ECON_CONTRACT_DELAYED |
| ECON_CONTRACT_PAYMENT_MISSED (client misses a scheduled payment) | SETTLEMENT | client, contractor | Client GOVERNMENT → GOVERNMENT 1.0 · else COMPANY 1.0 | GOVERNANCE −5 (gov client) | district | 30 | PUBLIC | client cash facts |
| ECON_CONTRACT_FAILED | SETTLEMENT | contractor, project | COMPANY 0.6 / GOVERNMENT 0.4 | GOVERNANCE −10, INFRASTRUCTURE −5 | district | 50 | PUBLIC | COMP_INSOLVENCY |
| ECON_PROJECT_COMPLETED | PRODUCTION | GOVERNMENT, contractor | Public: GOVERNMENT 0.7 / COMPANY 0.3 | + the project's concern (housing block: HOUSING +15 in district) | district | 30 (housing 40) | PUBLIC | contract |
| ECON_PROJECT_CANCELLED | DECISIONS | GOVERNMENT | GOVERNMENT 1.0 | GOVERNANCE −5, the project's concern −5 | district | 30 | PUBLIC | action |
| ECON_RENT_INCREASE (≥ 3%) | SOCIAL | landlord(s) | Private: COMPANY 0.6 / GOVERNMENT 0.4 · public: GOVERNMENT 1.0 | HOUSING −(2 × %), COST_OF_LIVING −(1 × %) | district renters | 4 × % | PUBLIC | occupancy |
| ECON_RENT_ARREARS (district ≥ 5% of households) | SOCIAL | households, landlords | GOVERNMENT 0.6 / COMPANY 0.4 | HOUSING −5 | district LOW band | 20 | PUBLIC | income facts |
| COMP_WORKPLACE_ACCIDENT (each accident; model in spec §4.5, reads `LAW_SAFETY_STANDARD`) | PRODUCTION | operator | COMPANY 0.7 / GOVERNMENT 0.3 (PE: GOVERNMENT 0.8 / COMPANY 0.2) | SAFETY −(5 × workers_affected), cap −30 | district, the facility's occupation | 15 + 10 × workers_affected | PUBLIC | condition, violation (`data.in_violation`) |
| *(Unlawful operation: comp decides, then law emits `LAW_VIOLATION` (SECRET); spec §9.5. Econ emits no breach facts of its own.)* | | | | | | | | |
| ECON_POLLUTION_THRESHOLD (index crosses 50 or 75 upward) | SOCIAL | emitting operators | COMPANY 0.5 / GOVERNMENT 0.5 | ENVIRONMENT_QUALITY −10 / −20 | district + neighbors | 40 / 60 | PUBLIC | facility facts |
| ECON_IMPORT_ARRIVED | TRADE | importer | GOVERNMENT 0.5 / EXTERNAL 0.5 (credit) | COST_OF_LIVING +(relief) | ALL | 10–30 | PUBLIC | order |
| ECON_IMPORT_DELAYED | TRADE | importer | EXTERNAL 0.6 / GOVERNMENT 0.4 | COST_OF_LIVING −5 | ALL | 20 | PUBLIC | ship capacity / event |
| ECON_MIGRANTS_ARRIVED | TRADE | — | GOVERNMENT 0.5 / EXTERNAL 0.5 | none (population change) | districts settled | 10 | PUBLIC | quota lever |
| ECON_EMIGRATION | TRADE | households | GOVERNMENT 0.8 / NATURE 0.2 | GOVERNANCE −5, JOBS −5 | source district | 25 | PUBLIC | unemployment / shortfall |
| COMP_COMPANY_FOUNDED | COMPANY_AI | company, founder Person | COMPANY 0.8 / GOVERNMENT 0.2 | JOBS +3 | district | 15 | PUBLIC | price / import signal |
| COMP_DISTRESSED | SETTLEMENT | company | COMPANY 1.0 | none | — | 20 | **OFFICIAL** (tax filings) | missed payment |
| COMP_INSOLVENCY (enters ADMINISTRATION) | SETTLEMENT | company, creditors | COMPANY 0.7 / GOVERNMENT 0.3 | JOBS −(employees ÷ district workforce × 100) | district, employees' occupations | 30 + employees ÷ 5 | PUBLIC | COMP_DISTRESSED |
| COMP_RESTRUCTURED | SETTLEMENT | company | COMPANY 0.8 / GOVERNMENT 0.2 | JOBS +5 | district | 20 | PUBLIC | insolvency |
| COMP_LIQUIDATED | COMPANY_AI | company | COMPANY 0.7 / GOVERNMENT 0.3 | JOBS −(as layoffs) | district | 40 + employees ÷ 5 | PUBLIC | insolvency |
| COMP_CEO_REPLACED | COMPANY_AI | company, old/new Person | COMPANY 1.0 | none | — | 10 (25 if distress-triggered) | PUBLIC | retirement / distress |
| ECON_PE_FUNDING_REQUEST | SETTLEMENT | PE | GOVERNMENT 1.0 | none | — | 30 | **OFFICIAL** | PE cash |
| ECON_SUBSIDY_GRANTED | DECISIONS | GOVERNMENT, company | GOVERNMENT 1.0 | JOBS +2 (district) | district | 10–40 by size | PUBLIC | action |
| ECON_FACILITY_SOLD (privatization / nationalization / liquidation sale) | COMPANY_AI | seller, buyer | Seller GOVERNMENT → GOVERNMENT 1.0 · else COMPANY 0.6 / GOVERNMENT 0.4 | none | district | 30 | PUBLIC | action / liquidation |
| ECON_RESERVE_RELEASED | TRADE | GOVERNMENT | GOVERNMENT 1.0 | COST_OF_LIVING +(relief) | ALL | 15 | PUBLIC | action |
| ECON_LOGISTICS_BOTTLENECK | TRADE | CTA, link | GOVERNMENT 0.7 / COMPANY(CTA) 0.3 | INFRASTRUCTURE −5 | district | 15 | PUBLIC | volume |
| ECON_GOV_BORROWED (each +25 pp of debt ratio crossed) | SETTLEMENT | GOVERNMENT, bank | GOVERNMENT 1.0 | GOVERNANCE −5 | ALL | 30 | PUBLIC | deficit |
| ECON_BANK_CREDIT_FREEZE | SETTLEMENT | bank | EXTERNAL 0.7 / GOVERNMENT 0.3 | JOBS −5 | ALL | 50 | PUBLIC | bank cash |
| ECON_GRANT_ENDED (month 49) | SETTLEMENT | EXTERNAL | EXTERNAL 1.0 | none | ALL | 40 | PUBLIC | charter |
| ECON_SOVEREIGN_DEFAULT | SETTLEMENT | GOVERNMENT | GOVERNMENT 1.0 | GOVERNANCE −60, all concerns −10 | ALL | **100** | PUBLIC | borrowing facts · **A6 input** |
| ECON_FAMINE | SOCIAL | — | GOVERNMENT 0.8 / NATURE 0.2 | COST_OF_LIVING −80, GOVERNANCE −40 | ALL | **100** | PUBLIC | shortage facts · **A6 input** |
| ECON_LEVER_EFFECTIVE (pic-core `*_LEVER_EFFECTIVE`) | STAFF→read in TRADE | GOVERNMENT | GOVERNMENT 1.0 | none (effects come via indicators) | per lever scope | 5–30 | PUBLIC | `POL_LEVER_CHANGED` |

---

> **ECON_ACTION_FAILED** (E73): OFFICIAL, subject GOVERNMENT, responsible GOVERNMENT 1.0, magnitude 35, no impact; data `{action, params, error}`. Emitted when a queued econ action fails at apply time.

### 2b. Interest groups, economy side (M9, spec-politics-v2 §5, E79). Code: `sim/economy/econ_unions.gd`

**Indicator `ECON_UNION_DENSITY`**:
- % of employed workers who are union members, ×1000 (0..100000). Granularity is **`OCCUPATION`** (a new granularity): the key is the occupation (`INDUSTRY`, `MINING`, `AGRICULTURE`, `SERVICES`, `PROFESSIONAL`, `PUBLIC_SECTOR`). Written in SOCIAL. It has no concern weights, so it does not move satisfaction; politics reads it as union strength.
- Each month density moves 1/12 of the way toward a target. The target is the occupation's base density (34 / 45 / 14 / 12 / 10 / 48) multiplied by:
  - union rights: 0.4 + 1.2 × `ECON_UNION_RIGHTS`/100;
  - safety standard: +4% per step;
  - sector size: 0.6..1.4, rising with the sector's share of jobs;
  - grievance: up to 1.3;
  - fear: falls when colony unemployment is above 10%.

**New lever `ECON_UNION_RIGHTS`** (0..100, default 50, LAW):
- Collective-bargaining rights. Ideology LABOR +0.8. Concerns: FAIRNESS +25, SAFETY +10, JOBS −10.
- It drives union density, and makes lockouts less likely.

**Facts** (all PUBLIC, emitted in COMPANY_AI):

| Fact | When | Responsible | Impact | Magnitude | Data |
|---|---|---|---|---|---|
| `ECON_STRIKE` | Chance per org each month = density × grievance × 0.035. At most 2 new stoppages a month in the colony, and at most 1 strike per org per 12 months. Grievance = real wages falling (12-month G+S real wage growth below −2%), plus adverse labor-law changes in the last 12 months (decaying; see note), plus the org's own layoffs (≥10% of staff). | `LABOR_LAW`: GOVERNMENT 1.0. `REAL_WAGES`: GOVERNMENT 1.0 at public employers, otherwise GOVERNMENT 0.7 / COMPANY 0.3. `LAYOFFS`: company blame 0.8 (public enterprises mostly blamed on the government). | JOBS −40, FAIRNESS −15, COST_OF_LIVING −20; PUBLIC_SERVICES −60 if a clinic, school, depot or utility is hit | 30..75 by number of strikers, +10 for public services (max 85) | `{org, occupation, persons, months, cause, union_density_pct, real_wage_growth_x10}` |
| `ECON_LOCKOUT` | Instead of bargaining, a PRIVATE employer may lock out its workers. Chance = CEO risk/100 × (0.25 + 0.5 × (1 − union rights/100)). The lockout's cause is the strike fact. | company blame 0.8 | JOBS −50, FAIRNESS −30 | strike + 5 | `{org, persons, months}` |
| `ECON_LAYOFFS_MASS` | An org lays off ≥ 15 persons in one month, and they are ≥ 20% of its workforce. At most one fact per org per 6 months. | company blame 0.7 | JOBS −(4 × persons, 40..300), FAIRNESS −20 | 30..80 | `{org, persons, share_pct, closing}` |

Note on adverse labor-law changes: these are cuts to `ECON_UNION_RIGHTS`, `ECON_MIN_WAGE` or `ECON_UNEMPLOYMENT_BENEFIT_RATE`, a downgrade of `LAW_SAFETY_STANDARD`, or a cut to `ECON_PUBLIC_PAY_INDEX` (that one counts for the public sector only). Each change is weighted by the size of the cut.

**Effects of a stoppage** (1–2 months, starting next month): every facility of the org works at 50% labor effectiveness during a strike, or 20% during a lockout. A strike that is not met with a lockout wins a wage premium of +4% (`org.union_pm`, capped at 12%, decaying 0.4 points a month). Wages are still paid during a stoppage.

**Table `donation_offer`**:
- Rewritten at the end of SETTLEMENT every month. Each row is keyed by company id: `{from, amount_milli, prefers: {axis: ±1}, month}`.
- Only ACTIVE PRIVATE companies and cooperatives that made a profit this month make offers.
- `prefers` holds the top two exposures with weight ≥ 0.2:
  - profit tax: REDISTRIBUTION −1;
  - labor cost (wage share × union density, minimum-wage bite, union premium): LABOR −1;
  - polluting plants: ENVIRONMENT −1;
  - state as customer (subsidies, public contracts): ECON_ROLE +1;
  - co-ops: LABOR +1 and REDISTRIBUTION +1.
- Amount = profit × 6% × summed exposure weight (capped at 1.5), and never more than the cash left after keeping 4 months of costs. Offers under 2000 cr are not made.
- **Politics books the match**: `ledger.transfer(EconUtil.acct(from), "party:<id>", amount_milli, ...)` in POLITICS. If the transfer returns false, the offer lapses. The offer itself moves no money.

### 2c. Facts that get an `exposure` block in M10 S4 (spec-population-v1 §6.1). PLANNED, not built yet

Until S7, housing block = district (`hb:d:N`), so a district-wide scope covers the whole parent block. That makes it a **shared** effect, which creates no split.

**Proposed additions to the `exposure` schema:**
- `scope.inc`: a list of income bands (I1–I5).
- `scope.moved`: the id of the fact whose transfers are targeted. It selects exactly the people moved by `PopStore.transfer` calls that carry that fact id as context this month.

Decay is in per-mille per month. "Persistent" exposures are recomputed from their source indicator each month instead of decaying.

| Fact | `kind` | Scope | `share` | `intensity` | Decay / persistent | Notes |
|---|---|---|---|---|---|---|
| `ECON_POLLUTION_THRESHOLD` | POLLUTION | housing of the district | 1000 (shared) | from `ECON_POLLUTION_INDEX` (bad = 70 → 1000) | persistent | After S7, only the blocks near the emitting facilities. HEALTH and ENVIRONMENT_QUALITY conditions |
| `COMP_WORKPLACE_ACCIDENT` | UNSAFE_WORK | `employer` = org, `occ` of the facility, status EMPLOYED | 1000 of that employer's workers (from the employment allocations) | 300–800 by casualties | 150 | WORK_CONDITIONS, SAFETY |
| `ECON_FACILITY_CLOSED_UNSAFE` | UNSAFE_WORK | as above | 1000 | 600 | 100 | |
| (new, monthly) `ECON_HAZARD_CONDITIONS` | UNSAFE_WORK | workers of HIGH-hazard facilities while `LAW_SAFETY_STANDARD` = BASIC | 1000 | 300 | persistent | Only if Wilma wants a standing condition, not just accidents |
| `ECON_LAYOFFS_MASS` | JOB_LOSS | `moved` = the layoff transfers of that org this month, plus (optionally) a 100-share community exposure on the org's district | 1000 | 400–900 by size | 80 | The laid-off people carry it into UNEMPLOYED. JOBS, grievance against the perceived cause |
| `COMP_LIQUIDATED`, `COMP_INSOLVENCY` (when the closure lays people off) | JOB_LOSS | as above | 1000 | 700 | 80 | |
| `ECON_STRIKE` | STRIKE | `employer` = org | 1000 | from magnitude | 300 | WORK_CONDITIONS. The lockout is the same with a higher intensity |
| `ECON_LOCKOUT` | STRIKE | `employer` = org | 1000 | magnitude + 200 | 300 | |
| `ECON_RENT_INCREASE` | RENT_RISE | housing of the district, `inc` I1–I3 (the renters under burden) | 1000 within scope | from the rent change % | 100 | HOUSING, COST_OF_LIVING |
| `ECON_SHORTAGE` | SHORTAGE | housing of the district, `inc` = bands with unmet essentials | 1000 within scope | from shortfall ‰ | 300 | Data gains `cause` (PD §12.5): `NO_SUPPLY` / `UNAFFORDABLE` / `INACCESSIBLE`. Consumption runs per (housing block × income band) from S2, so the cause is known per band |
| `ECON_UTILITY_OUTAGE` | OUTAGE | districts not fully served | 1000 | from the unserved share | 400 | INFRASTRUCTURE, HEALTH |
| `ECON_FAMINE` | SHORTAGE | colony | 1000 (shared) | 1000 | 150 | |

All of these facts are already emitted today. S4 adds only the `exposure` field and, for the shortage cause, a `data.cause`.

## 3. Policy levers

**Conventions:**

| Topic | Rule |
|---|---|
| **Units** | Lever values are ints in the unit shown: % = whole percent, cr = whole credits, `k cr/yr` = thousands of credits per year. Ranges are sized so a political clause (10% of range, spec-politics §5) is a meaningful step. |
| **`ideology`** | Slope **per 1 lever unit**: `{axis: slope}` (politics multiplies by Δ × 300 milli-points). |
| **`concerns`** | Expected signed relief **per full range** (low → high), used as the AI hint (spec-politics §6). GOVERNANCE hints on spending levers are negative because they worsen `ECON_BUDGET_BALANCE` / `ECON_PUBLIC_DEBT_RATIO`. |
| **`fiscal`** | Owner estimator: Δ monthly budget (+ = more revenue / less spend) from trailing-3-month bases. Month-1 values are shown. |
| **`implementation`** | One of a9's five classes (spec-law §6.1; `null` is not allowed). |
| **Who writes** | **Law is the single writer of operative lever values** (Wilma A8). Econ defines levers here and only *reads* `world.levers`. |
| **Legislatable** | Politics can legislate every lever below except two: `ECON_ENERGY_PRIORITY` (ENUM, ADMIN; changed only by ministerial decision) and `ECON_ORIGIN_GRANT` (CHARTER, LOCKED). |

**Charter bounds** (law enforces):
- any tax rate ≤ 50%
- `ECON_MIN_WAGE` ≥ 40% of W_ref

**Levers econ reads but law owns:** `LAW_SAFETY_STANDARD` (accident and compliance-cost model), `LAW_EXTRACTION_ROYALTY` and the `LAW_FEE_*` levers (operator costs), `LAW_LICENCE_REGIME_*` (licence gating via `validate`), `LAW_INSPECTORS` (misconduct rule).

| id | type | unit | range | default | legalLevel | foundingEra | ideology (per unit) | concerns (per full range) | fiscal estimator (month 1) | implementation | lag | scope |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ECON_INCOME_TAX_RATE | NUMBER | % | 0–50 | 20 | LAW | COMMANDER | REDISTRIBUTION 4, ECON_ROLE 1 | COST_OF_LIVING −40, FAIRNESS +10, GOVERNANCE +20 | `est_income_tax`: +1 ≈ +7,200 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_TAX_ALLOWANCE | NUMBER | cr/month | 0–2,000 | 300 | LAW | COMMANDER | REDISTRIBUTION 0.03 | COST_OF_LIVING +30, FAIRNESS +25, GOVERNANCE −20 | `est_income_tax`: +100 ≈ −21,200 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_PROFIT_TAX_RATE | NUMBER | % | 0–50 | 20 | LAW | COMMANDER | REDISTRIBUTION 2, ECON_ROLE 2 | JOBS −30, FAIRNESS +20, GOVERNANCE +10 | `est_profit_tax`: +1 ≈ +1,250 cr (quarterly) | STAFF_T_IMPL_FISCAL | 3 | COLONY |
| ECON_IMPORT_TARIFF | NUMBER | % | 0–50 | 0 | LAW | COMMANDER | ECON_ROLE 0.3, AUTONOMY 0.2 | COST_OF_LIVING −15, JOBS +10 | `est_tariff`: +10 × private import value (≈ 0 at start) | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_MIN_WAGE | NUMBER | % of W_ref | 40–150 | 40 (= 480 cr, non-binding) | LAW | COMMANDER | LABOR 0.6, ECON_ROLE 0.2 | COST_OF_LIVING +30, FAIRNESS +25, JOBS −30 | `est_min_wage`: public payroll uplift (0 until > 67) | STAFF_T_IMPL_REGULATORY | 2 | COLONY |
| ECON_UNEMPLOYMENT_BENEFIT_RATE | NUMBER | % of W_G | 0–80 | 40 | LAW | COMMANDER | REDISTRIBUTION 0.6, LABOR 0.3, FISCAL 0.2 | COST_OF_LIVING +30, FAIRNESS +20, GOVERNANCE −15 | `est_welfare`: +10 ≈ −6,600 cr | STAFF_T_IMPL_PROGRAM | 1 | COLONY |
| ECON_BENEFIT_DURATION | NUMBER | months | 3–60 | 12 | LAW | COMMANDER | REDISTRIBUTION 0.5 | COST_OF_LIVING +15, FAIRNESS +10, GOVERNANCE −10 | `est_welfare`: +6 ≈ −1,500 cr | STAFF_T_IMPL_PROGRAM | 1 | COLONY |
| ECON_PENSION_RATE | NUMBER | % of W_G | 0–100 | 50 | LAW | COMMANDER | REDISTRIBUTION 0.4, FISCAL 0.2 | COST_OF_LIVING +25, GOVERNANCE −20 | `est_welfare`: +10 ≈ −9,600 cr | STAFF_T_IMPL_PROGRAM | 1 | COLONY |
| ECON_PUBLIC_PAY_INDEX | NUMBER | % of wage index | 80–130 | 100 | REGULATION | COMMANDER | LABOR 0.6, FISCAL 0.6, ECON_ROLE 0.2 | PUBLIC_SERVICES +20, JOBS +5, GOVERNANCE −25 | `est_public_pay`: +5 ≈ −14,500 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_UTILITY_TARIFF_ENERGY | NUMBER | cr/unit | 10–120 | 40 | ADMIN | COMMANDER | REDISTRIBUTION −0.6, ECON_ROLE −0.4, FISCAL −0.4 | COST_OF_LIVING −35, INFRASTRUCTURE +10, GOVERNANCE +15 | `est_pe_tariff`: −5 ≈ −5,000 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_UTILITY_TARIFF_WATER | NUMBER | cr/unit | 5–60 | 20 | ADMIN | COMMANDER | REDISTRIBUTION −0.6, ECON_ROLE −0.4, FISCAL −0.4 | COST_OF_LIVING −25, GOVERNANCE +10 | `est_pe_tariff`: −5 ≈ −6,000 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_FREIGHT_TARIFF | NUMBER | cr per unit-link | 1–20 | 5 | ADMIN | COMMANDER | ECON_ROLE −1, AUTONOMY −1 | COST_OF_LIVING −10, INFRASTRUCTURE +10, GOVERNANCE +5 | `est_pe_tariff`: −1 ≈ −2,700 cr | STAFF_T_IMPL_ADMIN | 1 | COLONY |
| ECON_PUBLIC_RENT | NUMBER | cr/unit-month | 100–600 | 250 | ADMIN | COMMANDER | REDISTRIBUTION −0.12, FISCAL −0.04 | HOUSING −40, COST_OF_LIVING −20, GOVERNANCE +15 | `est_pe_tariff`: −25 ≈ −6,250 cr | STAFF_T_IMPL_ADMIN | 1 | COLONY |
| ECON_RENT_INCREASE_CAP | NUMBER | % per year, private rents (0 = freeze, 20 = uncapped) | 0–20 | 20 | LAW | COMMANDER | ECON_ROLE −1.5, REDISTRIBUTION −1 | HOUSING −15, COST_OF_LIVING −10 (short run; long-run supply effect in the estimator table) | 0 (private sector) | STAFF_T_IMPL_REGULATORY | 2 | COLONY |
| ECON_PE_DIVIDEND_RATE | NUMBER | % | 0–100 | 50 | REGULATION | COMMANDER | ECON_ROLE −0.2, FISCAL −0.1 | GOVERNANCE +10, INFRASTRUCTURE −10 | `est_pe_dividend`: −10 ≈ −1,400 cr | STAFF_T_IMPL_FISCAL | 3 | COLONY |
| ECON_PROCUREMENT_PRICE_WEIGHT | NUMBER | % weight on price in bid scores (rest split 60/40 reliability/duration) | 30–100 | 50 | REGULATION | COMMANDER | FISCAL −0.3, INSTITUTIONS −0.1 | GOVERNANCE −10, INFRASTRUCTURE −10 | `est_procurement`: ±5% of tender prices | STAFF_T_IMPL_REGULATORY | 1 | COLONY |
| ECON_EMISSION_REDUCTION | NUMBER | % emission cut required (input-cost uplift = 0.27 × value %) | 0–40 | 0 | REGULATION | COMMANDER | ENVIRONMENT 1.2, ECON_ROLE 0.3 | ENVIRONMENT_QUALITY +60, JOBS −15, COST_OF_LIVING −5 | `est_emission`: PE cost uplift ≈ −100 cr per 1 | STAFF_T_IMPL_REGULATORY | 3 | COLONY |
| ECON_IMMIGRATION_QUOTA | NUMBER | persons/ship | 0–120 | 60 | LAW | COMMANDER | FISCAL 0.1, LABOR −0.1, INSTITUTIONS 0.05 | JOBS −10, HOUSING −20, GOVERNANCE +5 | `est_immigration`: +20 ≈ +2,500 cr after 6 months | STAFF_T_IMPL_ADMIN | 3 | COLONY |
| ECON_HEALTH_FEE | NUMBER | cr per person-month | 0–100 | 0 | LAW | COMMANDER | REDISTRIBUTION −0.5, ECON_ROLE −0.3 | PUBLIC_SERVICES −30, COST_OF_LIVING −15, GOVERNANCE +15 | `est_fees`: +10 ≈ +18,000 cr (minus coverage loss) | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_SCHOOL_FEE | NUMBER | cr per pupil-month | 0–200 | 0 | LAW | COMMANDER | REDISTRIBUTION −0.25, ECON_ROLE −0.15 | PUBLIC_SERVICES −25, FAIRNESS −15, GOVERNANCE +10 | `est_fees`: +20 ≈ +6,500 cr | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_BUDGET_ADMIN | NUMBER | k cr/yr | 0–4,000 | 1,300 | LAW | COMMANDER | FISCAL 0.0077, INSTITUTIONS −0.0077 | GOVERNANCE +30 | Δ × 1000 / 12 | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_BUDGET_HEALTH | NUMBER | k cr/yr | 0–4,000 | 860 | LAW | COMMANDER | REDISTRIBUTION 0.023, ECON_ROLE 0.012, FISCAL 0.012 | PUBLIC_SERVICES +60, SAFETY +5, GOVERNANCE −20 | Δ × 1000 / 12 | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_BUDGET_EDUCATION | NUMBER | k cr/yr | 0–3,000 | 550 | LAW | COMMANDER | REDISTRIBUTION 0.036, ECON_ROLE 0.018, FISCAL 0.018 | PUBLIC_SERVICES +40, FAIRNESS +20, GOVERNANCE −15 | Δ × 1000 / 12 | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_BUDGET_TRAINING | NUMBER | k cr/yr | 0–2,000 | 0 | LAW | COMMANDER | LABOR 0.02, ECON_ROLE 0.02 | JOBS +25, FAIRNESS +10, GOVERNANCE −10 | Δ × 1000 / 12 | STAFF_T_IMPL_PROGRAM | 1 | COLONY |
| ECON_BUDGET_INFRASTRUCTURE | NUMBER | k cr/yr (capex appropriation) | 0–15,000 | 3,600 | LAW | COMMANDER | FISCAL 0.0056, ECON_ROLE 0.0028 | INFRASTRUCTURE +50, JOBS +20, GOVERNANCE −30 | commitments, not monthly spend | STAFF_T_IMPL_FISCAL | 0 | COLONY |
| ECON_BUDGET_HOUSING | NUMBER | k cr/yr (public housing capex) | 0–10,000 | 1,600 | LAW | COMMANDER | REDISTRIBUTION 0.0125, ECON_ROLE 0.0125, FISCAL 0.006 | HOUSING +60, JOBS +10, GOVERNANCE −25 | commitments | STAFF_T_IMPL_FISCAL | 0 | COLONY |
| ECON_BUDGET_SUBSIDIES | NUMBER | k cr/yr | 0–3,000 | 0 | LAW | COMMANDER | ECON_ROLE 0.03, FISCAL 0.01 | JOBS +25, FAIRNESS −5, GOVERNANCE −15 | Δ × 1000 / 12 | STAFF_T_IMPL_PROGRAM | 1 | COLONY |
| ECON_BUDGET_RESERVE_PURCHASES | NUMBER | k cr/yr | 0–2,000 | 200 | LAW | COMMANDER | ECON_ROLE 0.01, AUTONOMY 0.01 | COST_OF_LIVING +10, GOVERNANCE −5 | Δ × 1000 / 12 | STAFF_T_IMPL_FISCAL | 1 | COLONY |
| ECON_ENERGY_PRIORITY | ENUM (ADMIN decision only) | — | HOUSEHOLDS_FIRST / INDUSTRY_FIRST | HOUSEHOLDS_FIRST | ADMIN | COMMANDER | INDUSTRY_FIRST: REDISTRIBUTION −10, ECON_ROLE −3 (applied as a one-off step) | — | 0 | STAFF_T_IMPL_ADMIN | 0 | COLONY |
| ECON_ORIGIN_GRANT | NUMBER | cr/month | fixed schedule | 200,000 → 0 at month 49 | CHARTER | LOCKED | — | — | as scheduled | STAFF_T_IMPL_ADMIN (never changed in v1) | 0 | COLONY |

**Notes:**
- **ENUMs converted for legislation (E41):** the earlier ENUM levers are replaced by numeric equivalents with the same mechanics:

  | Old ENUM | New lever | Old value → new value |
  |---|---|---|
  | `ECON_RENT_CONTROL` | `ECON_RENT_INCREASE_CAP` | NONE = 20, CAP_3PCT_YEAR = 3, FREEZE = 0 |
  | `ECON_PROCUREMENT_RULE` | `ECON_PROCUREMENT_PRICE_WEIGHT` | LOWEST_PRICE = 100, BALANCED = 50, QUALITY_FIRST = 30 |
  | `ECON_EMISSION_STANDARD` | `ECON_EMISSION_REDUCTION` | BASIC = 0, STANDARD = 15, STRICT = 30 (cost +4% / +8%) |

- **Law-owned safety:** econ previously proposed `ECON_WORKPLACE_SAFETY_STANDARD`. It is withdrawn in favour of `LAW_SAFETY_STANDARD` (one lever, law-owned). Econ's compliance-cost model reads that lever: STANDARD +3% wages, STRICT +7%.

**Policy-effect estimators for party AI (`econ.estimate_concerns(lever_deltas) -> {concernId: Δ0..100 per cell class}`).** These are linear v1 elasticities. They are applied to cells by occupation and band, and re-fitted from soak runs at M4.

| Lever change | Predicted concern effect (satisfaction points) |
|---|---|
| Income tax +1 pp | COST_OF_LIVING −0.8 (employed MID/HIGH), −0.3 (employed LOW) |
| Allowance +100 cr | COST_OF_LIVING +2.0 (LOW), +1.0 (MID) |
| Benefit +10 pp | COST_OF_LIVING +6 (UNEMPLOYED); FAIRNESS +1 (all LOW) |
| Pension +10 pp | COST_OF_LIVING +5 (RETIRED) |
| `ECON_MIN_WAGE` +10 (% of W_ref, once above the market wage) | COST_OF_LIVING +3 (LOW employed); JOBS −2 (LOW, after 6 months) |
| Utility tariff −5 cr | COST_OF_LIVING +1.5 (LOW), +0.8 (others) |
| Public rent −25 cr | HOUSING +3 (public renters, LOW/MID) |
| `ECON_RENT_INCREASE_CAP` 20 → 3 / 0 | HOUSING +3 / +6 now; HOUSING −2 / −5 after 24 months (supply response) |
| `ECON_EMISSION_REDUCTION` 0 → 15 / 30 | ENVIRONMENT_QUALITY +8 / +15 (industrial districts) after 6 months; JOBS −1 / −3 (INDUSTRY, MINING) |
| `LAW_SAFETY_STANDARD` STANDARD / STRICT (law lever; econ supplies the effect) | SAFETY +6 / +12 (MINING, INDUSTRY); JOBS −0.5 / −1.5 |
| Health budget +10% | PUBLIC_SERVICES +4 (when access < 100%) |
| Education budget +10% | PUBLIC_SERVICES +3; FAIRNESS +1 (after 12 months) |
| Infrastructure / housing budget +10% | INFRASTRUCTURE / HOUSING +2 after build time (6–8 months) |

---

## 4. Actions

All actors use the same actions (pic-core §6). `legalAction` uses a9's closed taxonomy (spec-law §3). `staffTask` uses a9's catalogue (spec-staff §10). The `COMMANDER` actor exists before the first government only.

| id | actors | cost | legalAction (params) | preconditions | effects | aiHints |
|---|---|---|---|---|---|---|
| ECON_COMMISSION_PROJECT | PLAYER_GOV, AI_GOV, COMMANDER | `{staffTask: STAFF_T_PROCURE}` (spec, 1-month tender, evaluation); credits = commitment at award | `BUILD_FACILITY{facility_type, district, owner_kind: GOV, value_wref}` (permit via law) | Budget line headroom ≥ 1.1 × estimate; zone compatible; district connected, or the project is a road link | Project (with `size_class`) + tender; fact ECON_TENDER_OPENED. On award, `STAFF_T_SUPERVISE` becomes assignable. | `est_cost`, `months_to_effect`, target indicator Δ |
| ECON_AWARD_CONTRACT | PLAYER_GOV, AI_GOV, COMMANDER (or the official delegated on STAFF_T_PROCURE automatically) | award step of STAFF_T_PROCURE; 10% advance | `AWARD_CONTRACT{contract_type: CONSTRUCTION, value_wref, method: OPEN}` (method DIRECT if below `LAW_DIRECT_AWARD_THRESHOLD`) | Tender closed, ≥ 1 bid | Contract; advance; commitment; fact ECON_CONTRACT_AWARDED (`override` if not top score) | bid scores, reliability, distress flag (OFFICIAL) |
| ECON_RETENDER_PROJECT | PLAYER_GOV, AI_GOV, COMMANDER | `{staffTask: STAFF_T_PROCURE}` | `AWARD_CONTRACT` (re-run) | Tender failed or contract failed | New tender (optional budget increase) | |
| ECON_CANCEL_PROJECT | PLAYER_GOV, AI_GOV, COMMANDER | progress to date + 5% of remaining; covered by `STAFF_SD_PROCUREMENT` | `TERMINATE_CONTRACT{contract_type, reason: CONVENIENCE}` | Not complete | Contract ended, commitment released; fact ECON_PROJECT_CANCELLED | savings vs lost progress |
| ECON_TERMINATE_FOR_BREACH | PLAYER_GOV, AI_GOV, COMMANDER | none (retention kept); `STAFF_SD_PROCUREMENT` | `TERMINATE_CONTRACT{reason: BREACH}` | ≥ 4 months late, or contractor in ADMINISTRATION | Contract ended, no compensation, contractor reliability ×0.5; project TENDERABLE (M6: contractor may dispute) | |
| ECON_SET_BUDGET | COMMANDER (provisional ordinance); PLAYER_GOV, AI_GOV (budget bill, POL) | `{staffTask: STAFF_T_BUDGET}` (deadline = budget month) | `SET_LEVER` on the `ECON_BUDGET_*` levers | — | Bundle of `ECON_BUDGET_*` changes for the next fiscal year (or a supplementary) | fiscal estimators; projected debt ratio over 24 months |
| ECON_SUBSIDIZE | PLAYER_GOV, AI_GOV, COMMANDER | credits from the SUBSIDIES line; `{staffTask: STAFF_T_IMPL_PROGRAM}` | `GRANT_SUBSIDY{sector, amount_wref}` | Line headroom | Monthly transfer to an org for N months; fact ECON_SUBSIDY_GRANTED | jobs protected per credit |
| ECON_RESCUE_LOAN | PLAYER_GOV, AI_GOV, COMMANDER | credits from the SUBSIDIES line (repayable); `{staffTask: STAFF_T_IMPL_PROGRAM}` | `GRANT_SUBSIDY{sector, amount_wref}` | Org DISTRESSED or in ADMINISTRATION | Government loan to the firm (gov is creditor) | jobs at risk, recovery odds |
| ECON_BUY_FACILITY | PLAYER_GOV, AI_GOV, COMMANDER | price (liquidation ≥ 40% of book; willing seller = ask); INFRASTRUCTURE line; `STAFF_SD_PROCUREMENT` | `SPEND{budget_line, amount_wref}`, or `EXPROPRIATE{asset_kind: FACILITY, compensation_pct ≥ 100}` if compulsory (market value := book value) | Facility in liquidation, abandoned, or owner willing; compulsory needs a LAW | Facility → a PE/institution; fact ECON_FACILITY_SOLD | ECON_ROLE +, jobs saved |
| ECON_SELL_FACILITY (privatize) | PLAYER_GOV, AI_GOV | `{staffTask: STAFF_T_PROCURE}` (auction) | **`SELL_ASSET{asset_kind, value_wref}` — new type requested from a9** | Government-owned facility | Sealed-bid auction in next COMPANY_AI, reserve 60% of book; fact ECON_FACILITY_SOLD | one-off revenue; ECON_ROLE − |
| ECON_ORDER_IMPORTS | PLAYER_GOV, AI_GOV, COMMANDER | credits from the RESERVE_PURCHASES line, paid at order; `STAFF_SD_PROCUREMENT` | `IMPORT_GOOD{resource, qty}` | Cargo space on the target ship | Cargo reservation; into the government reserve on arrival | months to arrival, shortage forecast |
| ECON_RELEASE_RESERVE | PLAYER_GOV, AI_GOV, COMMANDER | none (sales revenue to treasury) | `SELL_GOOD{resource, buyer_kind: ANY}` | Reserve stock > 0 | Offer qty at a chosen price (≥ 0.5 × P_r) in next TRADE; fact ECON_RESERVE_RELEASED | shortage relief |
| ECON_BORROW | COMMANDER, PLAYER_GOV, AI_GOV | none (debt) | `BORROW{amount_wref, lender: "bank"}`. The charter authorizes the commander up to the Colony Bank credit line (spec §12.2). Later, the budget law. | Credit line headroom | Treasury +amount, debt +amount; fact ECON_GOV_BORROWED | debt ratio Δ, interest cost |
| ECON_REPAY_DEBT | PLAYER_GOV, AI_GOV, COMMANDER | credits; `STAFF_SD_FINANCE` | `SPEND{budget_line: DEBT, amount_wref}` | Debt > 0, cash available | Debt reduced | debt ratio Δ |
| ECON_PUBLISH_FISCAL_REPORT | PLAYER_GOV, AI_GOV | `{staffTask: STAFF_T_REPORT}` | `INTERNAL` | — | OFFICIAL econ indicators become PUBLIC for 1 month | INSTITUTIONS +; GOVERNANCE + if healthy |
| ECON_REQUEST_ECON_BRIEFING | PLAYER_GOV, AI_GOV; OPPOSITION via oversight | `{staffTask: STAFF_T_REPORT}` (opposition: `STAFF_T_OVERSIGHT`) | `INTERNAL` | — | Reveals OFFICIAL econ indicators to the requester | |

**Lever changes are not econ actions.** They go through POL bills, regulations or decisions, and law writes the operative value (A8). Econ supplies definitions, estimators and effects only.

**Firm-side legal calls are not PIC actions either** (companies are not PIC actors). They are internal calls to `law.validate`, described in spec §9.5.

---

## 5. Needs from other owners
| From | Need |
|---|---|
| Wilma (map D5) | ✅ Accepted as D5 v1 (A11). ~~Confirm or replace the 6-district proposal (spec §3.1): adjacency, link capacities, zoning per district (zone must allow the starting facilities, e.g. Redrock = MINING for law's LICENCE_EXTRACTION). |
| Wilma (kernel) | `world.values` dictionary (or equivalent) for `ECON_W_REF` and `LAW_RULES_VERSION`. Ledger changes L1–L7 (spec §16), which I implement at M4 start. |
| Wilma (D2/D6) | Ship schedule events (cancelled/halved ship); A6 consumption of `ECON_SOVEREIGN_DEFAULT` / `ECON_FAMINE`. |
| a9 (law) | Add `SELL_ASSET{asset_kind, value_wref}` to the LegalActionType enum (privatization), confirm the `INTERNAL` type, and expose `law.record_violation(actor, action, params)`. Hazard classes and licences per facility are in spec §4.1. Starting facilities are pre-licensed at month 1 (spec §9.5). |
| a9 (staff) | `STAFF_T_SUPERVISE` coverage `s` per project, readable by econ in PRODUCTION (spec §10.1). |
| a9 (Person) | Person roles CEO and OWNER with skill `MANAGEMENT` (0–100), trait `RISK` (0–100), and age (retire at 65). |
