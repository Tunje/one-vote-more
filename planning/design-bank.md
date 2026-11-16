# The colony bank: design (Bob, 2026-11-16)

Status: design and measurements only. Nothing here is built. Wilma relays the user's answer on whether to build.

The user's three points:
1. Lend against deposits as well as capital ("Yes on both").
2. The bank can raise capital ("Yes on both").
3. The bank should lose less to begin with, by pricing risk or asking for security, instead of lending to underbidding builders on the same terms as anyone else. The user said: "Yes, that sounds like a good suggestion". No caps built on past sales.

A gap to close as well: no AI government ever issues ECON_BANK_BAILOUT.

## 1. What was measured

**Code.** A scratch copy of HEAD after Wilma's change of 16 November (invoice credit and E153 on expected sales). The bank's code is unchanged apart from read-only counters.

**Runs.** Seeds 1–3 over 60 years, with the v11 defaults and with only the v10 switches. Tools:
- tools/_probe_bank.gd (scratch): the bank's yearly accounts.
- tools/_probe_deaths.gd (scratch): every private firm, co-op and builder that died.

The take-apart behind section 2 is in Wilma's v11 analysis and in my reports of 16 November. It used a scratch copy of HEAD 2168d26, before her change.

**Units.** Millions of credits. The bank starts with 16 of capital and may lend 10× its capital (CAPITAL_PM 100).

### 1.1 The bank loses more than it earns in five games of six

Interest earned, money sent home and losses are 60-year totals. "Lost loans" is what failed borrowers still owed when they died, before recoveries.

| Game | Interest earned | Sent home | Losses | Lost loans, private | Lost loans, builders | Lost loans, public enterprises | Bank fails |
|---|---|---|---|---|---|---|---|
| v11 seed 1 | 11.8 | 1.1 | 30.4 | 14.5 | 11.3 | 0 | year 38, for good |
| v11 seed 2 | 18.6 | 2.1 | 27.0 | 18.5 | 11.4 | 0 | never (capital 16 → 0.6 in year 31, then 4.7) |
| v11 seed 3 | 13.1 | 1.4 | 33.0 | 21.3 | 6.6 | 0 | year 36, for good |
| v10 switches, seed 1 | 7.3 | 2.5 | 23.7 | 20.4 | 13.2 | 0 | year 32, for good |
| v10 switches, seed 2 | 42.5 | 1.9 | 40.3 | 24.8 | 3.7 | 0 | never (refuses loans in years 9–20) |
| v10 switches, seed 3 | 27.8 | 0.4 | 46.1 | 32.7 | 14.8 | 0 | year 57 |

Reading:
- In five games of six, losses are 1.45–3.2 times the interest earned. In the sixth (seed 2, v10 switches) they are about equal (40.3 against 42.5). Only the bank's 16 million of founding capital keeps it going.
- Money sent home is small (0.4–2.5 over 60 years). Stopping it (E152c) would not save the bank.
- Public enterprises never die, so they never cost the bank anything.
- Losses come in waves:
  - Years 6–10: every game has a loss year of 3.5–6.9 here. In v11 seeds 1 and 3, builders' lost loans make up most of it (5.8 of 6.6, 4.1 of 6.9).
  - Years 30–38, or 48–57: private firms and a second builders' wave. Seed 2 v11 lent builders 0.6 → 11.8 in years 27–29 and lost 9.8 of it in years 30–31.
- The base rate is 0.6% a month (about 7% a year). At low utilisation the bank charges about 70% of that, about 5% a year, the same for every borrower. That price doesn't cover the losses in 1.1's table.

### 1.2 Room is not what binds; capital is

- While capital is above 0, the bank has refused almost nothing. The one exception is seed 2 with the v10 switches in years 9–20: capital 0.8–1.8, so a room of 8–18 against loans of 14–17.
- Line draws cut for lack of room: 0 in every game until the bank fails.
- After it fails, firms are refused 0.7–1.0 a year of term loans and 6–14 a year of line draws, for the rest of the game.

So lending against deposits would add nothing while capital is healthy (the capital limit of 160 stands far above loans of 5–30). Its value is in the years after a loss wave, when capital is thin.

Deposits are 9–65 (about 30 typical) and grow with lending, because the bank creates them.

### 1.3 Firms die of no customers, not of debt or lack of equity (Wilma's stock-market question)

Every private firm, co-op and builder that died in 60 years, by the cause at death:
- **No market:** operating surplus before interest ≤ 0 over its last year.
- **Debt:** surplus > 0 but below its monthly debt service, so it would have lived with less debt or more equity.
- **Cash:** surplus covers its debt service, but it ran out of cash.
- **Never opened:** died before its first sale.

| Game | Deaths | No market | Debt | Cash | Never opened | Builders (no market / never opened) | Bank had no room ≥ 6 of the last 12 months |
|---|---|---|---|---|---|---|---|
| v11 seed 1 | 218 | 99 | 4 | 22 | 93 | 35 / 4 | 66 |
| v11 seed 2 | 216 | 109 | 7 | 14 | 86 | 33 / 13 | 0 |
| v11 seed 3 | 254 | 116 | 8 | 24 | 106 | 35 / 11 | 93 |
| v10 switches, seed 1 | 182 | 85 | 1 | 5 | 91 | 36 / 20 | 86 |
| v10 switches, seed 2 | 181 | 96 | 3 | 14 | 68 | 44 / 11 | 9 |
| v10 switches, seed 3 | 201 | 82 | 4 | 22 | 93 | 35 / 25 | 16 |


- About half die with no market and 35–50% before their first sale. Only 1–8 per game (2–4%) die of debt their business could not carry; 5–24 more die of a cash gap.
- **No builder dies of debt.** Builders die with a negative operating surplus: they price below cost, which is the underbidding.
- So more equity (a stock market) would save few firms. What it would change is who carries the loss when a firm dies. Today a new private firm is founded with 40% of its building cost from its owner household and 60% borrowed (FirmAI new-firm path: `est * 6 / 10`), and it is the bank that loses the 60%.
- Firms that die before opening died with build loans of about 0.1–0.25 each (examples: service hub 0.25, farm 0.25, bakery 0.23). Many family firms die at 6 months holding cash and no debt; those are not a credit matter.

### 1.4 Jobs and the bank (correction to my report of 16 November)

On the code before Wilma's change I said unemployment jumps when the bank's room hits zero. On HEAD, seed 2 v11 shows that this is too narrow:
- The bank never fails there.
- Unemployment still goes 14% → 41% in years 27–40, right after the builders' boom and bust of years 27–31.
- Builders' borrowing falls from 11.8 to 0.3 and stays there.

The common trigger in all games is the builders' loss wave. Whether the bank then fails decides whether it lasts for ever.

## 2. Earlier finding that this design rests on

The credit change of 16 November (credit sized on expected sales) made lines and loans larger. This design keeps that ruling.

Without the expected-sales basis, the bank stayed alive on 9 of 10 seeds at 30 years, against 4 of 10 with it. On seed 1 with the plan stage, builders took 15–20 in lines and lost 23. The answer is not to shrink credit back to past sales (ruled out); it is for the bank to price and secure what it lends.

## 3. Design

Each part is behind its own switch until its own A/B. Saved state is integers only; everything below is integer ‰ or credits.

### 3.1 Lose less (the user's third point)

**(a) A rate that follows the borrower's record (risk price).**

The new loan's rate is:

    rate = base × utilisation factor (as now) × (1000 + risk‰) / 1000

risk‰ comes from what the bank can see about this borrower now. None of it is a limit built on past sales:
- each missed payment in the last 12 months (`missed`, the E140 record): +150‰;
- DISTRESSED or under a payment plan: +300‰;
- no trading record yet (months < MIN_M): +200‰ for a new firm or founding plan;
- cover = operating surplus ÷ debt service including the new loan, for firms with a record:
  - below 1: +400‰;
  - 1 to 1.5: +150‰;
  - above 2: −100‰;
- a builder's contract priced below the bank's own cost estimate for that project: +500‰ (see c);
- security pledged (b) reduces risk‰ by the secured share.

Rates are set once, when a loan or line is opened, and when a line renews each year.

The bank's interest then pays for its expected losses. The ‰ values above are starting points for the A/B, to be tuned until interest covers losses in the 60-year runs. Good borrowers pay less than today.

A firm whose project cannot carry the price will not borrow, which is the market signal ("it costs them"), not a ban.

**(b) Security.** The bank lends against what it can take back, and is paid first from it on failure.
- **Buildings and plants (term loans).** The loan is secured on the plant. On liquidation the bank takes the plant, not a write-off: it sells, reuses or tears it down through Otto's empty-buildings mechanism (446fe62), and the proceeds go to the bank before anyone else. E152b's pass_debt already moves a secured loan with a plant sold to a co-op; this generalises it to every sale.
- **Stock and receivables (lines).** E153's line_limit (50% of stock at cost, 80% of open invoices, plus a month of expected sales) is already written. It is opt-in and off by default. Turning it on makes the secured part of a line explicit, and the secured share lowers risk‰.
- **Signed contracts (builders).** A builder's line is secured by assignment of the contract: the client's stage payments go to the bank first, until the line drawn for that project is repaid. The line for a project covers at most what the contract still pays. This is an order book, not past sales, so it stays within the ruling. Public clients pay reliably, so lines backed by government contracts are cheap.

**(c) Underbidding builders.** Builders die with a negative operating surplus because they bid below cost.

The bank prices that risk where it arises: when a builder draws a line for a contract priced below the bank's cost estimate for the project (EconConstruction.estimate at today's prices), the shortfall part of the draw is unsecured and carries the +500‰. A builder that still wants the job pays for the risk, and the price signal reaches its bids (Otto's client-ceiling work) instead of the loss landing on the bank.

This is the bank's judgment of one contract, not a cap on the builder.

**(d) Owners' share at founding.** The bank asks for more of the owner's own money when the record is thin. It would lend 60% of the build cost to a new firm only with security (a). Without security it lends 40–50% and the founders or shareholders bring the rest, or the firm does not start.

This is where a stock market (Wilma's study) would plug in: shares sold to households and the home world raise the owners' part.

### 3.2 Lend against deposits as well as capital (point 1)

    room = max(0, min(capital limit, deposit limit) − loans)

The capital limit stays capital × 10. The deposit limit is the deposits the bank holds, less a liquid reserve (deposits × (1000 − RESERVE‰)/1000).

While capital is healthy the capital limit binds on paper, but neither binds in practice (1.2). After a loss wave, when capital is thin, the deposit side keeps the bank lending against money it actually holds, but only secured lending (3.1 b). Unsecured lending stays tied to capital.

So a thin-capital bank keeps funding secured working capital and contract-backed builder lines, instead of stopping dead as now.

### 3.3 Raise capital (point 2)

In order of preference, each automatic, with no player action needed:
1. **Retain earnings.** Nothing goes home while capital is below the floor. E152c is written but off; turn it on. With risk pricing, retained interest rebuilds capital from the loan book.
2. **Issue shares.** When capital falls below the floor, the bank offers new shares:
   - first to the home-world parent, which pays in proportion to what it expects back (the remittance stream);
   - then to colony households with savings.

   Buyers get a share of future profit (EconShares exists for firms). This is the stock-market hook again, and Wilma's study decides whether it is one market or separate.
3. **Bailout by the government** (next section).

### 3.4 The bailout gap (no AI government ever issues ECON_BANK_BAILOUT)

Today a failed bank stays failed unless loans still paying interest are left on its book (seed 2 with the v10 switches recovered on government loans). Options:
- **A. The AI government decides, at a political cost.** On ECON_BANK_FAILURE or a credit crunch, the governing party weighs a recapitalisation:
  - for: jobs (the JOBS effect and unemployment rising), an approaching election;
  - against: treasury runway, FAIRNESS (bailing out a home-world bank), its ideology.

  The fact already carries those effects (GOVERNANCE −10, FAIRNESS −10, JOBS +10). The opposition can attack either choice. This fits "governments are allowed to make things worse, but it costs them".
- **B. The home-world parent recapitalises** (3.3, step 2), possibly on terms: higher rates for a period, or a political price from the home world. This ties into Wilma's home-world pressure (home_world.gd).
- **C. A resolution rule.** A failed bank turns part of large deposits (firms' and the treasury's) into capital: a bail-in. Depositors lose; lending restarts. It's a law the legislature can pass or not, so Anni's law side.
- **D. Nobody acts.** The current state, kept only as the outcome when A–C all decline, never as a dead end by omission.

Recommendation: B always available (the parent wants its remittances back), A as the AI's choice with its political cost, and C as an optional law.

## 4. What I would measure before choosing

1. Risk price alone (3.1 a) against base, 10 × 30 and 3 × 60: bank losses, interest earned, adults, unemployment, builder crews.
2. Security alone (3.1 b, with E153 on), then risk price + security + underbid pricing (c).
3. Deposits (3.2) and capital raising (3.3), then the bailout options (3.4).

The headline numbers to report are the bank's 60-year losses against its interest, the years with no room, and unemployment in decades 3–4. Building waits for the user's answer.

## 5. Not in this design

- Household credit and mortgages (M2b).
- The stock market itself (Wilma's study).
- Ships and the home world's trade decisions.
