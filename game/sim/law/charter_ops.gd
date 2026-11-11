extends RefCounted
## M12 colonial charter, home-world sanctions and breaking away (planning/spec-colony-v1.md §5-§7; law side).
##
## Sovereignty (law_state s.sovereignty.status): COLONY -> INDEPENDENCE_DECLARED -> INDEPENDENT | AUTONOMY | COLONY.
## The political era stays PARLIAMENTARY. Politics (Wilma) runs the votes and the home-world actor and calls
## the transitions; 88 delivers the quota while LQ.quota_due says it is due.

const Det := preload("res://sim/staff/det.gd")
const L := preload("res://sim/law/law_data.gd")
const LawOps := preload("res://sim/law/law_ops.gd")
const J := preload("res://sim/law/justice_ops.gd")

const HOME := {"kind": "HOME_WORLD", "id": "home_world"}
const GOVERNMENT := {"kind": "GOVERNMENT", "id": "government"}
const PARLIAMENT := {"kind": "INSTITUTION", "id": "parliament"}
const INDEPENDENCE_SEATS := 101          # 2/3 of 151
const REFERENDUM_MIN_TURNOUT := 0.5      # of eligible voters
const REFERENDUM_MONTHS := 3             # the referendum must follow the parliament vote within 3 months
const EVASION_MEMORY := 36               # months a proven evasion justifies sanctions
const CHARTER_LEVERS := ["LAW_CHARTER_QUOTA_SHARE", "LAW_CHARTER_PRICE_PCT"]


static func sov(world: WorldState) -> Dictionary:
	var s := LawOps.state(world)
	if not s.has("sovereignty"):
		s["sovereignty"] = {"status": "COLONY", "since": world.month, "refusal": false, "governor": false,
			"governor_month": -1, "petitions": {}, "independence_vote": {}}
	return s["sovereignty"]


static func status(world: WorldState) -> String:
	return String(world.peek("law_state").get("s", {}).get("sovereignty", {}).get("status", "COLONY"))


static func is_colonial(world: WorldState) -> bool:
	return status(world) in ["COLONY", "AUTONOMY"]


## Charter rules added once (new games and older saves; called from the DECISIONS phase).
static func ensure_m12(world: WorldState) -> void:
	var s := LawOps.state(world)
	if s.get("m12_rules", false):
		return
	s["m12_rules"] = true
	sov(world)
	for r in L.m12_rules():
		r["effective_month"] = world.month
		LawOps.add_rule(world, r)
	LawOps.bump_rules_version(world)


static func _set_colonial_rules(world: WorldState, st: String) -> void:
	var rules := world.table("legal_rule")
	for rid in Det.ordered(rules):
		if rules[rid].get("colonial", false):
			rules[rid]["status"] = st
	LawOps.bump_rules_version(world)


static func _fact(world: WorldState, type: String, subjects: Array, resp: Array, impact: Dictionary, mag: int, data: Dictionary) -> String:
	return LawOps.law_fact(world, type, "PUBLIC", subjects, resp, impact, mag, data)


# =====================================================================================  the charter (§5)

## The home world changes its own charter terms (quota share, charter price %). Only while the colony is colonial.
static func home_world_amend(world: WorldState, lever: String, value: int) -> Dictionary:
	if not (lever in CHARTER_LEVERS) or not is_colonial(world):
		return {"ok": false, "reason": "the home world can only amend its charter terms while the colony is colonial"}
	var def: Dictionary = world.lever_defs[lever]
	value = clampi(value, int(def["range"][0]), int(def["range"][1]))
	var old = world.levers.get(lever)
	world.levers[lever] = value
	_fact(world, "LAW_CHARTER_AMENDED", [HOME], [{"actor": HOME, "share": 1.0}],
		{"FAIRNESS": -5 if lever == "LAW_CHARTER_QUOTA_SHARE" and value > int(old) else 0}, 50,
		{"lever": lever, "from": old, "to": value})
	return {"ok": true, "from": old, "to": value}


## What 88 delivers on a ship: {due, share_pct, price_pct, reason}. Not due when independent, declared, or refusing.
static func quota_due(world: WorldState) -> Dictionary:
	var st: Dictionary = world.peek("law_state").get("s", {}).get("sovereignty", {})
	var due := is_colonial(world) and not bool(st.get("refusal", false))
	var reason := ""
	if not is_colonial(world):
		reason = status(world)
	elif not due:
		reason = "REFUSAL"
	return {"due": due, "share_pct": int(world.levers.get("LAW_CHARTER_QUOTA_SHARE", 40)) if is_colonial(world) else 0,
		"price_pct": int(world.levers.get("LAW_CHARTER_PRICE_PCT", 35)), "reason": reason}


# =====================================================================================  home-world inspector (§6)

## At ship arrival: the inspector examines charter evasion and smuggling (greed kinds QUOTA_EVASION / SMUGGLING,
## reported by 88 through LawOps.record_greed). quality 0..100 is the inspector's skill, intensity scales effort.
## Found records become public (LAW_VIOLATION_REVEALED); colony courts prosecute them only while the colony enforces
## the charter. Returns the found records and emits HOME_EVASION_FOUND for the home-world actor.
static func home_inspection(world: WorldState, quality: int = 60, intensity: float = 1.0) -> Array:
	var found: Array = []
	if not is_colonial(world):
		return found
	var track := world.table("violation_track")
	var rng := world.rng.stream("law.home_inspector")
	var p_find := (0.6 + 0.3 * float(quality) / 100.0) * intensity
	for fid in Det.ordered(track):
		var v: Dictionary = track[fid]
		if v.get("channel", "") != "HOME" or v["revealed"] or (not v.get("active", true) and int(v.get("evidence", 0)) < 50):
			continue
		if rng.randf() < minf(1.0, p_find * (0.5 + float(v.get("evidence", 500)) / 1000.0)):
			found.append(fid)
			if bool(world.levers.get("LAW_ENFORCE_CHARTER", true)):
				J._reveal_violation(world, fid, HOME, "HOME_INSPECTION")
			else:
				v["revealed"] = true
				v["revealed_month"] = world.month
				v["channel_found"] = "HOME_INSPECTION"
				world.table("revealed_fact")[fid] = true
				world.facts.reveal(world.month, fid, [HOME])
	var total := 0
	var orgs: Array = []
	for fid in found:
		total += int(track[fid].get("saving", 0))
		if not orgs.has(track[fid]["company"]):
			orgs.append(track[fid]["company"])
	sov(world)["last_inspection"] = world.month
	_fact(world, "HOME_INSPECTION_REPORT", [HOME, GOVERNMENT], [], {}, 30 if found.is_empty() else 50,
		{"found": found.size(), "records": found, "orgs": orgs, "evaded": total})
	if not found.is_empty():
		_fact(world, "HOME_EVASION_FOUND", [HOME], [{"actor": GOVERNMENT, "share": 1.0}], {"GOVERNANCE": -3}, 50,
			{"records": found, "orgs": orgs, "evaded": total, "colony_enforces": bool(world.levers.get("LAW_ENFORCE_CHARTER", true))})
	return found


static func evasion_proven(world: WorldState) -> bool:
	return not world.facts.query("HOME_EVASION_FOUND", world.month - EVASION_MEMORY, world.month).is_empty()


## Legality of a home-world sanction under the charter: kind = FINE | WITHHOLD | REVOKE_PRIVILEGE | APPOINT_GOVERNOR |
## EXPEDITION. -> {lawful, result, reason}. An unlawful sanction emits HOME_UNLAWFUL_SANCTION (the actor's legitimacy).
## Lawful APPOINT_GOVERNOR installs the governor (veto power over colony laws).
static func home_sanction(world: WorldState, kind: String, params: Dictionary = {}) -> Dictionary:
	var st := sov(world)
	var p := params.duplicate()
	var bound: bool = st["status"] != "INDEPENDENT"     # after recognition no charter grievance justifies sanctions
	p["evasion_proven"] = bound and evasion_proven(world)
	p["refusal"] = bound and bool(st["refusal"])
	p["colony_defiant"] = bool(st["refusal"]) or st["status"] == "INDEPENDENCE_DECLARED"
	var res := LawOps.validate(world, HOME, "HOME_" + kind, p)
	var lawful: bool = res["result"] == "AUTHORIZED"
	if not lawful:
		_fact(world, "HOME_UNLAWFUL_SANCTION", [HOME, GOVERNMENT], [{"actor": HOME, "share": 1.0}], {"FAIRNESS": -5}, 50,
			{"sanction": kind, "reason": res["reason"]})
	elif kind == "APPOINT_GOVERNOR":
		st["governor"] = true
		st["governor_month"] = world.month
		_fact(world, "HOME_GOVERNOR_APPOINTED", [HOME, GOVERNMENT], [{"actor": HOME, "share": 1.0}], {"GOVERNANCE": -5}, 60,
			{"month": world.month})
	return {"lawful": lawful, "result": res["result"], "reason": res["reason"]}


## The governor vetoes a colony enactment before it takes effect (home-world actor decides which).
static func governor_veto(world: WorldState, enactment_id: String) -> Dictionary:
	var st := sov(world)
	var e: Dictionary = world.table("enactment").get(enactment_id, {})
	if not st["governor"] or not is_colonial(world):
		return {"ok": false, "reason": "no governor with veto power"}
	if e.is_empty() or not (e["status"] in ["PENDING", "LEGAL", "SCHEDULED"]):
		return {"ok": false, "reason": "only an enactment not yet in effect can be vetoed"}
	e["status"] = "VETOED"
	_fact(world, "HOME_GOVERNOR_VETO", [HOME, GOVERNMENT], [{"actor": HOME, "share": 1.0}], {"GOVERNANCE": -4}, 50,
		{"enactment": enactment_id, "lever": e.get("lever", ""), "value": e.get("value")})
	return {"ok": true}


# =====================================================================================  breaking away (§7)

## Parliament petitions the home world (always lawful). demands: e.g. {"LAW_CHARTER_QUOTA_SHARE": 30}.
static func petition_home(world: WorldState, demands: Dictionary, by: Dictionary = PARLIAMENT) -> String:
	var id := world.new_id("petition")
	sov(world)["petitions"][id] = {"id": id, "month": world.month, "demands": demands.duplicate(), "status": "SENT"}
	_fact(world, "LAW_PETITION_SENT", [by, HOME], [], {}, 40, {"petition": id, "demands": demands})
	return id


## The home world's answer (next ship): accepted demands become charter amendments.
static func answer_petition(world: WorldState, id: String, accepted: bool, terms: Dictionary = {}) -> void:
	var p: Dictionary = sov(world)["petitions"].get(id, {})
	if p.is_empty() or p["status"] != "SENT":
		return
	p["status"] = "ACCEPTED" if accepted else "REJECTED"
	var applied: Dictionary = terms if not terms.is_empty() else (p["demands"] if accepted else {})
	for lever in applied:
		if accepted:
			home_world_amend(world, lever, int(applied[lever]))
	_fact(world, "HOME_PETITION_ANSWERED", [HOME], [{"actor": HOME, "share": 1.0}], {}, 50,
		{"petition": id, "accepted": accepted, "terms": applied})


## The government refuses the quota: open defiance, unlawful under the charter (recorded, PUBLIC).
static func refuse_quota(world: WorldState, by: Dictionary = GOVERNMENT) -> Dictionary:
	var st := sov(world)
	if not is_colonial(world) or st["refusal"]:
		return {"ok": false, "reason": "no quota to refuse"}
	var res := LawOps.validate(world, by, "REFUSE_QUOTA", {})
	st["refusal"] = true
	st["refusal_month"] = world.month
	_fact(world, "LAW_CHARTER_DEFIANCE", [by, HOME], [{"actor": by, "share": 1.0}], {}, 70,
		{"act": "REFUSE_QUOTA", "lawful_under_charter": res["result"] == "AUTHORIZED", "rule": res["trace"]})
	return {"ok": true, "lawful": res["result"] == "AUTHORIZED"}


static func end_refusal(world: WorldState) -> void:
	var st := sov(world)
	if st["refusal"]:
		st["refusal"] = false
		_fact(world, "LAW_CHARTER_COMPLIANCE_RESUMED", [GOVERNMENT, HOME], [], {}, 40, {})


## Constitutional procedure: 2/3 of parliament (101 of 151), then within 3 months a referendum passed by a simple
## majority of votes with turnout >= 50% of eligible voters. Politics runs both votes.
static func record_independence_vote(world: WorldState, yes_seats: int) -> Dictionary:
	var ok := yes_seats >= INDEPENDENCE_SEATS
	sov(world)["independence_vote"] = {"month": world.month, "yes": yes_seats, "passed": ok}
	_fact(world, "LAW_INDEPENDENCE_VOTE", [PARLIAMENT], [], {}, 60, {"yes": yes_seats, "needed": INDEPENDENCE_SEATS, "passed": ok})
	return {"ok": ok, "needed": INDEPENDENCE_SEATS, "referendum_by": world.month + REFERENDUM_MONTHS}


static func can_declare_independence(world: WorldState, referendum_yes: int, referendum_no: int, eligible: int) -> Dictionary:
	var v: Dictionary = sov(world)["independence_vote"]
	if not is_colonial(world):
		return {"ok": false, "reason": "the colony is not under the charter"}
	if v.is_empty() or not v["passed"] or world.month - int(v["month"]) > REFERENDUM_MONTHS:
		return {"ok": false, "reason": "needs a 2/3 parliament vote (101 seats) in the last 3 months"}
	var cast := referendum_yes + referendum_no
	if eligible <= 0 or float(cast) / float(eligible) < REFERENDUM_MIN_TURNOUT:
		return {"ok": false, "reason": "referendum turnout below 50% of eligible voters"}
	if referendum_yes * 2 <= cast:
		return {"ok": false, "reason": "the referendum did not pass"}
	return {"ok": true, "reason": ""}


## Declare independence after a valid procedure: the charter's rules stop binding the colony (suspended), the quota
## stops, the governor's veto ends. The home world answers on the next ship (recognise / autonomy / restore).
static func declare_independence(world: WorldState, referendum_yes: int, referendum_no: int, eligible: int) -> Dictionary:
	var chk := can_declare_independence(world, referendum_yes, referendum_no, eligible)
	if not chk["ok"]:
		return chk
	var st := sov(world)
	st["status"] = "INDEPENDENCE_DECLARED"
	st["since"] = world.month
	st["governor"] = false
	_set_colonial_rules(world, "SUSPENDED")
	_fact(world, "LAW_INDEPENDENCE_DECLARED", [PARLIAMENT, HOME], [], {}, 95,
		{"referendum_yes": referendum_yes, "referendum_no": referendum_no, "eligible": eligible})
	return {"ok": true, "reason": ""}


static func recognise_independence(world: WorldState) -> void:
	var st := sov(world)
	st["status"] = "INDEPENDENT"
	st["since"] = world.month
	st["refusal"] = false
	st["governor"] = false
	_set_colonial_rules(world, "REPEALED")
	world.levers["LAW_CHARTER_QUOTA_SHARE"] = 0
	_fact(world, "LAW_INDEPENDENCE_RECOGNISED", [HOME, PARLIAMENT], [], {"GOVERNANCE": 10, "FAIRNESS": 5}, 95, {})


## Negotiated autonomy: the charter binds again on softer terms {LAW_CHARTER_QUOTA_SHARE, LAW_CHARTER_PRICE_PCT}.
static func grant_autonomy(world: WorldState, terms: Dictionary) -> void:
	_back_under_charter(world, "AUTONOMY", terms, false)
	_fact(world, "LAW_AUTONOMY_GRANTED", [HOME, PARLIAMENT], [], {"GOVERNANCE": 3}, 80, {"terms": terms})


## The colony is brought back under a (harsher) charter, usually with a governor.
static func restore_charter(world: WorldState, terms: Dictionary, governor: bool = true) -> void:
	_back_under_charter(world, "COLONY", terms, governor)
	_fact(world, "LAW_CHARTER_RESTORED", [HOME, GOVERNMENT], [{"actor": HOME, "share": 1.0}], {"GOVERNANCE": -10, "FAIRNESS": -8}, 90,
		{"terms": terms, "governor": governor})


static func _back_under_charter(world: WorldState, new_status: String, terms: Dictionary, governor: bool) -> void:
	var st := sov(world)
	st["status"] = new_status
	st["since"] = world.month
	st["refusal"] = false
	st["governor"] = governor
	st["governor_month"] = world.month if governor else -1
	_set_colonial_rules(world, "ACTIVE")
	for lever in terms:
		if lever in CHARTER_LEVERS:
			world.levers[lever] = clampi(int(terms[lever]), 0, 100)
	# A militia above the charter cap is unlawful again: clamp it (disbanded down to the cap).
	var cap := int(L.LEVER_BOUNDS["LAW_MILITIA"]["max"])
	if int(world.levers.get("LAW_MILITIA", 0)) > cap:
		world.levers["LAW_MILITIA"] = cap
