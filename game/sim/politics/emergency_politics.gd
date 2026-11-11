class_name EmergencyPolitics
extends RefCounted
## M11 politics side of states of emergency (planning/spec-events-v1.md §4; law side: a9, LawOps/LQ.emergency).
##   - An AI government declares an emergency when a crisis is serious enough for its temperament:
##     order-minded governments (INSTITUTIONS < 0) act sooner, liberty-minded ones (INSTITUTIONS > 0) later.
##   - Parliament votes to approve it within the month, and votes again to renew it every 6 months.
##   - While approved, the government uses the emergency levers that fit the crisis (food: export ban, price
##     control, rationing in a famine). Law reverts them all when the emergency ends.
##   - The government ends it when the crisis has been over for 3 months.
## Stateless; state is law's emergency record plus pol.state["emergency_pol"].

const LawOps := preload("res://sim/law/law_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")

const DECLARE_AT := 60.0          # crisis magnitude at which a neutral government declares
const TEMPERAMENT := 0.25         # magnitude points per INSTITUTIONS point (order declares sooner)
const CALM_MONTHS_TO_END := 3


## The worst crisis of the last 2 months: {type, magnitude, kind} or {}.
static func worst_crisis(world: WorldState) -> Dictionary:
	var best: Dictionary = {}
	for f in world.facts.query("", world.month - 2, world.month):
		var is_crisis: bool = f["type"] == "ECON_FAMINE" or bool(f["data"].get("crisis", false))
		if not is_crisis:
			continue
		var mag := int(f["magnitude"]) + (30 if f["type"] == "ECON_FAMINE" else 0)
		if best.is_empty() or mag > int(best["magnitude"]):
			best = {"type": f["type"], "magnitude": mag, "kind": kind_of(String(f["type"]) + " " + String(f["data"].get("crisis_type", "")))}
	return best


static func kind_of(t: String) -> String:
	for k in ["FAMINE", "FOOD", "DROUGHT", "BLIGHT", "HARVEST", "SHORTAGE"]:
		if t.contains(k):
			return "FOOD"
	for k in ["EPIDEMIC", "CONTAMINATION", "OUTBREAK", "HEALTH"]:
		if t.contains(k):
			return "HEALTH"
	for k in ["POWER", "OUTAGE", "BREAKDOWN", "UTILITY", "WATER"]:
		if t.contains(k):
			return "POWER"
	return "GENERAL"


static func monthly(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st.get("government", {})
	if g.is_empty() or st.get("era", "") != "PARLIAMENTARY":
		return
	if st.get("player_party", "") in g.get("members", []) and not st.get("autoplay_player", true):
		_parliament(world, st)  # a human government declares through the UI; parliament still votes
		return
	var e: Dictionary = LQ.emergency(world)
	var es: Dictionary = st.get("emergency_pol", {})
	if not e["active"]:
		es["calm"] = 0
		var c := worst_crisis(world)
		if not c.is_empty() and e["crisis_active"]:
			var inst := float(g["center"].get("INSTITUTIONS", 0)) / 1000.0
			if float(c["magnitude"]) >= DECLARE_AT + TEMPERAMENT * inst:
				LawOps.declare_emergency(world, c["kind"])
		st["emergency_pol"] = es
		_parliament(world, st)
		return
	# in force: use the levers once approved; end it when the crisis is over
	if e.get("approved", false):
		_apply_levers(world, String(e.get("kind", "GENERAL")), worst_crisis(world))
	es["calm"] = 0 if e["crisis_active"] else int(es.get("calm", 0)) + 1
	st["emergency_pol"] = es
	if int(es["calm"]) >= CALM_MONTHS_TO_END:
		LawOps.end_emergency(world, "ENDED_BY_GOVERNMENT")
		return
	_parliament(world, st)


## Approval (within the month) and renewal (in the last month) votes.
static func _parliament(world: WorldState, st: Dictionary) -> void:
	var e: Dictionary = LQ.emergency(world)
	if not e["active"]:
		return
	if not e.get("approved", false):
		var r := vote(world, st, false)
		LawOps.approve_emergency(world, r["passed"])
	elif int(e.get("until_month", 0)) - world.month <= 1 and e["crisis_active"]:
		var r2 := vote(world, st, true)
		if r2["passed"]:
			LawOps.renew_emergency(world)


## Parliament vote on approving (or renewing) the emergency. Members vote yes; others weigh the severity of the
## crisis against their view of emergency powers (INSTITUTIONS > 0 = civil liberty: wary) and an opposition reflex.
## A renewal is harder: powers that drag on look like a power grab.
static func vote(world: WorldState, st: Dictionary, renewal: bool) -> Dictionary:
	var g: Dictionary = st["government"]
	var c := worst_crisis(world)
	var sev := (float(c.get("magnitude", 40)) - 40.0) / 10.0
	var yes := 0
	var no := 0
	var votes := {}
	var r := world.rng.stream("pol.vote")
	var ids: Array = world.table("party").keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = world.table("party")[pid]
		if p["status"] != "ACTIVE" or int(p["seats"]) == 0:
			continue
		var s := 0.0
		if pid in g["members"]:
			s = 10.0
		else:
			s = sev - float(p["positions"].get("INSTITUTIONS", 0)) / 1000.0 / 15.0 - (2.0 if renewal else 0.0) \
				+ (1.5 if pid in g.get("support", []) else -1.5) + r.randfn(0.0, 1.5)
		var v := "YES" if s > 0.5 else ("NO" if s < -0.5 else "ABSTAIN")
		votes[pid] = v
		if v == "YES":
			yes += int(p["seats"])
		elif v == "NO":
			no += int(p["seats"])
	var passed := yes > no
	world.add_fact({"type": "POL_EMERGENCY_VOTE", "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
		"impact": {}, "magnitude": 45, "visibility": "PUBLIC",
		"data": {"renewal": renewal, "passed": passed, "yes": yes, "no": no, "votes": votes, "kind": LQ.emergency(world).get("kind", "")}})
	return {"passed": passed, "yes": yes, "no": no}


## Emergency measures that fit the crisis. Food: export ban and price control; rationing once there is famine.
static func _apply_levers(world: WorldState, kind: String, c: Dictionary) -> void:
	var want := {}
	if kind == "FOOD":
		want["LAW_FOOD_EXPORT_BAN"] = true
		want["LAW_PRICE_CONTROL"] = "ESSENTIALS"
		if c.get("type", "") == "ECON_FAMINE" or EconUtil.st(world).get("famine", false):
			want["LAW_RATIONING"] = "FOOD"
	elif kind == "POWER":
		want["LAW_RATIONING"] = "FOOD_FUEL"
	elif kind == "HEALTH" or kind == "GENERAL":
		want["LAW_PRICE_CONTROL"] = "ESSENTIALS"
	for lid in want:
		if not world.lever_defs.has(lid) or world.levers.get(lid) == want[lid]:
			continue
		if Legislature._pending_for(world, lid):
			continue
		var eid := Legislature._queue(world, {"lever": lid, "from": world.levers.get(lid), "to": want[lid]}, "REGULATION", "")
		world.table("enactment")[eid]["earliest_effective_month"] = world.month  # emergency measures are immediate
