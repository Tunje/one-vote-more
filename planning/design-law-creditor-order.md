# Design note: the creditor order (joint, law and economy)

Anni, 2026-11-15. Job 2.5 from the law survey (§2.5). A **joint note with Bob**: it changes his `_waterfall`. The law
sets who is paid in what order; Bob's code pays. Design only. **Agreed with Bob 2026-11-15; flag E174** (built with the
rule-6 sale mechanism; E166 rescues build on it). Bob adds `EconCredit.owed_by(world, oid) → {creditor: mcr}` and
`o.wage_arrears` (mcr, with its start month) for class W; the law computes, the waterfall pays.

## 0. Today (`insolvency.gd:_waterfall`, when a firm is dissolved)

1. The bank is paid every loan's principal from the firm's cash. The rest of each loan is written off.
2. Whatever is left goes to the owner household, or to the treasury if there is no owner.

Not in the waterfall:

- **Supplier invoices (E148):** written off separately as the seller's bad debt.
- **Open liabilities** (my fines and compensation, instalment plans, victims' awards, the plan's debts): left OPEN on a
  dissolved firm, never paid and never formally written off.
- **Wages owed:** none tracked as a claim.
- **Builder deposits and advances** (the contracts note): no place.

So a firm's failure costs its bank little and its suppliers and victims everything. That's how one failure spreads
quietly (E148), and why the user saw firms fail in chains.

## 1. The order in law: LAW_CREDITOR_ORDER

A new LAW-level lever with three settings. Every setting keeps the same classes; only the order changes.

**The classes** (each claim is in exactly one):

| class | what | holder |
|---|---|---|
| **S, secured** | bank loans (and grant loans: the bank's security is the plant) | the bank |
| **W, workers** | unpaid wages, up to **3 months** per worker; tort awards to workers (stress, accidents, unfair dismissal) | the workers' households |
| **P, the state** | fines, unpaid taxes and fees, grant clawback, state loans | the treasury (fines to gov:fines_revenue) |
| **U, unsecured** | supplier invoices; victims' compensation (law:victim_fund); builders' and customers' claims (deposits, cancellation fees); other COMPENSATION rows (with their creditor_acct) | each creditor |
| **O, owners** | what's left, by the share register (shares note) | the holders |

**The settings:**

| LAW_CREDITOR_ORDER | order | in real life |
|---|---|---|
| **0 BANK_FIRST** (default: today's spirit, with the gaps filled) | S → U → O | lender-friendly |
| **1 WORKERS_FIRST** | W → S → U → O | most of Europe: wages are preferred |
| **2 STATE_FIRST** | S → P → U → O | an old "crown preference" |

- Where a class isn't listed (W in setting 0, P in settings 0 and 1), its claims are **unsecured**: they join U pro
  rata.
- Workers' claims aren't lost under setting 0; they just aren't ahead.
- **Within a class: pro rata** by claim size.
- **What isn't paid** is written off and recorded:
  - each OPEN liability gets status `WRITTEN_OFF`;
  - each invoice becomes the seller's bad debt (as today, but now after its share of the estate);
  - one fact, **LAW_ESTATE_DISTRIBUTED** (PUBLIC; magnitude by size), with data {class: {claimed, paid}} and the
    largest losers. The chronicle and the press can say "suppliers got 12p in the pound".

**Victims as a political choice.** Victims' compensation sits in U by default. If the user wants it, a 4th setting (or
a BOOL, LAW_VICTIMS_PREFERRED) can put victims with W. I'd hold that back until the A/B shows how often victims lose.

## 2. The estate and the hook

- **The estate** = the firm's cash after its plants are sold (liquidation sales, or `SaleLaw.closed` for a distressed
  sale: the price lands in the seller's account first, as agreed).
- `CreditorLaw.claims(world, oid) → {S: [...], W: [...], P: [...], U: [...]}`. The law gathers them from:
  - the loan table;
  - liabilities (debtor = oid);
  - invoices (Bob's E148 rows; Bob gives a reader);
  - wage arrears (Bob gives a reader, if he tracks them);
  - deposits held (the contracts note).
- `CreditorLaw.distribute(world, oid) → {paid: {class: amount}, written_off: {...}}` returns the payment plan.
  **Bob's waterfall executes it** (ledger transfers), then calls `CreditorLaw.close_estate(world, oid, result)`, which
  marks rows and emits the fact.
- **Administration (before liquidation)** stays Bob's: rescheduling (E152a), workouts (E77), the 12-month liability
  plan (E135). Law adds one rule there: **a plan may not pay owners (dividends) while any W or P claim is overdue.**

## 3. Late-payment interest and creditor petitions

- **LAW_LATE_PAYMENT_INTEREST** (0–2% a month, default 1%): charged on overdue invoices (E148) and overdue liabilities.
  The same lever is used in the construction contracts note, for arrears. It is added to the claim; it doesn't need a
  separate ledger flow until the claim is paid.
- **Creditor petitions:** any creditor in U or P with claims more than **6 months** overdue and over **1 W_ref** may
  petition for liquidation (`EconInsolvency.court_liquidation`, reason CREDITOR_PETITION).
  - Today only my unpaid fines do (12 months). The fine rule folds into this one, keeping 12 months for the state.
  - Suppliers get the same weapon the state has. Small sums can't kill a firm.
- **A firm with a payment plan** (E135, small-firm instalments) can't be petitioned while it keeps to the plan.

## 4. Related protections (from the sales note)

- **Transactions at undervalue** (a distressed seller selling below the floor to a related buyer) can be voided by the
  creditors: the court case returns the plant or the difference to the estate. That's in the sales note as
  ASSET_STRIPPING.
- **Loans moving with a sold plant** need the bank's consent. Other creditors aren't asked, because the price goes to
  the estate.

## 5. Who decides

| decision | owner | alone? | goes higher when |
|---|---|---|---|
| LAW_CREDITOR_ORDER, LAW_LATE_PAYMENT_INTEREST | **parliament** (LAW levers) | no | a bill |
| The state waiving its own claims (fines, taxes) in a rescue | **Minister of Finance** | yes, up to LAW_STATE_AID_THRESHOLD (shares note) | above: **the Cabinet**; it's state aid |
| The state petitioning a debtor | **Minister of Finance** (tax and fees); the courts for fines (as today) | yes | n/a |
| A supplier's or victim's petition | the creditor and the courts | n/a | n/a |
| Distribution itself | the court and the administrator (automatic) | n/a | n/a |

The First Minister never sees an ordinary insolvency. Only a state waiver above the aid threshold reaches the Cabinet.

## 6. Ideology (for Wilma)

- **LAW_CREDITOR_ORDER** (NUMBER 0–2, default 0; the politics legislates numbers):
  - setting 1 (workers first) pulls LABOR / REDISTRIBUTION up; setting 2 (state first) pulls INSTITUTIONS toward order
    and FISCAL;
  - as one slope: REDISTRIBUTION +4 per step toward workers. Wilma: perhaps better as two BOOLs (workers preferred,
    state preferred) if one number reads oddly.
  - Concerns: JOBS +3 (setting 1) / FAIRNESS +3.
- **LAW_LATE_PAYMENT_INTEREST** (0–2% a month, default 1): ECON_ROLE −0.5 (market-minded like it). Concerns: JOBS −1 /
  FAIRNESS +2.

## 7. Questions for Bob

1. Can E148 invoices and wage arrears be read as claims (`EconCredit.open_invoices(world, debtor)`, and wages if you
   track them)? If wages are always paid or the worker is laid off, class W is only the tort awards. That's fine.
2. Is it OK that the waterfall executes a plan the law computes (law decides, economy pays, as for fines)? Or would you
   rather call `CreditorLaw.order(world)` and keep the arithmetic?
3. Flag: yours. It sits naturally with E166 (rescues) or with §3b's rule-6 sales.

## 8. Tests (when coded)

1. Setting 0: the bank is paid first; suppliers, victims and fines share the rest pro rata; owners get nothing until
   all are paid.
2. Setting 1: wages and worker torts come before the bank. Setting 2: the state comes after the bank and before the
   suppliers.
3. Unpaid rows are WRITTEN_OFF, and the fact gives "pence in the pound" per class.
4. A supplier 6 months overdue over 1 W_ref petitions; one with a kept payment plan can't.
5. Late interest grows a claim by 1% a month.
6. An administration plan can't pay dividends with wage or state claims overdue.
7. Flag off: today's waterfall, bit-identical.
