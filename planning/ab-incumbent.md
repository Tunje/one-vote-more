# A/B: the First Minister's party losing too much (Ella, 2026-11-15)

Wilma flagged that the First Minister's (FM) party lost 9–19 points per election. The target (Wilma): a loss of about
2–5 points on average, with approval centred near 50 over a century. The user then decided on rivalries (2026-11-15):
"Parties with opposite positions become rivals, they will target each other even if they are not governing."

The best version is in the shared tree for v11. Each part is opt-in, so the base is unchanged until the v11 defaults are switched:

| Flag | What it does | Files |
|---|---|---|
| `TREND2` | Centred approval trend: approval only moves when performance leaves its 12-month range (a new high or a new low); wobble inside the range counts as nothing. | sim/politics/politics_provider.gd |
| `RULE_COST3` | Cost of ruling 0.03 utility per year in office instead of 0.06. | sim/politics/pol_defs.gd, politics_provider.gd (`_rule_cost`, ctx `rule_cost`), vote_model.gd |
| `RIVALRY` (Wilma's flag, adfe628) | Campaign targets by `Rivalry.score` only (opposite positions plus grudges), in or out of government. No FM bonus (`RIVAL_PM_BONUS` 0), no competitor bonus, no size weight; parties skip targets with no seats and under 2% support (`RIVAL_FLOOR`). Martyr and scandal-heat rules kept. Released dirt makes the target hold a grudge (`Rivalry.on_attack`, 30 per severity-50 story). Questioning a bad government decision gives the questioner momentum (+40, government −20); carping at an ordinary decision costs the questioner −10. | sim/politics/campaign.gd, sim/politics/rivalry.gd |

Tests: tests/politics/test_campaign_rivalry.gd (4), tests/politics/test_incumbent_v11.gd (3); test_campaign and
test_politics green.

## Method

- Tool: scratch decomposition, run 60 years × seeds 1–4, giving 56 FM elections per arm.
  - For every election it gives the change in each party's vote share.
  - That change is split into model terms: distance, performance verdict, cost of ruling, issue ownership, loyalty,
    credibility, campaign, endorsements, leader.
  - It also gives the counting gap (turnout) and the election-day shock.
- Landslide check: seeds 1–3, the largest party's share at the first two elections (years 4 and 8). The earlier bug
  gave first elections above 50%.
- Every arm runs on the current shared tree.

## Results

FM party loss = change in the FM party's vote share per election, in points. Approval relative to 50 is the
population-weighted century mean.

| Arm | FM party loss | Approval −50 | Landslide check (max of the first two, seeds 1–3) |
|---|---|---|---|
| Before (fix 1 only, cost 0.06) | −12.75 | −11.7 | 33 / 38 / 49 |
| Cost of ruling 0.03 | −11.2 | −12.0 | 33 / 38 / 49 |
| ATTACK_CROWD 0.5 (weaker pile-on) | −12.45 | n/a | n/a |
| Trend: drop the ×1.5 on losses | −10.25 | −8.9 | 32 / 37 / 48 |
| **TREND2 + RULE_COST3** | −10.33 | −3.25 | 41 / 28 / 36 |
| … + AIMED_FATIGUE (repeat attacks count less) | −10.32 | −2.6 | 30 / 31 / 41 |
| … + RIVALRY with FM bonus 0.35 and competitor bonus | −12.32 | −2.7 | 39 / 31 / 40 |
| … + RIVALRY, FM bonus 0.1 only | −10.71 | −3.07 | 37 / 30 / 39 |
| **… + RIVALRY pure (v11)** | **−9.11** | **−2.94** | **34 / 30 / 39** |

No arm produces a first-election result above 50%.

Target counts: each party's target in the last campaign month, as a share of picks. "Positive" means it ran no attack.

| Who aims | Arm | at FM party | at largest opposition | at other Cabinet parties | at others | positive |
|---|---|---|---|---|---|---|
| Opposition | off | 66% | – | 4% | 9% | 22% |
| Opposition | pure | 22% | 12% | 20% | 38% | 8% |
| Opposition | FM bonus 0.1 | 60% | 2% | 1% | 20% | 17% |
| Largest opposition party | off | 52% | – | 4% | 11% | 34% |
| Largest opposition party | pure | 12% | – | 5% | 57% | 25% |

- With pure rivalry the opposition fights itself, as the user described.
- Any FM bonus brings back the gang-up on the governing party, because Rivalry.score values sit close together.

## What is left of the FM party's loss (pure arm, −9.1 points)

Model terms for the FM party: the change between its two elections, relative to the field, in utility units. Read the sizes against each other; I have not converted them to points.

| Part | Term | Note |
|---|---|---|
| Campaign | −0.147 | Only 22% of opposition fire now aims at it, so this is not about targeting. About a quarter is regression from its own strong campaign at the election it won (+0.06 then). Not yet measured: debate killer lines, questioning hits, and its own campaign more often positive. |
| Cost of ruling | −0.112 | Already halved by RULE_COST3. |
| Performance verdict | −0.097 | The record in government. |
| Issue ownership, endorsements, leader, credibility | −0.14 together | |
| Loyalty | +0.080 | Offsets. |
| Not in the model terms | −1.2 points | Regression of election-day luck: the winner had about +2 shock at the election it won. Turnout gap ≈ 0. |

## The real-world benchmark

Change in the vote share of the First Minister's party, Swedish Riksdag elections 1982–2022. Figures are from the
official results (Valmyndigheten / SCB), written from memory; please check them at val.se before relying on them.

| Election | Governing party | Change |
|---|---|---|
| 1982 | Centre (Fälldin) | −2.6 |
| 1985 | Social Democrats | −0.9 |
| 1988 | Social Democrats | −1.5 |
| 1991 | Social Democrats | −5.5 |
| 1994 | Moderates | +0.3 |
| 1998 | Social Democrats | −8.9 |
| 2002 | Social Democrats | +3.5 |
| 2006 | Social Democrats | −4.9 |
| 2010 | Moderates | +3.8 |
| 2014 | Moderates | −6.7 |
| 2018 | Social Democrats | −2.8 |
| 2022 | Social Democrats | +2.1 |

- **Mean −2.0 points**, range −8.9 to +3.8, and 4 of 12 elections were gains.
- Wider set: the "cost of ruling" literature puts the average government vote loss in established democracies at about
  2–2.5% per election (Paldam 1986; Nannestad & Paldam 2002). That is for the whole government, not only the largest
  party.
- So the 2–5 point target sits on real data, and the mean is at its lower end. The best v11 arm (−9.1) is still about
  twice the worst normal Swedish result.
- In the model, FM-party gains happen too, but rarely. Not yet counted per arm.

## Not done

- **AIMED_FATIGUE:** no effect, so it was left out.
- **Next candidates, if the user keeps the target:**
  - the FM party's own campaign (why its tone is more often positive);
  - debate killer-line vulnerability for a governing party;
  - the leftover issue-ownership and endorsement drift.
