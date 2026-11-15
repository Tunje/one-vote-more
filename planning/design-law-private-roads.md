# Design note: private roads (law side)

Anni, 2026-11-15, for Wilma (user: "private roads, bought and paid for by companies"). Design only, no code. Terra
writes the link model: the owner on a link, access, tolls, maintenance, and the owner's failure. This note says what the
law allows, who decides, and what each choice costs. As everywhere: governments stay free to choose badly. They get
pressures and costs, not bans, unless the lever itself is the ban.

## 0. Today

- Every road link is the colony's: built by Bob's ROAD projects, worn and repaired through the government's road works
  (ROAD_WORKS), paid from the INFRASTRUCTURE line.
- Land law (`land_law.gd`, M13) already has:
  - titles per tile: government freehold unless sold or leased; LAW_LAND_DISPOSAL KEEP / LEASE / SELL;
  - zoning: UNZONED / RESIDENTIAL / INDUSTRIAL / FARM / RESERVE;
  - expropriation (EXPROPRIATE: needs a public purpose and compensation of at least 100% of the land's value);
  - clearance and eviction rules.
- Transport law (`transport_law.gd`) has LAW_ROAD_TOLL: a **public** toll per vehicle trip on PAVED roads, paid to the
  treasury.
- **Nothing lets a firm own a road.** Since FREIGHT_ROADS, a firm whose freight is held back can only wait for the
  government's road works.

## 1. May a company build a road? `LAW_PRIVATE_ROADS`

A new LAW-level lever (NUMBER 0–2, default 1):

| setting | meaning |
|---|---|
| **0 FORBIDDEN** | only the state builds roads. A firm may pay the state to build one (a contribution, §6), but the road is public. |
| **1 BY LICENCE** (default) | a firm may build a road with a **road licence** from the Minister of Infrastructure (§1.1). |
| **2 FREE** | no licence. A firm builds on land it holds, as it builds a plant. Zoning, safety and the access rules still apply. |

**The small exception** (settings 1 and 2): a TRACK lying wholly on the builder's own or leased land in one district
(a farm track, a mine's haul road) needs no licence. It's part of the site.

### 1.1 The road licence (setting 1)

- **Application:** the firm files the route (tiles, kind, lanes, the junctions where it meets public roads) and the
  access regime it offers (§3). The filing is public (fact LAW_ROAD_LICENCE_FILED), so districts and the press see it.
- **Objection window:** 2 months. Each district the road crosses may object (§2.2).
- **Decision:** the Minister of Infrastructure, on four grounds:
  1. the land is lawfully held (§2);
  2. the road meets the safety standard (LAW_TRANSPORT_SAFETY, as for vehicles);
  3. its junctions don't overload the public road (Terra's junction capacity: the minister may require the firm to pay
     for upgrading the public junction);
  4. objections are weighed.
- **The minister may refuse for any of the four grounds, or for none.**
  - A refusal with no ground is lawful but public (fact LAW_ROAD_LICENCE_REFUSED, `grounds: []`).
  - The firm may appeal; the court reviews it as an ordinary case. A refusal with no ground is quashed, and the licence
    is then granted.
  - So a government can block private roads it dislikes. It pays in court time, press and the firm's anger, not with a
    ban.
- **Conditions** the licence may carry:
  - the access regime (common carriage when the road would be the only good route, §3.2);
  - a junction contribution;
  - the maintenance duty (§5).
- **Term:** none. The licence lasts while the duties are kept. It's revoked only for neglect (§5) or ended by a
  takeover (§4).

## 2. Land, and what the districts can say

### 2.1 On whose land

A private road is built only on land the builder **holds** (owns or leases, `LandLaw.right_of`):

- **Its own or leased land:** zoning permitting. RESERVE allows no roads. RESIDENTIAL needs `may_clear` if people live
  there, as today.
- **Government land:** the firm leases a strip (a **wayleave**) through the ordinary land-law lease
  (`grant_land` mode LEASE, rent at the land-law yield). Under LAW_LAND_DISPOSAL = KEEP the state leases no land. Under
  settings 1 and 2 a road strip is the one exception, because a road can't be built otherwise. The wayleave runs as long
  as the road licence does.
- **Other owners' land** (households, firms): only by agreement (`transfer_title` or a lease at a price they accept).
- **No private expropriation.** A firm can never force a sale. The state may expropriate **for** a private road only if
  the road is common-carrier (open to all, §3), because only then is it a public purpose. That's an expropriation
  through the existing rule (≥ 100% compensation), paid by the firm, decided by the Cabinet (§7).

### 2.2 The districts' say

There are no district governments, so a district speaks through its residents.

- **An objection** is raised when the road would:
  - clear housing;
  - cut a FARM or RESERVE zone;
  - or load the district's public junctions past capacity × JAM_ALLOW.
  - Wilma may add "the district's mood is against it" from her district opinion.
- **An objection is not a veto.** The minister may override it:
  - the override is public (fact LAW_ROAD_OBJECTION_OVERRIDDEN, with the districts);
  - it is felt in those districts the way POL_ROAD_PASSED_OVER is (Wilma's resentment mechanics), so it costs votes
    where the road runs.
- **Wilma's answer (2026-11-15):** the objection reads district opinion. Until she gives a query for it, that's the
  district's INFRASTRUCTURE satisfaction and the government's vote share there (`GovBuilder._district_share`). The
  override fact carries `"affected": {"districts": [d]}`, like POL_ROAD_PASSED_OVER.
- **Under setting 2 (FREE)** there is no licence and no objection window. The districts' only protection is zoning and
  clearance law. That's the political price of FREE.

## 3. Access and tolls

### 3.1 The owner's choice

The owner sets one of three regimes per road, within what the law allows:

| regime | who drives on it | toll |
|---|---|---|
| **OWNER** | the owner's own freight (and its suppliers' or customers' deliveries to it) | none |
| **OPEN_TOLL** | anyone, on equal terms | the posted toll, capped (§3.3) |
| **OPEN_FREE** | anyone | none (a firm may do this for goodwill, or to bring buyers to its district) |

### 3.2 `LAW_PRIVATE_ROAD_ACCESS`: common carriage

A LAW-level lever (NUMBER 0–1, default 0):

- **0 OWNER_CHOOSES:** the owner picks any regime. Competition law still applies: a road that is the **only good route**
  between two districts is an **essential facility**. Here "only good route" means the public alternative is ≥
  DETOUR_PM (1.6×) longer, or its `deliverable_pm` < 800. Refusing a rival access to an essential facility is
  ABUSE_OF_DOMINANCE (the existing competition rule, channel MARKET), and the authority can order access at a capped
  toll.
- **1 COMMON_CARRIER:** every private road between districts must be OPEN_TOLL or OPEN_FREE. The owner may reserve at
  most **50% of the road's capacity** for its own freight, and must carry others in the rest at the posted toll.
  - Turning away traffic within the open half: greed kind **ROAD_ACCESS_REFUSED** (MARKET, MINOR; SERIOUS when the road
    is an essential facility).
  - Charging a rival more than others: the same kind.

Commuters on an open road pay the car toll (the truck toll ÷ TRUCK_PCU). An OWNER road carries no commuters.

### 3.3 `LAW_PRIVATE_TOLL_CAP`

- A LAW-level lever (NUMBER 100–300, default 200; 300 = no cap). The highest toll per truck trip is set as a % of the
  road's **cost-recovery toll**:

  ```
  cost-recovery toll = (upkeep a month + build cost ÷ 240) ÷ last year's monthly truck trips (at least 1)
  ```

  This is 20 years' write-off plus upkeep. Terra or Bob compute it from the link's record. It is pure, so the law only
  compares.
- The cap binds every open private road. The public LAW_ROAD_TOLL doesn't apply to private roads; a firm's road is not
  a tax base.
- **Above the cap:** greed kind **TOLL_OVER_CAP** (MARKET, MINOR). The overcharge is refunded to the users as a
  COMPENSATION liability when found.
- **Whose lever:** the cap is parliament's. **Who enforces it:** the Minister of the Economy's competition authority, as
  for gouging.

## 4. The state buying or taking over a road

### 4.1 By agreement

The government may buy any private road at any time at an agreed price.

- **Who decides:** the Minister of Infrastructure, with the Minister of Finance's consent on the price.
  - Up to LAW_STATE_AID_THRESHOLD (shares note): ministers alone.
  - Above it: **the Cabinet**.
- **Overpaying is state aid:** paying more than 150% of the road's value (§4.2) to a firm linked to a governing party
  (a donation in 24 months) is public (fact LAW_PUBLIC_SALE_LINKED_BUYER, as for plant sales).

### 4.2 Compulsory takeover

The state may take a private road without the owner's consent for a public purpose. Purposes:

- to open it;
- to end a neglect it can't otherwise cure (§5);
- to fold it into the public network.

**The price is the road's value:**

```
value = build cost × condition ÷ 1000   (depreciated replacement cost)
      + the land under it at land-law value (LandLaw.land_value; leased state land counts as 0)
      − public money already put into it (contributions, grants, the state's step-in repairs unpaid, §5)
```

- **No payment for lost tolls.** This is the expropriation rule's "≥ 100% of value", extended to the road.
- **Paying less is unlawful:** the existing EXPROPRIATE rule. A government may still do it through
  `proceed_unlawfully`, with the usual risks (courts, press, the firm's case).
- **Who decides:** **the Cabinet (First Minister).** Taking property is never one minister's act. Parliament isn't
  needed, as expropriation is already authorised in law.
- **Facts:**
  - LAW_ROAD_TAKEN_OVER (PUBLIC; price, value, purpose);
  - the owner's grievance: a COMPANY-side opinion hit Wilma can read, as for nationalisation.

After a takeover the road is public: the road works maintain it and LAW_ROAD_TOLL applies. The cost of upkeep moves to
the INFRASTRUCTURE line. That's the pressure on a government that takes roads it can't keep.

## 5. Neglect

A licensed road carries a **maintenance duty**: condition kept at or above **400 / 1000**, where Terra's link starts to
wear down a kind. An OWNER road under FREE has only the general safety duty.

The ladder, monthly, from the link's condition:

1. **Notice.**
   - Below 400 for 3 months: fact LAW_ROAD_NEGLECT_NOTICE (PUBLIC, the owner, the link). The owner has **6 months** to
     bring it back to 400.
   - Not bringing it back: a greed record **ROAD_NEGLECT** (SAFETY, MINOR), found by the transport inspectorate (the
     LAW_TRANSPORT_SAFETY channel). On an open road, the users' freight losses aren't a tort; their remedy is the
     licence.
2. **Step-in.** After the 6 months the Minister of Infrastructure **may** have the road works repair it at the owner's
   cost.
   - The cost becomes a COMPENSATION liability of the owner to the treasury: class P under the creditor order, and late
     interest under LAW_LATE_PAYMENT_INTEREST.
   - Fact LAW_ROAD_STEP_IN.
   - The minister may also do nothing. Then a neglected road is the government's political problem too: its own fact
     **LAW_PRIVATE_ROAD_UNENFORCED** (PUBLIC; responsible owner 0.8 / government 0.2; `"affected": {"districts": [d]}`)
     is felt in the district. It is emitted when a road is still below 400 6 months after the notice and no step-in
     was ordered, and again each 6 months it stays so. POL_ROAD_NEGLECTED stays for public roads (Wilma, 2026-11-15).
3. **Revocation.** Repeated neglect (two notices in 24 months, or step-in costs unpaid for 12 months) lets the minister
   **revoke the licence**.
   - The road then must be sold (§6 rules) within 12 months, or the state takes it over at value minus the unpaid
     repairs (§4.2).
   - Revocation is the minister's alone. Taking it over is the Cabinet's, as in §4.2.
4. **An accident** on a neglected road (Bob's or Terra's vehicle accidents):
   - the greed record becomes SERIOUS and is revealed by the accident;
   - the victims get a TORT against the owner (paid through the victim fund, as for wildlife negligence);
   - the M11 chain names the owner responsible 0.8 and the government 0.2 (it didn't step in).

## 6. When the owner fails

A private road is an **asset of the estate** like a plant.

- **Security:** the bank may take the road as security for a loan (class S in the creditor order). That's normal.
- **In administration:** the road keeps running under its regime. An open road may not close during administration:
  closing it would hurt other users to squeeze the estate.
- **The sale:** the road is sold through `SaleLaw.check_sale`, with path LIQUIDATION.
  - **The buyer takes the licence and its conditions** (access regime, reserved share, maintenance duty). A sale can't
    wash a common-carrier condition.
  - **A buyer who is a rival freight user** in the road's market is a concentration: merger review, failing-firm
    path (1 month). If the road is an essential facility, the review's CONDITIONS is "common carriage", not BLOCK.
  - **The state's first right:** the state may buy at the sale floor before other buyers. That's the Minister of
    Infrastructure up to the aid threshold, else the Cabinet.
- **No buyer within 6 months:** the road **reverts to the state** without payment (fact LAW_ROAD_REVERTED). Its value,
  zero, goes into the creditor order: the creditors get nothing for it, and the bank's security over it lapses.
  - The government then chooses: maintain it (an INFRASTRUCTURE cost) or let it decay.
  - Either is lawful. Decay is public through Terra's condition and Wilma's POL_ROAD_NEGLECTED.

## 7. Private roads and concessions (my concessions note, E173)

These are different things and don't mix:

| | road concession (E173) | private road (this note) |
|---|---|---|
| **who owns the road** | the state | the firm |
| **who pays** | the state pays the concessionaire per job, plus the retainer | the firm, from its own money; tolls if open |
| **what it is** | a contract to build and maintain **public** roads | property: a road the firm owns |
| **procurement law** | applies (tendered, ProcLaw) | doesn't apply: it's private building |

Where they meet:

- **A firm hiring a builder for its private road:** an ordinary private construction contract (contracts note). It is
  not concession work. If the builder holds the road concession, the private job counts against its start duty like
  any private job: it may not delay a concession job past the quote.
- **The state's road works** (and a concessionaire) never maintain a private road, except by step-in (§5) or after a
  takeover. `road_needs` may count private road capacity on routes (it's real capacity), but the government's budget
  can't be spent on it.
- **A private road built on a public road's line:** not allowed. A firm can't take over or toll an existing public link.
  That would be a concession to toll public property, which needs a law (a separate, later lever if the user wants
  public toll-road concessions).
- **A contribution (setting 0, or by choice):** a firm may pay the state toward a public road it wants. The road is
  public, built by the road works or the concessionaire. The money is a gift to the treasury, public if the firm is
  linked to a governing party. No rights in the road come with it.
- **No exclusivity:** a licence gives no promise that the state won't build a public road alongside. That's the owner's
  risk.

## 8. Who decides

| decision | owner | alone? | goes higher when |
|---|---|---|---|
| LAW_PRIVATE_ROADS, LAW_PRIVATE_ROAD_ACCESS, LAW_PRIVATE_TOLL_CAP | **parliament** (LAW levers) | no | a bill |
| Grant or refuse a road licence | **Minister of Infrastructure** | yes | the road crosses 3+ districts, or needs a state expropriation for it: **the Cabinet** |
| Override a district objection | **Minister of Infrastructure** | yes, but public and felt in the district | n/a |
| Wayleave on state land | **Minister of Infrastructure** (land-law lease) | yes | n/a |
| Expropriating others' land for a common-carrier private road | **the Cabinet** | no | n/a |
| Ordering access to an essential facility; toll-cap enforcement | the competition authority; **Minister of the Economy** on review | yes | n/a |
| Neglect notice | the transport inspectorate (automatic) | n/a | n/a |
| Step-in repair; licence revocation | **Minister of Infrastructure** | yes | n/a |
| Buying a road by agreement | **Minister of Infrastructure** + Finance on price | up to LAW_STATE_AID_THRESHOLD | above: **the Cabinet** |
| Compulsory takeover | **the Cabinet (First Minister)** | no | n/a |
| The state's first right in a failed owner's sale | **Minister of Infrastructure** | up to the aid threshold | above: **the Cabinet** |
| Maintaining or abandoning a reverted road | **Minister of Infrastructure** (budget) | yes | n/a |

Most of this stays with the Minister of Infrastructure. The Cabinet sees only big licences, takeovers and
expropriations.

## 9. Ideology (proposals for Wilma)

Sign convention as in the concessions note: ECON_ROLE negative = market-minded.

- **LAW_PRIVATE_ROADS** (0–2, default 1):
  - ECON_ROLE −6 per step (market-minded want FREE);
  - INSTITUTIONS −2 per step (FREE drops a licence).
  - Concerns per step: INFRASTRUCTURE +5 / FAIRNESS −2 / GOVERNANCE −2.
- **LAW_PRIVATE_ROAD_ACCESS** (0–1, default 0):
  - ECON_ROLE +6, REDISTRIBUTION +3 for common carriage.
  - Concerns: FAIRNESS +4 / JOBS +2 / INFRASTRUCTURE −3 (fewer firms build when they must share).
- **LAW_PRIVATE_TOLL_CAP** (100–300, default 200):
  - ECON_ROLE −0.05 per point (market-minded want it high or off).
  - Concerns over the range: COST_OF_LIVING −5 / INFRASTRUCTURE +3.

## 10. Interface (for Terra and Bob, when coded; flag Terra's, e.g. PRIVATE_ROADS on FREIGHT_ROADS)

```
RoadLaw.may_build(world, org, plan) -> {status: LAWFUL|NEEDS_LICENCE|REFUSED, reasons, land: [{tile, right, need}],
                                        objections: [district], needs_cabinet}
    plan = {tiles, kind, lanes, junctions, regime, districts}
RoadLaw.apply_licence(world, org, plan) -> licence id      # filing fact; decided after the 2-month window
RoadLaw.licence(world, lid) -> {} or {id, org, status, conditions {regime_min, reserved_pm, junction_fee}}
RoadLaw.access(world, link) -> {regime, reserved_pm, toll_cap_mcr}      # pure; the link carries owner, regime, toll
RoadLaw.check_toll(world, link, toll_mcr, cost_toll_mcr) -> bool
RoadLaw.monthly(world)                                     # the neglect ladder from link condition (reads only)
RoadLaw.value(world, link) -> mcr                          # §4.2
RoadLaw.take_over(world, link, mode: AGREED|COMPULSORY, price) -> {lawful, needs_cabinet, unlawful_id}
RoadLaw.on_owner_failed(world, link) / RoadLaw.revert(world, link)
```

**From Terra's link record:** `owner`, `regime`, `toll`, `build_cost`, `public_money`, `licence`, `condition`, and the
truck trips (for the cost toll). Bob books every payment (tolls, wayleave rent, step-in costs, compensation). The law
decides and records.

**New law pieces:**

- greed kinds ROAD_ACCESS_REFUSED, TOLL_OVER_CAP, ROAD_NEGLECT;
- facts LAW_ROAD_LICENCE_FILED, LAW_ROAD_LICENCE_GRANTED / _REFUSED, LAW_ROAD_OBJECTION_OVERRIDDEN,
  LAW_ROAD_NEGLECT_NOTICE, LAW_ROAD_STEP_IN, LAW_PRIVATE_ROAD_UNENFORCED, LAW_ROAD_TAKEN_OVER, LAW_ROAD_REVERTED;
- three levers;
- rules:
  - AUTHORIZE BUILD_PRIVATE_ROAD by setting;
  - PROHIBIT REFUSE_ROAD_ACCESS under common carriage;
  - EXPROPRIATE for a private road only if it is open.

## 11. Tests (when coded)

1. Setting 0 refuses; setting 1 needs a licence; setting 2 needs none. A farm track on own land never needs one.
2. A road over another owner's land without agreement is refused. The state expropriates for it only if it is open.
3. An objection overridden is a public fact naming the districts.
4. Common carriage: refusing traffic in the open half is ROAD_ACCESS_REFUSED. An essential facility under
   OWNER_CHOOSES can be ordered open.
5. A toll above the cap is TOLL_OVER_CAP; at 300 there is no cap.
6. A takeover pays the depreciated cost + land − public money. Paying less is an unlawful act. It needs the Cabinet.
7. Neglect: notice at 3 months below 400, then step-in at the owner's cost (a class-P claim), then revocation.
8. Owner failure: the buyer takes the licence's conditions. With no buyer in 6 months, the road reverts.
9. Flag off: nothing changes.

## 12. Questions

- **Terra:**
  - Can a link carry `owner` / `regime` / `toll` / `build_cost` / `public_money`?
  - Can a private link be kept out of the government's road works and out of LAW_ROAD_TOLL?
- **Bob:**
  - Who builds the road for the firm: an ordinary construction job by a builder, so the contracts note applies?
  - Does the firm's choice to build use rule 8 (`deliverable_pm` held back × the margin lost vs the road's cost)?
- **Wilma:** answered (§2.2, §5).
