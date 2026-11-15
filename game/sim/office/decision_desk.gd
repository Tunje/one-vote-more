extends RefCounted
## Who decides, build step 1 (planning/design-delegation.md; Maja, 2026-11-15): the registry of decision types and a
## counter of cases by type and month. Opt-in (flag DELEGATION): without it note() returns before touching the world,
## so games without the flag reproduce exactly.
##
## Step 1 only counts. Each system that takes a government decision calls note(world, type) when it takes it; nothing
## changes who decides. Steps 2-4 (levels per type, the term-start screen, the monthly summary, trust) build on this.
##
## Table "decision_case": {"<month>": {type: n}} (string keys, int values; one small entry per month with cases).

const FLAG := "DELEGATION"

## Legal ceiling (section 4 of the design note):
##   MINISTER   a minister may make the call alone
##   CABINET    a Cabinet matter by law: reaches the First Minister's desk at least as a suggestion
##   PARLIAMENT the Cabinet decides to table it, Parliament votes
const CEILINGS := ["MINISTER", "CABINET", "PARLIAMENT"]

## Decision types. portfolio: the office role (OfficeStaff.ROLES) of the minister it belongs to; "fallback" is used
## when that portfolio is not in the Cabinet (AGRICULTURE needs flag AGRI_MIN). FM = the First Minister's own.
## src: the system that reports it.
const TYPES := {
	# GovBuilder: the state's capital programme
	"BUILD_HOUSING": {"name": "Public housing block", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_SCHOOL": {"name": "New school", "portfolio": "SERVICES", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_CLINIC": {"name": "New clinic", "portfolio": "SERVICES", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_ROAD": {"name": "Road works", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_STATE_FARM": {"name": "State farm", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_UTILITY": {"name": "Power, water or processing plant", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_BAKERY": {"name": "Public bakery", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILD_DEPOT": {"name": "Port depot", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"PUBLIC_WORKS": {"name": "Public works against unemployment", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "gov_builder"},
	"UPGRADE_FACILITY": {"name": "Upgrade a colony workshop", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"RETENDER_PROJECT": {"name": "Re-tender a public project", "portfolio": "ENGINEER", "ceiling": "MINISTER", "src": "gov_builder"},
	"BUILDER_GRANT": {"name": "Grant offer to private builders", "portfolio": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"FOOD_RESERVE_RELEASE": {"name": "Open the food reserve", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	"GRANT_COVERAGE": {"name": "Where a family grant programme lands", "portfolio": "AGRICULTURE", "fallback": "ECON_ADVISER", "ceiling": "MINISTER", "src": "gov_builder"},
	# GovWildlife: the yearly (or after a death) wildlife policy review
	"WILDLIFE_REVIEW": {"name": "Wildlife policy review", "portfolio": "ENVIRONMENT", "ceiling": "MINISTER", "src": "gov_wildlife"},
	# Legislature: laws
	"BILL": {"name": "Table a bill", "portfolio": "FM", "ceiling": "PARLIAMENT", "src": "legislature"},
	"ORDINANCE": {"name": "Commander's ordinance", "portfolio": "FM", "ceiling": "CABINET", "src": "legislature"},
	# HomeWorld: the colony's side of the charter
	"CHARTER_PETITION": {"name": "Petition the home world", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	"CHARTER_REFUSAL": {"name": "Refuse the charter quota", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	"INDEPENDENCE_VOTE": {"name": "Put independence to Parliament", "portfolio": "HOME_LIAISON", "ceiling": "PARLIAMENT", "src": "home_world"},
	# Office items answered (by the player, an AI First Minister, a delegate, or expired to the default)
	"UNION_DEMAND": {"name": "Public-sector union demand", "portfolio": "LABOUR_LIAISON", "ceiling": "MINISTER", "src": "office"},
	"STAFF_DECISION": {"name": "Staff decision request", "portfolio": "CHIEF_OF_STAFF", "ceiling": "MINISTER", "src": "office"},
	"COMPETITION_REVIEW": {"name": "Merger under competition law", "portfolio": "ECON_ADVISER", "ceiling": "CABINET", "src": "office"},
	"OFFICE_OTHER": {"name": "Other office decision", "portfolio": "FM", "ceiling": "MINISTER", "src": "office"},
}

## GovBuilder facility types -> decision type (public-works orders are PUBLIC_WORKS whatever they build).
const BUILD_TYPE := {"HOUSING": "BUILD_HOUSING", "SCHOOL": "BUILD_SCHOOL", "CLINIC": "BUILD_CLINIC", "ROAD": "BUILD_ROAD",
	"FARM": "BUILD_STATE_FARM", "POWER": "BUILD_UTILITY", "WATERWORKS": "BUILD_UTILITY", "PROCESSING": "BUILD_UTILITY",
	"COMPONENTS": "BUILD_UTILITY", "BAKERY": "BUILD_BAKERY", "DEPOT": "BUILD_DEPOT"}
## Office item categories -> decision type.
const OFFICE_TYPE := {"UNION_DEMAND": "UNION_DEMAND", "STAFF_DECISION": "STAFF_DECISION", "COMPETITION": "COMPETITION_REVIEW"}


static func on(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(FLAG) and not EconUtil.off(world, FLAG)


## A system took a decision of `type` this month. No-op without the flag. Unknown types are a programming error.
static func note(world: WorldState, type: String) -> void:
	if not on(world):
		return
	assert(TYPES.has(type), "unregistered decision type " + type)
	var t := world.table("decision_case")
	var key := str(world.month)
	if not t.has(key):
		t[key] = {}
	var row: Dictionary = t[key]
	row[type] = int(row.get(type, 0)) + 1


## GovBuilder's commissioning: the decision type of an order of facility `ftype` on budget line `line`.
static func build_type(ftype: String, line: String) -> String:
	if line == "ECON_BUDGET_PUBLIC_WORKS":
		return "PUBLIC_WORKS"
	return String(BUILD_TYPE.get(ftype, "BUILD_UTILITY"))


## An office item was answered or expired: counts EMAILs and CALLs from the government's side (party staff mail is
## the party's business, not the government's).
static func note_office(world: WorldState, item: Dictionary) -> void:
	if not on(world):
		return
	if not (String(item.get("kind", "")) in ["EMAIL", "CALL"]) or String(item.get("from", {}).get("kind", "")) == "PARTY_STAFF":
		return
	note(world, String(OFFICE_TYPE.get(String(item.get("category", "")), "OFFICE_OTHER")))


## The portfolio that holds `type` in this world (FM when it is the First Minister's own).
static func portfolio(world: WorldState, type: String) -> String:
	var d: Dictionary = TYPES.get(type, {})
	var p := String(d.get("portfolio", "FM"))
	if d.has("fallback") and not (load("res://sim/staff/office_staff.gd").portfolios(world) as Array).has(p):
		return String(d["fallback"])
	return p


# ======================================================================= reads (pure)

## Cases in month m: {type: n}.
static func month_counts(world: WorldState, m: int) -> Dictionary:
	return (world.peek("decision_case").get(str(m), {}) as Dictionary).duplicate()


## Cases summed over months [from_m, to_m]: {type: n}.
static func counts(world: WorldState, from_m: int, to_m: int) -> Dictionary:
	var out := {}
	var t := world.peek("decision_case")
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
