# Design note: the builders' order book: contract terms (law side)

Anni, 2026-11-15. Job 2.3 from the law survey (§3), for Bob's order book (E165Q2/Q3, R8 step 4). Design only. **Agreed with Bob
2026-11-15** (R8 step 4). Bob's answers: the 5% deposit is drawn from the plan's credit (interest-free until opening),
else the founder's cash, so the advance becomes 5% at award + 5% at the start; abandon_plan pays fee → bank → founder;
the labour revision here **replaces** E165Q2 (e) and E165Q3's re-estimate; `ContractLaw.terms` at award is the one source.

## 0. Today (in code)

- **Award:** the price is fixed. Under E165Q the job waits in the builder's book until a crew is free (`start_month`).
- **Advance:** 10%, paid at the start, not at award (E165Q).
- **Payments:** 80% of work done each month. The rest (10% retention, net of any late penalty) is paid at completion.
- **Late penalty:** 1% a month, capped at 10% (only if the owner's supervision ≥ 500).
- **Price risk:** the E76 escalation clause moves the price with MATERIAL and COMPONENT prices **since award** (−50% to
  +100% of the input cost). The owner bears it.
- **The builder walks away** from a private contract after 3 unpaid months (ECON_PROJECT_CANCELLED). On a government
  contract it only reports ECON_CONTRACT_PAYMENT_MISSED.
- **The owner's cancellation:** DECISIONS E30 says "pays progress + 5% of the remaining value"; **never coded.** A
  founder abandoning a plan (E165) cancels its projects and pays the builder nothing.
- **The builder's failure:** the job goes back to tender. The owner keeps the progress. The builder's reliability is
  halved.

## 1. The standard contract

One function gives every contract its terms at award, so they're fixed for the job's life (a later law change binds
new contracts only):

```
ContractLaw.terms(world, job) -> {deposit_pct, advance_pct, progress_pct, retention_pct, late_pct, late_cap_pct,
    start_grace_m, revision: {from, labour, cap_pct, walk_pct}, cancel_before_start, cancel_after_start_pct,
    builder_stop_m, interest_pm}
```

| term | value | why |
|---|---|---|
| **Deposit** | 5% of the price at award (signing) | the order book's new piece: a place in the book costs something, so founders don't book every builder. Counted toward the advance. |
| **Advance** | 10% at the start, less the deposit already paid | as today |
| **Progress** | 80% of work done, monthly | as today (E30) |
| **Retention** | 10%, paid at completion | as today |
| **Late penalty** | 1% a month after the agreed finish, capped at 10% | as today; the supervision gate stays Bob's (whether the owner notices) |
| **Start grace** | the quoted wait + max(3 months, half the wait) | a builder may slip a little. Beyond the grace, the owner may cancel for free (see 3). |
| **Price revision** | materials: the E76 clause from award, as today. **Labour (new):** if the wait was over 6 months, the labour share is revised at the start by the General wage index since award, capped at ±15%. | a long wait shouldn't lock in old wages. The cap keeps the bid meaningful. |
| **Revision walk-away** | if revision at the start raises the price by more than 10%, the owner may cancel before the start for the deposit only | protects founders from a book that got dear while they waited |
| **Owner cancels before the start** | the deposit is kept by the builder (that's the fee); nothing more | simple, and gives the deposit a purpose |
| **Owner cancels after the start** | progress to date + **5% of the remaining value** (E30, finally coded) | the builder's lost margin and crew cost |
| **Builder stops for non-payment** | after **3 unpaid months**, private or government | today only private. A builder may stop a government job too: it's suspended (not ended), and the arrears are owed with interest. |
| **Interest on arrears** | LAW_LATE_PAYMENT_INTEREST (from the creditor note; 0–2% a month, default 1%) | the same rule as invoices (E148) |

## 2. Who bears what

- **The founder's plan abandoned (E165):** it's the owner's cancellation.
  - Before the start: the builder keeps the deposit.
  - After the start: progress + 5%. It's paid from the plan's cash **before** the bank's draw is repaid and before
    anything returns to the founder household. The builder is a creditor of the plan, ranked by the creditor order
    (job 2.5). Without the creditor order, it's paid first from what the plan holds.
  - What isn't paid becomes the founder's COMPENSATION liability (my `_owe`). A plan has no further assets, so in
    practice it's a write-off. It's on record as a lost claim (fact LAW_CONTRACT_CLAIM_LOST) for the builder's
    distress.
- **The builder fails (insolvency, or abandons the job: E169 half-built):**
  - the owner keeps the work done (it's on the owner's land);
  - the unearned part of the deposit or advance is a claim in the builder's insolvency;
  - the retention held so far covers the owner's extra cost to re-tender, up to its amount;
  - the job is re-tendered (as today). The half-built work is valued at progress paid.
- **A builder late past the grace:** the owner may cancel and get the deposit back. Or wait, with the late penalty
  running from the agreed finish.
- **Price risk:** materials (E76, from award) and the capped labour revision fall on the owner. Everything else is the
  builder's (fixed price).

## 3. The government as client

The same contract binds the government (no special treatment), with two differences:

- The government can't be petitioned into liquidation. Its arrears are owed with interest (gov_owed), and a builder may
  stop work after 3 months. A suspended public job is public (fact ECON_PUBLIC_JOB_SUSPENDED), which is political.
- Cancelling a public project pays the same fees, from the INFRASTRUCTURE line.

**Who decides:**

| decision | owner | alone? | goes higher when |
|---|---|---|---|
| Sign a public contract (award) | **Minister of Infrastructure** | yes | as in the concession note |
| Cancel a public job before the start (deposit lost) | **Minister of Infrastructure** | yes | never; the cost is small |
| Cancel a public job after the start (progress + 5%) | **Minister of Infrastructure** | yes, if the fee ≤ [5] W_ref | above: **Minister of Finance**; a flagship project (≥ 2% of annual spending): **the Cabinet** |
| Pay arrears late / let a job be suspended | **Minister of Finance** | yes | n/a (the treasury's state) |
| Accept a revised price (wait > 6 months, revision ≤ 15%) | automatic (the contract) | n/a | n/a |
| Contract terms in law (the table in 1) | constants now. If the user wants them political: **parliament** (one lever, LAW_CONSTRUCTION_DEPOSIT 0–20%) | n/a | a bill |

## 4. Law pieces

- **New:** ContractLaw.terms; LAW_LATE_PAYMENT_INTEREST (shared with the creditor note); fact LAW_CONTRACT_CLAIM_LOST.
- **Optional:** LAW_CONSTRUCTION_DEPOSIT.
- **No new rule:** breach of contract is civil (TORT-style claims through the existing case machinery only when a party
  disputes; the default is that terms execute automatically).
- **Disputes (optional, later):** a builder or owner may sue over a cancellation fee or a late penalty. That's the
  existing CONTRACT case type, if Bob wants courts in the loop. I'd leave it out at first: automatic terms are enough
  to make the money right.

## 5. Questions for Bob

1. Deposit at award: does 5% fit the E165Q2 founders' cash (the plan's cash is drawn as the builder is paid)? Or
   should the deposit be drawn from the bank credit like progress?
2. Where does a cancelled plan's cash sit when `abandon_plan` runs: is the order "builder fee → bank → founder"
   workable in your code?
3. Is the labour revision useful, or is your bid's crew-cost estimate already re-made at start?

## 6. Tests (when coded)

1. The deposit is paid at award and counted in the advance.
2. Owner cancellation before the start forfeits the deposit; after the start it pays progress + 5% of the rest.
3. A wait over 6 months revises the labour share by the wage index, capped at 15%. A rise over 10% lets the owner
   walk away for the deposit.
4. A builder past the grace: the owner cancels and gets the deposit back.
5. Plan abandonment pays the builder before the bank and the founder.
6. A government job unpaid 3 months is suspended, and the arrears carry interest.
7. Builder insolvency: the unearned deposit is a claim; retention covers re-tender cost.
8. Flag off: nothing changes.
