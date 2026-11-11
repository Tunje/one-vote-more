class_name Congress
extends RefCounted
## Party congresses and leadership races (planning/spec-election-year-v1.md §9; owner Ella).
## - Leadership races: PartyLife.leadership_contest delegates non-forced contests here. One candidate per faction
##   (the incumbent defends for theirs), plus an outsider when the party is polling badly; two months of race news,
##   decided by the members' vote at a congress. A snap vote within RACE_SNAP_MONTHS of an election.
## - Per-term congress at T−18: motions nudge the platform toward the members (faction-strength-weighted poles),
##   and the congress adopts the manifesto themes the campaign starts from.
## - The human player's party: a discontented faction tables a motion against the leadership; the player accepts
##   (shift through PolActions, inside the yearly limit) or fights (popularity risk, discontent up).
## Stateless; rows in world.table("party_race") and world.table("congress").

const S := 1000
const RACE_MONTHS := 2
const RACE_SNAP_MONTHS := 4
const CONGRESS_AT_TO_GO := 18
const MOTION_PULL := 0.05            # share of the gap to the members' mean the congress moves the platform
const HOSTILE_MOTION_DISCONTENT := 60
const MOTION_POINTS := 5             # a hostile motion asks for this many points toward the faction's pole
const MOTION_DEADLINE := 2           # months for the player to answer
const OUTSIDER_POLL_DROP := 3000     # polling 3 pp under the last election: an outsider joins the race
const NARROW := 0.10                 # vote-share margin that makes a defeat bitter
const PA := preload("res://sim/politics/pol_actions.gd")


# ======================================================================= leadership races

static func race_of(world: WorldState, pid: String) -> Dictionary:
	var races := world.peek("party_race")
	for rid in Det.ordered(races):
		if races[rid]["party"] == pid and races[rid]["status"] == "OPEN":
			return races[rid]
	return {}


## Called by PartyLife.leadership_contest for non-forced reasons (ELECTION_LOSS, SCANDAL-free challenges).
static func open_race(world: WorldState, st: Dictionary, p: Dictionary, reason: String) -> void:
	if not race_of(world, p["id"]).is_empty():
		return
	PartyLife.ensure_factions(p)
	var inc := int(p["leader"]["faction"])
	var cands: Array = [{"leader": p["leader"].duplicate(), "faction": inc, "incumbent": true, "hustings": 0}]
	cands.append({"leader": PartyLife.make_leader(world, 1 - inc), "faction": 1 - inc, "incumbent": false, "hustings": 0})
	var poll := PartyLife.latest_poll_shares(world)
	var last := int(st.get("last_result", {}).get(p["id"], p["support"]))
	if last - int(poll.get(p["id"], last)) >= OUTSIDER_POLL_DROP:
		var o := PartyLife.make_leader(world, 1 - inc, 15)
		cands.append({"leader": o, "faction": 1 - inc, "incumbent": false, "hustings": 0, "outsider": true})
	var to_go := int(st.get("next_election", world.month + 99)) - world.month
	var rid := world.new_id("party_race")
	var race := {"id": rid, "party": p["id"], "reason": reason, "opened": world.month,
		"decide_month": world.month if to_go <= RACE_SNAP_MONTHS else world.month + RACE_MONTHS,
		"candidates": cands, "status": "OPEN", "result": {}}
	world.table("party_race")[rid] = race
	world.add_fact({"type": "POL_LEADERSHIP_RACE_OPENED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [], "impact": {}, "magnitude": 45, "visibility": "PUBLIC",
		"data": {"party": p["id"], "race": rid, "reason": reason, "candidates": cands.map(func(c): return String(c["leader"]["name"])),
			"snap": int(race["decide_month"]) == world.month, "channel": "PARTY"}})
	if int(race["decide_month"]) == world.month:
		_resolve(world, st, race)


## Hustings: halfway through, each candidate's showing among members (charisma + luck).
static func _hustings(world: WorldState, race: Dictionary) -> void:
	var r := world.rng.stream("pol.congress")
	for c in race["candidates"]:
		c["hustings"] = int(round((float(c["leader"]["charisma"]) - 50.0) / 5.0 + r.randfn(0.0, 4.0)))


## Members' vote: faction strength, candidate traits, the challengers' grievance, the incumbent's machine, luck.
static func _resolve(world: WorldState, st: Dictionary, race: Dictionary) -> void:
	var p: Dictionary = world.table("party").get(race["party"], {})
	race["status"] = "DONE"
	if p.is_empty() or p["status"] != "ACTIVE":
		race["status"] = "MOOT"
		return
	PartyLife.ensure_factions(p)
	var fs: Array = p["factions"]
	var r := world.rng.stream("pol.congress")
	var scores: Array = []
	var tot := 0.0
	for c in race["candidates"]:
		var f: Dictionary = fs[int(c["faction"])]
		var sc := 100.0 * PartyLife.faction_strength(f) + 0.3 * float(c["leader"]["charisma"]) + 0.2 * float(c["leader"]["competence"])
		sc += float(c["hustings"])
		if c["incumbent"]:
			sc += 5.0 + (float(c["leader"]["popularity"]) - 50.0) / 5.0
		else:
			sc += float(f["discontent"]) / 3.0
		sc += r.randfn(0.0, 8.0)
		var w := exp(maxf(-20.0, sc / 12.0))
		scores.append(w)
		tot += w
	var shares: Array = scores.map(func(x): return x / maxf(1e-9, tot))
	var wi := 0
	for i in shares.size():
		if shares[i] > shares[wi]:
			wi = i
	var sorted: Array = shares.duplicate()
	sorted.sort()
	var margin: float = sorted[sorted.size() - 1] - (sorted[sorted.size() - 2] if sorted.size() > 1 else 0.0)
	var narrow := margin < NARROW
	var w: Dictionary = race["candidates"][wi]
	race["result"] = {"winner": String(w["leader"]["name"]), "shares": shares.map(func(x): return int(round(x * 1000.0))), "narrow": narrow}
	var old_name := PartyLife.leader_name(p)
	var inc := int(p["leader"]["faction"])
	if w["incumbent"]:
		var ch := 1 - inc
		fs[ch]["discontent"] = mini(100, int(fs[ch]["discontent"]) + 10 + (5 if narrow else 0))  # lost again: bitterness
		world.add_fact({"type": "POL_LEADER_SURVIVED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
			"responsible": [], "impact": {}, "magnitude": 40, "visibility": "PUBLIC",
			"data": {"party": p["id"], "leader": old_name, "reason": race["reason"], "race": race["id"], "share": int(round(shares[wi] * 100.0)), "narrow": narrow}})
		return
	var nl: Dictionary = w["leader"].duplicate()
	nl["since"] = world.month
	nl["faction"] = int(w["faction"])
	p["leader"] = nl
	var ax: String = p["faction_axis"]
	var pole: int = fs[int(w["faction"])]["pole"]
	p["positions"][ax] += int(round(float(pole - int(p["positions"][ax])) * PartyLife.LEADER_PLATFORM_PULL))
	fs[int(w["faction"])]["discontent"] = 20
	var loser := 1 - int(w["faction"])
	fs[loser]["discontent"] = mini(100, int(fs[loser]["discontent"]) + 15 + (5 if narrow else 0))
	p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)
	world.add_fact({"type": "POL_LEADER_CHANGED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [], "impact": {}, "magnitude": 55, "visibility": "PUBLIC",
		"data": {"party": p["id"], "old": old_name, "new": nl["name"], "reason": race["reason"], "faction": int(w["faction"]),
			"race": race["id"], "share": int(round(shares[wi] * 100.0)), "narrow": narrow, "outsider": bool(w.get("outsider", false))}})


# ======================================================================= congresses

## Monthly (from PoliticsProvider._party_life_monthly): race hustings and votes, per-term congresses, motions.
static func monthly(world: WorldState, st: Dictionary) -> void:
	var races := world.table("party_race")
	for rid in Det.ordered(races):
		var race: Dictionary = races[rid]
		if race["status"] != "OPEN":
			continue
		if world.month == int(race["opened"]) + 1 and world.month < int(race["decide_month"]):
			_hustings(world, race)
		if world.month >= int(race["decide_month"]):
			_resolve(world, st, race)
	_motions_due(world, st)
	var to_go := int(st.get("next_election", -1)) - world.month
	if to_go != CONGRESS_AT_TO_GO:
		return
	for p in PartyLife.active(world):
		if not race_of(world, p["id"]).is_empty():
			continue   # this party's congress is the race vote
		hold_congress(world, st, p)


static func latest(world: WorldState, pid: String) -> Dictionary:
	var out := {}
	var cg := world.peek("congress")
	for cid in Det.ordered(cg):
		if cg[cid]["party"] == pid:
			out = cg[cid]
	return out


## The members' platform: faction poles weighted by faction strength, on the faction axis.
static func members_mean(p: Dictionary) -> int:
	PartyLife.ensure_factions(p)
	var fs: Array = p["factions"]
	var w0 := PartyLife.faction_strength(fs[0])
	var w1 := PartyLife.faction_strength(fs[1])
	return int(round((float(fs[0]["pole"]) * w0 + float(fs[1]["pole"]) * w1) / maxf(0.001, w0 + w1)))


static func hold_congress(world: WorldState, st: Dictionary, p: Dictionary) -> Dictionary:
	PartyLife.ensure_factions(p)
	var ax: String = p["faction_axis"]
	var human: bool = bool(p.get("is_player", false)) and not bool(st.get("autoplay_player", true))
	var cid := world.new_id("congress")
	var themes := Campaign.pick_themes(world, st, p, Campaign.segments(world))
	var row := {"id": cid, "party": p["id"], "month": world.month, "axis": ax, "shift": 0, "themes": themes, "motion": {}}
	if not human:
		var target := members_mean(p)
		var d := int(round(float(target - int(p["positions"][ax])) * MOTION_PULL))
		p["positions"][ax] = clampi(int(p["positions"][ax]) + d, -100 * S, 100 * S)
		p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)
		row["shift"] = d
	# a discontented faction tables a motion against the leadership
	var fs: Array = p["factions"]
	var rebel := -1
	for i in 2:
		if i != int(p["leader"]["faction"]) and int(fs[i]["discontent"]) >= HOSTILE_MOTION_DISCONTENT:
			rebel = i
	if rebel >= 0:
		var dir := signi(int(fs[rebel]["pole"]) - int(p["positions"][ax]))
		if dir != 0:
			row["motion"] = {"faction": rebel, "axis": ax, "points": MOTION_POINTS * dir, "status": "PENDING",
				"deadline": world.month + MOTION_DEADLINE}
			if not human:
				_decide_motion_ai(world, p, row)
	world.table("congress")[cid] = row
	world.add_fact({"type": "POL_CONGRESS_HELD", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [], "impact": {}, "magnitude": 35 if row["motion"].is_empty() else 45, "visibility": "PUBLIC",
		"data": {"party": p["id"], "congress": cid, "axis": ax, "shift": row["shift"], "themes": themes,
			"motion": String(row["motion"].get("status", "")), "channel": "PARTY"}})
	return row


## AI leaderships give in to a strong rebellion and fight a weaker one.
static func _decide_motion_ai(world: WorldState, p: Dictionary, row: Dictionary) -> void:
	var f: Dictionary = p["factions"][int(row["motion"]["faction"])]
	_apply_motion(world, p, row, "ACCEPT" if int(f["discontent"]) >= 75 else "FIGHT")


static func _apply_motion(world: WorldState, p: Dictionary, row: Dictionary, choice: String) -> Dictionary:
	var m: Dictionary = row["motion"]
	var f: Dictionary = p["factions"][int(m["faction"])]
	var human: bool = bool(p.get("is_player", false)) and not bool(world.peek("pol").get("state", {}).get("autoplay_player", true))
	if choice == "ACCEPT":
		if human:
			var left := int(PA.player_platform(world)["axes"][m["axis"]]["left_this_year"])
			var pts := signi(int(m["points"])) * mini(absi(int(m["points"])), left)
			if pts != 0:
				var res: Dictionary = PA.player_shift_platform(world, m["axis"], pts)
				if not res.get("ok", false):
					return res
			m["moved"] = pts
		else:
			p["positions"][m["axis"]] = clampi(int(p["positions"][m["axis"]]) + int(m["points"]) * S, -100 * S, 100 * S)
			p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)
			m["moved"] = int(m["points"])
		f["discontent"] = maxi(0, int(f["discontent"]) - 20)
		m["status"] = "ACCEPTED"
	else:
		f["discontent"] = mini(100, int(f["discontent"]) + 10)
		var l: Dictionary = p["leader"]
		l["popularity"] = clampi(int(l["popularity"]) - 5, 0, 100)
		m["status"] = "DEFEATED"
	world.add_fact({"type": "POL_CONGRESS_MOTION", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [], "impact": {}, "magnitude": 40, "visibility": "PUBLIC",
		"data": {"party": p["id"], "congress": row["id"], "axis": m["axis"], "points": int(m.get("moved", m["points"])),
			"outcome": m["status"], "channel": "PARTY"}})
	return {"ok": true}


## The human player's answer to a pending motion (ACCEPT / FIGHT).
static func player_answer_motion(world: WorldState, choice: String) -> Dictionary:
	var st: Dictionary = world.table("pol")["state"]
	var pp := String(st.get("player_party", ""))
	var row := latest(world, pp)
	if row.is_empty() or row["motion"].get("status", "") != "PENDING":
		return {"ok": false, "error": "No motion is waiting for your answer."}
	if not (choice in ["ACCEPT", "FIGHT"]):
		return {"ok": false, "error": "Accept or fight."}
	return _apply_motion(world, world.table("party")[pp], world.table("congress")[row["id"]], choice)


## Unanswered motions: when the deadline passes, the party staff accept them (the members get their way).
static func _motions_due(world: WorldState, st: Dictionary) -> void:
	var cg := world.table("congress")
	for cid in Det.ordered(cg):
		var row: Dictionary = cg[cid]
		var m: Dictionary = row.get("motion", {})
		if m.get("status", "") == "PENDING" and world.month >= int(m["deadline"]):
			var p: Dictionary = world.table("party").get(row["party"], {})
			if p.is_empty() or p["status"] != "ACTIVE":
				m["status"] = "MOOT"
				continue
			_apply_motion(world, p, row, "ACCEPT")


const Det := preload("res://sim/staff/det.gd")
