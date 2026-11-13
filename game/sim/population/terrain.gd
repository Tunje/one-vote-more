class_name Terrain
extends RefCounted
## M13 (planning/spec-areas-v1.md §1): the colony's 2D terrain map. Simulation state, not decoration: farms want
## fertile/river land, mines want deposits, housing wants plain.
## Since 2026-11-12 (Wilma) the map is the landing region of the globe: derive() builds it from the landing hex and its
## neighbours (Planet), so the flat map and the globe read as the same place.
## Stored in world table "map": {"grid": {"w", "h", "rows": [String per row], "landing": [x, y], "mouth": [x, y]},
## "uses": {"x,y": {...}}}. ("mouth": where the river leaves the map.)
## Codes:  . plain   f fertile   r river   h hills   k rock   o ore deposit   x rare-mineral deposit
##         n native-crop land   L landing site   ~ sea (nothing is built on it; roads cannot cross it)

## The map holds the whole landing hex (~250 km corner to corner, up to 290 km on the stretched hexes): 96 × 96 tiles of
## 3 km (Wilma, 2026-11-12: the tall map). Its corners show the neighbouring hexes, so its edges match the globe.
const W := 96
const H := 96
const KM_PER_TILE := 3
## How far (tiles) hex borders wobble on the map, so coasts and land edges are not straight lines.
const WARP := 2.5
## A mining site near the colony: ore within this many tiles of the map's middle, else a patch in the hills (derive).
const ORE_NEAR := 30
const NAMES := {".": "plain", "f": "fertile land", "r": "river", "h": "hills", "k": "rock", "o": "ore deposit",
	"x": "rare-mineral deposit", "n": "native-crop land", "L": "landing site", "~": "sea"}
## What each terrain allows (housing on plain/fertile/landing; farms on fertile/river edge; mines on deposits).
const BUILDABLE_HOUSING := [".", "f", "L", "n"]
## Water a road cannot cross (the river can be bridged).
const SEA := "~"
## Share of a biome's open land that is fertile meadow (river banks come on top), and native-crop land.
const FERTILE_SHARE := {"f": 0.10, "g": 0.05, "F": 0.04, "j": 0.05, "w": 0.06, "s": 0.015, "d": 0.0, "T": 0.01, "I": 0.0,
	"h": 0.03, "H": 0.015, "M": 0.0, "P": 0.0}
## Biomes whose river banks are wide and green (two tiles in places); elsewhere one tile.
const WET_BANKS := ["f", "F", "j", "w", "g"]
const NATIVE_SHARE := {"j": 0.16, "w": 0.12, "F": 0.04, "f": 0.03, "g": 0.03, "s": 0.02, "h": 0.02, "H": 0.01, "T": 0.01,
	"d": 0.01, "I": 0.0, "M": 0.01, "P": 0.0}


static func generate(world: WorldState) -> void:
	if not Planet.ready(world):
		Planet.generate(world)
		if ready(world):   # an expedition world writes its map while the planet is made
			return
	var d := derive(world)
	var m := world.table("map")
	m["grid"] = {"w": W, "h": H, "rows": d["rows"], "landing": d["landing"], "mouth": d["mouth"]}
	m["uses"] = {}


## The colony map as the landing region of the globe: W × H tiles of 3 km centred on the landing hex, laid on the
## globe with Planet.colony_frame. Pure in the planet (own RNG from the planet seed, no world stream):
##   base     every tile takes the globe cell it lies in (Planet.cell_at; borders wobble by WARP tiles): the landing
##            hex in the middle, the neighbours in the corners. Sea cells are sea ("~"); heights blend smoothly between
##            cell centres like the globe's terrain, so a higher neighbour raises its side into hills and rock;
##   detail   relief noise (hills with rocky cores, more on high ground), meadows and native-crop land by biome;
##   river    enters from the neighbour that drains here (Planet.inflows; else it rises at a spring on the landing
##            hex's high ground) and leaves towards Planet.downstream, into the sea when that is the sea. One mouth,
##            no forks; a tributary (the second inflow, else a hill stream) joins it;
##   deposits each hex's Planet.deposit as patches on its own hills, plus a few small local ones.
## Returns {"rows": [String], "landing": [x, y], "mouth": [x, y] (where the river leaves the map)}.
static func derive(world: WorldState) -> Dictionary:
	var li := Planet.landing(world)
	var fq := Planet.freq(world)
	var fr := Planet.colony_frame(world)
	var geo := Planet.geometry(fq)
	var cs: PackedVector3Array = geo["centers"]
	var sd := Planet._mix(Planet.seed_of(world), li)
	var r := RandomNumberGenerator.new()
	r.seed = sd ^ 0x7e44a1
	var relief := _nz(sd + 1, 0.07, 4)
	var wob_x := _nz(sd + 2, 0.06, 3)
	var wob_y := _nz(sd + 5, 0.06, 3)
	var meadow := _nz(sd + 3, 0.11, 3)
	var native := _nz(sd + 4, 0.08, 2)
	var h0 := Planet.height(world, li)
	var spacing := 0.0
	for j in Planet.neighbors(world, li):
		spacing += cs[li].angle_to(cs[j])
	spacing /= float(Planet.neighbors(world, li).size())
	# each tile takes the globe cell it lies in (hex borders wobble a little, so coasts and edges are not straight
	# lines); heights blend smoothly between cell centres like the globe's own terrain; relief noise adds detail
	var g: Array = []
	var hgt: Array = []
	var bio: Array = []
	var cell_of := PackedInt32Array()
	cell_of.resize(W * H)
	for y in H:
		var row: Array = []
		var hrow: Array = []
		var brow: Array = []
		for x in W:
			var gp := Vector2(x + 0.5 + WARP * wob_x.get_noise_2d(x, y), y + 0.5 + WARP * wob_y.get_noise_2d(x, y))
			var dir := Planet.colony_dir(fr, gp)
			var c := Planet.cell_at(dir, fq, li)
			cell_of[y * W + x] = c
			var hs := 0.0
			var ws := 0.0
			for k in [c] + Array(Planet.neighbors(world, c)):
				var wk := maxf(0.0, 1.0 - dir.angle_to(cs[k]) / (1.1 * spacing))
				wk *= wk
				hs += wk * float(maxi(Planet.height(world, k), -3))
				ws += wk
			var hv := hs / maxf(ws, 1e-6)
			var amp := 7.0 + 4.0 * float(maxi(0, Planet.level(world, c)))
			hv += amp * relief.get_noise_2d(x, y) * 1.6
			row.append(SEA if Planet.is_water(world, c) else ".")
			hrow.append(hv)
			brow.append(Planet.biome(world, c))
		g.append(row)
		hgt.append(hrow)
		bio.append(brow)
	# hills and rock: high ground relative to the landing, and at least a few patches (the map keeps its own hills)
	var land: Array = []
	for y in H:
		for x in W:
			if g[y][x] != SEA:
				land.append(Vector2i(x, y))
	var by_h := land.duplicate()
	by_h.sort_custom(func(a, b): return float(hgt[a.y][a.x]) > float(hgt[b.y][b.x]) or (float(hgt[a.y][a.x]) == float(hgt[b.y][b.x]) and (a.y * W + a.x) < (b.y * W + b.x)))
	var n_hill := int(land.size() * 0.05)
	var n_rock := int(land.size() * 0.015)
	for k in by_h.size():
		var t: Vector2i = by_h[k]
		var rel := float(hgt[t.y][t.x]) - float(h0)
		if rel >= 18.0 or k < n_rock:
			g[t.y][t.x] = "k"
		elif rel >= 9.0 or k < n_hill:
			g[t.y][t.x] = "h"
	# meadows (fertile) and native-crop land by biome: the best-scoring tiles of each biome's share
	_by_biome(g, bio, meadow, FERTILE_SHARE, "f")
	_by_biome(g, bio, native, NATIVE_SHARE, "n")
	# the river: in from the neighbour that drains here (else a spring on the landing hex's high ground), out
	# towards where the globe's water goes, into the sea when that is the sea. It never forks: one mouth.
	var out_c := Planet.downstream(world, li)
	var out_dir := _dir_to(fr, cs[out_c]) if out_c >= 0 else Vector2(0, -1)
	var ins := Planet.inflows(world, li)
	var big := Planet.river_flow(world, li) >= Planet.RIVER_MIN
	var mid := Vector2i(W / 2 + r.randi_range(-5, 5), H / 2 + r.randi_range(-5, 5))
	if g[mid.y][mid.x] == SEA:
		mid = Vector2i(W / 2, H / 2)
	var src := _spring(g, hgt, cell_of, li, -out_dir, mid) if ins.is_empty() else _edge_tile(_dir_to(fr, cs[int(ins[0][0])]))
	var exit_t := _edge_tile(out_dir)
	var up := _course(g, hgt, r, [src, mid], false)
	var down := _course(g, hgt, r, [mid, exit_t], false)
	# upstream: from the last sea tile before the middle (a river cannot come out of the sea); downstream: to the sea
	var first := 0
	for i in up.size():
		if g[up[i].y][up[i].x] == SEA:
			first = i + 1
	var path: Array = up.slice(first)
	for t in down.slice(1):
		if g[t.y][t.x] == SEA:
			break
		path.append(t)
	var mouth := Vector2i(-1, -1)
	var side := Vector2i(1, 0) if absf(out_dir.y) > absf(out_dir.x) else Vector2i(0, 1)
	for t in path:
		g[t.y][t.x] = "r"
		mouth = t
		if big and r.randf() < 0.4:   # a big river runs two tiles wide in places
			var t2: Vector2i = t + side
			if t2.x >= 0 and t2.y >= 0 and t2.x < W and t2.y < H and g[t2.y][t2.x] != SEA:
				g[t2.y][t2.x] = "r"
	# a tributary joins it: the second inflow from its side, else a stream from a spring in the hills
	var tsrc := _spring(g, hgt, cell_of, li, (-out_dir).rotated(PI / 2.0 * (1.0 if r.randf() < 0.5 else -1.0)), mid)
	if ins.size() >= 2:
		tsrc = _edge_tile(_dir_to(fr, cs[int(ins[1][0])]))
	var trib := _course(g, hgt, r, [tsrc, mid], true)
	var tfirst := 0
	for i in trib.size():
		if g[trib[i].y][trib[i].x] == SEA:
			tfirst = i + 1
	for t in trib.slice(tfirst):
		if g[t.y][t.x] == "r":
			break
		g[t.y][t.x] = "r"
	# fertile banks: one tile, two in places where the country is green
	for y in H:
		for x in W:
			if g[y][x] != "r":
				continue
			var wide := String(bio[y][x]) in WET_BANKS
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = x + dx
					var ny: int = y + dy
					var md := absi(dx) + absi(dy)
					if md == 0 or md > 2 or nx < 0 or ny < 0 or nx >= W or ny >= H or not (g[ny][nx] in [".", "n"]):
						continue
					if md == 1 or (wide and Planet._mix(sd, ny * W + nx) % 100 < 45):
						g[ny][nx] = "f"
	# deposits: each hex's (Planet.deposit) as patches on its own ground, and a few small local ones
	var dep_n := {"o": 0, "x": 0}
	var hexes: Array = [li] + Array(Planet.neighbors(world, li))
	for c2 in hexes:
		var code := Planet.deposit(world, int(c2))
		if code == "":
			continue
		for _patch in (3 if int(c2) == li else 1):
			dep_n[code] += _patch_on(g, r, code, cell_of, int(c2))
	# a mining site near the colony: without ore within ORE_NEAR tiles of the middle, a patch goes into the largest
	# hill range there (so a mining town has a real place to stand)
	if not _has_near(g, "o", Vector2i(W / 2, H / 2), ORE_NEAR):
		dep_n["o"] += _ore_in_hills(g, r, Vector2i(W / 2, H / 2))
	while int(dep_n["o"]) < 5:
		var got := _patch_on(g, r, "o", cell_of, li, 1)
		if got == 0:
			got = _patch_on(g, r, "o", cell_of, -1, 1)
		if got == 0:
			break
		dep_n["o"] += got
	while int(dep_n["x"]) < 2:
		var got2 := _patch_on(g, r, "x", cell_of, li, 1)
		if got2 == 0:
			got2 = _patch_on(g, r, "x", cell_of, -1, 1)
		if got2 == 0:
			break
		dep_n["x"] += got2
	# landing site: plain or fertile ground near the river (not on it), near the middle, away from the sea
	var best := Vector2i(W / 2, H / 2)
	var best_d := INF
	for y in range(H / 4, 3 * H / 4):
		for xx in range(W / 4, 3 * W / 4):
			if not (g[y][xx] in [".", "f"]) or cell_of[y * W + xx] != li:
				continue
			var d2 := absf(_nearest(g, xx, y, "r") - 3.0) * 3.0 + Vector2(xx - W / 2, y - H / 2).length() * 0.5 + r.randf()
			if _nearest(g, xx, y, SEA) < 4.0:
				d2 += 50.0
			if d2 < best_d:
				best_d = d2
				best = Vector2i(xx, y)
	g[best.y][best.x] = "L"
	var rows: Array = []
	for y in H:
		rows.append("".join(g[y]))
	return {"rows": rows, "landing": [best.x, best.y], "mouth": [mouth.x, mouth.y]}


## Direction (x east, y north) from the landing centre towards a globe point, in the map's plane.
static func _dir_to(fr: Dictionary, p: Vector3) -> Vector2:
	return Vector2(p.dot(fr["east"]), p.dot(fr["north"])).normalized()


## A spring: the highest land tile of the landing hex on the side `d` (x east, y north), at least 12 tiles from `mid`.
static func _spring(g: Array, hgt: Array, cell_of: PackedInt32Array, li: int, d: Vector2, mid: Vector2i) -> Vector2i:
	var best := _edge_tile(d)
	var bh := -INF
	for y in H:
		for x in W:
			if cell_of[y * W + x] != li or g[y][x] == SEA:
				continue
			var off := Vector2(x - mid.x, mid.y - y)
			if off.length() < 12.0 or off.normalized().dot(d.normalized()) < 0.5:
				continue
			if float(hgt[y][x]) > bh:
				bh = float(hgt[y][x])
				best = Vector2i(x, y)
	return best


static func _has_near(g: Array, code: String, c: Vector2i, reach: int) -> bool:
	for y in range(maxi(0, c.y - reach), mini(H, c.y + reach + 1)):
		for x in range(maxi(0, c.x - reach), mini(W, c.x + reach + 1)):
			if g[y][x] == code and Vector2(x - c.x, y - c.y).length() <= float(reach):
				return true
	return false


## An ore patch (3–5 tiles) in the largest hill range (connected hills and rock, counting its tiles within ORE_NEAR of
## `c`), at the tile nearest the middle of that part. Returns the tiles placed (0 if there are no hills near).
static func _ore_in_hills(g: Array, r: RandomNumberGenerator, c: Vector2i) -> int:
	var seen := {}
	var best: Array = []
	for y in H:
		for x in W:
			if seen.has(y * W + x) or not (g[y][x] in ["h", "k"]):
				continue
			var comp: Array = []
			var stack: Array = [Vector2i(x, y)]
			seen[y * W + x] = true
			while not stack.is_empty():
				var t: Vector2i = stack.pop_back()
				if Vector2(t - c).length() <= float(ORE_NEAR):
					comp.append(t)   # the part of the range within reach

				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var u: Vector2i = t + d
					if u.x >= 0 and u.y >= 0 and u.x < W and u.y < H and not seen.has(u.y * W + u.x) and g[u.y][u.x] in ["h", "k"]:
						seen[u.y * W + u.x] = true
						stack.append(u)
			if comp.size() > best.size():
				best = comp
	if best.is_empty():
		return 0
	var mid := Vector2.ZERO
	for t in best:
		mid += Vector2(t)
	mid /= float(best.size())
	var at: Vector2i = best[0]
	for t in best:
		if Vector2(t).distance_to(mid) < Vector2(at).distance_to(mid):
			at = t
	var want := r.randi_range(3, 5)
	var placed := 0
	for t in [at, at + Vector2i(1, 0), at + Vector2i(0, 1), at + Vector2i(-1, 0), at + Vector2i(0, -1), at + Vector2i(1, 1), at + Vector2i(-1, -1)]:
		if placed >= want:
			break
		if t.x >= 0 and t.y >= 0 and t.x < W and t.y < H and g[t.y][t.x] in ["h", "k"]:
			g[t.y][t.x] = "o"
			placed += 1
	return placed


static func _nz(sd: int, fq: float, octaves: int) -> FastNoiseLite:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.seed = sd & 0x7fffffff
	nz.frequency = fq
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = octaves
	return nz


static func _dir_of(nbs: Array, cell: int) -> Vector2:
	for nb in nbs:
		if int(nb["cell"]) == cell:
			return nb["dir"]
	return Vector2(0, 1)


## The edge tile of the map in direction `d` from the centre (d: x east, y north).
static func _edge_tile(d: Vector2) -> Vector2i:
	var s := minf(float(W) / 2.0 / maxf(absf(d.x), 1e-6), float(H) / 2.0 / maxf(absf(d.y), 1e-6))
	return Vector2i(clampi(int(floor(float(W) / 2.0 + d.x * s)), 0, W - 1), clampi(int(floor(float(H) / 2.0 - d.y * s)), 0, H - 1))


## A river's course through waypoints: between each pair, a few more waypoints pushed sideways (a meander that
## swings back and forth), then walked tile by tile. Ends at the river when `stop_at_river`.
static func _course(g: Array, hgt: Array, r: RandomNumberGenerator, pts: Array, stop_at_river: bool) -> Array:
	var way: Array = [pts[0]]
	for k in range(1, pts.size()):
		var a: Vector2i = pts[k - 1]
		var b: Vector2i = pts[k]
		var dv := Vector2(b - a)
		var n := int(dv.length() / 7.0)
		var perp := Vector2(-dv.y, dv.x).normalized()
		var swing := 0.0
		for i in range(1, n):
			swing = clampf(swing + r.randf_range(-2.5, 2.5), -4.0, 4.0)
			var p := Vector2(a) + dv * float(i) / float(n) + perp * swing
			way.append(Vector2i(clampi(roundi(p.x), 0, W - 1), clampi(roundi(p.y), 0, H - 1)))
		way.append(b)
	var path: Array = [way[0]]
	for k in range(1, way.size()):
		var seg := _walk(g, hgt, r, way[k - 1], way[k], stop_at_river)
		path += seg.slice(1)
		if stop_at_river and not seg.is_empty() and g[seg[-1].y][seg[-1].x] == "r":
			break
	return path


## A meandering 4-connected path from a to b (each step closer), preferring low ground. With `stop_at_river` it ends
## where it meets the river.
static func _walk(g: Array, hgt: Array, r: RandomNumberGenerator, a: Vector2i, b: Vector2i, stop_at_river: bool) -> Array:
	var path: Array = [a]
	var cur := a
	for _s in W * H:
		if cur == b:
			break
		var moves: Array = []
		if cur.x != b.x:
			moves.append(Vector2i(signi(b.x - cur.x), 0))
		if cur.y != b.y:
			moves.append(Vector2i(0, signi(b.y - cur.y)))
		var mv: Vector2i = moves[0]
		if moves.size() == 2:
			var ta: Vector2i = cur + moves[0]
			var tb: Vector2i = cur + moves[1]
			# step along the longer leg in proportion (a diagonal course zig-zags), prefer lower ground
			var pa := float(absi(b.x - cur.x)) / float(absi(b.x - cur.x) + absi(b.y - cur.y))
			pa += 0.15 * signf(float(hgt[tb.y][tb.x]) - float(hgt[ta.y][ta.x]))
			mv = moves[0] if r.randf() < pa else moves[1]
		cur += mv
		path.append(cur)
		if stop_at_river and g[cur.y][cur.x] == "r":
			break
	return path


## Each biome's share of its open land becomes `code`: the tiles where noise `nz` is highest (patches, not speckle).
static func _by_biome(g: Array, bio: Array, nz: FastNoiseLite, share: Dictionary, code: String) -> void:
	var groups := {}
	for y in H:
		for x in W:
			if g[y][x] != ".":
				continue
			var b := String(bio[y][x])
			if not groups.has(b):
				groups[b] = []
			groups[b].append([nz.get_noise_2d(x, y), y * W + x])
	for b in groups:
		var arr: Array = groups[b]
		arr.sort_custom(func(p, q): return float(p[0]) > float(q[0]) or (float(p[0]) == float(q[0]) and int(p[1]) < int(q[1])))
		var n := int(round(float(arr.size()) * float(share.get(b, 0.0))))
		for k in n:
			var ti: int = arr[k][1]
			g[ti / W][ti % W] = code


## A deposit patch (2–4 tiles; `n` to force a size) on hills or rock of hex `cell` (-1: anywhere on the map). Rare
## minerals only on rock. Returns the tiles placed.
static func _patch_on(g: Array, r: RandomNumberGenerator, code: String, cell_of: PackedInt32Array, cell: int, n: int = 0) -> int:
	var on: Array = ["k"] if code == "x" else ["h", "k"]
	var cands: Array = []
	for y in H:
		for x in W:
			if g[y][x] in on and (cell < 0 or cell_of[y * W + x] == cell):
				cands.append(Vector2i(x, y))
	if cands.is_empty():
		return 0
	var c: Vector2i = cands[r.randi_range(0, cands.size() - 1)]
	var want := n if n > 0 else r.randi_range(2, 4)
	var placed := 0
	for t in [c, c + Vector2i(1, 0), c + Vector2i(0, 1), c + Vector2i(-1, 0), c + Vector2i(0, -1), c + Vector2i(1, 1)]:
		if placed >= want:
			break
		if t.x >= 0 and t.y >= 0 and t.x < W and t.y < H and g[t.y][t.x] in on:
			g[t.y][t.x] = code
			placed += 1
	return placed


static func _nearest(g: Array, x: int, y: int, code: String) -> float:
	var best := 99.0
	for yy in range(maxi(0, y - 8), mini(H, y + 9)):
		for xx in range(maxi(0, x - 8), mini(W, x + 9)):
			if g[yy][xx] == code:
				best = minf(best, Vector2(xx - x, yy - y).length())
	return best


# ======================================================================= reads

static func ready(world: WorldState) -> bool:
	return world.peek("map").has("grid")


static func at(world: WorldState, x: int, y: int) -> String:
	var gr: Dictionary = world.peek("map").get("grid", {})
	if gr.is_empty() or x < 0 or y < 0 or x >= int(gr["w"]) or y >= int(gr["h"]):
		return ""
	return String(gr["rows"][y]).substr(x, 1)


static func landing(world: WorldState) -> Vector2i:
	var l: Array = world.peek("map")["grid"]["landing"]
	return Vector2i(int(l[0]), int(l[1]))


static func key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


static func use_at(world: WorldState, x: int, y: int) -> Dictionary:
	return world.peek("map").get("uses", {}).get(key(x, y), {})


static func set_use(world: WorldState, x: int, y: int, use: Dictionary) -> void:
	var u: Dictionary = world.table("map")["uses"]
	if use.is_empty():
		u.erase(key(x, y))
	else:
		u[key(x, y)] = use


## Nearest free tile of one of `codes` to (x, y), within `reach`; Vector2i(-1, -1) if none.
static func nearest_free(world: WorldState, x: int, y: int, codes: Array, reach: int = 40) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for yy in range(maxi(0, y - reach), mini(H, y + reach + 1)):
		for xx in range(maxi(0, x - reach), mini(W, x + reach + 1)):
			if at(world, xx, yy) in codes and use_at(world, xx, yy).is_empty():
				var d := Vector2(xx - x, yy - y).length()
				if d < best_d:
					best_d = d
					best = Vector2i(xx, yy)
	return best


static func distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()
