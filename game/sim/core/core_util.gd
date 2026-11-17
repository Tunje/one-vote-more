class_name CoreUtil
extends RefCounted
## General helpers every part of the game uses. They lived in the old economy's EconUtil until the economy was cut
## out (2026-11-17); they are not economy. Built by planning/step1_doorway.py (rebuild step 1).

const S := 1000  # fixed-point scale
const TREASURY := "gov:treasury"
const FINES := "gov:fines_revenue"
const BANK := "bank"


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


## A/B switch for tools only: world.meta["off"] lists mechanisms to disable (e.g. "E80"). Never set in play.
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


static func acct(org_id: String) -> String:
	return "co:" + org_id


static func hh_acct(group_id: String) -> String:
	return "hh:" + group_id


## Facility capacity multiplier (modular expansion, E54). 1.0 = one standard recipe unit.
static func fscale(f: Dictionary) -> float:
	return float(f.get("scale", 1000)) / 1000.0


static func lever(world: WorldState, id: String, default_value = 0):
	return world.levers.get(id, default_value)


## The economy's shared state. {} while there is no economy.
static func peek_st(world: WorldState) -> Dictionary:
	return world.peek("econ").get("s", {})


static func st(world: WorldState) -> Dictionary:
	return world.peek("econ").get("s", {})
