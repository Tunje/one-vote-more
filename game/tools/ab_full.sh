#!/bin/bash
# Bob: full-game A/B over 5 seeds per arm, PAR parallel. usage: OUT YEARS PAR "name:flags" ["name:flags" ...]
# (flags comma-separated, "base" for none, "-FLAG" removes a default). Output: $OUT/ab_<arm>_<seed>.txt, then a summary.
G="/c/Users/simon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
OUT="$1"; YEARS="$2"; PAR="$3"; shift 3
mkdir -p "$OUT"
jobs=()
for arm in "$@"; do for sd in ${SEEDS:-1 2 3 4 5}; do jobs+=("${arm%%:*} ${arm#*:} $sd"); done; done
i=0
for j in "${jobs[@]}"; do
  set -- $j
  ( "$G" --headless --script tools/ab_full.gd -- $3 $YEARS $2 $1 2>&1 | grep "^AB" > "$OUT/ab_$1_$3.txt" ) &
  i=$((i+1))
  if (( i % PAR == 0 )); then wait; fi
done
wait
cat "$OUT"/ab_*.txt | sort
