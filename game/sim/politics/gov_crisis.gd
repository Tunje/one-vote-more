class_name GovCrisis
extends RefCounted
## M7 government dynamics (project §10.5–10.6, constitutional procedures in law_data.PROCEDURES via LQ):
##   formation   one PM vote per month (negative parliamentarism); 4 failures -> mandatory extra election
##   cohesion    junior partners drift with distance, poll losses and agreement delivery; they can walk out
##   confidence  a hostile majority can topple the government (>= 76 votes against the PM)
##   extra elections  do not reset the ordinary 4-year calendar
## Stateless; state lives in pol.state: formation, cohesion, cohesion_low, extra_election_month, last_no_confidence.

const StaffOps := preload("res://sim/staff/staff_ops.gd")
const LQ := preload("res://sim/law/law_query.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

const START_COHESION := 70
const EXIT_COHESION := 25            # below this for EXIT_MONTHS in a row -> the partner leaves
const EXIT_MONTHS := 3
const QUIET_BEFORE_ELECTION := 6     # no walk-outs or motions this close to an ordinary election
const NC_MIN_MONTHS_IN_OFFICE := 6
const NC_APPROVAL_BELOW := 45000     # opposition only moves a motion when the government is unpopular
const NC_COOLDOWN := 6
const NC_HOSTILITY := 40.0          # points from the government centre that count as hostile
const NC_SYMBOLIC_SEATS := 60        # oppositions also move motions they expect to lose, to embarrass the government
const EXTRA_ELECTION_DELAY := 3
const DEAL_MONTHS := 18              # a confidence-and-supply partner waits this long for its demand


static func _active(world: WorldState) -> Dictionary:
	var out := {}
	for pid in world.table("party"):
		var p: Dictionary = world.table("party")[pid]
		if p["status"] == "ACTIVE":
			out[pid] = p
	return out


# ------------------------------------------------------------------ formation

static func start_formation(world: WorldState, st: Dictionary, reason: String) -> void:
	st["formation"] = {"round": 0, "start": world.month, "reason": reason}
	if not st["government"].is_empty():
		st["caretaker"] = true  # the outgoing government stays on as caretaker


static func formation_step(world: WorldState, st: Dictionary) -> void:
	if not st.has("formation"):
		return
	var f: Dictionary = st["formation"]
	var parties := _active(world)
	var best := _form_respecting(parties, int(f["round"]), f.get("ousted", {}))
	if best.is_empty():
		f["round"] = int(f["round"]) + 1
		world.add_fact({"type": "POL_PM_VOTE_FAILED", "owner": "pol", "subjects": [], "responsible": [],
			"impact": {"GOVERNANCE": -5}, "magnitude": 50, "visibility": "PUBLIC", "data": {"round": f["round"]}})
		if int(f["round"]) >= PolDefs.MAX_FORMATION_ROUNDS:
			st.erase("formation")
			schedule_extra_election(world, st, "CONSTITUTION", true)
			world.add_fact({"type": "POL_FORMATION_FAILED", "owner": "pol", "subjects": [], "responsible": [],
				"impact": {"GOVERNANCE": -20}, "magnitude": 85, "visibility": "PUBLIC",
				"data": {"rounds": PolDefs.MAX_FORMATION_ROUNDS, "extra_election_month": st["extra_election_month"]}})
		return
	var first: bool = st["era"] == "FOUNDING"
	best["formed_month"] = world.month
	best["rounds"] = int(f["round"]) + 1
	best["levers_at_formation"] = world.levers.duplicate()
	best["deals"] = Coalition.deals(best, parties, world)
	for d in best.get("deals", []):
		best["agreement"].append({"lever": d["lever"], "dir": d["dir"], "deal_for": d["party"]})
	best["withdrawn"] = []
	st["government"] = best
	st["caretaker"] = false
	st["era"] = "PARLIAMENTARY"
	st.erase("formation")
	var coh := {}
	for pid in best["members"]:
		if pid != best["pm_party"]:
			coh[pid] = START_COHESION
	st["cohesion"] = coh
	st["cohesion_low"] = {}
	world.add_fact({"type": "POL_GOVERNMENT_FORMED", "owner": "pol",
		"subjects": best["members"].map(func(pid): return {"kind": "PARTY", "id": pid}), "responsible": [],
		"impact": {}, "magnitude": 85, "visibility": "PUBLIC",
		"data": {"members": best["members"], "pm_party": best["pm_party"], "support": best["support"],
			"first_government": first, "reason": f["reason"], "deals": best.get("deals", []), "seats": best["yes"],
			"seats_with_support": best.get("with_support", best["yes"])}})


# ------------------------------------------------------------------ cohesion & partner exit

static func cohesion_step(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st["government"]
	if not g.is_empty() and not st.get("caretaker", false):
		deals_step(world, st)
	if g.is_empty() or st.get("caretaker", false) or g["members"].size() < 2:
		return
	if int(st["next_election"]) - world.month <= QUIET_BEFORE_ELECTION:
		return
	var parties := _active(world)
	var poll: Dictionary = world.peek("poll").get(st.get("last_poll", ""), {}).get("estimates", {})
	var delivered := _agreement_delivery(world, g)
	var coh: Dictionary = st.get("cohesion", {})
	var low: Dictionary = st.get("cohesion_low", {})
	for pid in g["members"].duplicate():
		if pid == g["pm_party"] or not parties.has(pid):
			continue
		var p: Dictionary = parties[pid]
		var dist := VoteModel.distance(p["positions"], g["center"])
		var drop := maxf(0.0, (float(p["support"]) - float(poll.get(pid, p["support"]))) / 1000.0)  # pp lost since election
		var years := float(world.month - int(g["formed_month"])) / 12.0
		var target := clampf(70.0 + 20.0 * delivered - 1.0 * dist - 3.0 * drop - 3.0 * years, 0.0, 100.0)
		coh[pid] = int(round(0.9 * float(coh.get(pid, START_COHESION)) + 0.1 * target))
		low[pid] = int(low.get(pid, 0)) + 1 if coh[pid] < EXIT_COHESION else 0
		if int(low[pid]) >= EXIT_MONTHS:
			partner_exit(world, st, pid)
	st["cohesion"] = coh
	st["cohesion_low"] = low


## Share of the coalition agreement whose levers have moved in the agreed direction since formation.
static func _agreement_delivery(world: WorldState, g: Dictionary) -> float:
	var items: Array = g.get("agreement", [])
	if items.is_empty():
		return 0.5
	var start: Dictionary = g.get("levers_at_formation", {})
	var kept := 0
	for a in items:
		var def: Dictionary = world.lever_defs.get(a["lever"], {})
		var moved := Legislature.ordinal(def, world.levers.get(a["lever"], 0)) - Legislature.ordinal(def, start.get(a["lever"], world.levers.get(a["lever"], 0)))
		if signf(moved) == float(a["dir"]):
			kept += 1
	return float(kept) / float(items.size())


## Confidence-and-supply partners withdraw when their demand has not moved their way after DEAL_MONTHS.
static func deals_step(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st["government"]
	if world.month - int(g.get("formed_month", world.month)) < DEAL_MONTHS:
		return
	var start: Dictionary = g.get("levers_at_formation", {})
	for d in g.get("deals", []):
		var pid: String = d["party"]
		if pid in g.get("withdrawn", []) or not (pid in g.get("support", [])):
			continue
		var def: Dictionary = world.lever_defs.get(d["lever"], {})
		var moved := Legislature.ordinal(def, world.levers.get(d["lever"], 0)) - Legislature.ordinal(def, start.get(d["lever"], world.levers.get(d["lever"], 0)))
		if signf(moved) == float(d["dir"]):
			continue
		g["support"].erase(pid)
		if not g.has("withdrawn"):
			g["withdrawn"] = []
		g["withdrawn"].append(pid)
		world.add_fact({"type": "POL_SUPPORT_WITHDRAWN", "owner": "pol", "subjects": [{"kind": "PARTY", "id": pid}],
			"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
			"impact": {"GOVERNANCE": -4}, "magnitude": 55, "visibility": "PUBLIC",
			"data": {"party": pid, "lever": d["lever"], "dir": d["dir"], "months": world.month - int(g["formed_month"])}})


static func partner_exit(world: WorldState, st: Dictionary, pid: String) -> void:
	var g: Dictionary = st["government"]
	var old: Array = g["members"].duplicate()
	var new_members: Array = old.filter(func(x): return x != pid)
	StaffOps.on_coalition_change(world, old, new_members)
	var parties := _active(world)
	g["members"] = new_members
	g["center"] = Coalition.seat_weighted_center(new_members, parties)
	var yes := 0
	for m in new_members:
		yes += int(parties[m]["seats"])
	g["yes"] = yes
	# existing confidence-and-supply partners stay (minus any that withdrew); the leaver joins the opposition
	g["agreement"] = Coalition.agreement(new_members, parties)
	st.get("cohesion", {}).erase(pid)
	st.get("cohesion_low", {}).erase(pid)
	world.add_fact({"type": "POL_PARTNER_LEFT", "owner": "pol", "subjects": [{"kind": "PARTY", "id": pid}],
		"responsible": [{"actor": {"kind": "PARTY", "id": pid}, "share": 0.5}, {"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 0.5}],
		"impact": {"GOVERNANCE": -8}, "magnitude": 60, "visibility": "PUBLIC",
		"data": {"party": pid, "remaining": new_members, "seats": yes}})


# ------------------------------------------------------------------ no confidence

## Opposition AI: move a motion when a hostile majority exists, the government is unpopular and an alternative exists.
static func no_confidence_ai(world: WorldState, st: Dictionary) -> void:
	var g: Dictionary = st["government"]
	g.erase("nc_alternative")
	if g.is_empty() or st.get("caretaker", false) or st.has("formation"):
		return
	if world.month - int(g["formed_month"]) < NC_MIN_MONTHS_IN_OFFICE or int(st["next_election"]) - world.month <= QUIET_BEFORE_ELECTION:
		return
	if world.month - int(st.get("last_no_confidence", -99)) < NC_COOLDOWN:
		return
	if world.indicators.read("POL_GOV_APPROVAL") >= NC_APPROVAL_BELOW:
		return
	var parties := _active(world)
	var hostile: Array = []
	var seats := 0
	for pid in parties:
		var p: Dictionary = parties[pid]
		if pid in g["members"] or p["seats"] == 0:
			continue
		if p["is_player"] and not st.get("autoplay_player", true):
			continue  # a human opposition decides for itself (PolActions.player_move_no_confidence)
		if VoteModel.distance(p["positions"], g["center"]) > NC_HOSTILITY or pid in g.get("withdrawn", []):
			hostile.append(pid)
			seats += int(p["seats"])
	# A real motion: the government lacks a majority with its partners and the rest of parliament could form
	# another government (100-year chronicles: a 32-seat cabinet survived 1.5 years untested).
	var gov_seats := 0
	for pid in g["members"] + g.get("support", []):
		gov_seats += int(parties.get(pid, {}).get("seats", 0))
	if gov_seats < PolDefs.MAJORITY:
		var others := {}
		for pid in parties:
			if not (pid in g["members"]):
				others[pid] = parties[pid]
		var alt := Coalition.form_round(others, 1)
		if not alt.is_empty() and int(alt.get("with_support", alt["yes"])) >= PolDefs.MAJORITY - 10:
			g["nc_alternative"] = alt["members"]
			for pid in alt["members"] + alt.get("support", []):
				if not (pid in hostile):
					hostile.append(pid)
					seats += int(parties[pid]["seats"])
	if seats < NC_SYMBOLIC_SEATS:
		return
	if seats >= PolDefs.MAJORITY:
		if not g.has("nc_alternative"):
			var alt2 := Coalition.form_round(parties, 0)
			if alt2.is_empty() or alt2["members"] == g["members"]:
				return  # a real motion needs a credible alternative government
	elif world.rng.stream("pol.vote").randf() > 0.15:
		return  # symbolic motions are occasional
	hostile.sort_custom(func(a, b): return parties[a]["seats"] > parties[b]["seats"])
	# v4 review: the same motion was moved again and again with an identical count. An opposition only tries again
	# when something changed: the hostile camp, its seats, or the government's support.
	var key := "%s|%s|%d|%s" % [str(g["formed_month"]), ",".join(PackedStringArray(hostile)), seats, ",".join(PackedStringArray(g.get("withdrawn", [])))]
	if String(st.get("nc_failed_key", "")) == key:
		return
	if not LQ.can_move_no_confidence(world, hostile[0], hostile.slice(1)).get("ok", false):
		return
	var r: Dictionary = vote_no_confidence(world, st, hostile[0])
	if not r.get("passed", false):
		st["nc_failed_key"] = key


## The vote itself (also used by the player). Members never vote against their own government.
static func vote_no_confidence(world: WorldState, st: Dictionary, mover: String) -> Dictionary:
	var g: Dictionary = st["government"]
	var parties := _active(world)
	var rng := world.rng.stream("pol.vote")
	var against := 0
	var hostile: Array = []
	var ids := parties.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = parties[pid]
		if pid in g["members"] or p["seats"] == 0:
			continue
		var d := VoteModel.distance(p["positions"], g["center"]) + rng.randfn(0.0, 5.0)
		var supporter: bool = pid in g.get("support", [])
		var alternative: bool = pid in g.get("nc_alternative", [])
		if pid == mover or alternative or pid in g.get("withdrawn", []) or (not supporter and d > Coalition.BASE_TOLERANCE):
			against += int(p["seats"])
			hostile.append(pid)
	st["last_no_confidence"] = world.month
	var passed := against >= PolDefs.MAJORITY
	world.add_fact({"type": "POL_NO_CONFIDENCE_PASSED" if passed else "POL_NO_CONFIDENCE_FAILED", "owner": "pol",
		"subjects": [{"kind": "PARTY", "id": mover}],
		"responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}] if passed else [{"actor": {"kind": "PARTY", "id": mover}, "share": 1.0}],
		"impact": {"GOVERNANCE": -15} if passed else {}, "magnitude": 85 if passed else 40, "visibility": "PUBLIC",
		"data": {"mover": mover, "against": against}})
	if passed:
		var ousted := {"pm": String(g.get("pm_party", "")), "members": g.get("members", []).duplicate(), "hostile": hostile}
		start_formation(world, st, "NO_CONFIDENCE")
		st["formation"]["ousted"] = ousted   # v6 review: the parties that brought it down don't rebuild it
		formation_step(world, st)
	return {"passed": passed, "against": against}


# ------------------------------------------------------------------ extra elections

## Discretionary extra elections go through the law gate (constitution + rules engine: caretaker ban etc.).
## Mandatory ones (4 failed PM votes) are required by the constitution and always allowed.
static func schedule_extra_election(world: WorldState, st: Dictionary, by: String, mandatory: bool = false) -> Dictionary:
	var chk: Dictionary = LawOps.check_extra_election(world, mandatory)
	if not chk.get("ok", false):
		return {"ok": false, "error": chk.get("reason", "An extra election is not allowed now.")}
	st["extra_election_month"] = world.month + EXTRA_ELECTION_DELAY
	world.add_fact({"type": "POL_EXTRA_ELECTION_CALLED", "owner": "pol", "subjects": [], "responsible": [],
		"impact": {}, "magnitude": 70, "visibility": "PUBLIC", "data": {"by": by, "month": st["extra_election_month"], "mandatory": mandatory}})
	return {"ok": true, "month": st["extra_election_month"]}


## After a successful no-confidence vote, the replacement must respect it (v6 review: 5 of 11 motions were followed
## by the identical cabinet): no party that voted the government down joins a government led by the ousted PM's
## party, and the same PM party with the same members cannot simply re-form. Otherwise the normal search.
static func _form_respecting(parties: Dictionary, round_i: int, ousted: Dictionary) -> Dictionary:
	var best := Coalition.form_round(parties, round_i)
	if ousted.is_empty() or best.is_empty():
		return best
	var pm := String(ousted.get("pm", ""))
	var hostile: Array = ousted.get("hostile", [])
	var same: bool = String(best.get("pm_party", "")) == pm and _same_set(best.get("members", []), ousted.get("members", []))
	var tainted: bool = String(best.get("pm_party", "")) == pm and best.get("members", []).any(func(x): return x in hostile)
	if not same and not tainted:
		return best
	# 1) the ousted PM party may try again, but without the parties that voted it down
	var without_hostile := parties.duplicate()
	for h in hostile:
		without_hostile.erase(h)
	var alt := Coalition.form_round(without_hostile, round_i)
	if not alt.is_empty() and not (String(alt.get("pm_party", "")) == pm and _same_set(alt.get("members", []), ousted.get("members", []))):
		return alt
	# 2) otherwise someone else must lead: the ousted PM party cannot head the next government
	var without_pm := parties.duplicate()
	without_pm.erase(pm)
	return Coalition.form_round(without_pm, round_i)


static func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not (x in b):
			return false
	return true
