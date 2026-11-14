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
## belief (A49 K2): the actor's belief in the lever's effect hints (1.0 = the hints); the budget sign is not scaled.
static func relief(def: Dictionary, delta: float, sat: Dictionary, sal: Dictionary, stress: float = 0.0, room: float = 0.0, cur: float = 0.0, belief: float = 1.0) -> float:
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
		s += w * frac * unmet * sl / 100.0 * belief
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
			s += float(hi["concerns"][c]) * frac_hi * maxf(unmet_h, 0.5) * float(sal.get(c, 111)) / 100.0 * HIGH_HARM_WEIGHT * belief
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
			s += float(lw["concerns"][c]) * frac_lo * maxf(unmet_l, 0.5) * float(sal.get(c, 111)) / 100.0 * HIGH_HARM_WEIGHT * belief
	return s


## Fiscal stress 0..1 = worst badness over indicators that declare `fiscalStress {good, bad}` (pic-core §3 v1.2).
## Read from current (official) values: the government sees its own books before voters do.
static func in_default(world: WorldState) -> bool:
	return world.table("econ").has("s") and bool(EconUtil.peek_st(world).get("sovereign_default", false))


static func fiscal_stress(world: WorldState) -> float:
	if in_default(world):
		return 1.0   # a defaulting state is under full stress whatever the runway reads
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
	if in_default(world):
		return true
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


## The long-term case for immigration (0..2), which the short-term hints (jobs, housing) don't carry: more open jobs
## than jobless people, and an ageing population (people 60+ against working age 20–59). v6: every colony closed its
## borders for good; a government should see when reopening pays.
static func _labour_need(world: WorldState) -> float:
	if not world.table("econ").has("s"):
		return 0.0
	var k: Dictionary = EconTraining.summary(world)
	var vac := float(k.get("vacancies_G", 0)) + float(k.get("vacancies_S", 0)) + float(k.get("vacancies_Sp", 0))
	var une := float(k.get("unemployed_G", 0)) + float(k.get("unemployed_S", 0)) + float(k.get("unemployed_Sp", 0))
	var shortage := maxf(0.0, vac - une) / 60.0
	var pyr: Array = EconQuery.demography(world).get("pop_by_band", [])
	var old := 0.0
	var work := 0.0
	for i in pyr.size():
		if i >= 12:
			old += float(pyr[i])
		elif i >= 4:
			work += float(pyr[i])
	var ageing := maxf(0.0, old / maxf(1.0, work) - 0.35) * 4.0
	return clampf(shortage + ageing, 0.0, 2.0)


## Unemployment 15%+ as a counter-cyclical case (0..2): at 15% nothing, at 25% 1.0, at 35%+ 2.0 (colony rate, a public
## statistic, not a picture). v7 review (Bob, seed 1 Y31–35): a government under fiscal stress cut public works and
## public jobs to zero while unemployment sat at ~50%. In a slump the job levers carry their own case, and from 20%
## the fiscal guard no longer blocks them (the guard is for new spending in good times, not for a depression).
const COUNTER_CYCLICAL := ["ECON_BUDGET_PUBLIC_EMPLOYMENT", "ECON_BUDGET_PUBLIC_WORKS"]
const SLUMP_FROM := 15.0
const SLUMP_GUARD_OFF := 20.0
const SLUMP_PENALTY := 8.0   # score cost of a pro-cyclical move in a deep slump (a strong case, not a ban)


static func unemployment(world: WorldState) -> float:
	# the colony-wide rate (Bob's EconQuery.labour), not the worst district (fixed 2026-11-13)
	if world.meta.has("test_unemployment"):
		return float(world.meta["test_unemployment"])   # test seam
	if world.table("econ").has("s"):
		return float(EconQuery.labour(world).get("rate_pct", 0.0))
	var id := "ECON_UNEMPLOYMENT_RATE"
	if not world.indicators.values.has(id):
		return 0.0
	var v: Dictionary = world.indicators.values[id]
	if v.has("COLONY"):
		return float(v["COLONY"]) / 1000.0
	var u := 0.0
	for k in EconUtil.sorted_keys(v):
		u = maxf(u, float(v[k]) / 1000.0)
	return u


static func _runway(world: WorldState) -> float:
	var id := "ECON_TREASURY_RUNWAY"
	if not world.indicators.values.has(id) or not world.indicators.values[id].has("COLONY"):
		return 99.0
	return float(world.indicators.read(id, "COLONY")) / 1000.0


## A58 lobbying (Anni's CL.open_asks): a party that took money from an org leans toward granting its asks. Bigger for
## more money and a less honest leader, smaller when lobbying must be registered or disclosed (a disclosed favour is
## riskier). Score points for moving `lid` in direction `dir`; asks against the move count negative. Capped.
const LOBBY_K := 2.0
const LOBBY_CAP := 4.0
const CL := preload("res://sim/law/competition_law.gd")


static func lobby_tilt(world: WorldState, party: Dictionary, lid: String, dir: float) -> float:
	if party.is_empty() or not world.peek("lobby") is Dictionary or world.peek("lobby").is_empty():
		return 0.0
	var integrity := float(party.get("leader", {}).get("integrity", 55)) if typeof(party.get("leader")) == TYPE_DICTIONARY else 55.0
	var mode := float(int(world.levers.get("LAW_LOBBY_REGISTER", 0)))
	var wref := float(maxi(1, int(world.values.get("ECON_W_REF", 1200000))))
	var t := 0.0
	for a in CL.open_asks(world, String(party.get("id", ""))):
		var req: Dictionary = a.get("request", {})
		if String(req.get("lever", "")) != lid:
			continue
		var w := LOBBY_K * float(a.get("donated_24m", 0)) / wref * (1.0 - integrity / 100.0) * (1.0 - 0.3 * mode)
		t += w if signf(float(req.get("dir", 0))) == signf(dir) else -w
	return clampf(t, -LOBBY_CAP, LOBBY_CAP)


static func _slump(world: WorldState) -> float:
	return clampf((unemployment(world) - SLUMP_FROM) / 10.0, 0.0, 2.0)


## Hunger amid plenty (Bob, v7 follow-up): households priced out of food while governments cut food assistance and
## the benefit floor. Share of household food need unmet (econ food_shortfall, milli). From 10% the support levers
## gain a case; from 15% they are protected like the jobs levers in a deep slump.
const HUNGER_LEVERS := ["ECON_FOOD_ASSISTANCE", "ECON_BENEFIT_FLOOR"]
const HUNGER_FROM := 0.10
const HUNGER_DEEP := 0.15


static func hunger(world: WorldState) -> float:
	if not world.table("econ").has("s"):
		return 0.0
	return float(EconUtil.peek_st(world).get("food_shortfall", 0)) / 1000.0


## Per protected lever: [strength 0..2, deep]. Deep = no cuts, past the fiscal guard, judged without fiscal stress.
static func protected_levers(world: WorldState) -> Dictionary:
	var out := {}
	if in_default(world):
		# a bankrupt state cannot fund job schemes: only food aid keeps a (non-deep) case, so it is cut last
		var h0 := hunger(world)
		if h0 >= HUNGER_FROM:
			out["ECON_FOOD_ASSISTANCE"] = [clampf((h0 - HUNGER_FROM) / 0.10, 0.0, 2.0), false]
		return out
	var u := unemployment(world)
	var sl := _slump(world)
	if sl > 0.0:
		for lid in COUNTER_CYCLICAL:
			out[lid] = [sl, u >= SLUMP_GUARD_OFF]
	var h := hunger(world)
	var hs := clampf((h - HUNGER_FROM) / 0.10, 0.0, 2.0)
	if hs > 0.0:
		for lid in HUNGER_LEVERS:
			out[lid] = [hs, h >= HUNGER_DEEP]
	# S7 (Bob's seed-4 probes, 2026-11-14): the hunger guard came too late. While food assistance works there is no
	# shortfall, so governments cut it and the shortfall followed (135-192 permille). Judge the cut by what it would do:
	# the share of the colony's food bill that assistance pays now (food_assist_pm), or households already priced out.
	var dep := maxf(food_dependence(world), food_unaffordable(world))
	var ds := clampf((dep - FOOD_DEP_FROM) / 0.05, 0.0, 2.0)
	if ds > 0.0:
		var cur: Array = out.get("ECON_FOOD_ASSISTANCE", [0.0, false])
		out["ECON_FOOD_ASSISTANCE"] = [maxf(float(cur[0]), ds), bool(cur[1]) or dep >= FOOD_DEP_DEEP]
	return out


## S7: share of the colony's food bill paid by food assistance (Bob's stat, permille), and the unaffordable share.
const FOOD_DEP_FROM := 0.03
const FOOD_DEP_DEEP := 0.08


static func food_dependence(world: WorldState) -> float:
	if not world.table("econ").has("s"):
		return 0.0
	return float(EconUtil.peek_st(world).get("food_assist_pm", 0)) / 1000.0


static func food_unaffordable(world: WorldState) -> float:
	if not world.table("econ").has("s"):
		return 0.0
	return float(EconUtil.peek_st(world).get("food_unaff", 0)) / 1000.0


## pork (0..1, election year; Ella/Campaign.pork_pressure): crowd-pleasing relief counts more, ideology less.
## stats (optional, written by the caller's state): {"guard_blocked": n} clauses the fiscal guard kept out.
static func propose(world: WorldState, pos: Dictionary, sat: Dictionary, sal: Dictionary, agreement: Array, allowed: String, stress: float = 0.0, crisis: bool = false, exclude: Dictionary = {}, pork: float = 0.0, stats: Dictionary = {}) -> Array:
	var scored: Array = []
	var guarded := fiscal_guard(world)
	var room := fiscal_room(world)
	var step_fraction := CRISIS_STEP_FRACTION if crisis else STEP_FRACTION
	var mem := _bill_memory(world) if allowed == "PARLIAMENT" else {"defeated": {}, "moved": {}}
	var skill_gap := _skill_gap(world) if allowed == "PARLIAMENT" else 0.0
	var believer := String(world.peek("pol").get("state", {}).get("government", {}).get("pm_party", "")) if allowed == "PARLIAMENT" else ""
	var labour_need := _labour_need(world) if allowed == "PARLIAMENT" else 0.0
	var protect := protected_levers(world) if allowed == "PARLIAMENT" else {}
	var tinker := TINKER_COST * Learn.mult(world.peek("party").get(believer, {}), "G_PACE", -0.6)   # A53: legislative pace
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
			var slump_lever: bool = protect.has(lid)
			var deep: bool = slump_lever and bool(protect[lid][1])
			# A55 (v7 follow-up): no tax rises in a deep slump while the treasury still holds 3+ months of spending; a
			# slump is fought with demand (a market Cabinet cuts taxes, a state Cabinet spends), not with austerity.
			# User (2026-11-13): governments must stay free to make things worse. These are strong pressures, not bans:
			# an austerity-minded government can still raise taxes or cut the schemes in a slump if its convictions
			# outweigh the cost.
			var against_slump := 0.0
			# only above the lever's normal level: restoring a tax cut back toward its default is never penalised
			# (fixed: the penalty ratcheted taxes to 0 in long slumps)
			if bool(def.get("is_tax", false)) and delta > 0.0 and cur >= float(def.get("default", 0)) 					and unemployment(world) >= SLUMP_GUARD_OFF and _runway(world) >= 3.0 and not in_default(world):
				against_slump += SLUMP_PENALTY   # raising taxes in a slump while holding reserves
			if deep and delta < 0.0:
				against_slump += SLUMP_PENALTY   # cutting the jobs schemes / food help in a deep slump or hunger
			if guarded and not owes and float(def.get("concerns", {}).get("GOVERNANCE", 0)) * delta < 0.0 and not deep:
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
			# in a deep slump (20%+) the jobs levers are judged as jobs, not as budget repair (no fiscal-stress weight)
			var rl := relief(def, delta, sat, sal, 0.0 if deep else stress, room, cur, Intel.belief(world, believer, lid) if believer != "" else 1.0)
			# Conviction: a government believes its own remedies work. Relief from a change that goes against its
			# ideology is discounted (a market government does not see a jobs scheme as the cure, a left one does not
			# see benefit cuts as one), so parties answer the same crisis differently. Not under fiscal stress:
			# budget repair is shared ground.
			if ia < 0.0 and rl > 0.0 and stress <= 0.0:
				rl /= 1.0 + absf(ia) / 2.0
			var sc := (1.0 - 0.3 * pork) * ia + 3.0 * (1.0 + 0.5 * pork) * rl
			if labour_need > 0.0 and lid == "LAW_IMMIGRATION":
				sc += labour_need * signf(delta)   # v6 review: an ageing colony with unfilled jobs needs newcomers
			sc -= against_slump
			sc += lobby_tilt(world, world.peek("party").get(believer, {}), lid, delta)   # A58: the donors' asks
			if slump_lever:
				sc += 4.0 * float(protect[lid][0]) * signf(delta)   # v7 review: jobs in a slump, food aid in hunger; cuts are costly
			if skill_gap > 0.0 and delta > 0.0 and lid in TRAINING_LEVERS:
				sc += skill_gap  # E114: firms cannot fill skilled posts; training money and the subsidy go together
			# v5 review (433 bills in one run): no endless tinkering. Moving the same lever again the same way within
			# the government's memory needs a stronger case, unless it is the programme (agreement) or an owed price.
			var programme := false
			for a in agreement:
				if a["lever"] == lid and signf(delta) == a["dir"]:
					programme = true
			if mem["moved"].has(dk) and not programme and not owes:
				sc -= tinker
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
	var protect := protected_levers(world)
	for c in clauses:
		var def: Dictionary = world.lever_defs[c["lever"]]
		var delta := clause_delta(def, c)
		var stress_c := 0.0 if protect.has(String(c["lever"])) and bool(protect[String(c["lever"])][1]) else fiscal_stress(world)   # v7: jobs judged as jobs
		s += lobby_tilt(world, party, String(c["lever"]), delta)   # A58
		s += IDEOLOGY_VOTE_WEIGHT * ideo_alignment(def, delta, party["positions"]) + 1.5 * relief(def, delta, sat, sal, stress_c, fiscal_room(world), ordinal(def, c["from"]), Intel.belief(world, String(party.get("id", "")), String(c["lever"])))
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
		var pic: Array = Intel.picture(world, pid) if world.peek("pol").get("state", {}).get("intel", {}).has(pid) else [sat, sal]
		var v := party_vote(p, clauses, world, gov, pic[0], pic[1], draft_quality, noise)
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
