# A/B: R8 step 2b, materials (MINERAL, MATERIAL, COMPONENT) (Bob, 2026-11-15)

**Baseline:** "base12": the shared tree at f915804, with only the DEFAULT_ON flags.

## Arms (all opt-in)

- **r8m:** R8 + R8_MATERIAL as built, with all eight rules. Price rules 1/2 are on:
  - while orders go unfilled, the price climbs toward full cost and never falls;
  - in a glut it falls only while plants are idle, never below variable cost.
- **r8v:** R8 + R8_MATERIAL + R8M_VALUE + R8M_NOPX. Value bids replace price rules 1/2; rules 3–8 stay:
  - **Producers:** the input limit is the output's worth per unit of input (output at full load × its price, less wages, other inputs, utilities and upkeep), plus the freight allowance. The old 1.3 × price stays as a floor.
  - **Builders:** the bid comes from what their contracts are worth.
  - **Others:** institutions and households are unchanged.
- **valonly:** value bids alone. Every materials rule is off (R8M_NOPX, NOOUT, NOCAP, NOENTRY).

Rules 3–8 in short:
- **3/4, output:** plants produce for the orders they can reach.
- **5, capacity up:** if a plant was busy and had unfilled orders 6 months running, and its price is at least 1.1 × cost, it expands or builds once a quarter.
- **6, capacity down:** plants with unfilled orders are not mothballed.
- **7/8, entry:** a founder enters only on the first-year forecast, and not while incumbents lose money.

Tool: tools/ab_full.gd. 40 games, and the ledger closed in all of them.

## 10 seeds × 30 years

| Arm | Adults | Unemployment % | Food short ‰ | Real wage | Firms dead | Food price (avg Y5+) |
|---|---|---|---|---|---|---|
| base12 | 4739 | 17.2 | 18.0 | 3.11 | 68.6 | 213 |
| r8m (as built) | 4598 | 20.4 | 25.2 | 2.71 | 68.2 | 240 |
| r8v (value bids, rules 3–8) | 4757 | 17.9 | **15.8** | 3.00 | 71.0 | 191 |
| valonly (value bids alone) | **4812** | 17.5 | 22.0 | 3.07 | 70.5 | 209 |

Materials, averaged from year 5. "pc" is the price index ÷ the plant type's full unit cost (%); fill is ‰ of orders filled.

| Arm | MINERAL pc / fill | MATERIAL pc / fill | COMPONENT pc / fill | Capacity at Y30, mine / proc / comp (‰ plant) | Rule-5 steps |
|---|---|---|---|---|---|
| base12 | 32 / 968 | 108 / 834 | 123 / 868 | 3925 / 7150 / 10212 | 0 |
| r8m | 169 / 929 | 158 / 879 | 124 / 907 | 3625 / 4475 / 7743 | 7.6 |
| r8v | **92** / 899 | **98** / 864 | 108 / 873 | 3450 / 4750 / 8106 | 6.5 |
| valonly | 27 / 977 | 92 / 875 | 116 / 874 | 3300 / 6575 / 9624 | 0 |

Probe, seeds 1 and 4 at year 30. Each cell is price / unit cost, then fill over the last two years, then producers' stock (thousand units). No plant is mothballed in any arm.

| Arm | s1 MINERAL | s1 MATERIAL | s4 MINERAL | s4 MATERIAL |
|---|---|---|---|---|
| base12 | 55/98, 100%, 4.3 | 171/249, 92%, 6.3 | 33/151, 100%, 2.4 | 193/311, 74%, 4.4 |
| r8m | 213/153, 100%, 2.0 | 990/543, 77%, 2.3 | 194/161, 100%, 3.2 | 621/533, 96%, 1.4 |
| r8v | 30/105, 100%, 4.1 | 261/216, 85%, 2.7 | 131/106, 95%, 1.2 | 273/351, 99%, 4.0 |
| valonly | 57/126, 88%, 2.3 | 167/290, 97%, 5.0 | 37/117, 85%, 2.2 | 103/257, 96%, 6.7 |

## Seeds 1–3 × 60 years

All arms carry the forecast fix. No arm has R8_FREIGHT. "r8vwin" is r8v with rule 5 counting busy months and months with unfilled orders over 6 of the last 12 months (12-bit masks) rather than 6 in a row.

| Arm | Adults | Unemployment % | Food short ‰ | Real wage | Firms dead | Per seed (adults / food ‰) |
|---|---|---|---|---|---|---|
| base12 | 6512 | 18.7 | 55 | 3.01 | 142 | s1 5875 / 142, s2 7322 / 16, s3 6339 / 7 |
| r8v | 5953 | 24.1 | 89 | 2.80 | 132 | s1 7379 / 70, s2 **4228 / 189**, s3 6253 / 8 |
| valonly | **7449** | 27.1 | 39 | 2.78 | 124 | s1 7740 / 23, s2 7694 / 52, s3 6912 / 41 |
| r8vwin | 7220 | 19.1 | **27** | **3.54** | 139 | s1 8116 / 59, s2 6096 / 12, s3 7448 / 11 |

Rule-5 capacity steps over 60 years:
- r8v: 18, 1 and 9 by seed;
- r8vwin: 30, 12 and 14.

On r8v's seed 2, MATERIAL ran at 3.5 × cost with 65% of orders filled and only one capacity step in 60 years. Busy months and months with unfilled orders seldom ran 6 in a row, so rule 5 never fired. The 6-of-12 window fixes that.

## Verdict (2026-11-15)

**r8vwin** is the materials candidate for v11:
- **60 years:** +11% adults, half the hunger, +0.53 real wage, unemployment level.
- **valonly:** has the most adults but +8.4 points of unemployment.
- **Ported to the shared tree:** opt-in R8 + R8_MATERIAL, base unchanged. With the switch on you get value bids, rules 3–8 and the 6-of-12 window.
- **Kill switches:** R8M_NOVALUE (value bids), R8M_NOOUT (rules 3/4), R8M_NOCAP (rules 5/6), R8M_NOENTRY (rules 7/8).
- **Price rules 1/2** are kept only as an opt-in for further take-apart arms: R8M_PX.

## Reading

1. **Rules 1/2 as built lock prices high, as the user predicted.**
   - MATERIAL runs at 1.6–1.8 × cost, and the unit cost itself roughly doubles down the chain (543 against 249 on seed 1).
   - Fewer plants are built, and the colony loses 141 adults and 0.40 of real wage, with 7 ‰ more hunger.
   - They are dropped (Wilma, 2026-11-15).
2. **r8v brings prices to cost without a price rule.**
   - MINERAL averages 0.92 × cost and MATERIAL 0.98 ×, where base has MINERAL at a third of cost.
   - It has the least hunger (15.8 ‰ against 18.0) and as many adults as base.
   - The cost is +0.7 points of unemployment and −0.11 of real wage.
3. **Value bids alone do not lift MINERAL.**
   - Most mineral moves inside one owner (E97: CPW owns mines, smelters and works), as internal transfers at book cost. So the price index barely touches trade, and it sinks to its floor while orders still fill.
   - Output from reachable orders (rules 3/4) is what holds the index at cost in r8v.
4. **Adult differences of 0 to +73 among base, r8v and valonly are within 10-seed noise.** The clear results are that r8m loses and that r8v cuts hunger.
5. **The forecast behind entry rules 7/8 had a ×12 interest bug** (found by Otto, fixed at econ_forecast.gd:84). Founders in r8m and r8v saw loans as cheaper than they were. The 60-year runs carry the fix.
