# M11 crises: economy side (88) — working notes

Spec: `spec-events-v1.md` (A33). Decisions from Wilma, 2026-11-11:

- **A. Survivability gate (hazards on):**
  - ≥ 4/6 seeds OK;
  - at most 1 famine across 6 seeds — a balance target, never a cap in code (if balancing yields 2, bring the traces);
  - conservation passes;
  - the guard test shows famine is reachable.
  - Item G stays as the gate with hazards off.
- **B. Guard test, "mismanaged colony":**
  - ECON_BUDGET_RESERVE_PURCHASES 0 and the reserve emptied;
  - ECON_FOOD_ASSISTANCE 0;
  - imports banned (a9's ban lever, or ECON_IMPORT_TARIFF 50);
  - ECON_BUDGET_INFRASTRUCTURE 0;
  - ECON_IMMIGRATION_QUOTA 120;
  - hazards on.
  - Origin food aid (E61) arrives only on a supply ship, so the ship hazard applies to it, and it is capped.
- **C.** Violations go through a9's API (below). No new table.
- **D. Order:**
  1. S2 leftovers (Gini and deprivation indicators, PD tests 4 and 5, J26 named headcount, docs) and the seed-2 unemployment look;
  2. then M11 steps 1 → 4: hazard engine, greed, preparation, facts.
  - The tree is frozen until Wilma releases it.

## a9 interface (approved)

1. **Recording a greedy choice:** `LawOps.record_violation(world, company_actor, ACTION, params)`, called at the moment of the choice. It creates a SECRET `LAW_VIOLATION` plus a `violation_track` row.

   | ACTION | params |
   |---|---|
   | `DEFER_SAFETY_UPKEEP` | `{facility, months}` |
   | `DISCHARGE_WASTE` | `{facility, district, amount}` |
   | `PRICE_GOUGE` | `{good, price, ref_price}` |
   | `EXPORT_IN_SHORTAGE` | `{good, qty}` |
   | `CARTEL` | `{members, good}` |
   | `CUT_CONTRACT_CORNERS` | `{project}` |

2. **Crisis facts** carry:
   - `data.cause_violations` = [LAW_VIOLATION ids];
   - `data.damages` {deaths, injuries, cleanup, lost property} in milli;
   - the `exposure` block.

   What follows:
   - Magnitude ≥ 50 opens a post-crisis inquiry.
   - A revealed cause emits `LAW_CRISIS_CAUSE_REVEALED` and leads to prosecution and a TORT case.
   - Compensation goes to the exposed pools; a9 will ask for a helper.
3. **Deterrence:** `LQ.expected_sanction(world, action, org)` returns `{p_detect_month, expected_fine, horizon}`. Greed decisions use the same odds the law uses.
4. **Emergency levers (88 implements the market effects):**
   - `LAW_RATIONING`: NONE / FOOD / FOOD_FUEL;
   - `LAW_PRICE_CONTROL`: ESSENTIALS, cap = pre-crisis price + X%;
   - `LAW_FOOD_EXPORT_BAN`;
   - `LAW_REQUISITION`.

   On `LAW_MANAGER_CONVICTED`: replace the CEO (`COMP_CEO_REPLACED`) and reroll greed.

a9's decision rows are J27 onward.
