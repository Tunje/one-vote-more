class_name EconSanitation
extends RefCounted
## Support economy part E, step 1 (planning/plan-support-economy.md; W1 of spec-waste: jobs only, before the waste
## economy): the Sanitation Department collects refuse, cleans streets and runs the sewage works — about
## SANIT_PER_10K posts per 10,000 residents (Swedish-like), G-heavy (SANITATION recipe 4 G + 1 S per unit).
## Public institution on the PES pattern: one org (key "SANIT"), one work site whose scale = posts × 200. v1 has no
## budget line of its own (a new lever would change politics even while switched off): it is paid from the treasury
## and booked to ECON_BUDGET_ADMIN as public administration; its own line comes with Wilma's lever-row review.
## OPT-IN until its A/B (world.meta["on"] has "SUPPORT_E"; the same switch adds building upkeep in EconOffice).

const S := EconUtil.S
const SANIT_PER_10K := 30
const POSTS_PER_UNIT := 5  # SANITATION recipe labour per 1000 scale
const LINE := "ECON_BUDGET_ADMIN"


static func active(world: WorldState) -> bool:
	return world.meta.has("on") and (world.meta["on"] as Array).has("SUPPORT_E") and not EconUtil.off(world, "SUPPORT_E")


static func dept(world: WorldState) -> String:
	return EconFinance.org_by_key(world, "SANIT")


static func _found(world: WorldState) -> String:
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "SANIT", "name": "Sanitation Department", "type": "PUBLIC_INSTITUTION", "hq": "d:1",
		"status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 10, "age_m": 45 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, "SANITATION", oid, "d:1", false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "SANITATION":
			return f
	return {}


## Posts the colony needs (persons).
static func need(world: WorldState) -> int:
	return PopStore.total(world) * SANIT_PER_10K / 10000


## COMPANY_AI, before FirmAI.run: size the department to the population and fund next month's wages.
static func monthly(world: WorldState) -> void:
	if not active(world):
		return
	var oid := dept(world)
	if oid == "":
		oid = _found(world)
	var f := _site(world, oid)
	if f.is_empty():
		return
	var posts := (need(world) / POSTS_PER_UNIT) * POSTS_PER_UNIT
	f["scale"] = posts * 1000 / POSTS_PER_UNIT
	f["T"] = 1000
	# fund next month's wage bill from the treasury (booked as public administration)
	var bill := 0
	for t in EconData.RECIPES["SANITATION"]["labor"]:
		bill += int(EconData.RECIPES["SANITATION"]["labor"][t]) * posts / POSTS_PER_UNIT * EconFinance.wage_for(world, oid, t)
	var due := bill - world.ledger.balance(EconUtil.acct(oid))
	if due > 0:
		var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), due, "SANITATION")
		EconFinance._spend_line(world, LINE, paid)
		EconFinance.pl_add(world, oid, "subsidy", paid)


## Posts wanted and held, coverage % (for probes, the office and the coming indicator).
static func summary(world: WorldState) -> Dictionary:
	var oid := dept(world)
	if oid == "":
		return {"need": need(world), "posts": 0, "coverage_pct": 0}
	var f := _site(world, oid)
	var held := EconLabor.staff_total(f["staff"]) / S if not f.is_empty() else 0
	return {"need": need(world), "posts": held, "coverage_pct": int(100.0 * float(held) / maxf(1.0, float(need(world))))}
