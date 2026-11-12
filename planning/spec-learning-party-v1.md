# Spec: A learning party and an overnight strategy optimiser (v1)

User decision 2026-11-12 (A53): "What if we introduced a NumPy model of AI to run at least one party, to see how it
adjusts, adapts and produces? It would find the most effective way of running a party and what wins." → build both
stages, run them overnight (scheduled 2026-11-14 01:00, after the A52 bias audit the night before).

Owner: **Wilma** (party strategy, politics, tools); **Ella** exposes the campaign genes; Bob/Anni untouched.
Machine: Python 3.14 + NumPy 2.4, 28 cores. The sim runs ~8–10 s per simulated year, so stage 2 uses 40-year games
in parallel. Integer state in the world; the Python side is outside the game (tools/ml/).

## L0. The strategy genome (both stages)

A party's strategy is a vector of genes (milli ints in party["strategy"], defaults = today's behaviour = 500):
- G_DRIFT — how fast the platform follows the electorate's centre vs staying with its base (PartyLife adapt);
- G_ISSUE — chase the voters' top worries vs push its own core issues (campaign themes, drafting relief weight);
- G_NEGATIVE — share of campaign effort on attack ads and dirt;
- G_SPEND — campaign spending vs saving (war chest, staff);
- G_COALITION — willingness to compromise to join a Cabinet (tolerance bonus in formation, deal acceptance);
- G_PORK — election-year goodies when governing;
- G_PACE — legislative pace when governing (bill frequency/tinkering tolerance);
- G_DISCIPLINE — party discipline vs internal tolerance (faction discontent damping, leadership challenge risk);
- G_RESEARCH — money into polling/research (A49 picture quality) vs other spending;
- G_UNION — courting unions vs business (endorsements, donations).
Each gene maps to an existing decision point through a small, documented multiplier, so the default genome
reproduces today's behaviour exactly.

## L1. A learning party inside the game (GDScript)

- One party (setting meta.learning_party = party id, or "auto": the largest founding party) adapts its genome
  online: after each election and each January it compares its result (vote share change, seats, months in Cabinet,
  approval when governing) with its expectation and nudges genes along directions that paid off
  (a simple evolution strategy / bandit with exploration noise, deterministic stream "pol.learn").
- Its genome history goes to the chronicle (a section: what the learning party tried and what stuck).

## L2. The overnight optimiser (Python + NumPy, tools/ml/)

- tools/ml/run_game.gd: a headless Godot runner that takes a genome (JSON) for one party, plays a 40-year game on a
  given seed, and prints a JSON score (mean vote share, seats, months as First Minister's party, months in Cabinet,
  approval, survival).
- tools/ml/optimise.py: CMA-ES (NumPy) over the genome; each generation evaluates N genomes × several seeds in
  parallel (subprocesses on the 28 cores), keeps the best, logs everything to tools/ml/out/<date>/.
- Budget: ~300–400 games in one night.
- Output: the winning genome, its per-gene importance, the score curve, and a short report: which strategies win,
  whether they match real politics, and which look like **exploits** (feeding the A52 bias report).
- Optionally a "learned" AI personality preset for a harder opponent.

## Acceptance

- The default genome reproduces today's runs (state hash identical with the genes absent).
- The learning party measurably changes its genome over a century and scores at least as well as a fixed party.
- The optimiser completes overnight and produces a report with the winning genome and exploit candidates.
