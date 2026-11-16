# Re-evaluation, Ella's switches: desk review (step 1)

Order: planning/reeval-off-switches.md (the user, 2026-11-16: "I want them all reevaluated and given a proper
consideration because some of those could be holding the answer"). Step 1 only: code reading and unit tests, no game
runs. Base: v11, HEAD 3e20850.

## E154: union funds release their savings

### What it was built to fix
Money audit, finding 3 (planning/money-audit.md; Anni's account map, seed 1, 60 years, v9 defaults): union funds
grew from 0.3M at Y5 to 5M at Y25 and held 16–35% of all household money for 40 years. Dues came in and almost
nothing went out until E133's rebates started after Y25, because E133's cap (12 weeks of strike pay) was far too high.
Fix plan item 4: "Lower E133's cap so dues above a strike reserve flow back to members."

What E154 changes (game/sim/economy/unions.gd:34–36, :269, :293). It changes nothing else:
- A union's fund cap drops from 12 to 8 weeks of strike pay (E154_CAP_WEEKS). Above the cap, members pay
  maintenance dues (25%), and the excess is rebated to members' households by membership. Both of those are E133
  rules, unchanged.
- The federation keeps a quarter of its affiliates' caps instead of half, and returns the rest to the affiliates.
  The affiliates then rebate it to households through the same rule.
- It works only through E133. E133 is on by default (`not EconUtil.off(world, "E133")`), so E154 needs nothing
  else switched on.

### The exact test that judged it
I can't find one.
- It landed opt-in in 91e5e5f (2026-11-14, "E152-E154 bank and union funds"; full suite 605 passed, all new systems
  off).
- No A/B, chronicle or verdict for it exists in planning/ or in DECISIONS.md.
- The only test that turns it on is tests/economy/test_money.gd `test_run_closes`. It runs 24 months, economy only,
  together with E140/E148/E152/E153, and checks only that the ledger closes and jobs equal people.
- The test that judged its parent, E133, was relative only (DECISIONS.md: "run during a contaminated tree window").

So E154 belongs with the switches never run in a full game. If Wilma or Bob has a run I don't know of, it replaces
this paragraph.

### Does it work on v11?
Yes.
- **Code is clean:** `--check-only` passes on unions.gd at 3e20850.
- **The switch is really read:** both places read `meta["on"].has("E154")` (unions.gd:269 for the union cap, :293
  for the federation cap).
- **Unit tests are green on a scratch copy of 3e20850:** test_union_funds, test_unions, test_union_disputes,
  test_money and test_union_politics all pass.
- **New scratch test, also green:** scratchpad `wt_e154/tests/economy/test_e154.gd` (2 tests):
  - With E154 on, a windfall is cut back to the 8-week cap within one month.
  - The strike chest stays at about 8 weeks.
  - The spare fund is at most 4 weeks of strike pay.
  - The ledger closes.
  - Under the same windfall, the fund ends lower with E154 than with E133 alone, and the federation stays near a
    quarter of the caps.
  - I can move this test into the shared tree if you want it there. It is tests only.
- **Strike strength is untouched:**
  - The strike decision reads fund weeks / 4 (union_disputes.gd:276), so it is already full at 4 weeks.
  - Escalation during a dispute reads weeks / 8 (:447), so it is full at 8.
  - An 8-week cap leaves both at full strength. This matches the code comment.

### What it should move if it holds part of the answer
**Direct effects:**
- Union fund total and its share of household money go down.
- Household money goes up by the released part.
- Dues fall sooner, because maintenance dues start at 8 weeks.
- Rough size: funds peaked near 5M against 45–101M of colony money, so cutting the cap by a third releases roughly
  1–2M. It also starts sooner, because funds reach 8 weeks years before 12.

**My expectation:** small and positive for households, and not the answer to the open problems by itself.
- It moves money from union accounts to the same members' households. It creates no money and does not touch the
  bank's capital.
- It reaches firms only through what households then spend.
- If household spending on essentials and services rises measurably when it is on, that is the part of the answer
  it can hold. If it doesn't rise, the money only changed accounts.

**Side effects in election year (mine), which the screen should read as well:**
- `Unions.spare_fund` = fund − 4 weeks of reserve. A union at its cap drops from up to 8 spare weeks to up to 4.
- Election-year union donations to parties (union_politics.gd:340, 8% of the spare fund a quarter) therefore fall
  by up to half for unions at their cap.
- The federation's spare fund halves. The union newspaper's founding check (media_ops.gd:1648, UNION_FOUND_CASH)
  and union coverage spending (:1820) read it, so "The Worker" may be founded later or not at all.
- These are losses of political money, not economic harm. In the screen, count union donations per election and
  whether The Worker exists. Strike counts and strike lengths should stay unchanged; if they move, the
  strike-strength reading above is wrong.

**Measures for Wilma's screen**, beyond the standard set (household money is already in it):
- union fund total and its share of household money by decade;
- household spending on essentials;
- union donations per election;
- strikes per decade.

### Which switches it needs with it
- Only E133 has to be on, and it is on by default.
- It makes sense alone, so screen it alone.
- If it shows more household money but no more spending, it should be looked at again together with the money and
  household-budget work, since spending is where its effect has to show. That pairing is for the second look; it
  is not a requirement for the screen.
