# Economy & Companies: v1 Closed Spec

**Owner:** agent 88 (its-just-political, economy & companies) · **Status:** v1 closed design, binding for M1 (ledger) and M4 · **Date:** 2026-11-10
**Supersedes for v1:** `economic-simulator.md` v0.2 and `companies.md` v0.6 wherever they conflict with this document. Those docs remain the long-term requirements catalogue.
**Aligned with:** [MASTER-PLAN.md](MASTER-PLAN.md) §3–4 (politics is the base), [pic-core.md](pic-core.md) (schemas, VoterCell, 11-phase tick), and rulings A1–A6 and X1–X13.
**PIC slice:** [pic-economy.md](pic-economy.md). **Decisions:** E1–E40 and C1–C12 in [DECISIONS.md](DECISIONS.md).
**Runtime:** GDScript, Godot 4.7.2 standard. The sim is pure `RefCounted` under `game/sim/econ/` and `game/sim/comp/`, with no scene tree. **All money and quantities are `int` fixed-point ×1000** (1 credit = 1000 mcr; 1 unit = 1000 mu).

> **Knob** marks a tuning value. It lives in `game/data/econ/tuning.json`, never in code. Everything *not* marked Knob is a structural rule. Changing one needs a DECISIONS row.

---

## 0. Design stance (v1)

1. **The economy exists to make politics bite.** Every mechanism below produces an indicator voters feel, a fact someone can be blamed for, or reacts to a lever politics sets. Mechanisms that do none of these were cut (§14).
2. **Small and closed, not big and vague.** There are 8 commodities, 4 non-storable capacity products, 3 skill tiers, 6 districts and about 20 organizations. Every number needed to run month 1 is in this document.
3. **Rule-based firms in v1.** The decisions are deterministic given a seed. Utility-AI is post-v1.
4. **Conservation is absolute.** Money only enters or leaves through the `ORIGIN` external account. Goods only appear through production or imports. The headless runner asserts both every month.

---

## 1. Units, numbers and determinism

| Item | Rule |
|---|---|
| Money | `int` mcr (×1000). The display rounds to whole credits. |
| Quantity | `int` mu (×1000). The display rounds to 1 decimal. |
| Rates, shares, multipliers | `int` per-mille (‰, ×1000). For example, 20% tax = 200. |
| Multiply | `fp_mul(a, b) = (a * b) / 1000` (truncate toward zero). Max operand product must be < 9.2e18. Prices ≤ 1e9 mcr × qty ≤ 1e9 mu is safe. |
| Allocation remainders | **Largest-remainder method**, with ties broken by ascending entity id. No money or goods are lost to rounding. A single transfer's truncated residue stays with the payer. |
| Iteration order | Always by ascending stable entity id. Never iterate dictionaries in insertion order unless the keys are ids. |
| RNG | Kernel streams per purpose: `econ.accident`, `econ.demog`, `comp.forecast`, `comp.bid`, `comp.entry`, `comp.ceo`. Each draws from its own seeded stream. Normal draws use the Irwin–Hall sum of 12 uniforms −6, all in ints. |
| Time | `month` int; month 1 = landing. Year = `(month-1)/12 + 1`. "Quarter end" = months where `month % 3 == 0`. |

---

## 2. Canonical resources & capacity products (closes blocker #2; X2)

### 2.1 Storable commodities (the 8, per X2)
| ID | Unit means | Storable | Traded via | Spoilage /month (Knob) | Cargo mass (imports) |
|---|---|---|---|---|---|
| FOOD | 1 person-month of food | yes | market | 2% | 1 |
| WATER | 1 person-month of household water | network | **utility network** (§5.6) | n/a | not importable |
| ENERGY | 1 energy unit | network | **utility network** | n/a | not importable |
| MINERAL | raw ore | yes | market | 0 | 2 |
| MATERIAL | construction/industrial material | yes | market | 0 | 2 |
| COMPONENT | industrial components | yes | market | 0 | 1 |
| CONSUMER | consumer goods | yes | market | 0 | 1 |
| MEDICAL | medical supplies | yes | market | 0.5% | 1 |

- **There is no fuel and no "equipment" commodity.** Power plants consume MATERIAL as upkeep (X2). "Equipment" is a facility's **capacity** plus its **condition** (§4.3).
- ALCOHOL is post-v1 (X8).

### 2.2 Non-storable capacity products (new; closes review gap #21 "services have no units")
These are produced and consumed in the same month. They have no inventory and no spoilage, and they never enter the commodity market.

| ID | Unit | Producer | Consumer | Priced? |
|---|---|---|---|---|
| HOUSING | 1 dwelling unit-month (1 household) | Residential block | Household groups | Rent (§7.6) |
| SERVICES | 1 service unit (≈ an hour of retail, repair, food service…) | Service hub | Households (discretionary) | Market price per district (§6.4) |
| HEALTH | 1 person covered for a month | Clinic | Residents (access share) | Fee lever (default 0) |
| EDUCATION | 1 pupil seat-month | School | School-age children (access share) | Fee lever (default 0) |
| FREIGHT | 1 cargo unit moved across 1 link | Freight depot (CTA) | Every inter-district shipment | Freight tariff lever |
| WU | 1 construction work-unit = 1 construction worker-month | Contractor workforce | Construction projects | Inside bid price |

---

## 3. Starting scenario (closes blocker #11 and question Q5)

### 3.1 Map (= D5 v1, accepted by Wilma A11; district ids `d:1`…`d:6` in this order)
| District | Role | Pop. | Households | Housing units | Facilities |
|---|---|---:|---:|---:|---|
| D1 **Landing** | admin / residential / port | 900 | 360 | 400 (CHO 250, Frontier 150) | Administration, Clinic, School, Freight depot, 2 service hubs, landing pad (ship port) |
| D2 **Riverside** | farming / water | 400 | 160 | 200 (CHO 100, Frontier 100) | 5 farms, 2 water works, 1 service hub |
| D3 **Redrock** | mining | 250 | 100 | 100 (CHO 100) | 2 mines |
| D4 **Foundry** | industry / power | 300 | 120 | 100 (CHO 50, Frontier 50) | 2 processing plants, component factory, consumer factory, medical works, 2 power plants, 1 service hub |
| D5 **Greenhill** | farming / residential | 150 | 60 | 50 (Frontier 50) | 3 farms |
| D6 **Northfield** | undeveloped expansion zone | 0 | 0 | 0 | none (no link, no utility connection) |
| **Total** | | **2,000** | **800** | **850** | |

Built-in tensions on day 1:
- Foundry is overcrowded (1.20 households/unit), next to the highest pollution.
- Greenhill is overcrowded (1.20).
- Redrock is full (1.00).
- Landing has slack (0.90).

**Transport links** (undirected; capacity in cargo units/month, Knob):
| Link | Capacity | Condition |
|---|---:|---:|
| Landing–Riverside | 3,000 | 90 |
| Landing–Foundry | 3,000 | 90 |
| Foundry–Redrock | 2,000 | 80 |
| Riverside–Greenhill | 1,500 | 85 |
| Landing–Greenhill | 1,500 | 85 |

Northfield has no link; building one is the first expansion project. All 5 developed districts are on the single energy grid and water network. A district is **connected** to the utility networks iff it has a road link to a connected district (v1 simplification).

### 3.2 Population & labor
| Item | Value |
|---|---|
| Population | 2,000 = 480 children (0–17), 1,400 working-age, 120 retired |
| School-age children (6–17) | 360 |
| Labor force | 1,142 (participation 81.6%) |
| Labor force by tier | General 750 · Skilled 300 · Specialist 92 |
| Employed at start | 1,059 = General 699 · Skilled 277 · Specialist 83 |
| Unemployed at start | 83 = **7.3%** (General 6.8%, Skilled 7.7%, Specialist 9.8%) |
| Avg household size | 2.5 persons |
| Starting household savings (per capita) | General-tier groups 500 · Skilled 900 · Specialist 2,000 · owner households +20,000 per owner (Knob) |

District split: each district's population is seeded with the colony tier mix (65.7% G / 26.3% S / 8.0% Sp of the labor force). Workers commute colony-wide (§6.3).

### 3.3 Prices, wages and rates at month 1
| Item | Value | Note |
|---|---:|---|
| Reference prices (cr/unit) | FOOD 115 · MINERAL 110 · MATERIAL 370 · COMPONENT 1,650 · CONSUMER 115 · MEDICAL 250 · SERVICES 30 | Cost-plus ≈ 9–20% at full utilization, after law's 8% extraction royalty on MINERAL (verified, §15) |
| **W_ref** (a9 money unit) | 1,200 cr | Published monthly as `world.values["ECON_W_REF"]` (mcr) = average Skilled wage actually paid that month (SETTLEMENT). All staff and law money is denominated in it (§6.5). |
| Utility tariffs (cr/unit) | ENERGY 40 · WATER 20 | Levers (CPW is a public enterprise) |
| Freight tariff | 5 cr per cargo unit per link | Lever |
| Wage index (cr/worker-month) | General 800 · Skilled 1,200 · Specialist 1,800 | Moves by §6.5 |
| Rent | CHO (public) 250 · Frontier (private) 260 per unit-month | Public rent is a lever |
| Origin import prices | 2.5 × month-1 reference price, +1%/year (Knob) | §8 |

### 3.4 Per-capita needs (closes blocker #12)
| Need | Quantity / person / month | Essential? | Source |
|---|---:|---|---|
| FOOD | 1.0 | yes | market |
| WATER | 1.0 | yes | network |
| ENERGY | 0.5 | yes | network |
| CONSUMER (minimum) | 0.1 | yes | market |
| HOUSING | 1 unit per household (2.5 persons) | yes | rent |
| HEALTH | 1 coverage slot | yes (public) | clinic |
| EDUCATION | 1 seat per school-age child | yes (public) | school |
| CONSUMER (discretionary) | 0–0.4 more | no | market (§7.3) |
| SERVICES (discretionary) | budget-driven | no | district market |

**Essentials cost at month 1:** food 115 + water 20 + energy 20 + consumer 11.5 + rent 100 = **≈ 266 cr per capita**. That is **55%** of average disposable income (487 cr per capita). Low-band households sit at 70–80%, which is the political pressure point.

### 3.5 Treasury, bank and external
| Account | Start | Note |
|---|---:|---|
| Government treasury | **15,000,000** cr | Expedition funding |
| Origin Development Grant | **+200,000 cr/month, months 1–48**, then 0 | Charter (LOCKED). Ending it creates the first-term fiscal squeeze. Knob |
| Government debt | 0 | |
| Colony Bank cash | 12,000,000 cr | Loan book 4,600,000 (firm loans below) |
| Government strategic reserve | FOOD 4,000 · MEDICAL 300 · MATERIAL 1,000 · COMPONENT 100 | Warehouse in Landing, capacity 10,000 units. Released only by Action |

**Founding fiscal runway (verified):**
- Government operating spend is ≈ 300k/month (admin 108k, health 72k, education 45k, welfare ≈ 75k).
- Revenue is ≈ 240k/month (income tax 145k, profit tax ≈ 25k, enterprise dividends ≈ 70k).
- That gives an operating gap of ≈ 60k/month. With the grant, ≈ 140k/month plus the 15M treasury is available for capital projects. This is **~20M over the founding term ≈ 12–14 major projects**.
- After month 48 the gap must be closed by growth, taxes or cuts. That is deliberate.

### 3.6 Starting organizations (C1 roster)
| Org | Type | District(s) | Facilities | Cash (cr) | Bank loan | CEO (Mgmt / Risk / Age) |
|---|---|---|---|---:|---:|---|
| Colony Power & Water (CPW) | PUBLIC_ENTERPRISE | Foundry, Riverside | 2 power plants, 2 water works | 300,000 | 0 | Director 64 / 25 / 51 |
| Colony Transit Authority (CTA) | PUBLIC_ENTERPRISE | Landing | Freight depot + link operation | 100,000 | 0 | Director 55 / 30 / 47 |
| Colony Housing Office (CHO) | PUBLIC_ENTERPRISE | 4 districts | 10 residential blocks (500 units) | 200,000 | 0 | Director 50 / 20 / 56 |
| Meridian Agricultural Co-op | COOPERATIVE | Riverside | 5 farms | 400,000 | 0 | Elected mgr 62 / 30 / 44 |
| Greenfold Farms Ltd | PRIVATE | Greenhill | 3 farms | 240,000 | 300,000 | Owner-CEO 55 / 50 / 39 |
| Redrock Mining Co. | PRIVATE | Redrock | 2 mines | 190,000 | 600,000 | Owner-CEO 58 / 60 / 45 |
| Basalt Processing Ltd | PRIVATE | Foundry | 2 processing plants | 450,000 | 800,000 | Owner-CEO 66 / 45 / 52 |
| Vector Components Ltd | PRIVATE | Foundry | Component factory, medical works | 240,000 | 500,000 | Owner-CEO 72 / 50 / 41 |
| Hearth Goods Co. | PRIVATE | Foundry | Consumer factory | 220,000 | 0 | Owner-CEO 50 / 55 / 36 |
| Commons Services Ltd | PRIVATE | Landing ×2, Foundry | 3 service hubs | 260,000 | 0 | Owner-CEO 57 / 45 / 43 |
| Landing Market Co-op | COOPERATIVE | Riverside | 1 service hub | 90,000 | 0 | Elected mgr 53 / 25 / 49 |
| Frontier Homes Ltd | PRIVATE | 4 districts | 7 residential blocks (350 units) | 150,000 | 2,000,000 | Owner-CEO 60 / 55 / 50 |
| Atlas Construction | PRIVATE (contractor) | Landing | 100 workers (60 G / 30 S / 10 Sp); MAT 600, COMP 40 | 600,000 | 0 | Founder 78 / 35 / **58** |
| Pioneer Builders | PRIVATE (contractor) | Foundry | 80 workers (55 / 20 / 5); MAT 400, COMP 25 | 150,000 | 400,000 | CEO 52 / **80** / 40 (owner is a separate investor Person) |
| Workers' Building Co-op | COOPERATIVE (contractor) | Riverside | 60 workers (45 / 15 / 0); MAT 300, COMP 15 | 200,000 | 0 | Elected mgr 60 / 30 / 46 |
| Colony Health Service | PUBLIC_INSTITUTION | Landing | Clinic | budget-funded | — | Director 61 / 20 / 53 |
| Colony School | PUBLIC_INSTITUTION | Landing | School | budget-funded | — | Head 58 / 20 / 48 |
| Colony Administration | PUBLIC_INSTITUTION | Landing | Admin office, 80 staff (20 G / 30 S / 30 Sp) | budget-funded | — | (the 20 senior officials are staff-owned, not here) |

**Story hooks seeded on purpose:**
- Atlas's founder (58) reaches retirement (age 65) in year 8, which triggers the v1 CEO-replacement rule (C9).
- Pioneer is cheap, aggressive and thin on cash, so it is the likeliest early contractor failure.
- Frontier is heavily leveraged and sensitive to rent control.

Every producing firm starts with **1 month of output in inventory and 1 month of inputs**.

---

## 4. Production (econ §5, closed)

### 4.1 Recipes v1 (per facility, per month, at 100% capacity)
| Facility | Workers G / S / Sp | Inputs | Output | MAT upkeep | Pollution pts | Accident base ‰/yr | Hazard class (law) | Licence (law §10) |
|---|---|---|---|---:|---:|---:|---|---|
| Power plant (solar-thermal) | 10 / 10 / 2 | MATERIAL 15 | ENERGY 1,200 | 4 | 2 | 3 | HIGH | LICENCE_HAZARD |
| Water works | 8 / 6 / 0 | ENERGY 80 | WATER 1,500 | 3 | 0 | 2 | LOW | — |
| Farm | 28 / 2 / 0 | WATER 40, ENERGY 10 | FOOD 280 | 1 | 1 | 3 | LOW | — |
| Mine | 20 / 10 / 0 | ENERGY 60 | MINERAL 400 | 3 | 6 | 8 | MEDIUM | LICENCE_EXTRACTION (+ royalty) |
| Processing plant (smelter) | 15 / 15 / 0 | MINERAL 400, ENERGY 80 | MATERIAL 250 | 4 | 8 | 5 | HIGH | LICENCE_HAZARD |
| Component factory | 8 / 16 / 4 | MATERIAL 50, ENERGY 50 | COMPONENT 40 | 3 | 4 | 3 | MEDIUM | — |
| Consumer factory | 35 / 12 / 0 | MATERIAL 75, ENERGY 60 | CONSUMER 850 | 2 | 3 | 3 | LOW | — |
| Medical works | 0 / 5 / 5 | COMPONENT 4, ENERGY 20, WATER 10 | MEDICAL 120 | 2 | 1 | 2 | MEDIUM | — |
| Service hub | 25 / 5 / 0 | ENERGY 30, CONSUMER 10 | SERVICES 1,200 | 1 | 0 | 1 | LOW | — |
| Clinic | 5 / 10 / 15 | MEDICAL 100, ENERGY 40, WATER 30 | HEALTH 2,500 | 2 | 0 | 1 | LOW | — |
| School | 4 / 16 / 10 | ENERGY 30, WATER 20, CONSUMER 15 | EDUCATION 450 | 2 | 0 | 1 | LOW | — |
| Freight depot | 20 / 5 / 0 | ENERGY 120, COMPONENT 2 | FREIGHT 8,000 | 3 | 2 | 4 | MEDIUM | — |
| Admin office | 20 / 30 / 30 | ENERGY 40, CONSUMER 10 | — (state capacity) | 0 | 0 | 1 | LOW | — |
| Residential block | 1 / 0 / 0 | — | HOUSING 50 | 2 | 0 | 1 | LOW | — |
| Contractor (per worker) | any tier | — | 1 WU | — | — | 6 | MEDIUM | — |

All recipes are data (`game/data/econ/recipes.json`). The numbers above are the v1 defaults (Knob).

### 4.2 Output formula
```
Q_f = C_f × U_f × E_f × T_f
U_f = min(1, r_inputs…, r_labor_G, r_labor_S, r_labor_Sp, r_energy, r_water)
E_f = E_condition × E_mgmt
T_f = target utilization chosen by the operator (§9.1), in [0, 1]
```
- **Labor substitution:** a higher tier may fill a lower-tier slot (Sp→S→G) at the *slot's* wage. Lower tiers never fill higher slots.
- `E_condition = min(1000, 600 + condition×4)‰` with condition 0–100 (100 → 1.0, 50 → 0.8, 0 → 0.6).
- `E_mgmt = 900 + 2 × mgmt‰` with operator CEO Management 0–100 (0.90…1.10). This is the *only* direct leader multiplier. Everything else a leader affects goes through decisions (§9).
- **Lag (econ §5.5):** output enters inventory in PRODUCTION and can be sold no earlier than next month's TRADE.

### 4.3 Condition, upkeep, closure
- Condition decays 1.0/month. If the MAT upkeep is delivered in full, the decay is 0. A partial delivery gives decay `1.0 × (1 − delivered/required)`. Facilities idle (T = 0) need 25% upkeep.
- Condition < 25 for 3 consecutive months forces closure as unsafe (`ECON_FACILITY_CLOSED_UNSAFE`). Repair is a construction project at 30% of build cost.
- **There are no money-only maintenance costs.** Every cost is wages, goods, utilities, freight, rent, interest or tax, so all money stays on the ledger.

### 4.4 Build bill (construction recipe per facility; Knob)
| Facility | WU | MATERIAL | COMPONENT | Min months | ≈ Bid price |
|---|---:|---:|---:|---:|---:|
| Residential block (50 units) | 1,200 | 400 | 20 | 6 | 1.66M |
| Farm | 250 | 250 | 10 | 3 | 0.43M |
| Water works | 500 | 500 | 60 | 6 | 0.93M |
| Power plant | 800 | 800 | 150 | 8 | 1.59M |
| Mine | 600 | 400 | 80 | 6 | 1.05M |
| Processing plant | 700 | 700 | 100 | 8 | 1.33M |
| Component factory | 700 | 600 | 120 | 8 | 1.33M |
| Consumer factory | 500 | 500 | 60 | 6 | 0.93M |
| Medical works | 400 | 300 | 80 | 6 | 0.76M |
| Service hub | 200 | 200 | 10 | 3 | 0.36M |
| Clinic | 450 | 400 | 60 | 6 | 0.83M |
| School | 450 | 450 | 30 | 6 | 0.79M |
| Freight depot (+8,000 FREIGHT) | 300 | 250 | 40 | 4 | 0.55M |
| Road link (new, cap 1,500) / upgrade (+1,000 cap, +20 cond.) | 300 | 300 | 10 | 4 | 0.51M |
| Repair (any) | 30% of WU/MAT/COMP | | | 2 | — |

Total colony contractor capacity at start is **240 WU/month**. That is roughly one large project at a time, so construction capacity is itself a political bottleneck.

### 4.5 Pollution & workplace injuries (feed ENVIRONMENT_QUALITY and SAFETY)
- **Emissions:** `E_d = Σ facility pollution pts × T_f × (1 − ECON_EMISSION_REDUCTION/100)`.
- **District pollution index:**
  ```
  P_d' = clamp( 0.8×P_d + 0.4×(E_d + 0.25×Σ_{n∈neighbours} E_n), 0, 100 )
  ```
  Steady state: Foundry ≈ 62, Redrock ≈ 38, Landing ≈ 18, others < 15.
- **Workplace accidents** (aligned with a9; feeds law's `LAW_WORKPLACE_SAFETY` = the v1 SAFETY concern):
  - Per facility per month: `p = workers × base‰ / 12 / 1000 × (1 + (100 − cond)/100) × S × V`.
    - `S` reads **law's lever `LAW_SAFETY_STANDARD`**: BASIC 1.0 / STANDARD 0.7 / STRICT 0.45.
    - `V` = 1.5 if the facility operates in violation (e.g. no required LICENCE_HAZARD or LICENCE_EXTRACTION, or knowingly below standard per §9.5), else 1.0.
  - Draw `k` accidents from stream `econ.accident`: Bernoulli on `p` when p ≤ 1, else floor(p) plus Bernoulli on the remainder.
  - Workers affected per accident: 1 at LOW/MEDIUM hazard, `1 + floor(u × 3)` at HIGH hazard and mines.
  - Each accident emits **`COMP_WORKPLACE_ACCIDENT`** `{district, facility, operator, workers_affected, hazard_class, in_violation}`.
  - **Expected colony rate at start:** ≈ 3.5 accidents per 1,000 workers per year at BASIC, ≈ 1.6 at STRICT.
  - Econ publishes **no** separate injury indicator (law owns it), which avoids double-counting SAFETY.
- **Compliance costs:** borne by operators and read from law's lever.
  - `LAW_SAFETY_STANDARD` STANDARD adds 3% to that facility's wage bill and STRICT adds 7% (safety staff time).
  - Econ's `ECON_EMISSION_REDUCTION` (0–40%) adds `0.27 × value`% to input costs (15% → +4%, 30% → +8%).

---

## 5. Monthly pipeline mapping (closes blocker #1; question Q11)

Econ and comp run **inside pic-core §7 phases 3, 4, 5, 6 and 8**. The internal order is fixed:

| Tick phase | Econ/comp steps (in order) |
|---|---|
| 1 `DECISIONS` (pol) | Queued econ Actions validated and applied. Lever changes are queued (they take effect via `STAFF`). Government purchase and import orders are posted. |
| 2 `STAFF` (staff) | Levers whose implementation task finished become effective → econ reads the new values from next phase onward. |
| 3 `TRADE` | (a) Shipments arrive. On ship months, import cargo and migrants land. (b) **Commodity market clearing** (§6.1) for orders posted last month in COMPANY_AI/SOCIAL, plus this month's government orders. Payment is cash-on-match and goods dispatch immediately. Paths of ≤ 2 links arrive this month, longer paths next month. (c) Freight charged to CTA. (d) Spoilage. (e) Reference-price update (§6.2). |
| 4 `PRODUCTION` | (a) **Labor matching** (§6.3). (b) **Utility allocation** (§6.6). (c) Facility production (§4.2), upkeep, condition. (d) Capacity products (HOUSING, HEALTH, EDUCATION, SERVICES, FREIGHT). (e) **Construction progress** (§10.4). (f) Emissions, injuries. |
| 5 `SETTLEMENT` | Fixed payment order per payer: (1) wages net of withheld income tax, (2) utility bills, (3) rent, (4) contract payments, (5) benefits & pensions, (6) loan service, (7) quarter end: profit tax, then dividends, (8) Origin grant inflow, (9) **insolvency checks** (§11). Then fiscal accounting update. |
| 6 `COMPANY_AI` | Firm decisions for next month (§9): targets, vacancies, wage offers, purchase orders, sale asks, tenders and bids, investment, distress responses. Quarterly firm entry (C7). Wage index update (§6.5). |
| 8 `SOCIAL` | (a) Households consume goods bought in TRADE, record unmet needs, update savings (§7). (b) Household purchase orders for next month posted. (c) Housing allocation, private rent adjustment. (d) Demography and migration (§7.7). (e) January: income-band re-banding (§7.2). (f) Pollution update. (g) **All econ indicators finalized**, VoterCell projection (§7.2). |

**Consequences (documented, intended):**
- Goods produced in month *m* are first sold in month *m+1* TRADE (econ §5.5 lag).
- Households buy in TRADE with orders placed from last month's income.
- Wages earned in month *m* SETTLEMENT fund month *m+1* purchases.
- A lever changed in DECISIONS affects the economy no earlier than the same month's TRADE, and usually later (implementation task + lag).

---

## 6. Markets, labor, utilities (closes blocker #3; question Q2)

### 6.1 Commodity market clearing (deterministic)
**Structure (Q2 ruling):**
- There is **one colony-wide market per commodity**, with one reference price `P_r`.
- Regional variation comes from **delivered price** = seller ask + freight (5 cr × links on the cheapest path).
- Per-district price indicators are the average delivered prices actually paid there.

**Algorithm** per commodity, in order FOOD, MEDICAL, MINERAL, MATERIAL, COMPONENT, CONSUMER:
1. **Offers:** `(seller, district, qty = available − reserved, ask)` from every holder that posted one. The government reserve is offered only via `ECON_RELEASE_RESERVE`.
2. **Bids:** `(buyer, district, qty, limit_price, class)`.
3. **Buyer classes, processed in this order:**
   1. `CONTRACT` (standing supply contracts; post-v1, empty in v1)
   2. `HOUSEHOLD_ESSENTIAL` (FOOD 1.0, CONSUMER 0.1, per capita)
   3. `INSTITUTION` (clinic, school, admin)
   4. `GOVERNMENT` (reserve purchases, government-supplied projects)
   5. `FIRM_INPUT` (production inputs, upkeep, construction materials)
   6. `HOUSEHOLD_DISCRETIONARY`
4. **Within `HOUSEHOLD_ESSENTIAL`:** **pro-rata rationing.**
   - Let `S` = total offered qty and `D` = total affordable essential demand.
   - If `S ≥ D`, every group is filled. If not, each group receives `D_g × S/D` (largest remainder).
   - Each group then sources its allotment from offers sorted by ascending delivered price to its district, ties by seller id.
5. **Within the other classes:** buyers are sorted by `limit_price` desc, then id. Each buyer takes offers by ascending delivered price while `ask + freight ≤ limit`.
6. **Price paid:** the seller's ask (pay-as-ask), plus freight paid to CTA. Cash moves at match. A match is skipped if the buyer can't pay (§1 integer check). There is no credit between firms in v1.
7. **Freight capacity:** each match reserves FREIGHT along the path. Once a link or the CTA fleet is full, remaining matches using it are deferred one month and become `ECON_LOGISTICS_BOTTLENECK` facts.
8. **Records:** unfilled demand per buyer and unsold qty per seller. These feed indicators, facts and next month's decisions.

**Limit prices:**
- Households essential: whatever they can afford (§7.3).
- Discretionary: 1.10 × P_r.
- Firm inputs: 1.30 × P_r (Knob). Distressed firms: 1.0 × P_r.
- Institutions and government: 2.0 × P_r.

### 6.2 Reference price update (econ §9.3, closed)
```
P_r' = clamp( P_r × (1 + α × (D_r − S_r) / max(D_r, S_r, ε)), P_min_r, P_max_r )
```
- α = 0.15 (Knob). ε = 1 unit.
- `D_r` = Σ bid qty with limit ≥ 0.8 × P_r.
- `S_r` = Σ offered qty, including import cargo landing this month.
- `P_min = 0.25 × base`, `P_max = 4 × base`, where base = the §3.3 month-1 price.
- The maximum move is therefore ±15%/month.
- Commodities with no bids and no offers keep their price.

**CPI:** basket weights are the colony household spending shares, re-weighted each January. The basket is FOOD, WATER, ENERGY, CONSUMER, SERVICES and rent. CPI is a Laspeyres index, 100 = month 1.

### 6.3 Labor market
- **Supply:** per household group, available workers by tier = labor force − employed. Health effects (§7.5) reduce this.
- **Demand:** vacancies by (employer, facility, tier, wage offer) posted in COMPANY_AI.
- **Matching** happens in PRODUCTION, tier by tier from Specialist down to General:
  1. Vacancies are sorted by wage offer desc, then employer id.
  2. Each vacancy is filled from unemployed workers of that tier. Same-district groups go first, then others by district id. Within a district, workers are drawn pro-rata across groups.
  3. Unfilled Specialist or Skilled supply may then fill lower-tier vacancies (the downgrade, at the lower wage).
- **Speed limits** (Knob):
  - A firm fills at most `max(5, 25% of its target headcount)` per month.
  - Layoffs are capped at 20% of headcount per month, except closure or liquidation.
  - Existing jobs persist. There is no voluntary churn in v1.
- **Occupation tag:** each employment records its sector → Occupation for the VoterCell mapping (§7.2).

### 6.4 SERVICES market (district-local)
- Service hubs sell only within their own district and adjacent districts at +10% (no freight).
- Price per district updates by the §6.2 rule, using that district's supply and demand.

### 6.5 Wages
- Each tier has a **wage index** `W_k` (start 800 / 1,200 / 1,800), updated in COMPANY_AI:
  ```
  W_k' = W_k × (1 + clamp(0.25 × (v_k − u_k + 0.07), −0.005, +0.020))
  ```
  - `v_k` = unfilled vacancies / (employed + unfilled), last month.
  - `u_k` = unemployment rate of tier k.
  - 0.07 = "neutral" unemployment (Knob). At start `W` is ≈ stable.
  - Wages are sticky downward: at most −0.5%/month.
- **Firm offer** = `W_k × (1.00 + 0.05 × months_with_unfilled_vacancies (cap 0.15))`. This is floored by `ECON_MIN_WAGE × W_ref` for every tier. `ECON_MIN_WAGE` is a fraction of W_ref, charter bound ≥ 0.40, default 0.40 = 480 cr, which is non-binding at start (W_G = 800).
- **W_ref** (for a9): `world.values["ECON_W_REF"]` = Skilled wage bill ÷ Skilled headcount actually paid this month, in mcr. It is written in SETTLEMENT; if headcount is 0, the previous value is kept. Staff and law read last month's value in DECISIONS/STAFF. W_ref is a world value, not a PIC indicator, because it feeds no concern.
- **Public-sector pay** = `W_k × ECON_PUBLIC_PAY_INDEX`. This covers institutions, administration and public enterprises.
- Existing employees are re-priced to the current offer each January. Mid-year, only new hires get the new offer.

### 6.6 Utility networks (ENERGY, WATER)
- These are not on the market. CPW supplies at the tariff lever price.
- **Allocation in PRODUCTION:** if supply ≥ demand, everyone is served. Otherwise tiers are filled in `ECON_ENERGY_PRIORITY` order (default per econ §6.2):
  1. Life-support / clinic
  2. Households
  3. Institutions and administration
  4. Utilities' own use (water works)
  5. Industry
  Within a tier the shortfall is pro-rata.
- A facility's `r_energy` and `r_water` = served / required. Households' shortfall feeds `ECON_UTILITY_RELIABILITY` and `ECON_ESSENTIAL_SHORTFALL`.
- Every rationing month emits `ECON_UTILITY_OUTAGE`.

---

## 7. Households (closes question Q6; X11)

### 7.1 Household group key
`HouseholdGroup = District × SkillTier(G, S, Sp) × IncomeBand(LOW, MID, HIGH)`. That is at most 6 × 3 × 3 = 54 groups; empty groups are skipped.

Each group holds:
- population: adults by status `{employed[sector], unemployed, non-participating, retired}`, plus children (attached proportionally)
- `cash_savings`
- an unmet-needs record
- `months_unemployed` histogram (for benefit duration)

### 7.2 Income bands & the VoterCell mapping (pic-core §1.1)
**Re-banding every January (and at month 1):**
1. Build "income classes" = (district, tier, status/sector) with per-adult disposable income (wages net, benefits, pensions, and dividends for owner households).
2. Sort colony-wide by per-adult income.
3. Cut population terciles. A class straddling a cut is split proportionally.
4. Move people and a proportional share of savings between the bands of the same district × tier.

**VoterCell projection (SOCIAL, every month):** for each group, voters = adults (working-age + retired; children excluded). Occupation is assigned like this:

| Household member status | Occupation |
|---|---|
| Employed at mine | `MINING` |
| Employed at farm | `AGRICULTURE` (added by Wilma, A11) |
| Employed at power, water, processing, component, consumer, medical works, or contractor | `INDUSTRY` |
| Employed at service hub, residential block (private), freight (private) | `SERVICES` |
| Employed by PUBLIC_ENTERPRISE or PUBLIC_INSTITUTION (incl. CPW, CTA, CHO, clinic, school, admin) | `PUBLIC_SECTOR` |
| Owner Person of a PRIVATE firm (C3) | `BUSINESS_OWNER` |
| Unemployed | `UNEMPLOYED` |
| Retired | `RETIRED` |
| Non-participating working-age adult | Same mix as the employed members of that group; `UNEMPLOYED` if the group has none |

The mapping is published as `[{group_id, cell(district, occupation, band), weight}]`. Cell-level econ indicators are the weight-averaged group values.

Farms map to `AGRICULTURE` (8th occupation, Wilma A11).

**Census (politics input):** in SOCIAL, econ writes `world.table("census")[PolDefs.cell_key(district_id, OCC, BAND)] = voting adults (int)`. The values are computed by largest-remainder rounding of the group→cell weights; keys with 0 are omitted. District ids are the map ids `d:1`…`d:6` (Landing, Riverside, Redrock, Foundry, Greenhill, Northfield).

### 7.3 Monthly household budget (SOCIAL)
For each group, using fixed-point arithmetic:
```
disposable  = wages_net + benefits + pensions + dividends            (received in SETTLEMENT)
E           = rent + water + energy + food(1.0 pc × P_food delivered) + consumer_min(0.1 pc × P_cons)
cash        = savings + disposable
spend order = rent → water → energy → food → consumer_min        (until cash runs out)
unmet_k     = needed_k − bought_k                                 (per essential, recorded)
surplus     = max(0, disposable − E)
excess      = max(0, savings − 6 × E)                             (6 months of essentials = target buffer)
B_disc      = 0.45 × surplus + 0.05 × excess                      (propensities: Knob)
consumer_extra qty = min(0.4 pc, 0.35 × B_disc / P_cons)
services qty       = 0.65 × B_disc / P_services(district)
savings'    = cash − spent
```
- **Arrears:** unpaid rent is written off by the landlord, with no evictions in v1. It raises `rent_arrears` and the fact `ECON_RENT_ARREARS` (district aggregate).
- **Rationed purchases:** if a purchase was rationed in TRADE (pro-rata), the shortfall is `unmet`, not savings.
- **Steady-state check (verified):** the average saving rate starts at ≈ 25% and falls as buffers fill. The soak-test target is a 5–15% saving rate by year 3.

### 7.4 Benefits & pensions
| Item | Rule |
|---|---|
| Unemployment benefit | `ECON_UNEMPLOYMENT_BENEFIT_RATE` × W_G (default 40% → 320 cr) for the first `ECON_BENEFIT_DURATION` months (default 12), then half that rate. |
| Pension | `ECON_PENSION_RATE` × W_G (default 50% → 400 cr) per retiree. |
| Payment | Both are paid from treasury in SETTLEMENT as entitlements (the WELFARE line is automatically appropriated). |

### 7.5 Public services
- **Access per district:**
  ```
  HEALTH access_d = min(1, (cap_in_d + 0.7 × cap_spill) / pop_d)
  ```
  Clinic capacity is shared colony-wide. Residents of districts with no clinic count at weight 0.7. Allocation goes to the clinic's own district first, then pro-rata.
- EDUCATION works the same way with school-age children.
- **Effects:**
  - Labor availability × `(1 − 0.08 × (1 − health_access))`.
  - Deaths +0.02%/month × `(1 − health_access)`.
  - School-leavers' tier split = `a × (45/40/15%) + (1 − a) × (85/15/0%)` (G/S/Sp), where `a` = education access.
- **Budget link:** institutions hire to their budget. If the HEALTH appropriation is below the clinic's full cost, its staffing target scales down, so capacity falls. This is how budget cuts become felt.

### 7.6 Housing
- Households occupy units in their district. `overcrowding_d = households / units`. There is no homelessness state in v1; it shows as overcrowding > 1.
- Rent paid per household = district average contracted rent. Receipts are split to landlords by units owned.
- **Private rent rule (quarterly):**
  - +3% if district occupancy ≥ 97%.
  - −2% if < 85%.
  - Capped so that the cumulative increase over the trailing 12 months stays ≤ `ECON_RENT_INCREASE_CAP` % (20 = effectively uncapped, 0 = freeze).
- Public rent = `ECON_PUBLIC_RENT` lever.
- **Internal moves:** each month, 2% of households in districts with overcrowding > 1.10 move to districts with occupancy < 0.95 (if any). Jobs are kept (commuting).

### 7.7 Demography & migration (econ-owned flows; flag to Wilma)
| Flow | Rule |
|---|---|
| Births | 0.15%/month of population, as children in the mother's group |
| Deaths | 0.05%/month base, plus health and famine terms |
| Aging | Children → working-age at 1/216 per month (enter the labor force using the §7.5 tier split). Working-age → retired at 0.2%/month. |
| Immigration | Arrives on supply ships, months 3, 6, 9, 12. `n = min(ECON_IMMIGRATION_QUOTA (default 60), 2.5 × vacant units colony-wide, 120 origin supply)`. Migrants are adults 70% (tier mix 50/35/15) and children 30%, and bring 2,000 cr each from `ORIGIN`. They settle into the districts with the most vacancies. |
| Emigration | Groups with unemployment > 20% **and** essential shortfall > 10% for 6 consecutive months lose 1%/month of members on ship months. Their savings leave to `ORIGIN`. Emits `ECON_EMIGRATION`. |
| Famine mortality | Colony FOOD shortfall > 30% in a month → deaths +0.5% of affected groups. |

---

## 8. Imports & external flows

| Item | Rule |
|---|---|
| Ships | One supply ship lands every quarter (months 3, 6, 9, 12), with 2,000 cargo-mass units (Knob) and up to 120 migrants. |
| Orders | An order placed in month *m* (government in DECISIONS, firms in COMPANY_AI) lands on the first ship with arrival ≥ *m*+3. It is **paid at order** to `ORIGIN`. Goods are reserved on the ship and cannot be used before arrival. |
| Price | `P_origin × (1 + ECON_IMPORT_TARIFF)` + 0 freight (built into P_origin). The tariff portion goes to the treasury. |
| Cargo allocation if over capacity | Government orders first (by priority: MEDICAL > FOOD > others), then private orders by order month, then firm id. Bumped orders roll to the next ship (fact `ECON_IMPORT_DELAYED`, responsible `EXTERNAL`). |
| Private imports (rule) | A firm imports an input if it was rationed ≥ 2 months running and `P_origin × (1 + tariff) ≤ 1.3 × its unit revenue`. |
| Exports | Post-v1 (econ §11.7). |
| Disruption | Event hook only. A ship can be cancelled or halved by `EVENTS` (D6). |

---

## 9. Firm decision rules v1 (closes blocker #4)

Rules run in `COMPANY_AI` for every non-dissolved organization, in id order. "Mgmt" and "Risk" are the CEO's 0–100 values. Forecast noise uses stream `comp.forecast`: `ε ~ N(0, σ)`, `σ = 0.20 × (1 − Mgmt/100)`.

### 9.1 Producers (farms, mines, plants, factories, hubs)
1. **Expected sales** `S^e = EMA_3(sales) × (1 + ε)`. If last month's sales were capped by rationing on the buy side, use offered qty instead.
2. **Inventory target** `I* = 1.0 × S^e` (FOOD 0.5 because of spoilage).
3. **Target output** `Q* = clamp(S^e + (I* − I), 0, C_f × U_f^expected × E_f)` → `T_f = Q* / (C_f × E_f)`.
4. **Mothball:** if `T_f < 0.25` for 3 months, the facility is mothballed (T = 0, staff laid off, 25% upkeep). It reopens when `S^e > 0.5 × C_f`.
5. **Vacancies** = recipe labor × T_f − current staff (layoffs if staff > 1.10× need, max 20%).
6. **Input orders** = recipe inputs × T_f + upkeep − input inventory. Limit price 1.30 × P_r. They are budget-capped at `cash − 1 × monthly_wage_bill`.
7. **Ask price** = `P_r × m`, where `m` depends on inventory cover `I/S^e`:

   | Cover | m |
   |---|---:|
   | < 0.5 | 1.05 |
   | 0.5–2 | 1.00 |
   | 2–4 | 0.95 |
   | > 4 | 0.90 |

   The ask is floored at `unit variable cost` (0.8× that when DISTRESSED).
8. **Investment** (quarter end only). Propose a new facility of the same type if **all** hold:
   - utilization ≥ 90% for 6 months
   - `P_r ≥ 1.10 × unit full cost`
   - cash ≥ 30% of build bid estimate
   - post-loan debt/book assets ≤ `0.30 + 0.40 × Risk/100`
   - status ACTIVE
   - the district is zoned for it (map)
   - the licence regime allows it (law)

   The firm then funds the remainder with a bank loan (§12.2) and runs a private tender (§10).
9. **Dividends** (quarter end): PRIVATE pays 50% of quarterly after-tax profit to its owner if cash ≥ 3 months of costs. COOPERATIVE pays 30% to member groups pro-rata by members' employment. PUBLIC_ENTERPRISE pays `ECON_PE_DIVIDEND_RATE` to the treasury.

### 9.2 Contractors
- Capacity `K` = construction workers × E_mgmt (WU/month).
- **Hiring:** target headcount = Σ over active contracts of `WU_remaining / months_remaining`, capped at +25%/month and floored at 60% of the current crew while contracts exist.
- **Bid/no-bid** on each open tender: bid iff
  ```
  (committed WU over the bid window + this WU) / (K × window) ≤ 1.0 + 0.5 × Risk/100
  ```
  So aggressive firms over-commit.
- **Bid price:**
  ```
  est_WU   = true_WU × (1 + ε_b),  ε_b ~ N(0, 0.25 × (1 − Mgmt/100))       (stream comp.bid)
  est_cost = est_WU × avg_wage_per_WU × 1.08 + MAT × P_MAT × 1.03 + COMP × P_COMP × 1.03
  margin   = 0.12 − 0.08 × Risk/100                                        (12% … 4%)
  price    = est_cost × (1 + margin)
  duration = max(min_months, ceil(est_WU / (0.6 × K)))
  ```
- Underestimated `est_WU` means the real WU is larger than priced: the overrun is absorbed by the contractor, which leads to losses and the distress path. This is how Pioneer fails without a scripted event.
- Contractors **buy the materials themselves** (econ §14.3 ruling). Government-supplied materials are post-v1.

### 9.3 Public enterprises & institutions
- **CPW:** produces to meet allocated demand. Price = tariff levers. It does not invest on its own; capacity grows only via government `ECON_COMMISSION_PROJECT`. When cash < 1 month of costs, it emits `ECON_PE_FUNDING_REQUEST` (government must subsidize or raise the tariff).
- **CTA, CHO:** same pattern (tariff = freight lever; rent = public rent lever).
- **Institutions** (clinic, school, admin) have no revenue. Each month they receive their budget line (SETTLEMENT) and hire up to `budget / unit cost`.

### 9.4 Firm entry (C7; quarterly)
- **Trigger:** for some commodity or service, (imports > 20% of supply **or** `P_r ≥ 1.25 × entrant unit full cost`) for 2 consecutive quarters, and the licence regime allows it.
- **Founder:** a new Person (Mgmt ~ N(50, 15), Risk ~ U(20, 80), stream `comp.entry`), drawn from the HIGH-band Specialist group with the largest savings.
- **Capital:** 40% of the build cost from that group's savings, 60% from a bank loan.
- **Limit:** at most 1 entry per quarter colony-wide.
- **Fact:** emits `COMP_COMPANY_FOUNDED`.


### 9.5 Legal checks, licences and misconduct (a9 interface; X7)
- **Where comp calls `law.validate(actor, action, params, world)`** (spec-law §3 taxonomy):

  | Call | When |
  |---|---|
  | `BUILD_FACILITY{facility_type, district, owner_kind, value_wref}` | Before a private investment tender (§9.1 step 8) or an entry (§9.4) |
  | `OPERATE_FACILITY{facility_type, district, hazard_class}` | When a facility first opens, when it reopens from mothball, and when law bumps `world.values["LAW_RULES_VERSION"]` (re-validate every operating facility once) |
  | `EXTRACT_RESOURCE{resource, site_district}` | Same events, for mines |
  | `IMPORT_GOOD` | Private imports |
  | `HIRE` / `SET_WAGE` | Only when a wage offer would fall below a law floor (normally prevented by §6.5) |

  **Before M3/M6** the stub returns `AUTHORIZED`.
- **`AUTHORIZED_WITH_CONDITIONS[missing]`:** the firm files the missing permit or licence application (law's permit queue). It pays the fee via ledger reason `FEE` to `gov:treasury`. A new build waits for the permit. An *already operating* facility keeps operating while the application is pending only if the misconduct rule below says so; otherwise it idles (T = 0).
- **`PROHIBITED`, a denied licence, or "keep operating while pending":** apply the **misconduct rule**. Proceed unlawfully iff
  ```
  expected monthly operating profit > 0
  AND ( Risk ≥ 70  OR  status == DISTRESSED  OR  (Risk ≥ 45 AND law's LAW_INSPECTORS ≤ 4) )
  ```
  If it proceeds, comp calls `law.record_violation(actor, action, params)`. Law emits the SECRET `LAW_VIOLATION`, and the facility's accident multiplier `V` = 1.5 (§4.5). Otherwise the facility idles, or the build is dropped.
- **Starting licences:** at month 1, every starting facility holds the licences it needs (LICENCE_HAZARD for power and processing plants, LICENCE_EXTRACTION for mines), issued month 1 with the standard terms. So law's default `REQUIRED` regimes cause no day-1 violations.
- **Law costs on operators** (paid in SETTLEMENT to `gov:treasury`):
  - royalty `LAW_EXTRACTION_ROYALTY` × MINERAL sales value (reason `ROYALTY`)
  - one-off permit and licence fees (reason `FEE`)
  - fines (M6; reason `FINE`, see §11 liabilities)
- **Land:** all land starts public (spec-law §7.1). **v1 ruling: plots for private facilities are leased at 0 rent.** Land sale and ground rent are post-v1 (lever reserved: `ECON_GROUND_RENT`).

---

## 10. Construction & procurement (closes review gaps #18, #28; question Q9)

### 10.1 Project & tender
- The core owns `Project` (X5). Econ provides the build bill (§4.4) and progress.
- **Size class** (for staff supervision, a9): `SMALL` if WU < 300, `MEDIUM` if 300–799, `LARGE` if ≥ 800. It is stored on the Project as `size_class` at creation. `STAFF_T_SUPERVISE` then needs 6 / 12 / 24 staff-WU per month.
- **Supervision effect:** coverage `s` ∈ [0, 1] is reported by staff each month (0 if unsupervised).
  - Contractor efficiency on that contract = `E_mgmt × (0.9 + 0.2 × s)`.
  - Late penalties are collected only if `s ≥ 0.5` in the month the delay is assessed. An unsupervised client doesn't notice slippage.
- **Tender:** `ECON_COMMISSION_PROJECT` creates a project (site, type, owner, budget line), opens a tender for 1 month, and needs staff task `STAFF_T_PROCURE` (a9: spec 20 WU → 1-month tender → evaluation 20 WU → award).
- At the next COMPANY_AI, contractors decide on bids (§9.2).

### 10.2 Award
**Score** for each bid:
```
score = w_p × (min_price / price) + w_r × (reliability / 100) + w_d × (min_duration / duration)
```
`w_p = ECON_PROCUREMENT_PRICE_WEIGHT/100` (default 0.5); the remainder is split 60/40, so `w_r = 0.6 × (1 − w_p)` and `w_d = 0.4 × (1 − w_p)`. Default (0.5, 0.3, 0.2).

**Who awards (Q9 ruling):**
- **Founding era:** the commander chooses manually from a scorecard UI showing all bids and scores.
- **After parliament:** `ECON_AWARD_CONTRACT` is a ministerial action:
  - The responsible minister's government (player or AI) may pick any bid.
  - If the project is delegated, the assigned official awards the top score automatically, unless the player overrides within the month.
  - Picking a non-top bid emits `ECON_CONTRACT_AWARDED` with `data.override = true`, which law/politics can use (favoritism).
- **No bids:** emits `ECON_TENDER_FAILED`. The project can be re-tendered with a budget increase.

### 10.3 Contract terms (v1 standard contract)
| Term | Rule |
|---|---|
| Price type | Fixed price |
| Advance | 10% at award |
| Progress payments | 80% × (progress this month / total WU) × price, monthly in SETTLEMENT |
| Retention | 10% paid on completion |
| Late penalty | 1% of price per month beyond the bid duration, max 10%, deducted at completion |
| Client cancellation | Pays progress to date + 5% of remaining value (a9 may refine in contract law) |
| Budget commitment | Recorded at award (econ §13.5): cash, appropriation and commitment are tracked separately |

### 10.4 Progress (PRODUCTION)
- Each contractor splits K across its contracts pro-rata to `WU_remaining / months_remaining`, with overdue contracts first.
- Per contract:
  ```
  wu      = min(alloc, WU_total / min_months, WU_remaining)
  U_mat   = min(1, MAT_on_hand / (MAT_per_WU × wu), COMP_on_hand / (COMP_per_WU × wu))
  progress = wu × U_mat
  ```
- MAT and COMP are consumed pro-rata to progress (econ Rule 3).
- **Completion:** a facility is created in state OPERATIONAL next month, owned by the client and operated per the project's operator field (government projects → the relevant public enterprise or institution).
- **Reliability update at completion:** `rel' = 0.8 × rel + 0.2 × 100 × min(1, bid_duration / actual_duration)`. If the contract was abandoned or terminated for default, `rel' = rel × 0.5`.
- **Starting reliability:** Atlas 85, WBC 70, Pioneer 60.

### 10.5 Contract facts for law (a9, M6 disputes)
- `ECON_CONTRACT_DELAYED` is emitted each late month. When the delay first reaches **4 months** (i.e. > 3), `ECON_CONTRACT_SEVERELY_DELAYED` is emitted once, with `{contract, months_late, cause_fact_ids}`. Law may open a breach dispute.
- `ECON_CONTRACT_PAYMENT_MISSED` `{contract, payer, amount_due, months_overdue}` is emitted when a client (government or private) fails a scheduled advance, progress or retention payment in SETTLEMENT. Ruling: the contractor continues for 2 months, then suspends work (progress 0).

### 10.6 Contractor failure
- If a contractor enters LIQUIDATION (§11), its contracts terminate.
- Incorporated progress stays with the project. Materials on site belong to the liquidation estate.
- The project returns to `TENDERABLE` with remaining WU.
- Emits `ECON_CONTRACT_FAILED` (responsible: company 0.6 / GOVERNMENT 0.4, per pic-core §4 example).

---

## 11. Insolvency state machine (closes blocker #4b; X9 — the one machine)

```
FORMING ──first facility operational──▶ ACTIVE
ACTIVE ──trigger D──▶ DISTRESSED ──recovery R──▶ ACTIVE
DISTRESSED ──trigger A──▶ ADMINISTRATION ──restructure ok──▶ ACTIVE (restructured)
ADMINISTRATION ──6 months w/o restructure──▶ LIQUIDATION ──estate empty──▶ DISSOLVED
ACTIVE/DISTRESSED ──all facilities sold/closed, solvent──▶ DORMANT ──3 months──▶ DISSOLVED
```

| Item | Rule (checked in SETTLEMENT step 9, after all payments) |
|---|---|
| **Fixed obligations F** | Monthly wages + loan service + upkeep at last month's levels, + any **liability due this month** (`world.table("liability")`: `{debtor, creditor, amount, due_month, kind: FINE / COMPENSATION / TAX_ARREARS}`; law creates FINE and COMPENSATION rows at M6) |
| **Trigger D** (→ DISTRESSED) | Any of: a missed payment this month (wages, utility, rent, loan, tax, **a liability due**), **or** cash < 1 × F for 2 consecutive months. An unpaid liability stays open, re-tries each month, and counts as a missed payment every month it is overdue. |
| **In DISTRESSED** | No dividends, no investment, ask floor 0.8× variable cost, upkeep at 50%, layoffs allowed up to 20%. The firm may request a rescue loan (§12.2) and may sell a facility (offer to firms with cash ≥ price, else to government). The CEO is replaced after 6 months distressed (C9). |
| **Recovery R** (→ ACTIVE) | Cash ≥ 2 × F **and** no missed payment for 3 consecutive months |
| **Trigger A** (→ ADMINISTRATION) | Missed payments in 3 consecutive months, **or** cash < −1 × F (an overdraft beyond a credit line), **or** the bank calls a loan in default (2 missed loan payments) |
| **ADMINISTRATION** | An automatic administrator (rule bot; the legal process is owned by justice, X7/X9) operates facilities whose operating margin is > 0 and idles the others. No new bids. Clients may terminate contracts. Creditors are offered a 30% haircut (Knob). If the post-haircut forecast satisfies R within 6 months → ACTIVE (`COMP_RESTRUCTURED`); else → LIQUIDATION. |
| **LIQUIDATION** | Facilities are auctioned in COMPANY_AI. Sealed bids come from firms with cash ≥ reserve, where reserve = 60% of book value (Knob). After 3 unsold months, the government has a right of first purchase at 40% of book (`ECON_BUY_FACILITY` action). Otherwise the facility becomes ABANDONED (ownerless, decays, purchasable later). Workers are laid off. |
| **Waterfall** | Unpaid wages → taxes → bank (secured on facilities) → other creditors → owners |
| **PUBLIC_ENTERPRISE** | Never liquidated. Distress → `ECON_PE_FUNDING_REQUEST`. After 3 months unfunded, upkeep stops and service degrades. |
| **Justice handoff** | Entering ADMINISTRATION emits `COMP_INSOLVENCY` with justice as consumer. When a9's courts exist (M6), the court ruling replaces the rule bot's restructure/liquidate choice. |

**Sovereign default & famine (A6 inputs):**
- **`ECON_SOVEREIGN_DEFAULT`:** the government misses loan service in 2 consecutive months, **or** misses public wages in 3 consecutive months. Government payment priority when short is public wages → benefits and pensions → contracts → loan service.
- **`ECON_FAMINE`:** colony-wide FOOD shortfall ≥ 25% in 3 consecutive months.
- Both are magnitude-100 facts. The A6 soft-fail decision is politics' call.

---

## 12. Money authority & the Colony Bank (closes blocker #5; question Q3)

### 12.1 Ruling
- **The colony cannot create money.** Credits are origin-civilization currency. Money supply changes only through the `ORIGIN` external account:
  - **In:** grants, migrant savings, (post-v1) exports.
  - **Out:** imports, emigrant savings, bank remittance.
- The **Colony Bank** is a chartered, origin-owned lender (actor kind `EXTERNAL` for blame). It lends from its own cash, with no fractional reserve. **Loans move existing credits; they do not create them.**

### 12.2 Lending rules
| Borrower | Limit | Rate (per month) | Term |
|---|---|---|---|
| Government | Credit line ≤ 150% of trailing-12-month revenue (taxes + dividends + grant). Drawn automatically when the treasury cannot cover SETTLEMENT obligations. | 0.5%, +0.25% if debt > 100% of revenue | Revolving; `ECON_REPAY_DEBT` action to repay |
| Firms | New loan if `(debt + new)/book_assets ≤ 0.5` **and** forecast EBITDA/interest ≥ 2. Rescue loans to DISTRESSED firms only if collateral (book × 0.5) covers them. | `0.6% + 0.6% × (1 − rating/100)`, rating = 100 − 100×debt/assets − 20×(DISTRESSED) | 60-month annuity |

- **Origin credit line = the government credit line above.** The Colony Bank is the `lender` in law's `BORROW{amount_wref, lender: "bank"}`.
  - The charter authorizes the commander to `BORROW` up to the credit line (spec-law §7.1).
  - After parliament, borrowing beyond the automatic draw needs the budget law.
  - Action `ECON_BORROW` (pic-economy §4) draws explicitly. SETTLEMENT also draws automatically when the treasury can't cover obligations: this *automatic* draw is pre-authorized by the charter as "liquidity drawing", and emits `ECON_GOV_BORROWED` at each 25 pp threshold.
- **Remittance:** each December the bank remits 50% of its year profit to `ORIGIN`. This is a money sink that keeps the money supply bounded.
- **Bank liquidity:** if bank cash < 1,000,000 cr, new lending stops (`ECON_BANK_CREDIT_FREEZE`, responsible `EXTERNAL` 0.7 / GOVERNMENT 0.3).
- **No interest on household savings in v1** (savings are cash).

---

## 13. Accounting, government finance & taxes (closes review gaps #19, #20; question Q13)

### 13.1 Minimal accounting model
| Item | Rule |
|---|---|
| Cash | Ledger accounts (§16) |
| Inventory value | **Weighted-average cost** per (owner, commodity). COGS = WAC × qty consumed or sold. |
| Fixed assets | Book = build price paid (or acquisition price). Straight-line depreciation over 240 months (Knob), monthly. |
| Receivables / payables | **None in v1** (cash on match). Contracts are the only deferred flows (commitments). |
| Profit (monthly, firm) | Revenue − COGS − wages − utilities − freight − rent − depreciation − interest |
| Profit tax | Assessed at quarter end on the quarter's profit after **indefinite loss carry-forward** at 100% offset (closes econ §13.4). Rate = `ECON_PROFIT_TAX_RATE`. |
| Income tax | Withheld at payroll: `rate × max(0, gross − ECON_TAX_ALLOWANCE)` per worker |
| Equity | Assets − loans (derived, not stored) |
| Public enterprises | Same rules, plus the dividend lever. Losses can be covered by `ECON_SUBSIDIZE` transfers (recorded as subsidy income, not revenue). |
| Institutions | Cost centers. Budget transfers in, costs out. No profit. |

### 13.2 Government finance (econ §13.5, closed)
- The government tracks **cash** (treasury), **appropriations** (per budget line per fiscal year) and **commitments** (awarded contracts not yet paid).
- **Budget lines** (each is a lever; LAW after parliament, COMMANDER before):
  | Line | Notes |
  |---|---|
  | `ADMIN` | |
  | `HEALTH` | |
  | `EDUCATION` | |
  | `TRAINING` | |
  | `INFRASTRUCTURE` | capex |
  | `HOUSING` | public housing capex |
  | `SUBSIDIES` | |
  | `RESERVE_PURCHASES` | |
  | `WELFARE` | **entitlement**: auto-sized by benefit levers and not capped |
- **Spending rule:** monthly spend on a line is ≤ its annual appropriation − spent YTD. Commitments count against the appropriation at award.
- **Year end:** unspent appropriations lapse in December. Multi-year contract commitments roll forward automatically.
- **Fiscal year** = calendar year. With no budget passed by January, the previous year's lines continue at 100% (Knob; politics may change to a % cut).
- **Revenue:** income tax, profit tax, import tariff, PE dividends, CHO/CPW/CTA surpluses via dividends, origin grant, fees (health/school if set), and law's extraction royalty, permit and licence fees, and fines.
- **Fines (a9, M6):** fines are paid into the dedicated ledger account **`gov:fines_revenue`**, which is swept into `gov:treasury` at the end of SETTLEMENT (reason `SWEEP`). Fine revenue is therefore separately visible. Unpaid fines are `liability` rows (§11) and feed the insolvency machine.

### 13.3 Training (skill upgrade lever)
- `TRAINING` budget buys conversions: every 4,000 cr (Knob) converts 1 unemployed General worker into a Skilled worker after 6 months.
- It is capped at 5% of unemployed General per month.

---

## 14. Companies v1: what's in, what's out (closes question Q8)

| Feature (companies.md) | v1 | Why / PIC hook |
|---|---|---|
| Company entity, facilities separate from owner/operator (§2) | **IN** | Every econ actor |
| Types: PRIVATE, COOPERATIVE, PUBLIC_ENTERPRISE, PUBLIC_INSTITUTION | **IN** | Privatization/nationalization debates; PUBLIC_SECTOR occupation |
| Publicly traded, mixed ownership, nonprofit, boards (§3.3–3.8, §6) | post-v1 | A3 |
| Owner + CEO as Persons; CEO Mgmt & Risk (0–100) | **IN** (C3–C5) | Drives forecast noise, bids, E_mgmt |
| Leader talents (17), other 9 leader skills | post-v1 | X6: role skill set = {MANAGEMENT} v1 |
| CEO replacement: retirement at 65; after 6 months DISTRESSED | **IN** (C9) | Fact `COMP_CEO_REPLACED` |
| Inheritance, family succession, M&A, hostile takeover (§7, §21) | post-v1 | A3 |
| Firm entry (§9) | **IN**, rule-based (§9.4) | `COMP_COMPANY_FOUNDED` |
| Market share, concentration (§10) | **IN** as indicators only (`ECON_MARKET_CONCENTRATION`, HHI, OFFICIAL) | Competition-law debates later |
| Reputation, multidimensional (§19) | v1 = **Reliability only** (contracts) | Procurement score |
| Institutions: clinic, school (§11–13) | **IN** (thin: §7.5) | PUBLIC_SERVICES concern |
| Private schools/hospitals (§12.5) | post-v1 (licence-gated entry rule ready) | |
| Newspapers/media (§14–15) | post-v1 (X12) | Facts already carry `visibility` for later |
| Lobbying, corruption (§16) | post-v1 | |
| Alcohol (§17) | post-v1 (X8) | |
| Misconduct/enforcement (§18) | v1 = comp **decides** whether to operate unlawfully (§9.5 rule); law records `LAW_VIOLATION` (SECRET) and owns detection and cases (X7) | `COMP_WORKPLACE_ACCIDENT`, `LAW_VIOLATION` |
| Supply contracts, subcontracting, corporate groups (§20) | post-v1 | Market class `CONTRACT` reserved |
| Corporate UI (§24) | **IN**, thin: directory, profile (overview, finances, facilities, leadership, reliability, history), industry overview | M5 panels |

---

## 15. Verification of the starting state (scratch balance check, 2026-11-10)

All of the following were recomputed from the tables above.

| Check | Result |
|---|---|
| ENERGY | Supply 2,400 vs demand 2,000 (83%) |
| WATER | Supply 3,000 vs demand 2,380 (79%) |
| FOOD | Supply 2,240 vs demand 2,000 (89%); 2 months of reserve |
| MINERAL | 800 vs 800 (100%, tight on purpose) |
| MATERIAL | 500 vs ≈ 245 non-construction + ≤ 240 at full construction load |
| COMPONENT | 40 vs ≈ 6 + ≤ 30 construction |
| CONSUMER | 850 vs ≈ 870 (slight excess demand → mild price rise → investment signal) |
| SERVICES | 4,800 vs ≈ 4,300 |
| Labor | 1,059 / 1,142 employed; unemployment 7.3% |
| Unit-cost margins at reference prices | Farm 13% · Mine 10% (after 8% royalty, MINERAL 110) · Processing 9% · Components 9% · Consumer 20% · Medical 12% · Services 16% · Power 22% · Water 27% (utility tariffs are levers) |
| Households | Disposable 487 cr per capita, essentials 266 (55%), saving rate ≈ 25% falling |
| Government | Opex ≈ 300k; revenue ≈ 240k; grant 200k; runway ≈ 48 months of the planned capex program |

**M4 soak-test acceptance targets** (headless, 10 seeds × 20 years, no player input, default levers):
- No conservation violation.
- Unemployment stays in 3–15%.
- CPI drift < 6%/year.
- ≤ 2 firm liquidations in the first 4 years in ≥ 7/10 seeds.
- No famine with default levers.
- Without player action, government debt crosses 100% of revenue between years 5 and 9 (this is the intended pressure).

---

## 16. Ledger: changes to the M1 kernel `game/sim/core/ledger.gd` (econ owns it after M1)

These are designed against the kernel as built:
- string account ids, int mcr
- `transfer(from, to, amt, memo, month) -> bool`
- `allow_negative` flag
- `EXTERNAL` is the only minting account, so total == 0
- journal compaction at 24 months

**Kept unchanged:** EXTERNAL semantics (`EXTERNAL` = the origin civilization = spec's `ORIGIN`), the total-is-0 invariant, atomic single transfer, and `compact()`.

**Changes required (to implement at M4 start, owner 88). They are backward-compatible: the existing 9 tests keep passing.**

| # | Change | Why |
|---|---|---|
| L1 | **Account id convention** `"<kind>:<id>"`: `gov:treasury`, `gov:fines_revenue` (a9), `bank`, `co:<org_id>`, `hh:<group_id>`, `inst:<org_id>`, `escrow:<contract_id>`. A doc constant, no code change. | Explainer and aggregates group by kind |
| L2 | Replace `allow_negative: bool` with **`credit_limit: int`**. 0 = no overdraft, N = may go to −N, `-1` = unbounded (only EXTERNAL). Keep `open_account(id, may_go_negative)` as a wrapper: true → −1. | Government credit line (§12.2) is a *bounded* negative balance on `gov:treasury`. The matching loan principal is tracked in the econ `loan` table, and the bank's lending pays into it. |
| L3 | **`transfer_batch(legs: Array, memo: String, month: int) -> bool`**: all-or-nothing over several `{from, to, amt}` legs. It checks every payer's limit against its *net* outflow first, then applies them all. | Payroll with withholding (employer → worker + treasury), trades with freight (buyer → seller + CTA), liquidation waterfall |
| L4 | **`memo` format** `"<REASON>"` or `"<REASON>#<fact_id>"`, where REASON is from the closed enum in `econ/reasons.gd`: `WAGE INCOME_TAX SALE FREIGHT RENT UTILITY CONTRACT_PAYMENT BENEFIT PENSION LOAN_DRAW LOAN_SERVICE PROFIT_TAX DIVIDEND SUBSIDY BUDGET_TRANSFER IMPORT TARIFF GRANT MIGRANT_FUNDS EMIGRANT_FUNDS REMITTANCE LIQUIDATION FEE ROYALTY FINE SWEEP COMPENSATION`. Unknown reasons assert. | Explainer (econ Rule 10) and indicator aggregation |
| L5 | **Monthly aggregates** `agg[month][account_id][REASON] = {in, out}`, updated inside `transfer`. They are **never compacted** (≈ 25 accounts per kind… fine). The journal still compacts at 24 months. | Indicators, fiscal history and the "where did the money go" UI over 30 years |
| L6 | **`QuantityLedger`** (new file `sim/core/quantity_ledger.gd`, same style). Keys `"<holder_acct>|<commodity>|<district>"`. Fields: `qty`, `reserved`, `wac` (mcr/unit). Ops: `produce` (mints, needs reason `PRODUCED` or `IMPORTED`), `consume` (burns: `CONSUMED`, `SPOILED`, `UPKEEP`, `BUILT_IN`), `transfer`, `reserve`, `release`. Invariant: Σqty per commodity == Σproduced − Σburned (asserted in RECORD). | Econ Rule 1 / 3 / 6 conservation, and WAC for COGS (§13.1) |
| L7 | `to_dict/from_dict` cover `credit_limit`, `agg` and the QuantityLedger. Bump the save schema. | Save (§17) |

**Rules stay in econ, not the ledger:** loans, commitments, appropriations and tax are econ tables in `WorldState` (`world.table("loan")`, etc.). The ledger only moves money and goods.

**Volume estimate:** about 3–5k journal legs/month at v1 scale (54 household groups × ~10 payments + ~20 orgs × ~30). 24 months ≈ 100k entries in a save, which is acceptable. If saves grow > 20 MB, compact household legs to per-group monthly sums.

---

## 17. Save state (econ/comp scope; closes review gap #38)
Save all of §16, plus:
- organizations (status, state-machine counters, CEO and owner refs)
- facilities (condition, T, mothball counters)
- inventories with WAC
- household groups (all fields)
- wage indices, reference prices, CPI weights
- open orders, unfilled-demand records and EMAs
- projects and contracts (progress, payments, penalties)
- tenders and bids
- import orders and ship schedule
- loans
- per-district pollution, rent and occupancy
- RNG stream states (kernel)

**Version:** `econ_schema: 1`.

---

## 18. Answers to the 15 review questions (review-economy-companies.md §7)

| Q | Ruling | Where |
|---|---|---|
| 1 | Econ's 8 commodities (X2), plus 6 non-storable capacity products. No fuel. Equipment = facility capacity + condition. Power plants use MATERIAL upkeep. | §2, E1–E3 |
| 2 | One colony-wide market per commodity, delivered-price matching, district price indicators. SERVICES is district-local. | §6.1, §6.4, E8 |
| 3 | No money creation. Origin-owned Colony Bank lends from its own cash. All money in and out goes through `ORIGIN`. | §12, E20–E21 |
| 4 | A6 soft fail. Econ defines the triggers `ECON_SOVEREIGN_DEFAULT` and `ECON_FAMINE`. | §11, E24 |
| 5 | 2,000 people, 6 districts, 18 orgs, 15M treasury + 200k/month grant for 48 months, full tables. | §3, E4–E7 |
| 6 | Groups = District × Tier × IncomeBand. Bands are re-cut each January as colony terciles. Owners live in household groups (dividends go there); Person has no cash. Published mapping to VoterCells. | §7.1–7.2, E14–E15, C3 |
| 7 | Unified Person (X6, a9 owns). Comp uses the role skill set {MANAGEMENT} + RISK on 0–100. No private↔government career moves in v1. | C4–C5 |
| 8 | Scope per §14 table (A3 applied). | §14, C1 |
| 9 | Score-based award with a procurement-rule lever. Manual in the founding era. Ministerial in government; delegated official auto-awards the top score; overrides are recorded as facts. | §10.2, E30–E31 |
| 10 | Media deferred (X12). The opinion pathway is politics' concern. Econ facts carry `visibility` and `magnitude` so media can later select from them. | C11 |
| 11 | pic-core §7 master tick accepted. Econ's internal order is in §5. | §5, E9 |
| 12 | Post-v1. When built: deterministic templates with slots, no runtime LLM (determinism, save size). | C12 |
| 13 | All tax levers are `foundingEra: COMMANDER`. Defaults: income 20% over 300 allowance, profit 20%, tariff 0. | §13, pic-economy levers |
| 14 | Perishability **in** v1: FOOD 2%/month, MEDICAL 0.5%/month. Stockpiling has a real cost. | §2.1, E2 |
| 15 | Justice owns cases, agencies and licences (X7). Econ/comp emit compliance and insolvency facts only. | §11, §14, C10 |
