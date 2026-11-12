class_name PolActions
extends RefCounted
## Player-facing political actions (the human counterpart of the AI in PoliticsProvider._decisions).
## UI calls these; they return {ok, error?, ...} with player-readable errors. All state is in world tables.
##   player_draft(world, clauses)      -> start staffed drafting of the player's own bill/ordinance
##   player_drafts(world)              -> the player's drafts with status/progress/quality
##   predict_vote(world, clauses, q)   -> expected YES/NO/ABSTAIN per party (negotiation aid)
##   player_submit(world, bill_id)     -> enact a completed draft (ordinance) or put it to a vote (bill)

const StaffOps := preload("res://sim/staff/staff_ops.gd")
const GOV := {"kind": "GOVERNMENT", "id": "government"}


static func _st(world: WorldState) -> Dictionary:
	return world.table("pol")["state"]


## Can the human player legislate right now? Founding era: as commander. Later: if their party governs.
static func player_can_legislate(world: WorldState) -> Dictionary:
	var st := _st(world)
	if st["era"] == "FOUNDING":
		return {"ok": true, "as": "COMMANDER"}
	var g: Dictionary = st["government"]
	if g.is_empty():
		return {"ok": false, "error": "There is no government yet."}
	if st.get("player_party", "") in g["members"]:
		return {"ok": true, "as": "GOVERNMENT"}
	return {"ok": false, "error": "Your party is not in government. Opposition parties cannot table government bills."}


## clauses: [{lever, to}]. Each lever must be a NUMBER lever the player's role may change.
static func player_draft(world: WorldState, clauses: Array) -> Dictionary:
	var can := player_can_legislate(world)
	if not can["ok"]:
		return can
	if clauses.is_empty() or clauses.size() > 4:
		return {"ok": false, "error": "A bill needs 1 to 4 clauses."}
	var full: Array = []
	for c in clauses:
		var def: Dictionary = world.lever_defs.get(c.get("lever", ""), {})
		if def.is_empty():
			return {"ok": false, "error": "Unknown policy: %s" % c.get("lever", "?")}
		if can["as"] == "COMMANDER" and def["foundingEra"] != "COMMANDER":
			return {"ok": false, "error": "%s cannot be changed during the founding era." % c["lever"]}
		var cur = world.levers[c["lever"]]
		var to = c.get("to")
		match def["type"]:
			"NUMBER":
				var r: Array = def.get("range", [0, 100])
				to = clampi(int(to), int(r[0]), int(r[1]))
			"ENUM":
				if not (to in def.get("values", [])):
					return {"ok": false, "error": "%s must be one of %s." % [c["lever"], def.get("values", [])]}
			"BOOL":
				to = bool(to)
		if str(to) == str(cur):
			return {"ok": false, "error": "%s is already %s." % [c["lever"], cur]}
		full.append({"lever": c["lever"], "from": cur, "to": to})
	var bill_id := world.new_id("bill")
	var r2: Dictionary = StaffOps.request_drafting(world, GOV, bill_id, full)
	if not r2.get("ok", false):
		return {"ok": false, "error": "Drafting could not start: %s" % r2.get("error", "no staff available")}
	var st := _st(world)
	if not st.has("player_drafts"):
		st["player_drafts"] = []
	st["player_drafts"].append({"bill": bill_id, "clauses": full, "month": world.month, "era": st["era"], "status": "DRAFTING"})
	return {"ok": true, "bill_id": bill_id}


static func player_drafts(world: WorldState) -> Array:
	var out: Array = []
	for d in world.peek("pol").get("state", {}).get("player_drafts", []):
		var t: Dictionary = StaffOps.draft_for_bill(world, d["bill"])
		var row: Dictionary = d.duplicate(true)
		row["task_status"] = t.get("status", "NONE")
		row["progress"] = t.get("progress", 0)
		row["quality"] = int(t.get("outputs", {}).get("draft_quality", -1))
		row["ready"] = d["status"] == "DRAFTING" and t.get("status", "") == "COMPLETED"
		out.append(row)
	return out


## Expected floor vote without noise: {party_id: "YES"|"NO"|"ABSTAIN"}, plus seat totals.
static func predict_vote(world: WorldState, clauses: Array, draft_quality: int = 50) -> Dictionary:
	var st := _st(world)
	var cs: Array = Intel.picture(world, String(_st(world).get("player_party", "gov"))) if _st(world).get("intel", {}).has(String(_st(world).get("player_party", ""))) else Intel.picture(world, "gov")
	var votes := {}
	var yes := 0
	var no := 0
	for pid in world.peek("party"):
		var p: Dictionary = world.peek("party")[pid]
		if p["seats"] == 0 or p["status"] != "ACTIVE":
			continue
		var v := Legislature.party_vote(p, clauses, world, st["government"], cs[0], cs[1], draft_quality)
		votes[pid] = v
		if v == "YES": yes += p["seats"]
		elif v == "NO": no += p["seats"]
	return {"votes": votes, "yes": yes, "no": no, "passes": yes > no}


static func player_submit(world: WorldState, bill_id: String) -> Dictionary:
	var st := _st(world)
	var d: Dictionary = {}
	for x in st.get("player_drafts", []):
		if x["bill"] == bill_id:
			d = x
	if d.is_empty():
		return {"ok": false, "error": "No such draft."}
	if d["status"] != "DRAFTING":
		return {"ok": false, "error": "This draft was already submitted."}
	if d["era"] != st["era"]:
		d["status"] = "LAPSED"
		return {"ok": false, "error": "The draft lapsed when the founding era ended."}
	var t: Dictionary = StaffOps.draft_for_bill(world, bill_id)
	if t.get("status", "") != "COMPLETED":
		return {"ok": false, "error": "Drafting is not finished yet."}
	var can := player_can_legislate(world)
	if not can["ok"]:
		return can
	var q := int(t.get("outputs", {}).get("draft_quality", 50))
	d["status"] = "SUBMITTED"
	st["last_bill_month"] = world.month
	if can["as"] == "COMMANDER":
		Legislature.issue_ordinance(world, d["clauses"], bill_id)
		return {"ok": true, "result": "ORDINANCE_ISSUED"}
	var cs: Array = Intel.picture(world, String(_st(world).get("player_party", "gov"))) if _st(world).get("intel", {}).has(String(_st(world).get("player_party", ""))) else Intel.picture(world, "gov")
	var bill := Legislature.submit_bill(world, d["clauses"], st["government"], cs[0], cs[1], bill_id, q)
	return {"ok": true, "result": bill["status"], "yes": bill["yes"], "no": bill["no"], "clauses": bill["clauses"]}


# ======================= party platform & agenda (human player) =======================
## The player's party identity: positions move slowly (max PLATFORM_YEARLY_MOVE points per axis per year)
## and every 5 points moved costs 1 credibility (voters dislike flip-flopping).

const PLATFORM_YEARLY_MOVE := 15
const AGENDA_SIZE := 3


static func _player_party(world: WorldState) -> Dictionary:
	var pid: String = _st(world).get("player_party", "")
	return world.table("party").get(pid, {}) if pid != "" else {}


static func player_platform(world: WorldState) -> Dictionary:
	var pid: String = world.peek("pol").get("state", {}).get("player_party", "")
	var p: Dictionary = world.peek("party").get(pid, {})
	if p.is_empty():
		return {"ok": false, "error": "Your party is formed in Year 3."}
	var moved: Dictionary = p.get("platform_moves", {}).get(str(world.year()), {})
	var axes := {}
	for ax in PolDefs.AXES:
		axes[ax] = {"position": int(p["positions"][ax]) / 1000, "left_this_year": PLATFORM_YEARLY_MOVE - int(moved.get(ax, 0))}
	return {"ok": true, "party": pid, "name": p["name"], "axes": axes, "credibility": p["credibility"],
		"agenda": p.get("agenda", []).duplicate(true), "commitments": p["commitments"].duplicate(true),
		"agenda_locked": p.get("agenda_locked", false)}


static func player_shift_platform(world: WorldState, axis: String, delta_points: int) -> Dictionary:
	var p := _player_party(world)
	if p.is_empty():
		return {"ok": false, "error": "Your party is formed in Year 3."}
	if not (axis in PolDefs.AXES) or delta_points == 0:
		return {"ok": false, "error": "Invalid platform change."}
	var y := str(world.year())
	if not p.has("platform_moves"):
		p["platform_moves"] = {}
	var moved: Dictionary = p["platform_moves"].get(y, {})
	var left := PLATFORM_YEARLY_MOVE - int(moved.get(axis, 0))
	if absi(delta_points) > left:
		return {"ok": false, "error": "You can only move %d more points on this axis this year." % left}
	p["positions"][axis] = clampi(int(p["positions"][axis]) + delta_points * 1000, -100000, 100000)
	moved[axis] = int(moved.get(axis, 0)) + absi(delta_points)
	p["platform_moves"][y] = moved
	p["credibility"] = maxi(0, int(p["credibility"]) - int(ceil(absi(delta_points) / 5.0)))
	p["commitments"] = PartyGen.commitments(p["positions"], world.lever_defs)
	p["ownership"] = PartyGen.ownership(p["positions"])
	world.add_fact({"type": "POL_PLATFORM_CHANGED", "owner": "pol", "subjects": [{"kind": "PARTY", "id": p["id"]}],
		"responsible": [{"actor": {"kind": "PARTY", "id": p["id"]}, "share": 1.0}], "impact": {},
		"magnitude": 15 + absi(delta_points), "visibility": "PUBLIC", "data": {"axis": axis, "delta": delta_points}})
	return {"ok": true, "position": int(p["positions"][axis]) / 1000, "credibility": p["credibility"]}


## items: up to 3 {lever, dir: +1|-1}. These are the promises voters will judge you on (credibility at the next election).
static func player_set_agenda(world: WorldState, items: Array) -> Dictionary:
	var p := _player_party(world)
	if p.is_empty():
		return {"ok": false, "error": "Your party is formed in Year 3."}
	if items.size() > AGENDA_SIZE:
		return {"ok": false, "error": "An election agenda has at most %d promises." % AGENDA_SIZE}
	var clean: Array = []
	for it in items:
		if not world.lever_defs.has(it.get("lever", "")) or not (int(it.get("dir", 0)) in [-1, 1]):
			return {"ok": false, "error": "Invalid promise: %s" % [it]}
		clean.append({"lever": it["lever"], "dir": int(it["dir"])})
	p["agenda"] = clean
	p["agenda_locked"] = not clean.is_empty()
	return {"ok": true, "agenda": clean}


# ======================= confidence & extra elections (human player) =======================
const LQ := preload("res://sim/law/law_query.gd")


## Move a no-confidence motion against the government (opposition only). joint: co-sponsoring party ids.
static func player_move_no_confidence(world: WorldState, joint: Array = []) -> Dictionary:
	var st := _st(world)
	var pid: String = st.get("player_party", "")
	if pid == "" or st["government"].is_empty() or pid in st["government"]["members"]:
		return {"ok": false, "error": "Only an opposition party can move a motion of no confidence."}
	if st.get("caretaker", false) or st.has("formation"):
		return {"ok": false, "error": "There is no sitting government to dismiss."}
	var chk: Dictionary = LQ.can_move_no_confidence(world, pid, joint)
	if not chk.get("ok", false):
		return {"ok": false, "error": chk.get("reason", "Not enough members to move the motion.")}
	var r := GovCrisis.vote_no_confidence(world, st, pid)
	return {"ok": true, "passed": r["passed"], "against": r["against"]}


## The PM's party may call an extra election (not within 3 months of an election, not as caretaker).
static func player_call_extra_election(world: WorldState) -> Dictionary:
	var st := _st(world)
	var g: Dictionary = st["government"]
	if g.is_empty() or g.get("pm_party", "") != st.get("player_party", ""):
		return {"ok": false, "error": "Only the prime minister can call an extra election."}
	var chk: Dictionary = LQ.extra_election_allowed(world)
	if not chk.get("ok", false):
		return {"ok": false, "error": chk.get("reason", "An extra election is not allowed now.")}
	if st.has("extra_election_month"):
		return {"ok": false, "error": "An extra election is already scheduled."}
	return GovCrisis.schedule_extra_election(world, st, "PRIME_MINISTER")
