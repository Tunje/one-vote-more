extends RefCounted
## Opposition actions (M7 groundwork): oversight inquiries and legal challenges, for AI parties and the player.
## Everything a party decides on is computed from what IT can see (Vis with its own viewer): no secrets.
##
##   options(world, pid)  pure: what the party could do now, with expected yields / win estimates (UI + AI)
##   run_ai(world)        AI opposition parties start at most one inquiry and one challenge at a time
##
## Results reach politics as facts: an inquiry's findings -> PUBLIC STAFF_OVERSIGHT_REPORT (GOVERNMENT blame) plus
## any *_REVEALED secrets; a challenge -> court case -> LAW_RULING (against the government when won).

const Ops := preload("res://sim/staff/staff_ops.gd")
const Vis := preload("res://sim/law/visibility.gd")
const Det := preload("res://sim/staff/det.gd")
const LawOps := preload("res://sim/law/law_ops.gd")

const DOMAINS := {
	"LAW": {"prefixes": ["LAW_"], "label": "Justice & legality"},
	"STAFF": {"prefixes": ["STAFF_"], "label": "Government administration"},
	"ECON": {"prefixes": ["ECON_"], "label": "Public finances & contracts"},
	"COMP": {"prefixes": ["COMP_"], "label": "Industry & workplace safety"},
}
const LOOKBACK := 24
const RECENT_INQUIRY := 12
const AI_OVERSIGHT_MIN_YIELD := 2.0
const AI_CHALLENGE_MIN_P := 0.5
const P_REVEALED := 0.95       # revealed unlawful act: the government's own record is in evidence
const P_DECREE := 0.85         # decree visibly beyond delegated powers
const P_HUNCH := 0.15          # lawful decree challenged for political reasons


static func _viewer(pid: String) -> Dictionary:
	return {"party_id": pid}


static func _gov_negative(f: Dictionary) -> bool:
	var gov := false
	for r in f.get("responsible", []):
		if r["actor"].get("kind", "") in ["GOVERNMENT", "COMMANDER", "AUTHORITY"]:
			gov = true
	if not gov:
		return false
	for c in f.get("impact", {}):
		if int(f["impact"][c]) < 0:
			return true
	return false


## Decrees (REGULATION/ADMIN enactments) that change a LAW/CHARTER-level lever without a public delegation.
## Laws and delegations are public, so any party can spot these.
static func suspicious_decrees(world: WorldState) -> Array:
	var out: Array = []
	var rows := world.peek("enactment")
	for eid in Det.ordered(rows):
		var e: Dictionary = rows[eid]
		if not e["legal_level"] in ["ADMIN", "REGULATION"] or e["status"] in ["REJECTED", "CANCELLED", "PENDING"]:
			continue
		var lvl := String(world.lever_defs.get(e["lever"], {}).get("legalLevel", ""))
		if lvl in ["LAW", "CHARTER"] and not LawOps._delegated(world, e["lever"], e["value"], "REGULATION"):
			out.append(eid)
	return out


static func _challenged(world: WorldState, key: String, value: String) -> bool:
	for c in world.peek("case").values():
		if String(c["data"].get(key, "")) == value:
			return true
	var param := "target_fact" if key == "unlawful_fact" else "target_enactment"
	for t in world.peek("task").values():
		if t["def_id"] == "STAFF_T_LEGAL_CHALLENGE" and t["status"] == "ACTIVE" and String(t["params"].get(param, "")) == value:
			return true
	return false


static func _recent_inquiry(world: WorldState, pid: String, domain: String) -> bool:
	for t in world.peek("task").values():
		if t["def_id"] != "STAFF_T_OVERSIGHT" or t["owner"].get("id", "") != pid or t["params"].get("domain", "") != domain:
			continue
		if t["status"] == "ACTIVE" or (t["status"] == "COMPLETED" and world.month - int(t["completed_month"]) < RECENT_INQUIRY):
			return true
	return false


## What the party could do now (pure). Returns
## {role, pool: {size, free, qualified_investigator, qualified_counsel}, oversight: [...], challenges: [...], running: [...]}
static func options(world: WorldState, pid: String) -> Dictionary:
	var viewer := _viewer(pid)
	var owner := {"kind": "PARTY", "id": pid}
	var free := Ops.available(world, owner)
	var inv := false
	var counsel := false
	for p in free:
		var sk: Dictionary = Ops.person(world, p)["skills"]
		inv = inv or int(sk["LAW"]) >= 45 or int(sk["ADMIN"]) >= 55
		counsel = counsel or int(sk["LAW"]) >= 45
	# --- oversight yields from visible signals
	var party: Dictionary = world.peek("party").get(pid, {})
	var owned := {}
	for c in party.get("commitments", []):
		owned[String(world.lever_defs.get(c["lever"], {}).get("owner", "")).to_upper()] = true
	var susp := suspicious_decrees(world)
	var stale := 0
	for e in world.peek("enactment").values():
		if e["status"] == "LEGAL" and world.month - int(e.get("legal_month", world.month)) > 6:
			stale += 1
	var oversight: Array = []
	for d in DOMAINS:
		var reasons: Array = []
		var y := 0.0
		var neg := 0
		for f in Vis.filter_facts(world, viewer, world.facts.query(DOMAINS[d]["prefixes"][0], world.month - LOOKBACK, world.month)):
			if f["visibility"] == "PUBLIC" and _gov_negative(f):
				neg += 1
		if neg > 0:
			y += minf(3.0, 0.5 * float(neg))
			reasons.append("%d public failures attributed to the government" % neg)
		if d == "LAW" and not susp.is_empty():
			y += 2.0 * float(susp.size())
			reasons.append("%d decree(s) that appear to exceed the government's powers" % susp.size())
		if d == "STAFF" and stale > 0:
			y += float(stale)
			reasons.append("%d enacted change(s) still not implemented after 6 months" % stale)
		if owned.has(d):
			y += 1.0
			reasons.append("touches the party's own commitments")
		var recent := _recent_inquiry(world, pid, d)
		if recent:
			y *= 0.25
			reasons.append("recently investigated")
		oversight.append({"domain": d, "label": DOMAINS[d]["label"], "prefixes": DOMAINS[d]["prefixes"],
			"expected_yield": snappedf(y, 0.01), "reasons": reasons, "recent": recent})
	oversight.sort_custom(func(a, b): return a["expected_yield"] > b["expected_yield"])
	# --- challenge targets
	var challenges: Array = []
	for f in Vis.filter_facts(world, viewer, world.facts.query("LAW_UNLAWFUL_GOV_ACTION_REVEALED", -1, world.month)):
		var orig: String = f["causes"][0] if not f["causes"].is_empty() else ""
		if orig == "" or _challenged(world, "unlawful_fact", orig):
			continue
		var grievance := false
		for s in f["subjects"]:
			if s.get("kind", "") == "PARTY" and s.get("id", "") == pid:
				grievance = true
		challenges.append({"kind": "REVEALED_UNLAWFUL", "target_fact": orig, "target_enactment": "", "p_win_est": P_REVEALED,
			"grievance": grievance, "label": "Challenge the unlawful government act revealed in month %d" % int(f["month"])})
	for eid in susp:
		if _challenged(world, "enactment", eid):
			continue
		var e: Dictionary = world.peek("enactment")[eid]
		challenges.append({"kind": "DECREE_ULTRA_VIRES", "target_fact": "", "target_enactment": eid, "p_win_est": P_DECREE,
			"grievance": false, "label": "Challenge the decree on %s: only parliament may set it" % e["lever"]})
	for c in party.get("commitments", []):
		for eid in Det.ordered(world.peek("enactment")):
			var e: Dictionary = world.peek("enactment")[eid]
			if e["lever"] != c["lever"] or not e["legal_level"] in ["ADMIN", "REGULATION"] or susp.has(eid) \
					or e["status"] in ["REJECTED", "CANCELLED"] or _challenged(world, "enactment", eid):
				continue
			var from_v = e.get("from")
			var dir := 0
			if from_v is int or from_v is float:
				dir = 1 if float(e["value"]) > float(from_v) else -1
			if dir != 0 and dir == -int(c["dir"]):
				challenges.append({"kind": "POLITICAL_HUNCH", "target_fact": "", "target_enactment": eid, "p_win_est": P_HUNCH,
					"grievance": false, "label": "Challenge the decree on %s (lawful on its face; weak case)" % e["lever"]})
	challenges.sort_custom(func(a, b):
		if a["grievance"] != b["grievance"]:
			return a["grievance"]
		return a["p_win_est"] > b["p_win_est"])
	var running: Array = []
	for tid in Det.ordered(world.peek("task")):
		var t: Dictionary = world.peek("task")[tid]
		if t["status"] == "ACTIVE" and t["owner"].get("id", "") == pid and t["def_id"] in ["STAFF_T_OVERSIGHT", "STAFF_T_LEGAL_CHALLENGE"]:
			running.append({"task_id": tid, "def_id": t["def_id"], "progress": int(t["progress"]) * 100 / maxi(1, int(t["work_required"]))})
	return {"role": Vis.role(world, pid), "pool": {"size": Ops.pool_members(world, owner).size(), "free": free.size(),
		"qualified_investigator": inv, "qualified_counsel": counsel}, "oversight": oversight, "challenges": challenges,
		"running": running}


static func start_oversight(world: WorldState, pid: String, domain: String) -> Dictionary:
	if not DOMAINS.has(domain):
		return {"ok": false, "error": "unknown domain"}
	return Ops.create_task(world, "STAFF_T_OVERSIGHT", {"domain": domain, "domain_prefixes": DOMAINS[domain]["prefixes"]},
		{"kind": "PARTY", "id": pid})


static func start_challenge(world: WorldState, pid: String, option: Dictionary) -> Dictionary:
	return Ops.create_task(world, "STAFF_T_LEGAL_CHALLENGE", {"target_fact": option.get("target_fact", ""),
		"target_enactment": option.get("target_enactment", ""), "kind": option.get("kind", "")}, {"kind": "PARTY", "id": pid})


## AI opposition (and autoplay): one inquiry and one challenge at a time, only with qualified free staff.
static func run_ai(world: WorldState) -> void:
	var parties := world.peek("party")
	for pid in Det.ordered(parties):
		var p: Dictionary = parties[pid]
		if String(p.get("status", "ACTIVE")) != "ACTIVE" or int(p.get("seats", 0)) <= 0:
			continue
		if Vis.role(world, pid) != "OPPOSITION" or not Ops.autopilot(world, {"kind": "PARTY", "id": pid}):
			continue
		var o := options(world, pid)
		var busy := {}
		for r in o["running"]:
			busy[r["def_id"]] = true
		if not busy.has("STAFF_T_OVERSIGHT") and o["pool"]["qualified_investigator"] and not o["oversight"].is_empty() \
				and float(o["oversight"][0]["expected_yield"]) >= AI_OVERSIGHT_MIN_YIELD:
			start_oversight(world, pid, o["oversight"][0]["domain"])
		if not busy.has("STAFF_T_LEGAL_CHALLENGE") and o["pool"]["qualified_counsel"] and not o["challenges"].is_empty() \
				and float(o["challenges"][0]["p_win_est"]) >= AI_CHALLENGE_MIN_P:
			start_challenge(world, pid, o["challenges"][0])
