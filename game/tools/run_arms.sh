#!/bin/bash
# Wilma: full-game arms on any machine (see planning/remote-tests.md). Resumable: finished arm/seed files are skipped.
# usage (from the repo root):  GODOT=/path/to/godot_console  bash game/tools/run_arms.sh OUT YEARS PAR "SEEDS" "name:flags" ["name:flags" ...]
#   flags: comma-separated switches, "base" for none, "-FLAG" switches a default off, "LEVER=N" forces a lever.
#   example: bash game/tools/run_arms.sh results/screen 60 8 "1 2 3" "base:base" "PLAN:E165,E165B"
# Output: OUT/ab_<name>_<seed>.txt (one "AB" line per game) and OUT/log_<name>_<seed>.txt; a sorted summary at the end.
G="${GODOT:-godot}"
OUT="$1"; YEARS="$2"; PAR="$3"; SEEDS="$4"; shift 4
HERE="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
cd "$HERE" || exit 1
# a fresh clone has no class index: without it every script fails with "Could not find type"
[ -f .godot/global_script_class_cache.cfg ] || "$G" --headless --import > "$OUT/import.log" 2>&1
i=0
for arm in "$@"; do for sd in $SEEDS; do
  name="${arm%%:*}"; flags="${arm#*:}"; f="$OUT/ab_${name}_${sd}.txt"
  [ -s "$f" ] && continue
  ( "$G" --headless --script tools/ab_full.gd -- $sd $YEARS $flags $name > "$OUT/log_${name}_${sd}.txt" 2>&1; grep "^AB" "$OUT/log_${name}_${sd}.txt" > "$f" ) &
  i=$((i+1))
  if (( i % PAR == 0 )); then wait; fi
done; done
wait
echo "DONE: $(find "$OUT" -name 'ab_*.txt' -size +0 | wc -l) games with a result, $(find "$OUT" -name 'ab_*.txt' -size 0 | wc -l) empty (see the log_ files)"
cat "$OUT"/ab_*.txt | sort | cut -c1-400
