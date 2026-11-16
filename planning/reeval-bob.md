# Re-evaluation of Bob's switched-off systems: desk review (step 1)

Bob, 2026-11-16, on the tree of cee7f20 (3e20850 + the bank build). The order and the method are in
planning/reeval-off-switches.md. This is step 1 only: the code, the records and a 48-month read-test, no game runs.

## How each switch was checked on v11

- **Syntax:** `--check-only` is clean on every file that reads these switches.
- **Where it is read:** every switch was found by its quoted name in game/sim; the file and line are given below.
- **New test, game/tests/economy/test_offswitch_bob.gd (30 tests):**
  - each switch runs on top of EconSim.DEFAULT_ON, with any switch it needs, on seed 1;
  - 48 months in the economy-only game; E151 and E171 run 36 months in the full game, because the legislature and
    the charter law are not in the economy-only game;
  - the run must differ from the same seed without the switch (firms by status and the cash of every firm), which
    shows the switch is really read;
  - the ledger must close and jobs must equal people.

  First run: 26 switches read, 4 no change (E139, E168, E171, S7C; the reasons are below). The test now records
  those four as "still inert", so a code change that wakes one shows up. It takes about 10 minutes on the loaded
  machine.

**The read-test after 48 months, seed 1 (one seed, one short run: a sign of life, not a result).** Without the switch:
18 private firms alive, bank capital 15,938k (full game: 16 and 15,774k).

| switch | private firms alive | bank capital (k) | | switch | private firms alive | bank capital (k) |
|---|---|---|---|---|---|---|
| E136 | 20 | 15,657 | | E156 | 18 | 15,976 |
| E137 | 27 | 15,261 | | E168 | inert | |
| E138 | 21 | 15,480 | | E171 | inert | |
| E139 | inert | | | S7 | 18 | 15,938 (path differs) |
| E140P | 20 | 15,300 | | S7F | 14 | 15,356 |
| E143 | 19 | 14,997 | | S7C | inert | |
| E150B | 18 | 15,933 | | SUPPORT_B | 16 | 15,467 |
| E150C | 21 | 15,023 | | SUPPORT_C | 24 | 15,039 |
| E150P | 26 | 16,496 | | SUPPORT_D | 17 | 14,957 |
| E151 (full) | 18 | 15,394 | | SUPPORT_E | 17 | 14,679 |
| E152 | 18 | 16,687 | | SUPPORT_S | 25 | 15,776 |
| E153 | 13 | 15,287 | | INV_EXPECT | 14 | 15,512 |
| E155 | 18 | 11,742 | | EXP | 18 | 15,128 |
| R8M_PX | 21 | 15,338 | | EXP_PORT (+EXP) | 20 | 15,653 (EXP alone: 15,128) |
| R8M_NOVALUE | 14 | 15,806 | | EXP_KEEP (+EXP) | 13 | 15,030 (EXP alone: 15,128) |

**Measures no judging run used:** none of these 30 was judged on bank capital or on private firms alive over 60 years.
Only R8M_PX / R8M_NOVALUE (ab-r8-materials.md) and SUPPORT_D/E (plan-support-economy.md §10) have a run table in a
planning file; every other record is a line in the code or a commit message. 14 of the 30 have no run recorded at all.

## Defects found (fixes are mine, after Wilma's suite on cee7f20; no behaviour change while meta "off" is empty)

- **meta "off" does not win** (the standing rule) for E150B, E150C, E150P (econ_public_co.gd:42, :46, :153), E156
  (econ_staple.gd:70), R8M_PX (econ_rules_mat.gd:59), PAYOUT (econ_finance.gd:602), R8_MATERIAL in
  EconRules.sector_on (econ_rules.gd:54), and FREIGHT_ROADS at econ_market.gd:164 and econ_rules.gd:161 (Terra's
  finding; the fix is FreightRoads.on(world)). E155: firm_ai.gd:1073 ORs in E155BLD with no off check.
  R8M_NOVALUE is a kill switch read from "on" only; listing it in "off" does nothing, which is correct for a kill switch.
- **E139 is dead on v11.** In _update_prices (econ_market.gd:362-386) E149 cost-plus (DEFAULT_ON) replaces the price
  after E139 has set it, on every good except FOOD, and FOOD is exempt from E139. Nothing E139 does survives.
- **E171 is dead in games.** Nothing in game/sim calls CharterOps.record_delivery; only test_charter_quota.gd does.
- **E150P has no one to say yes.** Tariff rises become proposals, but no AI code issues ECON_APPROVE_TARIFF (only the
  player's action list has it). Under an AI government every rise waits for ever. That is not a fair arm until the
  government decides on them.
- **E138 is dead when R8_BUILDERS is on** (econ_construction.gd:652/690). Fine on the v11 base, where R8_BUILDERS is
  off; it matters for Otto's arms.
- **EXP_KEEP does not need EXP** in the code (econ_trade.gd:469 needs only R8), although it was designed and planned
  with EXP. It works alone.

## The open problems these switches are read against (from reeval-off-switches.md)

- (P1) The bank fails in 8 of 9 sixty-year games.
- (P2) Private manufacturing and mining are gone by year 5.
- (P3) Unemployment jumps when the bank's room hits zero.
- (P4) The public sector posts 60-80% of jobs.

What has been measured since the list was made:
- **Wilma's off-world investor test** (scratch copy of 3e20850, 3 × 60 years, a flat sum into the bank at every ship;
  table in reeval-off-switches.md): with 1M or 2M a ship the bank lives on all three seeds. Where the base bank died
  (seeds 2 and 3) unemployment fell 33.3 → 23.3/22.0 and 29.6 → 15.8/14.5, and food shortfall 24 → 15 and 43 → 5.
  Firm deaths and builder deaths did not fall in any arm.
- **design-bank.md:** firms mostly die with no market (about half) and 35-50% before their first sale; only 1-8 a game
  die of debt.

So two kinds of switch may hold part of the answer. Those that keep the bank alive go to P1 and P3. Those that give a
young firm a market or time to find one go to P2. A switch that only moves money between the bank and firms is not
expected to change firm deaths.

---

## E136: start-up grace on the build loan

- **Built to fix:** "new mines, processing plants and workshops died at 8-13 months under a build loan they could not
  yet service". A firm still FORMING pays interest only for START_GRACE_M months (econ_finance.gd:52-54).
- **Judged by:** the v9 per-flag check, arm "private" = E136+E137+E138 together, 5 seeds × 30 years on the v8 base
  (tools/v9_check.sh:5). Verdict (econ_sim.gd:36-37): "lowest real income; wait for the private-firm work". No numbers
  recorded. Never run alone.
- **On v11:** read (econ_finance.gd:54, off wins). Read-test: 18 → 20 alive, capital −281k.
- **Should move:** P2 (deaths before the first sale). The bank's interest on young firms falls; capital should not.
- **Depends on:** only FORMING borrowers. It has never been judged without E137 and E138, which changed far more.
- **For the screen:** alone. If it keeps firms alive, with the bank build's BANK_RISK (which charges new firms more).

## E137: who expands the economy follows the government's ideology

- **Built to fix:** "private-firm diagnosis cause 3, crowd-out": the government builds what private firms would have
  built. Who expands is chosen by ideology (ECON_PUBLIC_OWNERSHIP_POLICY, else ECON_ROLE) (econ_ownership.gd:3-20).
- **Judged by:** the same v9 "private" arm; no numbers.
- **On v11:** read (econ_ownership.gd:20, off wins). Read-test: 18 → 27 alive, the largest change of the 30;
  capital −677k.
- **Should move:** P4 directly (fewer public posts, more private ones) and P2.
- **Depends on:** the ownership lever; the sale-policy designs (eight-rules.md, design-law-company-sales.md) build on it.
- **For the screen:** alone, read on the public share of jobs as well as the usual columns.

## E138: the main builder's crews grow with its backlog

- **Built to fix:** "the colony's main builder sat at 2× its founding crew (160) with 5-15 projects … crews may now
  grow to 5× with the backlog" (econ_construction.gd:697-699).
- **Judged by:** the same v9 "private" arm; no numbers.
- **On v11:** read (off wins). Read-test: 18 → 21 alive, capital −458k. Dead when R8_BUILDERS is on.
- **Should move:** building speed, so P3 both ways: larger crews when the bank lends, a deeper fall when it stops.
- **Depends on:** R8_BUILDERS off.
- **For the screen:** alone and with the bank alive (Wilma's investor arm), because the risk is the crash after the boom.

## E139: contestable prices

- **Built to fix:** "a sole producer makes just what sells … CONSUMER ran at 2-6× its unit cost"; in a fully
  supplied market the price drifts towards CONTEST_MARK × the cheapest producer's full cost (econ_market.gd:358-363).
- **Judged by:** 5 seeds × 30 years, v8: with FOOD included the food shortfall rose 31 → 42‰ (econ_market.gd:428).
  FOOD was then exempted. Left off: "A/B showed no real-income gain" (commit 185d15d). eight-rules.md:134 says R8
  rule 2 absorbs it.
- **On v11:** **dead.** E149 cost-plus (on since v9) overwrites its price on every good it covers. Read-test inert.
- **Verdict proposed:** off, superseded by E149 and R8. No screen run is needed; the test records that it is inert.

## E140P: owners paid once a year

- **Built to fix:** owners are paid once a year after the annual accounts, keeping KEEP_M months of costs plus the
  investment still owed (econ_annual.gd:4, :18-19).
- **Judged by:** the v9 per-flag check, 5 × 30 years on v8: E140 went on "without E140P, the yearly payout, which
  cost adults" (econ_sim.gd:34-35). No numbers.
- **On v11:** read (econ_annual.gd:36, off wins). Read-test: 18 → 20 alive, capital −638k.
- **Should move:** firms' own cash, so P2 (fewer firms short of cash in a bad month) and less household money.
- **Depends on:** E140 and PAYOUT, both on.
- **For the screen:** alone. Read household money as well: the old loss in adults probably came from money held back.

## E143: whole-person office hiring for small firms

- **Built to fix:** "a small firm's office of 0.45 G + 0.09 S stayed empty for ever and its fill of 0 stopped the
  plant" (econ_office.gd:139-142).
- **Judged by:** "A/B 5 × 30 y: neutral (adults +31, private alive +3.4)" (econ_office.gd:142). No base named. Left
  off in v10 without a reason.
- **On v11:** read (off wins). Read-test: 18 → 19 alive, capital −941k.
- **Should move:** P2. It is one of the few switches aimed at a small firm's own failure, not its money.
- **Depends on:** SUPPORT_A offices (on).
- **For the screen:** alone. Its old result was the one positive firm count on record; the 60-year run is missing.

## E150B: a public utility keeps enough cash

- **Built to fix:** the seed-3 collapse: the PE dividend took half of each quarter's profit down to one month of
  costs, so the water utility lived below half a month of cash and still cut its tariffs (econ_public_co.gd:27-35).
- **Judged by:** commit 7a2f2ce: "60-year result on seeds 1-3: food shortfall 82 -> 34 -> 8 permille, seed 3 no
  longer collapses". The arms of the three steps are not labelled. No reason recorded for leaving it off.
- **On v11:** read, but meta "off" does not win (fix listed above). Read-test: 18 → 18, capital −5k: nearly nothing
  in 48 months on seed 1, which fits a fix aimed at a seed-3 collapse.
- **Should move:** food shortfall in a utility crisis; not the bank or firms directly.
- **Depends on:** E150 (on).
- **For the screen:** alone, read first on seed 3.

## E150C: a utility's support is never cut below its payroll

- **Built to fix:** the E44 support of a utility is never capped below its payroll (econ_public_co.gd:35).
- **Judged by:** possibly one of the unlabelled steps in 7a2f2ce; no separate record.
- **On v11:** read; meta "off" does not win. Read-test: 18 → 21 alive, capital −915k.
- **Depends on:** E150; designed on top of E150B.
- **For the screen:** E150B+E150C as one arm, and E150C alone.

## E150P: tariff rises are proposals

- **Built to fix:** tariff rises are decided by the government (econ_public_co.gd:151-152).
- **Judged by:** no run recorded.
- **On v11:** read; meta "off" does not win. **No AI government approves a rise** (no AI issues
  ECON_APPROVE_TARIFF), so with it on the tariffs stay frozen in any AI game. Read-test: 18 → 26 alive, capital
  +558k. That is what frozen tariffs look like (cheaper power and water for firms, utilities paying for it), not a
  sign that the switch works.
- **Verdict proposed:** needs the government's decision first (an AI rule to approve or refuse a rise). Until then a
  screen run measures frozen tariffs, not E150P. This is a feature and waits for the user.

## E151: the treasury aims at 6 months of spending

- **Built to fix:** "the treasury held 19-68% of all colony money because governments read any runway under 24
  months as fiscal stress"; a two-sided target: 6 months is comfortable, under 2 is stress (legislature.gd:119-128;
  money-audit.md:45).
- **Judged by:** no numbers recorded. v10 verdict for E151-E155 together: "money arms: starve the colony until supply
  responds" (econ_sim.gd:43-44). Queued and never run: J4 in remote-tests.md, 10 × 60.
- **On v11:** read (off wins), in the full game only. Read-test (full game, 36 months): 16 → 18 alive, capital −380k.
- **Should move:** household money and public spending; P4 both ways (more spending, more public posts).
- **Depends on:** the old verdict was that the money arms need supply that answers. v11 has the eight rules for
  freight, materials and food, so that condition has changed.
- **For the screen:** alone and in the five money arms together.

## E152: a sound bank

- **Built to fix:** interest +19/+12 against write-offs −26/−19 on seeds 1/3 over 60 years. It (a) reschedules
  workouts instead of writing them down, (b) makes a co-op buy-out take the plant's share of the bank debt, (c) sends
  nothing home while capital is below the floor (econ_money.gd:5-11).
- **Judged by:** no A/B recorded; the v10 money-arms verdict. The only test that switches it on checks the ledger.
- **On v11:** read (off wins). Read-test: 18 → 18 alive, **capital +749k**, the largest gain of the 30.
- **Should move:** P1 directly; through a living bank, P3. Wilma's investor test values a living bank at 10-15 points
  of unemployment on the seeds where it died.
- **Depends on:** nothing. The bank build's BANK_CAP uses the same floor on remittance.
- **For the screen:** first in line for P1. Alone; then with BANK_RISK and BANK_SEC (the losses), because E152 only
  stops money leaving and delays write-offs.

## E153: credit lines against what a firm owns

- **Built to fix:** the E140 line's limit becomes a share of stock, receivables and expected sales instead of a
  profitable year (econ_money.gd:12-14). The code uses expected sales only when INV_EXPECT is on; otherwise the past
  average (econ_money.gd:108).
- **Judged by:** no A/B recorded; the money-arms verdict. design-bank.md plans "security alone, with E153 on".
- **On v11:** read (off wins). Read-test: **18 → 13 alive**, capital −651k, the worst firm count of the 30.
- **Should move:** P2, in principle: young firms with stock and no profit get a line. On seed 1 it went the other way;
  more credit to firms that then die is what design-bank.md warns about.
- **Depends on:** E140, E148, INV_EXPECT (for the expected-sales part); with the past-average part it breaks the
  user's ruling "no limit built on past sales". It should be judged with INV_EXPECT, not without.
- **For the screen:** E153+INV_EXPECT as the arm; E153 alone only as the reference.

## E155: founding firms bring five years of costs

- **Built to fix:** the user: "a company going to a colony would have 5 years of costs calculated and saved before
  going". The founding private firms and co-ops arrive with their running costs in cash from the home world and
  without start-up loans (econ_money.gd:114-122; the builder half at firm_ai.gd:1071-1073).
- **Judged by:** no E155 A/B recorded; the money-arms verdict. Its builder half E155BLD: ab-r8-builders.md §6, kept
  off (Otto's review).
- **On v11:** read (off wins in econ_money.gd; not at firm_ai.gd:1073 when E155BLD is on). Read-test: 18 → 18,
  **capital −4,196k**: with no start-up loans the bank has 4M less lent out, so less capital by the bank's own
  measure (capital = balance + loans). Fewer loans also mean fewer write-offs later; 48 months cannot show that.
- **Should move:** P2 for the founding firms only (they cannot fail for debt in their first years), P1 later.
- **For the screen:** alone, 60 years; read bank capital at Y60, not Y4.

## E156: bakeries cut a bread price that prices people out

- **Built to fix:** the user: "1000 orders at 250 beats 500 orders at 350". Bakeries were idle at 18-68% beside
  people eating raw (econ_staple.gd:55-70).
- **Judged by:** no run recorded; v10: "not in the candidate run". eight-rules.md says R8 rule 2 absorbs it, but R8
  does not cover FINE_FOOD yet (R8_WORKSHOPS and R8_SERVICES are not built).
- **On v11:** read; meta "off" does not win. Read-test: 18 → 18, capital +38k.
- **Should move:** food bought by the poor; small for P1-P4.
- **For the screen:** alone; read food shortfall first (it was switched off in the food years).

## E168: a frozen food price may rise to the farms' cost

- **Built to fix:** "FOOD sat frozen at 0.64 × the farms' unit cost for years while orders went unfilled and farms
  ran full" (econ_market.gd:372-376).
- **Judged by:** no A/B recorded; "Off by default; base unchanged" (f6b249d). eight-rules.md says R8 rule 1 absorbs it.
- **On v11:** read, and FOOD is exempt from cost-plus, so it can act. Its band (0-5% unfilled, price below the
  cheapest farm's cost) did not occur on seed 1 by month 48: inert in the test.
- **Verdict proposed:** screen it only if the screen's base shows FOOD below farm cost with orders unfilled; v11's
  family farms and R8_FOOD set farm output from orders, which was the gap it covered.

## E171: the charter quota delivery record

- **Built to fix:** the law side of the charter quota: the home world records each ship's delivery against the
  quota (charter_ops.gd:137-148; design-charter-quota-law.md).
- **Judged by:** no run recorded.
- **On v11:** read, but **nothing calls record_delivery** in the game. The comment says "Bob calls this after
  loading every ship"; I never wired it. Inert in the full game.
- **Verdict proposed:** needs X first: the call from EconTrade.on_ship. Small and mine. Since it changes behaviour
  under a switch that is off, it is a fix rather than a feature, but I wait for Wilma's word because of the freeze.

## S7: shacks and the homeless

- **Built to fix:** when formal housing fails, doubling up stops at 130% households per home; the rest put up shacks
  or are homeless (DECISIONS.md:264; econ_informal.gd).
- **Judged by:** seed 1 with S7 "stalled at ~5.5k by Y50 (farm building froze at 20 for 30 years) against 10.8k with
  it off" (econ_informal.gd:55-56); "S7 itself barely acts (few shacks); it is a small perturbation that tips seed 1
  into a FOOD TRAP" (bob-backlog.md:70-81). One seed, code version not named.
- **On v11:** read (off wins). Read-test: the path differs, but the firm count and capital are unchanged at month 48.
- **Should move:** housing, not P1-P4. The old failure was a food trap, which v11 handles differently.
- **For the screen:** alone; food shortfall first.

## S7F: the food trap is unaffordable food

- **Built to fix:** "the food trap is mostly UNAFFORDABLE food, not SCARCE food": diagnosis, recovery, and food
  assistance paid right before households order (econ_foodsec.gd:3-26).
- **Judged by:** "Off: S7F/S7C (no gain on the v9 base)", 5 × 30 (econ_sim.gd:36; the same header says "v8 base", so
  the two records disagree). No numbers.
- **On v11:** read (off wins). Read-test: 18 → 14 alive, capital −582k.
- **Should move:** food bought by the poor. Paying assistance before orders moves money from firms' turn to
  households' turn; that may be what costs firms here.
- **For the screen:** alone, and S7F+S7C.

## S7C: unsold food is perishable

- **Built to fix:** food price drifts down when every order is filled and more is on offer; "seed 4 sat at 2.3× base
  with 1.5 months on the shelves" (econ_market.gd:364-371).
- **Judged by:** with S7F, "no gain on the v9 base".
- **On v11:** read, and FOOD is exempt from cost-plus, so it can act. Its condition (no shortage, surplus cover) did
  not occur on seed 1 by month 48: inert in the test.
- **For the screen:** only with S7F, and only if the screen's base shows food priced above reach with full shelves.

## SUPPORT_B: party and union headquarters and newsrooms employ people

- **Built to fix:** non-production organisations employ real people (econ_hq.gd:3-16).
- **Judged by:** no run recorded; no reason for leaving it off recorded.
- **On v11:** read (off wins). Read-test: 18 → 16 alive, capital −471k.
- **Should move:** P4 (private and civic posts instead of public ones), small.
- **For the screen:** alone. It has never been run, so it is a first look, not a re-look.

## SUPPORT_C: business services

- **Built to fix:** every organisation buys cleaning, catering, courier and office supplies in proportion to its
  staff (econ_bizsvc.gd:3-31).
- **Judged by:** v1, 5 × 30 econ-only: "unemployment +0.9 points and tipped seed 3 into the food trap (shortfall
  177‰)". It was rebuilt as PROFIT_ONLY (paid from profit); the rebuild was never run.
- **On v11:** read (off wins). Read-test: 18 → 24 alive, capital −899k.
- **Should move:** P4 (private service jobs) and P2 (a market for small firms).
- **For the screen:** alone. The rebuilt version has never been judged.

## SUPPORT_D: retail margins

- **Built to fix:** household purchases pass through the district's shops, which take a margin that becomes local
  wages and shop profits (econ_retail.gd:3-20).
- **Judged by:** plan-support-economy.md §10, b25aabc, 3 seeds × 50 years: Y50 adults 10,121 / 9,188 / 9,454
  against 9,638 / 9,898 / 9,401; unemployment 27.5 / 26.3 / 27.1 against 26.8 / 21.2 / 20.6; food 50 / 38 / 73‰
  against 1 / 1 / 21. Then "food margin 0 for now". The food-margin-0 version was never run on its own.
- **On v11:** read (off wins). Read-test: 18 → 17 alive, capital −981k.
- **Should move:** P4 (shop jobs), food shortfall (the old failure).
- **For the screen:** alone; food shortfall first.

## SUPPORT_E: sanitation and building upkeep

- **Built to fix:** a sanitation department with posts per 10,000 residents, and caretakers paid by housing owners
  (econ_sanitation.gd:3-18, econ_office.gd:35).
- **Judged by:** the same §10 run: seeds 1/2/3 adults 7,661 / 9,847 / 10,223, unemployment 32.8 / 27.4 / 15.5%,
  food 111 / 27 / 1‰. Mixed by seed; "re-test after the food-trap/fiscal work".
- **On v11:** read (off wins). Read-test: 18 → 17 alive, capital −1,259k.
- **Should move:** more public posts (P4 the wrong way), more jobs in total.
- **For the screen:** alone. The re-test it was promised.

## SUPPORT_S: comfort spending

- **Built to fix:** households spend a share of income above essentials on cafés, hairdressers, gyms
  (econ_comfort.gd:3-22).
- **Judged by:** v9 per-flag check, 5 × 30 on v8: "no gain, higher tax" (econ_sim.gd:36). No numbers.
- **On v11:** read (off wins). Read-test: 18 → 25 alive, capital −162k.
- **Should move:** P2 and P4: private service firms with a market of their own.
- **For the screen:** alone; read the public share of jobs.

## INV_EXPECT: invoice room and credit lines on expected sales

- **Built to fix:** the user's ruling that credit follows expected sales: the E148 supplier-credit room and the E153
  line follow EconAnnual.expected_rev instead of last year's average (econ_credit.gd:23-26).
- **Judged by:** no run. Off by the user's order: "Build it but don't switch it on until after".
- **On v11:** read (off wins). Read-test: 18 → 14 alive, capital −426k.
- **Should move:** credit for young firms (P2). Expected sales are larger than history for a young firm, so it lends
  more early; seed 1 shows that more credit alone does not keep firms alive.
- **For the screen:** alone and with E153, as planned. Bank capital is the column to watch.

## EXP, EXP_PORT, EXP_KEEP: producing for the ship

- **Built to fix:** the user: "the people who send those things back only ever do things based on how much they can
  use on the colony, not on what also they get from off-world exports" (design-exports.md).
- **Judged by:** no run. The planned A/B is design-exports.md §9: base / exp / exp+port / exp+port+keep / all+SHIPPING,
  10 × 30, then 3 × 60, after the bank work.
- **On v11:** all three read (off wins). Read-test: EXP 18 → 18, capital −810k; EXP_PORT on EXP 20 alive, +525k on
  EXP; EXP_KEEP on EXP 13 alive, −98k on EXP.
- **Should move:** P2 most directly of all 30: the mines and material plants that die by year 5 get a second
  customer.
- **Depends on:** R8 and R8_MATERIAL/R8_FOOD. EXP_KEEP runs without EXP in the code.
- **For the screen:** the arms of design-exports.md §9; read mines and material plants alive at Y5 and Y10.

## R8M_PX: the material price rules

- **Built to fix:** kept the R8 material price rules 1 and 2 as an opt-in after the A/B dropped them
  (econ_rules_mat.gd:5-6).
- **Judged by:** ab-r8-materials.md, base12 (f915804), 10 × 30: r8m 4,598 adults / 20.4% / food 25.2‰ / real wage
  2.71 / firms dead 68.2 against 4,739 / 17.2% / 18.0‰ / 3.11 / 68.6. "Rules 1/2 as built lock prices high". Not in
  the 60-year run.
- **On v11:** read; meta "off" does not win. Read-test: 18 → 21 alive, capital −600k.
- **For the screen:** alone, 60 years, since only the 30-year run exists. A clear loss at 30 years; low priority.

## R8M_NOVALUE: no value bids for materials (kill switch)

- **Built to fix:** take-apart arm: R8 material rules without value bids (econ_rules_mat.gd:4-5, :330).
- **Judged by:** never in exactly this form. The 60-year numbers on seeds 1-3 nearest to it: base12 6,512 / 18.7% /
  55‰ / 3.01 / dead 142; valonly 7,449 / 27.1% / 39‰ / 2.78 / 124.
- **On v11:** read (it is a kill switch; "on" turns value bids off). Read-test: 18 → 14 alive, capital −132k.
- **For the screen:** low priority; it takes out a part that is on, and the 60-year record favoured value bids.

---

## Summary for the screen

| switch | state on v11 | proposed |
|---|---|---|
| E139 | dead (E149 overrides it) | off, superseded; no run |
| E171 | dead (never called) | needs the call from on_ship first |
| E150P | read, but no AI approves a rise | needs the government's decision first |
| E168, S7C | live, condition not met in 48 months | screen only if the base shows their condition |
| E152 | read; capital +749k in 48 months | screen first for P1; then with BANK_RISK, BANK_SEC |
| EXP, EXP_PORT, EXP_KEEP | read | the design-exports.md §9 arms, for P2 |
| E137, SUPPORT_S, SUPPORT_C | read; the most firms alive at 48 months | screen for P2 and P4 |
| E153 | read; the fewest firms alive | screen with INV_EXPECT, not alone |
| E155 | read; capital −4.2M from fewer loans | screen 60 years, read capital at Y60 |
| all others | read | screen alone, 3 × 60 |

Combinations I name for step 3: the money arms E151+E152+E153+E155 with INV_EXPECT (v11 now has supply that
answers); E152 with the bank build; E150B+E150C; S7F+S7C; EXP with SHIPPING; E136 with BANK_RISK.
