# Design note: share ownership in firms (law side)

Anni, 2026-11-15. Job 2.4 from the law survey (§2.7), for Bob's rescues (E166) and §3b (a firm's last plant is sold as
its shares). Design only. **Agreed with Bob 2026-11-15** (with E166, on top of E174). Bob: o.shares replaces his draft o.owners (founder
included); one payout helper reads it at every payout site; stake buyers are households (I3–I5 with spare savings) and
profitable firms; the mandatory offer (§4) waits until after the first A/B.

## 0. Today

Each firm has a single owner:

- a household pool (`o.owner_group`), which gets the dividend (`EconAnnual.payout`, `EconBizSvc`);
- or a co-op;
- or the state (public enterprises);
- or, through the charter deal, a home-world investor (privileges, council seats).

There are no shares, stakes or minority owners, and no law on them. E166 (design) wants stakes sold to raise cash, bank
stakes and state stakes.

## 1. The share register

- Every private firm and co-op gets a **register**: `o.shares = {holder_key: pm}`, summing to 1000.
  - holder_key: `hh:<group>`, `co:<org>`, `bank`, `gov`, `home:<investor>`.
  - Today's firms start as `{"hh:<owner_group>": 1000}`, so nothing changes until someone sells a stake.
- **Dividends** are paid pro rata to the register. Bob's payout splits `spare` by pm, to the holders' accounts.
- **A public register:** holdings of 10% or more are public (fact LAW_STAKE_ACQUIRED / LAW_STAKE_SOLD), for the press
  and Ella. Smaller holdings stay private.

Co-ops keep their own rule: members own them, one member one vote. Outside stakes in a co-op are capped at 49% and
carry no votes, only dividends, so a co-op stays its workers'.

## 2. Who may hold shares

| holder | may hold | limits |
|---|---|---|
| **Households** | any firm | none |
| **Firms** | any firm | a stake in a rival (same market) is a concentration (§4) |
| **The bank** | only by a rescue: a debt-for-equity swap in E166's rescue window | at most **LAW_BANK_STAKE_CAP** (default 30%) per firm; must sell within **5 years**; no say beyond the blocking rights in §3 |
| **The state** | by a rescue (a bailout for shares) or nationalisation | §5 (state aid). Sold under the E137 sale policy |
| **Home-world investors** | only under the charter deal while LAW_INVESTOR_PRIVILEGES = 1 | revoking privileges (existing) also caps their stakes at 49% (sold down within 2 years) |
| **Parties, unions, media** | no stakes in ordinary firms | a party owning a firm is a hidden donation route. Unions may hold their own pension funds' stakes later, not now |

## 3. What a stake gives

| stake | rights |
|---|---|
| **any** | dividends pro rata; information (the firm's yearly accounts) |
| **25% and over** (blocking minority) | a veto on: selling plants (§3b) or the company; merging; a new share issue that would dilute it; changing the firm's sector |
| **over 50%** (control) | the board: appoints the CEO, so the firm's eight-rule choices; the payout policy |
| **75% and over** | may also force the minority to sell at a fair price (book value per share) |

- The thresholds are constants: 25 / 50 / 75 are the usual company-law numbers. A lever (LAW_SHARE_CONTROL_PCT) only if
  the user wants it political; I'd keep them fixed.
- **Who decides inside the firm:** the controlling holder decides, and blocking holders can stop the listed acts. Bob's
  firm AI asks `ShareLaw.may(world, org, act) → {ok, blocked_by}` before a sale, merger or new issue. A blocked act
  doesn't happen, and the fact LAW_STAKE_VETO is public if the blocker is the state or the bank.

## 4. Takeovers through shares

- Buying a stake that takes a **rival** (same market) to **25% or more**, or any buyer **over 50%**, is a concentration.
  It goes through the same `SaleLaw.check_sale` (merger review, failing-firm path), with the share of the target's
  market added to the buyer's.
- Creeping control (several small stakes adding up) is counted: the buyer's total holding decides.
- **Mandatory offer:** a buyer crossing 50% must offer the same price per share to all other holders, so minority
  households aren't left in a firm run for the buyer's benefit. Bob's mechanics: the offer is made, and holders accept
  if the price is ≥ book value per share (simple rule).

## 5. State stakes and state aid

A bailout for shares (E166's last resort) is public money for one firm.

- **Up to LAW_STATE_AID_THRESHOLD** (new lever, W_ref, default 20): the **Minister of Finance** may decide alone, on the
  Minister of the Economy's request. The fact ECON_STATE_STAKE is public.
- **Above the threshold:** the **Cabinet (First Minister)**.
- **Above 5× the threshold, or any utility or strategic firm:** **parliament** (a bill, like a budget line). The AI
  legislature votes on it as on any spending.
- **Conditions in law:**
  - the stake is at most what the money buys at book value per share (no gift);
  - the state takes the board seats its stake gives (§3);
  - the state sells under the E137 sale policy, by the Minister of Finance.
- **Without a stake** (a grant to a private firm, ECON_SUBSIDIZE): the same thresholds apply to who decides. A grant
  to a firm linked to a governing party (a donation in 24 months) is public, as for public plant sales.

## 6. Media ownership

LAW_MEDIA_OWNERSHIP_CAP (today counts owners) counts **controlling stakes in full and 25–50% stakes pro rata**. A firm
holding 30% of a paper's owner counts as 30% of that paper's circulation toward the cap. That closes the minority-stake
loophole.

## 7. Who decides (summary)

| decision | owner | alone? | goes higher when |
|---|---|---|---|
| A household or firm buys a stake below 25% | the parties to the sale | yes | never (registered if ≥ 10%) |
| A rival reaches 25%, or anyone over 50% | merger review: **Minister of the Economy** | as in the sales note | 70%+ or a utility market: **the Cabinet** |
| Bank debt-for-equity in a rescue | the bank (private) | yes, within LAW_BANK_STAKE_CAP | n/a |
| State stake / bailout | **Minister of Finance** | up to LAW_STATE_AID_THRESHOLD | above: **the Cabinet**; above 5× or a utility: **parliament** |
| Using the state's blocking or control rights in a firm | **Minister of Finance** (owner of state holdings) | yes | the sale of a controlling state stake: as for public plants (sales note) |
| The thresholds and caps (state aid, bank stake cap) | **parliament** (LAW levers) | no | a bill |

## 8. New law pieces

- **New:** ShareLaw (register, `may`, `on_transfer`), and facts LAW_STAKE_ACQUIRED, LAW_STAKE_SOLD, LAW_STAKE_VETO,
  ECON_STATE_STAKE (Bob's or mine, to agree).
- **Levers** (Wilma: ideology rows):
  - **LAW_STATE_AID_THRESHOLD** (0–100 W_ref, default 20): FISCAL −0.01 (a higher threshold means freer spending),
    INSTITUTIONS +0.01. Concerns: GOVERNANCE −4 / JOBS +3.
  - **LAW_BANK_STAKE_CAP** (0–49%, default 30): ECON_ROLE −0.1. Concerns: JOBS +2 / FAIRNESS −2.
- **Rules:**
  - PROHIBIT HOLD_STAKE for PARTY / UNION / OUTLET actors;
  - PROHIBIT STATE_AID above the threshold without the Cabinet's or parliament's decision. A minister who does it
    alone commits an unlawful act (unlawful_track, as the direct award).

## 9. Questions for Bob

1. The register as `o.shares` (pm per holder): fine in your org rows? Payout split pro rata: one change in
   `EconAnnual.payout` and `EconBizSvc`.
2. E166's order (plant sale → stake → bank → state): does the stake sale need buyers from households (savings) and
   firms both? I'd let both bid, with the merger check for rivals.
3. Do you want the mandatory offer, or is it too much mechanics for now? It can wait for a second step.

## 10. Tests (when coded)

1. A new firm is 100% its household; dividends are unchanged.
2. A 30% stake gets 30% of dividends and blocks a plant sale.
3. A rival reaching 25% goes to merger review.
4. A bank stake above the cap is refused; a bank stake is sold within 5 years.
5. A state stake above the threshold needs the Cabinet; above 5× it needs parliament; done alone, it's an unlawful act.
6. The media cap counts a 30% stake pro rata.
7. A party may not hold a stake.
8. Flag off: nothing changes.
