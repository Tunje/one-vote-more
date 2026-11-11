# spec-events-v1 — Crises, natural and man-made (M11)

Owner: Wilma (spec, politics side). Economy and company side: 88. Law side: a9.
User decisions (2026-11-11):
- Crises must be possible, including famine. Problems must not be coded out of the game.
- They are **random**: there is no schedule and no fixed frequency.
- **Company greed must be able to cause them.**

## 1. Principle: hazards, not a calendar

There is no event schedule and no "one crisis every N years". Each hazard has a **monthly probability** computed from the current state of the colony, rolled on its own named RNG stream (deterministic per seed, PIC rule).

- Bad conditions raise the probability; good preparation lowers it.
- Calm decades and clustered disasters can both happen.
- **Severity** is rolled separately (mostly small, occasionally large; heavy-tailed).
- **Impact** depends on preparation: food reserves, spare power, health capacity, import routes, insurance and savings.

A prepared colony bends; a neglected one breaks. Hazards trigger and amplify each other: a power failure leads to water loss, which leads to crop loss and then famine.

## 2. Hazard list (v1)

| Hazard | Natural driver | Raised by (human / greed) | Lowered by | Typical impact |
|---|---|---|---|---|
| Drought / crop blight | climate draw, season | soil exhaustion from overfarming for profit, cut irrigation upkeep | farm diversity, irrigation, reserves | farm output −20..−80% for 1–3 seasons |
| Epidemic | base rate, overcrowding | contaminated water from cheap waste disposal, unsafe housing, health cuts | health budget, sanitation, clean water | sick workers, deaths, health demand |
| Industrial accident / mine collapse | hazard class | **skipped maintenance, safety corners cut to raise profit**, weak safety law, lax inspection | upkeep met, safety standard, inspectors | deaths, plant closed, liability |
| Power / water plant breakdown | age, condition | deferred maintenance, under-investment by a profit-taking or monopoly owner | condition, spare capacity, redundancy | outages, cascades to water, farms and freight |
| Contamination / pollution incident | — | illegal dumping, emission limits ignored to save costs | emission law, enforcement, fines | health hit in nearby districts, cleanup cost |
| Supply ship late or lost | origin draw | — | reserves, local production | missing imports for 1–6 months |
| Building / infrastructure failure | age | builder cut corners on a fixed-price contract, bribed inspection | draft quality, inspection, enforcement | casualties, homes lost, repair cost |
| Speculative food crisis | a real shortfall | **hoarding and price gouging**, exporting food in a shortage, cartel price fixing | price-gouging law, reserves, competition law | prices spike, poor households can't eat |
| Financial crash | — | reckless bank or firm lending, asset bubble | bank rules, reserves | firm failures, layoffs |

Famine is not a separate dice roll. It **emerges** when the food supply chain (farms, water, power, freight, imports, prices) fails for long enough. The existing ECON_FAMINE rule (shortfall ≥ 25% for 3 months) stays.

## 3. Company greed (the corporate driver)

Each company gets an owner/management trait `greed` (0–100) next to its existing management quality. It is seeded at founding, shifts with leadership changes (COMP_CEO_REPLACED), and is pushed by pressure: distress, a monopoly position, a weak regulator.

Greedy firms, when profitable to do so:
- **defer maintenance and safety spending** to raise payouts (now possible because E80 pays out surplus cash);
- **cut corners on contracts**;
- **dump waste or exceed emission limits** when expected fines are below the saving;
- **hoard and price-gouge** essentials in a shortage, or export food that the colony needs;
- **form cartels** where few firms compete.

Each of these choices raises the matching hazard's probability. Each is also a **violation that law can detect**: inspections, whistleblowers and investigations, with a chance that depends on enforcement levers and budget. When caught, the result is fines, licence suspension, prosecution of managers and civil liability to victims.

Every crisis records its **actual cause** (e.g. "Redrock Mining Co. skipped 9 months of shaft maintenance") as SECRET until revealed. The **perceived cause** goes to the public by the blame model. A greed-caused disaster that comes out later becomes a scandal for the company and for the government that let it happen, and a strong issue for parties. This is PD §7.10: actual vs perceived responsibility.

## 4. Ownership

- **88 (economy and companies):**
  - the hazard engine (monthly probabilities, severity rolls, impacts) for the economic hazards;
  - the `greed` trait and the greedy choices;
  - preparation stocks: food reserve, spare capacity;
  - facts with actual cause, and `exposure` blocks for S4.
- **a9 (law):**
  - detecting the violations (inspection, whistleblower, investigation) and the sanctions;
  - civil liability;
  - emergency powers (rationing, price controls, export bans, requisition) as levers, with constitutional limits;
  - new levers where needed: price-gouging law, competition/cartel law, emission and safety enforcement budgets.
- **Wilma (politics):**
  - crises raise salience (agenda-setting already exists);
  - blame by perceived cause;
  - crisis leadership: approval rally or collapse depending on response speed;
  - opposition and parties campaigning on crises and revealed corporate negligence;
  - single-issue parties can form from crisis anger.

## 5. Gates

1. **Guard test:** a deliberately mismanaged colony (farm budget 0, imports banned, food reserve 0) reaches ECON_FAMINE within 10 years. This stops anyone from coding famine out by accident.
2. **Greed test:** two otherwise identical colonies, one with greedy firms and lax enforcement and one with neither. The greedy one has significantly more accidents, breakdowns and contamination (measured over 6 seeds).
3. **Randomness test:**
   - over 6 seeds × 100 years, gaps between serious crises vary widely, from back-to-back to decades of calm;
   - no fixed period;
   - deterministic per seed.
4. **Survivability:** the ordinary economy gate (item G, A29) still passes with hazards on: a reasonably run colony survives most crises, but not without cost.
5. **The chronicle** lists every crisis with its actual cause, perceived cause, impact and political consequence.
