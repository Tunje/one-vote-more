class_name EconAnnual
extends RefCounted
## E140 (user via Wilma, 2026-11-14: "firms are not profitable? monthly budgets are extremely limiting — yearly is what
## most run on in real life"). OPT-IN: world.meta["on"] has "E140"; yearly owner payout is the sub-flag "E140P".
## Firms lived month to month: inputs bought from cash minus one month's wages, working capital as a 12-month term loan
## capped at 2× LAST month's revenue (principal/12 in the obligations), distress after 2 months below one month's
## obligations, and PAYOUT emptied every quarter down to 2 months of costs. Under E140:
##   1. a rolling 12-month P&L ring on every org (recorded always: measurement); "profitable" (misconduct, media
##      cover) and the insolvency workout read the 12-month figures;
##   2. the input budget is planned from 12-month revenue: the credit line tops cash up to PLAN_MULT × the average
##      month's sales (a cap, not a target — quantities still follow the production plan);
##   3. a revolving credit line (overdraft) of LINE_MONTHS × the average month's sales for firms profitable over the
##      year: interest only, no principal in the obligations, swept down from cash above SWEEP_KEEP_M months of costs;
##      fully drawn for CONVERT_M months it converts to a term loan (back in the obligations — the zombie rule holds);
##   4. distress only when a payment is missed with the line exhausted, or the year is loss-making and cash is below a
##      month of costs;
##   5. (E140P) owners are paid once a year after the annual accounts, keeping KEEP_M months of costs plus the
##      investment still owed; the quarterly sweep leaves private firms alone.

const RING_M := 12
const MIN_M := 3  # months of history before the yearly figures are used
const PLAN_MULT := 1.2
const LINE_MONTHS := 2.0
const SWEEP_KEEP_M := 2
const CONVERT_M := 12
const CONVERT_TERM := 36
const KEEP_M := 3
const KINDS := ["PRIVATE", "COOPERATIVE"]


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("E140") and not EconUtil.off(world, "E140")


static func yearly_payout(world: WorldState) -> bool:
	return active(world) and (world.meta["on"] as Array).has("E140P") and not EconUtil.off(world, "E140P")


static func applies(world: WorldState, o: Dictionary) -> bool:
	if active(world) and EconMoney.asset_lines(world) and String(o.get("type", "")) == "PUBLIC_ENTERPRISE":
		return true  # E153: public enterprises get working-capital lines too
	return active(world) and String(o.get("type", "")) in KINDS


## 1. Called by EconMarket.trade when the month's P&L rolls over (always: the ring is measurement only).
static func record(o: Dictionary) -> void:
	if (o.get("pl_last", {}) as Dictionary).is_empty():
		return
	var ring: Array = o.get("pl_ring", [])
	ring.append((o["pl_last"] as Dictionary).duplicate())
	while ring.size() > RING_M:
		ring.pop_front()
	o["pl_ring"] = ring


static func months(o: Dictionary) -> int:
	return (o.get("pl_ring", []) as Array).size()


## Sum of the ring's P&L lines (mcr).
static func sum12(o: Dictionary) -> Dictionary:
	var out := {}
	for pl in o.get("pl_ring", []):
		for k in pl:
			out[k] = int(out.get(k, 0)) + int(pl[k])
	return out


static func profit12(o: Dictionary) -> int:
	return EconFinance.profit(sum12(o)) if months(o) > 0 else 0


static func avg_rev(o: Dictionary) -> int:
	var n := months(o)
	return int(sum12(o).get("rev", 0)) / n if n > 0 else 0


## Average month's running costs over the ring (wages, inputs, utilities, freight, interest).
static func avg_costs(o: Dictionary) -> int:
	var n := months(o)
	if n <= 0:
		return EconFinance._monthly_costs(o)
	var s := sum12(o)
	return (int(s.get("wages", 0)) + int(s.get("cogs", 0)) + int(s.get("util", 0)) + int(s.get("freight", 0)) + int(s.get("interest", 0))) / n


## Profitable for the misconduct rule / media cover: over the year under E140, else last month (the old rule).
static func profitable(world: WorldState, o: Dictionary) -> bool:
	if applies(world, o) and months(o) >= MIN_M:
		return profit12(o) > 0
	return EconFinance.profit(o["pl_last"]) > 0 if not (o.get("pl_last", {}) as Dictionary).is_empty() else true


## Monthly profit the owner reasons with (media cover): the year's average under E140, else last month's.
static func profit_month(world: WorldState, o: Dictionary) -> int:
	if applies(world, o) and months(o) >= MIN_M:
		return profit12(o) / months(o)
	return EconFinance.profit(o["pl_last"]) if not (o.get("pl_last", {}) as Dictionary).is_empty() else 0


## Operating surplus for the E77 workout: the year's average month under E140, else last month (EconInsolvency).
static func operating_surplus(world: WorldState, o: Dictionary) -> int:
	if not (applies(world, o) and months(o) >= MIN_M):
		return -2  # caller uses the old rule
	var s := sum12(o)
	if int(s.get("rev", 0)) <= 0:
		return -1
	return (int(s.get("rev", 0)) + int(s.get("subsidy", 0)) - int(s.get("cogs", 0)) - int(s.get("wages", 0)) - int(s.get("freight", 0))) / months(o)


# ------------------------------------------------------------------ 3. the credit line

static func line_id(world: WorldState, oid: String) -> String:
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if l["borrower"] == oid and bool(l.get("revolving", false)):
			return lid
	return ""


static func drawn(world: WorldState, oid: String) -> int:
	var lid := line_id(world, oid)
	return int(world.table("loan")[lid]["principal"]) if lid != "" else 0


## Limit: LINE_MONTHS × the average month's sales, for a firm profitable over the year (0 otherwise: no new draws).
static func limit(world: WorldState, o: Dictionary) -> int:
	if EconMoney.asset_lines(world) and applies(world, o) and months(o) >= MIN_M and o["status"] in ["ACTIVE", "DISTRESSED"]:
		return EconMoney.line_limit(world, o)  # E153: secured on stock and receivables, no profit test
	if not applies(world, o) or months(o) < MIN_M or profit12(o) <= 0:
		return 0
	if not (o["status"] in ["ACTIVE", "DISTRESSED"]):
		return 0
	return int(LINE_MONTHS * float(avg_rev(o)))


static func room(world: WorldState, oid: String) -> int:
	var o: Dictionary = world.table("org")[oid]
	return maxi(0, limit(world, o) - drawn(world, oid))


## Draw up to `amount` from the line into the firm's account. Returns what was drawn.
static func draw(world: WorldState, oid: String, amount: int) -> int:
	var amt := mini(amount, room(world, oid))
	if amt <= 0:
		return 0
	if EconBank.active(world):
		EconBank.ensure(world)
		amt = mini(amt, EconBank.room(world))
	else:
		amt = mini(amt, world.ledger.balance(EconUtil.BANK) - EconData.BANK_MIN_CASH * EconUtil.S)
	if amt <= 0:
		return 0
	var lid := line_id(world, oid)
	if lid == "":
		var rate := int(EconData.BANK_FIRM_BASE_PM * 1000000)
		if EconBank.active(world):
			rate = EconBank.rate_ppm(world, rate)
		lid = world.new_id("loan")
		world.table("loan")[lid] = {"id": lid, "borrower": oid, "principal": 0, "rate_ppm": rate, "term_left": 0, "missed": 0,
			"revolving": true, "full_m": 0}
	world.ledger.transfer(EconUtil.BANK, EconUtil.acct(oid), amt, "LINE_DRAW", world.month)
	world.table("loan")[lid]["principal"] = int(world.table("loan")[lid]["principal"]) + amt
	return amt


## Input budget plan (2): how much the line may add to `own` (cash above the wage reserve) at order time.
static func input_draw(world: WorldState, oid: String, own: int, cost_needed: int) -> int:
	var o: Dictionary = world.table("org")[oid]
	var plan := int(PLAN_MULT * float(avg_rev(o)))
	var want := mini(cost_needed - own, plan - maxi(0, own))
	return draw(world, oid, want) if want > 0 else 0


## SETTLEMENT, before payroll: an overdraft covers this month's wages and interest when cash falls short.
static func pre_settle(world: WorldState) -> void:
	if not active(world):
		return
	for oid in EconUtil.sorted_keys(world.table("org")):
		var o: Dictionary = world.table("org")[oid]
		if not applies(world, o) or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			continue
		var pl: Dictionary = o["pl_last"] if not (o.get("pl_last", {}) as Dictionary).is_empty() else o["pl"]
		var need := int(pl.get("wages", 0)) + int(pl.get("interest", 0))
		var cash := world.ledger.balance(EconUtil.acct(oid))
		if cash < need:
			draw(world, oid, need - cash)


## SETTLEMENT, after loan service: sweep cash above SWEEP_KEEP_M months of costs back into the line; a line fully drawn
## for CONVERT_M months becomes a CONVERT_TERM-month term loan; a dead borrower's line is an ordinary loan for the waterfall.
static func post_settle(world: WorldState) -> void:
	if not active(world):
		return
	for lid in EconUtil.sorted_keys(world.table("loan")):
		var l: Dictionary = world.table("loan")[lid]
		if not bool(l.get("revolving", false)):
			continue
		var oid: String = l["borrower"]
		var o: Dictionary = world.table("org").get(oid, {})
		if o.is_empty() or not (o["status"] in ["ACTIVE", "DISTRESSED"]):
			l["revolving"] = false
			l["term_left"] = CONVERT_TERM
			continue
		var acc := EconUtil.acct(oid)
		var spare := world.ledger.balance(acc) - SWEEP_KEEP_M * maxi(1, avg_costs(o))
		var rep := mini(int(l["principal"]), spare)
		if rep > 0:
			world.ledger.transfer(acc, EconUtil.BANK, rep, "LINE_REPAY", world.month)
			l["principal"] = int(l["principal"]) - rep
		var lim := limit(world, o)
		l["full_m"] = int(l.get("full_m", 0)) + 1 if int(l["principal"]) > 0 and int(l["principal"]) >= lim * 95 / 100 else 0
		if int(l["full_m"]) >= CONVERT_M:
			l["revolving"] = false
			l["term_left"] = CONVERT_TERM
			EconFacts.emit(world, "COMP_CREDIT_LINE_TERMED", o["hq"], [["COMPANY", oid]], [["COMPANY", oid, 1.0]], {}, 10, "OFFICIAL",
				{"principal": int(l["principal"])})
		elif int(l["principal"]) <= 0:
			l["principal"] = 0


# ------------------------------------------------------------------ 4. distress

## E140 replacement for ACTIVE → DISTRESSED (EconInsolvency._step). Returns -1 when the old rule applies.
static func distress(world: WorldState, oid: String, missed: bool, cash: int) -> int:
	var o: Dictionary = world.table("org")[oid]
	if not applies(world, o) or months(o) < MIN_M:
		return -1
	var exhausted := room(world, oid) <= 0
	var losing := profit12(o) < 0 and cash < avg_costs(o)
	return 1 if (missed and exhausted) or losing else 0


## E140: a distressed firm that is profitable over the year, paying its way for 3 months and covering its obligations
## recovers (the old rule asked for 2× obligations in cash — impossible for a firm on a credit line).
static func recovered(world: WorldState, oid: String, cash: int, oblig: int) -> bool:
	var o: Dictionary = world.table("org")[oid]
	return applies(world, o) and months(o) >= MIN_M and profit12(o) > 0 and int(o["ok_streak"]) >= 3 and cash >= oblig


## Measurement (all arms): distress entries, and those of firms profitable over the last 12 months.
static func note_distress(world: WorldState, o: Dictionary) -> void:
	if not (String(o.get("type", "")) in KINDS):
		return
	var s := EconUtil.st(world)
	s["distress_n"] = int(s.get("distress_n", 0)) + 1
	if months(o) >= MIN_M and profit12(o) > 0:
		s["distress_pos12_n"] = int(s.get("distress_pos12_n", 0)) + 1


# ------------------------------------------------------------------ 5. yearly payout (E140P)

## Owners get the cash above KEEP_M months of the year's average costs plus the investment still owed — once a year,
## in the December settlement, if the year was profitable.
static func payout(world: WorldState, oid: String, o: Dictionary) -> void:
	if profit12(o) <= 0:
		return
	var owed := 0
	for pid in world.table("project"):
		var p: Dictionary = world.table("project")[pid]
		if p["owner"] == oid and p["status"] in ["TENDER", "TENDERABLE", "ACTIVE"]:
			owed += (int(p["price"]) - int(p["paid"])) if p["status"] == "ACTIVE" else int(p.get("est_cost", 0))
	var spare := world.ledger.balance(EconUtil.acct(oid)) - KEEP_M * maxi(1, avg_costs(o)) - owed - drawn(world, oid)
	if spare <= 0:
		return
	spare = EconShares.pay_others(world, oid, spare)  # E166 share register: outside holders first (no register: unchanged)
	world.ledger.transfer(EconUtil.acct(oid), EconUtil.hh_acct(o["owner_group"]), spare, "DIVIDEND", world.month)
	world.table("hh")[o["owner_group"]]["income"]["dividend"] += spare
	EconPop.credit_status(world, o["owner_group"], "NOT_IN_LF", spare, "dividend", "BUSINESS_OWNER")
