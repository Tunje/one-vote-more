# O-1 notes: unemployment drift after year 5 (handover to M8)

**Owner:** agent 88 · **Date:** 2026-11-11 · **Status:** open, parked for M8 (A29)
**Gate at handover:** 3/6 seeds OK. In-band months by seed: 91 / 61 / 106 / 60 / 74 / 72. Famine 1/6, default 1/6.

## What's already fixed
Firm deaths are no longer the main driver:
- debt workout and worker buyouts (E77)
- no micro co-op churn, one entrant at a time (E77)
- a public builder of last resort and price escalation on contracts (E76)
- the famine chain (E75)
- sticky wages (E78)

## The drift
Most seeds hold unemployment at 10–17% until years 4–5. It then climbs to 30–45% by year 10, and benefits drain the treasury.

## Best hypothesis
Jobs stop growing while the labor force keeps growing. The binding limit is supply capacity in the input chain, not household demand.

Evidence from the traces:
- **Population grows, firms don't.** Population grows about 19% over 10 years (seed 1: 2125 → 2525) through births and migration. The count of active firms stays flat or shrinks (16–18 → 13–15).
- **Consumer goods get dearer.** The CONSUMER price rises 2–4× (115 → 250–460) while unemployment rises. That is a shortage signal, not a demand shortfall.
- **Inputs are scarce.** MATERIAL sits at 2–3× base for long stretches. COMPONENT supply is close to zero without the origin backstop.
- **Expansion stalls.** Firms expand only with idle labor plus a strong price signal (firm_ai `_expansion`). Expansions need MATERIAL and COMPONENT, which are scarce, so they go slowly. The backstop is capped at 200 MATERIAL and 40 COMPONENT per month.
- **Rising prices cut real incomes.** Nominal wages are now sticky (E78), but real wages still fall, so households buy less at the same time.

Alternative hypothesis (demand-bound): households lack income, so firms cut targets and don't hire. The price signals above argue against it, but it hasn't been ruled out.

## First three experiments in M8
Each is an A/B on seeds 1–6 × 120 months, scored by in-band months and by the year-10 unemployment and treasury.

1. **Unemployment accounting.**
   - Build a tool that splits each year's change in unemployment into:
     - labor-force growth, by source: births, migrants, retirements
     - jobs lost, by sector, with the cause: closures, layoffs, automation by targets
     - jobs created
   - This tells whether the drift comes from labor-force growth or from job loss. It's cheap and decides which of experiments 2 and 3 matters.
2. **Is it supply-bound?** Raise the input-chain capacity:
   - backstop caps ×3 (MATERIAL 600, COMPONENT 120)
   - plus one extra COMPONENTS plant at start

   If unemployment drift and the CONSUMER price both drop, the fix is capacity. Candidate fixes are an entry signal for input plants and stronger strategic subsidies.
3. **Is it demand-bound?** Hold supply fixed and add demand:
   - benefit floor 80
   - public-works line fixed at 3000k
   - consumption smoothing share 0.8

   If the drift barely moves (or prices just rise), demand is not the binding limit and experiment 2's fix is the one to pursue.

Tools to use: `game/tools/debug_mortality.gd`, `debug_famine.gd`, `debug_pipeline.gd`, `ab_e70.gd` (template for an A/B runner), and `soak_integrated.gd`.
