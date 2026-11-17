"""Rebuild step 1, the cases the generator could not do: scripts loaded by path, and the game's start-up.
usage: python planning/step1_hand.py   (from the repo root, once, after step1_doorway.py)"""
import io
import re

G = "game/"


def patch(rel, pairs=(), regex=()):
    p = G + rel
    s = io.open(p, encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    s = s.replace("\r\n", "\n")
    for old, new in pairs:
        if old not in s:
            raise SystemExit("%s: missing %r" % (rel, old[:70]))
        s = s.replace(old, new)
    for pat, new in regex:
        s, k = re.subn(pat, new, s, flags=re.S)
        if k == 0:
            raise SystemExit("%s: no match %s" % (rel, pat[:60]))
    io.open(p, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n") if crlf else s)


# ---- more doors: things that were reached by loading a script by its path
p = G + "sim/core/econ_face.gd"
s = io.open(p, encoding="utf-8", newline="").read()
s = re.sub(r"## old EconSim\.for_load.*?\n\n\n", "", s, flags=re.S)
s = re.sub(r"## old EconSim\.make.*?\n\n\n", "", s, flags=re.S)
s = s.rstrip("\n") + '''


# ---------------------------------------------------------------- reached before by loading a script by its path

## old econ_institutions.gd on(): are public institutions run by the eight rules
static func inst_on(_world: WorldState) -> bool:
	return false


## old econ_institutions.gd build_needs(): plants an institution wants built
static func inst_build_needs(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd close_candidates(): plants an institution wants closed
static func inst_close_candidates(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd budget_requests(): what the institutions ask of the budget
static func inst_budget_requests(_world: WorldState) -> Array:
	return []


## old econ_institutions.gd answered(): the government has taken a request
static func inst_answered(_world: WorldState, _line: String, _answer: int) -> void:
	pass


## old econ_institutions.gd close(): close a public plant
static func inst_close(_world: WorldState, _fid: String) -> Dictionary:
	return {"ok": false, "error": NO}


## old econ_institutions.gd reopen(): reopen a public plant
static func inst_reopen(_world: WorldState, _fid: String) -> Dictionary:
	return {"ok": false, "error": NO}


## old econ_police.gd org(): the police organisation's id
static func police_org(_world: WorldState) -> String:
	return ""


## old EconQuery.prisons(): [{places, ...}]
static func query_prisons(_world: WorldState) -> Array:
	return []


## old companies/insolvency.gd court_liquidation(): the court winds a company up. True when it was done.
static func insolvency_court_liquidation(_world: WorldState, _org_id: String, _reason: String) -> bool:
	return false
'''
if "static func query_police(" not in s:
    s += '''

## old EconQuery.police(): {stations: [...]}
static func query_police(_world: WorldState) -> Dictionary:
	return {}
'''
io.open(p, "w", encoding="utf-8", newline="\n").write(s)

patch("sim/politics/gov_builder.gd", [('const EconInst := preload("res://sim/economy/econ_institutions.gd")\n', "")],
      regex=[(r"\bEconInst\.(\w+)\(", r"EconFace.inst_\1(")])
patch("sim/office/decision_desk.gd", regex=[
    (r"_inst\(\)\.(close|reopen)\(", r"EconFace.inst_\1("),
    (r"\n\nstatic func _inst\(\) -> GDScript:\n\treturn load\(\"res://sim/economy/econ_institutions\.gd\"\)\n", "\n"),
])
patch("sim/law/crime.gd", regex=[
    (r"\tvar eq = load\(\"res://sim/economy/econ_query\.gd\"\)\n\tfor m in eq\.get_script_method_list\(\):\n\t\tif String\(m\[\"name\"\]\) == \"crime_drivers\":\n\t\t\treturn eq\.call\(\"crime_drivers\", world\)\n\treturn _fallback_drivers\(world\)",
     "\treturn _fallback_drivers(world)  # the economy has no reader of its own yet"),
    (r"static func _station_hours\(\):\n.*?(?=\n\nstatic func _fallback_drivers)",
     "static func _station_hours():\n\treturn null  # no police stations to count until the economy has them (EconFace.query_police)\n"),
])
patch("sim/law/police.gd", regex=[
    (r"\tvar eq = load\(\"res://sim/economy/econ_query\.gd\"\)\n\tfor m in eq\.get_script_method_list\(\):\n\t\tif String\(m\[\"name\"\]\) == \"police\":\n\t\t\treturn eq\.call\(\"police\", world\)\.get\(\"stations\", \[\]\)\n\treturn \[\]",
     "\treturn EconFace.query_police(world).get(\"stations\", [])"),
    (r"\tif not ResourceLoader\.exists\(\"res://sim/economy/econ_police\.gd\"\):\n\t\treturn \"\"\n\treturn String\(load\(\"res://sim/economy/econ_police\.gd\"\)\.call\(\"org\", world\)\)",
     "\treturn EconFace.police_org(world)"),
])
patch("sim/law/criminal.gd", regex=[
    (r"\tvar eq = load\(\"res://sim/economy/econ_query\.gd\"\)\n\tfor m in eq\.get_script_method_list\(\):\n\t\tif String\(m\[\"name\"\]\) == \"prisons\":\n\t\t\tvar n := 0\n\t\t\tfor p in eq\.call\(\"prisons\", world\):\n\t\t\t\tn \+= int\(p\.get\(\"places\", 0\)\)\n\t\t\treturn n\n\treturn 0",
     "\tvar n := 0\n\tfor p in EconFace.query_prisons(world):\n\t\tn += int(p.get(\"places\", 0))\n\treturn n"),
])
patch("sim/law/justice_ops.gd", [
    ('bool(load("res://sim/companies/insolvency.gd").court_liquidation(world, org_id, reason))', "EconFace.insolvency_court_liquidation(world, org_id, reason)"),
])

# ---- the game's start-up: the world, law, staff, the planet's month and politics, with no economy
io.open(G + "sim/core/game_sim.gd", "w", encoding="utf-8", newline="\n").write('''class_name GameSim
extends RefCounted
## Builds the game (rebuild step 1). Until the new economy exists the world is the stand-in one politics was first
## built on (StubWorldProvider: a census and nine indicators); law, staff, the planet's month and politics are real.
## The old economy's EconSim did this job; the rebuild adds its parts to _register as they are built.

static func make(seed_value: int, scenario: String = "BALANCED", persona: Dictionary = {}, autoplay: bool = true) -> Simulation:
	var sim := Simulation.new(seed_value)
	sim.world.meta["scenario"] = scenario
	sim.world.meta["persona"] = persona
	sim.world.meta["autoplay_player"] = autoplay
	if not sim.world.meta.has("on"):
		sim.world.meta["on"] = []
	_register(sim)
	sim.new_game()
	return sim


## Registration order: law before staff and politics within DECISIONS.
static func _register(sim: Simulation) -> void:
	sim.register(preload("res://sim/law/law_provider.gd").new())
	sim.register(preload("res://sim/staff/staff_provider.gd").new())
	sim.register(StubWorldProvider.new())
	sim.register(PlanetProvider.new())
	sim.register(PoliticsProvider.new())


static func for_load() -> Simulation:
	var sim := Simulation.new(0)
	_register(sim)
	return sim
''')
for rel in ["ui/game_session.gd"]:
    patch(rel, regex=[(r"EconFace\.sim_make\(", "GameSim.make("), (r"EconFace\.sim_for_load\(", "GameSim.for_load(")])
print("hand cases done")
