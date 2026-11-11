# Political Interface Contract (PIC): Core Schema v1

**Owner:** Wilma · **Status:** v1 draft, binding for M0 specs · **Date:** 2026-11-10
**Purpose:** Politics is the base system (DECISIONS P0). This document defines the *only* ways other subsystems talk to politics. Subsystem slices (`pic-economy.md`, `pic-staff-law.md`) must use these schemas exactly. Request schema changes from Wilma; don't fork them.

---

## 1. Granularity: who the "public" is

### 1.1 Voter cell
The political unit of the colony is the **VoterCell**: `District × Occupation × IncomeBand`.

| Dimension | Values (v1) |
|---|---|
| District | From the map (D5). Expect 6–12 in v1. |
| Occupation (9) | `INDUSTRY`, `MINING`, `AGRICULTURE` (added 2026-11-10, ~22% of workers), `SERVICES`, `PROFESSIONAL` (added 2026-11-10: managers, specialists, professionals), `PUBLIC_SECTOR`, `BUSINESS_OWNER`, `UNEMPLOYED`, `RETIRED` (project §4.2) |
| IncomeBand (3) | `LOW`, `MID`, `HIGH`. Tercile boundaries are recomputed yearly from the colony income distribution. |

The economy keeps its own household groups (District × income × skill, per X11) and publishes a **mapping** from household groups to VoterCells, with population weights. Politics never reads household groups directly.

Empty cells (population < 1) are skipped. With 10 districts that is at most 240 cells, which is cheap to simulate.

### 1.2 Actors that can be blamed or credited
`ActorRef = { kind, id }`, where kind is one of:
`GOVERNMENT` (the cabinet in office) · `PARTY` · `OFFICIAL` (Person) · `COMPANY` · `INSTITUTION` (court, regulator, school…) · `COMMANDER` (founding era) · `NATURE` (no one to blame) · `EXTERNAL` (origin civilization, imports).

---

## 2. Issues: what politics is about

### 2.1 Ideology axes (positional, −100..+100)
Parties, laws, levers and voters all hold positions on these axes. Distance between positions drives voting and coalition fit.

| Axis id | −100 | +100 |
|---|---|---|
| `ECON_ROLE` | free market | state-directed economy |
| `REDISTRIBUTION` | low taxes / low transfers | high taxes / high transfers |
| `LABOR` | employer flexibility | strong worker protection |
| `ENVIRONMENT` | development first | protection first |
| `AUTONOMY` | central control | local district autonomy |
| `FISCAL` | balanced budget / low debt | spend / borrow for growth |
| `INSTITUTIONS` | strong executive, order | strong checks, civil liberties |

### 2.2 Concerns (valence, 0..100 where 100 = fully satisfied)
These are conditions everyone wants to be good. Voters judge *performance* on them, and their salience varies per cell.

`JOBS` · `COST_OF_LIVING` · `HOUSING` · `PUBLIC_SERVICES` · `SAFETY` (workplace + public) · `ENVIRONMENT_QUALITY` · `INFRASTRUCTURE` · `FAIRNESS` (inequality + trust that rules apply equally) · `GOVERNANCE` (competence, corruption, promise-keeping)

Every indicator **must** declare which concerns it feeds (§3). An indicator that feeds no concern is not a political indicator and doesn't belong in the PIC.

---

## 3. Indicators

```
Indicator {
  id:            string        // UPPER_SNAKE, prefixed by owner: ECON_, COMP_, STAFF_, LAW_, MAP_, POL_
  owner:         "econ" | "comp" | "staff" | "law" | "map" | "pol"
  unit:          string        // "%", "credits", "index 0-100", "months"…
  range:         [min, max]
  granularity:   "COLONY" | "DISTRICT" | "VOTER_CELL"
  polarity:      +1 | -1       // +1 = higher is better for the public
  concerns:      { concernId: weight 0..1 }   // weights sum ≤ 1
  normalize:     { good: value, bad: value }  // maps raw → 0..100 satisfaction, linear and clamped
  phase:         TickPhase     // when the value is final in the month (§6)
  visibility:    "PUBLIC" | "OFFICIAL" | "HIDDEN"  // HIDDEN = ground truth for the sim only
  perceptionLag: int months    // 0 = felt immediately; e.g. 3 for "economy feels better"
  history:       true          // the kernel stores monthly values for all indicators
  exceptionOnly: bool          // optional (v1.1). If true, the indicator only counts toward its concerns while its
                               // normalized value < 100 (i.e. when something is wrong). Use for "normally fine"
                               // signals such as rule of law, so they don't dilute satisfaction at baseline.
  fiscalStress:  {good, bad}   // optional (v1.2), COLONY granularity only. Marks a public-finance health signal.
                               // Politics computes stress = max badness (0..1) over such indicators, reading CURRENT
                               // values (the government knows its books). Under stress, AI governments and all parties
                               // weight the GOVERNANCE (budget) hint of levers up to 7x and legislate monthly.
  fiscalGuard:   {floor}       // optional (v1.3), COLONY only. While the current value < floor, no actor PROPOSES a
                               // budget-worsening clause (lever GOVERNANCE hint x delta < 0). Cuts are still allowed.
                               // A soft brake that is safe against false alarms because it never forces anything.
}
```

**Rules**
- Every indicator is computed exactly once per month, in its declared phase. Politics reads it in the `POLITICS` phase and later.
- Satisfaction per concern per cell = Σ over indicators of `weight × normalized value`, renormalized by total weight. That logic belongs to politics; subsystems only declare weights.
- `OFFICIAL` indicators are visible to the government only. The opposition sees them only through oversight actions (project §13.4).

---

## 4. Facts: the shared event store

All subsystems emit Facts. Facts power blame and credit, briefings, explainability (project §20.4), history, and later media.

```
Fact {
  id:           FactId (stable)
  month:        int
  type:         string            // owner-prefixed: ECON_SHORTAGE, COMP_BANKRUPTCY, LAW_RULING, POL_LAW_PASSED…
  owner:        subsystem
  location:     DistrictId | null
  subjects:     ActorRef[]        // who it happened to / who did it
  responsible:  [{ actor: ActorRef, share: 0..1 }]   // blame/credit split; shares sum to 1
  impact:       { concernId: -100..+100 }           // signed felt effect, per affected cell
  affected:     CellSelector       // ALL | districts[] | occupations[] | explicit cells
  magnitude:    0..100             // how big a deal it is (drives salience + briefing priority)
  visibility:   "PUBLIC" | "OFFICIAL" | "SECRET"    // SECRET = true but undiscovered (law: evidence ≠ truth)
  causes:       FactId[]           // causal chain for "why did this happen?"
  data:         typed payload per type
}
```

**Rules**
- `responsible` must use the *visible* chain of responsibility. If a contractor fails on a government project, the split is something like company 0.6 / GOVERNMENT 0.4. Politics then splits GOVERNMENT blame among coalition parties by ministry ownership.
- `SECRET` facts can be promoted to `PUBLIC` later (an investigation or audit). Promotion emits a new `*_REVEALED` fact that has the original as its cause. Voters react to the reveal month, not the original.
- Facts are immutable. Corrections are new facts.
- Retention: facts with magnitude < 20 are compacted after 24 months into monthly aggregates. Higher-magnitude facts are kept forever.

---

## 5. Policy levers

A lever is any parameter politics can change. Laws are bundles of lever changes plus legal rules (a9 defines the clause → rule mapping).

```
Lever {
  id:             string           // owner-prefixed: ECON_INCOME_TAX_RATE, LAW_MINING_PERMIT_REGIME…
  owner:          subsystem
  type:           "NUMBER" | "ENUM" | "BOOL"
  range | values: …
  default:        value at game start
  legalLevel:     "CHARTER" | "LAW" | "REGULATION" | "ADMIN"   // minimum authority required to change it
  foundingEra:    "COMMANDER" | "LOCKED"   // can the commander change it before parliament?
  ideology:       { axisId: slope }        // position implied per unit of change; e.g. +1% income tax → REDISTRIBUTION +4
  fiscal:         estimator ref            // owner provides a function: lever value → est. monthly budget delta
  implementation: TaskDefinitionId | null  // staff task required for the change to take effect (a9)
  lag:            int months               // delay after implementation before the effect starts
  scope:          "COLONY" | "DISTRICT"    // district-scoped levers have one value per district
  concerns:       {concern: effect per full range}   // AI hint: expected relief (spec-politics §6). GOVERNANCE = budget-sign proxy
  concernsHigh:   {from: value, concerns: {...}}     // optional (v1.4): EXTRA effects for the part of a change above
                                                     // `from` (non-linear harm, e.g. taxes above 35% choke jobs)
  concernsLow:    {from: value, concerns: {...}}     // optional (v1.4): same for the part BELOW `from` (cuts too deep)
}
```

**Rules**
- **Law is the single writer of operative lever values** (ruled 2026-11-10, DECISIONS A8). `world.levers` holds *operative* values only. Law keeps legal/pending values in its `lever_change` table and applies due changes in `DECISIONS`. Every other subsystem only reads `world.levers`. Before M6 law exists, the same pipeline runs in law's thin v1 module (M3/M4), so nobody else writes `world.levers` after `define_lever`.
- Changing a lever *never* takes effect directly. It goes Decision → (legal check) → (implementation task) → lag → effect, and it emits `POL_LEVER_CHANGED` and later `*_LEVER_EFFECTIVE` facts.
- Lever `ideology` slopes are how the player's founding decisions build the party's identity (project §8.1): every changed lever moves the commander's revealed ideology.
- Party AI evaluates laws as the sum of their lever changes on ideology axes, plus predicted concern effects (from owner-provided estimators), plus coalition commitments.

---

## 6. Actions

```
Action {
  id:            string            // ECON_COMMISSION_PROJECT, STAFF_ASSIGN, LAW_FILE_APPEAL, POL_PROPOSE_BILL…
  owner:         subsystem
  actors:        ["PLAYER_GOV", "AI_GOV", "PARTY", "OPPOSITION", "COMMANDER"]   // who may take it
  cost:          { credits?, staffTask?: TaskDefinitionId, partyTrust?: int }
  legalAction:   LegalActionType   // a9's action taxonomy; validated by the rules engine
  preconditions: predicate refs
  effects:       lever changes | entity changes | facts emitted
  aiHints:       { utilityFeatures… }   // features the AI government/party utility can read
}
```

**Rule:** player and AI use the *same* actions (project §18.3). No player-only shortcuts.

---

## 7. Master tick (preview of D2)

| # | Phase (`TickPhase`) | Owner | Notes |
|---|---|---|---|
| 1 | `DECISIONS` | pol | Apply queued player/AI actions; legal validation (law) |
| 2 | `STAFF` | staff | Work progress, implementations complete → levers become effective |
| 3 | `TRADE` | econ | Logistics, shipments arrive, imports |
| 4 | `PRODUCTION` | econ/comp | Labor allocation, production, construction progress |
| 5 | `SETTLEMENT` | econ | Wages, sales, taxes, ledger; insolvency checks |
| 6 | `COMPANY_AI` | comp | Firm decisions for next month |
| 7 | `JUSTICE` | law | Incidents, inspections, cases, rulings (M6+) |
| 8 | `SOCIAL` | econ/map | Households, housing, migration, pollution → **indicators final** |
| 9 | `POLITICS` | pol | Perception, satisfaction, opinion, parties, polls, parliament, AI gov planning |
| 10 | `EVENTS` | pol/all | Condition-triggered events |
| 11 | `RECORD` | kernel | History, fact compaction, briefing generation |

Indicators may be finalized in any phase ≤ 8. Politics reads only finalized values, so there is no double-counting.

---

## 8. GDScript shape (for M1)

```gdscript
# game/sim/core/pic_provider.gd. Every subsystem extends this.
class_name PicProvider extends RefCounted
func indicator_defs() -> Array[Dictionary]: return []   # §3 schema
func lever_defs() -> Array[Dictionary]: return []       # §5 schema
func action_defs() -> Array[Dictionary]: return []      # §6 schema
func phases() -> Array[int]: return []                  # TickPhase values this provider runs in
func run_phase(phase: int, world: WorldState) -> void: pass   # write indicators/facts via world
```
Indicators, levers and actions are **data-defined** (JSON in `game/data/pic/`), with code only for compute functions and estimators. In M2, `StubWorldProvider` implements `IPicProvider` with scripted values so politics runs before any real subsystem exists.

---

## 9. What each slice must deliver
For each indicator, fact type, lever and action, fill the fields above as a table row. Minimum v1 coverage:
- **econ/comp:** every concern except `GOVERNANCE` must have at least one econ indicator; tax, budget-line, minimum-wage, subsidy and procurement-rule levers; commission/cancel project, set budget and choose contractor actions.
- **staff/law:** `GOVERNANCE`, `FAIRNESS` and `SAFETY` contributions; implementation tasks for every lever type; legal levels for every lever; drafting/negotiation/campaign/oversight tasks; permit/licence levers.
