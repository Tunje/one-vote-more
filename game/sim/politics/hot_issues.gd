class_name HotIssues
extends RefCounted
## Hot issues (election year, owner Ella; planning/spec-election-year-v1.md §11): live controversies the sim's own
## facts make hot — settlers arriving, slums, the young leaving on the ships, a waste site next door. Each issue sits
## under one voter concern (the vote model is unchanged); a hot issue pushes its concern up the debate questions and
## the parties' theme picks, and gives the question and the theme its name ("asked about immigration").
## Read-only: computed from facts and live state each time, nothing saved.

const Det := preload("res://sim/staff/det.gd")

const WINDOW := 18          # months of facts that count, fading linearly
const HOT := 300            # heat (0..1000) at which an issue names its concern's question / theme
const DEBATE_WEIGHT := 1.0  # a concern's question weight × (1 + this × heat/1000)
const THEME_WEIGHT := 0.6   # a concern's theme score × (1 + this × heat/1000)
const ATTACK_BONUS := 0.2   # a hot issue the government is blamed for: attacking it lands better (× heat/1000)

## issue -> {concern, label}. WASTE_SITING waits for the siting facts of spec-waste W7 (Wilma): list their fact types
## in WASTE_SITING_FACTS when they exist.
const ISSUES := {
	"IMMIGRATION": {"concern": "HOUSING", "label": "immigration"},
	"SLUMS": {"concern": "HOUSING", "label": "the slums"},
	"EMIGRATION": {"concern": "JOBS", "label": "young people leaving"},
	"WASTE_SITING": {"concern": "ENVIRONMENT_QUALITY", "label": "the waste site fight"},
}
const WASTE_SITING_FACTS: Array[String] = []

const ARRIVALS_FULL_PM := 50     # settlers arriving in WINDOW months = 5% of the colony: full heat
const DEPARTURES_FULL_PM := 30   # the young leaving: 3% of the colony
const LAW_MOVE_HEAT := 400       # parliament moved LAW_IMMIGRATION within WINDOW (fading)
const SLUM_NOW_HEAT := 80        # per district in slum now, capped at SLUM_CHRONIC_CAP: chronic slums are the housing
                                 # concern's business (sat/sal); the hot issue is the news of a new one
const SLUM_CHRONIC_CAP := 250
const SLUM_NEW_HEAT := 600       # a district newly falling into slum (fading over WINDOW)


static func _fade(world: WorldState, month: int) -> float:
	return maxf(0.0, 1.0 - float(world.month - month) / float(WINDOW))


## {issue: heat 0..1000} for the colony right now.
static func heat(world: WorldState) -> Dictionary:
	var from := world.month - WINDOW + 1
	var pop := maxf(1.0, float(PopStore.total(world)))
	var out := {}
	# immigration: settlers relative to the colony, hotter when homes are already full, and when the law was moved
	var arr := 0.0
	for f in world.facts.query("ECON_MIGRANTS_ARRIVED", from):
		arr += float(f["data"].get("persons", 0)) * _fade(world, int(f["month"]))
	var crowd := 0.0
	for d in Det.ordered(world.peek("district")):
		crowd = maxf(crowd, float(world.peek("district")[d].get("occupancy", 1000)) / 1000.0)
	var h := 1000.0 * (arr / pop * 1000.0) / float(ARRIVALS_FULL_PM) * clampf(0.5 + 2.5 * (crowd - 0.9), 0.5, 1.5)
	for f in world.facts.query("POL_BILL_PASSED", from):
		var b: Dictionary = world.peek("bill").get(String(f["data"].get("bill", "")), {})
		for c in b.get("clauses", []):
			if String(c.get("lever", "")) == "LAW_IMMIGRATION":
				h += float(LAW_MOVE_HEAT) * _fade(world, int(f["month"]))
	out["IMMIGRATION"] = clampi(int(h), 0, 1000)
	# slums: a little for each standing slum, a lot for a new one
	var sl := minf(float(SLUM_CHRONIC_CAP), float(SLUM_NOW_HEAT) * float(EconCohorts.slums(world).size()))
	for f in world.facts.query("ECON_SLUM", from):
		sl += float(SLUM_NEW_HEAT) * _fade(world, int(f["month"]))
	out["SLUMS"] = clampi(int(sl), 0, 1000)
	# emigration: the young leaving on the ships
	var dep := 0.0
	for f in world.facts.query("ECON_EMIGRATION", from):
		dep += float(f["data"].get("persons", 0)) * _fade(world, int(f["month"]))
	out["EMIGRATION"] = clampi(int(1000.0 * (dep / pop * 1000.0) / float(DEPARTURES_FULL_PM)), 0, 1000)
	var ws := 0.0
	for t in WASTE_SITING_FACTS:
		for f in world.facts.query(t, from):
			ws += 400.0 * _fade(world, int(f["month"]))
	out["WASTE_SITING"] = clampi(int(ws), 0, 1000)
	return out


## {concern: heat of its hottest issue} (0..1000).
static func concern_heat(hs: Dictionary) -> Dictionary:
	var out := {}
	for i in Det.ordered(ISSUES):
		var cn := String(ISSUES[i]["concern"])
		out[cn] = maxi(int(out.get(cn, 0)), int(hs.get(i, 0)))
	return out


## The hot issue that names concern cn ("" when none is hot enough).
static func issue_for(hs: Dictionary, cn: String) -> String:
	var best := ""
	var bh := HOT - 1
	for i in Det.ordered(ISSUES):
		if String(ISSUES[i]["concern"]) == cn and int(hs.get(i, 0)) > bh:
			bh = int(hs[i])
			best = i
	return best


static func label(issue: String) -> String:
	return String(ISSUES.get(issue, {}).get("label", issue.to_lower()))
