# Design note: selling parts of a company (law side)

Anni, 2026-11-15. Job 2.2 from the law survey (§2.2, §2.4, §2.5, §2.6), for Bob's §3b (planning/eight-rules.md).
Design only. **Agreed with Bob 2026-11-15; flag E174** (with the creditor order; R8's rule 6). Bob's answers: market shares
from `EconRules.market_share_pm(world, org, good, district)` (reachable market; call it with the buyer owning the plant for
"after"); per-plant `orders` EMA in `st.r8.plants`; in a distressed sale the price lands in the seller's account, then
`SaleLaw.closed`, then the waterfall (creditor order).

## 0. Today

- Plants change hands in five ways, all in Bob's code and none of them with a law check:
  - liquidation sales (`_find_buyer`, same-sector buyers preferred);
  - E91 forced sales;
  - worker buy-outs (E77);
  - nationalisation of strategic plants;
  - E137 reprivatisation.
- The merger review exists (`competition_law.request_takeover`: authority review, office item to the Minister of the
  Economy, AI decision by ECON_ROLE, CLEARED / CONDITIONS / BLOCKED, CLOSE_BLOCKED_TAKEOVER prohibited). **Nothing calls
  it.**
- Licences are held per company. Loans move with a plant only in a worker buy-out and in E91 whole-company sales.
- Nothing protects a crew that moves with a plant.

## 1. One check for every sale

Bob calls one function before a sale closes, whatever the path (rule 6 voluntary, E166 rescue, liquidation, E91, E164
family, E169 half-built, §3c public builder parts, E137):

```
SaleLaw.check_sale(world, sale) -> {ok, status, review_id, conditions, reasons, clawback, licence, crew_protect_until,
                                    needs_bank, decided_by}
sale = {seller, buyer (org id | "NEW:<household>" | "gov" | "coop:<...>"), plant(s) [fac ids], goods, path,
        seller_state (ACTIVE|DISTRESSED|ADMINISTRATION|LIQUIDATION), price, crew, loans [ids], market_share_before_pm,
        market_share_after_pm, market, jobs, invest, last_plant: bool}
status: CLEARED | REVIEW (wait for review_id) | CONDITIONS | BLOCKED | REFUSED (a legal bar; reasons say which)
```

Once review is done, `SaleLaw.sale_status(world, review_id)` returns the same shape. `SaleLaw.closed(world, sale)` is
called when the sale completes: it writes the facts and starts the crew protection.

## 2. What the check decides

### 2.1 Competition (the merger review, finally called)

- **Who is reviewed:** any buyer already active in the same market (good and district set, as competition law defines
  it; Bob gives the share before and after, ‰ of the market's sales).
- A new firm, a founder, a workers' co-op, a family or the state buying is **not a concentration**: cleared at once.
- **Below LAW_MERGER_THRESHOLD:** cleared at once, as `request_takeover` does today.
- **Above it:** review, 3–6 months by the competition budget. The authority recommends APPROVE / CONDITIONS / BLOCK
  (as coded).
- **Failing-firm path** (new): when the seller is in ADMINISTRATION or LIQUIDATION, or in an E166 rescue window, the
  review is **1 month**. The recommendation is APPROVE unless share after ≥ BLOCK_FROM_PM (70%), and then CONDITIONS,
  not BLOCK. Real law clears failing-firm deals when the alternative is closure. The plant matters more than the
  rivalry.
- **Conditions** (existing CONDITIONS: sell a plant, cap prices for two years): for a plant sale, "cap prices for two
  years" means the buyer's district price for the good may not rise above the pre-sale price × CPI for 24 months. That
  is a check Bob's rule 1 calls (`SaleLaw.price_cap(world, org, good, district)`).
- **Closing a blocked sale:** unlawful (the existing CLOSE_BLOCKED_TAKEOVER). Bob simply doesn't close it.

### 2.2 The crew (transfer of undertakings)

- The crew moves with the plant on the same pay, as Bob's design says (`crew_protect_until` = month + 12).
- **For 12 months**, cutting a transferred worker because of the sale is **unlawful dismissal**:
  - a MINOR violation, kind UNFAIR_DISMISSAL (new greed kind, channel LABOUR, the work inspectorate's);
  - a tort for the workers (a month's wages each, through the existing TORT path).
- Rule 4 (produce less) may still shrink a protected crew for demand reasons, with **3 months' notice** (a notice
  record). Only "because of the sale" is unlawful. Practically: cutting the crew within 12 months with demand (orders
  EMA) not below its level at the sale is presumed unlawful; cutting it with demand down is lawful after notice.
- **Unions:** a recognised union in the plant must be told (fact LAW_TRANSFER_NOTICE). It has no veto.

### 2.3 Licences

- A licence moves with the plant to a **fit** buyer: no licence revoked and no SEVERE conviction in the last 5 years.
  The licence's expiry is unchanged.
- An unfit buyer must reapply: the plant may not run until the permit office grants it (its normal wait).
- A suspended licence moves suspended (the suspension isn't washed by a sale).
- **A sale to escape a revocation** (a firm convicted twice, selling its plants to a related buyer before the third
  conviction) is caught by counting convictions per plant, not only per firm: the plant's record goes with it for the
  repeat ladder.

### 2.4 Loans and creditors

- A loan secured on the plant moves only with the **bank's consent** (`needs_bank: true`). Bob's design has the bank
  choose between moving the loan and repayment from the price; law makes that consent a condition.
- **The price goes to creditors first in a distressed sale:** ADMINISTRATION or LIQUIDATION proceeds go through the
  creditor order (the joint note with Bob, job 2.5), not straight to the owner.
- **A sale below the floor by a distressed seller to a related buyer** (the owner's household, or a firm it owns) is a
  **transaction at undervalue**:
  - voidable by the creditors;
  - a SERIOUS violation, kind ASSET_STRIPPING (new greed kind, channel AUDIT).
  - This closes the "sell the plant cheap to my cousin before the firm fails" gap.

### 2.5 Families and grants

- Family attachment (the 3-in-4 rule) is Bob's mechanics. The law adds a **grant clawback**: a family plant built with
  a grant (E160/E162) and sold by choice within **5 years** of opening repays the grant pro rata (100% in year 1, 20%
  in year 5) to the treasury from the price.
- **Forced sales** (distress, a grant-loan default) owe no clawback.
- Families' **first right to buy** at the floor in forced sales (E164) is lawful as a public grant condition. No rule
  needed, but the check reports it (`reasons: ["FAMILY_FIRST"]`) so the chronicle can say why.

### 2.6 Public plants

- A public plant is sold only under the government's sale policy (E137):
  - **Minister of Finance** for ordinary public plants (proceeds to the treasury);
  - the sale is **refused** (status REFUSED, reason PUBLIC_POLICY) when the government's policy is to keep it;
  - utilities (POWER, WATERWORKS, DEPOT) need **the Cabinet (First Minister)** and are refused while the colony is
    short of them (Bob's rule, as a legal bar);
  - a public builder's parts (§3c b): **Minister of Infrastructure** with the Minister of Finance's consent on the
    price (a sale below 60% of book needs the Cabinet).
- **A sale to a buyer linked to a governing party** (a firm that donated to it in the last 24 months) is lawful, but
  public (fact LAW_PUBLIC_SALE_LINKED_BUYER), for the press and Ella.

### 2.7 The last plant

- Selling a firm's last plant is a sale of the company. That goes through share ownership (job 2.4); check_sale
  returns REFUSED with reason LAST_PLANT_USE_SHARES.

## 3. Who decides (minister, alone or not)

| decision | owner | alone? | goes higher when |
|---|---|---|---|
| Clearance below the threshold, failing-firm approvals | the competition authority (LAW) | yes | never |
| Merger review decision (above threshold) | **Minister of the Economy** (office item to ECON_ADVISER, as coded) | yes | share after ≥ 70% or a utility market: **the Cabinet (First Minister)** (a CALL item, as coded for big shares) |
| Overriding the authority's recommendation | **Minister of the Economy** | yes, but a public fact (LAW_TAKEOVER_OVERRIDDEN, as coded) | n/a |
| Sale of an ordinary public plant | **Minister of Finance** | yes | below 60% of book: **the Cabinet** |
| Sale of a utility or strategic plant | **the Cabinet (First Minister)** | no | a sale policy reversal needs parliament (E137's lever) |
| Selling a public builder's crew | **Minister of Infrastructure** + Finance on price | yes | below 60% of book: **the Cabinet** |
| Waiving a grant clawback | **Minister of the Economy** (grant programme owner) | yes, up to 2 W_ref | above: **Minister of Finance** |
| Licence transfer to a fit buyer | the permit office (civil service) | automatic | n/a |
| Voiding a sale at undervalue | **the courts** (on a creditor's or the AUDIT channel's case) | n/a | n/a |
| Merger threshold, dominance share, transfer protection months | **parliament** (LAW levers) | no | a bill |

Most sales never reach a minister: only reviewed mergers (Economy), public plant sales (Finance) and the big ones (the
Cabinet).

## 4. New law pieces

- **Greed kinds:** UNFAIR_DISMISSAL (LABOUR, MINOR) and ASSET_STRIPPING (AUDIT, SERIOUS).
- **Rules:** PROHIBIT DISMISS_TRANSFERRED (within the protection, demand not down); PROHIBIT SELL_AT_UNDERVALUE_RELATED
  (distressed seller).
- **Lever** (optional, else a constant): LAW_TRANSFER_PROTECTION_MONTHS (0–24, default 12): ECON_ROLE +0.5 per month
  (state-minded want longer). Concerns: JOBS +4 / FAIRNESS +3 vs GOVERNANCE −1.
- **Facts:** LAW_TRANSFER_NOTICE, LAW_PUBLIC_SALE_LINKED_BUYER, LAW_SALE_VOIDED. The takeover facts already exist.
- **The repeat ladder** counts per plant as well as per firm.

## 5. Questions for Bob

1. Can you give `market` and the shares before and after in your terms (good × reachable districts)? Or should
   competition law compute the shares from your sales EMA?
2. A protected crew: is "orders EMA not below the level at the sale" a signal you can expose per plant?
3. In a distressed sale, does the price land in the seller's account today (then the waterfall), or is it paid out
   directly? I need the hook for the creditor order.

## 6. Tests (when coded)

1. A same-market buyer over the threshold is reviewed; a new entrant is cleared at once.
2. Failing-firm review takes 1 month and approves unless share is 70%+.
3. Conditions cap the district price for 24 months.
4. A transferred worker cut within 12 months with demand flat is an UNFAIR_DISMISSAL record and a tort. With demand
   down and notice given, it is lawful.
5. A licence moves to a fit buyer, not to an unfit one; a suspension moves.
6. A family plant sold by choice in year 2 repays 80% of the grant; a forced sale repays nothing.
7. A distressed sale to the owner's household below the floor is ASSET_STRIPPING.
8. A utility sale needs the Cabinet and is refused while short.
9. Flag off: nothing changes.
