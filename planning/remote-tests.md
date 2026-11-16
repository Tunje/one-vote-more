# Tests for the second machine

Notes from Wilma for whoever runs tests from the GitHub copy of this repo (the user's work PC, set up 2026-11-16).
Each job below is self-contained. Do the jobs marked OPEN, top to bottom. Do not change game code; only run and report.

## Setup (once per clone)

- Godot 4.7.2 stable, the console build. Set `GODOT` to its path, or have `godot` on the PATH.
- The repo root holds `game/` (the Godot project) and `planning/` (docs).
- A fresh clone has no class index. `run_arms.sh` builds it on first use; by hand:
  `cd game && $GODOT --headless --import`
  Without it every script fails with "Could not find type WorldState".
- Use Git Bash on Windows.

## The commands

- **One unit test file:** `$GODOT --headless --path game --script res://tools/run_one.gd -- res://tests/economy/test_money.gd`
  It passed if the output has `failed: 0`.
- **The whole suite (about an hour):** `TEST_TIMEOUT=12000 bash game/tools/test.sh`
  The last lines give `N passed, M failed`.
- **Full games with switches on or off:**
  `bash game/tools/run_arms.sh OUT YEARS PAR "SEEDS" "name:flags" ...`
  - `flags`: comma-separated switches; `base` for none; `-FLAG` switches a default off; `LEVER=N` forces a lever.
  - `PAR`: games at once; one game uses one core.
  - Each game writes one line starting `AB` to `OUT/ab_<name>_<seed>.txt`. A 60-year game takes roughly 30-60 minutes.
  - It is resumable: run the same command again and finished games are skipped.

## Reading an AB line

`adults` at the end; `u` unemployment %, `food` shortfall per thousand and `real` wage are means from year 5 to the
end; `priv alive / dead` private firms; `builders alive/dead`; `blddead nowork / loss / other` why builders died;
`bankcap` bank capital in millions at the end (0 or below: the bank has failed); `money` all colony money in millions;
`treas%` the treasury's share of it; `ledger` must be 0.

## How to report

Put results under `results/<job id>/` in the repo: the `ab_*.txt` files (not the logs, unless a game gave no AB line;
then include that log). Add `results/<job id>/NOTES.md` with: the commit tested (`git rev-parse --short HEAD`), the
exact command, how long it took, and anything that failed. Commit and push on a branch named `results/<job id>`;
do not push to main. Then set the job's status below to DONE in the same branch.

## Jobs

### J1: the suite on a clean clone: OPEN
Run the whole suite on the newest main. Report the last 30 lines of output.
Why: every suite run on the first machine has shared it with other work.

### J2: the base, 10 seeds x 60 years: OPEN
`bash game/tools/run_arms.sh results/J2 60 <PAR> "1 2 3 4 5 6 7 8 9 10" "base:base"`
Why: the first machine has only seeds 1-3 at 60 years; every later comparison needs this base.

### J3: the "new way" for builders, 10 seeds x 60 years: OPEN
`bash game/tools/run_arms.sh results/J3 60 <PAR> "1 2 3 4 5 6 7 8 9 10" "PLAN:E165,E165B" "PLANQ:E165,E165B,E165Q" "R8BLD:R8_BUILDERS" "NEWWAY:E165,E165B,E165Q,R8_BUILDERS" "E155BLD:E155BLD"`
Why: builders are a third of private firm deaths (42-57 per game, 1-2 survive); these switches were built for that
and are off (planning/reeval-off-switches.md, planning/reeval-otto.md).

### J4: the money switches now that food supply has changed, 10 seeds x 60 years: OPEN
`bash game/tools/run_arms.sh results/J4 60 <PAR> "1 2 3 4 5 6 7 8 9 10" "E151:E151" "E152:E152" "E153:E153" "E154:E154" "E155:E155" "MONEY5:E151,E152,E153,E154,E155" "E139:E139" "E156:E156"`
Why: they were switched off because they "starve the colony until supply responds"; food works differently now.

More jobs follow when the first machine's 3-seed screen has shown which switches deserve 10 seeds, and when the
bank build is merged (switches BANK_RISK, BANK_SEC, BANK_DEP, BANK_CAP, BANK_EQUITY; not in main yet).
