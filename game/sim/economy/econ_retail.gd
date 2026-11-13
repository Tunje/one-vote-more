class_name EconRetail
extends RefCounted
## Support economy part D, step 1 (planning/plan-support-economy.md §8; user: "who delivers things ... where are the
## shops"): retail. Household purchases of food and goods pass through the district's shops, which take a margin
## (FOOD 5% grocer margin for now — Wilma: raise toward ~15% once the food trap is fixed, separately; CONSUMER and the
## D2 goods 20%) and employ shop staff. One shop company per district (key "SHOPS|<district>", PRIVATE, owned by a
## household pool of the district, so its profit returns as dividends), one RETAIL site whose scale = posts × 200.
## Staff are sized so wages take WAGE_SHARE of the margin revenue (a slow average): the margin is local wages and shop
## profits, not a tax — the A/B checks that real income stays roughly whole (Wilma).
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_D").

const S := EconUtil.S
const MARGIN_PM := {"FOOD": 0, "CONSUMER": 200, "CLOTHING": 200, "FURNISHINGS": 200, "FINE_FOOD": 200}  # FOOD 0 after the A/B (shortfall 38–73‰ at 5%)
const WAGE_SHARE := 0.7
const POSTS_PER_UNIT := 5  # RETAIL recipe labour per 1000 scale (4 G + 1 S)
const EMA_KEEP := 0.8  # monthly smoothing of margin revenue


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_D") and not EconUtil.off(world, "SUPPORT_D")


## Retail margin (‰) a household pays on top of the producer's price (0 when off).
static func margin_pm(world: WorldState, good: String) -> int:
	return int(MARGIN_PM.get(good, 0)) if active(world) else 0


static func shop_of(world: WorldState, d: String) -> String:
	return EconFinance.org_by_key(world, "SHOPS|" + d)


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
	world.table("org")[oid] = {"id": oid, "key": "SHOPS|" + d, "name": EconUtil.firm_name(world, d, "SERVICEHUB", "Shops"), "type": "PRIVATE",
		"hq": d, "status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 30, "age_m": 40 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": owner, "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, "RETAIL", oid, d, false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "RETAIL":
			return f
	return {}


## Market hook (EconMarket._fill, household purchases): the household pays the margin to its district's shops.
## Returns what was paid.
static func on_sale(world: WorldState, d: String, hh_acct: String, good: String, goods_cost: int) -> int:
	var m := margin_pm(world, good)
	if m <= 0 or goods_cost <= 0:
		return 0
	var oid := shop_of(world, d)
	if oid == "":
		oid = _found(world, d)
	var paid := EconUtil.pay_upto(world, hh_acct, EconUtil.acct(oid), int(float(goods_cost) * float(m) / 1000.0), "RETAIL")
	EconFinance.pl_add(world, oid, "rev", paid)
	var s := EconUtil.st(world)
	var rm: Dictionary = s.get("retail_rev_m", {})
	rm[d] = int(rm.get(d, 0)) + paid
	s["retail_rev_m"] = rm
	return paid


## COMPANY_AI, before FirmAI.run: staff each district's shops from their (smoothed) margin revenue.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var rm: Dictionary = s.get("retail_rev_m", {})
	var ema: Dictionary = s.get("retail_rev_ema", {})
	for d in EconUtil.sorted_keys(world.table("district")):
		var oid := shop_of(world, d)
		if oid == "" or world.table("org")[oid]["status"] in ["LIQUIDATION", "DISSOLVED"]:
			continue
		ema[d] = int(EMA_KEEP * float(ema.get(d, rm.get(d, 0))) + (1.0 - EMA_KEEP) * float(rm.get(d, 0)))
		var f := _site(world, oid)
		if f.is_empty():
			continue
		var wage := maxi(1, int(s["wage"]["G"]))
		var posts := int(float(ema[d]) * WAGE_SHARE / float(wage))
		f["scale"] = posts * 1000 / POSTS_PER_UNIT
		f["T"] = 1000
	s["retail_rev_ema"] = ema
	s["retail_rev_m"] = {}


## Shops per district: {posts held, margin revenue (smoothed)} — for probes and the A/B.
static func summary(world: WorldState) -> Dictionary:
	var out := {}
	var s := EconUtil.peek_st(world)
	for d in EconUtil.sorted_keys(world.peek("district")):
		var oid := shop_of(world, d)
		if oid == "":
			continue
		var f := _site(world, oid)
		out[d] = {"posts": EconLabor.staff_total(f["staff"]) / S if not f.is_empty() else 0, "margin_ema": int(s.get("retail_rev_ema", {}).get(d, 0)) / S}
	return out
