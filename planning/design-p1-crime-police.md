# Design note P1 — crime and police (Anni, 2026-11-13; plan-public-safety.md, A60)

Status: DESIGN. The build waits until scandal revival is committed and my current work is done.
Everything is opt-in (`meta["on"]` "CRIME", later "POLICE"); `meta["off"]` wins. State is integer. RNG streams
`law.crime`, `law.police`. Owner files: `sim/law/crime.gd` (new), `sim/law/police.gd` (new), `crime_query` readers in
`law_query.gd`, levers in `law_data.gd`.

## 1. Offence model (P1a)

**Aggregate counts, not individual offenders.** Per district and month, three offence kinds:

| kind | Swedish-level base at full employment (per 10k residents per year) | base clearance |
|---|---|---|
| THEFT | 600 (≈ 50/month) | 6% |
| VIOLENCE | 100 (≈ 8/month) | 25% |
| FRAUD | 200 (≈ 17/month) | 10% |

DRUGS and VANDALISM come later; the table shape allows them.

**Expected offences** (milli-offences, integer) are computed per district from:

`base × pop/10k/12 × drivers × deterrence × presence × cooperation`

- **Drivers.** These come from Bob's `crime_drivers` (§5). Each driver is a multiplier around 1.0 at the reference
  value. The weights differ by kind:
  - THEFT: unemployment, hunger, inequality, homelessness, stock worth stealing.
  - VIOLENCE: unemployment, youth share, inequality, homelessness, crowding.
  - FRAUD: firm and transaction count, low audit coverage.
  - Targets: a slump with unemployment rising from about 4% to 15% should raise THEFT by about 1.6× and VIOLENCE by
    about 1.3×. Hunger alone can reach 2× THEFT.
- **Deterrence.** This is `1 − D × (clearance − base clearance)`, using last year's clearance for that kind. A police
  force that solves more crimes lowers future crime, and a collapse in clearance raises it.
- **Presence.** Patrol hours per resident relative to the reference, raised to the power −0.3. Its effect on
  VIOLENCE and THEFT is diminishing.
- **Cooperation.** Average trust in the police among the district's voter groups (§3). Low trust means fewer reports
  and fewer witnesses, which lowers clearance. It does not change the true crime rate, only what is reported.

**Monthly draw.** The integer part of the expected count happens for certain. The remainder is drawn once with the
`law.crime` RNG stream. Reported offences are a share of all offences (`REPORT_SHARE` by kind × cooperation); only
reported offences enter the police workload and the published rate.

**State** is `law_state.s.crime[district]`:

- `{kind: {n_m, reported_m, solved_m, open}}` for the current month;
- 12-month rolling sums for each kind;
- a 12-month EMA of the rate per 10k per year.

**Facts.** Monthly totals are kept in state, not as facts, because the fact store would explode. Notable events
become facts:

- **LAW_CRIME_WAVE** (PUBLIC, district): when a district's 3-month rate is ≥ 1.5× its 24-month mean and ≥ 1.3× the
  colony base. It fires at most once a year per district.
  - responsible: GOVERNMENT, at a share scaled by police underfunding (§2). The rest of the blame is drivers with no
    actor.
- **LAW_VIOLENT_CRIME** (PUBLIC, rare, the top violent offence of a month): data `{district, solved}`. It gives the
  press a story. The victims are anonymous.
- **LAW_FRAUD_RING_BUSTED** (PUBLIC): a solved FRAUD cluster.

**Readers.** I give Wilma `crime_rate(world, district) → {kind: rate per 10k/yr}` and a colony version, for the
SAFETY concern (VIOLENCE and THEFT) and FAIRNESS (FRAUD).

## 2. Police (P1b)

**Institution.** POLICE is an org with key "POLICE" and type PUBLIC_INSTITUTION, on the PES pattern.

- It has one **POLICE_STATION** facility per district. Small neighbouring districts can share a station
  (`covers: [districts]`) while their combined population is under `STATION_MIN_POP`.
- Terra draws the stations. Bob adds the facility type and its recipe (construction and upkeep).

**Staff.** The reference is 200 officers per 100k residents, i.e. about 20 per 10k.

- I set `crew_target` per station each month from the budget lever. Bob's labour market fills it and pays wages
  from the police budget line.
- Officer tiers: 10% Sp (detectives, command), 75% S (officers), 15% G (community officers).
- Civilian support staff come on top under the A56 rules (about 8 per 20 officers). Bob's OFFICE logic decides
  that; I only count officers.

**Levers** (all NUMBER and legislative, so the AI can draft them):

- **LAW_POLICE_BUDGET** (W_ref per month, est_budget_line).
  - The default funds the reference strength at today's wages.
  - Coverage is `min(1, budget / wage bill of the reference)`.
  - Concern hints: SAFETY + / TAXES −.
- **LAW_POLICE_POWERS** 0..100, default 40, covering search, detention and surveillance.
  - Each step above 40 raises clearance: up to +40% at 100.
  - It also raises misconduct: up to 3× at 100.
  - It lowers trust among voters who lean towards civil liberties.
  - Ideology: INSTITUTIONS negative (the order pole favours raising it).
  - Concern hints: SAFETY + / FAIRNESS − (A54 symmetric).
- **LAW_POLICE_OVERSIGHT** 0..20000 (W_ref per month), an independent complaints authority.
  - It detects misconduct (§4).
  - Concern hints: FAIRNESS + / TAXES −.

**Monthly effects per district:**

- **Capacity.** Officer-hours available = officers on duty × hours. Officers on duty = staff × (1 − sick share from
  Bob's stress).
- **Workload ‰.** Hours needed / hours available. Hours needed = reported offences × hours per case (by kind) +
  patrol need per resident.
- **Clearance.** Base clearance by kind × min(1, capacity / need)^0.5 × the powers factor × competence × cooperation.
  - Competence is the cabinet's justice-duty quality (`Staff.duty_quality`, as for the inspectorate).
- **Response time** (minutes, for the UI and press) = base × workload / 1000 × an area factor.
- **Second detection channel "POLICE"** in `JO.detect_ctx`, for criminal-grade conduct: fraud squad capacity
  against violation_track kinds marked `criminal`. These are bribery, FAVOUR, CONTRACT_CORNERS above a size, and
  later tax evasion. It also covers the donation_track.
  - Revealing goes through the existing `_reveal_violation` and `PFN._scandal` with channel POLICE, so there is no
    new reveal code.

**Facts:**

- **LAW_DISTRICT_UNPATROLLED** (PUBLIC): coverage below 50% for 3 months.
  - responsible: GOVERNMENT.
  - data: `{budget_cut: true}` if the budget lever fell within 24 months.
  - This is the "district left unpatrolled after the cuts" scandal Wilma's plan names.
- **LAW_POLICE_STATION_CLOSED** and **LAW_POLICE_STATION_OPENED**, from the station rules.

## 3. Trust in the police

Trust is a per-voter-group integer, 0..100000, stored in `trust_police` on the voter group (as with media trust).

- It drifts towards a target built from:
  - clearance relative to the base (feeling safe);
  - recent revealed misconduct in the district (each reveal −X, fading);
  - the powers lever weighed against the group's INSTITUTIONS position (liberty-leaning groups dislike high powers,
    order-leaning ones like them).
- Trust feeds cooperation (§1) and is a reader for Wilma and Ella (A54 symmetric: the target mixes both
  directions).

## 4. Misconduct (P1c)

Misconduct reuses the M11 chain: `LawOps.record_greed`-style records in `violation_track`, with
`company = police org` and the actor being the police institution.

- New kinds in `GREED_KINDS`:
  - UNLAWFUL_DETENTION and EXCESSIVE_FORCE (SERIOUS);
  - IMPROPER_SEARCH (MINOR);
  - POLICE_CORRUPTION (SERIOUS; data.bribed_by can link to an org).
  - All are on the new channel OVERSIGHT, detected by LAW_POLICE_OVERSIGHT, plus press investigations, whistleblowers
    and complaints by the victims' groups.
- **Rate per station-month** = base × stress factor × powers factor × low-pay factor (from Bob's wage index against
  the private S wage) × (1 − training).
  - Training is a fixed share of the budget for now.
  - Integer records: one record per kind per station while it lasts, and `greed_stop` when the drivers fall. This is
    the same logic Bob uses for firms.
- **On a reveal:**
  - **LAW_POLICE_MISCONDUCT_REVEALED** (PUBLIC). responsible: GOVERNMENT 0.6 and police 0.4.
  - A TORT case for the victims, paid from the treasury.
  - A trust hit in the district.
  - The press can investigate it (add MD.INVEST_W_POLICE).
  - Repeat findings for the same kind within 5 years count as repeats, so an inquiry is opened.
- **No officer individuals in v1.** A notable corrupt officer becomes a named person only in the fact text.

## 5. Political control (P1c)

The government sets the budget, the laws and the structure. It cannot order arrests of opponents (§15.5).

- **New action POLITICAL_ARREST** in the rules engine: a charter-level PROHIBIT, and also a constitution-level one
  once the constitution is in force. It has the same shape as CENSOR_REPORT, so it is always PROHIBITED.
- **Entry point** `Police.order_investigation(world, actor, target {PARTY|PERSON}, reason)`:
  - **Lawful path** (always open): it files a referral. The independent prosecutor opens a case only if there is
    evidence, meaning a revealed or tracked violation against the target. Otherwise nothing happens and an OFFICIAL
    LAW_REFERRAL_DECLINED fact is recorded.
  - **Unlawful path** (only if the caller passes `force: true`; this is Wilma's call for the AI and a player choice):
    - the action is validated as PROHIBITED and carried out anyway;
    - a SECRET LAW_POLITICAL_ARREST fact plus a violation_track row (actor GOVERNMENT, class SEVERE, channel
      OVERSIGHT/PRESS/WHISTLE);
    - the target loses its post for a few months (detained);
    - on a reveal: an UNLAWFUL_GOV case and LAW_POLITICAL_ARREST_REVEALED.
  - Wilma's authoritarian drift reads the LAW_POLITICAL_ARREST facts and a lasting count in my justice state.
- The courts stay independent: the existing judge model decides these cases.

## 6. Workload and stress link (P1d)

- Each station publishes its monthly workload ‰ through the same data contract as services (plan-support-economy §3,
  service tag POLICE).
- **Bob's stress model** returns stress ‰ and the sick share. I use them for:
  - capacity (sick officers);
  - misconduct (stress factor);
  - stress accidents (`WK.stress_accident` at ≥ 1300‰ produces EXCESSIVE_FORCE records, not workplace accidents);
  - quits (handled by Bob).
- **Staffing law.** WK.RATIOS gains POLICE 500 residents per officer, so understaffed police can be UNDERSTAFFING
  under LAW_STAFFING_RATIOS = 2, with the government responsible.

## 7. Interfaces I need

**From Bob** (economy; after his support-economy pieces):

1. `EconQuery.crime_drivers(world) → {district: {...}}` with:
   - pop, unemployed_pm, hunger_pm (food shortfall), homeless_pm, youth_pm (aged 15–24);
   - an income ratio (top 20% / bottom 20%, ×1000);
   - stock_wref (warehouse, shop and stockpile value);
   - firms (count).
   - Integers, per district.
2. The POLICE org and the POLICE_STATION facility type on the PES pattern:
   - staff by tier filled from my `crew_target`;
   - wages from the LAW_POLICE_BUDGET line;
   - support staff by A56.
   - Later, the same for PRISON (P2).
3. Workload and stress for stations through his workload contract: workload ‰ in, stress ‰ and sick share out.
4. Optionally, theft losses. I emit `theft_wref[district]` monthly and he subtracts it from stock or household wealth.
   v1 can skip this.

**From Wilma** (politics):

1. SAFETY and FAIRNESS concerns read `LQ.crime_rate` and the crime facts. The "crime" hot issue goes to Ella.
2. Party positions and the legislature: rows for LAW_POLICE_BUDGET, LAW_POLICE_POWERS and LAW_POLICE_OVERSIGHT
   (tough on crime vs prevention). Please review the ideology signs.
3. Who can take the unlawful arrest path (AI under drift? the player only?), and how drift reads LAW_POLITICAL_ARREST.
4. A/B and chronicle slots: "CRIME" first, then "POLICE".

**From Terra:** stations (and later prisons) on the map per district, from LQ.police_stations(world).

**From Ella:** read only. LAW_CRIME_WAVE and LAW_DISTRICT_UNPATROLLED make campaign material, and `crime_rate` for
the issue.

## 8. Build order and tests

1. **P1a crime model** with a fixed police capacity derived from the budget lever. No org is needed yet.
   - Tests: rates at the reference, a slump raises THEFT, deterrence, crime-wave facts.
   - A/B "CRIME" on vs off, 3 seeds × 50 years.
2. **P1b police org and stations** (needs Bob 2): capacity, clearance, response time, the POLICE detection channel,
   and the unpatrolled facts.
3. **P1c misconduct and political control**: kinds, the oversight channel, POLITICAL_ARREST in the rules engine,
   trust in the police.
4. **P1d stress link** (needs Bob 3).

P2 (criminal procedure, prisons) gets its own note after P1a lands.
