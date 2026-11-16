# Re-evaluation of every switched-off system

## The user's order (2026-11-16, verbatim)

> "I want them all reevaluated and given a proper consideration because some of those could be holding the answer"

Asked after Wilma's list of about 52 systems that are off (32 are on). "The answer" is read by Wilma as the answer to
the open problems: the bank fails in 8 of 9 sixty-year games, private manufacturing and mining are gone by year 5,
unemployment jumps when the bank's room hits zero, the public sector posts 60–80% of jobs.

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

## Results

(filled in as the reviews and runs come in)
