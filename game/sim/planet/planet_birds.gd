class_name PlanetBirds
extends RefCounted
## Terra (ecology stage 3, under ECO): migrating birds. Each world has 2–3 flocks (pure in the seed): a name, a breeding
## range and a wintering range (a hex and its neighbours each), a route between them over the globe, and the months
## they travel. The colony always has birds of its own: the first flock breeds at the colony, the second passes over it,
## a third (if any) winters there.
##
## Where a flock is, it eats insects (mostly pests) and feeds the predators (PlanetWildlife reads `pressure`). Once a
## year, at the end of breeding, its size moves toward what its breeding grounds can feed and what its route and
## wintering grounds let survive: harm and cleared land anywhere along the way mean fewer birds come back.
##
## Saved: planet table "birds": {flock id: [size ‰ of natural, last year's size, gone 0|1]}.

const NAMES := ["ember swifts", "salt geese", "bell cranes", "dusk plovers", "glass terns", "reed larks", "storm petrels",
	"copper ibis", "moon swallows", "veil herons"]
const ROLES := ["BREEDS", "PASSES", "WINTERS"]
const INSECT_K := 1.0        # pest pressure per unit of yearly presence (x size)
const PREY_K := 0.2          # extra food for predators per unit of presence
const GREAT := 1300          # an arrival at least this big, or up 30%, is a great one
const FAILED := 400          # under this, or down 30%, the birds "didn't come"
const GONE := 100
const PULL_PM := 500         # share of the gap to the year's target closed at each breeding end (‰)

static var _cache := {}


static func on(world: WorldState) -> bool:
	return PlanetEcology.on(world)


# ================================================================== flocks (pure in the seed)

## [{id, name, role, breed: [cells], winter: [cells], route: [cells breed→winter], arrive (month 0..11 at the
## breeding grounds), leave (month they leave them), transit (months on the way)}].
static func flocks(world: WorldState) -> Array:
	var sd := world.rng.derive_seed("planet.eco.birds")
	var key := "fl|%d|%d|%d" % [sd, Planet.landing(world), Planet.freq(world)]
	if _cache.has(key):
		return _cache[key]
	var r := RandomNumberGenerator.new()
	r.seed = sd
	var geo := Planet.geometry(Planet.freq(world))
	var cs: PackedVector3Array = geo["centers"]
	var li := Planet.landing(world)
	var lat := Planet.lat_lon(li).x
	var hemi := 1.0 if lat >= 0.0 else -1.0
	var n := 2 + (1 if r.randf() < 0.6 else 0)
	var names: Array = NAMES.duplicate()
	var out: Array = []
	for k in n:
		var role: String = ROLES[k]
		var nm: String = names[r.randi_range(0, names.size() - 1)]
		names.erase(nm)
		var lon_off := r.randf_range(-25.0, 25.0)
		var span := r.randf_range(25.0, 45.0)
		var breed := li
		var winter := li
		var via := -1
		match role:
			"BREEDS":
				winter = _cell_at(world, lat - hemi * span, Planet.lat_lon(li).y + lon_off)
			"PASSES":
				breed = _cell_at(world, clampf(lat + hemi * r.randf_range(12.0, 22.0), -80.0, 80.0), Planet.lat_lon(li).y + r.randf_range(-10.0, 10.0))
				winter = _cell_at(world, lat - hemi * span, Planet.lat_lon(li).y + lon_off)
				via = li
			"WINTERS":
				breed = _cell_at(world, clampf(lat + hemi * span, -80.0, 80.0), Planet.lat_lon(li).y + lon_off)
		var route: Array = []
		if via >= 0:
			route = _path(cs, geo["nbrs"], breed, via, r)
			route.pop_back()
			route += _path(cs, geo["nbrs"], via, winter, r)
		else:
			route = _path(cs, geo["nbrs"], breed, winter, r)
		# breeding in the local spring and summer of the breeding range's hemisphere
		var south := Planet.lat_lon(breed).x < 0.0
		var arrive := posmod(r.randi_range(2, 4) + (6 if south else 0), 12)
		var leave := posmod(arrive + r.randi_range(4, 6), 12)
		out.append({"id": "flock:%d" % k, "name": nm, "role": role, "breed": _range(geo, breed), "winter": _range(geo, winter),
			"route": route, "arrive": arrive, "leave": leave, "transit": r.randi_range(1, 2)})
	_cache[key] = out
	return out


static func _cell_at(world: WorldState, lat: float, lon: float) -> int:
	var la := deg_to_rad(clampf(lat, -85.0, 85.0))
	var lo := deg_to_rad(lon)
	return Planet.cell_at(Vector3(cos(la) * sin(lo), sin(la), cos(la) * cos(lo)), Planet.freq(world))


static func _range(geo: Dictionary, c: int) -> Array:
	var out: Array = [c]
	for j in geo["nbrs"][c]:
		out.append(int(j))
	return out


## Hex path from a to b: greedy steps toward b with a little seeded wobble (pure: r is seeded from the world seed).
static func _path(cs: PackedVector3Array, nb: Array, a: int, b: int, r: RandomNumberGenerator) -> Array:
	var out: Array = [a]
	var cur := a
	for _k in 200:
		if cur == b:
			break
		var best := cur
		var bd := INF
		for j in nb[cur]:
			var d := cs[j].distance_to(cs[b]) * (1.0 + r.randf_range(0.0, 0.08))
			if d < bd and not int(j) in out:
				bd = d
				best = int(j)
		if best == cur:
			break
		cur = best
		out.append(cur)
	return out


## Where a flock is in a month: {phase BREEDING|SOUTH|NORTH|WINTER (SOUTH = towards winter), cells: [the cells it
## touches], centre: cell}. The arrival shifts by -1..+1 month in some years (pure in flock and year).
static func where(world: WorldState, f: Dictionary, month: int) -> Dictionary:
	var m := posmod(month, 12)
	var yr := month / 12
	var jit := (Planet._mix(yr * 7919 + 13, String(f["id"]).hash()) % 3) - 1
	var arrive := posmod(int(f["arrive"]) + jit, 12)
	var leave := int(f["leave"])
	var tr := int(f["transit"])
	var route: Array = f["route"]
	var since_leave := posmod(m - leave, 12)
	var to_arrive := posmod(arrive - m, 12)
	if posmod(m - arrive, 12) < posmod(leave - arrive, 12):
		return {"phase": "BREEDING", "cells": f["breed"], "centre": int(f["breed"][0])}
	if since_leave < tr:
		var a := route.size() * since_leave / tr
		var b := route.size() * (since_leave + 1) / tr
		var seg: Array = route.slice(a, maxi(b, a + 1))
		return {"phase": "SOUTH", "cells": seg, "centre": int(seg[seg.size() / 2])}
	if to_arrive >= 1 and to_arrive <= tr:
		var k := tr - to_arrive   # 0 = the first month of the way back
		var rev: Array = route.duplicate()
		rev.reverse()
		var a2 := rev.size() * k / tr
		var b2 := rev.size() * (k + 1) / tr
		var seg2: Array = rev.slice(a2, maxi(b2, a2 + 1))
		return {"phase": "NORTH", "cells": seg2, "centre": int(seg2[seg2.size() / 2])}
	return {"phase": "WINTER", "cells": f["winter"], "centre": int(f["winter"][0])}


## Share of the year each flock spends at a hex (pure; for the natural balance): {flock id: share}.
static func _yearly(world: WorldState, cell: int) -> Dictionary:
	var key := "yr|%d|%d|%d" % [world.rng.derive_seed("planet.eco.birds"), Planet.landing(world), cell]
	if not _cache.has(key):
		var out := {}
		for f in flocks(world):
			var n := 0
			for m in 12:
				if cell in where(world, f, m)["cells"]:
					n += 1
			if n > 0:
				out[String(f["id"])] = float(n) / 12.0
		_cache[key] = out
	return _cache[key]


# ================================================================== state

static func size(world: WorldState, fid: String) -> int:
	return int(world.peek("planet").get("birds", {}).get(fid, [1000, 1000, 0])[0])


static func last_year(world: WorldState, fid: String) -> int:
	return int(world.peek("planet").get("birds", {}).get(fid, [1000, 1000, 0])[1])


## Birds' pull on a hex's insects and predators over the year: [now, natural] in units of yearly presence (now x size).
static func pressure(world: WorldState, cell: int) -> Array:
	var yr := _yearly(world, cell)
	var now := 0.0
	var nat := 0.0
	for fid in yr:
		nat += float(yr[fid])
		now += float(yr[fid]) * float(size(world, String(fid))) / 1000.0
	return [now, nat]


## Flocks at a hex this month: [{id, name, phase, size}].
static func present(world: WorldState, cell: int, month: int) -> Array:
	var out: Array = []
	for f in flocks(world):
		var wh := where(world, f, month)
		if cell in wh["cells"]:
			out.append({"id": f["id"], "name": f["name"], "phase": wh["phase"], "size": size(world, String(f["id"]))})
	return out


## The colony's flocks' average size, ‰ (PLANET_BIRDS).
static func colony_index(world: WorldState) -> int:
	var fl := flocks(world)
	if fl.is_empty():
		return 1000
	var s := 0
	for f in fl:
		s += size(world, String(f["id"]))
	return s / fl.size()


## The most harmed hex a flock uses (route, breeding and wintering ranges): {cell, harm}.
static func worst_hex(world: WorldState, f: Dictionary) -> Dictionary:
	var best := -1
	var bh := -1
	for c in f["breed"] + f["route"] + f["winter"]:
		var h := PlanetEcology.harm(world, int(c))
		if h > bh:
			bh = h
			best = int(c)
	return {"cell": best, "harm": bh}


# ================================================================== the month (ECO, after the food web)

## Yearly size change at the end of breeding; arrival news at the colony. Returns [{kind ARRIVED|FAILED|GONE, ...}].
static func step_month(world: WorldState) -> Array:
	var t := world.table("planet")
	var st: Dictionary = t.get("birds", {})
	var r := world.rng.stream("planet.eco")
	var li := Planet.landing(world)
	var near: Array = [li] + Array(Planet.neighbors(world, li))
	var events: Array = []
	for f in flocks(world):
		var fid := String(f["id"])
		var row: Array = st.get(fid, [1000, 1000, 0]).duplicate()
		var now := where(world, f, world.month)
		var before := where(world, f, world.month - 1)
		# end of breeding: the year's size
		if before["phase"] == "BREEDING" and now["phase"] != "BREEDING":
			var food := 0.0
			for c in f["breed"]:
				var lv := PlanetWildlife.levels(world, int(c))
				food += float(int(lv["pol"]) + int(lv["pest"])) / 2000.0
			food /= float((f["breed"] as Array).size())
			var loss := 0.0
			var worst := 0.0
			var used: Array = f["route"] + f["winter"]
			var lu := PlanetWildlife.land_use(world)
			for c in used:
				var use: Array = lu.get(int(c), [0, 0])
				var bad := float(PlanetEcology.harm(world, int(c))) / 1000.0 * 0.8 + float(int(use[0])) / 1000.0 * 0.5
				loss += bad
				worst = maxf(worst, bad)
			# one poisoned stopover is deadly for the flock that rests there; many bad ones weigh on the whole trip
			loss = clampf(0.5 * worst + 2.0 * loss / float(maxi(1, used.size())), 0.0, 0.95)
			var target := clampf(1000.0 * clampf(food, 0.2, 1.4) * (1.0 - loss) * r.randf_range(0.92, 1.08), 0.0, 1800.0)
			row[1] = row[0]
			row[0] = int(row[0]) + roundi((target - float(row[0])) * float(PULL_PM) / 1000.0)
			if int(row[0]) < GONE and int(row[2]) == 0:
				row[2] = 1
				events.append({"kind": "GONE", "flock": f, "size": int(row[0])})
			elif int(row[0]) >= 2 * GONE:
				row[2] = 0
		# arrival at the colony: the flock reaches the colony's hex or a neighbour (breeding, passing or wintering)
		var here := false
		var was := false
		for c in now["cells"]:
			here = here or int(c) in near
		for c in before["cells"]:
			was = was or int(c) in near
		if here and not was and now["phase"] != "SOUTH":   # news of arrivals, not of the autumn passage south
			var sz := int(row[0])
			var last := int(row[1])
			if sz < FAILED or sz * 10 <= last * 7:
				events.append({"kind": "FAILED", "flock": f, "size": sz, "last": last, "phase": now["phase"]})
			else:
				events.append({"kind": "ARRIVED", "flock": f, "size": sz, "last": last, "phase": now["phase"],
					"great": sz >= GREAT or sz * 10 >= last * 13})
		st[fid] = row
	t["birds"] = st
	return events
