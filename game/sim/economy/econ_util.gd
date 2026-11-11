class_name EconUtil
extends RefCounted
## Shared helpers for the economy: accounts, inventories (quantity ledger), paths, rounding.
## All state goes through WorldState; this class holds no state (except a cache of constant path data).

const S := 1000  # fixed-point scale

const TREASURY := "gov:treasury"
const FINES := "gov:fines_revenue"
const BANK := "bank"


static func st(world: WorldState) -> Dictionary:
	return world.table("econ")["s"]


## Read-only econ state for queries/UI (README rule 10): never creates tables.
static func peek_st(world: WorldState) -> Dictionary:
	return world.peek("econ").get("s", {})


static func acct(org_id: String) -> String:
	return "co:" + org_id


static func hh_acct(group_id: String) -> String:
	return "hh:" + group_id


static func cash(world: WorldState, account: String) -> int:
	return world.ledger.balance(account)


## Transfer that never overdraws: returns the amount actually paid.
static func pay_upto(world: WorldState, from_acct: String, to_acct: String, amount: int, memo: String) -> int:
	if amount <= 0:
		return 0
	var avail: int = world.ledger.balance(from_acct) if from_acct != Ledger.EXTERNAL else amount
	var amt := mini(amount, maxi(avail, 0))
	if amt > 0:
		world.ledger.transfer(from_acct, to_acct, amt, memo, world.month)
	return amt


## Value in mcr of qty (mu) at price (mcr per unit).
static func val(qty_mu: int, price_mcr: int) -> int:
	return int(qty_mu * price_mcr / S)


## Facility capacity multiplier (modular expansion, E54). 1.0 = one standard recipe unit.
static func fscale(f: Dictionary) -> float:
	return float(f.get("scale", 1000)) / 1000.0


static func lever(world: WorldState, id: String, default_value = 0):
	return world.levers.get(id, default_value)


# ---------- inventory (quantity ledger, spec §16 L6 implemented as an econ table) ----------

static func _ikey(holder: String, good: String, district: String) -> String:
	return "%s|%s|%s" % [holder, good, district]


static func inv_get(world: WorldState, holder: String, good: String, district: String) -> int:
	return world.peek("inv").get(_ikey(holder, good, district), {}).get("q", 0)  # pure read


static func inv_wac(world: WorldState, holder: String, good: String, district: String) -> int:
	return world.table("inv").get(_ikey(holder, good, district), {}).get("wac", 0)


## Add qty (mu) at unit cost (mcr/unit); updates weighted-average cost.
static func inv_add(world: WorldState, holder: String, good: String, district: String, qty: int, unit_cost: int) -> void:
	if qty <= 0:
		return
	var t := world.table("inv")
	var k := _ikey(holder, good, district)
	if not t.has(k):
		t[k] = {"q": 0, "wac": 0}
	var r: Dictionary = t[k]
	var tot: int = r["q"] + qty
	r["wac"] = int((float(r["q"]) * r["wac"] + float(qty) * unit_cost) / float(tot))
	r["q"] = tot


## Remove up to qty; returns qty removed.
static func inv_take(world: WorldState, holder: String, good: String, district: String, qty: int) -> int:
	var t := world.table("inv")
	var k := _ikey(holder, good, district)
	if qty <= 0 or not t.has(k):
		return 0
	var r: Dictionary = t[k]
	var got := mini(qty, r["q"])
	r["q"] -= got
	return got


## Record a quantity flow for conservation accounting: kind = made | imported | burned.
static func qflow(world: WorldState, good: String, kind: String, qty: int) -> void:
	var f: Dictionary = st(world)["qflow"]
	if not f.has(good):
		f[good] = {"made": 0, "imported": 0, "burned": 0, "initial": 0}
	f[good][kind] += qty


## Sum of all stored qty of a good (for conservation checks).
static func inv_sum(world: WorldState, good: String) -> int:
	var tot := 0
	for k in world.table("inv"):
		if k.split("|")[1] == good:
			tot += world.table("inv")[k]["q"]
	return tot


# ---------- map ----------

static var _dist_cache: Dictionary = {}

## Number of links on the shortest path between two districts (-1 if unreachable).
static func hops(a: String, b: String) -> int:
	if a == b:
		return 0
	var key := a + ">" + b
	if _dist_cache.has(key):
		return _dist_cache[key]
	var adj := {}
	for l in EconData.LINKS:
		adj[l[0]] = adj.get(l[0], []) + [l[1]]
		adj[l[1]] = adj.get(l[1], []) + [l[0]]
	var dist := {a: 0}
	var q: Array = [a]
	while not q.is_empty():
		var c: String = q.pop_front()
		for n in adj.get(c, []):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	var r: int = dist.get(b, -1)
	_dist_cache[key] = r
	return r


static func neighbours(d: String) -> Array:
	var out: Array = []
	for l in EconData.LINKS:
		if l[0] == d: out.append(l[1])
		elif l[1] == d: out.append(l[0])
	return out


static func connected(d: String) -> bool:
	return d == "d:1" or hops("d:1", d) > 0


# ---------- rounding ----------

## Split total (int) proportionally to weights (Array of floats) by largest remainder; ties by index.
static func split_lr(total: int, weights: Array) -> Array:
	var n := weights.size()
	var out: Array = []
	out.resize(n)
	out.fill(0)
	var wsum := 0.0
	for w in weights:
		wsum += maxf(float(w), 0.0)
	if n == 0 or total <= 0 or wsum <= 0.0:
		return out
	var rems: Array = []
	var used := 0
	for i in n:
		var exact := float(total) * maxf(float(weights[i]), 0.0) / wsum
		out[i] = int(floor(exact))
		used += out[i]
		rems.append([exact - floor(exact), i])
	rems.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var left := total - used
	var j := 0
	while left > 0 and j < rems.size():
		out[rems[j][1]] += 1
		left -= 1
		j += 1
	return out


## Deterministic normal draw (Irwin-Hall approx) from a named stream.
static func normal(world: WorldState, stream: String, sigma: float) -> float:
	var r := world.rng.stream(stream)
	var s := 0.0
	for _i in 12:
		s += r.randf()
	return (s - 6.0) * sigma


static func sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k
