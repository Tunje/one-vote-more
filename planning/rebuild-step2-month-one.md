# Rebuild step 2: month one with the real numbers

**Bob, 2026-11-17.** Plan section 13: "Month one has to add up, on paper, before step 3 is run." The paper
([rebuild-type-table.md](rebuild-type-table.md) section 9) was worked with stand-in numbers. This check takes the real
ones from a new game at commit 40fd694 (`GameSim.make(1)`, all step-2 pieces in), read at landing and after 1, 6, 12
and 24 months. Nothing was changed to get them. The probe is a scratch tool and was never handed over.

Step 2 has no market, no sales, no rent collected and no private wages yet. So the game shows what the colony LANDS
with and what the purse pays; everything a company or household would DO is step 3's.

## 1. What the colony lands with

| | Paper (type table 9) | Game |
|---|---|---|
| Settlers | 1,000 in 400 households (Maja's figure) | **1,000 in 400 households**, 80 per income band I1–I5 |
| Labour force | 675 | **675** (plus 75 adults outside it, 30 retired, 220 children) |
| Savings per household, I1 … I5 | 1,800 / 3,600 / 7,200 / 14,400 / 36,000 | **the same**; 5,040,000 in all |
| Employed at landing | 261 (my review of Wilma's piece) | **261**: 5 builders 180, public works 40, administration 15, housing office 16, Colony Stores 10 |
| Jobless at landing | 414 | **414** |
| Landing shelters | 400 homes at 48 | **8 blocks of 50 = 400 homes, rent 48**, placed on the town grid |
| Landing stock | FOOD 12,000; MATERIAL 9,700; COMPONENT 1,060; trucks (Wilma: 20) | **the same**, in Colony Stores, each offered at its starting price |
| Starting prices | FOOD 60.7, MATERIAL 37.1, COMPONENT 138.1, TRUCK 6,426, BW 392 | **the same** (the code works them out from the rows) |
| Treasury | 2,000,000 (Wilma) | **2,000,000** |
| Builders' capital | three months of wages (Wilma) | **68,850 / 45,900 / 45,900 / 22,950 / 22,950** |
| Households' check (jobs = people) | | **clean** every month read |

Every figure the paper assumed is what the game lands with.

## 2. The paper's four questions, with these numbers

1. **Can a settler found a family farm?** Yes, unchanged from the paper. The farm needs 23,440 with three months'
   opening money, or 19,186 without. With the 15,000 grant:
   - I4 and I5 reach it with opening money;
   - I3 (7,200 + 15,000 = 22,200) reaches it only without.
   - That gives **240 households who can found a farm** (I3–I5), against 41 needed.
2. **A truck driver?** Yes:
   - a landing truck costs 6,426;
   - with three months' running costs and the 10,000 grant, I2 and up can found one;
   - the 20 trucks in the stock are enough for 20 drivers before a ship is needed.
3. **Which types can be paid from savings and a grant alone?** As the paper's 9.3:
   - farms, truck drivers, truck workshops and family bakeries (with a grant);
   - the services, for I5 only;
   - no mine, processing works, components works or landlord before the bank.
4. **Does the landing food outlast the first harvest?** The food is 12,000, which is twelve months for 1,000 people.
   - The paper's step-3 case needs 41 family farm jobs at once, so 547 builder crew. The game has 180 crew and
     414 jobless, which makes 594, so the crews can be found.
   - The farms open in month 4 and harvest from month 8, with about 3,500 to spare (paper 9.5).
   - It holds.

## 3. What the game shows that the paper did not have

1. **The treasury runs dry at month 24.** It holds 2,000,000 and pays out 83,055 a month (wages 30,225, benefit 49,680,
   pension 3,150), as my estimate said.
   - At month 24 it is empty and pays short: wages 26,351 of 30,225.
   - Politics raised the benefit lever from 40% to 56% along the way, so the drain grows.
   - **Step 3's grants come out of the same treasury:**
     - 41 family farm grants are 615,000;
     - 20 truck driver grants are 200,000;
     - with both, the runway is about 14 months.
   - There are no taxes until step 8. That is a step-3 result to report, not a number to change (section 13).
2. **The builders' crews are paid nothing in step 2.** The purse pays only the state's staff. The five home-world
   builders' 180 crew are employed, so they get no benefit, and no one pays them. Their capital sits untouched (68,850
   for the large one at month 24).
   - Correct for step 2: a builder paying its own crew is step 3.
   - Until then, 180 people and their households live on savings.
3. **Nobody eats from the stock yet.** The 12,000 FOOD is untouched at month 24, because households buy nothing until
   step 3's market. Households' savings rise from 5.04 to 7.04 million: exactly what the treasury paid out. Money is
   conserved.
4. **Who got the month-one jobs is lopsided.** Hiring takes people pool by pool in id order, so:
   - I1 is fully employed (135 of 135) and I5 has nobody employed (0 of 135);
   - I2 has 38 employed, I3 54, I4 34.
   - It follows from the order, not from a rule, and the plan says nothing about it. It matters for step 3: the
     poorest pool earns wages and the richest lives on the benefit and its savings. **For Maja:** whether hiring should
     take the best-matched or nearest people first, or spread across pools, is hers to decide. Today it is the order
     of the pool ids.
5. **Six of the state's companies have no staff and no plant** (power, water, transit, clinic, school, police). Plan
   9.12: the colony lands with no finished buildings. Their buildings wait for the government's commissions, which
   come with the purse in full at step 8. Until then the colony has no power, water, clinic or school. Farms need
   neither power nor water (type table, note 1).

## 4. Verdict

Month one adds up. Everything the paper assumed is what the game lands with, and the four questions answer as on
paper:
- the founders exist;
- they can pay for farms and trucks;
- the crews can be found;
- the food lasts.

The three things to carry into step 3's report are results, not faults:
- the treasury's runway (about 24 months, 14 with the grants);
- builders paying their own crews from step 3;
- the hiring order across income bands.
