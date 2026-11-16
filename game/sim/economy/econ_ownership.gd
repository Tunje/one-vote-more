class_name EconOwnership
extends RefCounted
## E137 (Wilma, user's "best decision" mandate; private-firm diagnosis cause 3, crowd-out): who expands the economy is
## the GOVERNMENT's choice by ideology, not a fixed rule.
##   MARKET (government ECON_ROLE < 0): new plants go to private and co-op investors; the public operator does not
##     pre-build essentials (E105); failed strategic plants are re-privatised at REPRIV_MARKET of book.
##   MIXED (0 .. STATE_FROM): private investors first; the public operator steps in after EXTRA_Q more quarters of
##     scarcity with no taker (in _new_plants and E105).
##   STATE (ECON_ROLE > STATE_FROM): as before — the incumbent (usually the public operator) expands and pre-builds;
##     re-privatisation stops.
## Reads ECON_PUBLIC_OWNERSHIP_POLICY (0 market / 1 mixed / 2 state) when that lever exists, else the government's
## (or, in the founding era, the commander's) ECON_ROLE position. OPT-IN until its A/B (world.meta["on"] has "E137").

const STATE_FROM := 0.2
const EXTRA_Q := 2
const REPRIV_MARKET := 0.4


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("E137") and not EconUtil.off(world, "E137")


## The governing ECON_ROLE position, -1..1 (0 when unknown).
static func econ_role(world: WorldState) -> float:
	var st: Dictionary = world.peek("pol").get("state", {})
	if st.is_empty():
		return 0.0
	if String(st.get("era", "")) == "FOUNDING":
		return float((st.get("persona", {}) as Dictionary).get("ECON_ROLE", 0)) / 100000.0
	return float((st.get("government", {}).get("center", {}) as Dictionary).get("ECON_ROLE", 0)) / 100000.0


## Utilities stay public in v1 (Wilma): a private power or water plant has no buyer but the public grid.
## Under R8_UTILITIES no type is public-only (the user, 2026-11-16: "All company types needs to be able to be created as
## private"): private plants sell to the grid (EconRulesUtil).
const PUBLIC_ONLY := ["POWER", "WATERWORKS"]


## The policy for one plant type (utilities always "STATE").
static func policy_for(world: WorldState, ftype: String) -> String:
	return "STATE" if ftype in PUBLIC_ONLY and not EconRulesUtil.on(world) else policy(world)


## "MARKET" | "MIXED" | "STATE" ("STATE" = the old behaviour when E137 is off).
static func policy(world: WorldState) -> String:
	if not active(world):
		return "STATE"
	if world.levers.has("ECON_PUBLIC_OWNERSHIP_POLICY"):
		return ["MARKET", "MIXED", "STATE"][clampi(int(world.levers["ECON_PUBLIC_OWNERSHIP_POLICY"]), 0, 2)]
	var r := econ_role(world)
	if r < 0.0:
		return "MARKET"
	return "STATE" if r > STATE_FROM else "MIXED"


## The richest active private or co-op firm (not a builder) that can put down CASH_SHARE of a plant's cost, "" if none.
static func private_investor(world: WorldState, est: int) -> String:
	var best := ""
	var best_cash := est * 3 / 10
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if o["status"] != "ACTIVE" or o["is_contractor"] or not (o["type"] in ["PRIVATE", "COOPERATIVE"]):
			continue
		var c := world.ledger.balance(EconUtil.acct(oid))
		if c >= best_cash:
			best_cash = c
			best = oid
	return best
