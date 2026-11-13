# v8 chronicles — analysis


These chronicles (v8, seeds 1–3) ran on the build of 2026-11-13 (commit 18224f8). They are the first runs with the
bus fleet, workload and stress, firms that cut corners, crime, and old scandals that come back. Seed 3 grows
normally. **Seeds 1 and 2 collapse**: the buses stop running, and from then on the colony has a power cut and a
shortage every month for the rest of the century.

### Changed since v7

**Switched on in this run** (the chronicle header lists them: E134, PAYOUT, SUPPORT_T, FLEET, WORKLOAD, SUPPORT_A,
CONDUCT, CRIME, SCANDAL_REVIVAL)
- **Service hubs expand** when they sell out (E134).
- **Owners take the surplus**: a private firm pays its owners any cash above two months of costs (PAYOUT).
- **Office staff** (A56): part of every crew now works in an office instead of on the plant floor. The total number
  of jobs and the wage bill do not change (SUPPORT_A).
- **Commuting and buses** (A59): workers pay fares to the public transport company, which employs the transit staff
  (SUPPORT_T). It runs a real bus fleet (FLEET). Buses wear out and break down, and they crash. When there are too few
  seats, workers cannot get to work. Short crews can stop a power plant, which means a power cut. The press and the
  parties can trace the blame back to the transport budget.
- **Workload and stress** (A57): workplaces can be overloaded. Reckless or struggling firms run lean, and overload
  brings sick days, accidents and "overload incidents". Stress cases go to court, and unions can demand staffing
  levels and strike over them (WORKLOAD).
- **Firms cut corners** (CONDUCT): they skip upkeep and safety, dump waste, cut corners on contracts and overcharge.
  Cases are found by inspectors, accidents, whistleblowers, the press and parties, then go to court. The penalties
  are fines (doubled for repeat offenders), licence suspensions, convicted managers and a victims' fund.
- **Crime** (A60, CRIME): each district has theft, violence and fraud, driven by the economy. This feeds the SAFETY
  and FAIRNESS concerns. New events cover crime waves, violent crime, fraud rings broken up and districts without
  police patrols.
- **Old scandals come back** (SCANDAL_REVIVAL): newspapers can dig up an old scandal or let it be forgotten. Ella's
  scandal fire keeps a scandal at least 30% "hot" for up to four years, and attack ads can name old scandals.

**Always on**
- Union funds have a cap, and money above it goes back to members (E133). There are remittance laws (bank retention
  and a remittance tax) and a public-transport budget line.
- The bias-audit fixes (A54). Slumps, hunger and high taxes now put strong pressure on a government, but do not ban
  anything (A55). Treasury stress was eased so that governments "stop maxing taxes while holding years of reserves".

### Known problems in this build
- **The bus collapse (seeds 1 and 2).** Once the fleet dies, every year of the chronicle shows exactly 60 commute
  disruptions, 60 shortages and 12 power cuts. That is five districts cut off, five shortages and one power cut
  every month. It lasts 44 years in seed 1 (Years 57–100) and 73 years in seed 2 (Years 28–100), and it never
  recovers. Seed 1 later raised the transport budget to 2,000 (Years 86–90) and nothing changed. In seed 3 the budget
  rose steadily and the colony saw only 2 disruptions all century.
- **Zombie firms**: the same firm goes insolvent about every five months for decades. In seed 3 a 76-person firm went
  insolvent 97 times (Years 16–69). In seed 1 a 45-person firm did so 79 times (from Year 59). About 115, 126 and 214
  of the insolvencies follow this five-month pattern (v7: 44, 77, 24).
- **Fines nobody pays**: 611 of 673 fines (seed 1), 467 of 549 (seed 2) and 904 of 1,029 (seed 3) were not paid in
  full. Even so, one firm was convicted 161 times (seed 1) and keeps trading.
- **Victims win and get nothing from the state**: every injury case (39, 15 and 48) was won by the victims, most of
  them against the government (37, 12, 37). Every ruling shows `gov_paid=0`.
- **Taxes at the maximum for decades** in seeds 1–2, despite A55 (see the tax table below). Seed 3 swings the other
  way and ends with no income, sales, profit or export tax at all.
- **Police budget at zero** in all three seeds from about Year 20–35, for most of the century. After Year 30 there
  are almost no crime waves, even with no police at all.
- **No detail lines** for buses, overload incidents, shortages or union demands. The event log only counts them, so
  this analysis cannot say which goods ran short, which firms were overloaded, or whether a strike was about staffing.
- **Build caveats** (from the run notes): a crime-wave blame assertion error was printed a few times (it had no effect
  on the results). The attack-ad recording fix is not in this build, so attacks that use a revived scandal are
  undercounted.

### Already fixed for v9 (built after this run started)
- The crime-wave blame assertion error.
- Ella's fix that records an attack ad for every new target (revival-driven attacks will be counted properly).

### Still to come
- **Built but switched off in v8**: comfort services, warehouses, elder care and childcare, police stations, bank
  credit, party/union/newspaper HQs and business-service jobs, and shipping treaties with the home world.
- **Company rivalry** (A58), **criminal courts and prisons** after police (A60), and **money supply and the
  independence currency** (A61).
- **Needed before the next run** (from this analysis): a way to rebuild a dead bus fleet, and a stop to the
  five-month insolvency loop.

### What this run shows (seed 1)
- **Adults**: 1,537 at Year 1, 5,990 at Year 50, a peak of 6,643 in Year 61, then down to 3,389 at Year 100. In v7
  the same seed reached 13,945 and was still growing.
- **The collapse**: in Year 51 (November) a Fair Share Party government cut the public-transport budget from 150 to
  0. Commute disruptions began in Year 56 (26 that year) and hit 60 a year from Year 57. Bus breakdowns rose to 75
  in Years 60–69, then stopped: after Year 71 there was no fleet left to break down. Hazardous plants began closing
  as unsafe (220 closures over the century, against 210 reopenings of all kinds). At the end the colony has 1 working power plant
  and 9 mothballed ones.
- **Unemployment** averages 27.8% (range 3.3–51.8%; worst Year 65). 59 years are at 30% or more (v7: 35). Decade
  averages run 38–40% from Year 21 to Year 70, then fall to about 15%, mostly because people left or died.
- **Real income** averages 116 and ends at 34 (v7: 166 and 165).
- **Famine in Year 29** (the government declared a food emergency from Y29-10 to Y30-03 with rationing, price controls
  and an export ban). Shortage counts reached 50 or more in 55 of the 100 years.
- **Exports**: 13.0 million credits in 31 ships (v7: 47.5 million in 48). The last real cargo sailed in Year 60. After
  that came 80,000 credits in Year 66 and 265 credits (2 units of minerals) in Year 71.
- **Population loss**: ships brought 5,780 migrants and took away 3,629 (v7: 9,425 and 3,698). Most of the loss is
  not by ship: in Years 81–100 net migration is about −180, but adults fell by about 1,500.
- **Housing**: building stopped. No project of any kind was completed after Year 60. There are 191 housing facilities
  at the end (v7: 659). 70 blocks fell into disrepair and 9 were renovated (v7: 53 and 301). Slums appear 30 times,
  still as late as Year 61–62.
- **Strikes**: 33 (v7: 21). **Insolvencies**: 453 (v7: 420). The government defaulted on its debts in Years 70, 88 and 89.
- **Politics**: 27 cabinets.
  - First Minister: Equal Share Movement about 22 years, Fair Share Party 16, Workers' Union Party and Founders'
    Party about 10 each, and Labour Front, Independence Party and Free Colony Movement 8 each.
  - 2 no-confidence votes passed (Years 10 and 18) and 6 failed. There were 10 splits and 10 mergers, and 18 parties
    in all, with one independent (Nils Kvist, Y41).
  - The colony stayed a colony. Government approval averaged 33% (v7: 42%).
  - Scandals: 9. Leader changes: 55.
- **Immigration law**: only 4 changes (70→90→100 in Years 22–24, 100→80 in Year 61, back to 100 in Year 64). The door
  was open, but in Years 61–70 ships brought only 104 migrants and took 628 away.

### What this run shows (seed 2)
- **Adults**: 1,537 at Year 1, a peak of 4,237 in Year 31, 3,422 at Year 50 and 2,074 at Year 100. This is the worst of
  all v7 and v8 runs (v7: 15,059 at Year 100).
- **The collapse came early.** The colony's component exports ended with the ship of Y23-05: about 2.1 million credits
  per ship before, 54,000 after. Commute disruptions began in Year 27 and hit 60 a year from Year 28, even though the
  transport budget was 550 at the time. Then Equal Share Movement cut the budget back to 150 in Year 31. The last bus
  breakdowns came in Year 38. From Year 39 to Year 100 there is no fleet, plus 12 power cuts and 60 shortages every
  year. (New buses are built from components, so the end of component production is a likely cause. The chronicle
  cannot prove it.)
- **Unemployment** averages 19.5% (range 2.6–45.0%; worst Year 37). 21 years are at 30% or more. It falls below 10% in
  the last decades only because the workforce shrank (decade averages: 37% in Years 31–40, 9% in Years 91–100).
- **Real income** averages 94 and ends at 58 (v7: 173 and 156). It was 36 in Year 38.
- **Famine in Year 29** (food emergency Y29-09 to Y30-02). Shortage counts reached 50 or more in 74 years.
- **Exports**: 19.4 million credits in 20 ships (v7: 68.6 million in 48). No ship carried exports after Year 76.
- **Debt**: the government defaulted in Years 6, 8 and 38. Debt rose from 4.9% of GDP in Year 60 to 19.5% in Year 100;
  every v7 seed ended at 0.
- **Housing**: no block was renovated all century, and only 8 fell into disrepair. There are 112 housing facilities at
  the end (v7: 702). No project of any kind was completed after Year 40.
- **Strikes**: 47 (v7: 23); Shop & Service Workers called 32 of them and won 27. **Insolvencies**: 555 (v7: 516).
- **Politics**: 29 cabinets.
  - First Minister: Equal Share Movement about 20 years, Services First 16, Free Enterprise Party 13, Workers' Union
    Party 12, and Founders' Party and Open Market League 8 each.
  - 4 no-confidence votes passed (Years 24, 27, 39 and 43). There were 10 splits and 14 mergers, and 25 parties in
    all, with two independents.
  - The vote to give the seat to the person instead of the party failed in Year 73 (67 yes, 101 needed).
  - Approval averaged 26%, the lowest of any seed (v7: 43%). Scandals: 13.
- **Sovereignty: the colony became independent, on its third try.**
  - Year 64: a Services First government refused the charter quota (unlawful under the charter). The home world held
    back ships or payments in Years 66, 68, 70 and 72.
  - Y72-09: parliament voted 151–0. Y72-11: the referendum passed 2,067 to 94 and independence was declared. The home
    world answered with **autonomy** (Y74-12, quota cut to 20%).
  - Second try: vote Y76-11, referendum Y77-01 (1,971 to 123); autonomy again Y78-10.
  - Third try: vote Y81-01, referendum Y81-03 (1,804 to 170); recognised in Y82-02. Independent from Year 82.

### What this run shows (seed 3)
- **Adults**: 1,537 at Year 1, 6,438 at Year 50, 12,218 at Year 100, the peak (still rising). In v7: 5,995 and 8,685.
- **Transport worked**: the budget rose from 150 to 550 (Year 25) and step by step to 2,000 (Year 76). Buses broke
  down 158 times and crashed 20 times, but there were only 2 commute disruptions and 46 power cuts all century (v7: 29).
- **Unemployment** averages 17.2% (range 3.5–31.9%; worst Year 21). Only 1 year is at 30% or more. Decade averages
  are 13–22% (v7: 18.3%).
- **Real income** averages 159 and ends at 146 (v7: 171 and 161).
- **No famine.** 280 shortage events, 167 of them in Years 21–30.
- **Exports**: 83.4 million credits in 50 ships (v7: 83.6 million in 50).
- **Housing**: 482 facilities at the end (v7: 422); 201 renovated, 23 in disrepair (v7: 184 and 226). Slums appear
  16 times, four of them late (Years 78, 85, 88, 90).
- **Strikes**: 43 (v7: 18); Farm Workers' Union called 29 and won 28. **Insolvencies**: 711 (v7: 353), the highest
  of all seeds. See "Insolvencies" below.
- **Politics: one party dominates.** Equal Share Movement held the First Minister about **64 of 96 years**, always in
  coalition. Next were Free Enterprise Party about 10 years, Founders' Party 8 and Order & Stability 6.
  - 27 cabinets; 2 no-confidence votes passed (Years 22 and 70).
  - Only 3 splits, all from Free Enterprise Party over spending (Builders' Party Y22, Fiscal Prudence Party Y60,
    Balanced Budget League Y70), and 2 mergers. 11 parties in all, with two independents.
  - The colony stayed a colony.
- **The v7 scandal loop is gone**: 17 scandals (v7: 140), 64 leader changes (v7: 128) and 3 leader convictions
  (v7: 68). Parties now clean up after a scandal (17 "party cleanup" events) and banned 5 donors.
- **Taxes ran down to nothing.** Income tax sat at 35% for Years 45–82, then fell to 0 (Years 85–88 and 95–100).
  Sales tax is also 0 at the end. Profit tax was 0 in most years from Year 56, and export tax in most years from
  Year 70. Debt stayed about 1%.
- **Immigration law**: 9 changes. It went down step by step to 0 in Year 71 (August) and stayed closed. Ships brought
  no migrants after Year 80, yet the colony still grew by about 2,450 adults in the last 20 years.

### Taxes
Years in which the mid-year rate was at the ceiling (income tax 49–50%, sales tax 25%):

| | Seed 1 v7 | Seed 1 v8 | Seed 2 v7 | Seed 2 v8 | Seed 3 v7 | Seed 3 v8 |
|---|---|---|---|---|---|---|
| Income tax at 49–50% | 73 | **86** | 10 | **77** | 9 | 19 |
| Sales tax at 25% | 35 | **70** | 28 | **69** | 50 | 1 |
| Average income tax | 46% | 47% | 35% | 45% | 36% | 33% |

- Seed 1 has income tax at 50% from Year 21 to Year 100, with only Years 60–61 lower. Seed 2 has 50% in every year
  from Year 30 except Years 73–76, and sales tax at 25% without a break from Year 32 to Year 100.
- The chronicle does not show the treasury or its runway. The only signs of stress are debt (% of GDP) and defaults:
  3 in seed 1, 3 in seed 2, none in seed 3 (v7 had none).

### Insolvencies: why they are higher
| | Seed 1 v7 → v8 | Seed 2 v7 → v8 | Seed 3 v7 → v8 |
|---|---|---|---|
| Insolvencies | 420 → 453 | 516 → 555 | 353 → 711 |
| …of firms with 50+ staff | 81 → 200 | 65 → 123 | 40 → 397 |
| …that repeat a same-size insolvency 4–6 months earlier | 44 → 115 | 77 → 126 | 24 → 214 |
| Restructured | 206 → 307 | 247 → 382 | 133 → 518 |
| Liquidated | 361 → 264 | 427 → 322 | 396 → 306 |
| Worker buyouts | 48 → 0 | 52 → 1 | 24 → 7 |
| Investments | 102 → 66 | 128 → 35 | 116 → 64 |

- **The rise is mostly a loop, not more failing firms.** Firms now get restructured instead of liquidated, then fail
  again about five months later, for decades.
  - Seed 3: a 76-person firm failed 97 times and a 223-person firm 58 times (Years 36–91).
  - Seeds 1–2: a 45-person firm failed 79 and 69 times. Its loop starts in Year 59 in seed 1 and Year 30 in seed 2,
    each time just after the buses failed. (It may be the transport company, but the log does not name the firm.)
  - Leave out the repeats and seeds 1–2 are no worse than v7 (338 against 376, and 429 against 439). Seed 3 is still
    higher (497 against 329).
- **Bigger firms fail**: the average failing firm has 59, 42 and 92 staff (v7: 36, 31, 29).
- **Corner-cutting fines may play a part**: 70–78% of insolvencies come within 3 months after a fine that was not paid
  in full. That is only a little above chance, because such fines are so common: 62–75% of all months fall in such a
  window.
- **PAYOUT and lean staffing**: the log has no events for owner payouts or lean staffing, so their share cannot be
  measured. The disappearance of worker buyouts and the drop in investment fit firms with no cash left over, but that
  is a guess.

### The new systems in the log
| Count | Seed 1 | Seed 2 | Seed 3 |
|---|---|---|---|
| Corner-cutting revealed | 1,413 | 1,330 | 1,998 |
| …revealed by parties / accidents / inspectors / whistleblowers / press | 716 / 283 / 249 / 89 / 76 | 771 / 141 / 245 / 104 / 69 | 945 / 555 / 323 / 76 / 99 |
| Fines / licence suspensions / managers convicted | 673 / 606 / 278 | 549 / 472 / 242 | 1,029 / 870 / 255 |
| Convictions of the single worst firm | 161 (Y3–Y100) | 119 | 93 |
| Injury cases won by victims (against the government) | 39 (37) | 15 (12) | 48 (37) |
| Crime waves (nearly all before Year 30) | 11 | 12 | 14 |
| Violent crimes / fraud rings broken up | 235 / 4 | 255 / 2 | 244 / 14 |
| "District unpatrolled" notices | 79 | 82 | 76 |
| Overload incidents | 1,935 | 2,039 | 1,014 |
| Workplace accidents (v7) | 634 (860) | 518 (961) | 1,037 (836) |
| Bus breakdowns / crashes | 123 / 7 | 104 / 3 | 158 / 20 |
| Commute disruptions | 2,668 | 4,405 | 2 |
| Power cuts (v7) | 570 (27) | 925 (25) | 46 (29) |
| Hazardous plants closed as unsafe | 220 | 246 | 0 |
| Scandals revived / buried by the press | 0 / 0 | 2 / 1 | 4 / 1 |
| Attack ads naming an old scandal | 5 | 27 | 24 |
| Remittances (last year) | 27 (Y27) | 35 (Y35) | 61 (Y61) |

- **Corner-cutting is the biggest new stream of news.** Parties, not inspectors, expose most of it. A repeat
  offender is fined huge sums it cannot pay. Seed 1, Y55-08:
  `LAW_FINE_IMPOSED amount=393407684, paid=2121187, class=SEVERE, violation=F19390, repeat=true` (0.5% paid). The
  same firm (org:10) lost its licence for six months three times in Year 55 alone.
- **Crime** is steady: about 2–3 violent crimes a year, and fraud rings broken up mainly in seed 3. Crime waves come
  early, for example seed 2, Y22-11: `LAW_CRIME_WAVE district=d:4, monthly=16, mean=10, coverage_pm=0`.
  - All three colonies cut the **police budget to 0**: seed 1 in Year 24 (Equal Share Movement), seed 2 in Year 21
    (Equal Share Movement) and seed 3 in Year 34 (Equal Share Movement). In seeds 1–2 it stayed at 0 to the end.
    Seed 3 brought back 400 in Years 86–90 and 400–800 from Year 96.
  - The cuts show up as notices: seed 2, Y19-11, `LAW_DISTRICT_UNPATROLLED district=d:3, coverage_pm=200, budget_cut=true`.
  - Crime waves stop after about Year 30 even with no police. A wave seems to be measured against a district's own
    average, so permanent high crime becomes "normal". This is a likely reason, not checked.
  - SAFETY never becomes a debate topic or a hot campaign issue.
- **Scandal revival is rare**: the press revived only 6 scandals in 300 colony-years. Most attack ads that name an old
  scandal (56 in all) use Ella's heat floor. Only one recalls a press revival. Seed 2, Y60-07: Open Market League
  attacks Free Enterprise Party with
  `recalls={ "fid": "F23370", "kind": "DONATION", "ago": 79, "outlet": "out:12", "revived_ago": 6 }`, a 6½-year-old
  donation scandal that a paper revived half a year earlier. Free Enterprise Party is the usual target.
- **Buses and overload reach politics through the economy, not through news lines.** INFRASTRUCTURE became a debate
  topic (11 debates in seed 1, 21 in seed 2, none in seed 3; v7: 0, 0 and 3). PUBLIC_SERVICES was the top
  debate topic in seed 2 (40 of 50 debates). EMIGRATION became a hot campaign issue (7 times in seed 1, 3 in seed 2).
- **Victims**: injury cases always end with compensation awarded to the victims, for example seed 3, Y8-08:
  `type=TORT, outcome=CLAIMANT, winner={ "kind": "VICTIMS" … }, against_government=true, remedy=COMPENSATION,
  amount=21723816, gov_paid=0`. Not one of the 102 cases shows the government paying.
- **Remittance laws ended remittances everywhere.** Every seed raised the remittance tax to 50% and bank retention to
  100% (by Year 29, 36 and 62). The last remittances were in Years 27, 35 and 61.
- **Staffing**: the staffing-ratio law was changed 6 times in seed 1, 2 in seed 2 and 4 in seed 3. The record judged
  it at 0.00 of its promise in seed 2 and 0.14 in seed 1, against 0.86 in seed 3. Strikes rose to 33, 47 and 43
  (v7: 21, 23, 18), but the log does not say what each strike was about.

### Across the three seeds
- **Two of three colonies collapse.** Seed 3 is a healthy colony: 12,218 adults, 17% unemployment, full export ships.
  Seeds 1–2 peak at 6,643 and 4,237 adults and end at 3,389 and 2,074, with real income at 34 and 58 (v7: about 160).
  In both, the bus fleet died. After that, every month brought commute disruption in every district, a power cut
  and five shortages, and the colony never recovered: building stopped, exports stopped and people left or died.
  In both the trigger was a cut or a shortfall in transport (seed 1 cut its budget to 0; in seed 2 component exports
  stopped). Seed 3 kept raising the budget and had only 2 disruptions.
- **Famine is back**: seeds 1 and 2 both had a famine and a food emergency in Year 29 (v7: none).
- **Taxes**: seeds 1–2 sat at the income and sales tax ceiling for about 70–86 years, more than in v7, even after
  A55. Seed 3 went the other way and ended with every main tax at 0.
- **Insolvencies** are up in all seeds (453, 555, 711 against 420, 516, 353), mainly because the same firms fail again
  and again on a five-month cycle. Big firms fail much more often than in v7.
- **The new systems are very visible, in part too visible**:
  - About 1,300–2,000 corner-cutting cases per seed, with fines that are mostly never paid and a few firms convicted
    100–160 times.
  - About 1,000–2,000 overload incidents per seed.
  - Thousands of commute disruptions where the fleet died.
  - Crime is steady but politically silent, scandal revival is rare, and the state never pays the victims.
- **Politics**: 27–29 cabinets per seed and frequent changes of First Minister in seeds 1–2. Seed 3 has long dominance
  by one party (Equal Share Movement about 64 years). Seed 2 became independent on the third try, after the home
  world twice offered autonomy instead. Seeds 1 and 2 had 10 splits each. Government approval fell to an average of
  33% and 26% in the collapsing seeds (v7: 42–46%).
