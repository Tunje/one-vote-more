# v11: what was switched on, and on which numbers (Wilma, 2026-11-16)

The user's decisions: family farms and bakeries are in v11; Ella's politics changes are in; the three farm crops are
out (after v11). The user's rulings applied to every game the same night: no credit limit, input budget or reserve
built on past sales (credit follows expected sales; public enterprises borrow like any firm; fd55c09, a30bcc3), fines
and union demands read the year (0720aa2, 7b2feec), a stuck public project is re-tendered once a year (fd5f422).

## Before the credit fix (Bob, g17 = c2aafeb + R8_FOOD + e408d0e)
10 seeds x 30 years; seeds 1-3 x 60 years in brackets.

| Arm | Adults | Unemployment % | Food shortfall permille | Real wage |
|---|---|---|---|---|
| base14 | 4735 (7620) | 17.8 (19.6) | 21.1 (47.7) | 2.96 (3.09) |
| food | 4959 (8606) | 17.5 (24.8) | 12.4 (16.7) | 3.17 (2.79) |
| food + plan stage | 4936 (9046) | 16.2 (23.3) | 8.4 (9.7) | 3.14 (2.90) |
| food + politics | 4931 (9133) | 17.7 (22.2) | 19.7 (9.7) | 3.14 (2.98) |
| food + plan + politics | 5066 (8007) | 16.4 (28.0) | 9.6 (18.7) | 3.29 (2.69) |

food = E160, E162, R8, R8_FREIGHT, R8_MATERIAL, R8_FOOD. plan = E165, E165B. politics = TREND2, RULE_COST3, RIVALRY.
With R8_BUILDERS added the colony collapses over 60 years (3932 adults, 206 permille): out.

## After the credit fix (Wilma, scratch copy of HEAD a30bcc3), 10 seeds x 30 years
| Arm | Adults | Unemployment % | Food shortfall permille | Real wage | Adults by seed | Food by seed |
|---|---|---|---|---|---|---|
| base15 | 4487 | 20.9 | 19.7 | 2.52 | 4012, 5044, 4928, 4808, 4324, 4655, 4686, 4370, 4463, 3581 | 41, 4, 11, 12, 36, 10, 8, 18, 44, 13 |
| food | 4840 | 16.9 | 8.3 | 3.21 | 5184, 4791, 4867, 4636, 4988, 5112, 5001, 4515, 4533, 4774 | 6, 15, 7, 4, 6, 7, 4, 11, 11, 12 |
| food + plan stage | 4620 | 19.4 | 47.3 | 2.81 | 2146, 4306, 4825, 4978, 4308, 5260, 5296, 4843, 4819, 5419 | 347, 31, 17, 5, 7, 9, 4, 21, 19, 13 |
| **food + politics (v11)** | 4875 | 18.3 | 13.9 | 3.01 | 5180, 4802, 5058, 5104, 4921, 3979, 5027, 4623, 5300, 4754 | 5, 14, 4, 11, 9, 38, 23, 11, 8, 16 |
| food + plan + politics | 4832 | 18.6 | 22.7 | 2.91 | 3870, 4481, 4957, 4949, 5149, 5275, 4985, 4789, 5026, 4837 | 64, 74, 16, 8, 7, 13, 11, 6, 14, 14 |

## Reading
1. The credit fix lowers the baseline at 30 years: adults 4735 -> 4487, unemployment 17.8 -> 20.9 %, real wage
   2.96 -> 2.52. Not explained yet. It is the user's ruling and stays; Bob takes it apart after v11.
2. With the credit fix the plan stage turns from a gain into a loss (seed 1 collapses), so it is out of v11. Before
   the fix it was ahead at both horizons.
3. food is the steadiest arm (every seed between 4515 and 5184 adults, hunger 4-15 permille). The politics flags cost
   some of that (13.9 against 8.3 permille, seed 6 at 3979 adults), but the user decided they go in.
4. v11 against base15: +388 adults, unemployment -2.6 points, hunger 13.9 against 19.7, real wage +0.49.
5. No 60-year run exists on the code with the credit fix. The three century chronicles are the first.

## v11 defaults (f411544)
E160, E162, R8, R8_FREIGHT, R8_MATERIAL, R8_FOOD, TREND2, RULE_COST3, RIVALRY, on top of v10's list.

## The credit pass taken apart (Bob, 2026-11-16, scratch g19 = f411544 + off switches; game code = HEAD)
10 seeds x 30 years, v10 switches on the v11 code. Bank <=0 = seeds with bank capital zero or below at year 30.

| Arm | Adults | Unemployment % | Food short permille | Real wage | Bank <=0 |
|---|---|---|---|---|---|
| base15 | 4487 | 20.9 | 19.7 | 2.52 | 6/10 |
| expected-sales basis off | 4734 | 17.4 | 17.5 | 3.07 | 1/10 |
| profit test restored | 4764 | 19.1 | 21.8 | 2.80 | 7/10 |
| reserves off | 4347 | 21.2 | 18.3 | 2.69 | 7/10 |
| public enterprises off | 4636 | 20.0 | 18.9 | 2.75 | 6/10 |
| supplier credit off | 4459 | 19.9 | 17.1 | 2.72 | 5/10 |
| all five off | 4626 | 18.7 | 19.7 | 2.98 | 4/10 |

Noise about +-130 adults on the mean. The expected-sales basis carries the whole loss, through the bank.
Seed 1 with the plan stage: builders hold 15-20M of loans by years 7-9 (bank capital 16M), builders' lost loans 23M,
the bank fails in year 13 and stays failed.

60 years, seeds 1-3 (bank capital at year 60 in millions, by seed):

| Arm | Adults | Unemployment % | Food short permille | Real wage | Bank capital Y60 | Adults by seed |
|---|---|---|---|---|---|---|
| base15 | 5939 | 26.5 | 73.3 | 2.42 | -2 / 0 / -5 | 4575 / 7490 / 5751 |
| food | 8478 | 28.0 | 23.7 | 2.58 | 0 / -2 / -1 | 9857 / 7641 / 7935 |
| food + politics (v11) | 8321 | 27.8 | 24.0 | 2.54 | 13 / 0 / -3 | 10370 / 6964 / 7628 |

Findings:
1. The bank is dead in 8 of 9 games at 60 years. No AI issues ECON_BANK_BAILOUT (player only). A failed bank recovers
   only if loans that still pay interest remain on its book (seed 2, v10 switches: government loans, capital 0 -> 5
   between years 25 and 40); otherwise it stays failed.
2. Unemployment jumps in the year the bank's room hits zero, in all four 60-year probes: builders stay alive (2-7) but
   their crews fall from about 300 to 30-70, public building stops, public posts (60-80 % of all jobs) stop growing.
   Private manufacturing and mining are gone by year 5 in every game; only family farms grow privately under v11.
3. Seed 2 under v11: the bank's room is 0 in year 20 and capital below 0 in year 25 (lost loans: private 10M,
   builders 5M), it never recovers; with the v10 switches it recovers by year 30 and unemployment stays 12-14 % to
   year 50. Public enterprises' lost loans are 0 in every game.
4. tools/ab_full.gd: a "-FLAG" arm did not reach meta "off" before b00d6e9; earlier "-FLAG" arms of switches read only
   through EconUtil.off were no-ops.
