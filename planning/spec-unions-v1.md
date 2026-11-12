# Spec: Unions as organisations (v1)

User decision 2026-11-12 (A41): "if we have strikes, where are the unions?" Unions become real organisations:
named, with members, money, leaders and decisions, and a political role. Today (M9) they are statistics: a
density per occupation, strikes rolled from a probability, one abstract "union:fed" endorsing a party. This spec
replaces that with actors while keeping what works (density targets, stoppage mechanics, union_pm wage premium,
LAW_ESSENTIAL_SERVICES).

Owners: **Bob** U1–U2 (organisations, bargaining, strikes), **Wilma + Ella** U3 (politics), **Anni** U4 (law),
**Wilma** U5 (UI and news). Order: U1 first (others build on its tables), then U2–U4 in parallel, U5 last.
No hidden autopilot: when the player governs, unions bargain with the player's government (the player answers);
nothing is settled on the player's behalf.

## 1. The unions (U1, Bob)

- Table `union`, one row per union:
  `{id, name, sectors: [occ...], members (mu), density (‰), fund (ledger acct union:<id>), dues_pm, leader: {name,
  militancy 0..100, competence 0..100, ambition 0..100, since}, mood (0..100 grievance), status ACTIVE|MERGED|DISSOLVED,
  founded, federation: bool, affiliated_to: union id or ""}`.
- Founding set (colony start, after the first year of work): one union per unionised sector, named from the work:
  Miners' Union (MINING), Builders' Union (CONSTRUCTION), Power & Water Workers (POWER/WATERWORKS staff, LOGISTICS
  may join "Transport & Depot Workers"), Plant Workers' Union (MANUFACTURING), Farm Workers' Union (AGRICULTURE),
  Public Servants' Union (PUBLIC_SECTOR), Shop & Service Workers (SERVICES), Professionals' Association
  (PROFESSIONAL, moderate by nature). Names per colony may vary; keep them plain.
- The **federation** (replaces "union:fed"): founded once 3+ unions exist; affiliated unions pay it a share of dues;
  it speaks politically for its members (endorsements, donations, the union paper).
- Membership: density targets as today (BASE_DENSITY × union rights law), applied to the real employed persons per
  occupation (PopStore). Members are a count, not a leaf field (no new PopStore key). Unemployed members lapse
  slowly (keep 30% for 12 months).
- Dues: a small per-member amount from household pools to the union account (closed ledger, never EXTERNAL).
  Fund pays strike pay, campaigns, donations, the union paper's cover.
- Leaders: elected at founding and every 4 years (or after a lost strike / scandal); a militant wins when mood is
  high, a moderate when the fund is low or the last strike was lost. Names from the person name pool; a leader can
  later stand for a party (U3).
- Unions can merge (two small unions in related sectors) and a breakaway can form when a moderate leadership ignores
  high mood for a long time (militant splinter). Rare.

## 2. Bargaining and strikes (U2, Bob)

- Grievance (mood) per union from: real wage vs last settlement, layoffs, accidents/unsafe plants in its sector,
  labour laws moving against workers (existing LABOR_LEVERS hook), employer profits vs pay.
- **Demands**: when mood passes a threshold (lower for militant leaders), the union tables a demand to an employer
  (a company, or the government for public sector): `{kind: WAGE|SAFETY|JOBS|RECOGNITION, size, deadline}`.
  Fact `UNION_DEMAND`.
- **Employer answer** (company AI by greed/cash/profit; the AI government by ideology; the **player** answers
  through the UI when the public sector is struck while they govern): ACCEPT, COUNTER, REFUSE. Facts
  `UNION_SETTLED` / `UNION_TALKS_FAILED`.
- **Strike decision** after failed talks: leader militancy × mood × fund strength (weeks of strike pay it can
  afford) × the ballot law (U4). A broke union cannot strike long. Lockouts by employers stay.
- **During a strike**: stoppage mechanics as today (STRIKE_WORK, essential-services law). Strike pay drains the fund;
  when the fund runs out, members drift back and the strike collapses (lost strike). Each month both sides may settle.
- **Outcomes**: won (wage premium as today, mood falls, leader strengthened), compromise, lost (mood rises, leader
  at risk, density dips). Arbitration under NO_STRIKE as Bob implemented.
- General strike: the federation can call one against a law (e.g. union rights cut) if 2+ big unions are in
  dispute; rare, very visible, all sectors partial.

## 3. Politics (U3, Wilma + Ella)

- **Endorsements** come from the federation and from big unions separately (they can disagree), based on party
  positions on LABOR/REDISTRIBUTION, the party's record on labour laws while governing, and personal ties.
  Replaces PartyLife.endorsements' single union entry; vote model keeps UNION_ENDORSE_BETA × member density.
- **Donations** from union funds to endorsed parties in election years (through the existing donation booking).
- **Labour party founding**: if density is high and no active party sits near the labour pole (LABOR) with
  credibility, the federation may found one (a new party kind UNION, named e.g. "Labour Party", "Workers' Party").
- **Betrayal**: a governing party that cuts union rights, minimum wage or benefits loses the endorsement and can
  trigger a split of its union wing.
- **Leaders into politics**: a popular union leader may become a party candidate or leader (ties the union and the
  party; scandals and strikes then hit both).
- Governments react: AI governments respond to public-sector demands by ideology; pro-labour governments settle,
  market governments resist; strikes in essential services push INSTITUTIONS-minded parties toward strike laws.

## 4. Law (U4, Anni)

- Existing: ECON_UNION_RIGHTS (number), LAW_ESSENTIAL_SERVICES (enum).
- New: strike ballot rule (NONE / MAJORITY / SUPERMAJORITY), closed shop (allowed / banned), public-sector right to
  strike, union recognition (employer must bargain above a density threshold), illegal strikes (a strike against
  the rules lets the employer sue the union fund; courts as for defamation), political levy (members may opt out of
  the union's party donations).
- Union papers: the paper belongs to the federation (or a big union) and is paid from its fund (media M4).

## 5. UI and news (U5, Wilma)

- **Unions window** (Politics group): each union's members, density, fund, leader (militancy), mood, current
  demand/dispute, endorsement; the federation on top. Click → dispute detail; when the player governs and the
  public sector is in dispute, the player answers the demand here.
- News sentences and Gazette headlines for every new fact (demand, settlement, talks failed, strike called,
  strike collapsed, general strike, leader elected, union founded/merged/split, endorsement withdrawn).
- Chronicle: a unions section (unions over time, disputes and outcomes, endorsements).

## 6. Acceptance (century runs, 3+ seeds)

- Every colony has 5–9 active unions after Year 5 and a federation; at least one leader change per union per 20 years.
- Strikes follow from failed talks (no strike without a prior demand), 2–12 strikes a decade colony-wide; at least
  one lost strike and one won strike per seed; no union strikes with an empty fund for more than 2 months.
- Union endorsement goes to different parties over a century on at least 2 seeds (betrayal works).
- Ledger closed; determinism and save/load hold; no new PopStore keys.
