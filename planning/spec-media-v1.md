# Media: Spec v1 (DRAFT, awaiting Wilma's sign-off)

**Owner:** Anni (media module, press law), with Wilma (voter side, Gazette UI), Bob (outlet money, company-owned papers) and Ella (campaign coverage) · **Status:** draft · **Date:** 2026-11-12
**Sources:** population.md §17 (PD 17.1–17.6), P10, tests 13–14 · companies.md §14–15 · justiceAndLaw.md §17 · spec-population-v1 §7 / S8 · supersedes X12 / J12 ("media post-v1").

## 0. Why

Today the colony has one neutral newspaper. The Gazette panel builds a front page from last month's PUBLIC facts, and every public fact with government responsibility reaches every affected voter group at full weight (`politics_provider._blame_facts`). Nobody chooses what to print, nobody spins it and nobody lies, so information has no politics of its own.

Media v1 adds **outlets**: papers with owners, an editorial line, credibility, a price and a readership. Each month every outlet picks which facts to run and how to frame them. It can bury stories about its owner, slant blame toward its opponents, and occasionally print something misleading or false. Readers update **perceived** conditions, blame and salience from their own papers, weighted by how much they trust each paper. **Facts never change**: a false report is a separate record, and it can be exposed, corrected and sued over.

## 1. Principles

1. **Facts are ground truth; reports are claims.** A report always points at a fact (or at nothing, if fabricated). Its *frame* says what it claims. No report ever edits a fact.
2. **Media perturbs, it does not replace** (calibration safety). In step M1, voters still see facts the way they do today, and media adds only the *distortion*: the difference between what their papers said and a full, neutral account. With one honest, neutral state paper the media term is about zero, so today's balance holds. Step M3 (reach gating, §7.4) is a separate, measured switch.
3. **Deterministic.** RNG streams `media.cover`, `media.invest`, `media.lie`, `media.expose`. Outlets and leaves are iterated in sorted order.
4. **People are never duplicated.** A leaf has one *news diet*: shares over its outlets plus "none", which sum to 1 (§4.3).
5. **Law decides legality.** Censorship, licensing, defamation and corrections go through the rules engine and the courts (§8).

## 2. Outlets

Table `outlet`, ids `out:N`:

| Field | Meaning |
|---|---|
| `name`, `founded` | e.g. "The Landing Gazette" |
| `owner` | `{kind: STATE \| COMPANY \| PARTY \| UNION, id}` |
| `account` | ledger account `media:out:N` (§9) |
| `line` | editorial position on the 8 axes, milli −100k..100k (same scale as voter ideology) |
| `cred` | public credibility 0..100000, starting at 60000 (a STATE paper under INDEPENDENT governance starts at 70000) |
| `price` | credits per copy-month, a W_ref fraction |
| `quality` | 0..100: journalists and editors (from the staff budget) |
| `sens` | sensationalism 0..1: how much magnitude and scandal outrank substance |
| `ethics` | 0..1: resistance to owner pressure and lying |
| `invest` | investigative capacity, W_ref per month |
| `reach` | distribution: list of districts (all, for the founding paper) |
| `status` | ACTIVE / SUSPENDED (licence) / CLOSED |
| `last_fid` | the last fact id already considered (editions cover "news since the last edition") |

**Owner interests**, derived and never stored:
- COMPANY: the org, plus its sector peers at half weight.
- PARTY: the party, plus its government or opposition bloc.
- UNION: labour and the unionised occupations.
- STATE: the government, but only when `LAW_PUBLIC_MEDIA` = GOVERNMENT_RUN.

### 2.1 Founding and entry

- **Founding:** one STATE paper, "The {Landing} Gazette": line = colony mean ideology, `sens` 0.2, `ethics` 0.8, governance INDEPENDENT. This is today's Gazette, so day one is unchanged.
- **Party papers:** a party with funds ≥ 6 W_ref and at least 8% in the polls may found a paper (AI rule: Wilma's party AI calls `Media.found_outlet`; the player can do the same through a PolActions action). The line is the party's position, `sens` 0.4, and `ethics` follows the leader's integrity.
- **Union paper:** when union density ≥ 30% in at least two occupations, the federation founds one. The line is pulled toward LABOR +40 and REDISTRIBUTION +30.
- **Company papers:** a commercial decision in Bob's firm AI (§9). The line is the owner's interests plus a market position next to the readers no other paper serves. `sens` 0.5–0.7.
- **Exit:** an outlet closes when its account stays below zero for 6 months and the owner will not cover the gap. Outlets can be sold to a new owner (Bob, later). At most 8 outlets at a time (v1 cap).

## 3. Editions: coverage and framing

Each month, in the JUSTICE phase after `PF.run` and `Land.tick`, so that this month's economy and justice facts exist:

### 3.1 Candidates

The candidates are PUBLIC facts with `id > last_fid`, plus the outlet's own investigation results (§6), minus types on a skip list (ledger noise, `*_DONATION`, `ECON_LEVER_EFFECTIVE`). Campaign facts (`data.channel` ∈ RALLY, DEBATE, OPPO, CAMPAIGN) are news. **AD facts are not news**: they are paid space (§9).

### 3.2 Score per outlet

```
news   = magnitude + WEIGHT[type]                (the Gazette's existing table moves into sim/media)
sensat = sens × (scandal/disaster/crime bonus 20, else 0)
slant  = 25 × stance(outlet, fact)               (−1..1; positive when the fact hurts the outlet's opponents)
bury   = 60 × owner_hit(outlet, fact) × (1 − ethics)   (only when magnitude < 70: big stories can't be buried)
score  = news + sensat + slant − bury + noise(media.cover, sd 5)
```

- `stance` compares the responsible actors' positions with the outlet's line. A fact blaming a party or government whose positions are far from the line counts as good copy. A fact crediting them counts as bad copy.
- `owner_hit` = 1 when the owner is a subject or a responsible actor of a negative fact.
- The edition runs the top `K = 4 + quality/20` stories (4–9). Everything else is **not covered by this outlet**. Coverage is per outlet, so a story one paper buries can lead another.

### 3.3 Framing (truth class)

Every printed story gets a **frame**: `blame` (a redistribution of the responsibility shares), `amp` (an impact multiplier) and `truth`.

| truth | What the paper does | When |
|---|---|---|
| ACCURATE | true shares, amp 1 | default |
| SLANTED | moves up to `0.3 × |line distance|` of the blame share between the government and the subject companies or parties; amp 1.0–1.2 | `|stance| > 0.3`; true events, opinionated framing (companies §14.7: "not dishonest") |
| MISLEADING | blame moved by ≥ 0.5, or amp 1.5 | owner or partisan pressure × (1 − ethics) ≥ 0.35 |
| ERROR | wrong blame by accident | p = 0.04 × (1 − quality/100) |
| FALSE | a fabricated claim: no source fact, or the opposite of one | §3.4 |

A frame never changes the fact. SLANTED is legal. MISLEADING and FALSE carry legal risk (§8).

### 3.4 Fabrication

At most once a month per outlet, with

```
p = 0.03 × pressure × (1 − ethics) × (1 + election_proximity) × legal_factor
```

- `pressure`: owner pressure is 1 for party papers in an election year and 0.5 otherwise; company papers whose owner is under investigation get 1.
- `election_proximity`: 1 in the last 3 months before an election.
- `legal_factor`: from `LAW_DEFAMATION_STANDARD`: STRICT 0.4, ACTUAL_MALICE 1.0, NONE 1.6.

A FALSE report invents a damaging claim about the outlet's chief opponent (a party, the government or a company), with impact on 1–2 concerns and a magnitude of 40–60. Publishing it also writes a **SECRET** fact `MEDIA_FALSE_REPORT {outlet, report, victim, deliberate: true}` with the owner and the editor as responsible actors. That fact is the ground truth that the paper lied, and it is what discovery reveals (§5). An ERROR writes the same fact with `deliberate: false`.

### 3.5 Records

- **Table `report`, ids `rep:N`:** `{outlet, month, fact ("" if fabricated), kind NEWS|INVESTIGATION|EDITORIAL|CORRECTION, rank, frame {blame: [{actor, share}], amp, impact {concern: v}}, truth, head_key, corrected_by}`.
- **Table `edition`:** `{outlet, month, reports[], circulation}`.
- **Retention:** 24 months. Reports, editions and the truth class are hidden from the UI (§10), and only exposure reveals them.

## 4. Readership

### 4.1 Appeal of outlet o to leaf l

```
access = 1 if l.district ∈ o.reach else 0
afford = clamp(1 − price / (0.02 × band_disposable(l.band)), 0, 1)   (LOW / MID / HIGH from Bob's band income)
fit    = exp(−dist(l.ideology, o.line) / 60k)                           (weighted by l's own salience, as in VoteModel.distance)
trust  = l.trust[o] / 100000                                            (§4.4)
A(l,o) = access × afford × (0.3 + 0.7 × fit) × (0.4 + 0.6 × trust) × (0.6 + quality/250)
```

### 4.2 Diet

```
diet(l,o) = A(l,o) / (Σ_o A + A_none),   A_none = 0.35
```

`diet(l, none)` is word of mouth: no paper. Shares sum to 1, so nobody is counted twice (PD 17.5).

### 4.3 Where it lives

`l["diet"] = {out:N: permille}` is a **derived** field, recomputed monthly. It is added to PolVoters.DERIVED and PopStore.NON_STATE, so it never mixes on transfer. Circulation per outlet = Σ_l pop × diet. In CELLS mode the same fields live on cells.

### 4.4 Trust per outlet

`l["trust"] = {out:N: milli}` is **belief state**: it mixes on transfer, which is right because trust travels with people.
- It starts at `o.cred × (0.5 + 0.5 × fit)`.
- It drifts 5%/month toward `cred × (0.5 + 0.5 × fit)`. Partisans trust their own papers more (motivated reasoning).
- Exposure of a lie (§5) hits the trust of that paper's readers directly.

## 5. Exposure, corrections and credibility

The SECRET `MEDIA_FALSE_REPORT` facts are found by four paths:

1. **Victim complaint:** p = 0.25/month while the report's magnitude ≥ 40. The victim (party, government or company) has the means and the motive.
2. **Rival debunk:** each other outlet with `invest` ≥ 0.5 W_ref has p = 0.1 × invest/W_ref × (its stance against the liar > 0 ? 1.5 : 1). A debunk is itself a story for the rival paper ("Gazette's mine story was false").
3. **Court:** a defamation verdict (§8.2) always reveals the fact.
4. **Inside leak:** whistleblower 1% (3% with `LAW_WHISTLEBLOWER_PROTECTION`). This reuses my existing constants.

On reveal (`world.facts.reveal`, plus a PUBLIC `MEDIA_REPORT_EXPOSED` fact):

- **Credibility:** deliberate lie −15000, plus −5000 per lie in the last 24 months. An ERROR costs −3000, and only −1000 when the paper corrects within 2 months. Companies §14.9: prompt correction is cheap, fabrication is expensive.
- **Reader trust:** readers of the liar lose 0.5× that amount in `trust[o]`. Other leaves lose 0.2×.
- **Correction:** the outlet publishes a CORRECTION report next edition when `LAW_CORRECTION_DUTY` is on (mandatory, front page) or when `ethics` ≥ 0.5 (voluntary, rank 6+). Corrections reach only the correcting outlet's readers (§7.3).
- **Law:** the victim may sue (§8.2).

## 6. Investigative journalism

Each month, outlet budget `invest` buys attempts against SECRET facts that a press investigation can reach:
- `violation_track` (company misconduct)
- `donation_track` (illegal party money)
- `MEDIA_FALSE_REPORT` of rivals
- government misconduct facts with SECRET visibility

```
p(find) = min(0.4, invest/W_ref × 0.08) × transparency × target_risk
transparency = 0.6 + 0.4 × (LAW_FOI ? 1 : 0)
```

- A success calls the **existing** reveal paths with channel `PRESS`:
  - `PartyFinance._scandal(..., "PRESS")` for donations;
  - `Justice._reveal_violation` for violations, which starts the usual prosecution.
- The outlet then runs an INVESTIGATION report at the top of its edition. Publication alone never convicts anyone (J §17.4).
- Outlets target their opponents: the target choice is weighted by stance. That is where partisan papers do real damage with true facts.

## 7. Effects on voters (Wilma's side; the interface I propose)

Media computes one **news vector per leaf** each month. Wilma's `_update_opinion` reads it. Media never writes `sat`, `salience`, `approval` or `ideology` itself.

### 7.1 Per outlet, aggregate the edition first (O(outlets × reports))

- `blame_o[actor_kind]`: Σ over reports of the framed gov share × Σ impact × salience-free weight, **minus** the same for a neutral, full account of the same facts. This is the distortion, including the stories the paper buried (negative distortion: "you never heard about it").
- `bias_o[concern]`: the claimed impact minus the true impact (MISLEADING, FALSE and ERROR only), plus the amp excess.
- `agenda_o[concern]`: coverage volume per concern × (1 + sens).

### 7.2 Per leaf (O(leaves × outlets × concerns))

```
w(l,o)           = diet(l,o) × trust(l,o)/100000
news_blame[l]    = Σ_o w × blame_o["GOV"]                 → approval target += news_blame × K_BLAME
news_bias[l][c]  += Σ_o w × bias_o[c] × K_BIAS             (belief state; decays 25%/month)
news_agenda[l][c] = Σ_o w × agenda_o[c]                    → added to salience like the existing agenda term
```

- **Facts never change.** `news_bias` is applied when Wilma computes `sat` (perceived = actual + bias, clamped). It is stored on the leaf (`l["news_bias"]`, belief state, mixes on transfer).
- Starting constants: `K_BLAME = 0.5`, `K_BIAS = 0.6`. These get tuned so that one FALSE lead story in a big paper moves its readers' approval by 1–3 points, and a sustained slanted press by about 3–5 points over a year.

### 7.3 Corrections (PD 17.4, test 14)

A correction carries `−bias` of the original report. A leaf's revision is

```
Σ_o diet(l,o) × trust(l,o) × 0.6 × (1 − 0.5 × fit(l, original claim))
```

so part of the audience keeps believing, especially those the false claim suited. A correction printed by a *different* paper (a rival debunk) reaches that paper's readers instead. Readers of the liar who never read a rival keep part of the bias until it decays.

### 7.4 Step M3: reach gating (measured switch, `world.meta["media_reach"]`)

`_blame_facts` hits a leaf only through its diet coverage of that fact plus direct experience (`_affects` → 1.0) plus word of mouth (diet_none × 0.3). This is PD 17.2 ("an article should not automatically affect every resident"). It changes calibration, so it lands only after the A/B measurement in §11.

### 7.5 Philosophy and trust (PD 17.6)

- Sustained reading pulls ideology toward the paper's line at 0.002 × w per month per axis, capped at 5k per year. This is about a fifth of today's social influence, so one headline does nothing.
- Repeated exposed lies by government-run media cut institutional trust (`GOVERNANCE` sat bias −).
- Wilma owns both terms. I only supply `w(l, o)` and the lines.

### 7.6 Fields I would add to leaves (Wilma owns the leaf schema)

| Field | Kind | Mix on move |
|---|---|---|
| `diet` | derived {outlet: ‰} | no (DERIVED + NON_STATE) |
| `trust` | belief {outlet: milli} | yes |
| `news_bias` | belief {concern: milli sat} | yes |
| `news_blame`, `news_agenda` | this month only | no (derived) |

## 8. Press law (mine)

### 8.1 Levers (LAW level unless noted)

| id | Values (default) | Effect |
|---|---|---|
| `LAW_PRESS_LICENSING` | NONE / REGISTER / LICENCE (NONE) | LICENCE: outlets need a press licence (rules engine `FOUND_OUTLET`), and the government may suspend one after 2 defamation convictions in 24 months. Suspension is RESTRICT_EXPRESSION, so it needs the court (§8.3). |
| `LAW_DEFAMATION_STANDARD` | NONE / ACTUAL_MALICE / STRICT (ACTUAL_MALICE) | Who wins defamation cases (§8.2), the fabrication factor (§3.4), and a chilling effect: under STRICT every outlet's `slant` term ×0.7 |
| `LAW_CORRECTION_DUTY` | bool (true) | exposed false reports must be corrected on the front page |
| `LAW_MEDIA_OWNERSHIP_CAP` | 20–100% of circulation (100) | an owner above the cap must sell (Bob) or may not found a new paper; MARKET-channel detection |
| `LAW_PARTY_PRESS` | bool (true) | parties may own papers |
| `LAW_PUBLIC_MEDIA` | INDEPENDENT / GOVERNMENT_RUN (INDEPENDENT) | GOVERNMENT_RUN: the state paper's owner interest becomes the government (bury + slant), and its cred drifts down 300/month while it slants |
| `LAW_FOI` | bool (false) | freedom of information: investigative success ×1.67 (§6), and +detection on government misconduct |
| `LAW_PRESS_SUBSIDY` | 0–3 W_ref/month (0) | split across outlets by circulation, paid from the treasury; keeps small papers alive |

Ideology slopes follow the usual pattern: AUTONOMY on licensing, censorship and freedom of information; INSTITUTIONS on public media; ECON_ROLE on the subsidy. The exact numbers are in code review.

### 8.2 Defamation (extends `file_defamation`)

- `file_defamation(world, victim, defendant, severity, report)` gains an outlet defendant: `{kind: OUTLET, id}`. Damages come out of `media:out:N` and the owner covers any shortfall.
- **Outcome:**
  - ACCURATE or SLANTED: the paper always wins.
  - Under NONE: the paper always wins.
  - Under ACTUAL_MALICE: liable only for a deliberate FALSE.
  - Under STRICT: liable for FALSE, MISLEADING and ERROR.
- Ella's party-vs-party path stays as it is.
- A guilty verdict reveals the fact, costs the paper credibility as in §5, and writes `LAW_DEFAMATION_RULED` (the existing fact).

### 8.3 Censorship

- Suppressing a report is the action `CENSOR_REPORT`, which maps to `RESTRICT_EXPRESSION`: a **constitutional** prohibition on public actors (already in `law_data`).
- During a declared emergency with the new emergency lever `LAW_EMERGENCY_PRESS_CONTROL`, the AUTHORIZE rule needs `world.emergency` at constitutional rank. That is the only lawful censorship.
- Under it, the government's reports with a negative gov share are dropped before scoring.
- Unlawful censorship (a government doing it anyway through PolActions) is recorded as a SECRET violation with the HOME/press detection paths. Exposure is a scandal.
- Both write FREEDOM exposure on the leaves for S4 (`exposure.kind = "PRESS_RESTRICTION"`).

## 9. Money (Bob decides; my proposal)

- **Account:** each outlet has `media:out:N`.
- **Revenue:**
  - **Copies:** households in a leaf pay `price × pop × diet` a month, out of household spending. Bob books it in `_buy_services`; I expose `Media.demand(world) -> {out: {district: copies}}`.
  - **Ads:** Ella's AD spending (the `AD` channel) is paid to outlets by circulation share among the targeted districts, instead of disappearing (closed economy, A34).
  - **Owner subsidy:** STATE, PARTY and UNION owners cover deficits up to a budget.
  - **Press subsidy:** the lever.
- **Costs:**
  - **Staff:** `quality × 0.02 W_ref` paid as wages to households, the same pro-rata path as `Staff.charge`.
  - **Investigation:** `invest`.
  - **Printing:** 0.1 W_ref + 0.0005 W_ref per copy. Material is ignored in v1.
- **Company papers:** I'd keep the outlet a separate entity owned by an org, with profits and losses settling into `co:<org>` quarterly. Bob may prefer a MEDIA sector org in his company table. Both work for me, because §2 only needs `owner` and `account`.

## 10. UI (shared; Wilma or me)

- **Gazette panel → one front page per paper:**
  - a paper selector (masthead, price, owner, editor, circulation);
  - the edition's reports in rank order, with headlines from the existing `headline()`, plus frame variants when the paper blames a different actor ("CONTRACTOR FAILS HOSPITAL" vs "GOVERNMENT PROCUREMENT UNDER SCRUTINY");
  - article categories shown (News / Investigation / Editorial / Correction);
  - historical editions.
- **Truth is hidden** (companies §15.5). The player sees a FALSE story printed like any other until it is exposed. After that, the old edition shows a "CORRECTED" or "EXPOSED" stamp.
- **Media overview box:** circulation per paper by district, and credibility trend.

## 11. Steps and gates

| Step | Content | Owner | Gate |
|---|---|---|---|
| **M1 Core** | `sim/media/` (media_data, media_ops, media_query); outlet table, founding state paper, editions, scoring, framing (ACCURATE/SLANTED/ERROR), diet, trust; news vector API; levers (law_data); tests | Anni | tests below; full suite green; seed runs unchanged within noise with one neutral paper |
| **M2 Lies and law** | MISLEADING/FALSE, the SECRET fact, exposure paths, corrections, defamation vs outlets, censorship and emergency lever, investigations via existing reveal paths | Anni | PD tests 13, 14 |
| **M3 Voter hookup** | Wilma reads `news_blame` / `news_bias` / `news_agenda` / `w(l,o)` in `_update_opinion`; reach gating as an A/B behind `media_reach` | Wilma | 3 seeds × 40 years: approval and vote shares within ±2 pp of baseline with one paper; plural press measurably polarises readers |
| **M4 Entrants and money** | party/union/company papers, `Media.demand`, ad routing, closures | Anni + Bob + Ella + Wilma (party AI) | closed ledger; 2–5 papers alive after 20 years on most seeds |
| **M5 UI** | Gazette per paper, stamps, overview | Anni or Wilma | smoke OK |

### Tests (tests/media/)

1. Founding gives one paper, which reads every public fact of weight; diet sums to 1000 per leaf.
2. **Bury:** a company paper does not lead with its owner's accident below magnitude 70, and the state paper does.
3. **Slant:** a paper with a far-left line frames a business-owner fact against the company and a right paper against the government; the source fact is identical before and after.
4. **Readership:** LOW-band leaves read the cheap paper; ideological fit raises the diet share.
5. **Misinformation (PD 13):** a FALSE report lowers its readers' perceived sat for the concern. Facts and indicators are unchanged, and non-readers are not affected.
6. **Correction (PD 14):** after exposure plus correction, readers revise part of the way (not all) back; leaves for whom the claim fit revise less.
7. **Exposure:** deliberate lie vs prompt-corrected error, the credibility hit differs by ≥ 3×.
8. **Defamation:** ACTUAL_MALICE convicts FALSE but not SLANTED; damages come from the outlet account.
9. **Censorship:** illegal without emergency + lever (rules engine PROHIBITED); lawful under both.
10. **Investigation:** a press find reveals a SECRET donation through the existing scandal path, with channel PRESS.
11. **Determinism:** the same seed gives the same editions; predict/read never writes.

## 12. Questions for the team

- **Wilma:**
  - Are you OK with the leaf fields in §7.6 and with media running at the end of JUSTICE (news "since last edition"; campaign facts made in POLITICS are covered next month)?
  - Do you take M3 and the party-AI founding call, or should I propose a patch for your review?
- **Bob:** Should outlets be separate entities with an owner, or orgs in your company table? Can household copy spending go through `_buy_services` from `Media.demand`? Who decides when a company founds or sells a paper?
- **Ella:**
  - Do AD facts pay outlets by circulation?
  - Do you want `Media.campaign_tilt(world, leaf, party) -> 0.7..1.3`, which you would multiply into your persuasion so that friendly papers amplify a party's campaign and hostile ones dampen it?
  - Debate coverage: partisan papers declare their side the winner, which uses the same tilt.
- **Scope cut if needed:** M1 + M2 + M3 are the playable core. Entrants (M4) can start with party and union papers only.

## 13. As built: M1 (2026-11-12)

- **Code:** `sim/media/media_data.gd` (constants), `media_ops.gd` (`class_name Media`: outlets, editions, framing, readers, hooks), `media_query.gd` (`class_name MediaQuery`, read-only). `Media.run` is called at the end of JUSTICE (`LawProvider`). Tables `outlet`, `report`, `edition`, `media` are pre-created in `LawOps.init_world`.
- **Levers** (in `law_data`, read by media): LAW_PRESS_LICENSING, LAW_DEFAMATION_STANDARD, LAW_CORRECTION_DUTY, LAW_MEDIA_OWNERSHIP_CAP, LAW_PARTY_PRESS, LAW_PUBLIC_MEDIA, LAW_FOI, LAW_PRESS_SUBSIDY, and the emergency lever LAW_EMERGENCY_PRESS_CONTROL.
  - Wired so far: party press, ownership cap, the licensing gate on founding, the GOVERNMENT_RUN owner interest, and the STRICT chilling effect.
  - The rest arrive with M2 or M4.
- **Changes from the draft:**
  - An INDEPENDENT state paper never slants and has no party tilt, so day one equals today.
  - A partisan paper also plays the government's part of a story up or down by its stance toward the government (`gov_amp`). Without this, blame shifts and downplaying cancelled out.
  - Repeats of a fact type are grouped under the best story (`also`), as the Gazette panel already did.
  - Groups with pop 0 are skipped.
  - `diet`, `news_blame` and `news_agenda` are in PopStore.NON_STATE. `trust` and `news_bias` mix on transfer.
- **APIs:**
  - **Wilma:** `MediaQuery.edition(world, out, month)`, `MediaQuery.outlets`, `MediaQuery.news(leaf)`, `MediaQuery.weight(leaf, out)`.
  - **Ella:** `MediaQuery.campaign_tilt(world, leaf, party)`, `MediaQuery.campaign_tilt_district(world, district, party)` and `Media.pay_ads(world, from_acc, amount, {district: weight}, memo) -> paid`.
  - **Bob:** `Media.demand`, `Media.record_sales`, `Media.on_insolvent`, `Media.found_outlet`, `Media.transfer_outlet`, `Media.close_outlet`, `MediaQuery.owned_by`.
- **Measured on seed 1, 6 years** (`tools/probe_media.gd`, with a labour and a business paper founded in year 3):
  - The papers split the readers about 570 / 410 / 370.
  - *The Worker* frames contract delays against the government; *The Ledger* blames the contractor.
  - The neutral Gazette alone gives a mean news_blame of about 0–20 milli (0.02 approval points).
  - The reader pass costs about 20 ms a month for ~360 groups, about 4% of a month step.
- **Tests:** `tests/media/test_media.gd` (11).

## 14. As built: M2 (2026-11-12)

- **MISLEADING** is a per-story chance, `(pressure − 0.35) × 0.5`, where pressure = |stance| × (1 − ethics), or (1 − ethics) when the story hits the owner. It never applies to an independent public paper. It moves at least half the blame, with amp 1.5 or 0.6.
- **FALSE**: at most one fabricated story a month per paper (§3.4). It targets the government, or the most opposed party, as the chief opponent. `world.meta.media_p_fabricate` overrides the base rate (tests).
- **Lies table:** every MISLEADING, ERROR or FALSE report writes a SECRET `MEDIA_FALSE_REPORT` and a `media_lie` row. The row holds the victim and the claimed bias, which corrections use.
- **Exposure** (each month, watched for 24 months):
  - Victim complaint: FALSE 0.25, ERROR 0.15, MISLEADING 0.08 (magnitude ≥ 40).
  - Rival debunk: 0.1 × invest (×1.5 for an opposed rival); it becomes the rival's scoop.
  - Whistleblower: 1% (3% with protection).
  - `Media.expose_lie` covers press investigations as well.
- **Credibility on exposure:**
  - FALSE: −15 −5 per recent lie.
  - MISLEADING: −5 −1 per recent lie.
  - ERROR: −3, or −1 when corrected.
  - Repeats are capped at 3; recovery is +0.3 a month back to the founding level.
  - Readers of the paper lose 0.5× the hit in trust, others 0.2×.
- **Corrections:** on the front page under LAW_CORRECTION_DUTY, otherwise inside. A correction reverses 0.6 × trust × (0.75^months) of the claimed bias for that paper's readers.
- **Defamation:** `Justice.file_defamation_outlet(world, victim, out, severity, liable)`. Damages come from `media:out:N`, and `Media.on_defamation_verdict` costs −5 credibility on a guilty verdict.
- **Investigations:** p = min(0.4, invest × 0.08) × (FOI ? 1 : 0.6). Targets are hidden donations, unlawful company practices and rival lies, weighted by opposition. Reveals go through PartyFinance._scandal and Justice._reveal_violation with channel PRESS, and run as the paper's INVESTIGATION story.
- **Censorship:** `Media.ensure_rules` installs, versioned, a charter PROHIBIT `CENSOR_REPORT` (unless the lever is on) and an AUTHORIZE when world.emergency is set and the lever is on. The censor drops negative stories that blame the government. It writes an OFFICIAL `MEDIA_CENSORED` with `exposure.kind = PRESS_RESTRICTION`.
- **10-year probe on seed 2** (a labour paper and a business paper from year 3, default ethics):
  - About 3 lie, error or spin records per paper a year, about half exposed, 2 defamation rulings.
  - Credibility: Gazette 70, union paper 53, business paper 39.
- **Tests:** `tests/media/test_media_m2.gd` (6, PD tests 13 and 14).

## 15. As built: AI founding (2026-11-12)

The v4 chronicles showed no paper but the Gazette in 100 years. `Media._found_ai` now runs monthly at the start of `Media.run`, from month 12 on.
- **Market room:** active outlets < 1 + voters / `POP_PER_PAPER` (500), and at most 8. `Media.market_room(world)`.
- **Entry rate:** at most one new paper a month and one per owner. Every candidate rolls; one hit is drawn (stream `media.found`).
- **Party:** ACTIVE, support ≥ 8%, ≥ 6 W_ref in `party:<id>`, and `LAW_PARTY_PRESS` on.
  - Monthly probability: 0.005 × (1 + support/20%).
  - The paper: "The {party} Herald", with the party's line and ethics = leader integrity / 100. 3 W_ref moves from the party into the paper.
- **Union federation** (`union:fed`): density ≥ 30% in ≥ 2 occupations.
  - Monthly probability: 0.02.
  - The paper: "The Worker", with the colony mean line + LABOR 40 and REDISTRIBUTION 30. No endowment, because unions have no account yet.
- **Company:** a private ACTIVE org (not `PUBLIC_*`) with ≥ 150 W_ref cash and ≥ 50 staff.
  - Monthly probability: 0.002 + 0.015 per bad PUBLIC story about it in 12 months (at most 3).
  - The paper: "The {firm} Courier", with the BUSINESS_OWNER line. 20 W_ref moves from `co:<id>`.
- **Licensing:** under `LAW_PRESS_LICENSING` = LICENCE, an owner opposed to the government (opposition ≥ 0.5) is refused.
- **Exit:** a paper closes when its party is no longer ACTIVE or `LAW_PARTY_PRESS` is switched off, or when its company is in LIQUIDATION or DISSOLVED. Money-driven exit is still M4.
- **Probe, 2 seeds × 20 years:**
  - Papers appear from year 2.
  - 5–6 papers are active at year 10 (union, company and party), and company papers die with their firms.
  - With no money exit, the line-up then freezes.
- **Tests:** `tests/media/test_media_found.gd` (8). `world.meta.media_found_scale` scales the founding probabilities for tests and probes.
