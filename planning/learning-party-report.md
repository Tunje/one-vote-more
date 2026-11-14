# Learning party: overnight optimiser report (A53, run 2026-11-14)

Spec: planning/spec-learning-party-v1.md. Raw outputs: game/tools/ml/out/2026-11-14/ (evals.jsonl, gens.jsonl, best.json,
report.md, final_mean_genome.json).

## Setup
- Code at commit 53ad743 (v8 defaults), in a separate worktree so peers' edits could not change the run.
- CMA-ES-style search over the 10-gene strategy genome of the largest founding party ("auto"), 11 genomes per
  generation × 2 seeds × 40-year games, 12 parallel workers, 7 hours: **12 generations, 264 scored games, 0 failures**.
- Score per game (run_game.gd): a mix of vote share, seats, months as First Minister's party and months in Cabinet.
  Each genome is scored as its **advantage over the default party** (all genes 500) on the same seeds, so seed luck
  cancels out within a generation.

## Score curve (advantage over the default party)

| Gen | Seeds' default score | Best | Mean of the generation |
|---|---|---|---|
| 0 | 26 / 41 | +8.2 | +3.2 |
| 1 | 30 / 38 | +3.8 | +0.8 |
| 2 | 43 / 48 | −5.5 | −7.2 |
| 3 | 26 / 32 | +5.0 | +1.3 |
| 4 | 42 / 40 | +3.8 | −0.9 |
| 5 | 26 / 45 | +8.1 | −0.2 |
| 6 | 38 / 30 | +2.8 | −0.6 |
| 7 | 44 / 23 | +5.4 | +0.1 |
| 8 | 35 / 35 | +8.4 | +4.2 |
| 9 | 37 / 36 | +11.6 | +4.5 |
| 10 | 30 / 41 | +14.3 | +5.3 |
| 11 | 28 / 34 | +25.5 | +11.0 |

Flat and noisy for 8 generations, then a clear climb. Gen 2's dip came from seeds where the default party already did
very well (43 and 48), leaving little room. The search had not converged when time ran out (sigma 0.14).

## Validation on fresh seeds
The final search mean against the default party, 6 seeds never used in the search (2001–2006), 40 years each:

| Seed | Default | Learned | Difference | Months as FM's party (share) |
|---|---|---|---|---|
| 2001 | 20.5 | 19.7 | −0.8 | 6% → 0% |
| 2002 | 36.4 | 36.4 | +0.1 | 12% → 13% |
| 2003 | 34.7 | 46.2 | +11.6 | 11% → 33% |
| 2004 | 29.9 | 40.4 | +10.5 | 11% → 25% |
| 2005 | 34.5 | 44.3 | +9.9 | 11% → 22% |
| 2006 | 31.2 | 32.8 | +1.6 | 21% → 21% |

**Mean +5.5 (sd 5.8), better in 5 of 6 seeds; vote share up about 2.4 points on average.** The learned strategy is real,
not seed luck, but it is a moderate edge, not a game-breaking one. (Godot crashed on exit in some runs after printing
the score; the known engine-exit crash, no data lost.)

## The winning strategy

| Gene | What it does | Learned (500 = today) | Effect, 500 → 1000 |
|---|---|---|---|
| G_PORK | election-year spending pressure while governing | **944** | +4.3 |
| G_UNION | courting the unions (+10 union score at 1000) | **968** | +2.9 |
| G_COALITION | willingness to compromise in coalition talks | 544 | −2.6 |
| G_DISCIPLINE | damping the party's internal factions | **926** | +1.9 |
| G_RESEARCH | sharper polling picture | **773** | +1.5 |
| G_SPEND | campaign spending rate | **158** | −1.2 |
| G_NEGATIVE | negative campaigning | 405 | +1.2 |
| G_ISSUE | chase voters' worries vs own issues | 446 | +0.6 |
| G_DRIFT | how fast positions follow voters | 465 | +0.6 |
| G_PACE | legislative pace | 675 | +0.3 |

(Effect: linear fit over all 264 games; it reads across genomes, so a gene can have a negative fitted effect yet sit near
500 in the final mean, as G_COALITION does.)

In words: **govern with election sweeteners, tie yourself to the unions, keep the party disciplined, poll well, and
spend little on the campaign itself.** That resembles real winning parties (Scandinavian social democracy: union link,
discipline, pre-election budgets), which is reassuring, but three of these genes cost the party nothing in the game,
and that is why they max out.

## Exploit candidates for the A52 bias report

1. **G_UNION is free (strongest exploit).** UnionPolitics.score adds up to +10 for courting the unions, with no cost:
   no lost business donations, no loss of market-leaning voters, no union demands to honour. Fix: courting unions should
   cost business money and trust with employer-minded voters, and bind the party to union demands (a broken promise
   becomes a grudge).
2. **G_DISCIPLINE is free.** Damping faction discontent by up to 40% has no downside. Real discipline costs internal
   debate, talent (defections of the able), and responsiveness. Fix: discipline raises the chance that a suppressed
   faction splits off in one go when it does break, or slows the party's drift toward its voters.
3. **G_RESEARCH is free.** "Polling money buys a sharper picture", but no money is spent. Fix: charge it to the
   party's funds per month, scaled by the gene.
4. **G_PORK pays off strongly** (follow-up 2026-11-14, Ella's check, 3 seeds × 40 years, gene 0 vs 1000 for all
   parties: sweeteners barely move the First Minister's party's vote and the bill reaches voters only faintly through
   GOVERNANCE satisfaction; the optimiser's gain was probably noise, so not a live exploit). Election-year spending is real politics and its cost lands on the treasury, so this is
   partly intended realism. Check whether voters ever punish the deficit afterwards; if the bill never arrives at the
   ballot box, this is an exploit too.
5. **G_SPEND low wins: campaign money buys too little.** The learned party spends a third of the default rate and
   does better, so its savings are worth more than ads. Either campaign spending is too weak, or a war chest is too
   useful (e.g. for later elections or debt-free credibility). Worth a look with Ella.

Nothing at an extreme looked like a bug (no crash, no ledger break, no gene that wins by breaking a rule).

## Recommendations
- Fix exploits 1–3 (costs for union courting, discipline and research). Small, in campaign.gd, union_politics.gd,
  party_life.gd and intel.gd; Ella's and my areas.
- Check 4 and 5 with Ella before changing anything.
- Re-run the optimiser after the fixes and on the v9 defaults, ideally for longer (it had not converged) and with
  3 seeds per genome to cut noise. If the next winner sits at a sensible interior point, the strategy space is healthy.
- L1 (the in-game learning party) can now be tried: the overnight run shows there is a real gradient to learn.
