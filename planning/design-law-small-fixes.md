# Design note: three small law fixes (gouging, owner-operators, wildlife duty)

Anni, 2026-11-15. From the law survey (§2.1, §2.4, §2.6). Agreed by Wilma and **by Bob (2026-11-15)**:
1. Gouging: Bob's conduct pass calls MarketLaw.gouging / price_cap once a good has district prices (R8 step 2b for
   MATERIAL / MINERAL / COMPONENT, then each sector); colony price until then.
2. Owner-operators: econ_workload puts `owner_operator: true` on records of orgs whose household owns ≥ 50% (family
   firms now, any org with the share register); the law's rule exception decides.
3. Wildlife: Bob's flag **E175** (only with ECO). Fencing and watch = 3% of the site's wage bill a month (upkeep) at
   LAW_SAFETY_STANDARD ≥ STANDARD; skipped (WILDLIFE_NEGLIGENCE via record_greed) when the firm lacks cash or its CEO's
   risk ≥ 60 (family farms only when short of cash). `EconProduction.wildlife_duty_kept(world, fid)` is pure. **Terra**
   calls `JO.on_wildlife_attack(world, attack_fact_id, kept)` where PlanetProvider resolves the attack.

## 1. Price gouging under district prices (R8 §3a)

**Today** (`companies/conduct.gd`):

- GOUGING (MINOR, channel MARKET) is reported when the colony is short (buyers got less than 90% of orders) and a seller
  with stock ≥ 2 × its sales EMA asks 1.5 × the colony price.
- Under LAW_PRICE_GOUGING = IN_EMERGENCY (default) it's only unlawful in an emergency; under ALWAYS, always.

**Problem.** Under district prices, a district that can't be supplied *should* get dear (rule 1). Measured against the
colony average, honest district prices look like gouging.

**Fix: gouging is measured against the seller's own district price.** A seller gouges when both hold:

- its ask is ≥ **1.3 × its district's price** for the good;
- it holds stock to spare: cover ≥ **2 months** of its sales EMA, i.e. it could relieve the shortage it profits from.

District prices themselves are never gouging. A seller whose stock can't reach buyers (freight) isn't gouging either:
its cover counts only stock in reachable districts.

**Price control** (LAW_PRICE_CONTROL = ESSENTIALS, an emergency lever): caps essentials at **the cheapest neighbouring
district's price + freight**, not at the colony average. Selling above the cap is PRICE_GOUGE under any setting of
LAW_PRICE_GOUGING while the control is on.

**Who decides:** unchanged.

- LAW_PRICE_GOUGING is parliament's (LAW).
- LAW_PRICE_CONTROL is an emergency regulation: the **Minister of the Economy** while an emergency is declared;
  declaring the emergency is the **Cabinet's**.

**Code:** a reader in my law side, `MarketLaw.gouging(world, ask, district_price, cover_m) → bool` and
`MarketLaw.price_cap(world, good, district)`. Bob's conduct pass calls them when R8's district prices are on (his R8
flag). Nothing changes before that.

## 2. Owner-operator families outside employment law

**Today:**

- Family farms and bakeries (E160/E162) are PRIVATE orgs whose four adults are the owning household, paid by what the
  firm sells, not by wages.
- No exemption anywhere:
  - econ_workload can record OVERWORK and UNDERSTAFFING on them;
  - the work inspectorate can find it;
  - the stress tort (`_stress_torts`) can have the family sue its own firm.

**Fix:** an **owner-operator** is a worker in a firm owned (≥ 50%, under the shares note) by their own household.

- **Owner-operators are outside working-time and staffing law:** no OVERWORK, UNDERSTAFFING or stress torts for them.
  A family may work as hard as it chooses.
- **Safety law still applies.** Hazards, accidents, inspections and closures as for any plant. An unsafe farm is still
  closed, because children and neighbours are at risk too.
- **Hired workers** on a family firm (none today) are ordinary employees, with full protection.
- **Rule:** the work_rules gain an exception, `unless: [{"field": "p.owner_operator", "op": "EQ", "value": true}]` on
  EXCEED_WORKING_HOURS and UNDERSTAFF_SERVICE.
- **Bob:** `econ_workload` and the conduct pass skip recording OVERWORK and UNDERSTANDING for family orgs (or pass
  `owner_operator: true` and let the law decide; I prefer the latter, so the rule shows up in the law browser).
- My `_stress_torts` skip family orgs.

**Who decides:** parliament (the exemption is in LAW). No lever needed. If the user wants it political later:
LAW_FAMILY_WORK_EXEMPT (BOOL, default true).

## 3. The duty of care for outdoor sites, and the state under PROTECT

**Today** (ECO, opt-in): a wildlife attack kills or injures workers on a farm or mine.

- PLANET_WILDLIFE_ATTACK has no one responsible (nature).
- Politics blames the government a little (POL_WILDLIFE_OUTCRY, more under PROTECT).
- There is no legal consequence.

**Fix, two duties:**

**a. The employer's duty of care (outdoor sites: FARM, FAMFARM, MINE).**

- LAW_SAFETY_STANDARD (existing) gains a meaning for outdoor sites: at STANDARD and above, a site in a district with
  dangerous wildlife must keep **fencing and watch**, a running cost per site that Bob's plant pays.
- **Skipping it** is a greed record, kind **WILDLIFE_NEGLIGENCE** (SAFETY channel, SERIOUS; under BASIC there is no
  duty, so it's lawful).
- **An attack on a site that skipped its duty:**
  - turns the attack into an accident under the M11 chain: the attack fact gets `responsible: [{company, 0.7},
    {government, 0.3}]`;
  - the violation is revealed (the attack exposes it);
  - an ENFORCEMENT case follows;
  - the victims' families get a TORT against the company (paid to them via the victim fund, as now).
- A site that kept its duty: the attack stays nature; there is no tort against the firm.
- **Family farms:** the family is employer and victim, so no tort against itself. The fine still applies if they
  skipped the duty, because the law protects the neighbours and children too. A grant-funded family farm (E160) gets
  the fencing cost in its grant.

**b. The state under PROTECT.**

- When ECO_WILDLIFE_POLICY = PROTECT forbids culling, and a protected animal kills someone on a site that **did** keep
  its duty, the families may sue the state: a **TORT against the GOVERNMENT** (as the police tort), damages through
  `_pay` (gov_owed if the treasury is empty).
- Under MANAGE or CULL there is no state liability.
- This gives PROTECT a real legal cost, matching the political blame Wilma already has.

**Who decides:**

- LAW_SAFETY_STANDARD is parliament's (LAW, existing).
- ECO_WILDLIFE_POLICY stays where it is: it's the **Minister of the Environment's** lever, with the yearly review as a
  bill to parliament, as in gov_wildlife.
- Paying a tort is automatic (the court).

**Code:**

- **Mine:** the greed kind WILDLIFE_NEGLIGENCE; the reveal-on-attack in justice_ops; the state tort.
- **Bob's (ECO and the plants):** the fencing cost and the greed decision (skip or keep), plus a call
  `JO.on_wildlife_attack(world, attack_fact_id, site_kept_duty)` from planet_provider's attack (Terra or Bob, whoever
  owns that line), under the ECO flag.

## 4. New pieces

- **Greed kind:** WILDLIFE_NEGLIGENCE.
- **Rule exception:** owner_operator on two work rules.
- **Readers:** `MarketLaw.gouging`, `MarketLaw.price_cap`.
- **Call:** `JO.on_wildlife_attack`.
- **No new levers.** Optional later: LAW_FAMILY_WORK_EXEMPT.
