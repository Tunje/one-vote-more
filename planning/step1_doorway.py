"""Rebuild step 1: builds the core helpers and the one doorway to the economy, and points every call at them.

usage: python planning/step1_doorway.py   (from the repo root; run once)

- game/sim/core/core_util.gd  (CoreUtil): the general helpers that lived in the old EconUtil.
- game/sim/core/econ_face.gd  (EconFace): ONE function for every call the rest of the game made into the old economy,
  under the old name, giving a plain "nothing yet" answer. The rebuild fills them in step by step; what is still a
  plain answer is what is still unconnected.
- every call site in game/ is pointed at one of the two.
"""
import collections
import io
import os
import re
import subprocess

OLD = "785c72f"
PREFIX = {"FirmAI": "firm", "Unions": "unions", "UnionDisputes": "disputes", "LawBridge": "lawbridge"}
CORE = {"sorted_keys", "split_lr", "off", "S", "TREASURY", "FINES", "BANK", "pay_upto", "cash", "normal", "fscale", "acct", "hh_acct", "lever", "peek_st", "st"}
NO = '"There is no economy yet."'
# plain data readers and answers that have a right value even with no economy
BODY = {
    ("EconHouseholds", "persons"): 'return int(g.get("lf", 0)) + int(g.get("nonpart", 0)) + int(g.get("retired", 0)) + int(g.get("children", 0)) + int(g.get("owners", 0))',
    ("EconHouseholds", "disposable"): 'var i: Dictionary = g.get("income", {})\n\treturn int(i.get("wages", 0)) + int(i.get("benefit", 0)) + int(i.get("pension", 0)) + int(i.get("dividend", 0)) + int(i.get("self", 0))',
    ("EconLabor", "staff_total"): 'var n := 0\n\tfor t in staff:\n\t\tfor g in staff[t]:\n\t\t\tn += int(staff[t][g])\n\treturn n',
    ("EconLabor", "employed"): 'var n := 0\n\tfor occ in g.get("emp", {}):\n\t\tn += int(g["emp"][occ])\n\treturn n',
    ("EconAnnual", "months"): 'return (o.get("pl_ring", []) as Array).size()',
    ("EconAnnual", "sum12"): 'var out := {}\n\tfor pl in o.get("pl_ring", []):\n\t\tfor k in pl:\n\t\t\tout[k] = int(out.get(k, 0)) + int(pl[k])\n\treturn out',
    ("EconPop", "district_of"): 'return hb.substr(3)',
    ("EconPop", "lab_parts"): 'var i := k.rfind("|")\n\treturn [k.substr(0, i), k.substr(i + 1)]',
    ("EconActions", "enqueue"): 'return {"ok": false, "error": %s}' % NO,
    ("EconActions", "check"): 'return {"ok": false, "error": %s}' % NO,
    ("EconActions", "validate"): 'return %s' % NO,
    ("EconActions", "lines_for"): 'return ["ECON_BUDGET_PUBLIC_WORKS"]',
    ("EconQuery", "budget_view"): 'return {"treasury": float(world.ledger.balance(CoreUtil.TREASURY)) / float(CoreUtil.S), "debt": 0.0, "credit_headroom": 0.0, "runway_months": 0, "balance_pct": 0, "grant_this_month": 0.0, "lines": [], "tax_levers": {"income": 0, "profit": 0, "tariff": 0}}',
    ("EconQuery", "district_economy"): 'return {"district": d, "name": str(world.peek("district").get(d, {}).get("name", d))}',
    ("EconTrade", "next_ship"): 'return -1',
    ("EconTrade", "ship_interval"): 'return [18, 30]',
}
CONST = {
    ("EconAnnual", "MIN_M"): "const ANNUAL_MIN_M := 3",
    ("EconActions", "LINE_OF"): "const ACTIONS_LINE_OF := {}",
    ("EconQuery", "LINE_LABELS"): "const QUERY_LINE_LABELS := {}",
    ("EconUnions", "DONATION_MIN"): "const UNIONS_DONATION_MIN := 2000 * 1000",
    ("Unions", "MODERATE"): 'const UNIONS_MODERATE := ["PROFESSIONAL"]',
}
DEFAULT = {"void": "pass", "int": "return 0", "float": "return 0.0", "bool": "return false", "String": 'return ""', "Dictionary": "return {}", "Array": "return []"}


def git(*a):
    return subprocess.run(["git"] + list(a), capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def prefix(c):
    if c in PREFIX:
        return PREFIX[c]
    return re.sub(r"^Econ", "", c).lower()


files = [f for f in git("ls-tree", "-r", "--name-only", OLD, "game/sim/economy", "game/sim/companies").split("\n") if f.endswith(".gd")]
src = {}
where = {}
for f in files:
    t = git("show", OLD + ":" + f)
    m = re.search(r"^class_name (\w+)", t, re.M)
    if m:
        src[m.group(1)] = t
        where[m.group(1)] = f.replace("game/sim/", "")
pat = re.compile(r"\b(%s)\.(\w+)" % "|".join(sorted(src, key=len, reverse=True)))


def gd_files():
    for root, _, fs in os.walk("game"):
        if ".godot" in root:
            continue
        for fn in sorted(fs):
            if fn.endswith(".gd"):
                yield os.path.join(root, fn)


def code_part(line):
    """the part of a line before a comment (strings with # are rare enough to ignore here)"""
    if line.lstrip().startswith("#"):
        return ""
    return line.split("#", 1)[0]


uses = collections.Counter()
for p in gd_files():
    if p.replace("\\", "/").startswith(("game/tests", "game/tools")):
        continue  # the doorway holds what the GAME calls; tests and tools of the old economy are dealt with apart
    for line in io.open(p, encoding="utf-8", errors="replace"):
        for m in pat.finditer(code_part(line)):
            uses[(m.group(1), m.group(2))] += 1

# ---------------------------------------------------------------- CoreUtil
util = src["EconUtil"]


def old_func(text, name):
    m = re.search(r"^((?:##[^\n]*\n)*)static func %s\(.*?(?=^\S|\Z)" % re.escape(name), text, re.M | re.S)
    return m.group(0).rstrip() + "\n" if m else ""


core = ['class_name CoreUtil', 'extends RefCounted',
        '## General helpers every part of the game uses. They lived in the old economy\'s EconUtil until the economy was cut',
        '## out (2026-11-17); they are not economy. Built by planning/step1_doorway.py (rebuild step 1).', '',
        'const S := 1000  # fixed-point scale', 'const TREASURY := "gov:treasury"', 'const FINES := "gov:fines_revenue"', 'const BANK := "bank"', '']
for name in ["sorted_keys", "split_lr", "normal", "off", "cash", "pay_upto", "acct", "hh_acct", "fscale", "lever"]:
    body = old_func(util, name)
    body = body.replace("EconUtil.", "").replace("EconData.", "EconData.")
    core.append("")
    core.append(body.rstrip())
    core.append("")
core += ["", "## The economy's shared state. {} while there is no economy.", "static func peek_st(world: WorldState) -> Dictionary:",
         '\treturn world.peek("econ").get("s", {})', "", "", "static func st(world: WorldState) -> Dictionary:", '\treturn world.peek("econ").get("s", {})', ""]
io.open("game/sim/core/core_util.gd", "w", encoding="utf-8", newline="\n").write("\n".join(core))

# ---------------------------------------------------------------- EconFace
face = ['class_name EconFace', 'extends RefCounted',
        '## THE ONE DOORWAY TO THE ECONOMY (rebuild step 1, planning/rebuild-company.md section 13).',
        '## Every call the rest of the game made into the old economy is one function here, under its old name',
        '## (<old class>_<old function>), with the old arguments. Each gives a plain "nothing yet" answer until the rebuild',
        '## connects it. A function still giving the plain answer is a connection still open. Nothing outside this file',
        '## may call the economy any other way. Built by planning/step1_doorway.py; edit by hand from here on.', '',
        'const NO := "There is no economy yet."', '']
for k in sorted(CONST):
    if k in uses:
        face.append(CONST[k] + "  # old %s.%s" % k)
face.append("")
made = []
for (c, f), n in sorted(uses.items()):
    if c == "EconUtil" or (c, f) in CONST:
        continue
    m = re.search(r"^static func %s\((.*?)\)(?:\s*->\s*([\w\[\]]+))?\s*:" % re.escape(f), src[c], re.M | re.S)
    if not m:
        print("NO SIGNATURE", c, f)
        continue
    args = re.sub(r"\s+", " ", m.group(1)).strip()
    args = re.sub(r"\b(%s)\." % "|".join(src), "EconFace_OLD_", args)  # defaults that referred to old constants
    ret = m.group(2) or ""
    name = "%s_%s" % (prefix(c), f.lstrip("_"))
    body = BODY.get((c, f)) or DEFAULT.get(ret, "return null")
    # unused arguments get an underscore so the compiler does not warn; keep names used by a real body
    parts = []
    for one in [x.strip() for x in re.split(r",(?![^\[\(]*[\]\)])", args) if x.strip()]:
        an = re.match(r"\w+", one).group(0)
        if not re.search(r"\b%s\b" % re.escape(an), body):
            one = "_" + one
        parts.append(one)
    args2 = ", ".join(parts)
    face.append("## old %s.%s (%s), %d call%s" % (c, f, where[c], n, "" if n == 1 else "s"))
    face.append("static func %s(%s)%s:" % (name, args2, (" -> " + ret) if ret else ""))
    face.append("\t" + body)
    face.append("")
    face.append("")
    made.append((c, f, name))
io.open("game/sim/core/econ_face.gd", "w", encoding="utf-8", newline="\n").write("\n".join(face).rstrip() + "\n")

# ---------------------------------------------------------------- call sites
names = {(c, f): n for c, f, n in made}
constname = {k: CONST[k].split()[1] for k in CONST}


def swap(m):
    c, f = m.group(1), m.group(2)
    if c == "EconUtil":
        return "CoreUtil." + f
    if (c, f) in constname:
        return "EconFace." + constname[(c, f)]
    if (c, f) in names:
        return "EconFace." + names[(c, f)]
    return m.group(0)


changed = 0
for p in gd_files():
    if p.replace("\\", "/").endswith(("core/core_util.gd", "core/econ_face.gd")):
        continue
    s = io.open(p, encoding="utf-8", newline="").read()
    lines = s.split("\n")
    out = []
    for line in lines:
        cp = code_part(line)
        if cp and pat.search(cp):
            line = pat.sub(swap, cp) + line[len(cp):]
        out.append(line)
    s2 = "\n".join(out)
    if s2 != s:
        io.open(p, "w", encoding="utf-8", newline="").write(s2)
        changed += 1
print("CoreUtil written; EconFace: %d functions; %d files repointed" % (len(made), changed))
