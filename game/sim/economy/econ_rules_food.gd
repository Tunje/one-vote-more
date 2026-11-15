class_name EconRulesFood
extends RefCounted
## R8 step 3 (Bob; planning/eight-rules.md): food under the eight rules. Switch R8 + R8_FOOD. Kill switches for the
## A/B take-apart (names in meta "on"): R8F_NOHH (households' value bids), R8F_NOFAMASK (family ask floor),
## R8F_NOFAMOUT (families produce for their sales), R8F_NOENTRY (families found on capacity against orders).
##
## Why (probe, seed 5 × 22 years, E160 + E162 at HEAD 2026-11-15): from year 15 the food market deadlocked. Asks stayed
## near 200 (firm_ai's floor, 0.9 × a big farm's full cost, for families too), the price index fell on cover to ~75,
## and households bid 3 × the index (~220): by year 21 a third of households' food orders were refused with food on
## offer ("unit > limit"), while 107 family farms ran at full output (T = 1.0) whatever they sold. User: food is a
## good like any other; buyers bid what it is worth to them, sellers decide what they accept, no price rule.
##
##   households: essential FOOD is bid up to what the household can spend on it (its cash per unit ordered, net of the
##     shop margin, sales tax and freight allowance), never under the old 3 × price, never over the price ceiling.
##     A hungry household with money pays the ask; it still pays only the ask.
##   family ask: a family firm's ask floor is its own unit cost (EconFamily.family_unit_cost: no wages, the ungranted
##     share of the building), not a wage-paying company's.
##   family output (rules 3/4): a family plant follows its sales like any producer (FirmAI._producer_target) instead of
##     working at full output; its hands are its own, so nobody is laid off.
##   family entry (rules 7/8): no family founds a farm (bakery) while the open plants making the good could already
##     make what buyers ordered (last month's output ≥ COVERED × orders), or no order goes unfilled
##     within its reach. Production against orders, not stock already piled up.

const S := EconUtil.S
const FAMILY_TYPES := {"FAMFARM": "FOOD", "FAMBAKERY": "FINE_FOOD"}
const COVERED := 1.05


static func on(world: WorldState) -> bool:
	return EconRules.sector_on(world, "FOOD")


static func _part(world: WorldState, kill: String) -> bool:
	return on(world) and not (world.meta.get("on", []) as Array).has(kill)


static func hh_on(world: WorldState) -> bool:
	return _part(world, "R8F_NOHH")


static func famask_on(world: WorldState) -> bool:
	return _part(world, "R8F_NOFAMASK")


static func famout_on(world: WorldState) -> bool:
	return _part(world, "R8F_NOFAMOUT")


static func entry_on(world: WorldState) -> bool:
	return _part(world, "R8F_NOENTRY")


## A household's limit for essential `good` (FOOD, FINE_FOOD): its cash per unit ordered, net of what comes on top of
## the ask (shop margin, sales tax, freight allowance `eff_mult` = price_eff ÷ price), at least the old limit and at
## most the price ceiling.
static func hh_limit(world: WorldState, good: String, old_lim: int, cash: int, qty: int, eff_mult: float) -> int:
	if not hh_on(world) or qty <= 0 or cash <= 0:
		return old_lim
	var s := EconUtil.st(world)
	var cap := int(float(s["base"][good]) * EconData.PRICE_MAX_MULT * EconMarket.wage_level(world))
	var per := int(float(cash) * float(S) / float(qty) / maxf(1.0, eff_mult))
	return maxi(old_lim, mini(per, cap))


## A family firm's ask floor basis (mcr/unit): its own unit cost with the grant share it was given.
static func family_full_cost(world: WorldState, oid: String, ftype: String) -> float:
	var o: Dictionary = world.table("org")[oid]
	var est := float(EconConstruction.estimate(ftype)) if EconData.BUILD.has(ftype) else 0.0
	var pct := 0
	if est > 0.0:
		pct = clampi(int(100.0 * float(int(o.get("grant_paid", 0))) / est), 0, 100)
	return EconFamily.family_unit_cost(world, ftype, pct)


## Whether the family's plant keeps the old full-output rule.
static func family_full_output(world: WorldState, o: Dictionary) -> bool:
	return bool(o.get("family", false)) and not famout_on(world)


## Rules 7/8 for a family plant of `ftype` in district d: "" to go ahead, else the reason it does not.
static func family_entry_block(world: WorldState, ftype: String, d: String) -> String:
	if not entry_on(world) or not FAMILY_TYPES.has(ftype):
		return ""
	var good := String(FAMILY_TYPES[ftype])
	var ms: Dictionary = EconUtil.st(world).get("market_stats", {}).get(good, {})
	var wanted := float(maxi(int(ms.get("D", 0)), int(ms.get("wanted", 0))))
	if wanted <= 0.0:
		return "no_customers"
	if output(world, good) >= COVERED * wanted:
		return "covered"
	if EconRules.reachable_unfilled(world, good, d) <= 0:
		return "no_customers"
	return ""


## What the open plants making `good` made last month (mu × S).
static func output(world: WorldState, good: String) -> float:
	var c := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if not f["mothball"] and not r.is_empty() and String(r["out"][0]) == good:
			c += float(int(f.get("out_last", 0)))
	return c


## What the open plants making `good` could make in a month at their present efficiency (mu × S).
static func capacity(world: WorldState, good: String) -> float:
	var c := 0.0
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"]:
			continue
		var r: Dictionary = EconData.RECIPES.get(f["type"], {})
		if r.is_empty() or String(r["out"][0]) != good:
			continue
		c += float(r["out"][1]) * float(S) * EconUtil.fscale(f) * EconProduction._eff(world, f)
	return c
