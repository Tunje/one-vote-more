extends RefCounted
## Month one's builders (plan 9.12 and section 3; rebuild-building.md 4.1; the step-2 brief).
##
## "5 building companies and alot of oppretunity"; "they are companies from the world". The five arrive from the home
## world already operating: owned by the home world, with their crews and equipment, and with no plant (a builder
## from the home world needs no building in order to exist, plan section 3). Their sizes: one large, two average, two
## small (rebuild-building 4.1), so three full builder units. Their crews are settlers of the Landing, hired on day one
## like any hire (Maja's Households.hire), so a job is recorded once (plan 9.2).
##
## The public works department (plan 12.11, 99) is the government's own builder, not one of the five: average size,
## owned by the state, hired the same way. It builds at cost when the government commissions it, which comes with the
## purse; until then it has no jobs.
##
## What is NOT here: their money (Wilma's starting numbers move it into their accounts), their price (Company.create
## sets the type table's starting price per BW), their book and their work (step 3).
##
## Every company made and every crew hired is in the log: Company.create writes OPEN and Households.hire writes HIRE.
## This file adds one LAND row per builder saying why it exists, and one CREW row when a crew comes up short.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const Households := preload("res://sim/population/households.gd")

const TYPE := "BUILDER"
const CREW_KEY := "crew"  # a builder with no plant keeps its crew under this key (Bob's company record)
## Highest first: the household side fills a post with its own skill or a higher one (never lower), so hiring the
## specialist and skilled posts first keeps the scarce skilled people for the posts that need them.
const TIERS := ["Sp", "S", "G"]
## The five, in the order they are made (and so take their crews): name, size. New names, none of the old game's.
const HOME_WORLD := [["Halcyon Construction", "LARGE"], ["Ironbridge Builders", "AVERAGE"], ["Keel and Beam", "AVERAGE"],
	["Northgate Works", "SMALL"], ["Sable Line Building", "SMALL"]]
const PUBLIC_WORKS := ["Colony Public Works", "AVERAGE"]
## Marks on the record, so the builders are found by what they are, not by their names (a screen or a takeover can
## rename a company; Bob's review).
const ORIGIN_HOME := "HOME_WORLD_LANDING"
const ORIGIN_PUBLIC := "PUBLIC_WORKS"
const OWNER_HOME := {"kind": "HOME_WORLD", "holders": {"home_world": 1000}}
const OWNER_STATE := {"kind": "STATE", "holders": {"gov": 1000}}


## Makes the five home-world builders and the public works department in `area` (the Landing), each with its crew hired
## from that area's settlers. Returns {"home_world": [ids in HOME_WORLD order], "public_works": id}. Called once, in
## month one; a second call finds them and makes nothing. The guard is all-or-nothing: if any of the six exists, nothing
## is made (land() makes all six together, so a partial set cannot come from it).
static func land(world: WorldState, area: String) -> Dictionary:
	var have := existing(world)
	if not (have["home_world"] as Array).is_empty() or String(have["public_works"]) != "":
		return have
	var ids: Array = []
	for i in HOME_WORLD.size():
		var spec: Array = HOME_WORLD[i]
		ids.append(_make(world, area, String(spec[0]), String(spec[1]), OWNER_HOME, ORIGIN_HOME, i,
			"arrived from the home world, operating"))
	var pw := _make(world, area, String(PUBLIC_WORKS[0]), String(PUBLIC_WORKS[1]), OWNER_STATE, ORIGIN_PUBLIC, 0,
		"the government's own builder")
	return {"home_world": ids, "public_works": pw}


## The builders land() made, found by the origin mark on their records, the five in their landing order (pure).
static func existing(world: WorldState) -> Dictionary:
	var five: Array = []
	var pw := ""
	for cid in Company.ids(world):
		var c := Company.record(world, cid)
		match String(c.get("origin", "")):
			ORIGIN_HOME:
				five.append([int(c.get("origin_n", 0)), cid])
			ORIGIN_PUBLIC:
				pw = cid
	five.sort()
	var ids: Array = []
	for e in five:
		ids.append(e[1])
	return {"home_world": ids, "public_works": pw}


## A builder's building work in a month at its present crew, in milli-BW: one BW per crew member, less its size's
## penalty (rebuild-building 2). Pure; step 3's book reads it.
static func bw_milli(world: WorldState, cid: String) -> int:
	var c := Company.record(world, cid)
	if c.is_empty():
		return 0
	var persons := Company.staff_count(world, cid, "", CREW_KEY)  # persons x S
	return persons * (1000 - TypeTable.penalty_pm(String(c["size"]))) / 1000


static func _make(world: WorldState, area: String, name: String, size: String, owner: Dictionary, origin: String,
		order: int, why: String) -> String:
	var cid := Company.create(world, TYPE, size, owner, name, {"origin": origin, "origin_n": order, "area": area})
	if cid == "":
		Logbook.note(world, "LAND", name, "builder NOT made: the company record refused it", {"size": size, "owner": owner})
		return ""
	var posts := TypeTable.posts(TYPE, size)
	Logbook.note(world, "LAND", cid, "builder in month one", {"size": size, "owner": String(owner["kind"]), "area": area,
		"posts": posts.duplicate(), "why": why})
	var short := {}
	for t in TIERS:
		var want := int(posts.get(t, 0))
		if want <= 0:
			continue
		var got := Households.hire(world, cid, CREW_KEY, t, area, want, {"why": "month one crew", "builder": name})
		if got < want:
			short[t] = [want, got]
	if not short.is_empty():
		Logbook.note(world, "CREW", cid, "crew short in month one", {"wanted_got": short})
	return cid
