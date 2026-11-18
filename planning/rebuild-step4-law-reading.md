## Step 4: the law's hold (Anni). Read in the shared tree after the 61c and benefit merges, 2026-11-18

Step 4 (rebuild-company 13), verbatim heading: "Everything that is sold, and how it moves, together. All items; the types
with work slots (public services, shops, utilities on the grid); freight on the roads with the queue, carriers' prices,
trucks and truck workshops." The law's pieces follow from what step 4 brings in: more types founded, roads and freight,
the grant's road to a spot, police, prisons and newspapers as companies.

### L1. A road built and owned by a company, and charging for its use

- **Words.** The user, 2026-11-17, answer 3 on the grant's spot (rebuild-company 13, step 4, l.1397), verbatim: "Most
  comonly the government but if a company out a collective wants to they should be able to,  that could come in planing
  of grants the government asks and if any company wsnts it but that would cost but they would be free to charge for
  using it". Earlier, user via Wilma 2026-11-15 (road_law.gd header): "private roads, bought and paid for by companies".
- **Against it in the plan:** 12.4, 33 (Wilma's) "Private roads and tolls are left out for now"; 12.12 "private roads
  and tolls" left out; law-face 12 (Anni's) "Private roads and tolls are left out (12.12). `road_law` stays and is
  dormant". All three are older than or equal to the user's answer 3, which says a company may build the spot's road
  and charge for it.
- **In the tree:**
  - `sim/law/road_law.gd` (Anni's, old code kept): the licence for a private road (`may_build`, `licence_decision`,
    2-month objection window, the minister or the Cabinet for 3+ districts), access and toll readers, maintenance duty,
    neglect ladder, step-in (`ROAD_STEP_IN` liability), revocation and take-over. Levers `LAW_PRIVATE_ROADS` (default 1
    LICENCE), `LAW_PRIVATE_ROAD_ACCESS`, `LAW_PRIVATE_TOLL_CAP` (default 200 %).
  - `sim/transport/private_roads.gd` (Terra's): the owner, regime OWNER / OPEN_TOLL / OPEN_FREE, toll, build cost on a
    link; `transport.gd:1139` `PrivateRoads.on_built`.
  - Both are off: `RoadLaw.on` needs `meta.on` to hold PRIVATE_ROADS and FREIGHT_ROADS; `game_sim.gd:12-13` starts
    every game with `meta.on = []`.
- **Missing:**
  - the grant's road offered to companies when the grant is planned ("the government asks");
  - a company taking it on, paying for it, owning it;
  - its toll in a rebuilt game: the rebuilt company has no road account, and nothing books toll income as revenue;
  - the plan line that lets private roads back in at step 4.
- **Whose:** the law's hold (licence, toll cap, access, neglect) Anni; the link, owner fields and route cost Terra;
  the money Bob; "the government asks" at the grant Ella.
- **Ours:** every number in road_law (objection 2 months, Cabinet at 3 districts, common carriage keeps ≤ 50 %, toll
  cap 200 %, maintenance cond ≥ 400) is old design (design-law-private-roads.md), not the user's.

### L2. The public road toll

- **Words:** none from the user. Law-face 11 (Anni's): `LAW_ROAD_TOLL` "each trip on a paved road | the carrier",
  "Until step 8 (10): no charge is taken".
- **In the tree:** `transport_law.gd:65` `road_toll` (0–20 milli-W_ref a trip, default 0); its only reader is
  `private_roads.gd:291`, which is off.
- **Missing:** nothing for step 4 if the paper's "until step 8" stands; with freight on, a toll set above 0 does nothing.
- **Whose:** Anni (the lever), Bob (the carrier's cost), Terra (trips).

### L3. Licences when more types are founded

- **Words:** none from the user on licences in the rebuild. 12.10, 66 (Wilma's): "Licences and permits work as
  before". Build order step 6 (Wilma's): "permits and licences; land sales". Law-face 2 (Anni's): "Until step 6: every
  plan and plant is lawful as it stands, with no permit, licence or fee."
- **In the tree:** `LawCompany.licences_required` (law_company.gd:133): HAZARD for a row with `hazard: true` (MINE,
  PROCESSING, MEDWORKS, POWER) and EXTRACTION for MINE, because `LAW_LICENCE_REGIME_HAZARD` and `_EXTRACTION` default
  to REQUIRED (law_data.gd:376-381). `may_sign` (l.159) files the application, and the plan waits until it is granted;
  `may_open` (l.196) closes a plant without one; `reopen_licensed` reopens it. The audit (audit-rules-anni,
  "Licences at step 3") has this as DIFFERENT from law-face 2, unseen only because FARM alone is founded.
- **What step 4 changes:** once mines, processing, medical works or power are founded, plans wait for a licence in
  the permit office's queue and plants open only licensed. That is a step-6 act biting at step 4.
- **Whose:** Anni.

### L4. Building permits

- **Words:** none from the user. Law-face 2.1 (Anni's): a plan needs a building permit before it signs, at step 6.
- **In the tree:** no permit is asked at step 3 (`may_sign` checks zone and licences only). SAME with the paper.
- **Missing for step 4:** nothing, if permits stay at step 6.

### L5. Zoning for the new types

- **Words:** the user, 61c, "Yes on zoning laws" (law-face 8.5, MASTER-PLAN). Law-face 8.5 (Anni's): five zones,
  unzoned allows every use.
- **In the tree:** `LandLaw.ZONE_USES`; `zone()` per tile; since 61c the colony-wide `zone_colony` (INDUSTRIAL against
  farms) with plans made before it keeping their site; `Site.zone_allows`, `LandLaw.terms`, `LawCompany.may_sign` all
  read `zone_of`. `use_of(type)` maps each type to HOUSING / INDUSTRY / MINE / FARM / SERVICE.
- **What step 4 changes:** the colony zone INDUSTRIAL allows INDUSTRY, MINE and SERVICE, so it stops only farms. Town
  cells are outside it. Nothing zones town cells, and no act of the government zones for any other type.
- **Missing:** none for the words as they stand.

### L6. Workplace accidents

- **Words:** 12.10, 69 (Wilma's): "An accident at work is the company's to pay for." Law-face 5.3 (Anni's): "Accidents
  may happen from production at step 3. They are published and counted, but nobody pays".
- **In the tree:** the type table has `accidents` per 1000 workers a year (MINE 25, PROCESSING 15, ...), and no code
  reads it (audit: NOT BUILT, step 3).
- **What step 4 changes:** the dangerous types arrive at step 4, so the gap starts to matter.
- **Whose:** Anni (the law's side), with the company's output (Bob).

### L7. Road accidents

- **Words:** 12.4, 33 (Wilma's): "road safety are all part of the rebuild and on".
- **In the tree:** `RoadSafety.on` returns true, and road-accident court cases are filed (audit: an act with no plan
  line). With trucks at step 4 there will be more vehicles.
- **Missing:** who pays when a truck of a rebuilt carrier is in an accident (today the treasury or a road company pays
  the victims' fund).

### L8. Police stations and prisons (state service companies)

- **Words:** law-face 12 (Anni's): "Police stations and prisons are state service companies (step 4)"; "Crime reads
  the households ... from step 3"; "Until step 4 the police's strength comes from the lever as now, and the court
  sends no one to prison". 12.6, 44 (Wilma's): "police lowers crime".
- **In the tree:**
  - the type table has POLICE (`@resident`, qty 2500) and PRISON (`@prisoner`, 50) rows;
  - crime (`crime.gd:64`) and police (`police.gd:56`) are opt-in ("CRIME", "POLICE" in `meta.on`), so both are off in
    a rebuilt game. That is DIFFERENT from "Crime reads the households ... from step 3";
  - `crime._station_hours` reads `EconFace.police_hours` (-1 with no stations) and falls back to the lever;
  - prisons (`criminal.gd`) are opt-in "PRISONS".
- **Missing:** a police company's staff counted as officers; prisoners as a prison's clients; crime switched on.
- **Whose:** the companies Maja or Ella (public services); crime, the court and sentences Anni.

### L9. Newspapers as companies

- **Words:** 12.6, 48 (Wilma's): "A newspaper is a company whose clients are its readers". Law-face 12 (Anni's):
  newspapers are companies from step 4; `LAW_PRESS_LICENSING` LICENCE "becomes a licence with a fee, never refused for
  being a newspaper"; `LAW_MEDIA_OWNERSHIP_CAP` limits papers per owner. Job adverts are paid to a newspaper (9.2,
  the user: "costs of hiring, articles in the newspaper").
- **In the tree:**
  - the type table has a NEWSPAPER row (`@reader`, 2000);
  - media's outlets are their own objects (`media_ops.gd`, `MAX_OUTLETS`), not companies;
  - `media_ops.gd:128` refuses a paper "NO_PRESS_LICENCE" under LICENCE when `opts.licensed` is false;
  - `media_ops.gd:1661`: under LICENCE "the government licenses only owners not opposed to it". That is DIFFERENT from
    law-face 12's "never refused for being a newspaper" read with 12.10, 65;
  - the advert money goes to the state Gazette account (audit).
- **Missing:** the outlet as a rebuilt company; the licence fee; adverts paid to that company.
- **Whose:** Ella (services; what politics reads) and Anni (media, the press law).

### Questions (the user's words do not decide)

1. Answer 3 says a company may build the spot's road and "be free to charge for using it". 12.4, 33 and 12.12 still
   say private roads and tolls are left out. Do private roads and their tolls come back at step 4, for the grant's road
   only, or for any road a company wants?
2. If a company charges for its road: is the toll its own choice, or capped by a law the government can change (the old
   `LAW_PRIVATE_TOLL_CAP`)? And may it refuse other carriers its road?
3. Licences for hazardous types and mines: from step 4, when those types are first founded, or still at step 6 as the
   build order says? Until then, may a mine or a power plant open with no licence?
4. Workplace accidents: at step 4 do they cost the company anything (12.10, 69 "the company's to pay for"), or only get
   counted until the court exists at step 5?
5. Police and prisons: at step 4, does crime switch on, so police companies have something to lower?
6. Newspapers: does the press licence still let the government refuse owners opposed to it, or is it only a fee?
