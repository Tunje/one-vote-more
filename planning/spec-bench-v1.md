# Spec: The party bench — recruiting, ambitions, election lists (v1)

User decision 2026-11-13 (A51): "How will we handle the people, will each party have ten you can pick from?" → the
bench exists (6 + 1 per 10 seats, +3 newcomers per election); the user asked for all three additions.

Owners: **Anni** B1, B2 (staff: recruiting, people's ambitions), **Ella + Wilma** B2 politics side (leadership
challenges, defections into party life), **Wilma** B3 (election lists, the Assembly link) and UI. Integer state;
deterministic; save/load.

## B1. Recruiting for your party (Anni)

- A party can **recruit** onto its bench, not only receive the 3 newcomers per election: a recruitment drive
  (costs party money and the party secretary's time) produces a shortlist of prospects (from unions, companies,
  the civil service, local notables, the press, a sister colony later).
- For the player's party, prospects are **interviewed at the door** exactly like civil servants (A44 O5: hidden
  traits, questions, bluffing, references); AI parties pick by their merit rule and party fit.
- Prospects have a **source** that colours their ties (a union organiser brings union ties; a company manager
  brings donors and business ties) and their leanings.
- The bench has a soft cap by party size and money; recruiting beyond it costs more.

## B2. Ambitions (Anni with Ella/Wilma)

- Every bench member has an **ambition** (office, leadership, a cause, money/quiet life) and **loyalty** to the
  leader and to the party line, which move with events: passed over for a portfolio, scandal, the party losing,
  disagreement with the line.
- What ambitious or disloyal people do:
  - **challenge the leader** (feeds Ella's leadership contests and congresses — a named challenger from the bench);
  - **defect** to a party closer to their views or with better prospects (taking some voters' trust and possibly a
    seat's worth of personal following);
  - **leak** to the press or the opposition;
  - **retire** (age, burnout, a quiet life) — the bench ages with the population model.
- Satisfied, loyal people stay and grow (skills improve with work, as today).

## B3. The bench is the party's election list (Wilma)

- Before each election a party ranks its bench as its **list**: the top names are its public faces (leader first),
  and the people elected from the top of the list hold the Assembly posts (party whip, committee chairs later) and
  are the pool for its Cabinet seats.
- A party with a thin or weak bench struggles to fill both its Cabinet seats and its top Assembly positions —
  weaker ministers, a worse picture (A49), more scandals.
- Popular, skilled names at the top help a little at the polls (a small candidate-quality term in the vote model);
  a scandal-hit name hurts.
- Player: arrange your party's list before the election (an office item from the party secretary).

## Acceptance

- Parties recruit; benches change composition over a century (sources, ages, retirements).
- Defections and leadership challenges by named bench members happen and have causes in the record.
- A thin bench visibly weakens a party's Cabinet (minister skill) and its polling a little.
