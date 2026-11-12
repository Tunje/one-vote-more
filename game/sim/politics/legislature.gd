class_name Legislature
extends RefCounted
## Bills = lists of lever-change clauses (DECISIONS J4/A9). This module is the politics side only:
## proposing, voting, and queueing enacted changes. The LAW subsystem applies them to world.levers.
##
## Hand-off table (agreed interface with law/a9): world.table("enactment")[id] = {
##   id, lever, value, legal_level ("ORDINANCE"|"LAW"), source_bill, decided_month,
##   earliest_effective_month, status: "PENDING" }
## Law owns everything after that: validation, implementation task, lag, operative write, *_LEVER_EFFECTIVE fact.

const LawOps := preload("res://sim/law/law_ops.gd")
const STEP_FRACTION := 0.10          # one clause moves a lever by 10% of its range
const MAX_CLAUSES := 2
const TINKER_COST := 1.5           # score cost of moving a lever again the same way (no endless small steps)
const IMPLEMENTATION_MONTHS_STUB := 2  # placeholder until staff implementation tasks exist (M3)
const IDEOLOGY_VOTE_WEIGHT := 2.5    # substance over role: ideology dominates floor votes (tuning knob)
const FISCAL_STRESS_GAIN := 6.0      # how hard fiscal stress amplifies the budget value of clauses (tuning knob)
const FISCAL_ROOM_PULL := 0.5        # with fiscal room, spending/tax cuts gain this much budget value (tuning knob)
const CRISIS_STEP_FRACTION := 0.20   # clause size when a concern is in crisis
const HIGH_HARM_WEIGHT := 2.0        # weight of concernsHigh harm relative to ordinary hints (tuning knob)
const REJECTED_MEMORY_MONTHS := 36   # a change rejected by legal review is not proposed again in that direction for 3 years
const VOTE_NOISE_SD := 3.0           # how unpredictable non-government parties are on the floor (tuning knob)


static func _range(def: Dictionary) -> Array:
	if def.get("type", "NUMBER") == "ENUM":
		return [0, maxi(1, def.get("values", []).size() - 1)]
	if def.get("type", "NUMBER") == "BOOL":
		return [0, 1]
	return def.get("range", [0, 100])


## Ordinal position of a lever value, so ENUM/BOOL levers work with the same maths as NUMBER levers.
## ENUM values are ordered as listed in the def (e.g. BASIC < STANDARD < STRICT).
static func ordinal(def: Dictionary, value) -> float:
	match def.get("type", "NUMBER"):
		"ENUM":
			return float(maxi(0, def.get("values", []).find(value)))
		"BOOL":
			return 1.0 if bool(value) else 0.0
	return float(value)


static func clause_delta(def: Dictionary, c: Dictionary) -> float:
	return ordinal(def, c["to"]) - ordinal(def, c["from"])


## Ideological alignment of a clause with a position (milli-point vector). Positive = actor likes it.
static func ideo_alignment(def: Dictionary, delta: float, pos: Dictionary) -> float:
	var s := 0.0
	for ax in def.get("ideology", {}):
		s += float(def["ideology"][ax]) * delta * float(pos[ax]) / 1000.0 / 100.0
	return s


## Expected relief of colony concerns: sum of the lever's concern hints x size of change x how unmet x how salient.
## Under fiscal stress (0..1) the GOVERNANCE hint (the sign-proxy for budget impact: spending < 0, revenue > 0)
## is amplified and treated as urgent, so tax-up / spend-down clauses rise to the top.
static func relief(def: Dictionary, delta: float, sat: Dictionary, sal: Dictionary, stress: float = 0.0, room: float = 0.0, cur: float = 0.0) -> float:
	var r := _range(def)
	var frac := delta / maxf(1.0, float(r[1] - r[0]))
	var s := 0.0
	var hints: Dictionary = def.get("concerns", {})
	for c in hints:
		var unmet := 1.0 - float(sat.get(c, 50000)) / 100000.0
		var w := float(hints[c])
		var sl := float(sal.get(c, 111))
		if c == "GOVERNANCE":
			# The GOVERNANCE hint on economic levers is a BUDGET-SIGN proxy (spending < 0, revenue > 0).
			# Its value follows the fiscal GAP: under stress raise revenue / cut spending; with room, the
			# opposite is acceptable; when the books are balanced it is neutral. It never follows voters'
			# governance dissatisfaction (scandals must not cause tax hikes; 88's seed-3 spiral).
			var pressure := 0.0
			if stress > 0.0:
				pressure = stress * (1.0 + FISCAL_STRESS_GAIN * stress)
			elif room > 0.0:
				pressure = -FISCAL_ROOM_PULL * room
			s += w * frac * pressure * 1.5
			continue
		s += w * frac * unmet * sl / 100.0
	# Non-linear harm (pic-core v1.4 `concernsHigh {from, concerns}`): the part of a change that lies above
	# `from` carries extra concern effects (e.g. taxes above 35% choke jobs). Counted like normal hints.
	var hi: Dictionary = def.get("concernsHigh", {})
	if not hi.is_empty() and delta != 0.0:
		var lo := float(hi["from"])
		var a := minf(cur, cur + delta)
		var b := maxf(cur, cur + delta)
		var above := maxf(0.0, b - maxf(a, lo))
		var frac_hi := signf(delta) * above / maxf(1.0, float(r[1] - r[0]))
		for c in hi["concerns"]:
			var unmet_h := 1.0 - float(sat.get(c, 50000)) / 100000.0
			s += float(hi["concerns"][c]) * frac_hi * maxf(unmet_h, 0.5) * float(sal.get(c, 111)) / 100.0 * HIGH_HARM_WEIGHT
	# Mirror image (pic-core v1.4 `concernsLow`): extra effects for the part of a change BELOW `from`
	# (cutting pensions, infrastructure or pay too far). Same sign convention: effect of RAISING.
	var lw: Dictionary = def.get("concernsLow", {})
	if not lw.is_empty() and delta != 0.0:
		var top := float(lw["from"])
		var a2 := minf(cur, cur + delta)
		var b2 := maxf(cur, cur + delta)
		var below := maxf(0.0, minf(b2, top) - a2)
		var frac_lo := signf(delta) * below / maxf(1.0, float(r[1] - r[0]))
		for c in lw["concerns"]:
			var unmet_l := 1.0 - float(sat.get(c, 50000)) / 100000.0
			s += float(lw["concerns"][c]) * frac_lo * maxf(unmet_l, 0.5) * float(sal.get(c, 111)) / 100.0 * HIGH_HARM_WEIGHT
	return s


## Fiscal stress 0..1 = worst badness over indicators that declare `fiscalStress {good, bad}` (pic-core §3 v1.2).
## Read from current (official) values: the government sees its own books before voters do.
static func fiscal_stress(world: WorldState) -> float:
	var worst := 0.0
	for id in world.indicators.defs:
		var fs: Dictionary = world.indicators.defs[id].get("fiscalStress", {})
		if fs.is_empty() or not world.indicators.values[id].has("COLONY"):
			continue
		var v := float(world.indicators.read(id, "COLONY"))
		var good := float(fs["good"])
		var bad := float(fs["bad"])
		if good != bad:
			worst = maxf(worst, clampf((v - good) / (bad - good), 0.0, 1.0))
	return worst


## Fiscal guard (pic-core §3 v1.3): true if any indicator declaring `fiscalGuard {floor}` is below its floor.
## While guarded, actors don't PROPOSE budget-worsening clauses (GOVERNANCE hint x delta < 0). They can still cut.
static func fiscal_guard(world: WorldState) -> bool:
	for id in world.indicators.defs:
		var fg: Dictionary = world.indicators.defs[id].get("fiscalGuard", {})
		if fg.is_empty() or not world.indicators.values[id].has("COLONY"):
			continue
		if world.indicators.read(id, "COLONY") < int(fg["floor"]):
			return true
	return false


## Fiscal room 0..1: how comfortably ALL fiscalStress indicators sit beyond their "good" level
## (by up to one good-bad span). 0 if there are none. Mirror image of fiscal_stress.
static func fiscal_room(world: WorldState) -> float:
	var room := 1.0
	var found := false
	for id in world.indicators.defs:
		var fs: Dictionary = world.indicators.defs[id].get("fiscalStress", {})
		if fs.is_empty() or not world.indicators.values[id].has("COLONY"):
			continue
		found = true
		var v := float(world.indicators.read(id, "COLONY"))
		var good := float(fs["good"])
		var bad := float(fs["bad"])
		if good != bad:
			room = minf(room, clampf((v - good) / (good - bad), 0.0, 1.0))
	return room if found else 0.0


## Pick the clauses an actor with position `pos` would propose.
## allowed: "COMMANDER" (founding-era ordinances) or "PARLIAMENT".
const TRAINING_LEVERS := ["ECON_TRAINING_SUBSIDY", "ECON_BUDGET_TRAINING"]


## How badly skilled posts go unfilled (0..2): skilled and specialist vacancies beyond the unemployed of that tier
## (Bob's E114 EconQuery.essentials()["SKILLS"]). A parliament under such a gap sees a case for training money;
## ideology still decides who backs it.
static func _skill_gap(world: WorldState) -> float:
	if not world.table("econ").has("s"):
		return 0.0
	var k: Dictionary = EconTraining.summary(world)
	var gap := maxf(0.0, float(k.get("vacancies_S", 0)) - float(k.get("unemployed_S", 0))) / 20.0 		+ maxf(0.0, float(k.get("vacancies_Sp", 0)) - float(k.get("unemployed_Sp", 0))) / 6.0
	return clampf(gap, 0.0, 2.0)


## pork (0..1, election year; Ella/Campaign.pork_pressure): crowd-pleasing relief counts more, ideology less.
## stats (optional, written by the caller's state): {"guard_blocked": n} clauses the fiscal guard kept out.
static func propose(world: WorldState, pos: Dictionary, sat: Dictionary, sal: Dictionary, agreement: Array, allowed: String, stress: float = 0.0, crisis: bool = false, exclude: Dictionary = {}, pork: float = 0.0, stats: Dictionary = {}) -> Array:
	var scored: Array = []
	var guarded := fiscal_guard(world)
	var room := fiscal_room(world)
	var step_fraction := CRISIS_STEP_FRACTION if crisis else STEP_FRACTION
	var mem := _bill_memory(world) if allowed == "PARLIAMENT" else {"defeated": {}, "moved": {}}
	var skill_gap := _skill_gap(world) if allowed == "PARLIAMENT" else 0.0
	var owed := {}   # "lever|dir" of confidence-and-supply prices still owed: a commitment, not a whim
	for a in agreement:
		if a.get("deal", false):
			owed["%s|%d" % [a["lever"], int(a["dir"])]] = true
	var ids := world.lever_defs.keys()
	ids.sort()
	for lid in ids:
		var def: Dictionary = world.lever_defs[lid]
		if def["type"] != "NUMBER" or (def.get("owner", "") == "law" and not bool(def.get("legislative", false))):
			continue
		if allowed == "COMMANDER" and def["foundingEra"] != "COMMANDER":
			continue
		if allowed == "PARLIAMENT" and not (def["legalLevel"] in ["LAW", "REGULATION"]):
			continue
		if _pending_for(world, lid) or exclude.has(lid):
			continue
		var r := _range(def)
		var step := maxf(1.0, round(float(r[1] - r[0]) * step_fraction))
		var cur := float(world.levers[lid])
		for dir in [1, -1]:
			var to := clampf(cur + dir * step, float(r[0]), float(r[1]))
			var delta := to - cur
			if delta == 0.0:
				continue
			var owes: bool = owed.has("%s|%d" % [lid, int(signf(delta))])
			if guarded and not owes and float(def.get("concerns", {}).get("GOVERNANCE", 0)) * delta < 0.0:
				stats["guard_blocked"] = int(stats.get("guard_blocked", 0)) + 1
				continue  # fiscal guard: no new spending / tax cuts while the books are weak (pork never overrides it)
			if _recently_rejected(world, lid, signf(delta)):
				continue  # learned: legal review threw this out recently
			var level: String = "ORDINANCE" if allowed == "COMMANDER" else String(def["legalLevel"])
			if not LawOps.check_change(world, lid, int(to), level).is_empty():
				continue  # the government's lawyers screen proposals before drafting
			var dk := "%s|%d" % [lid, int(signf(delta))]
			if mem["defeated"].has(dk) and not owes:
				continue  # parliament threw this out and its make-up hasn't changed: don't table it again
			if mem["moved"].has("%s|%d" % [lid, -int(signf(delta))]) and not owes:
				continue  # this government moved it the other way recently: no flip-flopping
			var ia := ideo_alignment(def, delta, pos)
			var rl := relief(def, delta, sat, sal, stress, room, cur)
			# Conviction: a government believes its own remedies work. Relief from a change that goes against its
			# ideology is discounted (a market government does not see a jobs scheme as the cure, a left one does not
			# see benefit cuts as one), so parties answer the same crisis differently. Not under fiscal stress:
			# budget repair is shared ground.
			if ia < 0.0 and rl > 0.0 and stress <= 0.0:
				rl /= 1.0 + absf(ia) / 2.0
			var sc := (1.0 - 0.3 * pork) * ia + 3.0 * (1.0 + 0.5 * pork) * rl
			if skill_gap > 0.0 and delta > 0.0 and lid in TRAINING_LEVERS:
				sc += skill_gap  # E114: firms cannot fill skilled posts; training money and the subsidy go together
			# v5 review (433 bills in one run): no endless tinkering. Moving the same lever again the same way within
			# the government's memory needs a stronger case, unless it is the programme (agreement) or an owed price.
			var programme := false
			for a in agreement:
				if a["lever"] == lid and signf(delta) == a["dir"]:
					programme = true
			if mem["moved"].has(dk) and not programme and not owes:
				sc -= TINKER_COST
			var is_deal := false
			for a in agreement:
				if a["lever"] == lid:
					var w := 12.0 if a.get("deal", false) else 6.0   # a confidence-and-supply price is owed: deliver it
					sc += w if signf(delta) == a["dir"] else -w
					if a.get("deal", false) and signf(delta) == a["dir"]:
						is_deal = true
			if sc > 1.0 or is_deal:
				var cl := {"lever": lid, "from": int(cur), "to": int(to), "score": int(round(sc * 100.0))}
				if is_deal:
					cl["deal"] = true
				scored.append(cl)
	# owed prices first (the deal is the government's survival), then by score
	scored.sort_custom(func(a, b): return (a.get("deal", false) and not b.get("deal", false)) or (a.get("deal", false) == b.get("deal", false) and (a["score"] > b["score"] or (a["score"] == b["score"] and a["lever"] < b["lever"]))))
	var out: Array = []
	var used := {}
	var gov: Dictionary = world.table("pol")["state"].get("government", {}) if allowed == "PARLIAMENT" else {}
	for c in scored:
		if used.has(c["lever"]):
			continue
		if not gov.is_empty() and not c.get("deal", false) and not _members_back(world, gov, c, sat, sal):
			continue  # every governing party must be willing to vote for its own government's bill
		used[c["lever"]] = true
		out.append(c)
		if out.size() >= MAX_CLAUSES:
			break
	return out


const IN_FLIGHT := ["PENDING", "LEGAL", "SCHEDULED"]
const DEFEAT_MEMORY_MONTHS := 24     # a defeated change waits this long, or until parliament is re-elected
const REVERSAL_MEMORY_MONTHS := 36   # a government doesn't reverse its own change within this


## Memory of recent parliamentary outcomes for the current government:
##   defeated: "lever|dir" defeated since the last election (and within DEFEAT_MEMORY_MONTHS)
##   moved:    "lever|dir" passed by THIS government within REVERSAL_MEMORY_MONTHS
static func _bill_memory(world: WorldState) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	var g: Dictionary = st.get("government", {})
	var formed := int(g.get("formed_month", -1))
	var last_election := -1
	for eid in st.get("elections", []):
		last_election = maxi(last_election, int(world.table("election")[eid]["month"]))
	var out := {"defeated": {}, "moved": {}}
	for b in world.table("bill").values():
		var m := int(b["month"])
		for c in b.get("clauses", []):
			if not world.lever_defs.has(c["lever"]):
				continue
			var d := int(signf(clause_delta(world.lever_defs[c["lever"]], c)))
			var k := "%s|%d" % [c["lever"], d]
			if b.get("status", "") == "DEFEATED" and m >= last_election and world.month - m <= DEFEAT_MEMORY_MONTHS:
				out["defeated"][k] = m
			elif b.get("status", "") == "PASSED" and formed >= 0 and m >= formed and world.month - m <= REVERSAL_MEMORY_MONTHS:
				out["moved"][k] = m
	return out


## True if every governing party would vote YES on a bill containing just this clause.
static func _members_back(world: WorldState, gov: Dictionary, clause: Dictionary, sat: Dictionary, sal: Dictionary) -> bool:
	for pid in gov.get("members", []):
		var p: Dictionary = world.table("party").get(pid, {})
		if p.is_empty() or p.get("status", "") != "ACTIVE":
			continue
		if party_vote(p, [clause], world, gov, sat, sal) != "YES":
			return false
	return true


## True if legal review rejected a change of this lever in direction `dir` within REJECTED_MEMORY_MONTHS.
static func _recently_rejected(world: WorldState, lever_id: String, dir: float) -> bool:
	for e in world.table("enactment").values():
		if e["lever"] != lever_id or e["status"] != "REJECTED":
			continue
		if world.month - int(e.get("decided_month", -999)) > REJECTED_MEMORY_MONTHS:
			continue
		var prev = e.get("prev_value", world.levers.get(lever_id))
		if typeof(prev) in [TYPE_INT, TYPE_FLOAT] and signf(float(e["value"]) - float(prev)) == dir:
			return true
		if not (typeof(prev) in [TYPE_INT, TYPE_FLOAT]):
			return true
	return false


## True if a change to this lever is already decided but not yet operative. Proposing again would supersede it.
static func _pending_for(world: WorldState, lever_id: String) -> bool:
	for e in world.table("enactment").values():
		if e["lever"] == lever_id and e["status"] in IN_FLIGHT:
			return true
	return false


## How a party votes on a bill: YES / NO / ABSTAIN.
static func party_vote(party: Dictionary, clauses: Array, world: WorldState, gov: Dictionary, sat: Dictionary, sal: Dictionary, draft_quality: int = 50, noise: float = 0.0) -> String:
	var s := (float(draft_quality) - 50.0) / 10.0 + noise  # well-drafted bills inspire confidence; sloppy ones lose votes
	var member: bool = party["id"] in gov.get("members", [])
	for c in clauses:
		var def: Dictionary = world.lever_defs[c["lever"]]
		var delta := clause_delta(def, c)
		s += IDEOLOGY_VOTE_WEIGHT * ideo_alignment(def, delta, party["positions"]) + 1.5 * relief(def, delta, sat, sal, fiscal_stress(world), fiscal_room(world), ordinal(def, c["from"]))
		for cm in party["commitments"]:
			if cm["lever"] == c["lever"]:
				var agree: bool = signf(delta) == cm["dir"]
				var w := 12.0 if cm["kind"] == "CORE" else 5.0
				s += w if agree else -w
		for a in gov.get("agreement", []):
			if member and a["lever"] == c["lever"]:
				s += 8.0 if signf(delta) == a["dir"] else -8.0
	if member:
		s += 15.0
	elif party["id"] in gov.get("support", []):
		s += 2.0   # support parties lean towards tolerating
	else:
		s -= 3.0   # mild opposition reflex; the bill's content decides
	if member:
		# coalition discipline (v4 review: cabinet parties voted against their own government's bills): a governing
		# party votes for the government's bills; on a matter of strong conscience it abstains, never votes against
		return "YES" if s > -10.0 else "ABSTAIN"
	if s > 2.0:
		return "YES"
	if s < -2.0:
		return "NO"
	return "ABSTAIN"


## Commander ordinance: no vote. Updates the commander's revealed ideology (the future player party identity).
static func issue_ordinance(world: WorldState, clauses: Array, source_id: String = "") -> String:
	var st: Dictionary = world.table("pol")["state"]
	for c in clauses:
		var def: Dictionary = world.lever_defs[c["lever"]]
		var delta := clause_delta(def, c)
		for ax in def.get("ideology", {}):
			st["revealed"][ax] = clampi(st["revealed"][ax] + int(round(float(def["ideology"][ax]) * delta * 450.0)), -100000, 100000)
		_queue(world, c, "ORDINANCE", source_id)
	return world.add_fact({"type": "POL_ORDINANCE_ISSUED", "owner": "pol", "subjects": [{"kind": "COMMANDER", "id": "commander"}],
		"responsible": [{"actor": {"kind": "COMMANDER", "id": "commander"}, "share": 1.0}],
		"impact": {}, "magnitude": 30, "visibility": "PUBLIC", "data": {"clauses": clauses}})


## Parliamentary bill: proposed by the government, voted by all seated parties. Majority of votes cast.
## Count YES/NO seats a set of clauses would get (no side effects).
static func predict(world: WorldState, clauses: Array, gov: Dictionary, sat: Dictionary, sal: Dictionary, draft_quality: int) -> Array:
	var yes := 0
	var no := 0
	for pid in world.table("party"):
		var p: Dictionary = world.table("party")[pid]
		if p["seats"] == 0 or p["status"] != "ACTIVE":
			continue
		var v := party_vote(p, clauses, world, gov, sat, sal, draft_quality)
		if v == "YES": yes += p["seats"]
		elif v == "NO": no += p["seats"]
	return [yes, no]


## Minority governments negotiate: if the full bill would fail, drop to the best single clause that passes.
## If nothing can pass, the government still tables the full bill (and loses the vote publicly).
static func negotiate(world: WorldState, clauses: Array, gov: Dictionary, sat: Dictionary, sal: Dictionary, draft_quality: int) -> Array:
	var r := predict(world, clauses, gov, sat, sal, draft_quality)
	if r[0] > r[1] or clauses.size() <= 1:
		return clauses
	for c in clauses:
		var rr := predict(world, [c], gov, sat, sal, draft_quality)
		if rr[0] > rr[1]:
			return [c]
	return clauses


static func submit_bill(world: WorldState, clauses: Array, gov: Dictionary, sat: Dictionary, sal: Dictionary, bill_id: String = "", draft_quality: int = 50) -> Dictionary:
	clauses = negotiate(world, clauses, gov, sat, sal, draft_quality)
	var parties: Dictionary = world.table("party")
	var votes := {}
	var yes := 0
	var no := 0
	for pid in parties:
		var p: Dictionary = parties[pid]
		if p["seats"] == 0 or p["status"] != "ACTIVE":
			continue
		# Whip uncertainty: the government counts votes without noise; the real vote has it (non-members only).
		var noise := 0.0
		if not (pid in gov.get("members", [])):
			noise = world.rng.stream("pol.vote").randfn(0.0, VOTE_NOISE_SD)
		var v := party_vote(p, clauses, world, gov, sat, sal, draft_quality, noise)
		votes[pid] = v
		if v == "YES":
			yes += p["seats"]
		elif v == "NO":
			no += p["seats"]
	if bill_id == "":
		bill_id = world.new_id("bill")
	var passed := yes > no
	var bill := {"id": bill_id, "month": world.month, "sponsor": gov["pm_party"], "clauses": clauses,
		"votes": votes, "yes": yes, "no": no, "draft_quality": draft_quality, "status": "PASSED" if passed else "DEFEATED"}
	world.table("bill")[bill_id] = bill
	if passed:
		for c in clauses:
			_queue(world, c, "LAW", bill_id)
	world.add_fact({"type": "POL_BILL_PASSED" if passed else "POL_BILL_DEFEATED", "owner": "pol",
		"subjects": [{"kind": "PARTY", "id": gov["pm_party"]}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 40, "visibility": "PUBLIC", "data": {"bill": bill_id, "yes": yes, "no": no}})
	return bill


static func _queue(world: WorldState, clause: Dictionary, level: String, bill_id: String) -> String:
	var id := world.new_id("enact")
	world.table("enactment")[id] = {"id": id, "lever": clause["lever"], "value": clause["to"], "legal_level": level,
		"source_bill": bill_id, "decided_month": world.month,
		"earliest_effective_month": world.month + IMPLEMENTATION_MONTHS_STUB + int(world.lever_defs[clause["lever"]].get("lag", 0)),
		"status": "PENDING"}
	return id
