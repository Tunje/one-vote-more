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
