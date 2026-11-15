# Design note: delivering the charter quota (law side)

Anni, 2026-11-15; agreed with Bob (E171) and Wilma. For Bob's quota design (user order via Wilma). Analysis and design only. Code comes only behind Bob's
opt-in flag, after an A/B.

## 0. What exists today

The machinery the law side already has:

- **`CharterOps.quota_due(world)`** returns `{due, share_pct, price_pct, reason}`.
  - due is true while the colony is colonial (COLONY or AUTONOMY) and not refusing.
  - reason is the status (INDEPENDENCE_DECLARED or INDEPENDENT) or "REFUSAL".
- **`CharterOps.export_terms(world, good)`** returns `{colonial, reserved, levy_pct, charter_price_pct, export_tax_pct,
  refusal}`. `EconTrade.prices` already uses it: reserved goods sell at the charter price, then the levy and export tax
  apply.
- **Charter rules (CHARTER level, source COLONIAL_CHARTER):**
  - Prohibited for anyone: SELL_COLONIAL_GOOD to a buyer other than HOME_WORLD, and WITHHOLD_QUOTA.
  - Prohibited for public actors: OBSTRUCT_QUOTA, REFUSE_QUOTA, and LEVY_TAX on base QUOTA or COLONIAL_EXPORT.
  - Prohibited (D5): REFUSE_EXPORT_TERMS.
- **Greed kinds** (channel HOME, SERIOUS): QUOTA_EVASION (action WITHHOLD_QUOTA) and SMUGGLING (action SELL_COLONIAL_GOOD).
  The economy has never reported either.
- **`home_inspection`** runs at ship arrival and finds HOME-channel records.
  - Found records are revealed and, under LAW_ENFORCE_CHARTER, prosecuted in colony courts (ENFORCEMENT → fine).
  - It emits HOME_EVASION_FOUND, which makes `evasion_proven` true for 36 months. That makes HOME_FINE and
    HOME_APPOINT_GOVERNOR lawful.
- **Refusal** (`refuse_quota`) is open defiance. It makes HOME_APPOINT_GOVERNOR and HOME_EXPEDITION lawful.
- **What is missing:** `EconTrade.on_ship` has `quota := {}  # colonial goods first (none exist yet)`, and no colonial
  goods (RARE_MINERAL, NATIVE_CROP) exist.

## 1. Which goods are quota goods

The charter names the quota goods. I propose a list in the sovereignty state, `sov.quota_goods`, set by the home world
the same way `reserved_goods` is:

- `CharterOps.home_world_designate(world, good, on)`, colonial only;
- it emits LAW_CHARTER_QUOTA_GOOD (PUBLIC, JOBS −2 / +2), on the `home_world_reserve` pattern.

**Default at founding (Wilma, 2026-11-15): MINERAL, MATERIAL and COMPONENT**, the same goods construction uses. The
squeeze on building is intended. `quota_due` returns the list as `goods`, and Bob's E171 reads it from there.
RARE_MINERAL and NATIVE_CROP join if they are ever built.

**Base: a share of output, not of what reaches the port.** The spec says "a share of colonial-goods output". On a port
base, a firm could evade the quota simply by not consigning. Proposed rule:

- due(good, firm) = share_pct × the firm's production of the good since the last ship;
- Bob already counts production, so the quota sits with the producer (the firm), pro rata.

**Delivery.** The due units are taken from the firm's stock (port first, then anywhere) and loaded first, before the
general exports.

- The firm is paid charter_price_pct × the home price, from EXTERNAL.
- The home-world levy, the colony export tax and the A61 home tariff do not apply to the quota. The charter price is
  the whole price, and LEVY_TAX on base QUOTA is already prohibited.
- Everything above the due units is the colony's own: used at home or exported at the market price, with the levy and
  export tax as for any good.

## 2. "The rest is free" and the exclusive-trade rule

**The conflict.** SELL_COLONIAL_GOOD (to anyone but the home world) is prohibited for every "colonial good". If quota
goods counted as colonial goods, the user's "the rest is the colony's to sell freely" would be unlawful.

**Resolution, with no new rule:** a colonial good in the sense of SELL_COLONIAL_GOOD is a reserved good (D5
`reserved_goods`), not a quota good. So:

- **Quota good, not reserved:** the share goes to the home world at the charter price; the rest is free.
- **Reserved good:** all of it goes only to the home world's buyer at the charter price, as today. If it is also a quota
  good, the quota part counts first, and the rest is still sold only to the home world. That is the harsher
  "navigation acts" setting the home world can impose.
- **SMUGGLING** therefore applies only to reserved goods sold elsewhere. Quota goods above the quota can't be smuggled.

I'd make this explicit by changing comments in law_data.m12_rules and charter_ops. The rule data stays the same.

## 3. What counts as a shortfall

Per ship and per good: shortfall = due − delivered. There are three causes, treated differently:

| cause | lawful? | who records it | consequence |
|---|---|---|---|
| **Refusal** (`quota_due.due == false`, reason REFUSAL) | unlawful act of the state, already recorded by `refuse_quota` (LAW_CHARTER_DEFIANCE) | nothing more: no per-firm records | Firms deliver nothing and sell freely. Sanctions follow the refusal path (governor or expedition). |
| **Evasion** (the firm keeps or sells units it owes) | unlawful, WITHHOLD_QUOTA | Bob: `LawOps.record_greed(world, org, {"kind": "QUOTA_EVASION", "good": g, "units": n, "saving": n × (market − charter price), "district": d})` | Inspected at the next ship by `home_inspection`. If found: revealed, prosecuted in the colony (fine; class SERIOUS, repeat ladder applies), HOME_EVASION_FOUND, and sanctions become lawful. |
| **Hold full** (the home world's own ship is too small) | lawful | nothing | Carried as quota debt (Bob's `st.quota_owed`), taken first next ship, excused. |
| **Not produced / ship lost** | lawful | nothing | Carried as excused debt. |
| **Port full** (no room to store what is owed until the ship) | excused **once**; after that, a breach by the government | `record_delivery` (law) | The first port-full shortfall is excused. Every later one emits **HOME_EVASION_FOUND** with `cause: "NO_STORAGE"`, responsible GOVERNMENT (the party to the charter, which must provide public storage). That makes `evasion_proven` true, so HOME_FINE or a governor become lawful (no new rule). |
| **Debt held back while the producer had stock** (sold or used locally) for more than 2 ships | unlawful (WITHHOLD_QUOTA) | Bob: a QUOTA_EVASION record via `LawOps.record_greed`, one per org and good, updated while the debt lasts, then `greed_stop` | Found by the home inspector, as below. |

**Carry-over (Wilma, 2026-11-15).** Bob's version: what isn't delivered is carried to the next ship as debt and taken
first. During a refusal or a declaration nothing accrues and the debt's ship counter pauses. Recognition and autonomy
cancel the debt. A restored charter keeps it.

**Storage is the colony's job (user).** The hold caps each ship, and ships come about 2 years apart, so warehouses are
needed. The government answers for missing public storage. The producer answers for withholding stock it had.

**How evasion arises (Bob's conduct pass).** Each firm with a quota decides, on the greed pattern, whether to hold back
part of what it owes. The probability rises with:

- the price gap (market − charter) ÷ market;
- the firm's ethics;
- falls with the inspector's quality (`world.values` or the home-world state; default 60).

The record runs until the next ship (`greed_stop` after delivery). One record per firm per ship keeps the
violation_track small.

**Hold priority.** The quota is loaded first. A shortfall from lack of space happens only if the quota alone exceeds the
hold.

## 4. Inspection and sanctions

Nothing new is needed:

- `home_inspection` already runs at arrival over HOME-channel records.
- QUOTA_EVASION is SERIOUS, so the colony fine is SERIOUS (share of revenue, floor 2 W_ref). A repeat within 5 years
  suspends licences, and the 3rd conviction winds the firm up.
- With LAW_ENFORCE_CHARTER off, the colony declines to prosecute: revealed only. That is the colony's quiet resistance,
  but the home world sees HOME_EVASION_FOUND and may fine or appoint a governor.

## 5. With the other charter terms

- **Levy (LAW_CHARTER_EXPORT_LEVY):** applies to general exports only, never to quota units.
- **Export refusal (`export_refusal`):** unreserves goods and drops the levy. It does not stop the quota, which needs
  `refuse_quota`. The two refusals stay separate, as today.
- **Autonomy:** `is_colonial` is true, so the quota is due on the softer terms (`grant_autonomy` sets share and price).
- **Independence declared:** not due (reason INDEPENDENCE_DECLARED). Unlike refusal, firms are not violating anything,
  because the charter rules are SUSPENDED. The home world's lawful answer is the expedition (colony_defiant).
- **Independent:** rules repealed, nothing due. All goods trade freely at market prices.
- **Restored charter:** due again on the harsher terms.

## 6. The delivery fact (law side, for the chronicle and Wilma's home world)

I would add `CharterOps.record_delivery(world, report) -> fact id`, called by Bob in `on_ship` after loading:

- **HOME_QUOTA_DELIVERED** (PUBLIC, magnitude 35).
- data:
  - `goods {g: {due, delivered, short_reason}}`;
  - `paid` (charter price × units);
  - `market_value` (home price × units);
  - `burden` = market_value − paid, the real cost to the colony, for COLONIAL_BURDEN;
  - `share_pct`, `price_pct`.
- It is also kept in `sov.last_quota` for Wilma's home-world actor and burden index. The index today uses
  share × price gap only; with this it can use the real burden.
- On refusal, Bob calls it with delivered 0 and reason REFUSAL, so the chronicle shows the empty ship.

## 7. Rules and levers: what's new

- **No new lever.** Share and price exist.
- **No new rule.** WITHHOLD_QUOTA, OBSTRUCT_QUOTA, REFUSE_QUOTA and LEVY_TAX on QUOTA already cover it.
- **New charter state:** `sov.quota_goods` (list) with `home_world_designate`. Wilma picks the default list.
- **New fact:** HOME_QUOTA_DELIVERED and `sov.last_quota`.
- **New report field from Bob:** QUOTA_EVASION greed records (the kind exists).
- **Clarified meaning:** SELL_COLONIAL_GOOD applies to reserved goods only (comments only).

Everything new is read only when Bob's flag is on. With the flag off, `on_ship` stays as today and `quota_goods` is not
used.

## 8. Tests (when coded)

1. Due by share: 40% of a firm's output since the last ship goes to the home world at 35% of the home price. The rest
   exports at market price with the levy.
2. Refusal: nothing delivered, the fact says REFUSAL, no QUOTA_EVASION records.
3. Evasion: a held-back share makes a QUOTA_EVASION record. The inspection finds it: HOME_EVASION_FOUND, a SERIOUS
   colony fine, and a HOME_FINE that is now lawful.
4. Reserved and quota good: the quota first, the rest still only to the home world at the charter price.
5. Independence declared: nothing due, no records.
6. Autonomy terms: the softer share is applied.
7. Flag off: `on_ship` cargo is unchanged (deterministic).
