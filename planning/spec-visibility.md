# Information Access Model (Visibility) v1

**Owner:** a9 (in `sim/law/` until Wilma moves it to core) · **Date:** 2026-11-10 · **Answers:** project §13.4, ui-staff-law §6
**Code:** `game/sim/law/visibility.gd` (Vis) · **Tests:** `game/tests/law/test_visibility.gd` · **Status:** built, suite green (76/76)

## 1. Viewers and roles

A **viewer** is a party: `{"party_id": pid}`, meaning that party's leader and staff. The player always views as their own party.
`{}` means the **simulation itself**: omniscient. It is used by AI internals, tests and debug tools, and is the default for every query, so existing callers are unchanged.

A party's **role at a month** comes from `world.table("gov_term")`, which law updates from `pol.state.government` each DECISIONS phase:

| Role | Who |
|---|---|
| `GOVERNING` | Members of the cabinet. In the commander era (before the first government), the player's party. |
| `SUPPORT` | Confidence-and-supply partners (`government.support`) |
| `OPPOSITION` | Everyone else, with or without seats |

- `Vis.role(world, pid, month = now)` gives the role at any month. Terms are recorded with `from_month = formed_month`, so the history is exact.
- A caretaker period counts as the outgoing term until the new cabinet forms.

## 2. Facts

| Visibility | Who sees it |
|---|---|
| `PUBLIC` | Everyone |
| `OFFICIAL` | (1) the **current government**: it inherits the files through civil-service continuity. (2) Parties that **were governing when it happened**. (3) A party the fact is **about** (PARTY subject or responsible actor, e.g. its own poll). (4) **Grants** (§4). **Support parties do not** see OFFICIAL facts. |
| `SECRET` | Only those who did it: (1) parties governing when a GOVERNMENT/COMMANDER/AUTHORITY-responsible secret was created, or (2) a party that is itself responsible. **A later government does not inherit a predecessor's secrets**, and grants never open SECRET facts. Everyone else learns of it only through the `*_REVEALED` fact, which is PUBLIC. |

`Vis.can_see_fact(world, viewer, fact)` and `Vis.filter_facts(world, viewer, facts)` implement this. The UI feed is `LQ.fact_feed(world, viewer, from_month, type_prefix, limit)`.

## 3. Indicators

| Visibility | Who sees it |
|---|---|
| `PUBLIC` | Everyone |
| `OFFICIAL` | Current government, **support parties** (they need budget-level information to support), and parties with an active indicator grant (§4) |
| `HIDDEN` | The simulation only (ground truth) |

`Vis.can_see_indicator(world, viewer, id)`. The UI reads values through `LQ.indicator(world, viewer, id, key)`, which returns `null` when the value is hidden.

## 4. Grants: how the opposition learns things

Grants live in `world.table("access_grant")` and are per party.

| Source | Grant |
|---|---|
| **Oversight inquiry** (`STAFF_T_OVERSIGHT` completed by a party, `params.domain_prefixes`, e.g. `["LAW_", "ECON_"]`) | Two grants. (1) `FACT_PREFIX`: OFFICIAL facts in those domains from the **last 24 months up to the inquiry**. These stay known for good; later facts are not covered. (2) `INDICATOR_PREFIX`: OFFICIAL indicators in those domains for **6 months**. The inquiry also reveals SECRET facts in the domain with p = 0.3 + 0.5·Q (spec-staff §3), which is how secrets become PUBLIC. |
| **Court case** (a party is claimant or respondent) | `FACT_IDS`: the case file (`unlawful_fact`, `violation`, `fact`). Cases about unlawful acts are filed after the reveal, so in practice this covers OFFICIAL material. SECRET stays closed (§2). |

`LQ.access(world, pid)` gives `{role, grants[]}` for the UI's "what can I see" panel. Grants are created by `Vis.add_grant` / `Vis.grant_oversight`, which staff and justice call. The UI never calls them.

## 5. Query tables (staff/law UI)

Every SQ/LQ query takes `viewer` as its last argument (default `{}` = simulation):

| Data | Visible to |
|---|---|
| Government staff internals: roster details, tasks, positions, candidates, briefing, decisions (`SQ.roster/summary/tasks/task_view/open_positions/candidates/briefing/decision_requests` with owner GOVERNMENT) | `GOVERNING` only. Others get `[]` / `{}`. |
| A party's own staff (owner PARTY:pid) | That party only |
| Person profiles (`SQ.person_view`) | Full profile to whoever sees the person's pool. Everyone else gets a public CV: `{name, age, party, category, specialization, status, public_only: true}`. |
| Government seats (`SQ.seats`): who the ministers are | Public |
| Law register, constitution, lever catalogue (legal/operative values), court cases (`LQ.cases`: no truth or evidence ever), courts, permits | Public. Laws and court registers are public. |
| Enactments (`LQ.enactments`) | Status public. `implementation` detail is GOVERNING only. The `unlawful` mark shows only once revealed, or to those who may see the SECRET fact. |
| Drafting status (`LQ.drafting_status`) | The drafting task's owner (government or party) |
| Decree check (`LQ.decree_check`) | GOVERNING only |

## 6. Not covered yet / for Wilma
- Politics-owned tables (polls, bills, coalition talks) need the same rule set: party polls are OFFICIAL with a PARTY subject (owner only), bills are public once proposed, and negotiation content stays private to the parties involved. `Vis` is generic enough to reuse; move it to `sim/core` if you adopt it.
- The voter model reads **ground truth for PUBLIC facts only** and does not need a viewer. AI parties should use their own viewer for fair play: an AI opposition shouldn't plan on secrets.
- Media (post-v1) will become a third grant source (investigative journalism).
