"""Rebuild step 1: the fixes from Ella's review of commit 90cd880. usage: python planning/step1_review_fixes.py (repo root, once)"""
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


# 1. st() must hand out a table that is kept, or what is written into it is lost without a word
patch("game/sim/core/core_util.gd", regex=[(
    r"## The economy's shared state\. \{\} while there is no economy\.\nstatic func peek_st\(world: WorldState\) -> Dictionary:\n\treturn world\.peek\(\"econ\"\)\.get\(\"s\", \{\}\)\n\n\nstatic func st\(world: WorldState\) -> Dictionary:\n\treturn world\.peek\(\"econ\"\)\.get\(\"s\", \{\}\)\n",
    '''## The shared state the old economy kept, which other parts also wrote into (politics keeps which grant programme is
## open there). Until the rebuilt economy has a state of its own it is kept in the table "econ_wait", so that what is
## written is not lost. It is NOT table "econ": much code reads `world.table("econ").has("s")` as "there is an economy",
## and that has to stay false until there is one.
static func peek_st(world: WorldState) -> Dictionary:
	return world.peek("econ_wait").get("s", {})


## The same state, to write into. Created on first use and kept.
static func st(world: WorldState) -> Dictionary:
	var t := world.table("econ_wait")
	if not t.has("s"):
		t["s"] = {}
	return t["s"]
''')])

# 2, 4, and the notes of 3 and 6
patch("game/sim/core/econ_face.gd", [
    ("static func trade_export_pressure(_world: WorldState) -> Dictionary:\n\treturn {}",
     "static func trade_export_pressure(_world: WorldState) -> Dictionary:\n\treturn {\"left_total\": 0}  # the caller reads this key directly"),
    ("## old EconHouseholds.pay_media_wages (economy/econ_households.gd), 2 calls\n",
     "## old EconHouseholds.pay_media_wages (economy/econ_households.gd), 2 calls\n## MUST be connected in the same step as the household pools (step 3): the press treats the household table as \"there is\n## an economy\", and with this still answering 0 every paper that is not the state's runs a deficit and closes.\n"),
    ("## old EconActions.headroom (economy/econ_actions.gd), 11 calls\n",
     "## old EconActions.headroom (economy/econ_actions.gd), 11 calls\n## Connect in the same step as construction_estimate: the government's money check compares the two.\n"),
    ("## old EconConstruction.estimate (economy/econ_construction.gd), 6 calls\n",
     "## old EconConstruction.estimate (economy/econ_construction.gd), 6 calls\n## Connect in the same step as actions_headroom: the government's money check compares the two.\n"),
], regex=[(
    r"## old EconFacts\.emit \(economy/econ_facts\.gd\), 1 call\nstatic func facts_emit\(.*?\) -> String:\n\treturn \"\"\n",
    '''## old EconFacts.emit (economy/econ_facts.gd), 1 call. This one is real, not a plain answer: publishing a fact is the
## fact store's work, not the economy's, so nothing emitted through here is swallowed.
## subjects: [[kind, id], ...]; responsible: [[kind, id, share], ...] (shares sum to 1).
static func facts_emit(world: WorldState, type: String, location, subjects: Array, responsible: Array, impact: Dictionary, magnitude: int, visibility: String, data: Dictionary = {}, affected = "ALL", causes: Array = []) -> String:
	var subj: Array = []
	for x in subjects:
		subj.append({"kind": x[0], "id": x[1]})
	var resp: Array = []
	for x in responsible:
		resp.append({"actor": {"kind": x[0], "id": x[1]}, "share": float(x[2])})
	var f := {"type": type, "owner": "comp" if type.begins_with("COMP_") else "econ", "subjects": subj, "responsible": resp,
		"impact": impact, "magnitude": clampi(magnitude, 0, 100), "visibility": visibility, "data": data,
		"affected": affected, "causes": causes}
	if location != null:
		f["location"] = location
	return world.add_fact(f)
''')])

# the step report
p = "planning/rebuild-step1-report.md"
s = io.open(p, encoding="utf-8", newline="").read()
s = s.rstrip("\n") + '''

## Reviews of this part (the rule: no code without another session reading it)

The first part was committed before the rule existed, so it was reviewed afterwards. Maja (population, office, staff),
Anni (law, staff, office) and Ella (politics, the press) each read every changed line on their ground against the old
code. All three found the renaming itself exact. What they found beyond that, and what was done:

| Found by | What | Done |
|---|---|---|
| Anni | The crime drivers and the police hours were cut off from the economy without a doorway function, so those two connections had vanished from the list | Two doorway functions added (`query_crime_drivers`, `police_hours`) and the law calls them |
| Anni | A fine read a company's last month's books directly, past the doorway | `annual_last_month` added |
| Ella | The shared state handed out for writing was a throwaway: politics' memory of which grant programme is open would have been lost without a word | It is now kept, in its own table, without making the game think an economy exists |
| Ella | One plain answer had the wrong shape: the home world reads a key that was not there | The key is there |
| Ella | Publishing a fact through the doorway did nothing | It publishes the fact; that is the fact store's work, not the economy's |

To remember at later steps, from the same reviews:

- **Step 3:** paying the press's wages must be connected together with the household pools, or every newspaper that is
  not the state's closes within months. (Ella)
- **Step 3:** the player's office screen asks the economy "does a person govern" as soon as the economy's state exists;
  it must answer for real then. (Maja)
- **When the budget comes:** what a budget line has left and what a building is estimated to cost must be connected in
  the same step; the government's money check compares the two. (Ella)
- **A law that does nothing yet:** a press subsidy can be voted and pays nothing while there is no budget. (Ella)
- **Elections in step-1 games** give the market party a business endorsement and the labour party none, because there
  are no unions. It was the same on the stand-in world before. (Ella)
- Law, staff and press code also read the old company and plant tables by name, past the doorway; they are to be
  listed line by line before the company record replaces those tables. (Anni)
- Staff costs are paid into household pools with no seller; in the rebuild they are paid to a service company. (Maja)
'''
io.open(p, "w", encoding="utf-8", newline="\n").write(s)
print("review fixes applied")
