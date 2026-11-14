#!/bin/bash
# Bob: runs the v9 on-list check, 5 seeds per arm, N parallel. Output: $OUT/v9_<arm>_<seed>.txt
G="/c/Users/simon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
OUT="$1"; YEARS="$2"; PAR="$3"
ARMS=("base:base" "fleet:SUPPORT_T,FLEET" "care:CARE" "comfort:SUPPORT_S" "private:E136,E137,E138" "warehouse:WAREHOUSE" "police:POLICE" "prisons:POLICE,PRISONS" "m2:M2")
jobs=()
for arm in "${ARMS[@]}"; do for sd in 1 2 3 4 5; do jobs+=("${arm%%:*} ${arm#*:} $sd"); done; done
i=0
for j in "${jobs[@]}"; do
  set -- $j
  ( "$G" --headless --script tools/v9_check.gd -- $3 $YEARS $2 $1 2>&1 | grep "^V9" > "$OUT/v9_$1_$3.txt" ) &
  i=$((i+1))
  if (( i % PAR == 0 )); then wait; fi
done
wait
cat "$OUT"/v9_*.txt
