# A/B: family farms and bakeries (E160 + E162), 2026-11-15 (Wilma)

10 seeds x 30 years, tools/ab_full.gd, scratch copies of HEAD; base12 is Bob's baseline on the same code.

| Arm | Adults | Unemployment % | Food shortfall permille | Food price avg (% of base) | Months food below cost (of 360) | Big farms at Y30 | Big farms' profit (12 m) | Family farms' share of food % | Freight deferred / full months |
|---|---|---|---|---|---|---|---|---|---|
| base12 (no family firms) | 4739 | 17.2 | 18.0 | 213 | 21 | 24.3 | 15,085 | - | 261 / 76 |
| family firms as they were (before f0284f1) | 4699 | 17.6 | 20.4 | 214 | 51 | 15.7 | 10,142 | 34 | 418 / 111 |
| + found_mark: hardship and unemployment lower the bar (f0284f1) | 4817 | 15.4 | 72.4 | 121 | 179 | 16.1 | 1,022 | 54 | 146 / 57 |
| + family_unit_cost: no wages, ungranted share of the building (e2ae6a0) | 4778 | 14.6 | 73.9 | 111 | 192 | 14.5 | 1,228 | 65 | 43 / 26 |
| + farm_site: sited where farmland is free (cf38d42) | 4782 | 14.5 | 98.4 | 116 | 187 | 15.2 | - | 65 | 76 / 27 |
| + food_glut: no grant and no founding with over 3 months' demand on offer (d370c67) | 4662 | 15.8 | 101.3 | 120 | 195 | 16.2 | - | 64 | 71 / 25 |

Family farms opened per game: 13-101 as they were; 51-112 with found_mark; 94-209 with family_unit_cost.

## Year-by-year probe, seed 5 (planning/data/probe_food_seed5_*.txt; monthly averages per year)
With the fixes (family_unit_cost arm):

| Year | Food price / big farm's unit cost | Big farms | Family farms | Offered | Wanted | Filled | Shortfall permille | Stock |
|---|---|---|---|---|---|---|---|---|
| 12 | 211 / 189 | 11 | 63 | 6,757 | 4,138 | 4,138 | 2 | 7,595 |
| 15 | 68 / 203 | 12 | 92 | 28,850 | 4,775 | 4,145 | 107 | 29,858 |
| 18 | 75 / 220 | 11 | 111 | 55,992 | 5,133 | 4,007 | 203 | 57,060 |
| 21 | 71 / 210 | 12 | 114 | 66,753 | 5,378 | 4,162 | 209 | 67,756 |

A year's worth of food sits in stock and is on offer while a fifth of the households' orders go unfilled, at a
market price a third of cost. Freight is not the limit (deferred 43 a month).

## Reading
1. The fixes do what was asked on take-up: twice the family farms, unemployment down 2.6 to 2.8 points.
2. The hunger is not a lack of food. From year 13-15 the market is flooded, the price falls to a third of cost, and
   then food stops being sold although it is there. Most likely the same deadlock Bob found for MINERAL and MATERIAL:
   sellers ask no less than 0.9 x their full unit cost (firm_ai offers), households bid at most 3 x the market price
   (econ_households), and once the price has fallen far enough the cheapest ask is above the highest bid. Not yet
   proven by a trace of refused bids.
3. Nothing stops families founding while the market is flooded: the eighth rule (when not to start) is missing from
   found_mark.
4. The baseline shows a different late hunger on this seed (year 25-28: shortfall 52-139 at a price 1.6-3 x cost,
   stock two months): that one looks like the known freight jam.
5. Siting farms where the land is does not help while (2) holds (98.4).

## Next
The user: family firms are on in v11, and food comes under the eight rules like any good. Bob's step 3 (after
materials): buyers bid what food is worth to them, sellers decide what they accept, no price rule; families do not
found into a glut. Family firms stay opt-in until that is measured.

## Addendum: the glut rule (d370c67) comes too late
With food_glut at 3 x demand on offer, grants fall to under half (443 against about 1,000 a game) and fewer family
farms open (61-143 against 94-209), but the collapse still happens (shortfall 101.3, food below cost 195 months).
The seed-5 series shows why: in year 13 the family farms alone make 3,825 a month against 4,244 wanted, with the big
farms adding 1,206 at a target of 375 permille; offered / wanted is 2.2 and the price still 1.04 x cost. A year later it
is 3.7 and the price 0.73 x cost; the 3 x test only trips then. Family farms always work at full output (firm_ai: "a
family works its own farm fully"), so once there are enough of them production exceeds demand whatever the price, and
the big farms cannot cut further. Missing for family farms: the "produce less" rule, and a "when not to start" test on
production against demand rather than on the stock already piled up. Both belong to the food step.
