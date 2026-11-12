class_name EconPublicJobs
extends RefCounted
## E117b (Wilma-approved): public employment scheme. Parliament funds ECON_BUDGET_PUBLIC_EMPLOYMENT (LAW level,
## default 0; GovBuilder does not touch it). The Public Employment Service (org key "PES", a public institution)
## hires unemployed General and Skilled workers for upkeep work — roads, parks, depots — that produces nothing for
## sale, so the wages are pure budget cost. Pay is PES_PAY of the General wage for every post, so any private or
## other public job is more attractive (hiring fills higher wages first; essential plants first of all).
## Each month (COMPANY_AI): posts = min(line's monthly budget / pay, unemployed + current posts), crewed 4 G : 1 S at
## the scheme's work site ("PUBJOBS" facility); the PES account is topped up with next month's wage bill from the line
## (within its headroom). A cut budget lays people off through the ordinary vacancy machinery. Large changes in
## posts emit ECON_PUBLIC_JOBS_HIRED / ECON_PUBLIC_JOBS_CUT for the papers.

const S := EconUtil.S
const LINE := "ECON_BUDGET_PUBLIC_EMPLOYMENT"
const PES_PAY := 0.8
const CREW_UNIT := 5  # posts per unit of facility scale (recipe PUBJOBS: 4 G + 1 S)
const BULK := 20  # posts changed in a month that make news


## The scheme's org id ("" if it was never needed).
static func pes(world: WorldState) -> String:
	return EconFinance.org_by_key(world, "PES")


static func _found(world: WorldState) -> String:
	var oid := world.new_id("org")
	world.table("org")[oid] = {"id": oid, "key": "PES", "name": "Public Employment Service", "type": "PUBLIC_INSTITUTION", "hq": "d:2",
		"status": "ACTIVE", "ceo": {"mgmt": 50, "risk": 10, "age_m": 45 * 12}, "reliability": 0, "is_contractor": false,
		"crew": {}, "crew_target": {}, "premium_m": {"G": 0, "S": 0, "Sp": 0}, "tax_loss_cf": 0, "profit_q": 0,
		"pl": EconFinance.empty_pl(), "pl_last": {}, "missed_streak": 0, "ok_streak": 0, "low_cash_streak": 0, "distress_months": 0,
		"admin_months": 0, "liq_months": 0, "missed_this_month": false, "owner_group": "", "sales_ema": {}, "contracts": [],
		"dividends_ytd": 0, "sold": {}}
	world.ledger.open_account(EconUtil.acct(oid))
	var fid := EconSetup.add_facility(world, "PUBJOBS", oid, "d:2", false)
	world.table("facility")[fid]["scale"] = 0
	world.table("facility")[fid]["book"] = 0
	return oid


static func _site(world: WorldState, oid: String) -> Dictionary:
	for fid in EconUtil.sorted_keys(world.table("facility")):
		var f: Dictionary = world.table("facility")[fid]
		if f["org"] == oid and f["type"] == "PUBJOBS":
			return f
	return {}


## Monthly wage per post (milli): PES_PAY × the General wage index (the safety-law surcharge applies as for anyone).
static func pay(world: WorldState) -> int:
	return int(float(EconUtil.st(world)["wage"]["G"]) * PES_PAY)


## Current posts held (persons).
static func posts(world: WorldState) -> int:
	var oid := pes(world)
	if oid == "":
		return 0
	var f := _site(world, oid)
	return 0 if f.is_empty() else EconLabor.staff_total(f["staff"]) / S


## COMPANY_AI, after training: size the scheme to its budget and fund next month's wages.
static func monthly(world: WorldState) -> void:
	if EconUtil.off(world, "E117"):
		return
	var annual := int(EconUtil.lever(world, LINE, 0)) * 1000 * S
	var oid := pes(world)
	if annual <= 0 and oid == "":
		return  # never funded: the scheme does not exist
	if oid == "":
		oid = _found(world)
	var f := _site(world, oid)
	if f.is_empty():
		return
	var held := posts(world)
	var w := maxi(1, EconFinance.wage_for(world, oid, "G"))
	var budget_m := mini(annual / 12, maxi(0, EconActions.headroom(world, LINE)))
	var free := PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:G") + PopStore.count(world, {"status": "UNEMPLOYED"}, "skill:S")
	var target := mini(budget_m / w, free + held)
	target = (target / CREW_UNIT) * CREW_UNIT
	f["scale"] = target * 1000 / CREW_UNIT
	# fund next month's bill (target posts) from the line, keeping what is already in the account
	var need := target * w - world.ledger.balance(EconUtil.acct(oid))
	if need > 0:
		var paid := EconFinance.gov_pay(world, EconUtil.acct(oid), mini(need, maxi(0, EconActions.headroom(world, LINE))), "PUBLIC_EMPLOYMENT")
		EconFinance._spend_line(world, LINE, paid)
		EconFinance.pl_add(world, oid, "subsidy", paid)
	var s := EconUtil.st(world)
	var last := int(s.get("pes_target", 0))
	s["pes_target"] = target
	if target - last >= BULK:
		EconFacts.emit(world, "ECON_PUBLIC_JOBS_HIRED", "d:2", [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
			{"JOBS": mini(30, (target - last) / 4)}, 30, "PUBLIC", {"posts": target - last, "total": target, "pay_pct": int(PES_PAY * 100)})
	elif last - target >= BULK:
		EconFacts.emit(world, "ECON_PUBLIC_JOBS_CUT", "d:2", [["GOVERNMENT", "government"]], [["GOVERNMENT", "government", 1.0]],
			{"JOBS": -mini(30, (last - target) / 4)}, 35, "PUBLIC", {"posts": last - target, "total": target})


## For EconQuery / GovBuilder views.
static func summary(world: WorldState) -> Dictionary:
	return {"posts": posts(world), "target": int(EconUtil.peek_st(world).get("pes_target", 0)), "pay": pay(world) / S,
		"budget_pa": int(EconUtil.lever(world, LINE, 0)), "headroom": EconActions.headroom(world, LINE) / S}
