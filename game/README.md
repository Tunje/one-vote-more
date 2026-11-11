# Political Colony Simulator: game project

Godot 4.7.2 (standard build), GDScript only (DECISIONS A1r/A2b).

## Run tests
```bash
bash tools/test.sh          # headless; exit 0 = all green
```
Set `GODOT=/path/to/Godot_console.exe` if Godot isn't at the default Downloads path.

## Layout
```
sim/core/        kernel (Wilma): TickPhase, WorldState, Simulation, RngStreams, Ledger, FactStore, IndicatorStore, PicProvider, SaveIO
sim/politics/    political core (Wilma), M2
sim/staff/       staff (agent a9), M3
sim/law/         law (agent a9), M6
sim/economy/     economy (agent 88), M4
sim/companies/   companies (agent 88), M4
data/pic/        indicator / lever / action definitions (data, not code)
tests/<area>/    test_*.gd files extending TestCase; methods named test_*
tools/           test.sh, soak runner
ui/              Godot scenes, M5+ (the sim must never depend on ui/)
```

## Rules for all sim code (non-negotiable)
1. **Sim code is pure `RefCounted`.** No Node, scene tree or engine singletons except FileAccess/DirAccess in SaveIO.
2. **Providers are stateless.** Every subsystem extends `PicProvider`. All state lives in `WorldState`: `world.table("<kind>")` for entities, `world.levers`, `world.ledger`, `world.facts`, `world.indicators`. If it's not in WorldState, it's not saved.
3. **Integers only in state.** Money and quantities are milli-units (`Ledger.SCALE = 1000`). Floats are allowed in temporary math, but round before storing.
4. **Randomness only through `world.rng.stream("<owner>.<purpose>")`.** Never use `randi()`/`randf()` globals.
5. **Iterate deterministically.** Dictionary order is insertion order; never iterate anything whose order depends on hashing or time.
6. **Money only moves via `ledger.transfer`.** Only `Ledger.EXTERNAL` may create money. The total must be 0 every month (checked in RECORD).
7. **Indicators** are written once per month, in their declared phase, by their owner (`world.set_indicator`). **Facts** are immutable (`world.add_fact`).
8. **Levers never change directly:** decision → legal check → implementation task → lag → effect (pic-core §5).
9. **Ids** come from `world.new_id("<kind>")` and are never reused.
10. **Read-only code (UI, queries, reports) uses `world.peek(kind)`, never `world.table(kind)`**, which creates missing tables and changes the save hash.
11. **Tests never share files across processes:** use `save_path("name.sav")` from TestCase (per process id). user:// is shared by every concurrent run.
12. Every new system ships with tests, including a determinism test and a save/load round-trip test.

Spec references: `../planning/pic-core.md` (interface contract), `../planning/MASTER-PLAN.md` (workplan), `../planning/DECISIONS.md` (rulings).
