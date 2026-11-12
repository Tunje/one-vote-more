# Plan: Bias audit (after v7)

User decision 2026-11-13 (A52): "The system we have built, is it biased?" → "Do so" (run a proper check after v7).

Owner: **Wilma** (politics, tools, report); **Bob** checks the economic side (hints vs real effects, rescues,
co-ops vs firms). Runs on the v7 tree, after the v7 chronicles. Output: planning/audit-bias-report.md and a short
summary for the user (which asymmetries are intended realism, which are accidental, and what we change).

## 1. Outcome audit (tools/audit_outcomes.gd)
12 seeds × 60 years (integrated sim, autoplay). Per seed, per Cabinet: the First Minister's party ideology centre
(ECON_ROLE, REDISTRIBUTION, FISCAL, ENVIRONMENT, SOVEREIGNTY, INSTITUTIONS), months in office, re-election,
approval path, and the economy during its term vs before (unemployment, real income, debt, pollution, housing).
Question: does one side systematically govern longer, poll better, or deliver better numbers — beyond seed luck
(bootstrap over seeds)?

## 2. Mirror test (tools/audit_mirror.gd)
Same seeds; the founding parties' positions mirrored on each axis (left↔right, state↔market, green↔growth,
loyal↔independent). A fair system gives the mirrored side about the same success (vote share, months governing).
Report the per-axis asymmetry with uncertainty.

## 3. Hint audit (from POL_POLICY_EVIDENCE, A49)
For every law: the hand-written effect hints vs the colony's recorded evidence across all audit runs, and whether
the error leans by the law's ideological direction (do we overstate what left- or right-coded laws achieve?).
Bob reviews the economic mechanisms behind any law with a large, consistent gap.

## 4. Press and money balance
Media tilt (outlets' lines × circulation) and donations per side, normalised by party size and vote share; scandals
per donation (already ~4.5% everywhere in v5 — recheck).

## 5. The report
A table of every asymmetry found: size, likely cause, intended (realism: e.g. companies donate to market parties,
unions to labour) or accidental, and a recommendation (keep / change / make it a law or setting). The user decides
what stays.
