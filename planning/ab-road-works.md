# A/B: the government's road works (ROAD_WORKS), 2026-11-15 (Wilma)

All arms: R8 + R8_FREIGHT + FREIGHT_ROADS, 10 seeds x 30 years, scratch copy of commit af1feda (before the
switched-off-laws fix, so compare the arms with each other, not with base12). Tool: tools/ab_full.gd.

| Arm | Adults | Unemployment % | Food shortfall permille | Real income |
|---|---|---|---|---|
| roads: the default fix (Terra's cheapest cure, by severity) | 4450 | 18.1 | 48.6 | 2.59 |
| works: all of ROAD_WORKS (choice of fix, budget need, ranking by held freight, district feelings) | 4296 | 18.8 | 66.8 | 2.47 |
| works without the ranking (severity order) | 4536 | 18.4 | 46.1 | 2.55 |
| works without the choice of fix | 4444 | 18.1 | 58.8 | 2.50 |
| works without the budget need | 4354 | 18.4 | 57.3 | 2.49 |
| works + repair first when a road's condition is under 400 | 4443 | 17.9 | 50.3 | 2.61 |

Food shortfall by seed (1..10):
- roads: 32, 23, 161, 47, 36, 17, 84, 10, 53, 23
- works: 29, 25, 84, 49, 38, 28, 151, 11, 127, 126
- no ranking: 29, 20, 34, 35, 33, 28, 18, 11, 127, 126
- no choice: 32, 39, 113, 65, 32, 20, 145, 10, 102, 30
- no budget need: 29, 28, 161, 48, 56, 21, 20, 11, 127, 72
- repair first: 30, 13, 33, 49, 38, 16, 64, 13, 112, 135

## Reading
1. The ranking by held freight is the harmful piece: without it ROAD_WORKS goes from 4296 adults / 66.8 to 4536 / 46.1.
   Terra's explanation: held freight is credited to every link on a jammed route, so "freight freed per cost" picks the
   cheapest item on the route, often not the bottleneck. She adds bottleneck_mu (credit only to the items at the
   route's maximum load); the ranking should use that.
2. Repair first on a badly worn road helps (66.8 -> 50.3): a repair restores capacity in 4 months, bigger works take
   7-8 and relieve nothing meanwhile.
3. The choice of fix and the budget need both help on average (taking either out is worse than the no-ranking arm), but
   seeds 9 and 10 are bad in every arm that chooses (127 and 126 against 53 and 23 with the default fix); not explained.
4. Without the ranking, ROAD_WORKS is about level with the default fix (4536 / 46.1 against 4450 / 48.6): within the
   noise of 10 seeds. No arm comes near freight without road limits (base12: 18.0).

## Next
Repair first into the code; rank by bottleneck_mu when it lands; trace seeds 9 and 10; rerun on HEAD against base12.
ROAD_WORKS stays off.
