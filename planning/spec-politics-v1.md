# Political Core: Spec v1 (D1, as built in M2)

**Owner:** Wilma · **Status:** implemented on the stub world (`game/sim/politics/`), 15/15 tests green · **Date:** 2026-11-10
Code is the source of truth for exact constants (`pol_defs.gd`). This doc explains the model and lists its interfaces.

## 1. Voter cells (pic-core §1)
- `cell[key]`, key `district|OCC|BAND`. Population comes from `world.table("census")`, written in SOCIAL by econ (or the stub).
- Each cell has:
  - `base` ideology: the occupation table, plus the income-band shift, plus seeded ±8 noise. All vectors are stored as **int milli-points**.
  - `ideology`, which drifts each month: if a concern is less than 50% satisfied, it pulls on the linked axes (`CONCERN_PULL`). Cells with a right-leaning base radicalise rightward instead. There is also a 1%/month reversion to base.
  - `sat[concern]`: the weighted mean of normalised indicators that declare that concern, read with their `perceptionLag`.
  - `salience`: the occupation base × (1 + 2 × unmet), renormalised to 1000.
  - `approval` (0..100000): EMA 0.85/0.15 of `0.6·perf + 0.4·(50 + 2.5·Δperf₁₂)`, plus blame/credit from this month's PUBLIC facts with GOVERNMENT/COMMANDER responsibility (`impact × salience × share × 400`).
  - `prev_share`: last election result, int per 100000.

## 2. Parties
- **Movements:** in Years 1–2, a concern that is < 45% satisfied colony-wide for 6 consecutive months creates `POL_MOVEMENT_FORMED`, with the COMMANDER blamed.
- **Formation:** month 24 (Year 3).
  - The player party "Founders' Party" sits at the **commander's revealed ideology**. Each ordinance adds `lever.ideology slope × Δ × 300` milli-points.
  - The other parties come from pop-weighted k-means (with the player's center fixed and farthest-point initialisation), exaggerated 15% from the colony mean.
  - k = 4, or 5 with ≥3 movements, giving ≥5 parties in total.
  - Each movement adds +40 ownership of its concern to the party most credible on it.
- **Party fields:** `positions`, `ownership{concern:0..100}`, `commitments[{lever, dir, kind CORE|NEGOTIABLE, weight}]` (A9; alignment of the lever's ideology slope with the position, CORE ≥ 40, NEGOTIABLE ≥ 15), `credibility`, `agenda`, `seats`, `support`, `status`.
- **Adaptation:** every January, AI parties (and an autoplayed player party) move 10% toward their own voters' mean.
- **New parties:** if ≥6% of voters are >35 points from every party, a new party is founded (max 8 active).
- **Dissolution:** a non-player party under 2% in two consecutive elections dissolves.

## 3. Voting (multinomial logit per cell)
`U = −0.045·dist_w + 1.4·govShare·(approval−50)/50 + 3.6·Σ salience·ownership·unmet + 0.4·ln(0.15+prev) + 0.5·(cred−50)/50 + 0.6·campaign + shock`
- `dist_w` is a weighted L1 distance; axis weights rise with the salience of linked concerns.
- In the founding era, the commander's record counts as the player party's government record.
- Turnout is 84%, minus alienation (nearest party > 25 points) and anger (approval < 30), clamped to 40–95%.
- Election-day shock: σ = 0.15 utility per party, from the `pol.election` stream.
- **Polls** run quarterly: true intentions + N(0, MoE/1.96) per party, renormalised. MoE defaults to 3 pp; staff quality overrides it (S6).
- **Seats:** Sainte-Laguë with first divisor 1.2, 4% threshold, 151 seats (A5).

## 4. Government formation (negative parliamentarism)
- Candidate cabinets are every subset of ≤3 seated parties.
- A member refuses if it is >50 points from the cabinet's seat-weighted centre.
- Outside parties vote **NO** if they are > tolerance (45, +10 per failed round) from the centre. The PM is approved unless NO ≥ 76.
- Score = `min(yes,76)·0.5 − surplus·0.35 − spread·0.6 − 8·(n−1) + 10 if it includes the plurality party`.
- Support parties: outsiders within 30 points.
- **Agreement:** lever directions where the members' seat-weighted commitments sum to |≥1500|.
- After 4 failed rounds: `POL_FORMATION_FAILED`, a caretaker government, and an extra election in M7.

## 5. Legislation (A9 / J4)
- Every 3 months the government (or the commander in the founding era, as ordinances with no vote) proposes ≤2 clauses. Each clause moves a NUMBER lever by 10% of its range.
- Clause score = ideological alignment with the proposer + 3 × concern relief (lever `concerns` hints × unmet × salience) ± agreement.
- Party vote = alignment + 1.5 × relief ± commitments (CORE 12, NEGOTIABLE 5) ± agreement (members) + 15 discipline (members) / +4 support / −4 opposition. YES if > 2, NO if < −2. Passes if YES seats > NO seats.
- **Hand-off to law:** `world.table("enactment")[id] = {id, lever, value, legal_level ORDINANCE|LAW, source_bill, decided_month, earliest_effective_month, status:"PENDING"}`. Law (currently `StubLawProvider`, later a9's LawProvider) is the only writer of `world.levers`.
- **Promises:** a party's agenda is its top 3 commitments. At the next election, governing parties' credibility = 0.5·old + 0.5·(20 + 70·kept ratio).

## 6. Lever contract additions (for 88/a9)
Levers that politics should be able to change need: `type: "NUMBER"`, `range`, `ideology {axis: slope per unit}`, and **`concerns {concern: signed effect per full range}`**. The last is the AI hint for expected relief. Without it, AI governments only legislate on ideology.

## 7. Turnover tuning (2026-11-10)
The problem: 6 PM changes in 18 runs × 20 years, approval stuck at 61–70%, and 0 defeated bills. Changes:
- **Loss aversion:** concern satisfaction below 50% counts 1.8× (`LOSS_AVERSION 0.8`). Falling 12-month trends count 1.5×.
- **Expectations:** `cell.expect` is a 36-month EMA of approval. The retrospective term is `1.4·govShare·((appr−expect)/20 + (appr−50)/100)`.
- **Cost of ruling:** −0.06 utility per year in government (consecutive tenure in `state.tenure`), capped at 0.5.
- **Opposition** −9 (was −4); **support parties** +1 (was +4).
- **Negotiation:** if the full bill is predicted to fail, the government drops to the best single passable clause.
- **Floor-vote noise:** non-member parties get N(0, 9) on the real vote (stream `pol.vote`). Predictions are noise-free, so governments sometimes miscount.

**Result** (`tools/measure_turnover.gd`, 16 runs × 20 years):

| Metric | Result |
|---|---|
| Runs with a PM change | **16/16** |
| PM changes | **42** (≈2.6 per run, about one every second election) |
| Defeated bills | **7/417** |
| Approval range | 37–75% |
| Player seats | 14–66 |

## 7b. Distinct parties, votes by substance (A21)
Measured with `tools/measure_party_spread.gd`: parties were within 7–24 points of each other because k-means centres sit near the middle, and opposition voted by a fixed reflex.
- `PartyGen.exaggerate`: 1.8× spread from the colony mean, ×1.35 on the defining axis, capped at ±65 points. Yearly adaptation targets the exaggerated voter mean.
- Vote: `2.5·ideology + 1.5·relief ± commitments ± agreement + role` (member +15, support +2, opposition −3). Noise N(0, 3).

## 8. Remaining tuning debts
- Approval is still quite stable within terms in calm scenarios. Revisit with the real economy (M4).
- The stub colony leans left. The real economy's demographics replace it.
- Open for M7: player-driven proposals (UI), multi-month formation, no-confidence votes, campaign effort.
