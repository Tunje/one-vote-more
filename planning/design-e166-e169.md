# E166 (rescues) and E169 (half-built buildings): design

Designed by Bob in messages to Wilma (agreed by Wilma). Moved into planning/ by Otto (2026-11-15), who now owns both.
Both come after R8 step 4 (builders) and sit under Anni's one sale mechanism (planning/design-law-company-sales.md,
E174).

## E169: half-built buildings

**User (via Wilma):** "half-built buildings should be able to be repurposed to a new company."

### Design (Bob, agreed by Wilma; government projects included)

**Becoming unfinished:**
- When a plan is withdrawn (no_reason, limit, no_rescue) or a build stalls for good, a project with work done isn't
  cancelled. It becomes **UNFINISHED**, keeping its type, district, work done and book value (what was paid to the
  builder).

**The holder:**
- the bank, if it wrote off a loan on the plan (up to the write-off);
- otherwise the founder household.
- Unsold after 60 months, it decays and is finally written off.

**Same use:**
- A founder of the same type takes it over for 60% of book, paid to the holder; the bank books a recovery.
- All work done counts. A new project is tendered only for the remaining work, material and components.

**Repurposed:**
- Another type, same district, for 30% of book.
- Half the work done counts (walls and site, not equipment), capped at half the new plant's work.

**Founders check first:**
- FirmAI._entry, family founding and the government's public projects look for a same-type unfinished building in
  their district, then in any district, then for one to repurpose if that saves at least 3 months of work.
- A government taking over a half-built clinic is fine.

**Report:** unfinished buildings on the market; taken over (same use / repurposed); months saved; bank recoveries;
decayed unsold.

### Implementation (Otto, flag E169, opt-in)

**When a building becomes unfinished:** a project for a new plant (any type in EconData.BUILD except ROAD; not
expansions, upgrades, renovations or road links) with at least one work unit done, when it is ended by:
1. **EconInsolvency.abandon_plan** (any cause).
   - Holder: the bank up to the loan it wrote off, the rest to the founder household (or the treasury if none).
   - The cancelled job also leaves the builder's book. Today it stays in `contracts`, which inflates `committed()`.
2. **The builder walking off an unpaid private contract** (E76, EconConstruction.settle_payments).
   - Holder: the owner firm.
3. **ECON_CANCEL_PROJECT** (the government cancels a public job).
   - Holder: the treasury.

**Table:** `world.table("unfinished")[uid] = {type, district, wu_done, wu_total, mat_total, comp_total, min_months,
book, holder_bank_cap, holder_rest (account), since}`.

**Taking over:**
- **Where it happens:** in EconConstruction.create, so every caller is covered at once: founders, families, developers,
  the government and firms' own builds.
- **What a new plant project looks for:**
  1. the same type and the same size in its own district. All work done counts, at 60% of book.
  2. otherwise, another type in its own district, if half the work done (capped at half the new plant's work) is
     worth at least 3 months of a standard builder crew. That half counts, at 30% of book.
- **Payment:** the owner pays the holder before tendering.
  - A plan may draw its plan credit (E165b) to pay.
  - The government pays from the project's budget line.
  - If the owner can't pay, there's no takeover.
- **The tender:** it covers only the remaining work, material, components and pace (as fail_contracts re-tenders).
- **The plant's book** is the new contract price plus the price paid for the shell.

**Decay:** unsold after 60 months, it's deleted and counted as decayed.

**Facts:**
- ECON_UNFINISHED_LEFT (a half-built building left behind);
- ECON_UNFINISHED_TAKEN (taken over: same use or repurposed; with the price and the holder).

**Deviation from Bob's design (first version):** takeovers look only in the project's own district. Taking a building
in another district would move the founder's chosen district and HQ, which every caller would need to agree to. That
can come later if the A/B shows buildings left unsold elsewhere.

**Stats:** st["e169_stats"] = {left, taken_same, taken_repurpose, months_saved, bank_recovered, paid_rest, decayed}.

## E166: rescues

**User (via Wilma):** "if a company in the planning stage is about to die it should be able to sell shares of itself to
save it, or if it's a company necessary for the colony the government could give a bailout, and banks give extensions
for first payments or buy part of the company." Later: "one of the big things was companies dying and not becoming big
enough to have people hire."

### Part 1: plans in trouble (the E166 scope agreed by Wilma)

**Trigger:**
- a plan whose build is ACTIVE with unpaid_m ≥ 1; or
- a plan whose cash + plan credit is below what's left to pay (price − paid).
- Shortfall = that gap.
- No rescue for plans dropped for want of a builder: money doesn't make a builder appear.

**The window:** RESCUE_M = 4 months. The steps are tried in this order, and each is the other side's choice:

1. **Shares:** a stake for the money.
   - Buyers: profitable firms with free cash > 6 months of their costs (same output good first), then I3–I5
     household pools with spare savings.
   - Only where the plant's good sells at ≥ 1.2 × unit cost.
   - Stake = money ÷ (value built + cash + money).
   - Outside stakes are ≤ 490‰ in total, so the founder stays the majority owner.
2. **The bank:**
   - interest-only first payments for 12 months after opening;
   - a top-up loan of the shortfall, if its room and the E152 capital floor allow;
   - plus a debt-for-equity swap of up to 30% of the existing loan into a bank stake.
3. **The government:**
   - only for a plant the colony needs (strategic types, or a good E157 shows short), and only after shares and the
     bank were tried;
   - it acts through **ECON_RESCUE_PLAN {org, form GRANT | LOAN | STAKE, amount}**;
   - Wilma writes the chooser (form by ideology) against a pure query **in_trouble(world) → [{org, type, district,
     shortfall, needed, months_left, offers_tried}]**;
   - a bailout is the public fact ECON_PLAN_BAILOUT.

**No rescue in the window:** E165's abandon_plan with cause "no_rescue". With E169, the half-built work becomes
UNFINISHED.

### Part 2: young opened firms (a separate, later flag; Wilma)

A firm in its first 36 months after opening that enters distress gets the same window before administration. Older
firms keep today's path.

### Since then

- Anni's shares note (planning/design-law-shares.md) replaces Bob's "owners" dict with **o.shares** (founder
  included).
- §3b (selling a plant) comes **first** in a cash-short firm's rescue order: plant sale → stake → bank → state.
- **Draft code** (Bob, unwired, never imported or tested): his scratchpad gres/sim/companies/econ_plan_rescue.gd. It
  predates Anni's notes.
- **Not coded yet** (Otto's now, with the creditor order E174): EconCredit.owed_by, o.shares, o["wage_arrears"].

**A/B asked for:** rescues by kind; saved plans alive at 12 and 36 months; bank stakes and write-offs avoided; public
money spent and recovered.
