class_name EconBizSvc
extends RefCounted
## Support economy part C (planning/plan-support-economy.md §2 C): business services. Every organisation buys
## cleaning, catering, courier and office-supply services in proportion to its staff: FEE_PM ‰ of the General wage per
## worker a month, paid to the business-services firm of the workplace's district (key "BIZSVC|<district>", PRIVATE,
## owned by a household pool of the district). The firm staffs its BIZSVC site (1 G a unit) from WAGE_SHARE of
## its smoothed revenue, in whole units (E49 hoarding), and pays the margin above PAYOUT_KEEP_M months of wages to its
## owners (the comfort lessons, v8 check: a live company only, whole units, a cushion). The fee rides on every
## production post in FirmAI.unit_cost (cost_factor), so prices can pass it on.
## A firm short of cash pays what it can (never pushed into distress by its cleaners). Rival service firms come with
## the rivalry work (backlog 28).
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_C").

const S := EconUtil.S
const FEE_PM := 40
const WAGE_SHARE := 0.7
const POSTS_PER_UNIT := 1  # one-person units: district fees buy 3–15 posts, so 5-post units rounded most to nothing
const PAYOUT_KEEP_M := 3
const EMA_KEEP := 0.8
const DEAD := ["LIQUIDATION", "DISSOLVED", "ADMINISTRATION"]
const NO_FEE := ["BIZSVC", "HOUSING", "ROAD"]
## v1 A/B (5 seeds × 30 years econ-only): as a per-worker cost on everyone it raised unit costs, unemployment +0.9
## points and tipped seed 3 into the food trap (shortfall 177‰). PROFIT_ONLY: a firm buys services only out of last
## month's profit (at most PROFIT_CAP of it) and the fee stays out of unit costs; public institutions do not buy.
const PROFIT_ONLY := true
const PROFIT_CAP := 0.5
const SPLIT_PM := {"CLEANING": 400, "CATERING": 300, "COURIER": 200, "SUPPLIES": 100}  # for reports


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_C") and not EconUtil.off(world, "SUPPORT_C")


## Labour-cost multiplier for FirmAI.unit_cost (1.0 when off).
static func cost_factor(world: WorldState) -> float:
	if not active(world) or PROFIT_ONLY:
		return 1.0
	var s := EconUtil.peek_st(world)
	var wg := float(int(s["wage"]["G"]))
	var avg := (wg + float(int(s["wage"]["S"]))) / 2.0
	return 1.0 + float(FEE_PM) / 1000.0 * wg / maxf(1.0, avg)


static func company_of(world: WorldState, d: String) -> String:
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if o["key"] == "BIZSVC|" + d and not (o["status"] in DEAD):
			return oid
	return ""


static func _found(world: WorldState, d: String) -> String:
	var owner := ""
	var best := -1
	for gid in EconUtil.sorted_keys(world.table("hh")):
		var g: Dictionary = world.table("hh")[gid]
		if g["district"] == d:
			var c := world.ledger.balance(EconUtil.hh_acct(gid))
			if c > best:
				best = c
				owner = gid
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "BIZSVC|" + d, "name": EconUtil.firm_name(world, d, "SERVICEHUB", "Business Services"), "type": "PRIVATE",
		"hq": d, "status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 30, "age_m": 40 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": owner, "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, "BIZSVC", oid, d, false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	world.table("facility")[fid]["mothball"] = true
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "BIZSVC":
			return f
	return {}


## COMPANY_AI, before FirmAI.run: collect last month's fees by district, staff the firms, pay out the margin.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var wg := int(s["wage"]["G"])
	var fee_per := wg * FEE_PM / 1000
	# fees: every workplace's staff, to its district's firm
	var rev_d := {}
	var spent_o := {}
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["mothball"] or f["type"] in NO_FEE:
			continue
		var heads := EconLabor.staff_total(f["staff"]) / S
		if heads <= 0:
			continue
		var o: Dictionary = world.table("org").get(f["org"], {})
		if o.is_empty() or o["status"] in DEAD:
			continue
		var d: String = f["district"]
		var sid := company_of(world, d)
		if sid == "":
			sid = _found(world, d)
		if sid == f["org"]:
			continue
		var due := heads * fee_per
		if PROFIT_ONLY:
			if o["type"] == "PUBLIC_INSTITUTION":
				continue
			var pr := EconFinance.profit(o.get("pl_last", {})) if not (o.get("pl_last", {}) as Dictionary).is_empty() else 0
			var room := int(float(maxi(0, pr)) * PROFIT_CAP) - int(spent_o.get(f["org"], 0))
			due = mini(due, maxi(0, room))
			if due <= 0:
				continue
		var paid := EconUtil.pay_upto(world, EconUtil.acct(f["org"]), EconUtil.acct(sid), due, "BIZ_SERVICES")
		spent_o[f["org"]] = int(spent_o.get(f["org"], 0)) + paid
		if paid > 0:
			EconFinance.pl_add(world, f["org"], "rent", paid)  # occupancy and services
			EconFinance.pl_add(world, sid, "rev", paid)
			rev_d[d] = int(rev_d.get(d, 0)) + paid
	var ema: Dictionary = s.get("bizsvc_rev_ema", {})
	for d in EconUtil.sorted_keys(world.table("district")):
		var sid2 := company_of(world, d)
		if sid2 == "":
			continue
		ema[d] = int(EMA_KEEP * float(ema.get(d, rev_d.get(d, 0))) + (1.0 - EMA_KEEP) * float(rev_d.get(d, 0)))
		var f2 := _site(world, sid2)
		if f2.is_empty():
			continue
		var posts := int(float(ema[d]) * WAGE_SHARE / float(maxi(1, wg))) / POSTS_PER_UNIT * POSTS_PER_UNIT
		f2["scale"] = posts * 1000 / POSTS_PER_UNIT
		f2["T"] = 1000
		f2["mothball"] = posts <= 0
		_pay_out(world, sid2, f2)
	s["bizsvc_rev_ema"] = ema


static func _pay_out(world: WorldState, oid: String, f: Dictionary) -> void:
	var o: Dictionary = world.table("org")[oid]
	if o.get("owner_group", "") == "" or not world.table("hh").has(o["owner_group"]):
		return
	var bill := 0
	var req := EconLabor.required(f)
	for t in req:
		bill += int(req[t]) / S * EconFinance.wage_for(world, oid, t)
	var spare := world.ledger.balance(EconUtil.acct(oid)) - bill * PAYOUT_KEEP_M
	if spare <= 0:
		return
	world.ledger.transfer(EconUtil.acct(oid), EconUtil.hh_acct(o["owner_group"]), spare, "DIVIDEND", world.month)
	world.table("hh")[o["owner_group"]]["income"]["dividend"] += spare
	EconPop.credit_status(world, o["owner_group"], "NOT_IN_LF", spare, "dividend", "BUSINESS_OWNER")


## Per district {posts, revenue_ema (credits a month)} and the colony's split by service (for probes and reports).
static func summary(world: WorldState) -> Dictionary:
	var out := {}
	var s := EconUtil.peek_st(world)
	var posts := 0
	for d in EconUtil.sorted_keys(world.peek("district")):
		var oid := company_of(world, d)
		if oid == "":
			continue
		var f := _site(world, oid)
		var p := EconLabor.staff_total(f["staff"]) / S if not f.is_empty() else 0
		posts += p
		out[d] = {"posts": p, "revenue_ema": int(s.get("bizsvc_rev_ema", {}).get(d, 0)) / S}
	var split := {}
	for k in SPLIT_PM:
		split[k] = posts * int(SPLIT_PM[k]) / 1000
	out["colony"] = {"posts": posts, "by_service": split}
	return out
