class_name EconVictims
extends RefCounted
## The victim-fund payout (Wilma; the pool payout Anni's justice_ops._pay_victims left to the economy): law:victim_fund
## only filled — a money sink. Each month PAYOUT_DIV-th of the fund's balance goes to households: those in the districts
## named by the open awards' scope ({"districts": [...]}), or, with no such scope, the colony's poorer half (by
## disposable income per person). Shares by persons. Counted by the fund's balance, not by award rows (awards paid
## through insolvency carry no row); open awards are marked paid oldest first as the money goes out.
## OPT-IN with CONDUCT (world.meta["on"] has "CONDUCT").

const FUND := "law:victim_fund"
const PAYOUT_DIV := 6
const MIN_PAY := 500000  # 500 credits


static func active(world: WorldState) -> bool:
	return EconConduct.active(world)


static func monthly(world: WorldState) -> void:
	if not active(world) or not world.ledger.has_account(FUND):
		return
	var bal := world.ledger.balance(FUND)
	var pay := mini(bal, maxi(bal / PAYOUT_DIV, MIN_PAY))  # the tail goes out whole, not as dust
	if pay <= 0:
		return
	# districts named by the open awards
	var districts := {}
	var awards: Dictionary = world.table("victim_award")
	for aid in EconUtil.sorted_keys(awards):
		var a: Dictionary = awards[aid]
		if a.get("status", "") != "OPEN":
			continue
		for d in (a.get("scope", {}) as Dictionary).get("districts", []):
			if world.table("district").has(String(d)):
				districts[String(d)] = true
	var gids: Array = []
	var w8: Array = []
	if not districts.is_empty():
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var g: Dictionary = world.table("hh")[gid]
			if districts.has(g["district"]) and EconHouseholds.persons(g) > 0:
				gids.append(gid)
				w8.append(float(EconHouseholds.persons(g)))
	if gids.is_empty():
		var rows: Array = []
		for gid in EconUtil.sorted_keys(world.table("hh")):
			var g: Dictionary = world.table("hh")[gid]
			var p := EconHouseholds.persons(g)
			if p > 0:
				rows.append([float(EconHouseholds.disposable(g)) / float(p), gid, p])
		rows.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and String(x[1]) < String(y[1])))
		for i in maxi(1, (rows.size() + 1) / 2):
			if i < rows.size():
				gids.append(rows[i][1])
				w8.append(float(rows[i][2]))
	if gids.is_empty():
		return
	var parts := EconUtil.split_lr(pay, w8)
	var paid := 0
	for i in gids.size():
		if int(parts[i]) > 0:
			paid += EconUtil.pay_upto(world, FUND, EconUtil.hh_acct(gids[i]), int(parts[i]), "VICTIM_COMPENSATION")
	# mark the open awards paid, oldest first
	var left := paid
	for aid in EconUtil.sorted_keys(awards):
		var a: Dictionary = awards[aid]
		if a.get("status", "") != "OPEN" or left <= 0:
			continue
		var owe := int(a["amount"]) - int(a.get("paid_out", 0))
		var x := mini(owe, left)
		a["paid_out"] = int(a.get("paid_out", 0)) + x
		left -= x
		if int(a["paid_out"]) >= int(a["amount"]):
			a["status"] = "PAID"
	var s := EconUtil.st(world)
	s["victim_paid_total"] = int(s.get("victim_paid_total", 0)) + paid
