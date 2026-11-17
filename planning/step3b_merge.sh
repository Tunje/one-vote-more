#!/bin/bash
# Rebuild step 3b: takes the reviewed pieces that stack on each other, in the order their code needs. Each file is
# copied only if the shared file equals the base its owner names (line endings ignored), or is new and absent.
# Run from the repo root:  bash planning/step3b_merge.sh <step>     steps: t18 maja t19 t20 s9 t21
set -u
R=/c/Users/simon/AppData/Local/Temp/claude/2d9b615807f12236
B=$R/8f597ecd-bd09-42f4-bdfb-1882bdba4833/scratchpad
M=$R/89fe55eb-61e6-4d54-a4eb-eff1cb12e96a/scratchpad
O=$R/4fcac64a-10b6-4020-a203-7080db3d699d/scratchpad
fail=0
n() { tr -d '\r' < "$1"; }

same() { diff <(n "$1") <(n "$2") >/dev/null; }

# take <who> <new file> <shared path under game/> <base file, or "-" to compare with HEAD, or "new">
check() {
  local who="$1" new="$2" f="$3" base="$4"
  [ -f "$new" ] || { echo "MISSING ($who): $new"; fail=1; return; }
  if [ -f "game/$f" ] && same "$new" "game/$f"; then return; fi
  if [ "$base" = "new" ]; then [ -e "game/$f" ] && { echo "GUARD ($who): game/$f exists"; fail=1; }; return; fi
  if [ "$base" = "-" ]; then
    diff <(git show "HEAD:game/$f" | tr -d '\r') <(n "game/$f") >/dev/null || { echo "GUARD ($who): game/$f differs from HEAD"; fail=1; }
  else
    [ -f "$base" ] || { echo "MISSING BASE ($who): $base"; fail=1; return; }
    same "$base" "game/$f" || { echo "GUARD ($who): game/$f differs from its base"; fail=1; }
  fi
}

run() {  # who, source root, base root ("-" = HEAD), files...
  local who="$1" src="$2" base="$3"; shift 3
  for f in "$@"; do
    local b="-"; [ "$base" != "-" ] && b="$base/$f"
    check "$who" "$src/$f" "$f" "$b"
  done
  [ $fail = 0 ] || return
  for f in "$@"; do mkdir -p "game/$(dirname "$f")"; cp "$src/$f" "game/$f" && echo "$who: $f"; done
}

case "${1:-}" in
  t18) run Bob "$B/t18" "$B/t18_base" sim/economy/company.gd sim/economy/market.gd tests/economy/test_company.gd tests/economy/test_market.gd ;;
  maja) run Maja "$M/s29" "-" sim/population/households.gd sim/population/demography.gd sim/population/area_store.gd \
          sim/population/population_provider.gd tests/population/test_households_month.gd ;;
  t19) run Bob "$B/t19" "$B/t19_base" sim/economy/making.gd sim/economy/rules.gd tests/economy/test_rules.gd
       check Bob "$B/t19/sim/economy/company.gd" sim/economy/company.gd "$B/t18/sim/economy/company.gd"
       for f in building.gd test_building.gd; do
         d=sim/economy/$f; [ "$f" = test_building.gd ] && d=tests/economy/$f
         check Otto "$O/s8/game/$d" "$d" "$O/s8/snap/$f"
       done
       if [ $fail = 0 ]; then
         cp "$B/t19/sim/economy/company.gd" game/sim/economy/company.gd && echo "Bob: sim/economy/company.gd"
         cp "$O/s8/game/sim/economy/building.gd" game/sim/economy/building.gd && echo "Otto: sim/economy/building.gd"
         cp "$O/s8/game/tests/economy/test_building.gd" game/tests/economy/test_building.gd && echo "Otto: tests/economy/test_building.gd"
       fi ;;
  t20) run Bob "$B/t20" "$B/t20_base" sim/economy/company.gd sim/economy/making.gd sim/economy/rules.gd tests/economy/test_rules.gd ;;
  s9)  for f in home_builders.gd test_home_builders.gd; do
         d=sim/economy/$f; [ "$f" = test_home_builders.gd ] && d=tests/economy/$f
         check Otto "$O/s9/game/$d" "$d" "$O/s9/snap/$f"
       done
       if [ $fail = 0 ]; then
         cp "$O/s9/game/sim/economy/home_builders.gd" game/sim/economy/home_builders.gd && echo "Otto: sim/economy/home_builders.gd"
         cp "$O/s9/game/tests/economy/test_home_builders.gd" game/tests/economy/test_home_builders.gd && echo "Otto: tests/economy/test_home_builders.gd"
       fi ;;
  t21) run Bob "$B/t21" "$B/t21_base" sim/economy/rules.gd tests/economy/test_rules.gd ;;
  *) echo "usage: bash planning/step3b_merge.sh t18|maja|t19|t20|s9|t21"; exit 2 ;;
esac
echo "fail=$fail"
exit $fail
