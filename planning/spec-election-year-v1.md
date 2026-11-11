# Election Year: Spec v1 (DRAFT, awaiting Wilma's sign-off)

**Owner:** Ella (election year & campaigns), under Wilma (politics/admin) · **Status:** approved by Wilma; v1 implemented 2026-11-11 (`sim/politics/campaign.gd`, 12 tests, gates pass). Not yet built: §2.6 pork (touches Legislature), campaign-season polls, the bandwagon/underdog term beyond poll momentum · **Date:** 2026-11-11

## 0. Why

Today the election is a quiet count. In the 6 months before it, each party spends 30% of its funds every month, and relative spending becomes `+0.6 · campaign` utility (`party_life.campaign_monthly`, `campaign_ctx`). Voters never see an ad, a debate, an attack or a gaffe. The only scandals are illegal donations (a9, `party_finance.gd`). The user rates this as a very low politics grade. Election year should be the loudest, most dramatic part of the four-year cycle, and the player should make real choices in it.

## 1. The calendar (Swedish valrörelse)

Elections are held in September, in month `next_election`. Counting backward (T = months before the election):

| T | Phase | What happens |
|---|---|---|
| 12 | **Election year opens** | Parties set their **campaign theme** (1–2 owned concerns). Budget review: what the party can afford. |
| 12–4 | **Long campaign** | Positioning bills ("valfläsk", election pork: the government proposes popular spending), opposition research, early ads. |
| ~2 (July) | **Politics week** (Almedalen-style) | Every leader gives a speech: one charisma/competence check each, and it sets the summer narrative. |
| 2–0 | **Short campaign** | Election huts (valstugor) and canvassing, posters, ads in full, weekly polls, the **leaders' debates**. |
| 0 (final week) | **Final debate** (slutdebatten) | The last big swing. Late dirt (an "October surprise") lands here. |

Extra elections (`run_election(extra=true)`) get a compressed 3-month version.

## 2. Campaign mechanics (all deterministic on seeded streams `pol.campaign.*`)

### 2.1 Campaign theme / framing
- Each party picks up to 2 concerns to push. Pushing raises the concern's **salience** among the cells reached (it reuses the `agenda_boost` path but per party), so a party that *owns* the concern gains through the existing ownership term.
- The campaign war is a war over which issue the election is about. The government wants its successes salient; the opposition wants the failures salient.

### 2.2 Ads and posters (persuasion)
- Spend buys **reach** into target segments (district × occupation; mass ads are cheap and broad, targeted ads are pricier and focused).
- Effect per reached cell: a small utility term `BETA_AD · quality · fit`, where fit = the party's ownership of the ad's concern × cell salience. Effect wears off (diminishing returns: log of spend).
- Ad **quality** = the campaign lead's skill (a9's `STAFF_T_CAMPAIGN` → `campaign_effort`).
- Replaces the flat `campaign_ctx` (keeps it as a fallback when no plan exists).

### 2.3 Ground game (mobilisation)
- Canvassing, election huts and rallies raise **turnout** among the party's own leaners (cells where the party has the highest probability) instead of persuading. Unions/interest groups (88's endorsements) add volunteers.
- A turnout term per party per cell in `VoteModel.turnout`: today turnout is per cell, not per party; the vote model needs a small change here (see §5).

### 2.4 Debates
- Leaders' debates (2–3 in the short campaign + the final debate). Each leader rolls `performance = f(charisma, competence, prep staff) + noise`.
- Outcomes: winner/loser **momentum** (a decaying utility bonus, ±0.1–0.3), **gaffes** (rare, competence-driven, a news fact with magnitude ≥ 60 so it also sets the agenda), and **killer lines** (attacks that land on a rival's weak spot, e.g. broken promises, low credibility).
- Facts `POL_DEBATE_HELD` {winner, loser, gaffes} PUBLIC.

### 2.5 Negative campaigning and dirt
- **Attack ads:** target a rival on a concern where it is weak, or on broken promises (`_score_promises` data) → lowers the rival's utility among reached cells, **but backfires** on the attacker among cells that dislike negativity (risk scales with how dirty the attack is and the attacker leader's integrity).
- **Opposition research:** a party can pay staff to dig into a rival. Chance per month to surface something:
  - real, already-SECRET facts about the rival (illegal donations, `POL_DONATION` SECRET; a9's justice records) → handed to a9's existing scandal path (`POL_SCANDAL_REVEALED`, channel `OPPO_RESEARCH`);
  - minor personal dirt about the leader (new, small: popularity hit, credibility −).
- **Timing choice:** dirt can be held and released late (bigger swing, no time to recover), but held dirt risks leaking as "they sat on it", which hurts the holder.
- **Smears without substance:** possible for low-integrity leaders; if exposed (a fact-check chance), a large backfire and a scandal for the smearer.

### 2.6 Election promises and pork
- The government can schedule popular clauses for the election year (`Legislature`). Voters discount obvious pork by the party's credibility (low credibility = little gain).
- Campaign promises become the party's **agenda** for the next term (reusing `agenda` / `_score_promises`), so lies in the campaign cost credibility in four years.

### 2.7 Momentum and polls
- Weekly-ish polls in the short campaign (`run_poll` already exists). A **bandwagon/underdog** term: small utility for rising parties; tactical **support votes** for small allies near the 4% threshold (Swedish "stödröster"), which is very real in Sweden.

## 3. AI parties
A campaign planner per party: choose themes (owned concerns × current salience × the government's record), split budget across ads/ground/oppo, decide attack targets (closest rival competing for the same voters), hold or release dirt. Leader integrity limits how dirty a party plays.

## 4. Player actions (PolActions + a Campaign panel)
Choose themes, set the budget split, approve attack ads, order opposition research, release/hold dirt, prep the leader for debates (assign staff), promise things (agenda). The panel shows the calendar, polls, debate results and a feed of campaign events.

## 5. Integration points (need Wilma's OK: her files)
- **New file** `game/sim/politics/campaign.gd` (Ella's), plus `game/tests/politics/test_campaign.gd`.
- `politics_provider.gd`: call `Campaign.monthly(world, st)` instead of `PartyLife.campaign_monthly`; pass the per-cell campaign context into `vote_shares`.
- `vote_model.gd`: `ctx.campaign` becomes per-cell (party → utility) instead of colony-wide; turnout gets a per-party mobilisation term.
- a9: a new scandal channel `OPPO_RESEARCH`, and the `STAFF_T_CAMPAIGN` effort output as ad quality.
- 88: ad/canvassing spend stays in the closed economy (already paid to households).
- **Scope conflict:** media is post-v1 (A3, X12). Ads and debates need a thin "campaign coverage" channel; I propose public facts only, no newspapers/outlets. That needs Wilma's ruling.

## 6. Exit criteria (measured with a new `tools/measure_campaigns.gd`)
- Over 6 seeds × 40 years: the campaign moves at least one party by ≥3 pp vs the T−12 poll in ≥50% of elections.
- ≥1 debate gaffe and ≥1 oppo-research scandal per seed; ≥1 backfired attack per 3 seeds.
- The player can change the outcome by campaign choices (scripted test: same seed, a good campaign vs no campaign, ≥2 pp difference).
- Determinism and save/load round-trip still pass; the campaign doesn't break the party-system gates (`measure_party_system.gd`) or turnover (`measure_turnover.gd`).

## 7. As built (v1, 2026-11-11)
- Calendar: opens at T−12 (T−3 for extra elections); short campaign at T≤2; politics week in July; leaders' debate at T−1, final debate in the election month before the vote.
- Spending: 8%/month of party funds in the long campaign, 30% in the short one, split across ads, ground game and opposition research by tone (POSITIVE/MIXED/NEGATIVE presets, or the player's choice). All of it goes to households.
- Effects reach the vote as a per-voter utility term `campaign_u` (segment persuasion + momentum + civility backfire by archetype, capped at ±0.8) and as a per-party turnout multiplier (≤ +6%, +1.5% for the union-endorsed party).
- Dirt: real hidden donations are revealed through `PartyFinance.reveal_by_rival` (Anni). Personal dirt is one story per leader per campaign. Smears come only from campaigns that are negative and low-integrity (leader integrity ≤35); if exposed, the victim sues via `JusticeOps.file_defamation`, and a guilty verdict costs −8 credibility.
- Support votes: a governing ally between 2.5% and 4% borrows up to 8% of its largest partner's voters (to 4.3%).
- Measurement (`tools/measure_campaigns.gd`, counterfactual on the eve of the vote; 3 seeds × 25 years): campaign effect ≥3 pp in 12/18 elections, median 4.0 pp, max 6.2 pp; turnout 78.6–85.1%.
