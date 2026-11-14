# v10 chronicles — analysis


These chronicles (v10, seeds 1–3) are the first runs with bread and bakeries, supplier credit, cost-plus prices,
self-funding public companies, the 12-month payout reserve, planning on deliverable capacity and hand-worked farms,
all switched on by default. **The result is mixed, and one seed is clearly worse.** Seeds 1 and 2 have lower
unemployment than in v9 (century average 24% and 22%, against 33% and 28%) and end larger and richer. Seed 3 goes
the other way: it ends with 7,237 adults instead of 19,493, spends 68 years at 30%+ unemployment, and runs **every
service budget at 0 from Year 52 to Year 100**. The first-election landslide is gone in all three seeds. The new
table of new firms shows that **founding a company rarely produces a workplace**: 11–24% of new firms are working
after twelve months, and closures destroy three to five times more jobs than new firms create.

How the counts were made: as in the v9 analysis. Century counts are the sum of the per-year `Counts:` lines in
section 8 (these include facts the log counts but does not print, such as ECON_RAW_FOOD, ECON_TARIFF_CHANGE,
ECON_SHORTAGE and UNION_STRIKE_CALLED). Year values come from the section 7 table. Lever values are mid-year (June)
values rebuilt from section 6. v9 numbers are taken from the v9 analysis; where I recounted v9, it is said beside
the number. My parser gives the same v9 totals as the v9 analysis for every fact I checked.

### Changed since v9
**Newly on by default** (the header adds E146, E147, E148, E149, E150, PAYOUT12, E157, E161)
- **E146/E147**: bread from bakeries as everyday food, raw food as the fallback (with dissatisfaction); start-up
  working capital for new firms.
- **E148**: supplier credit (30-day invoices between firms). **E149**: cost-plus prices for all goods except food,
  at most 3% a month.
- **E150**: public companies cover running costs from their own tariffs, with no automatic monthly support.
- **PAYOUT12**: private firms keep 12 months of costs before paying owners (was 2).
- **E157**: planners read deliverable capacity, not nameplate. **E161**: farms work by hand at 60% without power.

**Politics**: voters credit a government only for new highs over the past 12 months (the landslide fix).

**New in the chronicle**: the table "New firms and jobs, year by year" in section 9, and the tariff changes that
public companies make themselves (energy, water, freight) in section 6.

**Known and not fixed** (so expected below): money per adult falls; taxes at their caps; the First Minister's party
loses about 12 points per election; benefit floor cuts; police funding, powers and sentencing fall to zero; one
warehouse; the bank nearly invisible; no political arrests; no family farms or family bakeries.

### Year 100 at a glance
| | Seed 1 v9 | Seed 1 v10 | Seed 2 v9 | Seed 2 v10 | Seed 3 v9 | Seed 3 v10 |
|---|---|---|---|---|---|---|
| Adults Y100 (peak, year) | 6,109 (6,803, Y58) | **7,769** (Y100) | 13,677 (Y100) | **16,194** (Y100) | 19,493 (Y100) | **7,237** (7,668, Y72) |
| Unemployment Y100 | 19.4% | 23.0% | 49.8% | **21.7%** | 32.7% | 34.0% |
| Unemployment, century average | 33.4% | **24.4%** | 28.3% | **21.9%** | 20.1% | **32.7%** |
| Years at ≥30% unemployment | 71 | **34** | 42 | **7** | 11 | **68** |
| Real-income index Y100 (average) | 77 (119) | 103 (135) | 119 (141) | 179 (161) | 166 (164) | **99 (128)** |
| Government approval Y100 (average) | 52.6% (43) | 34.4% (37) | 40.2% (43) | 41.3% (38) | 54.9% (43) | 27.4% (34) |
| Debt % GDP Y100 (peak, year) | 56.9 | 59.0 (110.5, Y74) | 0.0 | 2.3 (14.1, Y12) | 0.0 | 2.6 (14.9, Y28) |
| Exports (ships) | 7.0 M (45) | 5.0 M (42) | 72.6 M (48) | 57.7 M (46) | 81.5 M (50) | **20.4 M (49)** |
| Status Y100 | colony | colony | independent (Y94) | colony (defiance Y92) | colony | colony |

Unemployment by decade in v10 (v9 in brackets):
- Seed 1: 8, 14, 26, 36, **37**, 30, 26, 23, 20, 23 (v9: 8, 15, 33, 44, 43, 43, 43, 40, 36, 30).
- Seed 2: 13, 10, 19, 28, 20, 27, 25, 26, 26, 24 (v9: 10, 14, 19, 13, 14, 28, 37, 47, 51, 50).
- Seed 3: 9, 14, 22, 35, 41, **49**, 45, 38, 41, 33 (v9: 11, 14, 14, 18, 21, 18, 21, 26, 26, 32).

- Seed 2 no longer climbs to 50%. It sits at 20–28% from Year 30 to Year 100 while the population more than triples.
- **Approval is lower in every seed**: the century average is 37, 38 and 34%, against 43% in all three v9 seeds.
  Years with approval under 25%: 11, 8 and 14 (v9: 6, 10, 8). The "new highs only" rule and the raw-food
  dissatisfaction both push this way; the chronicle cannot separate them.
- The chronicle has no money-per-adult, food-price or bread-price series, so the known fall in money per adult
  cannot be checked here. Inflation after Year 10 averages about 0% in every seed, as in v9.

### Seed 3: a colony with no services for 49 years
This is the main regression. The sequence in seed 3:
- Y28: sovereign default. Y42: credit crunch. Y43: bank failure.
- Income tax 50% from Y41, sales tax 25% from Y42, profit tax 50% from Y44, export tax 50% from Y34, all to Y100.
- Budgets cut to 0 and never restored: infrastructure (Y41), housing (Y42), pensions (Y43), unemployment benefit
  (Y44), police (Y45), public transport (Y46), health (Y51), education, childcare and elder care (Y52).
- Y52: unemployment 55.6%. Y53: famine and a food emergency (Y53-03 to Y53-08, with rationing).
- Y51–Y100: 7–40 completed projects a decade (v9: 224–350), 3 housing renovations in the century (v9: 553), all 12
  care homes mothballed, 88 offices and 62 service hubs mothballed, fewer than 300 private jobs.
- In those years parliament still passes 22–39 bills a decade, on merger thresholds, dominance share, emission
  targets and working hours. No bill restores a service budget in 49 years.
- ECON_ACTION_FAILED is exactly 4 a year in every year from Y51 to Y100 (v9 seed 1 had the same from Y31).

Seed 1 went through the same crisis and came back: famine and food emergency in Y43, credit crunch in Y42–43 and
Y46–48, bank failure in Y45, unemployment benefit at 0 in Y45–58, childcare and elder care at 0 in Y48–58, pensions
at 0 in Y46–59. Budgets return in Y59–62. So both weak seeds hit a fiscal wall in Years 41–45. In both, the energy
and water tariffs had already fallen to their lowest value and the funding requests of public companies had almost
stopped (see "Tariffs"). That is a correlation; the chronicle does not show the cause.

### Century event counts
| Fact (summed from `Counts:`) | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| ECON_UTILITY_OUTAGE | 48 | 70 | 49 | 39 | 57 | **106** |
| ECON_COMMUTE_DISRUPTION | 2 | 0 | 7 | 6 | 24 | 2 |
| ECON_SHORTAGE | 2,810 | 1,862 | 1,142 | **238** | 274 | **2,062** |
| COMP_INSOLVENCY | 187 | 248 | 248 | 297 | 319 | 209 |
| COMP_LIQUIDATED / COMP_RESTRUCTURED | 308 / 28 | 318 / 63 | 263 / 69 | 271 / 79 | 291 / 116 | 289 / 34 |
| ECON_LAYOFFS_MASS | 98 | 167 | 146 | **380** | 318 | 148 |
| ECON_PROJECT_COMPLETED | 518 | 794 | 1,034 | **2,113** | 2,217 | **658** |
| ECON_HOUSING_RENOVATED | 103 | 99 | 66 | **436** | 553 | **3** |
| ECON_TENDER_FAILED | 1,393 | **523** | 322 | 631 | 1,761 | 243 |
| ECON_CONTRACT_DELAYED | 6,352 | 7,211 | 8,785 | **20,396** | 22,808 | 5,775 |
| ECON_CONTRACT_PAYMENT_MISSED | 307 | **695** | 532 | 391 | 240 | **559** |
| ECON_FAMINE (year) | 1 (Y6) | 1 (Y43) | 0 | 0 | 1 (Y2) | 1 (Y53) |
| ECON_SOVEREIGN_DEFAULT (years) | 1 (Y29) | 2 (Y5, Y30) | 0 | 0 | 0 | 1 (Y28) |
| UNION_STRIKE_CALLED | 10 | **31** | 22 | 27 | 25 | 33 |

- **Insolvencies** are up in seeds 1–2 (+33%, +20%) and down in seed 3, where there is little left to fail.
  Repeats (same firm size failing 4–6 months earlier): 22, 16 and 9 (v9: 18, 19, 15), so the loop has not come back.
  20, 7 and 12 insolvencies are of firms with 0 employees.
- **Famines moved from the start to the middle**: Y43 and Y53, each with a 5-month food emergency, in the two seeds
  whose budgets collapsed. v9 had early-colony famines (Y6, Y2).
- **Defaults**: 3 against 1. Seed 1 defaulted in Y5-10, the same month as its only ECON_GOV_BORROWED fact
  (`debt_ratio_pct=25`). A default at a 25% debt ratio in the month of the loan looks wrong. **Check this.**
- **Shortages**: seed 2 has almost none (0–3 a year from Year 59, except 10 in Y89). Seed 3 has 20–44 every year
  from Year 51. Seed 1 has 11–23 a year from Year 61, about half the v9 rate.

### New firms and jobs (v10 only)
The table counts private firms and co-ops. Its "founded" totals (220, 249, 290) are lower than
COMP_COMPANY_FOUNDED (318, 324, 374), which presumably also counts other bodies.

| Whole century | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| Founded | 220 | 249 | 290 |
| Working at 12 months (share of founded) | 37 (**17%**) | 60 (**24%**) | 33 (**11%**) |
| Still building at 12 months | 57 | 52 | 58 |
| Gone by 12 months | 100 (45%) | 86 (35%) | 92 (32%) |
| In none of the three columns | 26 | 51 | 107 |
| Jobs at 12 months (per firm founded) | 1,033 (4.7) | 2,312 (9.3) | 1,476 (5.1) |
| Closed / jobs lost in closures | 221 / 5,015 | 179 / 5,566 | 203 / 5,533 |
| Net | **−3,982** | **−3,254** | **−4,057** |
| Years with no new firm working at 12 months | 67 | 59 | 74 |
| Years with 0 jobs from that year's new firms | 57 | 42 | 65 |
| Private jobs Y1 → Y25 → Y50 → Y75 → Y100 | 483 → 589 → 144 → 637 → **85** | 434 → 95 → 1,231 → 2,113 → **3,656** | 494 → 341 → 76 → 292 → **112** |
| Private jobs as % of adults, Y100 | 1.1% | 22.6% | 1.5% |

By quarter-century (founded / working at 12 m / still building / gone / jobs at 12 m / jobs lost / net):

| Years | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| 1–25 | 50 / 12 / 14 / 19 / 242 / 1,658 / −1,416 | 52 / 10 / 13 / 19 / 480 / 2,112 / −1,632 | 54 / 11 / 17 / 20 / 364 / 1,680 / −1,316 |
| 26–50 | 68 / 10 / 8 / 44 / 234 / 1,374 / −1,140 | 61 / 12 / 14 / 27 / 375 / 1,531 / −1,156 | 85 / 9 / 12 / 24 / 578 / 2,815 / −2,237 |
| 51–75 | 50 / 6 / 20 / 18 / 179 / 369 / −190 | 57 / 12 / 12 / 18 / 576 / 662 / −86 | 67 / 9 / 15 / 25 / 193 / 134 / +59 |
| 76–100 | 52 / 9 / 15 / 19 / 378 / 1,614 / −1,236 | 79 / 26 / 13 / 22 / 881 / 1,261 / −380 | 84 / 4 / 14 / 23 / 341 / 904 / −563 |

Years in which that year's new firms had 50 or more jobs after twelve months:
- Seed 1: four. Y20 (60), Y44 (95), Y84 (66), Y94 (154).
- Seed 2: fifteen. Y10, Y25 (299), Y26, Y36 (95), Y37, Y51, Y52, Y79, Y85, Y86, Y87 (77), Y91, Y92, Y93, Y96 (76).
- Seed 3: five. Y12 (61), Y21 (122), Y26 (241), Y27 (170), Y91 (293).

What the table says, plainly:
- **Company founding does not produce workplaces.** In 300 colony-years, 759 private firms were founded and 130
  (17%) were working a year later. About a fifth are still building after a year, a third to a half are already
  gone, and the rest (26, 51, 107) are open but in none of the columns (presumably no staffed plant or no sales).
- The table only looks at month 12, so the share that *ever* works is not known. The upper bound is working + still
  building + unclassified: 55%, 65% and 68%. The closure counts (221, 179, 203, almost as many as were founded) say
  that most do not last either.
- A new firm brings 5–9 jobs on average. A closure costs 23–31 (peak staff in its last twelve months). The net is
  negative in every quarter-century of every seed except seed 3, Years 51–75 (+59).
- **Seed 2 shows where private jobs really come from.** Its table sums to −3,254, yet private jobs grow from 95 in
  Year 25 to 3,656 in Year 100, about 50 a year, with no bad decade. So the growth happens after month 12 or inside
  existing firms, which the table does not show. A column for staff growth in firms older than a year would close
  this gap.
- **Seeds 1 and 3 have almost no private sector**: 85 and 112 private jobs at Year 100, about 1% of adults. Seed 1
  fell to 2 private jobs in Year 90 and seed 3 to 6 in Year 15. Single years wipe out the stock (seed 1: 698 jobs
  lost in Y81 and 925 in Y28–29; seed 3: 2,815 lost in Years 26–50). Employment there depends almost wholly on
  public jobs, and public employment is at its ceiling.

### Elections: the landslide is gone, the Year-2 crash is not
| | Seed 1 v9 | Seed 1 v10 | Seed 2 v9 | Seed 2 v10 | Seed 3 v9 | Seed 3 v10 |
|---|---|---|---|---|---|---|
| Y4 largest party | Founders 44.8% | Founders **42.3%** | Founders 50.3% | Founders **37.5%** | Founders 83.0% | Development First **21.6%** |
| Y4 seats (of 151) | 68 | 66 | 76 | 57 | 142 | 33 |
| Y4 poll at campaign start (moved) | 55.9 (−11.2) | 7.4 (**+34.9**) | 26.9 (+23.4) | 19.4 (+18.1) | 10.7 (+72.3) | 19.9 (+1.7) |
| Y8 largest (opening poll) | Founders 36.1% | Equal Share 28.7% (17.9) | Founders 28.2% | Workers' Union 23.7% (24.4) | Founders 29.8% | Workers' Union 35.8% (16.2) |
| Y12 largest (opening poll) | Green Frontier 31.4% | Founders 27.3% (17.4) | Free Enterprise 19.2% | Workers' Union 28.4% (33.0) | Free Enterprise 21.2% | Civic Liberty 31.3% (19.5) |
| Elections with one party >50% | 0 | 0 | 1 | **0** | 1 | **0** |
| Highest share in any election | 44.8% | 42.3% | 50.3% | 46.7% | 83.0% | 49.0% (Y24) |
| Approval Y2 / Y3 / Y4 | 16 / 78 / 62 | 1.5 / 39 / 58 | 0.5 / 91 / 69 | 1.3 / 54 / 52 | 7 / 50 / 93 | 0.6 / 43 / 20 |
| First Minister's party, average change per election (n) | −11.6 (23) | **−14.5** (22) | −12.3 (22) | **−13.2** (22) | −13.7 (22) | **−13.8** (21) |
| First Minister's party keeps the post after an election | 4 of 24 | 3 of 24 | 3 of 24 | 5 of 24 | 3 of 24 | 3 of 24 |

- **The fix works.** No party passes 50% in any of the 75 v10 elections. The Year-3 approval rebound is now 39–54%
  instead of 50–91%.
- **The Year-2 crash is unchanged**: approval 0.6–1.5% in every seed, with inflation of 34–40% (v9: 37–57%).
- Seed 1 still shows the old shape in a weaker form: Founders' Party opens at 7.4%, the lowest of six, gains 34.9
  points and wins with 42.3%. It falls to 13.7% in Year 8.
- **The First Minister's party loses 13–15 points per election**, a little worse than v9 (12–14). I computed this
  for both versions from sections 3 and 4: the party holding the post just before each election, its share then
  minus its share at the election before. Elections where that party was not on both ballots are left out (2–4 per
  seed), so the figure may be slightly off. It gained votes in 6 of 65 cases (v9: 3 of 67).

### Bread, supplier credit, prices
- **ECON_RAW_FOOD**: 0, 373 and 297. The fact is counted but never printed, so there is no detail (how many
  people, which district).
  - In seed 2 it is **exactly 4 a year in every year from Year 9 to Year 100**. In seed 3 it is 4 a year from Year
    25 (the year its first bakery was ordered) to Year 100, with five years at 2–3. So where bakeries exist, they
    fail to cover demand in almost every quarter. Seed 2 ends with 14 working bakeries and 13 mothballed; seed 3
    with 16 and 2.
  - **Seed 1 has no bakery until Years 91–100** (one, mothballed) and has **zero** raw-food facts. Either the fact
    needs a bakery to exist, or nobody there is counted. If people in seed 1 ate raw food for 100 years, the log
    hides it. **Check this.**
  - Only 0, 6 and 1 bakeries were ordered as political projects (POL_PROJECT_ORDERED type=BAKERY). The others
    appear only in the investment list of section 9.
- **Bread price, food price**: no series and no fact in any chronicle.
- **Supplier credit (E148)**: no fact contains INVOICE, SUPPLIER or WRITE in any seed. COMP_CREDIT_LINE_TERMED is
  2, 1 and 1 (v9: 2, 2, 2). ECON_CONTRACT_PAYMENT_MISSED more than doubled in seeds 1 and 3, but that fact is about
  public contracts and may have nothing to do with invoices. E148 cannot be judged from the chronicle.
- **Cost-plus prices, PAYOUT12, start-up capital**: no fact of their own. COMP_INVESTMENT doubled in seeds 1–2 (165
  and 199, v9: 82 and 111). The new-firm table is the only evidence for start-up capital, and it is not good.

### Tariffs and public companies (E150)
| | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| ECON_TARIFF_CHANGE | – | 237 | – | 251 | – | 173 |
| Tariff lever changes in section 6 (share of all lever changes) | 0 | 308 (26%) | 0 | 384 (29%) | 0 | 246 (26%) |
| ECON_PE_FUNDING_REQUEST | 1,330 | **729** | 1,931 | **707** | 1,370 | **399** |
| Energy tariff at 10, its lowest value | – | Y36–100 | – | never | – | Y40–100 |
| Water tariff at 5, its lowest value | – | Y28–100 | – | Y89–100 | – | Y32–100 |

- Tariff changes do **not** dominate the event log: they are counted (2–8 a year, then fewer) but not printed. They
  do inflate section 6 and the "Lever changes" line of the summary (1,189, 1,347 and 955, against 638, 681 and 842
  in v9). Without tariffs the totals are 881, 963 and 709.
- Funding requests halved, and the v9 pattern of exactly 12 a year is gone. In every seed they run at 10–24 a year
  until about Year 26–31 and then drop: seed 1 has 0–3 a year in Years 29–65, seed 2 mostly 1–8, and seed 3 has
  none at all from Year 61.
- **In seeds 1 and 3 the energy tariff steps down by 1 each quarter to 10 and the water tariff to 5, and then
  neither moves again** for 60–70 years. These are the lowest values seen in any run, so probably the floor. Under
  E150 a public company should set its tariff to cover its costs. A tariff resting on the floor for six decades in
  the two seeds with the weakest economies needs a look: either costs really are that low, or the rule walks the
  tariff down and cannot bring it back. Seed 2, the healthy seed, keeps an energy tariff of 42–60 that still moves
  in Year 99.

### Taxes, budgets and cuts in hard times
| Years at the limit (mid-year) | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| Income tax at 49–50% | 64 | 38 | 41 | **7** | 30 | **67** |
| Sales tax at 25% | 70 | 37 | 37 | 11 | 25 | **65** |
| Export tax at 50% | 84 | 85 | 47 | 14 | 22 | **76** |
| Profit tax at 50% (v9 not counted) | – | 25 | – | 0 | – | 57 |
| Minimum wage at 84 | 80 | 61 | 18 | 15 | 5 | **72** |
| Public employment at 5,000 | 74 | 64 | 73 | 66 | 66 | 74 |
| Health budget at 4,000 | 43 | 91 | 88 | 97 | 90 | 37 (then 0 from Y51) |
| Unemployment benefit rate at 0 | – | 14 (Y45–58) | 3 (from Y98) | 0 | – | **56 (Y45–100)** |
| Benefit floor at 0 | 0 | 0 | 28 | **0** | 0 | 1 (Y52) |
| Police budget at 0 | 60 | 49 | 26 | **0** | 0 | **55 (Y46–100)** |
| Public transport budget at 0 | 26 | 38 | 35 | 0 | – | 54 (Y47–100) |

Cuts that took effect in a year with 20% unemployment or more (v10: all cuts in brackets):

| | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| Public-employment budget | 2 | 4 (5) | 2 | 2 (2) | 3 | 0 (1) |
| Public-works budget | 1 | **10** (12) | 3 | 0 (0) | 2 | 0 (1) |
| Food assistance (v9: all cuts) | 1 | **3** (3) | 0 | 0 (0) | 0 | 1 (1) |
| Benefit floor (v9: all cuts) | 2 | 9 (12) | 10 | **15** (15) | 12 | **16** (17) |
| Unemployment benefit rate | – | 12 (14) | – | 8 (8) | – | 5 (6) |

- **The pinned seed moved.** Seed 1 is less pinned than in v9, seed 2 is hardly pinned at all, and seed 3 is now at
  every limit for 57–76 years. The pattern (maximum taxes, minimum wage at the top, worst unemployment, weakest
  exports) is the same as seed 1 in v8 and v9.
- **Benefit floor**: it reaches 0 only once (seed 3, Y52, at 55.6% unemployment) and is restored in Y53. But it is
  cut more often than in v9, and 40 of the 44 cuts fall in years with 20%+ unemployment. It swings between 40 and
  100 in a 10–15 year cycle in every seed.
- **The unemployment benefit took the hit instead**: 0 for 14 years in seed 1 and for the last 56 years in seed 3,
  both while unemployment was 30–56%.
- **Food assistance** was cut 4 times (v9: 1), all in years above 20%: seed 1 in Y28 (to 80, restored Y29) and
  Y75–76 (to 60, restored by Y78); seed 3 in Y28 (to 80, restored Y31). The guard is weaker than in v9.

### Sovereignty and politics
- **No colony became independent** (v9 seed 2: Y94). **Seed 2** started the same dispute 12 years later:
  LAW_CHARTER_DEFIANCE in Y92-09 (refusing the quota, unlawful under the charter), then HOME_SANCTION (withholding)
  in Y94-03, Y96-01, Y98-01 and Y99-10. No independence vote before Year 100. It sent 19 petitions.
- Seeds 1 and 3 held petition votes only (13 and 14). No defiance, no sanction.

| | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| No-confidence passed (years) / failed | 0 / 4 | 2 (Y25, Y91) / 2 | 0 / 1 | 1 (Y25) / 3 | 2 / 1 | 1 (Y96) / 2 |
| Scandals revealed | 5 | 11 | 18 | 11 | 28 | 31 |
| Scandals revived / buried by press | 1 / 0 | 8 / 2 | 10 / 4 | 12 / 7 | 20 / 5 | **40** / 9 |
| Attack ads (with `recalls=` an old scandal) | 132 (5) | 157 (13) | 161 (36) | 147 (30) | 206 (88) | 163 (77) |
| Leader convicted | 2 | 7 | 10 | 5 | 14 | 13 |

### Law and order
| | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| LAW_HIGH_CRIME | 459 | 440 | 358 | 357 | 361 | 439 |
| LAW_DISTRICT_UNPATROLLED | 70 | 70 | 30 | **2** | 0 | **57** |
| Police stations opened (years) | 3 | 2 (Y86, Y98) | 3 | 4 (Y45–49) | 4 | 1 (Y30) |
| LAW_HELD_IN_CELLS (more held than cells) | 37 (17) | 52 (20) | 73 (20) | 99 (19) | 98 (19) | 41 (3) |
| LAW_LICENCE_SUSPENDED / REVOKED | 1 / 8 | 1 / 14 | 0 / 24 | 0 / 18 | 1 / 17 | 0 / 13 |
| LAW_HARMFUL_CONDUCT_REVEALED | 7 | **157** | 6 | 44 | 6 | 5 |

- **Police budget**: seed 1 is at **0 from Y38** (v9: Y37), with four returns to 400 for 3–4 years each. Seed 2 is
  never at 0 and moves between 400 and 2,000 (v9: 0 from Y75). Seed 3 is at **0 from Y45 to Y100** (v9: never below
  600).
- **Police powers and sentencing still go to 0 in every seed and never come back**: powers by Y45, Y53 and Y25,
  sentencing by Y34, Y38 and Y23. Each moved 2–3 times, only downwards.
- **Crime** runs at 2.0–7.9 times the base; the median is 5.7, 2.6 and 6.8. Seed 2, the one seed that keeps paying
  its police, has less than half the crime of the others. The field now prints as `times_base_x10=53`.

### Other systems, and what is repetitive or broken
| | S1 v9 | S1 v10 | S2 v9 | S2 v10 | S3 v9 | S3 v10 |
|---|---|---|---|---|---|---|
| ECON_BANK_FAILURE (years) | 1 | 1 (Y45) | 1 | 0 | 0 | 2 (Y43, Y96) |
| ECON_CREDIT_CRUNCH (years) | 3 | 5 (Y42–43, 46–48) | 0 | 0 | 0 | 5 (Y42, 85–87, 90) |
| ECON_GOV_BORROWED | 2 | 1 (Y5) | 0 | 0 | 0 | 0 |
| ECON_STORAGE_SHORTAGE (warehouses at Y100) | 100 (1) | 100 (1) | 100 (1) | 78 (1) | 100 (1) | 78 (1) |
| Care facilities at Y100 (mothballed) | 10 (2) | 10 (2) | 0 (12) | 10 (2) | 10 (2) | **0 (12)** |
| STAFF_OVERSIGHT_REPORT (share revealing nothing) | 1,444 (93%) | 1,361 (85%) | 1,439 (88%) | 1,266 (82%) | 1,374 (84%) | 1,248 (88%) |
| POL_POLICY_EVIDENCE | 594 | 1,146 | 643 | 1,298 | 799 | 926 |
| BBCode `[color=…]` in the text | 31 | 41 | 31 | 36 | 32 | 32 |

- **The debt column is filled now**: non-zero in 96, 95 and 73 years. But ECON_GOV_BORROWED appears once in 300
  colony-years, while seed 1's debt climbs to 110.5% of GDP in Y74 and seed 3 defaults in Y28. Borrowing happens
  without the fact. The bank is still nearly silent: 3 failures and 10 crunch years, all in seeds 1 and 3.
- **Warehouses**: still one per colony. In seeds 2–3 the yearly storage shortage skips some early years, then fires
  every year from Year 41.
- **Most frequent printed lines**: STAFF_OVERSIGHT_REPORT, POL_POLICY_EVIDENCE (doubled in seeds 1–2),
  COMP_WORKPLACE_ACCIDENT (866, 1,181, 793), LAW_CASE_FILED (710, 1,054, 595), LAW_VIOLATION_REVEALED. The largest
  counted-only streams are ECON_CONTRACT_DELAYED, ECON_OVERLOAD_INCIDENT, ECON_SHORTAGE and MEDIA_FALSE_REPORT.
- **Mechanical repeats**: ECON_RAW_FOOD 4 a year; ECON_STORAGE_SHORTAGE 1 a year; in seeds 1 and 3, LAW_HIGH_CRIME
  exactly 5 a year from Y26 and LAW_DISTRICT_UNPATROLLED exactly 1 a year from Y35 and Y44; ECON_ACTION_FAILED
  exactly 4 a year in seed 3 from Y51; PLANET_MOON_SURGE is 47 in all six chronicles.
- **Pinned for decades**: energy tariff 10 and water tariff 5 (seeds 1, 3); every service budget at 0 in seed 3;
  police powers and sentencing at 0 for 48–77 years in all seeds; health budget at 4,000 for 91 and 97 years in
  seeds 1–2; public-company dividend rate at 100 from Year 28–30.
- **Zeros that should not be**: ECON_RAW_FOOD in seed 1; ECON_GOV_BORROWED in seeds 2–3; any invoice or
  supplier-credit fact. The line "Plants scrapped: 0 · mothballed: N" in section 9 reads 142, 2 and 0, but the
  facility list above it shows 172, 182 and 165 mothballed facilities.

### Status of the 12 problems from the v9 analysis
| # | v9 problem | v10 | The number |
|---|---|---|---|
| 1 | Unemployment that only rises | **Improved in seeds 1–2, worse in seed 3** | Century average 24.4 / 21.9 / 32.7% (v9: 33.4 / 28.3 / 20.1). Seed 2 ends at 21.7%, not 49.8% |
| 2 | Seed 1 stuck at the limits | **Unchanged (moved to seed 3)** | Seed 3: income tax 50% for 67 years, sales tax 65, export tax 76, minimum wage 72. Seed 1: 38, 37, 85, 61 |
| 3 | Year-2 approval crash decides the first election | **Landslide fixed, crash unchanged** | Y4 largest party 42.3 / 37.5 / 21.6% (v9: 44.8 / 50.3 / 83.0). Y2 approval still 0.6–1.5% |
| 4 | Benefit floor cut to 0 | **Improved for the floor, worse for the benefit** | Floor at 0 for 1 year in total (v9: 28). But 40 floor cuts in 20%+ years, and the unemployment benefit at 0 for 14 and 56 years |
| 5 | Licence suspensions 0–1 a century | **Unchanged** | 1, 0, 0 (revocations 14, 18, 13) |
| 6 | One warehouse, a storage shortage every year | **Unchanged** | 1 warehouse each; 100, 78, 78 shortages |
| 7 | Debt column 0.0; bank invisible | **Debt column fixed, bank unchanged** | Debt non-zero in 73–96 years. 3 bank failures; 1 borrowing fact |
| 8 | Police powers and sentencing to 0; small cells; seed 1 police at 0 | **Unchanged; worse in seed 3, better in seed 2** | Powers 0 by Y45 / Y53 / Y25. Police budget at 0 for 49 / 0 / 55 years. 20, 19, 3 over-full cell reports |
| 9 | Transport budget does not matter | **Unchanged** | 38 and 54 years at 0 with 0–2 commute disruptions |
| 10 | Log noise | **Unchanged** | Oversight reports 82–88% empty; BBCode 32–41; no shortage or strike detail |
| 11 | Contract delays and failed tenders | **Unchanged per project** | 9.1 / 9.7 / 8.8 delays per completed project (v9: 12.3 / 8.5 / 10.3). Seed 2 failed tenders 322 → 631 |
| 12 | No political arrests or martyr campaigns | **Unchanged** | No such fact in 300 colony-years |

### Problems for the next build, in order of priority
1. **New firms do not become workplaces.** 17% of 759 new private firms are working after a year; a third to a
   half are gone. Seeds 1 and 3 end with about 100 private jobs. Find out why firms are still building after 12
   months (57, 52, 58) or die before opening (100, 86, 92), and what the 26–107 open-but-idle firms lack. Add to the
   table: staff growth in firms older than a year, and the reason a firm was gone.
2. **Seed 3's dead state**: every service budget at 0 from Year 52 to Year 100 with all taxes at their caps, while
   parliament legislates on other things. Seed 1 was in the same state in Years 44–58 and got out. A government
   with health, schools and police at 0 for 49 years needs a strong push to restore them, and the cause of the
   fiscal wall in Years 41–45 (both seeds) needs finding. Start with the tariffs (point 3) and the missing money.
3. **Energy and water tariffs on their floor for 60–70 years** in seeds 1 and 3, and public-company funding
   requests that almost stop around Year 30. Check that E149/E150 cannot walk a tariff down to a level that no
   longer pays for the plant.
4. **Bread does not cover demand**: ECON_RAW_FOOD fires every quarter for 76–92 years, and seed 1 has no bakery for
   90 years and no fact at all. Print the fact with numbers (people on raw food, district), fire it when there is
   no bakery too, and add bread and food prices to the year table.
5. **The First Minister's party loses 13–15 points per election** and keeps the post after 3–5 of 24 elections. The
   "new highs only" rule fixed the landslide, but approval is now lower throughout (average 34–38%).
6. **Taxes and the minimum wage at their caps** in the weakest seed (now seed 3). Same finding as v8 and v9.
7. **Unemployment benefit and food assistance**: extend the guard. The benefit rate was 0 for 56 years in seed 3
   at 33–56% unemployment; food assistance was cut 4 times in hard years.
8. **Police powers and sentencing still ratchet to 0** in every seed; the police budget is 0 for 49 and 55 years
   in seeds 1 and 3; cells hold up to 13 people in 4 places. Prisons are still needed.
9. **Make the new systems visible**: no fact for invoices, supplier write-offs, cost-plus price moves, start-up
   capital or the payout reserve. ECON_GOV_BORROWED fires once although debt reaches 110% of GDP.
10. **Check these single oddities**: seed 1's default in Y5-10 in the month of its loan at a 25% debt ratio;
    harmful-conduct cases ×22 in seed 1; "mothballed: 0" in seed 3's industry summary against 165 mothballed
    facilities; overload incidents in seed 2 (56 → 688 a decade).
11. **Carried over unchanged from v9**: one warehouse and a storage shortage every year; licence suspensions 0–1 a
    century; a transport budget of 0 costs nothing; oversight reports that reveal nothing (82–88%); no detail for
    shortages and strikes; BBCode in the text; no political arrests or martyr campaigns. New: keep the tariff changes
    out of the "Lever changes" total in the summary (they are 26–29% of section 6).
