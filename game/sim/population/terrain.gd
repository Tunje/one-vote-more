class_name Terrain
extends RefCounted
## M13 (planning/spec-areas-v1.md §1): the colony's 2D terrain map. Simulation state, not decoration: farms want
## fertile/river land, mines want deposits, housing wants plain.
## Since 2026-11-12 (Wilma) the map is the landing region of the globe: derive() builds it from the landing hex and its
## six neighbours (Planet), so the flat map and the globe read as the same place. Old saves keep their stored grid.
## Stored in world table "map": {"grid": {"w", "h", "rows": [String per row], "landing": [x, y], "mouth": [x, y]},
## "uses": {"x,y": {...}}}. ("mouth": where the river leaves the map; absent in old saves.)
## Codes:  . plain   f fertile   r river   h hills   k rock   o ore deposit   x rare-mineral deposit
##         n native-crop land   L landing site   ~ sea (nothing is built on it; roads cannot cross it)

const W := 64
const H := 40
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


## The colony map as the landing region of the globe: a 192×120 km window centred on the landing hex, laid on the
## globe with Planet.colony_frame. Pure in the planet (own RNG from the planet seed, no world stream):
##   base     the landing hex's height and biome; the edges blend toward the six neighbours (a sea neighbour puts a
##            coast on its side, a mountain neighbour raises its edge, a desert neighbour dries its edge);
##   detail   local relief noise (hills with rocky cores, more of them on high ground), meadows and native-crop land
##            by biome, so the map keeps its own 3 km detail;
##   river    enters from the neighbour whose water runs in (Planet.inflows) and leaves towards Planet.downstream,
##            into the sea when that is the sea; a second inflow (or a local stream) joins it;
##   deposits the landing hex's and the neighbours' deposits (Planet.deposit) as patches in the hills on their side,
##            plus a few small local ones.
## Returns {"rows": [String], "landing": [x, y], "mouth": [x, y] (where the river leaves the map)}.
static func derive(world: WorldState) -> Dictionary:
	var li := Planet.landing(world)
	var fr := Planet.colony_frame(world)
	var geo := Planet.geometry(Planet.freq(world))
	var east: Vector3 = fr["east"]
	var north: Vector3 = fr["north"]
	var hw: float = fr["hw"]
	var hh: float = fr["hh"]
	var sd := Planet._mix(Planet.seed_of(world), li)
	var r := RandomNumberGenerator.new()
	r.seed = sd ^ 0x7e44a1
	var relief := _nz(sd + 1, 0.07, 4)
	var wob := _nz(sd + 2, 0.09, 3)
	var meadow := _nz(sd + 3, 0.11, 3)
	var native := _nz(sd + 4, 0.08, 2)
	var h0 := Planet.height(world, li)
	var b0 := Planet.biome(world, li)
	var lv0 := Planet.level_of(h0)
	# the neighbours as seen from the landing centre: direction in the map plane and reach to the map's edge that way
	var nbs: Array = []
	for j in Planet.neighbors(world, li):
		var cj: Vector3 = geo["centers"][j]
		var dj := Vector2(cj.dot(east), cj.dot(north)).normalized()
		var reach := minf(hw / maxf(absf(dj.x), 1e-6), hh / maxf(absf(dj.y), 1e-6))
		nbs.append({"cell": j, "dir": dj, "reach": reach, "h": Planet.height(world, j), "bio": Planet.biome(world, j),
			"sea": Planet.is_water(world, j)})
	var g: Array = []
	var hgt: Array = []
	var bio: Array = []
	var amp := 7.0 + 4.0 * float(lv0)
	for y in H:
		var row: Array = []
		var hrow: Array = []
		var brow: Array = []
		for x in W:
			var q := Vector2(((x + 0.5) / W - 0.5) * 2.0 * hw, (0.5 - (y + 0.5) / H) * 2.0 * hh)
			var nw := wob.get_noise_2d(x, y)
			var sea := false
			var dh := 0.0
			var wsum := 0.0
			var tb := b0
			var tb_e := 0.0
			for nb in nbs:
				var e: float = q.dot(nb["dir"]) / float(nb["reach"])
				if nb["sea"]:
					sea = sea or e + 0.18 * nw > 0.8
					continue
				var wj := smoothstep(0.25, 1.05, e)
				dh += wj * 0.6 * float(int(nb["h"]) - h0)
				wsum += wj
				if e + 0.2 * nw > 0.78 and e > tb_e:
					tb = String(nb["bio"])
					tb_e = e
			if wsum > 1.0:
				dh /= wsum
			var hv := float(h0) + dh + amp * relief.get_noise_2d(x, y) * 1.6
			row.append(SEA if sea else ".")
			hrow.append(hv)
			brow.append(tb)
		g.append(row)
		hgt.append(hrow)
		bio.append(brow)
	# hills and rock: high relative ground, and at least a few patches anywhere (the map keeps its own hills)
	var land: Array = []
	for y in H:
		for x in W:
			if g[y][x] != SEA:
				land.append(Vector2i(x, y))
	var by_h := land.duplicate()
	by_h.sort_custom(func(a, b): return float(hgt[a.y][a.x]) > float(hgt[b.y][b.x]) or (float(hgt[a.y][a.x]) == float(hgt[b.y][b.x]) and (a.y * W + a.x) < (b.y * W + b.x)))
	var n_hill := int(land.size() * 0.06)
	var n_rock := int(land.size() * 0.018)
	for k in by_h.size():
		var t: Vector2i = by_h[k]
		var rel := float(hgt[t.y][t.x]) - float(h0)
		if rel >= 18.0 or k < n_rock:
			g[t.y][t.x] = "k"
		elif rel >= 9.0 or k < n_hill:
			g[t.y][t.x] = "h"
	# meadows (fertile) and native-crop land by the local biome: the best-scoring tiles of each biome's share
	_by_biome(g, bio, meadow, FERTILE_SHARE, "f")
	_by_biome(g, bio, native, NATIVE_SHARE, "n")
	# the river: in from the neighbour that drains here, out towards where the water goes
	var out_c := Planet.downstream(world, li)
	var out_dir := Vector2(0, -1)
	for nb in nbs:
		if int(nb["cell"]) == out_c:
			out_dir = nb["dir"]
	var ins := Planet.inflows(world, li)
	var in_dir := (-out_dir).rotated(r.randf_range(-0.5, 0.5))
	if not ins.is_empty():
		in_dir = _dir_of(nbs, int(ins[0][0]))
	var big := Planet.river_flow(world, li) >= Planet.RIVER_MIN
	var exit_t := _edge_tile(out_dir, hw, hh)
	var entry_t := _edge_tile(in_dir, hw, hh)
	var mid := Vector2i(W / 2 + r.randi_range(-6, 6), H / 2 + r.randi_range(-4, 4))
	if Vector2(mid - entry_t).length() < 8.0 or Vector2(mid - exit_t).length() < 8.0:
		mid = (entry_t + exit_t) / 2
	var main_path := _course(g, hgt, r, [entry_t, mid, exit_t], false)
	var mouth := Vector2i(-1, -1)
	var side := Vector2i(1, 0) if absf(out_dir.y) > absf(out_dir.x) else Vector2i(0, 1)
	for t in main_path:
		if g[t.y][t.x] == SEA:
			break
		g[t.y][t.x] = "r"
		mouth = t
		if big and r.randf() < 0.4:   # a big river runs two tiles wide in places
			var t2: Vector2i = t + side
			if t2.x >= 0 and t2.y >= 0 and t2.x < W and t2.y < H and g[t2.y][t2.x] != SEA:
				g[t2.y][t2.x] = "r"
	# a tributary: the second inflow, else a local stream from the side
	var tdir := in_dir.rotated(PI / 2.0 * (1.0 if r.randf() < 0.5 else -1.0))
	if ins.size() >= 2:
		tdir = _dir_of(nbs, int(ins[1][0]))
	var trib := _course(g, hgt, r, [_edge_tile(tdir, hw, hh), mid], true)
	if not trib.is_empty() and g[trib[0].y][trib[0].x] != SEA:
		for t in trib:
			if g[t.y][t.x] in ["r", SEA]:
				break
			g[t.y][t.x] = "r"
	# fertile banks: one tile, two in places where the country is green
	var wide := b0 in WET_BANKS
	for y in H:
		for x in W:
			if g[y][x] != "r":
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = x + dx
					var ny: int = y + dy
					var md := absi(dx) + absi(dy)
					if md == 0 or md > 2 or nx < 0 or ny < 0 or nx >= W or ny >= H or not (g[ny][nx] in [".", "n"]):
						continue
					if md == 1 or (wide and Planet._mix(sd, ny * W + nx) % 100 < 45):
						g[ny][nx] = "f"
	# deposits: the landing hex's in the middle, each neighbour's on its side, and a few small local ones
	var sources: Array = [[Planet.deposit(world, li), Vector2.ZERO, 0.0]]
	for nb in nbs:
		sources.append([Planet.deposit(world, int(nb["cell"])), nb["dir"], 1.0])
	var dep_n := {"o": 0, "x": 0}
	for s in sources:
		var code := String(s[0])
		if code == "":
			continue
		for _patch in (2 if float(s[2]) == 0.0 else 1):
			dep_n[code] += _patch_on(g, r, code, s[1], float(s[2]), hw, hh)
	while int(dep_n["o"]) < 4:
		var got := _patch_on(g, r, "o", Vector2.ZERO, -1.0, hw, hh, 1)
		if got == 0:
			break
		dep_n["o"] += got
	while int(dep_n["x"]) < 1:
		var got2 := _patch_on(g, r, "x", Vector2.ZERO, -1.0, hw, hh, 1)
		if got2 == 0:
			break
		dep_n["x"] += got2
	# landing site: plain or fertile ground near the river (not on it), near the middle, away from the sea
	var best := Vector2i(W / 2, H / 2)
	var best_d := INF
	for y in range(H / 4, 3 * H / 4):
		for xx in range(W / 4, 3 * W / 4):
			if not (g[y][xx] in [".", "f"]):
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
static func _edge_tile(d: Vector2, hw: float, hh: float) -> Vector2i:
	var s := minf(hw / maxf(absf(d.x), 1e-6), hh / maxf(absf(d.y), 1e-6))
	var u := d * s   # in frame units: |u.x| <= hw, |u.y| <= hh
	return Vector2i(clampi(int(floor((u.x / hw * 0.5 + 0.5) * W)), 0, W - 1), clampi(int(floor((0.5 - u.y / hh * 0.5) * H)), 0, H - 1))


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


## A deposit patch (2–4 tiles; `n` to force a size) on hills or rock, on the side `dir` (`side` 1.0: the outer part
## of the map that way; 0.0: the middle; -1.0: anywhere). Rare minerals only on rock. Returns the tiles placed.
static func _patch_on(g: Array, r: RandomNumberGenerator, code: String, dir: Vector2, side: float, hw: float, hh: float, n: int = 0) -> int:
	var on: Array = ["k"] if code == "x" else ["h", "k"]
	var cands: Array = []
	for y in H:
		for x in W:
			if not (g[y][x] in on):
				continue
			var q := Vector2(((x + 0.5) / W - 0.5) * 2.0 * hw, (0.5 - (y + 0.5) / H) * 2.0 * hh)
			if side > 0.5:
				var reach := minf(hw / maxf(absf(dir.x), 1e-6), hh / maxf(absf(dir.y), 1e-6))
				if q.dot(dir) / reach < 0.35:
					continue
			elif side == 0.0 and Vector2(q.x / hw, q.y / hh).length() > 0.6:
				continue
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
