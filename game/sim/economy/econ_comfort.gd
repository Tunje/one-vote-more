class_name EconComfort
extends RefCounted
## Support economy §8b, step 1 (planning/plan-support-economy.md; user: "with hairdressers and the like we can increase
## comfort spending"): households spend a share of their income ABOVE essentials on comfort — cafés, restaurants and
## takeaway (~60%), hairdressers, gyms and entertainment (~40%) — rising with the income band (I1 4% … I5 15% of the
## surplus). The money comes out of the household's existing services budget (households already spend ~100% of
## income: the office A/B showed that added cost does not add jobs), so the gain is labour intensity: comfort work pays
## WAGE_SHARE of its revenue in wages, more than the hubs. One comfort company per district (key "COMFORT|<district>",
## PRIVATE, owned by a household pool of the district), one COMFORT site whose scale = posts × 200.
## Stress buying (§8b.3) is wired once the workload / stress system (27-W) exists. Commuting fares are step 2.
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_S").

const S := EconUtil.S
const SHARE_PM := {"I1": 40, "I2": 60, "I3": 90, "I4": 120, "I5": 150}  # ‰ of the surplus above essentials
const FOOD_SERVICE_PM := 600  # ‰ of comfort spending that is eating out / takeaway (the rest is personal services)
const WAGE_SHARE := 0.6
const POSTS_PER_UNIT := 5  # COMFORT recipe labour per 1000 scale (4 G + 1 S)
const EMA_KEEP := 0.8


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_S") and not EconUtil.off(world, "SUPPORT_S")


const PAYOUT_KEEP_M := 3  # months of wages kept as a cushion before the margin goes to the owners
const DEAD := ["LIQUIDATION", "DISSOLVED", "ADMINISTRATION"]


## The district's live comfort company ("" if none). A failed one keeps its key but is skipped, so a new one is founded
## (v8 full-game check, Wilma: households kept paying dissolved companies — a money sink of millions a decade).
static func company_of(world: WorldState, d: String) -> String:
	for oid in EconUtil.sorted_keys(world.peek("org")):
		var o: Dictionary = world.peek("org")[oid]
		if o["key"] == "COMFORT|" + d and not (o["status"] in DEAD):
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
	world.table("org")[oid] = {"id": oid, "key": "COMFORT|" + d, "name": EconUtil.firm_name(world, d, "SERVICEHUB", "Cafés & Salons"), "type": "PRIVATE",
		"hq": d, "status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 30, "age_m": 40 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": owner, "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, "COMFORT", oid, d, false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "COMFORT":
			return f
	return {}


## Household hook (EconHouseholds._buy_services, before the hubs): a household spends its comfort share of the surplus
## out of its services budget. Returns what was spent (the caller lowers the hub budget by it).
static func spend(world: WorldState, g: Dictionary, budget: int) -> int:
	if not active(world) or budget <= 0:
		return 0
	var surplus := maxi(0, EconHouseholds.disposable(g) - EconHouseholds.essentials_cost(world, g))
	var want := mini(budget, surplus * int(SHARE_PM.get(g.get("band", "I2"), 60)) / 1000)
	if want <= 0:
		return 0
	var d: String = g["district"]
	var oid := company_of(world, d)
	if oid == "":
		oid = _found(world, d)
	var paid := EconUtil.pay_upto(world, EconUtil.hh_acct(g["id"]), EconUtil.acct(oid), want, "SALE")
	EconFinance.pl_add(world, oid, "rev", paid)
	g["spent_goods"] = int(g.get("spent_goods", 0)) + paid
	g["comfort_spent"] = paid
	var s := EconUtil.st(world)
	var rm: Dictionary = s.get("comfort_rev_m", {})
	rm[d] = int(rm.get(d, 0)) + paid
	s["comfort_rev_m"] = rm
	return paid


## COMPANY_AI, before FirmAI.run: staff each district's comfort businesses from their (smoothed) revenue.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var s := EconUtil.st(world)
	var rm: Dictionary = s.get("comfort_rev_m", {})
	var ema: Dictionary = s.get("comfort_rev_ema", {})
	for d in EconUtil.sorted_keys(world.table("district")):
		var oid := company_of(world, d)
		if oid == "":
			continue
		ema[d] = int(EMA_KEEP * float(ema.get(d, rm.get(d, 0))) + (1.0 - EMA_KEEP) * float(rm.get(d, 0)))
		var f := _site(world, oid)
		if f.is_empty():
			continue
		_pay_out(world, oid, f)
		var posts := int(float(ema[d]) * WAGE_SHARE / float(maxi(1, int(s["wage"]["G"]))))
		# whole units: a site keeps 70% of a unit's crew however small (E49 labour hoarding), so a district earning
		# less than one unit's wages ran at a loss and failed (v8 full-game check) — below one unit it closes for now
		posts = posts / POSTS_PER_UNIT * POSTS_PER_UNIT
		f["scale"] = posts * 1000 / POSTS_PER_UNIT
		f["T"] = 1000
		f["mothball"] = posts <= 0
	s["comfort_rev_ema"] = ema
	s["comfort_rev_m"] = {}


## Local partnership: cash above one month of wages goes to the owner pool every month, so the margin returns to
## households as income instead of sitting in the company account (the §8b A/B: retained margins drained demand).
static func _pay_out(world: WorldState, oid: String, f: Dictionary) -> void:
	var o: Dictionary = world.table("org")[oid]
	if o.get("owner_group", "") == "" or not world.table("hh").has(o["owner_group"]):
		return
	var bill := 0
	for t in EconData.RECIPES[f["type"]]["labor"]:
		bill += int(EconData.RECIPES[f["type"]]["labor"][t]) * int(f.get("scale", 0)) / 1000 * EconFinance.wage_for(world, oid, t)
	var spare := world.ledger.balance(EconUtil.acct(oid)) - bill * PAYOUT_KEEP_M
	if spare <= 0:
		return
	world.ledger.transfer(EconUtil.acct(oid), EconUtil.hh_acct(o["owner_group"]), spare, "DIVIDEND", world.month)
	world.table("hh")[o["owner_group"]]["income"]["dividend"] += spare
	EconPop.credit_status(world, o["owner_group"], "NOT_IN_LF", spare, "dividend", "BUSINESS_OWNER")


## Per district {posts, revenue (smoothed), food service share} — for probes and the A/B.
static func summary(world: WorldState) -> Dictionary:
	var out := {}
	var s := EconUtil.peek_st(world)
	for d in EconUtil.sorted_keys(world.peek("district")):
		var oid := company_of(world, d)
		if oid == "":
			continue
		var f := _site(world, oid)
		out[d] = {"posts": EconLabor.staff_total(f["staff"]) / S if not f.is_empty() else 0, "revenue_ema": int(s.get("comfort_rev_ema", {}).get(d, 0)) / S,
			"food_service_pm": FOOD_SERVICE_PM}
	return out
