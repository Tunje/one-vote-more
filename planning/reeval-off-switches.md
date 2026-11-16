# Re-evaluation of every switched-off system

## The user's order (2026-11-16, verbatim)

> "I want them all reevaluated and given a proper consideration because some of those could be holding the answer"

Asked after Wilma's list of about 52 systems that are off (32 are on). "The answer" is read by Wilma as the answer to
the open problems: the bank fails in 8 of 9 sixty-year games, private manufacturing and mining are gone by year 5,
unemployment jumps when the bank's room hits zero, the public sector posts 60–80% of jobs.

The user, same day (verbatim): "Okay many of these where turned off because of the food crisis, sound we changed how
that works some of the night not have the same issue annymore"

Switches whose recorded reason was food (Wilma's reading of the notes): E139 (food shortfall 31 -> 42 permille),
E151 / E152 / E153 / E154 / E155 ("starve the colony until supply responds"), S7F / S7C (food trap, no gain), E156
(bread price), FREIGHT_ROADS (three times the hunger), SUPPORT_D / SUPPORT_E (failed while food was short). Food has
changed since: family farms and bakeries, farms following their sales, buyers bidding what food is worth, farms
working by hand without power. For these the screen's food shortfall column is read first.

## Why the old verdicts cannot be trusted (Wilma)

- Most were judged at 30 years. The bank and jobs failures show after year 30.
- Most were judged on v8, v9 or v10. The base is now v11 (family farms, eight rules for freight, materials and food,
  the credit fix, re-tendering).
- They were judged on adults, unemployment, food and real wage. None was judged on the bank's capital or on private
  firms staying alive.
- Many were judged alone. Some only make sense together (the money arms with supply able to respond; the plan stage
  with a bank that prices risk).
- 18 were never run in a full game at all.

## Method (Wilma's proposal; the numbers are Wilma's, not the user's)

1. **Desk review, by the owner.** For each switch: what it was built to fix, the exact test that judged it (base,
   seeds, years, what was measured), whether the code still works on v11 (unit tests, --check-only, the switch is
   really read), and what it should move if it holds part of the answer. Unit tests only.
2. **Screen, by Wilma, in a scratch copy.** Each switch alone on the v11 base, 3 seeds x 60 years, reading adults,
   unemployment, food shortfall, real wage, bank capital, private firms alive and dead, money held by households.
3. **Second look.** Anything ahead on any measure, or behind for a reason the desk review explains, goes to 10 seeds
   and to the combinations its owner names.
4. **Again after the bank fix.** The whole screen is repeated on the base with Bob's bank build, because the bank
   decides so many of the verdicts.
5. Every switch gets a written verdict here: on, off with the measured reason, or needs X first. No switch is
   left with "not run".

## The switches and their owners

| Owner | Switches |
|---|---|
| Bob | E136, E137, E138, E139, E140P, E143, E150B, E150C, E150P, E151, E152, E153, E155, E156, E168, E171, S7, S7F, S7C, SUPPORT_B, SUPPORT_C, SUPPORT_D, SUPPORT_E, SUPPORT_S, INV_EXPECT, EXP, EXP_PORT, EXP_KEEP, R8M_PX, R8M_NOVALUE |
| Otto | E165, E165B, E165Q, E155BLD, E166, E169, R8_BUILDERS, R8_HOUSING |
| Terra | FREIGHT_ROADS, ROAD_WORKS, SITING, TOWN_GRID, ECO, SEASONS |
| Anni | PRIVATE_ROADS, ROAD_SAFETY |
| Ella | E154 |
| Maja | DELEGATION, AGRI_MIN |
| Wilma | SHIPPING |

Not built, only named in EconRules.SECTORS: R8_WORKSHOPS, R8_SERVICES, R8_UTILITIES, R8_INSTITUTIONS (the eight rules
for workshops, services, utilities and institutions). Nothing to evaluate until they exist; building them is a
feature and waits for the user.

No longer in the code: E141, E158, E159.

## Experiment: off-world investors (the user, 2026-11-16, verbatim)

> "Do me a favor and run a test where the bank gets an infusion off extra money every time the homeworld ship arrives
> because i think you missed something when i talked about stockmarket, off world investors, we just try with a flat
> sum to see if it makes a difference"

Scratch copy only: with every ship, a flat sum goes from outside the colony into the bank's own account (its capital).
Sums tried (Wilma's): 0.5, 1 and 2 million credits per ship; 3 seeds x 60 years; against the base of the screen.
Not in the shared code.

## Idea, not a plan (the user, 2026-11-16, verbatim)

> "Also is it builders companies that die? In that case can we use a sell jobs on module where they take in sub co
> tractors to help?"

Base games, 60 years, seeds 1/2/3: builders alive 2/2/1, dead 52/57/42 (of 151/140/176 private deaths). Causes by the
A/B tool: too little work 22/21/12, work but at a loss 20/26/23, other 10/12/8. Subcontracting is "post-v1" in
spec-economy-v1.md §20; nothing is built.

## Firms in trouble and loss-making jobs (the user, 2026-11-16, verbatim)

> "Also firms in trouble should be able to be bought up by larger firms why did they not renegotiate jobs that was a
> loss? We talked about improving them and the new way contractors work with the plan and build list was made to fix
> this"

State of the code (Wilma, 3e20850):
- Bought up: a plant changes hands only after its firm is dead (liquidation sale), in a worker buy-out, a forced sale
  or a nationalisation. A larger firm buying a firm in trouble while it still trades: designed (E166 rescue window,
  Anni's sale law with flag E174 in design-law-company-sales.md, the merger review in competition_law that nothing
  calls), not running. E166 is off and reads a stub; E174 is not coded.
- Renegotiating a loss-making job: does not exist. Only E76 passes input-cost changes through, and a builder may walk
  away after 3 unpaid months. design-law-construction-contracts.md (price revision at the start date, deposit,
  cancellation fee) is not coded.
- The plan stage and the build list (E165, E165B, E165Q) and the builders' eight rules (R8_BUILDERS) are built and
  switched off; the base games with 42-57 dead builders ran without them.
Extra arm for the screen: all four together (NEWWAY).

## Results

### Off-world investors: a flat sum into the bank with every ship (scratch copy of 3e20850, 60 years, 2026-11-16)

u, food (permille) and real wage are means Y5-60; the rest at Y60. Bank capital and loans in millions.

| arm | seed | adults | u % | food | real | priv alive/dead | builders alive/dead | bank capital | loans | money |
|---|---|---|---|---|---|---|---|---|---|---|
| base | 1 | 10370 | 20.5 | 5 | 2.62 | 136/151 | 2/52 | 13 | 13 | 64 |
| base | 2 | 6964 | 33.3 | 24 | 2.38 | 179/140 | 2/57 | 0 | 0 | 71 |
| base | 3 | 7628 | 29.6 | 43 | 2.63 | 132/176 | 1/42 | -3 | 0 | 86 |
| 0.5M | 1 | 10023 | 23.0 | 8 | 2.76 | 140/133 | 2/46 | 9 | 12 | 73 |
| 0.5M | 2 | 8545 | 27.0 | 22 | 2.73 | 187/154 | 1/49 | 0 | 0 | 94 |
| 0.5M | 3 | 8458 | 28.2 | 32 | 2.88 | 191/156 | 1/43 | -2 | 0 | 90 |
| 1M | 1 | 10171 | 23.1 | 5 | 2.61 | 165/157 | 5/46 | 27 | 5 | 62 |
| 1M | 2 | 8694 | 23.3 | 15 | 2.93 | 157/188 | 3/53 | 13 | 10 | 95 |
| 1M | 3 | 6160 | 15.8 | 5 | 3.59 | 111/170 | 2/49 | 20 | 36 | 103 |
| 2M | 1 | 9818 | 25.1 | 4 | 2.73 | 207/129 | 4/44 | 32 | 10 | 100 |
| 2M | 2 | 7827 | 22.0 | 16 | 2.98 | 116/191 | 2/54 | 24 | 17 | 94 |
| 2M | 3 | 6777 | 14.5 | 6 | 3.99 | 177/190 | 1/50 | 26 | 44 | 130 |

Reading (Wilma): 1M per ship or more keeps the bank alive on every seed; 0.5M does not (seeds 2 and 3 still fail, so
the bank loses more than 12M + about 15M there). Where the base bank had died (seeds 2, 3), a living bank cuts
unemployment by 10-15 points, cuts the food shortfall and lifts the real wage. Where it had not died (seed 1), nothing
improves. Firm deaths and builder deaths do not fall in any arm: the bank's death is not what kills them. The bank
still loses heavily (about 30M in, capital up by 14-27M at most). Three seeds; adults move both ways (seed 2 up, seed
3 down).

(more filled in as the reviews and runs come in)
