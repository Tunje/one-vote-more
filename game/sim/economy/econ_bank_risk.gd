class_name EconBankRisk
extends RefCounted
## The bank loses less, lends against deposits for secured lending, raises capital (planning/design-bank.md; user
## 2026-11-16 via Wilma: "Keep it as you suggested"). Each part OPT-IN, off by default:
##   BANK_RISK   a loan's or line's rate follows the borrower's record: base × utilisation factor (as before) ×
##               (1000 + risk‰) / 1000, set at opening and each January for lines. risk‰: a missed payment in the
##               last 12 months, distress, no trading record yet, operating surplus ÷ debt service (cover), and for a
##               builder the share of its open contracts priced below their cost estimate (underbidding). Security
##               (BANK_SEC) lowers it by the secured share. No limit built on past sales: risk changes the price only.
##   BANK_SEC    security: a term loan is secured on the plant it built; a plant nobody buys at the liquidation auction
##               goes to a firm of its sector with its share of the bank debt (rescheduled, E152b's pass_debt) instead
##               of being abandoned; a builder's contract payments repay its line first (ASSIGN_PM of each payment);
##               a line's secured share is stock (50%) + open invoices (80%) + what cost-covered contracts still pay.
##   BANK_DEP    secured lending may use deposits (less a RESERVE_PM reserve) once the capital limit is used up, also
##               while the bank has failed; unsecured lending stays tied to capital.
##   BANK_CAP    nothing goes home while capital is below the floor (as E152c); below it, the bank sells shares to
##               households with savings each January (at most SHARE_PCT of a household's money); shareholders then
##               get their part of the bank's distributed profit instead of the home world.
##   BANK_EQUITY a new firm without security (BANK_SEC off) brings EQUITY_UNSEC_PM of its build cost itself.
## The home world's recapitalisation (Wilma, home_world.gd) uses EconBank.capital_need / recapitalise (always there).

const S := EconUtil.S
const MISSED_PM := 150
const DISTRESS_PM := 300
const NEW_PM := 200
const COVER_LOW_PM := 400   # cover below 1
const COVER_MID_PM := 150   # cover 1 to 1.5
const COVER_HI_PM := -100   # cover above 2
const UNDERBID_PM := 500    # × the share of a builder's open contract value priced below its cost estimate
const STOCK_PM := 500
const RECV_PM := 800
const ASSIGN_PM := 500      # ‰ of each contract payment that goes to the builder's line first
const RESERVE_PM := 200     # ‰ of deposits the bank keeps liquid
const SHARE_PCT := 5        # % of a household's money it puts into bank shares when asked
const EQUITY_PM := 400      # the founder's share of the build cost (as before)
const EQUITY_UNSEC_PM := 550


static func _on(world: WorldState, f: String) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has(f) and not EconUtil.off(world, f)


static func risk_on(world: WorldState) -> bool:
	return _on(world, "BANK_RISK")


static func sec_on(world: WorldState) -> bool:
	return _on(world, "BANK_SEC")


static func dep_on(world: WorldState) -> bool:
	return _on(world, "BANK_DEP")


static func cap_on(world: WorldState) -> bool:
	return _on(world, "BANK_CAP")


static func equity_on(world: WorldState) -> bool:
	return _on(world, "BANK_EQUITY")


# ------------------------------------------------------------------ risk price

## The monthly service of a firm's loans now (interest + principal part), mcr.
static func service(world: WorldState, oid: String) -> int:
	var sv := 0
	for lid in world.peek("loan"):
		var l: Dictionary = world.peek("loan")[lid]
		if l["borrower"] != oid or int(l["principal"]) <= 0:
			continue
		var r := float(l["rate_ppm"]) / 1000000.0
		var n := maxi(1, int(l["term_left"]))
		if bool(l.get("revolving", false)) or n <= 1 or r <= 0.0:
			sv += int(float(l["principal"]) * r) + (0 if bool(l.get("revolving", false)) else int(l["principal"]) / n)
		else:
			sv += int(float(l["principal"]) * r / (1.0 - pow(1.0 + r, -n)))
	return sv


## ‰ of a builder's open contract value priced below its cost estimate (est_cost at award).
static func underbid_pm(world: WorldState, o: Dictionary) -> int:
	var all_v := 0
	var low := 0
	for pid in o.get("contracts", []):
		var p: Dictionary = world.peek("project").get(pid, {})
		if p.is_empty() or not (p["status"] in ["ACTIVE", "AWARDED"]):
			continue
		var left := maxi(0, int(p["price"]) - int(p["paid"]))
		all_v += left
		if int(p["price"]) < int(p.get("est_cost", 0)):
			low += left
	return 0 if all_v <= 0 else 1000 * low / all_v


## Risk ‰ of lending to `oid` (pure). new_service: the monthly service of the loan being opened.
static func risk_pm(world: WorldState, oid: String, new_service: int = 0) -> int:
	var o: Dictionary = world.peek("org").get(oid, {})
	if o.is_empty():
		return 0
	var r := 0
	if EconAnnual.missed_payment(world, oid):
		r += MISSED_PM
	if String(o["status"]) in ["DISTRESSED", "ADMINISTRATION"]:
		r += DISTRESS_PM
	if EconAnnual.months(o) < EconAnnual.MIN_M:
		r += NEW_PM
	else:
		var sv := service(world, oid) + new_service
		if sv > 0:
			var cover := 1000 * EconInsolvency._op_surplus(world, o) / sv
			if cover < 1000:
				r += COVER_LOW_PM
			elif cover < 1500:
				r += COVER_MID_PM
			elif cover > 2000:
				r += COVER_HI_PM
	if bool(o.get("is_contractor", false)):
		r += UNDERBID_PM * underbid_pm(world, o) / 1000
	return r


## What secures a line of `oid` (mcr): stock at cost, open invoices and what cost-covered contracts still pay.
static func line_security(world: WorldState, oid: String) -> int:
	var v := EconMoney.stock_value(world, oid) * STOCK_PM / 1000 + EconMoney.receivables(world, oid) * RECV_PM / 1000
	var o: Dictionary = world.peek("org").get(oid, {})
	for pid in o.get("contracts", []):
		var p: Dictionary = world.peek("project").get(pid, {})
		if not p.is_empty() and p["status"] in ["ACTIVE", "AWARDED"] and int(p["price"]) >= int(p.get("est_cost", 0)):
			v += maxi(0, int(p["price"]) - int(p["paid"]))
	return v


## Secured share ‰ of lending `principal` to `oid`: a term loan is secured on the plant it builds (1000); a line by
## line_security. 0 with BANK_SEC off.
static func secured_pm(world: WorldState, oid: String, principal: int, term: bool) -> int:
	if not sec_on(world):
		return 0
	if term:
		return 1000
	return clampi(1000 * line_security(world, oid) / maxi(1, principal), 0, 1000)


## The rate for lending `principal` to `oid` (ppm a month), from the bank's rate `base_ppm`. BANK_RISK off: unchanged.
static func rate_ppm(world: WorldState, oid: String, base_ppm: int, principal: int, new_service: int, term: bool) -> int:
	if not risk_on(world) or not world.peek("org").has(oid):
		return base_ppm
	var risk := risk_pm(world, oid, new_service)
	if risk > 0:
		risk = risk * (1000 - secured_pm(world, oid, principal, term)) / 1000
	return maxi(1, base_ppm * (1000 + risk) / 1000)


## January: every credit line is re-priced on the borrower's record (BANK_RISK).
static func reprice_lines(world: WorldState) -> void:
	if not risk_on(world) or world.month_of_year() != 1:
		return
	var base := int(EconData.BANK_FIRM_BASE_PM * 1000000)
	if EconBank.active(world):
		base = EconBank.rate_ppm(world, base)
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if bool(l.get("revolving", false)):
			l["rate_ppm"] = rate_ppm(world, String(l["borrower"]), base, maxi(1, int(l["principal"])), 0, false)


# ------------------------------------------------------------------ security

## A builder's contract payment repays its line first (ASSIGN_PM of the payment, up to what is drawn). Returns repaid.
static func assign(world: WorldState, oid: String, paid: int) -> int:
	if not sec_on(world) or paid <= 0:
		return 0
	var lid := EconAnnual.line_id(world, oid)
	if lid == "":
		return 0
	var l: Dictionary = world.table("loan")[lid]
	var rep := mini(int(l["principal"]), mini(paid * ASSIGN_PM / 1000, world.ledger.balance(EconUtil.acct(oid))))
	if rep <= 0:
		return 0
	world.ledger.transfer(EconUtil.acct(oid), EconUtil.BANK, rep, "LINE_REPAY", world.month)
	l["principal"] = int(l["principal"]) - rep
	return rep


## Liquidation: a plant nobody bought at the auction goes to a firm of its sector with its share of the seller's bank
## debt (by book value), rescheduled, instead of being abandoned. Returns true when it found such a buyer.
static func secured_sale(world: WorldState, seller: String, f: Dictionary) -> bool:
	if not sec_on(world) or EconFinance.debt_of(world, seller) <= 0:
		return false
	var buyer := EconInsolvency._find_buyer(world, seller, f, 0)
	if buyer == "":
		return false
	var book_all := 0
	for fid in world.table("facility"):
		var f2: Dictionary = world.table("facility")[fid]
		if f2["org"] == seller and not f2.get("abandoned", false):
			book_all += maxi(0, int(f2["book"]))
	var share := 1000 if book_all <= 0 else clampi(1000 * maxi(0, int(f["book"])) / book_all, 0, 1000)
	EconMoney.pass_debt(world, seller, buyer, share)
	f["org"] = buyer
	f["mothball"] = true  # the buyer reopens it when its own rules say so
	var s := EconUtil.st(world)
	s["bank_secured_sales"] = int(s.get("bank_secured_sales", 0)) + 1
	EconFacts.emit(world, "ECON_FACILITY_SOLD", f["district"], [["COMPANY", seller], ["COMPANY", buyer]],
		[["COMPANY", seller, 0.6], ["EXTERNAL", "bank", 0.4]], {}, 30, "PUBLIC", {"facility": f["id"], "price": 0, "with_debt": true})
	return true


# ------------------------------------------------------------------ deposits

## Room for SECURED lending against deposits (BANK_DEP): deposits less the reserve, less what is lent. 0 when off.
static func deposit_room(world: WorldState) -> int:
	if not dep_on(world) or not EconBank.active(world):
		return 0
	return maxi(0, EconBank.deposits(world) * (1000 - RESERVE_PM) / 1000 - EconBank.loans(world))


## Room for a secured amount: the capital room, or with BANK_DEP the larger deposit room.
static func room_secured(world: WorldState) -> int:
	return maxi(EconBank.room(world), deposit_room(world))


# ------------------------------------------------------------------ capital

## January (BANK_CAP): below the capital floor the bank sells shares to households with savings.
static func raise_capital(world: WorldState) -> void:
	if not cap_on(world) or world.month_of_year() != 1 or not EconBank.active(world):
		return
	var need := EconBank.capital_need(world)
	if need <= 0:
		return
	var s := EconUtil.st(world)
	var fl: Dictionary = s.get("bank_float", {})
	var raised := 0
	for gid in EconUtil.sorted_keys(world.table("hh")):
		if need <= 0:
			break
		var acc := EconUtil.hh_acct(gid)
		var put := mini(need, maxi(0, world.ledger.balance(acc)) * SHARE_PCT / 100)
		if put <= 0:
			continue
		world.ledger.transfer(acc, EconUtil.BANK, put, "BANK_SHARES", world.month)
		fl[gid] = int(fl.get(gid, 0)) + put
		need -= put
		raised += put
	s["bank_float"] = fl
	if raised > 0:
		if EconBank.capital(world) > 0:
			s["bank_failed"] = false
		EconFacts.emit(world, "ECON_BANK_SHARES_SOLD", "d:1", [["EXTERNAL", "bank"]], [["EXTERNAL", "bank", 1.0]], {}, 30, "PUBLIC",
			{"amount": raised / S, "capital_after": EconBank.capital(world) / S})


## The colony shareholders' part ‰ of the bank's distributed profit (their shares against the founding grant).
static func float_pm(world: WorldState) -> int:
	var t := 0
	var fl: Dictionary = EconUtil.peek_st(world).get("bank_float", {})
	for gid in fl:
		t += int(fl[gid])
	return 0 if t <= 0 else 1000 * t / (t + EconData.BANK_CASH * S)


## Pays shareholders their part of `amount` (the profit about to go home). Returns what they got.
static func pay_dividends(world: WorldState, amount: int) -> int:
	var fl: Dictionary = EconUtil.st(world).get("bank_float", {})
	var tot := 0
	for gid in fl:
		tot += int(fl[gid])
	if tot <= 0 or amount <= 0:
		return 0
	var part := amount * float_pm(world) / 1000
	var paid := 0
	for gid in EconUtil.sorted_keys(fl):
		if not world.table("hh").has(gid):
			continue
		var d := part * int(fl[gid]) / tot
		paid += EconUtil.pay_upto(world, EconUtil.BANK, EconUtil.hh_acct(gid), d, "BANK_DIVIDEND")
	return paid


# ------------------------------------------------------------------ founders

## The founder's share ‰ of a new firm's build cost.
static func founder_equity_pm(world: WorldState) -> int:
	return EQUITY_UNSEC_PM if equity_on(world) and not sec_on(world) else EQUITY_PM
