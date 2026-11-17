extends RefCounted
## Who decides (planning/design-delegation.md; Maja, 2026-11-15). Opt-in (flag DELEGATION): without it every entry
## point returns before touching the world, so games without the flag reproduce exactly.
##
## Step 1: the registry of decision types and a counter of cases by type and month. Each system that takes a government
## decision calls note(world, type) when it takes it.
## Step 2: who decides. Every type has a level, set at the start of a term (presets, changeable later per type):
##   CALL     the minister makes the call; the First Minister reads it in the monthly summary
##   SUGGEST  the case comes to the desk with the minister's choice pre-selected
##   ME       the case comes to the desk with the options and the minister's advice, nothing pre-selected
## The legal ceiling caps the level (a Cabinet or Parliament matter is at most SUGGEST); a type whose portfolio has
## nobody in it stays with the First Minister until it is handed to a minister of the First Minister's choosing, and
## a minister deciding outside their portfolio does it worse. In step 2 the levels act on the office items (union
## demands, staff requests, road licences and neglect, merger reviews); the systems that still decide in code (the
## capital programme, grants, wildlife, ...) are routed through it in step 3. Trust and standing are step 4.
##
## Tables: "decision_case" {"<month>": {type: n}}; "decision_who" {"<month>": {"MINISTER": n, "FM": n}} (office cases:
## who answered); "delegation" {sig, term_start, preset, levels {type: level}, handed {type: role}, changes [{month,
## type, kind LEVEL|HAND_OVER|PRESET, from, to}], setup_item, summary {month, decided [...], waiting [...]}}.

const FLAG := "DELEGATION"
const OS_PATH := "res://sim/staff/office_staff.gd"

## Legal ceiling (section 4 of the design note):
##   MINISTER   a minister may make the call alone
##   CABINET    a Cabinet matter by law: reaches the First Minister's desk at least as a suggestion
##   PARLIAMENT the Cabinet decides to table it, Parliament votes
const CEILINGS := ["MINISTER", "CABINET", "PARLIAMENT"]
const LEVELS := ["CALL", "SUGGEST", "ME"]
const LEVEL_NAMES := {"CALL": "Make the call", "SUGGEST": "Give me a suggestion", "ME": "Leave it to me"}
## Presets for the term-start sheet: TRUSTING hands every type over as far as the law allows; BALANCED lets ministers
## call the routine types and suggest the rest; HANDS_ON keeps everything.
const PRESETS := ["TRUSTING", "BALANCED", "HANDS_ON"]
const PRESET_NAMES := {"TRUSTING": "Trust my ministers", "BALANCED": "Balanced", "HANDS_ON": "Hands-on"}
const DEFAULT_PRESET := "BALANCED"
const OUTSIDE_SKILL := 0.6          # a minister deciding outside their portfolio works at this share of their skill
const SETUP_DEADLINE_M := 2
## Option leans of the systems' cases, on OfficeFeed.ai_answer's scale (lean/1000 × the centre × 2 against a bonus of 1
## for the recommendation): a strongly ideological First Minister overrules a minister, a centrist one follows.
const CASE_LEAN_SCALE := 2000

## Decision types. portfolio: the office role (OfficeStaff.ROLES) of the minister it belongs to; "fallback" is used
## when that portfolio is not in the Cabinet (AGRICULTURE needs flag AGRI_MIN). FM = the First Minister's own.
## src: the system that reports it. routine: the BALANCED preset lets the minister call it.
const TYPES := {
	# GovBuilder: the state's capital programme. Road works include the choice of which road goes first and which fix
	# (road_ranking, road_option under ROAD_WORKS): one order is one decision.
	"BUILD_HOUSING": {"name": "Public housing block", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_SCHOOL": {"name": "New school", "portfolio": "SERVICES", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_CLINIC": {"name": "New clinic", "portfolio": "SERVICES", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_ROAD": {"name": "Road works", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder", "routine": true},
	"BUILD_STATE_FARM": {"name": "State farm", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_UTILITY": {"name": "Power, water or processing plant", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_BAKERY": {"name": "Public bakery", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_DEPOT": {"name": "Port depot", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"PUBLIC_WORKS": {"name": "Public works against unemployment", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "gov_builder"},
	"UPGRADE_FACILITY": {"name": "Upgrade a colony workshop", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"RETENDER_PROJECT": {"name": "Re-tender a public project", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder", "routine": true},
	"BUILDER_GRANT": {"name": "Grant offer to private builders", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"FOOD_RESERVE_RELEASE": {"name": "Open the food reserve", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder", "routine": true},
	"GRANT_COVERAGE": {"name": "Where a family grant programme lands", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	# EconBuilders (R8_BUILDERS): the government as a client of the builders, and its own public builders
	"PUBLIC_QUOTE": {"name": "Accept or refuse a builder's quote", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "econ_builders", "routine": true},
	"PUBLIC_BUILDER": {"name": "Found or enlarge a public builder", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "econ_builders"},
	# RoadLaw (PRIVATE_ROADS): private roads
	"ROAD_LICENCE": {"name": "Licence for a private road", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "road_law",
		"note": "the Cabinet's for a road across 3+ districts"},
	"ROAD_NEGLECT": {"name": "Neglected private road", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "road_law", "routine": true},
	"SPEED_LIMIT": {"name": "Speed limit on a road near people", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder", "routine": true},
	"ROAD_PASS": {"name": "Over- or underpass, or a bypass, for safety", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"ROAD_TAKEOVER": {"name": "The state takes a private road", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "road_law",
		"note": "the Cabinet's when compulsory or above the state-aid threshold"},
	# HiringCentre (HIRING_CENTRE, Ella): training the unemployed to become specialists. Whether the trained find posts
	# is not known beforehand. A private owner opening or converting a centre for fees is a company decision, not these.
	"HIRING_FUND_SEATS": {"name": "Fund training seats", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "hiring_centre", "routine": true},
	"HIRING_BUILD_CENTRE": {"name": "Build a skill centre", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "hiring_centre"},
	"HIRING_CONVERT_BUILDING": {"name": "Convert a building into a skill centre", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "hiring_centre"},
	# EconInstitutions (R8_INSTITUTIONS): the public services' own requests and sites
	"INSTITUTION_BUDGET": {"name": "Budget request from a public service", "portfolio": "SERVICES", "ceiling": "PARLIAMENT", "src": "gov_builder"},
	"INSTITUTION_FEE": {"name": "Fee proposal from a public service", "portfolio": "SERVICES", "ceiling": "PARLIAMENT", "src": "gov_builder"},
	"INSTITUTION_SITE": {"name": "Reopen or close a clinic or school", "portfolio": "SERVICES", "ceiling": "MINISTER", "src": "gov_builder"},
	# GovWildlife: the yearly (or after a death) wildlife policy review
	"WILDLIFE_REVIEW": {"name": "Wildlife policy review", "portfolio": "ENVIRONMENT", "ceiling": "MINISTER", "src": "gov_wildlife"},
	# FirmAI (Bob): the treasury pays for a public company's investment when no loan is to be had
	"PE_INVESTMENT": {"name": "Treasury funds a public company's investment", "portfolio": "FINANCE", "ceiling": "MINISTER", "src": "firm_ai"},
	# GovBuilder (Wilma): a public company's proposal to raise its tariff (its price rule 1; E150P / R8_UTILITIES)
	"TARIFF_PROPOSAL": {"name": "A public company's tariff rise", "portfolio": "FINANCE", "ceiling": "MINISTER", "src": "gov_builder"},
	# Legislature: laws
	"BILL": {"name": "Table a bill", "portfolio": "FM", "ceiling": "PARLIAMENT", "src": "legislature"},
	"ORDINANCE": {"name": "Commander's ordinance", "portfolio": "FM", "ceiling": "CABINET", "src": "legislature"},
	# HomeWorld: the colony's side of the charter
	"CHARTER_PETITION": {"name": "Petition the home world", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	"CHARTER_REFUSAL": {"name": "Refuse the charter quota", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	"INDEPENDENCE_VOTE": {"name": "Put independence to Parliament", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	# Office items answered (by the player, an AI First Minister, a minister, or expired to the default)
	"UNION_DEMAND": {"name": "Public-sector union demand", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "office"},
	"STAFF_DECISION": {"name": "Staff decision request", "portfolio": "CHIEF_OF_STAFF", "ceiling": "MINISTER", "src": "office", "routine": true},
	"COMPETITION_REVIEW": {"name": "Merger under competition law", "portfolio": "ECON_ADVISER", "ceiling": "CABINET", "src": "competition_law"},
	"OFFICE_OTHER": {"name": "Other office decision", "portfolio": "FM", "ceiling": "MINISTER", "src": "office"},
}

## GovBuilder facility types -> decision type (public-works orders are PUBLIC_WORKS whatever they build).
const BUILD_TYPE := {"HOUSING": "BUILD_HOUSING", "SCHOOL": "BUILD_SCHOOL", "CLINIC": "BUILD_CLINIC", "ROAD": "BUILD_ROAD",
	"FARM": "BUILD_STATE_FARM", "POWER": "BUILD_UTILITY", "WATERWORKS": "BUILD_UTILITY", "PROCESSING": "BUILD_UTILITY",
	"COMPONENTS": "BUILD_UTILITY", "BAKERY": "BUILD_BAKERY", "DEPOT": "BUILD_DEPOT"}
## Office items -> decision type: by the posting system first, then by category.
const SOURCE_TYPE := {"UNION": "UNION_DEMAND", "STAFF_DECISION": "STAFF_DECISION", "road_licence": "ROAD_LICENCE",
	"road_neglect": "ROAD_NEGLECT", "competition": "COMPETITION_REVIEW"}
const OFFICE_TYPE := {"UNION_DEMAND": "UNION_DEMAND", "STAFF_DECISION": "STAFF_DECISION", "COMPETITION": "COMPETITION_REVIEW"}
## Systems that note their own decisions when they apply the answer (their office items are not counted twice), and
## this module's own items (the term-start sheet), which are not decisions of the government.
const SELF_NOTED := ["road_licence", "road_neglect", "competition", "delegation", "delegation_summary"]


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(FLAG) and not CoreUtil.off(world, FLAG)


# ======================================================================= step 1: the counter

## A system took a decision of `type` this month. No-op without the flag. Unknown types are a programming error.
static func note(world: WorldState, type: String) -> void:
	if not on(world):
		return
	assert(TYPES.has(type), "unregistered decision type " + type)
	_bump(world.table("decision_case"), str(world.month), type)


static func _bump(t: Dictionary, key: String, k: String) -> void:
	if not t.has(key):
		t[key] = {}
	var row: Dictionary = t[key]
	row[k] = int(row.get(k, 0)) + 1


## GovBuilder's commissioning: the decision type of an order of facility `ftype` on budget line `line`.
static func build_type(ftype: String, line: String) -> String:
	if line == "ECON_BUDGET_PUBLIC_WORKS":
		return "PUBLIC_WORKS"
	return String(BUILD_TYPE.get(ftype, "BUILD_UTILITY"))


## The decision type of an office item ("" for items that are no decision: papers, reports, calendar, party mail).
static func case_type(item: Dictionary) -> String:
	if not (String(item.get("kind", "")) in ["EMAIL", "CALL"]) or String(item.get("from", {}).get("kind", "")) == "PARTY_STAFF":
		return ""
	var sys := String(item.get("source", {}).get("system", ""))
	if sys in ["delegation", "delegation_summary"]:
		return ""
	var ht := String(item.get("hidden", {}).get("case_type", ""))
	if ht != "":
		return ht
	if SOURCE_TYPE.has(sys):
		return String(SOURCE_TYPE[sys])
	return String(OFFICE_TYPE.get(String(item.get("category", "")), "OFFICE_OTHER"))


## An office item was answered or expired: counted as a case of its type (unless its system counts it itself), and
## who answered it: a minister (DELEGATED) or the First Minister (the player or an AI First Minister, or expiry).
static func note_office(world: WorldState, item: Dictionary) -> void:
	if not on(world):
		return
	var ty := case_type(item)
	if ty == "":
		return
	if not (String(item.get("source", {}).get("system", "")) in SELF_NOTED):
		note(world, ty)
	_bump(world.table("decision_who"), str(world.month), "MINISTER" if String(item.get("status", "")) == "DELEGATED" else "FM")


# ======================================================================= step 2: who decides

static func _os() -> GDScript:
	return load(OS_PATH)


static func _d(world: WorldState) -> Dictionary:
	var t := world.table("delegation")
	if not t.has("levels"):
		t.merge({"sig": "", "term_start": world.month, "preset": DEFAULT_PRESET, "levels": preset_levels(DEFAULT_PRESET),
			"handed": {}, "changes": [], "setup_item": "", "summary": {}})
	return t


## The portfolio that holds `type` by right in this world (FM when it is the First Minister's own).
static func portfolio(world: WorldState, type: String) -> String:
	var d: Dictionary = TYPES.get(type, {})
	var p := String(d.get("portfolio", "FM"))
	if d.has("fallback") and not (_os().portfolios(world) as Array).has(p):
		return String(d["fallback"])
	return p


## The most a type may be handed over: CALL for a minister's matter, SUGGEST for a Cabinet or Parliament matter.
static func max_level(type: String) -> String:
	return "CALL" if String(TYPES.get(type, {}).get("ceiling", "MINISTER")) == "MINISTER" else "SUGGEST"


static func _cap(lv: String, top: String) -> String:
	return top if LEVELS.find(lv) < LEVELS.find(top) else lv


## Levels of a preset, as far as each type's ceiling allows.
static func preset_levels(preset: String) -> Dictionary:
	var out := {}
	for ty in TYPES:
		var lv := "ME"
		match preset:
			"TRUSTING":
				lv = "CALL"
			"BALANCED":
				lv = "CALL" if bool(TYPES[ty].get("routine", false)) else "SUGGEST"
		out[ty] = _cap(lv, max_level(ty))
	return out


## The role that holds `type` now: the minister it was handed to, else its portfolio ("FM" = the First Minister's).
static func holder_role(world: WorldState, type: String) -> String:
	var h: Dictionary = world.peek("delegation").get("handed", {})
	return String(h[type]) if h.has(type) else portfolio(world, type)


## The person in `role` (empty when the role is vacant).
static func holder_person(world: WorldState, role: String) -> Dictionary:
	if role == "" or role == "FM":
		return {}
	return _os().holder(world, role)


## The level `type` is decided at now: the level set for it, capped by its ceiling; ME when it is the First Minister's
## own or nobody holds it. `cabinet` = this case is a Cabinet matter by law whatever its type (a road across three
## districts, a takeover above the state-aid threshold).
static func level(world: WorldState, type: String, cabinet: bool = false) -> String:
	if not TYPES.has(type):
		return "ME"
	var role := holder_role(world, type)
	if role == "FM" or holder_person(world, role).is_empty():
		return "ME"
	var lv := String(world.peek("delegation").get("levels", {}).get(type, preset_levels(DEFAULT_PRESET)[type]))
	lv = _cap(lv, max_level(type))
	return _cap(lv, "SUGGEST") if cabinet else lv


## Set the level of one type. Refused above the type's ceiling. Mid-term changes are logged (step 4 reads them).
static func set_level(world: WorldState, type: String, lv: String) -> Dictionary:
	if not on(world):
		return {"ok": false, "error": "Delegation is off"}
	if not TYPES.has(type) or not (lv in LEVELS):
		return {"ok": false, "error": "Unknown decision type or level"}
	if LEVELS.find(lv) < LEVELS.find(max_level(type)):
		return {"ok": false, "error": "The law keeps this on the First Minister's desk (at most: give me a suggestion)"}
	if portfolio(world, type) == "FM" and not (world.peek("delegation").get("handed", {}) as Dictionary).has(type):
		return {"ok": false, "error": "This is the First Minister's own decision"}
	var d := _d(world)
	var was := String(d["levels"].get(type, "ME"))
	if was == lv:
		return {"ok": true, "error": ""}
	d["levels"][type] = lv
	(d["changes"] as Array).append({"month": world.month, "type": type, "kind": "LEVEL", "from": was, "to": lv})
	return {"ok": true, "error": ""}


## Hand `type` to the minister in `role` (a type with no minister, or moved to another; "" hands it back to its
## portfolio). The role must be a ministerial portfolio with somebody in it.
static func hand_over(world: WorldState, type: String, role: String) -> Dictionary:
	if not on(world):
		return {"ok": false, "error": "Delegation is off"}
	if not TYPES.has(type):
		return {"ok": false, "error": "Unknown decision type"}
	var d := _d(world)
	var was := holder_role(world, type)
	if role == "" or role == portfolio(world, type):
		(d["handed"] as Dictionary).erase(type)
	else:
		if not (_os().portfolios(world) as Array).has(role) or holder_person(world, role).is_empty():
			return {"ok": false, "error": "Nobody holds that portfolio"}
		d["handed"][type] = role
	(d["changes"] as Array).append({"month": world.month, "type": type, "kind": "HAND_OVER", "from": was, "to": holder_role(world, type)})
	return {"ok": true, "error": ""}


static func apply_preset(world: WorldState, preset: String) -> Dictionary:
	if not on(world) or not (preset in PRESETS):
		return {"ok": false, "error": "Unknown preset"}
	var d := _d(world)
	d["preset"] = preset
	d["levels"] = preset_levels(preset)
	(d["changes"] as Array).append({"month": world.month, "type": "", "kind": "PRESET", "from": "", "to": preset})
	return {"ok": true, "error": ""}


## True when `type` is decided by a minister outside their own portfolio (handed over).
static func outside_portfolio(world: WorldState, type: String) -> bool:
	var role := holder_role(world, type)
	return role != "FM" and role != portfolio(world, type)


## The term-start sheet (pure): every type grouped by the role that holds it, with its level and limits. Groups:
## [{role, title, person, name, types: [{type, name, level, max_level, ceiling, outside, note}]}]; role "FM" = the
## First Minister's own, "" = held by nobody (vacant portfolio; stays with the First Minister until handed over).
static func sheet(world: WorldState) -> Array:
	var groups := {}
	var order: Array = []
	for ty in TYPES:
		var role := holder_role(world, ty)
		var key := role if role == "FM" or not holder_person(world, role).is_empty() else ""
		if not groups.has(key):
			var p := holder_person(world, key)
			groups[key] = {"role": key, "title": _role_title(world, key), "person": String(p.get("id", "")), "name": String(p.get("name", "")), "types": []}
			order.append(key)
		(groups[key]["types"] as Array).append({"type": ty, "name": String(TYPES[ty]["name"]), "level": level(world, ty),
			"max_level": max_level(ty), "ceiling": String(TYPES[ty]["ceiling"]), "outside": outside_portfolio(world, ty),
			"portfolio": portfolio(world, ty), "note": String(TYPES[ty].get("note", ""))})
	# cabinet order (Wilma): the First Minister, the portfolios as the Cabinet lists them, the civil service, then nobody
	var ports: Array = _os().portfolios(world)
	var ro: Array = ports + (_os().role_order(world) as Array).filter(func(r): return not (r in ports))   # as OfficeStaff.cabinet lists them
	order.sort_custom(func(a, b): return _group_rank(ro, String(a)) < _group_rank(ro, String(b)))
	var out: Array = []
	for k in order:
		out.append(groups[k])
	return out


static func _group_rank(ro: Array, role: String) -> int:
	if role == "FM":
		return -1
	if role == "":
		return 1000
	var i := ro.find(role)
	return i if i >= 0 else 999


static func _role_title(world: WorldState, role: String) -> String:
	if role == "FM":
		return "First Minister"
	if role == "":
		return "Nobody (vacant)"
	var lbl := String(_os().minister_label(world, role))
	return lbl if lbl != "" else role


# ======================================================================= monthly (OfficeFeed, POLITICS phase)

## Called by OfficeFeed at the end of its month, before an AI First Minister answers what is left. `player`: the
## player holds the office.
static func monthly(world: WorldState, player: bool) -> void:
	if not on(world):
		return
	_term(world, player)
	var decided := _ministers_call(world)
	_summary(world, player, decided)


## A new government (or the founding commander's office) starts a term: the levels go back to the preset, and the
## player gets the term-start sheet to choose a preset (BALANCED if they do not answer).
static func _term(world: WorldState, player: bool) -> void:
	var d := _d(world)
	var st: Dictionary = world.peek("pol").get("state", {})
	var g: Dictionary = st.get("government", {})
	var sig := "%s|%s|%s" % [String(st.get("era", "")), str(g.get("formed_month", -1)), String(g.get("pm_party", ""))]
	if sig != String(d["sig"]):
		d["sig"] = sig
		d["term_start"] = world.month
		d["preset"] = DEFAULT_PRESET
		d["levels"] = preset_levels(DEFAULT_PRESET)
		d["handed"] = {}
		d["changes"] = []
		d["setup_item"] = ""
		if player:
			d["setup_item"] = _post_setup(world)
	var sid := String(d["setup_item"])
	if sid != "":
		var o := Office.get_item(world, sid)
		if o.is_empty() or not (String(o["status"]) in Office.OPEN):
			var ans := String(o.get("answer", DEFAULT_PRESET))
			if ans in PRESETS and ans != String(d["preset"]):
				apply_preset(world, ans)
			d["setup_item"] = ""


static func _post_setup(world: WorldState) -> String:
	var opts: Array = []
	for p in PRESETS:
		opts.append({"id": p, "label": String(PRESET_NAMES[p]), "action": {}})
	var lines: Array = ["A new term: decide how much your ministers decide on their own.",
		"Trust my ministers: they make every call the law allows. Balanced: they make the routine calls and suggest the rest. Hands-on: everything comes to you.",
		"You can change any decision type later on the delegation sheet."]
	return Office.post(world, {"kind": "EMAIL", "role": "CHIEF_OF_STAFF", "category": "DELEGATION", "priority": 70,
		"subject": "Who decides what this term", "summary": " ".join(lines), "summary_lines": lines, "options": opts,
		"recommendation": DEFAULT_PRESET, "default_option": DEFAULT_PRESET, "deadline": world.month + SETUP_DEADLINE_M,
		"source": {"system": "delegation", "ref": String(world.peek("delegation").get("sig", ""))}})


## A case on the desk is a Cabinet matter by law whatever its type (per-case ceilings).
static func _cabinet_case(world: WorldState, item: Dictionary) -> bool:
	var src: Dictionary = item.get("source", {})
	if String(src.get("system", "")) == "road_licence":
		return bool(world.peek("road_licence").get(String(src.get("ref", "")), {}).get("needs_cabinet", false))
	return bool(item.get("hidden", {}).get("cabinet", false))


## The level an open office item is decided at, and its pre-selection for the desk: the minister's recommendation at
## SUGGEST, nothing at ME. Pure.
static func item_level(world: WorldState, item: Dictionary) -> String:
	var ty := case_type(item)
	if ty == "" or (item.get("options", []) as Array).is_empty():
		return ""
	return level(world, ty, _cabinet_case(world, item))


static func preselected(world: WorldState, item: Dictionary) -> String:
	return String(item.get("recommendation", "")) if on(world) and item_level(world, item) == "SUGGEST" else ""


## Ministers answer the open cases they may call. A minister outside their portfolio judges with part of their skill.
## Returns [{type, role, person, name, item, subject, answer, label, why}].
static func _ministers_call(world: WorldState) -> Array:
	var done: Array = []
	for o in Office.items(world, ["EMAIL", "CALL"]):
		var ty := case_type(o)
		if ty == "" or item_level(world, o) != "CALL":
			continue
		var role := holder_role(world, ty)
		var p := holder_person(world, role)
		var pick := _pick(world, o, ty, role, p)
		if pick == "":
			continue
		var r: Dictionary = Office.answer(world, String(o["id"]), pick, String(p["id"]))
		if not r.get("ok", false):
			continue
		var label := pick
		for x in o["options"]:
			if String(x.get("id", "")) == pick:
				label = String(x.get("label", pick))
		done.append({"type": ty, "role": role, "person": String(p["id"]), "name": String(p.get("name", "")), "item": String(o["id"]),
			"subject": String(o.get("subject", "")), "answer": pick, "label": label, "outside": outside_portfolio(world, ty),
			"why": String(o.get("author_note", ""))})
	return done


static func _pick(world: WorldState, o: Dictionary, ty: String, role: String, p: Dictionary) -> String:
	var ids: Array = (o["options"] as Array).map(func(x): return String(x.get("id", "")))
	var rec := String(o.get("recommendation", ""))
	if not outside_portfolio(world, ty) and rec in ids:
		return rec
	var hid: Dictionary = o.get("hidden", {})
	if not hid.get("options", {}).is_empty() and not p.is_empty():
		var OSx := _os()
		var skill := int(float(OSx.role_skill(p, role)) * OUTSIDE_SKILL)
		var pick := String(OSx._recommend(o, hid, OSx.traits(p)["lean"], skill, world.rng.stream("pol.delegation")))
		if pick in ids:
			return pick
	if rec in ids:
		return rec
	var dflt := String(o.get("default_option", ""))
	return dflt if dflt in ids else ""


## The monthly summary: what ministers decided this month (grouped by minister) and what waits on the desk. Kept in
## the delegation table (last month only); the player gets it as one REPORT.
static func _summary(world: WorldState, player: bool, decided: Array) -> void:
	var waiting: Array = []
	for o in Office.items(world, ["EMAIL", "CALL"]):
		var lv := item_level(world, o)
		if lv == "SUGGEST" or lv == "ME":
			waiting.append({"item": String(o["id"]), "type": case_type(o), "level": lv, "subject": String(o.get("subject", "")),
				"preselected": preselected(world, o)})
	var d := _d(world)
	var calls: Array = (d.get("calls", []) as Array).filter(func(x): return int(x["month"]) == world.month)
	d["calls"] = []
	decided = calls + decided
	d["summary"] = {"month": world.month, "decided": decided, "waiting": waiting}
	if not player or (decided.is_empty() and waiting.is_empty()):
		return
	var lines: Array = []
	var by_role := {}
	var roles: Array = []
	for x in decided:
		if not by_role.has(x["role"]):
			by_role[x["role"]] = []
			roles.append(x["role"])
		(by_role[x["role"]] as Array).append(x)
	for role in roles:
		var xs: Array = by_role[role]
		lines.append("%s (%s):" % [_role_title(world, String(role)), String(xs[0]["name"])])
		for x in xs:
			lines.append("  %s: %s%s%s" % [x["subject"], x["label"], (" (%s)" % String(x["why"]).to_lower().replace("_", " ")) if String(x["why"]) != "" else "",
				" [outside their portfolio]" if bool(x["outside"]) else ""])
	if not waiting.is_empty():
		var sug := waiting.filter(func(w): return w["level"] == "SUGGEST").size()
		lines.append("Waiting on your desk: %d (%d with a minister's choice pre-selected, %d left to you)." % [waiting.size(), sug, waiting.size() - sug])
	Office.post(world, {"kind": "REPORT", "role": "CHIEF_OF_STAFF", "priority": 35, "subject": "Monthly summary: what your ministers decided",
		"summary": "%d decision(s) taken by ministers, %d waiting on your desk." % [decided.size(), waiting.size()], "summary_lines": lines,
		"source": {"system": "delegation_summary", "ref": str(world.month)}})


# ======================================================================= reads (pure)

## Cases in month m: {type: n}.
static func month_counts(world: WorldState, m: int) -> Dictionary:
	return (world.peek("decision_case").get(str(m), {}) as Dictionary).duplicate()


## Cases summed over months [from_m, to_m]: {type: n}.
static func counts(world: WorldState, from_m: int, to_m: int) -> Dictionary:
	return _sum(world.peek("decision_case"), from_m, to_m)


## Office cases by who answered over [from_m, to_m]: {"MINISTER": n, "FM": n}.
static func who_counts(world: WorldState, from_m: int, to_m: int) -> Dictionary:
	return _sum(world.peek("decision_who"), from_m, to_m)


static func _sum(t: Dictionary, from_m: int, to_m: int) -> Dictionary:
	var out := {}
	for k in t:
		var m := int(k)
		if m < from_m or m > to_m:
			continue
		for ty in t[k]:
			out[ty] = int(out.get(ty, 0)) + int(t[k][ty])
	return out


static func total(c: Dictionary) -> int:
	var n := 0
	for k in c:
		n += int(c[k])
	return n


# ======================================================================= step 3: the systems' cases

## A system's decision as a case (step 3). spec = {type, ref (unique per open case, e.g. "ORDER|HOUSING|d:3"), subject,
## lines [..], options [{id, label, action}], hidden {option_id: {merit, lean {axis: milli}}}, default, cabinet?}.
## The options carry only what the government knows this month; merit = the system's own judgement (the code's
## choice), lean = which politics each option serves (on OfficeFeed.ai_answer's scale).
##   CALL     the minister picks with their lean and skill and the action runs now; returns the option id ("" when
##            its action failed); the monthly summary lists it.
##   SUGGEST / ME   the case goes to the desk (an EMAIL authored by the minister holding the type, pre-selected at
##            SUGGEST); returns "PENDING". An AI First Minister answers it at the end of the month; the player answers
##            or it falls to `default` at the deadline.
static func decide(world: WorldState, spec: Dictionary) -> String:
	var ty := String(spec["type"])
	assert(TYPES.has(ty), "unregistered decision type " + ty)
	var lv := level(world, ty, bool(spec.get("cabinet", false)))
	var role := holder_role(world, ty)
	var p := holder_person(world, role)
	var hid: Dictionary = spec.get("hidden", {})
	var pick := minister_pick(world, ty, spec["options"], hid, String(spec.get("default", "")))
	if lv == "CALL":
		var act: Dictionary = {}
		var label := pick
		for x in spec["options"]:
			if String(x.get("id", "")) == pick:
				act = x.get("action", {})
				label = String(x.get("label", pick))
		var r: Dictionary = Office._do(world, act)
		note(world, ty)
		if not r.get("ok", false):
			return ""
		# A minister's call leaves no office item: the record other systems read (Anni's road-safety law reads the
		# declined limits: data.ref, data.answer). OFFICIAL, no impact: the decision itself is not news.
		world.add_fact({"type": CALL_FACT, "owner": "pol", "subjects": [], "responsible": [{"actor": {"kind": "GOVERNMENT", "id": "government"}, "share": 1.0}],
			"impact": {}, "magnitude": 5, "visibility": "OFFICIAL",
			"data": {"ref": String(spec["ref"]), "type": ty, "answer": pick, "role": role, "person": String(p.get("id", ""))}})
		var d := _d(world)
		if not d.has("calls"):
			d["calls"] = []
		(d["calls"] as Array).append({"month": world.month, "type": ty, "role": role, "person": String(p.get("id", "")), "name": String(p.get("name", "")),
			"item": "", "subject": String(spec.get("subject", "")), "answer": pick, "label": label, "outside": outside_portfolio(world, ty), "why": ""})
		return pick
	var h2 := {"options": hid.duplicate(true), "case_type": ty}
	var lines: Array = spec.get("lines", [])
	var id := Office.post(world, {"kind": "EMAIL", "role": role if role != "FM" else "CHIEF_OF_STAFF", "category": "CASE", "priority": int(spec.get("priority", 50)),
		"subject": String(spec.get("subject", "")), "summary": " ".join(lines), "summary_lines": lines, "options": spec["options"],
		"default_option": String(spec.get("default", "")), "deadline": world.month + CASE_DEADLINE_M,
		"source": {"system": CASE_SYSTEM, "ref": String(spec["ref"])}, "hidden": h2})
	var o := Office.get_item(world, id)
	if not o.is_empty() and not p.is_empty() and pick != "":
		o["recommendation"] = pick   # the minister's own choice, as they would make the call
	return "PENDING"


const CASE_SYSTEM := "gov_case"
const CALL_FACT := "POL_CASE_CALLED"   # one per decision a minister makes at "make the call" (step 3 cases)
const CASE_DEADLINE_M := 2
const PICK_MERIT := 1.0             # weight of the system's judgement, times the minister's skill
const PICK_LEAN := 40.0             # weight of the minister's politics, times (1 − skill)


## The option the minister holding `type` would choose: the system's judgement (merit) weighed by their skill, bent by
## their lean (the less skilled, the more), blurred by inexperience. A minister outside their portfolio works at
## OUTSIDE_SKILL of their skill. Nobody holds it: the default.
static func minister_pick(world: WorldState, type: String, options: Array, hid: Dictionary, dflt: String) -> String:
	var role := holder_role(world, type)
	var p := holder_person(world, role)
	if p.is_empty() or options.is_empty():
		return dflt
	var OSx := _os()
	var sk := float(OSx.role_skill(p, role)) / 100.0
	if outside_portfolio(world, type):
		sk *= OUTSIDE_SKILL
	var tr: Dictionary = OSx.traits(p)
	var lean: Dictionary = tr.get("lean", {})
	var rng := world.rng.stream("pol.delegation")
	var best := dflt
	var bv := -INF
	for x in options:
		var oid := String(x.get("id", ""))
		var h: Dictionary = hid.get(oid, {})
		var al := 0.0
		for ax in h.get("lean", {}):
			al += float(h["lean"][ax]) / 1000.0 * float(lean.get(ax, 0)) / 100000.0
		var v := float(h.get("merit", 0)) * sk * PICK_MERIT + clampf(al, -1.0, 1.0) * (1.0 - sk) * PICK_LEAN + rng.randfn(0.0, 1.0) * (1.0 - sk) * 33.0
		if v > bv:
			bv = v
			best = oid
	return best


## An open case with this ref is waiting on the desk (the system must not post it again).
static func pending(world: WorldState, ref: String) -> bool:
	for o in world.peek("office_item").values():
		if o["status"] in Office.OPEN and String(o["source"].get("system", "")) == CASE_SYSTEM and String(o["source"].get("ref", "")) == ref:
			return true
	return false


## Office action route "DESK": the systems' own commit functions, run when a case is decided.
static func execute(world: WorldState, id: String, params: Dictionary) -> Dictionary:
	match id:
		"GOV_ORDER":
			return GovBuilder.commit_order(world, params)
		"GOV_COVER":
			return GovBuilder.commit_cover(world, params)
		"SAFE_LIMIT":
			var err := Transport.set_limit(world, String(params.get("link", "")), int(params.get("kmh", 0)))
			return {"ok": err == "", "error": err}
		"QUOTE_AWARD":
			return commit_quote_award(world, params)
		"QUOTE_REFUSE":
			return commit_quote_refuse(world, params)
		"GOV_UPGRADE":
			return GovBuilder.commit_upgrade(world, params)
		"WILDLIFE_BILL":
			return GovWildlife.commit_policy(world, params)
		"INST_BUDGET":
			return GovBuilder.commit_inst_budget(world, params)
		"INST_CLOSE":
			return EconFace.inst_close(world, String(params.get("facility", "")))
		"INST_REOPEN":
			return EconFace.inst_reopen(world, String(params.get("facility", "")))
	return {"ok": false, "error": "Unknown case action " + id}



# ======================================================================= step 3: builders' quotes (R8_BUILDERS)

const QUOTE_WHY := {"price": "above our own estimate", "budget": "beyond what the budget line can take", "wait": "it could not start for too long"}


## EconBuilders.award_round, for a public project with bids: award a quote or refuse them all, as a PUBLIC_QUOTE case.
## The government's own rule (EconBuilders.refusal) sets the merit: the best acceptable bid, or refusing when none is.
## The best-ranked bid is offered too even when the rule refuses it (a minister may pay over the estimate). Returns
## true when the case took the decision (made now or waiting on the desk).
static func quote_case(world: WorldState, p: Dictionary, ranked: Array, chosen: String, why: String) -> bool:
	if ranked.is_empty():
		return false
	var pid := String(p["id"])
	var est := int(p.get("est_cost", 0))
	var opts: Array = []
	var hid := {}
	var offered := {}
	for b in ranked:
		var org := String(b["org"])
		if offered.has(org) or not (org == chosen or org == String(ranked[0]["org"])):
			continue
		offered[org] = true
		var oid := "AWARD_" + org
		var name := String(world.peek("org").get(org, {}).get("name", org))
		opts.append({"id": oid, "label": "Award it to %s (%d cr, %+d%% on our estimate; starts in %d months)" % [name, int(b["price"]) / CoreUtil.S,
			int(round(100.0 * (float(b["price"]) / float(maxi(1, est)) - 1.0))), int(b.get("wait", 0))],
			"action": {"via": "DESK", "id": "QUOTE_AWARD", "params": {"project": pid, "org": org}}})
		hid[oid] = {"merit": 30 if org == chosen else 0, "lean": {}}
	opts.append({"id": "REFUSE", "label": "Refuse the quotes (the tender opens again in a few months)",
		"action": {"via": "DESK", "id": "QUOTE_REFUSE", "params": {"project": pid, "why": why}}})
	hid["REFUSE"] = {"merit": 30 if chosen == "" else 0, "lean": {}}
	var lines: Array = ["%d builder(s) quoted for the public %s in %s; our estimate is %d cr." % [ranked.size(), String(p.get("type", "")).to_lower(),
		String(world.peek("district").get(String(p.get("district", "")), {}).get("name", p.get("district", ""))), est / CoreUtil.S]]
	if chosen == "" and why != "":
		lines.append("The best quote is %s." % String(QUOTE_WHY.get(why, why)))
	decide(world, {"type": "PUBLIC_QUOTE", "ref": "QUOTE|" + pid, "subject": "Quotes for the public %s" % String(p.get("type", "")).to_lower(),
		"lines": lines, "options": opts, "hidden": hid, "default": ("AWARD_" + chosen) if chosen != "" else "REFUSE"})
	return true


## Desk route QUOTE_AWARD: the contract, if the tender is still open and the bid still stands.
static func commit_quote_award(world: WorldState, p: Dictionary) -> Dictionary:
	var pid := String(p.get("project", ""))
	var pr: Dictionary = world.peek("project").get(pid, {})
	if pr.is_empty() or String(pr["status"]) != "TENDER" or not (pr["bids"] as Array).any(func(b): return String(b["org"]) == String(p.get("org", ""))):
		return {"ok": true, "error": ""}   # the tender moved on meanwhile: nothing to award
	EconFace.construction_award(world, pid, String(p["org"]))
	return {"ok": true, "error": ""}


## Desk route QUOTE_REFUSE: refuse the quotes standing now (re-ranked).
static func commit_quote_refuse(world: WorldState, p: Dictionary) -> Dictionary:
	var pr: Dictionary = world.table("project").get(String(p.get("project", "")), {})
	if pr.is_empty() or String(pr["status"]) != "TENDER" or (pr["bids"] as Array).is_empty():
		return {"ok": true, "error": ""}
	EconFace.builders_refuse(world, pr, EconFace.construction_ranked_bids(world, pr), String(p.get("why", "")))
	return {"ok": true, "error": ""}

