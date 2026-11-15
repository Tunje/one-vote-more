# Law survey: this week's economy work (Anni, 2026-11-15)

The user asked: "Isn't there a lot missing in law on all of this?" Yes. The economy has gained contracts, debts, shares,
concessions and plant sales. The law still sees almost none of them: every law check the economy calls today is about
building permits, hazards and the charter. This note lists, for each new piece:

- what law already covers;
- what is missing;
- where existing law collides with it.

The last section lists what I propose to do first.

**Status of the pieces.**

| | pieces |
|---|---|
| **Built, opt-in** | family farms and bakeries (E160/E162), supplier credit (E148), the planning stage (E165/E165B/E165Q), public tariffs (E150/E150P), wildlife (ECO) |
| **Design only** (planning/eight-rules.md) | rescues (E166), half-built buildings (E169), family buy-outs (E164), the order book's later steps (E165Q2/Q3), hauliers (E172), selling parts of a company (§3b), public builders and concessions (§3c) |

So most of the law can still be designed in before the code exists.

## 1. The quick picture

| Piece | Law that already covers it | What's missing | Collision |
|---|---|---|---|
| **Charter quota (E171)** | all of it (done this week) | none | none |
| **District prices (R8 §3a)** | gouging rule (LAW_PRICE_GOUGING), price control (LAW_PRICE_CONTROL) | a definition of gouging that works with district prices | **yes**: see 2.1 |
| **Family farms and bakeries, grants (E160/E162)** | grant levers (ECON_*_GRANT, LAW level); the programme ends by enactment | family-work rules; terms of the grant loan; what the grant obliges | **yes**: unpaid family work vs labour law (2.4) |
| **Supplier credit, invoices (E148)** | none | the creditor ranking of invoices; late-payment interest; what a supplier can do (petition) | **yes**: the insolvency order (2.5) |
| **Planning stage, order book (E165, Q2/Q3)** | the E76 price escalation clause; a late penalty; a builder may walk away after 3 unpaid months | a contract: deposit, refund, cancellation fee (DECISIONS E30's "progress + 5%" was never coded), price revision at the start date, who bears a builder's failure | small (2.5) |
| **Rescues, share sales, bailouts (E166)** | ECON_SUBSIDIZE, bank bailout, nationalisation of strategic plants at 40% | who may own shares and what a stake gives; conditions on a state bailout (state aid); bank stakes | **yes**: competition and media ownership (2.2, 2.7) |
| **Half-built buildings (E169)** | none (today the job is re-tendered) | who owns the half-built work; the contractor's liability; how it is sold | small |
| **Family buy-outs (E164)** | none | sale terms; families' first right to buy | small (competition) |
| **Selling parts of a company (§3b)** | the competition law's merger review exists but **is never called** | a sale contract: crew, loans, customers, licences moving with the plant | **yes**: competition (2.2), labour (2.4), loans and creditors (2.5), licences (2.6) |
| **Public builders, concessions (§3c)** | the direct-award threshold (LAW_DIRECT_AWARD_THRESHOLD) exists but **is never read**; the award override fact | concession law: tender, term, retainer, termination | **yes**: procurement (2.3) |
| **Public tariffs (E150/E150P)** | the government approves (an action) | none needed now; maybe a regulator later | small: predation rule (2.2) |
| **Freight and hauliers (E172)** | transport law (franchise or open market) covers passenger routes only | a haulier licence; whether CTA's freight is a statutory monopoly | small |
| **Wildlife and deaths (ECO)** | wildlife policy lever; political blame | employer duty of care; the victims' fund; claims against the state | **yes**: liability (2.6) |

## 2. The collisions

### 2.1 Price gouging against rule 1 and district prices

**Today.** Gouging (a MINOR market offence) is reported when the colony is short (buyers got less than 90% of orders)
and a seller with spare stock asks 1.5 × the colony price.

**The problem.** Under R8 there is no single colony price. A district where bread can't be delivered *should* get dear;
that is rule 1, and it is the signal that brings hauliers and founders in. The current test would either:

- call honest district prices gouging, measured against the colony average; or
- (if measured against the district price) never fire.

**Fix.** Gouging becomes:

- *asking well above one's own district's price while holding stock to spare*, i.e. exploiting a shortage one could
  relieve; and
- with **LAW_PRICE_CONTROL = ESSENTIALS**, a cap on essentials at a multiple of the district price of a neighbour plus
  freight.

High prices where goods truly can't arrive stay lawful. Small change, my side plus one number from Bob.

### 2.2 Competition law against plant sales, rescues and buy-ins

**Today.**

- Competition law has a dominance share (LAW_DOMINANCE_SHARE, 50%) and a merger threshold (LAW_MERGER_THRESHOLD, 100 =
  no review), and a full review path (`competition_law.request_takeover`: authority review, a government decision,
  conditions).
- **No economy code calls it.** Today's sales (liquidation sales, E91 forced sales, worker buy-outs, reprivatisation)
  all happen with no check, and same-sector buyers are even preferred.

**What collides.**

- **§3b plant sales** let a firm grow by buying rivals' plants. Under a strict merger law that's exactly what should
  need approval.
- **E166 share sales and founders buying in:** a stake in a rival is a creeping takeover.
- **Predation (PRICE_BELOW_COST for a dominant firm)** against rule 2 (cut toward variable cost) and a **public builder
  bidding at cost** (§3c a). A dominant firm or the state's builder pricing at cost is the textbook case.

**Fix.**

- Every plant sale, share purchase above a threshold and rescue by a rival calls `request_takeover`.
- Rescue of a failing firm gets the usual "failing firm" defence: review is quick and conditions light when the
  alternative is closure.
- Public builders that bid at cost while dominant count as predation unless the government exempts them by law, which
  makes the choice political, as Bob's §3c wants.

### 2.3 Procurement law against the concession and retainer

**Today.**

- The direct-award threshold (LAW_DIRECT_AWARD_THRESHOLD, default 50,000) is defined but **never read**. Every public
  job is tendered whatever its size.
- The award override (choosing a lower bidder) is a public fact.

**What collides.** A road concession means appointing one builder for all road work for 5 years without tenders, plus a
retainer paid in idle months. Under the current procurement rule, every job above the threshold should be tendered, so
the concession is unlawful as it stands.

**Fix.**

- Concession law: the concession *itself* is tendered once (that's the competition), and the jobs under it are lawful
  direct awards.
- The retainer is a contract term, capped by law (proposed: at most 40% of the reserved crew's wages in idle months, at
  most 5 years, renewed only by a new tender).
- A government that awards a concession without a tender, or to a lower-ranked bidder, commits an unlawful act (my
  unlawful_track: secret until found, then a scandal and a court case).
- Small jobs below the threshold may be direct-awarded to anyone. That finally makes the lever do something.

### 2.4 Labour law against unpaid family work and crews that move with a sold plant

**Unpaid family work.** Family members get no wages; they live from what the farm sells and eats.

- Labour law (working hours, staffing) applies to COMPANY actors, and a family farm *is* a private company. A work
  inspector could find "overwork" on a family farm, and the stress tort could have the family suing itself.
- **Fix:** owner-operators (the household that owns the firm working in it) are outside employment law: no working-time
  violations, no stress torts against themselves. Safety law (hazards, accidents) still applies, because an inspector
  can close an unsafe farm.
- Hired non-family workers on a family farm would be ordinary employees. Bob doesn't hire any today.

**Crews moving with a sold plant.** A plant sold as a going concern takes its crew.

- In real law that's the transfer-of-undertakings rule: jobs move with the same terms, and no dismissal is allowed
  because of the sale.
- That matches Bob's design (no layoffs), but nothing protects it: the buyer could shed the crew the month after.
- **Fix:** a transfer rule. For 12 months after a sale, the buyer may not cut the transferred crew for reasons of the
  sale. A cut counts as an unlawful dismissal (a MINOR violation; a tort for the workers). Rule 4 (produce less) may
  still shrink crews for demand reasons after a notice period. Unions get a say through the existing union rules.

### 2.5 Creditors and insolvency against invoices, grant loans and loans that move with a plant

**Today.** When a firm is liquidated, **only the bank is paid** from what is left. Then:

- supplier invoices (E148) are written off separately;
- open fines and compensation (my liabilities) get nothing;
- unpaid wages get nothing.

There is no order of creditors in law.

**What collides.**

- E148 invoices: suppliers have no standing, so one firm's failure can quietly take down its suppliers, which is the
  credit chain the user wants to see.
- Grant loans (E160/E162): the bank lends against the grant and the plant. If the family defaults, is the state (which
  paid the grant) a creditor? Today, no.
- Loans moving with a sold plant (§3b, E152's pass_debt): the other creditors aren't asked.

**Fix: an insolvency order in law** (a new lever, LAW_CREDITOR_ORDER, with three settings):

1. **Today's order (default):** secured bank first, the rest pro rata.
2. **Workers first:** unpaid wages first, up to 3 months, as in most European law.
3. **State first:** fines, taxes and grant clawback ahead of suppliers.

The order would be:

- **Secured:** the bank on its collateral, i.e. the plant.
- **Preferred:** workers' wages (setting 2), or the state (setting 3).
- **Unsecured, pro rata:** suppliers, victims' compensation, fines.
- **Last:** the owners.

Also:

- **Late-payment interest** on overdue invoices: a lever, 0–2% a month.
- **Suppliers may petition** for liquidation, like my fine petitions today.
- **A plant that moves with its loan** needs the bank's consent (Bob's design has the bank choose; law says that is a
  condition of the sale).

### 2.6 Liability against wildlife deaths and plant sales

**Wildlife.** An attack kills workers on a farm or mine. Today the fact names no one responsible (nature), and the
politics blames the government a little. In law, two duties are missing:

- **The employer's duty of care.** Did the farm have the fences, guards or warnings the law requires? This needs a
  safety standard for outdoor sites (LAW_SAFETY_STANDARD already exists for plants; extend it to wildlife fencing).
  Under the M11 chain, a breach is a SAFETY_CORNERS violation with a tort for the families. On a family farm, the
  family is both employer and victim, so no tort; the grant programme's obligations decide instead.
- **The state's duty, under a PROTECT policy.** If the law forbids culling and a protected animal kills someone, the
  families can sue the state (a TORT against the government, like the police tort). This gives the wildlife policy a
  real legal cost and matches the political blame already in place.
- Victims are paid through the victims' fund as today.

**Licences when a plant is sold.** Licences are held per company. A plant sold to another firm loses its licence, or
keeps a licence that belonged to someone else, depending on the code path. **Fix:** a licence moves with the plant if
the buyer is fit (no revocation in 5 years, under the repeat ladder). Otherwise the buyer must reapply (the permit
office's normal wait).

### 2.7 Who may own shares, and what a stake gives

There's no law on this at all today. Firms are owned by one household, a co-op, the state or (for founders) the home
world's investors. E166 brings stakes (sold to raise cash), bank stakes and state stakes.

What law must say:

- **Who may hold shares:** households, firms, the bank (only up to a cap, only in a rescue, and sold within a term),
  the state, and home-world investors (only under LAW_INVESTOR_PRIVILEGES).
- **What a stake gives** (proposal):

  | stake | gives |
  |---|---|
  | below 25% | dividends only |
  | 25% and over | a blocking say on selling plants and the company |
  | over 50% | control: the board, so the CEO and the eight-rule choices |

- **Takeovers through shares** are mergers (2.2).
- **The media ownership cap** (LAW_MEDIA_OWNERSHIP_CAP) must count stakes, not just owners, or a firm can own a paper
  through a minority stake.
- **State stakes** follow the government's sale policy (E137) and count as public money: a state rescue without law
  is a ministry decision, but above a size it needs parliament (a state-aid rule).

## 3. What else is simply missing

- **Contract law for the order book** (E165Q2/Q3):
  - the deposit (paid at award, held by the builder);
  - the refund when the builder can't start within the quoted wait plus a grace period;
  - the cancellation fee (DECISIONS E30's progress + 5%, never coded);
  - price revision at the start date (today's escalation clause runs from award; the design wants revision at the
    start);
  - the builder's failure (half-built work, E169: the owner keeps the work and the deposit is a claim in the
    builder's insolvency).
- **Grant conditions** (E160/E162):
  - the grant's purpose (food for the district);
  - clawback if the plant is sold within N years (stops a family taking a grant and selling at once; fits E164's
    attachment rule);
  - and the loan as a contract.
- **Haulier licensing** (E172): an open entry licence, or CTA keeps a statutory freight monopoly until the law opens
  it. The existing LAW_TRANSPORT_OPERATION (public / franchise / open) could cover freight too, with one sentence of
  meaning; no new lever needed.
- **Regulated tariffs** (E150P): fine as a government action for now. Later, an independent regulator could be a lever
  (who approves: the minister or a regulator).

## 4. What I propose (Wilma's job 2), in order

These are the four Wilma gave me, plus the one collision that hurts now. All are design notes first; code only behind
Bob's flags and agreed with him, as for the quota.

1. **Road concession and retainer** (§3c, procurement): concession tender, direct awards under it, the retainer cap,
   termination, the unlawful no-tender award. It also makes LAW_DIRECT_AWARD_THRESHOLD real. Bob calls
   `ProcLaw.award_check(world, job, builder)` and `ProcLaw.concession_*`.
2. **Selling parts of a company** (§3b): one legal check for every sale. Bob calls
   `SaleLaw.check_sale(world, sale) → {ok, review, conditions}`, which covers:
   - competition (`request_takeover`);
   - the transfer of crews (the 12-month protection);
   - licences moving with the plant;
   - the bank's consent for loans that move;
   - family attachment and grant clawback.
3. **Order-book contract terms** (E165Q2/Q3): `ContractLaw.terms(world, job)` returns deposit, refund, cancellation fee,
   revision and penalties, with the defaults from DECISIONS E30.
4. **Share ownership** (E166): who may hold, what a stake gives (25% / 50%), bank and state stakes, takeovers through
   shares, media ownership counting stakes.
5. **Creditor order** (2.5): needed by 2 and 4, and it explains why one failure spreads (E148). It touches Bob's
   `_waterfall`, so it's a joint note.

The smaller ones can be done alongside, as fixes: gouging under district prices, owner-operators outside employment law,
the wildlife duty of care.

**New levers I expect:**

- LAW_CREDITOR_ORDER (3 settings);
- LAW_LATE_PAYMENT_INTEREST;
- LAW_CONCESSION_MAX_YEARS and LAW_RETAINER_CAP (or one concession lever);
- LAW_SHARE_CONTROL_PCT (the control stake, if the user wants it to be political; else a constant);
- possibly LAW_STATE_AID_THRESHOLD (state rescues above this need parliament).

Each has ideology rows for Wilma to review.

**New rules:**

- an unlawful direct award;
- an unlawful dismissal after a transfer;
- closing a sale that review has blocked (exists as CLOSE_BLOCKED_TAKEOVER);
- the employer's wildlife duty;
- a state-aid rule.

## 5. Added later the same day (Wilma's news, 2026-11-15)

- **Private roads:** a separate note, planning/design-law-private-roads.md. It has three levers (LAW_PRIVATE_ROADS,
  LAW_PRIVATE_ROAD_ACCESS, LAW_PRIVATE_TOLL_CAP), a road licence held by the Minister of Infrastructure, and the
  Cabinet for takeovers and expropriations.
- **Minister of Agriculture (flag AGRI_MIN):** with the flag on, the farm-side law decisions move from the Minister of
  the Economy to Agriculture:
  - the family-farm grant programme (E160/E162) and waiving its clawback (sales note §2.5);
  - the fencing cost in a farm grant (wildlife, small-fixes note §3).
  - ECO_WILDLIFE_POLICY stays with the Environment. Without the flag, nothing moves.
- **Rivalries (flag RIVALRY):** POL_DECISION_QUESTIONED gives the opposition a public voice on decisions. The law
  notes produce facts worth questioning:
  - LAW_TAKEOVER_OVERRIDDEN;
  - an overridden tender (ECON_CONTRACT_AWARDED `override`);
  - LAW_ROAD_OBJECTION_OVERRIDDEN;
  - a road licence refused with no ground;
  - LAW_ROAD_TAKEN_OVER;
  - ECON_STATE_STAKE.
  - Wilma may add them to rivalry's list. Questioning has no legal effect; the courts act only on cases.
- **Road facts:** POL_ROAD_PATCHED / PASSED_OVER / NEGLECTED are political. The law side meets them only on private
  roads: the neglect ladder (private-roads note §5) decides who is responsible for a neglected private road.
