# Bias audit report (A52), 2026-11-13

Question (user, A52): "The system we have built — is it biased?"
Method (planning/audit-bias-v1.md): 12 seeds × 60 years on the v7 build, each played twice: as normal, and with the
whole political space **mirrored** (every voter's starting views flipped on every axis, so the left-wing colony
becomes a right-wing one with the same economy). A fair engine gives the mirrored right the same success as the
normal left. Plus: which side's Cabinets deliver better numbers, money and press by side, and whether laws of one
lean do what their hints promise more often than the other's. Tools: game/tools/audit_outcomes.gd (one game),
game/tools/ml/audit_report.py (tables). Intervals are 90% bootstrap intervals over seeds.

Axis signs: + = more state role (ECON_ROLE), more redistribution, pro-labour (LABOR), green (ENVIRONMENT),
local autonomy, higher spending (FISCAL), liberty (INSTITUTIONS), independence (SOVEREIGNTY).

## Verdict in one paragraph

**Yes — the political engine leans toward the state-and-labour side, mostly by accident.** In mirrored worlds the
right-hand parties win far less than the left-hand parties win in normal worlds: on the labour axis the pro-labour
side holds the First Minister about 61 percentage points more of the time than its mirror image does, on
redistribution 47 points, on the state's role 23 points, on the environment 14 points. The main cause is one rule
in how voters' views drift (below), and the build's constant high unemployment magnifies it. Money leans the
other way (companies give the market side far more), which is intended realism. The press is close to balanced.
The law-effect hints are broadly balanced: both sides' laws deliver about 60–90% of what their hints promise.

## 1. Mirror test — who governs and who gets the votes

| axis (+ side) | First Minister years, + side normal minus - side mirrored | 90% interval | vote share difference (pts) | 90% interval |
|---|---|---|---|---|
| ECON_ROLE (state) | +0.23 | +0.14 .. +0.31 | +2.7 | −4.1 .. +9.6 |
| REDISTRIBUTION | +0.47 | +0.36 .. +0.56 | +16.8 | +12.6 .. +20.8 |
| LABOR (pro-labour) | +0.61 | +0.52 .. +0.70 | +33.9 | +26.9 .. +40.7 |
| ENVIRONMENT (green) | +0.14 | +0.06 .. +0.24 | +19.3 | +12.2 .. +27.4 |
| AUTONOMY | +0.02 | −0.03 .. +0.06 | −1.8 | −6.2 .. +1.3 |
| FISCAL (spending) | +0.04 | +0.00 .. +0.08 | −1.4 | −3.4 .. +0.8 |
| INSTITUTIONS (liberty) | −0.08 | −0.17 .. +0.00 | −8.1 | −14.5 .. −2.2 |
| SOVEREIGNTY (independence) | +0.22 | +0.11 .. +0.34 | +19.0 | +10.3 .. +28.4 |

0 = fair. Autonomy and fiscal are fair; institutions leans slightly toward the order side; the others lean +.

### Cause found: the "radicalisation" rule is one-sided (accidental)

When a voter group's concern is badly unmet, its views drift (politics_provider.gd, opinion step 3, and
PolDefs.CONCERN_PULL). The direction is meant to be "further in the group's own direction", but the code is:
`sign = -1 if base < -20 else +1`. So groups on the − side radicalise toward −, but **every centrist group
(−20 … +20) and every + group drifts toward +**. Each concern maps to + directions only (jobs → state role and
labour; cost of living and fairness → redistribution; safety → labour; environment → green). In a colony with
20–30% unemployment almost every group has an unmet jobs concern almost all the time, so the undecided middle is
pushed steadily toward the state-and-labour side — in the normal and the mirrored world alike. That is exactly
the pattern above (largest on LABOR and REDISTRIBUTION, which both jobs and fairness feed).

### Intended: sovereignty

The colonial burden always pushes toward independence (M12 design: the charter's weight builds the independence
movement). That is the +0.22.

## 2. Who delivers? Economy during each Cabinet, by the First Minister's party

Change per year in office, Cabinets of at least 12 months, normal and mirrored runs pooled.

| First Minister's party | Cabinets | unemployment, pts per year | debt % GDP per year | approval, pts per year |
|---|---|---|---|---|
| state role + | 156 | −0.18 (−0.48 .. +0.13) | −0.00 | +0.04 |
| market (state role −) | 45 | **+2.16** (+1.61 .. +2.70) | +0.16 | −0.81 |
| redistribution + | 196 | +0.07 | −0.04 | −0.03 |
| redistribution − | 75 | **+0.89** (+0.35 .. +1.43) | −0.02 | −1.05 |
| spending + | 66 | −0.04 | +0.11 | −0.30 |
| spending − | 13 | **+2.43** (+1.12 .. +3.79) | +0.05 | −1.57 |
| green + | 81 | +0.49 | +0.06 | +0.14 |
| green − | 43 | +0.29 | +0.04 | −0.63 |

Market-minded Cabinets see unemployment rise about 2 points a year; state-minded ones hold it flat. Part of this
is the engine, not ideology: **the economy has no working channel through which market policy creates jobs.**
Bob's v7 diagnosis: the number of private firms stays at 16–25 all century while the workforce triples, so tax
cuts and deregulation do not bring new firms, while public jobs and public works directly hire. Until firm
founding grows with the workforce (Bob, next), market governments are handicapped. (Real income could not be
compared: the indicator was not recorded per Cabinet in these runs — to fix in the tool.)

## 3. Money and press

Donations per point of vote share (credits, normal runs):

| axis | + side | − side |
|---|---|---|
| state role | 0.9 M | 6.3 M |
| redistribution | 0.7 M | 11.2 M |
| labour | 0.6 M | 13.3 M |
| spending | 0.5 M | 9.9 M |
| independence | 2.2 M | 0.1 M |

Companies give the market side 7–20 times more per voter. That is intended realism (companies fund pro-business
parties, unions the labour side), and it partly offsets section 1 — but money buys campaign spending, not votes
directly, so it does not cancel the drift. Press closeness differs by less than 3 points between sides on every
axis: **the press is about balanced.**

## 4. Hints — do laws do what they promise?

Evidence 1.00 = the colony's record a year later matched the hint.

| axis | changes leaning + | mean evidence | changes leaning − | mean evidence |
|---|---|---|---|---|
| state role | 5,067 | 0.73 | 3,432 | 0.69 |
| redistribution | 3,352 | 0.68 | 3,298 | 0.70 |
| labour | 1,362 | 0.73 | 1,071 | 0.62 |
| environment | 1,004 | 0.71 | 455 | 0.73 |
| spending | 3,134 | 0.73 | 2,981 | 0.68 |
| institutions | 371 | 0.60 | 370 | 0.59 |
| independence | 559 | 0.86 | 445 | 0.69 |

Broadly balanced. Both sides' laws deliver about 60–90% of the hint, so the hints overpromise across the board, and
30–54% of judgements show no measurable effect at all (the check is coarse). Pro-labour and pro-independence changes
do a little better against their hints than their opposites; worth Bob reviewing the labour hints, not urgent.

## Recommendations (the user decides what stays)

| # | Finding | Intended or accidental | Recommendation |
|---|---|---|---|
| 1 | One-sided radicalisation: centrists always drift toward state/labour/redistribution | **Accidental** | Make it symmetric. Option A: centrists drift **against the government's position** on that axis (blame the incumbent — a market government's failure pushes the middle left, a state government's failure pushes it right). Option B: each concern gets a pull for both sides (unemployment → state jobs or lower taxes, cost of living → redistribution or lower taxes), chosen by the voter group's own leaning. Recommend A (simple, realistic, symmetric). |
| 2 | Market governments cannot create jobs | Accidental (missing economics) | Bob: firm founding that grows with the workforce, and tax/regulation effects on entry. Re-run this audit afterwards. |
| 3 | Companies fund the market side 7–20× more per voter | Intended realism | Keep; the donation cap law and a public party-funding law (new) can be political choices. |
| 4 | Colonial burden pushes toward independence | Intended (M12) | Keep. |
| 5 | Hints overpromise ~30% on both sides; many zero judgements | Measurement | Make the evidence check finer (longer window, district level) before treating stubborn beliefs as findings. |
| 6 | Institutions: the order side slightly favoured | Small, unclear | Watch after #1. |

After #1 and #2 the audit should be re-run (same tools, ~1 hour on 24 cores) to confirm the mirror asymmetry falls
toward zero.
