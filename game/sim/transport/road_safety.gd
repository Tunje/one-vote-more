class_name RoadSafety
extends RefCounted
## Terra (the user's design, planning/plan-settlement-later.md "Road speed, accidents near people, over- and
## underpasses", approved 2026-11-15 via Wilma). Flag ROAD_SAFETY (opt-in; base unchanged without it).
## User: "accidents should [be in the game]. Any high speed road near utility people walk to, and near districts, have
## chances for accidents; over and under passes reduce the chance. Also road types should not be speed." / "a motorway
## around a village instead of through can be a thing."
##
## - No pedestrians as travellers. A link has its own speed: the surface's design speed (DESIGN_KMH) unless a limit is
##   set (Transport.set_limit); the surface keeps capacity and wear. A limit slows every trip on the link.
## - People near a road: each link tile within NEAR tiles of housing (a town's tiles, HOUSING) or what people walk to
##   (clinics, schools, shops, care, workplaces) is a spot, weighted by WALK. Pure in the layout and the network.
## - Accidents (monthly, stream transport.safety): per link, expected accidents a month = BASE × Σ spots (weight ×
##   what a pass there leaves) × speed factor ((kmh − 30) / 40)² × traffic factor (last month's trips / 1000, 0.2..3).
##   Each has a chance to kill that rises with speed. Deaths go through EconPop.casualties (the district's people, the
##   nearby workplace's staff first). Fact TRANSPORT_ROAD_ACCIDENT (PUBLIC, no one responsible: politics decides).
## - Choices (safety_needs, road_needs-style options): a speed limit (no cost, at once: Transport.set_limit), an
##   overpass or underpass at the worst spot (a ROAD project {pass: lid, tile, type}), a bypass (the capacity option,
##   now with a safety case), and at junctions of fast roads a flyover (a junction type, ROAD project {junction, type
##   FLYOVER}).
## State, only with the flag: link "limit" (km/h), "passes" [[tile, OVERPASS|UNDERPASS]]; transport "safety_offered"
## {lid: month a pass was first on offer}, "safety_acc" [month of each accident in the last 12 months].

const FLAG := "ROAD_SAFETY"
const DESIGN_KMH := {"TRACK": 40, "ROAD": 80, "PAVED": 110}
const LIMITS := [30, 50, 70, 90]
const SAFE_KMH := 30.0            # at or under this a road near people is (almost) safe
const NEAR := 1                   # tiles (3 km): a link tile this close to people is a spot
const TOWN_W := 2                 # a town tile (its houses and streets)
const WALK := {"HOUSING": 3, "CLINIC": 2, "SCHOOL": 2, "RETAIL": 2, "SERVICEHUB": 2, "CHILDCARE": 2, "ELDERCARE": 2,
	"COMFORT": 1, "ADMIN": 1, "POLICE_STATION": 1}
const WORK_W := 1                 # any other facility with people at work
const BASE := 0.002               # a busy fast road through a village: about an accident a year
const PASS_CUT := {"OVERPASS": 700, "UNDERPASS": 850}   # ‰ of the danger a pass takes away at spots within its reach
const PASS_REACH := 1
const BILL_PASS := {"OVERPASS": [40, 30, 1], "UNDERPASS": [90, 80, 2]}   # [wu, mat, comp] per lane
const NEED_PM := 100              # listed from one expected accident in ten years (milli-accidents a year)
const OFFER_MONTHS := 3           # a pass on offer this long and not built counts as refused in the news
const BYPASS_KEEPS_PM := 300      # a bypass leaves this ‰ of the danger (local traffic stays on the old road)

static var _cache := {}


## Always on: part of the rebuild ("nothing behind an off switch", rebuild-company.md 12.4, 33).
static func on(_world: WorldState = null) -> bool:
	return true


# ================================================================== speed

## The speed a link is driven at, km/h: its limit (or the surface's design speed), less for wear.
static func kmh(world: WorldState, l: Dictionary) -> int:
	var k := Transport.effective_kind(l, world)
	var v := float(DESIGN_KMH.get(k, 40))
	if on(world) and int(l.get("limit", 0)) > 0:
		v = minf(v, float(l["limit"]))
	return roundi(v * (0.5 + 0.5 * clampf(float(l["cond"]) / 1000.0, 0.0, 1.0)))


## Factor on the route graph's speed for a link's limit (1.0 without a limit or the flag).
static func speed_factor(world: WorldState, l: Dictionary) -> float:
	if not on(world) or int(l.get("limit", 0)) <= 0:
		return 1.0
	var design := float(DESIGN_KMH.get(Transport.effective_kind(l, world), 40))
	return minf(1.0, float(l["limit"]) / design)


static func _speed_risk(v: float) -> float:
	var x := maxf(0.0, (v - SAFE_KMH) / 40.0)
	return x * x


static func _kill_chance(v: float) -> float:
	return clampf((v - SAFE_KMH) / 120.0, 0.05, 0.6)


## Set or lift (kmh 0) a link's speed limit: a decision with no cost, felt at once. → "" or why not.
static func set_limit(world: WorldState, lid: String, kmh_v: int) -> String:
	if not on(world):
		return "Road safety is not in this game"
	var links: Dictionary = world.table("transport").get("links", {})
	if not links.has(lid) or int(links[lid].get("globe", 0)) == 1:
		return "Unknown colony link '%s'" % lid
	if kmh_v != 0 and not kmh_v in LIMITS:
		return "A limit is one of %s km/h (0 lifts it)" % str(LIMITS)
	var l: Dictionary = links[lid]
	var was := int(l.get("limit", 0))
	if kmh_v == 0:
		l.erase("limit")
	else:
		l["limit"] = kmh_v
	Transport._bump(world)
	world.add_fact({"type": "TRANSPORT_SPEED_LIMIT_SET", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
		"magnitude": 10, "visibility": "PUBLIC", "data": {"link": lid, "kmh": kmh_v, "was": was,
			"district": Transport._district_near(ColonyLayout.settlements(world), Transport.int_tile(int(l["path"][(l["path"] as Array).size() / 2])))}})
	return ""


## Struct-signature part (route memos): a limit changes route times.
static func sig(l: Dictionary) -> String:
	return "|L%d" % int(l["limit"]) if l.has("limit") else ""


# ================================================================== people near roads

## {tile int: [weight, fid of the nearest walk place ("" for houses), what]} for every tile with people on foot near
## it. Pure in the layout; cached on its key.
static func people(world: WorldState) -> Dictionary:
	var key := "p|%s" % ColonyLayout.key(world)
	if _cache.has(key):
		return _cache[key]
	if _cache.size() >= 32:
		_cache.clear()
	var src := {}   # tile int -> [weight, fid, what]
	var fac: Dictionary = world.peek("facility")
	var ft: Dictionary = ColonyLayout.facility_tiles(world)
	for fid in CoreUtil.sorted_keys(ft):
		var f: Dictionary = fac.get(fid, {})
		if f.is_empty() or bool(f.get("mothball", false)):
			continue
		var ty := String(f.get("type", ""))
		var w := int(WALK.get(ty, WORK_W))
		var ti := Transport.tile_int(ColonyLayout.as_tile(ft[fid]))
		var cur: Array = src.get(ti, [0, "", ""])
		src[ti] = [int(cur[0]) + w, String(fid) if w >= int(cur[0]) else String(cur[1]), ty if w >= int(cur[0]) else String(cur[2])]
	for s in ColonyLayout.settlements(world):
		for t in s.get("tiles", []):
			var ti2 := Transport.tile_int(ColonyLayout.as_tile(t))
			var cur2: Array = src.get(ti2, [0, "", ""])
			src[ti2] = [int(cur2[0]) + TOWN_W, String(cur2[1]), String(cur2[2]) if String(cur2[2]) != "" else "HOMES"]
	var out := {}   # spread to tiles within NEAR
	for ti in CoreUtil.sorted_keys(src):
		var t0 := Transport.int_tile(int(ti))
		for dy in range(-NEAR, NEAR + 1):
			for dx in range(-NEAR, NEAR + 1):
				var tt := t0 + Vector2i(dx, dy)
				if tt.x < 0 or tt.y < 0:
					continue
				var k := Transport.tile_int(tt)
				var cur3: Array = out.get(k, [0, "", ""])
				var row: Array = src[ti]
				var better := int(row[0]) > 0 and (String(cur3[2]) == "" or (dx == 0 and dy == 0))
				out[k] = [int(cur3[0]) + int(row[0]), String(row[1]) if better else String(cur3[1]), String(row[2]) if better else String(cur3[2])]
	_cache[key] = out
	return out


## A link's spots: [[tile int, weight, fid, what], ...] in path order. Pure (network shape and layout).
static func spots(world: WorldState, lid: String) -> Array:
	var l: Dictionary = Transport._links(world).get(lid, {})
	if l.is_empty() or int(l.get("globe", 0)) == 1:
		return []
	var pp := people(world)
	var out: Array = []
	for ti in l["path"]:
		if pp.has(int(ti)):
			var r: Array = pp[int(ti)]
			out.append([int(ti), int(r[0]), String(r[1]), String(r[2])])
	return out


## What a pass leaves of a spot's danger (1.0 = no pass in reach).
static func _pass_left(l: Dictionary, ti: int) -> float:
	var left := 1.0
	var t := Transport.int_tile(ti)
	for p in l.get("passes", []):
		var pt := Transport.int_tile(int(p[0]))
		if absi(pt.x - t.x) <= PASS_REACH and absi(pt.y - t.y) <= PASS_REACH:
			left = minf(left, 1.0 - float(PASS_CUT.get(String(p[1]), 0)) / 1000.0)
	return left


## Expected accidents a month on a link now (its speed, traffic, passes); kmh_v, passes override for "what if".
static func risk(world: WorldState, lid: String, kmh_v: int = -1, l_override: Dictionary = {}) -> float:
	var l: Dictionary = l_override if not l_override.is_empty() else Transport._links(world).get(lid, {})
	if l.is_empty():
		return 0.0
	var v := float(kmh(world, l) if kmh_v < 0 else kmh_v)
	var sf := _speed_risk(v)
	if sf <= 0.0:
		return 0.0
	var tf := clampf(float(int(l.get("traffic_last", 0))) / 1000.0, 0.2, 3.0)
	var s := 0.0
	for sp in spots(world, lid):
		s += float(sp[1]) * _pass_left(l, int(sp[0]))
	return BASE * s * sf * tf


# ================================================================== choices

## Links whose people-near danger is worth a decision, worst first: [{key "SAFE:<lid>", link, district, kmh, limit,
## people (Σ spot weights), risk_pm (expected accidents a year × 1000), deaths_pm, spot (the worst spot without a
## pass, "x,y"), offered_since (month a pass was first on offer, -1), options [{fix LIMIT_<kmh> | LIMIT_NONE |
## OVERPASS | UNDERPASS | BYPASS, type LIMIT | PASS | NEW, spec, cost, months, risk_after_pm, hours_lost (trip-hours a
## month the limit costs; negative = saved)}]}]. A LIMIT is applied with Transport.set_limit(lid, kmh); the others are
## ROAD projects with the spec. Pure.
static func safety_needs(world: WorldState) -> Array:
	var out: Array = []
	if not on(world):
		return out
	var links := Transport._links(world)
	var setl := ColonyLayout.settlements(world)
	var offered: Dictionary = world.peek("transport").get("safety_offered", {})
	var fixes := Transport.traffic_fixes(world)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var r := risk(world, lid)
		var rpm := roundi(r * 12000.0)
		if rpm < NEED_PM:
			continue
		var v := kmh(world, l)
		var opts: Array = []
		var trips := int(l.get("traffic_last", 0))
		var km := float(Transport.link_km(l))
		for k in LIMITS:
			if k >= v:
				continue
			var lost := roundi(float(trips) * (km / float(k) - km / float(maxi(1, v))))
			opts.append({"fix": "LIMIT_%d" % k, "type": "LIMIT", "spec": {"limit": lid, "kmh": k}, "cost": 0, "months": 0,
				"risk_after_pm": roundi(risk(world, lid, roundi(float(k) * (0.5 + 0.5 * clampf(float(l["cond"]) / 1000.0, 0.0, 1.0)))) * 12000.0),
				"hours_lost": lost})
		if l.has("limit"):
			var free := l.duplicate()
			free.erase("limit")
			var v2 := kmh(world, free)
			opts.append({"fix": "LIMIT_NONE", "type": "LIMIT", "spec": {"limit": lid, "kmh": 0}, "cost": 0, "months": 0,
				"risk_after_pm": roundi(risk(world, lid, v2) * 12000.0), "hours_lost": roundi(float(trips) * (km / float(maxi(1, v2)) - km / float(maxi(1, v))))})
		var worst := _worst_open_spot(world, lid, l)
		if worst >= 0:
			for ty in ["OVERPASS", "UNDERPASS"]:
				var spec := {"pass": lid, "tile": worst, "type": ty}
				var plan := Transport.plan_link(world, spec)
				if bool(plan["ok"]):
					var after := l.duplicate(true)
					after["passes"] = (l.get("passes", []) as Array).duplicate(true) + [[worst, ty]]
					opts.append({"fix": ty, "type": "PASS", "spec": spec, "cost": int(plan["cost"]), "months": int(plan["months"]),
						"risk_after_pm": roundi(risk(world, lid, -1, after) * 12000.0), "hours_lost": 0})
		for o in fixes.get("LINK:" + lid, {}).get("options", []):
			if String(o["fix"]) == "BYPASS":
				opts.append({"fix": "BYPASS", "type": "NEW", "spec": o["spec"], "cost": int(o["cost"]), "months": int(o["months"]),
					"risk_after_pm": rpm * BYPASS_KEEPS_PM / 1000, "hours_lost": 0})
		var mid := Transport.int_tile(int(l["path"][(l["path"] as Array).size() / 2]))
		var ppl := 0
		for sp in spots(world, lid):
			ppl += int(sp[1])
		var wt := Transport.int_tile(worst) if worst >= 0 else Vector2i(-1, -1)
		out.append({"key": "SAFE:" + lid, "link": lid, "district": Transport._district_near(setl, mid), "kmh": v, "limit": int(l.get("limit", 0)),
			"people": ppl, "risk_pm": rpm, "deaths_pm": roundi(float(rpm) * _kill_chance(float(v))),
			"spot": "%d,%d" % [wt.x, wt.y] if worst >= 0 else "", "offered_since": int(offered.get(lid, -1)), "options": opts})
	out.sort_custom(func(a, b): return int(a["risk_pm"]) > int(b["risk_pm"]) or (a["risk_pm"] == b["risk_pm"] and String(a["key"]) < String(b["key"])))
	return out


## The heaviest spot on a link not yet covered by a pass (tile int, -1 if none).
static func _worst_open_spot(world: WorldState, lid: String, l: Dictionary) -> int:
	var best := -1
	var bw := 0
	for sp in spots(world, lid):
		if _pass_left(l, int(sp[0])) < 1.0:
			continue
		if int(sp[1]) > bw:
			bw = int(sp[1])
			best = int(sp[0])
	return best


## A pass's plan (Transport.plan_link, spec {pass: lid, tile, type}). → the plan dict fields, or an error.
static func plan_pass(world: WorldState, spec: Dictionary, out: Dictionary) -> Array:
	var links := Transport._links(world)
	var lid := String(spec.get("pass", ""))
	var ty := String(spec.get("type", ""))
	if not on(world):
		out["error"] = "Road safety is not in this game"
		return []
	if not links.has(lid) or int(links[lid].get("globe", 0)) == 1:
		out["error"] = "Unknown colony link '%s'" % lid
		return []
	if not BILL_PASS.has(ty):
		out["error"] = "A pass is an OVERPASS or an UNDERPASS"
		return []
	var l: Dictionary = links[lid]
	var ti := int(spec.get("tile", -1))
	if not ti in l["path"]:
		out["error"] = "The pass must stand on the road"
		return []
	for p in l.get("passes", []):
		if int(p[0]) == ti:
			out["error"] = "There is a pass here already"
			return []
	var lanes := int(l.get("lanes", 1))
	var b: Array = BILL_PASS[ty]
	out["job"] = "PASS"
	out["kind"] = ty
	out["path"] = [ti]
	out["km"] = 0
	return [int(b[0]) * lanes, int(b[1]) * lanes, int(b[2]) * lanes]


## A finished pass (Transport.complete_road).
static func build_pass(world: WorldState, spec: Dictionary) -> String:
	var links: Dictionary = world.table("transport")["links"]
	var lid := String(spec["pass"])
	var l: Dictionary = links[lid]
	if not l.has("passes"):
		l["passes"] = []
	l["passes"].append([int(spec["tile"]), String(spec["type"])])
	var so: Dictionary = world.table("transport").get("safety_offered", {})
	so.erase(lid)
	Transport._bump(world)
	return lid


# ================================================================== the month's accidents (NATURE tick, after wear)

static func step_month(world: WorldState) -> void:
	if not on(world):
		return
	var t := world.table("transport")
	var links: Dictionary = t["links"]
	var setl := ColonyLayout.settlements(world)
	var r := world.rng.stream("transport.safety")
	if not t.has("safety_offered"):
		t["safety_offered"] = {}
	var offered: Dictionary = t["safety_offered"]
	var acc: Array = t.get("safety_acc", []).filter(func(m): return int(m) > world.month - 12)
	for lid in CoreUtil.sorted_keys(links):
		var l: Dictionary = links[lid]
		if int(l.get("globe", 0)) == 1:
			continue
		var lam := risk(world, lid)
		# a pass on offer (danger worth a decision, an uncovered spot): remembered for the news
		if roundi(lam * 12000.0) >= NEED_PM and _worst_open_spot(world, lid, l) >= 0:
			if not offered.has(lid):
				offered[lid] = world.month
		elif offered.has(lid):
			offered.erase(lid)
		if lam <= 0.0:
			continue
		var n := mini(3, PlanetClimate._poisson(r, lam))
		if n <= 0:
			continue
		var sp := spots(world, lid)
		var v := float(kmh(world, l))
		for _k in n:
			var tot := 0.0
			for s in sp:
				tot += float(s[1]) * _pass_left(l, int(s[0]))
			var pick := r.randf() * tot
			var at: Array = sp[0]
			for s in sp:
				pick -= float(s[1]) * _pass_left(l, int(s[0]))
				if pick <= 0.0:
					at = s
					break
			var killed := 1 if r.randf() < _kill_chance(v) else 0
			var injured := 0 if killed > 0 and r.randf() < 0.5 else 1 + (1 if r.randf() < 0.3 else 0)
			var tl := Transport.int_tile(int(at[0]))
			var d := Transport._district_near(setl, tl)
			if killed > 0:
				killed = EconFace.pop_casualties(world, d, killed, "", String(at[2]))
			acc.append(world.month)
			var since := int(offered.get(lid, -1))
			world.add_fact({"type": "TRANSPORT_ROAD_ACCIDENT", "owner": "transport", "subjects": [], "responsible": [], "impact": {},
				"magnitude": clampi(25 + 30 * killed + 5 * injured, 0, 90), "visibility": "PUBLIC",
				"data": {"district": d, "link": lid, "tile": "%d,%d" % [tl.x, tl.y], "kmh": int(v), "limit": int(l.get("limit", 0)),
					"kind": String(l["kind"]), "owner": String(l.get("owner", "")), "people": int(at[1]), "near": String(at[3]),
					"facility": String(at[2]), "pass_here": _pass_left(l, int(at[0])) < 1.0,
					"pass_refused": since >= 0 and world.month - since >= OFFER_MONTHS, "offered_since": since,
					"killed": killed, "injured": injured}})
	t["safety_acc"] = acc


## Accidents near people in the last 12 months.
static func accidents_last_year(world: WorldState) -> int:
	return (world.peek("transport").get("safety_acc", []) as Array).filter(func(m): return int(m) > world.month - 12).size()
