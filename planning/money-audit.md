# Money audit (2026-11-14)

User: "What is it we are missing? Something is all wrong here" -> agreed: pause new features, audit the money system,
then fix it instead of patching each place that runs short.

Tool: game/tools/money_audit.gd (v9 defaults incl. E140; seeds 1-3, 60 years, every 5 years). Anni mapped the law,
union, party and press accounts (seed 1, 60 years). Units below: the probe's millions (relative sizes matter).

## Findings

### 1. Almost no new money enters after the first year
- Year 1: 39 flows in from outside (the charter's start-up money). From year 2 on: 0-3 a year (exports, migrants).
- Total colony money: 28-29 at Y1 -> 45 / 101 / 98 at Y60 (seeds 1/2/3), while adults grow x4.6 / x5.7 / x7.3.
- Money per adult falls by about half to two thirds. The General wage peaks around Y5-15 (1,240-1,900) and ends at
  900 / 1,000 / 680: a 60-year deflation. Bob's earlier check (+66% money vs x3.6 people) said the same.

### 2. The bank does not create money; it shrinks
- The bank's lending limit (10x its capital) falls from 161 to 16-56. Its own reserves go from 10 to 0 and below.
  Seed 1's bank fails around year 45.
- Loans outstanding stay tiny: firms 1-9, public companies 0-3, government 0-10, households 0.
- Utilisation is 1-8% of the limit for most of the century, while the economy is starved of cash.
- Why so little borrowing (Bob): working-capital credit needs a profitable last 12 months, which most firms don't have;
  public companies never borrow; households can't; the government borrows only when the treasury runs dry; loans are
  short (12-60 months), so the book shrinks. Why the capital erodes is still open.

### 3. Money stops in the treasury and in union funds
- The treasury holds 19-68% of all colony money. In seed 3 it climbs to 62-68% from Y40, while all households together
  hold 5-9%.
- Households then spend their money 15-18 times a year (seed 3, Y40-60): they live hand to mouth.
- Union funds (Anni): 0.3M at Y5 -> 5M at Y25, 16-35% of household money for 40 years. Dues come in; almost nothing
  goes out until rebates start after Y25. E133's cap sits far too high.
- Not sinks: fines (swept to the treasury monthly), the victims' fund, party funds (spent each campaign), newspapers.

### 4. What this explains
Households can't afford food, bread or services; firms can't buy inputs or pay wages; public companies need top-ups;
new firms die before employing anyone (the chronicle's new-firm table: 27 founded in 12 years, 4 working after a year,
595 jobs lost against 95 created). Every patch today (grants, credit lines, supplier credit, price rules) moved cash
from one starved place to another; the total stayed too small and badly placed.

## Fix plan (one money system, not patches)

1. **Money must grow with the economy: the bank.** Find and fix why the bank's capital erodes. Then lend for working
   capital against stock and receivables (E148's invoices), not only against a profitable year. Households get
   capped consumer credit (M2b) and later mortgages. Deposits created by lending are the main way money grows.
2. **The treasury must not hoard.** A fiscal rule in the legislature: above a reserve target (e.g. 6 months of
   spending) governments get a strong push to cut taxes or spend; below it, the reverse. Pressure, not a ban (the user's
   rule). The earlier idle-money test drained the reserve and then maxed taxes, so the rule must be two-sided.
3. **Money from outside: exports.** Exports bring 0-3 a year. Find whether the ship hold, port capacity, prices or the
   charter levy keeps them so small (Bob's A61 M1 ledger), and fix the binding one.
4. **Union funds.** Lower E133's cap so dues above a strike reserve flow back to members.
5. **Measure it.** The money audit columns (money per adult, treasury share, bank limit and loans, velocity) go into
   the chronicle's yearly table, so every run shows whether the money system works.

Order: 1 and 2 first (they are the biggest), then 3 and 4. Each opt-in with its own A/B; then the combined package with
the opt-in work parked during the pause (E146-E150), judged on 10 seeds.
