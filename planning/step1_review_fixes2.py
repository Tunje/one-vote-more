"""Rebuild step 1: fixes from Bob's review of the doorway, and one fix of a fix.
usage: python planning/step1_review_fixes2.py (repo root, once)"""
import io
import re


def patch(p, pairs=(), regex=()):
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    s = s.replace("\r\n", "\n")
    for a, b in pairs:
        if a not in s:
            raise SystemExit("%s: missing %r" % (p, a[:60]))
        s = s.replace(a, b)
    for pat, b in regex:
        s, k = re.subn(pat, lambda m: b, s, flags=re.S)
        if k != 1:
            raise SystemExit("%s: %d matches for %s" % (p, k, pat[:50]))
    io.open(p, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)


# the shared state: where an economy's own state exists (table "econ", key "s") that is the one; else the kept stand-in
patch("game/sim/core/core_util.gd", regex=[
    (r"static func peek_st\(world: WorldState\) -> Dictionary:\n\treturn world\.peek\(\"econ_wait\"\)\.get\(\"s\", \{\}\)\n",
     'static func peek_st(world: WorldState) -> Dictionary:\n\tif world.peek("econ").has("s"):\n\t\treturn world.peek("econ")["s"]   # an economy\'s own state, once one exists (tests also set it)\n\treturn world.peek("econ_wait").get("s", {})\n'),
    (r"static func st\(world: WorldState\) -> Dictionary:\n\tvar t := world\.table\(\"econ_wait\"\)\n",
     'static func st(world: WorldState) -> Dictionary:\n\tif world.peek("econ").has("s"):\n\t\treturn world.table("econ")["s"]\n\tvar t := world.table("econ_wait")\n'),
])

# Bob: three answers that were values of the old game, not plain answers; one wrong shape
patch("game/sim/core/econ_face.gd", [
    ("const ACTIONS_LINE_OF := {}  # old EconActions.LINE_OF",
     'const ACTIONS_LINE_OF := {"HOUSING": "ECON_BUDGET_HOUSING"}  # old EconActions.LINE_OF: which budget line a type is paid from'),
    ('static func actions_lines_for(_ftype: String) -> Array:\n\treturn ["ECON_BUDGET_PUBLIC_WORKS"]',
     'static func actions_lines_for(ftype: String) -> Array:\n\treturn [ACTIONS_LINE_OF.get(ftype, "ECON_BUDGET_INFRASTRUCTURE"), "ECON_BUDGET_PUBLIC_WORKS"]   # the type\'s own line first, as before'),
    ("static func trade_ship_interval(_world: WorldState) -> Array:\n\treturn [18, 30]",
     'static func trade_ship_interval(world: WorldState) -> Array:\n\tvar v = world.values.get("SHIP_INTERVAL", null)   # a treaty or a sanction may set it; obeyed as before\n\tif typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:\n\t\treturn [int(v[0]), maxi(int(v[0]), int(v[1]))]\n\treturn [18, 30]'),
    ("static func query_explain_facility(_world: WorldState, _fid: String) -> Dictionary:\n\treturn {}",
     'static func query_explain_facility(_world: WorldState, _fid: String) -> Dictionary:\n\treturn {"causes": []}  # callers read this key directly'),
])
print("fixes 2 applied")
