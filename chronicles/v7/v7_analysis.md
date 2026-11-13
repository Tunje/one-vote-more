# v7 chronicles — analysis


These chronicles (v7, seeds 1–3) ran on the working build of 2026-11-12, 21:03. They are the first runs with the
fixed housing market, the globe-matched colony map and parties that only know the voters through their own polling.

### Changed since v6

**Housing and population (Bob)**
- **The housing freeze is fixed.** In v6 no builder could finish a housing block inside the bidding window, so
  nobody bid and the stock froze at about 1,150 homes. Now housing tenders run 24 months, big projects are split
  into **lots** that several builders can share, developers try the next district, and new builders are founded
  when housing tenders sit unbid.
- **Arrears instead of deadlocks**: a firm that cannot pay a supplier runs arrears rather than freezing the
  power and water chain (the cause of seed 1's decades of outages in v5–v6).
- **Housing condition counts**: voters now notice the state of their homes (renovations show up in the housing
  concern), not only rent and overcrowding.

**Parties know only what they can find out (your decision A49)**
- Every party, and the government, sees the voters through its **own picture**: polls with error, its own base
  (a bubble) and slow uptake. Bigger parties and the government (with an economic adviser) see more sharply.
- Parties draft and vote on laws using **beliefs** about what each law does. A year after each change the colony's
  record is compared with the promise, and beliefs move toward the evidence; ideology resists.
- Campaigns choose their themes and debate stances from that picture too; the real effect is still judged on the
  truth.
- New chronicle **section 10**: how far off each party's picture was, decade by decade, and which beliefs stayed
  stubborn against the record.

**The party bench (Anni, your decision A51)**
- Parties recruit people (from the civil service, local notables, the press, unions and companies), and members
  have ambitions, loyalty and grievances. They retire, challenge their leaders, defect to parties that fit them
  better (most often from a party that has just lost badly) and leak government secrets.
- **Not yet in this run**: independents, election lists and the vote on the personal mandate (built after this
  run started; they come in v8).

**Campaigns (Ella)**
- **Hot issues recalibrated**: a slum that has existed for years is background, not news; a new slum is hot for
  about a year and a half. In Ella's test runs the slums were hot in about 140 of 1,200 months instead of all of
  them, and most campaigns opened without one dominant issue.
- **Strategy genes** (A53): every party now has ten strategy settings (how fast it follows voters, issues vs its
  own themes, negative campaigning, spending, coalition willingness, election-year goodies, legislative pace,
  discipline, research, unions). In these runs every party plays the default — identical to before — and the
  learning party is switched off; the overnight optimiser uses them.

**The map (Terra)**
- **The colony map is now the landing hex of the globe**: 96 × 96 squares of 3 km. The globe has rivers and ore
  deposits; the flat map takes its coast, river, hills and ore from the landing hex and its six neighbours.
  Nothing is built on the sea, and roads go round it.

### Known problems in this build
- **Unemployment** is the main open problem: jobs do not grow with the workforce. Bob's diagnosis: the number of
  private firms stays at about 16–25 the whole century while the labour force triples; vacancies stay near zero;
  service hubs and workshops run nearly idle because demand is low. And in the worst slumps, governments under
  fiscal stress **cut** public works and the public-jobs scheme — in one test run to zero at ~50% unemployment.
- **A scandal loop in seed 3**: the Free Enterprise Party's undisclosed company donations came out 91 times and it
  changed leader 45 times over them. Its leaders were convicted again and again but stayed eligible to lead, so
  the pattern repeated until the party merged away in Year 67. A conviction should bar a leader for a while, and a
  party should learn to disclose. (Anni and Ella will fix it.)
- **Cuts in a slump**: in seeds 1 and 3, governments cut the job schemes while unemployment was above 30%
  (seed 1: eight times; seed 3: public employment 3,500 → 500 in Years 26–28). The new slump rule forbids this.
- **The public-jobs scheme was too small**: its maximum budget bought about 400 posts against ~1,600 unemployed.
- **Redrock** (the mining town) sits on a small hill patch with little or no ore nearby on most seeds.
- **The "law did what it promised" check is thin**: few law changes get judged a year later, and many show no
  measurable effect, so stubborn beliefs are hard to correct.
- These runs took 3–5 hours: a calculation in the company decisions grew with every year of history.

### Already fixed for v8 (built after this run started)
- **Slump rule**: from 15% unemployment the job schemes gain support; from 20% no government may cut them, and
  parties judge them as jobs, not as budget savings.
- **Bigger public-jobs scheme**: the maximum now buys about 1,500 posts.
- **Speed**: the company calculation is about 20–30 times faster in the late years; the results are identical.
- **Redrock stands at its ore** on every seed, next to a real ore field.
- **Party bench, part two**: election lists (the top names take the seats), independents who keep their seat until
  the next election, and a constitutional vote (2/3) on whether a seat belongs to the person or the party.
- **Informal housing (S7)**: when formal housing runs out, people double up to 130%, then build shacks; beyond that
  they are homeless. Shacks bring fire risk and worse health and delay families; homeless working families leave
  on the ship.

### Still to come
- **Jobs**: firm founding that grows with the workforce (Bob), and the service-hub trap done properly.
- **Shortages go to the government first** (grants, building, or authorising imports), only then imports.
- **Emergent settlements** (A46): the colony starts as a landing camp, settlements grow as clusters, and the first
  four years become the introduction where you choose where everything goes.
- **The expedition** (A47) and **sister colonies** (A48); **waste, sewage and cemeteries** (A45); **traffic
  engineering**; banking (loans, flat ownership, co-ops).
- **The bias audit** (A52) runs on the v8 build, and the **strategy optimiser** (A53) runs tomorrow night.

### What this run shows (seed 1)
- **Adults**: 1,537 at Year 1, 7,052 at Year 50, 13,945 at Year 100. Year 100 is also the peak, because the colony grew every year. In v6 the same seed had 2,966 at Year 50 and 2,995 at Year 100.
- **Unemployment** averages 26.6% (range 3.9–37.6%). It was below 10% only in the first decade. From Year 30 on it hovers around 30% (decade averages 28–32%). 35 years are at 30% or more; the longest unbroken run is Years 57–62, and the worst single year is Year 70 (37.6%). In v6 the average was 19.7%.
- **Real income** averages 166 and ends at 165 (v6: 154 and 138).
- **No famine.** No famine event and no famine mention anywhere (v6 had one in Year 20).
- **Strikes**: 21. **Insolvencies**: 420 (v6: 322).
- **Exports**: 47.5 million credits in 48 ships (v6: 44.5 million in 48).
- **Housing**: 53 blocks fell into disrepair and 301 were renovated. Renovations rise each decade, to 81 in Years 91–100. There are 659 housing facilities at the end (v6: 22). Slums appear 12 times, almost all in the founding years (Years 1–11), then in Years 34, 35 and 71. Shantytowns and homelessness are never mentioned.
- **Immigration law** changes: 70→50, 50→30, 30→10 (Years 18–20), then 10→30, 30→50, 50→70, 70→90, 90→100 (Years 24–28), then back and forth between 40 and 100 for the rest of the century: 100→80, 80→90, 90→100, 100→80, 80→60, 60→40, 40→60, 60→80, 80→100, 100→80, 80→60, 60→80, 80→100, 100→80. That is 22 changes in all.
- **Politics**: 26 Cabinets. The First Minister's party changed at almost every election. Equal Share Movement held the post about 29 years; Clean Planet Party, Fair Share Party and Green Frontier about 16 each; Work for All 12; Founders' Party and Ecology League 4 each. One no-confidence vote passed (Year 16, after Free Enterprise Party left Green Frontier's coalition). There were 5 splits and 3 mergers. Equal Share Movement split four times over redistribution: Fair Share Y24, Low Tax Alliance Y68, Keep What You Earn Y76, Taxpayers' League Y82. The colony stayed a **colony** all century, with the charter quota moving between 30% and 70%. Scandals: 11, of which 8 were Free Enterprise Party's.
- **Debates**: the slums came up once as the clash (Year 36). Immigration was the named clash in 20 of the 50 debates; 29 debates had no named clash. JOBS was the commonest debate topic (38 of 50) and HOUSING came up in 23. Campaign hot issues: IMMIGRATION 8 times, SLUMS 5. v6's "clash over the slums" in almost every debate is gone.
- **Knowledge**: the parties' picture error fell from about 2.9 points (Years 1–10) to 2.4 (Years 91–100). Their top worry was misread 47% of the time in the first decade and almost never after Year 20. The most stubborn belief: every party thinks the public-employment budget delivers 1.56–1.70 times its promise, but the record (27 changes) says 1.00. Similarly, public works is believed at 1.08–1.15 against a record of 0.62.
- **Public jobs and works**: the public-employment budget changed 27 times (16 raises, 11 cuts) and public works 31 times (16 raises, 15 cuts). Eight cuts took effect in years with unemployment above 30%:
  - Public employment: Clean Planet Party in Year 30 (35.7%) and Year 32 (33.4%); Fair Share Party in Year 38 (30.5%); Equal Share Movement in Year 52 (35.9%).
  - Public works: Clean Planet Party in Year 57 (32.2%) and Year 59 (32.8%); Work for All in Year 72 (32.5%) and Year 73 (31.6%).
  - Both budgets sit at 5,000 from Year 58 (employment) and Year 74 (works), yet unemployment stays around 30%.

### What this run shows (seed 2)
- **Adults**: 1,537 at Year 1, 7,507 at Year 50, 15,059 at Year 100, which is also the peak (still rising). In v6: 3,072 at Year 50 and 2,795 at Year 100.
- **Unemployment** averages 25.4% (range 3.0–40.6%). It gets worse over time: decade averages go from 10% to 34%. 44 years are at 30% or more, including an unbroken run from Year 62 to Year 83 and another from Year 86 to Year 100. The worst year is the last, Year 100 (40.6%). In v6 the average was 18.3%.
- **Real income** averages 173 and ends at 156 (v6: 170 and 189).
- **No famine.**
- **Strikes**: 23. **Insolvencies**: 516 (v6: 265).
- **Exports**: 68.6 million credits in 48 ships (v6: 58.0 million in 46).
- **Housing**: 52 blocks fell into disrepair and 357 were renovated (114 in Years 91–100). There are 702 housing facilities at the end. Slums appear 12 times, all in Years 1–19. Shantytowns and homelessness are never mentioned.
- **Immigration law** changes: 70→90 (Y28), 90→70, 70→90, 90→70, 70→90, 90→100 (Y44). Then Keep What You Earn closed it step by step: 100→80, 80→60, 60→40, 40→20, 20→0 (Years 65–68). After that it reopened: 0→20, 20→40, 40→60, 60→80, 80→100 (Years 71–74). Last changes: 100→80, 80→100, 100→80 (Y100). That is 19 changes.
- **Politics**: 27 Cabinets. Equal Share Movement held the First Minister about 36 years; Founders' Party about 15; Clean Planet Party and Keep What You Earn 12 each; Ecology League 8; Green Frontier, Work for All and Independence Party about 4–5 each. Two no-confidence votes passed (Years 8 and 11, both moved by Clean Planet Party). There were 5 splits and 4 mergers; Ecology League absorbed Green Frontier, Order & Stability and Keep What You Earn.
- **Sovereignty: the colony became independent.** The steps:
  - Year 68: a Keep What You Earn government refused the charter quota (unlawfully under the charter). The new Independence Party (founded Y68) then took the First Minister.
  - Years 70–84: the home world withheld ships or payments 8 times.
  - Year 84-04: the home world appointed a governor.
  - Year 84-09 to Year 85-05: parliament voted for independence 151–0 in nine monthly votes.
  - Year 85-07: a referendum passed, 9,670 yes to 331 no, and independence was declared.
  - Year 86-08: the home world recognised it. Colony column: COLONY until Y84, INDEPENDENCE_DECLARED in Y85, INDEPENDENT from Y86 (charter quota 0%).
- **Scandals**: 13, of which 8 were Free Enterprise Party's.
- **Debates**: the slums came up once as the clash (Year 16). Immigration was the named clash in 18 debates; 31 had no named clash. JOBS was the commonest topic (35 of 50) and HOUSING came up in 19. Campaign hot issues: IMMIGRATION 7, SLUMS 2.
- **Knowledge**: the picture error improved the most in this seed, from 3.8 points to 2.1. Top-worry misreads were 16–28% in the first two decades and about 0% later. The housing budget was judged 71 times (evidence 0.60), but beliefs at the end range from 0.16 (Development First) to 0.92 (Clean Air Coalition). The most stubborn belief: Equal Share Movement rates the strategic subsidy at 1.63 of its promise, against a record of 0.84.
- **Public jobs and works**: public employment changed 13 times (9 raises, 4 cuts) and public works 21 times (12 raises, 9 cuts). No cut took effect while unemployment was above 30%. The closest was Founders' Party cutting public employment 3,000→2,000 in Year 30 (29.0%). Public employment sits at 5,000 from Year 35 and public works at 5,000 from Year 61. Even so, unemployment climbs past 30% for most of the last 40 years.

### What this run shows (seed 3)
- **Adults**: 1,537 at Year 1, 5,995 at Year 50, 8,685 at Year 100, which is also the peak. Growth slows after immigration closes in Year 60. In v6: 3,221 at Year 50 and 2,953 at Year 100.
- **Unemployment** averages 18.3% (range 4.1–38.4%). The worst stretch is Years 25–29, peaking at 38.4% in Year 27; only 8 years are at 30% or more. After Year 51 it mostly stays between 13% and 23%. In v6 the average was 18.6%.
- **Real income** averages 171 and ends at 161 (v6: 177 and 164).
- **No famine.**
- **Strikes**: 18. **Insolvencies**: 353 (v6: 200).
- **Exports**: 83.6 million credits in 50 ships (v6: 69.3 million in 50).
- **Housing**: the worst of the three.
  - 226 blocks fell into disrepair and 184 were renovated, and the decay is late: 57 blocks in Years 81–90 and 135 in Years 91–100, while renovations fall to about 20 a decade.
  - There are 422 housing facilities at the end. Slums appear 13 times, all in Years 1–22. Shantytowns and homelessness are never mentioned.
  - Industry: 533 plant mothballings, almost all after Year 50. At the end, all consumer workshops except a few consumer-goods plants (consumerf) are mothballed: medworks 23, bakery 13, furniture 6, textile 4.
- **Immigration law** changes: 70→50, 50→30, 30→50, 50→70, 70→50, 50→30, 30→10, 10→30, 30→10, 10→20, 20→0 (Year 60, Reform & Rights League), then 0→20 in Year 99. So the colony was closed to immigrants for almost 40 years.
- **Politics**: 28 Cabinets. Development First held the First Minister about 24 years; Founders' Party about 17; Public Colony Movement 12; Colonial Solidarity about 10; Civic Liberty and Open Market League 8 each; five other parties 4 each. Three no-confidence votes passed, all early: Y10-04, Y10-10, Y13-04. There were 8 splits and 8 mergers, and 17 parties existed in all. The colony stayed a **colony** all century.
- **140 scandals, and why**: all 140 were undisclosed company donations that came out.
  - Free Enterprise Party had 91 of them (Development First 14, Public Colony Movement 13, the rest 6 or fewer). FEP's donations came mostly from three firms: org:12 (32 scandals), org:10 (29) and org:21 (15). 32 scandals involved donations above the legal limit.
  - FEP changed leader 45 times because of scandal. Its leaders were convicted again and again but stayed eligible for office ("can hold office"), so the pattern repeated until FEP was absorbed into Reform & Rights League in Year 67. After that, scandals dropped to 3–9 a decade.
  - The seed recorded 2,835 donations, against 639 and 767 in seeds 1 and 2, and 68 leader convictions, against 6 and 3. Leader changes totalled 128.
- **Debates**: the slums came up once as the clash (Year 16). Immigration was the named clash in 11 debates (none after Year 44, once the door was nearly shut), and "young people leaving" in 2. 36 debates had no named clash. JOBS (38 of 50), GOVERNANCE and ENVIRONMENT (29 each) were the commonest topics; HOUSING came up in only 15.
- **Knowledge**: this is the only seed where the parties' picture got worse: error went from 3.0 points (Years 1–10) to 3.3–3.4 (Years 61–100). In Years 71–80 the top worry was misread 46% of the time (the government's own picture, 50%). The most stubborn belief: five parties rate the political levy at 1.07–1.11 of its promise, while the record says 2.00 (it works twice as well as they think). The export tax was judged 37 times (evidence 0.75), yet beliefs range from 0.39 (Reform & Rights League) to 1.30 (Clean Planet Party).
- **Public jobs and works**: public employment changed 20 times (13 raises, 7 cuts) and public works 15 times (9 raises, 6 cuts). Civic Liberty Party cut public employment three times in a row (3,500→2,500→1,500→500) in Years 26–28, with unemployment at 33%, 38% and 36%, and cut public works 5,000→4,000 in Year 28 (36%). Both budgets were restored from Year 29 and sit at 5,000 from Year 61.

### Across the three seeds
- **Population is fixed and now in the target range.** All three colonies grow every year, unlike v6, where every seed stalled around 3,000 adults. By Year 100 seed 1 has 13,945 adults, seed 2 has 15,059 (just above the top of the 6,000–15,000 target) and seed 3 has 8,685. All cross 6,000 between about Year 41 and Year 51. All are still growing at Year 100, so seeds 1–2 would overshoot in a longer run.
- **The housing freeze is gone.** There are 422–702 housing facilities at the end (v6 seed 1: 22). In seeds 1–2, renovations outnumber blocks in disrepair about 6 to 1. Slums appear only in the founding decades. Seed 3 is the exception: its housing decays fast in the last 20 years (192 blocks in disrepair against 38 renovated).
- **Unemployment is the main open problem, and it is worse than v6.** Averages are 26.6%, 25.4% and 18.3% (v6: 19.7%, 18.3%, 18.6%). In seeds 1–2 it sits around 30% from about Year 30 to the end (35 and 44 years at 30% or more), even though both public-jobs budgets stay at 5,000 for decades. Seed 3 is the best-off seed, and it kept immigration closed from Year 60 to Year 99.
- **Governments still cut public jobs in deep unemployment**: eight cuts in seed 1 and four in seed 3 took effect with unemployment above 30%; seed 2 had none. The parties also overrate these levers: in seed 1 everyone believes public employment delivers 1.56–1.70 times its promise, against a record of 1.00.
- **Debates moved from slums to immigration and jobs.** The slums are the named clash once per seed (v6: 40–44 of 50 debates). Immigration is the most frequent named clash (20, 18 and 11 debates), JOBS is the top debate topic everywhere, and the immigration law swings constantly (22, 19 and 12 changes).
- **Economy**: no famine in any seed (v6 seed 1 had one).
  - Exports are up: 47.5, 68.6 and 83.6 million credits (v6: 44.5, 58.0, 69.3). Strikes are about the same (21, 23, 18). Insolvencies are higher: 420, 516 and 353 (v6: 322, 265, 200).
  - Consumer workshops still have not taken hold. At the end, bakeries, furniture and textile plants are mostly mothballed in all three seeds, while service hubs number 38–90.
- **Politics stays fragmented**: no party holds the First Minister more than about 36 of 100 years, and it changes hands at nearly every election (26–28 Cabinets). Seed 2 is the only v7 seed where the colony became independent: a refused charter quota (Y68), then sanctions, a governor, and finally a 97% referendum and recognition in Y86.
- **Scandals are concentrated in seed 3**: 140 of them (v6: 73, 44, 93). 91 of the 140 belonged to one party, Free Enterprise, which kept taking hidden company money under leaders who were convicted but never barred from office.
