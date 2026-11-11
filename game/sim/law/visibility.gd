extends RefCounted
## Information access model (planning/spec-visibility.md; project §13.4). Pure predicates + two writers
## (note_government, add_grant) that only touch tables owned here: gov_term, access_grant.
##
## viewer = {"party_id": pid}   a party (its leader / staff)
##        | {}                  the simulation itself (omniscient; AI internals, tests, debug)
## Roles at a month: GOVERNING (member of the cabinet; the player's party in the commander era), SUPPORT
## (confidence-and-supply), OPPOSITION (everyone else with or without seats).

const Det := preload("res://sim/staff/det.gd")

const COMMANDER_TERM := "@COMMANDER"
const OVERSIGHT_FACT_MONTHS := 24       # an inquiry sees OFFICIAL facts of the last 24 months in its domain
const OVERSIGHT_INDICATOR_MONTHS := 6   # and the domain's OFFICIAL indicators for 6 months


static func is_sim(viewer: Dictionary) -> bool:
	return not viewer.has("party_id")


static func _pol(world: WorldState) -> Dictionary:
	return world.peek("pol").get("state", {})


static func player_party(world: WorldState) -> String:
	return String(_pol(world).get("player_party", ""))


# ======================================================================  government terms (writer: law DECISIONS)

## Keeps world.table("gov_term") in step with politics: one row per cabinet, plus the commander era.
static func note_government(world: WorldState) -> void:
	var terms := world.table("gov_term")
	if terms.is_empty():
		var id := world.new_id("term")
		terms[id] = {"id": id, "members": [COMMANDER_TERM], "support": [], "from_month": 0, "to_month": -1, "formed_month": -1}
	var gov: Dictionary = _pol(world).get("government", {})
	if gov.is_empty():
		return
	var last: Dictionary = terms[Det.ordered(terms)[-1]]
	if int(last["formed_month"]) == int(gov.get("formed_month", -2)):
		last["support"] = gov.get("support", []).duplicate()
		return
	var start := int(gov.get("formed_month", world.month))   # politics forms the cabinet; law notices next month
	last["to_month"] = start - 1
	var id := world.new_id("term")
	terms[id] = {"id": id, "members": gov.get("members", []).duplicate(), "support": gov.get("support", []).duplicate(),
		"from_month": start, "to_month": -1, "formed_month": int(gov.get("formed_month", world.month))}


static func _term_at(world: WorldState, month: int) -> Dictionary:
	var terms := world.peek("gov_term")
	var found: Dictionary = {}
	for id in Det.ordered(terms):
		var t: Dictionary = terms[id]
		if int(t["from_month"]) <= month and (int(t["to_month"]) < 0 or int(t["to_month"]) >= month):
			found = t
	return found


static func _in(term: Dictionary, world: WorldState, pid: String, key: String) -> bool:
	if term.is_empty():
		return false
	if key == "members" and term["members"].has(COMMANDER_TERM):
		return pid != "" and pid == player_party(world)
	return term[key].has(pid)


## Role of a party at a month (default: now).
static func role(world: WorldState, pid: String, month: int = -1) -> String:
	var m := world.month if month < 0 else month
	var t := _term_at(world, m)
	if t.is_empty():
		# No term recorded yet (fresh world): read politics directly.
		var gov: Dictionary = _pol(world).get("government", {})
		if gov.is_empty():
			return "GOVERNING" if pid != "" and pid == player_party(world) and String(_pol(world).get("era", "FOUNDING")) == "FOUNDING" else "OPPOSITION"
		if gov.get("members", []).has(pid):
			return "GOVERNING"
		return "SUPPORT" if gov.get("support", []).has(pid) else "OPPOSITION"
	if _in(t, world, pid, "members"):
		return "GOVERNING"
	if _in(t, world, pid, "support"):
		return "SUPPORT"
	return "OPPOSITION"


# ======================================================================  grants (oversight, court cases)

## kind: "FACT_PREFIX" (prefixes, fact months [from, to]), "FACT_IDS" (ids), "INDICATOR_PREFIX" (prefixes, until expires).
static func add_grant(world: WorldState, pid: String, kind: String, data: Dictionary, source: String) -> String:
	var id := world.new_id("grant")
	var g := {"id": id, "party_id": pid, "kind": kind, "granted_month": world.month, "source": source}
	for k in data:
		g[k] = data[k]
	world.table("access_grant")[id] = g
	return id


static func grant_oversight(world: WorldState, pid: String, prefixes: Array, source: String) -> void:
	add_grant(world, pid, "FACT_PREFIX", {"prefixes": prefixes.duplicate(), "from_month": world.month - OVERSIGHT_FACT_MONTHS,
		"to_month": world.month}, source)
	add_grant(world, pid, "INDICATOR_PREFIX", {"prefixes": prefixes.duplicate(),
		"expires_month": world.month + OVERSIGHT_INDICATOR_MONTHS}, source)


static func _prefix_hit(prefixes: Array, s: String) -> bool:
	for p in prefixes:
		if s.begins_with(String(p)):
			return true
	return false


static func _granted_fact(world: WorldState, pid: String, fact: Dictionary) -> bool:
	var grants := world.peek("access_grant")
	for id in Det.ordered(grants):
		var g: Dictionary = grants[id]
		if g["party_id"] != pid:
			continue
		match g["kind"]:
			"FACT_IDS":
				if g["ids"].has(fact["id"]):
					return true
			"FACT_PREFIX":
				if _prefix_hit(g["prefixes"], fact["type"]) and int(fact["month"]) >= int(g["from_month"]) \
						and int(fact["month"]) <= int(g["to_month"]):
					return true
	return false


static func _granted_indicator(world: WorldState, pid: String, ind_id: String) -> bool:
	var grants := world.peek("access_grant")
	for id in Det.ordered(grants):
		var g: Dictionary = grants[id]
		if g["party_id"] == pid and g["kind"] == "INDICATOR_PREFIX" and world.month <= int(g["expires_month"]) \
				and _prefix_hit(g["prefixes"], ind_id):
			return true
	return false


# ======================================================================  predicates

static func _involves(fact: Dictionary, pid: String) -> bool:
	for s in fact.get("subjects", []):
		if s.get("kind", "") == "PARTY" and s.get("id", "") == pid:
			return true
	for r in fact.get("responsible", []):
		if r["actor"].get("kind", "") == "PARTY" and r["actor"].get("id", "") == pid:
			return true
	return false


static func _gov_responsible(fact: Dictionary) -> bool:
	for r in fact.get("responsible", []):
		if r["actor"].get("kind", "") in ["GOVERNMENT", "COMMANDER", "AUTHORITY"]:
			return true
	return false


## Fact rules (spec-visibility §2):
##   PUBLIC  everyone.
##   OFFICIAL  the current government (incl. predecessors' files: civil-service continuity), parties that governed
##             when it happened, parties it is about, and grants (oversight inquiry, court case).
##   SECRET  only those who did it: parties governing when a GOVERNMENT/COMMANDER/AUTHORITY-responsible secret
##           was created, or a party responsible itself. Everyone else learns it only via *_REVEALED.
static func can_see_fact(world: WorldState, viewer: Dictionary, fact: Dictionary) -> bool:
	if is_sim(viewer) or fact.get("visibility", "PUBLIC") == "PUBLIC":
		return true
	var pid: String = viewer["party_id"]
	if _involves(fact, pid):
		return true
	var then := role(world, pid, int(fact["month"]))
	if fact["visibility"] == "SECRET":
		return then == "GOVERNING" and _gov_responsible(fact)
	if then == "GOVERNING" or role(world, pid) == "GOVERNING":
		return true
	return _granted_fact(world, pid, fact)


static func filter_facts(world: WorldState, viewer: Dictionary, facts: Array) -> Array:
	return facts.filter(func(f): return can_see_fact(world, viewer, f))


## Indicator rules: PUBLIC everyone; OFFICIAL government + support parties + active oversight grants; HIDDEN sim only.
static func can_see_indicator(world: WorldState, viewer: Dictionary, ind_id: String) -> bool:
	if is_sim(viewer):
		return true
	var d: Dictionary = world.indicators.defs.get(ind_id, {})
	match String(d.get("visibility", "PUBLIC")):
		"PUBLIC":
			return true
		"HIDDEN":
			return false
	var pid: String = viewer["party_id"]
	var r := role(world, pid)
	return r == "GOVERNING" or r == "SUPPORT" or _granted_indicator(world, pid, ind_id)


## Indicator value or null if the viewer may not see it.
static func read_indicator(world: WorldState, viewer: Dictionary, ind_id: String, key: String = "COLONY"):
	if not can_see_indicator(world, viewer, ind_id):
		return null
	return world.indicators.read(ind_id, key)


## Staff/task data of an owner: the government's internals are visible to the government only;
## a party's staff to that party only.
static func can_see_owner(world: WorldState, viewer: Dictionary, owner: Dictionary) -> bool:
	if is_sim(viewer):
		return true
	if owner.get("kind", "") == "GOVERNMENT":
		return role(world, viewer["party_id"]) == "GOVERNING"
	return owner.get("id", "") == viewer["party_id"]


static func can_decree(world: WorldState, viewer: Dictionary) -> bool:
	return is_sim(viewer) or role(world, viewer["party_id"]) == "GOVERNING"
