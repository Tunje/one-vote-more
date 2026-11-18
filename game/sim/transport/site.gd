extends RefCounted
## Terra, rebuild step 2 (planning/rebuild-company.md 3, 5, 9.8, 12.1 points 3–6; rebuild-step2-brief.md): where a plant
## stands. Preload, no class_name: `const Site := preload("res://sim/transport/site.gd")`.
##
## - The place is recorded ONCE, on the map, keyed by the plant's id (agreed with Bob): a TOWN plant holds town-grid
##   cells (TownGrid's table "town": cell -> [id, form, homes]); a COUNTRY plant holds its 3 km tile (table "site",
##   "placed"). The company record keeps no place. Homes are recorded once too, in the cells (Wilma's step-2 decision);
##   a landlord's client places are TownGrid.homes_of(world, plant_id).
## - Which setting a type stands in is the type table's column (TypeTable.setting: TOWN or COUNTRY).
## - A plan picks its site before it signs ("chosen by its plan with the siting code: the best-scoring free place for
##   its type", 12.1 point 5): choose_country / choose_town are pure; hold() keeps the site under the plan's id; open()
##   moves it to the plant's id the day the plant opens. place() lays a plant directly (the government's month-one
##   plants, the landing shelters).
## - A square holds one full size of company PER TYPE (5, 12.1 point 4): the 3 km tile in the country, the 400 m street
##   block in a town. The chooser offers no place where the type's sixths would pass 6.
## - Land belongs to the colony until titled (land law: no row = the colony's, Anni). Its price is ours (Wilma's step-2
##   brief): 10% of the building's bill × the value of its place / 1000 (9.8, 12.1 point 3). land_value_milli is
##   registered as land law's land_value_fn (PlanetProvider._init).
## - Zoning is land law's one record (Anni): a place whose zone does not allow the type's use is never offered.
## - Every decision and deed writes a Logbook row (kind SITE).
##
## Table "site": {"placed": {id: {"tile": "x,y", "month": m}}, "hold": {plan id: {"type", "sixths", "month"}}, "rev"}.
## "rev" is part of ColonyLayout.key.

const Company := preload("res://sim/economy/company.gd")
const TypeTable := preload("res://sim/economy/type_table.gd")
const LandLaw := preload("res://sim/law/land_law.gd")

const LAND_SHARE := 0.10            # land = 10% of the building's bill × value / 1000 (9.8)
## What the land must be, per type, in the country (Terrain codes). Anything else: BUILD_TERRAIN.
const COUNTRY_TERRAIN := {"FARM": ["f", "n", "."], "MINE": ["o", "x", "k", "h"]}
## Score parts (country): each point is worth one tile nearer the nearest settlement.
const SCORE := {"road": 3.0, "fertile": 4.0, "ore": 6.0, "river": 5.0, "next_to_homes": -6.0}
## Every country type but a farm keeps away from homes (next_to_homes).
const HOME_BILL_DIV := 50           # a LANDLORD bill is for a block of 50 homes (rebuild-type-table.md 8)


# ================================================================== what a type is, on the land

## TOWN (on town-grid cells) or COUNTRY (on a 3 km tile): the type table's column.
static func setting(type: String) -> String:
	return TypeTable.setting(type)


## For land law's zones (ZONE_USES): HOUSING, FARM, MINE, INDUSTRY or SERVICE. Land law's own mapping (Anni: the
## zones are the law's, so the mapping lives in one place).
static func zone_use(type: String) -> String:
	return LandLaw.use_of(type)


## Land law's key for a town cell: "c:fx,fy" (Anni: a cell with no title row of its own takes its tile's).
static func cell_key(cell) -> String:
	var c := ColonyLayout.as_tile(cell)
	return "c:%d,%d" % [c.x, c.y]


## May this type stand here under land law's zoning? `place`: a town cell's key "c:fx,fy" (the cell's own zone), or a
## country tile in any tile form (the tile's zone).
static func zone_allows(world: WorldState, place, type: String) -> bool:
	var key: String = place if place is String and String(place).begins_with("c:") else Terrain.key(ColonyLayout.as_tile(place).x, ColonyLayout.as_tile(place).y)
	return zone_use(type) in LandLaw.ZONE_USES.get(LandLaw.zone_of(world, key), [])


# ================================================================== reads

static func _t(world: WorldState) -> Dictionary:
	return world.peek("site")


## Part of ColonyLayout.key: changes whenever a place is laid, held, moved or freed.
static func sig(world: WorldState) -> String:
	return "|s%d" % int(_t(world).get("rev", 0))


## Where a plant (or a plan holding its site) stands: {id, where "TOWN"|"COUNTRY", tile "x,y", cells ["fx,fy"...],
## town, block, homes}. {} if it has no place.
static func of(world: WorldState, id: String) -> Dictionary:
	var pl: Dictionary = _t(world).get("placed", {})
	if pl.has(id):
		return {"id": id, "where": "COUNTRY", "tile": String(pl[id]["tile"]), "cells": [], "town": "", "block": "", "homes": 0}
	var cs := TownGrid.cells_of(world, id)
	if cs.is_empty():
		return {}
	var t := TownGrid.tile_of(cs[0])
	return {"id": id, "where": "TOWN", "tile": Terrain.key(t.x, t.y), "cells": cs, "town": TownGrid.town_of(world, id),
		"block": TownGrid.block_of(cs[0]), "homes": TownGrid.homes_of(world, id)}


## Every id with a place (plants and held plan sites), sorted.
static func ids(world: WorldState) -> Array:
	var out := {}
	for k in _t(world).get("placed", {}):
		out[k] = true
	for k in TownGrid.ids(world):
		out[k] = true
	return CoreUtil.sorted_keys(out)


## What stands at a place: {type, sixths, plan (true for a held plan site), closed, company}. {} if unknown.
static func what(world: WorldState, id: String) -> Dictionary:
	var h: Dictionary = _t(world).get("hold", {}).get(id, {})
	if not h.is_empty():
		return {"type": String(h["type"]), "sixths": int(h["sixths"]), "plan": true, "closed": false, "company": ""}
	var p := Company.plant(world, id)
	if p.is_empty():
		return {}
	return {"type": String(p.get("type", "")), "sixths": int(p.get("sixths", 6)), "plan": false,
		"closed": bool(p.get("closed", false)), "company": String(p.get("company", ""))}


## The square a place counts in: "t:x,y" (the country tile) or the street block "b:bx,by".
static func square_of(site: Dictionary) -> String:
	if String(site.get("where", "")) == "TOWN":
		var cs: Array = site.get("cells", [])
		return TownGrid.block_of(cs[0]) if not cs.is_empty() else String(site.get("block", ""))
	return "t:" + String(site.get("tile", ""))


## Sixths of `type` already in a square (plants and held plan sites; closed buildings still stand, 12.1 point 6).
static func square_sixths(world: WorldState, square: String, type: String, except: String = "") -> int:
	var n := 0
	for id in ids(world):
		if id == except:
			continue
		var w := what(world, id)
		if w.is_empty() or String(w["type"]) != type:
			continue
		if square_of(of(world, id)) == square:
			n += int(w["sixths"])
	return n


# ================================================================== choosing (pure)

## The best free places in the country for a plant of `type` and `sixths`, best first: [{where "COUNTRY", tile "x,y",
## score, parts}]. Free: land, not the river or the sea, the type's terrain, not a settlement's tile or a town's, its
## zone allows the type, and its square has room for the type. Anywhere on the colony map: distance from the nearest
## settlement counts against a place (a tile a point), so a mine goes to the nearest ore worth it. Pure.
static func choose_country(world: WorldState, type: String, sixths: int, n: int = 5) -> Array:
	if not Terrain.ready(world):
		return []
	var setl := ColonyLayout.settlements(world)
	var homes_t := {}
	for s in setl:
		for t in s["tiles"]:
			homes_t[Terrain.key(t.x, t.y)] = true
	for k in TownGrid.town_tiles(world):
		homes_t[k] = true
	var road_t := {}
	var links := Transport._links(world)
	for lid in links:
		if int(links[lid].get("globe", 0)) == 0:
			for ti in links[lid].get("path", []):
				road_t[int(ti)] = true
	var codes: Array = COUNTRY_TERRAIN.get(type, ColonyLayout.BUILD_TERRAIN)
	var used := _country_sixths(world, type)
	var rows: Array = []
	for y in Terrain.H:
		for x in Terrain.W:
			var key := Terrain.key(x, y)
			var code := Terrain.at(world, x, y)
			if homes_t.has(key) or not code in codes:
				continue
			var d := INF
			for s in setl:
				d = minf(d, Vector2(s["tile"]).distance_to(Vector2(x, y)))
			if int(used.get(key, 0)) + sixths > 6:
				continue
			if not zone_allows(world, Vector2i(x, y), type):
				continue
			var parts := {"distance": -snappedf(d, 0.01)}
			if _near_road(road_t, x, y):
				parts["road"] = SCORE["road"]
			if type == "FARM" and code in ["f", "n"]:
				parts["fertile"] = SCORE["fertile"]
			if type == "MINE" and code in ["o", "x"]:
				parts["ore"] = SCORE["ore"]
			if type == "WATERWORKS" and ColonyLayout.near_code(world, Vector2i(x, y), "r", 1):
				parts["river"] = SCORE["river"]
			if type != "FARM" and _next_to(homes_t, x, y):
				parts["next_to_homes"] = SCORE["next_to_homes"]
			var s := 0.0
			for k in parts:
				s += float(parts[k])
			rows.append({"where": "COUNTRY", "tile": key, "score": snappedf(s, 0.01), "parts": parts})
	rows.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]) or (float(a["score"]) == float(b["score"]) and _key_less(String(a["tile"]), String(b["tile"]))))
	return rows.slice(0, n)


static func _key_less(a: String, b: String) -> bool:
	var ay := int(a.get_slice(",", 1))
	var by := int(b.get_slice(",", 1))
	return ay < by or (ay == by and int(a.get_slice(",", 0)) < int(b.get_slice(",", 0)))


static func _near_road(road_t: Dictionary, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if road_t.has((y + dy) * Terrain.W + (x + dx)):
				return true
	return false


static func _next_to(tiles: Dictionary, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if tiles.has(Terrain.key(x + dx, y + dy)):
				return true
	return false


## {"x,y": sixths of `type`} over the country tiles.
static func _country_sixths(world: WorldState, type: String) -> Dictionary:
	var out := {}
	var pl: Dictionary = _t(world).get("placed", {})
	for id in pl:
		var w := what(world, String(id))
		if not w.is_empty() and String(w["type"]) == type:
			var k := String(pl[id]["tile"])
			out[k] = int(out.get(k, 0)) + int(w["sixths"])
	return out


## The best free cells in a town (an area's id) for a plant of `type` and `sixths`, best first: [{where "TOWN", town,
## cells [the first cell], tile, block, score, parts}]. The town grid's scoring (what draws the type, what keeps it
## away), its blocked cells (taken, terrain, zone, a block another area owns), and the square: the street block must
## have room for the type. A plant with homes takes further cells next to the first when it is laid. Pure.
static func choose_town(world: WorldState, town: String, type: String, sixths: int, n: int = 5) -> Array:
	var out: Array = []
	for r in TownGrid.site_scores(world, town, type, maxi(n * 4, 20)):
		var blk := TownGrid.block_of(r["cell"])
		if square_sixths(world, blk, type) + sixths > 6:
			continue
		out.append({"where": "TOWN", "town": town, "cells": [String(r["cell"])], "tile": String(r["tile"]), "block": blk,
			"score": float(r["score"]), "parts": r["parts"]})
		if out.size() >= n:
			break
	return out


## Why choose_country / choose_town found no site for this type and size (pure; called only when they found none,
## for the founding row): {"cause": ZONED | FULL | NO_LAND | NO_MAP, "why": words, "counts": what turned the
## places away}. ZONED when the zone turned away places that had room for it: "the land is zoned against farms" (the
## user, 2026-11-18, 61c: the government stops founding by "stopping land being allowed to be built on"; Ella's
## request). FULL when every place of its terrain has its square full; BLOCKED when a town's cells are there but blocked
## for another reason; NO_LAND when there is none of its terrain.
static func why_no_site(world: WorldState, area: String, type: String, sixths: int) -> Dictionary:
	var counts := {"candidates": 0, "zoned": 0, "full": 0, "other": 0}
	if setting(type) == "COUNTRY":
		if not Terrain.ready(world):
			return {"cause": "NO_MAP", "why": "no free site: the map is not ready", "counts": counts}
		var homes_t := {}
		for st in ColonyLayout.settlements(world):
			for t in st["tiles"]:
				homes_t[Terrain.key(t.x, t.y)] = true
		for k in TownGrid.town_tiles(world):
			homes_t[k] = true
		var codes: Array = COUNTRY_TERRAIN.get(type, ColonyLayout.BUILD_TERRAIN)
		var used := _country_sixths(world, type)
		for y in Terrain.H:
			for x in Terrain.W:
				var key := Terrain.key(x, y)
				if homes_t.has(key) or not Terrain.at(world, x, y) in codes:
					continue
				counts["candidates"] += 1
				if int(used.get(key, 0)) + sixths > 6:
					counts["full"] += 1
				elif not zone_allows(world, Vector2i(x, y), type):
					counts["zoned"] += 1
	else:
		var blocked: Dictionary = TownGrid.blocked_counts(world, area, type)
		for why in blocked:
			counts["candidates"] += int(blocked[why])
			if String(why) == TownGrid.ZONE_BLOCK:
				counts["zoned"] += int(blocked[why])
			elif String(why) != "":
				counts["other"] += int(blocked[why])
		for r in TownGrid.site_scores(world, area, type, 1 << 30):
			if square_sixths(world, TownGrid.block_of(r["cell"]), type) + sixths > 6:
				counts["full"] += 1
	var what := type.to_lower() + "s"
	if int(counts["zoned"]) > 0:
		return {"cause": "ZONED", "why": "the land is zoned against %s" % what, "counts": counts}
	if int(counts["full"]) > 0:
		return {"cause": "FULL", "why": "no free site: every square of its kind is full", "counts": counts}
	if int(counts["other"]) > 0:   # a town's cells there but blocked otherwise (a country building's site, another town's block; Maja)
		return {"cause": "BLOCKED", "why": "no free site: every place is blocked", "counts": counts}
	return {"cause": "NO_LAND", "why": "no free site: no land it can stand on", "counts": counts}


## The most homes a plant of this type and size holds: its type row's client places (a LANDLORD's full unit is a block
## of 50 homes; smaller sizes their share, less the size's penalty). 0 for a type that has no homes.
static func homes_cap(type: String, sixths: int) -> int:
	if type != "LANDLORD":
		return 0
	return TypeTable.clients(type, String({1: "FAMILY", 2: "SMALL", 4: "AVERAGE", 6: "LARGE"}.get(sixths, "LARGE")))


# ================================================================== writes

static func _table(world: WorldState) -> Dictionary:
	var t := world.table("site")
	if not t.has("placed"):
		t["placed"] = {}
		t["hold"] = {}
		t["rev"] = 0
	return t


static func _bump(t: Dictionary) -> void:
	t["rev"] = int(t.get("rev", 0)) + 1


## Lay a plant on its site (a row of choose_country / choose_town). `homes` for a plant with homes (a LANDLORD): its
## cells take that many homes in the town's first allowed form. → "" or why not.
static func place(world: WorldState, plant_id: String, site: Dictionary, homes: int = 0) -> String:
	var p := Company.plant(world, plant_id)
	if p.is_empty():
		return "Unknown plant '%s'" % plant_id
	return _lay(world, plant_id, String(p.get("type", "")), int(p.get("sixths", 6)), site, homes, "placed")


## A plan keeps its chosen site until it opens or is given up. → "" or why not.
static func hold(world: WorldState, plan_id: String, type: String, sixths: int, site: Dictionary, homes: int = 0) -> String:
	if not of(world, plan_id).is_empty():
		return "%s already holds a site" % plan_id
	var t := _table(world)
	t["hold"][plan_id] = {"type": type, "sixths": sixths, "month": world.month}
	var why := _lay(world, plan_id, type, sixths, site, homes, "held")
	if why != "":
		t["hold"].erase(plan_id)
	return why


## The plan's site becomes its plant's, the day the plant opens. → "" or why not.
static func open(world: WorldState, plan_id: String, plant_id: String) -> String:
	var t := _table(world)
	if not t["hold"].has(plan_id):
		return "%s holds no site" % plan_id
	var s := of(world, plan_id)
	if String(s.get("where", "")) == "COUNTRY":
		t["placed"][plant_id] = t["placed"][plan_id]
		t["placed"].erase(plan_id)
	else:
		TownGrid.rekey(world, plan_id, plant_id)
	t["hold"].erase(plan_id)
	_bump(t)
	Logbook.note(world, "SITE", plant_id, "opened on its plan's site", {"where": s.get("where", ""), "tile": s.get("tile", "")},
		{}, "", plan_id)
	return ""


## A plan given up, or a building torn down: its place is free again.
static func release(world: WorldState, id: String, why: String = "") -> void:
	var t := _table(world)
	var s := of(world, id)
	if s.is_empty():
		t["hold"].erase(id)
		return
	if String(s["where"]) == "COUNTRY":
		t["placed"].erase(id)
	else:
		TownGrid.free_cells(world, id)
	t["hold"].erase(id)
	_bump(t)
	Logbook.note(world, "SITE", id, "released", {"why": why, "where": s["where"], "tile": s["tile"]}, {})


static func _lay(world: WorldState, id: String, type: String, sixths: int, site: Dictionary, homes: int, verb: String) -> String:
	if not of(world, id).is_empty() and verb == "placed":
		return "%s already stands somewhere" % id
	var where := String(site.get("where", ""))
	if where != setting(type):
		return "A %s stands in the %s" % [type.to_lower(), setting(type).to_lower()]
	if homes > 0 and homes > homes_cap(type, sixths):
		return "A %s of this size has room for %d homes, not %d" % [type.to_lower(), homes_cap(type, sixths), homes]
	var sq := square_of(site)
	if square_sixths(world, sq, type, id) + sixths > 6:
		return "No room for another %s in %s (one full size per type)" % [type.to_lower(), sq]
	var t := _table(world)
	if where == "COUNTRY":
		var tile := ColonyLayout.as_tile(String(site.get("tile", "")))
		if not Terrain.at(world, tile.x, tile.y) in COUNTRY_TERRAIN.get(type, ColonyLayout.BUILD_TERRAIN):
			return "A %s cannot stand on %s" % [type.to_lower(), String(Terrain.NAMES.get(Terrain.at(world, tile.x, tile.y), "this"))]
		if not zone_allows(world, tile, type):
			return "The zone does not allow a %s" % type.to_lower()
		t["placed"][id] = {"tile": Terrain.key(tile.x, tile.y), "month": world.month}
	else:
		var town := String(site.get("town", ""))
		var cells: Array = site.get("cells", [])
		if town == "" or cells.is_empty():
			return "A town site needs its town and a cell"
		var why := TownGrid.lay(world, town, id, type, String(cells[0]), homes)
		if why != "":
			return why
	_bump(t)
	var s := of(world, id)
	Logbook.note(world, "SITE", id, verb, {"type": type, "sixths": sixths, "where": where, "tile": s.get("tile", ""),
		"cells": (s.get("cells", []) as Array).size(), "homes": int(s.get("homes", 0)), "score": site.get("score", 0.0),
		"parts": site.get("parts", {}), "square": sq}, {})
	return ""


## Monthly (NATURE): a row for each farm with a low yield this month; places whose id is neither a plant nor a held
## plan are freed (a record deleted elsewhere).
static func step_month(world: WorldState) -> void:
	var t: Dictionary = _t(world)
	if t.is_empty():
		return
	note_low_yields(world)
	for id in ids(world):
		if what(world, id).is_empty():
			release(world, id, "no plant or plan of this id")


# ================================================================== land price

## A building's bill in whole credits at the starting prices (the type table: building work, material and components
## in milli-units, each at its starting price in milli-credits).
static func bill_credits(type: String, size: String = "LARGE") -> int:
	if not TypeTable.has_type(type):
		return 0
	var b := TypeTable.bill(type, size)
	var milli := int(b["bw"]) * TypeTable.start_price("BW") + int(b["material"]) * TypeTable.start_price("MATERIAL")
	milli += int(b["component"]) * TypeTable.start_price("COMPONENT")
	return roundi(float(milli) / 1.0e6)


## The mean value (1000 = ordinary) of a place: its cells in a town, the tile's middle cell in the country.
static func value_pm(world: WorldState, site: Dictionary) -> int:
	var cells: Array = site.get("cells", [])
	if cells.is_empty():
		var tl := ColonyLayout.as_tile(String(site.get("tile", "")))
		if tl.x < 0:
			return 1000
		cells = [TownGrid.centre_cell(tl)]
	var s := 0
	for ck in cells:
		s += int(TownGrid.value(world, ck)["value_pm"])
	return roundi(float(s) / float(cells.size()))


## What a plan pays for its land (whole credits): 10% of its building bill × the value of its place / 1000.
static func land_price(world: WorldState, site: Dictionary, bill_credits: int) -> int:
	return roundi(float(bill_credits) * LAND_SHARE * float(value_pm(world, site)) / 1000.0)


## Land law's land_value_fn (milli-credits): a town cell "c:fx,fy" is the land of a house cell's homes; a country tile
## "x,y" (or a Vector2i) is the land of a full-size farm. Both × the value of the place / 1000.
static func land_value_milli(world: WorldState, key) -> int:
	var k := String(key) if not key is Vector2i else Terrain.key(key.x, key.y)
	if k.begins_with("c:"):
		var homes := int(TownGrid.FORMS["HOUSE"]["homes"])
		var bill := float(bill_credits("LANDLORD")) / float(HOME_BILL_DIV) * float(homes)
		return roundi(bill * LAND_SHARE * float(TownGrid.value(world, k.trim_prefix("c:"))["value_pm"]))
	return roundi(float(bill_credits("FARM")) * LAND_SHARE * float(value_pm(world, {"where": "COUNTRY", "tile": k})))


# ================================================================== farm yield (rebuild step 3; joins: PRODUCTION)

## Below this a farm's month is unusual (drought, harmed land) and gets its own log row; ordinary seasons are in the
## making row's why.
const YIELD_LOG_BELOW := 700


## How much of its type row's output a plant makes this month, ‰ (rebuild step-3 joins: Bob's making multiplies by
## it). A FARM: the season at its hex (PlanetSeasons.farm_pct: the growing year, averaging 100 over a year, less the
## drought) × the harm to its land (PlanetEcology.yield_pct) / 100. Food grows month by month with the season; there
## is no harvest lump. Anything else, a held plan's site or a plant with no place: 1000. Pure (any reader may ask; the
## low-yield row is written once a month by note_low_yields). Reads the weather of `month` (NATURE has made this
## month's before PRODUCTION).
static func yield_pm(world: WorldState, plant_id: String, month: int) -> int:
	var parts := _yield_parts(world, plant_id, month)
	return int(parts.get("pm", 1000))


static func _yield_parts(world: WorldState, plant_id: String, month: int) -> Dictionary:
	var wt := what(world, plant_id)
	if wt.is_empty() or bool(wt["plan"]) or String(wt["type"]) != "FARM":
		return {}
	var s := of(world, plant_id)
	if s.is_empty():
		return {}
	var cell := Planet.hex_of_tile(world, ColonyLayout.as_tile(String(s["tile"])))
	if cell < 0:
		return {}
	var season := PlanetSeasons.farm_pct(world, cell, month)
	var land := PlanetEcology.yield_pct(world, cell)
	return {"pm": season * land * 10 / 100, "season_pct": season, "land_pct": land,
		"drought_loss_pct": PlanetSeasons.drought_loss(world, cell, month), "hex": cell}


## NATURE, once a month (from step_month): one PLANET "low yield" row for each farm whose yield this month is below
## YIELD_LOG_BELOW (drought, harmed land), with what it read.
static func note_low_yields(world: WorldState) -> void:
	for id in ids(world):
		var y := _yield_parts(world, String(id), world.month)
		if not y.is_empty() and int(y["pm"]) < YIELD_LOG_BELOW:
			Logbook.note(world, "PLANET", String(id), "low yield", {"season_pct": y["season_pct"], "land_pct": y["land_pct"],
				"drought_loss_pct": y["drought_loss_pct"], "hex": y["hex"], "month": world.month}, {"yield_pm": [1000, int(y["pm"])]})


# ================================================================== the land under a plan (rebuild step 3; joins: COMPANY_AI)

const SIZE_OF_SIXTHS := {1: "FAMILY", 2: "SMALL", 4: "AVERAGE", 6: "LARGE"}


## Land law's keys for a place: ["x,y"] in the country, ["c:fx,fy", ...] for a town place's cells.
static func land_keys(site: Dictionary) -> Array:
	if String(site.get("where", "")) == "TOWN":
		return (site.get("cells", []) as Array).map(func(ck): return cell_key(ck))
	return [String(site.get("tile", ""))]


## What a plan's land costs and on what terms, before it signs (pure): land law's terms for its held site at the
## plan's own price (10% of its bill × the value of its place). {} if the plan holds no site.
static func land_terms(world: WorldState, plan_id: String) -> Dictionary:
	var h: Dictionary = _t(world).get("hold", {}).get(plan_id, {})
	var s := of(world, plan_id)
	if h.is_empty() or s.is_empty():
		return {}
	var price := _plan_land_milli(world, h, s)
	var t: Dictionary = LandLaw.terms(world, land_keys(s), plan_id, String(h["type"]), int(h["sixths"]), price)
	t["due"] = _due(t)
	return t


## What a plan pays for its land at signing (milli-credits): the price when the land is sold, the first month's rent
## under a lease (a government's LEASE or KEEP policy). The sum a plan checks against its account ("land + total").
static func _due(t: Dictionary) -> int:
	return int(t.get("lease_rent", 0)) if String(t.get("mode", "")) == "LEASE" else int(t.get("price", 0))


static func _plan_land_milli(world: WorldState, h: Dictionary, s: Dictionary) -> int:
	var bill := bill_credits(String(h["type"]), String(SIZE_OF_SIXTHS.get(int(h["sixths"]), "LARGE")))
	return land_price(world, s, bill) * CoreUtil.S


## A plan buys the land it builds on, when it signs its contract (12.1 point 3). This takes no money itself: land
## law's sell is the one deed (it takes the price from `payer_acct` into the treasury, memo LAND_SALE, and writes the
## title, or nothing at all). → {ok, mode, price (the land's price, milli-credits), due (what was paid at signing: the
## price, or the first month's rent under a lease), why}.
static func buy_land(world: WorldState, plan_id: String, payer_acct: String) -> Dictionary:
	var h: Dictionary = _t(world).get("hold", {}).get(plan_id, {})
	var s := of(world, plan_id)
	if h.is_empty() or s.is_empty():
		Logbook.note(world, "SITE", plan_id, "land not bought", {"why": "no site held"}, {})
		return {"ok": false, "mode": "", "price": 0, "due": 0, "why": "no site held"}
	var price := _plan_land_milli(world, h, s)
	var keys := land_keys(s)
	var r: Dictionary = LandLaw.sell(world, keys, plan_id, payer_acct, String(h["type"]), int(h["sixths"]), price)
	var ok := bool(r.get("ok", false))
	Logbook.note(world, "SITE", plan_id, "land bought" if ok else "land not bought", {"type": h["type"], "sixths": h["sixths"],
		"where": s["where"], "keys": keys.size(), "value_pm": value_pm(world, s), "price": price, "mode": r.get("mode", ""),
		"why": String(r.get("reason", ""))}, {}, String(payer_acct))
	return {"ok": ok, "mode": String(r.get("mode", "")), "price": int(r.get("price", price)), "due": _due(r) if ok else 0,
		"why": String(r.get("reason", ""))}
