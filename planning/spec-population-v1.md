# spec-population-v1 — Population blocks (M10)

Owner: Wilma (population store, philosophy, effects, politics on blocks, UI).
Contributors: 88 (income, work, labour, consumption, demography, migration), a9 (eligibility law, rights/justice trust, visibility side of media).
Design source: `population.md` (the user's spec v0.8, referred to as **PD §n**). This document says **how** PD is built on the existing code. Where it differs from PD, the difference is listed in §0 and was accepted by the user (2026-11-11) as a changeable default. Anything else in PD stands as written (PD §28).

---

## 0. Accepted deviations from PD (changeable)

| # | PD says | We do | Why |
|---|---|---|---|
| D1 | §8: five entity types linked by child-ID lists | One flat **leaf** table with stable IDs; housing/income/work/philosophy blocks are **derived views** (`PopQuery.block(level, key)`) with the PD §8 fields | Parent = Σ children holds by construction; no parent/child sync bugs; sparse for free (PD §22.1) |
| D2 | §22.2: 72 000 leaves "manageable" | Benchmark from step 1. If a month with the full opinion/vote update exceeds budget (§10), opinion and votes are computed per **philosophy node** (housing × income × work × archetype) and effects act as deltas on it; counts stay exact per leaf | GDScript speed |
| D3 | §6.2: 8 dimensions | 9 axes = existing 7 + LIBERTY + STABILITY (keeps FISCAL, which PD lacks) | Party/lever system already uses FISCAL |
| D4 | §6.6: split/merge philosophy groups | Yearly regrouping (January), at most 8 archetypes per colony | Stability; cost |
| — | (M9) | No cap on the number of parties; a party below 0.1% for 36 months running is dissolved | User decision 2026-11-11 |

Until the map has residential zones (PD §3, P2), **housing block = district** (one block per district, IDs `hb:d:1` …). IDs are stable, so PD §3.9 splitting later creates new blocks with predecessor links.

---

## 1. What exists and is kept (maps PD onto current code)

| PD | Existing implementation | Change in M10 |
|---|---|---|
| §18.4 satisfaction Σ w·x | `cell.sat[concern]` from perceived indicators × `cell.salience` | Moves to leaves; concerns 9 → 13 (§5.3) |
| §18.5 expectations | `cell.expect`, performance vs expectation | Kept |
| §19.2 salience | unmet-need boost + agenda-setting (M9) | Kept; effects add salience (§6) |
| §20.3 U = A + T + P + C | `VoteModel.utility`: distance + ownership (A), credibility + loyalty + leader (T), performance − cost of ruling (P), campaign + endorsements + shock (C) | T becomes per-leaf party trust (§5.4) |
| §20.2 turnout | `VoteModel.turnout` (alienation, fed-up) | Rewritten per PD §20.2 (§5.5) |
| §20.4–20.7 | multinomial split per cell, 151 seats, Year-3 parties, ≥ 5 parties, M9 party life | Kept |
| §7.10 cause / perceived cause | facts: `responsible`, blame, `impact`, `magnitude` | Effects are **built from facts**, not a parallel system |
| §2.2 largest remainder | `EconUtil.split_lr` | Used for every transfer |
| §22.8 determinism | named RNG streams, ints in state | Kept |
| §23.7 imperfect information | polls with MOE, perceived indicators, a9 visibility | Kept |
| §9, §10 demography, ships | 88: `EconHouseholds._demography`, `_ship_migrants` | Re-expressed as PopStore operations |

What is **removed**: the monthly census rebuild (`census` table → `_sync_cells`). Cells stop being recomputed from economics; people move between leaves and carry their state (PD §1.2, §10.4.8, test 19).

---

## 2. Data model (D1)

### 2.1 Leaf

Table `pop` (owner Wilma). Key = `hb|inc|occ|status|arch|eff`, e.g. `hb:d:1|I2|MINING|UNEMPLOYED|LABOR|e3`.

| Field | Type | Notes |
|---|---|---|
| `n` | int persons | ≥ 0; leaf deleted when 0 (history keeps the key) |
| `age` | `{C: , Y: , A: , M: , O: }` int counts, Σ = n | children 0–17, young 18–29, adult 30–49, mature 50–64, old 65+ (PD §9.2, joint with status per §9.7) |
| `skill` | `{G: , S: , Sp: }` int counts, Σ adults | economy tiers; education outcome (PD §9.5) |
| `recent` | int | arrived in the colony < 24 months ago (eligibility, integration politics) |
| `inc_ema` | int milli-W | equivalized disposable income moving average (PD §4.6) |
| `ideology` | 9 axes, int ×1000 | philosophy vector; starts at archetype centroid + leaf offsets |
| `commitment`, `openness`, `engagement` | int 0–100 | PD §6.4 |
| `salience`, `sat` | 13 concerns | as cells today |
| `approval`, `expect`, `perf_hist` | | as cells today |
| `trust` | `{gov, parliament, institutions, justice}` int 0–100000 + `party: {pid: int}` | PD §19.4 |
| `prev_share` | `{pid: int}` | loyalty |
| `grievance` | `{concern: int}` | accumulated, decays (PD §19.1 "recent experiences") |
| `exposure` | sorted `[[effect_id, band]]` | the signature `eff` in the key is its short hash (§6) |

### 2.2 Keys

- `inc`: `I1` very low … `I5` very high (PD §4.1).
- `occ` (13, PD §5.1): MINING, CONSTRUCTION, MANUFACTURING (was INDUSTRY), AGRICULTURE, LOGISTICS, SERVICES, PROFESSIONAL, PUBLIC_SECTOR, BUSINESS_OWNER, plus NONE for people with no occupational history.
- `status` (PD §5.2, separate from occupation): EMPLOYED, UNEMPLOYED, STUDENT, RETIRED, NOT_IN_LF, CHILD. PD's "Unemployed / Education/training / Retired / Other nonworking" categories are `status` values; a laid-off miner is `MINING|UNEMPLOYED` (keeps the skill and history).
- `arch`: archetype id (§5.1).
- `eff`: exposure signature hash; `e0` = no local exposure.

### 2.3 Derived blocks

`PopQuery.block(level, key)` returns the PD §8 record for HOUSING / INCOME / WORK / PHILOSOPHY / EFFECT by summing leaves (population-weighted means for averages). Cached per month (PD §22.6), invalidated by any transfer. The housing block record also carries map-side fields (capacity, quality, cost, access, pollution) owned by 88's housing code.

### 2.4 Transfers and the ledger (PD §2, §8.7)

All changes go through `PopStore`:

| Operation | Effect |
|---|---|
| `transfer(src, dst_key, n, reason)` | moves n persons; age/skill/recent split with largest remainder; **beliefs travel**: dst opinion fields = n-weighted mean of dst and the moved people (src values); money moves with people (§3.4) |
| `birth(parent_key, n)` / `death(key, n, age_band)` | only demographic sources and sinks (PD §2.3) |
| `arrive(hb, n, profile)` / `depart(key, n, reason)` | immigration / emigration |
| `relabel(key, field, value)` | move a whole leaf (e.g. income band change) = transfer of all n |

Every call appends to `pop_transfer` (month, src, dst, n, reason, context). Ledger compaction: monthly rows are aggregated per (src block level 2, dst level 2, reason) after 24 months (PD §22.7 "older aggregation").

`PopStore.reconcile()` (PD §21 phase 11) asserts:
- Σ leaves = colony total;
- colony total changed only by births − deaths + arrivals − departures;
- every age/skill dict sums to n / adults;
- employed persons = economy employment slots filled;
- housing occupancy = Σ n per housing block.

It runs every month in tests and tools, and yearly in play (it is cheap enough to run monthly if the benchmark allows).

---

## 3. Economy on blocks (88)

### 3.1 One source of truth (PD §11)

The `hh` table (district × tier) becomes a **derived view** over leaves, or is replaced. The labour market reads supply from leaves (housing block, occupation, status, skill) and writes hires and layoffs as transfers:

- hire: `…|NONE or occ|UNEMPLOYED or NOT_IN_LF|…` → `…|job occ|EMPLOYED|…`;
- layoff: `…|occ|EMPLOYED|…` → `…|occ|UNEMPLOYED|…`.

Employment allocations (PD §5.5) store (origin housing block, workplace facility, occupation, n). The same person cannot be allocated twice: Σ allocations of a leaf ≤ its EMPLOYED n.

### 3.2 Income bands (PD §4)

- Equivalized disposable income per leaf: D = Y − T + B (PD §12.2), per adult-equivalent.
- `inc_ema` uses a 6-month EMA.
- A leaf moves band when the EMA is past a quintile cut by more than 5%, or when monthly income changed by more than 25% (job loss, PD §4.6).
- Cuts are colony quintiles of the EMA (relative). An absolute **deprivation** indicator per leaf (cannot afford essentials) is published separately (PD §4.4 hybrid).
- Indicators: Gini (colony and per housing block, PD §4.7).

### 3.3 Work and income order (PD §5.7)

Each month the economy computes jobs, wages and benefits first, then applies employment transfers, then income reclassification. One pass; no forced hierarchy outcome.

### 3.4 Money moves with people

Household money is held per (housing block, income band) account. A transfer moves `balance × n / n_src` of the source account to the destination account, so savings follow people. Ledger total stays 0.

### 3.5 Consumption and shortages (PD §12)

88 keeps the current consumption model at (housing block, income band) granularity. Shortage causes (PD §12.5: no supply / unaffordable / inaccessible / by choice) are recorded per block and published as indicators.

---

## 4. Demography, eligibility, migration

### 4.1 Demography (88, PD §9)

- **Births:** from Y+A women-equivalents (half of Y+A) × fertility × health. Babies are added to the parents' housing block and income band as `NONE|CHILD`, with the parents' archetype at 70% (otherwise the colony mix), and inherit the parents' ideology with 30% regression to the colony mean.
- **Ageing:** monthly accumulators per band (1/216 of C → Y, etc.) with remainders kept in state.
- **Deaths:** age-specific rates × healthcare access × environment.
- **School:** C reaching 16 move to STUDENT. Leaving school picks a skill tier by education access, then status NOT_IN_LF or UNEMPLOYED (job search). Skills change gradually (PD §9.5).
- **Retirement:** at O, or early, from UNEMPLOYED or NOT_IN_LF.

### 4.2 Eligibility (a9, PD §9.6)

- New levers: `LAW_VOTING_AGE` (16 / 18 / 21; default 18), `LAW_RESIDENCY_FOR_VOTE` (months; default 0), `LAW_NONCITIZEN_VOTE`.
- Eligible voters per leaf = adults over the voting age − `recent` if a residency rule applies.
- Elections and turnout use eligible voters, never `n`.
- Registered voters are not modelled in v1.

### 4.3 Migration (88, PD §10)

- **Immigration:** ships, limited by transport capacity; arrivals get a profile (skill, archetype mix of the origin) and `recent` set.
- **Emigration:** new; driven by deprivation, unemployment months and dissatisfaction, limited by departures.
- **Internal moves:** between housing blocks, constrained by capacity, rent and access (PD §10.4). Movers keep occupation, status and beliefs.

---

## 5. Politics on blocks (Wilma)

### 5.1 Archetypes (PD §6.3, D3, D4)

The eight PD archetypes are template vectors on the 9 axes: LABOR, MARKET, ENVIRONMENT, EQUALITY, LIBERTY, STABILITY, DEVELOPMENT, INSTITUTION.

- Each colony draws its own variants (random offsets, like today's cohorts) and its own mix.
- The archetype mix within a work block comes from occupation × income-band priors (today's `OCC_IDEOLOGY` and `BAND_SHIFT` become priors on the mix, not on the vector), so miners hold several philosophies (PD §6.7).
- Leaf vectors drift monthly as today (concern pull, neighbours, zeitgeist, base pull), slowed by `commitment` and sped by `openness`.

**Yearly regrouping (D4):**
- A leaf closer to another archetype's centroid by a margin moves there.
- Centroids are recomputed.
- Two archetypes closer than a threshold merge.
- A cluster of at least 2% of the population far from every centroid founds a new archetype, as long as there are fewer than 8.

These are PD §6.6 splits and merges.

### 5.2 Axes

The 9 axes are ECON_ROLE, REDISTRIBUTION, LABOR, ENVIRONMENT, AUTONOMY (central vs local), LIBERTY (new: individual freedom vs regulation), STABILITY (new: continuity vs rapid change), FISCAL, INSTITUTIONS. Party generation, party positions, commitments and lever mappings gain LIBERTY and STABILITY. Existing levers are mapped to them; new levers are not required.

### 5.3 Concerns (PD §18.1)

The 9 concerns become 13:

| PD well-being dimension | Concern |
|---|---|
| economic security | JOBS |
| essential consumption | COST_OF_LIVING |
| employment conditions | **WORK_CONDITIONS** (new: safety, hours, union) |
| housing | HOUSING |
| healthcare | **HEALTH** (split from PUBLIC_SERVICES) |
| education | **EDUCATION** (split from PUBLIC_SERVICES) |
| safety | SAFETY |
| environment | ENVIRONMENT_QUALITY |
| infrastructure | INFRASTRUCTURE |
| personal freedom | **FREEDOM** (new) |
| institutional trust | GOVERNANCE |
| recreation | **RECREATION** (new) |
| (kept) | FAIRNESS |

Indicators feeding the new concerns come from 88 (work conditions, recreation) and a9 (freedom, rights).

### 5.4 Trust (PD §19.4)

Per leaf: government, parliament, institutions and justice trust, plus per-party trust. Party trust replaces the global credibility term in U (credibility becomes the colony mean of party trust). Each moves with its own events:

- government: performance and blame;
- parliament: gridlock, crises, scandals;
- institutions: service delivery;
- justice (a9): case delays, convictions of the powerful, rights violations;
- party: promises kept or broken, scandals, leader integrity, coalition betrayals.

### 5.5 Turnout (PD §20.2)

turnout = clamp(base × engagement factor + mobilisation, 0.2, 0.97), where mobilisation includes:

- grievance mobilising opposition voters (dissatisfaction can *raise* turnout);
- alienation (no close party) lowering it;
- trust in institutions;
- campaign spending reach;
- election importance (close polls);
- health and deprivation lowering it;
- union and endorsement mobilisation.

All terms are bounded and calibrated by the gate.

### 5.6 Votes (PD §20)

- Utility as today, with A using 9 axes and T = party trust.
- Votes per leaf: eligible × turnout × probabilities.
- Votes are stored per housing block and district (PD §20.5).
- Seats: unchanged (151, 4% threshold).
- D2 fallback: compute per philosophy node, then add effect deltas per leaf.

---

## 6. Effects (Wilma; PD §7)

### 6.1 Effect definitions from facts

A fact may carry an `exposure` block:

```
{"scope": {"housing": [...], "district": [...], "occ": [...], "employer": org, "status": [...]},
 "share": 0..1000, "intensity": 0..1000, "kind": "POLLUTION", "decay": per-mille/month, "persistent": bool}
```

The fact supplies the actual cause (`responsible`). The **perceived** cause comes from the blame model, filtered by archetype: a MARKET leaf blames government less for a company's layoffs, a LABOR leaf blames the employer and the government. Owners add `exposure` to their facts:
- 88: pollution, layoffs, unsafe work, rent rises, shortages;
- a9: rights violations, rulings;
- Wilma: broken promises.

### 6.2 Applying an exposure

1. If the exposure covers **all** of a parent block with the same intensity, it is stored on the parent (`pop_shared[parent_key]`) and creates no split (PD §7.5).
2. Otherwise `share` of each matched philosophy node's leaves is transferred into the leaf with the extended signature (largest remainder). Intensity is quantised to 3 bands (PD §22.3).
3. **Cap:** at most 4 effect leaves per philosophy node. When a new split would exceed the cap, the two most similar signatures merge (PD §22.5), and the merged leaf takes the population-weighted state.

### 6.3 Consequences

Effects never add happiness directly (PD §7.9). They act through:

- the leaf's own condition values: exposure-specific overrides of the indicator a concern reads, e.g. pollution lowers ENVIRONMENT_QUALITY satisfaction, unsafe work lowers WORK_CONDITIONS and HEALTH;
- a salience boost;
- grievance;
- trust changes (via perceived cause).

### 6.4 Decay and expiry

- Temporary effects: intensity × (1 − d) each month (PD §7.8).
- Persistent effects are recomputed from their source condition.
- Below band 1 an exposure is removed and leaves with equal signatures merge back (PD test 9).

---

## 7. Media (PD §17) — later step

- Facts become **reports** by newspapers (accurate, slanted or false). Readership is per leaf: housing access, price, income, education, archetype affinity.
- Leaves update **perceived** conditions and blame from reports weighted by source credibility. Facts never change.
- Corrections reach only part of the audience (PD §17.4).
- a9's visibility system decides what can be reported.
- Owner: Wilma (perception), with a9 (visibility and press-law levers).
- Newspapers are companies (88).

---

## 8. Monthly order (PD §21 → engine phases)

| PD phase | Engine |
|---|---|
| 1–3 inputs | already produced by ECON, SOCIAL, JUSTICE phases |
| 4 demographics, 5 employment/income, 6 migration | SOCIAL phase (88) via PopStore |
| 7 effects, 8 well-being, 9 attitudes, 10 political outputs | POLITICS phase (Wilma) |
| 11 reconcile | end of POLITICS (`PopStore.reconcile`) |
| 12 history | end of month: colony/block snapshots; yearly compaction |

The JUSTICE phase stays before POLITICS.

---

## 9. UI (PD §23)

- A **Population** panel: district / housing block → income → work → philosophy → effects. Each level shows count, share of parent, income, employment, well-being, attitudes and active pressures (PD §23.3).
- Compare mode (PD §23.4).
- Trends from history (PD §23.6).
- Political attitudes are shown **only via polls** with uncertainty (PD §23.7); administrative counts are exact.
- Map overlays when the map supports them (PD §23.5).

---

## 10. Performance

- Tool `tools/bench_population.gd`: synthetic colonies of 2k / 20k / 100k residents and real runs. It reports leaf count and ms per month for SOCIAL+POLITICS.
- Budget: **≤ 150 ms per month** at the 100k benchmark for SOCIAL + POLITICS (a 40-year run ≈ 70 s per seed).
- Above budget → D2 fallback, then quantisation and caching (PD §22).
- Today's colony (about 2,000 residents, 6 districts) gives at most about 6 × 5 × 10 × 6 × 2 ≈ 3.6k leaves; sparse is far fewer.

---

## 11. Steps, owners, gates (AI-speed estimates)

| Step | PD phases | Owner | Content | Gate |
|---|---|---|---|---|
| **S1 Foundation** (~1 week) | P1, P13 basics | Wilma | PopStore, leaves, transfers, ledger, reconcile, derived blocks, save/load, migration from old saves (leaves built once from the census), bench tool | PD tests 1, 3, 8 (synthetic), 19; reconcile passes for 40 years; determinism |
| **S2 Income and work** (~1–2 weeks) | P3, P4, P8 part | 88 | hh replaced by leaves; hires and layoffs as transfers; 5 bands with EMA and hysteresis; 13 occupations; money moves with people; Gini, deprivation | PD tests 4, 5; economy gate not worse than A29 baseline |
| **S3 Philosophy and politics** (days–1 week) | P5, P11 | Wilma (+ a9 eligibility) | archetypes, 9 axes, 13 concerns, trust types, turnout, eligibility levers, votes per housing block | PD tests 6, 16, 17; M9 party gate still met; parties distinct |
| **S4 Effects** (~1 week) | P6 | Wilma (+ 88 and a9 add `exposure` to facts) | signatures, cap, shared effects, decay, perceived cause | PD tests 7, 8, 9, 12, 18 |
| **S5 Demography and migration** (~1 week) | P7, P9 | 88 (+ a9 justice trust, rights) | age, births, deaths, school, retirement, emigration, internal moves; health and education access | PD tests 10, 11; population stable over 40 years |
| **S6 UI** (days) | P12 | Wilma | Population panel, drill-down, compare, trends | smoke test; panel shows all 5 levels |
| **S7 Housing blocks** | P2 | 88 + map | residential areas from the map, capacity, splits | PD test 2; needs the map decision (2D/3D) |
| **S8 Media** | P10 | Wilma + a9 + 88 | newspapers, reports, perception, corrections | PD tests 13, 14 |
| **S9 Alcohol, recreation** | P9 part | 88 + a9 | | PD test 15 |
| **S10 Balance** | P14 | all | | PD test 20 and the PD §29 Year 1–24 scenario as a scripted soak |

Every step keeps the game playable and the full suite green.

---

## 12. Open items

- Housing blocks below the district need residential zones on the map (S7). This depends on the 2D/3D decision.
- Media ownership split (S8) to confirm when we get there.
- PD §11.5: the 20 named senior staff must be subtracted from PUBLIC_SECTOR employment counts (a9 + 88, S2).
