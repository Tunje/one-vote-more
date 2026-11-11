class_name Terrain
extends RefCounted
## M13 (planning/spec-areas-v1.md §1): the colony's 2D terrain map, generated per seed (stream "map.terrain").
## Simulation state, not decoration: farms want fertile/river land, mines want deposits, housing wants plain.
## Stored in world table "map": {"grid": {"w", "h", "rows": [String per row], "landing": [x, y]}, "uses": {"x,y": {...}}}.
## Codes:  . plain   f fertile   r river   h hills   k rock   o ore deposit   x rare-mineral deposit
##         n native-crop land   L landing site

const W := 64
const H := 40
const NAMES := {".": "plain", "f": "fertile land", "r": "river", "h": "hills", "k": "rock", "o": "ore deposit",
	"x": "rare-mineral deposit", "n": "native-crop land", "L": "landing site"}
## What each terrain allows (housing on plain/fertile/landing; farms on fertile/river edge; mines on deposits).
const BUILDABLE_HOUSING := [".", "f", "L", "n"]


static func generate(world: WorldState) -> void:
	var r := world.rng.stream("map.terrain")
	var g: Array = []
	for _y in H:
		var row: Array = []
		row.resize(W)
		row.fill(".")
		g.append(row)
	# a river from the north edge to the south edge (random walk), fertile banks
	var x := r.randi_range(W / 3, 2 * W / 3)
	for y in H:
		x = clampi(x + r.randi_range(-1, 1), 2, W - 3)
		g[y][x] = "r"
		if r.randf() < 0.4:
			g[y][mini(W - 1, x + 1)] = "r"
	for y in H:
		for xx in W:
			if g[y][xx] == "r":
				for d in [-2, -1, 1, 2]:
					var nx: int = xx + d
					if nx >= 0 and nx < W and g[y][nx] == ".":
						g[y][nx] = "f"
	# hills with rocky cores
	for _i in 5:
		var cx := r.randi_range(4, W - 5)
		var cy := r.randi_range(4, H - 5)
		var rad := r.randi_range(3, 6)
		for y in range(maxi(0, cy - rad), mini(H, cy + rad + 1)):
			for xx in range(maxi(0, cx - rad), mini(W, cx + rad + 1)):
				var dd := Vector2(xx - cx, y - cy).length() * (0.75 + 0.5 * r.randf())  # ragged edges
				if dd <= rad and g[y][xx] in [".", "f"]:
					g[y][xx] = "k" if dd <= rad * 0.4 else "h"
	# a tributary stream from a random edge point toward the river, with fertile banks
	var ty := r.randi_range(4, H - 5)
	var tx := 0 if r.randf() < 0.5 else W - 1
	for _s in W:
		if g[ty][tx] == "r":
			break
		if g[ty][tx] in [".", "f"]:
			g[ty][tx] = "r"
			for d2 in [-1, 1]:
				if ty + d2 >= 0 and ty + d2 < H and g[ty + d2][tx] == ".":
					g[ty + d2][tx] = "f"
		tx += 1 if tx < W / 2 else -1
		if r.randf() < 0.3:
			ty = clampi(ty + r.randi_range(-1, 1), 1, H - 2)
	# scattered fertile meadows
	for _i in 7:
		var mx := r.randi_range(2, W - 3)
		var my := r.randi_range(2, H - 3)
		for _j in r.randi_range(4, 12):
			var px := clampi(mx + r.randi_range(-2, 2), 0, W - 1)
			var py := clampi(my + r.randi_range(-2, 2), 0, H - 1)
			if g[py][px] == ".":
				g[py][px] = "f"
	# deposits: ore in hills, rare minerals in rock, native-crop land on far plains
	_scatter(g, r, "o", ["h", "k"], 5)
	_scatter(g, r, "x", ["k"], 2)
	for _i in 2:
		var cx2 := r.randi_range(3, W - 4)
		var cy2 := r.randi_range(3, H - 4)
		for y in range(maxi(0, cy2 - 2), mini(H, cy2 + 3)):
			for xx in range(maxi(0, cx2 - 2), mini(W, cx2 + 3)):
				if g[y][xx] == ".":
					g[y][xx] = "n"
	# landing site: plain or fertile ground near the river, near the middle of the map
	var best := Vector2i(W / 2, H / 2)
	var best_d := INF
	for y in range(H / 4, 3 * H / 4):
		for xx in range(W / 4, 3 * W / 4):
			if not (g[y][xx] in [".", "f"]):
				continue
			var river_d := _nearest(g, xx, y, "r")
			var d2 := absf(river_d - 3.0) * 3.0 + Vector2(xx - W / 2, y - H / 2).length() * 0.5 + r.randf()
			if d2 < best_d:
				best_d = d2
				best = Vector2i(xx, y)
	g[best.y][best.x] = "L"
	var rows: Array = []
	for y in H:
		rows.append("".join(g[y]))
	var m := world.table("map")
	m["grid"] = {"w": W, "h": H, "rows": rows, "landing": [best.x, best.y]}
	m["uses"] = {}


static func _scatter(g: Array, r: RandomNumberGenerator, code: String, on: Array, n: int) -> void:
	var placed := 0
	for _try in 400:
		if placed >= n:
			return
		var x := r.randi_range(0, W - 1)
		var y := r.randi_range(0, H - 1)
		if g[y][x] in on:
			g[y][x] = code
			placed += 1


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
