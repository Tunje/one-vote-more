#!/usr/bin/env bash
# Run the headless test suite. Usage: tools/test.sh   (from anywhere)
# A GDScript runtime error aborts the runner before quit(), so we enforce a timeout and
# require the "N passed, 0 failed" summary line.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/simon/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
LOG="$(mktemp)"
timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1   # always: registers new class_names
timeout "${TEST_TIMEOUT:-1500}" "$GODOT" --headless --path . --script res://tests/run_tests.gd >"$LOG" 2>&1
code=$?
grep -E '^\s+(PASS|FAIL)|^\s+- |passed, .* failed|SCRIPT ERROR|Parse Error|   at: (res://|GDScript::reload)' "$LOG"
if [ $code -eq 124 ]; then echo "!! TIMEOUT / runner crashed (see errors above)"; exit 2; fi
if grep -q "SCRIPT ERROR" "$LOG"; then echo "!! SCRIPT ERRORS (runtime errors do not fail a test by themselves)"; exit 1; fi
grep -qE '^[0-9]+ passed, 0 failed' "$LOG" || { echo "!! TESTS FAILED"; exit 1; }
echo "OK"
