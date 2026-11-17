class_name Siting
extends RefCounted
## Terra (Wilma's queued job 2026-11-15; planning/plan-settlement-later.md, "Who picks where a building goes"), flag
## SITING: the groundwork for choosing a site. Opt-in; nothing changes without the flag.
## - Land reserved by use: the government marks tiles FARMLAND / HOUSING / INDUSTRY / NATURE / OPEN. The layout does
##   not place a building on land reserved for another use (place_at refuses it too). Buildings already standing there
##   keep their tile (they are pinned when the land is marked).
## - Site options: candidate tiles for a building in a district, each with what stands near it, so a chooser can weigh
##   them (pure).
## - A chosen site: place_at(fid or project id, tile) is used instead of the nearest free tile.
## Nothing chooses yet: without a choice the old placement stands (the government side is Wilma's and Maja's).
## Table "siting" (only with the flag): {"use": {"x,y": USE}, "placed": {fid | project id: {"tile": "x,y", "month": m}},
## "rev": int}. "rev" is part of ColonyLayout.key, so the layout memo stays pure in its key.

const FLAG := "SITING"
const USES := ["FARMLAND", "HOUSING", "INDUSTRY", "NATURE", "OPEN"]
## What a building is, for the reservation rules. Anything not listed is TOWN: shops and services, which may stand on
## HOUSING or INDUSTRY land.
const FARM_TYPES := ["FARM", "FAMFARM"]
const HOME_TYPES := ["HOUSING"]
const INDUSTRY_TYPES := ["MINE", "PROCESSING", "POWER", "WATERWORKS", "DEPOT", "WAREHOUSE", "SANITATION", "COMPONENTS",
	"CONSUMERF", "MEDWORKS", "TEXTILE", "FURNITURE", "MATERIAL", "COMPONENT", "TRANSIT", "BAKERY"]
## Project types that are not a new building (they act on a facility or a road that already has its place).
const NOT_A_BUILDING := ["ROAD", "EXPAND", "RENOVATE", "UPGRADE"]
const REACH := 6        # site options: tiles this far from one of the district's settlements
const NEAR_R := 3       # site options: what stands within this many tiles is listed
const HOME_R := 2       # site options: homes within this many tiles are counted
const KM := 3           # km per tile (Terrain.KM_PER_TILE)


static func on(world: WorldState) -> bool:
	return (world.meta.get("on", []) as Array).has(FLAG) and not (world.meta.get("off", []) as Array).has(FLAG)


## Part of ColonyLayout.key: changes whenever a reservation or a chosen site changes. "" without the table.
static func sig(world: WorldState) -> String:
	var t: Dictionary = world.peek("siting")
	return "" if t.is_empty() else "|s%d" % int(t.get("rev", 0))


static func _tkey(t: Vector2i) -> String:
	return Terrain.key(t.x, t.y)


static func _bump(t: Dictionary) -> void:
	t["rev"] = int(t.get("rev", 0)) + 1


# ================================================================== land reserved by use

## FARMLAND, HOUSING, INDUSTRY or TOWN (shops and services).
static func kind_of(ftype: String) -> String:
	if ftype in FARM_TYPES:
		return "FARMLAND"
	if ftype in HOME_TYPES:
		return "HOUSING"
	if ftype in INDUSTRY_TYPES:
		return "INDUSTRY"
	return "TOWN"


## May a building of this type stand on land reserved for `use` ("" = not reserved)?
static func fits(use: String, ftype: String) -> bool:
	match use:
		"", "OPEN":
			return true
		"NATURE":
			return false
		"FARMLAND":
			return kind_of(ftype) == "FARMLAND"
		"HOUSING":
			return kind_of(ftype) in ["HOUSING", "TOWN"]
		"INDUSTRY":
			return kind_of(ftype) in ["INDUSTRY", "TOWN"]
	return true


## The use a tile is reserved for ("" = none). Any tile form ColonyLayout.as_tile reads.
static func use_at(world: WorldState, tile) -> String:
	var t := ColonyLayout.as_tile(tile)
	return String(world.peek("siting").get("use", {}).get(_tkey(t), ""))


## Reserve tiles for a use (one of USES), or lift the reservation (""). Buildings already standing there keep their
## tile. A public fact LAND_USE_SET. → "" or why not.
static func set_use(world: WorldState, tiles: Array, use: String, by: String = "gov") -> String:
	if not on(world):
		return "Land use is not in this game"
	if use != "" and not use in USES:
		return "A use is one of %s (\"\" lifts it)" % str(USES)
	var ts: Array = []
	for tv in tiles:
		var t := ColonyLayout.as_tile(tv)
		if t.x < 0 or t.y < 0 or t.x >= Terrain.W or t.y >= Terrain.H or Terrain.at(world, t.x, t.y) in ["", Terrain.SEA]:
			return "Tile %s is not land on the map" % str(tv)
		if not t in ts:
			ts.append(t)
	if ts.is_empty():
		return "No tiles"
	var ft := ColonyLayout.facility_tiles(world)   # before the change: what stands there now
	var at_tile := {}
	for fid in CoreUtil.sorted_keys(ft):
		at_tile[_tkey(ColonyLayout.as_tile(ft[fid]))] = String(fid)
	var tb := world.table("siting")
	if not tb.has("use"):
		tb["use"] = {}
		tb["placed"] = {}
	var u: Dictionary = tb["use"]
	var pl: Dictionary = tb["placed"]
	var was := {}
	var kept: Array = []
	var fac: Dictionary = world.peek("facility")
	for t in ts:
		var k := _tkey(t)
		var w0 := String(u.get(k, ""))
		was[w0] = int(was.get(w0, 0)) + 1
		if use == "":
			u.erase(k)
		else:
			u[k] = use
		if at_tile.has(k):   # what stands there stays there
			var fid := String(at_tile[k])
			if not pl.has(fid):
				pl[fid] = {"tile": k, "month": world.month}
			if not fits(use, String(fac.get(fid, {}).get("type", ""))):
				kept.append(fid)
	_bump(tb)
	var t0: Vector2i = ts[0]
	world.add_fact({"type": "LAND_USE_SET", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": mini(40, 5 + ts.size()), "visibility": "PUBLIC",
		"data": {"district": Transport._district_near(ColonyLayout.settlements(world), t0), "use": use, "tiles": ts.size(),
			"tile": _tkey(t0), "was": was, "kept": kept, "by": by}})
	return ""


## The land tiles (not the sea) within r of a centre, for set_use.
static func tiles_around(world: WorldState, center, r: int) -> Array:
	var c := ColonyLayout.as_tile(center)
	var out: Array = []
	for yy in range(c.y - r, c.y + r + 1):
		for xx in range(c.x - r, c.x + r + 1):
			if xx >= 0 and yy >= 0 and xx < Terrain.W and yy < Terrain.H and Vector2(xx - c.x, yy - c.y).length() <= float(r) + 0.01 					and not Terrain.at(world, xx, yy) in ["", Terrain.SEA]:
				out.append(Vector2i(xx, yy))
	return out


## Tiles a building of this type may not take: {"x,y": true} (reserved for another use). {} without the flag.
static func blocked(world: WorldState, ftype: String) -> Dictionary:
	var out := {}
	if not on(world):
		return out
	var u: Dictionary = world.peek("siting").get("use", {})
	for k in u:
		if not fits(String(u[k]), ftype):
			out[k] = true
	return out


# ================================================================== chosen sites

## Chosen and kept sites the layout uses: {"fac": {fid: Vector2i}, "pending": {"x,y": key}} (a project's site is
## pending until it is built). A built project's site goes to its facility (its ECON_PROJECT_COMPLETED fact), so the
## new building stands there from the month it opens. Pure.
static func pins(world: WorldState) -> Dictionary:
	var out := {"fac": {}, "pending": {}}
	if not on(world):
		return out
	var pl: Dictionary = world.peek("siting").get("placed", {})
	if pl.is_empty():
		return out
	var fac: Dictionary = world.peek("facility")
	var proj: Dictionary = world.peek("project")
	for key in CoreUtil.sorted_keys(pl):
		var t := ColonyLayout.as_tile(pl[key]["tile"])
		if fac.has(key):
			out["fac"][String(key)] = t
		elif proj.has(key):
			var p: Dictionary = proj[key]
			if String(p.get("status", "")) == "DONE":
				var fid := _built_fid(world, p)
				if fid != "" and fac.has(fid) and not out["fac"].has(fid):
					out["fac"][fid] = t
			elif String(p.get("status", "")) != "CANCELLED":
				out["pending"][_tkey(t)] = String(key)
	return out


static func _built_fid(world: WorldState, p: Dictionary) -> String:
	var dm := int(p.get("done_month", -1))
	for f in world.facts.query("ECON_PROJECT_COMPLETED", dm, dm):
		if String(f["data"].get("project", "")) == String(p["id"]):
			return String(f["data"].get("facility", ""))
	return ""


## Use this tile for a building: a facility opened this month (a founder's), or a building project not yet built
## (its facility will stand there). The tile must suit the building's terrain, be free, not be reserved for another
## use, and lie in the building's district. → "" or why not.
static func place_at(world: WorldState, key: String, tile) -> String:
	if not on(world):
		return "Site choice is not in this game"
	var ftype := ""
	var district := ""
	var fac: Dictionary = world.peek("facility")
	var proj: Dictionary = world.peek("project")
	if fac.has(key):
		var f: Dictionary = fac[key]
		if int(f.get("opened", -1)) != world.month or f.has("tile"):
			return "%s already stands; a site is chosen when it is built" % key
		ftype = String(f["type"])
		district = String(f.get("district", ""))
	elif proj.has(key):
		var p: Dictionary = proj[key]
		if String(p.get("type", "")) in NOT_A_BUILDING or String(p.get("status", "")) in ["DONE", "CANCELLED"]:
			return "Project %s is not a building still to be built" % key
		ftype = String(p["type"])
		district = String(p.get("district", ""))
	else:
		return "Unknown facility or project '%s'" % key
	var t := ColonyLayout.as_tile(tile)
	if t.x < 0 or t.y < 0 or t.x >= Terrain.W or t.y >= Terrain.H:
		return "Tile %s is off the map" % str(tile)
	var code := Terrain.at(world, t.x, t.y)
	var codes: Array = ColonyLayout.FAC_TERRAIN.get(ftype, ColonyLayout.BUILD_TERRAIN)
	if not code in codes:
		return "A %s cannot stand on %s" % [ftype.to_lower(), String(Terrain.NAMES.get(code, code))]
	var use := use_at(world, t)
	if not fits(use, ftype):
		return "The land is reserved for %s" % use.to_lower()
	var k := _tkey(t)
	var taken := _taken(world, key)
	if taken.has(k):
		return "Tile %s is taken (%s)" % [k, String(taken[k])]
	var setl := ColonyLayout.settlements(world)
	if district != "" and not setl.is_empty() and Transport._district_near(setl, t) != district:
		return "Tile %s is not in %s" % [k, district]
	var tb := world.table("siting")
	if not tb.has("use"):
		tb["use"] = {}
		tb["placed"] = {}
	tb["placed"][key] = {"tile": k, "month": world.month}
	_bump(tb)
	return ""


## Where a building may not go: {"x,y": what is there}: facilities (but `except`), area tiles, the settlements'
## anchors, and sites chosen for projects still to be built.
static func _taken(world: WorldState, except: String = "") -> Dictionary:
	var out := {}
	for k in world.peek("map").get("uses", {}):
		out[k] = "a settlement"
	var anchors := ColonyLayout.econ_anchors(world)
	for d in anchors:
		out[_tkey(anchors[d])] = "the centre of %s" % d
	var ft := ColonyLayout.facility_tiles(world)
	for fid in ft:
		if String(fid) != except:
			out[_tkey(ColonyLayout.as_tile(ft[fid]))] = String(fid)
	var pend: Dictionary = pins(world)["pending"]
	for k in pend:
		if String(pend[k]) != except:
			out[k] = String(pend[k])
	return out


## Monthly tidy (NATURE tick): a built project's site moves to its facility; sites of cancelled projects and of
## facilities that are gone are dropped.
static func step_month(world: WorldState) -> void:
	if not on(world):
		return
	var tb: Dictionary = world.peek("siting")
	var pl: Dictionary = tb.get("placed", {})
	if pl.is_empty():
		return
	var fac: Dictionary = world.peek("facility")
	var proj: Dictionary = world.peek("project")
	var changed := false
	for key in CoreUtil.sorted_keys(pl):
		if fac.has(key):
			continue
		if proj.has(key):
			var p: Dictionary = proj[key]
			var st := String(p.get("status", ""))
			if st == "DONE":
				var fid := _built_fid(world, p)
				if fid != "" and fac.has(fid) and not pl.has(fid):
					pl[fid] = pl[key]
				pl.erase(key)
				changed = true
			elif st == "CANCELLED":
				pl.erase(key)
				changed = true
		else:
			pl.erase(key)
			changed = true
	if changed:
		_bump(tb)


# ================================================================== site options

## Up to n candidate tiles for a building of this type in a district, for a chooser to weigh. The first is where the
## layout would put it today ("default": true); the others are spread over the free suitable land around the
## district's settlements. Each: {tile "x,y", default, terrain, use (its reservation, ""), town_km, road_km (-1 = no
## road), homes (people weight within HOME_R: town tiles 2, housing 3), near [{fid, type, km}] (within NEAR_R,
## nearest first), mine_km, depot_km (-1 = none within NEAR_R), farmland_lost (1 if a building other than a farm takes
## fertile or native-crop land or land reserved for farms), road {link, kmh, risk_pm, added_pm} (the fastest colony road within one tile; its
## expected accidents a year × 1000, and how many more this building's people would add, ROAD_SAFETY only; {} if
## none)}. Pure. [] without the flag.
static func site_options(world: WorldState, ftype: String, district: String, n: int = 5) -> Array:
	var out: Array = []
	if not on(world) or n <= 0:
		return out
	var setl := ColonyLayout.settlements(world)
	var mine: Array = setl.filter(func(s): return String(s["district"]) == district)
	var anchors := ColonyLayout.econ_anchors(world)
	if mine.is_empty() and not anchors.has(district):
		return out
	var codes: Array = ColonyLayout.FAC_TERRAIN.get(ftype, ColonyLayout.BUILD_TERRAIN)
	var taken := _taken(world)
	var bl := blocked(world, ftype)
	var a: Vector2i = anchors.get(district, Terrain.landing(world))
	var picked: Array = []
	var dflt := ColonyLayout.nearest_untaken(world, a, codes, taken, 40, bl)
	if dflt.x >= 0:
		picked.append(dflt)
	# the free suitable land around the district's settlements
	var centres: Array = mine.map(func(s): return ColonyLayout.as_tile(s["tile"]))
	if centres.is_empty():
		centres = [a]
	var cand: Array = []
	var seen := {}
	for c in centres:
		for yy in range(c.y - REACH, c.y + REACH + 1):
			for xx in range(c.x - REACH, c.x + REACH + 1):
				var t := Vector2i(xx, yy)
				var k := _tkey(t)
				if seen.has(k) or xx < 0 or yy < 0 or xx >= Terrain.W or yy >= Terrain.H:
					continue
				seen[k] = true
				if taken.has(k) or bl.has(k) or not Terrain.at(world, xx, yy) in codes:
					continue
				if not setl.is_empty() and Transport._district_near(setl, t) != district:
					continue
				cand.append(t)
	cand.sort_custom(func(p, q): return p.y < q.y or (p.y == q.y and p.x < q.x))
	while picked.size() < n and not cand.is_empty():   # spread out: the candidate farthest from those picked
		var best := -1
		var bd := -1.0
		for i in cand.size():
			var md := INF
			for pt in picked:
				md = minf(md, Vector2(cand[i] - pt).length())
			if picked.is_empty():
				md = -Vector2(cand[i] - a).length()   # none yet: the nearest to the centre first
			if md > bd + 1e-6:
				bd = md
				best = i
		if best < 0 or (not picked.is_empty() and bd <= 0.0):
			break
		picked.append(cand[best])
		cand.remove_at(best)
	var ctx := _context(world)
	for i in picked.size():
		var row := _describe(world, ftype, picked[i], centres, ctx)
		row["default"] = i == 0 and dflt.x >= 0
		out.append(row)
	return out


## What site_options needs once per call: facility tiles, road tiles.
static func _context(world: WorldState) -> Dictionary:
	var road := {}   # tile int -> [lid, ...]
	var links := Transport._links(world)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		for ti in l.get("path", []):
			if not road.has(int(ti)):
				road[int(ti)] = []
			road[int(ti)].append(String(lid))
	return {"ft": ColonyLayout.facility_tiles(world), "road": road, "links": links}


static func _describe(world: WorldState, ftype: String, t: Vector2i, centres: Array, ctx: Dictionary) -> Dictionary:
	var code := Terrain.at(world, t.x, t.y)
	var use := use_at(world, t)
	var town := INF
	for c in centres:
		town = minf(town, Vector2(t - c).length())
	# the nearest road tile
	var road_d := INF
	var road: Dictionary = ctx["road"]
	for ti in road:
		road_d = minf(road_d, Vector2(Transport.int_tile(int(ti)) - t).length())
	# homes and buildings nearby
	var homes := 0
	for s in ColonyLayout.settlements(world):
		for st in s.get("tiles", []):
			var tt := ColonyLayout.as_tile(st)
			if absi(tt.x - t.x) <= HOME_R and absi(tt.y - t.y) <= HOME_R:
				homes += RoadSafety.TOWN_W
	var near: Array = []
	var mine_d := INF
	var depot_d := INF
	var fac: Dictionary = world.peek("facility")
	var ft: Dictionary = ctx["ft"]
	for fid in CoreUtil.sorted_keys(ft):
		var ftile := ColonyLayout.as_tile(ft[fid])
		var d := Vector2(ftile - t).length()
		var ty := String(fac.get(fid, {}).get("type", ""))
		if ty == "HOUSING" and absi(ftile.x - t.x) <= HOME_R and absi(ftile.y - t.y) <= HOME_R:
			homes += int(RoadSafety.WALK["HOUSING"])
		if d <= float(NEAR_R) + 0.01:
			near.append({"fid": String(fid), "type": ty, "km": roundi(d * KM)})
			if ty == "MINE":
				mine_d = minf(mine_d, d)
			elif ty in ["DEPOT", "WAREHOUSE"]:
				depot_d = minf(depot_d, d)
	near.sort_custom(func(p, q): return int(p["km"]) < int(q["km"]) or (int(p["km"]) == int(q["km"]) and String(p["fid"]) < String(q["fid"])))
	return {"tile": _tkey(t), "terrain": code, "use": use, "town_km": roundi(town * KM),
		"road_km": roundi(road_d * KM) if road_d < INF else -1, "homes": homes, "near": near.slice(0, 6),
		"mine_km": roundi(mine_d * KM) if mine_d < INF else -1, "depot_km": roundi(depot_d * KM) if depot_d < INF else -1,
		"farmland_lost": 1 if kind_of(ftype) != "FARMLAND" and (code in ["f", "n"] or use == "FARMLAND") else 0, "road": _road_near(world, ftype, t, ctx)}


## The fastest colony road within RoadSafety.NEAR of a tile: {link, kmh, risk_pm, added_pm}; {} if none.
## risk_pm: its expected accidents a year now (× 1000); added_pm: how many more a building of this type would add
## there (its people on foot near the road). Both 0 without ROAD_SAFETY.
static func _road_near(world: WorldState, ftype: String, t: Vector2i, ctx: Dictionary) -> Dictionary:
	var road: Dictionary = ctx["road"]
	var links: Dictionary = ctx["links"]
	var hits := {}   # lid -> path tiles within reach
	for dy in range(-RoadSafety.NEAR, RoadSafety.NEAR + 1):
		for dx in range(-RoadSafety.NEAR, RoadSafety.NEAR + 1):
			var ti := Transport.tile_int(t + Vector2i(dx, dy))
			for lid in road.get(ti, []):
				if not hits.has(lid):
					hits[lid] = []
				hits[lid].append(ti)
	var best := {}
	for lid in CoreUtil.sorted_keys(hits):
		var l: Dictionary = links[lid]
		var v := RoadSafety.kmh(world, l)
		if not best.is_empty() and v <= int(best["kmh"]):
			continue
		var risk_pm := 0
		var added_pm := 0
		if RoadSafety.on(world):
			risk_pm = roundi(RoadSafety.risk(world, String(lid)) * 12000.0)
			var w := float(RoadSafety.WALK.get(ftype, RoadSafety.WORK_W))
			var tf := clampf(float(int(l.get("traffic_last", 0))) / 1000.0, 0.2, 3.0)
			var add := 0.0
			for ti in hits[lid]:
				add += RoadSafety.BASE * w * RoadSafety._pass_left(l, int(ti)) * RoadSafety._speed_risk(float(v)) * tf
			added_pm = roundi(add * 12000.0)
		best = {"link": String(lid), "kmh": v, "risk_pm": risk_pm, "added_pm": added_pm}
	return best
