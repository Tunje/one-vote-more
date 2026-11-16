class_name EconCredit
extends RefCounted
## E148 supplier credit (user decision via Wilma 2026-11-14: "real firms don't wait for monthly government money; they
## run on sales, supplier credit and cost-based prices"). OPT-IN: world.meta["on"] has "E148", until its A/B.
##   INVOICES (TRADE, EconMarket._fill): a firm buying from a firm (private, cooperative or public enterprise) is
##     invoiced instead of paying cash, up to its credit room = CREDIT_M × what it is going to sell in a month
##     (EconAnnual.expected_rev: orders, contracts, forecast; past sales only as a floor) minus what it already owes; beyond the room it pays cash as before. Freight from the
##     transport authority is invoiced the same way. One invoice per buyer, seller and month (table "invoice").
##     The seller books the sale as revenue at once (accrual); the cash arrives when the invoice is paid.
##   PAYMENT (SETTLEMENT, after the loan service): invoices fall due DUE_M month later and are paid from the buyer's
##     account; what cannot be paid stays open and the buyer has missed a payment (missed_this_month → the existing
##     distress rules). An open invoice of a buyer in LIQUIDATION / DISSOLVED is written off (the seller's loss).
##   Households, the government and public institutions still pay cash. The ledger never moves until payment, so it
##     always closes; invoices are integers in their own table (save/load as any table).

const S := EconUtil.S
const CREDIT_M := 1.5
const DUE_M := 1
const KINDS := ["PRIVATE", "COOPERATIVE", "PUBLIC_ENTERPRISE"]
const DEAD := ["LIQUIDATION", "DISSOLVED"]


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("E148") and not EconUtil.off(world, "E148")


## A firm that can buy or sell on account (alive, of a trading kind).
static func trades_on_account(world: WorldState, oid: String) -> bool:
	var o: Dictionary = world.table("org").get(oid, {})
	return not o.is_empty() and o["type"] in KINDS and not (o["status"] in DEAD)


## What a firm owes on open invoices (mcr).
static func owed(world: WorldState, oid: String) -> int:
	var t := 0
	for iid in world.peek("invoice"):
		var inv: Dictionary = world.peek("invoice")[iid]
		if inv["buyer"] == oid:
			t += int(inv["amount"])
	return t


## Credit room now (mcr): CREDIT_M months of expected sales, less what is owed (user 2026-11-16: no limit built on
## past sales, here too). Cached per month in s["credit_room"]
## (TRADE runs many fills; the cache is rebuilt each month and only ever lowered by new invoices).
static func room(world: WorldState, oid: String) -> int:
	var s := EconUtil.st(world)
	var cache: Dictionary = s.get("credit_room", {})
	if int(s.get("credit_room_m", -1)) != world.month:
		cache = {}
		s["credit_room"] = cache
		s["credit_room_m"] = world.month
	if not cache.has(oid):
		var o: Dictionary = world.table("org")[oid]
		cache[oid] = maxi(0, int(float(EconAnnual.expected_rev(world, o)) * CREDIT_M) - owed(world, oid))
	return int(cache[oid])


## Books `amount` (mcr) from buyer to seller on account, up to the buyer's room; returns the amount invoiced.
static func invoice(world: WorldState, buyer: String, seller: String, amount: int, force: bool = false) -> int:
	if amount <= 0:
		return 0
	var amt := amount if force else mini(amount, room(world, buyer))
	room(world, buyer)  # makes sure the cache entry exists
	if amt <= 0:
		return 0
	var key := "%s|%s|%d" % [buyer, seller, world.month]
	var s := EconUtil.st(world)
	var idx: Dictionary = s.get("invoice_idx", {})
	if int(s.get("invoice_idx_m", -1)) != world.month:
		idx = {}
		s["invoice_idx_m"] = world.month
	s["invoice_idx"] = idx
	var iid: String = idx.get(key, "")
	if iid == "" or not world.table("invoice").has(iid):
		iid = world.new_id("inv")
		world.table("invoice")[iid] = {"id": iid, "buyer": buyer, "seller": seller, "amount": 0, "due": world.month + DUE_M, "overdue_m": 0}
		idx[key] = iid
	world.table("invoice")[iid]["amount"] = int(world.table("invoice")[iid]["amount"]) + amt
	s["credit_room"][buyer] = int(s["credit_room"][buyer]) - amt
	s["invoiced_m"] = int(s.get("invoiced_m", 0)) + amt
	return amt


## SETTLEMENT: pay what is due; unpaid → missed payment; dead buyers' invoices written off.
static func settle(world: WorldState) -> void:
	var inv_t := world.table("invoice")
	if inv_t.is_empty():
		return
	var s := EconUtil.st(world)
	var orgs := world.table("org")
	for iid in EconUtil.sorted_keys(inv_t):
		var inv: Dictionary = inv_t[iid]
		var buyer: String = inv["buyer"]
		var seller: String = inv["seller"]
		var amt := int(inv["amount"])
		var bo: Dictionary = orgs.get(buyer, {})
		if amt <= 0:
			inv_t.erase(iid)
			continue
		if bo.is_empty() or bo["status"] in DEAD:
			if orgs.has(seller):
				EconFinance.pl_add(world, seller, "rev", -amt)  # bad debt: the sale is never paid
			s["invoice_written_ytd"] = int(s.get("invoice_written_ytd", 0)) + amt
			inv_t.erase(iid)
			continue
		if int(inv["due"]) > world.month:
			continue
		var to := EconUtil.acct(seller) if orgs.has(seller) else Ledger.EXTERNAL
		var paid := EconUtil.pay_upto(world, EconUtil.acct(buyer), to, amt, "INVOICE")
		inv["amount"] = amt - paid
		if int(inv["amount"]) <= 0:
			inv_t.erase(iid)
		else:
			inv["overdue_m"] = int(inv["overdue_m"]) + 1
			bo["missed_this_month"] = true
			s["invoice_overdue_m"] = int(s.get("invoice_overdue_m", 0)) + 1


## Colony totals for probes: {open, overdue, written_ytd} (credits).
static func view(world: WorldState) -> Dictionary:
	var open := 0
	var overdue := 0
	for iid in world.peek("invoice"):
		var inv: Dictionary = world.peek("invoice")[iid]
		open += int(inv["amount"])
		if int(inv["overdue_m"]) > 0:
			overdue += int(inv["amount"])
	return {"open": open / S, "overdue": overdue / S, "written_ytd": int(EconUtil.peek_st(world).get("invoice_written_ytd", 0)) / S}
