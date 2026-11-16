# Re-evaluation of Otto's switched-off systems: desk review (step 1)

Otto, 2026-11-16, on HEAD 3e20850. The order and the method are in planning/reeval-off-switches.md. This is step 1
only: unit tests, no game runs.

## How each switch was checked on v11

- **Syntax:** `--check-only` is clean on insolvency.gd, econ_plan_rescue.gd, econ_unfinished.gd, econ_builders.gd,
  econ_rules_housing.gd and firm_ai.gd.
- **Existing tests:** all pass on HEAD (test_plan, test_rescue, test_unfinished, test_builders, test_r8_housing,
  test_gated_commitments, test_builder_credit). Most of them switch their flags on alone, without the v11 defaults.
- **New test, game/tests/economy/test_offswitch_v11.gd (8 tests, all pass):**
  - each switch runs on top of EconSim.DEFAULT_ON, with any switches it needs, for 48 months on seed 1;
  - the run must differ from the same seed without the switch, which shows the switch is really read;
  - the switch's own counters must move, where it has counters;
  - the ledger must close and jobs must equal people.

  It takes 2 minutes 20 seconds.

**What the new test found, for each switch:**

| switch | added to v11 with | read on v11 | its counters after 48 months, seed 1 |
|---|---|---|---|
| E165 | – | yes | 14 plans opened, 2 dropped (no builder) |
| E165B | E165 | yes | 12 opened, 1 dropped as stalled, 212,520 credits written off by the bank |
| E165Q | E165, E165B | yes (60 → 59 orgs at month 48) | no counters |
| E155BLD | E165, E165B | yes (the run differs) | no counters |
| E166 | E165, E165B | yes | 5 rescue windows, 4 firm stakes, 1 plan saved itself |
| E169 | E165, E165B | yes | 4 shells left, 2 taken over for the same use |
| R8_BUILDERS | – (R8 is in v11) | yes | 2 builder entries passed, 3 blocked, 2 bids refused |
| R8_HOUSING | – | yes | no block built: 80 rounds where no district was full enough |

**Measures no judging run used:** none of these switches was judged on bank capital or on private firms alive over
60 years. The old A/Bs cover 30 years and, at most, firms alive and dead at year 30.

## The open problems these switches should be read against (from reeval-off-switches.md)

- (P1) The bank fails in 8 of 9 sixty-year games.
- (P2) Private manufacturing and mining are gone by year 5.
- (P3) Unemployment jumps when the bank's room hits zero: builders' crews fall from about 300 to 30–70 and public
  building stops.
- (P4) The public sector posts 60–80% of jobs.

---

## E165: the plan stage

- **Built to fix:** the user's ruling "a company that needs a building would not start without the building ... you
  can't fail before you exist". A new firm is a plan until its plant opens. A plan pays no wages, office or interest.
  A plan that stalls is abandoned, not liquidated, and is not counted as a firm death.
- **Judged by:**
  - E165 alone, early on 2026-11-15: 4779 → 4595 adults and half the bank's capital lost. The code header records
    this; the run itself is not in a planning file. E165B was added because of this result.
  - ab-r8-builders.md §5, HEAD 3a9b5d6, 10 seeds × 30 years, E165 + E165B against base12:
    - 4854 against 4739 adults;
    - unemployment 16.5 against 17.2%;
    - food shortfall 12.6 against 18.0‰;
    - private firms dead 45.0 against 68.6.
  - ab-r8-builders.md §6, HEAD 6039704, 10 × 30, with R8_BUILDERS, R8_FREIGHT and R8_MATERIAL:
    - −99 adults against r8;
    - best real income (3.28);
    - firm deaths 62.5 → 35.1.
  - ab-v11.md:
    - Bob, before the credit fix: ahead at 30 and 60 years (9046 against 8606 adults at 60 years).
    - Wilma, after the credit fix (a30bcc3): 4620 against 4840 adults. Seed 1 collapses to 2146 adults and 347‰
      hunger.
    - Bob's trace of seed 1: builders hold 15–20M of loans by years 7–9 against bank capital of 16M, builders' lost
      loans reach 23M, and the bank fails in year 13. That is why it is out of v11.
- **Works on v11:** yes (table above).
- **What it should move if it holds part of the answer:**
  - (P2) directly. It is the only one of my switches that has roughly halved private firm deaths in every A/B that
    measured them (68.6 → 45.0 and 62.5 → 35.1).
  - (P1) the other way. Plans hold the bank's lending room for years before they earn. Seed 1's collapse went through
    the bank, not through the plans themselves.
- **Only makes sense with:**
  - E165B, its loss-limiting half;
  - a bank that prices risk and stops lending to builders whose book cannot repay (Bob's bank build). Its one
    collapse was a bank failure.
- **Desk view:** a strong candidate for (P2). Screen E165 + E165B together, and screen them again on Bob's bank
  build. E165 alone has already been shown worse than with E165B and need not be screened alone.

## E165B: plan stage, safer version

- **Built to fix:** E165 alone cost 184 adults and half the bank's capital. E165B adds three things:
  - (a) no plan while every builder is booked;
  - (b) a plan dropped for want of a builder cools its sector for 12 months;
  - (c) the plan's bank loan is drawn only as the builder is paid, so a stall loses only what was built.
- **Judged by:** together with E165 in every run above. It was never judged on its own.
- **Works on v11:** yes. In the 48-month test it was the only switch to show a bank write-off (212,520 credits, one
  stalled plan). That write-off is the path that leads to (P1).
- **What it should move:** the bank's write-offs on plans should be smaller than with E165 alone. No run has measured
  that yet. The screen should report written_off from plan_stats next to bank capital.
- **Only makes sense with:** E165.
- **Desk view:** screen only as E165 + E165B.

## E165Q: builders' order books

- **Built to fix:** the user and Wilma, "firms queue work up: we do this in three months".
  - Builders quote a start date as well as a price.
  - A plan waits in a builder's book at no cost, instead of being dropped for want of a builder.
  - New builders enter when the books are long.
- **Judged by:** ab-r8-builders.md §6, 10 × 30:
  - −805 adults against the plan arm, below it on every seed;
  - founders see an 18.6-month wait and stop planning (6.3 plans against 24.3);
  - 6 private firms alive at year 30.
- **Works on v11:** yes.
- **What it should move:** (P2) the wrong way, as measured. Founders see a real queue and stay away. It holds part of
  the answer only if builder capacity stops being the bottleneck. That depends on builders' cash (§7 of
  ab-r8-builders.md: 80% of builders' blocked months are cash-limited), not on the order book.
- **Only makes sense with:** E165, plus builders who can grow. E155BLD was that partner, and it failed (below).
- **Desk view:** low priority for the screen. Screen it once with E165 + E165B on Bob's bank build, because a bank
  that lends builders working capital against their book could shorten the queue it reads.

## E155BLD: home-world builders

- **Built to fix:** a shortage of builders. Builders from the home world enter with 5 years of running costs in
  outside capital (new money) instead of a colony household's savings. It is the builder-only half of Bob's E155.
- **Judged by:** ab-r8-builders.md §6, with E165Q:
  - builders alive go from 2.7 to 10.1;
  - the quoted wait doubles to 35.8 months;
  - food shortfall reaches 57.5‰, with three seeds in hunger crisis (137, 188, 102‰).
  - More builders compete for the same material on thin cash.
- **Works on v11:** yes.
- **What it should move:** (P1) and (P3). Builders that bring their own capital need less from the bank and keep
  crews when the bank's room is zero. That is exactly the year unemployment jumps. It was never judged on either
  measure, only alongside E165Q.
- **Only makes sense with:** material supply that can follow demand (R8_MATERIAL is now in v11; at §6 it was in the
  arm too, so this was already tested). Also without E165Q, which it was only ever run with.
- **Desk view:** worth a screen alone on v11. The reading that matters is builders' crews and unemployment in the
  years when the bank's room is zero, plus food shortfall, which it hurt last time.

## E166: rescues for plans in trouble

- **Built to fix:** plans that fail half-built. Buyers take stakes, the bank tops up, or the state steps in, before
  the plan is abandoned.
- **Judged by:** ab-r8-builders.md §5, HEAD 3a9b5d6, 10 seeds.
  - First version: −188 adults against plan, food shortfall doubled, and 9% of rescued plans alive 36 months later.
  - Stricter version, E166B + E166T: −15 adults (near-neutral), 7 rescues.
  - The current code is that second version, recorded in design-e166-e169.md under "Second version". Its test of
    profit is EconForecast.first_year, a stub that sees no profit in plans in trouble. So it rescues almost nothing
    until Bob's E170 forecast is real.
- **Works on v11:** yes: 5 windows and 4 firm stakes in 48 months on seed 1.
- **What it should move:** (P2) a little, by saving good plans. The trace found that a plan in trouble is almost
  always a bad plan, so its upside is small. Its risk is (P1): the bank tops up plans in trouble.
- **Only makes sense with:** E165 + E165B, and Bob's E170 forecast. Without E170 it is close to a no-op.
- **Desk view:** screen only after E170 exists. A screen now measures the stub.

## E169: half-built buildings

- **Built to fix:** the user, "half-built buildings should be able to be repurposed to a new company".
  - A project ended with work done leaves an unfinished shell.
  - The next plant project of the same district takes it over: all the work counts for the same use, half of it for
    another use.
  - The money goes to the holder, the bank first, up to its write-off.
- **Judged by:** ab-r8-builders.md §5, 20 seeds × 30 years, on E165 + E165B:
  - −29 adults (noise);
  - builders lose work, because a takeover tenders only the remaining work;
  - 69% of shells decay unsold.
- **Works on v11:** yes: 4 shells left and 2 taken over in 48 months.
- **What it should move:** (P1) a little. The bank recovers part of its write-offs (bank_recovered in e169_stats), and
  only where plans fail, so it needs E165. It also costs builders some work, which touches (P3).
- **Only makes sense with:** E165 + E165B. Without plans few projects end half-built. It will also become part of the
  empty-buildings market the user ordered on 2026-11-16 (E176: one market for empty buildings and shells; plan sent to
  Wilma).
- **Desk view:** screen it on top of E165 + E165B, not alone. Alone it measures almost nothing.

## R8_BUILDERS: builders under the eight rules

- **Built to fix:** builders that bid at a loss, grew crews they could not pay, and entered while incumbents starved.
  Under it:
  - builders keep their own margin;
  - clients and the government can refuse a bid;
  - crews grow beyond 2× only with a long book and a profitable year;
  - entry is held while incumbents lose money;
  - there are public builders.
- **Judged by:**
  - ab-r8-builders.md §4, base11, 10 × 30: +108 adults, real income best, failed tenders −38%.
  - ab-v11.md, line 20, Bob, before the credit fix: "with R8_BUILDERS added the colony collapses over 60 years (3932
    adults, 206 permille): out". That run has no trace. Why it collapsed is not known.
  - Since then builders have gained material on the yearly line (5a55d61) and supplier credit at the order (a30bcc3).
    Neither was in the run that collapsed.
- **Works on v11:** yes: entries passed and blocked, and bids refused, in 48 months.
- **What it should move:**
  - (P3) and (P1) directly. Builders that refuse loss-making jobs and grow crews only on a profitable book should carry
    fewer lost loans to the bank. Builders' lost loans were 5M in seed 2 and 23M in seed 1 of the plan arm.
  - Its risk: refusals slow public building, and its entry rule holds new builders out exactly when the bank is short.
- **Only makes sense with:** the builder cash fixes still to test (the client pays for material as delivered;
  working capital against the book; both queued from §7). It also has a seam with Bob's builder allowance frozen at
  signing, which is about value bids.
- **Desk view:** the 60-year collapse is the reason it is out, and it has never been explained. In the screen, report
  bank capital, builders' lost loans and builder crews by year. Without those numbers the screen can say only that it
  is worse, not why.

## R8_HOUSING: housing under the eight rules

- **Built to fix:** E120 builds a housing block once a quarter whether or not it pays. Under R8_HOUSING a developer
  builds a block only if forecast rent covers the costs and the bank lends, the most profitable district first.
- **Judged by:** ab-r8-housing.md, HEAD a563d55, 10 × 30.
  - On R8 alone: +17 adults, unemployment −1.9 points, food shortfall −8‰, real income +0.55, 140 more homes.
  - On the v11 candidate of that night, with E165 + E165B and R8_BUILDERS: unemployment +1.9 points, food +10‰,
    fewer homes. Plans held the bank's room, and 6 of 10 seeds refused most blocks for want of a loan.
  - The arm it won on (R8 alone) is close to today's v11, apart from the food, freight and material rules.
- **Works on v11:** yes, but in 48 months on seed 1 no district was full enough to build (80 rounds of "no_empty").
  It acts later and on crowding, so 30–60 years is the right horizon.
- **What it should move:** (P3), a little. Private building that pays keeps builders' crews working. (P4) a little:
  private homes instead of public ones. (P1) through housing loans that are repaid from rent.
- **Only makes sense with:** a bank that decides who gets its room when it is short, plans or housing (Bob's bank
  build). It won without the plan stage and lost with it.
- **Desk view:** screen it alone on v11. Its best earlier result came without E165, which is v11's case.

---

## What the screen should report for my switches (beyond Wilma's list)

- **Plan switches (E165, E165B, E165Q, E166, E169):**
  - plan_stats: plans, opened, the abandoned counts by cause, written_off;
  - bank capital and builders' lost loans, by year.
- **Builder switches (R8_BUILDERS, E155BLD):**
  - builders alive, builders' crews and builders' lost loans, by year;
  - failed tenders.
- **R8_HOUSING:** homes, households, occupancy of the worst district, and r8h_stats (blocks built, refusals by
  cause).

## Combinations I would name for step 3

1. E165 + E165B, then + E169, on v11 and on Bob's bank build.
2. R8_BUILDERS alone, then with the builder cash fixes once they are tested.
3. R8_HOUSING alone; then with E165 + E165B on Bob's bank build only.
4. E155BLD alone.
5. E165Q and E166 wait. E165Q needs builder capacity to stop being the bottleneck; E166 needs Bob's E170 forecast.
