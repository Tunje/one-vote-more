# Re-evaluation of switched-off systems: Anni's desk review (2026-11-16)

Step 1 of planning/reeval-off-switches.md, for PRIVATE_ROADS and ROAD_SAFETY. Desk review only: unit tests,
--check-only and reading the code on v11 (HEAD 3e20850). No game runs.

"The answer" (Wilma's reading of the user's order):
- the bank fails in 8 of 9 sixty-year games;
- private manufacturing and mining are gone by year 5;
- unemployment jumps when the bank's room hits zero;
- the public sector posts 60–80% of jobs.

Both switches were built by Terra (transport) and me (law). The answers below cover both sides, because the law side
alone does nothing without the transport side.

On v11, the five test files for both switches pass: tests/law/test_road_law.gd, tests/law/test_road_law_links.gd,
tests/law/test_road_safety_law.gd, tests/transport/test_private_roads.gd and tests/transport/test_road_safety.gd
(36 tests, failed: 0).

## PRIVATE_ROADS (needs FREIGHT_ROADS)

**What it was built to fix.**
- The user: "private roads, bought and paid for by companies" (2026-11-15).
- A firm whose freight is held by the public roads (FREIGHT_ROADS: goods that cannot be moved) could build its own
  road instead of waiting for the government.
- It also carries tolls, open access, and the law around all of it: licences, neglect, takeover, reversion.

**Was it ever run in a full game?** No. Terra's steps 1–5 and my law steps 1–2 were unit-tested only.

**Does it work on v11, and is the switch really read?** The switch is read everywhere:
- Terra's network views and freight routes per firm;
- commuter tolls;
- gov_builder's toll pressure;
- the law provider's licences and links (RoadLaw.on honours meta.off).

But in a game nothing ever creates a private road. Nobody calls the business case
(Transport.private_road_case / road_needs). Nobody files a licence (RoadLaw.may_build / apply_licence). Nobody orders a
ROAD project with an owner. The firm's decision was always Bob's: rule 8 compares the freed freight × margin with the
road's cost. It was never built. Nobody books the toll bill (Transport.toll_bill) either.

Switched on as it stands, the switch changes nearly nothing. With no private links, the network views are the public
network, and no tolls are due. The only live parts are the gated levers. Parties take positions on them even without
the switch (the commitments leak I reported), and they are draftable with it. **A screen of this switch alone would
measure noise.**

**What it should move, if it holds part of the answer.** It could reach the private-firms problem only if roads are part
of why private manufacturing and mining die.
- A mine or plant whose output is held by roads loses sales.
- A firm-owned road frees that freight without waiting for the government's road programme.
- That keeps private firms alive and their jobs private, which bears on the public-share-of-jobs problem.
- It costs the firm the road's price up front, which is a borrowing need. With the bank failing, that may cut the
  other way.

A check before anything is built (Bob or Wilma, from data already in v11 games): in the base games where private
manufacturing and mining die by year 5, how much of their output was held by roads (Bob's hr per good and district)?
If it is small, private roads cannot be part of the answer and need not be finished for this question.

**Switches it needs with it:**
- FREIGHT_ROADS (required by the code);
- ROAD_WORKS (the government's own road building, the alternative it competes with);
- for a fair test, R8_FREIGHT, which is default in v11.

**What it needs before a screen means anything:**
- Bob's firm decision to build (rule 8 on Terra's road_case, then the licence through RoadLaw.may_build and
  apply_licence, then a ROAD project with an owner);
- the toll booking.

**Verdict proposed:** off, needs X first. X is Bob's build-a-road decision and the toll booking. Before that, look at the
held-freight share above, to decide whether it is worth finishing for the bank and private-firm problems at all.

## ROAD_SAFETY

**What it was built to fix.**
- The user: "accidents should [be in the game]. Any high speed road near utility people walk to, and near districts,
  have chances for accidents; over and under passes reduce the chance. Also road types should not be speed." /
  "a motorway around a village instead of through can be a thing." (2026-11-15)
- It is realism and a source of decisions for the desk: speed limits, passes, bypasses.
- On the law side: who sets limits, a default limit near homes parliament can set, and liability and blame for deaths.
- It was not built for the economy's problems.

**Was it ever run in a full game?** No. Terra's commit says "unit-tested only, no game comparison yet". Mine likewise.

**Does it work on v11, and is the switch really read?** Yes, the tests pass. With the switch on in a game:
- **Live without other switches:**
  - Terra's accidents are drawn every month (NATURE). Deaths go through EconPop.casualties, staff of the nearby
    workplace first, so a few adults are lost.
  - A limit slows the route graph.
  - Over- and underpasses and flyovers can be planned.
  - My liability runs: a TORT against the state or a road owner when a pass had been on offer 3+ months and was not
    built. The state's money goes to the victim fund.
- **Inert without other switches:**
  - Limits and passes are decided only with DELEGATION (gov_builder's SPEED_LIMIT / ROAD_PASS cases). Without it, no
    government ever sets a limit or orders a pass.
  - So pass_refused becomes true on every dangerous road after 3 months, and every death on one becomes a court case
    against the state. Read alone, the switch overstates the state's liability.
  - Parliament's default limit (LAW_SPEED_NEAR_HOMES) starts at 0. It acts only if a party drafts it.

**What it should move, if it holds part of the answer:**
- **Adults**, slightly down: road deaths, mostly of working people near workplaces.
- **Government spending**, slightly up: torts, and passes if DELEGATION orders them.
- **Freight times**, slightly up where limits are set (with DELEGATION or the lever). That is a small extra cost on
  private freight, the wrong direction for the private-firms problem.
- Nothing in it touches the bank, firms' credit, or the public share of jobs. **I do not expect it to hold any part of
  the answer.** Its screen should check only that it does no harm: adults and the treasury not visibly worse.

**Switches it needs with it:**
- DELEGATION, without which nobody decides limits or passes and liability overstates;
- FREIGHT_ROADS, if traffic per link is to be real (Terra's accident rate scales with last month's trips);
- PRIVATE_ROADS only for the neglect liability, which is inert until private roads exist (above).

**Verdict proposed:** off until screened with DELEGATION. Screen it as ROAD_SAFETY + DELEGATION, not alone, as a
does-no-harm check: adults, treasury, accidents and deaths a year, torts paid. It is not a candidate for the answer.

## Notes for the screen (Wilma)

- Read accidents from facts TRANSPORT_ROAD_ACCIDENT (data.killed, injured).
- Read torts from cases of type TORT with data.road = true.
- Read limits from TRANSPORT_SPEED_LIMIT_SET.
- For PRIVATE_ROADS a screen would count private links: Transport.private_links(world). I expect 0 in every game until
  Bob's decision exists. That count is the cheapest proof of the "inert" finding above.
