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
	"OVERLOAD": {"concern": "PUBLIC_SERVICES", "label": "overworked staff"},   # WORKING_LIFE once Wilma adds it
}
const WASTE_SITING_FACTS: Array[String] = []

const ARRIVALS_FULL_PM := 50     # settlers arriving in WINDOW months = 5% of the colony: full heat
const DEPARTURES_FULL_PM := 30   # the young leaving: 3% of the colony
const LAW_MOVE_HEAT := 400       # parliament moved LAW_IMMIGRATION within WINDOW (fading)
const SLUM_NOW_HEAT := 80        # per district in slum now, capped at SLUM_CHRONIC_CAP: chronic slums are the housing
                                 # concern's business (sat/sal); the hot issue is the news of a new one
const SLUM_CHRONIC_CAP := 250
const SLUM_NEW_HEAT := 600       # a district newly falling into slum (fading over WINDOW)
# workplace overload (Bob's 27-W, opt-in WORKLOAD): ECON_OVERLOAD_INCIDENT news, plus chronic stress
# Bursts, not a constant drone (v8, WORKLOAD on by default: ~8 incidents a year, nearly all severity 90+; the old
# 200-per-incident sum over 18 months was hot 1,109 of 1,200 months): heat comes from incidents ABOVE the colony's
# own usual rate. Seed 1, 40 years: hot 19% of months in ~30 bursts, the longest 5 months.
const OVERLOAD_INCIDENT_HEAT := 250   # per unit (severity/100) of fresh incidents above the usual rate
const OVERLOAD_RECENT := 6            # fresh incidents fade linearly over this many months...
const OVERLOAD_BASE := 36             # ...against the colony's own incident rate over the 36 months before
const OVERLOAD_CHRONIC_FROM := 600    # the worst sector's colony stress ‰ (itself built over ~6 months) above this...
const OVERLOAD_CHRONIC_SLOPE := 0.75  # ...adds 0.75 x the excess, capped at HOT: hot alone only at stress 1000,
const OVERLOAD_CHRONIC_CAP := 300     # a sustained 150% workload (v8 seed 1 peaks at 644)
const OVERLOAD_LINK_MONTHS := 48      # a party is tied to a firm's overload by its public donations or its votes
const STAFFING_LEVERS := {"LAW_STAFFING_RATIOS": -1, "LAW_WORK_INSPECTORATE_BUDGET": -1, "LAW_MAX_WORKING_HOURS": 1}
                                      # lever -> the direction that weakens workers' protection


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
	var sl := minf(float(SLUM_CHRONIC_CAP), float(SLUM_NOW_HEAT) * float((CoreUtil.econ_state(world).get("slums", []) as Array).size()))
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
	# workplace overload: incidents in the news and the most stressed sector (all zero while WORKLOAD is off)
	var fresh := 0.0
	var usual := 0.0
	for f in world.facts.query("ECON_OVERLOAD_INCIDENT", world.month - OVERLOAD_RECENT - OVERLOAD_BASE + 1):
		var sev := float(f["data"].get("severity", 80)) / 100.0
		var age := world.month - int(f["month"])
		if age < OVERLOAD_RECENT:
			fresh += sev * (1.0 - float(age) / float(OVERLOAD_RECENT))
		else:
			usual += sev
	var expected := usual / float(OVERLOAD_BASE) * float(OVERLOAD_RECENT + 1) / 2.0   # the same fade at the usual rate
	var ov := float(OVERLOAD_INCIDENT_HEAT) * maxf(0.0, fresh - expected)
	var worst := 0
	var wl: Dictionary = CoreUtil.econ_state(world).get("workload", {})
	for sec in wl:
		worst = maxi(worst, int(wl[sec]))
	ov += minf(float(OVERLOAD_CHRONIC_CAP), maxf(0.0, float(worst - OVERLOAD_CHRONIC_FROM) * OVERLOAD_CHRONIC_SLOPE))
	out["OVERLOAD"] = clampi(int(ov), 0, 1000)
	return out


## The concern an issue sits under (OVERLOAD moves to WORKING_LIFE when that concern exists).
static func concern(issue: String) -> String:
	if issue == "OVERLOAD" and PolDefs.CONCERNS.has("WORKING_LIFE"):
		return "WORKING_LIFE"
	return String(ISSUES.get(issue, {}).get("concern", ""))


## 0..1: how much of the blame for the hot issue under concern `cn` falls on party `tgt` (attack lines). Today's
## issues fall on the government (1 for a member, 0 otherwise). OVERLOAD is split by who runs the workplaces (A54,
## symmetric): public clinics and schools -> the government; a private firm's -> the parties it publicly funded, or
## that voted through a cut to the staffing laws, in the last OVERLOAD_LINK_MONTHS.
static func blame(world: WorldState, hs: Dictionary, cn: String, tgt: String, members: Array) -> float:
	var gov := 1.0 if members.has(tgt) else 0.0
	if issue_for(hs, cn) != "OVERLOAD":
		return gov
	var pub := 0.0
	var priv := {}
	var tot := 0.0
	for f in world.facts.query("ECON_OVERLOAD_INCIDENT", world.month - WINDOW + 1):
		var w := float(f["data"].get("severity", 80)) * _fade(world, int(f["month"]))
		tot += w
		if String(f["data"].get("owner_kind", "")) == "PUBLIC":
			pub += w
		else:
			var o := String(f["data"].get("owner", ""))
			priv[o] = float(priv.get(o, 0.0)) + w
	if tot <= 0.0:
		return gov
	var b := pub * gov
	if not priv.is_empty():
		var cut := voted_staffing_cut(world, tgt)
		var funders := {}
		for f in world.facts.query("POL_DONATION", world.month - OVERLOAD_LINK_MONTHS + 1):
			if String(f.get("visibility", "")) == "PUBLIC" and String(f["data"].get("party", "")) == tgt:
				funders[String(f["data"].get("donor", ""))] = true
		for o in priv:
			if cut or funders.has(o):
				b += float(priv[o])
	return clampf(b / tot, 0.0, 1.0)


## Did party `pid` vote YES on a passed bill that weakened a staffing law (STAFFING_LEVERS) in the link window?
static func voted_staffing_cut(world: WorldState, pid: String) -> bool:
	for f in world.facts.query("POL_BILL_PASSED", world.month - OVERLOAD_LINK_MONTHS + 1):
		var b: Dictionary = world.peek("bill").get(String(f["data"].get("bill", "")), {})
		if String(b.get("votes", {}).get(pid, "")) != "YES":
			continue
		for c in b.get("clauses", []):
			var lv := String(c.get("lever", ""))
			if STAFFING_LEVERS.has(lv) and signi(int(c.get("to", 0)) - int(c.get("from", 0))) == int(STAFFING_LEVERS[lv]):
				return true
	return false


## {concern: heat of its hottest issue} (0..1000).
static func concern_heat(hs: Dictionary) -> Dictionary:
	var out := {}
	for i in Det.ordered(ISSUES):
		var cn := concern(i)
		out[cn] = maxi(int(out.get(cn, 0)), int(hs.get(i, 0)))
	return out


## The hot issue that names concern cn ("" when none is hot enough).
static func issue_for(hs: Dictionary, cn: String) -> String:
	var best := ""
	var bh := HOT - 1
	for i in Det.ordered(ISSUES):
		if concern(i) == cn and int(hs.get(i, 0)) > bh:
			bh = int(hs[i])
			best = i
	return best


static func label(issue: String) -> String:
	return String(ISSUES.get(issue, {}).get("label", issue.to_lower()))


const OVERLOAD_WHO := {"CLINIC": "nurses", "SCHOOL": "teachers", "SANITATION": "refuse crews", "TRANSIT": "drivers",
	"ELDERCARE": "care workers", "CHILDCARE": "nursery staff"}

## The label as it reads today: workplace overload names the latest incident ("nurses working 64-hour weeks").
## Store it in the fact when emitting (it changes over time).
static func label_now(world: WorldState, issue: String) -> String:
	if issue == "OVERLOAD":
		var inc: Array = world.facts.query("ECON_OVERLOAD_INCIDENT", world.month - WINDOW + 1)
		if not inc.is_empty():
			var d: Dictionary = inc.back()["data"]
			var ft := String(world.peek("facility").get(String(d.get("facility", "")), {}).get("type", ""))
			var hours := clampi(40 * int(d.get("workload", 1000)) / 1000, 30, 80)
			return "%s working %d-hour weeks" % [String(OVERLOAD_WHO.get(ft, "workers")), hours]
	return label(issue)
