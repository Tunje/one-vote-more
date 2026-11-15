class_name EconShares
extends RefCounted
## The share register (Anni's planning/design-law-shares.md §1, agreed with Bob; built by Otto for E166 rescues and
## later §3b / E174). A firm has a register only once someone outside its founder holds a stake:
##   o["shares"] = {holder_key: ‰}, summing to 1000; holder keys: "hh:<group>", "co:<org>", "bank", "gov".
## The founder household is "hh:<owner_group>" (or "founder" when the firm has no owner group).
## Firms without a register are owned 100% by their owner group as before, so nothing changes until a stake is sold:
## pay_others() returns the amount untouched and moves no money. Every private-firm dividend site calls it before paying
## the founder (EconAnnual.payout, EconFinance._payout_surplus / dividends / _surplus_sweep, EconBizSvc, EconComfort).

const S := EconUtil.S
const OUTSIDE_MAX_PM := 490  # outside holders together: the founder stays the majority owner (E166)
const BANK_STAKE_CAP_PM := 300  # LAW_BANK_STAKE_CAP default (Anni)


static func founder_key(o: Dictionary) -> String:
	return "hh:" + String(o["owner_group"]) if String(o.get("owner_group", "")) != "" else "founder"


static func has_register(o: Dictionary) -> bool:
	return o.has("shares") and not (o["shares"] as Dictionary).is_empty()


## ‰ held outside the founder (0 without a register).
static func outside_pm(o: Dictionary) -> int:
	if not has_register(o):
		return 0
	return 1000 - int(o["shares"].get(founder_key(o), 0))


static func held_pm(o: Dictionary, holder: String) -> int:
	if not has_register(o):
		return 1000 if holder == founder_key(o) else 0
	return int(o["shares"].get(holder, 0))


## Moves `pm` from the founder to `holder` (creating the register). Returns the ‰ actually moved (capped so outside
## holders stay ≤ OUTSIDE_MAX_PM, and the bank ≤ BANK_STAKE_CAP_PM).
static func add_stake(o: Dictionary, holder: String, pm: int) -> int:
	if not has_register(o):
		o["shares"] = {founder_key(o): 1000}
	pm = mini(pm, OUTSIDE_MAX_PM - outside_pm(o))
	if holder == "bank":
		pm = mini(pm, BANK_STAKE_CAP_PM - held_pm(o, "bank"))
	if pm <= 0:
		return 0
	var reg: Dictionary = o["shares"]
	reg[founder_key(o)] = int(reg[founder_key(o)]) - pm
	reg[holder] = int(reg.get(holder, 0)) + pm
	return pm


## Pays the outside holders their part of a distribution `amount` from the firm's account and returns the founder's
## part (the caller pays that as before). No register: returns `amount`, nothing moves.
static func pay_others(world: WorldState, oid: String, amount: int) -> int:
	var o: Dictionary = world.table("org").get(oid, {})
	if amount <= 0 or o.is_empty() or not has_register(o):
		return amount
	var acc := EconUtil.acct(oid)
	var paid := 0
	var reg: Dictionary = o["shares"]
	for h in EconUtil.sorted_keys(reg):
		var hs := String(h)
		if hs == founder_key(o):
			continue
		var part := amount * int(reg[h]) / 1000
		if part <= 0:
			continue
		if hs.begins_with("hh:") and world.table("hh").has(hs.substr(3)):
			var gid := hs.substr(3)
			world.ledger.transfer(acc, EconUtil.hh_acct(gid), part, "DIVIDEND", world.month)
			world.table("hh")[gid]["income"]["dividend"] += part
			EconPop.credit_status(world, gid, "NOT_IN_LF", part, "dividend", "BUSINESS_OWNER")
		elif hs.begins_with("co:") and world.table("org").has(hs.substr(3)):
			world.ledger.transfer(acc, EconUtil.acct(hs.substr(3)), part, "DIVIDEND", world.month)
			EconFinance.pl_add(world, hs.substr(3), "rev", part)
		elif hs == "bank":
			world.ledger.transfer(acc, EconUtil.BANK, part, "DIVIDEND", world.month)
			_stat(world, "bank_dividends", part)
		elif hs == "gov":
			world.ledger.transfer(acc, EconUtil.TREASURY, part, "PE_DIVIDEND", world.month)
			EconFinance._gov_rev(world, part)
			_stat(world, "public_recovered", part)
		else:
			continue  # a holder that no longer exists: its part stays with the founder
		paid += part
	return amount - paid


static func _stat(world: WorldState, key: String, n: int) -> void:
	var s := EconUtil.st(world)
	var r: Dictionary = s.get("rescue_stats", {})
	r[key] = int(r.get(key, 0)) + n
	s["rescue_stats"] = r
