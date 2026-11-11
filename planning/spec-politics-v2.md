# Politics v2: a living party system (M9)

Owner: Wilma (politics). Contributions: 88 (interest groups, economy side) and a9 (party-finance law, scandals).
Status: started 2026-11-11.

## 0. Why

We measured three 25-year integrated runs: always exactly the same 5 parties from month 24 to month 300. No party was ever founded, split, merged or dissolved. Leaders are only names. Opinion moves only through indicators, blame facts and slow drift. Coalitions do rotate, which works, but the party landscape is frozen.

## 1. Leaders (politics)

Each party has a leader: `{name, charisma 0..100, competence 0..100, integrity 0..100, faction, since, popularity 0..100}`.
- **Utility term:** `+ BETA_LEADER * (popularity - 50)/50`, where `BETA_LEADER = 0.35`. Popularity drifts monthly toward `0.5*charisma + 0.3*competence-in-office + 0.2*integrity`, and scandals hit it.
- **Competence:** a PM's competence scales drafting quality and reduces "bad news" blame.
- **Leadership contest:** after an election where the party loses at least 3 points, or after a scandal that drops popularity below 25. Candidates come from each faction, and the winning faction moves the platform toward its pole (15% of the faction gap).

## 2. Factions (politics)

Each party has two factions, split on the axis where its own voters are most spread (the voter-weighted SD of `prev_share` cells).
- Faction positions sit at the party position ±(voter SD) on that axis. A faction's `strength` is the voter share on its side.
- The leader belongs to one faction. The losing faction's `discontent` grows when the party compromises in coalition (agreement items against its pole) or loses votes.

## 3. Party lifecycle (politics)

| Event | Trigger | Effect |
|---|---|---|
| **Founding: unrepresented** | at least 4% of voters are more than 28 pts from every party | new party at their mean |
| **Founding: protest/populist** | colony GOVERNANCE satisfaction below 40 and mean approval of the last two governments below 45 | anti-establishment party: positions at the disaffected voters' mean, INSTITUTIONS pulled toward "strong executive", big ownership of GOVERNANCE/FAIRNESS, starts with charisma 70+ |
| **Founding: single issue** | a movement's concern stays below 35% satisfaction for 24 months | party that owns that concern at 90 |
| **Split** | faction discontent of 70+ for 6 months and faction strength at least 25% | the faction leaves with seats ∝ strength, founds a party at its pole, and both get a credibility hit |
| **Merger** | two parties within 15 pts where at least one polled under 4% in the last two polls | the smaller one merges; the platform is the support-weighted mean |
| **Dissolution** | under 4% in two elections in a row, or after a merger | `DISSOLVED`; loyalty passes to the nearest party |

Splits and mergers between elections change `seats` immediately, so the government can lose its majority. That feeds GovCrisis, so splits can topple governments.

The maximum is 9 active parties, and the player's party never dissolves. The player's party *can* split, which is the player's main internal-party threat.

## 4. Opinion dynamics (politics)

- **Agenda-setting:** a public fact with magnitude 60 or more adds a salience boost to each concern it impacts (`boost += |impact| * magnitude/100 * 15` per-mille). The boost halves every 3 months. Scandals and strikes become the topic of the month.
- **Social influence:** each month a cell's ideology moves 1% toward its district's population mean. Districts develop political identities.
- **Zeitgeist / generational replacement:** each value cohort's offset does a slow random walk (SD 1.5 pts/year/axis, stream `pol.zeitgeist`), and `base` follows it. Colonies drift over decades.
- **Interest groups** (§5) endorse parties and mobilise turnout: an endorsed party gets a utility bonus among the group's members (`+0.3 * group strength`), and member turnout gets +3pp.
- **Campaigns:** in the 6 months before an election each party spends its funds. Effort goes to the concerns it owns with the highest salience. `campaign[pid] = clamp(spend / colony_avg_spend, 0, 2) * 0.5`, through the existing `ctx.campaign` hook (unused until now).

## 5. Interest groups (88 economy side, politics consumption)

Groups: `UNION` (one per producing sector, or a single confederation), `BUSINESS` (federation of companies), `ENVIRONMENT` (citizens' group, politics-owned), `FARMERS`.
- **88 publishes:**
  - Indicator `ECON_UNION_DENSITY` per occupation (0–100000), driven by labor levers and sector size.
  - Facts `ECON_STRIKE` (PUBLIC, `responsible` = government when wages fall behind prices or labor law moves against workers) and `ECON_LOCKOUT` / `ECON_LAYOFFS_MASS`.
  - Table `donation_offer` (written in SETTLEMENT): `{from: company_id, amount_milli, prefers: {axis: sign}}`. Company donations are funded from company cash. Companies donate when their profits are exposed to political levers.
- **Politics:** each month it matches offers to parties by `prefers`, books a ledger transfer company → `party:<id>`, and records a `POL_DONATION` fact. The fact is SECRET above the disclosure threshold if law allows hiding it, otherwise PUBLIC.

## 6. Party finance and scandals (a9 law/justice side)

- **Levers** (law owns them; politics reads them):
  - `LAW_DONATION_CAP` (NUMBER, per donor per year; 0 = no cap)
  - `LAW_DONATION_DISCLOSURE` (ENUM NONE/ABOVE_THRESHOLD/ALL)
  - `LAW_PUBLIC_PARTY_FUNDING` (NUMBER per seat per month, paid from the treasury)
- **Justice:** investigations can target `{kind: "PARTY", id}` and `{kind: "LEADER", id}`.
  - Revealing a SECRET `POL_DONATION` that breaks the cap gives `POL_SCANDAL_REVEALED`, which hits the party's credibility and the leader's popularity and can trigger a leadership contest.
  - a9 also decides: can a convicted leader keep the post (law lever `LAW_CONVICTED_CAN_HOLD_OFFICE`)?

## 7. Exit criteria

- 40-year integrated runs, 6 seeds, measured by `tools/measure_party_system.gd`:
  - at least one new party in at least 4/6 runs;
  - at least one dissolution or merger in at least 3/6;
  - at least one split in at least 2/6;
  - active parties stay between 4 and 9 at all times;
  - at least 2 leadership changes per run.
- Determinism and save/load round-trip still pass.
- The UI shows leaders, factions and lifecycle events.
