# Re-evaluation, step 1 (desk review): DELEGATION and AGRI_MIN (Maja)

Base: v11, HEAD 3e20850 (2026-11-16). This review used unit tests and `--check-only` only, with no game runs. The
method is in planning/reeval-off-switches.md.

## DELEGATION: who decides (planning/design-delegation.md)

**What it was built to fix.** It was not built to fix the economy. It is the user's delegation system. The First
Minister cannot take every government decision, so each decision type has a level:

- the minister decides it (CALL);
- the minister proposes and the First Minister answers (SUGGEST);
- the First Minister decides it (ME).

There are presets, legal ceilings, a hand-over and a monthly summary. Also:

- The state's decisions become cases on the office desk: the capital programme's orders, road fixes, grant coverage,
  re-tenders, upgrades, the wildlife review, the road law and builders' quotes.
- A human government gets proposals it would otherwise never see.

**How it changes a computer-run game.** This is what step 2's screen would measure. With the switch off, the code
takes these decisions directly by its own rule: if a need is found and the money is there, it orders. With it on,
every government, the autoplay one included, decides through the office:

1. A case carries options with a hidden merit, and almost always includes "wait / not now", which is the default.
2. The minister for the portfolio recommends an option. The recommendation reads the merit plus the minister's own
   lean, and is noisier when the minister's skill is low.
3. A routine type is decided by the minister alone (CALL); the rest go to the computer First Minister, who follows
   the minister unless the government's ideology runs strongly the other way (OfficeFeed.ai_answer, lean scale 2000).
4. A vacant portfolio sends the case to the First Minister.

So a market-leaning minister or government can now say "not now" to a school, a housing block, public works or a
re-tender. Without the switch, it cannot.

Computer First Ministers set no levels of their own; that is step 4, not built. They play the default preset
(BALANCED).

**Ever run in a full game?**

- The counter only (build step 1): yes. Six 100-year autoplay chronicles, seeds 1–3, in
  chronicles/desk_count_v1/. The base runs had DELEGATION; the "week" runs had DELEGATION, ECO, AGRI_MIN, E160, E162
  and FREIGHT_ROADS. Both were on v10-era defaults. The counter changes nothing in the game.
- With routing (build step 3, everything that changes outcomes): no full game. The only runs were short probes:
  - 60 months, seed 1, with ROAD_SAFETY: 4 speed-limit and 4 crossing cases, 2 limits set.
  - 4 years with R8_BUILDERS: 10 quote decisions.
  - Over the same 60 months the desk counted 25 housing, 19 school, 11 clinic, 20 builder-grant, 18 ordinance and
    13 re-tender decisions.
- No run ever compared outcomes (adults, unemployment, food, wage, bank, firms) with the switch on and off.

**Does it work on v11?**

- `--check-only` is clean on every file that reads the switch: decision_desk.gd, gov_builder.gd, gov_wildlife.gd,
  office_feed.gd, econ_builders.gd, road_law.gd and office_staff.gd.
- The unit tests on the shared tree, which matches HEAD 3e20850 in every tracked file: test_decision_desk,
  test_desk_cases, test_delegation_sheet and test_office_staff. Results are in the section "Unit test results" below.
- The switch is read at run time from world.meta["on"] by DecisionDesk.on(). It is honoured by `+DELEGATION` on the
  chronicle tool and by the `on` list of an autoplay game.
- An off-switch through meta["off"] also works.
- With the switch off, the state hash is unchanged. This was checked at every build step, 72–84 months, seed 1.
- One thing to know: the 60-month probe found that a computer First Minister chose a 606k bypass over a 64k
  overpass. A safety work's cost is weighed only against the infrastructure line's headroom, so a rich line makes
  cost nearly irrelevant. This only matters with ROAD_SAFETY on. It was reported to you earlier.

**What it should move if it holds part of the answer.**

- The public sector's share of jobs (60–80% now) and public capital spending. Governments that lean to the market
  will turn down some projects, and the two-month answer window will delay others. Expect fewer public projects
  started, a lower public share of jobs, and less treasury spending on the capital programme.
- Possibly room for private firms, if public projects were crowding them out.
- A risk on the other side: fewer homes, schools and clinics, and public works not ordered in a slump, so
  unemployment could rise rather than fall.
- It should not move the bank directly. Two indirect paths: quote refusals change builders' revenue, and re-tenders
  turned down leave projects stuck.

My expectation is modest. The case merits were set so that a sound project usually wins, and the lean (scale 2000)
only tips close calls. The decision count is low (about 1–3 a month), so how much it moves is an open question for
the screen.

**Switches it needs with it.**

- Alone, it routes:
  - the capital programme (orders, roads, grant coverage, upgrades, re-tenders, public works);
  - the wildlife review, which needs ECO;
  - ordinances and bills, counted only.
- More of its cases only exist with:
  - R8_BUILDERS: quotes to accept or refuse; public builders are counted only.
  - PRIVATE_ROADS: road licences, neglect and takeovers.
  - ROAD_SAFETY: speed limits, and over- and underpasses or a bypass.
  - ROAD_WORKS: which road goes first and which fix.
  - HIRING_CENTRE (Ella, not in the tree yet): counted only.
- AGRI_MIN gives food and farm cases (food reserve, grant coverage, state farm, bakery) their own minister. Without
  it they go to the economic adviser.
- Suggested screen: DELEGATION alone. Then, if it moves anything, add R8_BUILDERS (the builders are where the bank
  meets the state) and AGRI_MIN.

## AGRI_MIN: a Minister of Agriculture

**What it was built to fix.** The user asked on 2026-11-15 for a Minister of Agriculture to exist, covering farms,
family-farm programmes, food stocks and wildlife on farms. It adds the AGRICULTURE portfolio to the Cabinet:

- skills weighted ENV 0.4, ECON 0.3, LOGI 0.3;
- the minister's lean read on the ECON_ROLE axis.

It was not built to fix the economy.

**Ever run in a full game?** Only in the three 100-year "week" chronicles above. They were run together with five
other switches and judged on nothing but the decision count. It has never been run alone, and never judged on outcomes.

**Does it work on v11?**

- `--check-only` on office_staff.gd is clean.
- The tests that cover it are test_office_staff (the portfolio is dealt only with the switch) and test_decision_desk
  (agriculture cases go to that minister with the switch on, and to the economic adviser without it). Results are
  below.
- The switch is read from world.meta["on"] by OfficeStaff.portfolios().

**What it should move.** Without DELEGATION, almost nothing. Nothing in the tree posts an office item for the
AGRICULTURE role except the decision desk. Alone it adds one more Cabinet post:

- one more portfolio for coalitions to share out;
- one more minister off the backbench (Bench reads the portfolios).

That is a small political effect, and none on the economy.

With DELEGATION, the food reserve, grant coverage, state farms and bakeries are decided by a dedicated minister
with their own lean and skill, instead of the economic adviser. It could change how quickly the food reserve opens
in a shortfall, which matters for food shortfall.

**Switches it needs with it.** DELEGATION, or it only reshapes the Cabinet. E160/E162 (family farms and bakeries,
on in v11) give it most of its cases. Screening it alone would measure nothing. If it is screened at all, screen it
as DELEGATION + AGRI_MIN against DELEGATION.

## Unit test results (HEAD 3e20850, 2026-11-16)

All four pass with "failed: 0": test_decision_desk, test_desk_cases, test_delegation_sheet and test_office_staff.
Each run ended with the known, harmless segfault on exit.

Both switches still work on v11. Neither has been judged on outcomes in a full game.
