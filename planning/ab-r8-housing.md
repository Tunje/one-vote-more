# A/B: housing under the eight rules (R8 step 8, R8_HOUSING, Otto, 2026-11-15)

Code: game/sim/economy/econ_rules_housing.gd (EconRulesHousing), a 3-line hook in FirmAI._developers, tests in
game/tests/economy/test_r8_housing.gd (6 tests). Opt-in: R8 + R8_HOUSING. Without the switch E120 runs as before.

## The rule

A developer judges one more 50-home block in a district from what anyone can see this month:

- **Rent it would earn a month:** 50 × the district's private rent × the occupancy the district would have with the
  block, counting homes already being built and capped at 1 × (1 − the share of rent in arrears).
- **Costs a month:** crew wages + upkeep at today's material price + depreciation + interest on the 90% borrowed.
- **Rule 5 (build):** forecast profit is at least 10% a year of the developer's 10% equity.
- **Rule 8 (don't):** the district would be under 95% full with the block, or no builder could take the job, or rule 5
  fails, or the bank would not lend. The bank is asked first, so no developer is founded for a block it won't finance.
- **Rule 7 (new developer):** as in E120, a housing company is founded from the richest household's savings when no
  company has the equity.
- **Limit:** up to 3 blocks a quarter, the most profitable district first.

Rent rules 1 and 2 stay as they are (+3% a quarter at ≥ 97% full, −2% below 85%).

## Results: 10 seeds × 30 years, HEAD a563d55 plus the housing files

v11 = R8 + R8_BUILDERS + R8_FREIGHT + R8_MATERIAL + E165 + E165B. The R8 arm reproduces base13 exactly, because R8
alone switches on no sector.

| arm | adults | unemp % | food ‰ | real | private firms alive | homes Y30 | households Y30 | occupancy | worst district | rent Y30 | developers alive |
|---|---|---|---|---|---|---|---|---|---|---|---|
| R8 | 4735 | 17.8 | 21.1 | 2.96 | 11.5 | 2818 | 2902 | 104% | 121% | 1548 | 2 |
| R8 + housing | 4752 | 15.9 | 13.0 | 3.51 | 11.1 | 2958 | 2956 | 100% | 115% | 2174 | 1 |
| v11 | 4616 | 17.9 | 20.8 | 3.28 | 11.1 | 2716 | 2810 | 105% | 118% | 1711 | 5 |
| v11 + housing | 4625 | 19.8 | 31.0 | 3.19 | 8.8 | 2580 | 2786 | 109% | 138% | 1572 | 3 |

- Rent is unit-weighted, in credits a home a month.
- No arm had households in shacks or homeless at Y30.
- No developer died in any arm.

Per seed, v11 + housing:

| | s1 | s2 | s3 | s4 | s5 | s6 | s7 | s8 | s9 | s10 |
|---|---|---|---|---|---|---|---|---|---|---|
| adults | 4341 | 5076 | 4491 | 4700 | 4553 | 4664 | 4842 | 4458 | 4735 | 4387 |
| food ‰ | 21 | 3 | 22 | 4 | 31 | 63 | 23 | 99 | 29 | 15 |

v11 per seed for comparison:

| | s1 | s2 | s3 | s4 | s5 | s6 | s7 | s8 | s9 | s10 |
|---|---|---|---|---|---|---|---|---|---|---|
| adults | 4215 | 4905 | 4712 | 4532 | 4837 | 4549 | 5147 | 4223 | 4805 | 4234 |
| food ‰ | 39 | 13 | 29 | 17 | 14 | 8 | 26 | 49 | 10 | 3 |

Rule counters, v11 + housing, totals per seed over 30 years:

- Blocks built: 13–37.
- Refused for profit: 8–68.
- Refused because the bank had no room: 18–62, in 6 of 10 seeds.
- Developers founded: 0–4.

## Readings

- **On R8 alone, housing pays.** Developers build where rent covers a block. The colony ends with more homes (+140),
  the same households, occupancy 100% instead of 104%, and higher rents. Unemployment −1.9 points, food deaths −8‰,
  real income +0.55. Building that pays leaves landlords solvent and builders busy.
- **On v11, it does not.**
  - The bank's room is the binding limit: in 6 of 10 seeds most rounds that would build are refused because E165 plans
    already hold the bank's lending room.
  - The colony ends with fewer homes than under E120 (2580 against 2716), because E120 builds once a quarter whether or
    not it pays.
  - The crowded districts get worse (worst 138% against 118%).
  - Unemployment +1.9 points, food +10‰ (seeds 6 and 8 carry most of it), adults +9 (noise).
- **A bug found and fixed in this A/B.** The first v11 + housing run founded a developer before asking the bank. With
  the bank full, up to 64 empty housing companies per seed held households' savings. The bank is now asked first.
  Developers founded fell to 0–4 per seed; the other numbers barely moved (unemployment 19.9 → 19.8, food 30.6 → 31.0).
- **Recommendation:** R8_HOUSING is not a v11 candidate as it stands. It stays opt-in, and base is unchanged.
- **The open question:** who gets the bank's room when it is short — plans or housing blocks. That is a bank rule
  (Bob's side, R8 for the bank), not a housing rule.
