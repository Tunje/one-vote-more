#!/bin/bash
# Rebuild step 3: takes one reviewed piece from its owner's scratch copy into the shared tree. Each file is copied
# only if the shared file still equals what it was at the owner's base commit (ignoring line endings), or, for a new
# file, does not exist yet. Run from the repo root:  bash planning/step3_merge.sh <who>
# Safe to run again: a file already taken is recognised and skipped.
set -u
ROOT=/c/Users/simon/AppData/Local/Temp/claude/2d9b615807f12236
fail=0

norm() { tr -d '\r' < "$1"; }

take() {  # who, source root (holding sim/ and tests/), base commit, file under game/
  local who="$1" src="$2" base="$3" f="$4"
  if [ ! -f "$src/$f" ]; then echo "MISSING in $who's copy: $f"; fail=1; return; fi
  if [ -f "game/$f" ] && diff <(norm "$src/$f") <(norm "game/$f") >/dev/null; then echo "$who: $f (already in)"; return; fi
  if git cat-file -e "$base:game/$f" 2>/dev/null; then
    if ! { [ -f "game/$f" ] && diff <(git show "$base:game/$f" | tr -d '\r') <(norm "game/$f") >/dev/null; }; then
      echo "GUARD FAILED ($who): game/$f changed since $base"; fail=1; return
    fi
  elif [ -e "game/$f" ]; then
    echo "GUARD FAILED ($who): game/$f is new in $who's copy but exists in the tree"; fail=1; return
  fi
  mkdir -p "game/$(dirname "$f")"
  cp "$src/$f" "game/$f"
  echo "$who: $f"
}

case "${1:-}" in
  anni)
    S=$ROOT/735336d8-bdcc-45cb-9d1f-e751a72ca3cb/scratchpad/s3/game
    for f in sim/law/law_data.gd sim/law/land_law.gd sim/law/law_company.gd sim/law/law_provider.gd sim/law/law_ops.gd \
             sim/law/justice_ops.gd sim/law/party_finance.gd sim/staff/staff_ops.gd \
             tests/law/test_land_sale.gd tests/law/test_land_law.gd tests/law/test_law_records.gd; do take Anni "$S" ac6947e "$f"; done ;;
  terra)
    S=$ROOT/5c32b59e-d8dc-4d3f-9783-04e9fc000967/scratchpad/s3/game
    for f in sim/transport/site.gd tests/transport/test_site_land_yield.gd; do take Terra "$S" ac6947e "$f"; done ;;
  bob2)
    S=$ROOT/8f597ecd-bd09-42f4-bdfb-1882bdba4833/scratchpad/t11/game
    for f in sim/economy/making.gd sim/economy/rules.gd tests/economy/test_rules.gd; do take Bob "$S" ee52c74 "$f"; done ;;
  ella)
    S=$ROOT/9f5f5912-6a81-4208-ac3c-2648ee2d2b1e/scratchpad/wt_s3
    for f in sim/economy/grants.gd tests/economy/test_grants.gd sim/core/econ_face.gd sim/economy/econ_publish.gd \
             sim/politics/gov_builder.gd sim/politics/legislature.gd tests/politics/test_grant_memory.gd; do take Ella "$S" ac6947e "$f"; done ;;
  *) echo "usage: bash planning/step3_merge.sh anni|terra|bob2|ella"; exit 2 ;;
esac
echo "fail=$fail"
exit $fail
