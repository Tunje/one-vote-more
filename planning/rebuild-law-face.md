# The law's hold on the one company object

**Anni, 2026-11-17. On paper; nothing is built.** It works out section 9.10 and decisions 52 to 55 and 62 to 72 of
[rebuild-company.md](rebuild-company.md) (version 13). For each law of mine that touches a company, a household, the
bank, a union or the government's purse, it says:
- what the law reads from the company record;
- what it does to the company record;
- which build step of section 13 it comes on with;
- what it does until then.

How to read it:
- Text in quote marks is the user's own words.
- "(12.x, n)" points to Wilma's numbered decisions in section 12 of the plan.
- **(Anni's decision)** marks a point the plan does not settle where the answer looked obvious. I decided it so the
  work can go on. The user or Wilma strikes any that is wrong.

The law's code (`game/sim/law`) is kept. Only its one connection to the old economy was cut: `law_bridge.gd`, the gate
the economy called before building or running a plant. Every number below that the law uses is set again with the
others. Levers keep their names (12.10, 63).

---

## 1. How the law meets a company

1. **The law reads; the company acts.** The law reads the company record, the market's sale records, the bank's loan
   records, the ledger, the household pools and the owners counted one by one (12.5, 35). It changes a company only
   through the named acts of section 9 below, which the company code carries out. It keeps no copy of a company's
   fields.
2. **The law's own records** (section 3 of the plan) are kept by the law and keyed by the company's id, a plant's
   id or an owner's person id:
   - licences and permit applications;
   - violations and fines owed (the `liability` table);
   - court cases, convictions, winding-up orders;
   - land titles and leases, and evictions;
   - takeover reviews.
3. **A lever whose effect is not built yet** stays on the legislature's table. Governments and the AI may set it; it
   does nothing until its step. The law screen marks it "not in force yet" **(Anni's decision)**. Nothing about it is
   switched off: the lever exists and is read the moment its step is built.
4. **No law forbids a company type from being private; it can only make it dearer** (12.10, 65). Section 8 lists the
   three levers of mine this changes.
5. **A legal ceiling or floor set by a government stops the rules at it** (12.10, 64). It is the government's doing,
   and allowed. The rules' signal stays standing: the unfilled orders at a capped price are still work that rule 7
   reads, so new companies can still be planned.
6. **Who answers for a company:** the company's account first. What it cannot pay goes to its owners by their share
   (12.8, 52 and 54a). An owner is a named person from the day the plan is made (12.9, 60a). That is who the court
   acts on. A state company is never taken to court (12.8, 54): the government pays from what it has, or closes it.

## 2. Licences, permits and the permit office (step 6; 12.10, 66)

**What it reads:**
- the type row's hazard column and whether the type extracts (a mine);
- the plant's cells or tile, their area and their zone (land law);
- the plan's or company's account, for the fee;
- the owner register, for "who applied".

**What it does:**
1. **A plan needs a building permit before it signs with a builder.** The permit office decides it in its queue. Its
   wait is part of the start date the plan sees, and its fee (`LAW_FEE_BUILDING_PERMIT`) comes from the plan's own
   account (12.9, 60).
2. **A hazardous plant needs an operating licence before it opens,** and so does a mine, under `LAW_LICENCE_REGIME_HAZARD`
   and `LAW_LICENCE_REGIME_EXTRACTION` (the government's choice). The application goes into the permit office's queue
   while the plant is being built, with its fee (`LAW_FEE_HAZARD` or `LAW_FEE_EXTRACTION`).
3. **The criteria** for a permit or licence are the zone (land law) and, for a mine, a deposit on its cells (the
   planet). The old stand-in "extraction only in district d:3" goes **(Anni's decision)**.
4. **The office's speed:**
   - Its decisions per month follow its staff and its budget (`LAW_PERMIT_OFFICE_BUDGET`, `STAFF_SD_PERMITS`).
   - A badly run office makes mistakes, both wrong grants and wrong refusals. They are published.
   - A long queue holds plans back. It is a result, not a fault.
5. **Refusal.** A refused plan may apply again elsewhere, or be given up (12.9, 60b): what it paid for is settled, not
   erased.
6. **Going ahead without a licence** is the company's choice when its gain is worth more than the fine it risks
   (12.10, 66). "The fine it risks" is:
   - the chance of being found, which comes from the inspectors (`LAW_INSPECTORS`, their budget and their staff);
   - × the fine;
   - plus the chance of losing the licence.

   The old fixed test (a chief's risk ≥ 70, or ≥ 45 with 4 inspectors or fewer) goes. The chief's appetite for risk
   (12.11, 77) bends how the chance is read **(Anni's decision)**.
7. **A licence ends** when it runs out unrenewed, when it is suspended after a severe conviction, or when it is revoked.
   The company's plant is then closed by law (act 9.1). It reopens when a licence is granted again.
   - **Renewal** is filed by the company three months before expiry, and the licence stays valid while it is decided.
   - **The length of a licence** is a lever (`LAW_LICENCE_TERM`, months, set new) instead of our fixed 60 and 120
     months **(Anni's decision)**.
8. **Month one:**
   - The five home-world builders and the government's subsidiaries hold the licences their types need from landing,
     free.
   - The landing shelters need no permit.

   **(Anni's decision)**
9. **Unsafe plants (12.11, 80).** A hazardous plant whose condition falls below the safety standard's line is closed
   under the law and keeps its repair crew. The line rises from `BASIC` to `STRICT` (`LAW_SAFETY_STANDARD`); the
   numbers are set in testing. It reopens when it is put right.

**Until step 6:** every plan and plant is lawful as it stands, with no permit, licence or fee. The permit office has an
empty queue, and the old `law_bridge` gate is not rebuilt before then.

## 3. Violations and fines (detection with each violated thing; collection at step 5)

**What it reads:**
- the company's books (`money`): revenue over its last twelve months, or the months it has, as a year;
- the reference wage (12.11, 108);
- the law's record of earlier convictions.

**Where violations come from**, each from the step that builds the thing broken:

| Violation | Comes from | Step |
|---|---|---|
| Running unlicensed | section 2 | 6 |
| Unsafe plant kept running | section 2, point 9 | 6 |
| Cutting corners: deferred upkeep, running short-staffed (12.11, 84) | the company's own choice, as in section 2 point 6 | 6 |
| Selling over a legal ceiling | section 6 | 8 |
| Hours over the legal maximum; understaffing under binding ratios; hiring under the minimum wage; a yearly raise under the minimum | section 5 | 8 and 9 |
| Dumping waste; breaking the sewage standard | waste law (`LAW_WASTE_STANDARD`, `LAW_SEWAGE_STANDARD`) | 9 (pollution) |
| A donation over the cap or undisclosed | party finance (`LAW_DONATION_CAP`, `LAW_DONATION_DISCLOSURE`) | 9 |
| An unlawful strike or lockout | section 7 | 9 |

**What it does:**
- **Finding a violation** is the inspectors' work. The chance follows their number, budget and staff. A whistleblower,
  a leak or the press can also find it (as now).
- **A fine** is a share of the company's yearly revenue, with a least amount in reference wages, times `LAW_FINE_SCALE`
  (the government's).
  - It is paid from the company's account to the purse's fines line.
  - What it cannot pay becomes a fine owed (`liability`), which goes to court like a loan (12.8, 55): first the
    company, then its owners by their share.
  - A fine owed and unpaid for twelve months makes the purse petition the court, which winds the company up (section 4).
  - The fine's own upper bounds (a share of revenue for one fine and for all open fines) are the law's
    proportionality. They stay, with numbers set new **(Anni's decision)**.
- **A severe conviction** suspends the company's licences for a time.
- **Collection** (Wilma, 2026-11-17: "a debt nobody collects is a fault, not a design"; Anni's `Justice.collect_debts`).
  Each month in JUSTICE, after SETTLEMENT's wages (this month's staff before old debts), every open debt of every kind
  that is due and whose debtor has an account is paid, oldest first, from the debtor's account to the creditor's as
  the balance allows. A part payment lowers what is owed; paid in full, the debt is closed. Each payment is a Logbook
  row and a ledger memo `DEBT:<kind>`. A fine goes to the fines account, another debt to the government to the
  treasury, any other to its creditor's account. A debt whose debtor or creditor has no account waits.

**Until step 5:** nothing can break a rule, because the things the rules cover do not exist yet, so there is nothing to
fine. Any fine raised before the court exists is recorded as owed and waits.

## 4. The court after an ending, and winding up (step 5; 8.3, 12.8)

**What it reads:**
- the bank's loan records;
- the company's account and books;
- what selling the stock brought in (12.8, 53a);
- the owner register and each owner's own account;
- the other companies an owner holds;
- what each owner took out in the company's last year.

**What it does after an ending** ("if not the owner is taking to court, where the bank can either settle for a smaller
amount or demand payment over time, if he is rich or owns other companies a settlent might be reached"):
1. **Creditors are paid in this order** from what the company has **(Anni's decision)**:
   - staff wages owed;
   - the bank, from the stock it takes (12.8, 53a);
   - the purse (taxes and fines);
   - everyone else owed (builders, suppliers, landlords);
   - within one rank, in proportion to what each is owed.
2. **What is still owed goes to court against the owners,** each by their share (12.8, 54a). A case is filed for each
   creditor that is still owed.
3. **The court takes back** what an owner took out in the company's last year (12.8, 52), and puts it into the same
   order.
4. **The creditor chooses** between settling for less and payment over time; the user gave that choice to the bank.
   The court gives each creditor the same choice **(Anni's decision)**.
   - **Settlement:** the court sets what the owner can pay now. That is everything they hold beyond six months of their
     own living costs, plus what their other companies can pay out to them. The creditor may accept it.
   - **Payment over time:** the court orders a monthly share of the owner's income, until the debt is paid or the
     owner dies. A share is lost if the owner leaves the colony.
5. **The court is slow when it is short of judges** (`LAW_JUDGES` and the court budget). A slow court is a result, not
   a fault.

**Other debts that go to court the same way** (12.8, 55):
- an unpaid tax or fine;
- an apartment owner's unpaid upkeep fee;
- a grant owed back by a plan that was given up (12.9, 60b);
- a building contract the client stopped paying (12.9, 56);
- a claim for an accident at work (section 5).

**Winding up for convictions** (12.10, 68):
- The `LAW_REVOKE_AFTER_CONVICTIONS`-th conviction of a company within the window revokes its licences, and the court
  winds it up.
- A fine owed and unpaid for twelve months winds it up too (section 3).
- Winding up is an ending:
  - the staff are laid off;
  - the stock is sold to the bank and the rest in market order;
  - the plants are offered to any buyer (12.11, 81): a company, the workers as a co-op, or the government;
  - the debts go through the order above.
- A state company is not wound up. Its conviction is a fine paid by the purse, and the minister answers for it on the
  decision desk **(Anni's decision)**.

**Until step 5:** no company can end, so the court hears none of these cases. The court's other work goes on as now:
crime, defamation, the government's unlawful acts, appeals.

## 5. Work law (stress, hours and staffing ratios at step 9; accidents at step 5; minimum wage and yearly raise at step 8)

**What it reads:**
- the company's `staff`: people by tier and plant, their hours and their stress;
- the type row's occupation column (section 4 of the plan) and client intake;
- the work slots taken;
- each plant's accident risk, condition and hazard.

**What it does:**
1. **Hours (`LAW_MAX_WORKING_HOURS`):**
   - A plant works a normal week.
   - It may run overtime when it has open posts and unfilled orders, up to the legal maximum, paid at the overtime
     rate.
   - Over the maximum is a violation (section 3).
   - Hours feed stress (section 7 of the plan).

   **(Anni's decision:** overtime is how "hours" enters a company; the plan names hours as a cause of stress but gives
   no one who sets them.)
2. **Staffing ratios (`LAW_STAFFING_RATIOS`):** clients served per worker of the occupation, for health, care,
   childcare and police.
   - Under `GUIDANCE` the shortfall is published.
   - Under `BINDING`, a private company short of the ratio commits a violation. A state service short of it is the
     government breaking its own law, as now.
   - The ratio figures become levers set by the government, instead of our fixed ones **(Anni's decision)**.
3. **Accidents at work (12.10, 69)** are the company's to pay for. The risk is the type row's accident risk, scaled by
   wear, stress and `LAW_SAFETY_STANDARD`.
   - A death or injury is a claim the victim's household holds against the company, in reference wages.
   - Unpaid, it goes to court (section 4).
   - A stress accident (workload over the line) is the company's fault outright.
4. **Minimum wage (`ECON_MIN_WAGE`, a share of the reference wage)**, where a government sets one, is a legal floor on
   the HIRING salary (12.10, 64): the price rules that move the hiring salary stop at it. A post offered below it is a
   violation.
5. **The yearly raise** (the user, 2026-11-17: "No no, the sallery is not fluent, they have a sallery set on hire then
   it climbs based on yearly upps set by goverment"; plan 9.2). A worker's salary is set on hire and climbs once a year.
   The government sets the raise's minimum (the lever starts at 2%). Giving it is a yearly duty, not the company's
   choice; a company may give more. Work law reads each company's staff once a year: a worker whose salary did not
   climb by at least the minimum is a violation, found by the work inspectors like any other (section 3).
6. **Pay owed after a layoff** (the user, 2026-11-17, rebuild-company.md 9.2, ruled on Wilma's proposal: "On the
   workers rules i belive you have the right of it, and it should apply to builders"). A laid-off worker is owed
   `LAW_LAYOFF_PAY_MONTHS` months of their own pay by the company (default 3, range 0–12; a law the government can
   change). It applies to builders as to every company.
   - **The months are the law as it stands on the day of the layoff, for everyone** (Wilma's decision, 2026-11-17: the
     law is a minimum every contract carries, so raising it protects people already hired; nothing is stored on the
     job; she is telling the user and it can change).
   - Bob's layoff rule reads it through `WorkLaw.layoff_pay_months`; Maja's `Households.layoff` pays it from the
     company's account to the pool the worker went back to.
   - What the company cannot pay is a debt, `Justice.owe(company, pool, pool's account, rest, "LAYOFF_PAY")`, collected
     like every other debt (section 3, collection). Unpaid 12 months past due, the pool petitions the court to wind the
     company up, as for a fine ("a debt like unpaid wages, and can end the company").

**Until then:**
- **Accidents** may happen from production at step 3. They are published and counted, but nobody pays for them until
  the court exists at step 5.
- **Hours, ratios and stress** have no effect until step 9.
- **The minimum wage and the yearly raise's minimum** have no effect until step 8. Until then the hiring salary moves
  by the three price rules alone, and a worker's salary stays where it was set on hire.

## 6. Competition and buy-outs (step 6; 12.10, 67)

**What it reads:**
- the buyer's and the target's sales by type and area, from the market's sale records;
- the land, building and stock values of the target;
- the owner register.

**What it does:**
1. **A buy-out** (growing in a shared square, or buying a company outright) is filed with the competition authority
   when `LAW_COMPETITION` includes merger review. The authority measures the buyer's share of what was sold of that type
   in the area after the deal.
   - Under `LAW_MERGER_THRESHOLD`: approved without review.
   - Otherwise the government decides on the decision desk: approve, approve with conditions, or block.
   - The authority's recommendation follows the two levers: block at or over `LAW_DOMINANCE_SHARE`, conditions between
     the threshold and that share. This replaces our fixed 70% and +15% **(Anni's decision)**.
2. **Conditions** are a price ceiling on the buyer for a set number of months (a legal ceiling, section 6 below) and/or
   selling one plant.
3. **The company being bought may refuse** an offer below what its land, building and stock are worth (12.10, 67).
4. **In a buy-out the debts go with the plant** (12.8, 53). Land changes hands through land law (section 7), together
   with the building.
5. **Cartels and exclusive dealing** stay in the law, but nothing in the rebuild produces them. Companies do not agree
   prices, and supply contracts are left out (12.12). They stay dormant until supply contracts come back.
6. **Lobbying and favours** (`LAW_LOBBY_REGISTER`, the favour scan) read company donations (step 9).

**Until step 6:** no buy-outs, so nothing to review.

## 7. Price and rent ceilings (step 8; rent ceilings at step 8 over the rents built at step 7)

**What it reads:** each company's price and making price (12.3, 14), the decree's date, and the price index per area
(12.10, 74).

**What each control is (Anni's decision where the lever does not say it):**

| Lever | What it does to a company |
|---|---|
| `LAW_PRICE_CONTROL` `ESSENTIALS` | The price of food, power, water and medical goods may not rise above what it was when the control came in. |
| `LAW_PRICE_GOUGING` `IN_EMERGENCY` / `ALWAYS` | A company selling above its making price may not raise its price (during a declared emergency, or always). Below its making price it may: rule 9's priority to rise is untouched. |
| `LAW_RENT_CONTROL` `CAP` | A landlord's own rent may rise by no more than the area's price index did over the last year. |
| `LAW_RENT_CONTROL` `FREEZE` | A landlord's own rent may not rise. |
| `LAW_FARE_CAP` | A transit fare may not exceed the cap's share of the route's cost. Under a public or franchised operation it binds every operator. |
| A state company's tariff or bracket | Its rules propose; the government approves (12.6, 46; 12.7, 49). |
| `LAW_RATIONING` | Each household's orders of food (and fuel) are limited to its need per person. |
| `LAW_FOOD_EXPORT_BAN` | Food is refused at the port. |
| `LAW_REQUISITION` | In an emergency the government may take a company's stock of an essential at its making price. |

**What it does:**
- **The price rules stop at the ceiling** (section 1, point 5). Selling above it is a violation (section 3).
- **The cost of a ceiling** falls on the company: a capped seller below its making price loses money. The user ruled
  that failing is a result, not a fault (section 1 of the plan).

**Until step 8:** no ceiling acts, and prices move by the rules alone.

## 8. Land: sale, lease, zoning, expropriation (title and price at step 3; leases and arrears at step 5; expropriation at step 6)

**What it reads:**
- the plan's chosen cells or tile (siting);
- each cell's value (Terra's town grid, 9.8 of the plan), which is land law's `land_value_fn`;
- the zone;
- `LAW_LAND_DISPOSAL` and `LAW_LAND_PRICE_FLOOR_PCT`.

**What it does:**
1. **All land is the colony's at landing,** that is, the government's (12.1, 3).
2. **A plan buys or leases its land** from its owner before it signs.
   - Buying is at the land's value × `LAW_LAND_PRICE_FLOOR_PCT` for every buyer. The old fixed 90% for companies goes
     **(Anni's decision)**.
   - A lease's rent is the land's value × the bank's interest rate (12.8, 50), instead of our fixed 0.6% a month
     **(Anni's decision)**.
3. **A buy-out moves land and building together** (12.1, 3). Title passes in the law's register.
4. **`LAW_LAND_DISPOSAL`:**
   - `SELL` and `LEASE` stay.
   - `KEEP` (the state neither sells nor leases) would let no private company build anywhere. That forbids every type
     from being private, against 12.10, 65. `KEEP` therefore becomes lease-only, at double the lease rent: dearer, not
     forbidden **(Anni's decision)**.
5. **Zoning** (`UNZONED`, `RESIDENTIAL`, `INDUSTRIAL`, `FARM`, `RESERVE`) is the government's. Unzoned land allows every
   use. A zone that does not allow a type is not a ban on the type: the type may build in another zone.
6. **Lease arrears:** a lessee behind on rent for `LAW_EVICTION_NOTICE_MONTHS` loses the lease. The old fixed 3 months
   goes **(Anni's decision)**. Land with people on it then goes to an eviction (section 9).
7. **Expropriation** for public works, at the land's value, with rehousing or a court order for anyone living on it
   (as now).

**Until then:**
- Before step 3 no plan exists.
- At step 3 the first plans need a land price. The plan's build order lists "land sales" at step 6, but 12.1, 3 needs
  them in the first loop, so title and price come at step 3. Leases and arrears come at step 5, with money and the
  court. **Wilma: the build order should say so.**

## 9. Eviction and other non-payment by households (step 5; 12.8, 55)

**What it reads:**
- the household pools' debts (unpaid rent is a debt to the landlord, 9.1 of the plan);
- the landlord company's tenants (its work slots);
- the block and the home.

**What it does:**
1. **Unpaid rent.** After `LAW_EVICTION_NOTICE_MONTHS` of arrears the landlord may file an eviction. The order comes
   after the notice.
   - The evicted households leave the home: to a cheaper home with a free place, or to a shack, or they become homeless
     (9.1 of the plan).
   - The debt stays and goes to court like any other.
   - Pools are counts, so an eviction moves a number of households out of a block, not named people.
2. **Unpaid power and water bills** are a debt to the utility.
   - After the same notice the supply to those homes is cut, and is restored when the debt is paid.
   - Water and power were already last in a household's order of paying (9.1 of the plan).

   **(Anni's decision:** the plan's order of paying implies bills go unpaid, but says nothing of what follows.)
3. **An apartment owner's unpaid upkeep fee** goes to court (section 4). The court may order the apartment sold to pay
   it.

**Until step 5:** debts are recorded and wait. Nobody is evicted and no supply is cut.

## 10. Strike law (step 9; 12.10, 71; 12.11, 89)

**What it reads:**
- the union's record: members per company, fund, the dispute;
- the company's `staff`, its owner (a state company counts as public sector) and its type's occupation.

**What it does:**
1. **A shutdown is lawful** only when it passes all of these:
   - the ballot (`LAW_STRIKE_BALLOT`, yes-share of members);
   - the public-sector rule (`LAW_PUBLIC_SECTOR_STRIKE`): where public servants may not strike, the dispute goes to
     arbitration (12.11, 89);
   - the essential-services rule (`LAW_ESSENTIAL_SERVICES`).
2. **Essential services** are power, water and clinics.
   - Under `MIN_SERVICE` a shutdown there keeps half the crew at work.
   - Under `NO_STRIKE` it goes to arbitration.

   **(Anni's decision** on which types and on the half)
3. **An unlawful shutdown:** the company may sue the union for its losses, times `LAW_STRIKE_LIABILITY`. The union pays
   from its fund. What it cannot pay goes to court like any debt.
4. **A lockout** is lawful only in a dispute the union started, and only after the union has been told. Otherwise it is
   a violation **(Anni's decision)**.
5. **Union rights:**
   - `LAW_CLOSED_SHOP`;
   - `LAW_UNION_RECOGNITION` (the membership share at which a company must bargain);
   - `LAW_POLITICAL_LEVY` (what share of the fee may go to politics, within 12.10, 71's rule that only what is beyond
     one month of shutdown pay may be spent).

**Until step 9:** there are no unions, so nothing to judge.

## 11. Taxes and charges the law sets (step 8; export ones at step 10)

**What it reads:**
- the market's sale records (12.8, 50b);
- the port's records;
- what a plant takes from the ground (mineral) or puts in a landfill.

**What it does:** each charge is taken at the sale or event, from the payer's account, to its line in the purse.
Unpaid, it is owed and goes to court (section 4).

| Charge | On | Paid by |
|---|---|---|
| `LAW_EXTRACTION_ROYALTY` | each unit of mineral taken | the mine |
| `LAW_FEE_BUILDING_PERMIT`, `LAW_FEE_EXTRACTION`, `LAW_FEE_HAZARD` | each application (step 6) | the applicant |
| `LAW_LUXURY_TAX` | luxury sales to households | the seller, in its price |
| `LAW_TOURIST_TAX` | tourists' spending | the seller |
| `LAW_LANDFILL_TAX` | each tonne landfilled | the company that dumps it |
| `LAW_SANITATION_FEE` | each household | the household |
| `LAW_ROAD_TOLL` | each trip on a paved road | the carrier |
| `LAW_EXPORT_TAX` | export revenue, not on reserved goods (step 10) | the exporter |
| `LAW_CHARTER_EXPORT_LEVY` | export revenue, to the home world (step 10) | the exporter |
| `LAW_REMITTANCE_TAX` | a home-world-owned bank's remittance (12.11, 91; step 10) | the bank |

Income, profit and sales taxes are the purse's (12.10, 62), not the law's. They follow the same collection rule.

**The charter quota** (12.11, 107) is the law's too, at step 10:
- The colony owes the home world set amounts of the reserved goods (component, material, mineral) at the charter's
  price, collected by ship.
- Reserved goods may not be exported otherwise.
- An evasion found is a sanction by the home world, as now (`charter_ops`).

**Until step 8 (10):** no charge is taken.

## 12. The law's other ties to companies

- **Police stations and prisons** are state service companies (step 4).
  - A police station's clients are the people of its area; a prison's are prisoners in places (section 10 of the plan).
  - Crime reads the households (population, the employed, income) from step 3, and hunger from need (12.3, 23).
  - Until step 4 the police's strength comes from the lever as now, and the court sends no one to prison: there are no
    places.
- **The law's own staff** are hired and paid by the salary rules with the government as employer (12.10, 70) from step
  3: judges, inspectors, the permit office, the competition authority. Until then their numbers come from the levers
  as now.
- **Newspapers** are companies whose clients are their readers (12.6, 48), from step 4.
  - `LAW_PRESS_LICENSING` `LICENCE` becomes a licence with a fee, never refused for being a newspaper (12.10, 65)
    **(Anni's decision)**.
  - `LAW_MEDIA_OWNERSHIP_CAP` limits how many papers one owner holds; it does not forbid the type.
  - Defamation damages come from the paper's account; what it cannot pay goes to court.
- **Transit:** `LAW_TRANSPORT_OPERATION` `PUBLIC` no longer bars private routes (12.10, 65). Under `PUBLIC` a private
  operator pays a route licence and the fare cap binds it, as under `FRANCHISE` **(Anni's decision)**. Tour operator
  licences (`LAW_TOUR_LICENSING`) are licences with odds, as now.
- **Private roads and tolls** are left out (12.12). `road_law` stays and is dormant: no private link exists.
- **Donations** (12.10, 72):
  - A company gives from its profit, under `LAW_DONATION_CAP` and `LAW_DONATION_DISCLOSURE`.
  - A gift tied to a favour granted is corruption, as now (`competition_law` favour scan).
  - Step 9.
- **The victims' fund** is the law's and pays households, as now.

## 13. What the law needs from the company code (doorway entries)

These are the reads and acts the law will call. Until each is built, the doorway (`game/sim/core/econ_face.gd`) gives
its plain answer.

**Reads:**
- a company's revenue over twelve months and its months of record;
- its owners and their shares;
- its plants (cells, area, type, condition, closed or not);
- its staff by occupation, with hours and stress;
- its clients served;
- its price and making price;
- its sales by type and area;
- an owner's account, other companies, and what they took out in the last year;
- a household block's debts;
- a landlord's tenants.

**Acts:**
- **close a plant by law, and reopen it.** The plant keeps paying its costs (12.3, 19b);
- **charge** a fine, fee, tax or claim. Through the ledger; what is not paid is owed;
- **cap a price** of a company, a type or a lever-set list of items, from a month until it is lifted;
- **wind a company up**, with a reason: run the ending of 8.3;
- **pass title** of land and building in a buy-out or sale;
- **evict** a number of households from a block;
- **cut supply** of power and water to homes;
- **seize stock** under requisition at the making price.

## 14. For Wilma

- **Section 8:** title and land price are needed at step 3, not step 6.
- **Section 5, point 5:** the yearly raise follows the user's correction of 2026-11-17 (a duty at the minimum, not the
  company's choice). Settled.
- **Section 1, point 4 and sections 8 and 12:** three of my levers changed under 12.10, 65: `LAW_LAND_DISPOSAL` `KEEP`,
  `LAW_TRANSPORT_OPERATION` `PUBLIC` and `LAW_PRESS_LICENSING` `LICENCE`.
