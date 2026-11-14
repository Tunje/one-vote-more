# v9 chronicles — analysis


These chronicles (v9, seeds 1–3) are the first runs with bank credit, warehouses, police stations and holding
cells, elder care and childcare, and annual budgeting for firms, all switched on by default. They also carry the
fixes for the v8 bus collapse and the insolvency loop. **All three colonies now finish larger and richer than in
v8, and none collapses.** The bus death spiral is gone (2–24 commute disruptions per century, against 2,668 and
4,405 in v8 seeds 1–2). Insolvencies have fallen by more than half, and the five-month loop is almost gone. The new
problem is **unemployment**: it is higher than in v8 in every seed. Seed 2 sits at about 50% for the last 20 years,
and seed 1 at 40%+ for 50 years.

How the counts were made: century counts are the sum of the per-year `Counts:` lines in section 8. These include
fact types that the log only counts and does not print, such as ECON_SHORTAGE, ECON_TENDER_FAILED, BUS_BREAKDOWN and
ECON_FAMINE. Year values come from the section 7 table. Lever values are the mid-year (June) values rebuilt from
section 6. v8 numbers were recounted in the same way. Where my count differs from the v8 analysis, the method is
given beside it.

### Changed since v8

**Newly on by default** (the header lists E134, PAYOUT, SUPPORT_T, WORKLOAD, SUPPORT_A, CONDUCT, CRIME,
SCANDAL_REVIVAL, M2, WAREHOUSE, POLICE, PRISONS, FLEET, CARE, E140)
- **M2**: banks create credit.
- **WAREHOUSE**: storage buildings.
- **POLICE**: police stations and a police budget.
- **PRISONS**: criminal procedure. There are no prison buildings yet, only police holding cells (4 per station).
- **FLEET**: the bus fleet, with its v8 death spiral fixed.
- **CARE**: elder care and childcare.
- **E140**: annual budgeting for firms. A firm is judged on a 12-month profit and loss, has a credit line, and is in
  distress only when the line is used up or the year makes a loss.

**Fixes since v8**
- The insolvency repeat loop and the flood of conduct cases.
- Police budget hints (in v8 police were cut to 0), and the "government pays 0" bug.
- Farms are no longer fined for overwork when they simply cannot hire.
- A food-assistance guard: governments get a strong push against cutting food assistance once households depend on
  it, before hunger appears.
- Independence: after a declaration, the home world's offer of autonomy now goes to the colony's parliament. If
  parliament refuses it, the declaration stays in force (new fact HOME_AUTONOMY_REFUSED).
- Martyr campaigns for revealed political arrests.
- Campaign heat over overloaded workplaces now comes in bursts.
- A licence-suspension story only when a licence is newly suspended.

**Known before reading**: there is a public-services dip in Years 2–3. Annual budgeting removed most of it, but a
step in health access around month 32 remains.

### Year 100 at a glance
| | Seed 1 v8 | Seed 1 v9 | Seed 2 v8 | Seed 2 v9 | Seed 3 v8 | Seed 3 v9 |
|---|---|---|---|---|---|---|
| Adults Y100 (peak, year) | 3,389 (6,643, Y61) | **6,109** (6,803, Y58) | 2,074 (4,237, Y31) | **13,677** (Y100) | 12,218 (Y100) | **19,493** (Y100) |
| Unemployment Y100 | 11.7% | 19.4% | 9.2% | **49.8%** | 14.6% | **32.7%** |
| Unemployment, century average | 27.8% | **33.4%** | 19.5% | **28.3%** | 17.2% | 20.1% |
| Years at ≥30% unemployment | 59 | **71** | 21 | **42** | 1 | 11 |
| Real-income index Y100 (average) | 34 (116) | 77 (119) | 58 (94) | 119 (141) | 146 (159) | 166 (164) |
| Government approval Y100 (average) | 14.5% (33) | 52.6% (43) | 22.5% (26) | 40.2% (43) | 52.4% (46) | 54.9% (43) |
| Debt % GDP Y100 | 0.3 | **56.9** | 19.5 | 0.0 | 1.0 | 0.0 |
| Exports (ships) | 13.0 M (31) | **7.0 M (45)** | 19.4 M (20) | 72.6 M (48) | 83.4 M (50) | 81.5 M (50) |
| Status Y100 | colony | colony | independent (Y82) | independent (Y94) | colony | colony |

Unemployment by decade in v9:
- Seed 1: 8, 15, 33, **45, 43, 43, 43, 40**, 36, 30.
- Seed 2: 10, 14, 19, 13, 14, 28, 37, **48, 51, 50**.
- Seed 3: 11, 14, 14, 18, 21, 18, 21, 26, 26, 32 (it rises every decade).

In v8, unemployment fell late in the century mainly because the workforce shrank. In v9 the colonies keep
growing, and the jobless share grows with them.

### Century event counts
| Fact (summed from `Counts:`) | S1 v8 | S1 v9 | S2 v8 | S2 v9 | S3 v8 | S3 v9 |
|---|---|---|---|---|---|---|
| ECON_UTILITY_OUTAGE | 570 | **48** | 925 | **49** | 46 | 57 |
| ECON_COMMUTE_DISRUPTION | 2,668 | **2** | 4,405 | **7** | 2 | 24 |
| ECON_SHORTAGE | 4,068 | 2,810 | 4,661 | 1,142 | 280 | 274 |
| COMP_INSOLVENCY | 453 | **187** | 555 | **248** | 711 | **319** |
| COMP_LIQUIDATED / COMP_RESTRUCTURED | 264 / 307 | 308 / 28 | 322 / 382 | 263 / 69 | 306 / 518 | 291 / 116 |
| COMP_COURT_LIQUIDATION (new) | – | 9 | – | 27 | – | 21 |
| ECON_PROJECT_COMPLETED | 329 | 518 | 185 | **1,034** | 1,170 | **2,217** |
| ECON_HOUSING_RENOVATED | 9 | 103 | 0 | 66 | 201 | 553 |
| ECON_HOUSING_RUNDOWN | 70 | 43 | 8 | **429** | 23 | 239 |
| TRANSPORT_LINK_OPENED | 19 | 16 | 3 | 42 | 79 | 71 |
| ECON_TENDER_FAILED | 524 | **1,393** | 1,028 | 322 | 560 | **1,761** |
| ECON_CONTRACT_DELAYED | 2,914 | 6,352 | 2,264 | 8,785 | 10,352 | **22,808** |
| ECON_FAMINE (year) | 1 (Y29) | 1 (Y6) | 1 (Y29) | 0 | 0 | 1 (Y2) |
| ECON_SOVEREIGN_DEFAULT (years) | 3 (Y70, 88, 89) | 1 (Y29) | 3 (Y6, 8, 38) | 0 | 0 | 0 |
| ECON_FACILITY_CLOSED_UNSAFE | 220 | 0 | 246 | 0 | 0 | 0 |

- **Insolvency loop fixed.** I counted an insolvency as a repeat when the same firm size had failed 4–6 months
  earlier. That gives 18, 19 and 15 repeats in v9, against 115, 145 and 243 in v8. My v8 numbers are a little higher
  than the v8 analysis (126 and 214 for seeds 2–3) because I matched on size only. Failing firms are smaller: 28, 36
  and 36 staff on average (v8: 59, 42, 92). Restructurings fell from 307–518 to 28–116. Worker buyouts are back
  (2, 2, 17) and investments rose (82, 111, 192; v8: 66, 35, 64).
- **Famine**: v9 seed 1 had one in Year 6 (food emergency Y6-07 to Y6-12, with rationing). Seed 3 counted one in
  Year 2 with no emergency declared. Both are early-colony famines, not the Year-29 famines of v8.
- **Contract delays and failed tenders are now the biggest streams.** Seed 3 has 22,808 delays (about 19 a month)
  and 588 failed tenders in Years 81–90 alone. Seed 1 has 20–29 failed tenders every year from Year 61 on. Projects
  still complete (2,217 in seed 3), so this looks like a backlog of contracts, not a stop.

### Elections: the first-election landslide
| | Seed 1 v8 | Seed 1 v9 | Seed 2 v8 | Seed 2 v9 | Seed 3 v8 | Seed 3 v9 |
|---|---|---|---|---|---|---|
| Y4 largest party | Founders 82.5% | Founders **44.8%** | Founders 74.4% | Founders **50.3%** | Founders 59.3% | Founders **83.0%** |
| Y4 seats (of 151) | 133 | 68 | 112 | 76 | 89 | **142** |
| Y4 poll at campaign start | 10.2 | 55.9 | 54.5 | 26.9 | 43.5 | 10.7 |
| Y8 largest | Founders 29.2% | Founders 36.1% | Founders 71.6% | Founders 28.2% | Founders 26.0% | Founders 29.8% |
| Y12 largest | ESM 34.4% | Green Frontier 31.4% | ESM 31.6% | Free Enterprise 19.2% | ESM 38.4% | Free Enterprise 21.2% |
| Elections with one party >50% of votes | 1 | **0** | 2 | 1 (50.3%) | 1 | 1 |
| Approval Y2 / Y3 / Y4 | 1 / 84 / 90 | 16 / 78 / 62 | 0 / 90 / 90 | 0.5 / 91 / 69 | 0 / 89 / 76 | 7 / 50 / **93** |

- **The early swing is still there.** Approval falls almost to zero in Year 2 in every seed (0.5–16%), then jumps to
  50–91% in Year 3. Inflation is 37–57% in Year 2 (v8: 44–64%). So annual budgeting did not remove the Year-2 crash.
- Seed 3 repeats v8 seed 1 almost exactly. Founders' Party starts the campaign at 10.7%, gains **+72.3 points**
  (the same figure as v8 seed 1) and takes 142 of 151 seats. All five rivals go negative against it in Y4-07, and
  Development First and Colony Unity win both debates, yet Founders still wins 83%. The campaign seems to have
  almost no effect against the swing in approval.
- After Year 4 no party ever passes 50% again. The winning share in later elections is 15–37%.

### Budget cuts in hard times
Cuts that took effect in a year whose average unemployment was 20% or more:

| | S1 v8 | S1 v9 | S2 v8 | S2 v9 | S3 v8 | S3 v9 |
|---|---|---|---|---|---|---|
| Public-employment budget cuts (in ≥20% years) | 15 (8) | 2 (2) | 14 (7) | 2 (2) | 3 (2) | 4 (3) |
| Public-works budget cuts (in ≥20% years) | 15 (6) | 1 (1) | 18 (7) | 3 (3) | 5 (4) | 8 (2) |
| Years with public employment at its 5,000 cap | 60 | 74 | 29 | 73 | 81 | 66 |
| Food-assistance cuts | 11 | **1** | 3 | **0** | 1 | **0** |
| Benefit-floor cuts | 16 | 2 | 3 | **10** | 9 | **12** |

- **The food-assistance guard works.** There was one cut in 300 colony-years (seed 1, Y30-09, 100 to 80, restored
  in Y33). v8 had 15.
- **The benefit floor took its place.** Seed 2 cut it from 50 to 0 in Years 57–59 and again from 30 to 0 in Years
  73–75, while unemployment was 26–48%. It stayed at 0 for 28 of the last 41 years, and the unemployment benefit rate
  went to 0 in Year 98. Seed 3 cut it 12 times, 11 of them in years with 22–32% unemployment. The chronicle has no
  food-shortfall series, so I cannot say whether hunger followed. Shortage counts in those years were low (0–8).
- The remaining public-jobs cuts in v9 come in single crisis years: seed 1, Years 30–31 (around the default),
  seed 2, Years 50–51, and seed 3, Years 35–36. Public employment and public works sit at their 5,000 ceiling for
  66–75 years per seed, so this lever has nothing left to give when unemployment is 40–50%.

### Sovereignty
- **Seed 2 became independent in Year 94, on the first try, and the new parliament step works.**
  - Y80-09: the government refused the charter quota (unlawful under the charter). The home world withheld ships or
    payments in Y82-02, Y84-04, Y86-08 and Y88-03.
  - Y88-09: the independence vote passed 151–0. In Y88-11 the referendum passed 9,291 to 196 (12,445 eligible) and
    independence was declared.
  - The home world offered autonomy twice. Parliament refused both offers 151–0 (**HOME_AUTONOMY_REFUSED** in Y90-03
    and Y92-09), the declaration stayed in force, and independence was **recognised in Y94-03**.
  - Compare v8, where autonomy was simply granted twice (LAW_AUTONOMY_GRANTED in Y74 and Y78) and only the third try
    worked.
  - Around the dispute, seed 2 also ran its services down: police to 0 from Y75 and elder care and childcare to 0
    from Y76 (both before independence), then the health budget to 0 in Y100.
- Seeds 1 and 3 stayed colonies. They held only petition votes (13 and 12), with no defiance, independence vote or
  sanction.
- **Expeditions**: no fact containing "EXPEDITION" appears in any v8 or v9 chronicle. Either there are none, or they
  are not logged.

### Law and order
| | S1 v8 | S1 v9 | S2 v8 | S2 v9 | S3 v8 | S3 v9 |
|---|---|---|---|---|---|---|
| LAW_HIGH_CRIME (new) | – | 459 | – | 358 | – | 361 |
| LAW_CRIME_WAVE | 11 | 18 | 12 | 36 | 14 | 31 |
| LAW_VIOLENT_CRIME | 235 | 229 | 255 | 244 | 244 | 257 |
| LAW_FRAUD_RING_BUSTED | 4 | 8 | 2 | 42 | 14 | 107 |
| LAW_DISTRICT_UNPATROLLED | 79 | 70 | 82 | 30 | 76 | **0** |
| Police stations opened (years) | – | 3 (Y44, 51, 62) | – | 3 (Y28, 34, 62) | – | 4 (Y34–56) |
| LAW_HELD_IN_CELLS (reports with more held than cells) | – | 37 (17) | – | 73 (20) | – | 98 (19) |
| LAW_PRISON_DISTURBANCE / LAW_PRISON_ESCAPE | – | 11 / 20 | – | 9 / 14 | – | 13 / 24 |
| LAW_IMPRISONED (party leaders) | – | 2 (0) | – | 5 (0) | – | 16 (4) |
| Police misconduct revealed / inquiries | – | 18 / 11 | – | 52 / 35 | – | 104 / 85 |
| LAW_LICENCE_SUSPENDED | 606 | **1** | 472 | **0** | 870 | **1** |
| LAW_LICENCE_REVOKED (new) | – | 8 | – | 24 | – | 17 |
| Fines (not paid in full) | 673 (611) | 84 (41) | 549 (467) | 213 (106) | 1,029 (904) | 347 (137) |
| Managers convicted | 278 | 10 | 242 | 32 | 255 | 64 |
| Corner-cutting revealed | 1,413 | 274 | 1,330 | 576 | 1,998 | 883 |

**Police budget** (mid-year values):
- **Seed 1**: 1,000 → 600 (Y21) → 200 (Y31) → **0 from Y37**. It was 400 only in Y78–81.
  - Police powers went to 0 (Y37), sentencing to 0 (Y34) and police oversight to 0 (Y29).
  - Holding-cell reports stop after Year 40, and escapes stop after Year 30. No police means no arrests.
- **Seed 2**: held at 600–1,400 until Year 73, then **0 from Y75**. Unpatrolled-district notices start then.
- **Seed 3**: never below 600, and up to 1,800 at the end. It is the only seed with no unpatrolled notices.
- So the police-budget fix helped in seeds 2–3. Seed 1 still went to zero, two decades later than in v8 (Y37
  against Y24).
- **Police powers and sentencing go to 0 in every seed and never come back**: powers by Y37, Y57 and Y65, sentencing
  by Y34, Y53 and Y46. Each moved only 2–3 times, always downwards.
- **The cells are too small.** A station has 4 places. Seed 1 had 4 places for its first 43 years, and 7–12 people
  were held in them at disturbances. About half the reports in seed 1, and a fifth in seeds 2–3, show more people
  held than there are cells. Every escape (20, 14, 24) happened before about Year 50.
- **Crime**: LAW_HIGH_CRIME fires once a year per district. Once every district is above the threshold, the count is
  exactly 5 a year (seed 1 from Year 31, seed 2 from Year 61). Crime runs at 2.0–7.8 times the base (median 5.1).
  - Seed 1 Y100-11: `LAW_HIGH_CRIME district=d:4, theft=3183, violence=270, times_base=6.7, coverage_pm=0`.
- **Political arrests and martyrs**: I found no fact with ARREST, POLITICAL (apart from POLITICAL_LEVY) or MARTYR,
  and no misconduct kind for political arrests. The four leaders who were imprisoned in seed 3 were convicted in
  court (Y24, Y35 and Y68). So the martyr-campaign fix was never exercised.
- **Licence suspensions all but disappear**: 1, 0 and 1, each in Year 2, against 472–870 in v8. Fines and
  convictions fell by 70–95%, so fewer suspensions is expected. But 0–1 in a century, with 8–24 revocations, suggests
  the "only when newly suspended" fix also hides real new suspensions. **Check this.**
- **Victims are now paid**: `gov_paid>0` in 64 of 66, 76 of 79 and 153 of 190 rulings that carry the field. In v8
  it was 0 in every case.

### New systems in the log
| | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| ECON_BANK_FAILURE | 1 (Y42) | 1 (Y63) | 0 |
| ECON_CREDIT_CRUNCH | 3 (Y46, 47, 48) | 0 | 0 |
| COMP_CREDIT_LINE_TERMED | 2 (Y19, 55) | 2 (Y9, 12) | 2 (Y12, 36) |
| COMP_DISTRESSED (v8) | 230 (491) | 297 (596) | 405 (808) |
| ECON_STORAGE_SHORTAGE | **100** (1 every year) | **100** | **100** |
| Warehouses at Y100 | 1 | 1 | 1 |
| BUS_BREAKDOWN / BUS_CRASH (v8) | 745 / 13 (123 / 7) | 88 / 14 (104 / 3) | 204 / 28 (158 / 20) |
| Unlawful under-staffing of a service, overturned | 0 | 52 | 20 |
| Care facilities at Y100 (mothballed) | 10 (2) | 0 (12) | 10 (2) |

- **Banks are almost silent.** There were two bank failures and one three-year credit crunch in 300 colony-years,
  with no bailout, bank-run or lending facts. M2 cannot be judged from the chronicle.
- **The debt column reads 0.0 in every year of seeds 2 and 3**, and those seeds never borrowed
  (ECON_GOV_BORROWED = 0). Seed 1 borrowed (Y68, Y81) and ended at 57% of GDP after its Year-29 default. A flat 0.0
  for 200 colony-years may be true with M2, or the column may no longer be filled. **Check this.**
- **Warehouses**: exactly one storage shortage a year in all three seeds, every year from Year 1 to Year 100. No
  colony ever built a second warehouse. That looks like a yearly check that always fires, or a warehouse that can
  never grow.
- **Buses**: the fleet now survives a budget of 0. Seed 1 kept public transport at 0 from Year 45 to Year 70 and had
  no commute disruptions. Its breakdowns peaked at 185 in Years 31–40 and then fell each decade. Seed 2 cut transport
  to 0 from Year 66 to the end with 4 disruptions. So the fix removes the spiral, but transport funding now hardly
  matters. A budget of 0 for 35 years should cost something.
- **Care brings lawsuits.** In seeds 2 and 3, patients sued the government for under-staffing services, and the
  courts overturned the action:
  - 34 cases for elder care, 9 for childcare, 11 for health and 18 for police.
  - In seed 2 there were 46 such cases in Years 28–50, often over a single missing worker (`"required": 1,
    "staff": 0`).
  - Seed 2 cut both care budgets to 0 in Year 76, and all 12 of its care homes are mothballed at the end.
- **Distress (E140)** halved, and only 2 credit lines per seed were termed out, so annual budgeting does what it
  should.

### Politics
| | S1 v8 | S1 v9 | S2 v8 | S2 v9 | S3 v8 | S3 v9 |
|---|---|---|---|---|---|---|
| Governments formed | 27 | 25 | 29 | 25 | 27 | 27 |
| No-confidence passed / failed | 2 / 6 | 0 / 4 | 4 / 4 | 0 / 1 | 2 / 0 | 2 (Y26, Y50) / 1 |
| Scandals revealed | 9 | 5 | 13 | 18 | 17 | 28 |
| Scandals revived / buried by press | 0 / 0 | 1 / 0 | 2 / 1 | 10 / 4 | 4 / 1 | 20 / 5 |
| Attack ads (naming an old scandal) | 138 (5) | 132 (5) | 138 (27) | 161 (36) | 122 (24) | 206 (**88**) |
| Leader convicted | 5 | 2 | 4 | 10 | 3 | 14 |
| Strikes | 33 | **10** | 47 | **22** | 43 | **25** |
| Union endorsements / withdrawn | 119 / 50 | 73 / 32 | 47 / 16 | 65 / 22 | 39 / 22 | 47 / 18 |
| Splits / mergers | 10 / 10 | 7 / 6 | 10 / 14 | 4 / 5 | 3 / 2 | 6 / 6 |

- Scandal revival now works: 31 revivals against 6 in v8. Seed 3 attack ads name an old scandal 88 times. Seed 3
  revived 11 scandals in Years 19–28 alone.
- Strikes halved. The last strike came in Year 57 in seed 1 and Year 73 in seed 2. Seed 3 had strikes until Year
  100. There is still no detail line that says what a strike was about.
- In seed 1 no party wins more than 37% after Year 8, and no no-confidence vote passed in 100 years.
- Martyr events: none (see Law and order).

### Levers pinned at a limit
| Years at the limit (mid-year) | S1 v8 | S1 v9 | S2 v8 | S2 v9 | S3 v8 | S3 v9 |
|---|---|---|---|---|---|---|
| Income tax at 49–50% | 86 | 64 | 77 | 41 | 19 | 30 |
| Sales tax at 25% | 70 | 70 | 69 | 37 | 1 | 25 |
| Export tax at 50% | 88 | 84 | 83 | 47 | 31 | 22 |
| Minimum wage at 84 | 25 | **80** | 54 | 18 | 0 | 5 |
| Public employment at 5,000 | 60 | 74 | 29 | 73 | 81 | 66 |
| Health budget at 4,000 | 92 | 43 | 40 | 88 | 92 | 90 |

- **Seed 1 is pinned on almost everything** in v9, as in v8:
  - Income tax at 50% from Year 42 to Year 100 (except Years 73–79).
  - Sales tax at 25% and export tax at 50% for 70–84 years.
  - The minimum wage at its top value of 84 for 80 years, public jobs at the ceiling, and police and transport at 0.
  - It also has the worst unemployment and the weakest exports (7.0 M credits; the v8 collapse seed had 13.0 M).
  - The minimum wage at the top for 80 years while unemployment averages 40% is the first thing to check. It is a
    correlation, not a proven cause.
- Seed 2 is much less pinned than in v8, and seed 3 swings rather than sits.
- Levers that hardly ever move (1–3 changes in 100 years in every seed): LAW_PUBLIC_SECTOR_STRIKE,
  LAW_WORK_INSPECTORATE_BUDGET, LAW_BANK_RETENTION, LAW_LEISURE_LICENSING, LAW_TOUR_LICENSING, LAW_POLITICAL_LEVY,
  LAW_PROCUREMENT_PRICE_WEIGHT, and now LAW_POLICE_POWERS and LAW_SENTENCING (which only go down).

### Repetitive or broken in the log
- **STAFF_OVERSIGHT_REPORT** is the most common printed line in every seed: 1,444, 1,439 and 1,374, or about 14 a
  year. Of these, 93%, 88% and 84% reveal nothing (`revealed=` is empty).
  - Example: `party=Free Enterprise Party, domain=ECON, findings=52, revealed=`, repeated for each opposition party in
    the same month.
- **COMP_WORKPLACE_ACCIDENT** is second: 655, 940 and 1,342 (v8: 634, 518, 1,037). It is up in seeds 2–3.
- **Lines that repeat exactly each year or month in seed 1, Years 40–100**:
  - ECON_SHORTAGE: 36 or 37 every year, about 3 a month for 61 years. That is a lasting shortage state like v8's,
    but without power cuts.
  - ECON_PE_FUNDING_REQUEST: exactly 12 a year from Year 31.
  - LAW_HIGH_CRIME: exactly 5 a year.
  - LAW_DISTRICT_UNPATROLLED: exactly 1 a year.
- **Seed 2, Years 80–92**: 39–60 shortages a year. This overlaps the home world's sanctions (Y82–88) and the
  independence dispute, so the sanctions are a likely cause, but this is not checked.
- **ECON_STORAGE_SHORTAGE**: exactly 1 a year in every seed (see above).
- **Housing budget at 0 for decades**: seed 2 from Year 59 to Year 100, and seed 3 from Year 84. Housing that fell into
  disrepair followed (seed 2: 157, 108 and 148 in the last three decades; seed 3: 139 in Years 91–100).
- **Debt 0.0** in every year of seeds 2–3 (see above).
- **BBCode in the markdown**: `[color=#ff8a65]Gaffe[/color]` appears about 31 times per chronicle (as in v8).

### Across the three seeds
- **Biggest improvements**:
  - No collapse. Outages fell from 570 and 925 to 48 and 49, and commute disruptions from thousands to 2–24.
  - Every colony ends larger than in v8 (6,109, 13,677 and 19,493 adults) and richer (real income 77, 119 and 166).
  - Insolvencies fell by 55–59%, and the loop is gone.
  - Food assistance is protected.
  - Victims are paid.
  - Independence works through parliament.
  - Scandal revival is visible.
  - Defaults fell from 6 to 1.
- **Biggest regressions**:
  - Unemployment is higher in every seed, and in seeds 2–3 it rises to the end. Seed 2 holds about 50% for 20
    years while its population doubles.
  - Seed 1 is pinned at maximum taxes and minimum wage, with 40%+ unemployment for five decades and the lowest
    exports of any v8/v9 run.
  - The benefit floor is cut to 0 in seed 2.
  - Seed 1 police still go to 0.
  - Licence suspensions vanish.
  - The Year-2 approval crash and a first-election landslide remain: 83% in seed 3, against 44.8% and 50.3% in
    seeds 1–2.

### Problems for the next build, in order of priority
1. **Unemployment that only rises.** Seed 2 holds 48–52% from Year 70 on, and seed 3 climbs every decade to 32%.
   Public employment is already at its ceiling, so the government has no tool left. Check the job creation against
   the population growth (immigration law at 100 in seed 2 from Year 68), the 61–106 mothballed offices per seed, and
   whether the unemployment figure counts people who should not be in the labour force.
2. **Seed 1 stuck at the limits**: minimum wage at 84 for 80 years, income tax at 50%, sales tax 25% and export
   tax 50% for decades. The same seed was pinned in v8. The bias toward these limits needs another look (A55 was not
   enough).
3. **The Year-2 approval crash** (0.5–16% approval, 37–57% inflation) still decides the first election. Seed 3 went
   from a 10.7% poll to 83% and 142 of 151 seats. Find the Year-2 inflation spike, which is a bigger cause than the
   health step at month 32.
4. **Benefit floor**: extend the food-assistance guard to ECON_BENEFIT_FLOOR and the unemployment benefit. Seed 2
   set both to 0 with about 50% unemployment.
5. **Licence suspensions are 0–1 per century.** Check that the "newly suspended" test does not hide real new
   suspensions.
6. **Warehouses**: one storage shortage every year in every seed, and never a second warehouse.
7. **Debt column 0.0 for 100 years in seeds 2–3**, and almost no bank facts. Make M2 visible (lending, bank
   stress, money supply) so it can be judged.
8. **Police powers and sentencing ratchet down to 0 in every seed.** Cells are too small: 4 places for 40 years in
   seed 1, with half its cell reports showing more people held than there are cells. Prisons are needed. Seed 1 police
   budget still reaches 0 (Y37).
9. **Transport budget no longer matters**: 25–35 years at 0 with no disruption. The fix removed the spiral, but a
   zero budget should still cost service.
10. **Log noise**: show only oversight reports that reveal something (about 85–93% reveal nothing), and summarise
    LAW_HIGH_CRIME yearly instead of once per district. Add a detail line for shortages (which good) and for strikes
    (what demand). Strip the BBCode.
11. **Contract delays and failed tenders** (22,808 delays and 1,761 failed tenders in seed 3) may hide a procurement
    backlog. Check whether the delays clear.
12. **Political arrests and martyr campaigns never happened**, so that fix is untested in a full run.
