# Spec: Imperfect knowledge — opinion intelligence and policy beliefs (v1)

User decision 2026-11-13 (A49): "Does the AI know what happens before suggesting [a bill]?" + "How do they know what
voters think?" → "Yes" to replacing both cheats.

Today the AI reads the exact average satisfaction and salience of every voter (colony_concerns) and trusts fixed
"effect hints" on every lever; it never looks back at whether its laws worked. Both are perfect knowledge.

Owner: **Wilma** (politics); Anni (staff: advisers' skill), Bob (indicators as evidence), Ella (campaigns read the
pictures later). Integer state; deterministic (stream "pol.intel"); save/load.

## K1. Opinion intelligence: each actor's picture of the electorate

- Every active party, and the government, holds a **picture**: estimated satisfaction and salience per concern,
  updated monthly. It is built from what an actor can find out:
  - **polls and surveys** — noise shrinks with research quality (staff skill, money, size);
  - **its own base** — members and loyal voters (weighted by the party's vote share in each group); a weak research
    operation leans on its base: the **bubble**;
  - **slow uptake** — the picture moves toward the evidence over months, so new anger is noticed late.
- Quality: parties by size and funds; the government by its economic adviser's skill (office roles, A44 O5).
- Use: governments draft bills and judge crises from their picture; each party votes from its own picture; the
  player's vote forecast uses the player party's picture. Elections stay the hard truth.
- Later: media agenda and union/lobby signals shift salience in the picture; commissioned polls as an office action;
  campaigns (Ella) segment from the picture instead of the voters.

## K2. Policy beliefs: what each party thinks a law does

- Every party holds a **belief** per lever: how much of the lever's effect hints it believes (1000 = the hints
  exactly). Initial belief follows ideology: a party that likes a lever believes it works better (up to 1.4), one
  that dislikes it believes it works worse (down to 0.6).
- **The record**: when a law changes, the colony notes the true concern satisfaction then; a year later it measures
  the change in the directions the law was supposed to move them. That is the evidence — public, noisy, and
  confounded by everything else that happened that year (parties can misattribute).
- **Learning**: every party moves its belief toward the evidence; the governing parties that passed the law learn
  more from it; ideology resists — evidence against a cherished belief moves it slowly. So a party can keep
  believing what the colony's own record contradicts.
- Use: drafting relief and floor votes multiply each lever's hints by the actor's belief.
- Later: the advisers' estimate shown on the player's bills (A44 office), opposition and papers quoting the record
  ("the last tax cut didn't create jobs"), credibility loss for repeating failed policies.

## Acceptance

- No AI decision reads colony_concerns directly (the truth is only used to build pictures and the record).
- Pictures differ by party; a low-quality party misreads salience more (measured error larger), and its picture
  lags shifts by months.
- Beliefs move with evidence; a law that kept failing is tabled less often over time; ideology slows learning.
- 100-year check: the politics stays coherent (party field, government formation, bills passed within past ranges).
