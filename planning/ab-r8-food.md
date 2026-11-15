# A/B: R8 step 3, food, bread and family firms under the eight rules (Bob, 2026-11-15)

**Baseline:** "base13" is the working tree after the Road safety law commit (HEAD 2b8a440), with the DEFAULT_ON flags only.

## The deadlock (probe, seed 5)

The probe ran E160 + E162 on the tree at HEAD and traced every household order for FOOD.

| Year | Food price index / big farm's unit cost | Refused because every ask was over the limit (k / year) | Refused for cash | Mean bid limit | Mean cheapest ask | Family farms |
|---|---|---|---|---|---|---|
| 14 | 218 / 210 | 0 | 0 | 655 | 202 | 97 |
| 16 | 108 / 231 | 0 | 1.4k | 333 | 196 | 107 |
| 18 | 80 / 232 | 5.2k | 3.3k | 240 | 201 | 107 |
| 20 | 75 / 234 | 18.9k | 2.1k | 225 | 198 | 107 |
| 21 | 72 / 232 | 22.4k | 1.4k | 218 | 193 | 107 |

How it locks up:
- **Sellers:** asks stay near 200, because the floor in firm_ai is 0.9 × a company farm's full cost, and family farms use that same floor.
- **The index:** the price index falls on stock cover (E45 / E149).
- **Households:** they bid 3 × the index.
- **Result:** by year 21 a third of household food orders are refused while food sits on offer. Freight refuses nothing.
- **Output:** 107 family farms keep running at full output (T = 1.0).

## R8_FOOD (opt-in, R8 + R8_FOOD)

1. **Households bid what food is worth to them.** The limit for essential FOOD is their cash per unit ordered, after shop margin, tax and freight allowance. It never goes under the old 3 × price or over the price ceiling. Kill switch: R8F_NOHH.
2. **Family ask floor.** A family firm's floor is EconFamily.family_unit_cost, with its own grant share, not a company's cost. Kill switch: R8F_NOFAMASK.
3. **Family output (rules 3/4).** A family plant follows its sales (FirmAI._producer_target) instead of T = 1.0. Kill switch: R8F_NOFAMOUT.
4. **Family entry (rules 7/8).** A family founds only while orders exceed 1.05 × last month's food output and some order within its reach goes unfilled. food_glut stays as a backstop. Kill switch: R8F_NOENTRY.
5. **FARM and BAKERY take rules 3–6 from the materials code:**
   - output from reachable orders;
   - rule-5 capacity (this replaces _investment and _expansion for these types);
   - no mothballing while orders are unfilled.
   Kill switches: R8F_NOOUT, R8F_NOCAP.
6. **Unchanged:**
   - Company farm entry keeps the old price test, because the forecast doesn't know about farmland yet.
   - A farm's crop is still the single recipe field, so a switch to another crop can be added later.

Probe on seed 5, years 18–24, with E160 + E162 + R8 + R8_FREIGHT, without and with R8_FOOD:

| Arm | Food price ÷ cost | Refused over the limit | Refused for freight | Family farms (mean T) | Big farms | Stock (k) |
|---|---|---|---|---|---|---|
| without R8_FOOD | 0.33 | 5–18k a year | 0 | 107 (1.0) | 11 | 34–47 |
| with R8_FOOD | 1.2–1.4 | 0 | 0 | 24 (0.84–0.92) | 19–22 | 7–12 |

## 10 seeds × 30 years

Every arm except base13 runs E160 + E162 + R8 + R8_FREIGHT.

The materials rules in "fammat", "food" and "foodnocap" are the earlier r8v build: value bids with rules 3–8 and 6-in-a-row counters. They are not the r8vwin version that was ported. A confirmation run on r8vwin follows.

| Arm | Adults | Unemployment % | Food short ‰ | Real wage | Firms dead | Food price (avg Y5+) | Months food below cost | Big farms at Y30 | Family farms opened | Family share of food % |
|---|---|---|---|---|---|---|---|---|---|---|
| base13 | 4735 | 17.8 | 21.1 | 2.96 | 69.1 | 225 | 14 | 22.7 | - | - |
| fam (family firms + freight) | 4580 | 15.8 | 120.8 | 5.78 | 91.0 | 114 | 198 | 15.6 | 120 | 64 |
| fammat (+ materials) | 4676 | 17.2 | 52.9 | 5.32 | 129.8 | 123 | 184 | 16.2 | 166 | 59 |
| **food (+ R8_FOOD)** | **5116** | 16.0 | **9.5** | 3.37 | 81.5 | 212 | 107 | 18.9 | 58 | 29 |
| foodnocap (food without rules 5/6 for farms) | 4890 | 15.0 | 23.8 | 6.00 | 92.6 | 116 | 236 | 18.9 | 55 | 17 |

Per seed, adults / food short ‰:

| Arm | s1 | s2 | s3 | s4 | s5 | s6 | s7 | s8 | s9 | s10 |
|---|---|---|---|---|---|---|---|---|---|---|
| base13 | 4661 / 16 | 4902 / 8 | 4990 / 5 | 4738 / 13 | 4669 / 51 | 4425 / 28 | 4702 / 44 | 5107 / 13 | 4638 / 5 | 4515 / 28 |
| food | 5087 / 8 | 4823 / 6 | 5124 / 16 | 5144 / 10 | 5223 / 8 | 5116 / 7 | 5211 / 15 | 5173 / 11 | 5211 / 5 | 5046 / 9 |

## Reading

1. **R8_FOOD cures the deadlock.**
   - Compared with base13: +381 adults (+8%), less than half the hunger (9.5 ‰ against 21.1) and a higher real wage (3.37 against 2.96).
   - It beats base13 on adults in 9 of 10 seeds.
   - Compared with family firms as they are (fam): +536 adults and a twelfth of the hunger.
2. **Family firms stay, at a size the market carries.** About 58 open per game and 29% of the food, against 120 open per game and 64% of the food in fam.
3. **Farms' capacity rule (5/6) matters.**
   - Without it (foodnocap), the food price sinks back to about half of cost, with 236 months below cost and 2.5 × the hunger of the full arm.
   - With it, company farms expand where orders go unfilled, and the price stays near cost.
4. **The real wage in fam and foodnocap (5.8–6.0) is cheap food sold below cost, not prosperity.** The farms lose money the whole time: 198–236 months below cost, and more firms die.
5. **Firms dead:** 81.5 in food against 69.1 in base13. That is fewer than in any other family arm.

## Next

- Port onto the shared r8vwin materials code.
- Confirm with 10 × 30 (fammat and food on r8vwin) and seeds 1–3 × 60 years (base13, fammat, food).
