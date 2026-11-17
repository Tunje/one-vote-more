#!/bin/bash
# Rebuild step 2: takes five reviewed pieces from their owners' scratch copies into the shared tree, each file only if
# the shared file still equals the base its owner worked from (ignoring line endings). Run from the repo root.
# Safe to run again: a file already taken is recognised and skipped.
set -u
ROOT=/c/Users/simon/AppData/Local/Temp/claude/2d9b615807f12236
TERRA=$ROOT/5c32b59e-d8dc-4d3f-9783-04e9fc000967/scratchpad/s2/game
MAJA=$ROOT/89fe55eb-61e6-4d54-a4eb-eff1cb12e96a/scratchpad/s23
ANNI=$ROOT/735336d8-bdcc-45cb-9d1f-e751a72ca3cb/scratchpad/s2/game
OTTO=$ROOT/4fcac64a-10b6-4020-a203-7080db3d699d/scratchpad/s2/game
ELLA=$ROOT/9f5f5912-6a81-4208-ac3c-2648ee2d2b1e/scratchpad/wt_s2
BASE=6eddb2f
fail=0

norm() { tr -d '\r' < "$1"; }

same_as_base() {  # path under game/: is the shared file what it was at $BASE (or absent then and now)?
  local f="game/$1"
  if git cat-file -e "$BASE:$f" 2>/dev/null; then
    [ -f "$f" ] && diff <(git show "$BASE:$f" | tr -d '\r') <(norm "$f") >/dev/null
  else
    [ ! -e "$f" ]
  fi
}

take() {  # owner source-root path
  local who="$1" src="$2" f="$3"
  if [ ! -f "$src/$f" ]; then echo "MISSING in $who's copy: $f"; fail=1; return; fi
  if [ -f "game/$f" ] && diff <(norm "$src/$f") <(norm "game/$f") >/dev/null; then echo "$who: $f (already in)"; return; fi
  if ! same_as_base "$f"; then echo "GUARD FAILED ($who): game/$f changed since $BASE"; fail=1; return; fi
  mkdir -p "game/$(dirname "$f")"
  cp "$src/$f" "game/$f"
  echo "$who: $f"
}

for f in sim/transport/site.gd sim/transport/town_grid.gd sim/transport/colony_layout.gd sim/transport/transport.gd sim/transport/road_safety.gd \
         sim/planet/planet_provider.gd sim/planet/planet_wildlife.gd sim/waste/waste_map.gd \
         ui/colony_map.gd ui/colony_vista.gd ui/planet_view.gd ui/town_view.gd \
         tests/transport/test_site.gd tests/transport/test_landfall.gd; do take Terra "$TERRA" "$f"; done
if [ -e game/sim/transport/siting.gd ]; then
  if same_as_base sim/transport/siting.gd; then git rm -q -f game/sim/transport/siting.gd 2>/dev/null; rm -f game/sim/transport/siting.gd game/sim/transport/siting.gd.uid; echo "Terra: siting.gd removed"; else echo "GUARD FAILED (Terra): siting.gd"; fail=1; fi
fi

for f in sim/population/households.gd sim/population/population_provider.gd sim/population/area_store.gd \
         tests/population/test_households.gd tests/population/test_areas.gd; do take Maja "$MAJA" "$f"; done

for f in sim/law/law_company.gd sim/law/justice_ops.gd sim/law/law_ops.gd sim/law/competition_law.gd sim/law/party_finance.gd sim/law/road_law.gd \
         sim/law/union_law.gd sim/law/work_law.gd sim/law/law_query.gd sim/law/land_law.gd sim/law/law_data.gd sim/law/road_safety_law.gd \
         sim/staff/bench.gd tests/support/staff_fixture.gd tests/law/test_law_records.gd tests/law/test_justice.gd tests/law/test_union_law.gd \
         tests/law/test_waste_law.gd tests/law/test_work_law.gd tests/law/test_crisis_law.gd tests/law/test_law_m6prep.gd tests/law/test_land_law.gd; do
  take Anni "$ANNI" "$f"
done

for f in sim/economy/home_builders.gd tests/economy/test_home_builders.gd; do take Otto "$OTTO" "$f"; done

for f in sim/economy/econ_publish.gd tests/economy/test_econ_publish.gd tests/politics/test_grant_memory.gd \
         sim/core/econ_face.gd sim/core/game_sim.gd sim/media/media_ops.gd sim/politics/gov_builder.gd \
         tests_waiting/office/test_desk_cases.gd; do take Ella "$ELLA" "$f"; done
if [ -e game/tests_waiting/politics/test_grant_cover.gd ]; then
  git rm -q -f game/tests_waiting/politics/test_grant_cover.gd 2>/dev/null; rm -f game/tests_waiting/politics/test_grant_cover.gd*; echo "Ella: test_grant_cover.gd removed"
fi
echo "fail=$fail"
