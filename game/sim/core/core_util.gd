class_name CoreUtil
extends RefCounted
## General helpers every part of the game uses (they lived in the economy's EconUtil until the economy was cut out,
## 2026-11-17): fixed-point scale, the government's ledger accounts, ordered keys, proportional splits, safe payments.

const S := 1000  # fixed-point scale
const TREASURY := "gov:treasury"
const FINES := "gov:fines_revenue"


static func sorted_keys(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


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


## A/B switch for tools only: world.meta["off"] lists mechanisms to disable. Never set in play.
static func off(world: WorldState, key: String) -> bool:
	return world.meta.has("off") and (world.meta["off"] as Array).has(key)


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


# ---- plain readers of world data (no rules of their own). The economy that filled these tables was cut out on
# ---- 2026-11-17; whatever replaces it must fill the same shapes for the law, the press and the map to read.

static func acct(org_id: String) -> String:
	return "co:" + org_id


static func hh_acct(group_id: String) -> String:
	return "hh:" + group_id


static func hb_of(district: String) -> String:
	return "hb:" + district


static func district_of(hb: String) -> String:
	return hb.substr(3)


## The economy's shared state ({} while there is no economy).
static func econ_state(world: WorldState) -> Dictionary:
	return world.peek("econ").get("s", {})


## People in a household group.
static func persons(g: Dictionary) -> int:
	return int(g.get("lf", 0)) + int(g.get("nonpart", 0)) + int(g.get("retired", 0)) + int(g.get("children", 0)) + int(g.get("owners", 0))


static func disposable(g: Dictionary) -> int:
	var i: Dictionary = g.get("income", {})
	return int(i.get("wages", 0)) + int(i.get("benefit", 0)) + int(i.get("pension", 0)) + int(i.get("dividend", 0)) + int(i.get("self", 0))


static func employed(g: Dictionary) -> int:
	var n := 0
	for occ in g.get("emp", {}):
		n += int(g["emp"][occ])
	return n


static func staff_total(staff: Dictionary) -> int:
	var n := 0
	for t in staff:
		for g in staff[t]:
			n += int(staff[t][g])
	return n


## A plant's size (1.0 = one standard unit).
static func fscale(f: Dictionary) -> float:
	return float(f.get("scale", 1000)) / 1000.0


const PL_MIN_M := 3  # months of history before a firm's yearly figures are used

static func pl_months(o: Dictionary) -> int:
	return (o.get("pl_ring", []) as Array).size()


static func pl_sum12(o: Dictionary) -> Dictionary:
	var out := {}
	for pl in o.get("pl_ring", []):
		for k in pl:
			out[k] = int(out.get(k, 0)) + int(pl[k])
	return out


static func union(world: WorldState, id: String) -> Dictionary:
	return world.peek("union").get(id, {})


## The active union federation, or {}.
static func federation(world: WorldState) -> Dictionary:
	var t := world.peek("union")
	for id in sorted_keys(t):
		if bool(t[id].get("federation", false)) and String(t[id].get("status", "ACTIVE")) == "ACTIVE":
			return t[id]
	return {}


## What a union holds (0 when there is no such union).
static func union_fund(world: WorldState, id: String) -> int:
	var u := union(world, id)
	var a := String(u.get("acct", ""))
	return world.ledger.balance(a) if a != "" and world.ledger.has_account(a) else 0


## Active unions (federation included), in id order.
static func unions_active(world: WorldState) -> Array:
	var out: Array = []
	var t := world.peek("union")
	for id in sorted_keys(t):
		if String(t[id].get("status", "")) == "ACTIVE":
			out.append(t[id])
	return out


## The active sector union that organises an occupation, or {}.
static func union_of_occ(world: WorldState, occ: String) -> Dictionary:
	for u in unions_active(world):
		if not bool(u.get("federation", false)) and occ in (u.get("sectors", []) as Array):
			return u
	return {}
