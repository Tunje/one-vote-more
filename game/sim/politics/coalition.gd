class_name Coalition
extends RefCounted
## Government formation under Swedish-style negative parliamentarism (project §10, DECISIONS A5/A7):
## a proposed PM is approved unless an absolute majority (76) votes AGAINST.

const MAX_PARTIES := 4
const BASE_TOLERANCE := 45.0   # points: outside parties further than this from the government's centre vote NO
const MEMBER_LIMIT := 50.0     # points: a member further than this from the centre refuses to join
const SUPPORT_LIMIT := 30.0
const SEAT_VALUE := 1.0        # score per seat up to a majority (tuning knob; was 0.5)
const MAJORITY_BONUS := 20.0   # extra score for a cabinet with its own majority (tuning knob)
const PARTNER_COST := 4.0      # cohesion cost per extra coalition partner (tuning knob; was 8)    # points: outside parties this close count as "support parties"


static func seat_weighted_center(members: Array, parties: Dictionary) -> Dictionary:
	var c := PolDefs.zero_axes()
	var tot := 0
	for pid in members:
		tot += parties[pid]["seats"]
	for ax in PolDefs.AXES:
		var s := 0.0
		for pid in members:
			s += float(parties[pid]["positions"][ax]) * parties[pid]["seats"]
		c[ax] = int(round(s / maxf(1.0, float(tot))))
	return c


static func _subsets(ids: Array, max_size: int) -> Array:
	var out: Array = []
	var n := ids.size()
	for mask in range(1, 1 << n):
		var s: Array = []
		for i in n:
			if mask & (1 << i):
				s.append(ids[i])
		if s.size() <= max_size:
			out.append(s)
	return out


## Evaluate one candidate cabinet. Returns {} if a member refuses, otherwise vote counts and score.
static func evaluate(members: Array, parties: Dictionary, tolerance: float) -> Dictionary:
	var center := seat_weighted_center(members, parties)
	var spread := 0.0
	for a in members:
		if VoteModel.distance(parties[a]["positions"], center) > MEMBER_LIMIT:
			return {}
		for b in members:
			spread = maxf(spread, VoteModel.distance(parties[a]["positions"], parties[b]["positions"]))
	var yes := 0
	var no := 0
	var near: Array = []  # [distance, pid] of outside parties that could sign a confidence-and-supply deal
	var ids: Array = parties.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = parties[pid]
		if p["seats"] == 0:
			continue
		if pid in members:
			yes += p["seats"]
		else:
			var d := VoteModel.distance(p["positions"], center)
			if d > tolerance:
				no += p["seats"]
			elif d <= SUPPORT_LIMIT:
				near.append([d, pid])
	# Confidence and supply: a minority cabinet signs up only the closest outside parties it NEEDS for a
	# majority; a majority cabinet needs none. (Was: every nearby party listed as "support", owing nothing.)
	near.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var support: Array = []
	var with_support := yes
	for x in near:
		if with_support >= PolDefs.MAJORITY:
			break
		support.append(x[1])
		with_support += int(parties[x[1]]["seats"])
	var largest := ""
	for pid in members:
		if largest == "" or parties[pid]["seats"] > parties[largest]["seats"]:
			largest = pid
	# Prefer minimal-winning or tolerated minority cabinets: surplus seats beyond a majority dilute ministries.
	var plurality := ""
	for pid in parties:
		if plurality == "" or parties[pid]["seats"] > parties[plurality]["seats"]:
			plurality = pid
	# Seats matter (a minority cabinet loses votes and risks no-confidence), a majority is worth a clear bonus,
	# surplus seats dilute ministries, ideological spread and each extra partner cost cohesion.
	var score := float(mini(yes, PolDefs.MAJORITY)) * SEAT_VALUE + (MAJORITY_BONUS if yes >= PolDefs.MAJORITY else 0.0) 		- float(maxi(0, yes - PolDefs.MAJORITY)) * 0.35 - spread * 0.6 - PARTNER_COST * float(members.size() - 1) 		+ (10.0 if plurality in members else 0.0)
	return {"members": members, "pm_party": largest, "center": center, "yes": yes, "no": no, "with_support": with_support,
		"support": support, "spread": int(round(spread)), "score": int(round(score * 100.0)), "majority": yes >= PolDefs.MAJORITY}


## Run up to MAX_FORMATION_ROUNDS speaker rounds. Each failed round, parties grow more tolerant.
## Returns {government: {...} or {}, rounds: int, attempts: [..]}.
## One speaker round (one PM vote). Parties grow more tolerant each failed round. {} if no candidate survives.
static func form_round(parties: Dictionary, round_i: int) -> Dictionary:
	var seated: Array = []
	for pid in parties:
		if parties[pid]["seats"] > 0:
			seated.append(pid)
	seated.sort()
	var tol := BASE_TOLERANCE + 10.0 * round_i
	var best: Dictionary = {}
	for c in _subsets(seated, MAX_PARTIES):
		var e := evaluate(c, parties, tol)
		if e.is_empty() or e["no"] >= PolDefs.MAJORITY:
			continue
		if best.is_empty() or e["score"] > best["score"] or (e["score"] == best["score"] and str(e["members"]) < str(best["members"])):
			best = e
	if not best.is_empty():
		best["agreement"] = agreement(best["members"], parties)
		best["deals"] = deals(best, parties)
	return best


## Each confidence-and-supply party's price: its strongest commitment that the agreement doesn't contradict.
## The government is expected to deliver it within GovCrisis.DEAL_MONTHS or lose that party's support.
static func deals(gov: Dictionary, parties: Dictionary, world: WorldState = null) -> Array:
	var out: Array = []
	var agreed := {}
	for a in gov.get("agreement", []):
		agreed[a["lever"]] = a["dir"]
	for pid in gov.get("support", []):
		var cms: Array = parties[pid]["commitments"].duplicate()
		cms.sort_custom(func(a, b): return (a["kind"] == "CORE" and b["kind"] != "CORE") or (a["kind"] == b["kind"] and (a["weight"] > b["weight"] or (a["weight"] == b["weight"] and a["lever"] < b["lever"]))))
		for cm in cms:
			if agreed.has(cm["lever"]) and agreed[cm["lever"]] != cm["dir"]:
				continue
			if world != null and not feasible(world, cm["lever"], int(cm["dir"])):
				continue  # never demand (or promise) what can't be done: lever at its limit, or unlawful
			out.append({"party": pid, "lever": cm["lever"], "dir": cm["dir"]})
			break
	return out


## All rounds at once (used by tools/tests). The game itself runs one round per month (GovCrisis).
static func form(parties: Dictionary) -> Dictionary:
	for round_i in PolDefs.MAX_FORMATION_ROUNDS:
		var best := form_round(parties, round_i)
		if not best.is_empty():
			return {"government": best, "rounds": round_i + 1}
	return {"government": {}, "rounds": PolDefs.MAX_FORMATION_ROUNDS}


## Governing agreement: lever directions the coalition's seat-weighted commitments agree on,
## where the PM party is not opposed.
static func agreement(members: Array, parties: Dictionary) -> Array:
	var sums := {}
	for pid in members:
		for cm in parties[pid]["commitments"]:
			var w: float = cm["weight"] * (2.0 if cm["kind"] == "CORE" else 1.0) * parties[pid]["seats"]
			sums[cm["lever"]] = sums.get(cm["lever"], 0.0) + w * cm["dir"]
	var out: Array = []
	var keys := sums.keys()
	keys.sort()
	for lid in keys:
		if absf(sums[lid]) >= 1500.0:
			out.append({"lever": lid, "dir": 1 if sums[lid] > 0 else -1})
	return out


## Can this lever still move one step in direction dir? (not at its range limit, and the step is lawful)
static func feasible(world: WorldState, lever: String, dir: int) -> bool:
	if not world.lever_defs.has(lever):
		return false
	var def: Dictionary = world.lever_defs[lever]
	if def["type"] != "NUMBER":
		return true
	var r: Array = Legislature._range(def)
	var cur := float(world.levers.get(lever, def["default"]))
	if (dir > 0 and cur >= float(r[1])) or (dir < 0 and cur <= float(r[0])):
		return false
	var step := maxf(1.0, round(float(r[1] - r[0]) * Legislature.STEP_FRACTION))
	var to := int(clampf(cur + dir * step, float(r[0]), float(r[1])))
	return Legislature.LawOps.check_change(world, lever, to, String(def["legalLevel"])).is_empty()
