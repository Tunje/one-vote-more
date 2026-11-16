class_name EconMoney
extends RefCounted
## The money fix (planning/money-audit.md, user decision 2026-11-14): bank lending must be able to grow the money
## stock with the economy. Bob's parts, each OPT-IN until its A/B:
##   E152 a sound bank. The audit (seeds 1/3, 60 years): interest earned +19/+12 against write-offs −26/−19 (debt
##     workouts −20/−11, liquidations −5/−8) and the remittance −3, so capital fell 16 → 4–5 (seed 1 failed ~Y45).
##     (a) a debt workout RESCHEDULES (term + RESCHEDULE_M, RESCHEDULE_GRACE_M months interest only) instead of writing
##         the debt down; the loss is booked only if the firm later dies;
##     (b) a workers' co-op that takes over a failed firm's plant also takes over that plant's share of its bank debt
##         (by book value), rescheduled — before, buyouts were free and the whole debt was written off;
##     (c) no remittance to the home world while capital is below CAPITAL_FLOOR (the founding capital or
##         CAPITAL_LOAN_PCT of loans, whichever is larger).
##   E153 working capital against what a firm owns, not against a profitable year: the E140 credit line's limit becomes
##     STOCK_PCT of its stock at cost + RECV_PCT of what customers owe it (E148 invoices) + REV_M months of expected
##     sales (EconAnnual.expected_rev; user 2026-11-16: no limit built on past sales), with no profit test; public enterprises get lines too.

const S := EconUtil.S
const RESCHEDULE_M := 36
const RESCHEDULE_GRACE_M := 6
const CAPITAL_LOAN_PCT := 15
const STOCK_PCT := 50
const RECV_PCT := 80
const REV_M := 1.0


static func _on(world: WorldState, flag: String) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(flag) and not EconUtil.off(world, flag)


static func sound_bank(world: WorldState) -> bool:
	return _on(world, "E152")


static func asset_lines(world: WorldState) -> bool:
	return _on(world, "E153")


# ------------------------------------------------------------------ E152

## (a) reschedule a firm's term loans instead of writing them down (revolving lines stay as they are).
static func reschedule(world: WorldState, oid: String) -> void:
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] != oid or int(l["principal"]) <= 0 or bool(l.get("revolving", false)):
			continue
		l["term_left"] = int(l["term_left"]) + RESCHEDULE_M
		l["grace_until"] = world.month + RESCHEDULE_GRACE_M
		l["missed"] = 0
	var s := EconUtil.st(world)
	s["bank_rescheduled_n"] = int(s.get("bank_rescheduled_n", 0)) + 1


## (b) the co-op `buyer` takes over `share_pm` ‰ of `seller`'s bank debt, as a rescheduled term loan.
static func pass_debt(world: WorldState, seller: String, buyer: String, share_pm: int) -> void:
	var moved := 0
	var rate := 0
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] != seller or int(l["principal"]) <= 0 or bool(l.get("hh", false)):
			continue
		var part := int(l["principal"]) * share_pm / 1000
		if part <= 0:
			continue
		l["principal"] = int(l["principal"]) - part
		moved += part
		rate = maxi(rate, int(l["rate_ppm"]))
	if moved <= 0:
		return
	var nid := world.new_id("loan")
	world.table("loan")[nid] = {"id": nid, "borrower": buyer, "principal": moved, "rate_ppm": rate, "term_left": 60 + RESCHEDULE_M,
		"missed": 0, "grace_until": world.month + RESCHEDULE_GRACE_M}


## (c) the bank keeps its profit while its capital is below the floor.
static func remit_allowed(world: WorldState) -> bool:
	if not sound_bank(world) and not EconBankRisk.cap_on(world):
		return true
	var floor_c := maxi(EconData.BANK_CASH * S, EconBank.loans(world) * CAPITAL_LOAN_PCT / 100)
	return EconBank.capital(world) >= floor_c


# ------------------------------------------------------------------ E153

## Stock at cost (mcr) a firm holds, all goods and districts (port stock included).
static func stock_value(world: WorldState, oid: String) -> int:
	var t := 0
	var pre := oid + "|"
	for k in world.peek("inv"):
		if String(k).begins_with(pre):
			var e: Dictionary = world.peek("inv")[k]
			t += EconUtil.val(int(e.get("q", 0)), int(e.get("wac", 0)))
	return t


## What customers owe the firm on open invoices (E148), mcr.
static func receivables(world: WorldState, oid: String) -> int:
	var t := 0
	for iid in world.peek("invoice"):
		var inv: Dictionary = world.peek("invoice")[iid]
		if inv["seller"] == oid:
			t += int(inv["amount"])
	return t


## The asset-based line limit (mcr).
static func line_limit(world: WorldState, o: Dictionary) -> int:
	var oid: String = o["id"]
	return stock_value(world, oid) * STOCK_PCT / 100 + receivables(world, oid) * RECV_PCT / 100 + int(REV_M * float(EconAnnual.expected_rev(world, o) if EconCredit.expected_on(world) else EconAnnual.avg_rev(o)))


# ------------------------------------------------------------------ E155

## E155 (user, money fix: "a company going to a colony would have 5 years of costs calculated and saved before going"):
## the founding private firms and co-ops (the colony's sponsors) arrive with FOUND_M months of their running costs in
## cash from the home world and FOUND_M months of upkeep parts, and without start-up loans (they paid in their own
## savings). Applied once, in the first month (flags may be set after setup). Builders arriving later: FirmAI.
const FOUND_M := 60
const FOUND_KINDS := ["PRIVATE", "COOPERATIVE"]


static func home_capital(world: WorldState) -> bool:
	return _on(world, "E155")


## Monthly running cost of an org at founding (mcr): its plants' recipe crews at the wage index, market inputs and
## upkeep parts at base prices; a contractor's crew target + 10% for equipment.
static func founding_cost(world: WorldState, oid: String) -> int:
	var s := EconUtil.st(world)
	var o: Dictionary = world.table("org")[oid]
	var c := 0
	for fid in world.table("facility"):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] != oid:
			continue
		var r: Dictionary = EconData.RECIPES[f["type"]]
		for t in r["labor"]:
			c += int(float(r["labor"][t]) * EconUtil.fscale(f)) * int(s["wage"][t])
		for g in r["in"]:
			if g in EconData.MARKET_GOODS:
				c += int(float(r["in"][g]) * EconUtil.fscale(f)) * EconData.BASE_PRICE[g] * S
		c += int(r["upkeep"]) * EconData.BASE_PRICE["MATERIAL"] * S + int(EconData.UPKEEP_COMPONENT.get(f["type"], 0)) * EconData.BASE_PRICE["COMPONENT"] * S
	for t in o.get("crew_target", {}):
		c += int(float(int(o["crew_target"][t]) * int(s["wage"][t])) * 1.1)
	return c


static func found_capital(world: WorldState) -> void:
	var s := EconUtil.st(world)
	if not home_capital(world) or bool(s.get("e155_done", false)) or world.month > 1:
		return
	s["e155_done"] = true
	var brought := 0
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not (o["type"] in FOUND_KINDS):
			continue
		# no start-up loans: they paid in their own savings (the setup loans moved no cash, so they simply go)
		for lid in EconUtil.sorted_keys(world.table("loan")):
			if world.table("loan")[lid]["borrower"] == oid:
				world.table("loan").erase(lid)
		var target := founding_cost(world, oid) * FOUND_M
		var top := target - world.ledger.balance(EconUtil.acct(oid))
		if top > 0:
			world.ledger.transfer(Ledger.EXTERNAL, EconUtil.acct(oid), top, "HOME_CAPITAL", world.month)
			brought += top
		# equipment and machines: FOUND_M months of upkeep parts, at base prices
		for fid in EconUtil.sorted_keys(world.table("facility")):
			var f: Dictionary = world.table("facility")[fid]
			if f["org"] != oid:
				continue
			var r: Dictionary = EconData.RECIPES[f["type"]]
			if int(r["upkeep"]) > 0:
				var qm := int(r["upkeep"]) * S * FOUND_M
				EconUtil.inv_add(world, oid, "MATERIAL", f["district"], qm, EconData.BASE_PRICE["MATERIAL"] * S)
				EconUtil.qflow(world, "MATERIAL", "imported", qm)
			var uc := int(EconData.UPKEEP_COMPONENT.get(f["type"], 0))
			if uc > 0:
				EconUtil.inv_add(world, oid, "COMPONENT", f["district"], uc * S * FOUND_M, EconData.BASE_PRICE["COMPONENT"] * S)
				EconUtil.qflow(world, "COMPONENT", "imported", uc * S * FOUND_M)
			f["condition"] = 100 * S
	s["builder_home_capital"] = int(s.get("builder_home_capital", 0)) + brought
	s["e155_founding_capital"] = brought
